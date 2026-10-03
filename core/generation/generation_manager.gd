## Generation Manager: Orchestrates heir progression and generational transitions
##
## Manages the complete lifecycle: current heir progression → battle rewards → 
## Fate checks → generation transition → next heir creation

class_name GenerationManager


signal heir_created(heir: Heir)
signal heir_promoted(new_heir: Heir, previous_heir: Heir)
signal heir_died(heir: Heir, cause: String)
signal fate_triggered(heir: Heir, severity: String, failure_type: String)
signal generation_advanced(generation: int, total_generations: int)
signal game_complete(final_generation: int, total_heirs: int)


var lineage: Lineage = null
var current_heir: Heir = null
var heir_progression: HeirProgression = null
var fate_system: FateSystem = FateSystem.new()

# Game settings
var max_generations: int = 999
var enable_fate_checks: bool = true
var generation_lifespan_years: int = 25

# Session persistence
var session_data: Dictionary = {}


func _init(seed_value: int = 0) -> void:
	lineage = Lineage.new(seed_value)
	heir_progression = HeirProgression.new()


## Create the founder and begin the lineage
func create_founder(name: String, class_id: String, job_id: String) -> Heir:
	current_heir = lineage.create_founder(name, class_id, job_id)
	
	# Roll Fate at birth
	if enable_fate_checks:
		current_heir.roll_fate()
	
	heir_progression.initialize_heir(current_heir)
	heir_created.emit(current_heir)
	
	return current_heir


## Apply battle rewards to current heir
func apply_battle_rewards(rewards: Dictionary) -> void:
	if not current_heir:
		return
	
	heir_progression.apply_rewards(current_heir, rewards)


## Manually end current heir's life (death in battle or from age)
func end_heir_life(cause: String) -> void:
	if not current_heir:
		return
	
	current_heir.is_alive = false
	current_heir.death_cause = cause
	current_heir.death_year = current_heir.birth_year + generation_lifespan_years
	
	heir_died.emit(current_heir, cause)
	
	# Check if generation limit reached
	if lineage.generation_count() >= max_generations:
		game_complete.emit(lineage.generation_count(), lineage.generation_count())
		return
	
	# Trigger Fate check and transition to next heir
	_check_fate_and_transition()


## Internal: Check Fate at heir's death and create next heir
func _check_fate_and_transition() -> void:
	if not current_heir or not enable_fate_checks:
		return
	
	var milestone = FateSystem.Milestone.ELDER_YEARS
	var failed = FateSystem.roll_failure(current_heir.fate_value, lineage.rng)
	
	if failed:
		var severity = FateSystem.get_severity(current_heir.fate_value, lineage.rng)
		var severity_name = FateSystem.Severity.keys()[severity]
		var failure_type = FateSystem.get_failure_type(lineage.rng)
		
		fate_triggered.emit(current_heir, severity_name, failure_type)
		
		# Archetype determines next heir's bonuses/penalties
		var archetype = FateSystem.get_heir_archetype(severity, current_heir.job_id, lineage.rng)
		_create_next_heir_from_failure(current_heir, archetype, severity)
	else:
		# No failure - normal succession
		_create_next_heir_normal(current_heir)


## Create next heir with normal succession (no Fate failure)
func _create_next_heir_normal(previous_heir: Heir) -> void:
	var next_heir = lineage.produce_heir(
		previous_heir,
		previous_heir,
		"%s Jr." % previous_heir.name,
		previous_heir.class_id,
		previous_heir.job_id
	)
	
	# Roll Fate for new heir
	if enable_fate_checks:
		next_heir.roll_fate()
	
	heir_progression.initialize_heir(next_heir)
	current_heir = next_heir
	lineage.advance_generation(next_heir)
	
	heir_created.emit(next_heir)
	heir_promoted.emit(next_heir, previous_heir)
	generation_advanced.emit(lineage.current_generation, lineage.generation_count())


## Create next heir after Fate failure (with archetype bonuses/penalties)
func _create_next_heir_from_failure(previous_heir: Heir, archetype: int, severity: int) -> void:
	var next_heir = lineage.produce_heir(
		previous_heir,
		previous_heir,
		"%s II" % previous_heir.name,
		previous_heir.class_id,
		previous_heir.job_id
	)
	
	# Apply archetype-specific traits and bonuses
	_apply_archetype_modifiers(next_heir, archetype, severity)
	
	# Roll Fate for new heir (influenced by parent's failure)
	if enable_fate_checks:
		var parent_failure_modifier = 0.05 if severity >= FateSystem.Severity.MAJOR else 0.02
		next_heir.roll_fate(0.15, 0.0, true, parent_failure_modifier)
	
	heir_progression.initialize_heir(next_heir)
	current_heir = next_heir
	lineage.advance_generation(next_heir)
	
	heir_created.emit(next_heir)
	heir_promoted.emit(next_heir, previous_heir)
	generation_advanced.emit(lineage.current_generation, lineage.generation_count())


## Internal: Apply archetype-specific stat and trait modifications
func _apply_archetype_modifiers(heir: Heir, archetype: int, severity: int) -> void:
	match archetype:
		FateSystem.HeirArchetype.RESTORER:
			for stat in heir.stats:
				if stat in ["strength", "dexterity", "constitution"]:
					heir.stats[stat] = int(heir.stats[stat] * 1.15)
		
		FateSystem.HeirArchetype.REBEL:
			for stat in heir.stats:
				if stat in ["intelligence", "wisdom", "charisma"]:
					heir.stats[stat] = int(heir.stats[stat] * 1.10)
		
		FateSystem.HeirArchetype.INHERITOR:
			if heir.mother:
				for skill_name in heir.mother.crafting_skills:
					if skill_name not in heir.crafting_skills:
						heir.crafting_skills[skill_name] = heir.mother.crafting_skills[skill_name].duplicate()
		
		FateSystem.HeirArchetype.SURVIVOR:
			heir.stats["constitution"] = int(heir.stats["constitution"] * 1.20)
		
		FateSystem.HeirArchetype.REDEEMER:
			heir.stats["charisma"] = int(heir.stats["charisma"] * 1.05)
			for faction in heir.faction_reputation:
				heir.faction_reputation[faction] += 25
		
		FateSystem.HeirArchetype.SUCCESSOR:
			for stat in heir.stats:
				heir.stats[stat] = int(heir.stats[stat] * 1.05)
			if heir.mother:
				for item in heir.mother.get_equipped_items():
					heir.equipment_slots[item.slot_type] = item


## Get current generation number
func get_current_generation() -> int:
	return lineage.current_generation


## Get total heirs created so far
func get_total_heirs() -> int:
	return lineage.generation_count()


## Get heir at specific generation
func get_heir(generation: int) -> Heir:
	return lineage.get_heir(generation)


## Get all heirs in family tree
func get_all_heirs() -> Array[Heir]:
	return lineage.family_tree


## Get progress through 999 generations
func get_progress_percentage() -> float:
	return (float(lineage.generation_count()) / float(max_generations)) * 100.0


## Check if game is complete (reached max generations)
func is_game_complete() -> bool:
	return lineage.generation_count() >= max_generations


## Save current state to session
func save_session() -> Dictionary:
	if not current_heir:
		return {}
	
	var heir_list = []
	for heir in lineage.family_tree:
		heir_list.append({
			"name": heir.name,
			"generation": heir.generation,
			"class_id": heir.class_id,
			"job_id": heir.job_id,
			"traits": heir.traits,
			"fate_value": heir.fate_value,
			"fate_tier": heir.fate_tier,
			"is_alive": heir.is_alive,
			"death_cause": heir.death_cause,
			"wealth": heir.wallet.get_total_value() if heir.wallet else 0
		})
	
	session_data = {
		"current_generation": lineage.current_generation,
		"total_heirs": lineage.generation_count(),
		"heirs": heir_list,
		"progress_percent": get_progress_percentage(),
		"game_complete": is_game_complete()
	}
	
	return session_data


## Load session from save data
func load_session(data: Dictionary) -> bool:
	if data.is_empty() or not data.has("heirs"):
		return false
	
	session_data = data
	return true


## Get session summary for display
func get_session_summary() -> Dictionary:
	return {
		"current_heir": current_heir.to_string() if current_heir else "None",
		"generation": get_current_generation(),
		"total_heirs": get_total_heirs(),
		"progress": "%.1f%%" % get_progress_percentage(),
		"alive": current_heir.is_alive if current_heir else false,
		"fate_tier": current_heir.fate_tier if current_heir else "Unknown"
	}
