## The open world's camera state (runtime only, never saved but for the zoom, which lives in settings.cfg): where the view
## is centred, how fast it is moving, the look-ahead, the player's own look offset (the numpad), and the eased zoom. The
## arithmetic is GameCamera's (core, tested without a screen); the numbers are the `camera` block of data/world/sandbox.json.
## sandbox_screen.gd calls `update` once a frame and draws and hit-tests from `centre`.
extends RefCounted

const UiSettings := preload("res://ui/play/ui_settings.gd")
const WorldInput := preload("res://ui/play/world_input.gd")
const ZOOM_KEY := "world_zoom"

var pos := Vector2.ZERO        # the follow's position, in tiles (a tile's top-left is its whole number)
var vel := Vector2.ZERO
var ahead := Vector2.ZERO      # the look-ahead now (eased)
var look := Vector2.ZERO       # where the player has asked to look from the heir (numpad), as set
var look_shown := Vector2.ZERO # the same, eased
var centre := Vector2.ZERO     # what is drawn: pos + ahead + look, held inside the world and on the pixel grid
var started := false
var space_key := ""
var walk_left := 0.0           # seconds the look-ahead still holds after the heir's last step
var zoom_goal := -1.0          # the zoom being eased to; -1 when none is
var stored_zoom := -1.0        # the zoom last written to settings.cfg
var snapped_last := false      # the last update put the view on the heir instead of sliding (a test and the screen read it)
var _bounds_key := ""
var _bounds := Rect2()


## The point of the heir the camera follows: the middle of their tile.
static func target_of(heir: Vector2i) -> Vector2:
	return Vector2(heir) + Vector2(0.5, 0.5)


## Puts the view on `target` at once: no glide, no look-ahead, no look offset.
func snap_to(target: Vector2) -> void:
	pos = target
	vel = Vector2.ZERO
	ahead = Vector2.ZERO
	started = true
	walk_left = 0.0


## One frame. `target` is where the heir is (target_of), `key` names the space (the open world or an interior's id), so a
## change of space puts the view on them; `half` is half the view in tiles, `bounds` the tiles of the space and `cell`/`area`
## the pixel size of a tile and of the map area. Returns the centre to draw from.
func update(dt: float, target: Vector2, facing: Vector2i, stepped: bool, key: String, half: Vector2, bounds: Rect2, cell: float, area: Vector2) -> Vector2:
	var c: Dictionary = GameCamera.data()
	dt = minf(dt, float(c["max_dt"]))
	snapped_last = false
	if not started or key != space_key:
		snap_to(target)
		look = Vector2.ZERO
		look_shown = Vector2.ZERO
		space_key = key
		snapped_last = true
	else:
		if stepped:
			walk_left = float(c["walk_hold_seconds"])
		else:
			walk_left = maxf(0.0, walk_left - dt)
		var r := GameCamera.follow(pos, vel, target, dt, WorldInput.camera_follow_seconds(), float(c["dead_zone"]), float(c["snap_tiles"]))
		pos = r["pos"]
		vel = r["vel"]
		if bool(r["snapped"]):
			ahead = Vector2.ZERO
			look_shown = look
			snapped_last = true
	var glide := UiSettings.motion_time(float(c["look_ahead_seconds"]))
	var goal := GameCamera.ahead_goal(facing, walk_left > 0.0, float(c["look_ahead"]))
	ahead = GameCamera.ease_vec(ahead, goal if glide > 0.0 else Vector2.ZERO, dt, glide)   # locked to the heir with reduced motion: no look-ahead either
	look_shown = GameCamera.ease_vec(look_shown, look, dt, glide)
	var margin := float(c["edge_margin"]) if key == "world" else float(c["interior_margin"])
	var want := GameCamera.clamp_centre(pos + ahead + look_shown, half, bounds, margin)
	centre = GameCamera.snap_to_pixels(want, cell, area)
	return centre


## The bounds of a space in tiles (cached by its key): the world's square, or the box round an interior's cells.
func bounds_for(key: String, cells: Dictionary) -> Rect2:
	if key == _bounds_key:
		return _bounds
	_bounds_key = key
	if key == "world":
		var n := float(GameWorldGen.size())
		_bounds = Rect2(0, 0, n, n)
		return _bounds
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for k in cells:
		var t := Vector2(GameInterior._parse(k))
		lo = Vector2(minf(lo.x, t.x), minf(lo.y, t.y))
		hi = Vector2(maxf(hi.x, t.x + 1.0), maxf(hi.y, t.y + 1.0))
	_bounds = Rect2(lo, hi - lo) if lo.x < INF else Rect2(0, 0, 1, 1)
	return _bounds


# ---------------------------------------------------------------- zoom

## Asks for `steps` clicks of zoom from the zoom being eased to (or the current one).
func zoom_by(zoom: float, steps: int) -> void:
	zoom_goal = WorldInput.zoom_after(zoom_goal if zoom_goal > 0.0 else zoom, steps)


## The zoom after a frame of easing toward the goal (the current one when there is none).
func zoom_step(zoom: float, dt: float) -> float:
	if zoom_goal <= 0.0:
		return zoom
	var z := GameCamera.ease_float(zoom, zoom_goal, minf(dt, float(GameCamera.setting("max_dt"))), UiSettings.motion_time(GameCamera.setting("zoom_seconds")))
	if is_equal_approx(z, zoom_goal):
		z = zoom_goal
		zoom_goal = -1.0
	return z


## The zoom kept in settings.cfg, held between the limits; `fallback` when there is none or the value is not a number.
static func saved_zoom(fallback: float) -> float:
	var v: Variant = UiSettings.stored(ZOOM_KEY, null)
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		return fallback
	var z := float(v)
	if is_nan(z) or is_inf(z):
		return fallback
	return clampf(z, WorldInput.setting("zoom_min"), WorldInput.setting("zoom_max"))


## Writes the zoom to settings.cfg once it has settled (not while it eases or a pinch is on), and only when it changed.
func remember_zoom(zoom: float, settled: bool) -> void:
	if not settled or zoom_goal > 0.0 or is_equal_approx(zoom, stored_zoom):
		return
	stored_zoom = zoom
	UiSettings.store(ZOOM_KEY, snappedf(zoom, 0.001))
