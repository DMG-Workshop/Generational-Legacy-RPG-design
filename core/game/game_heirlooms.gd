## Heirloom upgrades across generations (roadmap item 18). An heirloom (GameDynasty.heirlooms, taken from a slain
## legend) can be reworked at a forge once in each heir's life: its `level` rises by one and every level adds power
## for every heir after, so an heirloom grows over generations and remembers who worked it (`smiths`, `worked_gen`).
## The keys are written only once an heirloom has been reworked. Rules and text are in data/items/heirlooms.json.
## No dice; the autopilot reworks nothing.
class_name GameHeirlooms
extends RefCounted

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json("res://data/items/heirlooms.json")
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


static func max_level() -> int:
	return int(setting("max_level"))


## An heirloom's level, 0 (as it was taken) to max_level, whatever was saved.
static func level(h: Variant) -> int:
	if typeof(h) != TYPE_DICTIONARY:
		return 0
	var v: Variant = h.get("level", 0)
	return clampi(int(v), 0, max_level()) if typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)) else 0


static func level_name(lv: int) -> String:
	var names: Array = data()["levels"]
	return str(names[clampi(lv, 0, names.size() - 1)])


## The power one heirloom gives: the base every heirloom gives and its levels.
static func bonus_of(h: Variant) -> float:
	return float(GameData.bal("heirloom_bonus")) + float(level(h)) * float(setting("level_bonus"))


## The power the house's heirlooms give every heir: the first `heirloom_max` of them count.
static func total_bonus(d: GameDynasty) -> float:
	var n := mini(d.heirlooms.size(), int(GameData.bal("heirloom_max")))
	var levels := 0
	for i in n:
		levels += level(d.heirlooms[i])
	# the base exactly as it was always worked out (count times the bonus), so a hall with no levels gives the same number to the last bit
	return float(n) * float(GameData.bal("heirloom_bonus")) + float(levels) * float(setting("level_bonus"))


## What the next level of an heirloom costs this heir, or -1 at the top.
static func cost(d: GameDynasty, index: int) -> int:
	if index < 0 or index >= d.heirlooms.size():
		return -1
	var lv := level(d.heirlooms[index])
	if lv >= max_level():
		return -1
	return maxi(1, int(round(float(setting("cost_base")) * float((lv + 1) * (lv + 1)) * GameData.enemy_scale(d.gen))))


## Why the heir cannot have this heirloom reworked now, or "".
static func why_not(d: GameDynasty, index: int) -> String:
	if index < 0 or index >= d.heirlooms.size() or typeof(d.heirlooms[index]) != TYPE_DICTIONARY:
		return text("none")
	if d.heir == null or d.state != "life":
		return text("not_alive")
	var h: Dictionary = d.heirlooms[index]
	if level(h) >= max_level():
		return text("max", {"name": str(h.get("name", ""))})
	if level(h) > 0 and typeof(h.get("worked_gen")) in [TYPE_INT, TYPE_FLOAT] and int(h["worked_gen"]) == d.gen:
		return text("this_heir", {"name": str(h.get("name", "")), "heir": d.heir.name})
	if not d.world.has_service(str(setting("needs_service"))):
		return text("service")
	if d.heir.gold < cost(d, index):
		return text("gold", {"need": GameText.num(cost(d, index))})
	return ""


## The heir has an heirloom reworked. Returns {ok, text}.
static func upgrade(d: GameDynasty, index: int) -> Dictionary:
	var why := why_not(d, index)
	if why != "":
		return {"ok": false, "text": why}
	var h: Dictionary = d.heirlooms[index]
	d.heir.gold -= cost(d, index)
	h["level"] = level(h) + 1
	h["worked_gen"] = d.gen
	var smiths: Array = _names(h.get("smiths"))
	smiths.append(d.heir.name)
	h["smiths"] = smiths
	d.heir.heirloom_bonus = d.heirloom_bonus()
	var line := text("done", {"heir": d.heir.name, "name": str(h.get("name", "")), "level": level_name(level(h)), "bonus": _pct(bonus_of(h))})
	d._say(line)
	return {"ok": true, "text": line}


static func _pct(v: float) -> String:
	return str(int(round(v * 100.0)))


## What a screen says of an heirloom: {name, level, level_name, line, worked, cost, why_not}.
static func describe(d: GameDynasty, index: int) -> Dictionary:
	if index < 0 or index >= d.heirlooms.size() or typeof(d.heirlooms[index]) != TYPE_DICTIONARY:
		return {}
	var h: Dictionary = d.heirlooms[index]
	var lv := level(h)
	var smiths := _names(h.get("smiths"))
	return {
		"name": str(h.get("name", "")), "level": lv, "level_name": level_name(lv),
		"line": text("line", {"name": str(h.get("name", "")), "level": level_name(lv), "bonus": _pct(bonus_of(h)),
			"boss": str(h.get("boss", "")), "gen": GameText.num(int(h.get("gen", 1)))}),
		"worked": text("worked", {"smiths": ", ".join(smiths)}) if not smiths.is_empty() else "",
		"cost": cost(d, index), "why_not": why_not(d, index),
	}


## A saved list of heirlooms with what this system adds made safe: a level within bounds (dropped at 0), the
## generation it was last worked in and the names of who worked it (no more than its level). The rest of each
## entry is left as it was. An entry that is not a dictionary is left alone, as loading always has.
static func load_list(v: Variant) -> Array:
	var out: Array = []
	if typeof(v) != TYPE_ARRAY:
		return out
	for h in v:
		if typeof(h) != TYPE_DICTIONARY:
			out.append(h)
			continue
		var e: Dictionary = h.duplicate()
		var lv := level(e)
		for k in ["level", "worked_gen", "smiths"]:
			e.erase(k)
		if lv > 0:
			e["level"] = lv
			var g: Variant = h.get("worked_gen")
			e["worked_gen"] = maxi(1, int(g)) if typeof(g) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(g)) else 1
			var smiths := _names(h.get("smiths")).slice(0, lv)
			if not smiths.is_empty():
				e["smiths"] = smiths
		out.append(e)
	return out


static func _names(v: Variant) -> Array:
	var out: Array = []
	if typeof(v) == TYPE_ARRAY:
		for n in v:
			if typeof(n) == TYPE_STRING:
				out.append(n)
	return out


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "text"]:
		if typeof(dat.get(k)) != TYPE_DICTIONARY:
			bad.append("heirlooms.json has no '%s'" % k)
	if typeof(dat.get("levels")) != TYPE_ARRAY:
		bad.append("heirlooms.json has no 'levels'")
	if not bad.is_empty():
		return bad
	if max_level() < 1:
		bad.append("heirlooms: max_level must be at least 1")
	if (dat["levels"] as Array).size() != max_level() + 1:
		bad.append("heirlooms: there must be a name for each level, 0 to max_level (%d names for %d levels)" % [(dat["levels"] as Array).size(), max_level() + 1])
	for n in dat["levels"]:
		if str(n).strip_edges() == "":
			bad.append("heirlooms: a level has no name")
	if float(setting("level_bonus")) <= 0.0:
		bad.append("heirlooms: a level must add power (level_bonus)")
	if float(setting("cost_base")) <= 0.0:
		bad.append("heirlooms: reworking must cost gold (cost_base)")
	var svc := str(setting("needs_service"))
	if not GameData.world["locations"].any(func(l): return svc in l.get("services", [])):
		bad.append("heirlooms: no place has the service '%s'" % svc)
	var top := float(int(GameData.bal("heirloom_max"))) * (float(GameData.bal("heirloom_bonus")) + float(max_level()) * float(setting("level_bonus")))
	if top > 1.0:
		bad.append("heirlooms: a full hall of finished heirlooms would more than double an heir's power (%.2f)" % top)
	for k in ["none", "not_alive", "max", "this_heir", "service", "gold", "done", "line", "worked"]:
		if str(dat["text"].get(k, "")) == "":
			bad.append("heirlooms: the text '%s' is missing" % k)
	return bad
