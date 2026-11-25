## One square of the figure pane or the pack (docs/PLAYER_INTERFACE.md, slice 4): a button showing an item's icon, which can be
## dragged and dropped onto another slot or pane, and double clicked. It holds no rule: the pane that makes it says what a drop or a
## double click does, by the `on_drop`, `can_drop` and `on_double` callables. Rendering only.
extends Button

const ItemIcon := preload("res://ui/play/item_icon.gd")
const UiSkin := preload("res://ui/play/ui_skin.gd")

var item := ""                     # the item id shown here ("" for an empty square)
var tag := ""                      # what the square is, for the pane's callables: "pack", "bag" or a slot name
var on_drop := Callable()          # func(data: Dictionary): something was dropped here
var can_drop := Callable()         # func(data: Dictionary) -> bool
var on_double := Callable()        # func(): a double click


func setup(id: String, size_px: float, shown_name: String = "") -> void:
	item = id
	custom_minimum_size = Vector2(size_px, size_px)
	mouse_filter = Control.MOUSE_FILTER_PASS   # a drop on a square that does not want it goes to the pane behind
	focus_mode = Control.FOCUS_NONE
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if id != "":
		icon = ItemIcon.texture(id)
		tooltip_text = "%s\n%s" % [GameItems.item_name(id), GameItems.describe(id)]
		text = ""
	else:
		text = shown_name
		add_theme_font_size_override("font_size", 11)
		modulate = Color(1, 1, 1, 0.55)


func _ready() -> void:
	if UiSkin.in_skin(self):   # an inset square, gold when pointed at
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		for state in ["normal", "disabled"]:
			add_theme_stylebox_override(state, UiSkin.inset_box(false))
		for state in ["hover", "pressed"]:
			add_theme_stylebox_override(state, UiSkin.inset_box(true))
		add_theme_color_override("font_color", UiSkin.pal("parch_hi"))
		if item == "":   # an empty square is the same inset, its name quiet inside it (not faded into the parchment)
			modulate = Color(1, 1, 1, 1)
			add_theme_color_override("font_color", UiSkin.pal("slot_lo"))
		set_meta("skin_done", true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.double_click and on_double.is_valid():
		on_double.call()
		accept_event()


func _get_drag_data(_at: Vector2) -> Variant:
	if item == "":
		return null
	var preview := TextureRect.new()
	preview.texture = ItemIcon.texture(item)
	preview.custom_minimum_size = Vector2(36, 36)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_drag_preview(preview)
	return {"item": item, "from": tag}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("item") and can_drop.is_valid() and bool(can_drop.call(data))


func _drop_data(_at: Vector2, data: Variant) -> void:
	if on_drop.is_valid():
		on_drop.call(data)
