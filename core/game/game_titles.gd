## Titles: names and honours the heir or the house earns (data/titles/titles.json), worn one at a time after the
## heir's name ("Tess Holloway, the Untouched"). A title is earned when its condition holds of the dynasty's own state,
## so an old save earns the titles it already deserves and nothing here keeps a counter of its own. Only the ids
## earned are saved (`GameHeir.titles` for a personal title, `GameDynasty.house_titles` for a house title, and the
## one worn in `GameHeir.title_worn`), each only once there is something to save.
##
## Earning is asked for by the screens (GameApp.show_state calls `update`), never by the rules of a life, so the
## autopilot and the golden scenarios, which play without a screen, earn nothing and their results do not move.
## Nothing here draws a die. A personal title ends with its heir (their record in the chronicle keeps it); a house
## title stays with the dynasty. A worn title may carry a small perk (`perk`), which is nothing when none is worn.
## Logic only (no UI).
class_name GameTitles
extends RefCounted

## What a condition may count, by the names the data uses.
const STATS := ["level", "battles_won", "kills", "gold", "children", "clean_streak", "age", "age_share", "party", "gen",
	"age_number", "bosses_slain", "house_hall", "house_yard", "world_year", "feats", "spells", "heirlooms"]
const KINDS := ["personal", "house"]
## The condition keys that name one test, besides the combinators all, any and not.
const TESTS := ["stat", "boss", "boss_by_heir", "flag", "trait", "class", "race", "family"]


static func defs() -> Array:
	GameData.load_all()
	return GameData.titles.get("titles", [])


static func def(id: String) -> Dictionary:
	for t in defs():
		if str(t["id"]) == id:
			return t
	return {}


static func known(id: Variant) -> bool:
	return typeof(id) == TYPE_STRING and not def(str(id)).is_empty()


## `v` (from a save, so anything) cleaned to the known title ids, once each, in order.
static func clean_ids(v: Variant) -> Array:
	var out: Array = []
	if typeof(v) != TYPE_ARRAY:
		return out
	for id in v:
		if known(id) and str(id) not in out:
			out.append(str(id))
	return out


# ---------------------------------------------------------------- the conditions

## One number about the dynasty, by a name in STATS. 0 for a name it does not know.
static func stat(d: GameDynasty, key: String) -> float:
	var h := d.heir
	match key:
		"level":
			return float(h.level)
		"battles_won":
			return float(h.battles_won)
		"kills":
			var n := 0
			for k in h.kills:
				n += int(h.kills[k])
			return float(n)
		"gold":
			return float(h.gold)
		"children":
			return float(h.children.size())
		"clean_streak":
			return float(h.clean_streak)
		"age":
			return h.age
		"age_share":
			return h.age / maxf(1.0, h.lifespan)
		"party":
			return float(d.party.members.size())
		"gen":
			return float(d.gen)
		"age_number":
			return float(d.age_number())
		"bosses_slain":
			return float(d.slain_bosses.size())
		"house_hall":
			return float(GameHouse.level(d, GameHouse.HALL))
		"house_yard":
			return float(GameHouse.level(d, GameHouse.YARD))
		"world_year":
			return d.world.year
		"feats":
			return float(h.known_feats.size())
		"spells":
			return float(h.spells.size())
		"heirlooms":
			return float(d.heirlooms.size())
	return 0.0


## Whether `cond` holds of the dynasty. A list means all of its conditions; an unknown or malformed one is false.
static func met(d: GameDynasty, cond: Variant) -> bool:
	if typeof(cond) == TYPE_ARRAY:
		for c in cond:
			if not met(d, c):
				return false
		return true
	if typeof(cond) != TYPE_DICTIONARY:
		return false
	var c: Dictionary = cond
	if c.has("all"):
		return met(d, c["all"])
	if c.has("any"):
		if typeof(c["any"]) != TYPE_ARRAY:
			return false
		for x in c["any"]:
			if met(d, x):
				return true
		return false
	if c.has("not"):
		return not met(d, c["not"])
	if c.has("stat"):
		var v := stat(d, str(c["stat"]))
		if c.has("gte") and v < float(c["gte"]):
			return false
		if c.has("lte") and v > float(c["lte"]):
			return false
		return c.has("gte") or c.has("lte")
	if c.has("boss"):
		return d.slain_bosses.has(str(c["boss"]))
	if c.has("boss_by_heir"):
		return d.slain_bosses.has(str(c["boss_by_heir"])) and int(d.slain_bosses[str(c["boss_by_heir"])]) == d.gen
	if c.has("flag"):
		return d.flags.has(str(c["flag"]))
	if c.has("trait"):
		return str(c["trait"]) in d.heir.traits
	if c.has("class"):
		return d.heir.class_id == str(c["class"])
	if c.has("race"):
		return d.heir.race_id == str(c["race"])
	if c.has("family"):
		return d.heir.family_founded == bool(c["family"])
	return false


# ---------------------------------------------------------------- earning and wearing

## Every title the heir may wear now: the house's and their own, house first, in the data's order.
static func earned(d: GameDynasty) -> Array:
	var out: Array = []
	for t in defs():
		var id := str(t["id"])
		if id in d.house_titles or id in d.heir.titles:
			out.append(id)
	return out


## Awards every title whose condition now holds and which is not yet held, and returns the ids newly earned (in the
## data's order). A living heir only: a dead one earns nothing. Draws no die.
static func update(d: GameDynasty) -> Array:
	var fresh: Array = []
	if d == null or d.heir == null or d.state != "life":
		return fresh
	for t in defs():
		var id := str(t["id"])
		if id in d.house_titles or id in d.heir.titles:
			continue
		if not met(d, t.get("when", {})):
			continue
		if str(t.get("kind", "personal")) == "house":
			d.house_titles.append(id)
		else:
			d.heir.titles.append(id)
		fresh.append(id)
	return fresh


## Awards what is due and tells each new title in the journal. Returns the ids newly earned.
static func announce(d: GameDynasty) -> Array:
	var fresh := update(d)
	for id in fresh:
		d._say("%s earns a title: %s." % [d.heir.name, str(def(id)["name"])])
	return fresh


## The title the heir wears, or "" when none (or when the one saved is no longer theirs to wear).
static func worn(d: GameDynasty) -> String:
	var id := d.heir.title_worn
	return id if id != "" and id in earned(d) else ""


## Wears an earned title. False (and nothing changes) for one not earned.
static func wear(d: GameDynasty, id: String) -> bool:
	if id not in earned(d):
		return false
	d.heir.title_worn = id
	return true


static func unwear(d: GameDynasty) -> void:
	d.heir.title_worn = ""


## The heir's name with the title they wear: "Tess Holloway, the Untouched".
static func display_name(d: GameDynasty) -> String:
	var id := worn(d)
	return d.heir.full_name() if id == "" else "%s, %s" % [d.heir.full_name(), str(def(id)["name"])]


## What the worn title gives toward `key` (a name in data `perk_keys`): 0 when none is worn or it gives none.
static func perk(d: GameDynasty, key: String) -> float:
	var id := worn(d)
	if id == "":
		return 0.0
	var p = def(id).get("perk", {})
	return float(p.get(key, 0.0)) if typeof(p) == TYPE_DICTIONARY else 0.0


## "persuasion +1%" for a perk, "" when there is none.
static func perk_text(t: Dictionary) -> String:
	var p = t.get("perk", {})
	if typeof(p) != TYPE_DICTIONARY or p.is_empty():
		return ""
	var parts: Array = []
	for k in p:
		parts.append("%s %s%d%%" % ["cheaper shops" if k == "persuasion" else str(k), "+" if float(p[k]) >= 0.0 else "", int(round(float(p[k]) * 100.0))])
	return ", ".join(parts)


# ---------------------------------------------------------------- the data

## Problems with data/titles/titles.json, one readable line each; [] when it is sound.
static func validate() -> Array:
	var out: Array = []
	var list: Array = defs()
	if list.is_empty():
		return ["titles: the list is empty or unreadable"]
	var perk_keys: Array = GameData.titles.get("settings", {}).get("perk_keys", [])
	var seen := {}
	var personal := 0
	var house := 0
	for t in list:
		if typeof(t) != TYPE_DICTIONARY:
			out.append("titles: an entry is not a dictionary")
			continue
		var id := str(t.get("id", ""))
		if id == "" or seen.has(id):
			out.append("titles: '%s' is missing an id or is listed twice" % id)
		seen[id] = true
		for k in ["name", "about"]:
			if str(t.get(k, "")).strip_edges() == "":
				out.append("title %s: needs %s" % [id, k])
		if str(t.get("kind", "")) not in KINDS:
			out.append("title %s: kind must be one of %s" % [id, ", ".join(KINDS)])
		elif str(t["kind"]) == "house":
			house += 1
		else:
			personal += 1
		out.append_array(_cond_problems("title " + id, t.get("when", null)))
		var p = t.get("perk", {})
		if typeof(p) != TYPE_DICTIONARY:
			out.append("title %s: perk must be a dictionary" % id)
		else:
			for k in p:
				if str(k) not in perk_keys:
					out.append("title %s: perk '%s' is not one the game gives" % [id, k])
				elif typeof(p[k]) != TYPE_FLOAT and typeof(p[k]) != TYPE_INT:
					out.append("title %s: perk '%s' must be a number" % [id, k])
	if personal == 0 or house == 0:
		out.append("titles: there should be both personal and house titles")
	return out


## Problems in one condition: only known tests, numbers where numbers go, ids that exist in the game's data.
static func _cond_problems(where: String, cond: Variant) -> Array:
	var out: Array = []
	if typeof(cond) == TYPE_ARRAY:
		if (cond as Array).is_empty():
			out.append("%s: an empty list of conditions" % where)
		for c in cond:
			out.append_array(_cond_problems(where, c))
		return out
	if typeof(cond) != TYPE_DICTIONARY or (cond as Dictionary).is_empty():
		return ["%s: a condition must be a dictionary or a list" % where]
	var c: Dictionary = cond
	var tests: Array = ["all", "any", "not"] + TESTS
	var named := c.keys().filter(func(k): return str(k) in tests)
	if named.size() != 1:
		return ["%s: a condition names exactly one test (%s), this has %s" % [where, ", ".join(tests), str(c.keys())]]
	var k: String = named[0]
	match k:
		"all", "any":
			if typeof(c[k]) != TYPE_ARRAY:
				return ["%s: '%s' takes a list" % [where, k]]
			for x in c[k]:
				out.append_array(_cond_problems(where, x))
		"not":
			out.append_array(_cond_problems(where, c[k]))
		"stat":
			if str(c[k]) not in STATS:
				out.append("%s: '%s' is not something titles count (%s)" % [where, c[k], ", ".join(STATS)])
			if not c.has("gte") and not c.has("lte"):
				out.append("%s: a stat condition needs gte or lte" % where)
			for b in ["gte", "lte"]:
				if c.has(b) and typeof(c[b]) != TYPE_FLOAT and typeof(c[b]) != TYPE_INT:
					out.append("%s: %s must be a number" % [where, b])
		"boss", "boss_by_heir":
			var boss := GameData.creatures.filter(func(cr): return str(cr["id"]) == str(c[k]) and cr.get("boss", false))
			if boss.is_empty():
				out.append("%s: '%s' is not a legend (boss) in the creatures" % [where, c[k]])
		"flag":
			if str(c[k]).strip_edges() == "":
				out.append("%s: a flag needs a name" % where)
		"trait":
			if not GameData.traits.has(str(c[k])):
				out.append("%s: no trait called '%s'" % [where, c[k]])
		"class":
			if not GameData.classes.has(str(c[k])):
				out.append("%s: no class called '%s'" % [where, c[k]])
		"race":
			if not GameData.races.has(str(c[k])):
				out.append("%s: no race called '%s'" % [where, c[k]])
		"family":
			if typeof(c[k]) != TYPE_BOOL:
				out.append("%s: 'family' is true or false" % where)
	return out
