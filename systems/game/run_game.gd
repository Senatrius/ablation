extends Node2D

@export var return_hold_time: float = 3.0
@export var death_delay: float = 1.5

@onready var _player: Player = $Player
@onready var _hud: HUD = $HUD

var _return_progress: float = 0.0
var _ending: bool = false

func _ready() -> void:
	_player.destroyed.connect(_on_player_destroyed)

func _process(delta: float) -> void:
	if _ending:
		return

	if Input.is_action_pressed(&"return_to_base"):
		_return_progress += delta / return_hold_time
	else:
		_return_progress = 0.0

	_hud.show_return_progress(_return_progress)
	_hud.show_distance($AsteroidField.distance_from_start(_player.global_position))

	if _return_progress >= 1.0:
		_ending = true
		Session.end_run(true)

func _on_player_destroyed() -> void:
	if _ending:
		return

	_ending = true
	_hud.show_return_progress(0.0)
	await get_tree().create_timer(death_delay).timeout
	Session.end_run(false)
