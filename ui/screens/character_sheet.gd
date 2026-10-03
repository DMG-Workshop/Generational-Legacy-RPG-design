# Character Sheet UI - Comprehensive heir information display
# Displays integrated stats, skills, traits, and legacy information
# Godot 4 Control node - production ready

extends Control

class_name CharacterSheet

# Data source
var current_heir: Heir

# UI Component References
var header_panel: PanelContainer
var stats_panel: PanelContainer
var skills_panel: PanelContainer
var traits_panel: PanelContainer
var legacy_panel: PanelContainer
var nav_buttons: HBoxContainer

# Header labels
var name_label: Label
var gen_year_label: Label
var class_label: Label
var archetype_label: Label
var bloodline_label: Label

# Stats display
var stats_container: VBoxContainer
var stat_labels: Dictionary = {}  # "STR" -> Label
var health_label: Label
var mana_label: Label

# Skills display
var skills_container: VBoxContainer
var skills_list: VBoxContainer
var skill_filter_buttons: HBoxContainer
var current_skill_filter: String = "all"  # "all", "crafting", "combat"

# Traits display
var traits_container: VBoxContainer
var traits_by_type: Dictionary = {}  # "BLOODLINE" -> VBoxContainer

# Legacy display
var legacy_container: VBoxContainer
var parents_label: Label
var spouse_label: Label
var children_label: Label
var reputation_label: Label
var legacy_summary_label: Label

# Styling constants
const STAT_COLOR_LOW = Color(0.8, 0.3, 0.3)      # Red-ish
const STAT_COLOR_MEDIUM = Color(0.9, 0.9, 0.3)  # Yellow-ish
const STAT_COLOR_GOOD = Color(0.3, 0.8, 0.3)    # Green-ish
const STAT_COLOR_EXCELLENT = Color(0.3, 0.8, 0.9) # Cyan

const TRAIT_COLOR_BLOODLINE = Color(0.3, 0.5, 0.9)  # Blue
const TRAIT_COLOR_ACQUIRED = Color(0.3, 0.8, 0.3)   # Green
const TRAIT_COLOR_CURSE = Color(0.9, 0.3, 0.3)      # Red
const TRAIT_COLOR_BLESSING = Color(0.9, 0.8, 0.3)   # Gold

const SKILL_COLOR_LOW = Color(0.4, 0.4, 0.4)    # Dark gray
const SKILL_COLOR_MID = Color(0.3, 0.7, 0.3)    # Green
const SKILL_COLOR_HIGH = Color(0.9, 0.8, 0.3)   # Gold

const PANEL_MARGIN = 10
const SECTION_SPACING = 15


func _ready() -> void:
	"""Initialize UI panels and setup all components."""
	setup_ui_layout()
	setup_styling()


func setup_ui_layout() -> void:
	"""Create and organize all UI panels."""
	var main_container = VBoxContainer.new()
	main_container.anchor_left = 0.0
	main_container.anchor_top = 0.0
	main_container.anchor_right = 1.0
	main_container.anchor_bottom = 1.0
	add_child(main_container)

	# ===== HEADER SECTION =====
	header_panel = create_panel("Header")
	var header_vbox = VBoxContainer.new()

	name_label = Label.new()
	name_label.text = "Character Name"
	name_label.add_theme_font_size_override("font_size", 24)
	header_vbox.add_child(name_label)

	gen_year_label = Label.new()
	gen_year_label.text = "Generation 5 | Year 847"
	gen_year_label.add_theme_font_size_override("font_size", 14)
	header_vbox.add_child(gen_year_label)

	var class_info_hbox = HBoxContainer.new()
	class_info_hbox.add_theme_constant_override("separation", 10)

	class_label = create_badge("Class: Warrior")
	class_info_hbox.add_child(class_label)

	archetype_label = create_badge("Archetype: Berserker")
	class_info_hbox.add_child(archetype_label)

	bloodline_label = create_badge("Bloodline: Ironborn")
	class_info_hbox.add_child(bloodline_label)

	header_vbox.add_child(class_info_hbox)
	header_panel.add_child(header_vbox)
	main_container.add_child(header_panel)

	# ===== STATS & SKILLS ROW =====
	var content_hbox = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 15)
	content_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Stats Panel (left side)
	stats_panel = create_panel("Core Stats")
	stats_container = VBoxContainer.new()

	# Create stat labels for STR, DEX, CON, INT, WIS, CHA
	for stat in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
		var stat_label = Label.new()
		stat_label.text = "%s: --" % stat
		stat_label.add_theme_font_size_override("font_size", 16)
		stats_container.add_child(stat_label)
		stat_labels[stat] = stat_label

	stats_container.add_child(create_separator())

	health_label = Label.new()
	health_label.text = "Health: --/--"
	health_label.add_theme_font_size_override("font_size", 14)
	stats_container.add_child(health_label)

	mana_label = Label.new()
	mana_label.text = "Mana: --/--"
	mana_label.add_theme_font_size_override("font_size", 14)
	stats_container.add_child(mana_label)

	stats_panel.add_child(stats_container)
	content_hbox.add_child(stats_panel)

	# Skills Panel (right side)
	skills_panel = create_panel("Skills & Progression")
	var skills_vbox = VBoxContainer.new()

	# Skill filter buttons
	skill_filter_buttons = HBoxContainer.new()
	skill_filter_buttons.add_theme_constant_override("separation", 5)
	for filter_name in ["all", "crafting", "combat"]:
		var btn = Button.new()
		btn.text = filter_name.to_upper()
		btn.pressed.connect(_on_skill_filter.bindv([filter_name]))
		skill_filter_buttons.add_child(btn)
	skills_vbox.add_child(skill_filter_buttons)

	skills_container = VBoxContainer.new()
	skills_container.add_theme_constant_override("separation", 8)
	skills_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skills_list = VBoxContainer.new()
	skills_container.add_child(skills_list)
	skills_vbox.add_child(skills_container)

	skills_panel.add_child(skills_vbox)
	content_hbox.add_child(skills_panel)

	main_container.add_child(content_hbox)

	# ===== TRAITS SECTION =====
	traits_panel = create_panel("Traits")
	traits_container = VBoxContainer.new()
	traits_container.add_theme_constant_override("separation", 10)

	# Create containers for each trait type
	for trait_type in ["BLOODLINE", "ACQUIRED", "CURSE", "BLESSING"]:
		var trait_type_vbox = VBoxContainer.new()
		trait_type_vbox.add_theme_constant_override("separation", 5)
		traits_by_type[trait_type] = trait_type_vbox
		traits_container.add_child(trait_type_vbox)

	traits_panel.add_child(traits_container)
	main_container.add_child(traits_panel)

	# ===== LEGACY SECTION =====
	legacy_panel = create_panel("Legacy & Relationships")
	legacy_container = VBoxContainer.new()
	legacy_container.add_theme_constant_override("separation", 8)

	parents_label = Label.new()
	parents_label.text = "Parents: [Unknown]"
	parents_label.add_theme_font_size_override("font_size", 12)
	legacy_container.add_child(parents_label)

	spouse_label = Label.new()
	spouse_label.text = "Spouse: [None]"
	spouse_label.add_theme_font_size_override("font_size", 12)
	legacy_container.add_child(spouse_label)

	children_label = Label.new()
	children_label.text = "Children: 0"
	children_label.add_theme_font_size_override("font_size", 12)
	legacy_container.add_child(children_label)

	reputation_label = Label.new()
	reputation_label.text = "Reputation: [Loading...]"
	reputation_label.add_theme_font_size_override("font_size", 12)
	legacy_container.add_child(reputation_label)

	legacy_summary_label = Label.new()
	legacy_summary_label.text = "Legacy: [No achievements yet]"
	legacy_summary_label.add_theme_font_size_override("font_size", 12)
	legacy_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	legacy_container.add_child(legacy_summary_label)

	legacy_panel.add_child(legacy_container)
	main_container.add_child(legacy_panel)

	# ===== NAVIGATION BUTTONS =====
	nav_buttons = HBoxContainer.new()
	nav_buttons.add_theme_constant_override("separation", 10)
	nav_buttons.alignment = BoxContainer.ALIGNMENT_CENTER

	for tab_name in ["Inventory", "Equipment", "Crafting", "Family Tree"]:
		var btn = Button.new()
		btn.text = tab_name
		btn.pressed.connect(_on_navigation_tab.bindv([tab_name]))
		nav_buttons.add_child(btn)

	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.pressed.connect(_on_back_pressed)
	nav_buttons.add_child(back_btn)

	main_container.add_child(nav_buttons)


func setup_styling() -> void:
	"""Apply consistent styling to all panels."""
	var panel_style = StyleBox.new()
	# Basic styling - can be enhanced with actual StyleBox resources


func set_heir(heir: Heir) -> void:
	"""Set data source and refresh all displays."""
	current_heir = heir
	if current_heir:
		refresh_all_displays()


func refresh_all_displays() -> void:
	"""Update all stat displays, skills, and traits."""
	if not current_heir:
		return

	update_header_info()
	update_stats_display()
	update_skills_display()
	update_traits_display()
	update_legacy_display()


func update_header_info() -> void:
	"""Display name, generation, year, and class information."""
	name_label.text = current_heir.name
	gen_year_label.text = "Generation %d | Year %d" % [
		current_heir.generation,
		current_heir.current_year
	]

	# Class and archetype from class system
	var class_name = "Unknown Class"
	var archetype_name = "Unknown Archetype"

	if current_heir.current_class:
		class_name = current_heir.current_class.get("class_name", "Unknown Class")
		archetype_name = current_heir.current_class.get("archetype", "Unknown Archetype")

	class_label.text = "Class: %s" % class_name
	archetype_label.text = "Archetype: %s" % archetype_name

	# Bloodline from traits
	var bloodline_name = "Unknown Bloodline"
	if current_heir.traits:
		for trait in current_heir.traits:
			if trait.get("trait_type") == "BLOODLINE":
				bloodline_name = trait.get("trait_name", "Unknown Bloodline")
				break

	bloodline_label.text = "Bloodline: %s" % bloodline_name


func update_stats_display() -> void:
	"""Show all 6 core stats with current values and color coding."""
	var stats_order = ["STR", "DEX", "CON", "INT", "WIS", "CHA"]

	for stat in stats_order:
		var value = current_heir.stats.get(stat, 0)
		var label = stat_labels[stat]
		label.text = "%s: %d" % [stat, value]
		label.add_theme_color_override("font_color", get_stat_color(value))

	# Health and Mana
	var max_health = current_heir.get_max_health() if current_heir.has_method("get_max_health") else 100
	var current_health = current_heir.current_health if "current_health" in current_heir else max_health
	health_label.text = "Health: %d / %d" % [current_health, max_health]

	var max_mana = current_heir.get_max_mana() if current_heir.has_method("get_max_mana") else 50
	var current_mana = current_heir.current_mana if "current_mana" in current_heir else max_mana
	mana_label.text = "Mana: %d / %d" % [current_mana, max_mana]


func update_skills_display() -> void:
	"""List all crafting and combat skills with levels and progress."""
	# Clear existing skill display
	for child in skills_list.get_children():
		child.queue_free()

	# Get crafting skills from HeirCrafting system
	var crafting_skills = []
	if current_heir.has_method("get_crafting_skills"):
		crafting_skills = current_heir.get_crafting_skills()
	elif "crafting" in current_heir:
		if current_heir.crafting.has_method("get_all_skills"):
			crafting_skills = current_heir.crafting.get_all_skills()

	# Filter skills based on current filter
	var displayed_skills = []

	for skill in crafting_skills:
		if current_skill_filter == "all" or current_skill_filter == "crafting":
			displayed_skills.append({
				"name": skill.get("skill_name", "Unknown"),
				"level": skill.get("level", 1),
				"xp": skill.get("xp", 0),
				"type": "crafting",
				"icon": skill.get("icon", "⚒")
			})

	# Add combat skills if available
	if current_heir.has_method("get_combat_skills"):
		var combat_skills = current_heir.get_combat_skills()
		for skill in combat_skills:
			if current_skill_filter == "all" or current_skill_filter == "combat":
				displayed_skills.append({
					"name": skill.get("skill_name", "Unknown"),
					"level": skill.get("level", 1),
					"xp": skill.get("xp", 0),
					"type": "combat",
					"icon": skill.get("icon", "⚔")
				})

	# Display skills
	for skill in displayed_skills:
		var skill_container = HBoxContainer.new()
		skill_container.add_theme_constant_override("separation", 8)

		# Icon
		var icon_label = Label.new()
		icon_label.text = skill["icon"]
		icon_label.custom_minimum_size = Vector2(20, 0)
		skill_container.add_child(icon_label)

		# Name and level
		var info_label = Label.new()
		info_label.text = "%s: Level %d / 100" % [skill["name"], skill["level"]]
		info_label.add_theme_font_size_override("font_size", 12)
		info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skill_container.add_child(info_label)

		# Progress bar
		var progress_bar = ProgressBar.new()
		progress_bar.value = skill["xp"]
		progress_bar.max_value = 100  # XP per level
		progress_bar.custom_minimum_size = Vector2(60, 15)
		progress_bar.modulate = get_skill_color(skill["level"])
		skill_container.add_child(progress_bar)

		skills_list.add_child(skill_container)


func update_traits_display() -> void:
	"""Organize and display all traits by category with descriptions."""
	# Clear existing traits
	for trait_type_container in traits_by_type.values():
		for child in trait_type_container.get_children():
			child.queue_free()

	if not current_heir.traits:
		return

	# Group traits by type
	var traits_grouped = {
		"BLOODLINE": [],
		"ACQUIRED": [],
		"CURSE": [],
		"BLESSING": []
	}

	for trait in current_heir.traits:
		var trait_type = trait.get("trait_type", "ACQUIRED")
		if trait_type in traits_grouped:
			traits_grouped[trait_type].append(trait)

	# Display traits for each type
	for trait_type in traits_grouped.keys():
		var container = traits_by_type[trait_type]

		if traits_grouped[trait_type].is_empty():
			continue

		# Type header
		var type_header = Label.new()
		type_header.text = "— %s —" % trait_type
		type_header.add_theme_font_size_override("font_size", 12)
		type_header.add_theme_color_override("font_color", get_trait_type_color(trait_type))
		container.add_child(type_header)

		# Traits of this type
		for trait in traits_grouped[trait_type]:
			var trait_label = Label.new()
			var icon = get_trait_icon(trait_type)
			var trait_name = trait.get("trait_name", "Unknown Trait")
			var effect = trait.get("effect", "")

			trait_label.text = "%s %s: %s" % [icon, trait_name, effect]
			trait_label.add_theme_font_size_override("font_size", 11)
			trait_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			container.add_child(trait_label)


func update_legacy_display() -> void:
	"""Show family info, reputation, and achievements."""
	# Parents
	var parent_names = []
	if "parents" in current_heir:
		for parent in current_heir.parents:
			if parent and "name" in parent:
				parent_names.append(parent.name)

	if parent_names.is_empty():
		parents_label.text = "Parents: [Unknown]"
	else:
		parents_label.text = "Parents: %s" % ", ".join(parent_names)

	# Spouse
	var spouse_text = "Spouse: [None]"
	if "spouse" in current_heir and current_heir.spouse:
		if "name" in current_heir.spouse:
			spouse_text = "Spouse: %s" % current_heir.spouse.name
	spouse_label.text = spouse_text

	# Children
	var child_count = 0
	var child_names = []
	if "children" in current_heir:
		child_count = current_heir.children.size()
		for child in current_heir.children:
			if child and "name" in child:
				child_names.append(child.name)

	if child_names.is_empty():
		children_label.text = "Children: %d" % child_count
	else:
		children_label.text = "Children: %d (%s)" % [child_count, ", ".join(child_names)]

	# Reputation from memory system
	var reputation_text = "Reputation: [Loading...]"
	if "reputation" in current_heir and current_heir.reputation:
		var rep_lines = []
		for faction_name in current_heir.reputation.keys():
			var rep_value = current_heir.reputation[faction_name]
			rep_lines.append("%s: %d%%" % [faction_name, rep_value])
		if rep_lines:
			reputation_text = "Reputation: %s" % " | ".join(rep_lines)
	reputation_label.text = reputation_text

	# Legacy summary
	var legacy_items = []
	if "legacy_achievements" in current_heir:
		legacy_items = current_heir.legacy_achievements

	if legacy_items.is_empty():
		legacy_summary_label.text = "Legacy: No achievements yet"
	else:
		legacy_summary_label.text = "Legacy: %s" % ", ".join(legacy_items)


func _on_stats_changed() -> void:
	"""Update stat display when equipment or effects change."""
	if current_heir:
		update_stats_display()


func _on_skills_changed() -> void:
	"""Update skill display when XP gained or level up occurs."""
	if current_heir:
		update_skills_display()


func _on_skill_filter(filter_name: String) -> void:
	"""Change displayed skills based on filter."""
	current_skill_filter = filter_name
	update_skills_display()


func _on_navigation_tab(tab_name: String) -> void:
	"""Navigate to other screens (inventory, equipment, etc.)."""
	match tab_name:
		"Inventory":
			get_tree().change_scene_to_file("res://ui/screens/inventory_screen.gd")
		"Equipment":
			get_tree().change_scene_to_file("res://ui/screens/equipment_screen.gd")
		"Crafting":
			get_tree().change_scene_to_file("res://ui/screens/crafting_screen.gd")
		"Family Tree":
			get_tree().change_scene_to_file("res://ui/screens/family_tree_screen.gd")


func _on_back_pressed() -> void:
	"""Close character sheet and return to previous screen."""
	queue_free()


# ===== UTILITY FUNCTIONS =====

func get_stat_color(value: int) -> Color:
	"""Return color based on stat value."""
	if value <= 5:
		return STAT_COLOR_LOW
	elif value <= 10:
		return STAT_COLOR_MEDIUM
	elif value <= 14:
		return STAT_COLOR_GOOD
	else:
		return STAT_COLOR_EXCELLENT


func get_skill_color(level: int) -> Color:
	"""Return color based on skill level."""
	if level <= 20:
		return SKILL_COLOR_LOW
	elif level <= 60:
		return SKILL_COLOR_MID
	else:
		return SKILL_COLOR_HIGH


func get_trait_type_color(trait_type: String) -> Color:
	"""Return color based on trait type."""
	match trait_type:
		"BLOODLINE":
			return TRAIT_COLOR_BLOODLINE
		"ACQUIRED":
			return TRAIT_COLOR_ACQUIRED
		"CURSE":
			return TRAIT_COLOR_CURSE
		"BLESSING":
			return TRAIT_COLOR_BLESSING
		_:
			return Color.WHITE


func get_trait_icon(trait_type: String) -> String:
	"""Return icon character for trait type."""
	match trait_type:
		"BLOODLINE":
			return "✓"
		"ACQUIRED":
			return "✓"
		"CURSE":
			return "⚠"
		"BLESSING":
			return "✨"
		_:
			return "•"


func create_panel(title: String) -> PanelContainer:
	"""Create a styled panel with title."""
	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new()

	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(title_label)

	vbox.add_child(create_separator())

	panel.add_child(vbox)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	return panel


func create_badge(text: String) -> Label:
	"""Create a styled badge label."""
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	return label


func create_separator() -> HSeparator:
	"""Create a visual separator."""
	var sep = HSeparator.new()
	return sep
