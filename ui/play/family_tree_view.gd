## The family tree drawn for a skinned chronicle: one parchment node card per heir (a crimson ribbon with the name, the facts below
## in ink), the generations one under another and joined by ink lines. It only draws what `GameFamilyTree.tree` says. Rendering only.
extends VBoxContainer

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSkin := preload("res://ui/play/ui_skin.gd")

const CARD_W := 250.0
const GAP := 22.0

var _rows: Array = []   # one flow of cards per generation, oldest first


func build(t: Dictionary) -> void:
	add_theme_constant_override("separation", int(GAP))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if int(t["folded"]) > 0:
		var l := Kit.label("%s earlier heirs are told in the Ages tab." % GameText.num(int(t["folded"])), 14, Kit.dim())
		add_child(l)
	for entry in t["generations"]:
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 14)
		flow.add_theme_constant_override("v_separation", 14)
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
		for h in entry["heirs"]:
			flow.add_child(_card(entry["gen"], h))
		add_child(flow)
		_rows.append(flow)
	if _rows.is_empty():
		add_child(Kit.label("No family yet.", 14, Kit.dim()))


func _card(gen: Variant, h: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiSkin.panel_box())
	card.set_meta("skin_face", true)   # parchment: its labels are dressed in ink like the pane's
	card.custom_minimum_size = Vector2(CARD_W, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	card.add_child(v)
	var rib := PanelContainer.new()
	rib.add_theme_stylebox_override("panel", UiSkin.ribbon_box())
	rib.set_meta("skin_face", true)
	var name := Label.new()
	name.text = str(h["name"])
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiSkin.dress_title(name)
	name.add_theme_font_size_override("font_size", 15)
	name.add_theme_constant_override("outline_size", 2)
	name.custom_minimum_size.y = 24.0
	rib.add_child(name)
	v.add_child(rib)
	var cname := "%s %s" % [GameData.races[h["race_id"]]["name"], GameData.classes[h["class_id"]]["name"]]
	var fate := "living, level %s" % GameText.num(int(h["level"])) if h["living"] else "died %s, level %s" % [h["cause"], GameText.num(int(h["level"]))]
	v.add_child(_line("Generation %s" % GameText.num(int(gen)), true, 15))
	v.add_child(_line("%s (%s)" % [cname, fate], false, 14))
	if not (h["parents"] as Array).is_empty():
		v.add_child(_line("child of %s" % " & ".join(h["parents"]), false, 13, true))
	if str(h["spouse"]) != "":
		v.add_child(_line("married to %s" % h["spouse"], false, 13, true))
	if not (h["children"] as Array).is_empty():
		v.add_child(_line("children: %s" % ", ".join(h["children"]), false, 13, true))
	if not (h["traits"] as Array).is_empty():
		v.add_child(_line("traits: %s" % ", ".join(h["traits"]), false, 13, true))
	for e in h["echoes"]:
		v.add_child(_line("legacy: %s" % e, false, 13, true))
	return card


func _line(text: String, strong: bool, size: int, quiet: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", UiSkin.pal("crimson_dk") if strong else (UiSkin.pal("ink_dim") if quiet else UiSkin.pal("ink")))
	l.set_meta("skin_done", true)
	return l


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		queue_redraw()


## Ink lines: a stem down from the generation above to a bar over the cards, and a short tick down to each card.
func _draw() -> void:
	var w := float(UiSkin.pixel())
	var ink := UiSkin.pal("ink")
	var prev_bottom := -1.0
	var prev_x := 0.0
	for flow in _rows:
		if not is_instance_valid(flow) or flow.get_child_count() == 0:
			continue
		var f: Control = flow
		var top := f.position.y
		var bus := top - GAP * 0.5
		var xs: Array = []
		for c in f.get_children():
			if absf(c.position.y) < 1.0:   # the cards on the first line of the flow share the bar
				xs.append(f.position.x + c.position.x + c.size.x * 0.5)
		if xs.is_empty():
			continue
		var lo: float = xs.min()
		var hi: float = xs.max()
		if prev_bottom < 0.0:   # the oldest generation hangs from nothing
			prev_bottom = f.position.y + f.size.y
			prev_x = (lo + hi) * 0.5
			continue
		draw_rect(Rect2(lo - w * 0.5, bus - w * 0.5, hi - lo + w, w), ink)
		for x in xs:
			draw_rect(Rect2(x - w * 0.5, bus, w, top - bus), ink)
		if prev_bottom >= 0.0:
			draw_rect(Rect2(prev_x - w * 0.5, prev_bottom, w, bus - prev_bottom), ink)
			draw_rect(Rect2(minf(prev_x, (lo + hi) * 0.5) - w * 0.5, bus - w * 0.5, absf(prev_x - (lo + hi) * 0.5) + w, w), ink)
		prev_bottom = f.position.y + f.size.y
		prev_x = (lo + hi) * 0.5
