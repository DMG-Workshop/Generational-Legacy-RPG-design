## The interface skin (docs/ART_DIRECTION.md; data/ui/skin.json): parchment panels with ink lines and gold studs, crimson ribbon
## titles, segmented bars, inset slots, a wooden frame and header, all made in code at one pixel size and drawn at whole multiples
## with no smoothing. It skins the panes over the open world on a desktop-sized window (`active`); a touch screen or a compact
## window keeps the older dark look, and so do the full-screen overlays. Every texture is built once and kept in `_memo`: a
## texture made while drawing and let go is freed before the frame shows, and draws white. Rendering only: no dynasty access.
extends RefCounted

const UiSettings := preload("res://ui/play/ui_settings.gd")
const PATH := "res://data/ui/skin.json"
const PIECES := ["panel", "frame", "ribbon", "inset", "bar", "header", "plate", "badge", "button", "tab"]
const HUD_KEYS := ["slot_px", "glyph_pixels", "gap", "badge_size", "dim_alpha", "wash", "header_tile", "bar_y", "plate_text"]
const PALETTE_KEYS := ["ink", "brown", "parch", "parch_hi", "parch_lo", "wood", "wood_hi", "wood_lo", "gold", "gold_dk", "gold_hi",
		"crimson", "crimson_hi", "crimson_dk", "slot_bg", "slot_lo", "track", "bar_text", "ink_dim", "ink_good", "ink_bad", "ink_blue",
		"ink_good_cb", "ink_bad_cb", "wood_text", "wood_dim", "wood_good", "wood_bad", "wood_blue", "wood_accent", "wood_good_cb",
		"wood_bad_cb", "slot_dim", "slot_good", "slot_bad"]
const TRIPLES := ["hp", "mp", "carry"]

static var _cache: Dictionary = {}
static var _memo := {}   # every texture and box made, kept alive


static func data() -> Dictionary:
	if _cache.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				_cache = parsed
	return _cache


## The palette the accessibility options pick: the high-contrast one or the standard one.
static func variant() -> String:
	return "high_contrast" if UiSettings.high_contrast() else "standard"


static func pal(key: String) -> Color:
	return Color(str(data()["variants"][variant()][key]))


static func triple(key: String) -> Array:
	return (data()["variants"][variant()][key] as Array).map(func(c): return Color(str(c)))


static func piece(name: String) -> Dictionary:
	return data()["pieces"][name]


## Whether the skin is used for what is drawn under `host`: a panel opened as a pane (it carries the meta `pane`) on a window that is
## wide and has a mouse. Anywhere else the older look stays.
static func active(host: Control) -> bool:
	return host != null and host.has_meta("pane") and not UiSettings.compact(host) and not UiSettings.touch()


## Whether the pieces over the open world (action bar, header, ring, thing menu) wear the skin: a wide window with a mouse. They are
## not panes, so this does not ask for the pane meta.
static func hud_active(n: Control) -> bool:
	return n != null and not UiSettings.compact(n) and not UiSettings.touch()


## A number of the `hud` block of the data.
static func hud(key: String) -> float:
	return float(data()["hud"][key])


## The pane a control is in, or null.
static func pane_of(n: Node) -> Control:
	var p := n
	while p != null:
		if p is Control and p.has_meta("pane"):
			return p
		p = p.get_parent()
	return null


## Whether `n` is in a pane that is skinned.
static func in_skin(n: Node) -> bool:
	return active(pane_of(n))


## The size of one pixel of the skin's art in UI units: the data's, or the next size up that makes a whole number of screen pixels
## at the player's UI scale (1.25 turns 2 into 4, never into 2.5).
static func pixel() -> int:
	var base := int(data().get("pixel", 2))
	var sc := UiSettings.get_scale()
	for s in range(base, base + 5):
		var screen := float(s) * sc
		if absf(screen - roundf(screen)) < 0.001:
			return s
	return base


## The face a pane has: "parch" or "wood".
static func face_for(key: String) -> String:
	var f: Dictionary = data().get("faces", {})
	return str(f.get(key.get_slice(":", 0), f.get("default", "parch")))


# ---------------------------------------------------------------- contrast

static func luminance(c: Color) -> float:
	var ch: Array = []
	for v in [c.r, c.g, c.b]:
		ch.append(v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]


static func contrast(a: Color, b: Color) -> float:
	var x := luminance(a)
	var y := luminance(b)
	return (maxf(x, y) + 0.05) / (minf(x, y) + 0.05)


## What stands in on `face` ("parch" or "wood") for a colour the dark overlay look uses: the palette colour the data names, or, for a
## colour it does not know, that colour made darker (on parchment) or lighter (on wood) until it can be read.
static func on_face(c: Color, face: String = "parch") -> Color:
	var m: Dictionary = data().get("text_maps", {}).get(face, {})
	var hex := "#" + c.to_html(false)
	if m.has(hex):
		return pal(str(m[hex]))
	var bg := pal("parch" if face == "parch" else "wood")
	var out := c
	for i in 16:
		if contrast(out, bg) >= 4.5:
			break
		out = out.darkened(0.12) if face == "parch" else out.lightened(0.12)
	return out


# ---------------------------------------------------------------- pixel art made in code (one logical pixel is `pixel()` UI units)

static func _img(w: int, h: int, c: Color) -> Image:
	var i := Image.create(w, h, false, Image.FORMAT_RGBA8)
	i.fill(c)
	return i


static func _rect(i: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	i.fill_rect(Rect2i(x, y, w, h), c)


static func _ring(i: Image, inset: int, c: Color) -> void:
	var w := i.get_width()
	var h := i.get_height()
	_rect(i, inset, inset, w - inset * 2, 1, c)
	_rect(i, inset, h - 1 - inset, w - inset * 2, 1, c)
	_rect(i, inset, inset, 1, h - inset * 2, c)
	_rect(i, w - 1 - inset, inset, 1, h - inset * 2, c)


static func _keep(k: String, v: Variant) -> Variant:
	_memo[k] = v
	return v


## The picture of `i` at the pixel size, whole multiples, no smoothing.
static func _tex(i: Image) -> ImageTexture:
	var s := pixel()
	var big := i.duplicate() as Image
	big.resize(i.get_width() * s, i.get_height() * s, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(big)


static func _logical(px: int) -> int:
	return maxi(1, ceili(float(px) / float(pixel())))


static func _key(kind: String, extra: String) -> String:
	return "%s|%s|%d|%s" % [kind, variant(), pixel(), extra]


## A panel: parchment with fibres, an inner bevel, a brown and an ink border and a gold stud in each corner.
static func panel_tex(w: int, h: int) -> ImageTexture:
	var k := _key("panel", "%d,%d" % [w, h])
	if _memo.has(k):
		return _memo[k]
	var p := piece("panel")
	var lw := maxi(_logical(w), 2 * int(p["margin"]) + 2)
	var lh := maxi(_logical(h), 2 * int(p["margin"]) + 2)
	var i := _img(lw, lh, pal("parch"))
	var r := CosmeticRng.keyed("skin_panel_%d_%d" % [lw, lh])
	var rate := float(p["speck"])
	for y in lh:
		for x in lw:
			var q := r.randf()
			if q < rate:
				i.set_pixel(x, y, pal("parch_hi"))
			elif q < rate * 2.0:
				i.set_pixel(x, y, pal("parch_lo"))
	var b := int(p["bevel"])
	_rect(i, b, b, lw - 2 * b, 1, pal("parch_hi"))
	_rect(i, b, b, 1, lh - 2 * b, pal("parch_hi"))
	_rect(i, b, lh - 1 - b, lw - 2 * b, 1, pal("parch_lo"))
	_rect(i, lw - 1 - b, b, 1, lh - 2 * b, pal("parch_lo"))
	_ring(i, 1, pal("brown"))
	_ring(i, 0, pal("ink"))
	var st := int(p["stud"])
	var at := int(p["stud_at"])
	for pt in [Vector2i(at, at), Vector2i(lw - at - st, at), Vector2i(at, lh - at - st), Vector2i(lw - at - st, lh - at - st)]:
		_rect(i, pt.x, pt.y, st, st, pal("ink"))
		_rect(i, pt.x + 1, pt.y + 1, st - 2, st - 2, pal("gold"))
		i.set_pixel(pt.x + st - 2, pt.y + st - 2, pal("gold_dk"))
	return _keep(k, _tex(i))


## A wooden frame (the minimap's): ink outside, then planks, a lit edge and a gold stud in each corner.
static func frame_tex(w: int, h: int) -> ImageTexture:
	var k := _key("frame", "%d,%d" % [w, h])
	if _memo.has(k):
		return _memo[k]
	var m := int(piece("frame")["margin"])
	var lw := maxi(_logical(w), 2 * m + 2)
	var lh := maxi(_logical(h), 2 * m + 2)
	var i := _img(lw, lh, pal("wood"))
	_ring(i, 0, pal("ink"))
	_ring(i, 1, pal("wood_lo"))
	_ring(i, 2, pal("wood_hi"))
	_ring(i, 3, pal("wood"))
	_ring(i, 4, pal("wood_lo"))
	for pt in [Vector2i(1, 1), Vector2i(lw - 3, 1), Vector2i(1, lh - 3), Vector2i(lw - 3, lh - 3)]:
		_rect(i, pt.x, pt.y, 2, 2, pal("gold"))
	return _keep(k, _tex(i))


## A ribbon title: crimson with a lit top edge, a shaded bottom edge, an ink outline and gold stitching.
static func ribbon_tex(w: int, h: int) -> ImageTexture:
	var k := _key("ribbon", "%d,%d" % [w, h])
	if _memo.has(k):
		return _memo[k]
	var p := piece("ribbon")
	var lw := maxi(_logical(w), 2 * int(p["margin"]) + 2)
	var lh := maxi(_logical(h), 2 * int(p["margin"]) + 2)
	var i := _img(lw, lh, pal("crimson"))
	_rect(i, 1, 1, lw - 2, 1, pal("crimson_hi"))
	_rect(i, 1, lh - 2, lw - 2, 1, pal("crimson_dk"))
	var at := int(p["stitch_at"])
	for x in range(at, lw - at, int(p["stitch_every"])):
		i.set_pixel(x, at, pal("gold"))
		i.set_pixel(x, lh - 1 - at, pal("gold"))
	_ring(i, 0, pal("ink"))
	return _keep(k, _tex(i))


## An inset box, as in an inventory: dark inside, a dark edge top and left, a light edge bottom and right. Lit: a gold frame.
static func inset_tex(w: int, h: int, lit: bool = false) -> ImageTexture:
	var k := _key("inset", "%d,%d,%s" % [w, h, lit])
	if _memo.has(k):
		return _memo[k]
	var m := int(piece("inset")["margin"])
	var lw := maxi(_logical(w), 2 * m + 1)
	var lh := maxi(_logical(h), 2 * m + 1)
	var i := _img(lw, lh, pal("slot_bg"))
	_rect(i, 0, 0, lw, 1, pal("ink"))
	_rect(i, 0, 0, 1, lh, pal("ink"))
	_rect(i, 0, lh - 1, lw, 1, pal("slot_lo"))
	_rect(i, lw - 1, 0, 1, lh, pal("slot_lo"))
	_rect(i, 1, 1, lw - 2, 1, pal("wood_lo"))
	_rect(i, 1, 1, 1, lh - 2, pal("wood_lo"))
	if lit:
		_ring(i, 0, pal("gold"))
		_ring(i, 1, pal("gold_dk"))
	return _keep(k, _tex(i))


## A segmented bar: an ink frame, a dark track and a fill with a lit top and a shaded bottom, ticked every few pixels.
## `colors` is the name of a palette triple (light, mid, shade): "hp", "mp" or "carry".
static func bar_tex(w: int, h: int, frac: float, colors: String) -> ImageTexture:
	var pct := int(clampf(frac, 0.0, 1.0) * 100.0)
	var k := _key("bar", "%d,%d,%d,%s" % [w, h, pct, colors])
	if _memo.has(k):
		return _memo[k]
	var p := piece("bar")
	var c := triple(colors)
	var lw := maxi(_logical(w), 8)
	var lh := maxi(_logical(h), 6)
	var i := _img(lw, lh, pal("ink"))
	_rect(i, 1, 1, lw - 2, lh - 2, pal("track"))
	var fw := int(float(lw - 4) * float(pct) / 100.0)
	if fw > 0:
		_rect(i, 2, 2, fw, lh - 4, c[1])
		_rect(i, 2, 2, fw, 1, c[0])
		_rect(i, 2, lh - 3, fw, 1, c[2])
		for x in range(int(p["segment_at"]), fw + 2, int(p["segment_every"])):
			_rect(i, x, 3, 1, lh - 6, c[2])
	return _keep(k, _tex(i))


## The header: wooden planks with seams and grain, an ink edge and a gold line under it.
static func header_tex(w: int, h: int) -> ImageTexture:
	var k := _key("header", "%d,%d" % [w, h])
	if _memo.has(k):
		return _memo[k]
	var p := piece("header")
	var lw := _logical(w)
	var lh := maxi(_logical(h), 4)
	var i := _img(lw, lh, pal("wood"))
	var r := CosmeticRng.keyed("skin_header")
	var rate := float(p["speck"])
	for y in lh:
		for x in lw:
			var q := r.randf()
			if q < rate:
				i.set_pixel(x, y, pal("wood_hi"))
			elif q < rate * 2.0:
				i.set_pixel(x, y, pal("wood_lo"))
	for x in range(0, lw, int(p["plank"])):
		_rect(i, x, 0, 1, lh, pal("wood_lo"))
	_rect(i, 0, 0, lw, 1, pal("wood_hi"))
	_rect(i, 0, lh - 3, lw, 1, pal("gold_dk"))
	_rect(i, 0, lh - 2, lw, 1, pal("gold"))
	_rect(i, 0, lh - 1, lw, 1, pal("ink"))
	return _keep(k, _tex(i))


## A small parchment plate (a ring item, a thing menu's choice, a name tag): ink outline, a brown or, lit, gold line inside it, a bevel.
static func plate_tex(w: int, h: int, lit: bool = false) -> ImageTexture:
	var k := _key("plate", "%d,%d,%s" % [w, h, lit])
	if _memo.has(k):
		return _memo[k]
	var m := int(piece("plate")["margin"])
	var lw := maxi(_logical(w), 2 * m + 1)
	var lh := maxi(_logical(h), 2 * m + 1)
	var i := _img(lw, lh, pal("parch_hi") if lit else pal("parch"))
	_rect(i, 2, 2, lw - 4, 1, pal("parch_hi"))
	_rect(i, 2, 2, 1, lh - 4, pal("parch_hi"))
	_rect(i, 2, lh - 3, lw - 4, 1, pal("parch_lo"))
	_rect(i, lw - 3, 2, 1, lh - 4, pal("parch_lo"))
	_ring(i, 1, pal("gold") if lit else pal("brown"))
	_ring(i, 0, pal("ink"))
	if lit:
		_rect(i, 2, 2, lw - 4, 1, pal("gold_dk"))   # (the lit line is doubled: gold outside, its shade inside)
		_rect(i, 2, lh - 3, lw - 4, 1, pal("gold_dk"))
		_rect(i, 2, 2, 1, lh - 4, pal("gold_dk"))
		_rect(i, lw - 3, 2, 1, lh - 4, pal("gold_dk"))
	return _keep(k, _tex(i))


## A small ink badge for light text (a key, the gold in the header): ink with a wooden line inside it, a gold one when lit.
static func badge_tex(w: int, h: int, lit: bool = false) -> ImageTexture:
	var k := _key("badge", "%d,%d,%s" % [w, h, lit])
	if _memo.has(k):
		return _memo[k]
	var m := int(piece("badge")["margin"])
	var lw := maxi(_logical(w), 2 * m + 1)
	var lh := maxi(_logical(h), 2 * m + 1)
	var i := _img(lw, lh, pal("ink"))
	_ring(i, 1, pal("gold_dk") if lit else pal("wood_hi"))
	return _keep(k, _tex(i))


## A raised key, as on a parchment page: lit top and left, shaded bottom and right, an ink outline. `state`: "normal", "hover" (a gold
## line inside the outline), "pressed" (sunk, shaded) or "disabled" (flat, a brown outline). (If the screens' own button set lands first,
## the integrator keeps one of the two.)
static func button_tex(w: int, h: int, state: String) -> ImageTexture:
	var k := _key("button", "%d,%d,%s" % [w, h, state])
	if _memo.has(k):
		return _memo[k]
	var m := int(piece("button")["margin"])
	var lw := maxi(_logical(w), 2 * m + 1)
	var lh := maxi(_logical(h), 2 * m + 1)
	var fill := pal("parch_hi") if state == "hover" else (pal("parch_lo") if state == "pressed" else pal("parch"))
	var i := _img(lw, lh, fill)
	if state == "normal" or state == "hover":
		_rect(i, 1, 1, lw - 2, 1, pal("parch_hi"))
		_rect(i, 1, 1, 1, lh - 2, pal("parch_hi"))
		_rect(i, 1, lh - 2, lw - 2, 1, pal("parch_lo"))
		_rect(i, lw - 2, 1, 1, lh - 2, pal("parch_lo"))
	elif state == "pressed":
		_rect(i, 1, 1, lw - 2, 1, pal("brown"))
		_rect(i, 1, 1, 1, lh - 2, pal("brown"))
	if state == "hover":
		_ring(i, 1, pal("gold"))
		_ring(i, 2, pal("gold_hi"))
	_ring(i, 0, pal("brown") if state == "disabled" else pal("ink"))
	return _keep(k, _tex(i))


## A wooden tab: ink outline, planks, a lit top edge. `state`: "off", "hover" or "on" (the open one: lighter wood, a gold frame).
static func tab_tex(w: int, h: int, state: String) -> ImageTexture:
	var k := _key("tab", "%d,%d,%s" % [w, h, state])
	if _memo.has(k):
		return _memo[k]
	var m := int(piece("tab")["margin"])
	var lw := maxi(_logical(w), 2 * m + 1)
	var lh := maxi(_logical(h), 2 * m + 1)
	var i := _img(lw, lh, pal("wood") if state == "off" else pal("wood_hi"))
	_rect(i, 1, 1, lw - 2, 1, pal("wood_hi") if state == "off" else pal("gold_hi"))
	_rect(i, 1, lh - 2, lw - 2, 1, pal("wood_lo"))
	if state == "on":
		_ring(i, 1, pal("gold"))
		_rect(i, 2, 2, lw - 4, 1, pal("gold_hi"))
	_ring(i, 0, pal("ink"))
	return _keep(k, _tex(i))


## A one-colour 8 by 8 picture from rows of "#" and ".", white so it can be tinted when drawn.
static func icon_tex(name: String) -> ImageTexture:
	var k := "icon|" + name
	if _memo.has(k):
		return _memo[k]
	var rows: Array = data()["icons"][name]
	var i := _img(8, 8, Color(0, 0, 0, 0))
	for y in mini(rows.size(), 8):
		for x in mini(str(rows[y]).length(), 8):
			if str(rows[y])[x] == "#":
				i.set_pixel(x, y, Color.WHITE)
	return _keep(k, ImageTexture.create_from_image(i))


# ---------------------------------------------------------------- styleboxes (nine patches of the textures above, tiled, never stretched)

static func _nine(kind: String, tex: ImageTexture, margin: int, content: Array, extra: String = "") -> StyleBoxTexture:
	var k := _key("box_" + kind, extra)
	if _memo.has(k):
		return _memo[k]
	var s := pixel()
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_texture_margin_all(margin * s)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.content_margin_left = float(content[0] * s)
	sb.content_margin_right = float(content[0] * s)
	sb.content_margin_top = float(content[1] * s)
	sb.content_margin_bottom = float(content[1] * s)
	return _keep(k, sb)


static func panel_box() -> StyleBoxTexture:
	var p := piece("panel")
	var b: Array = p["base"]
	return _nine("panel", panel_tex(int(b[0]) * pixel(), int(b[1]) * pixel()), int(p["margin"]), [p["content"], p["content"]])


static func frame_box() -> StyleBoxTexture:
	var p := piece("frame")
	var b: Array = p["base"]
	return _nine("frame", frame_tex(int(b[0]) * pixel(), int(b[1]) * pixel()), int(p["margin"]), [p["content"], p["content"]])


static func ribbon_box() -> StyleBoxTexture:
	var p := piece("ribbon")
	var b: Array = p["base"]
	return _nine("ribbon", ribbon_tex(int(b[0]) * pixel(), int(b[1]) * pixel()), int(p["margin"]), p["content"])


static func inset_box(lit: bool = false) -> StyleBoxTexture:
	var p := piece("inset")
	var b: Array = p["base"]
	return _nine("inset", inset_tex(int(b[0]) * pixel(), int(b[1]) * pixel(), lit), int(p["margin"]), [p["content"], p["content"]], str(lit))


static func plate_box(lit: bool = false) -> StyleBoxTexture:
	var p := piece("plate")
	var b: Array = p["base"]
	return _nine("plate", plate_tex(int(b[0]) * pixel(), int(b[1]) * pixel(), lit), int(p["margin"]), p["content"], str(lit))


static func badge_box(lit: bool = false) -> StyleBoxTexture:
	var p := piece("badge")
	var b: Array = p["base"]
	return _nine("badge", badge_tex(int(b[0]) * pixel(), int(b[1]) * pixel(), lit), int(p["margin"]), p["content"], str(lit))


## The header's wooden strip: a row of planks `h` tall, tiled across (a tile holds `header_tile` planks, so the seams stay even).
static func header_strip(h: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = header_tex(int(piece("header")["plank"]) * int(hud("header_tile")) * pixel(), int(h))
	r.stretch_mode = TextureRect.STRETCH_TILE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	r.offset_bottom = h
	r.set_meta("skin_done", true)
	return r


## A popup menu (the thing menu) as a parchment sheet whose pointed-at choice is a lit plate.
static func dress_popup(m: PopupMenu) -> void:
	m.add_theme_stylebox_override("panel", panel_box())
	m.add_theme_stylebox_override("hover", plate_box(true))
	var sep := StyleBoxFlat.new()
	sep.bg_color = pal("brown")
	sep.content_margin_top = 1.0
	sep.content_margin_bottom = 1.0
	m.add_theme_stylebox_override("separator", sep)
	m.add_theme_color_override("font_color", pal("ink"))
	m.add_theme_color_override("font_hover_color", pal("ink"))
	m.add_theme_color_override("font_disabled_color", pal("crimson_dk"))
	m.add_theme_color_override("font_separator_color", pal("ink"))
	m.add_theme_constant_override("v_separation", 8)
	m.add_theme_constant_override("outline_size", 0)


static func button_box(state: String) -> StyleBoxTexture:
	var p := piece("button")
	var b: Array = p["base"]
	return _nine("button", button_tex(int(b[0]) * pixel(), int(b[1]) * pixel(), state), int(p["margin"]), p["content"], state)


static func tab_box(state: String) -> StyleBoxTexture:
	var p := piece("tab")
	var b: Array = p["base"]
	return _nine("tab", tab_tex(int(b[0]) * pixel(), int(b[1]) * pixel(), state), int(p["margin"]), p["content"], state)


## The face of a pane: parchment, or wood.
static func face_box(face: String) -> StyleBoxTexture:
	return frame_box() if face == "wood" else panel_box()


# ---------------------------------------------------------------- dressing controls

## A label's text drawn light over an ink outline (on a bar or a slot).
static func outline(c: Control, size: int = 3) -> void:
	c.add_theme_color_override("font_outline_color", pal("ink"))
	c.add_theme_constant_override("outline_size", size)


## The title in a ribbon.
static func dress_title(l: Label) -> void:
	var t: Dictionary = data()["title"]
	l.add_theme_font_size_override("font_size", int(t["size"]))
	l.add_theme_color_override("font_color", pal(str(t["text"])))
	l.add_theme_color_override("font_outline_color", pal(str(t["outline"])))
	l.add_theme_constant_override("outline_size", int(t["outline_size"]))
	l.set_meta("skin_done", true)


## A button as a slot: dark inside, gold when pointed at.
static func dress_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", inset_box(false))
	b.add_theme_stylebox_override("hover", inset_box(true))
	b.add_theme_stylebox_override("pressed", inset_box(true))
	b.add_theme_stylebox_override("disabled", inset_box(false))
	b.add_theme_color_override("font_color", pal("parch_hi"))
	b.add_theme_color_override("font_hover_color", pal("gold_hi"))
	b.add_theme_color_override("font_pressed_color", pal("gold_hi"))
	b.add_theme_color_override("font_disabled_color", pal("slot_dim"))   # (quiet but readable on the slot)
	b.set_meta("skin_done", true)


## The shadow that falls down and to the right of a pane, behind its face.
static func shadow(host: Control) -> Panel:
	var s := Panel.new()   # (not a ColorRect: a ColorRect child of a pane means the whole window is dimmed)
	var o: Array = data()["shadow"]["offset"]
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, float(data()["shadow"]["alpha"]))
	s.add_theme_stylebox_override("panel", flat)
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.offset_left = float(o[0])
	s.offset_top = float(o[1])
	s.offset_right = float(o[0])
	s.offset_bottom = float(o[1])
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.set_meta("skin_done", true)
	return s


## Whether `n` sits in a box with a dark or a pictured face of its own (a Kit.panel, a button, a slot) between it and `host`: its
## colours were chosen for that and stay.
static func in_dark_box(n: Node, host: Node) -> bool:
	var p := n.get_parent()
	while p != null and p != host:
		if p is BaseButton:
			return true
		if p is Container and p is PanelContainer and not p.has_meta("skin_face") and p.has_theme_stylebox_override("panel"):
			var sb: StyleBox = p.get_theme_stylebox("panel")
			if sb is StyleBoxTexture:
				return true
			if sb is StyleBoxFlat and (sb as StyleBoxFlat).bg_color.a > 0.3 and luminance((sb as StyleBoxFlat).bg_color) < 0.2:
				return true
		p = p.get_parent()
	return false


## Makes one control read on the pane's face: labels get the colours of the skin, a kit button becomes a slot.
static func dress(n: Node, host: Control, face: String) -> void:
	if not (n is Control) or n.has_meta("skin_done"):
		return
	if n is Label or n is RichTextLabel:
		n.set_meta("skin_done", true)
		if in_dark_box(n, host):
			return
		var key := "font_color" if n is Label else "default_color"
		var c: Color = n.get_theme_color(key) if n.has_theme_color_override(key) else (pal("ink") if face == "parch" else pal("wood_text"))
		if n.has_theme_color_override(key):
			c = on_face(c, face)
		n.add_theme_color_override(key, c)
		if face == "wood" and n is Label:
			outline(n)
		if n is RichTextLabel:   # BBCode colours in its text are made to read too, whenever the text is set
			(n as RichTextLabel).draw.connect(func(): _retint_bb.call_deferred(n, face))
	elif n is Button and n.has_meta("tap_base") and not n.has_meta("skin_keep"):
		dress_button(n)


## The `[color=#rrggbb]` tags in a rich label's text, put on the pane's face. Only text not yet seen is looked at, and a colour already
## made to read is left, so this settles after one pass.
static func _retint_bb(n: RichTextLabel, face: String) -> void:
	if not is_instance_valid(n) or n.text == str(n.get_meta("skin_bb", "")):
		return
	var re := RegEx.new()
	re.compile("\\[color=#([0-9a-fA-F]{6})\\]")
	var out := ""
	var at := 0
	for m in re.search_all(n.text):
		out += n.text.substr(at, m.get_start() - at) + "[color=#%s]" % on_face(Color("#" + m.get_string(1)), face).to_html(false)
		at = m.get_end()
	out += n.text.substr(at)
	n.set_meta("skin_bb", out)
	if out != n.text:
		n.text = out


## Dresses everything that is added under a pane, as it is added (panels build and rebuild their contents after the pane is made),
## and what is there already. Stops when the pane leaves the tree.
static func watch(host: Control, face: String) -> void:
	var tree := host.get_tree()
	if tree == null:
		return
	var cb := func(n: Node):
		if host.is_ancestor_of(n):
			dress(n, host, face)
	tree.node_added.connect(cb)
	host.tree_exiting.connect(func():
		if tree.node_added.is_connected(cb):
			tree.node_added.disconnect(cb))
	var todo: Array = host.get_children()
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		dress(n, host, face)
		todo.append_array(n.get_children())


## Makes a ProgressBar draw as a segmented bar of the skin: the bar keeps its value and range, the skin draws over it.
static func dress_bar(pb: ProgressBar, kind: String) -> void:
	pb.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	pb.add_theme_stylebox_override("fill", StyleBoxEmpty.new())
	pb.custom_minimum_size.y = float(int(piece("bar")["height"]) * pixel())
	var v: Control = load("res://ui/play/skin_bar.gd").new()   # loaded, not preloaded: the bar script preloads this one
	v.pb = pb
	v.kind = kind
	pb.add_child(v)
	pb.value_changed.connect(func(_x): v.queue_redraw())
	pb.set_meta("skin_bar", v)


## Sets the words a skinned bar shows over its fill, and the kind of fill ("load_bad" for a burdened pack).
static func bar_text(pb: ProgressBar, text: String, kind: String = "") -> void:
	var v: Variant = pb.get_meta("skin_bar", null)
	if v == null:
		return
	v.text = text
	if kind != "":
		v.kind = kind
	v.queue_redraw()


# ---------------------------------------------------------------- the check

static func _color_ok(v: Variant) -> bool:
	return typeof(v) == TYPE_STRING and Color.html_is_valid(str(v))


## What is wrong with the skin's data, one line each. With no argument it checks data/ui/skin.json; a dictionary is checked instead
## (the tests use it to break the data).
static func validate(dat: Dictionary = {}) -> Array:
	var d: Dictionary = dat if not dat.is_empty() else data()
	var bad: Array = []
	if d.is_empty():
		return ["skin.json: missing or not an object"]
	for k in ["pixel", "shadow", "faces", "title", "pieces", "hud", "icons", "bars", "variants", "text_maps", "contrast"]:
		if not d.has(k):
			bad.append("skin.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	if typeof(d["pixel"]) not in [TYPE_INT, TYPE_FLOAT] or float(d["pixel"]) < 1.0 or float(d["pixel"]) != floorf(float(d["pixel"])):
		bad.append("skin.json: pixel must be a whole number, at least 1")
	var sh: Variant = d["shadow"]
	if typeof(sh) != TYPE_DICTIONARY or typeof(sh.get("offset")) != TYPE_ARRAY or (sh["offset"] as Array).size() != 2 or not (float(sh.get("alpha", -1.0)) >= 0.0 and float(sh.get("alpha", -1.0)) <= 1.0):
		bad.append("skin.json: shadow needs an offset [x, y] and an alpha from 0 to 1")
	for name in PIECES:
		if typeof(d["pieces"]) != TYPE_DICTIONARY or not (d["pieces"] as Dictionary).has(name) or typeof(d["pieces"][name]) != TYPE_DICTIONARY:
			bad.append("skin.json: pieces.%s is missing" % name)
	if not bad.is_empty():
		return bad
	for name in ["panel", "frame", "ribbon", "inset", "plate", "badge"]:
		var pc: Dictionary = d["pieces"][name]
		var b: Variant = pc.get("base")
		if typeof(b) != TYPE_ARRAY or (b as Array).size() != 2 or float(b[0]) != floorf(float(b[0])) or float(b[1]) != floorf(float(b[1])):
			bad.append("skin.json: pieces.%s.base must be [width, height] in whole pixels" % name)
		elif float(pc.get("margin", 0)) * 2.0 + 1.0 > minf(float(b[0]), float(b[1])):
			bad.append("skin.json: pieces.%s.margin leaves no middle in its base" % name)
	for k in d["faces"]:
		if str(d["faces"][k]) not in ["parch", "wood"]:
			bad.append("skin.json: faces.%s must be parch or wood" % k)
	if typeof(d["hud"]) != TYPE_DICTIONARY:
		bad.append("skin.json: hud must be an object")
	else:
		for f in HUD_KEYS:
			if not (d["hud"] as Dictionary).has(f) or typeof(d["hud"][f]) not in [TYPE_INT, TYPE_FLOAT] or float(d["hud"][f]) <= 0.0:
				bad.append("skin.json: hud.%s must be a number above 0" % f)
		if bad.is_empty() and (int(d["hud"]["slot_px"]) % int(d["pixel"]) != 0 or int(d["hud"]["slot_px"]) < 9 * int(d["pixel"])):
			bad.append("skin.json: hud.slot_px must be a whole multiple of the pixel, wide enough for a slot's frame and its picture")
	for k in ["bar"]:
		for f in ["height", "segment_every", "segment_at", "icon_scale", "text_size"]:
			if not (d["pieces"][k] as Dictionary).has(f) or float(d["pieces"][k][f]) < 1.0:
				bad.append("skin.json: pieces.%s.%s must be at least 1" % [k, f])
	for name in d["icons"]:
		var rows: Variant = d["icons"][name]
		if typeof(rows) != TYPE_ARRAY or (rows as Array).size() != 8:
			bad.append("skin.json: icon %s must be 8 rows" % name)
		else:
			for r in rows:
				if str(r).length() != 8:
					bad.append("skin.json: icon %s has a row that is not 8 wide" % name)
					break
	for name in d["bars"]:
		var spec: Variant = d["bars"][name]
		if typeof(spec) != TYPE_DICTIONARY or not d["icons"].has(str(spec.get("icon", ""))) or str(spec.get("colors", "")) not in TRIPLES:
			bad.append("skin.json: bars.%s needs an icon that exists and colors of hp, mp or carry" % name)
	if not (d["variants"] as Dictionary).has("standard") or not (d["variants"] as Dictionary).has("high_contrast"):
		bad.append("skin.json: variants needs standard and high_contrast")
		return bad
	for vn in d["variants"]:
		var v: Dictionary = d["variants"][vn]
		for k in PALETTE_KEYS:
			if not v.has(k) or not _color_ok(v[k]):
				bad.append("skin.json: %s.%s is missing or not a colour" % [vn, k])
		for k in TRIPLES:
			var t: Variant = v.get(k)
			if typeof(t) != TYPE_ARRAY or (t as Array).size() != 3 or not (t as Array).all(func(c): return _color_ok(c)):
				bad.append("skin.json: %s.%s must be three colours (light, mid, shade)" % [vn, k])
	if not bad.is_empty():
		return bad
	for face in d["text_maps"]:
		for hex in d["text_maps"][face]:
			if not Color.html_is_valid(str(hex)):
				bad.append("skin.json: text_maps.%s key %s is not a colour" % [face, hex])
			for vn in d["variants"]:
				if not (d["variants"][vn] as Dictionary).has(str(d["text_maps"][face][hex])):
					bad.append("skin.json: text_maps.%s.%s names %s, which %s lacks" % [face, hex, d["text_maps"][face][hex], vn])
	for pair in d["contrast"]:
		if typeof(pair) != TYPE_DICTIONARY or not pair.has("fg") or not pair.has("bg") or not pair.has("min") or not pair.has("min_hc"):
			bad.append("skin.json: a contrast pair needs fg, bg, min and min_hc")
			continue
		for vn in d["variants"]:
			var v: Dictionary = d["variants"][vn]
			if not v.has(str(pair["fg"])) or not v.has(str(pair["bg"])):
				bad.append("skin.json: contrast pair %s on %s names a colour %s lacks" % [pair["fg"], pair["bg"], vn])
				continue
			var need := float(pair["min_hc"] if vn == "high_contrast" else pair["min"])
			var got := contrast(Color(str(v[str(pair["fg"])])), Color(str(v[str(pair["bg"])])))
			if got < need:
				bad.append("skin.json: %s on %s (%s) is %.1f to 1 in %s, needs %.1f" % [pair["fg"], pair["bg"], pair.get("why", ""), got, vn, need])
	return bad
