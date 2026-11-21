class_name ChunkMap extends RefCounted

const EMPTY: int = -1

var size: Vector2i
var ids: PackedInt32Array
var hp: PackedFloat32Array
var damage: PackedFloat32Array
var neighbours: Array[PackedInt32Array] = []
var members: Array[PackedInt32Array] = []


static func build(cells: PackedByteArray, grid_size: Vector2i, materials: Array[MaterialDefinition], chunk_size: float, size_variation: float, min_cells: int, toughness: float, rng_seed: int) -> ChunkMap:
	var regions: PackedInt32Array = _voronoi_regions(cells, grid_size, chunk_size, size_variation, rng_seed)
	var labels: PackedInt32Array = _label_components(cells, grid_size, regions)
	var roots: PackedInt32Array = _merge_small(cells, grid_size, labels, min_cells)
	var map: ChunkMap = ChunkMap.new()
	map.size = grid_size

	var compact: PackedInt32Array = PackedInt32Array()
	compact.resize(roots.size())
	compact.fill(EMPTY)
	var chunk_count: int = 0

	for label: int in roots.size():
		var root: int = roots[label]
		if compact[root] == EMPTY:
			compact[root] = chunk_count
			chunk_count += 1

	map.ids.resize(cells.size())
	map.ids.fill(EMPTY)
	map.hp.resize(chunk_count)
	map.hp.fill(0.0)
	map.damage.resize(chunk_count)
	map.damage.fill(0.0)

	for i: int in cells.size():
		if labels[i] == EMPTY:
			continue

		var id: int = compact[roots[labels[i]]]
		map.ids[i] = id
		map.hp[id] += materials[cells[i] - 1].durability * toughness

	map._build_neighbours(chunk_count)
	map._rebuild_members(chunk_count)
	return map

func extract(rect: Rect2i, indices: PackedInt32Array) -> ChunkMap:
	var map: ChunkMap = ChunkMap.new()
	map.size = rect.size
	map.ids.resize(rect.size.x * rect.size.y)
	map.ids.fill(EMPTY)

	for i: int in indices:
		var x: int = i % size.x - rect.position.x
		var y: int = i / size.x - rect.position.y
		map.ids[y * rect.size.x + x] = ids[i]

	map.hp = hp
	map.damage = damage.duplicate()
	map.neighbours = neighbours
	map._rebuild_members(hp.size())
	return map

func forget(chunk: int) -> void:
	for i: int in members[chunk]:
		ids[i] = EMPTY
	members[chunk] = PackedInt32Array()

func has_chunk(chunk: int) -> bool:
	return not members[chunk].is_empty()

func fraction(chunk: int) -> float:
	return damage[chunk] / maxf(hp[chunk], 0.001)

func _rebuild_members(chunk_count: int) -> void:
	members.clear()
	for c: int in chunk_count:
		members.append(PackedInt32Array())

	for i: int in ids.size():
		var c: int = ids[i]

		if c == EMPTY:
			continue

		var list: PackedInt32Array = members[c]
		list.append(i)
		members[c] = list

func _build_neighbours(chunk_count: int) -> void:
	var sets: Array[Dictionary] = []
	for c: int in chunk_count:
		sets.append({})

	for y: int in size.y:
		for x: int in size.x:
			var i: int = y * size.x + x
			var c: int = ids[i]

			if c == EMPTY:
				continue

			if x < size.x - 1:
				_link(sets, c, ids[i + 1])

			if y < size.y - 1:
				_link(sets, c, ids[i + size.x])

	neighbours.clear()
	for c: int in chunk_count:
		neighbours.append(PackedInt32Array(sets[c].keys()))

static func _link(sets: Array[Dictionary], a: int, b: int) -> void:
	if b == EMPTY or b == a:
		return
	sets[a][b] = true
	sets[b][a] = true

static func _voronoi_regions(cells: PackedByteArray, grid_size: Vector2i, chunk_size: float,
		size_variation: float, rng_seed: int) -> PackedInt32Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed

	var grid: Vector2i = Vector2i(ceili(grid_size.x / chunk_size), ceili(grid_size.y / chunk_size))
	var seeds: PackedVector2Array = PackedVector2Array()
	var weights: PackedFloat32Array = PackedFloat32Array()

	for gy: int in grid.y:
		for gx: int in grid.x:
			seeds.append((Vector2(gx, gy) + Vector2(rng.randf(), rng.randf())) * chunk_size)
			weights.append(rng.randf_range(-size_variation, size_variation) * chunk_size * chunk_size)

	var warp: FastNoiseLite = FastNoiseLite.new()
	warp.seed = rng_seed
	warp.frequency = 0.5 / chunk_size
	var warp_amount: float = chunk_size * 0.4

	var regions: PackedInt32Array = PackedInt32Array()
	regions.resize(cells.size())
	regions.fill(EMPTY)

	for y: int in grid_size.y:
		for x: int in grid_size.x:
			var i: int = y * grid_size.x + x
			if cells[i] == 0:
				continue

			var p: Vector2 = Vector2(x + 0.5, y + 0.5)
			p += Vector2(warp.get_noise_2d(x, y), warp.get_noise_2d(x + 512.0, y - 512.0)) * warp_amount

			var gx: int = clampi(floori(p.x / chunk_size), 0, grid.x - 1)
			var gy: int = clampi(floori(p.y / chunk_size), 0, grid.y - 1)
			var best: int = EMPTY
			var best_score: float = INF

			for oy: int in range(maxi(gy - 1, 0), mini(gy + 2, grid.y)):
				for ox: int in range(maxi(gx - 1, 0), mini(gx + 2, grid.x)):
					var g: int = oy * grid.x + ox
					var score: float = p.distance_squared_to(seeds[g]) - weights[g]

					if score < best_score:
						best_score = score
						best = g

			regions[i] = best

	return regions

static func _label_components(cells: PackedByteArray, grid_size: Vector2i, regions: PackedInt32Array) -> PackedInt32Array:
	var labels: PackedInt32Array = PackedInt32Array()
	labels.resize(cells.size())
	labels.fill(EMPTY)

	var queue: PackedInt32Array = PackedInt32Array()
	var next: int = 0

	for start: int in cells.size():
		if cells[start] == 0 or labels[start] != EMPTY:
			continue

		labels[start] = next
		queue.clear()
		queue.append(start)
		var head: int = 0
		while head < queue.size():
			var i: int = queue[head]
			head += 1
			var x: int = i % grid_size.x
			if x > 0:
				_join(i, i - 1, cells, regions, labels, queue)
			if x < grid_size.x - 1:
				_join(i, i + 1, cells, regions, labels, queue)
			if i >= grid_size.x:
				_join(i, i - grid_size.x, cells, regions, labels, queue)
			if i < cells.size() - grid_size.x:
				_join(i, i + grid_size.x, cells, regions, labels, queue)
		next += 1

	return labels

static func _join(from: int, to: int, cells: PackedByteArray, regions: PackedInt32Array,
		labels: PackedInt32Array, queue: PackedInt32Array) -> void:
	if labels[to] == EMPTY and cells[to] == cells[from] and regions[to] == regions[from]:
		labels[to] = labels[from]
		queue.append(to)

static func _merge_small(cells: PackedByteArray, grid_size: Vector2i, labels: PackedInt32Array, min_cells: int) -> PackedInt32Array:
	var count: int = 0
	for label: int in labels:
		count = maxi(count, label + 1)

	var sizes: PackedInt32Array = PackedInt32Array()
	sizes.resize(count)
	sizes.fill(0)

	for label: int in labels:
		if label != EMPTY:
			sizes[label] += 1

	var target: PackedInt32Array = PackedInt32Array()
	target.resize(count)
	target.fill(EMPTY)

	var target_score: PackedFloat32Array = PackedFloat32Array()
	target_score.resize(count)
	target_score.fill(-1.0)

	for y: int in grid_size.y:
		for x: int in grid_size.x:
			var i: int = y * grid_size.x + x
			var c: int = labels[i]
			if c == EMPTY or sizes[c] >= min_cells:
				continue
			if x > 0:
				_consider(i, i - 1, c, cells, labels, sizes, target, target_score)
			if x < grid_size.x - 1:
				_consider(i, i + 1, c, cells, labels, sizes, target, target_score)
			if y > 0:
				_consider(i, i - grid_size.x, c, cells, labels, sizes, target, target_score)
			if y < grid_size.y - 1:
				_consider(i, i + grid_size.x, c, cells, labels, sizes, target, target_score)

	var roots: PackedInt32Array = PackedInt32Array()
	roots.resize(count)
	for c: int in count:
		var r: int = c
		while target[r] != EMPTY:
			r = target[r]
		roots[c] = r
	return roots

static func _consider(i: int, n: int, c: int, cells: PackedByteArray, labels: PackedInt32Array, sizes: PackedInt32Array, target: PackedInt32Array, target_score: PackedFloat32Array) -> void:
	var d: int = labels[n]
	if d == EMPTY or d == c:
		return

	if sizes[d] < sizes[c] or (sizes[d] == sizes[c] and d > c):
		return

	var score: float = float(sizes[d]) + (1_000_000.0 if cells[n] == cells[i] else 0.0)

	if score > target_score[c]:
		target_score[c] = score
		target[c] = d
