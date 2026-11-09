## Pathfinding over dug and built ground (roadmap item 49): the data and ways to break it; the cheapest way (checked
## against a plain Dijkstra on random grids), detours round walls and no way when sealed in, the best-effort way to the
## nearest cell, corners not cut, terrain and slope costs, cliffs for walkers and climbers, water and trees for walkers,
## swimmers and fliers; the ground under the surface (a shaft and a tunnel are a way round a wall, and digging changes the
## path), built walls, floors, roads, doors and bridges; the real generated world; creatures using a router to get round a
## wall; and that nothing of the dynasty's moves.
## Run: godot --headless --path . -s res://tests/test_game_path.gd
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
	test_open()
	test_walls()
	test_optimal()
	test_slope_and_water()
	test_underground()
	test_built()
	test_limits()
	test_world()
	test_router()
	print("path tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## A small ground: `size` square, `blocked` (trees) and `water` cells, a height and biome by function, dug cells and a built overlay.
func _ground(size: int, blocked: Dictionary = {}, water: Dictionary = {}, height: Callable = Callable(), biome: Callable = Callable(), dug: Dictionary = {}, built: Dictionary = {}) -> Dictionary:
	var surface := func(x: int, z: int) -> Dictionary:
		if x < 0 or z < 0 or x >= size or z >= size:
			return {}
		var k := Vector2i(x, z)
		return {"h": int(height.call(x, z)) if height.is_valid() else 10, "water": water.has(k), "biome": str(biome.call(x, z)) if biome.is_valid() else "plains", "block": blocked.has(k)}
	return {"surface": surface, "dug": func(x: int, y: int, z: int) -> bool: return dug.has(Vector3i(x, y, z)), "built": built, "max_depth": 50}


func _cells(list: Array) -> Dictionary:
	var out := {}
	for c in list:
		out[c] = true
	return out


func _s(x: int, z: int) -> Vector3i:
	return Vector3i(x, GamePath.SURFACE, z)


func _adjacent(a: Vector3i, b: Vector3i) -> bool:
	return absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1 and absi(a.z - b.z) <= 1 and (a != b)


func _contiguous(path: Array) -> bool:
	for i in range(1, path.size()):
		if not _adjacent(path[i - 1], path[i]):
			return false
	return true


# ---------------------------------------------------------------- data

func test_data() -> void:
	ok(GamePath.validate().is_empty(), "the data is sound: %s" % str(GamePath.validate()))
	var saved: Dictionary = GamePath.data().duplicate(true)
	GamePath.data()["settings"]["min_cost"] = 3.0
	ok(not GamePath.validate().is_empty(), "a min_cost above the cheapest step (which would make the search inexact) is found")
	GamePath._cache = saved.duplicate(true)
	GamePath.data()["terrain"].erase("swamp")
	ok(not GamePath.validate().is_empty(), "a biome with no terrain cost is found")
	GamePath._cache = saved.duplicate(true)
	GamePath.data()["node_blocks"].erase("oak_tree")
	ok(not GamePath.validate().is_empty(), "a node with no answer on whether it blocks is found")
	GamePath._cache = saved.duplicate(true)
	GamePath.data()["movers"].erase("flier")
	ok(not GamePath.validate().is_empty(), "a missing flier is found")
	GamePath._cache = saved.duplicate(true)
	GamePath.data()["movers"]["walker"].erase("max_climb")
	ok(not GamePath.validate().is_empty(), "a mover missing a field is found")
	GamePath._cache = saved.duplicate(true)
	GamePath.data()["settings"]["diagonal_mult"] = 2.5
	ok(not GamePath.validate().is_empty(), "a diagonal that costs more than two steps is found")
	GamePath._cache = saved.duplicate(true)
	GamePath.data()["settings"]["up_mult"] = 0.5
	ok(not GamePath.validate().is_empty(), "climbing cheaper than descending is found")
	GamePath._cache = saved.duplicate(true)
	GamePath.data()["built"]["wall"]["solid"] = "yes"
	ok(not GamePath.validate().is_empty(), "a built kind with a bad solid flag is found")
	GamePath._cache = saved.duplicate(true)
	GamePath.data()["terrain"]["plains"] = 0.0
	ok(not GamePath.validate().is_empty(), "a terrain that costs nothing is found")
	GamePath._cache = saved.duplicate(true)
	GamePath.data()["settings"].erase("slope_penalty")
	ok(not GamePath.validate().is_empty(), "a missing setting is found")
	GamePath._cache = saved
	ok(GamePath.validate().is_empty(), "and the data is put back")


# ---------------------------------------------------------------- open ground

func test_open() -> void:
	var g := _ground(30)
	var r := GamePath.find(g, _s(0, 0), _s(10, 0))
	ok(r["found"] and r["path"].size() == 11 and absf(float(r["cost"]) - 10.0) < 0.001 and r["path"][0] == _s(0, 0) and r["path"].back() == _s(10, 0), "across open ground it is a straight line: 11 cells costing 10")
	var d := GamePath.find(g, _s(0, 0), _s(5, 5))
	ok(d["found"] and d["path"].size() == 6 and absf(float(d["cost"]) - 5.0 * 1.4142) < 0.001, "diagonally it takes the diagonal: 6 cells costing %.2f" % float(d["cost"]))
	var mixed := GamePath.find(g, _s(0, 0), _s(8, 3))
	ok(mixed["found"] and _contiguous(mixed["path"]) and absf(float(mixed["cost"]) - (5.0 + 3.0 * 1.4142)) < 0.001, "a mixed route is some of each: cost %.2f" % float(mixed["cost"]))
	ok(GamePath.find(g, _s(4, 4), _s(4, 4))["path"] == [_s(4, 4)] and GamePath.find(g, _s(4, 4), _s(4, 4))["found"], "from a cell to itself is one cell")
	ok(GamePath.find(g, _s(0, 0), _s(10, 0)) == GamePath.find(g, _s(0, 0), _s(10, 0)), "the same question gets the same answer")
	ok(GamePath.next_step(g, _s(0, 0), _s(10, 0)) == _s(1, 0) and GamePath.next_step(g, _s(3, 3), _s(3, 3)) == _s(3, 3), "next_step is the second cell, or where it stands")
	# corners are not cut
	var one := _ground(10, _cells([Vector2i(1, 0)]))
	var c1 := GamePath.find(one, _s(0, 0), _s(1, 1))
	ok(c1["found"] and absf(float(c1["cost"]) - 2.0) < 0.001 and c1["path"].size() == 3, "it will not squeeze diagonally past a blocked cell: 2 steps, not the diagonal")
	var shut := _ground(10, _cells([Vector2i(1, 0), Vector2i(0, 1)]))
	ok(not GamePath.find(shut, _s(0, 0), _s(1, 1))["found"], "two blocked cells either side shut a corner for good")
	# the start is allowed wherever it is
	var inside := _ground(10, _cells([Vector2i(0, 0)]))
	ok(GamePath.find(inside, _s(0, 0), _s(3, 0))["found"], "a creature that finds itself on a blocked cell can walk out")
	# outside the world is nothing
	ok(not GamePath.find(g, _s(0, 0), _s(40, 0))["found"], "a goal outside the world cannot be reached")


# ---------------------------------------------------------------- walls

func test_walls() -> void:
	var wall: Array = []
	for z in range(0, 9):
		wall.append(Vector2i(5, z))
	var g := _ground(20, _cells(wall))
	var around := GamePath.find(g, _s(2, 2), _s(8, 2))
	ok(around["found"] and float(around["cost"]) > 6.5 and _contiguous(around["path"]), "round a wall with a gap at the end: cost %.1f against 6 straight" % float(around["cost"]))
	var clear := true
	for c in around["path"]:
		if wall.has(Vector2i(c.x, c.z)):
			clear = false
	ok(clear, "and it never goes through the wall")
	var sealed: Array = []
	for z in range(0, 20):
		sealed.append(Vector2i(5, z))
	var s := _ground(20, _cells(sealed))
	var none := GamePath.find(s, _s(2, 2), _s(8, 2))
	ok(not none["found"] and none["partial"] and none["path"].size() > 1, "sealed in, there is no way, only the way to the nearest cell")
	var end: Vector3i = none["path"].back()
	ok(end.x == 4 and absi(end.z - 2) <= 1, "which is the cell at the wall nearest the goal: (%d, %d)" % [end.x, end.z])
	ok(none["expanded"] < 1000, "and the search stops once the reachable ground is used up (%d cells)" % none["expanded"])
	# a goal that is itself in a wall
	var in_wall := GamePath.find(g, _s(2, 2), _s(5, 4))
	ok(not in_wall["found"] and in_wall["path"].back().x in [4, 5, 6], "a goal inside a wall gets the way to beside it")


# ---------------------------------------------------------------- the cheapest way

## The cheapest cost from a to b by plain Dijkstra over GamePath.neighbours, or -1 when there is no way.
func _dijkstra(ground: Dictionary, a: Vector3i, b: Vector3i, mover: Dictionary) -> float:
	var dist := {a: 0.0}
	var open: Array = [a]
	var done := {}
	while not open.is_empty():
		var bi := 0
		for i in open.size():
			if float(dist[open[i]]) < float(dist[open[bi]]):
				bi = i
		var c: Vector3i = open[bi]
		open.remove_at(bi)
		if done.has(c):
			continue
		done[c] = true
		if c == b:
			return float(dist[c])
		for nb in GamePath.neighbours(ground, c, mover):
			var n: Vector3i = nb[0]
			var g := float(dist[c]) + float(nb[1])
			if not dist.has(n) or g < float(dist[n]):
				dist[n] = g
				open.append(n)
	return -1.0


func test_optimal() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var agree := 0
	var unreachable := 0
	var total := 0
	var bad := ""
	for trial in 60:
		var blocked := {}
		var water := {}
		for i in 80:
			blocked[Vector2i(rng.randi_range(0, 17), rng.randi_range(0, 17))] = true
		for i in 25:
			water[Vector2i(rng.randi_range(0, 17), rng.randi_range(0, 17))] = true
		var heights := {}
		for x in 18:
			for z in 18:
				heights[Vector2i(x, z)] = rng.randi_range(0, 4)
		var biomes := ["plains", "forest", "hills", "swamp", "mountains"]
		var biome_of := {}
		for x in 18:
			for z in 18:
				biome_of[Vector2i(x, z)] = biomes[rng.randi_range(0, 4)]
		var g := _ground(18, blocked, water, func(x, z): return heights[Vector2i(x, z)], func(x, z): return biome_of[Vector2i(x, z)])
		for mover_name in ["walker", "swimmer"]:
			var mover: Dictionary = GamePath.data()["movers"][mover_name]
			var a := _s(rng.randi_range(0, 17), rng.randi_range(0, 17))
			var b := _s(rng.randi_range(0, 17), rng.randi_range(0, 17))
			var want := _dijkstra(g, a, b, mover)
			var got := GamePath.find(g, a, b, mover_name)
			total += 1
			if want < 0.0:
				unreachable += 1
				if not got["found"]:
					agree += 1
				else:
					bad = "found a way where Dijkstra found none"
			elif got["found"] and absf(float(got["cost"]) - want) < 0.0001 and _contiguous(got["path"]):
				agree += 1
			else:
				bad = "cost %s against %s" % [got["cost"], want]
	ok(agree == total, "on %d random grids (trees, water, slopes, five terrains; %d with no way) A* costs exactly what Dijkstra does, %s" % [total, unreachable, bad if bad != "" else "every time"])
	ok(unreachable > 3 and unreachable < total - 20, "(and the grids are a fair mix of reachable and not)")
	# the terrain costs time: round a swamp that is longer but quicker
	var swamp := _ground(20, {}, {}, Callable(), func(x, z): return "swamp" if x >= 5 and x <= 7 and z >= 2 and z <= 4 else "plains")
	var route := GamePath.find(swamp, _s(2, 3), _s(10, 3))
	var through := 0
	for c in route["path"]:
		if c.x >= 5 and c.x <= 7 and c.z >= 2 and c.z <= 4:
			through += 1
	ok(route["found"] and through == 0 and float(route["cost"]) < 8.0 * 1.8, "it goes round a swamp when that is quicker (%d swamp cells, cost %.1f)" % [through, float(route["cost"])])
	var thin := _ground(20, {}, {}, Callable(), func(x, z): return "forest" if x == 5 else "plains")
	var cross := GamePath.find(thin, _s(2, 3), _s(10, 3))
	ok(cross["found"] and absf(float(cross["cost"]) - (7.0 + 1.4)) < 0.001, "and straight through a single forest tile when going round is dearer: cost %.2f" % float(cross["cost"]))


# ---------------------------------------------------------------- slopes, water, trees

func test_slope_and_water() -> void:
	var cliff := _ground(20, {}, {}, func(x, z): return 0 if x < 5 else 10)
	ok(not GamePath.find(cliff, _s(2, 2), _s(8, 2), "walker")["found"], "a walker cannot climb a cliff of 10")
	ok(GamePath.find(cliff, _s(2, 2), _s(8, 2), "climber")["found"], "a climber can")
	ok(GamePath.find(cliff, _s(2, 2), _s(8, 2), "flier")["found"], "and a flier")
	var drop := _ground(20, {}, {}, func(x, z): return 10 if x < 5 else 2)
	ok(not GamePath.find(drop, _s(2, 2), _s(8, 2), "walker")["found"], "a walker will not jump down 8")
	var small_drop := _ground(20, {}, {}, func(x, z): return 6 if x < 5 else 2)
	ok(GamePath.find(small_drop, _s(2, 2), _s(8, 2), "walker")["found"], "but will step down 4")
	var up_small := _ground(20, {}, {}, func(x, z): return 2 if x < 5 else 4)
	ok(GamePath.find(up_small, _s(2, 2), _s(8, 2), "walker")["found"], "and up 2")
	var ramp := _ground(20, {}, {}, func(x, z): return x)
	var flat := _ground(20)
	var uphill := GamePath.find(ramp, _s(0, 5), _s(10, 5))
	ok(uphill["found"] and float(uphill["cost"]) > float(GamePath.find(flat, _s(0, 5), _s(10, 5))["cost"]) + 1.0, "a gentle slope can be climbed but costs more than flat ground: %.1f against 10" % float(uphill["cost"]))
	# water
	var lake: Array = []
	for z in range(0, 20):
		lake.append(Vector2i(8, z))
		lake.append(Vector2i(9, z))
	var wet := _ground(20, {}, _cells(lake))
	ok(not GamePath.find(wet, _s(3, 5), _s(15, 5), "walker")["found"], "a walker cannot cross a lake that spans the world")
	var sw := GamePath.find(wet, _s(3, 5), _s(15, 5), "swimmer")
	ok(sw["found"] and absf(float(sw["cost"]) - 12.0) < 0.001, "a swimmer swims straight across it: %.1f" % float(sw["cost"]))
	ok(GamePath.find(wet, _s(3, 5), _s(15, 5), "flier")["found"], "and a flier flies")
	var small_lake := _ground(20, {}, _cells([Vector2i(8, 4), Vector2i(8, 5), Vector2i(8, 6)]))
	var round_lake := GamePath.find(small_lake, _s(5, 5), _s(11, 5), "walker")
	var dry := true
	for c in round_lake["path"]:
		if Vector2i(c.x, c.z) in [Vector2i(8, 4), Vector2i(8, 5), Vector2i(8, 6)]:
			dry = false
	ok(round_lake["found"] and dry and float(round_lake["cost"]) > 6.0, "a walker goes round a pond: cost %.1f" % float(round_lake["cost"]))
	# trees
	var wood := _ground(20, _cells([Vector2i(5, 4), Vector2i(5, 5), Vector2i(5, 6)]))
	var tree_walk := GamePath.find(wood, _s(2, 5), _s(8, 5), "walker")
	ok(tree_walk["found"] and float(tree_walk["cost"]) > 6.0 and absf(float(GamePath.find(wood, _s(2, 5), _s(8, 5), "flier")["cost"]) - 6.0) < 0.001, "a walker goes round trees (%.1f) and a flier over them (6.0)" % float(tree_walk["cost"]))


# ---------------------------------------------------------------- the ground under

func test_underground() -> void:
	var wall: Array = []
	for z in range(0, 30):
		wall.append(Vector2i(15, z))
	var dug := {}
	var g := _ground(30, _cells(wall), {}, Callable(), Callable(), dug)
	ok(not GamePath.find(g, _s(10, 5), _s(20, 5))["found"], "a wall across the whole world cannot be walked round")
	# dig down, along and up
	for cell in [Vector3i(14, 0, 5), Vector3i(14, 1, 5), Vector3i(14, 2, 5), Vector3i(15, 2, 5), Vector3i(16, 2, 5), Vector3i(16, 1, 5), Vector3i(16, 0, 5)]:
		dug[cell] = true
	var through := GamePath.find(g, _s(10, 5), _s(20, 5))
	var underground := 0
	for c in through["path"]:
		if c.y >= 0:
			underground += 1
	ok(through["found"] and underground == 7 and _contiguous(through["path"]), "a tunnel under the wall is a way through: 7 dug cells on the route")
	ok(float(through["cost"]) > 10.0, "and it costs something (%.1f)" % float(through["cost"]))
	# the surface opens from a shaft only at depth 0
	var deep_only := {Vector3i(3, 1, 3): true, Vector3i(3, 2, 3): true}
	var g2 := _ground(30, {}, {}, Callable(), Callable(), deep_only)
	var mover: Dictionary = GamePath.data()["movers"]["walker"]
	ok(GamePath.neighbours(g2, _s(3, 3), mover).all(func(nb): return nb[0].y == GamePath.SURFACE), "a tunnel that never reaches the surface cannot be entered from it")
	ok(not GamePath.find(g2, _s(3, 3), Vector3i(3, 2, 3))["found"], "so there is no way down to it")
	# digging changes the path: the same ground before and after
	var before := dug.duplicate()
	dug.erase(Vector3i(15, 2, 5))
	ok(not GamePath.find(g, _s(10, 5), _s(20, 5))["found"], "take one cell of the tunnel away and there is no way")
	dug[Vector3i(15, 2, 5)] = true
	ok(GamePath.find(g, _s(10, 5), _s(20, 5))["found"] and dug == before, "dig it again and there is")
	# up costs more than down
	var down_cost := 0.0
	var up_cost := 0.0
	for nb in GamePath.neighbours(g, Vector3i(14, 1, 5), mover):
		if nb[0] == Vector3i(14, 2, 5):
			down_cost = float(nb[1])
		if nb[0] == Vector3i(14, 0, 5):
			up_cost = float(nb[1])
	ok(down_cost == 1.0 and up_cost == 1.5, "climbing a shaft costs more than going down it: %.1f against %.1f" % [up_cost, down_cost])
	# a tunnel is a mover thing too: the way out the top
	ok(GamePath.find(g, Vector3i(14, 2, 5), _s(14, 5))["found"], "from inside a tunnel there is a way out by the shaft")
	# the depth limit
	ok(not GamePath.passable(g, Vector3i(14, 99, 5), mover) and not GamePath.passable(g, Vector3i(14, 3, 5), mover), "undug rock and cells below the bottom cannot be stood in")


# ---------------------------------------------------------------- building

func test_built() -> void:
	var built := {}
	var g := _ground(30, {}, {}, Callable(), Callable(), {}, built)
	var open_cost := float(GamePath.find(g, _s(2, 10), _s(20, 10))["cost"])
	for z in range(4, 17):
		built["15,-1,%d" % z] = "wall"
	var detour := GamePath.find(g, _s(2, 10), _s(20, 10))
	ok(detour["found"] and float(detour["cost"]) > open_cost + 3.0, "a built wall makes a detour: %.1f against %.1f" % [float(detour["cost"]), open_cost])
	built["15,-1,10"] = "door"
	var door := GamePath.find(g, _s(2, 10), _s(20, 10))
	ok(door["found"] and float(door["cost"]) < float(detour["cost"]) and float(door["cost"]) > open_cost, "a door in it is a way through, a little dearer than open ground: %.1f" % float(door["cost"]))
	# a road is quick
	built.clear()
	for x in range(0, 30):
		built["%d,-1,14" % x] = "road"
	var by_road := GamePath.find(g, _s(0, 12), _s(29, 12))
	var along := 0
	for c in by_road["path"]:
		if c.z == 14:
			along += 1
	ok(by_road["found"] and along > 15 and float(by_road["cost"]) < 29.0 * 1.0 + 1.0, "it leaves the open ground for a road when the road is quicker (%d cells on it)" % along)
	# a floor over water is a bridge
	built.clear()
	var lake: Array = []
	for z in range(0, 30):
		lake.append(Vector2i(10, z))
	var wet := _ground(30, {}, _cells(lake), Callable(), Callable(), {}, built)
	ok(not GamePath.find(wet, _s(5, 10), _s(15, 10))["found"], "a lake across the world stops a walker")
	built["10,-1,10"] = "floor"
	var bridge := GamePath.find(wet, _s(5, 10), _s(15, 10))
	ok(bridge["found"] and bridge["path"].has(_s(10, 10)), "and a floor built over it is a bridge")
	# a wall underground shuts a tunnel
	var dug := {Vector3i(5, 0, 5): true, Vector3i(5, 1, 5): true, Vector3i(6, 1, 5): true, Vector3i(7, 1, 5): true}
	var b2 := {}
	var u := _ground(30, {}, {}, Callable(), Callable(), dug, b2)
	ok(GamePath.find(u, Vector3i(5, 0, 5), Vector3i(7, 1, 5))["found"], "a tunnel can be walked")
	b2["6,1,5"] = "wall"
	ok(not GamePath.find(u, Vector3i(5, 0, 5), Vector3i(7, 1, 5))["found"], "a wall built in it shuts it")
	b2["6,1,5"] = "road"
	ok(GamePath.find(u, Vector3i(5, 0, 5), Vector3i(7, 1, 5))["found"], "and a floor laid in dug ground can be walked")
	# a floor where there is no tunnel: built ground is walkable even undug (a built room)
	b2["9,3,9"] = "floor"
	ok(GamePath.passable(u, Vector3i(9, 3, 9), GamePath.data()["movers"]["walker"]), "built floor is a cell to stand in")


# ---------------------------------------------------------------- limits

func test_limits() -> void:
	var g := _ground(60)
	var cut := GamePath.find(g, _s(0, 0), _s(59, 59), "walker", 40)
	ok(not cut["found"] and cut["partial"] and cut["expanded"] <= 40 and cut["path"].size() > 1, "a search that runs out of nodes gives the way toward the goal as far as it got (%d expanded)" % cut["expanded"])
	var end: Vector3i = cut["path"].back()
	ok(end.x + end.z > 20, "which is well on the way (cell %d, %d)" % [end.x, end.z])
	ok(GamePath.find(g, _s(0, 0), _s(59, 59), "walker", 5000)["found"], "and with room it finds the whole way")
	ok(GamePath.find(g, _s(0, 0), _s(59, 59), "walker", 5000)["expanded"] < 400, "A* heads for the goal rather than flooding the map (%d cells)" % GamePath.find(g, _s(0, 0), _s(59, 59), "walker", 5000)["expanded"])


# ---------------------------------------------------------------- the real world

func test_world() -> void:
	var d := GameDynasty.new_game(5, "Tess", "warrior", "faetouched", "human")
	var rng_before := d.rng.state
	var save_before := JSON.stringify(d.to_dict())
	var g := GamePath.world_ground(d)
	# two clear land cells inland, 40 apart
	var a := _s(300, 300)
	while not GamePath.passable(g, a, GamePath.data()["movers"]["walker"]):
		a = _s(a.x + 1, a.z)
	var b := _s(a.x + 40, a.z + 10)
	while not GamePath.passable(g, b, GamePath.data()["movers"]["walker"]):
		b = _s(b.x + 1, b.z)
	var r := GamePath.find(g, a, b, "walker", 6000)
	ok(r["found"] and _contiguous(r["path"]) and r["path"][0] == a and r["path"].back() == b, "there is a way across the generated world: %d cells, cost %.1f" % [r["path"].size(), float(r["cost"])])
	var clean := true
	var trees := 0
	for c in r["path"]:
		var info: Dictionary = g["surface"].call(c.x, c.z)
		if info["water"] or info["block"]:
			clean = false
		if info["biome"] == "forest":
			trees += 1
	ok(clean, "and it keeps to dry ground clear of trees and rock")
	var straight := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
	ok(float(r["cost"]) >= straight * 0.5 and float(r["cost"]) < straight * 3.0, "at a cost that is sensible for %.0f tiles as the crow flies: %.1f" % [straight, float(r["cost"])])
	ok(GamePath.find(g, a, b, "walker", 6000) == r, "and the same each time")
	# the sea
	var west := _s(-10, 300)
	var shore := GamePath.find(g, _s(60, 300), west, "walker", 6000)
	ok(not shore["found"] and shore["partial"] and shore["path"].size() > 5, "a walker cannot reach a goal out at sea: it gets the way to the shore")
	var last: Vector3i = shore["path"].back()
	ok(not g["surface"].call(last.x, last.z)["water"], "and the nearest cell it reaches is dry land")
	var sea := _s(0, 300)
	while not g["surface"].call(sea.x, sea.z)["water"] and sea.x < 60:
		sea = _s(sea.x + 1, sea.z)
	var fly := GamePath.find(g, _s(60, 300), sea, "flier", 6000)
	ok(fly["found"] and fly["path"].size() <= 61, "a flier crosses straight to it (%d cells)" % fly["path"].size())
	ok(GamePath.mover_for("harpy") == "flier" and GamePath.mover_for("wolf") == "walker" and GamePath.mover_for("sheep") == "walker", "fliers fly and the rest walk")
	# digging and building change the way in the real world: a long wall, then a tunnel under it
	var x0 := 250
	var z0 := 250
	var mover: Dictionary = GamePath.data()["movers"]["walker"]
	var clear_strip := false
	while not clear_strip:
		clear_strip = true
		for dx in range(0, 7):
			if not GamePath.passable(g, _s(x0 + dx, z0), mover):
				clear_strip = false
		if not clear_strip:
			x0 += 1
			if x0 > 450:
				x0 = 250
				z0 += 1
	var built := {}
	for z in range(z0 - 30, z0 + 31):
		built["%d,-1,%d" % [x0 + 3, z]] = "wall"
	var g2 := GamePath.world_ground(d, built)
	var start := _s(x0, z0)
	var goal := _s(x0 + 6, z0)
	var round_it := GamePath.find(g2, start, goal, "walker", 12000)
	ok(round_it["found"] and float(round_it["cost"]) > 50.0, "with a 61-tile wall across it the way is long: cost %.1f" % float(round_it["cost"]))
	for cell in [Vector3i(x0 + 1, 0, z0), Vector3i(x0 + 1, 1, z0), Vector3i(x0 + 1, 2, z0), Vector3i(x0 + 2, 2, z0), Vector3i(x0 + 3, 2, z0), Vector3i(x0 + 4, 2, z0), Vector3i(x0 + 5, 2, z0), Vector3i(x0 + 5, 1, z0), Vector3i(x0 + 5, 0, z0)]:
		GameMine.dig(d, GameWorldGen.MINE_SITE, cell.x, cell.y, cell.z, 50.0)
	var g3 := GamePath.world_ground(d, built)
	var tunnelled := GamePath.find(g3, start, goal, "walker", 12000)
	var below := 0
	for c in tunnelled["path"]:
		if c.y >= 0:
			below += 1
	ok(tunnelled["found"] and below == 9 and float(tunnelled["cost"]) < float(round_it["cost"]) * 0.5, "dig under the wall with the game's own digging and the way is short: cost %.1f against %.1f, %d cells underground" % [float(tunnelled["cost"]), float(round_it["cost"]), below])
	ok(d.rng.state == rng_before and JSON.stringify(d.to_dict()) != save_before, "(finding paths drew no dice of the dynasty's; the dug cells are the only thing that changed what is saved)")


# ---------------------------------------------------------------- creatures round a wall

func test_router() -> void:
	var wall: Array = []
	for z in range(0, 25):
		wall.append(Vector2i(15, z))
	var blocked := _cells(wall)
	var g := _ground(30, blocked)
	var walk := func(x: float, z: float) -> bool: return x >= 0.0 and z >= 0.0 and x < 30.0 and z < 30.0 and not blocked.has(Vector2i(int(floor(x)), int(floor(z))))
	var wolf := [GameBehaviour.new_agent(1, "wolf", 10.0, 15.0)]
	var target := [{"x": 27.0, "z": 15.0}]
	var plain := wolf
	var routed := wolf
	var router := GamePath.router(g, "walker", 4000)
	for t in 120:
		plain = GameBehaviour.step_all(plain, {"targets": target, "night": true, "walkable": walk}, 7, t)
		routed = GameBehaviour.step_all(routed, {"targets": target, "night": true, "walkable": walk, "router": router}, 7, t)
	var plain_end := Vector2(float(plain[0]["x"]), float(plain[0]["z"]))
	var routed_end := Vector2(float(routed[0]["x"]), float(routed[0]["z"]))
	ok(plain_end.x < 15.0, "without a router the wolf stops at the wall: x = %.1f" % plain_end.x)
	ok(routed_end.distance_to(Vector2(27.0, 15.0)) < 2.0, "with one it goes round the wall to its prey: %.1f from it" % routed_end.distance_to(Vector2(27.0, 15.0)))
	var never_in := true
	var r2 := wolf
	for t in 120:
		r2 = GameBehaviour.step_all(r2, {"targets": target, "night": true, "walkable": walk, "router": router}, 7, t)
		if blocked.has(Vector2i(int(floor(float(r2[0]["x"]))), int(floor(float(r2[0]["z"]))))):
			never_in = false
	ok(never_in, "and never steps into the wall on the way")
	# a creature that cannot be reached still moves toward it
	var sealed: Array = []
	for z in range(0, 30):
		sealed.append(Vector2i(15, z))
	var sb := _cells(sealed)
	var sg := _ground(30, sb)
	var swalk := func(x: float, z: float) -> bool: return x >= 0.0 and z >= 0.0 and x < 30.0 and z < 30.0 and not sb.has(Vector2i(int(floor(x)), int(floor(z))))
	var trapped := wolf
	for t in 60:
		trapped = GameBehaviour.step_all(trapped, {"targets": target, "night": true, "walkable": swalk, "router": GamePath.router(sg, "walker", 4000)}, 7, t)
	ok(float(trapped[0]["x"]) > 12.0 and float(trapped[0]["x"]) < 15.0, "with no way at all it comes up to the wall and waits there: x = %.1f" % float(trapped[0]["x"]))
	# the router is plain data in the view: no router, no change to what item 48 did
	var again := wolf
	for t in 30:
		again = GameBehaviour.step_all(again, {"targets": target, "night": true, "walkable": walk}, 7, t)
	var once_more := wolf
	for t in 30:
		once_more = GameBehaviour.step_all(once_more, {"targets": target, "night": true, "walkable": walk, "router": Callable()}, 7, t)
	ok(again == once_more, "an empty router changes nothing")
