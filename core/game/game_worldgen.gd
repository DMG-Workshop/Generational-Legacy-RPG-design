## World generation from the dynasty's seed (roadmap item 46). The sandbox world is a grid of tiles laid over the authored
## map in data/world/world.json: each of its places is an anchor, a fixed point the generator never moves or contradicts, so
## the text game's map and the sandbox agree. Between the anchors the land is the same for the same seed: the biome at a
## tile comes from its nearest anchors (the border wobbles with a noise warp that fades to nothing at an anchor), the height
## blends the nearest biomes' heights with fractal noise, and the sea takes what falls below the sea level and the edge of
## the world. Towns and dungeons are flat and clear of nodes around the anchor. Nodes (trees, plants, bones, ore outcrops)
## are placed tile by tile from the biome's table and a clumping noise; an outcrop shows only where the mining ground
## (GameMine) has ore close under the surface. Every value is a pure function of the seed and the tile: no dice of the
## dynasty's are drawn, nothing is saved, and the autopilot never asks. Data: data/world/worldgen.json.
class_name GameWorldGen
extends RefCounted

const PATH := "res://data/world/worldgen.json"
const MINE_SITE := "world"

static var _cache: Dictionary = {}
static var _anchors: Array = []


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
		_anchors = []
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


## How many tiles wide and deep the world is.
static func size() -> int:
	return int(setting("map_size")) * int(setting("scale"))


## The anchors: one for each authored place, at its map position (x and y times the scale, to the middle of its square).
static func anchors() -> Array:
	GameData.load_all()
	if _anchors.is_empty():
		var scale := int(setting("scale"))
		for l in GameData.world["locations"]:
			var surface := "plains"
			for b in l.get("biomes", []):
				var mapped := str(data()["surface_of"].get(str(b), ""))
				if mapped != "":
					surface = mapped
					break
			_anchors.append({"id": str(l["id"]), "type": str(l["type"]), "name": str(l["name"]), "biome": surface,
				"x": float(int(l["x"]) * scale + scale / 2), "z": float(int(l["y"]) * scale + scale / 2),
				"radius": int(setting("anchor_radius").get(str(l["type"]), 0))})
	return _anchors


static func anchor(place_id: String) -> Dictionary:
	for a in anchors():
		if a["id"] == place_id:
			return a
	return {}


# ---------------------------------------------------------------- noise

## A number from 0 up to (not including) 1 for a seed, a tag and a lattice point. The Godot `hash` of nearby integers is
## correlated (two tags a few apart give near-equal numbers), so the bits are mixed here: independent for each tag.
static func _lat(seed_value: int, tag: int, ix: int, iz: int) -> float:
	var h := (seed_value & 0xFFFFFFFF) * 374761393 + tag * 668265263 + ix * 2246822519 + iz * 3266489917
	h &= 0xFFFFFFFF
	h = ((h ^ (h >> 15)) * 2246822519) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 3266489917) & 0xFFFFFFFF
	h = (h ^ (h >> 16)) & 0xFFFFFFFF
	return float(h) / 4294967296.0


static func _noise(seed_value: int, tag: int, x: float, z: float) -> float:
	var ix := int(floor(x))
	var iz := int(floor(z))
	var fx := x - float(ix)
	var fz := z - float(iz)
	var sx := fx * fx * (3.0 - 2.0 * fx)
	var sz := fz * fz * (3.0 - 2.0 * fz)
	var a := lerpf(_lat(seed_value, tag, ix, iz), _lat(seed_value, tag, ix + 1, iz), sx)
	var b := lerpf(_lat(seed_value, tag, ix, iz + 1), _lat(seed_value, tag, ix + 1, iz + 1), sx)
	return lerpf(a, b, sz)


## Fractal noise from 0 to 1: `octaves` layers, each half the size and half the weight of the one before.
static func _fbm(seed_value: int, tag: int, x: float, z: float, scale: float, octaves: int) -> float:
	var total := 0.0
	var norm := 0.0
	var amp := 1.0
	var freq := 1.0 / scale
	for i in octaves:
		total += amp * _noise(seed_value, tag + i * 7, x * freq, z * freq)
		norm += amp
		amp *= 0.5
		freq *= 2.0
	return total / norm


# ---------------------------------------------------------------- the land

## The nearest anchor to a point and its distance (unwarped).
static func nearest_anchor(x: float, z: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d := 1e18
	for a in anchors():
		var dist := Vector2(x - float(a["x"]), z - float(a["z"])).length()
		if dist < best_d:
			best_d = dist
			best = a
	return {"anchor": best, "dist": best_d}


## What the land at a point is made of: {biome, base, amp}. The biome is that of the nearest anchor once the point is warped
## (the warp fades to nothing at an anchor, so an anchor's own ground is its own biome); the base and amp blend the
## nearest few anchors' biomes, so the heights run into each other without cliffs.
static func blend(seed_value: int, x: float, z: float) -> Dictionary:
	var near := nearest_anchor(x, z)
	var fade := clampf(float(near["dist"]) / float(setting("anchor_lock")), 0.0, 1.0)
	var amp_w := float(setting("warp_amp")) * fade
	var wx := x + (_fbm(seed_value, 11, x, z, float(setting("warp_scale")), 2) - 0.5) * 2.0 * amp_w
	var wz := z + (_fbm(seed_value, 13, x, z, float(setting("warp_scale")), 2) - 0.5) * 2.0 * amp_w
	var ranked: Array = []
	for a in anchors():
		ranked.append([Vector2(wx - float(a["x"]), wz - float(a["z"])).length(), a])
	ranked.sort_custom(func(p, q): return p[0] < q[0])
	var biomes: Dictionary = data()["biomes"]
	var wsum := 0.0
	var base := 0.0
	var amp := 0.0
	for i in mini(int(setting("blend_nearest")), ranked.size()):
		var w := 1.0 / pow(float(ranked[i][0]) + 1.0, float(setting("blend_power")))
		var b: Dictionary = biomes[str(ranked[i][1]["biome"])]
		wsum += w
		base += w * float(b["base"])
		amp += w * float(b["amp"])
	return {"biome": str(ranked[0][1]["biome"]), "base": base / wsum, "amp": amp / wsum}


## The surface height of a tile: the blended base plus fractal noise, flattened near a town or dungeon and pulled under the
## sea at the edge of the world.
static func height_at(seed_value: int, x: int, z: int) -> int:
	var fx := float(x)
	var fz := float(z)
	var land := blend(seed_value, fx, fz)
	var n := _fbm(seed_value, 21, fx, fz, float(setting("height_scale")), int(setting("height_octaves")))
	var h: float = float(land["base"]) + (n - 0.5) * 2.0 * float(land["amp"])
	var near := nearest_anchor(fx, fz)
	var a: Dictionary = near["anchor"]
	var r := float(a["radius"])
	if r > 0.0 and float(near["dist"]) < r * 2.0:
		var f := clampf((float(near["dist"]) - r) / r, 0.0, 1.0)
		f = f * f * (3.0 - 2.0 * f)
		h = lerpf(float(data()["biomes"][str(a["biome"])]["base"]), h, f)
	var edge := mini(mini(x, z), mini(size() - 1 - x, size() - 1 - z))
	var shore := int(setting("shore"))
	if edge < shore:
		h = lerpf(float(setting("sea_level")) - 6.0, h, float(edge) / float(shore))
	return clampi(int(round(h)), 0, int(setting("max_height")))


static func in_bounds(x: int, z: int) -> bool:
	return x >= 0 and z >= 0 and x < size() and z < size()


## Whether a tile is inside an anchor's cleared ground (a town's flat, a dungeon's mouth).
static func in_anchor_ground(x: int, z: int) -> bool:
	var near := nearest_anchor(float(x), float(z))
	return float(near["anchor"]["radius"]) > 0.0 and float(near["dist"]) <= float(near["anchor"]["radius"])


## The node on a tile: {kind, name, material, amount} or {}. Placed from the biome's table and a clumping noise; never on
## water, and never on a town's or dungeon's cleared ground. An outcrop is shown only where the mining ground has ore
## within a few cells of the surface, and its material is that ore.
static func node_at(d: GameDynasty, x: int, z: int, biome: String, water: bool) -> Dictionary:
	if water or biome == "ocean" or in_anchor_ground(x, z):
		return {}
	var seed_value := d.seed_value
	var table: Dictionary = data()["biomes"][biome]["nodes"]
	var total := 0.0
	var kinds: Array = table.keys()
	kinds.sort()
	for k in kinds:
		total += float(table[k])
	var clump := lerpf(float(setting("clump_min")), float(setting("clump_max")), _noise(seed_value, 31, float(x) / float(setting("clump_scale")), float(z) / float(setting("clump_scale"))))
	var u := _lat(seed_value, 41, x, z)
	if u >= total * clump:
		return {}
	var roll := _lat(seed_value, 43, x, z) * total
	var pick: String = str(kinds.back())
	for k in kinds:
		roll -= float(table[k])
		if roll < 0.0:
			pick = str(k)
			break
	var def: Dictionary = data()["nodes"][pick]
	var material := str(def["material"])
	if pick == "outcrop":
		material = ""
		for y in setting("outcrop_depths"):
			var ore := GameMine.ore_at(d, MINE_SITE, x, int(y), z)
			if ore != "":
				material = ore
				break
		if material == "":
			return {}
	var span := int(def["max"]) - int(def["min"]) + 1
	return {"kind": pick, "name": str(def["name"]), "material": material, "amount": int(def["min"]) + int(_lat(seed_value, 47, x, z) * float(span))}


## One tile of the world: {x, z, biome, height, water, node, place}. Outside the world is ocean.
static func tile(d: GameDynasty, x: int, z: int) -> Dictionary:
	if not in_bounds(x, z):
		return {"x": x, "z": z, "biome": "ocean", "height": int(setting("sea_level")) - 8, "water": true, "node": {}, "place": ""}
	var land := blend(d.seed_value, float(x), float(z))
	var h := height_at(d.seed_value, x, z)
	var water := h < int(setting("sea_level"))
	var place := ""
	for a in anchors():
		if x == int(a["x"]) and z == int(a["z"]):
			place = str(a["id"])
	return {"x": x, "z": z, "biome": str(land["biome"]), "height": h, "water": water, "node": node_at(d, x, z, str(land["biome"]), water), "place": place}


## A square of tiles: {cx, cz, size, tiles (rows of z, each a row of x), summary {biomes, nodes, water}}.
static func chunk(d: GameDynasty, cx: int, cz: int) -> Dictionary:
	var n := int(setting("chunk"))
	var rows: Array = []
	var biomes := {}
	var nodes := {}
	var water := 0
	for dz in n:
		var row: Array = []
		for dx in n:
			var t := tile(d, cx * n + dx, cz * n + dz)
			row.append(t)
			biomes[t["biome"]] = int(biomes.get(t["biome"], 0)) + 1
			if not t["node"].is_empty():
				nodes[t["node"]["kind"]] = int(nodes.get(t["node"]["kind"], 0)) + 1
			if t["water"]:
				water += 1
		rows.append(row)
	return {"cx": cx, "cz": cz, "size": n, "tiles": rows, "summary": {"biomes": biomes, "nodes": nodes, "water": water}}


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = data()
	for k in ["settings", "surface_of", "biomes", "nodes"]:
		if not dat.has(k):
			bad.append("worldgen.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var s: Dictionary = dat["settings"]
	for k in ["scale", "map_size", "chunk", "sea_level", "max_height", "height_octaves", "height_scale", "warp_scale", "warp_amp", "anchor_lock", "blend_nearest", "blend_power", "shore", "clump_scale", "clump_min", "clump_max", "outcrop_depths", "anchor_radius"]:
		if not s.has(k):
			bad.append("worldgen.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if int(s["scale"]) < 16 or int(s["map_size"]) < 1 or int(s["chunk"]) < 4 or int(s["blend_nearest"]) < 1 or int(s["height_octaves"]) < 1:
		bad.append("worldgen.json: scale must be at least 16, map_size 1, chunk 4, blend_nearest 1 and height_octaves 1")
	if float(s["height_scale"]) <= 0.0 or float(s["warp_scale"]) <= 0.0 or float(s["clump_scale"]) <= 0.0 or float(s["anchor_lock"]) <= 0.0:
		bad.append("worldgen.json: the noise scales and anchor_lock must be above 0")
	if float(s["clump_min"]) < 0.0 or float(s["clump_max"]) < float(s["clump_min"]):
		bad.append("worldgen.json: clump_min must be 0 or more and clump_max at least clump_min")
	if int(s["sea_level"]) < 1 or int(s["sea_level"]) >= int(s["max_height"]):
		bad.append("worldgen.json: sea_level must be above 0 and below max_height")
	if int(s["shore"]) < 1 or int(s["shore"]) * 2 >= int(s["scale"]) * int(s["map_size"]):
		bad.append("worldgen.json: shore must be at least 1 and less than half the world")
	for ty in ["town", "dungeon", "wilds"]:
		if not s["anchor_radius"].has(ty) or int(s["anchor_radius"][ty]) < 0:
			bad.append("worldgen.json: anchor_radius.%s is missing or negative" % ty)
	if int(s["anchor_radius"].get("town", 0)) < 1:
		bad.append("worldgen.json: a town needs a cleared radius")
	for y in s["outcrop_depths"]:
		if int(y) < 0 or int(y) > int(GameMine.setting("max_depth")):
			bad.append("worldgen.json: an outcrop depth is outside the mining ground")
	GameData.load_all()
	var surface := {}
	for b in dat["surface_of"].values():
		surface[str(b)] = true
	for b in surface:
		if not dat["biomes"].has(b):
			bad.append("worldgen.json: surface_of names the biome '%s', which has no entry in biomes" % b)
	for b in dat["biomes"]:
		var def: Dictionary = dat["biomes"][b]
		if not surface.has(b):
			bad.append("worldgen.json: the biome '%s' is the surface of nothing" % b)
		var lo := float(def.get("base", -1.0)) - float(def.get("amp", 0.0))
		var hi := float(def.get("base", -1.0)) + float(def.get("amp", 0.0))
		if lo < 0.0 or hi > float(s["max_height"]) or float(def.get("amp", -1.0)) < 0.0:
			bad.append("worldgen.json: biome '%s' can be higher or lower than the world allows" % b)
		var total := 0.0
		for k in def.get("nodes", {}):
			if not dat["nodes"].has(k):
				bad.append("worldgen.json: biome '%s' has the unknown node '%s'" % [b, k])
			total += float(def["nodes"][k])
		if total > 0.5:
			bad.append("worldgen.json: biome '%s' fills more than half its tiles with nodes" % b)
	for k in dat["nodes"]:
		var n: Dictionary = dat["nodes"][k]
		if str(n.get("material", "x")) != "" and not GameMaterials.has(str(n.get("material", ""))):
			bad.append("worldgen.json: node '%s' is of the unknown material '%s'" % [k, n.get("material", "")])
		if int(n.get("min", 0)) < 1 or int(n.get("max", 0)) < int(n.get("min", 1)):
			bad.append("worldgen.json: node '%s' needs an amount of at least 1" % k)
	# every authored biome has a surface
	for l in GameData.world["locations"]:
		var any := false
		for b in l.get("biomes", []):
			if dat["surface_of"].has(str(b)):
				any = true
		if not any:
			bad.append("worldgen.json: the place '%s' has no biome with a surface" % l["id"])
		if int(l["x"]) < 0 or int(l["y"]) < 0 or int(l["x"]) >= int(s["map_size"]) or int(l["y"]) >= int(s["map_size"]):
			bad.append("worldgen.json: the place '%s' is off the map (map_size %s)" % [l["id"], s["map_size"]])
	return bad
