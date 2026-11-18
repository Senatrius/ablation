class_name MaterialDefinition extends ContentDefinition

enum Effects {NORMAL, VOLATILE, GAS}

@export var grid_id: int
@export var durability: float
@export var colours: PackedColorArray
@export var resource_yield: float
@export var effect: Effects
@export var explosion_radius: float
@export var density: float
