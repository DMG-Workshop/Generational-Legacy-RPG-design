## The panel ring (data/ui/radial.json): hold the ring key (Tab) and a ring of the panels opens round the mouse; move toward one and let go to
## open it. A quick tap leaves the ring up, and a click then chooses (a click on nothing, Tab again or Escape closes it). Each item is a
## panel id whose key is the action `world_panel_<id>` in input.json, so the ring and the keys cannot drift apart. Rendering and picking only:
## the sandbox screen opens what is chosen and nothing here touches a dynasty.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const WorldInput := preload("res://ui/play/world_input.gd")
const UiSkin := preload("res://ui/play/ui_skin.gd")
const PATH := "res://data/ui/radial.json"

signal chosen(id: String)   # an item's id, or "" when the ring was closed with nothing chosen

static var _cache: Dictionary = {}

var items: Array = []        # [{id, label, key}]
var centre := Vector2.ZERO   # where the ring is drawn, in this control's own space
var hover := -1
var sticky := false          # left up after a tap: a click chooses


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> float:
	return float(data()["settings"][key])


static func text(key: String) -> String:
	return str(data()["text"][key])


## The item a point is toward, from the ring's centre: 0 is at the top and they run clockwise, each owning an equal sector with its own
## item in the middle of it. -1 within `dead` of the centre (nothing chosen) or with nothing to choose.
static func pick(from: Vector2, pos: Vector2, count: int, dead: float) -> int:
	if count <= 0 or pos.distance_to(from) < dead:
		return -1
	var a := fposmod((pos - from).angle() + PI * 0.5, TAU)
	var step := TAU / float(count)
	return int(floor((a + step * 0.5) / step)) % count


## Where item `i` of `count` is drawn: on the ring, 0 at the top and clockwise.
static func slot_at(from: Vector2, i: int, count: int, radius: float) -> Vector2:
	var a := TAU * float(i) / float(maxi(count, 1)) - PI * 0.5
	return from + Vector2(cos(a), sin(a)) * radius


## The ring's centre moved so every item stays inside `bounds` (the screen), whatever the mouse is near.
static func fit(from: Vector2, bounds: Vector2) -> Vector2:
	var need := setting("radius") + maxf(setting("slot_w"), setting("slot_h")) * 0.5 + setting("margin")
	return Vector2(clampf(from.x, need, maxf(need, bounds.x - need)), clampf(from.y, need, maxf(need, bounds.y - need)))


## The ring for the panels in the data, at `at` (fitted into `bounds`).
static func make(at: Vector2, bounds: Vector2) -> Control:
	var ring: Control = load("res://ui/play/radial_menu.gd").new()
	for it in data()["items"]:
		var keys: Array = WorldInput.keys_of("world_panel_" + str(it["id"]))
		ring.items.append({"id": str(it["id"]), "label": str(it["label"]), "key": str(keys[0]) if not keys.is_empty() else ""})
	ring.centre = fit(at, bounds)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_STOP
	ring.z_index = 30
	return ring


## The id under the mouse now ("" when none).
func picked() -> String:
	return str(items[hover]["id"]) if hover >= 0 and hover < items.size() else ""


func _process(_delta: float) -> void:
	var now := pick(centre, get_local_mouse_position(), items.size(), setting("dead_radius"))
	if now != hover:
		hover = now
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not sticky:
		return
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		chosen.emit(picked() if event.button_index == MOUSE_BUTTON_LEFT else "")


func _draw() -> void:
	if UiSkin.hud_active(self):
		_draw_skinned()
		return
	draw_circle(centre, setting("radius") + setting("slot_h") * 0.5 + 6.0, Color(0, 0, 0, 0.35))
	draw_circle(centre, setting("dead_radius"), Color(0.1, 0.09, 0.16, 0.9))
	var font := ThemeDB.fallback_font
	var w := setting("slot_w")
	var h := setting("slot_h")
	for i in items.size():
		var at := slot_at(centre, i, items.size(), setting("radius"))
		var box := Rect2(at - Vector2(w, h) * 0.5, Vector2(w, h))
		var on := i == hover
		draw_style_box(Kit.style(Color("#2a2740") if not on else Color("#4a3f78"), 8, Kit.ACCENT if on else Color("#4a4666")), box)
		draw_string(font, box.position + Vector2(0, h * 0.5 - 2.0), str(items[i]["label"]), HORIZONTAL_ALIGNMENT_CENTER, w, 15, Kit.TEXT)
		if str(items[i]["key"]) != "":
			draw_string(font, box.position + Vector2(0, h - 6.0), str(items[i]["key"]), HORIZONTAL_ALIGNMENT_CENTER, w, 11, Kit.dim())
	var hint := text("sticky_hint") if sticky else text("hint")
	draw_string(font, centre + Vector2(-120, setting("radius") + h + 18.0), hint, HORIZONTAL_ALIGNMENT_CENTER, 240, 13, Kit.dim())


## The ring in the skin: a wooden hub with an ink rim, a parchment plate for each panel (a gold frame on the one pointed at), the key of
## each in a quiet ink on it, the hint in an ink badge.
func _draw_skinned() -> void:
	var px := float(UiSkin.pixel())
	draw_circle(centre, setting("radius") + setting("slot_h") * 0.5 + 6.0, Color(0, 0, 0, 0.35))
	draw_circle(centre, setting("dead_radius") + px, UiSkin.pal("ink"))
	draw_circle(centre, setting("dead_radius") - px, UiSkin.pal("wood"))
	draw_arc(centre, setting("dead_radius") - px * 2.0, 0.0, TAU, 32, UiSkin.pal("wood_hi"), px)
	var font := ThemeDB.fallback_font
	var w := setting("slot_w")
	var h := setting("slot_h")
	for i in items.size():
		var at := slot_at(centre, i, items.size(), setting("radius"))
		var box := Rect2((at - Vector2(w, h) * 0.5).round(), Vector2(w, h))
		var on := i == hover
		draw_style_box(UiSkin.plate_box(on), box)
		draw_string(font, box.position + Vector2(0, h * 0.5 - 2.0), str(items[i]["label"]), HORIZONTAL_ALIGNMENT_CENTER, w, 15, UiSkin.pal("crimson_dk") if on else UiSkin.pal("ink"))
		if str(items[i]["key"]) != "":
			draw_string(font, box.position + Vector2(0, h - 8.0), str(items[i]["key"]), HORIZONTAL_ALIGNMENT_CENTER, w, 11, UiSkin.pal("ink_dim"))
	var hint := text("sticky_hint") if sticky else text("hint")
	var hs := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var hbox := Rect2(centre + Vector2(-hs.x * 0.5 - px * 3.0, setting("radius") + h + 4.0), hs + Vector2(px * 6.0, px * 2.0))
	draw_style_box(UiSkin.badge_box(false), hbox)
	draw_string(font, hbox.position + Vector2(px * 3.0, px + font.get_ascent(13)), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiSkin.pal("parch_hi"))


static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = data()
	for k in ["settings", "items", "text"]:
		if not dat.has(k):
			bad.append("radial.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	for k in ["radius", "dead_radius", "slot_w", "slot_h", "tap_seconds", "margin"]:
		if not dat["settings"].has(k) or float(dat["settings"][k]) <= 0.0:
			bad.append("radial.json: settings.%s must be above 0" % k)
	if not bad.is_empty():
		return bad
	if float(dat["settings"]["dead_radius"]) >= float(dat["settings"]["radius"]):
		bad.append("radial.json: dead_radius must be smaller than radius")
	var items: Array = dat["items"]
	if items.size() < 3 or items.size() > 12:
		bad.append("radial.json: a ring holds 3 to 12 items, not %d" % items.size())
	var seen := {}
	for it in items:
		var id := str(it.get("id", ""))
		if id == "" or str(it.get("label", "")) == "":
			bad.append("radial.json: every item needs an id and a label")
			continue
		if seen.has(id):
			bad.append("radial.json: '%s' is on the ring twice" % id)
		seen[id] = true
		if not WorldInput.data()["actions"].has("world_panel_" + id):
			bad.append("radial.json: '%s' has no key action world_panel_%s in input.json" % [id, id])
	for k in ["hint", "sticky_hint"]:
		if not dat["text"].has(k):
			bad.append("radial.json: text.%s is missing" % k)
	return bad
