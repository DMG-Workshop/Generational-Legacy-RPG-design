## Main game controller: orchestrates all scenes and game state
##
## Manages transitions between menus, world, battle, and generation sequences.
## Persists across scene changes and handles save/load.

extends Node

class_name MainGame


## Game state (persistent across scenes)
var current_lineage: Lineage
var current_world: WorldManager
var current_generation_manager: GenerationManager
var dialogue_system: DialogueSystem
var current_save_slot: int = 0

## UI layers
var screen_manager: ScreenManager
var current_screen: Control
var transition_animator: ScreenTransitionAnimator

## Game modes
enum GameMode {
	MAIN_MENU,
	WORLD_EXPLORATION,
	BATTLE,
	CHARACTER_MENU,
	GENERATION_TRANSITION,
	PAUSE_MENU,
	LOAD_SCREEN,
	YEAR_ACTION,
	EVENT_POPUP,
	DIALOGUE,
	QUEST_DETAIL,
	CONSEQUENCE_NOTIFICATION
}

var current_mode: GameMode = GameMode.MAIN_MENU
var paused: bool = false


func _ready() -> void:
	# Initialize game systems
	current_lineage = Lineage.new(42)  # seeded RNG for reproducibility
	current_world = WorldManager.new()
	current_generation_manager = GenerationManager.new(current_lineage, current_world)
	dialogue_system = DialogueSystem.new()

	# Setup screen manager and animator
	screen_manager = ScreenManager.new()
	add_child(screen_manager)

	transition_animator = ScreenTransitionAnimator.new()
	add_child(transition_animator)

	# Start at main menu
	show_main_menu()


## Transition to a new screen
func show_screen(screen_type: String) -> void:
	if current_screen:
		screen_manager.remove_child(current_screen)
		current_screen.queue_free()

	match screen_type:
		"main_menu":
			current_screen = MainMenuScreen.new()
			current_mode = GameMode.MAIN_MENU

		"world":
			current_screen = WorldScreen.new(current_generation_manager, current_world)
			current_mode = GameMode.WORLD_EXPLORATION

		"battle":
			# Battle should be set via enter_battle()
			current_mode = GameMode.BATTLE
			return

		"character":
			current_screen = CharacterMenuEnhanced.new(
				current_generation_manager.current_heir,
				current_lineage,
				current_generation_manager.npc_system
			)
			current_mode = GameMode.CHARACTER_MENU

		"generation_transition":
			current_screen = GenerationTransitionScreen.new(current_generation_manager)
			current_mode = GameMode.GENERATION_TRANSITION

		"pause":
			current_screen = PauseMenuScreen.new()
			current_mode = GameMode.PAUSE_MENU

		"load":
			current_screen = LoadGameScreen.new()
			current_mode = GameMode.LOAD_SCREEN

		"year_action":
			current_screen = YearActionScreen.new(current_generation_manager)
			current_mode = GameMode.YEAR_ACTION

		"event_popup":
			current_screen = EventPopupScreen.new()
			current_mode = GameMode.EVENT_POPUP

		"dialogue":
			# Dialogue screen needs tree_key set via show_dialogue()
			current_mode = GameMode.DIALOGUE

		"quest_detail":
			# Quest detail screen needs quest_data set via show_quest_detail()
			current_mode = GameMode.QUEST_DETAIL

	if current_screen:
		screen_manager.add_child(current_screen)
		# Fade in the new screen
		transition_animator.fade_in(current_screen)


func show_main_menu() -> void:
	show_screen("main_menu")


func start_new_game() -> void:
	# Create founder
	var founder = current_lineage.create_founder("Theron", "warrior", "merchant")
	current_generation_manager.begin_generation(founder)

	# Start in world
	show_screen("world")


func enter_battle(enemies: Array[Heir]) -> void:
	# Create battle instance with current party vs enemies
	var battle = Battle.new()

	# Create party combatants from current generation
	var party_combatants: Array[Battle.Combatant] = []
	var current_heir = current_generation_manager.current_heir
	if current_heir:
		var party_member = Battle.Combatant.new()
		party_member.name = current_heir.name
		party_member.class_id = current_heir.class_id
		party_member.job_id = current_heir.job_id
		party_member.faction = "party"
		party_member.hp = current_heir.constitution * 10
		party_member.max_hp = party_member.hp
		party_member.mp = current_heir.intelligence * 5
		party_member.max_mp = party_member.mp
		party_member.stats["strength"] = current_heir.strength
		party_member.stats["dexterity"] = current_heir.dexterity
		party_member.stats["constitution"] = current_heir.constitution
		party_member.stats["intelligence"] = current_heir.intelligence
		party_member.stats["wisdom"] = current_heir.wisdom
		party_member.stats["charisma"] = current_heir.charisma
		party_member.traits = current_heir.traits
		party_combatants.append(party_member)

	# Create enemy combatants from provided enemies
	var enemy_combatants: Array[Battle.Combatant] = []
	for enemy_heir in enemies:
		var enemy = Battle.Combatant.new()
		enemy.name = enemy_heir.name
		enemy.class_id = enemy_heir.class_id
		enemy.job_id = enemy_heir.job_id
		enemy.faction = "enemy"
		enemy.hp = enemy_heir.constitution * 10
		enemy.max_hp = enemy.hp
		enemy.mp = enemy_heir.intelligence * 5
		enemy.max_mp = enemy.mp
		enemy.stats["strength"] = enemy_heir.strength
		enemy.stats["dexterity"] = enemy_heir.dexterity
		enemy.stats["constitution"] = enemy_heir.constitution
		enemy.stats["intelligence"] = enemy_heir.intelligence
		enemy.stats["wisdom"] = enemy_heir.wisdom
		enemy.stats["charisma"] = enemy_heir.charisma
		enemy.traits = enemy_heir.traits
		enemy_combatants.append(enemy)

	# Start battle
	battle.start_battle(party_combatants, enemy_combatants)

	# Create and show battle screen
	if current_screen:
		screen_manager.remove_child(current_screen)
		current_screen.queue_free()

	current_screen = BattleScreen.new(battle)
	current_mode = GameMode.BATTLE
	screen_manager.add_child(current_screen)
	transition_animator.fade_in(current_screen)


func exit_to_world() -> void:
	show_screen("world")


func toggle_pause() -> void:
	if paused:
		show_screen("world")
	else:
		show_screen("pause")

	paused = !paused


func show_dialogue(tree_key: String) -> void:
	if current_screen:
		screen_manager.remove_child(current_screen)
		current_screen.queue_free()

	current_screen = DialogueTreeScreen.new(dialogue_system, tree_key, current_generation_manager.current_heir)
	current_mode = GameMode.DIALOGUE
	screen_manager.add_child(current_screen)


func show_quest_detail(quest_data: Dictionary) -> void:
	if current_screen:
		screen_manager.remove_child(current_screen)
		current_screen.queue_free()

	current_screen = QuestDetailScreen.new(quest_data, current_generation_manager.current_heir)
	current_mode = GameMode.QUEST_DETAIL
	screen_manager.add_child(current_screen)


func show_consequence_notification(consequences: Dictionary) -> void:
	if current_screen:
		screen_manager.remove_child(current_screen)
		current_screen.queue_free()

	current_screen = ConsequenceNotificationScreen.new(consequences, current_generation_manager.current_heir)
	current_mode = GameMode.CONSEQUENCE_NOTIFICATION
	screen_manager.add_child(current_screen)


## Save game to slot
func save_game(slot: int) -> bool:
	current_save_slot = slot

	# Serialize state to JSON
	var save_data = {
		"generation": current_lineage.generation_count,
		"current_heir": current_generation_manager.current_heir.name,
		"current_age": current_generation_manager.current_age,
		"current_wealth": current_generation_manager.current_wealth,
		"timestamp": Time.get_ticks_msec()
	}

	var save_file = "user://saves/slot_%d.save" % slot
	var file = FileAccess.open(save_file, FileAccess.WRITE)
	if file == null:
		return false

	file.store_var(save_data)
	return true


## Load game from slot
func load_game(slot: int) -> bool:
	var save_file = "user://saves/slot_%d.save" % slot
	if not FileAccess.file_exists(save_file):
		return false

	var file = FileAccess.open(save_file, FileAccess.READ)
	var save_data = file.get_var()

	# Restore state
	current_save_slot = slot
	# TODO: Restore heir and game state from save_data

	show_screen("world")
	return true


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if current_mode == GameMode.WORLD_EXPLORATION:
					toggle_pause()

			KEY_I:
				if current_mode == GameMode.WORLD_EXPLORATION:
					show_screen("character")

			KEY_M:
				if current_mode == GameMode.WORLD_EXPLORATION:
					# TODO: Open map
					pass
