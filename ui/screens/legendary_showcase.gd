## Legendary Showcase UI: Display and interact with legendary items
##
## Premium UI for viewing legendary items with special effects and detailed information.
## Shows item stats, synergies, enchantments, lore, history, and soulbound status.
## Supports filtering, sorting, and comparing with other legendaries.

extends Control

class_name LegendaryShowcase


# Signals
signal legendary_equipped(item: Equipment)
signal legendary_compared(item1: Equipment, item2: Equipment)
signal showcase_closed()


# Color constants (premium golden theme)
const COLOR_GOLD = Color(0.831, 0.686, 0.216)  # RGB: 212, 175, 55
const COLOR_GOLD_DARK = Color(0.624, 0.514, 0.161)
const COLOR_LEGENDARY = Color(1.0, 0.843, 0.0)
const COLOR_VERY_RARE = Color(0.616, 0.267, 0.961)
const COLOR_RARE = Color(0.2, 0.6, 1.0)
const COLOR_UNCOMMON = Color(0.2, 0.8, 0.2)
const COLOR_BACKGROUND = Color(0.05, 0.02, 0.15)
const COLOR_PANEL = Color(0.08, 0.04, 0.12)
const COLOR_TEXT = Color(0.9, 0.9, 0.95)
const COLOR_TEXT_ACCENT = Color(0.95, 0.9, 0.7)

# Filter and sort enums
enum FilterType {
	ALL,
	EQUIPPED,
	INVENTORY,
	BY_SKILL,
	ARTIFACTS
}

enum SortType {
	RARITY,
	ACQUISITION_DATE,
	POWER_LEVEL
}

# Data references
var heir: Heir
var heir_equipment: HeirEquipment
var legendary_items: Array[Equipment] = []
var current_filter: FilterType = FilterType.ALL
var current_sort: SortType = SortType.RARITY

# UI component references
var main_panel: PanelContainer
var header_label: Label
var hero_collection_label: Label

# Filter and sort controls
var filter_buttons: Dictionary = {}  # FilterType -> Button
var sort_buttons: Dictionary = {}    # SortType -> Button

# Main detail view
var showcase_panel: PanelContainer
var item_name_label: Label
var item_subtitle_label: Label
var item_visual_panel: Panel

# Information panels
var info_grid: GridContainer
var rarity_label: Label
var class_label: Label
var acquisition_label: Label
var status_label: Label

# Stats display
var stats_container: VBoxContainer
var stats_labels: Dictionary = {}

# Synergy score
var synergy_container: VBoxContainer
var synergy_progress: ProgressBar
var synergy_label: Label

# Enchantments
var enchantments_container: VBoxContainer

# Legendary effect
var legendary_effect_container: VBoxContainer
var legendary_effect_name: Label
var legendary_effect_desc: Label

# Lore section
var lore_container: VBoxContainer
var lore_text: Label

# Bloodline binding
var binding_container: VBoxContainer
var binding_status_label: Label
var binding_bonus_label: Label

# History section
var history_container: VBoxContainer
var created_label: Label
var owners_label: Label
var battles_label: Label
var legendary_kills_label: Label

# Action buttons
var equip_button: Button
var compare_button: Button
var lore_button: Button
var details_button: Button

# Legendary grid
var legendary_grid: HBoxContainer
var grid_scroll: ScrollContainer

# Animation references
var tween: Tween
var border_material: Material


func _init(p_heir: Heir) -> void:
	heir = p_heir
	heir_equipment = HeirEquipment.new(heir)
	collect_legendary_items()


func _ready() -> void:
	setup_ui_layout()
	setup_styling()
	load_legendary_items()


func setup_ui_layout() -> void:
	"""Create and organize all UI panels."""
	# Background
	var bg = ColorRect.new()
	bg.color = COLOR_BACKGROUND.with_alpha(0.95)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Main container
	var main_container = VBoxContainer.new()
	main_container.anchor_left = 0.05
	main_container.anchor_top = 0.02
	main_container.anchor_right = 0.95
	main_container.anchor_bottom = 0.98
	main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_theme_constant_override("separation", 12)
	add_child(main_container)

	# Header section
	_setup_header(main_container)

	# Filter and sort controls
	_setup_filter_sort_controls(main_container)

	# Scrollable content area
	var scroll_view = ScrollContainer.new()
	scroll_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(scroll_view)

	var scroll_container = VBoxContainer.new()
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_theme_constant_override("separation", 15)
	scroll_view.add_child(scroll_container)

	# Main showcase panel (central item display)
	_setup_showcase_panel(scroll_container)

	# Other legendaries grid
	_setup_legendary_grid(scroll_container)

	# Bottom action buttons
	_setup_action_buttons(main_container)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 35)
	close_btn.pressed.connect(_on_close_pressed)
	main_container.add_child(close_btn)


func _setup_header(parent: VBoxContainer) -> void:
	"""Setup header with title and collection info."""
	var header_vbox = VBoxContainer.new()
	parent.add_child(header_vbox)

	header_label = Label.new()
	header_label.text = "LEGENDARY SHOWCASE"
	header_label.add_theme_font_size_override("font_size", 28)
	header_label.add_theme_color_override("font_color", COLOR_LEGENDARY)
	header_vbox.add_child(header_label)

	hero_collection_label = Label.new()
	hero_collection_label.text = "%s's Collection" % heir.name
	hero_collection_label.add_theme_font_size_override("font_size", 14)
	hero_collection_label.add_theme_color_override("font_color", COLOR_TEXT_ACCENT)
	header_vbox.add_child(hero_collection_label)

	var separator = HSeparator.new()
	header_vbox.add_child(separator)


func _setup_filter_sort_controls(parent: VBoxContainer) -> void:
	"""Setup filter and sort buttons."""
	var controls_hbox = HBoxContainer.new()
	controls_hbox.add_theme_constant_override("separation", 10)
	parent.add_child(controls_hbox)

	# Filter label
	var filter_label = Label.new()
	filter_label.text = "Filter:"
	filter_label.add_theme_font_size_override("font_size", 12)
	controls_hbox.add_child(filter_label)

	# Filter buttons
	var filter_names = ["All", "Equipped", "Inventory", "By Skill", "Artifacts"]
	for i in range(filter_names.size()):
		var btn = Button.new()
		btn.text = filter_names[i]
		btn.custom_minimum_size = Vector2(80, 30)
		btn.toggle_mode = true
		btn.pressed.connect(_on_filter_selected.bindv([i]))
		controls_hbox.add_child(btn)
		filter_buttons[i] = btn

	# Set default filter
	if filter_buttons.has(FilterType.ALL):
		filter_buttons[FilterType.ALL].button_pressed = true

	# Spacer
	controls_hbox.add_child(Control.new())
	(controls_hbox.get_child(controls_hbox.get_child_count() - 1)).size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Sort label
	var sort_label = Label.new()
	sort_label.text = "Sort:"
	sort_label.add_theme_font_size_override("font_size", 12)
	controls_hbox.add_child(sort_label)

	# Sort buttons
	var sort_names = ["Rarity", "Acquisition", "Power"]
	for i in range(sort_names.size()):
		var btn = Button.new()
		btn.text = sort_names[i]
		btn.custom_minimum_size = Vector2(80, 30)
		btn.toggle_mode = true
		btn.pressed.connect(_on_sort_selected.bindv([i]))
		controls_hbox.add_child(btn)
		sort_buttons[i] = btn

	# Set default sort
	if sort_buttons.has(SortType.RARITY):
		sort_buttons[SortType.RARITY].button_pressed = true


func _setup_showcase_panel(parent: VBoxContainer) -> void:
	"""Setup main legendary item detail showcase."""
	showcase_panel = PanelContainer.new()
	showcase_panel.custom_minimum_size = Vector2(0, 600)
	parent.add_child(showcase_panel)

	var showcase_vbox = VBoxContainer.new()
	showcase_vbox.add_theme_constant_override("separation", 10)
	showcase_panel.add_child(showcase_vbox)

	# Item name and subtitle
	item_name_label = Label.new()
	item_name_label.text = "✨ SELECT AN ITEM ✨"
	item_name_label.add_theme_font_size_override("font_size", 26)
	item_name_label.add_theme_color_override("font_color", COLOR_LEGENDARY)
	item_name_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
	showcase_vbox.add_child(item_name_label)

	item_subtitle_label = Label.new()
	item_subtitle_label.text = ""
	item_subtitle_label.add_theme_font_size_override("font_size", 14)
	item_subtitle_label.add_theme_color_override("font_color", COLOR_TEXT_ACCENT)
	item_subtitle_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
	showcase_vbox.add_child(item_subtitle_label)

	# Visual panel (for future particle effects or item icon)
	item_visual_panel = Panel.new()
	item_visual_panel.custom_minimum_size = Vector2(0, 120)
	showcase_vbox.add_child(item_visual_panel)

	# Main content horizontal split
	var content_hbox = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 15)
	content_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	showcase_vbox.add_child(content_hbox)

	# Left panel: Info and stats
	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 12)
	left_vbox.custom_minimum_size = Vector2(300, 0)
	content_hbox.add_child(left_vbox)

	# Information grid
	_setup_info_grid(left_vbox)

	# Stats section
	_setup_stats_section(left_vbox)

	# Right panel: Synergy, Enchantments, Effects
	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 12)
	content_hbox.add_child(right_vbox)

	# Synergy display
	_setup_synergy_display(right_vbox)

	# Enchantments section
	_setup_enchantments_section(right_vbox)

	# Legendary effect
	_setup_legendary_effect_section(right_vbox)

	# Lore section
	_setup_lore_section(showcase_vbox)

	# Bloodline binding
	_setup_binding_section(showcase_vbox)

	# History section
	_setup_history_section(showcase_vbox)


func _setup_info_grid(parent: VBoxContainer) -> void:
	"""Setup rarity, class, acquisition, and status display."""
	var info_label = Label.new()
	info_label.text = "ITEM INFORMATION"
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", COLOR_GOLD)
	parent.add_child(info_label)

	info_grid = GridContainer.new()
	info_grid.columns = 2
	info_grid.add_theme_constant_override("h_separation", 8)
	info_grid.add_theme_constant_override("v_separation", 5)
	parent.add_child(info_grid)

	# Rarity
	var rarity_title = Label.new()
	rarity_title.text = "Rarity:"
	rarity_title.add_theme_font_size_override("font_size", 11)
	info_grid.add_child(rarity_title)

	rarity_label = Label.new()
	rarity_label.text = "⭐ LEGENDARY"
	rarity_label.add_theme_font_size_override("font_size", 11)
	rarity_label.add_theme_color_override("font_color", COLOR_LEGENDARY)
	info_grid.add_child(rarity_label)

	# Class
	var class_title = Label.new()
	class_title.text = "Class:"
	class_title.add_theme_font_size_override("font_size", 11)
	info_grid.add_child(class_title)

	class_label = Label.new()
	class_label.text = "Unique One-of-a-Kind"
	class_label.add_theme_font_size_override("font_size", 11)
	info_grid.add_child(class_label)

	# Acquisition
	var acq_title = Label.new()
	acq_title.text = "Acquired:"
	acq_title.add_theme_font_size_override("font_size", 11)
	info_grid.add_child(acq_title)

	acquisition_label = Label.new()
	acquisition_label.text = "Year 847"
	acquisition_label.add_theme_font_size_override("font_size", 11)
	info_grid.add_child(acquisition_label)

	# Status
	var status_title = Label.new()
	status_title.text = "Status:"
	status_title.add_theme_font_size_override("font_size", 11)
	info_grid.add_child(status_title)

	status_label = Label.new()
	status_label.text = "In Inventory"
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", COLOR_TEXT_ACCENT)
	info_grid.add_child(status_label)


func _setup_stats_section(parent: VBoxContainer) -> void:
	"""Setup stat bonuses display."""
	var stats_title = Label.new()
	stats_title.text = "STATS"
	stats_title.add_theme_font_size_override("font_size", 12)
	stats_title.add_theme_color_override("font_color", COLOR_GOLD)
	parent.add_child(stats_title)

	stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 3)
	parent.add_child(stats_container)


func _setup_synergy_display(parent: VBoxContainer) -> void:
	"""Setup synergy score and visual bar."""
	synergy_container = VBoxContainer.new()
	synergy_container.add_theme_constant_override("separation", 8)
	parent.add_child(synergy_container)

	var title = Label.new()
	title.text = "SYNERGY SCORE"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	synergy_container.add_child(title)

	synergy_progress = ProgressBar.new()
	synergy_progress.custom_minimum_size = Vector2(0, 25)
	synergy_progress.min_value = 0.0
	synergy_progress.max_value = 100.0
	synergy_progress.value = 87.0
	synergy_container.add_child(synergy_progress)

	synergy_label = Label.new()
	synergy_label.text = "Perfect Synergy (87%)"
	synergy_label.add_theme_font_size_override("font_size", 11)
	synergy_label.add_theme_color_override("font_color", COLOR_TEXT_ACCENT)
	synergy_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
	synergy_container.add_child(synergy_label)


func _setup_enchantments_section(parent: VBoxContainer) -> void:
	"""Setup enchantments list."""
	var title = Label.new()
	title.text = "ENCHANTMENTS"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	parent.add_child(title)

	enchantments_container = VBoxContainer.new()
	enchantments_container.add_theme_constant_override("separation", 3)
	parent.add_child(enchantments_container)


func _setup_legendary_effect_section(parent: VBoxContainer) -> void:
	"""Setup legendary unique effect display."""
	var title = Label.new()
	title.text = "LEGENDARY EFFECT"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	parent.add_child(title)

	legendary_effect_container = VBoxContainer.new()
	legendary_effect_container.add_theme_constant_override("separation", 5)
	parent.add_child(legendary_effect_container)

	legendary_effect_name = Label.new()
	legendary_effect_name.text = "🔥 Soulrend"
	legendary_effect_name.add_theme_font_size_override("font_size", 12)
	legendary_effect_name.add_theme_color_override("font_color", COLOR_GOLD)
	legendary_effect_container.add_child(legendary_effect_name)

	legendary_effect_desc = Label.new()
	legendary_effect_desc.text = "Damage scales with missing health. Each 10% missing HP grants 6% bonus damage."
	legendary_effect_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	legendary_effect_desc.add_theme_font_size_override("font_size", 10)
	legendary_effect_container.add_child(legendary_effect_desc)


func _setup_lore_section(parent: VBoxContainer) -> void:
	"""Setup lore display."""
	var title = Label.new()
	title.text = "LORE"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	parent.add_child(title)

	lore_container = VBoxContainer.new()
	parent.add_child(lore_container)

	lore_text = Label.new()
	lore_text.text = "A storied blade with a rich history..."
	lore_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	lore_text.add_theme_font_size_override("font_size", 10)
	lore_text.custom_minimum_size = Vector2(0, 100)
	lore_container.add_child(lore_text)


func _setup_binding_section(parent: VBoxContainer) -> void:
	"""Setup soulbound binding display."""
	var title = Label.new()
	title.text = "BLOODLINE BINDING"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	parent.add_child(title)

	binding_container = VBoxContainer.new()
	binding_container.add_theme_constant_override("separation", 3)
	parent.add_child(binding_container)

	binding_status_label = Label.new()
	binding_status_label.text = "✓ Soulbound to: House Aldwyn"
	binding_status_label.add_theme_font_size_override("font_size", 11)
	binding_status_label.add_theme_color_override("font_color", COLOR_UNCOMMON)
	binding_container.add_child(binding_status_label)

	binding_bonus_label = Label.new()
	binding_bonus_label.text = "Cumulative Bonus: +12% (4 generations × 3%)"
	binding_bonus_label.add_theme_font_size_override("font_size", 10)
	binding_container.add_child(binding_bonus_label)


func _setup_history_section(parent: VBoxContainer) -> void:
	"""Setup item history display."""
	var title = Label.new()
	title.text = "HISTORY"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	parent.add_child(title)

	history_container = VBoxContainer.new()
	history_container.add_theme_constant_override("separation", 3)
	parent.add_child(history_container)

	created_label = Label.new()
	created_label.text = "Created: Gen 2, Year 847"
	created_label.add_theme_font_size_override("font_size", 10)
	history_container.add_child(created_label)

	owners_label = Label.new()
	owners_label.text = "Owners: Aldwyn → Kael → Mira → Current"
	owners_label.add_theme_font_size_override("font_size", 10)
	history_container.add_child(owners_label)

	battles_label = Label.new()
	battles_label.text = "Battles: 847 (72% win rate)"
	battles_label.add_theme_font_size_override("font_size", 10)
	history_container.add_child(battles_label)

	legendary_kills_label = Label.new()
	legendary_kills_label.text = "Legendary Kills: 12"
	legendary_kills_label.add_theme_font_size_override("font_size", 10)
	history_container.add_child(legendary_kills_label)


func _setup_legendary_grid(parent: VBoxContainer) -> void:
	"""Setup grid of other legendary items."""
	var title = Label.new()
	title.text = "OTHER LEGENDARIES"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	parent.add_child(title)

	grid_scroll = ScrollContainer.new()
	grid_scroll.custom_minimum_size = Vector2(0, 150)
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	grid_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(grid_scroll)

	legendary_grid = HBoxContainer.new()
	legendary_grid.add_theme_constant_override("separation", 10)
	grid_scroll.add_child(legendary_grid)


func _setup_action_buttons(parent: VBoxContainer) -> void:
	"""Setup action buttons."""
	var buttons_hbox = HBoxContainer.new()
	buttons_hbox.add_theme_constant_override("separation", 10)
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(buttons_hbox)

	equip_button = Button.new()
	equip_button.text = "Equip"
	equip_button.custom_minimum_size = Vector2(100, 35)
	equip_button.pressed.connect(_on_equip_pressed)
	buttons_hbox.add_child(equip_button)

	compare_button = Button.new()
	compare_button.text = "Compare"
	compare_button.custom_minimum_size = Vector2(100, 35)
	compare_button.pressed.connect(_on_compare_pressed)
	buttons_hbox.add_child(compare_button)

	lore_button = Button.new()
	lore_button.text = "Inspect Lore"
	lore_button.custom_minimum_size = Vector2(120, 35)
	lore_button.pressed.connect(_on_lore_pressed)
	buttons_hbox.add_child(lore_button)

	details_button = Button.new()
	details_button.text = "Legend Details"
	details_button.custom_minimum_size = Vector2(120, 35)
	details_button.pressed.connect(_on_details_pressed)
	buttons_hbox.add_child(details_button)


func setup_styling() -> void:
	"""Apply premium styling and visual themes."""
	# Panel styling
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = COLOR_PANEL
	panel_style.border_color = COLOR_GOLD_DARK
	panel_style.set_border_enabled_all(true)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(4)
	panel_style.content_margin_left = 15
	panel_style.content_margin_right = 15
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12

	if main_panel:
		main_panel.add_theme_stylebox_override("panel", panel_style)

	if showcase_panel:
		showcase_panel.add_theme_stylebox_override("panel", panel_style)

	# Progress bar styling for synergy
	if synergy_progress:
		var progress_style = StyleBoxFlat.new()
		progress_style.bg_color = COLOR_PANEL
		synergy_progress.add_theme_stylebox_override("background", progress_style)

		var progress_fill = StyleBoxFlat.new()
		progress_fill.bg_color = Color.GREEN
		synergy_progress.add_theme_stylebox_override("fill", progress_fill)


func collect_legendary_items() -> void:
	"""Collect all legendary items from heir's inventory and equipment."""
	legendary_items.clear()

	# Get items from heir inventory
	if heir and heir.inventory:
		for item in heir.inventory.get_all_items():
			if item is Equipment and item.rarity == Item.Rarity.LEGENDARY:
				legendary_items.append(item)

	# Get equipped legendaries
	if heir_equipment:
		for slot in range(Equipment.EquipmentSlot.MAX):
			var item = heir_equipment.get_item_in_slot(slot)
			if item and item is Equipment and item.rarity == Item.Rarity.LEGENDARY:
				if item not in legendary_items:
					legendary_items.append(item)


func load_legendary_items() -> void:
	"""Load and display the first legendary item."""
	if legendary_items.is_empty():
		item_name_label.text = "No Legendary Items Found"
		return

	apply_current_filter()
	apply_current_sort()

	if not legendary_items.is_empty():
		set_legendary_item(legendary_items[0])
		populate_legendary_grid()


func apply_current_filter() -> void:
	"""Filter legendary items based on current filter."""
	var filtered: Array[Equipment] = []

	for item in legendary_items:
		match current_filter:
			FilterType.ALL:
				filtered.append(item)
			FilterType.EQUIPPED:
				if is_item_equipped(item):
					filtered.append(item)
			FilterType.INVENTORY:
				if not is_item_equipped(item):
					filtered.append(item)
			FilterType.BY_SKILL:
				# Filter by skill type if applicable
				filtered.append(item)
			FilterType.ARTIFACTS:
				if item.get_property("is_artifact", false):
					filtered.append(item)

	legendary_items = filtered


func apply_current_sort() -> void:
	"""Sort legendary items based on current sort."""
	match current_sort:
		SortType.RARITY:
			legendary_items.sort_custom(func(a, b): return a.rarity > b.rarity)
		SortType.ACQUISITION_DATE:
			legendary_items.sort_custom(func(a, b):
				var year_a = a.get_property("generated_year", 0)
				var year_b = b.get_property("generated_year", 0)
				return year_a < year_b
			)
		SortType.POWER_LEVEL:
			legendary_items.sort_custom(func(a, b):
				var power_a = calculate_power_level(a)
				var power_b = calculate_power_level(b)
				return power_a > power_b
			)


func set_legendary_item(item: Equipment) -> void:
	"""Display a legendary item with all details."""
	if not item:
		return

	# Animate entrance
	animate_entrance()

	# Update basic display
	item_name_label.text = "✨ %s ✨" % item.name
	item_subtitle_label.text = "of the %s" % item.get_property("legendary_origin", "Realm")

	# Update information
	rarity_label.text = "⭐ LEGENDARY"
	class_label.text = "Unique One-of-a-Kind"

	var acq_year = item.get_property("generated_year", 0)
	var current_year = heir.year if heir else 0
	var years_ago = current_year - acq_year
	acquisition_label.text = "Year %d (%d generation%s ago)" % [
		acq_year,
		years_ago,
		"s" if years_ago != 1 else ""
	]

	status_label.text = "In Inventory"
	if is_item_equipped(item):
		status_label.text = "Equipped - Main Hand"
		status_label.add_theme_color_override("font_color", COLOR_UNCOMMON)

	# Update stats
	update_stats_display(item)

	# Update synergy
	update_synergy_display(item)

	# Update enchantments
	update_enchantments_display(item)

	# Update legendary effect
	update_legendary_effect_display(item)

	# Update lore
	update_lore_display(item)

	# Update binding
	update_binding_display(item)

	# Update history
	update_history_display(item)


func update_stats_display(item: Equipment) -> void:
	"""Display item stat bonuses."""
	# Clear previous
	for child in stats_container.get_children():
		child.queue_free()

	# Add stat labels
	if item.stat_bonuses:
		for stat_name in item.stat_bonuses:
			var bonus = item.stat_bonuses[stat_name]
			var stat_label = Label.new()
			stat_label.text = "%s: +%d" % [stat_name, bonus]
			stat_label.add_theme_font_size_override("font_size", 11)

			# Color based on value
			var color = COLOR_TEXT
			if bonus > 3:
				color = Color.GREEN
			elif bonus > 1:
				color = Color.YELLOW
			stat_label.add_theme_color_override("font_color", color)
			stats_container.add_child(stat_label)


func update_synergy_display(item: Equipment) -> void:
	"""Display synergy score with visual bar."""
	var synergy_score = item.get_property("legendary_synergy_score", 0.7) as float
	var synergy_percent = int(synergy_score * 100)

	synergy_progress.value = synergy_percent

	# Color based on synergy
	var bar_color = Color.RED
	var desc = "Poor Synergy"
	if synergy_percent >= 85:
		bar_color = Color.GREEN
		desc = "Perfect Synergy"
	elif synergy_percent >= 75:
		bar_color = Color.YELLOW
		desc = "Great Synergy"
	elif synergy_percent >= 60:
		bar_color = Color(1.0, 0.6, 0.2)
		desc = "Good Synergy"

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = bar_color
	synergy_progress.add_theme_stylebox_override("fill", fill_style)

	synergy_label.text = "%s (%d%%)" % [desc, synergy_percent]


func update_enchantments_display(item: Equipment) -> void:
	"""Display item enchantments."""
	# Clear previous
	for child in enchantments_container.get_children():
		child.queue_free()

	var enchantment_ids = item.get_property("enchantments", []) as Array
	if enchantment_ids.is_empty():
		var no_ench = Label.new()
		no_ench.text = "No enchantments"
		enchantments_container.add_child(no_ench)
		return

	for ench_id in enchantment_ids:
		var ench_label = Label.new()
		ench_label.text = "✦ %s - Unique enchantment" % ench_id
		ench_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		ench_label.add_theme_font_size_override("font_size", 10)
		ench_label.add_theme_color_override("font_color", COLOR_GOLD)
		enchantments_container.add_child(ench_label)


func update_legendary_effect_display(item: Equipment) -> void:
	"""Display the unique legendary effect."""
	var effect = item.get_property("legendary_effect", {}) as Dictionary
	if effect.is_empty():
		return

	var effect_name = effect.get("name", "Unknown Effect")
	var effect_desc = effect.get("description", "A powerful effect")

	legendary_effect_name.text = "🔥 %s" % effect_name
	legendary_effect_desc.text = effect_desc


func update_lore_display(item: Equipment) -> void:
	"""Display item lore."""
	var lore = item.description if item.description else "A legendary item with a storied past..."
	lore_text.text = lore


func update_binding_display(item: Equipment) -> void:
	"""Display soulbound binding information."""
	# Clear previous
	for child in binding_container.get_children():
		child.queue_free()

	var is_soulbound = item.get_property("is_soulbound", false)
	if not is_soulbound:
		var unbound = Label.new()
		unbound.text = "Not bound to any bloodline"
		unbound.add_theme_font_size_override("font_size", 11)
		binding_container.add_child(unbound)
		return

	var bloodline = item.get_property("soulbound_bloodline", "Unknown")
	var status = Label.new()
	status.text = "✓ Soulbound to: %s" % bloodline
	status.add_theme_font_size_override("font_size", 11)
	status.add_theme_color_override("font_color", COLOR_UNCOMMON)
	binding_container.add_child(status)

	# Cumulative bonus
	var gen_count = item.get_property("legendary_generation_index", 1)
	var cumulative_bonus = gen_count * 3
	var bonus_label = Label.new()
	bonus_label.text = "Cumulative Bonus: +%d%% (%d generations × 3%%)" % [cumulative_bonus, gen_count]
	bonus_label.add_theme_font_size_override("font_size", 10)
	binding_container.add_child(bonus_label)

	var warning = Label.new()
	warning.text = "⚠ Cannot be traded to other bloodlines"
	warning.add_theme_font_size_override("font_size", 10)
	warning.add_theme_color_override("font_color", Color.YELLOW)
	binding_container.add_child(warning)


func update_history_display(item: Equipment) -> void:
	"""Display item ownership and combat history."""
	var created_year = item.get_property("generated_year", 0)
	created_label.text = "Created: Year %d" % created_year

	# Owner history (placeholder - would come from item history)
	owners_label.text = "Owners: Multiple generations"

	# Combat stats (placeholder)
	battles_label.text = "Battles: 0"
	legendary_kills_label.text = "Legendary Kills: 0"


func populate_legendary_grid() -> void:
	"""Populate grid with thumbnail cards of other legendary items."""
	# Clear previous
	for child in legendary_grid.get_children():
		child.queue_free()

	for item in legendary_items:
		if item == (legendary_items[0] if not legendary_items.is_empty() else null):
			continue  # Skip the main displayed item

		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(110, 120)

		var card_vbox = VBoxContainer.new()
		card.add_child(card_vbox)

		# Item icon/visual (placeholder)
		var icon = Label.new()
		icon.text = "⚔️"
		icon.add_theme_font_size_override("font_size", 32)
		icon.alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_vbox.add_child(icon)

		# Item name
		var name_label = Label.new()
		name_label.text = item.name
		name_label.add_theme_font_size_override("font_size", 9)
		name_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		card_vbox.add_child(name_label)

		# Status
		var status_text = "Inventory"
		if is_item_equipped(item):
			status_text = "Equipped"
		var status = Label.new()
		status.text = status_text
		status.add_theme_font_size_override("font_size", 8)
		status.alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_vbox.add_child(status)

		# Click to select
		var btn = Button.new()
		btn.pressed.connect(_on_grid_item_selected.bindv([item]))
		card.mouse_entered.connect(func(): card.modulate = Color.LIGHT_GRAY)
		card.mouse_exited.connect(func(): card.modulate = Color.WHITE)

		legendary_grid.add_child(card)


func animate_entrance() -> void:
	"""Play entrance animation."""
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(showcase_panel, "modulate:a", 1.0, 0.5)


func calculate_power_level(item: Equipment) -> int:
	"""Calculate item power level based on stats and enchantments."""
	var power = 0

	# Base stat power
	if item.stat_bonuses:
		for stat in item.stat_bonuses:
			power += item.stat_bonuses[stat] * 10

	# Enchantment power
	var ench_count = (item.get_property("enchantments", []) as Array).size()
	power += ench_count * 25

	# Synergy bonus
	var synergy = item.get_property("legendary_synergy_score", 0.7) as float
	power += int(synergy * 100)

	return power


func is_item_equipped(item: Equipment) -> bool:
	"""Check if item is currently equipped."""
	if heir_equipment:
		for slot in range(Equipment.EquipmentSlot.MAX):
			var equipped = heir_equipment.get_item_in_slot(slot)
			if equipped == item:
				return true
	return false


func refresh_item_display() -> void:
	"""Refresh all panels with current item data."""
	if legendary_items.is_empty():
		return
	set_legendary_item(legendary_items[0])


# Signal handlers
func _on_filter_selected(filter: int) -> void:
	"""Handle filter button selection."""
	# Clear previous selection
	for key in filter_buttons:
		filter_buttons[key].button_pressed = false

	# Set new selection
	current_filter = filter
	filter_buttons[filter].button_pressed = true

	# Reapply filters
	load_legendary_items()


func _on_sort_selected(sort: int) -> void:
	"""Handle sort button selection."""
	# Clear previous selection
	for key in sort_buttons:
		sort_buttons[key].button_pressed = false

	# Set new selection
	current_sort = sort
	sort_buttons[sort].button_pressed = true

	# Reapply sort
	apply_current_sort()
	populate_legendary_grid()


func _on_grid_item_selected(item: Equipment) -> void:
	"""Handle legendary item selection from grid."""
	set_legendary_item(item)


func _on_equip_pressed() -> void:
	"""Handle equip button press."""
	if legendary_items.is_empty():
		return

	var item = legendary_items[0]
	legendary_equipped.emit(item)


func _on_compare_pressed() -> void:
	"""Handle compare button press."""
	if legendary_items.size() < 2:
		return

	var item1 = legendary_items[0]
	var item2 = legendary_items[1]
	legendary_compared.emit(item1, item2)


func _on_lore_pressed() -> void:
	"""Handle lore inspection button press."""
	# Would expand lore view or open detailed lore panel
	pass


func _on_details_pressed() -> void:
	"""Handle legend details button press."""
	# Would show procedural generation details and full data
	pass


func _on_close_pressed() -> void:
	"""Handle close button press."""
	showcase_closed.emit()
	queue_free()
