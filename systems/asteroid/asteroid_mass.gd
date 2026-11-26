class_name AsteroidMass extends RefCounted

var total: float = 0.0
var moment: Vector2 = Vector2.ZERO
var second_moment: float = 0.0
var solid_cells: int = 0

static func measure(cells: PackedByteArray, size: Vector2i, materials: Array[MaterialDefinition]) -> AsteroidMass:
	var result: AsteroidMass = AsteroidMass.new()
	var origin: Vector2 = -Vector2(size) / 2.0

	for i: int in cells.size():
		if cells[i] != 0:
			result.change_cell(i, materials[cells[i] - 1].density, size.x, origin, 1)

	return result

func change_cell(i: int, density: float, width: int, origin: Vector2, direction: int) -> void:
	var position: Vector2 = origin + CellGrid.centre(i, width)
	var signed_density: float = density * direction

	total += signed_density
	moment += position * signed_density
	second_moment += position.length_squared() * signed_density
	solid_cells += direction

func centre() -> Vector2:
	return moment / total if total > 0.0 else Vector2.ZERO

func inertia() -> float:
	var c: Vector2 = centre()

	return second_moment - total * c.length_squared() + total / 6.0
