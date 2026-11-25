## The open world's action bar (data/ui/actionbar.json, data/art/action_icons.json): a square slot with a small pixel picture, the key that
## does it in the corner, a tooltip naming it and its keys, dimmed when it does not apply and lit while its mode is on. Rendering only: a
## click calls `pressed` and the screen does what the slot's id says. A touch screen keeps its text buttons.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const WorldInput := preload("res://ui/play/world_input.gd")
const UiSkin := preload("res://ui/play/ui_skin.gd")
const BAR_PATH := "res://data/ui/actionbar.json"
const ICON_PATH := "res://data/art/action_icons.json"

static var _bar: Dictionary = {}
static var _icons: Dictionary = {}
static var _textures: Dictionary = {}

var id := ""
var glyph := ""
var tint := Color.WHITE
var badge := ""            # the slot's number, drawn in its corner ("" for the two small buttons)
var dim := false           # does not apply now
var active := false        # its mode is on
var pressed: Callable = Callable()
var hover := false
var skinned := false       # drawn with the interface skin (a wide window with a mouse), set by the screen that makes it


static func data() -> Dictionary:
	if _bar.is_empty():
		_bar = GameData.load_json(BAR_PATH)
	return _bar


static func icons() -> Dictionary:
	if _icons.is_empty():
		_icons = GameData.load_json(ICON_PATH)
	return _icons


static func setting(key: String) -> float:
	return float(data()["settings"][key])


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


## One glyph as a white-on-clear texture (tinted when drawn), made once.
static func texture(name: String) -> Texture2D:
	if _textures.has(name):
		return _textures[name]
	var rows: Array = icons()["glyphs"].get(name, [])
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in mini(rows.size(), 8):
		for x in mini(str(rows[y]).length(), 8):
			if str(rows[y])[x] == "#":
				img.set_pixel(x, y, Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_textures[name] = tex
	return tex


## The slot's tooltip: its label and the keys that do it (its number first, then the action's own).
static func tip_for(def: Dictionary, number: String) -> String:
	var keys: Array = []
	if number != "":
		keys.append(number)
	if str(def.get("action", "")) != "":
		for k in WorldInput.keys_of(str(def["action"])):
			keys.append(str(k))
	if keys.is_empty():
		return text("tip_plain", {"label": str(def["label"])})
	return text("tip", {"label": str(def["label"]), "keys": ", ".join(keys)})


## A slot made from one entry of `slots` or `extras`, `number` being "1".."8" or "".
static func make(def: Dictionary, number: String, on_press: Callable, skinned_look: bool = false) -> Control:
	var slot: Control = load("res://ui/play/action_slot.gd").new()
	slot.id = str(def["id"])
	slot.glyph = str(def["glyph"])
	var c: Array = def["color"]
	slot.tint = Color(float(c[0]), float(c[1]), float(c[2]))
	slot.badge = number
	slot.pressed = on_press
	slot.tooltip_text = tip_for(def, number)
	slot.skinned = skinned_look
	var px := UiSkin.hud("slot_px") if skinned_look else setting("slot_px")
	slot.custom_minimum_size = Vector2(px, px)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	return slot


## A slot for a thing the heir carries says how many in its tooltip ("Smoke pot  (9): 2 left", or "none").
func set_count(def: Dictionary, number: String, n: int) -> void:
	var tip := tip_for(def, number)
	tooltip_text = text("tip_count", {"tip": tip, "n": n}) if n > 0 else text("tip_none", {"tip": tip})


func set_state(p_dim: bool, p_active: bool) -> void:
	if p_dim != dim or p_active != active:
		dim = p_dim
		active = p_active
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if pressed.is_valid():
			pressed.call()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		hover = true
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		hover = false
		queue_redraw()


func _draw() -> void:
	if skinned:
		_draw_skinned()
		return
	var fill := Color("#4a3f78") if active else (Color("#34304e") if hover else Color("#26233a"))
	draw_style_box(Kit.style(fill, 6, Kit.ACCENT if active else Color("#4a4666")), Rect2(Vector2.ZERO, size))
	var sc := setting("glyph_scale")
	var gsize := Vector2(8, 8) * sc
	var colour := tint if not dim else Color(tint.r, tint.g, tint.b, 0.3)
	draw_texture_rect(texture(glyph), Rect2((size - gsize) * 0.5 + Vector2(0, 2), gsize), false, colour)
	if badge != "":
		draw_string(ThemeDB.fallback_font, Vector2(4, 12), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Kit.dim() if not dim else Color(1, 1, 1, 0.3))


## The slot as an inset square of the skin: gold frame (and a wash of gold) while its mode is on or the mouse is over it, the picture in
## its colour with a one-pixel ink outline, the key in a small ink badge, and a slot that does not apply dimmed, never removed.
func _draw_skinned() -> void:
	var px := float(UiSkin.pixel())
	var lit := active or hover
	draw_style_box(UiSkin.inset_box(lit), Rect2(Vector2.ZERO, size))
	var inner := Rect2(Vector2.ONE * px * 3.0, size - Vector2.ONE * px * 6.0)
	if active:
		draw_rect(inner, Color(UiSkin.pal("gold"), UiSkin.hud("wash")))
	var gsize := Vector2(8, 8) * px * UiSkin.hud("glyph_pixels")
	var at := (size - gsize) * 0.5 + Vector2(0, px)
	var tex := texture(glyph)
	var a := UiSkin.hud("dim_alpha") if dim else 1.0
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		draw_texture_rect(tex, Rect2(at + o * px, gsize), false, Color(UiSkin.pal("ink"), a))
	draw_texture_rect(tex, Rect2(at, gsize), false, Color(tint, a))
	if badge != "":
		var pf: Array = UiSkin.pick("badge", int(UiSkin.hud("badge_size")), ThemeDB.fallback_font)
		var font: Font = pf[0]
		var fs: int = pf[1]
		var sz := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pad := Vector2(float(UiSkin.piece("badge")["content"][0]), float(UiSkin.piece("badge")["content"][1])) * px
		var box := Rect2(Vector2.ONE * px * 3.0, Vector2(maxf(sz.x, font.get_height(fs) * 0.6) + pad.x * 2.0, font.get_height(fs) + pad.y * 2.0))
		draw_style_box(UiSkin.badge_box(active), box)
		var col := UiSkin.pal("gold_hi") if active else UiSkin.pal("parch_hi")
		draw_string(font, box.position + Vector2((box.size.x - sz.x) * 0.5, pad.y + font.get_ascent(fs)), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, 0.5 if dim else 1.0))


static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = data()
	for k in ["settings", "slots", "extras", "text"]:
		if not dat.has(k):
			bad.append("actionbar.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	for k in ["slot_px", "gap", "glyph_scale"]:
		if not dat["settings"].has(k) or float(dat["settings"][k]) <= 0.0:
			bad.append("actionbar.json: settings.%s must be above 0" % k)
	if dat["slots"].size() < 1 or dat["slots"].size() > 9:
		bad.append("actionbar.json: there are 1 to 9 numbered slots (the number keys), not %d" % dat["slots"].size())
	var seen := {}
	var all: Array = (dat["slots"] as Array) + (dat["extras"] as Array)
	for def in all:
		var id := str(def.get("id", ""))
		if id == "" or str(def.get("label", "")) == "":
			bad.append("actionbar.json: every slot needs an id and a label")
			continue
		if seen.has(id):
			bad.append("actionbar.json: '%s' is on the bar twice" % id)
		seen[id] = true
		var rows: Variant = icons().get("glyphs", {}).get(str(def.get("glyph", "")), null)
		if typeof(rows) != TYPE_ARRAY or (rows as Array).size() != 8:
			bad.append("actionbar.json: '%s' needs a glyph of 8 rows in action_icons.json" % id)
		else:
			for r in rows:
				if str(r).length() != 8 or str(r).replace("#", "").replace(".", "") != "":
					bad.append("action_icons.json: a row of '%s' is not 8 of # and ." % str(def["glyph"]))
					break
		if typeof(def.get("color", null)) != TYPE_ARRAY or (def["color"] as Array).size() != 3:
			bad.append("actionbar.json: '%s' needs a colour [r, g, b]" % id)
		if str(def.get("action", "")) != "" and not WorldInput.data()["actions"].has(str(def["action"])):
			bad.append("actionbar.json: '%s' names an action that is not in input.json" % id)
	for i in range(1, dat["slots"].size() + 1):
		if not WorldInput.data()["actions"].has("world_slot_%d" % i):
			bad.append("actionbar.json: slot %d has no key action world_slot_%d in input.json" % [i, i])
	for k in ["cast_none", "tip", "tip_plain"]:
		if not dat["text"].has(k):
			bad.append("actionbar.json: text.%s is missing" % k)
	return bad
