class_name StatModifier extends Resource

enum Operation {ADD, PERCENT,}

@export var stat: StringName
@export var operation: Operation = Operation.ADD
@export var value: float = 0.0
