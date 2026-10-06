## Overlay: the family's map of the world (fog of war), roads out of here, and maps for sale.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")

const BOX := Vector2(88, 28)
const SIDE_W := 300

var dynasty: GameDynasty
var on_travel: Callable   # called with the destination id; the life screen does the travelling
var on_change: Callable   # called after a purchase; the life screen saves and refreshes


## Places are laid out on the world grid, stretched to whatever room the panel leaves.
class MapCanvas extends Control:
	var world: GameWorld
	var flags: Dictionary = {}
	var grid := Vector2(1, 1)

	static func sealed(link: Dictionary, p_flags: Dictionary) -> bool:
		return link.has("requires_flag") and not p_flags.has(link["requires_flag"])

	## Names are drawn at 11px, smaller only when a long one would not fit inside its box.
	static func name_size(font: Font, text: String) -> int:
		var fs := 11
		while fs > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > BOX.x - 6.0:
			fs -= 1
		return fs

	func _ready() -> void:
		for l in GameData.world["locations"]:
			grid = Vector2(maxf(grid.x, float(l["x"])), maxf(grid.y, float(l["y"])))
		resized.connect(queue_redraw)

	func _pos(id: String) -> Vector2:
		var p := GameWorld.place(id)
		var half := BOX * 0.5 + Vector2(2, 2)
		var span := Vector2(maxf(0.0, size.x - half.x * 2.0), maxf(0.0, size.y - half.y * 2.0))
		return half + Vector2(float(p["x"]) / grid.x * span.x, float(p["y"]) / grid.y * span.y)

	func _draw() -> void:
		var font := get_theme_default_font()
		for l in GameData.world["locations"]:
			if world.knowledge(l["id"]) == "unknown":
				continue
			for link in l["links"]:
				if world.knowledge(link["to"]) == "unknown" or link["to"] < l["id"]:
					continue
				draw_line(_pos(l["id"]), _pos(link["to"]), Color("#3a2a3a") if sealed(link, flags) else Color("#5a5470"), 2.0)
		for l in GameData.world["locations"]:
			var k := world.knowledge(l["id"])
			if k == "unknown":
				continue
			var p := _pos(l["id"])
			var here: bool = l["id"] == world.location
			var fill := Color("#2e2a42")
			if k == "visited":
				fill = Color("#4a4466") if l["type"] != "town" else Color("#6a5a2a")
			var r := Rect2(p - BOX * 0.5, BOX)
			draw_rect(r, fill)
			draw_rect(r, Kit.ACCENT if here else Color("#8d88a0"), false, 2.0 if here else 1.0)
			var label: String = "?" if k == "seen" else str(l["name"])
			var col := Kit.TEXT if k == "visited" else Kit.DIM
			draw_string(font, p + Vector2(-BOX.x * 0.5, 4), label, HORIZONTAL_ALIGNMENT_CENTER, BOX.x, name_size(font, label), col)
			if l.has("lair") and k != "seen":
				draw_circle(p + Vector2(40, -12), 4, Kit.BAD)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var p := Kit.panel(Color("#1a1828"))
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.offset_left = 30
	p.offset_right = -30
	p.offset_top = 24
	p.offset_bottom = -24
	p.add_theme_stylebox_override("panel", Kit.style(Color("#1a1828"), 8, Kit.ACCENT))
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var w := dynasty.world
	var top := HBoxContainer.new()
	v.add_child(top)
	var title := Kit.label("Map of House %s  -  %s  -  %s" % [dynasty.dynasty_name, w.date_text(), w.weather()["name"]], 20, Kit.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(Kit.button("Close", func(): queue_free(), Vector2(100, 34)))

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var canvas := MapCanvas.new()
	canvas.world = w
	canvas.flags = dynasty.flags
	canvas.custom_minimum_size = Vector2(600, 420)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(canvas)

	var side_scroll := ScrollContainer.new()
	side_scroll.custom_minimum_size = Vector2(SIDE_W, 0)
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(side_scroll)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(side)
	var here := w.here()
	var where := Kit.label("%s (%s)\n%s" % [here["name"], here["type"], here.get("description", "")], 14)
	where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(where)
	var sky := Kit.label(w.weather().get("text", ""), 13, Kit.DIM)
	sky.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(sky)
	side.add_child(HSeparator.new())
	side.add_child(Kit.label("Roads from here", 16, Kit.ACCENT))
	for link in w.roads(w.location, dynasty.flags):
		var dest: Dictionary = GameWorld.place(link["to"])
		var known := w.knowledge(link["to"])
		var dest_name: String = dest["name"] if known != "seen" else "Unknown %s" % dest["type"]
		var to: String = link["to"]
		var b := Kit.button("%s  (%s)" % [dest_name, GameDynasty._span_text(w.travel_years(link))], func(): _go(to), Vector2(0, 34))
		b.clip_text = true
		b.tooltip_text = "Travel to %s." % (dest["name"] if known != "seen" else "the unknown %s" % dest["type"])
		side.add_child(b)
	for link in GameWorld.place(w.location).get("links", []):
		if link.has("requires_flag") and not dynasty.flags.has(link["requires_flag"]):
			var sealed := Kit.label("A road to %s is sealed." % ("somewhere" if w.knowledge(link["to"]) == "seen" else GameWorld.place(link["to"])["name"]), 13, Kit.DIM)
			sealed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			side.add_child(sealed)
	var maps := w.maps_for_sale()
	if not maps.is_empty():
		side.add_child(HSeparator.new())
		side.add_child(Kit.label("Maps for sale", 16, Kit.ACCENT))
		for m in maps:
			var mid: String = m["id"]
			var b2 := Kit.button("%s (%dg)" % [m["name"], dynasty.map_price(m)], func(): _buy(mid), Vector2(0, 34))
			b2.clip_text = true
			b2.tooltip_text = b2.text
			b2.disabled = dynasty.heir.gold < dynasty.map_price(m) or (m["reveals"] as Array).all(func(id): return w.knowledge(id) in ["visited", "charted"])
			side.add_child(b2)
	side.add_child(HSeparator.new())
	var legend := Kit.label("Gold box: town.  Red dot: a legend's lair.  ?: seen from the road, never walked.", 12, Kit.DIM)
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(legend)


func _go(to: String) -> void:
	queue_free()
	on_travel.call(to)


func _buy(map_id: String) -> void:
	dynasty._say(dynasty.buy_map(map_id))
	if on_change.is_valid():
		on_change.call()
	var again: Control = get_script().new()
	again.dynasty = dynasty
	again.on_travel = on_travel
	again.on_change = on_change
	get_parent().add_child(again)
	queue_free()
