class_name EngineFlare extends AnimatedSprite2D

enum Mode { OFF, BRAKE, IDLE, THRUST }

@export var response: float = 12.0

const ANIMATIONS: Dictionary[Mode, StringName] = {
	Mode.BRAKE: "brake",
	Mode.IDLE: "idle",
	Mode.THRUST: "accellerate",
}
var mode: Mode = Mode.IDLE:
	set(value):
		if value == mode:
			return
		mode = value
		if is_node_ready():
			_apply_mode()

var throttle: float = 1.0
var sputter: float = 0.0
var _shown: float = 0.0

func _ready() -> void:
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	play("idle")

	_apply_mode()

func _apply_mode() -> void:
	if mode == Mode.OFF:
		stop()
		return

	play(ANIMATIONS[mode])

func _process(delta: float) -> void:
	var target: float = throttle
	if sputter > 0.0 and randf() < sputter * delta * 10.0:
		target = 0.0

	_shown = lerpf(_shown, target, 1.0 - exp(-response * delta))
	visible = _shown > 0.02
	modulate.a = _shown
