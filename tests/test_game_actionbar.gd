## The open world's action bar (data/ui/actionbar.json, data/art/action_icons.json, ui/play/action_slot.gd, ui/play/sandbox_screen.gd,
## data/ui/input.json): eight numbered slots and two small buttons on a desktop window with a mouse, each with a picture, a tooltip naming
## its keys, and the number key that does the same as a click; a slot that does not apply is dimmed and says why; a mode's slot lights
## while it is on; the number keys are held off while a panel is up or the build bar has the controls; a touch screen keeps its text
## buttons; and the data is checked (a picture of 8 rows for each, a key action for each number).
## Run: godot --headless --path . -s res://tests/test_game_actionbar.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const WorldInput := preload("res://ui/play/world_input.gd")
const ActionSlot := preload("res://ui/play/action_slot.gd")
const SandboxScreen := preload("res://ui/play/sandbox_screen.gd")

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	GameData.load_all()
	UiSettings.path = "user://test_actionbar.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	GameDynasty.save_path = "user://test_actionbar_save.json"
	WorldInput.forget_overrides()
	test_data()
	await test_bar()
	await test_touch()
	DirAccess.remove_absolute(UiSettings.path)
	print("action bar tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func test_data() -> void:
	ok(ActionSlot.validate().is_empty(), "the bar's data checks: %s" % str(ActionSlot.validate()))
	ok(ActionSlot.data()["slots"].size() == 9, "nine numbered slots")
	for i in range(1, 10):
		ok(WorldInput.keys_of("world_slot_%d" % i) == [str(i)], "slot %d answers to the %d key" % [i, i])
	ok(WorldInput.validate().is_empty(), "the input data checks: %s" % str(WorldInput.validate()))
	for def in (ActionSlot.data()["slots"] as Array) + (ActionSlot.data()["extras"] as Array):
		var tex := ActionSlot.texture(str(def["glyph"]))
		var img := tex.get_image()
		var lit := 0
		for y in 8:
			for x in 8:
				if img.get_pixel(x, y).a > 0.5:
					lit += 1
		ok(lit >= 10 and lit <= 50, "%s has a picture (%d pixels lit)" % [str(def["id"]), lit])
	ok(ActionSlot.tip_for({"label": "Dig", "action": "world_dig"}, "2") == "Dig  (2, E)", "a tooltip names the number then the key: %s" % ActionSlot.tip_for({"label": "Dig", "action": "world_dig"}, "2"))
	ok(ActionSlot.tip_for({"label": "Forage"}, "3") == "Forage  (3)", "and just the number with no key action")
	ok(ActionSlot.tip_for({"label": "Menu", "action": "world_cancel"}, "") == "Menu  (Escape)", "a small button names only its key")
	var saved: Variant = ActionSlot._bar.duplicate(true)
	ActionSlot._bar["slots"][0]["glyph"] = "nothing"
	ok(not ActionSlot.validate().is_empty(), "a slot with no picture is refused")
	ActionSlot._bar = saved.duplicate(true)
	ActionSlot._bar["slots"].append({"id": "extra9", "label": "Nine", "glyph": "use", "color": [1, 1, 1]})
	ActionSlot._bar["slots"].append({"id": "extra10", "label": "Ten", "glyph": "use", "color": [1, 1, 1]})
	ok(not ActionSlot.validate().is_empty(), "more slots than number keys are refused")
	ActionSlot._bar = {}


func _key(code: int, pressed: bool = true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	return e


func test_bar() -> void:
	root.size = Vector2i(1280, 720)
	var app: Node = GameApp.new()
	root.add_child(app)
	await _frames(3)
	app.closed_badly = false
	app.new_game("Tess", "warrior", "faetouched", 7)
	await _frames(2)
	app.show_sandbox()
	await _frames(3)
	var map: Node = app.current
	ok(map is SandboxScreen and map.slot_ids.size() == 9, "the open world has the nine numbered slots")
	ok(map.slots.has("menu") and map.slots.has("map"), "and the Menu and the map")
	ok(map.cast_button == null, "no text Cast button on this bar")
	var order := ["use", "dig", "forage", "build", "cast", "orders", "up", "down", "smoke"]
	ok(map.slot_ids == order, "in the data's order: %s" % str(map.slot_ids))
	ok(map.slots["dig"].badge == "2" and map.slots["dig"].tooltip_text == "Dig  (2, E)", "a slot shows its number and names its keys: %s" % map.slots["dig"].tooltip_text)
	ok(map.slots["cast"].dim, "Cast is dimmed with no spell to cast")
	# the ninth slot is the smoke pot: dimmed with none, its tooltip counts them, the 9 key and a click light a cloud
	ok(map.slots["smoke"].badge == "9" and map.slots["smoke"].dim, "Smoke is dimmed when the heir has no pot")
	ok(map.slots["smoke"].tooltip_text == "Smoke pot  (9): none", "and its tooltip says none: %s" % map.slots["smoke"].tooltip_text)
	map.last_line = ""
	map._unhandled_input(_key(KEY_9))
	ok(map.last_line.contains("no smoke pot") and map.app.dynasty.smoke.is_empty(), "the 9 key with none says so and lights nothing: %s" % map.last_line)
	map.app.dynasty.heir.inventory.append("smoke_pot")
	map.app.dynasty.heir.inventory.append("smoke_pot")
	map._refresh_status()
	ok(not map.slots["smoke"].dim and map.slots["smoke"].tooltip_text == "Smoke pot  (9): 2 left", "with pots it is lit and counts them: %s" % map.slots["smoke"].tooltip_text)
	map.slots["smoke"].pressed.call()
	ok(GameSmoke.active(map.app.dynasty) and GameSmoke.count(map.app.dynasty.heir) == 1, "a click breaks one and lights the cloud")
	ok(map.slots["smoke"].active and map.slots["smoke"].tooltip_text == "Smoke pot  (9): 1 left", "the slot lights while it burns: %s" % map.slots["smoke"].tooltip_text)
	map.app.dynasty.smoke = {}
	map._unhandled_input(_key(KEY_9))
	ok(GameSmoke.active(map.app.dynasty) and GameSmoke.count(map.app.dynasty.heir) == 0, "the 9 key does the same")
	map.app.dynasty.smoke = {}
	map._refresh_status()
	# a click and the key do the same
	map.last_line = ""
	map.slots["use"].pressed.call()
	var by_click: String = map.last_line
	map.last_line = ""
	map._unhandled_input(_key(KEY_1))
	ok(by_click != "" and map.last_line == by_click, "the 1 key does what a click on Use does: '%s'" % by_click)
	# a held key repeats nothing
	map.last_line = ""
	var rep := _key(KEY_1)
	rep.echo = true
	map._unhandled_input(rep)
	ok(map.last_line == "", "a held key's repeats do nothing")
	# the cast slot with nothing to cast says so
	map.last_line = ""
	map._unhandled_input(_key(KEY_5))
	ok(map.last_line == ActionSlot.text("cast_none"), "Cast says there is nothing to cast: %s" % map.last_line)
	# build lights while it is on, and the other slots hold off while the build bar has the controls
	ok(map.mode == "walk" and not map.slots["build"].active, "build is not lit at first")
	map._unhandled_input(_key(KEY_4))
	await _frames(2)
	ok(map.mode == "build" and map.slots["build"].active, "the 4 key starts building and lights the slot")
	map.last_line = "unchanged"
	map._unhandled_input(_key(KEY_2))
	ok(map.last_line == "unchanged", "Dig is held off while building")
	map.slots["build"].pressed.call()
	await _frames(2)
	ok(map.mode == "walk" and not map.slots["build"].active, "a click on Build ends it and puts the light out")
	# orders light with their panel
	map._unhandled_input(_key(KEY_6))
	await _frames(2)
	ok(map.orders_panel.visible and map.slots["orders"].active, "the 6 key opens the orders and lights the slot")
	map._unhandled_input(_key(KEY_6))
	await _frames(2)
	ok(not map.orders_panel.visible and not map.slots["orders"].active, "and again puts them away")
	# the number keys wait while a panel is up
	map._unhandled_input(_key(KEY_H))
	await _frames(2)
	ok(map._modal_open(), "the house is up")
	map.last_line = "unchanged"
	map._unhandled_input(_key(KEY_1))
	ok(map.last_line == "unchanged", "the number keys do nothing while a panel is up")
	map._unhandled_input(_key(KEY_H))
	await _frames(2)
	# the small buttons
	map.slots["map"].pressed.call()
	await _frames(2)
	var on_map := false
	for c in map.get_children():
		if c.get_script() == load("res://ui/play/world_map_panel.gd") and not c.is_queued_for_deletion():
			on_map = true
	ok(on_map, "the map button opens the world map")
	map._unhandled_input(_key(KEY_M))
	await _frames(2)
	map.slots["menu"].pressed.call()
	await _frames(1)
	var menu := false
	for c in map.get_children():
		if c.get_script() == load("res://ui/play/pause_panel.gd"):
			menu = true
	ok(menu, "the Menu button opens the pause screen")
	# a click on a slot node itself
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	map.last_line = ""
	map.slots["use"]._gui_input(click)
	ok(map.last_line != "", "a left click on the slot does it")
	app.queue_free()
	await _frames(2)


func test_touch() -> void:
	UiSettings.force_touch = 1
	root.size = Vector2i(1280, 720)
	var app: Node = GameApp.new()
	root.add_child(app)
	await _frames(3)
	app.closed_badly = false
	app.new_game("Tess", "warrior", "faetouched", 7)
	await _frames(2)
	app.show_sandbox()
	await _frames(3)
	var map: Node = app.current
	ok(map.slots.is_empty() and map.slot_ids.is_empty(), "a touch screen has no slots")
	ok(map.cast_button != null, "and keeps its text buttons")
	var found := false
	for b in map.find_children("*", "Button", true, false):
		if b.text == "Dig":
			found = true
	ok(found, "among them Dig")
	# the touch bar has a text Smoke button, dimmed with none, and the status line leads with the level and experience
	ok(map.smoke_button != null and map.smoke_button.text == "Smoke" and map.smoke_button.modulate.a < 1.0, "a text Smoke button, dim with no pot")
	ok(map.smoke_button.custom_minimum_size.y >= float(UiSettings.setting("touch_target_px")), "as tall as any touch button: %s" % str(map.smoke_button.custom_minimum_size))
	var hh: GameHeir = app.dynasty.heir
	ok(map.status.text.begins_with("Lv %s  XP %s/%s" % [GameText.num(hh.level), GameText.num(hh.xp), GameText.num(hh.xp_to_next())]), "the status line leads with level and experience: %s" % map.status.text)
	app.dynasty.heir.inventory.append("smoke_pot")
	map._refresh_status()
	ok(map.smoke_button.text == "Smoke 1" and is_equal_approx(map.smoke_button.modulate.a, 1.0), "with a pot the button counts it")
	map.smoke_button.pressed.emit()
	await _frames(1)
	ok(GameSmoke.active(app.dynasty) and map.status.text.contains("Smoke "), "pressing it lights the cloud and the status line shows its time: %s" % map.status.text)
	app.queue_free()
	UiSettings.force_touch = -1
	await _frames(2)
