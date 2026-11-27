## What the open world's time of day and weather draw, over the map (rendering only: GameNightLife and GameWeatherFx say what is there
## and what the weather does; nothing here changes the world or is random). The night's glowcaps (small pale caps with a soft halo
## in the additive layer), the day's market stall (an awning and its trader), the footprints in snow, and the fog's veil: past the
## heir's sight (`GameWeatherFx.view_radius`) the world fades into the fog's grey. With reduced motion the glow does not pulse.
class_name SkyLife
extends RefCounted

const SpriteArt := preload("res://ui/play/sprite_art.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")

static var _veil: Dictionary = {}   # the veil's radial texture, by its look
static var _frame := -1
static var _frame_view := Rect2i()
static var _frame_tiles: Array = []


static func _glow_color() -> Color:
	var c: Array = GameNightLife.setting("glow_color")
	return Color(float(c[0]), float(c[1]), float(c[2]))


static func _to_screen(p: Vector2, origin: Vector2, area: Vector2, centre: Vector2, cell: float) -> Vector2:
	return origin + (p - centre) * cell + area * 0.5


## The glowcaps in view this frame, worked out once a frame however many layers ask.
static func glow_tiles(d: GameDynasty, view: Rect2i) -> Array:
	var f := Engine.get_process_frames()
	if f != _frame or view != _frame_view:
		_frame = f
		_frame_view = view
		_frame_tiles = GameNightLife.glow_in(d, view)
	return _frame_tiles


# ---------------------------------------------------------------- glowcaps

## A glowcap on its tile: a stem and two pale caps (drawn with the standing things, so a figure in front covers it).
static func paint_glowcap(c: Control, g: Dictionary, origin: Vector2, area: Vector2, centre: Vector2, cell: float) -> void:
	var col := _glow_color()
	var p := _to_screen(Vector2(float(g["x"]) + 0.5, float(g["z"]) + 0.6), origin, area, centre, cell)
	var s := cell * 0.16
	c.draw_line(p, p - Vector2(0, s * 1.4), Color(0.75, 0.9, 0.85), maxf(1.0, s * 0.35))
	c.draw_circle(p - Vector2(0, s * 1.6), s * 0.95, Color(col.r, col.g, col.b, 0.95))
	c.draw_circle(p + Vector2(cell * 0.18, s * 0.2), s * 0.6, Color(col.r * 0.9, col.g * 0.95, col.b, 0.9))
	c.draw_circle(p + Vector2(-cell * 0.2, s * 0.3), s * 0.5, Color(col.r * 0.9, col.g * 0.95, col.b, 0.85))


## The soft halo of every glowcap in view, drawn in the additive layer: it breathes slowly (still with reduced motion).
static func paint_glow_halos(c: Control, d: GameDynasty, view: Rect2i, origin: Vector2, area: Vector2, centre: Vector2, cell: float) -> void:
	var tiles := glow_tiles(d, view)
	if tiles.is_empty():
		return
	var col := _glow_color()
	var cap := float(GameNightLife.setting("glow_cap"))
	var t := 0.0 if UiSettings.reduced_motion() else float(Time.get_ticks_msec()) / 1000.0
	for g in tiles:
		var phase := float(absi(hash([int(g["x"]), int(g["z"])])) % 628) / 100.0
		var pulse := 0.8 + 0.2 * sin(t * 1.6 + phase)
		var p := _to_screen(Vector2(float(g["x"]) + 0.5, float(g["z"]) + 0.5), origin, area, centre, cell)
		c.draw_circle(p, cell * 0.85, Color(col.r, col.g, col.b, cap * 0.18 * pulse))
		c.draw_circle(p, cell * 0.45, Color(col.r, col.g, col.b, cap * 0.3 * pulse))


# ---------------------------------------------------------------- the market stall

## A stall of the day's market: an awning in stripes over a counter, with its trader standing behind.
static func paint_stall(c: Control, s: Dictionary, origin: Vector2, area: Vector2, centre: Vector2, cell: float, dim: Color) -> void:
	var p := _to_screen(Vector2(float(s["x"]) + 0.5, float(s["z"]) + 0.5), origin, area, centre, cell)
	var w := cell * 1.5
	var top := p + Vector2(-w * 0.5, -cell * 1.25)
	var stripes := 5
	for i in stripes:
		var col := Color(0.82, 0.25, 0.22) if i % 2 == 0 else Color(0.94, 0.9, 0.82)
		c.draw_rect(Rect2(top + Vector2(w / stripes * i, 0), Vector2(w / stripes + 0.5, cell * 0.38)), col * dim)
	c.draw_rect(Rect2(top + Vector2(w * 0.04, cell * 0.38), Vector2(cell * 0.07, cell * 0.8)), Color(0.4, 0.28, 0.16) * dim)
	c.draw_rect(Rect2(top + Vector2(w * 0.96 - cell * 0.07, cell * 0.38), Vector2(cell * 0.07, cell * 0.8)), Color(0.4, 0.28, 0.16) * dim)
	var tex: Texture2D = SpriteArt.hero("human", "rogue", Color(0.8, 0.55, 0.2))
	if tex != null:
		var h := cell * 1.0
		var bw := h * float(tex.get_width()) / float(tex.get_height())
		c.draw_texture_rect(tex, Rect2(p + Vector2(-bw * 0.5, -h * 0.95), Vector2(bw, h)), false, dim)
	c.draw_rect(Rect2(p + Vector2(-w * 0.45, -cell * 0.1), Vector2(w * 0.9, cell * 0.45)), Color(0.55, 0.38, 0.2) * dim)   # the counter, in front of the trader
	c.draw_circle(p + Vector2(-w * 0.2, -cell * 0.14), cell * 0.1, Color(0.85, 0.3, 0.25) * dim)
	c.draw_circle(p + Vector2(w * 0.05, -cell * 0.14), cell * 0.1, Color(0.9, 0.75, 0.25) * dim)
	c.draw_circle(p + Vector2(w * 0.25, -cell * 0.14), cell * 0.1, Color(0.4, 0.7, 0.3) * dim)


# ---------------------------------------------------------------- footprints

## The heir's footprints in snow: a pair of small dark marks on each tile crossed, fading over `print_seconds` of the world clock.
static func paint_prints(c: Control, d: GameDynasty, prints: Array, origin: Vector2, area: Vector2, centre: Vector2, cell: float) -> void:
	var life := GameWeatherFx.setting("print_seconds")
	for pr in prints:
		var age := d.world_seconds - float(pr["at"])
		if age < 0.0 or age >= life:
			continue
		var a := 0.32 * (1.0 - age / life)
		var p := _to_screen(Vector2(float(pr["x"]) + 0.5, float(pr["z"]) + 0.62), origin, area, centre, cell)
		c.draw_set_transform(p, 0.0, Vector2(1.0, 0.55))
		c.draw_circle(Vector2(-cell * 0.12, 0), cell * 0.07, Color(0.25, 0.3, 0.4, a))
		c.draw_circle(Vector2(cell * 0.12, cell * 0.06), cell * 0.07, Color(0.25, 0.3, 0.4, a))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- the fog's veil

static func _veil_texture(alpha: float, soft: float) -> Texture2D:
	var key := "%s|%s" % [alpha, soft]
	if not _veil.has(key):
		var fc: Array = WorldLook.data()["weather"]["fog_color"]
		var col := Color(float(fc[0]), float(fc[1]), float(fc[2]))
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 1.0 - soft, 1.0])
		g.colors = PackedColorArray([Color(col.r, col.g, col.b, 0.0), Color(col.r, col.g, col.b, 0.0), Color(col.r, col.g, col.b, alpha)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 256
		t.height = 256
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_veil[key] = t
	return _veil[key]


## The veil of fog past the heir's sight over `rect` (the map's area), the heir at `heir_px` on the screen. Nothing in clear weather.
static func paint_veil(c: Control, d: GameDynasty, rect: Rect2, heir_px: Vector2, cell: float) -> void:
	var tiles := GameWeatherFx.view_radius(d)
	if tiles < 0.0:
		return
	var r := tiles * cell
	var fc: Array = WorldLook.data()["weather"]["fog_color"]
	var alpha := GameWeatherFx.setting("veil_alpha")
	var square := Rect2(heir_px - Vector2(r, r), Vector2(r, r) * 2.0)
	var clipped := square.intersection(rect)
	if clipped.has_area():
		var tex := _veil_texture(alpha, GameWeatherFx.setting("veil_soft"))
		var k := Vector2(tex.get_width(), tex.get_height()) / square.size
		c.draw_texture_rect_region(tex, clipped, Rect2((clipped.position - square.position) * k, clipped.size * k))
	var solid := Color(float(fc[0]), float(fc[1]), float(fc[2]), alpha)
	for edge in [Rect2(rect.position, Vector2(rect.size.x, maxf(0.0, square.position.y - rect.position.y))),
			Rect2(Vector2(rect.position.x, square.end.y), Vector2(rect.size.x, maxf(0.0, rect.end.y - square.end.y))),
			Rect2(Vector2(rect.position.x, square.position.y), Vector2(maxf(0.0, square.position.x - rect.position.x), square.size.y)),
			Rect2(Vector2(square.end.x, square.position.y), Vector2(maxf(0.0, rect.end.x - square.end.x), square.size.y))]:
		var e: Rect2 = (edge as Rect2).intersection(rect)
		if e.has_area():
			c.draw_rect(e, solid)
