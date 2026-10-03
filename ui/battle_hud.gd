## Battle HUD: Displays battle information overlay during combat
##
## Shows HP bars, mana, status effects, turn order, ability cooldowns,
## and battle statistics

extends CanvasLayer

class_name BattleHUD


signal ability_selected(ability_index: int)
signal item_used(item_index: int)
signal flee_attempted()


# UI components
@onready var player_hp_bar = $VBoxContainer/PlayerStatus/HPBar
@onready var player_mp_bar = $VBoxContainer/PlayerStatus/MPBar
@onready var enemy_hp_bar = $VBoxContainer/EnemyStatus/HPBar
@onready var turn_indicator = $VBoxContainer/TurnIndicator
@onready var status_effects_container = $VBoxContainer/StatusEffects
@onready var ability_buttons = $VBoxContainer/AbilityPanel/GridContainer

# Data references
var current_battle: Dictionary = {}
var player_data: Dictionary = {}
var enemy_data: Dictionary = {}

# UI state
var selected_ability: int = -1
var battle_active: bool = false


func _ready() -> void:
	_setup_ui()
	visibility_changed.connect(_on_visibility_changed)


func _setup_ui() -> void:
	# Create HP bars
	player_hp_bar = ProgressBar.new()
	player_hp_bar.min_value = 0
	player_hp_bar.max_value = 100
	player_hp_bar.modulate = Color.GREEN
	add_child(player_hp_bar)

	enemy_hp_bar = ProgressBar.new()
	enemy_hp_bar.min_value = 0
	enemy_hp_bar.max_value = 100
	enemy_hp_bar.modulate = Color.RED
	add_child(enemy_hp_bar)

	# Create turn indicator
	turn_indicator = Label.new()
	turn_indicator.text = "Player Turn"
	add_child(turn_indicator)


## Initialize battle HUD with battle data
func initialize_battle(player: Dictionary, enemies: Array) -> void:
	player_data = player
	enemy_data = {"enemies": enemies, "current_enemy": 0}
	battle_active = true

	update_display()


## Update all HUD elements
func update_display() -> void:
	if not battle_active:
		return

	_update_hp_bars()
	_update_status_effects()
	_update_turn_indicator()
	_update_ability_buttons()


## Update HP bar displays
func _update_hp_bars() -> void:
	if player_data.is_empty():
		return

	var player_hp = player_data.get("hp", 0)
	var player_max_hp = player_data.get("max_hp", 100)
	player_hp_bar.max_value = float(player_max_hp)
	player_hp_bar.value = float(player_hp)

	var current_enemy = enemy_data["enemies"][enemy_data["current_enemy"]]
	var enemy_hp = current_enemy.get("hp", 0)
	var enemy_max_hp = current_enemy.get("max_hp", 100)
	enemy_hp_bar.max_value = float(enemy_max_hp)
	enemy_hp_bar.value = float(enemy_hp)


## Update status effects display
func _update_status_effects() -> void:
	status_effects_container.clear()

	var effects = player_data.get("status_effects", [])
	for effect in effects:
		var effect_label = Label.new()
		effect_label.text = effect
		effect_label.modulate = Color.YELLOW
		status_effects_container.add_child(effect_label)


## Update turn indicator
func _update_turn_indicator() -> void:
	var turn = current_battle.get("current_turn", "player")
	var turn_count = current_battle.get("turn_count", 1)

	if turn == "player":
		turn_indicator.text = "Player Turn #%d" % turn_count
		turn_indicator.modulate = Color.GREEN
	else:
		turn_indicator.text = "Enemy Turn #%d" % turn_count
		turn_indicator.modulate = Color.RED


## Update ability buttons
func _update_ability_buttons() -> void:
	ability_buttons.clear()

	var abilities = player_data.get("abilities", [])
	for i in range(abilities.size()):
		var ability = abilities[i]
		var button = Button.new()
		button.text = "%s (CD: %d)" % [ability["name"], ability.get("cooldown", 0)]
		button.pressed.connect(_on_ability_button_pressed.bind(i))
		ability_buttons.add_child(button)


## Handle ability selection
func _on_ability_button_pressed(ability_index: int) -> void:
	selected_ability = ability_index
	ability_selected.emit(ability_index)


## Get selected ability
func get_selected_ability() -> int:
	return selected_ability


## Set turn to player
func set_player_turn() -> void:
	current_battle["current_turn"] = "player"
	update_display()


## Set turn to enemy
func set_enemy_turn() -> void:
	current_battle["current_turn"] = "enemy"
	update_display()


## Display damage number (floating text)
func display_damage(damage: int, position: Vector2, is_critical: bool = false) -> void:
	var damage_label = Label.new()
	damage_label.text = str(damage)
	damage_label.modulate = Color.RED if is_critical else Color.WHITE
	damage_label.global_position = position
	add_child(damage_label)

	# Animate fade out
	var tween = create_tween()
	tween.tween_property(damage_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(damage_label.queue_free)


## Display healing number (floating text)
func display_healing(amount: int, position: Vector2) -> void:
	var heal_label = Label.new()
	heal_label.text = "+" + str(amount)
	heal_label.modulate = Color.GREEN
	heal_label.global_position = position
	add_child(heal_label)

	var tween = create_tween()
	tween.tween_property(heal_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(heal_label.queue_free)


## Clear battle display
func clear_battle() -> void:
	battle_active = false
	player_data.clear()
	enemy_data.clear()


## _on_visibility_changed: Update when visibility changes
func _on_visibility_changed() -> void:
	if visible:
		update_display()
