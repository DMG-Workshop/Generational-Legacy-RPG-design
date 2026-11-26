## The mark where a click (or a tap) on the ground sends the heir: a ring with a dot in it on the tile they are walking
## to. It follows the heir's own route (`update` reads it every frame, so a click, a double click, the thing menu and a
## tap all show it with no word from the caller), fades when they arrive, and fades faster when a key or the stick ends
## the walk. A walk in legs to a pinned town shows nothing: its legs are not a click. Reduced motion: the mark is plain
## (no pulse) and goes at once. The numbers are in sandbox.json under feel.marker. Drawing only; nothing is saved.
extends RefCounted

const UiSettings := preload("res://ui/play/ui_settings.gd")
const Glide := preload("res://ui/play/glide.gd")

var tile := Vector2i.ZERO
var active := false      # a mark is on the ground (shown or fading)
var fading := false
var _age := 0.0          # seconds since it was placed
var _fade := 0.0         # seconds it has been fading
var _fade_for := 0.0     # seconds the fade takes


static func setting(key: String) -> float:
	return float((Glide.data().get("marker", {}) as Dictionary).get(key, 0.0))


## Follows the walk: `route_end` is the last tile of the route (when there is one), `heir` where they stand and `legs`
## whether the walk is one of a journey's legs. Call once a frame with the seconds passed.
func update(route_end: Variant, heir: Vector2i, legs: bool, dt: float) -> void:
	_age += dt
	if route_end != null and not legs:
		if not active or fading or route_end != tile:
			tile = route_end
			active = true
			fading = false
			_age = 0.0
		return
	if not active or fading:
		if fading:
			_fade += dt
			if _fade >= _fade_for:
				clear()
		return
	# the route is gone: they arrived, or something ended the walk
	fading = true
	_fade = 0.0
	_fade_for = UiSettings.motion_time(setting("fade_seconds") if heir == tile else setting("cancel_fade_seconds"))
	if _fade_for <= 0.0:
		clear()


func clear() -> void:
	active = false
	fading = false
	_age = 0.0
	_fade = 0.0


## How solid the mark is, 1 down to 0 as it fades.
func alpha() -> float:
	if not active:
		return 0.0
	if not fading or _fade_for <= 0.0:
		return 1.0
	return clampf(1.0 - _fade / _fade_for, 0.0, 1.0)


## The ring's size now, as a share of its radius: it breathes once every pulse (steady with reduced motion).
func pulse() -> float:
	if UiSettings.reduced_motion() or fading:
		return 1.0
	return 1.0 + 0.12 * sin(_age / setting("pulse_seconds") * TAU)


## Draws it at `p` (the middle of the tile on `c`), `cell` pixels to a tile, in `color`.
func paint(c: Control, p: Vector2, cell: float, color: Color) -> void:
	var a := alpha()
	if a <= 0.0:
		return
	var r := cell * setting("radius_tiles") * pulse()
	var w := maxf(1.5, setting("line_px"))
	c.draw_arc(p, r + 1.0, 0.0, TAU, 24, Color(0, 0, 0, 0.55 * a), w + 2.0)   # a dark edge so it shows on any ground
	c.draw_arc(p, r, 0.0, TAU, 24, Color(color.r, color.g, color.b, a), w)
	c.draw_circle(p, maxf(1.5, r * 0.25), Color(color.r, color.g, color.b, a))
