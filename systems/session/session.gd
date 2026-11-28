extends Node

signal storage_changed
signal upgrades_changed

const SAVE_PATH: String = "user://save_files/save.json"
const SAVE_VERSION: int = 1
const HUB_SCENE: String = "uid://d1w5n631p8hf2"
const GAME_SCENE: String = "uid://dkw67lh51fmdc"
const SALVAGE_ON_DEATH: float = 0.1
const UPGRADE_LIST: UpgradeList = preload("uid://des4yn4to01jg")

var cargo: Cargo = Cargo.new()
var storage: Dictionary[StringName, int] = {}
var run_active: bool = false
var upgrade_levels: Dictionary[StringName, int] = {}
var discovered: Dictionary[StringName, bool] = {}
var known_resources: Array[StringName] = []

func _ready() -> void:
	cargo.changed.connect(_note_discoveries)

	for resource: Resource in ContentLibrary.load_all("res://data/materials"):
		if resource is MaterialDefinition:
			var id: StringName = resource.yields if resource.yields != &"" else resource.id

			if not known_resources.has(id):
				known_resources.append(id)

	if OS.is_debug_build():
		_validate_content()

	_load_game()

func level_of(upgrade: UpgradeDefinition) -> int:
	return upgrade_levels.get(upgrade.id, 0)

func is_revealed(upgrade: UpgradeDefinition) -> bool:
	var next: UpgradeLevel = upgrade.next_level(level_of(upgrade))

	if next == null:
		return true

	for id: StringName in next.cost_grams():
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
	return next != null and is_revealed(upgrade) and requirements_met(upgrade) and can_afford(next.cost_grams())

func buy(upgrade: UpgradeDefinition) -> bool:
	if not can_buy(upgrade):
		return false

	var next: UpgradeLevel = upgrade.next_level(level_of(upgrade))

	for id: StringName in next.cost_grams():
		storage[id] -= next.cost_grams()[id]

	upgrade_levels[upgrade.id] = level_of(upgrade) + 1
	storage_changed.emit()
	upgrades_changed.emit()

	save_game()
	return true

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

	save_game()

	get_tree().change_scene_to_file(HUB_SCENE)

func storage_total() -> int:
	var total: int = 0

	for id: StringName in storage:
		total += storage[id]

	return total

func _validate_content() -> void:
	var targets: Dictionary[StringName, ContentDefinition] = {}

	for resource: Resource in ContentLibrary.load_all("res://data/weapons"):
		if resource is ContentDefinition:
			targets[resource.id] = resource

	for problem: String in UPGRADE_LIST.validate(known_resources, targets):
		push_error(problem)

func refund_upgrades() -> void:
	for upgrade: UpgradeDefinition in UPGRADE_LIST.upgrades:
		var owned: int = mini(level_of(upgrade), upgrade.max_level())

		for n: int in owned:
			var cost: Dictionary[StringName, int] = upgrade.levels[n].cost_grams()

			for id: StringName in cost:
				storage[id] = storage.get(id, 0) + cost[id]

	upgrade_levels.clear()
	storage_changed.emit()
	upgrades_changed.emit()

	save_game()

func debug_grant(amount: int) -> void:
	for id: StringName in known_resources:
		storage[id] = storage.get(id, 0) + amount
		discovered[id] = true

	storage_changed.emit()

	save_game()

func save_game() -> void:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"storage": _string_keys(storage),
		"upgrades": _string_keys(upgrade_levels),
		"discovered": discovered.keys().map(func(id: StringName) -> String: return String(id)),
	}

	var version: int = int(data.get("version", 0))

	if version > SAVE_VERSION:
		push_error("This save is from a newer version of the game (format %d); not loading it." % version)
		return

	var folder: String = SAVE_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(folder):
		var folder_error: Error = DirAccess.make_dir_recursive_absolute(folder)

		if folder_error != OK:
			push_error("Couldn't create the save folder %s: %s" % [folder, error_string(folder_error)])
			return

	var temp_path: String = SAVE_PATH + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)

	if file == null:
		push_error("Couldn't write the save: %s" % error_string(FileAccess.get_open_error()))
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	var error: Error = DirAccess.rename_absolute(temp_path, SAVE_PATH)
	if error != OK:
		push_error("Couldn't replace the save: %s" % error_string(error))

func wipe_save() -> void:
	storage.clear()
	upgrade_levels.clear()
	discovered.clear()
	DirAccess.remove_absolute(SAVE_PATH)

	storage_changed.emit()
	upgrades_changed.emit()


func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))

	if not parsed is Dictionary:
		DirAccess.rename_absolute(SAVE_PATH, SAVE_PATH + ".broken")
		push_error("The save file was unreadable; it was kept as save.json.broken and a new game started.")
		return

	var data: Dictionary = parsed
	var version: int = int(data.get("version", 0))
	var storage_scale: int = Mass.GRAMS_PER_KG if version < 2 else 1

	if version > SAVE_VERSION:
		push_error("This save is from a newer version of the game (format %d); not loading it." % version)
		return

	var saved_storage: Dictionary = data.get("storage", {})
	for key: String in saved_storage:
		var id: StringName = StringName(key)

		if not known_resources.has(id):
			push_warning("Save has unknown resource '%s'; dropped." % key)
			continue

		storage[id] = int(saved_storage[key]) * storage_scale

	var saved_upgrades: Dictionary = data.get("upgrades", {})
	for key: String in saved_upgrades:
		var upgrade: UpgradeDefinition = UPGRADE_LIST.find(StringName(key))

		if upgrade == null:
			push_warning("Save has unknown upgrade '%s'; dropped." % key)
			continue

		upgrade_levels[upgrade.id] = clampi(int(saved_upgrades[key]), 0, upgrade.max_level())

	for key: Variant in data.get("discovered", []):
		discovered[StringName(str(key))] = true

static func _string_keys(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}

	for key: Variant in source:
		result[String(key)] = source[key]

	return result
