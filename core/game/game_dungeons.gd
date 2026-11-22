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
## foes: [{key, room, role, x, z}], boss: {key, room, x, z} or {}, features: [{id, room, x, z, prop, kind, name, ...}],
## solid: {"x,z": true} (cells the heir cannot stand on) and reserved: {"x,z": true}}.
static func layout(space_id: String) -> Dictionary:
	var place := place_of(space_id)
	if place == "":
		return {}
	if _layouts.has(place):
		return _layouts[place]
	var cells := GameInterior.cells(space_id)
	var out := {"containers": [], "traps": [], "foes": [], "boss": {}, "features": [], "solid": {}, "reserved": {}}
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
	_layouts[place] = out
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
## of the art as `prop` cells that cannot be stood on.
static func walk_cells(space_id: String) -> Dictionary:
	var cells := GameInterior.cells(space_id)
	if not is_dungeon(space_id):
		return cells
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
	return float(setting("foe_years")) if kind == "k" else float(setting("refill_years"))


## Whether a thing was marked (o opened, t sprung, f used, k killed) and has not yet come back.
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
		if (parts[0] == "u" and parts.size() == 2) or (parts[0] in ["o", "t", "f", "k"] and parts.size() == 3):
			out[str(k)] = float(v[k])
	return out


# ---------------------------------------------------------------- acting

## What the Use action finds beside a cell: the nearest container or feature within `reach` (Chebyshev), {} for none.
static func thing_near(space_id: String, x: int, z: int) -> Dictionary:
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
	return best


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
	if str(found["type"]) == "container":
		var kname := str(data()["kinds"][str(t["kind"])]["name"])
		if is_marked(d, "o", place, str(t["id"])):
			return {"ok": false, "text": text("empty", {"kind": kname}), "dirty": [], "lines": []}
		var got := GameDungeonLoot.roll(d, place, str(t["id"]), str(t["tier"]), str(t["kind"]))
		mark(d, "o", place, str(t["id"]))
		var lines: Array = [text("opened", {"h": d.heir.name, "kind": kname})]
		var given := GameDungeonLoot.give(d, got)
		lines.append_array(given)
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
	for k in ["opened", "empty", "found_gold", "found_materials", "found_nothing", "found_unique", "spotted", "spent", "boss_gone", "boss_stirs", "nothing_to_use", "healed"]:
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
