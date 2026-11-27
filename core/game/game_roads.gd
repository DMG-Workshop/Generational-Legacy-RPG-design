## Roads, trails and signposts of the open world (data/world/roads.json). GameWorldGen already lays a straight road between each pair of
## linked places (`roads()`); this is how they are seen and walked. A tile is road when it lies close to one of those lines on dry land
## outside a place's own ground: it is drawn as a worn trail (the 16 glyphs `trail_<mask>`, by which neighbours are road) and the heir
## takes a little less time between steps on it (`pace`). Signposts stand beside the road: out of each place on each road that leaves
## it (`end`), outside each town gate (`gate`) and where two roads cross away from a place (`cross`), each naming the places and how far
## they are. Cosmetic and convenient only: GameWorldGen.tile, height, water and node answer exactly as before, every value is a pure
## function of the seed and the tile (no die of the dynasty's), and nothing is saved. The autopilot never walks the open world.
## Run: godot --headless --path . -s res://tests/test_game_roads.gd
class_name GameRoads
extends RefCounted

const PATH := "res://data/world/roads.json"
const MASKS := 16

static var _cache: Dictionary = {}
static var _links: Array = []
static var _lane_memo: Dictionary = {}       # tile key -> whether the tile lies on a road line (geometry only: no seed)
static var _posts: Array = []
static var _post_at: Dictionary = {}         # tile key -> post
static var _posts_seed := -1
static var _glyphs: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
		_links = []
		_lane_memo = {}
		_posts = []
		_post_at = {}
		_posts_seed = -1
		_glyphs = {}
	return _cache


static func setting(key: String) -> float:
	return float(data()["settings"][key])


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


static func _key(x: int, z: int) -> int:
	return x * 2097152 + z


# ---------------------------------------------------------------- the links

## The road links in the order of GameWorldGen.roads(): [{a, b (place ids), ax, az, bx, bz, length}].
static func links() -> Array:
	GameData.load_all()
	data()
	if _links.is_empty():
		var seen := {}
		for l in GameData.world["locations"]:
			for link in l.get("links", []):
				var a := str(l["id"])
				var b := str(link["to"])
				var key := a + ">" + b if a < b else b + ">" + a
				if seen.has(key):
					continue
				seen[key] = true
				var pa := GameWorldGen.anchor(a)
				var pb := GameWorldGen.anchor(b)
				if not pa.is_empty() and not pb.is_empty():
					_links.append({"a": a, "b": b, "ax": float(pa["x"]), "az": float(pa["z"]), "bx": float(pb["x"]), "bz": float(pb["z"]),
						"length": Vector2(float(pa["x"]), float(pa["z"])).distance_to(Vector2(float(pb["x"]), float(pb["z"])))})
	return _links


static func _line_distance(l: Dictionary, p: Vector2) -> float:
	var a := Vector2(float(l["ax"]), float(l["az"]))
	var ab := Vector2(float(l["bx"]), float(l["bz"])) - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Whether a tile lies on a road line (geometry alone, a hash of the tile making the edge ragged): the same for every seed.
static func lane(x: int, z: int) -> bool:
	var key := _key(x, z)
	var hit: Variant = _lane_memo.get(key)
	if hit != null:
		return bool(hit)
	var reach := setting("half_width") + setting("wobble") * 0.5
	var p := Vector2(float(x), float(z))
	var found := false
	for l in links():
		if p.x < minf(float(l["ax"]), float(l["bx"])) - reach or p.x > maxf(float(l["ax"]), float(l["bx"])) + reach:
			continue
		if p.y < minf(float(l["az"]), float(l["bz"])) - reach or p.y > maxf(float(l["az"]), float(l["bz"])) + reach:
			continue
		var limit := setting("half_width") + (GameWorldGen._lat(0, 91, x, z) - 0.5) * setting("wobble")
		if _line_distance(l, p) <= limit:
			found = true
			break
	_lane_memo[key] = found
	return found


## Whether a tile is a road: on a road line, dry land, and not on the ground of a place or plot.
static func on_road(d: GameDynasty, x: int, z: int) -> bool:
	if not GameWorldGen.in_bounds(x, z) or not lane(x, z):
		return false
	if GameWorldGen.body_at(d.seed_value, x, z) != "" or GameWorldGen.in_anchor_ground(x, z):
		return false
	return true


## The times the usual step takes on a tile: `pace` on a road, 1 elsewhere.
static func pace_at(d: GameDynasty, x: int, z: int) -> float:
	return setting("pace") if on_road(d, x, z) else 1.0


## The pace under the heir on the open world's ground (1 indoors, upstairs and in a dungeon).
static func pace_for(sb: GameSandbox) -> float:
	if sb.space != "world" or sb.storey() > 0:
		return 1.0
	return pace_at(sb.d, sb.heir.x, sb.heir.y)


# ---------------------------------------------------------------- the trail's look

## The mask of a road tile: which of its four neighbours (N 1, E 2, S 4, W 8) are road.
static func mask_at(d: GameDynasty, x: int, z: int) -> int:
	var m := 0
	if on_road(d, x, z - 1):
		m |= 1
	if on_road(d, x + 1, z):
		m |= 2
	if on_road(d, x, z + 1):
		m |= 4
	if on_road(d, x - 1, z):
		m |= 8
	return m


## The glyph a road tile is drawn with ("trail_<mask>"), "" for a tile that is not road.
static func trail_at(d: GameDynasty, x: int, z: int) -> String:
	return "trail_%d" % mask_at(d, x, z) if on_road(d, x, z) else ""


## Every glyph this adds to the tile view: the sixteen trails (made here from `trail`) and the data's own (the signpost).
static func glyphs() -> Dictionary:
	data()
	if _glyphs.is_empty():
		for m in MASKS:
			_glyphs["trail_%d" % m] = _trail_glyph(m)
		for id in data()["glyphs"]:
			_glyphs[str(id)] = data()["glyphs"][id]
	return _glyphs


static func glyph_ids() -> Array:
	var out: Array = glyphs().keys()
	out.sort()
	return out


## A trail's 8 by 8 look for a mask: filled, with a ragged fading edge on each side that has no road beside it, and ruts and grit
## scattered by a hash of the pixel and the mask (never random: the same every time).
static func _trail_glyph(mask: int) -> Dictionary:
	var t: Dictionary = data()["trail"]
	var rows: Array = []
	for y in 8:
		var row := ""
		for x in 8:
			var h := int(GameWorldGen._lat(mask, 97, x, y) * 100.0)
			var open_n := y == 0 and (mask & 1) == 0
			var open_s := y == 7 and (mask & 4) == 0
			var open_w := x == 0 and (mask & 8) == 0
			var open_e := x == 7 and (mask & 2) == 0
			var ch := "a"
			if open_n or open_s or open_w or open_e:
				ch = "e" if h < int(t["edge_share"]) else "."
			elif h < int(t["rut_share"]):
				ch = "r"
			elif h >= 100 - int(t["grit_share"]):
				ch = "g"
			row += ch
		rows.append(row)
	return {"rows": rows, "palette": {"a": t["body"], "r": t["rut"], "g": t["grit"], "e": t["edge"]}}


# ---------------------------------------------------------------- signposts

static func _way(v: Vector2) -> String:
	var ang := fposmod(rad_to_deg(atan2(v.x, -v.y)), 360.0)   # 0 north, clockwise
	var names := ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
	return str(data()["text"]["ways"][names[int(round(ang / 45.0)) % 8]])


static func _name_of(id: String) -> String:
	return str(GameWorldGen.anchor(id).get("name", id))


## The line of a sign naming a place from a point: {id, place, n (tiles), way}.
static func _line(id: String, from: Vector2) -> Dictionary:
	var a := GameWorldGen.anchor(id)
	var to := Vector2(float(a["x"]), float(a["z"]))
	return {"id": id, "place": str(a["name"]), "n": int(round(from.distance_to(to))), "way": _way(to - from)}


## The ground of a place that a post stands outside of: a town's wall, else the anchor's cleared radius.
static func _ground(id: String) -> float:
	var a := GameWorldGen.anchor(id)
	var r := float(a.get("radius", 0))
	if id in GameWalls.walled():
		r = maxf(r, GameWalls.radius(id))
	return r


## Whether a post may stand on a tile: dry, free of a node, a road, a wall or a place's ground, and not taken.
static func _free(d: GameDynasty, x: int, z: int, taken: Dictionary) -> bool:
	if not GameWorldGen.in_bounds(x, z) or taken.has(_key(x, z)) or lane(x, z):
		return false
	if GameWorldGen.body_at(d.seed_value, x, z) != "" or GameWorldGen.in_anchor_ground(x, z) or GameWalls.cleared(x, z) or GameWalls.kind_at(x, z) != "":
		return false
	return GameWorldGen.node_at(d, x, z, GameWorldGen.biome_at(d.seed_value, x, z), false).is_empty()


## The nearest free tile to a point within `search` tiles (ties by the order of the scan), or (-1, -1).
static func _spot(d: GameDynasty, p: Vector2, taken: Dictionary) -> Vector2i:
	var s := int(setting("search"))
	var cx := int(round(p.x))
	var cz := int(round(p.y))
	var best := Vector2i(-1, -1)
	var best_d := 1e18
	for dz in range(-s, s + 1):
		for dx in range(-s, s + 1):
			var dist := Vector2(float(dx), float(dz)).length()
			if dist < best_d and _free(d, cx + dx, cz + dz, taken):
				best_d = dist
				best = Vector2i(cx + dx, cz + dz)
	return best


static func _side(l: Dictionary, salt: String) -> float:
	return 1.0 if GameWorldGen._lat(hash(salt) & 0xFFFF, 93, int(l["ax"]), int(l["bz"])) < 0.5 else -1.0


## Every signpost of the world for the dynasty's seed: [{id, kind ("end", "gate" or "cross"), x, z, here, lines: [{id, place, n, way}]}].
static func posts(d: GameDynasty) -> Array:
	data()
	if _posts_seed == d.seed_value and not _posts.is_empty():
		return _posts
	_posts_seed = d.seed_value
	_posts = []
	_post_at = {}
	var taken := {}
	var add := func(kind: String, tile: Vector2i, here: String, lines: Array) -> void:
		if tile.x < 0:
			return
		taken[_key(tile.x, tile.y)] = true
		var post := {"id": "sign:%d,%d" % [tile.x, tile.y], "kind": kind, "x": tile.x, "z": tile.y, "here": here, "lines": lines}
		_posts.append(post)
		_post_at[_key(tile.x, tile.y)] = post
	var lm := int(setting("lines_max"))
	for l in links():
		for end in 2:
			var here := str(l["a"]) if end == 0 else str(l["b"])
			var other := str(l["b"]) if end == 0 else str(l["a"])
			var a := GameWorldGen.anchor(here)
			var at := Vector2(float(a["x"]), float(a["z"]))
			var to := Vector2(float(GameWorldGen.anchor(other)["x"]), float(GameWorldGen.anchor(other)["z"]))
			var dir := (to - at).normalized()
			var p := at + dir * (_ground(here) + setting("gap")) + Vector2(-dir.y, dir.x) * setting("side") * _side(l, "end" + here + other)
			var lines: Array = [_line(here, p), _line(other, p)]
			add.call("end", _spot(d, p, taken), _name_of(here), lines)
	for g in GameWalls.all_gates():
		var place := str(g["place"])
		var out: Vector2i = g["outer"]
		var dir2 := Vector2(g["dir"])
		var q := Vector2(float(out.x), float(out.y)) + dir2 * setting("gap") + Vector2(-dir2.y, dir2.x) * setting("side")
		var lines2: Array = []
		var mine: Array = []
		for l in links():
			if str(l["a"]) == place:
				mine.append(str(l["b"]))
			elif str(l["b"]) == place:
				mine.append(str(l["a"]))
		var near: Array = mine.map(func(id): return _line(str(id), q))
		near.sort_custom(func(m, n): return int(m["n"]) < int(n["n"]))
		lines2.append(_line(place, q))
		lines2.append_array(near.slice(0, lm - 1))
		add.call("gate", _spot(d, q, taken), _name_of(place), lines2)
	var ls := links()
	for i in ls.size():
		for j in range(i + 1, ls.size()):
			var x: Variant = Geometry2D.segment_intersects_segment(Vector2(float(ls[i]["ax"]), float(ls[i]["az"])), Vector2(float(ls[i]["bx"]), float(ls[i]["bz"])), Vector2(float(ls[j]["ax"]), float(ls[j]["az"])), Vector2(float(ls[j]["bx"]), float(ls[j]["bz"])))
			if x == null:
				continue
			var cross: Vector2 = x
			var near_place := false
			for a in GameWorldGen.anchors():
				if Vector2(float(a["x"]), float(a["z"])).distance_to(cross) < _ground(str(a["id"])) + setting("cross_min_gap"):
					near_place = true
			if near_place:
				continue
			var ends: Array = []
			for id in [ls[i]["a"], ls[i]["b"], ls[j]["a"], ls[j]["b"]]:
				if str(id) not in ends:
					ends.append(str(id))
			var lines3: Array = ends.map(func(id): return _line(str(id), cross))
			add.call("cross", _spot(d, cross + Vector2(setting("side"), 0.0), taken), text("sign_cross"), lines3.slice(0, lm))
	return _posts


## The post on a tile, or {}.
static func post_at(d: GameDynasty, x: int, z: int) -> Dictionary:
	posts(d)
	return _post_at.get(_key(x, z), {})


## The post within `reach` tiles of a point (tile coordinates, centre of the tile at +0.5), the nearest first; {} for none.
static func post_near(d: GameDynasty, fx: float, fz: float, reach: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d := reach + 0.001
	for p in posts(d):
		var dist := Vector2(float(p["x"]) + 0.5, float(p["z"]) + 0.5).distance_to(Vector2(fx, fz))
		if dist < best_d:
			best_d = dist
			best = p
	return best


## The posts within a rectangle of tiles.
static func posts_in(d: GameDynasty, rect: Rect2i) -> Array:
	var out: Array = []
	for p in posts(d):
		if rect.has_point(Vector2i(int(p["x"]), int(p["z"]))):
			out.append(p)
	return out


## The lines of a post as the words on its board: "Ironford, 85 tiles east".
static func line_texts(p: Dictionary, short: bool = false) -> Array:
	var out: Array = []
	for l in p["lines"]:
		out.append(text("line_short" if short else "line", {"place": l["place"], "n": l["n"], "way": l["way"]}))
	return out


## What the signpost says when it is read.
static func read(p: Dictionary) -> String:
	var key := "read_" + str(p["kind"])
	return text(key, {"here": p["here"], "lines": text("join").join(line_texts(p))})


## The name a click gives a signpost.
static func name_of_post(p: Dictionary) -> String:
	return "%s: %s" % [text("sign_name"), text("join").join(line_texts(p, true))] if str(p["kind"]) != "cross" else text("sign_name") + ": " + text("sign_cross")


## Whether a place of the world map is joined by a road the heir has read of or walked: a post that names both ends of a road, once the
## heir has stood beside any of its posts, shows the road on the world map. Pure of the dynasty's history of places (visited).
static func known_links(d: GameDynasty) -> Array:
	var out: Array = []
	for l in links():
		if d.world.visited.has(str(l["a"])) or d.world.visited.has(str(l["b"])):
			out.append(l)
	return out


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "trail", "glyphs", "caravans", "text"]:
		if not dat.has(k):
			return ["roads.json: %s is missing" % k]
	var s: Dictionary = dat["settings"]
	for k in ["half_width", "wobble", "pace", "gap", "side", "search", "tag_range", "read_reach", "cross_min_gap", "lines_max"]:
		if not s.has(k) or typeof(s[k]) not in [TYPE_INT, TYPE_FLOAT]:
			bad.append("roads.json: settings.%s must be a number" % k)
	if not bad.is_empty():
		return bad
	if float(s["half_width"]) < 0.3 or float(s["half_width"]) > 1.5 or float(s["wobble"]) < 0.0 or float(s["wobble"]) > 0.8:
		bad.append("roads.json: half_width must be 0.3 to 1.5 and wobble 0 to 0.8")
	if float(s["pace"]) < 0.5 or float(s["pace"]) > 1.0:
		bad.append("roads.json: pace must be 0.5 to 1 (1 is no faster than the open ground)")
	if int(s["gap"]) < 1 or int(s["side"]) < 1 or int(s["search"]) < 1 or int(s["lines_max"]) < 2:
		bad.append("roads.json: gap, side and search must be at least 1 and lines_max at least 2")
	if float(s["tag_range"]) < 1.0 or float(s["read_reach"]) < 1.0:
		bad.append("roads.json: tag_range and read_reach must be at least 1")
	var t: Dictionary = dat["trail"]
	for k in ["body", "rut", "grit", "edge"]:
		if not t.has(k) or typeof(t[k]) != TYPE_ARRAY or (t[k] as Array).size() != 4:
			bad.append("roads.json: trail.%s needs [r, g, b, a]" % k)
	for k in ["rut_share", "grit_share", "edge_share"]:
		if not t.has(k) or int(t[k]) < 0 or int(t[k]) > 100:
			bad.append("roads.json: trail.%s must be 0 to 100" % k)
	if not bad.is_empty():
		return bad
	if int(t["rut_share"]) + int(t["grit_share"]) > 60:
		bad.append("roads.json: ruts and grit may cover at most 60 of 100 pixels of a trail")
	for id in dat["glyphs"]:
		var g: Dictionary = dat["glyphs"][id]
		if not g.has("rows") or not g.has("palette") or (g["rows"] as Array).size() != 8:
			bad.append("roads.json: glyph '%s' needs 8 rows and a palette" % id)
			continue
		for row in g["rows"]:
			if str(row).length() != 8:
				bad.append("roads.json: glyph '%s' has a row that is not 8 wide" % id)
			for ch in str(row):
				if ch != "." and not g["palette"].has(ch):
					bad.append("roads.json: glyph '%s' uses '%s', which its palette lacks" % [id, ch])
	if not dat["glyphs"].has("signpost"):
		bad.append("roads.json: the signpost has no glyph")
	for k in ["sign_name", "sign_cross", "line", "line_short", "read_end", "read_gate", "read_cross", "join", "caravan_name", "caravan_use", "caravan_resting", "ways"]:
		if not dat["text"].has(k):
			bad.append("roads.json: text.%s is missing" % k)
	if not bad.is_empty():
		return bad
	for k in ["n", "ne", "e", "se", "s", "sw", "w", "nw"]:
		if not dat["text"]["ways"].has(k):
			bad.append("roads.json: text.ways.%s is missing" % k)
	if links().size() != GameWorldGen.roads().size():
		bad.append("roads.json: the road links no longer match GameWorldGen.roads()")
	return bad
