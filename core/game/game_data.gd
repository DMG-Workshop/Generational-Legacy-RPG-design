## Loads and caches all JSON content for the playable slice. No game logic here.
class_name GameData
extends RefCounted

const TRAIT_FILES := [
	"res://data/traits/bloodline.json",
	"res://data/traits/blessings.json",
	"res://data/traits/curses.json",
	"res://data/traits/acquired.json",
	"res://data/traits/mutations.json",
	"res://data/traits/divine.json",
	"res://data/traits/racial.json",
]

static var _loaded := false
static var traits: Dictionary = {}
static var classes: Dictionary = {}
static var races: Dictionary = {}
static var world: Dictionary = {}
static var creatures: Array = []
static var balance: Dictionary = {}
static var names: Dictionary = {}


static func load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("GameData: cannot open %s" % path)
		return null
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("GameData: invalid JSON in %s" % path)
	return parsed


static func load_all() -> void:
	if _loaded:
		return
	traits.clear()
	for path in TRAIT_FILES:
		var d = load_json(path)
		if d == null:
			continue
		for t in d["traits"]:
			traits[t["id"]] = t
	# Drop mutation/conflict targets that have no definition.
	for id in traits:
		var t: Dictionary = traits[id]
		t["mutations"] = (t.get("mutations", []) as Array).filter(func(m): return traits.has(m))
	classes.clear()
	for c in load_json("res://data/classes/classes.json")["classes"]:
		classes[c["id"]] = c
	races.clear()
	for r in load_json("res://data/races/races.json")["races"]:
		races[r["id"]] = r
	creatures = load_json("res://data/creatures/creatures.json")["creatures"]
	world = load_json("res://data/world/world.json")
	balance = load_json("res://data/game/balance.json")
	names = load_json("res://data/game/names.json")
	_loaded = true


static func bal(key: String) -> Variant:
	load_all()
	return balance[key]


static func trait_def(id: String) -> Dictionary:
	load_all()
	return traits.get(id, {"id": id, "name": id.capitalize(), "description": "", "effects": [], "mutations": [], "conflicts": [], "inherit_chance": 0.3, "dormant_chance": 0.0, "fate_modifier": 0.0, "category": "unknown"})


static func trait_name(id: String) -> String:
	return trait_def(id).get("name", id)


## Traits that may be gifted to spouses / appear spontaneously.
static func traits_in(categories: Array) -> Array:
	load_all()
	var out: Array = []
	for id in traits:
		if traits[id].get("category", "") in categories:
			out.append(id)
	out.sort()
	return out


## Classes / races a founder can pick (hybrids only arise from mixed parents).
static func starting_ids(table: Dictionary) -> Array:
	load_all()
	var out: Array = []
	for id in table:
		if table[id].get("starting", true):
			out.append(id)
	out.sort()
	return out


## The hybrid born from two parents of different kinds, or "" if none is defined.
static func hybrid_of(table: Dictionary, a: String, b: String) -> String:
	if a == b:
		return ""
	for id in table:
		var parents: Array = table[id].get("parents", [])
		if parents.size() == 2 and a in parents and b in parents:
			return id
	return ""


## Monsters spawn at the hunter's level: their stats and XP grow with it.
static func enemy_level_scale(level: int) -> float:
	return 1.0 + float(bal("enemy_growth_per_level")) * float(level - 1)


static func xp_level_scale(level: int) -> float:
	return 1.0 + float(bal("xp_growth_per_level")) * float(level - 1)


static func enemy_scale(gen: int) -> float:
	return 1.0 + float(bal("enemy_scale_per_gen")) * float(gen - 1)


static func heir_scale(gen: int) -> float:
	return 1.0 + float(bal("heir_scale_per_gen")) * float(gen - 1)
