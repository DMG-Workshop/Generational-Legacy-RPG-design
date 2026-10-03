## Realm Time System: Manage realm-specific time multipliers
##
## Tracks time acceleration per realm (2-5x), allowing different realms
## to progress at different rates

class_name RealmTimeSystem


signal realm_time_multiplier_set(realm_name: String, multiplier: float)
signal realm_visited(realm_name: String, multiplier: float)


# Realm definitions with time multipliers
var realms: Dictionary = {
	"Aethral": {
		"name": "Aethral",
		"time_multiplier": 5.0,
		"description": "Time flows five times faster here",
		"color": Color.MAGENTA,
	},
	"Chronos": {
		"name": "Chronos",
		"time_multiplier": 3.0,
		"description": "Time accelerated threefold",
		"color": Color.CYAN,
	},
	"Prime": {
		"name": "Prime",
		"time_multiplier": 1.0,
		"description": "Time flows normally",
		"color": Color.WHITE,
	},
	"Stasis": {
		"name": "Stasis",
		"time_multiplier": 0.5,
		"description": "Time moves slowly here",
		"color": Color.GRAY,
	},
	"Forgotten": {
		"name": "Forgotten",
		"time_multiplier": 2.0,
		"description": "Time flows twice as fast",
		"color": Color.DARK_BLUE,
	},
}

# Current realm tracking
var current_realm: String = "Prime"

# Realm visit history
var realm_visits: Dictionary = {}  # realm_name -> visit_count


func _init() -> void:
	for realm_name in realms.keys():
		realm_visits[realm_name] = 0


## Get realm time multiplier
func get_realm_multiplier(realm_name: String) -> float:
	if realm_name in realms:
		return realms[realm_name]["time_multiplier"]
	return 1.0


## Get current realm multiplier
func get_current_multiplier() -> float:
	return get_realm_multiplier(current_realm)


## Set current realm
func set_current_realm(realm_name: String) -> bool:
	if realm_name not in realms:
		return false

	current_realm = realm_name
	realm_visits[realm_name] += 1
	realm_visited.emit(realm_name, get_realm_multiplier(realm_name))

	return true


## Get current realm
func get_current_realm() -> String:
	return current_realm


## Get all realms
func get_all_realms() -> Array[String]:
	return realms.keys()


## Get realm info
func get_realm_info(realm_name: String) -> Dictionary:
	if realm_name not in realms:
		return {}

	return realms[realm_name].duplicate()


## Get all realm info
func get_all_realm_info() -> Array[Dictionary]:
	var info = []
	for realm_name in realms.keys():
		info.append(realms[realm_name].duplicate())
	return info


## Apply time multiplier to time passage
func apply_multiplier(base_ticks: int) -> int:
	var multiplier = get_current_multiplier()
	return int(base_ticks * multiplier)


## Apply multiplier to years
func apply_multiplier_to_years(years: int) -> int:
	var multiplier = get_current_multiplier()
	return int(years * multiplier)


## Get realm description
func get_realm_description(realm_name: String) -> String:
	if realm_name in realms:
		return realms[realm_name]["description"]
	return ""


## Get realm color
func get_realm_color(realm_name: String) -> Color:
	if realm_name in realms:
		return realms[realm_name]["color"]
	return Color.WHITE


## Get realm visit count
func get_realm_visit_count(realm_name: String) -> int:
	return realm_visits.get(realm_name, 0)


## Get most visited realm
func get_most_visited_realm() -> String:
	var most_visited = "Prime"
	var max_visits = 0

	for realm_name in realm_visits.keys():
		if realm_visits[realm_name] > max_visits:
			max_visits = realm_visits[realm_name]
			most_visited = realm_name

	return most_visited


## Get realm timeline (sorted by visit count)
func get_realm_timeline() -> Array:
	var timeline = []

	for realm_name in realm_visits.keys():
		timeline.append({
			"realm": realm_name,
			"visits": realm_visits[realm_name],
			"multiplier": get_realm_multiplier(realm_name),
		})

	# Sort by visits descending
	timeline.sort_custom(func(a, b): return a["visits"] > b["visits"])

	return timeline


## Calculate total time acceleration (sum of all multipliers across visits)
func calculate_total_time_acceleration() -> float:
	var total = 0.0

	for realm_name in realm_visits.keys():
		var visits = realm_visits[realm_name]
		var multiplier = get_realm_multiplier(realm_name)
		total += visits * multiplier

	return total


## Get realm summary
func get_realm_summary() -> Dictionary:
	return {
		"current_realm": current_realm,
		"current_multiplier": get_current_multiplier(),
		"total_visits": realm_visits.values().reduce(func(a, b): return a + b, 0),
		"most_visited": get_most_visited_realm(),
		"realm_timeline": get_realm_timeline(),
	}


## Check if realm exists
func realm_exists(realm_name: String) -> bool:
	return realm_name in realms


## Get realms by multiplier (fast to slow)
func get_realms_by_speed() -> Array:
	var sorted_realms = []

	for realm_name in realms.keys():
		sorted_realms.append({
			"realm": realm_name,
			"multiplier": get_realm_multiplier(realm_name),
		})

	# Sort by multiplier descending (fastest first)
	sorted_realms.sort_custom(func(a, b): return a["multiplier"] > b["multiplier"])

	return sorted_realms
