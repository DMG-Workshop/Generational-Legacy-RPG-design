## How creatures are born, and how the young of a pairing are born (data/creatures/breeding.json and the `born` and
## `young` of each creature in creatures.json). A creature lays eggs ("egg"), bears live young ("live"), or is not
## born at all ("none": the undead, constructs, fiends and the people-like foes, which are never found young and
## never bred). Two creatures of one kind are born as their kind is. When they differ:
##   - a **hybrid recipe** (a pairing the game defines) says for itself how its young are born, whatever the parents;
##   - any other pairing of kin species, a **cross-breed**, follows `mixed_birth_rule`: by default the mother's way
##     (the mother lays, or the mother bears), and the young are named for the parent whose way they follow.
## Pure functions of the data: no dice, no state, so nothing here moves a life or a fight. The caller says which
## parent is the mother. Logic only (no UI).
class_name GameBirth
extends RefCounted

const MODES := ["egg", "live", "none"]
const RULES := ["mother", "father", "egg", "live"]


static func _creature(id: String) -> Dictionary:
	GameData.load_all()
	for c in GameData.creatures:
		if str(c["id"]) == id:
			return c
	return {}


## How a creature is born: "egg", "live", or "none" (also for an id that is no creature).
static func born(id: String) -> String:
	var m := str(_creature(id).get("born", "none"))
	return m if m in MODES else "none"


## What a creature's young are called ("" for one that is not born).
static func young_name(id: String) -> String:
	return str(_creature(id).get("young", "")) if born(id) != "none" else ""


## Whether a creature can be found young and bred at all.
static func can_breed(id: String) -> bool:
	return born(id) != "none"


## The rule for pairings of different ways of being born, one of RULES ("mother" when the data names none).
static func rule() -> String:
	GameData.load_all()
	var r := str(GameData.breeding.get("settings", {}).get("mixed_birth_rule", "mother"))
	return r if r in RULES else "mother"


## The recipe for a pairing of two creatures (in either order), or {} when the game defines none.
static func recipe_for(a: String, b: String) -> Dictionary:
	GameData.load_all()
	for r in GameData.breeding.get("recipes", []):
		var p: Array = r.get("parents", [])
		if p.size() == 2 and ((str(p[0]) == a and str(p[1]) == b) or (str(p[0]) == b and str(p[1]) == a)):
			return r
	return {}


## What kind of pairing two creatures make: "" when they cannot have young (one is not born), "pure" for two of
## one species, "hybrid" when the game has a recipe for them, else "cross" (a cross-breed).
static func kind(a: String, b: String) -> String:
	if not can_breed(a) or not can_breed(b):
		return ""
	if a == b:
		return "pure"
	return "hybrid" if not recipe_for(a, b).is_empty() else "cross"


## How the young of `mother` and `father` are born: "egg" or "live", or "" when they cannot have young.
static func mode(mother: String, father: String) -> String:
	var k := kind(mother, father)
	if k == "":
		return ""
	if k == "hybrid":
		var m := str(recipe_for(mother, father).get("born", ""))
		return m if m in ["egg", "live"] else born(mother)
	var bm := born(mother)
	var bf := born(father)
	if bm == bf:
		return bm
	match rule():
		"father":
			return bf
		"egg":
			return "egg"
		"live":
			return "live"
	return bm


## What the young are called: the recipe's name for a hybrid, else the name the young of the parent whose way of
## being born they follow go by (the mother's when both do).
static func young_of(mother: String, father: String) -> String:
	var m := mode(mother, father)
	if m == "":
		return ""
	var r := recipe_for(mother, father)
	if not r.is_empty() and str(r.get("young", "")) != "":
		return str(r["young"])
	if born(mother) == m:
		return young_name(mother)
	return young_name(father)


## Problems with the data, one readable line each; [] when it is sound.
static func validate() -> Array:
	GameData.load_all()
	var out: Array = []
	var modes := {}
	for c in GameData.creatures:
		var id := str(c["id"])
		var b := str(c.get("born", ""))
		if b not in MODES:
			out.append("creature %s: born must be one of %s (it is '%s')" % [id, ", ".join(MODES), b])
			continue
		modes[b] = int(modes.get(b, 0)) + 1
		if b == "none" and c.has("young"):
			out.append("creature %s: a creature that is not born has no young" % id)
		if b != "none" and str(c.get("young", "")).strip_edges() == "":
			out.append("creature %s: needs the name of its young" % id)
	if int(modes.get("egg", 0)) == 0 or int(modes.get("live", 0)) == 0:
		out.append("creatures: there must be some that lay eggs and some that bear live young")
	var settings: Dictionary = GameData.breeding.get("settings", {})
	if str(settings.get("mixed_birth_rule", "")) not in RULES:
		out.append("breeding: mixed_birth_rule must be one of %s" % ", ".join(RULES))
	var seen := {}
	for r in GameData.breeding.get("recipes", []):
		var id := str(r.get("id", ""))
		if id == "" or str(r.get("name", "")) == "":
			out.append("recipe '%s': needs an id and a name" % id)
		var p: Array = r.get("parents", [])
		if p.size() != 2:
			out.append("recipe %s: needs exactly two parents" % id)
			continue
		for pid in p:
			if _creature(str(pid)).is_empty():
				out.append("recipe %s: no creature called '%s'" % [id, pid])
			elif not can_breed(str(pid)):
				out.append("recipe %s: '%s' is not born and cannot be a parent" % [id, pid])
		if str(p[0]) == str(p[1]):
			out.append("recipe %s: a hybrid needs two different species" % id)
		var key := "|".join([str(p[0]), str(p[1])] if str(p[0]) < str(p[1]) else [str(p[1]), str(p[0])])
		if seen.has(key):
			out.append("recipe %s: the pairing %s is already a recipe" % [id, key])
		seen[key] = true
		if str(r.get("born", "")) not in ["egg", "live"]:
			out.append("recipe %s: born must be egg or live" % id)
		if str(r.get("young", "")).strip_edges() == "":
			out.append("recipe %s: needs the name of its young" % id)
	return out
