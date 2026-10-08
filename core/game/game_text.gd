## Number formatting for player-facing text: counts at generation 999,999 and level 99,999 run
## to a dozen digits, so headers, labels and journal lines group them in thousands.
class_name GameText
extends RefCounted


## 1234567 -> "1,234,567".
static func num(n: int) -> String:
	var digits := str(n).trim_prefix("-")
	var out := ""
	var i := digits.length()
	while i > 3:
		out = "," + digits.substr(i - 3, 3) + out
		i -= 3
	return ("-" if n < 0 else "") + digits.substr(0, i) + out
