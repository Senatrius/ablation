class_name ScatterLaserBehaviour extends WeaponBehaviour

func fire(ctx: WeaponContext, def: WeaponDefinition, _delta: float) -> void:
	for origin in ctx.origins:
		var aim := def.pick_target(ctx.rng, ctx.target)

		var direction := aim - origin.get_origin()

		if direction.length_squared() < 0.0001:
			return

		var endpoint := origin.get_origin() + direction.normalized() * def.max_range

		ctx.draw_ray(origin.get_origin(), endpoint)
