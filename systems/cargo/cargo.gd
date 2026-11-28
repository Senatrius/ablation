class_name Cargo extends RefCounted
@warning_ignore_start("integer_division")

signal changed

var capacity: int = 0
var used: int = 0

var _contents: Dictionary[StringName, int] = {}

func free_space() -> int:
	return maxi(capacity - used, 0)

func _amount(id: StringName) -> int:
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
	var excess: int = used - capacity

	if excess > 0 and used > 0:
		var to_spill: int = excess

		for id: StringName in _contents.keys():
			var lost: int = mini(excess * _contents[id] / used, _contents[id])
			_remove(id, lost, spilled)
			to_spill -= lost

		while to_spill > 0 and not _contents.is_empty():
			var largest: StringName = _contents.keys()[0]

			for id: StringName in _contents:
				if _contents[id] > _contents[largest]:
					largest = id

			var lost: int = mini(to_spill, _contents[largest])

			_remove(largest, lost, spilled)
			to_spill -= lost

	changed.emit()
	return spilled

func _remove(id: StringName, amount: int, spilled: Dictionary[StringName, int]) -> void:
	if amount <= 0:
		return

	_contents[id] -= amount
	used -= amount
	spilled[id] = spilled.get(id, 0) + amount

	if _contents[id] <= 0:
		_contents.erase(id)

func take_all() -> Dictionary[StringName, int]:
	var everything: Dictionary[StringName, int] = _contents

	_contents = {}
	used = 0

	changed.emit()
	return everything
