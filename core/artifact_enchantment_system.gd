## Artifact Enchantment System: Add special effects to artifacts
##
## Manages enchantments and their effects on artifacts

extends Node

class_name ArtifactEnchantmentSystem


signal enchantment_applied(artifact_id: String, enchantment_id: String)
signal enchantment_removed(artifact_id: String, enchantment_id: String)
signal enchantment_stacked(artifact_id: String, enchantment_type: int, stack_count: int)


enum EnchantmentType { STAT_BOOST, SPECIAL_ABILITY, CURSE_RESISTANCE, BLESSING_AFFINITY, COMBAT_BONUS }


var artifact_enchantments: Dictionary = {}
var enchantment_counter: int = 0


class Enchantment:
	var id: String
	var type: int
	var name: String
	var effect_description: String
	var stat_modifications: Dictionary
	var special_effect: String
	var power: float
	var applied_at_generation: int
	var stack_count: int

	func _init(p_id: String, p_type: int, p_name: String, p_gen: int) -> void:
		id = p_id
		type = p_type
		name = p_name
		applied_at_generation = p_gen
		effect_description = ""
		stat_modifications = {}
		special_effect = ""
		power = 1.0
		stack_count = 1


func _init() -> void:
	artifact_enchantments = {}
	enchantment_counter = 0


func apply_enchantment(artifact_id: String, enchantment_type: int, generation: int) -> String:
	var enchantment_id = "enchant_%d_%d" % [enchantment_counter, randi()]
	enchantment_counter += 1

	var enchantment = Enchantment.new(enchantment_id, enchantment_type, EnchantmentType.keys()[enchantment_type], generation)
	enchantment = _configure_enchantment(enchantment)

	if not artifact_enchantments.has(artifact_id):
		artifact_enchantments[artifact_id] = []

	# Check for stacking
	var existing_same_type = -1
	for i in range(artifact_enchantments[artifact_id].size()):
		if artifact_enchantments[artifact_id][i].type == enchantment_type:
			existing_same_type = i
			break

	if existing_same_type >= 0:
		artifact_enchantments[artifact_id][existing_same_type].stack_count += 1
		artifact_enchantments[artifact_id][existing_same_type].power *= 1.1
		enchantment_stacked.emit(artifact_id, enchantment_type, artifact_enchantments[artifact_id][existing_same_type].stack_count)
		return artifact_enchantments[artifact_id][existing_same_type].id
	else:
		artifact_enchantments[artifact_id].append(enchantment)
		enchantment_applied.emit(artifact_id, enchantment_id)
		return enchantment_id


func remove_enchantment(artifact_id: String, enchantment_id: String) -> bool:
	if not artifact_enchantments.has(artifact_id):
		return false

	var enchantments = artifact_enchantments[artifact_id]
	for i in range(enchantments.size()):
		if enchantments[i].id == enchantment_id:
			enchantments.remove_at(i)
			enchantment_removed.emit(artifact_id, enchantment_id)
			return true

	return false


func get_enchantments(artifact_id: String) -> Array:
	return artifact_enchantments.get(artifact_id, []).duplicate()


func get_enchantment_effects(artifact_id: String) -> Dictionary:
	var effects = {
		"stat_bonuses": {},
		"special_effects": [],
		"total_power": 1.0
	}

	if not artifact_enchantments.has(artifact_id):
		return effects

	for enchantment in artifact_enchantments[artifact_id]:
		for stat in enchantment.stat_modifications.keys():
			if not effects["stat_bonuses"].has(stat):
				effects["stat_bonuses"][stat] = 0
			effects["stat_bonuses"][stat] += enchantment.stat_modifications[stat] * enchantment.stack_count

		if enchantment.special_effect:
			effects["special_effects"].append({
				"effect": enchantment.special_effect,
				"power": enchantment.power,
				"stacks": enchantment.stack_count
			})

		effects["total_power"] *= enchantment.power

	return effects


func has_enchantment_type(artifact_id: String, enchantment_type: int) -> bool:
	if not artifact_enchantments.has(artifact_id):
		return false

	for enchantment in artifact_enchantments[artifact_id]:
		if enchantment.type == enchantment_type:
			return true

	return false


func get_enchantment_stack_count(artifact_id: String, enchantment_type: int) -> int:
	if not artifact_enchantments.has(artifact_id):
		return 0

	for enchantment in artifact_enchantments[artifact_id]:
		if enchantment.type == enchantment_type:
			return enchantment.stack_count

	return 0


func purge_enchantments(artifact_id: String) -> int:
	if not artifact_enchantments.has(artifact_id):
		return 0

	var count = artifact_enchantments[artifact_id].size()
	artifact_enchantments[artifact_id] = []
	return count


func combine_enchantments(artifact_id: String) -> Dictionary:
	if not artifact_enchantments.has(artifact_id):
		return {}

	var effects = get_enchantment_effects(artifact_id)
	var summary = {
		"total_stat_bonuses": 0,
		"stat_breakdown": effects["stat_bonuses"].duplicate(),
		"special_effects_count": effects["special_effects"].size(),
		"combined_power": effects["total_power"]
	}

	for stat_bonus in effects["stat_bonuses"].values():
		summary["total_stat_bonuses"] += stat_bonus

	return summary


func transfer_enchantments(source_artifact_id: String, target_artifact_id: String) -> int:
	if not artifact_enchantments.has(source_artifact_id):
		return 0

	if not artifact_enchantments.has(target_artifact_id):
		artifact_enchantments[target_artifact_id] = []

	var transferred_count = 0
	var source_enchantments = artifact_enchantments[source_artifact_id]

	for enchantment in source_enchantments:
		var new_enchantment = Enchantment.new(enchantment.id, enchantment.type, enchantment.name, enchantment.applied_at_generation)
		new_enchantment.effect_description = enchantment.effect_description
		new_enchantment.stat_modifications = enchantment.stat_modifications.duplicate()
		new_enchantment.special_effect = enchantment.special_effect
		new_enchantment.power = enchantment.power
		new_enchantment.stack_count = enchantment.stack_count

		artifact_enchantments[target_artifact_id].append(new_enchantment)
		transferred_count += 1

	return transferred_count


func export_enchantment_history() -> Dictionary:
	var history = {
		"total_enchanted_artifacts": artifact_enchantments.size(),
		"total_enchantments": 0,
		"enchantments_by_type": {},
		"average_enchantments_per_artifact": 0.0,
		"most_enchanted_artifact": "",
		"max_enchantments": 0
	}

	var max_enchantments = 0
	var most_enchanted_id = ""

	for artifact_id in artifact_enchantments.keys():
		var enchantments = artifact_enchantments[artifact_id]
		history["total_enchantments"] += enchantments.size()

		if enchantments.size() > max_enchantments:
			max_enchantments = enchantments.size()
			most_enchanted_id = artifact_id

		for enchantment in enchantments:
			var type_name = EnchantmentType.keys()[enchantment.type]
			if not history["enchantments_by_type"].has(type_name):
				history["enchantments_by_type"][type_name] = 0
			history["enchantments_by_type"][type_name] += 1

	history["most_enchanted_artifact"] = most_enchanted_id
	history["max_enchantments"] = max_enchantments

	if artifact_enchantments.size() > 0:
		history["average_enchantments_per_artifact"] = float(history["total_enchantments"]) / float(artifact_enchantments.size())

	return history


func _configure_enchantment(enchantment: Enchantment) -> Enchantment:
	match enchantment.type:
		EnchantmentType.STAT_BOOST:
			enchantment.stat_modifications = {"strength": 2, "dexterity": 1}
			enchantment.effect_description = "Boosts core stats"
			enchantment.power = 1.1

		EnchantmentType.SPECIAL_ABILITY:
			enchantment.special_effect = "Critical Strike"
			enchantment.effect_description = "Grants special combat ability"
			enchantment.stat_modifications = {"damage": 3}
			enchantment.power = 1.15

		EnchantmentType.CURSE_RESISTANCE:
			enchantment.special_effect = "Curse Ward"
			enchantment.effect_description = "Resists curses and hexes"
			enchantment.stat_modifications = {"resistance": 10}
			enchantment.power = 1.12

		EnchantmentType.BLESSING_AFFINITY:
			enchantment.special_effect = "Divine Favor"
			enchantment.effect_description = "Attuned to blessings"
			enchantment.stat_modifications = {"wisdom": 3}
			enchantment.power = 1.13

		EnchantmentType.COMBAT_BONUS:
			enchantment.special_effect = "Martial Mastery"
			enchantment.effect_description = "Enhanced combat effectiveness"
			enchantment.stat_modifications = {"damage": 5, "defense": 2}
			enchantment.power = 1.20

	return enchantment
