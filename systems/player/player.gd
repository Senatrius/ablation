class_name Player extends RigidBody2D

@onready var weapons: Node2D = $Weapons

@export var core: ShipCore
@export var weapon_def: WeaponDefinition

var weapon: Weapon

var is_accelerating: bool = false
var is_decelerating: bool = false
var turn_input: float = 0.0

func _ready() -> void:
	equip(weapon_def)

func equip(definition: WeaponDefinition) -> void:
	if weapon:
		weapon.queue_free()

	weapon.hit_mask = 0b10

	weapon = definition.scene.instantiate() as Weapon
	weapon.definition = definition
	weapon.muzzles.assign(weapons.get_children())

	add_child(weapon)

func aim_target() -> Vector2:
	var offset := get_global_mouse_position() - global_position
	return global_position + offset.limit_length(weapon.definition.max_range)

func _physics_process(_delta: float) -> void:
	is_accelerating = Input.is_action_pressed("accelerate")
	is_decelerating = Input.is_action_pressed("decelerate")
	turn_input = Input.get_axis("turn_left", "turn_right")

	if weapon and Input.is_action_pressed("primary"):
		weapon.try_fire(get_global_mouse_position())

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	ShipMovement.integrate_forces(core, is_accelerating, is_decelerating, turn_input, state)
