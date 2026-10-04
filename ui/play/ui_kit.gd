## Small helpers for building the code-driven UI.
extends RefCounted

const BG := Color("#14121c")
const PANEL := Color("#221f30")
const PANEL_LIGHT := Color("#2e2a42")
const ACCENT := Color("#e0b341")
const TEXT := Color("#e8e4f0")
const DIM := Color("#8d88a0")
const GOOD := Color("#6fcf6f")
const BAD := Color("#e0605a")
const MP_BLUE := Color("#5a8fe0")


static func style(color: Color, radius: int = 6, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	if border.a > 0.0:
		s.set_border_width_all(2)
		s.border_color = border
	return s


static func panel(color: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(color))
	return p


static func label(text: String, size: int = 16, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, callback: Callable, min_size: Vector2 = Vector2(0, 38)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_stylebox_override("normal", style(PANEL_LIGHT, 6, Color("#4a4466")))
	b.add_theme_stylebox_override("hover", style(Color("#3d3860"), 6, ACCENT))
	b.add_theme_stylebox_override("pressed", style(Color("#4d4680"), 6, ACCENT))
	b.add_theme_stylebox_override("disabled", style(Color("#1b1927"), 6, Color("#2a2740")))
	b.add_theme_color_override("font_disabled_color", Color("#5a566a"))
	b.pressed.connect(callback)
	return b


static func bar(color: Color, max_value: float, value: float, size: Vector2 = Vector2(200, 16)) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.custom_minimum_size = size
	pb.show_percentage = false
	pb.max_value = max_value
	pb.value = value
	pb.add_theme_stylebox_override("background", style(Color("#0c0b12"), 4))
	pb.add_theme_stylebox_override("fill", style(color, 4))
	return pb


static func rich(bbcode: bool = true) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = bbcode
	r.scroll_following = true
	r.add_theme_font_size_override("normal_font_size", 15)
	r.add_theme_color_override("default_color", TEXT)
	return r


## A modal overlay on `host`: dimmed backdrop, bordered panel, title row with Close.
## Returns the content box; the overlay itself is `box.get_meta("overlay")`.
static func overlay(host: Control, title: String) -> VBoxContainer:
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(Color("#1a1828"), 8, ACCENT))
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.offset_left = 30
	p.offset_right = -30
	p.offset_top = 24
	p.offset_bottom = -24
	host.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := label(title, 22, ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(button("Close", func(): host.queue_free(), Vector2(100, 34)))
	v.set_meta("overlay", host)
	return v


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func trait_color(id: String) -> Color:
	match GameData.trait_def(id).get("category", ""):
		"curse": return BAD
		"blessing": return GOOD
		"mutation": return Color("#c58fe8")
		"acquired": return Color("#e8a05a")
		"divine": return Color("#ffd75e")
		"racial": return Color("#5ad1c8")
	return Color("#7fb7ff")


static func trait_bbcode(id: String) -> String:
	var def := GameData.trait_def(id)
	return "[color=#%s]%s[/color]" % [trait_color(id).to_html(false), def.get("name", id)]


static func trait_tooltip(id: String) -> String:
	var def := GameData.trait_def(id)
	var s: String = "%s [%s]\n%s" % [def.get("name", id), def.get("category", ""), def.get("description", "")]
	if def.has("story_hook"):
		s += "\n\n" + str(def["story_hook"])
	if def.get("category", "") == "racial":
		s += "\n\nInnate to the race; never lost."
	else:
		s += "\n\nInherit chance: %d%%" % int(round(float(def.get("inherit_chance", 0.0)) * 100.0))
	return s
