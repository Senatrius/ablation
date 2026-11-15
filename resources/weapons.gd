class_name WeaponDefinition extends ContentDefinition

enum HitType {HITSCAN, PROJECTILE, HOMING, STICKY}

@export var weapon_behaviour: WeaponBehaviour

@export var shots_per_second: int
@export var damage: float
@export var max_range: float
@export var reticle_radius: int

func pick_target(rng: RandomNumberGenerator, center: Vector2) -> Vector2:
	var radius: float = reticle_radius * sqrt(rng.randf())
	return center + Vector2.from_angle(rng.randf() * TAU) * radius
