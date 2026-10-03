## Time Simulation System: Manage game time, ticks, and age progression
##
## Tracks game time in ticks/years, manages time advancement,
## and triggers age-based events

class_name TimeSimulationSystem


signal time_advanced(ticks: int, years_passed: int)
signal year_completed(year: int)
signal season_changed(season: int)
signal age_year_passed(heir_name: String)


enum Season { SPRING, SUMMER, AUTUMN, WINTER }

# Time constants
var ticks_per_year: int = 1000  # 1000 game ticks = 1 year
var ticks_per_season: int = 250  # 250 ticks = 1 season
var ticks_per_day: int = 10  # 10 ticks = 1 day

# Game time tracking
var current_tick: int = 0
var current_year: int = 0
var current_season: int = Season.SPRING

# Heir age tracking for time passage
var heir_last_aged_tick: Dictionary = {}  # heir_name -> last_tick_aged


func _init() -> void:
	current_tick = 0
	current_year = 0
	current_season = Season.SPRING


## Advance time by ticks
func advance_time(ticks: int) -> Dictionary:
	var old_tick = current_tick
	var old_year = current_year
	var old_season = current_season

	current_tick += ticks

	# Calculate years passed
	var years_passed = current_tick / ticks_per_year
	current_year = years_passed

	# Calculate season
	var ticks_in_year = current_tick % ticks_per_year
	current_season = (ticks_in_year / ticks_per_season) % 4

	time_advanced.emit(current_tick, current_year)

	# Emit year completion signal when year boundary crossed
	if current_year > old_year:
		year_completed.emit(current_year)

	# Emit season change signal when season changes
	if current_season != old_season:
		season_changed.emit(current_season)

	return {
		"ticks": current_tick,
		"years": current_year,
		"season": current_season,
		"years_advanced": current_year - old_year,
	}


## Advance time by years
func advance_years(years: int) -> Dictionary:
	return advance_time(years * ticks_per_year)


## Get current time
func get_current_time() -> Dictionary:
	return {
		"tick": current_tick,
		"year": current_year,
		"season": current_season,
		"season_name": Season.keys()[current_season],
		"day_in_year": (current_tick % ticks_per_year) / ticks_per_day,
	}


## Get time remaining in year
func get_time_remaining_in_year() -> int:
	var ticks_in_year = current_tick % ticks_per_year
	return ticks_per_year - ticks_in_year


## Get season name
func get_season_name(season: int) -> String:
	return Season.keys()[season]


## Check if heir needs aging
func should_age_heir(heir_name: String) -> bool:
	var last_aged = heir_last_aged_tick.get(heir_name, -ticks_per_year)
	var ticks_since_age = current_tick - last_aged

	return ticks_since_age >= ticks_per_year


## Mark heir as aged
func mark_heir_aged(heir_name: String) -> void:
	heir_last_aged_tick[heir_name] = current_tick
	age_year_passed.emit(heir_name)


## Get years since heir last aged
func get_years_since_heir_aged(heir_name: String) -> int:
	var last_aged = heir_last_aged_tick.get(heir_name, current_tick)
	var ticks_since = current_tick - last_aged
	return ticks_since / ticks_per_year


## Get time summary
func get_time_summary() -> Dictionary:
	var current = get_current_time()
	return {
		"total_years": current_year,
		"current_season": current["season_name"],
		"day_in_year": current["day_in_year"],
		"days_in_year": ticks_per_year / ticks_per_day,
	}


## Get year progress (0.0-1.0)
func get_year_progress() -> float:
	var ticks_in_year = current_tick % ticks_per_year
	return float(ticks_in_year) / float(ticks_per_year)


## Get season progress (0.0-1.0)
func get_season_progress() -> float:
	var ticks_in_season = current_tick % ticks_per_season
	return float(ticks_in_season) / float(ticks_per_season)


## Format time as readable string
func format_time() -> String:
	var year = current_year
	var season = Season.keys()[current_season]
	var day = (current_tick % ticks_per_year) / ticks_per_day

	return "Year %d, %s, Day %d" % [year, season, day]


## Reset time (for new game)
func reset_time() -> void:
	current_tick = 0
	current_year = 0
	current_season = Season.SPRING
	heir_last_aged_tick.clear()


## Get all heirs that need aging
func get_heirs_needing_aging(heir_names: Array) -> Array:
	var aging_needed = []
	for heir_name in heir_names:
		if should_age_heir(heir_name):
			aging_needed.append(heir_name)
	return aging_needed


## Simulate fast forward (testing utility)
func fast_forward_years(years: int) -> Dictionary:
	return advance_years(years)


## Get game day
func get_day_of_year() -> int:
	return (current_tick % ticks_per_year) / ticks_per_day


## Get game week
func get_week_of_year() -> int:
	return get_day_of_year() / 7
