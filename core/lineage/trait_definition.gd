## Trait Definition: Define all trait types, inheritance rules, and effects
##
## Traits form the foundation of family lineage. Each trait has type, inheritance pattern,
## mutation potential, and stat/ability effects that pass through generations.

extends Node

class_name TraitDefinition


enum TraitType { BLOODLINE, ACQUIRED, CURSE, BLESSING }
enum InheritancePattern { DOMINANT, RECESSIVE, MIXED }


class Trait:
	var trait_id: String
	var trait_type: int
	var name: String
	var description: String
	var inheritance_pattern: int
	var mutation_chance: float  # 0.0-1.0
	var stat_modifiers: Dictionary  # {"strength": 5, "dexterity": -2}
	var ability_unlocks: Array  # [ability_id, ...]
	var curse_effects: Array  # [curse_id, ...]
	var blessing_effects: Array  # [blessing_id, ...]
	var prestige_requirement: int  # Prestige needed to manifest
	var rarity: int  # 1-5, higher = rarer
	var is_dormant_capable: bool  # Can skip generations
	var dormant_skip_chance: float  # Chance trait stays dormant
	var mutation_chain: Array  # [trait_id that triggers, ...]
	var conflicting_traits: Array  # [trait_id that cannot coexist, ...]

	func _init(p_id: String, p_type: int, p_name: String) -> void:
		trait_id = p_id
		trait_type = p_type
		name = p_name
		description = ""
		inheritance_pattern = InheritancePattern.MIXED
		mutation_chance = 0.05
		stat_modifiers = {}
		ability_unlocks = []
		curse_effects = []
		blessing_effects = []
		prestige_requirement = 0
		rarity = 1
		is_dormant_capable = false
		dormant_skip_chance = 0.0
		mutation_chain = []
		conflicting_traits = []


class BloodlineTrait extends Trait:
	var generation_decay: float  # How much strength diminishes per generation
	var awakening_generation: int  # Generation where trait activates

	func _init(p_id: String, p_name: String) -> void:
		super(p_id, TraitType.BLOODLINE, p_name)
		inheritance_pattern = InheritancePattern.DOMINANT
		generation_decay = 0.95
		awakening_generation = 1


class AcquiredTrait extends Trait:
	var training_cost: int  # Experience or gold to learn
	var trainer_npc: String  # Who teaches this trait

	func _init(p_id: String, p_name: String) -> void:
		super(p_id, TraitType.ACQUIRED, p_name)
		inheritance_pattern = InheritancePattern.RECESSIVE
		is_dormant_capable = true
		dormant_skip_chance = 0.3
		training_cost = 100


class CurseTrait extends Trait:
	var curse_severity: int  # 1-5, how bad
	var curse_trigger: String  # What causes it
	var purification_cost: int  # Cost to remove

	func _init(p_id: String, p_name: String) -> void:
		super(p_id, TraitType.CURSE, p_name)
		inheritance_pattern = InheritancePattern.RECESSIVE
		curse_severity = 3
		curse_trigger = ""
		purification_cost = 500


class BlessingTrait extends Trait:
	var blessing_power: int  # 1-5, how strong
	var blessing_source: String  # What grants it
	var duration_generations: int  # How long it lasts

	func _init(p_id: String, p_name: String) -> void:
		super(p_id, TraitType.BLESSING, p_name)
		inheritance_pattern = InheritancePattern.DOMINANT
		blessing_power = 3
		blessing_source = "divine"
		duration_generations = 5


var trait_registry: Dictionary = {}  # trait_id -> Trait


func _init() -> void:
	_initialize_trait_registry()


func register_trait(trait: Trait) -> void:
	trait_registry[trait.trait_id] = trait


func get_trait(trait_id: String) -> Trait:
	return trait_registry.get(trait_id, null)


func get_traits_by_type(trait_type: int) -> Array:
	var results = []
	for trait in trait_registry.values():
		if trait.trait_type == trait_type:
			results.append(trait)
	return results


func get_inheritable_traits() -> Array:
	var results = []
	for trait in trait_registry.values():
		if trait.trait_type in [TraitType.BLOODLINE, TraitType.BLESSING]:
			results.append(trait)
	return results


func get_trait_stat_bonus(trait_id: String) -> Dictionary:
	var trait = get_trait(trait_id)
	if trait:
		return trait.stat_modifiers.duplicate()
	return {}


func get_trait_abilities(trait_id: String) -> Array:
	var trait = get_trait(trait_id)
	if trait:
		return trait.ability_unlocks.duplicate()
	return []


func can_traits_coexist(trait_id_1: String, trait_id_2: String) -> bool:
	var trait_1 = get_trait(trait_id_1)
	var trait_2 = get_trait(trait_id_2)

	if not trait_1 or not trait_2:
		return true

	if trait_id_2 in trait_1.conflicting_traits:
		return false
	if trait_id_1 in trait_2.conflicting_traits:
		return false

	return true


func _initialize_trait_registry() -> void:
	# Bloodline Traits
	var iron_blood = BloodlineTrait.new("bloodline_iron_blood", "Iron Blood")
	iron_blood.description = "Ancestors were hardened warriors. +15 Vitality, +10% physical defense"
	iron_blood.stat_modifiers = {"vitality": 15}
	iron_blood.ability_unlocks = ["ability_endurance"]
	iron_blood.mutation_chance = 0.02
	iron_blood.rarity = 3
	register_trait(iron_blood)

	var swift_reflexes = BloodlineTrait.new("bloodline_swift_reflexes", "Swift Reflexes")
	swift_reflexes.description = "Ancestors known for speed and agility. +20 Dexterity, +15% dodge chance"
	swift_reflexes.stat_modifiers = {"dexterity": 20}
	swift_reflexes.ability_unlocks = ["ability_dodge", "ability_parry"]
	swift_reflexes.mutation_chance = 0.02
	swift_reflexes.rarity = 3
	register_trait(swift_reflexes)

	var mage_blood = BloodlineTrait.new("bloodline_mage_blood", "Mage Blood")
	mage_blood.description = "Magic runs in your veins. +25 Intelligence, +20% spell power"
	mage_blood.stat_modifiers = {"intelligence": 25}
	mage_blood.ability_unlocks = ["ability_fireball", "ability_shield_spell"]
	mage_blood.mutation_chance = 0.03
	mage_blood.rarity = 4
	register_trait(mage_blood)

	# Acquired Traits
	var disciplined = AcquiredTrait.new("acquired_disciplined", "Disciplined")
	disciplined.description = "Years of training hardened your resolve. +10% all stats"
	disciplined.stat_modifiers = {"strength": 5, "dexterity": 5, "intelligence": 5, "vitality": 5}
	disciplined.training_cost = 250
	register_trait(disciplined)

	var monster_hunter = AcquiredTrait.new("acquired_monster_hunter", "Monster Hunter")
	monster_hunter.description = "Expert at defeating beasts. +30% damage vs monsters, +25% experience gain"
	monster_hunter.ability_unlocks = ["ability_monster_slayer"]
	monster_hunter.training_cost = 400
	register_trait(monster_hunter)

	# Curse Traits
	var cursed_luck = CurseTrait.new("curse_cursed_luck", "Cursed Luck")
	cursed_luck.description = "Misfortune follows you. -20% critical chance, -15% loot quality"
	cursed_luck.stat_modifiers = {"luck": -20}
	cursed_luck.curse_severity = 2
	cursed_luck.curse_trigger = "random_combat"
	cursed_luck.purification_cost = 300
	register_trait(cursed_luck)

	var weak_constitution = CurseTrait.new("curse_weak_constitution", "Weak Constitution")
	weak_constitution.description = "Frail and sickly. -30% max HP, -15% poison resistance"
	weak_constitution.stat_modifiers = {"vitality": -30}
	weak_constitution.curse_severity = 4
	weak_constitution.curse_trigger = "disease"
	weak_constitution.purification_cost = 500
	register_trait(weak_constitution)

	# Blessing Traits
	var divine_favor = BlessingTrait.new("blessing_divine_favor", "Divine Favor")
	divine_favor.description = "The gods smile upon you. +50% experience gain, +25% all rewards, lasts 10 generations"
	divine_favor.stat_modifiers = {"luck": 50}
	divine_favor.ability_unlocks = ["ability_blessing_strike"]
	divine_favor.blessing_power = 5
	divine_favor.duration_generations = 10
	register_trait(divine_favor)

	var lucky_coin = BlessingTrait.new("blessing_lucky_coin", "Lucky Coin")
	lucky_coin.description = "Fortune smiles gently. +20% critical chance, +10% gold gain, lasts 5 generations"
	lucky_coin.stat_modifiers = {"luck": 20}
	lucky_coin.blessing_power = 2
	lucky_coin.duration_generations = 5
	register_trait(lucky_coin)
