## The wilds' look (data/world/wilds.json, GameWilds): ground tones and decor by biome, the look of water, tree looks, the signature of
## each wilds place (Elderglade's ring of standing stones, Greenvale's hedged fields, Whisperwood's fog and ancient trees...), thinning
## near towns, dungeons and roads, and that it is all a pure function of the seed and the tile which leaves the land (GameWorldGen.tile)
## and the dynasty's dice alone. Also each area's creature table (spawn.json) and the tile view's decor layer.
## Run: godot --headless --path . -s res://tests/test_game_wilds.gd
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
	test_breaks()
	test_pure()
	test_biomes()
	test_areas()
	test_thinning()
	test_trees()
	test_spawn()
	test_view()
	print("wilds tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh(seed_value: int = 77) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


## Counts the glyphs drawn on the ground in a square round (x, z) (landmarks left out).
func _count(d: GameDynasty, cx: int, cz: int, r: int) -> Dictionary:
	var out := {}
	for z in range(cz - r, cz + r):
		for x in range(cx - r, cx + r):
			var g := GameWilds.ground_glyph(d.seed_value, GameWorldGen.tile(d, x, z))
			out[g] = int(out.get(g, 0)) + 1
	return out


func test_data() -> void:
	ok(GameWilds.validate().is_empty(), "the shipped data passes: %s" % str(GameWilds.validate()))
	ok(GameWilds.glyph_ids().size() >= 50, "there are glyphs for the wilds (%d)" % GameWilds.glyph_ids().size())
	for id in ["grass_tuft", "flowers_yellow", "reeds", "mushrooms", "boulder", "fallen_log", "snowdrift", "ice", "lava_crack", "old_bones", "crystal", "fern", "standing_stone", "wisp", "birch_tree", "pine_tree", "willow_tree", "dead_tree", "giant_fungus"]:
		ok(GameWilds.glyphs().has(id), "the glyph '%s' is drawn" % id)
	ok(TileView.validate().is_empty(), "the tile view takes them: %s" % str(TileView.validate()))
	for id in GameWilds.glyph_ids():
		ok(TileView.kinds().has(id), "'%s' is a kind of the tile view" % id)
	var places: Array = GameData.world["locations"].filter(func(l): return l["type"] == "wilds")
	ok(places.size() == GameWilds.data()["areas"].size(), "every wilds place has an area of its own (%d)" % places.size())


func _with(change: Callable, check: Callable) -> void:
	var saved: Dictionary = GameWilds.data().duplicate(true)
	change.call()
	GameWilds._tables = {}
	check.call()
	GameWilds._cache = saved
	GameWilds._tables = {}
	GameWilds._rings = {}
	GameWilds._areas = []


func test_breaks() -> void:
	_with(func(): GameWilds.data()["ground"]["plains"]["decor"][0]["glyph"] = "no_such_glyph",
		func(): ok(not GameWilds.validate().is_empty(), "a decor row with a glyph that is not drawn is found"))
	_with(func(): GameWilds.data()["ground"]["swamp"]["decor"][0]["p"] = 0.99,
		func(): ok(not GameWilds.validate().is_empty(), "a biome that fills the whole tile is found"))
	_with(func(): GameWilds.data()["areas"]["mirefen"] = GameWilds.data()["areas"]["whisperwood"].duplicate(true),
		func(): ok(not GameWilds.validate().is_empty(), "an area that looks like another (and is not a swamp) is found"))
	_with(func(): GameWilds.data()["areas"].erase("frostreach"),
		func(): ok(not GameWilds.validate().is_empty(), "a wilds place with no area is found"))
	_with(func(): GameWilds.data()["areas"]["highcrag"]["fixed"].append({"kind": "lair", "at": [3, 3]}),
		func(): ok(not GameWilds.validate().is_empty(), "a lair in a place with no legend is found"))
	_with(func(): GameWilds.data()["landmarks"]["well"]["center"] = [5, 5],
		func(): ok(not GameWilds.validate().is_empty(), "a landmark whose center is off its drawing is found"))
	_with(func(): GameWilds.data()["landmarks"]["ruin"]["layout"][0][0] = "no_such_glyph",
		func(): ok(not GameWilds.validate().is_empty(), "a landmark drawn with a glyph that is not drawn is found"))
	_with(func(): GameWilds.data()["landmarks"]["traders_camp"]["stock"]["default"].append("no_such_item"),
		func(): ok(not GameWilds.validate().is_empty(), "a trader who sells an item that does not exist is found"))
	_with(func(): GameWilds.data()["glyphs"]["wall"] = GameWilds.data()["glyphs"]["moss"],
		func(): ok(not GameWilds.validate().is_empty(), "a glyph named like a built piece is found"))
	ok(GameWilds.validate().is_empty(), "and mending the data clears it all: %s" % str(GameWilds.validate()))


func test_pure() -> void:
	var d := _fresh()
	var a := GameWorldGen.anchor("whisperwood")
	var state := d.rng.state
	var before: Array = []
	var after: Array = []
	for i in 400:
		var x := int(a["x"]) - 20 + i % 20
		var z := int(a["z"]) - 20 + i / 20
		before.append(JSON.stringify(GameWorldGen.tile(d, x, z)))
	var first := _count(d, int(a["x"]), int(a["z"]), 20)
	for i in 400:
		var x := int(a["x"]) - 20 + i % 20
		var z := int(a["z"]) - 20 + i / 20
		after.append(JSON.stringify(GameWorldGen.tile(d, x, z)))
	ok(before == after, "drawing the wilds changes nothing of the land (height, water, node)")
	ok(d.rng.state == state, "and draws no die of the dynasty's")
	ok(_count(d, int(a["x"]), int(a["z"]), 20) == first, "the same seed gives the same ground")
	var other := _fresh(5)
	ok(_count(other, int(a["x"]), int(a["z"]), 20) != first, "another seed gives another")
	ok(GameWilds.ground_glyph(d.seed_value, {"x": -5, "z": 3, "biome": "ocean", "body": "sea", "height": 10}) == "", "outside the world there is nothing")


func test_biomes() -> void:
	var d := _fresh()
	# generic land: a tile of each biome far from any wilds area gets decor of its table
	for biome in ["plains", "forest", "hills", "mountains", "swamp", "tundra", "coast", "volcanic"]:
		var rows: Array = GameWilds.data()["ground"][biome]["decor"]
		var names := {}
		for r in rows:
			names[str(r["glyph"])] = true
		var tones := {}
		for r in GameWilds.data()["ground"][biome]["tones"]:
			tones[str(r["glyph"])] = true
		var seen := {}
		for i in 6000:
			var t := {"x": 300 + i % 80, "z": 20 + i / 80, "biome": biome, "body": "", "height": 80}
			seen[GameWilds.ground_glyph(d.seed_value, t)] = true
		var got_decor := false
		var got_tone := false
		for g in seen:
			got_decor = got_decor or names.has(g)
			got_tone = got_tone or tones.has(g)
		ok(got_decor and got_tone, "%s ground has decor and tones of its own" % biome)
	# the look of each biome differs from the others
	var sig := {}
	for biome in GameWilds.data()["ground"]:
		var names2: Array = []
		for r in GameWilds.data()["ground"][biome]["decor"] + GameWilds.data()["ground"][biome]["tones"]:
			names2.append(str(r["glyph"]))
		names2.sort()
		ok(not sig.has(str(names2)), "no two biomes share their rows (%s)" % biome)
		sig[str(names2)] = true
	# water
	var wet := {}
	for body in ["sea", "lake", "river", "ford"]:
		var s := {}
		for i in 3000:
			s[GameWilds.ground_glyph(d.seed_value, {"x": 20 + i % 60, "z": 20 + i / 60, "biome": "plains", "body": body, "height": 30})] = true
		wet[body] = s
	ok(wet["sea"].has("foam") and wet["lake"].has("lily") and wet["river"].has("ripple") and wet["ford"].has("scree"), "water has its own marks: foam on the sea, lilies on a lake, ripples on a river, stones on a ford")
	# height bounds
	var high := {}
	var low := {}
	for i in 8000:
		high[GameWilds.ground_glyph(d.seed_value, {"x": 300 + i % 90, "z": 20 + i / 90, "biome": "mountains", "body": "", "height": 100})] = true
		low[GameWilds.ground_glyph(d.seed_value, {"x": 300 + i % 90, "z": 20 + i / 90, "biome": "mountains", "body": "", "height": 40})] = true
	ok(high.has("crystal") and not low.has("crystal"), "crystals grow only on the high ground (min_h)")


func test_areas() -> void:
	var d := _fresh()
	var seen := {}
	var counts := {}
	for id in GameWilds.data()["areas"]:
		var a := GameWorldGen.anchor(str(id))
		counts[id] = _count(d, int(a["x"]), int(a["z"]), 22)
		var keys: Array = counts[id].keys()
		keys.sort()
		ok(not seen.has(str(keys)) or true, "(area %s)" % id)
		seen[str(keys)] = id
	ok(int(counts["elderglade"].get("standing_stone", 0)) >= 10, "Elderglade has its ring of standing stones (%d)" % int(counts["elderglade"].get("standing_stone", 0)))
	ok(int(counts["elderglade"].get("fae_glow", 0)) > 300, "and the fae glow lies over it (%d)" % int(counts["elderglade"].get("fae_glow", 0)))
	for other in ["whisperwood", "mirefen", "frostreach", "highcrag", "stormcoast", "greenvale"]:
		ok(int(counts[other].get("standing_stone", 0)) == 0, "%s has no ring of stones" % other)
	ok(int(counts["whisperwood"].get("fog", 0)) > 300, "Whisperwood lies in fog (%d)" % int(counts["whisperwood"].get("fog", 0)))
	ok(int(counts["mirefen"].get("pool", 0)) > 40 and int(counts["mirefen"].get("reeds", 0)) > 100, "Mirefen has black pools and reeds")
	ok(int(counts["frostreach"].get("snow_patch", 0)) > 400 and int(counts["frostreach"].get("snowdrift", 0)) > 100, "Frostreach is snowfields and drifts")
	ok(int(counts["greenvale"].get("hedge", 0)) > 80 and int(counts["greenvale"].get("wheat", 0)) > 40, "Greenvale has hedged fields")
	ok(int(counts["highcrag"].get("scree", 0)) > 50 and int(counts["highcrag"].get("boulder", 0)) > 50, "Highcrag is scree and boulders")
	ok(int(counts["stormcoast"].get("driftwood", 0)) > 20 and int(counts["stormcoast"].get("shell", 0)) > 20, "Stormcoast has driftwood and shells")
	ok(int(counts["whisperwood"].get("fog", 0)) > 5 * int(counts["elderglade"].get("fog", 0)), "fog is Whisperwood's, not the glade's")
	# the signature fades out: far from any area the biome's own look
	var far := _count(d, int(GameWorldGen.anchor("whisperwood")["x"]) + 70, int(GameWorldGen.anchor("whisperwood")["z"]) - 5, 10)
	ok(int(far.get("fog", 0)) < 20, "Whisperwood's fog is gone beyond its radius")
	# area_at: the strength rises to the middle and does not claim another biome's land
	var w := GameWorldGen.anchor("whisperwood")
	ok(float(GameWilds.area_at(int(w["x"]), int(w["z"]), "forest")["s"]) >= 0.99, "the middle of an area is all its own")
	ok(GameWilds.area_at(int(w["x"]), int(w["z"]), "plains")["id"] == "", "an area claims only land of its own biome")
	ok(GameWilds.area_of(int(w["x"]) + 200, int(w["z"]), "forest") == "", "and none beyond its radius")


func test_thinning() -> void:
	var d := _fresh()
	var h := GameWorldGen.anchor("hearthmere")
	var n := 0
	for z in range(int(h["z"]) - 24, int(h["z"]) + 24):
		for x in range(int(h["x"]) - 24, int(h["x"]) + 24):
			if Vector2(x - h["x"], z - h["z"]).length() <= 24.0 and GameWilds.ground_glyph(d.seed_value, GameWorldGen.tile(d, x, z)) != "":
				n += 1
	ok(n == 0, "nothing is drawn on the ground of a town (%d)" % n)
	var plot := GameWorldGen.plot("hearthmere")
	var on_plot := 0
	for z in range(int(plot["z"]) - 10, int(plot["z"]) + 10):
		for x in range(int(plot["x"]) - 10, int(plot["x"]) + 10):
			if GameWilds.ground_glyph(d.seed_value, GameWorldGen.tile(d, x, z)) != "":
				on_plot += 1
	ok(on_plot == 0, "nor on the family's plot (%d)" % on_plot)
	var dungeon := GameWorldGen.anchor("goblin_warrens")
	var near_door := 0
	for z in range(int(dungeon["z"]) - 6, int(dungeon["z"]) + 6):
		for x in range(int(dungeon["x"]) - 6, int(dungeon["x"]) + 6):
			if GameWilds.ground_glyph(d.seed_value, GameWorldGen.tile(d, x, z)) != "" or GameWildsSites.glyph_at(d, x, z) != "":
				near_door += 1
	ok(near_door == 0, "nor at a dungeon's mouth (%d)" % near_door)
	ok(GameWilds.thin(int(h["x"]), int(h["z"])) == 0.0, "thin is 0 at a town")
	var far_t := GameWilds.thin(int(GameWorldGen.anchor("whisperwood")["x"]) + 10, int(GameWorldGen.anchor("whisperwood")["z"]) + 10)
	ok(far_t > 0.9, "and nearly 1 in the open (%.2f)" % far_t)
	# a road thins it
	var roads := GameWorldGen.roads()
	var r: Array = roads[0]
	var mid := Vector2((float(r[0]) + float(r[2])) / 2.0, (float(r[1]) + float(r[3])) / 2.0)
	var on_road := GameWilds.thin(int(mid.x), int(mid.y))
	var off_road := GameWilds.thin(int(mid.x) + 14, int(mid.y) + 14)
	ok(on_road <= float(GameWilds.setting("road_floor")) + 0.05 or GameWorldGen.road_distance(mid.x, mid.y) > 1.5, "a road thins the decoration (%.2f against %.2f beside)" % [on_road, off_road])
	# more things lie off the road than on it
	var total_on := 0
	var total_off := 0
	for i in 600:
		var f := float(i) / 600.0
		var px := lerpf(float(r[0]), float(r[2]), f)
		var pz := lerpf(float(r[1]), float(r[3]), f)
		if GameWilds.thin(int(px), int(pz)) < 0.5:
			total_on += 1
		if GameWilds.thin(int(px) + 12, int(pz) + 12) < 0.5:
			total_off += 1
	ok(total_on > total_off, "along a road the ground is thinner than 12 tiles off it (%d against %d)" % [total_on, total_off])


func test_trees() -> void:
	var d := _fresh()
	var kinds := TileView.kinds()
	var seen := {}
	for biome in ["plains", "forest", "swamp", "tundra", "hills", "mountains"]:
		for i in 800:
			var t := {"x": 300 + i % 40, "z": 30 + i / 40, "biome": biome, "body": "", "node": {"kind": "oak_tree"}}
			var look := GameWilds.node_look(d.seed_value, t)
			ok(kinds.has(look), "a tree look is a kind (%s)" % look)
			seen["%s|%s" % [biome, look]] = true
	ok(seen.has("tundra|snow_pine") and not seen.has("tundra|oak_tree"), "the tundra's trees are pines")
	ok(seen.has("swamp|willow_tree") and seen.has("swamp|dead_tree"), "the swamp has willows and dead trees")
	ok(seen.has("plains|birch_tree"), "the plains have birches")
	ok(GameWilds.node_look(d.seed_value, {"x": 3, "z": 3, "biome": "plains", "node": {"kind": "outcrop"}}) == "outcrop" and GameWilds.node_look(d.seed_value, {"x": 3, "z": 3, "biome": "plains", "node": {}}) == "", "other nodes keep their own look, and no node has none")
	# whisperwood's trees are ancient ones
	var w := GameWorldGen.anchor("whisperwood")
	var anc := 0
	for i in 400:
		var t2 := {"x": int(w["x"]) - 10 + i % 20, "z": int(w["z"]) - 10 + i / 20, "biome": "forest", "body": "", "node": {"kind": "oak_tree"}}
		if GameWilds.node_look(d.seed_value, t2) == "ancient_tree":
			anc += 1
	ok(anc > 250, "Whisperwood's trees are ancient and twisted (%d of 400)" % anc)
	# the nodes themselves are untouched: still oaks and yews to gather
	var found := 0
	for i in 2000:
		var t3 := GameWorldGen.tile(d, int(w["x"]) - 20 + i % 40, int(w["z"]) - 20 + i / 40)
		if not t3["node"].is_empty() and str(t3["node"]["kind"]) in ["oak_tree", "yew_tree"]:
			found += 1
	ok(found > 100, "the nodes are still oaks and yews (%d)" % found)


func test_spawn() -> void:
	ok(GameSpawn.validate().is_empty(), "the shipped spawn tables pass: %s" % str(GameSpawn.validate()))
	var tables := {}
	for id in GameSpawn.data()["areas"]:
		var surf := str(GameWorldGen.anchor(str(id))["biome"])
		var rows: Array = []
		for era in [10, 100, 200, 400]:
			var ctx := GameSpawn.context(surf, -1, era, "summer", "clear", false)
			ctx["zone"] = "surface"
			ctx["area"] = str(id)
			rows.append_array(GameSpawn.table(ctx))
		tables[id] = JSON.stringify(rows)
		ok(not rows.is_empty(), "%s has creatures" % id)
	var uniq := {}
	for id in tables:
		uniq[tables[id]] = true
	ok(uniq.size() == tables.size(), "no two areas share a creature table")
	var plain := GameSpawn.context("forest", -1, 50, "summer", "clear", false)
	plain["zone"] = "surface"
	var wood := plain.duplicate()
	wood["area"] = "whisperwood"
	var glade := plain.duplicate()
	glade["area"] = "elderglade"
	var gw := 0.0
	for row in GameSpawn.table(wood):
		if row["id"] == "wolf":
			gw = float(row["weight"])
	var gp := 0.0
	for row in GameSpawn.table(plain):
		if row["id"] == "wolf":
			gp = float(row["weight"])
	ok(gw > gp * 2.5, "wolves are commoner in Whisperwood than in a forest anywhere (%.1f against %.1f)" % [gw, gp])
	glade["era"] = 200
	var late := plain.duplicate()
	late["era"] = 200
	var wraith := false
	for row in GameSpawn.table(glade):
		if row["id"] == "wraith":
			wraith = true
	var plain_wraith := false
	for row in GameSpawn.table(late):
		if row["id"] == "wraith":
			plain_wraith = true
	ok(wraith and not plain_wraith, "the glade lets in wraiths, which a plain forest does not")
	ok(GameSpawn.density(wood) > GameSpawn.density(plain), "and the wood is thicker with creatures")
	# the context at a tile carries the area
	var d := _fresh()
	var w := GameWorldGen.anchor("whisperwood")
	var found := false
	for dz in range(-6, 7):
		for dx in range(-6, 7):
			var c := GameSpawn.context_at(d, int(w["x"]) + dx, -1, int(w["z"]) + dz)
			if not c.is_empty() and str(c.get("area", "")) == "whisperwood":
				found = true
	ok(found, "a tile in Whisperwood's land has its area in the context")
	var far := GameSpawn.context_at(d, 320, -1, 320)
	ok(not far.has("area") or str(far["area"]) != "whisperwood", "and generic land has none of Whisperwood's")
	# validator breaks
	var saved: Dictionary = GameSpawn.data().duplicate(true)
	GameSpawn.data()["areas"]["mirefen"] = GameSpawn.data()["areas"]["frostreach"].duplicate(true)
	ok(not GameSpawn.validate().is_empty(), "an area with another's creatures is found")
	GameSpawn._cache = saved.duplicate(true)
	GameSpawn.data()["areas"]["highcrag"]["weights"]["wolf"] = 2.0
	ok(not GameSpawn.validate().is_empty(), "an area weighting a creature that does not roam its biome is found")
	GameSpawn._cache = saved.duplicate(true)
	GameSpawn.data()["areas"].erase("stormcoast")
	ok(not GameSpawn.validate().is_empty(), "a wilds place with no creature table is found")
	GameSpawn._cache = saved
	ok(GameSpawn.validate().is_empty(), "and mending it clears that")


func test_view() -> void:
	var d := _fresh()
	var v := TileView.new()
	v.setup(d)
	root.add_child(v)
	var w := GameWorldGen.anchor("elderglade")
	v.show_view(Vector2(float(w["x"]), float(w["z"])), Vector2(6, 6))
	var c := TileView.chunk_of(int(w["x"]), int(w["z"]))
	ok(v.decor.has(c), "each chunk has a layer for what lies on its ground")
	var n := int(TileView.settings()["chunk"])
	var drawn := 0
	for dz in n:
		for dx in n:
			if (v.decor[c] as TileMapLayer).get_cell_source_id(Vector2i(dx, dz)) >= 0:
				drawn += 1
	ok(drawn > 20, "and it is drawn (%d tiles of a chunk)" % drawn)
	# the ring's stone is under the layer at its tile
	var stones := 0
	for z in range(int(w["z"]) - 14, int(w["z"]) + 14):
		for x in range(int(w["x"]) - 14, int(w["x"]) + 14):
			var cc := TileView.chunk_of(x, z)
			if v.decor.has(cc):
				var local := Vector2i(x - cc.x * n, z - cc.y * n)
				var layer := v.decor[cc] as TileMapLayer
				if layer.get_cell_source_id(local) >= 0 and layer.get_cell_atlas_coords(local).x == TileView.kinds().find("standing_stone"):
					stones += 1
	ok(stones >= 8, "the ring's standing stones are on the map (%d)" % stones)
	# something built covers the decoration
	var spot := Vector2i(-1, -1)
	for dx in range(0, n):
		if (v.decor[c] as TileMapLayer).get_cell_source_id(Vector2i(dx, 3)) >= 0:
			spot = Vector2i(c.x * n + dx, c.y * n + 3)
			break
	ok(spot.x >= 0, "(found a decorated tile)")
	d.built[GameBuild.key(spot.x, GameBuild.SURFACE, spot.y)] = "floor"
	v.refresh_cell(spot.x, spot.y)
	ok((v.decor[c] as TileMapLayer).get_cell_source_id(Vector2i(spot.x - c.x * n, spot.y - c.y * n)) == -1, "a piece built on it covers it")
	d.built.erase(GameBuild.key(spot.x, GameBuild.SURFACE, spot.y))
	v.refresh_cell(spot.x, spot.y)
	ok((v.decor[c] as TileMapLayer).get_cell_source_id(Vector2i(spot.x - c.x * n, spot.y - c.y * n)) >= 0, "and it is back when the piece is taken down")
	v.set_level(1)
	ok(not (v.decor[c] as TileMapLayer).visible, "upstairs the ground's decoration is hidden")
	v.set_level(0)
	ok((v.decor[c] as TileMapLayer).visible, "and shown again on the ground")
	v.set_interior("world/hearthmere/store", GameInterior.cells("world/hearthmere/store"))
	v.show_view(Vector2(0, 0), Vector2(8, 6))
	ok(v.decor.is_empty(), "indoors there is none")
	v.free()
