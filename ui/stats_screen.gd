## Stats Screen: Displays comprehensive heir information
##
## Shows stats, skills, traits, equipment, transformations, age, and progression

extends Control

class_name StatsScreen


signal stat_view_changed(view_type: String)
signal equipment_slot_selected(slot: int)


enum ViewType { STATS, SKILLS, TRAITS, EQUIPMENT, TRANSFORMATIONS, PROGRESSION }

# UI elements
var view_tabs: TabBar
var content_panel: PanelContainer
var stat_display: VBoxContainer
var scroll_container: ScrollContainer

# Current data
var heir_data: Dictionary = {}
var current_view: int = ViewType.STATS

# References
var age_progression_system: Object
var corruption_system: Object
var blessing_system: Object
var curse_system: Object


func _ready() -> void:
	_setup_stats_ui()


func _setup_stats_ui() -> void:
	var main_container = VBoxContainer.new()
	main_container.anchor_left = 0.0
	main_container.anchor_top = 0.0
	main_container.anchor_right = 1.0
	main_container.anchor_bottom = 1.0
	add_child(main_container)

	# Create tabs
	view_tabs = TabBar.new()
	view_tabs.add_tab("Stats")
	view_tabs.add_tab("Skills")
	view_tabs.add_tab("Traits")
	view_tabs.add_tab("Equipment")
	view_tabs.add_tab("Transformations")
	view_tabs.add_tab("Progression")
	view_tabs.tab_changed.connect(_on_tab_changed)
	main_container.add_child(view_tabs)

	# Content area with scroll
	scroll_container = ScrollContainer.new()
	scroll_container.custom_minimum_size = Vector2(0, 400)
	main_container.add_child(scroll_container)

	content_panel = PanelContainer.new()
	scroll_container.add_child(content_panel)

	stat_display = VBoxContainer.new()
	content_panel.add_child(stat_display)


## Initialize with heir data
func initialize_heir_stats(heir_name: String, heir: Dictionary) -> void:
	heir_data = heir.duplicate()
	heir_data["name"] = heir_name
	_display_current_view()


## Display current view
func _display_current_view() -> void:
	# Clear display
	for child in stat_display.get_children():
		child.queue_free()

	match current_view:
		ViewType.STATS:
			_display_stats_view()
		ViewType.SKILLS:
			_display_skills_view()
		ViewType.TRAITS:
			_display_traits_view()
		ViewType.EQUIPMENT:
			_display_equipment_view()
		ViewType.TRANSFORMATIONS:
			_display_transformations_view()
		ViewType.PROGRESSION:
			_display_progression_view()


## Display stats view (primary attributes)
func _display_stats_view() -> void:
	# Title
	var title = Label.new()
	title.text = "Attributes"
	title.add_theme_font_size_override("font_size", 18)
	stat_display.add_child(title)

	# Core stats
	var stats_to_display = [
		"strength",
		"dexterity",
		"constitution",
		"intelligence",
		"wisdom",
		"charisma",
	]

	for stat in stats_to_display:
		var stat_value = heir_data.get(stat, 0)
		var stat_label = Label.new()
		stat_label.text = "%s: %d" % [stat.capitalize(), stat_value]
		stat_display.add_child(stat_label)

		# Progress bar
		var progress = ProgressBar.new()
		progress.min_value = 0
		progress.max_value = 20
		progress.value = stat_value
		progress.custom_minimum_size = Vector2(0, 20)
		stat_display.add_child(progress)


## Display skills view (crafting, combat, etc.)
func _display_skills_view() -> void:
	var title = Label.new()
	title.text = "Skills"
	title.add_theme_font_size_override("font_size", 18)
	stat_display.add_child(title)

	var skills = heir_data.get("skills", {})

	if skills.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No skills learned"
		stat_display.add_child(empty_label)
		return

	for skill_name in skills.keys():
		var skill_data = skills[skill_name]

		var skill_label = Label.new()
		skill_label.text = "%s - Level %d" % [skill_name, skill_data.get("level", 1)]
		stat_display.add_child(skill_label)

		var xp_progress = ProgressBar.new()
		xp_progress.min_value = 0
		xp_progress.max_value = 100
		xp_progress.value = skill_data.get("xp", 0)
		xp_progress.custom_minimum_size = Vector2(0, 15)
		stat_display.add_child(xp_progress)


## Display traits view (bloodline, acquired, curses, blessings)
func _display_traits_view() -> void:
	var title = Label.new()
	title.text = "Traits & Conditions"
	title.add_theme_font_size_override("font_size", 18)
	stat_display.add_child(title)

	# Bloodline traits
	var bloodline = heir_data.get("bloodline_traits", [])
	if not bloodline.is_empty():
		var bloodline_label = Label.new()
		bloodline_label.text = "Bloodline:"
		bloodline_label.add_theme_font_size_override("font_size", 14)
		stat_display.add_child(bloodline_label)

		for trait in bloodline:
			var trait_label = Label.new()
			trait_label.text = "  • %s" % trait
			stat_display.add_child(trait_label)

	# Acquired traits
	var acquired = heir_data.get("acquired_traits", [])
	if not acquired.is_empty():
		var acquired_label = Label.new()
		acquired_label.text = "Acquired:"
		acquired_label.add_theme_font_size_override("font_size", 14)
		stat_display.add_child(acquired_label)

		for trait in acquired:
			var trait_label = Label.new()
			trait_label.text = "  • %s" % trait
			stat_display.add_child(trait_label)


## Display equipment view (equipped items and vault)
func _display_equipment_view() -> void:
	var title = Label.new()
	title.text = "Equipment"
	title.add_theme_font_size_override("font_size", 18)
	stat_display.add_child(title)

	var equipped = heir_data.get("equipped", {})

	if equipped.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No equipment equipped"
		stat_display.add_child(empty_label)
		return

	for slot_name in equipped.keys():
		var item = equipped[slot_name]

		var item_button = Button.new()
		item_button.text = "%s: %s (%s)" % [slot_name, item["name"], item["rarity"]]
		item_button.pressed.connect(_on_equipment_slot_selected.bind(slot_name))
		stat_display.add_child(item_button)

		# Item stats
		var stats_label = Label.new()
		var stat_text = "  Stats: "
		for stat_key in item["stats"].keys():
			stat_text += "%s +%d  " % [stat_key.capitalize(), item["stats"][stat_key]]
		stats_label.text = stat_text
		stat_display.add_child(stats_label)


## Display transformations view (corruption, curses, blessings, evolution)
func _display_transformations_view() -> void:
	var title = Label.new()
	title.text = "Transformations & Conditions"
	title.add_theme_font_size_override("font_size", 18)
	stat_display.add_child(title)

	# Corruption
	var corruption = heir_data.get("corruption_level", 0)
	var corruption_label = Label.new()
	corruption_label.text = "Corruption: %d/100" % corruption
	stat_display.add_child(corruption_label)

	var corruption_bar = ProgressBar.new()
	corruption_bar.min_value = 0
	corruption_bar.max_value = 100
	corruption_bar.value = corruption
	corruption_bar.custom_minimum_size = Vector2(0, 20)
	corruption_bar.modulate = Color.BLACK
	stat_display.add_child(corruption_bar)

	# Curses
	var curses = heir_data.get("curses", [])
	if not curses.is_empty():
		var curses_label = Label.new()
		curses_label.text = "Curses:"
		curses_label.add_theme_font_size_override("font_size", 14)
		stat_display.add_child(curses_label)

		for curse in curses:
			var curse_label = Label.new()
			curse_label.text = "  • %s" % curse
			curse_label.modulate = Color.DARK_RED
			stat_display.add_child(curse_label)

	# Blessings
	var blessings = heir_data.get("blessings", [])
	if not blessings.is_empty():
		var blessings_label = Label.new()
		blessings_label.text = "Blessings:"
		blessings_label.add_theme_font_size_override("font_size", 14)
		stat_display.add_child(blessings_label)

		for blessing in blessings:
			var blessing_label = Label.new()
			blessing_label.text = "  • %s" % blessing
			blessing_label.modulate = Color.GOLD
			stat_display.add_child(blessing_label)

	# Class evolution
	var class_name = heir_data.get("class", "")
	var evolved_class = heir_data.get("evolved_class", "")

	var class_label = Label.new()
	if evolved_class:
		class_label.text = "Class: %s → %s" % [class_name, evolved_class]
	else:
		class_label.text = "Class: %s" % class_name
	class_label.add_theme_font_size_override("font_size", 14)
	stat_display.add_child(class_label)


## Display progression view (age, experience, legacy)
func _display_progression_view() -> void:
	var title = Label.new()
	title.text = "Progression"
	title.add_theme_font_size_override("font_size", 18)
	stat_display.add_child(title)

	# Age
	var age = heir_data.get("age", 0)
	var age_label = Label.new()
	age_label.text = "Age: %d years" % age
	stat_display.add_child(age_label)

	# Life stage
	var life_stage = heir_data.get("life_stage", "Youth")
	var stage_label = Label.new()
	stage_label.text = "Life Stage: %s" % life_stage
	stat_display.add_child(stage_label)

	# Experience
	var experience = heir_data.get("experience", 0)
	var exp_label = Label.new()
	exp_label.text = "Total Experience: %d" % experience
	stat_display.add_child(exp_label)

	# Legacy value
	var legacy = heir_data.get("legacy_value", 0)
	var legacy_label = Label.new()
	legacy_label.text = "Legacy Value: %d" % legacy
	stat_display.add_child(legacy_label)

	# Generation
	var generation = heir_data.get("generation", 1)
	var gen_label = Label.new()
	gen_label.text = "Generation: %d" % generation
	stat_display.add_child(gen_label)


## Handle tab change
func _on_tab_changed(tab_index: int) -> void:
	current_view = tab_index
	_display_current_view()
	stat_view_changed.emit(ViewType.keys()[tab_index])


## Handle equipment slot selection
func _on_equipment_slot_selected(slot: String) -> void:
	equipment_slot_selected.emit(slot)


## Update heir stats (live updates)
func update_heir_stats(heir: Dictionary) -> void:
	heir_data.merge(heir)
	_display_current_view()


## Get current view type
func get_current_view() -> int:
	return current_view
