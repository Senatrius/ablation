extends Resource
class_name ShipCore

@export_group("Info")
@export var display_name: String
@export_multiline var description: String

@export_group("Thrust")
@export var engine_acceleration: float
@export var max_speed: float
@export var max_reverse_speed: float
@export var acceleration_curve: Curve

@export_group("Turning")
@export var max_turn_speed: float
@export var turn_acceleration: float
@export var turn_braking: float
