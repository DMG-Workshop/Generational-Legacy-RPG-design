## The world map: the open world as one picture (GameWorldMap), opened from the sandbox's Map button over the map while the
## world waits. Each cell is drawn in the tile view's colour for its kind; places are marked (named once visited), the family's
## place is ringed and the heir is a dot. Rendering only: GameWorldMap says what is where.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")

var dynasty: GameDynasty
var heir_tile := Vector2i(-1, -1)   # where the heir stands on the open world, if shown
var canvas: Control
var image: Image
var texture: ImageTexture


## The picture of the world: one pixel a cell, in the tile view's colours.
static func make_image(d: GameDynasty) -> Image:
	var n := GameWorldMap.cells()
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var colors: Dictionary = GameSandbox.data()["tiles"]["colors"]
	var grid := GameWorldMap.grid(d)
	for z in n:
		for x in n:
			var c: Array = colors.get(str(grid[z][x]), [0.2, 0.2, 0.2])
			img.set_pixel(x, z, Color(float(c[0]), float(c[1]), float(c[2])))
	return img


class MapCanvas extends Control:
	var panel: Control

	func _draw() -> void:
		var d: GameDynasty = panel.dynasty
		draw_texture_rect(panel.texture, Rect2(Vector2.ZERO, size), false)
		var n := float(GameWorldMap.cells())
		var cell := size / n
		var mpx := float(GameWorldMap.setting("marker_px"))
		var font := ThemeDB.fallback_font
		for m in GameWorldMap.markers(d):
			var at: Vector2 = (Vector2(m["cell"]) + Vector2(0.5, 0.5)) * cell
			var col: Color = Kit.ACCENT if bool(m["visited"]) else Kit.dim()
			draw_rect(Rect2(at - Vector2(mpx, mpx) * 0.5, Vector2(mpx, mpx)), Color(0.1, 0.08, 0.14))
			draw_rect(Rect2(at - Vector2(mpx, mpx) * 0.5 + Vector2.ONE, Vector2(mpx, mpx) - Vector2(2, 2)), col)
			if bool(m["here"]):
				draw_arc(at, mpx * 1.4, 0.0, TAU, 20, Color.WHITE, 2.0)
			if bool(m["visited"]):
				draw_string(font, at + Vector2(mpx * 0.8, -mpx * 0.6), str(m["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		for m in GameWorldMap.landmark_markers(d):
			var lp: Vector2 = (Vector2(m["cell"]) + Vector2(0.5, 0.5)) * cell
			var q := maxf(2.0, mpx * 0.4)
			draw_colored_polygon(PackedVector2Array([lp + Vector2(0, -q), lp + Vector2(q, 0), lp + Vector2(0, q), lp + Vector2(-q, 0)]), Color(0.95, 0.8, 0.4))
		if panel.heir_tile.x >= 0:
			var c := GameWorldMap.cell_of(panel.heir_tile.x, panel.heir_tile.y)
			var hp := (Vector2(c) + Vector2(0.5, 0.5)) * cell
			var r := float(GameWorldMap.setting("heir_px"))
			draw_circle(hp, r * 0.5 + 1.0, Color(0.1, 0.08, 0.14))
			draw_circle(hp, r * 0.5, Color(0.95, 0.3, 0.3))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("modal", true)
	set_meta("back_close", func(): queue_free())
	z_index = 20
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	image = make_image(dynasty)
	texture = ImageTexture.create_from_image(image)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.style(Color("#1a1828"), 8, Kit.ACCENT))
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := Kit.label(GameWorldMap.text("title"), 22, Kit.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var close := Kit.button("Close", func(): queue_free(), Vector2(100, 34))
	close.name = "Close"
	top.add_child(close)
	var room := UiSettings.room(self)
	var side := maxf(160.0, minf(room.x - 60.0, room.y - 190.0))
	canvas = MapCanvas.new()
	(canvas as MapCanvas).panel = self
	canvas.name = "Canvas"
	canvas.custom_minimum_size = Vector2(side, side)
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	v.add_child(canvas)
	var here := Kit.label(GameWorldMap.here_line(dynasty), 14, Kit.TEXT)
	here.name = "HereLine"
	v.add_child(here)
	if heir_tile.x >= 0:
		var h := Kit.label(GameWorldMap.text("heir", {"heir": dynasty.heir.name, "x": heir_tile.x, "z": heir_tile.y}), 14, Kit.TEXT)
		h.name = "HeirLine"
		v.add_child(h)
	var places := Kit.label(GameWilds.text("map_title") + ": " + ", ".join(GameWorldMap.landmark_lines(dynasty, 6)), 13, Kit.TEXT)
	places.name = "Landmarks"
	places.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	places.custom_minimum_size = Vector2(maxf(160.0, minf(room.x - 60.0, room.y - 190.0)), 0)
	v.add_child(places)
	var legend := Kit.label(GameWorldMap.text("legend"), 13, Kit.dim())
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.custom_minimum_size = Vector2(side, 0)
	v.add_child(legend)
