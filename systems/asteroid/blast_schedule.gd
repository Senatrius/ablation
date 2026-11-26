class_name BlastSchedule extends RefCounted

var _chunks: PackedInt32Array = PackedInt32Array()
var _times: PackedFloat32Array = PackedFloat32Array()
var _directions: PackedVector2Array = PackedVector2Array()

func add(chunk: int, time: float, direction: Vector2) -> void:
	_chunks.append(chunk)
	_times.append(time)
	_directions.append(direction)


func run_due(now: float, budget: int, breaker: Callable) -> void:
	var done: int = 0
	var n: int = 0

	while n < _chunks.size() and done < budget:
		if _times[n] > now:
			n += 1
			continue

		var chunk: int = _chunks[n]
		var direction: Vector2 = _directions[n]

		_chunks.remove_at(n)
		_times.remove_at(n)
		_directions.remove_at(n)

		if breaker.call(chunk, direction):
			done += 1
