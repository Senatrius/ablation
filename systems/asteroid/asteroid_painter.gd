class_name AsteroidPainter extends RefCounted

const DAMAGE_TINT: float = 0.25
const EDGE_TINT: float = 0.1

var _size: Vector2i
var _palettes: Array[PackedColorArray] = []
var _durabilities: PackedFloat32Array = PackedFloat32Array()
var _tint: PackedByteArray

func _init(size: Vector2i, materials: Array[MaterialDefinition], paint_seed: int) -> void:
	_size = size

	for material: MaterialDefinition in materials:
		_palettes.append(material.colours)
		_durabilities.append(maxf(material.durability, 0.001))

	var tint: FastNoiseLite = FastNoiseLite.new()
	tint.seed = paint_seed
	tint.frequency = 0.15
	_tint = tint.get_image(size.x, size.y, false, false, false).get_data()

func paint_all(cells: PackedByteArray, health: PackedFloat32Array) -> Image:
	var rgba: PackedByteArray = PackedByteArray()
	rgba.resize(_size.x * _size.y * 4)

	for y: int in _size.y:
		for x: int in _size.x:
			var i: int = y * _size.x + x
			if cells[i] == 0:
				continue
			var colour: Color = colour_at(cells, health, i, x, y)
			var o: int = i * 4
			rgba[o] = colour.r8
			rgba[o + 1] = colour.g8
			rgba[o + 2] = colour.b8
			rgba[o + 3] = 255

	return Image.create_from_data(_size.x, _size.y, false, Image.FORMAT_RGBA8, rgba)

func colour_at(cells: PackedByteArray, health: PackedFloat32Array, i: int, x: int, y: int) -> Color:
	var id: int = cells[i]
	if id == 0:
		return Color.TRANSPARENT

	var palette: PackedColorArray = _palettes[id - 1]
	var t: float = _tint[i] / 255.0
	var colour: Color = palette[mini(int(t * palette.size()), palette.size() - 1)]

	var damage: float = 1.0 - health[i] / _durabilities[id - 1]
	colour = colour.darkened(damage * DAMAGE_TINT)

	if _is_edge(cells, i, x, y):
		colour = colour.darkened(EDGE_TINT)

	return colour

func _is_edge(cells: PackedByteArray, i: int, x: int, y: int) -> bool:
	if x == 0 or y == 0 or x == _size.x - 1 or y == _size.y - 1:
		return true
	return cells[i - 1] == 0 or cells[i + 1] == 0 or cells[i - _size.x] == 0 or cells[i + _size.x] == 0
