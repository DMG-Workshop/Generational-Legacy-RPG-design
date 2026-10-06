## Combat content and the rules that need no battle in progress: spells and who learns them,
## statuses, elements, the battlefield formation, area shapes and packs. GameBattle runs fights.
## Abilities are plain dictionaries (class skills, spells, later feats) read through here.
class_name GameCombat
extends RefCounted

const ENEMY_SHAPES := ["single", "burst", "cone", "line", "all"]

static var _src: Dictionary = {}
static var _spells: Dictionary = {}
static var _spell_order: Array = []
static var _statuses: Dictionary = {}
static var _creatures: Dictionary = {}
static var _settings: Dictionary = {}
static var _added: Dictionary = {}   # statuses other systems register from their own data files


static func _index() -> void:
	if not _src.is_empty() and is_same(_src, GameData.combat):
		return
	GameData.load_all()
	if is_same(_src, GameData.combat):
		return
	_src = GameData.combat
	_spells.clear()
	_spell_order.clear()
	for s in _src["spells"]["spells"]:
		_spells[s["id"]] = s
		_spell_order.append(s["id"])
	_statuses.clear()
	for s in _src["statuses"]["statuses"]:
		_statuses[s["id"]] = s
	_statuses.merge(_added)
	_creatures.clear()
	for c in GameData.creatures:
		_creatures[c["id"]] = c
	_settings = {}
	for key in ["spells", "statuses", "formations"]:
		_settings.merge(_src[key].get("settings", {}))


static func setting(key: String) -> Variant:
	_index()
	return _settings[key]


## The live settings table (tests and harnesses may override values in it).
static func settings() -> Dictionary:
	_index()
	return _settings


# ---------------------------------------------------------------- content

static func spell(id: String) -> Dictionary:
	_index()
	return _spells.get(id, {})


static func spell_ids() -> Array:
	_index()
	return _spell_order.duplicate()


static func status_def(id: String) -> Dictionary:
	_index()
	return _statuses.get(id, {})


static func status_ids() -> Array:
	_index()
	return _statuses.keys()


## Lets another system bring its own statuses (a disease, a toxin) from its own data file; they
## work everywhere a status from data/combat/statuses.json does.
static func add_statuses(defs: Array) -> void:
	_index()
	for def in defs:
		_added[def["id"]] = def
		_statuses[def["id"]] = def


static func creature_def(id: String) -> Dictionary:
	_index()
	return _creatures.get(id, {})


static func formation() -> Dictionary:
	_index()
	return _src["formations"]


## Level at which a class learns a spell, or -1 if it never does.
static func learn_level(sp: Dictionary, class_id: String) -> int:
	var learn: Dictionary = sp.get("learn", {})
	if class_id not in learn.get("classes", []):
		return -1
	return int(learn.get("levels", {}).get(class_id, learn.get("min_level", 1)))


## Spells a class knows by `level`, earliest first.
static func class_spells(class_id: String, level: int) -> Array:
	_index()
	var out: Array = []
	for id in _spell_order:
		var lv := learn_level(_spells[id], class_id)
		if lv >= 1 and lv <= level:
			out.append(id)
	out.sort_custom(func(a, b): return learn_level(_spells[a], class_id) < learn_level(_spells[b], class_id))
	return out


## Every spell on a class's list with its learning level, earliest first: [[id, level], ...].
static func class_spell_plan(class_id: String) -> Array:
	_index()
	var out: Array = []
	for id in _spell_order:
		var lv := learn_level(_spells[id], class_id)
		if lv >= 1:
			out.append([id, lv])
	out.sort_custom(func(a, b): return a[1] < b[1])
	return out


## Costs grow with level like class skills do, so a level-5000 caster still has to choose.
static func ability_cost(ab: Dictionary, level: int) -> int:
	var growth := float(GameData.bal("skill_cost_growth_per_level"))
	return int(round(float(ab.get("mp", 0)) * (1.0 + growth * float(level - 1))))


static func element_mult(attack: String, defend: String) -> float:
	_index()
	if attack == "" or defend == "":
		return 1.0
	return float(_src["elements"]["matchups"].get(defend, {}).get(attack, 1.0))


static func element_name(el: String) -> String:
	_index()
	return str(_src["elements"]["elements"].get(el, {}).get("name", el.capitalize()))


static func element_color(el: String) -> String:
	_index()
	return str(_src["elements"]["elements"].get(el, {}).get("color", "#ffffff"))


# ---------------------------------------------------------------- shapes

static func shape(ab: Dictionary) -> String:
	return str(ab.get("target", {}).get("shape", "single"))


static func is_aoe(ab: Dictionary) -> bool:
	return bool(ab.get("is_aoe", shape(ab) in ["burst", "cone", "line", "all"]))


## True when the ability is aimed at a foe (single or an area around/through one).
static func aims_at_foe(ab: Dictionary) -> bool:
	return shape(ab) in ENEMY_SHAPES


static func is_control_status(id: String) -> bool:
	return bool(status_def(id).get("control", false))


## Which foes an area covers. `points` maps enemy index -> Vector2 (living foes only); the aimed
## foe is always inside. Returns [[index, damage factor], ...] in index order; the factor is below
## 1 only for shapes with an edge falloff.
static func footprint(ab: Dictionary, origin: Vector2, aim_index: int, points: Dictionary) -> Array:
	var t: Dictionary = ab.get("target", {})
	var sh := shape(ab)
	var aim: Vector2 = points.get(aim_index, origin)
	var falloff := float(t.get("falloff", 0.0))
	var out: Array = []
	var keys: Array = points.keys()
	keys.sort()
	for i in keys:
		var p: Vector2 = points[i]
		var edge := -1.0   # 0 at the centre/axis, 1 at the edge; -1 = outside
		match sh:
			"single":
				edge = 0.0 if i == aim_index else -1.0
			"all":
				edge = 0.0
			"burst":
				var r := float(t.get("radius", 3.0))
				var dist := p.distance_to(aim)
				edge = dist / r if dist <= r + 0.0001 else -1.0
			"cone":
				var reach := float(t.get("range", 16.0))
				var half := deg_to_rad(float(t.get("angle", 60.0)) * 0.5)
				var dir := aim - origin
				var to := p - origin
				if to.length() <= reach + 0.0001 and dir.length() > 0.0:
					var ang := absf(dir.angle_to(to))
					edge = ang / half if ang <= half + 0.0001 else -1.0
			"line":
				var length := float(t.get("length", 18.0))
				var half_w := float(t.get("width", 3.0)) * 0.5
				var d := (aim - origin).normalized()
				var to := p - origin
				var along := to.dot(d)
				var off := absf(to.cross(d))
				if along >= -0.0001 and along <= length + 0.0001 and off <= half_w + 0.0001:
					edge = off / half_w if half_w > 0.0 else 0.0
		if i == aim_index:
			edge = 0.0
		if edge >= 0.0:
			out.append([i, 1.0 - falloff * clampf(edge, 0.0, 1.0)])
	return out


# ---------------------------------------------------------------- formation

static func heir_point() -> Vector2:
	var f: Array = formation()["field"]["heir"]
	return Vector2(float(f[0]), float(f[1]))


static func ally_point(i: int) -> Vector2:
	var slots: Array = formation()["field"]["allies"]
	var s: Array = slots[mini(i, slots.size() - 1)]
	var extra := float(maxi(0, i - slots.size() + 1)) * -2.0   # more allies than slots stand further back
	return Vector2(float(s[0]) + extra, float(s[1]))


## Puts every foe on the field: front row first, creatures that keep back in the back row, and any
## row that is full spills into the other. Writes "row", "x" and "y" (paces) into each foe.
static func place_enemies(enemies: Array) -> void:
	var field: Dictionary = formation()["field"]
	var cap: Dictionary = field["row_max"]
	var rows := {"front": [], "back": []}
	for i in enemies.size():
		var e: Dictionary = enemies[i]
		var want: String = str(e.get("row", creature_def(str(e.get("id", ""))).get("row", "front")))
		if want != "back":
			want = "front"
		var other := "back" if want == "front" else "front"
		if (rows[want] as Array).size() >= int(cap[want]) and (rows[other] as Array).size() < int(cap[other]):
			want = other
		rows[want].append(i)
	var spacing := float(field["spacing"])
	for row in rows:
		var ids: Array = rows[row]
		for k in ids.size():
			var e: Dictionary = enemies[ids[k]]
			e["row"] = row
			e["x"] = float(field["rows"][row])
			e["y"] = (float(k) - float(ids.size() - 1) * 0.5) * spacing


# ---------------------------------------------------------------- packs

## Whether a hunt meets a pack instead of the usual one or two foes: {} or
## {creature, size, power, reward, elite}: multipliers on each member's power, rewards and elite
## chance. The data gives the whole pack's power and reward, shared among its members, so a pack
## weighs about what the usual foes would. Swarm creatures and some places make packs likelier.
static func roll_pack(d: GameDynasty, kind: String, pool: Array) -> Dictionary:
	var packs: Dictionary = formation()["packs"]
	var cfg: Dictionary = packs["kinds"].get(kind, {})
	if cfg.is_empty() or pool.is_empty():
		return {}
	var swarms := pool.filter(func(c): return c.get("swarm", false))
	var chance := float(cfg["chance"])
	if not swarms.is_empty():
		chance += float(packs.get("swarm_bonus", 0.0))
	var bonus := 0.0
	for b in d.world.here().get("biomes", []):
		bonus = maxf(bonus, float(packs.get("biomes", {}).get(b, 0.0)))
	if d.rng.randf() >= chance + bonus:
		return {}
	var from: Array = swarms if not swarms.is_empty() else pool
	var span: Array = cfg["size"]
	var kin: Dictionary = from[d.rng.randi() % from.size()]
	var size := d.rng.randi_range(int(span[0]), int(span[1]))
	return {"creature": kin, "size": size, "power": float(cfg["power"]) / float(size), "reward": float(cfg["reward"]) / float(size),
		"elite": float(cfg.get("elite", 1.0))}


# ---------------------------------------------------------------- text

static func shape_text(ab: Dictionary) -> String:
	var t: Dictionary = ab.get("target", {})
	match shape(ab):
		"burst":
			return "Burst %s" % _num(float(t.get("radius", 3.0)))
		"cone":
			return "Cone %d°" % int(t.get("angle", 60))
		"line":
			return "Line"
		"all":
			return "All foes"
		"party":
			return "Party"
		"self":
			return "Self"
	return "Single"


static func _num(v: float) -> String:
	return str(int(v)) if v == floorf(v) else String.num(v, 2)


## One line on what an ability does, from its data.
static func describe(ab: Dictionary) -> String:
	var parts: Array = []
	var mult := float(ab.get("mult", 0.0))
	if mult > 0.0:
		var el := str(ab.get("element", ""))
		var dmg := "x%s %sdamage" % [_num(mult), (element_name(el) + " ").to_lower() if el != "" else ""]
		if int(ab.get("hits", 1)) > 1:
			dmg = "%d hits of x%s" % [int(ab["hits"]), _num(mult)]
		match shape(ab):
			"burst":
				dmg += " to foes within %s paces of the target" % _num(float(ab["target"].get("radius", 3.0)))
			"cone":
				dmg += " in a %d° cone" % int(ab["target"].get("angle", 60))
			"line":
				dmg += " down a line"
			"all":
				dmg += " to every foe"
		parts.append(dmg)
	if ab.has("pct_max_hp"):
		parts.append("heals %d%%%s" % [int(round(float(ab["pct_max_hp"]) * 100.0)), " to the party" if ab.get("party", false) else ""])
	if ab.get("cleanse", false):
		parts.append("removes harmful effects")
	if ab.get("mana", false):
		parts.append("restores %d%% MP" % int(round(float(setting("mana_tap_pct")) * 100.0)))
	if float(ab.get("drain", 0.0)) > 0.0:
		parts.append("drains %d%%" % int(round(float(ab["drain"]) * 100.0)))
	for st in ab.get("statuses", []):
		var def := status_def(str(st["id"]))
		var chance := float(st.get("chance", 1.0))
		var who: String = {"party": " on the party", "self": " on self"}.get(str(st.get("on", "target")), "")
		var turns := int(st.get("turns", def.get("default_turns", 1)))
		if chance >= 0.999:
			parts.append("%s %dt%s" % [str(def.get("name", st["id"])).to_lower(), turns, who])
		else:
			parts.append("%d%% %s %dt%s" % [int(round(chance * 100.0)), str(def.get("name", st["id"])).to_lower(), turns, who])
	var s := ", ".join(parts)
	if s == "":
		return str(ab.get("text", ""))
	return s if s.begins_with("x") else s.left(1).to_upper() + s.substr(1)
