## Battle scenery: the land a fight happens in, painted behind the battle arena from data/art/scenery.json.
## A scene is a list of layers (a sky or a wall, ridges of hills or mountains, tree lines, the ground with its
## details, props drawn like the sprites) painted at a low resolution with the scene's own dice, seeded from
## the place so a place always looks the same, then scaled up by whole pixels like the sprites. Out of doors
## the season and the weather add their own layers. Rendering only: nothing here touches the game's state or
## its dice.
extends RefCounted

const SpriteArt := preload("res://ui/play/sprite_art.gd")
const PATH := "res://data/art/scenery.json"
const UPSCALE := 4
const KEEP := 3   # scenes kept made at once: this fight's and the last two
const OPS := ["sky", "wall", "clouds", "stars", "orb", "ridge", "trees", "columns", "spikes", "islands", "town",
	"ground", "water", "road", "pools", "cracks", "details", "scatter", "prop", "band", "tint", "particles", "place"]
const SEASONS := ["spring", "summer", "autumn", "winter"]

static var _data: Dictionary = {}
static var _loaded := false
static var _cache: Dictionary = {}   # key -> Texture2D
static var particles_on := true      # the graphics settings' weather particles (GraphicsSettings.apply)
static var _order: Array = []        # the cache's keys, oldest first


## One picture being painted: its size, where the sky meets the ground, and the scene's own dice.
class Canvas:
	var img: Image
	var w := 0
	var h := 0
	var hz := 0   # the horizon: the first row of the ground
	var rng: RandomNumberGenerator = CosmeticRng.keyed("")
	var mute := false   # draw nothing (the dice are still rolled, so the rest of the scene is the same)
	var season := ""
	var props: Dictionary = {}

	func put(x: int, y: int, c: Color) -> void:
		if mute or x < 0 or y < 0 or x >= w or y >= h or c.a <= 0.0:
			return
		if c.a >= 1.0:
			img.set_pixel(x, y, c)
		else:
			img.set_pixel(x, y, img.get_pixel(x, y).blend(c))

	## The rectangle from (x0, y0) up to, not including, (x1, y1).
	func fill(x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
		var a := Vector2i(maxi(0, x0), maxi(0, y0))
		var b := Vector2i(mini(w, x1), mini(h, y1))
		if b.x <= a.x or b.y <= a.y or c.a <= 0.0:
			return
		if c.a >= 1.0:
			img.fill_rect(Rect2i(a, b - a), c)
			return
		var layer := Image.create_empty(b.x - a.x, b.y - a.y, false, Image.FORMAT_RGBA8)
		layer.fill(c)
		img.blend_rect(layer, Rect2i(Vector2i.ZERO, b - a), a)

	## A whole number from a number or a [min, max] range, rolled on the scene's dice.
	func ri(v: Variant, fallback: int) -> int:
		if typeof(v) == TYPE_ARRAY and (v as Array).size() == 2:
			return rng.randi_range(int(v[0]), int(v[1]))
		if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
			return int(v)
		return fallback

	func rf(v: Variant, fallback: float) -> float:
		if typeof(v) == TYPE_ARRAY and (v as Array).size() == 2:
			return rng.randf_range(float(v[0]), float(v[1]))
		if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
			return float(v)
		return fallback

	## A row of the sky: 0 its top, 1 the horizon.
	func sky_y(f: float) -> int:
		return int(round(f * float(hz)))

	## A row of the ground: 0 the horizon, 1 the bottom.
	func ground_y(f: float) -> int:
		return hz + int(round(f * float(h - hz)))


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_data = {}
	if FileAccess.file_exists(PATH):
		var v = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if typeof(v) == TYPE_DICTIONARY:
			_data = v


## Forget the scenes already painted (a graphics setting changed what a scene shows); the data stays loaded.
static func forget_painted() -> void:
	_cache = {}
	_order = []


## Forget everything loaded and made (tests change the data in between).
static func reset() -> void:
	_loaded = false
	_data = {}
	_cache = {}
	_order = []


## The size a scene is painted at, before it is scaled up.
static func canvas_size() -> Vector2i:
	_load()
	var s = _data.get("size", [384, 120])
	if typeof(s) != TYPE_ARRAY or (s as Array).size() != 2:
		return Vector2i(384, 120)
	return Vector2i(maxi(16, int(s[0])), maxi(16, int(s[1])))


## How strongly the battle screen veils the scenery toward its background, so the fighters and their names
## read over it: more when the player asked for high contrast.
static func veil(high_contrast: bool) -> float:
	_load()
	return clampf(float(_data.get("veil_high_contrast" if high_contrast else "veil", 0.4)), 0.0, 1.0)


## The scene a place is fought in: its own entry under "places", else its first biome with a scene, else the
## fallback scene. "" when there is none (no scenery is drawn).
static func scene_id(place_id: String) -> String:
	_load()
	var scenes: Dictionary = _data.get("scenes", {})
	var own = _data.get("places", {}).get(place_id, {})
	if typeof(own) == TYPE_DICTIONARY and scenes.has(str(own.get("scene", ""))):
		return str(own["scene"])
	for b in GameWorld.place(place_id).get("biomes", []):
		if scenes.has(str(b)):
			return str(b)
	var fb := str(_data.get("fallback", ""))
	return fb if scenes.has(fb) else ""


## The scenery for a fight where the world stands now: its place, weather and season. Null without one.
static func for_world(w: GameWorld) -> Texture2D:
	if w == null:
		return null
	return texture(w.location, w.weather_id, str(w.season().get("id", "")))


## A place's scene in a weather and season, scaled up by whole pixels and kept. Null when there is none.
static func texture(place_id: String, weather: String, season: String) -> Texture2D:
	_load()
	var sid := scene_id(place_id)
	if sid == "":
		return null
	var key := "%s:%s:%s:%s" % [place_id, sid, weather, season]
	if _cache.has(key):
		return _cache[key]
	var img := paint(place_id, weather, season)
	var big := img.duplicate() as Image
	big.resize(img.get_width() * UPSCALE, img.get_height() * UPSCALE, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(big)
	_cache[key] = tex
	_order.append(key)
	while _order.size() > KEEP:
		_cache.erase(_order.pop_front())
	return tex


## The part of a scene of `tex_size` that covers a box of another shape when stretched over it: the box's
## shape, as large as the scene allows, centred across and taken from the top, so the sky and the horizon
## stay in sight and any cut comes off the near ground. The whole scene for an empty box.
static func crop(tex_size: Vector2, box: Vector2) -> Rect2:
	if box.x <= 0.0 or box.y <= 0.0 or tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return Rect2(Vector2.ZERO, tex_size)
	var k := maxf(box.x / tex_size.x, box.y / tex_size.y)   # screen pixels per scene pixel
	var size := Vector2(minf(tex_size.x, box.x / k), minf(tex_size.y, box.y / k))
	return Rect2(Vector2((tex_size.x - size.x) * 0.5, 0.0), size)


## A place's scene in a weather and season at its own resolution (the tools and the tests look at this).
static func paint(place_id: String, weather: String, season: String) -> Image:
	_load()
	var sid := scene_id(place_id)
	var scene: Dictionary = _data.get("scenes", {}).get(sid, {})
	var cv := Canvas.new()
	var sz := canvas_size()
	cv.w = sz.x
	cv.h = sz.y
	cv.hz = clampi(int(round(float(sz.y) * float(scene.get("horizon", _data.get("horizon", 0.35))))), 1, sz.y - 1)
	cv.img = Image.create_empty(cv.w, cv.h, false, Image.FORMAT_RGBA8)
	cv.img.fill(_col(scene.get("base", "#14121c"), Color("#14121c")))
	cv.rng = CosmeticRng.keyed("%s:%s" % [place_id, sid])
	cv.season = season
	cv.props = _data.get("props", {})
	var own = _data.get("places", {}).get(place_id, {})
	var extra: Array = own.get("layers", []) if typeof(own) == TYPE_DICTIONARY else []
	var placed := false
	for op in scene.get("layers", []):
		if typeof(op) != TYPE_DICTIONARY:
			continue
		if str(op.get("op", "")) == "place":   # the place's own layers go here: a town on the skyline
			placed = true
			for e in extra:
				_op(cv, e)
		else:
			_op(cv, op)
	if not placed:
		for e in extra:
			_op(cv, e)
	if not bool(scene.get("indoor", false)):
		for op in _data.get("seasons", {}).get(season, []):
			_op(cv, op)
		for op in _data.get("weather", {}).get(weather, []):
			_op(cv, op)
	return cv.img


## One layer. A layer may carry its own changes for a season ("autumn": {"colors": [...]}), used in it.
static func _op(cv: Canvas, raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var op: Dictionary = raw
	if raw.has(cv.season) and typeof(raw[cv.season]) == TYPE_DICTIONARY:
		op = (raw as Dictionary).duplicate()
		op.merge(raw[cv.season], true)
	match str(op.get("op", "")):
		"sky":
			_sky(cv, op)
		"wall":
			_wall(cv, op)
		"clouds":
			_clouds(cv, op)
		"stars":
			_stars(cv, op)
		"orb":
			_orb(cv, op)
		"ridge":
			_ridge(cv, op)
		"trees":
			_trees(cv, op)
		"columns":
			_columns(cv, op)
		"spikes":
			_spikes(cv, op)
		"islands":
			_islands(cv, op)
		"town":
			_town(cv, op)
		"ground":
			_ground(cv, op)
		"water":
			_water(cv, op)
		"road":
			_road(cv, op)
		"pools":
			_pools(cv, op)
		"cracks":
			_cracks(cv, op)
		"details":
			_details(cv, op)
		"scatter":
			_scatter(cv, op)
		"prop":
			_prop(cv, op)
		"band":
			_band(cv, op)
		"tint":
			_tint(cv, op)
		"particles":
			cv.mute = not particles_on   # switched off by the graphics settings: rolled, not drawn
			_particles(cv, op)
			cv.mute = false


# ---------------------------------------------------------------- the sky and the back wall

## Flat bands from the top down to the horizon, the darkest and widest at the top.
static func _sky(cv: Canvas, op: Dictionary) -> void:
	var cols := _cols(op.get("colors", []))
	var n := cols.size()
	if n == 0:
		return
	var total := 0.0
	for i in n:
		total += float(n - i) + 1.0
	var y := 0.0
	for i in n:
		var y1 := y + float(cv.hz) * (float(n - i) + 1.0) / total
		cv.fill(0, int(round(y)), cv.w, cv.hz if i == n - 1 else int(round(y1)), cols[i])
		y = y1


## Courses of blocks over a band of the picture (fractions of its height): a cave's rock face, a crypt's
## masonry, a floor. "rough" breaks the courses up; "grow" makes each course taller than the one above, as
## a floor seen from above; "edge": false leaves out the lit top edge a wall's blocks have.
static func _wall(cv: Canvas, op: Dictionary) -> void:
	var cols := _cols(op.get("colors", []))
	if cols.is_empty():
		return
	var span := _pair(op.get("y"), [0.0, 0.35])
	var y0 := int(round(span[0] * cv.h))
	var y1 := int(round(span[1] * cv.h))
	var brick := _pair(op.get("brick"), [12, 6])
	var bw := maxi(3, int(brick[0]))
	var bh := maxi(2, int(brick[1]))
	var rough := bool(op.get("rough", false))
	var grow := float(op.get("grow", 0.0))
	var edge := bool(op.get("edge", true))
	cv.fill(0, y0, cv.w, y1, _col(op.get("mortar"), (cols[0] as Color).darkened(0.45)))
	var y := y0
	var row := 0
	var ch := float(bh)
	while y < y1:
		var hh := maxi(2, int(round(ch)) + (cv.rng.randi_range(-1, 1) if rough else 0))
		var ww0 := maxi(3, int(round(float(bw) * ch / float(bh))))
		var x := -((row % 2) * ww0 / 2) - (cv.rng.randi_range(0, ww0 / 2) if rough else 0)
		while x < cv.w:
			var ww := maxi(3, ww0 + (cv.rng.randi_range(-ww0 / 3, ww0 / 3) if rough else 0))
			var c: Color = cols[cv.rng.randi() % cols.size()]
			cv.fill(x, y, x + ww - 1, mini(y + hh - 1, y1), c)
			if edge:
				cv.fill(x, y, x + ww - 1, mini(y + 1, y1), c.lightened(0.1))   # the lit top edge
			x += ww
		y += hh
		row += 1
		ch += grow


## Clouds: a few domes on a flat base, the underside in shade.
static func _clouds(cv: Canvas, op: Dictionary) -> void:
	var cols := _cols(op.get("colors", []))
	if cols.is_empty():
		return
	var lit: Color = cols[0]
	var shade: Color = cols[1] if cols.size() > 1 else lit.darkened(0.15)
	var span := _pair(op.get("y"), [0.1, 0.6])
	for i in cv.ri(op.get("count"), 3):
		var cw := maxi(6, cv.ri(op.get("w", [24, 48]), 32))
		var cx := cv.rng.randi_range(-cw / 2, cv.w + cw / 2)
		var cy := cv.sky_y(cv.rng.randf_range(span[0], span[1]))
		var puffs := 2 + cw / 14
		var pw := float(cw) / float(puffs)
		var domes: Array = []
		for p in puffs:
			var rx := int(pw * 0.75) + cv.rng.randi_range(0, 2)
			domes.append(Vector3i(cx - cw / 2 + int((float(p) + 0.5) * pw), rx, maxi(2, int(float(rx) * cv.rng.randf_range(0.5, 0.85)))))
		for d in domes:
			_dome(cv, d.x, cy, d.y, d.z, shade)
		for d in domes:
			_dome(cv, d.x - 1, cy - 2, d.y - 1, d.z - 1, lit)


## Stars: points in the sky, a few brighter with short rays.
static func _stars(cv: Canvas, op: Dictionary) -> void:
	var cols := _cols(op.get("colors", ["#ffffff"]))
	if cols.is_empty():
		return
	var span := _pair(op.get("y"), [0.0, 0.8])
	var bright := float(op.get("bright", 0.15))
	for i in cv.ri(op.get("count"), 30):
		var x := cv.rng.randi_range(0, cv.w - 1)
		var y := cv.sky_y(cv.rng.randf_range(span[0], span[1]))
		var c: Color = cols[cv.rng.randi() % cols.size()]
		cv.put(x, y, c)
		if cv.rng.randf() < bright:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				cv.put(x + d.x, y + d.y, Color(c, 0.45))


## A sun or a moon: a disc with a shaded rim at the lower right and stepped rings of glow.
static func _orb(cv: Canvas, op: Dictionary) -> void:
	var cols := _cols(op.get("colors", ["#fff6d8"]))
	if cols.is_empty():
		return
	var cx := int(round(float(op.get("x", 0.8)) * cv.w))
	var cy := cv.sky_y(float(op.get("y", 0.3)))
	var r := maxi(1, int(op.get("r", 5)))
	var glow := _col(op.get("glow"), Color(0, 0, 0, 0))
	if glow.a > 0.0:
		for k in [3, 2, 1]:
			_disc(cv, cx, cy, r + k * 2, Color(glow, float(op.get("glow_alpha", 0.1))))
	_disc(cv, cx, cy, r, cols[0])
	if cols.size() > 1:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var d := sqrt(float(dx * dx + dy * dy))
				if d <= float(r) + 0.3 and d > float(r) - 1.3 and dx + dy > 0:
					cv.put(cx + dx, cy + dy, cols[1])


# ---------------------------------------------------------------- the skyline

## A ridge of mountains ("peaks": straight slopes up to sharp tops) or hills ("round"), standing on the
## horizon (or `base` rows below it). Peaks rise at uneven spacing with saddles between them; each mountain's
## lit face is left of a line falling from its top toward the lower right, as the light comes from the top
## left, and a hill is lit on its slopes that face that way. Mountains may wear snow above `snow_at` rows.
static func _ridge(cv: Canvas, op: Dictionary) -> void:
	var cols := _cols(op.get("colors", []))
	if cols.is_empty():
		return
	var lit: Color = cols[0]
	var shade: Color = cols[1] if cols.size() > 1 else lit.darkened(0.2)
	var base := cv.hz + int(op.get("base", 0))
	var hr := _pair(op.get("height"), [6, 14])
	var sp := _pair(op.get("spacing"), [24, 48])
	var rounded := str(op.get("kind", "peaks")) == "round"
	var xs := _pair(op.get("x"), [0.0, 1.0])
	var x0 := int(round(xs[0] * cv.w))
	var x1 := int(round(xs[1] * cv.w))
	# Saddles and peaks in turn: (x, height, 1 for a peak).
	var pts: Array = []
	var x := float(x0) - cv.rng.randf_range(0.0, sp[1])
	var last := cv.rng.randf_range(hr[0], hr[1])
	pts.append(Vector3(x, last * cv.rng.randf_range(0.2, 0.5), 0.0))
	while x < float(x1) + sp[1]:
		var gap := cv.rng.randf_range(sp[0], sp[1])
		var peak := cv.rng.randf_range(hr[0], hr[1])
		pts.append(Vector3(x + gap * cv.rng.randf_range(0.3, 0.7), peak, 1.0))
		x += gap
		pts.append(Vector3(x, minf(peak, last) * cv.rng.randf_range(0.25, 0.6) if not rounded else peak * cv.rng.randf_range(0.5, 0.8), 0.0))
		last = peak
	var heights := PackedFloat32Array()
	heights.resize(cv.w)
	var tops: Array = []   # the peak that rules each column
	tops.resize(cv.w)
	var k := 0
	for cx in cv.w:
		while k < pts.size() - 2 and (pts[k + 1] as Vector3).x <= cx:
			k += 1
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		var t := clampf((float(cx) - a.x) / maxf(1.0, b.x - a.x), 0.0, 1.0)
		if rounded:
			t = (1.0 - cos(t * PI)) * 0.5
		heights[cx] = lerpf(a.y, b.y, t) if cx >= x0 and cx < x1 else 0.0
		tops[cx] = a if a.z > 0.5 else b
	var snow := _cols(op.get("snow", []))
	var snow_at := float(op.get("snow_at", 9999))
	var lean := float(op.get("lean", 0.45))
	for cx in cv.w:
		var hh := heights[cx]
		if hh < 0.5:
			continue
		var p: Vector3 = tops[cx]
		var slope_lit := heights[mini(cv.w - 1, cx + 1)] - heights[maxi(0, cx - 1)] > 0.0
		for y in range(base - int(round(hh)), base):
			var on_lit := slope_lit
			if not rounded:
				on_lit = float(cx) < p.x + float(y - (base - int(round(p.y)))) * lean
			var c := lit if on_lit else shade
			if not snow.is_empty() and float(base - y) > snow_at:
				c = snow[0] if on_lit or snow.size() < 2 else snow[1]
			cv.put(cx, y, c)


## A line of trees standing on the horizon (or `base` rows below it): pines, round broadleaf trees or bare
## dead ones, side by side every `gap` pixels, or `count` of them scattered along the line.
static func _trees(cv: Canvas, op: Dictionary) -> void:
	var cols := _cols(op.get("colors", []))
	if cols.is_empty():
		return
	var trunk := _cols(op.get("trunk", ["#3a2a1e"]))
	var kind := str(op.get("kind", "pine"))
	var base := cv.hz + int(op.get("base", 0))
	var xs := _pair(op.get("x"), [0.0, 1.0])
	var x0 := int(round(xs[0] * cv.w))
	var x1 := int(round(xs[1] * cv.w))
	var spots: Array = []
	if op.has("count"):
		for i in cv.ri(op["count"], 4):
			spots.append(cv.rng.randi_range(x0, x1))
	else:
		var x := x0 - cv.rng.randi_range(0, 4)
		while x < x1 + 4:
			spots.append(x)
			x += maxi(1, cv.ri(op.get("gap", [3, 8]), 5))
	for x in spots:
		var th := maxi(3, cv.ri(op.get("size", [8, 14]), 10))
		var b := base + cv.ri(op.get("drop", 0), 0)
		match kind:
			"broad":
				_broad(cv, x, b, th, cols, trunk)
			"dead":
				_dead(cv, x, b, th, cols)
			_:
				_pine(cv, x, b, th, cols, trunk)


static func _pine(cv: Canvas, cx: int, base: int, th: int, cols: Array, trunk: Array) -> void:
	var lit: Color = cols[0]
	var mid: Color = cols[mini(1, cols.size() - 1)]
	var shade: Color = cols[mini(2, cols.size() - 1)]
	var stem := maxi(1, th / 6)
	var crown := th - stem
	var half := maxf(1.0, float(th) * 0.27)
	for r in crown:
		var hw := int(round(float(r + 1) / float(crown) * half))
		if r > 2 and (crown - r) % 4 == 0:
			hw = maxi(0, hw - 1)   # a notch between two tiers of branches
		var y := base - th + r
		for x in range(cx - hw, cx + hw + 1):
			cv.put(x, y, lit if x < cx else (mid if x == cx else shade))
	if not trunk.is_empty():
		for y in range(base - stem, base):
			cv.put(cx, y, trunk[0])


static func _broad(cv: Canvas, cx: int, base: int, th: int, cols: Array, trunk: Array) -> void:
	var lit: Color = cols[0]
	var mid: Color = cols[mini(1, cols.size() - 1)]
	var shade: Color = cols[mini(2, cols.size() - 1)]
	var r := maxf(1.5, float(th) * 0.4)
	var cy := base - th + int(round(r))
	if not trunk.is_empty():
		for y in range(cy + int(r * 0.5), base):
			cv.put(cx, y, trunk[0])
			if th >= 12:
				cv.put(cx + 1, y, trunk[mini(1, trunk.size() - 1)])
	var blobs := [Vector3(0.0, 0.0, r), Vector3(-r * 0.6, r * 0.25, r * 0.62), Vector3(r * 0.6, r * 0.3, r * 0.58)]
	for bl in blobs:
		var rr: float = bl.z
		for dy in range(-int(ceil(rr)), int(ceil(rr)) + 1):
			for dx in range(-int(ceil(rr)), int(ceil(rr)) + 1):
				if float(dx * dx + dy * dy) > rr * rr + 0.5:
					continue
				var px := cx + dx + int(round(bl.x))
				var py := cy + dy + int(round(bl.y))
				var lean := (float(px - cx) + float(py - cy)) / r   # toward the lower right: away from the light
				cv.put(px, py, lit if lean < -0.5 else (mid if lean < 0.4 else shade))


static func _dead(cv: Canvas, cx: int, base: int, th: int, cols: Array) -> void:
	var lit: Color = cols[0]
	var shade: Color = cols[cols.size() - 1]
	for y in range(base - th, base):
		cv.put(cx, y, lit)
		if th >= 14:
			cv.put(cx + 1, y, shade)
	for i in cv.rng.randi_range(2, 4):
		var y := base - th + cv.rng.randi_range(1, maxi(2, th / 2))
		var dir := -1 if cv.rng.randf() < 0.5 else 1
		var ln := cv.rng.randi_range(maxi(2, th / 5), maxi(3, th / 3))
		var x := cx + (0 if dir < 0 else 1)
		for s in ln:
			x += dir
			if s % 2 == 0:
				y -= 1
			cv.put(x, y, lit if dir < 0 else shade)


## Columns standing on the horizon at fractions of the width, lit on the left; some broken off.
static func _columns(cv: Canvas, op: Dictionary) -> void:
	var cols := _cols(op.get("colors", []))
	if cols.size() < 3:
		return
	var base := cv.hz + int(op.get("base", 0))
	var w := maxi(3, int(op.get("w", 8)))
	for xf in op.get("x", []):
		var cx := int(round(float(xf) * cv.w))
		var ht := cv.ri(op.get("height", [30, 40]), 30)
		var broken := cv.rng.randf() < float(op.get("broken", 0.0))
		if broken:
			ht = int(float(ht) * cv.rng.randf_range(0.35, 0.7))
		var top := base - ht
		var x0 := cx - w / 2
		for x in range(x0, x0 + w):
			var c: Color = cols[0] if x < x0 + w / 3 else (cols[2] if x >= x0 + w - w / 3 else cols[1])
			var from := top + (cv.rng.randi_range(0, 3) if broken else 3)
			for y in range(from, base - 2):
				cv.put(x, y, c)
		if not broken:   # the capital: three courses, a pixel wider each side
			cv.fill(x0 - 1, top, x0 + w + 1, top + 1, cols[0])
			cv.fill(x0 - 1, top + 1, x0 + w + 1, top + 2, cols[1])
			cv.fill(x0, top + 2, x0 + w, top + 3, cols[2])
		cv.fill(x0 - 1, base - 2, x0 + w + 1, base - 1, cols[0])   # the foot
		cv.fill(x0 - 1, base - 1, x0 + w + 1, base, cols[2])


## Spikes of rock or ice: hanging from the top ("from": "top") or standing on the horizon.
static func _spikes(cv: Canvas, op: Dictionary) -> void:
	var cols := _cols(op.get("colors", []))
	if cols.is_empty():
		return
	var lit: Color = cols[0]
	var shade: Color = cols[1] if cols.size() > 1 else lit.darkened(0.2)
	var hanging := str(op.get("from", "top")) == "top"
	var base := int(op.get("base", 0)) + (0 if hanging else cv.hz)
	for i in cv.ri(op.get("count"), 8):
		var cx := cv.rng.randi_range(0, cv.w - 1)
		var ln := maxi(2, cv.ri(op.get("len", [6, 16]), 8))
		var sw := maxi(1, cv.ri(op.get("w", [3, 7]), 4))
		for r in ln:
			var hw := int(round(float(sw) * 0.5 * (1.0 - float(r) / float(ln))))
			var y := base + r if hanging else base - 1 - r
			for x in range(cx - hw, cx + hw + 1):
				cv.put(x, y, lit if x < cx else shade)


## Rocks floating in the sky: a flat cap over a jagged point, lit on the left.
static func _islands(cv: Canvas, op: Dictionary) -> void:
	var cols := _cols(op.get("colors", []))
	if cols.size() < 3:
		return
	var span := _pair(op.get("y"), [0.1, 0.8])
	for i in cv.ri(op.get("count"), 5):
		var cx := cv.rng.randi_range(0, cv.w - 1)
		var cy := cv.sky_y(cv.rng.randf_range(span[0], span[1]))
		var iw := maxi(4, cv.ri(op.get("w", [6, 20]), 10))
		var depth := maxi(3, iw * 2 / 3)
		cv.fill(cx - iw / 2, cy, cx + iw / 2 + 1, cy + 2, cols[0])
		for r in depth:
			var hw := int(round(float(iw) * 0.5 * (1.0 - float(r + 1) / float(depth + 1))))
			hw += cv.rng.randi_range(-1, 0) if r > 0 else 0
			for x in range(cx - hw, cx + hw + 1):
				cv.put(x, cy + 2 + r, cols[1] if x < cx else cols[2])


## A town on the skyline: towers, houses under gable roofs with a few lit windows, and a wall in front.
## colors: wall lit, wall shade, roof lit, roof shade.
static func _town(cv: Canvas, op: Dictionary) -> void:
	var cols := _cols(op.get("colors", []))
	if cols.size() < 4:
		return
	var lights := _col(op.get("lights"), Color(0, 0, 0, 0))
	var base := cv.hz + int(op.get("base", 0))
	var xs := _pair(op.get("x"), [0.55, 0.85])
	var x0 := int(round(xs[0] * cv.w))
	var x1 := int(round(xs[1] * cv.w))
	for t in cv.ri(op.get("towers", 0), 0):
		var tw := cv.rng.randi_range(4, 6)
		var tx := cv.rng.randi_range(x0 + 2, maxi(x0 + 2, x1 - tw - 2))
		var th := cv.ri(op.get("tower_height", [14, 20]), 16)
		_house(cv, tx, base, tw, th, cols, lights, true)
	var x := x0
	while x < x1:
		var hw := cv.rng.randi_range(5, 9)
		_house(cv, x, base, hw, cv.ri(op.get("height", [5, 9]), 6), cols, lights, false)
		x += hw + cv.rng.randi_range(0, 2)
	if bool(op.get("wall", false)):
		var wh := int(op.get("wall_height", 4))
		cv.fill(x0 - 3, base - wh, x1 + 3, base, cols[1])
		cv.fill(x0 - 3, base - wh, x1 + 3, base - wh + 1, cols[0])
		var cx := x0 - 3
		while cx < x1 + 3:
			cv.fill(cx, base - wh - 1, cx + 2, base - wh, cols[0])   # the battlements
			cx += 4


static func _house(cv: Canvas, x: int, base: int, w: int, h: int, cols: Array, lights: Color, tower: bool) -> void:
	for xx in range(x, x + w):
		var c: Color = cols[0] if xx < x + maxi(1, w / 3) else cols[1]
		for y in range(base - h, base):
			cv.put(xx, y, c)
	var peak := w / 2 + (2 if tower else 1)
	for r in peak:   # the roof, from its eaves up to the ridge or the spire's point
		var hw := int(round(float(w + 1) * 0.5 * (1.0 - float(r) / float(peak))))
		var y := base - h - 1 - r
		for xx in range(x + w / 2 - hw, x + w / 2 + hw + (w % 2)):
			cv.put(xx, y, cols[2] if xx < x + w / 2 else cols[3])
	if lights.a > 0.0:
		for i in maxi(1, w / 4):
			if cv.rng.randf() < 0.45:
				cv.put(cv.rng.randi_range(x + 1, x + w - 2), cv.rng.randi_range(base - h + 1, base - 2), lights)


# ---------------------------------------------------------------- the ground

## Bands from the horizon down, each nearer band taller, their edges gently uneven.
static func _ground(cv: Canvas, op: Dictionary) -> void:
	var cols := _cols(op.get("colors", []))
	var n := cols.size()
	if n == 0:
		return
	var total := 0.0
	for i in n:
		total += float(i) + 1.5
	var tops: Array = []
	var y := float(cv.hz)
	for i in n:
		tops.append(int(round(y)))
		y += float(cv.h - cv.hz) * (float(i) + 1.5) / total
	cv.fill(0, cv.hz, cv.w, cv.h, cols[0])
	for i in range(1, n):
		var off := 0
		var reach := 1 + i / 2
		for x in cv.w:
			if cv.rng.randf() < 0.12:
				off = clampi(off + (1 if cv.rng.randf() < 0.5 else -1), -reach, reach)
			cv.fill(x, int(tops[i]) + off, x + 1, cv.h, cols[i])


## A band of water across the ground (fractions of the ground), with glints and a line of foam at its edge.
static func _water(cv: Canvas, op: Dictionary) -> void:
	var cols := _cols(op.get("colors", []))
	if cols.is_empty():
		return
	var span := _pair(op.get("y"), [0.0, 0.3])
	var y0 := cv.ground_y(span[0])
	var y1 := cv.ground_y(span[1])
	var n := cols.size()
	for i in n:
		cv.fill(0, y0 + (y1 - y0) * i / n, cv.w, y0 + (y1 - y0) * (i + 1) / n, cols[i])
	var glint := _col(op.get("glint"), Color(0, 0, 0, 0))
	for i in cv.ri(op.get("glints"), 24):
		var gy := cv.rng.randi_range(y0, maxi(y0, y1 - 2))
		var ln := 2 + (gy - y0) * 5 / maxi(1, y1 - y0)
		var gx := cv.rng.randi_range(0, cv.w - 1)
		cv.fill(gx, gy, gx + ln, gy + 1, glint)
	var foam := _col(op.get("foam"), Color(0, 0, 0, 0))
	if foam.a > 0.0:
		var off := 0
		for x in cv.w:
			if cv.rng.randf() < 0.15:
				off = clampi(off + (1 if cv.rng.randf() < 0.5 else -1), -1, 1)
			cv.put(x, y1 + off, foam)


## A track across the ground (fractions of it) that winds a little, with two worn ruts.
static func _road(cv: Canvas, op: Dictionary) -> void:
	var cols := _cols(op.get("colors", []))
	if cols.is_empty():
		return
	var span := _pair(op.get("y"), [0.3, 0.5])
	var y0 := cv.ground_y(span[0])
	var y1 := cv.ground_y(span[1])
	var amp := float(op.get("wave", 2.0))
	var ph := cv.rng.randf() * TAU
	var fr := cv.rng.randf_range(0.012, 0.025)
	for x in cv.w:
		var off := int(round(sin(float(x) * fr + ph) * amp))
		var top := y0 + off
		var bot := y1 + off
		cv.fill(x, top, x + 1, bot, cols[0])
		if cols.size() > 1 and (x / 3) % 4 != 0:
			var quarter := maxi(1, (bot - top) / 4)
			cv.put(x, top + quarter, cols[1])
			cv.put(x, bot - quarter - 1, cols[1])
		if cols.size() > 2:
			cv.put(x, top, cols[2])


## Pools of still water lying on the ground, rimmed with the sky's light along their far edge.
static func _pools(cv: Canvas, op: Dictionary) -> void:
	var cols := _cols(op.get("colors", []))
	if cols.is_empty():
		return
	var water: Color = cols[0]
	var rim: Color = cols[1] if cols.size() > 1 else water.lightened(0.3)
	var span := _pair(op.get("y"), [0.1, 0.9])
	var pools: Array = []
	for i in cv.ri(op.get("count"), 4):
		pools.append(Vector3i(cv.rng.randi_range(0, cv.w - 1), cv.ground_y(cv.rng.randf_range(span[0], span[1])), maxi(6, cv.ri(op.get("w", [14, 40]), 20))))
	pools.sort_custom(func(a, b): return a.y < b.y)
	for p: Vector3i in pools:
		var half_w := p.z / 2
		var ph := maxi(1, p.z / 7)
		for dx in range(-half_w, half_w + 1):
			var f := float(dx) / float(maxi(1, half_w))
			var depth := int(round(float(ph) * sqrt(maxf(0.0, 1.0 - f * f))))
			if depth <= 0:
				continue
			cv.fill(p.x + dx, p.y - depth, p.x + dx + 1, p.y + depth, water)
			cv.put(p.x + dx, p.y - depth, rim)
		cv.fill(p.x - half_w / 3, p.y, p.x - half_w / 3 + maxi(2, half_w / 3), p.y + 1, rim)


## Glowing cracks across the ground: lava, or the light of a rift.
static func _cracks(cv: Canvas, op: Dictionary) -> void:
	var cols := _cols(op.get("colors", []))
	if cols.is_empty():
		return
	var span := _pair(op.get("y"), [0.1, 1.0])
	for i in cv.ri(op.get("count"), 8):
		var x := cv.rng.randi_range(0, cv.w - 1)
		var y := cv.ground_y(cv.rng.randf_range(span[0], span[1]))
		var dir := -1 if cv.rng.randf() < 0.5 else 1
		for s in maxi(2, cv.ri(op.get("len", [6, 18]), 10)):
			cv.put(x, y, cols[0])
			if cols.size() > 1 and s % 3 == 1:
				cv.put(x, y, cols[1])
			x += dir
			if cv.rng.randf() < 0.3:
				y += 1 if cv.rng.randf() < 0.5 else -1
				cv.put(x, y, cols[0])


## Small things drawn straight onto the ground, scattered and nearer ones larger: "tuft" (grass), "flower"
## (a tuft with a bloom of the last colour), "pebble", "dash" (streaks in the soil) and "rock".
static func _details(cv: Canvas, op: Dictionary) -> void:
	var cols := _cols(op.get("colors", []))
	if cols.is_empty():
		return
	var lit: Color = cols[0]
	var shade: Color = cols[mini(1, cols.size() - 1)]
	var kind := str(op.get("kind", "tuft"))
	var span := _pair(op.get("y"), [0.0, 1.0])
	var xs := _pair(op.get("x"), [0.0, 1.0])
	var spots: Array = []
	for i in cv.ri(op.get("count"), 20):
		spots.append(Vector2i(cv.rng.randi_range(int(xs[0] * cv.w), int(xs[1] * cv.w) - 1), cv.ground_y(cv.rng.randf_range(span[0], span[1]))))
	spots.sort_custom(func(a, b): return a.y < b.y)
	for p in spots:
		var near := float(p.y - cv.hz) / float(maxi(1, cv.h - cv.hz))   # 0 at the horizon, 1 at the bottom
		match kind:
			"tuft", "flower":
				var t := 2 if near < 0.35 else 3
				for k in t:
					cv.put(p.x, p.y - k, lit)
				for k in t - 1:
					cv.put(p.x - 1, p.y - k, lit)
					cv.put(p.x + 1, p.y - k, shade)
				if kind == "flower" and cols.size() > 2:
					cv.put(p.x, p.y - t, cols[cols.size() - 1])
			"pebble":
				cv.put(p.x, p.y, lit)
				cv.put(p.x + 1, p.y, shade)
				if near > 0.5:
					cv.fill(p.x, p.y + 1, p.x + 3, p.y + 2, shade)
			"dash":
				var ln := 2 + int(near * 4.0)
				cv.fill(p.x, p.y, p.x + ln, p.y + 1, lit)
			"rock":
				var rw := 3 + int(near * 5.0) + cv.rng.randi_range(0, 2)
				var rh := maxi(2, rw / 2)
				for dx in range(-rw / 2, rw / 2 + 1):
					var f := float(dx) / float(maxi(1, rw / 2))
					var top := int(round(float(rh) * sqrt(maxf(0.0, 1.0 - f * f))))
					for dy in range(0, top + 1):
						cv.put(p.x + dx, p.y - dy, lit if dx < 0 and dy > 0 else shade)
				if cols.size() > 2:
					cv.fill(p.x - rw / 2, p.y, p.x + rw / 2 + 1, p.y + 1, cols[2])


## Props from "props" (grids like the sprites) scattered over the ground, the far ones drawn first.
## "recolor" swaps a prop's palette keys for this scene's colours.
static func _scatter(cv: Canvas, op: Dictionary) -> void:
	var ids: Array = (op.get("props", []) as Array).filter(func(id): return cv.props.has(str(id)))
	if ids.is_empty():
		return
	var span := _pair(op.get("y"), [0.0, 1.0])
	var xs := _pair(op.get("x"), [0.0, 1.0])
	var spots: Array = []
	for i in cv.ri(op.get("count"), 10):
		spots.append([cv.rng.randi_range(int(xs[0] * cv.w), int(xs[1] * cv.w) - 1), cv.ground_y(cv.rng.randf_range(span[0], span[1])), str(ids[cv.rng.randi() % ids.size()]), cv.rng.randf() < 0.5])
	spots.sort_custom(func(a, b): return a[1] < b[1])
	var recolor: Dictionary = op.get("recolor", {}) if typeof(op.get("recolor")) == TYPE_DICTIONARY else {}
	for s in spots:
		_stamp(cv, cv.props[s[2]], int(s[0]), int(s[1]), bool(s[3]), recolor)


## One prop at a fraction of the width, its bottom row `base` rows below the horizon.
static func _prop(cv: Canvas, op: Dictionary) -> void:
	var id := str(op.get("id", ""))
	if not cv.props.has(id):
		return
	var recolor: Dictionary = op.get("recolor", {}) if typeof(op.get("recolor")) == TYPE_DICTIONARY else {}
	_stamp(cv, cv.props[id], int(round(float(op.get("x", 0.5)) * cv.w)), cv.hz + int(op.get("base", 0)), bool(op.get("flip", false)), recolor)


## A grid drawn with its bottom row's middle at (cx, bottom), mirrored if asked.
static func _stamp(cv: Canvas, s: Dictionary, cx: int, bottom: int, flip: bool, recolor: Dictionary) -> void:
	var size := _pair(s.get("size"), [1, 1])
	var w := int(size[0])
	var h := int(size[1])
	var pal := {}
	var raw: Dictionary = s.get("palette", {})
	for k in raw:
		pal[k] = Color.html(str(raw[k])) if Color.html_is_valid(str(raw[k])) else Color(0, 0, 0, 0)
	for k in recolor:
		if Color.html_is_valid(str(recolor[k])):
			pal[k] = Color.html(str(recolor[k]))
	var rows: Array = s.get("rows", [])
	var left := cx - w / 2
	var top := bottom - h + 1
	for y in mini(h, rows.size()):
		var line := str(rows[y])
		for x in mini(w, line.length()):
			var ch := line[x]
			if ch != "." and pal.has(ch):
				cv.put(left + (w - 1 - x if flip else x), top + y, pal[ch])


# ---------------------------------------------------------------- the air: haze, tints, weather

## A see-through band across the picture (fractions of its height): mist, smoke, a glow on the horizon.
static func _band(cv: Canvas, op: Dictionary) -> void:
	var span := _pair(op.get("y"), [0.3, 0.4])
	var c := _col(op.get("color"), Color.WHITE)
	c.a = clampf(float(op.get("alpha", 0.3)), 0.0, 1.0)
	cv.fill(0, int(round(span[0] * cv.h)), cv.w, int(round(span[1] * cv.h)), c)


## Every pixel of the sky, the ground or all of it moved toward a colour: a grey sky, snow on the ground.
static func _tint(cv: Canvas, op: Dictionary) -> void:
	var c := _col(op.get("color"), Color.WHITE)
	var amount := clampf(float(op.get("amount", 0.3)), 0.0, 1.0)
	var region := str(op.get("region", "all"))
	var y0 := cv.hz if region == "ground" else 0
	var y1 := cv.hz if region == "sky" else cv.h
	cv.fill(0, y0, cv.w, y1, Color(c, amount))   # over opaque pixels, the same as moving each toward the colour


## Rain, snow, embers and motes, still in the air: "dot", "plus" (a glowing point), "streak" (rain falling
## at a slant, `len` long) or "flake" (some two pixels wide).
static func _particles(cv: Canvas, op: Dictionary) -> void:
	var cols := _cols(op.get("colors", ["#ffffff"]))
	if cols.is_empty():
		return
	var alpha := clampf(float(op.get("alpha", 1.0)), 0.0, 1.0)
	var shape := str(op.get("shape", "dot"))
	var span := _pair(op.get("y"), [0.0, 1.0])
	var ln := maxi(1, int(op.get("len", 3)))
	for i in cv.ri(op.get("count"), 40):
		var x := cv.rng.randi_range(0, cv.w - 1)
		var y := int(round(cv.rng.randf_range(span[0], span[1]) * cv.h))
		var c: Color = Color(cols[cv.rng.randi() % cols.size()], alpha)
		match shape:
			"plus":
				cv.put(x, y, c)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					cv.put(x + d.x, y + d.y, Color(c, alpha * 0.4))
			"streak":
				for k in ln:
					cv.put(x - k / 2, y + k, c)
			"flake":
				cv.put(x, y, c)
				if cv.rng.randf() < 0.3:
					cv.put(x + 1, y, c)
					cv.put(x, y + 1, c)
					cv.put(x + 1, y + 1, c)
			_:
				cv.put(x, y, c)


# ---------------------------------------------------------------- shapes and helpers

## The upper half of an ellipse standing on row `base`.
static func _dome(cv: Canvas, cx: int, base: int, rx: int, ry: int, c: Color) -> void:
	if rx < 1 or ry < 1:
		return
	for dy in range(0, ry + 1):
		var f := float(dy) / float(ry)
		var half := int(round(float(rx) * sqrt(maxf(0.0, 1.0 - f * f))))
		cv.fill(cx - half, base - dy, cx + half + 1, base - dy + 1, c)


static func _disc(cv: Canvas, cx: int, cy: int, r: int, c: Color) -> void:
	for dy in range(-r, r + 1):
		var half := int(round(sqrt(maxf(0.0, float(r * r - dy * dy)))))
		cv.fill(cx - half, cy + dy, cx + half + 1, cy + dy + 1, c)


static func _cols(v: Variant) -> Array:
	var out: Array = []
	if typeof(v) != TYPE_ARRAY:
		return out
	for c in v:
		out.append(Color.html(str(c)) if Color.html_is_valid(str(c)) else Color(0, 0, 0, 0))
	return out


static func _col(v: Variant, fallback: Color) -> Color:
	if typeof(v) == TYPE_STRING and Color.html_is_valid(str(v)):
		return Color.html(str(v))
	return fallback


## A [low, high] pair of numbers, or the fallback.
static func _pair(v: Variant, fallback: Array) -> Array:
	if typeof(v) == TYPE_ARRAY and (v as Array).size() == 2 and _num(v[0]) and _num(v[1]):
		return [float(v[0]), float(v[1])]
	return [float(fallback[0]), float(fallback[1])]


static func _num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


# ---------------------------------------------------------------- checking the data

## Problems with the scenery data, one readable line each; [] when it is sound.
static func validate() -> Array:
	_load()
	var out: Array = []
	var scenes = _data.get("scenes", {})
	if typeof(scenes) != TYPE_DICTIONARY or (scenes as Dictionary).is_empty():
		return ["scenery: no scenes"]
	var props = _data.get("props", {})
	if typeof(props) != TYPE_DICTIONARY:
		return ["scenery: props must be a dictionary"]
	for id in props:
		var s = props[id]
		if typeof(s) != TYPE_DICTIONARY:
			out.append("prop %s: not a grid" % id)
			continue
		out.append_array(SpriteArt._grid_problems("prop " + str(id), s.get("rows", []), s.get("size", [0, 0]), s.get("palette", {}), false))
	for id in scenes:
		var sc = scenes[id]
		if typeof(sc) != TYPE_DICTIONARY:
			out.append("scene %s: not a dictionary" % id)
			continue
		for op in sc.get("layers", []):
			out.append_array(_op_problems("scene " + str(id), op, props))
	var places = _data.get("places", {})
	for id in places:
		var p = places[id]
		if typeof(p) != TYPE_DICTIONARY:
			out.append("place %s: not a dictionary" % id)
			continue
		if GameWorld.place(str(id)).is_empty():
			out.append("place %s: no such place in the world" % id)
		if p.has("scene") and not scenes.has(str(p["scene"])):
			out.append("place %s: no scene called %s" % [id, p["scene"]])
		for op in p.get("layers", []):
			out.append_array(_op_problems("place " + str(id), op, props))
	for key in ["seasons", "weather"]:
		var group = _data.get(key, {})
		for id in group:
			for op in group[id]:
				out.append_array(_op_problems("%s %s" % [key, id], op, props))
	return out


static func _op_problems(where: String, op: Variant, props: Dictionary) -> Array:
	if typeof(op) != TYPE_DICTIONARY:
		return ["%s: a layer that is not a dictionary" % where]
	var out: Array = []
	var kind := str(op.get("op", ""))
	if not OPS.has(kind):
		out.append("%s: no layer called '%s'" % [where, kind])
	var keys: Array = (op as Dictionary).keys()
	for k in keys:
		if str(k) in ["colors", "snow", "trunk"]:
			for c in op[k]:
				if not Color.html_is_valid(str(c)):
					out.append("%s: %s in %s is not a colour" % [where, c, kind])
		elif str(k) in ["color", "glow", "glint", "foam", "lights", "mortar", "base_color"]:
			if not Color.html_is_valid(str(op[k])):
				out.append("%s: %s of %s is not a colour" % [where, k, kind])
		elif SEASONS.has(str(k)) and typeof(op[k]) != TYPE_DICTIONARY:
			out.append("%s: the %s change of %s must be a dictionary" % [where, k, kind])
	for id in op.get("props", []):
		if not props.has(str(id)):
			out.append("%s: no prop called %s" % [where, id])
	if kind == "prop" and not props.has(str(op.get("id", ""))):
		out.append("%s: no prop called %s" % [where, op.get("id", "")])
	return out
