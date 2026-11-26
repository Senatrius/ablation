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

func validate(material_ids: Array[StringName], targets: Dictionary[StringName, ContentDefinition]) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var upgrade_ids: Dictionary[StringName, bool] = {}

	for upgrade: UpgradeDefinition in upgrades:
		upgrade_ids[upgrade.id] = true

	for upgrade: UpgradeDefinition in upgrades:
		var target: ContentDefinition = targets.get(upgrade.target)

		if target == null:
			problems.append("%s: target '%s' doesn't exist" % [upgrade.id, upgrade.target])

		for required: StringName in upgrade.requires:
			if not upgrade_ids.has(required):
				problems.append("%s: requires '%s', which isn't an upgrade" % [upgrade.id, required])

		for n: int in upgrade.levels.size():
			var level: UpgradeLevel = upgrade.levels[n]

			for id: StringName in level.cost:
				if not material_ids.has(id):
					problems.append("%s level %d: costs '%s', which isn't a material" % [upgrade.id, n + 1, id])

			if target == null:
				continue

			for modifier: StatModifier in level.modifiers:
				if not modifier.stat in target:
					problems.append("%s level %d: %s has no stat '%s'" % [upgrade.id, n + 1, upgrade.target, modifier.stat])

	return problems

func find(id: StringName) -> UpgradeDefinition:
	for upgrade: UpgradeDefinition in upgrades:
		if upgrade.id == id:
			return upgrade

	return null
