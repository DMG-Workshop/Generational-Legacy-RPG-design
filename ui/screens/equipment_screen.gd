## Equipment Screen: display and manage equipped items and stat bonuses
##
## Shows the heir's equipped items, stat totals, stat breakdowns, and elemental resistances.
## Allows equipping/unequipping items and comparing with inventory.

extends Control

class_name EquipmentScreen


## Data source
var heir_equipment: HeirEquipment
var heir: Heir

## UI Components
var equipment_slot_display: Control
var stat_panel: VBoxContainer
var resistance_panel: VBoxContainer
var item_details_panel: VBoxContainer
var action_buttons_container: HBoxContainer

## Selected item tracking
var selected_slot: int = -1
var selected_item: Equipment = null

## Equipment slots (order for UI display)
var slot_order: Array[int] = [
	Equipment.EquipmentSlot.HEAD,
	Equipment.EquipmentSlot.CHEST,
	Equipment.EquipmentSlot.HANDS,
	Equipment.EquipmentSlot.LEGS,
	Equipment.EquipmentSlot.FEET,
	Equipment.EquipmentSlot.MAIN_HAND,
	Equipment.EquipmentSlot.OFF_HAND,
	Equipment.EquipmentSlot.NECK,
	Equipment.EquipmentSlot.FINGER,
]

## Stat display labels (for real-time updates)
var stat_labels: Dictionary = {}
var resistance_labels: Dictionary = {}
var slot_buttons: Dictionary = {}


func _init(p_heir: Heir) -> void:
	heir = p_heir
	heir_equipment = HeirEquipment.new(heir)


func _ready() -> void:
	setup_ui()
	refresh_equipment_display()

	# Connect to signals if available
	if heir and heir.is_connected("equipment_changed", Callable(self, "refresh_equipment_display")):
		pass


func setup_ui() -> void:
	# Background overlay
	var bg = ColorRect.new()
	bg.color = Color.BLACK.with_alpha(0.85)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Main content container
	var main_panel = PanelContainer.new()
	main_panel.anchor_left = 0.05
	main_panel.anchor_top = 0.05
	main_panel.anchor_right = 0.95
	main_panel.anchor_bottom = 0.95
	add_child(main_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	main_panel.add_child(main_vbox)

	# Header
	_setup_header(main_vbox)

	# Main content area (horizontal split)
	var content_hbox = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 15)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_hbox)

	# Left side: Equipment slots
	_setup_equipment_slots(content_hbox)

	# Middle: Stats and Resistances
	_setup_stat_and_resistance_panels(content_hbox)

	# Right side: Item details
	_setup_item_details_panel(content_hbox)

	# Bottom: Action buttons
	_setup_action_buttons(main_vbox)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close (ESC)"
	close_btn.custom_minimum_size = Vector2(120, 35)
	close_btn.pressed.connect(_on_close_pressed)
	main_vbox.add_child(close_btn)


func _setup_header(parent: VBoxContainer) -> void:
	var header = VBoxContainer.new()
	parent.add_child(header)

	var title = Label.new()
	title.text = "EQUIPMENT"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.GOLD)
	header.add_child(title)

	var heir_info = Label.new()
	heir_info.text = "%s - Level %d (%s)" % [
		heir.name,
		heir.generation,
		heir.class_id
	]
	heir_info.add_theme_font_size_override("font_size", 14)
	header.add_child(heir_info)

	var separator = HSeparator.new()
	header.add_child(separator)


func _setup_equipment_slots(parent: HBoxContainer) -> void:
	equipment_slot_display = VBoxContainer.new()
	equipment_slot_display.custom_minimum_size = Vector2(220, 0)
	equipment_slot_display.add_theme_constant_override("separation", 5)
	parent.add_child(equipment_slot_display)

	var slot_title = Label.new()
	slot_title.text = "EQUIPPED ITEMS"
	slot_title.add_theme_font_size_override("font_size", 14)
	slot_title.add_theme_color_override("font_color", Color.YELLOW)
	equipment_slot_display.add_child(slot_title)

	# Create slot display for each equipment slot
	for slot in slot_order:
		_create_slot_button(slot)


func _create_slot_button(slot: int) -> void:
	var slot_container = PanelContainer.new()
	slot_container.custom_minimum_size = Vector2(0, 45)
	equipment_slot_display.add_child(slot_container)

	var slot_hbox = HBoxContainer.new()
	slot_hbox.add_theme_constant_override("separation", 10)
	slot_container.add_child(slot_hbox)

	# Slot name label
	var slot_name_label = Label.new()
	slot_name_label.text = heir_equipment.get_slot_name(slot)
	slot_name_label.custom_minimum_size = Vector2(100, 0)
	slot_name_label.add_theme_font_size_override("font_size", 12)
	slot_hbox.add_child(slot_name_label)

	# Item name or "Empty"
	var item_label = Label.new()
	item_label.text = "—"
	item_label.custom_minimum_size = Vector2(100, 0)
	item_label.clip_text = true
	item_label.add_theme_font_size_override("font_size", 11)
	slot_hbox.add_child(item_label)

	# Clickable button
	var btn = Button.new()
	btn.text = "Select"
	btn.custom_minimum_size = Vector2(60, 0)
	btn.pressed.connect(_on_slot_button_pressed.bindv([slot]))
	slot_hbox.add_child(btn)

	# Store references
	slot_buttons[slot] = {
		"container": slot_container,
		"item_label": item_label,
		"button": btn
	}


func _setup_stat_and_resistance_panels(parent: HBoxContainer) -> void:
	var stat_resist_vbox = VBoxContainer.new()
	stat_resist_vbox.add_theme_constant_override("separation", 15)
	stat_resist_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(stat_resist_vbox)

	# Stats panel
	stat_panel = VBoxContainer.new()
	stat_resist_vbox.add_child(stat_panel)

	var stat_title = Label.new()
	stat_title.text = "STATS"
	stat_title.add_theme_font_size_override("font_size", 14)
	stat_title.add_theme_color_override("font_color", Color.YELLOW)
	stat_panel.add_child(stat_title)

	# Create stat display for each core stat
	var stat_names = ["Strength", "Dexterity", "Constitution", "Intelligence", "Wisdom", "Charisma"]
	var stat_keys = ["strength", "dexterity", "constitution", "intelligence", "wisdom", "charisma"]

	for i in range(stat_names.size()):
		_create_stat_row(stat_names[i], stat_keys[i])

	# Resistances panel
	resistance_panel = VBoxContainer.new()
	stat_resist_vbox.add_child(resistance_panel)

	var resist_title = Label.new()
	resist_title.text = "RESISTANCES"
	resist_title.add_theme_font_size_override("font_size", 14)
	resist_title.add_theme_color_override("font_color", Color.YELLOW)
	resistance_panel.add_child(resist_title)

	# Create resistance display
	var resistance_types = ["fire", "cold", "lightning", "poison", "magic"]
	for res_type in resistance_types:
		_create_resistance_row(res_type)


func _create_stat_row(stat_name: String, stat_key: String) -> void:
	var stat_hbox = HBoxContainer.new()
	stat_hbox.add_theme_constant_override("separation", 10)
	stat_panel.add_child(stat_hbox)

	var name_label = Label.new()
	name_label.text = "%s:" % stat_name
	name_label.custom_minimum_size = Vector2(100, 0)
	name_label.add_theme_font_size_override("font_size", 11)
	stat_hbox.add_child(name_label)

	var value_label = Label.new()
	value_label.text = "10 → 10 (+0)"
	value_label.custom_minimum_size = Vector2(120, 0)
	value_label.add_theme_font_size_override("font_size", 11)
	stat_hbox.add_child(value_label)

	stat_labels[stat_key] = value_label


func _create_resistance_row(resistance_type: String) -> void:
	var resist_hbox = HBoxContainer.new()
	resist_hbox.add_theme_constant_override("separation", 10)
	resistance_panel.add_child(resist_hbox)

	var name_label = Label.new()
	name_label.text = resistance_type.capitalize() + ":"
	name_label.custom_minimum_size = Vector2(100, 0)
	name_label.add_theme_font_size_override("font_size", 11)
	resist_hbox.add_child(name_label)

	var value_label = Label.new()
	value_label.text = "0%"
	value_label.custom_minimum_size = Vector2(50, 0)
	value_label.add_theme_font_size_override("font_size", 11)
	resist_hbox.add_child(value_label)

	# Visual bar
	var bar_bg = ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(100, 15)
	bar_bg.color = Color.DARK_GRAY
	resist_hbox.add_child(bar_bg)

	var bar_fill = ColorRect.new()
	bar_fill.anchor_right = 0.0  # Will be set dynamically
	bar_fill.anchor_bottom = 1.0
	bar_fill.custom_minimum_size = Vector2(0, 15)
	bar_fill.color = Color.GREEN
	bar_bg.add_child(bar_fill)

	resistance_labels[resistance_type] = {
		"label": value_label,
		"bar_bg": bar_bg,
		"bar_fill": bar_fill
	}


func _setup_item_details_panel(parent: HBoxContainer) -> void:
	var details_container = PanelContainer.new()
	details_container.custom_minimum_size = Vector2(280, 0)
	parent.add_child(details_container)

	item_details_panel = VBoxContainer.new()
	item_details_panel.add_theme_constant_override("separation", 8)
	details_container.add_child(item_details_panel)

	# Title
	var details_title = Label.new()
	details_title.text = "ITEM DETAILS"
	details_title.add_theme_font_size_override("font_size", 14)
	details_title.add_theme_color_override("font_color", Color.YELLOW)
	item_details_panel.add_child(details_title)

	var separator = HSeparator.new()
	item_details_panel.add_child(separator)

	# Placeholder when nothing selected
	var placeholder = Label.new()
	placeholder.text = "Select an item to view details"
	placeholder.custom_minimum_size = Vector2(0, 200)
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.add_theme_color_override("font_color", Color.GRAY)
	item_details_panel.add_child(placeholder)
	item_details_panel.set_meta("placeholder", placeholder)


func _setup_action_buttons(parent: VBoxContainer) -> void:
	action_buttons_container = HBoxContainer.new()
	action_buttons_container.add_theme_constant_override("separation", 10)
	parent.add_child(action_buttons_container)

	var unequip_btn = Button.new()
	unequip_btn.text = "Unequip"
	unequip_btn.custom_minimum_size = Vector2(100, 35)
	unequip_btn.pressed.connect(_on_unequip_pressed)
	action_buttons_container.add_child(unequip_btn)
	action_buttons_container.set_meta("unequip_btn", unequip_btn)

	var compare_btn = Button.new()
	compare_btn.text = "Compare"
	compare_btn.custom_minimum_size = Vector2(100, 35)
	compare_btn.pressed.connect(_on_compare_pressed)
	action_buttons_container.add_child(compare_btn)
	action_buttons_container.set_meta("compare_btn", compare_btn)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_buttons_container.add_child(spacer)


func set_heir_equipment(equipment: HeirEquipment) -> void:
	"""Set the data source and refresh display"""
	heir_equipment = equipment
	heir = equipment.heir
	refresh_equipment_display()


func refresh_equipment_display() -> void:
	"""Rebuild slot display with current equipment and update stats/resistances"""
	_update_slot_displays()
	update_stat_display()
	update_resistance_display()


func _update_slot_displays() -> void:
	"""Update each equipment slot button with current item"""
	for slot in slot_order:
		var equipped_item = heir_equipment.get_equipped(slot)
		var slot_info = slot_buttons[slot]

		if equipped_item and equipped_item is Equipment:
			var equipment = equipped_item as Equipment
			var rarity_color = _get_rarity_color(equipment.rarity)

			slot_info["item_label"].text = equipment.name
			slot_info["item_label"].add_theme_color_override("font_color", rarity_color)

			# Set container border color based on rarity
			if slot_info["container"].has_theme_stylebox_override("panel"):
				var style = slot_info["container"].get_theme_stylebox("panel").duplicate()
				# This is simplified; a full implementation would create custom styles
			else:
				pass
		else:
			slot_info["item_label"].text = "—"
			slot_info["item_label"].remove_theme_color_override("font_color")

		# Highlight selected slot
		if slot == selected_slot:
			slot_info["button"].add_theme_color_override("font_color", Color.YELLOW)
		else:
			slot_info["button"].remove_theme_color_override("font_color")


func update_stat_display() -> void:
	"""Recalculate and display all stat bonuses with format: 'BASE → TOTAL (+BONUS)'"""
	var base_stats = heir.stats
	var bonuses = heir_equipment.get_total_stat_bonuses()

	var stat_keys = ["strength", "dexterity", "constitution", "intelligence", "wisdom", "charisma"]

	for stat_key in stat_keys:
		if stat_key not in stat_labels:
			continue

		var base_value = base_stats.get(stat_key, 10)
		var bonus = bonuses.get(stat_key, 0)
		var total_value = base_value + bonus

		var label = stat_labels[stat_key]
		var text = "%d → %d" % [base_value, total_value]

		if bonus > 0:
			text += " (+%d)" % bonus
			label.add_theme_color_override("font_color", Color.GREEN)
		elif bonus < 0:
			text += " (%d)" % bonus
			label.add_theme_color_override("font_color", Color.RED)
		else:
			text += " (+0)"
			label.remove_theme_color_override("font_color")

		label.text = text


func update_resistance_display() -> void:
	"""Recalculate and display elemental resistances with visual bars"""
	var resistances = heir_equipment.get_total_resistances()

	var resistance_types = ["fire", "cold", "lightning", "poison", "magic"]

	for res_type in resistance_types:
		if res_type not in resistance_labels:
			continue

		var resistance_value = resistances.get(res_type, 0)
		resistance_value = clampi(resistance_value, 0, 100)

		var res_info = resistance_labels[res_type]
		var label = res_info["label"]
		var bar_fill = res_info["bar_fill"]

		# Update label
		label.text = "%d%%" % resistance_value

		# Update bar color and width based on resistance value
		var bar_color = _get_resistance_color(resistance_value)
		bar_fill.color = bar_color

		# Set bar fill ratio
		bar_fill.anchor_right = resistance_value / 100.0

		# Color code the percentage text
		if resistance_value >= 15:
			label.add_theme_color_override("font_color", Color.GREEN)
		elif resistance_value >= 5:
			label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			label.add_theme_color_override("font_color", Color.RED)


func _on_slot_button_pressed(slot: int) -> void:
	"""Handle equipment slot selection"""
	var equipped_item = heir_equipment.get_equipped(slot)

	selected_slot = slot
	selected_item = equipped_item as Equipment

	_update_slot_displays()
	_display_item_details(selected_item)


func _display_item_details(item: Equipment) -> void:
	"""Display selected item details in the details panel"""
	# Clear existing details
	var children = item_details_panel.get_children()
	for child in children:
		if child.get_meta("placeholder", null) == null and child is not Label and child is not HSeparator:
			child.queue_free()

	if not item:
		# Show placeholder
		if item_details_panel.has_meta("placeholder"):
			item_details_panel.get_meta("placeholder").show()
		return

	if item_details_panel.has_meta("placeholder"):
		item_details_panel.get_meta("placeholder").hide()

	# Item name and rarity
	var name_label = Label.new()
	name_label.text = "%s [%s]" % [item.name, _get_rarity_name(item.rarity)]
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", _get_rarity_color(item.rarity))
	item_details_panel.add_child(name_label)

	# Slot
	var slot_label = Label.new()
	slot_label.text = "Slot: %s" % item.get_slot_name()
	slot_label.add_theme_font_size_override("font_size", 10)
	item_details_panel.add_child(slot_label)

	# Level requirement
	if item.required_level > 1:
		var level_label = Label.new()
		level_label.text = "Required: Level %d" % item.required_level
		level_label.add_theme_font_size_override("font_size", 10)

		if heir.generation >= item.required_level:
			level_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			level_label.add_theme_color_override("font_color", Color.RED)

		item_details_panel.add_child(level_label)

	# Stats section
	var has_bonuses = false
	for stat in item.stat_bonuses:
		if item.stat_bonuses[stat] != 0:
			has_bonuses = true
			break

	if has_bonuses:
		var stats_label = Label.new()
		stats_label.text = "STATS"
		stats_label.add_theme_font_size_override("font_size", 11)
		stats_label.add_theme_color_override("font_color", Color.YELLOW)
		item_details_panel.add_child(stats_label)

		for stat in item.stat_bonuses:
			if item.stat_bonuses[stat] != 0:
				var stat_label = Label.new()
				var prefix = "+" if item.stat_bonuses[stat] > 0 else ""
				stat_label.text = "  %s %s%d" % [stat.capitalize(), prefix, item.stat_bonuses[stat]]
				stat_label.add_theme_font_size_override("font_size", 10)

				if item.stat_bonuses[stat] > 0:
					stat_label.add_theme_color_override("font_color", Color.GREEN)
				else:
					stat_label.add_theme_color_override("font_color", Color.RED)

				item_details_panel.add_child(stat_label)

	# Resistances section
	var has_resistances = false
	for res_type in item.resistances:
		if item.resistances[res_type] != 0:
			has_resistances = true
			break

	if has_resistances:
		var resist_label = Label.new()
		resist_label.text = "RESISTANCES"
		resist_label.add_theme_font_size_override("font_size", 11)
		resist_label.add_theme_color_override("font_color", Color.YELLOW)
		item_details_panel.add_child(resist_label)

		for res_type in item.resistances:
			if item.resistances[res_type] != 0:
				var res_label = Label.new()
				res_label.text = "  %s +%d%%" % [res_type.capitalize(), item.resistances[res_type]]
				res_label.add_theme_font_size_override("font_size", 10)
				res_label.add_theme_color_override("font_color", Color.GREEN)
				item_details_panel.add_child(res_label)

	# Description
	if item.description != "":
		var sep = HSeparator.new()
		item_details_panel.add_child(sep)

		var desc_label = Label.new()
		desc_label.text = item.description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_label.custom_minimum_size = Vector2(260, 0)
		desc_label.add_theme_font_size_override("font_size", 9)
		desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		item_details_panel.add_child(desc_label)

	# Value
	var value_label = Label.new()
	value_label.text = "Value: %s" % item.value.to_string()
	value_label.add_theme_font_size_override("font_size", 9)
	item_details_panel.add_child(value_label)


func _on_unequip_pressed() -> void:
	"""Unequip selected item"""
	if selected_slot < 0 or not selected_item:
		return

	heir_equipment.unequip_item(selected_slot)
	selected_slot = -1
	selected_item = null

	refresh_equipment_display()
	_display_item_details(null)


func _on_compare_pressed() -> void:
	"""Compare selected item with alternative items (placeholder for future inventory comparison)"""
	if not selected_item:
		return

	# TODO: Implement comparison with inventory items
	# This would open a comparison panel showing differences
	print("Comparison feature: %s" % selected_item.name)


func _on_close_pressed() -> void:
	"""Close equipment screen and return to previous screen"""
	queue_free()


## Helper function: Get rarity color
func _get_rarity_color(rarity: int) -> Color:
	match rarity:
		Item.Rarity.LEGENDARY:
			return Color.GOLD
		Item.Rarity.VERY_RARE:
			return Color.MAGENTA
		Item.Rarity.RARE:
			return Color.CORNFLOWER_BLUE
		Item.Rarity.UNCOMMON:
			return Color.GREEN
		Item.Rarity.COMMON:
			return Color.WHITE
		_:
			return Color.GRAY


## Helper function: Get rarity name
func _get_rarity_name(rarity: int) -> String:
	match rarity:
		Item.Rarity.LEGENDARY:
			return "Legendary"
		Item.Rarity.VERY_RARE:
			return "Very Rare"
		Item.Rarity.RARE:
			return "Rare"
		Item.Rarity.UNCOMMON:
			return "Uncommon"
		Item.Rarity.COMMON:
			return "Common"
		_:
			return "Unknown"


## Helper function: Get resistance bar color based on percentage
func _get_resistance_color(resistance_value: int) -> Color:
	if resistance_value >= 15:
		return Color.GREEN
	elif resistance_value >= 5:
		return Color.YELLOW
	else:
		return Color.RED


func _input(event: InputEvent) -> void:
	"""Handle input - close on ESC"""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_close_pressed()
			get_tree().root.set_input_as_handled()
