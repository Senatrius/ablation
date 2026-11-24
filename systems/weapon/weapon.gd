@abstract
class_name Weapon extends Node2D

@export var turret: Marker2D

var definition: WeaponDefinition
var hit_mask: int = 0
var cooldown: float = 0.0
var misfire_chance: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var target: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)
	look_at(target)

func cast(from: Vector2, to: Vector2) -> Dictionary:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, hit_mask)
	return get_world_2d().direct_space_state.intersect_ray(query)

func try_fire() -> void:
	if cooldown > 0.0:
		return

	cooldown = 1.0 / definition.shots_per_second

	if misfire_chance > 0.0 and rng.randf() < misfire_chance:
		return

	fire(target)

@abstract
func fire(at: Vector2) -> void

func scatter(center: Vector2) -> Vector2:
	var radius: float = definition.spread_radius * sqrt(rng.randf())
	return center + Vector2.from_angle(rng.randf() * TAU) * radius

func stagger(index: int, count: int) -> void:
	cooldown = (1.0 / definition.shots_per_second) * index / count
