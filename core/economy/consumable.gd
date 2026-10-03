## Consumable: items that can be used and are consumed
##
## Potions, scrolls, food, etc.

extends Item

class_name Consumable


## Effect type (determines what the consumable does)
enum EffectType {
	HEAL = 0,
	MANA_RESTORE = 1,
	BUFF = 2,
	CURE = 3,
	SPECIAL = 4
}


## How the consumable is used
var effect_type: int = EffectType.HEAL

## Amount restored/healed
var effect_amount: int = 20

## Duration (in turns, 0 = instant)
var effect_duration: int = 0

## Stat boost (for buff consumables)
var stat_boost: String = ""  # "strength", "dexterity", etc.
var boost_amount: int = 0

## What this cures (for cure consumables)
var cures: Array[String] = []  # "poison", "curse", etc.

## Required level to use
var required_level: int = 1

## Cooldown (in seconds) before can use again
var cooldown: int = 0
var last_used_time: int = 0


func _init(
	p_id: String = "",
	p_name: String = "",
	p_effect: int = EffectType.HEAL,
	p_value: Currency = null
) -> void:
	super._init(p_id, p_name, ItemType.CONSUMABLE, Item.Rarity.COMMON, p_value)
	effect_type = p_effect
	is_stackable = true
	max_stack = 99


## Get effect type name
func get_effect_name() -> String:
	match effect_type:
		EffectType.HEAL:
			return "Heal"
		EffectType.MANA_RESTORE:
			return "Mana Restore"
		EffectType.BUFF:
			return "Buff"
		EffectType.CURE:
			return "Cure"
		EffectType.SPECIAL:
			return "Special"
	return "Unknown"


## Check if consumable is on cooldown
func is_on_cooldown() -> bool:
	if cooldown == 0:
		return false

	var elapsed = (Time.get_ticks_msec() - last_used_time) / 1000
	return elapsed < cooldown


## Get remaining cooldown time
func get_remaining_cooldown() -> int:
	if not is_on_cooldown():
		return 0

	var elapsed = (Time.get_ticks_msec() - last_used_time) / 1000
	return cooldown - elapsed


## Mark as used (sets cooldown timer)
func mark_used() -> void:
	last_used_time = Time.get_ticks_msec()


## Get description of effect
func get_effect_description() -> String:
	match effect_type:
		EffectType.HEAL:
			return "Restores %d HP" % effect_amount
		EffectType.MANA_RESTORE:
			return "Restores %d Mana" % effect_amount
		EffectType.BUFF:
			return "Increases %s by %d for %d turns" % [stat_boost, boost_amount, effect_duration]
		EffectType.CURE:
			return "Cures: %s" % ", ".join(cures)
		EffectType.SPECIAL:
			return description
	return "Unknown effect"


## Get detailed string
func to_detailed_string() -> String:
	var str = super.to_detailed_string()
	str += "\nEffect: %s\n" % get_effect_name()
	str += get_effect_description() + "\n"
	if required_level > 1:
		str += "Required Level: %d\n" % required_level
	if cooldown > 0:
		str += "Cooldown: %ds\n" % cooldown
	return str


## Create a healing potion
static func create_potion(
	p_id: String,
	p_name: String,
	heal_amount: int,
	value: Currency
) -> Consumable:
	var potion = Consumable.new(p_id, p_name, EffectType.HEAL, value)
	potion.effect_amount = heal_amount
	return potion


## Create a mana potion
static func create_mana_potion(
	p_id: String,
	p_name: String,
	mana_amount: int,
	value: Currency
) -> Consumable:
	var potion = Consumable.new(p_id, p_name, EffectType.MANA_RESTORE, value)
	potion.effect_amount = mana_amount
	return potion


## Create a buff consumable
static func create_buff(
	p_id: String,
	p_name: String,
	stat: String,
	amount: int,
	duration: int,
	value: Currency
) -> Consumable:
	var buff = Consumable.new(p_id, p_name, EffectType.BUFF, value)
	buff.stat_boost = stat
	buff.boost_amount = amount
	buff.effect_duration = duration
	return buff


## Create a cure consumable
static func create_cure(
	p_id: String,
	p_name: String,
	cures_array: Array[String],
	value: Currency
) -> Consumable:
	var cure = Consumable.new(p_id, p_name, EffectType.CURE, value)
	cure.cures = cures_array
	return cure
