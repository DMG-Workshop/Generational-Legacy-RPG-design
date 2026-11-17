## How the lie of the land shows (open-world terrain). The heights come from GameWorldGen; this turns them into what a view
## draws: a light step for a land tile (the sun in the north-west: slopes facing it are bright, slopes turned away dark, high
## ground lighter than low), deep or shallow water, and snow on the high peaks. Pure functions of the seed and the tile: no
## dice, nothing saved. Data: data/world/relief.json.
class_name GameRelief
extends RefCounted

const PATH := "res://data/world/relief.json"

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


## The brightness step of a land tile, from -steps (darkest) to steps (brightest); 0 is the colour as it is. Water has none.
static func step_at(d: GameDynasty, x: int, z: int) -> int:
	var seed_value := d.seed_value
	var h := GameWorldGen.height_at(seed_value, x, z)
	var sea := int(GameWorldGen.setting("sea_level"))
	if h < sea:
		return 0
	return step_of(h, GameWorldGen.height_at(seed_value, x - 1, z), GameWorldGen.height_at(seed_value, x + 1, z),
		GameWorldGen.height_at(seed_value, x, z - 1), GameWorldGen.height_at(seed_value, x, z + 1))


## The step for a height and the heights of the tiles west, east, north and south of it.
static func step_of(h: int, west: int, east: int, north: int, south: int) -> int:
	var slope := float((east - west) + (south - north)) * float(setting("slope_k"))
	var span := maxf(1.0, float(setting("alt_span")))
	var up := clampf(float(h - int(GameWorldGen.setting("sea_level"))) / span, 0.0, 1.0)
	var alt := (up - float(setting("alt_mid"))) * float(setting("alt_gain"))
	var n := int(setting("steps"))
	return clampi(roundi(slope + alt), -n, n)


## How much brighter (above 1) or darker (below 1) a step makes a colour.
static func light(step: int) -> float:
	return 1.0 + float(step) * float(setting("step_gain"))


## How far under the sea level a tile's ground lies (0 on dry land).
static func depth(height: int) -> int:
	return maxi(0, int(GameWorldGen.setting("sea_level")) - height)


## What a tile looks like before anything built on it: "deep" or "water" for water, "ford" for the shallows of a river, "snow" for high mountain ground, else its
## biome. `tile` is a GameWorldGen.tile (a tile with no height is taken to be at the sea level).
static func kind(tile: Dictionary) -> String:
	var h := int(tile.get("height", int(GameWorldGen.setting("sea_level"))))
	if str(tile.get("body", "")) == "ford":
		return "ford"   # shallows across a river, walked
	if bool(tile.get("water", false)):
		if str(tile.get("body", "")) == "lake" and int(tile.get("depth", 0)) >= int(setting("lake_deep")):
			return "deep"   # the middle of a lake, whatever the sea level (a lake in the hills is not shallow for lying high)
		return "deep" if depth(h) >= int(setting("deep_depth")) else "water"
	var biome := str(tile.get("biome", "plains"))
	if h >= int(setting("snow_line")) and setting("snow_biomes").has(biome):
		return "snow"
	return biome


static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = data()
	if not dat.has("settings"):
		return ["relief.json: settings is missing"]
	var s: Dictionary = dat["settings"]
	for k in ["steps", "step_gain", "slope_k", "alt_gain", "alt_span", "alt_mid", "deep_depth", "lake_deep", "snow_line", "snow_biomes"]:
		if not s.has(k):
			bad.append("relief.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if int(s["steps"]) < 1 or int(s["steps"]) > 8:
		bad.append("relief.json: steps must be 1 to 8")
	if float(s["step_gain"]) <= 0.0 or float(s["step_gain"]) * float(s["steps"]) >= 1.0:
		bad.append("relief.json: step_gain must be above 0, and steps of it under 1 (or the darkest step is black)")
	if float(s["alt_span"]) <= 0.0 or float(s["alt_mid"]) < 0.0 or float(s["alt_mid"]) > 1.0:
		bad.append("relief.json: alt_span must be above 0 and alt_mid between 0 and 1")
	if int(s["deep_depth"]) < 1 or int(s["lake_deep"]) < 1:
		bad.append("relief.json: deep_depth and lake_deep must be at least 1")
	if int(s["snow_line"]) <= int(GameWorldGen.setting("sea_level")) or int(s["snow_line"]) > int(GameWorldGen.setting("max_height")):
		bad.append("relief.json: snow_line must be above the sea and no higher than the world")
	for b in s["snow_biomes"]:
		if not GameWorldGen.data()["biomes"].has(str(b)):
			bad.append("relief.json: snow_biomes names '%s', which is not a biome" % b)
	return bad
