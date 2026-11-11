## Faction reputation (roadmap item 17, first part). NPCs judge the heir by their ancestors: a faction's standing
## with the heir is worked out, never saved, from the heirs the chronicle keeps (their class, level, battles, kills,
## gold, death and titles, fading by the generation), the living heir's own deeds, and what belongs to the whole
## house (echoes, legends slain, milestones). Standing gives a rank; a faction that holds the heir well offers a gift
## once in their life and, at the top, a title (GameTitles' `faction` condition). Rules and text are in
## data/factions/factions.json. No dice; the autopilot takes no gift and nothing in a life reads a standing.
class_name GameFactions
extends RefCounted

const HEIR_RULES := ["class", "level", "battles", "kills", "gold", "cause", "titles"]
const HOUSE_RULES := ["echo", "bosses", "milestones"]

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json("res://data/factions/factions.json")
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


static func ids() -> Array:
	return data()["factions"].keys()


static func has(id: Variant) -> bool:
	return typeof(id) == TYPE_STRING and data()["factions"].has(id)


static func faction(id: String) -> Dictionary:
	return data()["factions"].get(id, {})


static func name_of(id: String) -> String:
	return str(faction(id).get("name", id))


## The heirs a faction can remember, newest first: the living heir (ago 0), then the dead the chronicle keeps in
## full. Each is {ago, class_id, level, battles_won, kills, gold, cause, titles}.
static func remembered(d: GameDynasty) -> Array:
	var out: Array = []
	if d.heir != null and d.state != "dead":
		out.append({"ago": 0, "class_id": d.heir.class_id, "level": d.heir.level, "battles_won": d.heir.battles_won,
			"kills": d.heir.kills, "gold": d.heir.gold, "cause": "", "titles": d.heir.titles.size()})
	for i in range(d.history.size() - 1, -1, -1):
		var r: Dictionary = d.history[i]
		var t: Variant = r.get("titles", [])
		out.append({"ago": maxi(0, d.gen - int(r.get("gen", d.gen))), "class_id": str(r.get("class_id", "")),
			"level": int(r.get("level", 1)), "battles_won": int(r.get("battles_won", 0)),
			"kills": r.get("kills", {}) if typeof(r.get("kills")) == TYPE_DICTIONARY else {},
			"gold": int(r.get("gold", 0)), "cause": str(r.get("cause", "")),
			"titles": (t as Array).size() if typeof(t) == TYPE_ARRAY else 0})
	return out


## What one heir adds by one rule, before fading: the rule's `each` for every time it applies, within its `cap`.
static func heir_points(rule: Dictionary, h: Dictionary) -> float:
	var n := 0.0
	match str(rule.get("what", "")):
		"class":
			n = 1.0 if str(h["class_id"]) in rule.get("classes", []) else 0.0
		"level":
			n = floorf(float(h["level"]) / maxf(1.0, float(rule.get("per", 1))))
		"battles":
			n = floorf(float(h["battles_won"]) / maxf(1.0, float(rule.get("per", 1))))
		"kills":
			var k := 0
			for c in h["kills"]:
				if str(c) in rule.get("creatures", []) or _tagged(str(c), rule.get("tags", [])):
					k += int(h["kills"][c])
			n = floorf(float(k) / maxf(1.0, float(rule.get("per", 1))))
		"gold":
			n = floorf(float(h["gold"]) / maxf(1.0, float(rule.get("per", 1))))
		"cause":
			n = 1.0 if str(h["cause"]) in rule.get("causes", []) else 0.0
		"titles":
			n = float(h["titles"])
	var p := n * float(rule.get("each", 0))
	if rule.has("cap"):
		p = clampf(p, -float(rule["cap"]), float(rule["cap"]))
	return p


static func _tagged(creature: String, tags: Array) -> bool:
	if tags.is_empty():
		return false
	for t in GameCombat.creature_def(creature).get("tags", []):
		if t in tags:
			return true
	return false


## What the whole house adds by one rule.
static func house_points(rule: Dictionary, d: GameDynasty) -> float:
	var n := 0.0
	match str(rule.get("what", "")):
		"echo":
			n = d.echo_total(str(rule.get("kind", "")))
		"bosses":
			for id in rule.get("ids", []):
				if d.slain_bosses.has(str(id)):
					n += 1.0
		"milestones":
			n = float(d.achievements.size())
	var p := n * float(rule.get("each", 0))
	if rule.has("cap"):
		p = clampf(p, -float(rule["cap"]), float(rule["cap"]))
	return p


## Everything a faction weighs, one entry per rule that adds anything: [{points, n, say}], strongest first. `n` is
## how many heirs the rule applied to.
static func reasons(d: GameDynasty, id: String) -> Array:
	var out: Array = []
	var f := faction(id)
	if f.is_empty():
		return out
	var heirs := remembered(d)
	var memory := float(f.get("memory", 1.0))
	for rule in f.get("remembers", []):
		var total := 0.0
		var n := 0
		for h in heirs:
			var p := heir_points(rule, h)
			if p != 0.0:
				total += p * pow(memory, float(h["ago"]))
				n += 1
		if total != 0.0:
			out.append({"points": total, "n": n, "say": str(rule.get("say", "")).format({"n": GameText.num(n)})})
	for rule in f.get("house", []):
		var p := house_points(rule, d)
		if p != 0.0:
			out.append({"points": p, "n": 0, "say": str(rule.get("say", ""))})
	out.sort_custom(func(a, b): return absf(a["points"]) > absf(b["points"]) or (absf(a["points"]) == absf(b["points"]) and str(a["say"]) < str(b["say"])))
	return out


## A faction's standing with the heir, -100 to 100, a whole number.
static func standing(d: GameDynasty, id: String) -> int:
	var total := 0.0
	for r in reasons(d, id):
		total += float(r["points"])
	return clampi(int(round(total)), -100, 100)


## The rank a standing gives: the highest whose `min` it reaches.
static func rank_at(value: int) -> Dictionary:
	var got: Dictionary = data()["ranks"][0]
	for r in data()["ranks"]:
		if value >= int(r["min"]):
			got = r
	return got


static func rank(d: GameDynasty, id: String) -> String:
	return str(rank_at(standing(d, id))["id"])


static func _rank_index(rank_id: String) -> int:
	var list: Array = data()["ranks"]
	for i in list.size():
		if str(list[i]["id"]) == rank_id:
			return i
	return -1


## Whether the faction holds the heir at this rank or better.
static func at_least(d: GameDynasty, id: String, rank_id: String) -> bool:
	return has(id) and _rank_index(rank_id) >= 0 and _rank_index(rank(d, id)) >= _rank_index(rank_id)


## What the faction would give the heir now: {gold, potions, xp} (all 0 below `boon_rank`).
static func gift(d: GameDynasty, id: String) -> Dictionary:
	var out := {"gold": 0, "potions": 0, "xp": 0}
	if not at_least(d, id, str(setting("boon_rank"))) or d.heir == null:
		return out
	var b: Dictionary = faction(id).get("boon", {})
	var mult := float(setting("honoured_mult")) if at_least(d, id, str(setting("top_rank"))) else 1.0
	out["gold"] = int(round(float(b.get("gold", 0)) * mult * GameData.enemy_scale(d.gen)))
	out["potions"] = int(round(float(b.get("potions", 0)) * mult))
	out["xp"] = int(round(float(b.get("xp", 0)) * mult * float(maxi(1, d.heir.level))))
	return out


static func gift_text(g: Dictionary) -> String:
	var parts: Array = []
	for k in ["gold", "potions", "xp"]:
		if int(g.get(k, 0)) > 0:
			parts.append(text("gift_" + k, {k: GameText.num(int(g[k]))}))
	return ", ".join(parts)


## Why the heir cannot take the faction's gift now, or "".
static func why_not(d: GameDynasty, id: String) -> String:
	if not has(id):
		return text("no_faction")
	if d.heir == null or d.state != "life":
		return text("not_alive")
	if id in d.heir.boons:
		return text("taken", {"faction": _cap(name_of(id)), "heir": d.heir.name})
	if not at_least(d, id, str(setting("boon_rank"))):
		return text("low", {"faction": _cap(name_of(id)), "rank": str(rank_at(standing(d, id))["name"]).to_lower()})
	if not d.world.is_town():
		return text("not_town", {"faction": _cap(name_of(id))})
	return ""


## The heir takes the faction's gift, once in their life. Returns {ok, text}.
static func take(d: GameDynasty, id: String) -> Dictionary:
	var why := why_not(d, id)
	if why != "":
		return {"ok": false, "text": why}
	var g := gift(d, id)
	d.heir.gold += int(g["gold"])
	d.heir.potions += int(g["potions"])
	if int(g["xp"]) > 0:
		d.heir.gain_xp(int(g["xp"]))
	d.heir.boons.append(id)
	var line := text("gift", {"faction": _cap(name_of(id)), "heir": d.heir.name, "gift": gift_text(g)})
	d._say(line)
	return {"ok": true, "text": line}


static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)


## What a screen says of a faction: {name, standing, rank, rank_name, line, remembers, gift, why_not}.
static func describe(d: GameDynasty, id: String) -> Dictionary:
	var s := standing(d, id)
	var r := rank_at(s)
	var says: Array = []
	for x in reasons(d, id).slice(0, int(setting("reasons_shown"))):
		says.append(str(x["say"]))
	return {
		"name": _cap(name_of(id)), "standing": s, "rank": str(r["id"]), "rank_name": str(r["name"]),
		"line": text("standing", {"rank": str(r["name"]), "standing": ("+" if s > 0 else "") + str(s)}),
		"remembers": text("remembers", {"reasons": "; ".join(says)}) if not says.is_empty() else text("nothing"),
		"gift": gift_text(gift(d, id)), "why_not": why_not(d, id),
	}


## A saved list of the factions that have honoured an heir, made safe: known ids, once each.
static func load_boons(v: Variant) -> Array:
	var out: Array = []
	if typeof(v) != TYPE_ARRAY:
		return out
	for id in v:
		if has(id) and id not in out:
			out.append(str(id))
	return out


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "factions", "text"]:
		if typeof(dat.get(k)) != TYPE_DICTIONARY:
			bad.append("factions.json has no '%s'" % k)
	if typeof(dat.get("ranks")) != TYPE_ARRAY or (dat.get("ranks", []) as Array).size() < 3:
		bad.append("factions.json needs at least three ranks")
	if not bad.is_empty():
		return bad
	var last := -1000
	var rank_ids: Array = []
	for r in dat["ranks"]:
		if str(r.get("id", "")) == "" or str(r.get("name", "")) == "" or str(r["id"]) in rank_ids:
			bad.append("a rank has no id or name, or is listed twice")
		rank_ids.append(str(r.get("id", "")))
		if int(r.get("min", 0)) <= last:
			bad.append("rank '%s' does not start above the rank before it" % r.get("id", ""))
		last = int(r.get("min", 0))
	if int(dat["ranks"][0].get("min", 0)) != -100:
		bad.append("the lowest rank must start at -100, or a standing could have no rank")
	for k in ["boon_rank", "top_rank"]:
		if str(setting(k)) not in rank_ids:
			bad.append("settings.%s is not a rank" % k)
	if rank_ids.size() > 0 and str(setting("top_rank")) != rank_ids[-1]:
		bad.append("settings.top_rank is not the highest rank")
	if _rank_index(str(setting("boon_rank"))) >= 0 and int(dat["ranks"][_rank_index(str(setting("boon_rank")))]["min"]) <= 0:
		bad.append("a gift would be offered to a house a faction knows nothing of (boon_rank starts at 0 or below)")
	if float(setting("honoured_mult")) < 1.0:
		bad.append("the top rank's gift is smaller than the one below it")
	var titled := {}
	for id in dat["factions"]:
		var f: Dictionary = dat["factions"][id]
		if str(f.get("name", "")) == "":
			bad.append("faction %s has no name" % id)
		var memory := float(f.get("memory", 0))
		if memory <= 0.0 or memory > 1.0:
			bad.append("faction %s: memory must be above 0 and no more than 1" % id)
		if (f.get("remembers", []) as Array).is_empty():
			bad.append("faction %s remembers nothing of any heir" % id)
		var can_rise := false
		for rule in f.get("remembers", []):
			bad.append_array(_rule_problems("faction %s" % id, rule, HEIR_RULES))
			if float(rule.get("each", 0)) > 0.0:
				can_rise = true
		for rule in f.get("house", []):
			bad.append_array(_rule_problems("faction %s" % id, rule, HOUSE_RULES))
			if float(rule.get("each", 0)) > 0.0:
				can_rise = true
		if not can_rise:
			bad.append("faction %s can never think well of a house" % id)
		var b: Variant = f.get("boon")
		if typeof(b) != TYPE_DICTIONARY:
			bad.append("faction %s has no gift" % id)
		else:
			var any := 0.0
			for k in b:
				if k not in ["gold", "potions", "xp"]:
					bad.append("faction %s: a gift cannot hold '%s'" % [id, k])
				elif typeof(b[k]) not in [TYPE_INT, TYPE_FLOAT] or float(b[k]) < 0.0:
					bad.append("faction %s: the gift's %s is not a number of 0 or more" % [id, k])
				else:
					any += float(b[k])
			if any <= 0.0:
				bad.append("faction %s gives nothing" % id)
		var t := str(f.get("title", ""))
		if t != "":
			var def := GameTitles.def(t)
			if def.is_empty():
				bad.append("faction %s confers the title '%s', which does not exist" % [id, t])
			elif def.get("when", {}) != {"faction": id} or str(def.get("kind")) != "personal":
				bad.append("faction %s: the title '%s' must be a personal title earned by {faction: %s}" % [id, t, id])
			titled[t] = id
	for t in GameTitles.defs():
		var w: Variant = t.get("when")
		if typeof(w) == TYPE_DICTIONARY and w.has("faction") and str(titled.get(str(t["id"]), "")) != str(w["faction"]):
			bad.append("title %s: is conferred by the faction '%s', which does not confer it" % [t["id"], w["faction"]])
	for k in ["standing", "remembers", "nothing", "gift", "gift_gold", "gift_potions", "gift_xp", "no_faction", "not_alive", "low", "taken", "not_town"]:
		if str(dat["text"].get(k, "")) == "":
			bad.append("factions: the text '%s' is missing" % k)
	return bad


static func _rule_problems(where: String, rule: Variant, kinds: Array) -> Array:
	var bad: Array = []
	if typeof(rule) != TYPE_DICTIONARY:
		return ["%s: a rule is not a dictionary" % where]
	var what := str(rule.get("what", ""))
	if what not in kinds:
		return ["%s: '%s' is not something it can weigh here (%s)" % [where, what, ", ".join(kinds)]]
	if typeof(rule.get("each")) not in [TYPE_INT, TYPE_FLOAT] or float(rule["each"]) == 0.0:
		bad.append("%s: the %s rule adds nothing (each)" % [where, what])
	if rule.has("cap") and float(rule["cap"]) <= 0.0:
		bad.append("%s: the %s rule's cap must be above 0" % [where, what])
	if str(rule.get("say", "")) == "":
		bad.append("%s: the %s rule does not say what is remembered" % [where, what])
	match what:
		"class":
			if (rule.get("classes", []) as Array).is_empty():
				bad.append("%s: a class rule names no class" % where)
			for c in rule.get("classes", []):
				if not GameData.classes.has(str(c)):
					bad.append("%s: no class called '%s'" % [where, c])
		"level", "battles", "gold":
			if float(rule.get("per", 0)) <= 0.0:
				bad.append("%s: the %s rule needs a 'per' above 0" % [where, what])
		"kills":
			if float(rule.get("per", 0)) <= 0.0:
				bad.append("%s: the kills rule needs a 'per' above 0" % where)
			if (rule.get("creatures", []) as Array).is_empty() and (rule.get("tags", []) as Array).is_empty():
				bad.append("%s: a kills rule names no creature and no tag" % where)
			for c in rule.get("creatures", []):
				if GameCombat.creature_def(str(c)).is_empty():
					bad.append("%s: no creature called '%s'" % [where, c])
			for t in rule.get("tags", []):
				if not GameData.creatures.any(func(c): return t in c.get("tags", [])):
					bad.append("%s: no creature has the tag '%s'" % [where, t])
		"cause":
			if (rule.get("causes", []) as Array).is_empty():
				bad.append("%s: a cause rule names no cause" % where)
		"echo":
			if str(rule.get("kind", "")) not in ["glory", "infamy"]:
				bad.append("%s: an echo rule's kind must be glory or infamy" % where)
		"bosses":
			if (rule.get("ids", []) as Array).is_empty():
				bad.append("%s: a bosses rule names no legend" % where)
			for b in rule.get("ids", []):
				if not GameCombat.creature_def(str(b)).get("boss", false):
					bad.append("%s: '%s' is not a legend" % [where, b])
	return bad
