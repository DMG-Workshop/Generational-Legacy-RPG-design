## Report a problem: says what an error report holds and that the game sends it nowhere, takes a note, and makes the
## report (GameReport) to copy or to save as a file. Opened from the menu. Rendering only: the report is built by
## GameReport from the house being played (or none, at the title), the device facts and the error log.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const Clipboard := preload("res://ui/play/clipboard.gd")
const FilePicker := preload("res://ui/play/file_picker.gd")
const ReportEnv := preload("res://ui/play/report_env.gd")

const FILTER := "*.glreport ; Generational Legacy error report"

var app: Node
var note_box: LineEdit
var said: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("back_close", func(): queue_free())
	z_index = 21   # above the menu it was opened from
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
	p.custom_minimum_size = Vector2(minf(560.0, UiSettings.room(self).x - 24.0), 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := Kit.label("Report a problem", 22, Kit.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(Kit.button("Close", func(): queue_free(), Vector2(100, 34)))
	var never := Kit.label(GameReport.text("never_sent"), 15, Kit.TEXT)
	never.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(never)
	v.add_child(Kit.label("A report holds:", 15, Kit.ACCENT))
	for line in GameReport.holds():
		var l := Kit.label("- " + str(line), 14, Kit.dim())
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var log_line := "The error log is on: %d remembered." % GameErrorLog.recent().size() if GameErrorLog.installed() else "The error log is off (Menu > Problems), so this report will carry no errors."
	var ll := Kit.label(log_line, 14, Kit.dim())
	ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(ll)
	v.add_child(Kit.label("What went wrong?", 15, Kit.ACCENT))
	note_box = LineEdit.new()
	note_box.placeholder_text = "A few words (optional)"
	note_box.max_length = int(GameReport.setting("max_note_chars"))
	note_box.custom_minimum_size = Vector2(0, UiSettings.tap_h(40))
	v.add_child(note_box)
	v.add_child(Kit.button("Copy report", func(): _copy(), Vector2(0, 40)))
	v.add_child(Kit.button("Save report to a file", func(): _save(), Vector2(0, 40)))
	said = Kit.label("", 14, Kit.good())
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(said)


## The report as text: the house being played as it is now (none at the title), the device, the errors and the note.
func make() -> String:
	var d: GameDynasty = app.dynasty if app.menu_mode() != "title" else null
	return GameReport.to_text(GameReport.build(d, ReportEnv.facts(get_window()), GameErrorLog.recent(), note_box.text))


func _copy() -> void:
	Clipboard.set_text(make())
	said.text = "Report copied. Paste it into a message to whoever is helping you."


func _save() -> void:
	var text := make()
	FilePicker.save("Save the report to a file", "problem." + GameReport.FILE_EXT, func(path: String):
		if path == "":
			said.text = "Nothing was saved."
			return
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			said.text = "The file could not be written to %s. Copy report works too." % path
			return
		f.store_string(text)
		f.close()
		said.text = "Saved to %s." % path, FILTER)
