## Panes (docs/PLAYER_INTERFACE.md, slice 1; ui/play/pane_kit.gd, data/ui/pane.json): the data and its validator; that a panel the
## open world opens becomes a window of its own on a desktop-sized window (a title bar, no dimming of the whole screen, the
## size from the data); that it is dragged by its title bar, kept reachable, raised when clicked and remembered where it was
## left; that two are open at once and the same panel is not opened twice; and that a narrow window, or a panel that did not ask,
## gets the full-screen overlay it always had.
## Run: godot --headless --path . -s res://tests/test_game_panes.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const PaneKit := preload("res://ui/play/pane_kit.gd")
const SandboxScreen := preload("res://ui/play/sandbox_screen.gd")
const HousePanel := preload("res://ui/play/house_panel.gd")
const Chronicle := preload("res://ui/play/chronicle_panel.gd")

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
	UiSettings.path = "user://test_panes.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	GameDynasty.save_path = "user://test_panes_save.json"
	test_data()
	test_sizes()
	await test_open()
	await test_drag()
	await test_narrow()
	DirAccess.remove_absolute(UiSettings.path)
	print("pane tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _map() -> Node:
	var app: Node = GameApp.new()
	root.add_child(app)
	await _frames(3)
	app.closed_badly = false
	app.new_game("Tess", "warrior", "faetouched", 7)
	await _frames(2)
	app.show_sandbox()
	await _frames(3)
	return app


func _pane_of(map: Node, script: Script) -> Control:
	for c in map.get_children():
		if c.get_script() == script and not c.is_queued_for_deletion():
			return c
	return null


func _bar(pane: Control) -> Control:
	var queue: Array = [pane]
	while not queue.is_empty():
		var n: Node = queue.pop_front()
		if n is Control and n.mouse_default_cursor_shape == Control.CURSOR_DRAG:
			return n
		queue.append_array(n.get_children())
	return null


func _press(bar: Control, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	bar.gui_input.emit(e)


func _move(bar: Control, by: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.relative = by
	bar.gui_input.emit(e)


func test_data() -> void:
	ok(PaneKit.validate().is_empty(), "the pane data is sound: %s" % str(PaneKit.validate()))
	var orig: Dictionary = PaneKit.data()["sizes"].duplicate(true)
	PaneKit.data()["sizes"]["no_such_panel"] = [500, 400]
	ok(not PaneKit.validate().is_empty(), "a size for a panel that does not exist is found")
	PaneKit.data()["sizes"] = orig.duplicate(true)
	PaneKit.data()["sizes"]["house_panel"] = [10, 10]
	ok(not PaneKit.validate().is_empty(), "a size that is too small is found")
	PaneKit.data()["sizes"] = orig.duplicate(true)
	PaneKit.data()["colors"]["face"] = "not a colour"
	ok(not PaneKit.validate().is_empty(), "a colour that is not a colour is found")
	PaneKit.data()["colors"]["face"] = "#1a1828"
	ok(PaneKit.validate().is_empty(), "and the data is whole again after")


func test_sizes() -> void:
	var room := Vector2(1280, 720)
	ok(PaneKit.size_for("shop_panel", room) == Vector2(1040, 640), "a panel with its own size gets it")
	ok(PaneKit.size_for("something_else", room) == Vector2(880, 600), "any other gets the default")
	ok(PaneKit.size_for("shop_panel", Vector2(800, 500)).x <= 800.0 - 24.0, "and a size is cut to the room")
	var inside := PaneKit.clamp_to(Vector2(5000, 5000), Vector2(900, 600), room)
	ok(inside.x <= room.x - 80.0 and inside.y <= room.y - 38.0, "a pane dragged far off keeps its title bar in reach: %s" % str(inside))
	ok(PaneKit.clamp_to(Vector2(-5000, -50), Vector2(900, 600), room).y >= 0.0, "and never above the window")


func test_open() -> void:
	root.size = Vector2i(1280, 720)
	await _frames(2)
	var app := await _map()
	var map: Node = app.current
	ok(map is SandboxScreen, "the open world is up")
	map._open_popup(HousePanel)
	await _frames(2)
	var house := _pane_of(map, HousePanel)
	ok(house != null and house.has_meta("pane") and str(house.get_meta("pane")) == "house_panel", "the house panel is marked as a pane")
	ok(house != null and house.size == PaneKit.size_for("house_panel", UiSettings.room(map)), "and has the size the data gives it")
	ok(house != null and house.size.x < 1280.0 and house.position.x > 0.0, "a window in the middle of the screen, not the whole of it")
	ok(_bar(house) != null, "with a title bar to drag it by")
	var dimmed := false
	for c in house.get_children():
		if c is ColorRect:
			dimmed = true
	ok(not dimmed, "and no dimming of the whole window behind it")
	ok(map._modal_open(), "the world still waits while it is open")
	map._open_popup(Chronicle)
	await _frames(2)
	var chron := _pane_of(map, Chronicle)
	ok(chron != null and house != null and not house.is_queued_for_deletion(), "two panes are open at once")
	ok(chron != null and chron.position != house.position, "the second is set a little off the first")
	var before := map.get_child_count()
	map._open_popup(HousePanel)
	await _frames(2)
	ok(map.get_child_count() == before and map.get_child(map.get_child_count() - 1) == house, "opening one that is already open raises it instead of opening another")
	app.queue_free()
	await _frames(2)


func test_drag() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute(UiSettings.path)
	var app := await _map()
	var map: Node = app.current
	map._open_popup(HousePanel)
	await _frames(2)
	var house := _pane_of(map, HousePanel)
	var bar := _bar(house)
	var start := house.position
	_press(bar, true)
	_move(bar, Vector2(60, 40))
	_move(bar, Vector2(-10, 5))
	_press(bar, false)
	ok(house.position == start + Vector2(50, 45), "dragging the title bar moves the pane by the drag: %s" % str(house.position - start))
	_move(bar, Vector2(300, 300))
	ok(house.position == start + Vector2(50, 45), "a move with the button up does nothing")
	_press(bar, true)
	_move(bar, Vector2(9000, 9000))
	_press(bar, false)
	ok(house.position.x <= 1280.0 - 80.0 and house.position.y <= 720.0 - 38.0, "a pane cannot be dragged out of reach: %s" % str(house.position))
	var left := house.position
	house.queue_free()
	await _frames(2)
	map._open_popup(HousePanel)
	await _frames(2)
	var again := _pane_of(map, HousePanel)
	ok(again != null and again.position == left, "a pane opens where it was left")
	# raising: a click on a pane puts it in front
	map._open_popup(Chronicle)
	await _frames(2)
	var chron := _pane_of(map, Chronicle)
	ok(map.get_child(map.get_child_count() - 1) == chron, "the newest pane is in front")
	_press(_bar(again), true)
	_press(_bar(again), false)
	ok(map.get_child(map.get_child_count() - 1) == again, "and a click on another raises it")
	app.queue_free()
	await _frames(2)


func test_narrow() -> void:
	root.size = Vector2i(1280, 720)
	UiSettings.set_scale(1.5)   # the window holds fewer UI units at a larger scale: narrower than the pane threshold
	UiSettings.apply(root)
	await _frames(2)
	var app := await _map()
	var map: Node = app.current
	map._open_popup(HousePanel)
	await _frames(2)
	var house := _pane_of(map, HousePanel)
	ok(UiSettings.compact(map), "(a window at the larger scale is narrow: %s)" % str(UiSettings.room(map)))
	var dimmed := false
	if house != null:
		for c in house.get_children():
			if c is ColorRect:
				dimmed = true
	ok(house != null and dimmed and house.anchor_right == 1.0, "on a narrow window the panel is the full-screen overlay it always was")
	app.queue_free()
	await _frames(2)
	UiSettings.set_scale(1.0)
	UiSettings.apply(root)
	root.size = Vector2i(1280, 720)
	await _frames(2)
	var plain: Control = HousePanel.new()   # a panel that did not ask to be a pane, opened on a wide window
	plain.dynasty = GameDynasty.new_game(3, "A", "warrior", "faetouched", "human")
	root.add_child(plain)
	await _frames(2)
	var dim2 := false
	for c in plain.get_children():
		if c is ColorRect:
			dim2 = true
	ok(dim2, "a panel that did not ask to be a pane stays an overlay on a wide window too")
	plain.queue_free()
