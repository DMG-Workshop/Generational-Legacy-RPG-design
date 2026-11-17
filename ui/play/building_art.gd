## The buildings of the open world's towns, painted as pixel art (rendering only; data/art/buildings.json, which says what each kind
## looks like, and GameTown, which says where they stand). A building is 48 by 32 pixels, three tiles by two: a roof over a wall with
## a door and windows, then the features of its kind (a forge's chimney and glow, a temple's cross, a store's awning). Painted once
## and kept; nothing is random.
class_name BuildingArt
extends RefCounted

const PATH := "res://data/art/buildings.json"
const W := 48
const H := 32

static var _cache: Dictionary = {}
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = GameData.load_json(PATH)
	return _data


static func _col(key: String) -> Color:
	return Color.html(str(data()["colors"][key]))


## The texture of a building of `kind` in `style` (a plain house's or the family house's look; the other kinds have one).
static func texture(kind: String, style: int = 0) -> Texture2D:
	var k := _key(kind, style)
	if not _cache.has(k):
		_cache[k] = ImageTexture.create_from_image(image(kind, style))
	return _cache[k]


static func _key(kind: String, style: int) -> String:
	var def: Dictionary = data()["kinds"].get(kind, {})
	return "%s:%d" % [kind, (style % (data()["styles"] as Array).size()) if bool(def.get("styled", false)) else 0]


## The pixels of one building.
static func image(kind: String, style: int = 0) -> Image:
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var def: Dictionary = data()["kinds"].get(kind, {})
	if def.is_empty():
		return img
	if str(def.get("shape", "")) == "board":
		_board(img)
		return _outline(img)
	var pal: Dictionary = def
	if bool(def.get("styled", false)):
		var styles: Array = data()["styles"]
		pal = styles[style % styles.size()]
	var roof_l := Color.html(str(pal["roof"][0]))
	var roof_d := Color.html(str(pal["roof"][1]))
	var wall_l := Color.html(str(pal["wall"][0]))
	var wall_d := Color.html(str(pal["wall"][1]))
	var feats: Array = def.get("features", [])
	# wall
	_r(img, 3, 15, 42, 15, wall_l)
	for x in range(3, 45, 6):
		_r(img, x, 15, 1, 15, wall_d)   # boards
	_r(img, 3, 28, 42, 2, wall_d)
	# roof: rows of shingles, a lit top edge and a dark eave
	_r(img, 1, 3, 46, 11, roof_l)
	for y in range(5, 14, 3):
		_r(img, 1, y, 46, 1, roof_d)
		for x in range(1 + ((y / 3) % 2) * 2, 47, 4):
			_r(img, x, y - 2, 1, 2, roof_d)
	_r(img, 1, 3, 46, 1, roof_l.lightened(0.3))
	_r(img, 0, 13, 48, 3, roof_d)
	# windows
	var shut := _col("shutter")
	for wx in [8, 34]:
		_r(img, wx - 1, 18, 8, 8, shut)
		_r(img, wx, 19, 6, 6, _col("glass"))
		_r(img, wx + 2, 19, 1, 6, _col("glass_dark"))
		_r(img, wx, 21, 6, 1, _col("glass_dark"))
	# door
	var door := _col("glow") if feats.has("glow") else _col("door")
	_r(img, 20, 19, 8, 11, _col("door_dark"))
	_r(img, 21, 20, 6, 10, door)
	if not feats.has("glow"):
		_r(img, 23, 20, 1, 10, _col("door_dark"))
		_dot(img, 25, 25, _col("gold"))
	else:
		_r(img, 22, 24, 4, 6, _col("glow").lightened(0.35))
	for f in feats:
		_feature(img, str(f), def, wall_d, roof_d)
	return _outline(img)


static func _feature(img: Image, f: String, def: Dictionary, wall_d: Color, roof_d: Color) -> void:
	match f:
		"chimney":
			_r(img, 36, 0, 5, 9, _col("stone"))
			_r(img, 36, 0, 1, 9, _col("stone").lightened(0.2))
			_r(img, 40, 0, 1, 9, _col("stone_dark"))
			_r(img, 35, 0, 7, 2, _col("stone_dark"))
		"anvil":
			_r(img, 21, 16, 6, 2, _col("iron"))
			_r(img, 21, 16, 6, 1, _col("iron").lightened(0.3))
			_r(img, 23, 18, 2, 1, _col("iron"))
		"cross":
			_r(img, 23, 0, 2, 9, _col("white"))
			_r(img, 21, 2, 6, 2, _col("white"))
			_r(img, 23, 0, 1, 9, _col("gold"))
		"round_window":
			for p in [Vector2i(23, 16), Vector2i(24, 16), Vector2i(22, 17), Vector2i(23, 17), Vector2i(24, 17), Vector2i(25, 17), Vector2i(23, 18), Vector2i(24, 18)]:
				_dot(img, p.x, p.y, _col("glass"))
			_dot(img, 23, 17, _col("gold"))
		"awning":
			var a: Array = def.get("awning", ["#e4dfd0", "#b8483a"])
			var c0 := Color.html(str(a[0]))
			var c1 := Color.html(str(a[1]))
			for i in 7:
				_r(img, 13 + i * 3, 15, 3, 5, c0 if i % 2 == 0 else c1)
				_dot(img, 14 + i * 3, 20, c0 if i % 2 == 0 else c1)
		"crate":
			_r(img, 29, 24, 5, 5, _col("crate"))
			_r(img, 29, 24, 5, 1, _col("crate").lightened(0.25))
			_r(img, 29, 26, 5, 1, _col("crate_dark"))
			_r(img, 31, 24, 1, 5, _col("crate_dark"))
		"sign":
			_r(img, 39, 16, 7, 1, _col("iron"))
			_r(img, 40, 17, 5, 6, _col("sign"))
			_r(img, 41, 18, 3, 3, _col("mug"))
			_dot(img, 44, 19, _col("mug"))
		"banner":
			_r(img, 23, 0, 1, 10, _col("iron"))
			_r(img, 24, 0, 7, 5, _col("flag"))
			_r(img, 24, 4, 7, 1, _col("flag").darkened(0.35))
			_dot(img, 26, 2, _col("gold"))
		"gold_trim":
			_r(img, 1, 12, 46, 1, _col("gold"))
			_r(img, 20, 18, 8, 1, _col("gold"))
		"lantern":
			_r(img, 16, 16, 1, 2, _col("iron"))
			_r(img, 15, 18, 3, 3, _col("lamp"))
			_dot(img, 16, 19, _col("lamp").lightened(0.4))


## The notice board: two posts, a roofed board and the notices on it.
static func _board(img: Image) -> void:
	var wood := _col("wood")
	var dark := _col("wood_dark")
	_r(img, 6, 8, 3, 22, dark)
	_r(img, 39, 8, 3, 22, dark)
	_r(img, 4, 5, 40, 3, dark)
	_r(img, 5, 8, 38, 15, wood)
	_r(img, 5, 8, 38, 1, wood.lightened(0.25))
	_r(img, 5, 22, 38, 1, dark)
	var paper := _col("paper")
	var paper2 := _col("paper2")
	for n in [[8, 10, 7, 8], [18, 11, 6, 7], [27, 10, 8, 9], [37, 12, 4, 6]]:
		_r(img, n[0], n[1], n[2], n[3], paper if n[0] % 2 == 0 else paper2)
		_r(img, n[0] + 1, n[1] + 2, n[2] - 2, 1, wood)
		_r(img, n[0] + 1, n[1] + 4, n[2] - 3, 1, wood)
		_dot(img, n[0] + n[2] / 2, n[1], _col("flag"))


static func _outline(img: Image) -> Image:
	var line := Color.html(str(data()["outline"]))
	var out := img.duplicate()
	for y in H:
		for x in W:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < W and ny < H and img.get_pixel(nx, ny).a > 0.0:
					out.set_pixel(x, y, line)
					break
	return out


static func _r(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var box := Rect2i(x, y, w, h).intersection(Rect2i(0, 0, W, H))
	if box.size.x > 0 and box.size.y > 0:
		img.fill_rect(box, c)


static func _dot(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		img.set_pixel(x, y, c)


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["outline", "colors", "styles", "kinds"]:
		if not dat.has(k):
			bad.append("buildings.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	if not Color.html_is_valid(str(dat["outline"])):
		bad.append("buildings.json: outline is not a colour")
	var needed := ["door", "door_dark", "glass", "glass_dark", "shutter", "gold", "flag", "stone", "stone_dark", "glow", "iron", "crate", "crate_dark", "sign", "mug", "wood", "wood_dark", "paper", "paper2", "lamp", "white"]
	for k in needed:
		if not dat["colors"].has(k) or not Color.html_is_valid(str(dat["colors"][k])):
			bad.append("buildings.json: colors.%s is missing or not a colour" % k)
	for s in dat["styles"]:
		for part in ["roof", "wall"]:
			if not s.has(part) or typeof(s[part]) != TYPE_ARRAY or s[part].size() != 2 or not Color.html_is_valid(str(s[part][0])) or not Color.html_is_valid(str(s[part][1])):
				bad.append("buildings.json: a style needs a roof and a wall of two colours")
	var features := ["chimney", "glow", "anvil", "cross", "round_window", "awning", "crate", "sign", "banner", "gold_trim", "lantern"]
	for kind in dat["kinds"]:
		var def: Dictionary = dat["kinds"][kind]
		if str(def.get("shape", "")) == "board":
			continue
		if not bool(def.get("styled", false)):
			for part in ["roof", "wall"]:
				if not def.has(part) or typeof(def[part]) != TYPE_ARRAY or def[part].size() != 2 or not Color.html_is_valid(str(def[part][0])) or not Color.html_is_valid(str(def[part][1])):
					bad.append("buildings.json: '%s' needs a roof and a wall of two colours (or to be styled)" % kind)
		for f in def.get("features", []):
			if not features.has(str(f)):
				bad.append("buildings.json: '%s' has the unknown feature '%s'" % [kind, f])
	# every building of GameTown has a look, and the size is the footprint's
	var seen := {}
	for b in GameTown.all():
		seen[str(b["kind"])] = true
	for kind in seen:
		if not dat["kinds"].has(kind):
			bad.append("buildings.json: the town building '%s' has no look" % kind)
	var px := int(GameData.load_json("res://data/world/sandbox.json")["tiles"]["px"])
	if int(GameTown.setting("w")) * px != W or int(GameTown.setting("h")) * px != H:
		bad.append("buildings.json: a building is %d by %d pixels, not the %d by %d tiles of towns.json at %d pixels a tile" % [W, H, GameTown.setting("w"), GameTown.setting("h"), px])
	return bad
