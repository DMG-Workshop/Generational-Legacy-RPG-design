## Breeding at the ranch (roadmap item 57, first part). A creature set to breed (`breeding` on its roster entry) pairs
## each year with a compatible creature of the opposite sex, and the pair may have young. How the young are born is
## GameBirth's rule; who may pair, how often, what the young inherit and how they mutate are in
## data/creatures/breeding_rules.json. Every roll is keyed on the dynasty seed, the year and the two creatures
## (never the dynasty's own dice), so nothing in a life moves, and a ranch that breeds nothing does nothing.
class_name GameBreeding
extends RefCounted

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json("res://data/creatures/breeding_rules.json")
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary) -> String:
	return str(data()["text"][key]).format(vals)


static func family_of(species: String) -> String:
	for f in data()["families"]:
		if species in data()["families"][f]:
			return str(f)
	return ""


## Whether two species can have young together: both are born, and they are one species, kin (a family) or a recipe.
static func compatible(a: String, b: String) -> bool:
	var k := GameBirth.kind(a, b)
	if k == "":
		return false
	if k == "pure" or k == "hybrid":
		return true
	var fa := family_of(a)
	return fa != "" and fa == family_of(b)


## "pure", "hybrid" or "cross" for a pair that is compatible, else "".
static func kind(a: String, b: String) -> String:
	return GameBirth.kind(a, b) if compatible(a, b) else ""


## What a trait does to a number: the product over the creature's traits of the trait's `key` (1.0 when none says).
static func trait_mult(e: Dictionary, key: String) -> float:
	var m := 1.0
	for t in e.get("traits", []):
		m *= float(data()["traits"].get(str(t), {}).get(key, 1.0))
	return m


## Whether this creature could have young now (the flag only says it is meant to).
static func able(e: Dictionary) -> bool:
	if not e.get("breeding", false) or e.get("sterile", false) or float(e.get("cooldown", 0.0)) > 0.0:
		return false
	if int(e.get("mood", 0)) < int(setting("min_mood")):
		return false
	return GameRanch.STAGES.find(str(e.get("stage"))) >= GameRanch.STAGES.find(str(setting("min_stage"))) \
			and str(e.get("stage")) != "elder"


## Whether the player may set this creature to breed: it is grown, not old, not sterile, and of a kind that can breed.
static func can_set(e: Dictionary) -> bool:
	return not e.get("sterile", false) and str(e.get("stage")) in ["adult"] and GameBirth.can_breed(str(e.get("species", "")))


## Sets a creature to breed or to rest. Returns whether it was changed (not in a life, no such creature, or one that cannot).
static func set_breeding(d: GameDynasty, id: int, on: bool) -> bool:
	var e := GameRanch.find(d, id)
	if e.is_empty() or d.state != "life" or (on and not can_set(e)):
		return false
	e["breeding"] = on
	return true


## The pairs the roster makes now: [[mother, father], ...] in id order, each creature in at most one pair. A creature
## pairs with the first able creature of the opposite sex it is compatible with.
static func pairs(d: GameDynasty) -> Array:
	var out: Array = []
	var used := {}
	var list: Array = d.roster.duplicate()
	list.sort_custom(func(a, b): return int(a["id"]) < int(b["id"]))
	for e in list:
		if used.has(int(e["id"])) or not able(e):
			continue
		for o in list:
			if int(o["id"]) == int(e["id"]) or used.has(int(o["id"])) or not able(o):
				continue
			if str(o["sex"]) == str(e["sex"]) or not compatible(str(e["species"]), str(o["species"])):
				continue
			used[int(e["id"])] = true
			used[int(o["id"])] = true
			out.append([e, o] if str(e["sex"]) == GameSex.FEMALE else [o, e])
			break
	return out


## A pair's chance of young in a year: by kind, and by the parents' traits.
static func fertility(mother: Dictionary, father: Dictionary) -> float:
	var k := kind(str(mother["species"]), str(father["species"]))
	if k == "":
		return 0.0
	var base := float(setting("fertility")[k])
	return clampf(base * trait_mult(mother, "fertility_mult") * trait_mult(father, "fertility_mult"), 0.0, 1.0)


static func _rng(d: GameDynasty, parts: Array) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "breed"] + parts)
	return r


## Time passes: cooldowns run down, and for each year that ended (a whole year number the world clock crossed)
## each pair rolls for young. `year_end` is the world's year now (a parameter so a test can set it). Lines are told
## and journalled.
static func on_years(d: GameDynasty, years: float, msgs: Array, year_end: float = -1.0) -> void:
	if d.roster.is_empty() or years <= 0.0:
		return
	for e in d.roster:
		e["cooldown"] = maxf(0.0, float(e.get("cooldown", 0.0)) - years)
	var end := d.world.year if year_end < 0.0 else year_end
	var first := int(floor(end - years)) + 1
	var last := int(floor(end))
	for y in range(first, last + 1):
		for pair in pairs(d):
			if GameRoster.full(d):
				return
			var mother: Dictionary = pair[0]
			var father: Dictionary = pair[1]
			var r := _rng(d, [y, int(mother["id"]), int(father["id"])])
			if r.randf() >= fertility(mother, father):
				continue
			for line in _birth(d, mother, father, r):
				d._say(line)
				msgs.append(line)


## Young are born to the pair. Returns the lines to tell.
static func _birth(d: GameDynasty, mother: Dictionary, father: Dictionary, r: RandomNumberGenerator) -> Array:
	var ms := str(mother["species"])
	var fs := str(father["species"])
	var k := kind(ms, fs)
	var species := ms
	if k == "hybrid":
		var s := str(GameBirth.recipe_for(ms, fs).get("species", ""))
		if s != "" and GameBirth.born(s) != "none":
			species = s
	var mode := GameBirth.mode(ms, fs)
	if mode == "":
		return []
	var name_rng := RandomNumberGenerator.new()
	name_rng.seed = r.randi()
	var e := GameRoster.add(d, species, GameInheritance.random_name(name_rng))
	if e.is_empty():
		return []
	e["born"] = mode
	e["stage"] = "egg" if mode == "egg" else "young"
	e["young"] = GameBirth.young_of(ms, fs)
	e["bred"] = true
	e["parents"] = [str(mother["name"]), str(father["name"])]
	e["line"] = str(mother.get("line", "")) if str(mother.get("line", "")) != "" else str(mother["name"])
	if k == "cross":
		e["lines"] = [ms, fs]
	var traits: Array = []
	for parent in [mother, father]:
		for t in parent.get("traits", []):
			if t not in traits and r.randf() < float(setting("trait_pass_chance")):
				traits.append(t)
	var out: Array = []
	var pool: Array = data()["traits"].keys()
	pool.sort()
	var mutated := ""
	if r.randf() < float(setting("mutation_chance")):
		var t := str(pool[r.randi() % pool.size()])
		if t not in traits:
			traits.append(t)
			mutated = t
	e["traits"] = traits.slice(0, int(setting("max_traits")))
	if mutated != "" and mutated in e["traits"]:
		out.append(text("mutates", {"name": e["name"], "trait": str(data()["traits"][mutated]["name"])}))
	if r.randf() < float(setting("sterile_chance")[k]):
		e["sterile"] = true
		out.append(text("sterile", {"name": e["name"]}))
	mother["cooldown"] = float(setting("cooldown")[mode])
	var def := GameCombat.creature_def(ms)
	var vals := {"mother": str(mother["name"]), "name": e["name"], "young": e["young"], "species": str(def.get("name", ms)).to_lower()}
	out.push_front(text("born_egg" if mode == "egg" else "born_live", vals))
	return out


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "families", "traits", "text"]:
		if not dat.has(k):
			bad.append("breeding_rules.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var s: Dictionary = dat["settings"]
	for k in ["min_stage", "min_mood", "fertility", "sterile_chance", "cooldown", "trait_pass_chance", "mutation_chance", "max_traits"]:
		if not s.has(k):
			bad.append("breeding_rules.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if not GameRanch.STAGES.has(str(s["min_stage"])):
		bad.append("breeding_rules.json: min_stage '%s' is not a stage" % s["min_stage"])
	for kind_name in ["pure", "hybrid", "cross"]:
		if not s["fertility"].has(kind_name) or float(s["fertility"][kind_name]) < 0.0 or float(s["fertility"][kind_name]) > 1.0:
			bad.append("breeding_rules.json: fertility.%s must be between 0 and 1" % kind_name)
		if not s["sterile_chance"].has(kind_name) or float(s["sterile_chance"][kind_name]) < 0.0 or float(s["sterile_chance"][kind_name]) > 1.0:
			bad.append("breeding_rules.json: sterile_chance.%s must be between 0 and 1" % kind_name)
	for m in ["egg", "live"]:
		if not s["cooldown"].has(m) or float(s["cooldown"][m]) < 0.0:
			bad.append("breeding_rules.json: cooldown.%s must be 0 or more" % m)
	for k in ["trait_pass_chance", "mutation_chance"]:
		if float(s[k]) < 0.0 or float(s[k]) > 1.0:
			bad.append("breeding_rules.json: %s must be between 0 and 1" % k)
	if int(s["max_traits"]) < 1:
		bad.append("breeding_rules.json: max_traits must be at least 1")
	var seen := {}
	for f in dat["families"]:
		for sp in dat["families"][f]:
			if GameBirth.born(str(sp)) == "none":
				bad.append("breeding_rules.json: family '%s' names '%s', which is not born" % [f, sp])
			if seen.has(str(sp)):
				bad.append("breeding_rules.json: '%s' is in two families (%s and %s)" % [sp, seen[str(sp)], f])
			seen[str(sp)] = f
	for t in dat["traits"]:
		var def: Dictionary = dat["traits"][t]
		if not def.has("name") or not def.has("about"):
			bad.append("breeding_rules.json: trait '%s' needs a name and an about" % t)
		for k in def:
			if k not in ["name", "about", "mood_loss_mult", "value_mult", "work_mult", "guard_mult", "fertility_mult"]:
				bad.append("breeding_rules.json: trait '%s' has an unknown effect '%s'" % [t, k])
			elif k not in ["name", "about"] and float(def[k]) <= 0.0:
				bad.append("breeding_rules.json: trait '%s' %s must be above 0" % [t, k])
	for r in GameData.breeding.get("recipes", []):
		var sp := str(r.get("species", ""))
		if sp != "" and GameBirth.born(sp) == "none":
			bad.append("breeding.json: recipe '%s' makes '%s', which is not a born creature" % [r.get("id", "?"), sp])
	for k in ["born_egg", "born_live", "sterile", "mutates", "breed_on", "breed_off", "pairs", "line", "cross", "sterile_note", "traits", "bred", "bred_grown"]:
		if not dat["text"].has(k):
			bad.append("breeding_rules.json: text.%s is missing" % k)
	return bad
