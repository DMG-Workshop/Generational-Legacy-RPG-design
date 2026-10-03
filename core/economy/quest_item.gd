## Quest Item: items tied to specific quests
##
## Not tradeable, only obtained through quest progression

extends Item

class_name QuestItem


## Quest this item is tied to
var quest_id: String = ""

## Quest stage this item is relevant to
var quest_stage: String = ""

## Whether this item is a quest objective
var is_objective: bool = false

## What happens when item is used/turned in
var turn_in_reward: Dictionary = {}  # {"gold": 100, "reputation": 10, etc.}

## Whether quest completes when this item is obtained
var completes_quest_on_obtain: bool = false

## Custom flavor text
var lore: String = ""


func _init(
	p_id: String = "",
	p_name: String = "",
	p_quest_id: String = "",
	p_value: Currency = null
) -> void:
	super._init(p_id, p_name, ItemType.QUEST_ITEM, Item.Rarity.UNCOMMON, p_value)
	quest_id = p_quest_id
	is_tradeable = false
	is_stackable = false


## Get detailed string with lore
func to_detailed_string() -> String:
	var str = super.to_detailed_string()
	if not lore.is_empty():
		str += "\n[Lore]\n%s\n" % lore
	if is_objective:
		str += "\n⚡ Quest Objective\n"
	if not turn_in_reward.is_empty():
		str += "\n[Turn-in Rewards]\n"
		for reward_type in turn_in_reward:
			str += "%s: %s\n" % [reward_type.capitalize(), turn_in_reward[reward_type]]
	return str


## Get turn-in reward for display
func get_turn_in_display() -> String:
	if turn_in_reward.is_empty():
		return "No reward"

	var rewards: Array[String] = []
	for reward_type in turn_in_reward:
		rewards.append("%s %s" % [turn_in_reward[reward_type], reward_type.capitalize()])

	return ", ".join(rewards)


## Create a simple quest item
static func create_quest_item(
	p_id: String,
	p_name: String,
	p_quest_id: String,
	p_stage: String,
	value: Currency
) -> QuestItem:
	var item = QuestItem.new(p_id, p_name, p_quest_id, value)
	item.quest_stage = p_stage
	item.is_objective = true
	return item


## Create collectible quest item (multiple copies needed)
static func create_collectible(
	p_id: String,
	p_name: String,
	p_quest_id: String,
	quantity_needed: int,
	value: Currency
) -> QuestItem:
	var item = QuestItem.new(p_id, p_name, p_quest_id, value)
	item.is_objective = true
	item.turn_in_reward["progress"] = quantity_needed
	return item


## Create key item (used to unlock something)
static func create_key_item(
	p_id: String,
	p_name: String,
	p_quest_id: String,
	unlocks: String,
	value: Currency
) -> QuestItem:
	var item = QuestItem.new(p_id, p_name, p_quest_id, value)
	item.description = "Unlocks: %s" % unlocks
	item.is_objective = true
	return item
