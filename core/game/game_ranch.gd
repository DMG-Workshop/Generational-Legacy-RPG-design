## Growth and keep for the family's creatures (roadmap item 56, first part): as the world clock passes
## (GameDynasty._pass_years calls on_years) each creature on the roster ages through egg, young, adult and
## elder, costs gold to keep, and is neglected if the gold runs out. No dice are drawn, so nothing else in a
## life moves, and with an empty roster (every autopilot and golden run) it does nothing at all.
## Tuning and text: data/creatures/ranch.json.
class_name GameRanch
extends RefCounted

const STAGES := ["egg", "young", "adult", "elder"]
const SIZE_KEYS := ["egg", "young", "adult", "elder", "keep"]

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json("res://data/creatures/ranch.json")
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary) -> String:
	return str(data()["text"][key]).format(vals)


## The size class of a species: what sets how long each part of its life lasts and what it costs to keep.
static func size_of(species: String) -> Dictionary:
	var name := str(data()["size_of"].get(species, setting("default_size")))
	return data()["sizes"].get(name, data()["sizes"][setting("default_size")])


## How long this creature's egg lasts, in years (none for what is born live).
static func egg_years(e: Dictionary) -> float:
	return float(size_of(str(e["species"]))["egg"]) if str(e.get("born")) == "egg" else 0.0


static func adult_at(e: Dictionary) -> float:
	var s := size_of(str(e["species"]))
	return egg_years(e) + float(s["young"]) + float(s["adult"])


## The age at which this creature dies of old age: its elder years, stretched or shortened by a value that
## comes from the dynasty seed and its id (the same every time, and no die is drawn).
static func death_at(d: GameDynasty, e: Dictionary) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "elder", int(e["id"])])
	var spread := float(setting("elder_spread"))
	var factor := 1.0 + spread * (2.0 * r.randf() - 1.0)
	return adult_at(e) + float(size_of(str(e["species"]))["elder"]) * factor


## The stage an age falls in. Dying is not a stage: death_at says when.
static func stage_at(e: Dictionary, age: float) -> String:
	var s := size_of(str(e["species"]))
	var egg := egg_years(e)
	if age < egg:
		return "egg"
	if age < egg + float(s["young"]):
		return "young"
	if age < adult_at(e):
		return "adult"
	return "elder"


## The Ranch's row for the dynasty's level (level 0 when nothing is built).
static func ranch(d: GameDynasty) -> Dictionary:
	var levels: Array = data()["ranch"]["levels"]
	return levels[clampi(GameHouse.level(d, GameHouse.RANCH), 0, levels.size() - 1)]


## Places beyond the family's own that the Ranch's pens give.
static func extra_pens(d: GameDynasty) -> int:
	return int(ranch(d)["pens"])


## A Ranch factor that depends on a creature's stage: eggs have the hatchery's, the young the nursery's, the
## grown nothing. `what` is "keep" or "mood_loss".
static func ranch_factor(d: GameDynasty, e: Dictionary, what: String) -> float:
	var stage := str(e.get("stage"))
	if stage == "egg":
		return float(ranch(d)["egg_" + what])
	if stage == "young":
		return float(ranch(d)["young_" + what])
	return 1.0


static func yearly_keep(e: Dictionary, d: GameDynasty = null) -> float:
	var k := float(size_of(str(e["species"]))["keep"])
	if str(e.get("stage")) == "egg":
		k *= float(setting("egg_keep_share"))
	return k * (ranch_factor(d, e, "keep") if d != null else 1.0)


## What work a species does: {kind, gold} or {} (grown creatures only; see work_share).
static func work_of(species: String) -> Dictionary:
	return data()["work_of"].get(species, {})


## How much of its work a creature does now: 0 while it is an egg or young or too unhappy, the elder's share when old.
static func work_share(e: Dictionary) -> float:
	if int(e.get("mood", 0)) < int(data()["work"]["min_mood"]):
		return 0.0
	match str(e.get("stage")):
		"adult":
			return 1.0
		"elder":
			return float(data()["work"]["elder_share"])
	return 0.0


## The gold a year the roster earns by wool, eggs and venom: {gold, kinds: {kind: gold}}.
static func yearly_work(d: GameDynasty) -> Dictionary:
	var by_kind := {}
	var total := 0.0
	for e in d.roster:
		var w := work_of(str(e["species"]))
		var share := work_share(e)
		if w.is_empty() or share <= 0.0 or str(w["kind"]) == "guard":
			continue
		var g := float(w["gold"]) * share
		by_kind[str(w["kind"])] = float(by_kind.get(str(w["kind"]), 0.0)) + g
		total += g
	return {"gold": total, "kinds": by_kind}


## The share of an event's gold loss that guards turn away, 0 to guard_cut_max.
static func guard_cut(d: GameDynasty) -> float:
	var n := 0.0
	for e in d.roster:
		var w := work_of(str(e["species"]))
		if not w.is_empty() and str(w["kind"]) == "guard":
			n += work_share(e)
	return minf(float(data()["work"]["guard_cut_max"]), n * float(data()["work"]["guard_cut_each"]))


## A loss of gold after the guards: the same loss when there are none. Whole gold, rounded in the house's favour.
static func guarded_loss(d: GameDynasty, loss: int) -> int:
	if loss <= 0 or d.roster.is_empty():
		return loss
	return int(ceil(float(loss) * (1.0 - guard_cut(d))))


## What this creature does now, for its entry: "" while it is an egg, young, unhappy or has no work.
static func work_text(e: Dictionary) -> String:
	var w := work_of(str(e.get("species", "")))
	if w.is_empty() or work_share(e) <= 0.0:
		return ""
	var kind: Dictionary = data()["work"]["kinds"][str(w["kind"])]
	var cut := int(round(float(data()["work"]["guard_cut_each"]) * work_share(e) * 100.0))
	return str(kind["about"]).format({"gold": GameText.num(int(ceil(float(w.get("gold", 0)) * work_share(e)))), "cut": str(cut)})


## The line for a screen: what each kind earns, e.g. "wool 8, eggs 20".
static func kinds_text(by_kind: Dictionary) -> String:
	var keys: Array = by_kind.keys()
	keys.sort()
	return ", ".join(keys.map(func(k): return "%s %s" % [str(data()["work"]["kinds"][k]["said"]), GameText.num(int(ceil(float(by_kind[k]))))]))


## What the whole roster costs to keep each year, in gold (a part of a gold is rounded up).
static func keep_total(d: GameDynasty) -> int:
	var due := 0.0
	for e in d.roster:
		due += yearly_keep(e, d)
	return int(ceil(due))


## The word for how a creature is doing.
static func mood_word(mood: int) -> String:
	var top := int(setting("mood_max"))
	if mood * 100 >= top * 60:
		return text("mood_high", {})
	if mood * 100 >= top * 30:
		return text("mood_mid", {})
	return text("mood_low", {})


## A year count as a short number: 3, or 2.5.
static func years_text(v: float) -> String:
	return str(snappedf(v, 0.1)).trim_suffix(".0")


## Time passes for the creatures: they are fed from the heir's gold (what cannot be paid is neglect), grow,
## and may spoil, wander off or die of old age. Lines are journalled and added to `msgs`.
static func on_years(d: GameDynasty, years: float, msgs: Array) -> void:
	if d.roster.is_empty() or years <= 0.0 or d.heir == null:
		return
	var earned := yearly_work(d)   # what the grown earn comes first, so a working ranch pays for itself
	var income := int(round(float(earned["gold"]) * years))
	if income > 0:
		d.heir.gold += income
		var said := text("work_income", {"gold": GameText.num(income), "kinds": kinds_text(earned["kinds"])})
		d._say(said)
		msgs.append(said)
	var due := 0.0
	for e in d.roster:
		due += yearly_keep(e, d) * years
	var cost := int(ceil(due))
	var paid := mini(cost, maxi(0, d.heir.gold))
	d.heir.gold -= paid
	var ratio := 1.0 if cost <= 0 else float(paid) / float(cost)
	var gain := float(setting("fed_mood_gain")) * years * ratio
	var loss := float(setting("unfed_mood_loss")) * years * (1.0 - ratio)
	var top := int(setting("mood_max"))
	var kept: Array = []
	for e in d.roster:
		var felt := gain - loss * ranch_factor(d, e, "mood_loss")   # the hatchery and nursery soften neglect
		for line in _live_years(d, e, years, felt, top):
			d._say(line)
			msgs.append(line)
		if not e.get("gone", false):
			kept.append(e)
	d.roster = kept


## One creature's years. Returns the lines to tell. A creature that is gone is marked "gone".
static func _live_years(d: GameDynasty, e: Dictionary, years: float, mood_change: float, top: int) -> Array:
	var def := GameCombat.creature_def(str(e["species"]))
	var vals := {"name": str(e["name"]), "young": str(e["young"]), "species": str(def.get("name", e["species"])).to_lower()}
	e["mood"] = clampi(int(round(float(e["mood"]) + mood_change)), 0, top)
	if int(e["mood"]) <= 0:
		e["gone"] = true
		return [text("spoils" if str(e["stage"]) == "egg" else "leaves", vals)]
	var was := str(e["stage"])
	e["age"] = float(e["age"]) + years
	if float(e["age"]) >= death_at(d, e):
		e["gone"] = true
		return [text("dies", vals)]
	var now := stage_at(e, float(e["age"]))
	e["stage"] = now
	var out: Array = []
	var from := STAGES.find(was)
	var to := STAGES.find(now)
	for i in range(from + 1, to + 1):   # every step it passed, in order, if a long time went by at once
		match STAGES[i]:
			"young":
				out.append(text("hatches", vals))
			"adult":
				out.append(text("grows_up", vals))
			"elder":
				out.append(text("grows_old", vals))
	return out


## What a creature would sell for: its size's value, by stage, by how well it has been kept.
static func sell_price(e: Dictionary) -> int:
	var v := float(size_of(str(e["species"])).get("value", 0))
	var stage_mult := float(setting("stage_value").get(str(e.get("stage")), 1.0))
	var mood := float(clampi(int(e.get("mood", setting("start_mood"))), 0, int(setting("mood_max")))) / float(setting("mood_max"))
	return maxi(1, int(round(v * stage_mult * mood)))


## Sells a kept creature for gold. Returns the line told, or "" if it could not be sold (not in a life, no such creature).
static func sell(d: GameDynasty, id: int) -> String:
	var e := find(d, id)
	if e.is_empty() or d.state != "life":
		return ""
	var gold := sell_price(e)
	d.heir.gold += gold
	return _part(d, e, "sold", {"gold": GameText.num(gold)})


## Sets a kept creature free. Returns the line told, or "".
static func release(d: GameDynasty, id: int) -> String:
	var e := find(d, id)
	if e.is_empty() or d.state != "life":
		return ""
	return _part(d, e, "freed", {})


static func find(d: GameDynasty, id: int) -> Dictionary:
	for e in d.roster:
		if int(e["id"]) == id:
			return e
	return {}


static func _part(d: GameDynasty, e: Dictionary, key: String, extra: Dictionary) -> String:
	var def := GameCombat.creature_def(str(e["species"]))
	var vals := {"h": d.heir.name, "name": str(e["name"]), "species": str(def.get("name", e["species"])).to_lower()}
	vals.merge(extra)
	d.roster.erase(e)
	var line := text(key, vals)
	d._say(line)
	return line


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "sizes", "size_of", "text"]:
		if not dat.has(k):
			bad.append("ranch.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var s: Dictionary = dat["settings"]
	for k in ["start_mood", "mood_max", "fed_mood_gain", "unfed_mood_loss", "egg_keep_share", "elder_spread", "default_size"]:
		if not s.has(k):
			bad.append("ranch.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if int(s["start_mood"]) < 1 or int(s["start_mood"]) > int(s["mood_max"]):
		bad.append("ranch.json: start_mood must be between 1 and mood_max")
	if float(s["elder_spread"]) < 0.0 or float(s["elder_spread"]) >= 1.0:
		bad.append("ranch.json: elder_spread must be at least 0 and under 1")
	if float(s["egg_keep_share"]) < 0.0:
		bad.append("ranch.json: egg_keep_share is negative")
	if not dat["sizes"].has(str(s["default_size"])):
		bad.append("ranch.json: default_size '%s' is not a size" % s["default_size"])
	for name in dat["sizes"]:
		if not dat["sizes"][name].has("value") or float(dat["sizes"][name]["value"]) <= 0.0:
			bad.append("ranch.json: size '%s' needs a positive value" % name)
		for k in SIZE_KEYS:
			if not dat["sizes"][name].has(k) or float(dat["sizes"][name][k]) <= 0.0:
				bad.append("ranch.json: size '%s' needs a positive %s" % [name, k])
	for st in STAGES:
		if not dat["settings"].get("stage_value", {}).has(st):
			bad.append("ranch.json: settings.stage_value.%s is missing" % st)
	var levels: Variant = dat.get("ranch", {}).get("levels")
	if typeof(levels) != TYPE_ARRAY or (levels as Array).size() != GameHouse.max_level() + 1:
		bad.append("ranch.json: ranch.levels needs one row for level 0 and each house level (%d rows)" % (GameHouse.max_level() + 1))
	else:
		var prev_pens := -1
		for i in (levels as Array).size():
			var row: Dictionary = levels[i]
			for k in ["pens", "egg_keep", "egg_mood_loss", "young_keep", "young_mood_loss", "about"]:
				if not row.has(k):
					bad.append("ranch.json: ranch level %d has no %s" % [i, k])
			if not bad.is_empty():
				continue
			if int(row["pens"]) < prev_pens or (i == 0 and int(row["pens"]) != 0):
				bad.append("ranch.json: pens must start at 0 and never fall (level %d)" % i)
			prev_pens = int(row["pens"])
			for k in ["egg_keep", "egg_mood_loss", "young_keep", "young_mood_loss"]:
				if float(row[k]) < 0.0 or float(row[k]) > 1.0:
					bad.append("ranch.json: ranch level %d %s must be between 0 and 1" % [i, k])
	var work: Variant = dat.get("work")
	if typeof(work) != TYPE_DICTIONARY or not (work.has("kinds") and work.has("min_mood") and work.has("elder_share") and work.has("guard_cut_each") and work.has("guard_cut_max")):
		bad.append("ranch.json: work needs kinds, min_mood, elder_share, guard_cut_each and guard_cut_max")
	else:
		if float(work["elder_share"]) < 0.0 or float(work["elder_share"]) > 1.0:
			bad.append("ranch.json: work.elder_share must be between 0 and 1")
		if float(work["guard_cut_max"]) < 0.0 or float(work["guard_cut_max"]) >= 1.0 or float(work["guard_cut_each"]) < 0.0:
			bad.append("ranch.json: guard cuts must be 0 or more, and the most under 1 (guards cannot stop every loss)")
		for kind in work["kinds"]:
			for k in ["name", "about", "said"]:
				if not work["kinds"][kind].has(k):
					bad.append("ranch.json: work kind '%s' has no %s" % [kind, k])
		for sp in dat.get("work_of", {}):
			var w: Dictionary = dat["work_of"][sp]
			if GameBirth.born(str(sp)) == "none":
				bad.append("ranch.json: work_of names '%s', which is not born" % sp)
			if not w.has("kind") or not work["kinds"].has(str(w.get("kind"))):
				bad.append("ranch.json: '%s' has an unknown work kind" % sp)
			elif str(w["kind"]) != "guard" and float(w.get("gold", 0)) <= 0.0:
				bad.append("ranch.json: '%s' works at '%s' but earns nothing" % [sp, w["kind"]])
	for sp in dat["size_of"]:
		if GameBirth.born(str(sp)) == "none":
			bad.append("ranch.json: size_of names '%s', which is not born" % sp)
		if not dat["sizes"].has(str(dat["size_of"][sp])):
			bad.append("ranch.json: '%s' has unknown size '%s'" % [sp, dat["size_of"][sp]])
	for c in GameData.creatures:
		if GameBirth.born(str(c["id"])) != "none" and not dat["size_of"].has(str(c["id"])):
			bad.append("ranch.json: '%s' is born but has no size (it would use the default)" % c["id"])
	for k in ["hatches", "grows_up", "grows_old", "dies", "spoils", "leaves", "stage_egg", "stage_young", "stage_adult", "stage_elder", "mood_high", "mood_mid", "mood_low", "age", "keep", "sold", "freed", "sell", "free", "sure_sell", "sure_free", "house_row", "work_income", "work_line", "work_none", "work_income_head", "guard_head", "guard_saved"]:
		if not dat["text"].has(k):
			bad.append("ranch.json: text.%s is missing" % k)
	return bad
