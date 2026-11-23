## Landmarks of the wilds (data/world/wilds.json): ruins, camps, shrines, wells, farms, caves, standing stones, old battlefields, lairs,
## ore outcrops, herb groves, fishing spots, hermits, merchants and wrecks, placed by area as pure functions of the seed (cells of
## `cell` tiles each holding at most one, and `fixed` ones at an offset from a wilds place's anchor). Nothing of the land is touched
## (a landmark stands only on dry, node-free ground clear of towns, dungeons and plots). The heir finds one by coming within
## `see_range` and can use it once until `renew_gens` generations pass: the outcome is drawn on dice keyed on the seed and the
## landmark, never the dynasty's, and loot comes from GameWildsLoot. What is found and used is `GameDynasty.wilds`, saved only once set.
class_name GameWildsSites
extends RefCounted

const OFFSETS_SEARCH := 6

static var _seed := -1
static var _cells: Dictionary = {}     # Vector2i -> Array of landmarks
static var _foot: Dictionary = {}      # x * 100003 + z -> glyph
static var _by_id: Dictionary = {}
static var _fixed: Array = []
static var _fixed_done := false


static func _def(kind: String) -> Dictionary:
	return GameWilds.data()["landmarks"].get(kind, {})


static func _ensure(d: GameDynasty) -> void:
	if d.seed_value != _seed:
		_seed = d.seed_value
		_cells = {}
		_foot = {}
		_by_id = {}
		_fixed = []
		_fixed_done = false
	if not _fixed_done:
		_fixed_done = true
		_place_fixed(d)


static func _key(x: int, z: int) -> int:
	return x * 100003 + z


static func make_id(x: int, z: int) -> String:
	return "lm:%d:%d" % [x, z]


## The tile an id names, or (-1, -1) for a text that is no landmark id.
static func parse_id(id: String) -> Vector2i:
	var p := id.split(":")
	if p.size() != 3 or p[0] != "lm" or not p[1].is_valid_int() or not p[2].is_valid_int():
		return Vector2i(-1, -1)
	return Vector2i(int(p[1]), int(p[2]))


# ---------------------------------------------------------------- placement

static func _spot_ok(d: GameDynasty, kind: String, x: int, z: int, at_anchor: bool) -> bool:
	var def := _def(kind)
	var size := GameWorldGen.size()
	if x < 4 or z < 4 or x >= size - 4 or z >= size - 4:
		return false
	var water_near := false
	if str(def.get("need", "")) == "water":
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				if GameWorldGen.water_at(d.seed_value, x + dx, z + dz):
					water_near = true
		if not water_near:
			return false
	for off in _footprint(kind, x, z):
		var t := GameWorldGen.tile(d, int(off[0]), int(off[1]))
		if str(t["body"]) != "" or not t["node"].is_empty():
			return false
	for a in GameWorldGen.zones():
		var r := float(a["radius"])
		var dist := Vector2(float(x) - float(a["x"]), float(z) - float(a["z"])).length()
		if r > 0.0:
			var clear := float(GameWilds.setting("dungeon_clear")) if str(a["type"]) == "dungeon" else float(GameWilds.setting("town_clear"))
			if dist < r + clear + 4.0:
				return false
		elif not at_anchor and dist < 4.0:
			return false
	return true


## The tiles a landmark of a kind covers when its center is at (x, z): [[x, z, glyph]].
static func _footprint(kind: String, x: int, z: int) -> Array:
	var def := _def(kind)
	var out: Array = []
	var c: Array = def["center"]
	var rows: Array = def["layout"]
	for j in rows.size():
		for i in (rows[j] as Array).size():
			if str(rows[j][i]) != ".":
				out.append([x + i - int(c[0]), z + j - int(c[1]), str(rows[j][i])])
	return out


static func _register(d: GameDynasty, kind: String, x: int, z: int, area: String) -> Dictionary:
	var biome := GameWorldGen.biome_at(d.seed_value, x, z)
	var lm := {"id": make_id(x, z), "kind": kind, "x": x, "z": z, "area": area, "biome": biome}
	for f in _footprint(kind, x, z):
		var k := _key(int(f[0]), int(f[1]))
		if not _foot.has(k):
			_foot[k] = str(f[2])
	_by_id[lm["id"]] = lm
	return lm


static func _place_fixed(d: GameDynasty) -> void:
	for id in GameWilds.data()["areas"]:
		var a := GameWorldGen.anchor(str(id))
		if a.is_empty():
			continue
		var place: Dictionary = GameWorld.place(str(id))
		for f in GameWilds.data()["areas"][id].get("fixed", []):
			var kind := str(f["kind"])
			if kind == "lair" and str(place.get("lair", "")) == "":
				continue
			var tx := int(a["x"]) + int(f["at"][0])
			var tz := int(a["z"]) + int(f["at"][1])
			var found := Vector2i(-1, -1)
			var at_anchor: bool = int(f["at"][0]) == 0 and int(f["at"][1]) == 0
			for r in range(0, OFFSETS_SEARCH + 1):
				for dz in range(-r, r + 1):
					for dx in range(-r, r + 1):
						if maxi(absi(dx), absi(dz)) != r or found.x >= 0:
							continue
						if _spot_ok(d, kind, tx + dx, tz + dz, at_anchor and r == 0):
							found = Vector2i(tx + dx, tz + dz)
			if found.x >= 0:
				_fixed.append(_register(d, kind, found.x, found.y, str(id)))


## The landmarks of one cell of the grid, worked out once.
static func _cell(d: GameDynasty, cx: int, cz: int) -> Array:
	_ensure(d)
	var key := Vector2i(cx, cz)
	if _cells.has(key):
		return _cells[key]
	var out: Array = []
	_cells[key] = out
	var cell := int(GameWilds.setting("cell"))
	var margin := int(GameWilds.setting("margin"))
	var u := GameWorldGen._lat(d.seed_value, GameWilds.TAG + 60, cx, cz)
	for attempt in int(GameWilds.setting("tries")):
		var px := cx * cell + margin + int(GameWorldGen._lat(d.seed_value, GameWilds.TAG + 61 + attempt * 3, cx, cz) * float(cell - 2 * margin))
		var pz := cz * cell + margin + int(GameWorldGen._lat(d.seed_value, GameWilds.TAG + 62 + attempt * 3, cx, cz) * float(cell - 2 * margin))
		if not GameWorldGen.in_bounds(px, pz):
			continue
		var biome := GameWorldGen.biome_at(d.seed_value, px, pz)
		var area := GameWilds.area_of(px, pz, biome)
		var table: Dictionary = GameWilds.data()["areas"][area]["placement"] if area != "" else GameWilds.data()["placement"].get(biome, {})
		if table.is_empty() or u >= float(table["p"]):
			return out
		var kinds: Dictionary = table["kinds"]
		var names: Array = kinds.keys()
		names.sort()
		var total := 0.0
		for k in names:
			total += float(kinds[k])
		var roll := GameWorldGen._lat(d.seed_value, GameWilds.TAG + 63 + attempt * 3, cx, cz) * total
		var kind := str(names.back())
		for k in names:
			roll -= float(kinds[k])
			if roll < 0.0:
				kind = str(k)
				break
		if not _spot_ok(d, kind, px, pz, false):
			continue
		var gap := float(GameWilds.setting("min_gap"))
		var clash := false
		for f in _fixed:
			if Vector2(float(px - int(f["x"])), float(pz - int(f["z"]))).length() < gap:
				clash = true
		if clash:
			continue
		out.append(_register(d, kind, px, pz, area))
		return out
	return out


static func _cell_of(x: int, z: int) -> Vector2i:
	var cell := int(GameWilds.setting("cell"))
	return Vector2i(floori(float(x) / float(cell)), floori(float(z) / float(cell)))


## The glyph a landmark draws on a tile, or "".
static func glyph_at(d: GameDynasty, x: int, z: int) -> String:
	_ensure(d)
	var c := _cell_of(x, z)
	_cell(d, c.x, c.y)
	return str(_foot.get(_key(x, z), ""))


## Every landmark whose center is within `r` tiles of a point, nearest first.
static func within(d: GameDynasty, fx: float, fz: float, r: float) -> Array:
	_ensure(d)
	var lo := _cell_of(int(floor(fx - r)), int(floor(fz - r)))
	var hi := _cell_of(int(floor(fx + r)), int(floor(fz + r)))
	var found: Array = []
	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			for lm in _cell(d, cx, cz):
				found.append(lm)
	for lm in _fixed:
		found.append(lm)
	var out: Array = []
	for lm in found:
		var dist := Vector2(fx - float(lm["x"]) - 0.5, fz - float(lm["z"]) - 0.5).length()
		if dist <= r:
			out.append({"lm": lm, "dist": dist})
	out.sort_custom(func(a, b): return float(a["dist"]) < float(b["dist"]) or (float(a["dist"]) == float(b["dist"]) and str(a["lm"]["id"]) < str(b["lm"]["id"])))
	return out.map(func(e): return e["lm"])


## The landmark an id names, or {}.
static func get_landmark(d: GameDynasty, id: String) -> Dictionary:
	var t := parse_id(id)
	if t.x < 0:
		return {}
	_ensure(d)
	var c := _cell_of(t.x, t.y)
	_cell(d, c.x, c.y)
	return _by_id.get(id, {})


static func legend_of(lm: Dictionary) -> String:
	return str(GameWorld.place(str(lm.get("area", ""))).get("lair", ""))


static func legend_name(lm: Dictionary) -> String:
	var id := legend_of(lm)
	for c in GameData.creatures:
		if str(c["id"]) == id:
			return str(c["name"])
	return GameWilds.text("legend_unknown")


static func name_of(lm: Dictionary) -> String:
	return str(_def(str(lm["kind"]))["name"]).format({"legend": legend_name(lm)})


static func area_name(lm: Dictionary) -> String:
	var a := str(lm.get("area", ""))
	return str(GameWorld.place(a).get("name", GameWilds.text("in_wilds"))) if a != "" else GameWilds.text("in_wilds")


## The nearest dungeon within `dungeon_near` tiles, {} if none.
static func dungeon_near(lm: Dictionary) -> Dictionary:
	var best := {}
	var best_d := float(GameWilds.setting("dungeon_near"))
	for a in GameWorldGen.anchors():
		if str(a["type"]) != "dungeon":
			continue
		var dist := Vector2(float(lm["x"]) - float(a["x"]), float(lm["z"]) - float(a["z"])).length()
		if dist < best_d:
			best_d = dist
			best = a
	return best


# ---------------------------------------------------------------- what the family has found and used

static func state(d: GameDynasty) -> Dictionary:
	return d.wilds


static func is_found(d: GameDynasty, id: String) -> bool:
	return id in d.wilds.get("found", [])


## The landmarks the family has found, in the order found (those the data no longer has are left out).
static func found(d: GameDynasty) -> Array:
	var out: Array = []
	for id in d.wilds.get("found", []):
		var lm := get_landmark(d, str(id))
		if not lm.is_empty():
			out.append(lm)
	return out


## Marks every landmark within `see_range` of a tile found; returns the ones newly found.
static func discover_near(d: GameDynasty, x: int, z: int) -> Array:
	var fresh: Array = []
	for lm in within(d, float(x) + 0.5, float(z) + 0.5, float(GameWilds.setting("see_range"))):
		if is_found(d, str(lm["id"])):
			continue
		var list: Array = d.wilds.get("found", [])
		if list.size() >= int(GameWilds.setting("found_cap")):
			break
		list.append(str(lm["id"]))
		d.wilds["found"] = list
		fresh.append(lm)
	return fresh


static func used_info(d: GameDynasty, id: String) -> Dictionary:
	return d.wilds.get("used", {}).get(id, {})


## Whether a landmark can be used now: never used, or used `renew_gens` generations ago.
static func available(d: GameDynasty, id: String) -> bool:
	var u := used_info(d, id)
	return u.is_empty() or d.gen - int(u["gen"]) >= int(GameWilds.setting("renew_gens"))


static func _mark_used(d: GameDynasty, id: String) -> void:
	var used: Dictionary = d.wilds.get("used", {})
	used[id] = {"gen": d.gen, "n": int(used.get(id, {}).get("n", 0)) + 1}
	d.wilds["used"] = used


## The state as it loads: only well-formed ids, whole numbers; {} for anything else.
static func load_state(v: Variant) -> Dictionary:
	var out := {}
	if typeof(v) != TYPE_DICTIONARY:
		return out
	var cap := 4000
	if typeof(v.get("found")) == TYPE_ARRAY:
		var list: Array = []
		for id in v["found"]:
			if typeof(id) == TYPE_STRING and parse_id(id).x >= 0 and id not in list and list.size() < cap:
				list.append(id)
		if not list.is_empty():
			out["found"] = list
	if typeof(v.get("used")) == TYPE_DICTIONARY:
		var used := {}
		for id in v["used"]:
			var u: Variant = v["used"][id]
			if typeof(id) == TYPE_STRING and parse_id(id).x >= 0 and typeof(u) == TYPE_DICTIONARY and typeof(u.get("gen")) in [TYPE_INT, TYPE_FLOAT] and typeof(u.get("n")) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(u["gen"])) and is_finite(float(u["n"])) and used.size() < cap:
				used[id] = {"gen": int(u["gen"]), "n": maxi(1, int(u["n"]))}
		if not used.is_empty():
			out["used"] = used
	out.merge(GameWildsFights.load_marks(v))   # fought and cleared (GameWildsFights)
	return out


# ---------------------------------------------------------------- using one

## The landmark within reach of a tile the heir stands on, or {}.
static func near(d: GameDynasty, x: int, z: int) -> Dictionary:
	var list := within(d, float(x) + 0.5, float(z) + 0.5, float(GameWilds.setting("use_reach")))
	return {} if list.is_empty() else list[0]


## The line the place line adds beside a landmark.
static func hint(d: GameDynasty, x: int, z: int) -> String:
	var lm := near(d, x, z)
	if lm.is_empty():
		return ""
	var def := _def(str(lm["kind"]))
	var vals := {"name": name_of(lm), "verb": str(def["verb"]), "done": str(def["done"])}
	return GameWilds.text("hint" if available(d, str(lm["id"])) else "hint_done", vals)


static func _rng(d: GameDynasty, lm: Dictionary, n: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([d.seed_value, "wilds_use", str(lm["id"]), n])
	return r


static func _weighted(r: RandomNumberGenerator, rows: Array) -> Dictionary:
	var total := 0.0
	for o in rows:
		total += float(o["w"])
	var roll := r.randf() * total
	for o in rows:
		roll -= float(o["w"])
		if roll < 0.0:
			return o
	return rows.back()


static func _stock(def: Dictionary, area: String) -> Array:
	var stock: Dictionary = def["stock"]
	return stock[area] if stock.has(area) else stock["default"]


## Uses a landmark: {ok, text, open?}. A trader opens its merchant panel (`open` "merchant"); anything else plays out an outcome once.
static func use(d: GameDynasty, lm: Dictionary) -> Dictionary:
	var id := str(lm["id"])
	var def := _def(str(lm["kind"]))
	var vals := {"heir": d.heir.name, "name": name_of(lm), "legend": legend_name(lm)}
	if not available(d, id):
		return {"ok": false, "text": str(def["done"])}
	var n := int(used_info(d, id).get("n", 0))
	var r := _rng(d, lm, n)
	if GameWildsFights.use_springs(d, lm):   # searching a guarded place may spring its guards (GameWildsFights); the search waits for the win
		var plan := GameWildsFights.plan(d, lm, "use")
		if not plan.is_empty():
			return {"ok": true, "text": str(plan["text"]), "fight": plan, "landmark": lm}
	if bool(def.get("trade", false)):
		return _trade(d, lm, def, vals)
	var rows: Array = def["outcomes"].filter(func(o): return _fits(d, lm, o))
	if rows.is_empty():
		return {"ok": false, "text": GameWilds.text("nothing")}
	var o := _weighted(r, rows)
	var nearest := dungeon_near(lm)
	vals["dungeon"] = str(GameWorld.place(str(nearest["id"])).get("name", "")) if not nearest.is_empty() else GameWilds.text("dungeon_none")
	vals["dungeon_line"] = GameWilds.text("dungeon_line", vals) if not nearest.is_empty() else ""
	if o.has("gold"):
		var base := float(r.randi_range(int(o["gold"][0]), int(o["gold"][1])))
		var amount := int(round(base * GameData.enemy_scale(d.gen)))
		if amount < 0:
			amount = -mini(d.heir.gold, -amount)
		d.heir.gold += amount
		vals["gold"] = absi(amount)
	if o.has("ore") or o.has("material"):
		var mat := ""
		var cnt := 0
		if o.has("ore"):
			var ores: Array = GameWilds.data()["ores"].get(str(lm["biome"]), []).filter(func(x): return int(x["gen"]) <= d.gen)
			mat = str(ores[r.randi() % ores.size()]["id"]) if not ores.is_empty() else "iron"
			cnt = r.randi_range(int(o["ore"][0]), int(o["ore"][1]))
		else:
			mat = str(o["material"]["id"])
			cnt = r.randi_range(int(o["material"]["n"][0]), int(o["material"]["n"][1]))
		GameCraft.add_material(d, mat, cnt)
		vals["n"] = cnt
		vals["material"] = GameMaterials.name_of(mat).to_lower()
	if o.has("hurt"):
		d.heir.hp = maxi(1, d.heir.hp - int(ceil(float(d.heir.max_hp()) * float(o["hurt"]))))
	if bool(o.get("heal", false)):
		d.heir.full_heal()
		d.party.rest(d)
	if o.has("potion"):
		d.heir.potions += int(o["potion"])
	if o.has("xp"):
		d.heir.gain_xp(int(round(float(GameData.bal("train_xp")) * GameData.xp_level_scale(d.heir.level) * float(o["xp"]))))
	if o.has("loot"):
		var item := GameWildsLoot.roll(d, str(lm["area"]), id, str(lm["kind"]), {"boost": float(o["loot"]), "n": n, "biome": str(lm["biome"]), "slots": o.get("slots", {})})
		vals["item"] = GameWildsLoot.give(d, item)["name"] if item != "" else "a few small things"
	_mark_used(d, id)
	var line := str(o["text"]).format(vals).strip_edges()
	d._say(line)
	return {"ok": true, "text": line}


static func _fits(d: GameDynasty, lm: Dictionary, o: Dictionary) -> bool:
	if o.has("areas") and str(lm["area"]) not in o["areas"]:
		return false
	if o.has("biomes") and str(lm["biome"]) not in o["biomes"]:
		return false
	if o.has("if"):
		var stirring := false
		var legend := legend_of(lm)
		for c in d.stirring_legends():
			if str(c["id"]) == legend:
				stirring = true
		return stirring == (str(o["if"]) == "legend_stirring")
	return true


## A trader opens its panel (GameWildsTrade: wares, selling and barter, none of which uses the landmark up): {ok, text, open: "merchant", site}.
static func _trade(d: GameDynasty, lm: Dictionary, def: Dictionary, vals: Dictionary) -> Dictionary:
	var line := GameWilds.text("merchant_open", vals)
	return {"ok": true, "text": line, "open": "merchant", "site": str(lm["id"]), "landmark": lm}
