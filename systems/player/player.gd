class_name Player extends RigidBody2D

@onready var hardpoints: Node2D = $Hardpoints

@export var core: ShipCore
@export var weapon_def: WeaponDefinition
@export var main_flares: Array[EngineFlare] = []
@export var left_flare: EngineFlare
@export var right_flare: EngineFlare

var weapons: Array[Weapon] = []

var is_accelerating: bool = false
var is_decelerating: bool = false
var turn_input: float = 0.0

func _ready() -> void:
	equip(weapon_def)

func equip(definition: WeaponDefinition) -> void:
	for old: Weapon in weapons:
		old.queue_free()
	weapons.clear()

	weapon_def = definition
	for hardpoint: Marker2D in hardpoints.get_children():
		var weapon: Weapon = definition.weapon_scene.instantiate()

		weapon.definition = definition
		weapon.hit_mask = 0b10

		hardpoint.add_child(weapon)
		weapons.append(weapon)

		weapon.stagger(weapons.size() - 1, hardpoints.get_child_count())

func aim_target() -> Vector2:
	var offset: Vector2 = get_global_mouse_position() - global_position
	return global_position + offset.limit_length(weapon_def.max_range)

func _physics_process(_delta: float) -> void:
	var main_mode: EngineFlare.Mode = EngineFlare.Mode.IDLE

	is_accelerating = Input.is_action_pressed("accelerate")
	is_decelerating = Input.is_action_pressed("decelerate")
	turn_input = Input.get_axis("turn_left", "turn_right")

	if is_accelerating:
		main_mode = EngineFlare.Mode.THRUST
	elif is_decelerating:
		main_mode = EngineFlare.Mode.BRAKE

	for flare: EngineFlare in main_flares:
		flare.mode = main_mode

	left_flare.mode = EngineFlare.Mode.THRUST if turn_input > 0.0 else main_mode
	right_flare.mode = EngineFlare.Mode.THRUST if turn_input < 0.0 else main_mode

	var target: Vector2 = aim_target()
	var firing: bool = Input.is_action_pressed("primary")
	for weapon: Weapon in weapons:
		weapon.target = target
		if firing:
			weapon.try_fire()

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	ShipMovement.integrate_forces(core, is_accelerating, is_decelerating, turn_input, state)

func collect(contents: Dictionary) -> void:
	print(contents)
