class_name AsteroidBlueprint extends RefCounted
@warning_ignore_start("integer_division")

var asteroid_def: AsteroidDefinition
var used_seed: int
var tint_offset: Vector2i = Vector2i.ZERO
var size: Vector2i
var cells: PackedByteArray
var health: PackedFloat32Array
var materials: Array[MaterialDefinition] = []
var chunks: ChunkMap
var mass: AsteroidMass
var painter: AsteroidPainter
var image: Image
var collision_pieces: Array[PackedVector2Array] = []
var source_rect: Rect2i
var timings: Dictionary[StringName, float] = {}
var spawn_distance: float = 0.0

static func generate(definition: AsteroidDefinition, gen_seed: int, debug_chunks: bool = false, toughness_scale: float = 1.0) -> AsteroidBlueprint:
	var bp: AsteroidBlueprint = AsteroidBlueprint.new()
	var t: int = Time.get_ticks_usec()
	var generator: AsteroidGenerator = AsteroidGenerator.new(definition)

	bp.asteroid_def = definition
	bp.used_seed = gen_seed
	bp.size = Vector2i(definition.width, definition.height)
	bp.cells = generator.generate_cells(bp.size, gen_seed)
	bp.materials = generator.materials
	t = bp._lap(&"shape", t)

	bp.health.resize(bp.cells.size())
	for i: int in bp.cells.size():
		if bp.cells[i] != 0:
			bp.health[i] = bp.materials[bp.cells[i] - 1].durability

	bp.chunks = ChunkMap.build(bp.cells, bp.size, bp.materials, definition.chunk_size, definition.chunk_size_variation, definition.min_chunk_cells, definition.chunk_toughness * toughness_scale, gen_seed)
	bp.chunks.find_pockets(bp.cells, bp.materials)
	t = bp._lap(&"chunks", t)

	bp._finish(debug_chunks, t)

	return bp

static func from_fragment(definition: AsteroidDefinition, parent_seed: int, parent_tint_offset: Vector2i, parent_size: Vector2i, parent_cells: PackedByteArray, parent_health: PackedFloat32Array, parent_materials: Array[MaterialDefinition], parent_chunks: ChunkMap, indices: PackedInt32Array, debug_chunks: bool = false) -> AsteroidBlueprint:
	var bp: AsteroidBlueprint = AsteroidBlueprint.new()
	var rect: Rect2i = CellGrid.bounds(indices, parent_size.x)

	bp.asteroid_def = definition
	bp.used_seed = parent_seed
	bp.source_rect = rect
	bp.tint_offset = parent_tint_offset + rect.position
	bp.size = rect.size
	bp.cells = CellGrid.crop_bytes(parent_cells, parent_size.x, indices, rect)
	bp.health = CellGrid.crop_floats(parent_health, parent_size.x, indices, rect)
	bp.materials = parent_materials
	bp.chunks = parent_chunks.extract(rect, indices)

	bp._finish(debug_chunks, Time.get_ticks_usec())

	return bp

func total_ms() -> float:
	var total: float = 0.0
	for step: StringName in timings:
		total += timings[step]
	return total

func _finish(debug_chunks: bool, t: int) -> void:
	mass = AsteroidMass.measure(cells, size, materials)
	t = _lap(&"mass", t)

	painter = AsteroidPainter.new(size, materials, used_seed, tint_offset)
	painter.debug_chunks = debug_chunks
	image = painter.paint_all(cells, health, chunks.ids)
	t = _lap(&"paint", t)

	collision_pieces = Asteroid.collision_pieces_from(image, size)
	_lap(&"collision", t)


func _lap(step: StringName, since: int) -> int:
	var now: int = Time.get_ticks_usec()
	timings[step] = (now - since) / 1000.0
	return now
