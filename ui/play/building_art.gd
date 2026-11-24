## The buildings of the open world's towns, painted as pixel art (rendering only; data/art/buildings.json, which says what each kind
## looks like, and GameTown, which says where they stand). A building is 48 by 32 pixels, three tiles by two: a roof over a wall with
## a door and windows, then the features of its kind (a forge's chimney and glow, a temple's cross, a store's awning). Painted once
## and kept; nothing is random.
class_name BuildingArt
extends RefCounted

const PATH := "res://data/art/buildings.json"
const TILE := 16   # a tile's pixels (sandbox.json tiles.px)

static var _cache: Dictionary = {}
static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = GameData.load_json(PATH)
	return _data


static func _col(key: String) -> Color:
	return Color.html(str(data()["colors"][key]))


## The texture of a building of `kind` in `style` (a plain house's or the family house's look; the other kinds have one), `w` by
## `h` tiles (the default 3 by 2): the art is drawn to the size, so a hut and a hall are not one picture stretched.
static func texture(kind: String, style: int = 0, w: int = 3, h: int = 2, door_scale: float = 1.0) -> Texture2D:
	var k := _key(kind, style, w, h) + ":%.2f" % door_scale
	if not _cache.has(k):
		_cache[k] = ImageTexture.create_from_image(image(kind, style, w, h, door_scale))
	return _cache[k]


static func _key(kind: String, style: int, w: int = 3, h: int = 2) -> String:
	var def: Dictionary = data()["kinds"].get(kind, {})
	return "%s:%d:%dx%d" % [kind, (style % (data()["styles"] as Array).size()) if bool(def.get("styled", false)) else 0, w, h]


## The pixels of one building, `w` by `h` tiles of TILE pixels.
## `door_scale` is the size of the tallest who lives there against a human (GameVillagers.door_scale): the door is made for them.
static func image(kind: String, style: int = 0, w: int = 3, h: int = 2, door_scale: float = 1.0) -> Image:
	var cw := w * TILE
	var ch := h * TILE
	var img := Image.create_empty(cw, ch, false, Image.FORMAT_RGBA8)
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
	# the door is made for the tallest who lives there, with headroom: a person is `figure_tiles` tall, so a human's door is a little over
	# that. A small building thins its roof so the wall can hold it (a door never reaches into the roof), and a very tall resident's door
	# is as tall as the wall allows.
	var dd: Dictionary = data()["door"]
	var person_px := float(TILE) * float(GameSandbox.data()["view"]["figure_tiles"])
	var want := roundi(person_px * float(dd["headroom"]) * door_scale)
	var most := ch - 4 - int(dd["min_roof"]) - 2 - int(dd["above"])
	var dh := clampi(want, 11, maxi(11, most))
	var roof_end := mini(3 + roundi(float(ch - 6) * 0.4), maxi(int(dd["min_roof"]), ch - 4 - dh - int(dd["above"])))   # where the roof's shingles end
	var wall_top := roof_end + 2
	var dcx := ((w - 1) / 2) * TILE + TILE / 2   # the door's middle: the bottom-middle tile's
	# wall
	_r(img, 3, wall_top, cw - 6, ch - 2 - wall_top, wall_l)
	for x in range(3, cw - 3, 6):
		_r(img, x, wall_top, 1, ch - 2 - wall_top, wall_d)   # boards
	_r(img, 3, ch - 4, cw - 6, 2, wall_d)
	# roof: rows of shingles, a lit top edge and a dark eave
	_r(img, 1, 3, cw - 2, roof_end - 2, roof_l)
	for y in range(5, roof_end + 1, 3):
		_r(img, 1, y, cw - 2, 1, roof_d)
		for x in range(1 + ((y / 3) % 2) * 2, cw - 1, 4):
			_r(img, x, y - 2, 1, 2, roof_d)
	_r(img, 1, 3, cw - 2, 1, roof_l.lightened(0.3))
	_r(img, 0, roof_end, cw, 3, roof_d)
	# windows: in the tiles an odd number of tiles from the door's, so they sit evenly either side of it; two rows on a tall wall
	var wall_h := ch - 2 - wall_top
	var ws := 8 if wall_h < 30 else 10
	var rows := 2 if wall_h >= 40 else 1
	var shut := _col("shutter")
	var dcol := (w - 1) / 2
	for i in w:
		if absi(i - dcol) % 2 == 0:
			continue
		var wx := i * TILE + (TILE - ws) / 2
		for r in rows:
			var wy := wall_top + 4 + r * (ws + 8)
			_r(img, wx - 1, wy - 1, ws + 2, ws + 2, shut)
			_r(img, wx, wy, ws, ws, _col("glass"))
			_r(img, wx + ws / 2 - 1, wy, 1, ws, _col("glass_dark"))
			_r(img, wx, wy + ws / 2, ws, 1, _col("glass_dark"))
	# door: its height is `dh` above; as wide as the race needs, up to a whole tile
	var dw := clampi(roundi(float(dd["width"]) * minf(door_scale, 1.6)), 8, TILE)
	var dy := ch - 2 - dh
	var door := _col("glow") if feats.has("glow") else _col("door")
	_r(img, dcx - dw / 2, dy, dw, dh, _col("door_dark"))
	_r(img, dcx - dw / 2 + 1, dy + 1, dw - 2, dh - 1, door)
	if not feats.has("glow"):
		_r(img, dcx - 1, dy + 1, 1, dh - 1, _col("door_dark"))
		_dot(img, dcx + dw / 2 - 3, dy + dh / 2, _col("gold"))
	else:
		_r(img, dcx - dw / 2 + 2, dy + dh / 2, dw - 4, dh / 2 - 1, _col("glow").lightened(0.35))
	var at := {"w": cw, "h": ch, "dcx": dcx, "roof_end": roof_end, "wall_top": wall_top}
	for f in feats:
		_feature(img, str(f), def, wall_d, roof_d, at)
	return _outline(img)


static func _feature(img: Image, f: String, def: Dictionary, wall_d: Color, roof_d: Color, at: Dictionary) -> void:
	var cw: int = at["w"]
	var dcx: int = at["dcx"]
	var wt: int = at["wall_top"]
	var re: int = at["roof_end"]
	match f:
		"chimney":
			var cx := cw - 12
			_r(img, cx, 0, 5, re - 4, _col("stone"))
			_r(img, cx, 0, 1, re - 4, _col("stone").lightened(0.2))
			_r(img, cx + 4, 0, 1, re - 4, _col("stone_dark"))
			_r(img, cx - 1, 0, 7, 2, _col("stone_dark"))
		"anvil":
			_r(img, dcx - 3, wt + 1, 6, 2, _col("iron"))
			_r(img, dcx - 3, wt + 1, 6, 1, _col("iron").lightened(0.3))
			_r(img, dcx - 1, wt + 3, 2, 1, _col("iron"))
		"cross":
			_r(img, dcx - 1, 0, 2, re - 4, _col("white"))
			_r(img, dcx - 3, 2, 6, 2, _col("white"))
			_r(img, dcx - 1, 0, 1, re - 4, _col("gold"))
		"round_window":
			for p in [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(-2, 1), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 2), Vector2i(0, 2)]:
				_dot(img, dcx + p.x, wt + 1 + p.y, _col("glass"))
			_dot(img, dcx - 1, wt + 2, _col("gold"))
		"awning":
			var a: Array = def.get("awning", ["#e4dfd0", "#b8483a"])
			var c0 := Color.html(str(a[0]))
			var c1 := Color.html(str(a[1]))
			var n := 7 if cw <= 64 else 15
			for i in n:
				_r(img, dcx - n * 3 / 2 + i * 3, wt, 3, 5, c0 if i % 2 == 0 else c1)
				_dot(img, dcx - n * 3 / 2 + 1 + i * 3, wt + 5, c0 if i % 2 == 0 else c1)
		"crate":
			var ch: int = at["h"]
			var cx := dcx + 5
			_r(img, cx, ch - 8, 5, 5, _col("crate"))
			_r(img, cx, ch - 8, 5, 1, _col("crate").lightened(0.25))
			_r(img, cx, ch - 6, 5, 1, _col("crate_dark"))
			_r(img, cx + 2, ch - 8, 1, 5, _col("crate_dark"))
		"sign":
			var sx := cw - 9
			_r(img, sx, wt + 1, 7, 1, _col("iron"))
			_r(img, sx + 1, wt + 2, 5, 6, _col("sign"))
			_r(img, sx + 2, wt + 3, 3, 3, _col("mug"))
			_dot(img, sx + 5, wt + 4, _col("mug"))
		"banner":
			_r(img, dcx - 1, 0, 1, re - 3, _col("iron"))
			_r(img, dcx, 0, 7, 5, _col("flag"))
			_r(img, dcx, 4, 7, 1, _col("flag").darkened(0.35))
			_dot(img, dcx + 2, 2, _col("gold"))
		"gold_trim":
			_r(img, 1, re - 1, cw - 2, 1, _col("gold"))
			_r(img, dcx - 4, wt + 3, 8, 1, _col("gold"))
		"sign_icon":
			var sx := maxi(1, dcx - 17)
			var icon: Array = data().get("icons", {}).get(str(def.get("icon", "")), [])
			_r(img, sx + 4, wt, 1, 3, _col("iron"))
			_r(img, sx, wt + 2, 11, 12, _col("sign"))
			_r(img, sx, wt + 2, 11, 1, _col("sign").lightened(0.25))
			var main := Color.html(str(def.get("icon_color", "#f0e6c8")))
			for row in icon.size():
				for col in str(icon[row]).length():
					var ch := str(icon[row])[col]
					if ch == "x":
						_dot(img, sx + 1 + col + (1 if col > 6 else 0) * 0, wt + 4 + row, main)
					elif ch == "o":
						_dot(img, sx + 1 + col, wt + 4 + row, main.darkened(0.45))
		"barrels":
			var ch2: int = at["h"]
			for k in 2:
				var bx := dcx + 10 + k * 7
				_r(img, bx, ch2 - 11, 6, 8, _col("barrel"))
				_r(img, bx, ch2 - 9, 6, 1, _col("hoop"))
				_r(img, bx, ch2 - 6, 6, 1, _col("hoop"))
				_r(img, bx + 1, ch2 - 11, 4, 1, _col("barrel").lightened(0.3))
		"sails":
			var mx := cw / 2
			_r(img, mx - 1, 2, 3, 14, _col("wood_dark"))
			_r(img, mx - 14, 7, 28, 3, _col("wood_dark"))
			_r(img, mx - 13, 4, 8, 3, _col("paper"))
			_r(img, mx + 5, 10, 8, 3, _col("paper"))
			_r(img, mx - 4, 2, 3, 6, _col("paper2"))
			_r(img, mx + 2, 9, 3, 6, _col("paper2"))
		"pole":
			var px := cw - 8
			for k in 6:
				var c := _col("stripe_red") if k % 3 == 0 else (_col("white") if k % 3 == 1 else _col("stripe_blue"))
				_r(img, px, wt + 2 + k * 3, 3, 3, c)
			_r(img, px - 1, wt + 1, 5, 1, _col("gold"))
		"lantern":
			var lx := dcx - 8
			_r(img, lx, wt + 1, 1, 2, _col("iron"))
			_r(img, lx - 1, wt + 3, 3, 3, _col("lamp"))
			_dot(img, lx, wt + 4, _col("lamp").lightened(0.4))


## What a building looks like with its roof off, seen from above: planks, a wall round, its door, and the furniture of its kind
## (`furniture` in buildings.json), laid out to its size (`w` by `h` tiles). Nobody is drawn in it. Null for the notice board, which
## has no inside. Painted once and kept.
static func inside(kind: String, style: int = 0, w: int = 3, h: int = 2) -> Texture2D:
	var def: Dictionary = data()["kinds"].get(kind, {})
	if def.is_empty() or str(def.get("shape", "")) == "board":
		return null
	var k := "in:%s:%dx%d" % [kind, w, h]
	if not _cache.has(k):
		_cache[k] = ImageTexture.create_from_image(inside_image(kind, w, h))
	return _cache[k]


static func inside_image(kind: String, w: int = 3, h: int = 2) -> Image:
	var cw := w * TILE
	var ch := h * TILE
	var img := Image.create_empty(cw, ch, false, Image.FORMAT_RGBA8)
	var def: Dictionary = data().get("kinds", {}).get(kind, {})
	var ins: Dictionary = data()["inside"]
	var fl := Color.html(str(ins["floor"][0]))
	var fd := Color.html(str(ins["floor"][1]))
	var wall := Color.html(str(ins["wall"]))
	_r(img, 0, 0, cw, ch, fl)
	for y in range(5, ch, 6):
		_r(img, 0, y, cw, 1, fd)   # the seams of the boards
	for x in range(7, cw, 13):
		for y in range(0, ch, 12):
			_r(img, x, y, 1, 5, fd)
	_r(img, 0, 0, cw, 3, wall)
	_r(img, 0, ch - 3, cw, 3, wall)
	_r(img, 0, 0, 3, ch, wall)
	_r(img, cw - 3, 0, 3, ch, wall)
	_r(img, 0, 3, cw, 1, wall.darkened(0.3))
	var dcx := ((w - 1) / 2) * TILE + TILE / 2
	_r(img, dcx - 5, ch - 3, 10, 3, _col("door"))   # the door, in the south wall
	for f in def.get("furniture", []):
		_furniture(img, str(f), ins, cw, ch)
	return _outline_box(img)


## A drawing of a piece of furniture at its own place in the room, sized to people (a tile is about a metre: a bed is a tile
## wide and two long, a table two by one): against the walls, the larger pieces spreading with the room.
static func _furniture(img: Image, f: String, ins: Dictionary, cw: int, ch: int) -> void:
	var wood := Color.html(str(ins["wood"]))
	var cloth := Color.html(str(ins["cloth"]))
	var mx := cw / 2
	var my := ch / 2
	match f:
		"bed":
			_r(img, 16, 16, 32, 16, wood)
			_r(img, 17, 17, 9, 14, cloth)   # the pillow, at the head
			_r(img, 26, 17, 21, 14, Color.html(str(ins["blanket"])))
		"table":
			_r(img, mx - 16, my - 8, 32, 16, wood)
			_r(img, mx - 16, my - 8, 32, 2, wood.lightened(0.25))
			_dot(img, mx - 8, my, cloth)
			_dot(img, mx + 6, my, _col("mug"))
			_r(img, mx - 20, my - 4, 3, 8, wood.darkened(0.2))   # a bench each side
			_r(img, mx + 17, my - 4, 3, 8, wood.darkened(0.2))
		"hearth":
			_r(img, cw - 46, 4, 30, 14, _col("stone"))
			_r(img, cw - 43, 7, 24, 9, Color.html(str(ins["ember"])))
			_r(img, cw - 40, 9, 18, 5, Color.html(str(ins["fire"][0])))
			_r(img, cw - 36, 10, 10, 3, Color.html(str(ins["fire"][1])))
		"chest":
			_r(img, cw - 32, ch - 30, 16, 10, wood.darkened(0.15))
			_r(img, cw - 32, ch - 30, 16, 2, wood.lightened(0.3))
			_dot(img, cw - 25, ch - 25, _col("gold"))
		"anvil_floor":
			_r(img, mx - 12, my - 6, 24, 8, _col("iron"))
			_r(img, mx - 12, my - 6, 24, 2, _col("iron").lightened(0.3))
			_r(img, mx - 5, my + 2, 10, 8, _col("iron"))
		"forge_fire":
			_r(img, cw - 50, 4, 34, 16, _col("stone"))
			_r(img, cw - 47, 7, 28, 11, Color.html(str(ins["ember"])))
			_r(img, cw - 44, 9, 22, 7, Color.html(str(ins["fire"][0])))
			_r(img, cw - 40, 11, 12, 3, Color.html(str(ins["fire"][1])))
		"rack":
			_r(img, 8, 5, 44, 6, wood)
			for x in range(12, 50, 8):
				_r(img, x, 5, 2, 6, _col("iron"))
		"altar":
			_r(img, mx - 14, 6, 28, 12, _col("stone"))
			_r(img, mx - 14, 6, 28, 2, _col("white"))
			_r(img, mx - 1, 9, 2, 8, _col("gold"))
			_r(img, mx - 3, 11, 6, 2, _col("gold"))
		"pews":
			var half := maxi(12, mx - 28)
			for row in range(my - 4, ch - 24, 14):
				_r(img, 14, row, half, 5, wood)
				_r(img, cw - 14 - half, row, half, 5, wood)
		"counter":
			_r(img, 10, my - 6, cw - 20, 8, wood)
			_r(img, 10, my - 6, cw - 20, 2, wood.lightened(0.3))
		"shelves":
			_r(img, 8, 4, cw - 16, 8, wood.darkened(0.1))
			for x in range(10, cw - 14, 9):
				_r(img, x, 5, 5, 5, _col("crate") if (x / 9) % 2 == 0 else _col("paper"))
		"crates":
			_r(img, 8, ch - 26, 14, 14, _col("crate"))
			_r(img, 8, ch - 26, 14, 2, _col("crate").lightened(0.25))
			_r(img, cw - 24, ch - 28, 14, 14, _col("crate"))
			_r(img, cw - 24, ch - 28, 14, 2, _col("crate").lightened(0.25))
			_r(img, 24, ch - 22, 10, 10, _col("crate_dark"))
		"bar":
			_r(img, 8, 6, cw - 16, 8, wood)
			_r(img, 8, 6, cw - 16, 2, wood.lightened(0.3))
			for x in range(14, cw - 12, 12):
				_dot(img, x, 9, _col("mug"))
		"tables":
			for t in [Vector2i(16, my), Vector2i(cw - 32, my), Vector2i(16, ch - 30), Vector2i(cw - 32, ch - 30)]:
				_r(img, t.x, t.y, 16, 10, wood)
				_dot(img, t.x + 4, t.y + 4, _col("mug"))
				_dot(img, t.x + 11, t.y + 4, _col("mug"))
		"rug":
			var rw := maxi(8, cw - 48)
			var rh := maxi(8, ch - 44)
			_r(img, (cw - rw) / 2, (ch - rh) / 2, rw, rh, Color.html(str(ins["rug"])))
			_r(img, (cw - rw) / 2 + 2, (ch - rh) / 2 + 2, rw - 4, rh - 4, Color.html(str(ins["rug"])).darkened(0.25))
		"oven":
			_r(img, cw / 2 - 14, 4, 28, 14, _col("stone"))
			_r(img, cw / 2 - 9, 8, 18, 9, Color.html(str(ins["ember"])))
			_r(img, cw / 2 - 6, 11, 12, 5, Color.html(str(ins["fire"][0])))
		"stalls":
			for x in range(8, cw - 20, 22):
				_r(img, x, 6, 18, 10, wood)
				_r(img, x + 2, 8, 14, 6, _col("crate"))
				_dot(img, x + 5, 10, _col("flag"))
				_dot(img, x + 11, 11, _col("gold"))
		"hooks":
			_r(img, 8, 5, cw - 16, 2, _col("iron"))
			for x in range(12, cw - 12, 9):
				_r(img, x, 7, 3, 8, Color.html("#b0504a"))
		"cauldron":
			_r(img, cw - 36, 6, 22, 14, _col("iron"))
			_r(img, cw - 34, 8, 18, 4, Color.html(str(ins["fire"][0])).darkened(0.2))
			_r(img, cw - 30, 20, 10, 3, Color.html(str(ins["ember"])))
		"workbench":
			_r(img, 8, my + 2, cw - 16, 9, wood)
			_r(img, 8, my + 2, cw - 16, 2, wood.lightened(0.3))
			for x in range(14, cw - 14, 14):
				_r(img, x, my + 4, 5, 2, _col("iron"))
		"loom":
			_r(img, 10, 6, 26, 18, wood)
			for x in range(13, 34, 3):
				_r(img, x, 8, 1, 14, cloth)
			_r(img, 10, 6, 26, 2, wood.darkened(0.2))
		"bookcases":
			_r(img, 6, 4, cw - 12, 10, wood.darkened(0.15))
			for x in range(8, cw - 10, 4):
				_r(img, x, 5, 3, 8, [Color.html("#a84a4a"), Color.html("#4a6aa8"), Color.html("#4a8a5a"), Color.html("#c0a04a")][(x / 4) % 4])
		"display":
			_r(img, 10, my - 4, cw - 20, 10, wood)
			_r(img, 12, my - 3, cw - 24, 6, _col("glass"))
			for x in range(16, cw - 18, 9):
				_dot(img, x, my, _col("flag") if (x / 9) % 2 == 0 else _col("lamp"))
		"tubs":
			for x in [14, cw - 40]:
				_r(img, x, 6, 26, 16, wood.darkened(0.1))
				_r(img, x + 2, 8, 22, 12, _col("glass"))
		"hay":
			_r(img, 8, ch - 22, 22, 14, Color.html("#c8a850"))
			_r(img, cw - 30, ch - 22, 22, 14, Color.html("#c8a850"))
			_r(img, 12, ch - 20, 14, 2, Color.html("#e0c870"))
		"desk":
			_r(img, mx - 14, 6, 28, 10, wood)
			_r(img, mx - 14, 6, 28, 2, wood.lightened(0.3))
			_r(img, mx - 6, 9, 8, 5, _col("paper"))
			_dot(img, mx + 6, 10, _col("iron"))
		"mapboard":
			_r(img, mx - 18, my - 8, 36, 18, wood)
			_r(img, mx - 16, my - 6, 32, 14, _col("paper"))
			_r(img, mx - 10, my - 2, 12, 2, _col("glass_dark"))
			_dot(img, mx + 6, my + 3, _col("flag"))
		"kiln":
			_r(img, cw - 38, 4, 26, 18, _col("stone"))
			_r(img, cw - 32, 10, 14, 8, Color.html(str(ins["ember"])))
			_r(img, cw - 29, 12, 8, 4, Color.html(str(ins["fire"][1])))
		"vault":
			_r(img, cw - 36, 4, 26, 18, _col("iron"))
			_r(img, cw - 32, 7, 18, 12, _col("stone_dark"))
			_dot(img, cw - 23, 13, _col("gold"))
		"armour_stand":
			for x in [10, cw - 22]:
				_r(img, x, 6, 12, 16, _col("iron"))
				_r(img, x + 3, 3, 6, 4, _col("stone"))
				_r(img, x + 2, 22, 8, 3, wood)
		"millstone":
			_r(img, mx - 14, my - 10, 28, 20, _col("stone"))
			_r(img, mx - 10, my - 6, 20, 12, _col("stone_dark"))
			_r(img, mx - 2, my - 2, 4, 4, wood)
		"sacks":
			for x in range(8, cw - 20, 14):
				_r(img, x, ch - 22, 11, 12, cloth.darkened(0.15))
				_r(img, x + 2, ch - 24, 7, 3, cloth.darkened(0.3))
		"pelts":
			for x in range(10, cw - 16, 14):
				_r(img, x, 5, 9, 14, Color.html("#8a6a4a"))
				_r(img, x + 2, 7, 5, 8, Color.html("#a8845a"))
		"chair":
			_r(img, mx - 6, my - 6, 12, 14, wood.darkened(0.25))
			_r(img, mx - 5, my - 5, 10, 8, Color.html("#8a3a3a"))
		"benches":
			for y in [my - 6, my + 8]:
				_r(img, 14, y, cw - 28, 4, wood)
		"slab":
			_r(img, mx - 16, my - 8, 32, 14, _col("stone"))
			_r(img, mx - 16, my - 8, 32, 2, _col("white"))
			_r(img, mx - 4, my - 2, 8, 6, _col("stone_dark"))
		"barrels":
			for x in range(10, cw - 18, 14):
				_r(img, x, 6, 10, 12, _col("barrel"))
				_r(img, x, 9, 10, 1, _col("hoop"))
				_r(img, x, 14, 10, 1, _col("hoop"))
		"lamp_floor":
			_r(img, mx - 8, 6, 16, 8, _col("lamp"))
			_r(img, mx - 4, 8, 8, 4, _col("lamp").lightened(0.4))


## The same outline as the building's, drawn inside the picture's edge, so a roofless building is as clear against the ground.
static func _outline_box(img: Image) -> Image:
	var line := Color.html(str(data()["outline"]))
	var w := img.get_width()
	var h := img.get_height()
	for x in w:
		img.set_pixel(x, 0, line)
		img.set_pixel(x, h - 1, line)
	for y in h:
		img.set_pixel(0, y, line)
		img.set_pixel(w - 1, y, line)
	return img


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
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and img.get_pixel(nx, ny).a > 0.0:
					out.set_pixel(x, y, line)
					break
	return out


static func _r(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var box := Rect2i(x, y, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if box.size.x > 0 and box.size.y > 0:
		img.fill_rect(box, c)


static func _dot(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["outline", "colors", "styles", "kinds", "door"]:
		if not dat.has(k):
			bad.append("buildings.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var dd: Dictionary = dat["door"]
	if float(dd.get("headroom", 0.0)) < 1.0 or float(dd.get("headroom", 0.0)) > 1.5 or int(dd.get("width", 0)) < 8 or int(dd.get("width", 0)) > TILE or int(dd.get("min_roof", 0)) < 6 or int(dd.get("above", -1)) < 2:
		bad.append("buildings.json: door needs headroom 1 to 1.5 (of a person's height), width 8 to a tile, min_roof 6 or more and above 2 or more")
	if not Color.html_is_valid(str(dat["outline"])):
		bad.append("buildings.json: outline is not a colour")
	var needed := ["door", "door_dark", "glass", "glass_dark", "shutter", "gold", "flag", "stone", "stone_dark", "glow", "iron", "crate", "crate_dark", "sign", "mug", "wood", "wood_dark", "paper", "paper2", "lamp", "white", "barrel", "hoop", "stripe_red", "stripe_blue"]
	for k in needed:
		if not dat["colors"].has(k) or not Color.html_is_valid(str(dat["colors"][k])):
			bad.append("buildings.json: colors.%s is missing or not a colour" % k)
	for s in dat["styles"]:
		for part in ["roof", "wall"]:
			if not s.has(part) or typeof(s[part]) != TYPE_ARRAY or s[part].size() != 2 or not Color.html_is_valid(str(s[part][0])) or not Color.html_is_valid(str(s[part][1])):
				bad.append("buildings.json: a style needs a roof and a wall of two colours")
	var furniture := ["bed", "table", "hearth", "chest", "anvil_floor", "forge_fire", "rack", "altar", "pews", "counter", "shelves", "crates", "bar", "tables", "rug", "lamp_floor",
			"oven", "stalls", "hooks", "cauldron", "workbench", "loom", "bookcases", "display", "tubs", "hay", "desk", "mapboard", "kiln", "vault", "armour_stand", "millstone", "sacks", "pelts", "chair", "benches", "slab", "barrels"]
	var ins: Dictionary = dat.get("inside", {})
	for k in ["floor", "wall", "rug", "cloth", "blanket", "wood", "fire", "ember"]:
		if not ins.has(k):
			bad.append("buildings.json: inside.%s is missing" % k)
	var features := ["chimney", "glow", "anvil", "cross", "round_window", "awning", "crate", "sign", "banner", "gold_trim", "lantern", "sign_icon", "barrels", "sails", "pole"]
	for kind in dat["kinds"]:
		var def: Dictionary = dat["kinds"][kind]
		if str(def.get("shape", "")) == "board":
			continue
		if not bool(def.get("styled", false)):
			for part in ["roof", "wall"]:
				if not def.has(part) or typeof(def[part]) != TYPE_ARRAY or def[part].size() != 2 or not Color.html_is_valid(str(def[part][0])) or not Color.html_is_valid(str(def[part][1])):
					bad.append("buildings.json: '%s' needs a roof and a wall of two colours (or to be styled)" % kind)
		if def.get("furniture", []).is_empty():
			bad.append("buildings.json: '%s' has no furniture for its inside" % kind)
		for f in def.get("furniture", []):
			if not furniture.has(str(f)):
				bad.append("buildings.json: '%s' has the unknown furniture '%s'" % [kind, f])
		if def.get("features", []).has("sign_icon"):
			var rows: Array = dat.get("icons", {}).get(str(def.get("icon", "")), [])
			var okrows := rows.size() == 8
			for rw in rows:
				okrows = okrows and str(rw).length() == 8
			if not okrows or not Color.html_is_valid(str(def.get("icon_color", ""))):
				bad.append("buildings.json: '%s' needs an `icon` of 8 rows of 8 in `icons` and an `icon_color`" % kind)
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
	if px != TILE:
		bad.append("buildings.json: a tile is %d pixels in sandbox.json but BuildingArt.TILE is %d" % [px, TILE])
	return bad
