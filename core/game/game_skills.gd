## Class skills by level, and how a class likes to fight. Every class's "skills" list in
## data/classes/classes.json grows with the heir: each entry opens at its "level" (1 when it has
## none), and the first ones, open from level 1, keep the places saves and plans index them by.
## A skill with "once" may be used once a battle. A class's "style" ({kind: martial, caster or
## hybrid, lean 0..1}) tells the autopilot which of its actions to lean on; without one it follows
## the stat of the class's first strike. The weights per kind of action live in formations.json
## (settings.bot_styles). No rendering and no rolls here.
##
## State on a GameHeir: skill_news, the ids of class skills opened since the journal last told
## them (see GameHeir.gain_xp and on_years).
class_name GameSkills
extends RefCounted

const TYPES := ["damage", "heal", "control", "buff"]
const KINDS := ["martial", "caster", "hybrid"]
const CATEGORIES := ["attack", "spell", "magic_skill", "weapon_skill", "both_skill", "feat_magic", "feat_weapon", "support"]


static func level_of(s: Dictionary) -> int:
	return int(s.get("level", 1))


static func list(class_id: String) -> Array:
	return GameData.classes.get(class_id, {}).get("skills", [])


## Whether a unit's level has opened its class skill `i`.
static func unlocked(u: GameHeir, i: int) -> bool:
	var all := list(u.class_id)
	return i >= 0 and i < all.size() and u.level >= level_of(all[i])


static func is_once(s: Dictionary) -> bool:
	return bool(s.get("once", false))


## How many skills a class has open from level 1: the ones the battle screen gives a button each.
static func first_count(class_id: String) -> int:
	var n := 0
	for s in list(class_id):
		if level_of(s) <= 1:
			n += 1
	return n


## Ids of the class skills open at `level`.
static func unlocked_ids(class_id: String, level: int) -> Array:
	return list(class_id).filter(func(s): return level_of(s) <= level).map(func(s): return str(s["id"]))


## Ids of the class skills that open after `from_level`, up to and including `to_level`.
static func between(class_id: String, from_level: int, to_level: int) -> Array:
	return list(class_id).filter(func(s): return level_of(s) > from_level and level_of(s) <= to_level).map(func(s): return str(s["id"]))


static func skill_name(class_id: String, id: String) -> String:
	for s in list(class_id):
		if str(s["id"]) == id:
			return str(s["name"])
	return id.capitalize()


## The next class skill the unit's level has yet to open: {name, level}, or {}.
static func next_unlock(u: GameHeir) -> Dictionary:
	for s in list(u.class_id):
		if level_of(s) > u.level:
			return {"name": str(s["name"]), "level": level_of(s)}
	return {}


## For the life screen: "Known: Power Strike, Second Wind." and "Next: Iron Stance at level 12,
## then Sundering Strike at 28."
static func summary_lines(h: GameHeir) -> Array:
	var known: Array = []
	var later: Array = []
	for s in list(h.class_id):
		if level_of(s) <= h.level:
			known.append(str(s["name"]))
		else:
			later.append(s)
	var out: Array = ["Known: %s." % ", ".join(known)]
	if not later.is_empty():
		var next := "Next: %s at level %s" % [later[0]["name"], GameText.num(level_of(later[0]))]
		if later.size() > 1:
			next += ", then %s at %s" % [later[1]["name"], GameText.num(level_of(later[1]))]
		out.append(next + ".")
	return out


## For the title and tavern screens: "Power Strike, Second Wind; later Sweeping Blow (5), Iron
## Stance (12), ...".
static func plan_text(class_id: String) -> String:
	var first: Array = []
	var later: Array = []
	for s in list(class_id):
		if level_of(s) <= 1:
			first.append(str(s["name"]))
		else:
			later.append("%s (%s)" % [s["name"], GameText.num(level_of(s))])
	var text := ", ".join(first)
	if not later.is_empty():
		text += "; later " + ", ".join(later)
	return text


## The journal line for skills newly opened, or "" when there are none.
static func news_text(h: GameHeir, ids: Array) -> String:
	if ids.is_empty():
		return ""
	var names: Array = ids.map(func(id): return skill_name(h.class_id, str(id)))
	return "%s can now use %s (class skill%s)." % [h.name, " and ".join(names), "" if names.size() == 1 else "s"]


## Tells the skills opened since last time, once (from GameDynasty._pass_years).
static func on_years(d: GameDynasty, msgs: Array) -> void:
	var line := news_text(d.heir, d.heir.skill_news)
	d.heir.skill_news = []
	if line != "":
		msgs.append(line)
		d._say(line)


# ---------------------------------------------------------------- style

## {kind, lean}: the class's own style, else the kind its first strike's stat suggests. `lean` is
## -1 when the data gives none (a hybrid then leans by its build; see weights).
static func style(class_id: String) -> Dictionary:
	var c: Dictionary = GameData.classes.get(class_id, {})
	var st: Dictionary = c.get("style", {})
	var kind := str(st.get("kind", ""))
	if kind == "":
		kind = "martial"
		for s in c.get("skills", []):
			if str(s.get("type", "")) == "damage":
				kind = {"mag": "caster", "both": "hybrid"}.get(str(s.get("stat", "str")), "martial")
				break
	return {"kind": kind, "lean": float(st.get("lean", -1.0))}


## How far a unit leans toward spellcraft, 0 (all steel) to 1 (all spell). A martial class is 0
## and a caster 1; a hybrid leans by its build (MAG against STR power), clamped to
## settings.bot_style_lean, and halfway toward its class's own lean when the data gives one.
static func lean(u: GameHeir, nums: Dictionary) -> float:
	var st := style(u.class_id)
	match str(st["kind"]):
		"martial":
			return 0.0
		"caster":
			return 1.0
	var span: Array = GameCombat.setting("bot_style_lean")
	var by_build := float(nums["mag"]) / maxf(0.0001, float(nums["str"]) + float(nums["mag"]))
	if float(st["lean"]) >= 0.0:
		by_build = (by_build + float(st["lean"])) * 0.5
	return clampf(by_build, float(span[0]), float(span[1]))


## The autopilot's multiplier per kind of action (CATEGORIES) and on the price of MP, for this
## unit: the martial weights, the caster weights, or a blend by lean.
static func weights(u: GameHeir, nums: Dictionary) -> Dictionary:
	var styles: Dictionary = GameCombat.setting("bot_styles")
	var m: Dictionary = styles["martial"]
	var c: Dictionary = styles["caster"]
	var t := lean(u, nums)
	var out := {}
	for k in m:
		out[k] = lerpf(float(m[k]), float(c.get(k, m[k])), t)
	if not out.has("both_skill"):   # a skill of body and spell alike: halfway, unless the data says
		out["both_skill"] = (float(out["weapon_skill"]) + float(out["magic_skill"])) * 0.5
	return out


## What kind of action a plan is (one of CATEGORIES, or "heal", "potion", "pass"): a plain blow,
## a spell, a class skill by its stat, a feat by what it scales with, or support (anything not
## aimed at a foe, and plague vials).
static func category(plan: Dictionary, _u: GameHeir = null) -> String:
	match str(plan.get("act", "attack")):
		"attack":
			return "attack"
		"potion":
			return "potion"
		"pass":
			return "pass"
	var ab: Dictionary = plan.get("ab", {})
	if ab.has("pct_max_hp"):
		return "heal"
	if str(plan.get("item", "")) != "" or not GameCombat.aims_at_foe(ab):
		return "support"
	if str(plan.get("spell", "")) != "":
		return "spell"
	if str(plan.get("feat", "")) != "":
		var sc: Dictionary = ab.get("scaling", {})
		var mag := float(sc.get("mag", 0.0))
		return "feat_magic" if mag > 0.0 and mag >= float(sc.get("str", 0.0)) + float(sc.get("agi", 0.0)) else "feat_weapon"
	match str(ab.get("stat", "str")):
		"mag":
			return "magic_skill"
		"both":
			return "both_skill"
	return "weapon_skill"


## One line on how the autopilot fights for this unit.
static func style_text(u: GameHeir) -> String:
	match str(style(u.class_id)["kind"]):
		"caster":
			return "%s fights as a caster: spells and magic first, the staff only when MP runs dry." % u.name
		"hybrid":
			return "%s fights as a %s: steel and spell by turns." % [u.name, str(u.cls().get("name", "hybrid")).to_lower()]
	return "%s fights as a fighter: weapon, class strikes and feats." % u.name


# ---------------------------------------------------------------- data checks

## The mechanics a skill carries, as tags (see validate): its area, several hits, real pierce or
## crit, drain, a bonus on the wounded, a field, mana, each status and element, a blessing's reach.
static func signature(s: Dictionary) -> Array:
	var tags: Array = []
	if GameCombat.is_aoe(s):
		tags.append("aoe:around" if GameCombat.around_self(s) else "aoe:" + GameCombat.shape(s))
	if int(s.get("hits", 1)) > 1:
		tags.append("hits")
	if float(s.get("pierce", 0.0)) >= 0.5:
		tags.append("pierce")
	if float(s.get("crit_bonus", 0.0)) >= 0.2:
		tags.append("crit")
	if float(s.get("drain", 0.0)) > 0.0:
		tags.append("drain")
	for key in [["vs_wounded", "wounded"], ["field", "field"]]:
		if s.has(key[0]):
			tags.append(key[1])
	if s.get("mana", false):
		tags.append("mana")
	for st in s.get("statuses", []):
		tags.append("status:" + str(st.get("id", "")))
	if str(s.get("element", "")) != "":
		tags.append("element:" + str(s["element"]))
	if GameCombat.shape(s) in ["self", "party"] and str(s.get("type", "")) == "buff":
		tags.append("buff:" + GameCombat.shape(s))
	tags.sort()
	return tags


## Skills a class has had from level 1 since before skills opened by level.
static func _kept(class_id: String) -> int:
	return first_count(class_id)


## Everything wrong with the class skills and styles, one line each (statuses, elements and shapes
## are GameCombat's to check). Empty when sound.
static func validate() -> Array:
	var out: Array = []
	var cap := int(GameData.bal("level_cap"))
	var marks := {}   # sorted signatures -> the class that has them
	for cid in GameData.classes:
		var c: Dictionary = GameData.classes[cid]
		var all: Array = c.get("skills", [])
		if all.size() < 5 or all.size() > 7:
			out.append("class %s has %d skills (5 to 7)" % [cid, all.size()])
		if all.is_empty():
			continue
		if str(all[0].get("type", "")) != "damage" or level_of(all[0]) != 1:
			out.append("class %s: its first skill must be a level-1 damage skill" % cid)
		var ids := {}
		var last := 1
		var heal_seen := false
		var sigs: Array = []
		for s in all:
			var id := str(s.get("id", "?"))
			var what := "class %s skill %s" % [cid, id]
			if ids.has(id):
				out.append("%s: the id is used twice" % what)
			ids[id] = true
			var lv := level_of(s)
			if lv < 1 or lv > cap:
				out.append("%s: level %d is outside 1..%d" % [what, lv, cap])
			if lv < last:
				out.append("%s: opens at level %d, before the skill above it" % [what, lv])
			last = maxi(last, lv)
			var type := str(s.get("type", ""))
			if type not in TYPES:
				out.append("%s: unknown type '%s'" % [what, type])
			var mult := float(s.get("mult", 0.0))
			match type:
				"damage", "control":
					if mult < 0.0 or (type == "damage" and mult <= 0.0):
						out.append("%s: a %s skill needs a mult%s" % [what, type, " above 0" if type == "damage" else " of 0 or more"])
					if not GameCombat.aims_at_foe(s):
						out.append("%s: a %s skill must aim at a foe" % [what, type])
					if type == "control" and (s.get("statuses", []) as Array).is_empty():
						out.append("%s: a control skill puts no status on its foes" % what)
				"heal":
					if not s.has("pct_max_hp"):
						out.append("%s: a heal needs pct_max_hp" % what)
					if not heal_seen and lv != 1:
						out.append("%s: the class's first heal must be open from level 1" % what)
					heal_seen = true
				"buff":
					if GameCombat.shape(s) not in ["self", "party"]:
						out.append("%s: a buff must have a self or party shape" % what)
					if mult > 0.0:
						out.append("%s: a buff deals no damage" % what)
					var sts: Array = s.get("statuses", [])
					if sts.is_empty() or sts.any(func(st): return str(st.get("on", "target")) not in ["self", "party"]):
						out.append("%s: a buff's statuses must all land on self or party" % what)
			if s.get("mana", false) and float(s.get("mp", 0.0)) <= 0.0 and not is_once(s):
				out.append("%s: a free mana skill must be once a battle, or it loops" % what)
			sigs.append(",".join(signature(s)))
		if not heal_seen:
			out.append("class %s has no heal" % cid)
		var st: Dictionary = c.get("style", {})
		if not st.is_empty():
			if str(st.get("kind", "")) not in KINDS:
				out.append("class %s: style kind must be one of %s" % [cid, ", ".join(KINDS)])
			if st.has("lean") and (float(st["lean"]) < 0.0 or float(st["lean"]) > 1.0):
				out.append("class %s: style lean must be within 0..1" % cid)
		sigs.sort()
		var mark := "|".join(sigs)
		if marks.has(mark):
			out.append("classes %s and %s have skills of the very same mechanics" % [marks[mark], cid])
		marks[mark] = cid
		if not c.has("parents"):
			var fresh := {}
			for k in range(_kept(cid), all.size()):
				for tag in signature(all[k]):
					fresh[tag] = true
			if fresh.size() < 5:
				out.append("class %s: its later skills carry only %d distinct mechanics (5 or more)" % [cid, fresh.size()])
	return out


## Soft checks that do not fail the data: a hybrid's later skills should borrow a mechanic from
## each parent's list.
static func warnings() -> Array:
	var out: Array = []
	for cid in GameData.classes:
		var parents: Array = GameData.classes[cid].get("parents", [])
		if parents.size() != 2:
			continue
		var mine := {}
		var all := list(cid)
		for k in range(_kept(cid), all.size()):
			for tag in signature(all[k]):
				mine[tag] = true
		for p in parents:
			var theirs := {}
			for s in list(p):
				for tag in signature(s):
					theirs[tag] = true
			if not mine.keys().any(func(t): return theirs.has(t)):
				out.append("hybrid %s: no later skill borrows a mechanic from %s" % [cid, p])
	return out
