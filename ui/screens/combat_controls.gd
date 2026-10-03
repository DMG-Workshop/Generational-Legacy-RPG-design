## Combat Controls UI: ability and skill selection during battles
##
## Turn-based action selection interface with:
## - Ability list with hotkey support
## - Resource cost display (Mana, Stamina)
## - Target selection for single/AOE abilities
## - Action preview before execution
## - Color-coded availability status
## - Responsive to keyboard and mouse input

extends Control

class_name CombatControls


signal action_executed(action_data: Dictionary)
signal action_cancelled


## Combat system reference
var battle: Battle
var active_character: Battle.Combatant
var current_ability: Dictionary
var selected_target: Battle.Combatant
var is_ability_list_visible: bool = true
var ability_hotkey_map: Dictionary = {}

## UI References
var ability_container: VBoxContainer
var resource_display: PanelContainer
var target_buttons: Array[Button] = []
var action_preview_label: Label
var ability_list_scroll: ScrollContainer
var header_label: Label


func _init(p_battle: Battle) -> void:
	battle = p_battle


func _ready() -> void:
	setup_ui()
	setup_input_handling()


## Build the entire combat controls interface
func setup_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color.BLACK.with_alpha(0.85)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Main container
	var main_panel = PanelContainer.new()
	main_panel.anchor_left = 0.1
	main_panel.anchor_top = 0.05
	main_panel.anchor_right = 0.9
	main_panel.anchor_bottom = 0.95
	add_child(main_panel)

	var main_vbox = VBoxContainer.new()
	main_panel.add_child(main_vbox)
	main_vbox.add_theme_constant_override("separation", 12)

	# === HEADER ===
	header_label = Label.new()
	header_label.text = "COMBAT ACTIONS"
	header_label.add_theme_font_size_override("font_size", 20)
	header_label.add_theme_color_override("font_color", Color.LIGHT_CYAN)
	main_vbox.add_child(header_label)

	# Separator
	var separator1 = ColorRect.new()
	separator1.color = Color.DARK_SLATE_GRAY
	separator1.custom_minimum_size = Vector2(0, 2)
	main_vbox.add_child(separator1)

	# === RESOURCE DISPLAY ===
	resource_display = _create_resource_display()
	main_vbox.add_child(resource_display)

	# === ABILITY LIST ===
	var ability_title = Label.new()
	ability_title.text = "ABILITIES (%d available)" % 6  # Placeholder
	ability_title.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	ability_title.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(ability_title)

	ability_list_scroll = ScrollContainer.new()
	ability_list_scroll.custom_minimum_size = Vector2(0, 220)
	ability_list_scroll.scroll_vertical = true
	main_vbox.add_child(ability_list_scroll)

	ability_container = VBoxContainer.new()
	ability_list_scroll.add_child(ability_container)
	ability_container.add_theme_constant_override("separation", 4)

	# === TARGET SELECTION ===
	var target_title = Label.new()
	target_title.text = "TARGET SELECTION"
	target_title.add_theme_color_override("font_color", Color.LIGHT_YELLOW)
	target_title.add_theme_font_size_override("font_size", 12)
	main_vbox.add_child(target_title)

	var target_hbox = HBoxContainer.new()
	target_hbox.custom_minimum_size = Vector2(0, 40)
	target_hbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(target_hbox)

	# Will be populated dynamically with enemy buttons
	var target_placeholder = Label.new()
	target_placeholder.text = "No targets available"
	target_placeholder.name = "target_placeholder"
	target_hbox.add_child(target_placeholder)

	# === ACTION PREVIEW ===
	var preview_title = Label.new()
	preview_title.text = "ACTION PREVIEW"
	preview_title.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	preview_title.add_theme_font_size_override("font_size", 12)
	main_vbox.add_child(preview_title)

	action_preview_label = Label.new()
	action_preview_label.text = "Select an ability to preview"
	action_preview_label.add_theme_font_size_override("font_size", 11)
	action_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	action_preview_label.custom_minimum_size = Vector2(0, 60)
	main_vbox.add_child(action_preview_label)

	# Separator
	var separator2 = ColorRect.new()
	separator2.color = Color.DARK_SLATE_GRAY
	separator2.custom_minimum_size = Vector2(0, 2)
	main_vbox.add_child(separator2)

	# === ACTION BUTTONS ===
	var button_hbox = HBoxContainer.new()
	button_hbox.add_theme_constant_override("separation", 8)
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(button_hbox)

	var execute_btn = PolishedButton.new()
	execute_btn.text = "Execute"
	execute_btn.custom_minimum_size = Vector2(100, 40)
	execute_btn.pressed.connect(_on_execute_pressed)
	button_hbox.add_child(execute_btn)

	var cancel_btn = PolishedButton.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(100, 40)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	button_hbox.add_child(cancel_btn)

	var defend_btn = PolishedButton.new()
	defend_btn.text = "Defend"
	defend_btn.custom_minimum_size = Vector2(100, 40)
	defend_btn.pressed.connect(_on_defend_pressed)
	button_hbox.add_child(defend_btn)

	var flee_btn = PolishedButton.new()
	flee_btn.text = "Flee"
	flee_btn.custom_minimum_size = Vector2(100, 40)
	flee_btn.pressed.connect(_on_flee_pressed)
	button_hbox.add_child(flee_btn)


## Create resource display panel (health, mana, stamina)
func _create_resource_display() -> PanelContainer:
	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	vbox.add_theme_constant_override("separation", 8)

	# Health bar
	var hp_label = Label.new()
	hp_label.name = "hp_label"
	hp_label.text = "HP: 100/100"
	hp_label.add_theme_color_override("font_color", Color.RED)
	vbox.add_child(hp_label)

	var hp_bar = ProgressBar.new()
	hp_bar.name = "hp_bar"
	hp_bar.value = 100
	hp_bar.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(hp_bar)

	# Mana bar
	var mp_label = Label.new()
	mp_label.name = "mp_label"
	mp_label.text = "Mana: 50/50"
	mp_label.add_theme_color_override("font_color", Color.CYAN)
	vbox.add_child(mp_label)

	var mp_bar = ProgressBar.new()
	mp_bar.name = "mp_bar"
	mp_bar.value = 50
	mp_bar.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(mp_bar)

	# Stamina bar (conditional)
	var stamina_label = Label.new()
	stamina_label.name = "stamina_label"
	stamina_label.text = "Stamina: 75/100"
	stamina_label.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(stamina_label)

	var stamina_bar = ProgressBar.new()
	stamina_bar.name = "stamina_bar"
	stamina_bar.value = 75
	stamina_bar.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(stamina_bar)

	return panel


## Set active character and refresh abilities
func set_active_character(character: Battle.Combatant) -> void:
	active_character = character
	header_label.text = "COMBAT ACTIONS - %s's Turn" % character.name
	refresh_ability_list()
	update_resource_display()


## Rebuild ability list from character's available abilities
func refresh_ability_list() -> void:
	ability_container.queue_free_children()
	ability_hotkey_map.clear()
	var hotkey_index = 1

	# Mock abilities for demonstration - in real game, load from character data
	var mock_abilities = [
		{
			"name": "Basic Attack",
			"icon": "⚔",
			"cost": 10,
			"cost_type": "stamina",
			"cooldown": 0,
			"description": "Damage: +15% vs selected target",
			"target_type": "single",
			"damage": 15
		},
		{
			"name": "Fireball",
			"icon": "🔥",
			"cost": 25,
			"cost_type": "mana",
			"cooldown": 0,
			"description": "AOE Damage: 30 fire damage to all enemies",
			"target_type": "aoe",
			"damage": 30
		},
		{
			"name": "Shield Wall",
			"icon": "🛡",
			"cost": 15,
			"cost_type": "stamina",
			"cooldown": 0,
			"description": "Effect: +5 DEF for 2 turns",
			"target_type": "self",
			"effect": "shield"
		},
		{
			"name": "Lightning Strike",
			"icon": "⚡",
			"cost": 30,
			"cost_type": "mana",
			"cooldown": 0,
			"description": "Damage: 40 lightning to target, 20% to all",
			"target_type": "single_aoe",
			"damage": 40
		},
		{
			"name": "Healing Potion",
			"icon": "💉",
			"cost": 0,
			"cost_type": "inventory",
			"cooldown": 0,
			"quantity": 3,
			"description": "Effect: Heal 50 HP",
			"target_type": "self",
			"healing": 50
		},
		{
			"name": "Defend",
			"icon": "🏃",
			"cost": 0,
			"cost_type": "none",
			"cooldown": 0,
			"description": "Effect: Reduce damage by 50% this turn",
			"target_type": "self",
			"effect": "defend"
		}
	]

	for ability in mock_abilities:
		var ability_item = _create_ability_item(ability, hotkey_index)
		ability_container.add_child(ability_item)
		ability_hotkey_map[hotkey_index] = ability
		hotkey_index += 1


## Create a single ability item in the list
func _create_ability_item(ability: Dictionary, hotkey: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 70)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	vbox.add_theme_constant_override("separation", 2)

	# Title line: icon, name, hotkey, status
	var title_hbox = HBoxContainer.new()
	vbox.add_child(title_hbox)

	var icon_label = Label.new()
	icon_label.text = ability["icon"]
	icon_label.custom_minimum_size = Vector2(30, 0)
	title_hbox.add_child(icon_label)

	var name_label = Label.new()
	name_label.text = ability["name"]
	name_label.add_theme_font_size_override("font_size", 12)
	title_hbox.add_child(name_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(spacer)

	var hotkey_label = Label.new()
	hotkey_label.text = "[%d]" % hotkey
	hotkey_label.add_theme_color_override("font_color", Color.LIGHT_CYAN)
	title_hbox.add_child(hotkey_label)

	var status_label = Label.new()
	status_label.text = "Ready"
	var status_color = _get_ability_status_color(ability)
	status_label.add_theme_color_override("font_color", status_color)
	title_hbox.add_child(status_label)

	# Cost line
	var cost_line = Label.new()
	var cost_text = ""
	if ability["cost"] > 0:
		cost_text = "Cost: %d %s | " % [ability["cost"], ability["cost_type"].to_upper()]
	if ability.has("quantity"):
		cost_text += "Inventory (%d) | " % ability["quantity"]
	if ability["cooldown"] > 0:
		cost_text += "Cooldown: %d turns" % ability["cooldown"]
	else:
		cost_text += "Cooldown: Ready"

	cost_line.text = cost_text
	cost_line.add_theme_font_size_override("font_size", 10)
	cost_line.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(cost_line)

	# Description line
	var desc_line = Label.new()
	desc_line.text = ability["description"]
	desc_line.add_theme_font_size_override("font_size", 10)
	desc_line.add_theme_color_override("font_color", Color.DARK_GRAY)
	desc_line.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_line)

	# Make it clickable
	var button = Button.new()
	button.modulate.a = 0  # Invisible button overlay
	button.anchor_right = 1.0
	button.anchor_bottom = 1.0
	panel.add_child(button)

	var stored_ability = ability.duplicate()
	button.pressed.connect(func(): select_ability(stored_ability))

	return panel


## Get color for ability availability status
func _get_ability_status_color(ability: Dictionary) -> Color:
	if ability["cooldown"] > 0:
		return Color.YELLOW  # On cooldown
	elif ability["cost"] > active_character.mp if ability["cost_type"] == "mana" else false:
		return Color.RED  # Insufficient resources
	elif ability.has("quantity") and ability["quantity"] <= 0:
		return Color.GRAY  # Out of stock
	else:
		return Color.GREEN  # Available


## Select an ability and show preview
func select_ability(ability: Dictionary) -> void:
	current_ability = ability
	update_target_buttons()
	update_action_preview()


## Update target selection buttons based on ability target type
func update_target_buttons() -> void:
	# Clear existing buttons
	for btn in target_buttons:
		btn.queue_free()
	target_buttons.clear()

	var target_container = find_child("target_placeholder").get_parent()
	if target_container.has_meta("target_placeholder"):
		target_container.get_node("target_placeholder").queue_free()

	if not current_ability:
		var placeholder = Label.new()
		placeholder.text = "Select an ability"
		target_container.add_child(placeholder)
		return

	match current_ability["target_type"]:
		"single":
			# Create buttons for each alive enemy
			for enemy in battle.state.enemies:
				if enemy.is_alive:
					var btn = _create_target_button(enemy)
					target_container.add_child(btn)
					target_buttons.append(btn)

		"aoe":
			# Show "All Enemies" indicator
			var label = Label.new()
			label.text = "Target: All Enemies"
			label.add_theme_color_override("font_color", Color.LIGHT_CYAN)
			target_container.add_child(label)
			selected_target = null

		"self":
			# Self-target
			var label = Label.new()
			label.text = "Target: Self (%s)" % active_character.name
			label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
			target_container.add_child(label)
			selected_target = active_character

		"single_aoe":
			# Single target with AOE splash
			for enemy in battle.state.enemies:
				if enemy.is_alive:
					var btn = _create_target_button(enemy)
					target_container.add_child(btn)
					target_buttons.append(btn)


## Create a target selection button
func _create_target_button(target: Battle.Combatant) -> Button:
	var btn = PolishedButton.new()
	btn.text = "%s\nHP: %d/%d" % [target.name, target.hp, target.max_hp]
	btn.custom_minimum_size = Vector2(120, 50)
	btn.pressed.connect(func(): selected_target = target)
	return btn


## Update action preview text
func update_action_preview() -> void:
	if not current_ability:
		action_preview_label.text = "Select an ability to preview"
		return

	var preview_lines = []
	preview_lines.append("%s will %s" % [current_ability["name"], _get_ability_effect_text()])

	# Add resource check
	if current_ability["cost"] > 0:
		var can_afford = true
		if current_ability["cost_type"] == "mana":
			can_afford = active_character.mp >= current_ability["cost"]
		elif current_ability["cost_type"] == "stamina":
			can_afford = true  # Assume stamina exists

		var resource_check = "✓ Resources available" if can_afford else "✗ Insufficient %s" % current_ability["cost_type"]
		preview_lines.append(resource_check)
	else:
		preview_lines.append("✓ Resources available")

	# Cooldown check
	var cooldown_check = "✓ Cooldown ready" if current_ability["cooldown"] <= 0 else "✗ On cooldown for %d turns" % current_ability["cooldown"]
	preview_lines.append(cooldown_check)

	# Range check
	preview_lines.append("✓ In range")

	action_preview_label.text = "\n".join(preview_lines)


## Get ability effect text for preview
func _get_ability_effect_text() -> String:
	match current_ability["target_type"]:
		"aoe":
			return "deal ~%d damage to all %d enemies" % [current_ability.get("damage", 0), battle.state.enemies.filter(func(c): return c.is_alive).size()]
		"self":
			if current_ability.has("healing"):
				return "heal %d HP" % current_ability["healing"]
			else:
				return "apply effect: %s" % current_ability.get("effect", "unknown")
		_:
			if current_ability.has("damage"):
				return "deal ~%d damage to target" % current_ability["damage"]
			else:
				return "apply effect"


## Update resource display bars and labels
func update_resource_display() -> void:
	if not active_character:
		return

	# HP
	var hp_label = resource_display.find_child("hp_label", true, false)
	var hp_bar = resource_display.find_child("hp_bar", true, false)
	if hp_label and hp_bar:
		hp_label.text = "HP: %d/%d" % [active_character.hp, active_character.max_hp]
		hp_bar.max_value = active_character.max_hp
		hp_bar.value = active_character.hp
		# Color based on health percentage
		var health_percent = float(active_character.hp) / active_character.max_hp
		if health_percent > 0.5:
			hp_bar.modulate = Color.GREEN
		elif health_percent > 0.25:
			hp_bar.modulate = Color.YELLOW
		else:
			hp_bar.modulate = Color.RED

	# Mana
	var mp_label = resource_display.find_child("mp_label", true, false)
	var mp_bar = resource_display.find_child("mp_bar", true, false)
	if mp_label and mp_bar:
		mp_label.text = "Mana: %d/%d" % [active_character.mp, active_character.max_mp]
		mp_bar.max_value = active_character.max_mp
		mp_bar.value = active_character.mp


## Execute the selected action
func _on_execute_pressed() -> void:
	if not current_ability:
		return

	var action_data = {
		"actor": active_character,
		"ability": current_ability,
		"target": selected_target,
		"timestamp": Time.get_ticks_msec()
	}

	action_executed.emit(action_data)


## Cancel current selection
func _on_cancel_pressed() -> void:
	current_ability = null
	selected_target = null
	action_preview_label.text = "Select an ability to preview"
	action_cancelled.emit()


## Quick defend action
func _on_defend_pressed() -> void:
	var defend_ability = {
		"name": "Defend",
		"icon": "🏃",
		"cost": 0,
		"cost_type": "none",
		"cooldown": 0,
		"description": "Reduce damage by 50% this turn",
		"target_type": "self",
		"effect": "defend"
	}

	var action_data = {
		"actor": active_character,
		"ability": defend_ability,
		"target": active_character,
		"timestamp": Time.get_ticks_msec()
	}

	action_executed.emit(action_data)


## Attempt to flee from battle
func _on_flee_pressed() -> void:
	var flee_ability = {
		"name": "Flee",
		"icon": "🏃",
		"cost": 0,
		"cost_type": "none",
		"cooldown": 0,
		"description": "Attempt to escape battle",
		"target_type": "none",
		"effect": "flee"
	}

	var action_data = {
		"actor": active_character,
		"ability": flee_ability,
		"target": null,
		"timestamp": Time.get_ticks_msec()
	}

	action_executed.emit(action_data)


## Setup keyboard input handling for hotkeys
func setup_input_handling() -> void:
	pass  # Input will be handled by parent battle screen


## Handle hotkey input (called from parent)
func handle_hotkey(key: int) -> void:
	if ability_hotkey_map.has(key):
		select_ability(ability_hotkey_map[key])
