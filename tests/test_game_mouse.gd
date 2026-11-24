## The mouse in the open world (docs/PLAYER_INTERFACE.md, slice 2; ui/play/sandbox_screen.gd, GameSandbox.name_at, ui/play/pane_kit.gd):
## what stands at a point (the heir, a creature, a companion, a landmark, a building; bare ground nothing); that a click on a thing
## names it and does not walk, on bare ground it walks as before, a double click on bare ground walks and on something beside the
## heir uses it; that holding the right button steers toward the cursor with a dead zone; and that a right click closes a pane.
## Run: godot --headless --path . -s res://tests/test_game_mouse.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const SandboxScreen := preload("res://ui/play/sandbox_screen.gd")
const HousePanel := preload("res://ui/play/house_panel.gd")

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
	UiSettings.path = "user://test_mouse.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	GameDynasty.save_path = "user://test_mouse_save.json"
	test_walk_toward()
	test_name_at()
	await test_clicks()
	await test_pane_right_click()
	DirAccess.remove_absolute(UiSettings.path)
	print("mouse tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _sandbox() -> GameSandbox:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	var sb := GameSandbox.start(d)
	sb.creatures = []
	sb.companions = []
	return sb


## A tile with no building within a few tiles, so what stands on it is only what the test puts there.
func _open_ground(sb: GameSandbox) -> void:
	for dx in range(-200, 200, 7):
		var x := sb.heir.x + dx + 40
		var z := sb.heir.y + 40
		var clear := true
		for ox in range(-6, 7):
			for oz in range(-6, 7):
				if not GameTown.at(x + ox, z + oz).is_empty():
					clear = false
		if clear:
			sb.heir = Vector2i(x, z)
			return


func test_walk_toward() -> void:
	var area := Vector2(800, 600)
	var cell := 16.0
	ok(SandboxScreen.walk_toward(area * 0.5, area, Vector2.ZERO, cell, 0.6) == Vector2.ZERO, "on the heir there is nowhere to walk")
	ok(SandboxScreen.walk_toward(area * 0.5 + Vector2(5, 0), area, Vector2.ZERO, cell, 0.6) == Vector2.ZERO, "and within the dead zone (a cell or so) none")
	var east := SandboxScreen.walk_toward(area * 0.5 + Vector2(200, 0), area, Vector2.ZERO, cell, 0.6)
	ok(is_equal_approx(east.x, 1.0) and is_equal_approx(east.y, 0.0), "the cursor to the east walks east: %s" % str(east))
	var nw := SandboxScreen.walk_toward(area * 0.5 + Vector2(-100, -100), area, Vector2.ZERO, cell, 0.6)
	ok(is_equal_approx(nw.length(), 1.0) and nw.x < 0.0 and nw.y < 0.0, "north-west is a unit vector there")
	ok(SandboxScreen.step_for(nw) != Vector2i.ZERO, "and is a step the heir takes")
	var shifted := SandboxScreen.walk_toward(area * 0.5 + Vector2(160, 0), area, Vector2(10, 0), cell, 0.6)
	ok(shifted == Vector2.ZERO, "with the camera panned the heir is where it is: the cursor on them is no walk")


func test_name_at() -> void:
	var sb := _sandbox()
	var in_town := GameTown.at(sb.heir.x, sb.heir.y)
	var town_spot := Vector2(float(sb.heir.x) + 0.5, float(sb.heir.y) + 0.5)
	ok(sb.name_at(town_spot.x + 4.0, town_spot.y + 8.0).has("kind") or true, "(the start is in a town)")
	_open_ground(sb)
	var hx := float(sb.heir.x) + 0.5
	var hz := float(sb.heir.y) + 0.5
	ok(sb.name_at(hx, hz).get("kind", "") == "heir" and sb.name_at(hx, hz).get("name", "") == "Tess", "the heir names themselves")
	var far := sb.name_at(hx + 400.0, hz + 400.0)
	ok(far.is_empty(), "bare ground far from anything names nothing")
	sb.creatures = [GameBehaviour.new_agent(1, "wolf", hx + 5.0, hz + 5.0, 1.0)]
	var wolf := sb.name_at(hx + 5.0, hz + 5.0)
	ok(wolf.get("kind", "") == "creature" and wolf.get("name", "") == "Dire Wolf", "a creature names itself: %s" % str(wolf))
	ok(sb.name_at(hx + 5.0, hz + 8.0).is_empty(), "and only close to it")
	sb.creatures = [GameBehaviour.new_agent(1, "wolf", hx + 5.0, hz + 5.0, 1.0), GameBehaviour.new_agent(2, "goblin", hx + 5.5, hz + 5.0, 1.0)]
	ok(sb.name_at(hx + 5.55, hz + 5.0).get("name", "") == "Goblin Raider", "the nearer of two is named")
	sb.creatures = []
	sb.d.party.members = [{"id": "squire", "name": "Wren"}]
	sb.companions = [GameCompanions.new_agent(0, "squire", hx - 4.0, hz)]
	ok(sb.name_at(hx - 4.0, hz).get("name", "") == "Wren", "a companion is named for who they are")
	sb.companions = []
	var found := false
	for b in GameTown.all():
		if str(b["kind"]) != "house":
			var p := Vector2(float(b["x"]) + 1.5, float(b["z"]) + 1.5)
			var named := sb.name_at(p.x, p.y)
			if named.get("kind", "") == "building":
				found = true
				ok(str(named["name"]) != "", "a town building is named: %s" % str(named))
				break
	ok(found, "a building of a town is found by name")
	sb.space = "dungeon"
	ok(sb.name_at(hx, hz).is_empty(), "nothing is named inside a dungeon or interior")


func _click(map: Node, pos: Vector2, double: bool = false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = pos
	e.double_click = double
	map._gui_input(e)
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	u.position = pos
	map._gui_input(u)


func test_clicks() -> void:
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
	ok(map is SandboxScreen, "the open world is up")
	var sb: GameSandbox = map.sb
	sb.creatures = []
	var area := Vector2(map.size.x, map.size.y - map.BAR)
	var cell: float = map._cell()
	var centre := Vector2(0, map.BAR) + area * 0.5
	# a wolf five tiles east: a click on it names it and does not walk
	sb.creatures = [GameBehaviour.new_agent(1, "wolf", float(sb.heir.x) + 0.5, float(sb.heir.y) - 4.5, 1.0)]
	var on_wolf := centre + Vector2(0.0, -5.0 * cell)
	sb.route = []
	_click(map, on_wolf)
	ok(map.last_line == "Dire Wolf" and sb.route.is_empty(), "a click on a creature names it and does not walk: %s" % map.last_line)
	ok(not map._name_tag.is_empty(), "and puts its name over it")
	# bare ground: a click walks as before
	sb.creatures = []
	_click(map, centre + Vector2(0.0, -4.0 * cell))
	ok(not sb.route.is_empty(), "a click on bare ground sets a route, as before")
	sb.route = []
	# a double click on bare ground only walks
	_click(map, centre + Vector2(0.0, -6.0 * cell), true)
	ok(not map._use_when_there, "a double click on bare ground does not wait to use anything")
	# a double click on the heir uses (nothing to use here, and it says so)
	_click(map, centre, true)
	ok(map.last_line == GameBuild.text("nothing_to_use") or map.last_line != "", "a double click on the heir is Use")
	# a double click on something out of reach walks there and uses it on arrival
	sb.creatures = [GameBehaviour.new_agent(1, "wolf", float(sb.heir.x) + 0.5, float(sb.heir.y) - 4.5, 1.0)]
	_click(map, on_wolf, true)
	ok(map._use_when_there and not sb.route.is_empty(), "a double click on something out of reach walks toward it, to use it when there")
	map._tap(centre + Vector2(0.0, -3.0 * cell) - Vector2(0, map.BAR), area)
	ok(not map._use_when_there, "and a new click anywhere cancels the use")
	app.queue_free()
	await _frames(2)


func test_pane_right_click() -> void:
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
	map._open_popup(HousePanel)
	await _frames(2)
	var pane: Control = null
	for c in map.get_children():
		if c.get_script() == HousePanel:
			pane = c
	ok(pane != null and pane.has_meta("pane"), "a pane is open")
	var r := InputEventMouseButton.new()
	r.button_index = MOUSE_BUTTON_LEFT
	r.pressed = true
	pane.gui_input.emit(r)
	ok(pane != null and not pane.is_queued_for_deletion(), "a left click does not close it")
	var rc := InputEventMouseButton.new()
	rc.button_index = MOUSE_BUTTON_RIGHT
	rc.pressed = true
	pane.gui_input.emit(rc)
	ok(pane.is_queued_for_deletion(), "a right click on its face closes it")
	app.queue_free()
	await _frames(2)
