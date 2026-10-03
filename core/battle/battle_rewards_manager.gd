## Battle Rewards Manager: Apply battle rewards to heir progression
##
## Handles currency distribution, item collection, XP gains, and stat tracking
## Integrates battle results with heir's inventory, skills, and reputation systems

class_name BattleRewardsManager


signal rewards_applied(heir: Heir, rewards: Dictionary)
signal item_acquired(heir: Heir, item: Equipment)
signal skill_xp_gained(heir: Heir, skill: String, amount: int)
signal level_up(heir: Heir, skill: String)


var current_heir: Heir = null
var rewards_data: Dictionary = {}

# Tracking for rewards application
var applied_currency: Dictionary = {}
var applied_items: Array[Equipment] = []
var applied_xp: Dictionary = {}


func _init(heir: Heir = null) -> void:
	current_heir = heir


## Set the heir to receive rewards
func set_heir(heir: Heir) -> void:
	current_heir = heir


## Set reward data from battle system
func set_rewards(items: Array[Equipment], currency: Currency, xp: Dictionary, combat_stats: Dictionary) -> void:
	rewards_data = {
		"items": items,
		"currency": currency,
		"xp": xp,
		"combat_stats": combat_stats
	}


## Apply all rewards to heir
func apply_all_rewards() -> bool:
	if not current_heir:
		return false

	_apply_currency()
	_apply_items()
	_apply_xp()
	_apply_combat_stats()

	rewards_applied.emit(current_heir, rewards_data)
	return true


## Apply currency rewards
func _apply_currency() -> void:
	var currency = rewards_data.get("currency", null)
	if not currency or not current_heir:
		return

	# Add to heir's wallet
	current_heir.wallet.platinum += currency.platinum
	current_heir.wallet.gold += currency.gold
	current_heir.wallet.silver += currency.silver
	current_heir.wallet.copper += currency.copper

	applied_currency = {
		"platinum": currency.platinum,
		"gold": currency.gold,
		"silver": currency.silver,
		"copper": currency.copper,
		"total_value": currency.platinum * 1000 + currency.gold * 100 + currency.silver * 10 + currency.copper
	}


## Apply item rewards
func _apply_items() -> void:
	var items = rewards_data.get("items", [])
	if items.is_empty() or not current_heir:
		return

	for item in items:
		if item is Equipment:
			current_heir.inventory.append(item)
			applied_items.append(item)
			item_acquired.emit(current_heir, item)


## Apply XP rewards to skills
func _apply_xp() -> void:
	var xp_rewards = rewards_data.get("xp", {})
	if xp_rewards.is_empty() or not current_heir:
		return

	for skill_name in xp_rewards.keys():
		var xp_amount = xp_rewards[skill_name]
		if xp_amount <= 0:
			continue

		# Get or create skill
		if skill_name not in current_heir.crafting_skills:
			var new_skill = CraftingSkill.new()
			new_skill.skill_type = skill_name
			new_skill.xp = 0
			new_skill.level = 1
			current_heir.crafting_skills[skill_name] = new_skill

		var skill = current_heir.crafting_skills[skill_name]
		var old_level = skill.level

		# Award XP
		skill.xp += xp_amount
		applied_xp[skill_name] = xp_amount

		# Check for level up (every 100 XP)
		while skill.xp >= 100:
			skill.xp -= 100
			skill.level += 1
			if skill.level > old_level:
				level_up.emit(current_heir, skill_name)

		skill_xp_gained.emit(current_heir, skill_name, xp_amount)


## Apply combat statistics tracking
func _apply_combat_stats() -> void:
	var stats = rewards_data.get("combat_stats", {})
	if stats.is_empty() or not current_heir:
		return

	# Store combat statistics on heir for reference/tracking
	# These could be used for achievements, leaderboards, etc.
	if not hasattr(current_heir, "total_combat_stats"):
		current_heir.total_combat_stats = {}

	for stat_name in stats.keys():
		if stat_name not in current_heir.total_combat_stats:
			current_heir.total_combat_stats[stat_name] = 0

		current_heir.total_combat_stats[stat_name] += stats[stat_name]


## Get summary of applied rewards
func get_applied_rewards() -> Dictionary:
	return {
		"currency": applied_currency,
		"items": applied_items,
		"xp": applied_xp,
	}


## Get reward summary text for display
func get_reward_summary() -> Array[String]:
	var summary = []

	# Currency summary
	if applied_currency.size() > 0:
		var value = applied_currency.get("total_value", 0)
		summary.append("Gold earned: %d" % applied_currency.get("gold", 0))

	# Items summary
	if applied_items.size() > 0:
		summary.append("Items acquired: %d" % applied_items.size())

	# XP summary
	if applied_xp.size() > 0:
		for skill in applied_xp.keys():
			var amount = applied_xp[skill]
			summary.append("%s XP: +%d" % [skill, amount])

	return summary


## Check if item is legendary
func is_legendary_item(item: Equipment) -> bool:
	if not item:
		return false
	return item.rarity == "Legendary"


## Get legendary items from rewards
func get_legendary_items() -> Array[Equipment]:
	var legendaries = []
	for item in applied_items:
		if is_legendary_item(item):
			legendaries.append(item)
	return legendaries


## Clear applied rewards for next battle
func clear() -> void:
	rewards_data = {}
	applied_currency = {}
	applied_items = []
	applied_xp = {}


## Helper to check if heir has attribute (duck typing support)
func hasattr(obj: Object, attr: String) -> bool:
	return obj.get(attr) != null
