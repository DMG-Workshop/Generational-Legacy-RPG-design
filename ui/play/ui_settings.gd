## Player settings kept apart from the dynasty save, in user://settings.cfg: the UI scale (applied
## as the window's content scale, so every screen grows together) and the touch layout (Auto, the
## default, lays out for fingers on phones and tablets only). Tunables live in data/ui/mobile.json.
extends RefCounted

static var path := "user://settings.cfg"
static var scale := -1.0         # -1 until read from disk
static var touch_layout := ""    # "auto", "on" or "off"; "" until read from disk
static var force_touch := -1     # 1 or 0 overrides touch detection (tests, screenshots)
static var force_mobile := -1    # 1 or 0 overrides OS.has_feature("mobile") (tests, screenshots)
static var force_touchscreen := -1   # 1 or 0 overrides DisplayServer.is_touchscreen_available() (tests)
static var insets := Rect2()     # safe-area margins of the root UI: position = left/top, size = right/bottom


static func setting(key: String) -> Variant:
	return GameData.mobile["settings"][key]


static func scales() -> Array:
	return (setting("ui_scales") as Array).map(func(s): return float(s))


static func is_mobile() -> bool:
	return force_mobile == 1 if force_mobile >= 0 else OS.has_feature("mobile")


static func default_scale() -> float:
	return float(setting("default_scale_mobile" if is_mobile() else "default_scale_desktop"))


## The listed scale closest to `s`: a hand-edited or stale file cannot set an unlisted one.
static func nearest(s: float) -> float:
	var best := default_scale()
	for v in scales():
		if absf(v - s) < absf(best - s):
			best = v
	return best


## Both settings read again from the file (each is also read on its own when first wanted).
static func load_settings() -> void:
	scale = -1.0
	touch_layout = ""
	get_scale()
	get_touch_layout()


## One saved value, or `fallback` without a file or the key.
static func stored(key: String, fallback: Variant) -> Variant:
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return fallback
	return cf.get_value("ui", key, fallback)


## One value written to the file, keeping the rest.
static func store(key: String, value: Variant) -> bool:
	var cf := ConfigFile.new()
	cf.load(path)
	cf.set_value("ui", key, value)
	return cf.save(path) == OK


static func save_settings() -> bool:
	var cf := ConfigFile.new()
	cf.load(path)
	cf.set_value("ui", "scale", get_scale())
	cf.set_value("ui", "touch_layout", get_touch_layout())
	return cf.save(path) == OK


static func get_scale() -> float:
	if scale < 0.0:
		scale = nearest(float(stored("scale", default_scale())))
	return scale


static func set_scale(s: float) -> void:
	scale = nearest(s)
	save_settings()


static func apply(win: Window) -> void:
	win.content_scale_factor = get_scale()


static func touch_layouts() -> Array:
	return ["auto", "on", "off"]


static func get_touch_layout() -> String:
	if touch_layout == "":
		var t := str(stored("touch_layout", "auto"))   # files from before the setting have no key
		touch_layout = t if t in touch_layouts() else "auto"
	return touch_layout


static func set_touch_layout(t: String) -> void:
	touch_layout = t if t in touch_layouts() else "auto"
	save_settings()


## Laid out for fingers: bigger buttons and "tap" / "hold" in the help text. Auto means phones and
## tablets only: a laptop with a touch screen keeps the desktop layout unless the player turns it on
## (its long-press hints work either way, see TouchHint).
static func touch() -> bool:
	if force_touch >= 0:
		return force_touch == 1
	match get_touch_layout():
		"on":
			return true
		"off":
			return false
	return is_mobile()


## A finger can reach the screen, whatever the layout.
static func touch_screen() -> bool:
	if is_mobile():
		return true
	return force_touchscreen == 1 if force_touchscreen >= 0 else DisplayServer.is_touchscreen_available()


## The least height a button may have: a fingertip on touch screens, as designed elsewhere.
static func tap_h(h: float) -> float:
	return maxf(h, float(setting("touch_target_px"))) if touch() else h


## The room the screens have, in UI units: the window at the current scale, less the safe area.
static func room(n: CanvasItem) -> Vector2:
	return n.get_viewport_rect().size - insets.position - insets.size


## Too narrow for side-by-side columns at their full width.
static func compact(n: CanvasItem) -> bool:
	return room(n).x < float(setting("compact_width"))
