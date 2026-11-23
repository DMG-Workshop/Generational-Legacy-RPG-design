## What is in each dungeon (data/world/dungeons.json): rooms with roles (spaces.json), the creatures that live in each, the
## containers, traps and features placed by role, and what the heir has opened, sprung, used or killed (the dynasty's
## `dungeon_marks`, saved only once something is). Where things stand is a pure function of the dungeon's id (the same every
## game); who is met and what is found uses dice keyed on the seed, never the dynasty's. The sandbox asks (the Use action,
## stepping on a trap, a creature's contact); the rules of a life never do, so the autopilot and golden digests do not move.
## Run: godot --headless --path . -s res://tests/test_game_dungeons.gd
class_name GameDungeons
extends RefCounted

const PATH := "res://data/world/dungeons.json"
static var _cache: Dictionary = {}
static var _layouts: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


## The dungeons that have contents: place ids.
static func dungeon_ids() -> Array:
	var out: Array = []
	for l in GameData.world["locations"]:
		if str(l["type"]) == "dungeon":
			out.append(str(l["id"]))
	return out


## The place id of a dungeon's space id ("world/hollow_barrow" is "hollow_barrow"), "" for anything else.
static func place_of(space_id: String) -> String:
	if GameSpaces.kind(space_id) != "interior":
		return ""
	var p := str(GameSpaces.space(space_id).get("place", ""))
	return p if data()["dungeons"].has(p) and space_id == "world/" + p else ""


static func is_dungeon(space_id: String) -> bool:
	return place_of(space_id) != ""


static func _key(x: int, z: int) -> String:
	return "%d,%d" % [x, z]


static func _hash(tags: Array) -> int:
	return absi(hash(tags))


# ---------------------------------------------------------------- where things stand

## The layout of a dungeon, built once: {containers: [{id, room, role, x, z, kind, tier}], traps: [{id, room, x, z, kind}],
## foes: [{key, room, role, x, z}], boss: {key, room, x, z} or {}, locks: [{id, x, z, key, name, rooms: [from, to]}] (a door that
## stays shut until its key is used; a container that holds a key has `key` set), features: [{id, room, x, z, prop, kind, name, ...}],
## solid: {"x,z": true} (cells the heir cannot stand on) and reserved: {"x,z": true}}.
static func layout(space_id: String) -> Dictionary:
	var place := place_of(space_id)
	if place == "":
		return {}
	if _layouts.has(place):
		return _layouts[place]
	var cells := GameInterior.cells(space_id)
	var out := {"containers": [], "traps": [], "foes": [], "boss": {}, "features": [], "locks": [], "solid": {}, "reserved": {}}
	var near_door := {}
	for k in cells:
		if str(cells[k]) in ["door", "exit"]:
			var p := GameInterior._parse(k)
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					near_door[_key(p.x + dx, p.y + dz)] = true
	var tables: Dictionary = data()["dungeons"][place]["roles"]
	for room in GameSpaces.rooms(space_id):
		var rid := str(room["id"])
		var role := str(room.get("role", ""))
		var rect: Array = room["rect"]
		var floor_cells: Array = []
		for dz in int(rect[3]):
			for dx in int(rect[2]):
				var x := int(rect[0]) + dx
				var z := int(rect[1]) + dz
				if str(cells.get(_key(x, z), "")) == "floor":
					floor_cells.append(Vector2i(x, z))
		var table: Dictionary = tables.get(role, {})
		# features sit at the head of the room (the middle of its north row)
		var head := Vector2i(int(rect[0]) + int(rect[2]) / 2, int(rect[1]))
		var fi := 0
		for f in table.get("features", []):
			var spot := head + Vector2i(fi, 0)
			if cells.get(_key(spot.x, spot.y), "") == "floor" and not near_door.has(_key(spot.x, spot.y)) and _try_solid(cells, out, spot):
				out["features"].append({"id": "%s#f%d" % [rid, fi], "room": rid, "x": spot.x, "z": spot.y, "prop": str(f["prop"]), "kind": str(f["kind"]), "name": str(f["name"]), "text": str(f["text"]), "effect": str(f.get("effect", "")), "pct": float(f.get("pct", 0.0)), "spent": str(f.get("spent", ""))})
			fi += 1
		# containers: against a wall, away from doors, never blocking the way
		var edge: Array = floor_cells.filter(func(c): return _against_wall(cells, c) and not near_door.has(_key(c.x, c.y)) and not out["reserved"].has(_key(c.x, c.y)))
		edge.sort_custom(func(a, b): return _hash([place, rid, "box", a.x, a.y]) < _hash([place, rid, "box", b.x, b.y]))
		# a key lies in a container of its room (placed first, so no other container takes its spot)
		for kspec in data()["dungeons"][place].get("keys", []):
			if str(kspec["room"]) != rid:
				continue
			for c in edge:
				if out["reserved"].has(_key(c.x, c.y)):
					continue
				if _try_solid(cells, out, c):
					out["containers"].append({"id": "%s#%d" % [rid, out["containers"].size()], "room": rid, "role": role, "x": c.x, "z": c.y, "kind": str(kspec["kind"]), "tier": str(kspec.get("tier", "plain")), "key": str(kspec["id"])})
					break
		var ci := 0
		for spec in table.get("containers", []):
			var n := _count(place, rid, "boxn%d" % ci, spec["count"])
			for i in n:
				var placed := false
				for c in edge:
					if out["reserved"].has(_key(c.x, c.y)):
						continue
					if _try_solid(cells, out, c):
						out["containers"].append({"id": "%s#%d" % [rid, out["containers"].size()], "room": rid, "role": role, "x": c.x, "z": c.y, "kind": str(spec["kind"]), "tier": str(spec["tier"])})
						placed = true
						break
				if not placed:
					break
			ci += 1
		# traps: hidden floor cells away from the doors
		var open: Array = floor_cells.filter(func(c): return not near_door.has(_key(c.x, c.y)) and not out["reserved"].has(_key(c.x, c.y)))
		open.sort_custom(func(a, b): return _hash([place, rid, "trap", a.x, a.y]) < _hash([place, rid, "trap", b.x, b.y]))
		var ti := 0
		var ti_n := 0
		for spec in table.get("traps", []):
			var n := _count(place, rid, "trapn%d" % ti, spec["count"])
			for i in n:
				if ti_n >= open.size():
					break
				var c: Vector2i = open[ti_n]
				ti_n += 1
				out["reserved"][_key(c.x, c.y)] = true
				out["traps"].append({"id": "%s#t%d" % [rid, out["traps"].size()], "room": rid, "x": c.x, "z": c.y, "kind": str(spec["kind"])})
			ti += 1
		# foes: where they stand, away from the way in
		var min_d := float(setting("min_foe_distance"))
		var spots: Array = floor_cells.filter(func(c): return Vector2(c).length() >= min_d and not out["reserved"].has(_key(c.x, c.y)) and not near_door.has(_key(c.x, c.y)))
		spots.sort_custom(func(a, b): return _hash([place, rid, "foe", a.x, a.y]) < _hash([place, rid, "foe", b.x, b.y]))
		var fcount := 0
		var foes: Dictionary = table.get("foes", {})
		if not foes.is_empty():
			fcount = mini(_count(place, rid, "foes", foes["count"]), maxi(1, floor_cells.size() / 6))
		for i in mini(fcount, spots.size()):
			var c: Vector2i = spots[i]
			out["foes"].append({"key": "%s#%d" % [rid, i], "room": rid, "role": role, "x": c.x, "z": c.y})
			out["reserved"][_key(c.x, c.y)] = true
		if role == "boss_lair" and out["boss"].is_empty() and not floor_cells.is_empty():
			var mid := Vector2(float(rect[0]) + float(rect[2]) / 2.0, float(rect[1]) + float(rect[3]) / 2.0)
			var best: Vector2i = floor_cells[0]
			for c in floor_cells:
				if Vector2(c).distance_to(mid) < Vector2(best).distance_to(mid) and not out["reserved"].has(_key(c.x, c.y)):
					best = c
			out["boss"] = {"key": "%s#boss" % rid, "room": rid, "x": best.x, "z": best.y}
			out["reserved"][_key(best.x, best.y)] = true
	for lk in data()["dungeons"][place].get("locks", []):
		var at := _door_between(space_id, str(lk["door"][0]), str(lk["door"][1]))
		if at != Vector2i(-9999, -9999):
			out["locks"].append({"id": str(lk["id"]), "x": at.x, "z": at.y, "key": str(lk["key"]), "name": str(lk["name"]), "rooms": [str(lk["door"][0]), str(lk["door"][1])]})
	_layouts[place] = out
	return out


## The cell of the door between two rooms of a plan, or (-9999, -9999) when there is none.
static func _door_between(space_id: String, a: String, b: String) -> Vector2i:
	for dr in GameSpaces._layout(space_id).get("doors", []):
		if (str(dr["from"]) == a and str(dr["to"]) == b) or (str(dr["from"]) == b and str(dr["to"]) == a):
			return Vector2i(int(dr["at"][0]), int(dr["at"][1]))
	return Vector2i(-9999, -9999)


static func room_ids(space_id: String) -> Dictionary:
	var out := {}
	for rm in GameSpaces.rooms(space_id):
		out[str(rm["id"])] = true
	return out


static func _count(place: String, room: String, tag: String, range_: Array) -> int:
	var r := RandomNumberGenerator.new()
	r.seed = _hash([place, room, tag])
	return r.randi_range(int(range_[0]), int(range_[1]))


static func _against_wall(cells: Dictionary, c: Vector2i) -> bool:
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if str(cells.get(_key(c.x + dir.x, c.y + dir.y), "")) == "wall":
			return true
	return false


## Makes a cell solid if every walkable cell is still reached from the way in; false (and nothing changes) if not.
static func _try_solid(cells: Dictionary, out: Dictionary, c: Vector2i) -> bool:
	var k := _key(c.x, c.y)
	if out["reserved"].has(k) or str(cells.get(k, "")) != "floor":
		return false
	out["solid"][k] = true
	if not still_connected(cells, out["solid"]):
		out["solid"].erase(k)
		return false
	out["reserved"][k] = true
	return true


## Whether every walkable cell that is not in `solid` can be reached from the way in without stepping on `solid`.
static func still_connected(cells: Dictionary, solid: Dictionary) -> bool:
	var total := 0
	for k in cells:
		if str(cells[k]) in GameInterior.WALKABLE and not solid.has(k):
			total += 1
	var e := GameInterior.entry()
	var seen := {_key(e.x, e.y): true}
	var stack: Array = [e]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dir
			var nk := _key(n.x, n.y)
			if seen.has(nk) or solid.has(nk) or not GameInterior.passable(cells, n.x, n.y):
				continue
			seen[nk] = true
			stack.append(n)
	return seen.size() == total


## The walkable cells of a dungeon as the sandbox walks them: the floor plan's, with the containers, features and solid props
## of the art as `prop` cells that cannot be stood on. Given the dynasty, a door whose key has not been used is `locked`, a cell
## that cannot be stood on either (it is `door` once opened).
static func walk_cells(space_id: String, d: GameDynasty = null) -> Dictionary:
	var cells := GameInterior.cells(space_id)
	if not is_dungeon(space_id):
		return cells
	if d != null:
		for lk in layout(space_id)["locks"]:
			if not lock_open(d, space_id, str(lk["id"])):
				cells[_key(int(lk["x"]), int(lk["z"]))] = "locked"
	for k in layout(space_id)["solid"]:
		cells[k] = "prop"
	for k in GameDungeonArt.solid_props(space_id):
		cells[k] = "prop"
	return cells


# ---------------------------------------------------------------- who is here

## The foes of a dungeon now: [{key, creature, x, z, room, boss}] (a creature of the era from the room's pool; the lair's
## boss when it is stirring), without those the heir has killed recently. Keyed on the seed, never the dynasty's dice.
static func inhabitants(d: GameDynasty, space_id: String) -> Array:
	var place := place_of(space_id)
	var out: Array = []
	if place == "":
		return out
	var lay := layout(space_id)
	var tables: Dictionary = data()["dungeons"][place]["roles"]
	var era := d.era_gen()
	for f in lay["foes"]:
		if is_marked(d, "k", place, str(f["key"])):
			continue
		var spec: Dictionary = tables.get(str(f["role"]), {}).get("foes", {})
		var id := _creature_for(d, place, str(f["key"]), spec.get("pool", []), era)
		if id != "":
			out.append({"key": str(f["key"]), "creature": id, "x": int(f["x"]), "z": int(f["z"]), "room": str(f["room"]), "boss": false})
	var boss: Dictionary = lay["boss"]
	var lair := str(GameWorld.place(place).get("lair", ""))
	if not boss.is_empty() and lair != "" and boss_stirring(d, lair):
		out.append({"key": str(boss["key"]), "creature": lair, "x": int(boss["x"]), "z": int(boss["z"]), "room": str(boss["room"]), "boss": true})
	return out


## Whether a legend is up in this Age: its window holds and it has not been slain.
static func boss_stirring(d: GameDynasty, id: String) -> bool:
	for c in d.stirring_legends():
		if str(c["id"]) == id:
			return true
	return false


static func _creature_for(d: GameDynasty, place: String, key: String, pool: Array, era: int) -> String:
	var rows: Array = _era_rows(pool, era)
	if rows.is_empty():
		rows = _era_rows(data()["dungeons"][place].get("fallback", []), era)
	if rows.is_empty():
		return ""
	var r := RandomNumberGenerator.new()
	r.seed = _hash([d.seed_value, "dungeon_foe", place, key, era])
	return str(GameLoot.pick_weighted(r, rows)["id"])


static func _era_rows(pool: Array, era: int) -> Array:
	var rows: Array = []
	for p in pool:
		var c := GameBehaviour._def(str(p["id"]))
		if not c.is_empty() and int(c["min_gen"]) <= era and era <= int(c["max_gen"]):
			rows.append(p)
	return rows


# ---------------------------------------------------------------- marks

static func mark_key(kind: String, place: String, key: String) -> String:
	return "%s:%s:%s" % [kind, place, key]


static func _span(kind: String) -> float:
	if kind in ["y", "d"]:   # a key held and a door opened do not come back
		return INF
	return float(setting("foe_years")) if kind == "k" else float(setting("refill_years"))


## Whether a thing was marked (o opened, t sprung, f used, k killed, y a key held, d a door opened) and has not yet come back.
static func is_marked(d: GameDynasty, kind: String, place: String, key: String) -> bool:
	var k := mark_key(kind, place, key)
	return d.dungeon_marks.has(k) and float(d.world.year) - float(d.dungeon_marks[k]) < _span(kind)


static func mark(d: GameDynasty, kind: String, place: String, key: String) -> void:
	d.dungeon_marks[mark_key(kind, place, key)] = float(d.world.year)


static func has_unique(d: GameDynasty, item: String) -> bool:
	return d.dungeon_marks.has("u:" + item)


static func mark_unique(d: GameDynasty, item: String) -> void:
	d.dungeon_marks["u:" + item] = float(d.world.year)


## The saved marks, checked: "kind:place:key" and "u:item" keys with a finite number of years, else dropped.
static func load_marks(v: Variant) -> Dictionary:
	var out := {}
	if typeof(v) != TYPE_DICTIONARY:
		return out
	for k in v:
		if typeof(k) != TYPE_STRING or typeof(v[k]) not in [TYPE_INT, TYPE_FLOAT] or is_nan(float(v[k])) or is_inf(float(v[k])):
			continue
		var parts := str(k).split(":")
		if (parts[0] == "u" and parts.size() == 2) or (parts[0] in ["o", "t", "f", "k", "y", "d"] and parts.size() == 3):
			out[str(k)] = float(v[k])
	return out


# ---------------------------------------------------------------- acting

## What the Use action finds beside a cell: the nearest container, feature or (given the dynasty) shut door within `reach`
## (Chebyshev), {} for none.
static func thing_near(space_id: String, x: int, z: int, d: GameDynasty = null) -> Dictionary:
	var lay := layout(space_id)
	if lay.is_empty():
		return {}
	var reach := int(setting("reach"))
	var best: Dictionary = {}
	var best_d := 99.0
	for c in lay["containers"]:
		var dist := Vector2(float(int(c["x"]) - x), float(int(c["z"]) - z)).length()
		if maxi(absi(int(c["x"]) - x), absi(int(c["z"]) - z)) <= reach and dist < best_d:
			best_d = dist
			best = {"type": "container", "thing": c}
	for f in lay["features"]:
		var dist := Vector2(float(int(f["x"]) - x), float(int(f["z"]) - z)).length()
		if maxi(absi(int(f["x"]) - x), absi(int(f["z"]) - z)) <= reach and dist < best_d:
			best_d = dist
			best = {"type": "feature", "thing": f}
	if d != null:
		for lk in lay["locks"]:
			var dist := Vector2(float(int(lk["x"]) - x), float(int(lk["z"]) - z)).length()
			if not lock_open(d, space_id, str(lk["id"])) and maxi(absi(int(lk["x"]) - x), absi(int(lk["z"]) - z)) <= reach and dist < best_d:
				best_d = dist
				best = {"type": "lock", "thing": lk}
	return best


# ---------------------------------------------------------------- locked doors and keys

static func lock_open(d: GameDynasty, space_id: String, id: String) -> bool:
	return d.dungeon_marks.has(mark_key("d", place_of(space_id), id))


## Whether the heir holds a key (and has not yet used it).
static func has_key(d: GameDynasty, space_id: String, key: String) -> bool:
	return d.dungeon_marks.has(mark_key("y", place_of(space_id), key))


## Whether a cell is a door still shut.
static func lock_closed(d: GameDynasty, space_id: String, x: int, z: int) -> bool:
	for lk in layout(space_id).get("locks", []):
		if int(lk["x"]) == x and int(lk["z"]) == z:
			return not lock_open(d, space_id, str(lk["id"]))
	return false


static func key_name(space_id: String, key: String) -> String:
	for k in data()["dungeons"][place_of(space_id)].get("keys", []):
		if str(k["id"]) == key:
			return str(k["name"])
	return key


static func _key_spent(d: GameDynasty, space_id: String, key: String) -> bool:
	for lk in layout(space_id)["locks"]:
		if str(lk["key"]) == key and lock_open(d, space_id, str(lk["id"])):
			return true
	return false


## The Use action beside a shut door: with its key the key is spent and the door opens for good; without, the heir is told what
## it needs. {ok, text, dirty, lines, opened: Vector2i when it opened}.
static func use_lock(d: GameDynasty, space_id: String, lk: Dictionary) -> Dictionary:
	var place := place_of(space_id)
	var cell := Vector2i(int(lk["x"]), int(lk["z"]))
	var kname := key_name(space_id, str(lk["key"]))
	if not has_key(d, space_id, str(lk["key"])):
		var t := text("locked", {"door": str(lk["name"]), "key": kname.to_lower()})
		return {"ok": false, "text": t, "dirty": [], "lines": [t]}
	d.dungeon_marks.erase(mark_key("y", place, str(lk["key"])))
	d.dungeon_marks[mark_key("d", place, str(lk["id"]))] = float(d.world.year)
	var t2 := text("unlocked", {"h": d.heir.name, "door": str(lk["name"]), "key": kname.to_lower()})
	return {"ok": true, "text": t2, "dirty": [cell], "lines": [t2], "opened": cell}


## Whether every walkable cell of a dungeon can be reached from the way in by taking the keys that lie on the way, in some
## order (so no key is locked behind its own door, and no room is cut off for good). Used by the validator and the tests.
static func solvable(space_id: String) -> bool:
	var lay := layout(space_id)
	var cells := GameInterior.cells(space_id)
	var solid: Dictionary = lay["solid"]
	var held := {}
	var opened := {}
	var total := 0
	var reach := int(setting("reach"))
	for k in cells:
		if str(cells[k]) in GameInterior.WALKABLE and not solid.has(k):
			total += 1
	while true:
		var seen := {}
		var e := GameInterior.entry()
		seen[_key(e.x, e.y)] = true
		var stack: Array = [e]
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + dir
				var nk := _key(n.x, n.y)
				if seen.has(nk) or solid.has(nk) or not GameInterior.passable(cells, n.x, n.y):
					continue
				var shut := false
				for lk in lay["locks"]:
					if int(lk["x"]) == n.x and int(lk["z"]) == n.y and not opened.has(str(lk["id"])):
						shut = true
				if shut:
					continue
				seen[nk] = true
				stack.append(n)
		var progress := false
		for ct in lay["containers"]:
			if not ct.has("key") or held.has(str(ct["key"])):
				continue
			if _beside(seen, int(ct["x"]), int(ct["z"]), reach):
				held[str(ct["key"])] = true
				progress = true
		for lk in lay["locks"]:
			if held.has(str(lk["key"])) and not opened.has(str(lk["id"])) and _beside(seen, int(lk["x"]), int(lk["z"]), reach):
				opened[str(lk["id"])] = true
				progress = true
		if not progress:
			return seen.size() == total
	return false


static func _beside(seen: Dictionary, x: int, z: int, reach: int) -> bool:
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if seen.has(_key(x + dx, z + dz)):
				return true
	return false


static func container_open(d: GameDynasty, space_id: String, id: String) -> bool:
	return is_marked(d, "o", place_of(space_id), id)


static func trap_sprung(d: GameDynasty, space_id: String, id: String) -> bool:
	return is_marked(d, "t", place_of(space_id), id)


## The Use action beside a container or feature: {ok, text, dirty: [Vector2i], lines}. An opened container is marked; the loot
## is GameDungeonLoot.roll (keyed on the seed, never the dynasty's dice) and goes into the pack, purse and stores.
static func use_thing(d: GameDynasty, space_id: String, found: Dictionary) -> Dictionary:
	var place := place_of(space_id)
	var t: Dictionary = found["thing"]
	var cell := Vector2i(int(t["x"]), int(t["z"]))
	if str(found["type"]) == "lock":
		return use_lock(d, space_id, t)
	if str(found["type"]) == "container":
		var kname := str(data()["kinds"][str(t["kind"])]["name"])
		if is_marked(d, "o", place, str(t["id"])):
			return {"ok": false, "text": text("empty", {"kind": kname}), "dirty": [], "lines": []}
		var got := GameDungeonLoot.roll(d, place, str(t["id"]), str(t["tier"]), str(t["kind"]))
		mark(d, "o", place, str(t["id"]))
		var lines: Array = [text("opened", {"h": d.heir.name, "kind": kname})]
		var given := GameDungeonLoot.give(d, got)
		lines.append_array(given)
		if t.has("key") and not has_key(d, space_id, str(t["key"])) and not _key_spent(d, space_id, str(t["key"])):
			d.dungeon_marks[mark_key("y", place, str(t["key"]))] = float(d.world.year)
			given.append(text("found_key", {"h": d.heir.name, "key": key_name(space_id, str(t["key"])).to_lower()}))
			lines.append(str(given[-1]))
		if given.is_empty():
			lines.append(text("found_nothing"))
		return {"ok": true, "text": "  ".join(lines), "dirty": [cell], "lines": lines}
	# a feature
	var tn := str(t["text"]).format({"h": d.heir.name})
	if str(t["effect"]) == "heal":
		if is_marked(d, "f", place, str(t["id"])):
			return {"ok": false, "text": str(t["spent"]) if str(t["spent"]) != "" else text("spent"), "dirty": [], "lines": []}
		var amount := mini(maxi(1, int(round(float(d.heir.max_hp()) * float(t["pct"])))), d.heir.max_hp() - d.heir.hp)
		d.heir.hp += amount
		mark(d, "f", place, str(t["id"]))
		return {"ok": true, "text": "%s  %s" % [tn, text("healed", {"h": d.heir.name, "n": amount})], "dirty": [cell], "lines": [tn]}
	return {"ok": true, "text": tn, "dirty": [], "lines": [tn]}


## The heir steps on a cell: a hidden trap there that has not been sprung goes off (keyed dice: it may be seen and avoided by the
## agile) and hurts for a share of their health, never killing. {hit, text, damage, cell}.
static func step_on(d: GameDynasty, space_id: String, x: int, z: int) -> Dictionary:
	var none := {"hit": false, "text": "", "damage": 0}
	var place := place_of(space_id)
	if place == "" or d.heir == null:
		return none
	for t in layout(space_id)["traps"]:
		if int(t["x"]) != x or int(t["z"]) != z or is_marked(d, "t", place, str(t["id"])):
			continue
		mark(d, "t", place, str(t["id"]))
		var def: Dictionary = data()["traps"][str(t["kind"])]
		var r := RandomNumberGenerator.new()
		r.seed = _hash([d.seed_value, "dungeon_trap", place, str(t["id"])])
		var spot := clampf(d.heir.stat("agi") * 0.004, 0.0, 0.5)
		if r.randf() < spot:
			return {"hit": false, "text": text("spotted", {"h": d.heir.name, "trap": str(def["name"])}), "damage": 0, "cell": Vector2i(x, z)}
		var dmg := mini(maxi(1, int(round(float(d.heir.max_hp()) * float(def["hp_pct"])))), maxi(0, d.heir.hp - 1))
		d.heir.hp -= dmg
		return {"hit": true, "text": str(def["text"]).format({"h": d.heir.name, "n": dmg}), "damage": dmg, "cell": Vector2i(x, z)}
	return none


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "roles", "kinds", "traps", "dungeons", "text"]:
		if not dat.has(k):
			bad.append("dungeons.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	GameData.load_all()
	for k in ["refill_years", "foe_years", "min_foe_distance", "reach"]:
		if float(dat["settings"].get(k, 0)) <= 0.0:
			bad.append("dungeons.json: settings.%s must be above 0" % k)
	for k in ["opened", "empty", "found_gold", "found_materials", "found_nothing", "found_unique", "spotted", "spent", "boss_gone", "boss_stirs", "nothing_to_use", "healed", "found_key", "locked", "unlocked"]:
		if str(dat["text"].get(k, "")) == "":
			bad.append("dungeons.json: the text '%s' is missing" % k)
	for t in dat["traps"]:
		var def: Dictionary = dat["traps"][t]
		if float(def.get("hp_pct", 0)) <= 0.0 or float(def["hp_pct"]) > 0.5 or str(def.get("name", "")) == "" or not str(def.get("text", "")).contains("{n}"):
			bad.append("dungeons.json: trap '%s' needs a name, text with {n} and an hp_pct above 0 and at most 0.5" % t)
	for place in dungeon_ids():
		if not dat["dungeons"].has(place):
			bad.append("dungeons.json: the dungeon '%s' has no contents" % place)
	for place in dat["dungeons"]:
		var space: String = "world/" + str(place)
		if GameSpaces.kind(space) != "interior":
			bad.append("dungeons.json: '%s' is not a dungeon" % place)
			continue
		var dg: Dictionary = dat["dungeons"][place]
		var roles := {}
		for rm in GameSpaces.rooms(space):
			var role := str(rm.get("role", ""))
			if not dat["roles"].has(role):
				bad.append("dungeons.json: room '%s' of %s has the unknown role '%s'" % [rm["id"], place, role])
			roles[role] = true
		var lair := str(GameWorld.place(place).get("lair", ""))
		if lair != "" and not roles.has("boss_lair"):
			bad.append("dungeons.json: %s has a lair (%s) but no boss_lair room" % [place, lair])
		if lair == "" and roles.has("boss_lair"):
			bad.append("dungeons.json: %s has a boss_lair room but world.json gives it no lair" % place)
		var key_ids := {}
		for k in dg.get("keys", []):
			if str(k.get("id", "")) == "" or str(k.get("name", "")) == "" or not room_ids(space).has(str(k.get("room", ""))) or not dat["kinds"].has(str(k.get("kind", ""))) or key_ids.has(str(k["id"])):
				bad.append("dungeons.json: %s has a bad key (an id, a name, a room of the dungeon, a container kind)" % place)
			key_ids[str(k.get("id", ""))] = true
		var lock_ids := {}
		for lk in dg.get("locks", []):
			var dd := GameDungeons._door_between(space, str(lk.get("door", ["", ""])[0]), str(lk.get("door", ["", ""])[1]))
			if str(lk.get("id", "")) == "" or lock_ids.has(str(lk["id"])) or str(lk.get("name", "")) == "" or not key_ids.has(str(lk.get("key", ""))) or dd == Vector2i(-9999, -9999):
				bad.append("dungeons.json: %s has a bad lock (an id, a name, a door between two rooms, a key of the dungeon)" % place)
			lock_ids[str(lk.get("id", ""))] = true
		for k in key_ids:
			var used := false
			for lk in dg.get("locks", []):
				used = used or str(lk.get("key", "")) == str(k)
			if not used:
				bad.append("dungeons.json: %s has the key '%s', which opens no door" % [place, k])
		if bad.is_empty() and not solvable(space):
			bad.append("dungeons.json: %s cannot be walked through with its keys (a key behind its own door, or a key with no spot)" % place)
		for p in dg.get("fallback", []):
			if GameBehaviour._def(str(p["id"])).is_empty():
				bad.append("dungeons.json: %s falls back on '%s', which is no creature" % [place, p["id"]])
		for role in dg["roles"]:
			if not roles.has(role):
				bad.append("dungeons.json: %s has contents for the role '%s', which no room of it has" % [place, role])
			var table: Dictionary = dg["roles"][role]
			var foes: Dictionary = table.get("foes", {})
			for p in foes.get("pool", []):
				var c := GameBehaviour._def(str(p["id"]))
				if c.is_empty() or bool(c.get("boss", false)) or bool(c.get("farm", false)) or float(p["weight"]) <= 0.0:
					bad.append("dungeons.json: %s %s has a bad foe '%s' (a wild creature with a weight)" % [place, role, p["id"]])
			if not foes.is_empty() and (int(foes["count"][0]) < 0 or int(foes["count"][1]) < int(foes["count"][0])):
				bad.append("dungeons.json: %s %s has a bad foe count" % [place, role])
			for c in table.get("containers", []):
				if not dat["kinds"].has(str(c["kind"])) or not GameDungeonLoot.data()["tiers"].has(str(c["tier"])):
					bad.append("dungeons.json: %s %s has a container of an unknown kind or tier" % [place, role])
			for t in table.get("traps", []):
				if not dat["traps"].has(str(t["kind"])):
					bad.append("dungeons.json: %s %s has the unknown trap '%s'" % [place, role, t["kind"]])
			for f in table.get("features", []):
				if str(f["kind"]) not in ["shrine", "lore"] or str(f.get("text", "")) == "":
					bad.append("dungeons.json: %s %s has a bad feature" % [place, role])
				elif str(f["kind"]) == "shrine" and (str(f.get("effect", "")) != "heal" or float(f.get("pct", 0)) <= 0.0 or float(f["pct"]) > 1.0):
					bad.append("dungeons.json: %s %s has a shrine that does not heal by a share up to 1" % [place, role])
				if not GameDungeonArt.has_glyph(place, str(f["prop"])):
					bad.append("dungeons.json: %s %s has a feature on the prop '%s', which its theme has no glyph for" % [place, role, f["prop"]])
	return bad
