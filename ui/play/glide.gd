## The look of walking in the open world: what is drawn glides between tiles instead of snapping to them. A thing
## the game moves a tile (or a fraction of one) at a time, such as the heir, a creature, a companion or a villager,
## has a drawn position that eases toward its real one (a smooth-damp: it starts gently, runs and slows to rest, so
## a walk has acceleration and deceleration), a small bob in time with its stride, and a footstep each time a
## stride is done (a signal, with the kind of thing and where it stands; the sound is wired by whoever listens).
## The numbers are in data/world/sandbox.json under "feel" (`validate`, called by tools/check_data.gd).
## Rendering only: the position the game holds is never changed, nothing here is saved, and no dice are drawn
## (the dynasty's or any other). With reduced motion the drawn position is the real one and nothing bobs, but a
## footstep is still told, so the sound is not lost.
extends RefCounted

const UiSettings := preload("res://ui/play/ui_settings.gd")

## A thing took a step: `key` is how the screen names it, `kind` is "heir", "companion", "creature", "villager" or
## "person", `foot` alternates 0 and 1, `tile` is where it stands, `speed` its pace in tiles a second and `near`
## its distance from the heir in tiles (the sound is quieter the further off).
signal footstep(key: String, kind: String, foot: int, tile: Vector2i, speed: float, near: float)

static var _data: Dictionary = {}
static var _loaded := false

var _st: Dictionary = {}     # key -> {pos, vel, target, frame, stride, foot, speed, lift}
var _frame := 0
var _dt := 0.0
var _heir := Vector2.ZERO    # where the heir is drawn (for the hearing range of a footstep)
var _heir_known := false


static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		var v: Variant = GameSandbox.data().get("feel", {})
		_data = v if typeof(v) == TYPE_DICTIONARY else {}
	return _data


static func reset_data() -> void:
	_loaded = false
	_data = {}


static func setting(key: String) -> float:
	return float(data().get(key, 0.0))


## How much faster than a walk a run is (hold the run key); 1 when the data has no say.
static func run_multiplier() -> float:
	return maxf(1.0, setting("run_multiplier"))


## The seconds between two steps of the heir on foot: the walk's, shortened by a run.
static func step_seconds(running: bool) -> float:
	var base := float(GameSandbox.setting("walk_seconds"))
	return base / run_multiplier() if running else base


## Starts a frame: `dt` seconds have passed. Forgets those not drawn for a while.
func advance(dt: float) -> void:
	_frame += 1
	_dt = maxf(dt, 0.0)
	if _frame % 60 == 0:
		var gone: Array = []
		for k in _st:
			if _frame - int(_st[k]["frame"]) > int(setting("forget_frames")):
				gone.append(k)
		for k in gone:
			_st.erase(k)


## Draws everything where it really is, at once (a new place, a teleport, a loaded game).
func snap_all() -> void:
	for k in _st:
		var s: Dictionary = _st[k]
		s["pos"] = s["target"]
		s["vel"] = Vector2.ZERO
		s["stride"] = 0.0
		s["speed"] = 0.0
		s["lift"] = 0.0
	if _st.has("heir"):
		_heir = _st["heir"]["pos"]


func clear() -> void:
	_st.clear()
	_heir_known = false


## Where `key` is drawn this frame, given where it is (`target`, in tiles). The first call of a frame moves it.
func at(key: String, target: Vector2, kind: String = "creature") -> Vector2:
	var s: Variant = _st.get(key)
	if s == null:
		_st[key] = {"pos": target, "vel": Vector2.ZERO, "target": target, "frame": _frame, "stride": 0.0, "foot": 0, "speed": 0.0, "lift": 0.0}
		if key == "heir":
			_heir = target
			_heir_known = true
		return target
	var st: Dictionary = s
	if int(st["frame"]) == _frame:
		return st["pos"]
	st["frame"] = _frame
	var before: Vector2 = st["pos"]
	var pos := before
	var smooth := UiSettings.motion_time(setting("heir_smooth_seconds") if kind == "heir" else setting("other_smooth_seconds"))
	if target.distance_to(st["target"]) > setting("snap_tiles"):
		pos = target
		st["vel"] = Vector2.ZERO
		st["stride"] = 0.0
		before = target
	elif smooth <= 0.0 or _dt <= 0.0:
		pos = target
		st["vel"] = Vector2.ZERO
	else:
		var out := smooth_damp(before, target, st["vel"], smooth, _dt, setting("max_speed_tiles"))
		pos = out[0]
		st["vel"] = out[1]
		if pos.distance_to(target) < 0.002:
			pos = target
			st["vel"] = Vector2.ZERO
	st["target"] = target
	st["pos"] = pos
	var moved := pos.distance_to(before)
	var speed := moved / _dt if _dt > 0.0 else 0.0
	st["speed"] = speed
	if speed >= setting("bob_min_speed"):
		st["stride"] = float(st["stride"]) + moved
		var step := setting("step_tiles")
		if step > 0.0 and float(st["stride"]) >= step:
			st["stride"] = float(st["stride"]) - step
			st["foot"] = 1 - int(st["foot"])
			if key == "heir":
				_heir = pos
				_heir_known = true
			_step(key, kind, st)
	else:
		st["stride"] = 0.0
	var phase := float(st["stride"]) / maxf(setting("step_tiles"), 0.001)
	var pace := clampf(speed / maxf(setting("bob_full_speed"), 0.001), 0.0, 1.0) if speed >= setting("bob_min_speed") else 0.0
	st["lift"] = 0.0 if UiSettings.reduced_motion() else sin(phase * PI) * setting("bob_tiles") * pace
	if key == "heir":
		_heir = pos
		_heir_known = true
	return pos


## Tells of a footstep when the thing is near enough to the heir to be heard.
func _step(key: String, kind: String, st: Dictionary) -> void:
	var pos: Vector2 = st["pos"]
	var near := pos.distance_to(_heir) if _heir_known else 0.0
	if key != "heir" and near > setting("hear_tiles"):
		return
	footstep.emit(key, kind, int(st["foot"]), Vector2i(floori(pos.x), floori(pos.y)), float(st["speed"]), near)


## How far `key` is lifted off the ground this frame by its stride, in tiles (0 standing still or with reduced motion).
func lift(key: String) -> float:
	var s: Variant = _st.get(key)
	return float((s as Dictionary)["lift"]) if s != null else 0.0


## The pace `key` has this frame, in tiles a second.
func speed(key: String) -> float:
	var s: Variant = _st.get(key)
	return float((s as Dictionary)["speed"]) if s != null else 0.0


## How far the drawn position is from the real one now.
func lag(key: String) -> float:
	var s: Variant = _st.get(key)
	return (s["pos"] as Vector2).distance_to(s["target"]) if s != null else 0.0


## One step of a critically damped spring toward `target` (the smooth-damp): eases in from rest, runs and eases out to
## rest with no overshoot. Returns [position, velocity]; `max_speed` caps the pace in units a second.
static func smooth_damp(cur: Vector2, target: Vector2, vel: Vector2, smooth_time: float, dt: float, max_speed: float) -> Array:
	var st := maxf(0.0001, smooth_time)
	var omega := 2.0 / st
	var x := omega * dt
	var ex := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := cur - target
	var cap := max_speed * st
	if cap > 0.0 and change.length() > cap:
		change = change.normalized() * cap
	var goal := cur - change
	var temp := (vel + change * omega) * dt
	var nv := (vel - temp * omega) * ex
	var out := goal + (change + temp) * ex
	if (target - cur).dot(out - target) > 0.0:   # it would run past: stop on it
		out = target
		nv = Vector2.ZERO
	return [out, nv]


static func validate() -> Array:
	var bad: Array = []
	var f: Variant = GameSandbox.data().get("feel")
	if typeof(f) != TYPE_DICTIONARY:
		return ["sandbox.json: feel (how walking looks and feels) is missing"]
	for k in ["run_multiplier", "heir_smooth_seconds", "other_smooth_seconds", "max_speed_tiles", "snap_tiles", "step_tiles", "bob_tiles", "bob_full_speed", "bob_min_speed", "hear_tiles", "forget_frames"]:
		if not (f.get(k) is float or f.get(k) is int):
			bad.append("sandbox.json: feel.%s must be a number" % k)
	if not bad.is_empty():
		return bad
	if float(f["run_multiplier"]) < 1.0 or float(f["run_multiplier"]) > 4.0:
		bad.append("sandbox.json: feel.run_multiplier must be from 1 to 4")
	for k in ["heir_smooth_seconds", "other_smooth_seconds"]:
		if float(f[k]) < 0.0 or float(f[k]) > 1.0:
			bad.append("sandbox.json: feel.%s must be from 0 to 1 second (0 is no gliding)" % k)
	for k in ["max_speed_tiles", "snap_tiles", "step_tiles", "bob_full_speed", "hear_tiles"]:
		if float(f[k]) <= 0.0:
			bad.append("sandbox.json: feel.%s must be above 0" % k)
	if float(f["bob_tiles"]) < 0.0 or float(f["bob_tiles"]) > 0.3:
		bad.append("sandbox.json: feel.bob_tiles must be from 0 to 0.3 of a tile")
	if float(f["bob_min_speed"]) < 0.0 or int(f["forget_frames"]) < 1:
		bad.append("sandbox.json: feel.bob_min_speed must be 0 or more and forget_frames at least 1")
	var m: Variant = f.get("marker")
	if typeof(m) != TYPE_DICTIONARY:
		bad.append("sandbox.json: feel.marker (the mark where a click walks to) is missing")
	else:
		for k in ["fade_seconds", "cancel_fade_seconds", "pulse_seconds", "radius_tiles", "line_px"]:
			if not (m.get(k) is float or m.get(k) is int) or float(m[k]) <= 0.0:
				bad.append("sandbox.json: feel.marker.%s must be a number above 0" % k)
	return bad
