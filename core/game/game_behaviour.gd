## Creature behaviour as data (roadmap item 48). A creature in the open world needs no code of its own: it has tags
## (data/creatures/behaviour.json), each tag sets some of the parameters, and `step_all` is one small state machine that
## reads them. Modes: idle and wander (a random walk held to `wander_radius` of home), chase (hostile and it sees a target;
## a leash or a guard's radius ends it and it returns home), flee (hurt below `flee_hp`, or skittish and something is close,
## until it is `flee_dist` away), herd (kept within `herd_radius` of its kind's centre), ambush (still until a target is
## within `ambush_range`, then a burst) and the pack: a `swarm` creature that sees a target alerts its kind within
## `alert_radius`, and the pack spreads round the target rather than queueing. Ground creatures are held off ground the
## caller says they cannot walk on; fliers are not. Pure functions: every die is keyed on the seed, the creature and the
## tick, never the dynasty's; nothing is saved; the autopilot never asks.
class_name GameBehaviour
extends RefCounted

const PATH := "res://data/creatures/behaviour.json"
const MODES := ["idle", "wander", "chase", "flee", "return", "herd", "dead"]

static var _cache: Dictionary = {}
static var _params: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
		_params = {}
	return _cache


static func _def(id: String) -> Dictionary:
	GameData.load_all()
	for c in GameData.creatures:
		if c["id"] == id:
			return c
	return {}


## Whether a creature is a pack animal: its `swarm` in creatures.json.
static func is_pack(id: String) -> bool:
	return bool(_def(id).get("swarm", false))


## A creature's tags: those listed for it, in the global order, and "pack" if it swarms.
static func tags_of(id: String) -> Array:
	var listed: Array = data()["creatures"].get(id, [])
	var out: Array = []
	for t in data()["order"]:
		if t in listed:
			out.append(t)
	if is_pack(id):
		out.append("pack")
	return out


## A creature's parameters: the defaults, then each of its tags' settings in the global order (a later tag wins).
static func params(id: String) -> Dictionary:
	data()
	if _params.has(id):
		return _params[id]
	var p: Dictionary = data()["defaults"].duplicate(true)
	var listed: Array = data()["creatures"].get(id, [])
	for t in data()["order"]:
		if t in listed:
			for k in data()["tags"][t]["set"]:
				p[k] = data()["tags"][t]["set"][k]
	_params[id] = p
	return p


## A new creature in the world: where it is, where its home is, how hurt it is (1.0 whole).
static func new_agent(uid: int, id: String, x: float, z: float, hp: float = 1.0) -> Dictionary:
	return {"uid": uid, "id": id, "x": x, "z": z, "home_x": x, "home_z": z, "hp": hp, "mode": "idle", "target": {}, "heading": 0.0, "burst": 0}


static func _u(seed_value: int, uid: int, tick: int, tag: String) -> float:
	return float(absi(hash([seed_value, "behave", uid, tick, tag])) % 1000003) / 1000003.0


static func _pos(a: Dictionary) -> Vector2:
	return Vector2(float(a["x"]), float(a["z"]))


static func _home(a: Dictionary) -> Vector2:
	return Vector2(float(a["home_x"]), float(a["home_z"]))


## The nearest of `targets` ([{x, z}]) within `reach` of a point: {x, z} or {}.
static func _nearest(from: Vector2, targets: Array, reach: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d := reach
	for t in targets:
		var d := from.distance_to(Vector2(float(t["x"]), float(t["z"])))
		if d <= best_d:
			best_d = d
			best = {"x": float(t["x"]), "z": float(t["z"])}
	return best


## How far a creature sees now: its sight, by day or by night.
static func sight_now(id: String, night: bool) -> float:
	var p := params(id)
	return float(p["sight"]) * float(p["sight_night"] if night else p["sight_day"])


## One tick for every creature in `agents`, returning the new agents (the old ones are not changed).
## `view`: {targets: [{x, z}] (what they hunt or fear), night: bool, walkable: Callable(x, z) -> bool (optional), sight_mult: float (optional, 1), router: Callable (optional)}.
static func step_all(agents: Array, view: Dictionary, seed_value: int, tick: int) -> Array:
	var targets: Array = view.get("targets", [])
	var night := bool(view.get("night", false))
	var sight_scale := float(view.get("sight_mult", 1.0))   # the weather's, from GameDay.view: fog and storms shorten every creature's sight
	var n := agents.size()
	var ps: Array = []
	var seen: Array = []
	for a in agents:
		ps.append(params(str(a["id"])))
	# what each one sees: a hunter keeps a target it had out to a longer reach; an ambusher stirs only when one is close
	for i in n:
		var a: Dictionary = agents[i]
		var p: Dictionary = ps[i]
		var prev := str(a["mode"])
		var reach := sight_now(str(a["id"]), night) * sight_scale * (float(p["lose_sight_mult"]) if prev in ["chase", "flee"] else 1.0)
		if prev == "flee":
			reach = maxf(reach, float(p["flee_dist"]))
		if float(p["ambush_range"]) > 0.0 and prev != "chase" and prev != "flee":
			reach = minf(reach, float(p["ambush_range"]))
		seen.append(_nearest(_pos(a), targets, reach))
	# the pack: one that sees a target tells its kind within the alert radius
	var told: Array = seen.duplicate()
	for i in n:
		if not seen[i].is_empty() or not is_pack(str(agents[i]["id"])):
			continue
		var best_d := float(ps[i]["alert_radius"])
		for j in n:
			if j == i or seen[j].is_empty() or agents[j]["id"] != agents[i]["id"]:
				continue
			var d := _pos(agents[i]).distance_to(_pos(agents[j]))
			if d <= best_d:
				best_d = d
				told[i] = seen[j]
	# herds: the centre of each kind that keeps together
	var centres := {}
	var counts := {}
	for i in n:
		if float(ps[i]["herd_radius"]) > 0.0 and str(agents[i]["mode"]) != "dead":
			var k := str(agents[i]["id"])
			centres[k] = Vector2(centres.get(k, Vector2.ZERO)) + _pos(agents[i])
			counts[k] = int(counts.get(k, 0)) + 1
	for k in centres:
		centres[k] = Vector2(centres[k]) / float(counts[k])
	# a pack that has a target spreads round it: each member takes its own side
	var chasers: Dictionary = {}
	for i in n:
		if not told[i].is_empty() and is_pack(str(agents[i]["id"])):
			var k2 := str(agents[i]["id"])
			chasers[k2] = chasers.get(k2, {"uids": [], "centre": Vector2.ZERO})
			chasers[k2]["uids"].append(int(agents[i]["uid"]))
			chasers[k2]["centre"] = Vector2(chasers[k2]["centre"]) + _pos(agents[i])
	for k in chasers:
		chasers[k]["uids"].sort()
		chasers[k]["centre"] = Vector2(chasers[k]["centre"]) / float(chasers[k]["uids"].size())
	var out: Array = []
	for i in n:
		var herd_centre: Variant = centres.get(str(agents[i]["id"]), null)
		out.append(_act(agents[i], ps[i], told[i], herd_centre, chasers.get(str(agents[i]["id"]), {}), view, seed_value, tick))
	return out


static func _act(a: Dictionary, p: Dictionary, threat: Dictionary, herd_centre: Variant, flank_group: Dictionary, view: Dictionary, seed_value: int, tick: int) -> Dictionary:
	var next: Dictionary = a.duplicate(true)
	if float(a["hp"]) <= 0.0:
		next["mode"] = "dead"
		next["target"] = {}
		return next
	var pos := _pos(a)
	var home := _home(a)
	var prev := str(a["mode"])
	var home_d := pos.distance_to(home)
	var uid := int(a["uid"])
	var mode := "wander"
	var goal := pos
	var speed := float(p["speed"])
	var hostile: bool = bool(p["hostile"])
	var scared: bool = float(a["hp"]) < float(p["flee_hp"]) or bool(p["skittish"])
	var leash := float(p["leash"])
	var burst := int(a["burst"])
	var chasing := false
	if not threat.is_empty() and scared:
		mode = "flee"
	elif not threat.is_empty() and hostile:
		var tpos := Vector2(float(threat["x"]), float(threat["z"]))
		var in_post := float(p["guard_radius"]) <= 0.0 or tpos.distance_to(home) <= float(p["guard_radius"])
		var held := leash > 0.0 and (home_d > leash or (prev == "return" and home_d > leash * 0.5))
		if in_post and not held:
			mode = "chase"
			chasing = true
		elif held:
			mode = "return"
	if mode == "wander":
		if prev == "return" and leash > 0.0 and home_d > leash * 0.5:
			mode = "return"
		elif prev == "return" and home_d > 1.5:
			mode = "return"
		elif herd_centre != null and float(p["herd_radius"]) > 0.0 and pos.distance_to(Vector2(herd_centre)) > float(p["herd_radius"]):
			mode = "herd"
		elif home_d > float(p["wander_radius"]) * 1.5:
			mode = "return"
	# the move
	var heading := float(a["heading"])
	var step_len := 0.0
	var dir := Vector2.ZERO
	match mode:
		"chase":
			var tp := Vector2(float(threat["x"]), float(threat["z"]))
			var aim := tp
			var flankers: Array = flank_group.get("uids", [])
			var k := flankers.find(uid)
			var dist_t := pos.distance_to(tp)
			if k >= 0 and flankers.size() > 1 and dist_t > float(p["flank"]):
				# take a bearing to one side of the pack's approach and circle in at it
				var base := (Vector2(flank_group["centre"]) - tp).angle()
				var angle := base + (float(k) / float(flankers.size() - 1) - 0.5) * float(p["flank_spread"])
				aim = tp + Vector2.from_angle(angle) * maxf(float(p["flank"]), dist_t * float(p["flank_close"]))
			if float(p["ambush_range"]) > 0.0 and prev != "chase":
				burst = int(p["ambush_ticks"])
			dir = _route(view, pos, aim) - pos
			step_len = speed
			if float(a["hp"]) < float(p["rage_hp"]):
				step_len *= float(p["rage_speed"])
			if burst > 0:
				step_len *= float(p["ambush_speed_mult"])
				burst -= 1
			step_len = minf(step_len, maxf(0.0, pos.distance_to(aim)))
		"flee":
			var away := pos - Vector2(float(threat["x"]), float(threat["z"]))
			if away.length() < 0.001:
				away = Vector2.from_angle(_u(seed_value, uid, tick, "away") * TAU)
			dir = away
			step_len = speed * 1.1
		"return":
			dir = _route(view, pos, home) - pos
			step_len = minf(speed, home_d)
		"herd":
			dir = _route(view, pos, Vector2(herd_centre)) - pos
			step_len = minf(speed * 0.7, pos.distance_to(Vector2(herd_centre)))
		_:
			if _u(seed_value, uid, tick, "idle") < float(p["idle_chance"]):
				mode = "idle"
			else:
				heading += (_u(seed_value, uid, tick, "turn") - 0.5) * float(p["turn"]) * PI
				if home_d > float(p["wander_radius"]):
					var back := (home - pos).angle()
					heading = lerp_angle(heading, back, 0.7)
				dir = Vector2.from_angle(heading)
				step_len = speed * 0.5
	if dir.length() > 0.0001 and step_len > 0.0:
		var moved := _move(pos, dir.normalized(), step_len, bool(p["flier"]), view.get("walkable", Callable()))
		if moved == pos and mode == "wander":
			heading += PI * 0.5   # blocked: turn
		pos = moved
	next["x"] = pos.x
	next["z"] = pos.y
	next["mode"] = mode
	next["target"] = threat if mode in ["chase", "flee"] else {}
	next["heading"] = heading
	next["burst"] = burst
	return next


## Where to head to get to `aim`: itself, or, when the caller gives a `router` (see GamePath.router), the next waypoint on a
## route that goes round what is in the way. A flier never needs one.
static func _route(view: Dictionary, pos: Vector2, aim: Vector2) -> Vector2:
	var router: Variant = view.get("router", null)
	if router is Callable and (router as Callable).is_valid():
		return (router as Callable).call(pos, aim)
	return aim


## One step of `dist` along `dir`, held off ground that cannot be walked: if it is blocked, try each axis alone.
static func _move(pos: Vector2, dir: Vector2, dist: float, flier: bool, walkable: Variant) -> Vector2:
	var cand := pos + dir * dist
	if flier or not (walkable is Callable) or not (walkable as Callable).is_valid():
		return cand
	var w: Callable = walkable
	if w.call(cand.x, cand.y):
		return cand
	var ax := Vector2(pos.x + dir.x * dist, pos.y)
	var az := Vector2(pos.x, pos.y + dir.y * dist)
	if absf(dir.x) >= absf(dir.y):
		if w.call(ax.x, ax.y):
			return ax
		if w.call(az.x, az.y):
			return az
	else:
		if w.call(az.x, az.y):
			return az
		if w.call(ax.x, ax.y):
			return ax
	return pos


## A view of the generated world for a dynasty: ground creatures keep off open water and out of the sea.
static func world_view(d: GameDynasty, targets: Array, night: bool = false) -> Dictionary:
	return {"targets": targets, "night": night, "walkable": func(x: float, z: float) -> bool:
		var t := GameWorldGen.tile(d, int(floor(x)), int(floor(z)))
		return not t["water"]}


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = data()
	for k in ["defaults", "tags", "order", "creatures"]:
		if not dat.has(k):
			bad.append("behaviour.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var defaults: Dictionary = dat["defaults"]
	for k in defaults:
		var v: Variant = defaults[k]
		if typeof(v) in [TYPE_INT, TYPE_FLOAT] and float(v) < 0.0:
			bad.append("behaviour.json: the default %s is negative" % k)
	for k in ["sight", "speed", "wander_radius", "flee_dist", "lose_sight_mult", "alert_radius", "flank", "flank_spread", "flank_close"]:
		if float(defaults.get(k, 0.0)) <= 0.0:
			bad.append("behaviour.json: the default %s must be above 0" % k)
	if float(defaults.get("idle_chance", -1.0)) < 0.0 or float(defaults.get("idle_chance", 2.0)) > 1.0:
		bad.append("behaviour.json: the default idle_chance must be from 0 to 1")
	var order: Array = dat["order"]
	for t in dat["tags"]:
		if t not in order:
			bad.append("behaviour.json: the tag '%s' is not in order" % t)
		var def: Dictionary = dat["tags"][t]
		if str(def.get("about", "")) == "" or not (def.get("set") is Dictionary) or def["set"].is_empty():
			bad.append("behaviour.json: the tag '%s' needs an about and something to set" % t)
			continue
		for k in def["set"]:
			if not defaults.has(k):
				bad.append("behaviour.json: the tag '%s' sets the unknown parameter '%s'" % [t, k])
			elif typeof(def["set"][k]) != typeof(defaults[k]) and not (typeof(def["set"][k]) in [TYPE_INT, TYPE_FLOAT] and typeof(defaults[k]) in [TYPE_INT, TYPE_FLOAT]):
				bad.append("behaviour.json: the tag '%s' sets %s to the wrong kind of value" % [t, k])
	for t in order:
		if not dat["tags"].has(t):
			bad.append("behaviour.json: order names the unknown tag '%s'" % t)
	if order.size() != dat["tags"].size():
		bad.append("behaviour.json: order must list every tag once")
	GameData.load_all()
	var used := {}
	var ids := {}
	for c in GameData.creatures:
		ids[str(c["id"])] = c
		if not dat["creatures"].has(str(c["id"])):
			bad.append("behaviour.json: the creature '%s' has no tags" % c["id"])
	for id in dat["creatures"]:
		if not ids.has(id):
			bad.append("behaviour.json: '%s' is not a creature" % id)
			continue
		for t in dat["creatures"][id]:
			used[t] = true
			if t == "pack":
				bad.append("behaviour.json: '%s' lists pack, which comes from its swarm in creatures.json" % id)
			elif not dat["tags"].has(t):
				bad.append("behaviour.json: '%s' has the unknown tag '%s'" % [id, t])
		var p := params(id)
		if float(p["sight"]) <= 0.0 or float(p["speed"]) <= 0.0 or float(p["wander_radius"]) <= 0.0:
			bad.append("behaviour.json: '%s' ends up with no sight, speed or wander radius" % id)
		if float(p["flee_hp"]) < 0.0 or float(p["flee_hp"]) > 1.0 or float(p["idle_chance"]) < 0.0 or float(p["idle_chance"]) > 1.0:
			bad.append("behaviour.json: '%s' has a flee_hp or idle_chance outside 0 to 1" % id)
		if float(p["leash"]) > 0.0 and float(p["guard_radius"]) > float(p["leash"]):
			bad.append("behaviour.json: '%s' guards further out than its leash lets it go" % id)
		if not bool(p["hostile"]) and not (ids[id].get("farm", false)):
			bad.append("behaviour.json: the wild creature '%s' is never hostile" % id)
	for t in dat["tags"]:
		if not used.has(t):
			bad.append("behaviour.json: no creature has the tag '%s'" % t)
	return bad
