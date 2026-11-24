## The popup of actions on a thing, and the mouse's buttons (docs/PLAYER_INTERFACE.md; GameSandbox.thing_actions and give_order,
## WorldInput's mouse roles, ui/play/sandbox_screen.gd, ui/play/controls_panel.gd, ui/play/pane_kit.gd): what a thing offers (the
## heir their character and pack, a person to talk to, a companion each order but its own), a quick click of the walk button on a
## thing opening the popup and a held one walking instead, bare ground opening nothing, the two roles (select and walk) taking any
## button with a clash changing places, a damaged settings file cleaned, the Controls panel's rows, and a pane closing on the walk
## button.
## Run: godot --headless --path . -s res://tests/test_game_thing_menu.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const WorldInput := preload("res://ui/play/world_input.gd")
const SandboxScreen := preload("res://ui/play/sandbox_screen.gd")
const ControlsPanel := preload("res://ui/play/controls_panel.gd")
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


func _fresh() -> void:
	UiSettings.path = "user://test_thing_menu.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	WorldInput.forget_mouse()
	WorldInput.forget_overrides()


func _run() -> void:
	GameData.load_all()
	GameDynasty.save_path = "user://test_thing_menu_save.json"
	_fresh()
	test_actions()
	test_roles()
	await test_screen()
	await test_swapped()
	await test_panel()
	DirAccess.remove_absolute(UiSettings.path)
	print("thing menu tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _sandbox() -> GameSandbox:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	var sb := GameSandbox.start(d)
	sb.creatures = []
	sb.companions = []
	return sb


func _ids(acts: Array) -> Array:
	return acts.map(func(a): return str(a["id"]))


func test_actions() -> void:
	var sb := _sandbox()
	ok(sb.thing_actions({}).is_empty(), "bare ground offers nothing")
	var heir := sb.thing_actions({"kind": "heir", "name": "Tess", "id": ""})
	ok(_ids(heir) == ["character", "pack"], "the heir offers their character and pack: %s" % str(_ids(heir)))
	ok(str(heir[0]["label"]) != "" and str(heir[1]["label"]) != "", "each has a label")
	ok(_ids(sb.thing_actions({"kind": "person", "name": "Smith", "id": ""})) == ["talk", "walk"], "a person offers talking and walking")
	ok(_ids(sb.thing_actions({"kind": "creature", "name": "Wolf", "id": "1"})) == ["walk"], "a creature offers a walk to it")
	ok(_ids(sb.thing_actions({"kind": "building", "name": "Forge", "id": ""})) == ["use", "walk"], "a building offers using it and walking")
	ok(sb.thing_actions({"kind": "nothing", "name": "x"}).is_empty(), "an unknown kind offers nothing")
	sb.d.party.members = [{"id": "squire", "name": "Wren"}]
	var named := {"kind": "companion", "name": "Wren", "id": "squire"}
	var acts := _ids(sb.thing_actions(named))
	ok(acts[0] == "walk" and "order:stay" in acts and "order:guard" in acts and not ("order:follow" in acts), "a companion offers each order but follow, which it has: %s" % str(acts))
	var r := sb.give_order(named, "order:stay")
	ok(r["ok"] and str(sb.d.party.member("squire").get("order", "")) == "stay", "choosing an order gives it")
	acts = _ids(sb.thing_actions(named))
	ok("order:follow" in acts and not ("order:stay" in acts), "and the menu then offers follow and not stay: %s" % str(acts))
	ok(not sb.give_order(named, "walk")["ok"] and not sb.give_order({"kind": "creature", "id": "squire"}, "order:stay")["ok"], "only a companion takes an order")
	ok(not sb.give_order({"kind": "companion", "id": "nobody"}, "order:stay")["ok"], "and only one in the party")
	var before := JSON.stringify(sb.d.to_dict())
	sb.thing_actions(named)
	ok(JSON.stringify(sb.d.to_dict()) == before, "asking what a thing offers changes nothing")


func test_roles() -> void:
	_fresh()
	ok(WorldInput.mouse_name("select") == "left" and WorldInput.mouse_name("walk") == "right", "the roles start on left and right")
	ok(WorldInput.mouse_button("walk") == MOUSE_BUTTON_RIGHT and WorldInput.mouse_button("select") == MOUSE_BUTTON_LEFT, "and the engine's buttons follow")
	ok(WorldInput.validate().is_empty(), "the data checks: %s" % str(WorldInput.validate()))
	var r := WorldInput.set_mouse("walk", "middle")
	ok(r["ok"] and WorldInput.mouse_name("walk") == "middle" and WorldInput.mouse_name("select") == "left", "a free button is simply taken: %s" % r["text"])
	r = WorldInput.set_mouse("walk", "left")
	ok(r["ok"] and WorldInput.mouse_name("walk") == "left" and WorldInput.mouse_name("select") == "middle", "a button the other role has changes places with it: %s" % r["text"])
	ok(WorldInput.mouse_owner("left") == "walk" and WorldInput.mouse_owner("right") == "", "so no two roles share a button")
	WorldInput.forget_mouse()
	ok(WorldInput.mouse_name("walk") == "left" and WorldInput.mouse_name("select") == "middle", "it is kept in settings.cfg")
	ok(not WorldInput.set_mouse("walk", "wheel_up")["ok"] and not WorldInput.set_mouse("fly", "left")["ok"], "a button the game does not use and an unknown role are refused")
	WorldInput.reset_mouse()
	ok(WorldInput.mouse_name("walk") == "right" and WorldInput.mouse_name("select") == "left", "reset gives the own buttons back")
	# a damaged settings file
	ok(WorldInput.clean_mouse("junk").is_empty() and WorldInput.clean_mouse(null).is_empty(), "a mouse setting of the wrong kind is dropped")
	var c := WorldInput.clean_mouse({"select": "right", "walk": "right", "fly": "left"})
	ok(c.get("select", "") == "right" and not c.has("walk") and not c.has("fly"), "two roles on one button: the first keeps it, the other its own: %s" % str(c))
	c = WorldInput.clean_mouse({"select": "wheel_down", "walk": 3})
	ok(c.is_empty(), "an unknown button or a number is dropped")
	c = WorldInput.clean_mouse({"walk": "left"})
	ok(c.is_empty(), "a role named alone on the other's own button is dropped (a swap is saved as both)")
	c = WorldInput.clean_mouse({"select": "right", "walk": "left"})
	ok(c.get("select", "") == "right" and c.get("walk", "") == "left", "a swap, saved as both roles, is kept: %s" % str(c))
	WorldInput.reset_mouse()


func _click(map: Node, pos: Vector2, button: int, held_ms: int = 0) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	e.position = pos
	map._gui_input(e)
	if held_ms > 0:
		map._walk_press_ms -= held_ms   # as if held that long
	var u := InputEventMouseButton.new()
	u.button_index = button
	u.pressed = false
	u.position = pos
	map._gui_input(u)


## A tile with no building within a few tiles and open walking to the north, so what stands on it is only what the test puts there.
func _open_ground(sb: GameSandbox) -> void:
	var home := sb.heir
	for dx in range(0, 600, 7):
		var x := home.x + dx + 40
		var z := home.y + 40
		var clear := GameWorldGen.in_bounds(x, z - 12)
		for ox in range(-9, 10):
			for oz in range(-9, 10):
				if not GameTown.at(x + ox, z + oz).is_empty():
					clear = false
		if clear:
			sb.heir = Vector2i(x, z)
			var walkable := true
			for dz in range(1, 8):
				if not sb.set_route(Vector2i(x, z - dz))["ok"]:
					walkable = false
			sb.route = []
			if walkable:
				return
	sb.heir = home


func _menus(map: Node) -> Array:
	return map.get_children().filter(func(c): return c is PopupMenu and not c.is_queued_for_deletion())


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


func test_screen() -> void:
	_fresh()
	var both: Array = await _open_map()
	var app: Node = both[0]
	var map: Node = both[1]
	ok(map is SandboxScreen, "the open world is up")
	var sb: GameSandbox = map.sb
	_open_ground(sb)
	sb.creatures = []
	sb.companions = []
	var area := Vector2(map.size.x, map.size.y - map.BAR)
	var cell: float = map._cell()
	var centre := Vector2(0, map.BAR) + area * 0.5
	# a quick right click on the heir opens their menu
	_click(map, centre, MOUSE_BUTTON_RIGHT)
	var m := _menus(map)
	ok(m.size() == 1, "a quick click of the walk button on the heir opens a popup")
	if m.size() == 1:
		var menu: PopupMenu = m[0]
		ok(menu.item_count >= 3 and menu.get_item_text(0) == "Tess" and menu.is_item_disabled(0), "headed by the heir's name, which is not a choice")
		menu.id_pressed.emit(0)   # Open the character
		await _frames(2)
		var fig := false
		for c in map.get_children():
			if c.has_meta("pane") and str(c.get_meta("pane")) == "figure_pane":
				fig = true
		ok(fig, "choosing Open the character opens the character pane")
		menu.queue_free()
	await _frames(2)
	for c in map.get_children():
		if c.has_meta("pane"):
			c.queue_free()
	await _frames(2)
	# a creature: its menu walks there
	var off := Vector2i(0, -5)   # five tiles off that the heir can walk to
	for dz in range(-5, -12, -1):
		if sb.set_route(sb.heir + Vector2i(0, dz))["ok"]:
			off = Vector2i(0, dz)
			break
	sb.route = []
	sb.creatures = [GameBehaviour.new_agent(1, "wolf", float(sb.heir.x) + 0.5, float(sb.heir.y) + float(off.y) + 0.5, 1.0)]
	var on_wolf := centre + Vector2(0.0, float(off.y) * cell)
	_click(map, on_wolf, MOUSE_BUTTON_RIGHT)
	m = _menus(map)
	ok(m.size() == 1 and m[0].get_item_text(0) == "Dire Wolf", "a creature's popup is headed by its name")
	ok(sb.route.is_empty(), "and opening it walks nowhere")
	if m.size() == 1:
		m[0].id_pressed.emit(0)
		await _frames(2)
		ok(not sb.route.is_empty() and not map._use_when_there, "choosing Walk there sets a route and uses nothing: %s / %s" % [str(sb.route), map.last_line])
		m[0].queue_free()
	await _frames(2)
	# bare ground: nothing opens
	sb.creatures = []
	_click(map, centre + Vector2(0.0, -6.0 * cell), MOUSE_BUTTON_RIGHT)
	ok(_menus(map).is_empty(), "a quick click of the walk button on bare ground opens nothing")
	# a held button walks and does not open a menu
	sb.creatures = [GameBehaviour.new_agent(1, "wolf", float(sb.heir.x) + 0.5, float(sb.heir.y) + float(off.y) + 0.5, 1.0)]
	_click(map, on_wolf, MOUSE_BUTTON_RIGHT, 1500)
	ok(_menus(map).is_empty(), "a click held past a tap opens no popup")
	map._walk_press_ms = Time.get_ticks_msec()
	ok(not map._walk_held() or not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT), "just pressed, the walk has not begun (a quick click takes no step)")
	map._walk_press_ms = 0
	ok(not map._walk_held(), "and with no press recorded, nothing is held")
	# the select button still names
	sb.creatures = [GameBehaviour.new_agent(1, "wolf", float(sb.heir.x) + 0.5, float(sb.heir.y) + float(off.y) + 0.5, 1.0)]
	_click(map, on_wolf, MOUSE_BUTTON_LEFT)
	ok(map.last_line == "Dire Wolf" and _menus(map).is_empty(), "a left click still names it, and opens no popup")
	app.queue_free()
	await _frames(2)


func test_swapped() -> void:
	_fresh()
	WorldInput.set_mouse("select", "right")   # right selects, left walks
	var both: Array = await _open_map()
	var app: Node = both[0]
	var map: Node = both[1]
	var sb: GameSandbox = map.sb
	var area := Vector2(map.size.x, map.size.y - map.BAR)
	var cell: float = map._cell()
	var centre := Vector2(0, map.BAR) + area * 0.5
	sb.creatures = [GameBehaviour.new_agent(1, "wolf", float(sb.heir.x) + 0.5, float(sb.heir.y) - 4.5, 1.0)]
	var on_wolf := centre + Vector2(0.0, -5.0 * cell)
	_click(map, on_wolf, MOUSE_BUTTON_RIGHT)
	ok(map.last_line == "Dire Wolf" and _menus(map).is_empty(), "with the buttons swapped, the right one names a thing")
	_click(map, on_wolf, MOUSE_BUTTON_LEFT)
	ok(_menus(map).size() == 1, "and a quick click of the left opens the popup")
	for m in _menus(map):
		m.queue_free()
	await _frames(2)
	# a pane closes on the walk button
	map._open_popup(HousePanel)
	await _frames(2)
	var pane: Control = null
	for c in map.get_children():
		if c.get_script() == HousePanel:
			pane = c
	ok(pane != null, "a pane is open")
	var rc := InputEventMouseButton.new()
	rc.button_index = MOUSE_BUTTON_RIGHT
	rc.pressed = true
	pane.gui_input.emit(rc)
	ok(not pane.is_queued_for_deletion(), "the right button, now selecting, no longer closes it")
	var lc := InputEventMouseButton.new()
	lc.button_index = MOUSE_BUTTON_LEFT
	lc.pressed = true
	pane.gui_input.emit(lc)
	ok(pane.is_queued_for_deletion(), "the walk button, now the left, closes it")
	app.queue_free()
	await _frames(2)
	WorldInput.reset_mouse()


func test_panel() -> void:
	_fresh()
	var panel := ControlsPanel.new()
	root.add_child(panel)
	await _frames(2)
	var found := {}
	for role in WorldInput.mouse_roles():
		for b in WorldInput.mouse_buttons():
			var n := panel.find_child("Mouse_%s_%s" % [role, b], true, false)
			found["%s_%s" % [role, b]] = n
	ok(found.values().all(func(n): return n != null), "the Controls panel has a button for each role and button")
	ok(found["walk_right"].disabled and not found["walk_middle"].disabled, "the button a role has now is disabled")
	found["walk_middle"].pressed.emit()
	await _frames(2)
	ok(WorldInput.mouse_name("walk") == "middle", "choosing one sets the role")
	ok(panel.said.text != "", "and says what happened")
	panel._reset_all()
	await _frames(2)
	ok(WorldInput.mouse_name("walk") == "right", "Reset every key and button gives the mouse back too")
	panel.queue_free()
	await _frames(2)
