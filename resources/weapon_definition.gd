class_name WeaponDefinition extends ContentDefinition

@export var weapon_scene: PackedScene

@export var shots_per_second: int
@export var damage: float
@export var max_range: float
@export var spread_radius: int

func pick_target(rng: RandomNumberGenerator, center: Vector2) -> Vector2:
	var radius: float = spread_radius * sqrt(rng.randf())
	return center + Vector2.from_angle(rng.randf() * TAU) * radius
