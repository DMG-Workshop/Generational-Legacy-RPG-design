## Battle Rewards Screen: Display loot, currency, and XP from combat
##
## Shows earned rewards after victory including currency, experience, and loot drops.
## Features animated currency/XP counting, legendary item showcase, and item inspection.
## Emits signals when rewards are collected to integrate with battle and inventory systems.

extends Control

class_name BattleRewardsScreen


# Signals for integration with battle system
signal rewards_closed(data: Dictionary)
signal item_inspected(item: Equipment)
signal legendary_found(item: Equipment)


# Color constants for rarity display
const COLOR_LEGENDARY = Color(1.0, 0.843, 0.0)
const COLOR_VERY_RARE = Color(0.616, 0.267, 0.961)
const COLOR_RARE = Color(0.2, 0.6, 1.0)
const COLOR_UNCOMMON = Color(0.2, 0.8, 0.2)
const COLOR_COMMON = Color(0.5, 0.5, 0.5)
const COLOR_GOLD = Color(0.831, 0.686, 0.216)
const COLOR_BACKGROUND = Color(0.08, 0.04, 0.12)
const COLOR_PANEL = Color(0.12, 0.06, 0.16)
const COLOR_TEXT = Color(0.9, 0.9, 0.95)

# Layout constants
const ITEM_CARD_SIZE: Vector2 = Vector2(140, 160)
const ITEMS_PER_ROW: int = 6
const ANIMATION_DURATION: float = 1.5
const CURRENCY_COUNT_DURATION: float = 2.0


# Data storage
var collected_items: Array[Equipment] = []
var legendary_item: Equipment = null
var reward_data: Dictionary = {
	"items": [],
	"currency": null,
	"xp": {},
	"combat_stats": {}
}

# UI components - Header
var header_label: Label
var enemy_name_label: Label
var difficulty_label: Label
var summary_label: Label

# UI components - Currency
var currency_container: VBoxContainer
var total_value_label: Label
var currency_items: Dictionary = {}  # Currency type -> Label with animated value

# UI components - Experience
var xp_container: VBoxContainer
var xp_items: Dictionary = {}  # Skill -> Label with animated value
var xp_bar: ProgressBar
var level_up_labels: Array[Label] = []

# UI components - Loot
var loot_container: VBoxContainer
var equipment_section: VBoxContainer
var consumables_section: VBoxContainer
var materials_section: VBoxContainer
var legendary_section: VBoxContainer
var item_cards: Dictionary = {}  # Equipment -> ItemCard

# UI components - Legendary showcase
var legendary_showcase: PanelContainer
var legendary_name_label: Label
var legendary_effect_label: Label
var legendary_inspect_button: Button

# UI components - Statistics
var stats_container: VBoxContainer
var stats_labels: Dictionary = {}

# UI components - Action buttons
var take_all_button: Button
var inspect_items_button: Button
var compare_button: Button
var continue_button: Button

# State tracking
var is_collecting: bool = false
var collected_count: int = 0


func _ready() -> void:
	setup_ui()


## Main setup for all UI elements
func setup_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COLOR_BACKGROUND.with_alpha(0.9)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Main scroll container for all content
	var scroll_container = ScrollContainer.new()
	scroll_container.anchor_right = 1.0
	scroll_container.anchor_bottom = 1.0
	add_child(scroll_container)

	# Main VBox for all content
	var main_vbox = VBoxContainer.new()
	main_vbox.anchor_right = 1.0
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 12)
	scroll_container.add_child(main_vbox)

	# Setup sections
	_setup_header(main_vbox)
	_setup_currency_section(main_vbox)
	_setup_experience_section(main_vbox)
	_setup_loot_section(main_vbox)
	_setup_legendary_section(main_vbox)
	_setup_statistics_section(main_vbox)
	_setup_action_buttons(main_vbox)


## Setup rewards header with title and combat summary
func _setup_header(parent: VBoxContainer) -> void:
	var header_panel = PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel", _create_panel_style(COLOR_PANEL))
	header_panel.custom_minimum_size = Vector2(0, 100)
	parent.add_child(header_panel)

	var header_vbox = VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 6)
	header_panel.add_child(header_vbox)

	# Victory title with sparkle emoji
	header_label = Label.new()
	header_label.text = "✨ VICTORY! BATTLE REWARDS ✨"
	header_label.add_theme_font_size_override("font_size", 28)
	header_label.add_theme_color_override("font_color", COLOR_LEGENDARY)
	header_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_vbox.add_child(header_label)

	# Enemy defeated info
	enemy_name_label = Label.new()
	enemy_name_label.text = "Enemy: Unknown"
	enemy_name_label.add_theme_font_size_override("font_size", 16)
	header_vbox.add_child(enemy_name_label)

	# Difficulty badge
	difficulty_label = Label.new()
	difficulty_label.text = "Difficulty: NORMAL"
	difficulty_label.add_theme_font_size_override("font_size", 14)
	difficulty_label.add_theme_color_override("font_color", COLOR_UNCOMMON)
	header_vbox.add_child(difficulty_label)

	# Combat summary
	summary_label = Label.new()
	summary_label.text = "Duration: 3m 24s | Rounds: 8 | Allies: 4 | Enemies: 2"
	summary_label.add_theme_font_size_override("font_size", 12)
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	header_vbox.add_child(summary_label)


## Setup currency collection display with animation
func _setup_currency_section(parent: VBoxContainer) -> void:
	var section_panel = PanelContainer.new()
	section_panel.add_theme_stylebox_override("panel", _create_panel_style(COLOR_PANEL))
	parent.add_child(section_panel)

	currency_container = VBoxContainer.new()
	currency_container.add_theme_constant_override("separation", 8)
	section_panel.add_child(currency_container)

	# Section title
	var title = Label.new()
	title.text = "💰 Currency Earned"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	currency_container.add_child(title)

	# Total value at top
	total_value_label = Label.new()
	total_value_label.text = "Total Value: 0g"
	total_value_label.add_theme_font_size_override("font_size", 14)
	total_value_label.add_theme_color_override("font_color", COLOR_GOLD)
	currency_container.add_child(total_value_label)

	# Individual currency items (Platinum, Gold, Silver, Copper)
	for currency_type in ["Platinum", "Gold", "Silver", "Copper"]:
		var currency_label = Label.new()
		currency_label.text = "%s: +0" % currency_type
		currency_label.add_theme_font_size_override("font_size", 12)
		match currency_type:
			"Platinum":
				currency_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
				currency_label.text = "⭐ Platinum: +0"
			"Gold":
				currency_label.add_theme_color_override("font_color", COLOR_GOLD)
				currency_label.text = "🔖 Gold: +0"
			"Silver":
				currency_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
				currency_label.text = "💎 Silver: +0"
			"Copper":
				currency_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
				currency_label.text = "🪙 Copper: +0"
		currency_container.add_child(currency_label)
		currency_items[currency_type] = currency_label


## Setup experience gains display with level-up notifications
func _setup_experience_section(parent: VBoxContainer) -> void:
	var section_panel = PanelContainer.new()
	section_panel.add_theme_stylebox_override("panel", _create_panel_style(COLOR_PANEL))
	parent.add_child(section_panel)

	xp_container = VBoxContainer.new()
	xp_container.add_theme_constant_override("separation", 8)
	section_panel.add_child(xp_container)

	# Section title
	var title = Label.new()
	title.text = "⚔ Experience Gained"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.4, 1.0, 1.0))
	xp_container.add_child(title)

	# XP bar
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(0, 24)
	xp_bar.max_value = 100
	xp_bar.value = 50
	xp_container.add_child(xp_bar)

	# Individual XP by skill (placeholder - will be populated)
	var skills = ["Combat", "Crafting", "Magic", "Survival"]
	for skill in skills:
		var skill_label = Label.new()
		skill_label.text = "%s: +0 XP" % skill
		skill_label.add_theme_font_size_override("font_size", 12)
		match skill:
			"Combat":
				skill_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				skill_label.text = "⚔ Combat: +0 XP"
			"Crafting":
				skill_label.add_theme_color_override("font_color", COLOR_GOLD)
				skill_label.text = "⛏ Crafting: +0 XP"
			"Magic":
				skill_label.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0))
				skill_label.text = "✨ Magic: +0 XP"
			"Survival":
				skill_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
				skill_label.text = "🌲 Survival: +0 XP"
		xp_container.add_child(skill_label)
		xp_items[skill] = skill_label


## Setup loot display grid with sections for equipment, consumables, materials
func _setup_loot_section(parent: VBoxContainer) -> void:
	var section_panel = PanelContainer.new()
	section_panel.add_theme_stylebox_override("panel", _create_panel_style(COLOR_PANEL))
	parent.add_child(section_panel)

	loot_container = VBoxContainer.new()
	loot_container.add_theme_constant_override("separation", 12)
	section_panel.add_child(loot_container)

	# Section title
	var title = Label.new()
	title.text = "🎁 Loot Dropped"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", COLOR_RARE)
	loot_container.add_child(title)

	# Equipment section
	equipment_section = _create_loot_section("⚔ Equipment", loot_container)

	# Consumables section
	consumables_section = _create_loot_section("🧪 Consumables", loot_container)

	# Materials section
	materials_section = _create_loot_section("📦 Materials", loot_container)


## Helper to create a loot subsection
func _create_loot_section(title_text: String, parent: VBoxContainer) -> VBoxContainer:
	var subsection_vbox = VBoxContainer.new()
	subsection_vbox.add_theme_constant_override("separation", 6)

	var subsection_title = Label.new()
	subsection_title.text = title_text
	subsection_title.add_theme_font_size_override("font_size", 14)
	subsection_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	subsection_vbox.add_child(subsection_title)

	# Grid for items in this section
	var item_grid = GridContainer.new()
	item_grid.columns = ITEMS_PER_ROW
	subsection_vbox.add_child(item_grid)

	parent.add_child(subsection_vbox)
	return subsection_vbox


## Setup legendary item special showcase section
func _setup_legendary_section(parent: VBoxContainer) -> void:
	legendary_section = VBoxContainer.new()
	legendary_section.visible = false
	legendary_section.add_theme_constant_override("separation", 8)
	parent.add_child(legendary_section)

	legendary_showcase = PanelContainer.new()
	legendary_showcase.add_theme_stylebox_override("panel", _create_panel_style(COLOR_LEGENDARY.with_alpha(0.3)))
	legendary_section.add_child(legendary_showcase)

	var showcase_vbox = VBoxContainer.new()
	showcase_vbox.add_theme_constant_override("separation", 6)
	legendary_showcase.add_child(showcase_vbox)

	# Legendary badge
	var legendary_badge = Label.new()
	legendary_badge.text = "✨ ONE-OF-A-KIND LEGENDARY ITEM! ✨"
	legendary_badge.add_theme_font_size_override("font_size", 16)
	legendary_badge.add_theme_color_override("font_color", COLOR_LEGENDARY)
	legendary_badge.alignment = HORIZONTAL_ALIGNMENT_CENTER
	showcase_vbox.add_child(legendary_badge)

	# Item name
	legendary_name_label = Label.new()
	legendary_name_label.text = "Legendary Item Name"
	legendary_name_label.add_theme_font_size_override("font_size", 18)
	legendary_name_label.add_theme_color_override("font_color", COLOR_LEGENDARY)
	showcase_vbox.add_child(legendary_name_label)

	# Item effect
	legendary_effect_label = Label.new()
	legendary_effect_label.text = "Special effect description"
	legendary_effect_label.add_theme_font_size_override("font_size", 12)
	legendary_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	showcase_vbox.add_child(legendary_effect_label)

	# Inspect button
	legendary_inspect_button = PolishedButton.new()
	legendary_inspect_button.text = "Inspect Legendary Item →"
	legendary_inspect_button.custom_minimum_size = Vector2(0, 32)
	legendary_inspect_button.pressed.connect(_on_legendary_inspect)
	showcase_vbox.add_child(legendary_inspect_button)


## Setup statistics summary display
func _setup_statistics_section(parent: VBoxContainer) -> void:
	var section_panel = PanelContainer.new()
	section_panel.add_theme_stylebox_override("panel", _create_panel_style(COLOR_PANEL))
	parent.add_child(section_panel)

	stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 6)
	section_panel.add_child(stats_container)

	# Section title
	var title = Label.new()
	title.text = "📊 Battle Statistics"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	stats_container.add_child(title)

	# Stats grid
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 20)
	stats_grid.add_theme_constant_override("v_separation", 4)
	stats_container.add_child(stats_grid)

	# Create stat labels (all initialized to 0)
	var stat_names = [
		"Damage Dealt",
		"Damage Taken",
		"Healing Received",
		"Abilities Used",
		"Enemies Defeated",
		"Allies Defeated",
		"Most Valuable Item",
		"Legendary Drop Rate"
	]

	for stat_name in stat_names:
		var stat_label = Label.new()
		stat_label.text = "%s: --" % stat_name
		stat_label.add_theme_font_size_override("font_size", 11)
		stats_grid.add_child(stat_label)
		stats_labels[stat_name] = stat_label


## Setup bottom action buttons
func _setup_action_buttons(parent: VBoxContainer) -> void:
	var button_container = HBoxContainer.new()
	button_container.custom_minimum_size = Vector2(0, 50)
	button_container.add_theme_constant_override("separation", 10)
	parent.add_child(button_container)

	button_container.add_child(Control.new())  # Spacer

	# Take All button
	take_all_button = PolishedButton.new()
	take_all_button.text = "Take All"
	take_all_button.custom_minimum_size = Vector2(120, 40)
	take_all_button.pressed.connect(_on_take_all_pressed)
	button_container.add_child(take_all_button)

	# Inspect Items button
	inspect_items_button = PolishedButton.new()
	inspect_items_button.text = "Inspect Items"
	inspect_items_button.custom_minimum_size = Vector2(140, 40)
	inspect_items_button.pressed.connect(_on_inspect_items_pressed)
	button_container.add_child(inspect_items_button)

	# Compare Equipment button
	compare_button = PolishedButton.new()
	compare_button.text = "Compare Equipment"
	compare_button.custom_minimum_size = Vector2(160, 40)
	compare_button.pressed.connect(_on_compare_pressed)
	button_container.add_child(compare_button)

	# Continue button (primary action)
	continue_button = PolishedButton.new()
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(120, 40)
	continue_button.add_theme_color_override("font_color", COLOR_LEGENDARY)
	continue_button.pressed.connect(_on_continue_pressed)
	button_container.add_child(continue_button)

	button_container.add_child(Control.new())  # Spacer


## Public: Set rewards data from battle system
func set_rewards(items: Array, currency: Dictionary = {}, xp: Dictionary = {},
		combat_stats: Dictionary = {}) -> void:
	reward_data = {
		"items": items,
		"currency": currency,
		"xp": xp,
		"combat_stats": combat_stats
	}
	collected_items.clear()
	legendary_item = null
	refresh_displays()


## Public: Display the rewards screen
func show_rewards() -> void:
	visible = true
	if not is_collecting:
		animate_currency_collection()


## Public: Get the items that were collected
func get_collected_items() -> Array[Equipment]:
	return collected_items


## Public: Animate currency collection with count-up effect
func animate_currency_collection() -> void:
	if is_collecting:
		return

	is_collecting = true

	# Count up each currency type
	if "Platinum" in reward_data["currency"]:
		_animate_count(currency_items["Platinum"], 0, reward_data["currency"]["Platinum"], "⭐ Platinum: +%d")

	if "Gold" in reward_data["currency"]:
		_animate_count(currency_items["Gold"], 0, reward_data["currency"]["Gold"], "🔖 Gold: +%d")

	if "Silver" in reward_data["currency"]:
		_animate_count(currency_items["Silver"], 0, reward_data["currency"]["Silver"], "💎 Silver: +%d")

	if "Copper" in reward_data["currency"]:
		_animate_count(currency_items["Copper"], 0, reward_data["currency"]["Copper"], "🪙 Copper: +%d")

	# Play coin collect sound
	_play_sound("coin_collect")
	is_collecting = false


## Public: Highlight a legendary item with special effects
func highlight_legendary(item: Equipment) -> void:
	if not item:
		return

	legendary_item = item
	legendary_section.visible = true
	legendary_name_label.text = item.name
	legendary_effect_label.text = "A legendary artifact of immense power..."

	# Add glow animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(legendary_showcase, "modulate", COLOR_LEGENDARY, 0.6)
	tween.tween_property(legendary_showcase, "modulate", Color.WHITE, 0.6)

	# Emit signal
	legendary_found.emit({"item": item})
	_play_sound("legendary_drop")


## Public: Refresh all displays with current data
func refresh_displays() -> void:
	_populate_loot_grid()
	_update_statistics()


## Populate loot grid with items from reward data
func _populate_loot_grid() -> void:
	# Clear existing cards
	for card in item_cards.values():
		card.queue_free()
	item_cards.clear()

	# Clear section grids
	for child in equipment_section.get_children():
		if child is GridContainer:
			for item in child.get_children():
				item.queue_free()

	for child in consumables_section.get_children():
		if child is GridContainer:
			for item in child.get_children():
				item.queue_free()

	for child in materials_section.get_children():
		if child is GridContainer:
			for item in child.get_children():
				item.queue_free()

	# Get grids from sections
	var equipment_grid = null
	var consumables_grid = null
	var materials_grid = null

	for child in equipment_section.get_children():
		if child is GridContainer:
			equipment_grid = child
	for child in consumables_section.get_children():
		if child is GridContainer:
			consumables_grid = child
	for child in materials_section.get_children():
		if child is GridContainer:
			materials_grid = child

	# Populate with items
	for item in reward_data["items"]:
		var card = _create_item_card(item)
		item_cards[item] = card

		# Add to appropriate section
		if item.item_type == Equipment.ItemType.WEAPON or \
		   item.item_type == Equipment.ItemType.ARMOR or \
		   item.item_type == Equipment.ItemType.ACCESSORY:
			if equipment_grid:
				equipment_grid.add_child(card)
		elif item.item_type == Equipment.ItemType.CONSUMABLE:
			if consumables_grid:
				consumables_grid.add_child(card)
		else:
			if materials_grid:
				materials_grid.add_child(card)

		# Check if legendary
		if item.rarity >= 4:  # Legendary
			highlight_legendary(item)


## Create an item card for display in the grid
func _create_item_card(item: Equipment) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = ITEM_CARD_SIZE
	card.add_theme_stylebox_override("panel", _create_panel_style(COLOR_PANEL))
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	# Item icon (emoji based on type)
	var icon_label = Label.new()
	match item.item_type:
		Equipment.ItemType.WEAPON:
			icon_label.text = "⚔"
		Equipment.ItemType.ARMOR:
			icon_label.text = "🛡"
		Equipment.ItemType.ACCESSORY:
			icon_label.text = "💍"
		Equipment.ItemType.CONSUMABLE:
			icon_label.text = "🧪"
		_:
			icon_label.text = "📦"
	icon_label.add_theme_font_size_override("font_size", 24)
	icon_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon_label)

	# Item name
	var name_label = Label.new()
	name_label.text = item.name
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(name_label)

	# Rarity badge
	var rarity_label = Label.new()
	rarity_label.text = _get_rarity_text(item.rarity)
	rarity_label.add_theme_font_size_override("font_size", 10)
	rarity_label.add_theme_color_override("font_color", _get_rarity_color(item.rarity))
	rarity_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(rarity_label)

	# Item type
	var type_label = Label.new()
	type_label.text = _get_type_text(item.item_type)
	type_label.add_theme_font_size_override("font_size", 9)
	type_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_label)

	# Value in gold
	var value_label = Label.new()
	value_label.text = "Worth: %dg" % item.value
	value_label.add_theme_font_size_override("font_size", 10)
	value_label.add_theme_color_override("font_color", COLOR_GOLD)
	vbox.add_child(value_label)

	# Legendary indicator
	if item.rarity >= 4:
		var legendary_badge = Label.new()
		legendary_badge.text = "✨ LEGENDARY!"
		legendary_badge.add_theme_font_size_override("font_size", 10)
		legendary_badge.add_theme_color_override("font_color", COLOR_LEGENDARY)
		legendary_badge.alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(legendary_badge)

	vbox.add_child(Control.new())  # Spacer

	# Connect click event
	card.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				item_inspected.emit({"item": item})
	)

	return card


## Update statistics display
func _update_statistics() -> void:
	var stats = reward_data["combat_stats"]

	if "damage_dealt" in stats:
		stats_labels["Damage Dealt"].text = "Damage Dealt: %d" % stats["damage_dealt"]
	if "damage_taken" in stats:
		stats_labels["Damage Taken"].text = "Damage Taken: %d" % stats["damage_taken"]
	if "healing_received" in stats:
		stats_labels["Healing Received"].text = "Healing Received: %d" % stats["healing_received"]
	if "abilities_used" in stats:
		stats_labels["Abilities Used"].text = "Abilities Used: %d" % stats["abilities_used"]
	if "enemies_defeated" in stats:
		stats_labels["Enemies Defeated"].text = "Enemies Defeated: %d" % stats["enemies_defeated"]
	if "allies_defeated" in stats:
		stats_labels["Allies Defeated"].text = "Allies Defeated: %d" % stats["allies_defeated"]
	if "most_valuable_item" in stats:
		stats_labels["Most Valuable Item"].text = "Most Valuable Item: %s" % stats["most_valuable_item"]
	if "legendary_drop_rate" in stats:
		stats_labels["Legendary Drop Rate"].text = "Legendary Drop Rate: %.1f%%" % stats["legendary_drop_rate"]


## Animate a number counting up from start to end
func _animate_count(label: Label, start: int, end: int, format_string: String) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)

	var current = start
	tween.tween_method(func(value: float):
		current = int(value)
		label.text = format_string % current
	, float(start), float(end), CURRENCY_COUNT_DURATION)


## Handle Take All button
func _on_take_all_pressed() -> void:
	collected_items = reward_data["items"].duplicate()
	_play_sound("item_collect")
	take_all_button.disabled = true


## Handle Inspect Items button
func _on_inspect_items_pressed() -> void:
	# TODO: Open item inspection dialog
	print("Opening item inspection dialog...")
	_play_sound("ui_select")


## Handle Compare Equipment button
func _on_compare_pressed() -> void:
	# TODO: Open comparison dialog for legendary items
	if legendary_item:
		print("Comparing legendary item with equipped gear...")
	_play_sound("ui_select")


## Handle Continue button
func _on_continue_pressed() -> void:
	visible = false
	rewards_closed.emit({
		"items": collected_items,
		"currency": reward_data["currency"],
		"xp": reward_data["xp"]
	})


## Handle legendary item inspection
func _on_legendary_inspect() -> void:
	if legendary_item:
		item_inspected.emit({"item": legendary_item})


## Play a sound effect
func _play_sound(sound_name: String) -> void:
	# TODO: Integrate with audio system
	print("Playing sound: %s" % sound_name)


## Get rarity text from rarity level
func _get_rarity_text(rarity: int) -> String:
	match rarity:
		0:
			return "Common"
		1:
			return "Uncommon"
		2:
			return "Rare"
		3:
			return "Very Rare"
		4:
			return "Legendary"
		_:
			return "Unknown"


## Get rarity color from rarity level
func _get_rarity_color(rarity: int) -> Color:
	match rarity:
		0:
			return COLOR_COMMON
		1:
			return COLOR_UNCOMMON
		2:
			return COLOR_RARE
		3:
			return COLOR_VERY_RARE
		4:
			return COLOR_LEGENDARY
		_:
			return Color.WHITE


## Get item type text
func _get_type_text(item_type: int) -> String:
	match item_type:
		Equipment.ItemType.WEAPON:
			return "Weapon"
		Equipment.ItemType.ARMOR:
			return "Armor"
		Equipment.ItemType.ACCESSORY:
			return "Accessory"
		Equipment.ItemType.CONSUMABLE:
			return "Consumable"
		_:
			return "Item"


## Helper: Create a stylebox for panels
func _create_panel_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_enabled_all(true)
	style.set_border_width_all(1)
	style.border_color = Color(1, 1, 1, 0.2)
	return style
