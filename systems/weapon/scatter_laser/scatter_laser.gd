class_name ScatterLaser extends Weapon

func fire(target: Vector2) -> void:
	for turret in turrets:
		var from := turret.global_position
		var to := from + (scatter(target) - from).limit_length(definition.max_range)
		var hit := cast(from, to)

		if hit:
			to = hit.position

		spawn_ray(from, to)

func spawn_ray(from: Vector2, to: Vector2) -> void:
	var ray := Ray.new()
	ray.top_level = true
	ray.width = 1.0
	ray.default_color = Color(0.5, 0.7, 0.8, 0.5)
	ray.points = PackedVector2Array([from, to])

	add_child(ray)
