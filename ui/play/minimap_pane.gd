## The minimap pane (docs/PLAYER_INTERFACE.md, slice 3): the ground round the heir, a tile a pixel and scaled up, in the tile view's
## colours (GameMiniMap), with the heir, the creatures and the companions as dots. Indoors it says so. The sandbox screen calls
## `refresh` a few times a second; the ground is only made again when the heir has moved. Rendering only.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSkin := preload("res://ui/play/ui_skin.gd")

var dynasty: GameDynasty
var sb: GameSandbox
var radius := 20
var _image: TextureRect
var _dots: Control
var _note: Label
var _at := Vector2i(-99999, -99999)


class Dots extends Control:
	var pane: Control

	func _draw() -> void:
		var sb: GameSandbox = pane.sb
		if sb == null or sb.space != "world":
			return
		var n := float(pane.radius * 2 + 1)
		var cell := size / n
		var c: Dictionary = GameSandbox.data()["colors"]
		var centre := Vector2(sb.heir) + Vector2(0.5, 0.5)
		for g in GameMiniMap.gates(pane.dynasty, sb.heir.x, sb.heir.y, pane.radius):   # a waygate the family knows: a diamond in its state's colour
			var go := (Vector2(float(g["x"]) + 0.5, float(g["z"]) + 0.5) - centre) * cell + size * 0.5
			var gq := 4.0
			var gc := GateArt.icon_color(str(g["mode"]))
			draw_colored_polygon(PackedVector2Array([go + Vector2(0, -gq - 1), go + Vector2(gq + 1, 0), go + Vector2(0, gq + 1), go + Vector2(-gq - 1, 0)]), Color(0.05, 0.04, 0.08))
			draw_colored_polygon(PackedVector2Array([go + Vector2(0, -gq), go + Vector2(gq, 0), go + Vector2(0, gq), go + Vector2(-gq, 0)]), gc)
		for a in sb.creatures:
			_dot(Vector2(float(a["x"]), float(a["z"])), centre, cell, n, _rgb(c["creature"]), 2.0)
		for a in sb.companions:
			_dot(Vector2(float(a["x"]), float(a["z"])), centre, cell, n, _rgb(c["companion"]), 2.0)
		_dot(centre, centre, cell, n, _rgb(c["heir"]), 3.0)

	func _dot(p: Vector2, centre: Vector2, cell: Vector2, n: float, col: Color, r: float) -> void:
		var o := (p - centre) * cell + size * 0.5
		if o.x < 0.0 or o.y < 0.0 or o.x > size.x or o.y > size.y:
			return
		draw_circle(o, r + 1.0, Color(0.05, 0.04, 0.08))
		draw_circle(o, r, col)

	static func _rgb(a: Array) -> Color:
		return Color(float(a[0]), float(a[1]), float(a[2]))


func _ready() -> void:
	radius = int(GameSandbox.data()["view"].get("minimap_radius", 20))
	var v := Kit.overlay(self, "Nearby")
	_image = TextureRect.new()
	_image.custom_minimum_size = Vector2(200, 200)
	_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	v.add_child(_image)
	if UiSkin.in_skin(self):   # the picture is set in an ink and gold edge, inside the wooden frame
		_image.draw.connect(_edge)
	_dots = Dots.new()
	_dots.pane = self
	_dots.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.add_child(_dots)
	_note = Kit.label("", 13, Kit.dim())
	v.add_child(_note)
	refresh()


## The edge round the picture the ground is drawn in (the square the image is centred as).
func _edge() -> void:
	var side := minf(_image.size.x, _image.size.y)
	var r := Rect2((_image.size - Vector2(side, side)) * 0.5, Vector2(side, side))
	var w := float(UiSkin.pixel())
	_image.draw_rect(r.grow(w * 0.5), UiSkin.pal("gold_dk"), false, w)
	_image.draw_rect(r.grow(w * 1.5), UiSkin.pal("ink"), false, w)


## The ground as a picture, one pixel a tile, in the tile view's colours.
static func make_image(d: GameDynasty, cx: int, cz: int, r: int) -> Image:
	var colors: Dictionary = GameSandbox.data()["tiles"]["colors"]
	var standing: Dictionary = GameSandbox.data()["minimap"]   # what a town adds over the ground: its buildings, wall and gates
	var kinds := GameMiniMap.kinds(d, cx, cz, r)
	var n := r * 2 + 1
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for z in n:
		for x in n:
			var k := str(kinds[z][x])
			var c: Array = standing[k] if standing.has(k) else colors.get(k, colors.get("built", [0.5, 0.42, 0.3]))
			img.set_pixel(x, z, Color(float(c[0]), float(c[1]), float(c[2])))
	return img


func refresh() -> void:
	if sb == null:
		return
	if sb.space != "world":
		_image.texture = null
		_note.text = "Indoors."
		_dots.queue_redraw()
		return
	if sb.heir != _at:
		_at = sb.heir
		_image.texture = ImageTexture.create_from_image(make_image(dynasty, sb.heir.x, sb.heir.y, radius))
		_note.text = "%s" % sb.place_line() if sb.place_line() != "" else "Open ground."
	_dots.queue_redraw()
