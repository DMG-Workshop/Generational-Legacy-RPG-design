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


## A gold-studded button on parchment: a lit face with an ink outline and a gold stud in each corner. States: "normal", "hover"
## (a gold frame and lit studs), "pressed" (a shaded face, the bevel turned over) and "disabled" (flat, no studs). (Added with the
## battle screen's skin; if another branch adds a `button` piece too, the two are the same job: keep one.)
static func stud_tex(w: int, h: int, state: String = "normal") -> ImageTexture:
	var k := _key("stud", "%d,%d,%s" % [w, h, state])
	if _memo.has(k):
		return _memo[k]
	var m := int(piece("stud")["margin"])
	var lw := maxi(_logical(w), 2 * m + 1)
	var lh := maxi(_logical(h), 2 * m + 1)
	var face := pal("parch_lo") if state == "pressed" else (pal("parch") if state == "disabled" else pal("parch_hi"))
	var i := _img(lw, lh, face)
	var hi := pal("parch_lo") if state == "pressed" else pal("parch_hi")
	var lo := pal("parch_hi") if state == "pressed" else pal("parch_lo")
	if state != "disabled":
		_rect(i, 1, 1, lw - 2, 1, hi)
		_rect(i, 1, 1, 1, lh - 2, hi)
		_rect(i, 1, lh - 2, lw - 2, 1, lo)
		_rect(i, lw - 2, 1, 1, lh - 2, lo)
	_ring(i, 0, pal("brown") if state == "disabled" else pal("ink"))
	if state == "hover" or state == "pressed":
		_ring(i, 1, pal("gold"))
		_ring(i, 2, pal("gold_dk"))
	if state != "disabled":
		var lit := pal("gold_hi") if state == "hover" else pal("gold")
		for pt in [Vector2i(2, 2), Vector2i(lw - 3, 2), Vector2i(2, lh - 3), Vector2i(lw - 3, lh - 3)]:
			i.set_pixel(pt.x, pt.y, lit)
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


static func stud_box(state: String = "normal") -> StyleBoxTexture:
	var p := piece("stud")
	var b: Array = p["base"]
	return _nine("stud", stud_tex(int(b[0]) * pixel(), int(b[1]) * pixel(), state), int(p["margin"]), p["content"], state)


## The ring a gamepad or the keyboard's focus draws round a skinned button: gold, never only a colour change.
static func button_focus() -> StyleBoxFlat:
	var f := StyleBoxFlat.new()
	f.draw_center = false
	f.set_border_width_all(2 * pixel())
	f.border_color = pal("gold_hi")
	f.set_expand_margin_all(float(pixel()))
	return f


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


## A button of the battle screen's parchment panels: a gold-studded button, lit gold when pointed at or focused, ink text.
static func dress_battle_button(b: Button) -> void:
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, stud_box(st))
	b.add_theme_stylebox_override("focus", button_focus())
	b.add_theme_color_override("font_color", pal("ink"))
	b.add_theme_color_override("font_hover_color", pal("crimson_dk"))
	b.add_theme_color_override("font_focus_color", pal("crimson_dk"))
	b.add_theme_color_override("font_pressed_color", pal("ink"))
	b.add_theme_color_override("font_disabled_color", pal("ink_dim"))
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


## A slim segmented bar for a plate (no picture, no words): the bar keeps its value and range, the skin draws over it at its own size.
static func dress_thin_bar(pb: ProgressBar, kind: String) -> void:
	pb.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	pb.add_theme_stylebox_override("fill", StyleBoxEmpty.new())
	var v: Control = load("res://ui/play/skin_bar.gd").new()
	v.pb = pb
	v.kind = kind
	v.thin = true
	pb.add_child(v)
	pb.value_changed.connect(func(_x): v.queue_redraw())
	pb.changed.connect(func(): v.queue_redraw())
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


# ---------------------------------------------------------------- the full-screen text screens (ui/play/skin_screen.gd)

static func screens() -> Dictionary:
	return data().get("screens", {})


## Whether a full-screen text screen (title, life, succession, ending, menu, controls) wears the skin: on every device and window size
## (it was made to fit a phone), unless the data switches it off. `host` only says there is a screen.
static func screen_active(host: Node) -> bool:
	return host != null and not data().is_empty() and not GameData.mobile.is_empty() and bool(screens().get("enabled", false))   # (the text scale reads the mobile data)


static func night(key: String) -> Color:
	return Color(str(screens()["night"][variant()][key]))


## One button picture: "normal", "hover", "pressed", "disabled" or "on" (chosen). Wood with a lit top and left, an ink outline and a
## gold stud in each corner; pointed at, a gold frame; chosen, crimson inside the gold frame; shut, flat and dark with dull studs.
static func plank_tex(state: String, w: int, h: int) -> ImageTexture:
	var k := _key("plank", "%s,%d,%d" % [state, w, h])
	if _memo.has(k):
		return _memo[k]
	var p: Dictionary = screens()["plank"]
	var m := int(p["margin"])
	var lw := maxi(_logical(w), 2 * m + 2)
	var lh := maxi(_logical(h), 2 * m + 2)
	var face := pal("wood")
	var lit := pal("wood_hi")
	var shade := pal("wood_lo")
	var stud := pal("gold")
	var stud_lo := pal("gold_dk")
	match state:
		"hover":
			face = pal("wood_hi")
			lit = pal("wood_hi").lightened(0.15)
		"pressed":
			face = pal("wood_lo")
			lit = pal("wood_lo")
			shade = pal("wood_lo").darkened(0.3)
		"disabled":
			face = pal("wood_lo")
			lit = pal("wood_lo")
			shade = pal("wood_lo")
			stud = pal("wood_hi")
			stud_lo = pal("wood_hi")
		"on":
			face = pal("crimson")
			lit = pal("crimson_hi")
			shade = pal("crimson_dk")
	var i := _img(lw, lh, face)
	_rect(i, 1, 1, lw - 2, 1, lit)
	_rect(i, 1, 1, 1, lh - 2, lit)
	_rect(i, 1, lh - 2, lw - 2, 1, shade)
	_rect(i, lw - 2, 1, 1, lh - 2, shade)
	var st := int(p["stud"])
	var at := int(p["stud_at"])
	for pt in [Vector2i(at, at), Vector2i(lw - at - st, at), Vector2i(at, lh - at - st), Vector2i(lw - at - st, lh - at - st)]:
		_rect(i, pt.x, pt.y, st, st, stud)
		i.set_pixel(pt.x + st - 1, pt.y + st - 1, stud_lo)
	_ring(i, 0, pal("ink"))
	if state == "hover" or state == "pressed" or state == "on":
		_ring(i, 0, pal("gold_dk"))
		_ring(i, 1, pal("gold"))
	return _keep(k, _tex(i))


## The ring a button shows while the keyboard or a pad is on it: gold, two pixels thick, nothing inside.
static func focus_tex(w: int, h: int) -> ImageTexture:
	var k := _key("focus", "%d,%d" % [w, h])
	if _memo.has(k):
		return _memo[k]
	var m := int(screens()["focus"]["margin"])
	var lw := maxi(_logical(w), 2 * m + 1)
	var lh := maxi(_logical(h), 2 * m + 1)
	var i := _img(lw, lh, Color(0, 0, 0, 0))
	_ring(i, 0, pal("ink"))
	_ring(i, 1, pal("gold_hi"))
	_ring(i, 2, pal("gold_hi"))
	return _keep(k, _tex(i))


## A text field: light parchment inside, a dark edge top and left, a shaded one bottom and right.
static func field_tex(w: int, h: int) -> ImageTexture:
	var k := _key("field", "%d,%d" % [w, h])
	if _memo.has(k):
		return _memo[k]
	var m := int(screens()["field"]["margin"])
	var lw := maxi(_logical(w), 2 * m + 1)
	var lh := maxi(_logical(h), 2 * m + 1)
	var i := _img(lw, lh, pal("parch_hi"))
	_ring(i, 0, pal("ink"))
	_rect(i, 1, 1, lw - 2, 1, pal("brown"))
	_rect(i, 1, 1, 1, lh - 2, pal("brown"))
	_rect(i, 1, lh - 2, lw - 2, 1, pal("parch_lo"))
	_rect(i, lw - 2, 1, 1, lh - 2, pal("parch_lo"))
	return _keep(k, _tex(i))


## The dark well a journal reads in: an inset like the slot's, but deeper, so coloured news reads on it.
static func well_tex(w: int, h: int) -> ImageTexture:
	var k := _key("well", "%d,%d" % [w, h])
	if _memo.has(k):
		return _memo[k]
	var m := int(piece("inset")["margin"])
	var lw := maxi(_logical(w), 2 * m + 1)
	var lh := maxi(_logical(h), 2 * m + 1)
	var i := _img(lw, lh, night("well"))
	_rect(i, 0, 0, lw, 1, pal("ink"))
	_rect(i, 0, 0, 1, lh, pal("ink"))
	_rect(i, 0, lh - 1, lw, 1, pal("slot_lo"))
	_rect(i, lw - 1, 0, 1, lh, pal("slot_lo"))
	_rect(i, 1, lh - 2, lw - 2, 1, pal("brown"))
	_rect(i, lw - 2, 1, 1, lh - 2, pal("brown"))
	return _keep(k, _tex(i))


## The night sky: bands of colour from the top to the bottom (stretched over the screen, so each band is a wide stripe).
static func sky_tex() -> ImageTexture:
	var k := _key("sky", "")
	if _memo.has(k):
		return _memo[k]
	var n := int(screens()["sky"]["bands"])
	var i := _img(4, n, night("top"))
	for y in n:
		_rect(i, 0, y, 4, 1, night("top").lerp(night("bottom"), float(y) / float(maxi(1, n - 1))))
	return _keep(k, ImageTexture.create_from_image(i))


## A tile of stars (drawn tiled over the sky): single pixels and a few small crosses.
static func stars_tex() -> ImageTexture:
	var k := _key("stars", "")
	if _memo.has(k):
		return _memo[k]
	var sp: Dictionary = screens()["sky"]
	var t: Array = sp["tile"]
	var i := _img(int(t[0]), int(t[1]), Color(0, 0, 0, 0))
	var r := CosmeticRng.keyed("skin_stars")
	for n in int(sp["stars"]):
		var x := 2 + r.randi() % (int(t[0]) - 4)
		var y := 2 + r.randi() % (int(t[1]) - 4)
		if n % 4 == 0:
			i.set_pixel(x, y, night("star"))
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				i.set_pixel(x + o.x, y + o.y, night("star_dim"))
		else:
			i.set_pixel(x, y, night("star") if n % 2 == 0 else night("star_dim"))
	return _keep(k, _tex(i))


## A strip of hills along the bottom that tiles sideways: heights are sums of waves whose periods divide the tile.
static func hills_tex() -> ImageTexture:
	var k := _key("hills", "")
	if _memo.has(k):
		return _memo[k]
	var sp: Dictionary = screens()["sky"]
	var w := int(sp["hill_tile"])
	var h := int(sp["hill_height"])
	var i := _img(w, h, Color(0, 0, 0, 0))
	for x in w:
		var a := TAU * float(x) / float(w)
		var top := float(h) * 0.55 - sin(a) * float(h) * 0.22 - sin(a * 3.0 + 1.0) * float(h) * 0.1
		for y in range(maxi(0, int(top)), h):
			i.set_pixel(x, y, night("hill_hi") if y == int(top) else night("hill"))
	return _keep(k, _tex(i))


static func plank_box(state: String) -> StyleBoxTexture:
	var p: Dictionary = screens()["plank"]
	var b: Array = p["base"]
	return _nine("splank", plank_tex(state, int(b[0]) * pixel(), int(b[1]) * pixel()), int(p["margin"]), p["content"], state)


static func focus_box() -> StyleBoxTexture:
	var p: Dictionary = screens()["focus"]
	var b: Array = p["base"]
	var sb := _nine("sfocus", focus_tex(int(b[0]) * pixel(), int(b[1]) * pixel()), int(p["margin"]), [0, 0])
	sb.draw_center = false
	sb.set_expand_margin_all(float(int(p["expand"]) * pixel()))
	return sb


static func field_box() -> StyleBoxTexture:
	var p: Dictionary = screens()["field"]
	var b: Array = p["base"]
	return _nine("sfield", field_tex(int(b[0]) * pixel(), int(b[1]) * pixel()), int(p["margin"]), p["content"])


static func well_box() -> StyleBoxTexture:
	var p := piece("inset")
	var b: Array = p["base"]
	return _nine("swell", well_tex(int(b[0]) * pixel(), int(b[1]) * pixel()), int(p["margin"]), [p["content"], p["content"]])


## A rule between sections on parchment: a brown line.
static func rule_box() -> StyleBoxLine:
	var k := _key("rule", "")
	if _memo.has(k):
		return _memo[k]
	var l := StyleBoxLine.new()
	l.color = pal("brown")
	l.thickness = pixel()
	return _keep(k, l)


## A button of a full-screen screen: a wooden plank with studs, lit gold when pointed at, crimson when chosen (the meta `skin_on`).
## A text colour the button already carries is read as the kit's light-on-dark one and put on wood; a shut button's text stays readable.
static func dress_screen_button(b: Button) -> void:
	var on := bool(b.get_meta("skin_on", false))
	b.add_theme_stylebox_override("normal", plank_box("on" if on else "normal"))
	b.add_theme_stylebox_override("hover", plank_box("on" if on else "hover"))
	b.add_theme_stylebox_override("pressed", plank_box("pressed"))
	b.add_theme_stylebox_override("disabled", plank_box("disabled"))
	b.add_theme_stylebox_override("focus", focus_box())
	var base := pal("gold_hi") if on else pal("wood_text")
	if not on and not b.has_meta("skin_font") and b.has_theme_color_override("font_color"):
		base = on_face(b.get_theme_color("font_color"), "wood")
	b.set_meta("skin_font", true)
	b.add_theme_color_override("font_color", base)
	b.add_theme_color_override("font_hover_color", pal("gold_hi") if on else pal("wood_accent"))
	b.add_theme_color_override("font_pressed_color", pal("gold_hi"))
	b.add_theme_color_override("font_focus_color", pal("gold_hi") if on else pal("wood_accent"))
	b.add_theme_color_override("font_disabled_color", pal("wood_dim"))
	b.set_meta("skin_done", true)
	b.set_meta("skin_screen_done", true)


## Marks a button of a full-screen screen as chosen (crimson, gold text) or not. Does nothing where the screens are not skinned.
static func mark_on(b: Button, on: bool) -> void:
	if not screen_active(b):
		return
	b.set_meta("skin_on", on)
	dress_screen_button(b)


## A text box of a full-screen screen: light parchment, ink text.
static func dress_field(e: LineEdit) -> void:
	for st in ["normal", "focus", "read_only"]:
		e.add_theme_stylebox_override(st, field_box())
	e.add_theme_color_override("font_color", pal("ink"))
	e.add_theme_color_override("font_placeholder_color", pal("ink_dim"))
	e.add_theme_color_override("caret_color", pal("ink"))
	e.add_theme_color_override("selection_color", pal("gold"))
	e.add_theme_color_override("font_selected_color", pal("ink"))
	e.add_theme_color_override("font_uneditable_color", pal("ink_dim"))
	e.set_meta("skin_screen_done", true)


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
	if (d["pieces"] as Dictionary).has("stud"):   # a piece later screens add: checked when it is there
		var bp: Variant = d["pieces"]["stud"]
		var bb: Variant = bp.get("base") if typeof(bp) == TYPE_DICTIONARY else null
		if typeof(bb) != TYPE_ARRAY or (bb as Array).size() != 2 or float(bp.get("margin", 0)) * 2.0 + 1.0 > minf(float(bb[0]), float(bb[1])) or typeof(bp.get("content")) != TYPE_ARRAY:
			bad.append("skin.json: pieces.stud needs a base [w, h], a margin that leaves a middle, and a content [x, y]")
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
	bad.append_array(_validate_screens(d))
	return bad


## What is wrong with the full-screen screens' part of the data ("screens").
static func _validate_screens(d: Dictionary) -> Array:
	var bad: Array = []
	var s: Variant = d.get("screens")
	if typeof(s) != TYPE_DICTIONARY:
		return ["skin.json: screens is missing"]
	for name in ["plank", "field", "focus"]:
		var pc: Variant = (s as Dictionary).get(name)
		var b: Variant = pc.get("base") if typeof(pc) == TYPE_DICTIONARY else null
		if typeof(b) != TYPE_ARRAY or (b as Array).size() != 2 or float(b[0]) != floorf(float(b[0])) or float(b[1]) != floorf(float(b[1])):
			bad.append("skin.json: screens.%s.base must be [width, height] in whole pixels" % name)
		elif float(pc.get("margin", 0)) * 2.0 + 1.0 > minf(float(b[0]), float(b[1])):
			bad.append("skin.json: screens.%s.margin leaves no middle in its base" % name)
	var sky: Variant = s.get("sky")
	if typeof(sky) != TYPE_DICTIONARY:
		bad.append("skin.json: screens.sky is missing")
		return bad
	for k in ["bands", "stars", "hill_tile", "hill_height"]:
		if float(sky.get(k, 0)) < 1.0 or float(sky.get(k, 0)) != floorf(float(sky.get(k, 0))):
			bad.append("skin.json: screens.sky.%s must be a whole number, at least 1" % k)
	if typeof(sky.get("tile")) != TYPE_ARRAY or (sky["tile"] as Array).size() != 2 or float(sky["tile"][0]) < 8 or float(sky["tile"][1]) < 8:
		bad.append("skin.json: screens.sky.tile must be [width, height], at least 8 by 8")
	var night_colours := ["top", "bottom", "star", "star_dim", "hill", "hill_hi", "well"]
	var nights: Variant = s.get("night", {})
	for vn in d["variants"]:
		var nv: Variant = (nights as Dictionary).get(vn) if typeof(nights) == TYPE_DICTIONARY else null
		if typeof(nv) != TYPE_DICTIONARY:
			bad.append("skin.json: screens.night.%s is missing" % vn)
			continue
		for k in night_colours:
			if not _color_ok(nv.get(k)):
				bad.append("skin.json: screens.night.%s.%s is missing or not a colour" % [vn, k])
	if not bad.is_empty():
		return bad
	for pair in s.get("contrast", []):
		for vn in d["variants"]:
			var v: Dictionary = d["variants"][vn]
			var nv2: Dictionary = s["night"][vn]
			if not v.has(str(pair.get("fg", ""))) or not nv2.has(str(pair.get("night", ""))):
				bad.append("skin.json: screens contrast pair %s on night %s names a colour %s lacks" % [pair.get("fg"), pair.get("night"), vn])
				continue
			var need := float(pair["min_hc"] if vn == "high_contrast" else pair["min"])
			var got := contrast(Color(str(v[str(pair["fg"])])), Color(str(nv2[str(pair["night"])])))
			if got < need:
				bad.append("skin.json: %s on night %s (%s) is %.1f to 1 in %s, needs %.1f" % [pair["fg"], pair["night"], pair.get("why", ""), got, vn, need])
	for pair in s.get("pairs", []):
		for vn in d["variants"]:
			var v2: Dictionary = d["variants"][vn]
			if not v2.has(str(pair.get("fg", ""))) or not v2.has(str(pair.get("bg", ""))):
				bad.append("skin.json: screens pair %s on %s names a colour %s lacks" % [pair.get("fg"), pair.get("bg"), vn])
				continue
			var need2 := float(pair["min_hc"] if vn == "high_contrast" else pair["min"])
			var got2 := contrast(Color(str(v2[str(pair["fg"])])), Color(str(v2[str(pair["bg"])])))
			if got2 < need2:
				bad.append("skin.json: %s on %s (%s) is %.1f to 1 in %s, needs %.1f" % [pair["fg"], pair["bg"], pair.get("why", ""), got2, vn, need2])
	return bad
