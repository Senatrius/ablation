@abstract
class_name WeaponBehaviour extends Resource

@abstract
func fire(ctx: WeaponContext, def: WeaponDefinition, delta: float) -> void

func additional_stats() -> Array[PackedStringArray]:
	return []
