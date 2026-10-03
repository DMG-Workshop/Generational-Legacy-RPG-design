## Test Suite for Phase 10: UI/Rendering Layer
##
## Comprehensive tests for battle screens, menus, family tree display,
## stats screens, world screens, and UI integration

extends GutTest


var menu_manager: MenuManager
var battle_screen: BattleScreen
var battle_hud: BattleHUD
var family_tree_screen: FamilyTreeScreen
var stats_screen: StatsScreen
var world_screen: WorldScreen
var ui_integration: UIIntegration


func before_each() -> void:
	menu_manager = MenuManager.new()
	battle_screen = BattleScreen.new()
	battle_hud = BattleHUD.new()
	family_tree_screen = FamilyTreeScreen.new()
	stats_screen = StatsScreen.new()
	world_screen = WorldScreen.new()
	ui_integration = UIIntegration.new()


# ============================================================
# Menu Manager Tests
# ============================================================

func test_menu_manager_created() -> void:
	assert_not_null(menu_manager)


func test_main_menu_visible_on_start() -> void:
	menu_manager._ready()
	assert_true(menu_manager.main_menu.visible)


func test_pause_menu_hidden_initially() -> void:
	menu_manager._ready()
	assert_false(menu_manager.pause_menu.visible)


func test_show_settings_menu() -> void:
	menu_manager._ready()
	menu_manager.show_menu(MenuManager.MenuType.SETTINGS)
	assert_eq(menu_manager.current_menu, MenuManager.MenuType.SETTINGS)


func test_toggle_pause_menu() -> void:
	menu_manager._ready()
	menu_manager.toggle_pause_menu()
	assert_true(menu_manager.pause_menu.visible)


func test_escape_toggles_pause() -> void:
	menu_manager._ready()
	var event = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	menu_manager._input(event)
	# Pause menu should toggle


func test_menu_state_tracking() -> void:
	menu_manager._ready()
	assert_true(menu_manager.is_menu_visible())
	menu_manager.hide_all_menus()
	assert_false(menu_manager.is_menu_visible())


# ============================================================
# Battle Screen Tests
# ============================================================

func test_battle_screen_created() -> void:
	assert_not_null(battle_screen)


func test_battle_screen_initialization() -> void:
	var player = {"name": "Hero", "hp": 100, "max_hp": 100, "class": "Warrior"}
	var enemies = [{"name": "Goblin", "hp": 20, "max_hp": 20}]

	battle_screen._setup_battle_screen()
	battle_screen.initialize_battle(player, enemies, null)

	assert_eq(battle_screen.current_battle_data["player"]["name"], "Hero")


func test_player_turn_display() -> void:
	battle_screen._setup_battle_screen()
	battle_screen.start_player_turn()
	assert_eq(battle_screen.turn_label.text, "Player Turn")


func test_enemy_turn_display() -> void:
	battle_screen._setup_battle_screen()
	battle_screen.start_enemy_turn(0)
	assert_true("Turn" in battle_screen.turn_label.text)


func test_process_action_result() -> void:
	battle_screen._setup_battle_screen()
	var action = {"type": "attack", "actor": "Hero", "target": 0, "damage": 15}
	battle_screen.process_action_result(action)
	assert_true("attacks" in battle_screen.log_panel.text)


func test_victory_display() -> void:
	battle_screen._setup_battle_screen()
	var rewards = {"gold": 100, "xp": 50}
	battle_screen.display_victory(rewards)
	assert_true("VICTORY" in battle_screen.log_panel.text)


func test_defeat_display() -> void:
	battle_screen._setup_battle_screen()
	battle_screen.display_defeat()
	assert_true("DEFEAT" in battle_screen.log_panel.text)


func test_hp_update() -> void:
	battle_screen._setup_battle_screen()
	battle_screen.current_battle_data = {
		"player": {"name": "Hero", "hp": 100, "max_hp": 100},
		"enemies": [{"name": "Goblin", "hp": 20, "max_hp": 20}]
	}
	battle_screen._update_player_display()
	# Player sprite should have label with HP


# ============================================================
# Battle HUD Tests
# ============================================================

func test_battle_hud_created() -> void:
	assert_not_null(battle_hud)


func test_battle_hud_setup() -> void:
	battle_hud._setup_ui()
	assert_not_null(battle_hud.player_hp_bar)
	assert_not_null(battle_hud.enemy_hp_bar)


func test_hud_initialization() -> void:
	var player = {"hp": 80, "max_hp": 100}
	var enemies = [{"hp": 30, "max_hp": 50}]

	battle_hud._setup_ui()
	battle_hud.initialize_battle(player, enemies)
	assert_true(battle_hud.battle_active)


func test_damage_display_floating_text() -> void:
	battle_hud._setup_ui()
	battle_hud.display_damage(25, Vector2(100, 100))
	# Label should be added


func test_healing_display_floating_text() -> void:
	battle_hud._setup_ui()
	battle_hud.display_healing(30, Vector2(100, 100))
	# Label should be added


func test_turn_indicator_update() -> void:
	battle_hud._setup_ui()
	battle_hud.current_battle = {"current_turn": "player", "turn_count": 1}
	battle_hud._update_turn_indicator()
	assert_true("Player" in battle_hud.turn_indicator.text)


# ============================================================
# Family Tree Screen Tests
# ============================================================

func test_family_tree_created() -> void:
	assert_not_null(family_tree_screen)


func test_family_tree_ui_setup() -> void:
	family_tree_screen._setup_family_tree_ui()
	assert_not_null(family_tree_screen.tree_container)
	assert_not_null(family_tree_screen.heir_detail_panel)


func test_heir_node_creation() -> void:
	family_tree_screen._setup_family_tree_ui()
	var heir = {"name": "Hero1", "generation": 1, "age": 30}
	var node = family_tree_screen._create_heir_node(heir, Vector2(100, 100))
	assert_not_null(node)


func test_heir_selection() -> void:
	family_tree_screen._setup_family_tree_ui()
	family_tree_screen._on_heir_selected("Hero1")
	assert_eq(family_tree_screen.current_selected_heir, "Hero1")


func test_highlight_heir() -> void:
	family_tree_screen._setup_family_tree_ui()
	var heir = {"name": "Hero1", "generation": 1, "age": 30}
	var node = family_tree_screen._create_heir_node(heir, Vector2(100, 100))
	family_tree_screen.heir_nodes["Hero1"] = node

	family_tree_screen.highlight_heir("Hero1")
	# Node should be highlighted


func test_reset_highlights() -> void:
	family_tree_screen._setup_family_tree_ui()
	family_tree_screen.reset_highlights()
	# All highlights should be cleared


# ============================================================
# Stats Screen Tests
# ============================================================

func test_stats_screen_created() -> void:
	assert_not_null(stats_screen)


func test_stats_screen_ui_setup() -> void:
	stats_screen._setup_stats_ui()
	assert_not_null(stats_screen.view_tabs)
	assert_not_null(stats_screen.content_panel)


func test_initialize_heir_stats() -> void:
	stats_screen._setup_stats_ui()
	var heir = {"strength": 10, "dexterity": 8, "constitution": 12}
	stats_screen.initialize_heir_stats("Hero1", heir)
	assert_eq(stats_screen.heir_data["name"], "Hero1")


func test_stats_view_display() -> void:
	stats_screen._setup_stats_ui()
	var heir = {"strength": 10, "dexterity": 8, "constitution": 12, "intelligence": 9, "wisdom": 11, "charisma": 7}
	stats_screen.initialize_heir_stats("Hero1", heir)
	stats_screen.current_view = StatsScreen.ViewType.STATS
	stats_screen._display_stats_view()
	# Stats should be displayed


func test_skills_view_display() -> void:
	stats_screen._setup_stats_ui()
	var heir = {"skills": {"Blacksmithing": {"level": 3, "xp": 50}}}
	stats_screen.initialize_heir_stats("Hero1", heir)
	stats_screen.current_view = StatsScreen.ViewType.SKILLS
	stats_screen._display_skills_view()
	# Skills should be displayed


func test_traits_view_display() -> void:
	stats_screen._setup_stats_ui()
	var heir = {"bloodline_traits": ["Strong"], "acquired_traits": ["Brave"]}
	stats_screen.initialize_heir_stats("Hero1", heir)
	stats_screen.current_view = StatsScreen.ViewType.TRAITS
	stats_screen._display_traits_view()
	# Traits should be displayed


func test_equipment_view_display() -> void:
	stats_screen._setup_stats_ui()
	var heir = {"equipped": {"Weapon": {"name": "Sword", "rarity": "Common", "stats": {"strength": 2}}}}
	stats_screen.initialize_heir_stats("Hero1", heir)
	stats_screen.current_view = StatsScreen.ViewType.EQUIPMENT
	stats_screen._display_equipment_view()
	# Equipment should be displayed


func test_transformations_view_display() -> void:
	stats_screen._setup_stats_ui()
	var heir = {"corruption_level": 25, "curses": ["Weakness"], "blessings": ["Vigor"]}
	stats_screen.initialize_heir_stats("Hero1", heir)
	stats_screen.current_view = StatsScreen.ViewType.TRANSFORMATIONS
	stats_screen._display_transformations_view()
	# Transformations should be displayed


func test_progression_view_display() -> void:
	stats_screen._setup_stats_ui()
	var heir = {"age": 35, "life_stage": "Adult", "experience": 1000, "legacy_value": 500, "generation": 2}
	stats_screen.initialize_heir_stats("Hero1", heir)
	stats_screen.current_view = StatsScreen.ViewType.PROGRESSION
	stats_screen._display_progression_view()
	# Progression should be displayed


func test_tab_switching() -> void:
	stats_screen._setup_stats_ui()
	stats_screen._on_tab_changed(1)
	assert_eq(stats_screen.current_view, 1)


# ============================================================
# World Screen Tests
# ============================================================

func test_world_screen_created() -> void:
	assert_not_null(world_screen)


func test_world_screen_ui_setup() -> void:
	world_screen._setup_world_ui()
	assert_not_null(world_screen.location_label)
	assert_not_null(world_screen.time_display)
	assert_not_null(world_screen.movement_pad)


func test_initialize_world() -> void:
	world_screen._setup_world_ui()
	world_screen._setup_camera()
	world_screen.initialize_world(Vector2i(10, 10))
	assert_eq(world_screen.heir_position, Vector2i(10, 10))


func test_heir_movement_up() -> void:
	world_screen._setup_world_ui()
	world_screen._setup_camera()
	world_screen.initialize_world(Vector2i(10, 10))
	world_screen._on_move_up()
	assert_eq(world_screen.heir_position, Vector2i(10, 9))


func test_heir_movement_down() -> void:
	world_screen._setup_world_ui()
	world_screen._setup_camera()
	world_screen.initialize_world(Vector2i(10, 10))
	world_screen._on_move_down()
	assert_eq(world_screen.heir_position, Vector2i(10, 11))


func test_heir_movement_left() -> void:
	world_screen._setup_world_ui()
	world_screen._setup_camera()
	world_screen.initialize_world(Vector2i(10, 10))
	world_screen._on_move_left()
	assert_eq(world_screen.heir_position, Vector2i(9, 10))


func test_heir_movement_right() -> void:
	world_screen._setup_world_ui()
	world_screen._setup_camera()
	world_screen.initialize_world(Vector2i(10, 10))
	world_screen._on_move_right()
	assert_eq(world_screen.heir_position, Vector2i(11, 10))


func test_time_display_update() -> void:
	world_screen._setup_world_ui()
	world_screen.update_time(5, "Summer")
	assert_true("Year 5" in world_screen.time_display.text)


func test_realm_display_update() -> void:
	world_screen._setup_world_ui()
	world_screen.update_realm("Chronos")
	assert_true("Chronos" in world_screen.realm_display.text)


func test_location_name_determination() -> void:
	world_screen._setup_world_ui()
	var location = world_screen._get_location_name(Vector2i(0, 0))
	assert_true(location.length() > 0)


# ============================================================
# UI Integration Tests
# ============================================================

func test_ui_integration_created() -> void:
	assert_not_null(ui_integration)


func test_show_battle_screen() -> void:
	ui_integration._initialize_ui_systems()
	var player = {"name": "Hero", "hp": 100, "max_hp": 100}
	var enemies = [{"name": "Enemy", "hp": 50, "max_hp": 50}]

	ui_integration.show_battle(player, enemies)
	assert_true(ui_integration.battle_active)
	assert_eq(ui_integration.current_screen, "battle")


func test_hide_battle_screen() -> void:
	ui_integration._initialize_ui_systems()
	ui_integration.show_battle({}, [])
	ui_integration.hide_battle()
	assert_false(ui_integration.battle_active)


func test_show_stats_screen() -> void:
	ui_integration._initialize_ui_systems()
	var heir = {"strength": 10}
	ui_integration.show_stats_screen("Hero1", heir)
	assert_eq(ui_integration.current_screen, "stats")


func test_hide_stats_screen() -> void:
	ui_integration._initialize_ui_systems()
	ui_integration.show_stats_screen("Hero1", {})
	ui_integration.hide_stats_screen()
	assert_eq(ui_integration.current_screen, "world")


func test_show_family_tree() -> void:
	ui_integration._initialize_ui_systems()
	var lineage = [{"name": "Hero1", "generation": 1}]
	ui_integration.show_family_tree(lineage, 1)
	assert_eq(ui_integration.current_screen, "family_tree")


func test_update_world_time() -> void:
	ui_integration._initialize_ui_systems()
	ui_integration.update_world_time(10, "Autumn")
	# World screen time should update


func test_notification_system() -> void:
	ui_integration._initialize_ui_systems()
	ui_integration.show_notification("Test Notification", 1.0)
	# Notification should be displayed


# ============================================================
# Complex Scenario Tests
# ============================================================

func test_full_battle_flow() -> void:
	ui_integration._initialize_ui_systems()
	var player = {"name": "Hero", "hp": 100, "max_hp": 100}
	var enemies = [{"name": "Enemy", "hp": 50, "max_hp": 50}]

	ui_integration.show_battle(player, enemies)
	assert_true(ui_integration.battle_active)

	# Simulate action
	var action = {"type": "attack", "actor": "Hero", "damage": 10}
	ui_integration.update_battle_display(action)

	# End battle
	ui_integration.hide_battle()
	assert_false(ui_integration.battle_active)


func test_world_exploration_flow() -> void:
	ui_integration._initialize_ui_systems()
	ui_integration.update_world_time(1, "Spring")
	ui_integration.update_world_realm("Prime")
	# World should be initialized and ready


func test_menu_to_game_transition() -> void:
	ui_integration._initialize_ui_systems()
	ui_integration.menu_manager._ready()
	# Game should start and display world
