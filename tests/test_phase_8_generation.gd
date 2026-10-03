## Tests for Phase 8: Generation & Heir System
##
## Tests: GenerationManager, HeirProgression

extends GutTest


var generation_manager: GenerationManager
var heir_progression: HeirProgression


func before_each() -> void:
	generation_manager = GenerationManager.new(42)  # Seeded for reproducibility
	heir_progression = HeirProgression.new()


# ========== GenerationManager Tests ==========

## Test: Generation manager initialization
func test_generation_manager_init() -> void:
	assert_not_null(generation_manager)
	assert_not_null(generation_manager.lineage)
	assert_not_null(generation_manager.heir_progression)
	assert_eq(generation_manager.max_generations, 999)


## Test: Create founder
func test_create_founder() -> void:
	var founder = generation_manager.create_founder("Aldric", "warrior", "fighter")
	
	assert_not_null(founder)
	assert_eq(founder.name, "Aldric")
	assert_eq(founder.generation, 0)
	assert_eq(founder.class_id, "warrior")
	assert_eq(founder.job_id, "fighter")
	assert_true(founder.is_alive)


## Test: Founder has Fate Value rolled
func test_founder_fate_rolled() -> void:
	var founder = generation_manager.create_founder("Aldric", "warrior", "fighter")
	
	assert_gt(founder.fate_value, 0.0)
	assert_lt(founder.fate_value, 0.31)
	assert_true(founder.fate_tier in ["Charmed", "Steady", "Uncertain", "Ill-Starred"])


## Test: Current generation starts at 0
func test_current_generation_zero() -> void:
	generation_manager.create_founder("Aldric", "warrior", "fighter")
	assert_eq(generation_manager.get_current_generation(), 0)


## Test: Total heirs is 1 after founder
func test_total_heirs_one() -> void:
	generation_manager.create_founder("Aldric", "warrior", "fighter")
	assert_eq(generation_manager.get_total_heirs(), 1)


## Test: Get heir at generation
func test_get_heir_by_generation() -> void:
	var founder = generation_manager.create_founder("Aldric", "warrior", "fighter")
	
	var retrieved = generation_manager.get_heir(0)
	assert_eq(retrieved.name, founder.name)


## Test: Heir progression initialized
func test_heir_progression_initialized() -> void:
	var founder = generation_manager.create_founder("Aldric", "warrior", "fighter")
	
	assert_not_null(founder.crafting_skills)
	assert_not_null(founder.skill_tree)


## Test: End heir life triggers transition
func test_end_heir_life() -> void:
	var founder = generation_manager.create_founder("Aldric", "warrior", "fighter")
	assert_eq(generation_manager.get_total_heirs(), 1)
	
	generation_manager.end_heir_life("Aged")
	
	assert_false(founder.is_alive)
	assert_eq(founder.death_cause, "Aged")
	# Should create next heir (normal succession or Fate failure)
	assert_gt(generation_manager.get_total_heirs(), 1)


## Test: Succession creates generation 1 heir
func test_succession_creates_next_generation() -> void:
	var founder = generation_manager.create_founder("Aldric", "warrior", "fighter")
	generation_manager.end_heir_life("Aged")
	
	var second_heir = generation_manager.current_heir
	assert_not_null(second_heir)
	assert_eq(second_heir.generation, 1)


## Test: Next heir inherits class and job
func test_inheritance_class_and_job() -> void:
	var founder = generation_manager.create_founder("Aldric", "warrior", "fighter")
	generation_manager.end_heir_life("Aged")
	
	var second_heir = generation_manager.current_heir
	assert_eq(second_heir.class_id, founder.class_id)
	assert_eq(second_heir.job_id, founder.job_id)


## Test: Get progress percentage
func test_progress_percentage() -> void:
	generation_manager.create_founder("Aldric", "warrior", "fighter")
	var progress = generation_manager.get_progress_percentage()
	
	# 1 out of 999
	assert_gt(progress, 0.0)
	assert_lt(progress, 1.0)


## Test: Is game complete (false at start)
func test_game_not_complete_at_start() -> void:
	generation_manager.create_founder("Aldric", "warrior", "fighter")
	assert_false(generation_manager.is_game_complete())


## Test: Apply battle rewards to heir
func test_apply_battle_rewards() -> void:
	generation_manager.create_founder("Aldric", "warrior", "fighter")
	
	var rewards = {
		"victory": true,
		"damage_dealt": 250,
		"healing_received": 50,
		"abilities_used": 8,
		"enemies_defeated": 3,
		"crafting_xp": {"Blacksmithing": 50}
	}
	
	generation_manager.apply_battle_rewards(rewards)
	
	var heir = generation_manager.current_heir
	assert_true(hasattr(heir, "lifetime_stats"))


## Test: Save session
func test_save_session() -> void:
	generation_manager.create_founder("Aldric", "warrior", "fighter")
	
	var saved = generation_manager.save_session()
	
	assert_true("current_generation" in saved)
	assert_true("total_heirs" in saved)
	assert_true("heirs" in saved)
	assert_true("progress_percent" in saved)
	assert_eq(saved["total_heirs"], 1)


## Test: Get session summary
func test_get_session_summary() -> void:
	generation_manager.create_founder("Aldric", "warrior", "fighter")
	
	var summary = generation_manager.get_session_summary()
	
	assert_true("current_heir" in summary)
	assert_true("generation" in summary)
	assert_true("total_heirs" in summary)
	assert_true("progress" in summary)
	assert_true("alive" in summary)
	assert_true("fate_tier" in summary)


## Test: Heir promoted signal
func test_heir_promoted_signal() -> void:
	generation_manager.create_founder("Aldric", "warrior", "fighter")
	
	var signal_received = false
	generation_manager.heir_promoted.connect(func(new, prev): signal_received = true)
	
	generation_manager.end_heir_life("Aged")
	
	assert_true(signal_received)


## Test: Generation advanced signal
func test_generation_advanced_signal() -> void:
	generation_manager.create_founder("Aldric", "warrior", "fighter")
	
	var signal_received = false
	generation_manager.generation_advanced.connect(func(gen, total): signal_received = true)
	
	generation_manager.end_heir_life("Aged")
	
	assert_true(signal_received)


## Test: Multiple generations progression
func test_multiple_generations() -> void:
	generation_manager.create_founder("Aldric", "warrior", "fighter")
	
	for i in range(5):
		generation_manager.end_heir_life("Aged")
	
	assert_eq(generation_manager.get_total_heirs(), 6)  # Founder + 5 successors
	assert_eq(generation_manager.get_current_generation(), 5)


## Test: Get all heirs
func test_get_all_heirs() -> void:
	generation_manager.create_founder("Aldric", "warrior", "fighter")
	generation_manager.end_heir_life("Aged")
	
	var all_heirs = generation_manager.get_all_heirs()
	assert_eq(all_heirs.size(), 2)


# ========== HeirProgression Tests ==========

## Test: Heir progression initialization
func test_heir_progression_init() -> void:
	assert_not_null(heir_progression)
	assert_true("first_victory" in heir_progression.achievements)


## Test: Initialize heir
func test_initialize_heir() -> void:
	var heir = Heir.new()
	heir_progression.initialize_heir(heir)
	
	assert_not_null(heir.crafting_skills)
	assert_not_null(heir.skill_tree)


## Test: Apply stat bonus from damage
func test_apply_stat_bonus_damage() -> void:
	var heir = Heir.new()
	heir.stats["strength"] = 10
	heir_progression.initialize_heir(heir)
	
	var rewards = {
		"victory": true,
		"damage_dealt": 150,
		"abilities_used": 3,
		"healing_received": 20,
		"enemies_defeated": 2
	}
	
	heir_progression.apply_rewards(heir, rewards)
	
	assert_gt(heir.stats["strength"], 10)


## Test: Apply stat bonus from healing
func test_apply_stat_bonus_healing() -> void:
	var heir = Heir.new()
	heir.stats["constitution"] = 10
	heir_progression.initialize_heir(heir)
	
	var rewards = {
		"victory": true,
		"damage_dealt": 50,
		"abilities_used": 2,
		"healing_received": 60,
		"enemies_defeated": 1
	}
	
	heir_progression.apply_rewards(heir, rewards)
	
	assert_gt(heir.stats["constitution"], 10)


## Test: Apply skill progression
func test_apply_skill_progression() -> void:
	var heir = Heir.new()
	heir_progression.initialize_heir(heir)
	
	var rewards = {
		"victory": true,
		"damage_dealt": 100,
		"abilities_used": 5,
		"healing_received": 30,
		"enemies_defeated": 2,
		"crafting_xp": {"Blacksmithing": 50}
	}
	
	heir_progression.apply_rewards(heir, rewards)
	
	assert_true("Blacksmithing" in heir.crafting_skills)
	assert_eq(heir.crafting_skills["Blacksmithing"].xp, 50)


## Test: Skill level up
func test_skill_level_up() -> void:
	var heir = Heir.new()
	heir_progression.initialize_heir(heir)
	
	var rewards = {
		"victory": true,
		"damage_dealt": 100,
		"abilities_used": 5,
		"healing_received": 30,
		"enemies_defeated": 2,
		"crafting_xp": {"Blacksmithing": 100}  # Exactly level up
	}
	
	heir_progression.apply_rewards(heir, rewards)
	
	var skill = heir.crafting_skills["Blacksmithing"]
	assert_eq(skill.level, 2)  # Started at 1
	assert_eq(skill.xp, 0)


## Test: First victory achievement
func test_first_victory_achievement() -> void:
	var heir = Heir.new()
	heir_progression.initialize_heir(heir)
	
	var achievement_received = false
	heir_progression.achievement_earned.connect(func(h, ach):
		if ach == "first_victory":
			achievement_received = true)
	
	var rewards = {
		"victory": true,
		"damage_dealt": 50,
		"abilities_used": 2,
		"healing_received": 20,
		"enemies_defeated": 1
	}
	
	heir_progression.apply_rewards(heir, rewards)
	
	assert_true(achievement_received)


## Test: Monster slayer achievement
func test_monster_slayer_achievement() -> void:
	var heir = Heir.new()
	heir_progression.initialize_heir(heir)
	
	var achievement_received = false
	heir_progression.achievement_earned.connect(func(h, ach):
		if ach == "monster_slayer":
			achievement_received = true)
	
	var rewards = {
		"victory": true,
		"damage_dealt": 100,
		"abilities_used": 5,
		"healing_received": 30,
		"enemies_defeated": 6  # Exceeds 5
	}
	
	heir_progression.apply_rewards(heir, rewards)
	
	assert_true(achievement_received)


## Test: Combat summary tracking
func test_combat_summary() -> void:
	var heir = Heir.new()
	heir_progression.initialize_heir(heir)
	
	var rewards = {
		"victory": true,
		"damage_dealt": 150,
		"healing_received": 50,
		"enemies_defeated": 3
	}
	
	heir_progression.apply_rewards(heir, rewards)
	
	var summary = heir_progression.get_combat_summary(heir)
	
	assert_eq(summary["total_battles"], 1)
	assert_eq(summary["total_victories"], 1)
	assert_eq(summary["lifetime_damage"], 150)


## Test: Stat progression
func test_stat_progression() -> void:
	var heir = Heir.new()
	heir_progression.initialize_heir(heir)
	
	var progression = heir_progression.get_stat_progression(heir)
	
	assert_true("strength" in progression)
	assert_true("dexterity" in progression)
	assert_true("constitution" in progression)
	assert_gt(progression["strength"], 0)


## Test: Skill progression
func test_skill_progression() -> void:
	var heir = Heir.new()
	heir_progression.initialize_heir(heir)
	
	var rewards = {
		"victory": true,
		"damage_dealt": 100,
		"abilities_used": 3,
		"healing_received": 20,
		"enemies_defeated": 2,
		"crafting_xp": {"Blacksmithing": 75}
	}
	
	heir_progression.apply_rewards(heir, rewards)
	
	var progression = heir_progression.get_skill_progression(heir)
	
	assert_true("Blacksmithing" in progression)
	assert_eq(progression["Blacksmithing"]["level"], 1)
	assert_eq(progression["Blacksmithing"]["xp"], 75)


## Test: Multiple battles accumulate stats
func test_multiple_battles_accumulate() -> void:
	var heir = Heir.new()
	heir_progression.initialize_heir(heir)
	
	for i in range(3):
		var rewards = {
			"victory": true,
			"damage_dealt": 100,
			"abilities_used": 4,
			"healing_received": 25,
			"enemies_defeated": 2
		}
		heir_progression.apply_rewards(heir, rewards)
	
	var summary = heir_progression.get_combat_summary(heir)
	
	assert_eq(summary["total_battles"], 3)
	assert_eq(summary["total_victories"], 3)
	assert_eq(summary["lifetime_damage"], 300)


## Test: Defeat tracking
func test_defeat_tracking() -> void:
	var heir = Heir.new()
	heir_progression.initialize_heir(heir)
	
	var rewards = {
		"victory": false,
		"damage_dealt": 75,
		"abilities_used": 2,
		"healing_received": 40,
		"enemies_defeated": 0
	}
	
	heir_progression.apply_rewards(heir, rewards)
	
	var summary = heir_progression.get_combat_summary(heir)
	
	assert_eq(summary["total_battles"], 1)
	assert_eq(summary["total_defeats"], 1)
	assert_eq(summary["total_victories"], 0)


## Helper to check if object has attribute
func hasattr(obj: Object, attr: String) -> bool:
	return obj.get(attr) != null
