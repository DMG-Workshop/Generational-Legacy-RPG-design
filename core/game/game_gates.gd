## Waygates: the standing arches of the Old Roads (data/world/gates.json; design in docs/GATES.md). Each stands at a fixed place that is a
## pure function of the seed (an offset from a place's anchor, moved to the nearest dry, flat, clear ground off every wall and building),
## has a rune slot for each rune of its alphabet, and links to the other gates of its network. A slot is whole, worn, broken or stripped,
## and that is a PURE FUNCTION of the seed, the gate, the slot and the world year: at year 0 some gates are whole and most are ruined,
## wear takes a slot down the longer it goes unrepaired, and thieves strip the silver from one slot of a gate in some years (keyed hashes,
## never the dynasty's dice) unless a guard stands at it. Only what the family does is saved (`GameDynasty.gates`, only once something is
## set): the runes learned, the slots repaired and when, the gates found and the guards posted. A gate with no broken or stripped slot works
## (lit if every slot is whole, flickering if some are worn: a charge for each trip); the heir steps from a working gate to any other working
## gate of the same network, and a realm's gate is the door to that realm (its repair opens the realm's `gate_<realm>` flag). Logic only:
## the screens ask (GameSandbox.use, the gate panel, the map), never the rules of a life, so the autopilot and the golden digests do not move.
class_name GameGates
extends RefCounted

const PATH := "res://data/world/gates.json"
const SLOT_STATES := ["whole", "worn", "broken", "stripped"]

static var _cache: Dictionary = {}
static var _seed := -1
static var _placed: Dictionary = {}      # gate id -> {x, z, fx, fz} for the seed
static var _order: Array = []            # the ids in data order
static var _thefts: Dictionary = {}      # "seed|gate" -> {upto: year, list: [[year, slot]]}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


# ---------------------------------------------------------------- the data

## Every gate id, in data order.
static func ids() -> Array:
	var out: Array = []
	for g in data()["gates"]:
		out.append(str(g["id"]))
	return out


static func has(id: String) -> bool:
	return not def(id).is_empty()


## A gate's data row, or {}.
static func def(id: String) -> Dictionary:
	for g in data()["gates"]:
		if str(g["id"]) == id:
			return g
	return {}


static func name_of(id: String) -> String:
	return str(def(id).get("name", id))


static func rune_def(rune: String) -> Dictionary:
	return data()["runes"].get(rune, {})


static func rune_name(rune: String) -> String:
	return str(rune_def(rune).get("name", rune))


static func network_name(net: String) -> String:
	return str(data()["networks"].get(net, {}).get("name", net))


## The runes of a gate, one for each slot.
static func runes_of(id: String) -> Array:
	return def(id).get("runes", [])


static func slot_count(id: String) -> int:
	return runes_of(id).size()


## The realm a gate is the door to, or "" for a gate of the roads.
static func realm_of(id: String) -> String:
	return str(def(id).get("realm", ""))


## The gate that is the door to a realm, or "".
static func gate_of_realm(realm: String) -> String:
	for g in data()["gates"]:
		if str(g.get("realm", "")) == realm:
			return str(g["id"])
	return ""


## The year of the world: whole years since the dynasty was founded.
static func year(d: GameDynasty) -> int:
	return int(floor(d.world.year))


# ---------------------------------------------------------------- placement

static func _ensure(d: GameDynasty) -> void:
	if d.seed_value == _seed and not _order.is_empty():
		return
	_seed = d.seed_value
	_placed = {}
	_order = []
	_thefts = {}
	for g in data()["gates"]:
		var id := str(g["id"])
		var t := _find(d, g)
		if t.x < 0:
			continue
		var f := _front(d, t.x, t.y)
		_placed[id] = {"x": t.x, "z": t.y, "fx": f.x, "fz": f.y}
		_order.append(id)


## The tile a gate's data names before it is moved to good ground.
static func _nominal(g: Dictionary) -> Vector2i:
	var a: Dictionary = g["anchor"]
	if a.has("realm"):
		var t: Array = GameSpaces.data()["realm_gates"].get(str(a["realm"]), [0, 0])
		return Vector2i(int(t[0]), int(t[1]))
	var an := GameWorldGen.anchor(str(a.get("place", "")))
	if an.is_empty():
		return Vector2i(-1, -1)
	return Vector2i(int(an["x"]) + int(a.get("at", [0, 0])[0]), int(an["z"]) + int(a.get("at", [0, 0])[1]))


static func _find(d: GameDynasty, g: Dictionary) -> Vector2i:
	var n := _nominal(g)
	if n.x < 0:
		return Vector2i(-1, -1)
	var best := Vector2i(-1, -1)
	for r in range(0, int(setting("search")) + 1):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r or best.x >= 0:
					continue
				if _spot_ok(d, n.x + dx, n.y + dz):
					best = Vector2i(n.x + dx, n.y + dz)
		if best.x >= 0:
			return best
	return best


## The tiles an arch stands on when its passage tile is (x, z): three wide, two deep (the pillars and the lintel's shadow).
static func footprint(x: int, z: int) -> Array:
	var out: Array = []
	for dz in range(-1, 1):
		for dx in range(-1, 2):
			out.append(Vector2i(x + dx, z + dz))
	return out


## Whether a tile is plain walkable ground as the land makes it: dry, no node, no wall, no building.
static func _plain(d: GameDynasty, x: int, z: int) -> bool:
	if not GameWorldGen.in_bounds(x, z):
		return false
	var t := GameWorldGen.tile(d, x, z)
	if bool(t["water"]) or not (t["node"] as Dictionary).is_empty():
		return false
	if GameWalls.blocks(x, z) or GameWalls.kind_at(x, z) != "" or GameWalls.cleared(x, z):
		return false
	return GameTown.at(x, z).is_empty()


static func _spot_ok(d: GameDynasty, x: int, z: int) -> bool:
	var size := GameWorldGen.size()
	if x < 6 or z < 6 or x >= size - 6 or z >= size - 6:
		return false
	var lo := 1 << 30
	var hi := -(1 << 30)
	for t in footprint(x, z):
		if not _plain(d, t.x, t.y):
			return false
		var h := int(GameWorldGen.tile(d, t.x, t.y)["height"])
		lo = mini(lo, h)
		hi = maxi(hi, h)
	if hi - lo > int(setting("flat_max")):
		return false
	for a in GameWorldGen.zones():   # never on a dungeon's mouth or a plot
		var r := float(a["radius"])
		var dist := Vector2(float(x) - float(a["x"]), float(z) - float(a["z"])).length()
		if str(a["type"]) == "dungeon" and dist < r + 8.0:
			return false
		if r <= 0.0 and dist < 3.0:
			return false
	for id in _order:
		var p: Dictionary = _placed[id]
		if Vector2(float(x - int(p["x"])), float(z - int(p["z"]))).length() < float(setting("min_gap")):
			return false
	return true


## The open tile in front (south) of an arch that a traveller arrives on: the nearest plain tile to two below the passage that is not under it.
static func _front(d: GameDynasty, x: int, z: int) -> Vector2i:
	var under := footprint(x, z)
	var aim := Vector2i(x, z + 2)
	for r in range(0, int(setting("front_search")) + 1):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var t := aim + Vector2i(dx, dz)
				if t not in under and _plain(d, t.x, t.y):
					return t
	return aim


## Where a gate stands: {x, z, fx, fz} (the passage tile and the tile in front of it), or {} when the land has no room (never so in the data).
static func placed(d: GameDynasty, id: String) -> Dictionary:
	_ensure(d)
	return _placed.get(id, {})


## Every gate that stands in this world, in data order.
static func all(d: GameDynasty) -> Array:
	_ensure(d)
	return _order.duplicate()


## The tile of a gate's passage.
static func tile_of(d: GameDynasty, id: String) -> Vector2i:
	var p := placed(d, id)
	return Vector2i(-1, -1) if p.is_empty() else Vector2i(int(p["x"]), int(p["z"]))


## The tile a traveller comes out on in front of a gate.
static func front_of(d: GameDynasty, id: String) -> Vector2i:
	var p := placed(d, id)
	return Vector2i(-1, -1) if p.is_empty() else Vector2i(int(p["fx"]), int(p["fz"]))


## Whether a tile is under or just round a gate (the landmarks of the wilds keep off it).
static func claims(d: GameDynasty, x: int, z: int, margin: int = 3) -> bool:
	_ensure(d)
	for id in _order:
		var p: Dictionary = _placed[id]
		if absi(x - int(p["x"])) <= margin and z >= int(p["z"]) - margin - 1 and z <= int(p["z"]) + margin + 2:
			return true
	return false


## The place a gate is nearest, as its name: "near Hearthmere".
static func place_name(d: GameDynasty, id: String) -> String:
	var t := tile_of(d, id)
	if t.x < 0:
		return ""
	var near := GameWorldGen.nearest_anchor(float(t.x), float(t.y))
	if (near["anchor"] as Dictionary).is_empty():
		return ""
	return "near %s" % str(near["anchor"]["name"])


static func distance(d: GameDynasty, a: String, b: String) -> int:
	var p := tile_of(d, a)
	var q := tile_of(d, b)
	if p.x < 0 or q.x < 0:
		return 0
	return int(round(Vector2(p - q).length()))


# ---------------------------------------------------------------- the state of a gate (pure)

static func _rng(d: GameDynasty, tag: String, a: Variant, b: Variant = 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "gate", tag, a, b])
	return r


## What the world did to a slot before anyone repaired it: {ordinal 0 whole to 2 broken, stripped}. The `whole` slots of the gate with the lowest
## rolls are whole; the rest are dealt worn, broken or stripped by `start_split`.
static func start_of(d: GameDynasty, id: String, slot: int) -> Dictionary:
	var g := def(id)
	var n := slot_count(id)
	var rolls: Array = []
	for i in n:
		rolls.append([_rng(d, "start", id, i).randf(), i])
	rolls.sort()
	var rank := 0
	for k in n:
		if int(rolls[k][1]) == slot:
			rank = k
	if rank < int(g.get("whole", 0)):
		return {"ordinal": 0, "stripped": false}
	var r := _rng(d, "split", id, slot).randf()
	var split: Dictionary = setting("start_split")
	if r < float(split["worn"]):
		return {"ordinal": 1, "stripped": false}
	if r < float(split["worn"]) + float(split["broken"]):
		return {"ordinal": 2, "stripped": false}
	return {"ordinal": 2, "stripped": true}


## How fast a slot wears, in steps a year: its rune's rate with a keyed jitter either way.
static func wear_rate(d: GameDynasty, id: String, slot: int) -> float:
	var rune := str(runes_of(id)[slot])
	var j := float(setting("wear_jitter"))
	return float(rune_def(rune).get("wear", 0.03)) * (1.0 + (_rng(d, "wear", id, slot).randf() * 2.0 - 1.0) * j)


## The thefts of a gate up to a year: [[year, slot]], in order (a year with a theft strips one slot's silver). Kept: a pure function of
## the seed and the gate, so the same answer however it is asked.
static func thefts(d: GameDynasty, id: String, upto: int) -> Array:
	_ensure(d)
	var key := "%d|%s" % [d.seed_value, id]
	var e: Dictionary = _thefts.get(key, {"upto": 0, "list": []})
	var cap := mini(upto, int(setting("year_cap")))
	var n := slot_count(id)
	var chance := float(setting("theft_chance")) * float(def(id).get("exposure", 1.0))
	for y in range(int(e["upto"]) + 1, cap + 1):
		var r := _rng(d, "theft", id, y)
		if r.randf() < chance and n > 0:
			(e["list"] as Array).append([y, r.randi() % n])
	e["upto"] = maxi(int(e["upto"]), cap)
	_thefts[key] = e
	return (e["list"] as Array).filter(func(t): return int(t[0]) <= upto)


## The guard record of a gate: {id (the one serving or posted last, "" once relieved), since, seen, past: [[from, to]]} or {}. `past` keeps the years
## earlier guards served, so a thief's year they kept off stays kept.
static func guard_record(d: GameDynasty, id: String) -> Dictionary:
	var g: Variant = d.gates.get("guard", {})
	return (g as Dictionary).get(id, {}) if typeof(g) == TYPE_DICTIONARY else {}


## Whether the guard of a gate is serving now: still in the party and still under the `guard` order.
static func guard_serving(d: GameDynasty, id: String) -> bool:
	var r := guard_record(d, id)
	if r.is_empty() or str(r.get("id", "")) == "":
		return false
	var m := str(r["id"])
	return d.party.has_member(m) and GameCompanions.order_of(d, m) == "guard"


## The party member guarding a gate now ("" for none).
static func guard_of(d: GameDynasty, id: String) -> String:
	return str(guard_record(d, id).get("id", "")) if guard_serving(d, id) else ""


## Whether thieves in a year are kept off a gate: a guard stood there that year (since the year after they were posted, up to the year they were relieved or
## the family last looked, or for as long as they serve).
static func guarded_in(d: GameDynasty, id: String, y: int) -> bool:
	var r := guard_record(d, id)
	if r.is_empty():
		return false
	for p in r.get("past", []):
		if y > int(p[0]) and y <= int(p[1]):
			return true
	if str(r.get("id", "")) == "" or y <= int(r.get("since", 0)):
		return false
	return guard_serving(d, id) or y <= int(r.get("seen", 0))


## The year a slot was last repaired, or -1 when it never was (it is as the world left it).
static func repaired_in(d: GameDynasty, id: String, slot: int) -> int:
	var f: Variant = d.gates.get("fixed", {})
	if typeof(f) != TYPE_DICTIONARY:
		return -1
	return int((f as Dictionary).get("%s:%d" % [id, slot], -1))


## One slot's state in a year: "whole", "worn", "broken" or "stripped".
static func slot_state(d: GameDynasty, id: String, slot: int, y: int) -> String:
	var fixed := repaired_in(d, id, slot)
	var ordinal := 0
	var stripped := false
	var from := 0
	if fixed >= 0:
		from = fixed
	else:
		var s := start_of(d, id, slot)
		ordinal = int(s["ordinal"])
		stripped = bool(s["stripped"])
	var t := maxi(0, y - from)
	ordinal = mini(2, ordinal + int(floor(float(t) * wear_rate(d, id, slot))))
	if not stripped:
		for e in thefts(d, id, y):
			if int(e[1]) == slot and int(e[0]) > from and not guarded_in(d, id, int(e[0])):
				stripped = true
	if stripped:
		return "stripped"
	return SLOT_STATES[ordinal]


## The state of a gate now: {slots: [{rune, state}], lit, mode ("lit", "flickering" or "dark"), condition (0 to 1), failed, worn}.
static func state(d: GameDynasty, id: String) -> Dictionary:
	return state_in(d, id, year(d))


static func state_in(d: GameDynasty, id: String, y: int) -> Dictionary:
	var slots: Array = []
	var failed := 0
	var worn := 0
	var score := 0.0
	var runes := runes_of(id)
	for i in runes.size():
		var st := slot_state(d, id, i, y)
		slots.append({"rune": str(runes[i]), "state": st})
		match st:
			"whole":
				score += 1.0
			"worn":
				worn += 1
				score += 0.5
			_:
				failed += 1
	var mode := "lit"
	if failed >= int(setting("dark_at")):
		mode = "dark"
	elif worn > 0:
		mode = "flickering"
	return {"slots": slots, "lit": mode == "lit", "mode": mode, "condition": score / maxf(1.0, float(runes.size())), "failed": failed, "worn": worn}


## Whether a gate works (lit or flickering).
static func working(d: GameDynasty, id: String) -> bool:
	return has(id) and str(state(d, id)["mode"]) != "dark"


static func mode_name(mode: String) -> String:
	return text("state_" + mode)


# ---------------------------------------------------------------- lore: the runes the family knows

static func _list(d: GameDynasty, key: String) -> Array:
	var v: Variant = d.gates.get(key, [])
	return v if typeof(v) == TYPE_ARRAY else []


## Whether the heir can cut a rune: learned, or a Runescribe, who knows them all.
static func knows(d: GameDynasty, rune: String) -> bool:
	if not data()["runes"].has(rune):
		return false
	if d.heir.subclass == str(setting("scribe")):
		return true
	return rune in _list(d, "runes") or rune in setting("known_at_start")


static func known_runes(d: GameDynasty) -> Array:
	var out: Array = []
	for r in data()["runes"]:
		if knows(d, str(r)):
			out.append(str(r))
	return out


static func learn(d: GameDynasty, rune: String) -> bool:
	if not data()["runes"].has(rune) or rune in _list(d, "runes") or rune in setting("known_at_start"):
		return false
	var l := _list(d, "runes").duplicate()
	l.append(rune)
	d.gates["runes"] = l
	return true


## What a landmark of the wilds teaches when it is searched (`settings.lore`: a chance for each kind): a keyed roll on the seed, the landmark and
## how often it was used, never the dynasty's dice. Learns a rune the family lacks (the common ones likelier) and returns the line, or "".
static func lore_from(d: GameDynasty, lm: Dictionary, n: int) -> String:
	var chance := float(setting("lore").get(str(lm.get("kind", "")), 0.0))
	if chance <= 0.0:
		return ""
	var r := _rng(d, "lore", str(lm["id"]), n)
	if r.randf() >= chance:
		return ""
	var pool: Array = []
	var total := 0.0
	for k in data()["runes"]:
		if not knows(d, str(k)):
			pool.append(str(k))
			total += float(rune_def(str(k)).get("weight", 1))
	if pool.is_empty():
		return ""
	var pick := r.randf() * total
	var chosen := str(pool[0])
	for k in pool:
		pick -= float(rune_def(str(k)).get("weight", 1))
		if pick <= 0.0:
			chosen = str(k)
			break
	learn(d, chosen)
	return text("lore_found", {"heir": d.heir.name, "rune": rune_name(chosen).to_lower(), "lore": str(rune_def(chosen)["lore"])})


# ---------------------------------------------------------------- finding gates

static func found(d: GameDynasty) -> Array:
	return _list(d, "found")


static func is_found(d: GameDynasty, id: String) -> bool:
	return id in _list(d, "found")


## Whether the family knows a gate: it found it, or it is awake (a working arch answers the others of its road).
static func is_known(d: GameDynasty, id: String) -> bool:
	return has(id) and (is_found(d, id) or working(d, id))


## Marks every gate within `see_range` of a tile found; returns the ones newly found.
static func discover_near(d: GameDynasty, x: int, z: int) -> Array:
	var fresh: Array = []
	var r := float(setting("see_range"))
	for id in all(d):
		if is_found(d, id):
			continue
		var p := placed(d, id)
		if Vector2(float(x) - float(p["x"]), float(z) - float(p["z"])).length() <= r:
			var l := _list(d, "found").duplicate()
			l.append(id)
			d.gates["found"] = l
			fresh.append(id)
	return fresh


## The gate within reach of a tile, or "".
static func near(d: GameDynasty, x: int, z: int) -> String:
	var best := ""
	var best_d := float(setting("reach")) + 0.001
	for id in all(d):
		var p := placed(d, id)
		var dist := Vector2(float(x - int(p["x"])), float(z - int(p["z"]))).length()
		if dist < best_d:
			best_d = dist
			best = id
	return best


## The line the place line adds beside a gate.
static func hint(d: GameDynasty, x: int, z: int) -> String:
	var id := near(d, x, z)
	if id == "":
		return ""
	return text("hint", {"name": name_of(id), "state": mode_name(str(state(d, id)["mode"])).to_lower()})


## The markers of the gates the family knows, for the maps: {id, name, x, z, cell, mode, realm}.
static func markers(d: GameDynasty) -> Array:
	var out: Array = []
	for id in all(d):
		if not is_known(d, id):
			continue
		var t := tile_of(d, id)
		out.append({"id": id, "name": name_of(id), "x": t.x, "z": t.y, "cell": GameWorldMap.cell_of(t.x, t.y), "mode": str(state(d, id)["mode"]), "realm": realm_of(id)})
	return out


# ---------------------------------------------------------------- repair

static func _near_gate(d: GameDynasty, id: String, at: Vector2i) -> bool:
	if at.x < 0 and at.y < 0:
		return true   # no position given (a tool or a test): the caller has checked
	var t := tile_of(d, id)
	return Vector2(at - t).length() <= float(setting("reach")) + 0.001


## What cutting a slot again costs: {silver, gold} for its state (0 for a whole one). The gold is scaled by the gate's size, the rune and the
## generation, and halved for a Runescribe; a Runescribe also needs less silver to relay a stripped slot.
static func repair_cost(d: GameDynasty, id: String, slot: int, st: String) -> Dictionary:
	var row: Dictionary = setting("repair").get(st, {})
	if row.is_empty():
		return {"silver": 0, "gold": 0}
	var rune := str(runes_of(id)[slot])
	var gold := float(row["gold"]) * float(setting("size_cost")[str(def(id)["size"])]) * float(rune_def(rune).get("cost", 1.0)) * GameData.enemy_scale(d.gen)
	gold *= GameSubclass.perk(d.heir, "rune_fee_mult")
	var silver := float(row["silver"])
	if st == "stripped":
		silver *= GameSubclass.perk(d.heir, "rune_silver_mult")
	return {"silver": maxi(1, int(round(silver))), "gold": maxi(1, int(ceil(gold)))}


## What repairing a slot would be: {ok, why, rune, state, silver, gold}. Nothing is spent.
static func inscribe_plan(d: GameDynasty, id: String, slot: int, at: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	if not has(id) or placed(d, id).is_empty():
		return {"ok": false, "why": text("no_gate")}
	if slot < 0 or slot >= slot_count(id):
		return {"ok": false, "why": text("no_slot")}
	var st := str(state(d, id)["slots"][slot]["state"])
	var rune := str(runes_of(id)[slot])
	var cost := repair_cost(d, id, slot, st)
	var plan := {"ok": false, "why": "", "rune": rune, "state": st, "silver": int(cost["silver"]), "gold": int(cost["gold"])}
	var vals := {"heir": d.heir.name, "rune": rune_name(rune).to_lower()}
	if not _near_gate(d, id, at):
		plan["why"] = text("far", vals)
	elif st == "whole":
		plan["why"] = text("slot_ok")
	elif not knows(d, rune):
		plan["why"] = text("rune_unknown", vals)
	elif GameCraft.have(d, str(setting("silver"))) < int(cost["silver"]):
		plan["why"] = text("need_silver", {"n": cost["silver"], "have": GameCraft.have(d, str(setting("silver")))})
	elif d.heir.gold < int(cost["gold"]):
		plan["why"] = text("need_gold", {"n": cost["gold"], "have": d.heir.gold, "heir": d.heir.name})
	else:
		plan["ok"] = true
	return plan


## Cuts a slot's rune again and inlays it with silver: spends the silver and the gold and records the repair (the slot is whole from this year on).
## A realm's gate that is lit by it opens the realm's flag (GameRealms.open_gate). {ok, text}.
static func inscribe(d: GameDynasty, id: String, slot: int, at: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var plan := inscribe_plan(d, id, slot, at)
	if not bool(plan["ok"]):
		return {"ok": false, "text": str(plan["why"])}
	d.heir.gold -= int(plan["gold"])
	GameCraft.add_material(d, str(setting("silver")), -int(plan["silver"]))
	var fixed: Dictionary = d.gates.get("fixed", {})
	fixed["%s:%d" % [id, slot]] = year(d)
	d.gates["fixed"] = fixed
	tend(d)
	var now := state(d, id)
	var line := text("inscribed", {"heir": d.heir.name, "rune": rune_name(str(plan["rune"])).to_lower(), "state_line": text("state_line_" + str(now["mode"]), {"name": name_of(id)})})
	var realm := realm_of(id)
	if realm != "" and bool(now["lit"]):
		var opened := GameRealms.open_gate(d, realm)
		if opened != "":
			line += " " + text("realm_flag", {"line": opened})
	d._say(line)
	return {"ok": true, "text": line}


## Copies a rune from a slot that can still be read (whole or worn): learns it for nothing. {ok, text}.
static func copy_rune(d: GameDynasty, id: String, slot: int, at: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	if not has(id) or slot < 0 or slot >= slot_count(id):
		return {"ok": false, "text": text("no_slot")}
	var rune := str(runes_of(id)[slot])
	var vals := {"heir": d.heir.name, "rune": rune_name(rune).to_lower()}
	if not _near_gate(d, id, at):
		return {"ok": false, "text": text("far", vals)}
	if knows(d, rune):
		return {"ok": false, "text": text("copy_known", vals)}
	if str(state(d, id)["slots"][slot]["state"]) not in ["whole", "worn"]:
		return {"ok": false, "text": text("copy_illegible", vals)}
	learn(d, rune)
	var line := text("copied", vals)
	d._say(line)
	return {"ok": true, "text": line}


## The price of silver at a gate's smith, one unit (gold, scaled by the generation).
static func silver_price(d: GameDynasty) -> int:
	return maxi(1, int(ceil(float(setting("silver_price")) * GameData.enemy_scale(d.gen))))


## Why silver cannot be bought at a gate now ("" when it can).
static func buy_silver_why(d: GameDynasty, id: String, n: int, at: Vector2i = Vector2i(-1, -1)) -> String:
	if not bool(def(id).get("trader", false)):
		return text("no_trader")
	if not _near_gate(d, id, at):
		return text("far", {"heir": d.heir.name})
	if n < 1 or n > int(setting("silver_buy_max")):
		return text("silver_max", {"n": int(setting("silver_buy_max"))})
	if d.heir.gold < silver_price(d) * n:
		return text("need_gold", {"n": silver_price(d) * n, "have": d.heir.gold, "heir": d.heir.name})
	return ""


## Buys silver from the road smith at a town's gate. {ok, text}.
static func buy_silver(d: GameDynasty, id: String, n: int, at: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var why := buy_silver_why(d, id, n, at)
	if why != "":
		return {"ok": false, "text": why}
	var gold := silver_price(d) * n
	d.heir.gold -= gold
	GameCraft.add_material(d, str(setting("silver")), n)
	var line := text("bought_silver", {"heir": d.heir.name, "n": n, "gold": gold})
	d._say(line)
	return {"ok": true, "text": line}


# ---------------------------------------------------------------- guards

## Brings the guards' "last looked" year up to now, for those serving. Cheap; the sandbox calls it as the heir walks and a repair calls it.
static func tend(d: GameDynasty) -> void:
	var g: Variant = d.gates.get("guard", {})
	if typeof(g) != TYPE_DICTIONARY:
		return
	for id in g:
		if guard_serving(d, str(id)):
			g[id]["seen"] = year(d)


## Closes the guard's current stretch into `past` (the record is left with no one on duty).
static func _close_guard(d: GameDynasty, id: String) -> void:
	var g: Dictionary = d.gates.get("guard", {})
	if not g.has(id):
		return
	var r: Dictionary = g[id]
	if str(r.get("id", "")) != "":
		var past: Array = (r.get("past", []) as Array).duplicate()
		if int(r["seen"]) > int(r["since"]) and past.size() < 20:
			past.append([int(r["since"]), int(r["seen"])])
		r["past"] = past
		r["id"] = ""
	g[id] = r
	d.gates["guard"] = g


## Posts a party member at a gate: it takes the `guard` order, and no thief strips the gate from then on while they serve. {ok, text}.
static func assign_guard(d: GameDynasty, id: String, member: String, at: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	if not has(id):
		return {"ok": false, "text": text("no_gate")}
	if not d.party.has_member(member):
		return {"ok": false, "text": text("guard_member")}
	if not _near_gate(d, id, at):
		return {"ok": false, "text": text("far", {"heir": d.heir.name})}
	var nm := str(d.party.member(member)["name"])
	if guard_of(d, id) == member:
		return {"ok": false, "text": text("guard_busy", {"name": nm, "gate": name_of(id)})}
	tend(d)
	if guard_of(d, id) != "":
		release_guard(d, id, true)
	var g: Dictionary = d.gates.get("guard", {})
	for other in g.keys():   # one post a companion
		if str(g[other].get("id", "")) == member:
			if guard_serving(d, str(other)):
				GameCompanions.set_order(d, member, "follow")
			_close_guard(d, str(other))
	g = d.gates.get("guard", {})
	GameCompanions.set_order(d, member, "guard")
	var rec: Dictionary = g.get(id, {})
	g[id] = {"id": member, "since": year(d), "seen": year(d), "past": rec.get("past", [])}
	d.gates["guard"] = g
	var line := text("guard_set", {"name": nm, "gate": name_of(id)})
	d._say(line)
	return {"ok": true, "text": line}


## Takes the guard off a gate (they return to following). The years they served stay kept. {ok, text}.
static func release_guard(d: GameDynasty, id: String, quiet: bool = false) -> Dictionary:
	var r := guard_record(d, id)
	if r.is_empty() or str(r.get("id", "")) == "":
		return {"ok": false, "text": text("guard_none")}
	var member := str(r["id"])
	tend(d)
	if d.party.has_member(member) and GameCompanions.order_of(d, member) == "guard":
		GameCompanions.set_order(d, member, "follow")
	var nm := d.party.display_name(member)
	_close_guard(d, id)
	var line := text("guard_off", {"name": nm, "gate": name_of(id)})
	if not quiet:
		d._say(line)
	return {"ok": true, "text": line}


# ---------------------------------------------------------------- the roads: where a gate leads

## The gates a gate links to: the other working gates of any of its networks (the realm's own door for a realm gate): [{id, name, place, distance, kind}].
static func destinations(d: GameDynasty, id: String) -> Array:
	var out: Array = []
	if not has(id):
		return out
	var realm := realm_of(id)
	if realm != "":
		out.append({"id": "realm:" + realm, "name": GameRealms.name_of(realm), "place": "beyond the gate", "distance": 0, "kind": "realm", "realm": realm})
	var mine: Array = def(id)["networks"]
	for other in all(d):
		if other == id or realm_of(other) != "" or realm != "":
			continue
		var shared := false
		for n in def(other)["networks"]:
			if n in mine:
				shared = true
		if shared and working(d, other):
			out.append({"id": other, "name": name_of(other), "place": place_name(d, other), "distance": distance(d, id, other), "kind": "gate", "realm": ""})
	out.sort_custom(func(a, b): return int(a["distance"]) < int(b["distance"]) or (int(a["distance"]) == int(b["distance"]) and str(a["id"]) < str(b["id"])))
	return out


## The world-clock seconds a trip takes: a base and so much a tile, capped.
static func travel_seconds(d: GameDynasty, a: String, b: String) -> float:
	var t: Dictionary = setting("travel")
	return minf(float(t["cap_seconds"]), float(t["base_seconds"]) + float(t["per_tile"]) * float(distance(d, a, b)))


## What a trip costs at the gates: {} for two lit gates, else {material, n} (silver) or the essence to give; "essence" is an affix id the family holds.
static func charge_for(d: GameDynasty, a: String, b: String) -> Dictionary:
	var flicker := str(state(d, a)["mode"]) == "flickering" or (has(b) and str(state(d, b)["mode"]) == "flickering")
	if not flicker:
		return {}
	var c: Dictionary = setting("charge")
	var silver := int(c["n"])
	if GameCraft.have(d, str(c["material"])) >= silver:
		return {"material": str(c["material"]), "n": silver}
	var ess: Dictionary = GameCraft.essences(d)
	var keys: Array = ess.keys()
	keys.sort()
	for k in keys:
		if int(ess[k]) >= int(c["essences"]):
			return {"essence": str(k), "n": int(c["essences"])}
	return {"short": true, "material": str(c["material"]), "n": silver}


## Whether a trip can be made now, by the rules of the gates alone (the sandbox adds where the heir is): {ok, why, seconds, charge}.
static func travel_plan(d: GameDynasty, a: String, b: String) -> Dictionary:
	var plan := {"ok": false, "why": "", "seconds": 0.0, "charge": {}}
	if not has(a) or not working(d, a):
		plan["why"] = text("refuse_dark")
		return plan
	var realm := b.begins_with("realm:")
	if realm:
		if realm_of(a) != b.substr(6):
			plan["why"] = text("refuse_link")
			return plan
	else:
		if not has(b) or not working(d, b):
			plan["why"] = text("refuse_there")
			return plan
		var share := false
		for n in def(a)["networks"]:
			if n in def(b)["networks"]:
				share = true
		if not share or realm_of(a) != "" or realm_of(b) != "":
			plan["why"] = text("refuse_link")
			return plan
	if not GameClock.running(d):
		plan["why"] = text("refuse_clock")
		return plan
	var ch := charge_for(d, a, a if realm else b)
	if bool(ch.get("short", false)):
		var c: Dictionary = setting("charge")
		plan["why"] = text("refuse_charge", {"n": c["n"], "what": GameMaterials.name_of(str(c["material"])).to_lower() + " or an essence"})
		return plan
	plan["ok"] = true
	plan["charge"] = ch
	plan["seconds"] = travel_seconds(d, a, a if realm else b) if not realm else float((setting("travel") as Dictionary)["base_seconds"])
	return plan


## Takes the charge of a trip from the stores; returns the line to tell.
static func pay_charge(d: GameDynasty, ch: Dictionary) -> String:
	if ch.has("material"):
		GameCraft.add_material(d, str(ch["material"]), -int(ch["n"]))
		return text("charge_silver", {"n": ch["n"]})
	if ch.has("essence"):
		GameCraft.add_essence(d, str(ch["essence"]), -int(ch["n"]))
		return text("charge_essence", {"what": GameCraft._affix_label(str(ch["essence"]))})
	return ""


# ---------------------------------------------------------------- the realms' arrival grounds

const REALM_SPACE := "realm/"


## The space id of a realm's arrival ground.
static func realm_space(realm: String) -> String:
	return REALM_SPACE + realm


## The realm a space id is the arrival ground of ("" for any other space).
static func realm_of_space(space: String) -> String:
	if space.begins_with(REALM_SPACE) and GameRealms.gateable(space.substr(REALM_SPACE.length())):
		return space.substr(REALM_SPACE.length())
	return ""


## The look of a realm's arrival ground: {floor, floor2, wall, glow, sky} as colours (the palette of the realm's mark).
static func look(realm: String) -> Dictionary:
	var out := {}
	var l: Dictionary = data()["looks"].get(realm, {})
	for k in l:
		out[k] = Color(float(l[k][0]), float(l[k][1]), float(l[k][2]))
	return out


## The cells of a realm's arrival ground, as an interior's (GameInterior: floor, exit, wall): a rounded clearing `width` by `depth` north of the
## tile the heir comes in on, which is the `exit` (the return gate stands over it), with a few pillars of the realm's own stone and a wall all
## round. Pure and the same for every seed; every floor tile can be walked to from the exit.
static func arrival_cells(realm: String) -> Dictionary:
	var s: Dictionary = setting("realm_arrival")
	var w := int(s["width"])
	var dep := int(s["depth"])
	var out := {}
	var half := w / 2
	for z in range(-(dep - 1), 1):
		for x in range(-half, half + 1):
			var cx := float(x) / float(half)
			var cz := float(z + (dep - 1) / 2) / float((dep - 1) / 2)   # -1 to 1 over the depth
			var corner := absf(cx) > 0.55 and absf(cz) > 0.55 and (absf(cx) - 0.55) + (absf(cz) - 0.55) > 0.5
			if not corner:
				out[GameInterior.key(x, z)] = "floor"
	out[GameInterior.key(0, 0)] = "exit"
	# pillars: single tiles, never beside each other, never within two tiles of the way in
	var r := RandomNumberGenerator.new()
	r.seed = hash(["gate_arrival", realm])
	var placed := 0
	var tries := 0
	var pillars: Array = []
	while placed < int(s["pillars"]) and tries < 200:
		tries += 1
		var px := r.randi_range(-half + 2, half - 2)
		var pz := r.randi_range(-(dep - 3), -3)
		var k := GameInterior.key(px, pz)
		if out.get(k, "") != "floor" or Vector2(px, pz).length() < 4.0:
			continue
		var apart := true
		for p in pillars:
			if maxi(absi(px - int(p.x)), absi(pz - int(p.y))) < 3:
				apart = false
		if apart:
			pillars.append(Vector2i(px, pz))
			placed += 1
	var walls := {}
	for k in out:
		var c := GameInterior._parse(k)
		for a in GameInterior.AROUND:
			var n: Vector2i = c + a
			if not out.has(GameInterior.key(n.x, n.y)):
				walls[GameInterior.key(n.x, n.y)] = "wall"
	for k in walls:
		out[k] = "wall"
	for p in pillars:
		out[GameInterior.key(p.x, p.y)] = "wall"
	return out


## The creatures of a realm that stand in its arrival ground: [{id, x, z}], a few of the creatures `realms.json` puts in that realm, on floor tiles
## `keep` or more from the way in, picked by a hash of the seed and the realm (never the dynasty's dice). The seam for the realm's wildlife: the
## ground lists them and tests check them; the sandbox does not yet set them on the floor.
static func arrival_creatures(d: GameDynasty, realm: String) -> Array:
	var pool: Array = []
	var of: Dictionary = GameRealms.data()["of"]
	for c in of:
		if str(of[c]) == realm:
			pool.append(str(c))
	pool.sort()
	var cells := arrival_cells(realm)
	var floors: Array = []
	for k in cells:
		if cells[k] == "floor":
			var c := GameInterior._parse(k)
			if Vector2(c).length() >= float(setting("realm_arrival")["keep"]):
				floors.append(c)
	floors.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	var out: Array = []
	if pool.is_empty() or floors.is_empty():
		return out
	var r := _rng(d, "arrival", realm)
	for i in mini(int(setting("realm_arrival")["creatures"]), floors.size()):
		var at: Vector2i = floors.pop_at(r.randi() % floors.size())
		out.append({"id": str(pool[r.randi() % pool.size()]), "x": at.x, "z": at.y})
	return out


# ---------------------------------------------------------------- what is saved

static func _year_ok(v: Variant) -> bool:
	return typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)) and float(v) >= 0.0 and float(v) < 100000.0


## The state as it loads: only well-formed ids and whole numbers; {} for anything else (a corrupt part is dropped on its own).
static func load_state(v: Variant) -> Dictionary:
	var out := {}
	if typeof(v) != TYPE_DICTIONARY:
		return out
	var cap := 200
	if typeof(v.get("runes")) == TYPE_ARRAY:
		var l: Array = []
		for r in v["runes"]:
			if typeof(r) == TYPE_STRING and data()["runes"].has(r) and r not in l:
				l.append(r)
		if not l.is_empty():
			out["runes"] = l
	if typeof(v.get("found")) == TYPE_ARRAY:
		var l: Array = []
		for r in v["found"]:
			if typeof(r) == TYPE_STRING and has(r) and r not in l and l.size() < cap:
				l.append(r)
		if not l.is_empty():
			out["found"] = l
	if typeof(v.get("fixed")) == TYPE_DICTIONARY:
		var f := {}
		for k in v["fixed"]:
			var y: Variant = v["fixed"][k]
			var p := str(k).split(":")
			if typeof(k) == TYPE_STRING and p.size() == 2 and has(p[0]) and p[1].is_valid_int() and int(p[1]) >= 0 and int(p[1]) < slot_count(p[0]) \
					and typeof(y) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(y)) and float(y) >= 0.0 and float(y) < 100000.0:
				f[k] = int(y)
		if not f.is_empty():
			out["fixed"] = f
	if typeof(v.get("guard")) == TYPE_DICTIONARY:
		var g := {}
		for k in v["guard"]:
			var r: Variant = v["guard"][k]
			if typeof(k) == TYPE_STRING and has(k) and typeof(r) == TYPE_DICTIONARY and typeof(r.get("id")) == TYPE_STRING \
					and _year_ok(r.get("since")) and _year_ok(r.get("seen")):
				var past: Array = []
				if typeof(r.get("past")) == TYPE_ARRAY:
					for p in r["past"]:
						if typeof(p) == TYPE_ARRAY and (p as Array).size() == 2 and _year_ok(p[0]) and _year_ok(p[1]) and past.size() < 20:
							past.append([int(p[0]), int(p[1])])
				g[k] = {"id": str(r["id"]), "since": int(r["since"]), "seen": int(r["seen"]), "past": past}
		if not g.is_empty():
			out["guard"] = g
	return out


# ---------------------------------------------------------------- the data's own check

static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["note", "settings", "networks", "runes", "gates", "text"]:
		if not dat.has(k):
			bad.append("gates.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var s: Dictionary = dat["settings"]
	for k in ["reach", "see_range", "search", "flat_max", "min_gap", "front_search", "year_cap", "theft_chance", "wear_jitter", "dark_at", "start_split", "sizes", "size_cost", "repair", "silver", "silver_price", "silver_buy_max", "charge", "travel", "known_at_start", "lore", "scribe"]:
		if not s.has(k):
			bad.append("gates.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if float(s["reach"]) <= 0.0 or float(s["see_range"]) < float(s["reach"]):
		bad.append("gates.json: reach must be above 0 and see_range at least reach")
	if float(s["theft_chance"]) < 0.0 or float(s["theft_chance"]) > 1.0:
		bad.append("gates.json: theft_chance is a chance, 0 to 1")
	if float(s["wear_jitter"]) < 0.0 or float(s["wear_jitter"]) >= 1.0:
		bad.append("gates.json: wear_jitter must be 0 up to (not including) 1")
	if int(s["dark_at"]) < 1:
		bad.append("gates.json: dark_at must be at least 1")
	var split := 0.0
	for k in ["worn", "broken", "stripped"]:
		split += float(s["start_split"].get(k, -1.0))
		if not s["repair"].has(k):
			bad.append("gates.json: repair.%s is missing" % k)
	if absf(split - 1.0) > 0.001:
		bad.append("gates.json: start_split must add up to 1")
	for k in s["repair"]:
		if int(s["repair"][k].get("silver", 0)) < 1 or int(s["repair"][k].get("gold", 0)) < 1:
			bad.append("gates.json: repair.%s needs silver and gold of at least 1" % k)
	if not GameMaterials.has(str(s["silver"])):
		bad.append("gates.json: the silver '%s' is no material" % s["silver"])
	if not GameMaterials.has(str(s["charge"].get("material", ""))):
		bad.append("gates.json: the charge material is no material")
	if float(s["travel"].get("base_seconds", -1.0)) < 0.0 or float(s["travel"].get("cap_seconds", 0.0)) < float(s["travel"].get("base_seconds", 0.0)):
		bad.append("gates.json: travel needs a base of 0 or more and a cap at least the base")
	if not GameSubclass.has(str(s["scribe"])):
		bad.append("gates.json: settings.scribe is no subclass")
	for r in s["known_at_start"]:
		if not dat["runes"].has(r):
			bad.append("gates.json: known_at_start names no rune '%s'" % r)
	for k in dat["runes"]:
		var r: Dictionary = dat["runes"][k]
		for f in ["name", "wear", "cost", "lore", "weight"]:
			if not r.has(f):
				bad.append("gates.json: rune '%s' has no %s" % [k, f])
		if float(r.get("wear", 0.0)) <= 0.0 or float(r.get("wear", 0.0)) > 0.5:
			bad.append("gates.json: rune '%s' wear must be above 0 and at most 0.5 a year" % k)
		if r.has("realm") and not GameRealms.gateable(str(r["realm"])):
			bad.append("gates.json: rune '%s' names no gateable realm" % k)
	var seen := {}
	var realms_done := {}
	for g in dat["gates"]:
		var id := str(g.get("id", ""))
		if id == "" or seen.has(id):
			bad.append("gates.json: a gate has no id or repeats '%s'" % id)
		seen[id] = true
		for f in ["name", "size", "networks", "anchor", "whole", "exposure", "runes"]:
			if not g.has(f):
				bad.append("gates.json: gate '%s' has no %s" % [id, f])
		if not g.has("runes") or not g.has("size"):
			continue
		if not s["sizes"].has(str(g["size"])):
			bad.append("gates.json: gate '%s' has an unknown size" % id)
		elif (g["runes"] as Array).size() != int(s["sizes"][str(g["size"])]):
			bad.append("gates.json: gate '%s' has %d runes but its size takes %d" % [id, (g["runes"] as Array).size(), int(s["sizes"][str(g["size"])])])
		if (g["runes"] as Array).size() < 4 or (g["runes"] as Array).size() > 7:
			bad.append("gates.json: gate '%s' must have 4 to 7 rune slots" % id)
		for r in g["runes"]:
			if not dat["runes"].has(r):
				bad.append("gates.json: gate '%s' uses no rune '%s'" % [id, r])
		if int(g.get("whole", 0)) < 0 or int(g.get("whole", 0)) > (g["runes"] as Array).size():
			bad.append("gates.json: gate '%s' starts with a number of whole slots that does not fit" % id)
		if float(g.get("exposure", 1.0)) < 0.0:
			bad.append("gates.json: gate '%s' has a negative exposure" % id)
		for n in g.get("networks", []):
			if not dat["networks"].has(n):
				bad.append("gates.json: gate '%s' is on no network '%s'" % [id, n])
		var a: Dictionary = g.get("anchor", {})
		if a.has("realm"):
			if not GameRealms.gateable(str(a["realm"])) or str(g.get("realm", "")) != str(a["realm"]):
				bad.append("gates.json: gate '%s' stands for a realm it is not the door of" % id)
		elif GameWorldGen.anchor(str(a.get("place", ""))).is_empty():
			bad.append("gates.json: gate '%s' is anchored to no place" % id)
		if g.has("realm"):
			var rn := str(g["realm"])
			if not GameRealms.gateable(rn):
				bad.append("gates.json: gate '%s' is the door of no gateable realm" % id)
			if realms_done.has(rn):
				bad.append("gates.json: two gates are the door of '%s'" % rn)
			realms_done[rn] = true
			var has_key := false
			for r in g["runes"]:
				if str(dat["runes"].get(r, {}).get("realm", "")) == rn:
					has_key = true
			if not has_key:
				bad.append("gates.json: the gate of '%s' has no rune of its own realm" % rn)
	for r in GameRealms.ids():
		if GameRealms.gateable(str(r)) and not realms_done.has(str(r)):
			bad.append("gates.json: the realm '%s' has no gate" % r)
	for r in GameRealms.ids():
		if GameRealms.gateable(str(r)):
			var lk: Dictionary = dat.get("looks", {}).get(str(r), {})
			for f in ["floor", "floor2", "wall", "glow", "sky"]:
				if typeof(lk.get(f)) != TYPE_ARRAY or (lk[f] as Array).size() != 3:
					bad.append("gates.json: the look of '%s' has no [r, g, b] for %s" % [r, f])
	var ra: Dictionary = s.get("realm_arrival", {})
	for k in ["width", "depth", "pillars", "creatures", "keep"]:
		if int(ra.get(k, -1)) < 0:
			bad.append("gates.json: realm_arrival.%s is missing" % k)
	if int(ra.get("width", 0)) < 9 or int(ra.get("depth", 0)) < 7:
		bad.append("gates.json: an arrival ground needs at least 9 by 7 tiles")
	for k in dat["text"]:
		if typeof(dat["text"][k]) != TYPE_STRING:
			bad.append("gates.json: text.%s is not a line" % k)
	return bad
