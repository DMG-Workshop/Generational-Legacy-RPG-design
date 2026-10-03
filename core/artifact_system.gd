## Artifact System: Create and manage artifacts with stat scaling
##
## Manages artifact definitions, crafting, and power progression

extends Node

class_name ArtifactSystem


signal artifact_created(artifact_id: String, name: String, rarity: int)
signal artifact_upgraded(artifact_id: String, old_rarity: int, new_rarity: int)
signal artifact_stat_changed(artifact_id: String, stat: String, value: int)


enum ArtifactType { WEAPON, ARMOR, ACCESSORY, RELIC }
enum ArtifactRarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, MYTHIC }


var artifacts: Dictionary = {}
var artifact_counter: int = 0


class Artifact:
	var id: String
	var name: String
	var description: String
	var type: int
	var rarity: int
	var base_stats: Dictionary
	var current_stats: Dictionary
	var age: int
	var creation_generation: int
	var creation_heir_id: String
	var power_level: float
	var bonuses: Array
	var enchantments: Array

	func _init(p_id: String, p_name: String, p_type: int, p_rarity: int, p_gen: int, p_heir_id: String) -> void:
		id = p_id
		name = p_name
		type = p_type
		rarity = p_rarity
		creation_generation = p_gen
		creation_heir_id = p_heir_id
		age = 0
		power_level = 1.0
		bonuses = []
		enchantments = []
		description = ""
		_initialize_base_stats()

	func _initialize_base_stats() -> void:
		base_stats = {}
		current_stats = {}

		match type:
			ArtifactType.WEAPON:
				base_stats = {"damage": 10 + (rarity * 5), "accuracy": 85}
			ArtifactType.ARMOR:
				base_stats = {"defense": 5 + (rarity * 3), "durability": 100}
			ArtifactType.ACCESSORY:
				base_stats = {"stat_bonus": 2 + rarity, "luck": 10}
			ArtifactType.RELIC:
				base_stats = {"power": 15 + (rarity * 8), "essence": 100}

		current_stats = base_stats.duplicate()

	func apply_power_scaling(multiplier: float) -> void:
		power_level *= multiplier
		for stat in current_stats.keys():
			current_stats[stat] = int(base_stats[stat] * power_level)


func _init() -> void:
	artifacts = {}
	artifact_counter = 0


func create_artifact(name: String, artifact_type: int, rarity: int, generation: int, heir_id: String, description: String = "") -> String:
	var artifact_id = "artifact_%d_%d" % [artifact_counter, randi()]
	artifact_counter += 1

	var artifact = Artifact.new(artifact_id, name, artifact_type, rarity, generation, heir_id)
	artifact.description = description if description else _get_default_description(artifact_type, rarity)

	artifacts[artifact_id] = artifact
	artifact_created.emit(artifact_id, name, rarity)
	return artifact_id


func get_artifact(artifact_id: String) -> Artifact:
	return artifacts.get(artifact_id)


func upgrade_artifact_rarity(artifact_id: String) -> bool:
	var artifact = artifacts.get(artifact_id)
	if not artifact:
		return false
	if artifact.rarity >= ArtifactRarity.MYTHIC:
		return false

	var old_rarity = artifact.rarity
	artifact.rarity += 1
	artifact.apply_power_scaling(1.2)
	artifact_upgraded.emit(artifact_id, old_rarity, artifact.rarity)
	return true


func add_stat_bonus(artifact_id: String, stat_name: String, amount: int) -> bool:
	var artifact = artifacts.get(artifact_id)
	if not artifact:
		return false

	if not artifact.current_stats.has(stat_name):
		artifact.current_stats[stat_name] = amount
	else:
		artifact.current_stats[stat_name] += amount

	artifact_stat_changed.emit(artifact_id, stat_name, artifact.current_stats[stat_name])
	return true


func age_artifact(artifact_id: String) -> void:
	var artifact = artifacts.get(artifact_id)
	if artifact:
		artifact.age += 1


func get_artifact_stats(artifact_id: String) -> Dictionary:
	var artifact = artifacts.get(artifact_id)
	if not artifact:
		return {}

	return {
		"id": artifact.id,
		"name": artifact.name,
		"type": ArtifactType.keys()[artifact.type],
		"rarity": ArtifactRarity.keys()[artifact.rarity],
		"stats": artifact.current_stats.duplicate(),
		"age": artifact.age,
		"power_level": artifact.power_level,
		"creation_generation": artifact.creation_generation
	}


func get_artifact_power(artifact_id: String) -> float:
	var artifact = artifacts.get(artifact_id)
	if not artifact:
		return 0.0

	var power = artifact.power_level
	power *= (1.0 + (artifact.rarity * 0.15))
	power *= (1.0 + (artifact.age * 0.02))
	return power


func get_artifacts_by_type(artifact_type: int) -> Array:
	var result = []
	for artifact in artifacts.values():
		if artifact.type == artifact_type:
			result.append(artifact)
	return result


func get_artifacts_by_rarity(rarity: int) -> Array:
	var result = []
	for artifact in artifacts.values():
		if artifact.rarity == rarity:
			result.append(artifact)
	return result


func get_all_artifacts() -> Array:
	return artifacts.values()


func combine_artifacts(artifact_id_1: String, artifact_id_2: String, heir_id: String, generation: int) -> String:
	var artifact_1 = artifacts.get(artifact_id_1)
	var artifact_2 = artifacts.get(artifact_id_2)

	if not artifact_1 or not artifact_2:
		return ""
	if artifact_1.type != artifact_2.type:
		return ""

	var combined_rarity = min(artifact_1.rarity + 1, ArtifactRarity.MYTHIC)
	var combined_power = (artifact_1.power_level + artifact_2.power_level) / 2.0 * 1.15

	var combined_name = "Merged %s" % artifact_1.name
	var combined_id = create_artifact(
		combined_name,
		artifact_1.type,
		combined_rarity,
		generation,
		heir_id
	)

	var combined_artifact = artifacts[combined_id]
	combined_artifact.power_level = combined_power
	combined_artifact.age = max(artifact_1.age, artifact_2.age)

	# Transfer stat bonuses
	for stat in artifact_1.current_stats.keys():
		if artifact_2.current_stats.has(stat):
			var combined_stat = int((artifact_1.current_stats[stat] + artifact_2.current_stats[stat]) / 2.0)
			combined_artifact.current_stats[stat] = combined_stat

	return combined_id


func get_artifact_info(artifact_id: String) -> Dictionary:
	var artifact = artifacts.get(artifact_id)
	if not artifact:
		return {}

	return {
		"id": artifact.id,
		"name": artifact.name,
		"description": artifact.description,
		"type": ArtifactType.keys()[artifact.type],
		"rarity": ArtifactRarity.keys()[artifact.rarity],
		"stats": artifact.current_stats.duplicate(),
		"age": artifact.age,
		"power_level": artifact.power_level,
		"creation_generation": artifact.creation_generation,
		"creation_heir_id": artifact.creation_heir_id,
		"bonuses": artifact.bonuses.duplicate(),
		"enchantments": artifact.enchantments.duplicate()
	}


func export_artifact_history() -> Dictionary:
	var history = {
		"total_artifacts": artifacts.size(),
		"by_type": {},
		"by_rarity": {},
		"strongest_artifact": "",
		"oldest_artifact": "",
		"average_power": 0.0
	}

	var max_power = 0.0
	var max_age = 0
	var total_power = 0.0

	for artifact in artifacts.values():
		var type_name = ArtifactType.keys()[artifact.type]
		if not history["by_type"].has(type_name):
			history["by_type"][type_name] = 0
		history["by_type"][type_name] += 1

		var rarity_name = ArtifactRarity.keys()[artifact.rarity]
		if not history["by_rarity"].has(rarity_name):
			history["by_rarity"][rarity_name] = 0
		history["by_rarity"][rarity_name] += 1

		var power = get_artifact_power(artifact.id)
		total_power += power
		if power > max_power:
			max_power = power
			history["strongest_artifact"] = artifact.name

		if artifact.age > max_age:
			max_age = artifact.age
			history["oldest_artifact"] = artifact.name

	if artifacts.size() > 0:
		history["average_power"] = total_power / float(artifacts.size())

	return history


func _get_default_description(artifact_type: int, rarity: int) -> String:
	var rarity_name = ArtifactRarity.keys()[rarity]
	var type_name = ArtifactType.keys()[artifact_type]
	return "A %s %s artifact" % [rarity_name.to_lower(), type_name.to_lower()]
