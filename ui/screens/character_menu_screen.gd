## Character menu screen: character sheet, inventory, equipment
##
## Shows current heir's stats, traits, equipment, and inventory

extends Control

class_name CharacterMenuScreen


var heir: Heir


func _init(current_heir: Heir) -> void:
	heir = current_heir


func _ready() -> void:
	# Setup background with semi-transparent overlay
	var bg = ColorRect.new()
	bg.color = Color.BLACK.with_alpha(0.8)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Main panel
	var panel = PanelContainer.new()
	panel.anchor_left = 0.1
	panel.anchor_top = 0.1
	panel.anchor_right = 0.9
	panel.anchor_bottom = 0.9
	add_child(panel)

	var main_hbox = HBoxContainer.new()
	panel.add_child(main_hbox)

	# Left side - Character Info
	var char_panel = VBoxContainer.new()
	char_panel.custom_minimum_size = Vector2(300, 0)
	main_hbox.add_child(char_panel)

	var char_title = Label.new()
	char_title.text = "Character"
	char_title.add_theme_font_size_override("font_size", 20)
	char_panel.add_child(char_title)

	var name_label = Label.new()
	name_label.text = "Name: %s" % heir.name
	char_panel.add_child(name_label)

	var class_label = Label.new()
	class_label.text = "Class: %s" % heir.class_id
	char_panel.add_child(class_label)

	var job_label = Label.new()
	job_label.text = "Job: %s" % heir.job_id
	char_panel.add_child(job_label)

	var gen_label = Label.new()
	gen_label.text = "Generation: %d" % heir.generation
	char_panel.add_child(gen_label)

	# Stats section
	var stats_title = Label.new()
	stats_title.text = "Stats"
	stats_title.add_theme_font_size_override("font_size", 16)
	char_panel.add_child(stats_title)

	var stats = ["Strength", "Constitution", "Dexterity", "Intelligence", "Wisdom", "Charisma"]
	for stat in stats:
		var stat_label = Label.new()
		stat_label.text = "%s: 10" % stat
		char_panel.add_child(stat_label)

	# Center - Traits and Skills
	var center_vbox = VBoxContainer.new()
	center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(center_vbox)

	var traits_title = Label.new()
	traits_title.text = "Traits"
	traits_title.add_theme_font_size_override("font_size", 20)
	center_vbox.add_child(traits_title)

	var traits_list = ItemList.new()
	traits_list.custom_minimum_size = Vector2(0, 200)
	for trait in heir.traits:
		traits_list.add_item(trait)
	center_vbox.add_child(traits_list)

	var skills_title = Label.new()
	skills_title.text = "Skills"
	skills_title.add_theme_font_size_override("font_size", 16)
	center_vbox.add_child(skills_title)

	var skills_list = ItemList.new()
	skills_list.custom_minimum_size = Vector2(0, 150)
	skills_list.add_item("Attack")
	skills_list.add_item("Defend")
	skills_list.add_item("Dodge")
	center_vbox.add_child(skills_list)

	# Right side - Inventory
	var inv_panel = VBoxContainer.new()
	inv_panel.custom_minimum_size = Vector2(300, 0)
	main_hbox.add_child(inv_panel)

	var inv_title = Label.new()
	inv_title.text = "Inventory"
	inv_title.add_theme_font_size_override("font_size", 20)
	inv_panel.add_child(inv_title)

	var inv_list = ItemList.new()
	inv_list.custom_minimum_size = Vector2(0, 300)
	inv_list.add_item("Health Potion x5")
	inv_list.add_item("Mana Potion x2")
	inv_list.add_item("Ancient Rune")
	inv_panel.add_child(inv_list)

	var equip_title = Label.new()
	equip_title.text = "Equipment"
	equip_title.add_theme_font_size_override("font_size", 16)
	inv_panel.add_child(equip_title)

	var equip_list = ItemList.new()
	equip_list.custom_minimum_size = Vector2(0, 150)
	equip_list.add_item("Sword of Honor")
	equip_list.add_item("Iron Armor")
	equip_list.add_item("Shield of Warding")
	inv_panel.add_child(equip_list)

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


func _on_close() -> void:
	var main_game = get_tree().root.get_child(0)
	main_game.show_screen("world")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_I:
			_on_close()
