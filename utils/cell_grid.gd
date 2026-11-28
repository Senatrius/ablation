class_name CellGrid extends RefCounted

static func coords(i: int, width: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(i % width, i / width)

static func centre(i: int, width: int) -> Vector2:
	return Vector2(coords(i, width)) + Vector2(0.5, 0.5)

static func average_centre(indices: PackedInt32Array, width: int) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	for i: int in indices:
		sum += centre(i, width)
	return sum / maxf(indices.size(), 1.0)

static func bounds(indices: PackedInt32Array, width: int) -> Rect2i:
	var min_cell: Vector2i = Vector2i(1 << 30, 1 << 30)
	var max_cell: Vector2i = Vector2i(-1, -1)

	for i: int in indices:
		var cell: Vector2i = coords(i, width)
		min_cell = min_cell.min(cell)
		max_cell = max_cell.max(cell)

	return Rect2i(min_cell, max_cell - min_cell + Vector2i.ONE)

static func crop_bytes(source: PackedByteArray, width: int, indices: PackedInt32Array, rect: Rect2i) -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(rect.size.x * rect.size.y)

	for i: int in indices:
		var cell: Vector2i = coords(i, width) - rect.position
		result[cell.y * rect.size.x + cell.x] = source[i]

	return result

static func crop_floats(source: PackedFloat32Array, width: int, indices: PackedInt32Array, rect: Rect2i) -> PackedFloat32Array:
	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(rect.size.x * rect.size.y)

	for i: int in indices:
		var cell: Vector2i = coords(i, width) - rect.position
		result[cell.y * rect.size.x + cell.x] = source[i]

	return result
