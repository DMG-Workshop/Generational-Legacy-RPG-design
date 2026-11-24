## Controls: the open world's keys, one row for each action with what it answers to now, a Change button that waits for the
## next key (Escape cancels), and Reset. Rendering only: WorldInput (remap, reset, reset_all) does the work and keeps the
## player's keys in settings.cfg. Opened from the menu.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const WorldInput := preload("res://ui/play/world_input.gd")

var waiting := ""     # the action whose next key is awaited ("" when none)
var said: Label
var rows: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("back_close", func(): _back())
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
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := Kit.label("Controls", 22, Kit.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(Kit.button("Close", func(): queue_free(), Vector2(100, 34)))
	var how := Kit.label("Choose Change, then press a key. Escape cancels. For the mouse, pick the button for each job; a button another job has changes places. The gamepad's buttons are fixed.", 14, Kit.dim())
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(how)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	v.add_child(rows)
	said = Kit.label("", 14, Kit.good())
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(said)
	v.add_child(Kit.button("Reset every key and button", func(): _reset_all(), Vector2(0, 40)))
	_rebuild()


func _rebuild() -> void:
	for c in rows.get_children():
		rows.remove_child(c)
		c.queue_free()
	for role in WorldInput.mouse_roles():
		var r: String = role
		var mrow := HBoxContainer.new()
		mrow.add_theme_constant_override("separation", 6)
		var mname := Kit.label(str(WorldInput.data()["mouse_roles"][r]["name"]), 15, Kit.TEXT)
		mname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mname.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mrow.add_child(mname)
		for b in WorldInput.mouse_buttons():
			var button: String = b
			var pick := Kit.button(button.capitalize(), func(): _mouse(r, button), Vector2(72, 34))
			pick.name = "Mouse_%s_%s" % [r, button]
			pick.disabled = WorldInput.mouse_name(r) == button
			mrow.add_child(pick)
		rows.add_child(mrow)
	for action in WorldInput.actions():
		var a: String = action
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var name := Kit.label(str(WorldInput.data()["actions"][a]["name"]), 15, Kit.TEXT)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		row.add_child(Kit.label(", ".join(WorldInput.keys_of(a)), 15, Kit.dim()))
		var change := Kit.button("Press a key..." if waiting == a else "Change", func(): _wait(a), Vector2(96, 34))
		change.name = "Change_" + a
		row.add_child(change)
		var reset := Kit.button("Reset", func(): _reset(a), Vector2(72, 34))
		reset.name = "Reset_" + a
		reset.disabled = not WorldInput.overrides().has(a)
		row.add_child(reset)
		rows.add_child(row)


func _wait(action: String) -> void:
	waiting = "" if waiting == action else action
	said.text = ""
	_rebuild()


## The next key goes to the action being changed, in place of its first key.
func _input(event: InputEvent) -> void:
	if waiting == "" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var key := OS.get_keycode_string((event as InputEventKey).keycode)
	if key == "Escape":
		waiting = ""
		said.text = ""
		_rebuild()
		return
	var r := WorldInput.remap(waiting, 0, key)
	said.text = str(r["text"])
	if r["ok"]:
		waiting = ""
	_rebuild()


func _mouse(role: String, button: String) -> void:
	said.text = str(WorldInput.set_mouse(role, button)["text"])
	_rebuild()


func _reset(action: String) -> void:
	said.text = str(WorldInput.reset(action)["text"])
	_rebuild()


func _reset_all() -> void:
	WorldInput.reset_all()
	WorldInput.reset_mouse()
	waiting = ""
	said.text = "Every key and mouse button is back to its own."
	_rebuild()


func _back() -> void:
	if waiting != "":
		waiting = ""
		_rebuild()
	else:
		queue_free()
