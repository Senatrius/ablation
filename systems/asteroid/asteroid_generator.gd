class_name AsteroidGenerator extends RefCounted

var _materials: Array[MaterialDefinition]
var _data: AsteroidDefinition

var _material_lookup: Dictionary[int, MaterialDefinition] = {}

func _init(data: AsteroidDefinition) -> void:
	_materials = data.materials
	_data = data

	for material: MaterialDefinition in _materials:
		_material_lookup[material.grid_id] = material

func get_noise_bytes(noise: FastNoiseLite, size: Vector2i) -> PackedByteArray:
	return noise.get_image(size.x, size.y, false, false, false).get_data()

func generate_noise(gen_seed: int) -> FastNoiseLite:
	var noise: FastNoiseLite = FastNoiseLite.new()

	noise.seed = gen_seed
	noise.noise_type = _data.noise_type
	noise.frequency = _data.frequency
	noise.fractal_type = _data.fractal_type
	noise.fractal_gain = _data.gain
	noise.fractal_octaves = _data.octaves

	return noise

func generate_cells(size: Vector2i, gen_seed: int) -> PackedByteArray:

	var cells: PackedByteArray = []
	cells.resize(size.x * size.y)
	cells.fill(0)

	var center: Vector2 = Vector2(size) / 2
	var radius: Vector2 = Vector2(size) * 0.42
	var pixels_per_unit: float = minf(radius.x, radius.y)

	var shape_noise: FastNoiseLite = generate_noise(gen_seed)
	var contour_noise: FastNoiseLite = generate_noise(gen_seed + 1)
	var depth_noise: FastNoiseLite = generate_noise(gen_seed + 2)

	shape_noise.frequency = _data.frequency / pixels_per_unit
	contour_noise.frequency = _data.frequency * 4.0 / pixels_per_unit
	depth_noise.frequency = _data.frequency * 2.0 / pixels_per_unit

	var shape_data: PackedByteArray = get_noise_bytes(shape_noise, size)
	var contour_data: PackedByteArray = get_noise_bytes(contour_noise, size)
	var depth_data: PackedByteArray = get_noise_bytes(depth_noise, size)

	var depth_fields: Array[PackedByteArray] = []
	for b: int in _data.layer_boundaries.size():
		depth_noise.offset = Vector3(b * 1000.0, 0.0, 0.0)
		depth_fields.append(depth_data)

	for y: int in range(size.y):
		for x: int in range(size.x):
			var local: Vector2 = (Vector2(x + 0.5, y + 0.5) - center) / radius
			var distance: float = local.length()

			var i: int = y * size.x + x
			var edge: float = 1.0
			edge += (shape_data[i] / 127.5 - 1.0) * 0.22
			edge += (contour_data[i] / 127.5 - 1.0) * 0.055

			if distance > edge:
				continue

			var depth: float = distance / edge  # 0 = center, 1 = surface
			cells[y * size.x + x] = _pick_layer(depth, depth_fields, i) + 1

	return IslandManager.keep_largest(cells, size)

func _pick_layer(depth: float, depth_fields: Array[PackedByteArray], i: int) -> int:
	for b: int in _data.layer_boundaries.size():
		var wobble: float = (depth_fields[b][i] / 127.5 - 1.0) * _data.layer_variation[b]
		if depth + wobble >= _data.layer_boundaries[b]:
			return b

	return _data.materials.size() - 1
