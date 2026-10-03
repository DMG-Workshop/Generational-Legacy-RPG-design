## Currency system: multi-denomination value storage and conversion
##
## Copper (cp), Silver (sp), Gold (gp), Platinum (pp)
## Conversion: 1 pp = 10 gp = 100 sp = 1000 cp

extends Resource

class_name Currency


var platinum: int = 0  # pp (highest)
var gold: int = 0     # gp (1 pp = 10 gp)
var silver: int = 0   # sp (1 gp = 10 sp)
var copper: int = 0   # cp (1 sp = 10 cp)


func _init(p_pp: int = 0, p_gp: int = 0, p_sp: int = 0, p_cp: int = 0) -> void:
	platinum = p_pp
	gold = p_gp
	silver = p_sp
	copper = p_cp
	_normalize()


## Get total value in copper pieces (smallest unit)
func to_copper() -> int:
	return (platinum * 1000) + (gold * 100) + (silver * 10) + copper


## Create from total copper value
static func from_copper(total_cp: int) -> Currency:
	var result = Currency.new()
	result.platinum = total_cp / 1000
	total_cp %= 1000
	result.gold = total_cp / 100
	total_cp %= 100
	result.silver = total_cp / 10
	result.copper = total_cp % 10
	return result


## Add another currency
func add(other: Currency) -> void:
	copper += other.copper
	silver += other.silver
	gold += other.gold
	platinum += other.platinum
	_normalize()


## Subtract another currency (returns false if insufficient)
func subtract(other: Currency) -> bool:
	if to_copper() < other.to_copper():
		return false

	var total = to_copper() - other.to_copper()
	var converted = Currency.from_copper(total)
	platinum = converted.platinum
	gold = converted.gold
	silver = converted.silver
	copper = converted.copper
	return true


## Check if has at least this much
func has(other: Currency) -> bool:
	return to_copper() >= other.to_copper()


## Compare with another currency
func equals(other: Currency) -> bool:
	return to_copper() == other.to_copper()


## Compare values
func is_greater_than(other: Currency) -> bool:
	return to_copper() > other.to_copper()


func is_less_than(other: Currency) -> bool:
	return to_copper() < other.to_copper()


## Normalize (convert overflow to higher denominations)
func _normalize() -> void:
	if copper >= 10:
		silver += copper / 10
		copper = copper % 10

	if silver >= 10:
		gold += silver / 10
		silver = silver % 10

	if gold >= 10:
		platinum += gold / 10
		gold = gold % 10


## Get display string (e.g., "5pp 3gp 7sp 2cp")
func to_string() -> String:
	var parts = []

	if platinum > 0:
		parts.append("%dp" % platinum)
	if gold > 0:
		parts.append("%dg" % gold)
	if silver > 0:
		parts.append("%ds" % silver)
	if copper > 0:
		parts.append("%dc" % copper)

	if parts.is_empty():
		return "0c"

	return " ".join(parts)


## Get short display (just highest denomination, e.g., "523sp")
func to_short_string() -> String:
	if platinum > 0:
		return "%dp" % platinum
	elif gold > 0:
		return "%dg" % gold
	elif silver > 0:
		return "%ds" % silver
	else:
		return "%dc" % copper


## Get full breakdown for UI display
func get_breakdown() -> Dictionary:
	return {
		"platinum": platinum,
		"gold": gold,
		"silver": silver,
		"copper": copper,
		"total_copper": to_copper()
	}


## Multiply currency (for pricing, scaling, etc.)
func multiply(factor: float) -> Currency:
	var total = int(to_copper() * factor)
	return Currency.from_copper(total)


## Get percentage of another currency
func percent_of(other: Currency) -> float:
	if other.to_copper() == 0:
		return 0.0
	return float(to_copper()) / float(other.to_copper()) * 100.0
