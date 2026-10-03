## Heirloom System: Track artifacts passed down through family
##
## Manages inheritance, power scaling, and multi-generational artifact progression

extends Node

class_name HeirloomSystem


signal heirloom_designated(artifact_id: String, heir_id: String)
signal heirloom_inherited(artifact_id: String, from_heir: String, to_heir: String, generation: int)
signal heirloom_powered_up(artifact_id: String, new_power: float)


var heirlooms: Dictionary = {}
var heirloom_families: Dictionary = {}
var heirloom_history: Dictionary = {}


class Heirloom:
	var artifact_id: String
	var original_heir_id: String
	var current_heir_id: String
	var generation_obtained: int
	var times_inherited: int
	var power_multiplier: float
	var inheritance_chain: Array
	var last_inherited_generation: int

	func _init(p_artifact_id: String, p_original_heir: String, p_generation: int) -> void:
		artifact_id = p_artifact_id
		original_heir_id = p_original_heir
		current_heir_id = p_original_heir
		generation_obtained = p_generation
		times_inherited = 0
		power_multiplier = 1.0
		inheritance_chain = [p_original_heir]
		last_inherited_generation = p_generation


func _init() -> void:
	heirlooms = {}
	heirloom_families = {}
	heirloom_history = {}


func designate_heirloom(artifact_id: String, heir_id: String, generation: int) -> String:
	var heirloom = Heirloom.new(artifact_id, heir_id, generation)
	heirlooms[artifact_id] = heirloom

	if not heirloom_families.has(heir_id):
		heirloom_families[heir_id] = []
	heirloom_families[heir_id].append(artifact_id)

	if not heirloom_history.has(artifact_id):
		heirloom_history[artifact_id] = []
	heirloom_history[artifact_id].append({
		"event": "designated",
		"heir_id": heir_id,
		"generation": generation
	})

	heirloom_designated.emit(artifact_id, heir_id)
	return artifact_id


func inherit_heirloom(artifact_id: String, from_heir: String, to_heir: String, generation: int) -> bool:
	var heirloom = heirlooms.get(artifact_id)
	if not heirloom:
		return false
	if heirloom.current_heir_id != from_heir:
		return false

	heirloom.current_heir_id = to_heir
	heirloom.times_inherited += 1
	heirloom.last_inherited_generation = generation
	heirloom.inheritance_chain.append(to_heir)

	# Power scaling: +5-10% per inheritance (scales with generations passed)
	var generations_passed = generation - heirloom.generation_obtained
	var power_increase = 1.05 + (min(generations_passed, 50) * 0.001)
	heirloom.power_multiplier *= power_increase

	# Update family tracking
	if not heirloom_families.has(to_heir):
		heirloom_families[to_heir] = []
	heirloom_families[to_heir].append(artifact_id)

	heirloom_history[artifact_id].append({
		"event": "inherited",
		"from_heir": from_heir,
		"to_heir": to_heir,
		"generation": generation,
		"power_multiplier": heirloom.power_multiplier
	})

	heirloom_inherited.emit(artifact_id, from_heir, to_heir, generation)
	return true


func get_heirloom(artifact_id: String) -> Heirloom:
	return heirlooms.get(artifact_id)


func get_heir_heirlooms(heir_id: String) -> Array:
	var artifact_ids = heirloom_families.get(heir_id, [])
	var result = []
	for artifact_id in artifact_ids:
		if heirlooms[artifact_id].current_heir_id == heir_id:
			result.append(artifact_id)
	return result


func get_all_heir_heirlooms_in_family(heir_id: String) -> Array:
	return heirloom_families.get(heir_id, [])


func get_heirloom_chain(artifact_id: String) -> Array:
	var heirloom = heirlooms.get(artifact_id)
	if not heirloom:
		return []
	return heirloom.inheritance_chain.duplicate()


func get_power_multiplier(artifact_id: String) -> float:
	var heirloom = heirlooms.get(artifact_id)
	if not heirloom:
		return 1.0
	return heirloom.power_multiplier


func get_inheritance_count(artifact_id: String) -> int:
	var heirloom = heirlooms.get(artifact_id)
	if not heirloom:
		return 0
	return heirloom.times_inherited


func get_heirloom_age(artifact_id: String, current_generation: int) -> int:
	var heirloom = heirlooms.get(artifact_id)
	if not heirloom:
		return 0
	return current_generation - heirloom.generation_obtained


func get_heirloom_stats(artifact_id: String) -> Dictionary:
	var heirloom = heirlooms.get(artifact_id)
	if not heirloom:
		return {}

	return {
		"artifact_id": artifact_id,
		"original_heir_id": heirloom.original_heir_id,
		"current_heir_id": heirloom.current_heir_id,
		"times_inherited": heirloom.times_inherited,
		"power_multiplier": heirloom.power_multiplier,
		"inheritance_chain": heirloom.inheritance_chain.duplicate(),
		"generation_obtained": heirloom.generation_obtained,
		"last_inherited_generation": heirloom.last_inherited_generation
	}


func get_family_legacy(heir_id: String) -> Dictionary:
	var legacy = {
		"heir_id": heir_id,
		"total_heirlooms": 0,
		"current_heirlooms": 0,
		"inherited_artifacts": 0,
		"average_power_multiplier": 0.0,
		"total_power": 0.0
	}

	var current_heirlooms = get_heir_heirlooms(heir_id)
	legacy["current_heirlooms"] = current_heirlooms.size()

	var all_heirlooms = get_all_heir_heirlooms_in_family(heir_id)
	legacy["total_heirlooms"] = all_heirlooms.size()

	var power_sum = 0.0
	var power_count = 0

	for artifact_id in all_heirlooms:
		var heirloom = heirlooms[artifact_id]
		if heirloom.times_inherited > 0:
			legacy["inherited_artifacts"] += 1
		power_sum += heirloom.power_multiplier
		power_count += 1

	if power_count > 0:
		legacy["average_power_multiplier"] = power_sum / float(power_count)
		legacy["total_power"] = power_sum

	return legacy


def get_heirloom_history(artifact_id: String) -> Array:
	return heirloom_history.get(artifact_id, []).duplicate()


func list_all_heirlooms() -> Array:
	return heirlooms.keys()


func export_heirloom_history() -> Dictionary:
	var history = {
		"total_heirlooms": heirlooms.size(),
		"total_inheritances": 0,
		"average_power_multiplier": 0.0,
		"families_with_heirlooms": 0,
		"most_inherited_artifact": "",
		"max_inheritances": 0,
		"strongest_heirloom": "",
		"strongest_multiplier": 0.0
	}

	var power_sum = 0.0
	var families_set = {}

	for artifact_id in heirlooms.keys():
		var heirloom = heirlooms[artifact_id]
		history["total_inheritances"] += heirloom.times_inherited
		power_sum += heirloom.power_multiplier

		families_set[heirloom.original_heir_id] = true

		if heirloom.times_inherited > history["max_inheritances"]:
			history["max_inheritances"] = heirloom.times_inherited
			history["most_inherited_artifact"] = artifact_id

		if heirloom.power_multiplier > history["strongest_multiplier"]:
			history["strongest_multiplier"] = heirloom.power_multiplier
			history["strongest_heirloom"] = artifact_id

	history["families_with_heirlooms"] = families_set.size()

	if heirlooms.size() > 0:
		history["average_power_multiplier"] = power_sum / float(heirlooms.size())

	return history


func get_heirloom_legacy() -> String:
	if heirlooms.size() == 0:
		return "No family heirlooms have been designated."

	var history = export_heirloom_history()
	var legacy = "The family treasures %d heirlooms. " % history["total_heirlooms"]

	if history["total_inheritances"] > 0:
		legacy += "They have passed through %d hands across generations. " % history["total_inheritances"]

	legacy += "These artifacts have grown to average %.2fx their original power. " % history["average_power_multiplier"]

	return legacy
