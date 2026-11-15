class_name ShipCore extends ContentDefinition

@export_group("Thrust")
@export var engine_acceleration: float
@export var max_speed: float
@export var max_reverse_speed: float
@export var acceleration_curve: Curve

@export_group("Turning")
@export var max_turn_speed: float
@export var turn_acceleration: float
@export var turn_braking: float
