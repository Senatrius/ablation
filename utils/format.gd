class_name Format extends RefCounted

static func number(amount: int) -> String:
	var digits: String = str(absi(amount))
	var result: String = ""

	while digits.length() > 3:
		result = "," + digits.right(3) + result
		digits = digits.left(digits.length() - 3)

	return ("-" if amount < 0 else "") + digits + result
