## Loot of the wilds' landmarks (data/items/wilds_loot.json): what a ruin, a camp, a shrine, a wreck or a lair gives, bent by the place
## it stands in (its area, or its biome on generic land), with a few themed unique items for each area. Built on the loot generator:
## a find is a `GameLoot.roll_item` kept when it fits the landmark's slot weights, rarity floor and the place's preferred materials, so
## it grows with the generation as the generator's tiers and grades do. Every roll is keyed on the seed, the area, the landmark and
## its use count, never the dynasty's dice, and only the screens' actions ask (the autopilot never does). Separate from the shops
## and the dungeons' loot; it shares only GameLoot.
class_name GameWildsLoot
extends RefCounted

const PATH := "res://data/items/wilds_loot.json"
static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


## Every themed unique the wilds can give.
static func unique_ids() -> Array:
	var out: Array = []
	for a in data()["areas"].values():
		for u in a.get("uniques", []):
			out.append(str(u["id"]))
	for b in data()["biomes"].values():
		for u in b.get("uniques", []):
			out.append(str(u["id"]))
	return out


## What applies to a landmark of a kind in a place: {boost, slots (weights), prefer, uniques, unique_mult, min_rarity}.
static func config(area: String, biome: String, kind: String) -> Dictionary:
	var dat := data()
	var k: Dictionary = dat["kinds"].get(kind, {})
	var place: Dictionary = dat["areas"].get(area, dat["biomes"].get(biome, {}))
	var slots: Dictionary = (k.get("slots", dat["settings"]["default_slots"]) as Dictionary).duplicate()
	for s in place.get("slots", {}):
		slots[s] = float(slots.get(s, 0.0)) * float(place["slots"][s])
	return {"boost": float(k.get("boost", 1.0)) * float(place.get("boost", 1.0)), "slots": slots, "prefer": place.get("prefer", []),
		"uniques": place.get("uniques", []), "unique_mult": float(k.get("unique", 1.0)) * float(place.get("unique_boost", 1.0)),
		"min_rarity": str(k.get("min_rarity", ""))}


static func _rarity_index(id: String) -> int:
	var rows: Array = GameLoot.data()["rarities"]
	for i in rows.size():
		if str(rows[i]["id"]) == id:
			return i
	return 0


## One item id for a landmark, or "" for a kind with nothing to give. `opts`: boost (a multiplier from the outcome), n (the use
## count), biome (for generic land), slots (the outcome's own slot weights, replacing the landmark's).
static func roll(d: GameDynasty, area: String, landmark_id: String, kind: String, opts: Dictionary = {}) -> String:
	var cfg := config(area, str(opts.get("biome", "")), kind)
	var slots: Dictionary = opts["slots"] if not (opts.get("slots", {}) as Dictionary).is_empty() else cfg["slots"]
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "wilds_loot", area, landmark_id, int(opts.get("n", 0)), kind])
	var chance := float(data()["settings"]["unique_chance"]) * float(cfg["unique_mult"])
	var u := r.randf()
	var pool: Array = (cfg["uniques"] as Array).filter(func(x): return int(x["min_gen"]) <= d.gen and not GameItems.owns(d.heir, str(x["id"])))
	var pick := r.randi()
	if u < chance and not pool.is_empty():
		return str(pool[pick % pool.size()]["id"])
	var names: Array = slots.keys()
	names.sort()
	var total := 0.0
	for s in names:
		total += float(slots[s])
	var roll := r.randf() * total
	var slot := str(names.back())
	for s in names:
		roll -= float(slots[s])
		if roll < 0.0:
			slot = str(s)
			break
	var boost := float(cfg["boost"]) * float(opts.get("boost", 1.0)) * GameSubclass.perk(d.heir, "rarity_mult")
	var floor_i := _rarity_index(str(cfg["min_rarity"])) if str(cfg["min_rarity"]) != "" else 0
	var best := ""
	var best_i := -1
	for t in int(data()["settings"]["tries"]):
		var ir := RandomNumberGenerator.new()
		ir.seed = r.randi()
		var id := GameLoot.roll_item(ir, d.gen, boost)
		var p := GameLoot.parse(id)
		if p.is_empty() or str(p["slot"]) != slot:
			continue
		var ri := _rarity_index(str(p["rarity"]))
		var made_of := (cfg["prefer"] as Array).is_empty()
		for tag in cfg["prefer"]:
			if tag in GameMaterials.tags_of(str(p["material"])):
				made_of = true
		if ri >= floor_i and made_of:
			return id
		var score := ri + (100 if made_of else 0)
		if score > best_i:
			best = id
			best_i = score
	if best != "":
		return best
	return GameLoot.roll_item(r, d.gen, boost)


## Puts a find in the pack (sold where it lies when too heavy, as the generator does); {name, line}.
static func give(d: GameDynasty, id: String) -> Dictionary:
	var def := GameItems.item_def(id)
	var nm := str(def.get("name", id))
	if not GameCarry.can_carry(d.heir, id):
		var heavy := GameCarry.sell_find(d, id, "a " + nm)
		d._say(heavy)
		return {"name": nm, "line": heavy}
	d.heir.inventory.append(id)
	return {"name": nm, "line": GameLoot.text("find", {"h": d.heir.name, "name": nm, "a": "a"})}


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "kinds", "areas", "biomes"]:
		if not dat.has(k):
			bad.append("wilds_loot.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	GameData.load_all()
	var s: Dictionary = dat["settings"]
	if float(s.get("unique_chance", -1)) < 0.0 or float(s["unique_chance"]) > 0.5 or int(s.get("tries", 0)) < 1:
		bad.append("wilds_loot.json: unique_chance must be 0 to 0.5 and tries at least 1")
	var rarities: Array = GameLoot.data()["rarities"].map(func(x): return str(x["id"]))
	for k in dat["kinds"]:
		if not GameWilds.data()["landmarks"].has(k):
			bad.append("wilds_loot.json: kinds has '%s', which is no landmark" % k)
		var def: Dictionary = dat["kinds"][k]
		for sl in def.get("slots", {}):
			if sl not in GameItems.SLOTS:
				bad.append("wilds_loot.json: kind '%s' weights the unknown slot '%s'" % [k, sl])
		if str(def.get("min_rarity", "")) != "" and str(def["min_rarity"]) not in rarities:
			bad.append("wilds_loot.json: kind '%s' has the unknown min_rarity '%s'" % [k, def["min_rarity"]])
		if float(def.get("boost", 1.0)) <= 0.0:
			bad.append("wilds_loot.json: kind '%s' needs a boost above 0" % k)
	for k in GameWilds.data()["landmarks"]:
		var gives: bool = false
		for o in GameWilds.data()["landmarks"][k]["outcomes"]:
			if o.has("loot"):
				gives = true
		if gives and not dat["kinds"].has(k):
			bad.append("wilds_loot.json: the landmark '%s' gives loot but has no kind here" % k)
	var seen := {}
	for group in ["areas", "biomes"]:
		for a in dat[group]:
			var def2: Dictionary = dat[group][a]
			if group == "areas" and not GameWilds.data()["areas"].has(a):
				bad.append("wilds_loot.json: loot for the area '%s', which wilds.json lacks" % a)
			if group == "biomes" and not GameWorldGen.data()["biomes"].has(a):
				bad.append("wilds_loot.json: loot for the unknown biome '%s'" % a)
			for sl in def2.get("slots", {}):
				if sl not in GameItems.SLOTS or float(def2["slots"][sl]) <= 0.0:
					bad.append("wilds_loot.json: %s '%s' has a bad slot multiplier '%s'" % [group, a, sl])
			for t in def2.get("prefer", []):
				if not GameMaterials.with_tag(str(t)).size() > 0:
					bad.append("wilds_loot.json: %s '%s' prefers the tag '%s', which no material has" % [group, a, t])
			for u in def2.get("uniques", []):
				var item: Dictionary = GameData.items.get(str(u.get("id", "")), {})
				if item.is_empty() or not bool(item.get("unique", false)) or str(item.get("shop", "")) != "":
					bad.append("wilds_loot.json: '%s' is not a unique item that no shop sells" % u.get("id", ""))
				if seen.has(str(u.get("id", ""))):
					bad.append("wilds_loot.json: the unique '%s' is listed twice" % u["id"])
				seen[str(u.get("id", ""))] = true
	for a in GameWilds.data()["areas"]:
		if not dat["areas"].has(a):
			bad.append("wilds_loot.json: the area '%s' has no loot of its own" % a)
		elif (dat["areas"][a].get("uniques", []) as Array).size() < 2:
			bad.append("wilds_loot.json: the area '%s' needs at least two themed uniques" % a)
	for b in GameWorldGen.data()["biomes"]:
		if not dat["biomes"].has(b):
			bad.append("wilds_loot.json: the biome '%s' has no loot" % b)
	return bad
