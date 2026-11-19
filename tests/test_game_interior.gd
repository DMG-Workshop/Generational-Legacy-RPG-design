## Walking into interiors (roadmap item 41): the floor of every interior as cells (rooms as floor, doors between them, the
## way out at the origin, walls round it all) and that all of it can be reached from the way in; the sandbox's door, in and out
## by Use, and what stops indoors (routes, digging, building, climbing, the open world's creatures, the saved place); the tile
## view drawing an interior and the screen following the sandbox into it.
## Run: godot --headless --path . -s res://tests/test_game_interior.gd
extends SceneTree

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
	test_cells()
	test_every_interior()
	test_sandbox()
	test_indoors_rules()
	test_tile_view()
	await test_screen()
	print("interior tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _interiors() -> Array:
	var out: Array = []
	for id in GameSpaces.ids():
		if GameSpaces.kind(id) == "interior":
			out.append(id)
	return out


func _sandbox() -> GameSandbox:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 500
	return GameSandbox.start(d)


func _door(id: String) -> Vector2i:
	var door: Dictionary = GameSpaces.space(id)["door"]
	return Vector2i(int(door["x"]), int(door["z"]))


func test_cells() -> void:
	var forge := "world/hearthmere/forge"
	var g := GameInterior.cells(forge)
	var n := {"floor": 0, "door": 0, "exit": 0, "wall": 0, "person": 0}
	for k in g:
		n[g[k]] += 1
	ok(n["floor"] + n["exit"] + n["person"] == 32 and n["door"] == 2 and n["exit"] == 1 and n["person"] == 1, "the forge's rooms are 32 tiles of floor (one the way out, one with the smith on it) and 2 doors: %s" % str(n))
	ok(g["0,0"] == "exit", "the way out is the origin")
	ok(g["2,0"] == "door" and g["0,2"] == "door", "the doors are where the layout says")
	ok(g["-3,-2"] == "wall" and g["-3,0"] == "wall", "walls stand round the floor")
	ok(not g.has("-9,-9"), "and nothing is drawn further out")
	ok(GameInterior.passable(g, 0, 0) and GameInterior.passable(g, 2, 0) and GameInterior.passable(g, 1, 1), "floor, doors and the way out can be stood on")
	ok(not GameInterior.passable(g, -3, 0) and not GameInterior.passable(g, 50, 50), "walls and nowhere cannot")
	ok(GameInterior.cells("world").is_empty() and GameInterior.cells("world/hearthmere").is_empty() and GameInterior.cells("nowhere").is_empty(), "the open world, an area and nothing are not interiors")
	ok(GameInterior.cells(forge) == GameInterior.cells(forge), "it is the same every time")
	ok(GameInterior.room_at(forge, 4, 0) == "smithy" and GameInterior.room_at(forge, 2, 0) == "", "a tile's room is the layout's; a door is in none")


func test_every_interior() -> void:
	var all := _interiors()
	ok(all.size() >= 20, "there are interiors to check: %d" % all.size())
	var bad := 0
	for id in all:
		var g := GameInterior.cells(id)
		var walkable := 0
		var open_edge := false
		for k in g:
			var kind: String = g[k]
			if kind in GameInterior.WALKABLE:
				walkable += 1
				var p := GameInterior._parse(k)
				for a in GameInterior.AROUND:
					if not g.has(GameInterior.key(p.x + a.x, p.y + a.y)):
						open_edge = true
		var reach := GameInterior.reachable(g).size()
		if g.is_empty() or g["0,0"] != "exit" or reach != walkable or open_edge:
			bad += 1
			print("  bad interior ", id, ": cells ", g.size(), ", walkable ", walkable, ", reached ", reach, ", open edge ", open_edge, ", origin ", g.get("0,0", "-"))
	ok(bad == 0, "every interior has its way out at the origin, can be walked across all of it and is walled in")
	var seen := {}
	var clash := 0
	for id in all:
		var t := _door(id)
		if seen.has(t):
			clash += 1
		seen[t] = id
	ok(clash == 0, "no two interiors share a door tile on the open world")


func test_sandbox() -> void:
	var forge := "world/hearthmere/forge"
	var s := _sandbox()
	ok(s.space == "world" and s.door_here() == "", "a visit starts on the open world, not at a door")
	ok(not s.enter()["ok"] and s.enter()["text"].contains("no door"), "no going in where there is no door: %s" % s.enter()["text"])
	s.heir = _door(forge)
	ok(s.door_here() == forge, "at the forge's door the sandbox knows it")
	var door_tile := s.heir
	var r := s.use()
	ok(r["ok"] and s.space == forge and s.heir == Vector2i.ZERO and s.outside == door_tile, "Use goes in: the heir is at the way out of the floor and remembers the door: %s" % r["text"])
	ok(not s.interior.is_empty() and s.log.back()["text"].contains("forge"), "and the floor is held and the log says where: %s" % s.log.back()["text"])
	ok(s.place_line().to_lower().contains("forge") and s.place_line().to_lower().contains("yard"), "the place line says where and in which room: %s" % s.place_line())
	var moved := 0
	for dir in [Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 0)]:
		if s.move(dir.x, dir.y)["ok"]:
			moved += 1
	ok(moved == 3 and s.heir == Vector2i(3, 0), "the heir walks across the yard and through the door into the smithy: %s" % str(s.heir))
	ok(s.place_line().to_lower().contains("smithy"), "and the room changes: %s" % s.place_line())
	var wall := s.can_step(0, -3)
	ok(not wall["ok"], "a wall stops the heir")
	s.heir = Vector2i(1, 1)
	ok(not s.can_step(1, -1)["ok"] and s.can_step(0, -1)["ok"], "and a diagonal past a wall corner is refused (no cutting a corner): %s" % s.can_step(1, -1)["why"])
	s.heir = Vector2i(3, 0)
	var out := s.use()
	ok(not out["ok"] and s.space == forge and out["text"].contains("way out"), "Use away from the way out does not leave: %s" % out["text"])
	for i in 3:
		s.move(-1, 0)
	ok(s.heir == Vector2i.ZERO, "back at the way out")
	var back := s.use()
	ok(back["ok"] and s.space == "world" and s.heir == door_tile and s.interior.is_empty(), "Use there goes out, to the door on the open world: %s" % back["text"])
	ok(s.log.back()["text"].contains("outside"), "and the log says so")
	var all_ok := true
	for id in _interiors():
		var t := _sandbox()
		t.heir = _door(id)
		if not t.use()["ok"] or t.space != id or t.heir != Vector2i.ZERO or not t.use()["ok"] or t.heir != _door(id):
			all_ok = false
			print("  cannot go in and out of ", id)
	ok(all_ok, "every interior can be gone into and out of by its door")


func test_indoors_rules() -> void:
	var s := _sandbox()
	s.heir = _door("world/hearthmere/forge")
	var saved_before := s.d.sandbox_at.duplicate()
	s.use()
	ok(not s.set_route(Vector2i(1, 1))["ok"] and s.route.is_empty(), "no routes indoors")
	ok(not s.dig(0)["ok"], "no digging indoors")
	ok(s.build_check("wall", 1, 0) != "" and not s.build("wall", 1, 0)["ok"] and not s.remove_at(1, 0)["ok"], "no building or taking down indoors")
	ok(not s.climb(-1)["ok"], "no stairs indoors")
	if s.creatures.is_empty():   # (a town's own ground has none: put one out there to wait)
		s.creatures.append(GameBehaviour.new_agent(900, "wolf", float(s.heir.x) + 30.5, float(s.heir.y) + 0.5, 20))
	var before: Array = s.creatures.map(func(a): return [a["x"], a["z"], a["mode"]])
	ok(before.size() > 0, "(there are creatures out there to wait)")
	var tick := s.tick
	s.step(5)
	var after: Array = s.creatures.map(func(a): return [a["x"], a["z"], a["mode"]])
	ok(s.tick == tick + 5 and after == before, "time passes but the open world's creatures wait where they were")
	s.remember()
	ok(s.d.sandbox_at == saved_before, "the saved place is not moved indoors")
	s.use()
	var up := _sandbox()
	up.heir = _door("world/hearthmere/forge")
	up.heir_y = -2
	ok(up.door_here() == "" and not up.use()["ok"], "no going in by a door from upstairs")


func test_tile_view() -> void:
	var forge := "world/hearthmere/forge"
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	var v := TileView.new()
	v.setup(d)
	v.show_view(Vector2(0, 0), Vector2(8, 6))
	var world_chunks := v.layers.size()
	ok(world_chunks > 0 and v.interior_id == "", "the view starts on the open world")
	var g := GameInterior.cells(forge)
	v.set_level(1)
	ok(v.level == 1 and not v.uppers.is_empty(), "(a storey is shown on the open world)")
	v.set_interior(forge, g)
	ok(v.layers.is_empty() and v.interior_id == forge, "going into an interior drops the world's tiles")
	ok(v.uppers.is_empty() and v.level == 0, "and its storey layers, and the storey")
	v.set_level(2)
	ok(v.level == 0 and v.uppers.is_empty(), "an interior has one floor: no storey can be shown in it")
	v.show_view(Vector2(0, 0), Vector2(8, 6))
	var c := TileView.chunk_of(0, 0)
	var n: int = TileView.settings()["chunk"]
	var layer: TileMapLayer = v.layers[c]
	var kinds := TileView.kinds()
	ok(layer.get_cell_atlas_coords(Vector2i(0 - c.x * n, 0 - c.y * n)).x == kinds.find("exit"), "the way out is drawn as the way out")
	ok(layer.get_cell_atlas_coords(Vector2i(1 - c.x * n, 0 - c.y * n)).x == kinds.find("floor"), "floor as floor")
	ok(layer.get_cell_atlas_coords(Vector2i(2 - c.x * n, 0 - c.y * n)).x == kinds.find("door"), "a door as a door")
	var wc := TileView.chunk_of(-3, 0)
	ok((v.layers[wc] as TileMapLayer).get_cell_atlas_coords(Vector2i(-3 - wc.x * n, 0 - wc.y * n)).x == kinds.find("wall"), "a wall as a wall")
	ok(layer.get_cell_source_id(Vector2i(20 - c.x * n, 0 - c.y * n)) == -1, "and nothing where the interior has no cell")
	var fills := v.fills
	v.set_interior(forge, g)
	v.show_view(Vector2(0, 0), Vector2(8, 6))
	ok(v.fills == fills, "setting the same interior again draws nothing more")
	v.set_interior("", {})
	v.show_view(Vector2(0, 0), Vector2(8, 6))
	ok(v.interior_id == "" and v.layers.size() == world_chunks, "coming out draws the open world again")
	ok(TileView.validate().is_empty() and TileView.kinds().has("exit"), "the tile data has a colour for the way out")
	v.free()


func test_screen() -> void:
	var forge := "world/hearthmere/forge"
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	var app := FakeApp.new()
	app.dynasty = d
	root.add_child(app)
	var scr: Control = load("res://ui/play/sandbox_screen.gd").new()
	scr.app = app
	scr.size = Vector2(1280, 720)
	root.add_child(scr)
	await process_frame
	await process_frame
	scr.sb.heir = Vector2i(int(GameSpaces.space(forge)["door"]["x"]), int(GameSpaces.space(forge)["door"]["z"]))
	scr._use()
	await process_frame
	await process_frame
	ok(scr.sb.space == forge and scr.tile_view.interior_id == forge, "the screen follows the sandbox into the interior")
	ok(scr.status.text.to_lower().contains("forge"), "and says where: %s" % scr.status.text)
	ok(scr.tile_view.modulate == Color(1, 1, 1), "it is always light indoors")
	scr._use()
	await process_frame
	await process_frame
	ok(scr.sb.space == "world" and scr.tile_view.interior_id == "", "and out again")
	scr.queue_free()
	app.queue_free()
