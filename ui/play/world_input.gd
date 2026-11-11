## Input for a world (roadmap item 39): the open world's actions and bindings from data/ui/input.json, put into the
## engine's input map (`install`), and the arithmetic that turns keys, sticks, fingers and wheels into what the heir
## means: a move, a look, a zoom, a tap on the ground, the tile in front of them. A sandbox screen reads `read()` each
## frame and never asks for a key. Touch is arithmetic only here (a stick drawn where the finger lands, a tap, a
## pinch); the screen that tracks the fingers calls it. Reduced motion carries over: the camera does not glide.
## Input side only: nothing here touches a dynasty.
extends RefCounted

const UiSettings := preload("res://ui/play/ui_settings.gd")
const PATH := "res://data/ui/input.json"

const MOUSE := {"left": MOUSE_BUTTON_LEFT, "right": MOUSE_BUTTON_RIGHT, "middle": MOUSE_BUTTON_MIDDLE,
	"wheel_up": MOUSE_BUTTON_WHEEL_UP, "wheel_down": MOUSE_BUTTON_WHEEL_DOWN}
const PAD_BUTTONS := {"a": JOY_BUTTON_A, "b": JOY_BUTTON_B, "x": JOY_BUTTON_X, "y": JOY_BUTTON_Y,
	"dpad_up": JOY_BUTTON_DPAD_UP, "dpad_down": JOY_BUTTON_DPAD_DOWN, "dpad_left": JOY_BUTTON_DPAD_LEFT, "dpad_right": JOY_BUTTON_DPAD_RIGHT,
	"left_shoulder": JOY_BUTTON_LEFT_SHOULDER, "right_shoulder": JOY_BUTTON_RIGHT_SHOULDER, "start": JOY_BUTTON_START, "back": JOY_BUTTON_BACK,
	"left_stick": JOY_BUTTON_LEFT_STICK, "right_stick": JOY_BUTTON_RIGHT_STICK}
const PAD_AXES := {"left_x": JOY_AXIS_LEFT_X, "left_y": JOY_AXIS_LEFT_Y, "right_x": JOY_AXIS_RIGHT_X, "right_y": JOY_AXIS_RIGHT_Y,
	"trigger_left": JOY_AXIS_TRIGGER_LEFT, "trigger_right": JOY_AXIS_TRIGGER_RIGHT}
## The eight ways to face, as tile steps (x right, y down the screen).
const FACINGS := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> float:
	return float(data()["settings"][key])


static func actions() -> Array:
	return data()["actions"].keys()


# ---------------------------------------------------------------- bindings

## The events bound to an action, built from the data: keys, mouse buttons, pad buttons and pad axes.
static func events_for(action: String) -> Array:
	var out: Array = []
	var a: Dictionary = data()["actions"].get(action, {})
	for k in a.get("keys", []):
		var code := OS.find_keycode_from_string(str(k))
		if code != KEY_NONE:
			var ev := InputEventKey.new()
			ev.keycode = code
			out.append(ev)
	for m in a.get("mouse", []):
		if MOUSE.has(str(m)):
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE[str(m)]
			out.append(ev)
	for b in a.get("pad_buttons", []):
		if PAD_BUTTONS.has(str(b)):
			var ev := InputEventJoypadButton.new()
			ev.button_index = PAD_BUTTONS[str(b)]
			ev.device = -1
			out.append(ev)
	for ax in a.get("pad_axes", []):
		if typeof(ax) == TYPE_ARRAY and (ax as Array).size() == 2 and PAD_AXES.has(str(ax[0])):
			var ev := InputEventJoypadMotion.new()
			ev.axis = PAD_AXES[str(ax[0])]
			ev.axis_value = 1.0 if float(ax[1]) > 0.0 else -1.0
			ev.device = -1
			out.append(ev)
	return out


## Puts every action and its bindings into the engine's input map. Calling it again changes nothing.
static func install() -> void:
	for action in actions():
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, setting("stick_deadzone"))
		for ev in events_for(action):
			InputMap.action_add_event(action, ev)


static func installed() -> bool:
	for action in actions():
		if not InputMap.has_action(action):
			return false
	return true


# ---------------------------------------------------------------- what the heir means

## A stick's push with the dead middle taken out: nothing inside `deadzone`, then growing smoothly to 1 at the rim.
static func stick(v: Vector2, deadzone: float) -> Vector2:
	var len := v.length()
	if len <= deadzone or deadzone >= 1.0:
		return Vector2.ZERO
	return v / len * minf(1.0, (len - deadzone) / (1.0 - deadzone))


## The move four directions add up to (strengths 0 to 1): never longer than 1, so a diagonal is no faster.
static func move_vector(up: float, down: float, left: float, right: float) -> Vector2:
	var v := Vector2(right - left, down - up)
	return v.normalized() if v.length() > 1.0 else v


## A finger's stick: the push from where the finger landed to where it is now.
static func touch_stick(origin: Vector2, now: Vector2) -> Vector2:
	return stick((now - origin) / setting("touch_stick_radius_px"), setting("touch_stick_deadzone"))


## Whether a press and its release were a tap (a short touch that hardly moved) and not a drag or a hold.
static func is_tap(pressed_at: Vector2, released_at: Vector2, seconds: float) -> bool:
	return pressed_at.distance_to(released_at) <= setting("tap_max_px") and seconds <= setting("tap_max_seconds")


## The zoom after `steps` clicks of the wheel or presses of a shoulder (in is positive), held between the limits.
static func zoom_after(zoom: float, steps: int) -> float:
	return clampf(zoom + float(steps) * setting("zoom_step"), setting("zoom_min"), setting("zoom_max"))


## The zoom after two fingers went from `before` apart to `after` apart (pixels).
static func pinch_zoom(zoom: float, before: float, after: float) -> float:
	return clampf(zoom + (after - before) * setting("pinch_zoom_per_px"), setting("zoom_min"), setting("zoom_max"))


## The way a move faces, one of the eight FACINGS; `fallback` when there is no move.
static func facing(move: Vector2, fallback: Vector2i = Vector2i(0, 1)) -> Vector2i:
	if move.length() < 0.001:
		return fallback
	return FACINGS[posmod(int(round(move.angle() / (PI / 4.0))), 8)]


## The tile a gamepad or the keyboard acts on: the one in front of the heir.
static func cell_ahead(tile: Vector2i, facing_dir: Vector2i) -> Vector2i:
	return tile + facing_dir


## How long the camera takes to catch up with the heir: nothing with reduced motion on.
static func camera_follow_seconds() -> float:
	return UiSettings.motion_time(setting("camera_follow_seconds"))


## What is asked for right now, from the input map: {move, look (both -1..1 each way, length at most 1), zoom (-1, 0 or
## 1), dig, build, interact, cancel, menu (each true on the frame it is pressed)}.
static func read() -> Dictionary:
	var move := move_vector(Input.get_action_strength("world_move_up"), Input.get_action_strength("world_move_down"),
		Input.get_action_strength("world_move_left"), Input.get_action_strength("world_move_right"))
	var look := move_vector(Input.get_action_strength("world_cam_up"), Input.get_action_strength("world_cam_down"),
		Input.get_action_strength("world_cam_left"), Input.get_action_strength("world_cam_right"))
	return {
		"move": move, "look": look,
		"zoom": int(Input.is_action_just_pressed("world_zoom_in")) - int(Input.is_action_just_pressed("world_zoom_out")),
		"dig": Input.is_action_just_pressed("world_dig"), "build": Input.is_action_just_pressed("world_build"),
		"interact": Input.is_action_just_pressed("world_interact"), "cancel": Input.is_action_just_pressed("world_cancel"),
		"menu": Input.is_action_just_pressed("world_menu"),
	}


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = data()
	for k in ["settings", "actions"]:
		if not dat.has(k):
			bad.append("input.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var s: Dictionary = dat["settings"]
	for k in ["stick_deadzone", "touch_stick_radius_px", "touch_stick_deadzone", "tap_max_px", "tap_max_seconds", "pinch_zoom_per_px", "zoom_min", "zoom_max", "zoom_step", "camera_follow_seconds"]:
		if not s.has(k):
			bad.append("input.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	for k in ["stick_deadzone", "touch_stick_deadzone"]:
		if float(s[k]) < 0.0 or float(s[k]) >= 1.0:
			bad.append("input.json: %s must be 0 up to (not including) 1" % k)
	if float(s["zoom_min"]) <= 0.0 or float(s["zoom_min"]) >= float(s["zoom_max"]) or float(s["zoom_step"]) <= 0.0:
		bad.append("input.json: zoom_min must be above 0 and under zoom_max, and zoom_step above 0")
	if float(s["touch_stick_radius_px"]) <= 0.0 or float(s["tap_max_px"]) <= 0.0 or float(s["tap_max_seconds"]) <= 0.0 or float(s["camera_follow_seconds"]) < 0.0:
		bad.append("input.json: the stick radius and the tap limits must be above 0, and camera_follow_seconds 0 or more")
	var used := {}   # binding -> action
	for action in dat["actions"]:
		var a: Dictionary = dat["actions"][action]
		if not str(action).begins_with("world_"):
			bad.append("input.json: action '%s' should begin with world_ (the engine's own are ui_)" % action)
		if str(a.get("name", "")) == "":
			bad.append("input.json: action '%s' has no name" % action)
		var bindings: Array = []
		for k in a.get("keys", []):
			if OS.find_keycode_from_string(str(k)) == KEY_NONE:
				bad.append("input.json: action '%s' names a key '%s' the engine does not know" % [action, k])
			bindings.append("key " + str(k))
		for m in a.get("mouse", []):
			if not MOUSE.has(str(m)):
				bad.append("input.json: action '%s' names a mouse button '%s' that is not one" % [action, m])
			bindings.append("mouse " + str(m))
		for b in a.get("pad_buttons", []):
			if not PAD_BUTTONS.has(str(b)):
				bad.append("input.json: action '%s' names a gamepad button '%s' that is not one" % [action, b])
			bindings.append("pad " + str(b))
		for ax in a.get("pad_axes", []):
			if typeof(ax) != TYPE_ARRAY or (ax as Array).size() != 2 or not PAD_AXES.has(str(ax[0])) or absf(float(ax[1])) != 1.0:
				bad.append("input.json: action '%s' has a gamepad axis that is not [axis, -1 or 1]: %s" % [action, str(ax)])
			else:
				bindings.append("axis %s %d" % [ax[0], int(ax[1])])
		for b in bindings:
			if used.has(b):
				bad.append("input.json: '%s' is bound to both %s and %s" % [b, used[b], action])
			used[b] = action
		var desk: bool = not (a.get("keys", []) as Array).is_empty() or not (a.get("mouse", []) as Array).is_empty()
		var pad: bool = not (a.get("pad_buttons", []) as Array).is_empty() or not (a.get("pad_axes", []) as Array).is_empty()
		if not desk:
			bad.append("input.json: action '%s' cannot be reached from a keyboard or mouse" % action)
		if not pad and not bool(a.get("pointer_only", false)):
			bad.append("input.json: action '%s' cannot be reached from a gamepad (mark it pointer_only if that is meant)" % action)
	for need in ["world_move_up", "world_move_down", "world_move_left", "world_move_right", "world_cam_up", "world_cam_down", "world_cam_left", "world_cam_right",
			"world_zoom_in", "world_zoom_out", "world_dig", "world_build", "world_interact", "world_cancel", "world_menu"]:
		if not dat["actions"].has(need):
			bad.append("input.json: the action '%s' is needed (world_input.gd reads it)" % need)
	return bad
