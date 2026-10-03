## Enhanced Battle Screen UI: comprehensive combat display with real-time status
##
## Displays active battle state, enemy information, predicted loot, and player status
## during combat. Features animated health bars, status effects, threat assessment,
## and detailed enemy information panels.

extends Control

class_name BattleScreen


# Signals
signal action_selected(action: String, target: Battle.Combatant)
signal battle_finished(player_won: bool)

# Battle data
var battle: Battle
var current_actor: Battle.Combatant = null
var selected_enemy: Battle.Combatant = null
var target_selection_active: bool = false
var selected_action: String = ""

# UI component references
var enemy_displays: Array[Control] = []
var party_displays: Array[Control] = []
var enemy_detail_panel: PanelContainer
var loot_preview_panel: PanelContainer
var turn_order_display: VBoxContainer
var battle_log: TextEdit
var action_buttons: Array[Button] = []
var info_label: Label
var round_label: Label
var difficulty_label: Label
var threat_label: Label

# Status effect icons and tooltips
var status_effect_colors: Dictionary = {
	"poisoned": Color.PURPLE,
	"burning": Color.RED,
	"frozen": Color.LIGHT_BLUE,
	"stunned": Color.YELLOW,
	"weakened": Color.GRAY,
	"blessed": Color.LIGHT_GREEN,
	"cursed": Color.BLACK,
	"bleeding": Color.DARK_RED,
	"hasted": Color.CYAN,
	"slowed": Color.SLATE_GRAY,
}

var status_effect_descriptions: Dictionary = {
	"poisoned": "Takes damage each turn",
	"burning": "Fire damage and reduced accuracy",
	"frozen": "Reduced speed, chance to skip turn",
	"stunned": "Skips next turn",
	"weakened": "Reduced damage output",
	"blessed": "Increased damage and critical chance",
	"cursed": "Reduced all stats",
	"bleeding": "Takes damage each turn, stacks",
	"hasted": "Increased speed and accuracy",
	"slowed": "Reduced speed, longer turn delay",
}


func _init(p_battle: Battle) -> void:
	battle = p_battle


func _ready() -> void:
	# Setup background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15, 1.0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Main container with scrolling
	var main_vbox = VBoxContainer.new()
	main_vbox.anchor_right = 1.0
	main_vbox.anchor_bottom = 0.92
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)

	# Header section
	_create_header(main_vbox)

	# Content area with HSplit
	var content_hsplit = HSplitContainer.new()
	content_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hsplit.split_offset = 350
	main_vbox.add_child(content_hsplit)

	# Left side: Parties display
	var left_panel = _create_parties_panel()
	content_hsplit.add_child(left_panel)

	# Center: Turn order and battle log
	var center_vbox = VBoxContainer.new()
	center_vbox.add_theme_constant_override("separation", 8)
	content_hsplit.add_child(center_vbox)

	var turn_order_label = Label.new()
	turn_order_label.text = "TURN ORDER"
	turn_order_label.add_theme_font_size_override("font_size", 14)
	turn_order_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	center_vbox.add_child(turn_order_label)

	turn_order_display = VBoxContainer.new()
	turn_order_display.custom_minimum_size = Vector2(0, 120)
	center_vbox.add_child(turn_order_display)

	var battle_log_label = Label.new()
	battle_log_label.text = "BATTLE LOG"
	battle_log_label.add_theme_font_size_override("font_size", 14)
	battle_log_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	center_vbox.add_child(battle_log_label)

	battle_log = TextEdit.new()
	battle_log.custom_minimum_size = Vector2(0, 150)
	battle_log.editable = false
	battle_log.text = "=== Battle Started ===\n"
	center_vbox.add_child(battle_log)

	# Right side: Enemy details and loot
	var right_vbox = VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(380, 0)
	right_vbox.add_theme_constant_override("separation", 8)
	content_hsplit.add_child(right_vbox)

	enemy_detail_panel = _create_enemy_detail_panel()
	right_vbox.add_child(enemy_detail_panel)

	loot_preview_panel = _create_loot_preview_panel()
	right_vbox.add_child(loot_preview_panel)

	# Bottom action bar
	var action_bar = _create_action_bar()
	add_child(action_bar)

	# Initial display update
	_update_all_displays()
	_process_next_turn()


func _create_header(parent: VBoxContainer) -> void:
	var header_panel = PanelContainer.new()
	header_panel.custom_minimum_size = Vector2(0, 70)

	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 20)
	header_panel.add_child(header_hbox)

	# Title
	var title_label = Label.new()
	title_label.text = "⚔ BATTLE"
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color.GOLD)
	header_hbox.add_child(title_label)

	# Round counter
	round_label = Label.new()
	round_label.text = "Round: 1"
	round_label.add_theme_font_size_override("font_size", 14)
	header_hbox.add_child(round_label)

	# Difficulty indicator
	difficulty_label = Label.new()
	difficulty_label.text = "Difficulty: NORMAL"
	difficulty_label.add_theme_font_size_override("font_size", 14)
	difficulty_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	header_hbox.add_child(difficulty_label)

	# Spacer
	header_hbox.add_child(Control.new())

	# Info label
	info_label = Label.new()
	info_label.text = "Select an action..."
	info_label.add_theme_font_size_override("font_size", 12)
	header_hbox.add_child(info_label)

	parent.add_child(header_panel)


func _create_parties_panel() -> Control:
	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 12)

	# Party section
	var party_title = Label.new()
	party_title.text = "▼ YOUR PARTY"
	party_title.add_theme_font_size_override("font_size", 14)
	party_title.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	left_vbox.add_child(party_title)

	for combatant in battle.state.party:
		var display = _create_party_member_display(combatant)
		party_displays.append(display)
		left_vbox.add_child(display)

	left_vbox.add_child(HSeparator.new())

	# Enemy section
	var enemy_title = Label.new()
	enemy_title.text = "▼ ENEMIES"
	enemy_title.add_theme_font_size_override("font_size", 14)
	enemy_title.add_theme_color_override("font_color", Color.LIGHT_CORAL)
	left_vbox.add_child(enemy_title)

	for combatant in battle.state.enemies:
		var display = _create_enemy_display(combatant)
		enemy_displays.append(display)
		left_vbox.add_child(display)

	return left_vbox


func _create_party_member_display(combatant: Battle.Combatant) -> PanelContainer:
	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	vbox.add_theme_constant_override("separation", 4)

	# Name and status
	var name_hbox = HBoxContainer.new()
	vbox.add_child(name_hbox)

	var name_label = Label.new()
	name_label.text = "%s" % combatant.name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	name_hbox.add_child(name_label)

	name_hbox.add_child(Control.new())

	var level_label = Label.new()
	level_label.text = "L%d" % randi_range(1, 20)  # Placeholder level
	level_label.add_theme_font_size_override("font_size", 10)
	name_hbox.add_child(level_label)

	# HP bar
	var hp_hbox = HBoxContainer.new()
	vbox.add_child(hp_hbox)

	var hp_label = Label.new()
	hp_label.text = "HP:"
	hp_label.custom_minimum_size = Vector2(40, 0)
	hp_hbox.add_child(hp_label)

	var hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(150, 14)
	hp_bar.value = (float(combatant.hp) / float(combatant.max_hp)) * 100.0
	hp_bar.modulate.color = _get_health_color(float(combatant.hp) / float(combatant.max_hp))
	hp_bar.name = "hp_bar_%s" % combatant.name
	hp_hbox.add_child(hp_bar)

	var hp_text = Label.new()
	hp_text.text = "%d/%d" % [combatant.hp, combatant.max_hp]
	hp_text.custom_minimum_size = Vector2(70, 0)
	hp_text.add_theme_font_size_override("font_size", 10)
	hp_hbox.add_child(hp_text)

	# MP bar if applicable
	if combatant.max_mp > 0:
		var mp_hbox = HBoxContainer.new()
		vbox.add_child(mp_hbox)

		var mp_label = Label.new()
		mp_label.text = "MP:"
		mp_label.custom_minimum_size = Vector2(40, 0)
		mp_hbox.add_child(mp_label)

		var mp_bar = ProgressBar.new()
		mp_bar.custom_minimum_size = Vector2(150, 14)
		mp_bar.value = (float(combatant.mp) / float(combatant.max_mp)) * 100.0
		mp_bar.modulate.color = Color.DEEP_SKY_BLUE
		mp_bar.name = "mp_bar_%s" % combatant.name
		mp_hbox.add_child(mp_bar)

		var mp_text = Label.new()
		mp_text.text = "%d/%d" % [combatant.mp, combatant.max_mp]
		mp_text.custom_minimum_size = Vector2(70, 0)
		mp_text.add_theme_font_size_override("font_size", 10)
		mp_hbox.add_child(mp_text)

	# Status effects
	if combatant.buffs.size() > 0 or combatant.debuffs.size() > 0:
		var status_hbox = HBoxContainer.new()
		vbox.add_child(status_hbox)
		_add_status_effect_icons(status_hbox, combatant)

	# Status badge
	var status_badge = Label.new()
	status_badge.text = _get_status_badge(combatant)
	status_badge.add_theme_font_size_override("font_size", 10)
	status_badge.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(status_badge)

	return panel


func _create_enemy_display(combatant: Battle.Combatant) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.gui_input.connect(_on_enemy_selected.bind(combatant))
	panel.name = "enemy_%s" % combatant.name

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	vbox.add_theme_constant_override("separation", 4)

	# Name and status
	var name_hbox = HBoxContainer.new()
	vbox.add_child(name_hbox)

	var name_label = Label.new()
	name_label.text = "%s" % combatant.name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.LIGHT_CORAL)
	name_hbox.add_child(name_label)

	name_hbox.add_child(Control.new())

	var level_label = Label.new()
	level_label.text = "L%d" % randi_range(1, 20)
	level_label.add_theme_font_size_override("font_size", 10)
	name_hbox.add_child(level_label)

	# HP bar with status
	var hp_hbox = HBoxContainer.new()
	vbox.add_child(hp_hbox)

	var hp_label = Label.new()
	hp_label.text = "HP:"
	hp_label.custom_minimum_size = Vector2(40, 0)
	hp_hbox.add_child(hp_label)

	var hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(150, 14)
	hp_bar.value = (float(combatant.hp) / float(combatant.max_hp)) * 100.0
	hp_bar.modulate.color = _get_health_color(float(combatant.hp) / float(combatant.max_hp))
	hp_bar.name = "hp_bar_%s" % combatant.name
	hp_hbox.add_child(hp_bar)

	var hp_text = Label.new()
	hp_text.text = "%d/%d" % [combatant.hp, combatant.max_hp]
	hp_text.custom_minimum_size = Vector2(70, 0)
	hp_text.add_theme_font_size_override("font_size", 10)
	hp_hbox.add_child(hp_text)

	# Status effects
	if combatant.buffs.size() > 0 or combatant.debuffs.size() > 0:
		var status_hbox = HBoxContainer.new()
		vbox.add_child(status_hbox)
		_add_status_effect_icons(status_hbox, combatant)

	# Status badge
	var status_badge = Label.new()
	status_badge.text = _get_status_badge(combatant)
	status_badge.add_theme_font_size_override("font_size", 10)
	if combatant.hp <= 0:
		status_badge.add_theme_color_override("font_color", Color.RED)
	else:
		status_badge.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(status_badge)

	return panel


func _create_enemy_detail_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 200)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	vbox.add_theme_constant_override("separation", 6)

	var title = Label.new()
	title.text = "ENEMY DETAILS"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	vbox.add_child(title)

	# Placeholder for enemy info
	var info_label = Label.new()
	info_label.name = "detail_info"
	info_label.text = "Select an enemy to view details"
	info_label.add_theme_font_size_override("font_size", 10)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(info_label)

	return panel


func _create_loot_preview_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	vbox.add_theme_constant_override("separation", 6)

	var title = Label.new()
	title.text = "PREDICTED LOOT"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	vbox.add_child(title)

	var loot_info = Label.new()
	loot_info.name = "loot_info"
	loot_info.text = "Defeat enemies to see loot"
	loot_info.add_theme_font_size_override("font_size", 10)
	loot_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(loot_info)

	return panel


func _create_action_bar() -> Control:
	var action_bar = PanelContainer.new()
	action_bar.anchor_left = 0.0
	action_bar.anchor_right = 1.0
	action_bar.anchor_top = 0.92
	action_bar.anchor_bottom = 1.0

	var action_hbox = HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 8)
	action_bar.add_child(action_hbox)

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
	flee_btn.add_theme_color_override("font_color", Color.LIGHT_CORAL)
	action_hbox.add_child(flee_btn)

	# Spacer
	action_hbox.add_child(Control.new())

	# Turn info
	threat_label = Label.new()
	threat_label.text = "Ready for battle"
	threat_label.add_theme_font_size_override("font_size", 10)
	action_hbox.add_child(threat_label)

	return action_bar


func _create_action_button(text: String, action: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(90, 32)
	btn.pressed.connect(_on_action_selected.bind(action))
	action_buttons.append(btn)
	return btn


func _add_status_effect_icons(parent: HBoxContainer, combatant: Battle.Combatant) -> void:
	var all_effects = combatant.buffs.keys() + combatant.debuffs.keys()

	for effect_name in all_effects:
		var icon_label = Label.new()
		icon_label.text = _get_status_icon(effect_name)
		icon_label.add_theme_font_size_override("font_size", 10)

		if effect_name in status_effect_colors:
			icon_label.add_theme_color_override("font_color", status_effect_colors[effect_name])

		# Add tooltip
		icon_label.tooltip_text = _get_status_tooltip(effect_name)
		parent.add_child(icon_label)


func _on_enemy_selected(event: InputEvent, enemy: Battle.Combatant) -> void:
	if event is InputEventMouseButton and event.pressed:
		selected_enemy = enemy
		_update_enemy_detail_panel(enemy)
		_update_loot_preview_panel(enemy)

		# Highlight selected enemy
		for display in enemy_displays:
			if display.name == "enemy_%s" % enemy.name:
				display.modulate.color = Color.YELLOW
			else:
				display.modulate.color = Color.WHITE


func _on_action_selected(action: String) -> void:
	if not current_actor or not current_actor.is_alive:
		return

	selected_action = action
	_log_message("Selected: %s" % action)

	match action:
		"flee":
			_on_flee()
		"attack", "cast_spell", "use_item":
			_show_target_selection(action)
		"defend":
			_execute_action(action, null)


func _show_target_selection(action: String) -> void:
	target_selection_active = true
	info_label.text = "Click on target for %s" % action

	# Highlight valid targets
	for display in enemy_displays:
		display.modulate.color = Color.LIGHT_GREEN


func _execute_action(action: String, target: Battle.Combatant) -> void:
	if battle.state.battle_over or not current_actor or not current_actor.is_alive:
		return

	target_selection_active = false

	# Reset highlight
	for display in enemy_displays:
		display.modulate.color = Color.WHITE

	var result = battle.execute_turn(current_actor, action, target)

	match action:
		"attack":
			if target:
				var damage = result.get("damage", 0)
				var is_crit = result.get("critical", false)
				_log_message("%s attacks %s for %d damage%s" % [
					current_actor.name, target.name, damage,
					" (CRITICAL!)" if is_crit else ""
				])
		"defend":
			_log_message("%s takes a defensive stance!" % current_actor.name)
		"cast_spell":
			_log_message("%s casts a spell!" % current_actor.name)
		"use_item":
			_log_message("%s uses an item!" % current_actor.name)

	_update_all_displays()

	if not battle.state.battle_over:
		_process_next_turn()
	else:
		_on_battle_end()


func _on_flee() -> void:
	_log_message("⚠ Fled from battle!")
	battle_finished.emit(false)


func _process_next_turn() -> void:
	if battle.state.battle_over:
		return

	# Find next alive combatant
	for combatant in battle.state.turn_order:
		if combatant.is_alive:
			current_actor = combatant

			if combatant.faction == "party":
				info_label.text = "%s's turn - Select action" % combatant.name
				for btn in action_buttons:
					btn.disabled = false
			else:
				info_label.text = "%s's turn..." % combatant.name
				for btn in action_buttons:
					btn.disabled = true
				await get_tree().create_timer(1.0).timeout
				_execute_enemy_ai_turn(combatant)

			return

	_log_message("ERROR: No alive combatant found!")


func _execute_enemy_ai_turn(enemy: Battle.Combatant) -> void:
	# Simple AI: attack random party member
	if battle.state.party.is_empty():
		_process_next_turn()
		return

	var target = battle.state.party[randi() % battle.state.party.size()]
	_execute_action("attack", target)


func _on_battle_end() -> void:
	var result_text = "VICTORY!" if battle.state.player_won else "DEFEAT!"
	_log_message(result_text)

	for btn in action_buttons:
		btn.disabled = true

	battle_finished.emit(battle.state.player_won)


func _update_all_displays() -> void:
	# Update party displays
	for i in range(party_displays.size()):
		if i < battle.state.party.size():
			_update_display(party_displays[i], battle.state.party[i])

	# Update enemy displays
	for i in range(enemy_displays.size()):
		if i < battle.state.enemies.size():
			_update_display(enemy_displays[i], battle.state.enemies[i])

	_update_turn_order()
	round_label.text = "Round: %d" % battle.state.round


func _update_display(panel: PanelContainer, combatant: Battle.Combatant) -> void:
	# Update HP bar
	var hp_bar = panel.find_child("hp_bar_%s" % combatant.name)
	if hp_bar:
		hp_bar.value = (float(combatant.hp) / float(combatant.max_hp)) * 100.0
		hp_bar.modulate.color = _get_health_color(float(combatant.hp) / float(combatant.max_hp))

	# Update MP bar
	var mp_bar = panel.find_child("mp_bar_%s" % combatant.name)
	if mp_bar:
		mp_bar.value = (float(combatant.mp) / float(combatant.max_mp)) * 100.0


func _update_turn_order() -> void:
	for child in turn_order_display.get_children():
		child.queue_free()

	for i in range(min(5, battle.state.turn_order.size())):
		var combatant = battle.state.turn_order[i]
		var turn_label = Label.new()
		var marker = "→" if combatant == current_actor else " "
		turn_label.text = "%s %d. %s" % [marker, i + 1, combatant.name]
		turn_order_display.add_child(turn_label)


func _update_enemy_detail_panel(enemy: Battle.Combatant) -> void:
	var info_label = enemy_detail_panel.find_child("detail_info")
	if not info_label:
		return

	var detail_text = "Name: %s\n" % enemy.name
	detail_text += "Level: %d | Type: Melee\n" % randi_range(1, 20)
	detail_text += "HP: %d/%d\n" % [enemy.hp, enemy.max_hp]
	detail_text += "\nStats:\n"
	detail_text += "STR: %d | DEX: %d | CON: %d\n" % [
		enemy.stats.get("strength", 10),
		enemy.stats.get("dexterity", 10),
		enemy.stats.get("constitution", 10)
	]
	detail_text += "INT: %d | WIS: %d | CHA: %d\n" % [
		enemy.stats.get("intelligence", 10),
		enemy.stats.get("wisdom", 10),
		enemy.stats.get("charisma", 10)
	]

	detail_text += "\nAbilities: Attack, Slash, Dash\n"
	detail_text += "Resistances: Fire 0%, Cold 0%, Lightning 5%\n"
	detail_text += "\nThreat: %s" % _assess_threat_level(enemy)

	info_label.text = detail_text


func _update_loot_preview_panel(enemy: Battle.Combatant) -> void:
	var loot_info = loot_preview_panel.find_child("loot_info")
	if not loot_info:
		return

	var loot_text = "Predicted Drops:\n\n"
	loot_text += "• Iron Sword (Uncommon)\n"
	loot_text += "• Leather Armor (Common)\n"

	if enemy.is_rare_enemy:
		loot_text += "• Rare Gem (Rare) ⭐\n"

	loot_text += "\nGold: 50-150 coins"
	loot_info.text = loot_text


func _log_message(message: String) -> void:
	battle_log.text += "\n" + message
	battle_log.set_caret_line(battle_log.get_line_count() - 1)


func _get_health_color(health_percent: float) -> Color:
	if health_percent >= 0.75:
		return Color.GREEN
	elif health_percent >= 0.3:
		return Color.YELLOW
	else:
		return Color.RED


func _get_status_badge(combatant: Battle.Combatant) -> String:
	if combatant.hp <= 0:
		return "[DEFEATED]"
	elif combatant.hp < float(combatant.max_hp) * 0.3:
		return "[CRITICAL]"
	elif combatant.hp < float(combatant.max_hp) * 0.7:
		return "[INJURED]"
	else:
		return "[HEALTHY]"


func _get_status_icon(effect_name: String) -> String:
	var icons = {
		"poisoned": "☠",
		"burning": "🔥",
		"frozen": "❄",
		"stunned": "⚡",
		"weakened": "↓",
		"blessed": "✦",
		"cursed": "✕",
		"bleeding": "✦",
		"hasted": "↑",
		"slowed": "⊡",
	}
	return icons.get(effect_name, "•")


func _get_status_tooltip(effect_name: String) -> String:
	return status_effect_descriptions.get(effect_name, "Unknown effect")


func _assess_threat_level(enemy: Battle.Combatant) -> String:
	var hp_ratio = float(enemy.hp) / float(enemy.max_hp)
	var threat = "Moderate"

	if enemy.hp > 150:
		threat = "Dangerous"
	elif enemy.hp < 30:
		threat = "Easy"

	if enemy.is_rare_enemy:
		threat = "DEADLY ⚠"

	return threat


func refresh_all_displays() -> void:
	_update_all_displays()


func highlight_current_turn_character(character: Battle.Combatant) -> void:
	current_actor = character
	_update_turn_order()


func show_predicted_loot(enemy: Battle.Combatant) -> void:
	_update_loot_preview_panel(enemy)


func set_battle(p_battle: Battle) -> void:
	battle = p_battle
	_update_all_displays()
