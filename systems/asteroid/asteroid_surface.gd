class_name AsteroidSurface extends RefCounted

const DAMAGE_PAINT_STEPS: int = 12

var image: Image
var texture: ImageTexture

var _painter: AsteroidPainter
var _queue: PackedInt32Array = PackedInt32Array()
var _queued: PackedByteArray = PackedByteArray()
var _painted_step: PackedInt32Array = PackedInt32Array()
var _dirty: bool = false

func _init(painter: AsteroidPainter, painted: Image, cell_count: int, chunk_count: int) -> void:
	_painter = painter
	image = painted
	texture = ImageTexture.create_from_image(image)
	_queued.resize(cell_count)
	_painted_step.resize(chunk_count)
	_painted_step.fill(-1)

func mark(i: int) -> void:
	if _queued[i] == 1:
		return
	_queued[i] = 1
	_queue.append(i)

func mark_with_neighbours(i: int, size: Vector2i) -> void:
	mark(i)
	var x: int = i % size.x

	if x > 0:
		mark(i - 1)
	if x < size.x - 1:
		mark(i + 1)
	if i >= size.x:
		mark(i - size.x)
	if i < _queued.size() - size.x:
		mark(i + size.x)

func enter_damage_step(chunk: int, fraction: float) -> bool:
	var step: int = int(fraction * DAMAGE_PAINT_STEPS)

	if step == _painted_step[chunk]:
		return false

	_painted_step[chunk] = step

	return true

func flush(cells: PackedByteArray, health: PackedFloat32Array, chunk_ids: PackedInt32Array, width: int) -> void:
	if _queue.is_empty():
		return

	for i: int in _queue:
		_queued[i] = 0
		var cell: Vector2i = CellGrid.coords(i, width)
		image.set_pixel(cell.x, cell.y, _painter.colour_at(cells, health, chunk_ids, i, cell.x, cell.y))

	_queue.clear()
	_dirty = true

func upload() -> void:
	if _dirty:
		texture.update(image)
		_dirty = false
