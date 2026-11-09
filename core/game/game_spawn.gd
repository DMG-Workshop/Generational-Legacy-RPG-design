## Spawn tables (roadmap item 47): which creatures appear where and when, as data (data/creatures/spawn.json). Where is a
## surface biome (the world generator's), a depth underground (the mining ground's zones) or an authored place (a dungeon
## mouth); when is the era within the Age, the season, the weather and the night. Two things live here:
##  - `hunt_pool`: the pool a text-game hunt draws from, exactly as it always was (creatures of the era whose biomes meet
##    the place's, with the same fallbacks and the same order), moved out of GameDynasty.start_hunt so the hunt and the world
##    ask one place. The hunt still picks uniformly with the dynasty's dice, so every seeded fight is unchanged.
##  - `table`, `pick`, `spawn_at`: the weighted table for a context and a keyed roll for a tile, for the world. Pure
##    functions of the seed and the tile: no dice of the dynasty's, nothing saved, the autopilot never asks.
class_name GameSpawn
extends RefCounted

const PATH := "res://data/creatures/spawn.json"

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


## Every creature that can be met in a hunt or a spawn: not a legend, not a farm animal.
static func wild() -> Array:
	return GameData.creatures.filter(func(c): return not c.get("boss", false) and not c.get("farm", false))


# ---------------------------------------------------------------- the hunt's pool

## The pool a hunt at a place draws from: creatures of the era whose biomes meet the place's. If nothing roams the era at all,
## anything wild will do; if nothing in the era roams these biomes, anything in the era will. The order is the creature
## list's, because the hunt picks by index.
static func hunt_pool(era: int, place_biomes: Array) -> Array:
	var in_era := wild().filter(func(c): return c["min_gen"] <= era and era <= c["max_gen"])
	if in_era.is_empty():
		in_era = wild()
	var pool := in_era.filter(func(c): return (c.get("biomes", []) as Array).any(func(b): return b in place_biomes))
	if pool.is_empty():
		pool = in_era
	return pool


# ---------------------------------------------------------------- the weighted table

## A context for a table: {surface (a surface biome, for the surface), depth (-1 on the surface, else cells under it), place
## (an authored place's id, or ""), era, season, weather, night}. Missing keys are "nothing in particular".
static func context(surface: String, depth: int, era: int, season: String = "", weather: String = "", night: bool = false, place: String = "") -> Dictionary:
	return {"surface": surface, "depth": depth, "place": place, "era": era, "season": season, "weather": weather, "night": night}


static func _lives_here(c: Dictionary, spec: Dictionary, ctx: Dictionary) -> bool:
	if str(ctx.get("place", "")) != "":
		return true   # the pool is the place's own; hunt_pool has already chosen
	var depth := int(ctx.get("depth", -1))
	if depth < 0:
		return str(ctx.get("surface", "")) in spec.get("surface", [])
	var band: Array = spec.get("depth", [])
	return band.size() == 2 and depth >= int(band[0]) and depth <= int(band[1])


## What a creature's weight is in a context: its own weight times what it likes of the season, weather and night.
static func weight_of(id: String, ctx: Dictionary) -> float:
	var spec: Dictionary = data()["creatures"].get(id, {})
	if spec.is_empty():
		return 0.0
	var w := float(spec.get("weight", 1.0))
	w *= float(spec.get("seasons", {}).get(str(ctx.get("season", "")), 1.0))
	w *= float(spec.get("weather", {}).get(str(ctx.get("weather", "")), 1.0))
	if bool(ctx.get("night", false)):
		w *= float(spec.get("night", 1.0))
	return w


## The table for a context: [{id, weight}] sorted by id, empty when nothing lives there.
static func table(ctx: Dictionary) -> Array:
	var era := int(ctx.get("era", 1))
	var candidates: Array
	var place_id := str(ctx.get("place", ""))
	if place_id != "":
		candidates = hunt_pool(era, GameWorld.place(place_id).get("biomes", []))
	else:
		candidates = wild().filter(func(c): return c["min_gen"] <= era and era <= c["max_gen"])
	var out: Array = []
	for c in candidates:
		var spec: Dictionary = data()["creatures"].get(str(c["id"]), {})
		if spec.is_empty() or not _lives_here(c, spec, ctx):
			continue
		var w := weight_of(str(c["id"]), ctx)
		if w > 0.0:
			out.append({"id": str(c["id"]), "weight": w})
	out.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	return out


## One creature id from a table, by weight, from the caller's dice; "" for an empty table.
static func pick(r: RandomNumberGenerator, rows: Array) -> String:
	var total := 0.0
	for row in rows:
		total += float(row["weight"])
	if total <= 0.0:
		return ""
	var roll := r.randf() * total
	for row in rows:
		roll -= float(row["weight"])
		if roll < 0.0:
			return str(row["id"])
	return str(rows.back()["id"])


# ---------------------------------------------------------------- the world's tiles

## The context at a tile of the generated world, or {} where nothing spawns (open water, a town's cleared ground, the soil
## above the stone). y is -1 on the surface and otherwise the depth under it. A dungeon's mouth is its place's own.
static func context_at(d: GameDynasty, x: int, y: int, z: int, night: bool = false) -> Dictionary:
	var season := str(d.world.season()["id"])
	var weather := str(d.world.weather_id)
	var era := d.era_gen()
	if y >= 0:
		var zone := str(GameMine.zone_at(y)["id"])
		if zone == "surface":
			return {}
		var c := context("", y, era, season, weather, false)
		c["zone"] = zone
		return c
	var t := GameWorldGen.tile(d, x, z)
	if t["water"]:
		return {}
	var near := GameWorldGen.nearest_anchor(float(x), float(z))
	if GameWorldGen.in_anchor_ground(x, z):
		var a: Dictionary = near["anchor"]
		if a["type"] == "town":
			return {}
		var c2 := context("", -1, era, season, weather, night, str(a["id"]))
		c2["zone"] = "place"
		return c2
	var c3 := context(str(t["biome"]), -1, era, season, weather, night)
	c3["zone"] = "surface"
	return c3


## How likely a slot at a tile is to hold a creature: by the surface biome, the underground zone, or a dungeon's mouth;
## more at night on the surface.
static func density(ctx: Dictionary) -> float:
	if ctx.is_empty():
		return 0.0
	var base := 0.0
	match str(ctx.get("zone", "")):
		"place":
			base = float(setting("dungeon_density"))
		"surface":
			base = float(setting("surface_density").get(str(ctx.get("surface", "")), 0.0))
		_:
			base = float(setting("underground_density").get(str(ctx.get("zone", "")), 0.0))
	if bool(ctx.get("night", false)):
		base *= float(setting("night_density_mult"))
	return base


## What is at a tile in a time slot (a counter the caller moves on): a creature id or "". Keyed on the seed, the tile and the
## slot, never the dynasty's dice, so the same world gives the same creature at the same place and time.
static func spawn_at(d: GameDynasty, x: int, y: int, z: int, slot: int, night: bool = false) -> String:
	var ctx := context_at(d, x, y, z, night)
	if ctx.is_empty():
		return ""
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "spawn", x, y, z, slot])
	if r.randf() >= density(ctx):
		return ""
	return pick(r, table(ctx))


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = data()
	for k in ["settings", "creatures"]:
		if not dat.has(k):
			bad.append("spawn.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var s: Dictionary = dat["settings"]
	for k in ["underground_biomes", "dungeon_density", "night_density_mult", "surface_density", "underground_density"]:
		if not s.has(k):
			bad.append("spawn.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	GameData.load_all()
	var surface_ids: Array = GameWorldGen.data()["biomes"].keys()
	var zone_ids := ["underground", "deep"]
	for b in surface_ids:
		if not s["surface_density"].has(b) or float(s["surface_density"][b]) < 0.0 or float(s["surface_density"][b]) > 1.0:
			bad.append("spawn.json: surface_density needs a number from 0 to 1 for '%s'" % b)
	for z in zone_ids:
		if not s["underground_density"].has(z) or float(s["underground_density"][z]) < 0.0 or float(s["underground_density"][z]) > 1.0:
			bad.append("spawn.json: underground_density needs a number from 0 to 1 for '%s'" % z)
	if float(s["dungeon_density"]) < 0.0 or float(s["dungeon_density"]) > 1.0 or float(s["night_density_mult"]) <= 0.0:
		bad.append("spawn.json: dungeon_density must be from 0 to 1 and night_density_mult above 0")
	var seasons: Array = GameData.world["seasons"].map(func(x): return str(x["id"]))
	var weathers: Array = GameData.world["weather"].map(func(x): return str(x["id"]))
	var max_depth := int(GameMine.setting("max_depth"))
	var named := {}
	for c in wild():
		named[str(c["id"])] = c
		if not dat["creatures"].has(str(c["id"])):
			bad.append("spawn.json: the creature '%s' has no entry" % c["id"])
	for id in dat["creatures"]:
		var spec: Dictionary = dat["creatures"][id]
		if not named.has(id):
			bad.append("spawn.json: '%s' is not a wild creature" % id)
			continue
		var c: Dictionary = named[id]
		if float(spec.get("weight", 0.0)) <= 0.0:
			bad.append("spawn.json: '%s' needs a weight above 0" % id)
		# the surface biomes it roams must be surfaces of its own place biomes
		var allowed := {}
		for pb in c.get("biomes", []):
			var surf := str(GameWorldGen.data()["surface_of"].get(str(pb), ""))
			if surf != "":
				allowed[surf] = true
		for sb in spec.get("surface", []):
			if sb not in surface_ids:
				bad.append("spawn.json: '%s' roams the unknown surface biome '%s'" % [id, sb])
			elif not allowed.has(sb):
				bad.append("spawn.json: '%s' roams %s, which none of its biomes in creatures.json has as a surface" % [id, sb])
		if spec.has("depth"):
			var band: Array = spec["depth"]
			if band.size() != 2 or int(band[0]) < int(GameMine.data()["zones"][1]["from"]) or int(band[1]) < int(band[0]) or int(band[1]) > max_depth:
				bad.append("spawn.json: '%s' has a depth band outside the underground (%s)" % [id, str(band)])
			var has_ug := false
			for pb in c.get("biomes", []):
				if pb in s["underground_biomes"]:
					has_ug = true
			if not has_ug:
				bad.append("spawn.json: '%s' lives underground but none of its biomes is an underground one" % id)
		for k in spec.get("seasons", {}):
			if k not in seasons or float(spec["seasons"][k]) <= 0.0:
				bad.append("spawn.json: '%s' has a bad season entry '%s'" % [id, k])
		for k in spec.get("weather", {}):
			if k not in weathers or float(spec["weather"][k]) <= 0.0:
				bad.append("spawn.json: '%s' has a bad weather entry '%s'" % [id, k])
		if spec.has("night") and float(spec["night"]) <= 0.0:
			bad.append("spawn.json: '%s' needs a night multiplier above 0" % id)
		if spec.get("surface", []).is_empty() and not spec.has("depth"):
			bad.append("spawn.json: '%s' lives nowhere (no surface biome and no depth band)" % id)
	return bad
