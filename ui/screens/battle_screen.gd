## Battle screen: turn-based combat UI
##
## Displays party and enemies, turn order, HP bars, ability buttons
## Executes combat actions and shows damage/effects

extends Control

class_name BattleScreen


var battle: Battle
var turn_order: Array[Battle.Combatant] = []
var current_turn_index: int = 0


func _ready() -> void:
	# Setup background
	var bg = ColorRect.new()
	bg.color = Color.BLACK
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Create battle layout
	var hbox = HBoxContainer.new()
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	add_child(hbox)

	# Party side (left)
	var party_panel = PanelContainer.new()
	party_panel.custom_minimum_size = Vector2(300, 600)
	hbox.add_child(party_panel)

	var party_vbox = VBoxContainer.new()
	party_panel.add_child(party_vbox)

	var party_label = Label.new()
	party_label.text = "Party"
	party_label.add_theme_font_size_override("font_size", 20)
	party_vbox.add_child(party_label)

	# Create party member displays (placeholder)
	for i in range(3):
		var member_panel = _create_combatant_display("Member %d" % i, 100, 100)
		party_vbox.add_child(member_panel)

	# Center - Turn order and log
	var center_panel = VBoxContainer.new()
	hbox.add_child(center_panel)
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var turn_label = Label.new()
	turn_label.text = "Turn Order"
	turn_label.add_theme_font_size_override("font_size", 20)
	center_panel.add_child(turn_label)

	var turn_order_display = VBoxContainer.new()
	turn_order_display.custom_minimum_size = Vector2(200, 150)
	center_panel.add_child(turn_order_display)

	# Placeholder for turn order
	for i in range(5):
		var order_item = Label.new()
		order_item.text = "Combatant %d" % i
		turn_order_display.add_child(order_item)

	# Battle log
	var log_label = Label.new()
	log_label.text = "Battle Log"
	log_label.add_theme_font_size_override("font_size", 16)
	center_panel.add_child(log_label)

	var log_display = TextEdit.new()
	log_display.custom_minimum_size = Vector2(200, 300)
	log_display.editable = false
	center_panel.add_child(log_display)

	# Enemy side (right)
	var enemy_panel = PanelContainer.new()
	enemy_panel.custom_minimum_size = Vector2(300, 600)
	hbox.add_child(enemy_panel)

	var enemy_vbox = VBoxContainer.new()
	enemy_panel.add_child(enemy_vbox)

	var enemy_label = Label.new()
	enemy_label.text = "Enemies"
	enemy_label.add_theme_font_size_override("font_size", 20)
	enemy_vbox.add_child(enemy_label)

	# Create enemy displays (placeholder)
	for i in range(3):
		var enemy_display = _create_combatant_display("Enemy %d" % i, 80, 80)
		enemy_vbox.add_child(enemy_display)

	# Action buttons at bottom
	var action_bar = HBoxContainer.new()
	action_bar.anchor_left = 0.0
	action_bar.anchor_right = 1.0
	action_bar.anchor_top = 1.0
	action_bar.anchor_bottom = 1.0
	action_bar.offset_top = -60
	action_bar.offset_left = 10
	action_bar.offset_right = -10
	add_child(action_bar)

	var attack_btn = Button.new()
	attack_btn.text = "Attack"
	attack_btn.pressed.connect(_on_attack)
	action_bar.add_child(attack_btn)

	var defend_btn = Button.new()
	defend_btn.text = "Defend"
	defend_btn.pressed.connect(_on_defend)
	action_bar.add_child(defend_btn)

	var spell_btn = Button.new()
	spell_btn.text = "Spell"
	spell_btn.pressed.connect(_on_spell)
	action_bar.add_child(spell_btn)

	var item_btn = Button.new()
	item_btn.text = "Item"
	item_btn.pressed.connect(_on_item)
	action_bar.add_child(item_btn)

	var flee_btn = Button.new()
	flee_btn.text = "Flee"
	flee_btn.pressed.connect(_on_flee)
	action_bar.add_child(flee_btn)


func _create_combatant_display(name: String, hp: int, max_hp: int) -> PanelContainer:
	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	var name_label = Label.new()
	name_label.text = name
	vbox.add_child(name_label)

	var hp_label = Label.new()
	hp_label.text = "%d / %d HP" % [hp, max_hp]
	vbox.add_child(hp_label)

	var hp_bar = ProgressBar.new()
	hp_bar.value = float(hp) / float(max_hp) * 100
	hp_bar.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(hp_bar)

	return panel


func _on_attack() -> void:
	print("Attack action selected")


func _on_defend() -> void:
	print("Defend action selected")


func _on_spell() -> void:
	print("Spell action selected")


func _on_item() -> void:
	print("Item action selected")


func _on_flee() -> void:
	print("Flee action selected")
	# Return to world
	var main_game = get_tree().root.get_child(0)
	main_game.exit_to_world()
