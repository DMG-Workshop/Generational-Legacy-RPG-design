## The goal arrow's screen side (GameGoal says what the goal is; the screens only show it). One place holds what the open world's
## screen knows and the core cannot: the guided start's facts (the heir walked to the marker, clicked to walk, stood in the store),
## the goals as of the last `update`, and which of them the goal key has set aside. All of it is runtime only, never saved: an old
## save and a new one start the same way, and a goal is worked out again each time from the dynasty.
## Drawing: the arrow over the world, the arrow at the minimap's edge and the marker on the world map. The map pin, which is the
## player's own, wins over the goal wherever both would point (a pin set means no goal arrow over the world or on the minimap).
## It is a hint: nothing here moves the heir.
extends RefCounted

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const TutorialTip := preload("res://ui/play/tutorial_tip.gd")

static var _owner := 0              # the dynasty the facts below belong to
static var _start := Vector2i(-1, -1)
static var _marker := GameGoal.NONE   # the guided start's marker (worked out once per dynasty)
static var facts := {}              # the guided start's yes-or-no facts (GameTutorial.CONTEXT)
static var skipped := {}            # goal key -> true: set aside by the goal key until all are (then it starts over)
static var _list: Array = []        # every goal as of the last `update`
static var _shown := {}             # the goal shown now ({} for none)
static var _tip_id := ""


## Forgets everything (a new dynasty, a test).
static func reset() -> void:
	_owner = 0
	_start = Vector2i(-1, -1)
	_marker = GameGoal.NONE
	facts = {}
	skipped = {}
	_list = []
	_shown = {}
	_tip_id = ""


## The tile the heir is "at" for the world's purposes: where they stand on the open world, or the door they went in by.
static func from_tile(sb: GameSandbox) -> Vector2i:
	return sb.heir if sb.space == "world" else sb.outside


## Notes what the screen alone can see (see GameTutorial.CONTEXT). Cheap: every frame.
static func observe(d: GameDynasty, sb: GameSandbox) -> void:
	if sb == null:
		return
	if _owner != d.get_instance_id():
		reset()
		_owner = d.get_instance_id()
	if _start == Vector2i(-1, -1):
		_start = from_tile(sb)
	if from_tile(sb) != _start:
		facts["moved"] = true
	if sb.space == "world":
		if _marker == GameGoal.NONE:
			_marker = GameGoal.marker_tile(d)
		var m := _marker
		if maxi(absi(sb.heir.x - m.x), absi(sb.heir.y - m.y)) <= int(GameGoal.setting("marker_reach")):
			facts["at_marker"] = true
		if sb.route.size() > 1:
			facts["routed"] = true
	elif sb.space.ends_with("/store"):
		facts["store_seen"] = true


static func context(d: GameDynasty, sb: GameSandbox) -> Dictionary:
	return {"tips": UiSettings.tutorial_on(), "facts": facts, "creatures": sb.creatures, "space": sb.space}


## The key a goal is set aside by: its id, and for a quest its words (one id stands for many quests).
static func key_of(g: Dictionary) -> String:
	return str(g["label"]) if str(g["kind"]) == "quest" else str(g["id"])


## Works the goals out again (a few times a second, and when asked): the list and the one to show.
static func update(d: GameDynasty, sb: GameSandbox) -> void:
	observe(d, sb)
	_list = GameGoal.all(d, from_tile(sb), context(d, sb)) if UiSettings.goal_on() else []
	_shown = {}
	for g in _list:
		if not skipped.has(key_of(g)):
			_shown = g
			break


## The goal shown now ({} for none, or when the option is off).
static func current() -> Dictionary:
	return _shown if UiSettings.goal_on() else {}


## The goal key: sets the shown goal aside and shows the next; when none is left, starts over. Returns the new goal ({} for none).
static func cycle(d: GameDynasty, sb: GameSandbox) -> Dictionary:
	update(d, sb)
	if _shown.is_empty():
		skipped = {}
	else:
		skipped[key_of(_shown)] = true
	update(d, sb)
	if _shown.is_empty():
		skipped = {}
		update(d, sb)
	return _shown


## "Goal: Rest at the family house (24 tiles NE)" for a status line; "" for none.
static func line(from: Vector2i) -> String:
	var g := current()
	if g.is_empty():
		return ""
	var tile: Vector2i = g["tile"]
	if tile == GameGoal.NONE:
		return GameGoal.text("line_words", {"label": g["label"]})
	var n := GameTravel.tiles(from, tile)
	if n <= 0:
		return GameGoal.text("line_here", {"label": g["label"]})
	return GameGoal.text("line", {"label": g["label"], "tiles": n, "dir": GameTravel.compass(from, tile)})


## The bearing of the goal from a tile for the minimap (GameMiniMap.bearing_to), {} for none or a goal with no tile.
static func bearing(d: GameDynasty, from: Vector2i, radius: int) -> Dictionary:
	var g := current()
	if g.is_empty() or g["tile"] == GameGoal.NONE or GameTravel.has_pin(d):
		return {}   # the player's pin wins
	return GameMiniMap.bearing_to(from, g["tile"], str(g["label"]), radius)


# ---------------------------------------------------------------- the tip strip

## Keeps the open world's tip strip (one row, the first-heir tutorial's "sandbox" steps) up to date on `host`: made when a tip applies,
## replaced when it changes, taken away when none does. Returns the strip or null.
static func sync_tip(host: Control, d: GameDynasty, top: float) -> Control:
	var strip := host.get_node_or_null("TutorialTip") as Control
	var tip := GameTutorial.current(d, "sandbox", facts) if UiSettings.tutorial_on() and d.gen <= 1 else {}
	if tip.is_empty():
		if strip != null:
			strip.queue_free()
			host.remove_child(strip)
		_tip_id = ""
		return null
	if strip != null and _tip_id == str(tip["id"]):
		return strip
	if strip != null:
		strip.queue_free()
		host.remove_child(strip)
	var width := minf(host.size.x - 16.0, 620.0)
	strip = TutorialTip.make(tip, width, func(): _skip(host))
	strip.position = Vector2(8.0, top)
	strip.custom_minimum_size.x = width
	strip.size = Vector2(width, 0)
	host.add_child(strip)
	_tip_id = str(tip["id"])
	return strip


static func _skip(host: Control) -> void:
	UiSettings.set_tutorial(false)
	var strip := host.get_node_or_null("TutorialTip")
	if strip != null:
		strip.queue_free()
		host.remove_child(strip)
	_tip_id = ""


# ---------------------------------------------------------------- the first fight

## The scripted first fight: once a brand new heir has walked to the marker and has not fought yet, the first foe waits outside the
## town's gate (a creature agent put among the world's own: no dice, nothing saved). Put there again when the heir comes
## back near it and it is gone. Returns whether one was added.
static func place_first_foe(d: GameDynasty, sb: GameSandbox) -> bool:
	if sb.space != "world" or not GameGoal.guided(d) or not bool(facts.get("at_marker", false)) or not GameGoal.fresh_start(d):
		return false
	for a in sb.creatures:
		if bool(a.get("guided", false)):
			return false
	var foe := GameGoal.first_foe(d)
	var at := Vector2(float(foe["x"]), float(foe["z"]))
	if at.distance_to(sb.heir_point()) > float(GameSandbox.setting("radius")) + 2.0:
		return false
	foe["uid"] = sb.next_uid
	sb.next_uid += 1
	sb.creatures.append(foe)
	return true


# ---------------------------------------------------------------- drawing

static func _pulse() -> float:
	return 0.0 if UiSettings.reduced_motion() else sin(float(Time.get_ticks_msec()) / 220.0)


## The arrow over the open world: a bobbing marker above the goal's tile when it is in view, else an arrow at the edge of the view
## pointing the way, with the goal's words. `area` is the map area at `origin`, `centre` the tile at its middle, `cell` a tile's pixels.
static func paint_world(c: Control, d: GameDynasty, origin: Vector2, area: Vector2, centre: Vector2, cell: float) -> void:
	var g := current()
	if g.is_empty() or g["tile"] == GameGoal.NONE or GameTravel.has_pin(d):
		return
	var tile: Vector2i = g["tile"]
	var p := origin + (Vector2(tile) + Vector2(0.5, 0.5) - centre) * cell + area * 0.5
	var col := Kit.good()
	var ink := Color(0.05, 0.04, 0.08)
	var rect := Rect2(origin, area).grow(-18.0)
	var font := ThemeDB.fallback_font
	if rect.has_point(p):
		var bob := _pulse() * 3.0
		var tip := p + Vector2(0.0, -cell * 0.9 + bob)
		var w := maxf(7.0, cell * 0.28)
		draw_down(c, tip, w, col, ink)
		var text := str(g["label"])
		var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		var box := Rect2(tip + Vector2(-sz.x * 0.5 - 6.0, -w * 2.2 - sz.y - 6.0), sz + Vector2(12.0, 6.0))
		box.position.x = clampf(box.position.x, rect.position.x, rect.end.x - box.size.x)
		c.draw_style_box(Kit.style(Color(0.1, 0.09, 0.14, 0.88), 5, col), box)
		c.draw_string(font, box.position + Vector2(6.0, sz.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.92, 0.9, 0.96))
		return
	var dir := (p - (origin + area * 0.5)).normalized()
	var half := rect.size * 0.5
	var t := minf(half.x / maxf(absf(dir.x), 0.0001), half.y / maxf(absf(dir.y), 0.0001))
	var at := origin + area * 0.5 + dir * t
	draw_pointer(c, at, dir, 11.0, col, ink)
	var n := GameTravel.tiles(Vector2i(centre), tile)
	var text := "%s  %d" % [str(g["label"]), n]
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var box := Rect2(at - dir * 30.0 - sz * 0.5 - Vector2(5, 3), sz + Vector2(10, 6))
	box.position = Vector2(clampf(box.position.x, rect.position.x, rect.end.x - box.size.x), clampf(box.position.y, rect.position.y, rect.end.y - box.size.y))
	c.draw_style_box(Kit.style(Color(0.1, 0.09, 0.14, 0.82), 4, col), box)
	c.draw_string(font, box.position + Vector2(5, sz.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.92, 0.9, 0.96))


## A down-pointing marker with its point at `tip`.
static func draw_down(c: CanvasItem, tip: Vector2, w: float, col: Color, ink: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, 2), tip + Vector2(-w - 2, -w * 1.6 - 2), tip + Vector2(w + 2, -w * 1.6 - 2)]), ink)
	c.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-w, -w * 1.6), tip + Vector2(w, -w * 1.6)]), col)


## An arrow whose point is at `at` and which looks along `dir`.
static func draw_pointer(c: CanvasItem, at: Vector2, dir: Vector2, s: float, col: Color, ink: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	var back := at - dir * s * 1.3
	c.draw_colored_polygon(PackedVector2Array([at + dir * 3.0, back + side * (s + 2.0), back - dir * 3.0, back - side * (s + 2.0)]), ink)
	c.draw_colored_polygon(PackedVector2Array([at, back + side * s, back - dir * 2.0, back - side * s]), col)


## The goal on the minimap: a ring where it stands when it is in the picture, else an arrow at the picture's edge. `size` is the
## control's size and `radius` the picture's (tiles each way). The pin, when set, is drawn by the pane and wins (see `bearing`).
static func paint_minimap(c: CanvasItem, size: Vector2, radius: int, b: Dictionary) -> void:
	if b.is_empty():
		return
	var side := minf(size.x, size.y)
	var box := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	var ink := Color(0.05, 0.04, 0.08)
	var col := Kit.good()
	if bool(b["inside"]):
		var cellpx := side / float(radius * 2 + 1)
		var at := box.get_center() + Vector2(b["offset"]) * cellpx + Vector2(cellpx, cellpx) * 0.5
		var r := 5.0 + _pulse() * 1.2
		c.draw_arc(at, r + 1.5, 0.0, TAU, 20, ink, 3.0)
		c.draw_arc(at, r, 0.0, TAU, 20, col, 1.8)
		draw_down(c, at + Vector2(0, -r - 2.0), 4.0, col, ink)
		return
	var dir := Vector2(cos(float(b["angle"])), sin(float(b["angle"])))
	var half := box.size * 0.5 - Vector2(12, 12)
	var t := minf(half.x / maxf(absf(dir.x), 0.0001), half.y / maxf(absf(dir.y), 0.0001))
	draw_pointer(c, box.get_center() + dir * t, dir, 7.0, col, ink)


## The goal's marker on the world map (GameWorldMap's cells): a ring and a down arrow over its cell. `cell` is a cell's pixels.
static func paint_map(c: CanvasItem, d: GameDynasty, cell: Vector2, mpx: float) -> void:
	var g := current()
	if g.is_empty() or g["tile"] == GameGoal.NONE:
		return
	var tile: Vector2i = g["tile"]
	var gc := GameWorldMap.cell_of(tile.x, tile.y)
	var at := (Vector2(gc) + Vector2(0.5, 0.5)) * cell
	var ink := Color(0.05, 0.04, 0.08)
	var col := Kit.good()
	var r := maxf(4.0, mpx * 0.7)
	c.draw_arc(at, r + 1.5, 0.0, TAU, 20, ink, 3.0)
	c.draw_arc(at, r, 0.0, TAU, 20, col, 1.8)
	draw_down(c, at + Vector2(0, -r - 1.0), maxf(3.0, mpx * 0.5), col, ink)
