## Artifact Persistence: Save/load artifact state across generations
##
## Serializes artifacts, heirlooms, and enchantments across generation boundaries

extends Node

class_name ArtifactPersistence


signal artifact_state_saved
signal artifact_state_loaded


func save_artifact_state(
	artifact_system: ArtifactSystem,
	heirloom_system: HeirloomSystem,
	enchantment_system: ArtifactEnchantmentSystem
) -> Dictionary:
	var state = {
		"artifacts": [],
		"heirlooms": [],
		"enchantments": {},
		"artifact_counter": artifact_system.artifact_counter,
		"enchantment_counter": enchantment_system.enchantment_counter
	}

	# Save artifacts
	for artifact_id in artifact_system.artifacts.keys():
		var artifact = artifact_system.artifacts[artifact_id]
		state["artifacts"].append({
			"id": artifact.id,
			"name": artifact.name,
			"description": artifact.description,
			"type": artifact.type,
			"rarity": artifact.rarity,
			"base_stats": artifact.base_stats.duplicate(),
			"current_stats": artifact.current_stats.duplicate(),
			"age": artifact.age,
			"creation_generation": artifact.creation_generation,
			"creation_heir_id": artifact.creation_heir_id,
			"power_level": artifact.power_level,
			"bonuses": artifact.bonuses.duplicate()
		})

	# Save heirlooms
	for artifact_id in heirloom_system.heirlooms.keys():
		var heirloom = heirloom_system.heirlooms[artifact_id]
		state["heirlooms"].append({
			"artifact_id": artifact_id,
			"original_heir_id": heirloom.original_heir_id,
			"current_heir_id": heirloom.current_heir_id,
			"generation_obtained": heirloom.generation_obtained,
			"times_inherited": heirloom.times_inherited,
			"power_multiplier": heirloom.power_multiplier,
			"inheritance_chain": heirloom.inheritance_chain.duplicate(),
			"last_inherited_generation": heirloom.last_inherited_generation
		})

	# Save enchantments
	for artifact_id in enchantment_system.artifact_enchantments.keys():
		var enchantments = enchantment_system.artifact_enchantments[artifact_id]
		var enchant_list = []
		for enchantment in enchantments:
			enchant_list.append({
				"id": enchantment.id,
				"type": enchantment.type,
				"name": enchantment.name,
				"effect_description": enchantment.effect_description,
				"stat_modifications": enchantment.stat_modifications.duplicate(),
				"special_effect": enchantment.special_effect,
				"power": enchantment.power,
				"applied_at_generation": enchantment.applied_at_generation,
				"stack_count": enchantment.stack_count
			})
		state["enchantments"][artifact_id] = enchant_list

	artifact_state_saved.emit()
	return state


func load_artifact_state(
	state: Dictionary,
	artifact_system: ArtifactSystem,
	heirloom_system: HeirloomSystem,
	enchantment_system: ArtifactEnchantmentSystem
) -> void:
	if not state:
		artifact_state_loaded.emit()
		return

	# Restore artifacts
	for artifact_data in state.get("artifacts", []):
		var artifact = ArtifactSystem.Artifact.new(
			artifact_data["id"],
			artifact_data["name"],
			artifact_data["type"],
			artifact_data["rarity"],
			artifact_data["creation_generation"],
			artifact_data["creation_heir_id"]
		)
		artifact.description = artifact_data.get("description", "")
		artifact.age = artifact_data.get("age", 0)
		artifact.power_level = artifact_data.get("power_level", 1.0)
		artifact.base_stats = artifact_data.get("base_stats", {}).duplicate()
		artifact.current_stats = artifact_data.get("current_stats", {}).duplicate()
		artifact.bonuses = artifact_data.get("bonuses", []).duplicate()

		artifact_system.artifacts[artifact.id] = artifact

	artifact_system.artifact_counter = state.get("artifact_counter", 0)

	# Restore heirlooms
	for heirloom_data in state.get("heirlooms", []):
		var heirloom = HeirloomSystem.Heirloom.new(
			heirloom_data["artifact_id"],
			heirloom_data["original_heir_id"],
			heirloom_data["generation_obtained"]
		)
		heirloom.current_heir_id = heirloom_data.get("current_heir_id", "")
		heirloom.times_inherited = heirloom_data.get("times_inherited", 0)
		heirloom.power_multiplier = heirloom_data.get("power_multiplier", 1.0)
		heirloom.inheritance_chain = heirloom_data.get("inheritance_chain", []).duplicate()
		heirloom.last_inherited_generation = heirloom_data.get("last_inherited_generation", 0)

		heirloom_system.heirlooms[heirloom.artifact_id] = heirloom

		# Restore family tracking
		for heir_id in heirloom.inheritance_chain:
			if not heirloom_system.heirloom_families.has(heir_id):
				heirloom_system.heirloom_families[heir_id] = []
			if heirloom.artifact_id not in heirloom_system.heirloom_families[heir_id]:
				heirloom_system.heirloom_families[heir_id].append(heirloom.artifact_id)

	# Restore enchantments
	for artifact_id in state.get("enchantments", {}).keys():
		enchantment_system.artifact_enchantments[artifact_id] = []
		for enchant_data in state["enchantments"][artifact_id]:
			var enchantment = ArtifactEnchantmentSystem.Enchantment.new(
				enchant_data["id"],
				enchant_data["type"],
				enchant_data["name"],
				enchant_data["applied_at_generation"]
			)
			enchantment.effect_description = enchant_data.get("effect_description", "")
			enchantment.stat_modifications = enchant_data.get("stat_modifications", {}).duplicate()
			enchantment.special_effect = enchant_data.get("special_effect", "")
			enchantment.power = enchant_data.get("power", 1.0)
			enchantment.stack_count = enchant_data.get("stack_count", 1)

			enchantment_system.artifact_enchantments[artifact_id].append(enchantment)

	enchantment_system.enchantment_counter = state.get("enchantment_counter", 0)

	artifact_state_loaded.emit()


func transfer_artifacts_to_next_generation(
	state: Dictionary,
	generation: int
) -> Dictionary:
	var new_state = {
		"artifacts": state.get("artifacts", []).duplicate(true),
		"heirlooms": [],
		"enchantments": state.get("enchantments", {}).duplicate(true),
		"artifact_counter": state.get("artifact_counter", 0),
		"enchantment_counter": state.get("enchantment_counter", 0)
	}

	# Transfer heirlooms with power scaling
	for heirloom_data in state.get("heirlooms", []):
		var transferred = heirloom_data.duplicate(true)

		# Increase power multiplier for passed-down heirlooms
		var generations_since_obtained = generation - heirloom_data["generation_obtained"]
		var power_increase = 1.02 + (min(generations_since_obtained, 50) * 0.001)
		transferred["power_multiplier"] *= power_increase

		new_state["heirlooms"].append(transferred)

	return new_state


func export_artifact_history(state: Dictionary) -> Dictionary:
	var history = {
		"total_artifacts": state.get("artifacts", []).size(),
		"total_heirlooms": state.get("heirlooms", []).size(),
		"total_inheritances": 0,
		"total_enchantments": 0,
		"average_heirloom_power": 0.0,
		"strongest_heirloom": "",
		"strongest_power": 0.0,
		"artifacts_by_rarity": {}
	}

	# Count heirloom inheritances
	for heirloom_data in state.get("heirlooms", []):
		history["total_inheritances"] += heirloom_data.get("times_inherited", 0)
		var power = heirloom_data.get("power_multiplier", 1.0)
		if power > history["strongest_power"]:
			history["strongest_power"] = power
			history["strongest_heirloom"] = heirloom_data.get("artifact_id", "")

	# Count enchantments
	for artifact_id in state.get("enchantments", {}).keys():
		history["total_enchantments"] += state["enchantments"][artifact_id].size()

	# Count artifacts by rarity
	for artifact_data in state.get("artifacts", []):
		var rarity_name = ArtifactSystem.ArtifactRarity.keys()[artifact_data.get("rarity", 0)]
		if not history["artifacts_by_rarity"].has(rarity_name):
			history["artifacts_by_rarity"][rarity_name] = 0
		history["artifacts_by_rarity"][rarity_name] += 1

	# Calculate average heirloom power
	var power_sum = 0.0
	for heirloom_data in state.get("heirlooms", []):
		power_sum += heirloom_data.get("power_multiplier", 1.0)

	if state.get("heirlooms", []).size() > 0:
		history["average_heirloom_power"] = power_sum / float(state.get("heirlooms", []).size())

	return history


func get_artifact_legacy(state: Dictionary) -> String:
	if state.get("heirlooms", []).size() == 0:
		return "No family heirlooms have been established yet."

	var history = export_artifact_history(state)
	var legacy = "The family preserves %d artifacts, %d of which are treasured heirlooms. " % [history["total_artifacts"], history["total_heirlooms"]]

	if history["total_inheritances"] > 0:
		legacy += "These heirlooms have passed through %d generations. " % history["total_inheritances"]

	legacy += "Through time, they have grown to %.2fx their original strength. " % history["average_heirloom_power"]

	return legacy
