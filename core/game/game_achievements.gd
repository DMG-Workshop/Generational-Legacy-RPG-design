## Achievements and dynasty milestones (roadmap item 16). A milestone is a count about the whole dynasty reaching a
## goal (data/achievements/achievements.json); once reached it is kept on the dynasty for good, with the generation,
## the year and the heir. A milestone can award a house title: GameTitles has the condition `{achievement: id}`.
## Reaching is asked for by the screens (through GameTitles.announce), never by the rules of a life, so the autopilot
## and the golden scenarios reach nothing and no die is drawn.
class_name GameAchievements
extends RefCounted

## What a milestone can count. Each is a number about the dynasty as a whole.
const COUNTS := ["generations", "years", "ages", "legends", "legend_kills", "heirs", "house", "creatures", "bred",
	"crafted", "built", "heirlooms", "titles", "gold", "milestones"]
## Where a goal can be taken from the game instead of written down.
const GOALS_FROM := ["house_max"]

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json("res://data/achievements/achievements.json")
	return _cache


static func defs() -> Array:
	return data().get("achievements", [])


static func def(id: String) -> Dictionary:
	for a in defs():
		if str(a["id"]) == id:
			return a
	return {}


static func known(id: Variant) -> bool:
	return typeof(id) == TYPE_STRING and not def(str(id)).is_empty()


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


## One count about the dynasty, by a name in COUNTS. 0 for a name it does not know.
static func count(d: GameDynasty, key: String) -> float:
	match key:
		"generations":
			return float(d.gen)
		"years":
			return d.world.year
		"ages":
			return float(d.age_number())
		"legends":
			return float(d.slain_bosses.size())
		"legend_kills":
			return float(GameStats.summary(d)["legends"])
		"heirs":
			return float(GameStats.summary(d)["heirs"])
		"house":
			var n := 0
			for track in GameHouse.TRACKS:
				n += GameHouse.level(d, track)
			return float(n)
		"creatures":
			return float(d.roster.size())
		"bred":
			return float(d.roster.filter(func(e): return e.get("bred", false)).size())
		"crafted":
			var made: Variant = d.stores.get("crafted", 0)
			return float(made) if typeof(made) in [TYPE_INT, TYPE_FLOAT] else 0.0
		"built":
			return float(d.built.size())
		"heirlooms":
			return float(d.heirlooms.size())
		"titles":
			return float(d.house_titles.size() + (d.heir.titles.size() if d.heir != null else 0))
		"gold":
			return float(d.heir.gold) if d.heir != null else 0.0
		"milestones":
			return float(d.achievements.size())
	return 0.0


## The number a milestone asks for.
static func goal(a: Dictionary) -> float:
	if str(a.get("goal_from", "")) == "house_max":
		return float(GameHouse.max_level() * GameHouse.TRACKS.size())
	return float(a.get("goal", 0))


## How far along a milestone is: {have, goal, share (0 to 1), done}. A reached milestone stays done whatever the count.
static func progress(d: GameDynasty, id: String) -> Dictionary:
	var a := def(id)
	if a.is_empty():
		return {"have": 0.0, "goal": 0.0, "share": 0.0, "done": false}
	var g := goal(a)
	var have := count(d, str(a["count"]))
	var done: bool = d.achievements.has(id)
	return {"have": have, "goal": g, "share": 1.0 if done else clampf(have / maxf(1.0, g), 0.0, 1.0), "done": done}


static func reached(d: GameDynasty, id: String) -> bool:
	return d.achievements.has(id)


## Marks every milestone whose count has reached its goal and which is not yet held, and returns the ids newly
## reached, in the data's order. A living heir only. Draws no die.
static func update(d: GameDynasty) -> Array:
	var fresh: Array = []
	if d == null or d.heir == null or d.state != "life":
		return fresh
	for a in defs():
		var id := str(a["id"])
		if d.achievements.has(id) or count(d, str(a["count"])) < goal(a):
			continue
		d.achievements[id] = {"gen": d.gen, "year": int(floor(d.world.year)), "heir": d.heir.name}
		fresh.append(id)
	return fresh


## Marks what is due and tells each new milestone in the journal. Returns the ids newly reached.
static func announce(d: GameDynasty) -> Array:
	var fresh := update(d)
	for id in fresh:
		d._say(text("reached", {"name": str(def(id)["name"])}))
	return fresh


## What a screen says of one milestone: {name, about, done, line}. `line` is who reached it and when, or how far along.
static func describe(d: GameDynasty, id: String) -> Dictionary:
	var a := def(id)
	var p := progress(d, id)
	var line := ""
	if p["done"]:
		var got: Dictionary = d.achievements[id]
		line = text("when", {"heir": str(got["heir"]), "gen": GameText.num(int(got["gen"])), "year": GameText.num(int(got["year"]))})
	else:
		line = text("progress", {"have": GameText.num(int(minf(p["have"], p["goal"]))), "goal": GameText.num(int(p["goal"]))})
	return {"name": str(a.get("name", id)), "about": str(a.get("about", "")), "done": p["done"], "line": line}


## A saved record of milestones made safe: known ids only, each a generation, a year and a name.
static func load_state(v: Variant) -> Dictionary:
	var out := {}
	if typeof(v) != TYPE_DICTIONARY:
		return out
	for a in defs():   # in the data's order, so a loaded record is ordered as an earned one
		var id := str(a["id"])
		var got: Variant = v.get(id)
		if typeof(got) != TYPE_DICTIONARY:
			continue
		out[id] = {"gen": maxi(1, _int(got.get("gen"), 1)), "year": maxi(0, _int(got.get("year"), 0)),
			"heir": str(got["heir"]) if typeof(got.get("heir")) == TYPE_STRING else ""}
	return out


static func _int(v: Variant, fallback: int) -> int:
	return int(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)) else fallback


static func validate() -> Array:
	var bad: Array = []
	var list: Array = defs()
	if list.is_empty():
		return ["achievements: the list is empty or unreadable"]
	for k in ["reached", "when", "progress"]:
		if str(data().get("text", {}).get(k, "")) == "":
			bad.append("achievements: the text '%s' is missing" % k)
	var seen := {}
	var by_goal := {}
	for a in list:
		if typeof(a) != TYPE_DICTIONARY:
			bad.append("achievements: an entry is not a dictionary")
			continue
		var id := str(a.get("id", ""))
		if id == "" or seen.has(id):
			bad.append("achievements: '%s' is missing an id or is listed twice" % id)
		seen[id] = true
		for k in ["name", "about"]:
			if str(a.get(k, "")).strip_edges() == "":
				bad.append("achievement %s: needs %s" % [id, k])
		var c := str(a.get("count", ""))
		if c not in COUNTS:
			bad.append("achievement %s: '%s' is not something the house counts (%s)" % [id, c, ", ".join(COUNTS)])
		if a.has("goal_from"):
			if str(a["goal_from"]) not in GOALS_FROM:
				bad.append("achievement %s: a goal cannot be taken from '%s'" % [id, a["goal_from"]])
		elif typeof(a.get("goal")) not in [TYPE_INT, TYPE_FLOAT] or float(a["goal"]) <= 0.0:
			bad.append("achievement %s: needs a goal above 0" % id)
		var key := "%s at %s" % [c, str(goal(a))]
		if by_goal.has(key):
			bad.append("achievements %s and %s are the same milestone (%s)" % [by_goal[key], id, key])
		by_goal[key] = id
		if c == "milestones" and goal(a) >= float(list.size()):
			bad.append("achievement %s: asks for more milestones than there are besides itself" % id)
		if a.has("title"):
			var t := GameTitles.def(str(a["title"]))
			if t.is_empty():
				bad.append("achievement %s: awards the title '%s', which does not exist" % [id, a["title"]])
			elif str(t.get("kind")) != "house" or t.get("when", {}) != {"achievement": id}:
				bad.append("achievement %s: the title '%s' must be a house title earned by {achievement: %s}" % [id, a["title"], id])
	for t in GameTitles.defs():
		var w: Variant = t.get("when")
		if typeof(w) == TYPE_DICTIONARY and w.has("achievement") and str(def(str(w["achievement"])).get("title", "")) != str(t["id"]):
			bad.append("title %s: is earned by the milestone '%s', which does not award it" % [t["id"], w["achievement"]])
	return bad
