## Session Persistence: Save/load heir progression and game state
##
## Manages save slots, serialization of complete game state,
## and session resumption across play sessions

class_name SessionPersistence


signal game_saved(slot: int, heir_name: String, generation: int)
signal game_loaded(slot: int, heir_name: String, generation: int)
signal slot_deleted(slot: int)


const SAVE_DIR = "user://generations/"
const MAX_SAVE_SLOTS = 10

# Current session data
var current_session: Dictionary = {}
var autosave_enabled: bool = true
var autosave_interval_seconds: float = 300.0  # 5 minutes


func _init() -> void:
	_ensure_save_directory()


## Internal: Ensure save directory exists
func _ensure_save_directory() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_abs_absolute(SAVE_DIR)


## Save complete game state to slot
func save_game(slot: int, generation_manager: GenerationManager) -> bool:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		return false
	
	if not generation_manager or not generation_manager.current_heir:
		return false
	
	var heir = generation_manager.current_heir
	var save_data = _serialize_game_state(generation_manager)
	
	var file_path = "%ssave_%d.json" % [SAVE_DIR, slot]
	
	# Write to file
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return false
	
	file.store_var(save_data)
	
	current_session = save_data
	game_saved.emit(slot, heir.name, generation_manager.get_current_generation())
	
	return true


## Load game state from slot
func load_game(slot: int) -> Dictionary:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		return {}
	
	var file_path = "%ssave_%d.json" % [SAVE_DIR, slot]
	
	if not FileAccess.file_exists(file_path):
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}
	
	var save_data = file.get_var()
	current_session = save_data
	
	if save_data.has("current_heir_name"):
		game_loaded.emit(slot, save_data["current_heir_name"], save_data.get("current_generation", 0))
	
	return save_data


## Delete save slot
func delete_save(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		return false
	
	var file_path = "%ssave_%d.json" % [SAVE_DIR, slot]
	
	if FileAccess.file_exists(file_path):
		var dir = DirAccess.open(SAVE_DIR)
		if dir:
			dir.remove(file_path)
			slot_deleted.emit(slot)
			return true
	
	return false


## Get list of available save slots with info
func get_save_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	
	for i in range(MAX_SAVE_SLOTS):
		var file_path = "%ssave_%d.json" % [SAVE_DIR, i]
		
		var slot_info = {
			"slot": i,
			"exists": FileAccess.file_exists(file_path),
			"heir_name": "Empty",
			"generation": 0,
			"playtime_hours": 0.0,
			"last_save": ""
		}
		
		if slot_info["exists"]:
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file:
				var data = file.get_var()
				slot_info["heir_name"] = data.get("current_heir_name", "Unknown")
				slot_info["generation"] = data.get("current_generation", 0)
				slot_info["playtime_hours"] = data.get("playtime_seconds", 0.0) / 3600.0
				slot_info["last_save"] = data.get("save_timestamp", "")
		
		slots.append(slot_info)
	
	return slots


## Check if save slot is empty
func is_slot_empty(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		return true
	
	var file_path = "%ssave_%d.json" % [SAVE_DIR, slot]
	return not FileAccess.file_exists(file_path)


## Internal: Serialize complete game state
func _serialize_game_state(generation_manager: GenerationManager) -> Dictionary:
	var heir = generation_manager.current_heir
	
	# Serialize all heirs
	var heirs_data: Array[Dictionary] = []
	for heir_obj in generation_manager.get_all_heirs():
		heirs_data.append(_serialize_heir(heir_obj))
	
	var state = {
		"current_heir_name": heir.name if heir else "None",
		"current_generation": generation_manager.get_current_generation(),
		"total_heirs": generation_manager.get_total_heirs(),
		"progress_percent": generation_manager.get_progress_percentage(),
		"heirs": heirs_data,
		"save_timestamp": Time.get_datetime_string_from_system(),
		"playtime_seconds": Time.get_ticks_msec() / 1000.0
	}
	
	return state


## Internal: Serialize single heir
func _serialize_heir(heir: Heir) -> Dictionary:
	var skills_data: Dictionary = {}
	for skill_name in heir.crafting_skills:
		var skill = heir.crafting_skills[skill_name]
		skills_data[skill_name] = {
			"level": skill.level,
			"xp": skill.xp
		}
	
	return {
		"name": heir.name,
		"generation": heir.generation,
		"class_id": heir.class_id,
		"job_id": heir.job_id,
		"traits": heir.traits.duplicate(),
		"stats": heir.stats.duplicate(),
		"is_alive": heir.is_alive,
		"death_cause": heir.death_cause,
		"fate_value": heir.fate_value,
		"fate_tier": heir.fate_tier,
		"wealth": heir.wallet.get_total_value() if heir.wallet else 0,
		"inventory_count": heir.inventory.size(),
		"crafting_skills": skills_data,
		"faction_reputation": heir.faction_reputation.duplicate(),
		"spouse": heir.spouse.name if heir.spouse else "None"
	}


## Create autosave in first available slot
func create_autosave(generation_manager: GenerationManager) -> bool:
	# Find first empty slot or oldest save
	var slots = get_save_slots()
	var target_slot = 0
	var oldest_time = 999999999.0
	
	for slot_info in slots:
		if not slot_info["exists"]:
			target_slot = slot_info["slot"]
			break
		
		# Track oldest save
		if slot_info["slot"] > 0:  # Skip slot 0 (manual save)
			target_slot = slot_info["slot"]
	
	return save_game(target_slot, generation_manager)


## Export save as text report
func export_save_report(slot: int) -> String:
	var data = load_game(slot)
	if data.is_empty():
		return "Save slot %d is empty" % slot
	
	var report = "=== Generation Save Report ===\n\n"
	report += "Heir: %s\n" % data.get("current_heir_name", "Unknown")
	report += "Generation: %d / 999\n" % data.get("current_generation", 0)
	report += "Progress: %.1f%%\n" % data.get("progress_percent", 0.0)
	report += "Playtime: %.1f hours\n" % (data.get("playtime_seconds", 0) / 3600.0)
	report += "Saved: %s\n\n" % data.get("save_timestamp", "Unknown")
	
	# List recent heirs
	var heirs = data.get("heirs", [])
	report += "Recent Lineage:\n"
	for heir in heirs.slice(maxi(0, heirs.size() - 5), heirs.size()):
		var status = "Alive" if heir["is_alive"] else "Deceased (%s)" % heir["death_cause"]
		report += "  Gen %d: %s (%s) - %s\n" % [heir["generation"], heir["name"], heir["class_id"], status]
	
	return report


## Get session summary
func get_session_summary() -> Dictionary:
	return {
		"current_heir": current_session.get("current_heir_name", "None"),
		"generation": current_session.get("current_generation", 0),
		"progress": "%.1f%%" % current_session.get("progress_percent", 0.0),
		"playtime_hours": current_session.get("playtime_seconds", 0) / 3600.0,
		"save_timestamp": current_session.get("save_timestamp", "Never"),
		"total_heirs": current_session.get("total_heirs", 0)
	}
