class_name ScatterLaser extends Weapon

const BEAM_COLOUR: Color = Color(0.5, 0.7, 0.8, 0.5)
const HOT_BEAM_COLOUR: Color = Color(0.988, 0.588, 0.365, 0.851)

func fire(at: Vector2) -> void:
	var from: Vector2 = turret.global_position
	var to: Vector2 = from + (scatter(at) - from).limit_length(definition.max_range)
	var hit: Dictionary = cast(from, to)

	if hit:
		to = hit.position

		if hit.collider.has_method("take_hit"):
			hit.collider.take_hit(to, from.direction_to(to), definition.damage,
				definition.damage_radius, definition.damage_falloff)

	spawn_ray(turret, to)

func spawn_ray(origin: Node2D, to: Vector2) -> void:
	var ray: Ray = Ray.new()
	ray.top_level = true
	ray.width = 1.0
	ray.default_color = BEAM_COLOUR.lerp(HOT_BEAM_COLOUR, overcharge_ratio())
	ray.setup(origin, to)
	add_child(ray)
