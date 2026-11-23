## Trials (roadmap item 67, docs/TRIALS.md): timed tests in each realm, each run by a trial-master creature and reached through
## a small quest. Passing one gives the heir one lasting gain of its focus (Body, Will, Lore, Mastery, Spirit, Wild, Pact).
## Content is in data/world/trials.json. Where a realm's trials stand is a pure function of the world seed (`placed`). THE
## QUEST: each trial has steps (visit a place, offer gold, reach a level) the family does in order with `do_step`; the trial
## starts only once they are all done, and it is the quest's last step: the gain is given when the trial is passed. THE
## MASTER: a creature of data/creatures speaks the trial's lines (opening, a line for each stage, success, failure) and
## judges it; a trial marked `fight` is won by beating the master through the dynasty's own battle path (`begin_master`,
## `settle_master`). THE TIME: a trial runs on the world clock in world hours (GameDay's day is 24 hours); `wait` feeds
## GameClock. THE CHECK: a seeded roll on dice keyed on the world seed, the trial, the heir and the try, never the
## dynasty's. Failing costs health or gold, never a life, and a retry waits `retry_hours`. Gains are stat bonuses read
## through `bonus` (capped per focus and stat) and Lore unlocks a spell or feat the class suits. `Spirit` gains marked
## `legacy` pass to heirs. The autopilot (GameBot) never calls any of this, so seeded lives are unchanged.
## Saved: `GameHeir.trials_done` (ids; "id:fb" for a Lore trial that gave its fallback) and `GameDynasty.trials`
## ({steps, legacy, active, tries, retry}), each only once something is done, and both cleaned on load.
class_name GameTrials
extends RefCounted

const PATH := "res://data/world/trials.json"
const STEP_KINDS := ["visit", "offering", "level"]
const RISK_KINDS := ["hurt", "cost"]
const TEXT_KEYS := ["no_trial", "not_placed", "realm_closed", "done_already", "one_at_a_time", "low_level", "wrong_class", "needs_trial", "quest_open",
	"retry_wait", "started", "left", "not_ready", "no_active", "step_blocked", "need_place", "need_gold", "need_level", "no_step", "quest_done", "passed", "failed",
	"hurt", "cost", "gain_stat", "gain_capped", "gain_unlock", "gain_legacy", "drawback", "fight_first", "fight_begins", "fight_not_run", "no_fight", "stage"]

static var _cache: Dictionary = {}
static var _index: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
		_index = {}
		for realm in _cache["realms"]:
			for t in _cache["realms"][realm]["trials"]:
				t["realm"] = realm
				_index[str(t["id"])] = t
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


static func realm_ids() -> Array:
	var out: Array = data()["realms"].keys()
	out.sort()
	return out


static func ids() -> Array:
	data()
	var out: Array = _index.keys()
	out.sort()
	return out


static func has(id: String) -> bool:
	data()
	return _index.has(id)


static func trial(id: String) -> Dictionary:
	data()
	return _index.get(id, {})


static func pool(realm: String) -> Array:
	return data()["realms"].get(realm, {}).get("trials", [])


static func focus_name(focus: String) -> String:
	return str(data()["focuses"].get(focus, {}).get("name", focus))


static func focus_cap(focus: String) -> Dictionary:
	return data()["focuses"].get(focus, {}).get("cap", {})


# ---------------------------------------------------------------- placement

## The trials standing in a realm of the world with this seed: [{id, realm, x, z}]. A pure function of the seed and the realm.
static func placed(seed_value: int, realm: String) -> Array:
	var all := pool(realm)
	var out: Array = []
	if all.is_empty():
		return out
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, "trials", realm])
	var order: Array = all.map(func(t): return str(t["id"]))
	for i in range(order.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	var n := clampi(r.randi_range(int(setting("place_min")), int(setting("place_max"))), 1, order.size())
	var area := int(setting("area"))
	for i in n:
		out.append({"id": order[i], "realm": realm, "x": r.randi_range(0, area - 1), "z": r.randi_range(0, area - 1)})
	return out


## Every placed trial of every realm.
static func placed_all(seed_value: int) -> Array:
	var out: Array = []
	for realm in realm_ids():
		out.append_array(placed(seed_value, realm))
	return out


static func is_placed(d: GameDynasty, id: String) -> bool:
	var t := trial(id)
	if t.is_empty():
		return false
	return placed(d.seed_value, str(t["realm"])).any(func(p): return p["id"] == id)


# ---------------------------------------------------------------- state

static func _st(d: GameDynasty) -> Dictionary:
	return d.trials


static func hours_now(d: GameDynasty) -> float:
	return GameDay.seconds(d) / float(GameDay.setting("day_seconds")) * 24.0


static func done(h: GameHeir, id: String) -> bool:
	return h.trials_done.has(id) or h.trials_done.has(id + ":fb")


static func active(d: GameDynasty) -> Dictionary:
	return _st(d).get("active", {})


static func quest_steps_done(d: GameDynasty, id: String) -> int:
	return int(_st(d).get("steps", {}).get(id, 0))


static func quest_complete(d: GameDynasty, id: String) -> bool:
	return quest_steps_done(d, id) >= (trial(id).get("quest", {}).get("steps", []) as Array).size()


## The step the family is on, or {} when the way in is done.
static func next_step(d: GameDynasty, id: String) -> Dictionary:
	var steps: Array = trial(id).get("quest", {}).get("steps", [])
	var n := quest_steps_done(d, id)
	return steps[n] if n < steps.size() else {}


static func offering_cost(d: GameDynasty, step: Dictionary) -> int:
	return int(round(float(step.get("gold", 0)) * GameData.enemy_scale(d.gen)))


# ---------------------------------------------------------------- the quest

## Why the next step cannot be done now, or "".
static func step_block(d: GameDynasty, id: String) -> String:
	if not has(id):
		return text("no_trial")
	var s := next_step(d, id)
	if s.is_empty():
		return text("no_step")
	match str(s["kind"]):
		"visit":
			if d.world.location != str(s["place"]):
				return text("need_place", {"place": GameQuests.place_name(str(s["place"]))})
		"offering":
			if d.heir.gold < offering_cost(d, s):
				return text("need_gold", {"gold": offering_cost(d, s)})
		"level":
			if d.heir.level < int(s["level"]):
				return text("need_level", {"level": int(s["level"])})
	return ""


## Does the next step of a trial's quest. Returns the line to tell: the step's own, the master's when it is the last, or why not.
static func do_step(d: GameDynasty, id: String) -> String:
	var why := step_block(d, id)
	if why != "":
		return text("step_blocked", {"why": why})
	var s := next_step(d, id)
	if str(s["kind"]) == "offering":
		d.heir.gold -= offering_cost(d, s)
	if not d.trials.has("steps"):
		d.trials["steps"] = {}
	d.trials["steps"][id] = quest_steps_done(d, id) + 1
	var line := str(s.get("done", ""))
	if quest_complete(d, id):
		line += " " + text("quest_done", {"trial": str(trial(id)["name"])})
		d.set_flag("trial_%s_way" % id)
	d._say(line)
	return line


# ---------------------------------------------------------------- starting

## Why a trial cannot be started now, or "".
static func start_block(d: GameDynasty, id: String) -> String:
	var t := trial(id)
	if t.is_empty():
		return text("no_trial")
	if not is_placed(d, id):
		return text("not_placed")
	if not GameRealms.gate_open(d, str(t["realm"])):
		return text("realm_closed")
	if done(d.heir, id):
		return text("done_already", {"name": d.heir.name})
	if not active(d).is_empty():
		return text("one_at_a_time", {"name": d.heir.name})
	var g: Dictionary = t["gate"]
	if d.heir.level < int(g.get("level", 1)):
		return text("low_level", {"level": int(g.get("level", 1))})
	if g.has("classes") and d.heir.class_id not in g["classes"]:
		return text("wrong_class")
	if g.has("trial") and not done(d.heir, str(g["trial"])):
		return text("needs_trial", {"trial": str(trial(str(g["trial"])).get("name", g["trial"]))})
	var wait: float = float(_st(d).get("retry", {}).get(id, 0.0)) - hours_now(d)
	if wait > 0.0:
		return text("retry_wait", {"hours": int(ceil(wait))})
	if not quest_complete(d, id):
		return text("quest_open", {"master": str(t["master"]["name"]), "step": str(next_step(d, id).get("text", ""))})
	return ""


## Begins a trial. Returns the master's opening line, or why not.
static func start(d: GameDynasty, id: String) -> String:
	var why := start_block(d, id)
	if why != "":
		return why
	var t := trial(id)
	d.trials["active"] = {"id": id, "start": hours_now(d)}
	var line := "%s %s" % [text("started", {"name": d.heir.name, "trial": str(t["name"])}), str(t["lines"]["opening"])]
	d._say(line)
	return line


## World hours spent in the trial now under way.
static func spent(d: GameDynasty) -> float:
	var a := active(d)
	return 0.0 if a.is_empty() else maxf(0.0, hours_now(d) - float(a["start"]))


static func remaining(d: GameDynasty) -> float:
	var a := active(d)
	return 0.0 if a.is_empty() else maxf(0.0, float(trial(str(a["id"]))["length"]) - spent(d))


## The master's line for the stage the trial is in.
static func stage_line(d: GameDynasty) -> String:
	var a := active(d)
	if a.is_empty():
		return ""
	var t := trial(str(a["id"]))
	var stages: Array = t["lines"]["stages"]
	var i := clampi(int(floor(spent(d) / float(t["length"]) * float(stages.size()))), 0, stages.size() - 1)
	return text("stage", {"n": i + 1, "total": stages.size(), "line": str(stages[i])})


## Lets world hours pass on the world clock (the day, hunger and raids go on). Returns the clock's messages.
static func wait(d: GameDynasty, hours: float) -> Array:
	return GameClock.feed(d, maxf(0.0, hours) / 24.0 * float(GameDay.setting("day_seconds")))


## Leaves the trial under way; its progress is lost.
static func leave(d: GameDynasty) -> String:
	var a := active(d)
	if a.is_empty():
		return text("no_active")
	var line := text("left", {"name": d.heir.name, "trial": str(trial(str(a["id"]))["name"])})
	d.trials.erase("active")
	d._say(line)
	return line


# ---------------------------------------------------------------- resolution

## The chance the heir passes a trial's check: score / (score + difficulty), kept within the data's limits.
static func chance(h: GameHeir, id: String) -> float:
	var c: Dictionary = trial(id)["check"]
	var score := float(h.stat(str(c["stat"])))
	return clampf(score / (score + float(c["difficulty"])), float(setting("check_min")), float(setting("check_max")))


## The trial's own dice for this heir's try.
static func dice(d: GameDynasty, id: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "trial", id, d.heir.id, int(_st(d).get("tries", {}).get(id, 0))])
	return r


## Finishes the trial under way once its hours are spent. A trial won by a fight waits for `settle_master`. Returns the lines.
static func finish(d: GameDynasty) -> Array:
	var a := active(d)
	if a.is_empty():
		return [text("no_active")]
	var id := str(a["id"])
	var t := trial(id)
	if remaining(d) > 0.0:
		return [text("not_ready", {"trial": str(t["name"]), "hours": int(ceil(remaining(d)))})]
	var won := false
	if bool(t.get("fight", false)):
		if not bool(a.get("won", false)):
			return [text("fight_first", {"master": str(t["master"]["name"])})]
		won = true
	else:
		won = dice(d, id).randf() < chance(d.heir, id)
	if not d.trials.has("tries"):
		d.trials["tries"] = {}
	d.trials["tries"][id] = int(d.trials["tries"].get(id, 0)) + 1
	d.trials.erase("active")
	var out: Array = []
	if won:
		out.append("%s %s" % [str(t["lines"]["success"]), text("passed", {"name": d.heir.name, "trial": str(t["name"]), "gain": _give(d, id)})])
		d.set_flag("trial_" + id)
	else:
		out.append("%s %s" % [str(t["lines"]["failure"]), _setback(d, id)])
	for m in out:
		d._say(m)
	return out


static func _setback(d: GameDynasty, id: String) -> String:
	var t := trial(id)
	var risk: Dictionary = t["risk"]
	var h := d.heir
	var parts: Array = []
	if str(risk["kind"]) == "hurt":
		var lost := mini(h.hp - 1, int(round(float(h.max_hp()) * float(risk["hp_pct"]))))
		lost = maxi(0, lost)
		h.hp -= lost
		parts.append(text("hurt", {"hp": lost}))
	var gold := mini(h.gold, int(risk.get("gold", 0)))
	if gold > 0:
		h.gold -= gold
		parts.append(text("cost", {"gold": gold}))
	if not d.trials.has("retry"):
		d.trials["retry"] = {}
	d.trials["retry"][id] = hours_now(d) + float(setting("retry_hours"))
	return text("failed", {"name": h.name, "trial": str(t["name"]), "setback": " ".join(parts)}).strip_edges()


static func _percent(v: float) -> String:
	return "%+d%%" % int(round(v * 100.0))


static func _give(d: GameDynasty, id: String) -> String:
	var t := trial(id)
	var h := d.heir
	var gain: Dictionary = t["gain"]
	var line := ""
	if gain.has("lore"):
		var pick := _lore_pick(d, id)
		if pick.is_empty():
			h.trials_done.append(id + ":fb")
			line = _stat_line(h, t, gain["fallback"])
		else:
			h.trials_done.append(id)
			if str(pick["kind"]) == "spell":
				h.spells.append(str(pick["id"]))
				h.spell_news.append(str(pick["id"]))
				line = text("gain_unlock", {"what": str(GameCombat.spell(str(pick["id"])).get("name", pick["id"]))})
			else:
				h.known_feats.append(str(pick["id"]))
				line = text("gain_unlock", {"what": GameFeats.feat_name(str(pick["id"]))})
	else:
		h.trials_done.append(id)
		line = _stat_line(h, t, gain)
		if bool(gain.get("legacy", false)):
			if not d.trials.has("legacy"):
				d.trials["legacy"] = []
			if id not in d.trials["legacy"]:
				d.trials["legacy"].append(id)
			line += text("gain_legacy")
	if t.has("drawback"):
		line += text("drawback", {"stat": str(t["drawback"]["stat"]).replace("_", " "), "value": _percent(float(t["drawback"]["value"]))})
	h.hp = mini(h.hp, h.max_hp())
	return line


static func _stat_line(h: GameHeir, t: Dictionary, gain: Dictionary) -> String:
	var stat := str(gain["stat"])
	var cap := float(focus_cap(str(t["focus"])).get(stat, 0.0))
	var have := _focus_sum(h, str(t["focus"]), stat, str(t["id"]))
	if have >= cap - 0.000001:
		return text("gain_capped")
	return text("gain_stat", {"stat": stat.replace("_", " "), "value": _percent(minf(float(gain["value"]), cap - have))})


## The Lore unlock for this heir: the first of the trial's list that suits the class and is not known yet (picked on the trial's
## dice among them), or {} when none fits, or the focus has given its `unlocks` already: the fallback gain is given then.
static func _lore_pick(d: GameDynasty, id: String) -> Dictionary:
	var h := d.heir
	var t := trial(id)
	var cap := int(focus_cap("lore").get("unlocks", 0))
	var given := 0
	for e in h.trials_done:
		if trial(str(e)).get("focus", "") == "lore" and not str(e).ends_with(":fb"):
			given += 1
	if given >= cap:
		return {}
	var fits: Array = []
	for u in t["gain"]["lore"]:
		if str(u["kind"]) == "spell":
			var cls: Array = GameCombat.spell(str(u["id"])).get("learn", {}).get("classes", [])
			if h.class_id in cls and str(u["id"]) not in h.spells:
				fits.append(u)
		elif GameFeats.class_may(h.class_id, str(u["id"])) and str(u["id"]) not in h.known_feats:
			fits.append(u)
	if fits.is_empty():
		return {}
	return fits[dice(d, id).randi_range(0, fits.size() - 1)]


# ---------------------------------------------------------------- the master's fight

## Starts the fight with the master of the trial under way, once its hours are spent. Null when it is not a fight trial or not ready.
static func begin_master(d: GameDynasty) -> GameBattle:
	var a := active(d)
	if a.is_empty() or d.battle != null or remaining(d) > 0.0:
		return null
	var t := trial(str(a["id"]))
	if not bool(t.get("fight", false)):
		return null
	var foe := d.foe_for(str(t["master"]["id"]), maxi(1, int(round(float(d.heir.level) * float(setting("master_level_mult"))))))
	if foe.is_empty():
		return null
	foe["name"] = str(t["master"]["name"])
	a["fight"] = true
	d._say(text("fight_begins", {"master": str(t["master"]["name"])}))
	return d._begin_battle([foe], "legend")   # no sickness is rolled on the dynasty's dice, as for a legend


## After `finish_battle`: a victory over the master wins the trial, anything else leaves it to be fought again. Returns the lines.
static func settle_master(d: GameDynasty) -> Array:
	var a := active(d)
	if a.is_empty() or not bool(a.get("fight", false)) or d.battle != null:
		return []
	a.erase("fight")
	if d.last_result != "victory":
		return []
	a["won"] = true
	return finish(d)


# ---------------------------------------------------------------- effects

## The sum of a stat's trial bonuses on a heir: each focus's gains capped, a Pact's drawback added whole.
static func bonus(h: GameHeir, stat: String) -> float:
	var by_focus := {}
	var total := 0.0
	for e in h.trials_done:
		var id := str(e).trim_suffix(":fb")
		var t := trial(id)
		if t.is_empty():
			continue
		var gain: Dictionary = t["gain"]
		if gain.has("lore"):
			if not str(e).ends_with(":fb"):
				continue
			gain = gain["fallback"]
		if str(gain["stat"]) == stat:
			by_focus[t["focus"]] = float(by_focus.get(t["focus"], 0.0)) + float(gain["value"])
		if t.has("drawback") and str(t["drawback"]["stat"]) == stat:
			total += float(t["drawback"]["value"])
	for focus in by_focus:
		total += minf(float(by_focus[focus]), float(focus_cap(str(focus)).get(stat, 0.0)))
	return total


static func _focus_sum(h: GameHeir, focus: String, stat: String, except_id: String) -> float:
	var s := 0.0
	for e in h.trials_done:
		var id := str(e).trim_suffix(":fb")
		var t := trial(id)
		if t.is_empty() or id == except_id or str(t["focus"]) != focus:
			continue
		var gain: Dictionary = t["gain"]
		if gain.has("lore"):
			if not str(e).ends_with(":fb"):
				continue
			gain = gain["fallback"]
		if str(gain["stat"]) == stat:
			s += float(gain["value"])
	return s


## A new heir: Spirit gains marked `legacy` pass down; a trial under way is lost, and so are the waits. Does nothing for a house with no trials.
static func on_succession(d: GameDynasty, c: GameHeir) -> void:
	if d.trials.is_empty():
		return
	d.trials.erase("active")
	d.trials.erase("retry")
	c.trials_done = clean_done(d.trials.get("legacy", []))


# ---------------------------------------------------------------- save / load

## `v` (from a save, so anything) cleaned to known trial ids, once each ("id:fb" only for a Lore trial).
static func clean_done(v: Variant) -> Array:
	var out: Array = []
	if typeof(v) != TYPE_ARRAY:
		return out
	for e in v:
		if typeof(e) != TYPE_STRING or str(e) in out:
			continue
		var id := str(e).trim_suffix(":fb")
		if not has(id) or (str(e).ends_with(":fb") and not trial(id)["gain"].has("lore")):
			continue
		if done_in(out, id):
			continue
		out.append(str(e))
	return out


static func done_in(list: Array, id: String) -> bool:
	return list.has(id) or list.has(id + ":fb")


static func _num(v: Variant) -> bool:
	return typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v))


## The dynasty's saved trial state, checked: damaged ids and values are dropped. {} when nothing is left.
static func load_state(raw: Variant) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var steps := {}
	if typeof(raw.get("steps")) == TYPE_DICTIONARY:
		for id in raw["steps"]:
			if has(str(id)) and _num(raw["steps"][id]):
				var n := clampi(int(raw["steps"][id]), 0, (trial(str(id))["quest"]["steps"] as Array).size())
				if n > 0:
					steps[str(id)] = n
	if not steps.is_empty():
		out["steps"] = steps
	var legacy := clean_done(raw.get("legacy", [])).filter(func(e): return not str(e).ends_with(":fb"))
	if not legacy.is_empty():
		out["legacy"] = legacy
	var a: Variant = raw.get("active")
	if typeof(a) == TYPE_DICTIONARY and typeof(a.get("id")) == TYPE_STRING and has(str(a["id"])) and _num(a.get("start")):
		var act := {"id": str(a["id"]), "start": float(a["start"])}
		for k in ["fight", "won"]:
			if typeof(a.get(k)) == TYPE_BOOL and a[k]:
				act[k] = true
		out["active"] = act
	for key in ["tries", "retry"]:
		var m := {}
		if typeof(raw.get(key)) == TYPE_DICTIONARY:
			for id in raw[key]:
				if has(str(id)) and _num(raw[key][id]) and float(raw[key][id]) > 0.0:
					m[str(id)] = int(raw[key][id]) if key == "tries" else float(raw[key][id])
		if not m.is_empty():
			out[key] = m
	return out


# ---------------------------------------------------------------- validation

static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "focuses", "text", "realms"]:
		if typeof(dat.get(k)) != TYPE_DICTIONARY:
			bad.append("trials.json has no '%s'" % k)
	if not bad.is_empty():
		return bad
	for k in TEXT_KEYS:
		if str(dat["text"].get(k, "")) == "":
			bad.append("trials: no text '%s'" % k)
	if int(setting("place_min")) < 1 or int(setting("place_min")) > int(setting("place_max")):
		bad.append("trials: place_min must be 1 or more and at most place_max")
	if int(setting("area")) < 1 or float(setting("check_min")) <= 0.0 or float(setting("check_max")) > 1.0 or float(setting("check_min")) > float(setting("check_max")):
		bad.append("trials: area and the check limits are not sound")
	if float(setting("retry_hours")) < 0.0:
		bad.append("trials: retry_hours is negative")
	var seen := {}
	var base_focuses := {}
	if dat["realms"].size() < 3:
		bad.append("trials: at least the base world and two realms need trials")
	for realm in dat["realms"]:
		if not GameRealms.has(str(realm)):
			bad.append("trials: '%s' is not a realm" % realm)
		var list: Array = pool(str(realm))
		if list.size() < int(setting("place_min")):
			bad.append("trials: realm '%s' has fewer trials than place_min" % realm)
		for t in list:
			var id := str(t.get("id", ""))
			var w := "trial '%s'" % id
			if id == "" or seen.has(id):
				bad.append("trials: a trial has no id or repeats '%s'" % id)
			seen[id] = true
			if str(realm) == GameRealms.home():
				base_focuses[str(t.get("focus", ""))] = true
			bad.append_array(_check_trial(t, w))
	for f in dat["focuses"]:
		if not base_focuses.has(str(f)):
			bad.append("trials: the base world has no '%s' trial" % f)
	for realm in dat["realms"]:
		for t in pool(str(realm)):
			var g: Dictionary = t.get("gate", {})
			if g.has("trial") and not seen.has(str(g["trial"])):
				bad.append("trial '%s': gate names the unknown trial '%s'" % [t.get("id", ""), g["trial"]])
	return bad


static func _check_trial(t: Dictionary, w: String) -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["name", "focus", "length", "gate", "check", "risk", "gain", "master", "quest", "lines"]:
		if not t.has(k):
			bad.append("%s has no '%s'" % [w, k])
	if not bad.is_empty():
		return bad
	var focus := str(t["focus"])
	var cap: Dictionary = focus_cap(focus)
	if not dat["focuses"].has(focus):
		bad.append("%s has the unknown focus '%s'" % [w, focus])
	if str(t["name"]).strip_edges() == "" or float(t["length"]) <= 0.0:
		bad.append("%s needs a name and a length in hours" % w)
	if int(t["gate"].get("level", 0)) < 1:
		bad.append("%s: the gate needs a level of 1 or more" % w)
	for c in t["gate"].get("classes", []):
		if not GameData.classes.has(str(c)):
			bad.append("%s: gate class '%s' is unknown" % [w, c])
	if str(t["check"].get("stat", "")) not in GameHeir.STATS or float(t["check"].get("difficulty", 0)) <= 0.0:
		bad.append("%s: the check needs a stat and a difficulty" % w)
	if str(t["risk"].get("kind", "")) not in RISK_KINDS:
		bad.append("%s: risk kind must be one of %s" % [w, RISK_KINDS])
	if float(t["risk"].get("hp_pct", 0.0)) < 0.0 or float(t["risk"].get("hp_pct", 0.0)) >= 1.0:
		bad.append("%s: a risk must never kill (hp_pct 0 to under 1)" % w)
	var gains: Array = []
	var gain: Dictionary = t["gain"]
	if gain.has("lore"):
		if focus != "lore":
			bad.append("%s: only a Lore trial unlocks" % w)
		if (gain["lore"] as Array).is_empty() or not gain.has("fallback"):
			bad.append("%s: Lore needs a list and a fallback gain" % w)
		for u in gain["lore"]:
			if str(u.get("kind", "")) == "spell" and GameCombat.spell(str(u.get("id", ""))).is_empty():
				bad.append("%s: unknown spell '%s'" % [w, u.get("id", "")])
			elif str(u.get("kind", "")) == "feat" and GameFeats.def(str(u.get("id", ""))).is_empty():
				bad.append("%s: unknown feat '%s'" % [w, u.get("id", "")])
			elif str(u.get("kind", "")) not in ["spell", "feat"]:
				bad.append("%s: a Lore unlock is a spell or a feat" % w)
		if gain.has("fallback"):
			gains.append(gain["fallback"])
	else:
		gains.append(gain)
	for g in gains:
		if not cap.has(str(g.get("stat", ""))) or float(g.get("value", 0.0)) <= 0.0:
			bad.append("%s: a gain needs a positive value for a stat the focus caps (%s)" % [w, str(g.get("stat", ""))])
	if focus == "pact" and (not t.has("drawback") or float(t["drawback"].get("value", 0.0)) >= 0.0):
		bad.append("%s: a Pact must carry a drawback (a negative value)" % w)
	if bool(t.get("fight", false)) and focus not in ["mastery", "pact"]:
		bad.append("%s: only Mastery and Pact trials are won by a fight" % w)
	var m: Dictionary = t["master"]
	if not GameData.creatures.any(func(c): return c["id"] == m.get("id", "")) or str(m.get("name", "")).strip_edges() == "":
		bad.append("%s: the master needs a creature of the game and a name" % w)
	var lines: Dictionary = t["lines"]
	for k in ["opening", "success", "failure"]:
		if str(lines.get(k, "")).strip_edges() == "":
			bad.append("%s: the master has no '%s' line" % [w, k])
	if typeof(lines.get("stages")) != TYPE_ARRAY or (lines["stages"] as Array).is_empty() or (lines["stages"] as Array).any(func(s): return str(s).strip_edges() == ""):
		bad.append("%s: the master needs a line for each stage" % w)
	var steps: Array = t["quest"].get("steps", [])
	if steps.is_empty():
		bad.append("%s: the quest has no steps" % w)
	for s in steps:
		var k := str(s.get("kind", ""))
		if k not in STEP_KINDS or str(s.get("text", "")) == "" or str(s.get("done", "")) == "":
			bad.append("%s: a quest step needs a kind (%s), text and done line" % [w, STEP_KINDS])
		elif k == "visit" and GameWorld.place(str(s.get("place", ""))).is_empty():
			bad.append("%s: a quest step names the unknown place '%s'" % [w, s.get("place", "")])
		elif k == "offering" and int(s.get("gold", 0)) <= 0:
			bad.append("%s: an offering needs gold" % w)
		elif k == "level" and int(s.get("level", 0)) < 1:
			bad.append("%s: a level step needs a level" % w)
	return bad
