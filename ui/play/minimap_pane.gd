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
var _pin_note: Label   # "Kingshold: 212 tiles NE" under the picture, while a pin is set
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
		for a in sb.creatures:
			_dot(Vector2(float(a["x"]), float(a["z"])), centre, cell, n, _rgb(c["creature"]), 2.0)
		for a in sb.companions:
			_dot(Vector2(float(a["x"]), float(a["z"])), centre, cell, n, _rgb(c["companion"]), 2.0)
		_dot(centre, centre, cell, n, _rgb(c["heir"]), 3.0)
		_pin(sb)

	## The map pin: a flag where it stands when it is in the picture, else an arrow at the picture's edge pointing the way to it
	## (GameMiniMap.pin_bearing says which, and the angle: the arrow turns with the bearing, nothing is random).
	func _pin(sb: GameSandbox) -> void:
		var b := GameMiniMap.pin_bearing(pane.dynasty, sb.heir, pane.radius)
		if b.is_empty():
			return
		var side := minf(size.x, size.y)
		var box := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
		var ink := Color(0.05, 0.04, 0.08)
		var col: Color = Kit.ACCENT
		if bool(b["inside"]):
			var at := box.get_center() + Vector2(b["offset"]) * (side / float(pane.radius * 2 + 1))
			draw_line(at, at + Vector2(0, -9), ink, 3.0)
			draw_line(at, at + Vector2(0, -9), Color.WHITE, 1.0)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-1, -10), at + Vector2(8, -6), at + Vector2(-1, -2)]), ink)
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -9), at + Vector2(6, -6), at + Vector2(0, -3)]), col)
			return
		var dir := Vector2(cos(float(b["angle"])), sin(float(b["angle"])))
		var half := box.size * 0.5 - Vector2(12, 12)
		var t := minf(half.x / maxf(absf(dir.x), 0.0001), half.y / maxf(absf(dir.y), 0.0001))
		var tip := box.get_center() + dir * t
		var side_v := Vector2(-dir.y, dir.x)
		var back := tip - dir * 14.0
		var pts := PackedVector2Array([tip + dir * 2.0, back + side_v * 8.0, back - dir * 4.0, back - side_v * 8.0])
		draw_colored_polygon(PackedVector2Array([tip + dir * 4.0, back + side_v * 10.0, back - dir * 5.0, back - side_v * 10.0]), ink)
		draw_colored_polygon(pts, col)

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
	_pin_note = Kit.label("", 13, Kit.ACCENT)
	_pin_note.name = "PinNote"
	_pin_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pin_note.visible = false
	v.add_child(_pin_note)
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
	var kinds := GameMiniMap.kinds(d, cx, cz, r)
	var n := r * 2 + 1
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for z in n:
		for x in n:
			var c: Array = colors.get(str(kinds[z][x]), colors.get("built", [0.5, 0.42, 0.3]))
			img.set_pixel(x, z, Color(float(c[0]), float(c[1]), float(c[2])))
	return img


func refresh() -> void:
	if sb == null:
		return
	if sb.space != "world":
		_image.texture = null
		_note.text = "Indoors."
		_pin_note.visible = false
		_dots.queue_redraw()
		return
	if sb.heir != _at:
		_at = sb.heir
		_image.texture = ImageTexture.create_from_image(make_image(dynasty, sb.heir.x, sb.heir.y, radius))
		_note.text = "%s" % sb.place_line() if sb.place_line() != "" else "Open ground."
	var b := GameMiniMap.pin_bearing(dynasty, sb.heir, radius)
	_pin_note.visible = not b.is_empty()
	if not b.is_empty():
		_pin_note.text = GameWorldMap.text("pin_under", {"name": b["place"], "tiles": b["distance"], "dir": b["dir"]})
	_dots.queue_redraw()
