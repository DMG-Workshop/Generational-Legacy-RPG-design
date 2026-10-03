## Enhanced battle screen: integrated turn-based combat UI
##
## Fully connected to Battle system with live stats, turn order, actions

extends Control

class_name BattleScreen


var battle: Battle
var party_displays: Array[Control] = []
var enemy_displays: Array[Control] = []
var turn_order_display: VBoxContainer
var action_buttons: Array[Button] = []
var battle_log: TextEdit
var selected_action: String = ""
var selected_target: Battle.Combatant = null
var current_actor: Battle.Combatant = null
var battle_log_label: Label
var info_label: Label
var target_selection_active: bool = false


func _init(p_battle: Battle) -> void:
	battle = p_battle


func _ready() -> void:
	# Setup background
	var bg = ColorRect.new()
	bg.color = Color.BLACK
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Main layout
	var main_hbox = HBoxContainer.new()
	main_hbox.anchor_right = 1.0
	main_hbox.anchor_bottom = 0.95
	add_child(main_hbox)

	# === LEFT SIDE: PARTY ===
	var party_panel = PanelContainer.new()
	party_panel.custom_minimum_size = Vector2(350, 0)
	main_hbox.add_child(party_panel)

	var party_vbox = VBoxContainer.new()
	party_panel.add_child(party_vbox)
	party_vbox.add_theme_constant_override("separation", 10)

	var party_title = Label.new()
	party_title.text = "Party"
	party_title.add_theme_font_size_override("font_size", 18)
	party_title.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	party_vbox.add_child(party_title)

	# Display each party member
	for combatant in battle.state.party:
		var display = _create_combatant_display(combatant, true)
		party_displays.append(display)
		party_vbox.add_child(display)

	# === CENTER: TURN ORDER & LOG ===
	var center_panel = VBoxContainer.new()
	main_hbox.add_child(center_panel)
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.add_theme_constant_override("separation", 10)

	# Turn Order section
	var turn_title = Label.new()
	turn_title.text = "Turn Order"
	turn_title.add_theme_font_size_override("font_size", 16)
	center_panel.add_child(turn_title)

	turn_order_display = VBoxContainer.new()
	turn_order_display.custom_minimum_size = Vector2(0, 120)
	center_panel.add_child(turn_order_display)

	# Battle Log section
	battle_log_label = Label.new()
	battle_log_label.text = "Battle Log"
	battle_log_label.add_theme_font_size_override("font_size", 16)
	center_panel.add_child(battle_log_label)

	battle_log = TextEdit.new()
	battle_log.custom_minimum_size = Vector2(0, 200)
	battle_log.editable = false
	battle_log.text = "Battle started!\n"
	center_panel.add_child(battle_log)

	# Current turn info
	var turn_info = Label.new()
	turn_info.name = "turn_info"
	turn_info.text = "Waiting for first action..."
	turn_info.add_theme_font_size_override("font_size", 12)
	center_panel.add_child(turn_info)

	# === RIGHT SIDE: ENEMIES ===
	var enemy_panel = PanelContainer.new()
	enemy_panel.custom_minimum_size = Vector2(350, 0)
	main_hbox.add_child(enemy_panel)

	var enemy_vbox = VBoxContainer.new()
	enemy_panel.add_child(enemy_vbox)
	enemy_vbox.add_theme_constant_override("separation", 10)

	var enemy_title = Label.new()
	enemy_title.text = "Enemies"
	enemy_title.add_theme_font_size_override("font_size", 18)
	enemy_title.add_theme_color_override("font_color", Color.LIGHT_CORAL)
	enemy_vbox.add_child(enemy_title)

	# Display each enemy
	for combatant in battle.state.enemies:
		var display = _create_combatant_display(combatant, false)
		enemy_displays.append(display)
		enemy_vbox.add_child(display)

	# === BOTTOM: ACTION BAR ===
	var action_bar = PanelContainer.new()
	action_bar.anchor_left = 0.0
	action_bar.anchor_right = 1.0
	action_bar.anchor_top = 0.95
	action_bar.anchor_bottom = 1.0
	add_child(action_bar)

	var action_hbox = HBoxContainer.new()
	action_bar.add_child(action_hbox)
	action_hbox.add_theme_constant_override("separation", 5)

	# Action buttons
	var attack_btn = _create_action_button("Attack", "attack")
	action_hbox.add_child(attack_btn)

	var defend_btn = _create_action_button("Defend", "defend")
	action_hbox.add_child(defend_btn)

	var spell_btn = _create_action_button("Spell", "cast_spell")
	action_hbox.add_child(spell_btn)

	var item_btn = _create_action_button("Item", "use_item")
	action_hbox.add_child(item_btn)

	var flee_btn = _create_action_button("Flee", "flee")
	action_hbox.add_child(flee_btn)

	# Spacer
	action_hbox.add_child(Control.new())

	# Info label
	info_label = Label.new()
	info_label.text = "Select an action to begin"
	action_hbox.add_child(info_label)

	_update_display()
	_process_next_turn()


func _create_combatant_display(combatant: Battle.Combatant, is_player: bool) -> PanelContainer:
	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	vbox.add_theme_constant_override("separation", 5)

	# Name and status
	var name_label = Label.new()
	name_label.text = "%s (%s)" % [combatant.name, combatant.class_id.to_upper()]
	name_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(name_label)

	# HP bar
	var hp_container = HBoxContainer.new()
	vbox.add_child(hp_container)

	var hp_label = Label.new()
	hp_label.text = "HP: %d / %d" % [combatant.hp, combatant.max_hp]
	hp_label.custom_minimum_size = Vector2(100, 0)
	hp_container.add_child(hp_label)

	var hp_bar = ProgressBar.new()
	hp_bar.value = float(combatant.hp) / float(combatant.max_hp) * 100.0
	hp_bar.custom_minimum_size = Vector2(100, 20)
	hp_bar.modulate.color = Color.GREEN if combatant.is_alive else Color.RED
	hp_bar.name = "hp_bar_%s" % combatant.name
	hp_container.add_child(hp_bar)

	# MP bar (if available)
	if combatant.max_mp > 0:
		var mp_container = HBoxContainer.new()
		vbox.add_child(mp_container)

		var mp_label = Label.new()
		mp_label.text = "MP: %d / %d" % [combatant.mp, combatant.max_mp]
		mp_label.custom_minimum_size = Vector2(100, 0)
		mp_container.add_child(mp_label)

		var mp_bar = ProgressBar.new()
		mp_bar.value = float(combatant.mp) / float(combatant.max_mp) * 100.0
		mp_bar.custom_minimum_size = Vector2(100, 20)
		mp_bar.modulate.color = Color.CYAN
		mp_bar.name = "mp_bar_%s" % combatant.name
		mp_container.add_child(mp_bar)

	# Buffs/Debuffs display
	if combatant.buffs.size() > 0 or combatant.debuffs.size() > 0:
		var status_label = Label.new()
		var status_text = "Status: "
		for buff_name in combatant.buffs:
			status_text += buff_name + " "
		for debuff_name in combatant.debuffs:
			status_text += debuff_name + " "
		status_label.text = status_text
		status_label.add_theme_font_size_override("font_size", 10)
		status_label.add_theme_color_override("font_color", Color.YELLOW)
		vbox.add_child(status_label)

	return panel


func _create_action_button(text: String, action: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(80, 30)
	btn.pressed.connect(_on_action_selected.bind(action))
	action_buttons.append(btn)
	return btn


func _on_action_selected(action: String) -> void:
	if not current_actor or not current_actor.is_alive:
		return

	selected_action = action
	_log_message("Selected action: %s" % action)

	match action:
		"flee":
			_on_flee()
		"attack", "cast_spell", "use_item":
			_show_target_selection(action)
		"defend":
			_execute_action(action, null)


func _show_target_selection(action: String) -> void:
	_log_message("Select target for: %s" % action)
	target_selection_active = true
	info_label.text = "Click on target for %s" % action

	var valid_targets = battle.get_valid_targets(current_actor, action)
	if valid_targets.is_empty():
		_log_message("No valid targets available!")
		target_selection_active = false
		_process_next_turn()
		return

	for target in valid_targets:
		# Find enemy display and connect click
		for i in range(enemy_displays.size()):
			if i < battle.state.enemies.size() and battle.state.enemies[i] == target:
				var display = enemy_displays[i]
				if not display.is_connected("gui_input", Callable(self, "_on_target_selected")):
					display.gui_input.connect(_on_target_selected.bind(target))
				display.modulate.color = Color.YELLOW


func _on_target_selected(event: InputEvent, target: Battle.Combatant) -> void:
	if event is InputEventMouseButton and event.pressed and target_selection_active:
		selected_target = target
		target_selection_active = false

		# Reset enemy highlight
		for display in enemy_displays:
			display.modulate.color = Color.WHITE

		_execute_action(selected_action, target)


func _execute_action(action: String, target: Battle.Combatant) -> void:
	if battle.state.battle_over:
		return

	if not current_actor or not current_actor.is_alive:
		_log_message("Cannot act while dead")
		_process_next_turn()
		return

	var result = battle.execute_turn(current_actor, action, target)

	if result.get("success", true):
		match action:
			"attack":
				if target:
					var damage = result.get("damage", 0)
					var is_crit = result.get("critical", false)
					_log_message("%s attacks %s for %d damage%s" % [
						current_actor.name,
						target.name,
						damage,
						" (CRITICAL!)" if is_crit else ""
					])
			"defend":
				_log_message("%s takes a defensive stance!" % current_actor.name)
			"cast_spell":
				_log_message("%s casts a spell!" % current_actor.name)
			"use_item":
				_log_message("%s uses an item!" % current_actor.name)

	_update_display()
	_check_battle_end()

	if not battle.state.battle_over:
		_process_next_turn()


func _on_flee() -> void:
	_log_message("Fled from battle!")
	var main_game = get_tree().root.get_child(0)
	main_game.exit_to_world()


func _process_next_turn() -> void:
	if battle.state.battle_over:
		return

	# Find next alive combatant in turn order
	for i in range(battle.state.turn_order.size()):
		var combatant = battle.state.turn_order[i]
		if combatant.is_alive:
			current_actor = combatant
			info_label.text = "%s's turn" % combatant.name

			if combatant.faction == "party":
				# Enable action buttons for player
				for btn in action_buttons:
					btn.disabled = false
			else:
				# AI turn for enemy
				for btn in action_buttons:
					btn.disabled = true
				await get_tree().create_timer(0.5).timeout
				_execute_enemy_turn(combatant)

			return

	# Should not reach here if battle logic is correct
	_log_message("Error: No alive combatant found!")


func _execute_enemy_turn(enemy: Battle.Combatant) -> void:
	var valid_actions = battle.get_valid_actions(enemy)
	if valid_actions.is_empty():
		_log_message("No valid actions for %s" % enemy.name)
		_process_next_turn()
		return

	var action = valid_actions[randi() % valid_actions.size()]
	var targets = battle.get_valid_targets(enemy, action)
	var target = targets[randi() % targets.size()] if not targets.is_empty() else null

	_execute_action(action, target)


func _update_display() -> void:
	# Update party displays
	for i in range(party_displays.size()):
		if i < battle.state.party.size():
			_update_combatant_display(party_displays[i], battle.state.party[i])

	# Update enemy displays
	for i in range(enemy_displays.size()):
		if i < battle.state.enemies.size():
			_update_combatant_display(enemy_displays[i], battle.state.enemies[i])

	# Update turn order
	_update_turn_order()


func _update_combatant_display(panel: PanelContainer, combatant: Battle.Combatant) -> void:
	# Find and update HP bar
	var hp_bar = panel.find_child("hp_bar_%s" % combatant.name)
	if hp_bar:
		hp_bar.value = float(combatant.hp) / float(combatant.max_hp) * 100.0
		hp_bar.modulate.color = Color.GREEN if combatant.is_alive else Color.RED

	# Find and update MP bar
	var mp_bar = panel.find_child("mp_bar_%s" % combatant.name)
	if mp_bar:
		mp_bar.value = float(combatant.mp) / float(combatant.max_mp) * 100.0


func _update_turn_order() -> void:
	# Clear old entries
	for child in turn_order_display.get_children():
		child.queue_free()

	# Show current turn order
	for i in range(min(5, battle.state.turn_order.size())):
		var combatant = battle.state.turn_order[i]
		var turn_label = Label.new()
		var turn_text = "%d. %s" % [i + 1, combatant.name]
		if combatant == current_actor:
			turn_text += " ← CURRENT"
		turn_label.text = turn_text
		turn_order_display.add_child(turn_label)


func _check_battle_end() -> void:
	if battle.state.battle_over:
		var result_text = "Victory!" if battle.state.player_won else "Defeat!"
		_log_message(result_text)

		# Disable action buttons
		for btn in action_buttons:
			btn.disabled = true


func _log_message(message: String) -> void:
	battle_log.text += "\n" + message
	# Auto-scroll to bottom
	battle_log.set_caret_line(battle_log.get_line_count() - 1)
