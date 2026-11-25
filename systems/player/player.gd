class_name Player extends RigidBody2D

signal destroyed()

@export var hardpoints: Array[Marker2D] = []
@export var core_data: ShipCore
@export var weapon_def: WeaponDefinition
@export var cargo_capacity: int = 300

@export_group("Ship Parts")
@export var body: ShipPart
@export var core: ShipPart
@export var rear_engines: ShipPart
@export var left_engine: ShipPart
@export var right_engine: ShipPart
@export var left_cargo: ShipPart
@export var right_cargo: ShipPart
@export var left_wing: ShipPart
@export var right_wing: ShipPart

@export_group("Flares")
@export var main_flares: Array[EngineFlare] = []
@export var left_flare: EngineFlare
@export var right_flare: EngineFlare

@export_group("Damage")
@export var safe_impact_speed: float = 40.0
@export var damage_per_impact_speed: float = 2.0
@export_range(0.0, 1.0, 0.05) var engine_minimum: float = 0.35
@export_range(0.0, 1.0, 0.05) var max_misfire_chance: float = 0.8

var weapons: Array[Weapon] = []

var modifiers: ShipModifiers = ShipModifiers.new()
var cargo: Dictionary[StringName, int] = {}
var cargo_limit: int = 0
var cargo_used: int = 0

var is_accelerating: bool = false
var is_decelerating: bool = false
var turn_input: float = 0.0

var parts: Array[ShipPart] = []
var pending_parts: Array[ShipPart] = []
var pending_damage: PackedFloat32Array = PackedFloat32Array()
var part_by_shape: Dictionary[Node, ShipPart] = {}

func _ready() -> void:
	for part:ShipPart in [body, core, rear_engines, left_engine, right_engine, left_cargo, right_cargo, left_wing, right_wing]:
		if part != null: parts.append(part)
		if part.collider != null: part_by_shape[part.collider] = part

		part.health_changed.connect(_on_part_health_changed)

	equip(weapon_def)
	_recalculate_damage_effects()

func _on_part_health_changed(part: ShipPart) -> void:
	_recalculate_damage_effects()

	if part == core and part.is_destroyed():
		destroyed.emit()

func _recalculate_damage_effects() -> void:
	modifiers.thrust = rear_engines.effectiveness(engine_minimum)
	modifiers.turn_right = left_engine.effectiveness(engine_minimum)
	modifiers.turn_left = right_engine.effectiveness(engine_minimum)

	for flare: EngineFlare in main_flares:
		flare.sputter = rear_engines.damage_ratio()
	left_flare.sputter = left_engine.damage_ratio()
	right_flare.sputter = right_engine.damage_ratio()

	for weapon: Weapon in weapons:
		var wing: ShipPart = _part_of(weapon)
		weapon.misfire_chance = wing.damage_ratio() * max_misfire_chance if wing else 0.0

	var half: float = cargo_capacity * 0.5
	cargo_limit = int(half * left_cargo.effectiveness(0.0) + half * right_cargo.effectiveness(0.0))

	_spill_excess_cargo()

func _spill_excess_cargo() -> void:
	var excess: int = cargo_used - cargo_limit

	while excess > 0 and not cargo.is_empty():
		var id: StringName = cargo.keys().pick_random()
		var lost: int = mini(cargo[id], excess)

		cargo[id] -= lost

		if cargo[id] == 0:
			cargo.erase(id)

		cargo_used -= lost
		excess -= lost

		print("Lost %d %s" % [lost, id])

func _part_at(world_point: Vector2) -> ShipPart:
	var nearest: ShipPart = null
	var nearest_distance: float = INF

	for part: ShipPart in parts:
		if part.invulnerable:
			continue

		if part.get_rect().has_point(part.to_local(world_point)):
			return part

		var distance: float = part.global_position.distance_squared_to(world_point)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest = part

	return nearest

func _part_of(node: Node) -> ShipPart:
	var current: Node = node.get_parent()

	while current != null and current != self:
		if current is ShipPart:
			return current

		current = current.get_parent()

	return null

func equip(definition: WeaponDefinition) -> void:
	for old: Weapon in weapons:
		old.queue_free()

	weapons.clear()

	weapon_def = definition
	for hardpoint: Marker2D in hardpoints:
		var weapon: Weapon = definition.weapon_scene.instantiate()

		weapon.definition = definition
		weapon.hit_mask = 0b10

		hardpoint.add_child(weapon)
		weapons.append(weapon)

		weapon.stagger(weapons.size() - 1, hardpoints.size())

	_recalculate_damage_effects()

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

	for n: int in pending_parts.size():
		pending_parts[n].take_damage(pending_damage[n])

	pending_parts.clear()
	pending_damage.clear()

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	for i: int in state.get_contact_count():
		var speed_change: float = state.get_contact_impulse(i).length() / mass
		if speed_change <= safe_impact_speed:
			continue

		var owner_id: int = shape_find_owner(state.get_contact_local_shape(i))
		var part: ShipPart = part_by_shape.get(shape_owner_get_owner(owner_id))

		if part != null:
			pending_parts.append(part)
			pending_damage.append((speed_change - safe_impact_speed) * damage_per_impact_speed)

	ShipMovement.integrate_forces(core_data, modifiers, is_accelerating, is_decelerating, turn_input, state)

func collect(contents: Dictionary) -> void:
	print(contents)
