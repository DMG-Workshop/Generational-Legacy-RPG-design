## The loot generator. There is no list of generated items: an item is built from its own id, `gen:<rarity>:<slot>:
## <form>:<material>:<affixes joined by +, or ->:<mythic or ->:<grade>:<quality 0-9>`, out of the forms, materials
## (data/items/materials.json), affixes and rarities in data/items/loot.json. So a save holds nothing but the id, an old
## save loads, and `GameItems.item_def` hands the built item to everything that already knows items. What can drop
## grows with the world: material tiers open at set generations, and after the top tier every few generations add a
## grade that makes all effects stronger, so there is always something better to find. Rarity is a roll out of a million;
## the top rarity is ten in a million. Rolls use dice keyed on the dynasty seed, never the dynasty's, and the screens
## ask (`search_dead`, `after_legend`), never the rules of a life, so the autopilot and the golden digests do not move.
class_name GameLoot
extends RefCounted

const PREFIX := "gen:"
const SEP := ":"
const QUALITY_MAX := 9

static var _cache: Dictionary = {}
static var _built: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json("res://data/items/loot.json")
		_cache["_form"] = _index(_cache["forms"])
		_cache["_affix"] = _index(_cache["affixes"])
		_cache["_mythic"] = _index(_cache["mythics"])
		_cache["_rarity"] = _index(_cache["rarities"])
	return _cache


static func _index(rows: Array) -> Dictionary:
	var out := {}
	for r in rows:
		out[str(r["id"])] = r
	return out


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


static func is_generated(id: String) -> bool:
	return id.begins_with(PREFIX)


# ---------------------------------------------------------------- what the world allows

## The highest material tier that can drop at this generation (1 up to the top).
static func tier_ceiling(gen: int) -> int:
	var gens: Array = setting("tier_gens")
	var t := 1
	for i in gens.size():
		if gen >= int(gens[i]):
			t = i + 1
	return t


static func top_tier() -> int:
	return (setting("tier_gens") as Array).size()


## The grade the world is at: 0 until the top tier has been open for `grade_gens` generations, then one more each.
static func grade_of(gen: int) -> int:
	var gens: Array = setting("tier_gens")
	var over := gen - int(gens.back())
	if over < 0:
		return 0
	return mini(int(setting("max_grade")), over / maxi(1, int(setting("grade_gens"))))


# ---------------------------------------------------------------- id and build

static func make_id(rarity: String, slot: String, form: String, material: String, affixes: Array, mythic: String, grade: int, quality: int) -> String:
	var aff := "-" if affixes.is_empty() else "+".join(affixes)
	return SEP.join([PREFIX.trim_suffix(SEP), rarity, slot, form, material, aff, mythic if mythic != "" else "-", str(grade), str(quality)])


## The parts of a generated id, or {} when it is not a well-formed one this game's data can build.
static func parse(id: String) -> Dictionary:
	if not id.begins_with(PREFIX):
		return {}
	var p := id.split(SEP)
	if p.size() != 9:
		return {}
	var dat := data()
	var rarity: Dictionary = dat["_rarity"].get(p[1], {})
	var form: Dictionary = dat["_form"].get(p[3], {})
	if rarity.is_empty() or form.is_empty() or str(form["slot"]) != p[2] or not GameMaterials.has(p[4]):
		return {}
	var fits := false
	for tag in form["needs"]:
		if tag in GameMaterials.tags_of(p[4]):
			fits = true
	if not fits:
		return {}
	var affixes: Array = [] if p[5] == "-" else Array(p[5].split("+"))
	if affixes.size() != int(rarity["affixes"]):
		return {}
	var tier := GameMaterials.tier_of(p[4])
	var seen := {}
	for a in affixes:
		var def: Dictionary = dat["_affix"].get(a, {})
		if def.is_empty() or seen.has(a) or p[2] not in def["slots"] or int(def["min_tier"]) > tier:
			return {}
		seen[a] = true
	var mythic := "" if p[6] == "-" else p[6]
	if rarity.get("mythic", false) != (mythic != ""):
		return {}
	if mythic != "" and (not dat["_mythic"].has(mythic) or p[2] not in dat["_mythic"][mythic]["slots"]):
		return {}
	if not p[7].is_valid_int() or not p[8].is_valid_int():
		return {}
	var grade := int(p[7])
	var q := int(p[8])
	if grade < 0 or grade > int(setting("max_grade")) or q < 0 or q > QUALITY_MAX:
		return {}
	return {"rarity": p[1], "slot": p[2], "form": p[3], "material": p[4], "affixes": affixes, "mythic": mythic, "grade": grade, "quality": q, "tier": tier}


## The item an id builds, shaped like an entry of items.json; {} for an id that is not a generated item.
static func build(id: String) -> Dictionary:
	if _built.has(id):
		return _built[id]
	var parts := parse(id)
	if parts.is_empty():
		return {}
	if _built.size() > 4000:
		_built.clear()
	var dat := data()
	var form: Dictionary = dat["_form"][parts["form"]]
	var rarity: Dictionary = dat["_rarity"][parts["rarity"]]
	var tier: int = parts["tier"]
	var grade: int = parts["grade"]
	var grade_mult := 1.0 + float(setting("grade_power")) * grade
	var q_mult := float(setting("quality_min")) + float(setting("quality_step")) * int(parts["quality"])
	var tier_power := float(setting("tier_power")[str(tier)])
	var base := tier_power * grade_mult * q_mult * float(rarity["power_mult"])
	var stats := {}
	for e in form["effects"]:
		stats[e["stat"]] = float(stats.get(e["stat"], 0.0)) + float(e["value"]) * base
	var prefix_name := ""
	var suffix_name := ""
	var extras: Array = []
	for a in parts["affixes"]:
		var ad: Dictionary = dat["_affix"][a]
		for e in ad["effects"]:
			stats[e["stat"]] = float(stats.get(e["stat"], 0.0)) + float(e["value"]) * base * float(setting("affix_power"))
		if ad["position"] == "prefix" and prefix_name == "":
			prefix_name = str(ad["name"])
		elif ad["position"] == "suffix" and suffix_name == "":
			suffix_name = str(ad["name"])
		else:
			extras.append(str(ad["name"]))
	var mythic_name := ""
	if parts["mythic"] != "":
		var md: Dictionary = dat["_mythic"][parts["mythic"]]
		mythic_name = str(md["name"])
		for k in stats:
			stats[k] = float(stats[k]) * float(md["power_mult"])
		for e in md["effects"]:
			stats[e["stat"]] = float(stats.get(e["stat"], 0.0)) + float(e["value"]) * grade_mult
	var effects: Array = []
	var keys: Array = stats.keys()
	keys.sort()
	for k in keys:
		var v: float = snappedf(float(stats[k]), 0.001)
		if absf(v) > 0.0:
			effects.append({"stat": k, "value": v})
	var mat_name := GameMaterials.name_of(parts["material"])
	var plain := "%s %s" % [mat_name, form["name"]]
	var nm := plain
	if mythic_name != "":
		nm = "%s, %s" % [mythic_name, plain]
	else:
		if prefix_name != "":
			nm = prefix_name + " " + nm
		if suffix_name != "":
			nm += " " + suffix_name
	if grade > 0:
		nm += " +%d" % grade
	var desc := "%s %s, made of %s." % [str(rarity["name"]), str(form["name"]).to_lower(), mat_name.to_lower()]
	if not extras.is_empty():
		desc += " Also " + ", ".join(extras).to_lower() + "."
	var price := int(round(float(setting("price_per_tier")[str(tier)]) * float(rarity["price_mult"]) * (1.0 + 0.05 * grade)))
	var def := {
		"id": id, "name": nm, "slot": parts["slot"], "tier": tier, "material": parts["material"],
		"weight": maxf(0.01, snappedf(float(form["weight"]) * float(GameMaterials.get_material(parts["material"]).get("weight_mult", 1.0)), 0.01)),
		"price": maxi(1, price), "description": desc, "effects": effects, "rarity": parts["rarity"],
		"generated": true, "tags": [str(parts["form"]), str(parts["rarity"])], "weapon_kind": str(form.get("weapon_kind", "")),
	}
	if rarity.get("mythic", false):
		def["unique"] = true
	_built[id] = def
	return def


static func rarity_name(id: String) -> String:
	return str(build(id).get("rarity", ""))


static func weapon_kind(id: String) -> String:
	return str(build(id).get("weapon_kind", ""))


# ---------------------------------------------------------------- rolling

## The rarity of a roll: weights out of `weight_total`, the rare ones (from the third up) multiplied by `boost`.
static func pick_rarity(r: RandomNumberGenerator, boost: float) -> String:
	var rows: Array = data()["rarities"]
	var total := 0.0
	var w: Array = []
	for i in rows.size():
		var x := float(rows[i]["weight"]) * (boost if i >= 2 else 1.0)
		w.append(x)
		total += x
	var roll := r.randf() * total
	for i in rows.size():
		roll -= float(w[i])
		if roll < 0.0:
			return str(rows[i]["id"])
	return str(rows.back()["id"])


static func _pick_weighted(r: RandomNumberGenerator, rows: Array) -> Dictionary:
	var total := 0.0
	for x in rows:
		total += float(x["weight"])
	var roll := r.randf() * total
	for x in rows:
		roll -= float(x["weight"])
		if roll < 0.0:
			return x
	return rows.back()


## One item id for this world: the rarity, then what the world allows, all drawn from `r`. `gen` is the generation.
static func roll_item(r: RandomNumberGenerator, gen: int, boost: float = 1.0) -> String:
	var dat := data()
	var rarity_id := pick_rarity(r, boost)
	var rarity: Dictionary = dat["_rarity"][rarity_id]
	var slots := dat["settings"]["slot_weights"] as Dictionary
	var slot_rows: Array = []
	for s in slots:
		slot_rows.append({"id": s, "weight": slots[s]})
	slot_rows.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	var slot := str(_pick_weighted(r, slot_rows)["id"])
	var cap := mini(top_tier(), tier_ceiling(gen) + int(rarity["overreach"]))
	var forms: Array = []
	for f in dat["forms"]:
		if str(f["slot"]) == slot and not _materials_for(f, cap).is_empty():
			forms.append(f)
	var form: Dictionary = forms[r.randi() % forms.size()]
	# the tier: among those with a material for this form, the higher the likelier by the rarity's bias
	var tier_rows: Array = []
	for t in range(1, cap + 1):
		if not _materials_at(form, t).is_empty():
			tier_rows.append({"id": t, "weight": pow(float(rarity["tier_bias"]), t)})
	var tier := int(_pick_weighted(r, tier_rows)["id"])
	var mats := _materials_at(form, tier)
	var material := str(mats[r.randi() % mats.size()])
	var affixes := _pick_affixes(r, slot, tier, int(rarity["affixes"]))
	var mythic := ""
	if rarity.get("mythic", false):
		var pool: Array = dat["mythics"].filter(func(m): return slot in m["slots"])
		mythic = str(pool[r.randi() % pool.size()]["id"])
	var q := r.randi_range(int(rarity["quality_floor"]), QUALITY_MAX)
	return make_id(rarity_id, slot, str(form["id"]), material, affixes, mythic, grade_of(gen), q)


static func _materials_at(form: Dictionary, tier: int) -> Array:
	var out: Array = []
	for m in GameMaterials.of_tier(tier):
		for tag in form["needs"]:
			if tag in GameMaterials.tags_of(str(m)):
				out.append(m)
				break
	return out


static func _materials_for(form: Dictionary, cap: int) -> Array:
	var out: Array = []
	for t in range(1, cap + 1):
		out.append_array(_materials_at(form, t))
	return out


## `n` distinct affixes for a slot and tier: with two or more, a prefix and a suffix first.
static func _pick_affixes(r: RandomNumberGenerator, slot: String, tier: int, n: int) -> Array:
	var pool: Array = data()["affixes"].filter(func(a): return slot in a["slots"] and int(a["min_tier"]) <= tier)
	var out: Array = []
	if n <= 0:
		return out
	var order: Array = []
	if n == 1:
		order = [""]
	else:
		order = ["prefix", "suffix"]
		while order.size() < n:
			order.append("")
	for pos in order:
		var rows: Array = pool.filter(func(a): return (pos == "" or a["position"] == pos) and str(a["id"]) not in out)
		if rows.is_empty():
			rows = pool.filter(func(a): return str(a["id"]) not in out)
		out.append(str(_pick_weighted(r, rows)["id"]))
	return out


# ---------------------------------------------------------------- drops (the screens call these)

## What the screens call to search the dead: the search as it plays (GameFinding.search_dead) and then, on this
## generator's own dice, a chance of a made item beside each foe. Returns all the lines.
static func search_dead(d: GameDynasty) -> Array:
	var foes: Array = d.loot.get("foes", [])
	var lines := GameFinding.search_dead(d)
	lines.append_array(after_search(d, foes))
	return lines


## One roll per foe searched (a die each whatever happens, so a foe's roll never depends on the others): the chance is
## `drop_chance`, and the item goes into the pack. Returns the lines to show.
static func after_search(d: GameDynasty, foes: Array, place: String = "search") -> Array:
	var out: Array = []
	if d.state != "life":
		return out
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "loot", d.total_hunts, place])
	var boost := float(setting("source_boost").get(place, 1.0))
	for f in foes:
		var drop := r.randf()
		var item_seed := r.randi()
		if drop >= float(setting("drop_chance")):
			continue
		var ir := RandomNumberGenerator.new()
		ir.seed = item_seed
		out.append(_give(d, roll_item(ir, d.gen, boost)))
	return out


## A slain legend leaves something better, once per legend (a flag): one drop at the legend boost. Returns the lines.
static func after_legend(d: GameDynasty, result: String, enemies: Array) -> Array:
	var out: Array = []
	if d.state != "life" or result != "victory":
		return out
	for e in enemies:
		var id := str(e.get("id", ""))
		var flag := "legend_loot_" + id
		if not e.get("boss", false) or d.flags.has(flag) or int(d.slain_bosses.get(id, -1)) != d.gen:
			continue
		d.set_flag(flag)
		var ir := RandomNumberGenerator.new()
		ir.seed = hash([d.seed_value, "loot_legend", id])
		out.append(_give(d, roll_item(ir, d.gen, float(setting("source_boost")["legend"]))))
	return out


static func _give(d: GameDynasty, id: String) -> String:
	var def := build(id)
	if not GameCarry.can_carry(d.heir, id):
		var heavy := GameCarry.sell_find(d, id, "a " + str(def["name"]))
		d._say(heavy)
		return heavy
	d.heir.inventory.append(id)
	var vals := {"h": d.heir.name, "name": str(def["name"]), "rarity": str(data()["_rarity"][def["rarity"]]["name"]).to_lower(), "a": "a"}
	var key := "find"
	if def["rarity"] == "mythic":
		key = "find_mythic"
	elif def["rarity"] in ["epic", "legendary"]:
		key = "find_rare"
	var line := text(key, vals)
	d._say(line)
	return line


# ---------------------------------------------------------------- the data

## Every problem in the generator's data, each starting with the part it belongs to.
static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = data()
	if dat.is_empty():
		return ["loot.json: cannot be read"]
	for k in ["settings", "rarities", "forms", "affixes", "mythics", "text"]:
		if not dat.has(k):
			bad.append("loot.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var s: Dictionary = dat["settings"]
	for k in ["drop_chance", "tier_gens", "grade_gens", "max_grade", "grade_power", "affix_power", "quality_min", "quality_step", "tier_power", "price_per_tier", "slot_weights", "source_boost", "weight_total"]:
		if not s.has(k):
			bad.append("loot.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if float(s["drop_chance"]) < 0.0 or float(s["drop_chance"]) > 1.0:
		bad.append("loot.json: drop_chance must be between 0 and 1")
	var gens: Array = s["tier_gens"]
	if gens.is_empty() or int(gens[0]) != 1:
		bad.append("loot.json: tier_gens must start at generation 1")
	for i in range(1, gens.size()):
		if int(gens[i]) <= int(gens[i - 1]):
			bad.append("loot.json: tier_gens must rise")
	if gens.size() > GameMaterials.MAX_TIER:
		bad.append("loot.json: more tiers than materials can have")
	for t in range(1, gens.size() + 1):
		if not s["tier_power"].has(str(t)) or not s["price_per_tier"].has(str(t)):
			bad.append("loot.json: tier %d needs a tier_power and a price_per_tier" % t)
		elif GameMaterials.of_tier(t).is_empty():
			bad.append("loot.json: tier %d has no material" % t)
	if int(s["grade_gens"]) < 1 or int(s["max_grade"]) < 0:
		bad.append("loot.json: grade_gens must be at least 1 and max_grade 0 or more")
	for slot in s["slot_weights"]:
		if slot not in GameItems.SLOTS:
			bad.append("loot.json: slot_weights names '%s', which is not a gear slot" % slot)
	var labels := GameItems._effect_labels()
	var seen := {}
	var total := 0.0
	for r in dat["rarities"]:
		var id := str(r.get("id", ""))
		if seen.has(id) or id == "" or SEP in id:
			bad.append("loot.json: rarity '%s' is blank, repeated or has a colon" % id)
		seen[id] = true
		for k in ["weight", "affixes", "power_mult", "price_mult", "tier_bias", "overreach", "quality_floor", "name"]:
			if not r.has(k):
				bad.append("loot.json: rarity '%s' has no %s" % [id, k])
		if r.has("weight"):
			total += float(r["weight"])
		if r.has("quality_floor") and (int(r["quality_floor"]) < 0 or int(r["quality_floor"]) > QUALITY_MAX):
			bad.append("loot.json: rarity '%s' has a quality floor out of range" % id)
	if absf(total - float(s["weight_total"])) > 0.5:
		bad.append("loot.json: the rarity weights add up to %s, not weight_total %s" % [total, s["weight_total"]])
	var mythic_rarities := 0
	for r in dat["rarities"]:
		if r.get("mythic", false):
			mythic_rarities += 1
	if mythic_rarities != 1:
		bad.append("loot.json: exactly one rarity must be mythic")
	var rows := {}
	for group in [["forms", "slot"], ["affixes", "position"], ["mythics", "slots"]]:
		rows[group[0]] = {}
	for f in dat["forms"]:
		var id := str(f.get("id", ""))
		if rows["forms"].has(id) or id == "" or SEP in id or "+" in id:
			bad.append("loot.json: form '%s' is blank, repeated or has a colon or plus" % id)
		rows["forms"][id] = true
		if str(f.get("slot", "")) not in GameItems.SLOTS:
			bad.append("loot.json: form '%s' has the slot '%s'" % [id, f.get("slot")])
		if not (f.get("needs") is Array) or f["needs"].is_empty():
			bad.append("loot.json: form '%s' needs a material tag" % id)
		else:
			var any := false
			for tag in f["needs"]:
				if tag not in GameMaterials.data()["tags"]:
					bad.append("loot.json: form '%s' needs the unknown tag '%s'" % [id, tag])
				if not GameMaterials.with_tag(str(tag)).is_empty():
					any = true
			if not any:
				bad.append("loot.json: form '%s' has no material to be made of" % id)
		if float(f.get("weight", 0.0)) <= 0.0:
			bad.append("loot.json: form '%s' needs a positive weight" % id)
		if f.get("slot") == "weapon" and not GameFeats.has_weapon_kind(str(f.get("weapon_kind", ""))):
			bad.append("loot.json: weapon form '%s' has the unknown weapon_kind '%s'" % [id, f.get("weapon_kind", "")])
		bad.append_array(_effect_problems("form '%s'" % id, f.get("effects", []), labels))
	for slot in GameItems.SLOTS:
		if not dat["forms"].any(func(f): return f["slot"] == slot):
			bad.append("loot.json: no form for the slot '%s'" % slot)
		elif not dat["mythics"].any(func(m): return slot in m["slots"]):
			bad.append("loot.json: no mythic for the slot '%s'" % slot)
	for a in dat["affixes"]:
		var id := str(a.get("id", ""))
		if rows["affixes"].has(id) or id == "" or SEP in id or "+" in id:
			bad.append("loot.json: affix '%s' is blank, repeated or has a colon or plus" % id)
		rows["affixes"][id] = true
		if str(a.get("position", "")) not in ["prefix", "suffix"]:
			bad.append("loot.json: affix '%s' is neither a prefix nor a suffix" % id)
		for slot in a.get("slots", []):
			if slot not in GameItems.SLOTS:
				bad.append("loot.json: affix '%s' names the slot '%s'" % [id, slot])
		if float(a.get("weight", 0.0)) <= 0.0 or int(a.get("min_tier", 0)) < 1:
			bad.append("loot.json: affix '%s' needs a positive weight and a min_tier of 1 or more" % id)
		if a.get("effects", []).is_empty():
			bad.append("loot.json: affix '%s' has no effect" % id)
		bad.append_array(_effect_problems("affix '%s'" % id, a.get("effects", []), labels))
	for slot in GameItems.SLOTS:
		for pos in ["prefix", "suffix"]:
			if not dat["affixes"].any(func(a): return slot in a["slots"] and a["position"] == pos and int(a["min_tier"]) == 1):
				bad.append("loot.json: no tier 1 %s for the slot '%s'" % [pos, slot])
	for m in dat["mythics"]:
		var id := str(m.get("id", ""))
		if rows["mythics"].has(id) or id == "" or SEP in id:
			bad.append("loot.json: mythic '%s' is blank, repeated or has a colon" % id)
		rows["mythics"][id] = true
		if float(m.get("power_mult", 0.0)) < 1.0:
			bad.append("loot.json: mythic '%s' must have a power_mult of at least 1" % id)
		bad.append_array(_effect_problems("mythic '%s'" % id, m.get("effects", []), labels))
	for k in ["find", "find_rare", "find_mythic"]:
		if not dat["text"].has(k):
			bad.append("loot.json: text.%s is missing" % k)
	return bad


static func _effect_problems(where: String, effects: Array, labels: Dictionary) -> Array:
	var bad: Array = []
	if effects.is_empty():
		return bad
	for e in effects:
		if not labels.has(str(e.get("stat", ""))):
			bad.append("loot.json: %s has the unknown stat '%s'" % [where, e.get("stat", "")])
		if typeof(e.get("value")) not in [TYPE_FLOAT, TYPE_INT]:
			bad.append("loot.json: %s has an effect with no number" % where)
	return bad
