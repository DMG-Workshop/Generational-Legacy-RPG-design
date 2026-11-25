## The world map view (roadmap follow-up): the world sampled at a step into a grid of kinds, markers for every place (named only once
## visited), the family's place and the heir's cell, a picture in the tile view's colours, the panel that draws it and the sandbox's
## Map button that opens it while the world waits. A pure function of the seed and the visits: no dice, nothing saved.
## Run: godot --headless --path . -s res://tests/test_game_world_map.gd
extends SceneTree

const WorldMapPanel := preload("res://ui/play/world_map_panel.gd")

var fails := 0
var checks := 0


class FakeApp extends Node:
	var dynasty: GameDynasty

	func show_state() -> void:
		pass


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	test_data()
	test_grid()
	test_markers()
	test_trials()
	test_image()
	await test_panel()
	await test_screen()
	await test_town_card()
	await test_travel_from_the_map()
	print("world map tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh(seed_value: int = 7) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


func test_data() -> void:
	ok(GameWorldMap.validate().is_empty(), "the shipped data passes: %s" % str(GameWorldMap.validate()))
	var s: Dictionary = GameWorldMap.data()["settings"]
	var keep: Variant = s["step"]
	s["step"] = 0
	ok(not GameWorldMap.validate().is_empty(), "a step of 0 is caught")
	s["step"] = 400
	ok(not GameWorldMap.validate().is_empty(), "a step that leaves no map is caught")
	s["step"] = keep
	var t: Variant = GameWorldMap.data()["text"]["legend"]
	GameWorldMap.data()["text"]["legend"] = ""
	ok(not GameWorldMap.validate().is_empty(), "missing text is caught")
	GameWorldMap.data()["text"]["legend"] = t
	ok(GameWorldMap.validate().is_empty(), "and mending the data clears it")


func test_grid() -> void:
	var d := _fresh()
	var n := GameWorldMap.cells()
	var g := GameWorldMap.grid(d)
	ok(n == int(ceil(float(GameWorldGen.size()) / float(int(GameWorldMap.setting("step"))))) and g.size() == n and (g[0] as Array).size() == n, "a grid of %d by %d cells" % [n, n])
	var kinds := TileView.kinds()
	var bad := 0
	for row in g:
		for k in row:
			if not kinds.has(str(k)):
				bad += 1
	ok(bad == 0, "every cell is a kind the tile view has a colour for")
	ok(g[0][0] == "water" and g[n - 1][n - 1] == "water", "the edges of the world are sea")
	var land := 0
	for row in g:
		for k in row:
			if k != "water":
				land += 1
	ok(land > n * n / 10 and land < n * n, "and there is land and water between: %d of %d cells are land" % [land, n * n])
	# a cell is its middle tile
	var c := Vector2i(n / 2, n / 2)
	var t := GameWorldMap.tile_of(c.x, c.y)
	ok(GameWorldMap.cell_of(t.x, t.y) == c, "a cell's tile falls in that cell")
	var tile := GameWorldGen.tile(d, t.x, t.y)
	ok(GameWorldMap.kind_at(d, c.x, c.y) == TileView.kind_for(tile, ""), "and a cell is what the tile there is: %s" % GameWorldMap.kind_at(d, c.x, c.y))
	ok(JSON.stringify(g) == JSON.stringify(GameWorldMap.grid(_fresh())), "the same seed makes the same map")
	ok(JSON.stringify(g) != JSON.stringify(GameWorldMap.grid(_fresh(11))), "another seed makes another")
	var rng := d.rng.state
	GameWorldMap.grid(d)
	ok(d.rng.state == rng, "no dice are drawn")
	ok(GameWorldMap.cell_of(-5, 99999) == Vector2i(0, n - 1), "a tile off the world is held to the edge cell")


func test_markers() -> void:
	var d := _fresh()
	var ms := GameWorldMap.markers(d)
	ok(ms.size() == GameWorldGen.anchors().size(), "a marker for every place on the map: %d" % ms.size())
	var here := ms.filter(func(m): return bool(m["here"]))
	ok(here.size() == 1 and str(here[0]["id"]) == str(d.world.location), "one is where the family is")
	ok(bool(here[0]["visited"]) and str(here[0]["name"]) == "Hearthmere", "and is named: %s" % here[0]["name"])
	var unknown := ms.filter(func(m): return not bool(m["visited"]))
	ok(unknown.size() >= 1 and unknown.size() == ms.size() - d.world.visited.size(), "places not visited are unknown (%d of %d)" % [unknown.size(), ms.size()])
	for m in unknown:
		ok(str(m["name"]) == GameWorldMap.text("unknown"), "an unvisited place gives no name (%s)" % str(m["id"]))
		break
	var target := str(unknown[0]["id"])
	d.world.visit(target)
	var after: Dictionary = GameWorldMap.markers(d).filter(func(m): return str(m["id"]) == target)[0]
	ok(bool(after["visited"]) and str(after["name"]) != GameWorldMap.text("unknown") and bool(after["here"]), "visiting a place names it, and the family is there now")
	var home: Dictionary = GameWorldMap.markers(d).filter(func(m): return str(m["id"]) == "hearthmere")[0]
	ok(not bool(home["here"]) and bool(home["visited"]), "and the home town is still known, no longer here")
	var a := GameWorldGen.anchor("hearthmere")
	ok(int(home["x"]) == int(a["x"]) and home["cell"] == GameWorldMap.cell_of(int(a["x"]), int(a["z"])), "a marker is at its anchor")
	ok(GameWorldMap.here_line(d).contains(str(d.world.here()["name"])), "the line says where the family is: %s" % GameWorldMap.here_line(d))


func test_trials() -> void:
	var d := _fresh()
	ok(GameWorldMap.trial_markers(d).is_empty(), "no trial is on the map before the family has found one")
	ok(GameWorldMap.trial_lines(d, 4).size() == 1 and GameWorldMap.trial_lines(d, 4)[0] == GameWorldMap.text("trial_none"), "and the list says so")
	var placed := GameTrials.placed(d.seed_value, "material")
	ok(not placed.is_empty(), "the world has trials in the open realm")
	var id := str(placed[0]["id"])
	d.trials["steps"] = {id: 1}
	var ms := GameWorldMap.trial_markers(d)
	ok(ms.size() == 1 and str(ms[0]["id"]) == id and not bool(ms[0]["passed"]), "the first step of the way in puts the trial's site on the map")
	var m: Dictionary = ms[0]
	var n := GameWorldGen.size()
	ok(int(m["x"]) >= 0 and int(m["z"]) >= 0 and int(m["x"]) < n and int(m["z"]) < n, "the site is inside the world (%d, %d)" % [int(m["x"]), int(m["z"])])
	ok(GameWorldMap.kind_at(d, m["cell"].x, m["cell"].y) != "water", "and never under water")
	ok(JSON.stringify(GameWorldMap.trial_markers(d)) == JSON.stringify(ms), "the same seed gives the same site")
	for other in GameTrials.placed_all(d.seed_value):
		if str(other["realm"]) != "material":
			ok(GameWorldMap.trial_markers(d).all(func(x): return str(x["id"]) != str(other["id"])), "a trial of another realm is not on this map")
			break
	d.heir.trials_done.append(id)
	ok(bool(GameWorldMap.trial_markers(d)[0]["passed"]), "a passed trial is marked passed")
	ok(GameWorldMap.trial_lines(d, 4)[0].contains(str(GameTrials.trial(id)["name"])) and GameWorldMap.trial_lines(d, 4)[0].contains(GameWorldMap.text("trial_passed")), "and listed by name: %s" % GameWorldMap.trial_lines(d, 4)[0])
	var all_found := _fresh()
	all_found.trials["steps"] = {}
	for p in placed:
		all_found.trials["steps"][str(p["id"])] = 1
	ok(GameWorldMap.trial_markers(all_found).size() == placed.size(), "every found trial has a marker")
	ok(GameWorldMap.trial_lines(all_found, 1).size() == (2 if placed.size() > 1 else 1), "a long list is cut with a count of the rest")
	var old := _fresh()
	old.trials = {}
	ok(GameWorldMap.trial_markers(old).is_empty(), "a save with no trial state shows none")


func test_image() -> void:
	var d := _fresh()
	var img := WorldMapPanel.make_image(d)
	var n := GameWorldMap.cells()
	ok(img.get_width() == n and img.get_height() == n, "one pixel a cell")
	var colors: Dictionary = GameSandbox.data()["tiles"]["colors"]
	var ok_all := true
	for cz in [0, n / 3, n / 2, n - 1]:
		for cx in [0, n / 3, n / 2, n - 1]:
			var c: Array = colors[GameWorldMap.kind_at(d, cx, cz)]
			var want := Color(float(c[0]), float(c[1]), float(c[2]))
			var got := img.get_pixel(cx, cz)
			if absf(got.r - want.r) > 0.01 or absf(got.g - want.g) > 0.01 or absf(got.b - want.b) > 0.01:
				ok_all = false
	ok(ok_all, "each pixel is the tile view's colour for its kind")


func test_panel() -> void:
	var d := _fresh()
	var panel: Control = WorldMapPanel.new()
	panel.dynasty = d
	panel.heir_tile = Vector2i(160, 288)
	root.add_child(panel)
	await process_frame
	await process_frame
	ok(panel.has_meta("modal"), "the panel is modal (the world waits)")
	ok(panel.find_child("Canvas", true, false) != null and panel.find_child("Close", true, false) != null, "it has the picture and a Close button")
	ok((panel.find_child("HereLine", true, false) as Label).text.contains("Hearthmere"), "it says where the family is")
	ok(panel.find_child("HeirLine", true, false) != null and (panel.find_child("HeirLine", true, false) as Label).text.contains("160"), "and where the heir stands")
	ok(panel.find_child("Trials", true, false) != null and (panel.find_child("Trials", true, false) as Label).text.contains(GameWorldMap.text("trial_none")), "it lists the trials found, none at first")
	panel.canvas.queue_redraw()
	await process_frame
	(panel.find_child("Close", true, false) as Button).pressed.emit()
	await process_frame
	await process_frame
	ok(not is_instance_valid(panel) or panel.is_queued_for_deletion(), "Close closes it")
	var bare: Control = WorldMapPanel.new()
	bare.dynasty = d
	root.add_child(bare)
	await process_frame
	ok(bare.find_child("HeirLine", true, false) == null, "with no heir tile (indoors) no heir line")
	bare.queue_free()
	await process_frame


func test_town_card() -> void:
	var d := _fresh()
	d.heir.gold = 3
	var sb := GameSandbox.start(d)
	sb.creatures.clear()
	var panel: Control = WorldMapPanel.new()
	panel.dynasty = d
	panel.sb = sb
	panel.heir_tile = sb.heir
	root.add_child(panel)
	await process_frame
	await process_frame
	var towns: Array = panel.find_child("Towns", true, false).get_children()
	ok(towns.size() == 4, "a key for each of the four towns")
	ok(panel.find_child("CardNone", true, false) != null and panel.find_child("CardTitle", true, false) == null, "no town selected: the card says to select one")
	ok(panel.find_child("Legend", true, false) != null and (panel.find_child("Legend", true, false) as Label).text.contains("castle"), "the legend explains the house and the castle")
	# a click on a marker selects it
	var canvas: Control = panel.canvas
	canvas.size = Vector2(640, 640)
	var k: Dictionary = GameWorldMap.markers(d).filter(func(m): return m["id"] == "kingshold")[0]
	var at: Vector2 = (Vector2(k["cell"]) + Vector2(0.5, 0.5)) * (canvas.size / float(GameWorldMap.cells()))
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at + Vector2(3, 2)
	canvas._gui_input(ev)
	ok(panel.selected == "kingshold", "a click on Kingshold's marker selects it")
	ok(str(canvas._get_tooltip(at)).contains("Kingshold") and str(canvas._get_tooltip(at)).contains("tiles"), "and the marker's tooltip names it and says how far: %s" % str(canvas._get_tooltip(at)).replace("\n", " / "))
	ok(canvas._get_tooltip(Vector2(5, 5)) == "", "bare sea says nothing")
	var wild: Dictionary = GameWorldMap.markers(d).filter(func(m): return m["kind"] == "wilds")[0]
	var wp: Vector2 = (Vector2(wild["cell"]) + Vector2(0.5, 0.5)) * (canvas.size / float(GameWorldMap.cells()))
	ev.position = wp
	canvas._gui_input(ev)
	ok(panel.selected == "kingshold", "the wilds cannot be selected")
	var title := panel.find_child("CardTitle", true, false) as Label
	ok(title != null and title.text == "Kingshold (City)", "the card names it and what it is: %s" % (title.text if title != null else ""))
	ok((panel.find_child("CardDistance", true, false) as Label).text.contains("tiles") and (panel.find_child("CardFare", true, false) as Label).text.contains("gold"), "with the distance, direction and fare")
	var pin := panel.find_child("PinButton", true, false) as Button
	var walk := panel.find_child("WalkButton", true, false) as Button
	var book := panel.find_child("BookButton", true, false) as Button
	ok(pin != null and walk != null and book != null and pin.text == "Pin it" and walk.text == "Walk there" and book.text == "Book travel", "three keys: Pin it, Walk there, Book travel")
	ok(book.disabled and panel.find_child("Reason", true, false) != null and (panel.find_child("Reason", true, false) as Label).text.contains("gold"), "with 3 gold, Book travel is shut and the reason is text under the keys: %s" % (panel.find_child("Reason", true, false) as Label).text)
	ok(not pin.disabled and not walk.disabled, "pinning and walking cost nothing")
	pin.pressed.emit()
	await process_frame
	ok(GameTravel.pin_place(d) == "kingshold", "Pin it pins the town")
	ok((panel.find_child("PinButton", true, false) as Button).text == "Unpin", "and the key becomes Unpin")
	(panel.find_child("PinButton", true, false) as Button).pressed.emit()
	await process_frame
	ok(not GameTravel.has_pin(d) and (panel.find_child("PinButton", true, false) as Button).text == "Pin it", "Unpin takes it off again")
	# a key row button selects too (the keyboard and gamepad reach it)
	(panel.find_child("Town_ironford", true, false) as Button).pressed.emit()
	await process_frame
	ok(panel.selected == "ironford" and (panel.find_child("CardTitle", true, false) as Label).text == "Ironford (Town)", "a town's key selects it")
	# in the town itself
	var here: Dictionary = GameWorldMap.markers(d).filter(func(m): return m["here"])[0]
	panel.select(str(here["id"]))
	await process_frame
	ok((panel.find_child("BookButton", true, false) as Button).disabled and (panel.find_child("WalkButton", true, false) as Button).disabled, "the town the heir stands in cannot be walked or booked to")
	ok((panel.find_child("CardDistance", true, false) as Label).text.contains("stands in"), "and its card says the heir is there")
	panel.canvas.queue_redraw()
	await process_frame
	panel.queue_free()
	await process_frame


func test_travel_from_the_map() -> void:
	var d := _fresh()
	d.heir.gold = 1000
	var app := FakeApp.new()
	app.dynasty = d
	root.add_child(app)
	var scr: Control = load("res://ui/play/sandbox_screen.gd").new()
	scr.app = app
	scr.size = Vector2(1280, 720)
	root.add_child(scr)
	await process_frame
	await process_frame
	scr.sb.creatures.clear()
	scr._open_world_map()
	await process_frame
	var panel: Control = null
	for c in scr.get_children():
		if c.get_script() == WorldMapPanel and not c.is_queued_for_deletion():
			panel = c
	ok(panel != null and panel.sb == scr.sb, "the screen hands the panel the open world")
	panel.select("kingshold")
	await process_frame
	(panel.find_child("PinButton", true, false) as Button).pressed.emit()
	await process_frame
	ok(GameTravel.pin_place(d) == "kingshold", "Pin it in the screen's map pins")
	ok(is_instance_valid(panel) and not panel.is_queued_for_deletion(), "pinning leaves the map open")
	scr._refresh_status()
	await process_frame
	var has_status_pane := false
	for c in scr.get_children():
		if c.get_script() == load("res://ui/play/status_pane.gd") and not c.is_queued_for_deletion():
			has_status_pane = true
	ok(scr._pin_line().contains("Pin: Kingshold") != has_status_pane, "the pin is said by the status pane when it is up, else by the bar's line: %s" % scr._pin_line())
	# book to Ironford from Hearthmere
	panel.select("ironford")
	await process_frame
	var fare := GameTravel.fare(d, scr.sb.heir, "ironford")
	var gold := d.heir.gold
	(panel.find_child("BookButton", true, false) as Button).pressed.emit()
	await process_frame
	await process_frame
	ok(d.heir.gold == gold - fare and GameTravel.town_at(scr.sb.heir.x, scr.sb.heir.y) == "ironford", "Book travel takes the fare and puts the heir in Ironford")
	ok(not scr._modal_open(), "and closes the map (the world goes on)")
	ok(scr.last_line.contains("Ironford") and scr.last_line.contains(str(fare)), "the status says so: %s" % scr.last_line)
	ok(GameTravel.pin_place(d) == "kingshold", "the pin on another town stays")
	# walk to Kingshold: the pin is there, a route starts, and a key press ends it
	scr._open_world_map()
	await process_frame
	for c in scr.get_children():
		if c.get_script() == WorldMapPanel and not c.is_queued_for_deletion():
			panel = c
	panel.select("kingshold")
	await process_frame
	(panel.find_child("WalkButton", true, false) as Button).pressed.emit()
	await process_frame
	await process_frame
	ok(not scr._modal_open() and scr.sb.walk_goal == GameTravel.anchor_tile("kingshold") and not scr.sb.route.is_empty(), "Walk there closes the map and starts the walk")
	var said := false
	for e in scr.sb.log:
		if str(e["text"]) == GameWorldMap.text("walk_start", {"heir": d.heir.name, "name": "Kingshold", "tiles": GameTravel.tiles(scr.sb.heir, GameTravel.anchor_tile("kingshold")), "dir": GameTravel.compass(scr.sb.heir, GameTravel.anchor_tile("kingshold"))}):
			said = true
	ok(said, "saying so in the log")
	scr.sb.cancel_walk()
	ok(scr.sb.route.is_empty() and scr.sb.walk_goal == GameTravel.NONE, "(a key, a stick or a click does the same through cancel_walk)")
	scr.queue_free()
	app.queue_free()
	await process_frame


func test_screen() -> void:
	var d := _fresh()
	var app := FakeApp.new()
	app.dynasty = d
	root.add_child(app)
	var scr: Control = load("res://ui/play/sandbox_screen.gd").new()
	scr.app = app
	scr.size = Vector2(1280, 720)
	root.add_child(scr)
	await process_frame
	await process_frame
	scr.sb.creatures.clear()
	ok(scr.slots.has("map"), "the bar has a Map button")
	ok(not scr._modal_open(), "(no panel open)")
	scr.slots["map"].pressed.call()
	await process_frame
	ok(scr._modal_open(), "pressing it opens the world map")
	var tick: int = scr.sb.tick
	for i in 40:
		await process_frame
	ok(scr.sb.tick == tick, "and the world waits while it is open")
	for c in scr.get_children():
		if c.has_meta("modal"):
			c.queue_free()
	await process_frame
	await process_frame
	ok(not scr._modal_open(), "closing it gives the world back")
	scr.queue_free()
	app.queue_free()
