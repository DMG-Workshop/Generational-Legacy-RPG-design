## Day, night and weather (roadmap item 51). The world clock (GameClock) already turns real seconds into years, seasons
## and a weather rolled each span; this adds the day on top of it. `GameDynasty.world_seconds` is the seconds the clock
## has run, a day is `day_seconds` of them (data/world/daycycle.json), and from the seconds everything follows: the phase
## of the day, the sun's light, whether it is night (the flag GameSpawn and GameBehaviour take), the clock face, and the
## `look` of the world (light and tint, fog, rain or snow) with the weather the world already has. Weather also changes how
## far creatures see (`sight_mult`), so fog and storms hide the hunter and the hunted alike; `view` and `spawn_context` give
## the behaviour and spawn systems the open world's current night, weather and season. Pure functions of the dynasty:
## nothing is random, nothing is saved but the seconds, and the autopilot (which never feeds the clock) is unaffected. The
## text game's hunts do not use any of it yet.
class_name GameDay
extends RefCounted

const PATH := "res://data/world/daycycle.json"
const PHASES := ["night", "dawn", "day", "dusk"]

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


# ---------------------------------------------------------------- the day

## The seconds the world clock has run.
static func seconds(d: GameDynasty) -> float:
	return maxf(0.0, d.world_seconds)


## How far through the day it is, 0 to 1: 0 is midnight, 0.5 noon.
static func phase(d: GameDynasty) -> float:
	return fposmod(float(setting("start_phase")) + seconds(d) / float(setting("day_seconds")), 1.0)


## Which day it is, from 1.
static func day_number(d: GameDynasty) -> int:
	return int(floor(float(setting("start_phase")) + seconds(d) / float(setting("day_seconds")))) + 1


## The sun's height at a phase, -1 (midnight) to 1 (noon).
static func sun_height(p: float) -> float:
	return -cos(TAU * p)


## The sun's light at a phase, 0 (dark) to 1 (full): from the horizon, ramping across the twilight either side of it.
static func sun_light(p: float) -> float:
	var tw := float(setting("twilight"))
	return clampf((sun_height(p) + tw) / (2.0 * tw), 0.0, 1.0)


## "night", "dawn", "day" or "dusk".
static func phase_name(d: GameDynasty) -> String:
	var p := phase(d)
	var l := sun_light(p)
	if l <= 0.0:
		return "night"
	if l >= 1.0:
		return "day"
	return "dawn" if p < 0.5 else "dusk"


## Whether it is night: the sun's light is under `night_below`. (Weather does not make a night.)
static func is_night(d: GameDynasty) -> bool:
	return sun_light(phase(d)) < float(setting("night_below"))


## The hour of the day, 0 to 24.
static func hour(d: GameDynasty) -> float:
	return phase(d) * 24.0


static func time_text(d: GameDynasty) -> String:
	var minutes := int(floor(phase(d) * 24.0 * 60.0))
	return text("time", {"day": day_number(d), "hh": "%02d" % (minutes / 60), "mm": "%02d" % (minutes % 60), "phase": text(phase_name(d))})


# ---------------------------------------------------------------- weather and the look of the world

## The weather the world has (the one the clock rolls each span).
static func weather_id(d: GameDynasty) -> String:
	return str(d.world.weather_id)


static func weather_look(id: String) -> Dictionary:
	return data()["weather_look"].get(id, data()["weather_look"]["clear"])


## How far creatures see in this weather, as a share of their sight (1 in clear weather).
static func sight_mult(d: GameDynasty) -> float:
	return float(weather_look(weather_id(d))["sight"])


## What the open world looks like now: {phase, hour, sun, light, tint [r, g, b], fog, precip, weather, season, night}.
## `sun` is the sun alone, `light` what gets through the weather (never more than the sun), `tint` the colour of the light.
static func look(d: GameDynasty) -> Dictionary:
	var p := phase(d)
	var sun := sun_light(p)
	var w := weather_look(weather_id(d))
	var t: Dictionary = data()["tints"]
	var base := _mix(t["night"], t["day"], sun)
	var warm := 4.0 * sun * (1.0 - sun) * 0.5   # the horizon's glow: most at mid-twilight
	var tint := _mix(base, t["warm"], warm)
	return {"phase": phase_name(d), "hour": hour(d), "sun": sun, "light": sun * float(w["light"]), "tint": tint,
		"fog": float(w["fog"]), "precip": str(w["precip"]), "weather": weather_id(d), "season": str(d.world.season()["id"]),
		"night": is_night(d)}


static func _mix(a: Array, b: Array, f: float) -> Array:
	return [lerpf(float(a[0]), float(b[0]), f), lerpf(float(a[1]), float(b[1]), f), lerpf(float(a[2]), float(b[2]), f)]


# ---------------------------------------------------------------- what the open world's systems are told

## A view for GameBehaviour.step_all: the targets, the current night, and the weather's sight.
static func view(d: GameDynasty, targets: Array) -> Dictionary:
	var v := GameBehaviour.world_view(d, targets, is_night(d))
	v["sight_mult"] = sight_mult(d)
	return v


## The spawn context of a tile or cell for GameSpawn: its ground, with the season, the weather and the night now.
static func spawn_context(d: GameDynasty, x: int, y: int, z: int) -> Dictionary:
	return GameSpawn.context_at(d, x, y, z, is_night(d))


# ---------------------------------------------------------------- saving

## The saved seconds, checked: a finite number of 0 or more, else 0.
static func load_seconds(v: Variant) -> float:
	if typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)) and float(v) > 0.0:
		return minf(float(v), 1.0e9)
	return 0.0


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = data()
	for k in ["settings", "tints", "weather_look", "text"]:
		if not dat.has(k):
			bad.append("daycycle.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var s: Dictionary = dat["settings"]
	for k in ["day_seconds", "start_phase", "twilight", "night_below"]:
		if not s.has(k):
			bad.append("daycycle.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if float(s["day_seconds"]) < 10.0:
		bad.append("daycycle.json: a day should last at least 10 seconds")
	if float(s["start_phase"]) < 0.0 or float(s["start_phase"]) >= 1.0:
		bad.append("daycycle.json: start_phase must be 0 up to (not including) 1")
	if float(s["twilight"]) <= 0.0 or float(s["twilight"]) >= 1.0:
		bad.append("daycycle.json: twilight must be above 0 and under 1, or the day would have no dawn or no night")
	if float(s["night_below"]) <= 0.0 or float(s["night_below"]) >= 1.0:
		bad.append("daycycle.json: night_below must be above 0 and under 1")
	for name in ["night", "day", "warm"]:
		var c: Variant = dat["tints"].get(name, null)
		if typeof(c) != TYPE_ARRAY or (c as Array).size() != 3:
			bad.append("daycycle.json: tint '%s' must be three numbers" % name)
			continue
		for v in c:
			if typeof(v) not in [TYPE_INT, TYPE_FLOAT] or float(v) < 0.0 or float(v) > 1.0:
				bad.append("daycycle.json: tint '%s' has a value outside 0 to 1" % name)
	GameData.load_all()
	var ids := {}
	for w in GameData.world["weather"]:
		ids[str(w["id"])] = true
		if not dat["weather_look"].has(str(w["id"])):
			bad.append("daycycle.json: weather '%s' has no look" % w["id"])
	for id in dat["weather_look"]:
		var l: Dictionary = dat["weather_look"][id]
		if not ids.has(id):
			bad.append("daycycle.json: look for '%s', which is not a weather" % id)
		for k in ["light", "fog", "precip", "sight"]:
			if not l.has(k):
				bad.append("daycycle.json: look '%s' has no %s" % [id, k])
		if not bad.is_empty():
			return bad
		if float(l["light"]) <= 0.0 or float(l["light"]) > 1.0 or float(l["sight"]) <= 0.0 or float(l["sight"]) > 1.0:
			bad.append("daycycle.json: look '%s' light and sight must be above 0 and at most 1" % id)
		if float(l["fog"]) < 0.0 or float(l["fog"]) > 1.0:
			bad.append("daycycle.json: look '%s' fog must be 0 to 1" % id)
		if not str(l["precip"]) in ["none", "rain", "snow"]:
			bad.append("daycycle.json: look '%s' precip must be none, rain or snow" % id)
	for k in ["night", "dawn", "day", "dusk", "time"]:
		if not dat["text"].has(k):
			bad.append("daycycle.json: text.%s is missing" % k)
	return bad
