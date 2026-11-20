class_name WeaponDefinition extends ContentDefinition

@export var weapon_scene: PackedScene

@export var shots_per_second: float
@export var damage: float
@export var max_range: float
@export var spread_radius: int
@export var damage_radius: float
@export_range(0.0, 1.0, 0.1) var damage_falloff: float
