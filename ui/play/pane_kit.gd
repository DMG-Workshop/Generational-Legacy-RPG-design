## Panes (docs/PLAYER_INTERFACE.md, slice 1; data/ui/pane.json): a panel that is opened over the open world on a desktop-sized
## window becomes a window of its own, with a title bar the player drags, raised when it is clicked and remembered where it
## was left (settings.cfg). `Kit.overlay` asks `available` and `build`, so the panels need no change: the sandbox screen marks
## the ones it opens with the meta `pane` (the name of the panel's script), and anywhere else, or on a narrow or touch
## screen, the panel is the full-screen overlay it always was. Rendering only: nothing here touches the dynasty.
extends RefCounted

const UiSettings := preload("res://ui/play/ui_settings.gd")
const WorldInput := preload("res://ui/play/world_input.gd")
const UiSkin := preload("res://ui/play/ui_skin.gd")
const PATH := "res://data/ui/pane.json"

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				_cache = parsed
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func color(key: String) -> Color:
	return Color(str(data()["colors"][key]))


## Whether a panel is shown as a pane: it asked to be (the meta `pane`) and the window is wide and has a mouse.
static func available(host: Control) -> bool:
	return host.has_meta("pane") and not UiSettings.compact(host) and not UiSettings.touch()


## The size of a pane: its own from the data or the default, cut to the room.
static func size_for(key: String, room: Vector2) -> Vector2:
	var raw: Variant = data()["sizes"].get(key, data()["settings"]["default_size"])
	var want := Vector2(float(raw[0]), float(raw[1]))
	var m := float(setting("margin"))
	return Vector2(minf(want.x, room.x - 2.0 * m), minf(want.y, room.y - 2.0 * m))


## The corner a pane is set in when it has never been moved, or null (the middle).
static func place_for(key: String, size: Vector2, room: Vector2) -> Variant:
	var pl: Variant = data().get("places", {}).get(key)
	if typeof(pl) != TYPE_ARRAY or (pl as Array).size() != 4:
		return null
	var x := float(pl[2]) if str(pl[0]) == "left" else room.x - size.x - float(pl[2])
	var y := float(pl[3]) if str(pl[1]) == "top" else room.y - size.y - float(pl[3])
	return Vector2(x, y)


## Whether a pane that stays up (the status, minimap and journal) is meant to be open: until the player closes it.
static func wanted(key: String) -> bool:
	return bool(UiSettings.stored("pane_open_" + _stored(key), true))


## A pane's key as a settings.cfg key (no colons or number signs).
static func _stored(key: String) -> String:
	return key.replace(":", "_").replace("#", "_")


## Remembers that a pane that stays up is wanted again (the Menu opens it).
static func want(key: String) -> void:
	UiSettings.store("pane_open_" + _stored(key), true)


## Closes a pane; one that stays up is remembered as closed.
static func close(host: Control) -> void:
	if host.has_meta("pane_hud"):
		UiSettings.store("pane_open_" + _stored(str(host.get_meta("pane"))), false)
	host.queue_free()


## Where a pane starts: where it was left, or centred and shifted a little for each pane already open.
static func start_position(host: Control, key: String, size: Vector2, room: Vector2, open: int) -> Vector2:
	var saved: Variant = UiSettings.stored("pane_" + _stored(key), [])
	var pos: Vector2
	if typeof(saved) == TYPE_ARRAY and (saved as Array).size() == 2 and (saved[0] is float or saved[0] is int) and (saved[1] is float or saved[1] is int):
		pos = Vector2(float(saved[0]), float(saved[1]))
	elif place_for(key.get_slice(":", 0), size, room) != null:
		pos = place_for(key.get_slice(":", 0), size, room)
	else:
		pos = (room - size) * 0.5 + Vector2(1, 1) * float(setting("cascade")) * float(open)
	return clamp_to(pos, size, room)


## Keeps a pane's title bar reachable: at least `keep_visible` pixels of it stay inside the room.
static func clamp_to(pos: Vector2, size: Vector2, room: Vector2) -> Vector2:
	var keep := float(setting("keep_visible"))
	return Vector2(clampf(pos.x, keep - size.x, room.x - keep), clampf(pos.y, 0.0, room.y - float(setting("title_height"))))


static func _box(color: Color, border: Color = Color(0, 0, 0, 0), width: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(6)
	if width > 0:
		s.border_color = border
		s.set_border_width_all(width)
	return s


## Builds the pane on `host` and returns its content box (as `Kit.overlay` does).
static func build(host: Control, title: String) -> VBoxContainer:
	var key := str(host.get_meta("pane"))   # the panel's name, and for a bag's pane ":" and the bag
	var base := key.get_slice(":", 0)
	var room := UiSettings.room(host)
	var size := size_for(base, room)
	var siblings := 0
	var parent := host.get_parent()
	if parent != null:
		for c in parent.get_children():
			if c != host and c.has_meta("pane") and not c.is_queued_for_deletion():
				siblings += 1
	host.set_anchors_preset(Control.PRESET_TOP_LEFT)
	host.size = size
	host.position = start_position(host, key, size, room, siblings)
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	host.set_meta("pane_room", size.x - 2.0 * float(setting("padding")) - 20.0)
	host.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			if ev.button_index == WorldInput.mouse_button("walk"):
				close(host)   # a click of the walk button (the right one, unless the player moved it) on a pane's face closes it
			else:
				host.move_to_front())   # a click anywhere on it raises it
	var skinned := UiSkin.active(host)   # parchment, ribbon and studs (data/ui/skin.json); the older dark look otherwise
	var face_kind := UiSkin.face_for(key)
	if skinned:
		host.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		host.add_child(UiSkin.shadow(host))
	var face := PanelContainer.new()
	face.add_theme_stylebox_override("panel", UiSkin.face_box(face_kind) if skinned else _box(color("face"), color("border"), 2))
	face.set_meta("skin_face", true)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_PASS
	host.add_child(face)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var pad := MarginContainer.new()
	for side in ["left", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, int(setting("padding")))
	pad.add_theme_constant_override("margin_top", 0)
	face.add_child(pad)
	pad.add_child(v)
	# the title bar: the handle the pane is dragged by
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UiSkin.ribbon_box() if skinned else _box(color("title_bar")))
	bar.custom_minimum_size = Vector2(0, float(setting("title_height")))
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.mouse_default_cursor_shape = Control.CURSOR_DRAG
	v.add_child(bar)
	var row := HBoxContainer.new()
	bar.add_child(row)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", color("title_text"))
	if skinned:
		UiSkin.dress_title(t)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(t)
	var x_button := Button.new()
	x_button.text = "X"
	x_button.focus_mode = Control.FOCUS_NONE
	x_button.custom_minimum_size = Vector2(36, 0)
	x_button.add_theme_color_override("font_color", color("close_text"))
	x_button.pressed.connect(func(): close(host))
	if skinned:
		UiSkin.dress_button(x_button)
	row.add_child(x_button)
	var drag := {"on": false}
	bar.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			drag["on"] = ev.pressed
			host.move_to_front()
			if not ev.pressed:
				UiSettings.store("pane_" + _stored(key), [host.position.x, host.position.y])
		elif ev is InputEventMouseMotion and drag["on"]:
			host.position = clamp_to(host.position + (ev as InputEventMouseMotion).relative, host.size, UiSettings.room(host)))
	host.set_meta("back_close", func(): close(host))
	v.set_meta("overlay", host)
	if skinned:
		UiSkin.watch(host, face_kind)   # what the panel adds from here on reads on the face
	return v


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	if dat.is_empty() or not dat.has("settings") or not dat.has("sizes") or not dat.has("colors"):
		return ["pane.json: needs settings, sizes and colors"]
	for k in ["default_size", "margin", "title_height", "cascade", "keep_visible", "padding"]:
		if not dat["settings"].has(k):
			bad.append("pane.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	var ds: Variant = dat["settings"]["default_size"]
	if typeof(ds) != TYPE_ARRAY or (ds as Array).size() != 2 or float(ds[0]) < 180 or float(ds[1]) < 120:
		bad.append("pane.json: default_size must be [width, height], at least 180 by 120")
	for k in ["margin", "title_height", "cascade", "keep_visible", "padding"]:
		if float(dat["settings"][k]) < 0.0:
			bad.append("pane.json: settings.%s must not be negative" % k)
	for k in dat.get("places", {}):
		var pl: Variant = dat["places"][k]
		if typeof(pl) != TYPE_ARRAY or (pl as Array).size() != 4 or str(pl[0]) not in ["left", "right"] or str(pl[1]) not in ["top", "bottom"]:
			bad.append("pane.json: places.%s must be [left or right, top or bottom, x offset, y offset]" % k)
		elif not dat["sizes"].has(k):
			bad.append("pane.json: places.%s has no size" % k)
	for name in dat["sizes"]:
		var s: Variant = dat["sizes"][name]
		if typeof(s) != TYPE_ARRAY or (s as Array).size() != 2 or float(s[0]) < 180 or float(s[1]) < 120:
			bad.append("pane.json: size of %s must be [width, height], at least 180 by 120" % name)
		elif not FileAccess.file_exists("res://ui/play/%s.gd" % name):
			bad.append("pane.json: sizes names %s, which is no panel script" % name)
	for k in ["face", "border", "title_bar", "title_text", "close_text"]:
		if not dat["colors"].has(k) or not Color.html_is_valid(str(dat["colors"][k])):
			bad.append("pane.json: color %s is missing or not a colour" % k)
	return bad
