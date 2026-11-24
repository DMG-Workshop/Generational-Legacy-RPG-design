## Giving companions orders the way a strategy game does (GameCompanions.place, GameSandbox.send_order and order_party, ui/play/
## sandbox_screen.gd, data/ui/input.json): a click on a companion chooses them (and again lets them go), a quick right click then sends
## them (bare ground: hold that place, a creature: guard it, the heir: follow), the keys T Y U O P give the chosen companion or, with none
## chosen, everyone an order, the chosen one is drawn in a ring, and a thing that is none of these still opens the popup.
## Run: godot --headless --path . -s res://tests/test_game_orders.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const WorldInput := preload("res://ui/play/world_input.gd")
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
	UiSettings.path = "user://test_orders.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	GameDynasty.save_path = "user://test_orders_save.json"
	WorldInput.forget_overrides()
	test_core()
	await test_screen()
	DirAccess.remove_absolute(UiSettings.path)
	print("orders tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## The party with these companions on the payroll (as test_game_companions makes them), in place of what it had.
func _hire(d: GameDynasty, ids: Array) -> void:
	d.party.members = []
	for id in ids:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": 10, "gen": 1,
			"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
		d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
			"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}


func _sandbox() -> GameSandbox:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	_hire(d, ["bren_cask", "maddy_thorn"])
	var sb := GameSandbox.start(d)
	sb.creatures = []
	sb.companions = [GameCompanions.new_agent(0, "bren_cask", 10.5, 10.5), GameCompanions.new_agent(1, "maddy_thorn", 12.5, 10.5)]
	return sb


func test_core() -> void:
	var agents := [GameCompanions.new_agent(0, "bren_cask", 10.5, 10.5), GameCompanions.new_agent(1, "maddy_thorn", 12.5, 10.5)]
	var placed := GameCompanions.place(agents, "bren_cask", "stay", 30.5, 40.5)
	ok(placed[0]["order"] == "stay" and placed[0]["post_x"] == 30.5 and placed[0]["post_z"] == 40.5, "place gives the order and the post")
	ok(placed[0]["x"] == 10.5 and placed[0]["plan"] == [] and placed[0]["target"] == {}, "they stay where they are and forget their work")
	ok(placed[1]["order"] == "follow" and placed[1]["post_x"] == 12.5, "the others are untouched")
	ok(agents[0]["order"] == "follow" and agents[0]["post_x"] == 10.5, "and the old agents are not changed")
	ok(GameCompanions.place(agents, "bren_cask", "dance", 1.0, 1.0)[0]["order"] == "follow", "an unknown order changes nothing")
	ok(GameCompanions.place(agents, "nobody", "stay", 1.0, 1.0)[1]["post_x"] == 12.5, "an id with no agent changes nothing")
	var sb := _sandbox()
	var r := sb.send_order("bren_cask", "stay", 30.5, 40.5)
	ok(r["ok"] and GameCompanions.order_of(sb.d, "bren_cask") == "stay" and sb.companions[0]["post_x"] == 30.5, "send_order sets the party's order and the agent's post")
	ok(GameCompanions.order_of(sb.d, "maddy_thorn") == "follow", "and no one else's")
	r = sb.send_order("bren_cask", "follow", 0.0, 0.0)
	ok(r["ok"] and GameCompanions.order_of(sb.d, "bren_cask") == "follow", "follow brings them back (no post to send them to)")
	ok(not sb.send_order("nobody", "stay", 1.0, 1.0)["ok"], "someone not in the party is refused")
	var lines := sb.order_party("guard")
	ok(lines.size() == 2 and GameCompanions.order_of(sb.d, "bren_cask") == "guard" and GameCompanions.order_of(sb.d, "maddy_thorn") == "guard", "order_party orders everyone")
	lines = sb.order_party("gather", "maddy_thorn")
	ok(lines.size() == 1 and GameCompanions.order_of(sb.d, "maddy_thorn") == "gather" and GameCompanions.order_of(sb.d, "bren_cask") == "guard", "or just one")
	ok(sb.order_party("stay", "nobody").is_empty(), "and no one at all for an id not in the party")
	ok(WorldInput.validate().is_empty(), "the input data checks: %s" % str(WorldInput.validate()))
	for o in GameCompanions.ORDERS:
		ok(WorldInput.keys_of("world_order_" + str(o)).size() == 1, "%s has a key" % str(o))


func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


func _click(map: Node, pos: Vector2, button: int) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	e.position = pos
	map._gui_input(e)
	var u := InputEventMouseButton.new()
	u.button_index = button
	u.pressed = false
	u.position = pos
	map._gui_input(u)


## A tile with no building within a few tiles and open walking round it, so what stands on it is only what the test puts there.
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


func test_screen() -> void:
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
	var sb: GameSandbox = map.sb
	_open_ground(sb)
	_hire(sb.d, ["bren_cask", "maddy_thorn"])
	var area := Vector2(map.size.x, map.size.y - map.BAR)
	var cell: float = map._cell()
	var centre := Vector2(0, map.BAR) + area * 0.5
	var hx := float(sb.heir.x)
	var hz := float(sb.heir.y)
	sb.creatures = []
	sb.companions = [GameCompanions.new_agent(0, "bren_cask", hx + 5.5, hz + 0.5), GameCompanions.new_agent(1, "maddy_thorn", hx - 4.5, hz + 0.5)]
	# a click on a companion chooses them, again lets them go
	_click(map, centre + Vector2(5.0 * cell, 0.0), MOUSE_BUTTON_LEFT)
	ok(map.selected_companion == "bren_cask" and map.last_line.contains("Bren"), "a click on a companion chooses them: %s / %s" % [map.selected_companion, map.last_line])
	_click(map, centre + Vector2(5.0 * cell, 0.0), MOUSE_BUTTON_LEFT)
	ok(map.selected_companion == "", "and a second click lets them go: %s" % map.last_line)
	_click(map, centre + Vector2(-5.0 * cell, 0.0), MOUSE_BUTTON_LEFT)
	ok(map.selected_companion == "maddy_thorn", "a click on the other chooses that one instead")
	_click(map, centre + Vector2(5.0 * cell, 0.0), MOUSE_BUTTON_LEFT)
	ok(map.selected_companion == "bren_cask", "and back")
	# a quick right click on bare ground sends them to hold it
	var spot := centre + Vector2(0.0, -6.0 * cell)
	_click(map, spot, MOUSE_BUTTON_RIGHT)
	ok(GameCompanions.order_of(sb.d, "bren_cask") == "stay", "a right click on bare ground sends the chosen companion to stay: %s" % map.last_line)
	var agent: Dictionary = sb.companions[0]
	ok(is_equal_approx(float(agent["post_x"]), hx + 0.5) and is_equal_approx(float(agent["post_z"]), hz - 6.0 + 0.5), "their post is the tile clicked: %s,%s" % [agent["post_x"], agent["post_z"]])
	ok(GameCompanions.order_of(sb.d, "maddy_thorn") == "follow", "and no one else is sent")
	var popups := map.get_children().filter(func(c): return c is PopupMenu and not c.is_queued_for_deletion())
	ok(popups.is_empty(), "with no popup")
	# a creature: guard it
	sb.creatures = [GameBehaviour.new_agent(1, "wolf", hx + 0.5, hz - 4.5, 1.0)]
	_click(map, centre + Vector2(0.0, -5.0 * cell), MOUSE_BUTTON_RIGHT)
	ok(GameCompanions.order_of(sb.d, "bren_cask") == "guard", "a right click on a creature sends them to guard it: %s" % map.last_line)
	sb.creatures = []
	# the heir: follow
	_click(map, centre, MOUSE_BUTTON_RIGHT)
	ok(GameCompanions.order_of(sb.d, "bren_cask") == "follow", "a right click on the heir brings them back to follow")
	# the order keys: the chosen one, else everyone
	map._unhandled_input(_key(KEY_Y))
	ok(GameCompanions.order_of(sb.d, "bren_cask") == "stay" and GameCompanions.order_of(sb.d, "maddy_thorn") == "follow", "Y gives the chosen companion stay, and only them")
	map.selected_companion = ""
	map._unhandled_input(_key(KEY_O))
	ok(GameCompanions.order_of(sb.d, "bren_cask") == "guard" and GameCompanions.order_of(sb.d, "maddy_thorn") == "guard", "with none chosen O orders everyone to guard")
	map._unhandled_input(_key(KEY_T))
	ok(GameCompanions.order_of(sb.d, "bren_cask") == "follow" and GameCompanions.order_of(sb.d, "maddy_thorn") == "follow", "and T brings them all back")
	# with a companion chosen, a click on something else still opens the popup
	map.selected_companion = "bren_cask"
	_click(map, centre + Vector2(-5.0 * cell, 0.0), MOUSE_BUTTON_RIGHT)   # the other companion
	popups = map.get_children().filter(func(c): return c is PopupMenu and not c.is_queued_for_deletion())
	ok(popups.size() == 1, "a right click on another companion still opens their popup")
	for p in popups:
		p.queue_free()
	await _frames(2)
	# a companion who leaves the party is no longer chosen
	_hire(sb.d, ["maddy_thorn"])
	_click(map, centre + Vector2(0.0, -6.0 * cell), MOUSE_BUTTON_RIGHT)
	ok(map.selected_companion == "", "a chosen companion who has left the party is let go")
	map.selected_companion = ""
	_hire(sb.d, [])
	map.last_line = ""
	map._unhandled_input(_key(KEY_Y))
	ok(map.last_line == str(GameSandbox.data()["text"]["nobody"]), "an order key with no one in the party says so: %s" % map.last_line)
	# the chosen companion is drawn with their ring (the screen draws without error)
	_hire(sb.d, ["bren_cask"])
	map.selected_companion = "bren_cask"
	map.overlay.queue_redraw()
	await _frames(3)
	ok(true, "the ring draws")
	app.queue_free()
	await _frames(2)
