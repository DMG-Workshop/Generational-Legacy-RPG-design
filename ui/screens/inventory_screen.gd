## Inventory Screen: display and manage heir's items
##
## Manages inventory display with filtering, sorting, searching, and item interaction.
## Supports equipping, using, and dropping items with drag-drop capability.

extends Control

class_name InventoryScreen


## Signals emitted when inventory changes
signal item_equipped(item: Item)
signal item_used(item: Item)
signal item_dropped(item: Item)
signal inventory_changed()


## Constants for layout
const ITEMS_PER_ROW: int = 5
const ITEM_CARD_SIZE: Vector2 = Vector2(120, 140)
const DETAILS_PANEL_WIDTH: float = 280.0
const FILTER_BUTTON_HEIGHT: float = 32.0
const SEARCH_BAR_HEIGHT: float = 32.0

## Item type filter options
enum FilterType {
	ALL,
	WEAPONS,
	ARMOR,
	ACCESSORIES,
	CONSUMABLES,
	MATERIALS,
	QUEST_ITEMS
}

## Sort options
enum SortType {
	RARITY,
	TYPE,
	VALUE,
	NAME,
	QUANTITY
}


## Data references
var heir: Heir
var heir_inventory: HeirInventory
var heir_equipment: HeirEquipment

## UI state
var current_filter: FilterType = FilterType.ALL
var current_sort: SortType = SortType.RARITY
var search_text: String = ""
var selected_item: Item = null
var filtered_items: Array[Item] = []

## UI components
var item_grid_container: FlowContainer
var details_panel: PanelContainer
var details_label: Label
var action_buttons_container: HBoxContainer
var equip_button: Button
var use_button: Button
var drop_button: Button
var sell_button: Button
var search_input: LineEdit
var sort_dropdown: OptionButton
var filter_buttons: Dictionary = {}  # FilterType -> Button
var item_cards: Dictionary = {}  # Item -> InventoryItemCard
var empty_state_label: Label


func _init(current_heir: Heir) -> void:
	heir = current_heir
	heir_inventory = HeirInventory.new(heir)
	heir_equipment = HeirEquipment.new(heir)


func _ready() -> void:
	# Setup background
	var bg = ColorRect.new()
	bg.color = Color.BLACK.with_alpha(0.7)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Main container
	var main_container = VBoxContainer.new()
	main_container.anchor_left = 0.05
	main_container.anchor_top = 0.05
	main_container.anchor_right = 0.95
	main_container.anchor_bottom = 0.95
	main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_container)

	# Header section
	_setup_header(main_container)

	# Filter and sort section
	_setup_filters_and_sort(main_container)

	# Search section
	_setup_search_bar(main_container)

	# Main content area (grid + details panel)
	var content_container = HBoxContainer.new()
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(content_container)

	# Item grid (left side)
	_setup_item_grid(content_container)

	# Details panel (right side)
	_setup_details_panel(content_container)

	# Bottom buttons
	_setup_bottom_buttons(main_container)

	# Initial refresh
	refresh_inventory()


## Setup header with heir name and inventory stats
func _setup_header(parent: VBoxContainer) -> void:
	var header_container = VBoxContainer.new()
	header_container.custom_minimum_size = Vector2(0, 60)
	parent.add_child(header_container)

	var title_label = Label.new()
	title_label.text = "Inventory of %s" % heir.name
	title_label.add_theme_font_size_override("font_size", 24)
	header_container.add_child(title_label)

	var stats_label = Label.new()
	var total_items = heir_inventory.get_total_count()
	var total_weight = heir_inventory.get_total_weight()
	var total_value = heir_inventory.get_total_value()
	stats_label.text = "Items: %d | Weight: %.1f lbs | Value: %d cp" % [
		total_items, total_weight, total_value
	]
	header_container.add_child(stats_label)


## Setup filter buttons and sort dropdown
func _setup_filters_and_sort(parent: VBoxContainer) -> void:
	var filter_container = HBoxContainer.new()
	filter_container.custom_minimum_size = Vector2(0, FILTER_BUTTON_HEIGHT + 8)
	parent.add_child(filter_container)

	# Filter buttons
	var filter_options = [
		{"type": FilterType.ALL, "label": "All"},
		{"type": FilterType.WEAPONS, "label": "Weapons"},
		{"type": FilterType.ARMOR, "label": "Armor"},
		{"type": FilterType.ACCESSORIES, "label": "Accessories"},
		{"type": FilterType.CONSUMABLES, "label": "Consumables"},
		{"type": FilterType.MATERIALS, "label": "Materials"},
		{"type": FilterType.QUEST_ITEMS, "label": "Quest Items"},
	]

	for option in filter_options:
		var btn = Button.new()
		btn.text = option["label"]
		btn.custom_minimum_size = Vector2(100, FILTER_BUTTON_HEIGHT)
		btn.toggle_mode = true
		if option["type"] == FilterType.ALL:
			btn.button_pressed = true
		var filter_type = option["type"]
		btn.pressed.connect(func(): _on_filter_changed(filter_type))
		filter_container.add_child(btn)
		filter_buttons[option["type"]] = btn

	filter_container.add_child(VSeparator.new())

	# Sort dropdown
	var sort_label = Label.new()
	sort_label.text = "Sort:"
	sort_label.custom_minimum_size = Vector2(40, FILTER_BUTTON_HEIGHT)
	filter_container.add_child(sort_label)

	sort_dropdown = OptionButton.new()
	sort_dropdown.custom_minimum_size = Vector2(150, FILTER_BUTTON_HEIGHT)
	sort_dropdown.add_item("Rarity (High)", SortType.RARITY)
	sort_dropdown.add_item("Type", SortType.TYPE)
	sort_dropdown.add_item("Value (High)", SortType.VALUE)
	sort_dropdown.add_item("Name (A-Z)", SortType.NAME)
	sort_dropdown.add_item("Quantity (High)", SortType.QUANTITY)
	sort_dropdown.item_selected.connect(_on_sort_changed)
	filter_container.add_child(sort_dropdown)

	filter_container.add_child(Control.new())  # Spacer


## Setup search bar
func _setup_search_bar(parent: VBoxContainer) -> void:
	var search_container = HBoxContainer.new()
	search_container.custom_minimum_size = Vector2(0, SEARCH_BAR_HEIGHT + 4)
	parent.add_child(search_container)

	var search_label = Label.new()
	search_label.text = "Search:"
	search_label.custom_minimum_size = Vector2(60, SEARCH_BAR_HEIGHT)
	search_container.add_child(search_label)

	search_input = LineEdit.new()
	search_input.placeholder_text = "Type to filter items..."
	search_input.custom_minimum_size = Vector2(200, SEARCH_BAR_HEIGHT)
	search_input.text_changed.connect(_on_search_text_changed)
	search_container.add_child(search_input)

	var clear_btn = Button.new()
	clear_btn.text = "Clear"
	clear_btn.custom_minimum_size = Vector2(60, SEARCH_BAR_HEIGHT)
	clear_btn.pressed.connect(func(): search_input.clear())
	search_container.add_child(clear_btn)

	search_container.add_child(Control.new())  # Spacer


## Setup item grid container
func _setup_item_grid(parent: HBoxContainer) -> void:
	var grid_container = PanelContainer.new()
	grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(grid_container)

	var grid_vbox = VBoxContainer.new()
	grid_container.add_child(grid_vbox)

	# Empty state label
	empty_state_label = Label.new()
	empty_state_label.text = "Inventory is empty"
	empty_state_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid_vbox.add_child(empty_state_label)

	# Item grid
	item_grid_container = FlowContainer.new()
	item_grid_container.custom_minimum_size = Vector2(0, 400)
	item_grid_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_grid_container.alignment = FlowContainer.ALIGNMENT_BEGIN
	grid_vbox.add_child(item_grid_container)

	# Add scroll container for better UX
	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.custom_minimum_size = Vector2(0, 400)
	var temp = item_grid_container
	item_grid_container = FlowContainer.new()
	item_grid_container.alignment = FlowContainer.ALIGNMENT_BEGIN
	scroll_container.add_child(item_grid_container)

	# Replace the grid in parent
	grid_vbox.remove_child(empty_state_label)
	grid_vbox.remove_child(temp)
	grid_vbox.add_child(scroll_container)
	grid_vbox.move_child(scroll_container, 1)


## Setup details panel on the right
func _setup_details_panel(parent: HBoxContainer) -> void:
	details_panel = PanelContainer.new()
	details_panel.custom_minimum_size = Vector2(DETAILS_PANEL_WIDTH, 0)
	details_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(details_panel)

	var details_vbox = VBoxContainer.new()
	details_vbox.add_theme_constant_override("separation", 8)
	details_panel.add_child(details_vbox)

	var details_title = Label.new()
	details_title.text = "Item Details"
	details_title.add_theme_font_size_override("font_size", 16)
	details_vbox.add_child(details_title)

	details_label = Label.new()
	details_label.text = "Select an item to view details"
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	details_label.custom_minimum_size = Vector2(0, 200)
	details_vbox.add_child(details_label)

	# Action buttons container
	action_buttons_container = VBoxContainer.new()
	action_buttons_container.add_theme_constant_override("separation", 4)
	details_vbox.add_child(action_buttons_container)

	equip_button = Button.new()
	equip_button.text = "Equip"
	equip_button.custom_minimum_size = Vector2(0, 32)
	equip_button.pressed.connect(_on_equip_button_pressed)
	action_buttons_container.add_child(equip_button)

	use_button = Button.new()
	use_button.text = "Use"
	use_button.custom_minimum_size = Vector2(0, 32)
	use_button.pressed.connect(_on_use_button_pressed)
	action_buttons_container.add_child(use_button)

	drop_button = Button.new()
	drop_button.text = "Drop"
	drop_button.custom_minimum_size = Vector2(0, 32)
	drop_button.pressed.connect(_on_drop_button_pressed)
	action_buttons_container.add_child(drop_button)

	sell_button = Button.new()
	sell_button.text = "Sell"
	sell_button.custom_minimum_size = Vector2(0, 32)
	sell_button.pressed.connect(_on_sell_button_pressed)
	action_buttons_container.add_child(sell_button)

	# Spacer
	details_vbox.add_child(Control.new())


## Setup bottom close button
func _setup_bottom_buttons(parent: VBoxContainer) -> void:
	var button_container = HBoxContainer.new()
	button_container.custom_minimum_size = Vector2(0, 40)
	parent.add_child(button_container)

	button_container.add_child(Control.new())  # Spacer

	var close_btn = Button.new()
	close_btn.text = "Close (ESC)"
	close_btn.custom_minimum_size = Vector2(120, 36)
	close_btn.pressed.connect(_on_close)
	button_container.add_child(close_btn)


## Refresh inventory display based on current filter/sort
func refresh_inventory() -> void:
	# Clear existing cards
	for card in item_cards.values():
		card.queue_free()
	item_cards.clear()
	for child in item_grid_container.get_children():
		child.queue_free()

	# Apply filter
	filtered_items = _apply_filter(heir.inventory)

	# Apply sort
	_apply_sort(filtered_items)

	# Apply search
	filtered_items = _apply_search(filtered_items)

	# Show/hide empty state
	empty_state_label.visible = filtered_items.is_empty()

	# Create item cards
	if not filtered_items.is_empty():
		for item in filtered_items:
			var card = InventoryItemCard.new(item)
			card.item_selected.connect(func(): _on_item_card_selected(card))
			card.item_dragged.connect(func(dragged_item): _on_item_dragged(dragged_item))
			item_grid_container.add_child(card)
			item_cards[item] = card

	# Clear selection if current item was filtered out
	if selected_item and selected_item not in filtered_items:
		selected_item = null
		_update_details_panel()


## Apply current filter to items
func _apply_filter(items: Array[Item]) -> Array[Item]:
	var result: Array[Item] = []
	for item in items:
		if _matches_filter(item):
			result.append(item)
	return result


## Check if item matches current filter
func _matches_filter(item: Item) -> bool:
	if current_filter == FilterType.ALL:
		return true

	match current_filter:
		FilterType.WEAPONS:
			return item.item_type == Item.ItemType.WEAPON
		FilterType.ARMOR:
			return item.item_type == Item.ItemType.ARMOR
		FilterType.ACCESSORIES:
			return item.item_type == Item.ItemType.ACCESSORY
		FilterType.CONSUMABLES:
			return item.item_type == Item.ItemType.CONSUMABLE
		FilterType.MATERIALS:
			return item.item_type == Item.ItemType.CRAFTING_MATERIAL
		FilterType.QUEST_ITEMS:
			return item.item_type == Item.ItemType.QUEST_ITEM
	return false


## Apply current sort to items
func _apply_sort(items: Array[Item]) -> void:
	match current_sort:
		SortType.RARITY:
			items.sort_custom(func(a, b): return a.rarity > b.rarity)
		SortType.TYPE:
			items.sort_custom(func(a, b): return a.item_type < b.item_type)
		SortType.VALUE:
			items.sort_custom(func(a, b): return a.value.to_copper() > b.value.to_copper())
		SortType.NAME:
			items.sort_custom(func(a, b): return a.name < b.name)
		SortType.QUANTITY:
			items.sort_custom(func(a, b): return a.max_stack > b.max_stack)


## Apply search text to filter items
func _apply_search(items: Array[Item]) -> Array[Item]:
	if search_text.is_empty():
		return items

	var result: Array[Item] = []
	var lower_search = search_text.to_lower()
	for item in items:
		if item.name.to_lower().contains(lower_search) or \
		   item.description.to_lower().contains(lower_search):
			result.append(item)
	return result


## Handle filter button pressed
func _on_filter_changed(filter_type: FilterType) -> void:
	# Deselect all other filter buttons
	for btn_type in filter_buttons:
		filter_buttons[btn_type].button_pressed = (btn_type == filter_type)

	current_filter = filter_type
	refresh_inventory()


## Handle sort dropdown changed
func _on_sort_changed(index: int) -> void:
	current_sort = sort_dropdown.get_item_metadata(index)
	refresh_inventory()


## Handle search text changed
func _on_search_text_changed(new_text: String) -> void:
	search_text = new_text
	refresh_inventory()


## Handle item card selected
func _on_item_card_selected(card: InventoryItemCard) -> void:
	# Deselect previous card
	if selected_item and selected_item in item_cards:
		item_cards[selected_item].set_selected(false)

	selected_item = card.item
	card.set_selected(true)
	_update_details_panel()


## Update details panel with selected item info
func _update_details_panel() -> void:
	if not selected_item:
		details_label.text = "Select an item to view details"
		equip_button.disabled = true
		use_button.disabled = true
		drop_button.disabled = true
		sell_button.disabled = true
		return

	# Build details text
	var details_text = ""
	details_text += "%s\n" % selected_item.to_string()
	details_text += "\n"
	details_text += "Type: %s\n" % selected_item.get_type_name()
	details_text += "Rarity: %s\n" % selected_item.get_rarity_name()

	if not selected_item.description.is_empty():
		details_text += "\nDescription:\n%s\n" % selected_item.description

	details_text += "\nValue: %s\n" % selected_item.value.to_string()
	details_text += "Weight: %.1f lbs\n" % selected_item.weight

	if selected_item.item_type in [Item.ItemType.WEAPON, Item.ItemType.ARMOR]:
		details_text += "\nDurability: %d/%d (%.0f%%)\n" % [
			selected_item.current_durability,
			selected_item.max_durability,
			selected_item.get_durability_percent()
		]

	if selected_item.is_stackable:
		details_text += "Max Stack: %d\n" % selected_item.max_stack

	if selected_item.is_cursed:
		details_text += "\n[CURSED ITEM]"

	details_label.text = details_text

	# Update button states
	equip_button.disabled = not selected_item.can_equip()
	use_button.disabled = not selected_item.can_use()
	drop_button.disabled = false
	sell_button.disabled = not selected_item.can_sell()


## Handle equip button pressed
func _on_equip_button_pressed() -> void:
	if not selected_item or not selected_item.can_equip():
		return

	# TODO: Show equipment slot selection dialog
	# For now, equip to main hand for weapons or first available armor slot
	print("Equipping: %s" % selected_item.name)
	item_equipped.emit(selected_item)


## Handle use button pressed
func _on_use_button_pressed() -> void:
	if not selected_item or not selected_item.can_use():
		return

	print("Using: %s" % selected_item.name)
	heir_inventory.remove_item(selected_item)
	item_used.emit(selected_item)
	refresh_inventory()


## Handle drop button pressed
func _on_drop_button_pressed() -> void:
	if not selected_item:
		return

	print("Dropping: %s" % selected_item.name)
	heir_inventory.remove_item(selected_item)
	item_dropped.emit(selected_item)
	refresh_inventory()


## Handle sell button pressed
func _on_sell_button_pressed() -> void:
	if not selected_item or not selected_item.can_sell():
		return

	print("Selling: %s for %s" % [selected_item.name, selected_item.value.to_string()])
	heir_inventory.remove_item(selected_item)
	# TODO: Add currency to heir.wallet
	refresh_inventory()


## Handle item dragged for drag-drop equipping
func _on_item_dragged(item: Item) -> void:
	# TODO: Implement drag-drop to equipment slots
	print("Item dragged: %s" % item.name)


## Handle close button
func _on_close() -> void:
	get_tree().root.get_child(0).show_screen("world")


## Handle ESC key
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_I:
			_on_close()


## Inner class for individual item display cards
class InventoryItemCard:
	extends PanelContainer

	signal item_selected
	signal item_dragged(item: Item)

	var item: Item
	var is_selected: bool = false

	func _init(p_item: Item) -> void:
		item = p_item
		custom_minimum_size = ITEM_CARD_SIZE
		mouse_filter = Control.MOUSE_FILTER_STOP

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		add_child(vbox)

		# Item name
		var name_label = Label.new()
		name_label.text = item.name
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.custom_minimum_size = Vector2(0, 24)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(name_label)

		# Rarity badge
		var rarity_label = Label.new()
		rarity_label.text = item.get_rarity_name()
		rarity_label.add_theme_font_size_override("font_size", 10)
		rarity_label.add_theme_color_override("font_color", item.get_rarity_color())
		rarity_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(rarity_label)

		# Quantity if stackable
		if item.is_stackable:
			var qty_label = Label.new()
			qty_label.text = "x%d" % item.max_stack
			qty_label.add_theme_font_size_override("font_size", 10)
			qty_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(qty_label)

		# Type info
		var type_label = Label.new()
		type_label.text = item.get_type_name()
		type_label.add_theme_font_size_override("font_size", 9)
		type_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(type_label)

		# Durability bar if applicable
		if item.item_type in [Item.ItemType.WEAPON, Item.ItemType.ARMOR]:
			var durability_bar = ProgressBar.new()
			durability_bar.value = item.get_durability_percent()
			durability_bar.custom_minimum_size = Vector2(0, 8)
			vbox.add_child(durability_bar)

		vbox.add_child(Control.new())  # Spacer

	func _ready() -> void:
		gui_input.connect(_on_gui_input)
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)

	func _on_gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				item_selected.emit()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				item_dragged.emit(item)

	func _on_mouse_entered() -> void:
		if not is_selected:
			modulate = Color.WHITE * 1.1

	func _on_mouse_exited() -> void:
		if not is_selected:
			modulate = Color.WHITE

	func set_selected(selected: bool) -> void:
		is_selected = selected
		if selected:
			modulate = Color.YELLOW
			add_theme_stylebox_override("panel", _get_selected_stylebox())
		else:
			modulate = Color.WHITE
			add_theme_stylebox_override("panel", StyleBoxFlat.new())

	func _get_selected_stylebox() -> StyleBox:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 0, 0.2)
		style.border_color = Color.YELLOW
		style.set_border_enabled_all(true)
		style.set_border_width_all(2)
		return style
