## Legendary Deed System: Record major accomplishments and record-breaking feats
##
## Tracks legendary achievements that define a dynasty's history

extends Node

class_name LegendaryDeedSystem


signal legendary_deed_recorded(deed_id: String, deed_type: int)
signal record_set(record_type: String, value: int, heir_id: String)


enum DeedType {
	FIRST_DEATH, FIRST_BOSS_DEFEAT, LEGENDARY_BATTLE,
	RICHEST_HEIR, OLDEST_HEIR, FAMILY_EXPANSION,
	FACTION_HERO, WORLD_SHAPER, DISASTER_CONQUEROR,
	BLESSING_SEEKER, DIPLOMATIC_TRIUMPH
}


var legendary_deeds: Dictionary = {}
var deeds_by_type: Dictionary = {}
var deeds_by_heir: Dictionary = {}
var records: Dictionary = {}
var deed_counter: int = 0


class LegendaryDeed:
	var id: String
	var deed_type: int
	var heir_id: String
	var generation: int
	var timestamp: float
	var value: int
	var description: String
	var witnesses: Array

	func _init(p_id: String, p_type: int, p_heir_id: String, p_gen: int, p_value: int = 0) -> void:
		id = p_id
		deed_type = p_type
		heir_id = p_heir_id
		generation = p_gen
		value = p_value
		timestamp = Time.get_ticks_msec() / 1000.0
		description = ""
		witnesses = []


func _init() -> void:
	legendary_deeds = {}
	deeds_by_type = {}
	deeds_by_heir = {}
	records = {}
	_initialize_record_types()


func _initialize_record_types() -> void:
	records = {
		"richest_heir": {"value": 0, "heir_id": "", "generation": 0},
		"oldest_heir": {"value": 0, "heir_id": "", "generation": 0},
		"most_battles_won": {"value": 0, "heir_id": "", "generation": 0},
		"most_bosses_defeated": {"value": 0, "heir_id": "", "generation": 0},
		"longest_lived": {"value": 0, "heir_id": "", "generation": 0},
		"highest_faction_standing": {"value": 0, "faction_id": "", "heir_id": "", "generation": 0},
		"most_settlements_visited": {"value": 0, "heir_id": "", "generation": 0},
		"most_disasters_survived": {"value": 0, "heir_id": "", "generation": 0},
		"most_children": {"value": 0, "heir_id": "", "generation": 0}
	}


func record_deed(deed_type: int, heir_id: String, generation: int, value: int = 0, description: String = "") -> String:
	var deed_id = "deed_%d_%d" % [deed_counter, randi()]
	deed_counter += 1

	var deed = LegendaryDeed.new(deed_id, deed_type, heir_id, generation, value)
	deed.description = description if description else _get_default_description(deed_type, value)

	legendary_deeds[deed_id] = deed

	if not deeds_by_type.has(deed_type):
		deeds_by_type[deed_type] = []
	deeds_by_type[deed_type].append(deed_id)

	if not deeds_by_heir.has(heir_id):
		deeds_by_heir[heir_id] = []
	deeds_by_heir[heir_id].append(deed_id)

	legendary_deed_recorded.emit(deed_id, deed_type)
	return deed_id


func get_deed(deed_id: String) -> LegendaryDeed:
	return legendary_deeds.get(deed_id)


func get_deeds_by_type(deed_type: int) -> Array:
	var deed_ids = deeds_by_type.get(deed_type, [])
	var result = []
	for deed_id in deed_ids:
		result.append(legendary_deeds[deed_id])
	return result


func get_deeds_by_heir(heir_id: String) -> Array:
	var deed_ids = deeds_by_heir.get(heir_id, [])
	var result = []
	for deed_id in deed_ids:
		result.append(legendary_deeds[deed_id])
	return result


func check_and_update_record(record_type: String, heir_id: String, generation: int, value: int, extra_data: Dictionary = {}) -> bool:
	if not records.has(record_type):
		return false

	var record = records[record_type]
	if value > record["value"]:
		record["value"] = value
		record["heir_id"] = heir_id
		record["generation"] = generation
		for key in extra_data:
			record[key] = extra_data[key]

		record_set.emit(record_type, value, heir_id)
		return true

	return false


func get_record(record_type: String) -> Dictionary:
	return records.get(record_type, {})


func get_all_records() -> Dictionary:
	return records.duplicate(true)


func get_top_deeds(count: int = 10, sort_by_generation: bool = true) -> Array:
	var all_deeds = []
	for deed in legendary_deeds.values():
		all_deeds.append(deed)

	if sort_by_generation:
		all_deeds.sort_custom(func(a, b): return a.generation > b.generation)
	else:
		all_deeds.sort_custom(func(a, b): return a.value > b.value)

	return all_deeds.slice(0, min(count, all_deeds.size()))


func get_heir_records(heir_id: String) -> Dictionary:
	var heir_records = {}
	var heir_deeds = get_deeds_by_heir(heir_id)

	heir_records["total_deeds"] = heir_deeds.size()
	heir_records["deeds_by_type"] = {}

	for deed in heir_deeds:
		var type_name = DeedType.keys()[deed.deed_type]
		if not heir_records["deeds_by_type"].has(type_name):
			heir_records["deeds_by_type"][type_name] = 0
		heir_records["deeds_by_type"][type_name] += 1

	# Count records this heir holds
	heir_records["records_held"] = 0
	for record_type in records.keys():
		if records[record_type]["heir_id"] == heir_id:
			heir_records["records_held"] += 1

	return heir_records


func get_generation_legacy(generation: int) -> Array:
	var legacy = []
	for deed in legendary_deeds.values():
		if deed.generation == generation:
			legacy.append(deed)
	return legacy


func _get_default_description(deed_type: int, value: int) -> String:
	match deed_type:
		DeedType.FIRST_DEATH:
			return "First death of the dynasty"
		DeedType.FIRST_BOSS_DEFEAT:
			return "Defeated a legendary boss for the first time"
		DeedType.LEGENDARY_BATTLE:
			return "Achieved victory in legendary combat"
		DeedType.RICHEST_HEIR:
			return "Amassed %d gold" % value
		DeedType.OLDEST_HEIR:
			return "Lived to age %d" % value
		DeedType.FAMILY_EXPANSION:
			return "Expanded the family with new bloodlines"
		DeedType.FACTION_HERO:
			return "Became a hero to a faction"
		DeedType.WORLD_SHAPER:
			return "Reshaped the world through their actions"
		DeedType.DISASTER_CONQUEROR:
			return "Survived and recovered from %d disasters" % value
		DeedType.BLESSING_SEEKER:
			return "Sought and found blessing in the world"
		DeedType.DIPLOMATIC_TRIUMPH:
			return "Achieved diplomatic breakthrough"
		_:
			return "Legendary achievement"


func export_deed_history() -> Dictionary:
	var history = {
		"total_deeds": legendary_deeds.size(),
		"deeds_by_type": {},
		"records_summary": {},
		"most_prolific_heir": "",
		"deed_timeline": []
	}

	# Count deeds by type
	for deed_type in deeds_by_type.keys():
		var type_name = DeedType.keys()[deed_type]
		history["deeds_by_type"][type_name] = deeds_by_type[deed_type].size()

	# Summarize records
	for record_type in records.keys():
		var record = records[record_type]
		if record["heir_id"]:
			history["records_summary"][record_type] = {
				"value": record["value"],
				"heir_id": record["heir_id"],
				"generation": record["generation"]
			}

	# Find most prolific heir
	var max_deeds = 0
	var prolific_heir = ""
	for heir_id in deeds_by_heir.keys():
		if deeds_by_heir[heir_id].size() > max_deeds:
			max_deeds = deeds_by_heir[heir_id].size()
			prolific_heir = heir_id
	history["most_prolific_heir"] = prolific_heir

	# Build timeline
	var timeline_deeds = []
	for deed in legendary_deeds.values():
		timeline_deeds.append(deed)
	timeline_deeds.sort_custom(func(a, b): return a.generation < b.generation)

	for deed in timeline_deeds.slice(0, 20):
		history["deed_timeline"].append({
			"generation": deed.generation,
			"heir_id": deed.heir_id,
			"deed_type": DeedType.keys()[deed.deed_type],
			"value": deed.value
		})

	return history


func get_dynasty_legacy(starting_generation: int = 1) -> String:
	var total_deeds = legendary_deeds.size()
	var legacy = "The dynasty has recorded %d legendary deeds. " % total_deeds

	var record_count = 0
	for record_type in records.keys():
		if records[record_type]["heir_id"]:
			record_count += 1

	legacy += "%d records stand as testament to their greatness. " % record_count

	var most_common_type = ""
	var max_count = 0
	for deed_type in deeds_by_type.keys():
		if deeds_by_type[deed_type].size() > max_count:
			max_count = deeds_by_type[deed_type].size()
			most_common_type = DeedType.keys()[deed_type]

	if most_common_type:
		legacy += "They are remembered most for their %s. " % most_common_type.to_lower()

	return legacy
