class_name UpgradeList extends Resource

@export var upgrades: Array[UpgradeDefinition] = []

func on_part(part: StringName) -> Array[UpgradeDefinition]:
	return upgrades.filter(func(u: UpgradeDefinition) -> bool: return u.part == part)

func upgraded(base: ContentDefinition, levels: Dictionary[StringName, int]) -> ContentDefinition:
	var adds: Dictionary[StringName, float] = {}
	var percents: Dictionary[StringName, float] = {}

	for upgrade: UpgradeDefinition in upgrades:
		if upgrade.target != base.id:
			continue

		var owned: int = mini(levels.get(upgrade.id, 0), upgrade.max_level())

		for n: int in owned:
			for modifier: StatModifier in upgrade.levels[n].modifiers:
				var totals: Dictionary[StringName, float] = adds if modifier.operation == StatModifier.Operation.ADD else percents
				totals[modifier.stat] = totals.get(modifier.stat, 0.0) + modifier.value

	var result: ContentDefinition = base.duplicate()

	for stat: StringName in _union(adds, percents):
		var value: float = (float(result.get(stat)) + adds.get(stat, 0.0)) * (1.0 + percents.get(stat, 0.0) / 100.0)

		if typeof(result.get(stat)) == TYPE_INT:
			result.set(stat, roundi(value))
		else:
			result.set(stat, value)

	return result

static func _union(a: Dictionary[StringName, float], b: Dictionary[StringName, float]) -> Array[StringName]:
	var keys: Array[StringName] = []
	keys.assign(a.keys())

	for key: StringName in b:
		if not keys.has(key):
			keys.append(key)

	return keys
