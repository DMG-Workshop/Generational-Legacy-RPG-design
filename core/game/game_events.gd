## Events with skill checks and degrees of success. Content lives in data/events/events.json,
## tuning in data/game/balance.json (event_* keys). An event waiting for the player is stored in
## GameDynasty.pending_event:
##   {id, heir, place, source, stage: "choose"}                 while a choice is awaited
##   {..., stage: "result", result: {choice_text, roll, ...}}    after the choice, until dismissed
class_name GameEvents
extends RefCounted

const DEGREES := ["crit_failure", "failure", "success", "crit_success"]
const DEGREE_LABELS := {
	"crit_failure": "Critical failure", "failure": "Failure", "success": "Success",
	"crit_success": "Critical success", "always": "",
}
const ATTR_LABELS := {
	"str": "STR", "mag": "MAG", "agi": "AGI", "vit": "VIT",
	"persuasion": "Persuasion", "stealth": "Stealth", "theft": "Theft", "intimidation": "Intimidation",
	"luck": "Luck", "prophecy_strength": "Prophecy", "healing_power": "Healing", "glamour_sight": "Fae-sight",
	"divine_magic_power": "Faith", "dark_magic_power": "Dark arts", "element_power": "Elements",
	"craft_quality": "Craft",
}
const EFFECT_KEYS := ["text", "gold", "xp", "hp_pct", "potions", "add_trait", "remove_trait", "flag", "item", "echo", "fate", "years", "fight"]
const SEEN := "event_seen_"   # once-per-dynasty events
const LAST := "event_last_"   # repeatable events: generation they last happened


# ---------------------------------------------------------------- content lookup

static func event_def(id: String) -> Dictionary:
	GameData.load_all()
	for e in GameData.events:
		if e["id"] == id:
			return e
	return {}


static func current(d: GameDynasty) -> Dictionary:
	if d.pending_event.is_empty():
		return {}
	return event_def(str(d.pending_event.get("id", "")))


## Replaces {heir}, {house}, {place} and {ancestor} in event text.
static func fill(d: GameDynasty, text: String) -> String:
	var place: Dictionary = GameWorld.place(str(d.pending_event.get("place", d.world.location)))
	return text.replace("{heir}", d.heir.name).replace("{house}", d.dynasty_name) \
		.replace("{place}", str(place.get("name", ""))).replace("{ancestor}", str(d.pending_event.get("ancestor", "an ancestor")))


static func event_title(d: GameDynasty) -> String:
	return fill(d, str(current(d).get("title", "")))


static func event_text(d: GameDynasty) -> String:
	return fill(d, str(current(d).get("text", "")))


# ---------------------------------------------------------------- eligibility

static func place_matches(ev: Dictionary, place: Dictionary) -> bool:
	var w: Dictionary = ev.get("where", {})
	var types: Array = w.get("types", [])
	if not types.is_empty() and place.get("type", "") not in types:
		return false
	var biomes: Array = w.get("biomes", [])
	var own: Array = place.get("biomes", [])
	if not biomes.is_empty() and not biomes.any(func(b): return b in own):
		return false
	var places: Array = w.get("places", [])
	if not places.is_empty() and place.get("id", "") not in places:
		return false
	return true


static func is_eligible(d: GameDynasty, ev: Dictionary) -> bool:
	if not place_matches(ev, d.world.here()):
		return false
	var r: Dictionary = ev.get("requires", {})
	if d.gen < int(r.get("min_gen", 1)) or d.gen > int(r.get("max_gen", 1000000)):
		return false
	if d.heir.level < int(r.get("min_level", 1)):
		return false
	for f in r.get("flags", []):
		if not d.flags.has(f):
			return false
	for f in r.get("not_flags", []):
		if d.flags.has(f):
			return false
	var need_traits: Array = r.get("traits", [])
	if not need_traits.is_empty() and not need_traits.any(func(t): return t in d.heir.all_traits()):
		return false
	var id: String = ev["id"]
	if ev.get("once", false):
		return not d.flags.has(SEEN + id)
	return int(d.flags.get(LAST + id, 0)) < d.gen   # repeatable events come at most once a generation


static func eligible(d: GameDynasty) -> Array:
	GameData.load_all()
	return GameData.events.filter(func(e): return is_eligible(d, e))


static func pick_event(d: GameDynasty) -> Dictionary:
	var pool := eligible(d)
	if pool.is_empty():
		return {}
	var total := 0.0
	for e in pool:
		total += float(e.get("weight", 10))
	var roll := d.rng.randf() * total
	for e in pool:
		roll -= float(e.get("weight", 10))
		if roll < 0.0:
			return e
	return pool[pool.size() - 1]


## Opens an event for the living heir (also used by tests and tools to force one).
static func begin(d: GameDynasty, id: String, source: String = "explore") -> bool:
	var ev := event_def(id)
	if ev.is_empty() or d.state != "life":
		return false
	d.pending_event = {"id": id, "heir": d.heir.id, "place": d.world.location, "source": source, "stage": "choose"}
	if str(ev.get("text", "")).contains("{ancestor}") or str(ev.get("title", "")).contains("{ancestor}"):
		d.pending_event["ancestor"] = _ancestor_name(d)
	if ev.get("once", false):
		d.set_flag(SEEN + id)
	else:
		d.flags[LAST + id] = d.gen   # bookkeeping, not a story flag: no quest listens for it
	return true


static func _ancestor_name(d: GameDynasty) -> String:
	if d.history.is_empty():
		return "a stranger with your family's eyes"
	return str(d.history[d.rng.randi() % d.history.size()]["name"])


## A pending event left by an heir who has since died (or content that no longer exists) is dropped.
static func drop_stale(d: GameDynasty) -> void:
	if d.pending_event.is_empty():
		return
	if int(d.pending_event.get("heir", -1)) != d.heir.id or current(d).is_empty():
		d.pending_event = {}


static func dismiss(d: GameDynasty) -> void:
	d.pending_event = {}


static func stage(d: GameDynasty) -> String:
	return str(d.pending_event.get("stage", ""))


# ---------------------------------------------------------------- triggers

## The heir spends a year exploring the current place; may set d.pending_event.
static func explore(d: GameDynasty) -> Array:
	drop_stale(d)
	if d.state != "life":
		return []
	if d.has_pending_event():
		return ["%s must first settle the matter at hand: %s." % [d.heir.name, event_title(d)]]
	var h := d.heir
	var place := d.world.here()
	var ev: Dictionary = {}
	if d.rng.randf() < float(GameData.bal("event_explore_chance")):
		ev = pick_event(d)
	if ev.is_empty():
		var xp := int(round(float(GameData.bal("event_quiet_xp")) * GameData.xp_level_scale(h.level)))
		var msgs: Array = ["%s explores %s. Nothing stirs, but the land is better known for it (+%d XP)." % [h.name, place["name"], xp]]
		if h.gain_xp(xp) > 0:
			msgs.append("Level up! %s is now level %d." % [h.name, h.level])
		return d._finish_time("explore", msgs)
	var out := d._finish_time("explore", ["%s spends a year exploring %s." % [h.name, place["name"]]])
	if d.state == "life":
		begin(d, ev["id"], "explore")
		var m := "Something happens: %s." % event_title(d)
		d._say(m)
		out.append(m)
	return out


## Something may happen on arriving in the wilds or a dungeon; may set d.pending_event.
static func on_arrive(d: GameDynasty, place_id: String) -> Array:
	drop_stale(d)
	if d.state != "life" or d.has_pending_event() or d.world.location != place_id:
		return []
	if GameWorld.place(place_id).get("type", "") not in GameData.bal("event_arrive_types"):
		return []
	if d.rng.randf() >= float(GameData.bal("event_arrive_chance")):
		return []
	var ev := pick_event(d)
	if ev.is_empty():
		return []
	begin(d, ev["id"], "arrive")
	var m := "On the way into %s: %s." % [GameWorld.place(place_id)["name"], event_title(d)]
	d._say(m)
	return [m]


# ---------------------------------------------------------------- choices & requirements

static func _matches_kind(table: Dictionary, own: String, wanted: Array) -> bool:
	if own in wanted:
		return true
	for p in table.get(own, {}).get("parents", []):   # a hybrid counts as both parent kinds
		if p in wanted:
			return true
	return false


static func _owns(h: GameHeir, item: String) -> bool:
	return item in h.inventory or item in h.equipment.values()


static func gold_amount(d: GameDynasty, base: float) -> int:
	return int(round(base * GameData.enemy_scale(d.gen)))


static func _names(table: Dictionary, ids: Array) -> String:
	return " or ".join(ids.map(func(x): return str(table.get(x, {}).get("name", x))))


## Whether the heir may take a choice: {ok, reason ("Requires: The Sight"), tag (what opened it)}.
## Gates in "requires" must all pass, or any one of them with "any": true.
static func choice_status(d: GameDynasty, c: Dictionary) -> Dictionary:
	var r: Dictionary = c.get("requires", {})
	if r.is_empty():
		return {"ok": true, "reason": "", "tag": ""}
	var h := d.heir
	var passed: Array = []   # tags of gates that passed
	var failed: Array = []   # reasons of gates that failed
	if r.has("traits"):
		var hit: Array = (r["traits"] as Array).filter(func(t): return t in h.all_traits())
		if hit.is_empty():
			failed.append(" or ".join((r["traits"] as Array).map(func(t): return GameData.trait_name(t))))
		else:
			passed.append(GameData.trait_name(hit[0]))
	if r.has("race"):
		if _matches_kind(GameData.races, h.race_id, r["race"]):
			passed.append(h.race()["name"])
		else:
			failed.append(_names(GameData.races, r["race"]))
	if r.has("class"):
		if _matches_kind(GameData.classes, h.class_id, r["class"]):
			passed.append(h.cls()["name"])
		else:
			failed.append(_names(GameData.classes, r["class"]))
	if r.has("item"):
		var item: String = r["item"]
		if _owns(h, item):
			passed.append(GameItems.item_def(item).get("name", item))
		else:
			failed.append(GameItems.item_def(item).get("name", item))
	if r.has("flag"):
		if d.flags.has(r["flag"]):
			passed.append("")
		else:
			failed.append(str(r["flag"]).capitalize())
	if r.has("min_level"):
		if h.level >= int(r["min_level"]):
			passed.append("")
		else:
			failed.append("level %d" % int(r["min_level"]))
	if r.has("min_gold"):
		var cost := gold_amount(d, float(r["min_gold"]))
		if h.gold >= cost:
			passed.append("")
		else:
			failed.append("%d gold" % cost)
	var ok: bool = failed.is_empty() or (r.get("any", false) and not passed.is_empty())
	var tags: Array = passed.filter(func(t): return t != "")
	var tag: String = tags[0] if not tags.is_empty() else ""
	if ok:
		return {"ok": true, "reason": "", "tag": tag}
	var why: String = r.get("reason", "Requires: " + (" or " if r.get("any", false) else ", ").join(failed))
	return {"ok": false, "reason": why, "tag": ""}


## The button text for choice `i` of the pending event, e.g. "Climb the cliff  [AGI vs DC 15: +9, 70%]".
static func choice_label(d: GameDynasty, i: int) -> String:
	var c: Dictionary = current(d)["choices"][i]
	var st := choice_status(d, c)
	var text := fill(d, str(c["text"]))
	if not st["ok"]:
		return "%s  (%s)" % [text, st["reason"]]
	if st["tag"] != "":
		text = "[%s] %s" % [st["tag"], text]
	var extra: Array = []
	if c.get("requires", {}).has("min_gold"):
		extra.append("%d gold" % gold_amount(d, float(c["requires"]["min_gold"])))
	if c.has("check"):
		extra.append(check_text(d, c["check"]))
	elif outcome_for(c, "always").has("fight"):
		extra.append("Battle")
	return text if extra.is_empty() else "%s  [%s]" % [text, ", ".join(extra)]


## Hover text: how the bonus is made up and the odds of each degree.
static func choice_tooltip(d: GameDynasty, i: int) -> String:
	var c: Dictionary = current(d)["choices"][i]
	var st := choice_status(d, c)
	if not st["ok"]:
		return st["reason"]
	if not c.has("check"):
		return "No roll needed."
	var lines: Array = []
	for p in check_parts(d, c["check"]):
		lines.append("%s %+d" % [p[0], p[1]])
	lines.append("Difficulty %d" % check_dc(d, c["check"]))
	var odds := degree_odds(d, c["check"])
	for k in [3, 2, 1, 0]:
		lines.append("%s: %d%%" % [DEGREE_LABELS[DEGREES[k]], int(round(odds[k] * 100.0))])
	return "\n".join(lines)


# ---------------------------------------------------------------- checks

## Proficiency grows by event_proficiency_step with each doubling of level (step 1: +1 at level 1,
## +5 at 31, +12 at 5000, +16 at the cap).
static func proficiency(level: int) -> int:
	var n := maxi(1, level + 1)
	var doublings := 0
	while n > 1:
		n >>= 1
		doublings += 1
	return int(GameData.bal("event_proficiency_step")) * doublings


## Attribute part of a check: a stat relative to the heir's best stat, or a skill from traits and gear.
static func attr_bonus(h: GameHeir, attr: String) -> int:
	if attr in GameHeir.STATS:
		var best := 1.0
		for s in GameHeir.STATS:
			best = maxf(best, h.stat(s))
		return int(round(float(GameData.bal("event_stat_bonus_max")) * h.stat(attr) / best))
	var cap := float(GameData.bal("event_skill_bonus_cap"))
	return int(round(clampf(h.trait_total(attr) * float(GameData.bal("event_skill_bonus_mult")), -cap, cap)))


static func _bonus_applies(h: GameHeir, b: Dictionary) -> String:
	if b.has("race") and _matches_kind(GameData.races, h.race_id, [b["race"]]):
		return str(GameData.races[b["race"]]["name"])
	if b.has("class") and _matches_kind(GameData.classes, h.class_id, [b["class"]]):
		return str(GameData.classes[b["class"]]["name"])
	if b.has("trait") and b["trait"] in h.all_traits():
		return GameData.trait_name(b["trait"])
	return ""


## [[label, value], ...] making up the bonus of a check.
static func check_parts(d: GameDynasty, check: Dictionary) -> Array:
	var h := d.heir
	var attr: String = check["attr"]
	var parts: Array = [["Proficiency (level %d)" % h.level, proficiency(h.level)], [ATTR_LABELS.get(attr, attr), attr_bonus(h, attr)]]
	for b in check.get("bonus_if", []):
		var who := _bonus_applies(h, b)
		if who != "":
			parts.append([who, int(b["value"])])
	return parts


static func check_bonus(d: GameDynasty, check: Dictionary) -> int:
	var total := 0
	for p in check_parts(d, check):
		total += int(p[1])
	return total


## The authored DC, raised in dangerous places and lowered in safe ones.
static func check_dc(d: GameDynasty, check: Dictionary) -> int:
	var place: Dictionary = GameWorld.place(str(d.pending_event.get("place", d.world.location)))
	var danger := float(place.get("danger", 1.0))
	return int(check["dc"]) + int(round((danger - 1.0) * float(GameData.bal("event_dc_per_danger"))))


## Degree index (0 crit failure .. 3 crit success) of a d20 roll; a natural 20 / 1 moves it one step.
static func degree_index(die: int, total: int, dc: int) -> int:
	var margin := int(GameData.bal("event_crit_margin"))
	var deg := 0
	if total >= dc + margin:
		deg = 3
	elif total >= dc:
		deg = 2
	elif total > dc - margin:
		deg = 1
	if die == 20:
		deg = mini(3, deg + 1)
	elif die == 1:
		deg = maxi(0, deg - 1)
	return deg


## Chance of each degree, indexed like DEGREES.
static func degree_odds(d: GameDynasty, check: Dictionary) -> Array:
	var bonus := check_bonus(d, check)
	var dc := check_dc(d, check)
	var odds := [0.0, 0.0, 0.0, 0.0]
	for die in range(1, 21):
		odds[degree_index(die, die + bonus, dc)] += 0.05
	return odds


static func success_chance(d: GameDynasty, check: Dictionary) -> float:
	var odds := degree_odds(d, check)
	return clampf(float(odds[2]) + float(odds[3]), 0.0, 1.0)


static func check_text(d: GameDynasty, check: Dictionary) -> String:
	return "%s vs DC %d: %+d, %d%%" % [ATTR_LABELS.get(check["attr"], check["attr"]), check_dc(d, check), check_bonus(d, check), int(round(success_chance(d, check) * 100.0))]


## "d20 (14) +9 = 23 vs DC 15: Success" for a stored roll.
static func roll_text(roll: Dictionary) -> String:
	if roll.is_empty():
		return ""
	return "d20 (%d) %+d = %d vs DC %d: %s" % [int(roll["die"]), int(roll["bonus"]), int(roll["total"]), int(roll["dc"]), DEGREE_LABELS[roll["degree"]]]


# ---------------------------------------------------------------- resolution

## The outcome for a degree; a missing critical falls back to the plain one, then to "always".
static func outcome_for(c: Dictionary, degree: String) -> Dictionary:
	var o: Dictionary = c.get("outcomes", {})
	for k in [degree, {"crit_success": "success", "crit_failure": "failure"}.get(degree, degree), "always"]:
		if o.has(k):
			return o[k]
	return {}


## Resolve the pending event with the chosen option. Returns the messages (also written to the journal).
static func resolve(d: GameDynasty, choice: int) -> Array:
	return _resolve(d, choice, "")


## Like resolve, but with the degree fixed instead of rolled (tests and tools).
static func resolve_as(d: GameDynasty, choice: int, degree: String) -> Array:
	return _resolve(d, choice, degree)


static func _resolve(d: GameDynasty, choice: int, forced: String) -> Array:
	drop_stale(d)
	if d.state != "life" or stage(d) != "choose":
		return []
	var ev := current(d)
	var choices: Array = ev["choices"]
	if choice < 0 or choice >= choices.size():
		return []
	var c: Dictionary = choices[choice]
	if not choice_status(d, c)["ok"]:
		return []
	var roll: Dictionary = {}
	var degree := "always"
	if c.has("check"):
		var bonus := check_bonus(d, c["check"])
		var dc := check_dc(d, c["check"])
		var die := d.rng.randi_range(1, 20)
		degree = DEGREES[degree_index(die, die + bonus, dc)] if forced == "" else forced
		roll = {"attr": c["check"]["attr"], "die": die, "bonus": bonus, "total": die + bonus, "dc": dc, "degree": degree}
	var outcome := outcome_for(c, degree)
	var text := fill(d, str(outcome.get("text", "")))
	var head := "%s - %s" % [event_title(d), fill(d, str(c["text"]))]
	if not roll.is_empty():
		head += " (%s %s)" % [ATTR_LABELS.get(roll["attr"], roll["attr"]), roll_text(roll)]
	var msgs: Array = [head + "."]
	if text != "":
		msgs.append(text)
	var fx := _apply(d, ev, outcome, msgs)
	var years := int(outcome.get("years", 0))
	if years > 0:
		fx.append({"t": "%d year%s pass" % [years, "" if years == 1 else "s"], "k": "bad"})
		msgs = d._pass_years(float(years), msgs)
	else:
		for m in msgs:
			d._say(m)
	var fight_names: Array = []
	if d.state == "life" and outcome.has("fight"):
		var foes := _build_foes(d, outcome["fight"])
		d._begin_battle(foes, "event")
		fight_names = foes.map(func(e): return e["name"])
		fx.append({"t": "Battle: %s" % ", ".join(fight_names), "k": "bad"})
	if d.state != "life":
		fx.append({"t": "%s's story ends here." % d.heir.name, "k": "bad"})
	d.pending_event["stage"] = "result"
	d.pending_event["result"] = {
		"choice": choice, "choice_text": fill(d, str(c["text"])), "roll": roll, "degree": degree,
		"text": text, "effects": fx, "fight": fight_names,
	}
	return msgs


## Applies an outcome's immediate effects; returns [{t: text, k: good|bad|info}] for the panel and
## appends journal lines to `msgs`. Years and fights are handled by the caller.
static func _apply(d: GameDynasty, ev: Dictionary, o: Dictionary, msgs: Array) -> Array:
	var h := d.heir
	var fx: Array = []
	if o.has("gold"):
		var g := gold_amount(d, float(o["gold"]))
		if g < 0:
			g = -mini(-g, h.gold)
		h.gold += g
		if g != 0:
			fx.append({"t": "%+d gold" % g, "k": "good" if g > 0 else "bad"})
	if o.has("xp"):
		var xp := int(round(float(o["xp"]) * GameData.xp_level_scale(h.level)))
		fx.append({"t": "+%d XP" % xp, "k": "good"})
		if h.gain_xp(xp) > 0:
			fx.append({"t": "Level up! Now level %d" % h.level, "k": "good"})
			msgs.append("Level up! %s is now level %d." % [h.name, h.level])
	if o.has("hp_pct"):
		var before := h.hp
		h.hp = clampi(h.hp + int(round(float(h.max_hp()) * float(o["hp_pct"]))), 1, h.max_hp())   # events wound, never kill
		if h.hp > before:
			fx.append({"t": "Recovered %d HP" % (h.hp - before), "k": "good"})
		elif h.hp < before:
			fx.append({"t": "Lost %d HP" % (before - h.hp), "k": "bad"})
	if o.has("potions"):
		h.potions += int(o["potions"])
		fx.append({"t": "+%d potion%s" % [int(o["potions"]), "" if int(o["potions"]) == 1 else "s"], "k": "good"})
	if o.has("add_trait"):
		var t: String = o["add_trait"]
		if d._add_trait(h, t):
			fx.append({"t": "Trait gained: %s" % GameData.trait_name(t), "k": "bad" if is_harmful_trait(t) else "good"})
	if o.has("remove_trait"):
		var ids: Array = o["remove_trait"] if o["remove_trait"] is Array else [o["remove_trait"]]
		for t in ids:
			if t in h.traits:
				h.traits.erase(t)
				h.lifespan = h.compute_lifespan()
				fx.append({"t": "Trait lost: %s" % GameData.trait_name(t), "k": "good" if is_harmful_trait(t) else "bad"})
				break
	if o.has("flag"):
		d.set_flag(o["flag"])
	if o.has("item"):
		var item: String = o["item"]
		if _owns(h, item):
			var g := maxi(1, int(round(float(GameItems.item_def(item).get("price", 0)) * GameData.enemy_scale(d.gen) * float(GameData.bal("event_duplicate_item_gold")))))
			h.gold += g
			fx.append({"t": "Already owned %s: sold for %d gold" % [GameItems.item_def(item).get("name", item), g], "k": "good"})
		else:
			fx.append({"t": d.give_item(item).trim_suffix("."), "k": "good"})
	if o.has("echo"):
		var e: Dictionary = o["echo"]
		var etext := fill(d, str(e["text"]))
		d._add_echo(e["kind"], "event_" + str(ev["id"]), etext, float(e["strength"]))
		fx.append({"t": "Legacy echo: %s (%s)" % [etext, e["kind"]], "k": "good" if e["kind"] == "glory" else "bad"})
	if o.has("fate"):
		var before := h.fate_value
		h.fate_value = snappedf(clampf(h.fate_value + float(o["fate"]), float(GameData.bal("fate_min")), float(GameData.bal("fate_max"))), 0.0001)
		var delta := h.fate_value - before
		if absf(delta) > 0.00005:
			fx.append({"t": "Fate Value %+.1f%%" % (delta * 100.0), "k": "good" if delta < 0.0 else "bad"})   # lower is kinder
	var summary: Array = fx.filter(func(f): return not str(f["t"]).begins_with("Level up")).map(func(f): return f["t"])
	if not summary.is_empty():
		msgs.append(", ".join(summary) + ".")
	return fx


static func is_harmful_trait(id: String) -> bool:
	var def := GameData.trait_def(id)
	return def.get("category", "") == "curse" or float(def.get("fate_modifier", 0.0)) > 0.0


## Foes for an event fight, built like hunt foes. A creature that does not roam in this era (or
## "local") is replaced by one that lives here now.
static func _build_foes(d: GameDynasty, f: Dictionary) -> Array:
	var danger := float(d.world.here().get("danger", 1.0))
	var level := maxi(1, int(round(float(d.heir.level) * float(f.get("level", 1.0)) * danger)))
	var power := float(f.get("power", GameData.bal("event_fight_power")))
	var reward := float(f.get("reward", GameData.bal("event_fight_reward")))
	var foes: Array = []
	for id in f.get("foes", ["local"]):
		foes.append(d._make_enemy(_creature_for(d, str(id)), power, reward, level))
	return foes


static func _in_era(d: GameDynasty, c: Dictionary) -> bool:
	return not c.get("boss", false) and int(c["min_gen"]) <= d.gen and d.gen <= int(c["max_gen"])


static func _creature_for(d: GameDynasty, id: String) -> Dictionary:
	for c in GameData.creatures:
		if c["id"] == id and _in_era(d, c):
			return c
	var era := GameData.creatures.filter(func(c): return _in_era(d, c))
	if era.is_empty():
		era = GameData.creatures.filter(func(c): return not c.get("boss", false))
	var biomes: Array = d.world.here().get("biomes", [])
	var local := era.filter(func(c): return (c.get("biomes", []) as Array).any(func(b): return b in biomes))
	var pool: Array = local if not local.is_empty() else era
	return pool[d.rng.randi() % pool.size()]


# ---------------------------------------------------------------- autopilot

static func bot_wants_explore(d: GameDynasty) -> bool:
	var h := d.heir
	if d.state != "life" or d.has_pending_event() or d.world.is_town() or float(h.hp) < float(h.max_hp()) * 0.7:
		return false
	var key := "%d:%d:%d:%d" % [h.id, h.level, h.battles_won, int(h.age * 4.0)]
	return posmod(key.hash(), int(GameData.bal("event_bot_explore_every"))) == 0


## Picks the open choice with the best expected value, settles the event and fights any battle.
static func bot_resolve(d: GameDynasty) -> void:
	drop_stale(d)
	if not d.has_pending_event():
		return
	if stage(d) == "choose":
		var best := -1
		var best_v := -INF
		var choices: Array = current(d)["choices"]
		for i in choices.size():
			if not choice_status(d, choices[i])["ok"]:
				continue
			var v := choice_value(d, choices[i])
			if v > best_v:
				best_v = v
				best = i
		if best >= 0:
			resolve(d, best)
	dismiss(d)
	if d.battle != null:
		GameBot.fight(d)


static func choice_value(d: GameDynasty, c: Dictionary) -> float:
	if not c.has("check"):
		return outcome_value(d, outcome_for(c, "always"))
	var odds := degree_odds(d, c["check"])
	var v := 0.0
	for k in 4:
		v += float(odds[k]) * outcome_value(d, outcome_for(c, DEGREES[k]))
	return v


## Rough worth of an outcome to the autopilot, in "XP-like" points.
static func outcome_value(d: GameDynasty, o: Dictionary) -> float:
	var h := d.heir
	var v := float(o.get("xp", 0)) + float(o.get("gold", 0)) * 0.5 + float(o.get("hp_pct", 0.0)) * 100.0
	v += float(o.get("potions", 0)) * 8.0 - float(o.get("years", 0)) * 15.0 - float(o.get("fate", 0.0)) * 2000.0
	if o.has("item"):
		v += 30.0
	if o.has("add_trait") and o["add_trait"] not in h.traits:
		v += -150.0 if is_harmful_trait(o["add_trait"]) else 50.0
	if o.has("remove_trait"):
		var ids: Array = o["remove_trait"] if o["remove_trait"] is Array else [o["remove_trait"]]
		for t in ids:
			if t in h.traits:
				v += 80.0 if is_harmful_trait(t) else -50.0
				break
	if o.has("echo"):
		v += float(o["echo"]["strength"]) * (200.0 if o["echo"]["kind"] == "glory" else -200.0)
	if o.has("fight"):
		v += 10.0 if float(h.hp) >= float(h.max_hp()) * 0.75 else -80.0
	return v


# ---------------------------------------------------------------- content checks

## Problems with the event data (unknown ids, missing outcomes, events nobody can leave). Empty = fine.
static func validate() -> Array:
	GameData.load_all()
	var errs: Array = []
	var ids := {}
	var biomes := {}
	var place_ids := {}
	for l in GameData.world["locations"]:
		place_ids[l["id"]] = true
		for b in l.get("biomes", []):
			biomes[b] = true
	var creature_ids := {"local": true}
	for c in GameData.creatures:
		if not c.get("boss", false):
			creature_ids[c["id"]] = true
	for ev in GameData.events:
		var id: String = ev.get("id", "?")
		if ids.has(id):
			errs.append("%s: duplicate id" % id)
		ids[id] = true
		for k in ["title", "text"]:
			if str(ev.get(k, "")) == "":
				errs.append("%s: missing %s" % [id, k])
		var w: Dictionary = ev.get("where", {})
		for t in w.get("types", []):
			if t not in ["town", "wilds", "dungeon"]:
				errs.append("%s: unknown place type %s" % [id, t])
		for b in w.get("biomes", []):
			if not biomes.has(b):
				errs.append("%s: unknown biome %s" % [id, b])
		for p in w.get("places", []):
			if not place_ids.has(p):
				errs.append("%s: unknown place %s" % [id, p])
		if not GameData.world["locations"].any(func(l): return place_matches(ev, l)):
			errs.append("%s: matches no place" % id)
		for t in ev.get("requires", {}).get("traits", []):
			if not GameData.traits.has(t):
				errs.append("%s: unknown trait %s" % [id, t])
		var choices: Array = ev.get("choices", [])
		if choices.size() < 2 or choices.size() > 4:
			errs.append("%s: needs 2-4 choices" % id)
		if not choices.any(func(c): return c.get("requires", {}).is_empty()):
			errs.append("%s: no choice is open to everyone" % id)
		for c in choices:
			var where := "%s/%s" % [id, c.get("text", "?")]
			var r: Dictionary = c.get("requires", {})
			for t in r.get("traits", []):
				if not GameData.traits.has(t):
					errs.append("%s: unknown trait %s" % [where, t])
			for x in r.get("race", []):
				if not GameData.races.has(x):
					errs.append("%s: unknown race %s" % [where, x])
			for x in r.get("class", []):
				if not GameData.classes.has(x):
					errs.append("%s: unknown class %s" % [where, x])
			if r.has("item") and not GameData.items.has(r["item"]):
				errs.append("%s: unknown item %s" % [where, r["item"]])
			var outs: Dictionary = c.get("outcomes", {})
			if c.has("check"):
				var ch: Dictionary = c["check"]
				if not ATTR_LABELS.has(ch.get("attr", "")):
					errs.append("%s: unknown check attribute %s" % [where, ch.get("attr", "")])
				if not ch.has("dc"):
					errs.append("%s: check without dc" % where)
				for b in ch.get("bonus_if", []):
					if b.has("race") and not GameData.races.has(b["race"]):
						errs.append("%s: bonus for unknown race %s" % [where, b["race"]])
					if b.has("class") and not GameData.classes.has(b["class"]):
						errs.append("%s: bonus for unknown class %s" % [where, b["class"]])
					if b.has("trait") and not GameData.traits.has(b["trait"]):
						errs.append("%s: bonus for unknown trait %s" % [where, b["trait"]])
					if not b.has("value") or not (b.has("race") or b.has("class") or b.has("trait")):
						errs.append("%s: bonus_if needs race/class/trait and value" % where)
				if not (outs.has("success") and outs.has("failure")):
					errs.append("%s: check needs success and failure outcomes" % where)
			elif not outs.has("always"):
				errs.append("%s: needs an always outcome" % where)
			for k in outs:
				if k not in DEGREES and k != "always":
					errs.append("%s: unknown outcome %s" % [where, k])
				var o: Dictionary = outs[k]
				for key in o:
					if key not in EFFECT_KEYS:
						errs.append("%s/%s: unknown effect %s" % [where, k, key])
				if str(o.get("text", "")) == "":
					errs.append("%s/%s: outcome without text" % [where, k])
				for t in ([o["add_trait"]] if o.has("add_trait") else []) + ((o["remove_trait"] if o["remove_trait"] is Array else [o["remove_trait"]]) if o.has("remove_trait") else []):
					if not GameData.traits.has(t):
						errs.append("%s/%s: unknown trait %s" % [where, k, t])
				if o.has("item") and not GameData.items.has(o["item"]):
					errs.append("%s/%s: unknown item %s" % [where, k, o["item"]])
				if o.has("echo") and o["echo"].get("kind", "") not in ["glory", "infamy"]:
					errs.append("%s/%s: echo kind must be glory or infamy" % [where, k])
				if o.has("fight"):
					for f in o["fight"].get("foes", []):
						if not creature_ids.has(f):
							errs.append("%s/%s: unknown or boss creature %s" % [where, k, f])
	return errs
