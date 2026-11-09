## Companions in the open world (roadmap item 52), built on the party rules (GameParty). A hired companion is given an
## order: follow (keep close to the heir), stay (hold where they stand), gather (work the nodes round where they stand,
## into the family's stores) or guard (hold a post and go out to meet a threat that comes near it). The order is saved on
## the party member, only once it is not follow (`GameParty` keeps it, an unknown one loads as follow); where they stand
## is not saved, a sandbox puts them beside the heir (`agents_for`). `step_all` is one state machine over their agents,
## moving them by the router and ground rules creatures use (GameBehaviour, GamePath). Gathering takes a node's material
## (shared by the companion's class, data/companions/world.json `classes`) into `GameDynasty.stores` and marks the node
## in `GameDynasty.gathered` (saved only when not empty) until `regrow_years` of the world's calendar have passed.
## Guards do not fight: one that sees a threat near its post goes out to meet it and says so (an `alert` event).
## Nothing here is random, and the autopilot (which never steps companions or gives orders) is unaffected.
class_name GameCompanions
extends RefCounted

const PATH := "res://data/companions/world.json"
const FOLLOW := "follow"
const ORDERS := ["follow", "stay", "gather", "guard"]
const GOLDEN := 2.399963   # radians: spreads followers round the heir

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


# ---------------------------------------------------------------- orders

## A companion's order: follow unless one was given.
static func order_of(d: GameDynasty, id: String) -> String:
	var m := d.party.member(id)
	var o := str(m.get("order", FOLLOW)) if not m.is_empty() else FOLLOW
	return o if ORDERS.has(o) else FOLLOW


static func order_name(order: String) -> String:
	return str(data()["orders"].get(order, order))


## Gives an order to a companion in the party: {ok, text}. Follow clears it (a party member saves no order then).
static func set_order(d: GameDynasty, id: String, order: String) -> Dictionary:
	if not d.party.has_member(id):
		return {"ok": false, "text": text("not_in_party", {"id": id})}
	if not ORDERS.has(order):
		return {"ok": false, "text": text("unknown_order", {"order": order})}
	var m := d.party.member(id)
	if order == FOLLOW:
		m.erase("order")
	else:
		m["order"] = order
	return {"ok": true, "text": text("set", {"name": str(m["name"]), "order": order_name(order).to_lower()})}


static func describe(d: GameDynasty) -> String:
	if d.party.members.is_empty():
		return text("summary_none")
	var lines: Array = []
	for m in d.party.members:
		lines.append(text("line", {"name": str(m["name"]), "order": order_name(order_of(d, str(m["id"])))}))
	return "\n".join(lines)


## A saved order, checked: a known one other than follow, or "" (nothing to keep).
static func load_order(v: Variant) -> String:
	if typeof(v) == TYPE_STRING and ORDERS.has(str(v)) and str(v) != FOLLOW:
		return str(v)
	return ""


## How much better or worse a companion's class is at a kind of work: `gather` or `guard` (1 when not listed).
static func class_mult(id: String, kind: String) -> float:
	var cls := str(GameParty.def(id).get("class", ""))
	var table: Dictionary = data()["classes"]
	var entry: Dictionary = table.get(cls, table["default"])
	return float(entry.get(kind, 1.0))


# ---------------------------------------------------------------- gathered nodes

static func node_key(x: int, z: int) -> String:
	return "%d,%d" % [x, z]


## Whether a node was gathered less than `regrow_years` ago.
static func depleted(d: GameDynasty, x: int, z: int) -> bool:
	var k := node_key(x, z)
	return d.gathered.has(k) and float(d.world.year) - float(d.gathered[k]) < float(setting("regrow_years"))


## The saved gathered nodes, checked: "x,z" keys with a finite number for the year, else dropped.
static func load_gathered(v: Variant) -> Dictionary:
	var out := {}
	if typeof(v) != TYPE_DICTIONARY:
		return out
	var re := RegEx.new()
	re.compile("^-?\\d+,-?\\d+$")
	for k in v:
		if re.search(str(k)) != null and typeof(v[k]) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v[k])):
			out[str(k)] = float(v[k])
	return out


# ---------------------------------------------------------------- agents

## A companion in the open world: where they are, their post (where they stand when given an order) and what they are doing.
static func new_agent(uid: int, id: String, x: float, z: float) -> Dictionary:
	return {"uid": uid, "id": id, "x": x, "z": z, "post_x": x, "post_z": z, "order": FOLLOW, "mode": "hold", "plan": [], "target": {},
		"work": 0, "scanned": -1000000, "alerted": false}


static func _pos(a: Dictionary) -> Vector2:
	return Vector2(float(a["x"]), float(a["z"]))


static func _post(a: Dictionary) -> Vector2:
	return Vector2(float(a["post_x"]), float(a["post_z"]))


## One agent for every companion in the party, beside the heir.
static func agents_for(d: GameDynasty, hx: float, hz: float) -> Array:
	var out: Array = []
	for m in d.party.members:
		out.append(_beside(out.size(), str(m["id"]), hx, hz))
	return out


static func _beside(index: int, id: String, hx: float, hz: float) -> Dictionary:
	var ang := float(index) * GOLDEN
	var r := float(setting("follow_min"))
	return new_agent(index, id, hx + cos(ang) * r, hz + sin(ang) * r)


## Agents for the party as it is now: those who left are dropped and new ones stand beside the heir. The rest are kept as they are.
static func reconcile(d: GameDynasty, agents: Array, hx: float, hz: float) -> Array:
	var out: Array = []
	for a in agents:
		if d.party.has_member(str(a["id"])):
			out.append(a)
	var have := {}
	for a in out:
		have[str(a["id"])] = true
	for m in d.party.members:
		if not have.has(str(m["id"])):
			out.append(_beside(out.size(), str(m["id"]), hx, hz))
	return out


## A view for `step_all`: the heir's place, the threats near ({x, z} each), the ground (as GameBehaviour's world view: ground
## companions keep off water) and, if given, a router (GamePath.router) to get round walls and water.
static func view(d: GameDynasty, hx: float, hz: float, threats: Array = [], router: Variant = null) -> Dictionary:
	var v := GameBehaviour.world_view(d, threats, false)
	v["heir"] = {"x": hx, "z": hz}
	v["threats"] = threats
	if router is Callable:
		v["router"] = router
	return v


## What an event tells the player.
static func event_text(e: Dictionary) -> String:
	var name := str(e.get("name", e.get("id", "")))
	match str(e.get("type", "")):
		"gathered":
			return text("gathered", {"name": name, "n": int(e["n"]), "material": GameMaterials.name_of(str(e["material"])).to_lower()})
		"alert":
			return text("alert", {"name": name})
		"regrouped":
			return text("regrouped", {"name": name})
		"nothing":
			return text("nothing", {"name": name})
	return ""


# ---------------------------------------------------------------- the step

## One tick for every companion. Returns {agents: the new agents (the old ones are not changed), events: [{type, id, name, ...}]}.
## Gathering takes materials into the dynasty's stores and marks the node; nothing else here changes it.
static func step_all(d: GameDynasty, agents: Array, view: Dictionary, tick: int) -> Dictionary:
	var out: Array = []
	var events: Array = []
	var claimed := {}
	for a in agents:
		if not (a["target"] as Dictionary).is_empty():
			claimed[node_key(int(a["target"]["x"]), int(a["target"]["z"]))] = true
	for i in agents.size():
		var a: Dictionary = (agents[i] as Dictionary).duplicate(true)
		var order := order_of(d, str(a["id"]))
		if order != str(a["order"]):   # a new order: forget the old work and take the place they stand as their post
			a["order"] = order
			a["plan"] = []
			a["target"] = {}
			a["work"] = 0
			a["alerted"] = false
			a["scanned"] = -1000000
			a["post_x"] = a["x"]
			a["post_z"] = a["z"]
		var before := events.size()
		match order:
			"stay":
				_stay(a, view)
			"guard":
				_guard(a, view, events)
			"gather":
				_gather(d, a, view, tick, claimed, events)
			_:
				_follow(a, view, i, events)
		for j in range(before, events.size()):
			events[j]["name"] = str(d.party.member(str(a["id"])).get("name", a["id"]))
		out.append(a)
	return {"agents": out, "events": events}


static func _go(a: Dictionary, aim: Vector2, view: Dictionary) -> void:
	var pos := _pos(a)
	var wp: Vector2 = GameBehaviour._route(view, pos, aim)
	var to := wp - pos
	var dist := to.length()
	if dist < 0.0001:
		return
	var step := minf(float(setting("speed")), dist)
	var next: Vector2 = GameBehaviour._move(pos, to / dist, step, false, view.get("walkable", null))
	a["x"] = next.x
	a["z"] = next.y


static func _follow(a: Dictionary, view: Dictionary, index: int, events: Array) -> void:
	var heir := Vector2(float(view["heir"]["x"]), float(view["heir"]["z"]))
	var pos := _pos(a)
	var ang := float(index) * GOLDEN
	var ring := heir + Vector2(cos(ang), sin(ang)) * float(setting("follow_min"))
	var dist := pos.distance_to(heir)
	if dist > float(setting("follow_catchup")):
		a["x"] = ring.x
		a["z"] = ring.y
		a["mode"] = "hold"
		events.append({"type": "regrouped", "id": a["id"]})
	elif dist > float(setting("follow_max")) or (a["mode"] == "trail" and dist > float(setting("follow_min"))):
		a["mode"] = "trail"
		_go(a, ring, view)
	else:
		a["mode"] = "hold"
	a["post_x"] = a["x"]
	a["post_z"] = a["z"]


static func _stay(a: Dictionary, view: Dictionary) -> void:
	var pos := _pos(a)
	var post := _post(a)
	if pos.distance_to(post) > float(setting("stay_radius")):
		a["mode"] = "return"
		_go(a, post, view)
	else:
		a["mode"] = "hold"


static func _guard(a: Dictionary, view: Dictionary, events: Array) -> void:
	var post := _post(a)
	var reach := float(setting("guard_radius")) * class_mult(str(a["id"]), "guard")
	var best := Vector2.ZERO
	var best_d := INF
	for t in view.get("threats", []):
		var tp := Vector2(float(t["x"]), float(t["z"]))
		var dp := tp.distance_to(post)
		if dp <= reach and dp < best_d:
			best_d = dp
			best = tp
	if best_d < INF:
		if not bool(a["alerted"]):
			a["alerted"] = true
			events.append({"type": "alert", "id": a["id"]})
		a["mode"] = "intercept"
		var pos := _pos(a)
		if pos.distance_to(best) > float(setting("guard_engage")):
			_go(a, best, view)
			var moved := _pos(a)
			if moved.distance_to(post) > reach:   # never drawn beyond the post's reach
				var held := post + (moved - post).normalized() * reach
				a["x"] = held.x
				a["z"] = held.y
		return
	a["alerted"] = false
	if _pos(a).distance_to(post) > 0.75:
		a["mode"] = "return"
		_go(a, post, view)
	else:
		a["mode"] = "hold"


## The nodes within `gather_radius` of a post that can be gathered now, nearest first: [{x, z, material, amount}].
static func scan(d: GameDynasty, post: Vector2, claimed: Dictionary = {}) -> Array:
	var found: Array = []
	var r := int(setting("gather_radius"))
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			if dx * dx + dz * dz > r * r:
				continue
			var x := int(floor(post.x)) + dx
			var z := int(floor(post.y)) + dz
			if not GameWorldGen.in_bounds(x, z) or claimed.has(node_key(x, z)) or depleted(d, x, z):
				continue
			var t := GameWorldGen.tile(d, x, z)
			var n: Dictionary = t["node"]
			if t["water"] or n.is_empty() or str(n["material"]) == "":
				continue
			found.append({"x": x, "z": z, "material": str(n["material"]), "amount": int(n["amount"]), "dist": Vector2(x, z).distance_to(post)})
	found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
		if p["dist"] != q["dist"]:
			return p["dist"] < q["dist"]
		return p["x"] < q["x"] or (p["x"] == q["x"] and p["z"] < q["z"]))
	return found


static func _gather(d: GameDynasty, a: Dictionary, view: Dictionary, tick: int, claimed: Dictionary, events: Array) -> void:
	var pos := _pos(a)
	var post := _post(a)
	var target: Dictionary = a["target"]
	if not target.is_empty():
		var tx := int(target["x"])
		var tz := int(target["z"])
		if depleted(d, tx, tz):   # someone else got it
			a["target"] = {}
			a["work"] = 0
			target = {}
		else:
			var aim := Vector2(float(tx) + 0.5, float(tz) + 0.5)
			if int(a["work"]) <= 0 and pos.distance_to(aim) > float(setting("gather_reach")):
				a["mode"] = "walk"
				_go(a, aim, view)
				return
			if int(a["work"]) <= 0:
				a["work"] = int(setting("gather_ticks"))
			a["mode"] = "work"
			a["work"] = int(a["work"]) - 1
			if int(a["work"]) > 0:
				return
			var n := maxi(1, int(round(float(target["amount"]) * class_mult(str(a["id"]), "gather"))))
			GameCraft.add_material(d, str(target["material"]), n)
			d.gathered[node_key(tx, tz)] = float(d.world.year)
			events.append({"type": "gathered", "id": a["id"], "material": target["material"], "n": n, "x": tx, "z": tz})
			a["target"] = {}
			return
	# no target: the next of the plan, or look again
	var plan: Array = a["plan"]
	while not plan.is_empty():
		var nxt: Dictionary = plan.pop_front()
		var k := node_key(int(nxt["x"]), int(nxt["z"]))
		if not depleted(d, int(nxt["x"]), int(nxt["z"])) and not claimed.has(k):
			a["target"] = nxt
			claimed[k] = true
			a["work"] = 0
			a["plan"] = plan
			a["mode"] = "walk"
			return
	a["plan"] = plan
	if tick - int(a["scanned"]) >= int(setting("rescan_ticks")):
		a["scanned"] = tick
		var found := scan(d, post, claimed)
		a["plan"] = found.slice(0, int(setting("plan_size"))).map(func(n: Dictionary) -> Dictionary: return {"x": n["x"], "z": n["z"], "material": n["material"], "amount": n["amount"]})
		if (a["plan"] as Array).is_empty():
			if a["mode"] != "idle":
				events.append({"type": "nothing", "id": a["id"]})
			a["mode"] = "idle"
		return
	if _pos(a).distance_to(post) > float(setting("stay_radius")):
		_go(a, post, view)
	a["mode"] = "idle"


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = data()
	for k in ["settings", "classes", "orders", "text"]:
		if not dat.has(k):
			bad.append("companions/world.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var s: Dictionary = dat["settings"]
	for k in ["speed", "follow_min", "follow_max", "follow_catchup", "stay_radius", "gather_radius", "gather_reach", "gather_ticks", "rescan_ticks", "plan_size", "regrow_years", "guard_radius", "guard_engage"]:
		if not s.has(k):
			bad.append("companions/world.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	for k in s:
		if float(s[k]) <= 0.0:
			bad.append("companions/world.json: settings.%s must be above 0" % k)
	if float(s["follow_min"]) >= float(s["follow_max"]) or float(s["follow_max"]) >= float(s["follow_catchup"]):
		bad.append("companions/world.json: follow_min < follow_max < follow_catchup is needed, or followers would never settle or never catch up")
	if float(s["gather_reach"]) >= float(s["gather_radius"]):
		bad.append("companions/world.json: gather_reach must be under gather_radius")
	if int(s["gather_ticks"]) < 1 or int(s["plan_size"]) < 1 or int(s["rescan_ticks"]) < 1:
		bad.append("companions/world.json: gather_ticks, plan_size and rescan_ticks must be at least 1")
	for o in ORDERS:
		if not dat["orders"].has(o):
			bad.append("companions/world.json: order '%s' has no name" % o)
	for o in dat["orders"]:
		if not ORDERS.has(o):
			bad.append("companions/world.json: '%s' is not an order the code knows" % o)
	if not dat["classes"].has("default"):
		bad.append("companions/world.json: classes needs a 'default'")
	GameData.load_all()
	for c in dat["classes"]:
		if c != "default" and not GameData.classes.has(c):
			bad.append("companions/world.json: '%s' is not a class" % c)
		for k in ["gather", "guard"]:
			if float(dat["classes"][c].get(k, 0.0)) <= 0.0:
				bad.append("companions/world.json: class '%s' needs a %s share above 0" % [c, k])
	for comp in GameData.companions:
		if str(comp["class"]) != "" and not dat["classes"].has(str(comp["class"])):
			bad.append("companions/world.json: companion '%s' is a %s, which has no work shares (it would use the default; list it)" % [comp["id"], comp["class"]])
	for k in ["set", "not_in_party", "unknown_order", "gathered", "alert", "regrouped", "nothing", "summary_none", "line"]:
		if not dat["text"].has(k):
			bad.append("companions/world.json: text.%s is missing" % k)
	return bad
