## Travel between the towns of the open world and the map pin (data/world/worldmap.json `travel` and `settings.pin_*`; the world map panel
## draws it, the sandbox calls it). A town or a city is a place with a town's ground (GameTown.towns); everyone knows them. The family can
## PIN one (or a bare point of the map): `GameDynasty.map_pin`, {place: id} or {x, z, name}, saved only when set, cleared when the heir comes
## within `pin_clear_tiles` of the place's anchor or by unpinning, and the minimap points at it (GameMiniMap.pin_bearing). The family can WALK
## there (the pin, and a route in legs of `leg_tiles`, which GameSandbox.walk_one carries on; a gate shut for the night stops the walk
## outside the wall) or BOOK travel for gold from a town's ground: the fare takes gold and world-clock time and the heir stands just inside
## the gate nearest where they set out. Pure of the dynasty's dice: nothing here draws one, and nothing is saved but the pin.
class_name GameTravel
extends RefCounted

const NONE := Vector2i(-1, -1)


static func setting(key: String) -> Variant:
	return GameWorldMap.data()["travel"][key]


static func pin_setting(key: String) -> Variant:
	return GameWorldMap.data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return GameWorldMap.text(key, vals)


# ---------------------------------------------------------------- the towns

## The towns and cities, in the order of the world's data.
static func towns() -> Array:
	return GameTown.towns()


static func is_town(id: String) -> bool:
	return id in towns()


static func is_city(id: String) -> bool:
	return is_town(id) and id in GameWorldMap.data()["cities"]


static func name_of(id: String) -> String:
	return str(GameWorld.place(id).get("name", id))


## The tile of a place's anchor (NONE for an unknown place).
static func anchor_tile(id: String) -> Vector2i:
	var a := GameWorldGen.anchor(id)
	return NONE if a.is_empty() else Vector2i(int(a["x"]), int(a["z"]))


## The compass point (a name of `compass`, east first, clockwise, z south) of `to` seen from `from`.
static func compass(from: Vector2i, to: Vector2i) -> String:
	var names: Array = GameWorldMap.data()["compass"]
	var v := Vector2(to - from)
	if v.length() < 0.5:
		return str(names[0])
	var sector := int(round(atan2(v.y, v.x) / (TAU / float(names.size()))))
	return str(names[posmod(sector, names.size())])


## Whole tiles as the crow flies.
static func tiles(a: Vector2i, b: Vector2i) -> int:
	return GameSpaces.tiles_between(a, b)


## The town whose ground a tile stands on ("" for none).
static func town_at(x: int, z: int) -> String:
	var s := GameSpaces.space(GameSpaces.at_tile(x, z))
	if s.is_empty() or str(s["kind"]) != "area":
		return ""
	var place := str(s.get("place", ""))
	return place if is_town(place) else ""


## What the world map says of a town from where the heir stands: {id, name, city, kind, tiles, dir, fare, here, x, z}.
static func card(d: GameDynasty, from: Vector2i, id: String) -> Dictionary:
	if not is_town(id):
		return {}
	var at := anchor_tile(id)
	return {"id": id, "name": name_of(id), "city": is_city(id), "kind": text("kind_city" if is_city(id) else "kind_town"),
		"tiles": tiles(from, at), "dir": compass(from, at), "fare": fare(d, from, id), "here": town_at(from.x, from.y) == id, "x": at.x, "z": at.y}


# ---------------------------------------------------------------- the fare

## The gold a coach to a town costs from where the heir stands: the tiles times the rate, at least the minimum, times the shop price
## multiplier (so the town's faction standing, haggling and the generation's scale count as they do at a shop).
static func fare(d: GameDynasty, from: Vector2i, id: String) -> int:
	var n := tiles(from, anchor_tile(id))
	var base := maxi(int(setting("min_fee")), int(ceil(float(n) * float(setting("gold_per_tile")))))
	return maxi(1, int(round(float(base) * GameItems.price_mult(d))))


## The seconds of the world clock a coach to a town takes.
static func seconds(from: Vector2i, id: String) -> float:
	return float(tiles(from, anchor_tile(id))) * float(setting("seconds_per_tile"))


## Why travel cannot be booked to a town from here ("" when it can).
static func refusal(sb: GameSandbox, id: String) -> String:
	var d := sb.d
	var v := {"heir": d.heir.name}
	if not is_town(id):
		return text("book_no_town", v)
	v["name"] = name_of(id)
	if d.battle != null:
		return text("book_fight", v)
	if sb.space != "world":
		return text("book_indoors", v)
	if sb.heir_y != GameBuild.SURFACE:
		return text("book_upstairs", v)
	if not GameClock.running(d):
		return text("book_busy", v)
	var here := town_at(sb.heir.x, sb.heir.y)
	if here == "":
		return text("book_not_town", v)
	if here == id:
		return text("book_same", v)
	var gold := fare(d, sb.heir, id)
	if d.heir.gold < gold:
		v["gold"] = gold
		v["have"] = d.heir.gold
		return text("book_poor", v)
	return ""


## The tile the heir stands on when a coach sets them down at a town: `arrive_in_tiles` inside the gate nearest where they set out
## (so no wall is crossed). A town with no gate puts them at its anchor.
static func arrival_tile(from: Vector2i, id: String) -> Vector2i:
	var best := {}
	var best_d := INF
	for g in GameWalls.gates(id):
		var dist := Vector2(from - (g["centre"] as Vector2i)).length()
		if dist < best_d:
			best_d = dist
			best = g
	if best.is_empty():
		return anchor_tile(id)
	return (best["inner"] as Vector2i) - (best["dir"] as Vector2i) * (int(setting("arrive_in_tiles")) - 1)


## Books the coach: {ok, text}. The fare comes out of the heir's gold, the clock runs `seconds` (ages and weather move on) and the heir
## is set down at the town's gate with the party beside them; the creatures of the old place are left behind and the town becomes the
## family's place. A pin on the town comes off.
static func book(sb: GameSandbox, id: String) -> Dictionary:
	var why := refusal(sb, id)
	if why != "":
		return {"ok": false, "text": why}
	var d := sb.d
	var gold := fare(d, sb.heir, id)
	var n := tiles(sb.heir, anchor_tile(id))
	var origin := name_of(town_at(sb.heir.x, sb.heir.y))
	var to := arrival_tile(sb.heir, id)
	d.heir.gold -= gold
	var msgs: Array = []
	GameClock.feed(d, seconds(sb.heir, id), msgs)
	for m in msgs:
		sb.log.append({"kind": "travel", "text": str(m.get("text", m)) if m is Dictionary else str(m)})
	if d.state == "life":
		sb.cancel_walk()
		sb.heir = to
		sb.creatures = []
		sb.armed = {}
		sb.companions = GameCompanions.agents_for(d, float(to.x) + 0.5, float(to.y) + 0.5)
		sb._arrive()
		sb.refresh()
	if pin_place(d) == id:
		clear_pin(d)
	var line := text("booked", {"heir": d.heir.name, "from": origin, "name": name_of(id), "gold": gold, "tiles": n})
	sb.log.append({"kind": "travel", "text": line})
	return {"ok": true, "text": line}


# ---------------------------------------------------------------- walking

## Pins a town and starts the heir walking there: {ok, text}. `ok` is whether a walk began; the pin is set either way (a way may be
## found later). The walk goes in legs (the route search is bounded): GameSandbox.walk_one asks `plan_next` for each in turn.
static func walk(sb: GameSandbox, id: String) -> Dictionary:
	if not is_town(id):
		return {"ok": false, "text": text("pin_bad")}
	var d := sb.d
	set_pin(d, id)
	var at := anchor_tile(id)
	var v := {"heir": d.heir.name, "name": name_of(id), "tiles": tiles(sb.heir, at), "dir": compass(sb.heir, at)}
	if sb.space != "world" or sb.heir_y != GameBuild.SURFACE:
		v["why"] = text("book_indoors" if sb.space != "world" else "book_upstairs", v)
		return {"ok": false, "text": text("walk_pinned_only", v)}
	sb.route = []
	sb.walk_goal = at
	sb.walk_place = id
	sb.walk_replans = 0
	var line := text("walk_start", v)
	sb.log.append({"kind": "travel", "text": line})
	if not plan_next(sb):
		var last := str(sb.log[sb.log.size() - 1]["text"])
		return {"ok": false, "text": last if last != line else text("walk_stalled", v)}
	return {"ok": true, "text": line}


## Where a walk stops: the goal, or (with the gates shut and the heir outside the wall) the tile in front of the nearest gate.
static func walk_stop(sb: GameSandbox) -> Vector2i:
	var goal: Vector2i = sb.walk_goal
	var place := sb.walk_place
	if goal == NONE or place == "" or not GameWalls.shut_now(sb.d):
		return goal
	if Vector2(sb.heir - goal).length() <= GameWalls.radius(place):
		return goal   # already inside
	var best := goal
	var best_d := INF
	for g in GameWalls.gates(place):
		var dist := Vector2(sb.heir - (g["outer"] as Vector2i)).length()
		if dist < best_d:
			best_d = dist
			best = g["outer"]
	return best


## Plans the next leg of the walk (sb.walk_goal) into sb.route. False when there is no next leg: the walk has ended (arrived, stopped at a
## shut gate, or no way found), with a line in the log, and the goal is cleared.
static func plan_next(sb: GameSandbox) -> bool:
	if sb.walk_goal == NONE:
		return false
	var d := sb.d
	var v := {"heir": d.heir.name, "name": name_of(sb.walk_place)}
	var stop := walk_stop(sb)
	if sb.heir == stop or Vector2(sb.heir - sb.walk_goal).length() <= 1.5:
		var shut := stop != sb.walk_goal
		sb.log.append({"kind": "travel", "text": text("walk_shut" if shut else "walk_arrived", v)})
		sb.cancel_walk()
		return false
	var ground := GamePath.world_ground(d)
	var total := Vector2(stop - sb.heir).length()
	var leg := float(setting("leg_tiles"))
	var step := leg if total > leg else maxf(4.0, total * 0.6)
	var aim := Vector2(stop - sb.heir).normalized()
	var cands: Array = []
	if total <= leg:
		cands.append(stop)
	var tries := int(setting("leg_tries"))
	for i in tries:
		var k := (i + 1) / 2 * (1 if i % 2 == 0 else -1)
		var dir := aim.rotated(deg_to_rad(float(setting("leg_turn_deg")) * float(k)))
		var t := Vector2i(roundi(float(sb.heir.x) + dir.x * step), roundi(float(sb.heir.y) + dir.y * step))
		t = _snap(ground, t)
		if t != NONE and t != sb.heir and Vector2(stop - t).length() <= total - float(setting("leg_min_gain")):
			cands.append(t)
	for t in cands:
		var found := GamePath.find(ground, Vector3i(sb.heir.x, -1, sb.heir.y), Vector3i(t.x, -1, t.y), "walker", int(GameSandbox.setting("route_nodes")))
		if not found["found"]:
			continue
		var path: Array = found["path"]
		sb.route = []
		for i in range(1, path.size()):
			sb.route.append(Vector2i(path[i].x, path[i].z))
		if not sb.route.is_empty():
			return true
	sb.log.append({"kind": "travel", "text": text("walk_stalled", v)})
	sb.cancel_walk()
	return false


## The nearest walkable tile to `t` (within `snap_tiles`), or NONE.
static func _snap(ground: Dictionary, t: Vector2i) -> Vector2i:
	var mover := {"water": false, "ignore_blocks": false}
	for r in range(0, int(setting("snap_tiles")) + 1):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var c := t + Vector2i(dx, dz)
				if GameWorldGen.in_bounds(c.x, c.y) and GamePath.passable(ground, Vector3i(c.x, -1, c.y), mover):
					return c
	return NONE


## The walk was stopped where it stood (the way was blocked, a gate shut): plan it again a few times, else give it up.
static func stalled(sb: GameSandbox) -> bool:
	if sb.walk_goal == NONE:
		return false
	sb.walk_replans += 1
	if sb.walk_replans > int(setting("replans")):
		sb.log.append({"kind": "travel", "text": text("walk_stalled", {"heir": sb.d.heir.name, "name": name_of(sb.walk_place)})})
		sb.cancel_walk()
		return false
	return plan_next(sb)


# ---------------------------------------------------------------- the pin

## A saved pin, checked: {place: id} for a place of the map, or {x, z, name} for a tile of the world. Anything else is {}.
static func clean_pin(v: Variant) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	var p: Dictionary = v
	if p.has("place"):
		if typeof(p["place"]) == TYPE_STRING and not GameWorldGen.anchor(str(p["place"])).is_empty():
			return {"place": str(p["place"])}
		return {}
	if p.has("x") and p.has("z"):
		for k in ["x", "z"]:
			if typeof(p[k]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(p[k])):
				return {}
		var x := int(p["x"])
		var z := int(p["z"])
		if not GameWorldGen.in_bounds(x, z):
			return {}
		var nm := str(p.get("name", "")) if typeof(p.get("name", "")) == TYPE_STRING else ""
		return {"x": x, "z": z, "name": nm.substr(0, int(pin_setting("pin_name_max")))}
	return {}


static func has_pin(d: GameDynasty) -> bool:
	return not d.map_pin.is_empty()


static func pin_place(d: GameDynasty) -> String:
	return str(d.map_pin.get("place", ""))


## The pinned tile: a place's anchor, or the point (NONE for no pin).
static func pin_tile(d: GameDynasty) -> Vector2i:
	if d.map_pin.has("place"):
		return anchor_tile(str(d.map_pin["place"]))
	if d.map_pin.has("x"):
		return Vector2i(int(d.map_pin["x"]), int(d.map_pin["z"]))
	return NONE


static func pin_name(d: GameDynasty) -> String:
	if d.map_pin.has("place"):
		return name_of(str(d.map_pin["place"]))
	return str(d.map_pin.get("name", ""))


## Pins a place of the map: false (and nothing changes) for one that is not on it.
static func set_pin(d: GameDynasty, id: String) -> bool:
	var p := clean_pin({"place": id})
	if p.is_empty():
		return false
	d.map_pin = p
	return true


static func set_pin_point(d: GameDynasty, x: int, z: int, nm: String = "") -> bool:
	var p := clean_pin({"x": x, "z": z, "name": nm})
	if p.is_empty():
		return false
	d.map_pin = p
	return true


static func clear_pin(d: GameDynasty) -> void:
	d.map_pin = {}


## The line that says where the pin is from a tile: "Pin: Kingshold, 212 tiles NE" ("" for no pin).
static func pin_line(d: GameDynasty, from: Vector2i) -> String:
	if d.map_pin.is_empty():
		return ""
	var at := pin_tile(d)
	var n := tiles(from, at)
	var nm := pin_name(d)
	if nm == "":
		nm = "%d, %d" % [at.x, at.y]
	if n <= 0:
		return text("pin_here", {"name": nm})
	return text("pin_line", {"name": nm, "tiles": n, "dir": compass(from, at)})


## The heir has taken a step: a pin they have come to comes off.
static func after_step(sb: GameSandbox) -> void:
	var d := sb.d
	if d.map_pin.is_empty() or sb.space != "world":
		return
	var at := pin_tile(d)
	var reach := float(pin_setting("pin_clear_tiles") if d.map_pin.has("place") else pin_setting("pin_clear_point_tiles"))
	if Vector2(sb.heir - at).length() <= reach:
		var nm := pin_name(d)
		clear_pin(d)
		sb.log.append({"kind": "travel", "text": text("pin_cleared", {"heir": d.heir.name, "name": nm})})


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat := GameWorldMap.data()
	for k in ["cities", "compass", "travel"]:
		if not dat.has(k):
			bad.append("worldmap.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var t: Dictionary = dat["travel"]
	for k in ["min_fee", "gold_per_tile", "seconds_per_tile", "arrive_in_tiles", "leg_tiles", "leg_tries", "leg_turn_deg", "leg_min_gain", "snap_tiles", "replans"]:
		if not t.has(k) or typeof(t[k]) not in [TYPE_INT, TYPE_FLOAT]:
			bad.append("worldmap.json: travel.%s is missing" % k)
	for k in ["pin_clear_tiles", "pin_clear_point_tiles", "pin_name_max"]:
		if not dat["settings"].has(k) or int(dat["settings"][k]) < 1:
			bad.append("worldmap.json: settings.%s must be at least 1" % k)
	if not bad.is_empty():
		return bad
	if int(t["min_fee"]) < 1 or float(t["gold_per_tile"]) <= 0.0 or float(t["seconds_per_tile"]) < 0.0:
		bad.append("worldmap.json: travel needs a fee of at least 1, gold a tile above 0 and seconds a tile of 0 or more")
	if int(t["arrive_in_tiles"]) < 2 or int(t["leg_tiles"]) < 8 or int(t["leg_tries"]) < 1 or int(t["snap_tiles"]) < 0 or int(t["replans"]) < 0:
		bad.append("worldmap.json: travel arrives at least 2 tiles inside, walks legs of at least 8 tiles and tries at least once")
	if float(t["leg_min_gain"]) <= 0.0 or float(t["leg_min_gain"]) >= float(t["leg_tiles"]):
		bad.append("worldmap.json: travel.leg_min_gain must be above 0 and under the leg")
	if (dat["compass"] as Array).size() != 8:
		bad.append("worldmap.json: the compass has eight points")
	for c in dat["cities"]:
		if not is_town(str(c)):
			bad.append("worldmap.json: the city '%s' is not a town" % c)
	var longest := 0.0
	for place in GameWalls.walled():
		longest = maxf(longest, GameWalls.radius(place))
	if float(dat["settings"]["pin_clear_tiles"]) < longest + 2.0:
		bad.append("worldmap.json: pin_clear_tiles must reach the gate of a walled town (%.0f tiles from its anchor) and a tile past it" % longest)
	for place in towns():
		if GameWalls.gates(place).is_empty() and not GameWalls.walled().has(place):
			continue
		if arrival_tile(Vector2i(0, 0), place) == NONE:
			bad.append("worldmap.json: no arrival tile for %s" % place)
	for k in ["unknown", "kind_town", "kind_city", "card_title", "card_distance", "card_here", "card_fare", "card_none", "btn_pin", "btn_unpin", "btn_walk", "btn_book",
			"pin_line", "pin_here", "pin_under", "pin_set", "pin_removed", "pin_cleared", "pin_bad", "walk_start", "walk_pinned_only", "walk_shut", "walk_arrived",
			"walk_stalled", "book_no_town", "book_not_town", "book_indoors", "book_upstairs", "book_fight", "book_busy", "book_same", "book_poor", "booked"]:
		if str(dat["text"].get(k, "")) == "":
			bad.append("worldmap.json: text.%s is missing" % k)
	return bad
