class_name AsteroidField extends Node2D

@export var asteroid_scene: PackedScene
@export var spawn_entries: Array[AsteroidSpawn] = []

@export_group("Density")
@export var live_count: int = 30
@export var spawn_interval: float = 0.25

@export_group("Difficulty")
@export var tier_step: float = 2500.0
@export var stale_distance: float = 1500.0

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

@export_group("Background generation")
@export var prefetch_count: int = 6
@export var print_timings: bool = false

const PLACEMENT_ATTEMPTS: int = 20

var _origin: Vector2 = Vector2.ZERO
var _asteroids: Array[Asteroid] = []
var _player: RigidBody2D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _total_weight: float = 0.0
var _spawn_timer: float = 0.0
var _ready_blueprints: Array[AsteroidBlueprint] = []
var _tasks: Array[int] = []

func _ready() -> void:
	_rng.randomize()
	for entry: AsteroidSpawn in spawn_entries:
		_total_weight += entry.spawn_weight

	_player = get_tree().get_first_node_in_group("player") as RigidBody2D
	if is_instance_valid(_player):
		_origin = _player.global_position

	for child: Node in get_children():
		if child is Asteroid:
			_track(child)

	_prepopulate()

func _new_seed() -> int:
	var s: int = _rng.randi()
	return s if s != 0 else 1

func _prepopulate() -> void:
	if not is_instance_valid(_player) or spawn_entries.is_empty():
		return
	var count: int = live_count - _asteroids.size()
	if count <= 0:
		return

	var definitions: Array[AsteroidDefinition] = []
	var seeds: Array[int] = []
	for n: int in count:
		var definition: AsteroidDefinition = _pick_definition(distance_from_start(_player.global_position))
		if definition != null: definitions.append(definition)
		seeds.append(_new_seed())

	var results: Array[AsteroidBlueprint] = []
	results.resize(count)
	var group: int = WorkerThreadPool.add_group_task(func(n: int) -> void:
		results[n] = AsteroidBlueprint.generate(definitions[n], seeds[n]), count)
	WorkerThreadPool.wait_for_group_task_completion(group)

	var outer: float = _view_radius() + spawn_field_start + spawn_field_end
	for bp: AsteroidBlueprint in results:
		var position_found: Vector2 = _find_position(bp.size, safe_radius, outer)
		if position_found.is_finite():
			_spawn(bp, position_found)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		return

	_reap_tasks()
	_despawn_far()

	while _ready_blueprints.size() + _tasks.size() < prefetch_count:
		if not _request_blueprint():
			break

	var current: float = distance_from_start(_player.global_position)
	while not _ready_blueprints.is_empty() and absf(_ready_blueprints[0].spawn_distance - current) > stale_distance:
		_ready_blueprints.pop_front()

	_spawn_timer -= delta
	if _spawn_timer > 0.0 or _asteroids.size() >= live_count or _ready_blueprints.is_empty():
		return

	_spawn_timer = spawn_interval

	var bp: AsteroidBlueprint = _ready_blueprints[0]
	var inner: float = _view_radius() + spawn_field_start
	var position_found: Vector2 = _find_position(bp.size, inner, inner + spawn_field_end)

	if position_found.is_finite():
		_ready_blueprints.pop_front()
		_spawn(bp, position_found)

func distance_from_start(point: Vector2) -> float:
	return point.distance_to(_origin)

func _exit_tree() -> void:
	for task: int in _tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	_tasks.clear()

func _request_blueprint() -> bool:
	var distance: float = distance_from_start(_player.global_position)
	var definition: AsteroidDefinition = _pick_definition(distance)

	if definition == null:
		return false

	var tier: int = tier_at(distance)
	_tasks.append(WorkerThreadPool.add_task(
		_build_in_background.bind(definition, _new_seed(), distance, tier)))

	return true

func _build_in_background(definition: AsteroidDefinition, gen_seed: int, distance: float, toughness: float) -> void:
	var bp: AsteroidBlueprint = AsteroidBlueprint.generate(definition, gen_seed, false, toughness)
	bp.spawn_distance = distance
	_receive_blueprint.call_deferred(bp)

func _receive_blueprint(bp: AsteroidBlueprint) -> void:
	_ready_blueprints.append(bp)
	if print_timings:
		print("%s: %.1f ms %s" % [bp.asteroid_def.id, bp.total_ms(), bp.timings])

func _reap_tasks() -> void:
	for n: int in range(_tasks.size() - 1, -1, -1):
		if WorkerThreadPool.is_task_completed(_tasks[n]):
			WorkerThreadPool.wait_for_task_completion(_tasks[n])
			_tasks.remove_at(n)

func _spawn(bp: AsteroidBlueprint, world_position: Vector2) -> void:
	var asteroid: Asteroid = asteroid_scene.instantiate() as Asteroid
	asteroid.blueprint = bp
	asteroid.asteroid_def = bp.asteroid_def
	asteroid.position = to_local(world_position)
	asteroid.rotation = _rng.randf() * TAU
	asteroid.linear_velocity = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, drift_speed)
	asteroid.angular_velocity = _rng.randf_range(-rotation_speed, rotation_speed)
	add_child(asteroid)

	_track(asteroid)

func _find_position(size: Vector2i, min_distance: float, max_distance: float) -> Vector2:
	var radius: float = maxf(size.x, size.y) * 0.5
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

func tier_at(distance: float) -> int:
	var exact: float = distance / tier_step
	var tier: int = floori(exact)

	if _rng.randf() < exact - tier:
		tier += 1

	return tier

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

func _pick_definition(distance: float) -> AsteroidDefinition:
	var total: float = 0.0
	for entry: AsteroidSpawn in spawn_entries:
		total += entry.weight_at(distance)

	if total <= 0.0:
		return null

	var roll: float = _rng.randf() * total
	var last: AsteroidDefinition = null

	for entry: AsteroidSpawn in spawn_entries:
		var weight: float = entry.weight_at(distance)

		if weight <= 0.0:
			continue

		last = entry.asteroid_def
		roll -= weight

		if roll <= 0.0:
			return entry.asteroid_def

	return last

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
