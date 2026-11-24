## Pixel art made in code for the art-direction mock-up (tools/mockup.gd, docs/ART_DIRECTION.md). Throwaway: not part of the game.
extends RefCounted

const S := 2   # screen pixels to a pixel of the interface's own art

# the palette (docs/ART_DIRECTION.md)
const INK := Color("#2a1c14")
const BROWN := Color("#6b4a2b")
const WOOD := Color("#5a3d24")
const WOOD_LO := Color("#46301c")
const WOOD_HI := Color("#74512f")
const PARCH := Color("#d9c597")
const PARCH_HI := Color("#ecdcb0")
const PARCH_LO := Color("#b99f6c")
const GOLD := Color("#e0b341")
const GOLD_DK := Color("#9a6f1c")
const CRIMSON := Color("#8e2f2f")
const CRIMSON_HI := Color("#b04545")
const CRIMSON_DK := Color("#5c1c1c")
const SLOT_BG := Color("#4b3b2b")
const SLOT_LO := Color("#8f7650")
const TRACK := Color("#4a3a2c")
const HP_C := [Color("#e0605a"), Color("#c8483f"), Color("#8e2a28")]
const MP_C := [Color("#7fb2ff"), Color("#4f86e0"), Color("#2c5299")]
const CARRY_C := [Color("#e0b341"), Color("#c49a2c"), Color("#8a6a1c")]


# ---------------------------------------------------------------- pixel art made in code (one logical pixel is S screen pixels)

static func _img(w: int, h: int, c: Color) -> Image:
	var i := Image.create(w, h, false, Image.FORMAT_RGBA8)
	i.fill(c)
	return i


static func _rect(i: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	i.fill_rect(Rect2i(x, y, w, h), c)


static func _ring(i: Image, inset: int, c: Color) -> void:
	var w := i.get_width()
	var h := i.get_height()
	_rect(i, inset, inset, w - inset * 2, 1, c)
	_rect(i, inset, h - 1 - inset, w - inset * 2, 1, c)
	_rect(i, inset, inset, 1, h - inset * 2, c)
	_rect(i, w - 1 - inset, inset, 1, h - inset * 2, c)


static var _memo := {}   # the textures made, kept: one made while drawing and let go is freed before the frame is shown, and draws white


static func _keep(k: String, t: ImageTexture) -> ImageTexture:
	_memo[k] = t
	return t


static func _tex(i: Image) -> ImageTexture:
	var big := i.duplicate() as Image
	big.resize(i.get_width() * S, i.get_height() * S, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(big)


## A panel: parchment with fibres, an inner bevel, a brown and an ink border and a gold stud in each corner.
static func panel_tex(w: int, h: int) -> ImageTexture:
	var k := "panel%d,%d" % [w, h]
	if _memo.has(k):
		return _memo[k]
	var lw := w / S
	var lh := h / S
	var i := _img(lw, lh, PARCH)
	var r := RandomNumberGenerator.new()
	r.seed = hash("panel%dx%d" % [w, h])
	for y in lh:
		for x in lw:
			var q := r.randf()
			if q < 0.05:
				i.set_pixel(x, y, PARCH_HI)
			elif q < 0.10:
				i.set_pixel(x, y, PARCH_LO)
	_rect(i, 2, 2, lw - 4, 1, PARCH_HI)
	_rect(i, 2, 2, 1, lh - 4, PARCH_HI)
	_rect(i, 2, lh - 3, lw - 4, 1, PARCH_LO)
	_rect(i, lw - 3, 2, 1, lh - 4, PARCH_LO)
	_ring(i, 1, BROWN)
	_ring(i, 0, INK)
	for p in [Vector2i(3, 3), Vector2i(lw - 8, 3), Vector2i(3, lh - 8), Vector2i(lw - 8, lh - 8)]:
		_rect(i, p.x, p.y, 5, 5, INK)
		_rect(i, p.x + 1, p.y + 1, 3, 3, GOLD)
		i.set_pixel(p.x + 3, p.y + 3, GOLD_DK)
	return _keep(k, _tex(i))


## A ribbon title: crimson with a lit top edge, a shaded bottom edge, an ink outline and gold stitching.
static func ribbon_tex(w: int, h: int) -> ImageTexture:
	var k := "ribbon%d,%d" % [w, h]
	if _memo.has(k):
		return _memo[k]
	var lw := w / S
	var lh := h / S
	var i := _img(lw, lh, CRIMSON)
	_rect(i, 1, 1, lw - 2, 1, CRIMSON_HI)
	_rect(i, 1, lh - 2, lw - 2, 1, CRIMSON_DK)
	for x in range(3, lw - 3, 2):
		i.set_pixel(x, 3, GOLD)
		i.set_pixel(x, lh - 4, GOLD)
	_ring(i, 0, INK)
	return _keep(k, _tex(i))


## A segmented bar: an ink frame, a dark track and a fill with a lit top and a shaded bottom, ticked every few pixels.
static func bar_tex(w: int, h: int, frac: float, c: Array) -> ImageTexture:
	var k := "bar%d,%d,%d,%s" % [w, h, int(frac * 100.0), (c[1] as Color).to_html()]
	if _memo.has(k):
		return _memo[k]
	var lw := w / S
	var lh := h / S
	var i := _img(lw, lh, INK)
	_rect(i, 1, 1, lw - 2, lh - 2, TRACK)
	var fw := int(float(lw - 4) * clampf(frac, 0.0, 1.0))
	if fw > 0:
		_rect(i, 2, 2, fw, lh - 4, c[1])
		_rect(i, 2, 2, fw, 1, c[0])
		_rect(i, 2, lh - 3, fw, 1, c[2])
		for x in range(7, fw + 2, 6):
			_rect(i, x, 3, 1, lh - 6, c[2])
	return _keep(k, _tex(i))


## An inset box, as in an inventory: dark inside, a dark edge top and left, a light edge bottom and right.
static func inset_tex(w: int, h: int, lit: bool = false) -> ImageTexture:
	var k := "inset%d,%d,%s" % [w, h, lit]
	if _memo.has(k):
		return _memo[k]
	var lw := w / S
	var lh := h / S
	var i := _img(lw, lh, SLOT_BG)
	_rect(i, 0, 0, lw, 1, INK)
	_rect(i, 0, 0, 1, lh, INK)
	_rect(i, 0, lh - 1, lw, 1, SLOT_LO)
	_rect(i, lw - 1, 0, 1, lh, SLOT_LO)
	_rect(i, 1, 1, lw - 2, 1, WOOD_LO)
	_rect(i, 1, 1, 1, lh - 2, WOOD_LO)
	if lit:
		_ring(i, 0, GOLD)
		_ring(i, 1, GOLD_DK)
	return _keep(k, _tex(i))


static func slot_tex(n: int, lit: bool) -> ImageTexture:
	return inset_tex(n, n, lit)


## The header: wooden planks with seams and grain, an ink edge and a gold line under it.
static func header_tex(w: int, h: int) -> ImageTexture:
	var k := "header%d,%d" % [w, h]
	if _memo.has(k):
		return _memo[k]
	var lw := w / S
	var lh := h / S
	var i := _img(lw, lh, WOOD)
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for y in lh:
		for x in lw:
			var q := r.randf()
			if q < 0.07:
				i.set_pixel(x, y, WOOD_HI)
			elif q < 0.14:
				i.set_pixel(x, y, WOOD_LO)
	for x in range(0, lw, 36):
		_rect(i, x, 0, 1, lh, WOOD_LO)
	_rect(i, 0, 0, lw, 1, WOOD_HI)
	_rect(i, 0, lh - 3, lw, 1, GOLD_DK)
	_rect(i, 0, lh - 2, lw, 1, GOLD)
	_rect(i, 0, lh - 1, lw, 1, INK)
	return _keep(k, _tex(i))


static func glyph_tex(rows: Array) -> ImageTexture:
	var k := "glyph" + str(rows)
	if _memo.has(k):
		return _memo[k]
	var i := _img(8, 8, Color(0, 0, 0, 0))
	for y in mini(rows.size(), 8):
		for x in mini(str(rows[y]).length(), 8):
			if str(rows[y])[x] == "#":
				i.set_pixel(x, y, Color.WHITE)
	return _keep(k, ImageTexture.create_from_image(i))


const HEART := [".##.##..", "########", "########", "########", ".######.", "..####..", "...##...", "........"]
const GEM := ["...##...", "..####..", ".######.", "########", ".######.", "..####..", "...##...", "........"]
const POUCH := ["..####..", "...##...", ".######.", "########", "########", "########", ".######.", "........"]
const COIN := ["..####..", ".######.", "###..###", "##.##.##", "##.##.##", "###..###", ".######.", "..####.."]


## The vignette: clear in the middle, dark at the corners, smooth (drawn with its own filter).
static func vignette_tex() -> ImageTexture:
	var k := "vignette"
	if _memo.has(k):
		return _memo[k]
	var w := 64
	var h := 36
	var i := _img(w, h, Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var dx := (float(x) / float(w - 1) - 0.5) * 2.0
			var dy := (float(y) / float(h - 1) - 0.5) * 2.0
			var dist := sqrt(dx * dx * 0.8 + dy * dy)
			i.set_pixel(x, y, Color(0.06, 0.03, 0.0, clampf((dist - 0.55) * 0.75, 0.0, 0.55)))
	return _keep(k, ImageTexture.create_from_image(i))


