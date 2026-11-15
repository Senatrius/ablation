class_name ShipMovement extends RefCounted

static func integrate_forces(core: ShipCore, is_accelerating: bool, is_decelerating: bool, turning: float, state: PhysicsDirectBodyState2D) -> void:
	if core == null:
		return

	var forward := Vector2.RIGHT.rotated(state.transform.get_rotation())

	if is_accelerating:
		thrust(core, state, forward, core.max_speed)
	if is_decelerating:
		thrust(core, state, -forward, core.max_reverse_speed)

	var target_spin := deg_to_rad(turning * core.max_turn_speed)
	var turn_rate := core.turn_acceleration if turning != 0.0 else core.turn_braking
	state.angular_velocity = move_toward(state.angular_velocity, target_spin, deg_to_rad(turn_rate) * state.step)

static func thrust(core: ShipCore, state: PhysicsDirectBodyState2D, direction: Vector2, top_speed: float) -> void:
	var speed_along := state.linear_velocity.dot(direction)
	var t := clampf(speed_along / top_speed, 0.0, 1.0)
	var strength := core.acceleration_curve.sample_baked(t) if core.acceleration_curve else 1.0 - t
	state.linear_velocity += direction * core.engine_acceleration * strength * state.step
