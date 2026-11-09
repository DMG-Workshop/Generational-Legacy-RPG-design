## World generation from the dynasty's seed (roadmap item 46): the data and ways to break it; the anchors (one for each
## authored place, at its map position, each keeping its own biome and its flat, clear ground); the same seed the same
## world and another seed another; coherent land (biomes in regions, heights without cliffs); the sea at the edge of the
## world; nodes by biome (trees where forests are, bones in tundra, outcrops only over ore and only in rock country); the
## outcrop's tie to the mining ground; chunks agreeing with tiles; and that nothing of the dynasty's moves.
## Run: godot --headless --path . -s res://tests/test_game_worldgen.gd
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
	test_anchors()
	test_seed()
	test_anchor_lock()
	test_land()
	test_sea()
	test_anchor_ground()
	test_nodes()
	test_chunks()
	test_untouched()
	print("worldgen tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func dyn(seed_value: int = 5) -> GameDynasty:
	return GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")


# ---------------------------------------------------------------- data

func test_data() -> void:
	ok(GameWorldGen.validate().is_empty(), "the data is sound: %s" % str(GameWorldGen.validate()))
	var saved: Dictionary = GameWorldGen.data().duplicate(true)
	var reset := func():
		GameWorldGen._cache = saved.duplicate(true)
		GameWorldGen._anchors = []
	GameWorldGen.data()["biomes"]["forest"]["nodes"]["no_such_node"] = 0.1
	ok(not GameWorldGen.validate().is_empty(), "a node that is not defined is found")
	reset.call()
	GameWorldGen.data()["nodes"]["oak_tree"]["material"] = "unobtainium"
	ok(not GameWorldGen.validate().is_empty(), "a node of an unknown material is found")
	reset.call()
	for b in GameWorldGen.data()["surface_of"].keys():
		if b in ["rift"]:
			GameWorldGen.data()["surface_of"].erase(b)
	ok(not GameWorldGen.validate().is_empty(), "a place whose every biome has no surface is found")
	reset.call()
	GameWorldGen.data()["surface_of"]["cave"] = "no_such_biome"
	ok(not GameWorldGen.validate().is_empty(), "a surface that is not a biome is found")
	reset.call()
	GameWorldGen.data()["biomes"]["mountains"]["amp"] = 200
	ok(not GameWorldGen.validate().is_empty(), "a biome that can pass the world's top is found")
	reset.call()
	GameWorldGen.data()["biomes"]["forest"]["nodes"]["oak_tree"] = 0.9
	ok(not GameWorldGen.validate().is_empty(), "a biome packed with nodes is found")
	reset.call()
	GameWorldGen.data()["settings"]["sea_level"] = 500
	ok(not GameWorldGen.validate().is_empty(), "a sea above the top is found")
	reset.call()
	GameWorldGen.data()["settings"]["anchor_radius"]["town"] = 0
	ok(not GameWorldGen.validate().is_empty(), "a town with no cleared ground is found")
	reset.call()
	GameWorldGen.data()["settings"]["map_size"] = 4
	ok(not GameWorldGen.validate().is_empty(), "a map smaller than the authored one is found")
	reset.call()
	GameWorldGen.data()["settings"]["outcrop_depths"] = [900]
	ok(not GameWorldGen.validate().is_empty(), "an outcrop depth below the mining ground is found")
	reset.call()
	GameWorldGen.data()["biomes"]["swamp"]["name"] = "Swamp"
	GameWorldGen.data()["settings"].erase("shore")
	ok(not GameWorldGen.validate().is_empty(), "a missing setting is found")
	reset.call()
	GameWorldGen.data()["biomes"]["lonely"] = {"name": "Lonely", "base": 40, "amp": 3, "nodes": {}}
	ok(not GameWorldGen.validate().is_empty(), "a biome that is the surface of nothing is found")
	reset.call()
	ok(GameWorldGen.validate().is_empty(), "and the data is put back")


# ---------------------------------------------------------------- anchors

func test_anchors() -> void:
	var anchors := GameWorldGen.anchors()
	ok(anchors.size() == GameData.world["locations"].size() and anchors.size() == 17, "one anchor for each authored place: %d" % anchors.size())
	var scale := int(GameWorldGen.setting("scale"))
	for l in GameData.world["locations"]:
		var a := GameWorldGen.anchor(str(l["id"]))
		ok(not a.is_empty() and int(a["x"]) == int(l["x"]) * scale + scale / 2 and int(a["z"]) == int(l["y"]) * scale + scale / 2, "%s stands at its map position" % l["id"])
	ok(GameWorldGen.anchor("hearthmere")["biome"] == "plains" and GameWorldGen.anchor("whisperwood")["biome"] == "forest" and GameWorldGen.anchor("mirefen")["biome"] == "swamp", "an anchor's biome is its place's")
	ok(GameWorldGen.anchor("the_rift")["biome"] == "volcanic" and GameWorldGen.anchor("deepstone_halls")["biome"] == "hills" and GameWorldGen.anchor("hollow_barrow")["biome"] == "plains" and GameWorldGen.anchor("elderglade")["biome"] == "forest", "places of the underworld or the fae stand on a surface biome")
	ok(GameWorldGen.anchor("brinehaven")["biome"] == "coast" and GameWorldGen.anchor("frostreach")["biome"] == "tundra" and GameWorldGen.anchor("highcrag")["biome"] == "mountains", "coast, tundra and mountains where the map says")
	ok(GameWorldGen.anchor("nowhere").is_empty(), "an unknown place has no anchor")
	ok(GameWorldGen.size() == 640, "the world is 640 tiles each way: %d" % GameWorldGen.size())
	# the map's order is kept: places that are east on the map are east in the world
	ok(float(GameWorldGen.anchor("brinehaven")["x"]) > float(GameWorldGen.anchor("hearthmere")["x"]) and float(GameWorldGen.anchor("frostreach")["z"]) < float(GameWorldGen.anchor("mirefen")["z"]), "the sandbox agrees with the authored map's directions")


func test_seed() -> void:
	var d := dyn()
	var other := dyn(99)
	var same := 0
	var differ_biome := 0
	var differ_height := 0
	for i in 400:
		var x := (i * 37) % 640
		var z := (i * 91) % 640
		var a := GameWorldGen.tile(d, x, z)
		if GameWorldGen.tile(dyn(), x, z) == a:
			same += 1
		var b := GameWorldGen.tile(other, x, z)
		if b["biome"] != a["biome"]:
			differ_biome += 1
		if b["height"] != a["height"]:
			differ_height += 1
	ok(same == 400, "the same seed gives the same world, tile for tile")
	ok(differ_biome > 5 and differ_height > 300, "another seed gives another world (%d biomes and %d heights differ of 400)" % [differ_biome, differ_height])
	# but the anchors stay where the map puts them, in their own biomes, whatever the seed
	var kept := 0
	for a in GameWorldGen.anchors():
		for dd in [d, other, dyn(7)]:
			var t := GameWorldGen.tile(dd, int(a["x"]), int(a["z"]))
			if t["biome"] == a["biome"] and t["place"] == a["id"]:
				kept += 1
	ok(kept == 17 * 3, "every anchor keeps its biome and its mark in every seed: %d of 51" % kept)


## The promise that an anchor never moves: even with the border warped far more than the real data warps it, every anchor
## still stands in its own biome, because the warp fades to nothing at an anchor.
func test_anchor_lock() -> void:
	var saved: Dictionary = GameWorldGen.data().duplicate(true)
	GameWorldGen.data()["settings"]["warp_amp"] = 600.0
	var kept := 0
	var moved_elsewhere := 0
	for sd in [5, 17, 61]:
		var d := dyn(sd)
		for a in GameWorldGen.anchors():
			if GameWorldGen.tile(d, int(a["x"]), int(a["z"]))["biome"] == a["biome"]:
				kept += 1
		# and the warp really does move the land away from the anchors
		for i in 200:
			var x := (i * 37) % 640
			var z := (i * 91) % 640
			if GameWorldGen.blend(sd, float(x), float(z))["biome"] != GameWorldGen.nearest_anchor(float(x), float(z))["anchor"]["biome"]:
				moved_elsewhere += 1
	GameWorldGen._cache = saved
	GameWorldGen._anchors = []
	ok(kept == 17 * 3, "with the border thrown about, every anchor still keeps its biome: %d of 51" % kept)
	ok(moved_elsewhere > 60, "(and the warp does move the land elsewhere: %d of 600 tiles are not their nearest anchor's biome)" % moved_elsewhere)


# ---------------------------------------------------------------- the land

func test_land() -> void:
	var d := dyn()
	# biomes come in regions: a tile and the one beside it are nearly always the same biome
	var pairs := 0
	var same := 0
	var big_steps := 0
	var max_step := 0
	for i in 1500:
		var x := 20 + (i * 53) % 600
		var z := 20 + (i * 29) % 600
		var a := GameWorldGen.tile(d, x, z)
		var b := GameWorldGen.tile(d, x + 1, z)
		var c := GameWorldGen.tile(d, x, z + 1)
		pairs += 2
		same += (1 if a["biome"] == b["biome"] else 0) + (1 if a["biome"] == c["biome"] else 0)
		var step := maxi(absi(int(a["height"]) - int(b["height"])), absi(int(a["height"]) - int(c["height"])))
		max_step = maxi(max_step, step)
		if step > 4:
			big_steps += 1
	ok(float(same) / pairs > 0.99, "biomes come in regions: %.1f%% of neighbours match" % (100.0 * same / pairs))
	ok(big_steps < 30 and max_step <= 14, "the land has no cliffs: %d steps over 4 and none over %d" % [big_steps, max_step])
	# the biomes are what their data says
	var hsum := {}
	var hn := {}
	for i in 3000:
		var t := GameWorldGen.tile(d, (i * 53) % 640, (i * 131) % 640)
		if t["water"]:
			continue
		hsum[t["biome"]] = float(hsum.get(t["biome"], 0.0)) + float(t["height"])
		hn[t["biome"]] = int(hn.get(t["biome"], 0)) + 1
	var mean := func(b: String) -> float: return float(hsum.get(b, 0.0)) / maxf(1.0, float(hn.get(b, 0)))
	ok(hn.size() == 8, "all eight surface biomes are in this world: %s" % str(hn.keys()))
	ok(mean.call("mountains") > mean.call("hills") and mean.call("hills") > mean.call("plains") and mean.call("volcanic") > mean.call("forest") and mean.call("plains") > mean.call("coast") - 1.0, "mountains stand higher than hills, hills than plains (%.0f, %.0f, %.0f)" % [mean.call("mountains"), mean.call("hills"), mean.call("plains")])
	var low := 999
	var high := -1
	for i in 2000:
		var t := GameWorldGen.tile(d, (i * 71) % 640, (i * 17) % 640)
		low = mini(low, int(t["height"]))
		high = maxi(high, int(t["height"]))
	ok(low >= 0 and high <= int(GameWorldGen.setting("max_height")) and high > 85, "heights stay inside the world and the peaks are high: %d to %d" % [low, high])


func test_sea() -> void:
	var d := dyn()
	var t := GameWorldGen.tile(d, -5, 100)
	ok(t["biome"] == "ocean" and t["water"] and t["node"].is_empty(), "outside the world is ocean")
	ok(GameWorldGen.tile(d, 640, 10)["water"] and GameWorldGen.tile(d, 10, 700)["water"] and not GameWorldGen.in_bounds(640, 0), "on every side")
	var edge_water := 0
	var n := 0
	for i in 100:
		for pair in [[0, i * 6], [639, i * 6], [i * 6, 0], [i * 6, 639]]:
			n += 1
			if GameWorldGen.tile(d, int(pair[0]), int(pair[1]))["water"]:
				edge_water += 1
	ok(edge_water == n, "the sea takes the edge of the world: %d of %d edge tiles" % [edge_water, n])
	var inner := 0
	var water := 0
	for i in 3000:
		var x := 60 + (i * 53) % 520
		var z := 60 + (i * 131) % 520
		inner += 1
		if GameWorldGen.tile(d, x, z)["water"]:
			water += 1
	ok(float(water) / inner < 0.1, "inland is mostly land: %.1f%% water" % (100.0 * water / inner))
	ok(GameWorldGen.tile(d, 320, 320)["height"] > int(GameWorldGen.setting("sea_level")) - 3, "(the middle of the world is not under the sea)")


# ---------------------------------------------------------------- anchors' own ground

func test_anchor_ground() -> void:
	var d := dyn()
	for a in GameWorldGen.anchors():
		var r := int(a["radius"])
		if r == 0:
			continue
		var cx := int(a["x"])
		var cz := int(a["z"])
		var lo := 999
		var hi := -1
		var nodes := 0
		var wet := 0
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if Vector2(dx, dz).length() > float(r) - 0.5:
					continue
				var t := GameWorldGen.tile(d, cx + dx, cz + dz)
				lo = mini(lo, int(t["height"]))
				hi = maxi(hi, int(t["height"]))
				if not t["node"].is_empty():
					nodes += 1
				if t["water"]:
					wet += 1
		ok(hi - lo <= 2 and nodes == 0 and wet == 0, "%s's ground is flat, dry and clear (%d to %d, %d nodes)" % [a["id"], lo, hi, nodes])
	ok(GameWorldGen.in_anchor_ground(int(GameWorldGen.anchor("hearthmere")["x"]), int(GameWorldGen.anchor("hearthmere")["z"])) and not GameWorldGen.in_anchor_ground(0, 0), "the anchor's ground is known")
	# a town covers more ground than a dungeon's mouth
	ok(int(GameWorldGen.anchor("hearthmere")["radius"]) > int(GameWorldGen.anchor("hollow_barrow")["radius"]) and int(GameWorldGen.anchor("greenvale")["radius"]) == 0, "a town has more cleared ground than a dungeon, and the wilds none")


# ---------------------------------------------------------------- nodes

## Up to `each` tiles of every biome, found by walking the world in steps.
func _by_biome(d: GameDynasty, each: int) -> Dictionary:
	var out := {}
	for z in range(30, 610, 3):
		for x in range(30, 610, 3):
			var t := GameWorldGen.tile(d, x, z)
			if t["water"]:
				continue
			out[t["biome"]] = out.get(t["biome"], [])
			if out[t["biome"]].size() < each:
				out[t["biome"]].append(t)
	return out


func test_nodes() -> void:
	var d := dyn()
	var sample := _by_biome(d, 1500)
	var per := {}
	var kinds := {}
	var bad := 0
	var outcrops := 0
	var outcrop_biomes := {}
	var total := 0
	var land := 0
	for b in sample:
		for t in sample[b]:
			land += 1
			var n: Dictionary = t["node"]
			if n.is_empty():
				continue
			total += 1
			per[b] = per.get(b, {})
			per[b][n["kind"]] = int(per[b].get(n["kind"], 0)) + 1
			kinds[n["kind"]] = true
			if not GameMaterials.has(str(n["material"])) or int(n["amount"]) < 1 or int(n["amount"]) > 4:
				bad += 1
			if n["kind"] == "oak_tree" and n["material"] != "oak" or n["kind"] == "yew_tree" and n["material"] != "yew" or n["kind"] == "herb_patch" and n["material"] != "herb" or n["kind"] == "bone_pile" and n["material"] != "bone":
				bad += 1
			if n["kind"] == "outcrop":
				outcrops += 1
				outcrop_biomes[b] = true
				var found := ""
				for y in GameWorldGen.setting("outcrop_depths"):
					var ore := GameMine.ore_at(d, GameWorldGen.MINE_SITE, int(t["x"]), int(y), int(t["z"]))
					if ore != "":
						found = ore
						break
				if found != n["material"]:
					bad += 1
	ok(sample.size() == 8, "all eight surface biomes are in this world: %s" % str(sample.keys()))
	ok(bad == 0, "every node is of a real material, in range, and an outcrop is the ore beneath it")
	ok(kinds.has("oak_tree") and kinds.has("yew_tree") and kinds.has("herb_patch") and kinds.has("bone_pile") and kinds.has("outcrop"), "all five kinds of node are placed: %s" % str(kinds.keys()))
	var rate := func(biome: String, kind: String) -> float: return float(per.get(biome, {}).get(kind, 0)) / maxf(1.0, float(sample.get(biome, []).size()))
	ok(rate.call("forest", "oak_tree") > rate.call("plains", "oak_tree") * 3.0 and rate.call("forest", "oak_tree") > rate.call("tundra", "oak_tree"), "trees stand thick in forests (%.3f a tile) and thin on plains (%.3f)" % [rate.call("forest", "oak_tree"), rate.call("plains", "oak_tree")])
	ok(rate.call("swamp", "herb_patch") > rate.call("plains", "herb_patch") and rate.call("plains", "herb_patch") > rate.call("hills", "herb_patch"), "herbs grow thickest in swamps (%.3f), then plains (%.3f)" % [rate.call("swamp", "herb_patch"), rate.call("plains", "herb_patch")])
	var bones_cold: float = rate.call("tundra", "bone_pile") + rate.call("swamp", "bone_pile") + rate.call("coast", "bone_pile")
	ok(bones_cold > 0.0 and rate.call("plains", "bone_pile") == 0.0 and rate.call("forest", "bone_pile") == 0.0, "bones lie in the tundra, swamps and on the coast and not on plains or in forests")
	ok(per.get("plains", {}).get("outcrop", 0) == 0 and per.get("forest", {}).get("outcrop", 0) == 0 and per.get("swamp", {}).get("outcrop", 0) == 0 and per.get("coast", {}).get("outcrop", 0) == 0, "no outcrops on plains, in forests, swamps or on the coast")
	ok(outcrops > 20 and outcrop_biomes.has("hills") and outcrop_biomes.has("mountains"), "outcrops show in rock country: %d in %s" % [outcrops, str(outcrop_biomes.keys())])
	ok(float(total) / land > 0.02 and float(total) / land < 0.25, "nodes are scattered, not wall to wall: %.1f%% of land tiles" % (100.0 * total / land))
	# nodes of the same kind come in groves: the forest's trees clump
	var forest: Array = sample["forest"]
	var near := 0
	var trees := 0
	for t in forest:
		if t["node"].is_empty():
			continue
		trees += 1
		if not GameWorldGen.tile(d, int(t["x"]) + 1, int(t["z"]))["node"].is_empty() or not GameWorldGen.tile(d, int(t["x"]), int(t["z"]) + 1)["node"].is_empty():
			near += 1
	var base := float(trees) / forest.size()
	ok(trees > 50 and float(near) / trees > base * 1.4, "nodes clump into groves: beside a node there is another %.0f%% of the time, against %.0f%% anywhere in the forest" % [100.0 * near / maxf(1, trees), 100.0 * base])
	# the same seed places the same nodes, another seed other ones
	var same := 0
	var other := dyn(41)
	var differ := 0
	for i in 500:
		var x := 100 + i
		var z := 200 + (i * 7) % 300
		var a: Dictionary = GameWorldGen.tile(d, x, z)["node"]
		if GameWorldGen.tile(dyn(), x, z)["node"] == a:
			same += 1
		if GameWorldGen.tile(other, x, z)["node"] != a:
			differ += 1
	ok(same == 500 and differ > 20, "the same seed places the same nodes (%d of 500), another seed others (%d differ)" % [same, differ])


# ---------------------------------------------------------------- chunks

func test_chunks() -> void:
	var d := dyn()
	var c := GameWorldGen.chunk(d, 10, 12)
	ok(c["size"] == 16 and c["tiles"].size() == 16 and c["tiles"][0].size() == 16 and c["cx"] == 10 and c["cz"] == 12, "a chunk is 16 by 16 tiles")
	var agree := true
	for dz in 16:
		for dx in 16:
			if c["tiles"][dz][dx] != GameWorldGen.tile(d, 160 + dx, 192 + dz):
				agree = false
	ok(agree, "every tile of a chunk is the tile the world gives at that place")
	var count := 0
	for b in c["summary"]["biomes"]:
		count += int(c["summary"]["biomes"][b])
	ok(count == 256, "the summary counts every tile")
	var nodes := 0
	for dz in 16:
		for dx in 16:
			if not c["tiles"][dz][dx]["node"].is_empty():
				nodes += 1
	var summed := 0
	for k in c["summary"]["nodes"]:
		summed += int(c["summary"]["nodes"][k])
	ok(summed == nodes, "and every node")
	ok(GameWorldGen.chunk(d, 10, 12) == c and GameWorldGen.chunk(d, 11, 12) != c, "a chunk is the same each time, and its neighbour is not it")
	var out := GameWorldGen.chunk(d, -1, 0)
	ok(out["summary"]["water"] == 256 and out["summary"]["biomes"].keys() == ["ocean"], "a chunk outside the world is all sea")
	var edge := GameWorldGen.chunk(d, 0, 0)
	ok(edge["summary"]["water"] > 40, "a chunk at the corner is mostly sea: %d of 256" % edge["summary"]["water"])
	# the chunk with a town in it
	var h := GameWorldGen.anchor("hearthmere")
	var tc := GameWorldGen.chunk(d, int(h["x"]) / 16, int(h["z"]) / 16)
	var marked := 0
	for row in tc["tiles"]:
		for t in row:
			if t["place"] == "hearthmere":
				marked += 1
	ok(marked == 1, "the chunk with Hearthmere in it carries its mark once")


func test_untouched() -> void:
	var d := dyn()
	var before := d.rng.state
	var save_before := JSON.stringify(d.to_dict())
	for i in 20:
		GameWorldGen.chunk(d, i % 10, i / 2)
	ok(d.rng.state == before and JSON.stringify(d.to_dict()) == save_before, "generating the world draws nothing from the dynasty's dice and changes nothing that is saved")
	ok(not d.to_dict().has("world_tiles") and not d.to_dict().has("mine"), "and saves nothing of its own")
