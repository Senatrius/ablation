extends Node

const HUB_SCENE: String = "uid://d1w5n631p8hf2"
const GAME_SCENE: String = "uid://dkw67lh51fmdc"
const SALVAGE_ON_DEATH: float = 0.1

var cargo: Cargo = Cargo.new()
var storage: Dictionary[StringName, int] = {}
var run_active: bool = false

func start_run() -> void:
	cargo.take_all()
	run_active = true
	get_tree().change_scene_to_file(GAME_SCENE)

func end_run(returned: bool) -> void:
	if not run_active:
		return

	run_active = false
	var hold: Dictionary[StringName, int] = cargo.take_all()
	var share: float = 1.0 if returned else SALVAGE_ON_DEATH

	for id: StringName in hold:
		var kept: int = floori(hold[id] * share)

		if kept > 0:
			storage[id] = storage.get(id, 0) + kept

	get_tree().change_scene_to_file(HUB_SCENE)

func storage_total() -> int:
	var total: int = 0

	for id: StringName in storage:
		total += storage[id]

	return total
