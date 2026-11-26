class_name Cargo extends RefCounted

signal changed

var capacity: int = 0
var used: int = 0

var _contents: Dictionary[StringName, int] = {}

func free_space() -> int:
	return maxi(capacity - used, 0)

func amount(id: StringName) -> int:
	return _contents.get(id, 0)

func contents() -> Dictionary[StringName, int]:
	return _contents.duplicate()

func add(items: Dictionary[StringName, int]) -> Dictionary[StringName, int]:
	var leftover: Dictionary[StringName, int] = {}
	var stored: bool = false

	for id: StringName in items:
		var take: int = mini(items[id], free_space())

		if take > 0:
			_contents[id] = _contents.get(id, 0) + take
			used += take
			stored = true

		if items[id] > take:
			leftover[id] = items[id] - take

	if stored:
		changed.emit()

	return leftover

func set_capacity(new_capacity: int) -> Dictionary[StringName, int]:
	capacity = maxi(new_capacity, 0)
	var spilled: Dictionary[StringName, int] = {}

	while used > capacity:
		var roll: int = randi_range(0, used - 1)
		var id: StringName = &""

		for candidate: StringName in _contents:
			roll -= _contents[candidate]

			if roll < 0:
				id = candidate
				break

		_contents[id] -= 1
		if _contents[id] == 0:
			_contents.erase(id)

		used -= 1
		spilled[id] = spilled.get(id, 0) + 1

	changed.emit()
	return spilled

func take_all() -> Dictionary[StringName, int]:
	var everything: Dictionary[StringName, int] = _contents

	_contents = {}
	used = 0

	changed.emit()
	return everything
