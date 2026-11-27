class_name MaterialDefinition extends ContentDefinition

enum Effects {NORMAL, VOLATILE, GAS}

@export var grid_id: int
@export var durability: float
@export var colours: PackedColorArray
@export var yields: StringName
@export var grain_size: float
@export var kg_per_cell: float
@export var effect: Effects
@export var explosion_damage: float = 4.0
@export var explosion_base_radius: float = 3.0
@export var explosion_radius: float
@export_range(0.0, 1.0, 0.05) var explosion_falloff: float = 0.5
@export var density: float
