class_name AsteroidField extends Node2D

@export var asteroid_scene: PackedScene
@export var spawn_entries: Array[AsteroidSpawn] = []

@export_group("Density")
@export var live_count: int = 20
@export var spawn_interval: float = 0.25

@export_group("Spawn Fields")
@export var spawn_field_start: int = 100
@export var spawn_field_end: int = 250
@export var despawn_field_start: int = 1500
@export var safe_radius: int = 200
@export var gap: int = 30
@export var ahead_bias: float = 0.6

@export_group("Motion")
@export var drift_speed: float = 10.0
@export var rotation_speed: float = 0.3

const PLACEMENT_ATTEMPTS: int = 20

var _asteroids: Array[Asteroid] = []
var _player: RigidBody2D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _total_weight: float = 0.0
var _spawn_timer: float = 0.0

func _ready() -> void:
	_rng.randomize()
	for entry: AsteroidSpawn in spawn_entries:
		_total_weight += entry.spawn_weight

	_player = get_tree().get_first_node_in_group("player") as RigidBody2D

	for child: Node in get_children():
		if child is Asteroid:
			_track(child)

	_prepopulate()

func _prepopulate() -> void:
	if spawn_entries.is_empty():
		return

	var outer: float = _view_radius() + spawn_field_start + spawn_field_end

	for n: int in live_count - _asteroids.size():
		var definition: AsteroidDefinition = _pick_definition()
		var position_found: Vector2 = _find_position(definition, safe_radius, outer)

		if position_found.is_finite():
			_spawn(definition, position_found)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		return

	_despawn_far()

	_spawn_timer -= delta

	if _spawn_timer > 0.0 or _asteroids.size() >= live_count:
		return

	_spawn_timer = spawn_interval

	var definition: AsteroidDefinition = _pick_definition()
	var inner: float = _view_radius() + spawn_field_start
	var position_found: Vector2 = _find_position(definition, inner, inner + spawn_field_end)

	if position_found.is_finite():
		_spawn(definition, position_found)

func _spawn(definition: AsteroidDefinition, world_position: Vector2) -> void:
	var asteroid: Asteroid = asteroid_scene.instantiate() as Asteroid
	asteroid.asteroid_def = definition
	asteroid.gen_seed = 0
	asteroid.position = to_local(world_position)
	asteroid.rotation = _rng.randf() * TAU
	asteroid.linear_velocity = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, drift_speed)
	asteroid.angular_velocity = _rng.randf_range(-rotation_speed, rotation_speed)
	add_child(asteroid)

	_track(asteroid)

func _find_position(definition: AsteroidDefinition, min_distance: float, max_distance: float) -> Vector2:
	var radius: float = maxf(definition.width, definition.height) * 0.5
	var velocity: Vector2 = _player.linear_velocity

	for attempt: int in PLACEMENT_ATTEMPTS:
		var angle: float = _rng.randf() * TAU

		if velocity.length() > 20.0 and _rng.randf() < ahead_bias:
			angle = velocity.angle() + _rng.randf_range(-PI / 3.0, PI / 3.0)

		var distance: float = _rng.randf_range(min_distance, max_distance) + radius
		var candidate: Vector2 = _player.global_position + Vector2.from_angle(angle) * distance

		if _is_clear(candidate, radius):
			return candidate

	return Vector2.INF

func _is_clear(point: Vector2, radius: float) -> bool:
	for asteroid: Asteroid in _asteroids:
		var other_radius: float = maxf(asteroid.size.x, asteroid.size.y) * 0.5

		if asteroid.global_position.distance_to(point) < radius + other_radius + gap:
			return false
	return true

func _despawn_far() -> void:
	for n: int in range(_asteroids.size() - 1, -1, -1):
		var asteroid: Asteroid = _asteroids[n]

		if asteroid.global_position.distance_to(_player.global_position) > despawn_field_start:
			asteroid.queue_free()


func _pick_definition() -> AsteroidDefinition:
	var roll: float = _rng.randf() * _total_weight

	for entry: AsteroidSpawn in spawn_entries:
		roll -= entry.spawn_weight

		if roll <= 0.0:
			return entry.asteroid_def

	return spawn_entries.back().definition

func _view_radius() -> float:
	var view: Vector2 = get_viewport_rect().size
	var camera: Camera2D = get_viewport().get_camera_2d()

	if camera != null:
		view /= camera.zoom

	return view.length() * 0.5

func _track(asteroid: Asteroid) -> void:
	if _asteroids.has(asteroid):
		return

	_asteroids.append(asteroid)

	if not asteroid.fragment_spawned.is_connected(_track):
		asteroid.fragment_spawned.connect(_track)

	asteroid.tree_exiting.connect(_untrack.bind(asteroid))

func _untrack(asteroid: Asteroid) -> void:
	_asteroids.erase(asteroid)
