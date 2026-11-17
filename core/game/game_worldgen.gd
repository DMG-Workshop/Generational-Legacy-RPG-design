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
static var _roads: Array = []
static var _surf: Dictionary = {}   # tile key -> [biome, height] (see _surface)
static var _surf_seed := -1
const SURFACE_KEEP := 150000


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
		_anchors = []
		_roads = []
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


## The roads of the text game as straight lines between their two anchors: [ax, az, bx, bz] each, once for each pair (a road
## listed from both ends is one). Water that a road crosses is shallow there (see `_water`), so no river or lake can cut one
## place off from the rest.
static func roads() -> Array:
	GameData.load_all()
	if _roads.is_empty():
		var seen := {}
		for l in GameData.world["locations"]:
			for link in l.get("links", []):
				var a := str(l["id"])
				var b := str(link["to"])
				var key := a + ">" + b if a < b else b + ">" + a
				if seen.has(key):
					continue
				seen[key] = true
				var pa := anchor(a)
				var pb := anchor(b)
				if not pa.is_empty() and not pb.is_empty():
					_roads.append([float(pa["x"]), float(pa["z"]), float(pb["x"]), float(pb["z"])])
	return _roads


## How far a point is from the nearest road (a very large number with no roads).
static func road_distance(x: float, z: float) -> float:
	var best := 1e18
	var p := Vector2(x, z)
	for r in roads():
		var a := Vector2(float(r[0]), float(r[1]))
		var ab := Vector2(float(r[2]), float(r[3])) - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


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


## The biome, surface height, body of water and (for a lake) how far its bed lies under its banks, of a tile, worked out once:
## [biome, height, body, depth] (body: "" dry land, "sea",
## "lake", "river", or "ford", a shallow crossing of a river that can be walked). A view asks for a tile and its neighbours
## (relief is the difference between them), so each tile is kept for the next ask. Kept for one seed at a time and let go when
## it grows past SURFACE_KEEP; it holds nothing the seed and the tile do not give, so a cleared cache changes nothing.
static func _surface(seed_value: int, x: int, z: int) -> Array:
	if seed_value != _surf_seed or _surf.size() > SURFACE_KEEP:
		_surf.clear()
		_surf_seed = seed_value
	var key := x * 2097152 + z
	var hit: Variant = _surf.get(key)
	if hit != null:
		return hit
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
	var wet := _water(seed_value, x, z, h, near)
	h = float(wet[0])
	var body := str(wet[1])
	var final := clampi(int(round(h)), 0, int(setting("max_height")))
	if body == "" and final < int(setting("sea_level")):
		body = "sea"
	var out: Array = [str(land["biome"]), final, body, int(round(float(wet[2])))]
	_surf[key] = out
	return out


## Lakes, rivers and fords on land of height `h` (before any water): [height, body]. Rivers follow the zero-crossings of a
## large noise field (a ridge where it crosses 0.5), only where a second noise says the land is wet and thinning to nothing up
## the heights (they start in the hills), with a valley carved along them; lakes fill the basins of a third noise on low
## ground; a ford is a stretch of river a fourth noise leaves shallow, and wherever one of the text game's roads crosses a river
## or a lake the water is shallow too (a causeway `road_width` either side), so no water cuts a road, and with the roads
## joining every place the land stays joined. Nothing within a
## town's or dungeon's reach of an anchor: its ground is dry and flat, and the anchors can all be reached. A valley is never
## carved under the sea; only a river's channel and a lake go under.
static func _water(seed_value: int, x: int, z: int, h: float, near: Dictionary) -> Array:   # [height, body, lake depth]
	var w: Dictionary = setting("water")
	var sea := float(setting("sea_level"))
	if h < sea:
		return [h, "", 0.0]
	var a: Dictionary = near["anchor"]
	var calm := smoothstep(float(w["clear_inner"]) + float(a["radius"]), float(w["clear_outer"]) + float(a["radius"]), float(near["dist"]))
	if calm <= 0.0:
		return [h, "", 0.0]
	var fx := float(x)
	var fz := float(z)
	var out := h
	var body := ""
	var carved_lake := 0.0
	var lowland := 1.0 - smoothstep(float(w["lake_land_max"]) - 12.0, float(w["lake_land_max"]), h)
	if lowland > 0.0:
		var basin := _fbm(seed_value, 61, fx, fz, float(w["lake_scale"]), int(w["lake_octaves"]))
		var depth := smoothstep(float(w["lake_threshold"]), float(w["lake_threshold"]) + float(w["lake_band"]), basin) * lowland * calm
		if depth > 0.0:
			out -= float(w["lake_depth"]) * depth
			carved_lake = float(w["lake_depth"]) * depth
			if depth >= float(w["lake_water_at"]):
				body = "lake"
	if body != "lake":
		out = maxf(out, sea)   # the rim of a lake slopes down to it but is never a pit under the sea (that would ring a low-lying place with sea)
	var up := 1.0 - smoothstep(float(w["river_fade_from"]), float(w["river_fade_to"]), h)
	if up > 0.0:
		var wet := smoothstep(float(w["wet_from"]), float(w["wet_to"]), _fbm(seed_value, 53, fx, fz, float(w["wet_scale"]), 2))
		var reach := wet * up * calm
		if reach > 0.0:
			var u := _fbm(seed_value, 51, fx, fz, float(w["river_scale"]), int(w["river_octaves"]))
			var off := absf(u - 0.5) * 2.0
			var valley := float(w["valley_width"]) * reach
			if off < valley:
				var t := 1.0 - off / valley
				var carved := h - float(w["valley_depth"]) * t * t * (3.0 - 2.0 * t)
				out = minf(out, maxf(carved, minf(h, sea)))
				if body == "" and off < float(w["river_width"]) * reach:
					body = "ford" if _fbm(seed_value, 67, fx, fz, float(w["ford_scale"]), 1) >= float(w["ford_threshold"]) else "river"
	if (body == "river" or body == "lake") and road_distance(fx, fz) <= float(w["road_width"]):
		body = "ford"   # a road crosses here: shallows to wade, a causeway
	if body == "river" or body == "ford":
		out = maxf(out, sea)   # a river's bed is never under the sea (a lake's can be); a ford is never a pit
	return [out, body, carved_lake if body == "lake" else 0.0]


## The surface height of a tile: the blended base plus fractal noise, flattened near a town or dungeon and pulled under the
## sea at the edge of the world.
static func height_at(seed_value: int, x: int, z: int) -> int:
	return int(_surface(seed_value, x, z)[1])


## The body of water on a tile: "" (dry land), "sea", "lake", "river" or "ford".
static func body_at(seed_value: int, x: int, z: int) -> String:
	return str(_surface(seed_value, x, z)[2])


## Whether a tile is under water a walker cannot cross: sea, lake or river. A ford is shallow and can be walked.
static func water_at(seed_value: int, x: int, z: int) -> bool:
	return is_water(body_at(seed_value, x, z))


static func is_water(body: String) -> bool:
	return body == "sea" or body == "lake" or body == "river"


## The biome of a tile.
static func biome_at(seed_value: int, x: int, z: int) -> String:
	return str(_surface(seed_value, x, z)[0])


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
		return {"x": x, "z": z, "biome": "ocean", "height": int(setting("sea_level")) - 8, "water": true, "body": "sea", "depth": 8, "node": {}, "place": ""}
	var here := _surface(d.seed_value, x, z)
	var h := int(here[1])
	var body := str(here[2])
	var water := is_water(body)
	var place := ""
	for a in anchors():
		if x == int(a["x"]) and z == int(a["z"]):
			place = str(a["id"])
	return {"x": x, "z": z, "biome": str(here[0]), "height": h, "water": water, "body": body, "depth": int(here[3]), "node": node_at(d, x, z, str(here[0]), water), "place": place}


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

## Problems in settings.water (lakes, rivers and fords).
static func _water_problems(s: Dictionary) -> Array:
	var bad: Array = []
	if not s.has("water") or typeof(s["water"]) != TYPE_DICTIONARY:
		return ["worldgen.json: settings.water is missing"]
	var w: Dictionary = s["water"]
	for k in ["clear_inner", "clear_outer", "wet_scale", "wet_from", "wet_to", "river_scale", "river_octaves", "river_width", "river_fade_from", "river_fade_to", "valley_width", "valley_depth", "lake_scale", "lake_octaves", "lake_threshold", "lake_band", "lake_depth", "lake_land_max", "lake_water_at", "ford_scale", "ford_threshold", "road_width"]:
		if not w.has(k):
			bad.append("worldgen.json: settings.water.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if float(w["clear_inner"]) < 1.0 or float(w["clear_outer"]) <= float(w["clear_inner"]):
		bad.append("worldgen.json: water clear_inner must be at least 1 and clear_outer above it (an anchor's tile must stay dry)")
	for k in ["wet_scale", "river_scale", "lake_scale", "ford_scale"]:
		if float(w[k]) <= 0.0:
			bad.append("worldgen.json: water %s must be above 0" % k)
	for k in ["river_octaves", "lake_octaves"]:
		if int(w[k]) < 1:
			bad.append("worldgen.json: water %s must be at least 1" % k)
	if float(w["wet_from"]) < 0.0 or float(w["wet_to"]) <= float(w["wet_from"]) or float(w["wet_to"]) > 1.0:
		bad.append("worldgen.json: water wet_from and wet_to must run up within 0 to 1")
	if float(w["river_width"]) <= 0.0 or float(w["river_width"]) >= 0.5:
		bad.append("worldgen.json: water river_width must be above 0 and under 0.5")
	if float(w["valley_width"]) < float(w["river_width"]) or float(w["valley_width"]) >= 1.0:
		bad.append("worldgen.json: water valley_width must be at least river_width and under 1")
	if float(w["valley_depth"]) < 0.0 or float(w["valley_depth"]) >= float(s["sea_level"]):
		bad.append("worldgen.json: water valley_depth must be 0 or more and less than the sea level")
	if float(w["river_fade_from"]) <= float(s["sea_level"]) or float(w["river_fade_to"]) <= float(w["river_fade_from"]):
		bad.append("worldgen.json: water river_fade_from must be above the sea and river_fade_to above it")
	if float(w["lake_threshold"]) <= 0.0 or float(w["lake_band"]) <= 0.0 or float(w["lake_threshold"]) + float(w["lake_band"]) > 1.0:
		bad.append("worldgen.json: water lake_threshold and lake_band must be above 0 and together at most 1")
	if float(w["lake_depth"]) <= 0.0 or float(w["lake_water_at"]) <= 0.0 or float(w["lake_water_at"]) > 1.0:
		bad.append("worldgen.json: water lake_depth must be above 0 and lake_water_at within 0 to 1")
	if float(w["lake_land_max"]) <= float(s["sea_level"]):
		bad.append("worldgen.json: water lake_land_max must be above the sea level")
	if float(w["road_width"]) < 1.0 or float(w["road_width"]) > 6.0:
		bad.append("worldgen.json: water road_width must be 1 to 6 (a road's causeway must be wide enough to walk, with room for a diagonal)")
	if float(w["ford_threshold"]) <= 0.0 or float(w["ford_threshold"]) >= 1.0:
		bad.append("worldgen.json: water ford_threshold must be within 0 and 1 (a river with no fords cuts the land in two)")
	return bad


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
	bad.append_array(_water_problems(s))
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
