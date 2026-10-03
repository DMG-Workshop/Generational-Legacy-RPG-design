## Strata System: Manage generational compression and legacy persistence
##
## Tracks compressed generational data, maintains historical records,
## and manages strata transitions

class_name StrataSystem


signal strata_created(strata_id: int, generations: int)
signal strata_compressed(strata_id: int, generation_count: int)
signal legacy_echoes_recorded(strata_id: int, echo_count: int)


# Strata store generational data in compressed form
var strata: Dictionary = {}  # strata_id -> {generation_range, compressed_data, legacy_echoes}

var next_strata_id: int = 1
var generations_per_strata: int = 10  # Compress every 10 generations


## Create new strata for generational data
func create_strata(start_generation: int, end_generation: int) -> Dictionary:
	var strata_id = next_strata_id
	next_strata_id += 1

	strata[strata_id] = {
		"start_generation": start_generation,
		"end_generation": end_generation,
		"generation_count": (end_generation - start_generation) + 1,
		"compressed_data": {},
		"legacy_echoes": [],
		"created_tick": Time.get_ticks_msec(),
	}

	strata_created.emit(strata_id, strata[strata_id]["generation_count"])

	return {
		"success": true,
		"strata_id": strata_id,
		"generations": strata[strata_id]["generation_count"],
	}


## Compress generation into strata
func compress_generation_data(strata_id: int, generation: int, gen_data: Dictionary) -> bool:
	if strata_id not in strata:
		return false

	var gen_key = "gen_%d" % generation
	strata[strata_id]["compressed_data"][gen_key] = {
		"generation": generation,
		"heir_name": gen_data.get("heir_name", ""),
		"age_at_death": gen_data.get("age_at_death", 0),
		"legacy_value": gen_data.get("legacy_value", 0),
		"cause": gen_data.get("cause", "unknown"),
	}

	strata_compressed.emit(strata_id, strata[strata_id]["generation_count"])
	return true


## Record legacy echo for strata
func record_legacy_echo(strata_id: int, echo: Dictionary) -> bool:
	if strata_id not in strata:
		return false

	strata[strata_id]["legacy_echoes"].append({
		"generation": echo.get("generation", 0),
		"heir_name": echo.get("heir_name", ""),
		"description": echo.get("description", ""),
		"impact": echo.get("impact", 0),
	})

	legacy_echoes_recorded.emit(strata_id, strata[strata_id]["legacy_echoes"].size())
	return true


## Get strata data
func get_strata(strata_id: int) -> Dictionary:
	if strata_id not in strata:
		return {}

	return strata[strata_id].duplicate()


## Get all strata
func get_all_strata() -> Array:
	var all_strata = []
	for strata_id in strata.keys():
		all_strata.append(strata[strata_id].duplicate())
	return all_strata


## Get legacy echoes from strata
func get_legacy_echoes(strata_id: int) -> Array:
	if strata_id not in strata:
		return []

	return strata[strata_id]["legacy_echoes"].duplicate()


## Count total legacy echoes across all strata
func count_total_legacy_echoes() -> int:
	var total = 0
	for strata_id in strata.keys():
		total += strata[strata_id]["legacy_echoes"].size()
	return total


## Calculate strata legacy value (sum of all generations in strata)
func calculate_strata_value(strata_id: int) -> int:
	if strata_id not in strata:
		return 0

	var total = 0
	for gen_key in strata[strata_id]["compressed_data"].keys():
		total += strata[strata_id]["compressed_data"][gen_key]["legacy_value"]

	return total


## Get strata timeline
func get_strata_timeline() -> Array:
	var timeline = []

	for strata_id in strata.keys():
		timeline.append({
			"strata_id": strata_id,
			"generation_range": "%d-%d" % [strata[strata_id]["start_generation"], strata[strata_id]["end_generation"]],
			"generation_count": strata[strata_id]["generation_count"],
			"legacy_value": calculate_strata_value(strata_id),
			"echo_count": strata[strata_id]["legacy_echoes"].size(),
		})

	return timeline


## Get most recent strata
func get_latest_strata() -> Dictionary:
	if strata.is_empty():
		return {}

	var latest_id = strata.keys().max()
	return get_strata(latest_id)


## Get all heroes from strata (heroes with high legacy value)
func get_heroes_from_strata(min_legacy_value: int = 100) -> Array:
	var heroes = []

	for strata_id in strata.keys():
		for gen_key in strata[strata_id]["compressed_data"].keys():
			var gen_data = strata[strata_id]["compressed_data"][gen_key]
			if gen_data["legacy_value"] >= min_legacy_value:
				heroes.append({
					"heir_name": gen_data["heir_name"],
					"generation": gen_data["generation"],
					"legacy_value": gen_data["legacy_value"],
					"age": gen_data["age_at_death"],
				})

	return heroes


## Calculate total legacy across all strata
func calculate_total_legacy() -> int:
	var total = 0
	for strata_id in strata.keys():
		total += calculate_strata_value(strata_id)
	return total


## Get strata summary
func get_strata_summary() -> Dictionary:
	return {
		"total_strata": strata.size(),
		"generations_stored": strata.size() * generations_per_strata,
		"total_legacy": calculate_total_legacy(),
		"total_echoes": count_total_legacy_echoes(),
		"strata_timeline": get_strata_timeline(),
	}


## Archive strata (mark as historical)
func archive_strata(strata_id: int) -> bool:
	if strata_id not in strata:
		return false

	strata[strata_id]["archived"] = true
	strata[strata_id]["archived_tick"] = Time.get_ticks_msec()

	return true


## Get archived strata
func get_archived_strata() -> Array:
	var archived = []
	for strata_id in strata.keys():
		if strata[strata_id].get("archived", false):
			archived.append(strata[strata_id].duplicate())
	return archived


## Merge old strata (combine multiple strata for compression)
func merge_strata(strata_ids: Array) -> Dictionary:
	if strata_ids.is_empty():
		return {"success": false, "reason": "no_strata_to_merge"}

	var new_strata = create_strata(1, 100)  # Placeholder range
	var merged_echoes = []
	var merged_data = {}

	for strata_id in strata_ids:
		if strata_id in strata:
			for gen_key in strata[strata_id]["compressed_data"].keys():
				merged_data[gen_key] = strata[strata_id]["compressed_data"][gen_key]

			merged_echoes.append_array(strata[strata_id]["legacy_echoes"])

	new_strata_id = new_strata["strata_id"]
	strata[new_strata_id]["compressed_data"] = merged_data
	strata[new_strata_id]["legacy_echoes"] = merged_echoes

	return {
		"success": true,
		"merged_strata_id": new_strata_id,
		"merged_count": strata_ids.size(),
	}


## Get lineage summary from strata
func get_lineage_summary() -> Array:
	var lineage = []

	for strata_id in strata.keys():
		for gen_key in strata[strata_id]["compressed_data"].keys():
			var gen_data = strata[strata_id]["compressed_data"][gen_key]
			lineage.append({
				"generation": gen_data["generation"],
				"heir": gen_data["heir_name"],
				"age": gen_data["age_at_death"],
				"legacy": gen_data["legacy_value"],
			})

	return lineage
