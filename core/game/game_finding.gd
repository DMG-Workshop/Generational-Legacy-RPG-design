## Finding eggs and young (roadmap item 55). After the dead are searched, each foe that was born
## (an egg-layer or a live-bearer, see GameBirth) may have left young beside it. The roll uses its own
## seeded dice, keyed on the dynasty seed, the hunt count and the foe, so it draws nothing from the
## dynasty's main dice and no life changes. The screens call it (like titles); the rules of a life do not.
## Tuning and text: data/creatures/finding.json.
class_name GameFinding
extends RefCounted

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json("res://data/creatures/finding.json")
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary) -> String:
	return str(data()["text"][key]).format(vals)


## The chance that one dead foe of this species left young, for this heir, at this kind of place.
static func chance(h: GameHeir, species: String, place: String = "search") -> float:
	if GameBirth.born(species) == "none":
		return 0.0
	var c := float(setting("base_chance")) * float(setting("places").get(place, 1.0))
	c *= float(setting("rarity").get(species, 1.0))
	c *= float(setting("class_bonus").get(h.class_id, 1.0))
	for t in h.traits:
		c *= float(setting("trait_bonus").get(str(t), 1.0))
	return clampf(c, 0.0, float(setting("max_chance")))


## What the screens call to search the dead: the search as it always played (GamePlague.search) and then,
## on its own dice, any young left beside them. Returns all the lines.
static func search_dead(d: GameDynasty) -> Array:
	var dead: Array = d.loot.get("foes", [])
	var lines := GamePlague.search(d)
	lines.append_array(after_search(d, dead))
	return lines


## Searching the dead: one roll per foe in `foes` ([{id, name}], from the loot), at most one find.
## Adds the creature to the dynasty's roster and returns the lines to show ([] when nothing is found).
static func after_search(d: GameDynasty, foes: Array, place: String = "search") -> Array:
	if d.state != "life":
		return []
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "find", d.total_hunts, place])
	for f in foes:
		var sp := str(f.get("id", ""))
		var roll := r.randf()   # one die per foe whatever happens, so a foe's roll never depends on the others
		var naming := r.randi()
		if roll >= chance(d.heir, sp, place):
			continue
		var young := GameBirth.young_name(sp)
		var parent := str(f.get("name", sp)).to_lower()
		if GameRoster.full(d):
			var line := text("full", {"parent": parent})
			d._say(line)
			return [line]
		var nr := RandomNumberGenerator.new()
		nr.seed = naming
		var e := GameRoster.add(d, sp, GameInheritance.random_name(nr))
		if e.is_empty():
			continue
		var line2 := text(str(e["born"]), {"parent": parent, "h": d.heir.name, "young": young, "name": e["name"]})
		d._say(line2)
		return [line2]
	return []


static func validate() -> Array:
	var bad: Array = []
	var s: Dictionary = data().get("settings", {})
	for k in ["base_chance", "max_chance", "roster_cap", "places", "rarity", "class_bonus", "trait_bonus"]:
		if not s.has(k):
			bad.append("finding.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if float(s["base_chance"]) < 0.0 or float(s["max_chance"]) > 1.0 or float(s["max_chance"]) < float(s["base_chance"]):
		bad.append("finding.json: chances must be 0 <= base <= max <= 1")
	if int(s["roster_cap"]) < 1:
		bad.append("finding.json: roster_cap must be at least 1")
	for sp in s["rarity"]:
		if GameBirth.born(str(sp)) == "none":
			bad.append("finding.json: rarity for '%s', which is not born" % sp)
		if float(s["rarity"][sp]) < 0.0:
			bad.append("finding.json: rarity for '%s' is negative" % sp)
	for c in s["class_bonus"]:
		if not GameData.classes.has(str(c)):
			bad.append("finding.json: class_bonus names unknown class '%s'" % c)
	for k in ["egg", "live", "full", "kept", "empty", "note", "stage_egg", "stage_young", "entry"]:
		if not data().get("text", {}).has(k):
			bad.append("finding.json: text.%s is missing" % k)
	return bad
