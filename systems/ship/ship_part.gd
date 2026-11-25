class_name ShipPart extends Sprite2D

signal health_changed(part: ShipPart)

@export var collider: CollisionPolygon2D
@export var max_health: float = 10.0
@export var invulnerable: bool = false
@export var damaged_texture: Texture2D
@export_range(0.0, 1.0, 0.05) var damage_threshold: float = 0.5

const DARKEN: float = 0.3

var health: float
var _intact_texture: Texture2D

func _ready() -> void:
	health = max_health
	_intact_texture = texture

func damage_ratio() -> float:
	return 1.0 - health / max_health if max_health > 0.0 else 0.0

func is_destroyed() -> bool:
	return health <= 0.0

func effectiveness(minimum: float) -> float:
	return lerpf(1.0, minimum, damage_ratio())

func take_damage(amount: float) -> void:
	if invulnerable or amount <= 0.0 or is_destroyed():
		return

	health = maxf(health - amount, 0.0)
	if is_destroyed() and collider != null:
		collider.set_deferred(&"disabled", true)

	print("%s: %.1f / %.1f" % [name, health, max_health])
	_refresh()
	health_changed.emit(self)


func repair(amount: float) -> void:
	if amount <= 0.0 or health >= max_health:
		return

	var was_destroyed: bool = is_destroyed()
	health = minf(health + amount, max_health)

	if was_destroyed and collider != null:
		collider.set_deferred(&"disabled", false)

	_refresh()
	health_changed.emit(self)

func _refresh() -> void:
	var ratio: float = damage_ratio()

	if damaged_texture != null:
		texture = damaged_texture if ratio >= damage_threshold else _intact_texture

	self_modulate = Color.WHITE.darkened(ratio * DARKEN)
