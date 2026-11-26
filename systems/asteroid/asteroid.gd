class_name Asteroid extends RigidBody2D
@warning_ignore_start("integer_division")

## - AsteroidBlueprint builds everything up front (on a worker thread when spawned by the field).
## - AsteroidSurface owns the image, texture and batched repaints.
## - AsteroidMass keeps mass, centre of mass and inertia up to date as cells are removed.
## - BlastSchedule spreads a blast's breaks over a few frames.
## - ChunkMap knows how chunks connect, which ones are pockets, and which islands exist.

signal chunk_broken(contents: Dictionary[StringName, int], world_position: Vector2)
signal fragment_spawned(fragment: Asteroid)

const HIT_SEARCH_DISTANCE: float = 6.0
const HIT_SEARCH_STEP: float = 0.5
const BLAST_WAVE_SPEED: float = 150.0
const MAX_BREAKS_PER_FRAME: int = 5
const COLLISION_CLEANUP_INSET: float = 0.01

@export var asteroid_def: AsteroidDefinition
@export var gen_seed: int = 0
@export var debug_show_chunks: bool = false

var blueprint: AsteroidBlueprint

var cells: PackedByteArray
var health: PackedFloat32Array
var size: Vector2i
var chunks: ChunkMap
var materials: Array[MaterialDefinition] = []

var _surface: AsteroidSurface
var _mass: AsteroidMass
var _blasts: BlastSchedule = BlastSchedule.new()
var _origin: Vector2
var _used_seed: int = 0
var _tint_offset: Vector2i = Vector2i.ZERO
var _pocket_triggered: PackedByteArray
var _shape_owner: int = -1
var _clock: float = 0.0
var _collision_cooldown: float = 0.0
var _collision_dirty: bool = false
var _islands_dirty: bool = false
var _mass_dirty: bool = false

func _ready() -> void:
	if blueprint != null:
		_apply(blueprint)
		blueprint = null
	else:
		generate()

func generate() -> void:
	if asteroid_def == null:
		return
	var used_seed: int = gen_seed if gen_seed != 0 else randi()
	_apply(AsteroidBlueprint.generate(asteroid_def, used_seed, debug_show_chunks))

func _apply(bp: AsteroidBlueprint) -> void:
	asteroid_def = bp.asteroid_def
	_used_seed = bp.used_seed
	_tint_offset = bp.tint_offset
	size = bp.size
	cells = bp.cells
	health = bp.health
	materials = bp.materials
	chunks = bp.chunks
	_mass = bp.mass
	_origin = -Vector2(size) / 2.0

	_surface = AsteroidSurface.new(bp.painter, bp.image, cells.size(), chunks.hp.size())
	_pocket_triggered = PackedByteArray()
	_pocket_triggered.resize(chunks.pockets.size())

	_apply_mass_properties()
	_apply_collision(bp.collision_pieces)
	queue_redraw()

func _process(_delta: float) -> void:
	if _surface == null:
		return
	_surface.flush(cells, health, chunks.ids, size.x)
	_surface.upload()

func _physics_process(delta: float) -> void:
	if _surface == null:
		return

	_clock += delta
	_blasts.run_due(_clock, MAX_BREAKS_PER_FRAME, _break_scheduled)

	if _islands_dirty:
		_split_islands()

	if _mass_dirty:
		_mass_dirty = false
		_apply_mass_properties()

	_collision_cooldown -= delta
	if _collision_dirty and _collision_cooldown <= 0.0:
		_rebuild_collision()

func _draw() -> void:
	if _surface != null:
		draw_texture(_surface.texture, _origin)

func take_hit(world_point: Vector2, world_direction: Vector2, damage: float, radius: float = 0.0, falloff: float = 0.0) -> void:
	var centre: int = _find_solid_cell(world_point, world_direction)

	if centre == -1:
		return

	var cell: Vector2i = CellGrid.coords(centre, size.x)
	_damage_area(cell.x, cell.y, radius, damage, falloff, world_direction)

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
	var spread: float = asteroid_def.damage_spread

	for chunk: int in hits:
		_add_chunk_damage(chunk, hits[chunk], broken)

		if spread > 0.0:
			for neighbour: int in chunks.neighbours[chunk]:
				_add_chunk_damage(neighbour, hits[chunk] * spread, broken)

	for chunk: int in broken:
		if blast_centre == null:
			_break_chunk(chunk, world_direction)
		else:
			var away: Vector2 = CellGrid.average_centre(chunks.members[chunk], size.x) - (blast_centre as Vector2)
			_blasts.add(chunk, _clock + away.length() / BLAST_WAVE_SPEED,
				global_transform.basis_xform(-away).normalized())

func _add_chunk_damage(chunk: int, amount: float, broken: PackedInt32Array) -> void:
	if not chunks.has_chunk(chunk) or broken.has(chunk):
		return

	chunks.damage[chunk] += amount
	var fraction: float = chunks.fraction(chunk)

	if fraction >= 1.0:
		broken.append(chunk)
		return

	if _surface.enter_damage_step(chunk, fraction):
		for i: int in chunks.members[chunk]:
			health[i] = materials[cells[i] - 1].durability * (1.0 - fraction)
			_surface.mark(i)


func _break_scheduled(chunk: int, direction: Vector2) -> bool:
	if not chunks.has_chunk(chunk):
		return false

	_break_chunk(chunk, direction, asteroid_def.blast_debris_speed)
	return true

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

func _break_chunk(chunk: int, world_direction: Vector2, speed_scale: float = 1.0) -> void:
	var indices: PackedInt32Array = chunks.members[chunk]
	if indices.is_empty():
		return

	var pocket: int = chunks.pocket_of[chunk]
	var rect: Rect2i = CellGrid.bounds(indices, size.x)
	var local_centre: Vector2 = _origin + Vector2(rect.position) + Vector2(rect.size) / 2.0

	if pocket == ChunkMap.EMPTY:
		var contents: Dictionary[StringName, int] = _contents_of(indices)
		_spawn_debris(_debris_image(indices, rect), local_centre, world_direction, contents, speed_scale)
		chunk_broken.emit(contents, to_global(local_centre))

	chunks.forget(chunk)
	_remove_cells(indices)

	if pocket != ChunkMap.EMPTY:
		_trigger_pocket(pocket, local_centre - _origin)


func _remove_cells(indices: PackedInt32Array) -> void:
	for i: int in indices:
		_mass.change_cell(i, materials[cells[i] - 1].density, size.x, _origin, -1)
		cells[i] = 0
		health[i] = 0.0

	if _mass.solid_cells <= 0:
		queue_free()
		return

	_mass_dirty = true
	_collision_dirty = true
	_islands_dirty = true

	for i: int in indices:
		_surface.mark_with_neighbours(i, size)

func _contents_of(indices: PackedInt32Array) -> Dictionary[StringName, int]:
	var contents: Dictionary[StringName, int] = {}
	for i: int in indices:
		var id: StringName = materials[cells[i] - 1].id
		contents[id] = contents.get(id, 0) + 1
	return contents

func _debris_image(indices: PackedInt32Array, rect: Rect2i) -> Image:
	var image: Image = Image.create_empty(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)

	for i: int in indices:
		var cell: Vector2i = CellGrid.coords(i, size.x)
		image.set_pixel(cell.x - rect.position.x, cell.y - rect.position.y, _surface.image.get_pixel(cell.x, cell.y))

	return image

func _spawn_debris(image: Image, local_centre: Vector2, world_direction: Vector2, contents: Dictionary[StringName, int], speed_scale: float = 1.0) -> void:
	var parent: Node = get_parent()

	if parent == null:
		return

	var outward: Vector2 = global_transform.basis_xform(local_centre - center_of_mass).normalized()
	var direction: Vector2 = (outward - world_direction.normalized() * 0.6).normalized()
	var world_centre: Vector2 = to_global(local_centre)
	var speed: float = randf_range(asteroid_def.debris_min_speed, asteroid_def.debris_max_speed) * speed_scale
	var velocity: Vector2 = _velocity_at(world_centre) + direction.rotated(randf_range(-0.4, 0.4)) * speed
	var spin: float = randf_range(-asteroid_def.debris_max_spin, asteroid_def.debris_max_spin)
	var debris: ChunkDebris = ChunkDebris.new()

	debris.setup(image, world_centre, global_rotation, velocity, spin, contents)
	parent.add_child(debris)

func _trigger_pocket(p: int, fallback_centre: Vector2) -> void:
	if _pocket_triggered[p] == 1:
		return

	_pocket_triggered[p] = 1

	get_tree().create_timer(randf_range(0.05, 0.15), false).timeout.connect(_detonate_pocket.bind(p, fallback_centre))

func _detonate_pocket(p: int, fallback_centre: Vector2) -> void:
	var remaining: PackedInt32Array = PackedInt32Array()

	for chunk: int in chunks.pockets[p]:
		if chunks.has_chunk(chunk):
			remaining.append_array(chunks.members[chunk])

	var centre: Vector2 = CellGrid.average_centre(remaining, size.x) if not remaining.is_empty() else fallback_centre

	for chunk: int in chunks.pockets[p]:
		if chunks.has_chunk(chunk):
			_break_chunk(chunk, Vector2.ZERO)

	var gas: MaterialDefinition = materials[chunks.pocket_material[p] - 1]
	var fuel: float = chunks.pocket_fuel[p]
	var gas_share: float = fuel / (fuel + _mass.solid_cells)
	var radius: float = gas.explosion_base_radius + gas.explosion_radius * sqrt(fuel)

	_damage_area(floori(centre.x), floori(centre.y), radius, gas.explosion_damage, gas.explosion_falloff, Vector2.ZERO, centre)

	if is_inside_tree() and not is_queued_for_deletion():
		var kick_speed: float = asteroid_def.explosion_kick * sqrt(gas_share)
		var blast_local: Vector2 = _origin + centre
		var push: Vector2 = global_transform.basis_xform(center_of_mass - blast_local).normalized()

		apply_impulse(push * kick_speed * mass, global_transform.basis_xform(blast_local))

func _split_islands() -> void:
	_islands_dirty = false

	var islands: Array[PackedInt32Array] = chunks.find_islands()
	if islands.size() <= 1:
		return

	var island_cells: PackedInt32Array = PackedInt32Array()
	var largest: int = 0

	for n: int in islands.size():
		island_cells.append(chunks.cell_count(islands[n]))
		if island_cells[n] > island_cells[largest]:
			largest = n

	for n: int in islands.size():
		if n == largest:
			continue

		if island_cells[n] < asteroid_def.min_fragment_cells:
			for chunk: int in islands[n]:
				_break_chunk(chunk, Vector2.ZERO)
		else:
			_spawn_fragment(islands[n])

func _spawn_fragment(island: PackedInt32Array) -> void:
	var indices: PackedInt32Array = chunks.cells_of(island)
	var bp: AsteroidBlueprint = AsteroidBlueprint.from_fragment(asteroid_def, _used_seed, _tint_offset, size, cells, health, materials, chunks, indices, debug_show_chunks)

	var fragment: Asteroid = _instantiate_sibling()
	fragment.blueprint = bp
	fragment.debug_show_chunks = debug_show_chunks
	_copy_signals_to(fragment)

	var rect: Rect2i = bp.source_rect
	var local_centre: Vector2 = _origin + Vector2(rect.position) + Vector2(rect.size) / 2.0
	var world_centre: Vector2 = to_global(local_centre)
	var parent: Node = get_parent()
	var world_transform: Transform2D = Transform2D(global_rotation, world_centre)

	if parent is Node2D:
		fragment.transform = (parent as Node2D).global_transform.affine_inverse() * world_transform
	else:
		fragment.transform = world_transform

	var away: Vector2 = (world_centre - _global_center_of_mass()).normalized()
	fragment.linear_velocity = _velocity_at(world_centre) + away * asteroid_def.fragment_kick
	fragment.angular_velocity = angular_velocity + randf_range(-0.5, 0.5)

	for chunk: int in island:
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

	var fallback: Asteroid = Asteroid.new()
	fallback.collision_layer = collision_layer
	fallback.collision_mask = collision_mask
	fallback.gravity_scale = gravity_scale

	return fallback

func _copy_signals_to(fragment: Asteroid) -> void:
	for connection: Dictionary in chunk_broken.get_connections():
		fragment.chunk_broken.connect(connection.callable, connection.flags)
	for connection: Dictionary in fragment_spawned.get_connections():
		fragment.fragment_spawned.connect(connection.callable, connection.flags)

func _apply_mass_properties() -> void:
	if _mass.total <= 0.0:
		return

	center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = _mass.centre()
	mass = maxf(_mass.total * asteroid_def.mass_per_density, 0.1)
	inertia = maxf(_mass.inertia() * asteroid_def.mass_per_density, 0.01)

func _global_center_of_mass() -> Vector2:
	return to_global(center_of_mass)

func _velocity_at(world_point: Vector2) -> Vector2:
	var r: Vector2 = world_point - _global_center_of_mass()
	return linear_velocity + Vector2(-r.y, r.x) * angular_velocity

func _rebuild_collision() -> void:
	_surface.flush(cells, health, chunks.ids, size.x)
	_collision_dirty = false
	_collision_cooldown = asteroid_def.collision_rebuild_interval

	_apply_collision(collision_pieces_from(_surface.image, size))

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
	var pieces: Array[PackedVector2Array] = []

	bitmap.create_from_image_alpha(image, 0.5)

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
