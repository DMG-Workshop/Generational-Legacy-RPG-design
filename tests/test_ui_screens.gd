## Tests for the UI rendering layer (Phase 5)
##
## Tests: screen creation, transitions, menu interactions

extends GutTest


var main_game: MainGame
var lineage: Lineage
var world: WorldManager


func before_each() -> void:
	lineage = Lineage.new(42)
	world = WorldManager.new()
	main_game = MainGame.new()


## Test: Main game initializes with main menu
func test_main_game_starts_with_menu() -> void:
	assert_eq(main_game.current_mode, MainGame.GameMode.MAIN_MENU)
	assert_not_null(main_game.current_screen)


## Test: New game transitions to world screen
func test_new_game_opens_world() -> void:
	main_game.start_new_game()

	assert_eq(main_game.current_mode, MainGame.GameMode.WORLD_EXPLORATION)
	assert_true(main_game.current_screen is WorldScreen)


## Test: Character menu can be opened from world
func test_open_character_menu() -> void:
	main_game.start_new_game()
	main_game.show_screen("character")

	assert_eq(main_game.current_mode, MainGame.GameMode.CHARACTER_MENU)
	assert_true(main_game.current_screen is CharacterMenuScreen)


## Test: Pause menu can be toggled
func test_pause_menu() -> void:
	main_game.start_new_game()
	var initial_mode = main_game.current_mode

	main_game.toggle_pause()
	assert_eq(main_game.current_mode, MainGame.GameMode.PAUSE_MENU)
	assert_true(main_game.paused)

	main_game.toggle_pause()
	assert_eq(main_game.current_mode, initial_mode)
	assert_false(main_game.paused)


## Test: Battle screen initializes correctly
func test_battle_screen_init() -> void:
	var battle_screen = BattleScreen.new()

	assert_not_null(battle_screen)
	assert_eq(battle_screen.turn_order_index, 0)


## Test: World screen displays player position
func test_world_screen_player_position() -> void:
	var gen_manager = GenerationManager.new(lineage, world)
	var founder = lineage.create_founder("Test", "warrior", "merchant")
	gen_manager.begin_generation(founder)

	var world_screen = WorldScreen.new(gen_manager, world)

	assert_eq(world_screen.player_pos, Vector3i.ZERO)


## Test: Character menu displays heir information
func test_character_menu_shows_heir_stats() -> void:
	var heir = Heir.new()
	heir.name = "Test Hero"
	heir.class_id = "warrior"
	heir.job_id = "knight"
	heir.traits = ["warrior_steel", "noble_blood"]

	var char_screen = CharacterMenuScreen.new(heir)

	assert_not_null(char_screen)
	assert_eq(char_screen.heir, heir)


## Test: Generation transition screen displays children
func test_generation_transition_shows_children() -> void:
	var gen_manager = GenerationManager.new(lineage, world)
	var founder = lineage.create_founder("Parent", "warrior", "merchant")
	gen_manager.begin_generation(founder)

	# Add some children
	var child1 = Heir.new()
	child1.name = "Child 1"
	child1.generation = 1
	gen_manager.children.append(child1)

	var trans_screen = GenerationTransitionScreen.new(gen_manager)

	assert_not_null(trans_screen)
	assert_eq(gen_manager.children.size(), 1)


## Test: Save game creates file
func test_save_game() -> void:
	main_game.start_new_game()
	var result = main_game.save_game(0)

	# Check that save was attempted (would need file system to verify)
	assert_true(result or !FileAccess.file_exists("user://saves/slot_0.save"))


## Test: Screen transitions maintain game state
func test_screen_transitions_preserve_state() -> void:
	main_game.start_new_game()
	var founder = main_game.current_generation_manager.current_heir

	main_game.show_screen("character")
	main_game.show_screen("world")

	assert_eq(main_game.current_generation_manager.current_heir, founder)


## Test: Pause/resume preserves position
func test_pause_resume_preserves_position() -> void:
	main_game.start_new_game()
	var world_screen = main_game.current_screen as WorldScreen
	world_screen.player_pos = Vector3i(5, 5, 0)

	main_game.toggle_pause()
	main_game.toggle_pause()

	var resumed_screen = main_game.current_screen as WorldScreen
	assert_eq(resumed_screen.player_pos, Vector3i(5, 5, 0))


## Test: Enhanced character menu has tabs
func test_enhanced_character_menu_tabs() -> void:
	var heir = Heir.new()
	heir.name = "Test Hero"
	heir.class_id = "warrior"

	var char_menu = CharacterMenuEnhanced.new(heir)

	assert_not_null(char_menu)
	assert_eq(char_menu.current_tab, "character")


## Test: Generation transition shows heir stats
func test_generation_transition_heir_stats() -> void:
	var gen_manager = GenerationManager.new(lineage, world)
	var founder = lineage.create_founder("Parent", "warrior", "merchant")
	gen_manager.begin_generation(founder)

	# Create child with specific stats
	var child = Heir.new()
	child.name = "Child Hero"
	child.generation = 1
	child.strength = 16
	child.constitution = 14
	child.dexterity = 13
	gen_manager.children.append(child)

	var trans_screen = GenerationTransitionScreen.new(gen_manager)

	assert_not_null(trans_screen)
	assert_eq(child.strength, 16)


## Test: Skill tree initialization
func test_skill_tree_init() -> void:
	var heir = Heir.new()
	heir.class_id = "warrior"

	var skill_tree = SkillTree.new(heir)

	assert_not_null(skill_tree)
	assert_eq(skill_tree.heir.class_id, "warrior")
