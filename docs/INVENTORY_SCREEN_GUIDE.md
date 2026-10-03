# Inventory Screen UI Component Guide

## Overview

The `InventoryScreen` is a comprehensive UI component for displaying, filtering, sorting, and managing a character's inventory. It provides:

- **Item Display Grid**: Visual cards for each item with rarity color coding
- **Dynamic Filtering**: Filter by item type (weapons, armor, consumables, etc.)
- **Sorting Options**: Sort by rarity, type, value, name, or quantity
- **Real-time Search**: Case-insensitive search by item name or description
- **Item Details Panel**: View detailed information about selected items
- **Action Buttons**: Equip, use, drop, or sell items
- **Responsive Design**: Adapts to different screen sizes
- **Signal Integration**: Emits signals for inventory changes

## File Location

- **Main Component**: `ui/screens/inventory_screen.gd`
- **Integration**: Registered in `ui/main_game.gd`
- **Tests**: `tests/test_inventory_screen.gd`

## Quick Start

### Opening the Inventory Screen

From any screen, call:

```gdscript
var main_game = get_tree().root.get_child(0)
main_game.show_screen("inventory")
```

Or programmatically:

```gdscript
var inventory = InventoryScreen.new(heir)
add_child(inventory)
```

### Basic Usage

```gdscript
# Create inventory screen for a specific heir
var inventory_screen = InventoryScreen.new(heir)

# Connect to signals to react to item actions
inventory_screen.item_equipped.connect(_on_item_equipped)
inventory_screen.item_used.connect(_on_item_used)
inventory_screen.item_dropped.connect(_on_item_dropped)

# Add to scene tree
add_child(inventory_screen)
```

## Component Structure

### Main Class: InventoryScreen

**Extends**: Control

**Key Properties**:
- `heir: Heir` - The character whose inventory is displayed
- `heir_inventory: HeirInventory` - Inventory helper class
- `heir_equipment: HeirEquipment` - Equipment helper class
- `current_filter: FilterType` - Active filter type
- `current_sort: SortType` - Active sort type
- `search_text: String` - Current search filter text
- `selected_item: Item` - Currently selected item
- `filtered_items: Array[Item]` - Items after applying all filters

### Nested Class: InventoryItemCard

**Extends**: PanelContainer

Represents a single item in the inventory grid.

**Features**:
- Shows item name, rarity, type, and quantity
- Displays durability bar for weapons/armor
- Color-coded by rarity
- Hover effects for feedback
- Selection highlight with yellow border
- Signals for selection and drag events

## Enumerations

### FilterType

```gdscript
enum FilterType {
    ALL,              # Show all items
    WEAPONS,          # Show weapons only
    ARMOR,            # Show armor only
    ACCESSORIES,      # Show accessories only
    CONSUMABLES,      # Show consumables only
    MATERIALS,        # Show crafting materials only
    QUEST_ITEMS       # Show quest items only
}
```

### SortType

```gdscript
enum SortType {
    RARITY,      # Sort by rarity (highest first)
    TYPE,        # Sort by item type
    VALUE,       # Sort by monetary value (highest first)
    NAME,        # Sort alphabetically (A-Z)
    QUANTITY     # Sort by stack size (highest first)
}
```

## UI Layout

### Header Section
- Displays heir name and inventory statistics
- Shows total item count, weight, and value

### Filter & Sort Section
- Row of filter buttons (All, Weapons, Armor, etc.)
- Sort dropdown menu with 5 options
- Search bar with clear button

### Main Content Area
- **Left Panel**: Grid of item cards (scrollable)
  - Items arranged in flow layout
  - 4-6 items per row depending on screen size
  - Empty state message if inventory is empty

- **Right Panel**: Details panel
  - Shows detailed information about selected item
  - Displays item stats, durability, description
  - Action buttons (context-sensitive)
  - Spacer for balance

### Bottom Section
- Close button (ESC to close)

## Filtering & Sorting

### Filter Examples

```gdscript
# Filter by weapon type
inventory_screen._on_filter_changed(InventoryScreen.FilterType.WEAPONS)

# Filter by consumables
inventory_screen._on_filter_changed(InventoryScreen.FilterType.CONSUMABLES)

# Show all items
inventory_screen._on_filter_changed(InventoryScreen.FilterType.ALL)
```

### Sort Examples

```gdscript
# Sort by rarity (highest first)
inventory_screen.current_sort = InventoryScreen.SortType.RARITY
inventory_screen.refresh_inventory()

# Sort alphabetically
inventory_screen.current_sort = InventoryScreen.SortType.NAME
inventory_screen.refresh_inventory()

# Sort by value
inventory_screen.current_sort = InventoryScreen.SortType.VALUE
inventory_screen.refresh_inventory()
```

### Search Examples

```gdscript
# Search for items with "sword" in name
inventory_screen.search_text = "sword"
inventory_screen.refresh_inventory()

# Clear search
inventory_screen.search_text = ""
inventory_screen.refresh_inventory()
```

## Item Actions

### Equip Item

```gdscript
inventory_screen.selected_item = some_item
inventory_screen._on_equip_button_pressed()
```

**Behavior**:
- Only works for weapons, armor, and accessories
- Emits `item_equipped` signal
- Note: Equipment slot selection not yet implemented

### Use Item

```gdscript
inventory_screen.selected_item = potion
inventory_screen._on_use_button_pressed()
```

**Behavior**:
- Only works for consumable items
- Removes item from inventory
- Emits `item_used` signal

### Drop Item

```gdscript
inventory_screen.selected_item = some_item
inventory_screen._on_drop_button_pressed()
```

**Behavior**:
- Works for any item
- Removes item from inventory
- Emits `item_dropped` signal
- Optional: Integrate with loot system

### Sell Item

```gdscript
inventory_screen.selected_item = some_item
inventory_screen._on_sell_button_pressed()
```

**Behavior**:
- Only works for tradeable items (excludes quest items)
- Removes item from inventory
- **TODO**: Add currency to heir's wallet

## Signals

The InventoryScreen emits the following signals:

```gdscript
## Emitted when an item is equipped
signal item_equipped(item: Item)

## Emitted when a consumable is used
signal item_used(item: Item)

## Emitted when an item is dropped
signal item_dropped(item: Item)

## Emitted when inventory changes (after any action)
signal inventory_changed()
```

### Signal Usage Examples

```gdscript
var inventory = InventoryScreen.new(heir)

# Listen for item equipping
inventory.item_equipped.connect(func(item):
    print("Equipped: %s" % item.name)
    update_equipment_display()
)

# Listen for item usage
inventory.item_used.connect(func(item):
    print("Used: %s" % item.name)
    apply_consumable_effect(item)
)

# Listen for item drops
inventory.item_dropped.connect(func(item):
    print("Dropped: %s" % item.name)
    spawn_item_on_ground(item)
)

add_child(inventory)
```

## Styling & Theming

### Color Coding

Items are color-coded by rarity:

| Rarity | Color |
|--------|-------|
| Common | Gray |
| Uncommon | Green |
| Rare | Blue |
| Very Rare | Magenta |
| Legendary | Gold |

### Layout Constants

```gdscript
const ITEMS_PER_ROW: int = 5
const ITEM_CARD_SIZE: Vector2 = Vector2(120, 140)
const DETAILS_PANEL_WIDTH: float = 280.0
const FILTER_BUTTON_HEIGHT: float = 32.0
const SEARCH_BAR_HEIGHT: float = 32.0
```

Adjust these constants to customize layout.

### Theme Overrides

The component respects Godot's theme system:

```gdscript
# Override button style
var theme = Theme.new()
var button_style = StyleBoxFlat.new()
button_style.bg_color = Color.DARK_BLUE
theme.set_stylebox("normal", "Button", button_style)

inventory_screen.theme = theme
```

## Methods

### Public Methods

```gdscript
## Set the heir whose inventory to display
func set_heir_inventory(inventory: HeirInventory) -> void

## Refresh inventory display with current filter/sort/search
func refresh_inventory() -> void

## Get the currently selected item
func get_selected_item() -> Item

## Change which filter is active
func _on_filter_changed(filter_type: FilterType) -> void

## Change which sort is active
func _on_sort_changed(index: int) -> void

## Handle search text changes
func _on_search_text_changed(new_text: String) -> void

## Select an item from the grid
func _on_item_card_selected(card: InventoryItemCard) -> void
```

### Internal Methods

```gdscript
## Apply current filter to items array
func _apply_filter(items: Array[Item]) -> Array[Item]

## Check if item matches current filter
func _matches_filter(item: Item) -> bool

## Sort items by current sort option
func _apply_sort(items: Array[Item]) -> void

## Apply search text filtering
func _apply_search(items: Array[Item]) -> Array[Item]

## Update details panel with selected item info
func _update_details_panel() -> void
```

## Integration with Game Systems

### Equipment System Integration

When an item is equipped:

```gdscript
inventory.item_equipped.connect(func(item):
    # TODO: Show equipment slot selection dialog
    # heir_equipment.equip_item(item, slot)
    # update_equipment_screen()
    pass
)
```

### Loot System Integration

When an item is dropped:

```gdscript
inventory.item_dropped.connect(func(item):
    # Spawn item as loot on ground
    var loot = LootEntity.new(item, current_position)
    world.add_child(loot)
)
```

### Merchant System Integration

When an item is sold:

```gdscript
inventory.item_equipped.connect(func(item):
    if item.can_sell():
        var value = item.value.to_copper()
        heir.wallet.add_currency(item.value)
        # TODO: Implement in sell action
)
```

## Keyboard Shortcuts

- **ESC**: Close inventory screen
- **I**: Close inventory screen (toggles if held)

## Known Limitations & TODOs

1. **Equipment Slot Selection**: Dialog for selecting equipment slot not yet implemented
2. **Drag-Drop Equipping**: Framework in place but not fully functional
3. **Item Quantity Picker**: Not yet implemented for stackable items
4. **Sell Integration**: Currency transfer not connected
5. **Item Tooltips**: Extended tooltip on hover not implemented
6. **Durability Repair**: No repair functionality in UI
7. **Crafting Integration**: No link to crafting system

## Testing

Comprehensive tests are available in `tests/test_inventory_screen.gd`:

```bash
# Run tests (requires GUT framework)
godot --addons res://addons/gut/ -run_tests tests/test_inventory_screen.gd
```

### Test Coverage

- Filter functionality (all 6 filter types)
- Sort functionality (all 5 sort types)
- Search functionality (name, description, case-insensitivity)
- Item selection and details
- Action buttons (equip, use, drop, sell)
- Signal emissions
- Combined filter+sort+search

## Performance Considerations

- **Grid Rendering**: FlowContainer dynamically arranges items
- **Scroll Container**: Efficiently handles large inventories
- **Signal Optimization**: Minimal allocations on refresh
- **Memory**: Item cards cleaned up when filtered out

For inventories > 100 items, consider:
- Implementing lazy loading
- Using ItemList instead of FlowContainer
- Pagination or virtual scrolling

## Extension Points

### Adding Custom Item Filters

```gdscript
# Extend FilterType enum
# Add custom filter logic to _matches_filter()
func _matches_filter(item: Item) -> bool:
    if current_filter == FilterType.CUSTOM:
        return _check_custom_condition(item)
    # ... existing code
```

### Adding Custom Actions

```gdscript
# Add new button to action_buttons_container
var custom_btn = Button.new()
custom_btn.text = "Custom Action"
custom_btn.pressed.connect(_on_custom_action)
action_buttons_container.add_child(custom_btn)

func _on_custom_action() -> void:
    if not selected_item:
        return
    # Custom logic
```

## Architecture Notes

The InventoryScreen follows clean architecture principles:

1. **Separation of Concerns**: UI logic separate from data logic
2. **Data-Driven**: All filtering/sorting applied to data, not UI
3. **Reactive Design**: UI reflects data state changes
4. **Signal-Based Communication**: Loose coupling with other systems
5. **Reusable Components**: InventoryItemCard can be used independently

## Troubleshooting

### Inventory Not Displaying

```gdscript
# Ensure heir has inventory
print(heir.inventory.size())

# Refresh manually
inventory_screen.refresh_inventory()

# Check filter
print(inventory_screen.current_filter)
```

### Items Not Clickable

- Ensure `InventoryItemCard.mouse_filter` is `MOUSE_FILTER_STOP`
- Check if buttons are on top of grid

### Details Panel Not Updating

- Call `refresh_inventory()` after modifying items
- Ensure signal connections are working

### Buttons Disabled When Not Expected

- Check `item.can_equip()`, `item.can_use()`, `item.can_sell()`
- These determine button state

## Future Enhancements

- [ ] Equipment slot selection dialog
- [ ] Drag-drop item reordering
- [ ] Item comparison view
- [ ] Quick equip for recommended items
- [ ] Item splitting/combining for stacks
- [ ] Favorite/pin frequently used items
- [ ] Item preview 3D model
- [ ] Keyboard navigation
- [ ] Controller support
- [ ] Customizable column count
- [ ] Save/load custom sort preferences
- [ ] Item locking to prevent accidents

## Support

For issues or questions:
1. Check test file for usage examples
2. Review method documentation
3. Check signal emissions in console
4. Verify heir.inventory is populated
5. Ensure Item class has required methods

---

**Last Updated**: 2026-10-03  
**Component Version**: 1.0  
**Status**: Production Ready
