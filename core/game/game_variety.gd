## Variety in the fights of the open world (data/combat/elites.json): elite foes with a name, a change of stats and a bigger
## reward; attack patterns (a heavy blow announced the round before, a guard that braces, a creature that calls for help); and the
## phases of a legend (at set shares of its health it enrages, takes up a pattern or calls its servants). All of it is switched on
## by `GameBattle.variety`, which only the open world sets (GameDynasty.start_encounter given variety keys, and a dungeon's legend,
## GameDynasty.start_legend_at with `variety`). A hunt, a hunt-board legend and every fight the autopilot or the golden scenarios
## play leave it off, and then none of the hooks in GameBattle does anything: those fights draw and play exactly as before.
## Every roll here is a keyed hash of the dynasty's seed, the tile or place and the creature (like GameLevels), never the
## dynasty's dice, so a tile holds the same elite every time and no draw of any other fight shifts.
## What a foe carries is in its own dictionary (saved with the fight): `elite` (the mod's id) and `v`, the runtime part:
## taken, drain, rage, lead, `pt` (pattern id -> its state), `kin` (the foe it calls), `reserve` (a legend's servants by phase),
## `phase` (the next one), `now` (this blow's multiplier), `guard`/`guard_t` (a brace). Read with casts: a save may turn ints to floats.
## The intro card, the arena and the victory beat for a legend are presentation only and show for every legend fight.
## Run: godot --headless --path . -s res://tests/test_game_variety.gd
class_name GameVariety
extends RefCounted

const PATH := "res://data/combat/elites.json"

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		var v: Variant = GameData.load_json(PATH)
		_cache = v if typeof(v) == TYPE_DICTIONARY else {}
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func mods() -> Dictionary:
	return data()["mods"]


static func pattern(id: String) -> Dictionary:
	return data()["patterns"].get(id, {})


static func boss(id: String) -> Dictionary:
	return data()["bosses"].get(id, {})


## A fresh dice keyed on the dynasty's seed, a purpose and what it is for: the same every time, and none of the dynasty's own.
static func keyed(seed_value: int, tag: String, key: Variant) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, "variety", tag, key])
	return r


static func _v(e: Dictionary) -> Dictionary:
	var v: Variant = e.get("v", {})
	return v if typeof(v) == TYPE_DICTIONARY else {}


# ---------------------------------------------------------------- building the foes

## Gives the foes of a fight from the open world their elite, their pattern and, for a legend, its phases. `keys` holds what each
## foe stands for (its tile, its place and room), one per foe. Draws nothing from the dynasty.
static func dress(d: GameDynasty, foes: Array, keys: Array) -> void:
	var seed_value := d.seed_value
	var elite_given := false
	var lead_key: Variant = keys[0] if not keys.is_empty() else 0
	if foes.size() >= int(setting("leader_min_foes")) and keyed(seed_value, "leader", lead_key).randf() < float(setting("leader_chance")):
		var best := -1
		for n in foes.size():
			if not bool(foes[n].get("boss", false)) and not bool(foes[n].get("fearful", false)) and (best < 0 or int(foes[n]["level"]) > int(foes[best]["level"])):
				best = n
		if best >= 0:
			_give(d, foes[best], "pack_leader")
			elite_given = true
	for n in foes.size():
		var foe: Dictionary = foes[n]
		if bool(foe.get("boss", false)):
			continue
		var key: Variant = keys[n] if n < keys.size() else n
		var r := keyed(seed_value, "elite", [key, str(foe["id"]), int(foe["level"])])
		if not elite_given and not bool(foe.get("fearful", false)):
			var chance := float(setting("elite_chance")) * float((setting("chance_by_con") as Dictionary).get(str(foe.get("con", "even")), 1.0))
			if r.randf() < chance:
				_give(d, foe, _pick_mod(r))
				elite_given = true
		if not bool(foe.get("fearful", false)):
			_pattern_for(d, foe, keyed(seed_value, "pattern", [key, str(foe["id"])]))


static func _pick_mod(r: RandomNumberGenerator) -> String:
	var ids: Array = mods().keys()
	ids.sort()
	var total := 0.0
	for id in ids:
		if not bool(mods()[id].get("pack_only", false)):
			total += float(mods()[id].get("weight", 1))
	var pick := r.randf() * total
	var last := ""
	for id in ids:
		if bool(mods()[id].get("pack_only", false)):
			continue
		last = id
		pick -= float(mods()[id].get("weight", 1))
		if pick < 0.0:
			return id
	return last


## An elite: the mod's prefix and stat changes, its bigger reward, and the numbers its rules read in battle.
static func _give(d: GameDynasty, foe: Dictionary, id: String) -> void:
	var m: Dictionary = mods()[id]
	var v := _v(foe)
	foe["elite"] = id
	foe["name"] = "%s %s" % [str(m["name"]), str(foe["name"])]
	foe["max_hp"] = maxi(1, int(round(float(foe["max_hp"]) * float(m.get("hp", 1.0)))))
	foe["hp"] = foe["max_hp"]
	foe["atk"] = float(foe["atk"]) * float(m.get("atk", 1.0))
	foe["def"] = float(foe["def"]) * float(m.get("def", 1.0))
	foe["agi"] = float(foe["agi"]) * float(m.get("agi", 1.0))
	foe["xp"] = int(round(float(foe["xp"]) * float(m.get("reward", 1.0))))
	foe["gold"] = int(round(float(foe["gold"]) * float(m.get("reward", 1.0))))
	for k in ["taken", "drain", "rage", "lead"]:
		if m.has(k):
			v[k] = float(m[k])
	foe["v"] = v


## A pattern the creature's kind has, if the keyed dice say so.
static func _pattern_for(d: GameDynasty, foe: Dictionary, r: RandomNumberGenerator) -> void:
	var list: Array = (data()["assign"] as Dictionary).get(str(foe["id"]), [])
	if list.is_empty() or r.randf() >= float(setting("pattern_chance")):
		return
	add_pattern(d, foe, str(list[r.randi() % list.size()]), r)


## Gives a foe a pattern with its place in the cycle (the dice's), and for a call the kin that will answer it.
static func add_pattern(d: GameDynasty, foe: Dictionary, id: String, r: RandomNumberGenerator) -> void:
	var p := pattern(id)
	if p.is_empty():
		return
	var v := _v(foe)
	var pt: Dictionary = v.get("pt", {})
	pt[id] = {"off": r.randi() % maxi(1, int(p.get("every", 3))), "wind_t": -1, "done": false}
	v["pt"] = pt
	if id == "call" and d != null and not v.has("kin"):
		v["kin"] = kin(d, str(foe["id"]), maxi(1, int(round(float(foe["level"]) * float((setting("kin") as Dictionary)["level"])))))
	foe["v"] = v


## A lesser foe of the creature's kind (the one a call brings, or a legend's servant): weaker, and worth little.
static func kin(d: GameDynasty, creature_id: String, level: int) -> Dictionary:
	var k := d.foe_for(creature_id, level)
	if k.is_empty():
		return {}
	var s: Dictionary = setting("kin")
	k["max_hp"] = maxi(1, int(round(float(k["max_hp"]) * float(s["hp"]))))
	k["hp"] = k["max_hp"]
	k["atk"] = float(k["atk"]) * float(s["atk"])
	k["def"] = float(k["def"]) * float(s["def"])
	k["xp"] = int(round(float(k["xp"]) * float(s["reward"])))
	k["gold"] = int(round(float(k["gold"]) * float(s["reward"])))
	k["boss"] = false
	return k


## A legend's phases: its servants are made now (the dynasty's numbers are at hand), kept until the phase comes.
static func dress_boss(d: GameDynasty, foe: Dictionary) -> void:
	var phases: Array = boss(str(foe["id"])).get("phases", [])
	if phases.is_empty():
		return
	var v := _v(foe)
	var reserve: Dictionary = {}
	for n in phases.size():
		var made: Array = []
		for sid in phases[n].get("summon", []):
			var k := kin(d, str(sid), maxi(1, int(round(float(foe["level"]) * float((setting("kin") as Dictionary)["level"])))))
			if not k.is_empty():
				made.append(k)
		if not made.is_empty():
			reserve[str(n)] = made
	v["phase"] = 0
	v["reserve"] = reserve
	foe["v"] = v


# ---------------------------------------------------------------- what the battle asks (only when `variety` is on)

## How much harder the foe's blow lands: the rage of a berserker, a pack leader's lead, this blow's heavy multiplier.
static func blow_mult(b: GameBattle, i: int) -> float:
	var e: Dictionary = b.enemies[i]
	var v := _v(e)
	var m := 1.0
	if v.has("rage"):
		m *= 1.0 + float(v["rage"]) * clampf(1.0 - float(e["hp"]) / maxf(1.0, float(e["max_hp"])), 0.0, 1.0)
	for j in b.enemies.size():
		if j != i and int(b.enemies[j]["hp"]) > 0 and float(_v(b.enemies[j]).get("lead", 0.0)) > 0.0:
			m *= 1.0 + float(_v(b.enemies[j])["lead"])
			break
	return m * float(v.get("now", 1.0))


## The share of a blow the foe takes: a warded one less, a braced one less still.
static func taken_mult(b: GameBattle, i: int) -> float:
	if i < 0 or i >= b.enemies.size():
		return 1.0
	var v := _v(b.enemies[i])
	return float(v.get("taken", 1.0)) * float(v.get("guard", 1.0))


## A blow just landed: a heavy one is marked for the screen, and a vampire drinks.
static func landed(b: GameBattle, i: int, dealt: int) -> void:
	var e: Dictionary = b.enemies[i]
	var v := _v(e)
	if float(v.get("now", 1.0)) > 1.0 and not b.events.is_empty() and str(b.events.back().get("type", "")) == "damage":
		b.events.back()["heavy"] = true
	var drain := float(v.get("drain", 0.0))
	if drain > 0.0 and dealt > 0 and int(e["hp"]) > 0:
		var gain := mini(int(e["max_hp"]) - int(e["hp"]), int(round(float(dealt) * drain)))
		if gain > 0:
			e["hp"] = int(e["hp"]) + gain
			b._say(GameMessages.line("drains", {"name": e["name"], "n": gain}))


## The foe's blow is done: the heavy multiplier is spent.
static func end_blow(b: GameBattle, i: int) -> void:
	var e: Dictionary = b.enemies[i]
	if e.has("v") and _v(e).has("now"):
		_v(e).erase("now")


## The start of a foe's turn: a legend that has fallen below a phase's share takes it up.
static func begin_turn(b: GameBattle, i: int) -> void:
	var e: Dictionary = b.enemies[i]
	var v := _v(e)
	if not v.has("phase") or not bool(e.get("boss", false)):
		return
	var phases: Array = boss(str(e["id"])).get("phases", [])
	while int(v["phase"]) < phases.size() and float(e["hp"]) <= float(phases[int(v["phase"])]["at"]) * float(e["max_hp"]):
		_phase(b, i, v, int(v["phase"]), phases[int(v["phase"])])
		v["phase"] = int(v["phase"]) + 1


static func _phase(b: GameBattle, i: int, v: Dictionary, n: int, ph: Dictionary) -> void:
	var e: Dictionary = b.enemies[i]
	e["atk"] = float(e["atk"]) * float(ph.get("atk", 1.0))
	e["def"] = float(e["def"]) * float(ph.get("def", 1.0))
	b.events.append({"type": "phase", "index": i, "step": n + 1})
	if ph.has("summon"):
		b._say(GameMessages.line("phase_summon", {"name": e["name"]}))
	elif ph.has("pattern"):
		b._say(GameMessages.line("phase_pattern", {"name": e["name"]}))
	else:
		b._say(GameMessages.line("phase_enrage", {"name": e["name"]}))
	if ph.has("pattern"):
		add_pattern(null, e, str(ph["pattern"]), keyed(0, "phase", [str(e["id"]), n]))
	for k in (v.get("reserve", {}) as Dictionary).get(str(n), []):
		_spawn(b, (k as Dictionary).duplicate(true), i)


## A new foe joins the fight, last in the line; the places are worked out again and the screen is told.
static func _spawn(b: GameBattle, foe: Dictionary, by: int) -> void:
	if b.living_enemies().size() >= int(setting("max_foes")):
		return
	foe.erase("row")
	b.enemies.append(foe)
	GameCombat.place_enemies(b.enemies)
	b.events.append({"type": "summon", "index": b.enemies.size() - 1, "by": by, "name": str(foe["name"])})
	b._say(GameMessages.line("joins", {"name": foe["name"]}))


## The foe's action is about to be taken. True when this turn was spent on something else (a brace, an answered call); false
## when it strikes as usual, and then this blow may be a heavy one (`now`), announced the round before.
static func act(b: GameBattle, i: int) -> bool:
	var e: Dictionary = b.enemies[i]
	var v := _v(e)
	var pts: Dictionary = v.get("pt", {})
	if pts.is_empty():
		return false
	if float(v.get("guard", 1.0)) != 1.0 and int(v.get("guard_t", -1)) < b.turn:
		v["guard"] = 1.0
	var t := b.turn
	if pts.has("call") and not bool(pts["call"]["done"]):
		var st: Dictionary = pts["call"]
		var p := pattern("call")
		if int(st["wind_t"]) >= 0 and int(st["wind_t"]) < t:
			st["done"] = true
			var k: Dictionary = (v.get("kin", {}) as Dictionary).duplicate(true)
			if not k.is_empty():
				for _n in int(p.get("count", 1)):
					_spawn(b, k.duplicate(true), i)
			return true
		if int(st["wind_t"]) < 0 and float(e["hp"]) < float(p["below"]) * float(e["max_hp"]):
			st["wind_t"] = t
			b.events.append({"type": "wind_up", "index": i, "pattern": "call"})
			b._say(GameMessages.line("wind_up_call", {"name": e["name"]}))
			return false
	if pts.has("brace"):
		var st: Dictionary = pts["brace"]
		var p := pattern("brace")
		var every := int(p["every"])
		if int(st["wind_t"]) != t and (t + int(st["off"])) % every == every - 1:
			st["wind_t"] = t
			v["guard"] = float(p["taken"])
			v["guard_t"] = t
			b.events.append({"type": "guard_up", "index": i})
			b._say(GameMessages.line("guard_up", {"name": e["name"]}))
			return true
	if pts.has("heavy"):
		var st: Dictionary = pts["heavy"]
		var p := pattern("heavy")
		var every := int(p["every"])
		if int(st["wind_t"]) >= 0 and int(st["wind_t"]) < t:
			st["wind_t"] = -1
			v["now"] = float(p["mult"])
			b._say(GameMessages.line("heavy_blow", {"name": e["name"]}))
		elif int(st["wind_t"]) < 0 and (t + int(st["off"])) % every == every - 2:
			st["wind_t"] = t
			b.events.append({"type": "wind_up", "index": i, "pattern": "heavy"})
			b._say(GameMessages.line("wind_up_heavy", {"name": e["name"]}))
	return false


# ---------------------------------------------------------------- the legend's stage (presentation, for every legend fight)

## The boss of a fight, as an index, or -1.
static func boss_index(b: GameBattle) -> int:
	for i in b.enemies.size():
		if bool(b.enemies[i].get("boss", false)):
			return i
	return -1


## What the title card shows as a legend's fight begins: {name, epithet} or {} when the fight has no legend.
static func intro(b: GameBattle) -> Dictionary:
	var i := boss_index(b)
	if i < 0:
		return {}
	var id := str(b.enemies[i]["id"])
	var name := str(GameCombat.creature_def(id).get("short", b.enemies[i]["name"]))
	return {"name": name, "epithet": str(boss(id).get("epithet", ""))}


## The place whose scenery the fight is staged in: a legend's lair (or the arena its row names), "" for any other fight.
static func arena_place(b: GameBattle) -> String:
	var i := boss_index(b)
	if i < 0:
		return ""
	var id := str(b.enemies[i]["id"])
	var own := str(boss(id).get("arena", ""))
	if own != "":
		return own
	var lair := str(GameCombat.creature_def(id).get("lair", ""))
	return lair if not GameWorld.place(lair).is_empty() else ""


## The beat after a legend falls: {title, heirloom, claimed, line} or {} (no legend slain). Call after GameDynasty.finish_battle,
## given how many heirlooms the house held before it.
static func victory_beat(d: GameDynasty, b: GameBattle, held_before: int) -> Dictionary:
	if b.result != "victory":
		return {}
	for e in b.enemies:
		if bool(e.get("boss", false)) and int(e["hp"]) <= 0 and not bool(e.get("fled", false)):
			var claimed := d.heirlooms.size() > held_before
			var heirloom := str(e.get("heirloom", ""))
			var short := str(GameCombat.creature_def(str(e["id"])).get("short", e["name"]))
			var out := {"title": GameMessages.line("boss_falls", {"name": short}), "heirloom": heirloom, "claimed": claimed, "line": ""}
			if heirloom != "":
				out["line"] = GameMessages.line("boss_heirloom" if claimed else "boss_heirloom_held", {"heirloom": heirloom})
			return out
	return {}


# ---------------------------------------------------------------- the data's own check

static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "mods", "patterns", "assign", "bosses"]:
		if typeof(dat.get(k)) != TYPE_DICTIONARY:
			return ["elites.json has no '%s'" % k]
	var s: Dictionary = dat["settings"]
	for k in ["elite_chance", "leader_chance", "pattern_chance"]:
		if typeof(s.get(k)) not in [TYPE_INT, TYPE_FLOAT] or float(s[k]) < 0.0 or float(s[k]) > 1.0:
			bad.append("elites: settings.%s must be a share from 0 to 1" % k)
	if typeof(s.get("leader_min_foes")) not in [TYPE_INT, TYPE_FLOAT] or int(s["leader_min_foes"]) < 2:
		bad.append("elites: settings.leader_min_foes must be at least 2")
	if typeof(s.get("max_foes")) not in [TYPE_INT, TYPE_FLOAT] or int(s["max_foes"]) < 2:
		bad.append("elites: settings.max_foes must be at least 2")
	if typeof(s.get("chance_by_con")) != TYPE_DICTIONARY:
		bad.append("elites: settings.chance_by_con is missing")
	if typeof(s.get("kin")) != TYPE_DICTIONARY:
		bad.append("elites: settings.kin is missing")
	else:
		for k in ["hp", "atk", "def", "level", "reward"]:
			if typeof(s["kin"].get(k)) not in [TYPE_INT, TYPE_FLOAT] or float(s["kin"][k]) <= 0.0:
				bad.append("elites: settings.kin.%s must be above 0" % k)
	var normal := 0
	for id in dat["mods"]:
		var m: Dictionary = dat["mods"][id]
		if str(m.get("name", "")).strip_edges() == "":
			bad.append("elites: mod '%s' has no name" % id)
		if not bool(m.get("pack_only", false)):
			normal += 1
			if float(m.get("weight", 0)) <= 0.0:
				bad.append("elites: mod '%s' needs a weight above 0" % id)
		for k in ["hp", "atk", "def", "agi", "taken"]:
			if m.has(k) and (typeof(m[k]) not in [TYPE_INT, TYPE_FLOAT] or float(m[k]) <= 0.0):
				bad.append("elites: mod '%s' %s must be above 0" % [id, k])
		for k in ["drain", "rage", "lead"]:
			if m.has(k) and (typeof(m[k]) not in [TYPE_INT, TYPE_FLOAT] or float(m[k]) <= 0.0 or float(m[k]) > 2.0):
				bad.append("elites: mod '%s' %s must be above 0 and at most 2" % [id, k])
		if typeof(m.get("reward")) not in [TYPE_INT, TYPE_FLOAT] or float(m["reward"]) < 1.0:
			bad.append("elites: mod '%s' must pay at least its foe's own reward (reward 1 or more)" % id)
	if normal == 0 or not (dat["mods"] as Dictionary).has("pack_leader"):
		bad.append("elites: there must be a normal mod and a pack_leader")
	for id in dat["patterns"]:
		if id not in ["heavy", "brace", "call"]:
			bad.append("elites: pattern '%s' is not one the battle knows (heavy, brace, call)" % id)
		var p: Dictionary = dat["patterns"][id]
		if id != "call" and int(p.get("every", 0)) < 3:
			bad.append("elites: pattern '%s' needs every >= 3, so the telegraph comes first" % id)
	if typeof(dat["patterns"].get("heavy", {}).get("mult")) not in [TYPE_INT, TYPE_FLOAT] or float(dat["patterns"].get("heavy", {}).get("mult", 0)) <= 1.0:
		bad.append("elites: heavy.mult must be above 1")
	if float(dat["patterns"].get("brace", {}).get("taken", 0)) <= 0.0 or float(dat["patterns"].get("brace", {}).get("taken", 0)) >= 1.0:
		bad.append("elites: brace.taken must be between 0 and 1")
	if float(dat["patterns"].get("call", {}).get("below", 0)) <= 0.0 or int(dat["patterns"].get("call", {}).get("count", 0)) < 1:
		bad.append("elites: call needs below above 0 and a count of at least 1")
	var known: Dictionary = {}
	for c in GameData.creatures:
		known[str(c["id"])] = c
	for id in dat["assign"]:
		if not known.has(id):
			bad.append("elites: assign names '%s', which is no creature" % id)
		if typeof(dat["assign"][id]) != TYPE_ARRAY or (dat["assign"][id] as Array).is_empty():
			bad.append("elites: assign.%s must list patterns" % id)
			continue
		for p in dat["assign"][id]:
			if not (dat["patterns"] as Dictionary).has(str(p)):
				bad.append("elites: assign.%s names the pattern '%s', which is not defined" % [id, p])
	for id in dat["bosses"]:
		if not known.has(id) or not bool(known[id].get("boss", false)):
			bad.append("elites: bosses names '%s', which is no legend" % id)
			continue
		var row: Dictionary = dat["bosses"][id]
		if str(row.get("epithet", "")).strip_edges() == "":
			bad.append("elites: boss '%s' has no epithet" % id)
		if row.has("arena") and GameWorld.place(str(row["arena"])).is_empty():
			bad.append("elites: boss '%s' has the arena '%s', which is no place" % [id, row["arena"]])
		var last := 1.0
		for ph in row.get("phases", []):
			var at := float(ph.get("at", 0.0))
			if at <= 0.0 or at >= last:
				bad.append("elites: boss '%s' phases must fall from below 1 toward 0 (at %s)" % [id, at])
			last = at
			if ph.has("pattern") and not (dat["patterns"] as Dictionary).has(str(ph["pattern"])):
				bad.append("elites: boss '%s' has a phase with the unknown pattern '%s'" % [id, ph["pattern"]])
			for sid in ph.get("summon", []):
				if not known.has(str(sid)):
					bad.append("elites: boss '%s' summons '%s', which is no creature" % [id, sid])
			if not (ph.has("atk") or ph.has("def") or ph.has("pattern") or ph.has("summon")):
				bad.append("elites: boss '%s' has a phase at %s that does nothing" % [id, at])
	return bad
