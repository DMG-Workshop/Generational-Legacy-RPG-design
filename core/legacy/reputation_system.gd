## Reputation System: Track dynasty reputation with factions across generations
##
## Manages faction standing, reputation decay, reputation-based perks, and how dynasty
## choices ripple through the world affecting future generations' interactions.

extends Node

class_name ReputationSystem


signal reputation_changed(faction_id: String, new_reputation: int)
signal faction_unlocked(faction_id: String)
signal faction_perk_earned(faction_id: String, perk_id: String)
signal reputation_tier_reached(faction_id: String, tier: String)


enum ReputationTier { HATED, DISLIKED, NEUTRAL, LIKED, REVERED, LEGENDARY }


var factions: Dictionary = {}  # faction_id -> FactionProfile
var faction_perks: Dictionary = {}  # faction_id -> [perk_id, ...]
var generational_reputation_history: Dictionary = {}  # generation -> faction_standing


class Faction:
	var faction_id: String
	var name: String
	var description: String
	var alignment: String  # "good", "neutral", "evil"
	var prestige_unlock_requirement: int
	var base_reputation: int
	var max_reputation: int

	func _init(p_id: String, p_name: String) -> void:
		faction_id = p_id
		name = p_name
		description = ""
		alignment = "neutral"
		prestige_unlock_requirement = 0
		base_reputation = 0
		max_reputation = 10000


class FactionProfile:
	var faction_id: String
	var current_reputation: int
	var lifetime_reputation_gained: int
	var lifetime_reputation_lost: int
	var tier: int  # 0-5 (HATED to LEGENDARY)
	var perks_unlocked: Array
	var quest_completed_count: int
	var generation_discovered: int
	var last_action_generation: int
	var reputation_decay_rate: float  # Per generation

	func _init(p_faction_id: String) -> void:
		faction_id = p_faction_id
		current_reputation = 0
		lifetime_reputation_gained = 0
		lifetime_reputation_lost = 0
		tier = ReputationTier.NEUTRAL
		perks_unlocked = []
		quest_completed_count = 0
		generation_discovered = 0
		last_action_generation = 0
		reputation_decay_rate = 0.95  # 5% decay per generation


class FactionPerk:
	var perk_id: String
	var perk_name: String
	var description: String
	var reputation_requirement: int
	var effect_type: String  # "combat_bonus", "reward_multiplier", "ability_unlock", etc.
	var effect_value: float
	var prestige_requirement: int

	func _init(p_id: String, p_name: String) -> void:
		perk_id = p_id
		perk_name = p_name
		description = ""
		reputation_requirement = 0
		effect_type = ""
		effect_value = 1.0
		prestige_requirement = 0


func _init() -> void:
	_initialize_factions()
	_initialize_perks()


func register_faction(faction: Faction) -> void:
	factions[faction.faction_id] = faction
	var profile = FactionProfile.new(faction.faction_id)
	profile.current_reputation = faction.base_reputation
	factions[faction.faction_id + "_profile"] = profile


func get_faction(faction_id: String) -> Faction:
	return factions.get(faction_id, null)


func get_faction_profile(faction_id: String) -> FactionProfile:
	return factions.get(faction_id + "_profile", null)


func add_reputation(faction_id: String, amount: int, prestige: int) -> bool:
	var profile = get_faction_profile(faction_id)
	if not profile:
		return false

	# Prestige scales reputation gain
	var prestige_multiplier = 1.0 + (prestige / 100000.0) * 0.5  # Up to 1.5x at max prestige
	var actual_gain = int(amount * prestige_multiplier)

	profile.current_reputation = min(profile.current_reputation + actual_gain, profile.faction_id in factions and factions[profile.faction_id].max_reputation or 10000)
	profile.lifetime_reputation_gained += actual_gain

	_check_reputation_tier_change(faction_id)
	reputation_changed.emit(faction_id, profile.current_reputation)

	return true


func subtract_reputation(faction_id: String, amount: int) -> bool:
	var profile = get_faction_profile(faction_id)
	if not profile:
		return false

	profile.current_reputation = max(profile.current_reputation - amount, -10000)
	profile.lifetime_reputation_lost += amount

	_check_reputation_tier_change(faction_id)
	reputation_changed.emit(faction_id, profile.current_reputation)

	return true


func get_reputation(faction_id: String) -> int:
	var profile = get_faction_profile(faction_id)
	if profile:
		return profile.current_reputation
	return 0


func get_reputation_tier(faction_id: String) -> String:
	var profile = get_faction_profile(faction_id)
	if not profile:
		return "UNKNOWN"

	match profile.tier:
		ReputationTier.HATED:
			return "HATED"
		ReputationTier.DISLIKED:
			return "DISLIKED"
		ReputationTier.NEUTRAL:
			return "NEUTRAL"
		ReputationTier.LIKED:
			return "LIKED"
		ReputationTier.REVERED:
			return "REVERED"
		ReputationTier.LEGENDARY:
			return "LEGENDARY"

	return "UNKNOWN"


func is_faction_available(faction_id: String, prestige: int) -> bool:
	var faction = get_faction(faction_id)
	if not faction:
		return false

	return prestige >= faction.prestige_unlock_requirement


func check_faction_unlock(faction_id: String, prestige: int, generation: int) -> bool:
	var profile = get_faction_profile(faction_id)
	if not profile:
		return false

	if not is_faction_available(faction_id, prestige):
		return false

	if profile.generation_discovered == 0:
		profile.generation_discovered = generation
		faction_unlocked.emit(faction_id)
		return true

	return false


func get_faction_perk_bonus(faction_id: String, perk_id: String) -> float:
	var perk = faction_perks.get(faction_id + "_" + perk_id, null)
	if perk:
		var profile = get_faction_profile(faction_id)
		if profile and perk.reputation_requirement <= profile.current_reputation:
			return perk.effect_value
	return 1.0


func earn_faction_perk(faction_id: String, perk_id: String) -> bool:
	var profile = get_faction_profile(faction_id)
	if not profile:
		return false

	if perk_id not in profile.perks_unlocked:
		profile.perks_unlocked.append(perk_id)
		faction_perk_earned.emit(faction_id, perk_id)
		return true

	return false


func apply_reputation_decay(generation: int) -> void:
	for faction_id in factions.keys():
		if not faction_id.ends_with("_profile"):
			continue

		var profile = factions[faction_id]
		var decay_multiplier = pow(profile.reputation_decay_rate, generation - profile.last_action_generation)
		profile.current_reputation = int(profile.current_reputation * decay_multiplier)

		_check_reputation_tier_change(faction_id.trim_suffix("_profile"))


func get_reputation_report(faction_id: String) -> Dictionary:
	var profile = get_faction_profile(faction_id)
	if not profile:
		return {}

	return {
		"faction_id": faction_id,
		"current_reputation": profile.current_reputation,
		"tier": get_reputation_tier(faction_id),
		"lifetime_gained": profile.lifetime_reputation_gained,
		"lifetime_lost": profile.lifetime_reputation_lost,
		"perks_unlocked": profile.perks_unlocked.duplicate(),
		"quests_completed": profile.quest_completed_count,
		"generation_discovered": profile.generation_discovered
	}


func get_all_factions_report() -> Dictionary:
	var report = {
		"factions": {},
		"total_reputation": 0,
		"avg_tier": "NEUTRAL"
	}

	var tier_sum = 0
	var faction_count = 0

	for faction_id in factions.keys():
		if not faction_id.ends_with("_profile"):
			var faction_report = get_reputation_report(faction_id)
			if faction_report:
				report["factions"][faction_id] = faction_report
				report["total_reputation"] += faction_report["current_reputation"]
				tier_sum += get_faction_profile(faction_id).tier
				faction_count += 1

	if faction_count > 0:
		report["avg_tier"] = get_reputation_tier("") if tier_sum / faction_count > 0 else "NEUTRAL"

	return report


func _check_reputation_tier_change(faction_id: String) -> void:
	var profile = get_faction_profile(faction_id)
	if not profile:
		return

	var new_tier = ReputationTier.NEUTRAL

	if profile.current_reputation >= 8000:
		new_tier = ReputationTier.LEGENDARY
	elif profile.current_reputation >= 5000:
		new_tier = ReputationTier.REVERED
	elif profile.current_reputation >= 2000:
		new_tier = ReputationTier.LIKED
	elif profile.current_reputation >= -2000:
		new_tier = ReputationTier.NEUTRAL
	elif profile.current_reputation >= -5000:
		new_tier = ReputationTier.DISLIKED
	else:
		new_tier = ReputationTier.HATED

	if new_tier != profile.tier:
		profile.tier = new_tier
		reputation_tier_reached.emit(faction_id, get_reputation_tier(faction_id))


func _initialize_factions() -> void:
	var merchant_guild = Faction.new("faction_merchant_guild", "Merchant Guild")
	merchant_guild.description = "Powerful traders controlling commerce across realms"
	merchant_guild.alignment = "neutral"
	merchant_guild.prestige_unlock_requirement = 0
	merchant_guild.base_reputation = 0
	merchant_guild.max_reputation = 10000
	register_faction(merchant_guild)

	var royal_order = Faction.new("faction_royal_order", "Royal Order")
	royal_order.description = "The kingdom's elite military force"
	royal_order.alignment = "good"
	royal_order.prestige_unlock_requirement = 1000
	royal_order.base_reputation = 0
	register_faction(royal_order)

	var shadow_circle = Faction.new("faction_shadow_circle", "Shadow Circle")
	shadow_circle.description = "Mysterious underground network"
	shadow_circle.alignment = "evil"
	shadow_circle.prestige_unlock_requirement = 5000
	shadow_circle.base_reputation = 0
	register_faction(shadow_circle)

	var scholar_academy = Faction.new("faction_scholar_academy", "Scholar Academy")
	scholar_academy.description = "Keepers of ancient knowledge"
	scholar_academy.alignment = "good"
	scholar_academy.prestige_unlock_requirement = 2000
	scholar_academy.base_reputation = 0
	register_faction(scholar_academy)

	var dragon_cult = Faction.new("faction_dragon_cult", "Dragon Cult")
	dragon_cult.description = "Worshippers of legendary dragons"
	dragon_cult.alignment = "evil"
	dragon_cult.prestige_unlock_requirement = 15000
	dragon_cult.base_reputation = 0
	register_faction(dragon_cult)

	var celestial_order = Faction.new("faction_celestial_order", "Celestial Order")
	celestial_order.description = "Divine protectors of the realm"
	celestial_order.alignment = "good"
	celestial_order.prestige_unlock_requirement = 35000
	celestial_order.base_reputation = 0
	register_faction(celestial_order)


func _initialize_perks() -> void:
	# Merchant Guild perks
	var trade_discount = FactionPerk.new("perk_trade_discount", "Trade Discount")
	trade_discount.description = "10% discount on all merchant purchases"
	trade_discount.reputation_requirement = 1000
	trade_discount.effect_type = "cost_reduction"
	trade_discount.effect_value = 0.9
	faction_perks["faction_merchant_guild_perk_trade_discount"] = trade_discount

	var merchant_quests = FactionPerk.new("perk_merchant_quests", "Merchant Quests")
	merchant_quests.description = "Access to lucrative merchant quests"
	merchant_quests.reputation_requirement = 3000
	merchant_quests.effect_type = "quest_unlock"
	merchant_quests.effect_value = 1.5
	faction_perks["faction_merchant_guild_perk_merchant_quests"] = merchant_quests

	# Royal Order perks
	var combat_training = FactionPerk.new("perk_combat_training", "Combat Training")
	combat_training.description = "+15% combat damage"
	combat_training.reputation_requirement = 2000
	combat_training.effect_type = "combat_bonus"
	combat_training.effect_value = 1.15
	faction_perks["faction_royal_order_perk_combat_training"] = combat_training

	var royal_blessing = FactionPerk.new("perk_royal_blessing", "Royal Blessing")
	royal_blessing.description = "20% more experience from combat"
	royal_blessing.reputation_requirement = 4000
	royal_blessing.effect_type = "experience_bonus"
	royal_blessing.effect_value = 1.2
	faction_perks["faction_royal_order_perk_royal_blessing"] = royal_blessing

	# Scholar Academy perks
	var arcane_knowledge = FactionPerk.new("perk_arcane_knowledge", "Arcane Knowledge")
	arcane_knowledge.description = "+20% spell power"
	arcane_knowledge.reputation_requirement = 2000
	arcane_knowledge.effect_type = "spell_bonus"
	arcane_knowledge.effect_value = 1.2
	faction_perks["faction_scholar_academy_perk_arcane_knowledge"] = arcane_knowledge

	# Shadow Circle perks
	var stealth_mastery = FactionPerk.new("perk_stealth_mastery", "Stealth Mastery")
	stealth_mastery.description = "+30% critical chance"
	stealth_mastery.reputation_requirement = 3000
	stealth_mastery.effect_type = "crit_bonus"
	stealth_mastery.effect_value = 1.3
	faction_perks["faction_shadow_circle_perk_stealth_mastery"] = stealth_mastery

	# Celestial Order perks
	var divine_protection = FactionPerk.new("perk_divine_protection", "Divine Protection")
	divine_protection.description = "+40% damage resistance"
	divine_protection.reputation_requirement = 5000
	divine_protection.effect_type = "defense_bonus"
	divine_protection.effect_value = 1.4
	faction_perks["faction_celestial_order_perk_divine_protection"] = divine_protection
