## The fishing panel (see GameFishing; data/world/fishing.json), opened over the open world by Use at a bank, the Fish key, the thing menu on
## water or the Use button of a rod in the pack: the world waits while it is open. A bobber on the water, a bite after a keyed wait, then one
## input (a click, a tap or Space) to reel in when the marker of the timing bar is in the green. With "No timing when fishing" (or reduced
## motion) there is no bar: after the wait the fish always comes in. A miss costs only the bait. Nothing here computes a result: GameFishing
## gives the wait, the fish, the size and the zone, and `land` puts the catch in the pack, the stores and the record book.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const PanelSkin := preload("res://ui/play/panel_skin.gd")
const ItemIcon := preload("res://ui/play/item_icon.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const WIDE := 520.0
const SCENE_H := 150.0
const SCENE_H_COMPACT := 110.0

var dynasty: GameDynasty
var spot: Dictionary = {}              # the water fished: {x, z, body}
var on_change := Callable()            # func(): a catch changed the pack, the stores or the book; the screen saves and redraws
var stage := "ready"                   # ready (rod in hand), wait (the bobber floats), bite (the bar runs), done (a line says how it went)
var easy := false                      # no timing: the fish always comes in
var line := ""                         # what the last cast came to
var t := 0.0                           # seconds since the cast (wait) or the bite (bite)
var wait := 0.0                        # seconds the bite takes to come
var got: Dictionary = {}               # the fish on the line: GameFishing.bite
var zone := 0.5                        # the green zone's centre on the bar (0 to 1)
var landed: Dictionary = {}            # the last catch's result (GameFishing.land)
var _used_bait := false
var _column := WIDE
var _scene: Control
var _info: Label
var _said: Label
var _cast_button: Button
var _reel_button: Button


func _ready() -> void:
	var v := Kit.overlay(self, "Fishing")
	set_meta("modal", true)
	easy = UiSettings.access_on("easy_fishing") or UiSettings.reduced_motion()
	_column = minf(WIDE, Kit.overlay_room(self) - 16.0)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(_column, 0)
	box.add_theme_constant_override("separation", 10)
	v.add_child(box)
	_info = _wrapped("", 15, Kit.dim())
	_info.name = "Info"
	box.add_child(_info)
	_scene = Control.new()
	_scene.name = "Scene"
	_scene.custom_minimum_size = Vector2(_column, SCENE_H_COMPACT if UiSettings.compact(self) else SCENE_H)
	_scene.mouse_filter = Control.MOUSE_FILTER_STOP
	_scene.draw.connect(_paint)
	_scene.gui_input.connect(_scene_input)
	box.add_child(_scene)
	_said = _wrapped("", 15, Kit.ACCENT)
	_said.name = "Said"
	box.add_child(_said)
	_reel_button = PanelSkin.button(self, GameFishing.text("reel"), func(): tap(), Vector2(_column, 48))
	_reel_button.name = "Reel"
	box.add_child(_reel_button)
	_cast_button = PanelSkin.button(self, GameFishing.text("cast_again"), func(): cast(), Vector2(_column, 48))
	_cast_button.name = "Cast"
	box.add_child(_cast_button)
	var close := PanelSkin.button(self, GameFishing.text("close"), func(): queue_free(), Vector2(_column, 48))
	close.name = "Close"
	box.add_child(close)
	_refresh()


func _wrapped(text: String, size: int, color: Color) -> Label:
	var l := PanelSkin.label(self, text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


# ---------------------------------------------------------------- the rules of one cast

## Casts the line: takes a bait if the pack has one, keys the wait and the fish on the cast number. False when the heir cannot (no rod).
func cast() -> bool:
	if stage in ["wait", "bite"] or dynasty == null or GameFishing.rod_count(dynasty.heir) <= 0:
		return false
	_used_bait = GameFishing.take_bait(dynasty.heir)
	var no := GameFishing.cast_number(dynasty)
	dynasty.fishing_casts += 1
	wait = GameFishing.wait_seconds(dynasty, spot, no, _used_bait)
	if easy:
		wait += float(GameFishing.setting("no_timing_extra_wait"))
	got = GameFishing.bite(dynasty, spot, no, _used_bait)
	zone = GameFishing.zone_centre(dynasty, spot, no)
	t = 0.0
	stage = "wait"
	line = GameFishing.text("cast_bait" if _used_bait else "cast", {"heir": dynasty.heir.name, "water": GameFishing.water_name(str(spot["body"]))})
	if on_change.is_valid():
		on_change.call()   # the bait has gone from the pack
	_refresh()
	return true


## Time passes `delta` seconds: the wait runs down to the bite, and then the bar's marker runs.
func step(delta: float) -> void:
	if stage == "wait":
		t += delta
		if t >= wait:
			if got.is_empty():
				line = GameFishing.text("missed_free")
				stage = "done"
			elif easy:
				_land()
			else:
				stage = "bite"
				t = 0.0
				line = GameFishing.text("bite")
			_refresh()
	elif stage == "bite":
		t += delta
	if stage in ["wait", "bite"]:
		_scene.queue_redraw()


## The one input: casts when the rod is in hand, reels in when something bites. True when it did something.
func tap() -> bool:
	if stage == "bite":
		if GameFishing.hits(GameFishing.marker(t), zone, GameFishing.zone_width(dynasty)):
			_land()
		else:
			line = GameFishing.text("missed" if _used_bait else "missed_free")
			stage = "done"
			_refresh()
		return true
	if stage in ["ready", "done"]:
		return cast()
	return false


func _land() -> void:
	landed = GameFishing.land(dynasty, got)
	line = str(landed["text"])
	stage = "done"
	if on_change.is_valid():
		on_change.call()
	_refresh()


# ---------------------------------------------------------------- what is drawn

func _process(delta: float) -> void:
	if stage in ["wait", "bite"]:
		step(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		tap()


func _scene_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		tap()


func _refresh() -> void:
	if _info == null:
		return
	var bait := GameFishing.bait_count(dynasty.heir)
	var lv := GameFishing.level(dynasty)
	var head := "%s  |  Angler: %s (%d)  |  %s" % [GameFishing.water_name(str(spot.get("body", ""))).left(1).to_upper() + GameFishing.water_name(str(spot.get("body", ""))).substr(1), GameFishing.level_name(lv), lv,
		GameFishing.text("bait_left", {"n": bait}) if bait > 0 else GameFishing.text("no_bait")]
	_info.text = head
	var hint := ""
	match stage:
		"wait":
			hint = GameFishing.text("waiting")
		"bite":
			hint = GameFishing.text("bite") + " " + GameFishing.text("tap_to_reel")
		"ready":
			hint = GameFishing.text("easy_reel") if easy else GameFishing.text("tap_to_reel")
	_said.text = line if hint == "" else ("%s\n%s" % [line, hint] if line != "" else hint)
	_reel_button.visible = stage == "bite"
	_cast_button.visible = stage in ["ready", "done"]
	_cast_button.text = GameFishing.text("cast_again") if stage == "done" else GameFishing.text("cast")
	_cast_button.disabled = GameFishing.rod_count(dynasty.heir) <= 0
	_scene.queue_redraw()


## The water, the bobber, and while a fish is on, the timing bar. The bobber bobs unless reduced motion is on; the zone is green by colour
## and by a solid frame, so it reads without colour.
func _paint() -> void:
	var w := _scene.size.x
	var h := _scene.size.y
	var body := str(spot.get("body", "lake"))
	var water := Color(0.12, 0.27, 0.42)
	var sky := Color(0.55, 0.68, 0.8).darkened(0.35 if GameDay.is_night(dynasty) else 0.0)
	_scene.draw_rect(Rect2(0, 0, w, h * 0.3), sky)
	_scene.draw_rect(Rect2(0, h * 0.3, w, h * 0.7), water.lightened(0.1 if body != "sea" else 0.0))
	for i in 5:   # a few still ripples on the water
		var y := h * (0.42 + 0.1 * float(i))
		_scene.draw_line(Vector2(w * (0.1 + 0.07 * float(i % 3)), y), Vector2(w * (0.3 + 0.07 * float(i % 3)), y), water.lightened(0.25), 1.0)
	if stage == "done" and not landed.is_empty() and line == str(landed.get("text", "")):   # the catch, held up over the water
		var s := 56.0
		_scene.draw_texture_rect(ItemIcon.texture(str(got.get("item", ""))), Rect2(w * 0.5 - s * 0.5, h * 0.5 - s * 0.5, s, s), false)
		return
	var phase := 0.0 if UiSettings.reduced_motion() else float(Time.get_ticks_msec()) / 1000.0
	var bob := sin(phase * 3.0) * 2.0
	var cx := w * 0.5
	var cy := h * 0.5 + bob
	if stage == "bite":
		cy += 7.0 + (sin(phase * 14.0) * 2.0 if not UiSettings.reduced_motion() else 0.0)   # the bobber is pulled under
		_scene.draw_arc(Vector2(cx, cy), 14.0, 0.0, TAU, 20, Color(1, 1, 1, 0.7), 2.0)
	_scene.draw_line(Vector2(cx, cy - 6), Vector2(w * 0.9, -4.0), Color(0.9, 0.9, 0.85, 0.8), 1.0)   # the line back to the rod
	_scene.draw_circle(Vector2(cx, cy), 6.0, Color(0.9, 0.2, 0.2))
	_scene.draw_circle(Vector2(cx, cy - 2.0), 3.5, Color(0.97, 0.97, 0.97))
	if stage == "bite":
		var bw := w * 0.84
		var bx := (w - bw) * 0.5
		var by := h - 26.0
		_scene.draw_rect(Rect2(bx, by, bw, 14.0), Color(0.08, 0.07, 0.11, 0.85))
		var zw := GameFishing.zone_width(dynasty) * bw
		var zx := bx + zone * bw - zw * 0.5
		_scene.draw_rect(Rect2(zx, by, zw, 14.0), Kit.good())
		_scene.draw_rect(Rect2(zx, by, zw, 14.0), Color(1, 1, 1, 0.9), false, 2.0)
		var mx := bx + GameFishing.marker(t) * bw
		_scene.draw_rect(Rect2(mx - 2.0, by - 5.0, 4.0, 24.0), Color(1, 1, 1))
