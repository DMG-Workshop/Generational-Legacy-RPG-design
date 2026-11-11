## Menus by gamepad and keyboard (ui/play/pad_focus.gd): no focus until a pad or an arrow key is used; the first
## input shows the focus on the first button of the screen and the next ones move it; A presses it; an open panel
## keeps the focus inside it however far it is moved; B and Escape go back; Start opens and closes the menu; a rebuilt
## screen gets its focus back; a click drops the focus; a text box keeps its arrows; and every kit button has a ring.
## Run: godot --headless --path . -s res://tests/test_game_pad.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const Kit := preload("res://ui/play/ui_kit.gd")
const MenuPanel := preload("res://ui/play/menu_panel.gd")
const ReportPanel := preload("res://ui/play/report_panel.gd")
const DIR := "user://test_pad/"

var checks := 0
var fails := 0
var app: Node


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_wipe()
	GameDynasty.save_path = DIR + "save.json"
	UiSettings.path = DIR + "settings.cfg"
	UiSettings.scale = 1.0
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	root.size = Vector2i(1280, 720)
	await _frames(2)
	app = GameApp.new()
	root.add_child(app)
	await _frames(3)
	await test_wakes_on_the_pad()
	await test_moves_and_presses()
	await test_stays_in_the_panel()
	await test_back_and_start()
	await test_keyboard()
	await test_mouse_drops_it()
	await test_life_screen()
	test_ring()
	_wipe()
	print("pad tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _wipe() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)


func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


func _focus() -> Control:
	return root.gui_get_focus_owner()


func _pad(button: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = button
		ev.pressed = pressed
		ev.device = 0
		Input.parse_input_event(ev)
		await _frames(2)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _frames(2)


func _click() -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = Vector2(4, 4)
		ev.global_position = Vector2(4, 4)
		Input.parse_input_event(ev)
		await _frames(2)


func _menu() -> Control:
	for c in app.current.get_children():
		if c is MenuPanel and not c.is_queued_for_deletion():
			return c
	return null


func _inside(c: Control, top: Node) -> bool:
	return c != null and (c == top or top.is_ancestor_of(c))


func test_wakes_on_the_pad() -> void:
	app.show_title()
	await _frames(3)
	ok(_focus() == null and not app.pad.on, "with a mouse or a finger nothing has the focus")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	var f := _focus()
	ok(app.pad.on and f != null and _inside(f, app.current), "the first press on the d-pad puts the focus on the screen (%s)" % (f.get_class() if f != null else "nothing"))
	ok(f == app.pad.first_in(app.current), "on its first button or box")


func test_moves_and_presses() -> void:
	var m: Control = app.open_menu()
	await _frames(4)
	var first := _focus()
	ok(first is Button and (first as Button).text == "Close" and _inside(first, m), "a panel that opens takes the focus: the menu's Close")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	var second := _focus()
	ok(second != first and second is Button and _inside(second, m), "down moves it to another button of the menu (%s)" % (second as Button).text)
	await _pad(JOY_BUTTON_DPAD_UP)
	ok(_focus() == first, "and up brings it back")
	await _pad(JOY_BUTTON_A)
	await _frames(3)
	ok(_menu() == null, "A presses the focused button: Close closes the menu")
	ok(_inside(_focus(), app.current), "and the focus goes back to the screen under it")


func test_stays_in_the_panel() -> void:
	var m: Control = app.open_menu()
	await _frames(4)
	var strayed := false
	var seen := {}
	for i in 40:
		await _pad(JOY_BUTTON_DPAD_DOWN if i % 5 != 4 else JOY_BUTTON_DPAD_RIGHT)
		var f := _focus()
		if f != null:
			seen[f.get_instance_id()] = true
		if not _inside(f, _menu()):
			strayed = true
			print("  strayed at move %d to %s" % [i, str(f)])
	ok(not strayed, "forty moves down and across never take the focus out of the open menu")
	ok(seen.size() >= 6, "and it reaches the menu's many buttons (%d of them)" % seen.size())
	var scroll: ScrollContainer = null
	for c in m.get_children():
		if c is ScrollContainer:
			scroll = c
	ok(scroll != null and scroll.follow_focus, "the menu scrolls to follow the focus (it is taller than the window)")
	_menu().queue_free()
	await _frames(3)


func test_back_and_start() -> void:
	app.open_menu()
	await _frames(3)
	await _pad(JOY_BUTTON_B)
	await _frames(2)
	ok(_menu() == null, "B closes the open panel")
	await _pad(JOY_BUTTON_START)
	await _frames(3)
	ok(_menu() != null and _inside(_focus(), _menu()), "Start opens the menu, focused")
	app.open_report()
	await _frames(4)
	var report: Control = null
	for c in app.current.get_children():
		if c is ReportPanel:
			report = c
	ok(report != null and _inside(_focus(), report), "a panel opened over the menu takes the focus from it")
	await _pad(JOY_BUTTON_B)
	await _frames(3)
	ok(_menu() != null and _inside(_focus(), _menu()), "B closes only the top panel, and the focus returns to the menu")
	await _pad(JOY_BUTTON_START)
	await _frames(3)
	ok(_menu() == null, "Start closes the menu again")


func test_keyboard() -> void:
	await _click()
	ok(not app.pad.on, "(pad mode off)")
	await _key(KEY_DOWN)
	ok(app.pad.on and _inside(_focus(), app.current), "an arrow key wakes the focus too")
	await _key(KEY_ESCAPE)
	await _frames(3)
	ok(_menu() != null, "Escape with nothing open opens the menu (as the back button does)")
	await _key(KEY_ESCAPE)
	await _frames(3)
	ok(_menu() == null, "and Escape again closes it")


func test_mouse_drops_it() -> void:
	await _pad(JOY_BUTTON_DPAD_DOWN)
	ok(app.pad.on and _focus() != null, "(the pad has the focus)")
	await _click()
	ok(not app.pad.on and _focus() == null, "a click turns pad mode off and drops the focus: no ring for a mouse")
	app.open_menu()
	await _frames(3)
	ok(_focus() == null, "and a panel opened by mouse takes no focus")
	_menu().queue_free()
	await _frames(2)


func test_life_screen() -> void:
	app.new_game("Tess", "warrior", "faetouched", 31)
	await _frames(3)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	var f := _focus()
	ok(f is Button and _inside(f, app.current), "on the life screen the pad focuses an action (%s)" % ((f as Button).text if f is Button else "?"))
	app.show_state()   # the screen is rebuilt, as after any action
	await _frames(4)
	ok(_inside(_focus(), app.current) and _focus() != f, "a rebuilt screen gets the focus back on its own")
	await _click()


func test_ring() -> void:
	var b := Kit.button("x", func(): pass)
	var ring := b.get_theme_stylebox("focus")
	ok(ring is StyleBoxFlat and not (ring as StyleBoxFlat).draw_center and (ring as StyleBoxFlat).border_width_left >= 2, "every kit button has a focus ring")
	b.free()
