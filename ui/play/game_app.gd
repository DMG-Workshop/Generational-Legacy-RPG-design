## Root of the playable game: owns the dynasty and swaps screens. Screens sit inside `frame`, which
## keeps clear of a phone's notch and rounded corners; the touch-hint helper and the app's
## lifecycle (save on pause, Android back) live here too.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const TouchHint := preload("res://ui/play/touch_hint.gd")
const MenuPanel := preload("res://ui/play/menu_panel.gd")
const TitleScreen := preload("res://ui/play/title_screen.gd")
const LifeScreen := preload("res://ui/play/life_screen.gd")
const BattleView := preload("res://ui/play/battle_view.gd")
const SuccessionScreen := preload("res://ui/play/succession_screen.gd")
const EndingScreen := preload("res://ui/play/ending_screen.gd")

var dynasty: GameDynasty
var current: Control
var bg: ColorRect
var frame: Control
var hints: Node
var safe_override := Rect2i()   # tests and screenshots: a pretend safe area, in window pixels
var _safe_seen := Rect2i()
var _safe_check := 0.0


func _ready() -> void:
	GameData.load_all()
	UiSettings.apply(get_window())
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg = ColorRect.new()
	bg.color = Kit.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	frame = Control.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	hints = TouchHint.new()
	add_child(hints)
	get_viewport().size_changed.connect(apply_safe_area)
	apply_safe_area()
	show_title()


## Insets the screens by the display's safe area (phones only, where the game fills the screen; a
## desktop window has none).
func apply_safe_area() -> void:
	var win := get_window()
	var safe := safe_override
	if safe.size == Vector2i.ZERO:
		safe = DisplayServer.get_display_safe_area() if UiSettings.is_mobile() else Rect2i()
	_safe_seen = safe
	var m := Rect2()
	if safe.size.x > 0 and safe.size.y > 0 and win.size.x > 0:
		var to_ui := get_viewport_rect().size.x / float(win.size.x)
		var left := maxf(0.0, float(safe.position.x))
		var top := maxf(0.0, float(safe.position.y))
		var right := maxf(0.0, float(win.size.x - safe.end.x))
		var bottom := maxf(0.0, float(win.size.y - safe.end.y))
		m = Rect2(Vector2(left, top) * to_ui, Vector2(right, bottom) * to_ui)
	UiSettings.insets = m
	frame.offset_left = m.position.x
	frame.offset_top = m.position.y
	frame.offset_right = -m.size.x
	frame.offset_bottom = -m.size.y


## Turning a phone end over moves the notch to the other side without resizing the window.
func _process(delta: float) -> void:
	if not UiSettings.is_mobile() or safe_override.size != Vector2i.ZERO:
		return
	_safe_check += delta
	if _safe_check >= 0.5:
		_safe_check = 0.0
		if DisplayServer.get_display_safe_area() != _safe_seen:
			apply_safe_area()


func _swap(screen: Control) -> void:
	hints.hide_hint()
	if current != null:
		frame.remove_child(current)
		current.queue_free()
	current = screen
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(screen)


func show_title() -> void:
	var s := TitleScreen.new()
	s.app = self
	_swap(s)


func new_game(p_name: String, class_id: String, bloodline: String, p_seed: int, race_id: String = "human") -> void:
	dynasty = GameDynasty.new_game(p_seed, p_name, class_id, bloodline, race_id)
	dynasty.save_to_disk()
	show_state()


func continue_game() -> void:
	var d := GameDynasty.load_from_disk()
	if d == null:
		return
	dynasty = d
	show_state()


## Show the screen that matches the dynasty's current state.
func show_state() -> void:
	if dynasty.battle != null:
		var b := BattleView.new()
		b.app = self
		_swap(b)
	elif dynasty.state == "succession":
		var s := SuccessionScreen.new()
		s.app = self
		_swap(s)
	elif dynasty.state == "ended":
		var e := EndingScreen.new()
		e.app = self
		_swap(e)
	else:
		var l := LifeScreen.new()
		l.app = self
		_swap(l)


func autosave() -> void:
	if dynasty != null:
		dynasty.save_to_disk()


# ---------------------------------------------------------------- menu and UI scale

func menu_mode() -> String:
	if current is TitleScreen or dynasty == null:
		return "title"
	return "battle" if dynasty.battle != null else "game"


func open_menu() -> Control:
	var m: Control = MenuPanel.new()
	m.app = self
	current.add_child(m)
	return m


func set_ui_scale(s: float) -> void:
	UiSettings.set_scale(s)
	UiSettings.apply(get_window())
	apply_safe_area()
	# A fight is laid out again in place (rebuilding it would lose its log); other screens are
	# rebuilt at the new size.
	if menu_mode() == "battle":
		current.relayout()
		for c in current.get_children():
			if c is MenuPanel:
				c.queue_free()
	elif menu_mode() == "title":
		show_title()
	else:
		show_state()
	open_menu()


# ---------------------------------------------------------------- lifecycle

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			autosave()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if UiSettings.is_mobile():
				autosave()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			go_back()


## Android's back button: drop a hint, step back inside the screen (an aim, a spell list), close
## the topmost panel, or else open the menu. It never quits the game.
func go_back() -> String:
	if hints.is_showing():
		hints.hide_hint()
		return "hint"
	if current.has_method("back") and current.back():
		return "screen"
	var top := _top_closable(current)
	if top != null:
		(top.get_meta("back_close") as Callable).call()
		return "closed"
	open_menu()
	return "menu"


## The last-opened panel that the back button may close, the innermost when panels open panels.
func _top_closable(n: Node) -> Control:
	for i in range(n.get_child_count() - 1, -1, -1):
		var c := n.get_child(i)
		if not (c is Control) or c.is_queued_for_deletion() or not (c as Control).visible:
			continue
		var inner := _top_closable(c)
		if inner != null:
			return inner
		if c.has_meta("back_close"):
			return c
		if c.has_meta("modal"):   # waits for an answer: back opens the menu over it instead
			return null
	return null
