## Overlay: the family's map of the world (fog of war), roads out of here, and maps for sale.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")

const CELL := Vector2(92, 66)
const ORIGIN := Vector2(46, 40)

var dynasty: GameDynasty
var on_travel: Callable   # called with the destination id; the life screen does the travelling


class MapCanvas extends Control:
	var world: GameWorld

	func _pos(id: String) -> Vector2:
		var p := GameWorld.place(id)
		return ORIGIN + Vector2(float(p["x"]) * CELL.x, float(p["y"]) * CELL.y)

	func _draw() -> void:
		var font := get_theme_default_font()
		for l in GameData.world["locations"]:
			if world.knowledge(l["id"]) == "unknown":
				continue
			for link in l["links"]:
				if world.knowledge(link["to"]) == "unknown" or link["to"] < l["id"]:
					continue
				var locked: bool = link.has("requires_flag")
				draw_line(_pos(l["id"]), _pos(link["to"]), Color("#5a5470") if not locked else Color("#3a2a3a"), 2.0)
		for l in GameData.world["locations"]:
			var k := world.knowledge(l["id"])
			if k == "unknown":
				continue
			var p := _pos(l["id"])
			var here: bool = l["id"] == world.location
			var fill := Color("#2e2a42")
			if k == "visited":
				fill = Color("#4a4466") if l["type"] != "town" else Color("#6a5a2a")
			var r := Rect2(p - Vector2(44, 14), Vector2(88, 28))
			draw_rect(r, fill)
			draw_rect(r, Kit.ACCENT if here else Color("#8d88a0"), false, 2.0 if here else 1.0)
			var label: String = "?" if k == "seen" else str(l["name"])
			var col := Kit.TEXT if k == "visited" else Kit.DIM
			draw_string(font, p + Vector2(-43, 4), label, HORIZONTAL_ALIGNMENT_CENTER, 86, 11, col)
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
	canvas.custom_minimum_size = Vector2(ORIGIN.x * 2.0 + CELL.x * 9.0, ORIGIN.y * 2.0 + CELL.y * 7.0)
	row.add_child(canvas)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(side)
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
		var dest_name: String = dest["name"] if known != "seen" else "the unknown (%s)" % dest["type"]
		var to: String = link["to"]
		var b := Kit.button("To %s - %s" % [dest_name, GameDynasty._span_text(w.travel_years(link))], func(): _go(to), Vector2(0, 34))
		side.add_child(b)
	for link in GameWorld.place(w.location).get("links", []):
		if link.has("requires_flag") and not dynasty.flags.has(link["requires_flag"]):
			side.add_child(Kit.label("A road to %s is sealed." % ("somewhere" if w.knowledge(link["to"]) == "seen" else GameWorld.place(link["to"])["name"]), 13, Kit.DIM))
	var maps := w.maps_for_sale()
	if not maps.is_empty():
		side.add_child(HSeparator.new())
		side.add_child(Kit.label("Maps for sale", 16, Kit.ACCENT))
		for m in maps:
			var mid: String = m["id"]
			var b2 := Kit.button("%s (%dg)" % [m["name"], dynasty.map_price(m)], func(): _buy(mid), Vector2(0, 34))
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
	var again: Control = get_script().new()
	again.dynasty = dynasty
	again.on_travel = on_travel
	get_parent().add_child(again)
	queue_free()
