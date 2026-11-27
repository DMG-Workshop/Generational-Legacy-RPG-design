## What the roadside looks like over the open world, drawn by the sandbox screen like the villagers are: the caravans' wagons and traders, the camp's
## tent and fire, and the name tag of a signpost the heir has come near (data/world/roads.json, data/world/camp.json). Rendering only: it reads
## GameRoads, GameCaravans and GameCamp and changes nothing. The wagon, tent and fire are the wilds' own 8 by 8 glyphs (wilds.json), made into
## textures here; movement (the trader's stride, the fire's flicker) takes its time from WorldLook.clock(), which stands still with reduced motion.
class_name RoadsideArt
extends RefCounted

const Kit := preload("res://ui/play/ui_kit.gd")

static var _textures: Dictionary = {}


## A glyph (wilds or roads) as a texture, made once.
static func glyph_texture(id: String) -> Texture2D:
	if _textures.has(id):
		return _textures[id]
	var g: Dictionary = TileView.all_glyphs().get(id, {})
	if g.is_empty():
		return null
	var px := 16
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	TileView._paint_glyph(img, 0, px, g)
	var tex := ImageTexture.create_from_image(img)
	_textures[id] = tex
	return tex


static func _at(origin: Vector2, area: Vector2, centre: Vector2, cell: float, p: Vector2) -> Vector2:
	return origin + (p - centre) * cell + area * 0.5


## The caravan's wagon and the trader walking ahead of it, its feet at the road's point.
static func paint_caravan(c: Control, st: Dictionary, origin: Vector2, area: Vector2, centre: Vector2, cell: float, dim: Color) -> void:
	var feet := _at(origin, area, centre, cell, Vector2(float(st["x"]), float(st["z"]))) + Vector2(0, cell * 0.3)
	var tex := glyph_texture("wagon")
	var dir := float(st.get("dx", 0))
	var t := WorldLook.clock()
	var bob := absf(sin(t * 6.0 + float(int(st["index"])))) * cell * 0.04
	c.draw_set_transform(feet, 0.0, Vector2(1.0, 0.4))
	c.draw_circle(Vector2.ZERO, cell * 0.8, Color(0, 0, 0, 0.3))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if tex != null:
		var box := Vector2(cell * 1.6, cell * 1.6)
		var at := feet - Vector2(box.x * 0.5, box.y * 0.92 + bob)
		if dir < 0.0:
			c.draw_set_transform(at + Vector2(box.x, 0.0), 0.0, Vector2(-1.0, 1.0))
			c.draw_texture_rect(tex, Rect2(Vector2.ZERO, box), false, dim)
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			c.draw_texture_rect(tex, Rect2(at, box), false, dim)
	var lead := feet + Vector2(cell * 1.15 * (1.0 if dir >= 0.0 else -1.0), 0.0)
	var stride := sin(t * 7.0 + float(int(st["index"]))) * cell * 0.04
	var coat := Color(0.55, 0.3, 0.22) * dim
	var skin := Color(0.88, 0.7, 0.55) * dim
	c.draw_rect(Rect2(lead + Vector2(-cell * 0.12, -cell * 0.5 - absf(stride)), Vector2(cell * 0.24, cell * 0.36)), coat)
	c.draw_circle(lead + Vector2(0, -cell * 0.6 - absf(stride)), cell * 0.1, skin)
	c.draw_rect(Rect2(lead + Vector2(-cell * 0.16, -cell * 0.74 - absf(stride)), Vector2(cell * 0.32, cell * 0.07)), Color(0.35, 0.25, 0.15) * dim)
	c.draw_line(lead + Vector2(stride, -cell * 0.14), lead + Vector2(stride, 0), Color(0.2, 0.15, 0.1) * dim, maxf(1.5, cell * 0.06))


## The camp's tent (to the north-west of the fire) and the fire itself, which flickers.
static func paint_camp(c: Control, sb: GameSandbox, origin: Vector2, area: Vector2, centre: Vector2, cell: float, dim: Color) -> void:
	var p := GameCamp.point(sb)
	var fire := _at(origin, area, centre, cell, p) + Vector2(0, cell * 0.35)
	var tent := glyph_texture("tent_green")
	if tent != null:
		var tb := Vector2(cell * 1.5, cell * 1.5)
		c.draw_texture_rect(tent, Rect2(fire + Vector2(-cell * 1.35, -tb.y * 0.95), tb), false, dim)
	var flame := glyph_texture("campfire")
	if flame != null:
		var flick := 1.0 + sin(WorldLook.clock() * 9.0) * 0.06
		var fb := Vector2(cell * 0.9, cell * 0.9) * flick
		c.draw_texture_rect(flame, Rect2(fire - Vector2(fb.x * 0.5, fb.y * 0.9), fb), false)


## The sources of light a camp gives at night (WorldLook.glow_sources' shape).
static func glow_sources(sb: GameSandbox) -> Array:
	if sb == null or not GameCamp.active(sb):
		return []
	return [{"pos": GameCamp.point(sb), "spec": GroundArt.light_data()["glow"]["glyphs"]["campfire"]}]


## The tags of the signposts within `tag_range` tiles of the heir: the places they name and how far, over the post, fading in as the heir comes near.
static func paint_tags(c: Control, d: GameDynasty, heir: Vector2, origin: Vector2, area: Vector2, centre: Vector2, cell: float, zoom: float) -> void:
	var reach := GameRoads.setting("tag_range")
	var view := Rect2i(floori(heir.x - reach), floori(heir.y - reach), ceili(reach * 2.0) + 1, ceili(reach * 2.0) + 1)
	var font := ThemeDB.fallback_font
	var fs := clampi(int(round(12.0 * maxf(zoom, 0.8))), 10, 16)
	for p in GameRoads.posts_in(d, view):
		var pos := Vector2(float(p["x"]) + 0.5, float(p["z"]) + 0.5)
		var dist := pos.distance_to(heir)
		if dist > reach:
			continue
		var alpha := clampf((reach - dist) / (reach * 0.35), 0.0, 1.0)
		var lines := GameRoads.line_texts(p, true)
		var title := str(p["here"]) if str(p["kind"]) != "cross" else GameRoads.text("sign_name")
		var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var h := font.get_string_size("Ag", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).y
		for l in lines:
			width = maxf(width, font.get_string_size(str(l), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		var top := _at(origin, area, centre, cell, pos) + Vector2(0, -cell * 0.55)
		var box := Rect2(top + Vector2(-width * 0.5 - 5.0, -h * float(lines.size() + 1) - 6.0), Vector2(width + 10.0, h * float(lines.size() + 1) + 4.0))
		c.draw_rect(box, Color(0.05, 0.04, 0.08, 0.78 * alpha))
		c.draw_string(font, box.position + Vector2(5.0, h - 1.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Kit.ACCENT.r, Kit.ACCENT.g, Kit.ACCENT.b, alpha))
		for i in lines.size():
			c.draw_string(font, box.position + Vector2(5.0, h * float(i + 2) - 1.0), str(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.92, 0.9, 0.96, alpha))
