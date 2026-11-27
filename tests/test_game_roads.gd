## Roads, signposts and caravans of the open world (GameRoads, GameCaravans, GameRoadside, data/world/roads.json): the data is sound; a road is a
## strip of dry land along GameWorldGen's links, off a place's ground, and the land itself (tile, height, water, node) answers exactly as it did,
## with no die drawn; a road is a little quicker to walk; the sixteen trail glyphs and the signpost are drawn by the tile view; signposts stand on free
## dry tiles beside the road, outside each place and each town gate, name the places and their distances, and are read by Use and named by a click; a
## caravan walks each road between two towns on a schedule that is a pure function of the seed, the road and the hour, rests in the towns, and its Use
## opens the merchant's panel with wares that can be bought; nothing is saved.
## Run: godot --headless --path . -s res://tests/test_game_roads.gd
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
	test_land_unchanged()
	test_roads()
	test_pace()
	test_trails()
	test_posts()
	test_use()
	test_caravans()
	test_caravan_trade()
	test_view()
	print("roads tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh(seed_value: int = 7) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


## The first road tile on the straight road between two places, walking from the first toward the second.
func _road_tile(d: GameDynasty, a: String, b: String) -> Vector2i:
	var pa := GameWorldGen.anchor(a)
	var pb := GameWorldGen.anchor(b)
	var from := Vector2(float(pa["x"]), float(pa["z"]))
	var to := Vector2(float(pb["x"]), float(pb["z"]))
	var n := int(from.distance_to(to))
	for i in range(0, n):
		var p := from.lerp(to, float(i) / float(n))
		var t := Vector2i(int(round(p.x)), int(round(p.y)))
		if GameRoads.on_road(d, t.x, t.y):
			return t
	return Vector2i(-1, -1)


func test_data() -> void:
	ok(GameRoads.validate().is_empty(), "the roads data is valid: %s" % str(GameRoads.validate()))
	ok(GameRoads.links().size() == GameWorldGen.roads().size() and GameRoads.links().size() > 10, "a link for each road of the world (%d)" % GameRoads.links().size())
	for i in GameRoads.links().size():
		var l: Dictionary = GameRoads.links()[i]
		var r: Array = GameWorldGen.roads()[i]
		ok(is_equal_approx(float(l["ax"]), float(r[0])) and is_equal_approx(float(l["bz"]), float(r[3])), "link %d is road %d" % [i, i])
	var keep: float = GameRoads.data()["settings"]["pace"]
	GameRoads.data()["settings"]["pace"] = 1.4
	ok(not GameRoads.validate().is_empty(), "a road that is slower than the open ground is caught")
	GameRoads.data()["settings"]["pace"] = keep
	var rows: Array = GameRoads.data()["glyphs"]["signpost"]["rows"]
	var row0: Variant = rows[0]
	rows[0] = "..sss"
	ok(not GameRoads.validate().is_empty(), "a signpost row of the wrong width is caught")
	rows[0] = row0
	ok(GameRoads.validate().is_empty(), "and mending the data clears it")
	var kinds := TileView.kinds()
	for id in GameRoads.glyph_ids():
		ok(kinds.has(id), "'%s' is a kind of the tile view" % id)
	ok(GameRoads.glyph_ids().size() == 17, "sixteen trails and the signpost")
	ok(TileView.validate().is_empty(), "and the tile view's data holds: %s" % str(TileView.validate()))


## Nothing about the land changes: the same tile, height, water and node as before, and no die of the dynasty's.
func test_land_unchanged() -> void:
	var d := _fresh()
	var probe: Array = []
	for i in 80:
		probe.append(Vector2i(60 + i * 6, 40 + (i * 53) % 560))
	var snap := func() -> String:
		var out: Array = []
		for p in probe:
			var t := GameWorldGen.tile(d, p.x, p.y)
			out.append([t["biome"], t["height"], t["water"], t["body"], t["node"]])
		return JSON.stringify(out)
	var before: String = snap.call()
	var rng := d.rng.state
	for p in probe:
		GameRoads.on_road(d, p.x, p.y)
		GameRoads.trail_at(d, p.x, p.y)
	GameRoads.posts(d)
	GameCaravans.out(d)
	ok(snap.call() == before, "the land answers as it did after the roads were asked")
	ok(d.rng.state == rng, "no die of the dynasty's is drawn")
	ok(JSON.stringify(d.to_dict()).find("road") < 0 and JSON.stringify(d.to_dict()).find("caravan") < 0 and JSON.stringify(d.to_dict()).find("camp") < 0, "and nothing of it is saved")


func test_roads() -> void:
	var d := _fresh()
	var t := _road_tile(d, "ironford", "kingshold")
	ok(t.x >= 0, "there is a road tile on the road from Ironford to Kingshold")
	ok(GameRoads.on_road(d, t.x, t.y) and not GameWorldGen.water_at(d.seed_value, t.x, t.y), "on dry land")
	ok(not GameWorldGen.in_anchor_ground(t.x, t.y), "outside a place's ground")
	var anchor := GameWorldGen.anchor("ironford")
	ok(not GameRoads.on_road(d, int(anchor["x"]), int(anchor["z"])), "a town's own ground is no road")
	ok(not GameRoads.on_road(d, -5, 10) and not GameRoads.on_road(d, 3000, 3000), "nor is anything off the world")
	var wet := 0
	var wrong := 0
	var road_tiles := 0
	for l in GameRoads.links():
		var from := Vector2(float(l["ax"]), float(l["az"]))
		var to := Vector2(float(l["bx"]), float(l["bz"]))
		var n := int(from.distance_to(to))
		for i in range(0, n, 3):
			var p := from.lerp(to, float(i) / float(n))
			var x := int(round(p.x))
			var z := int(round(p.y))
			if GameRoads.on_road(d, x, z):
				road_tiles += 1
				if GameWorldGen.body_at(d.seed_value, x, z) != "":
					wet += 1
				if GameWorldGen.in_anchor_ground(x, z):
					wrong += 1
	ok(road_tiles > 400, "a long way of road all round the world (%d sampled tiles)" % road_tiles)
	ok(wet == 0 and wrong == 0, "no road tile is wet or on a place's ground")
	# tiles well away from every road are not road
	var far := 0
	for i in 60:
		var x := 20 + i * 10
		var z := 20 + (i * 37) % 600
		if GameWorldGen.road_distance(float(x), float(z)) > 3.0 and GameRoads.on_road(d, x, z):
			far += 1
	ok(far == 0, "bare ground away from the roads is not road")
	# the same for the same tile every time
	ok(GameRoads.on_road(d, t.x, t.y) == GameRoads.on_road(_fresh(), t.x, t.y), "a tile is road the same way for the same seed")


func test_pace() -> void:
	var d := _fresh()
	var t := _road_tile(d, "ironford", "kingshold")
	ok(is_equal_approx(GameRoads.pace_at(d, t.x, t.y), float(GameRoads.data()["settings"]["pace"])) and GameRoads.pace_at(d, t.x, t.y) < 1.0, "the road is quicker underfoot")
	ok(GameRoads.pace_at(d, 5, 5) == 1.0, "and the open ground is as it was")
	var s := GameSandbox.start(d)
	s.heir = t
	ok(GameRoads.pace_for(s) < 1.0, "the heir on the road takes less time to a step")
	s.heir_y = GameBuild.SURFACE - 1
	ok(GameRoads.pace_for(s) == 1.0, "but not upstairs")
	s.heir_y = GameBuild.SURFACE
	s.space = "somewhere"
	ok(GameRoads.pace_for(s) == 1.0, "nor indoors")


func test_trails() -> void:
	var d := _fresh()
	var t := _road_tile(d, "ironford", "kingshold")
	var m := GameRoads.mask_at(d, t.x, t.y)
	ok(GameRoads.trail_at(d, t.x, t.y) == "trail_%d" % m and m > 0, "a road tile on a long road has a neighbour on the road (mask %d)" % m)
	ok(GameRoads.trail_at(d, 5, 5) == "", "bare ground has no trail")
	for id in GameRoads.glyph_ids():
		if not id.begins_with("trail_"):
			continue
		var g: Dictionary = GameRoads.glyphs()[id]
		ok((g["rows"] as Array).size() == 8 and (g["rows"] as Array).all(func(r): return str(r).length() == 8), "%s is 8 by 8" % id)
		var solid := 0
		for r in g["rows"]:
			for ch in str(r):
				if ch != ".":
					solid += 1
		ok(solid >= 36, "%s is mostly path (%d of 64)" % [id, solid])
	# an end with no road beyond it is ragged on that side, a joined side is whole
	var rows: Array = GameRoads.glyphs()["trail_5"]["rows"]   # joined north and south
	ok(str(rows[0]).substr(1, 6).count(".") == 0 and str(rows[7]).substr(1, 6).count(".") == 0, "a trail joined north and south is whole at both ends")
	ok(str(rows[3]).substr(0, 1) != "a" or str(rows[4]).substr(0, 1) != "a" or str(rows[2]).substr(0, 1) != "a" or str(rows[5]).substr(0, 1) != "a", "and ragged at its sides")


func test_posts() -> void:
	var d := _fresh()
	var ps := GameRoads.posts(d)
	var kinds := {}
	for p in ps:
		kinds[p["kind"]] = int(kinds.get(p["kind"], 0)) + 1
	ok(int(kinds.get("end", 0)) >= GameRoads.links().size(), "a post at the end of every road out of a place (%d)" % int(kinds.get("end", 0)))
	ok(int(kinds.get("gate", 0)) >= GameWalls.all_gates().size() - 4, "and one outside nearly every town gate (%d of %d)" % [int(kinds.get("gate", 0)), GameWalls.all_gates().size()])
	var bad := 0
	var near_road := 0
	for p in ps:
		var x := int(p["x"])
		var z := int(p["z"])
		if GameWorldGen.body_at(d.seed_value, x, z) != "" or GameWorldGen.in_anchor_ground(x, z) or GameRoads.lane(x, z) or not GameWorldGen.tile(d, x, z)["node"].is_empty() or GameWalls.cleared(x, z):
			bad += 1
		if GameWorldGen.road_distance(float(x), float(z)) < 8.0 or str(p["kind"]) == "gate":
			near_road += 1
		ok((p["lines"] as Array).size() >= 2 and not str(p["here"]).is_empty(), "the post at %d,%d names places" % [x, z])
		for l in p["lines"]:
			if int(l["n"]) < 0 or str(l["place"]) == "":
				bad += 1
	ok(bad == 0, "every post stands on free dry ground off the road, and every line has a place and a distance")
	ok(near_road == ps.size(), "and every post is beside a road or a gate")
	var first: Dictionary = ps[0]
	ok(GameRoads.post_at(d, int(first["x"]), int(first["z"]))["id"] == first["id"], "a post is found by its tile")
	ok(GameRoads.post_at(d, 5, 5).is_empty(), "and bare ground has none")
	var read := GameRoads.read(first)
	var name_ok := false
	for l in first["lines"]:
		name_ok = name_ok or read.contains(str(l["place"])) and read.contains(str(l["n"]))
	ok(name_ok, "reading it names the places and how far: %s" % read)
	ok(GameRoads.name_of_post(first).begins_with(GameRoads.text("sign_name")), "a click names it")
	var mid := GameRoads.post_near(d, float(first["x"]) + 1.0, float(first["z"]) + 0.5, 2.0)
	ok(mid.get("id", "") == first["id"] and GameRoads.post_near(d, 5.5, 5.5, 2.0).is_empty(), "the post within reach is found")
	# the same for the same seed, in the same order
	GameRoads._posts_seed = -1
	var again := GameRoads.posts(d)
	ok(JSON.stringify(again) == JSON.stringify(ps), "the posts are the same when worked out again")
	# a crossing away from any place is a post of its own
	var made: Array = []
	var saved: Array = GameRoads._links.duplicate(true)
	GameRoads._links = [{"a": "hearthmere", "b": "ironford", "ax": 100.0, "az": 100.0, "bx": 200.0, "bz": 200.0, "length": 141.0},
		{"a": "kingshold", "b": "brinehaven", "ax": 200.0, "az": 100.0, "bx": 100.0, "bz": 200.0, "length": 141.0}]
	GameRoads._posts_seed = -1
	for p in GameRoads.posts(d):
		if str(p["kind"]) == "cross":
			made.append(p)
	GameRoads._links = saved
	GameRoads._posts_seed = -1
	GameRoads._lane_memo = {}
	ok(made.size() == 1 and (made[0]["lines"] as Array).size() == 4, "two roads crossing in the open make a crossroads post naming four places")


func test_use() -> void:
	var d := _fresh()
	var p: Dictionary = GameRoads.posts(d)[0]
	var s := GameSandbox.start(d)
	s.creatures.clear()
	s.heir = Vector2i(int(p["x"]), int(p["z"])) + Vector2i(1, 0)
	var named := s.name_at(float(p["x"]) + 0.5, float(p["z"]) + 0.5)
	ok(str(named.get("kind", "")) == "sign" and str(named["id"]) == str(p["id"]), "a click on a signpost names it")
	var acts := s.thing_actions(named)
	ok(acts.size() == 2 and str(acts[0]["id"]) == "use", "and the menu offers to go and read it")
	var r := s.use()
	ok(bool(r["ok"]) and str(r["text"]) == GameRoads.read(p), "Use beside it reads it")
	ok(str(s.log[-1]["text"]) == GameRoads.read(p), "and the journal keeps the words")
	s.heir = Vector2i(5, 5)
	ok(s.name_at(5.5, 5.5).is_empty() or str(s.name_at(5.5, 5.5).get("kind", "")) != "sign", "far from any post there is none to name")
	var far := s.use()
	ok(not bool(far["ok"]) or not str(far["text"]).contains("signpost"), "and nothing to read")


func test_caravans() -> void:
	var d := _fresh()
	var routes := GameCaravans.routes()
	ok(routes.size() >= 2, "a caravan on each road between two towns (%d)" % routes.size())
	for i in routes:
		var l: Dictionary = GameRoads.links()[int(i)]
		ok(str(GameWorldGen.anchor(str(l["a"]))["type"]) == "town" and str(GameWorldGen.anchor(str(l["b"]))["type"]) == "town", "road %d joins two towns" % int(i))
	var i0 := int(routes[0])
	var l0: Dictionary = GameRoads.links()[i0]
	# pure of the seed, the road and the hour
	for h in [0.0, 7.5, 31.0, 100.0]:
		ok(JSON.stringify(GameCaravans.state(d, i0, h)) == JSON.stringify(GameCaravans.state(_fresh(), i0, h)), "the same hour shows the same wagon (%.1f)" % h)
	var rng := d.rng.state
	GameCaravans.out(d)
	ok(d.rng.state == rng, "asking draws no die of the dynasty's")
	# the wagon is on the road between the two towns
	var on_line := true
	var moved := 0.0
	var prev: Dictionary = {}
	var walking := 0
	var resting := 0
	var cycle := GameCaravans.cycle_hours(l0)
	var h := 0.0
	while h < cycle * 1.01:
		var st := GameCaravans.state(d, i0, h)
		var pos := Vector2(float(st["x"]) - 0.5, float(st["z"]) - 0.5)
		var a := Vector2(float(l0["ax"]), float(l0["az"]))
		var b := Vector2(float(l0["bx"]), float(l0["bz"]))
		if GameRoads._line_distance(l0, pos) > 0.01:
			on_line = false
		if bool(st["on_road"]):
			walking += 1
			if not prev.is_empty() and bool(prev["on_road"]) and str(prev["from"]) == str(st["from"]):
				moved = maxf(moved, Vector2(float(st["x"]), float(st["z"])).distance_to(Vector2(float(prev["x"]), float(prev["z"]))))
		else:
			resting += 1
			ok(pos.distance_to(a) < 0.01 or pos.distance_to(b) < 0.01, "a resting caravan is at one of the towns")
		prev = st
		h += 0.5
	ok(on_line, "the wagon is always on the line of the road")
	ok(walking > 0 and resting > 0, "it walks and it rests (%d half-hours walking, %d resting)" % [walking, resting])
	ok(moved <= float(GameCaravans.setting("tiles_per_hour")) * 0.5 + 0.01 and moved > 0.0, "at the speed of the data (%.2f tiles a half hour)" % moved)
	ok(is_equal_approx(fposmod(GameCaravans.clock_at(d, i0, 5.0 + cycle), cycle), fposmod(GameCaravans.clock_at(d, i0, 5.0), cycle)), "a round repeats")
	# only the ones out in the open are drawn
	for st in GameCaravans.out(d):
		ok(bool(st["on_road"]) and GameCaravans.out_in_the_open(st), "a drawn wagon is out on the road, not in a town")
	var any_out := false
	for k in 40:
		d.world_seconds = float(k) * 25.0
		if not GameCaravans.out(d).is_empty():
			any_out = true
	ok(any_out, "some time of the world shows a caravan out")


func test_caravan_trade() -> void:
	var d := _fresh()
	var found := {}
	for k in 120:
		d.world_seconds = float(k) * 13.0
		var out := GameCaravans.out(d)
		if not out.is_empty():
			found = out[0]
			break
	ok(not found.is_empty(), "a caravan is out to meet")
	var s := GameSandbox.start(d)
	s.creatures.clear()
	s.heir = Vector2i(floori(float(found["x"])), floori(float(found["z"])))
	var named := s.name_at(float(found["x"]), float(found["z"]))
	ok(str(named.get("kind", "")) == "caravan", "a click on the wagon names it")
	var r := s.use()
	ok(bool(r["ok"]) and str(r.get("open", "")) == "merchant" and not (r["landmark"] as Dictionary).is_empty(), "Use beside it opens the merchant's panel")
	var lm: Dictionary = r["landmark"]
	ok(GameWildsTrade.is_trader(lm) and str(lm["id"]).begins_with(GameCaravans.PREFIX), "it is a trader of its own kind")
	var wares := GameWildsTrade.wares(d, lm)
	ok(wares.size() >= int(GameWilds.data()["landmarks"]["caravan"]["merchant"]["stock_count"][0]), "with wares to buy (%d)" % wares.size())
	ok(JSON.stringify(wares) == JSON.stringify(GameWildsTrade.wares(_fresh(), lm)), "keyed on the seed: the same wares for the same seed")
	var rng := d.rng.state
	GameWildsTrade.wares(d, lm)
	ok(d.rng.state == rng, "and not on the dynasty's dice")
	var w: Dictionary = wares[0]
	d.heir.gold = 5000
	var line := GameWildsTrade.buy(d, lm, str(w["key"]))
	ok(d.heir.gold < 5000, "a ware can be bought: %s" % line)
	ok(GameWildsTrade.sold_out(d, lm, str(w["key"])), "and is gone from the cart")
	# far from any caravan Use opens nothing
	s.heir = Vector2i(5, 5)
	ok(str(s.use().get("open", "")) != "merchant", "away from the road there is no trader")


func test_view() -> void:
	var d := _fresh()
	var t := _road_tile(d, "ironford", "kingshold")
	var v := TileView.new()
	v.setup(d)
	root.add_child(v)
	v.show_view(Vector2(float(t.x) + 0.5, float(t.y) + 0.5), Vector2(6, 6))
	var c := TileView.chunk_of(t.x, t.y)
	var n := int(TileView.settings()["chunk"])
	var local := Vector2i(t.x - c.x * n, t.y - c.y * n)
	var kinds := TileView.kinds()
	var layer: TileMapLayer = v.decor[c]
	ok(layer.get_cell_source_id(local) >= 0 and layer.get_cell_atlas_coords(local).x == kinds.find(GameRoads.trail_at(d, t.x, t.y)), "a road tile is drawn with its trail under what stands there")
	ok(GameRoads.trail_at(d, t.x, t.y) != "" and str(TileView.cell_kind(layer, local)).begins_with("trail_"), "the trail is a kind")
	# bare ground beside it has none
	var off := Vector2i(t.x + 6, t.y)
	var oc := TileView.chunk_of(off.x, off.y)
	if v.decor.has(oc) and not GameRoads.on_road(d, off.x, off.y):
		var ol := Vector2i(off.x - oc.x * n, off.y - oc.y * n)
		ok(not str(TileView.cell_kind((v.decor[oc] as TileMapLayer), ol)).begins_with("trail_"), "and a tile off the road does not")
	# a signpost is a standing thing
	var p: Dictionary = GameRoads.posts(d)[0]
	v.show_view(Vector2(float(p["x"]) + 0.5, float(p["z"]) + 0.5), Vector2(6, 6))
	var pc := TileView.chunk_of(int(p["x"]), int(p["z"]))
	var pl := Vector2i(int(p["x"]) - pc.x * n, int(p["z"]) - pc.y * n)
	ok(TileView.cell_kind(v.things[pc] as TileMapLayer, pl) == "signpost", "a signpost stands on its tile")
	ok(RoadsideArt.glyph_texture("signpost") != null, "the signpost has a texture")
	ok(RoadsideArt.glyph_texture("wagon") != null and RoadsideArt.glyph_texture("tent_green") != null and RoadsideArt.glyph_texture("campfire") != null, "the wagon, the tent and the fire have textures")
	ok(RoadsideArt.glyph_texture("nothing") == null, "and an unknown glyph none")
	v.queue_free()
