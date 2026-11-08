## The creatures the family keeps: eggs and young found beside the dead and raised (roadmap item 55).
## Held on the dynasty as `roster` (only once something is found, so old saves load as before). An
## entry: {id, species, name, sex, stage (egg, young, adult or elder: GameRanch.STAGES), born ("egg" or "live"),
## young (what the species calls its young), age (years), mood, found_gen, found_by}. Years pass in GameRanch.
class_name GameRoster
extends RefCounted



## The places for creatures: the family's own (finding.json) and the Ranch's pens.
static func cap(d: GameDynasty) -> int:
	return int(GameFinding.setting("roster_cap")) + GameRanch.extra_pens(d)


static func full(d: GameDynasty) -> bool:
	return d.roster.size() >= cap(d)


static func next_id(d: GameDynasty) -> int:
	var top := 0
	for e in d.roster:
		top = maxi(top, int(e["id"]))
	return top + 1


## Adds a found creature of a species that is born; returns the entry, or {} if it cannot be kept.
static func add(d: GameDynasty, species: String, name: String) -> Dictionary:
	var mode := GameBirth.born(species)
	if mode == "none" or full(d):
		return {}
	var id := next_id(d)
	var e := {
		"id": id, "species": species, "name": name,
		"sex": GameSex.roll(d.seed_value, int(hash(["creature", id]))),
		"stage": "egg" if mode == "egg" else "young", "born": mode,
		"young": GameBirth.young_name(species), "age": 0.0, "mood": int(GameRanch.setting("start_mood")),
		"traits": [], "breeding": false, "cooldown": 0.0, "sterile": false,
		"found_gen": d.gen, "found_by": d.heir.name,
	}
	d.roster.append(e)
	return e


## A saved list made safe: wrong shapes, unknown species, unborn species, bad stages and repeated ids are dropped.
static func load_list(v: Variant) -> Array:
	var out: Array = []
	if typeof(v) != TYPE_ARRAY:
		return out
	var seen := {}
	for e in v:
		if typeof(e) != TYPE_DICTIONARY or not (e.has("id") and e.has("species")):
			continue
		if typeof(e["id"]) not in [TYPE_INT, TYPE_FLOAT] or typeof(e["species"]) != TYPE_STRING:
			continue
		var id := int(e["id"])
		var sp: String = e["species"]
		if seen.has(id) or GameBirth.born(sp) == "none":
			continue
		var mode := GameBirth.born(sp)
		var lines := _species_pair(e.get("lines"))
		if not lines.is_empty() and str(e.get("born")) in ["egg", "live"]:
			mode = str(e["born"])   # a cross-breed follows the way its parents' pairing is born
		var age: float = float(e["age"]) if typeof(e.get("age")) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(e["age"])) else 0.0
		var mood: int = int(e["mood"]) if typeof(e.get("mood")) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(e["mood"])) else int(GameRanch.setting("start_mood"))
		var entry := {
			"id": id, "species": sp, "name": str(e.get("name", "")),
			"sex": str(e.get("sex")) if GameSex.valid(e.get("sex")) else GameSex.roll(0, id),
			"born": mode, "young": GameBirth.young_name(sp),
			"age": maxf(0.0, age), "mood": clampi(mood, 1, int(GameRanch.setting("mood_max"))),
			"found_gen": int(e.get("found_gen", 1)), "found_by": str(e.get("found_by", "")),
			"traits": _traits(e.get("traits")), "breeding": _flag(e.get("breeding")),
			"sterile": _flag(e.get("sterile")),
			"cooldown": _years(e.get("cooldown")),
		}
		if _flag(e.get("bred")):
			entry["bred"] = true
			entry["parents"] = _names(e.get("parents"))
		if typeof(e.get("line")) == TYPE_STRING and str(e["line"]) != "":
			entry["line"] = str(e["line"])
		if not lines.is_empty():
			entry["lines"] = lines
			if typeof(e.get("young")) == TYPE_STRING and str(e["young"]) != "":
				entry["young"] = str(e["young"])
		entry["stage"] = GameRanch.stage_at(entry, entry["age"])   # the stage follows the age, whatever was saved
		out.append(entry)
		seen[id] = true
	return out


static func _species_name(species: String) -> String:
	return str(GameCombat.creature_def(species).get("name", species)).to_lower()


## A saved yes-or-no: only a real true is true.
static func _flag(v: Variant) -> bool:
	return typeof(v) == TYPE_BOOL and v


static func _years(v: Variant) -> float:
	return maxf(0.0, float(v)) if typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)) else 0.0


## A saved list of trait ids made safe: known ids only, no repeats, no more than the most a creature may hold.
static func _traits(v: Variant) -> Array:
	var out: Array = []
	if typeof(v) != TYPE_ARRAY:
		return out
	for t in v:
		if typeof(t) == TYPE_STRING and GameBreeding.data()["traits"].has(t) and t not in out:
			out.append(t)
	return out.slice(0, int(GameBreeding.setting("max_traits")))


## Two names, or [] when what was saved is not a pair of strings.
static func _names(v: Variant) -> Array:
	if typeof(v) == TYPE_ARRAY and (v as Array).size() == 2 and typeof(v[0]) == TYPE_STRING and typeof(v[1]) == TYPE_STRING:
		return [str(v[0]), str(v[1])]
	return []


## Two born species that are a cross-breed's lines, or [].
static func _species_pair(v: Variant) -> Array:
	if typeof(v) == TYPE_ARRAY and (v as Array).size() == 2 and typeof(v[0]) == TYPE_STRING and typeof(v[1]) == TYPE_STRING:
		if GameBreeding.kind(str(v[0]), str(v[1])) == "cross":
			return [str(v[0]), str(v[1])]
	return []


## What a kept creature is called on a screen: {name, stage, line}. The name and the stage are the title, the
## line says what it is and who found it. Text is in data/creatures/finding.json.
static func describe(e: Dictionary) -> Dictionary:
	var sp := str(e.get("species", ""))
	var def := GameCombat.creature_def(sp)
	var species := str(def.get("name", sp)).to_lower()
	var key := "stage_" + (str(e.get("stage")) if GameRanch.STAGES.has(str(e.get("stage"))) else "young")
	var stage := GameRanch.text(key, {"young": str(e.get("young", "")), "species": species})
	var mood := int(e.get("mood", GameRanch.setting("start_mood")))
	var work := GameRanch.work_text(e)
	var grown: bool = str(e.get("stage")) in ["adult", "elder"]
	var capital := stage.substr(0, 1).to_upper() + stage.substr(1)
	var origin: String
	if e.get("bred", false) == true and not e.get("parents", []).is_empty():
		origin = GameBreeding.text("bred_grown" if grown else "bred", {"stage": capital, "species": species, "sex": str(e.get("sex", "")),
				"gen": str(e.get("found_gen", 1)), "mother": str(e["parents"][0]), "father": str(e["parents"][1])})
	else:
		origin = GameFinding.text("entry_grown" if grown else "entry", {
			"stage": capital, "species": species,
			"sex": str(e.get("sex", "")), "by": str(e.get("found_by", "")), "gen": str(e.get("found_gen", 1))})
	var extra: Array = []
	if not e.get("lines", []).is_empty():
		extra.append(GameBreeding.text("cross", {"a": _species_name(str(e["lines"][0])), "b": _species_name(str(e["lines"][1]))}))
	if str(e.get("line", "")) != "":
		extra.append(GameBreeding.text("line", {"line": str(e["line"])}))
	if not e.get("traits", []).is_empty():
		extra.append(GameBreeding.text("traits", {"list": ", ".join(e["traits"].map(func(t): return str(GameBreeding.data()["traits"][t]["name"])))}))
	if e.get("sterile", false) == true:
		extra.append(GameBreeding.text("sterile_note", {}))
	return {
		"name": str(e.get("name", "")), "stage": stage,
		"line": origin
			+ " " + GameRanch.text("age", {"years": GameRanch.years_text(float(e.get("age", 0.0))), "mood": GameRanch.mood_word(mood)})
			+ (" " + work if work != "" else "") + (" " + " ".join(extra) if not extra.is_empty() else ""),
	}
