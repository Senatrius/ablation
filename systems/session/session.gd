extends Node

signal storage_changed
signal upgrades_changed

const HUB_SCENE: String = "uid://d1w5n631p8hf2"
const GAME_SCENE: String = "uid://dkw67lh51fmdc"
const SALVAGE_ON_DEATH: float = 0.1
const UPGRADE_LIST: UpgradeList = preload("uid://des4yn4to01jg")

var cargo: Cargo = Cargo.new()
var storage: Dictionary[StringName, int] = {}
var run_active: bool = false
var upgrade_levels: Dictionary[StringName, int] = {}
var discovered: Dictionary[StringName, bool] = {}

func _ready() -> void:
	cargo.changed.connect(_note_discoveries)

func level_of(upgrade: UpgradeDefinition) -> int:
	return upgrade_levels.get(upgrade.id, 0)

func is_revealed(upgrade: UpgradeDefinition) -> bool:
	var next: UpgradeLevel = upgrade.next_level(level_of(upgrade))

	if next == null:
		return true

	for id: StringName in next.cost:
		if not discovered.has(id):
			return false

	return true


func requirements_met(upgrade: UpgradeDefinition) -> bool:
	for id: StringName in upgrade.requires:
		if upgrade_levels.get(id, 0) < upgrade.requires[id]:
			return false

	return true


func can_afford(cost: Dictionary[StringName, int]) -> bool:
	for id: StringName in cost:
		if storage.get(id, 0) < cost[id]:
			return false

	return true


func can_buy(upgrade: UpgradeDefinition) -> bool:
	var next: UpgradeLevel = upgrade.next_level(level_of(upgrade))
	return next != null and is_revealed(upgrade) and requirements_met(upgrade) and can_afford(next.cost)


func buy(upgrade: UpgradeDefinition) -> bool:
	if not can_buy(upgrade):
		return false

	var next: UpgradeLevel = upgrade.next_level(level_of(upgrade))

	for id: StringName in next.cost:
		storage[id] -= next.cost[id]

	upgrade_levels[upgrade.id] = level_of(upgrade) + 1
	storage_changed.emit()
	upgrades_changed.emit()
	return true


## `base` with every purchased upgrade applied.
func upgraded(base: ContentDefinition) -> ContentDefinition:
	return UPGRADE_LIST.upgraded(base, upgrade_levels)

func _note_discoveries() -> void:
	for id: StringName in cargo.contents():
		discovered[id] = true

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
