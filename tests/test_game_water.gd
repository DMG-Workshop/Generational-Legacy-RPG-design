## Rivers, lakes and fords (open-world terrain; core/game/game_worldgen.gd `_water`, data/world/worldgen.json settings.water):
## each seed's world has a sea, lakes and rivers in sensible shares; an anchor's ground is dry; rivers have a valley, thin out up
## the heights and cross at fords; a lake lies on low ground; a walker cannot cross a river or a lake but can use a ford; the
## roads leave a causeway where they cross water; the land between the places stays connected; the map shows seas and lakes; the view draws them; the data checks.
## Run: godot --headless --path . -s res://tests/test_game_water.gd
extends SceneTree

var fails := 0
var checks := 0
const SEEDS := [77, 5, 12]


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	test_shares()
	test_anchors_dry()
	test_sea_rule()
	test_valleys_and_lakes()
	test_fords()
	test_walking()
	test_roads()
	test_routes()
	test_connected()
	test_map_and_view()
	test_pure()
	test_data()
	print("water tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## Tiles of a seed's whole world on a grid `step` apart, by body: {body: [Vector2i, ...]}.
func _scan(seed_value: int, step: int) -> Dictionary:
	var out := {}
	var n := GameWorldGen.size()
	for z in range(0, n, step):
		for x in range(0, n, step):
			var b := GameWorldGen.body_at(seed_value, x, z)
			if not out.has(b):
				out[b] = []
			out[b].append(Vector2i(x, z))
	return out


func _share(scan: Dictionary, body: String) -> float:
	var total := 0
	for k in scan:
		total += (scan[k] as Array).size()
	return float((scan.get(body, []) as Array).size()) / float(maxi(1, total))


func test_shares() -> void:
	for sd in SEEDS:
		var scan := _scan(sd, 4)
		for body in ["sea", "lake", "river", "ford", ""]:
			ok(scan.has(body), "seed %d has '%s' in its world" % [sd, body])
		var lake := _share(scan, "lake")
		var river := _share(scan, "river")
		var ford := _share(scan, "ford")
		var sea := _share(scan, "sea")
		ok(lake > 0.01 and lake < 0.09, "seed %d: lakes are %.1f%% of the world" % [sd, lake * 100.0])
		ok(river > 0.01 and river < 0.09, "seed %d: rivers are %.1f%% of the world" % [sd, river * 100.0])
		ok(ford > 0.0 and ford < river, "seed %d: fords are a part of the rivers (%.2f%% against %.1f%%)" % [sd, ford * 100.0, river * 100.0])
		var w: Dictionary = GameWorldGen.setting("water")
		var away := 0
		for p in scan["ford"]:
			if GameWorldGen.road_distance(float(p.x), float(p.y)) > float(w["road_width"]) + 2.0:
				away += 1
		ok(away > 5, "seed %d: and there are fords away from any road, where a river's own shallows are (%d)" % [sd, away])
		ok(sea > 0.03 and sea < 0.15, "seed %d: the sea is %.1f%% of the world" % [sd, sea * 100.0])
		ok(_share(scan, "") > 0.7, "seed %d: most of the world is dry land" % sd)


func test_anchors_dry() -> void:
	var w: Dictionary = GameWorldGen.setting("water")
	for sd in SEEDS:
		var wet := 0
		var looked := 0
		for a in GameWorldGen.anchors():
			var reach := int(float(w["clear_inner"]) + float(a["radius"]))
			for dz in range(-reach, reach + 1, 2):
				for dx in range(-reach, reach + 1, 2):
					if Vector2(dx, dz).length() > float(reach):
						continue
					looked += 1
					var b := GameWorldGen.body_at(sd, int(a["x"]) + dx, int(a["z"]) + dz)
					if b != "":
						wet += 1
		ok(looked > 500 and wet == 0, "seed %d: the ground round every place is dry land (%d wet of %d looked at)" % [sd, wet, looked])
	var d := GameDynasty.new_game(77, "Tess", "warrior", "faetouched", "human")
	for a in GameWorldGen.anchors():
		var t := GameWorldGen.tile(d, int(a["x"]), int(a["z"]))
		ok(not t["water"] and t["body"] == "", "%s stands on dry land" % a["id"])


func test_sea_rule() -> void:
	var sea := int(GameWorldGen.setting("sea_level"))
	for sd in SEEDS:
		var scan := _scan(sd, 5)
		var low_dry := 0
		var high_sea := 0
		for b in scan:
			for p in scan[b]:
				var h := GameWorldGen.height_at(sd, p.x, p.y)
				if (b == "" or b == "ford") and h < sea:
					low_dry += 1
				if b == "sea" and h >= sea:
					high_sea += 1
		ok(low_dry == 0, "seed %d: no dry tile or ford lies under the sea level (%d)" % [sd, low_dry])
		ok(high_sea == 0, "seed %d: the sea is only what lies under the sea level (%d)" % [sd, high_sea])
	var d := GameDynasty.new_game(77, "Tess", "warrior", "faetouched", "human")
	var out := GameWorldGen.tile(d, -3, 40)
	ok(out["water"] and out["body"] == "sea", "outside the world is sea")
	ok(GameWorldGen.is_water("sea") and GameWorldGen.is_water("lake") and GameWorldGen.is_water("river"), "sea, lake and river are water")
	ok(not GameWorldGen.is_water("ford") and not GameWorldGen.is_water(""), "a ford and dry land are not")


func test_valleys_and_lakes() -> void:
	var w: Dictionary = GameWorldGen.setting("water")
	for sd in SEEDS:
		var scan := _scan(sd, 3)
		# Rivers thin out up the heights: none above where they fade to nothing.
		var too_high := 0
		for p in scan["river"]:
			if GameWorldGen.height_at(sd, p.x, p.y) >= int(w["river_fade_to"]):
				too_high += 1
		ok(too_high == 0, "seed %d: no river runs above %d (%d do)" % [sd, int(w["river_fade_to"]), too_high])
		# A river lies in a valley: lower than the ground a few tiles to each side, on the whole.
		var gap := 0.0
		var counted := 0
		var rivers: Array = scan["river"]
		for i in range(0, rivers.size(), maxi(1, rivers.size() / 80)):
			var p: Vector2i = rivers[i]
			var side := 0.0
			var seen := 0
			for off in [Vector2i(10, 0), Vector2i(-10, 0), Vector2i(0, 10), Vector2i(0, -10)]:
				if GameWorldGen.body_at(sd, p.x + off.x, p.y + off.y) == "":
					side += float(GameWorldGen.height_at(sd, p.x + off.x, p.y + off.y))
					seen += 1
			if seen >= 2:
				gap += side / float(seen) - float(GameWorldGen.height_at(sd, p.x, p.y))
				counted += 1
		ok(counted >= 20 and gap / float(counted) >= 1.0, "seed %d: rivers run lower than the land beside them by %.1f on average (%d looked at)" % [sd, gap / float(maxi(1, counted)), counted])
		# Lakes lie on low ground, deeper in the middle than at the edge.
		var lakes: Array = scan["lake"]
		var high := 0
		for p in lakes:
			if GameWorldGen.height_at(sd, p.x, p.y) >= int(w["lake_land_max"]):
				high += 1
		ok(high == 0, "seed %d: no lake lies on high ground (%d do)" % [sd, high])
		var deepest := 999
		for p in lakes:
			deepest = mini(deepest, GameWorldGen.height_at(sd, p.x, p.y))
		ok(deepest <= int(GameWorldGen.setting("sea_level")), "seed %d: the deepest lake bed is at or under the sea level (%d)" % [sd, deepest])
		var d := GameDynasty.new_game(sd, "Tess", "warrior", "faetouched", "human")
		var deep := 0
		var shallow := 0
		for p in lakes:
			if GameRelief.kind(GameWorldGen.tile(d, p.x, p.y)) == "deep":
				deep += 1
			else:
				shallow += 1
		ok(deep > 0 and shallow > 0 and deep < shallow * 3, "seed %d: lakes have a deep middle and shallow edges (%d deep, %d shallow)" % [sd, deep, shallow])
		# A lake's rim is land (it slopes down to the lake but is not a pit under the sea): no sea tile touches a lake that is not at
		# the edge of the world. (A ring of sea round a swampy town once cut Mirefen off.)
		var shore := int(GameWorldGen.setting("shore"))
		var n := GameWorldGen.size()
		var touching := 0
		var rim := 0
		for p in lakes:
			if mini(mini(p.x, p.y), mini(n - 1 - p.x, n - 1 - p.y)) < shore + 6:
				continue
			for off in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
				rim += 1
				if GameWorldGen.body_at(sd, p.x + off.x, p.y + off.y) == "sea":
					touching += 1
		ok(rim > 100 and touching == 0, "seed %d: no sea touches a lake inland (%d of %d)" % [sd, touching, rim])
		# The valley and the lake bank are slopes a walker can take, not cliffs.
		var steep := 0
		var looked := 0
		for b in ["river", "lake"]:
			var list: Array = scan[b]
			for i in range(0, list.size(), maxi(1, list.size() / 150)):
				var p: Vector2i = list[i]
				var h := GameWorldGen.height_at(sd, p.x, p.y)
				for off in [Vector2i(1, 0), Vector2i(0, 1)]:
					looked += 1
					if absi(GameWorldGen.height_at(sd, p.x + off.x, p.y + off.y) - h) > 4:
						steep += 1
		ok(looked > 100 and steep * 100 <= looked, "seed %d: next to no cliffs beside the water (%d steep of %d; the hills were always steep)" % [sd, steep, looked])


func test_fords() -> void:
	var sd: int = SEEDS[0]
	var d := GameDynasty.new_game(sd, "Tess", "warrior", "faetouched", "human")
	var scan := _scan(sd, 3)
	var ford: Vector2i = scan["ford"][scan["ford"].size() / 2]
	var t := GameWorldGen.tile(d, ford.x, ford.y)
	ok(t["body"] == "ford" and not t["water"], "a ford is shallow water that is not water to a walker")
	ok(GameRelief.kind(t) == "ford" and TileView.kind_for(t, "") == "ford", "and is drawn as a ford")
	var ground := GamePath.world_ground(d)
	var walker: Dictionary = GamePath.data()["movers"]["walker"]
	var swimmer: Dictionary = GamePath.data()["movers"]["swimmer"]
	ok(GamePath.passable(ground, Vector3i(ford.x, GamePath.SURFACE, ford.y), walker) or GameWorldGen.tile(d, ford.x, ford.y)["node"].size() > 0, "a walker can stand on a ford (unless a tree stands on it)")
	var river: Vector2i = scan["river"][scan["river"].size() / 2]
	var lake: Vector2i = scan["lake"][scan["lake"].size() / 2]
	for p in [river, lake]:
		ok(not GamePath.passable(ground, Vector3i(p.x, GamePath.SURFACE, p.y), walker), "a walker cannot stand in %s" % GameWorldGen.body_at(sd, p.x, p.y))
		ok(GamePath.passable(ground, Vector3i(p.x, GamePath.SURFACE, p.y), swimmer), "but a swimmer can")
	var dry: Vector2i = scan[""][scan[""].size() / 3]
	ok(not GameWorldGen.water_at(sd, dry.x, dry.y), "dry land is not water")


func test_walking() -> void:
	# The heir cannot step into a river or a lake, and can step onto a ford.
	var sd: int = SEEDS[0]
	var d := GameDynasty.new_game(sd, "Tess", "warrior", "faetouched", "human")
	var scan := _scan(sd, 2)
	var s := GameSandbox.start(d)
	var found := {"river": false, "lake": false, "ford": false}
	for body in ["river", "lake", "ford"]:
		for p in scan[body]:
			var bank := Vector2i(-1, -1)
			for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = p + off
				if GameWorldGen.in_bounds(q.x, q.y) and GameWorldGen.body_at(sd, q.x, q.y) == "" and GameWorldGen.tile(d, q.x, q.y)["node"].is_empty() and absi(GameWorldGen.height_at(sd, q.x, q.y) - GameWorldGen.height_at(sd, p.x, p.y)) <= 1:
					bank = q
					break
			if bank.x < 0 or not GameWorldGen.tile(d, p.x, p.y)["node"].is_empty():
				continue
			s.heir = bank
			var dx: int = p.x - bank.x
			var dz: int = p.y - bank.y
			var c := s.can_step(dx, dz)
			if body == "ford":
				ok(c["ok"], "the heir can wade onto a ford at %s" % str(p))
			else:
				ok(not c["ok"], "the heir cannot walk into a %s at %s" % [body, str(p)])
			found[body] = true
			break
	ok(found["river"] and found["lake"] and found["ford"], "(tried a river, a lake and a ford)")


func test_routes() -> void:
	# Places are joined: a walker finds its way between places across the rivers (round them or by a ford). (Whisperwood is left out:
	# on seed 77 its forest walls it off from Hearthmere with or without water.)
	for sd in [77, 5]:
		var d := GameDynasty.new_game(sd, "Tess", "warrior", "faetouched", "human")
		var ground := GamePath.world_ground(d)
		var home := GameWorldGen.anchor("hearthmere")
		for other in ["greenvale", "ironford"]:
			var a := GameWorldGen.anchor(other)
			var r := GamePath.find(ground, Vector3i(int(home["x"]), GamePath.SURFACE, int(home["z"])), Vector3i(int(a["x"]), GamePath.SURFACE, int(a["z"])), "walker", 60000)
			ok(bool(r["found"]), "seed %d: a walker finds the way from Hearthmere to %s" % [sd, other])


func test_roads() -> void:
	var roads := GameWorldGen.roads()
	var links := {}
	for l in GameData.world["locations"]:
		for link in l.get("links", []):
			var a := str(l["id"])
			var b := str(link["to"])
			links[a + ">" + b if a < b else b + ">" + a] = true
	ok(roads.size() == links.size() and roads.size() >= 16, "every road of the text game is a line (%d of %d)" % [roads.size(), links.size()])
	var home := GameWorldGen.anchor("hearthmere")
	var green := GameWorldGen.anchor("greenvale")
	var mid := Vector2((float(home["x"]) + float(green["x"])) * 0.5, (float(home["z"]) + float(green["z"])) * 0.5)
	ok(GameWorldGen.road_distance(float(home["x"]), float(home["z"])) < 0.01 and GameWorldGen.road_distance(mid.x, mid.y) < 0.01, "a road's ends and middle are on it")
	ok(GameWorldGen.road_distance(float(home["x"]) + 3.0, float(home["z"]) + 400.0) > 20.0, "and a point far from every road is far from it")
	var w: Dictionary = GameWorldGen.setting("water")
	for sd in SEEDS:
		var wet := 0
		var fords := 0
		var steps := 0
		for r in roads:
			var a := Vector2(float(r[0]), float(r[1]))
			var b := Vector2(float(r[2]), float(r[3]))
			var n := int(a.distance_to(b))
			for i in n + 1:
				var p := a.lerp(b, float(i) / float(maxi(1, n)))
				var body := GameWorldGen.body_at(sd, roundi(p.x), roundi(p.y))
				steps += 1
				if body == "river" or body == "lake":
					wet += 1
				if body == "ford":
					fords += 1
		ok(steps > 1000 and wet == 0, "seed %d: no river or lake lies across a road (%d wet of %d steps)" % [sd, wet, steps])
		ok(fords > 0, "seed %d: and the roads do cross water, at fords (%d)" % [sd, fords])
	# The causeway is as wide as the data says and is only where there is water to cross.
	ok(float(w["road_width"]) >= 1.0, "(the causeway is at least a tile wide)")


func _flood(sd: int) -> Dictionary:
	# Every tile of the world a walker can reach from Hearthmere, by the walker's own climb and drop and no corner cutting
	# (trees and rocks aside). Returns {reached: set of anchor ids reached, share: of dry land}.
	var n := GameWorldGen.size()
	var mv: Dictionary = GamePath.data()["movers"]["walker"]
	var up := int(mv["max_climb"])
	var down := int(mv["max_drop"])
	var hs := PackedInt32Array()
	hs.resize(n * n)
	var dry := PackedByteArray()
	dry.resize(n * n)
	for z in n:
		for x in n:
			hs[z * n + x] = GameWorldGen.height_at(sd, x, z)
			dry[z * n + x] = 0 if GameWorldGen.water_at(sd, x, z) else 1
	var start := GameWorldGen.anchor("hearthmere")
	var seen := PackedByteArray()
	seen.resize(n * n)
	var q: Array = [int(start["z"]) * n + int(start["x"])]
	seen[q[0]] = 1
	var head := 0
	while head < q.size():
		var c: int = q[head]
		head += 1
		var cx := c % n
		var cz := c / n
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				var nx := cx + dx
				var nz := cz + dz
				if nx < 0 or nz < 0 or nx >= n or nz >= n:
					continue
				var ni := nz * n + nx
				if seen[ni] == 1 or dry[ni] == 0:
					continue
				if dx != 0 and dz != 0 and (dry[cz * n + nx] == 0 or dry[nz * n + cx] == 0):
					continue
				var dh := hs[ni] - hs[c]
				if dh > up or -dh > down:
					continue
				seen[ni] = 1
				q.append(ni)
	var reached := {}
	for a in GameWorldGen.anchors():
		if seen[int(a["z"]) * n + int(a["x"])] == 1:
			reached[str(a["id"])] = true
	var land := 0
	var got := 0
	for i in n * n:
		if dry[i] == 1:
			land += 1
			if seen[i] == 1:
				got += 1
	return {"reached": reached, "share": float(got) / float(land)}


func test_connected() -> void:
	# The seeds whose rivers and lakes once cut a place off (14: Mirefen and the Sunken Temple; 24: Greenvale).
	for sd in [14, 24]:
		var r := _flood(sd)
		var lost: Array = []
		for a in GameWorldGen.anchors():
			if not r["reached"].has(str(a["id"])):
				lost.append(str(a["id"]))
		ok(lost.is_empty(), "seed %d: a walker can reach every place from Hearthmere over the land (cut off: %s)" % [sd, str(lost)])
		ok(float(r["share"]) > 0.97, "seed %d: and nearly all the dry land (%.1f%%)" % [sd, float(r["share"]) * 100.0])


func test_map_and_view() -> void:
	var sd: int = SEEDS[0]
	var d := GameDynasty.new_game(sd, "Tess", "warrior", "faetouched", "human")
	var step := int(GameWorldMap.setting("step"))
	var lake_cell := Vector2i(-1, -1)
	var river_cell := Vector2i(-1, -1)
	for cz in GameWorldMap.cells():
		for cx in GameWorldMap.cells():
			var t := GameWorldMap.tile_of(cx, cz)
			var b := GameWorldGen.body_at(sd, t.x, t.y)
			if b == "lake" and lake_cell.x < 0:
				lake_cell = Vector2i(cx, cz)
			if b == "river" and river_cell.x < 0:
				river_cell = Vector2i(cx, cz)
	ok(lake_cell.x >= 0 and GameWorldMap.kind_at(d, lake_cell.x, lake_cell.y) == "water", "the world map shows a lake as water")
	ok(river_cell.x >= 0 and GameWorldMap.kind_at(d, river_cell.x, river_cell.y) != "water", "and leaves a river out (it is narrower than a cell of %d)" % step)
	var kinds := TileView.kinds()
	ok(kinds.has("ford") and TileView.settings()["colors"].has("ford"), "a ford is a kind with a colour")
	ok(TileView.kind_for({"water": true, "body": "lake", "height": int(GameWorldGen.setting("sea_level")) - 5, "biome": "plains"}, "") == "deep", "a lake bed well under the sea level is drawn deep")
	ok(TileView.kind_for({"water": true, "body": "river", "height": int(GameWorldGen.setting("sea_level")) + 3, "biome": "plains"}, "") == "water", "a river is drawn as shallow water")


func test_pure() -> void:
	var sd: int = SEEDS[0]
	var probe: Array = []
	for i in 60:
		probe.append(Vector2i(20 + i * 10, 60 + (i * 37) % 500))
	var first: Array = []
	for p in probe:
		first.append(GameWorldGen.body_at(sd, p.x, p.y) + str(GameWorldGen.height_at(sd, p.x, p.y)))
	GameWorldGen._surf.clear()
	for i in probe.size():
		ok(GameWorldGen.body_at(sd, probe[i].x, probe[i].y) + str(GameWorldGen.height_at(sd, probe[i].x, probe[i].y)) == first[i], "a tile's water is the same with the kept tiles cleared (%s)" % str(probe[i]))
	var differs := 0
	for p in probe:
		if GameWorldGen.body_at(sd, p.x, p.y) != GameWorldGen.body_at(sd + 1, p.x, p.y):
			differs += 1
	var other := _scan(sd + 1, 8)
	var mine := _scan(sd, 8)
	ok(differs > 0 or (other.get("river", []) as Array) != (mine.get("river", []) as Array), "another seed lays its water differently")
	var d := GameDynasty.new_game(sd, "Tess", "warrior", "faetouched", "human")
	var before := d.rng.state
	for i in 50:
		GameWorldGen.tile(d, 100 + i * 7, 300 + i * 3)
	ok(d.rng.state == before, "water draws no die of the dynasty's")


func test_data() -> void:
	ok(GameWorldGen.validate().is_empty(), "the world data is sound: %s" % str(GameWorldGen.validate()))
	var w: Dictionary = GameWorldGen.setting("water")
	var cases := [["clear_inner", 0.5], ["clear_outer", 1.0], ["wet_scale", 0.0], ["river_scale", 0.0], ["lake_scale", -1.0], ["ford_scale", 0.0],
		["river_octaves", 0], ["lake_octaves", 0], ["wet_from", 0.9], ["wet_to", 1.5], ["river_width", 0.0], ["river_width", 0.6], ["valley_width", 0.01],
		["valley_width", 1.0], ["valley_depth", -1.0], ["valley_depth", 40.0], ["river_fade_from", 10.0], ["river_fade_to", 50.0],
		["lake_threshold", 0.0], ["lake_threshold", 0.99], ["lake_band", 0.0], ["lake_depth", 0.0], ["lake_water_at", 0.0], ["lake_water_at", 1.5],
		["lake_land_max", 20.0], ["ford_threshold", 0.0], ["ford_threshold", 1.0]]
	cases.append(["road_width", 0.5])
	cases.append(["road_width", 9.0])
	for c in cases:
		var keep: Variant = w[c[0]]
		w[c[0]] = c[1]
		ok(not GameWorldGen.validate().is_empty(), "%s of %s is refused" % [c[0], str(c[1])])
		w[c[0]] = keep
	var gone: Variant = w["ford_scale"]
	w.erase("ford_scale")
	ok(not GameWorldGen.validate().is_empty(), "a missing water setting is refused")
	w["ford_scale"] = gone
	ok(GameWorldGen.validate().is_empty(), "and the data is back as it was")
