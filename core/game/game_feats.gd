## Feats: martial techniques an heir learns with feat points and readies in a few slots. A feat is
## an ability like a class skill or a spell and runs through GameBattle's one pipeline, but it
## never costs MP: it waits out a cooldown, and a few take a share of the user's own HP. Power
## comes from STR, AGI and MAG by the feat's weights, each landing as hard as a plain blow or spell
## of that stat (trait, gear and heirloom bonuses included), raised by the tier of the weapon in
## hand (bare hands are tier 0). Most feats belong to a class (`requires.classes`): a hybrid learns
## its own and both parents' feats; a feat with no classes is open to all. Environmental feats need
## the ground the battle is fought on. Points come at level milestones and slots open at others;
## loadouts change only in a town or right after a rest. Content and tuning live in
## data/feats/feats.json.
##
## State on a GameHeir: known_feats, equipped_feats (slot order), feat_points (unspent),
## feat_level (milestones granted through this level), feat_news (milestone levels the journal has
## yet to tell), downtime (from a rest until the next action that takes time). Feats are personal:
## a new heir starts over with the points of their own level. Companions carry a loadout picked
## for their class and level at the start of each battle; it is never saved.
class_name GameFeats
extends RefCounted

const SCALING_KEYS := ["str", "agi", "mag", "weapon_tier"]
const KEYS := ["name", "kind", "description", "scaling", "mult", "target", "cooldown", "cost", "requires"]
const NEVER := ["mp", "mana", "pct_max_hp", "party", "cleanse", "group", "learn"]   # spell and healing keys
const STATUS_KEYS := ["name", "tag", "color", "stack", "basis", "default_turns", "default_potency", "text"]
const SETTING_KEYS := ["start_points", "point_levels", "slot_levels", "companion_slots", "recovery_turns", "bot_targets",
	"bot_status_worth", "bot_party_worth", "bot_min_score", "bot_hp_cost_worth", "bot_taunt_min_hp"]

static var _src: Dictionary = {}
static var _defs: Dictionary = {}
static var _order: Array = []
static var _item_kind: Dictionary = {}   # weapon item id -> weapon kind
static var _worth: Dictionary = {}       # feat id -> what score() needs that no unit changes (see _worth_of)
static var _hirelings: Dictionary = {}   # what a companion of a given make carries on given ground


static func _index() -> void:
	if not _src.is_empty() and is_same(_src, GameData.feats):
		return
	GameData.load_all()
	if is_same(_src, GameData.feats):
		return
	_src = GameData.feats
	_defs.clear()
	_order.clear()
	for f in _src.get("feats", []):
		# The definition is the ability the battle resolves; its power is read under this stat.
		f["stat"] = "feat:" + str(f["id"])
		f["feat"] = str(f["id"])
		_defs[str(f["id"])] = f
		_order.append(str(f["id"]))
	_item_kind.clear()
	var kinds: Dictionary = _src.get("weapon_kinds", {})
	for k in kinds:
		for item in kinds[k].get("items", []):
			_item_kind[str(item)] = str(k)
	GameCombat.add_statuses(_src.get("statuses", []))
	_worth.clear()
	_hirelings.clear()
	for id in _order:
		_worth[id] = _worth_of(_defs[id])


## Reads the feat data again after it was changed in place (tools and tests), and the autopilot's
## weights (bot_* in the settings) after they were.
static func reindex() -> void:
	_src = {}
	_index()


## The live settings table (tests and harnesses may override values in it).
static func settings() -> Dictionary:
	_index()
	return _src.get("settings", {})


static func setting(key: String) -> Variant:
	return settings()[key]


static func def(id: String) -> Dictionary:
	_index()
	return _defs.get(id, {})


static func ids() -> Array:
	_index()
	return _order.duplicate()


static func feat_name(id: String) -> String:
	return str(def(id).get("name", id))


static func kind_info(kind: String) -> Dictionary:
	_index()
	return _src.get("kinds", {}).get(kind, {})


static func requires(id: String) -> Dictionary:
	return def(id).get("requires", {})


static func cooldown(id: String) -> int:
	return int(def(id).get("cooldown", 0))


static func cost(id: String) -> int:
	return int(def(id).get("cost", 1))


# ---------------------------------------------------------------- weapons and power

## The kind of weapon an item is ("blade", "bow"...), or "" for bare hands and anything unlisted.
static func weapon_kind(item_id: String) -> String:
	_index()
	return str(_item_kind.get(item_id, ""))


static func held_weapon(u: GameHeir) -> String:
	return str(u.equipment.get("weapon", ""))


## Tier of the weapon in hand; bare hands are tier 0.
static func weapon_tier(u: GameHeir) -> int:
	var id := held_weapon(u)
	return 0 if id == "" else int(GameItems.item_def(id).get("tier", 0))


## "a bow", "a blade or mace" for a list of weapon kinds.
static func weapon_text(kinds: Array) -> String:
	_index()
	var nouns: Array = kinds.map(func(k): return str(_src.get("weapon_kinds", {}).get(k, {}).get("noun", k)))
	if nouns.is_empty():
		return ""
	var s: String = nouns[0] if nouns.size() == 1 else "%s or %s" % [", ".join(PackedStringArray(nouns.slice(0, -1))), nouns[-1]]
	return ("an " if s.left(1) in ["a", "e", "i", "o", "u"] else "a ") + s


## What one unit brings to every feat, worked out once: a plain blow's power, that power per point
## of STR (so AGI is weighed the same way), AGI, a spell's power (for MAG), the weapon's tier, and
## the unit's best blow.
static func numbers(u: GameHeir) -> Dictionary:
	var atk := u.attack_power()
	var mag := u.magic_power()
	return {"atk": atk, "per": atk / maxf(0.0001, u.stat("str")), "agi": u.stat("agi"), "mag": mag, "tier": weapon_tier(u),
		"best": maxf(atk, mag)}


static func _power(n: Dictionary, f: Dictionary) -> float:
	var sc: Dictionary = f.get("scaling", {})
	var p := float(n["atk"]) * float(sc.get("str", 0.0)) + float(n["per"]) * float(n["agi"]) * float(sc.get("agi", 0.0)) \
		+ float(n.get("mag", 0.0)) * float(sc.get("mag", 0.0))
	return p * (1.0 + float(sc.get("weapon_tier", 0.0)) * float(n["tier"]))


## A feat's power for a unit: STR, AGI and MAG by the feat's weights, raised by the weapon's tier.
static func power(u: GameHeir, id: String) -> float:
	return _power(numbers(u), def(id))


## The same from numbers() already worked out for the unit.
static func power_with(n: Dictionary, id: String) -> float:
	return _power(n, def(id))


## HP one use costs: a share of max HP, at least 1 for a feat that has a cost at all.
static func hp_cost(u: GameHeir, id: String, max_hp: int = -1) -> int:
	var share := float(def(id).get("hp_cost", 0.0))
	if share <= 0.0:
		return 0
	return maxi(1, int(ceil(float(max_hp if max_hp >= 0 else u.max_hp()) * share)))


static func terrain_ok(id: String, biomes: Array) -> bool:
	return _on_ground(requires(id).get("biomes", []), biomes)


static func _on_ground(need: Array, biomes: Array) -> bool:
	if need.is_empty():
		return true
	for b in need:
		if b in biomes:
			return true
	return false


# ---------------------------------------------------------------- points and slots

## Feat points an heir has been granted by `level`: the starting points, then one per milestone.
static func points_at(level: int) -> int:
	if level < 1:
		return 0
	var n := int(setting("start_points"))
	for lv in setting("point_levels"):
		if int(lv) > level:
			break
		n += 1
	return n


## How many feats an heir of `level` can have readied at once.
static func slots_at(level: int) -> int:
	var n := 0
	for s in setting("slot_levels"):
		if int(s[0]) <= level:
			n = maxi(n, int(s[1]))
	return n


static func slots(h: GameHeir) -> int:
	return slots_at(h.level)


## The next level after `level` that brings a feat point, or -1 past the last.
static func next_point_level(level: int) -> int:
	for lv in setting("point_levels"):
		if int(lv) > level:
			return int(lv)
	return -1


## The next [level, slots] after `level` that opens a slot, or [] past the last.
static func next_slot(level: int) -> Array:
	for s in setting("slot_levels"):
		if int(s[0]) > level:
			return [int(s[0]), int(s[1])]
	return []


static func _is_point_level(lv: int) -> bool:
	for p in setting("point_levels"):
		if int(p) == lv:
			return true
	return false


## A new heir: nothing learned, the points of their own level. Feats are not inherited.
static func start(h: GameHeir) -> void:
	h.known_feats = []
	h.equipped_feats = []
	h.feat_points = points_at(h.level)
	h.feat_level = h.level
	h.feat_news = []
	h.downtime = false


## Grants the points of every milestone between the last one granted and the heir's level, and
## keeps the milestones passed for the journal (an heir's first points are no news). Returns the
## points granted.
static func sync(h: GameHeir) -> int:
	if h.feat_level >= h.level:
		return 0
	var before := h.feat_level
	var got := points_at(h.level) - points_at(before)
	h.feat_points += got
	if before >= 1:
		var marks := {}
		for p in setting("point_levels"):
			if int(p) > before and int(p) <= h.level:
				marks[int(p)] = true
		for s in setting("slot_levels"):
			if int(s[0]) > before and int(s[0]) <= h.level:
				marks[int(s[0])] = true
		var ms: Array = marks.keys()
		ms.sort()
		h.feat_news.append_array(ms)
	h.feat_level = h.level
	return got


static func points(h: GameHeir) -> int:
	sync(h)
	return h.feat_points


## "Tess earns a feat point and can now ready 3 feats (2 to spend)." for the milestones in `news`.
static func news_text(h: GameHeir, news: Array) -> String:
	var pts := 0
	var slot := 0
	for lv in news:
		if _is_point_level(int(lv)):
			pts += 1
		slot = maxi(slot, slots_at(int(lv)) if slots_at(int(lv)) > slots_at(int(lv) - 1) else 0)
	var parts: Array = []
	if pts > 0:
		parts.append("earns %s" % ("a feat point" if pts == 1 else "%d feat points" % pts))
	if slot > 0:
		parts.append("can now ready %d feats" % slot)
	if parts.is_empty():
		return ""
	return "%s %s (%s to spend)." % [h.name, " and ".join(PackedStringArray(parts)), GameText.num(h.feat_points)]


## "With the old drills set aside, Tess forgets Cleave and Flurry, which no Mage is taught (2 feat
## points back)." for the feats a loaded save knew that the heir's class is not taught.
static func forgot_text(h: GameHeir, names: Array, back: int) -> String:
	var list: String = names[0] if names.size() == 1 else "%s and %s" % [", ".join(PackedStringArray(names.slice(0, -1))), names[-1]]
	return "With the old drills set aside, %s forgets %s, which no %s is taught (%s feat point%s back)." % [h.name, list,
		str(GameData.classes.get(h.class_id, {}).get("name", h.class_id)), GameText.num(back), "" if back == 1 else "s"]


## Time passes: the quiet after a rest is over, the feats a loaded save's class is not taught are
## told forgotten (once), and feat milestones reached are told.
static func on_years(d: GameDynasty, msgs: Array) -> void:
	var h := d.heir
	h.downtime = false
	if h.has_meta("feat_forgot"):
		var f: Dictionary = h.get_meta("feat_forgot")
		h.remove_meta("feat_forgot")
		var note := forgot_text(h, f["names"], int(f["points"]))
		msgs.append(note)
		d._say(note)
	sync(h)
	if h.feat_news.is_empty():
		return
	var line := news_text(h, h.feat_news)
	h.feat_news = []
	if line != "":
		msgs.append(line)
		d._say(line)


# ---------------------------------------------------------------- requirements

## "Warrior, Paladin or Cleric".
static func classes_text(classes: Array) -> String:
	var names: Array = classes.map(func(c): return str(GameData.classes.get(c, {}).get("name", c)))
	if names.size() <= 1:
		return "".join(PackedStringArray(names))
	return "%s or %s" % [", ".join(PackedStringArray(names.slice(0, -1))), names[-1]]


## Whether a class may learn a feat taught to `classes`: one of them, or a hybrid with a parent
## among them. An empty list is open to every class.
static func _class_ok(class_id: String, classes: Array) -> bool:
	if classes.is_empty() or class_id in classes:
		return true
	for p in GameData.classes.get(class_id, {}).get("parents", []):
		if p in classes:
			return true
	return false


## Whether a class may ever learn a feat (level, weapon and ground aside).
static func class_may(class_id: String, id: String) -> bool:
	return _class_ok(class_id, requires(id).get("classes", []))


## The feats a class is taught as its own (a hybrid: its own and both parents'), in data order.
static func class_feats(class_id: String) -> Array:
	_index()
	return _order.filter(func(id): return not (requires(id).get("classes", []) as Array).is_empty() and class_may(class_id, id))


## The feats open to every class, the ground's own among them.
static func universal_feats() -> Array:
	_index()
	return _order.filter(func(id): return (requires(id).get("classes", []) as Array).is_empty())


## A hybrid's class feats told apart by where they come from: those that list the class itself
## (`from` == class_id), or those it has only through the parent `from`.
static func feats_from(class_id: String, from: String) -> Array:
	var out: Array = []
	for id in class_feats(class_id):
		var cs: Array = requires(id).get("classes", [])
		if (class_id in cs) if from == class_id else (from in cs and class_id not in cs):
			out.append(id)
	return out


## "Rime Strike at level 8": the heir's next class feat by level, or "" when none is left.
static func next_class_feat(h: GameHeir) -> String:
	var best := ""
	var at := 0
	for id in class_feats(h.class_id):
		var lv := int(requires(id).get("min_level", 1))
		if lv > h.level and id not in h.known_feats and (best == "" or lv < at):
			best = id
			at = lv
	return "" if best == "" else "%s at level %s" % [feat_name(best), GameText.num(at)]


## Level, class and weapon: what a feat asks of whoever learns or readies it ("" when met).
static func requirement_block(h: GameHeir, id: String) -> String:
	var why := rank_block(h, id)
	if why != "":
		return why
	var kinds: Array = requires(id).get("weapon", [])
	if not kinds.is_empty() and weapon_kind(held_weapon(h)) not in kinds:
		return "Needs %s in hand." % weapon_text(kinds)
	return ""


## The part of requirement_block that only the heir's own making decides: level and class.
static func rank_block(h: GameHeir, id: String) -> String:
	var req := requires(id)
	if h.level < int(req.get("min_level", 1)):
		return "Needs level %s." % GameText.num(int(req.get("min_level", 1)))
	var classes: Array = req.get("classes", [])
	if not _class_ok(h.class_id, classes):
		return "Taught only to a %s." % classes_text(classes)
	return ""


## Every requirement in short: ["Level 12", "A bow in hand", "Warrior or Paladin", "Only on ..."].
static func requirement_parts(id: String) -> Array:
	var req := requires(id)
	var out: Array = ["Level %s" % GameText.num(int(req.get("min_level", 1)))]
	if not (req.get("weapon", []) as Array).is_empty():
		var w := weapon_text(req["weapon"])
		out.append("%s in hand" % (w.left(1).to_upper() + w.substr(1)))
	if not (req.get("classes", []) as Array).is_empty():
		out.append(classes_text(req["classes"]))
	if not (req.get("biomes", []) as Array).is_empty():
		out.append("Only on %s" % str(def(id).get("terrain", ", ".join(PackedStringArray(req["biomes"])))))
	return out


## Why a unit cannot use a readied feat in a battle fought on `biomes` ("" if it can): the weapon
## in hand, the ground, and the HP a costly feat takes, which must leave the user standing.
static func use_block(u: GameHeir, id: String, biomes: Array, max_hp: int = -1) -> String:
	var why := gear_block(u, id, biomes)
	return why if why != "" else hurt_block(u, id, max_hp)


## The part of use_block that holds for a whole battle: the weapon in hand and the ground.
static func gear_block(u: GameHeir, id: String, biomes: Array) -> String:
	var f := def(id)
	if f.is_empty():
		return "No such feat."
	var kinds: Array = f.get("requires", {}).get("weapon", [])
	if not kinds.is_empty() and weapon_kind(held_weapon(u)) not in kinds:
		return "Needs %s in hand." % weapon_text(kinds)
	if not terrain_ok(id, biomes):
		return "Needs %s." % str(f.get("terrain", "other ground"))
	return ""


## The part that changes blow by blow: too hurt to pay the HP a feat takes.
static func hurt_block(u: GameHeir, id: String, max_hp: int = -1) -> String:
	var hp := hp_cost(u, id, max_hp)
	if hp > 0 and u.hp <= hp:
		return "Too hurt: it costs %s HP." % GameText.num(hp)
	return ""


# ---------------------------------------------------------------- loadout

## Why feats cannot be learned or readied right now ("" if they can): only in a town or in the
## quiet right after a rest, and never in the middle of a fight.
static func manage_block(d: GameDynasty) -> String:
	if d.state != "life":
		return "Only a living heir can train feats."
	if d.battle != null:
		return "Not in the middle of a fight."
	if d.world.is_town() or d.heir.downtime:
		return ""
	return "%s is no place to drill feats. Change them in a town or right after a rest." % d.world.here().get("name", "This")


## Why the heir cannot learn a feat, wherever they stand ("" if they can).
static func learn_block(h: GameHeir, id: String) -> String:
	var f := def(id)
	if f.is_empty():
		return "No such feat."
	if id in h.known_feats:
		return "%s already knows %s." % [h.name, f["name"]]
	var why := requirement_block(h, id)
	if why != "":
		return why
	if points(h) < cost(id):
		return "%s costs %d feat point%s; %s has %s." % [f["name"], cost(id), "" if cost(id) == 1 else "s", h.name, GameText.num(h.feat_points)]
	return ""


## Why the heir cannot ready a feat they know ("" if they can).
static func equip_block(h: GameHeir, id: String) -> String:
	var f := def(id)
	if f.is_empty():
		return "No such feat."
	if id not in h.known_feats:
		return "%s has not learned %s." % [h.name, f["name"]]
	if id in h.equipped_feats:
		return "%s is already readied." % f["name"]
	if h.equipped_feats.size() >= slots(h):
		return "All %d feat slots are full. Set one aside first." % slots(h)
	return requirement_block(h, id)


## Learns a feat for its points and readies it if a slot is free. Returns the journal line, or
## why it could not be done (nothing changes then).
static func learn(d: GameDynasty, id: String) -> String:
	var h := d.heir
	var why := manage_block(d)
	if why == "":
		why = learn_block(h, id)
	if why != "":
		return why
	h.feat_points -= cost(id)
	h.known_feats.append(id)
	var readied := equip_block(h, id) == ""
	if readied:
		h.equipped_feats.append(id)
	var text := "%s learns %s%s (%s feat point%s left)." % [h.name, feat_name(id), " and readies it" if readied else "",
		GameText.num(h.feat_points), "" if h.feat_points == 1 else "s"]
	d._say(text)
	return text


## Readies a known feat in the next free slot. Returns the journal line or why not.
static func equip(d: GameDynasty, id: String) -> String:
	var why := manage_block(d)
	if why == "":
		why = equip_block(d.heir, id)
	if why != "":
		return why
	d.heir.equipped_feats.append(id)
	var text := "%s readies %s." % [d.heir.name, feat_name(id)]
	d._say(text)
	return text


## Sets a readied feat aside; it stays learned. Returns the journal line or why not.
static func unequip(d: GameDynasty, id: String) -> String:
	var why := manage_block(d)
	if why != "":
		return why
	if def(id).is_empty():
		return "No such feat."
	if id not in d.heir.equipped_feats:
		return "%s is not readied." % feat_name(id)
	d.heir.equipped_feats.erase(id)
	var text := "%s sets %s aside." % [d.heir.name, feat_name(id)]
	d._say(text)
	return text


## A saved loadout read back into `h`: feats that still exist, readied ones among those known, of
## the heir's level and class (the data may have changed since), and no more than the slots allow.
## A known feat the heir's class is not taught (saves from before feats were bound to classes) is
## forgotten and its points given back, and the journal tells it at the next passing of time; one
## above the heir's level stays known. A save from before feats grants the points of the heir's level.
static func load_into(h: GameHeir, v: Dictionary) -> void:
	if not v.has("feat_points"):
		start(h)
		return
	h.known_feats = []
	var forgot: Array = []
	var back := 0
	for id in v.get("known_feats", []):
		var fid := str(id)
		if def(fid).is_empty() or fid in h.known_feats or fid in forgot:
			continue
		if not class_may(h.class_id, fid):
			forgot.append(fid)
			back += cost(fid)
			continue
		h.known_feats.append(fid)
	h.equipped_feats = []
	for id in v.get("equipped_feats", []):
		if str(id) in h.known_feats and str(id) not in h.equipped_feats and h.equipped_feats.size() < slots(h) and rank_block(h, str(id)) == "":
			h.equipped_feats.append(str(id))
	h.feat_points = int(v.get("feat_points", 0)) + back
	if not forgot.is_empty():
		h.set_meta("feat_forgot", {"names": forgot.map(func(id): return feat_name(id)), "points": back})
	elif h.has_meta("feat_forgot"):
		h.remove_meta("feat_forgot")
	h.feat_level = int(v.get("feat_level", h.level))
	h.feat_news = Array(v.get("feat_news", [])).map(func(x): return int(x))
	h.downtime = bool(v.get("downtime", false))


# ---------------------------------------------------------------- text

static func _num(v: float) -> String:
	return str(int(v)) if v == floorf(v) else String.num(v, 2)


static func _pct(v: float) -> String:
	return "%d%%" % int(round(v * 100.0))


## "STR x1, weapon +8% a tier" for a feat's weights.
static func scaling_text(id: String) -> String:
	var sc: Dictionary = def(id).get("scaling", {})
	var parts: Array = []
	for k in ["str", "agi", "mag"]:
		if float(sc.get(k, 0.0)) > 0.0:
			parts.append("%s x%s" % [k.to_upper(), _num(float(sc[k]))])
	if float(sc.get("weapon_tier", 0.0)) > 0.0:
		parts.append("weapon +%s a tier" % _pct(float(sc["weapon_tier"])))
	return ", ".join(PackedStringArray(parts))


## What a party or self effect does, from its status: "the party: +25% damage (3 turns)".
static func _boon_text(st: Dictionary) -> String:
	var sd := GameCombat.status_def(str(st["id"]))
	var pot := float(st.get("potency", sd.get("default_potency", 0.0)))
	var parts: Array = []
	if sd.get("draws", false):
		parts.append("every foe comes for you")
	if sd.get("absorb", false):
		parts.append("a ward of %s max HP" % _pct(pot))
	var mods: Dictionary = sd.get("mods", {})
	var words := {"damage_dealt": "damage", "damage_taken": "damage taken", "dodge": "dodge", "crit": "crit"}
	for key in words:
		if mods.has(key):
			var v := float(mods[key]) * pot
			parts.append("%s%s %s" % ["+" if v >= 0.0 else "-", _pct(absf(v)), words[key]])
	var turns := int(st.get("turns", sd.get("default_turns", 1)))
	var who := "the party: " if str(st.get("on", "")) == "party" else ""
	return "%s%s (%d turn%s)" % [who, ", ".join(PackedStringArray(parts)), turns, "" if turns == 1 else "s"]


## One line on what a feat does: damage and area, effects, and its price in turns and HP.
static func describe(id: String) -> String:
	var f := def(id)
	if f.is_empty():
		return ""
	var parts: Array = []
	var strike := f.duplicate()
	strike.erase("statuses")
	var dmg := GameCombat.describe(strike)
	if dmg != "":
		parts.append(dmg)
	var w: Dictionary = f.get("vs_wounded", {})
	if not w.is_empty():
		parts.append("x%s on a foe under %s HP" % [_num(float(w["mult"]) * float(f.get("mult", 1.0))), _pct(float(w["below"]))])
	if float(f.get("crit_bonus", 0.0)) > 0.0:
		parts.append("+%s crit chance" % _pct(float(f["crit_bonus"])))
	if float(f.get("pierce", 0.0)) > 0.0:
		parts.append("ignores %s of armour" % _pct(float(f["pierce"])))
	var foes: Array = []
	for st in f.get("statuses", []):
		if str(st.get("on", "target")) == "target":
			foes.append(st)
		else:
			parts.append(_boon_text(st))
	if not foes.is_empty():
		var who := " on every foe" if GameCombat.shape(f) == "all" and float(f.get("mult", 0.0)) <= 0.0 else ""
		parts.append(GameCombat.describe({"statuses": foes}).to_lower() + who)
	if f.has("field"):
		var stay := int(f["field"].get("turns", 1))
		parts.append("the ground holds it %d more turn%s" % [stay, "" if stay == 1 else "s"])
	parts.append("ready again after %d turn%s" % [cooldown(id), "" if cooldown(id) == 1 else "s"] if cooldown(id) > 0 else "no wait")
	if float(f.get("hp_cost", 0.0)) > 0.0:
		parts.append("costs %s of max HP" % _pct(float(f["hp_cost"])))
	var s := ", ".join(PackedStringArray(parts))
	return s if s.begins_with("x") else s.left(1).to_upper() + s.substr(1)


## "Burst 4.5", "Around 10.5", "Party" for a feat's area.
static func shape_text(id: String) -> String:
	return GameCombat.shape_text(def(id))


# ---------------------------------------------------------------- companions and the autopilot

## What a feat is worth to a unit for each turn of its cooldown, measured in the unit's own best
## blow (STR or MAG, whichever hits harder): one use is its damage over the foes its shape usually
## catches plus flat worths for its statuses, less the plain blow it takes the place of (a feat is
## free, so it stands in for the free blow: a caster's staff, not a spell) and the HP it costs.
## Below zero, a plain blow does better. A feat for other ground is worth nothing. So is,
## to a companion, a feat that strikes no one (rallies and taunts are the heir's to call) or one
## the data keeps from hirelings. A class's own feat counts bot_class_worth times over, so at equal
## power the autopilot takes up its class's craft before what any class may learn. `party` counts
## the heir and companions.
static func score(n: Dictionary, id: String, biomes: Array, party: int = 1, companion: bool = false) -> float:
	_index()
	var r: Dictionary = _worth.get(id, {})
	if r.is_empty() or (companion and not r["hireling"]) or not _on_ground(r["biomes"], biomes):
		return 0.0
	var use := float(r["foes"]) * float(r["reach"]) + float(r["self"])
	if float(r["party"]) > 0.0:
		use += float(r["party"]) * (1.0 + float(party - 1) * float(setting("bot_party_worth")))
	if float(r["hit"]) > 0.0:
		use += _power(n, _defs[id]) * float(r["hit"]) / maxf(1.0, float(n["best"])) * float(r["reach"])
	var blow := float(n["atk"]) / maxf(1.0, float(n["best"]))
	var s := (use - blow - float(r["price"])) / float(r["wait"])
	return s * float(settings().get("bot_class_worth", 1.0)) if s > 0.0 and r["classed"] else s


## What score() needs of a feat that no unit changes: the foes its shape usually catches, its blow
## per point of power (a foe spends about `below` of its life wounded, for Execute), the worth of
## its statuses by whom they land on, the price of the HP it takes and the turns of its cycle.
static func _worth_of(f: Dictionary) -> Dictionary:
	var s: Dictionary = _src.get("settings", {})
	var worth: Dictionary = s.get("bot_status_worth", {})
	var hit := float(f.get("mult", 0.0)) * float(f.get("hits", 1)) * (1.0 + float(f.get("crit_bonus", 0.0)) * 0.75)
	var w: Dictionary = f.get("vs_wounded", {})
	if not w.is_empty():
		hit *= 1.0 + (float(w.get("mult", 1.0)) - 1.0) * float(w.get("below", 0.0))
	var on := {"target": 0.0, "party": 0.0, "self": 0.0}
	for st in f.get("statuses", []):
		var who := str(st.get("on", "target"))
		on[who] = float(on.get(who, 0.0)) + float(worth.get(str(st.get("id", "")), 0.1)) * float(st.get("chance", 1.0))
	return {"reach": float(s.get("bot_targets", {}).get("around" if GameCombat.around_self(f) else GameCombat.shape(f), 1.0)),
		"hit": hit, "foes": on["target"], "party": on["party"], "self": on["self"],
		"price": float(f.get("hp_cost", 0.0)) * float(s.get("bot_hp_cost_worth", 0.0)),
		"wait": float(1 + int(f.get("cooldown", 0))), "biomes": f.get("requires", {}).get("biomes", []),
		"classed": not (f.get("requires", {}).get("classes", []) as Array).is_empty(),
		"hireling": f.get("companion", true) is bool and f.get("companion", true) and float(f.get("mult", 0.0)) > 0.0}


## The best feats a unit can use here, best first: known ones only if `known_only`, else any it
## meets the requirements for. Ties keep the data's order.
static func ranked(u: GameHeir, biomes: Array, party: int, companion: bool, known_only: bool) -> Array:
	var n := numbers(u)
	var least := float(setting("bot_min_score"))
	var picks: Array = []
	for k in _order.size():
		var id: String = _order[k]
		if known_only and id not in u.known_feats:
			continue
		var s := score(n, id, biomes, party, companion)
		if s >= least and requirement_block(u, id) == "":
			picks.append([id, s, k])
	picks.sort_custom(func(a, b): return float(a[1]) > float(b[1]) or (float(a[1]) == float(b[1]) and int(a[2]) < int(b[2])))
	return picks.map(func(p): return p[0])


## A companion's loadout for one battle: the blows a fighter of its class and level would carry on
## this ground, as many as its level has slots for but at most companion_slots. Companions bring
## no gear of the house, so they fight bare-handed and take no feat that asks for a weapon. Their
## make (class, race, level, generation, power) and the ground decide it, so it is worked out once.
static func ready_companion(u: GameHeir, biomes: Array, party: int) -> void:
	_index()
	var room := mini(slots_at(u.level), int(setting("companion_slots")))
	var picks: Array = []
	if room > 0:
		var key := [u.class_id, u.race_id, u.level, u.gen, u.archetype_bonus, biomes, party, room, setting("bot_min_score")].duplicate(true)
		if not _hirelings.has(key):
			if _hirelings.size() > 512:
				_hirelings.clear()
			_hirelings[key] = ranked(u, biomes, party, true, false).slice(0, room)
		picks = _hirelings[key]
	u.known_feats = picks.duplicate()
	u.equipped_feats = picks.duplicate()


## The autopilot's feat errands whenever loadouts may change: learn the feats that would be its
## best few where it stands (its own STR, AGI and weapon decide), then ready the best it knows.
## Nothing changes while nothing they depend on does, so an unchanged heir is not weighed again.
static func bot_tick(d: GameDynasty) -> void:
	if manage_block(d) != "":
		return
	var h := d.heir
	sync(h)
	var biomes: Array = d.world.here().get("biomes", [])
	var party := 1 + d.party.members.size()
	if h.has_meta("feat_bot") and h.get_meta("feat_bot") == _bot_key(h, biomes, party):
		return
	var n := slots(h)
	for id in ranked(h, biomes, party, false, false).slice(0, n):
		if id not in h.known_feats and learn_block(h, id) == "":
			learn(d, id)
	var best: Array = ranked(h, biomes, party, false, true).slice(0, n)
	if best != h.equipped_feats:
		h.equipped_feats = best
	h.set_meta("feat_bot", _bot_key(h, biomes, party).duplicate(true))


## Everything the autopilot's choice of feats depends on (live; duplicate it to keep it).
static func _bot_key(h: GameHeir, biomes: Array, party: int) -> Array:
	return [h.class_id, h.level, h.feat_points, h.equipment, h.training, h.traits, h.diseases, h.heirloom_bonus, h.known_feats, h.equipped_feats, biomes, party,
		h.tree_ranks, h.tree_free]


# ---------------------------------------------------------------- checks

## Everything wrong with the feat data, one readable line each; empty when it is sound.
static func validate() -> Array:
	_index()
	var out: Array = []
	var s := settings()
	for key in SETTING_KEYS:
		if not s.has(key):
			out.append("settings has no %s" % key)
	if not out.is_empty():
		return out
	var cap := int(GameData.bal("level_cap"))
	var last := 1
	for lv in s["point_levels"]:
		if int(lv) <= last or int(lv) > cap:
			out.append("settings.point_levels must rise from 2 to the level cap (%s after %d)" % [str(lv), last])
		last = int(lv)
	last = 0
	var most := 0
	for sl in s["slot_levels"]:
		if typeof(sl) != TYPE_ARRAY or (sl as Array).size() != 2 or int(sl[0]) <= last or int(sl[1]) <= most:
			out.append("settings.slot_levels must be [level, slots] pairs, both rising: %s" % str(sl))
		else:
			last = int(sl[0])
			most = int(sl[1])
	if (s["slot_levels"] as Array).is_empty() or typeof(s["slot_levels"][0]) != TYPE_ARRAY or int(s["slot_levels"][0][0]) != 1:
		out.append("settings.slot_levels must open the first slots at level 1")
	if int(s["start_points"]) < 1:
		out.append("settings.start_points must give a new heir at least one point")
	var kinds: Dictionary = _src.get("kinds", {})
	var wk: Dictionary = _src.get("weapon_kinds", {})
	var biomes := {}
	for l in GameData.world["locations"]:
		for b in l.get("biomes", []):
			biomes[b] = true
	var seen := {}
	for f in _src.get("feats", []):
		var id := str(f.get("id", ""))
		if seen.has(id):
			out.append("feat %s is defined twice" % id)
		seen[id] = true
		for key in KEYS:
			if not f.has(key):
				out.append("feat %s has no %s" % [id, key])
		for key in NEVER:
			if f.has(key):
				out.append("feat %s: a feat never uses '%s'" % [id, key])
		if str(f.get("name", "")) == "" or str(f.get("description", "")) == "":
			out.append("feat %s needs a name and a description" % id)
		if not kinds.has(str(f.get("kind", ""))):
			out.append("feat %s: unknown kind '%s'" % [id, f.get("kind", "")])
		var sc: Dictionary = f.get("scaling", {})
		for k in sc:
			if k not in SCALING_KEYS or float(sc[k]) < 0.0:
				out.append("feat %s: scaling '%s' must be one of str, agi, mag, weapon_tier and not negative" % [id, k])
		var mult := float(f.get("mult", 0.0))
		if mult > 0.0 and float(sc.get("str", 0.0)) + float(sc.get("agi", 0.0)) + float(sc.get("mag", 0.0)) <= 0.0:
			out.append("feat %s deals damage but scales with none of STR, AGI or MAG" % id)
		if float(sc.get("mag", 0.0)) > 0.0 and str(f.get("kind", "")) == "environmental":
			out.append("feat %s: the ground's feats are worked with the body; MAG has no part in them" % id)
		if f.has("drain") and (float(f["drain"]) <= 0.0 or float(f["drain"]) > 1.0 or mult <= 0.0):
			out.append("feat %s: drain is a share of the damage dealt, above 0 and at most 1" % id)
		if mult <= 0.0 and (f.get("statuses", []) as Array).is_empty():
			out.append("feat %s does nothing: no damage and no statuses" % id)
		if mult > 0.0 and not GameCombat.aims_at_foe(f):
			out.append("feat %s deals damage but is not aimed at a foe" % id)
		if int(f.get("cost", 0)) < 1 or int(f.get("cooldown", -1)) < 0:
			out.append("feat %s: cost must be at least 1 point and cooldown at least 0 turns" % id)
		if float(f.get("hp_cost", 0.0)) < 0.0 or float(f.get("hp_cost", 0.0)) > 0.5:
			out.append("feat %s: hp_cost is a share of max HP from 0 to 0.5" % id)
		if f.has("companion") and typeof(f["companion"]) != TYPE_BOOL:
			out.append("feat %s: companion is true or false" % id)
		out.append_array(GameCombat._ability_problems("feat " + id, f))
		var t: Dictionary = f.get("target", {})
		if t.has("center") and (str(t["center"]) != "self" or GameCombat.shape(f) != "burst"):
			out.append("feat %s: only a burst can be centred, and only on 'self'" % id)
		var w: Dictionary = f.get("vs_wounded", {})
		if not w.is_empty() and (float(w.get("below", 0.0)) <= 0.0 or float(w.get("below", 0.0)) >= 1.0 or float(w.get("mult", 0.0)) <= 1.0):
			out.append("feat %s: vs_wounded needs below between 0 and 1 and mult above 1" % id)
		var aimed := GameCombat.aims_at_foe(f)
		for st in f.get("statuses", []):
			var on := str(st.get("on", "target"))
			if on not in ["target", "party", "self"]:
				out.append("feat %s: status %s is on '%s' (target, party or self)" % [id, st.get("id", ""), on])
			elif (on == "target") != aimed:
				out.append("feat %s: status %s on %s does not fit its %s shape" % [id, st.get("id", ""), on, GameCombat.shape(f)])
		if f.has("field"):
			var field = f["field"]
			var foe_statuses := (f.get("statuses", []) as Array).filter(func(st): return str(st.get("on", "target")) == "target")
			if typeof(field) != TYPE_DICTIONARY or GameCombat.shape(f) != "burst" or foe_statuses.is_empty():
				out.append("feat %s: a field is left by a burst with statuses on foes" % id)
			elif int(field.get("turns", 0)) < 1 or int(field.get("turns", 0)) > int(GameCombat.setting("status_turns_max")):
				out.append("feat %s: a field lasts from 1 to %d turns" % [id, int(GameCombat.setting("status_turns_max"))])
		var req: Dictionary = f.get("requires", {})
		if int(req.get("min_level", 0)) < 1 or int(req.get("min_level", 0)) > cap:
			out.append("feat %s: min_level must be from 1 to the level cap" % id)
		for c in req.get("classes", []):
			if not GameData.classes.has(c):
				out.append("feat %s: unknown class '%s'" % [id, c])
		for k in req.get("weapon", []):
			if not wk.has(k):
				out.append("feat %s: unknown weapon kind '%s'" % [id, k])
		for b in req.get("biomes", []):
			if not biomes.has(b):
				out.append("feat %s: no place in the world has the biome '%s'" % [id, b])
		var env := str(f.get("kind", "")) == "environmental"
		if env != not (req.get("biomes", []) as Array).is_empty():
			out.append("feat %s: environmental feats, and only they, need biomes" % id)
		if env and str(f.get("terrain", "")) == "":
			out.append("feat %s: an environmental feat names its ground in 'terrain'" % id)
	out.append_array(_class_problems())
	var kinded := {}
	for k in wk:
		if str(wk[k].get("noun", "")) == "":
			out.append("weapon kind %s has no noun" % k)
		for item in wk[k].get("items", []):
			if GameItems.slot_of(str(item)) != "weapon":
				out.append("weapon kind %s lists '%s', which is not a weapon" % [k, item])
			if kinded.has(item):
				out.append("weapon %s is listed under two kinds" % item)
			kinded[item] = true
	for id in GameData.items:
		if GameItems.slot_of(id) == "weapon" and not kinded.has(id):
			out.append("weapon %s has no kind in feats.json" % id)
	for st in _src.get("statuses", []):
		for key in STATUS_KEYS:
			if not st.has(key):
				out.append("status %s has no %s" % [st.get("id", "?"), key])
	return out


## Every class has a craft of its own: a base class at least 6 feats, one of them a blow it can
## strike by level 3 with no weapon asked (for a ranger, a trap), a hybrid at least
## one feat of its own; and only a few feats are left open to every class.
static func _class_problems() -> Array:
	var out: Array = []
	var cap := 12
	if universal_feats().size() > cap:
		out.append("%d feats are open to every class; at most %d may be" % [universal_feats().size(), cap])
	for cid in GameData.classes:
		var c: Dictionary = GameData.classes[cid]
		var own := _order.filter(func(id): return cid in requires(id).get("classes", []))
		if c.has("parents"):
			if own.is_empty():
				out.append("hybrid class %s has no feat of its own" % cid)
			continue
		if own.size() < 6:
			out.append("class %s is taught only %d feats of its own; it needs at least 6" % [cid, own.size()])
		var first := own.filter(func(id): return float(def(id).get("mult", 0.0)) > 0.0 and int(requires(id).get("min_level", 1)) <= 3 \
			and (requires(id).get("weapon", []) as Array).is_empty())
		if first.is_empty():
			out.append("class %s has no damaging feat by level 3 that asks for no weapon" % cid)
	return out
