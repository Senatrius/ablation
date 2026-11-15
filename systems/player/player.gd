class_name Player extends RigidBody2D

@onready var effect_root: Node = $Effects
@onready var weapons: Node = $Weapons

@export var core: ShipCore
@export var weapon_def: WeaponDefinition

var weapon_ctx := WeaponContext.new()

var is_accelerating: bool = false
var is_decelerating: bool = false
var turn_input: float = 0.0

func _ready() -> void:
	weapon_ctx.effect_root = effect_root

func _process(delta: float) -> void:
	weapon_ctx.origins.clear()

	for weapon in weapons.get_children():
		weapon_ctx.origins.append(weapon.global_transform)

	weapon_ctx.target = get_global_mouse_position()

	if Input.is_action_pressed("primary"):
		weapon_def.weapon_behaviour.fire(weapon_ctx, weapon_def, delta)

func _physics_process(_delta: float) -> void:
	is_accelerating = Input.is_action_pressed("accelerate")
	is_decelerating = Input.is_action_pressed("decelerate")
	turn_input = Input.get_axis("turn_left", "turn_right")

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	ShipMovement.integrate_forces(core, is_accelerating, is_decelerating, turn_input, state)
