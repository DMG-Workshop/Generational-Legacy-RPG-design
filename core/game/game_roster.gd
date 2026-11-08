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
		var age: float = float(e["age"]) if typeof(e.get("age")) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(e["age"])) else 0.0
		var mood: int = int(e["mood"]) if typeof(e.get("mood")) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(e["mood"])) else int(GameRanch.setting("start_mood"))
		var entry := {
			"id": id, "species": sp, "name": str(e.get("name", "")),
			"sex": str(e.get("sex")) if GameSex.valid(e.get("sex")) else GameSex.roll(0, id),
			"born": mode, "young": GameBirth.young_name(sp),
			"age": maxf(0.0, age), "mood": clampi(mood, 1, int(GameRanch.setting("mood_max"))),
			"found_gen": int(e.get("found_gen", 1)), "found_by": str(e.get("found_by", "")),
		}
		entry["stage"] = GameRanch.stage_at(entry, entry["age"])   # the stage follows the age, whatever was saved
		out.append(entry)
		seen[id] = true
	return out


## What a kept creature is called on a screen: {name, stage, line}. The name and the stage are the title, the
## line says what it is and who found it. Text is in data/creatures/finding.json.
static func describe(e: Dictionary) -> Dictionary:
	var sp := str(e.get("species", ""))
	var def := GameCombat.creature_def(sp)
	var species := str(def.get("name", sp)).to_lower()
	var key := "stage_" + (str(e.get("stage")) if GameRanch.STAGES.has(str(e.get("stage"))) else "young")
	var stage := GameRanch.text(key, {"young": str(e.get("young", "")), "species": species})
	var mood := int(e.get("mood", GameRanch.setting("start_mood")))
	return {
		"name": str(e.get("name", "")), "stage": stage,
		"line": GameFinding.text("entry_grown" if str(e.get("stage")) in ["adult", "elder"] else "entry", {
			"stage": stage.substr(0, 1).to_upper() + stage.substr(1), "species": species,
			"sex": str(e.get("sex", "")), "by": str(e.get("found_by", "")), "gen": str(e.get("found_gen", 1))})
			+ " " + GameRanch.text("age", {"years": GameRanch.years_text(float(e.get("age", 0.0))), "mood": GameRanch.mood_word(mood)}),
	}
