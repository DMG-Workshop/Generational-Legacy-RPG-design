## How long the battle SCREEN takes (data/ui/battle_ui.json "speed"): a speed of 1x, 2x or 4x that divides every animation and wait
## of the battle screen, and Skip, which shows each round at once, as its result and the log only. Both are the player's, kept in
## user://settings.cfg by UiSettings (never the save). Rendering only: the rules, the dice and the typed events of a fight are
## played by the same code before the screen sees them, so a seeded fight ends with the same result and event list at every speed
## and with Skip on (tests/test_game_battle_speed.gd).
##
##   mult() / skip()      the speed and Skip as they apply NOW: 1 and false unless a battle screen is up (`active`), so the world's
##                        own motion is never sped up by a setting made in a fight
##   time(s)              an animation's seconds: UiSettings.motion_time(s) over the speed (0 with Skip)
##   pause(s)             a wait between things the screen shows: over the speed, shrunk for reduced motion, 0 with Skip
##   fx_scale()           how much of a shake or hit-stop is left at this speed (data: 1, then half, then none)
##   tune(tween)          the tween at the speed; returns it
##   set_speed / cycle    the stored speed, one of the data's steps
extends RefCounted

const PATH := "res://data/ui/battle_ui.json"
const UiSettings := preload("res://ui/play/ui_settings.gd")

static var active := false   # a battle screen is up (it sets and clears this)
static var _data: Dictionary = {}
static var _loaded := false


static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = v if typeof(v) == TYPE_DICTIONARY else {}
	return _data


static func reset() -> void:
	_loaded = false
	_data = {}


static func section(key: String) -> Dictionary:
	var s: Variant = data().get(key, {})
	return s if typeof(s) == TYPE_DICTIONARY else {}


static func speed_data() -> Dictionary:
	return section("speed")


## The words of the controls, with {placeholders} filled.
static func text(key: String, vals: Dictionary = {}) -> String:
	return str((speed_data().get("text", {}) as Dictionary).get(key, key)).format(vals)


static func wait(key: String) -> float:
	return float((speed_data().get("waits", {}) as Dictionary).get(key, 0.0))


static func steps() -> Array:
	var out: Array = []
	for s in speed_data().get("steps", [1]):
		out.append(int(s))
	return out if not out.is_empty() else [1]


## The stored speed, or 1x when it is not one of the data's steps (a hand-edited or damaged file).
static func chosen() -> int:
	var v := UiSettings.battle_speed()
	return v if v in steps() else 1


static func set_speed(n: int) -> void:
	UiSettings.set_battle_speed(n if n in steps() else 1)


## The next speed up, from the top back to the first.
static func cycle() -> int:
	var s := steps()
	var n: int = s[(s.find(chosen()) + 1) % s.size()]
	set_speed(n)
	return n


static func mult() -> float:
	return float(chosen()) if active else 1.0


static func skip() -> bool:
	return active and UiSettings.battle_skip()


static func time(seconds: float) -> float:
	if skip():
		return 0.0
	return UiSettings.motion_time(seconds) / mult()


static func pause(seconds: float) -> float:
	if skip():
		return 0.0
	if UiSettings.reduced_motion():   # skip-friendly: nothing moves, so there is little to wait for
		return seconds * float(speed_data().get("reduced_wait_scale", 1.0)) / mult()
	return seconds / mult()


static func fx_scale() -> float:
	if skip() or not active:
		return 0.0 if skip() else 1.0
	return float((speed_data().get("fx_scale", {}) as Dictionary).get(str(chosen()), 1.0))


static func tune(t: Tween) -> Tween:
	if t != null and mult() != 1.0:
		t.set_speed_scale(mult())
	return t


## The key a control answers to ("skip" or "speed"), as a keycode; KEY_NONE when the data names none.
static func key(which: String) -> int:
	return int(OS.find_keycode_from_string(str((speed_data().get("keys", {}) as Dictionary).get(which, ""))))


static func validate() -> Array:
	var out: Array = []
	var s := speed_data()
	if s.is_empty():
		return ["battle speed: data/ui/battle_ui.json has no speed section"]
	var steps_v: Variant = s.get("steps")
	if typeof(steps_v) != TYPE_ARRAY or (steps_v as Array).is_empty() or int((steps_v as Array)[0]) != 1:
		return ["battle speed: steps must be a list that starts with 1"]
	var last := 0
	for n in steps_v:
		if typeof(n) not in [TYPE_INT, TYPE_FLOAT] or int(n) <= last or int(n) > 8:
			out.append("battle speed: steps must rise and stay at 8x or below")
			break
		last = int(n)
	var fx: Variant = s.get("fx_scale")
	for n in steps_v:
		if typeof(fx) != TYPE_DICTIONARY or typeof((fx as Dictionary).get(str(int(n)))) not in [TYPE_INT, TYPE_FLOAT]:
			out.append("battle speed: fx_scale needs a number for step %s" % str(int(n)))
		elif float(fx[str(int(n))]) < 0.0 or float(fx[str(int(n))]) > 1.0:
			out.append("battle speed: fx_scale for step %s must be between 0 and 1" % str(int(n)))
	if typeof(fx) == TYPE_DICTIONARY and float((fx as Dictionary).get("1", 0.0)) != 1.0:
		out.append("battle speed: fx_scale at 1x must be 1")
	var rws: Variant = s.get("reduced_wait_scale")
	if typeof(rws) not in [TYPE_INT, TYPE_FLOAT] or float(rws) < 0.0 or float(rws) > 1.0:
		out.append("battle speed: reduced_wait_scale must be between 0 and 1")
	for k in ["event", "cast", "auto_pace"]:
		var w: Variant = (s.get("waits", {}) as Dictionary).get(k)
		if typeof(w) not in [TYPE_INT, TYPE_FLOAT] or float(w) <= 0.0 or float(w) > 2.0:
			out.append("battle speed: waits.%s must be a number of seconds above 0 and at most 2" % k)
	for k in ["skip", "speed"]:
		if key(k) == KEY_NONE:
			out.append("battle speed: keys.%s must name a key" % k)
	if key("skip") == key("speed"):
		out.append("battle speed: skip and speed need different keys")
	for k in ["speed", "speed_compact", "skip_on", "skip_off", "skip_compact_on", "skip_compact_off", "speed_tip", "skip_tip", "forward", "forward_tip"]:
		if str((s.get("text", {}) as Dictionary).get(k, "")) == "":
			out.append("battle speed: text.%s is missing" % k)
	return out
