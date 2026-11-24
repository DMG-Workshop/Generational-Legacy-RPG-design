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
