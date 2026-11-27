## What the open world has only by night or only by day (data/world/night_life.json). By night: some creatures are met only after
## dark (`adjust_weight`, which GameSpawn.weight_of applies to its surface table: those listed in `day_only_off` have no weight by
## day, and `night_adds` lets existing creatures roam a surface they do not by day), and glowcaps grow on forest and swamp ground
## (`glow_node`: a gathering node for GameCompanions.scan, so the Forage action and gathering companions take it, only while it
## is night). By day: each walled town has a market stall outside its first gate (`stalls`), a trader who is there from `stall_open`
## to `stall_close` and not in the weathers of `closed_weather`, dealing as the wilds' wandering merchant does (GameWildsTrade).
## Every choice is a hash of the seed and a tile, never the dynasty's dice; nothing is saved but the shop marks a purchase already
## uses; the text game's hunts (GameSpawn.hunt_pool), the autopilot and the golden digests never ask for any of it.
class_name GameNightLife
extends RefCounted

const PATH := "res://data/world/night_life.json"
const CACHE_MAX := 60000

static var _cache: Dictionary = {}
static var _glow: Dictionary = {}       # Vector2i -> the glowcap node a tile would grow at night ({} for none): time-free, so worked out once
static var _glow_seed := 0
static var _stalls: Dictionary = {}     # seed -> [stall]


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


static func _u(parts: Array) -> float:
	return float(absi(hash(parts)) % 1000003) / 1000003.0


# ---------------------------------------------------------------- creatures

## The creatures a context lets in after dark that the surface table would not have: {id: weight}; empty by day, off the surface
## and for a context that says nothing of the night.
static func adds(ctx: Dictionary) -> Dictionary:
	if not bool(ctx.get("night", false)) or str(ctx.get("zone", "")) != "surface":
		return {}
	return data()["night_adds"].get(str(ctx.get("surface", "")), {})


## A creature's spawn weight `w` in a context, with the night's rules: those that roam only by night are gone by day, and a
## night-add has its own weight where its table has none. Anything else (and any context off the surface) comes back as it was.
static func adjust_weight(id: String, ctx: Dictionary, w: float) -> float:
	if str(ctx.get("zone", "")) != "surface":
		return w
	if not bool(ctx.get("night", false)):
		return w * float(setting("day_mult")) if id in data()["day_only_off"] else w
	var add: Variant = adds(ctx).get(id)
	if add == null:
		return w
	var spec: Dictionary = GameSpawn.data()["creatures"].get(id, {})
	if str(ctx.get("surface", "")) in spec.get("surface", []) or GameSpawn.area_spec(ctx).get("add", {}).has(id):
		return w   # it roams here anyway
	return float(spec.get("weight", 1.0)) * float(add)


# ---------------------------------------------------------------- glowcaps

## The glowcap a tile would grow in the dark, {kind, name, material, amount} or {}: a keyed hash of the seed and the tile on ground with no
## node of its own (not water, not a town's or dungeon's ground, not a wall's). It does not depend on the time: see `glow_node`.
static func glow_decision(d: GameDynasty, x: int, z: int) -> Dictionary:
	if _glow_seed != d.seed_value or _glow.size() > CACHE_MAX:
		_glow.clear()
		_glow_seed = d.seed_value
	var key := Vector2i(x, z)
	if _glow.has(key):
		return _glow[key]
	var out := {}
	if GameWorldGen.in_bounds(x, z):
		var g: Dictionary = data()["glow"]
		var t := GameWorldGen.tile(d, x, z)
		var dens: float = float(g["density"].get(str(t["biome"]), 0.0))
		if dens > 0.0 and not t["water"] and (t["node"] as Dictionary).is_empty() and not GameWorldGen.in_anchor_ground(x, z) and not GameWalls.cleared(x, z) \
				and _u([d.seed_value, "glowcap", x, z]) < dens:
			var span := int(g["max"]) - int(g["min"]) + 1
			out = {"kind": str(g["kind"]), "name": str(g["name"]), "material": str(g["material"]), "amount": int(g["min"]) + absi(hash([d.seed_value, "glowcap_n", x, z])) % span}
	_glow[key] = out
	return out


## The glowcap on a tile now: only while it is night.
static func glow_node(d: GameDynasty, x: int, z: int) -> Dictionary:
	if not GameDay.is_night(d):
		return {}
	return glow_decision(d, x, z)


## The glowcaps to be seen in a rect of tiles that are not gathered: [{x, z}]. None by day.
static func glow_in(d: GameDynasty, rect: Rect2i) -> Array:
	var out: Array = []
	if not GameDay.is_night(d):
		return out
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if not glow_decision(d, x, z).is_empty() and not GameCompanions.depleted(d, x, z):
				out.append({"x": x, "z": z})
	return out


# ---------------------------------------------------------------- the market stalls

## Whether the stalls are open now: between their hours, not at night and not in the weathers that close them.
static func stalls_open(d: GameDynasty) -> bool:
	var h := GameDay.hour(d)
	return h >= float(setting("stall_open")) and h < float(setting("stall_close")) and not GameDay.is_night(d) and GameDay.weather_id(d) not in setting("closed_weather")


static func _stall_tile_ok(d: GameDynasty, x: int, z: int) -> bool:
	if not GameWorldGen.in_bounds(x, z) or GameWalls.blocks(x, z) or not GameTown.at(x, z).is_empty():
		return false
	var t := GameWorldGen.tile(d, x, z)
	return not t["water"] and (t["node"] as Dictionary).is_empty()


## The market stalls of the world, one outside the first gate of each walled town: [{id, kind, name, place, area, biome, x, z}]. The id and
## the rest are what GameWildsTrade asks of a landmark, so the trader's wares and dealing are the merchant's. Open or not.
static func stalls(d: GameDynasty) -> Array:
	if _stalls.has(d.seed_value):
		return _stalls[d.seed_value]
	var out: Array = []
	for place in GameWalls.walled():
		var gates := GameWalls.gates(str(place))
		if gates.is_empty():
			continue
		var g: Dictionary = gates[0]
		var outer: Vector2i = g["outer"]
		var dir: Vector2i = g["dir"]
		var tang := Vector2i(1, 0) if dir.x == 0 else Vector2i(0, 1)
		var spot := Vector2i(-1, -1)
		for o in setting("stall_out"):
			for s in setting("stall_side"):
				for sgn in [1, -1]:
					var t: Vector2i = outer + dir * int(o) + tang * (int(s) * int(sgn))
					if spot.x < 0 and _stall_tile_ok(d, t.x, t.y):
						spot = t
		if spot.x < 0:
			continue
		var tile := GameWorldGen.tile(d, spot.x, spot.y)
		out.append({"id": "stall:%s" % place, "kind": str(setting("stall_kind")), "name": text("stall_name"), "place": str(place),
			"area": GameWilds.area_of(spot.x, spot.y, str(tile["biome"])), "biome": str(tile["biome"]), "x": spot.x, "z": spot.y})
	_stalls[d.seed_value] = out
	return out


## The open stalls whose tile is in a rect.
static func stalls_in(d: GameDynasty, rect: Rect2i) -> Array:
	var out: Array = []
	if not stalls_open(d):
		return out
	for s in stalls(d):
		if rect.has_point(Vector2i(int(s["x"]), int(s["z"]))):
			out.append(s)
	return out


## The open stall within reach of a tile (the nearest), or {}.
static func stall_near(d: GameDynasty, x: int, z: int) -> Dictionary:
	if not stalls_open(d):
		return {}
	var best := {}
	var best_d := float(setting("stall_reach")) + 0.001
	for s in stalls(d):
		var dist := Vector2(float(int(s["x"]) - x), float(int(s["z"]) - z)).length()
		if dist < best_d:
			best_d = dist
			best = s
	return best


## Use at a stall: the trader's panel opens (the merchant's: GameWildsTrade). {ok, text, open: "merchant", site, landmark}.
static func stall_use(_d: GameDynasty, stall: Dictionary) -> Dictionary:
	return {"ok": true, "text": text("stall_open"), "open": "merchant", "site": str(stall["id"]), "landmark": stall}


## The hint the place line adds beside an open stall.
static func stall_hint(d: GameDynasty, x: int, z: int) -> String:
	return "" if stall_near(d, x, z).is_empty() else text("stall_hint")


# ---------------------------------------------------------------- what the status says

## The line about the time of day: the night's creatures and glowcaps, or the day's stall when the heir is near one ("" otherwise).
static func note(d: GameDynasty, heir: Vector2i) -> String:
	if GameDay.is_night(d):
		return text("night_note")
	if stalls_open(d):
		for s in stalls(d):
			if Vector2(float(int(s["x"]) - heir.x), float(int(s["z"]) - heir.y)).length() <= float(setting("note_reach")):
				return text("day_note")
	return ""


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "day_only_off", "night_adds", "glow", "text"]:
		if not dat.has(k):
			bad.append("night_life.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var s: Dictionary = dat["settings"]
	for k in ["day_mult", "stall_open", "stall_close", "stall_reach", "stall_kind", "stall_out", "stall_side", "note_reach", "glow_color", "glow_cap", "closed_weather"]:
		if not s.has(k):
			bad.append("night_life.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	GameData.load_all()
	if float(s["day_mult"]) < 0.0 or float(s["day_mult"]) > 1.0:
		bad.append("night_life.json: day_mult must be 0 to 1 (a creature of the night is rarer by day)")
	if float(s["stall_open"]) < 0.0 or float(s["stall_close"]) > 24.0 or float(s["stall_open"]) >= float(s["stall_close"]):
		bad.append("night_life.json: the stall must open before it closes, within the 24 hours")
	if float(s["stall_reach"]) < 1.0 or float(s["note_reach"]) <= 0.0 or float(s["glow_cap"]) <= 0.0:
		bad.append("night_life.json: stall_reach must be at least 1, note_reach and glow_cap above 0")
	if (s["glow_color"] as Array).size() != 3:
		bad.append("night_life.json: glow_color is three numbers")
	if (s["stall_out"] as Array).is_empty() or (s["stall_side"] as Array).is_empty():
		bad.append("night_life.json: stall_out and stall_side need at least one distance")
	var weathers: Array = GameData.world["weather"].map(func(w): return str(w["id"]))
	for w in s["closed_weather"]:
		if str(w) not in weathers:
			bad.append("night_life.json: closed_weather '%s' is not a weather" % w)
	if GameWildsSites._def(str(s["stall_kind"])).is_empty() or not GameWildsSites._def(str(s["stall_kind"])).has("merchant"):
		bad.append("night_life.json: stall_kind '%s' is not a wilds landmark that trades" % s["stall_kind"])
	var wild := {}
	for c in GameSpawn.wild():
		wild[str(c["id"])] = c
	var surfaces: Array = GameWorldGen.data()["biomes"].keys()
	for id in dat["day_only_off"]:
		if not GameSpawn.data()["creatures"].has(str(id)) or not wild.has(str(id)):
			bad.append("night_life.json: day_only_off '%s' is not a wild creature of spawn.json" % id)
		elif not (float(GameSpawn.data()["creatures"][str(id)].get("night", 1.0)) > 1.0):
			bad.append("night_life.json: '%s' roams by night only, so spawn.json should favour the night for it (night above 1)" % id)
	for surf in dat["night_adds"]:
		if str(surf) not in surfaces:
			bad.append("night_life.json: night_adds has the unknown surface '%s'" % surf)
			continue
		for id in dat["night_adds"][surf]:
			var ok := false
			if wild.has(str(id)) and float(dat["night_adds"][surf][id]) > 0.0:
				for pb in wild[str(id)].get("biomes", []):
					if str(GameWorldGen.data()["surface_of"].get(str(pb), "")) == str(surf):
						ok = true
			if not ok:
				bad.append("night_life.json: night_adds puts '%s' on %s, but it is no wild creature with a biome of that surface, or the weight is not above 0" % [id, surf])
	var g: Dictionary = dat["glow"]
	for k in ["kind", "name", "material", "min", "max", "density"]:
		if not g.has(k):
			bad.append("night_life.json: glow.%s is missing" % k)
	if bad.is_empty():
		if not GameMaterials.has(str(g["material"])):
			bad.append("night_life.json: glow gives the unknown material '%s'" % g["material"])
		if int(g["min"]) < 1 or int(g["max"]) < int(g["min"]):
			bad.append("night_life.json: glow needs 1 <= min <= max")
		for b in g["density"]:
			if str(b) not in surfaces or float(g["density"][b]) <= 0.0 or float(g["density"][b]) > 0.2:
				bad.append("night_life.json: glow density for '%s' must be a surface biome and above 0 up to 0.2" % b)
	for k in ["night_note", "day_note", "stall_name", "stall_hint", "stall_open", "trader"]:
		if not dat["text"].has(k):
			bad.append("night_life.json: text.%s is missing" % k)
	return bad
