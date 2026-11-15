class_name WeaponContext extends RefCounted

var origins: Array[Transform2D] = []
var target: Vector2 = Vector2.ZERO
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var effect_root: Node

func draw_ray(from: Vector2, to: Vector2) -> void:
	var ray = Ray.new()
	ray.width = 1.0
	ray.default_color = Color(0.5, 0.7, 0.8, 0.5)

	ray.add_point(Vector2.ZERO)
	ray.add_point(to - from)

	effect_root.add_child(ray)
	ray.global_position = from
