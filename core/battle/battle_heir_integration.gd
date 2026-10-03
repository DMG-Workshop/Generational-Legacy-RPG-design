## Battle Heir Integration: Connect battle results to heir progression
##
## Manages the complete flow: battle end → calculate rewards → apply to heir → save progress
## Handles death penalties, XP distribution, and loot persistence

class_name BattleHeirIntegration


signal battle_complete(heir: Heir, victory: bool)
signal rewards_awarded(heir: Heir, rewards: Dictionary)
signal heir_leveled_up(heir: Heir, new_level: int)
signal heir_death(heir: Heir, cause: String)


var battle_manager: BattleManager = null
var rewards_manager: BattleRewardsManager = null
var current_heir: Heir = null
var loot_catalog: LootCatalog = null

# Configuration
var xp_multiplier: float = 1.0
var currency_multiplier: float = 1.0
var difficulty_multiplier: float = 1.0


func _init(heir: Heir) -> void:
	current_heir = heir
	rewards_manager = BattleRewardsManager.new(heir)


## Set battle manager to get results from
func set_battle_manager(manager: BattleManager) -> void:
	battle_manager = manager
	if manager:
		manager.battle_ended.connect(_on_battle_ended)


## Set loot catalog for item generation
func set_loot_catalog(catalog: LootCatalog) -> void:
	loot_catalog = catalog


## Called when battle ends
func _on_battle_ended(player_won: bool, rewards: BattleRewards) -> void:
	if player_won:
		_handle_victory()
	else:
		_handle_defeat()

	battle_complete.emit(current_heir, player_won)


## Handle victory: award all rewards
func _handle_victory() -> void:
	if not battle_manager or not current_heir:
		return

	var state = battle_manager.get_state()
	var rewards_summary = battle_manager.battle.get_rewards_summary()

	# Calculate final rewards
	var final_items = rewards_summary.get("items", [])
	var final_currency = _apply_multipliers_to_currency(rewards_summary.get("currency", Currency.new()))
	var final_xp = _apply_multipliers_to_xp(rewards_summary.get("xp", {}))
	var combat_stats = rewards_summary.get("combat_stats", {})

	# Set and apply rewards
	rewards_manager.set_rewards(final_items, final_currency, final_xp, combat_stats)
	rewards_manager.apply_all_rewards()

	# Track heir's battle history
	_record_battle_victory(state, rewards_summary)

	rewards_awarded.emit(current_heir, rewards_manager.get_applied_rewards())


## Handle defeat: apply penalties
func _handle_defeat() -> void:
	if not current_heir:
		return

	# Apply defeat penalties (reduced XP, possible item loss, etc.)
	_apply_defeat_penalties()

	# Record defeat in heir history
	_record_battle_defeat()


## Apply difficulty/era multipliers to currency
func _apply_multipliers_to_currency(currency: Currency) -> Currency:
	var multiplier = xp_multiplier * difficulty_multiplier

	var adjusted = Currency.new(
		int(currency.platinum * multiplier),
		int(currency.gold * multiplier),
		int(currency.silver * multiplier),
		int(currency.copper * multiplier)
	)

	return adjusted


## Apply difficulty/era multipliers to XP
func _apply_multipliers_to_xp(xp_dict: Dictionary) -> Dictionary:
	var adjusted = {}
	var multiplier = xp_multiplier * difficulty_multiplier

	for skill in xp_dict.keys():
		adjusted[skill] = int(xp_dict[skill] * multiplier)

	return adjusted


## Record victory in heir's combat history
func _record_battle_victory(state: Battle.CombatState, rewards: Dictionary) -> void:
	if not current_heir:
		return

	# Create battle record
	var battle_record = {
		"type": "victory",
		"date": "Year %d" % current_heir.birth_year,  # Would use actual date system
		"round": state.round,
		"enemies_defeated": state.enemies.filter(func(e): return not e.is_alive).size(),
		"rewards": rewards
	}

	# Store in heir's combat history
	if not hasattr(current_heir, "combat_history"):
		current_heir.combat_history = []
	current_heir.combat_history.append(battle_record)


## Record defeat in heir's combat history
func _record_battle_defeat() -> void:
	if not current_heir:
		return

	# Create battle record
	var battle_record = {
		"type": "defeat",
		"date": "Year %d" % current_heir.birth_year
	}

	# Store in heir's combat history
	if not hasattr(current_heir, "combat_history"):
		current_heir.combat_history = []
	current_heir.combat_history.append(battle_record)


## Apply penalties for defeat
func _apply_defeat_penalties() -> void:
	if not current_heir:
		return

	# Reduced XP gain for defeat (could be 50% of normal)
	# Item loss (some items could be dropped)
	# Reputation penalty (factions lose trust)

	# For now, just record the defeat
	_record_battle_defeat()


## Check for heir leveling up
func check_skill_level_ups() -> Array[String]:
	var level_ups = []

	for skill_name in current_heir.crafting_skills.keys():
		var skill = current_heir.crafting_skills[skill_name]
		# Track level ups - this would be emitted during XP application
		level_ups.append(skill_name)

	return level_ups


## Get heir's battle summary
func get_heir_battle_summary() -> Dictionary:
	if not current_heir:
		return {}

	var total_victories = 0
	var total_defeats = 0
	var total_xp_earned = 0

	if hasattr(current_heir, "combat_history"):
		for battle in current_heir.combat_history:
			if battle.get("type") == "victory":
				total_victories += 1
			elif battle.get("type") == "defeat":
				total_defeats += 1

	return {
		"victories": total_victories,
		"defeats": total_defeats,
		"total_battles": total_victories + total_defeats,
		"wealth": current_heir.wallet.get_total_value() if current_heir.wallet else 0,
		"items": current_heir.inventory.size() if current_heir.inventory else 0,
	}


## Get heir's combat tier based on victories
func get_combat_tier() -> String:
	var summary = get_heir_battle_summary()
	var victories = summary.get("victories", 0)

	match victories:
		0:
			return "Novice"
		1, 2:
			return "Initiate"
		3, 4:
			return "Warrior"
		5, 9:
			return "Veteran"
		10, 19:
			return "Champion"
		20, 49:
			return "Hero"
		50, _:
			return "Legend"


## Save heir progression to persist across sessions
func save_heir_progression() -> Dictionary:
	if not current_heir:
		return {}

	return {
		"name": current_heir.name,
		"wallet": current_heir.wallet.get_total_value() if current_heir.wallet else 0,
		"inventory_size": current_heir.inventory.size(),
		"skills": _serialize_skills(),
		"combat_tier": get_combat_tier(),
		"battle_summary": get_heir_battle_summary()
	}


## Serialize skill progression
func _serialize_skills() -> Dictionary:
	var serialized = {}

	for skill_name in current_heir.crafting_skills.keys():
		var skill = current_heir.crafting_skills[skill_name]
		serialized[skill_name] = {
			"level": skill.level,
			"xp": skill.xp
		}

	return serialized


## Load heir progression from save
func load_heir_progression(save_data: Dictionary) -> void:
	if not save_data:
		return

	# Could restore from saved state
	# For now, this is a placeholder for future session persistence


## Helper to check if heir has attribute
func hasattr(obj: Object, attr: String) -> bool:
	return obj.get(attr) != null
