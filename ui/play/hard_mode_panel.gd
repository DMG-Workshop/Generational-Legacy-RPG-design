## The founder's hard-mode choices (see GameHardMode), opened from the title screen: whole-line permadeath and the
## iron-man save are switched on or off, and a generation cap is picked from the data's list or left off. Every
## name and line comes from data/game/hard_mode.json. The panel only keeps the choices and hands them back through
## `on_change`; the dynasty is founded with them by the title's Begin button. Nothing here computes a result.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")

var opts: Dictionary = {}
var on_change: Callable
var _body: VBoxContainer


func _ready() -> void:
	opts = opts.duplicate()
	var v := Kit.overlay(self, GameHardMode.text("panel_title"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_body)
	_build()


func _build() -> void:
	Kit.clear(_body)
	_body.add_child(_wrapped(GameHardMode.text("panel_note"), Kit.dim()))
	for key in [GameHardMode.PERMADEATH, GameHardMode.IRONMAN]:
		var on: bool = opts.get(key, false) == true
		var row := _row(key)
		_pick(row, GameHardMode.text("is_off"), not on, _choose.bind(key, false))
		_pick(row, GameHardMode.text("on"), on, _choose.bind(key, true))
	var cap := int(opts.get(GameHardMode.GEN_CAP, 0))
	var caps := _row(GameHardMode.GEN_CAP)
	_pick(caps, GameHardMode.text("no_cap"), cap == 0, _choose.bind(GameHardMode.GEN_CAP, 0))
	for c in GameHardMode.caps():
		_pick(caps, GameHardMode.text("cap_choice", {"cap": GameText.num(c)}), cap == c, _choose.bind(GameHardMode.GEN_CAP, c))
	var done := Kit.button(GameHardMode.text("close"), func(): queue_free(), Vector2(0, 0))
	done.custom_minimum_size.y = UiSettings.tap_h(0)
	_body.add_child(done)


## An option's name and what it does, with the row its choices go in.
func _row(key: String) -> HFlowContainer:
	_body.add_child(Kit.label(GameHardMode.option_name(key), 17, Kit.ACCENT))
	_body.add_child(_wrapped(GameHardMode.option_about(key), Kit.TEXT))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(row)
	return row


## One of a row of choices, the one in use marked.
func _pick(row: Control, text: String, on: bool, cb: Callable) -> void:
	var b := Kit.button(("> " if on else "") + text, cb, Vector2(130, 0))
	b.custom_minimum_size.y = UiSettings.tap_h(0)
	b.set_meta("chosen", on)
	row.add_child(b)


func _wrapped(text: String, color: Color) -> Label:
	var l := Kit.label(text, 14, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _choose(key: String, value: Variant) -> void:
	opts[key] = value
	opts = (GameHardMode.choices(opts)["hard"] as Dictionary).duplicate()   # only what is on is kept
	if on_change.is_valid():
		on_change.call(opts.duplicate())
	_build()
