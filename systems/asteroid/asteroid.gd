class_name Asteroid extends RigidBody2D

signal chunk_broken(material_counts: Dictionary[StringName, int], world_position: Vector2)
signal fragment_spawned(fragment: Asteroid)

const HIT_SEARCH_DISTANCE: float = 6.0
const HIT_SEARCH_STEP: float = 0.5
const DAMAGE_PAINT_STEPS: int = 12
const COLLISION_CLEANUP_INSET: float = 0.01

@export var asteroid_def: AsteroidDefinition
@export var gen_seed: int = 0
@export_range(0.0, 1.0, 0.01, "or_greater", "suffix:s") var collision_recalculation_interval: float = 0.1
@export_range(0.0001, 1.0, 0.0001, "or_greater") var mass_per_density: float = 0.01

@export_group("Breaking")
@export_range(0, 200, 1, "or_greater") var min_fragment_cells: int = 40
@export_range(0.0, 1.0) var damage_spread: float = 0.1
@export var fragment_kick: float = 12.0
@export var explosion_kick: float = 150.0
@export var blast_debris_speed: float = 2.5
@export var debris_min_speed: float = 20.0
@export var debris_max_speed: float = 60.0
@export var debris_max_spin: float = 4.0

@export_group("Debug")
@export var debug_show_chunks: bool = false

var cells: PackedByteArray
var health: PackedFloat32Array
var size: Vector2i
var chunks: ChunkMap
var materials: Array[MaterialDefinition] = []
var blueprint: AsteroidBlueprint

var _painter: AsteroidPainter
var _image: Image
var _texture: ImageTexture
var _origin: Vector2
var _solid: int = 0
var _used_seed: int = 0
var _tint_offset: Vector2i = Vector2i.ZERO
var _painted_step: PackedInt32Array
var _texture_dirty: bool = false
var _collision_dirty: bool = false
var _islands_dirty: bool = false
var _collision_interval: float = 0.0
var _is_fragment: bool = false
var _shape_owner: int = -1
var _mass_sum: float = 0.0
var _mass_moment: Vector2 = Vector2.ZERO
var _mass_second_moment: float = 0.0
var _pocket_triggered: PackedByteArray

func _ready() -> void:
	if blueprint != null:
		_apply(blueprint)
		blueprint = null
	else:
		generate()


func generate() -> void:
	if asteroid_def == null:
		return
	_validate_settings()
	var used_seed: int = gen_seed if gen_seed != 0 else randi()
	_apply(AsteroidBlueprint.generate(asteroid_def, used_seed, debug_show_chunks))

func _validate_settings() -> void:
	var problems: PackedStringArray = PackedStringArray()
	if mass_per_density <= 0.0:
		problems.append("mass_per_density %s -> 0.01" % mass_per_density)
		mass_per_density = 0.01
	if debris_max_speed < debris_min_speed:
		problems.append("debris_max_speed %s -> %s" % [debris_max_speed, debris_min_speed])
		debris_max_speed = debris_min_speed

	if not problems.is_empty():
		push_warning("%s: invalid asteroid settings (check for overrides saved in the scene), using defaults: %s"
			% [get_path() if is_inside_tree() else name, ", ".join(problems)])

func _apply(bp: AsteroidBlueprint) -> void:
	asteroid_def = bp.asteroid_def
	_used_seed = bp.used_seed
	_tint_offset = bp.tint_offset
	size = bp.size
	cells = bp.cells
	health = bp.health
	materials = bp.materials
	chunks = bp.chunks
	_painter = bp.painter
	_image = bp.image
	_origin = -Vector2(size) / 2.0

	_solid = bp.solid
	_mass_sum = bp.mass_sum
	_mass_moment = bp.mass_moment
	_mass_second_moment = bp.mass_second_moment
	_apply_mass_properties()

	_painted_step = PackedInt32Array()
	_painted_step.resize(chunks.hp.size())
	_painted_step.fill(-1)
	_pocket_triggered = PackedByteArray()
	_pocket_triggered.resize(chunks.pockets.size())

	_texture = ImageTexture.create_from_image(_image)
	_apply_collision(bp.collision_pieces)
	_collision_dirty = false
	queue_redraw()

func _build() -> void:
	_origin = -Vector2(size) / 2.0
	_solid = 0

	_mass_sum = 0.0
	_mass_moment = Vector2.ZERO
	_mass_second_moment = 0.0
	for i: int in cells.size():
		if cells[i] == 0:
			continue
		_add_cell_mass(i, 1.0)
		_solid += 1
	_apply_mass_properties()

	_painted_step = PackedInt32Array()
	_painted_step.resize(chunks.hp.size())
	_painted_step.fill(-1)

	_painter = AsteroidPainter.new(size, materials, _used_seed, _tint_offset)
	_painter.debug_chunks = debug_show_chunks
	_image = _painter.paint_all(cells, health, chunks.ids)
	_texture = ImageTexture.create_from_image(_image)

	_pocket_triggered = PackedByteArray()
	_pocket_triggered.resize(chunks.pockets.size())

	_rebuild_collision()
	queue_redraw()


func take_hit(world_point: Vector2, world_direction: Vector2, damage: float, radius: float = 0.0, falloff: float = 0.0) -> void:
	var center: int = _find_solid_cell(world_point, world_direction)
	if center == -1:
		return

	_damage_area(center % size.x, center / size.x, radius, damage, falloff, world_direction)

func _damage_area(cx: int, cy: int, radius: float, damage: float, falloff: float, world_direction: Vector2, blast_centre: Variant = null) -> void:
	var reach: int = ceili(radius)
	var hits: Dictionary[int, float] = {}
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var distance: float = sqrt(dx * dx + dy * dy)
			if distance > radius:
				continue

			var x: int = cx + dx
			var y: int = cy + dy
			if x < 0 or y < 0 or x >= size.x or y >= size.y:
				continue

			var i: int = y * size.x + x
			if cells[i] == 0:
				continue

			var edge_factor: float = distance / radius if radius > 0.0 else 0.0
			var chunk: int = chunks.ids[i]
			hits[chunk] = hits.get(chunk, 0.0) + damage * (1.0 - edge_factor * falloff)

	var broken: PackedInt32Array = PackedInt32Array()
	for chunk: int in hits:
		_add_chunk_damage(chunk, hits[chunk], broken)
		if damage_spread > 0.0:
			for neighbour: int in chunks.neighbours[chunk]:
				_add_chunk_damage(neighbour, hits[chunk] * damage_spread, broken)

	for chunk: int in broken:
		if blast_centre == null:
			_break_chunk(chunk, world_direction)
		else:
			var away: Vector2 = _chunk_centre(chunk) - (blast_centre as Vector2)
			# _spawn_debris pushes debris *against* the hit direction, so point the "hit" at the blast.
			_break_chunk(chunk, global_transform.basis_xform(-away).normalized(), blast_debris_speed)

func _chunk_centre(chunk: int) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	var members: PackedInt32Array = chunks.members[chunk]
	for i: int in members:
		sum += Vector2(i % size.x + 0.5, i / size.x + 0.5)
	return sum / maxf(members.size(), 1.0)

func _add_chunk_damage(chunk: int, amount: float, broken: PackedInt32Array) -> void:
	if not chunks.has_chunk(chunk) or broken.has(chunk):
		return

	chunks.damage[chunk] += amount
	var fraction: float = chunks.fraction(chunk)
	if fraction >= 1.0:
		broken.append(chunk)
		return

	var step: int = int(fraction * DAMAGE_PAINT_STEPS)
	if step != _painted_step[chunk]:
		_painted_step[chunk] = step
		for i: int in chunks.members[chunk]:
			health[i] = materials[cells[i] - 1].durability * (1.0 - fraction)
			_repaint(i)


func _break_chunk(chunk: int, world_direction: Vector2, speed_scale: float = 1.0) -> void:
	var indices: PackedInt32Array = chunks.members[chunk]
	if indices.is_empty():
		return

	var pocket: int = chunks.pocket_of[chunk]
	var rect: Rect2i = _bounds_of(indices)
	var local_center: Vector2 = _origin + Vector2(rect.position) + Vector2(rect.size) / 2.0

	if pocket == ChunkMap.EMPTY:
		var material_counts: Dictionary[StringName, int] = {}
		var debris_image: Image = Image.create_empty(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
		for i: int in indices:
			var x: int = i % size.x
			var y: int = i / size.x
			debris_image.set_pixel(x - rect.position.x, y - rect.position.y, _image.get_pixel(x, y))
			var material: StringName = materials[cells[i] - 1].id
			material_counts[material] = material_counts.get(material, 0) + 1
		_spawn_debris(debris_image, local_center, world_direction, material_counts, speed_scale)
		chunk_broken.emit(material_counts, to_global(local_center))

	chunks.forget(chunk)
	_islands_dirty = true
	_remove_cells(indices)

	if pocket != ChunkMap.EMPTY:
		_trigger_pocket(pocket, local_center - _origin)

func _trigger_pocket(p: int, fallback_centre: Vector2) -> void:
	if _pocket_triggered[p] == 1:
		return
	_pocket_triggered[p] = 1
	get_tree().create_timer(randf_range(0.05, 0.15), false).timeout.connect(
		_detonate_pocket.bind(p, fallback_centre))


func _detonate_pocket(p: int, fallback_centre: Vector2) -> void:
	# Centre of whatever gas is left. It all burns away in the blast.
	var sum: Vector2 = Vector2.ZERO
	var count: int = 0
	for chunk: int in chunks.pockets[p]:
		if not chunks.has_chunk(chunk):
			continue
		for i: int in chunks.members[chunk]:
			sum += Vector2(i % size.x + 0.5, i / size.x + 0.5)
			count += 1
		_break_chunk(chunk, Vector2.ZERO)
	var centre: Vector2 = sum / count if count > 0 else fallback_centre

	var material: MaterialDefinition = materials[chunks.pocket_material[p] - 1]
	var fuel: float = chunks.pocket_fuel[p]
	var radius: float = material.explosion_base_radius + material.explosion_radius * sqrt(fuel)
	_damage_area(floori(centre.x), floori(centre.y), radius, material.explosion_damage, material.explosion_falloff, Vector2.ZERO, centre)

	if is_inside_tree() and not is_queued_for_deletion():
		var gas_share: float = fuel / (fuel + _solid)
		var kick_speed: float = explosion_kick * sqrt(gas_share)
		var blast_local: Vector2 = _origin + centre
		var push: Vector2 = global_transform.basis_xform(center_of_mass - blast_local).normalized()
		apply_impulse(push * kick_speed * mass, global_transform.basis_xform(blast_local))

func _remove_cells(indices: PackedInt32Array) -> void:
	for i: int in indices:
		_add_cell_mass(i, -1.0)
		cells[i] = 0
		health[i] = 0.0
		_solid -= 1

	if _solid <= 0:
		queue_free()
		return

	_apply_mass_properties()

	_collision_dirty = true
	for i: int in indices:
		_repaint_with_neighbours(i)


func _spawn_debris(image: Image, local_center: Vector2, world_direction: Vector2, material_count: Dictionary[StringName, int], speed_scale: float = 1.0) -> void:
	var parent: Node = get_parent()
	if parent == null or Engine.is_editor_hint():
		return

	var outward: Vector2 = global_transform.basis_xform(local_center - center_of_mass).normalized()
	var direction: Vector2 = (outward - world_direction.normalized() * 0.6).normalized()
	var world_center: Vector2 = to_global(local_center)
	var velocity: Vector2 = _velocity_at(world_center) + direction.rotated(randf_range(-0.4, 0.4)) * randf_range(debris_min_speed, debris_max_speed) * speed_scale

	var debris: ChunkDebris = ChunkDebris.new()
	debris.setup(image, world_center, global_rotation, velocity, randf_range(-debris_max_spin, debris_max_spin), material_count)
	parent.add_child(debris)

func _split_islands() -> void:
	_islands_dirty = false

	var islands: Array[PackedInt32Array] = []  # chunk ids per island
	var island_cells: PackedInt32Array = PackedInt32Array()
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(chunks.hp.size())
	visited.fill(0)
	var queue: PackedInt32Array = PackedInt32Array()

	for start: int in chunks.hp.size():
		if visited[start] != 0 or not chunks.has_chunk(start):
			continue
		visited[start] = 1
		queue.clear()
		queue.append(start)
		var cell_count: int = 0
		var head: int = 0
		while head < queue.size():
			var chunk: int = queue[head]
			head += 1
			cell_count += chunks.members[chunk].size()
			for neighbour: int in chunks.neighbours[chunk]:
				if visited[neighbour] == 0 and chunks.has_chunk(neighbour):
					visited[neighbour] = 1
					queue.append(neighbour)
		islands.append(queue.duplicate())
		island_cells.append(cell_count)

	if islands.size() <= 1:
		return

	var largest: int = 0
	for island: int in range(1, islands.size()):
		if island_cells[island] > island_cells[largest]:
			largest = island

	for island: int in islands.size():
		if island == largest:
			continue
		if island_cells[island] < min_fragment_cells:
			for chunk: int in islands[island]:
				_break_chunk(chunk, Vector2.ZERO)
		else:
			var indices: PackedInt32Array = PackedInt32Array()
			for chunk: int in islands[island]:
				indices.append_array(chunks.members[chunk])
			_spawn_fragment(indices)


func _spawn_fragment(indices: PackedInt32Array) -> void:
	var rect: Rect2i = _bounds_of(indices)
	var fragment: Asteroid = _instantiate_sibling()

	var fragment_cells: PackedByteArray = PackedByteArray()
	fragment_cells.resize(rect.size.x * rect.size.y)
	var fragment_health: PackedFloat32Array = PackedFloat32Array()
	fragment_health.resize(rect.size.x * rect.size.y)
	for i: int in indices:
		var x: int = i % size.x - rect.position.x
		var y: int = i / size.x - rect.position.y
		var j: int = y * rect.size.x + x
		fragment_cells[j] = cells[i]
		fragment_health[j] = health[i]

	fragment.blueprint = AsteroidBlueprint.from_fragment(asteroid_def, _used_seed,
		_tint_offset + rect.position, rect.size, fragment_cells, fragment_health,
		materials, chunks.extract(rect, indices), debug_show_chunks)
	_copy_settings_to(fragment)

	var local_center: Vector2 = _origin + Vector2(rect.position) + Vector2(rect.size) / 2.0
	var world_center: Vector2 = to_global(local_center)
	var world_transform: Transform2D = Transform2D(global_rotation, world_center)
	var parent: Node = get_parent()
	if parent is Node2D:
		fragment.transform = (parent as Node2D).global_transform.affine_inverse() * world_transform
	else:
		fragment.transform = world_transform

	var away: Vector2 = (world_center - _global_center_of_mass()).normalized()
	fragment.linear_velocity = _velocity_at(world_center) + away * fragment_kick
	fragment.angular_velocity = angular_velocity + randf_range(-0.5, 0.5)

	for chunk: int in _chunks_in(indices):
		chunks.forget(chunk)
	_remove_cells(indices)

	parent.add_child(fragment)
	fragment_spawned.emit(fragment)

func _instantiate_sibling() -> Asteroid:
	if not scene_file_path.is_empty():
		var scene: PackedScene = load(scene_file_path) as PackedScene
		if scene != null:
			var node: Node = scene.instantiate()
			if node is Asteroid:
				return node
			node.free()

	return Asteroid.new()

func _copy_settings_to(fragment: Asteroid) -> void:
	fragment.collision_recalculation_interval = collision_recalculation_interval
	fragment.mass_per_density = mass_per_density
	fragment.damage_spread = damage_spread
	fragment.min_fragment_cells = min_fragment_cells
	fragment.fragment_kick = fragment_kick
	fragment.debris_min_speed = debris_min_speed
	fragment.debris_max_speed = debris_max_speed
	fragment.debris_max_spin = debris_max_spin
	fragment.debug_show_chunks = debug_show_chunks

	fragment.collision_layer = collision_layer
	fragment.collision_mask = collision_mask
	fragment.gravity_scale = gravity_scale
	fragment.linear_damp = linear_damp
	fragment.angular_damp = angular_damp
	fragment.physics_material_override = physics_material_override

	for connection: Dictionary in chunk_broken.get_connections():
		fragment.chunk_broken.connect(connection.callable, connection.flags)
	for connection: Dictionary in fragment_spawned.get_connections():
		fragment.fragment_spawned.connect(connection.callable, connection.flags)

func _add_cell_mass(i: int, weight: float) -> void:
	var density: float = materials[cells[i] - 1].density * weight
	var position_local: Vector2 = _origin + Vector2(i % size.x + 0.5, i / size.x + 0.5)
	_mass_sum += density
	_mass_moment += position_local * density
	_mass_second_moment += position_local.length_squared() * density

func _apply_mass_properties() -> void:
	if Engine.is_editor_hint() or _mass_sum <= 0.0:
		return

	var centre: Vector2 = _mass_moment / _mass_sum
	center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = centre
	mass = maxf(_mass_sum * mass_per_density, 0.1)
	# Parallel axis theorem: inertia about the centre, plus each 1x1 cell's own (m/6).
	var about_centre: float = _mass_second_moment - _mass_sum * centre.length_squared() + _mass_sum / 6.0
	inertia = maxf(about_centre * mass_per_density, 0.01)


func _global_center_of_mass() -> Vector2:
	return to_global(center_of_mass)

func _velocity_at(world_point: Vector2) -> Vector2:
	var r: Vector2 = world_point - _global_center_of_mass()
	return linear_velocity + Vector2(-r.y, r.x) * angular_velocity

func _chunks_in(indices: PackedInt32Array) -> PackedInt32Array:
	var found: Dictionary[int, bool] = {}
	for i: int in indices:
		var chunk: int = chunks.ids[i]
		if chunk != ChunkMap.EMPTY:
			found[chunk] = true
	return PackedInt32Array(found.keys())

func _bounds_of(indices: PackedInt32Array) -> Rect2i:
	var min_cell: Vector2i = size
	var max_cell: Vector2i = Vector2i(-1, -1)

	for i: int in indices:
		var cell: Vector2i = Vector2i(i % size.x, i / size.x)
		min_cell = min_cell.min(cell)
		max_cell = max_cell.max(cell)

	return Rect2i(min_cell, max_cell - min_cell + Vector2i.ONE)

func _draw() -> void:
	if _texture:
		draw_texture(_texture, _origin)

func _find_solid_cell(world_point: Vector2, world_direction: Vector2) -> int:
	var step: Vector2 = global_transform.basis_xform_inv(world_direction).normalized() * HIT_SEARCH_STEP
	var pos: Vector2 = to_local(world_point) - _origin - step * 2.0

	var travelled: float = 0.0
	while travelled <= HIT_SEARCH_DISTANCE:
		var x: int = floori(pos.x)
		var y: int = floori(pos.y)
		if x >= 0 and y >= 0 and x < size.x and y < size.y:
			var i: int = y * size.x + x
			if cells[i] != 0:
				return i
		pos += step
		travelled += HIT_SEARCH_STEP
	return -1

func _repaint_with_neighbours(i: int) -> void:
	_repaint(i)
	var x: int = i % size.x
	if x > 0:
		_repaint(i - 1)
	if x < size.x - 1:
		_repaint(i + 1)
	if i >= size.x:
		_repaint(i - size.x)
	if i < cells.size() - size.x:
		_repaint(i + size.x)

func _repaint(i: int) -> void:
	var x: int = i % size.x
	var y: int = i / size.x
	_image.set_pixel(x, y, _painter.colour_at(cells, health, chunks.ids, i, x, y))
	_texture_dirty = true

func _rebuild_collision() -> void:
	_collision_dirty = false
	_collision_interval = collision_recalculation_interval
	_apply_collision(collision_pieces_from(_image, size))

func _apply_collision(pieces: Array[PackedVector2Array]) -> void:
	if _shape_owner == -1:
		_shape_owner = create_shape_owner(self)
	shape_owner_set_transform(_shape_owner, Transform2D(0.0, _origin))
	shape_owner_clear_shapes(_shape_owner)
	for piece: PackedVector2Array in pieces:
		var convex: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
		convex.points = piece
		shape_owner_add_shape(_shape_owner, convex)

static func collision_pieces_from(image: Image, grid_size: Vector2i) -> Array[PackedVector2Array]:
	var bitmap: BitMap = BitMap.new()
	bitmap.create_from_image_alpha(image, 0.5)
	var pieces: Array[PackedVector2Array] = []
	for outline: PackedVector2Array in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, grid_size), 1.0):
		pieces.append_array(_convex_pieces(outline))
	return pieces
static func _convex_pieces(outline: PackedVector2Array) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = []
	var outline_clockwise: bool = Geometry2D.is_polygon_clockwise(outline)

	for cleaned: PackedVector2Array in Geometry2D.offset_polygon(outline, -COLLISION_CLEANUP_INSET, Geometry2D.JOIN_MITER):
		if cleaned.size() < 3 or Geometry2D.is_polygon_clockwise(cleaned) != outline_clockwise:
			continue

		pieces.append_array(Geometry2D.decompose_polygon_in_convex(cleaned))

	return pieces

func _process(_delta: float) -> void:
	if _texture_dirty:
		_texture.update(_image)
		_texture_dirty = false

func _physics_process(delta: float) -> void:
	if _islands_dirty and not Engine.is_editor_hint():
		_split_islands()

	_collision_interval -= delta
	if _collision_dirty and _collision_interval <= 0.0:
		_rebuild_collision()
