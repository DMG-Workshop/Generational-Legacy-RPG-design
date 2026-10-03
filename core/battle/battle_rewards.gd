## Battle Rewards: tracks all items and currency gained during a battle
##
## Collects drops from defeated enemies, applies enchantments to rare items,
## and provides summary of all rewards earned

class_name BattleRewards


## Reward data structure
class Reward:
	var item: Item
	var source_enemy: String  # Enemy name that dropped it
	var rarity: int
	var is_enchanted: bool = false

	func _init(p_item: Item, p_source: String) -> void:
		item = p_item
		source_enemy = p_source
		rarity = p_item.rarity
		is_enchanted = p_item.get_property("enchantments") != null


## All rewards collected in this battle
var rewards: Array[Reward] = []

## Total currency earned
var currency_reward: Currency = Currency.new(0, 0, 0, 0)

## Track which enemies have dropped loot (prevent duplication)
var enemies_looted: Dictionary = {}


func _init() -> void:
	pass


## Add a reward item to the collection
func add_reward(item: Item, source_enemy: String = "Unknown") -> void:
	if not item:
		return

	var reward = Reward.new(item, source_enemy)
	rewards.append(reward)


## Add currency reward
func add_currency(amount: Currency) -> void:
	if amount:
		currency_reward.add(amount)


## Get all rewards collected
func get_all_rewards() -> Array[Reward]:
	return rewards.duplicate()


## Get rewards by type
func get_rewards_by_type(item_type: int) -> Array[Reward]:
	return rewards.filter(func(r): return r.item.item_type == item_type)


## Get rewards by rarity
func get_rewards_by_rarity(rarity: int) -> Array[Reward]:
	return rewards.filter(func(r): return r.rarity == rarity)


## Get enchanted rewards
func get_enchanted_rewards() -> Array[Reward]:
	return rewards.filter(func(r): return r.is_enchanted)


## Get reward summary as dictionary
func get_reward_summary() -> Dictionary:
	var summary = {
		"total_items": rewards.size(),
		"total_currency": currency_reward.to_copper(),
		"by_type": {},
		"by_rarity": {},
		"enchanted_count": 0,
		"items": []
	}

	# Count by type
	for reward in rewards:
		var type_name = reward.item.get_type_name()
		if type_name not in summary["by_type"]:
			summary["by_type"][type_name] = 0
		summary["by_type"][type_name] += 1

		# Count by rarity
		var rarity_name = reward.item.get_rarity_name()
		if rarity_name not in summary["by_rarity"]:
			summary["by_rarity"][rarity_name] = 0
		summary["by_rarity"][rarity_name] += 1

		# Count enchanted
		if reward.is_enchanted:
			summary["enchanted_count"] += 1

		# Add item detail
		summary["items"].append({
			"name": reward.item.name,
			"type": type_name,
			"rarity": rarity_name,
			"value": reward.item.value.to_copper(),
			"source": reward.source_enemy,
			"enchanted": reward.is_enchanted
		})

	return summary


## Check if enemy has been looted already
func is_enemy_looted(enemy_name: String) -> bool:
	return enemy_name in enemies_looted


## Mark enemy as looted
func mark_enemy_looted(enemy_name: String) -> void:
	enemies_looted[enemy_name] = true


## Clear all rewards
func clear() -> void:
	rewards.clear()
	currency_reward = Currency.new(0, 0, 0, 0)
	enemies_looted.clear()


## Get total item count
func get_total_items() -> int:
	return rewards.size()


## Get total value of all rewards in copper
func get_total_value() -> int:
	var total = currency_reward.to_copper()
	for reward in rewards:
		total += reward.item.value.to_copper()
	return total


## Get string representation
func to_string() -> String:
	return "BattleRewards(items:%d, value:%d copper, currency:%d copper)" % [
		rewards.size(),
		get_total_value(),
		currency_reward.to_copper()
	]
