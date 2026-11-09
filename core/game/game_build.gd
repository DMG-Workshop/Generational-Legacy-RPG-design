## Building and placement rules (roadmap item 50). The family house is the first base: the family may build only inside a
## claim round the home town (data/world/building.json `base_place`), which grows with every level bought in the house.
## A piece (wall, floor, road, door: the kinds GamePath walks) goes in one cell of the surface (layer y = -1) or of dug ground
## (y = 0 and down) and is paid for from the family's stores and the heir's gold. What can stand where: one piece to a
## cell; nothing on a tree or rock outcrop; level ground (`max_slope`); over water only a floor or road, as a bridge that
## reaches the shore within `max_span` tiles; a door only between two walls; underground only in dug ground. A wall cannot
## be taken away while a door hangs on it, nor a plank while another rests on it. A room is a region shut in by walls and
## doors (four-way, as GamePath never cuts a corner), no bigger than `max_room_area`.
## The built pieces are `GameDynasty.built` ({"x,y,z": kind}, saved only when not empty, loaded clean) and are what
## `GamePath.world_ground` uses by default, so building changes how creatures walk. Nothing is random and the autopilot
## never builds.
class_name GameBuild
extends RefCounted

const PATH := "res://data/world/building.json"
const SURFACE := -1
const DIRS4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func pieces() -> Dictionary:
	return data()["pieces"]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


# ---------------------------------------------------------------- the base

## The home town's anchor in the generated world.
static func base() -> Dictionary:
	return GameWorldGen.anchor(str(setting("base_place")))


## How far from the home town the family may build: the base radius and more for each level bought in the house.
static func claim_radius(d: GameDynasty) -> float:
	var levels := 0
	for track in GameHouse.TRACKS:
		levels += GameHouse.level(d, track)
	return float(setting("base_radius")) + float(setting("radius_per_house_level")) * float(levels)


static func in_claim(d: GameDynasty, x: int, z: int) -> bool:
	var b := base()
	if b.is_empty():
		return false
	return Vector2(float(x), float(z)).distance_to(Vector2(float(b["x"]), float(b["z"]))) <= claim_radius(d)


# ---------------------------------------------------------------- what is built

static func key(x: int, y: int, z: int) -> String:
	return "%d,%d,%d" % [x, y, z]


static func kind_at(d: GameDynasty, x: int, y: int, z: int) -> String:
	return str(d.built.get(key(x, y, z), ""))


static func count(d: GameDynasty) -> int:
	return d.built.size()


## A saved key "x,y,z" as a cell, or null when it is not one.
static func parse(k: String) -> Variant:
	var parts := k.split(",")
	if parts.size() != 3:
		return null
	for p in parts:
		if not p.is_valid_int():
			return null
	return Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))


# ---------------------------------------------------------------- rules

## Why a piece cannot be built in a cell, or "" when it can. Nothing is spent or changed.
static func check(d: GameDynasty, kind: String, x: int, y: int, z: int) -> String:
	if not pieces().has(kind):
		return text("unknown", {"kind": kind})
	var p: Dictionary = pieces()[kind]
	var piece := str(p["name"]).to_lower()
	if y < SURFACE or y > int(GameMine.setting("max_depth")):
		return text("out_of_range")
	if not GameWorldGen.in_bounds(x, z):
		return text("off_map")
	if not in_claim(d, x, z):
		return text("outside_claim", {"radius": int(claim_radius(d)), "place": str(base()["name"])})
	if d.built.has(key(x, y, z)):
		return text("occupied")
	if y == SURFACE:
		var surf: Callable = GamePath.world_ground(d)["surface"]
		var info: Dictionary = surf.call(x, z)
		if bool(info["water"]):
			if not bool(p["over_water"]):
				return text("water", {"piece": piece})
			if not _bridge_ok(d, surf, x, z):
				return text("span", {"span": int(setting("max_span"))})
		else:
			if bool(info["block"]):
				return text("in_the_way")
			for dir in DIRS4:
				var n: Dictionary = surf.call(x + dir.x, z + dir.y)
				if n.is_empty() or bool(n["water"]):
					continue
				if absi(int(n["h"]) - int(info["h"])) > int(p["max_slope"]):
					return text("slope", {"piece": piece})
	elif not GameMine.is_dug(d, GameWorldGen.MINE_SITE, x, y, z):
		return text("undug")
	if bool(p["needs_frame"]) and not _framed(d, x, y, z, ""):
		return text("needs_frame")
	return _cost_problem(d, p)


static func _cost_problem(d: GameDynasty, p: Dictionary) -> String:
	for m in p["cost"]:
		if GameCraft.have(d, str(m)) < int(p["cost"][m]):
			return text("missing", {"material": GameMaterials.name_of(str(m)).to_lower(), "need": int(p["cost"][m]), "have": GameCraft.have(d, str(m))})
	if int(p["gold"]) > d.heir.gold:
		return text("gold", {"need": int(p["gold"])})
	return ""


## Whether a cell has a wall on each of two opposite sides (a door's frame), not counting the cell `ignore`.
static func _framed(d: GameDynasty, x: int, y: int, z: int, ignore: String) -> bool:
	for pair in [[Vector2i(1, 0), Vector2i(-1, 0)], [Vector2i(0, 1), Vector2i(0, -1)]]:
		var both := true
		for dir in pair:
			var k := key(x + dir.x, y, z + dir.y)
			if k == ignore or str(d.built.get(k, "")) != "wall":
				both = false
		if both:
			return true
	return false


## Whether a bridge piece over water at (x, z) is joined to the shore by built pieces over water, within `max_span` tiles.
static func _bridge_ok(d: GameDynasty, surf: Callable, x: int, z: int) -> bool:
	var seen := {Vector2i(x, z): true}
	var frontier: Array = [Vector2i(x, z)]
	for depth in range(1, int(setting("max_span")) + 1):
		var next: Array = []
		for c in frontier:
			for dir in DIRS4:
				var n: Vector2i = c + dir
				var info: Dictionary = surf.call(n.x, n.y)
				if info.is_empty() or seen.has(n):
					continue
				if not bool(info["water"]):
					return true
				if d.built.has(key(n.x, SURFACE, n.y)):
					seen[n] = true
					next.append(n)
		frontier = next
	return false


# ---------------------------------------------------------------- building and taking down

## Builds a piece: {ok, text}. Spends its materials and gold only when it is built.
static func place(d: GameDynasty, kind: String, x: int, y: int, z: int) -> Dictionary:
	var why := check(d, kind, x, y, z)
	if why != "":
		return {"ok": false, "text": why}
	var p: Dictionary = pieces()[kind]
	for m in p["cost"]:
		GameCraft.add_material(d, str(m), -int(p["cost"][m]))
	d.heir.gold -= int(p["gold"])
	d.built[key(x, y, z)] = kind
	return {"ok": true, "text": text("placed", {"piece": str(p["name"]).to_lower()})}


## Takes a piece down and gives back its `refund` share: {ok, text}.
static func remove(d: GameDynasty, x: int, y: int, z: int) -> Dictionary:
	var k := key(x, y, z)
	var kind := str(d.built.get(k, ""))
	if kind == "":
		return {"ok": false, "text": text("nothing")}
	var p: Dictionary = pieces()[kind]
	if kind == "wall":
		for dir in DIRS4:
			if kind_at(d, x + dir.x, y, z + dir.y) == "door" and not _framed(d, x + dir.x, y, z + dir.y, k):
				return {"ok": false, "text": text("hangs")}
	if y == SURFACE:
		var surf: Callable = GamePath.world_ground(d)["surface"]
		if bool(surf.call(x, z)["water"]):
			d.built.erase(k)
			for dir in DIRS4:
				var n: Vector2i = Vector2i(x, z) + dir
				if d.built.has(key(n.x, SURFACE, n.y)) and bool(surf.call(n.x, n.y)["water"]) and not _bridge_ok(d, surf, n.x, n.y):
					d.built[k] = kind
					return {"ok": false, "text": text("bears")}
			d.built[k] = kind
	d.built.erase(k)
	var back: Array = []
	for m in p["cost"]:
		var n := int(floor(float(p["cost"][m]) * float(p["refund"])))
		if n > 0:
			GameCraft.add_material(d, str(m), n)
			back.append("%d %s" % [n, GameMaterials.name_of(str(m)).to_lower()])
	var gold := int(floor(float(p["gold"]) * float(p["refund"])))
	if gold > 0:
		d.heir.gold += gold
		back.append("%d gold" % gold)
	var piece := str(p["name"]).to_lower()
	if back.is_empty():
		return {"ok": true, "text": text("removed", {"piece": piece})}
	return {"ok": true, "text": text("removed_back", {"piece": piece, "back": ", ".join(back)})}


# ---------------------------------------------------------------- rooms

## The rooms on the surface: regions shut in by walls and doors, no bigger than `max_room_area`, with no open water in them.
## Each is {cells: [Vector2i] sorted, area, doors: [Vector2i] sorted, sealed: true when it has no door}.
static func rooms(d: GameDynasty) -> Array:
	var cells := {}
	for k in d.built:
		var c: Variant = parse(str(k))
		if c != null and (c as Vector3i).y == SURFACE:
			cells[Vector2i(c.x, c.z)] = str(d.built[k])
	var out: Array = []
	if cells.is_empty():
		return out
	var lo := Vector2i(1000000, 1000000)
	var hi := Vector2i(-1000000, -1000000)
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	lo -= Vector2i(1, 1)
	hi += Vector2i(1, 1)
	var surf: Callable = GamePath.world_ground(d)["surface"]
	var seen := {}
	for x in range(lo.x, hi.x + 1):
		for z in range(lo.y, hi.y + 1):
			var start := Vector2i(x, z)
			if seen.has(start) or cells.get(start, "") in ["wall", "door"]:
				continue
			var region: Array = []
			var doors := {}
			var open := false
			var wet := false
			var stack: Array = [start]
			seen[start] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				region.append(c)
				if c.x == lo.x or c.y == lo.y or c.x == hi.x or c.y == hi.y:
					open = true
				var info: Dictionary = surf.call(c.x, c.y)
				if not info.is_empty() and bool(info["water"]) and not cells.has(c):
					wet = true
				for dir in DIRS4:
					var n: Vector2i = c + dir
					if n.x < lo.x or n.y < lo.y or n.x > hi.x or n.y > hi.y:
						continue
					var kind := str(cells.get(n, ""))
					if kind == "door":
						doors[n] = true
					elif kind != "wall" and not seen.has(n):
						seen[n] = true
						stack.append(n)
			if open or wet or region.size() > int(setting("max_room_area")):
				continue
			region.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
			var door_list: Array = doors.keys()
			door_list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
			out.append({"cells": region, "area": region.size(), "doors": door_list, "sealed": door_list.is_empty()})
	return out


## The room a surface tile is in, or {}.
static func room_at(d: GameDynasty, x: int, z: int) -> Dictionary:
	for r in rooms(d):
		if (r["cells"] as Array).has(Vector2i(x, z)):
			return r
	return {}


static func describe(d: GameDynasty) -> String:
	return text("summary", {"pieces": count(d), "rooms": rooms(d).size()})


# ---------------------------------------------------------------- saving

## The saved pieces, checked: a "x,y,z" of whole numbers inside the world (and the ground that can be dug), a known kind.
static func load_state(v: Variant) -> Dictionary:
	var out := {}
	if typeof(v) != TYPE_DICTIONARY:
		return out
	for k in v:
		var c: Variant = parse(str(k))
		if c == null or typeof(v[k]) != TYPE_STRING or not pieces().has(str(v[k])):
			continue
		var cell: Vector3i = c
		if cell.y < SURFACE or cell.y > int(GameMine.setting("max_depth")) or not GameWorldGen.in_bounds(cell.x, cell.z):
			continue
		out[key(cell.x, cell.y, cell.z)] = str(v[k])
	return out


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = data()
	for k in ["settings", "pieces", "text"]:
		if not dat.has(k):
			bad.append("building.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var s: Dictionary = dat["settings"]
	for k in ["base_place", "base_radius", "radius_per_house_level", "max_span", "max_room_area"]:
		if not s.has(k):
			bad.append("building.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	var home := GameWorldGen.anchor(str(s["base_place"]))
	if home.is_empty():
		bad.append("building.json: base_place '%s' is not a place in the world" % s["base_place"])
	elif str(home["type"]) != "town":
		bad.append("building.json: the base should be a town (the family's home), not a %s" % home["type"])
	if float(s["base_radius"]) < 3.0 or float(s["radius_per_house_level"]) < 0.0:
		bad.append("building.json: base_radius must be at least 3 and radius_per_house_level 0 or more")
	if int(s["max_span"]) < 1 or int(s["max_room_area"]) < 1:
		bad.append("building.json: max_span and max_room_area must be at least 1")
	var kinds: Dictionary = GamePath.data()["built"]
	for kind in kinds:
		if not dat["pieces"].has(kind):
			bad.append("building.json: GamePath walks a '%s' but nothing can build it" % kind)
	for id in dat["pieces"]:
		var p: Dictionary = dat["pieces"][id]
		if not kinds.has(id):
			bad.append("building.json: piece '%s' is not a kind GamePath knows" % id)
		for k in ["name", "cost", "gold", "refund", "max_slope", "over_water", "needs_frame"]:
			if not p.has(k):
				bad.append("building.json: piece '%s' has no %s" % [id, k])
		if not bad.is_empty():
			return bad
		for m in p["cost"]:
			if not GameMaterials.has(str(m)):
				bad.append("building.json: piece '%s' costs unknown material '%s'" % [id, m])
			elif int(p["cost"][m]) < 1:
				bad.append("building.json: piece '%s' costs a non-positive amount of %s" % [id, m])
		if p["cost"].is_empty() and int(p["gold"]) < 1:
			bad.append("building.json: piece '%s' costs nothing" % id)
		if float(p["refund"]) < 0.0 or float(p["refund"]) > 1.0:
			bad.append("building.json: piece '%s' refund must be 0 to 1" % id)
		if int(p["max_slope"]) < 0:
			bad.append("building.json: piece '%s' max_slope must be 0 or more" % id)
		if bool(p["over_water"]) and bool(kinds.get(id, {}).get("solid", false)):
			bad.append("building.json: a solid piece ('%s') cannot be a bridge" % id)
	for key_id in ["unknown", "out_of_range", "off_map", "outside_claim", "occupied", "water", "span", "in_the_way", "slope", "undug", "needs_frame", "missing", "gold", "placed", "nothing", "hangs", "bears", "removed", "removed_back", "summary"]:
		if not dat["text"].has(key_id):
			bad.append("building.json: text.%s is missing" % key_id)
	return bad
