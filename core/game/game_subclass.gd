## Subclasses (roadmap item 60): a calling layered on an heir's class, none or one, picked when the dynasty is
## founded, taken later for gold, or passed to a child. Twenty callings (the Tamer, whose id is still `breeder` so old saves, replays and the harness keep working, and nineteen crafts and trades).
## Perks are multipliers on numbers the rules already have (creatures, the forge, the shops, loot, mining, building,
## farming, companions, the heir's own fights); the heir who is "founded" in it (chose it at the founding, or was
## born to it) gets them stronger. Each calling also has its own works: items in data/items/items.json that carry a
## `subclass` and a `recipe`, which only that calling can make (`work_plan`, `make`) and no shop sells. Nothing
## here draws a die from the dynasty: the child's inheritance rolls on dice keyed on the seed and the child.
## Data: data/subclasses/subclasses.json.
class_name GameSubclass
extends RefCounted

const GENERIC_NAMES := ["Magic Crafter", "Scroll Master", "Item Crafter", "Blacksmith"]

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json("res://data/subclasses/subclasses.json")
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


static func defs() -> Array:
	return data()["subclasses"]


static func def(id: String) -> Dictionary:
	for s in defs():
		if str(s["id"]) == id:
			return s
	return {}


static func has(id: String) -> bool:
	return not def(id).is_empty()


static func name_of(id: String) -> String:
	return str(def(id).get("name", id))


## The multiplier this heir's subclass puts on `key`: 1.0 with none, or one that does not name it.
static func perk(h: GameHeir, key: String) -> float:
	if h == null or h.subclass == "":
		return 1.0
	var m := float(def(h.subclass).get("perks", {}).get(key, 1.0))
	var scale := float(setting("founder_scale")) if h.subclass_founded else 1.0
	return maxf(float(setting("perk_floor")), 1.0 + (m - 1.0) * scale)


## What taking or changing to a subclass costs the heir, in gold, scaled as other prices are by the generation.
static func cost(d: GameDynasty, id: String) -> int:
	var base := float(setting("take_cost")) * float(def(id).get("price_mult", 1.0)) * GameData.enemy_scale(d.gen)
	if d.heir != null and d.heir.subclass != "" and d.heir.subclass != id:
		base *= float(setting("change_cost_mult"))
	return int(round(base))


## Why the heir cannot take this subclass now, or "".
static func why_not(d: GameDynasty, id: String) -> String:
	if d.state != "life" or d.heir == null:
		return text("outside_life")
	if not has(id):
		return GameMessages.text("life", "no_such_subclass")
	if d.heir.subclass == id:
		return text("already", {"name": name_of(id)})
	if d.heir.gold < cost(d, id):
		return text("not_enough", {"gold": GameText.num(cost(d, id))})
	return ""


## The living heir takes up (or changes to) a subclass for gold. Returns the line told, or "" if it could not be done.
## A subclass taken later is not "founded": its perks are at their plain strength.
static func take(d: GameDynasty, id: String) -> String:
	if why_not(d, id) != "":
		return ""
	var gold := cost(d, id)
	var old := d.heir.subclass
	d.heir.gold -= gold
	d.heir.subclass = id
	d.heir.subclass_founded = false
	var line := text("changed" if old != "" else "taken", {"h": d.heir.name, "name": name_of(id), "old": name_of(old), "gold": GameText.num(gold)})
	d._say(line)
	return line


## Founds an heir in a subclass (the dynasty's start): the perks are at the founded strength. "" or an unknown id leaves none.
static func found(h: GameHeir, id: String) -> void:
	if has(id):
		h.subclass = id
		h.subclass_founded = true


## At succession a child may be born to the parent's calling. The roll is keyed on the seed and the child, never
## the dynasty's dice. Returns the line to tell, or "".
static func on_succession(d: GameDynasty, parent: GameHeir, child: GameHeir) -> String:
	if parent.subclass == "" or not has(parent.subclass):
		return ""
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "subclass", child.id])
	if r.randf() >= float(setting("inherit_chance")):
		return ""
	child.subclass = parent.subclass
	child.subclass_founded = true
	var line := text("inherited", {"h": child.name, "name": name_of(parent.subclass), "parent": parent.name})
	d._say(line)
	return line


# ---------------------------------------------------------------- works (a calling's own items)

## The items only this calling can make, easiest first. An item with no `subclass` is nobody's work.
static func works(id: String) -> Array:
	GameData.load_all()
	var out: Array = []
	for item_id in GameData.items:
		if str(GameData.items[item_id].get("subclass", "")) == id and GameData.items[item_id].has("recipe"):
			out.append(str(item_id))
	out.sort_custom(func(a, b):
		var la := int(GameData.items[a]["recipe"].get("min_level", 1))
		var lb := int(GameData.items[b]["recipe"].get("min_level", 1))
		return la < lb or (la == lb and a < b))
	return out


## The calling an item belongs to ("" for any other item).
static func calling_of(item_id: String) -> String:
	return str(GameItems.item_def(item_id).get("subclass", ""))


## What making one of the calling's works would be: {ok, why, name, cost: {material: n}, fee, level}. Nothing is spent.
## `forge` is as for GameCraft.plan: "" at a town's forge, "home" at the family's own (a fraction of the fee).
static func work_plan(d: GameDynasty, item_id: String, forge: String = "") -> Dictionary:
	var def := GameItems.item_def(item_id)
	var calling := str(def.get("subclass", ""))
	if def.is_empty() or calling == "" or not def.has("recipe"):
		return {"ok": false, "why": text("work_unknown")}
	var h := d.heir
	var recipe: Dictionary = def["recipe"]
	var fee := float(recipe["fee"])
	if forge == "home":
		fee *= float(GameCraft.setting("home_fee_mult"))
	fee *= GameHouse.smithy_fee_mult(d) * perk(h, "forge_fee_mult")
	var out := {"ok": true, "why": "", "name": str(def["name"]), "cost": recipe["cost"], "fee": maxi(1, int(round(fee))), "level": int(recipe.get("min_level", 1)), "item": item_id}
	if d.state != "life" or h == null or h.subclass != calling:
		out["ok"] = false
		out["why"] = text("work_not_yours", {"name": name_of(calling)})
	elif h.level < int(out["level"]):
		out["ok"] = false
		out["why"] = text("work_level", {"level": int(out["level"])})
	elif GameItems.stack_max(item_id) <= 0 and GameItems.owns(h, item_id):
		out["ok"] = false
		out["why"] = text("work_has", {"name": str(def["name"])})
	elif GameItems.stack_max(item_id) > 0 and GameItems.count(h, item_id) >= GameItems.stack_max(item_id):
		out["ok"] = false
		out["why"] = text("work_stack", {"name": str(def["name"]), "max": GameItems.stack_max(item_id)})
	elif forge != "home" and not d.world.has_service(str(GameCraft.setting("needs_service"))):
		out["ok"] = false
		out["why"] = GameCraft.text("no_forge")
	else:
		for m in recipe["cost"]:
			if GameCraft.have(d, str(m)) < int(recipe["cost"][m]):
				out["ok"] = false
				out["why"] = text("work_short", {"material": GameMaterials.name_of(str(m)).to_lower(), "need": int(recipe["cost"][m]), "have": GameCraft.have(d, str(m))})
				return out
		if h.gold < int(out["fee"]):
			out["ok"] = false
			out["why"] = text("work_gold", {"fee": GameText.num(int(out["fee"]))})
		elif not GameCarry.can_carry(h, item_id):
			out["ok"] = false
			out["why"] = GameCarry.why_not(h, item_id)
	return out


## Makes one of the calling's works: spends the materials and the fee and puts it in the pack. Returns the line told
## (the reason it could not be made, if it could not). No dice.
static func make(d: GameDynasty, item_id: String, forge: String = "") -> String:
	var p := work_plan(d, item_id, forge)
	if not p["ok"]:
		return str(p["why"])
	for m in p["cost"]:
		GameCraft.add_material(d, str(m), -int(p["cost"][m]))
	d.heir.gold -= int(p["fee"])
	d.heir.inventory.append(item_id)
	var line := text("work_made", {"h": d.heir.name, "name": str(p["name"]), "calling": name_of(d.heir.subclass)})
	d._say(line)
	return line


## One work as a line for a screen: "Hammer-Mark Brooch (level 1): 2 iron, 20 gold. +5% defense."
static func work_line(d: GameDynasty, item_id: String, forge: String = "") -> String:
	var p := work_plan(d, item_id, forge)
	var parts: Array = []
	for m in p.get("cost", {}):
		parts.append("%d %s" % [int(p["cost"][m]), GameMaterials.name_of(str(m)).to_lower()])
	return text("works_line", {"name": GameItems.item_name(item_id), "level": int(p.get("level", 1)), "cost": ", ".join(parts), "fee": GameText.num(int(p.get("fee", 0))), "effects": GameItems.describe(item_id)})


static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)


## A perk as words: "Finding eggs and young: 40% more" (shown at the strength this heir gets it).
static func perk_lines(h: GameHeir, id: String, founded: bool) -> Array:
	var out: Array = []
	var keys: Array = def(id).get("perks", {}).keys()
	keys.sort()
	for k in keys:
		var m := float(def(id)["perks"][k])
		var scale := float(setting("founder_scale")) if founded else 1.0
		var eff := maxf(float(setting("perk_floor")), 1.0 + (m - 1.0) * scale)
		var pct := int(round(absf(eff - 1.0) * 100.0))
		out.append(text("perk_up" if eff >= 1.0 else "perk_down", {"what": _cap(str(data()["perks"].get(k, k))), "pct": str(pct)}))
	return out


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "perks", "subclasses", "text"]:
		if not dat.has(k):
			bad.append("subclasses.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var s: Dictionary = dat["settings"]
	for k in ["take_cost", "change_cost_mult", "founder_scale", "inherit_chance", "perk_floor"]:
		if not s.has(k):
			bad.append("subclasses.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if float(s["take_cost"]) < 0.0 or float(s["change_cost_mult"]) < 1.0:
		bad.append("subclasses.json: take_cost must be 0 or more and change_cost_mult at least 1")
	if float(s["founder_scale"]) < 1.0:
		bad.append("subclasses.json: founder_scale must be at least 1 (a founded subclass is never weaker)")
	if float(s["inherit_chance"]) < 0.0 or float(s["inherit_chance"]) > 1.0:
		bad.append("subclasses.json: inherit_chance must be between 0 and 1")
	if float(s["perk_floor"]) <= 0.0:
		bad.append("subclasses.json: perk_floor must be above 0")
	var seen := {}
	for sc in dat["subclasses"]:
		var id := str(sc.get("id", ""))
		if id == "" or seen.has(id):
			bad.append("subclasses.json: a subclass has no id or repeats '%s'" % id)
		seen[id] = true
		for k in ["name", "about", "perks"]:
			if not sc.has(k):
				bad.append("subclasses.json: '%s' has no %s" % [id, k])
		if sc.has("perks"):
			if (sc["perks"] as Dictionary).is_empty():
				bad.append("subclasses.json: '%s' has no perks" % id)
			for k in sc["perks"]:
				if not dat["perks"].has(k):
					bad.append("subclasses.json: '%s' has an unknown perk '%s'" % [id, k])
				elif float(sc["perks"][k]) <= 0.0:
					bad.append("subclasses.json: '%s' perk '%s' must be above 0" % [id, k])
	GameData.load_all()
	var used := {}
	for sc in dat["subclasses"]:
		for k in sc.get("perks", {}):
			used[k] = true
	for k in dat["perks"]:
		if not used.has(k):
			bad.append("subclasses.json: the perk '%s' is given by no subclass" % k)
	var names := {}
	for sc in dat["subclasses"]:
		var id2 := str(sc.get("id", ""))
		if float(sc.get("price_mult", 1.0)) <= 0.0:
			bad.append("subclasses.json: '%s' price_mult must be above 0" % id2)
		if str(sc.get("name", "")) in GENERIC_NAMES:
			bad.append("subclasses.json: '%s' has a generic name" % id2)
		if names.has(str(sc.get("name", ""))):
			bad.append("subclasses.json: the name '%s' is used twice" % sc.get("name", ""))
		names[str(sc.get("name", ""))] = true
		if works(id2).size() < 2:
			bad.append("subclasses.json: '%s' has fewer than two works (items with subclass '%s')" % [id2, id2])
	for item_id in GameData.items:
		var it: Dictionary = GameData.items[item_id]
		if not it.has("subclass") and not it.has("recipe"):
			continue
		if not seen.has(str(it.get("subclass", ""))):
			bad.append("items.json: '%s' belongs to the unknown calling '%s'" % [item_id, it.get("subclass", "")])
		if str(it.get("shop", "")) != "" or it.get("unique", false):
			bad.append("items.json: '%s' is a calling's work and cannot be sold in a shop" % item_id)
		var rec = it.get("recipe", null)
		if typeof(rec) != TYPE_DICTIONARY or typeof(rec.get("cost", null)) != TYPE_DICTIONARY or (rec["cost"] as Dictionary).is_empty() or not rec.has("fee"):
			bad.append("items.json: '%s' has a calling but no recipe with a cost and a fee" % item_id)
			continue
		if int(rec["fee"]) < 0 or int(rec.get("min_level", 1)) < 1:
			bad.append("items.json: '%s' recipe needs a fee of 0 or more and a min_level of at least 1" % item_id)
		for m in rec["cost"]:
			if not GameMaterials.has(str(m)) or int(rec["cost"][m]) < 1:
				bad.append("items.json: '%s' recipe costs the unknown material '%s' or a bad amount" % [item_id, m])
	for k in ["none", "current", "how_founded", "how_taken", "perk_up", "perk_down", "take", "change", "have", "taken", "changed", "inherited", "not_enough", "already", "outside_life", "work_unknown", "work_not_yours", "work_level", "work_has", "work_stack", "work_short", "work_gold", "work_made", "works_head", "works_line", "works_none", "works_make", "works_where"]:
		if not dat["text"].has(k):
			bad.append("subclasses.json: text.%s is missing" % k)
	return bad
