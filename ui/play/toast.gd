## Toasts: short news that stacks at a screen corner and fades, instead of a box that has to be dismissed. The sandbox screen feeds one
## from every line it would have put in its status strip (its `last_line`), and any screen may add a layer with `Toast.attach(host)` and say
## things to it. At most `max_visible` are up; a new one pushes the oldest out. Every line, shown or not, is kept in `history` (the
## journal pane lists it). Reduced motion shows a toast without sliding it in. Sizes and times are in data/ui/menus.json. Rendering only.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const UiSkin := preload("res://ui/play/ui_skin.gd")
const MenuKit := preload("res://ui/play/menu_kit.gd")

## What has been said, oldest first: {text, kind, ms}. Shared by every layer, kept for the session.
static var history: Array = []

var _shown: Array = []   # {node, born (seconds), text}
var _clock := 0.0
var _last_text := ""
var _last_at := -100.0


## Adds a toast layer over `host` (it ignores the mouse, so nothing under it is blocked) and returns it.
static func attach(host: Control) -> Control:
	var t: Control = load("res://ui/play/toast.gd").new()
	host.add_child(t)
	return t


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 30   # above the panes and popups: news is never hidden by the thing it is about
	set_process(true)


## Says `text`. `kind`: "news" (the default), "good" or "bad" (the border's colour). The same line twice in a row within
## `repeat_seconds` is told once.
func say(text: String, kind: String = "news") -> void:
	text = text.strip_edges()
	if text == "":
		return
	var now := Time.get_ticks_msec() / 1000.0
	if text == _last_text and now - _last_at < float(MenuKit.toast("repeat_seconds")):
		return
	_last_text = text
	_last_at = now
	history.append({"text": text, "kind": kind, "ms": Time.get_ticks_msec()})
	var cap := int(MenuKit.toast("history_max"))
	while history.size() > cap:
		history.pop_front()
	var node := _make(text, kind)
	add_child(node)
	_shown.append({"node": node, "born": _clock, "text": text})
	while _shown.size() > int(MenuKit.toast("max_visible")):
		var old: Dictionary = _shown.pop_front()
		(old["node"] as Node).queue_free()
	_place(true)


## The toasts on screen now, oldest first (their lines).
func lines() -> Array:
	return _shown.map(func(s): return s["text"])


func count() -> int:
	return _shown.size()


func _make(text: String, kind: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var edge := Kit.good() if kind == "good" else (Kit.bad() if kind == "bad" else Kit.ACCENT)
	if UiSkin.screen_active(self):
		p.add_theme_stylebox_override("panel", UiSkin.plate_box())
	else:
		p.add_theme_stylebox_override("panel", Kit.style(Color(0.10, 0.09, 0.16, 0.92), 6, edge))
	p.custom_minimum_size.x = minf(float(MenuKit.toast("width")), maxf(160.0, UiSettings.room(self).x - 2.0 * float(MenuKit.toast("margin"))))
	var l := Kit.label(text, int(MenuKit.toast("font_size")), Kit.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	p.set_meta("toast_kind", kind)
	return p


## The toasts stacked down from the top-right corner, newest at the bottom. `fresh`: the newest slides in from the edge.
func _place(fresh: bool) -> void:
	var margin := float(MenuKit.toast("margin"))
	var y := float(MenuKit.toast("top"))
	for i in _shown.size():
		var n: Control = _shown[i]["node"]
		n.size = Vector2(n.custom_minimum_size.x, 0)
		var w := n.custom_minimum_size.x
		var x := size.x - w - margin
		n.position.y = y
		if not n.has_meta("sliding"):
			n.position.x = x
		if fresh and i == _shown.size() - 1 and UiSettings.motion_time(1.0) > 0.0:
			n.set_meta("sliding", true)
			n.position.x = x + float(MenuKit.toast("slide_px"))
			n.modulate.a = 0.0
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(n, "position:x", x, UiSettings.motion_time(0.18))
			tw.tween_property(n, "modulate:a", 1.0, UiSettings.motion_time(0.18))
			tw.finished.connect(func():
				if is_instance_valid(n):
					n.remove_meta("sliding"))
		y += maxf(n.get_combined_minimum_size().y, n.size.y) + float(MenuKit.toast("gap"))


func _process(delta: float) -> void:
	_clock += delta
	var life := float(MenuKit.toast("seconds"))
	var fade := maxf(0.01, UiSettings.motion_time(float(MenuKit.toast("fade_seconds"))))   # reduced motion: gone at once, no fade
	var gone := false
	for s in _shown.duplicate():
		var age: float = _clock - float(s["born"])
		var n: Control = s["node"]
		if age >= life + fade:
			n.queue_free()
			_shown.erase(s)
			gone = true
		elif age >= life:
			n.modulate.a = 1.0 - (age - life) / fade
	if gone:
		_place(false)
	elif not _shown.is_empty():
		_place(false)   # a line that wrapped to another row moves the ones under it
