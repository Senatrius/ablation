class_name AsteroidBlueprint extends RefCounted

var asteroid_def: AsteroidDefinition
var used_seed: int
var tint_offset: Vector2i = Vector2i.ZERO
var size: Vector2i
var cells: PackedByteArray
var health: PackedFloat32Array
var materials: Array[MaterialDefinition] = []
var chunks: ChunkMap
var painter: AsteroidPainter
var image: Image
var collision_pieces: Array[PackedVector2Array] = []
var solid: int = 0
var mass_sum: float = 0.0
var mass_moment: Vector2 = Vector2.ZERO
var mass_second_moment: float = 0.0

## Milliseconds per build step
var timings: Dictionary[StringName, float] = {}

static func generate(definition: AsteroidDefinition, gen_seed: int, debug_chunks: bool = false) -> AsteroidBlueprint:
	var blueprint: AsteroidBlueprint = AsteroidBlueprint.new()
	var generator: AsteroidGenerator = AsteroidGenerator.new(definition)
	var t: int = Time.get_ticks_usec()

	t = blueprint._lap("shape", t)

	blueprint.asteroid_def = definition
	blueprint.used_seed = gen_seed
	blueprint.size = Vector2i(definition.width, definition.height)
	blueprint.cells = generator.generate_cells(blueprint.size, gen_seed)
	blueprint.materials = generator.materials
	blueprint.health.resize(blueprint.cells.size())

	for i: int in blueprint.cells.size():
		if blueprint.cells[i] != 0:
			blueprint.health[i] = blueprint.materials[blueprint.cells[i] - 1].durability

	blueprint.chunks = ChunkMap.build(blueprint.cells, blueprint.size, blueprint.materials, definition.chunk_size,
		definition.chunk_size_variation, definition.min_chunk_cells, definition.chunk_toughness, gen_seed)
	blueprint.chunks.find_pockets(blueprint.cells, blueprint.materials)

	t = blueprint._lap("chunks", t)

	blueprint._finish(debug_chunks, t)
	return blueprint

static func from_fragment(definition: AsteroidDefinition, parent_seed: int, offset: Vector2i, fragment_size: Vector2i, fragment_cells: PackedByteArray, fragment_health: PackedFloat32Array, fragment_materials: Array[MaterialDefinition], fragment_chunks: ChunkMap, debug_chunks: bool = false) -> AsteroidBlueprint:
	var blueprint: AsteroidBlueprint = AsteroidBlueprint.new()
	blueprint.asteroid_def = definition
	blueprint.used_seed = parent_seed
	blueprint.tint_offset = offset
	blueprint.size = fragment_size
	blueprint.cells = fragment_cells
	blueprint.health = fragment_health
	blueprint.materials = fragment_materials
	blueprint.chunks = fragment_chunks

	blueprint._finish(debug_chunks, Time.get_ticks_usec())

	return blueprint

func total_ms() -> float:
	var total: float = 0.0

	for step: StringName in timings:
		total += timings[step]

	return total

func _finish(debug_chunks: bool, t: int) -> void:
	_measure_mass()

	t = _lap(&"mass", t)

	painter = AsteroidPainter.new(size, materials, used_seed, tint_offset)
	painter.debug_chunks = debug_chunks
	image = painter.paint_all(cells, health, chunks.ids)

	t = _lap(&"paint", t)

	collision_pieces = Asteroid.collision_pieces_from(image, size)

	_lap("collision", t)

func _measure_mass() -> void:
	var origin: Vector2 = -Vector2(size) / 2.0

	for i: int in cells.size():
		if cells[i] == 0:
			continue

		var density: float = materials[cells[i] - 1].density
		var p: Vector2 = origin + Vector2(i % size.x + 0.5, i / size.x + 0.5)

		mass_sum += density
		mass_moment += p * density
		mass_second_moment += p.length_squared() * density
		solid += 1

func _lap(step: StringName, since: int) -> int:
	var now: int = Time.get_ticks_usec()
	timings[step] = (now - since) / 1000.0

	return now
