## What weather does in the open world (data/world/weather_effects.json; the look of the weather and how far creatures see are
## GameDay's). Every effect is a multiplier that is exactly 1.0 in clear weather (and in a weather the data has no entry for):
## the heir's pace on foot (`walk_mult`, used through GameSandbox.step_pace), how fast a gathered herb regrows (`regrow_mult`,
## used by GameCompanions.depleted), the speed of fire creatures in rain (`speed_by`, a table the behaviour view carries) and fliers
## sheltering in a storm (`shelter_fliers`, also on the view), with the weather's sight (GameDay.sight_mult) for creatures and, with
## `view_tiles`, for the heir (`view_radius`, which the sandbox screen draws as a veil of fog and uses to hide creatures beyond).
## `notes` is what the status pane says about the sky now, the night's and the day's included (GameNightLife). Pure functions of the
## dynasty: no dice, nothing saved, and the text game and the autopilot (which never walk the open world or feed the clock) never
## ask. Randomness, where any is wanted, is keyed on the seed, a tile and the day, never the dynasty's dice.
class_name GameWeatherFx
extends RefCounted

const PATH := "res://data/world/weather_effects.json"

static var _cache: Dictionary = {}
static var _speed_tables: Dictionary = {}   # weather id -> {creature id: multiplier} (only the creatures that are not 1)


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> float:
	return float(data()["settings"][key])


## What the data says of a weather ({} for clear weather and any weather it does not list).
static func effects(id: String) -> Dictionary:
	return data()["weather"].get(id, {})


static func _now(d: GameDynasty) -> Dictionary:
	return effects(GameDay.weather_id(d))


# ---------------------------------------------------------------- the multipliers

## The seconds between the heir's steps, as a share of the usual (1 in clear weather; above 1 is slower).
static func walk_mult(d: GameDynasty) -> float:
	return float(_now(d).get("walk", 1.0))


## How much faster a gathered herb node regrows at a tile now (1 in clear weather and for anything but a herb).
static func regrow_mult(d: GameDynasty, x: int, z: int) -> float:
	var m := float(_now(d).get("herb_regrow", 1.0))
	if m == 1.0:
		return 1.0
	var n: Dictionary = GameWorldGen.tile(d, x, z)["node"]
	if n.is_empty():
		n = GameNightLife.glow_decision(d, x, z)   # a glowcap is a herb too
	return m if str(n.get("material", "")) == "herb" else 1.0


## {creature id: speed multiplier} for the weather now: only the creatures whose element it slows (empty in clear weather).
static func speed_by(d: GameDynasty) -> Dictionary:
	var id := GameDay.weather_id(d)
	if _speed_tables.has(id):
		return _speed_tables[id]
	var out := {}
	var slow: Dictionary = effects(id).get("slow", {})
	if not slow.is_empty():
		for c in GameData.creatures:
			var m := float(slow.get(str(c.get("element", "")), 1.0))
			if m != 1.0:
				out[str(c["id"])] = m
	_speed_tables[id] = out
	return out


static func shelter_fliers(d: GameDynasty) -> bool:
	return bool(_now(d).get("shelter_fliers", false))


## How far the heir sees now, in tiles: `view_tiles` times the weather's sight; -1 when nothing is hidden (sight is 1, clear weather).
static func view_radius(d: GameDynasty) -> float:
	var s := GameDay.sight_mult(d)
	return -1.0 if s >= 1.0 else setting("view_tiles") * s


## Whether a point can be seen by the heir at a point (always, in clear weather).
static func seen_by_heir(d: GameDynasty, heir: Vector2, x: float, z: float) -> bool:
	var r := view_radius(d)
	return r < 0.0 or heir.distance_to(Vector2(x, z)) <= r * setting("hide_margin")


# ---------------------------------------------------------------- the behaviour view

## `view` (GameBehaviour.world_view's) with the weather in it: the sight of creatures, the speed table and fliers' shelter. In clear
## weather it adds nothing but keys that are 1, empty and false, so the creatures act exactly as before.
static func apply(d: GameDynasty, view: Dictionary) -> Dictionary:
	view["sight_mult"] = GameDay.sight_mult(d)
	view["speed_by"] = speed_by(d)
	view["shelter_fliers"] = shelter_fliers(d)
	return view


## One step of a creature that flies, in a storm that sends fliers home: it heads for its home and rests there, neither seeing nor
## chasing. Pure (no dice). `a` is not changed; the moved copy comes back.
static func shelter_step(a: Dictionary, p: Dictionary, view: Dictionary) -> Dictionary:
	var next: Dictionary = a.duplicate(true)
	var pos := Vector2(float(a["x"]), float(a["z"]))
	var home := Vector2(float(a["home_x"]), float(a["home_z"]))
	var dist := pos.distance_to(home)
	next["target"] = {}
	next["burst"] = 0
	if dist <= 0.75:
		next["mode"] = "idle"
		return next
	var moved := pos + (home - pos).normalized() * minf(float(p["speed"]), dist)
	next["x"] = moved.x
	next["z"] = moved.y
	next["mode"] = "return"
	return next


# ---------------------------------------------------------------- footprints (the look only)

## Whether the weather leaves footprints (snow).
static func prints_now(d: GameDynasty) -> bool:
	return bool(_now(d).get("prints", false))


# ---------------------------------------------------------------- what the status says

## The lines about the sky now for the status pane: the night's or the day's (GameNightLife) and what the weather does.
## `heir` is the heir's tile (the day's stall is mentioned only near one). Empty in clear weather by day away from a stall.
static func notes(d: GameDynasty, heir: Vector2i = Vector2i(-100000, -100000)) -> Array:
	var out: Array = []
	var n := GameNightLife.note(d, heir)
	if n != "":
		out.append(n)
	var t := str(_now(d).get("text", ""))
	if t != "":
		out.append(t)
	return out


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "weather"]:
		if not dat.has(k):
			bad.append("weather_effects.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var s: Dictionary = dat["settings"]
	for k in ["view_tiles", "veil_alpha", "veil_soft", "hide_margin", "max_prints", "print_seconds"]:
		if not s.has(k):
			bad.append("weather_effects.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if float(s["view_tiles"]) < 4.0 or float(s["veil_alpha"]) <= 0.0 or float(s["veil_alpha"]) > 1.0 or float(s["veil_soft"]) <= 0.0 or float(s["veil_soft"]) >= 1.0:
		bad.append("weather_effects.json: view_tiles must be at least 4, veil_alpha above 0 up to 1 and veil_soft between 0 and 1")
	if float(s["hide_margin"]) < 1.0 or int(s["max_prints"]) < 1 or float(s["print_seconds"]) <= 0.0:
		bad.append("weather_effects.json: hide_margin must be at least 1, max_prints at least 1 and print_seconds above 0")
	GameData.load_all()
	var ids: Array = GameData.world["weather"].map(func(w): return str(w["id"]))
	var elements := {}
	for c in GameData.creatures:
		if str(c.get("element", "")) != "":
			elements[str(c["element"])] = true
	for id in dat["weather"]:
		var e: Dictionary = dat["weather"][id]
		if str(id) not in ids:
			bad.append("weather_effects.json: '%s' is not a weather" % id)
		if str(id) == "clear":
			bad.append("weather_effects.json: clear weather must have no effects")
		if str(e.get("text", "")) == "":
			bad.append("weather_effects.json: '%s' needs a text line, so nothing is opaque" % id)
		for k in ["walk", "herb_regrow"]:
			if e.has(k) and (typeof(e[k]) not in [TYPE_INT, TYPE_FLOAT] or float(e[k]) <= 0.0 or float(e[k]) > 3.0):
				bad.append("weather_effects.json: '%s' %s must be above 0 and at most 3" % [id, k])
		for el in e.get("slow", {}):
			if not elements.has(str(el)) or float(e["slow"][el]) <= 0.0 or float(e["slow"][el]) > 1.0:
				bad.append("weather_effects.json: '%s' slows the element '%s' wrongly (a creature element, above 0 up to 1)" % [id, el])
		for k in e:
			if str(k) not in ["walk", "herb_regrow", "slow", "shelter_fliers", "prints", "text"]:
				bad.append("weather_effects.json: '%s' has the unknown effect '%s'" % [id, k])
	return bad
