class_name AsteroidSpawn extends Resource

@export var asteroid_def: AsteroidDefinition
@export_range(0.0, 1.0, 0.1) var spawn_weight: float = 1.0

@export_group("Distance")
@export var min_distance: float = 0.0
@export var max_distance: float = 0.0
@export var fade: float = 500.0

func weight_at(distance: float) -> float:
	if distance < min_distance:
		return 0.0
	if max_distance > 0.0 and distance > max_distance:
		return 0.0

	var weight: float = spawn_weight

	if fade > 0.0:
		if min_distance > 0.0:
			weight *= clampf((distance - min_distance) / fade, 0.0, 1.0)
		if max_distance > 0.0:
			weight *= clampf((max_distance - distance) / fade, 0.0, 1.0)

	return weight
