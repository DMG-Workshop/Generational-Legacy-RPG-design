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
static var _over: Variant = null   # the player's own keys, {action: [key names]}; null until read from the settings file


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> float:
	return float(data()["settings"][key])


static func actions() -> Array:
	return data()["actions"].keys()


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


# ---------------------------------------------------------------- the player's own keys

## The saved overrides, cleaned: only known actions, keys the engine knows and that are not reserved, no key on two actions
## (the first action in the data's order keeps it), no more than `max_keys` to an action and never none. Anything else is dropped,
## so a damaged settings file cannot break the controls. Pure: takes what was read, gives what is safe.
static func clean_overrides(raw: Variant) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var taken := {}
	for action in actions():   # what an action keeps by default is not up for grabs
		if not ((raw as Dictionary).has(action) and typeof(raw[action]) == TYPE_ARRAY):
			for k in data()["actions"][action].get("keys", []):
				taken[str(k)] = action
	for action in actions():
		if not (raw as Dictionary).has(action) or typeof(raw[action]) != TYPE_ARRAY:
			continue
		var keys: Array = []
		for k in raw[action]:
			if typeof(k) != TYPE_STRING or OS.find_keycode_from_string(str(k)) == KEY_NONE or str(k) in reserved_keys() or taken.has(str(k)) or str(k) in keys:
				continue
			keys.append(str(k))
		if keys.size() > int(setting("max_keys")):
			keys = keys.slice(0, int(setting("max_keys")))
		if keys.is_empty():
			continue
		for k in keys:
			taken[k] = action
		out[str(action)] = keys
	return out


static func reserved_keys() -> Array:
	return data()["settings"].get("reserved_keys", [])


## The player's overrides (read from settings.cfg the first time).
static func overrides() -> Dictionary:
	if _over == null:
		_over = clean_overrides(UiSettings.stored("keys", {}))
	return _over


## Forgets what was read, so the next ask reads the settings file again (tests; a new settings file).
static func forget_overrides() -> void:
	_over = null


## The keys an action answers to: the player's own if they set any, else the data's.
static func keys_of(action: String) -> Array:
	if overrides().has(action):
		return overrides()[action]
	return data()["actions"].get(action, {}).get("keys", [])


## The action a key is bound to (its keys now, the player's or the data's), or "" when none; `except` is left out.
static func key_owner(key_name: String, except: String = "") -> String:
	for action in actions():
		if action != except and key_name in keys_of(action):
			return action
	return ""


## Binds a key to an action in a slot (0 up to the number of keys it has: the last slot adds one, up to `max_keys`). {ok, text}.
## Refused: an unknown action or key, a reserved key, a key another action has (it names which), a slot beyond the next free one.
## It is saved to settings.cfg and put into the engine's input map at once.
static func remap(action: String, slot: int, key_name: String) -> Dictionary:
	if not data()["actions"].has(action):
		return {"ok": false, "text": text("no_action")}
	if OS.find_keycode_from_string(key_name) == KEY_NONE:
		return {"ok": false, "text": text("bad_key")}
	if key_name in reserved_keys():
		return {"ok": false, "text": text("reserved", {"key": key_name})}
	var other := key_owner(key_name, action)
	if other != "":
		return {"ok": false, "text": text("clash", {"key": key_name, "action": str(data()["actions"][other]["name"]).to_lower()})}
	var keys: Array = (keys_of(action) as Array).duplicate()
	if slot < 0 or slot > keys.size():
		return {"ok": false, "text": text("too_many", {"n": int(setting("max_keys"))})}
	if slot == keys.size():
		if keys.size() >= int(setting("max_keys")):
			return {"ok": false, "text": text("too_many", {"n": int(setting("max_keys"))})}
		keys.append(key_name)
	else:
		keys[slot] = key_name
	var seen := {}
	var unique: Array = []
	for k in keys:
		if not seen.has(k):
			seen[k] = true
			unique.append(k)
	var now := overrides().duplicate(true)
	now[action] = unique
	_save_overrides(now)
	return {"ok": true, "text": text("set", {"action": str(data()["actions"][action]["name"]), "keys": ", ".join(unique)})}


## Takes an action back to the data's keys. A default key another action has since taken stays with that action.
static func reset(action: String) -> Dictionary:
	if not data()["actions"].has(action):
		return {"ok": false, "text": text("no_action")}
	var now := overrides().duplicate(true)
	now.erase(action)
	_save_overrides(now)
	return {"ok": true, "text": text("reset", {"action": str(data()["actions"][action]["name"])})}


static func reset_all() -> void:
	_save_overrides({})


static func _save_overrides(now: Dictionary) -> void:
	_over = clean_overrides(now)
	UiSettings.store("keys", _over)
	install()


# ---------------------------------------------------------------- the mouse's buttons

static var _mouse: Variant = null   # the player's own roles, {role: button name}; null until read from the settings file


static func mouse_roles() -> Array:
	return data()["mouse_roles"].keys()


static func mouse_buttons() -> Array:
	return data()["mouse_buttons"]


## The saved roles, cleaned: only known roles and buttons the game uses, and no two roles on one button (the first role in the
## data's order keeps it). A role not saved, or dropped, has its own default; so a damaged file cannot leave a role unbound.
static func clean_mouse(raw: Variant) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var used := {}
	for role in mouse_roles():
		var own := str(data()["mouse_roles"][role]["default"])
		var b: Variant = (raw as Dictionary).get(role, null)
		if typeof(b) == TYPE_STRING and str(b) in mouse_buttons() and str(b) != own and not used.has(str(b)):
			out[str(role)] = str(b)
			used[str(b)] = true
		else:
			used[own] = true   # the role keeps its own button, so nothing else may take it
	return out


static func mouse_overrides() -> Dictionary:
	if _mouse == null:
		_mouse = clean_mouse(UiSettings.stored("mouse", {}))
	return _mouse


static func forget_mouse() -> void:
	_mouse = null


## The button name ("left", "right", "middle") a role answers to now.
static func mouse_name(role: String) -> String:
	if mouse_overrides().has(role):
		return str(mouse_overrides()[role])
	return str(data()["mouse_roles"].get(role, {}).get("default", ""))


## The engine's button index for a role (MOUSE_BUTTON_LEFT...), or 0 for an unknown role.
static func mouse_button(role: String) -> int:
	return int(MOUSE.get(mouse_name(role), 0))


## The role a button name has now, or "".
static func mouse_owner(button: String) -> String:
	for role in mouse_roles():
		if mouse_name(str(role)) == button:
			return str(role)
	return ""


## Gives a role a button. A button another role has changes places with it (so each role always has a button): {ok, text}.
static func set_mouse(role: String, button: String) -> Dictionary:
	if not data()["mouse_roles"].has(role):
		return {"ok": false, "text": text("no_action")}
	if not button in mouse_buttons():
		return {"ok": false, "text": text("mouse_bad")}
	var other := mouse_owner(button)
	var was := mouse_name(role)
	var now := mouse_overrides().duplicate(true)
	now[role] = button
	var vals := {"role": str(data()["mouse_roles"][role]["name"]).split(":")[0].split(" (")[0], "button": button}
	var line := "mouse_set"
	if other != "" and other != role:
		now[other] = was
		line = "mouse_swap"
		vals["other"] = str(data()["mouse_roles"][other]["name"]).split(":")[0].split(" (")[0].to_lower()
		vals["was"] = was
	_save_mouse(now)
	return {"ok": true, "text": text(line, vals)}


static func reset_mouse() -> Dictionary:
	_save_mouse({})
	return {"ok": true, "text": text("mouse_reset")}


static func _save_mouse(now: Dictionary) -> void:
	_mouse = clean_mouse(now)
	UiSettings.store("mouse", _mouse)


# ---------------------------------------------------------------- bindings

## The events bound to an action, built from the data: keys, mouse buttons, pad buttons and pad axes.
static func events_for(action: String) -> Array:
	var out: Array = []
	var a: Dictionary = data()["actions"].get(action, {})
	for k in keys_of(action):
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
## 1), dig, build, interact, climb_up, climb_down, cancel, menu (each true on the frame it is pressed)}.
static func read() -> Dictionary:
	var move := move_vector(Input.get_action_strength("world_move_up"), Input.get_action_strength("world_move_down"),
		Input.get_action_strength("world_move_left"), Input.get_action_strength("world_move_right"))
	var look := move_vector(Input.get_action_strength("world_cam_up"), Input.get_action_strength("world_cam_down"),
		Input.get_action_strength("world_cam_left"), Input.get_action_strength("world_cam_right"))
	return {
		"move": move, "look": look,
		"zoom": int(Input.is_action_just_pressed("world_zoom_in")) - int(Input.is_action_just_pressed("world_zoom_out")),
		"dig": Input.is_action_just_pressed("world_dig"), "build": Input.is_action_just_pressed("world_build"),
		"interact": Input.is_action_just_pressed("world_interact"),
		"climb_up": Input.is_action_just_pressed("world_climb_up"), "climb_down": Input.is_action_just_pressed("world_climb_down"), "cancel": Input.is_action_just_pressed("world_cancel"),
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
	for k in ["stick_deadzone", "touch_stick_radius_px", "touch_stick_deadzone", "stick_zone_share", "tap_max_px", "tap_max_seconds", "pinch_zoom_per_px", "zoom_min", "zoom_max", "zoom_step", "camera_follow_seconds"]:
		if not s.has(k):
			bad.append("input.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if float(s["stick_zone_share"]) <= 0.0 or float(s["stick_zone_share"]) >= 1.0:
		bad.append("input.json: stick_zone_share must be above 0 and below 1")
	for k in ["stick_deadzone", "touch_stick_deadzone"]:
		if float(s[k]) < 0.0 or float(s[k]) >= 1.0:
			bad.append("input.json: %s must be 0 up to (not including) 1" % k)
	if float(s["zoom_min"]) <= 0.0 or float(s["zoom_min"]) >= float(s["zoom_max"]) or float(s["zoom_step"]) <= 0.0:
		bad.append("input.json: zoom_min must be above 0 and under zoom_max, and zoom_step above 0")
	if float(s["touch_stick_radius_px"]) <= 0.0 or float(s["tap_max_px"]) <= 0.0 or float(s["tap_max_seconds"]) <= 0.0 or float(s["camera_follow_seconds"]) < 0.0:
		bad.append("input.json: the stick radius and the tap limits must be above 0, and camera_follow_seconds 0 or more")
	if int(s.get("max_keys", 0)) < 1 or typeof(s.get("reserved_keys", null)) != TYPE_ARRAY or not dat.has("text"):
		bad.append("input.json: settings.max_keys (1 or more), settings.reserved_keys and text are needed for remapping")
	else:
		for k in s["reserved_keys"]:
			if OS.find_keycode_from_string(str(k)) == KEY_NONE:
				bad.append("input.json: reserved key '%s' is not a key the engine knows" % k)
		for k in ["no_action", "bad_key", "reserved", "clash", "too_many", "set", "reset", "mouse_set", "mouse_swap", "mouse_reset", "mouse_bad"]:
			if not dat["text"].has(k):
				bad.append("input.json: text.%s is missing" % k)
		for action in dat["actions"]:
			var nkeys: int = (dat["actions"][action].get("keys", []) as Array).size()
			if nkeys > int(s["max_keys"]):
				bad.append("input.json: action '%s' has more keys than max_keys" % action)
	if typeof(dat.get("mouse_roles", null)) != TYPE_DICTIONARY or typeof(dat.get("mouse_buttons", null)) != TYPE_ARRAY or float(s.get("walk_hold_seconds", 0.0)) <= 0.0:
		bad.append("input.json: mouse_roles, mouse_buttons and settings.walk_hold_seconds (above 0) are needed")
	else:
		var taken := {}
		for role in ["select", "walk"]:
			if not dat["mouse_roles"].has(role):
				bad.append("input.json: mouse_roles.%s is missing" % role)
				continue
			var r: Dictionary = dat["mouse_roles"][role]
			var own := str(r.get("default", ""))
			if str(r.get("name", "")) == "" or not own in dat["mouse_buttons"] or not MOUSE.has(own):
				bad.append("input.json: mouse role '%s' needs a name and a default button from mouse_buttons" % role)
			if taken.has(own):
				bad.append("input.json: mouse roles '%s' and '%s' share the %s button" % [taken[own], role, own])
			taken[own] = role
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
			"world_zoom_in", "world_zoom_out", "world_dig", "world_build", "world_interact", "world_climb_up", "world_climb_down", "world_cancel", "world_menu"]:
		if not dat["actions"].has(need):
			bad.append("input.json: the action '%s' is needed (world_input.gd reads it)" % need)
	return bad
