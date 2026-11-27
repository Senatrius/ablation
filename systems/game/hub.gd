extends Control

@onready var storage_label: Label = %StorageLabel
@onready var upgrade_rows: VBoxContainer = %UpgradeRows
@onready var play_button: Button = %PlayButton
@onready var refund_button: Button = %RefundButton
@onready var grant_button: Button = %GrantButton
@onready var delete_save_button: Button = %DeleteSaveButton

var _refresh_queued: bool = false

func _ready() -> void:
	play_button.pressed.connect(Session.start_run)
	refund_button.pressed.connect(Session.refund_upgrades)
	grant_button.pressed.connect(Session.debug_grant.bind(10000))
	grant_button.visible = OS.is_debug_build()

	Session.storage_changed.connect(_queue_refresh)
	Session.upgrades_changed.connect(_queue_refresh)

	play_button.grab_focus()

	delete_save_button.pressed.connect(Session.wipe_save)
	delete_save_button.visible = OS.is_debug_build()

	_refresh()

func _queue_refresh() -> void:
	if _refresh_queued:
		return

	_refresh_queued = true
	_refresh.call_deferred()

func _refresh() -> void:
	_refresh_queued = false
	storage_label.text = _storage_text()

	for child: Node in upgrade_rows.get_children():
		upgrade_rows.remove_child(child)
		child.queue_free()

	for upgrade: UpgradeDefinition in Session.UPGRADE_LIST.upgrades:
		if Session.level_of(upgrade) == 0 and not Session.is_revealed(upgrade):
			continue

		upgrade_rows.add_child(_make_row(upgrade))

func _make_row(upgrade: UpgradeDefinition) -> Control:
	var level: int = Session.level_of(upgrade)
	var next: UpgradeLevel = upgrade.next_level(level)

	var row: HBoxContainer = HBoxContainer.new()
	var info: Label = Label.new()
	info.custom_minimum_size.x = 320
	var button: Button = Button.new()
	button.custom_minimum_size.x = 80

	var lines: PackedStringArray = PackedStringArray(["%s  [%d / %d]" % [upgrade.display_name, level, upgrade.max_level()]])

	if next == null:
		button.text = "Maxed"
		button.disabled = true
	elif not Session.is_revealed(upgrade):
		lines.append("Next: ??? (needs a material you haven't found)")
		button.text = "Locked"
		button.disabled = true
	elif not Session.requirements_met(upgrade):
		lines.append("Requires: %s" % _requirements_text(upgrade))
		button.text = "Locked"
		button.disabled = true
	else:
		lines.append(next.description)
		lines.append("Cost: %s" % _cost_text(next.cost))
		button.text = "Buy"
		button.disabled = not Session.can_afford(next.cost)
		button.pressed.connect(Session.buy.bind(upgrade))

	info.text = "\n".join(lines)
	row.add_child(info)
	row.add_child(button)
	return row

func _cost_text(cost: Dictionary[StringName, int]) -> String:
	var parts: PackedStringArray = PackedStringArray()

	for id: StringName in cost:
		parts.append("%s %s kg" % [id, HUD.format_kg(cost[id])])

	return ", ".join(parts)

func _requirements_text(upgrade: UpgradeDefinition) -> String:
	var parts: PackedStringArray = PackedStringArray()

	for id: StringName in upgrade.requires:
		parts.append("%s level %d" % [id, upgrade.requires[id]])

	return ", ".join(parts)

func _storage_text() -> String:
	var lines: PackedStringArray = PackedStringArray(["Total: %s kg" % HUD.format_kg(Session.storage_total())])

	for id: StringName in Session.storage:
		lines.append("  %s: %s kg" % [id, HUD.format_kg(Session.storage[id])])

	return "\n".join(lines)
