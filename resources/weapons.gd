class_name Weapons extends Resource

enum HIT_TYPE {HITSCAN, PROJECTILE, HOMING, STICKY}

@export var display_name: String
@export_multiline var description: String
@export var projectile_count: int
@export var projectile_damage: float
@export var max_range: float
@export var reticle: Texture2D
@export var hit_type: HIT_TYPE

func pick_target(rng: RandomNumberGenerator, center: Vector2) -> Vector2:
	var radius: float = 12 * 0.5 * sqrt(rng.randf())
	return center + Vector2.from_angle(rng.randf() * TAU) * radius
