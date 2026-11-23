## Landmarks of the wilds that start fights (the `encounter` block of a landmark kind in data/world/wilds.json; specified in docs/WILDS_ENCOUNTERS.md).
## A bandit camp's guards, a battlefield's dead and a cave's lodgers are met by **approach** (the heir comes within `range` tiles) or by **use** (a
## `use_chance` percent that searching springs an ambush), once per visit, with a cooldown (`renew_years` of the world calendar and once a generation unless
## `repeatable`), until the heir wins, which **clears** the landmark for `renew_gens` generations (its outcomes, a camp's search, are then free to take) and
## pays a bonus find (`loot`). Who is met comes from the block's weighted `pool` (a creature only in its own era), how many from `count`, on dice keyed on
## the seed, the landmark and how often it has been fought, never the dynasty's; the fight itself is `GameDynasty.start_encounter` with the hunt's own rules
## (levels round the heir's, scaled by the block's `level_mult`), which draws the dynasty's dice as any sandbox fight does and nothing here does. An
## **ambush** (`hidden`) gives the foes the first blow (`GameBattle.heir_skip`) unless the heir is already below `surprise_min_hp` of their health.
## The marks are `GameDynasty.wilds.fought` ({id: {year, gen, n}}) and `cleared` ({id: gen}), saved with the rest of `wilds` only when set and loaded clean
## (`GameWildsSites.load_state`). The autopilot never walks the wilds, so no seeded life moves.
class_name GameWildsFights
extends RefCounted


static func block(lm: Dictionary) -> Dictionary:
	return {} if lm.is_empty() else GameWildsSites._def(str(lm["kind"])).get("encounter", {})


static func fought_info(d: GameDynasty, id: String) -> Dictionary:
	return d.wilds.get("fought", {}).get(id, {})


## Whether the landmark has been cleared by a win and not yet renewed.
static func cleared(d: GameDynasty, id: String) -> bool:
	var g: Variant = d.wilds.get("cleared", {}).get(id)
	return g != null and d.gen - int(g) < int(GameWilds.setting("renew_gens"))


## Whether `trigger` ("approach" or "use") can start a fight at this landmark now: it has the trigger, is not cleared, is not on cooldown (the calendar and, unless
## `repeatable`, the generation).
static func can_trigger(d: GameDynasty, lm: Dictionary, trigger: String) -> bool:
	var b := block(lm)
	if b.is_empty() or trigger not in b["triggers"] or cleared(d, str(lm["id"])):
		return false
	var f := fought_info(d, str(lm["id"]))
	if f.is_empty():
		return true
	if d.world.year - float(f["year"]) < float(b["renew_years"]):
		return false
	return bool(b.get("repeatable", false)) or int(f["gen"]) != d.gen


## The foes this landmark sends for the n-th time: a creature id list, from the pool by weight (creatures of the dynasty's era only; the first entry if none fit).
static func foes_for(d: GameDynasty, lm: Dictionary) -> Array:
	var b := block(lm)
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "wilds_fight", str(lm["id"]), int(fought_info(d, str(lm["id"])).get("n", 0))])
	var pool: Array = (b["pool"] as Array).filter(func(p): return _in_era(d, str(p["id"])))
	if pool.is_empty():
		pool = [(b["pool"] as Array)[0]]
	var c: Array = b["count"]
	var n := r.randi_range(int(c[0]), int(c[1]))
	var total := 0
	for p in pool:
		total += int(p["w"])
	var out: Array = []
	for i in n:
		var pick := r.randi() % maxi(1, total)
		for p in pool:
			pick -= int(p["w"])
			if pick < 0:
				out.append(str(p["id"]))
				break
	return out


static func _in_era(d: GameDynasty, creature_id: String) -> bool:
	for c in GameData.creatures:
		if str(c["id"]) == creature_id:
			return int(c.get("min_gen", 1)) <= d.era_gen()
	return false


## The creatures that live at a landmark and can be seen idling beside it at an hour of the day: [{id, creature, x, z, mode: "idle", uid, site}]. They are the foes the
## landmark would send next (`foes_for`), standing about the landmark's centre within the block's `dwell.radius`, each moving to a new spot every `dwell.hours` hours:
## a pure function of the seed, the landmark, how often it has been fought and the hour, never the dynasty's dice. Nobody lives at a landmark that has no `dwell`, is
## cleared (its guards are gone) or is on its cooldown (they are away or dead for now).
static func dwellers(d: GameDynasty, lm: Dictionary, hour: float) -> Array:
	var b := block(lm)
	var dw: Dictionary = {} if b.is_empty() else b.get("dwell", {})
	if dw.is_empty() or cleared(d, str(lm["id"])) or not _off_cooldown(d, lm):
		return []
	var out: Array = []
	var slot := int(floor(hour / float(dw["hours"])))
	var foes := foes_for(d, lm)
	var n := int(fought_info(d, str(lm["id"])).get("n", 0))
	for i in foes.size():
		var r := RandomNumberGenerator.new()
		r.seed = hash([d.seed_value, "wilds_dwell", str(lm["id"]), n, i, slot])
		var ang := r.randf() * TAU
		var dist := 1.0 + r.randf() * (float(dw["radius"]) - 1.0)
		out.append({"id": str(foes[i]), "creature": str(foes[i]), "x": float(lm["x"]) + 0.5 + cos(ang) * dist, "z": float(lm["z"]) + 0.5 + sin(ang) * dist, "mode": "idle", "uid": "%s#%d" % [str(lm["id"]), i], "site": str(lm["id"])})
	return out


## Whether the landmark's cooldown has run out (the calendar and, unless `repeatable`, the generation) whatever its triggers.
static func _off_cooldown(d: GameDynasty, lm: Dictionary) -> bool:
	var b := block(lm)
	var f := fought_info(d, str(lm["id"]))
	if f.is_empty():
		return true
	return d.world.year - float(f["year"]) >= float(b["renew_years"]) and (bool(b.get("repeatable", false)) or int(f["gen"]) != d.gen)


## What a trigger would start: {foes, ambush (bool), level_mult, text, loot} or {} when it cannot.
static func plan(d: GameDynasty, lm: Dictionary, trigger: String) -> Dictionary:
	if not can_trigger(d, lm, trigger):
		return {}
	var b := block(lm)
	var foes := foes_for(d, lm)
	if foes.is_empty():
		return {}
	var names: Array = foes.map(func(id): return _name(str(id)))
	var vals := {"heir": d.heir.name, "name": GameWildsSites.name_of(lm), "foes": GameMessages.text("life", "list_comma").join(names)}
	return {"foes": foes, "ambush": str(b["ambush"].get(trigger, "none")) == "hidden", "level_mult": float(b.get("level_mult", 1.0)), "text": str(b["text"][trigger]).format(vals), "trigger": trigger, "loot": float(b.get("loot", 0.0))}


static func _name(creature_id: String) -> String:
	for c in GameData.creatures:
		if str(c["id"]) == creature_id:
			return str(c["name"])
	return creature_id


## Whether searching this landmark springs an ambush this time (a roll keyed on the seed, the landmark and how often it has been fought).
static func use_springs(d: GameDynasty, lm: Dictionary) -> bool:
	var b := block(lm)
	if not can_trigger(d, lm, "use"):
		return false
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "wilds_ambush", str(lm["id"]), int(fought_info(d, str(lm["id"])).get("n", 0))])
	return r.randi_range(1, 100) <= int(b["use_chance"])


## Writes that a fight began here (the calendar year, the generation and how often): its cooldown starts now, win, flight or defeat.
static func mark_fought(d: GameDynasty, lm: Dictionary) -> void:
	var fought: Dictionary = d.wilds.get("fought", {})
	var id := str(lm["id"])
	fought[id] = {"year": d.world.year, "gen": d.gen, "n": int(fought.get(id, {}).get("n", 0)) + 1}
	d.wilds["fought"] = fought


## A win: the landmark is cleared until it renews, and pays its bonus find. Returns the lines to tell.
static func won(d: GameDynasty, lm: Dictionary) -> Array:
	var out: Array = []
	var id := str(lm["id"])
	var c: Dictionary = d.wilds.get("cleared", {})
	c[id] = d.gen
	d.wilds["cleared"] = c
	var b := block(lm)
	var vals := {"heir": d.heir.name, "name": GameWildsSites.name_of(lm)}
	out.append(str(b["text"]["won"]).format(vals))
	if float(b.get("loot", 0.0)) > 0.0:
		var item := GameWildsLoot.roll(d, str(lm["area"]), id, str(lm["kind"]), {"boost": float(b["loot"]), "n": int(fought_info(d, id).get("n", 0)), "biome": str(lm["biome"]), "slots": {}})
		if item != "":
			out.append(GameWilds.text("found_item", {"heir": d.heir.name, "item": GameWildsLoot.give(d, item)["name"]}))
	for l in out:
		d._say(l)
	return out


static func fled(d: GameDynasty, lm: Dictionary) -> String:
	var line := str(block(lm)["text"]["fled"]).format({"heir": d.heir.name, "name": GameWildsSites.name_of(lm)})
	d._say(line)
	return line


## The marks as they load: whole numbers and finite years on well-formed landmark ids only.
static func load_marks(v: Variant) -> Dictionary:
	var out := {}
	if typeof(v) != TYPE_DICTIONARY:
		return out
	var cap := 4000
	if typeof(v.get("fought")) == TYPE_DICTIONARY:
		var f := {}
		for id in v["fought"]:
			var u: Variant = v["fought"][id]
			if typeof(id) == TYPE_STRING and GameWildsSites.parse_id(id).x >= 0 and typeof(u) == TYPE_DICTIONARY and typeof(u.get("year")) in [TYPE_INT, TYPE_FLOAT] and typeof(u.get("gen")) in [TYPE_INT, TYPE_FLOAT] and typeof(u.get("n")) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(u["year"])) and is_finite(float(u["gen"])) and is_finite(float(u["n"])) and f.size() < cap:
				f[id] = {"year": float(u["year"]), "gen": int(u["gen"]), "n": maxi(1, int(u["n"]))}
		if not f.is_empty():
			out["fought"] = f
	if typeof(v.get("cleared")) == TYPE_DICTIONARY:
		var c := {}
		for id in v["cleared"]:
			var g: Variant = v["cleared"][id]
			if typeof(id) == TYPE_STRING and GameWildsSites.parse_id(id).x >= 0 and typeof(g) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(g)) and c.size() < cap:
				c[id] = int(g)
		if not c.is_empty():
			out["cleared"] = c
	return out


static func validate() -> Array:
	var bad: Array = []
	GameData.load_all()
	var found := false
	var creature_ids := {}
	for c in GameData.creatures:
		creature_ids[str(c["id"])] = c
	for kind in GameWilds.data()["landmarks"]:
		var def: Dictionary = GameWilds.data()["landmarks"][kind]
		var b: Dictionary = def.get("encounter", {})
		if b.is_empty():
			continue
		found = true
		for k in ["triggers", "pool", "count", "ambush", "renew_years", "text"]:
			if not b.has(k):
				bad.append("wilds.json: the encounter of '%s' has no %s" % [kind, k])
		if not (b.has("triggers") and b.has("pool") and b.has("count") and b.has("ambush") and b.has("text")):
			continue
		for t in b["triggers"]:
			if str(t) not in ["approach", "use"]:
				bad.append("wilds.json: '%s' has the unknown trigger '%s'" % [kind, t])
			if not b["ambush"].has(str(t)) or str(b["ambush"][str(t)]) not in ["none", "hidden"]:
				bad.append("wilds.json: '%s' needs its ambush for '%s' to be none or hidden" % [kind, t])
			if not b["text"].has(str(t)):
				bad.append("wilds.json: '%s' has no text for '%s'" % [kind, t])
		for k in ["won", "fled"]:
			if not b["text"].has(k):
				bad.append("wilds.json: '%s' has no text.%s" % [kind, k])
		var dw: Dictionary = b.get("dwell", {})
		if not dw.is_empty() and (float(dw.get("radius", 0.0)) < 1.5 or float(dw["radius"]) > 12.0 or float(dw.get("hours", 0.0)) <= 0.0 or float(dw["hours"]) > 24.0):
			bad.append("wilds.json: '%s' dwell needs a radius of 1.5 to 12 tiles and hours above 0 and at most 24" % kind)
		if "approach" in b["triggers"] and float(b.get("range", 0.0)) <= 0.0:
			bad.append("wilds.json: '%s' triggers by approach and needs a range above 0" % kind)
		if "use" in b["triggers"] and (int(b.get("use_chance", 0)) < 1 or int(b.get("use_chance", 0)) > 100):
			bad.append("wilds.json: '%s' triggers by use and needs use_chance of 1 to 100" % kind)
		if "use" in b["triggers"] and (def.get("outcomes", []) as Array).is_empty():
			bad.append("wilds.json: '%s' triggers by use but has no outcomes to search" % kind)
		var c: Array = b["count"]
		if c.size() != 2 or int(c[0]) < 1 or int(c[1]) < int(c[0]) or int(c[1]) > int(GameSandbox.setting("contact_max")):
			bad.append("wilds.json: '%s' count is [min, max] from 1 to the sandbox's contact_max" % kind)
		if float(b["renew_years"]) < 0.0 or float(b.get("level_mult", 1.0)) <= 0.0 or float(b.get("loot", 0.0)) < 0.0:
			bad.append("wilds.json: '%s' has a negative renew_years or loot, or a level_mult of 0" % kind)
		if (b["pool"] as Array).is_empty():
			bad.append("wilds.json: '%s' has an empty pool" % kind)
		var first_ok := false
		for p in b["pool"]:
			if not creature_ids.has(str(p.get("id", ""))) or int(p.get("w", 0)) < 1:
				bad.append("wilds.json: '%s' pool has the unknown creature or weight '%s'" % [kind, p.get("id", "")])
			elif bool(creature_ids[str(p["id"])].get("farm", false)):
				bad.append("wilds.json: '%s' pool has the farm animal '%s' (never fought)" % [kind, p["id"]])
			elif int(creature_ids[str(p["id"])].get("min_gen", 1)) <= 1:
				first_ok = true
		if not first_ok:
			bad.append("wilds.json: '%s' pool has no creature of the first era, so a new house could meet nothing" % kind)
	if not found:
		bad.append("wilds.json: no landmark has an encounter")
	for k in ["found_item", "surprised", "door_open"]:
		if not GameWilds.data()["text"].has(k):
			bad.append("wilds.json: text.%s is missing" % k)
	if float(GameWilds.setting("leave_mult")) < 1.0 or float(GameWilds.setting("surprise_min_hp")) < 0.0 or float(GameWilds.setting("surprise_min_hp")) > 1.0:
		bad.append("wilds.json: settings leave_mult is at least 1 and surprise_min_hp 0 to 1")
	return bad
