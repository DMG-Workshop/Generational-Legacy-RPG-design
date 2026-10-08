## Number formatting for player-facing text: counts at generation 999,999 and level 99,999 run
## to a dozen digits, so headers, labels and journal lines group them in thousands.
class_name GameText
extends RefCounted

static var _long_number: RegEx


## 1234567 -> "1,234,567".
static func num(n: int) -> String:
	var digits := str(n).trim_prefix("-")
	var out := ""
	var i := digits.length()
	while i > 3:
		out = "," + digits.substr(i - 3, 3) + out
		i -= 3
	return ("-" if n < 0 else "") + digits.substr(0, i) + out


## 1234 -> "+1,234", -1234 -> "-1,234".
static func signed(n: int) -> String:
	return ("+" if n >= 0 else "") + num(n)


## Groups every standalone whole number of four digits or more in a finished line, for text built
## elsewhere (the battle log): "hits the drake for 1234567." -> "hits the drake for 1,234,567."
static func group_numbers(text: String) -> String:
	if _long_number == null:
		_long_number = RegEx.create_from_string("(?<![\\w#])\\d{4,18}(?!\\w)")
	var out := ""
	var at := 0
	for m in _long_number.search_all(text):
		out += text.substr(at, m.get_start() - at) + num(int(m.get_string()))
		at = m.get_end()
	return out + text.substr(at)
