## Skill trees: nodes an heir or a companion unlocks with skill points. Each base class has a tree,
## a hybrid draws on both its parents' trees, and every unit shares the bloodline tree. A node has
## ranks; each rank costs points and adds its effect again: core stats (flat or percent), derived
## bonuses read like trait effects (max_hp, luck, defense...), and upgrades to class skills, spells
## and feats. Keystones (data/keystones) rewrite one combat rule and carry a real drawback.
## A node needs any one of its prerequisites to hold a rank. Points come at level milestones,
## a separate pool from feat points; refunds cost gold and need a town or the quiet after a rest.
## Content and tuning live in data/skill_trees/*.json and data/keystones/keystones.json.
##
## State on a GameHeir: tree_ranks (bought), tree_free (carried in the blood: inherited, free),
## tree_points (unspent), tree_level (milestones granted through this level), tree_news (points
## the journal has yet to tell). A companion keeps the same in its party record under "tree".
## Effects are worked out once per change (fx); anything that changes ranks calls changed().
class_name GameSkillTree
extends RefCounted

const CORE := ["str", "mag", "agi", "vit"]
const BONUS := ["max_hp", "max_mp", "melee_damage", "element_power", "defense", "reflexes", "luck", "crit_damage",
	"healing_power", "resist", "mp_regen", "fire_resistance", "persuasion", "stealth", "work_gold"]
const RULES := ["no_dodge", "wrath", "glass", "blood_magic", "mind_over_matter", "crit_mult", "party_heals"]
const MODS := ["mult", "cost", "heal", "radius", "range", "angle", "length", "width", "turns", "cooldown", "crit", "pierce"]
const AREA := {"radius": ["burst"], "range": ["cone"], "angle": ["cone"], "length": ["line"], "width": ["line"]}
const NODE_KEYS := ["id", "tier", "col", "requires", "cost", "max_rank"]
const SETTING_KEYS := ["start_points", "point_bands", "inherit_share", "inherit_fate_failure", "inherit_per_curse",
	"inherit_per_blessing", "inherit_max", "inherit_curses", "inherit_blessings", "respec_fee", "respec_fee_per_sqrt_level",
	"cost_floor", "pierce_cap", "labels", "points_as_value", "bot", "companion_points"]

static var _src: Dictionary = {}
static var _keys_src: Dictionary = {}
static var _trees: Dictionary = {}       # tree id -> tree
static var _order: Array = []            # tree ids, data order
static var _nodes: Dictionary = {}       # node id -> node (keystones carry their keystone's name and effect)
static var _children: Dictionary = {}    # node id -> ids of nodes that list it as a prerequisite
static var _keystones: Dictionary = {}
static var _for_class: Dictionary = {}   # class id -> tree ids
static var _paths: Dictionary = {}       # class id -> node ids in the order the autopilot buys ranks
static var _epoch: int = 0               # bumps when the data is read again, so cached effects go stale


static func _index() -> void:
	if not _src.is_empty() and is_same(_src, GameData.skill_trees) and is_same(_keys_src, GameData.keystones):
		return
	GameData.load_all()
	_src = GameData.skill_trees
	_keys_src = GameData.keystones
	_epoch += 1
	_trees.clear()
	_order.clear()
	_nodes.clear()
	_children.clear()
	_keystones.clear()
	_for_class.clear()
	_paths.clear()
	for k in _keys_src.get("keystones", []):
		_keystones[str(k["id"])] = k
	for t in _src.get("trees", []):
		var tid := str(t["id"])
		_trees[tid] = t
		_order.append(tid)
		for n in t.get("nodes", []):
			n["tree"] = tid
			if n.has("keystone"):
				var k: Dictionary = _keystones.get(str(n["keystone"]), {})
				n["name"] = str(k.get("name", n["keystone"]))
				n["effect"] = k.get("effect", {})
			_nodes[str(n["id"])] = n
	for id in _nodes:
		for r in _nodes[id].get("requires", []):
			if not _children.has(str(r)):
				_children[str(r)] = []
			_children[str(r)].append(id)


## Reads the tree data again after it was changed in place (tools and tests).
static func reindex() -> void:
	_src = {}
	_index()


## The live settings table (tests and harnesses may override values in it).
static func settings() -> Dictionary:
	_index()
	return _src.get("settings", {})


static func setting(key: String) -> Variant:
	return settings()[key]


static func tree(id: String) -> Dictionary:
	_index()
	return _trees.get(id, {})


static func tree_ids() -> Array:
	_index()
	return _order.duplicate()


static func node(id: String) -> Dictionary:
	_index()
	return _nodes.get(id, {})


static func node_name(id: String) -> String:
	return str(node(id).get("name", id))


static func keystone(id: String) -> Dictionary:
	_index()
	return _keystones.get(id, {})


static func keystone_ids() -> Array:
	_index()
	return _keystones.keys()


## The node ids of one tree, in data order.
static func nodes_of(tree_id: String) -> Array:
	return tree(tree_id).get("nodes", []).map(func(n): return str(n["id"]))


static func children_of(id: String) -> Array:
	_index()
	return _children.get(id, [])


## The trees a class draws on: its own (a hybrid, its parents'), then the bloodline's.
static func trees_for(class_id: String) -> Array:
	_index()
	if not _for_class.has(class_id):
		var own: Array = []
		for tid in _order:
			if str(_trees[tid].get("class", "")) == class_id:
				own.append(tid)
		if own.is_empty():
			for p in GameData.classes.get(class_id, {}).get("parents", []):
				for tid in _order:
					if str(_trees[tid].get("class", "")) == str(p) and tid not in own:
						own.append(tid)
		for tid in _order:
			if str(_trees[tid].get("class", "")) == "":
				own.append(tid)
		_for_class[class_id] = own
	return _for_class[class_id]


static func is_keystone(id: String) -> bool:
	return node(id).has("keystone")


static func inheritable(id: String) -> bool:
	return bool(node(id).get("inheritable", false))


# ---------------------------------------------------------------- points

## Skill points granted by `level`: the starting points, then one every `every` levels within each
## band [until, every] (frequent early, sparse late).
static func points_at(level: int) -> int:
	if level < 1:
		return 0
	var n := int(setting("start_points"))
	var prev := 0
	for b in setting("point_bands"):
		var until := int(b[0])
		var top := mini(level, until)
		if top > prev:
			n += (top - prev) / int(b[1])
		prev = until
		if level <= until:
			break
	return n


## A hireling's points at `level`: a share of an heir's (settings.companion_points).
static func companion_points_at(level: int) -> int:
	return int(floor(float(points_at(level)) * float(setting("companion_points")) + 0.000001))


## The next level after `level` that brings a skill point, or -1 past the last.
static func next_point_level(level: int) -> int:
	var prev := 0
	for b in setting("point_bands"):
		var until := int(b[0])
		var every := int(b[1])
		if level < until:
			var from := maxi(level, prev)
			var at := prev + every * ((from - prev) / every + 1)
			if at <= until:
				return at
		prev = until
	return -1


## A new heir: nothing bought, the points of their own level. Class nodes are personal; what the
## blood carries is given at succession (see inherit).
static func start(u: GameHeir) -> void:
	u.tree_ranks = {}
	u.tree_free = {}
	u.tree_points = points_at(u.level)
	u.tree_level = u.level
	u.tree_news = 0
	changed(u)


## Grants the points of every milestone passed since the last grant. Returns the points granted.
static func sync(u: GameHeir) -> int:
	if u.tree_level >= u.level:
		return 0
	var got := points_at(u.level) - points_at(u.tree_level)
	u.tree_points += got
	if u.tree_level >= 1:
		u.tree_news += got
	u.tree_level = u.level
	return got


static func points(u: GameHeir) -> int:
	sync(u)
	return u.tree_points


static func rank(u: GameHeir, id: String) -> int:
	return int(u.tree_ranks.get(id, 0)) + int(u.tree_free.get(id, 0))


static func max_rank(id: String) -> int:
	return int(node(id).get("max_rank", 1))


static func cost(id: String) -> int:
	return int(node(id).get("cost", 1))


## Points spent on the unit's tree (refunded by a respec).
static func spent(u: GameHeir) -> int:
	var n := 0
	for id in u.tree_ranks:
		n += int(u.tree_ranks[id]) * cost(str(id))
	return n


static func changed(u: GameHeir) -> void:
	u.tree_version += 1


# ---------------------------------------------------------------- rules for buying a rank

## Why the unit cannot buy the next rank of a node ("" if it can).
static func take_block(u: GameHeir, id: String) -> String:
	var n := node(id)
	if n.is_empty():
		return "No such skill."
	if str(n["tree"]) not in trees_for(u.class_id):
		return "%s is not on a %s's paths." % [n["name"], u.cls()["name"]]
	if rank(u, id) >= max_rank(id):
		return "%s is mastered." % n["name"] if max_rank(id) > 1 else "%s already holds %s." % [u.name, n["name"]]
	var req: Array = n.get("requires", [])
	if not req.is_empty() and not req.any(func(r): return rank(u, str(r)) > 0):
		return "Needs %s first." % _or_list(req.map(func(r): return node_name(str(r))))
	if n.has("keystone"):
		var why := _keystone_block(u, str(n["keystone"]))
		if why != "":
			return why
	sync(u)
	if u.tree_points < cost(id):
		return "%s costs %d skill point%s; %s has %s." % [n["name"], cost(id), "" if cost(id) == 1 else "s", u.name, GameText.num(u.tree_points)]
	return ""


## A keystone may not join one that follows the same rule, or one it names as its opposite.
static func _keystone_block(u: GameHeir, kid: String) -> String:
	var k := keystone(kid)
	for held in held_keystones(u):
		var h := keystone(held)
		if held == kid:
			return "%s already follows %s." % [u.name, k["name"]]
		if str(h.get("rule", "")) == str(k.get("rule", "")) and str(k.get("rule", "")) != "":
			return "%s already follows %s, which bends the same rule." % [u.name, h["name"]]
		if held in k.get("excludes", []) or kid in h.get("excludes", []):
			return "%s cannot be joined to %s." % [k["name"], h["name"]]
	return ""


static func held_keystones(u: GameHeir) -> Array:
	var out: Array = []
	for id in u.tree_ranks.keys() + u.tree_free.keys():
		if rank(u, str(id)) > 0 and is_keystone(str(id)) and str(node(str(id))["keystone"]) not in out:
			out.append(str(node(str(id))["keystone"]))
	return out


## Buys one rank; no questions of place. Returns false if take_block refuses.
static func take(u: GameHeir, id: String) -> bool:
	if take_block(u, id) != "":
		return false
	u.tree_points -= cost(id)
	u.tree_ranks[id] = int(u.tree_ranks.get(id, 0)) + 1
	changed(u)
	return true


## Why ranks cannot be bought for anyone right now ("" if they can): a living heir, not mid-fight.
static func spend_block(d: GameDynasty) -> String:
	if d.state != "life":
		return "Only a living heir can learn."
	if d.battle != null:
		return "Not in the middle of a fight."
	return ""


## The heir (`who` "") or a companion in the party (`who` its id) buys a rank of `id`. Returns the
## journal line or why not (nothing changes then).
static func spend(d: GameDynasty, who: String, id: String) -> String:
	var why := spend_block(d)
	var u := unit_of(d, who)
	if why == "" and u == null:
		why = "No such companion."
	if why == "":
		why = take_block(u, id)
	if why != "":
		return why
	take(u, id)
	_store(d, who, u)
	var r := rank(u, id)
	var text := "%s takes %s%s (%s skill point%s left)." % [u.name, node_name(id), "" if max_rank(id) == 1 else " %d/%d" % [r, max_rank(id)],
		GameText.num(u.tree_points), "" if u.tree_points == 1 else "s"]
	d._say(text)
	return text


## The heir (`who` "") or a companion's unit, as the tree sees it.
static func unit_of(d: GameDynasty, who: String) -> GameHeir:
	if who == "":
		sync(d.heir)
		return d.heir
	var m := d.party.member(who)
	return null if m.is_empty() else d.party.unit(d, m)


## A companion's tree lives in its party record.
static func _store(d: GameDynasty, who: String, u: GameHeir) -> void:
	if who == "":
		return
	var m := d.party.member(who)
	if not m.is_empty():
		m["tree"] = state_of(u)


# ---------------------------------------------------------------- respec

static func respec_fee(d: GameDynasty, u: GameHeir) -> int:
	var f := float(setting("respec_fee")) * (1.0 + float(setting("respec_fee_per_sqrt_level")) * sqrt(float(maxi(0, u.level - 1))))
	return maxi(1, int(round(f * GameData.enemy_scale(d.gen))))


## Why the tree cannot be refunded now ("" if it can): a town or the quiet after a rest, something
## bought to refund, and the heir's gold for the fee.
static func respec_block(d: GameDynasty, who: String = "") -> String:
	var why := spend_block(d)
	if why != "":
		return why
	var u := unit_of(d, who)
	if u == null:
		return "No such companion."
	if not (d.world.is_town() or d.heir.downtime):
		return "%s is no place to unlearn. Refund skill points in a town or right after a rest." % d.world.here().get("name", "This")
	if spent(u) <= 0:
		return "%s has bought nothing to refund." % u.name
	var fee := respec_fee(d, u)
	if d.heir.gold < fee:
		return "Unlearning costs %s gold; %s has %s." % [GameText.num(fee), d.heir.name, GameText.num(d.heir.gold)]
	return ""


## Refunds every bought rank for the fee; what the blood carries stays.
static func respec(d: GameDynasty, who: String = "") -> String:
	var why := respec_block(d, who)
	if why != "":
		return why
	var u := unit_of(d, who)
	var fee := respec_fee(d, u)
	var back := spent(u)
	d.heir.gold -= fee
	u.tree_points += back
	u.tree_ranks = {}
	changed(u)
	_store(d, who, u)
	var text := "%s pays %s gold to unlearn and has %s skill point%s to spend again." % [u.name, GameText.num(fee), GameText.num(u.tree_points), "" if u.tree_points == 1 else "s"]
	if who != "":
		text = "%s pays %s gold for %s to unlearn; %s skill point%s to spend again." % [d.heir.name, GameText.num(fee), u.name, GameText.num(u.tree_points), "" if u.tree_points == 1 else "s"]
	d._say(text)
	return text


# ---------------------------------------------------------------- effects

## Everything the unit's ranks add up to, worked out once per change: {flat, pct (core stats),
## bonus (trait-like stats), mods ("skill:damage", "spell:fireball", "feat:*" -> summed upgrades),
## rules (rule -> params), made (upgraded abilities)}.
static func fx(u: GameHeir) -> Dictionary:
	_index()
	if u.tree_fx_v == u.tree_version and u.tree_fx_e == _epoch:
		return u.tree_fx
	var f := {"flat": {}, "pct": {}, "bonus": {}, "mods": {}, "rules": {}, "made": {}, "skills": []}
	var done := {}
	for id in u.tree_ranks.keys() + u.tree_free.keys():
		if done.has(id):
			continue
		done[id] = true
		var r := rank(u, str(id))
		var n := node(str(id))
		if r <= 0 or n.is_empty():
			continue
		_add_effect(f, n.get("effect", {}), float(r))
		if n.has("keystone"):
			var k := keystone(str(n["keystone"]))
			if str(k.get("rule", "")) != "":
				f["rules"][str(k["rule"])] = k.get("params", {})
	u.tree_fx = f
	u.tree_fx_v = u.tree_version
	u.tree_fx_e = _epoch
	return f


static func _add_effect(f: Dictionary, e: Dictionary, r: float) -> void:
	var stats: Dictionary = e.get("stats", {})
	for s in stats:
		for c in (CORE if s == "all" else [s]):
			for kind in ["flat", "pct"]:
				if stats[s].has(kind):
					f[kind][c] = float(f[kind].get(c, 0.0)) + float(stats[s][kind]) * r
	var bonus: Dictionary = e.get("bonus", {})
	for s in bonus:
		f["bonus"][s] = float(f["bonus"].get(s, 0.0)) + float(bonus[s]) * r
	for m in e.get("abilities", []):
		var key := _mod_key(m)
		var into: Dictionary = f["mods"].get(key, {})
		for k in MODS:
			if m.has(k):
				into[k] = float(into.get(k, 0.0)) + float(m[k]) * r
		f["mods"][key] = into


static func _mod_key(m: Dictionary) -> String:
	for kind in ["skill", "spell", "feat"]:
		if m.has(kind):
			return "%s:%s" % [kind, m[kind]]
	return ""


static func flat(u: GameHeir, s: String) -> float:
	return float(fx(u)["flat"].get(s, 0.0))


static func pct(u: GameHeir, s: String) -> float:
	return float(fx(u)["pct"].get(s, 0.0))


## A trait-like stat (max_hp, luck, resist...) the unit's ranks add.
static func bonus(u: GameHeir, s: String) -> float:
	if u.tree_ranks.is_empty() and u.tree_free.is_empty():
		return 0.0
	return float(fx(u)["bonus"].get(s, 0.0))


## A keystone rule the unit follows: its params, or {} when it does not.
static func rule(u: GameHeir, name: String) -> Dictionary:
	if u.tree_ranks.is_empty() and u.tree_free.is_empty():
		return {}
	return fx(u)["rules"].get(name, {})


static func has_rule(u: GameHeir, name: String) -> bool:
	if u.tree_ranks.is_empty() and u.tree_free.is_empty():
		return false
	return fx(u)["rules"].has(name)


## The unit's class skills as its ranks have shaped them.
static func skills(u: GameHeir) -> Array:
	var base: Array = u.cls()["skills"]
	if u.tree_ranks.is_empty() and u.tree_free.is_empty():
		return base
	var f := fx(u)
	if (f["skills"] as Array).size() != base.size():
		f["skills"] = base.map(func(s): return upgraded(u, "skill", s))
	return f["skills"]


static func skill(u: GameHeir, i: int) -> Dictionary:
	return skills(u)[i]


static func spell(u: GameHeir, id: String) -> Dictionary:
	return upgraded(u, "spell", GameCombat.spell(id))


static func feat(u: GameHeir, id: String) -> Dictionary:
	return upgraded(u, "feat", GameFeats.def(id))


## An ability (class skill, spell or feat definition) with the unit's upgrades applied, kept until
## its ranks change. Without upgrades it is the definition itself.
static func upgraded(u: GameHeir, kind: String, ab: Dictionary) -> Dictionary:
	if ab.is_empty() or (u.tree_ranks.is_empty() and u.tree_free.is_empty()):
		return ab
	var f := fx(u)
	var key := "%s:%s" % [kind, ab.get("id", "")]
	if f["made"].has(key):
		return f["made"][key]
	var m := _mods_for(f, kind, ab)
	var party: bool = kind == "skill" and ab.has("pct_max_hp") and not ab.get("party", false) and f["rules"].has("party_heals")
	var out := ab
	if not m.is_empty() or party:
		out = _apply(ab, m)
		if party:
			var p: Dictionary = f["rules"]["party_heals"]
			out["party"] = true
			out["target"] = {"shape": "party"}
			out["pct_max_hp"] = float(out["pct_max_hp"]) * float(p.get("potency", 1.0))
			out["mp"] = float(out.get("mp", 0)) * (1.0 + float(p.get("cost", 0.0)))
	f["made"][key] = out
	return out


static func _mods_for(f: Dictionary, kind: String, ab: Dictionary) -> Dictionary:
	var keys: Array = ["%s:%s" % [kind, ab.get("id", "")], kind + ":*"]
	if kind == "skill" and "skill:" + str(ab.get("type", "")) not in keys:   # a skill may be named for its type
		keys.append("skill:" + str(ab.get("type", "")))
	var m := {}
	for k in keys:
		var add: Dictionary = f["mods"].get(k, {})
		for x in add:
			m[x] = float(m.get(x, 0.0)) + float(add[x])
	return m


## Whether an upgrade field means anything for this ability (a radius only for a burst...).
static func fits(ab: Dictionary, field: String) -> bool:
	match field:
		"mult", "crit", "pierce":
			return float(ab.get("mult", 0.0)) > 0.0
		"cost":
			return float(ab.get("mp", 0.0)) > 0.0
		"heal":
			return ab.has("pct_max_hp")
		"turns":
			return not (ab.get("statuses", []) as Array).is_empty()
		"cooldown":
			return ab.has("cooldown")
	if AREA.has(field):
		return GameCombat.shape(ab) in AREA[field]
	return false


static func _apply(ab: Dictionary, m: Dictionary) -> Dictionary:
	var out := ab.duplicate(true)
	for k in m:
		if not fits(ab, k):
			continue
		var v := float(m[k])
		match k:
			"mult":
				out["mult"] = float(ab["mult"]) * (1.0 + v)
			"cost":
				out["mp"] = float(ab["mp"]) * maxf(float(setting("cost_floor")), 1.0 + v)
			"heal":
				out["pct_max_hp"] = float(ab["pct_max_hp"]) * (1.0 + v)
			"crit":
				out["crit_bonus"] = float(ab.get("crit_bonus", 0.0)) + v
			"pierce":
				out["pierce"] = minf(float(setting("pierce_cap")), float(ab.get("pierce", 0.0)) + v)
			"cooldown":
				out["cooldown"] = maxi(0, int(ab["cooldown"]) + int(round(v)))
			"turns":
				for st in out["statuses"]:
					var sd := GameCombat.status_def(str(st["id"]))
					st["turns"] = mini(int(GameCombat.setting("status_turns_max")), int(st.get("turns", sd.get("default_turns", 1))) + int(round(v)))
			_:
				var t: Dictionary = out["target"]
				var base := {"radius": 3.0, "range": 16.0, "angle": 60.0, "length": 18.0, "width": 3.0}
				t[k] = float(t.get(k, base[k])) + v
	return out


## Skill and spell costs paid in HP under Blood Magic: the cost's share of the mana pool, times
## hp_share, of max HP.
static func blood_cost(u: GameHeir, mp_cost: int, max_hp: int, max_mp: int) -> int:
	if mp_cost <= 0:
		return 0
	var share := float(rule(u, "blood_magic").get("hp_share", 0.5))
	return maxi(1, int(ceil(float(mp_cost) / float(maxi(1, max_mp)) * float(max_hp) * share)))


# ---------------------------------------------------------------- the blood

## The share of the parent's inheritable ranks the child carries: the data's base, less for a life
## that failed its fate (the child was shaped by it) and each curse the child bears, more for each
## blessing.
static func inherit_share(child: GameHeir) -> Dictionary:
	var share := float(setting("inherit_share"))
	var why: Array = []
	if child.archetype != "":
		share += float(setting("inherit_fate_failure"))
		why.append("a failed fate thinned it")
	var curses := _count_of(child, setting("inherit_curses"))
	var blessings := _count_of(child, setting("inherit_blessings"))
	if curses.size() > 0:
		share += float(setting("inherit_per_curse")) * float(curses.size())
		why.append("%s thinned it" % _and_list(curses))
	if blessings.size() > 0:
		share += float(setting("inherit_per_blessing")) * float(blessings.size())
		why.append("%s strengthened it" % _and_list(blessings))
	return {"share": clampf(share, 0.0, float(setting("inherit_max"))), "why": why}


static func _count_of(u: GameHeir, rule_: Dictionary) -> Array:
	var out: Array = []
	for t in u.traits:
		if t in rule_.get("traits", []) or str(GameData.trait_def(t).get("category", "")) in rule_.get("categories", []):
			out.append(GameData.trait_name(t))
	return out


## At succession the child wakes with part of what the parent's blood had awakened, free: a share of
## the parent's inheritable ranks (bought or carried), shallow nodes and first ranks first, so what
## passes down always holds together. The last part rank is rolled on the dynasty's dice.
static func inherit(d: GameDynasty, parent: GameHeir, child: GameHeir, msgs: Array) -> void:
	var have := {}
	var total := 0
	for tid in _order:
		if str(_trees[tid].get("class", "")) != "":
			continue
		for id in nodes_of(tid):
			if inheritable(id) and rank(parent, id) > 0:
				have[id] = rank(parent, id)
				total += int(have[id])
	child.tree_free = {}
	changed(child)
	if total == 0:
		return
	var s := inherit_share(child)
	var exact := float(total) * float(s["share"])
	var n := int(floor(exact + 0.000001))
	if exact - float(n) > 0.000001 and d.rng.randf() < exact - float(n):
		n += 1
	var order: Array = have.keys()
	order.sort_custom(func(a, b): return int(node(a)["tier"]) < int(node(b)["tier"]) or (int(node(a)["tier"]) == int(node(b)["tier"]) and _pos(a) < _pos(b)))
	var given := 0
	var r := 1
	while given < n:
		var any := false
		for id in order:
			if given >= n:
				break
			if int(have[id]) < r or int(child.tree_free.get(id, 0)) != r - 1:
				continue
			var req: Array = node(id).get("requires", [])
			if not req.is_empty() and not req.any(func(q): return int(child.tree_free.get(str(q), 0)) > 0):
				continue
			child.tree_free[id] = r
			given += 1
			any = true
		if not any:
			r += 1
			if r > 99:
				break
	changed(child)
	var why := "" if (s["why"] as Array).is_empty() else "; " + "; ".join(PackedStringArray(s["why"]))
	var text: String
	if given == 0:
		text = "None of the %d rank%s %s's blood had awakened stirs in %s%s." % [total, "" if total == 1 else "s", parent.name, child.name, why]
	else:
		var parts: Array = []
		for id in order:
			if child.tree_free.has(id):
				parts.append("%s %d/%d" % [node_name(id), int(child.tree_free[id]), max_rank(id)])
		text = "The blood remembers: %s wakes with %s (%d of %s's %d rank%s%s)." % [child.name, _and_list(parts), given, parent.name, total, "" if total == 1 else "s", why]
	msgs.append(text)


static func _pos(id: String) -> int:
	var n := node(id)
	return (tree(str(n["tree"])).get("nodes", []) as Array).find(n)


# ---------------------------------------------------------------- companions

## A companion's tree record, read back from a save ({} when there is none: attach grants it).
static func load_member(v: Variant) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY or not v.has("points"):
		return {}
	return {"ranks": _ranks(v.get("ranks", {})), "points": int(v.get("points", 0)), "level": int(v.get("level", 1))}


## Gives a companion's unit its tree from the party record. A record from before trees, or one
## made at hire, gets the points of the companion's level spent along its class's path; points
## of levels gained since are spent the same way. A companion brought down to a lower level (a
## young heir now leads) learns again along that path for the points the level gives.
static func attach(u: GameHeir, m: Dictionary) -> void:
	var t: Dictionary = m.get("tree", {})
	var auto := 0
	if t.is_empty() or int(t["level"]) > u.level:
		t = {"ranks": {}, "points": companion_points_at(u.level), "level": u.level}
		auto = int(t["points"])
	elif int(t["level"]) < u.level:
		auto = companion_points_at(u.level) - companion_points_at(int(t["level"]))
		t["points"] = int(t["points"]) + auto
		t["level"] = u.level
	u.tree_ranks = (t["ranks"] as Dictionary).duplicate()
	u.tree_free = {}
	u.tree_points = int(t["points"])
	u.tree_level = u.level
	u.tree_news = 0
	changed(u)
	if auto > 0:
		auto_spend(u, auto)
		t = state_of(u)
	m["tree"] = t


static func state_of(u: GameHeir) -> Dictionary:
	return {"ranks": u.tree_ranks.duplicate(), "points": u.tree_points, "level": u.tree_level}


# ---------------------------------------------------------------- the autopilot's path

## How the class fights: by its damage skill's stat (str, mag or both).
static func style_of(class_id: String) -> String:
	for s in GameData.classes.get(class_id, {}).get("skills", []):
		if str(s.get("type", "")) == "damage":
			return str(s.get("stat", "str"))
	return "str"


## Whether the autopilot would ever follow a keystone with this class.
static func suits(class_id: String, kid: String) -> bool:
	return class_id in keystone(kid).get("suits", [])


## What one rank of a node is worth to a class, in about "percent of power" (settings.bot): its
## stats by the class's style, its upgrades by how much the class uses what they touch. A keystone
## is worth a fixed amount where it suits the class and is never taken where it does not.
static func worth(id: String, class_id: String) -> float:
	var n := node(id)
	var bot: Dictionary = setting("bot")
	if n.has("keystone"):
		return float(bot["keystone"]) if suits(class_id, str(n["keystone"])) else -INF
	var w: Dictionary = bot["styles"].get(style_of(class_id), {})
	var e: Dictionary = n.get("effect", {})
	var v := 0.0
	var stats: Dictionary = e.get("stats", {})
	for s in stats:
		var ws := float(w.get(s, 0.0))
		v += float(stats[s].get("pct", 0.0)) * 100.0 * ws + float(stats[s].get("flat", 0.0)) * float(bot["flat"]) * ws
	var b: Dictionary = e.get("bonus", {})
	for s in b:
		v += float(b[s]) * 100.0 * float(w.get(s, 0.1))
	var ab: Dictionary = bot["ability"]
	var plan := GameCombat.class_spell_plan(class_id).map(func(p): return p[0])
	for m in e.get("abilities", []):
		var use := 0.0
		if m.has("skill"):
			var want := str(m["skill"])
			for s in GameData.classes.get(class_id, {}).get("skills", []):
				if str(s.get("id", "")) == want or str(s.get("type", "")) == want:
					use = float(ab["skill_heal" if str(s.get("type", "")) == "heal" else "skill_damage"])
		elif m.has("spell"):
			if str(m["spell"]) == "*":
				use = float(ab["spell_all"]) if not plan.is_empty() else 0.0
			elif str(m["spell"]) in plan:
				use = float(ab["spell"])
		elif m.has("feat"):
			use = float(ab["feat"])
		var each := float(m.get("mult", 0.0)) * 100.0 * float(ab["mult"]) - float(m.get("cost", 0.0)) * 100.0 * float(ab["cost"])
		each += float(m.get("heal", 0.0)) * 100.0 * float(ab["heal"]) - float(m.get("cooldown", 0.0)) * float(ab["cooldown"])
		each += float(m.get("turns", 0.0)) * float(ab["turns"]) + float(m.get("crit", 0.0)) * 100.0 * float(ab["crit"])
		each += float(m.get("pierce", 0.0)) * 100.0 * float(ab["pierce"])
		for k in AREA:
			if m.has(k):
				each += float(ab["area"]) * (0.1 if k == "angle" else 1.0) * float(m[k])
		v += use * each
	return v


## The order in which the autopilot buys ranks for a class, worked out once: each step takes the
## open rank worth the most per point, a node not yet started counting half of what it opens up.
## Keystones that do not suit the class are left out; so is a second keystone of the same rule.
static func path_of(class_id: String) -> Array:
	_index()
	if _paths.has(class_id):
		return _paths[class_id]
	var ids: Array = []
	for tid in trees_for(class_id):
		ids.append_array(nodes_of(tid))
	var val := {}
	for id in ids:
		val[id] = worth(id, class_id)
	var look := float(setting("bot")["lookahead"])
	var pull := {}
	var by_tier := ids.duplicate()
	by_tier.sort_custom(func(a, b): return int(node(a)["tier"]) > int(node(b)["tier"]))
	for id in by_tier:
		var best := 0.0
		for c in children_of(id):
			if pull.has(c):
				best = maxf(best, float(pull[c]))
		pull[id] = maxf(float(val[id]), 0.0) + look * best if float(val[id]) > -INF else -INF
	var have := {}
	var rules := {}
	var out: Array = []
	while true:
		var pick := ""
		var score := -INF
		for id in ids:
			var n := node(id)
			if int(have.get(id, 0)) >= int(n.get("max_rank", 1)) or float(val[id]) == -INF:
				continue
			var req: Array = n.get("requires", [])
			if not req.is_empty() and not req.any(func(r): return int(have.get(str(r), 0)) > 0):
				continue
			if n.has("keystone"):
				var k := keystone(str(n["keystone"]))
				if rules.has(str(k.get("rule", ""))) or (k.get("excludes", []) as Array).any(func(x): return rules.values().has(x)):
					continue
			var s := (float(pull[id]) if int(have.get(id, 0)) == 0 else float(val[id])) / float(maxi(1, int(n.get("cost", 1))))
			if s > score:
				score = s
				pick = id
		if pick == "":
			break
		have[pick] = int(have.get(pick, 0)) + 1
		if node(pick).has("keystone"):
			var k := keystone(str(node(pick)["keystone"]))
			rules[str(k.get("rule", ""))] = str(k["id"])
		out.append(pick)
	_paths[class_id] = out
	return out


## Spends up to `budget` points along the class's path (all of them by default). Returns the
## ranks bought. Each step only reads the path, so it costs little.
static func auto_spend(u: GameHeir, budget: int = -1) -> int:
	sync(u)
	var left := u.tree_points if budget < 0 else mini(budget, u.tree_points)
	if left <= 0:
		return 0
	var seen := {}
	var bought := 0
	for id in path_of(u.class_id):
		seen[id] = int(seen.get(id, 0)) + 1
		if rank(u, id) >= int(seen[id]) or cost(id) > left:
			continue
		if take(u, id):
			left -= cost(id)
			bought += 1
			if left <= 0:
				break
	return bought


## The player hands the choice over: every point the heir or a companion holds is spent along the
## path the autopilot follows for their class. Returns the journal line or why not.
static func auto(d: GameDynasty, who: String = "") -> String:
	var why := spend_block(d)
	var u := unit_of(d, who)
	if why == "" and u == null:
		why = "No such companion."
	if why != "":
		return why
	var before := u.tree_ranks.duplicate()
	if auto_spend(u) == 0:
		return "Nothing on %s's path can be bought with %s skill point%s." % [u.name, GameText.num(u.tree_points), "" if u.tree_points == 1 else "s"]
	_store(d, who, u)
	var got: Array = []
	for id in u.tree_ranks:
		var n := int(u.tree_ranks[id]) - int(before.get(id, 0))
		if n > 0:
			got.append(node_name(id) if n == 1 else "%s x%d" % [node_name(id), n])
	var what := _and_list(got) if got.size() <= 6 else "%s and %d more" % [", ".join(PackedStringArray(got.slice(0, 5))), got.size() - 5]
	var text := "%s follows the well-worn path: %s (%s skill point%s left)." % [u.name, what, GameText.num(u.tree_points), "" if u.tree_points == 1 else "s"]
	d._say(text)
	return text


## The autopilot's tree errand: spend the heir's points along the path for their class.
static func bot_tick(d: GameDynasty) -> void:
	if spend_block(d) != "":
		return
	if points(d.heir) > 0:
		auto_spend(d.heir)


## Time passes: skill points earned are told.
static func on_years(d: GameDynasty, msgs: Array) -> void:
	var h := d.heir
	sync(h)
	if h.tree_news <= 0:
		return
	var line := "%s earns %s%s." % [h.name, "a skill point" if h.tree_news == 1 else "%s skill points" % GameText.num(h.tree_news),
		" (%s to spend)" % GameText.num(h.tree_points) if h.tree_points > 0 else ""]
	h.tree_news = 0
	msgs.append(line)
	d._say(line)


# ---------------------------------------------------------------- save / load

static func to_dict(u: GameHeir) -> Dictionary:
	return {"ranks": u.tree_ranks.duplicate(), "free": u.tree_free.duplicate(), "points": u.tree_points, "level": u.tree_level, "news": u.tree_news}


## A saved tree read back: ranks of nodes that still exist, no more than their max. A save from
## before skill trees grants the points of the heir's level.
static func load_into(u: GameHeir, v: Variant) -> void:
	if typeof(v) != TYPE_DICTIONARY or not v.has("points"):
		start(u)
		return
	u.tree_ranks = _ranks(v.get("ranks", {}))
	u.tree_free = _ranks(v.get("free", {}))
	u.tree_points = int(v.get("points", 0))
	u.tree_level = int(v.get("level", u.level))
	u.tree_news = int(v.get("news", 0))
	for id in u.tree_ranks.keys():   # a rank the data no longer allows is refunded
		var over := rank(u, id) - max_rank(id)
		if over > 0:
			u.tree_points += over * cost(id)
			u.tree_ranks[id] = int(u.tree_ranks[id]) - over
			if int(u.tree_ranks[id]) <= 0:
				u.tree_ranks.erase(id)
	changed(u)


static func _ranks(v: Variant) -> Dictionary:
	var out := {}
	if typeof(v) != TYPE_DICTIONARY:
		return out
	for id in v:
		if not node(str(id)).is_empty() and int(v[id]) > 0:
			out[str(id)] = mini(int(v[id]), max_rank(str(id)))
	return out


# ---------------------------------------------------------------- text

static func _or_list(names: Array) -> String:
	if names.size() <= 1:
		return "".join(PackedStringArray(names))
	return "%s or %s" % [", ".join(PackedStringArray(names.slice(0, -1))), names[-1]]


static func _and_list(names: Array) -> String:
	if names.size() <= 1:
		return "".join(PackedStringArray(names))
	return "%s and %s" % [", ".join(PackedStringArray(names.slice(0, -1))), names[-1]]


static func _n(v: float) -> String:
	var r := snappedf(v, 0.01)
	return str(int(r)) if r == floorf(r) else String.num(r, 2)


static func _p(v: float) -> String:
	return "%s%%" % _n(v * 100.0)


static func label(stat: String) -> String:
	return str(setting("labels").get(stat, stat))


## What a node's effect gives at `r` ranks, one short line per part, for the unit `u` (whose own
## skill names are used; null for no particular unit).
static func effect_lines(id: String, r: int, u: GameHeir = null) -> Array:
	var n := node(id)
	var out: Array = []
	if n.has("keystone"):
		var k := keystone(str(n["keystone"]))
		out.append(str(k.get("text", "")))
		out.append("Drawback: " + str(k.get("drawback", "")))
	var e: Dictionary = n.get("effect", {})
	var stats: Dictionary = e.get("stats", {})
	for s in stats:
		if stats[s].has("flat"):
			out.append("+%s %s" % [_n(float(stats[s]["flat"]) * r), label(s)])
		if stats[s].has("pct"):
			out.append("+%s %s" % [_p(float(stats[s]["pct"]) * r), label(s)])
	var b: Dictionary = e.get("bonus", {})
	for s in b:
		var v := float(b[s]) * r
		if s == "crit_damage":
			out.append("%s%s to the crit multiplier" % ["+" if v >= 0.0 else "", _n(v)])
		else:
			out.append("%s%s %s" % ["+" if v >= 0.0 else "-", _p(absf(v)), label(s)])
	for m in e.get("abilities", []):
		out.append(ability_line(m, r, u))
	return out


static func target_name(m: Dictionary, u: GameHeir = null) -> String:
	if m.has("skill"):
		var want := str(m["skill"])
		var cid := u.class_id if u != null else ""
		for s in GameData.classes.get(cid, {}).get("skills", []):
			if str(s.get("id", "")) == want or str(s.get("type", "")) == want:
				return str(s["name"])
		return {"damage": "Class strike", "heal": "Class heal"}.get(want, want)
	if m.has("spell"):
		return "Every spell" if str(m["spell"]) == "*" else str(GameCombat.spell(str(m["spell"])).get("name", m["spell"]))
	return "Every feat" if str(m["feat"]) == "*" else GameFeats.feat_name(str(m["feat"]))


static func ability_line(m: Dictionary, r: int, u: GameHeir = null) -> String:
	var parts: Array = []
	for k in MODS:
		if not m.has(k):
			continue
		var v := float(m[k]) * r
		match k:
			"mult":
				parts.append("+%s damage" % _p(v))
			"cost":
				parts.append("%s cheaper" % _p(-v))
			"heal":
				parts.append("heals %s more" % _p(v))
			"crit":
				parts.append("+%s crit chance" % _p(v))
			"pierce":
				parts.append("ignores %s more armour" % _p(v))
			"cooldown":
				parts.append("ready %s turn%s sooner" % [_n(-v), "" if -v == 1.0 else "s"])
			"turns":
				parts.append("its effects last %s more turn%s" % [_n(v), "" if v == 1.0 else "s"])
			"angle":
				parts.append("cone %s° wider" % _n(v))
			"width":
				parts.append("line %s paces wider" % _n(v))
			_:
				parts.append("%s %s paces longer" % [k, _n(v)] if k != "radius" else "radius %s paces larger" % _n(v))
	return "%s: %s" % [target_name(m, u), ", ".join(PackedStringArray(parts))]


## Hover text for a node as the unit stands: what it gives now and at the next rank, its price and
## what it needs.
static func node_text(u: GameHeir, id: String) -> String:
	var n := node(id)
	var r := rank(u, id)
	var mx := max_rank(id)
	var lines: Array = ["%s%s   rank %d/%d   %d point%s a rank" % [n["name"], "  (keystone)" if n.has("keystone") else "", r, mx, cost(id), "" if cost(id) == 1 else "s"]]
	if str(n.get("text", "")) != "":
		lines.append(str(n["text"]))
	if r > 0:
		lines.append("Now: " + "; ".join(PackedStringArray(effect_lines(id, r, u))))
	if r < mx:
		lines.append(("Next rank: " if r > 0 else "Gives: ") + "; ".join(PackedStringArray(effect_lines(id, r + 1, u))))
	var req: Array = n.get("requires", [])
	if not req.is_empty():
		lines.append("Needs a rank in %s." % _or_list(req.map(func(q): return node_name(str(q)))))
	if int(u.tree_free.get(id, 0)) > 0:
		lines.append("%d rank%s carried in the blood (free, never refunded)." % [int(u.tree_free[id]), "" if int(u.tree_free[id]) == 1 else "s"])
	if inheritable(id):
		lines.append("Inheritable: part of it passes to the next heir.")
	return "\n".join(PackedStringArray(lines))


## "Ancestral Vigor 2/3, Heavy Blows 1/3" for the summary column.
static func summary_lines(d: GameDynasty) -> Array:
	var h := d.heir
	var out: Array = []
	var pts := points(h)
	var taken: Array = []
	for tid in trees_for(h.class_id):
		for id in nodes_of(tid):
			if rank(h, id) > 0:
				taken.append(id)
	out.append("%s skill point%s to spend, %d node%s taken." % [GameText.num(pts), "" if pts == 1 else "s", taken.size(), "" if taken.size() == 1 else "s"])
	var keys := held_keystones(h).map(func(k): return str(keystone(k)["name"]))
	if not keys.is_empty():
		out.append("Keystone: " + _and_list(keys))
	return out


# ---------------------------------------------------------------- checks

## Everything wrong with the tree data, one readable line each; empty when it is sound.
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
	var last := 0
	for b in s["point_bands"]:
		if typeof(b) != TYPE_ARRAY or (b as Array).size() != 2 or int(b[0]) <= last or int(b[1]) < 1 or int(b[0]) > cap:
			out.append("settings.point_bands must be [until level, every n levels] with rising levels up to the cap: %s" % str(b))
		else:
			last = int(b[0])
	if last != cap:
		out.append("settings.point_bands must run to the level cap (%d)" % cap)
	if int(s["start_points"]) < 1:
		out.append("settings.start_points must give a new heir at least one point")
	for k in ["inherit_share", "inherit_max"]:
		if float(s[k]) < 0.0 or float(s[k]) > 1.0:
			out.append("settings.%s is a share from 0 to 1" % k)
	for k in _keystones:
		var ks: Dictionary = _keystones[k]
		for key in ["name", "rule", "text", "drawback"]:
			if not ks.has(key) or str(ks[key]) == "":
				out.append("keystone %s has no %s" % [k, key])
		if str(ks.get("rule", "")) not in RULES:
			out.append("keystone %s: unknown rule '%s'" % [k, ks.get("rule", "")])
		out.append_array(_effect_problems("keystone " + k, ks.get("effect", {}), []))
		for x in ks.get("excludes", []):
			if not _keystones.has(str(x)):
				out.append("keystone %s excludes unknown keystone '%s'" % [k, x])
		for c in ks.get("suits", []):
			if not GameData.classes.has(str(c)):
				out.append("keystone %s suits unknown class '%s'" % [k, c])
	var seen := {}
	var bloodlines := 0
	for tid in _order:
		var t: Dictionary = _trees[tid]
		var cid := str(t.get("class", ""))
		if cid == "":
			bloodlines += 1
		elif not GameData.classes.has(cid) or GameData.classes[cid].has("parents"):
			out.append("tree %s: '%s' is not a base class" % [tid, cid])
		if str(t.get("name", "")) == "":
			out.append("tree %s has no name" % tid)
		var users: Array = []
		for c in GameData.classes:
			if tid in trees_for(c):
				users.append(c)
		var places := {}
		var ids: Array = nodes_of(tid)
		if ids.size() < 12:
			out.append("tree %s has only %d nodes" % [tid, ids.size()])
		for n in t.get("nodes", []):
			var id := str(n.get("id", ""))
			var what := "node %s" % id
			if seen.has(id):
				out.append("%s is defined twice" % what)
			seen[id] = true
			for key in NODE_KEYS:
				if not n.has(key):
					out.append("%s has no %s" % [what, key])
			if not n.has("keystone") and (str(n.get("name", "")) == "" or (n.get("effect", {}) as Dictionary).is_empty()):
				out.append("%s needs a name and an effect" % what)
			if n.has("keystone") and not _keystones.has(str(n["keystone"])):
				out.append("%s: unknown keystone '%s'" % [what, n["keystone"]])
			if n.has("keystone") and int(n.get("max_rank", 1)) != 1:
				out.append("%s: a keystone has one rank" % what)
			if int(n.get("cost", 0)) < 1 or int(n.get("max_rank", 0)) < 1:
				out.append("%s: cost and max_rank are at least 1" % what)
			var spot := "%d,%d" % [int(n.get("tier", 0)), int(n.get("col", 0))]
			if places.has(spot):
				out.append("%s sits on %s at tier %d, column %d" % [what, places[spot], int(n.get("tier", 0)), int(n.get("col", 0))])
			places[spot] = id
			if int(n.get("tier", 0)) < 1 or int(n.get("col", -1)) < 0:
				out.append("%s: tier from 1 and column from 0" % what)
			for r in n.get("requires", []):
				var p := node(str(r))
				if p.is_empty():
					out.append("%s requires unknown node '%s'" % [what, r])
				elif str(p["tree"]) != tid:
					out.append("%s requires %s from another tree" % [what, r])
				elif int(p["tier"]) >= int(n.get("tier", 0)):
					out.append("%s requires %s, which is not on an earlier tier" % [what, r])
				elif bool(n.get("inheritable", false)) and not bool(p.get("inheritable", false)):
					out.append("%s is inheritable but its prerequisite %s is not" % [what, r])
			if bool(n.get("inheritable", false)) and cid != "":
				out.append("%s: only bloodline nodes are inheritable" % what)
			if (n.get("requires", []) as Array).is_empty() and int(n.get("tier", 0)) != 1:
				out.append("%s has no prerequisites but is not on tier 1" % what)
			out.append_array(_effect_problems(what, n.get("effect", {}), users))
		out.append_array(_graph_problems(tid))
	if bloodlines != 1:
		out.append("there must be exactly one bloodline tree (a tree with no class), not %d" % bloodlines)
	for c in GameData.classes:
		if trees_for(c).size() < 2:
			out.append("class %s draws on no class tree" % c)
	return out


## A cycle or a node no path from tier 1 reaches.
static func _graph_problems(tid: String) -> Array:
	var out: Array = []
	var ids := nodes_of(tid)
	var state := {}
	for id in ids:
		if _cycle(id, state):
			out.append("tree %s: the prerequisites of %s run in a circle" % [tid, id])
			break
	var reach := {}
	var grew := true
	while grew:
		grew = false
		for id in ids:
			if reach.has(id):
				continue
			var req: Array = node(id).get("requires", [])
			if req.is_empty() or req.any(func(r): return reach.has(str(r))):
				reach[id] = true
				grew = true
	for id in ids:
		if not reach.has(id):
			out.append("tree %s: nothing leads to %s" % [tid, id])
	return out


static func _cycle(id: String, state: Dictionary) -> bool:
	if int(state.get(id, 0)) == 1:
		return true
	if int(state.get(id, 0)) == 2:
		return false
	state[id] = 1
	for r in node(id).get("requires", []):
		if not node(str(r)).is_empty() and _cycle(str(r), state):
			return true
	state[id] = 2
	return false


## What is wrong with an effect block: unknown stats, upgrades to abilities that do not exist,
## and upgrade fields that mean nothing for every ability they touch.
static func _effect_problems(what: String, e: Dictionary, users: Array) -> Array:
	var out: Array = []
	for k in e:
		if k not in ["stats", "bonus", "abilities"]:
			out.append("%s: unknown effect part '%s'" % [what, k])
	var stats: Dictionary = e.get("stats", {})
	for s in stats:
		if s not in CORE and s != "all":
			out.append("%s: unknown core stat '%s'" % [what, s])
		elif typeof(stats[s]) != TYPE_DICTIONARY or (stats[s] as Dictionary).is_empty() or (stats[s] as Dictionary).keys().any(func(x): return x not in ["flat", "pct"]):
			out.append("%s: stat %s takes flat and/or pct" % [what, s])
	for s in e.get("bonus", {}):
		if s not in BONUS:
			out.append("%s: unknown bonus '%s'" % [what, s])
	for m in e.get("abilities", []):
		var key := _mod_key(m)
		if key == "":
			out.append("%s: an upgrade names a skill, spell or feat" % what)
			continue
		var abs_: Array = _targets(m, users)
		if abs_.is_empty():
			out.append("%s: no ability '%s' for the classes using this tree" % [what, key])
			continue
		for f in m:
			if f in ["skill", "spell", "feat"]:
				continue
			if f not in MODS:
				out.append("%s: unknown upgrade field '%s'" % [what, f])
			elif not abs_.any(func(ab): return fits(ab, f)):
				out.append("%s: '%s' means nothing for %s" % [what, f, key])
	return out


## The abilities an upgrade touches for the classes using a tree (all of them for a keystone).
static func _targets(m: Dictionary, users: Array) -> Array:
	var out: Array = []
	if m.has("skill"):
		for c in users:
			for s in GameData.classes[c]["skills"]:
				if str(s.get("id", "")) == str(m["skill"]) or str(s.get("type", "")) == str(m["skill"]):
					out.append(s)
	elif m.has("spell"):
		for id in GameCombat.spell_ids():
			if str(m["spell"]) == "*" or id == str(m["spell"]):
				out.append(GameCombat.spell(id))
	elif m.has("feat"):
		for id in GameFeats.ids():
			if str(m["feat"]) == "*" or id == str(m["feat"]):
				out.append(GameFeats.def(id))
	return out
