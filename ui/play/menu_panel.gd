## The game menu: text size, touch layout, saving and the way back to the title. Opened by the life
## screen's Menu button, the title's Settings button, or Android's back button when nothing else is
## open.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const Clipboard := preload("res://ui/play/clipboard.gd")
const FilePicker := preload("res://ui/play/file_picker.gd")
const GraphicsSettings := preload("res://ui/play/graphics_settings.gd")

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
		_choice(row, "%d%%" % int(round(sc * 100.0)), is_equal_approx(sc, UiSettings.get_scale()), func(): app.set_ui_scale(sc))
	var why := Kit.label("Everything on screen grows together. Phones and tablets start at %d%%." % int(round(float(UiSettings.setting("default_scale_mobile")) * 100.0)), 14, Kit.dim())
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(why)

	v.add_child(Kit.label("Touch layout", 17, Kit.ACCENT))
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	v.add_child(trow)
	for tl in UiSettings.touch_layouts():
		var mode_id: String = tl
		_choice(trow, mode_id.capitalize(), mode_id == UiSettings.get_touch_layout(), func(): app.set_touch_layout(mode_id))
	var twhy := Kit.label("Fingertip-sized buttons and tap / hold in the help. Auto: on phones and tablets only.", 14, Kit.dim())
	twhy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(twhy)
	if UiSettings.touch() or UiSettings.touch_screen():
		var tip := Kit.label("Hold a finger on anything for its details; a quick tap acts.", 14, Kit.dim())
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(tip)

	v.add_child(Kit.label("Tutorial tips", 17, Kit.ACCENT))
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 8)
	v.add_child(prow)
	_choice(prow, "On", UiSettings.tutorial_on(), func(): app.set_tutorial(true))
	_choice(prow, "Off", not UiSettings.tutorial_on(), func(): app.set_tutorial(false))
	var pwhy := Kit.label("Short tips about what to do next, for a new house's first heir.", 14, Kit.dim())
	pwhy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(pwhy)
	v.add_child(Kit.label("Accessibility", 17, Kit.ACCENT))
	var options := [
		["colour_blind", "Colour-blind colours", "Good and bad news in blue and orange, not green and red."],
		["high_contrast", "High contrast", "Quiet text in a brighter grey."],
		["reduced_motion", "Reduced motion", "No sliding or lunging in fights; numbers fade where they are."],
	]
	for opt in options:
		var key: String = opt[0]
		var on := UiSettings.access_on(key)
		var krow := HBoxContainer.new()
		krow.add_theme_constant_override("separation", 8)
		v.add_child(krow)
		var name_l := Kit.label(opt[1], 15, Kit.TEXT)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		krow.add_child(name_l)
		_choice(krow, "On", on, func(): app.set_access(key, true))
		_choice(krow, "Off", not on, func(): app.set_access(key, false))
		var khy := Kit.label(opt[2], 14, Kit.dim())
		khy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(khy)
	v.add_child(Kit.label("Graphics", 17, Kit.ACCENT))
	var grow := HBoxContainer.new()
	grow.add_theme_constant_override("separation", 8)
	v.add_child(grow)
	for gid in GraphicsSettings.ids():
		var preset_id: String = gid
		_choice(grow, str(GraphicsSettings.preset_def(preset_id)["name"]), preset_id == GraphicsSettings.preset(), func(): app.set_graphics(preset_id))
	var gwhy := Kit.label(str(GraphicsSettings.preset_def(GraphicsSettings.preset())["about"]), 14, Kit.dim())
	gwhy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(gwhy)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 8)
	v.add_child(brow)
	var blabel := Kit.label("Battery saver", 15, Kit.TEXT)
	blabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brow.add_child(blabel)
	_choice(brow, "On", GraphicsSettings.battery_saver(), func(): app.set_battery_saver(true))
	_choice(brow, "Off", not GraphicsSettings.battery_saver(), func(): app.set_battery_saver(false))
	var bwhy := Kit.label(str(GraphicsSettings.data()["battery_saver"]["about"]), 14, Kit.dim())
	bwhy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(bwhy)
	v.add_child(Kit.label("Problems", 17, Kit.ACCENT))
	var erow := HBoxContainer.new()
	erow.add_theme_constant_override("separation", 8)
	v.add_child(erow)
	var elabel := Kit.label("Error log", 15, Kit.TEXT)
	elabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	erow.add_child(elabel)
	_choice(erow, "On", UiSettings.error_log_on(), func(): app.set_error_log(true))
	_choice(erow, "Off", not UiSettings.error_log_on(), func(): app.set_error_log(false))
	var ewhy := Kit.label("Remembers the game's last errors, for a report. Kept in memory only; nothing is sent.", 14, Kit.dim())
	ewhy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(ewhy)
	v.add_child(Kit.button("Report a problem", func(): app.open_report(), Vector2(0, 40)))
	v.add_child(HSeparator.new())
	note = Kit.label("", 14, Kit.good())
	match mode:
		"game":
			v.add_child(Kit.button("Save", func():
				app.autosave()
				note.text = "Saved.", Vector2(0, 40)))
			v.add_child(Kit.button("Copy backup", func():
				app.autosave()
				var text := GameSaves.export_text(app.slot)
				if text.is_empty():
					note.text = "Nothing could be copied."
				else:
					Clipboard.set_text(text)
					note.text = "Backup of slot %d copied. Paste it into a note to keep it." % app.slot, Vector2(0, 40)))
			v.add_child(Kit.button("Export to file", func():
				app.autosave()
				var slot: int = app.slot
				FilePicker.save("Save the house to a file", GameSaves.file_name(slot), func(path: String):
					if path == "":
						note.text = "Nothing was saved."
						return
					var r := GameSaves.export_file(slot, path)
					note.text = "Saved to %s." % path if r["ok"] else r["error"] + " Copy backup works too."), Vector2(0, 40)))
			v.add_child(Kit.button("Title screen", func(): app.show_title(), Vector2(0, 40)))
		"battle":
			var l := Kit.label("The fight is saved as you go: closing the game now reopens it where you left off.", 14, Kit.dim())
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(l)
	v.add_child(note)


## One of a row of settings buttons, the one in use marked.
func _choice(row: HBoxContainer, text: String, on: bool, cb: Callable) -> void:
	var b := Kit.button(text, cb, Vector2(100, 40))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if on:
		b.add_theme_stylebox_override("normal", Kit.style(Color("#3d3860"), 6, Kit.ACCENT))
		b.add_theme_color_override("font_color", Kit.ACCENT)
	row.add_child(b)
