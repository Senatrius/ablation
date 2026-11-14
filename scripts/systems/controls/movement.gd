extends RigidBody2D

@export_group("Thrust")
@export var engine_acceleration: float = 150.0
@export var max_speed: float = 260.0
@export var max_reverse_speed: float = 60.0
@export var acceleration_curve: Curve

@export_group("Turning")
@export var max_turn_speed: float = 120.0
@export var turn_acceleration: float = 300.0
@export var turn_braking: float = 160.0

var is_accelerating: bool = false
var is_decelerating: bool = false
var turn_input: float = 0.0

func _physics_process(_delta: float) -> void:
	is_accelerating = Input.is_action_pressed("accelerate")
	is_decelerating = Input.is_action_pressed("decelerate")
	turn_input = Input.get_axis("turn_left", "turn_right")

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var forward := Vector2.RIGHT.rotated(state.transform.get_rotation())

	if is_accelerating:
		_thrust(state, forward, max_speed)
	if is_decelerating:
		_thrust(state, -forward, max_reverse_speed)

	var target_spin := deg_to_rad(turn_input * max_turn_speed)
	var turn_rate := turn_acceleration if turn_input != 0.0 else turn_braking
	state.angular_velocity = move_toward(state.angular_velocity, target_spin, deg_to_rad(turn_rate) * state.step)

func _thrust(state: PhysicsDirectBodyState2D, direction: Vector2, top_speed: float) -> void:
	var speed_along := state.linear_velocity.dot(direction)
	var t := clampf(speed_along / top_speed, 0.0, 1.0)
	var strength := acceleration_curve.sample_baked(t) if acceleration_curve else 1.0 - t
	state.linear_velocity += direction * engine_acceleration * strength * state.step
