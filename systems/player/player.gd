class_name Player extends RigidBody2D

@export var core: ShipCore

var is_accelerating: bool = false
var is_decelerating: bool = false
var turn_input: float = 0.0

func _physics_process(_delta: float) -> void:
	is_accelerating = Input.is_action_pressed("accelerate")
	is_decelerating = Input.is_action_pressed("decelerate")
	turn_input = Input.get_axis("turn_left", "turn_right")

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	ShipMovement.integrate_forces(core, is_accelerating, is_decelerating, turn_input, state)
