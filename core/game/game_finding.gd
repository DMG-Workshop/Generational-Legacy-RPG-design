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
	for t in h.all_traits():
		c *= float(setting("trait_bonus").get(str(t), 1.0))
	c *= GameSubclass.perk(h, "find_mult")
	return clampf(c, 0.0, float(setting("max_chance")))


## The house has found young: Explore events that give young become possible (the flag is what they require).
static func _found(d: GameDynasty) -> void:
	d.set_flag(str(setting("found_flag")))


## Takes in a creature of one of `species` (an event's outcome: the choice's own check was the roll). The pick of
## species and the name are keyed on the dynasty seed, the generation and the event, never the dynasty's dice.
## Returns the lines to tell: the creature, or that there is nowhere to keep it.
static func take(d: GameDynasty, species: Array, key: String) -> Array:
	if d.state != "life" or species.is_empty():
		return []
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "take", d.gen, key, d.roster.size()])
	var sp := str(species[r.randi() % species.size()])
	var nr := RandomNumberGenerator.new()
	nr.seed = r.randi()
	if GameRoster.full(d):
		var full := text("found_full", {})
		d._say(full)
		return [full]
	var e := GameRoster.add(d, sp, GameInheritance.random_name(nr))
	if e.is_empty():
		return []
	_found(d)
	var def := GameCombat.creature_def(sp)
	var line := text("found_" + str(e["born"]), {"h": d.heir.name, "young": e["young"], "species": str(def.get("name", sp)).to_lower(), "name": e["name"]})
	d._say(line)
	return [line]


## A won fight: a slain legend that is born may have left its young beside it. Once per legend (a flag), on its own
## dice keyed on the seed and the legend. Returns the lines to tell. The screens call it; the rules of a life do not.
static func after_battle(d: GameDynasty, result: String, enemies: Array) -> Array:
	var out: Array = []
	if d.state != "life" or result != "victory":
		return out
	for e in enemies:
		var id := str(e.get("id", ""))
		var flag := "legend_clutch_" + id
		if not e.get("boss", false) or GameBirth.born(id) == "none" or d.flags.has(flag) or int(d.slain_bosses.get(id, -1)) != d.gen:
			continue
		d.set_flag(flag)
		var r := RandomNumberGenerator.new()
		r.seed = hash([d.seed_value, "legend", id])
		if r.randf() >= chance(d.heir, id, "legend"):
			continue
		if GameRoster.full(d):
			var full := text("full", {"parent": str(e.get("name", id)).to_lower()})
			d._say(full)
			out.append(full)
			continue
		var nr := RandomNumberGenerator.new()
		nr.seed = r.randi()
		var made := GameRoster.add(d, id, GameInheritance.random_name(nr))
		if made.is_empty():
			continue
		_found(d)
		var line := text("legend_" + str(made["born"]), {"parent": str(e.get("name", id)).to_lower(), "h": d.heir.name, "young": made["young"], "name": made["name"]})
		d._say(line)
		out.append(line)
	return out


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
		_found(d)
		var line2 := text(str(e["born"]), {"parent": parent, "h": d.heir.name, "young": young, "name": e["name"]})
		d._say(line2)
		return [line2]
	return []


static func validate() -> Array:
	var bad: Array = []
	var s: Dictionary = data().get("settings", {})
	for k in ["base_chance", "max_chance", "roster_cap", "places", "rarity", "class_bonus", "trait_bonus", "found_flag"]:
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
	for t in s["trait_bonus"]:
		if not GameData.traits.has(str(t)):
			bad.append("finding.json: trait_bonus names unknown trait '%s'" % t)
		elif float(s["trait_bonus"][t]) < 0.0:
			bad.append("finding.json: trait_bonus for '%s' is negative" % t)
	if typeof(s["places"]) != TYPE_DICTIONARY or not s["places"].has("legend") or not s["places"].has("search"):
		bad.append("finding.json: places needs search and legend")
	for c in s["class_bonus"]:
		if not GameData.classes.has(str(c)):
			bad.append("finding.json: class_bonus names unknown class '%s'" % c)
	for k in ["egg", "live", "full", "kept", "empty", "note", "stage_egg", "stage_young", "entry", "entry_grown", "found_egg", "found_live", "legend_egg", "legend_live", "found_full"]:
		if not data().get("text", {}).has(k):
			bad.append("finding.json: text.%s is missing" % k)
	return bad
