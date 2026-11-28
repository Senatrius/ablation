class_name AsteroidGenerator extends RefCounted

var materials: Array[MaterialDefinition] = []
var depth: PackedFloat32Array

var _data: AsteroidDefinition

func _init(data: AsteroidDefinition, tier: int = 0) -> void:
	_data = data
	materials = data.resolve_materials(tier)

	assert(materials.size() == data.layer_boundaries.size() + 1,
		"%s: %d layer materials but %d boundaries; needs exactly one more material than boundaries" %
		[data.id, materials.size(), data.layer_boundaries.size()])

func material_id(material: MaterialDefinition) -> int:
	var index: int = materials.find(material)

	if index == -1:
		materials.append(material)
		index = materials.size() - 1

	return index + 1

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
	var cells: PackedByteArray = PackedByteArray()
	cells.resize(size.x * size.y)
	depth = PackedFloat32Array()
	depth.resize(size.x * size.y)

	var center: Vector2 = Vector2(size) / 2.0
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

	var depth_fields: Array[PackedByteArray] = []
	for b: int in _data.layer_boundaries.size():
		depth_noise.offset = Vector3(b * 1000.0, 0.0, 0.0)
		depth_fields.append(get_noise_bytes(depth_noise, size))

	for y: int in size.y:
		for x: int in size.x:
			var i: int = y * size.x + x
			var local: Vector2 = (Vector2(x + 0.5, y + 0.5) - center) / radius
			var distance: float = local.length()

			var edge: float = 1.0
			edge += (shape_data[i] / 127.5 - 1.0) * 0.22
			edge += (contour_data[i] / 127.5 - 1.0) * 0.055
			if distance > edge:
				continue

			var d: float = distance / edge
			depth[i] = d
			cells[i] = _pick_layer(d, depth_fields, i) + 1

	cells = IslandManager.keep_largest(cells, size)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = gen_seed
	for generation_pass: GenerationPass in _data.passes:
		cells = generation_pass.apply(self, cells, size, rng)
	return cells

func _pick_layer(d: float, depth_fields: Array[PackedByteArray], i: int) -> int:
	for b: int in _data.layer_boundaries.size():
		var wobble: float = (depth_fields[b][i] / 127.5 - 1.0) * _data.layer_variation[b]

		if d + wobble >= _data.layer_boundaries[b]:
			return b

	return materials.size() - 1
