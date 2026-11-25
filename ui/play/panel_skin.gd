## The skin for the big management panels (house, chronicle, shops and the like; docs/ART_DIRECTION.md): rows as inset slots, costs
## with a gold coin, wooden tabs with a gold-lit open one, raised parchment buttons, and the family tree's node cards. Every helper
## takes the panel (`host`) and returns the panel's old look when it is not skinned (`UiSkin.active`: a pane on a wide window with a
## mouse), so a compact window, a touch screen and the full-screen overlays are drawn as they were. Rendering only.
extends RefCounted

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const UiSkin := preload("res://ui/play/ui_skin.gd")


static func on(host: Control) -> bool:
	return UiSkin.active(host)


## A colour for text that sits in a slot row: the kit's light-on-dark colours stay light, the quiet grey and the red are made to read on
## the slot's brown. Unskinned: the colour as it is.
static func ink(host: Control, c: Color) -> Color:
	return UiSkin.on_face(c, "slot") if on(host) else c


## One row of a list: an inset slot (a dark box with a lit edge below) round `inner`'s place, or the kit's dark panel when not skinned.
## Fill it with `add_child`; its labels are dressed by `label` below, so they are left alone by the pane's dressing.
static func row(host: Control, color: Color = Kit.PANEL) -> PanelContainer:
	if not on(host):
		return Kit.panel(color)
	var p := PanelContainer.new()
	var sb: StyleBoxTexture = UiSkin.inset_box(false).duplicate()
	var c: Array = UiSkin.piece("row")["content"]
	var s := UiSkin.pixel()
	sb.content_margin_left = float(c[0] * s) + 4.0
	sb.content_margin_right = float(c[0] * s) + 4.0
	sb.content_margin_top = float(c[1] * s) + 2.0
	sb.content_margin_bottom = float(c[1] * s) + 2.0
	p.add_theme_stylebox_override("panel", sb)
	p.set_meta("skin_row", true)
	p.ready.connect(func(): retint(host, p))   # whatever was put in it, once it is all there
	return p


## A label in a slot row (colour as `ink`).
static func label(host: Control, text: String, size: int = 16, color: Color = Kit.TEXT) -> Label:
	return Kit.label(text, size, ink(host, color))


## A button: the kit's, and when skinned a raised parchment key (ink text; a disabled one is flat, with its text in the quiet ink).
static func button(host: Control, text: String, callback: Callable, min_size: Vector2 = Vector2(0, 38)) -> Button:
	var b := Kit.button(text, callback, min_size)
	if on(host):
		dress_button(b)
	return b


static func dress_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", UiSkin.button_box("normal"))
	b.add_theme_stylebox_override("hover", UiSkin.button_box("hover"))
	b.add_theme_stylebox_override("hover_pressed", UiSkin.button_box("pressed"))
	b.add_theme_stylebox_override("pressed", UiSkin.button_box("pressed"))
	b.add_theme_stylebox_override("disabled", UiSkin.button_box("disabled"))
	b.add_theme_color_override("font_color", UiSkin.pal("ink"))
	b.add_theme_color_override("font_hover_color", UiSkin.pal("crimson_dk"))
	b.add_theme_color_override("font_pressed_color", UiSkin.pal("ink"))
	b.add_theme_color_override("font_hover_pressed_color", UiSkin.pal("ink"))
	b.add_theme_color_override("font_disabled_color", UiSkin.pal("ink_dim"))
	b.set_meta("skin_done", true)


## A price: a gold coin and the number (the words "gold" are left to the label round it). Unskinned: just the number in gold.
static func cost(host: Control, amount: int, affordable: bool = true, size: int = 15) -> Control:
	return coin_text(host, GameText.num(amount), Kit.ACCENT if affordable else Kit.bad(), size)


## A gold coin and some text (a price as the shops write it: "120g", "sells 8g"). Unskinned: just the text.
static func coin_text(host: Control, text: String, color: Color, size: int = 15) -> Control:
	if not on(host):
		return Kit.label(text, size, color)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	hb.set_meta("skin_cost", true)
	var coin := TextureRect.new()
	coin.texture = UiSkin.icon_tex("coin")
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin.custom_minimum_size = Vector2(8 * UiSkin.pixel(), 8 * UiSkin.pixel())
	coin.modulate = UiSkin.pal("gold")
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(coin)
	var l := Kit.label(text, size, ink(host, color))
	hb.add_child(l)
	return hb


## Puts the colours of every label under `n` (a slot row, or a dark box of the pane) on the slot's brown: the quiet grey and the red are
## made to read, BBCode colours too. Run once a row is built; later text is the row's to colour.
static func retint(host: Control, n: Node) -> void:
	if not on(host):
		return
	if n is Label:
		var l := n as Label
		l.add_theme_color_override("font_color", ink(host, l.get_theme_color("font_color")))
		l.set_meta("skin_done", true)
	elif n is RichTextLabel:
		var r := n as RichTextLabel
		r.add_theme_color_override("default_color", ink(host, r.get_theme_color("default_color")))
		UiSkin._retint_bb(r, "slot")
		r.set_meta("skin_done", true)
	for c in n.get_children():
		if not (c is BaseButton):
			retint(host, c)


## A TabContainer with wooden tabs, the open one lit in gold, over the pane's own face.
static func tabs(host: Control, tc: TabContainer) -> void:
	if not on(host):
		return
	tc.add_theme_stylebox_override("tab_unselected", UiSkin.tab_box("off"))
	tc.add_theme_stylebox_override("tab_hovered", UiSkin.tab_box("hover"))
	tc.add_theme_stylebox_override("tab_selected", UiSkin.tab_box("on"))
	tc.add_theme_stylebox_override("tab_disabled", UiSkin.tab_box("off"))
	tc.add_theme_stylebox_override("tab_focus", StyleBoxEmpty.new())
	tc.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	tc.add_theme_color_override("font_unselected_color", UiSkin.pal("wood_text"))
	tc.add_theme_color_override("font_hovered_color", UiSkin.pal("wood_text"))
	tc.add_theme_color_override("font_selected_color", UiSkin.pal("gold_hi"))
	tc.add_theme_color_override("font_disabled_color", UiSkin.pal("wood_dim"))
	tc.add_theme_color_override("font_outline_color", UiSkin.pal("ink"))
	tc.add_theme_constant_override("outline_size", 2)
	tc.add_theme_constant_override("side_margin", 0)


## A toggle button that is a tab (the shops' row of shops): wood, and the open one lit.
static func tab_button(host: Control, b: Button) -> void:
	if not on(host):
		return
	b.add_theme_stylebox_override("normal", UiSkin.tab_box("off"))
	b.add_theme_stylebox_override("hover", UiSkin.tab_box("hover"))
	b.add_theme_stylebox_override("pressed", UiSkin.tab_box("on"))
	b.add_theme_stylebox_override("hover_pressed", UiSkin.tab_box("on"))
	b.add_theme_stylebox_override("disabled", UiSkin.tab_box("off"))
	b.add_theme_color_override("font_color", UiSkin.pal("wood_text"))
	b.add_theme_color_override("font_hover_color", UiSkin.pal("wood_text"))
	b.add_theme_color_override("font_pressed_color", UiSkin.pal("gold_hi"))
	b.add_theme_color_override("font_hover_pressed_color", UiSkin.pal("gold_hi"))
	b.add_theme_color_override("font_disabled_color", UiSkin.pal("wood_dim"))
	b.add_theme_color_override("font_outline_color", UiSkin.pal("ink"))
	b.add_theme_constant_override("outline_size", 2)
	b.set_meta("skin_done", true)


## A segmented progress bar of the skin (the house's levels): `kind` is "hp", "mp" or "load" (gold).
static func progress(host: Control, value: float, max_value: float, kind: String = "load") -> Control:
	var pb := Kit.bar(Kit.ACCENT, max_value, value, Vector2(160, 14))
	if on(host):
		UiSkin.dress_bar(pb, kind)
	return pb
