## The creatures the family keeps: eggs and young found beside the dead and raised (roadmap item 55).
## Held on the dynasty as `roster` (only once something is found, so old saves load as before). An
## entry: {id, species, name, sex, stage ("egg" or "young"), born ("egg" or "live"), young (what the
## species calls its young), found_gen, found_by}. Growth, care and the ranch come later (item 56).
class_name GameRoster
extends RefCounted

const STAGES := ["egg", "young"]


static func cap() -> int:
	return int(GameFinding.setting("roster_cap"))


static func full(d: GameDynasty) -> bool:
	return d.roster.size() >= cap()


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
		"young": GameBirth.young_name(species), "found_gen": d.gen, "found_by": d.heir.name,
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
		var stage := str(e.get("stage", ""))
		out.append({
			"id": id, "species": sp, "name": str(e.get("name", "")),
			"sex": str(e.get("sex")) if GameSex.valid(e.get("sex")) else GameSex.roll(0, id),
			"stage": stage if STAGES.has(stage) and (mode == "egg" or stage == "young") else ("egg" if mode == "egg" else "young"),
			"born": mode, "young": GameBirth.young_name(sp),
			"found_gen": int(e.get("found_gen", 1)), "found_by": str(e.get("found_by", "")),
		})
		seen[id] = true
	return out
