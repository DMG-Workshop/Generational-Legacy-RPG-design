## Legendary Encounter System: Boss battles with prestige-tier-locked mechanics
##
## Creates legendary bosses with scaling stats, tier-locked abilities, and exclusive rewards

extends Node

class_name LegendaryEncounterSystem


signal legendary_boss_encountered(boss_id: String, boss_tier: int)
signal boss_phase_changed(boss_id: String, current_phase: int)
signal legendary_victory(boss_id: String, prestige_reward: int)
signal exclusive_loot_dropped(boss_id: String, loot_tier: String)


enum BossTier { SILVER, GOLD, PLATINUM, DIAMOND, ETERNAL }

enum BossPhase { PHASE_1, PHASE_2, PHASE_3, PHASE_FINAL }

enum TierLockedMechanic { ARMOR_BREAK, PHASE_SHIFT, AOE_ATTACK, HEAL, DEBUFF_IMMUNITY, ULTIMATE_ABILITY }


var legendary_bosses: Dictionary = {}
var boss_defeat_records: Dictionary = {}
var exclusive_loot_pools: Dictionary = {}


class LegendaryBoss:
	var boss_id: String
	var boss_name: String
	var tier: int  # BossTier enum
	var required_prestige: int
	var min_party_level: int
	var base_stats: Dictionary
	var current_phase: int
	var max_phases: int
	var health_phases: Array  # Health thresholds for phase transitions
	var current_health: int
	var tier_locked_mechanics: Array
	var exclusive_loot_table: Array
	var prestige_reward_base: int
	var difficulty_multiplier: float

	func _init(p_id: String, p_name: String, p_tier: int, p_prestige_req: int) -> void:
		boss_id = p_id
		boss_name = p_name
		tier = p_tier
		required_prestige = p_prestige_req
		min_party_level = 10 + (p_tier * 5)
		base_stats = {"health": 500 + (p_tier * 200), "attack": 30 + (p_tier * 15), "defense": 20 + (p_tier * 10)}
		current_phase = 0
		max_phases = 3 + (p_tier / 2)
		health_phases = []
		current_health = base_stats["health"]
		tier_locked_mechanics = []
		exclusive_loot_table = []
		prestige_reward_base = 500 + (p_tier * 300)
		difficulty_multiplier = 1.0 + (p_tier * 0.3)


class LegendaryVictory:
	var boss_id: String
	var heir_id: String
	var victory_date: int
	var prestige_gained: int
	var exclusive_loot_obtained: Array
	var victory_tier: int
	var turns_taken: int
	var damage_taken: int
	var critical_hits: int

	func _init(p_boss_id: String, p_heir_id: String, p_prestige: int) -> void:
		boss_id = p_boss_id
		heir_id = p_heir_id
		prestige_gained = p_prestige
		victory_date = int(Time.get_ticks_msec())
		exclusive_loot_obtained = []
		victory_tier = 0
		turns_taken = 0
		damage_taken = 0
		critical_hits = 0


func _init() -> void:
	_initialize_legendary_bosses()
	_initialize_exclusive_loot_pools()


func create_legendary_boss(boss_id: String, boss_name: String, tier: int, required_prestige: int) -> LegendaryBoss:
	var boss = LegendaryBoss.new(boss_id, boss_name, tier, required_prestige)

	# Add tier-locked mechanics
	match tier:
		BossTier.SILVER:
			boss.tier_locked_mechanics = [TierLockedMechanic.ARMOR_BREAK]
		BossTier.GOLD:
			boss.tier_locked_mechanics = [TierLockedMechanic.ARMOR_BREAK, TierLockedMechanic.PHASE_SHIFT]
		BossTier.PLATINUM:
			boss.tier_locked_mechanics = [TierLockedMechanic.ARMOR_BREAK, TierLockedMechanic.PHASE_SHIFT, TierLockedMechanic.AOE_ATTACK]
		BossTier.DIAMOND:
			boss.tier_locked_mechanics = [TierLockedMechanic.ARMOR_BREAK, TierLockedMechanic.PHASE_SHIFT, TierLockedMechanic.AOE_ATTACK, TierLockedMechanic.HEAL]
		BossTier.ETERNAL:
			boss.tier_locked_mechanics = [TierLockedMechanic.ARMOR_BREAK, TierLockedMechanic.PHASE_SHIFT, TierLockedMechanic.AOE_ATTACK, TierLockedMechanic.HEAL, TierLockedMechanic.DEBUFF_IMMUNITY, TierLockedMechanic.ULTIMATE_ABILITY]

	# Set health phases
	var phase_health = boss.base_stats["health"]
	for i in range(boss.max_phases):
		boss.health_phases.append(int(phase_health * ((boss.max_phases - i) / float(boss.max_phases))))

	legendary_bosses[boss_id] = boss
	legendary_boss_encountered.emit(boss_id, tier)
	return boss


func get_legendary_boss(boss_id: String) -> LegendaryBoss:
	return legendary_bosses.get(boss_id)


func can_fight_legendary_boss(boss_id: String, prestige_amount: int) -> bool:
	var boss = legendary_bosses.get(boss_id)
	if not boss:
		return false

	return prestige_amount >= boss.required_prestige


func calculate_boss_scaled_stats(boss: LegendaryBoss, prestige_amount: int) -> Dictionary:
	var scaled_stats = boss.base_stats.duplicate()

	# Scale boss stats based on prestige
	var prestige_multiplier = 1.0 + (prestige_amount / 10000.0) * 0.5
	prestige_multiplier = clamp(prestige_multiplier, 1.0, 2.0)

	for stat in scaled_stats.keys():
		scaled_stats[stat] = int(scaled_stats[stat] * prestige_multiplier * boss.difficulty_multiplier)

	return scaled_stats


func process_boss_phase_transition(boss_id: String, current_health: int) -> int:
	var boss = legendary_bosses.get(boss_id)
	if not boss:
		return -1

	var new_phase = boss.current_phase

	for i in range(boss.health_phases.size()):
		if current_health <= boss.health_phases[i]:
			new_phase = i + 1

	if new_phase != boss.current_phase:
		boss.current_phase = new_phase
		boss_phase_changed.emit(boss_id, new_phase)

	return new_phase


func record_legendary_victory(boss_id: String, heir_id: String, prestige_amount: int,
                              turns_taken: int, damage_taken: int, critical_hits: int) -> LegendaryVictory:
	var boss = legendary_bosses.get(boss_id)
	if not boss:
		return null

	var victory = LegendaryVictory.new(boss_id, heir_id, boss.prestige_reward_base)
	victory.turns_taken = turns_taken
	victory.damage_taken = damage_taken
	victory.critical_hits = critical_hits
	victory.victory_tier = boss.tier

	# Calculate prestige reward multiplier based on performance
	var performance_bonus = 1.0
	if turns_taken <= 5:
		performance_bonus = 1.5  # Speedkill bonus
	elif damage_taken < 100:
		performance_bonus = 1.25  # Low damage taken bonus

	victory.prestige_gained = int(boss.prestige_reward_base * performance_bonus)

	# Award exclusive loot
	victory.exclusive_loot_obtained = _roll_exclusive_loot(boss, prestige_amount)

	if not boss_defeat_records.has(boss_id):
		boss_defeat_records[boss_id] = []

	boss_defeat_records[boss_id].append(victory)
	legendary_victory.emit(boss_id, victory.prestige_gained)

	return victory


func get_boss_defeat_count(boss_id: String, heir_id: String = "") -> int:
	if not boss_defeat_records.has(boss_id):
		return 0

	var records = boss_defeat_records[boss_id]
	if heir_id == "":
		return records.size()

	var count = 0
	for record in records:
		if record.heir_id == heir_id:
			count += 1

	return count


func get_tier_locked_mechanic_description(mechanic: int) -> String:
	match mechanic:
		TierLockedMechanic.ARMOR_BREAK:
			return "Boss can shatter your armor, reducing defense"
		TierLockedMechanic.PHASE_SHIFT:
			return "Boss shifts to new phase at health thresholds"
		TierLockedMechanic.AOE_ATTACK:
			return "Boss performs area-of-effect attacks"
		TierLockedMechanic.HEAL:
			return "Boss can heal itself mid-battle"
		TierLockedMechanic.DEBUFF_IMMUNITY:
			return "Boss is immune to most debuffs"
		TierLockedMechanic.ULTIMATE_ABILITY:
			return "Boss unleashes ultimate ability at critical health"
		_:
			return "Unknown mechanic"


func get_legendary_boss_description(boss: LegendaryBoss) -> String:
	var tier_names = ["Silver", "Gold", "Platinum", "Diamond", "Eternal"]
	var tier_name = tier_names[boss.tier] if boss.tier < tier_names.size() else "Unknown"

	var desc = "Legendary Boss: %s (%s Tier)\n" % [boss.boss_name, tier_name]
	desc += "- Required Prestige: %d\n" % boss.required_prestige
	desc += "- Minimum Party Level: %d\n" % boss.min_party_level
	desc += "- Base Health: %d\n" % boss.base_stats["health"]
	desc += "- Difficulty Multiplier: %.2fx\n" % boss.difficulty_multiplier
	desc += "- Prestige Reward: %d\n" % boss.prestige_reward_base
	desc += "- Tier-Locked Mechanics:\n"

	for mechanic in boss.tier_locked_mechanics:
		desc += "  * %s\n" % get_tier_locked_mechanic_description(mechanic)

	return desc


func get_legendary_boss_stats() -> Dictionary:
	var stats = {
		"total_legendary_bosses": legendary_bosses.size(),
		"by_tier": {},
		"total_defeats_recorded": 0,
		"exclusive_loot_pools": exclusive_loot_pools.size()
	}

	for boss in legendary_bosses.values():
		var tier_name = ["Silver", "Gold", "Platinum", "Diamond", "Eternal"][boss.tier]
		if not stats["by_tier"].has(tier_name):
			stats["by_tier"][tier_name] = 0
		stats["by_tier"][tier_name] += 1

	for defeats in boss_defeat_records.values():
		stats["total_defeats_recorded"] += defeats.size()

	return stats


func _initialize_legendary_bosses() -> void:
	create_legendary_boss("silver_warden", "Silver Warden", BossTier.SILVER, 1000)
	create_legendary_boss("gold_dragon", "Golden Dragon", BossTier.GOLD, 5000)
	create_legendary_boss("platinum_tyrant", "Platinum Tyrant", BossTier.PLATINUM, 15000)
	create_legendary_boss("diamond_sovereign", "Diamond Sovereign", BossTier.DIAMOND, 35000)
	create_legendary_boss("eternal_void", "Eternal Void", BossTier.ETERNAL, 75000)


func _initialize_exclusive_loot_pools() -> void:
	exclusive_loot_pools = {
		"silver_warden": ["Silver Pendant", "Warden's Cloak", "Silver Signet"],
		"gold_dragon": ["Golden Scale Armor", "Dragon Heart", "Hoard Key"],
		"platinum_tyrant": ["Tyrant's Crown", "Platinum Greatsword", "Ring of Tyranny"],
		"diamond_sovereign": ["Sovereign's Scepter", "Diamond Throne Piece", "Crown of Eternity"],
		"eternal_void": ["Void Essence", "Eternal Artifact", "Nightmare Crown"]
	}


func _roll_exclusive_loot(boss: LegendaryBoss, prestige_amount: int) -> Array:
	var obtained = []

	if not exclusive_loot_pools.has(boss.boss_id):
		return obtained

	var loot_pool = exclusive_loot_pools[boss.boss_id]

	# Higher prestige = more loot rolls
	var roll_count = 1 + (prestige_amount / 10000)
	roll_count = clampi(roll_count, 1, 3)

	for _i in range(roll_count):
		if randf() < 0.7:  # 70% chance per roll
			obtained.append(loot_pool[randi() % loot_pool.size()])

	for loot in obtained:
		exclusive_loot_dropped.emit(boss.boss_id, loot)

	return obtained
