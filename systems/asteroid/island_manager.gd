class_name IslandManager extends RefCounted

var ids: PackedInt32Array
var sizes: PackedInt32Array


static func find(cells: PackedByteArray, size: Vector2i) -> IslandManager:
	var result: IslandManager = IslandManager.new()
	result.ids.resize(cells.size())
	result.sizes.append(0)

	var queue: PackedInt32Array = PackedInt32Array()

	for start: int in cells.size():
		if cells[start] == 0 or result.ids[start] != 0:
			continue

		# Flood-fill a new island starting from this cell.
		var label: int = result.sizes.size()
		result.sizes.append(0)
		queue.clear()
		queue.append(start)
		result.ids[start] = label

		var head: int = 0
		while head < queue.size():
			var i: int = queue[head]
			head += 1
			result.sizes[label] += 1

			var x: int = i % size.x
			if x > 0:
				_try_add(result, cells, queue, i - 1, label)
			if x < size.x - 1:
				_try_add(result, cells, queue, i + 1, label)
			if i >= size.x:
				_try_add(result, cells, queue, i - size.x, label)
			if i < cells.size() - size.x:
				_try_add(result, cells, queue, i + size.x, label)

	return result


static func _try_add(result: IslandManager, cells: PackedByteArray, queue: PackedInt32Array, i: int, label: int) -> void:
	if cells[i] != 0 and result.ids[i] == 0:
		result.ids[i] = label
		queue.append(i)


static func keep_largest(cells: PackedByteArray, size: Vector2i) -> PackedByteArray:
	var islands: IslandManager = find(cells, size)
	var best: int = 0
	for label: int in range(1, islands.sizes.size()):
		if islands.sizes[label] > islands.sizes[best]:
			best = label

	var result: PackedByteArray = cells.duplicate()
	for i: int in result.size():
		if islands.ids[i] != best:
			result[i] = 0
	return result
