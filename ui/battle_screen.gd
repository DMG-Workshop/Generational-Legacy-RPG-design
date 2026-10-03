## Battle Screen: Main battle display showing combatants and actions
##
## Renders player and enemies with animations, handles turn display,
## and manages battle flow visualization

extends Control

class_name BattleScreen


signal battle_action_requested(action_type: String, target: int)
signal battle_ended(victory: bool, rewards: Dictionary)


# References
var battle_hud: BattleHUD
var battle_system: Object  # Reference to active battle system
var current_battle_data: Dictionary = {}

# Visual elements
var player_sprite: Sprite2D
var enemy_sprites: Array[Sprite2D] = []
var turn_label: Label
var log_panel: TextEdit

# Battle state
var is_player_turn: bool = false
var current_action: String = ""
var selected_enemy_index: int = 0


func _ready() -> void:
	_setup_battle_screen()


func _setup_battle_screen() -> void:
	# Create main container
	var main_container = VBoxContainer.new()
	main_container.anchor_left = 0.0
	main_container.anchor_top = 0.0
	main_container.anchor_right = 1.0
	main_container.anchor_bottom = 1.0
	add_child(main_container)

	# Create battle area (left side for player, right for enemies)
	var battle_area = HBoxContainer.new()
	battle_area.custom_minimum_size = Vector2(0, 400)
	main_container.add_child(battle_area)

	# Player side
	var player_container = VBoxContainer.new()
	player_container.custom_minimum_size = Vector2(200, 0)
	player_sprite = Sprite2D.new()
	player_sprite.modulate = Color.BLUE
	player_sprite.scale = Vector2(2, 2)
	player_container.add_child(player_sprite)
	battle_area.add_child(player_container)

	# Enemy side (multiple enemies)
	var enemy_container = VBoxContainer.new()
	enemy_container.custom_minimum_size = Vector2(200, 0)
	battle_area.add_child(enemy_container)

	# Turn label
	turn_label = Label.new()
	turn_label.text = "Player Turn"
	turn_label.add_theme_font_size_override("font_size", 24)
	main_container.add_child(turn_label)

	# Battle log
	log_panel = TextEdit.new()
	log_panel.readonly = true
	log_panel.custom_minimum_size = Vector2(0, 200)
	main_container.add_child(log_panel)

	# Action buttons
	var action_container = HBoxContainer.new()
	main_container.add_child(action_container)

	var attack_button = Button.new()
	attack_button.text = "Attack"
	attack_button.pressed.connect(_on_attack_pressed)
	action_container.add_child(attack_button)

	var defend_button = Button.new()
	defend_button.text = "Defend"
	defend_button.pressed.connect(_on_defend_pressed)
	action_container.add_child(defend_button)

	var flee_button = Button.new()
	flee_button.text = "Flee"
	flee_button.pressed.connect(_on_flee_pressed)
	action_container.add_child(flee_button)


## Initialize battle with combatants
func initialize_battle(player: Dictionary, enemies: Array, battle_system_ref: Object) -> void:
	battle_system = battle_system_ref
	current_battle_data = {
		"player": player,
		"enemies": enemies,
		"turn": 0,
		"current_actor": "player",
	}

	# Setup player sprite
	_update_player_display()

	# Setup enemy sprites
	_update_enemy_display()

	# Start battle log
	log_panel.text = "Battle started!\n"
	log_panel.text += "Player vs %d enemies\n" % enemies.size()

	# Start first turn
	start_player_turn()


## Update player display
func _update_player_display() -> void:
	var player = current_battle_data["player"]

	# Update sprite color based on class
	match player.get("class", "Warrior"):
		"Warrior":
			player_sprite.modulate = Color.RED
		"Mage":
			player_sprite.modulate = Color.BLUE
		"Rogue":
			player_sprite.modulate = Color.GREEN
		"Priest":
			player_sprite.modulate = Color.YELLOW

	# Create character label
	var label = Label.new()
	label.text = "%s (HP: %d/%d)" % [player["name"], player["hp"], player["max_hp"]]
	player_sprite.add_child(label)


## Update enemy display
func _update_enemy_display() -> void:
	var enemies = current_battle_data["enemies"]

	for i in range(enemies.size()):
		var enemy = enemies[i]
		var sprite = Sprite2D.new()
		sprite.modulate = Color.RED
		sprite.scale = Vector2(1.5, 1.5)

		var label = Label.new()
		label.text = "%s (HP: %d/%d)" % [enemy["name"], enemy["hp"], enemy["max_hp"]]
		sprite.add_child(label)

		enemy_sprites.append(sprite)


## Start player turn
func start_player_turn() -> void:
	is_player_turn = true
	turn_label.text = "Player Turn"
	turn_label.modulate = Color.GREEN
	log_panel.text += "\n>>> Player's turn\n"
	current_battle_data["current_actor"] = "player"


## Start enemy turn
func start_enemy_turn(enemy_index: int) -> void:
	is_player_turn = false
	var enemy = current_battle_data["enemies"][enemy_index]
	turn_label.text = "%s's Turn" % enemy["name"]
	turn_label.modulate = Color.RED
	log_panel.text += "\n>>> %s's turn\n" % enemy["name"]
	current_battle_data["current_actor"] = "enemy"


## Process action result
func process_action_result(action: Dictionary) -> void:
	var action_text = ""

	match action.get("type", ""):
		"attack":
			var damage = action.get("damage", 0)
			var target = action.get("target", 0)
			action_text = "%s attacks %s for %d damage!" % [action.get("actor", "Unknown"), current_battle_data["enemies"][target].get("name", "Enemy"), damage]

		"defend":
			action_text = "%s braces for impact!" % action.get("actor", "Unknown")

		"ability":
			action_text = "%s uses %s!" % [action.get("actor", "Unknown"), action.get("ability", "Unknown")]

		"item":
			action_text = "%s uses %s!" % [action.get("actor", "Unknown"), action.get("item", "Unknown")]

	log_panel.text += action_text + "\n"


## Victory condition
func display_victory(rewards: Dictionary) -> void:
	log_panel.text += "\n=== VICTORY ===\n"
	log_panel.text += "Gold: +%d\n" % rewards.get("gold", 0)
	log_panel.text += "XP: +%d\n" % rewards.get("xp", 0)

	turn_label.text = "Victory!"
	turn_label.modulate = Color.GREEN

	battle_ended.emit(true, rewards)


## Defeat condition
func display_defeat() -> void:
	log_panel.text += "\n=== DEFEAT ===\n"
	turn_label.text = "Defeated!"
	turn_label.modulate = Color.RED

	battle_ended.emit(false, {})


## Handle attack button
func _on_attack_pressed() -> void:
	if not is_player_turn:
		return

	current_action = "attack"
	log_panel.text += "You prepare to attack...\n"
	battle_action_requested.emit("attack", selected_enemy_index)


## Handle defend button
func _on_defend_pressed() -> void:
	if not is_player_turn:
		return

	current_action = "defend"
	log_panel.text += "You take a defensive stance...\n"
	battle_action_requested.emit("defend", 0)


## Handle flee button
func _on_flee_pressed() -> void:
	if not is_player_turn:
		return

	log_panel.text += "You attempt to flee...\n"
	battle_action_requested.emit("flee", 0)


## Update HP display
func update_hp(actor: String, target_index: int, new_hp: int, max_hp: int) -> void:
	if actor == "player":
		var label = player_sprite.get_child_count() > 0 ? player_sprite.get_child(0) : null
		if label:
			label.text = "%s (HP: %d/%d)" % [current_battle_data["player"]["name"], new_hp, max_hp]
	else:
		if target_index < enemy_sprites.size() and enemy_sprites[target_index].get_child_count() > 0:
			var label = enemy_sprites[target_index].get_child(0)
			label.text = "%s (HP: %d/%d)" % [current_battle_data["enemies"][target_index]["name"], new_hp, max_hp]


## Get current battle state
func get_battle_state() -> Dictionary:
	return current_battle_data.duplicate(true)


## Clear battle display
func clear_battle() -> void:
	current_battle_data.clear()
	player_sprite.queue_free()
	for sprite in enemy_sprites:
		sprite.queue_free()
	enemy_sprites.clear()
