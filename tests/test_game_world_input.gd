## Input for a world (roadmap item 39): the data and ways to break it; every action reachable from the keyboard or mouse
## and from a gamepad, and no key doing two things; installing the bindings (once, however often it is called); real
## key, mouse, pad-button and stick events reaching the right action; the arithmetic (dead middle of a stick, a diagonal
## no faster, a finger's stick, a tap against a drag or a hold, zoom by steps and by pinch, the way a move faces, the
## tile ahead); reading what is asked for; and reduced motion stilling the camera.
## Run: godot --headless --path . -s res://tests/test_game_world_input.gd
extends SceneTree

const WorldInput := preload("res://ui/play/world_input.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const GameApp := preload("res://ui/play/game_app.gd")
const DIR := "user://test_world_input/"

var checks := 0
var fails := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	GameData.load_all()
	UiSettings.path = DIR + "settings.cfg"
	GameDynasty.save_path = DIR + "save.json"
	test_data()
	test_reach()
	test_install()
	await test_events()
	test_arithmetic()
	await test_read()
	await test_app()
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
	print("world input tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _frames(n: int = 2) -> void:
	for i in n:
		await process_frame


func test_data() -> void:
	ok(WorldInput.validate().is_empty(), "the data is sound: %s" % str(WorldInput.validate()))
	var saved: Dictionary = WorldInput.data().duplicate(true)
	WorldInput.data()["actions"]["world_build"]["keys"] = ["E"]
	ok(str(WorldInput.validate()).contains("bound to both"), "a key bound to two actions is found")
	WorldInput._cache = saved.duplicate(true)
	WorldInput.data()["actions"]["world_dig"].erase("pad_buttons")
	ok(str(WorldInput.validate()).contains("gamepad"), "an action a gamepad cannot reach is found")
	WorldInput._cache = saved.duplicate(true)
	WorldInput.data()["actions"]["world_interact"].erase("keys")
	ok(str(WorldInput.validate()).contains("keyboard or mouse"), "an action the keyboard and mouse cannot reach is found")
	WorldInput._cache = saved.duplicate(true)
	WorldInput.data()["actions"]["world_dig"]["keys"] = ["Florp"]
	ok(str(WorldInput.validate()).contains("does not know"), "a key the engine does not know is found")
	WorldInput._cache = saved.duplicate(true)
	WorldInput.data()["actions"]["world_dig"]["pad_buttons"] = ["turbo"]
	ok(not WorldInput.validate().is_empty(), "a gamepad button that is not one is found")
	WorldInput._cache = saved.duplicate(true)
	WorldInput.data()["actions"]["world_move_up"]["pad_axes"] = [["left_y", 0.5]]
	ok(not WorldInput.validate().is_empty(), "a stick direction that is not -1 or 1 is found")
	WorldInput._cache = saved.duplicate(true)
	WorldInput.data()["actions"].erase("world_zoom_in")
	ok(str(WorldInput.validate()).contains("is needed"), "a missing action the code reads is found")
	WorldInput._cache = saved.duplicate(true)
	WorldInput.data()["settings"]["zoom_min"] = 5.0
	ok(not WorldInput.validate().is_empty(), "a least zoom above the most is found")
	WorldInput._cache = saved.duplicate(true)
	WorldInput.data()["actions"]["jump"] = {"name": "Jump", "keys": ["Space"], "pad_buttons": ["back"]}
	ok(str(WorldInput.validate()).contains("world_"), "an action outside the world_ names is found")
	WorldInput._cache = {}
	ok(WorldInput.validate().is_empty(), "(and the data is whole again after)")


func test_reach() -> void:
	var all := true
	var pointer_only := 0
	for action in WorldInput.actions():
		var a: Dictionary = WorldInput.data()["actions"][action]
		var desk: bool = not a.get("keys", []).is_empty() or not a.get("mouse", []).is_empty()
		var pad: bool = not a.get("pad_buttons", []).is_empty() or not a.get("pad_axes", []).is_empty()
		if bool(a.get("pointer_only", false)):
			pointer_only += 1
		elif not (desk and pad):
			all = false
	ok(all and WorldInput.actions().size() >= 15, "every one of the %d actions can be done from the keyboard or mouse and from a gamepad (%d are for a pointer only)" % [WorldInput.actions().size(), pointer_only])
	var moves := 0
	for action in ["world_move_up", "world_move_down", "world_move_left", "world_move_right"]:
		var a: Dictionary = WorldInput.data()["actions"][action]
		if a["keys"].size() >= 2 and not a["pad_buttons"].is_empty() and not a["pad_axes"].is_empty():
			moves += 1
	ok(moves == 4, "moving is on WASD, the arrows, the d-pad and the left stick")


func test_install() -> void:
	for action in WorldInput.actions():
		if InputMap.has_action(action):
			InputMap.erase_action(action)
	ok(not WorldInput.installed(), "nothing is in the input map to begin with")
	WorldInput.install()
	ok(WorldInput.installed(), "install puts every action in")
	var counts := {}
	for action in WorldInput.actions():
		counts[action] = InputMap.action_get_events(action).size()
	ok(counts["world_move_up"] == 4 and counts["world_dig"] == 3 and counts["world_pan"] == 1, "with its bindings (move up has 4, dig 3, drag the view 1)")
	WorldInput.install()
	WorldInput.install()
	var same := true
	for action in WorldInput.actions():
		if InputMap.action_get_events(action).size() != counts[action]:
			same = false
	ok(same, "installing again adds nothing twice")
	ok(InputMap.action_get_events("ui_accept").size() > 0 and not InputMap.has_action("ui_world"), "the engine's own menu actions are left alone")


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)
	await _frames()


func _pad(button: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.device = 0
	Input.parse_input_event(ev)
	await _frames()


func _axis(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	ev.device = 0
	Input.parse_input_event(ev)
	await _frames()


func _mouse(button: MouseButton, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = Vector2(50, 50)
	ev.global_position = Vector2(50, 50)
	Input.parse_input_event(ev)
	await _frames()


func test_events() -> void:
	await _key(KEY_W, true)
	ok(Input.is_action_pressed("world_move_up") and not Input.is_action_pressed("world_move_down"), "W moves up")
	await _key(KEY_W, false)
	ok(not Input.is_action_pressed("world_move_up"), "and letting go stops")
	await _key(KEY_LEFT, true)
	ok(Input.is_action_pressed("world_move_left"), "the left arrow moves left")
	await _key(KEY_LEFT, false)
	await _pad(JOY_BUTTON_DPAD_RIGHT, true)
	ok(Input.is_action_pressed("world_move_right"), "the d-pad moves right")
	await _pad(JOY_BUTTON_DPAD_RIGHT, false)
	await _axis(JOY_AXIS_LEFT_Y, 0.9)
	ok(Input.is_action_pressed("world_move_down") and Input.get_action_strength("world_move_down") > 0.8, "the left stick pushed down moves down, by how far it is pushed")
	await _axis(JOY_AXIS_LEFT_Y, 0.1)
	ok(not Input.is_action_pressed("world_move_down"), "a stick near the middle does nothing (the dead zone)")
	await _axis(JOY_AXIS_LEFT_Y, 0.0)
	await _axis(JOY_AXIS_RIGHT_X, -1.0)
	ok(Input.is_action_pressed("world_cam_left") and not Input.is_action_pressed("world_move_left"), "the right stick looks, it does not move")
	await _axis(JOY_AXIS_RIGHT_X, 0.0)
	await _pad(JOY_BUTTON_X, true)
	ok(Input.is_action_pressed("world_dig") and not Input.is_action_pressed("world_build"), "X digs")
	await _pad(JOY_BUTTON_X, false)
	await _mouse(MOUSE_BUTTON_RIGHT, true)
	ok(Input.is_action_pressed("world_build"), "the right mouse button builds")
	await _mouse(MOUSE_BUTTON_RIGHT, false)
	await _key(KEY_E, true)
	ok(Input.is_action_pressed("world_dig"), "E digs too")
	await _key(KEY_E, false)


func test_arithmetic() -> void:
	ok(WorldInput.stick(Vector2(0.1, 0.1), 0.25) == Vector2.ZERO, "a stick inside its dead middle is no push")
	ok(WorldInput.stick(Vector2(1, 0), 0.25).is_equal_approx(Vector2(1, 0)), "a stick at the rim is a full push")
	var half := WorldInput.stick(Vector2(0.625, 0), 0.25)
	ok(is_equal_approx(half.x, 0.5), "and half way from the dead middle to the rim is half a push (%.2f)" % half.x)
	ok(WorldInput.stick(Vector2(3, 4), 0.25).length() <= 1.0001, "a push is never more than 1")
	ok(is_equal_approx(WorldInput.move_vector(1, 0, 0, 1).length(), 1.0) and WorldInput.move_vector(1, 0, 0, 1).x > 0.0 and WorldInput.move_vector(1, 0, 0, 1).y < 0.0, "up and right together is a diagonal no faster than straight")
	ok(WorldInput.move_vector(1, 1, 0, 0) == Vector2.ZERO, "up and down together cancel")
	ok(WorldInput.move_vector(0.4, 0, 0, 0).is_equal_approx(Vector2(0, -0.4)), "a gentle push is a slow walk")
	var r := WorldInput.setting("touch_stick_radius_px")
	ok(WorldInput.touch_stick(Vector2(100, 100), Vector2(100 + r, 100)).is_equal_approx(Vector2(1, 0)), "a finger dragged a stick's radius right is a full push right")
	ok(WorldInput.touch_stick(Vector2(100, 100), Vector2(103, 101)) == Vector2.ZERO, "a finger that has hardly moved is no push")
	ok(WorldInput.touch_stick(Vector2(100, 100), Vector2(100, 100 - 5 * r)).is_equal_approx(Vector2(0, -1)), "and dragged far it is still only a full push")
	ok(WorldInput.is_tap(Vector2(10, 10), Vector2(14, 12), 0.15), "a short touch that hardly moved is a tap")
	ok(not WorldInput.is_tap(Vector2(10, 10), Vector2(60, 10), 0.15), "a drag is not")
	ok(not WorldInput.is_tap(Vector2(10, 10), Vector2(10, 10), 0.8), "nor a hold")
	ok(is_equal_approx(WorldInput.zoom_after(1.0, 2), 1.5) and is_equal_approx(WorldInput.zoom_after(1.0, -1), 0.75), "the wheel zooms a step at a time")
	ok(is_equal_approx(WorldInput.zoom_after(1.0, 100), WorldInput.setting("zoom_max")) and is_equal_approx(WorldInput.zoom_after(1.0, -100), WorldInput.setting("zoom_min")), "and stops at the limits")
	ok(WorldInput.pinch_zoom(1.0, 100.0, 200.0) > 1.0 and WorldInput.pinch_zoom(1.0, 200.0, 100.0) < 1.0 and is_equal_approx(WorldInput.pinch_zoom(1.0, 100.0, 100.0), 1.0), "fingers moving apart zoom in, together zoom out, still do nothing")
	ok(is_equal_approx(WorldInput.pinch_zoom(1.0, 0.0, 100000.0), WorldInput.setting("zoom_max")), "a pinch stops at the limits too")
	ok(WorldInput.facing(Vector2(1, 0)) == Vector2i(1, 0) and WorldInput.facing(Vector2(0, -1)) == Vector2i(0, -1) and WorldInput.facing(Vector2(-0.7, 0.7)) == Vector2i(-1, 1), "a move faces one of eight ways")
	ok(WorldInput.facing(Vector2(1, 0.2)) == Vector2i(1, 0), "(the nearest of them)")
	ok(WorldInput.facing(Vector2.ZERO, Vector2i(-1, 0)) == Vector2i(-1, 0), "standing still keeps the way last faced")
	ok(WorldInput.cell_ahead(Vector2i(10, 10), WorldInput.facing(Vector2(0, 1))) == Vector2i(10, 11), "the tile acted on is the one in front")
	var all_eight := {}
	for i in 8:
		all_eight[WorldInput.facing(Vector2.RIGHT.rotated(float(i) * PI / 4.0))] = true
	ok(all_eight.size() == 8, "all eight ways can be faced")
	UiSettings.set_access("reduced_motion", false)
	ok(WorldInput.camera_follow_seconds() > 0.0, "the camera glides to the heir")
	UiSettings.set_access("reduced_motion", true)
	ok(WorldInput.camera_follow_seconds() == 0.0, "with reduced motion it does not")
	UiSettings.set_access("reduced_motion", false)


func test_read() -> void:
	var idle := WorldInput.read()
	ok(idle["move"] == Vector2.ZERO and idle["look"] == Vector2.ZERO and idle["zoom"] == 0 and not idle["dig"] and not idle["build"], "with nothing held, nothing is asked for")
	Input.action_press("world_move_up")
	Input.action_press("world_move_right")
	var r := WorldInput.read()
	ok(is_equal_approx(r["move"].length(), 1.0) and r["move"].x > 0.0 and r["move"].y < 0.0, "up and right held reads as one diagonal move")
	Input.action_release("world_move_up")
	Input.action_release("world_move_right")
	Input.action_press("world_cam_left", 0.5)
	ok(WorldInput.read()["look"].is_equal_approx(Vector2(-0.5, 0)), "a half push of the look stick reads as half a look")
	Input.action_release("world_cam_left")
	Input.action_press("world_dig")
	ok(WorldInput.read()["dig"], "a press of dig is read on the frame it happens")
	await _frames(2)
	ok(not WorldInput.read()["dig"] and Input.is_action_pressed("world_dig"), "a held dig digs once, not every frame")
	Input.action_release("world_dig")
	Input.action_press("world_zoom_in")
	ok(WorldInput.read()["zoom"] == 1, "zoom in reads as +1")
	Input.action_release("world_zoom_in")
	await _frames(2)
	Input.action_press("world_zoom_out")
	ok(WorldInput.read()["zoom"] == -1, "and zoom out as -1")
	Input.action_release("world_zoom_out")
	await _mouse(MOUSE_BUTTON_WHEEL_UP, true)
	await _mouse(MOUSE_BUTTON_WHEEL_UP, false)
	ok(WorldInput.read()["zoom"] == 0, "and a wheel click is over by the next frames")


func test_app() -> void:
	for action in WorldInput.actions():
		if InputMap.has_action(action):
			InputMap.erase_action(action)
	var app := GameApp.new()
	root.add_child(app)
	await _frames(3)
	ok(WorldInput.installed(), "the game installs the world's actions when it starts")
	app.queue_free()
	await _frames(2)
