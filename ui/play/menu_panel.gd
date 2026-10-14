## The game menu: text size, saving and the way back to the title. Opened by the life screen's
## Menu button, the title's Settings button, or Android's back button when nothing else is open.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")

var app: Node
var note: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("back_close", func(): queue_free())
	z_index = 20   # above a fight's lists and result, which draw raised
	var mode: String = app.menu_mode()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.style(Color("#1a1828"), 8, Kit.ACCENT))
	p.custom_minimum_size = Vector2(minf(520.0, UiSettings.room(self).x - 24.0), 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := Kit.label("Settings" if mode == "title" else "Menu", 22, Kit.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(Kit.button("Close", func(): queue_free(), Vector2(100, 34)))

	v.add_child(Kit.label("Text size", 17, Kit.ACCENT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	for s in UiSettings.scales():
		var sc: float = s
		var b := Kit.button("%d%%" % int(round(sc * 100.0)), func(): app.set_ui_scale(sc), Vector2(100, 40))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_equal_approx(sc, UiSettings.get_scale()):
			b.add_theme_stylebox_override("normal", Kit.style(Color("#3d3860"), 6, Kit.ACCENT))
			b.add_theme_color_override("font_color", Kit.ACCENT)
		row.add_child(b)
	var why := Kit.label("Everything on screen grows together. Phones and tablets start at %d%%." % int(round(float(UiSettings.setting("default_scale_mobile")) * 100.0)), 14, Kit.DIM)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(why)
	if UiSettings.touch():
		var tip := Kit.label("Hold a finger on anything for its details; a quick tap acts.", 14, Kit.DIM)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(tip)
	v.add_child(HSeparator.new())
	note = Kit.label("", 14, Kit.GOOD)
	match mode:
		"game":
			v.add_child(Kit.button("Save", func():
				app.autosave()
				note.text = "Saved.", Vector2(0, 40)))
			v.add_child(Kit.button("Title screen", func(): app.show_title(), Vector2(0, 40)))
		"battle":
			var l := Kit.label("A fight is not saved until it ends; the house is as it was before it began.", 14, Kit.DIM)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(l)
	v.add_child(note)
