## About: the game's name, version and a few lines (data/ui/menus.json), with Back (Escape) to close it. Opened from the main menu.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const SkinScreen := preload("res://ui/play/skin_screen.gd")
const MenuKit := preload("res://ui/play/menu_kit.gd")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("modal", true)
	set_meta("back_close", func(): queue_free())
	z_index = 22
	SkinScreen.apply(self, false)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
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
	p.set_meta("kit_panel", true)
	p.custom_minimum_size = Vector2(minf(520.0, UiSettings.room(self).x - 24.0), 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var rb := SkinScreen.ribbon(Kit.label(str(MenuKit.data()["about"]["title"]), 22, Kit.ACCENT))
	rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(rb)
	top.add_child(Kit.button("Back", func(): queue_free(), Vector2(100, 34)))
	var ver := str(ProjectSettings.get_setting("application/config/version", ""))
	v.add_child(Kit.label("%s%s" % [str(ProjectSettings.get_setting("application/config/name", "Generational Legacy")), ("  v" + ver) if ver != "" else ""], 17, Kit.TEXT))
	for line in MenuKit.data()["about"]["lines"]:
		var l := Kit.label(str(line), 14, Kit.dim())
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	v.add_child(Kit.label("Settings: %s" % UiSettings.path.get_base_dir(), 13, Kit.dim()))
