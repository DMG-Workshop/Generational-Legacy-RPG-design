## The walls and gates round the towns of the open world (core, no UI; data/world/walls.json). A town's wall is a ring of tiles
## round its anchor that blocks a walker like a tree or a building does (GamePath's ground asks `blocks`), except at the gates:
## openings a cart wide, each with a tower either side and a lintel over the passage. Everything is a pure function of the data and
## the world's fixed map (the anchors and the text game's roads): no dice, nothing saved, and the same on every seed (the wall
## stands on the town's own flat ground, which is the same height all round it).
class_name GameWalls
extends RefCounted

const PATH := "res://data/world/walls.json"
const DIRS := {"n": Vector2i(0, -1), "e": Vector2i(1, 0), "s": Vector2i(0, 1), "w": Vector2i(-1, 0)}
const ANGLES := {"n": -90.0, "e": 0.0, "s": 90.0, "w": 180.0}
const SOLID := ["wall", "tower", "jamb"]

static var _cache: Dictionary = {}
static var _built := false
static var _tiles: Dictionary = {}    # place -> {"x,z": {k, s, i}}: k is wall, tower, jamb (the tower beside a passage) or gate; s the side of
									  # the passage a tower is on (-1 or 1); i the tile's place across a gate's passage (-1 to 1)
static var _kinds: Dictionary = {}    # "x,z" -> the tile's record, for every town at once
static var _gates: Dictionary = {}    # place -> [gate]
static var _clear: Dictionary = {}    # "x,z" -> true: the wall's tiles and the ground in front of and behind each gate
static var _pieces: Array = []        # every tile of every wall as {x, z, k, s, i, a (a gate's axis), p (the place)}, for the screen


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func _dot(a: Vector2i, b: Vector2i) -> int:
	return a.x * b.x + a.y * b.y


static func _k(x: int, z: int) -> String:
	return "%d,%d" % [x, z]


## The towns with a wall, in the order of the data.
static func walled() -> Array:
	var out: Array = []
	for place in data()["towns"]:
		if not GameWorldGen.anchor(str(place)).is_empty():
			out.append(str(place))
	return out


## The wall's radius (tiles) round a town's anchor.
static func radius(place: String) -> float:
	return float(data()["towns"].get(place, {}).get("radius", setting("radius")))


## Every gate of a town: {id, place, side, axis ("ns" or "ew"), dir (the way out), centre (the middle tile of the passage), inner and
## outer (the tiles just inside and outside it), tiles (the passage's tiles), posts (where the two guards on duty stand, inside the
## wall either side of the passage)}.
static func gates(place: String) -> Array:
	_ensure()
	return _gates.get(place, [])


static func all_gates() -> Array:
	var out: Array = []
	for place in walled():
		out.append_array(gates(place))
	return out


## The wall's tiles of a town: {"x,z": {k, s, i}}.
static func tiles(place: String) -> Dictionary:
	_ensure()
	return _tiles.get(place, {})


## The pieces of walls within a rectangle of tiles: [{x, z, k, s, i, a, p}] (kind, the side of the passage a tower is on, the place
## across a passage, a gate's axis, the town).
static func pieces_in(rect: Rect2i) -> Array:
	_ensure()
	var out: Array = []
	for p in _pieces:
		if rect.has_point(Vector2i(int(p["x"]), int(p["z"]))):
			out.append(p)
	return out


## What a tile of a wall is ("wall", "tower", "jamb" or "gate"), or "" for none.
static func kind_at(x: int, z: int) -> String:
	_ensure()
	var r: Variant = _kinds.get(_k(x, z))
	return "" if r == null else str((r as Dictionary)["k"])


static func record_at(x: int, z: int) -> Dictionary:
	_ensure()
	var r: Variant = _kinds.get(_k(x, z))
	return {} if r == null else r


## Whether a tile is a wall or a tower, which a walker cannot cross (a gate's passage is open).
static func blocks(x: int, z: int) -> bool:
	_ensure()
	var r: Variant = _kinds.get(_k(x, z))
	return r != null and str((r as Dictionary)["k"]) in SOLID


## Whether the world leaves a tile free of trees and rocks: the wall itself and the way in and out of each gate.
static func cleared(x: int, z: int) -> bool:
	_ensure()
	return _clear.has(_k(x, z))


## The gate whose passage (or the tile just in front of or behind it) holds a tile, or {}.
static func gate_at(x: int, z: int) -> Dictionary:
	for g in all_gates():
		for t in g["tiles"]:
			if t.x == x and t.y == z:
				return g
	return {}


## The gate a tile is next to (within `reach` tiles of its passage's middle), or {}: for the guards and the text of a gate.
static func gate_near(x: float, z: float, reach: float) -> Dictionary:
	var best := {}
	var best_d := reach
	for g in all_gates():
		var c: Vector2i = g["centre"]
		var dist := Vector2(x - float(c.x) - 0.5, z - float(c.y) - 0.5).length()
		if dist <= best_d:
			best_d = dist
			best = g
	return best


## The place a gate's road leads to: the destination of the text game's road that leaves the town on this side (within
## `road_angle` degrees of it), the nearest in angle; "" when none leaves that way.
static func road_of(g: Dictionary) -> String:
	var best := ""
	var best_diff := float(setting("road_angle")) + 0.001
	for r in roads_from(str(g["place"])):
		var diff := _angle_diff(float(r["angle"]), float(ANGLES[str(g["side"])]))
		if diff < best_diff:
			best_diff = diff
			best = str(r["to"])
	return best


## The roads that leave a town (the text game's links): [{to, angle (degrees, z south)}].
static func roads_from(place: String) -> Array:
	GameData.load_all()
	var a := GameWorldGen.anchor(place)
	var out: Array = []
	for l in GameData.world["locations"]:
		if str(l["id"]) != place:
			continue
		for link in l.get("links", []):
			var b := GameWorldGen.anchor(str(link["to"]))
			if not b.is_empty() and not a.is_empty():
				out.append({"to": str(link["to"]), "angle": rad_to_deg(atan2(float(b["z"]) - float(a["z"]), float(b["x"]) - float(a["x"])))})
	return out


static func _angle_diff(a: float, b: float) -> float:
	return absf(fposmod(a - b + 180.0, 360.0) - 180.0)


# ---------------------------------------------------------------- the build

static func _ensure() -> void:
	if _built:
		return
	_built = true
	for place in walled():
		_make(place)


## Forgets the data and the built walls (read again from the file).
static func reload() -> void:
	_cache = {}
	reset()


## Forgets the built walls only, to be made again from the data as it now is (the tests break the data on purpose).
static func reset() -> void:
	_built = false
	_tiles = {}
	_kinds = {}
	_gates = {}
	_clear = {}
	_pieces = []


static func _make(place: String) -> void:
	var a := GameWorldGen.anchor(place)
	var ax := int(a["x"])
	var az := int(a["z"])
	var r := radius(place)
	var thick := float(setting("thickness"))
	var ring := {}
	var reach := int(ceil(r)) + 1
	for z in range(az - reach, az + reach + 1):
		for x in range(ax - reach, ax + reach + 1):
			var dist := Vector2(x - ax, z - az).length()
			if dist <= r and dist > r - thick:
				ring[_k(x, z)] = {"k": "wall", "s": 0, "i": 0}
	var half := int(setting("gate_width")) / 2
	var towers := int(setting("tower_len"))
	var list: Array = []
	for g in data()["towns"][place]["gates"]:
		var side := str(g["side"])
		if not DIRS.has(side):
			continue
		var dir: Vector2i = DIRS[side]
		var along_x := dir.x == 0   # a north or south gate: the passage runs along x
		var c := (ax if along_x else az) + int(g.get("shift", 0))
		var cols := {}   # tangent coordinate -> [tiles of the ring in it, on this side]
		for key in ring:
			var p := (key as String).split(",")
			var x := int(p[0])
			var z := int(p[1])
			if float(_dot(Vector2i(x - ax, z - az), dir)) < r * 0.5:
				continue   # not on this side of the ring
			var t := x if along_x else z
			if absi(t - c) > half + towers:
				continue
			if not cols.has(t):
				cols[t] = []
			cols[t].append(Vector2i(x, z))
		var passage: Array = []
		for t in cols:
			var off: int = t - c
			for tile in cols[t]:
				var rec: Dictionary = ring[_k(tile.x, tile.y)]
				if absi(off) <= half:
					rec["k"] = "gate"
					rec["i"] = off
					rec["a"] = "ns" if along_x else "ew"
					passage.append(tile)
				else:
					rec["k"] = "jamb" if absi(off) == half + 1 else "tower"
					rec["s"] = 1 if off > 0 else -1
		var gate := {"id": "%s/gate_%s" % [place, side], "place": place, "side": side, "axis": "ns" if along_x else "ew", "dir": dir,
			"shift": int(g.get("shift", 0)), "tiles": passage}
		_place_gate(gate, ring, ax, az, c, half, along_x)
		list.append(gate)
	_tiles[place] = ring
	_gates[place] = list
	for key in ring:
		_kinds[key] = ring[key]
		_clear[key] = true
		var xz := (key as String).split(",")
		var rec: Dictionary = (ring[key] as Dictionary).duplicate()
		rec["x"] = int(xz[0])
		rec["z"] = int(xz[1])
		rec["p"] = place
		_pieces.append(rec)
	var depth_in := int(setting("inside"))
	var depth_out := int(setting("approach"))
	for gate in list:
		var inner: Vector2i = gate["inner"]
		var dir: Vector2i = gate["dir"]
		var tang := Vector2i(1, 0) if dir.x == 0 else Vector2i(0, 1)
		var far_in := inner - dir * (depth_in - 1)
		var far_out: Vector2i = gate["outer"] + dir * (depth_out - 1)
		var steps := absi((far_out - far_in).x) + absi((far_out - far_in).y)
		for i in range(steps + 1):
			for o in range(-half, half + 1):
				var tile: Vector2i = far_in + dir * i + tang * o
				_clear[_k(tile.x, tile.y)] = true


## Fills in a gate's middle, inner and outer tiles and the posts of its guards from the passage the ring left.
static func _place_gate(gate: Dictionary, ring: Dictionary, ax: int, az: int, c: int, half: int, along_x: bool) -> void:
	var dir: Vector2i = gate["dir"]
	var tang := Vector2i(1, 0) if along_x else Vector2i(0, 1)
	var anchor := Vector2i(ax, az)
	var mid: Array = []
	for tile in gate["tiles"]:
		if (tile.x if along_x else tile.y) == c:
			mid.append(tile)
	# the middle column's tiles by depth: the centre is the middle one
	mid.sort_custom(func(p, q): return _dot(p - anchor, dir) < _dot(q - anchor, dir))
	if mid.is_empty():
		gate["centre"] = anchor
		gate["inner"] = anchor
		gate["outer"] = anchor
		gate["posts"] = []
		return
	gate["centre"] = mid[mid.size() / 2]
	gate["inner"] = (mid[0] as Vector2i) - dir
	gate["outer"] = (mid[mid.size() - 1] as Vector2i) + dir
	var posts: Array = []
	for sign in [-1, 1]:
		var t: int = c + int(sign) * (half + 1)
		var best := Vector2i(-1, -1)
		var best_depth := 1 << 30
		for key in ring:
			var p := (key as String).split(",")
			var tile := Vector2i(int(p[0]), int(p[1]))
			if (tile.x if along_x else tile.y) != t or float(_dot(tile - anchor, dir)) < float(radius(str(gate["place"]))) * 0.5:
				continue
			var depth: int = _dot(tile - anchor, dir)
			if depth < best_depth:
				best_depth = depth
				best = tile
		posts.append(best - dir if best != Vector2i(-1, -1) else (gate["inner"] as Vector2i) + tang * (int(sign) * (half + 1)))
	gate["posts"] = posts


# ---------------------------------------------------------------- checks

## Whether a walker (eight ways, no cutting a corner) can get from `from` to `to` over a town's tiles, the wall's tiles and the
## buildings blocking and `open_gates` letting the passages through. Bounded to a box round the anchor.
static func reaches(place: String, from: Vector2i, to: Vector2i, open_gates: bool) -> bool:
	var a := GameWorldGen.anchor(place)
	var box := int(ceil(radius(place))) + int(setting("approach")) + 4
	var ax := int(a["x"])
	var az := int(a["z"])
	var seen := {from: true}
	var q: Array = [from]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		if c == to:
			return true
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				var n := Vector2i(c.x + dx, c.y + dz)
				if seen.has(n) or absi(n.x - ax) > box or absi(n.y - az) > box:
					continue
				if not _open(n, open_gates):
					continue
				if dx != 0 and dz != 0 and not (_open(Vector2i(c.x + dx, c.y), open_gates) and _open(Vector2i(c.x, c.y + dz), open_gates)):
					continue
				seen[n] = true
				q.append(n)
	return false


static func _open(t: Vector2i, open_gates: bool) -> bool:
	var k := kind_at(t.x, t.y)
	if k in SOLID or (k == "gate" and not open_gates):
		return false
	return not GameTown.blocks(t.x, t.y)


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "towns"]:
		if not dat.has(k):
			bad.append("walls.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var s: Dictionary = dat["settings"]
	for k in ["radius", "thickness", "gate_width", "tower_len", "approach", "inside", "max_shift", "max_step", "road_angle", "min_gates", "check_seeds"]:
		if not s.has(k):
			bad.append("walls.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if int(s["gate_width"]) < 3 or int(s["gate_width"]) % 2 == 0:
		bad.append("walls.json: the gate is an odd number of tiles wide, at least 3 (a cart passes)")
	if int(s["tower_len"]) < 1 or float(s["thickness"]) < 1.0 or int(s["approach"]) < 2 or int(s["inside"]) < 2:
		bad.append("walls.json: thickness is at least 1, towers at least 1 tile and the clear ground at least 2 tiles each way")
	if not bad.is_empty():
		return bad
	reset()
	var town_ground := float(GameWorldGen.data()["settings"]["anchor_radius"]["town"])
	for place in GameTown.towns():
		if not dat["towns"].has(place):
			bad.append("walls.json: the town %s has no wall" % place)
	for place in dat["towns"]:
		var a := GameWorldGen.anchor(str(place))
		if a.is_empty() or str(a["type"]) != "town":
			bad.append("walls.json: '%s' is not a town" % place)
			continue
		var r := radius(str(place))
		if r < town_ground + 1.0 or r > town_ground + float(GameWorldGen.data()["settings"]["water"]["clear_inner"]):
			bad.append("walls.json: the wall of %s (radius %.0f) should stand just past the town's ground (%.0f) and on dry ground" % [place, r, town_ground])
		var ax := int(a["x"])
		var az := int(a["z"])
		# every building and every door inside the ring, with a tile to spare
		for b in GameTown.buildings(str(place)):
			for dz in int(b["h"]):
				for dx in int(b["w"]):
					if Vector2(int(b["x"]) + dx - ax, int(b["z"]) + dz - az).length() > r - float(s["thickness"]) - 1.0:
						bad.append("walls.json: %s reaches the wall of %s" % [b["id"], place])
			var dd: Vector2i = b["door"]
			if Vector2(dd.x - ax, dd.y - az).length() > r - float(s["thickness"]) - 1.0:
				bad.append("walls.json: the door of %s is outside the wall of %s" % [b["id"], place])
		var gl := gates(str(place))
		var sides := {}
		if gl.size() < int(s["min_gates"]):
			bad.append("walls.json: %s has %d gates, at least %d" % [place, gl.size(), int(s["min_gates"])])
		for g in dat["towns"][place]["gates"]:
			if not DIRS.has(str(g.get("side", ""))):
				bad.append("walls.json: a gate of %s has the side '%s' (n, e, s or w)" % [place, g.get("side", "")])
			elif absi(int(g.get("shift", 0))) > int(s["max_shift"]):
				bad.append("walls.json: a gate of %s is shifted more than %d tiles" % [place, int(s["max_shift"])])
		for g in gl:
			if sides.has(str(g["side"])):
				bad.append("walls.json: %s has two gates on the %s side" % [place, g["side"]])
			sides[str(g["side"])] = true
			# the passage is as wide as a gate is and has its inner and outer tiles on open, flat, dry ground
			var cols := {}
			for t in g["tiles"]:
				cols[t.x if str(g["axis"]) == "ns" else t.y] = true
			if cols.size() != int(s["gate_width"]):
				bad.append("walls.json: the passage of %s is %d tiles wide, not %d" % [g["id"], cols.size(), int(s["gate_width"])])
			if (g["posts"] as Array).size() != 2:
				bad.append("walls.json: %s has no two places for its guards" % g["id"])
			for p in g["posts"]:
				if kind_at(p.x, p.y) != "" or GameTown.blocks(p.x, p.y):
					bad.append("walls.json: a guard's place at %s is not open ground" % g["id"])
		# each road that leaves the town has a gate where it leaves
		for road in roads_from(str(place)):
			var found := false
			for g in gl:
				if _angle_diff(float(road["angle"]), float(ANGLES[str(g["side"])])) <= float(s["road_angle"]):
					found = true
			if not found:
				bad.append("walls.json: the road from %s to %s leaves by no gate" % [place, road["to"]])
		# the ring is whole: sealed with the gates shut, and open through every gate
		var inside := Vector2i(ax, az)
		var outside_probe := Vector2i(ax + int(ceil(r)) + 3, az + int(ceil(r)) + 3)
		if reaches(str(place), inside, outside_probe, false):
			bad.append("walls.json: the wall of %s has a gap" % place)
		for g in gl:
			if not reaches(str(place), inside, g["outer"], true):
				bad.append("walls.json: nobody can walk out of %s by the gate %s" % [place, g["id"]])
		# the ground under the wall is dry and flat, on several seeds
		for sd in s["check_seeds"]:
			var h0 := GameWorldGen.height_at(int(sd), ax, az)
			for key in tiles(str(place)):
				var p := (key as String).split(",")
				var x := int(p[0])
				var z := int(p[1])
				if not GameWorldGen.in_bounds(x, z) or GameWorldGen.water_at(int(sd), x, z) or absi(GameWorldGen.height_at(int(sd), x, z) - h0) > int(s["max_step"]):
					bad.append("walls.json: the wall of %s stands on wet or uneven ground at %d,%d on the seed %d" % [place, x, z, int(sd)])
					break
	return bad
