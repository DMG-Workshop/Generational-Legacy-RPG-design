## The open world as a screen (roadmap items 39 and 51): a top-down map of the generated ground round the heir, drawn from
## GameSandbox, with the world's input (ui/play/world_input.gd) and the day's light (GameDay). Nothing here works out a
## result: it reads GameSandbox and GameDay, calls them, and draws. While it is open the world clock runs (GameClock), the
## world's own time, so a fight, a succession or an ended saga hands the screen back to the app at once.
## Tap a tile to walk there (a route over the ground as it is now); the keys or the stick walk the heir one tile at a time.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const WorldInput := preload("res://ui/play/world_input.gd")
const BAR := 56.0

var app: Node
var sb: GameSandbox
var zoom := 1.0           # the view's zoom (WorldInput.zoom_after keeps it within the data's limits)
var cam := Vector2.ZERO   # the view's offset from the heir, in tiles
var facing_dir := Vector2i(0, 1)
var status: Label
var last_line := ""
var _walk_wait := 0.0
var _tick_wait := 0.0
var _save_wait := 0.0
var _tiles := {}          # "x,z" -> the generated tile (pure of the seed; cached for drawing)
var _press := Vector2.ZERO
var _press_ms := 0


static func setting(key: String) -> Variant:
	return GameSandbox.data()["view"][key]


## The map tile under a point of the map area (its own top-left at 0,0), with the heir at the centre of the view.
static func tile_at(p: Vector2, area: Vector2, heir: Vector2i, cam_tiles: Vector2, cell: float) -> Vector2i:
	var t := (p - area * 0.5) / cell + Vector2(heir) + cam_tiles
	return Vector2i(floori(t.x), floori(t.y))


## The step (one of eight) that a move vector means: the dominant direction, zero when it is not moved.
static func step_for(move: Vector2) -> Vector2i:
	if move.length() < float(setting("move_threshold")):
		return Vector2i.ZERO
	return WorldInput.facing(move)


func _ready() -> void:
	if not WorldInput.installed():
		WorldInput.install()   # the app installs them at start; a screen made on its own installs them itself
	sb = GameSandbox.start(app.dynasty)
	var bar := HBoxContainer.new()
	bar.position = Vector2(8, 4)
	bar.size = Vector2(maxf(0.0, size.x - 16.0), BAR - 8.0)
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)
	bar.add_child(Kit.button("Back", func(): app.show_state(), Vector2(88, BAR - 12)))
	bar.add_child(Kit.button("Dig", func(): _dig(), Vector2(72, BAR - 12)))
	bar.add_child(Kit.button("Build wall", func(): _build(), Vector2(120, BAR - 12)))
	status = Kit.label("", 14, Kit.dim())
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.clip_text = true
	bar.add_child(status)
	_refresh_status()


func _process(delta: float) -> void:
	var d: GameDynasty = app.dynasty
	if d.battle != null or d.state != "life":
		app.show_state()   # the clock (or the heir) has handed the screen over: a fight, a succession, the end
		return
	var inp := WorldInput.read()
	if int(inp["zoom"]) != 0:
		zoom = WorldInput.zoom_after(zoom, int(inp["zoom"]))
	var look: Vector2 = inp["look"]
	if look.length() > 0.0:
		cam += look * float(setting("cam_tiles_per_second")) * delta
	var mv: Vector2 = inp["move"]
	_walk_wait -= delta
	var stepped := false
	if step_for(mv) != Vector2i.ZERO:
		sb.route = []
		if _walk_wait <= 0.0:
			facing_dir = step_for(mv)
			sb.move(facing_dir.x, facing_dir.y)
			_walk_wait = float(GameSandbox.setting("walk_seconds"))
			stepped = true
	elif not sb.route.is_empty() and _walk_wait <= 0.0:
		sb.walk_one()
		_walk_wait = float(GameSandbox.setting("walk_seconds"))
		stepped = true
	if stepped:
		cam = Vector2.ZERO   # the view follows the heir while they walk
	_tick_wait -= delta
	while _tick_wait <= 0.0:
		sb.step(1)
		_tick_wait += float(GameSandbox.setting("tick_seconds"))
	var lines := GameClock.feed(d, delta)
	for e in lines:
		last_line = str(e.get("text", e)) if e is Dictionary else str(e)
	_save_wait -= delta
	if _save_wait <= 0.0:
		d.save_to_disk()
		_save_wait = float(setting("save_seconds"))
	if inp["cancel"]:
		app.show_state()
		return
	if inp["dig"]:
		_dig()
	if inp["build"]:
		_build()
	_refresh_status()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var e := event as InputEventMouseButton
		var area := Vector2(size.x, size.y - BAR)
		if e.pressed:
			_press = e.position
			_press_ms = Time.get_ticks_msec()
		elif WorldInput.is_tap(_press, e.position, float(Time.get_ticks_msec() - _press_ms) / 1000.0):
			_tap(e.position - Vector2(0, BAR), area)


func _tap(p: Vector2, area: Vector2) -> void:
	if p.y < 0.0 or p.y > area.y:
		return
	var tile := tile_at(p, area, sb.heir, cam, _cell())
	var dx := tile.x - sb.heir.x
	var dz := tile.y - sb.heir.y
	if absi(dx) <= 1 and absi(dz) <= 1 and (dx != 0 or dz != 0):
		sb.route = []
		var r := sb.move(dx, dz)
		if not r["ok"]:
			last_line = str(r["why"])
	elif tile != sb.heir:
		var planned := sb.set_route(tile)
		if not planned["ok"]:
			last_line = str(planned["why"])
		else:
			_walk_wait = 0.0
	cam = Vector2.ZERO
	_refresh_status()
	queue_redraw()


func _dig() -> void:
	var r := sb.dig(0)
	if r["ok"]:
		last_line = str(sb.log.back()["text"])   # GameSandbox.dig logged the line just now
		app.dynasty.save_to_disk()
	else:
		last_line = str(r["why"])
	_refresh_status()
	queue_redraw()


func _build() -> void:
	var r := sb.build("wall", facing_dir.x, facing_dir.y)
	last_line = str(r["text"])
	if r["ok"]:
		app.dynasty.save_to_disk()
	_refresh_status()
	queue_redraw()


func _cell() -> float:
	return float(setting("cell_px")) * zoom


func _refresh_status() -> void:
	var d: GameDynasty = app.dynasty
	status.text = "%s  %s  %s" % [GameDay.time_text(d), GameDay.look(d)["weather"], last_line]


func _draw() -> void:
	var d: GameDynasty = app.dynasty
	var area := Vector2(size.x, size.y - BAR)
	var origin := Vector2(0, BAR)
	var cell := _cell()
	var colors: Dictionary = GameSandbox.data()["colors"]
	var look := GameDay.look(d)
	var light := clampf(float(look["light"]), float(setting("dim_floor")), 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0))
	var centre := Vector2(sb.heir) + cam
	var half := area * 0.5 / cell
	var x0 := floori(centre.x - half.x) - 1
	var z0 := floori(centre.y - half.y) - 1
	for z in range(z0, ceili(centre.y + half.y) + 2):
		for x in range(x0, ceili(centre.x + half.x) + 2):
			var t := _tile(d, x, z)
			var col := _rgb(colors["water"]) if t["water"] else _rgb(colors["land"])
			if GameBuild.kind_at(d, x, -1, z) != "":
				col = _rgb(colors["built"])
			col = col * light
			var p := origin + (Vector2(x, z) - centre) * cell + area * 0.5
			draw_rect(Rect2(p, Vector2(cell, cell)), col)
	var tint: Array = look["tint"]
	var night_alpha := (1.0 - float(look["light"])) * 0.5
	if night_alpha > 0.0:
		draw_rect(Rect2(origin, area), Color(float(tint[0]), float(tint[1]), float(tint[2]), night_alpha))
	for i in range(sb.route.size()):
		var rp := origin + (Vector2(sb.route[i]) + Vector2(0.5, 0.5) - centre) * cell + area * 0.5
		draw_circle(rp, maxf(2.0, cell * 0.12), _rgb(colors["route"]))
	for a in sb.creatures:
		var cp := origin + (Vector2(float(a["x"]), float(a["z"])) - centre) * cell + area * 0.5
		draw_circle(cp, maxf(2.0, cell * 0.3), _rgb(colors["creature"]))
	for a in sb.companions:
		var kp := origin + (Vector2(float(a["x"]), float(a["z"])) - centre) * cell + area * 0.5
		draw_circle(kp, maxf(2.0, cell * 0.3), _rgb(colors["companion"]))
	var hp := origin + (Vector2(sb.heir) + Vector2(0.5, 0.5) - centre) * cell + area * 0.5
	draw_circle(hp, maxf(3.0, cell * 0.4), _rgb(colors["heir"]))


func _tile(d: GameDynasty, x: int, z: int) -> Dictionary:
	var k := "%d,%d" % [x, z]
	if not _tiles.has(k):
		if _tiles.size() > 20000:
			_tiles.clear()
		_tiles[k] = GameWorldGen.tile(d, x, z)
	return _tiles[k]


static func _rgb(v: Array) -> Color:
	return Color(float(v[0]), float(v[1]), float(v[2]))
