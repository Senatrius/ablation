@tool
class_name Asteroid extends RigidBody2D

@export var asteroid_def: AsteroidDefinition
@export var gen_seed: int = 0
@export var collision_recalculation_interval: float = 0.1
@export var mass_per_density: float = 0.01

@export_tool_button("Generate")
var generate_button: Callable = generate

const HIT_SEARCH_DISTANCE: float = 6.0
const HIT_SEARCH_STEP: float = 0.5

var cells: PackedByteArray
var health: PackedFloat32Array
var size: Vector2i

var _painter: AsteroidPainter
var _image: Image
var _texture: ImageTexture
var _origin: Vector2
var _solid: int = 0
var _texture_dirty: bool = false
var _collision_dirty: bool = false
var _collision_interval: float = 0.0

func _ready() -> void:
	generate()

func generate() -> void:
	if asteroid_def == null:
		return

	var used_seed: int = gen_seed if gen_seed != 0 else randi()
	size = Vector2i(asteroid_def.width, asteroid_def.height)
	_origin = Vector2(size) / 2.0
	cells = AsteroidGenerator.new(asteroid_def).generate_cells(size, used_seed)
	health = PackedFloat32Array()
	health.resize(cells.size())
	_solid = 0

	var total_density: float = 0.0

	for i: int in cells.size():
		var id: int = cells[i]
		if id == 0:
			continue
		var material: MaterialDefinition = asteroid_def.materials[id - 1]
		health[i] = material.durability
		total_density += material.density
		_solid += 1

	mass = maxf(total_density * mass_per_density, 0.1)

	_painter = AsteroidPainter.new(size, asteroid_def.materials, used_seed)
	_image = _painter.paint_all(cells, health)
	_texture = ImageTexture.create_from_image(_image)

	_rebuild_collision()
	queue_redraw()

func take_hit(world_point: Vector2, world_direction: Vector2, damage: float) -> void:
	var i: int = _find_solid_cell(world_point, world_direction)
	if i == -1:
		return

	health[i] -= damage
	if health[i] <= 0.0:
		_destroy_cell(i)
	else:
		_repaint(i)

func _draw() -> void:
	if _texture:
		draw_texture(_texture, _origin)

func _find_solid_cell(world_point: Vector2, world_direction: Vector2) -> int:
	var step: Vector2 = global_transform.basis_xform_inv(world_direction).normalized() * HIT_SEARCH_STEP
	# Start a pixel early, in case the collision outline sits inside the visible rock.
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

func _destroy_cell(i: int) -> void:
	var material: MaterialDefinition = asteroid_def.materials[cells[i] - 1]
	mass = maxf(mass - material.density * mass_per_density, 0.1)

	cells[i] = 0
	health[i] = 0.0
	_solid -= 1

	if _solid <= 0:
		queue_free()
		return

	_collision_dirty = true
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
	@warning_ignore("integer_division")
	var y: int = i / size.x
	_image.set_pixel(x, y, _painter.colour_at(cells, health, i, x, y))
	_texture_dirty = true

func _rebuild_collision() -> void:
	_collision_dirty = false
	_collision_interval = collision_recalculation_interval

	for child: Node in get_children():
		if child is CollisionPolygon2D:
			child.queue_free()

	var bitmap: BitMap = BitMap.new()
	bitmap.create_from_image_alpha(_image, 0.5)
	for polygon: PackedVector2Array in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, size), 1.0):
		var shape: CollisionPolygon2D = CollisionPolygon2D.new()
		shape.build_mode = CollisionPolygon2D.BUILD_SOLIDS
		shape.polygon = polygon
		shape.position = _origin
		add_child(shape)
