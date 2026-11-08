## Gathering and crafting (roadmap item 44). No recipe grid: an item is composed. The heir picks a form, a material they
## have gathered and up to three essences, and the result is the same kind of made item the loot generator builds (an id
## `GameLoot.build` reads), so what is made and what drops are one system. Materials come from hunts (`drops` in
## data/items/craft.json) and from salvaging gear (half the material back; a gear's affixes become essences, so a pelt
## keeps the wolf). The stores belong to the family (`GameDynasty.stores`, saved only once something is in them) and
## pass down. Crafting needs a forge; salvaging can be done anywhere. Dice are keyed on the seed, never the dynasty's,
## and the screens ask (`after_search`, `after_legend`, the craft panel), never the rules of a life, so the autopilot
## and the golden digests do not move.
class_name GameCraft
extends RefCounted

const PATH := "res://data/items/craft.json"

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


# ---------------------------------------------------------------- the stores

static func materials(d: GameDynasty) -> Dictionary:
	return d.stores.get("materials", {})


static func essences(d: GameDynasty) -> Dictionary:
	return d.stores.get("essences", {})


static func have(d: GameDynasty, material: String) -> int:
	return int(materials(d).get(material, 0))


static func essence_have(d: GameDynasty, affix: String) -> int:
	return int(essences(d).get(affix, 0))


static func add_material(d: GameDynasty, material: String, n: int) -> void:
	_add(d, "materials", material, n)


static func add_essence(d: GameDynasty, affix: String, n: int = 1) -> void:
	_add(d, "essences", affix, n)


static func _add(d: GameDynasty, kind: String, id: String, n: int) -> void:
	var table: Dictionary = d.stores.get(kind, {})
	var now := maxi(0, int(table.get(id, 0)) + n)
	if now == 0:
		table.erase(id)
	else:
		table[id] = now
	if table.is_empty():
		d.stores.erase(kind)
	else:
		d.stores[kind] = table


## The stores as they are saved: only known ids and positive whole numbers; {} for anything else.
static func load_stores(v: Variant) -> Dictionary:
	var out := {}
	if typeof(v) != TYPE_DICTIONARY:
		return out
	for kind in ["materials", "essences"]:
		var src: Variant = v.get(kind, {})
		if typeof(src) != TYPE_DICTIONARY:
			continue
		var clean := {}
		for id in src:
			var known: bool = GameMaterials.has(str(id)) if kind == "materials" else GameLoot.data()["_affix"].has(str(id))
			var n: Variant = src[id]
			if known and typeof(n) in [TYPE_INT, TYPE_FLOAT] and int(n) > 0:
				clean[str(id)] = int(n)
		if not clean.is_empty():
			out[kind] = clean
	var made: Variant = v.get("crafted", 0)
	if typeof(made) in [TYPE_INT, TYPE_FLOAT] and int(made) > 0:
		out["crafted"] = int(made)
	return out


static func describe(d: GameDynasty) -> String:
	var parts: Array = []
	for m in GameMaterials.ids():
		if have(d, str(m)) > 0:
			parts.append("%d %s" % [have(d, str(m)), GameMaterials.name_of(str(m)).to_lower()])
	for a in essences(d):
		parts.append("%d essence of %s" % [essence_have(d, str(a)), _affix_label(str(a))])
	return ", ".join(parts) if not parts.is_empty() else text("nothing")


static func _affix_label(affix: String) -> String:
	var name := str(GameLoot.data()["_affix"].get(affix, {}).get("name", affix))
	return name.trim_prefix("of ").trim_prefix("the ").to_lower() if name.begins_with("of ") else name.to_lower()


static func _list(table: Dictionary, labels: bool = true) -> String:
	var parts: Array = []
	var keys: Array = table.keys()
	keys.sort()
	for k in keys:
		parts.append("%d %s" % [int(table[k]), GameMaterials.name_of(str(k)).to_lower()])
	return ", ".join(parts)


# ---------------------------------------------------------------- gathering

## What a hunt's dead leave: for each foe in `foes` ([{id, ...}]) the materials and the essence its `drops` entry
## gives, one die for each entry whatever happens, on dice keyed on the seed and the hunt. Adds them to the stores
## and returns the lines to show ([] when nothing is found).
static func after_search(d: GameDynasty, foes: Array, place: String = "search") -> Array:
	if d.state != "life":
		return []
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "gather", d.total_hunts, place])
	var got := {}
	var gotess := {}
	for f in foes:
		_roll_drops(r, str(f.get("id", "")), got, gotess, false)
	return _tell(d, got, gotess)


## A slain legend gives what it always gives, once per legend (a flag).
static func after_legend(d: GameDynasty, result: String, enemies: Array) -> Array:
	if d.state != "life" or result != "victory":
		return []
	var got := {}
	var gotess := {}
	for e in enemies:
		var id := str(e.get("id", ""))
		var flag := "legend_gather_" + id
		if not e.get("boss", false) or d.flags.has(flag) or int(d.slain_bosses.get(id, -1)) != d.gen:
			continue
		d.set_flag(flag)
		var r := RandomNumberGenerator.new()
		r.seed = hash([d.seed_value, "gather_legend", id])
		_roll_drops(r, id, got, gotess, true)
	return _tell(d, got, gotess)


static func _roll_drops(r: RandomNumberGenerator, creature: String, got: Dictionary, gotess: Dictionary, sure: bool) -> void:
	var row: Dictionary = data()["drops"].get(creature, {})
	for m in row.get("materials", []):
		var roll := r.randf()
		var n := r.randi_range(int(m["min"]), int(m["max"]))
		if roll < float(m["chance"]) or (sure and float(m["chance"]) >= 1.0):
			got[m["material"]] = int(got.get(m["material"], 0)) + n
	if row.has("essence"):
		var roll := r.randf()
		if roll < float(row["essence"]["chance"]):
			gotess[row["essence"]["affix"]] = int(gotess.get(row["essence"]["affix"], 0)) + 1


static func _tell(d: GameDynasty, got: Dictionary, gotess: Dictionary) -> Array:
	if got.is_empty() and gotess.is_empty():
		return []
	var parts: Array = []
	var keys: Array = got.keys()
	keys.sort()
	for k in keys:
		add_material(d, str(k), int(got[k]))
		parts.append("%d %s" % [int(got[k]), GameMaterials.name_of(str(k)).to_lower()])
	var ekeys: Array = gotess.keys()
	ekeys.sort()
	for a in ekeys:
		add_essence(d, str(a), int(gotess[a]))
		parts.append("%d essence of %s" % [int(gotess[a]), _affix_label(str(a))])
	var line := text("gathered", {"h": d.heir.name, "list": ", ".join(parts)})
	d._say(line)
	return [line]


# ---------------------------------------------------------------- salvage

## What breaking up one item gives: {materials: {id: n}, essences: [affix ids]}. {} for an item that is not known.
static func salvage_yield(item_id: String) -> Dictionary:
	var def := GameItems.item_def(item_id)
	if def.is_empty() or str(def.get("material", "")) == "":
		return {}
	var n := maxi(1, int(floor(float(units_for(float(def.get("weight", 0.0)))) * float(setting("salvage_share")))))
	var ess: Array = []
	var parts := GameLoot.parse(item_id)
	if not parts.is_empty():
		ess = Array(parts["affixes"])
	return {"materials": {str(def["material"]): n}, "essences": ess}


static func units_for(weight: float) -> int:
	return maxi(1, int(round(weight * float(setting("units_per_weight")))))


## Breaks one item in the pack into materials and essences (worn gear is not broken up). Returns the line.
static func salvage(d: GameDynasty, item_id: String) -> String:
	var h := d.heir
	if item_id not in h.inventory:
		return text("cannot_salvage", {"name": GameItems.item_name(item_id)})
	var y := salvage_yield(item_id)
	if y.is_empty():
		return text("cannot_salvage", {"name": GameItems.item_name(item_id)})
	var name := GameItems.item_name(item_id)
	h.inventory.erase(item_id)
	if not GameItems.owns(h, item_id):
		h.tainted_gear.erase(item_id)
	var parts: Array = []
	for m in y["materials"]:
		add_material(d, str(m), int(y["materials"][m]))
		parts.append("%d %s" % [int(y["materials"][m]), GameMaterials.name_of(str(m)).to_lower()])
	for a in y["essences"]:
		add_essence(d, str(a), 1)
		parts.append("1 essence of %s" % _affix_label(str(a)))
	var line := text("salvaged", {"h": h.name, "name": name, "list": ", ".join(parts)})
	d._say(line)
	return line


# ---------------------------------------------------------------- crafting

## The quality the next piece would have: the heir's level and Craft quality traits and a small roll keyed on the
## seed and how many pieces have been made, so the preview shows what the forge will make.
static func quality(d: GameDynasty) -> int:
	var h := d.heir
	var base := int(floor(float(h.level) * float(setting("quality_per_level"))))
	var bonus := int(round(h.trait_total("craft_quality") * float(setting("quality_per_craft_quality"))))
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "craft", int(d.stores.get(str(setting("counter")), 0))])
	var roll := r.randi_range(0, int(setting("quality_roll_max")))
	return clampi(base + bonus + roll, int(setting("quality_floor")), GameLoot.QUALITY_MAX)


## The materials that can make a form (their tags meet its `needs`), sorted by tier then id.
static func materials_for(form_id: String) -> Array:
	var form: Dictionary = GameLoot.data()["_form"].get(form_id, {})
	var out: Array = []
	for m in GameMaterials.ids():
		for tag in form.get("needs", []):
			if tag in GameMaterials.tags_of(str(m)):
				out.append(str(m))
				break
	out.sort_custom(func(a, b): return GameMaterials.tier_of(a) < GameMaterials.tier_of(b) or (GameMaterials.tier_of(a) == GameMaterials.tier_of(b) and a < b))
	return out


## The essences that will take in a form of a material: the affix allows the slot and the material's tier.
static func essences_for(form_id: String, material: String) -> Array:
	var form: Dictionary = GameLoot.data()["_form"].get(form_id, {})
	var out: Array = []
	for a in GameLoot.data()["affixes"]:
		if str(form.get("slot", "")) in a["slots"] and int(a["min_tier"]) <= GameMaterials.tier_of(material):
			out.append(str(a["id"]))
	out.sort()
	return out


## What making this would be: {ok, why, id, item, units, fee, quality}. Nothing is spent.
static func plan(d: GameDynasty, form_id: String, material: String, chosen: Array) -> Dictionary:
	var h := d.heir
	var fail := func(key: String, vals: Dictionary = {}) -> Dictionary: return {"ok": false, "why": text(key, vals)}
	var form: Dictionary = GameLoot.data()["_form"].get(form_id, {})
	if form.is_empty():
		return fail.call("unknown_form")
	var form_name := str(form["name"]).to_lower()
	var mat_name := GameMaterials.name_of(material).to_lower()
	if material not in materials_for(form_id):
		return fail.call("bad_material", {"material": mat_name, "form": form_name})
	var weight := maxf(0.01, snappedf(float(form["weight"]) * float(GameMaterials.get_material(material).get("weight_mult", 1.0)), 0.01))
	var units := units_for(weight)
	if have(d, material) < units:
		return fail.call("short_material", {"material": mat_name, "need": units, "have": have(d, material)})
	if chosen.size() > int(setting("max_essences")):
		return fail.call("too_many", {"n": setting("max_essences")})
	var seen := {}
	for a in chosen:
		var affix := str(a)
		if seen.has(affix) or affix not in essences_for(form_id, material):
			return fail.call("bad_essence", {"affix": _affix_label(affix), "form": form_name, "material": mat_name})
		seen[affix] = true
		if essence_have(d, affix) < 1:
			return fail.call("short_essence", {"affix": _affix_label(affix)})
	var rarity := str(setting("rarity_by_essences")[str(chosen.size())])
	var q := quality(d)
	var id := GameLoot.make_id(rarity, str(form["slot"]), form_id, material, chosen, "", GameLoot.grade_of(d.gen), q)
	var item := GameLoot.build(id)
	if item.is_empty():
		return fail.call("unknown_form")
	var fee := maxi(1, int(round(float(item["price"]) * float(setting("fee_share")))))
	var service := str(setting("needs_service"))
	var base := {"ok": true, "why": "", "id": id, "item": item, "units": units, "fee": fee, "quality": q, "weight": float(item["weight"])}
	if not d.world.has_service(service):
		base["ok"] = false
		base["why"] = text("no_forge")
	elif h.gold < fee:
		base["ok"] = false
		base["why"] = text("short_gold", {"fee": GameText.num(fee)})
	elif not GameCarry.can_carry(h, id):
		base["ok"] = false
		base["why"] = text("no_room", {"h": h.name, "name": item["name"], "weight": "%.1f" % float(item["weight"])})
	return base


## Makes the piece: spends the material, the essences and the fee and puts it in the pack. Returns the line.
static func craft(d: GameDynasty, form_id: String, material: String, chosen: Array) -> String:
	var p := plan(d, form_id, material, chosen)
	if not p["ok"]:
		return str(p["why"])
	add_material(d, material, -int(p["units"]))
	for a in chosen:
		add_essence(d, str(a), -1)
	d.heir.gold -= int(p["fee"])
	d.heir.inventory.append(str(p["id"]))
	var counter := str(setting("counter"))
	d.stores[counter] = int(d.stores.get(counter, 0)) + 1
	var line := text("made", {"h": d.heir.name, "a": "a", "name": p["item"]["name"], "units": p["units"], "material": GameMaterials.name_of(material).to_lower(), "quality": p["quality"]})
	d._say(line)
	return line


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = data()
	for k in ["settings", "drops", "text"]:
		if not dat.has(k):
			bad.append("craft.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var s: Dictionary = dat["settings"]
	for k in ["needs_service", "units_per_weight", "fee_share", "salvage_share", "max_essences", "rarity_by_essences", "quality_per_level", "quality_per_craft_quality", "quality_roll_max", "quality_floor", "counter"]:
		if not s.has(k):
			bad.append("craft.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if float(s["units_per_weight"]) <= 0.0:
		bad.append("craft.json: units_per_weight must be above 0")
	for k in ["fee_share", "salvage_share"]:
		if float(s[k]) < 0.0 or float(s[k]) > 1.0:
			bad.append("craft.json: %s must be between 0 and 1" % k)
	if int(s["max_essences"]) < 0 or int(s["max_essences"]) > 3:
		bad.append("craft.json: max_essences must be from 0 to 3")
	for n in range(int(s["max_essences"]) + 1):
		var rid := str(s["rarity_by_essences"].get(str(n), ""))
		var rar: Dictionary = GameLoot.data()["_rarity"].get(rid, {})
		if rar.is_empty() or int(rar["affixes"]) != n or rar.get("mythic", false):
			bad.append("craft.json: rarity_by_essences[%d] must be a non-mythic rarity with %d affixes" % [n, n])
	if int(s["quality_floor"]) < 0 or int(s["quality_floor"]) > GameLoot.QUALITY_MAX:
		bad.append("craft.json: quality_floor must be 0 to 9")
	GameData.load_all()
	for cid in dat["drops"]:
		var found := false
		for c in GameData.creatures:
			if c["id"] == cid:
				found = true
		if not found:
			bad.append("craft.json: drops names the unknown creature '%s'" % cid)
		var row: Dictionary = dat["drops"][cid]
		for m in row.get("materials", []):
			if not GameMaterials.has(str(m.get("material", ""))):
				bad.append("craft.json: %s drops the unknown material '%s'" % [cid, m.get("material", "")])
			if float(m.get("chance", -1.0)) < 0.0 or float(m.get("chance", 2.0)) > 1.0 or int(m.get("min", 0)) < 1 or int(m.get("max", 0)) < int(m.get("min", 0)):
				bad.append("craft.json: %s has a drop with a chance outside 0 to 1 or a bad amount" % cid)
		if row.has("essence"):
			if not GameLoot.data()["_affix"].has(str(row["essence"].get("affix", ""))):
				bad.append("craft.json: %s drops the unknown essence '%s'" % [cid, row["essence"].get("affix", "")])
			if float(row["essence"].get("chance", -1.0)) < 0.0 or float(row["essence"].get("chance", 2.0)) > 1.0:
				bad.append("craft.json: %s has an essence chance outside 0 to 1" % cid)
	# every hunted creature gives something: a farm animal is slaughtered instead
	for c in GameData.creatures:
		if not c.get("farm", false) and not dat["drops"].has(c["id"]):
			bad.append("craft.json: the creature '%s' has no drops entry" % c["id"])
	# every material can be reached: some hunted creature drops it
	var dropped := {}
	for cid in dat["drops"]:
		for m in dat["drops"][cid].get("materials", []):
			dropped[str(m["material"])] = true
	for m in GameMaterials.ids():
		if not dropped.has(str(m)):
			bad.append("craft.json: nothing drops the material '%s'" % m)
	for k in ["gathered", "no_forge", "unknown_form", "bad_material", "short_material", "short_essence", "bad_essence", "too_many", "short_gold", "no_room", "made", "salvaged", "cannot_salvage", "nothing"]:
		if not dat["text"].has(k):
			bad.append("craft.json: text.%s is missing" % k)
	return bad
