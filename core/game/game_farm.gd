## Farm animals and what they are worth (roadmap item 62, first part). Farm animals are creatures flagged `farm`
## in creatures.json: never fought and never found beside the dead, but bought young at a town's market, raised
## and bred like any creature (GameRanch, GameBreeding). Their yearly work (wool, milk, eggs) follows the season and
## how well they are kept; meat and hide are paid once, when one is slaughtered. No dice are drawn, and a house that
## keeps none is exactly what it was. Data: data/creatures/farm.json (the work itself is in ranch.json's work_of).
class_name GameFarm
extends RefCounted

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json("res://data/creatures/farm.json")
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


static func is_farm(species: String) -> bool:
	return GameCombat.creature_def(species).get("farm", false) == true


## The farm species the market sells, in a fixed order.
static func market_species() -> Array:
	var ids: Array = data()["market"].keys()
	ids.sort()
	return ids


static func young_name(species: String) -> String:
	return GameBirth.young_name(species)


## How much of its yield a creature gives for how it has been kept: the floor at the lowest mood, 1 at the top.
static func mood_scale(e: Dictionary) -> float:
	var floor_v := float(setting("mood_floor"))
	var top := float(GameRanch.setting("mood_max"))
	return floor_v + (1.0 - floor_v) * clampf(float(e.get("mood", 0)) / top, 0.0, 1.0)


## The multiplier on a farm animal's yearly work: the season's, if the dynasty is known, times how well it is kept.
## 1.0 for anything that is not a farm animal (the wild creatures' work is as it was).
static func yield_mult(d: GameDynasty, e: Dictionary) -> float:
	var species := str(e.get("species", ""))
	if not is_farm(species):
		return 1.0
	var w := GameRanch.work_of(species)
	var m := mood_scale(e)
	if d != null and d.world != null and not w.is_empty():
		m *= float(setting("season_mult").get(str(w["kind"]), {}).get(str(d.world.season()["id"]), 1.0))
	return m


# ---------------------------------------------------------------- the market

static func price(species: String) -> int:
	return int(data()["market"].get(species, 0))


## Why this animal cannot be bought now, or "".
static func why_not_buy(d: GameDynasty, species: String) -> String:
	if d.state != "life" or d.heir == null:
		return text("outside_life")
	if price(species) <= 0:
		return "The market does not sell that."
	if str(d.world.here().get("type", "")) != str(setting("market_place_type")):
		return text("not_in_town")
	if GameRoster.full(d):
		return text("no_room")
	if d.heir.gold < price(species):
		return text("not_enough", {"gold": GameText.num(price(species))})
	return ""


## Buys a young animal at the market. It joins the roster as young (a bird skips its egg). The name and sex are
## keyed on the seed, the generation and what is already kept, never the dynasty's dice. Returns the line told, or "".
static func buy(d: GameDynasty, species: String) -> String:
	if why_not_buy(d, species) != "":
		return ""
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "market", d.gen, species, d.roster.size(), d.total_hunts])
	var e := GameRoster.add(d, species, GameInheritance.random_name(r))
	if e.is_empty():
		return ""
	e["stage"] = "young"
	e["age"] = GameRanch.egg_years(e)
	var gold := price(species)
	d.heir.gold -= gold
	var line := text("bought", {"h": d.heir.name, "young": young_name(species), "species": _name(species), "gold": GameText.num(gold), "name": e["name"]})
	d._say(line)
	return line


# ---------------------------------------------------------------- slaughter

## What slaughtering this animal now would fetch, or 0 when it cannot be (not a farm animal, or still an egg).
static func slaughter_value(e: Dictionary) -> int:
	var species := str(e.get("species", ""))
	var table: Dictionary = data()["slaughter"].get(species, {})
	var stage_mult := float(setting("slaughter_stage").get(str(e.get("stage")), 0.0))
	if table.is_empty() or stage_mult <= 0.0 or not is_farm(species) or species in setting("no_slaughter"):
		return 0
	return maxi(1, int(round((float(table["meat"]) + float(table["hide"])) * stage_mult * mood_scale(e))))


## Slaughters a farm animal for its meat and hide. Returns the line told, or "" (not a farm animal, an egg, no such
## animal, or not in a life).
static func slaughter(d: GameDynasty, id: int) -> String:
	var e := GameRanch.find(d, id)
	if e.is_empty() or d.state != "life":
		return ""
	var gold := slaughter_value(e)
	if gold <= 0:
		return ""
	d.heir.gold += gold
	d.roster.erase(e)
	var line := text("slaughtered", {"h": d.heir.name, "name": str(e["name"]), "species": _name(str(e["species"])), "gold": GameText.num(gold)})
	d._say(line)
	return line


static func _name(species: String) -> String:
	return str(GameCombat.creature_def(species).get("name", species)).to_lower()


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "market", "slaughter", "text"]:
		if not dat.has(k):
			bad.append("farm.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var s: Dictionary = dat["settings"]
	for k in ["mood_floor", "season_mult", "slaughter_stage", "market_place_type", "no_slaughter"]:
		if not s.has(k):
			bad.append("farm.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if float(s["mood_floor"]) <= 0.0 or float(s["mood_floor"]) > 1.0:
		bad.append("farm.json: mood_floor must be above 0 and at most 1")
	var seasons: Array = GameData.world["seasons"].map(func(x): return str(x["id"]))
	for kind in s["season_mult"]:
		if not GameRanch.data()["work"]["kinds"].has(kind):
			bad.append("farm.json: season_mult names '%s', which is not a work kind" % kind)
		for sid in seasons:
			if not s["season_mult"][kind].has(sid) or float(s["season_mult"][kind][sid]) <= 0.0:
				bad.append("farm.json: season_mult.%s needs a positive %s" % [kind, sid])
	for st in s["slaughter_stage"]:
		if st not in GameRanch.STAGES or st == "egg" or float(s["slaughter_stage"][st]) <= 0.0:
			bad.append("farm.json: slaughter_stage.%s must be a stage after the egg with a positive share" % st)
	for sp in dat["market"]:
		if not is_farm(str(sp)) or GameBirth.born(str(sp)) == "none":
			bad.append("farm.json: the market sells '%s', which is not a born farm animal" % sp)
		elif int(dat["market"][sp]) <= 0:
			bad.append("farm.json: the market price of '%s' must be above 0" % sp)
	for sp in s["no_slaughter"]:
		if not is_farm(str(sp)):
			bad.append("farm.json: no_slaughter names '%s', which is not a farm animal" % sp)
		elif dat["slaughter"].has(str(sp)):
			bad.append("farm.json: '%s' has meat and hide and is also in no_slaughter" % sp)
	for sp in dat["slaughter"]:
		var t: Dictionary = dat["slaughter"][sp]
		if not is_farm(str(sp)):
			bad.append("farm.json: slaughter names '%s', which is not a farm animal" % sp)
		if not t.has("meat") or not t.has("hide") or float(t.get("meat", 0)) <= 0.0 or float(t.get("hide", 0)) < 0.0:
			bad.append("farm.json: slaughter.%s needs a positive meat and a hide of 0 or more" % sp)
	for c in GameData.creatures:
		if c.get("farm", false):
			var id := str(c["id"])
			if GameBirth.born(id) == "none":
				bad.append("farm.json: farm animal '%s' is not born" % id)
			if not dat["market"].has(id):
				bad.append("farm.json: farm animal '%s' is not sold at the market" % id)
			if not dat["slaughter"].has(id) and id not in s["no_slaughter"]:
				bad.append("farm.json: farm animal '%s' has no meat and hide and is not in no_slaughter" % id)
			if c.get("boss", false):
				bad.append("farm.json: farm animal '%s' is a boss" % id)
	for k in ["buy", "bought", "slaughter", "sure_slaughter", "slaughtered", "market_head", "market_note", "not_in_town", "no_room", "not_enough", "outside_life"]:
		if not dat["text"].has(k):
			bad.append("farm.json: text.%s is missing" % k)
	return bad
