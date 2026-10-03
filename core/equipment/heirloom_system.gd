## Heirloom System: Track legendary gear that passes through generations
##
## Manages heirloom items, prestige-tier locks, stat scaling, and generational inheritance

extends Node

class_name HeirloomSystem


signal heirloom_acquired(heir_id: String, heirloom_id: String)
signal heirloom_evolved(heirloom_id: String, new_tier: int)
signal heirloom_inherited(heir_id: String, heirloom_id: String)


enum HeirloomSlot { WEAPON, ARMOR, ACCESSORY }
enum HeirloomTier { BRONZE, SILVER, GOLD, PLATINUM, DIAMOND, ETERNAL }


var heirloom_registry: Dictionary = {}  # heirloom_id -> HeirloomDefinition
var heir_heirlooms: Dictionary = {}  # heir_id -> [heirloom_id, ...]
var heirloom_instances: Dictionary = {}  # heirloom_id -> HeirloomInstance


class HeirloomDefinition:
	var heirloom_id: String
	var name: String
	var slot: int
	var prestige_tier_requirement: int  # Minimum prestige tier to use
	var base_stats: Dictionary  # {"damage": 20, "defense": 10}
	var stat_scaling: Dictionary  # How much stats grow per generation {"damage": 1.5}
	var special_abilities: Array
	var legendary_lore: String
	var rarity: int  # 1-5

	func _init(p_id: String, p_name: String, p_slot: int) -> void:
		heirloom_id = p_id
		name = p_name
		slot = p_slot
		prestige_tier_requirement = 0
		base_stats = {}
		stat_scaling = {}
		special_abilities = []
		legendary_lore = ""
		rarity = 1


class HeirloomInstance:
	var heirloom_id: String
	var current_owner: String
	var current_tier: int
	var generations_owned: int
	var current_stats: Dictionary
	var is_activated: bool
	var affix_count: int
	var reforge_count: int

	func _init(p_id: String) -> void:
		heirloom_id = p_id
		current_owner = ""
		current_tier = HeirloomTier.BRONZE
		generations_owned = 0
		current_stats = {}
		is_activated = false
		affix_count = 0
		reforge_count = 0


func _init() -> void:
	_initialize_heirlooms()


func register_heirloom(heirloom: HeirloomDefinition) -> void:
	heirloom_registry[heirloom.heirloom_id] = heirloom
	heirloom_instances[heirloom.heirloom_id] = HeirloomInstance.new(heirloom.heirloom_id)


func acquire_heirloom(heir_id: String, heirloom_id: String, prestige: int) -> bool:
	var definition = heirloom_registry.get(heirloom_id, null)
	if not definition:
		return false

	# Check prestige tier requirement
	var prestige_tier = _calculate_prestige_tier(prestige)
	if prestige_tier < definition.prestige_tier_requirement:
		return false  # Cannot acquire without sufficient prestige tier

	if heir_id not in heir_heirlooms:
		heir_heirlooms[heir_id] = []

	if heirloom_id not in heir_heirlooms[heir_id]:
		heir_heirlooms[heir_id].append(heirloom_id)
		var instance = heirloom_instances[heirloom_id]
		instance.current_owner = heir_id
		instance.current_stats = definition.base_stats.duplicate()
		heirloom_acquired.emit(heir_id, heirloom_id)
		return true

	return false


func inherit_heirloom(heir_id: String, parent_heirloom_id: String, parent_prestige: int) -> bool:
	var parent_instance = heirloom_instances.get(parent_heirloom_id, null)
	if not parent_instance:
		return false

	# Inherit at scaled stats
	var inheritance_multiplier = 1.0 + (parent_prestige / 100000.0) * 0.3  # Up to 1.3x

	if heir_id not in heir_heirlooms:
		heir_heirlooms[heir_id] = []

	if parent_heirloom_id not in heir_heirlooms[heir_id]:
		heir_heirlooms[heir_id].append(parent_heirloom_id)

	parent_instance.current_owner = heir_id
	parent_instance.generations_owned += 1

	# Scale stats
	for stat in parent_instance.current_stats.keys():
		parent_instance.current_stats[stat] = int(parent_instance.current_stats[stat] * inheritance_multiplier)

	# Potential tier advancement
	if parent_instance.generations_owned % 5 == 0:
		_attempt_tier_advancement(parent_heirloom_id)

	heirloom_inherited.emit(heir_id, parent_heirloom_id)
	return true


func get_heir_heirlooms(heir_id: String) -> Array:
	if heir_id not in heir_heirlooms:
		return []
	return heir_heirlooms[heir_id].duplicate()


func get_heirloom_stats(heirloom_id: String) -> Dictionary:
	var instance = heirloom_instances.get(heirloom_id, null)
	if instance:
		return instance.current_stats.duplicate()
	return {}


func get_heirloom_tier(heirloom_id: String) -> String:
	var instance = heirloom_instances.get(heirloom_id, null)
	if not instance:
		return "UNKNOWN"

	match instance.current_tier:
		HeirloomTier.BRONZE:
			return "BRONZE"
		HeirloomTier.SILVER:
			return "SILVER"
		HeirloomTier.GOLD:
			return "GOLD"
		HeirloomTier.PLATINUM:
			return "PLATINUM"
		HeirloomTier.DIAMOND:
			return "DIAMOND"
		HeirloomTier.ETERNAL:
			return "ETERNAL"
	return "UNKNOWN"


func add_affix(heirloom_id: String, affix_type: String, affix_power: float) -> bool:
	var instance = heirloom_instances.get(heirloom_id, null)
	if not instance or instance.affix_count >= 3:  # Max 3 affixes
		return false

	var definition = heirloom_registry.get(heirloom_id, null)
	if not definition:
		return false

	# Affix adds bonus to stats
	for stat in definition.base_stats.keys():
		instance.current_stats[stat] = int(instance.current_stats[stat] * (1.0 + affix_power))

	instance.affix_count += 1
	return true


func reforge_heirloom(heirloom_id: String, target_tier: int) -> bool:
	var instance = heirloom_instances.get(heirloom_id, null)
	if not instance or target_tier < instance.current_tier or target_tier > HeirloomTier.ETERNAL:
		return false

	instance.current_tier = target_tier
	instance.reforge_count += 1

	# Stat boost from reforging
	for stat in instance.current_stats.keys():
		instance.current_stats[stat] = int(instance.current_stats[stat] * 1.1)

	return true


func get_heirloom_report(heirloom_id: String) -> Dictionary:
	var definition = heirloom_registry.get(heirloom_id, null)
	var instance = heirloom_instances.get(heirloom_id, null)

	if not definition or not instance:
		return {}

	return {
		"heirloom_id": heirloom_id,
		"name": definition.name,
		"tier": get_heirloom_tier(heirloom_id),
		"current_owner": instance.current_owner,
		"generations_owned": instance.generations_owned,
		"stats": instance.current_stats.duplicate(),
		"affixes": instance.affix_count,
		"reforges": instance.reforge_count,
		"rarity": definition.rarity
	}


func _attempt_tier_advancement(heirloom_id: String) -> void:
	var instance = heirloom_instances.get(heirloom_id, null)
	if not instance or instance.current_tier >= HeirloomTier.ETERNAL:
		return

	# 25% chance to tier up every 5 generations
	if randf() < 0.25:
		instance.current_tier += 1
		heirloom_evolved.emit(heirloom_id, instance.current_tier)

		# Stat boost from tier advancement
		for stat in instance.current_stats.keys():
			instance.current_stats[stat] = int(instance.current_stats[stat] * 1.15)


func _calculate_prestige_tier(prestige: int) -> int:
	if prestige < 1000:
		return 0
	elif prestige < 5000:
		return 1
	elif prestige < 15000:
		return 2
	elif prestige < 35000:
		return 3
	elif prestige < 75000:
		return 4
	else:
		return 5


func _initialize_heirlooms() -> void:
	# Weapon: Sword of Legends
	var sword = HeirloomDefinition.new("heirloom_sword_of_legends", "Sword of Legends", HeirloomSlot.WEAPON)
	sword.prestige_tier_requirement = HeirloomTier.BRONZE
	sword.base_stats = {"damage": 50, "attack_speed": 1.2}
	sword.stat_scaling = {"damage": 1.5, "attack_speed": 0.05}
	sword.special_abilities = ["ability_legendary_slash"]
	sword.rarity = 4
	register_heirloom(sword)

	# Armor: Ancestral Plate
	var armor = HeirloomDefinition.new("heirloom_ancestral_plate", "Ancestral Plate", HeirloomSlot.ARMOR)
	armor.prestige_tier_requirement = HeirloomTier.SILVER
	armor.base_stats = {"defense": 40, "vitality": 30}
	armor.stat_scaling = {"defense": 1.3, "vitality": 1.2}
	armor.special_abilities = ["ability_ancestral_shield"]
	armor.rarity = 4
	register_heirloom(armor)

	# Accessory: Ring of Power
	var ring = HeirloomDefinition.new("heirloom_ring_of_power", "Ring of Power", HeirloomSlot.ACCESSORY)
	ring.prestige_tier_requirement = HeirloomTier.GOLD
	ring.base_stats = {"intelligence": 20, "prestige_multiplier": 0.1}
	ring.stat_scaling = {"intelligence": 1.4}
	ring.special_abilities = ["ability_arcane_boost"]
	ring.rarity = 5
	register_heirloom(ring)

	# Weapon: Bow of the Hunt
	var bow = HeirloomDefinition.new("heirloom_bow_of_hunt", "Bow of the Hunt", HeirloomSlot.WEAPON)
	bow.prestige_tier_requirement = HeirloomTier.SILVER
	bow.base_stats = {"damage": 35, "dexterity": 25}
	bow.stat_scaling = {"damage": 1.4, "dexterity": 1.3}
	bow.rarity = 3
	register_heirloom(bow)
