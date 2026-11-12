## Random world events (roadmap item 19): wars, famines, pestilences, fairs and golden ages that come and go with
## the years and change prices, what fights and work pay, and how easily sickness takes hold. One runs at a time
## (GameDynasty.world_event); it begins and ends on dice keyed on the dynasty seed and the year, never the
## dynasty's own. Rules and text are in data/world/world_events.json. This changes what the autopilot meets: a
## balance change (docs/BALANCE.md).
class_name GameWorldEvents
extends RefCounted

const EFFECTS := ["price_mult", "hunt_gold_mult", "hunt_xp_mult", "work_gold_mult", "disease_mult"]

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json("res://data/world/world_events.json")
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func ids() -> Array:
	var out: Array = data()["events"].keys()
	out.sort()
	return out


static func event(id: String) -> Dictionary:
	return data()["events"].get(id, {})


## The id of the event running now, or "".
static func active(d: GameDynasty) -> String:
	var id := str(d.world_event.get("id", ""))
	return id if id != "" and data()["events"].has(id) else ""


## What the running event does to one of the game's numbers: 1.0 when none runs or it does not touch it.
static func mult(d: GameDynasty, key: String) -> float:
	var id := active(d)
	if id == "":
		return 1.0
	return float(event(id).get("effects", {}).get(key, 1.0))


## Whether an event can begin in this generation of the Age.
static func in_window(id: String, era_gen: int) -> bool:
	var e := event(id)
	return era_gen >= int(e.get("min_gen", 1)) and era_gen <= int(e.get("max_gen", 1 << 30))


static func _rng(d: GameDynasty, year: int, what: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "world event", what, year])
	return r


## The event that begins in `year` if the world is free, or "" (most years). The same for the same seed and year.
static func rolled(d: GameDynasty, year: int) -> String:
	if year < int(setting("grace_years")):
		return ""
	var r := _rng(d, year, "begins")
	if r.randf() >= float(setting("chance_per_year")):
		return ""
	var pool: Array = ids().filter(func(id): return in_window(id, d.era_gen()))
	var total := 0.0
	for id in pool:
		total += float(event(id)["weight"])
	if total <= 0.0:
		return ""
	var at := r.randf() * total
	for id in pool:
		at -= float(event(id)["weight"])
		if at < 0.0:
			return id
	return str(pool[-1])


## How many years an event beginning in `year` lasts.
static func length(d: GameDynasty, id: String, year: int) -> int:
	var span: Array = event(id)["years"]
	return _rng(d, year, "length").randi_range(int(span[0]), int(span[1]))


## Begins an event in `year` (a test or the clock). Returns the line told, or "" for an unknown event.
static func begin(d: GameDynasty, id: String, year: int, msgs: Array = []) -> String:
	if not data()["events"].has(id):
		return ""
	d.world_event = {"id": id, "began": year, "until": year + length(d, id, year)}
	var flag := str(setting("counter_flag"))
	d.flags[flag] = int(d.flags.get(flag, 0)) + 1
	var line := str(event(id)["begins"])
	d._say(line)
	msgs.append(line)
	return line


## Time passes: for each whole year the world clock crosses, the running event may end, and with the world free
## and rested one may begin. `year_end` is the world's year now (a parameter so a test can set it).
static func on_years(d: GameDynasty, years: float, msgs: Array, year_end: float = -1.0) -> void:
	if years <= 0.0 or d.state != "life":
		return
	var end := d.world.year if year_end < 0.0 else year_end
	for y in range(int(floor(end - years)) + 1, int(floor(end)) + 1):
		var id := active(d)
		if id != "":
			if y < int(d.world_event.get("until", y)):
				continue
			var line := str(event(id)["ends"])
			d._say(line)
			msgs.append(line)
			d.world_event = {"id": "", "until": y + int(setting("rest_years"))}
			continue
		if not d.world_event.is_empty():
			if y < int(d.world_event.get("until", y)):
				continue
			d.world_event = {}
		var next := rolled(d, y)
		if next != "":
			begin(d, next, y, msgs)


## What a screen says of the world now: the running event with what it does and when it ends, or that all is quiet.
static func describe(d: GameDynasty) -> String:
	var id := active(d)
	if id == "":
		return str(data()["text"]["quiet"])
	var e := event(id)
	var n := str(e["name"])
	return str(data()["text"]["now"]).format({"name": n.substr(0, 1).to_upper() + n.substr(1), "about": str(e["about"]),
		"until": GameText.num(int(d.world_event.get("until", 0)) + 1)})


## A saved world event made safe: a known event with whole years, a rest with its year, or nothing.
static func load_state(v: Variant) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	var until: Variant = v.get("until")
	if typeof(until) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(until)):
		return {}
	var id: Variant = v.get("id", "")
	if typeof(id) != TYPE_STRING:
		return {}
	if id == "":
		return {"id": "", "until": int(until)}
	if not data()["events"].has(id):
		return {}
	var began: Variant = v.get("began")
	return {"id": id, "began": int(began) if typeof(began) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(began)) else int(until), "until": int(until)}


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "events", "text"]:
		if typeof(dat.get(k)) != TYPE_DICTIONARY:
			bad.append("world_events.json has no '%s'" % k)
	if not bad.is_empty():
		return bad
	var chance := float(setting("chance_per_year"))
	if chance <= 0.0 or chance > 0.5:
		bad.append("world events: chance_per_year must be above 0 and no more than 0.5")
	if int(setting("rest_years")) < 1:
		bad.append("world events: the world must rest at least a year between events")
	if int(setting("grace_years")) < 0:
		bad.append("world events: grace_years cannot be negative")
	if str(setting("counter_flag")) == "":
		bad.append("world events: counter_flag is missing")
	if (dat["events"] as Dictionary).is_empty():
		bad.append("world events: there are none")
	var always := false
	for id in dat["events"]:
		var e: Dictionary = dat["events"][id]
		for k in ["name", "begins", "ends", "about"]:
			if str(e.get(k, "")).strip_edges() == "":
				bad.append("world event %s: needs %s" % [id, k])
		if float(e.get("weight", 0)) <= 0.0:
			bad.append("world event %s: needs a weight above 0" % id)
		var span: Variant = e.get("years")
		if typeof(span) != TYPE_ARRAY or (span as Array).size() != 2 or int(span[0]) < 1 or int(span[1]) < int(span[0]):
			bad.append("world event %s: years must be [least, most], at least 1" % id)
		var fx: Variant = e.get("effects")
		if typeof(fx) != TYPE_DICTIONARY or (fx as Dictionary).is_empty():
			bad.append("world event %s: changes nothing" % id)
		else:
			for k in fx:
				if k not in EFFECTS:
					bad.append("world event %s: changes '%s', which nothing reads" % [id, k])
				elif typeof(fx[k]) not in [TYPE_INT, TYPE_FLOAT] or float(fx[k]) < 0.25 or float(fx[k]) > 4.0 or float(fx[k]) == 1.0:
					bad.append("world event %s: %s must be between 0.25 and 4, and not 1" % [id, k])
		if int(e.get("min_gen", 1)) > int(e.get("max_gen", 1 << 30)):
			bad.append("world event %s: its window ends before it begins" % id)
		if not e.has("min_gen") and not e.has("max_gen"):
			always = true
	if not always:
		bad.append("world events: none can begin in every generation, so some generations could have none to pick")
	for k in ["now", "quiet"]:
		if str(dat["text"].get(k, "")) == "":
			bad.append("world events: the text '%s' is missing" % k)
	return bad
