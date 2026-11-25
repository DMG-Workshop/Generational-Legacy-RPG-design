## The look of the open world's ground (data/art/ground.json, data/art/light.json): what a TileView atlas draws for a ground kind.
## Each ground kind has a few variants (specks, tufts, pebbles) chosen by a hash of the tile, water that is a short loop of frames,
## and soft edges where two kinds meet (a ragged fading band of the higher-ranked kind; a light foam edge where water meets land),
## and the soft shadow tiles under what stands on the ground. All of it is drawn in code from the data and none of it is random: a tile
## looks the same every time, and nothing here reads or changes the world. A rendering helper with static functions, so the tests need
## no scene.
class_name GroundArt
extends RefCounted

const PATH := "res://data/art/ground.json"
const LIGHT_PATH := "res://data/art/light.json"
const SIDE_COLS := 15      # the edge tiles for a mask of sides (N 1, E 2, S 4, W 8), masks 1 to 15
const CORNER_COLS := 15    # then those for a lone corner (NE 1, SE 2, SW 4, NW 8), masks 1 to 15
const TYPES := ["speck", "tuft", "pebble", "streak", "crack", "flake"]

static var _cache: Dictionary = {}
static var _light: Dictionary = {}
static var _ground_image: Image = null
static var _overlay_set: TileSet = null
static var _glow_tex: Texture2D = null
static var _vignette_tex: Texture2D = null


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func light_data() -> Dictionary:
	if _light.is_empty():
		_light = GameData.load_json(LIGHT_PATH)
	return _light


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func px() -> int:
	return int(GameSandbox.data()["tiles"]["px"])


# ---------------------------------------------------------------- hashing: the same answer for the same place, no dice

## A well mixed number from up to four integers (the place of a tile, a kind's hash, an index).
static func mix(a: int, b: int = 0, c: int = 0, e: int = 0) -> int:
	var h: int = ((a & 0xffffffff) * 73856093) ^ ((b & 0xffffffff) * 19349663) ^ ((c & 0xffffffff) * 83492791) ^ ((e & 0xffffffff) * 668265263)
	h &= 0x7fffffffffff
	h = ((h ^ (h >> 15)) * 2246822519) & 0xffffffff
	h = ((h ^ (h >> 13)) * 3266489917) & 0xffffffff
	return h ^ (h >> 16)


# ---------------------------------------------------------------- the kinds and their variants

## The kinds the ground has a look for.
static func ground_kinds() -> Array:
	return data()["kinds"].keys()


static func has_kind(kind: String) -> bool:
	return data()["kinds"].has(kind)


static func is_water(kind: String) -> bool:
	return (data()["edges"]["water_kinds"] as Array).has(kind)


## How many looks a kind has (1 for what has no data).
static func variant_count(kind: String) -> int:
	if not has_kind(kind):
		return 1
	return (data()["kinds"][kind]["variants"] as Array).size()


## The frames of a water tile's loop.
static func frames() -> int:
	return int(setting("water_frames"))


## The look of the ground tile (x, z) of a kind: by weight, from a hash of the tile.
static func variant_at(kind: String, x: int, z: int) -> int:
	if not has_kind(kind):
		return 0
	var w: Array = data()["kinds"][kind]["variants"]
	var total := 0
	for v in w:
		total += int(v)
	var r := mix(x, z, kind.hash()) % total
	for i in w.size():
		r -= int(w[i])
		if r < 0:
			return i
	return 0


## The row in the ground atlas of a variant of a kind: water's variants stand `frames` rows apart (the frames are stacked under each).
static func row_of(kind: String, variant: int) -> int:
	return variant * frames() if is_water(kind) else variant


## The atlas cell a ground tile is drawn from (the column is the kind's, as in the flat atlas).
static func cell_for(all: Array, kind: String, x: int, z: int) -> Vector2i:
	return Vector2i(all.find(kind), row_of(kind, variant_at(kind, x, z)))


static func _rows_needed() -> int:
	var most := 1
	for k in ground_kinds():
		most = maxi(most, row_of(k, variant_count(k)))
	return most


# ---------------------------------------------------------------- painting

static func base_color(kind: String) -> Color:
	var c: Array = GameSandbox.data()["tiles"]["colors"][kind]
	return Color(float(c[0]), float(c[1]), float(c[2]))


static func shifted(c: Color, s: float) -> Color:
	return c.lerp(Color.WHITE, s) if s >= 0.0 else c.lerp(Color.BLACK, -s)


static func _put(img: Image, ox: int, oy: int, size: int, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < size and y < size:
		img.set_pixel(ox + x, oy + y, col)


static func _pattern_color(base: Color, p: Dictionary) -> Color:
	if p.has("color"):
		var c: Array = p["color"]
		return Color(float(c[0]), float(c[1]), float(c[2]))
	return shifted(base, float(p.get("shift", 0.0)))


## One pattern's pixels in the tile at (ox, oy): `count` of them at places from the hash of the kind, variant and pattern.
static func _paint_pattern(img: Image, ox: int, oy: int, size: int, base: Color, p: Dictionary, seed_value: int) -> void:
	var col := _pattern_color(base, p)
	var dark := shifted(base, -0.14)
	for k in int(p["count"]):
		var s := mix(seed_value, k)
		var x := mix(s, 1) % size
		var y := mix(s, 2) % size
		match str(p["type"]):
			"speck":
				_put(img, ox, oy, size, x, y, col)
			"tuft":   # a blade of grass: a stem and a leaf leaning to one side
				var lean := 1 if mix(s, 3) % 2 == 0 else -1
				y = maxi(y, 2)
				_put(img, ox, oy, size, x, y, dark)
				_put(img, ox, oy, size, x, y - 1, col)
				_put(img, ox, oy, size, x + lean, y - 2, col)
			"pebble":   # a light stone with a shadow to its south-east
				_put(img, ox, oy, size, x, y, col)
				_put(img, ox, oy, size, x + 1, y, col)
				_put(img, ox, oy, size, x + 1, y + 1, dark)
				_put(img, ox, oy, size, x, y + 1, dark)
			"streak":
				for i in 3:
					_put(img, ox, oy, size, x + i, y, col)
			"crack":
				_put(img, ox, oy, size, x, y, col)
				_put(img, ox, oy, size, x + 1, y + 1, col)
				_put(img, ox, oy, size, x + 2, y + 1, col)
				_put(img, ox, oy, size, x + 3, y + 2, col)
			"flake":
				_put(img, ox, oy, size, x, y, col)
				_put(img, ox, oy, size, x + 1, y + 1, col.lerp(base, 0.5))


## One variant of a kind (one frame of it, for water) in the tile at (ox, oy).
static func paint_ground(img: Image, ox: int, oy: int, size: int, kind: String, variant: int, frame: int) -> void:
	var spec: Dictionary = data()["kinds"][kind]
	var base := base_color(kind)
	var grid := float(setting("grid_darken"))
	if grid > 0.0:
		img.fill_rect(Rect2i(ox, oy, size, size), base.darkened(grid))
		img.fill_rect(Rect2i(ox + 1, oy + 1, size - 2, size - 2), base)
	else:
		img.fill_rect(Rect2i(ox, oy, size, size), base)
	var kseed := kind.hash()
	var pats: Array = spec["patterns"]
	for i in pats.size():
		_paint_pattern(img, ox, oy, size, base, pats[i], mix(kseed, variant, i))
	if spec.has("glints"):
		var g: Dictionary = spec["glints"]
		var sway: Array = g["sway"]
		var pulse: Array = g["pulse"]
		var lit := shifted(base, float(g["shift"]))
		for k in int(g["count"]):
			var s := mix(kseed, variant, 100 + k)
			var y := 1 + mix(s, 1) % (size - 2)
			var x0 := mix(s, 2) % size
			var phase := mix(s, 3) % maxi(1, pulse.size())
			var col := base.lerp(lit, float(pulse[(frame + phase) % pulse.size()]))
			for i in int(g["len"]):
				img.set_pixel(ox + posmod(x0 + int(sway[frame % sway.size()]) + i, size), oy + y, col)


## The ground atlas: a column for each kind (the kind's index in `all`), a row for each variant, and for water the frames of each
## variant stacked under it. Made once.
static func ground_image(all: Array) -> Image:
	if _ground_image != null and _ground_image.get_width() == px() * all.size():
		return _ground_image
	var size := px()
	var img := Image.create(size * all.size(), size * _rows_needed(), false, Image.FORMAT_RGBA8)
	for kind in ground_kinds():
		var col := all.find(kind)
		if col < 0:
			continue
		for v in variant_count(kind):
			if is_water(kind):
				for f in frames():
					paint_ground(img, col * size, (v * frames() + f) * size, size, kind, v, f)
			else:
				paint_ground(img, col * size, v * size, size, kind, v, 0)
	_ground_image = img
	return img


## The atlas source of the ground in its variants (source 1 of the tile set). Water's tiles play their frames, or hold the first one
## when `still` (reduced motion); every tile has the relief's brightness steps as alternatives, as the flat atlas does.
static func ground_source(all: Array, still: bool) -> TileSetAtlasSource:
	var size := px()
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(ground_image(all))
	src.texture_region_size = Vector2i(size, size)
	var steps := int(GameRelief.setting("steps"))
	for kind in ground_kinds():
		var col := all.find(kind)
		if col < 0:
			continue
		for v in variant_count(kind):
			var c := Vector2i(col, row_of(kind, v))
			src.create_tile(c)
			if is_water(kind):
				src.set_tile_animation_columns(c, 1)
				src.set_tile_animation_frames_count(c, 1 if still else frames())
				src.set_tile_animation_speed(c, float(setting("water_fps")))
				src.set_tile_animation_mode(c, TileSetAtlasSource.TILE_ANIMATION_MODE_RANDOM_START_TIMES)
			for step in range(-steps, steps + 1):
				if step == 0:
					continue
				var alt := TileView.alt_for(step)
				src.create_alternative_tile(c, alt)
				var m := GameRelief.light(step)
				src.get_tile_data(c, alt).modulate = Color(m, m, m)
	return src


## Plays or holds the water of a ground source (reduced motion holds the first frame).
static func set_still(src: TileSetAtlasSource, all: Array, still: bool) -> void:
	for kind in ground_kinds():
		if not is_water(kind) or all.find(kind) < 0:
			continue
		for v in variant_count(kind):
			src.set_tile_animation_frames_count(Vector2i(all.find(kind), row_of(kind, v)), 1 if still else frames())


# ---------------------------------------------------------------- soft edges

static func rank_of(kind: String) -> int:
	return int(data()["edges"]["rank"].get(kind, -1))


const _SIDES := [["n", 1], ["e", 2], ["s", 4], ["w", 8]]
const _CORNERS := [["ne", 1], ["se", 2], ["sw", 4], ["nw", 8]]


## The edge a ground tile of `kind` is drawn with, from the ground kinds round it (`near`: n, e, s, w, ne, se, sw, nw; "" for
## unknown): Vector2i(column, row) in the overlay atlas, or Vector2i(-1, -1) for none. Where water meets land the water tile gets foam;
## otherwise the neighbour of the highest rank above the tile's own bleeds onto it, along the sides it is on or at a corner it touches.
static func edge_for(kind: String, near: Dictionary) -> Vector2i:
	var none := Vector2i(-1, -1)
	var rank := rank_of(kind)
	if rank < 0:
		return none
	var water := is_water(kind)
	var source := ""
	if water:
		for key in near:
			var k := str(near[key])
			if k != "" and has_kind(k) and not is_water(k):
				source = "foam"
				break
		if source == "":
			source = _best(kind, near, rank)
	else:
		source = _best(kind, near, rank)
	if source == "":
		return none
	var mask := 0
	for s in _SIDES:
		if _is_source(str(near.get(s[0], "")), source, water):
			mask |= int(s[1])
	if mask != 0:
		return Vector2i(mask - 1, edge_row(source))
	var cmask := 0
	for s in _CORNERS:
		if _is_source(str(near.get(s[0], "")), source, water):
			cmask |= int(s[1])
	if cmask == 0:
		return none
	return Vector2i(SIDE_COLS + cmask - 1, edge_row(source))


static func _is_source(k: String, source: String, water: bool) -> bool:
	if k == "":
		return false
	if source == "foam":
		return has_kind(k) and not is_water(k)
	return k == source


## The neighbour kind of the highest rank above `rank` (the kind that bleeds onto a tile), "" for none. Water gives way only to water.
static func _best(kind: String, near: Dictionary, rank: int) -> String:
	var best := ""
	var best_rank := rank
	var water := is_water(kind)
	for key in near:
		var k := str(near[key])
		if k == "" or k == kind or not has_kind(k) or is_water(k) != water:
			continue
		var r := rank_of(k)
		if r > best_rank:
			best_rank = r
			best = k
	return best


## The kinds that can bleed (they have a rank), in the order of the overlay atlas's rows; the foam row follows them.
static func edge_sources() -> Array:
	var out: Array = (data()["edges"]["rank"] as Dictionary).keys()
	out.sort()
	return out


static func edge_row(source: String) -> int:
	if source == "foam":
		return edge_sources().size()
	return edge_sources().find(source)


## How solid each pixel of a tile is for an edge column: the bands along its sides (reaching in by `profile`, fading by `alphas`),
## or the quarter fade round a lone corner.
static func edge_alphas(col: int, profile: Array, alphas: Array, corner_reach: int, size: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(size * size)
	if col < SIDE_COLS:
		var mask := col + 1
		for i in size:
			var reach := int(profile[i % profile.size()])
			for d in mini(reach, alphas.size()):
				var a := float(alphas[d])
				if mask & 1:
					out[d * size + i] = maxf(out[d * size + i], a)
				if mask & 4:
					out[(size - 1 - d) * size + i] = maxf(out[(size - 1 - d) * size + i], a)
				if mask & 8:
					out[i * size + d] = maxf(out[i * size + d], a)
				if mask & 2:
					out[i * size + size - 1 - d] = maxf(out[i * size + size - 1 - d], a)
	else:
		var cmask := col - SIDE_COLS + 1
		for y in corner_reach:
			for x in corner_reach:
				var dist := int(round(sqrt(float(x * x + y * y))))
				if dist >= alphas.size():
					continue
				var a := float(alphas[dist])
				if cmask & 1:
					out[y * size + size - 1 - x] = maxf(out[y * size + size - 1 - x], a)
				if cmask & 2:
					out[(size - 1 - y) * size + size - 1 - x] = maxf(out[(size - 1 - y) * size + size - 1 - x], a)
				if cmask & 4:
					out[(size - 1 - y) * size + x] = maxf(out[(size - 1 - y) * size + x], a)
				if cmask & 8:
					out[y * size + x] = maxf(out[y * size + x], a)
	return out


## The shadow shapes' ids in the order of their rows in the overlay atlas (after the edge rows and the foam row).
static func shadow_shapes() -> Array:
	var out: Array = (light_data()["shadow"]["shapes"] as Dictionary).keys()
	out.sort()
	return out


## The shadow shape a standing thing (a node or decor glyph) throws, "" for none.
static func shadow_of(glyph: String) -> String:
	return str(light_data()["shadow"]["kinds"].get(glyph, ""))


## The overlay atlas cell of a shadow shape.
static func shadow_cell(shape: String) -> Vector2i:
	return Vector2i(0, edge_sources().size() + 1 + shadow_shapes().find(shape))


static func _paint_shadow(img: Image, ox: int, oy: int, size: int, s: Dictionary, color: Color) -> void:
	for y in size:
		for x in size:
			var ex := (float(x) + 0.5 - float(s["cx"])) / float(s["rx"])
			var ey := (float(y) + 0.5 - float(s["cy"])) / float(s["ry"])
			var r2 := ex * ex + ey * ey
			if r2 < 1.0:
				img.set_pixel(ox + x, oy + y, Color(color.r, color.g, color.b, float(s["alpha"]) * clampf((1.0 - r2) / 0.6, 0.0, 1.0)))


## The tile set of what is drawn over the ground but under what stands on it: the soft edges (a row for each kind that can bleed, then
## foam, with the relief's brightness steps as alternatives so an edge is as bright as the tile it is on) and the shadows. Made once.
static func overlay_set() -> TileSet:
	if _overlay_set != null:
		return _overlay_set
	var size := px()
	var e: Dictionary = data()["edges"]
	var sources := edge_sources()
	var shapes := shadow_shapes()
	var rows := sources.size() + 1 + shapes.size()
	var img := Image.create(size * (SIDE_COLS + CORNER_COLS), size * rows, false, Image.FORMAT_RGBA8)
	var cols := SIDE_COLS + CORNER_COLS
	var main_a := []
	var foam: Dictionary = e["foam"]
	var foam_a := []
	for c in cols:
		main_a.append(edge_alphas(c, e["profile"], e["alphas"], int(e["corner_reach"]), size))
		foam_a.append(edge_alphas(c, foam["profile"], foam["alphas"], int(foam["corner_reach"]), size))
	for r in sources.size() + 1:
		var color: Color = Color(float(foam["color"][0]), float(foam["color"][1]), float(foam["color"][2])) if r == sources.size() else base_color(str(sources[r]))
		for c in cols:
			var al: PackedFloat32Array = foam_a[c] if r == sources.size() else main_a[c]
			for i in size * size:
				if al[i] > 0.0:
					img.set_pixel(c * size + i % size, r * size + i / size, Color(color.r, color.g, color.b, al[i]))
	var sc: Array = light_data()["shadow"]["color"]
	for i in shapes.size():
		_paint_shadow(img, 0, (sources.size() + 1 + i) * size, size, light_data()["shadow"]["shapes"][shapes[i]], Color(float(sc[0]), float(sc[1]), float(sc[2])))
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(size, size)
	var steps := int(GameRelief.setting("steps"))
	for r in sources.size() + 1:
		for c in cols:
			var at := Vector2i(c, r)
			src.create_tile(at)
			for step in range(-steps, steps + 1):
				if step == 0:
					continue
				var alt := TileView.alt_for(step)
				src.create_alternative_tile(at, alt)
				var m := GameRelief.light(step)
				src.get_tile_data(at, alt).modulate = Color(m, m, m)
	for i in shapes.size():
		src.create_tile(Vector2i(0, sources.size() + 1 + i))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(size, size)
	ts.add_source(src, 0)
	_overlay_set = ts
	return ts


# ---------------------------------------------------------------- the soft textures the world look draws

## A round soft glow: white, its opacity falling from the middle (the power `falloff`).
static func glow_texture() -> Texture2D:
	if _glow_tex == null:
		var n := int(light_data()["glow"]["texture_px"])
		var fall := float(light_data()["glow"]["falloff"])
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var r := Vector2(float(x) + 0.5 - float(n) * 0.5, float(y) + 0.5 - float(n) * 0.5).length() / (float(n) * 0.5)
				img.set_pixel(x, y, Color(1, 1, 1, pow(clampf(1.0 - r, 0.0, 1.0), fall)))
		_glow_tex = ImageTexture.create_from_image(img)
	return _glow_tex


## The vignette: clear in the middle, darkening toward the edge from `inner` (a share of the way out) to the corners.
static func vignette_texture() -> Texture2D:
	if _vignette_tex == null:
		var v: Dictionary = light_data()["vignette"]
		var n := int(v["texture_px"])
		var inner := float(v["inner"])
		var c: Array = v["color"]
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2((float(x) + 0.5) / float(n) * 2.0 - 1.0, (float(y) + 0.5) / float(n) * 2.0 - 1.0)
				var r := clampf((d.length() / sqrt(2.0) - inner) / (1.0 - inner), 0.0, 1.0)
				img.set_pixel(x, y, Color(float(c[0]), float(c[1]), float(c[2]), r * r * (3.0 - 2.0 * r)))
		_vignette_tex = ImageTexture.create_from_image(img)
	return _vignette_tex


# ---------------------------------------------------------------- the checks

static func validate() -> Array:
	return problems(data(), light_data())


## What is wrong with a ground file and a light file (the data is passed so the tests can break a copy).
static func problems(dat: Dictionary, light: Dictionary) -> Array:
	var bad: Array = []
	for k in ["settings", "kinds", "edges"]:
		if not dat.has(k):
			bad.append("ground.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var s: Dictionary = dat["settings"]
	for k in ["grid_darken", "max_variants", "water_frames", "water_fps"]:
		if not s.has(k):
			bad.append("ground.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	var frames_n := int(s["water_frames"])
	if frames_n < 2 or frames_n > 8 or float(s["water_fps"]) <= 0.0 or float(s["grid_darken"]) < 0.0 or float(s["grid_darken"]) >= 1.0:
		bad.append("ground.json: water_frames must be 2 to 8, water_fps above 0 and grid_darken 0 up to 1")
	var colors: Dictionary = GameSandbox.data()["tiles"]["colors"]
	var e: Dictionary = dat["edges"]
	for k in ["rank", "water_kinds", "alphas", "profile", "corner_reach", "foam"]:
		if not e.has(k):
			bad.append("ground.json: edges.%s is missing" % k)
	if not bad.is_empty():
		return bad
	for k in dat["kinds"]:
		var kd: Variant = dat["kinds"][k]
		if not colors.has(k):
			bad.append("ground.json: '%s' has no colour in sandbox.json tiles.colors" % k)
		if typeof(kd) != TYPE_DICTIONARY or not (kd as Dictionary).has("variants") or not (kd as Dictionary).has("patterns"):
			bad.append("ground.json: '%s' needs variants and patterns" % k)
			continue
		var vs: Array = kd["variants"]
		if vs.size() < 1 or vs.size() > int(s["max_variants"]):
			bad.append("ground.json: '%s' needs 1 to %d variants" % [k, int(s["max_variants"])])
		for w in vs:
			if typeof(w) not in [TYPE_INT, TYPE_FLOAT] or float(w) <= 0.0:
				bad.append("ground.json: '%s' has a variant weight that is not above 0" % k)
		for p in kd["patterns"]:
			if typeof(p) != TYPE_DICTIONARY or not TYPES.has(str(p.get("type", ""))):
				bad.append("ground.json: '%s' has a pattern of an unknown type" % k)
				continue
			if not p.has("count") or int(p["count"]) < 0 or int(p["count"]) > 40:
				bad.append("ground.json: '%s' pattern '%s' needs a count of 0 to 40" % [k, p["type"]])
			if not p.has("color") and not p.has("shift"):
				bad.append("ground.json: '%s' pattern '%s' needs a color or a shift" % [k, p["type"]])
			if p.has("color") and (typeof(p["color"]) != TYPE_ARRAY or (p["color"] as Array).size() != 3):
				bad.append("ground.json: '%s' pattern '%s' color must be [r, g, b]" % [k, p["type"]])
		var water: bool = (e["water_kinds"] as Array).has(k)
		if water != (kd as Dictionary).has("glints"):
			bad.append("ground.json: '%s' %s glints" % [k, "needs" if water else "must not have"])
		if water and kd.has("glints"):
			var g: Dictionary = kd["glints"]
			for gk in ["shift", "count", "len", "sway", "pulse"]:
				if not g.has(gk):
					bad.append("ground.json: '%s' glints.%s is missing" % [k, gk])
			if g.has("sway") and g.has("pulse") and (typeof(g["sway"]) != TYPE_ARRAY or typeof(g["pulse"]) != TYPE_ARRAY or (g["sway"] as Array).size() != frames_n or (g["pulse"] as Array).size() != frames_n):
				bad.append("ground.json: '%s' glints need a sway and a pulse for each of the %d frames" % [k, frames_n])
	for k in TileView.kinds():
		if ["plains", "forest", "hills", "mountains", "swamp", "tundra", "coast", "volcanic", "ocean", "water", "deep", "snow", "ford"].has(k) and not dat["kinds"].has(k):
			bad.append("ground.json: the ground kind '%s' has no look" % k)
	for k in e["water_kinds"]:
		if not dat["kinds"].has(k):
			bad.append("ground.json: edges.water_kinds names '%s', which has no look" % k)
	for k in dat["kinds"]:
		if not (e["rank"] as Dictionary).has(k):
			bad.append("ground.json: '%s' has no edge rank" % k)
	for k in e["rank"]:
		if not dat["kinds"].has(k):
			bad.append("ground.json: edges.rank has '%s', which has no look" % k)
	var sets: Array = [["edges", e], ["edges.foam", e["foam"] if typeof(e["foam"]) == TYPE_DICTIONARY else {}]]
	for pair in sets:
		var d: Dictionary = pair[1]
		for k in ["alphas", "profile", "corner_reach"]:
			if not d.has(k):
				bad.append("ground.json: %s.%s is missing" % [pair[0], k])
		if not bad.is_empty():
			return bad
		for a in d["alphas"]:
			if float(a) <= 0.0 or float(a) > 1.0:
				bad.append("ground.json: %s.alphas must each be above 0 and at most 1" % pair[0])
		for r in d["profile"]:
			if int(r) < 1 or int(r) > (d["alphas"] as Array).size():
				bad.append("ground.json: %s.profile must each be 1 up to the number of alphas" % pair[0])
		if (d["profile"] as Array).is_empty() or (d["alphas"] as Array).is_empty() or int(d["corner_reach"]) < 1 or int(d["corner_reach"]) > 8:
			bad.append("ground.json: %s needs alphas, a profile and a corner_reach of 1 to 8" % pair[0])
	if not e["foam"].has("color") or typeof(e["foam"]["color"]) != TYPE_ARRAY or (e["foam"]["color"] as Array).size() != 3:
		bad.append("ground.json: edges.foam.color must be [r, g, b]")
	bad.append_array(_light_problems(light))
	return bad


static func _light_problems(light: Dictionary) -> Array:
	var bad: Array = []
	for k in ["shadow", "grade", "glow", "weather", "vignette"]:
		if not light.has(k):
			bad.append("light.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var sh: Dictionary = light["shadow"]
	for k in ["color", "shapes", "kinds", "building"]:
		if not sh.has(k):
			bad.append("light.json: shadow.%s is missing" % k)
	if not bad.is_empty():
		return bad
	for id in sh["shapes"]:
		var sp: Dictionary = sh["shapes"][id]
		for k in ["cx", "cy", "rx", "ry", "alpha"]:
			if not sp.has(k):
				bad.append("light.json: shadow shape '%s' has no %s" % [id, k])
		if not bad.is_empty():
			return bad
		if float(sp["rx"]) <= 0.0 or float(sp["ry"]) <= 0.0 or float(sp["alpha"]) <= 0.0 or float(sp["alpha"]) > 1.0:
			bad.append("light.json: shadow shape '%s' needs radii above 0 and an alpha above 0 up to 1" % id)
	var glyphs := TileView.all_glyphs()
	for g in sh["kinds"]:
		if not sh["shapes"].has(str(sh["kinds"][g])):
			bad.append("light.json: shadow of '%s' is the unknown shape '%s'" % [g, sh["kinds"][g]])
		if not glyphs.has(g):
			bad.append("light.json: shadow names '%s', which is not a glyph" % g)
	for k in ["dx", "dy", "grow", "alpha", "layers"]:
		if not sh["building"].has(k):
			bad.append("light.json: shadow.building.%s is missing" % k)
	var gl: Dictionary = light["glow"]
	for k in ["from_sun", "texture_px", "falloff", "flicker", "flicker_hz", "tiles", "glyphs", "buildings"]:
		if not gl.has(k):
			bad.append("light.json: glow.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if int(gl["texture_px"]) < 8 or float(gl["falloff"]) <= 0.0 or float(gl["from_sun"]) <= 0.0 or float(gl["from_sun"]) > 1.0:
		bad.append("light.json: glow needs texture_px of 8 or more, falloff above 0 and from_sun above 0 up to 1")
	for group in ["tiles", "glyphs", "buildings"]:
		for id in gl[group]:
			var sp: Dictionary = gl[group][id]
			for k in ["color", "radius", "strength"]:
				if not sp.has(k):
					bad.append("light.json: glow %s '%s' has no %s" % [group, id, k])
			if not bad.is_empty():
				return bad
			if float(sp["radius"]) <= 0.0 or float(sp["strength"]) <= 0.0 or float(sp["strength"]) > 1.0:
				bad.append("light.json: glow %s '%s' needs a radius above 0 and a strength above 0 up to 1" % [group, id])
	for id in gl["tiles"]:
		if not GameBuild.pieces().has(id):
			bad.append("light.json: glow.tiles names '%s', which is not a building piece" % id)
	for id in gl["glyphs"]:
		if not glyphs.has(id):
			bad.append("light.json: glow.glyphs names '%s', which is not a glyph" % id)
	if not gl["buildings"].has("default"):
		bad.append("light.json: glow.buildings needs a default")
	var w: Dictionary = light["weather"]
	for k in ["rain", "snow", "intensity", "fog_alpha", "fog_color"]:
		if not w.has(k):
			bad.append("light.json: weather.%s is missing" % k)
	if not bad.is_empty():
		return bad
	for id in ["rain", "snow"]:
		if int(w[id].get("count", 0)) < 1 or int(w[id].get("count", 0)) > 2000:
			bad.append("light.json: weather.%s needs a count of 1 to 2000" % id)
		if float(w[id].get("fall", 0.0)) <= 0.0:
			bad.append("light.json: weather.%s needs a fall above 0" % id)
		if typeof(w[id].get("color", null)) != TYPE_ARRAY or (w[id]["color"] as Array).size() != 4:
			bad.append("light.json: weather.%s color must be [r, g, b, a]" % id)
	for k in w["intensity"]:
		if float(w["intensity"][k]) <= 0.0:
			bad.append("light.json: weather intensity '%s' must be above 0" % k)
	var v: Dictionary = light["vignette"]
	for k in ["texture_px", "inner", "strength", "night_boost", "color"]:
		if not v.has(k):
			bad.append("light.json: vignette.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if float(v["inner"]) < 0.0 or float(v["inner"]) >= 1.0 or int(v["texture_px"]) < 8 or float(v["strength"]) < 0.0 or float(v["strength"]) > 1.0:
		bad.append("light.json: vignette needs inner 0 up to 1, texture_px of 8 or more and strength 0 to 1")
	return bad
