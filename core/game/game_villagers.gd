## The people who live in the open world's town buildings (core, no UI; data/world/villagers.json). A plain house has residents by
## the size of its body; a service building has its one person. Who they are and where they stand are pure functions of the
## building and the hour (`GameDay.hour`): no dice, nothing saved, so a village is the same people every time. The sandbox screen
## draws them when a building's roof is off; nobody is drawn under a whole roof.
class_name GameVillagers
extends RefCounted

const SpriteArtRef := preload("res://ui/play/sprite_art.gd")   # (only asked whether a creature has art, by the validator)

const PATH := "res://data/world/villagers.json"

static var _cache: Dictionary = {}
static var _trips: Dictionary = {}   # "seed|building|i" -> the day's trip (the way is worked out once)


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func _h(text: String) -> int:
	return absi(hash(text))


## The size of a person of `race` against a human's (1.0): a halfling is smaller, an orc or a dragonborn larger. Drawn so, and
## it sets the room they need.
static func scale_of(race: String) -> float:
	return float(data()["sizes"].get(race, 1.0))


## The floor a person of that scale needs to live in, in tiles: `area_per_person` for a human, more for the large, less for the
## small (by the square of the size, as a floor is).
static func need_of(scale: float) -> float:
	return float(data()["settings"]["area_per_person"]) * scale * scale


## How many humans a house of `area` tiles holds (at most `max_residents`).
static func count_for(area: int) -> int:
	return clampi(int(floor(float(area) / need_of(1.0))), 1, int(data()["settings"]["max_residents"]))


## The residents of a building (`GameTown` entry): [{id, class, race, color, service, scale, creature}]. A plain house holds as many
## people as its floor has room for (each needs `need_of` their size; the large races and the monsters of the town, which live
## beside the people, are put only in houses that can hold them), so a hall for an ogre is not a hut. A service building has its one
## person; the family house and the notice board have none (the family's own house is the family's). `creature` is a monster's
## kind, or "" for a person.
static func residents(b: Dictionary) -> Array:
	var out: Array = []
	var kind := str(b["kind"])
	if kind == "family" or kind == "board":
		return out
	if kind == "house":
		var place := str(b["place"])
		var races: Array = data()["races"].get(place, ["human"])
		var classes: Array = data()["classes"]
		var colors: Array = data()["colors"]
		var monsters: Array = []
		for m in data()["monsters"]:
			if place in m["places"]:
				monsters.append(m)
		var room := float(int(b["w"]) * int(b["h"]))
		var cap := int(data()["settings"]["max_residents"])
		for i in cap:
			var seed_text := "%s:%d" % [b["id"], i]
			var pool: Array = []   # [race, creature, scale]
			for r in races:
				pool.append([str(r), "", scale_of(str(r))])
			if _h(seed_text + "m") % 100 < int(data()["settings"]["monster_percent"]):
				for m in monsters:
					pool.append(["", str(m["creature"]), float(m["scale"])])
			var fits: Array = pool.filter(func(c): return need_of(float(c[2])) <= room)
			if fits.is_empty():
				break
			var c: Array = fits[_h(seed_text + "r") % fits.size()]
			room -= need_of(float(c[2]))
			out.append({"id": seed_text, "class": str(classes[_h(seed_text + "c") % classes.size()]), "race": str(c[0]), "creature": str(c[1]),
				"scale": float(c[2]), "color": str(colors[_h(seed_text + "s") % colors.size()]), "service": ""})
		if out.is_empty():
			var seed_text := "%s:0" % b["id"]
			out.append({"id": seed_text, "class": str(classes[_h(seed_text + "c") % classes.size()]), "race": "halfling", "creature": "", "scale": scale_of("halfling"),
				"color": str(colors[_h(seed_text + "s") % colors.size()]), "service": ""})
	else:
		var s: Dictionary = data()["service"].get(kind, {})
		if not s.is_empty():
			out.append({"id": "%s:person" % b["id"], "class": str(s["class"]), "race": str(s["race"]), "creature": str(s.get("creature", "")), "scale": float(s.get("scale", scale_of(str(s["race"])))),
				"color": str(s["color"]), "service": kind})
	return out


## The tallest of a building's people against a human: its door is made for them.
static func door_scale(b: Dictionary) -> float:
	var tallest := 1.0
	for r in residents(b):
		tallest = maxf(tallest, float(r["scale"]))
	return tallest


## Where resident `i` of `b` stands at the world's hour: {cell: Vector2i (x east, z south in the body), asleep}. A service person
## stands behind the counter in the middle of the room, near the back. By night a resident is in bed (the first in the top left, the others
## by the hearth); by day each is in a cell below the top row, which changes every `slot_hours` hours.
static func spot(b: Dictionary, i: int, hour: float, night: bool) -> Dictionary:
	var w := int(b["w"])
	var h := int(b["h"])
	var r: Array = residents(b)
	if i < 0 or i >= r.size():
		return {}
	if str(r[i]["service"]) != "":
		return {"cell": Vector2i(w / 2, mini(1, h - 1)), "asleep": false}
	if night:
		var cells := [Vector2i(mini(1, w - 1), mini(1, h - 1)), Vector2i(maxi(w - 2, 0), mini(1, h - 1)), Vector2i(maxi(w - 2, 0), mini(3, h - 1))]
		return {"cell": cells[mini(i, cells.size() - 1)], "asleep": true}
	var row0 := 1 if h > 1 else 0
	var slots := (h - row0) * w
	var block := int(floor(hour / float(data()["settings"]["slot_hours"])))
	var k := _h("%s:%d" % [r[i]["id"], block]) % slots
	return {"cell": Vector2i(k % w, row0 + k / w), "asleep": false}


## Whether resident `i` of `b` is indoors at `hour`: a house's residents go to work by day (`jobs` in villagers.json) and are in
## their houses the rest of the time; a service person is always in. Needs the dynasty for the way (the land's trees and water).
static func present(d: GameDynasty, b: Dictionary, i: int, hour: float) -> bool:
	if str(b["kind"]) != "house":
		return GameShops.open_at(str(b["kind"]), hour)   # a shop's keeper is in by its opening hours, gone when it is shut
	var trip := trip_of(d, b, i)
	if trip.is_empty():
		return true
	return hour < float(trip["leave"]) or hour >= float(trip["back"])


## What resident `i` of a house does for a living: {id, name, work} from the `jobs` the town has the places for (a service job needs
## that service in the town), picked by weight from the resident's id: no dice. A service building's person has their service's job
## (the keeper of the store); `{}` for the family house, whose people are the family's own.
static func job_of(b: Dictionary, i: int) -> Dictionary:
	var who := residents(b)
	if i < 0 or i >= who.size():
		return {}
	var service := str(who[i]["service"])
	if service != "":
		return {"id": service, "name": str(data()["service_jobs"].get(service, service.capitalize())), "work": service}
	var here := {}
	for o in GameTown.buildings(str(b["place"])):
		here[str(o["kind"])] = true
	var open: Array = []
	var total := 0
	for j in data()["jobs"]:
		var w := str(j["work"])
		if w in ["", "field", "patrol"] or here.has(w):
			open.append(j)
			total += int(j["weight"])
	if open.is_empty():
		return {}
	var pick := _h(str(who[i]["id"]) + "j") % total
	for j in open:
		pick -= int(j["weight"])
		if pick < 0:
			return {"id": str(j["id"]), "name": str(j["name"]), "work": str(j["work"])}
	return {}


## The day's trip of resident `i` of a house: {leave, back (hours), path (points, from the home door), length (tiles), walk (hours
## each way), hours (the shift), work (the job's place: a service's name, "field" or "patrol")}, or {} when they stay in (no work to
## go to, a service person, or no way there). A service shift is spent inside the building, a field's standing in the field, and a
## patrol on foot along the streets.
static func trip_of(d: GameDynasty, b: Dictionary, i: int) -> Dictionary:
	if str(b["kind"]) != "house":
		return {}
	var key := "%d|%s|%d" % [d.seed_value, b["id"], i]
	if _trips.has(key):
		return _trips[key]
	var trip := {}
	var job := job_of(b, i)
	var w: Dictionary = data()["walk"]
	if not job.is_empty() and str(job["work"]) != "":
		var id := str(residents(b)[i]["id"])
		var from: Vector2i = b["door"]
		var anchor := GameWorldGen.anchor(str(b["place"]))
		var ground := GamePath.world_ground(d, {})
		var legs: Array = []   # the places the way runs through, after the home door
		var work := str(job["work"])
		if work == "field":
			for attempt in 8:   # a spot at the edge of the town's ground, in a direction the id picks, that can be reached
				var ang := float(_h(id + "a%d" % attempt) % 360) / 360.0 * TAU
				var r := float(w["field_from"]) + float(_h(id + "r%d" % attempt) % 100) / 100.0 * float(w["field_span"])
				var spot := Vector2i(int(round(float(anchor["x"]) + cos(ang) * r)), int(round(float(anchor["z"]) + sin(ang) * r)))
				if GameWorldGen.in_bounds(spot.x, spot.y):
					legs = [spot]
					if _route(ground, [from, spot], int(w["max_nodes"])).is_empty():
						legs = []
					else:
						break
		elif work == "patrol":
			var sv: Array = []
			for o in GameTown.buildings(str(b["place"])):
				if str(o["kind"]) != "house" and str(o["kind"]) != "board":
					sv.append(o)
			if not sv.is_empty():
				legs = [Vector2i(int(anchor["x"]), int(anchor["z"])), (sv[_h(id + "p") % sv.size()] as Dictionary)["door"]]
		else:
			for o in GameTown.buildings(str(b["place"])):
				if str(o["kind"]) == work:
					legs = [o["door"]]
					break
		if not legs.is_empty():
			var stops: Array = [from]
			stops.append_array(legs)
			var pts := _route(ground, stops, int(w["max_nodes"]))
			if not pts.is_empty():
				var length := 0.0
				for k in range(1, pts.size()):
					length += (pts[k - 1] as Vector2).distance_to(pts[k])
				var walk_h := length / float(w["tiles_per_hour"])
				var leave := float(w["depart_from"]) + float(_h(id + "t") % 1000) / 1000.0 * float(w["depart_span"])
				var hours := float(job.get("hours", w["shift_hours"]))
				for j in data()["jobs"]:
					if str(j["id"]) == str(job["id"]):
						hours = float(j["hours"])
				trip = {"leave": leave, "back": leave + 2.0 * walk_h + hours, "path": pts, "length": length, "walk": walk_h, "hours": hours, "work": work}
	_trips[key] = trip
	return trip


## The points of the way through the `stops` (tiles; a way found by `GamePath` between each pair), or [] if one cannot be found.
static func _route(ground: Dictionary, stops: Array, max_nodes: int) -> Array:
	var pts: Array = []
	for k in range(1, stops.size()):
		var a: Vector2i = stops[k - 1]
		var z: Vector2i = stops[k]
		var found := GamePath.find(ground, Vector3i(a.x, GamePath.SURFACE, a.y), Vector3i(z.x, GamePath.SURFACE, z.y), "walker", max_nodes)
		if not bool(found.get("found", false)):
			return []
		for c in found["path"]:
			var v := Vector2(float(c.x) + 0.5, float(c.z) + 0.5)
			if pts.is_empty() or (pts[pts.size() - 1] as Vector2) != v:
				pts.append(v)
	return pts


## Where resident `i` of `b` is out of doors at `hour`: {x, z, dx} (tiles; `dx` the way they face, -1 or 1), or {} when they are
## indoors (or in the service where they work).
static func outside(d: GameDynasty, b: Dictionary, i: int, hour: float) -> Dictionary:
	var trip := trip_of(d, b, i)
	if trip.is_empty() or hour < float(trip["leave"]) or hour >= float(trip["back"]):
		return {}
	var walk_h := float(trip["walk"])
	var hours := float(trip["hours"])
	var t := hour - float(trip["leave"])
	var pts: Array = trip["path"]
	var length := float(trip["length"])
	var speed := float(data()["walk"]["tiles_per_hour"])
	var work := str(trip["work"])
	if t < walk_h:
		return _at(pts, t / walk_h * length, true)
	if t < walk_h + hours:
		if work == "field":
			var e := _at(pts, length, true)
			e["dx"] = 1 if _h(str(b["id"]) + str(i)) % 2 == 0 else -1
			return e
		if work == "patrol":   # to and fro along the streets at walking pace
			var along := fmod((t - walk_h) * speed, 2.0 * length)
			var back := along > length
			return _at(pts, (2.0 * length - along) if back else along, not back)
		return {}   # inside the service
	return _at(pts, length - (t - walk_h - hours) / walk_h * length, false)


## The point `target` tiles along `pts`, facing the way of travel (reversed when not `forward`).
static func _at(pts: Array, target: float, forward: bool) -> Dictionary:
	var run := 0.0
	for k in range(1, pts.size()):
		var a: Vector2 = pts[k - 1]
		var c: Vector2 = pts[k]
		var seg := a.distance_to(c)
		if run + seg >= target or k == pts.size() - 1:
			var f := 0.0 if seg <= 0.0 else clampf((target - run) / seg, 0.0, 1.0)
			var p := a.lerp(c, f)
			var dirx := signf(c.x - a.x) * (1.0 if forward else -1.0)
			return {"x": p.x, "z": p.y, "dx": int(dirx) if dirx != 0.0 else 1}
		run += seg
	return {}


## Everyone out of doors within `radius` tiles of (x, z) at `hour`: [{id, class, race, color, x, z, dx, job}].
static func walkers_near(d: GameDynasty, x: float, z: float, radius: float, hour: float) -> Array:
	var out: Array = []
	for b in GameTown.all():
		if str(b["kind"]) != "house":
			continue
		var a := GameWorldGen.anchor(str(b["place"]))
		if Vector2(float(a["x"]), float(a["z"])).distance_to(Vector2(x, z)) > radius + float(GameTown.setting("max_reach")):
			continue
		var who := residents(b)
		for i in who.size():
			var o := outside(d, b, i, hour)
			if not o.is_empty():
				var r: Dictionary = who[i]
				out.append({"id": r["id"], "class": r["class"], "race": r["race"], "color": r["color"], "creature": r["creature"], "scale": r["scale"], "x": o["x"], "z": o["z"], "dx": o["dx"], "job": str(job_of(b, i).get("name", ""))})
	return out


static func validate() -> Array:
	var bad: Array = []
	var d := data()
	for k in ["settings", "classes", "races", "colors", "service", "walk", "jobs", "service_jobs", "sizes", "monsters"]:
		if not d.has(k):
			bad.append("villagers.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	if float(d["settings"].get("slot_hours", 0)) <= 0.0 or float(d["settings"]["slot_hours"]) > 24.0:
		bad.append("villagers.json: settings.slot_hours is above 0 and at most 24")
	var wk: Dictionary = d["walk"]
	for k in ["tiles_per_hour", "shift_hours", "depart_from", "depart_span", "max_nodes", "field_from", "field_span"]:
		if not wk.has(k) or typeof(wk[k]) not in [TYPE_FLOAT, TYPE_INT]:
			bad.append("villagers.json: walk.%s is missing or not a number" % k)
	if bad.is_empty() and (float(wk["tiles_per_hour"]) <= 0.0 or float(wk["shift_hours"]) < 0.0 or float(wk["depart_from"]) < 0.0 or float(wk["depart_span"]) < 0.0 or float(wk["field_from"]) < float(GameWorldGen.data()["settings"]["anchor_radius"]["town"]) or float(wk["field_span"]) < 0.0):
		bad.append("villagers.json: walk needs a positive speed, times from 0, and fields beyond the town's own ground")
	var kinds_seen := {}
	for o in GameTown.all():
		kinds_seen[str(o["kind"])] = true
	var weight_total := 0
	for j in d["jobs"]:
		if str(j.get("id", "")) == "" or str(j.get("name", "")) == "" or int(j.get("weight", 0)) < 1 or float(j.get("hours", 0)) <= 0.0:
			bad.append("villagers.json: a job needs an id, a name, a weight of at least 1 and hours above 0")
			continue
		weight_total += int(j["weight"])
		var w := str(j.get("work", ""))
		if w != "" and w not in ["field", "patrol"] and not kinds_seen.has(w):
			bad.append("villagers.json: the job '%s' works at '%s', which no town has" % [j["id"], w])
		if bad.is_empty() and float(wk["depart_from"]) + float(wk["depart_span"]) + 2.0 * 3.0 + float(j["hours"]) > 24.0:
			bad.append("villagers.json: a '%s' shift can run past the end of the day" % j["id"])
	if weight_total < 1:
		bad.append("villagers.json: there are no jobs")
	var st: Dictionary = d["settings"]
	for k in ["slot_hours", "area_per_person", "max_residents", "monster_percent"]:
		if not st.has(k):
			bad.append("villagers.json: settings.%s is missing" % k)
	if bad.is_empty() and (float(st["area_per_person"]) < 1.0 or int(st["max_residents"]) < 1 or int(st["monster_percent"]) < 0 or int(st["monster_percent"]) > 100):
		bad.append("villagers.json: area_per_person is at least 1, max_residents at least 1 and monster_percent 0 to 100")
	for r in d["sizes"]:
		if float(d["sizes"][r]) < 0.4 or float(d["sizes"][r]) > 3.0:
			bad.append("villagers.json: the size of %s is between 0.4 and 3 times a human's" % r)
	var known_classes: Array = GameData.load_json("res://data/art/classes.json").get("sprites", {}).keys()
	var known_races: Array = GameData.load_json("res://data/art/races.json").get("races", {}).keys()
	for r in known_races:
		if not d["sizes"].has(r):
			bad.append("villagers.json: the race %s has no size" % r)
	var largest := 0
	for tb in GameTown.all():
		if str(tb["kind"]) == "house":
			largest = maxi(largest, int(tb["w"]) * int(tb["h"]))
	for m in d["monsters"]:
		if not SpriteArtRef.has_creature(str(m.get("creature", ""))):
			bad.append("villagers.json: the monster '%s' has no art" % m.get("creature", ""))
		elif float(m.get("scale", 0)) < 0.4 or float(m["scale"]) > 3.0:
			bad.append("villagers.json: the monster '%s' is between 0.4 and 3 times a human's" % m["creature"])
		elif need_of(float(m["scale"])) > float(largest):
			bad.append("villagers.json: no house is big enough for the monster '%s' (it needs %.0f tiles, the largest house has %d)" % [m["creature"], need_of(float(m["scale"])), largest])
		for pl in m.get("places", []):
			if not GameTown.towns().has(pl):
				bad.append("villagers.json: the monster '%s' lives in %s, which is no town" % [m["creature"], pl])
	for c in d["classes"]:
		if not known_classes.has(c):
			bad.append("villagers.json: '%s' has no figure art" % c)
	for place in d["races"]:
		for r in d["races"][place]:
			if not known_races.has(r):
				bad.append("villagers.json: the race '%s' of %s has no art" % [r, place])
	for t in GameTown.towns():
		if not d["races"].has(t):
			bad.append("villagers.json: the town %s has no races" % t)
	for c in d["colors"]:
		if not Color.html_is_valid(str(c)):
			bad.append("villagers.json: '%s' is not a colour" % c)
	for k in d["service"]:
		var s: Dictionary = d["service"][k]
		if not known_classes.has(str(s.get("class", ""))) or not known_races.has(str(s.get("race", ""))) or not Color.html_is_valid(str(s.get("color", ""))):
			bad.append("villagers.json: the service person of %s needs a class and race with art and a colour" % k)
	# every service building of the towns has its person, and no one lives in a building too small to stand in
	for b in GameTown.all():
		var kind := str(b["kind"])
		if kind != "family" and kind != "board" and kind != "house" and not d["service"].has(kind):
			bad.append("villagers.json: the %s has no person" % kind)
		if kind == "house" and residents(b).is_empty():
			bad.append("villagers.json: a house with no residents")
	return bad
