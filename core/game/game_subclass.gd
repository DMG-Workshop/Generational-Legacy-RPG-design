## Subclasses (roadmap item 60, first part): a calling layered on an heir's class, none or one, picked when the
## dynasty is founded, taken later for gold, or passed to a child. Perks are multipliers on numbers the rules
## already have (finding young, keeping, breeding, selling creatures); the heir who is "founded" in it (chose it at
## the founding, or was born to it) gets them stronger. Nothing here draws a die from the dynasty: the child's
## inheritance rolls on dice keyed on the seed and the child. Data: data/subclasses/subclasses.json.
class_name GameSubclass
extends RefCounted

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json("res://data/subclasses/subclasses.json")
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


static func defs() -> Array:
	return data()["subclasses"]


static func def(id: String) -> Dictionary:
	for s in defs():
		if str(s["id"]) == id:
			return s
	return {}


static func has(id: String) -> bool:
	return not def(id).is_empty()


static func name_of(id: String) -> String:
	return str(def(id).get("name", id))


## The multiplier this heir's subclass puts on `key`: 1.0 with none, or one that does not name it.
static func perk(h: GameHeir, key: String) -> float:
	if h == null or h.subclass == "":
		return 1.0
	var m := float(def(h.subclass).get("perks", {}).get(key, 1.0))
	var scale := float(setting("founder_scale")) if h.subclass_founded else 1.0
	return maxf(float(setting("perk_floor")), 1.0 + (m - 1.0) * scale)


## What taking or changing to a subclass costs the heir, in gold, scaled as other prices are by the generation.
static func cost(d: GameDynasty, id: String) -> int:
	var base := float(setting("take_cost")) * GameData.enemy_scale(d.gen)
	if d.heir != null and d.heir.subclass != "" and d.heir.subclass != id:
		base *= float(setting("change_cost_mult"))
	return int(round(base))


## Why the heir cannot take this subclass now, or "".
static func why_not(d: GameDynasty, id: String) -> String:
	if d.state != "life" or d.heir == null:
		return text("outside_life")
	if not has(id):
		return "No such subclass."
	if d.heir.subclass == id:
		return text("already", {"name": name_of(id)})
	if d.heir.gold < cost(d, id):
		return text("not_enough", {"gold": GameText.num(cost(d, id))})
	return ""


## The living heir takes up (or changes to) a subclass for gold. Returns the line told, or "" if it could not be done.
## A subclass taken later is not "founded": its perks are at their plain strength.
static func take(d: GameDynasty, id: String) -> String:
	if why_not(d, id) != "":
		return ""
	var gold := cost(d, id)
	var old := d.heir.subclass
	d.heir.gold -= gold
	d.heir.subclass = id
	d.heir.subclass_founded = false
	var line := text("changed" if old != "" else "taken", {"h": d.heir.name, "name": name_of(id), "old": name_of(old), "gold": GameText.num(gold)})
	d._say(line)
	return line


## Founds an heir in a subclass (the dynasty's start): the perks are at the founded strength. "" or an unknown id leaves none.
static func found(h: GameHeir, id: String) -> void:
	if has(id):
		h.subclass = id
		h.subclass_founded = true


## At succession a child may be born to the parent's calling. The roll is keyed on the seed and the child, never
## the dynasty's dice. Returns the line to tell, or "".
static func on_succession(d: GameDynasty, parent: GameHeir, child: GameHeir) -> String:
	if parent.subclass == "" or not has(parent.subclass):
		return ""
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "subclass", child.id])
	if r.randf() >= float(setting("inherit_chance")):
		return ""
	child.subclass = parent.subclass
	child.subclass_founded = true
	var line := text("inherited", {"h": child.name, "name": name_of(parent.subclass), "parent": parent.name})
	d._say(line)
	return line


static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)


## A perk as words: "Finding eggs and young: 40% more" (shown at the strength this heir gets it).
static func perk_lines(h: GameHeir, id: String, founded: bool) -> Array:
	var out: Array = []
	var keys: Array = def(id).get("perks", {}).keys()
	keys.sort()
	for k in keys:
		var m := float(def(id)["perks"][k])
		var scale := float(setting("founder_scale")) if founded else 1.0
		var eff := maxf(float(setting("perk_floor")), 1.0 + (m - 1.0) * scale)
		var pct := int(round(absf(eff - 1.0) * 100.0))
		out.append(text("perk_up" if eff >= 1.0 else "perk_down", {"what": _cap(str(data()["perks"].get(k, k))), "pct": str(pct)}))
	return out


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "perks", "subclasses", "text"]:
		if not dat.has(k):
			bad.append("subclasses.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var s: Dictionary = dat["settings"]
	for k in ["take_cost", "change_cost_mult", "founder_scale", "inherit_chance", "perk_floor"]:
		if not s.has(k):
			bad.append("subclasses.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if float(s["take_cost"]) < 0.0 or float(s["change_cost_mult"]) < 1.0:
		bad.append("subclasses.json: take_cost must be 0 or more and change_cost_mult at least 1")
	if float(s["founder_scale"]) < 1.0:
		bad.append("subclasses.json: founder_scale must be at least 1 (a founded subclass is never weaker)")
	if float(s["inherit_chance"]) < 0.0 or float(s["inherit_chance"]) > 1.0:
		bad.append("subclasses.json: inherit_chance must be between 0 and 1")
	if float(s["perk_floor"]) <= 0.0:
		bad.append("subclasses.json: perk_floor must be above 0")
	var seen := {}
	for sc in dat["subclasses"]:
		var id := str(sc.get("id", ""))
		if id == "" or seen.has(id):
			bad.append("subclasses.json: a subclass has no id or repeats '%s'" % id)
		seen[id] = true
		for k in ["name", "about", "perks"]:
			if not sc.has(k):
				bad.append("subclasses.json: '%s' has no %s" % [id, k])
		if sc.has("perks"):
			if (sc["perks"] as Dictionary).is_empty():
				bad.append("subclasses.json: '%s' has no perks" % id)
			for k in sc["perks"]:
				if not dat["perks"].has(k):
					bad.append("subclasses.json: '%s' has an unknown perk '%s'" % [id, k])
				elif float(sc["perks"][k]) <= 0.0:
					bad.append("subclasses.json: '%s' perk '%s' must be above 0" % [id, k])
	for k in ["none", "current", "how_founded", "how_taken", "perk_up", "perk_down", "take", "change", "have", "taken", "changed", "inherited", "not_enough", "already", "outside_life"]:
		if not dat["text"].has(k):
			bad.append("subclasses.json: text.%s is missing" % k)
	return bad
