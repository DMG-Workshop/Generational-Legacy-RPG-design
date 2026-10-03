## Prophecy System: Generate prophecies about dynasty's future
##
## Creates mystical prophecies tied to lineage, achievements, and fate

extends Node

class_name ProphecySystem


signal prophecy_generated(prophecy_id: String, prophecy_type: int)
signal prophecy_fulfilled(prophecy_id: String, generation: int)
signal prophecy_milestone_reached(fulfilled_count: int)


enum ProphecyType { DESTINY, WARNING, BLESSING, CURSE, REVELATION }


var prophecies: Dictionary = {}
var prophecies_by_heir: Dictionary = {}
var fulfilled_prophecies: Array = []
var prophecy_counter: int = 0


class Prophecy:
	var id: String
	var type: int
	var text: String
	var related_heir_id: String
	var generation_given: int
	var prophecy_generation: int
	var fulfilled: bool
	var fulfilled_at_generation: int
	var impact: String

	func _init(p_id: String, p_type: int, p_text: String, p_generation: int) -> void:
		id = p_id
		type = p_type
		text = p_text
		generation_given = p_generation
		prophecy_generation = -1
		fulfilled = false
		fulfilled_at_generation = 0
		related_heir_id = ""
		impact = ""


func _init() -> void:
	prophecies = {}
	prophecies_by_heir = {}
	fulfilled_prophecies = []


func generate_prophecy(prophecy_type: int, generation: int, heir_id: String = "", context: Dictionary = {}) -> String:
	var prophecy_id = "prophecy_%d_%d" % [prophecy_counter, randi()]
	prophecy_counter += 1

	var text = _generate_prophecy_text(prophecy_type, generation, heir_id, context)
	var prophecy = Prophecy.new(prophecy_id, prophecy_type, text, generation)
	prophecy.related_heir_id = heir_id
	prophecy.prophecy_generation = _calculate_prophecy_generation(prophecy_type, generation)

	prophecies[prophecy_id] = prophecy

	if heir_id:
		if not prophecies_by_heir.has(heir_id):
			prophecies_by_heir[heir_id] = []
		prophecies_by_heir[heir_id].append(prophecy_id)

	prophecy_generated.emit(prophecy_id, prophecy_type)
	return prophecy_id


func fulfill_prophecy(prophecy_id: String, generation: int, impact: String = "") -> bool:
	var prophecy = prophecies.get(prophecy_id)
	if not prophecy or prophecy.fulfilled:
		return false

	prophecy.fulfilled = true
	prophecy.fulfilled_at_generation = generation
	prophecy.impact = impact if impact else _get_default_impact(prophecy.type)

	fulfilled_prophecies.append(prophecy_id)

	if fulfilled_prophecies.size() % 5 == 0:
		prophecy_milestone_reached.emit(fulfilled_prophecies.size())

	prophecy_fulfilled.emit(prophecy_id, generation)
	return true


func get_prophecy(prophecy_id: String) -> Prophecy:
	return prophecies.get(prophecy_id)


func get_prophecies_for_heir(heir_id: String) -> Array:
	var prophecy_ids = prophecies_by_heir.get(heir_id, [])
	var result = []
	for prophecy_id in prophecy_ids:
		result.append(prophecies[prophecy_id])
	return result


func get_prophecies_by_type(prophecy_type: int) -> Array:
	var result = []
	for prophecy in prophecies.values():
		if prophecy.type == prophecy_type:
			result.append(prophecy)
	return result


func get_unfulfilled_prophecies() -> Array:
	var result = []
	for prophecy in prophecies.values():
		if not prophecy.fulfilled:
			result.append(prophecy)
	return result


func get_fulfilled_prophecies() -> Array:
	var result = []
	for prophecy_id in fulfilled_prophecies:
		result.append(prophecies[prophecy_id])
	return result


func get_prophecy_fulfillment_rate() -> float:
	if prophecies.size() == 0:
		return 0.0
	return float(fulfilled_prophecies.size()) / float(prophecies.size())


func check_prophecy_fulfillment(current_generation: int, heir_id: String = "", milestone_reached: int = -1) -> Array:
	var fulfilled_this_generation = []

	for prophecy in get_unfulfilled_prophecies():
		if prophecy.prophecy_generation == current_generation:
			if not heir_id or prophecy.related_heir_id == heir_id or prophecy.related_heir_id == "":
				if fulfill_prophecy(prophecy.id, current_generation):
					fulfilled_this_generation.append(prophecy.id)

	return fulfilled_this_generation


func get_prophecy_description(prophecy_type: int) -> String:
	match prophecy_type:
		ProphecyType.DESTINY:
			return "A prophecy of great destiny"
		ProphecyType.WARNING:
			return "A prophecy of caution and trials"
		ProphecyType.BLESSING:
			return "A prophecy of divine favor"
		ProphecyType.CURSE:
			return "A prophecy of dark omens"
		ProphecyType.REVELATION:
			return "A prophecy of hidden truths"
		_:
			return "An ancient prophecy"


func get_prophecy_stats() -> Dictionary:
	var stats = {
		"total_prophecies": prophecies.size(),
		"fulfilled": fulfilled_prophecies.size(),
		"unfulfilled": 0,
		"fulfillment_rate": 0.0,
		"by_type": {},
		"generations_with_prophecies": 0
	}

	var generations_set = {}

	for prophecy in prophecies.values():
		var type_name = ProphecyType.keys()[prophecy.type]
		if not stats["by_type"].has(type_name):
			stats["by_type"][type_name] = {"total": 0, "fulfilled": 0}

		stats["by_type"][type_name]["total"] += 1
		if prophecy.fulfilled:
			stats["by_type"][type_name]["fulfilled"] += 1

		generations_set[prophecy.generation_given] = true

	stats["unfulfilled"] = prophecies.size() - fulfilled_prophecies.size()
	stats["fulfillment_rate"] = get_prophecy_fulfillment_rate()
	stats["generations_with_prophecies"] = generations_set.size()

	return stats


func export_prophecy_history() -> Dictionary:
	var history = {
		"total_prophecies": prophecies.size(),
		"fulfilled": fulfilled_prophecies.size(),
		"fulfillment_rate": get_prophecy_fulfillment_rate(),
		"prophecies_by_type": {},
		"prophecy_timeline": [],
		"earliest_prophecy_generation": 9999,
		"latest_prophecy_generation": 0
	}

	for prophecy in prophecies.values():
		var type_name = ProphecyType.keys()[prophecy.type]
		if not history["prophecies_by_type"].has(type_name):
			history["prophecies_by_type"][type_name] = 0
		history["prophecies_by_type"][type_name] += 1

		if prophecy.generation_given < history["earliest_prophecy_generation"]:
			history["earliest_prophecy_generation"] = prophecy.generation_given
		if prophecy.generation_given > history["latest_prophecy_generation"]:
			history["latest_prophecy_generation"] = prophecy.generation_given

	for prophecy_id in fulfilled_prophecies:
		var prophecy = prophecies[prophecy_id]
		history["prophecy_timeline"].append({
			"generation_given": prophecy.generation_given,
			"fulfilled_at": prophecy.fulfilled_at_generation,
			"type": ProphecyType.keys()[prophecy.type],
			"impact": prophecy.impact
		})

	return history


func get_prophecy_legacy() -> String:
	var total = prophecies.size()
	var fulfilled = fulfilled_prophecies.size()

	if total == 0:
		return "No prophecies have been spoken over this dynasty."

	var legacy = "The dynasty has been touched by %d prophecies. " % total

	if fulfilled > 0:
		var rate = int(get_prophecy_fulfillment_rate() * 100)
		legacy += "%d have come to pass (%d%% fulfillment). " % [fulfilled, rate]

	var blessings = 0
	var curses = 0
	for prophecy in prophecies.values():
		if prophecy.type == ProphecyType.BLESSING:
			blessings += 1
		elif prophecy.type == ProphecyType.CURSE:
			curses += 1

	if blessings > curses:
		legacy += "The divine has favored this line. "
	elif curses > blessings:
		legacy += "Dark forces have shadowed their path. "
	else:
		legacy += "They walk between blessing and curse. "

	return legacy


func _generate_prophecy_text(prophecy_type: int, generation: int, heir_id: String, context: Dictionary) -> String:
	match prophecy_type:
		ProphecyType.DESTINY:
			return "In generation yet to come, %s shall shape the very fate of nations." % (heir_id if heir_id else "a great hero")
		ProphecyType.WARNING:
			return "Beware, for in generation %d, trials shall test the very foundations of this dynasty." % (generation + 50)
		ProphecyType.BLESSING:
			return "The stars have spoken: this lineage is blessed with fortune beyond measure."
		ProphecyType.CURSE:
			return "A shadow falls upon this house. Woe to those who bear its name in coming ages."
		ProphecyType.REVELATION:
			return "Hidden truths shall be revealed. The dynasty's past shall shape its future."
		_:
			return "An ancient voice whispers of things yet to come."


func _calculate_prophecy_generation(prophecy_type: int, current_generation: int) -> int:
	match prophecy_type:
		ProphecyType.DESTINY:
			return current_generation + randi() % 100 + 50
		ProphecyType.WARNING:
			return current_generation + randi() % 75 + 25
		ProphecyType.BLESSING:
			return current_generation + randi() % 50 + 10
		ProphecyType.CURSE:
			return current_generation + randi() % 100 + 50
		ProphecyType.REVELATION:
			return current_generation + randi() % 200 + 100
		_:
			return current_generation + 100


func _get_default_impact(prophecy_type: int) -> String:
	match prophecy_type:
		ProphecyType.DESTINY:
			return "The dynasty's path became clear."
		ProphecyType.WARNING:
			return "The dynasty overcame the trial."
		ProphecyType.BLESSING:
			return "Divine fortune blessed the lineage."
		ProphecyType.CURSE:
			return "The shadow was lifted or embraced."
		ProphecyType.REVELATION:
			return "The truth was finally revealed."
		_:
			return "The prophecy came to pass."
