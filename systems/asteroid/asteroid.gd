@tool
class_name Asteroid extends Node2D

@onready var sprite_2d: Sprite2D = $Sprite2D

@export var asteroid_def: AsteroidDefinition
@export var gen_seed: int = 0

@export_tool_button("Generate")
var generate_button: Callable = generate

var cells: PackedByteArray
var size: Vector2i

var _texture: ImageTexture


func _ready() -> void:
	generate()


func generate() -> void:
	var start: int = Time.get_ticks_usec()
	if asteroid_def == null:
		return

	var used_seed: int = gen_seed if gen_seed != 0 else randi()
	size = Vector2i(asteroid_def.width, asteroid_def.height)
	cells = AsteroidGenerator.new(asteroid_def).generate_cells(size, used_seed)

	var image: Image = AsteroidPainter.paint(cells, size, asteroid_def.materials, used_seed)
	_texture = ImageTexture.create_from_image(image)
	queue_redraw()
	print("asteroid generated in %.1f ms" % ((Time.get_ticks_usec() - start) / 1000.0))


func _draw() -> void:
	if _texture:
		draw_texture(_texture, -Vector2(size) / 2.0)
