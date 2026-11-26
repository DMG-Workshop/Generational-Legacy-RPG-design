## The goal arrow: what the heir might do next, worked out from the dynasty's own state (data/world/goals.json). A pure function of
## the dynasty, where the heir stands and what the screen tells in `ctx`: no UI, no dice, nothing saved (so an old save works),
## and the autopilot never reads it. It is a hint: it never moves the heir. The screens show it (the minimap's edge, a
## small arrow over the world, the status line, the world map; see ui/play/goal_view.gd).
## A goal is {id, label, tile (the tile to point at; NONE when it has none, as a goal that is only words), kind}.
## Weighed in this order: a step of the first-heir tutorial that names a goal (data/ui/tutorial.json `goal`), then the `order` of the
## data: resting at home when hurt, a quest to claim, a quest to hunt or travel for, the store when the pack is full or the purse
## heavy, a landmark found and not yet searched, the notice board, and a creature near enough to hunt.
## The guided start's scripted pieces (the marker, the first foe's tile and level) are here too, as keyed functions of the
## town's own layout; they draw no dice.
## ctx (all optional): tips (bool, whether the tutorial is on), facts (the screen's yes-or-no facts for GameTutorial), creatures (the
## open world's creature agents), space (where the heir is: "world" or an interior's id).
class_name GameGoal
extends RefCounted

const PATH := "res://data/world/goals.json"
const NONE := Vector2i(-1, -1)

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


## A goal's label template, through the `goal` text catalog.
static func template(id: String) -> String:
	var src := str(data()["goals"].get(id, {}).get("label", id))
	return GameLocale.text("goal", id, src)


## The source lines of the `goal` catalog (GameLocale.source_lines).
static func lines() -> Dictionary:
	var out := {}
	for id in data()["goals"]:
		out[str(id)] = str(data()["goals"][id]["label"])
	return out


static func label(id: String, vals: Dictionary = {}) -> String:
	var s := template(id).format(vals)
	var cap := int(setting("label_max"))
	return s if s.length() <= cap else s.substr(0, cap - 1) + "…"


static func _goal(id: String, kind: String, vals: Dictionary, tile: Vector2i) -> Dictionary:
	return {"id": id, "kind": kind, "label": label(id, vals), "tile": tile}


# ---------------------------------------------------------------- places

## The tile of a town service's door ("store", "board"), or the town's anchor when it has none; NONE for an unknown place.
static func service_tile(place: String, service: String) -> Vector2i:
	var s := GameSpaces.space("%s/%s/%s" % [GameSpaces.root_id(), place, service])
	if s.is_empty():
		return GameTravel.anchor_tile(place)
	var door: Dictionary = s["door"]
	return Vector2i(int(door["x"]), int(door["z"]))


## The family house's door in the home town.
static func house_tile() -> Vector2i:
	var home := str(GameData.world["start"])
	return service_tile(home, str(GameSpaces.data()["house"]["id"]))


## The id of the family house's interior.
static func house_space() -> String:
	return "%s/%s/%s" % [GameSpaces.root_id(), str(GameData.world["start"]), str(GameSpaces.data()["house"]["id"])]


static func _gate() -> Dictionary:
	var home := str(GameData.world["start"])
	var gates := GameWalls.gates(home)
	for g in gates:
		if str(g["side"]) == str(setting("marker_gate")):
			return g
	return gates[0] if not gates.is_empty() else {}


static func _snap(d: GameDynasty, t: Vector2i) -> Vector2i:
	var s := GameTravel._snap(GamePath.world_ground(d), t)
	return t if s == GameTravel.NONE else s


## Where the guided start's first marker stands: just inside the home town's east gate (the way out to the wild). Nothing random.
static func marker_tile(d: GameDynasty) -> Vector2i:
	var g := _gate()
	if g.is_empty():
		return _snap(d, GameTravel.anchor_tile(str(GameData.world["start"])))
	return _snap(d, (g["inner"] as Vector2i) - (g["dir"] as Vector2i) * int(setting("marker_in")))


## Where the first foe waits: `foe_out` tiles outside that gate.
static func foe_tile(d: GameDynasty) -> Vector2i:
	var g := _gate()
	if g.is_empty():
		return marker_tile(d)
	return _snap(d, (g["outer"] as Vector2i) + (g["dir"] as Vector2i) * int(setting("foe_out")))


## The level of the first foe: the highest level under the heir's that the level bands call trivial or easy, else 1.
static func first_foe_level(heir_level: int) -> int:
	for lv in range(maxi(1, heir_level), 0, -1):
		if GameLevels.con(lv, heir_level) in ["trivial", "easy"]:
			return lv
	return 1


## The creature agent of the scripted first fight, to put in the open world's creatures: {agent (without a uid: the world gives it
## one), level}. Pure; the screen adds it (a hash of nothing: no dice anywhere).
static func first_foe(d: GameDynasty) -> Dictionary:
	var t := foe_tile(d)
	var a := GameBehaviour.new_agent(0, str(setting("first_foe")), float(t.x) + 0.5, float(t.y) + 0.5)
	a["level"] = first_foe_level(d.heir.level)
	a["guided"] = true
	return a


## The id of the first job (a quest of data/quests/quests.json).
static func first_quest() -> String:
	return str(setting("first_quest"))


## Whether the heir is a brand new house's first heir who has not fought yet: the guided start applies to them.
static func fresh_start(d: GameDynasty) -> bool:
	return d.gen <= 1 and d.total_hunts == 0 and d.heir.battles_won == 0


## Whether the guided start was begun for this dynasty (its flag).
static func guided(d: GameDynasty) -> bool:
	return d.flags.has(str(setting("guide_flag")))


## Begins the guided start for a brand new first heir: the flag that posts the first job, and the smoke pot. Only once (the flag is
## the memory), only for a fresh start, and only when the screen asks. Returns whether it began.
static func begin(d: GameDynasty) -> bool:
	if guided(d) or not fresh_start(d):
		return false
	d.flags[str(setting("guide_flag"))] = d.gen   # no on_flag: it is a mark, not a deed
	var pot := GameSmoke.item_id()
	for _i in maxi(0, int(setting("first_pots")) - GameSmoke.count(d.heir)):
		d.heir.inventory.append(pot)
	return true


## Using the family house's bedroom: the heir rests as in a bedroom they built (GameDynasty.rest_for). {ok, text} when the heir
## stands in it, {} otherwise. The player asks for it (the Use action); nothing here draws a die of its own.
static func home_rest(sb: GameSandbox) -> Dictionary:
	if sb.space != house_space() or GameSpaces.room_at(sb.space, sb.heir.x, sb.heir.y) != str(setting("home_room")):
		return {}
	var msgs := sb.d.rest_for(float(setting("home_years")))
	for m in msgs:
		sb.log.append({"kind": "rest", "text": str(m)})
	return {"ok": true, "text": str(msgs[0]) if not msgs.is_empty() else ""}


# ---------------------------------------------------------------- the goals

static func _con_ok(d: GameDynasty, a: Dictionary) -> bool:
	var lv := int(a.get("level", 0))
	return lv <= 0 or GameLevels.con(lv, d.heir.level) in ["trivial", "easy", "even"]


## The creature agent of `ids` (any when empty) nearest `from`, or {}.
static func nearest(creatures: Array, from: Vector2i, ids: Array = [], d: GameDynasty = null) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for a in creatures:
		if not ids.is_empty() and str(a.get("id", "")) not in ids:
			continue
		if d != null and ids.is_empty() and not _con_ok(d, a):
			continue
		var dist := Vector2(float(a["x"]) - float(from.x) - 0.5, float(a["z"]) - float(from.y) - 0.5).length()
		if dist < best_d:
			best_d = dist
			best = a
	return best


static func _tile_of(a: Dictionary) -> Vector2i:
	return Vector2i(floori(float(a["x"])), floori(float(a["z"])))


static func _creature_name(id: String) -> String:
	for c in GameData.creatures:
		if str(c["id"]) == id:
			return str(c["name"])
	return id


static func _quest_goals(d: GameDynasty, from: Vector2i, ctx: Dictionary) -> Array:
	var out: Array = []
	var qs := d.quests
	var creatures: Array = ctx.get("creatures", [])
	for e in qs.active:
		var q := GameQuests.def(str(e["id"]))
		if q.is_empty():
			continue
		var giver := str(q["giver"])
		var vals := {"title": str(q["name"]), "place": GameQuests.place_name(giver)}
		if qs.is_complete(e):
			out.append(_goal("quest_pay", "quest", vals, service_tile(giver, "board")))
			continue
		match GameQuests.kind(q):
			"kill":
				var ids := GameQuests.targets(q)
				vals["names"] = ", ".join(ids.map(func(t): return _creature_name(str(t)).to_lower()))
				var o: Dictionary = q["objective"]
				if o.has("place") and str(o["place"]) != d.world.location:
					vals["place"] = GameQuests.place_name(str(o["place"]))
					out.append(_goal("quest_visit", "quest", vals, GameTravel.anchor_tile(str(o["place"]))))
					continue
				var a := nearest(creatures, from, ids)
				if a.is_empty():
					out.append(_goal("quest_find", "quest", vals, NONE))
				else:
					vals["names"] = _creature_name(str(a["id"])).to_lower()
					out.append(_goal("quest_hunt", "quest", vals, _tile_of(a)))
			"visit":
				var target := str(q["objective"].get("target", ""))
				vals["place"] = GameQuests.place_name(target)
				out.append(_goal("quest_visit", "quest", vals, GameTravel.anchor_tile(target)))
	return out


## One goal by id, or {} when it does not hold now. `tips` goals (the tutorial's) are resolved by `_named`.
static func _named(d: GameDynasty, from: Vector2i, ctx: Dictionary, id: String) -> Dictionary:
	var h := d.heir
	var here := str(d.world.location)
	match id:
		"guide_marker":
			return _goal(id, "guide", {}, marker_tile(d))
		"guide_foe":
			var a := nearest(ctx.get("creatures", []), from, [str(setting("first_foe"))])
			return _goal(id, "guide", {"name": _creature_name(str(setting("first_foe"))).to_lower()}, foe_tile(d) if a.is_empty() else _tile_of(a))
		"rest_home":
			if str(ctx.get("space", "world")) == house_space():
				return _goal("rest_here", "rest", {}, NONE)
			return _goal(id, "rest", {}, house_tile())
		"store_sell", "gold_spend":
			if not GameWorld.place(here).get("services", []).has("store"):
				return {}
			return _goal(id, "store", {}, service_tile(here, "store"))
		"board_new":
			if not GameWorld.place(here).get("services", []).has("board"):
				return {}
			return _goal(id, "board", {}, service_tile(here, "board"))
		"quest":   # the tutorial's "the quest": the first quest goal
			var qg := _quest_goals(d, from, ctx)
			return {} if qg.is_empty() else qg[0]
	return {}


## Whether a goal of the data's `order` holds now.
static func _holds(d: GameDynasty, from: Vector2i, ctx: Dictionary, id: String) -> bool:
	var h := d.heir
	match id:
		"rest_home":
			return float(h.hp) < float(setting("rest_below")) * float(h.max_hp()) and str(d.world.location) == str(GameData.world["start"])
		"store_sell":
			return GameCarry.carried(h) >= float(setting("pack_full_share")) * GameCarry.capacity(h)
		"gold_spend":
			return float(h.gold) >= float(setting("gold_high")) * GameData.enemy_scale(d.gen)
		"board_new":
			var qs := d.quests
			if qs.active.size() >= int(GameData.bal("quest_max_active")):
				return false
			return qs.postings(d, str(d.world.location)).any(func(q): return int(q.get("requires", {}).get("min_level", 1)) <= h.level)
	return false


## Every goal that holds, the one to head for first. Each is {id, kind, label, tile}; a goal with no `tile` (NONE) is words only.
static func all(d: GameDynasty, from: Vector2i, ctx: Dictionary = {}) -> Array:
	GameData.load_all()
	var out: Array = []
	var seen := {}
	if bool(ctx.get("tips", false)) and d.gen <= 1:
		var step := GameTutorial.current(d, "sandbox", ctx.get("facts", {}))
		var gid := str(step.get("goal", ""))
		if gid != "":
			var g := _named(d, from, ctx, gid)
			if not g.is_empty():
				out.append(g)
				seen[str(g["id"])] = true
	for id in data()["order"]:
		var sid := str(id)
		match sid:
			"quest_pay", "quest_hunt", "quest_visit":
				if seen.has("quests"):
					continue
				seen["quests"] = true
				for g in _quest_goals(d, from, ctx):
					if not seen.has(str(g["id"]) + str(g["label"])):
						seen[str(g["id"]) + str(g["label"])] = true
						out.append(g)
			"landmark_use":
				var lm := _landmark(d, from)
				if not lm.is_empty():
					out.append(_goal(sid, "landmark", {"name": GameWildsSites.name_of(lm)}, Vector2i(int(lm["x"]), int(lm["z"]))))
			"hunt_near":
				var a := nearest(ctx.get("creatures", []), from, [], d)
				if not a.is_empty():
					out.append(_goal(sid, "hunt", {"name": _creature_name(str(a["id"])).to_lower()}, _tile_of(a)))
			_:
				if _holds(d, from, ctx, sid):
					var g := _named(d, from, ctx, sid)
					if not g.is_empty() and not seen.has(str(g["id"])):
						out.append(g)
						seen[str(g["id"])] = true
	return out


## The goal to head for: the first of `all`, or {}.
static func current(d: GameDynasty, from: Vector2i, ctx: Dictionary = {}) -> Dictionary:
	var list := all(d, from, ctx)
	return {} if list.is_empty() else list[0]


## The nearest landmark the family has found and can still search, or {}.
static func _landmark(d: GameDynasty, from: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for lm in GameWildsSites.found(d):
		if not GameWildsSites.available(d, str(lm["id"])):
			continue
		var dist := Vector2(Vector2i(int(lm["x"]), int(lm["z"])) - from).length()
		if dist < best_d:
			best_d = dist
			best = lm
	return best


# ---------------------------------------------------------------- checks

static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "order", "goals"]:
		if not dat.has(k):
			return ["goals.json: %s is missing" % k]
	for k in ["label_max", "rest_below", "pack_full_share", "gold_high", "marker_gate", "marker_in", "marker_reach", "foe_out", "first_foe", "first_quest", "guide_flag", "first_pots", "home_room", "home_years"]:
		if not (dat["settings"] as Dictionary).has(k):
			bad.append("goals.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	var cap := int(dat["settings"]["label_max"])
	for id in dat["goals"]:
		var g: Variant = dat["goals"][id]
		if typeof(g) != TYPE_DICTIONARY or typeof(g.get("label")) != TYPE_STRING or str(g["label"]) == "":
			bad.append("goals.json: goal '%s' needs a label" % id)
		elif str(g["label"]).length() > cap:
			bad.append("goals.json: goal '%s' has a label over %d characters" % [id, cap])
	for id in dat["order"]:
		if not (dat["goals"] as Dictionary).has(str(id)):
			bad.append("goals.json: order names '%s', which is not a goal" % id)
	for id in ["guide_marker", "guide_foe", "rest_home", "rest_here", "store_sell", "board_new", "quest_pay", "quest_hunt", "quest_find", "quest_visit", "landmark_use", "hunt_near"]:
		if not (dat["goals"] as Dictionary).has(id):
			bad.append("goals.json: the goal '%s' is missing" % id)
	var s: Dictionary = dat["settings"]
	if float(s["rest_below"]) <= 0.0 or float(s["rest_below"]) >= 1.0:
		bad.append("goals.json: rest_below must be between 0 and 1")
	if float(s["pack_full_share"]) <= 0.0 or float(s["pack_full_share"]) > 1.0:
		bad.append("goals.json: pack_full_share must be above 0 and at most 1")
	if not GameWalls.DIRS.has(str(s["marker_gate"])):
		bad.append("goals.json: marker_gate must be n, e, s or w")
	GameData.load_all()
	if GameQuests.def(str(s["first_quest"])).is_empty():
		bad.append("goals.json: first_quest '%s' is not a quest" % s["first_quest"])
	elif not (GameQuests.def(str(s["first_quest"])).get("requires", {}).get("flags", []) as Array).has(str(s["guide_flag"])):
		bad.append("goals.json: the first quest must wait for the guide flag, or the autopilot would see it")
	if GameBehaviour._def(str(s["first_foe"])).is_empty():
		bad.append("goals.json: first_foe '%s' is not a creature" % s["first_foe"])
	return bad
