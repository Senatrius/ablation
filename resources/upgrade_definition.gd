class_name UpgradeDefinition extends ContentDefinition

@export var part: StringName
@export var target: StringName
@export var icon: Texture2D
@export var levels: Array[UpgradeLevel] = []
@export var requires: Dictionary[StringName, int] = {}

func max_level() -> int:
	return levels.size()

func next_level(current: int) -> UpgradeLevel:
	return levels[current] if current < levels.size() else null
