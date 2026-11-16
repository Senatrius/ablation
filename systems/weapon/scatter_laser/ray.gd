class_name Ray extends Line2D

var lifetime: float = 0.1

var age: float = 0.0
var _anchor: Node2D

func setup(anchor: Node2D, end: Vector2) -> void:
	_anchor = anchor
	points = PackedVector2Array([anchor.global_position, end])


func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return

	set_point_position(0, _anchor.global_position)
	modulate.a = 1.0 - age / lifetime
