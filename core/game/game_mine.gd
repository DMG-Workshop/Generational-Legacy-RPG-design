## Mining as data (roadmap item 45). Nothing here draws a picture: it says what the ground is. A site (a place, by id) has
## its own ground, the same for the same dynasty seed. Depth y counts down from 0, the first cell under the surface.
## The ground is rock layers (hardness, and whether ore forms there) in three zones (Surface, Underground, The Deep);
## digging down goes back in time (`age_at`). Ore grows in veins: each block of ground may hold one vein, a sphere of ore
## whose kind comes from the depth bands in data/mining/mining.json (the deeper, the rarer and the better). Digging a cell
## takes effort, yields the ore into the family's stores (GameCraft) and adds strain to the shaft's region; strain changes
## the ground (softer rock, fatter veins) until the last stage opens a gateway to the underworld at the cell that tipped
## it. A cell can be dug only beside open air or an earlier cell, so a shaft is a connected hole. Everything is a pure
## function of the seed, the site and the dug cells: no dice are drawn, nothing is keyed on the dynasty's, and the
## autopilot never digs. The dug cells are saved as runs per column, only once something is dug.
class_name GameMine
extends RefCounted

const PATH := "res://data/mining/mining.json"

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


# ---------------------------------------------------------------- the ground

## The rock at a depth: the last layer that starts at or above it.
static func layer_at(y: int) -> Dictionary:
	var out: Dictionary = data()["layers"][0]
	for l in data()["layers"]:
		if y >= int(l["from"]):
			out = l
	return out


static func zone_at(y: int) -> Dictionary:
	var out: Dictionary = data()["zones"][0]
	for z in data()["zones"]:
		if y >= int(z["from"]):
			out = z
	return out


## Digging down goes back in time: the Age a depth belongs to (the dynasty's own Age at the surface, one older for every
## `depth_per_age` below it, and 0, before the first Age, at the bottom).
static func age_at(d: GameDynasty, y: int) -> int:
	return maxi(0, d.age_number() - y / maxi(1, int(setting("depth_per_age"))))


# ---------------------------------------------------------------- ore

static func _unit(d: GameDynasty, site: String, a: int, b: int, c: int, tag: String) -> float:
	return float(absi(hash([d.seed_value, site, a, b, c, tag])) % 1000003) / 1000003.0


static func _floor_div(a: int, b: int) -> int:
	return int(floor(float(a) / float(b)))


## The vein a block may hold: {ore, centre, radius} or {} for none. The block's depth picks the candidates, the weights
## pick one, and its chance says whether the block holds it at all.
static func vein_in(d: GameDynasty, site: String, bx: int, by: int, bz: int) -> Dictionary:
	var block := int(setting("block"))
	var cy := float(by * block) + float(block) * 0.5
	var cands: Array = []
	var total := 0.0
	for o in data()["ores"]:
		if cy >= float(o["from"]) and cy <= float(o["to"]):
			cands.append(o)
			total += float(o["weight"])
	if cands.is_empty():
		return {}
	var roll := _unit(d, site, bx, by, bz, "ore") * total
	var pick: Dictionary = cands.back()
	for o in cands:
		roll -= float(o["weight"])
		if roll < 0.0:
			pick = o
			break
	if _unit(d, site, bx, by, bz, "here") >= float(pick["chance"]):
		return {}
	var centre := Vector3(
		float(bx * block) + float(block) * (0.2 + 0.6 * _unit(d, site, bx, by, bz, "x")),
		float(by * block) + float(block) * (0.2 + 0.6 * _unit(d, site, bx, by, bz, "y")),
		float(bz * block) + float(block) * (0.2 + 0.6 * _unit(d, site, bx, by, bz, "z")))
	return {"ore": str(pick["material"]), "centre": centre, "radius": float(pick["radius"])}


## The ore in a cell before anything is dug: "" for plain rock. `bonus` fattens the veins (see the stages).
static func ore_at(d: GameDynasty, site: String, x: int, y: int, z: int, bonus: float = 0.0) -> String:
	if y < 0 or y > int(setting("max_depth")) or not bool(layer_at(y)["ore"]):
		return ""
	var block := int(setting("block"))
	var bx := _floor_div(x, block)
	var by := _floor_div(y, block)
	var bz := _floor_div(z, block)
	var here := Vector3(float(x) + 0.5, float(y) + 0.5, float(z) + 0.5)
	var best := ""
	var best_ratio := 1e9
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				var v := vein_in(d, site, bx + dx, by + dy, bz + dz)
				if v.is_empty():
					continue
				var reach: float = float(v["radius"]) * (1.0 + bonus)
				var ratio: float = here.distance_to(v["centre"]) / reach
				if ratio <= 1.0 and ratio < best_ratio:
					best_ratio = ratio
					best = str(v["ore"])
	return best


## The ore in a cell as the ground is now: the veins of its region are as fat as the region's strain makes them.
static func ore_here(d: GameDynasty, site: String, x: int, y: int, z: int) -> String:
	return ore_at(d, site, x, y, z, float(stage_of(strain_at(d, site, x, z))["ore_bonus"]))


# ---------------------------------------------------------------- the dug ground and its strain

static func _state(d: GameDynasty, site: String) -> Dictionary:
	return d.mine.get(site, {})


static func _col(x: int, z: int) -> String:
	return "%d,%d" % [x, z]


static func region_key(x: int, z: int) -> String:
	var r := int(setting("region"))
	return "%d,%d" % [_floor_div(x, r), _floor_div(z, r)]


static func is_dug(d: GameDynasty, site: String, x: int, y: int, z: int) -> bool:
	for run in _state(d, site).get("dug", {}).get(_col(x, z), []):
		if y >= int(run[0]) and y <= int(run[1]):
			return true
	return false


static func dug_count(d: GameDynasty, site: String) -> int:
	var n := 0
	for col in _state(d, site).get("dug", {}):
		for run in _state(d, site)["dug"][col]:
			n += int(run[1]) - int(run[0]) + 1
	return n


static func _mark(st: Dictionary, x: int, y: int, z: int) -> void:
	var dug: Dictionary = st.get("dug", {})
	var runs: Array = dug.get(_col(x, z), [])
	runs.append([y, y])
	dug[_col(x, z)] = _merge(runs)
	st["dug"] = dug


static func _merge(runs: Array) -> Array:
	runs.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	var out: Array = []
	for r in runs:
		if not out.is_empty() and int(r[0]) <= int(out.back()[1]) + 1:
			out.back()[1] = maxi(int(out.back()[1]), int(r[1]))
		else:
			out.append([int(r[0]), int(r[1])])
	return out


## The strain in the region that holds a column.
static func strain_at(d: GameDynasty, site: String, x: int, z: int) -> float:
	return float(_state(d, site).get("strain", {}).get(region_key(x, z), 0.0))


## The stage a strain has reached: the last stage that starts at or below it.
static func stage_of(strain: float) -> Dictionary:
	var out: Dictionary = data()["stages"][0]
	for s in data()["stages"]:
		if strain >= float(s["at"]):
			out = s
	return out


static func gateways(d: GameDynasty, site: String) -> Array:
	return _state(d, site).get("gateways", [])


static func gateway_in(d: GameDynasty, site: String, x: int, z: int) -> bool:
	var key := region_key(x, z)
	for g in gateways(d, site):
		if str(g["region"]) == key:
			return true
	return false


## How much effort one cell takes: the rock's hardness (eased by strain) against the digger's Strength.
static func effort(d: GameDynasty, site: String, x: int, y: int, z: int, strength: float) -> int:
	var l := layer_at(y)
	var s := stage_of(strain_at(d, site, x, z))
	var e := float(l["hardness"]) * float(s["hardness_mult"]) / (1.0 + strength * float(setting("effort_per_strength")))
	return maxi(1, int(ceil(e)))


## Whether a cell can be dug now: {ok, why}. It must be underground and within reach, not dug already, and beside open
## air (the surface above depth 0) or a dug cell.
static func can_dig(d: GameDynasty, site: String, x: int, y: int, z: int) -> Dictionary:
	if y < 0:
		return {"ok": false, "why": text("above")}
	if y > int(setting("max_depth")):
		return {"ok": false, "why": text("too_deep", {"max": setting("max_depth")})}
	if is_dug(d, site, x, y, z):
		return {"ok": false, "why": text("already")}
	if y > 0:
		var open := false
		for n in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			if is_dug(d, site, x + n.x, y + n.y, z + n.z):
				open = true
		if not open:
			return {"ok": false, "why": text("closed")}
	return {"ok": true, "why": ""}


## Digs one cell. Returns {ok, why, layer, ore, qty, effort, strain, stage, stage_changed, gateway, lines}. The ore goes into
## the family's stores. `strength` is the digger's Strength (the heir's by default).
static func dig(d: GameDynasty, site: String, x: int, y: int, z: int, strength: float = -1.0) -> Dictionary:
	var can := can_dig(d, site, x, y, z)
	if not can["ok"]:
		return {"ok": false, "why": can["why"], "lines": []}
	var st: Dictionary = d.mine.get(site, {})
	var power := strength if strength >= 0.0 else (d.heir.stat("str") if d.heir != null else 0.0)
	var l := layer_at(y)
	var cost := effort(d, site, x, y, z, power)
	var ore := ore_here(d, site, x, y, z)
	var qty := 0
	if ore != "":
		var span := int(setting("yield_max")) - int(setting("yield_min")) + 1
		qty = int(setting("yield_min")) + int(_unit(d, site, x, y, z, "qty") * float(span))
		GameCraft.add_material(d, ore, qty)
	_mark(st, x, y, z)
	var key := region_key(x, z)
	var strains: Dictionary = st.get("strain", {})
	var before: Dictionary = stage_of(float(strains.get(key, 0.0)))
	var add := float(setting("base_strain")) + maxf(0.0, float(y - int(setting("strain_from_depth")))) * float(setting("strain_per_depth"))
	strains[key] = float(strains.get(key, 0.0)) + add
	st["strain"] = strains
	var after := stage_of(float(strains[key]))
	var out := {"ok": true, "why": "", "layer": str(l["id"]), "ore": ore, "qty": qty, "effort": cost, "strain": float(strains[key]), "stage": str(after["id"]), "stage_changed": str(before["id"]) != str(after["id"]), "gateway": false, "lines": []}
	var name := d.heir.name if d.heir != null else "Someone"
	out["lines"].append(text("dug", {"h": name, "layer": str(l["name"]).to_lower(), "ore": text("ore", {"n": qty, "material": GameMaterials.name_of(ore).to_lower()}) if ore != "" else ""}))
	if out["stage_changed"]:
		out["lines"].append(text("stage", {"stage": str(after["name"]).to_lower(), "about": str(after["about"])}))
	if str(after["id"]) == str(setting("gateway_stage")) and not gateway_in(d, site, x, z):
		var gates: Array = st.get("gateways", [])
		gates.append({"region": key, "at": [x, y, z]})
		st["gateways"] = gates
		out["gateway"] = true
		out["lines"].append(text("gateway"))
	d.mine[site] = st
	return out


# ---------------------------------------------------------------- saving

## The mine as it is saved: only known shapes, in range, merged; {} for anything else.
static func load_state(v: Variant) -> Dictionary:
	var out := {}
	if typeof(v) != TYPE_DICTIONARY:
		return out
	var max_y := int(setting("max_depth"))
	var col_re := RegEx.new()
	col_re.compile("^-?\\d+,-?\\d+$")
	for site in v:
		var src: Variant = v[site]
		if typeof(src) != TYPE_DICTIONARY or str(site) == "":
			continue
		var st := {}
		var dug := {}
		var srcd: Variant = src.get("dug", {})
		if typeof(srcd) == TYPE_DICTIONARY:
			for col in srcd:
				if col_re.search(str(col)) == null or typeof(srcd[col]) != TYPE_ARRAY:
					continue
				var runs: Array = []
				for run in srcd[col]:
					if typeof(run) == TYPE_ARRAY and run.size() == 2 and typeof(run[0]) in [TYPE_INT, TYPE_FLOAT] and typeof(run[1]) in [TYPE_INT, TYPE_FLOAT]:
						var a := int(run[0])
						var b := int(run[1])
						if a >= 0 and b >= a and b <= max_y:
							runs.append([a, b])
				if not runs.is_empty():
					dug[str(col)] = _merge(runs)
		if not dug.is_empty():
			st["dug"] = dug
		var strains := {}
		var srcs: Variant = src.get("strain", {})
		if typeof(srcs) == TYPE_DICTIONARY:
			for key in srcs:
				if col_re.search(str(key)) != null and typeof(srcs[key]) in [TYPE_INT, TYPE_FLOAT] and float(srcs[key]) > 0.0:
					strains[str(key)] = float(srcs[key])
		if not strains.is_empty():
			st["strain"] = strains
		var gates: Array = []
		var srcg: Variant = src.get("gateways", [])
		if typeof(srcg) == TYPE_ARRAY:
			for g in srcg:
				if typeof(g) == TYPE_DICTIONARY and col_re.search(str(g.get("region", ""))) != null and typeof(g.get("at")) == TYPE_ARRAY and g["at"].size() == 3:
					var ok := true
					for n in g["at"]:
						if typeof(n) not in [TYPE_INT, TYPE_FLOAT]:
							ok = false
					if ok:
						gates.append({"region": str(g["region"]), "at": [int(g["at"][0]), int(g["at"][1]), int(g["at"][2])]})
		if not gates.is_empty():
			st["gateways"] = gates
		if not st.is_empty():
			out[str(site)] = st
	return out


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = data()
	for k in ["settings", "zones", "layers", "ores", "stages", "text"]:
		if not dat.has(k):
			bad.append("mining.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var s: Dictionary = dat["settings"]
	for k in ["max_depth", "block", "region", "base_strain", "strain_per_depth", "strain_from_depth", "effort_per_strength", "yield_min", "yield_max", "depth_per_age", "gateway_stage"]:
		if not s.has(k):
			bad.append("mining.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if int(s["max_depth"]) < 1 or int(s["block"]) < 4 or int(s["region"]) < 1 or int(s["depth_per_age"]) < 1:
		bad.append("mining.json: max_depth, region and depth_per_age must be positive and block at least 4")
	if int(s["yield_min"]) < 1 or int(s["yield_max"]) < int(s["yield_min"]):
		bad.append("mining.json: yield_min must be at least 1 and yield_max at least yield_min")
	for group in ["zones", "layers"]:
		var rows: Array = dat[group]
		if rows.is_empty() or int(rows[0]["from"]) != 0:
			bad.append("mining.json: %s must be listed from depth 0" % group)
		for i in range(1, rows.size()):
			if int(rows[i]["from"]) <= int(rows[i - 1]["from"]):
				bad.append("mining.json: %s must go deeper in order" % group)
		var seen := {}
		for r in rows:
			if seen.has(str(r.get("id", ""))) or str(r.get("id", "")) == "":
				bad.append("mining.json: a %s id is blank or repeated" % group)
			seen[str(r.get("id", ""))] = true
	for l in dat["layers"]:
		if float(l.get("hardness", 0.0)) <= 0.0 or typeof(l.get("ore")) != TYPE_BOOL:
			bad.append("mining.json: layer '%s' needs a positive hardness and an ore flag" % l.get("id", ""))
	var max_bonus := 0.0
	var prev_at := -1.0
	for st in dat["stages"]:
		if float(st.get("at", -1.0)) <= prev_at and not (prev_at < 0.0 and float(st["at"]) == 0.0):
			bad.append("mining.json: stages must rise from 0")
		prev_at = float(st.get("at", -1.0))
		if float(st.get("hardness_mult", 0.0)) <= 0.0 or float(st.get("hardness_mult", 2.0)) > 1.0 or float(st.get("ore_bonus", -1.0)) < 0.0:
			bad.append("mining.json: stage '%s' needs a hardness_mult above 0 and at most 1 and an ore_bonus of 0 or more" % st.get("id", ""))
		max_bonus = maxf(max_bonus, float(st.get("ore_bonus", 0.0)))
	if float(dat["stages"][0]["at"]) != 0.0:
		bad.append("mining.json: the first stage must start at strain 0")
	if str(dat["stages"].back()["id"]) != str(s["gateway_stage"]):
		bad.append("mining.json: the last stage must be the gateway stage")
	GameData.load_all()
	for o in dat["ores"]:
		if not GameMaterials.has(str(o.get("material", ""))):
			bad.append("mining.json: an ore names the unknown material '%s'" % o.get("material", ""))
		if float(o.get("weight", 0.0)) <= 0.0 or float(o.get("chance", 0.0)) <= 0.0 or float(o.get("chance", 2.0)) > 1.0:
			bad.append("mining.json: ore '%s' needs a positive weight and a chance above 0 and at most 1" % o.get("material", ""))
		if int(o.get("from", -1)) < 0 or int(o.get("to", -1)) < int(o.get("from", 0)) or int(o.get("to", 0)) > int(s["max_depth"]):
			bad.append("mining.json: ore '%s' has a depth band outside 0 to max_depth" % o.get("material", ""))
		if float(o.get("radius", 0.0)) * (1.0 + max_bonus) >= float(s["block"]):
			bad.append("mining.json: ore '%s' could grow past the blocks beside it (its radius with the largest ore_bonus must be under one block)" % o.get("material", ""))
	# no dead ground: every depth where ore can form has some ore band
	var first_ore := -1
	for l in dat["layers"]:
		if l["ore"] and first_ore < 0:
			first_ore = int(l["from"])
	for y in range(maxi(first_ore, 0), int(s["max_depth"]) + 1, 4):
		if bool(layer_at(y)["ore"]) and not dat["ores"].any(func(o): return y >= int(o["from"]) and y <= int(o["to"])):
			bad.append("mining.json: no ore can form at depth %d" % y)
			break
	for k in ["dug", "ore", "stage", "gateway", "too_deep", "above", "already", "closed"]:
		if not dat["text"].has(k):
			bad.append("mining.json: text.%s is missing" % k)
	return bad
