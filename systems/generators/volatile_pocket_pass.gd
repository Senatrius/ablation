class_name VolatilePocketPass extends GenerationPass

@export var material: MaterialDefinition
@export_range(0.0, 1.0, 0.01) var chance: float = 0.15
@export var count: Vector2i = Vector2i(1, 3)
@export var radius: Vector2 = Vector2(3.0, 7.0)
@export var depth_range: Vector2 = Vector2(0.2, 0.75)

const ATTEMPTS: int = 30

func apply(generator: AsteroidGenerator, cells: PackedByteArray, size: Vector2i, rng: RandomNumberGenerator) -> PackedByteArray:
	if material == null or rng.randf() >= chance:
		return cells

	var id: int = generator.material_id(material)
	var edge_noise: FastNoiseLite = FastNoiseLite.new()
	edge_noise.seed = rng.randi()
	edge_noise.frequency = 0.7

	var result: PackedByteArray = cells.duplicate()
	for n: int in rng.randi_range(count.x, count.y):
		var centre: int = _pick_centre(generator.depth, result, rng)
		if centre == -1:
			continue

		var cx: int = centre % size.x
		var cy: int = centre / size.x
		var r: float = rng.randf_range(radius.x, radius.y)
		var reach: int = ceili(r * 1.3)

		for dy: int in range(-reach, reach + 1):
			for dx: int in range(-reach, reach + 1):
				var x: int = cx + dx
				var y: int = cy + dy
				if x < 0 or y < 0 or x >= size.x or y >= size.y:
					continue
				var i: int = y * size.x + x
				if result[i] == 0:
					continue
				var wobble: float = 1.0 + edge_noise.get_noise_2d(x, y) * 0.3
				if sqrt(dx * dx + dy * dy) <= r * wobble:
					result[i] = id

	return result

func _pick_centre(depth: PackedFloat32Array, cells: PackedByteArray, rng: RandomNumberGenerator) -> int:
	for attempt: int in ATTEMPTS:
		var i: int = rng.randi_range(0, cells.size() - 1)
		if cells[i] != 0 and depth[i] >= depth_range.x and depth[i] <= depth_range.y:
			return i

	return -1
