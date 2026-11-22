## The walls and gates of the open world's towns, painted as pixel art (rendering only; data/art/walls.json, GameWalls says where each
## piece stands). A tile is 16 pixels and about a metre: a wall piece is one tile wide and three tall (battlements, a cap, courses of
## stone, a dark foot), a tower piece four tall with an arrow slit, the tower beside a gate's passage with a banner in the town's colour,
## and over the passage a lintel at a cart's height: an arch with a portcullis on a north or south gate, a thick beam on an east or west
## one. Painted once and kept; nothing is random.
class_name WallArt
extends RefCounted

const PATH := "res://data/art/walls.json"
const TILE := 16

static var _cache: Dictionary = {}
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = GameData.load_json(PATH)
	return _data


static func _c(key: String, i: int = -1) -> Color:
	var v: Variant = data()["colors"][key]
	return Color.html(str(v[i] if i >= 0 else v))


## How many tiles tall a piece stands: the wall's, the tower's, or the lintel's (what it stands `lintel_height` tiles above the ground on).
static func tiles_tall(kind: String) -> float:
	match kind:
		"wall":
			return float(data()["wall_tiles"])
		"tower", "jamb":
			return float(data()["tower_tiles"])
	return float(data()["lintel_tiles"]) if kind in ["arch", "beam"] else 1.0


## The texture of a piece: `kind` is wall, tower, jamb, arch or beam; `variant` the brick pattern (0 or 1) or, for an arch, the slice
## across the passage (-1, 0, 1); `banner` the town's colour for a jamb.
static func texture(kind: String, variant: int = 0, banner: Color = Color.WHITE) -> Texture2D:
	var k := "%s:%d:%s" % [kind, variant, banner.to_html(false)]
	if not _cache.has(k):
		_cache[k] = ImageTexture.create_from_image(image(kind, variant, banner))
	return _cache[k]


static func _r(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(maxi(y, 0), mini(y + h, img.get_height())):
		for xx in range(maxi(x, 0), mini(x + w, img.get_width())):
			img.set_pixel(xx, yy, c)


## Battlements on the top six rows: merlons five wide with a three-pixel gap between (a period of eight, so tiles join), then the cap.
static func _top(img: Image, stone: Array, cap: Array, merlons: bool) -> void:
	var w := img.get_width()
	if merlons:
		for x in range(0, w, 8):
			_r(img, x, 0, 5, 6, stone[0])
			_r(img, x, 0, 5, 1, cap[0])
			_r(img, x + 4, 1, 1, 5, stone[1])
	_r(img, 0, 6, w, 1, cap[0])
	_r(img, 0, 7, w, 2, cap[1])


## Courses of stone (every eight rows, the joints offset on alternate courses) from row `y0` to `y1`.
static func _courses(img: Image, y0: int, y1: int, variant: int, stone: Array) -> void:
	var w := img.get_width()
	_r(img, 0, y0, w, y1 - y0, stone[0])
	var k := 0
	for y in range(y0, y1, 8):
		_r(img, 0, y, w, 1, _c("mortar"))
		var off := ((k + variant) % 2) * 8
		for x in range(off, w, 16):
			_r(img, x, y, 1, mini(8, y1 - y), _c("mortar"))
		_r(img, 0, y + 1, w, 1, stone[0].lightened(0.1))
		_r(img, 0, mini(y + 7, y1 - 1), w, 1, stone[1])
		k += 1


## Darkens the edge of the shape (opaque pixels beside clear ones, inside the picture).
static func _outline(img: Image) -> Image:
	var out := img.duplicate() as Image
	var o := _c("outline")
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a == 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < img.get_width() and ny < img.get_height() and img.get_pixel(nx, ny).a == 0.0:
					out.set_pixel(x, y, o)
					break
	return out


static func image(kind: String, variant: int = 0, banner: Color = Color.WHITE) -> Image:
	var tall := int(round(tiles_tall(kind) * TILE))
	var img := Image.create_empty(TILE, tall, false, Image.FORMAT_RGBA8)
	var stone: Array = [_c("stone", 0), _c("stone", 1)]
	var cap: Array = [_c("cap", 0), _c("cap", 1)]
	match kind:
		"wall":
			_top(img, stone, cap, true)
			_courses(img, 9, tall - 4, variant, stone)
			_r(img, 0, tall - 4, TILE, 4, stone[1].darkened(0.25))
			_r(img, 2 + variant * 7, tall - 6, 3, 2, _c("moss"))   # a patch of moss at the foot
		"tower", "jamb":
			var t: Array = [_c("tower", 0), _c("tower", 1)]
			_top(img, t, cap, true)
			_courses(img, 9, tall - 4, variant, t)
			_r(img, 7, 24, 2, 10, _c("slit"))   # an arrow slit
			_r(img, 0, 40, TILE, 2, t[1])
			_r(img, 0, tall - 4, TILE, 4, t[1].darkened(0.25))
			if kind == "jamb":
				_r(img, 7, 10, 2, 28, _c("pole"))   # a pole and a banner in the town's colour
				_r(img, 3, 12, 10, 14, banner)
				_r(img, 3, 12, 10, 2, banner.lightened(0.3))
		"arch":
			_top(img, stone, cap, true)
			_courses(img, 9, tall, variant + 1, stone)
			# the opening: an ellipse across the three slices (the slice -1, 0 or 1 is `variant`), a portcullis in its top
			for y in tall:
				for x in TILE:
					var gx := float((variant + 1) * TILE + x) - 24.0
					var gy := float(y) - float(tall)
					if gx * gx / (22.0 * 22.0) + gy * gy / (18.0 * 18.0) < 1.0 and y >= 9:
						img.set_pixel(x, y, Color(0, 0, 0, 0))
						if gy < -13.0 and (int(gx) + 100) % 3 == 0:
							img.set_pixel(x, y, _c("iron"))
		"beam":
			_top(img, stone, cap, true)
			_courses(img, 9, tall, variant, stone)
			_r(img, 0, tall - 3, TILE, 3, stone[1].darkened(0.2))
	return _outline(img)


## The walls' fade as the heir stands behind one: a piece hides what is up to its height behind it (a tall wall is drawn over the
## north of it), so a piece fades to `fade_alpha` while the heir stands behind it within a tile either side.
static func fade(tile: Vector2i, kind: String, heir: Vector2) -> float:
	var behind := heir.y < float(tile.y) + 1.0 and heir.y > float(tile.y) + 1.0 - tiles_tall(kind) - 1.0
	if behind and absf(heir.x - float(tile.x) - 0.5) <= 1.5:
		return float(data()["fade_alpha"])
	return 1.0


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["wall_tiles", "tower_tiles", "lintel_height", "lintel_tiles", "fade_alpha", "colors"]:
		if not dat.has(k):
			bad.append("walls art: %s is missing" % k)
	if not bad.is_empty():
		return bad
	if int(dat["wall_tiles"]) < 3 or int(dat["tower_tiles"]) <= int(dat["wall_tiles"]):
		bad.append("walls art: a wall is at least three tiles tall (a person is two) and a tower taller than the wall")
	if int(dat["lintel_height"]) < 3 or int(dat["lintel_tiles"]) < 1:
		bad.append("walls art: the lintel is at least three tiles up (a cart passes under) and a tile thick")
	if float(dat["fade_alpha"]) <= 0.0 or float(dat["fade_alpha"]) >= 1.0:
		bad.append("walls art: fade_alpha is between 0 and 1")
	for k in ["outline", "stone", "cap", "tower", "mortar", "moss", "slit", "wood", "iron", "pole"]:
		var v: Variant = dat["colors"].get(k)
		var list: Array = v if typeof(v) == TYPE_ARRAY else [v]
		if v == null or (typeof(v) == TYPE_ARRAY and list.size() != 2):
			bad.append("walls art: the colour '%s' is missing (or not [light, dark])" % k)
			continue
		for c in list:
			if not Color.html_is_valid(str(c)):
				bad.append("walls art: '%s' is not a colour" % c)
	if not bad.is_empty():
		return bad
	if int(GameData.load_json("res://data/world/sandbox.json")["tiles"]["px"]) != TILE:
		bad.append("walls art: a tile is not %d pixels in sandbox.json" % TILE)
	for kind in ["wall", "tower", "jamb", "arch", "beam"]:
		var img := image(kind, 0, Color.RED)
		var seen := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.0:
					seen += 1
		if seen < 40 or img.get_height() != int(round(tiles_tall(kind) * TILE)):
			bad.append("walls art: the %s piece paints nothing or the wrong height" % kind)
	return bad
