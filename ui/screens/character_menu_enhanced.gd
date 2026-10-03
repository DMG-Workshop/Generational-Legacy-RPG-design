## Enhanced character menu screen with tabs, skills, and family tree
##
## Tabbed interface showing character stats, skills, inventory, and family tree

extends Control

class_name CharacterMenuEnhanced


var heir: Heir
var lineage: Lineage
var npc_system: NPCSystem
var current_tab: String = "character"
var tab_content_container: Control


func _init(current_heir: Heir, p_lineage: Lineage = null, p_npc_system: NPCSystem = null) -> void:
	heir = current_heir
	lineage = p_lineage
	npc_system = p_npc_system


func _ready() -> void:
	# Background overlay
	var bg = ColorRect.new()
	bg.color = Color.BLACK.with_alpha(0.8)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Main panel with VBox
	var panel = PanelContainer.new()
	panel.anchor_left = 0.05
	panel.anchor_top = 0.05
	panel.anchor_right = 0.95
	panel.anchor_bottom = 0.95
	add_child(panel)

	var main_vbox = VBoxContainer.new()
	panel.add_child(main_vbox)

	# Header
	var header = Label.new()
	header.text = "Character: %s (Generation %d)" % [heir.name, heir.generation]
	header.add_theme_font_size_override("font_size", 20)
	main_vbox.add_child(header)

	# Tab buttons
	var tabs_hbox = HBoxContainer.new()
	main_vbox.add_child(tabs_hbox)

	var char_tab = Button.new()
	char_tab.text = "Character"
	char_tab.toggle_mode = true
	char_tab.button_pressed = true
	char_tab.pressed.connect(_on_tab_selected.bind("character", char_tab))
	tabs_hbox.add_child(char_tab)

	var skills_tab = Button.new()
	skills_tab.text = "Skills"
	skills_tab.toggle_mode = true
	skills_tab.pressed.connect(_on_tab_selected.bind("skills", skills_tab))
	tabs_hbox.add_child(skills_tab)

	var family_tab = Button.new()
	family_tab.text = "Family"
	family_tab.toggle_mode = true
	family_tab.pressed.connect(_on_tab_selected.bind("family", family_tab))
	tabs_hbox.add_child(family_tab)

	var inv_tab = Button.new()
	inv_tab.text = "Inventory"
	inv_tab.toggle_mode = true
	inv_tab.pressed.connect(_on_tab_selected.bind("inventory", inv_tab))
	tabs_hbox.add_child(inv_tab)

	# Tab content area
	tab_content_container = Control.new()
	tab_content_container.custom_minimum_size = Vector2(0, 500)
	main_vbox.add_child(tab_content_container)

	# Show character tab by default
	_update_tab_content()

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close (ESC)"
	close_btn.anchor_left = 0.5
	close_btn.anchor_top = 1.0
	close_btn.anchor_right = 0.5
	close_btn.anchor_bottom = 1.0
	close_btn.offset_left = -50
	close_btn.offset_top = -40
	close_btn.custom_minimum_size = Vector2(100, 30)
	close_btn.pressed.connect(_on_close)
	add_child(close_btn)


func _on_tab_selected(tab_name: String, button: Button) -> void:
	current_tab = tab_name

	# Deselect other tabs (toggle buttons)
	for child in button.get_parent().get_children():
		if child != button and child is Button:
			child.button_pressed = false

	_update_tab_content()


func _update_tab_content() -> void:
	# Clear container
	for child in tab_content_container.get_children():
		child.queue_free()

	match current_tab:
		"character":
			_show_character_tab()
		"skills":
			_show_skills_tab()
		"family":
			_show_family_tab()
		"inventory":
			_show_inventory_tab()


func _show_character_tab() -> void:
	var vbox = VBoxContainer.new()
	tab_content_container.add_child(vbox)

	# Stats section
	var stats_label = Label.new()
	stats_label.text = "Stats"
	stats_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(stats_label)

	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	vbox.add_child(stats_grid)

	var stats = {
		"Strength": 15,
		"Constitution": 12,
		"Dexterity": 14,
		"Intelligence": 13,
		"Wisdom": 11,
		"Charisma": 10
	}

	for stat_name in stats:
		var name_label = Label.new()
		name_label.text = stat_name + ":"
		stats_grid.add_child(name_label)

		var value_label = Label.new()
		value_label.text = str(stats[stat_name])
		stats_grid.add_child(value_label)

	# Traits section
	var traits_label = Label.new()
	traits_label.text = "Traits"
	traits_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(traits_label)

	var traits_list = ItemList.new()
	for trait in heir.traits:
		traits_list.add_item(trait)
	traits_list.custom_minimum_size = Vector2(0, 150)
	vbox.add_child(traits_list)


func _show_skills_tab() -> void:
	var skill_tree = SkillTree.new(heir)
	tab_content_container.add_child(skill_tree)


func _show_family_tab() -> void:
	if lineage and npc_system:
		var family_tree = FamilyTreeBrowser.new(lineage, heir, npc_system)
		tab_content_container.add_child(family_tree)
	else:
		var label = Label.new()
		label.text = "Family tree data not available"
		tab_content_container.add_child(label)


func _show_inventory_tab() -> void:
	var vbox = VBoxContainer.new()
	tab_content_container.add_child(vbox)

	# Inventory section
	var inv_label = Label.new()
	inv_label.text = "Inventory"
	inv_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(inv_label)

	var inv_list = ItemList.new()
	inv_list.add_item("Health Potion x5")
	inv_list.add_item("Mana Potion x2")
	inv_list.add_item("Ancient Rune")
	inv_list.custom_minimum_size = Vector2(0, 200)
	vbox.add_child(inv_list)

	# Equipment section
	var equip_label = Label.new()
	equip_label.text = "Equipment"
	equip_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(equip_label)

	var equip_list = ItemList.new()
	equip_list.add_item("Sword of Honor (Equipped)")
	equip_list.add_item("Iron Armor (Equipped)")
	equip_list.add_item("Shield of Warding (Equipped)")
	equip_list.add_item("Ancient Ring (Available)")
	equip_list.custom_minimum_size = Vector2(0, 150)
	vbox.add_child(equip_list)


func _on_close() -> void:
	var main_game = get_tree().root.get_child(0)
	main_game.show_screen("world")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_I:
			_on_close()
