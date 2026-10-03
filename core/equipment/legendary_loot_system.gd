## Legendary Loot System: Track legendary item drops from bosses and legendary encounters
##
## Manages boss-specific loot, loot scaling by prestige, and legendary treasure distribution

extends Node

class_name LegendaryLootSystem


signal legendary_loot_dropped(heir_id: String, loot_id: String, source_boss: String)
signal treasure_discovered(heir_id: String, treasure_type: String)


var boss_loot_tables: Dictionary = {}  # boss_id -> [loot_id, ...]
var collected_loot: Dictionary = {}  # heir_id -> [loot_id, ...]
var treasure_map: Dictionary = {}  # treasure_id -> TreasureDefinition


class Loot:
	var loot_id: String
	var name: String
	var rarity: int  # 1-5
	var item_type: String  # weapon, armor, accessory, spell_scroll, artifact
	var base_value: int
	var stat_bonuses: Dictionary
	var source_boss: String
	var drop_chance: float

	func _init(p_id: String, p_name: String) -> void:
		loot_id = p_id
		name = p_name
		rarity = 1
		item_type = ""
		base_value = 100
		stat_bonuses = {}
		source_boss = ""
		drop_chance = 0.1


class TreasureDefinition:
	var treasure_id: String
	var name: String
	var description: String
	var prestige_requirement: int
	var treasure_type: String  # "gold_hoard", "artifact_cache", "spell_library"
	var value_amount: int
	var associated_quest: String

	func _init(p_id: String, p_name: String) -> void:
		treasure_id = p_id
		name = p_name
		description = ""
		prestige_requirement = 0
		treasure_type = ""
		value_amount = 1000
		associated_quest = ""


func _init() -> void:
	_initialize_loot_tables()
	_initialize_treasures()


func register_boss_loot(boss_id: String, loot_id: String) -> void:
	if boss_id not in boss_loot_tables:
		boss_loot_tables[boss_id] = []

	if loot_id not in boss_loot_tables[boss_id]:
		boss_loot_tables[boss_id].append(loot_id)


func drop_boss_loot(heir_id: String, boss_id: String, prestige: int) -> Array:
	var drops = []

	if boss_id not in boss_loot_tables:
		return drops

	var loot_pool = boss_loot_tables[boss_id]
	var prestige_multiplier = 1.0 + (prestige / 100000.0) * 0.5

	for loot_id in loot_pool:
		var loot = _get_loot_definition(loot_id)
		if not loot:
			continue

		var drop_chance = loot.drop_chance * prestige_multiplier
		if randf() < drop_chance:
			if heir_id not in collected_loot:
				collected_loot[heir_id] = []

			collected_loot[heir_id].append(loot_id)
			drops.append(loot_id)
			legendary_loot_dropped.emit(heir_id, loot_id, boss_id)

	return drops


func discover_treasure(heir_id: String, treasure_id: String, prestige: int) -> bool:
	var treasure = treasure_map.get(treasure_id, null)
	if not treasure:
		return false

	if prestige < treasure.prestige_requirement:
		return false  # Cannot discover without sufficient prestige

	treasure_discovered.emit(heir_id, treasure.treasure_type)
	return true


func get_heir_legendary_loot(heir_id: String) -> Array:
	if heir_id not in collected_loot:
		return []
	return collected_loot[heir_id].duplicate()


func get_loot_value_total(heir_id: String, prestige: int) -> int:
	var total = 0
	var prestige_multiplier = 1.0 + (prestige / 100000.0) * 0.3

	for loot_id in get_heir_legendary_loot(heir_id):
		var loot = _get_loot_definition(loot_id)
		if loot:
			total += int(loot.base_value * prestige_multiplier)

	return total


func get_loot_report(heir_id: String) -> Dictionary:
	var report = {
		"heir_id": heir_id,
		"loot_count": 0,
		"unique_loot": [],
		"rarity_distribution": {},
		"total_value": 0
	}

	for loot_id in get_heir_legendary_loot(heir_id):
		var loot = _get_loot_definition(loot_id)
		if loot:
			report["loot_count"] += 1
			if loot_id not in report["unique_loot"]:
				report["unique_loot"].append(loot_id)

			var rarity_name = "Rarity %d" % loot.rarity
			report["rarity_distribution"][rarity_name] = report["rarity_distribution"].get(rarity_name, 0) + 1

			report["total_value"] += loot.base_value

	return report


func _get_loot_definition(loot_id: String) -> Loot:
	# For now, return generic loot. In full implementation, would have registry
	var loot = Loot.new(loot_id, loot_id)
	loot.base_value = 500 + (hash(loot_id) % 1000)
	loot.rarity = (hash(loot_id) % 5) + 1
	loot.drop_chance = 0.1 + (loot.rarity * 0.05)
	return loot


func _initialize_loot_tables() -> void:
	# Silver Warden drops
	register_boss_loot("boss_silver_warden", "loot_silver_sword")
	register_boss_loot("boss_silver_warden", "loot_silver_shield")

	# Gold Dragon drops
	register_boss_loot("boss_gold_dragon", "loot_dragon_scales_armor")
	register_boss_loot("boss_gold_dragon", "loot_golden_egg")

	# Platinum Tyrant drops
	register_boss_loot("boss_platinum_tyrant", "loot_tyrant_crown")
	register_boss_loot("boss_platinum_tyrant", "loot_platinum_hammer")

	# Diamond Sovereign drops
	register_boss_loot("boss_diamond_sovereign", "loot_sovereign_ring")
	register_boss_loot("boss_diamond_sovereign", "loot_diamond_scepter")

	# Eternal Void drops
	register_boss_loot("boss_eternal_void", "loot_void_artifact")
	register_boss_loot("boss_eternal_void", "loot_infinity_stone")


func _initialize_treasures() -> void:
	var gold_hoard = TreasureDefinition.new("treasure_gold_hoard", "Gold Hoard")
	gold_hoard.description = "Massive cache of ancient gold"
	gold_hoard.prestige_requirement = 5000
	gold_hoard.treasure_type = "gold_hoard"
	gold_hoard.value_amount = 5000
	treasure_map[gold_hoard.treasure_id] = gold_hoard

	var artifact_cache = TreasureDefinition.new("treasure_artifact_cache", "Artifact Cache")
	artifact_cache.description = "Hidden vault of powerful artifacts"
	artifact_cache.prestige_requirement = 25000
	artifact_cache.treasure_type = "artifact_cache"
	artifact_cache.value_amount = 15000
	treasure_map[artifact_cache.treasure_id] = artifact_cache

	var spell_library = TreasureDefinition.new("treasure_spell_library", "Spell Library")
	spell_library.description = "Ancient library of forbidden spells"
	spell_library.prestige_requirement = 35000
	spell_library.treasure_type = "spell_library"
	spell_library.value_amount = 10000
	treasure_map[spell_library.treasure_id] = spell_library
