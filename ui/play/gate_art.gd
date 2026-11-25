## The waygates of the Old Roads, painted as pixel art (rendering only; data/art/gates.json says what they look like, GameGates where they stand and
## what state they are in). An arch is 3 tiles wide and 4 tall (48 by 64 pixels) with the passage tile at the bottom middle: two legs on plinths
## under a ring of old stone with a rune cut for each slot along it. Each rune shows its slot's state: silver when whole (gold-lit when the gate is
## lit), dim when worn, chipped when broken, an empty groove when the silver is stripped. A lit arch has a shimmer in its opening and a flickering one
## a thin, broken one; a ruined arch is cracked and mossy, a gap in its ring and rubble at its feet; one that stands in the wilds beside ruins has
## fallen stones. Light comes from the top left, the outline is 1 pixel, nothing is anti-aliased. Made once for each look and kept; nothing is random
## (the cracks and moss follow a hash of the gate's id), and the glow it gives at night is the glow layer's (WorldLook.glow_sources asks).
class_name GateArt
extends RefCounted

const PATH := "res://data/art/gates.json"
const TILE := 16
const W := 48
const H := 64
const CX := 24.0
const CY := 30.0

static var _data: Dictionary = {}
static var _tex: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = GameData.load_json(PATH)
	return _data


static func _col(key: String) -> Color:
	return Color.html(str(data()["colors"][key]))


static func _mix(a: int, b: int, c: int = 0, e: int = 0) -> int:
	return GroundArt.mix(a, b, c, e)


## How ruined a set of slot states is, 0 (every slot whole) to 1 (every slot gone).
static func ruin_of(states: Array) -> float:
	if states.is_empty():
		return 0.0
	var s := 0.0
	for st in states:
		match str(st):
			"worn":
				s += 0.4
			"broken":
				s += 0.9
			"stripped":
				s += 1.0
	return s / float(states.size())


## The pixels of one look: `mode` "lit", "flickering" or "dark"; `states` and `runes` one for each slot; `ruins` for a gate among fallen stones; `variant` a
## number from the gate's id for the cracks.
static func image(mode: String, states: Array, runes: Array, ruins: bool, variant: int) -> Image:
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var ruin := ruin_of(states)
	var mask := PackedByteArray()
	mask.resize(W * H)
	# the stone: a ring over two legs on plinths
	for y in H:
		for x in W:
			var d := Vector2(float(x) + 0.5 - CX, float(y) + 0.5 - CY).length()
			var on := false
			if y <= 30:
				on = d >= 13.0 and d <= 21.5
			elif y <= 58:
				on = (x >= 3 and x <= 11) or (x >= 37 and x <= 45)
			elif y <= 62:
				on = (x >= 1 and x <= 13) or (x >= 35 and x <= 47)
			mask[y * W + x] = 1 if on else 0
	if ruin >= 0.5:   # a chunk of the ring has fallen
		var centre := 215.0 + float(_mix(variant, 7) % 110)
		var half := 7.0 + 14.0 * (ruin - 0.5) * 2.0
		for y in range(0, 31):
			for x in W:
				var a := rad_to_deg(atan2(float(y) + 0.5 - CY, float(x) + 0.5 - CX))
				a = fposmod(a, 360.0)
				if mask[y * W + x] == 1 and absf(a - centre) <= half:
					mask[y * W + x] = 0
		# a stub is left either side so the gap reads as broken stone, not as a smaller arch
	if ruins or ruin >= 0.35:   # fallen stones at the feet
		for p in [[13, 61, 4, 2], [33, 60, 4, 3], [15, 62, 2, 1]]:
			for y in range(int(p[1]), int(p[1]) + int(p[3])):
				for x in range(int(p[0]), int(p[0]) + int(p[2])):
					mask[y * W + x] = 1
	_mask_clean(mask)
	# the stone's shading: light from the top left, mortar in courses, a speckle of lighter and darker
	var stone := _col("stone")
	for y in H:
		for x in W:
			if mask[y * W + x] == 0:
				continue
			var c := stone
			var h := _mix(x, y, variant) % 29
			if h == 0:
				c = _col("stone_lo")
			elif h == 1:
				c = _col("stone_hi")
			if _course_line(x, y):
				c = _col("mortar")
			if _at(mask, x - 1, y) == 0 or _at(mask, x, y - 1) == 0:
				c = _col("stone_hi")
			if _at(mask, x + 1, y) == 0 or _at(mask, x, y + 1) == 0:
				c = _col("stone_lo")
			img.set_pixel(x, y, c)
	# cracks: short runs of dark, more the more ruined
	var cracks := int(ceil(ruin * 6.0))
	for k in cracks:
		var px := 4 + _mix(variant, k, 1) % (W - 8)
		var py := 10 + _mix(variant, k, 2) % (H - 14)
		for s in 8:
			if _at(mask, px, py) == 1:
				img.set_pixel(px, py, _col("stone_dk"))
			px += (_mix(variant, k, s + 10) % 3) - 1
			py += 1
	# moss on what faces up, more the more ruined
	var moss_p := ruin * 0.85 + (0.12 if ruins else 0.0)
	for y in H:
		for x in W:
			if mask[y * W + x] == 1 and _at(mask, x, y - 1) == 0 and float(_mix(x, y, variant, 5) % 100) / 100.0 < moss_p:
				img.set_pixel(x, y, _col("moss"))
				if _at(mask, x, y + 1) == 1 and (_mix(x, y, variant, 6) & 1) == 0:
					img.set_pixel(x, y + 1, _col("moss_dk"))
	# the runes, one for each slot, along the ring
	var n := states.size()
	var glyphs: Array = data()["glyphs"]
	for i in n:
		var a := PI + (float(i) + 0.5) / float(n) * PI
		var gx := int(round(CX + 17.25 * cos(a)))
		var gy := int(round(CY + 17.25 * sin(a)))
		var rows: Array = glyphs[_mix(str(runes[i]).hash(), 3) % glyphs.size()]
		for ry in 7:
			for rx in 5:
				var px2 := gx - 2 + rx
				var py2 := gy - 3 + ry
				if px2 < 0 or py2 < 0 or px2 >= W or py2 >= H or _at(mask, px2, py2) == 0:
					continue
				var inside := rx >= 1 and rx <= 3 and ry >= 1 and ry <= 5
				var on := inside and str(rows[ry - 1]).substr(rx - 1, 1) == "1"
				img.set_pixel(px2, py2, _rune_color(str(states[i]), mode, on, px2, py2, variant))
	# the outline, and the shimmer in the opening
	var out_c := _col("outline")
	var edge := PackedByteArray()
	edge.resize(W * H)
	for y in H:
		for x in W:
			if mask[y * W + x] == 0 and (_at(mask, x - 1, y) == 1 or _at(mask, x + 1, y) == 1 or _at(mask, x, y - 1) == 1 or _at(mask, x, y + 1) == 1):
				img.set_pixel(x, y, out_c)
				edge[y * W + x] = 1
	var alpha := float(data()["shimmer_alpha"].get(mode, 0.0))
	if alpha > 0.0:
		var sh := _col("shimmer")
		for y in range(12, 59):
			for x in range(11, 38):
				if mask[y * W + x] == 1 or edge[y * W + x] == 1:
					continue
				var d2 := Vector2(float(x) + 0.5 - CX, float(y) + 0.5 - CY).length()
				if y <= 30 and d2 >= 13.0:
					continue
				if x < 12 or x > 36:
					continue
				if mode == "flickering" and ((y + variant) % 3) == 0:   # thin, broken bands of light
					continue
				var fade := 0.55 + 0.45 * (1.0 - float(y - 12) / 46.0)
				img.set_pixel(x, y, Color(sh.r, sh.g, sh.b, alpha * fade))
	return img


static func _at(mask: PackedByteArray, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= W or y >= H:
		return 0
	return mask[y * W + x]


## Whether a stone pixel is on a joint between courses: rows every 8 on the legs, spokes every 15 degrees on the ring.
static func _course_line(x: int, y: int) -> bool:
	if y > 30:
		return (y % 8) == 5
	var a := fposmod(rad_to_deg(atan2(float(y) + 0.5 - CY, float(x) + 0.5 - CX)), 360.0)
	return fposmod(a, 15.0) < 1.6


## Removes stray stone pixels (any with no stone to its side or above or below).
static func _mask_clean(mask: PackedByteArray) -> void:
	for y in H:
		for x in W:
			if mask[y * W + x] == 1 and _at(mask, x - 1, y) == 0 and _at(mask, x + 1, y) == 0 and _at(mask, x, y - 1) == 0 and _at(mask, x, y + 1) == 0:
				mask[y * W + x] = 0


## The colour of one pixel of a rune's 5 by 7 patch: the groove, with the silver in it (when it is there).
static func _rune_color(state: String, mode: String, glyph: bool, x: int, y: int, variant: int) -> Color:
	var groove := _col("groove")
	if not glyph:
		return groove
	match state:
		"whole":
			return _col("rune_lit") if mode == "lit" else (_col("rune_flick") if mode == "flickering" else _col("silver"))
		"worn":
			if mode == "flickering" and ((x + y) % 2) == 0:
				return _col("rune_flick")
			return _col("silver_dim")
		"broken":
			return _col("silver_dim") if (_mix(x, y, variant, 9) % 3) == 0 else groove
		_:
			return _col("stone_dk")


## The texture of one look, made once.
static func texture(mode: String, states: Array, runes: Array, ruins: bool, variant: int) -> Texture2D:
	var key := "%s|%s|%s|%d|%d" % [mode, ",".join(PackedStringArray(states.map(func(s): return str(s).substr(0, 1)))), ",".join(PackedStringArray(runes.map(func(r): return str(r)))), 1 if ruins else 0, variant]
	if not _tex.has(key):
		_tex[key] = ImageTexture.create_from_image(image(mode, states, runes, ruins, variant))
	return _tex[key]


## The texture of a gate as it is now.
static func texture_of(d: GameDynasty, id: String) -> Texture2D:
	var st := GameGates.state(d, id)
	var states: Array = (st["slots"] as Array).map(func(s): return str(s["state"]))
	var runes: Array = (st["slots"] as Array).map(func(s): return str(s["rune"]))
	return texture(str(st["mode"]), states, runes, bool(GameGates.def(id).get("ruins", false)), id.hash() & 0xffff)


## The rect (in tiles) a gate's picture covers: 3 wide and 4 tall, the passage tile at the bottom middle.
static func rect_of(d: GameDynasty, id: String) -> Rect2i:
	var t := GameGates.tile_of(d, id)
	return Rect2i(t.x - 1, t.y - 3, int(data()["w"]), int(data()["h"]))


## The gates whose picture shows in a rect of tiles: [{id, rect}].
static func in_view(d: GameDynasty, view: Rect2i) -> Array:
	var out: Array = []
	for id in GameGates.all(d):
		var r := rect_of(d, id)
		if r.intersects(view):
			out.append({"id": id, "rect": r})
	return out


## What the glow layer draws at night for the gates in a rect: [{pos, spec}] for a lit or flickering arch.
static func glow_sources(d: GameDynasty, view: Rect2i) -> Array:
	var out: Array = []
	for g in in_view(d, view):
		var mode := str(GameGates.state(d, str(g["id"]))["mode"])
		var spec: Variant = data()["glow"].get(mode, null)
		if spec == null:
			continue
		var r: Rect2i = g["rect"]
		out.append({"pos": Vector2(float(r.position.x) + float(spec["at"][0]) * float(r.size.x), float(r.position.y) + float(spec["at"][1]) * float(r.size.y)), "spec": spec})
	return out


## The colour a gate of a mode is marked with on the maps.
static func icon_color(mode: String) -> Color:
	var c: Array = data()["icon"].get(mode, [0.5, 0.5, 0.56])
	return Color(float(c[0]), float(c[1]), float(c[2]))


## A small picture of one rune in a slot's state (7 by 9 pixels, to be shown at a whole multiple): the groove with the silver in it.
static func rune_texture(rune: String, state: String, lit: bool) -> Texture2D:
	var key := "rune|%s|%s|%d" % [rune, state, 1 if lit else 0]
	if _tex.has(key):
		return _tex[key]
	var img := Image.create_empty(7, 9, false, Image.FORMAT_RGBA8)
	var rows: Array = data()["glyphs"][_mix(rune.hash(), 3) % (data()["glyphs"] as Array).size()]
	for y in 9:
		for x in 7:
			var gx := x - 1
			var gy := y - 1
			var inner := x >= 1 and x <= 5 and y >= 1 and y <= 7
			var inside := gx >= 1 and gx <= 3 and gy >= 1 and gy <= 5
			if not inner:
				img.set_pixel(x, y, _col("outline"))
				continue
			var on := inside and str(rows[gy - 1]).substr(gx - 1, 1) == "1"
			img.set_pixel(x, y, _rune_color(state, "lit" if lit else "dark", on, x, y, 1))
	_tex[key] = ImageTexture.create_from_image(img)
	return _tex[key]


## Paints a realm's arrival ground over the interior's plain floor: each cell in the realm's own colours (the palette of its mark), a ripple of the lighter tone,
## the return gate standing over the way in. `cells` is GameGates.arrival_cells; `origin`, `area`, `centre` and `cell` are the screen's, as for the interior.
static func paint_arrival(c: Control, realm: String, cells: Dictionary, origin: Vector2, area: Vector2, centre: Vector2, cell: float, tint: Color = Color.WHITE) -> void:
	var lk := GameGates.look(realm)
	if lk.is_empty():
		return
	var half := area / (2.0 * cell) + Vector2(2, 2)
	for k in cells:
		var p := GameInterior._parse(str(k))
		if absf(float(p.x) + 0.5 - centre.x) > half.x or absf(float(p.y) + 0.5 - centre.y) > half.y:
			continue
		var at := origin + (Vector2(p) - centre) * cell + area * 0.5
		var rect := Rect2(at, Vector2(cell, cell))
		if str(cells[k]) == "wall":
			c.draw_rect(rect, lk["wall"] * tint)
			c.draw_rect(Rect2(at, Vector2(cell, maxf(1.0, cell * 0.18))), (lk["wall"] as Color).lightened(0.25) * tint)
		else:
			var h := _mix(p.x, p.y, realm.hash() & 0xffff)
			var col: Color = lk["floor2"] if (h % 5) == 0 else lk["floor"]
			c.draw_rect(rect, col * tint)
			if str(cells[k]) == "exit":
				c.draw_rect(rect, Color(lk["glow"].r, lk["glow"].g, lk["glow"].b, 0.35) * tint)
			elif (h % 11) == 1:
				var dot := Rect2(at + Vector2(cell * 0.4, cell * 0.4), Vector2(maxf(1.0, cell * 0.12), maxf(1.0, cell * 0.12)))
				c.draw_rect(dot, (lk["glow"] as Color) * Color(1, 1, 1, 0.55) * tint)
	var states := ["whole", "whole", "whole", "whole", "whole"]
	var runes := ["door", "return", "light", "road", "deep"]
	var arch := texture("lit", states, runes, false, realm.hash() & 0xffff)
	var top := origin + (Vector2(-1, -3) - centre) * cell + area * 0.5
	c.draw_texture_rect(arch, Rect2(top, Vector2(3, 4) * cell), false, tint)


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["w", "h", "colors", "shimmer_alpha", "glow", "glyphs", "icon"]:
		if not dat.has(k):
			bad.append("art/gates.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	if int(dat["w"]) * TILE != W or int(dat["h"]) * TILE != H:
		bad.append("art/gates.json: a gate is %d by %d tiles, but the art is made for 3 by 4" % [int(dat["w"]), int(dat["h"])])
	for k in ["outline", "stone_hi", "stone", "stone_lo", "stone_dk", "mortar", "moss", "moss_dk", "groove", "silver", "silver_dim", "rune_lit", "rune_flick", "shimmer"]:
		if not dat["colors"].has(k) or not str(dat["colors"][k]).is_valid_html_color():
			bad.append("art/gates.json: colors.%s is no colour" % k)
	for g in dat["glyphs"]:
		if (g as Array).size() != 5:
			bad.append("art/gates.json: a rune glyph must have 5 rows")
			continue
		for row in g:
			if str(row).length() != 3:
				bad.append("art/gates.json: a rune glyph row must be 3 wide")
	if not bad.is_empty():
		return bad
	var states := ["whole", "worn", "broken", "stripped", "whole", "worn"]
	var runes := ["road", "door", "light", "bind", "ward", "deep"]
	for mode in ["lit", "flickering", "dark"]:
		for ruins in [false, true]:
			for look in [["whole", "whole", "whole", "whole", "whole", "whole"], states, ["stripped", "broken", "stripped", "broken", "stripped", "stripped"]]:
				var img := image(mode, look, runes, ruins, 77)
				var solid := 0
				var stray := 0
				var colours := {}
				var outline := 0
				var edge := 0
				for y in H:
					for x in W:
						var c := img.get_pixel(x, y)
						if c.a <= 0.0:
							continue
						solid += 1
						if c.a >= 1.0:
							colours[c.to_html()] = true
						var nb := 0
						for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
							var q: Vector2i = Vector2i(x, y) + o
							if q.x >= 0 and q.y >= 0 and q.x < W and q.y < H and img.get_pixel(q.x, q.y).a > 0.0:
								nb += 1
						if nb == 0:
							stray += 1
						if c.is_equal_approx(_col("outline")):
							outline += 1
				if solid < 700:
					bad.append("art/gates.json: the %s gate is mostly clear" % mode)
				if stray > 0:
					bad.append("art/gates.json: the %s gate has %d stray pixels" % [mode, stray])
				if colours.size() > 20:
					bad.append("art/gates.json: the %s gate uses %d colours (20 at most)" % [mode, colours.size()])
				if outline < 120:
					bad.append("art/gates.json: the %s gate has little outline" % mode)
				var mid_px := 0   # the passage tile (bottom middle) must be open to walk through: nothing solid at its top
				for y in range(H - TILE, H - 4):
					for x in range(TILE + 3, TILE * 2 - 3):
						if img.get_pixel(x, y).a >= 1.0:
							mid_px += 1
				if mid_px > 12:
					bad.append("art/gates.json: the %s gate is blocked in the passage" % mode)
	return bad
