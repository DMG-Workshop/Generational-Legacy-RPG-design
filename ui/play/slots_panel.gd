## The save slots in the game: one row per slot with what it holds, a Save here and a Load button. Saving over another house, and
## loading (which leaves the world as it was last saved), ask first. Opened from the pause screen; Back (Escape) closes it. Rendering
## only: GameSaves says what each slot holds, the app moves between slots.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const SkinScreen := preload("res://ui/play/skin_screen.gd")
const MenuKit := preload("res://ui/play/menu_kit.gd")

var app: Node
var screen: Control
var rows: VBoxContainer
var confirm: HBoxContainer
var note: Label
var _pending: Callable = Callable()


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
	p.custom_minimum_size = Vector2(minf(560.0, UiSettings.room(self).x - 24.0), 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := Kit.label(str(MenuKit.data()["slots_panel"]["title"]), 22, Kit.ACCENT)
	var rb := SkinScreen.ribbon(t)
	rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(rb)
	top.add_child(Kit.button("Back", func(): queue_free(), Vector2(100, 34)))
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	v.add_child(rows)
	confirm = HBoxContainer.new()
	confirm.add_theme_constant_override("separation", 8)
	confirm.visible = false
	v.add_child(confirm)
	note = Kit.label("", 14, Kit.dim())
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	_build()


## What a slot holds, in one short line.
static func line(n: int) -> String:
	var info := GameSaves.peek(n)
	var d: Dictionary = MenuKit.data()["slots_panel"]
	if info["exists"] and not info["valid"]:
		return "%d: %s" % [n, d["damaged"]]
	if not info["valid"]:
		return "%d: %s" % [n, d["empty"]]
	return "%d: %s, gen %d, %s lv %d" % [n, info["house"], info["gen"], info["heir"], info["level"]]


func _build() -> void:
	Kit.clear(rows)
	var d: Dictionary = MenuKit.data()["slots_panel"]
	var iron: bool = app.dynasty != null and GameHardMode.ironman(app.dynasty)
	for n in range(1, GameSaves.slots() + 1):
		var slot := n
		var info := GameSaves.peek(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		rows.add_child(row)
		var l := Kit.label(("> " if slot == app.slot else "") + line(slot), 15, Kit.TEXT if info["valid"] else Kit.dim())
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.tooltip_text = line(slot)
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(l)
		var save := Kit.button(str(d["save_here"]), func(): _ask(slot, true), Vector2(96, 38))
		save.name = "Save_%d" % slot
		save.disabled = iron and slot != app.slot   # an iron-man house keeps to its one slot
		if save.disabled:
			save.tooltip_text = GameHardMode.text("no_export")
		row.add_child(save)
		var load_b := Kit.button(str(d["load"]), func(): _ask(slot, false), Vector2(80, 38))
		load_b.name = "Load_%d" % slot
		load_b.disabled = not info["valid"]
		row.add_child(load_b)


## Saving over another slot's house, or loading one (this world's unsaved steps go to the slot in use first), asks first when it would
## replace something.
func _ask(slot: int, saving: bool) -> void:
	var here := GameSaves.peek(slot)
	if saving and (slot == app.slot or not here["exists"]):
		_do_save(slot)
		return
	_pending = (func(): _do_save(slot)) if saving else (func(): _do_load(slot))
	Kit.clear(confirm)
	var q := Kit.label(str(MenuKit.data()["slots_panel"]["over"]) % slot if saving else "Load slot %d? This world is saved to slot %d first." % [slot, app.slot], 14, Kit.bad())
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.add_child(q)
	confirm.add_child(Kit.button(str(MenuKit.data()["confirm"]["yes"]), _confirmed, Vector2(70, 36)))
	confirm.add_child(Kit.button(str(MenuKit.data()["confirm"]["no"]), func(): confirm.visible = false, Vector2(70, 36)))
	confirm.visible = true


func _confirmed() -> void:
	var act := _pending
	_pending = Callable()
	confirm.visible = false
	if act.is_valid():
		act.call()


func _do_save(slot: int) -> void:
	app.use_slot(slot)
	if screen != null and screen.has_method("_save"):
		screen._save()
	else:
		app.autosave()
	note.text = "Saved to slot %d." % slot
	if screen != null and "toast" in screen and screen.toast != null:
		screen.toast.say(note.text, "good")
	_build()


func _do_load(slot: int) -> void:
	if screen != null and screen.has_method("_save"):
		screen._save()   # the world as it stands goes to the slot in use before another is picked up
	else:
		app.autosave()
	app.use_slot(slot)
	app.continue_game(true)
