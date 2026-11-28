class_name UpgradeLevel extends Resource

@export_multiline var description: String
@export var cost: Dictionary[StringName, float]
@export var modifiers: Array[StatModifier]

func cost_grams() -> Dictionary[StringName, int]:
	var grams: Dictionary[StringName, int] = {}

	for id: StringName in cost:
		grams[id] = Mass.from_kg(cost[id])

	return grams
