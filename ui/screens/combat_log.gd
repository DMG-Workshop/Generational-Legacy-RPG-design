## Combat Log UI: displays battle messages, turn history, and combat statistics
##
## Scrollable text panel showing all combat messages with:
## - Color-coded message types (damage, healing, status effects)
## - Turn history with compacted view
## - Filter controls and search functionality
## - Real-time combat statistics tracking
## - Professional monospace display with auto-scroll

extends Control

class_name CombatLog


# Signal emitted when a message is added
signal log_message_added(data: Dictionary)


# Message storage and display
var messages: Array[Dictionary] = []  # Stores up to 100 messages
var max_messages: int = 100
var turn_count: int = 0
var current_filter: String = "all"  # all, damage, healing, status, turns

# UI References
var scroll_container: ScrollContainer
var message_panel: VBoxContainer
var turn_history_panel: VBoxContainer
var stats_display: PanelContainer
var filter_buttons: Dictionary = {}
var search_bar: LineEdit

# Combat statistics
var combat_stats: Dictionary = {
	"total_damage_dealt": 0,
	"total_healing_received": 0,
	"turns_elapsed": 0,
	"damage_by_actor": {},
	"healing_by_actor": {},
	"abilities_used": {},
	"status_effects_applied": 0,
	"critical_hits": 0,
	"largest_damage": 0,
	"largest_healing": 0
}

# Message type colors and emojis
var message_styles: Dictionary = {
	"damage": {"color": Color.RED, "emoji": "⚔"},
	"healing": {"color": Color.GREEN, "emoji": "💚"},
	"buff": {"color": Color.CYAN, "emoji": "✨"},
	"debuff": {"color": Color.YELLOW, "emoji": "☠"},
	"status": {"color": Color.YELLOW, "emoji": "⚠"},
	"turn": {"color": Color.WHITE, "emoji": "→"},
	"victory": {"color": Color(1.0, 0.84, 0.0, 1.0), "emoji": "✓"},  # Gold
	"defeat": {"color": Color.RED, "emoji": "✗"},
	"info": {"color": Color.LIGHT_GRAY, "emoji": "ℹ"}
}


func _ready() -> void:
	setup_ui()
	add_theme_constant_override("margin_left", 8)
	add_theme_constant_override("margin_top", 8)
	add_theme_constant_override("margin_right", 8)
	add_theme_constant_override("margin_bottom", 8)


## Build the entire combat log interface
func setup_ui() -> void:
	# Main vertical layout
	var main_vbox = VBoxContainer.new()
	main_vbox.anchor_right = 1.0
	main_vbox.anchor_bottom = 1.0
	main_vbox.add_theme_constant_override("separation", 12)
	add_child(main_vbox)

	# === HEADER ===
	var header = Label.new()
	header.text = "COMBAT LOG"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color.LIGHT_CYAN)
	main_vbox.add_child(header)

	# === FILTER BAR ===
	var filter_hbox = HBoxContainer.new()
	filter_hbox.add_theme_constant_override("separation", 6)
	filter_hbox.custom_minimum_size = Vector2(0, 40)
	main_vbox.add_child(filter_hbox)

	var filter_label = Label.new()
	filter_label.text = "Filter:"
	filter_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	filter_hbox.add_child(filter_label)

	# Create filter buttons
	for filter_type in ["all", "damage", "healing", "status", "turns"]:
		var btn = PolishedButton.new()
		btn.text = filter_type.to_upper()
		btn.custom_minimum_size = Vector2(80, 32)
		btn.toggle_mode = true
		if filter_type == "all":
			btn.button_pressed = true
		btn.pressed.connect(_on_filter_button_pressed.bindv([filter_type]))
		filter_hbox.add_child(btn)
		filter_buttons[filter_type] = btn

	# Search bar
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_hbox.add_child(spacer)

	search_bar = LineEdit.new()
	search_bar.placeholder_text = "Search messages..."
	search_bar.custom_minimum_size = Vector2(150, 32)
	filter_hbox.add_child(search_bar)

	# === STATS BAR ===
	var stats_hbox = HBoxContainer.new()
	stats_hbox.add_theme_constant_override("separation", 16)
	stats_hbox.custom_minimum_size = Vector2(0, 30)
	main_vbox.add_child(stats_hbox)

	var damage_stat = Label.new()
	damage_stat.name = "damage_stat"
	damage_stat.text = "Damage Dealt: 0"
	damage_stat.add_theme_color_override("font_color", Color.RED)
	damage_stat.add_theme_font_size_override("font_size", 11)
	stats_hbox.add_child(damage_stat)

	var healing_stat = Label.new()
	healing_stat.name = "healing_stat"
	healing_stat.text = "Healing: 0"
	healing_stat.add_theme_color_override("font_color", Color.GREEN)
	healing_stat.add_theme_font_size_override("font_size", 11)
	stats_hbox.add_child(healing_stat)

	var turn_stat = Label.new()
	turn_stat.name = "turn_stat"
	turn_stat.text = "Turn: 0"
	turn_stat.add_theme_color_override("font_color", Color.LIGHT_CYAN)
	turn_stat.add_theme_font_size_override("font_size", 11)
	stats_hbox.add_child(turn_stat)

	# Separator
	var separator1 = ColorRect.new()
	separator1.color = Color.DARK_SLATE_GRAY
	separator1.custom_minimum_size = Vector2(0, 2)
	main_vbox.add_child(separator1)

	# === MESSAGE DISPLAY ===
	var messages_label = Label.new()
	messages_label.text = "BATTLE MESSAGES"
	messages_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	messages_label.add_theme_font_size_override("font_size", 12)
	main_vbox.add_child(messages_label)

	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.scroll_vertical = true
	scroll_container.custom_minimum_size = Vector2(0, 200)
	main_vbox.add_child(scroll_container)

	message_panel = VBoxContainer.new()
	message_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(message_panel)
	message_panel.add_theme_constant_override("separation", 2)

	# === TURN HISTORY ===
	var separator2 = ColorRect.new()
	separator2.color = Color.DARK_SLATE_GRAY
	separator2.custom_minimum_size = Vector2(0, 2)
	main_vbox.add_child(separator2)

	var history_label = Label.new()
	history_label.text = "TURN HISTORY"
	history_label.add_theme_color_override("font_color", Color.LIGHT_YELLOW)
	history_label.add_theme_font_size_override("font_size", 12)
	main_vbox.add_child(history_label)

	turn_history_panel = VBoxContainer.new()
	turn_history_panel.custom_minimum_size = Vector2(0, 80)
	turn_history_panel.add_theme_constant_override("separation", 2)
	main_vbox.add_child(turn_history_panel)

	# Placeholder turn history
	var history_placeholder = Label.new()
	history_placeholder.name = "history_placeholder"
	history_placeholder.text = "No turns yet"
	history_placeholder.add_theme_color_override("font_color", Color.DARK_GRAY)
	turn_history_panel.add_child(history_placeholder)


## Add a generic message to the log
func add_message(message: String, msg_type: String = "info", actor: String = "") -> void:
	var msg_data = {
		"text": message,
		"type": msg_type,
		"actor": actor,
		"timestamp": Time.get_ticks_msec()
	}

	messages.append(msg_data)

	# Keep message history limited
	if messages.size() > max_messages:
		messages.pop_front()

	log_message_added.emit(msg_data)
	_display_message(msg_data)
	_refresh_stats()


## Add damage message
func add_damage(attacker: String, target: String, damage: int, crit: bool = false) -> void:
	var crit_text = " [CRIT!]" if crit else ""
	var message = "%s dealt %d damage to %s%s" % [attacker, damage, target, crit_text]
	add_message(message, "damage", attacker)

	# Update statistics
	combat_stats["total_damage_dealt"] += damage
	if attacker not in combat_stats["damage_by_actor"]:
		combat_stats["damage_by_actor"][attacker] = 0
	combat_stats["damage_by_actor"][attacker] += damage
	combat_stats["largest_damage"] = max(combat_stats["largest_damage"], damage)
	if crit:
		combat_stats["critical_hits"] += 1


## Add healing message
func add_healing(healer: String, target: String, healing: int) -> void:
	var message = "%s healed %s for %d HP" % [healer, target, healing]
	add_message(message, "healing", healer)

	# Update statistics
	combat_stats["total_healing_received"] += healing
	if healer not in combat_stats["healing_by_actor"]:
		combat_stats["healing_by_actor"][healer] = 0
	combat_stats["healing_by_actor"][healer] += healing
	combat_stats["largest_healing"] = max(combat_stats["largest_healing"], healing)


## Add status effect message
func add_status_effect(actor: String, effect: String, active: bool) -> void:
	var status_text = "gained" if active else "lost"
	var message = "%s %s %s" % [actor, status_text, effect]
	add_message(message, "status", actor)
	combat_stats["status_effects_applied"] += 1


## Add buff message
func add_buff(actor: String, buff_name: String, value: String = "") -> void:
	var value_text = " %s" % value if value else ""
	var message = "%s gained %s%s" % [actor, buff_name, value_text]
	add_message(message, "buff", actor)


## Add debuff message
func add_debuff(actor: String, debuff_name: String, value: String = "") -> void:
	var value_text = " %s" % value if value else ""
	var message = "%s received %s%s" % [actor, debuff_name, value_text]
	add_message(message, "debuff", actor)


## Add turn change message
func add_turn_change(actor: String) -> void:
	turn_count += 1
	var message = "--- %s's turn (Turn %d) ---" % [actor, turn_count]
	add_message(message, "turn", actor)
	combat_stats["turns_elapsed"] = turn_count


## Add victory message
func add_victory(xp_gained: int = 0, gold_gained: int = 0) -> void:
	var rewards_text = ""
	if xp_gained > 0:
		rewards_text = " Gained %d XP" % xp_gained
	if gold_gained > 0:
		rewards_text += " and %d Gold" % gold_gained
	var message = "VICTORY!%s" % rewards_text
	add_message(message, "victory")


## Add defeat message
func add_defeat() -> void:
	add_message("DEFEAT... The party fell in battle.", "defeat")


## Display a single message in the message panel with formatting
func _display_message(msg_data: Dictionary) -> void:
	var style = message_styles.get(msg_data["type"], message_styles["info"])
	var emoji = style.get("emoji", "")
	var color = style.get("color", Color.WHITE)

	var message_label = Label.new()
	message_label.text = "[%s] %s" % [emoji, msg_data["text"]]
	message_label.add_theme_color_override("font_color", color)
	message_label.add_theme_font_size_override("font_size", 12)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	message_panel.add_child(message_label)

	# Apply fade-in animation
	var tween = create_tween()
	message_label.modulate.a = 0.0
	tween.tween_property(message_label, "modulate:a", 1.0, 0.3)

	# Auto-scroll to latest
	await get_tree().process_frame
	scroll_container.get_v_scroll_bar().value = scroll_container.get_v_scroll_bar().max_value


## Refresh statistics display
func _refresh_stats() -> void:
	var damage_label = find_child("damage_stat", true, false)
	if damage_label:
		damage_label.text = "Damage: %d | Max: %d" % [combat_stats["total_damage_dealt"], combat_stats["largest_damage"]]

	var healing_label = find_child("healing_stat", true, false)
	if healing_label:
		healing_label.text = "Healing: %d | Max: %d" % [combat_stats["total_healing_received"], combat_stats["largest_healing"]]

	var turn_label = find_child("turn_stat", true, false)
	if turn_label:
		turn_label.text = "Turn: %d | Messages: %d" % [turn_count, messages.size()]


## Handle filter button presses
func _on_filter_button_pressed(filter_type: String) -> void:
	# Deselect all other buttons
	for btn_name in filter_buttons:
		if btn_name != filter_type:
			filter_buttons[btn_name].button_pressed = false

	current_filter = filter_type
	refresh_displays()


## Clear all messages
func clear_log() -> void:
	messages.clear()
	message_panel.queue_free_children()
	turn_history_panel.queue_free_children()
	turn_count = 0
	combat_stats.clear()
	combat_stats = {
		"total_damage_dealt": 0,
		"total_healing_received": 0,
		"turns_elapsed": 0,
		"damage_by_actor": {},
		"healing_by_actor": {},
		"abilities_used": {},
		"status_effects_applied": 0,
		"critical_hits": 0,
		"largest_damage": 0,
		"largest_healing": 0
	}
	_refresh_stats()


## Get turn history as array of dictionaries
func get_turn_history() -> Array[Dictionary]:
	var turn_history: Array[Dictionary] = []
	var current_turn: Dictionary = {"turn": 0, "messages": []}

	for msg in messages:
		if msg["type"] == "turn":
			if current_turn["messages"].size() > 0:
				turn_history.append(current_turn)
			current_turn = {"turn": turn_count, "messages": []}
		else:
			current_turn["messages"].append(msg)

	if current_turn["messages"].size() > 0:
		turn_history.append(current_turn)

	return turn_history


## Refresh all display elements based on current filter
func refresh_displays() -> void:
	message_panel.queue_free_children()

	var search_text = search_bar.text.to_lower() if search_bar else ""

	# Display messages based on filter and search
	for msg in messages:
		# Apply filter
		if current_filter != "all" and msg["type"] != current_filter:
			continue

		# Apply search
		if search_text and search_text not in msg["text"].to_lower():
			continue

		_display_message(msg)


## Get combat statistics dictionary
func get_combat_stats() -> Dictionary:
	return combat_stats.duplicate(true)


## Update combat statistics (called externally if needed)
func update_combat_stats(stat_name: String, value: int) -> void:
	if combat_stats.has(stat_name):
		combat_stats[stat_name] = value
		_refresh_stats()
