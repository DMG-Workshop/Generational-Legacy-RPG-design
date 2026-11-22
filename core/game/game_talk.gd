## What the people of the open world's towns say to the heir (core, no UI; rules in data/world/talk.json, words in the `talk` catalog
## data/text/talk.json, read through GameLocale). A person speaks when the heir uses them (`beside`, `talk`, `reply`) and sometimes
## first (`greeting`). Every choice is a hash of the seed, the person's id, the day, the hour and the heir's tile: no dice of the
## dynasty's are drawn, nothing is saved, so the same save gives the same words. The screen draws the bubble and the panel.
class_name GameTalk
extends RefCounted

const PATH := "res://data/world/talk.json"
const LINES := "res://data/text/talk.json"
const NEVER := -1.0e9

static var _cache: Dictionary = {}
static var _lines: Dictionary = {}
static var _counts: Dictionary = {}   # group -> how many variants
static var _rumours: Dictionary = {}  # "seed|place|day" -> the sighting


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


## The catalog's lines by key (also the `talk` catalog of GameLocale).
static func lines() -> Dictionary:
	if _lines.is_empty():
		_lines = GameData.load_json(LINES).get("lines", {})
		_counts = {}
		for k in _lines:
			var i := (k as String).rfind(".")
			if i > 0 and (k as String).substr(i + 1).is_valid_int():
				var g := (k as String).substr(0, i)
				_counts[g] = maxi(int(_counts.get(g, 0)), int((k as String).substr(i + 1)))
	return _lines


## How many variants a group of lines has (0 when it has none).
static func variants(group: String) -> int:
	lines()
	return int(_counts.get(group, 0))


## A line by its key, in the chosen language, its {placeholders} filled.
static func text(key: String, vals: Dictionary = {}) -> String:
	var src := str(lines().get(key, key))
	return GameLocale.text("talk", key, src).format(vals)


static func _h(parts: Array) -> int:
	return absi(hash(parts))


## A variant of a group by a hash, formatted; "" when the group has no lines.
static func _variant(group: String, h: int, vals: Dictionary) -> String:
	var n := variants(group)
	if n == 0:
		return ""
	return text("%s.%d" % [group, h % n + 1], vals)


# ---------------------------------------------------------------- who is near

## The people the heir could talk to from a point (x, z in tiles): those out of doors and the gate guards within `reach_street`, and
## those inside a building whose roof is lifting within `reach_house` (a sleeper too). Each is {id, job_id, job, work, race, class, scale,
## creature, place, gate, x, z, asleep, dist, where ("street", "gate" or "house")}, the nearest first.
static func nearby(d: GameDynasty, x: float, z: float, hour: float, street: float, house: float) -> Array:
	var out: Array = []
	for w in GameVillagers.walkers_near(d, x, z, street + 1.0, hour):
		var dist := Vector2(float(w["x"]), float(w["z"])).distance_to(Vector2(x, z))
		if dist > street:
			continue
		out.append({"id": str(w["id"]), "job_id": str(w.get("job_id", "")), "job": str(w["job"]), "work": _work_of(str(w.get("job_id", ""))), "race": str(w["race"]), "class": str(w["class"]),
			"scale": float(w["scale"]), "creature": str(w["creature"]), "place": str(w.get("place", "")), "gate": str(w.get("gate", "")), "x": float(w["x"]), "z": float(w["z"]),
			"asleep": false, "dist": dist, "where": "gate" if str(w.get("gate", "")) != "" else "street"})
	var night := GameDay.is_night(d)
	var rect := Rect2i(floori(x) - 8, floori(z) - 8, 17, 17)
	for b in GameTown.in_rect(rect):
		if str(b["kind"]) == "family" or str(b["kind"]) == "board":
			continue
		var body := Rect2i(int(b["x"]), int(b["z"]), int(b["w"]), int(b["h"]))
		if GameReveal.alpha(GameReveal.distance_to(body, x, z)) >= 1.0:
			continue   # the roof is whole: the people inside are not seen
		var who := GameVillagers.residents(b)
		for i in who.size():
			if not GameVillagers.present(d, b, i, hour):
				continue
			var sp := GameVillagers.spot(b, i, hour, night)
			if sp.is_empty():
				continue
			var cell: Vector2i = sp["cell"]
			var px := float(body.position.x + cell.x) + 0.5
			var pz := float(body.position.y + cell.y) + 0.5
			var dist := Vector2(px, pz).distance_to(Vector2(x, z))
			if dist > house:
				continue
			var job := GameVillagers.job_of(b, i)
			var r: Dictionary = who[i]
			out.append({"id": str(r["id"]), "job_id": str(job.get("id", "")), "job": str(job.get("name", "")), "work": str(job.get("work", "")), "race": str(r["race"]), "class": str(r["class"]),
				"scale": float(r["scale"]), "creature": str(r["creature"]), "place": str(b["place"]), "gate": "", "x": px, "z": pz, "asleep": bool(sp["asleep"]), "dist": dist, "where": "house"})
	out.sort_custom(func(p, q): return float(p["dist"]) < float(q["dist"]) or (float(p["dist"]) == float(q["dist"]) and str(p["id"]) < str(q["id"])))
	return out


static func _work_of(job_id: String) -> String:
	for j in GameVillagers.data()["jobs"]:
		if str(j["id"]) == job_id:
			return str(j["work"])
	return job_id   # a service person's job id is the service's name


## The person the heir would talk to with Use, standing at the tile: the nearest in reach, or {}.
static func beside(d: GameDynasty, tile: Vector2i, hour: float) -> Dictionary:
	var list := nearby(d, float(tile.x) + 0.5, float(tile.y) + 0.5, hour, float(setting("reach_street")), float(setting("reach_house")))
	return {} if list.is_empty() else list[0]


# ---------------------------------------------------------------- what they say

static func _vals(d: GameDynasty, who: Dictionary) -> Dictionary:
	var place := str(who.get("place", ""))
	var town := str(GameWorldGen.anchor(place).get("name", place))
	var faction := str(GameFactions.data().get("towns", {}).get(place, ""))
	var gate := GameWalls.all_gates().filter(func(g): return str(g["id"]) == str(who.get("gate", "")))
	var vals := {"heir": str(d.heir.name), "house": str(d.dynasty_name), "town": town, "faction": GameFactions.name_of(faction) if faction != "" else town, "job": str(who["job"]), "dest": "", "gate": ""}
	if not gate.is_empty():
		vals["gate"] = gate_name(gate[0])
		var dest := GameWalls.road_of(gate[0])
		vals["dest"] = str(GameWorldGen.anchor(dest).get("name", dest)) if dest != "" else ""
	return vals


## A gate's name ("North Gate").
static func gate_name(g: Dictionary) -> String:
	return text("gate.name.%s" % str(g["side"]))


## What a person says when the heir uses them: {ok, text, who, choices [{id, label}]}. A sleeper mumbles; a monster or a person says
## their job's line for the time of day, then the extras (weather, standing, house, size, race, town) their id picks.
static func talk(d: GameDynasty, who: Dictionary, hour: float) -> Dictionary:
	if who.is_empty():
		return {"ok": false, "text": "", "who": {}, "choices": []}
	var day := GameDay.day_number(d)
	var block := int(floor(hour / float(setting("hour_block"))))
	var base := [d.seed_value, "say", str(who["id"]), day, block]
	var vals := _vals(d, who)
	var parts: Array = []
	if bool(who.get("asleep", false)):
		parts.append(_variant("asleep", _h(base + ["z"]), vals))
	elif str(who["creature"]) != "":
		parts.append(_variant("creature.%s" % str(who["creature"]), _h(base + ["c"]), vals))
	else:
		if str(who.get("gate", "")) != "":
			parts.append(_variant("gate.call" if str(vals["dest"]) != "" else "gate.call_plain", _h(base + ["g"]), vals))
		parts.append(_variant("job.%s.%s" % [str(who["job_id"]), "night" if GameDay.is_night(d) else "day"], _h(base + ["j"]), vals))
		var kinds: Array = (data()["extras"] as Array).duplicate()
		kinds.sort_custom(func(p, q): return _h(base + ["x", p]) < _h(base + ["x", q]))
		var added := 0
		for k in kinds:
			if added >= int(setting("extras")):
				break
			var line := _extra(d, who, str(k), _h(base + ["e", k]), vals)
			if line != "":
				parts.append(line)
				added += 1
	var said := " ".join(parts.filter(func(p): return p != ""))
	return {"ok": true, "text": text("format.say", {"job": str(who["job"]), "text": said}), "bare": said, "who": who, "choices": choices_of(who)}


static func _extra(d: GameDynasty, who: Dictionary, kind: String, h: int, vals: Dictionary) -> String:
	match kind:
		"weather":
			return _variant("weather.%s" % GameDay.weather_id(d), h, vals)
		"standing":
			var f := str(GameFactions.data().get("towns", {}).get(str(who.get("place", "")), ""))
			return "" if f == "" else _variant("standing.%s" % GameFactions.rank(d, f), h, vals)
		"house":
			return _variant("house.built" if not d.built.is_empty() else "house.none", h, vals)
		"size":
			var s := float(who["scale"])
			var mine := GameVillagers.scale_of(str(d.heir.race_id))
			if s < float(setting("small_below")):
				return _variant("size.small", h, vals)
			if s > float(setting("large_above")):
				return _variant("size.large", h, vals)
			if mine - s > float(setting("size_gap")):
				return _variant("size.heir_tall", h, vals)
			if s - mine > float(setting("size_gap")):
				return _variant("size.heir_short", h, vals)
			return ""
		"race":
			var key := "race.%s" % str(who["race"])
			return text(key, vals) if lines().has(key) else ""
		"town":
			return _variant("town.%s" % str(who.get("place", "")), h, vals)
	return ""


## The choices a person offers: [{id, label}] (the job's `conversations`).
static func choices_of(who: Dictionary) -> Array:
	var out: Array = []
	if bool(who.get("asleep", false)) or str(who["creature"]) != "":
		return out
	for c in data()["conversations"].get(str(who["job_id"]), []):
		out.append({"id": str(c), "label": text(str(data()["choices"][c]["label"]))})
	return out


## A person's answer to a choice: {ok, text}. A rumour and a warning name the creature seen near the town (`sighting`) or say
## there is none; `wares` names what the person's service offers.
static func reply(d: GameDynasty, who: Dictionary, choice: String, hour: float) -> Dictionary:
	if who.is_empty() or not data()["choices"].has(choice) or not any_choice(who, choice):
		return {"ok": false, "text": ""}
	var day := GameDay.day_number(d)
	var base := [d.seed_value, "reply", str(who["id"]), day, choice]
	var vals := _vals(d, who)
	var said := ""
	match str(data()["choices"][choice]["reply"]):
		"rumour", "warn":
			var kind := str(data()["choices"][choice]["reply"])
			var s := sighting(d, str(who["place"]), day)
			if s.is_empty():
				said = _variant("%s.none" % kind, _h(base), vals)
			else:
				vals["creature"] = str(s["name"]).to_lower()
				vals["dir"] = text("dir.%s" % str(s["dir"]))
				vals["paces"] = int(s["paces"])
				said = _variant(kind, _h(base), vals)
		"wares":
			said = text("wares.%s" % str(who["work"]), vals) if lines().has("wares.%s" % str(who["work"])) else ""
	return {"ok": said != "", "text": text("format.say", {"job": str(who["job"]), "text": said}), "bare": said}


static func any_choice(who: Dictionary, choice: String) -> bool:
	for c in choices_of(who):
		if str(c["id"]) == choice:
			return true
	return false


## A creature the world has near a town today: {id, name, x, z, dir, paces} of the first tile (by a hash of the seed, the town and
## the day, up to `rumour.tries` of them, `rumour.min` to `rumour.max` tiles from the anchor) where GameSpawn puts one by day, or {}.
static func sighting(d: GameDynasty, place: String, day: int) -> Dictionary:
	var key := "%d|%s|%d" % [d.seed_value, place, day]
	if _rumours.has(key):
		return _rumours[key]
	var out := {}
	var a := GameWorldGen.anchor(place)
	if not a.is_empty():
		var r: Dictionary = data()["rumour"]
		for k in int(r["tries"]):
			var ang := float(_h([d.seed_value, "ra", place, day, k]) % 3600) / 3600.0 * TAU
			var dist := float(r["min"]) + float(_h([d.seed_value, "rd", place, day, k]) % 1000) / 1000.0 * float(int(r["max"]) - int(r["min"]))
			var tx := int(round(float(a["x"]) + cos(ang) * dist))
			var tz := int(round(float(a["z"]) + sin(ang) * dist))
			if not GameWorldGen.in_bounds(tx, tz):
				continue
			var id := GameSpawn.spawn_at(d, tx, GameBuild.SURFACE, tz, 0, false)
			if id == "":
				continue
			var name := id
			for c in GameData.creatures:
				if str(c["id"]) == id:
					name = str(c["name"])
			var octant := int(round(rad_to_deg(ang) / 45.0))
			out = {"id": id, "name": name, "x": tx, "z": tz, "dir": str(data()["directions"][posmod(octant, 8)]), "paces": int(round(dist / 5.0) * 5)}
			break
	if _rumours.size() > 64:
		_rumours.clear()
	_rumours[key] = out
	return out


# ---------------------------------------------------------------- talking first

## Whether the person at `id` calls out to the heir standing on `tile` on `day`: a hash of the seed, the person, the day and the tile
## against `percent`. A pure function; the day's one greeting and the cooldown are the caller's (`greeting`).
static func wants(d: GameDynasty, id: String, day: int, tile: Vector2i, percent: int) -> bool:
	return _h([d.seed_value, "greet", id, day, tile.x, tile.y]) % 100 < percent


## Who calls out to the heir at `tile`, if anyone: {who, text (the line, bare), line (with the job), offers (they have choices)} or {}.
## `seen` maps a person's id to the last day they spoke and `last_at` is the world clock's seconds when anyone last did: nobody
## speaks twice in a day or within `cooldown_seconds` of another. Those asleep, the monsters and the nearest-first order decide the
## rest; the caller records the greeting (`seen[id] = day`, `last_at`) and never asks during a fight or while a panel is open.
static func greeting(d: GameDynasty, tile: Vector2i, hour: float, seen: Dictionary, last_at: float) -> Dictionary:
	if GameDay.seconds(d) - last_at < float(setting("cooldown_seconds")):
		return {}
	var day := GameDay.day_number(d)
	var list := nearby(d, float(tile.x) + 0.5, float(tile.y) + 0.5, hour, float(setting("call_range")), float(setting("call_range_house")))
	for w in list:
		if bool(w["asleep"]) or str(w["creature"]) != "" or int(seen.get(str(w["id"]), -1)) == day:
			continue
		var percent := int(setting("gate_percent")) if str(w["gate"]) != "" else int(setting("chance_percent"))
		if not wants(d, str(w["id"]), day, tile, percent):
			continue
		var vals := _vals(d, w)
		var h := _h([d.seed_value, "call", str(w["id"]), day])
		var bare := ""
		if str(w["gate"]) != "":
			bare = _variant("gate.call" if str(vals["dest"]) != "" else "gate.call_plain", h, vals)
		else:
			bare = _variant("call.%s" % str(w["job_id"]), h, vals)
		if bare == "":
			continue
		var offers := not choices_of(w).is_empty()
		var line := text("format.call", {"job": str(w["job"]), "text": bare})
		if offers:
			line += " " + text("hint.talk")
		return {"who": w, "text": bare, "line": line, "offers": offers}
	return {}


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "rumour", "conversations", "choices", "extras", "directions"]:
		if not dat.has(k):
			bad.append("talk.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var s: Dictionary = dat["settings"]
	for k in ["reach_street", "reach_house", "call_range", "call_range_house", "chance_percent", "gate_percent", "cooldown_seconds", "hour_block", "extras", "small_below", "large_above", "size_gap", "bubble_seconds"]:
		if not s.has(k) or typeof(s[k]) not in [TYPE_INT, TYPE_FLOAT]:
			bad.append("talk.json: settings.%s is missing or not a number" % k)
	if not bad.is_empty():
		return bad
	if float(s["reach_street"]) <= 0.0 or float(s["reach_house"]) <= 0.0 or float(s["call_range"]) <= 0.0 or float(s["call_range_house"]) <= 0.0:
		bad.append("talk.json: the reaches are above 0")
	for k in ["chance_percent", "gate_percent"]:
		if int(s[k]) < 1 or int(s[k]) > 100:
			bad.append("talk.json: %s is 1 to 100" % k)
	if int(s["chance_percent"]) > 50:
		bad.append("talk.json: chance_percent is at most 50 (a greeting is not every time)")
	if float(s["cooldown_seconds"]) <= 0.0 or float(s["hour_block"]) <= 0.0 or float(s["hour_block"]) > 24.0 or int(s["extras"]) < 0 or float(s["bubble_seconds"]) <= 0.0:
		bad.append("talk.json: a cooldown, an hour block and a bubble time above 0, extras 0 or more")
	var r: Dictionary = dat["rumour"]
	if int(r.get("min", 0)) < int(GameWorldGen.data()["settings"]["anchor_radius"]["town"]) or int(r.get("max", 0)) <= int(r.get("min", 0)) or int(r.get("tries", 0)) < 1:
		bad.append("talk.json: rumour is a min past the town's ground, a larger max and at least 1 try")
	if (dat["directions"] as Array).size() != 8:
		bad.append("talk.json: directions are the eight points, east first and turning south")
	# every choice has a label and a known reply; every conversation names a known job and known choices
	var job_ids := {}
	for j in GameVillagers.data()["jobs"]:
		job_ids[str(j["id"])] = true
	for sv in GameVillagers.data()["service_jobs"]:
		job_ids[str(sv)] = true
	for c in dat["choices"]:
		var ch: Dictionary = dat["choices"][c]
		if not lines().has(str(ch.get("label", ""))):
			bad.append("talk.json: the choice '%s' has no label line" % c)
		if str(ch.get("reply", "")) not in ["rumour", "warn", "wares"]:
			bad.append("talk.json: the choice '%s' has an unknown reply" % c)
	for jid in dat["conversations"]:
		if not job_ids.has(str(jid)):
			bad.append("talk.json: conversations name the unknown job '%s'" % jid)
		for c in dat["conversations"][jid]:
			if not dat["choices"].has(str(c)):
				bad.append("talk.json: the job '%s' offers the unknown choice '%s'" % [jid, c])
	for k in dat["extras"]:
		if str(k) not in ["weather", "standing", "house", "size", "race", "town"]:
			bad.append("talk.json: the unknown extra '%s'" % k)
	# the catalog: every group the code can ask for has lines, every line belongs to one, placeholders are known
	var groups := {}   # group -> true (numbered variants)
	var singles := {}
	for j in job_ids:
		groups["job.%s.day" % j] = true
		groups["job.%s.night" % j] = true
		groups["call.%s" % j] = true
	for m in GameVillagers.data()["monsters"]:
		groups["creature.%s" % m["creature"]] = true
	for g in ["asleep", "gate.call", "gate.call_plain", "rumour", "rumour.none", "warn", "warn.none", "house.built", "house.none", "size.small", "size.large", "size.heir_tall", "size.heir_short"]:
		groups[g] = true
	for w in GameDay.data()["weather_look"]:
		groups["weather.%s" % w] = true
	for rk in GameFactions.data()["ranks"]:
		groups["standing.%s" % rk["id"]] = true
	for t in GameTown.towns():
		groups["town.%s" % t] = true
	for rid in GameData.races:
		singles["race.%s" % rid] = true
	for sd in ["n", "e", "s", "w"]:
		singles["gate.name.%s" % sd] = true
	for dn in dat["directions"]:
		singles["dir.%s" % dn] = true
	for k in ["choice.news", "choice.fear", "choice.wares", "choice.bye", "hint.talk", "format.say", "format.call", "wares.forge", "wares.temple", "wares.store", "wares.tavern", "wares.black_market"]:
		singles[k] = true
	var known := ["heir", "house", "town", "faction", "gate", "dest", "creature", "dir", "paces", "job", "text"]
	_lines = {}
	for k in lines():
		var key := str(k)
		var line: Variant = lines()[k]
		if typeof(line) != TYPE_STRING or str(line).strip_edges() == "":
			bad.append("talk.json: the line '%s' is not text" % key)
			continue
		for p in GameLocale.placeholders(str(line)):
			if str(p) not in known:
				bad.append("talk.json: the line '%s' uses the unknown placeholder {%s}" % [key, p])
		var i := key.rfind(".")
		var tail := key.substr(i + 1)
		if tail.is_valid_int() and groups.has(key.substr(0, i)):
			pass
		elif not singles.has(key):
			bad.append("talk.json: the line '%s' is one nothing asks for" % key)
	for g in groups:
		for n in range(1, variants(g) + 1):
			if not lines().has("%s.%d" % [g, n]):
				bad.append("talk.json: the variants of '%s' are not numbered from 1 without a gap" % g)
				break
		if variants(g) < 2 and not (g in ["gate.call_plain"]):
			bad.append("talk.json: '%s' has %d lines, at least 2 for some variety" % [g, variants(g)])
	for sk in singles:
		if not lines().has(sk):
			bad.append("talk.json: the line '%s' is missing" % sk)
	return bad
