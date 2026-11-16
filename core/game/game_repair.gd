## Damage to what the family has built, and mending it (roadmap item 50). A piece can be damaged, a level at a time up to
## `max_damage` (data/world/building.json, "repair"); at the top it is wrecked and removed, and whatever rested on it
## falls too (GameBuild.collapse). A damaged roof no longer covers its room (GameBuild.rooms_on). Mending costs
## `repair_share` of the piece's cost for each level of damage, in the family's stores and gold. Damage comes from raids
## that look at built pieces (the vandals, GameRaids). Saved on the dynasty only when something is damaged. No dice here:
## the caller picks the pieces (GameRaids keys its roll on the seed, never the dynasty's).
class_name GameRepair
extends RefCounted


static func setting(key: String) -> Variant:
	return GameBuild.data()["repair"][key]


## A piece's damage, 0 when it is whole.
static func level(d: GameDynasty, x: int, y: int, z: int) -> int:
	return int(d.damage.get(GameBuild.key(x, y, z), 0))


## The damaged pieces' keys, sorted.
static func damaged(d: GameDynasty) -> Array:
	var ks: Array = d.damage.keys()
	ks.sort()
	return ks


## Hurts a piece by `n` levels. At `max_damage` it is wrecked: removed (nothing refunded) with whatever then hangs.
## Returns {ok, wrecked, fell, text}.
static func hurt(d: GameDynasty, x: int, y: int, z: int, n: int = 1) -> Dictionary:
	var k := GameBuild.key(x, y, z)
	var kind := str(d.built.get(k, ""))
	if kind == "" or n <= 0:
		return {"ok": false, "wrecked": false, "fell": 0, "text": ""}
	var piece := str(GameBuild.pieces()[kind]["name"]).to_lower()
	var lv := mini(int(setting("max_damage")), int(d.damage.get(k, 0)) + n)
	if lv < int(setting("max_damage")):
		d.damage[k] = lv
		return {"ok": true, "wrecked": false, "fell": 0, "text": GameBuild.text("damaged_piece", {"piece": piece})}
	d.built.erase(k)
	d.damage.erase(k)
	var fell := GameBuild.collapse(d)
	var line := GameBuild.text("ruined", {"piece": piece})
	if fell > 0:
		line += " " + GameBuild.text("collapsed", {"n": fell})
	return {"ok": true, "wrecked": true, "fell": fell, "text": line}


## What mending a piece would cost: {materials: {id: n}, gold}, from its level of damage.
static func cost(d: GameDynasty, x: int, y: int, z: int) -> Dictionary:
	var kind := GameBuild.kind_at(d, x, y, z)
	var lv := level(d, x, y, z)
	if kind == "" or lv <= 0:
		return {"materials": {}, "gold": 0}
	var p: Dictionary = GameBuild.pieces()[kind]
	var mats := {}
	for m in p["cost"]:
		mats[str(m)] = maxi(1, int(ceil(float(p["cost"][m]) * float(setting("repair_share")) * lv)))
	var gold := int(ceil(float(p["gold"]) * float(setting("repair_share")) * lv))
	if mats.is_empty():
		gold = maxi(gold, int(setting("repair_gold_min")) * lv)
	return {"materials": mats, "gold": gold}


## Why a piece cannot be mended, or "".
static func why_not(d: GameDynasty, x: int, y: int, z: int) -> String:
	if level(d, x, y, z) <= 0:
		return GameBuild.text("undamaged")
	var c := cost(d, x, y, z)
	for m in c["materials"]:
		if GameCraft.have(d, str(m)) < int(c["materials"][m]):
			return GameBuild.text("repair_missing", {"material": GameMaterials.name_of(str(m)).to_lower(), "need": int(c["materials"][m]), "have": GameCraft.have(d, str(m))})
	if int(c["gold"]) > d.heir.gold:
		return GameBuild.text("repair_gold", {"need": int(c["gold"])})
	return ""


## Mends a piece: spends the cost and clears the damage. {ok, text}.
static func repair(d: GameDynasty, x: int, y: int, z: int) -> Dictionary:
	var why := why_not(d, x, y, z)
	if why != "":
		return {"ok": false, "text": why}
	var c := cost(d, x, y, z)
	for m in c["materials"]:
		GameCraft.add_material(d, str(m), -int(c["materials"][m]))
	d.heir.gold -= int(c["gold"])
	var kind := GameBuild.kind_at(d, x, y, z)
	d.damage.erase(GameBuild.key(x, y, z))
	return {"ok": true, "text": GameBuild.text("repaired", {"piece": str(GameBuild.pieces()[kind]["name"]).to_lower()})}


## Vandals strike `vandal_hits` pieces, picked from the built ones with `r` (the caller's keyed dice). Returns the lines.
static func vandalise(d: GameDynasty, r: RandomNumberGenerator) -> Array:
	var ks: Array = d.built.keys()
	ks.sort()
	var lines: Array = []
	for i in int(setting("vandal_hits")):
		if ks.is_empty():
			break
		var k: String = ks[r.randi() % ks.size()]
		ks.erase(k)
		var c: Vector3i = GameBuild.parse(k)
		var out := hurt(d, c.x, c.y, c.z)
		if bool(out["ok"]):
			lines.append(str(out["text"]))
	return lines


## The saved damage, checked: a built piece's key and a level from 1 up to just under the wreck. Anything else is dropped.
static func load_state(v: Variant, built: Dictionary) -> Dictionary:
	var out := {}
	if typeof(v) != TYPE_DICTIONARY:
		return out
	for k in v:
		if not built.has(str(k)) or typeof(v[k]) not in [TYPE_INT, TYPE_FLOAT]:
			continue
		var lv := int(v[k])
		if lv >= 1 and lv < int(setting("max_damage")):
			out[str(k)] = lv
	return out


static func validate() -> Array:
	var bad: Array = []
	var s: Variant = GameBuild.data().get("repair", null)
	if typeof(s) != TYPE_DICTIONARY:
		return ["building.json: repair is missing"]
	for k in ["max_damage", "repair_share", "repair_gold_min", "vandal_hits", "built_piece_value"]:
		if not s.has(k):
			bad.append("building.json: repair.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if int(s["max_damage"]) < 2:
		bad.append("building.json: repair.max_damage must be at least 2 (a piece is damaged before it is wrecked)")
	if float(s["repair_share"]) <= 0.0 or float(s["repair_share"]) > 1.0:
		bad.append("building.json: repair.repair_share must be above 0 and at most 1")
	if int(s["repair_gold_min"]) < 1 or int(s["vandal_hits"]) < 1 or int(s["built_piece_value"]) < 0:
		bad.append("building.json: repair_gold_min and vandal_hits must be at least 1, built_piece_value 0 or more")
	return bad
