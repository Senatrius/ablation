class_name ChunkDebris extends Sprite2D

const MAGNET_DELAY: float = 0.35
const MAGNET_RANGE: float = 220.0
const MAGNET_SPEED: float = 260.0
const MAGNET_ACCEL: float = 600.0
const COLLECT_RADIUS: float = 14.0
const DRAG: float = 1.5
const LIFETIME: float = 30.0

## Material id -> cell count.
var _contents: Dictionary[StringName, int] = {}

var _velocity: Vector2
var _spin: float
var _age: float = 0.0
var _target: Player

func setup(image: Image, world_position: Vector2, world_rotation: float, velocity: Vector2, spin: float, material_contents: Dictionary[StringName, int]) -> void:
	texture = ImageTexture.create_from_image(image)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = world_position
	rotation = world_rotation
	_velocity = velocity
	_spin = spin
	_contents = material_contents

func _ready() -> void:
	_target = get_tree().get_first_node_in_group("player") as Player

func _physics_process(delta: float) -> void:
	_age += delta

	if _age > LIFETIME:
		queue_free()
		return

	var homing: bool = false
	if is_instance_valid(_target) and _age > MAGNET_DELAY:
		var to_target: Vector2 = _target.global_position - global_position
		var distance: float = to_target.length()

		if distance < COLLECT_RADIUS:
			_contents = _target.collect(_contents)
			if _contents.is_empty():
				queue_free()
				return

		if distance < MAGNET_RANGE and _target.cargo_free() > 0:
			homing = true
			_velocity = _velocity.move_toward(to_target / distance * MAGNET_SPEED, MAGNET_ACCEL * delta)

	if not homing:
		_velocity *= maxf(1.0 - DRAG * delta, 0.0)

	position += _velocity * delta
	rotation += _spin * delta
