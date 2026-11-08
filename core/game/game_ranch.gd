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


static func yearly_keep(e: Dictionary) -> float:
	var k := float(size_of(str(e["species"]))["keep"])
	return k * float(setting("egg_keep_share")) if str(e.get("stage")) == "egg" else k


## What the whole roster costs to keep each year, in gold (a part of a gold is rounded up).
static func keep_total(d: GameDynasty) -> int:
	var due := 0.0
	for e in d.roster:
		due += yearly_keep(e)
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
	var due := 0.0
	for e in d.roster:
		due += yearly_keep(e) * years
	var cost := int(ceil(due))
	var paid := mini(cost, maxi(0, d.heir.gold))
	d.heir.gold -= paid
	var ratio := 1.0 if cost <= 0 else float(paid) / float(cost)
	var gain := float(setting("fed_mood_gain")) * years * ratio
	var loss := float(setting("unfed_mood_loss")) * years * (1.0 - ratio)
	var top := int(setting("mood_max"))
	var kept: Array = []
	for e in d.roster:
		for line in _live_years(d, e, years, gain - loss, top):
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
		for k in SIZE_KEYS:
			if not dat["sizes"][name].has(k) or float(dat["sizes"][name][k]) <= 0.0:
				bad.append("ranch.json: size '%s' needs a positive %s" % [name, k])
	for sp in dat["size_of"]:
		if GameBirth.born(str(sp)) == "none":
			bad.append("ranch.json: size_of names '%s', which is not born" % sp)
		if not dat["sizes"].has(str(dat["size_of"][sp])):
			bad.append("ranch.json: '%s' has unknown size '%s'" % [sp, dat["size_of"][sp]])
	for c in GameData.creatures:
		if GameBirth.born(str(c["id"])) != "none" and not dat["size_of"].has(str(c["id"])):
			bad.append("ranch.json: '%s' is born but has no size (it would use the default)" % c["id"])
	for k in ["hatches", "grows_up", "grows_old", "dies", "spoils", "leaves", "stage_egg", "stage_young", "stage_adult", "stage_elder", "mood_high", "mood_mid", "mood_low", "age", "keep"]:
		if not dat["text"].has(k):
			bad.append("ranch.json: text.%s is missing" % k)
	return bad
