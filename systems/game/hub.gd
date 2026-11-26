extends Control

@onready var storage_label: Label = %StorageLabel
@onready var play_button: Button = %PlayButton

func _ready() -> void:
	play_button.pressed.connect(Session.start_run)
	play_button.grab_focus()
	storage_label.text = _storage_text()


func _storage_text() -> String:
	var lines: PackedStringArray = PackedStringArray(["Total: %s Kg" % HUD.format_kg(Session.storage_total())])

	for id: StringName in Session.storage:
		lines.append("  %s: %s Kg" % [id, HUD.format_kg(Session.storage[id])])

	return "\n".join(lines)
