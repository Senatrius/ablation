class_name HUD extends CanvasLayer

@onready var cargo_label: Label = $CargoLabel
@onready var return_label: Label = $ReturnLabel
@onready var distance_label: Label = $DistanceLabel

func _ready() -> void:
	Session.cargo.changed.connect(_refresh)
	_refresh()
	return_label.hide()

func show_return_progress(ratio: float) -> void:
	return_label.visible = ratio > 0.0
	return_label.text = "[R]eturning to base... %d%%" % roundi(clampf(ratio, 0.0, 1.0) * 100.0)

func _refresh() -> void:
	var cargo: Cargo = Session.cargo
	var lines: PackedStringArray = PackedStringArray([
		"Cargo %s / %s Kg" % [HUD.format_number(cargo.used), HUD.format_number(cargo.capacity)]])
	var contents: Dictionary[StringName, int] = cargo.contents()

	for id: StringName in contents:
		lines.append("  %s: %s Kg" % [id, HUD.format_number(contents[id])])

	cargo_label.text = "\n".join(lines)

static func format_number(amount: int) -> String:
	var digits: String = str(absi(amount))
	var result: String = ""

	while digits.length() > 3:
		result = "," + digits.right(3) + result
		digits = digits.left(digits.length() - 3)

	return ("-" if amount < 0 else "") + digits + result

func show_distance(distance: float) -> void:
	distance_label.text = "Distance: %s" % HUD.format_number(roundi(distance))
