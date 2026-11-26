## The panel keys and the panel ring (docs/PLAYER_INTERFACE.md; data/ui/radial.json, ui/play/radial_menu.gd, ui/play/sandbox_screen.gd,
## data/ui/input.json): a key for each panel that opens it and, pressed again, closes it, even with another panel up; the camera's look
## keys moved to the numpad so I, J, K and L are free; the ring's geometry (the item toward a point, where each is drawn, fitted into the
## screen), its data checked against the key actions, holding Tab and letting go on an item opening it, a quick tap leaving the ring up
## for a click, Tab or a click on nothing putting it away, and the Menu's labels naming the keys.
## Run: godot --headless --path . -s res://tests/test_game_panels.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const WorldInput := preload("res://ui/play/world_input.gd")
const RadialMenu := preload("res://ui/play/radial_menu.gd")
const SandboxScreen := preload("res://ui/play/sandbox_screen.gd")
const WorldMapPanel := preload("res://ui/play/world_map_panel.gd")

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
	UiSettings.path = "user://test_panels.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	GameDynasty.save_path = "user://test_panels_save.json"
	WorldInput.forget_overrides()
	test_geometry()
	test_data()
	await test_keys()
	await test_ring()
	DirAccess.remove_absolute(UiSettings.path)
	print("panels tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func test_geometry() -> void:
	var c := Vector2(200, 200)
	ok(RadialMenu.pick(c, c + Vector2(0, -80), 8, 28.0) == 0, "straight up is the first item")
	ok(RadialMenu.pick(c, c + Vector2(80, 0), 8, 28.0) == 2, "to the right of eight is the third")
	ok(RadialMenu.pick(c, c + Vector2(0, 80), 8, 28.0) == 4, "straight down is the fifth")
	ok(RadialMenu.pick(c, c + Vector2(-80, 0), 8, 28.0) == 6, "to the left is the seventh")
	ok(RadialMenu.pick(c, c + Vector2(-80, -2), 8, 28.0) == 6 and RadialMenu.pick(c, c + Vector2(-2, -80), 8, 28.0) == 0, "and a small slip keeps the same item")
	ok(RadialMenu.pick(c, c + Vector2(10, 10), 8, 28.0) == -1, "within the middle nothing is chosen")
	ok(RadialMenu.pick(c, c + Vector2(80, 0), 0, 28.0) == -1, "with nothing on the ring nothing is chosen")
	for n in [3, 5, 8, 12]:
		var round_trip := true
		for i in n:
			round_trip = round_trip and RadialMenu.pick(c, RadialMenu.slot_at(c, i, n, 96.0), n, 28.0) == i
		ok(round_trip, "every item of %d is picked at the place it is drawn" % n)
	var fitted := RadialMenu.fit(Vector2(2, 2), Vector2(1280, 720))
	ok(fitted.x > 100.0 and fitted.y > 100.0, "a ring asked for in a corner is moved in: %s" % str(fitted))
	var far := RadialMenu.fit(Vector2(5000, 5000), Vector2(1280, 720))
	ok(far.x < 1280.0 and far.y < 720.0, "and one asked for off the far corner is too: %s" % str(far))
	var mid := RadialMenu.fit(Vector2(640, 360), Vector2(1280, 720))
	ok(mid == Vector2(640, 360), "one in the middle stays where it is")


func test_data() -> void:
	ok(RadialMenu.validate().is_empty(), "the ring's data checks: %s" % str(RadialMenu.validate()))
	ok(WorldInput.validate().is_empty(), "the input data checks: %s" % str(WorldInput.validate()))
	ok(WorldInput.keys_of("world_cam_up") == ["Kp 8"] and WorldInput.keys_of("world_cam_left") == ["Kp 4"], "the look keys are on the numpad")
	ok(WorldInput.key_owner("J") == "world_panel_journal" and WorldInput.key_owner("K") == "world_panel_skills", "so J and K are panels")
	ok(WorldInput.keys_of("world_radial") == ["Tab"] and WorldInput.keys_of("world_menu") == ["F10"], "Tab is the ring and F10 the menu")
	for it in RadialMenu.data()["items"]:
		ok(not WorldInput.keys_of("world_panel_" + str(it["id"])).is_empty(), "%s has a key" % str(it["id"]))
	var saved: Variant = RadialMenu._cache.duplicate(true)
	RadialMenu._cache["items"].append({"id": "nowhere", "label": "Nowhere"})
	ok(not RadialMenu.validate().is_empty(), "an item with no key action is refused")
	RadialMenu._cache = saved
	RadialMenu._cache["settings"]["dead_radius"] = 500
	ok(not RadialMenu.validate().is_empty(), "a middle bigger than the ring is refused")
	RadialMenu._cache = {}


func _key(code: int, pressed: bool = true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	return e


func _has_pane(map: Node, key: String) -> bool:
	for c in map.get_children():
		if c.has_meta("pane") and str(c.get_meta("pane")) == key and not c.is_queued_for_deletion():
			return true
	return false


func _open_map() -> Array:
	root.size = Vector2i(1280, 720)
	var app: Node = GameApp.new()
	root.add_child(app)
	await _frames(3)
	app.closed_badly = false
	app.new_game("Tess", "warrior", "faetouched", 7)
	await _frames(2)
	app.show_sandbox()
	await _frames(3)
	return [app, app.current]


func test_keys() -> void:
	var both: Array = await _open_map()
	var app: Node = both[0]
	var map: Node = both[1]
	ok(map is SandboxScreen, "the open world is up")
	for pair in [[KEY_C, "figure_pane"], [KEY_B, "pack_pane"], [KEY_H, "house_panel"], [KEY_L, "chronicle_panel"], [KEY_K, "skill_tree_panel"], [KEY_G, "shop_panel"]]:
		map._unhandled_input(_key(pair[0]))
		await _frames(2)
		ok(_has_pane(map, pair[1]), "%s opens %s" % [OS.get_keycode_string(pair[0]), pair[1]])
		map._unhandled_input(_key(pair[0]))
		await _frames(2)
		ok(not _has_pane(map, pair[1]), "and the key again closes it")
	# a panel up does not stop another key from opening a second, nor from closing the first
	map._unhandled_input(_key(KEY_H))
	await _frames(2)
	map._unhandled_input(_key(KEY_C))
	await _frames(2)
	ok(_has_pane(map, "house_panel") and _has_pane(map, "figure_pane"), "a second panel opens with the first up")
	map._unhandled_input(_key(KEY_H))
	await _frames(2)
	ok(not _has_pane(map, "house_panel") and _has_pane(map, "figure_pane"), "and the first closes with its own key, even while the world waits")
	map._unhandled_input(_key(KEY_C))
	await _frames(2)
	# the journal and the map
	var was := _has_pane(map, "journal_pane")
	map._unhandled_input(_key(KEY_J))
	await _frames(2)
	ok(_has_pane(map, "journal_pane") != was, "J switches the journal")
	map._unhandled_input(_key(KEY_M))
	await _frames(2)
	var on_map := false
	for c in map.get_children():
		if c.get_script() == WorldMapPanel and not c.is_queued_for_deletion():
			on_map = true
	ok(on_map, "M opens the world map")
	map._unhandled_input(_key(KEY_M))
	await _frames(2)
	on_map = false
	for c in map.get_children():
		if c.get_script() == WorldMapPanel and not c.is_queued_for_deletion():
			on_map = true
	ok(not on_map, "and closes it")
	# a key held down repeats nothing
	var rep := _key(KEY_C)
	rep.echo = true
	map._unhandled_input(rep)
	await _frames(2)
	ok(not _has_pane(map, "figure_pane"), "a held key's repeats do nothing")
	# the Menu names the keys
	map._open_panels_menu()
	await _frames(1)
	var menu: PopupMenu = null
	for c in map.get_children():
		if c is PopupMenu:
			menu = c
	ok(menu != null and menu.get_item_text(4).contains("(C)") and menu.get_item_text(5).contains("(B)"), "the Menu's Character and Pack name their keys")
	if menu != null:
		menu.hide()
	app.queue_free()
	await _frames(2)


func _ring(map: Node) -> Control:
	return map._radial


func test_ring() -> void:
	var both: Array = await _open_map()
	var app: Node = both[0]
	var map: Node = both[1]
	# hold Tab, move toward the first item, let go: it opens
	map._unhandled_input(_key(KEY_TAB))
	ok(_ring(map) != null and _ring(map).items.size() == RadialMenu.data()["items"].size(), "Tab raises the ring with every panel on it")
	ok(map._modal_open(), "and the world waits while it is up")
	map._radial_down_ms -= 1000   # held a second
	_ring(map).hover = 0
	map._unhandled_input(_key(KEY_TAB, false))
	await _frames(3)
	ok(_ring(map) == null and _has_pane(map, "figure_pane"), "letting go on the first item (Character) opens it and puts the ring away")
	map._unhandled_input(_key(KEY_C))
	await _frames(2)
	# a long hold with nothing under the mouse opens nothing
	map._unhandled_input(_key(KEY_TAB))
	map._radial_down_ms -= 1000
	_ring(map).hover = -1
	map._unhandled_input(_key(KEY_TAB, false))
	await _frames(2)
	ok(_ring(map) == null and not _has_pane(map, "figure_pane") and not _has_pane(map, "pack_pane"), "letting go over the middle chooses nothing and closes the ring")
	# a quick tap leaves it up for a click
	map._unhandled_input(_key(KEY_TAB))
	_ring(map).hover = -1
	map._unhandled_input(_key(KEY_TAB, false))
	ok(_ring(map) != null and _ring(map).sticky, "a quick tap leaves the ring up")
	_ring(map).hover = 1   # Pack
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_ring(map)._gui_input(click)
	await _frames(3)
	ok(_ring(map) == null and _has_pane(map, "pack_pane"), "and a click on an item opens it")
	map._unhandled_input(_key(KEY_B))
	await _frames(2)
	# Tab again puts a left-up ring away, and so does a click on nothing
	map._unhandled_input(_key(KEY_TAB))
	map._unhandled_input(_key(KEY_TAB, false))
	map._unhandled_input(_key(KEY_TAB))
	await _frames(2)
	ok(_ring(map) == null, "Tab again puts the ring away")
	map._unhandled_input(_key(KEY_TAB))
	map._unhandled_input(_key(KEY_TAB, false))
	_ring(map).hover = -1
	_ring(map)._gui_input(click)
	await _frames(2)
	ok(_ring(map) == null and not _has_pane(map, "pack_pane") and not _has_pane(map, "figure_pane"), "a click on nothing closes it too")
	ok(not map._modal_open(), "and the world goes on")
	# a ring from the screen's own corner stays on the screen
	var near := RadialMenu.make(Vector2(1, 1), Vector2(1280, 720))
	ok(near.centre.x > 100.0 and near.centre.y > 100.0, "a ring made in a corner is fitted in")
	near.free()
	app.queue_free()
	await _frames(2)
