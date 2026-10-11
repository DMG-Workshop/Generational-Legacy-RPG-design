## The battle side of sickness: foes that carry it, searching the dead after a victory, toxins on
## the blade and plague vials thrown into a crowd, and sickness among the companions. Tuning and
## texts live in data/diseases/plague.json; diseases themselves in diseases.json (GameDisease).
##
## A foe's body may pass on what its creature "carries" ([{disease, chance}] in creatures.json);
## a foe that spawned "infected" carries its sickness at settings.infected_chance. Every chance
## goes through GameDisease.contagion_check, so resistances apply.
class_name GamePlague
extends RefCounted

static var _registered: Dictionary = {}
static var _vials: Dictionary = {}   # item id -> its thrown ability, built once per data load


static func data() -> Dictionary:
	GameData.load_all()
	if not is_same(_registered, GameData.plague):
		_registered = GameData.plague
		_vials.clear()
		GameCombat.add_statuses(GameData.plague.get("statuses", []))
	return GameData.plague


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary) -> String:
	return str(data()["text"][key]).format(vals)


## The colour a coated blade is shown in: its venom's.
static func toxin_color() -> Color:
	return Color(str(GameCombat.status_def(str(data()["toxin_status"])).get("color", "#9acd32")))


## The colour a plague-touched foe's name is shown in.
static func infected_color() -> Color:
	return Color(str(data()["settings"].get("infected_color", "#c8b050")))


# ---------------------------------------------------------------- carriers

## What a foe's body may pass on: [{disease, chance}].
static func carried(e: Dictionary) -> Array:
	var out: Array = []
	var inf := str(e.get("infected", ""))
	if inf != "":
		out.append({"disease": inf, "chance": float(setting("infected_chance"))})
	for c in GameCombat.creature_def(str(e.get("id", ""))).get("carries", []):
		if str(c["disease"]) != inf:
			out.append({"disease": str(c["disease"]), "chance": float(c["chance"])})
	return out


## A hunt's foes may come plague-touched: a carrier with its own sickness, anything else with one
## from the pool that fits the ground. Their name says so.
static func mark_infected(d: GameDynasty, foes: Array) -> void:
	var spawn := float(setting("infected_spawn"))
	for e in foes:
		if e.get("boss", false) or d.rng.randf() >= spawn:
			continue
		var own: Array = GameCombat.creature_def(str(e["id"])).get("carries", [])
		var id: String = str(own[0]["disease"]) if not own.is_empty() else _pool_pick(d)
		if id == "" or GameDisease.def(id).is_empty():
			continue
		e["infected"] = id
		var nm := str(e["name"])
		var prefix := str(setting("infected_prefix"))
		e["name"] = "Elite %s %s" % [prefix, nm.substr(6)] if nm.begins_with("Elite ") else "%s %s" % [prefix, nm]


static func _pool_pick(d: GameDynasty) -> String:
	var here: Array = d.world.here().get("biomes", [])
	var pool: Array = (setting("infected_pool") as Array).filter(func(p): return not p.has("biomes") or (p["biomes"] as Array).any(func(b): return b in here))
	var total := 0.0
	for p in pool:
		total += float(p["weight"])
	if total <= 0.0:
		return ""
	var roll := d.rng.randf() * total
	for p in pool:
		roll -= float(p["weight"])
		if roll < 0.0:
			return str(p["disease"])
	return str(pool.back()["disease"])


# ---------------------------------------------------------------- searching the dead

## After a victory: the bodies, until the heir searches them or moves on. Legends are not
## searched (their hoard is the heirloom). {} when there is nothing to search.
static func offer(_d: GameDynasty, b: GameBattle) -> Dictionary:
	var foes: Array = []
	var gold := 0
	for e in b.enemies:
		if e.get("boss", false):
			continue
		gold += int(e["gold"])
		foes.append({"id": str(e["id"]), "name": str(e["name"]), "carries": carried(e)})
	if foes.is_empty():
		return {}
	var chance := minf(1.0, float(setting("loot_item_chance")) + float(setting("loot_item_per_foe")) * float(foes.size()))
	return {"gold": gold, "item_chance": chance, "foes": foes}


## The chance of catching something while searching, after resistance and what the heir already has.
static func risk(d: GameDynasty) -> float:
	var clean := 1.0
	for f in d.loot.get("foes", []):
		for c in f["carries"]:
			var id := str(c["disease"])
			if not GameDisease.has(d.heir, id):
				clean *= 1.0 - float(c["chance"]) * (1.0 - GameDisease.resistance(d.heir, id))
	return 1.0 - clean


## The sicknesses among the dead, worst first: [id, ...].
static func risk_diseases(d: GameDynasty) -> Array:
	var ids: Array = []
	for f in d.loot.get("foes", []):
		for c in f["carries"]:
			if str(c["disease"]) not in ids:
				ids.append(str(c["disease"]))
	ids.sort_custom(func(a, b): return _worse(a, b))
	return ids


static func _worse(a: String, b: String) -> bool:
	if GameDisease.is_lethal(a) != GameDisease.is_lethal(b):
		return GameDisease.is_lethal(a)
	return float(GameDisease.def(a).get("cures", {}).get("temple", 1.0)) > float(GameDisease.def(b).get("cures", {}).get("temple", 1.0))


## "Two of the dead carry sickness (Grave Rot, Red Flux): about a 2% risk." for the result screen.
static func risk_text(d: GameDynasty) -> String:
	var n := 0
	for f in d.loot.get("foes", []):
		if not (f["carries"] as Array).is_empty():
			n += 1
	if n == 0:
		return str(data()["text"]["clean"])
	var names: Array = risk_diseases(d).map(func(id): return GameDisease.disease_name(id))
	var pct := risk(d) * 100.0
	var odds := "under 1%" if pct < 1.0 else "about %d%%" % int(round(pct))
	var who := "One of the dead carries" if n == 1 else "%d of the dead carry" % n
	return "%s sickness (%s): %s risk of catching it." % [who, ", ".join(names), odds]


## Search the bodies: extra gold, maybe a find, and a contagion check for every carrier.
static func search(d: GameDynasty) -> Array:
	var loot := d.loot
	d.loot = {}
	if loot.is_empty() or d.state != "life":
		return []
	var h := d.heir
	var out: Array = []
	var spread := float(setting("loot_gold_spread"))
	var gold := maxi(1, int(round(float(loot["gold"]) * float(setting("loot_gold_share")) * (1.0 + spread * (2.0 * d.rng.randf() - 1.0)))))
	h.gold += gold
	out.append(text("search", {"h": h.name, "gold": GameText.num(gold)}))
	if d.rng.randf() < float(loot["item_chance"]):
		out.append(_find(d))
	for f in loot["foes"]:
		for c in f["carries"]:
			var line := GameDisease.contagion_check(d, h, str(c["disease"]), float(c["chance"]), "corpse")
			if line != "":
				out.append(line)
	for m in out:
		d._say(m)
	return out


static func _find(d: GameDynasty) -> String:
	var h := d.heir
	var finds: Array = setting("loot_finds")
	var total := 0.0
	for f in finds:
		total += float(f["weight"])
	var roll := d.rng.randf() * total
	var pick: Dictionary = finds.back()
	for f in finds:
		roll -= float(f["weight"])
		if roll < 0.0:
			pick = f
			break
	if pick.get("potion", false):
		h.potions += 1
		return text("search_find", {"h": h.name, "find": "a healing potion"})
	var id := str(pick["item"])
	var iname := "a " + GameItems.item_name(id)
	if GameItems.stack_max(id) > 0 and GameItems.count(h, id) >= GameItems.stack_max(id):
		var g := GameItems.sell_price(d, id)
		h.gold += g
		return text("search_full", {"h": h.name, "find": iname, "gold": GameText.num(g)})
	h.inventory.append(id)
	return text("search_find", {"h": h.name, "find": iname})


static func leave(d: GameDynasty) -> Array:
	if d.loot.is_empty():
		return []
	d.loot = {}
	var line := text("leave", {"h": d.heir.name})
	d._say(line)
	return [line]


## The autopilot (and auto-battle's result screen) searches when the risk is small, or when the
## worst sickness among the dead could be cured at a temple with gold to spare.
static func bot_wants_search(d: GameDynasty) -> bool:
	if d.loot.is_empty():
		return false
	if risk(d) <= float(setting("bot_loot_max_risk")):
		return true
	var worst: Array = risk_diseases(d)
	return d.heir.gold - GameItems.bot_reserve(d) >= GameDisease.cure_price(d, str(worst[0]))


static func bot_loot(d: GameDynasty) -> Array:
	return search(d) if bot_wants_search(d) else leave(d)


static func load_loot(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY or raw.is_empty():
		return {}
	var foes: Array = []
	for f in raw.get("foes", []):
		if typeof(f) != TYPE_DICTIONARY:
			continue
		var carries: Array = []
		for c in f.get("carries", []):
			if typeof(c) == TYPE_DICTIONARY and not GameDisease.def(str(c.get("disease", ""))).is_empty():
				carries.append({"disease": str(c["disease"]), "chance": float(c.get("chance", 0.0))})
		foes.append({"id": str(f.get("id", "")), "name": str(f.get("name", "")), "carries": carries})
	if foes.is_empty():
		return {}
	return {"gold": int(raw.get("gold", 0)), "item_chance": float(raw.get("item_chance", 0.0)), "foes": foes}


# ---------------------------------------------------------------- toxins and vials

static func _kind_in_pack(h: GameHeir, kind: String) -> Array:
	var out: Array = []
	for id in h.inventory:
		if id not in out and GameItems.kind_of(id) == kind:
			out.append(id)
	return out


## Toxins in the pack, strongest first.
static func toxins_carried(h: GameHeir) -> Array:
	var out := _kind_in_pack(h, "toxin")
	out.sort_custom(func(a, b): return float(GameItems.item_def(a)["toxin"].get("poison_pct", 0.0)) > float(GameItems.item_def(b)["toxin"].get("poison_pct", 0.0)))
	return out


## Plague vials in the pack, strongest first.
static func vials_carried(h: GameHeir) -> Array:
	var out := _kind_in_pack(h, "vial")
	out.sort_custom(func(a, b): return float(GameItems.item_def(a)["vial"].get("weaken", 0.0)) > float(GameItems.item_def(b)["vial"].get("weaken", 0.0)))
	return out


## The statuses a coated blade puts on every foe it strikes.
static func coat_statuses(item_id: String) -> Array:
	var tox: Dictionary = GameItems.item_def(item_id).get("toxin", {})
	var out: Array = [{"id": str(data()["toxin_status"]), "potency": float(tox.get("poison_pct", 0.03)), "turns": int(tox.get("turns", 3))}]
	if float(tox.get("weaken", 0.0)) > 0.0:
		out.append({"id": "weaken", "potency": float(tox["weaken"]), "turns": int(tox.get("turns", 3))})
	return out


## A thrown vial as an ability: a burst that sickens and weakens every foe inside it.
static func vial_ability(item_id: String) -> Dictionary:
	data()
	if _vials.has(item_id):
		return _vials[item_id]
	var v: Dictionary = GameItems.item_def(item_id).get("vial", {})
	var sick := str(data()["vial_status"].get(str(v.get("disease", "")), "poison"))
	var turns := int(v.get("turns", 4))
	var ab := {"name": GameItems.item_name(item_id), "item": item_id, "target": {"shape": "burst", "radius": float(setting("vial_radius"))},
		"statuses": [{"id": sick, "turns": turns}, {"id": "weaken", "potency": float(v.get("weaken", 0.1)), "turns": turns}]}
	_vials[item_id] = ab
	return ab


## Auto-battle and the autopilot coat the blade (it takes no turn) when the foes left would take
## a few blows to bring down; a quick fight is not worth a toxin.
static func auto_coat(b: GameBattle) -> void:
	if b.result != "" or b.heir_skip or not b.coating.is_empty():
		return
	var tox := toxins_carried(b.heir)
	if tox.is_empty():
		return
	var t := b.first_target()
	var hits := b.expected_hits(-1, {}, t)
	var blow := float(hits[0][1]) if not hits.is_empty() else 1.0
	var left := 0.0
	for i in b.living_enemies():
		left += float(b.enemies[i]["hp"])
	if left >= blow * float(setting("bot_coat_min_blows")):
		b.coat_blade(str(tox[0]))


## After a battle: the heir's own exposures (a toxin's backfire, a vial's splash) are rolled.
static func after_battle(d: GameDynasty, b: GameBattle) -> Array:
	var out: Array = []
	for x in b.exposures:
		var line := GameDisease.contagion_check(d, d.heir, str(x["disease"]), float(x["chance"]), str(x["source"]))
		if line != "":
			out.append(line)
	return out


# ---------------------------------------------------------------- companions

## Years pass for the party: each companion's sickness runs its course (a deadly last stage can
## take them), and the catching kinds pass between the heir and the companions.
static func party_years(d: GameDynasty, p: GameParty, years: float, msgs: Array) -> void:
	if p.members.is_empty():
		return
	var bodies: Array = [d.heir]
	for m in p.members.duplicate():
		var u := p.sick_body(d, m)
		if not u.diseases.is_empty():
			var cause := GameDisease.advance(d, u, years, msgs)
			m["hp"] = clampi(int(m["hp"]), 1, u.max_hp())
			if cause != "":
				var line := p.die_of_sickness(d, m, cause)
				d._say(line)
				msgs.append(line)
				continue
		bodies.append(u)
	var any := false
	for u in bodies:
		any = any or not (u as GameHeir).diseases.is_empty()
	if not any:
		return
	for from in bodies:
		for e in (from as GameHeir).diseases.duplicate():
			for to in bodies:
				if to == from:
					continue
				var line := GameDisease.pass_on(d, from, to, str(e["id"]), "companion", years)
				if line != "":
					d._say(line)
					msgs.append(line)


## The temple cures a companion. Returns the journal line (the caller records it).
static func cure_companion(d: GameDynasty, member_id: String, id: String) -> String:
	var p := d.party
	var m := p.member(member_id)
	var place: String = d.world.here()["name"]
	if m.is_empty():
		return "No such companion."
	if not d.world.has_service("temple"):
		return "There is no temple in %s." % place
	var u := p.sick_body(d, m)
	if not GameDisease.has(u, id):
		return "%s is not sick with %s." % [m["name"], GameDisease.disease_name(id)]
	var cost := GameDisease.cure_price(d, id, u)
	if d.heir.gold < cost:
		return "The priests ask %s gold to cure %s." % [GameText.num(cost), GameDisease.disease_name(id)]
	d.heir.gold -= cost
	GameDisease.cure(u, id)
	m["hp"] = clampi(int(m["hp"]), 1, u.max_hp())
	return text("companion_cured", {"place": place, "name": m["name"], "disease": GameDisease.disease_name(id), "gold": GameText.num(cost)})


## Between actions: the autopilot has the temple cure a sick companion when it can spare the gold,
## the deadly sicknesses first.
static func bot_tick(d: GameDynasty) -> void:
	if not d.world.has_service("temple"):
		return
	for m in d.party.members.duplicate():
		var ids: Array = (m.get("diseases", []) as Array).map(func(e): return str(e["id"]))
		ids.sort_custom(func(a, b): return _worse(a, b))
		for id in ids:
			var cost := GameDisease.cure_price(d, id, d.party.sick_body(d, m))
			if d.heir.gold - cost >= GameItems.bot_reserve(d):
				d._say(cure_companion(d, str(m["id"]), id))
