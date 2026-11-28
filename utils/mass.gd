class_name Mass extends RefCounted

const GRAMS_PER_KG: int = 1000

static func from_kg(kg: float) -> int:
	return roundi(kg * GRAMS_PER_KG)

static func format(grams: int, step: int = 10) -> String:
	var rounded: int = roundi(float(grams) / step) * step

	if absi(rounded) < GRAMS_PER_KG:
		return "%d g" % rounded

	var decimals: int = 0
	if step < 10:
		decimals = 3
	elif step < 100:
		decimals = 2
	elif step < 1000:
		decimals = 1

	var text: String = String.num(rounded / float(GRAMS_PER_KG), decimals)
	var parts: PackedStringArray = text.split(".")
	var whole: String = Format.number(int(parts[0]))

	return whole + ("." + parts[1] if parts.size() > 1 else "") + "Kg"
