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
		"Cargo %s / %s" % [Mass.format(cargo.used, 100), Mass.format(cargo.capacity, 100)]])
	var contents: Dictionary[StringName, int] = cargo.contents()

	for id: StringName in contents:
		lines.append("  %s: %s" % [id, Mass.format(contents[id], 100)])

	cargo_label.text = "\n".join(lines)

func show_distance(distance: float) -> void:
	distance_label.text = "Distance: %s" % Format.number(roundi(distance))
