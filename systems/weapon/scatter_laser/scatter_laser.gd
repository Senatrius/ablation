class_name ScatterLaser extends Weapon

func fire(at: Vector2) -> void:
	var from: Vector2 = turret.global_position
	var to: Vector2 = from + (scatter(at) - from).limit_length(definition.max_range)
	var hit: Dictionary = cast(from, to)

	if hit:
		to = hit.position

	spawn_ray(turret, to)

func spawn_ray(origin: Node2D, to: Vector2) -> void:
	var ray: Ray = Ray.new()
	ray.top_level = true
	ray.width = 2.0
	ray.default_color = Color(0.5, 0.7, 0.8, 0.5)
	ray.setup(origin, to)
	add_child(ray)
