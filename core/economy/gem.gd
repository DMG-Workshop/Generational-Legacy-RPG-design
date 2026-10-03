## Gem: valuable stone with type, condition, and value
##
## Condition affects value: Flawless (100%) → Damaged (30%)
## Rarity determines base value

extends Resource

class_name Gem


## Gem conditions (affect value multiplier)
enum Condition {
	FLAWLESS = 0,    # 100% value (perfect)
	EXCELLENT = 1,   # 90% value
	GOOD = 2,        # 75% value
	FAIR = 3,        # 50% value
	POOR = 4,        # 30% value
	DAMAGED = 5      # 10% value (nearly worthless)
}


## Gem rarity tiers (affects base value)
enum Rarity {
	COMMON = 0,      # 10-50 gp base
	UNCOMMON = 1,    # 50-150 gp base
	RARE = 2,        # 150-500 gp base
	VERY_RARE = 3,   # 500-2000 gp base
	LEGENDARY = 4    # 2000+ gp base
}


var gem_type: String = ""      # ruby, sapphire, emerald, diamond, etc.
var condition: int = Condition.EXCELLENT
var rarity: int = Rarity.UNCOMMON
var base_value_gp: int = 50    # Base value in gold pieces


func _init(p_type: String = "", p_condition: int = Condition.EXCELLENT, p_rarity: int = Rarity.UNCOMMON, p_value: int = 50) -> void:
	gem_type = p_type
	condition = clamp(p_condition, Condition.FLAWLESS, Condition.DAMAGED)
	rarity = clamp(p_rarity, Rarity.COMMON, Rarity.LEGENDARY)
	base_value_gp = p_value


## Get condition multiplier (0.1 to 1.0)
func get_condition_multiplier() -> float:
	match condition:
		Condition.FLAWLESS:
			return 1.0
		Condition.EXCELLENT:
			return 0.9
		Condition.GOOD:
			return 0.75
		Condition.FAIR:
			return 0.5
		Condition.POOR:
			return 0.3
		Condition.DAMAGED:
			return 0.1
	return 0.5


## Get actual value in gold pieces
func get_value_gp() -> int:
	return int(base_value_gp * get_condition_multiplier())


## Get actual value as Currency
func get_value_currency() -> Currency:
	return Currency.new(0, get_value_gp(), 0, 0)


## Get condition name
func get_condition_name() -> String:
	match condition:
		Condition.FLAWLESS:
			return "Flawless"
		Condition.EXCELLENT:
			return "Excellent"
		Condition.GOOD:
			return "Good"
		Condition.FAIR:
			return "Fair"
		Condition.POOR:
			return "Poor"
		Condition.DAMAGED:
			return "Damaged"
	return "Unknown"


## Get rarity name
func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON:
			return "Common"
		Rarity.UNCOMMON:
			return "Uncommon"
		Rarity.RARE:
			return "Rare"
		Rarity.VERY_RARE:
			return "Very Rare"
		Rarity.LEGENDARY:
			return "Legendary"
	return "Unknown"


## Get display string (e.g., "Excellent Ruby (Uncommon) - 45gp")
func to_string() -> String:
	return "%s %s (%s) - %dgp" % [
		get_condition_name(),
		gem_type.capitalize(),
		get_rarity_name(),
		get_value_gp()
	]


## Get short string (e.g., "Ruby (45gp)")
func to_short_string() -> String:
	return "%s (%dgp)" % [gem_type.capitalize(), get_value_gp()]


## Check if gem is valuable (worth at least 100 gp)
func is_valuable() -> bool:
	return get_value_gp() >= 100


## Apply damage to gem (downgrade condition)
func damage() -> void:
	if condition < Condition.DAMAGED:
		condition += 1


## Restore gem quality (upgrade condition)
func restore() -> void:
	if condition > Condition.FLAWLESS:
		condition -= 1


## Get color code for rarity
func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON:
			return Color.GRAY
		Rarity.UNCOMMON:
			return Color.GREEN
		Rarity.RARE:
			return Color.BLUE
		Rarity.VERY_RARE:
			return Color.MAGENTA
		Rarity.LEGENDARY:
			return Color.GOLD
	return Color.WHITE


## Get gem icon/emoji representation
func get_symbol() -> String:
	match gem_type.to_lower():
		"ruby":
			return "◆"
		"sapphire":
			return "◊"
		"emerald":
			return "✦"
		"diamond":
			return "★"
		"pearl":
			return "●"
		"opal":
			return "◐"
		"amethyst":
			return "▲"
		"garnet":
			return "■"
	return "◌"
