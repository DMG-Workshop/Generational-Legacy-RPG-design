## Diseases: catching them, how they worsen or clear, cures and contagion. Content and tuning
## live in data/diseases/diseases.json; cures and black-market wares in data/items/items.json.
## Every helper takes any GameHeir (the heir, a spouse, a child, a companion's unit), so the
## battle side can use the same rules for looted corpses, plague vials and sick companions.
##
## State on a GameHeir: diseases = [{id, stage, years_in_stage, source}], tainted_gear = bargain
## items still hiding a sickness until first worn, disease_level = the level up to which the
## level-milestone rolls are done. The current stage's effects add into GameHeir.trait_total.
##
## For the battle phase: contagion_check() is one exposure (looting, a vial's splash, a toxin's
## backfire), corpse_risk() says what a corpse carries, pass_on(..., "companion", ...) spreads a
## sickness between fighters, advance() moves a companion's sickness along. Companion units are
## rebuilt from data, so their list belongs on the party member dict (saved through load_list())
## and is copied onto the unit. Items: "toxin"
## {poison_pct, turns, weaken?, backfire {disease, chance}}, "vial" {disease, weaken, turns, splash}.
class_name GameDisease
extends RefCounted

const BLACK_MARKET := "black_market"
const YEAR_STEP := 0.0001   # years_in_stage is kept snapped so a save reloads it exactly


# ---------------------------------------------------------------- data

static func settings() -> Dictionary:
	GameData.load_all()
	return GameData.diseases.get("settings", {})


static func setting(key: String) -> Variant:
	return settings()[key]


static func all() -> Array:
	GameData.load_all()
	return GameData.diseases.get("diseases", [])


static func def(id: String) -> Dictionary:
	for dz in all():
		if dz["id"] == id:
			return dz
	return {}


static func disease_name(id: String) -> String:
	return str(def(id).get("name", id))


static func stages(id: String) -> Array:
	return def(id).get("stages", [])


static func stage_def(e: Dictionary) -> Dictionary:
	var st := stages(str(e["id"]))
	return st[clampi(int(e["stage"]), 0, st.size() - 1)] if not st.is_empty() else {}


static func is_last_stage(e: Dictionary) -> bool:
	return int(e["stage"]) >= stages(str(e["id"])).size() - 1


static func is_lethal(id: String) -> bool:
	return str(def(id).get("end", {}).get("kind", "")) == "lethal"


static func natural_chance(id: String, stage: int) -> float:
	var nat: Array = def(id).get("cures", {}).get("natural", [])
	return float(nat[stage]) if stage >= 0 and stage < nat.size() else 0.0


## Chance a year of dying of `id` at `stage`: only the last stage of a deadly sickness kills.
static func death_chance(id: String, stage: int) -> float:
	if not is_lethal(id) or stage < stages(id).size() - 1:
		return 0.0
	return float(def(id)["end"].get("death_per_year", 0.0))


static func contagion_chance(id: String, relation: String) -> float:
	return float(def(id).get("contagion", {}).get(relation, 0.0))


## Per-year chance turned into the chance over `years` (which may be a season).
static func over_years(per_year: float, years: float) -> float:
	if per_year <= 0.0 or years <= 0.0:
		return 0.0
	if per_year >= 1.0:
		return 1.0
	return 1.0 - pow(1.0 - per_year, years)


static func _snap(years: float) -> float:
	return snappedf(years, YEAR_STEP)


# ---------------------------------------------------------------- one body's state

static func entry(h: GameHeir, id: String) -> Dictionary:
	for e in h.diseases:
		if e["id"] == id:
			return e
	return {}


static func has(h: GameHeir, id: String) -> bool:
	return not entry(h, id).is_empty()


## What the current stages take away, as a trait effect total (see GameHeir.trait_total).
static func effect_total(h: GameHeir, stat: String) -> float:
	var t := 0.0
	for e in h.diseases:
		for fx in stage_def(e).get("effects", []):
			if fx["stat"] == stat:
				t += float(fx["value"])
	return t


## Adds a sickness without a roll. False if `h` already has it or it does not exist.
static func infect(h: GameHeir, id: String, source: String, stage: int = 0) -> bool:
	if def(id).is_empty() or has(h, id):
		return false
	var keep := GameItems._vitals(h)
	h.diseases.append({"id": id, "stage": clampi(stage, 0, stages(id).size() - 1), "years_in_stage": 0.0, "source": source})
	GameItems._restore_vitals(h, keep)
	return true


static func cure(h: GameHeir, id: String) -> bool:
	var e := entry(h, id)
	if e.is_empty():
		return false
	var keep := GameItems._vitals(h)
	h.diseases.erase(e)
	GameItems._restore_vitals(h, keep)
	return true


static func _set_stage(h: GameHeir, e: Dictionary, stage: int) -> void:
	var keep := GameItems._vitals(h)
	e["stage"] = stage
	GameItems._restore_vitals(h, keep)


static func household(h: GameHeir) -> Array:
	var out: Array = []
	if h.spouse != null:
		out.append(h.spouse)
	out.append_array(h.children)
	return out


# ---------------------------------------------------------------- resistance & recovery

## Why a body may not catch `id`: [[value, label], ...], strongest first. A value of 1 is immunity.
## Race, class and trait ids share one table (settings.resist) plus the disease's own "resist".
static func resist_sources(h: GameHeir, id: String) -> Array:
	var general: Dictionary = setting("resist")
	var own: Dictionary = def(id).get("resist", {})
	var out: Array = []
	for k in [h.race_id, h.class_id] + h.all_traits():
		var v := float(general.get(k, 0.0)) + float(own.get(k, 0.0))
		if v > 0.0:
			out.append([v, _resist_label(str(k))])
	var cats: Dictionary = setting("category_resist")
	for t in h.all_traits():
		var cat: String = str(GameData.trait_def(t).get("category", ""))
		if cats.has(cat):
			out.append([float(cats[cat]), _resist_label(cat)])
	var vit := _vit_resist(h)
	if vit > 0.0:
		out.append([vit, str(setting("vit_label"))])
	out.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	return out


static func _resist_label(key: String) -> String:
	var labels: Dictionary = setting("resist_labels")
	if labels.has(key):
		return str(labels[key])
	if GameData.races.has(key):
		return "%s blood" % GameData.races[key]["name"]
	if GameData.classes.has(key):
		return "%s training" % GameData.classes[key]["name"]
	return GameData.trait_name(key)


## A body built around VIT shrugs sickness off: compares VIT with the mean of the four stats,
## so it means the same at level 1 and level 5000.
static func _vit_resist(h: GameHeir) -> float:
	var cfg: Dictionary = setting("vit_resist")
	var mean := 0.0
	for s in GameHeir.STATS:
		mean += h.stat(s)
	mean /= float(GameHeir.STATS.size())
	if mean <= 0.0:
		return 0.0
	return clampf((h.stat("vit") / mean - float(cfg["from"])) * float(cfg["per"]), 0.0, float(cfg["max"]))


## 0..resist_cap, or 1 for immunity: the share of an exposure's chance that is turned away.
static func resistance(h: GameHeir, id: String) -> float:
	var total := 0.0
	for src in resist_sources(h, id):
		if float(src[0]) >= 1.0:
			return 1.0
		total += float(src[0])
	return clampf(total, 0.0, float(setting("resist_cap")))


## Multiplies the chance of throwing a sickness off: healing power, healer classes, holy blood.
static func recovery_mult(h: GameHeir) -> float:
	var bonus: Dictionary = setting("recovery")
	var m := 1.0 + h.trait_total("healing_power")
	for k in [h.race_id, h.class_id] + h.all_traits():
		m += float(bonus.get(k, 0.0))
	return maxf(float(setting("recovery_floor")), m)


# ---------------------------------------------------------------- exposure

## Rolls one exposure: "caught", "resisted" (only resistance kept it off) or "" (missed anyway).
static func _expose(d: GameDynasty, unit: GameHeir, id: String, chance: float) -> String:
	if def(id).is_empty() or has(unit, id) or chance <= 0.0:
		return ""
	var roll := d.rng.randf()
	if roll < chance * (1.0 - resistance(unit, id)):
		return "caught"
	return "resisted" if roll < chance else ""


## One exposure to `id` at `base_chance`, lowered by resistance. Infects `unit` on a hit.
## Returns a journal line when it mattered (caught, or kept off only by resistance), else "";
## the caller records it. source: "level", "corpse", "vial", "toxin", "bargain", "companion"...
static func contagion_check(d: GameDynasty, unit: GameHeir, id: String, base_chance: float, source: String) -> String:
	match _expose(d, unit, id, base_chance):
		"caught":
			infect(unit, id, source)
			return _caught_text(unit, id, source)
		"resisted":
			return _resisted_text(unit, id, source)
	return ""


## `from` may pass `id` to `to` over `years`; relation is a contagion key (spouse, child,
## companion). Returns a line if it spread, else "".
static func pass_on(d: GameDynasty, from: GameHeir, to: GameHeir, id: String, relation: String, years: float) -> String:
	var p := over_years(contagion_chance(id, relation), years)
	if p <= 0.0 or has(to, id) or not has(from, id):
		return ""
	if _expose(d, to, id, p) != "caught":
		return ""
	infect(to, id, "family" if relation in ["spouse", "child"] else relation)
	match relation:
		"spouse", "child":
			return "%s's %s %s catches %s." % [from.name, relation, to.name, disease_name(id)]
	return "%s catches %s from %s." % [to.name, disease_name(id), from.name]


## For looting (battle phase): the sickness a fallen foe's corpse may carry here, and the base
## chance of catching it. {} when the corpse is clean.
static func corpse_risk(d: GameDynasty, creature_id: String) -> Dictionary:
	var here: Array = d.world.here().get("biomes", [])
	var pool: Array = []
	var total := 0.0
	for dz in all():
		var c: Dictionary = dz.get("vectors", {}).get("corpse", {})
		if c.is_empty():
			continue
		if creature_id in c.get("creatures", []) or (c.get("biomes", []) as Array).any(func(b): return b in here):
			pool.append(dz)
			total += float(c.get("weight", 1.0))
	if pool.is_empty():
		return {}
	var roll := d.rng.randf() * total
	for dz in pool:
		var c: Dictionary = dz["vectors"]["corpse"]
		roll -= float(c.get("weight", 1.0))
		if roll < 0.0 or dz == pool.back():
			return {"id": dz["id"], "chance": float(c.get("chance", setting("corpse_chance")))}
	return {}


# ---------------------------------------------------------------- time

static func _note(d: GameDynasty, msgs: Array, line: String) -> void:
	d._say(line)
	msgs.append(line)


## Years pass for the living heir's household: sickness clears or worsens, a deadly last stage
## may kill, the heir passes it to the family, and level milestones bring their rolls.
static func on_years(d: GameDynasty, years: float, msgs: Array) -> void:
	var cause := advance(d, d.heir, years, msgs)
	if cause != "":
		msgs.append_array(d._die(cause))
		return
	_spread_home(d, years, msgs)
	_mend_home(d, years, msgs)
	_level_rolls(d, msgs)


## One body's sicknesses over `years`: early stages may clear, untreated ones worsen once their
## stage's years run out. Returns the death cause if a deadly stage claimed them, else "";
## the caller decides what death means for that body.
static func advance(d: GameDynasty, h: GameHeir, years: float, msgs: Array) -> String:
	if h.diseases.is_empty() or years <= 0.0:
		return ""
	var mult := recovery_mult(h)
	var cause := ""
	for e in h.diseases.duplicate():
		var id: String = e["id"]
		var nat := natural_chance(id, int(e["stage"]))
		if nat > 0.0 and d.rng.randf() < over_years(nat * mult, years):
			cure(h, id)
			_note(d, msgs, _clear_text(h, id))
			continue
		e["years_in_stage"] = _snap(float(e["years_in_stage"]) + years)
		var st := stages(id)
		while int(e["stage"]) < st.size() - 1 and float(e["years_in_stage"]) >= float(st[int(e["stage"])].get("years", 1.0)):
			e["years_in_stage"] = _snap(float(e["years_in_stage"]) - float(st[int(e["stage"])].get("years", 1.0)))
			_set_stage(h, e, int(e["stage"]) + 1)
			_note(d, msgs, _worse_text(h, e))
		var death := death_chance(id, int(e["stage"]))
		if cause == "" and death > 0.0 and d.rng.randf() < over_years(death, minf(years, float(e["years_in_stage"]))):
			cause = str(def(id)["end"].get("cause", "taken by " + disease_name(id)))
	return cause


static func _spread_home(d: GameDynasty, years: float, msgs: Array) -> void:
	var h := d.heir
	for e in h.diseases.duplicate():
		for m in household(h):
			var line := pass_on(d, h, m, str(e["id"]), "spouse" if m == h.spouse else "child", years)
			if line != "":
				_note(d, msgs, line)


## The family is nursed at home: their sickness never worsens and clears within a few years.
static func _mend_home(d: GameDynasty, years: float, msgs: Array) -> void:
	var h := d.heir
	for m in household(h):
		for e in m.diseases.duplicate():
			var id: String = e["id"]
			var p := maxf(float(setting("family_recovery")), natural_chance(id, int(e["stage"]))) * recovery_mult(m)
			if d.rng.randf() < over_years(p, years):
				cure(m, id)
				_note(d, msgs, "%s's %s %s shakes off %s." % [h.name, "spouse" if m == h.spouse else "child", m.name, disease_name(id)])


## Each level milestone passed brings one roll against a common sickness; most are shrugged off.
static func _level_rolls(d: GameDynasty, msgs: Array) -> void:
	var h := d.heir
	if h.level <= h.disease_level:
		return
	var from := h.disease_level
	h.disease_level = h.level
	for lv in setting("level_milestones"):
		if int(lv) <= from or int(lv) > h.level:
			continue
		var id := _milestone_pick(d)
		if id == "":
			continue
		var line := contagion_check(d, h, id, float(setting("milestone_chance")), "level")
		if line != "":
			_note(d, msgs, line)


static func _milestone_pick(d: GameDynasty) -> String:
	var here: Array = d.world.here().get("biomes", [])
	var pool: Array = []
	var total := 0.0
	for dz in all():
		var w := float(dz.get("vectors", {}).get("milestone", 0.0))
		if w <= 0.0 or has(d.heir, dz["id"]):
			continue
		if (dz.get("biomes", []) as Array).any(func(b): return b in here):
			w *= float(setting("milestone_biome_mult"))
		pool.append([dz["id"], w])
		total += w
	if pool.is_empty():
		return ""
	var roll := d.rng.randf() * total
	for p in pool:
		roll -= float(p[1])
		if roll < 0.0:
			return p[0]
	return pool.back()[0]


## Rest: early stages may break (a roll on top of the year's own), stages that never clear alone
## are held back for the time spent abed, and a last stage is past helping. Lines go into `msgs`;
## the rest action journals them.
static func on_rest(d: GameDynasty, msgs: Array) -> void:
	var h := d.heir
	var mult := recovery_mult(h)
	var span := float(d.years_for("rest"))
	for e in h.diseases.duplicate():
		var id: String = e["id"]
		if is_last_stage(e):
			continue
		if natural_chance(id, int(e["stage"])) > 0.0:
			if d.rng.randf() < float(def(id)["cures"].get("rest", 0.0)) * mult:
				cure(h, id)
				msgs.append("Bed rest breaks %s's %s." % [h.name, disease_name(id)])
		else:
			e["years_in_stage"] = _snap(float(e["years_in_stage"]) - span)
			msgs.append("Bed rest keeps %s's %s from worsening." % [h.name, disease_name(id)])


## A child born to a sick parent may be born with it. Returns journal lines.
static func on_birth(d: GameDynasty, child: GameHeir) -> Array:
	var out: Array = []
	for parent in [d.heir, d.heir.spouse]:
		if parent == null:
			continue
		for e in parent.diseases:
			var id: String = e["id"]
			if _expose(d, child, id, contagion_chance(id, "birth")) == "caught":
				infect(child, id, "birth")
				out.append("%s is born with %s." % [child.name, disease_name(id)])
	return out


## The new heir takes the family's gear (and whatever hides in it) and may start out sick.
static func on_succession(_d: GameDynasty, parent: GameHeir, c: GameHeir, msgs: Array) -> void:
	c.tainted_gear = parent.tainted_gear.duplicate()
	c.disease_level = c.level
	for e in c.diseases:
		msgs.append("%s comes into the house still sick with %s (%s)." % [c.name, disease_name(e["id"]), stage_def(e)["name"]])


# ---------------------------------------------------------------- treatment

## Temple price: grows with the disease's severity, its stage and the generation.
static func cure_price(d: GameDynasty, id: String) -> int:
	var stage := int(entry(d.heir, id).get("stage", 0))
	var p := float(setting("cure_cost")) * float(def(id).get("cures", {}).get("temple", 1.0))
	p *= (1.0 + float(setting("cure_stage_step")) * float(stage)) * GameItems.price_mult(d)
	return maxi(1, int(round(p)))


static func temple_cure(d: GameDynasty, id: String) -> String:
	var h := d.heir
	var place: String = d.world.here()["name"]
	if not d.world.has_service("temple"):
		return "There is no temple in %s." % place
	if not has(h, id):
		return "%s is not sick with %s." % [h.name, disease_name(id)]
	var cost := cure_price(d, id)
	if h.gold < cost:
		return "The priests ask %s gold to cure %s." % [GameText.num(cost), disease_name(id)]
	h.gold -= cost
	cure(h, id)
	return "The priests of %s cure %s of %s for %s gold." % [place, h.name, disease_name(id), GameText.num(cost)]


## Stages a remedy item takes off (0 = not a remedy).
static func remedy_power(item_id: String) -> int:
	return int(GameItems.item_def(item_id).get("remedy", 0))


static func treats(item_id: String, id: String) -> bool:
	return remedy_power(item_id) > 0 and item_id in def(id).get("cures", {}).get("remedies", [])


static func treatable_by(item_id: String) -> Array:
	return all().filter(func(dz): return treats(item_id, dz["id"])).map(func(dz): return dz["id"])


## The sickness on `h` a remedy would treat: the furthest gone of those it can. "" if none.
static func remedy_target(h: GameHeir, item_id: String) -> String:
	var best := ""
	for e in h.diseases:
		if treats(item_id, e["id"]) and (best == "" or int(e["stage"]) > int(entry(h, best)["stage"])):
			best = e["id"]
	return best


## Take a remedy from the pack: it eases the sickness by its power in stages, past the first
## stage clears it. Takes no time.
static func use_remedy(d: GameDynasty, item_id: String, id: String = "") -> String:
	var h := d.heir
	var iname := GameItems.item_name(item_id)
	if item_id not in h.inventory:
		return "There is no %s in the pack." % iname
	if id == "":
		id = remedy_target(h, item_id)
	if id == "" or not has(h, id):
		return "%s has nothing the %s can treat." % [h.name, iname]
	if not treats(item_id, id):
		return "The %s does nothing for %s." % [iname, disease_name(id)]
	h.inventory.erase(item_id)
	var e := entry(h, id)
	var stage := int(e["stage"]) - remedy_power(item_id)
	if stage < 0:
		cure(h, id)
		return "%s takes the %s, and the %s is gone." % [h.name, iname, disease_name(id)]
	_set_stage(h, e, stage)
	e["years_in_stage"] = 0.0
	return "%s takes the %s: %s eases to %s." % [h.name, iname, disease_name(id), stage_def(e)["name"]]


# ---------------------------------------------------------------- the black market

## Bargain gear may hide a sickness that shows itself the first time it is worn.
static func is_bargain(item_id: String) -> bool:
	return GameItems.item_def(item_id).has("taint")


## After a purchase: smugglers' wares stain the house's name, and a bargain may be tainted.
static func on_buy(d: GameDynasty, item_id: String) -> void:
	var it := GameItems.item_def(item_id)
	if str(it.get("shop", "")) == BLACK_MARKET:
		d._add_echo("infamy", BLACK_MARKET, "House %s deals with smugglers" % d.dynasty_name, float(setting("black_market_infamy")))
	if is_bargain(item_id) and item_id not in d.heir.tainted_gear:
		if d.rng.randf() < float(it["taint"].get("chance", setting("bargain_taint_chance"))):
			d.heir.tainted_gear.append(item_id)


## The heir puts gear on: a tainted bargain gives up its sickness now. Returns a line or "",
## which follows the caller's sentence naming the item.
static func on_wear(d: GameDynasty, item_id: String) -> String:
	var h := d.heir
	if item_id not in h.tainted_gear:
		return ""
	h.tainted_gear.erase(item_id)
	if not is_bargain(item_id):   # a save made before the data dropped this taint
		return ""
	var id: String = str(GameItems.item_def(item_id)["taint"].get("disease", ""))
	match _expose(d, h, id, 1.0):
		"caught":
			infect(h, id, "bargain")
			return "It came cheap for a reason: %s has %s (%s)." % [h.name, disease_name(id), _fx(id, 0)]
		"resisted":
			return "It carried %s, but %s keeps %s well." % [disease_name(id), resist_sources(h, id)[0][1], h.name]
	return ""


# ---------------------------------------------------------------- autopilot

## Errands between actions (no time passes): treat the worst sickness first with a remedy
## carried, else the cheaper of a remedy sold here or the temple, keeping the potion reserve.
## The bot stays away from the black market.
static func bot_tick(d: GameDynasty) -> void:
	if d.state != "life" or d.battle != null:
		return
	var h := d.heir
	for i in 10:
		var acted := false
		for id in _by_severity(h):
			if _bot_treat(d, id):
				acted = true
				break
		if not acted:
			return


static func _by_severity(h: GameHeir) -> Array:
	var ids: Array = h.diseases.map(func(e): return e["id"])
	ids.sort_custom(func(a, b): return _severity(h, a) > _severity(h, b))
	return ids


static func _severity(h: GameHeir, id: String) -> float:
	return float(entry(h, id)["stage"]) + (10.0 if is_lethal(id) else 0.0)


static func _bot_treat(d: GameDynasty, id: String) -> bool:
	var h := d.heir
	var carried := ""
	for it in h.inventory:
		if treats(it, id) and (carried == "" or remedy_power(it) > remedy_power(carried)):
			carried = it
	if carried != "":
		d._say(use_remedy(d, carried, id))
		return true
	var reserve := GameItems.bot_reserve(d)
	var stage := int(entry(h, id)["stage"])
	var temple := cure_price(d, id) if d.world.has_service("temple") else -1
	var buy := ""
	var buy_cost := 0
	for s in GameItems.shops_here(d):
		if s == BLACK_MARKET:
			continue
		for it in GameItems.stock(d, s):
			if not treats(it, id):
				continue
			var cost := GameItems.price(d, it) * int(ceil(float(stage + 1) / float(remedy_power(it))))
			if buy == "" or cost < buy_cost:
				buy = it
				buy_cost = cost
	if buy != "" and (temple < 0 or buy_cost <= temple) and h.gold - GameItems.price(d, buy) >= reserve:
		var had := GameItems.count(h, buy)
		d._say(GameItems.buy(d, buy))
		if GameItems.count(h, buy) > had:
			d._say(use_remedy(d, buy, id))
			return true
	if temple >= 0 and h.gold - temple >= reserve:
		d._say(temple_cure(d, id))
		return true
	return false


# ---------------------------------------------------------------- text

static func _fx(id: String, stage: int) -> String:
	return GameItems.describe_effects(stages(id)[stage].get("effects", []))


## "young", "adult" or "elder": lines read differently across a life.
static func age_band(h: GameHeir) -> String:
	if h.age >= h.lifespan * float(GameData.bal("elder_fraction")):
		return "elder"
	if h.age < h.adult_age() + float(setting("young_years")):
		return "young"
	return "adult"


static func _caught_text(h: GameHeir, id: String, source: String) -> String:
	var nm := disease_name(id)
	var fx := _fx(id, 0)
	match source:
		"level":
			match age_band(h):
				"young":
					return "Green to the road, %s picks up %s (%s)." % [h.name, nm, fx]
				"elder":
					return "%s finds %s at %d, slower to mend than once (%s)." % [nm, h.name, int(h.age), fx]
			return "Hard years on the road: %s comes down with %s (%s)." % [h.name, nm, fx]
		"corpse":
			return "%s handles the dead and catches %s (%s)." % [h.name, nm, fx]
		"vial":
			return "The vial's fumes reach %s: %s (%s)." % [h.name, nm, fx]
		"toxin":
			return "Poison gets into %s's hands: %s (%s)." % [h.name, nm, fx]
	return "%s catches %s (%s)." % [h.name, nm, fx]


static func _resisted_text(h: GameHeir, id: String, source: String) -> String:
	var why: String = resist_sources(h, id)[0][1]
	if source == "level":
		return "%s goes round the camp, but %s keeps %s well." % [disease_name(id), why, h.name]
	return "%s brushes past %s; %s keeps it off." % [disease_name(id), h.name, why]


static func _worse_text(h: GameHeir, e: Dictionary) -> String:
	var id: String = e["id"]
	var st: Dictionary = stage_def(e)
	var fx := _fx(id, int(e["stage"]))
	var line: String
	if age_band(h) == "elder":
		line = "At %d, %s cannot throw off %s: %s (%s)." % [int(h.age), h.name, disease_name(id), st["name"], fx]
	else:
		line = "%s's %s worsens: %s (%s)." % [h.name, disease_name(id), st["name"], fx]
	if is_last_stage(e):
		line += " Untreated, it can kill." if is_lethal(id) else " Untreated, it may stay for life."
	return line


static func _clear_text(h: GameHeir, id: String) -> String:
	match age_band(h):
		"young":
			return "%s shakes off %s." % [h.name, disease_name(id)]
		"elder":
			return "%s's %s clears at last." % [h.name, disease_name(id)]
	return "%s's %s clears up." % [h.name, disease_name(id)]


## How a sickness stands, for the life screen: "worsens in 2 seasons", "can kill: 10% a year".
static func outlook(e: Dictionary) -> String:
	var id: String = e["id"]
	var parts: Array = []
	if not is_last_stage(e):
		var left := maxf(0.25, float(stage_def(e).get("years", 1.0)) - maxf(0.0, float(e["years_in_stage"])))
		parts.append("worsens in %s" % GameDynasty._span_text(left))
	elif is_lethal(id):
		parts.append("can kill: %d%% a year" % int(round(death_chance(id, int(e["stage"])) * 100.0)))
	elif natural_chance(id, int(e["stage"])) > 0.0:
		parts.append("lingers; rarely clears without a cure")
	else:
		parts.append("stays until cured")
	if not is_last_stage(e) and natural_chance(id, int(e["stage"])) > 0.0:
		parts.append("may clear with rest")
	return "; ".join(parts)


## One line per sickness for panels: name, stage, effects and outlook.
static func describe_entry(e: Dictionary) -> Dictionary:
	var id: String = e["id"]
	return {
		"name": disease_name(id), "stage_name": stage_def(e)["name"], "stage": int(e["stage"]) + 1,
		"stages": stages(id).size(), "effects": _fx(id, int(e["stage"])), "outlook": outlook(e),
		"description": str(def(id).get("description", "")), "lethal": is_lethal(id),
	}


## "Camp Cough, Red Flux" (or "" when well), for family rows and heir cards.
static func status_text(h: GameHeir) -> String:
	return ", ".join(h.diseases.map(func(e): return disease_name(e["id"])))


# ---------------------------------------------------------------- save / load & checks

## A saved disease list, cleaned: unknown sicknesses dropped, numbers restored to their types.
static func load_list(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for r in raw:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var id := str(r.get("id", ""))
		if def(id).is_empty() or out.any(func(x): return x["id"] == id):
			continue
		out.append({
			"id": id, "stage": clampi(int(r.get("stage", 0)), 0, stages(id).size() - 1),
			"years_in_stage": _snap(float(r.get("years_in_stage", 0.0))), "source": str(r.get("source", "")),
		})
	return out


## Anything wrong with the disease data or the items that refer to it.
static func validate() -> Array:
	var bad: Array = []
	var labels := GameItems._effect_labels()
	var last := 0
	for lv in setting("level_milestones"):
		if int(lv) <= last:
			bad.append("level milestones must rise: %d" % int(lv))
		last = int(lv)
	for dz in all():
		var id: String = dz.get("id", "?")
		var st: Array = dz.get("stages", [])
		if st.is_empty() or str(dz.get("name", "")) == "" or str(dz.get("description", "")) == "":
			bad.append("%s: needs a name, description and stages" % id)
		for i in st.size():
			if i < st.size() - 1 and float(st[i].get("years", 0.0)) <= 0.0:
				bad.append("%s stage %d: needs years before it worsens" % [id, i])
			for fx in st[i].get("effects", []):
				if not labels.has(fx["stat"]) or float(fx["value"]) >= 0.0:
					bad.append("%s stage %d: %s must be a known stat lowered" % [id, i, fx["stat"]])
		var cures: Dictionary = dz.get("cures", {})
		if (cures.get("natural", []) as Array).size() != st.size():
			bad.append("%s: one natural recovery chance per stage" % id)
		for it in cures.get("remedies", []):
			if remedy_power(it) <= 0:
				bad.append("%s: remedy %s is not a remedy item" % [id, it])
		var end: Dictionary = dz.get("end", {})
		if str(end.get("kind", "")) not in ["chronic", "lethal"]:
			bad.append("%s: end must be chronic or lethal" % id)
		if is_lethal(id) and (float(end.get("death_per_year", 0.0)) <= 0.0 or str(end.get("cause", "")) == ""):
			bad.append("%s: a lethal end needs death_per_year and cause" % id)
		for k in ["spouse", "child", "companion", "birth"]:
			var c: float = float(dz.get("contagion", {}).get(k, -1.0))
			if c < 0.0 or c > 1.0:
				bad.append("%s: contagion %s missing or out of range" % [id, k])
	for item_id in GameData.items:
		var it: Dictionary = GameData.items[item_id]
		for ref in [it.get("taint", {}).get("disease", null), it.get("vial", {}).get("disease", null), it.get("toxin", {}).get("backfire", {}).get("disease", null)]:
			if ref != null and def(str(ref)).is_empty():
				bad.append("%s refers to unknown disease %s" % [item_id, ref])
		if remedy_power(item_id) > 0 and treatable_by(item_id).is_empty():
			bad.append("%s treats nothing" % item_id)
	return bad
