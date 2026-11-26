## The open world's camera, as arithmetic only (no nodes, no dice, nothing saved): where the view's centre goes
## each frame, from where it is, how fast it moves and where the heir is. ui/play/world_camera.gd keeps the state and
## ui/play/sandbox_screen.gd draws from it. The numbers are the `camera` block of data/world/sandbox.json (and
## input.json's camera_follow_seconds and zoom limits); every function takes them as arguments so a test can try any.
## Positions are in tiles, the way the view's centre is (a tile's top-left corner is its whole number).
class_name GameCamera
extends RefCounted


static func data() -> Dictionary:
	return GameSandbox.data()["camera"]


static func setting(key: String) -> float:
	return float(data()[key])


## One step of a critically damped spring (the follow that never overshoots): from `pos` with velocity `vel` toward
## `target`, taking about `smooth_time` seconds to arrive. Returns [new position, new velocity]. A smooth time of 0 (reduced
## motion) puts the camera on the target at once. Stable for any `dt`.
static func smooth_damp(pos: Vector2, vel: Vector2, target: Vector2, smooth_time: float, dt: float) -> Array:
	if smooth_time <= 0.0001:
		return [target, Vector2.ZERO]
	if dt <= 0.0:
		return [pos, vel]
	var omega := 2.0 / smooth_time
	var x := omega * dt
	var decay := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := pos - target
	var temp := (vel + omega * change) * dt
	var new_vel := (vel - omega * temp) * decay
	var new_pos := target + (change + temp) * decay
	if (target - pos).dot(new_pos - target) > 0.0:   # it would pass the target: stop on it
		new_pos = target
		new_vel = Vector2.ZERO
	return [new_pos, new_vel]


## The point the camera aims at when the heir is at `target`: the heir's own position unless it is within `dead` tiles of
## where the camera already is, in which case the camera stays (a small dead zone, so a step to and fro does not shake the
## view). Farther off, the aim is `dead` short of the heir.
static func dead_aim(pos: Vector2, target: Vector2, dead: float) -> Vector2:
	var off := target - pos
	var len := off.length()
	if len <= dead:
		return pos
	return target - off / len * dead


## One frame of the follow: {pos, vel, snapped}. A heir farther than `snap_tiles` away (a trip through a gate, a coach) is
## not slid to: the camera is put on them.
static func follow(pos: Vector2, vel: Vector2, target: Vector2, dt: float, smooth_time: float, dead: float, snap_tiles: float) -> Dictionary:
	if (target - pos).length() > snap_tiles:
		return {"pos": target, "vel": Vector2.ZERO, "snapped": true}
	if smooth_time <= 0.0001:
		return {"pos": target, "vel": Vector2.ZERO, "snapped": false}   # reduced motion: locked to the heir, no dead zone either
	var r := smooth_damp(pos, vel, dead_aim(pos, target, dead), smooth_time, dt)
	return {"pos": r[0], "vel": r[1], "snapped": false}


## A float eased toward its goal with a time constant of `seconds` (the zoom). Zero seconds: the goal.
static func ease_float(cur: float, goal: float, dt: float, seconds: float) -> float:
	if seconds <= 0.0001:
		return goal
	var f := lerpf(cur, goal, 1.0 - exp(-maxf(dt, 0.0) / seconds))
	return goal if absf(f - goal) < 0.002 else f


## A point eased toward its goal the same way (the look-ahead).
static func ease_vec(cur: Vector2, goal: Vector2, dt: float, seconds: float) -> Vector2:
	if seconds <= 0.0001:
		return goal
	var v := cur.lerp(goal, 1.0 - exp(-maxf(dt, 0.0) / seconds))
	return goal if v.distance_to(goal) < 0.002 else v


## The look-ahead's goal: `tiles` along the way the heir faces while they walk, nothing while they stand.
static func ahead_goal(facing: Vector2i, walking: bool, tiles: float) -> Vector2:
	if not walking or facing == Vector2i.ZERO:
		return Vector2.ZERO
	return Vector2(facing).normalized() * tiles


## `centre` held so the view (`half` tiles each way from it) never shows more than `margin` tiles beyond `bounds` (the
## world's tiles, or an interior's). A view larger than the bounds plus margins sits on the middle of them.
static func clamp_centre(centre: Vector2, half: Vector2, bounds: Rect2, margin: float) -> Vector2:
	var out := centre
	for axis in 2:
		var lo: float = bounds.position[axis] - margin + half[axis]
		var hi: float = bounds.end[axis] + margin - half[axis]
		out[axis] = (bounds.position[axis] + bounds.end[axis]) * 0.5 if lo > hi else clampf(centre[axis], lo, hi)
	return out


## `centre` moved so the tiles land on whole pixels of the screen at this cell size (the area's middle is where the centre is
## drawn), so nearest-neighbour tiles never straddle a pixel and a still view does not shimmer.
static func snap_to_pixels(centre: Vector2, cell: float, area: Vector2 = Vector2.ZERO) -> Vector2:
	if cell <= 0.0:
		return centre
	var phase := area * 0.5
	return (Vector2(roundf(centre.x * cell - phase.x), roundf(centre.y * cell - phase.y)) + phase) / cell


## The tile under a point of an area (its top-left at 0,0) for a view centred on `centre` at this cell size.
static func tile_under(p: Vector2, area: Vector2, centre: Vector2, cell: float) -> Vector2i:
	var t := (p - area * 0.5) / cell + centre
	return Vector2i(floori(t.x), floori(t.y))


static func validate() -> Array:
	var bad: Array = []
	if not GameSandbox.data().has("camera"):
		return ["sandbox.json: the camera block is missing"]
	var c: Dictionary = data()
	for k in ["dead_zone", "look_ahead", "look_ahead_seconds", "walk_hold_seconds", "snap_tiles", "zoom_seconds", "edge_margin", "interior_margin", "max_dt"]:
		if not c.has(k) or typeof(c[k]) not in [TYPE_FLOAT, TYPE_INT]:
			bad.append("sandbox.json: camera.%s is missing or not a number" % k)
	if not bad.is_empty():
		return bad
	for k in ["dead_zone", "look_ahead", "look_ahead_seconds", "walk_hold_seconds", "zoom_seconds", "edge_margin", "interior_margin"]:
		if float(c[k]) < 0.0:
			bad.append("sandbox.json: camera.%s must be 0 or more" % k)
	if float(c["dead_zone"]) >= 2.0:
		bad.append("sandbox.json: camera.dead_zone must be under 2 tiles")
	if float(c["look_ahead"]) > 6.0:
		bad.append("sandbox.json: camera.look_ahead must be at most 6 tiles")
	if float(c["snap_tiles"]) < 2.0:
		bad.append("sandbox.json: camera.snap_tiles must be at least 2 (a step of a walk is never a jump)")
	if float(c["max_dt"]) <= 0.0 or float(c["max_dt"]) > 0.5:
		bad.append("sandbox.json: camera.max_dt must be above 0 and at most 0.5")
	return bad
