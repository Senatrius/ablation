class_name AsteroidGenerator extends RefCounted

var _materials: Array[MaterialDefinition]
var _data: AsteroidDefinition

var _material_lookup: Dictionary[int, MaterialDefinition] = {}

func _init(data: AsteroidDefinition) -> void:
	_materials = data.materials
	_data = data

	for material: MaterialDefinition in _materials:
		_material_lookup[material.grid_id] = material

func generate_noise(gen_seed: int) -> FastNoiseLite:
	var noise: FastNoiseLite = FastNoiseLite.new()

	noise.seed = gen_seed
	noise.noise_type = _data.noise_type
	noise.frequency = _data.frequency
	noise.fractal_type = _data.fractal_type
	noise.fractal_gain = _data.gain
	noise.fractal_octaves = _data.octaves

	return noise

func generate_asteroid(size: Vector2i, gen_seed: int) -> PackedByteArray:
	var cells: PackedByteArray = []
	cells.resize(size.x * size.y)
	cells.fill(0)

	var center: Vector2 = Vector2(size.x / 2, size.y / 2)
	var base_radius: float = minf(size.x, size.y) * 0.42

	var shape_noise: FastNoiseLite = generate_noise(gen_seed)
	var contour_noise: FastNoiseLite = generate_noise(gen_seed + 1)
	var depth_noise: FastNoiseLite = generate_noise(gen_seed + 2)

	for y: int in range(size.y):
		for x: int in range(size.x):
			var local: Vector2 = Vector2(x + 0.5, y + 0.5) - center
			var distance: float = local.length()

			var large_shape: float = shape_noise.get_noise_2d(x, y)
			var contour_shape: float = contour_noise.get_noise_2d(x, y)

			var edge_radius: float = base_radius
			edge_radius += large_shape * base_radius * 0.22
			edge_radius += contour_shape * base_radius * 0.055

			if distance > edge_radius:
				continue

			var normalized_radius: float = distance / edge_radius

			var layer_index: int = _materials.size() - 1

			for i: int in range(_data.layer_boundaries.size()):
				if normalized_radius >= _data.layer_thresholds[i]:
					layer_index = i
					break

			cells[y * size.x + x] = _materials[layer_index].grid_id

	return cells

func generate_image() -> ImageTexture:
	var asteroid_cells: PackedByteArray = generate_asteroid(Vector2i(_data.width, _data.height), randi_range(1, 9999))
	var image: Image = Image.create(_data.width, _data.height, false, Image.FORMAT_RGBA8)

	for y:int in range(_data.height):
		for x:int in range(_data.width):
			var material_idx: int = asteroid_cells[y * _data.width + x]
			if material_idx == 0:
				continue

			var material: MaterialDefinition = _material_lookup[material_idx]

			image.set_pixel(
				x,
				y,
				material.colours[0]
			)

	return ImageTexture.create_from_image(image)
