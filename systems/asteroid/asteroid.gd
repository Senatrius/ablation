@tool
class_name Asteroid extends Node

@onready var sprite_2d: Sprite2D = $Sprite2D

@export var asteroid_def: AsteroidDefinition

@export_tool_button("Generate")
var draw: Callable = draw_asteroid

func draw_asteroid() -> void:
	var new_asteroid: AsteroidGenerator = AsteroidGenerator.new(asteroid_def)
	sprite_2d.texture = new_asteroid.generate_image()
