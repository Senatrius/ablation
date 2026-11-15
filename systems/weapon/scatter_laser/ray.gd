class_name Ray extends Line2D

var lifetime := 0.1
var current_age := 0.0

func _process(delta: float) -> void:
	current_age += delta

	modulate.a = clampf(1.0 - current_age / lifetime, 0.0, 1.0)

	if current_age >= lifetime:
		queue_free()
