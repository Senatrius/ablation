class_name MaterialLadder extends Resource

@export var steps: Array[MaterialDefinition] = []

func at(step: int) -> MaterialDefinition:
	return steps[clampi(step, 0, steps.size() - 1)]
