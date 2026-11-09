## Pathfinding over dug and built ground (roadmap item 49). A* over the cells of the world: the surface (layer y = -1, one
## cell for each tile of the generated world, with its height) and the ground under it (y = 0 and down, the cells GameMine
## says are dug). A mover (data/world/pathing.json `movers`) steps between cells its kind can stand on: a walker climbs a
## few heights and drops a few more, keeps off open water and is stopped by trees and rock outcrops; a climber takes cliffs;
## a swimmer crosses water; a flier crosses anything on the surface. Terrain costs time, a slope costs more, a diagonal costs
## more and may not cut a corner, climbing a shaft costs more than descending it. Digging changes the ground (a dug cell can
## be walked, so a tunnel is a way round a wall) and so does building: a `built` overlay ({"x,y,z": kind}) puts a wall, a
## floor, a road or a door in a cell (a floor over water is a bridge), so item 50's buildings only have to fill it in.
## The search is bounded; if it cannot reach the goal it gives the way to the nearest cell it did reach. Pure: nothing is
## saved, nothing random, no dice of the dynasty's.
class_name GamePath
extends RefCounted

const PATH := "res://data/world/pathing.json"
const SURFACE := -1
const DIRS8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


# ---------------------------------------------------------------- the ground

## A ground is {surface: Callable(x, z) -> {h, water, biome, block} or {} outside the world, dug: Callable(x, y, z) -> bool,
## built: {"x,y,z": kind}, max_depth: int}. The tests make small ones; `world_ground` makes the real one.
static func key(c: Vector3i) -> String:
	return "%d,%d,%d" % [c.x, c.y, c.z]


## The ground of a dynasty's world: the generated surface (cached), the cells dug at the mining `site`, and a built overlay.
static func world_ground(d: GameDynasty, built: Dictionary = {}, site: String = GameWorldGen.MINE_SITE) -> Dictionary:
	var memo := {}
	var surface := func(x: int, z: int) -> Dictionary:
		var k := Vector2i(x, z)
		if memo.has(k):
			return memo[k]
		var info: Dictionary = {}
		if GameWorldGen.in_bounds(x, z):
			var land := GameWorldGen.blend(d.seed_value, float(x), float(z))
			var h := GameWorldGen.height_at(d.seed_value, x, z)
			var water := h < int(GameWorldGen.setting("sea_level"))
			var node := GameWorldGen.node_at(d, x, z, str(land["biome"]), water)
			info = {"h": h, "water": water, "biome": str(land["biome"]), "block": not node.is_empty() and bool(data()["node_blocks"].get(str(node["kind"]), false))}
		memo[k] = info
		return info
	return {"surface": surface, "dug": func(x: int, y: int, z: int) -> bool: return GameMine.is_dug(d, site, x, y, z), "built": built, "max_depth": int(GameMine.setting("max_depth"))}


static func _built_kind(ground: Dictionary, c: Vector3i) -> Dictionary:
	var k: Variant = ground.get("built", {}).get(key(c), null)
	return data()["built"].get(str(k), {}) if k != null else {}


## Whether a mover can stand in a cell.
static func passable(ground: Dictionary, c: Vector3i, mover: Dictionary) -> bool:
	var b := _built_kind(ground, c)
	if not b.is_empty():
		return not bool(b["solid"])   # a floor, a road, a door can be walked (over water, a bridge); a wall cannot
	if c.y == SURFACE:
		var info: Dictionary = ground["surface"].call(c.x, c.z)
		if info.is_empty():
			return false
		if bool(info["water"]) and not bool(mover["water"]):
			return false
		if bool(info["block"]) and not bool(mover["ignore_blocks"]):
			return false
		return true
	if c.y < 0 or c.y > int(ground.get("max_depth", 0)):
		return false
	return bool(ground["dug"].call(c.x, c.y, c.z))


## What it costs to step into a cell: the built thing's cost, the terrain's, or 1 underground.
static func cell_cost(ground: Dictionary, c: Vector3i) -> float:
	var b := _built_kind(ground, c)
	if not b.is_empty():
		return float(b["cost"])
	if c.y == SURFACE:
		var info: Dictionary = ground["surface"].call(c.x, c.z)
		return float(data()["terrain"].get(str(info.get("biome", "plains")), 1.0))
	return 1.0


static func _height(ground: Dictionary, c: Vector3i) -> int:
	return int(ground["surface"].call(c.x, c.z).get("h", 0))


## The cells a mover can step to from a cell, with what each step costs.
static func neighbours(ground: Dictionary, c: Vector3i, mover: Dictionary) -> Array:
	var out: Array = []
	var diag := float(setting("diagonal_mult"))
	var slope := float(setting("slope_penalty"))
	if c.y == SURFACE:
		for dir in DIRS8:
			var n := Vector3i(c.x + dir.x, SURFACE, c.z + dir.y)
			if not passable(ground, n, mover):
				continue
			var diagonal: bool = dir.x != 0 and dir.y != 0
			if diagonal and not (passable(ground, Vector3i(c.x + dir.x, SURFACE, c.z), mover) and passable(ground, Vector3i(c.x, SURFACE, c.z + dir.y), mover)):
				continue   # no cutting a corner
			var dh := 0
			if _built_kind(ground, n).is_empty() and _built_kind(ground, c).is_empty():
				dh = _height(ground, n) - _height(ground, c)
				if dh > int(mover["max_climb"]) or -dh > int(mover["max_drop"]):
					continue
			var step := cell_cost(ground, n) * (1.0 + slope * float(absi(dh)))
			out.append([n, step * (diag if diagonal else 1.0)])
		var down := Vector3i(c.x, 0, c.z)
		if passable(ground, down, mover):
			out.append([down, cell_cost(ground, down)])
		return out
	for dir3: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]:
		var n3: Vector3i = c + dir3
		var up: bool = dir3.y < 0
		var target: Vector3i = n3
		if up and c.y == 0:
			target = Vector3i(c.x, SURFACE, c.z)   # the top of a shaft opens onto the surface
		elif n3.y < 0:
			continue
		if not passable(ground, target, mover):
			continue
		out.append([target, cell_cost(ground, target) * (float(setting("up_mult")) if up else 1.0)])
	return out


# ---------------------------------------------------------------- the search

## The cheapest a step can cost on this ground (the terrain's cheapest, or a built road's if anything is built): the
## search's lower bound, so the search is exact and still heads for the goal.
static func _floor_cost(ground: Dictionary) -> float:
	var lo := INF
	for v in data()["terrain"].values():
		lo = minf(lo, float(v))
	if not ground.get("built", {}).is_empty():
		for k in data()["built"].values():
			lo = minf(lo, float(k["cost"]))
	return maxf(minf(lo, 1.0), float(setting("min_cost")))


static func _heuristic(a: Vector3i, b: Vector3i, floor_cost: float = -1.0) -> float:
	var dx := absf(float(a.x - b.x))
	var dz := absf(float(a.z - b.z))
	var dy := absf(float(a.y - b.y))
	var octile := (dx + dz) + (float(setting("diagonal_mult")) - 2.0) * minf(dx, dz)
	return (float(setting("min_cost")) if floor_cost < 0.0 else floor_cost) * (octile + dy)


static func _push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if _less(heap[i], heap[p]):
			var tmp: Array = heap[i]
			heap[i] = heap[p]
			heap[p] = tmp
			i = p
		else:
			break


static func _pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		var i := 0
		var n := heap.size()
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < n and _less(heap[l], heap[m]):
				m = l
			if r < n and _less(heap[r], heap[m]):
				m = r
			if m == i:
				break
			var tmp: Array = heap[i]
			heap[i] = heap[m]
			heap[m] = tmp
			i = m
	return top


static func _less(a: Array, b: Array) -> bool:
	return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1]) < int(b[1]))


## The cheapest way from a cell to another for a mover kind: {found, path (cells, start first), cost, expanded, partial}.
## When the goal cannot be reached (or the search runs out of `max_nodes`), `found` is false and `path` is the way to the
## cell the search got nearest to it (`partial`). The start is always allowed, wherever it is.
static func find(ground: Dictionary, start: Vector3i, goal: Vector3i, mover_name: String = "walker", max_nodes: int = -1) -> Dictionary:
	var mover: Dictionary = data()["movers"][mover_name]
	var limit := int(setting("max_nodes")) if max_nodes < 0 else max_nodes
	var best: Dictionary = {start: 0.0}
	var came := {}
	var closed := {}
	var heap: Array = []
	var counter := 0
	var fc := _floor_cost(ground)
	_push(heap, [_heuristic(start, goal, fc), counter, start])
	var nearest := start
	var nearest_h := _heuristic(start, goal, fc)
	var expanded := 0
	var found := false
	while not heap.is_empty() and expanded < limit:
		var top: Array = _pop(heap)
		var c: Vector3i = top[2]
		if closed.has(c):
			continue
		closed[c] = true
		expanded += 1
		if c == goal:
			found = true
			nearest = c
			break
		var h := _heuristic(c, goal, fc)
		if h < nearest_h:
			nearest_h = h
			nearest = c
		for nb in neighbours(ground, c, mover):
			var n: Vector3i = nb[0]
			if closed.has(n):
				continue
			var g: float = float(best[c]) + float(nb[1])
			if not best.has(n) or g < float(best[n]):
				best[n] = g
				came[n] = c
				counter += 1
				_push(heap, [g + _heuristic(n, goal, fc), counter, n])
	var path: Array = [nearest]
	while came.has(path[0]):
		path.push_front(came[path[0]])
	return {"found": found, "path": path, "cost": float(best.get(nearest, 0.0)), "expanded": expanded, "partial": not found}


## The mover kind a creature uses: fliers fly, everything else walks (item 48's `flier` tag).
static func mover_for(creature_id: String) -> String:
	return "flier" if bool(GameBehaviour.params(creature_id)["flier"]) else "walker"


## The next cell on the way from one to another (the start itself when there is nowhere to go).
static func next_step(ground: Dictionary, start: Vector3i, goal: Vector3i, mover_name: String = "walker", max_nodes: int = -1) -> Vector3i:
	var r := find(ground, start, goal, mover_name, max_nodes)
	return r["path"][1] if r["path"].size() > 1 else start


## A router for GameBehaviour (`view.router`): given where a creature is and where it wants to be on the surface, the
## middle of the next tile on the way (the goal itself once it is in the same or the next tile).
static func router(ground: Dictionary, mover_name: String = "walker", max_nodes: int = 4000) -> Callable:
	return func(from: Vector2, to: Vector2) -> Vector2:
		var a := Vector3i(int(floor(from.x)), SURFACE, int(floor(from.y)))
		var b := Vector3i(int(floor(to.x)), SURFACE, int(floor(to.y)))
		if a == b:
			return to
		var step := next_step(ground, a, b, mover_name, max_nodes)
		if step == a:
			return to   # nowhere better to go: head for the goal and let the ground stop it
		if step == b:
			return to
		return Vector2(float(step.x) + 0.5, float(step.z) + 0.5)


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = data()
	for k in ["settings", "movers", "terrain", "node_blocks", "built"]:
		if not dat.has(k):
			bad.append("pathing.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var s: Dictionary = dat["settings"]
	for k in ["max_nodes", "diagonal_mult", "slope_penalty", "up_mult", "min_cost"]:
		if not s.has(k):
			bad.append("pathing.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if int(s["max_nodes"]) < 10 or float(s["diagonal_mult"]) < 1.0 or float(s["up_mult"]) < 1.0 or float(s["slope_penalty"]) < 0.0 or float(s["min_cost"]) <= 0.0:
		bad.append("pathing.json: max_nodes must be at least 10, diagonal_mult and up_mult at least 1, slope_penalty 0 or more and min_cost above 0")
	if float(s["diagonal_mult"]) > 2.0:
		bad.append("pathing.json: a diagonal that costs more than two steps would never be taken")
	for m in dat["movers"]:
		var mv: Dictionary = dat["movers"][m]
		for k in ["max_climb", "max_drop", "water", "ignore_blocks", "fly"]:
			if not mv.has(k):
				bad.append("pathing.json: mover '%s' has no %s" % [m, k])
		if int(mv.get("max_climb", -1)) < 0 or int(mv.get("max_drop", -1)) < 0:
			bad.append("pathing.json: mover '%s' needs a climb and a drop of 0 or more" % m)
	for need in ["walker", "flier"]:
		if not dat["movers"].has(need):
			bad.append("pathing.json: the mover '%s' is needed (item 48's tags)" % need)
	var cheapest := 1.0
	for b in GameWorldGen.data()["biomes"]:
		if not dat["terrain"].has(b):
			bad.append("pathing.json: terrain has no cost for the biome '%s'" % b)
	if not dat["terrain"].has("ocean"):
		bad.append("pathing.json: terrain has no cost for the ocean")
	for b in dat["terrain"]:
		if float(dat["terrain"][b]) <= 0.0:
			bad.append("pathing.json: the terrain cost of '%s' must be above 0" % b)
		cheapest = minf(cheapest, float(dat["terrain"][b]))
	for k in GameWorldGen.data()["nodes"]:
		if not dat["node_blocks"].has(k):
			bad.append("pathing.json: node_blocks has no answer for the node '%s'" % k)
	for k in dat["built"]:
		var bk: Dictionary = dat["built"][k]
		if typeof(bk.get("solid")) != TYPE_BOOL or float(bk.get("cost", 0.0)) <= 0.0:
			bad.append("pathing.json: the built kind '%s' needs solid and a cost above 0" % k)
		elif not bool(bk["solid"]):
			cheapest = minf(cheapest, float(bk["cost"]))
	if float(s["min_cost"]) > cheapest:
		bad.append("pathing.json: min_cost %s is more than the cheapest step %s, so the search would not be exact" % [s["min_cost"], cheapest])
	return bad
