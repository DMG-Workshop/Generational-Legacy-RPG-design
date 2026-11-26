## The pause screen of the open world (Escape, the pad's B or Start, the bar's Menu button): Resume, Panels, Options, Controls, Save, Save
## slots, Back to the text game, Main menu and Quit, over a dimmed map that waits. Rows come from data/ui/menus.json. Escape (the app's
## back) closes it; so does Resume. Rendering only: saving goes through the sandbox screen and the app.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const SkinScreen := preload("res://ui/play/skin_screen.gd")
const MenuKit := preload("res://ui/play/menu_kit.gd")
const SlotsPanel := preload("res://ui/play/slots_panel.gd")

var app: Node
var screen: Control   # the sandbox screen it pauses
var note: Label
var buttons := {}     # row id -> Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("modal", true)   # the world waits while it is up
	set_meta("back_close", func(): close())
	z_index = 20
	SkinScreen.apply(self, false)
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
	p.set_meta("kit_panel", true)
	p.custom_minimum_size = Vector2(minf(360.0, UiSettings.room(self).x - 24.0), 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var t := Kit.label(str(MenuKit.data()["pause"]["title"]), 22, Kit.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(SkinScreen.ribbon(t))
	for r in MenuKit.rows("pause"):
		var id := str(r["id"])
		if id == "quit" and UiSettings.is_mobile():
			continue   # a phone leaves an app from the system, not from a button
		var b := Kit.button(str(r["label"]), func(): do(id), Vector2(0, 40))
		b.tooltip_text = str(r.get("hint", ""))
		b.name = "Row_" + id
		buttons[id] = b
		v.add_child(b)
	note = Kit.label("", 14, Kit.good())
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)
	if app != null and app.pad != null and app.pad.on:
		app.pad.refocus.call_deferred()   # the pad or keys are in use: the focus starts on Resume


## Puts the pause screen away. The sandbox ignores that same frame's Escape, which would open it again.
func close() -> void:
	if screen != null and "pause_closed_frame" in screen:
		screen.pause_closed_frame = Engine.get_process_frames()
	queue_free()


## Does one row.
func do(id: String) -> void:
	match id:
		"resume":
			close()
		"panels":
			close()
			if screen != null:
				screen._open_panels_menu.call_deferred()
		"options":
			app.open_menu()
		"controls":
			app.open_controls()
		"save":
			if screen != null:
				screen._save()
			else:
				app.autosave()
			note.text = str(MenuKit.data()["pause"]["saved"])
			if screen != null and screen.toast != null:
				screen.toast.say(note.text, "good")
		"slots":
			var s: Control = SlotsPanel.new()
			s.app = app
			s.screen = screen
			add_child(s)
		"text":
			app.show_state()
		"main":
			if screen != null:
				screen._save()
			app.show_title()
		"quit":
			if screen != null:
				screen._save()
			get_tree().quit()
