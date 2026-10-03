## Crafting Interface: browse, filter, and craft recipes
##
## Multi-panel UI for recipe discovery, ingredient checking, and active job tracking
## Supports single-generation and multi-generation legendary crafting

extends Control

class_name CraftingInterface


## Signals for crafting events
signal recipe_selected(recipe: Recipe)
signal craft_started(recipe_id: String)
signal craft_completed(recipe_id: String, item_created: Item)
signal multi_gen_contributed(recipe_id: String, progress: int)
signal favorite_toggled(recipe_id: String, is_favorite: bool)


## Layout constants
const RECIPE_BROWSER_WIDTH: float = 300.0
const DETAILS_PANEL_WIDTH: float = 350.0
const ACTIVE_JOBS_HEIGHT: float = 120.0
const RECIPE_ITEM_HEIGHT: float = 80.0
const STAR_UNICODE: String = "⭐"
const HAMMER_EMOJI: String = "⚒"
const ALCHEMY_EMOJI: String = "🧪"
const SCROLL_V_SEPARATION: float = 8.0


## Filter options
enum FilterType {
	ALL,
	LEARNABLE,
	FAVORITES,
	MULTI_GEN
}

## Sort options
enum SortType {
	BY_LEVEL,
	BY_TIME,
	BY_DIFFICULTY
}


## Data references
var heir: Heir
var heir_crafting: HeirCrafting
var heir_inventory: HeirInventory

## Current state
var current_skill_type: int = CraftingSkill.SkillType.BLACKSMITHING
var current_filter: FilterType = FilterType.ALL
var current_sort: SortType = SortType.BY_LEVEL
var selected_recipe_id: String = ""
var favorite_recipes: Array[String] = []
var active_crafting_jobs: Dictionary = {}  # recipe_id -> {time_started, duration_hours, heir_name}

## UI component references
var skill_selector: OptionButton
var level_label: Label
var xp_progress_bar: ProgressBar
var xp_label: Label

var filter_buttons: Dictionary = {}  # FilterType -> Button
var sort_dropdown: OptionButton

var recipe_browser: ItemList
var recipe_list: Array[String] = []
var recipe_details_label: Label
var ingredients_container: VBoxContainer
var ingredient_items: Array[Node] = []

var craft_button: Button
var favorite_button: Button
var active_jobs_container: VBoxContainer
var craft_confirmation_dialog: AcceptDialog


func _init(p_heir: Heir) -> void:
	heir = p_heir
	heir_crafting = HeirCrafting.new(heir)
	heir_inventory = HeirInventory.new(heir)

	# Initialize with first available crafting skill
	if not heir.crafting_skills.is_empty():
		current_skill_type = heir.crafting_skills.keys()[0]


func _ready() -> void:
	# Background overlay
	var bg = ColorRect.new()
	bg.color = Color.BLACK.with_alpha(0.8)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Main panel
	var panel = PanelContainer.new()
	panel.anchor_left = 0.05
	panel.anchor_top = 0.05
	panel.anchor_right = 0.95
	panel.anchor_bottom = 0.95
	add_child(panel)

	var main_vbox = VBoxContainer.new()
	panel.add_child(main_vbox)

	# Header
	var header_label = Label.new()
	header_label.text = "CRAFTING WORKSHOP"
	header_label.add_theme_font_size_override("font_size", 22)
	main_vbox.add_child(header_label)

	# Skill selector bar
	_setup_skill_bar(main_vbox)

	# Filter and sort controls
	_setup_filter_sort_controls(main_vbox)

	# Main content: Recipe browser (left) + Details (right)
	var content_hbox = HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_hbox)

	_setup_recipe_browser(content_hbox)
	_setup_recipe_details_panel(content_hbox)

	# Active crafting jobs section
	_setup_active_jobs_section(main_vbox)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close (ESC)"
	close_btn.custom_minimum_size = Vector2(100, 30)
	close_btn.pressed.connect(_on_close_pressed)
	main_vbox.add_child(close_btn)

	# Refresh UI
	refresh_recipe_list()
	update_skill_display()


## Setup skill selector and XP progress display
func _setup_skill_bar(parent: VBoxContainer) -> void:
	var skill_bar = HBoxContainer.new()
	skill_bar.custom_minimum_size = Vector2(0, 40)
	parent.add_child(skill_bar)

	# Skill dropdown
	skill_selector = OptionButton.new()
	skill_selector.custom_minimum_size = Vector2(150, 30)
	skill_selector.item_selected.connect(_on_skill_changed)

	var skills = heir_crafting.get_all_skills()
	for skill in skills:
		skill_selector.add_item(skill.skill_name, skill.skill_type)

	if skills.size() > 0:
		skill_selector.select(0)

	skill_bar.add_child(skill_selector)

	# Level label
	level_label = Label.new()
	level_label.custom_minimum_size = Vector2(100, 30)
	skill_bar.add_child(level_label)

	# XP progress bar and label
	xp_progress_bar = ProgressBar.new()
	xp_progress_bar.custom_minimum_size = Vector2(200, 20)
	xp_progress_bar.value = 0
	xp_progress_bar.max_value = 100
	skill_bar.add_child(xp_progress_bar)

	xp_label = Label.new()
	xp_label.custom_minimum_size = Vector2(150, 30)
	skill_bar.add_child(xp_label)


## Setup filter and sort controls
func _setup_filter_sort_controls(parent: VBoxContainer) -> void:
	var controls_hbox = HBoxContainer.new()
	controls_hbox.custom_minimum_size = Vector2(0, 35)
	parent.add_child(controls_hbox)

	# Filter label
	var filter_label = Label.new()
	filter_label.text = "Filter:"
	filter_label.custom_minimum_size = Vector2(50, 30)
	controls_hbox.add_child(filter_label)

	# Filter buttons
	var filter_names = ["All", "Learnable", "Favorites", "Multi-Gen"]
	for i in range(FilterType.size()):
		var btn = Button.new()
		btn.text = filter_names[i]
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(80, 30)
		btn.pressed.connect(_on_filter_pressed.bind(i))
		controls_hbox.add_child(btn)
		filter_buttons[i] = btn

	filter_buttons[FilterType.ALL].button_pressed = true

	# Spacer
	controls_hbox.add_child(Control.new())

	# Sort label
	var sort_label = Label.new()
	sort_label.text = "Sort:"
	sort_label.custom_minimum_size = Vector2(50, 30)
	controls_hbox.add_child(sort_label)

	# Sort dropdown
	sort_dropdown = OptionButton.new()
	sort_dropdown.custom_minimum_size = Vector2(120, 30)
	sort_dropdown.add_item("By Level", SortType.BY_LEVEL)
	sort_dropdown.add_item("By Time", SortType.BY_TIME)
	sort_dropdown.add_item("By Difficulty", SortType.BY_DIFFICULTY)
	sort_dropdown.item_selected.connect(_on_sort_changed)
	controls_hbox.add_child(sort_dropdown)


## Setup recipe browser (left panel)
func _setup_recipe_browser(parent: HBoxContainer) -> void:
	var browser_vbox = VBoxContainer.new()
	browser_vbox.custom_minimum_size = Vector2(RECIPE_BROWSER_WIDTH, 0)
	browser_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(browser_vbox)

	var browser_label = Label.new()
	browser_label.text = "RECIPE BROWSER"
	browser_label.add_theme_font_size_override("font_size", 14)
	browser_vbox.add_child(browser_label)

	recipe_browser = ItemList.new()
	recipe_browser.size_flags_vertical = Control.SIZE_EXPAND_FILL
	recipe_browser.item_clicked.connect(_on_recipe_selected)
	recipe_browser.custom_minimum_size = Vector2(RECIPE_BROWSER_WIDTH, 300)
	browser_vbox.add_child(recipe_browser)


## Setup recipe details panel (right panel)
func _setup_recipe_details_panel(parent: HBoxContainer) -> void:
	var details_vbox = VBoxContainer.new()
	details_vbox.custom_minimum_size = Vector2(DETAILS_PANEL_WIDTH, 0)
	details_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(details_vbox)

	var details_label_title = Label.new()
	details_label_title.text = "RECIPE DETAILS"
	details_label_title.add_theme_font_size_override("font_size", 14)
	details_vbox.add_child(details_label_title)

	# Scrollable details area
	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_vbox.add_child(scroll_container)

	var details_content = VBoxContainer.new()
	details_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(details_content)

	# Recipe name (placeholder)
	recipe_details_label = Label.new()
	recipe_details_label.text = "[Select a recipe]"
	recipe_details_label.add_theme_font_size_override("font_size", 16)
	recipe_details_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	details_content.add_child(recipe_details_label)

	# Separator
	var separator = HSeparator.new()
	details_content.add_child(separator)

	# Ingredients container
	var ing_label = Label.new()
	ing_label.text = "INGREDIENTS:"
	ing_label.add_theme_font_size_override("font_size", 12)
	details_content.add_child(ing_label)

	ingredients_container = VBoxContainer.new()
	ingredients_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_content.add_child(ingredients_container)

	# Action buttons at bottom
	var action_buttons = HBoxContainer.new()
	action_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	details_vbox.add_child(action_buttons)

	craft_button = Button.new()
	craft_button.text = "[CRAFT]"
	craft_button.custom_minimum_size = Vector2(100, 30)
	craft_button.pressed.connect(_on_craft_pressed)
	action_buttons.add_child(craft_button)

	favorite_button = Button.new()
	favorite_button.text = "[FAVORITE]"
	favorite_button.custom_minimum_size = Vector2(100, 30)
	favorite_button.toggle_mode = true
	favorite_button.pressed.connect(_on_favorite_toggled)
	action_buttons.add_child(favorite_button)


## Setup active crafting jobs display
func _setup_active_jobs_section(parent: VBoxContainer) -> void:
	var jobs_label = Label.new()
	jobs_label.text = "ACTIVE CRAFTING JOBS:"
	jobs_label.add_theme_font_size_override("font_size", 12)
	parent.add_child(jobs_label)

	var jobs_panel = PanelContainer.new()
	jobs_panel.custom_minimum_size = Vector2(0, ACTIVE_JOBS_HEIGHT)
	parent.add_child(jobs_panel)

	active_jobs_container = VBoxContainer.new()
	active_jobs_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jobs_panel.add_child(active_jobs_container)


## Refresh recipe list based on current filters and sorts
func refresh_recipe_list() -> void:
	var skill = heir_crafting.get_skill(current_skill_type)
	if not skill:
		recipe_list.clear()
		_refresh_browser_display()
		return

	var all_recipes = RecipeCatalog.get_recipes_by_skill(current_skill_type)
	recipe_list.clear()

	# Apply filter
	for recipe_id in all_recipes:
		var recipe = RecipeCatalog.create_recipe(recipe_id)
		if not recipe:
			continue

		var include = false
		match current_filter:
			FilterType.ALL:
				include = true
			FilterType.LEARNABLE:
				include = skill.level >= recipe.required_skill_level
			FilterType.FAVORITES:
				include = recipe_id in favorite_recipes
			FilterType.MULTI_GEN:
				include = false  # Handle in separate section if needed

		if include:
			recipe_list.append(recipe_id)

	# Apply sort
	_apply_sort_to_recipe_list()

	# Refresh display
	_refresh_browser_display()


## Apply sort to recipe list
func _apply_sort_to_recipe_list() -> void:
	match current_sort:
		SortType.BY_LEVEL:
			recipe_list.sort_custom(func(a, b):
				var recipe_a = RecipeCatalog.create_recipe(a)
				var recipe_b = RecipeCatalog.create_recipe(b)
				return recipe_a.required_skill_level < recipe_b.required_skill_level
			)
		SortType.BY_TIME:
			recipe_list.sort_custom(func(a, b):
				var recipe_a = RecipeCatalog.create_recipe(a)
				var recipe_b = RecipeCatalog.create_recipe(b)
				return recipe_a.crafting_time_hours < recipe_b.crafting_time_hours
			)
		SortType.BY_DIFFICULTY:
			recipe_list.sort_custom(func(a, b):
				var recipe_a = RecipeCatalog.create_recipe(a)
				var recipe_b = RecipeCatalog.create_recipe(b)
				return recipe_a.difficulty < recipe_b.difficulty
			)


## Refresh browser display with current recipe list
func _refresh_browser_display() -> void:
	recipe_browser.clear()
	var skill = heir_crafting.get_skill(current_skill_type)

	for recipe_id in recipe_list:
		var recipe = RecipeCatalog.create_recipe(recipe_id)
		if not recipe:
			continue

		# Build display text
		var status = ""
		var can_craft = skill.level >= recipe.required_skill_level
		var has_materials = _check_ingredients_available(recipe)

		if can_craft and has_materials:
			status = "✓ [Ready]"
		elif can_craft:
			status = "✗ [Missing Items]"
		else:
			status = "✗ [Too Advanced]"

		var display_text = "%s %s\nLvl %d | %s | %s\n%s" % [
			_get_skill_emoji(),
			recipe.output_item_id,
			recipe.required_skill_level,
			STAR_UNICODE.repeat(recipe.difficulty),
			recipe.get_time_string(),
			status
		]

		recipe_browser.add_item(display_text, null, false)


## Get emoji for current skill type
func _get_skill_emoji() -> String:
	match current_skill_type:
		CraftingSkill.SkillType.BLACKSMITHING:
			return "⚒"
		CraftingSkill.SkillType.ALCHEMY:
			return "🧪"
		CraftingSkill.SkillType.LEATHERWORKING:
			return "🎯"
		CraftingSkill.SkillType.CARPENTRY:
			return "🪵"
		CraftingSkill.SkillType.ENCHANTING:
			return "✨"
		CraftingSkill.SkillType.COOKING:
			return "🍳"
		CraftingSkill.SkillType.WEAVING:
			return "🧵"
		_:
			return "◇"


## Display recipe details
func _display_recipe_details(recipe: Recipe) -> void:
	if not recipe:
		recipe_details_label.text = "[No recipe selected]"
		craft_button.disabled = true
		return

	# Update selected recipe ID
	selected_recipe_id = recipe.recipe_id

	# Recipe name and basic info
	var skill = heir_crafting.get_skill(current_skill_type)
	var can_craft = skill.level >= recipe.required_skill_level

	var title_text = recipe.output_item_id.to_upper()
	if not can_craft:
		title_text += " (Level %d Required)" % recipe.required_skill_level

	recipe_details_label.text = title_text

	# Clear and rebuild ingredients display
	for child in ingredient_items:
		child.queue_free()
	ingredient_items.clear()

	# Display ingredients with availability
	var all_ingredients_available = true
	for ingredient in recipe.ingredients:
		var material_id = ingredient["material_id"]
		var needed = ingredient["quantity"]
		var available = heir_inventory.get_item_count(material_id)

		var is_available = available >= needed
		all_ingredients_available = all_ingredients_available and is_available

		var ing_hbox = HBoxContainer.new()
		ing_hbox.custom_minimum_size = Vector2(0, 25)

		var status_label = Label.new()
		status_label.text = "✓" if is_available else "✗"
		status_label.add_theme_color_override("font_color", Color.GREEN if is_available else Color.RED)
		ing_hbox.add_child(status_label)

		var ing_label = Label.new()
		ing_label.text = "%s: %d/%d" % [material_id, available, needed]
		ing_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ing_hbox.add_child(ing_label)

		ingredients_container.add_child(ing_hbox)
		ingredient_items.append(ing_hbox)

	# Disable craft button if missing materials or not skilled enough
	craft_button.disabled = not (can_craft and all_ingredients_available)

	# Update favorite button state
	favorite_button.button_pressed = recipe.recipe_id in favorite_recipes


## Check if all ingredients are available
func _check_ingredients_available(recipe: Recipe) -> bool:
	for ingredient in recipe.ingredients:
		var material_id = ingredient["material_id"]
		var needed = ingredient["quantity"]
		var available = heir_inventory.get_item_count(material_id)
		if available < needed:
			return false
	return true


## Update skill display (level and XP)
func update_skill_display() -> void:
	var skill = heir_crafting.get_skill(current_skill_type)
	if not skill:
		return

	level_label.text = "Level: %d" % skill.level
	xp_label.text = skill.get_progress_string()

	xp_progress_bar.value = skill.get_progress_to_next() * 100


## Handle skill selection change
func _on_skill_changed(index: int) -> void:
	var skill_type = skill_selector.get_item_metadata(index)
	current_skill_type = skill_type
	refresh_recipe_list()
	update_skill_display()
	selected_recipe_id = ""
	recipe_details_label.text = "[Select a recipe]"
	craft_button.disabled = true


## Handle filter button pressed
func _on_filter_pressed(filter_type: int) -> void:
	# Deselect previous filter
	for btn in filter_buttons.values():
		btn.button_pressed = false

	# Select new filter
	filter_buttons[filter_type].button_pressed = true
	current_filter = filter_type

	refresh_recipe_list()


## Handle sort dropdown change
func _on_sort_changed(index: int) -> void:
	current_sort = sort_dropdown.get_item_metadata(index)
	refresh_recipe_list()


## Handle recipe selection in browser
func _on_recipe_selected(index: int) -> void:
	if index < 0 or index >= recipe_list.size():
		return

	var recipe_id = recipe_list[index]
	var recipe = RecipeCatalog.create_recipe(recipe_id)
	_display_recipe_details(recipe)
	recipe_selected.emit(recipe)


## Handle craft button pressed
func _on_craft_pressed() -> void:
	if selected_recipe_id.is_empty():
		return

	var recipe = RecipeCatalog.create_recipe(selected_recipe_id)
	if not recipe:
		return

	# Show confirmation dialog
	_show_craft_confirmation_dialog(recipe)


## Show crafting confirmation dialog
func _show_craft_confirmation_dialog(recipe: Recipe) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "Confirm Crafting"
	dialog.dialog_text = "Craft %s?\n\nTime: %s\nXP Reward: %d\nMaterials will be consumed." % [
		recipe.output_item_id,
		recipe.get_time_string(),
		recipe.xp_reward
	]
	dialog.confirmed.connect(func(): _confirm_craft(recipe))
	add_child(dialog)
	dialog.popup_centered_ratio(0.4)


## Confirm and start crafting
func _confirm_craft(recipe: Recipe) -> void:
	# Consume ingredients
	for ingredient in recipe.ingredients:
		var material_id = ingredient["material_id"]
		var needed = ingredient["quantity"]
		for i in range(needed):
			for item in heir.inventory:
				if item.item_id == material_id:
					heir.inventory.erase(item)
					break

	# Award XP
	heir_crafting.add_skill_xp(current_skill_type, recipe.xp_reward)

	# Track crafting job (simplified - would be more complex in full system)
	active_crafting_jobs[recipe.recipe_id] = {
		"time_started": Time.get_ticks_msec(),
		"duration_hours": recipe.crafting_time_hours,
		"heir_name": heir.name
	}

	# Update UI
	update_active_jobs_display()
	update_skill_display()
	refresh_recipe_list()

	craft_started.emit(recipe.recipe_id)


## Update active jobs display
func update_active_jobs_display() -> void:
	# Clear current display
	for child in active_jobs_container.get_children():
		child.queue_free()

	if active_crafting_jobs.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No active crafting jobs"
		empty_label.add_theme_color_override("font_color", Color.GRAY)
		active_jobs_container.add_child(empty_label)
		return

	# Display each active job
	for recipe_id in active_crafting_jobs:
		var job_data = active_crafting_jobs[recipe_id]
		var recipe = RecipeCatalog.create_recipe(recipe_id)
		if not recipe:
			continue

		var job_hbox = HBoxContainer.new()
		job_hbox.custom_minimum_size = Vector2(0, 35)

		var recipe_label = Label.new()
		recipe_label.text = "%s (%s)" % [recipe.output_item_id, job_data["heir_name"]]
		recipe_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		job_hbox.add_child(recipe_label)

		var time_label = Label.new()
		time_label.text = "%dh" % job_data["duration_hours"]
		job_hbox.add_child(time_label)

		var progress = ProgressBar.new()
		progress.value = 50  # Simplified - would track actual time
		progress.custom_minimum_size = Vector2(100, 20)
		job_hbox.add_child(progress)

		active_jobs_container.add_child(job_hbox)


## Handle favorite toggle
func _on_favorite_toggled() -> void:
	if selected_recipe_id.is_empty():
		return

	if selected_recipe_id in favorite_recipes:
		favorite_recipes.erase(selected_recipe_id)
	else:
		favorite_recipes.append(selected_recipe_id)

	favorite_toggled.emit(selected_recipe_id, selected_recipe_id in favorite_recipes)


## Handle close button
func _on_close_pressed() -> void:
	queue_free()


## Set the heir to manage
func set_heir_crafting(p_heir_crafting: HeirCrafting) -> void:
	heir_crafting = p_heir_crafting
	heir = p_heir_crafting.heir
	heir_inventory = HeirInventory.new(heir)
	refresh_recipe_list()
	update_skill_display()
