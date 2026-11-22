## The walls and gates round the four towns (core/game/game_walls.gd, data/world/walls.json, ui/play/wall_art.gd) and the guards at every
## gate (core/game/game_villagers.gd, `guards`): a ring of wall tiles round each town that blocks a walker except at its gates, past every
## building and on dry flat ground; each road leaves by a gate; a cart-wide passage with a tower either side; no tree on the wall or in a
## gate's way; every place and the homestead plot still reachable from Hearthmere through the gates; A* routes via the gates (villagers'
## field trips, the heir's routes); creatures keep off the wall; two guards at every gate at every hour; and breaks of each rule.
## Run: godot --headless --path . -s res://tests/test_game_walls.gd
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
	test_ring()
	test_gates()
	test_ground()
	test_trees()
	test_routes()
	test_world_reach()
	test_creatures_and_heir()
	test_guards()
	test_night_gates()
	test_breaks()
	test_art()
	print("walls tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(seed_value: int = 77) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


func _fresh() -> void:
	GameWalls.reload()


func test_ring() -> void:
	ok(GameWalls.validate().is_empty(), "the data is sound: %s" % str(GameWalls.validate()))
	var towns := GameTown.towns()
	ok(GameWalls.walled().size() == 4 and towns.size() == 4, "all four towns have a wall")
	for place in towns:
		ok(GameWalls.walled().has(place), "%s has a wall" % place)
		var a := GameWorldGen.anchor(place)
		var ax := int(a["x"])
		var az := int(a["z"])
		var r := GameWalls.radius(place)
		var walls := 0
		var far := 0.0
		var near := 1e9
		for key in GameWalls.tiles(place):
			var p := (key as String).split(",")
			var x := int(p[0])
			var z := int(p[1])
			var dist := Vector2(x - ax, z - az).length()
			far = maxf(far, dist)
			near = minf(near, dist)
			if GameWalls.blocks(x, z):
				walls += 1
				ok(not GamePath.passable(GamePath.world_ground(_dyn()), Vector3i(x, -1, z), GamePath.data()["movers"]["walker"]), "%s: a wall tile at %d,%d stops a walker" % [place, x, z])
		ok(walls > 150, "%s's wall has %d solid tiles, a ring of some length" % [place, walls])
		ok(far <= r and near > r - float(GameWalls.setting("thickness")) - 0.01, "%s: the ring lies between %.1f and %.1f of the anchor" % [place, near, far])
		# every building tile and door is inside, with ground to spare
		for b in GameTown.buildings(place):
			var worst := 0.0
			for dz in int(b["h"]):
				for dx in int(b["w"]):
					worst = maxf(worst, Vector2(int(b["x"]) + dx - ax, int(b["z"]) + dz - az).length())
			ok(worst < near - 1.0, "%s: %s (to %.1f) is inside the wall (from %.1f)" % [place, b["id"], worst, near])
			var dd: Vector2i = b["door"]
			ok(Vector2(dd.x - ax, dd.y - az).length() < near - 1.0, "%s: the door of %s is inside" % [place, b["id"]])
		# the anchor and every service door stand free, and the family's house is inside
		ok(not GameWalls.blocks(ax, az), "%s: the anchor is not a wall" % place)
		# no wall tile is a building tile
		for key in GameWalls.tiles(place):
			var p2 := (key as String).split(",")
			ok(not GameTown.blocks(int(p2[0]), int(p2[1])), "%s: a wall does not stand on a building" % place)
			break
	# the ring is sealed with the gates shut and open through each gate
	for place in towns:
		var a2 := GameWorldGen.anchor(place)
		var centre := Vector2i(int(a2["x"]), int(a2["z"]))
		var far_out := centre + Vector2i(int(GameWalls.radius(place)) + 3, int(GameWalls.radius(place)) + 3)
		ok(not GameWalls.reaches(place, centre, far_out, false), "%s: with the gates shut nobody walks out" % place)
		for g in GameWalls.gates(place):
			ok(GameWalls.reaches(place, centre, g["outer"], true), "%s: the centre of town reaches outside by %s" % [place, g["id"]])


func test_gates() -> void:
	var home_roads := 0
	for place in GameWalls.walled():
		var list := GameWalls.gates(place)
		ok(list.size() >= 2, "%s has at least two gates (%d)" % [place, list.size()])
		var sides := {}
		for g in list:
			ok(not sides.has(str(g["side"])), "%s: one gate to a side" % place)
			sides[str(g["side"])] = true
			var cols := {}
			for t in g["tiles"]:
				cols[t.x if str(g["axis"]) == "ns" else t.y] = true
				ok(not GameWalls.blocks(t.x, t.y) and GameWalls.kind_at(t.x, t.y) == "gate", "%s: the passage tile %s is open" % [g["id"], str(t)])
			ok(cols.size() == int(GameWalls.setting("gate_width")) and cols.size() >= 3, "%s is %d tiles wide, a cart passes" % [g["id"], cols.size()])
			# a tower beside the passage on each side
			var c: Vector2i = g["centre"]
			var tang := Vector2i(1, 0) if str(g["axis"]) == "ns" else Vector2i(0, 1)
			var towers := 0
			var sides_with := {}
			for key in GameWalls.tiles(place):
				var rec: Dictionary = GameWalls.tiles(place)[key]
				if str(rec["k"]) not in ["tower", "jamb"]:
					continue
				var pp := (key as String).split(",")
				var t := Vector2i(int(pp[0]), int(pp[1]))
				var off: int = (t - c).x * tang.x + (t - c).y * tang.y
				if absi(off) >= 2 and absi(off) < 2 + int(GameWalls.setting("tower_len")) and absi((t - c).x * (1 - tang.x) + (t - c).y * (1 - tang.y)) <= 2:
					towers += 1
					sides_with[signi(off)] = true
			ok(sides_with.size() == 2, "%s has a tower on each side" % g["id"])
			ok(towers >= 2, "%s has towers either side of its passage (%d)" % [g["id"], towers])
			ok(not GameWalls.blocks(g["inner"].x, g["inner"].y) and not GameWalls.blocks(g["outer"].x, g["outer"].y), "%s: the tiles before and behind the passage are open" % g["id"])
			ok(GameWalls.gate_at(c.x, c.y)["id"] == g["id"], "%s: gate_at finds it" % g["id"])
			ok(GameWalls.gate_near(float(c.x) + 0.5, float(c.y) + 0.5, 2.0)["id"] == g["id"], "%s: gate_near finds it" % g["id"])
			ok(GameWalls.road_of(g) != "", "%s: a road runs out of it (%s)" % [g["id"], GameWalls.road_of(g)])
		# each road that leaves the town has a gate where it leaves (within road_angle degrees)
		for road in GameWalls.roads_from(place):
			var found := false
			for g in list:
				if GameWalls._angle_diff(float(road["angle"]), float(GameWalls.ANGLES[str(g["side"])])) <= float(GameWalls.setting("road_angle")):
					found = true
			ok(found, "%s: the road to %s has its gate" % [place, road["to"]])
		if place == "hearthmere":
			home_roads = list.size()
	ok(home_roads == 4, "Hearthmere has four gates (north, east, south, west)")


func test_ground() -> void:
	# on every seed the wall stands on dry ground within a step or two of the town's own height; a gate's passage too
	for sd in [3, 14, 24, 99, 555]:
		for place in GameWalls.walled():
			var a := GameWorldGen.anchor(place)
			var h0 := GameWorldGen.height_at(sd, int(a["x"]), int(a["z"]))
			var wet := 0
			var uneven := 0
			for key in GameWalls.tiles(place):
				var p := (key as String).split(",")
				var x := int(p[0])
				var z := int(p[1])
				if GameWorldGen.water_at(sd, x, z):
					wet += 1
				if absi(GameWorldGen.height_at(sd, x, z) - h0) > int(GameWalls.setting("max_step")):
					uneven += 1
			ok(wet == 0 and uneven == 0, "seed %d: %s's wall is on dry, flat ground (%d wet, %d uneven)" % [sd, place, wet, uneven])
	# the ground in front of and behind each gate is dry on the town's side and for the first tiles outside
	for sd in [14, 77]:
		for g in GameWalls.all_gates():
			var o: Vector2i = g["outer"]
			ok(not GameWorldGen.water_at(sd, o.x, o.y) and not GameWorldGen.water_at(sd, g["inner"].x, g["inner"].y), "seed %d: %s opens onto dry ground" % [sd, g["id"]])


func test_trees() -> void:
	for sd in [1, 14, 77, 123]:
		var d := _dyn(sd)
		var trees := 0
		var checked := 0
		for place in GameWalls.walled():
			for key in GameWalls.tiles(place):
				var p := (key as String).split(",")
				var x := int(p[0])
				var z := int(p[1])
				checked += 1
				var biome := GameWorldGen.biome_at(sd, x, z)
				if not GameWorldGen.node_at(d, x, z, biome, false).is_empty():
					trees += 1
			for g in GameWalls.gates(place):
				var dir: Vector2i = g["dir"]
				for i in range(int(GameWalls.setting("approach"))):
					var t: Vector2i = g["outer"] + dir * i
					checked += 1
					if not GameWorldGen.node_at(d, t.x, t.y, GameWorldGen.biome_at(sd, t.x, t.y), false).is_empty():
						trees += 1
		ok(checked > 800 and trees == 0, "seed %d: no tree or rock on the wall or in the way of a gate (%d of %d tiles)" % [sd, trees, checked])
	# and the rule is the wall's, not a gap in the world: a tile well outside any wall can still hold a node
	var d2 := _dyn(77)
	var any := false
	for x in range(300, 400):
		for z in range(180, 260):
			if not GameWalls.cleared(x, z) and not GameWorldGen.in_anchor_ground(x, z) and not GameWorldGen.node_at(d2, x, z, GameWorldGen.biome_at(77, x, z), GameWorldGen.water_at(77, x, z)).is_empty():
				any = true
	ok(any, "(trees still grow in the open country)")


func test_routes() -> void:
	var d := _dyn()
	var ground := GamePath.world_ground(d, {})
	for g in GameWalls.all_gates():
		var a := GameWorldGen.anchor(str(g["place"]))
		var from := Vector3i(int(a["x"]), -1, int(a["z"]))
		var to := Vector3i(g["outer"].x, -1, g["outer"].y)
		var f := GamePath.find(ground, from, to, "walker", 6000)
		ok(bool(f.get("found", false)), "%s: a walker finds the way out from the anchor" % g["id"])
		if not bool(f.get("found", false)):
			continue
		var through := false
		var bad := 0
		for c in f["path"]:
			if GameWalls.kind_at(c.x, c.z) == "gate":
				through = true
			if GameWalls.blocks(c.x, c.z):
				bad += 1
		ok(through and bad == 0, "%s: the way runs through the passage and over no wall" % g["id"])
	# a tile just outside a wall, far from every gate, is reached only by going round to a gate: the way is longer than straight
	var a2 := GameWorldGen.anchor("hearthmere")
	var north := Vector3i(int(a2["x"]), -1, int(a2["z"]) - 29)
	var south := Vector3i(int(a2["x"]) + 12, -1, int(a2["z"]) + 27)
	var f2 := GamePath.find(ground, Vector3i(int(a2["x"]), -1, int(a2["z"])), south, "walker", 8000)
	ok(bool(f2.get("found", false)) and float(f2["cost"]) > 27.0 + 5.0, "a tile outside the wall away from a gate costs more than the straight line (%s)" % str(f2.get("cost")))
	ok(bool(GamePath.find(ground, Vector3i(int(a2["x"]), -1, int(a2["z"])), north, "walker", 8000).get("found", false)), "and the north gate leads there")
	# the family's homestead plot, outside the town, is reached from the heart of Hearthmere through a gate
	var plot := GameWorldGen.plot("hearthmere")
	var pf := GamePath.find(ground, Vector3i(int(a2["x"]), -1, int(a2["z"])), Vector3i(int(plot["x"]), -1, int(plot["z"])), "walker", 9000)
	ok(bool(pf.get("found", false)), "the homestead plot is reachable from Hearthmere")
	var via := false
	for c in pf.get("path", []):
		if GameWalls.kind_at(c.x, c.z) == "gate":
			via = true
	ok(via, "(and the way to it is through a gate)")
	# a flier crosses a wall (the movers' own rule), so the wall is no cage for what flies
	var wall := Vector2i(-1, -1)
	for key in GameWalls.tiles("hearthmere"):
		if GameWalls.blocks(int((key as String).split(",")[0]), int((key as String).split(",")[1])):
			var p := (key as String).split(",")
			wall = Vector2i(int(p[0]), int(p[1]))
			break
	ok(GamePath.passable(ground, Vector3i(wall.x, -1, wall.y), GamePath.data()["movers"]["flier"]), "a flier passes over a wall")
	# villagers' trips: a farmer's field is outside the wall and the trip to it runs through a gate, over no wall
	var checked := 0
	for b in GameTown.all():
		if str(b["kind"]) != "house":
			continue
		var who := GameVillagers.residents(b)
		for i in who.size():
			var trip := GameVillagers.trip_of(d, b, i)
			if trip.is_empty() or str(trip["work"]) != "field":
				continue
			checked += 1
			var gate := false
			var wall_hit := 0
			for pt in trip["path"]:
				var tx := int(floor((pt as Vector2).x))
				var tz := int(floor((pt as Vector2).y))
				if GameWalls.kind_at(tx, tz) == "gate":
					gate = true
				if GameWalls.blocks(tx, tz):
					wall_hit += 1
			ok(gate and wall_hit == 0, "%s's farmer %d walks to the field through a gate, over no wall" % [b["id"], i])
			if checked >= 12:
				break
		if checked >= 12:
			break
	ok(checked >= 6, "(%d farmers' trips were checked)" % checked)
	# the other jobs' trips stay inside the town (a service or a patrol) and still exist
	var inside := 0
	for b in GameTown.buildings("hearthmere"):
		if str(b["kind"]) != "house":
			continue
		for i in GameVillagers.residents(b).size():
			var tr := GameVillagers.trip_of(d, b, i)
			if not tr.is_empty() and str(tr["work"]) != "field":
				inside += 1
	ok(inside > 0, "Hearthmere's other trips (to the services and the patrol) still run (%d)" % inside)


## The land a walker can reach from Hearthmere over the dry land, with the wall and the buildings in the way.
func _flood(sd: int) -> Dictionary:
	var n := GameWorldGen.size()
	var mv: Dictionary = GamePath.data()["movers"]["walker"]
	var up := int(mv["max_climb"])
	var down := int(mv["max_drop"])
	var hs := PackedInt32Array()
	hs.resize(n * n)
	var open := PackedByteArray()
	open.resize(n * n)
	for z in n:
		for x in n:
			hs[z * n + x] = GameWorldGen.height_at(sd, x, z)
			open[z * n + x] = 0 if GameWorldGen.water_at(sd, x, z) else 1
	for place in GameWalls.walled():
		for key in GameWalls.tiles(place):
			var p := (key as String).split(",")
			if GameWalls.blocks(int(p[0]), int(p[1])):
				open[int(p[1]) * n + int(p[0])] = 0
	for b in GameTown.all():
		for dz in int(b["h"]):
			for dx in int(b["w"]):
				open[(int(b["z"]) + dz) * n + int(b["x"]) + dx] = 0
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
				if seen[ni] == 1 or open[ni] == 0:
					continue
				if dx != 0 and dz != 0 and (open[cz * n + nx] == 0 or open[nz * n + cx] == 0):
					continue
				var dh := hs[ni] - hs[c]
				if dh > up or -dh > down:
					continue
				seen[ni] = 1
				q.append(ni)
	return {"seen": seen, "n": n}


func test_world_reach() -> void:
	for sd in [14, 24, 77]:
		var r := _flood(sd)
		var seen: PackedByteArray = r["seen"]
		var n: int = r["n"]
		var lost: Array = []
		for a in GameWorldGen.anchors():
			if seen[int(a["z"]) * n + int(a["x"])] != 1:
				lost.append(str(a["id"]))
		ok(lost.is_empty(), "seed %d: with the walls up a walker still reaches every place from Hearthmere (cut off: %s)" % [sd, str(lost)])
		var plot := GameWorldGen.plot("hearthmere")
		ok(seen[int(plot["z"]) * n + int(plot["x"])] == 1, "seed %d: and the family's homestead plot" % sd)
		# every town's every door is reached too
		var unreached := 0
		for b in GameTown.all():
			var dd: Vector2i = b["door"]
			if seen[dd.y * n + dd.x] != 1:
				unreached += 1
		ok(unreached == 0, "seed %d: every door of every town is reached from Hearthmere (%d not)" % [sd, unreached])
		for g in GameWalls.all_gates():
			ok(seen[int(g["outer"].y) * n + int(g["outer"].x)] == 1, "seed %d: outside %s is reached" % [sd, g["id"]])


func test_creatures_and_heir() -> void:
	var d := _dyn()
	var view := GameBehaviour.world_view(d, [], false)
	var w: Callable = view["walkable"]
	var g: Dictionary = GameWalls.gates("hearthmere")[0]
	var c: Vector2i = g["centre"]
	ok(bool(w.call(float(c.x) + 0.5, float(c.y) + 0.5)), "a creature may walk through a gate's passage")
	var wall := Vector2i(-1, -1)
	for key in GameWalls.tiles("hearthmere"):
		var p := (key as String).split(",")
		if GameWalls.blocks(int(p[0]), int(p[1])):
			wall = Vector2i(int(p[0]), int(p[1]))
			break
	ok(not bool(w.call(float(wall.x) + 0.5, float(wall.y) + 0.5)), "but not through the wall")
	# the heir: the sandbox does not let them step into a wall, and a route out of town goes through a gate
	var sb := GameSandbox.start(d)
	var dir: Vector2i = g["dir"]
	sb.heir = g["inner"]
	ok(sb.can_step(dir.x, dir.y)["ok"], "the heir steps from inside a gate into its passage")
	# beside the wall (not at the gate) the way on is blocked
	var a := GameWorldGen.anchor("hearthmere")
	var inner_wall := Vector2i(wall.x, wall.y)
	var step := Vector2i(signi(int(a["x"]) - wall.x), signi(int(a["z"]) - wall.y))
	sb.heir = inner_wall + step
	var out_step := Vector2i(-step.x, -step.y)
	if not GameWalls.blocks(sb.heir.x, sb.heir.y):
		ok(not sb.can_step(out_step.x, out_step.y)["ok"], "the heir cannot step into the wall (%s)" % str(wall))
	var east: Dictionary = {}
	for gg in GameWalls.gates("hearthmere"):
		if str(gg["side"]) == "e":
			east = gg
	sb.heir = Vector2i(int(a["x"]), int(a["z"]))
	var r := sb.set_route(east["outer"])
	ok(bool(r["ok"]) and sb.route.size() > 20, "a route from the middle of Hearthmere to outside its east gate is found (%d steps)" % sb.route.size())
	var through := false
	for t in sb.route:
		if GameWalls.kind_at(t.x, t.y) == "gate":
			through = true
	ok(through, "and it goes through the gate")
	var walked := 0
	while not sb.route.is_empty() and walked < 200:
		if not sb.walk_one():
			break
		walked += 1
	ok(sb.heir == east["outer"], "and the heir walks it out of the gate (%s)" % str(sb.heir))
	# an old save's position inside what is now a wall puts the heir at the place's door, not in the stone
	d.sandbox_at = {"x": wall.x, "z": wall.y, "gen": d.gen, "place": str(d.world.location)}
	var sb2 := GameSandbox.start(d)
	ok(not GameWalls.blocks(sb2.heir.x, sb2.heir.y), "a saved position inside the wall is not used (the heir is at %s)" % str(sb2.heir))
	# the same heir can step out through the passage onto the road side and back in
	sb.heir = east["outer"]
	var back: Vector2i = -east["dir"]
	ok(sb.can_step(back.x, back.y)["ok"], "and step back in")
	# the world's dice are not touched by any of it
	var before := d.rng.state
	GameWalls.gates("hearthmere")
	GameWalls.road_of(g)
	GameVillagers.walkers_near(d, float(c.x), float(c.y), 20.0, 3.0)
	ok(d.rng.state == before, "no die of the dynasty's was drawn")


func test_guards() -> void:
	var d := _dyn()
	var gd: Dictionary = GameVillagers.data()["guards"]
	ok(int(gd["per_shift"]) >= 2, "two guards are on a gate's every shift at least")
	var total := 0
	for g in GameWalls.all_gates():
		var all := GameVillagers.guards(g)
		total += 1
		ok(all.size() >= 2 * (gd["shifts"] as Array).size(), "%s has %d guards over its shifts" % [g["id"], all.size()])
		for k in 48:
			var hour := float(k) / 2.0
			var on := GameVillagers.guards_on(g, hour)
			ok(on.size() >= int(gd["per_shift"]), "%s has %d guards on at %.1f" % [g["id"], on.size(), hour])
			if on.size() < 2:
				break
			for o in on:
				ok(str(o["job"]) == "Gate guard" and str(o["class"]) == "warrior", "a guard of %s is a warrior with the job Gate guard" % g["id"])
				ok(not GameWalls.blocks(int(o["x"]), int(o["z"])), "and stands on open ground")
				ok(Vector2(float(o["x"]), float(o["z"])).distance_to(Vector2(float((g["centre"] as Vector2i).x), float((g["centre"] as Vector2i).y))) < 4.5, "within a few tiles of the passage")
		var colours := {}
		for o in all:
			colours[str(o["color"])] = true
		ok(colours.size() == 1 and colours.keys()[0] == str(gd["colors"][str(g["place"])]), "%s's guards wear the town's colour" % g["id"])
		# the day and the night guards are different people
		var day_ids := GameVillagers.guards_on(g, 12.0).map(func(o): return str(o["id"]))
		var night_ids := GameVillagers.guards_on(g, 0.0).map(func(o): return str(o["id"]))
		ok(not day_ids.any(func(i): return night_ids.has(i)), "%s: different guards by day and by night" % g["id"])
		# they are among the people walkers_near gives, day and night, and are the same ones every time
		var c: Vector2i = g["centre"]
		for hour in [3.0, 12.0, 22.0]:
			var near := GameVillagers.walkers_near(d, float(c.x), float(c.y), 6.0, hour)
			var guards_here := near.filter(func(w): return str(w.get("gate", "")) == str(g["id"]))
			ok(guards_here.size() == int(gd["per_shift"]), "%s: %d guards are drawn at %.0f o'clock" % [g["id"], guards_here.size(), hour])
	ok(total == 14, "there are fourteen gates to guard (%d)" % total)
	# the job is in the jobs system and nobody's house job
	var has_job := false
	for j in GameVillagers.data()["jobs"]:
		if str(j["id"]) == "gate_guard":
			has_job = bool(j.get("post", false)) and int(j["weight"]) == 0 and str(j["name"]) == "Gate guard"
	ok(has_job, "'Gate guard' is a post job with no weight")
	for b in GameTown.all():
		for i in GameVillagers.residents(b).size():
			ok(str(GameVillagers.job_of(b, i).get("id", "")) != "gate_guard", "no house resident draws the post job")
			break
	ok(GameVillagers.on_shift(18.0, 6.0, 23.0) and GameVillagers.on_shift(18.0, 6.0, 2.0) and not GameVillagers.on_shift(18.0, 6.0, 12.0), "a night shift runs past midnight")


## Sets the dynasty's clock to a night or a day (the seconds of the world clock; the day is `day_seconds` long).
func _at(d: GameDynasty, night: bool) -> void:
	var span := float(GameDay.setting("day_seconds"))
	for i in 48:
		d.world_seconds = span * float(i) / 48.0
		if GameDay.is_night(d) == night:
			return


func test_night_gates() -> void:
	ok(bool(GameWalls.setting("shut_at_night")), "the gates shut by night")
	var d := _dyn()
	var g: Dictionary = GameWalls.gates("hearthmere")[1]   # the east gate
	var c: Vector2i = g["centre"]
	var inner: Vector2i = g["inner"]
	var outer: Vector2i = g["outer"]
	_at(d, false)
	ok(not GameWalls.shut_now(d), "by day the gates stand open")
	var day := GamePath.find(GamePath.world_ground(d), Vector3i(inner.x, -1, inner.y), Vector3i(outer.x, -1, outer.y), "walker", 4000)
	ok(bool(day["found"]), "by day a walker goes out by the gate")
	_at(d, true)
	ok(GameWalls.shut_now(d), "by night they are shut")
	var ground := GamePath.world_ground(d)
	ok(not GamePath.passable(ground, Vector3i(c.x, -1, c.y), GamePath.data()["movers"]["walker"]), "a shut gate blocks a walker like the wall")
	var night := GamePath.find(ground, Vector3i(inner.x, -1, inner.y), Vector3i(outer.x, -1, outer.y), "walker", 4000)
	ok(not bool(night["found"]) or float(night["cost"]) > float(day["cost"]) * 3.0, "by night the way out by that gate is shut (another gate may be far)")
	var open := GamePath.world_ground(d, null, GameWorldGen.MINE_SITE, false)
	ok(GamePath.passable(open, Vector3i(c.x, -1, c.y), GamePath.data()["movers"]["walker"]), "villagers' trips are found as if the gates stood open")
	ok(GamePath.ground_stamp(d) != _stamp_at(d, false), "the path cache is cleared when the gates shut")
	_at(d, false)


func _stamp_at(d: GameDynasty, night: bool) -> int:
	var was := d.world_seconds
	_at(d, night)
	var s := GamePath.ground_stamp(d)
	d.world_seconds = was
	return s


func test_breaks() -> void:
	# each rule is broken on purpose and found
	var base: Dictionary = GameWalls.data().duplicate(true)
	var cases := {
		"a wall too small to hold the buildings": func(dd: Dictionary): dd["towns"]["hearthmere"]["radius"] = 22,
		"a wall out on the wet": func(dd: Dictionary): dd["towns"]["kingshold"]["radius"] = 40,
		"one gate only": func(dd: Dictionary): dd["towns"]["ironford"]["gates"] = [{"side": "n", "shift": 0}],
		"a road with no gate": func(dd: Dictionary): dd["towns"]["kingshold"]["gates"] = [{"side": "n", "shift": 0}, {"side": "s", "shift": 0}],
		"two gates on a side": func(dd: Dictionary): dd["towns"]["hearthmere"]["gates"].append({"side": "n", "shift": 3}),
		"a gate far along the wall": func(dd: Dictionary): dd["towns"]["hearthmere"]["gates"][0]["shift"] = 12,
		"a gate that is no side": func(dd: Dictionary): dd["towns"]["hearthmere"]["gates"][0]["side"] = "x",
		"a gate too narrow for a cart": func(dd: Dictionary): dd["settings"]["gate_width"] = 1,
		"an even gate": func(dd: Dictionary): dd["settings"]["gate_width"] = 4,
		"a wall a hair thick": func(dd: Dictionary): dd["settings"]["thickness"] = 0.5,
		"a town with no wall": func(dd: Dictionary): dd["towns"].erase("brinehaven"),
		"a wall round a dungeon": func(dd: Dictionary): dd["towns"]["goblin_warrens"] = {"gates": [{"side": "n", "shift": 0}, {"side": "s", "shift": 0}]},
	}
	for what in cases:
		GameWalls._cache = base.duplicate(true)
		cases[what].call(GameWalls._cache)
		GameWalls.reset()
		ok(not GameWalls.validate().is_empty(), "the checker finds %s" % what)
	_fresh()
	ok(GameWalls.validate().is_empty(), "(the data is whole again after)")
	# guard rules
	var gv: Dictionary = GameVillagers.data().duplicate(true)
	var broken := {
		"one guard a shift": func(dd: Dictionary): dd["guards"]["per_shift"] = 1,
		"no night shift": func(dd: Dictionary): dd["guards"]["shifts"] = [{"id": "day", "from": 6.0, "to": 18.0}],
		"a gap in the shifts": func(dd: Dictionary): dd["guards"]["shifts"] = [{"id": "day", "from": 6.0, "to": 18.0}, {"id": "night", "from": 20.0, "to": 6.0}],
		"a town with no colour": func(dd: Dictionary): dd["guards"]["colors"].erase("ironford"),
		"a guard with no figure": func(dd: Dictionary): dd["guards"]["class"] = "dragon",
		"a post job a house may draw": func(dd: Dictionary): _gate_job(dd)["weight"] = 3,
		"no post job": func(dd: Dictionary): dd["jobs"].erase(_gate_job(dd)),
	}
	for what in broken:
		GameVillagers._cache = gv.duplicate(true)
		broken[what].call(GameVillagers._cache)
		ok(not GameVillagers.validate().is_empty(), "the checker finds %s" % what)
	GameVillagers._cache = gv.duplicate(true)
	ok(GameVillagers.validate().is_empty(), "(and the guards' data is whole again: %s)" % str(GameVillagers.validate()))
	# the sealing check sees a gap: a few tiles taken out of the ring let a walker out with the gates shut
	_fresh()
	var place := "kingshold"
	var a := GameWorldGen.anchor(place)
	var centre := Vector2i(int(a["x"]), int(a["z"]))
	var far_out := centre + Vector2i(int(GameWalls.radius(place)) + 3, int(GameWalls.radius(place)) + 3)
	ok(not GameWalls.reaches(place, centre, far_out, false), "kingshold's wall is sealed")
	var hole := Vector2i(-1, -1)
	for k in GameWalls.tiles(place):
		var p := (k as String).split(",")
		var t := Vector2i(int(p[0]), int(p[1]))
		if str((GameWalls.tiles(place)[k] as Dictionary)["k"]) == "wall" and t.x > centre.x + 12 and t.y > centre.y + 12:
			hole = t
			break
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			var key := "%d,%d" % [hole.x + dx, hole.y + dz]
			if GameWalls.tiles(place).has(key):
				(GameWalls.tiles(place)[key] as Dictionary)["k"] = "gone"
	ok(GameWalls.reaches(place, centre, far_out, false), "a gap in the ring is seen by the check that looks for one")
	_fresh()
	ok(not GameWalls.reaches(place, centre, far_out, false) and GameWalls.validate().is_empty(), "(and the wall is whole again)")


func test_art() -> void:
	ok(WallArt.validate().is_empty(), "the wall art is sound: %s" % str(WallArt.validate()))
	var w := WallArt.image("wall")
	ok(w.get_width() == 16 and w.get_height() == 48, "a wall piece is a tile wide and three tall (%dx%d), a person two" % [w.get_width(), w.get_height()])
	var t := WallArt.image("tower")
	ok(t.get_height() == 64, "a tower is four tiles tall")
	var j1 := WallArt.image("jamb", 0, Color.RED)
	var j2 := WallArt.image("jamb", 0, Color.BLUE)
	var same := true
	for y in j1.get_height():
		for x in j1.get_width():
			if j1.get_pixel(x, y) != j2.get_pixel(x, y):
				same = false
	ok(not same, "the banner takes the town's colour")
	var open_pixels := 0
	for i in [-1, 0, 1]:
		var a := WallArt.image("arch", i)
		for y in a.get_height():
			for x in a.get_width():
				if a.get_pixel(x, y).a == 0.0 and y >= 10:
					open_pixels += 1
	ok(open_pixels > 100, "the arch is open under (%d clear pixels), so a walker is seen through it" % open_pixels)
	ok(WallArt.image("wall", 0) != null and WallArt.texture("wall", 1) != null, "the textures are made")
	ok(WallArt.fade(Vector2i(10, 10), "wall", Vector2(10.5, 9.2)) < 1.0 and WallArt.fade(Vector2i(10, 10), "wall", Vector2(10.5, 14.0)) == 1.0, "a wall fades while the heir stands behind it, not in front")
	var data_back: Dictionary = WallArt.data().duplicate(true)
	WallArt._data["wall_tiles"] = 2
	ok(not WallArt.validate().is_empty(), "a wall under three tiles is found")
	WallArt._data = data_back.duplicate(true)
	WallArt._data["lintel_height"] = 2
	ok(not WallArt.validate().is_empty(), "a lintel too low for a cart is found")
	WallArt._data = data_back
	ok(WallArt.validate().is_empty(), "(whole again)")


## The gate guard's entry in the jobs list (not at a fixed place: the shops add jobs before it).
func _gate_job(dd: Dictionary) -> Dictionary:
	for j in dd["jobs"]:
		if str(j["id"]) == str(dd["guards"]["job"]):
			return j
	return {}
