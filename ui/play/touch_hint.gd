## Touch screens have no hover. Holding a finger still on anything that has a tooltip or a hover
## preview shows it, in a bubble by the finger, and that touch is not a click. A quick tap still
## clicks and a drag scrolls the list under the finger. Mouse input is left alone, so the desktop
## keeps its tooltips and hover exactly as before. One instance lives on the game's root. It works
## on any screen that sends touches, whatever the touch layout setting says.
##
## Godot moves its emulated mouse with the finger (Input.emulate_mouse_from_touch; those events carry
## InputEvent.DEVICE_ID_EMULATION). A tap's emulated button enters the control under it and the
## pointer rests there after the lift, so the engine's own tooltip pops up as soon as a resting
## motion reaches it: Viewport.update_mouse_cursor_state sends one (device DEVICE_ID_INTERNAL, which
## no script's _input sees) after a cursor change or a drag, even while the finger is still down.
## So while a finger has the pointer the engine's tooltip popup (a PopupPanel of theme type
## TooltipPanel) is freed the moment it enters the tree, before it is ever drawn, and hover
## previews are not played on enter: only the long-press bubble shows. The emulated events still
## reach the GUI, so taps click and ScrollContainer drags with the finger.
##
## Screens register hover previews through on_hover() instead of connecting mouse_entered and
## mouse_exited themselves, so a long press can play them too.
extends Node

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const META := "touch_hover"
const MOUSE_IN := "touch_hover_mouse_in"

static var finger := false    # the pointer was last moved by a finger, not a mouse

var layer: CanvasLayer
var bubble: PanelContainer
var text: Label
var shown_text := ""          # what the bubble says while it is up
var shown_on: Control = null  # the control whose tooltip or preview it shows

var _down := false
var _start := Vector2.ZERO
var _held := 0.0
var _target: Control = null
var _shown := false
var _linger := 0.0
var _exit := Callable()
var _scroll: ScrollContainer = null
var _scrolling := false
var _scroll_from := Vector2.ZERO


## Hover preview for `c`: the mouse plays it on enter and exit, a long press on touch screens. An
## enter made by a finger's emulated mouse plays nothing, and only an enter that played has its exit.
static func on_hover(c: Control, enter: Callable, exit: Callable = Callable()) -> void:
	c.mouse_entered.connect(func():
		if not finger:
			c.set_meta(MOUSE_IN, true)
			enter.call())
	if exit.is_valid():
		c.mouse_exited.connect(func():
			if c.get_meta(MOUSE_IN, false):
				c.set_meta(MOUSE_IN, false)
				exit.call())
	c.set_meta(META, [enter, exit])


## Who has the pointer, from the window's raw events: they come before the viewport updates hover.
## Emulated mouse events are a finger's; touches the engine emulates from a mouse are the mouse's.
static func note_pointer(ev: InputEvent) -> void:
	if ev is InputEventMouse:
		finger = ev.device == InputEvent.DEVICE_ID_EMULATION
	elif (ev is InputEventScreenTouch or ev is InputEventScreenDrag) and ev.device != InputEvent.DEVICE_ID_EMULATION:
		finger = true


func _ready() -> void:
	layer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	bubble = PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", Kit.style(Color("#0f0e17"), 6, Kit.ACCENT))
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.visible = false
	layer.add_child(bubble)
	text = Kit.label("", int(UiSettings.setting("hint_font_size")))
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(text)
	get_window().window_input.connect(note_pointer)
	get_tree().node_added.connect(_on_node_added)


## The engine's tooltip, popped up by a finger's resting pointer: gone before it is drawn (the
## viewport forgets it when it is freed). The mouse's tooltips are left alone.
func _on_node_added(n: Node) -> void:
	if finger and n is PopupPanel and (n as Window).theme_type_variation == &"TooltipPanel":
		n.queue_free()


func is_showing() -> bool:
	return _shown


func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		var st := ev as InputEventScreenTouch
		if st.index != 0:
			_cancel_hold()
			return
		if st.pressed:
			hide_hint()
			_down = true
			_start = st.position
			_held = 0.0
			_scrolling = false
			_target = pick(st.position)
			_scroll = _scroll_of(_target)
		else:
			_down = false
			_scrolling = false
			_linger = float(UiSettings.setting("hint_linger_seconds"))
	elif ev is InputEventScreenDrag and _down and not _shown:
		var sd := ev as InputEventScreenDrag
		if sd.index != 0:
			return
		var moved := sd.position - _start
		if not _scrolling and moved.length() > float(UiSettings.setting("hold_slop_px")):
			_begin_scroll()
		if _scrolling:
			_drag_scroll(moved)


func _process(delta: float) -> void:
	tick(delta)


## Time passes for the hold and the bubble (tests call this directly).
func tick(delta: float) -> void:
	if _down and not _shown and not _scrolling and _target != null and is_instance_valid(_target):
		_held += delta
		if _held >= float(UiSettings.setting("hold_seconds")):
			_trigger()
	elif _shown and not _down:
		_linger -= delta
		# Gone with what it describes: a closed list, a rebuilt panel.
		if _linger <= 0.0 or not is_instance_valid(shown_on) or not shown_on.is_visible_in_tree():
			hide_hint()


## A second finger: a pinch or a slip, neither a hold nor a click.
func _cancel_hold() -> void:
	if _down and _target != null and is_instance_valid(_target) and not _shown:
		_cancel_press(_target)
	_down = false
	_target = null


func _trigger() -> void:
	var tip := tooltip_at(_target, _start)
	var hover := _hover_of(_target)
	if tip["text"] == "" and hover.is_empty():
		_target = null
		return
	_cancel_press(_target)
	if not hover.is_empty():
		(hover[0] as Callable).call()
		_exit = hover[1]
	_shown = true
	shown_on = tip["owner"] if tip["owner"] != null else _target
	shown_text = tip["text"]
	if shown_text != "":
		_show_bubble(shown_text, _start)


## Takes the hint down and ends the preview it started.
func hide_hint() -> void:
	if _exit.is_valid():
		var ex := _exit
		_exit = Callable()
		ex.call()
	_shown = false
	shown_text = ""
	shown_on = null
	if bubble != null:
		bubble.visible = false


func _show_bubble(s: String, at: Vector2) -> void:
	text.text = s
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	var w := float(UiSettings.setting("hint_max_width"))
	if text.get_minimum_size().x > w:
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(w, 0)
	else:
		text.custom_minimum_size = Vector2.ZERO
	bubble.visible = true
	bubble.modulate.a = 0.0
	bubble.reset_size()
	_place.call_deferred(at)


## Placed once laid out: a wrapped label only knows its height after it has its width.
func _place(at: Vector2) -> void:
	await get_tree().process_frame
	if not _shown:
		return
	bubble.reset_size()
	bubble.modulate.a = 1.0
	var room := Rect2(UiSettings.insets.position, UiSettings.room(bubble))
	var finger := 40.0   # clear of the fingertip
	var pos := at - Vector2(bubble.size.x * 0.5, bubble.size.y + finger)
	if pos.y < room.position.y:
		pos.y = at.y + finger
	pos.x = clampf(pos.x, room.position.x + 4.0, maxf(room.position.x + 4.0, room.end.x - bubble.size.x - 4.0))
	pos.y = clampf(pos.y, room.position.y + 4.0, maxf(room.position.y + 4.0, room.end.y - bubble.size.y - 4.0))
	bubble.position = pos


# ---------------------------------------------------------------- finding what is under the finger

## The control the GUI would hand a click at `pos`: topmost by tree order, inside its clipping
## parents, skipping hidden ones and those that let the mouse through.
func pick(pos: Vector2) -> Control:
	return _pick_in(get_tree().root, pos)


func _pick_in(n: Node, pos: Vector2) -> Control:
	for i in range(n.get_child_count() - 1, -1, -1):
		var c := n.get_child(i)
		if c is Window or c == layer:
			continue
		if c is CanvasLayer and not (c as CanvasLayer).visible:
			continue
		if c is Control:
			if not (c as Control).visible:
				continue
			var hit := _pick_control(c, pos)
			if hit != null:
				return hit
		elif not (c is CanvasItem) or (c as CanvasItem).visible:
			var h := _pick_in(c, pos)
			if h != null:
				return h
	return null


func _pick_control(c: Control, pos: Vector2) -> Control:
	var local := c.get_global_transform_with_canvas().affine_inverse() * pos
	var inside := Rect2(Vector2.ZERO, c.size).has_point(local)
	if c.clip_contents and not inside:
		return null
	for i in range(c.get_child_count() - 1, -1, -1):
		var ch := c.get_child(i)
		if ch is Control and (ch as Control).visible:
			var hit := _pick_control(ch, pos)
			if hit != null:
				return hit
	if inside and c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return c
	return null


## The tooltip the mouse would show over `c` at `pos`, and the control it belongs to: the first
## one up the parents that has a tooltip, stopping where the mouse would stop.
static func tooltip_at(c: Control, pos: Vector2) -> Dictionary:
	while c != null:
		var local := c.get_global_transform_with_canvas().affine_inverse() * pos
		var tip := c.get_tooltip(local)
		if tip != "":
			return {"text": tip, "owner": c}
		if c.mouse_filter == Control.MOUSE_FILTER_STOP or c.top_level:
			break
		c = c.get_parent_control()
	return {"text": "", "owner": null}


func _hover_of(c: Control) -> Array:
	while c != null:
		if c.has_meta(META):
			return c.get_meta(META)
		if c.mouse_filter == Control.MOUSE_FILTER_STOP or c.top_level:
			break
		c = c.get_parent_control()
	return []


## A long press or a drag is not a click: the button under the finger forgets it was pressed.
func _cancel_press(c: Control) -> void:
	while c != null:
		if c is BaseButton:
			var b := c as BaseButton
			if not b.disabled:
				b.disabled = true
				b.disabled = false
			return
		if c.mouse_filter == Control.MOUSE_FILTER_STOP:
			return
		c = c.get_parent_control()


# ---------------------------------------------------------------- drag to scroll

func _scroll_of(c: Control) -> ScrollContainer:
	while c != null:
		if c is ScrollContainer:
			return c
		c = c.get_parent_control()
	return null


## A ScrollContainer drags itself on touch screens when the touch reaches it; buttons and cards in
## between stop the touch, so those drags are scrolled here.
func _native_scroll() -> bool:
	if not DisplayServer.is_touchscreen_available():
		return false
	var c := _target
	while c != null and c != _scroll:
		if c.mouse_filter == Control.MOUSE_FILTER_STOP:
			return false
		c = c.get_parent_control()
	return true


func _begin_scroll() -> void:
	_held = 0.0
	if _scroll == null or not is_instance_valid(_scroll) or _native_scroll():
		_target = null
		return
	_scrolling = true
	_cancel_press(_target)
	_scroll_from = Vector2(_scroll.scroll_horizontal, _scroll.scroll_vertical)


func _drag_scroll(moved: Vector2) -> void:
	if _scroll == null or not is_instance_valid(_scroll):
		return
	if _scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		_scroll.scroll_vertical = int(round(_scroll_from.y - moved.y))
	if _scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		_scroll.scroll_horizontal = int(round(_scroll_from.x - moved.x))
