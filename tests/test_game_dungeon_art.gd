## Dungeon looks (data/world/dungeon_themes.json; GameDungeonArt, DungeonView, DungeonEntranceArt): every dungeon has a theme of its
## own (palette, floor, wall, door, props, light, entrance), the props are placed from the id alone and never cut the floor in two,
## the dark closes in round the heir and lights give it back, the entrance is drawn at the door, and the tile view draws a
## dungeon in its theme.
## Run: godot --headless --path . -s res://tests/test_game_dungeon_art.gd
extends SceneTree

var fails := 0
var checks := 0


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
	test_themes_differ()
	test_props()
	test_light()
	test_entrance()
	test_view()
	test_breaks()
	print("dungeon art tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _places() -> Array:
	return GameDungeons.dungeon_ids()


func test_data() -> void:
	ok(GameDungeonArt.validate().is_empty(), "the themes validate: %s" % str(GameDungeonArt.validate()))
	ok(DungeonEntranceArt.validate().is_empty(), "the entrances validate: %s" % str(DungeonEntranceArt.validate()))
	ok(_places().size() == 6, "world.json has six dungeons")
	for p in _places():
		ok(GameDungeonArt.theme_id(p) != "" and GameDungeonArt.theme("world/" + p) == GameDungeonArt.theme(p), "%s has a theme, by place or space id" % p)
	ok(GameDungeonArt.theme("world/hearthmere/forge").is_empty() and GameDungeonArt.theme_id("nowhere") == "", "a town's forge and nowhere have none")


func test_themes_differ() -> void:
	var seen := {}
	var floors := {}
	var walls := {}
	var doors := {}
	var entrances := {}
	for p in _places():
		var t := GameDungeonArt.theme(p)
		seen[GameDungeonArt.theme_id(p)] = true
		floors[str(t["glyphs"]["floor_a"])] = true
		walls[str(t["glyphs"]["wall_face"])] = true
		doors[str(t["glyphs"]["door"])] = true
		entrances[str(t["entrance"]["rows"])] = true
	ok(seen.size() == 6 and floors.size() == 6 and walls.size() == 6 and doors.size() == 6 and entrances.size() == 6, "six dungeons, six themes, floors, walls, doors and entrances")
	var props := {}
	for p in _places():
		var sig := {}
		for k in GameDungeonArt.props("world/" + p):
			sig[GameDungeonArt.props("world/" + p)[k]] = true
		var names: Array = sig.keys()
		names.sort()
		props[str(names)] = true
		ok(sig.size() >= 4, "%s has at least four kinds of prop: %s" % [p, str(names)])
	ok(props.size() == 6, "and no two dungeons have the same set")
	var lights := {}
	for p in _places():
		lights[str(GameDungeonArt.theme(p)["light"])] = true
	ok(lights.size() >= 5, "the lighting differs from dungeon to dungeon")


func test_props() -> void:
	for p in _places():
		var id: String = "world/" + str(p)
		var cells := GameInterior.cells(id)
		var a := GameDungeonArt.props(id)
		GameDungeonArt._props.clear()
		var b := GameDungeonArt.props(id)
		ok(a == b and a.size() >= 8, "%s: the same props every time from the id alone (%d)" % [p, a.size()])
		var bad := 0
		var near_exit := 0
		var th := GameDungeonArt.theme(id)
		for k in a:
			var def: Dictionary = th["propdefs"][a[k]]
			var kind := str(cells.get(k, ""))
			if bool(def.get("on_wall", false)):
				if kind != "wall":
					bad += 1
			elif kind != "floor":
				bad += 1
			var pt := GameInterior._parse(k)
			if kind == "floor" and maxi(absi(pt.x), absi(pt.y)) <= 1:
				near_exit += 1
		ok(bad == 0, "%s: floor props on floor, wall props on walls" % p)
		ok(near_exit == 0, "%s: nothing stands on the way in" % p)
		var walk := GameDungeons.walk_cells(id)
		var solid := {}
		for k in walk:
			if walk[k] == "prop":
				solid[k] = true
		ok(solid.size() >= 5 and GameDungeons.still_connected(cells, solid), "%s: %d solid things and every other cell can still be reached" % [p, solid.size()])
		var reach := GameInterior.reachable(walk).size()
		var open := 0
		for k in walk:
			if walk[k] in GameInterior.WALKABLE:
				open += 1
		ok(reach == open, "%s: the sandbox's cells are all reached from the way in" % p)
		# a chest can be stood beside from a reachable cell
		for c in GameDungeons.layout(id)["containers"]:
			var beside := false
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					if walk.get("%d,%d" % [int(c["x"]) + dx, int(c["z"]) + dz], "") in GameInterior.WALKABLE:
						beside = true
			ok(beside, "%s: the %s in %s has floor beside it" % [p, c["kind"], c["room"]])
	var warren := GameDungeonArt.floor_kind("world/goblin_warrens", 3, 4)
	var kinds := {}
	for x in 30:
		kinds[GameDungeonArt.floor_kind("world/goblin_warrens", x, 2)] = true
	ok(kinds.size() == 3 and warren == GameDungeonArt.floor_kind("world/goblin_warrens", 3, 4), "the floor has three looks by a hash of the tile, the same every time")


func test_light() -> void:
	for p in _places():
		var id: String = "world/" + str(p)
		var t := GameDungeonArt.theme(id)
		var dark := float(t["light"]["dark"])
		var near := GameDungeonArt.darkness(id, 0, 0, 0, 0)
		var far := GameDungeonArt.darkness(id, 200, 200, 0, 0)
		ok(near < 0.001 and absf(far - dark) < 0.001, "%s: no dark at the heir, the full dark far from them and from any light" % p)
		var mid := GameDungeonArt.darkness(id, 3, 0, 0, 0)
		ok(mid >= near and mid <= dark, "%s: the dark grows with the distance" % p)
		var ls := GameDungeonArt.lights(id)
		ok(not ls.is_empty(), "%s has light sources" % p)
		if not ls.is_empty():
			var s: Dictionary = ls[0]
			ok(GameDungeonArt.darkness(id, int(s["x"]), int(s["z"]), 90, 90) < dark - 0.05, "%s: a light source lightens the dark round it" % p)
	var dim := GameDungeonArt.darkness("world/the_rift", 4, 0, 0, 0)
	var bright := GameDungeonArt.darkness("world/emberpeak", 4, 0, 0, 0)
	ok(float(GameDungeonArt.theme("world/the_rift")["light"]["dark"]) > float(GameDungeonArt.theme("world/emberpeak")["light"]["dark"]), "the rift is darker than a volcano")
	ok(dim >= 0.0 and bright >= 0.0, "(darkness is never negative)")


func test_entrance() -> void:
	for p in _places():
		var r := GameDungeonArt.entrance_rect(p)
		var door: Dictionary = GameSpaces.space("world/" + p)["door"]
		ok(r.size == Vector2i(5, 3) and r.position == Vector2i(int(door["x"]) - 2, int(door["z"]) - 2), "%s: the entrance is 5 by 3 tiles with the door tile at the bottom middle" % p)
		var hits := GameDungeonArt.entrances_in(Rect2i(int(door["x"]) - 1, int(door["z"]) - 1, 3, 3))
		ok(hits.size() == 1 and hits[0]["place"] == p, "%s: found by the tiles it stands on" % p)
		var img := DungeonEntranceArt.image(p)
		ok(img.get_width() == 80 and img.get_height() == 48, "%s: 80 by 48 pixels" % p)
	ok(GameDungeonArt.entrances_in(Rect2i(0, 0, 3, 3)).is_empty(), "nothing at the world's corner")


func test_view() -> void:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	var v := TileView.new()
	v.setup(d)
	for p in _places():
		var id: String = "world/" + str(p)
		var walk := GameDungeons.walk_cells(id)
		v.set_interior(id, walk)
		ok(v.dungeon != null and v.interior_id == id, "%s: the tile view draws it as a dungeon" % p)
		var drawn := v.dungeon.ground.get_used_cells().size()
		ok(drawn == walk.size(), "%s: every cell has a ground tile (%d)" % [p, drawn])
		ok(v.dungeon.ground.get_cell_atlas_coords(Vector2i(0, 0)).x == v.dungeon.names.find("exit"), "%s: the way out is drawn as the theme's exit" % p)
		ok(v.dungeon.things.get_used_cells().size() >= 10, "%s: things stand over the ground" % p)
		var c: Dictionary = GameDungeons.layout(id)["containers"][0]
		var before := v.dungeon.things.get_cell_atlas_coords(Vector2i(int(c["x"]), int(c["z"]))).x
		GameDungeons.mark(d, "o", p, str(c["id"]))
		v.refresh_cell(int(c["x"]), int(c["z"]))
		var after := v.dungeon.things.get_cell_atlas_coords(Vector2i(int(c["x"]), int(c["z"]))).x
		ok(before == v.dungeon.names.find(str(c["kind"])) and after == v.dungeon.names.find(str(c["kind"]) + "_open"), "%s: an opened %s is drawn open" % [p, c["kind"]])
		d.dungeon_marks.clear()
	v.set_interior("world/hearthmere/forge", GameInterior.cells("world/hearthmere/forge"))
	ok(v.dungeon == null, "a town's forge is not drawn as a dungeon")
	v.set_interior("", {})
	ok(v.dungeon == null, "and going out drops it")
	v.free()


func test_breaks() -> void:
	# break check: a wall of solid things across a door must be seen as cutting the floor in two
	var id := "world/hollow_barrow"
	var cells := GameInterior.cells(id)
	var solid := {}
	for k in cells:
		if cells[k] == "door":
			solid[k] = true
	ok(not GameDungeons.still_connected(cells, solid), "break check: blocking every door is seen as cutting the floor in two")
	ok(GameDungeons.still_connected(cells, {}), "and blocking nothing is not")
	var bad := GameDungeonArt.data().duplicate(true)
	bad["themes"]["warren"]["glyphs"]["floor_a"][0] = "bbb"
	var keep := GameDungeonArt._cache
	GameDungeonArt._cache = bad
	ok(not GameDungeonArt.validate().is_empty(), "break check: a glyph row of the wrong width is refused")
	GameDungeonArt._cache = keep
	var bad2 := GameDungeonArt.data().duplicate(true)
	bad2["themes"]["rift"]["ambient"].append({"prop": "ghost", "chance": 0.1, "where": "floor"})
	GameDungeonArt._cache = bad2
	ok(not GameDungeonArt.validate().is_empty(), "break check: an ambient rule for a prop that is not defined is refused")
	GameDungeonArt._cache = keep
	ok(GameDungeonArt.validate().is_empty(), "(and the real data is whole again)")
