## The world map: the open world as one picture (GameWorldMap), opened from the sandbox's Map button over the map while the
## world waits. Each cell is drawn in the tile view's colour for its kind; the towns (a house) and the cities (a castle) are always
## named, other places are named once visited, the family's place is ringed and the heir is a dot. A town or a city is selected by a
## click or tap on its marker (or its key in the row under the picture), which opens its card: the name, how far and which way, what a
## coach costs, and Pin it, Walk there and Book travel (GameTravel). The pin is drawn as a flag. Rendering only: GameWorldMap and
## GameTravel say what is where and what the keys do.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const PanelSkin := preload("res://ui/play/panel_skin.gd")

var dynasty: GameDynasty
var sb: GameSandbox = null          # the open world as it runs, for Walk there and Book travel (none: the card only pins)
var on_line: Callable = Callable()  # called with the line to say when a walk starts or a coach is booked (the panel then closes)
var heir_tile := Vector2i(-1, -1)   # where the heir stands on the open world, if shown
var selected := ""                  # the town whose card is up
var canvas: Control
var card: VBoxContainer
var image: Image
var texture: ImageTexture
var _skin: Control                  # a hidden stand-in for a pane, so the skin's helpers dress the card as they dress the house's rows


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

	func _cell_size() -> Vector2:
		return size / float(GameWorldMap.cells())

	## The town marker under a point of the canvas (within a fingertip or a few pixels), or {}.
	func town_at(p: Vector2) -> Dictionary:
		var cell := _cell_size()
		var reach_px := float(UiSettings.setting("touch_target_px")) * 0.5 if UiSettings.touch() else 14.0
		return GameWorldMap.town_near_cell(panel.dynasty, p / cell, reach_px / maxf(cell.x, 1.0))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var m := town_at((event as InputEventMouseButton).position)
			if not m.is_empty():
				panel.select(str(m["id"]))
				accept_event()

	func _get_tooltip(at_position: Vector2) -> String:
		var m := town_at(at_position)
		if m.is_empty():
			return ""
		return panel.tip_for(str(m["id"]))

	func _draw() -> void:
		var d: GameDynasty = panel.dynasty
		draw_texture_rect(panel.texture, Rect2(Vector2.ZERO, size), false)
		var n := float(GameWorldMap.cells())
		var cell := size / n
		var mpx := float(GameWorldMap.setting("marker_px"))
		var font := ThemeDB.fallback_font
		var ink := Color(0.1, 0.08, 0.14)
		for m in GameWorldMap.markers(d):
			var at: Vector2 = (Vector2(m["cell"]) + Vector2(0.5, 0.5)) * cell
			var kind := str(m["kind"])
			if kind == "town":
				_house(at, mpx, ink)
			elif kind == "city":
				_castle(at, mpx, ink)
			else:
				var col: Color = Kit.ACCENT if bool(m["visited"]) else Kit.dim()
				draw_rect(Rect2(at - Vector2(mpx, mpx) * 0.5, Vector2(mpx, mpx)), ink)
				draw_rect(Rect2(at - Vector2(mpx, mpx) * 0.5 + Vector2.ONE, Vector2(mpx, mpx) - Vector2(2, 2)), col)
			if bool(m["here"]):
				draw_arc(at, mpx * 1.4, 0.0, TAU, 20, Color.WHITE, 2.0)
			if str(m["id"]) == panel.selected:
				draw_arc(at, mpx * 1.9, 0.0, TAU, 28, Kit.ACCENT, 3.0)
			if bool(m["known"]):
				draw_string_outline(font, at + Vector2(mpx * 1.1, -mpx * 0.7), str(m["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, ink)
				draw_string(font, at + Vector2(mpx * 1.1, -mpx * 0.7), str(m["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		for m in GameWorldMap.landmark_markers(d):
			var lp: Vector2 = (Vector2(m["cell"]) + Vector2(0.5, 0.5)) * cell
			var q := maxf(2.0, mpx * 0.4)
			draw_colored_polygon(PackedVector2Array([lp + Vector2(0, -q), lp + Vector2(q, 0), lp + Vector2(0, q), lp + Vector2(-q, 0)]), Color(0.95, 0.8, 0.4))
		for m in GameWorldMap.trial_markers(d):
			var tp: Vector2 = (Vector2(m["cell"]) + Vector2(0.5, 0.5)) * cell
			var tq := maxf(3.0, mpx * 0.55)
			var tcol: Color = Kit.good() if bool(m["passed"]) else Color(0.8, 0.55, 0.95)
			var tri := PackedVector2Array([tp + Vector2(0, -tq), tp + Vector2(tq, tq * 0.8), tp + Vector2(-tq, tq * 0.8)])
			draw_colored_polygon(PackedVector2Array([tri[0] + Vector2(0, -1), tri[1] + Vector2(1.5, 1), tri[2] + Vector2(-1.5, 1)]), ink)
			draw_colored_polygon(tri, tcol)
		if GameTravel.has_pin(d):
			var pt := GameTravel.pin_tile(d)
			var pc := GameWorldMap.cell_of(pt.x, pt.y)
			_flag((Vector2(pc) + Vector2(0.5, 0.5)) * cell, mpx, ink)
		if panel.heir_tile.x >= 0:
			var c := GameWorldMap.cell_of(panel.heir_tile.x, panel.heir_tile.y)
			var hp := (Vector2(c) + Vector2(0.5, 0.5)) * cell
			var r := float(GameWorldMap.setting("heir_px"))
			draw_circle(hp, r * 0.5 + 1.0, ink)
			draw_circle(hp, r * 0.5, Color(0.95, 0.3, 0.3))

	## A town: a small house, a gable roof over a plank wall.
	func _house(at: Vector2, s: float, ink: Color) -> void:
		var w := s * 0.8
		draw_rect(Rect2(at + Vector2(-w, -s * 0.15), Vector2(w * 2.0, s * 1.0)), ink)
		draw_rect(Rect2(at + Vector2(-w + 1, -s * 0.15 + 1), Vector2(w * 2.0 - 2, s * 1.0 - 2)), Color(0.86, 0.72, 0.5))
		draw_colored_polygon(PackedVector2Array([at + Vector2(-w - 2, -s * 0.1), at + Vector2(0, -s * 1.0), at + Vector2(w + 2, -s * 0.1)]), ink)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-w, -s * 0.2), at + Vector2(0, -s * 0.86), at + Vector2(w, -s * 0.2)]), Color(0.75, 0.28, 0.22))

	## A city: a castle, a curtain wall between two towers with a gate, and a pennant.
	func _castle(at: Vector2, s: float, ink: Color) -> void:
		var w := s * 1.15
		draw_rect(Rect2(at + Vector2(-w - 1, -s * 0.5 - 1), Vector2(w * 2.0 + 2, s * 1.4 + 2)), ink)
		var stone := Color(0.78, 0.76, 0.82)
		draw_rect(Rect2(at + Vector2(-w, -s * 0.5), Vector2(w * 2.0, s * 1.4)), stone)
		for i in 3:   # the battlements along the top
			draw_rect(Rect2(at + Vector2(-w + float(i) * w * 0.9, -s * 0.8), Vector2(w * 0.5, s * 0.35)), stone)
		draw_rect(Rect2(at + Vector2(-s * 0.28, s * 0.25), Vector2(s * 0.56, s * 0.65)), ink)   # the gate
		draw_line(at + Vector2(0, -s * 0.8), at + Vector2(0, -s * 1.5), ink, 1.5)
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -s * 1.5), at + Vector2(s * 0.7, -s * 1.25), at + Vector2(0, -s * 1.0)]), Color(0.85, 0.2, 0.25))

	## The pin: a flag on a pole standing on its place.
	func _flag(at: Vector2, s: float, ink: Color) -> void:
		draw_line(at, at + Vector2(0, -s * 2.2), ink, 3.0)
		draw_line(at, at + Vector2(0, -s * 2.2), Color.WHITE, 1.0)
		var top := at + Vector2(0, -s * 2.2)
		draw_colored_polygon(PackedVector2Array([top + Vector2(-1, -1), top + Vector2(s * 1.5, s * 0.45), top + Vector2(-1, s * 0.95)]), ink)
		draw_colored_polygon(PackedVector2Array([top, top + Vector2(s * 1.25, s * 0.4), top + Vector2(0, s * 0.8)]), Kit.ACCENT)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("modal", true)
	set_meta("back_close", func(): queue_free())
	z_index = 20
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_skin = Control.new()
	_skin.set_meta("pane", "world_map_panel")
	_skin.visible = false
	add_child(_skin)
	image = make_image(dynasty)
	texture = ImageTexture.create_from_image(image)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", Kit.style(Color("#1a1828"), 8, Kit.ACCENT))
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := Kit.overlay_margin(self)
	frame.offset_left = m.x
	frame.offset_right = -m.x
	frame.offset_top = m.y
	frame.offset_bottom = -m.y
	add_child(frame)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	frame.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := Kit.label(GameWorldMap.text("title"), 22, Kit.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var close := Kit.button("Close", func(): queue_free(), Vector2(100, 34))
	close.name = "Close"
	top.add_child(close)
	var room := UiSettings.room(self)
	var wide := not UiSettings.compact(self) and room.x >= room.y * 1.4
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.name = "Scroll"
	v.add_child(scroll)
	var body: BoxContainer = HBoxContainer.new() if wide else VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	var inner := room.x - 2.0 * m.x - 40.0   # the width the body has
	var side: float
	var text_w: float
	if wide:
		side = clampf(minf(room.y - 2.0 * m.y - 150.0, inner * 0.55), 160.0, 900.0)
		text_w = maxf(240.0, inner - side - 24.0)
	else:
		side = clampf(minf(inner, room.y * 0.42), 160.0, 900.0)
		text_w = maxf(160.0, inner)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)
	canvas = MapCanvas.new()
	(canvas as MapCanvas).panel = self
	canvas.name = "Canvas"
	canvas.custom_minimum_size = Vector2(side, side)
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # a square, whatever the room beside it
	left.add_child(canvas)
	var here := Kit.label(GameWorldMap.here_line(dynasty), 14, Kit.TEXT)
	here.name = "HereLine"
	here.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	here.custom_minimum_size = Vector2(minf(side, text_w), 0)
	left.add_child(here)
	if heir_tile.x >= 0:
		var h := Kit.label(GameWorldMap.text("heir", {"heir": dynasty.heir.name, "x": heir_tile.x, "z": heir_tile.y}), 14, Kit.TEXT)
		h.name = "HeirLine"
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.custom_minimum_size = Vector2(minf(side, text_w), 0)
		left.add_child(h)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.custom_minimum_size = Vector2(text_w, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var row := HFlowContainer.new()   # the towns, as keys: for the keyboard, a gamepad and a finger
	row.name = "Towns"
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	right.add_child(row)
	for mk in GameWorldMap.town_markers(dynasty):
		var id := str(mk["id"])
		var c := GameTravel.card(dynasty, _from(), id)
		var b := Kit.button(GameWorldMap.text("town_key", {"name": c["name"], "tiles": c["tiles"], "dir": c["dir"]}), func(): select(id), Vector2(0, 38))
		b.name = "Town_" + id
		b.tooltip_text = tip_for(id)
		row.add_child(b)
	card = VBoxContainer.new()
	card.name = "Card"
	card.add_theme_constant_override("separation", 6)
	card.custom_minimum_size = Vector2(text_w, 0)
	right.add_child(card)
	for line in [
		[GameWilds.text("map_title") + ": " + ", ".join(GameWorldMap.landmark_lines(dynasty, 6)), "Landmarks"],
		[GameWorldMap.text("trial_title") + ": " + ", ".join(GameWorldMap.trial_lines(dynasty, 4)), "Trials"],
		[GameWorldMap.text("legend"), "Legend"],
	]:
		var l := Kit.label(str(line[0]), 13, Kit.dim() if line[1] == "Legend" else Kit.TEXT)
		l.name = str(line[1])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(text_w, 0)
		right.add_child(l)
	_build_card()


## Where the heir is for the map's sums: the tile they stand on, else the family's place's anchor (indoors, or with no sandbox).
func _from() -> Vector2i:
	if heir_tile.x >= 0:
		return heir_tile
	var a := GameWorldGen.anchor(str(dynasty.world.location))
	return Vector2i(int(a.get("x", 0)), int(a.get("z", 0))) if not a.is_empty() else Vector2i.ZERO


## What the mouse's tooltip (and a long press) says of a town.
func tip_for(id: String) -> String:
	var c := GameTravel.card(dynasty, _from(), id)
	if c.is_empty():
		return ""
	return "%s\n%s" % [GameWorldMap.text("card_title", {"name": c["name"], "kind": c["kind"]}), GameWorldMap.text("card_distance", {"tiles": c["tiles"], "dir": c["dir"], "heir": dynasty.heir.name})]


## A click, tap or key on a town: its card comes up.
func select(id: String) -> void:
	if not GameTravel.is_town(id):
		return
	selected = id
	_build_card()
	if canvas != null:
		canvas.queue_redraw()


## Draws the card of the selected town afresh (the pin and the gold change what it shows).
func _build_card() -> void:
	for c in card.get_children():
		card.remove_child(c)
		c.queue_free()
	if selected == "":
		var none := Kit.label(GameWorldMap.text("card_none"), 14, Kit.dim())
		none.name = "CardNone"
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(card.custom_minimum_size.x, 0)
		card.add_child(none)
		return
	var info := GameTravel.card(dynasty, _from(), selected)
	var width := card.custom_minimum_size.x
	var slot := PanelSkin.row(_skin, Color("#232036"))
	slot.name = "CardBox"
	card.add_child(slot)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	slot.add_child(col)
	var title := PanelSkin.label(_skin, GameWorldMap.text("card_title", {"name": info["name"], "kind": info["kind"]}), 18, Kit.ACCENT)
	title.name = "CardTitle"
	col.add_child(title)
	var dist_text := GameWorldMap.text("card_here", {"heir": dynasty.heir.name, "name": info["name"]}) if bool(info["here"]) and heir_tile.x >= 0 \
		else GameWorldMap.text("card_distance", {"tiles": info["tiles"], "dir": info["dir"], "heir": dynasty.heir.name})
	var dist := PanelSkin.label(_skin, dist_text, 15, Kit.TEXT)
	dist.name = "CardDistance"
	dist.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(dist)
	var fare := PanelSkin.label(_skin, GameWorldMap.text("card_fare", {"gold": GameText.num(int(info["fare"]))}), 15, Kit.dim())
	fare.name = "CardFare"
	fare.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(fare)
	var keys := HFlowContainer.new()
	keys.add_theme_constant_override("h_separation", 6)
	keys.add_theme_constant_override("v_separation", 6)
	col.add_child(keys)
	var pinned := GameTravel.pin_place(dynasty) == selected
	var pin := PanelSkin.button(_skin, GameWorldMap.text("btn_unpin" if pinned else "btn_pin"), func(): _pin(), Vector2(0, 40))
	pin.name = "PinButton"
	keys.add_child(pin)
	var walk := PanelSkin.button(_skin, GameWorldMap.text("btn_walk"), func(): _walk(), Vector2(0, 40))
	walk.name = "WalkButton"
	var walk_why := ""
	if bool(info["here"]) and heir_tile.x >= 0:
		walk_why = GameWorldMap.text("book_same", {"heir": dynasty.heir.name, "name": info["name"]})
	elif sb == null:
		walk_why = GameWorldMap.text("book_indoors", {"heir": dynasty.heir.name})
	walk.disabled = walk_why != ""
	keys.add_child(walk)
	var book := PanelSkin.button(_skin, GameWorldMap.text("btn_book"), func(): _book(), Vector2(0, 40))
	book.name = "BookButton"
	var why := GameTravel.refusal(sb, selected) if sb != null else GameWorldMap.text("book_indoors", {"heir": dynasty.heir.name})
	book.disabled = why != ""
	keys.add_child(book)
	# What shuts a key is said as text under the keys, never in a tooltip (a finger has none).
	var reason_text := why if why != "" else walk_why
	if reason_text != "":
		var reason := PanelSkin.reason(_skin, reason_text, true, 14)
		reason.name = "Reason"
		reason.custom_minimum_size = Vector2(maxf(120.0, width - 40.0), 0)
		col.add_child(reason)


func _pin() -> void:
	if GameTravel.pin_place(dynasty) == selected:
		GameTravel.clear_pin(dynasty)
		_say(GameWorldMap.text("pin_removed", {"name": GameTravel.name_of(selected)}), false)
	else:
		GameTravel.set_pin(dynasty, selected)
		var c := GameTravel.card(dynasty, _from(), selected)
		_say(GameWorldMap.text("pin_set", {"name": c["name"], "tiles": c["tiles"], "dir": c["dir"]}), false)
	_build_card()
	canvas.queue_redraw()


func _walk() -> void:
	if sb == null:
		return
	var r := sb.walk_there(selected)
	_say(str(r["text"]), true)


func _book() -> void:
	if sb == null:
		return
	var r := sb.book_travel(selected)
	if bool(r["ok"]):
		_say(str(r["text"]), true)
	else:
		_build_card()
		canvas.queue_redraw()


## Tells the screen what happened; an action that sets the heir going closes the map.
func _say(line: String, close: bool) -> void:
	if on_line.is_valid():
		on_line.call(line)
	if close:
		queue_free()
