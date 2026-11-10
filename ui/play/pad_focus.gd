## Menus by gamepad and keyboard. The game's buttons are ordinary controls, so the engine already moves a focus
## between them with the d-pad, the left stick or the arrow keys and presses the focused one with A or Enter; what
## it does not do is put the focus anywhere to begin with, keep it inside the panel that is open, or go back. This
## node does those: the first pad or arrow input turns "pad mode" on and focuses the first button of the top layer
## (the open panel, else the screen); while it is on, a focus that is lost (the screen was rebuilt) or that strays
## out of the open panel is brought back; B or Escape goes back as Android's back button does (`GameApp.go_back`);
## Start opens or closes the menu. A click or a touch turns pad mode off and drops the focus, so a mouse or a
## finger never sees a focus ring. Rendering only.
extends Node

const MenuPanel := preload("res://ui/play/menu_panel.gd")

const STICK_DEADZONE := 0.5
const MOVES := ["ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev"]

var app: Node
var on := false


func _ready() -> void:
	_bind("ui_accept", JOY_BUTTON_A)   # the engine's own menu actions know the d-pad and stick, but not these two
	_bind("ui_cancel", JOY_BUTTON_B)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	get_viewport().gui_focus_changed.connect(_focus_changed)


## Adds a pad button to one of the engine's menu actions, once.
static func _bind(action: String, button: JoyButton) -> void:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == button:
			return
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.device = -1
	InputMap.action_add_event(action, ev)


## The layer the focus belongs in: the open panel on top, else the screen.
func layer() -> Control:
	if app.current == null:
		return null
	var top: Control = app._top_closable(app.current)
	return top if top != null else app.current


## The first thing in `n` the focus can rest on: a visible, enabled button or drop-down (a text box only when there
## is nothing else: a focused text box keeps the arrows and Escape to itself).
func first_in(n: Node) -> Control:
	var b := _first(n, false)
	return b if b != null else _first(n, true)


func _first(n: Node, text_boxes: bool) -> Control:
	if n is Control:
		var c: Control = n
		if not c.visible or c.is_queued_for_deletion():
			return null
		if text_boxes and c is LineEdit:
			return c
		if not text_boxes and c is BaseButton and not (c as BaseButton).disabled and c.focus_mode != Control.FOCUS_NONE:
			return c
	for child in n.get_children():
		var found := _first(child, text_boxes)
		if found != null:
			return found
	return null


func _inside(c: Control, top: Control) -> bool:
	return c != null and top != null and is_instance_valid(c) and c.is_visible_in_tree() and (c == top or top.is_ancestor_of(c))


## Puts the focus on the first button of the top layer (and lets its scroll areas follow the focus).
func refocus() -> void:
	var top := layer()
	if top == null:
		return
	_follow(top)
	var first := first_in(top)
	if first != null:
		first.grab_focus()


func _follow(n: Node) -> void:
	if n is ScrollContainer:
		(n as ScrollContainer).follow_focus = true
	for c in n.get_children():
		_follow(c)


func set_on(value: bool) -> void:
	if on == value:
		return
	on = value
	set_process(on)
	if on:
		var owner := get_viewport().gui_get_focus_owner()
		if not _inside(owner, layer()):
			refocus()
	else:
		var owner := get_viewport().gui_get_focus_owner()
		if owner != null and not (owner is LineEdit):   # a text box being typed in keeps its caret
			owner.release_focus()


func _process(_delta: float) -> void:
	if not _inside(get_viewport().gui_get_focus_owner(), layer()):
		refocus()


func _focus_changed(c: Control) -> void:
	if on and not _inside(c, layer()):
		refocus.call_deferred()


func _is_move(ev: InputEvent) -> bool:
	if ev is InputEventJoypadMotion:
		return absf((ev as InputEventJoypadMotion).axis_value) >= STICK_DEADZONE
	for a in MOVES:
		if ev.is_action_pressed(a):
			return true
	return false


func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton or ev is InputEventScreenTouch:
		if ev.is_pressed():
			set_on(false)
		return
	if ev is InputEventJoypadButton and ev.is_pressed():
		var was := on
		set_on(true)
		if (ev as InputEventJoypadButton).button_index == JOY_BUTTON_START:
			_menu()
			get_viewport().set_input_as_handled()
		elif not was and (ev.is_action_pressed("ui_accept") or _is_move(ev)):
			get_viewport().set_input_as_handled()   # the press that woke the focus shows it: it does not also move it or press a button
		return
	if (ev is InputEventJoypadMotion or ev is InputEventKey) and _is_move(ev) and not on:
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return   # arrows in a text box move its caret
		set_on(true)
		get_viewport().set_input_as_handled()   # the first move shows where the focus is; the next one moves it


func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel"):
		app.go_back()
		get_viewport().set_input_as_handled()


## Start: the menu, or away with it.
func _menu() -> void:
	for c in app.current.get_children():
		if c is MenuPanel and not c.is_queued_for_deletion():
			app.go_back()
			return
	app.open_menu()
