## Creatures of the realms (roadmap item 58, first part). Every creature belongs to a realm
## (data/creatures/realms.json `of`; unlisted means the home realm), and a creature of another realm sells for more
## at home. The rest is written and tested but switched off (`settings.linked`) until the worlds are joined: taking
## a kept creature to another realm, where it is unsettled until it has adapted; and young of two realms, which
## carry both and take a mark from each world. A mark changes the numbers a trait changes; an unstable realm's mark
## is awake or dormant by the year, on dice keyed on the dynasty seed, the year, the creature and the mark (never
## the dynasty's). Roster entries gain `realms`, `marks`, `dormant`, `in_realm`, `adapt` and `settled`, each only
## when it says something, so a ranch that never crosses worlds saves exactly what it did.
class_name GameRealms
extends RefCounted

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json("res://data/creatures/realms.json")
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


static func ids() -> Array:
	var out: Array = data()["realms"].keys()
	out.sort()
	return out


static func has(id: String) -> bool:
	return data()["realms"].has(id)


static func realm(id: String) -> Dictionary:
	return data()["realms"].get(id, {})


static func name_of(id: String) -> String:
	return str(realm(id).get("name", id))


static func home() -> String:
	return str(setting("home"))


## Whether the worlds are joined, so creatures can cross and be crossed. Off until there are gates.
static func linked() -> bool:
	return typeof(setting("linked")) == TYPE_BOOL and setting("linked")


## The realm a species belongs to.
static func of(species: String) -> String:
	return str(data()["of"].get(species, home()))


## The realms a kept creature belongs to: its species' realm, or the two it was born of.
static func of_entry(e: Dictionary) -> Array:
	var two := _realm_pair(e.get("realms"))
	return two if not two.is_empty() else [of(str(e.get("species", "")))]


## Whether a kept creature is of another world than home (in whole or in half).
static func foreign(e: Dictionary) -> bool:
	for r in of_entry(e):
		if r != home():
			return true
	return false


## The realm a kept creature lives in.
static func where(e: Dictionary) -> String:
	var r := str(e.get("in_realm", ""))
	return r if has(r) else home()


## Whether a creature is at ease where it lives: at home, in a realm of its own, or in one it has adapted to.
static func settled(e: Dictionary) -> bool:
	var r := where(e)
	return r == home() or r in of_entry(e) or r in e.get("settled", [])


## The years it still needs before it is at ease where it lives.
static func adapt_left(e: Dictionary) -> float:
	if settled(e):
		return 0.0
	return maxf(0.0, float(realm(where(e)).get("adapt_years", 0)) - float(e.get("adapt", 0.0)))


## The marks that are doing something now (a dormant one does nothing).
static func awake_marks(e: Dictionary) -> Array:
	var out: Array = []
	for m in e.get("marks", []):
		if m not in e.get("dormant", []):
			out.append(m)
	return out


## Whether a mark flickers: it is the mark of an unstable realm.
static func unstable(mark: String) -> bool:
	for id in data()["realms"]:
		if str(realm(id).get("mark", "")) == mark:
			return not realm(id).get("stable", true)
	return false


## What its worlds do to one of a creature's numbers (1.0 when nothing does): its awake marks, being unsettled
## where it lives, and for `value_mult` being of another world.
static func mult(e: Dictionary, key: String) -> float:
	var m := 1.0
	for mark in awake_marks(e):
		m *= float(data()["marks"].get(str(mark), {}).get(key, 1.0))
	if not settled(e):
		m *= float(data()["unsettled"].get(key, 1.0))
	if key == "value_mult" and foreign(e):
		m *= float(setting("foreign_value_mult"))
	return m


## Why a kept creature cannot be taken to a realm, or "".
static func why_not(d: GameDynasty, id: int, to: String) -> String:
	if not linked():
		return text("not_linked")
	var e := GameRanch.find(d, id)
	if e.is_empty() or d.state != "life":
		return text("no_creature")
	if not has(to):
		return text("no_realm")
	if where(e) == to:
		return text("there", {"name": str(e["name"]), "realm": name_of(to)})
	if str(e.get("stage")) == "egg":
		return text("egg")
	return ""


## Takes a kept creature to a realm. Returns {ok, text}. Time spent adapting to the realm it leaves is lost.
static func move(d: GameDynasty, id: int, to: String) -> Dictionary:
	var why := why_not(d, id, to)
	if why != "":
		return {"ok": false, "text": why}
	var e := GameRanch.find(d, id)
	if to == home():
		e.erase("in_realm")
	else:
		e["in_realm"] = to
	e.erase("adapt")
	var left := adapt_left(e)
	var vals := {"name": str(e["name"]), "realm": name_of(to), "years": GameText.num(int(ceil(left)))}
	var line := text("moved_unsettled" if left > 0.0 else "moved", vals)
	d._say(line)
	return {"ok": true, "text": line}


## What young of these parents carry from their worlds: {realms, marks}. `realms` is empty unless the parents are of
## two different realms (then the mother's first); `marks` are the marks of those two worlds, then any the parents
## hold, the mother's first, no more than `max_marks`. No dice.
static func cross(mother: Dictionary, father: Dictionary) -> Dictionary:
	var mr: Array = of_entry(mother)
	var fr: Array = of_entry(father)
	var realms: Array = []
	for r in mr + fr:
		if r not in realms:
			realms.append(r)
	realms = realms.slice(0, 2)
	if realms.size() < 2:
		return {"realms": [], "marks": _inherited(mother, father, [])}
	var marks: Array = []
	for r in realms:
		var m := str(realm(str(r)).get("mark", ""))
		if m != "" and m not in marks:
			marks.append(m)
	return {"realms": realms, "marks": _inherited(mother, father, marks)}


static func _inherited(mother: Dictionary, father: Dictionary, first: Array) -> Array:
	var marks: Array = first.duplicate()
	for parent in [mother, father]:
		for m in parent.get("marks", []):
			if m not in marks:
				marks.append(m)
	return marks.slice(0, int(setting("max_marks")))


## Young are born: GameBreeding calls this with the new roster entry. Does nothing while the worlds are not linked.
## Returns the lines to tell.
static func on_birth(e: Dictionary, mother: Dictionary, father: Dictionary) -> Array:
	if not linked():
		return []
	var got := cross(mother, father)
	if not (got["realms"] as Array).is_empty():
		e["realms"] = got["realms"]
	if (got["marks"] as Array).is_empty():
		return []
	e["marks"] = got["marks"]
	var names: Array = []
	for m in e["marks"]:
		names.append(str(data()["marks"][m]["name"]))
	return [text("born_marked", {"name": str(e["name"]), "marks": GameMessages.text("life", "list_comma").join(names)})]


## Whether an unstable mark is awake in a year: the same answer for the same seed, year, creature and mark.
static func awake_in(seed_value: int, year: int, id: int, mark: String) -> bool:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, "realm mark", year, id, mark])
	return r.randf() < float(setting("awake_chance"))


## Time passes: a creature living in a realm it has not adapted to adapts, and unstable marks wake or sleep for
## the year the clock is now in. Does nothing (and returns at once) for a roster with neither. `year_now` is the
## world's year (a parameter so a test can set it).
static func on_years(d: GameDynasty, years: float, msgs: Array, year_now: float = -1.0) -> void:
	if years <= 0.0:
		return
	var any := false
	for e in d.roster:
		if e.has("in_realm") or e.has("marks"):
			any = true
			break
	if not any:
		return
	var year := int(floor(year_now if year_now >= 0.0 else float(d.world.year)))
	for e in d.roster:
		if not settled(e):
			e["adapt"] = float(e.get("adapt", 0.0)) + years
			if adapt_left(e) <= 0.0:
				var known: Array = e.get("settled", [])
				known.append(where(e))
				e["settled"] = known
				e.erase("adapt")
				_tell(d, msgs, text("settles", {"name": str(e["name"]), "realm": name_of(where(e))}))
		var dormant: Array = []
		for m in e.get("marks", []):
			if not unstable(str(m)):
				continue
			var was_awake: bool = m not in e.get("dormant", [])
			var awake := awake_in(d.seed_value, year, int(e["id"]), str(m))
			if not awake:
				dormant.append(m)
			if awake != was_awake:
				_tell(d, msgs, text("wakes" if awake else "sleeps", {"name": str(e["name"]), "mark": str(data()["marks"][m]["name"])}))
		if dormant.is_empty():
			e.erase("dormant")
		else:
			e["dormant"] = dormant


static func _tell(d: GameDynasty, msgs: Array, line: String) -> void:
	d._say(line)
	msgs.append(line)


## What a screen says of a creature's worlds: "of the Void", "of the Void and the Material Realm", or "" for a
## creature wholly of home.
static func describe(e: Dictionary) -> String:
	if not foreign(e):
		return ""
	var rs := of_entry(e)
	if rs.size() == 2:
		return text("of_two", {"a": name_of(str(rs[0])), "b": name_of(str(rs[1]))})
	return text("of_realm", {"realm": name_of(str(rs[0]))})


## Copies what a saved roster entry says of its worlds into the cleaned entry: only known realms and marks, only
## real numbers, and nothing that says nothing.
static func load_entry(saved: Dictionary, entry: Dictionary) -> void:
	var two := _realm_pair(saved.get("realms"))
	if not two.is_empty():
		entry["realms"] = two
	var marks := _known(saved.get("marks"), data()["marks"]).slice(0, int(setting("max_marks")))
	if not marks.is_empty():
		entry["marks"] = marks
		var dormant: Array = []
		for m in _known(saved.get("dormant"), data()["marks"]):
			if m in marks and unstable(str(m)):
				dormant.append(m)
		if not dormant.is_empty():
			entry["dormant"] = dormant
	var settled_in: Array = []
	for r in _known(saved.get("settled"), data()["realms"]):
		if r != home():
			settled_in.append(r)
	if not settled_in.is_empty():
		entry["settled"] = settled_in
	var at: Variant = saved.get("in_realm")
	if typeof(at) == TYPE_STRING and has(at) and at != home():
		entry["in_realm"] = at
		var a: Variant = saved.get("adapt")
		if typeof(a) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(a)) and float(a) > 0.0 and not settled(entry):
			entry["adapt"] = float(a)


static func _known(v: Variant, among: Dictionary) -> Array:
	var out: Array = []
	if typeof(v) != TYPE_ARRAY:
		return out
	for x in v:
		if typeof(x) == TYPE_STRING and among.has(x) and x not in out:
			out.append(x)
	return out


## Two different known realms, or [].
static func _realm_pair(v: Variant) -> Array:
	if typeof(v) == TYPE_ARRAY and (v as Array).size() == 2 and typeof(v[0]) == TYPE_STRING and typeof(v[1]) == TYPE_STRING:
		if has(v[0]) and has(v[1]) and v[0] != v[1]:
			return [str(v[0]), str(v[1])]
	return []


const MULT_KEYS := ["value_mult", "mood_loss_mult", "guard_mult", "work_mult", "fertility_mult", "keep_mult"]


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "unsettled", "realms", "of", "marks", "text"]:
		if typeof(dat.get(k)) != TYPE_DICTIONARY:
			bad.append("realms.json has no '%s'" % k)
	if not bad.is_empty():
		return bad
	if not has(home()):
		bad.append("the home realm '%s' is not a realm" % home())
	elif str(realm(home()).get("mark", "")) != "" or float(realm(home()).get("adapt_years", 0)) != 0.0:
		bad.append("the home realm has a mark or needs adapting to")
	if typeof(setting("linked")) != TYPE_BOOL:
		bad.append("settings.linked is not yes or no")
	if float(setting("foreign_value_mult")) < 1.0:
		bad.append("a creature of another realm is worth less than one of home")
	if int(setting("max_marks")) < 2:
		bad.append("young of two worlds cannot hold a mark of each (max_marks under 2)")
	var chance := float(setting("awake_chance"))
	if chance <= 0.0 or chance >= 1.0:
		bad.append("awake_chance must be between 0 and 1, or an unstable mark never changes")
	var mark_used := {}
	for id in dat["realms"]:
		var r: Dictionary = dat["realms"][id]
		for k in ["name", "stable", "adapt_years", "mark"]:
			if not r.has(k):
				bad.append("realm '%s' has no '%s'" % [id, k])
		if typeof(r.get("stable")) != TYPE_BOOL:
			bad.append("realm '%s' does not say whether it is stable" % id)
		var m := str(r.get("mark", ""))
		if id != home():
			if m == "" or not dat["marks"].has(m):
				bad.append("realm '%s' has no mark of its own" % id)
			elif mark_used.has(m):
				bad.append("realms '%s' and '%s' share the mark '%s'" % [mark_used[m], id, m])
			mark_used[m] = id
			if float(r.get("adapt_years", 0)) <= 0.0:
				bad.append("realm '%s' needs no adapting to" % id)
	for m in dat["marks"]:
		if not mark_used.has(m):
			bad.append("the mark '%s' belongs to no realm" % m)
		var def: Dictionary = dat["marks"][m]
		if str(def.get("name", "")) == "" or str(def.get("about", "")) == "":
			bad.append("the mark '%s' has no name or says nothing of itself" % m)
		var does := false
		for k in def:
			if k in ["name", "about"]:
				continue
			if k not in MULT_KEYS:
				bad.append("the mark '%s' changes '%s', which nothing reads" % [m, k])
			elif float(def[k]) <= 0.0:
				bad.append("the mark '%s' has a '%s' that is not above 0" % [m, k])
			else:
				does = true
		if not does:
			bad.append("the mark '%s' does nothing" % m)
	for k in dat["unsettled"]:
		if k not in MULT_KEYS:
			bad.append("being unsettled changes '%s', which nothing reads" % k)
	for sp in dat["of"]:
		if GameCombat.creature_def(str(sp)).is_empty():
			bad.append("'%s' is given a realm but is not a creature" % sp)
		var r := str(dat["of"][sp])
		if not has(r):
			bad.append("'%s' is of '%s', which is not a realm" % [sp, r])
		elif r == home():
			bad.append("'%s' is listed as of home; leave it out" % sp)
		if GameCombat.creature_def(str(sp)).get("farm", false):
			bad.append("the farm animal '%s' is of another realm" % sp)
	return bad
