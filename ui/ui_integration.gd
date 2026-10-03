## UI Integration: Ties all UI systems to game logic
##
## Coordinates menus, screens, displays, and handles game state rendering

extends Node

class_name UIIntegration


# UI systems
var menu_manager: MenuManager
var battle_screen: BattleScreen
var battle_hud: BattleHUD
var family_tree_screen: FamilyTreeScreen
var stats_screen: StatsScreen
var world_screen: WorldScreen

# Game systems (references)
var battle_system: Object
var heir_system: Object
var world_system: Object
var time_system: Object
var generation_system: Object

# UI state
var current_screen: String = "world"
var battle_active: bool = false


func _ready() -> void:
	_initialize_ui_systems()
	_connect_signals()


## Initialize all UI systems
func _initialize_ui_systems() -> void:
	# Create menu manager
	menu_manager = MenuManager.new()
	add_child(menu_manager)

	# Create battle screen
	battle_screen = BattleScreen.new()
	add_child(battle_screen)
	battle_screen.visible = false

	# Create battle HUD
	battle_hud = BattleHUD.new()
	add_child(battle_hud)
	battle_hud.visible = false

	# Create family tree screen
	family_tree_screen = FamilyTreeScreen.new()
	add_child(family_tree_screen)
	family_tree_screen.visible = false

	# Create stats screen
	stats_screen = StatsScreen.new()
	add_child(stats_screen)
	stats_screen.visible = false

	# Create world screen
	world_screen = WorldScreen.new()
	add_child(world_screen)
	world_screen.visible = true


## Connect UI signals to game systems
func _connect_signals() -> void:
	# Menu signals
	if menu_manager:
		menu_manager.game_started.connect(_on_game_started)
		menu_manager.game_resumed.connect(_on_game_resumed)
		menu_manager.settings_changed.connect(_on_settings_changed)

	# Battle signals
	if battle_screen:
		battle_screen.battle_action_requested.connect(_on_battle_action)
		battle_screen.battle_ended.connect(_on_battle_ended)

	# World signals
	if world_screen:
		world_screen.heir_moved.connect(_on_heir_moved)
		world_screen.settlement_entered.connect(_on_settlement_entered)


## Show battle screen
func show_battle(player: Dictionary, enemies: Array) -> void:
	current_screen = "battle"
	battle_active = true
	world_screen.visible = false
	battle_screen.visible = true
	battle_hud.visible = true

	battle_screen.initialize_battle(player, enemies, battle_system)
	battle_hud.initialize_battle(player, enemies)


## Hide battle screen
func hide_battle() -> void:
	current_screen = "world"
	battle_active = false
	battle_screen.visible = false
	battle_hud.visible = false
	world_screen.visible = true


## Update battle display
func update_battle_display(action: Dictionary) -> void:
	if battle_screen:
		battle_screen.process_action_result(action)
	if battle_hud:
		battle_hud.update_display()


## Show stats screen
func show_stats_screen(heir_name: String, heir_data: Dictionary) -> void:
	current_screen = "stats"
	world_screen.visible = false
	stats_screen.visible = true
	stats_screen.initialize_heir_stats(heir_name, heir_data)


## Hide stats screen
func hide_stats_screen() -> void:
	current_screen = "world"
	stats_screen.visible = false
	world_screen.visible = true


## Show family tree
func show_family_tree(lineage_data: Array, generation: int) -> void:
	current_screen = "family_tree"
	world_screen.visible = false
	family_tree_screen.visible = true
	family_tree_screen.initialize_tree(lineage_data, generation)


## Hide family tree
func hide_family_tree() -> void:
	current_screen = "world"
	family_tree_screen.visible = false
	world_screen.visible = true


## Update world time display
func update_world_time(year: int, season: String) -> void:
	if world_screen:
		world_screen.update_time(year, season)


## Update world realm display
func update_world_realm(realm_name: String) -> void:
	if world_screen:
		world_screen.update_realm(realm_name)


## Display floating damage
func display_damage(damage: int, position: Vector2, is_critical: bool = false) -> void:
	if battle_hud:
		battle_hud.display_damage(damage, position, is_critical)


## Display floating healing
func display_healing(amount: int, position: Vector2) -> void:
	if battle_hud:
		battle_hud.display_healing(amount, position)


## Show notification
func show_notification(message: String, duration: float = 3.0) -> void:
	var notification = Label.new()
	notification.text = message
	notification.add_theme_font_size_override("font_size", 16)
	notification.modulate = Color.YELLOW
	add_child(notification)

	await get_tree().create_timer(duration).timeout
	notification.queue_free()


## Get current screen type
func get_current_screen() -> String:
	return current_screen


## Is battle active
func is_battle_active() -> bool:
	return battle_active


## Handle game started
func _on_game_started() -> void:
	# Initialize world and display
	if world_screen:
		world_screen.visible = true
	if menu_manager:
		menu_manager.hide_all_menus()


## Handle game resumed
func _on_game_resumed() -> void:
	if world_screen:
		world_screen.visible = true


## Handle settings changed
func _on_settings_changed(setting: String, value: String) -> void:
	match setting:
		"volume":
			# Update audio volume
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), float(value) - 80)
		"difficulty":
			# Update game difficulty
			pass


## Handle battle action
func _on_battle_action(action_type: String, target: int) -> void:
	# Forward to battle system
	if battle_system:
		battle_system.handle_player_action(action_type, target)


## Handle battle ended
func _on_battle_ended(victory: bool, rewards: Dictionary) -> void:
	if victory:
		show_notification("Victory! Gained %d gold and %d XP" % [rewards.get("gold", 0), rewards.get("xp", 0)])
	else:
		show_notification("Defeat! Returning to town...")

	await get_tree().create_timer(2.0).timeout
	hide_battle()


## Handle heir moved
func _on_heir_moved(new_position: Vector2i) -> void:
	# Check for encounters or events at new location
	if world_system:
		var encounter = world_system.check_encounter_at(new_position)
		if encounter:
			show_notification("Encountered: %s!" % encounter["type"])


## Handle settlement entered
func _on_settlement_entered(settlement_name: String) -> void:
	show_notification("Entered: %s" % settlement_name)


## Toggle pause menu
func toggle_pause() -> void:
	if menu_manager:
		menu_manager.toggle_pause_menu()


## Update heir stats display
func update_heir_stats(heir_name: String, heir_data: Dictionary) -> void:
	if stats_screen and stats_screen.visible:
		stats_screen.update_heir_stats(heir_data)


## Set game systems references
func set_game_systems(battle_sys: Object, heir_sys: Object, world_sys: Object, time_sys: Object, gen_sys: Object) -> void:
	battle_system = battle_sys
	heir_system = heir_sys
	world_system = world_sys
	time_system = time_sys
	generation_system = gen_sys
