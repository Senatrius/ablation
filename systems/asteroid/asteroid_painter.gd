class_name AsteroidPainter extends RefCounted


static func paint(cells: PackedByteArray, size: Vector2i, materials: Array[MaterialDefinition], paint_seed: int) -> Image:
	var rgba: PackedByteArray = PackedByteArray()
	rgba.resize(size.x * size.y * 4)

	var tint: FastNoiseLite = FastNoiseLite.new()
	tint.seed = paint_seed
	tint.frequency = 0.05
	var tint_bytes: PackedByteArray = tint.get_image(size.x, size.y, false, false, false).get_data()

	var palettes: Array[PackedColorArray] = []
	for material: MaterialDefinition in materials:
		palettes.append(material.colours)

	for y: int in size.y:
		for x: int in size.x:
			var i: int = y * size.x + x

			var id: int = cells[i]
			if id == 0:
				continue

			var palette: PackedColorArray = palettes[id - 1]
			var t: float = tint_bytes[i] / 255.0  # byte 0..255 → 0..1
			var colour: Color = palette[mini(int(t * palette.size()), palette.size() - 1)]

			if is_edge(cells, size, i, x, y):
				colour = colour.darkened(0.25)

			var o: int = i * 4
			rgba[o] = colour.r8
			rgba[o + 1] = colour.g8
			rgba[o + 2] = colour.b8
			rgba[o + 3] = 255

	return Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, rgba)

static func is_edge(cells: PackedByteArray, size: Vector2i, i: int, x: int, y: int) -> bool:
	if x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1:
		return true
	return cells[i - 1] == 0 or cells[i + 1] == 0 or cells[i - size.x] == 0 or cells[i + size.x] == 0
