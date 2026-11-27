## What lies on the open world's ground after a fight (GameDrops), drawn as small objects: a coin pile, a chest-like bundle, a gem
## glint or an egg, each in its rarity's colour with the rarity as a word and a mark under it (so colour is never the only cue), a
## soft bob, and for rare and better a light beam. In its last seconds a drop blinks. Look only: the rules are GameDrops and the
## numbers are data/world/drops.json; with reduced motion nothing bobs, pulses or blinks.
extends RefCounted

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const LootPop := preload("res://ui/play/loot_pop.gd")


## The mark and word a drop wears: "* Rare", or "Common".
static func tag_of(p: Dictionary) -> String:
	var inf := LootPop.info(GameDrops.rarity_of(p))
	return str(inf["word"]) if str(inf["mark"]) == "" else "%s %s" % [inf["mark"], inf["word"]]


## The rarity's colour for a drop.
static func color_of(p: Dictionary) -> Color:
	return LootPop.info(GameDrops.rarity_of(p))["color"]


## Draws one drop with its feet at `at` (a screen point), on a tile `cell` pixels wide, tinted by `dim` (the night), at `seconds` of
## the real clock (the bob), with `left` seconds of the world clock before it is gone.
static func paint(c: CanvasItem, p: Dictionary, at: Vector2, cell: float, dim: Color, seconds: float, left: float) -> void:
	var live := UiSettings.motion_time(1.0) > 0.0
	var fade := float(GameDrops.setting("fade_seconds"))
	if left < fade and live and int(seconds * 4.0) % 2 == 0:
		dim = Color(dim.r, dim.g, dim.b, 0.45)   # about to go: it blinks
	var col := color_of(p)
	var hz := float(GameDrops.setting("bob_hz"))
	var bob := sin((seconds * hz + float(int(p["uid"]) % 7) * 0.37) * TAU) * float(GameDrops.setting("bob_tiles")) * cell if live else 0.0
	var rest := at + Vector2(0, cell * 0.15)
	_shadow(c, rest, cell * 0.28)
	var up := rest + Vector2(0, bob - cell * 0.12)
	if GameDrops.beams(p):
		_beam(c, rest, cell, col, seconds, live)
	match GameDrops.shape_of(p):
		"coins":
			_coins(c, up, cell, dim)
		"gem":
			_gem(c, up, cell, col, dim, seconds, live)
		"egg":
			_egg(c, up, cell, col, dim)
		_:
			_bundle(c, up, cell, col, dim)
	if cell >= float(GameDrops.setting("label_min_cell")):
		_label(c, tag_of(p), rest + Vector2(0, cell * 0.28), col, dim.a)


static func _shadow(c: CanvasItem, at: Vector2, r: float) -> void:
	c.draw_set_transform(at, 0.0, Vector2(1.0, 0.4))
	c.draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.3))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A column of light over the drop that fades as it rises (a pulse with motion on).
static func _beam(c: CanvasItem, base: Vector2, cell: float, col: Color, seconds: float, live: bool) -> void:
	var h := float(GameDrops.setting("beam_tiles")) * cell
	var w := cell * 0.22
	var a := 0.5 + (0.18 * sin(seconds * 2.4) if live else 0.0)
	var pts := PackedVector2Array([base + Vector2(-w, 0), base + Vector2(w, 0), base + Vector2(w * 0.4, -h), base + Vector2(-w * 0.4, -h)])
	var cols := PackedColorArray([Color(col, a), Color(col, a), Color(col, 0.0), Color(col, 0.0)])
	c.draw_polygon(pts, cols)


static func _coins(c: CanvasItem, at: Vector2, cell: float, dim: Color) -> void:
	var gold := Color("#e8c14a") * dim
	var edge := Color("#7a5a14") * dim
	for i in 3:
		var o := Vector2([-0.14, 0.12, -0.02][i], [0.04, 0.06, -0.08][i]) * cell
		c.draw_set_transform(at + o, 0.0, Vector2(1.0, 0.55))
		c.draw_circle(Vector2.ZERO, cell * 0.17, edge)
		c.draw_circle(Vector2(0, -cell * 0.02), cell * 0.14, gold)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A chest-like bundle: a wooden box with a lid line and a clasp in the rarity's colour.
static func _bundle(c: CanvasItem, at: Vector2, cell: float, col: Color, dim: Color) -> void:
	var w := cell * 0.5
	var h := cell * 0.34
	var box := Rect2(at + Vector2(-w * 0.5, -h), Vector2(w, h))
	c.draw_rect(box, Color("#7b5330") * dim)
	c.draw_rect(Rect2(box.position, Vector2(w, h * 0.38)), Color("#9a6b3f") * dim)
	c.draw_rect(box, Color("#2c1c0e") * dim, false, maxf(1.0, cell * 0.05))
	c.draw_line(box.position + Vector2(0, h * 0.38), box.position + Vector2(w, h * 0.38), Color("#2c1c0e") * dim, maxf(1.0, cell * 0.04))
	c.draw_rect(Rect2(at + Vector2(-cell * 0.05, -h * 0.62), Vector2(cell * 0.1, h * 0.36)), col * dim)


## A gem: a diamond in the rarity's colour with a glint that turns.
static func _gem(c: CanvasItem, at: Vector2, cell: float, col: Color, dim: Color, seconds: float, live: bool) -> void:
	var r := cell * 0.22
	var mid := at + Vector2(0, -r * 1.1)
	var pts := PackedVector2Array([mid + Vector2(0, -r), mid + Vector2(r * 0.8, 0), mid + Vector2(0, r), mid + Vector2(-r * 0.8, 0)])
	c.draw_colored_polygon(pts, col * dim)
	c.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0, 0, 0, 0.6), maxf(1.0, cell * 0.04))
	c.draw_line(pts[3], pts[1], Color(1, 1, 1, 0.5), 1.0)
	var g := 0.5 + (0.5 * sin(seconds * 3.0) if live else 0.5)
	var s := cell * 0.12 * g
	c.draw_line(mid + Vector2(-s, -r * 0.4 - s), mid + Vector2(s, -r * 0.4 + s), Color(1, 1, 1, 0.8), 1.5)
	c.draw_line(mid + Vector2(s, -r * 0.4 - s), mid + Vector2(-s, -r * 0.4 + s), Color(1, 1, 1, 0.8), 1.5)


static func _egg(c: CanvasItem, at: Vector2, cell: float, col: Color, dim: Color) -> void:
	c.draw_set_transform(at + Vector2(0, -cell * 0.2), 0.0, Vector2(0.78, 1.0))
	c.draw_circle(Vector2.ZERO, cell * 0.2, Color("#efe6cf") * dim)
	c.draw_arc(Vector2.ZERO, cell * 0.2, 0.0, TAU, 20, col * dim, maxf(1.5, cell * 0.06))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.draw_circle(at + Vector2(-cell * 0.05, -cell * 0.26), cell * 0.03, col * dim)
	c.draw_circle(at + Vector2(cell * 0.06, -cell * 0.17), cell * 0.025, col * dim)


static func _label(c: CanvasItem, word: String, at: Vector2, col: Color, alpha: float) -> void:
	var font := ThemeDB.fallback_font
	var size := 12
	var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := at + Vector2(-w * 0.5, 0)
	c.draw_string_outline(font, pos, word, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0, 0, 0, 0.85 * alpha))
	c.draw_string(font, pos, word, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col, alpha))
