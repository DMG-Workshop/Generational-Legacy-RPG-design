## Heir Progression: Applies battle rewards and achievements to heir stats
##
## Tracks how battle victories improve heir capabilities, unlock skills,
## and create lasting impact across generations

class_name HeirProgression


signal stat_increased(heir: Heir, stat_name: String, amount: int)
signal skill_unlocked(heir: Heir, skill_name: String)
signal achievement_earned(heir: Heir, achievement_id: String)


# Track milestone achievements
var achievements: Dictionary = {}


func _init() -> void:
	_initialize_achievements()


## Initialize heir with base progression tracking
func initialize_heir(heir: Heir) -> void:
	if not heir:
		return
	
	# Initialize crafting skills
	heir.initialize_crafting_skills()
	
	# Initialize skill tree
	heir.initialize_skill_tree()
	
	# Clear achievements for new heir
	achievements.clear()


## Apply battle rewards to heir progression
func apply_rewards(heir: Heir, rewards: Dictionary) -> void:
	if not heir:
		return
	
	# Apply stat bonuses from battle
	_apply_stat_bonuses(heir, rewards)
	
	# Apply skill progression
	_apply_skill_progression(heir, rewards)
	
	# Check for achievement unlocks
	_check_achievements(heir, rewards)
	
	# Apply combat experience
	_apply_combat_experience(heir, rewards)


## Internal: Apply stat increases from battle
func _apply_stat_bonuses(heir: Heir, rewards: Dictionary) -> void:
	var victory = rewards.get("victory", false)
	if not victory:
		return
	
	var damage_dealt = rewards.get("damage_dealt", 0)
	var abilities_used = rewards.get("abilities_used", 0)
	
	# Strength increases with damage dealt
	if damage_dealt > 100:
		heir.stats["strength"] += 1
		stat_increased.emit(heir, "strength", 1)
	
	# Dexterity increases with abilities used (tactical combat)
	if abilities_used > 5:
		heir.stats["dexterity"] += 1
		stat_increased.emit(heir, "dexterity", 1)
	
	# Constitution increases from healing received (survivability)
	var healing = rewards.get("healing_received", 0)
	if healing > 50:
		heir.stats["constitution"] += 1
		stat_increased.emit(heir, "constitution", 1)


## Internal: Apply skill progression from battle
func _apply_skill_progression(heir: Heir, rewards: Dictionary) -> void:
	var crafting_xp = rewards.get("crafting_xp", {})
	
	for skill_name in crafting_xp:
		var xp_gained = crafting_xp[skill_name]
		
		if skill_name not in heir.crafting_skills:
			var skill = CraftingSkill.new()
			skill.skill_type = skill_name
			skill.xp = 0
			skill.level = 1
			heir.crafting_skills[skill_name] = skill
		
		var skill = heir.crafting_skills[skill_name]
		var old_level = skill.level
		
		skill.xp += xp_gained
		
		# Check for level up (100 XP per level)
		while skill.xp >= 100:
			skill.xp -= 100
			skill.level += 1
			if skill.level > old_level:
				skill_unlocked.emit(heir, skill_name)


## Internal: Check for milestone achievements
func _check_achievements(heir: Heir, rewards: Dictionary) -> void:
	var victory = rewards.get("victory", false)
	if not victory:
		return
	
	var enemies_defeated = rewards.get("enemies_defeated", 0)
	var damage_dealt = rewards.get("damage_dealt", 0)
	var critical_hits = rewards.get("critical_hits", 0)
	
	# First victory
	if not achievements.has("first_victory"):
		achievements["first_victory"] = true
		achievement_earned.emit(heir, "first_victory")
	
	# Monster slayer (defeat 5+ enemies)
	if enemies_defeated >= 5 and not achievements.has("monster_slayer"):
		achievements["monster_slayer"] = true
		achievement_earned.emit(heir, "monster_slayer")
	
	# Damage dealer (deal 200+ damage)
	if damage_dealt >= 200 and not achievements.has("damage_dealer"):
		achievements["damage_dealer"] = true
		achievement_earned.emit(heir, "damage_dealer")
	
	# Critical strike master (land 5+ critical hits)
	if critical_hits >= 5 and not achievements.has("critical_master"):
		achievements["critical_master"] = true
		achievement_earned.emit(heir, "critical_master")


## Internal: Apply combat experience tracking
func _apply_combat_experience(heir: Heir, rewards: Dictionary) -> void:
	var victory = rewards.get("victory", false)
	
	# Track total battles
	if not hasattr(heir, "total_battles"):
		heir.total_battles = 0
	heir.total_battles += 1
	
	if victory:
		if not hasattr(heir, "total_victories"):
			heir.total_victories = 0
		heir.total_victories += 1
	else:
		if not hasattr(heir, "total_defeats"):
			heir.total_defeats = 0
		heir.total_defeats += 1
	
	# Track combat stats
	if not hasattr(heir, "lifetime_stats"):
		heir.lifetime_stats = {}
	
	for stat_key in ["damage_dealt", "damage_taken", "healing_received", "enemies_defeated"]:
		if stat_key in rewards:
			if stat_key not in heir.lifetime_stats:
				heir.lifetime_stats[stat_key] = 0
			heir.lifetime_stats[stat_key] += rewards[stat_key]


## Internal: Initialize achievement definitions
func _initialize_achievements() -> void:
	achievements = {
		"first_victory": false,
		"monster_slayer": false,
		"damage_dealer": false,
		"critical_master": false
	}


## Get heir's current achievements
func get_achievements(heir: Heir) -> Array[String]:
	var unlocked = []
	for achievement in achievements:
		if achievements[achievement]:
			unlocked.append(achievement)
	return unlocked


## Get heir's combat summary
func get_combat_summary(heir: Heir) -> Dictionary:
	return {
		"total_battles": heir.total_battles if hasattr(heir, "total_battles") else 0,
		"total_victories": heir.total_victories if hasattr(heir, "total_victories") else 0,
		"total_defeats": heir.total_defeats if hasattr(heir, "total_defeats") else 0,
		"lifetime_damage": heir.lifetime_stats.get("damage_dealt", 0) if hasattr(heir, "lifetime_stats") else 0,
		"lifetime_healing": heir.lifetime_stats.get("healing_received", 0) if hasattr(heir, "lifetime_stats") else 0,
		"enemies_defeated": heir.lifetime_stats.get("enemies_defeated", 0) if hasattr(heir, "lifetime_stats") else 0
	}


## Get heir's stat progression
func get_stat_progression(heir: Heir) -> Dictionary:
	return {
		"strength": heir.stats.get("strength", 10),
		"dexterity": heir.stats.get("dexterity", 10),
		"constitution": heir.stats.get("constitution", 10),
		"intelligence": heir.stats.get("intelligence", 10),
		"wisdom": heir.stats.get("wisdom", 10),
		"charisma": heir.stats.get("charisma", 10)
	}


## Get heir's skill progression
func get_skill_progression(heir: Heir) -> Dictionary:
	var skills = {}
	for skill_name in heir.crafting_skills:
		var skill = heir.crafting_skills[skill_name]
		skills[skill_name] = {
			"level": skill.level,
			"xp": skill.xp,
			"xp_to_next": 100 - skill.xp
		}
	return skills


## Helper to check if heir has attribute
func hasattr(obj: Object, attr: String) -> bool:
	return obj.get(attr) != null
