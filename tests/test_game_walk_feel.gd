## How walking feels in the open world (ui/play/glide.gd, ui/play/move_marker.gd, data/world/sandbox.json "feel", the world_run
## action): the smooth-damp eases in and out with no overshoot; a drawn position glides to the real one and snaps on a jump or with
## reduced motion; a stride bobs the figure and tells of a footstep (alternating feet, only when heard, also with reduced motion); the
## run key is a remappable action that shortens the step; the mark of a click follows the route, fades on arrival and faster on a
## cancel, shows nothing for a journey's legs and is plain with reduced motion; a click on bare ground (the select button, whatever it
## is remapped to) puts the mark down; the screen's view follows the glide; the data validator catches breaks; nothing here draws a die,
## changes the dynasty or reaches a save.
## Run: godot --headless --path . -s res://tests/test_game_walk_feel.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const SandboxScreen := preload("res://ui/play/sandbox_screen.gd")
const WorldInput := preload("res://ui/play/world_input.gd")
const Glide := preload("res://ui/play/glide.gd")
const MoveMarker := preload("res://ui/play/move_marker.gd")

var fails := 0
var checks := 0
var _feet: Array = []


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	GameData.load_all()
	UiSettings.path = "user://test_walk_feel.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	GameDynasty.save_path = "user://test_walk_feel_save.json"
	test_smooth_damp()
	test_glide()
	test_reduced_motion()
	test_footsteps()
	test_run()
	await test_marker()
	test_data()
	await test_screen()
	UiSettings.set_access("reduced_motion", false)
	WorldInput.reset_mouse()
	DirAccess.remove_absolute(UiSettings.path)
	print("walk feel tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _walk(g: Glide, key: String, from: float, tiles: int, seconds_per_tile: float, dt: float) -> Array:
	# the real position steps a tile every `seconds_per_tile`; returns the drawn x after each frame
	var out: Array = []
	var t := 0.0
	var real := from
	var next := seconds_per_tile
	var total := float(tiles) * seconds_per_tile + 1.0
	while t < total:
		if t >= next and real < from + float(tiles):
			real += 1.0
			next += seconds_per_tile
		g.advance(dt)
		out.append(g.at(key, Vector2(real, 0.0), "heir").x)
		t += dt
	return out


func test_smooth_damp() -> void:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var steps: Array = []
	var over := false
	for i in 120:
		var r := Glide.smooth_damp(pos, Vector2(1, 0), vel, 0.14, 1.0 / 60.0, 14.0)
		steps.append((r[0] as Vector2).x - pos.x)
		pos = r[0]
		vel = r[1]
		if pos.x > 1.0 + 0.0001:
			over = true
	ok(not over, "the smooth-damp never runs past its target")
	ok(pos.is_equal_approx(Vector2(1, 0)), "and arrives")
	ok(float(steps[0]) < float(steps[6]), "it accelerates from rest (the first step is smaller than a later one)")
	ok(float(steps[119]) < float(steps[12]), "and decelerates into the stop")
	var mono := true
	for i in range(1, 60):
		if float(steps[i]) < -0.00001:
			mono = false
	ok(mono, "it never goes back")
	var r2 := Glide.smooth_damp(Vector2.ZERO, Vector2(100, 0), Vector2.ZERO, 0.14, 1.0 / 60.0, 14.0)
	ok((r2[0] as Vector2).x <= 14.0 / 60.0 + 0.0001, "its pace is capped by max speed: %f" % (r2[0] as Vector2).x)
	var big := Glide.smooth_damp(Vector2.ZERO, Vector2(1, 0), Vector2.ZERO, 0.14, 5.0, 14.0)
	ok(is_equal_approx((big[0] as Vector2).x, 1.0) or (big[0] as Vector2).x <= 1.0, "a long frame cannot throw it past")


func test_glide() -> void:
	UiSettings.set_access("reduced_motion", false)
	var g := Glide.new()
	g.advance(1.0 / 60.0)
	ok(g.at("heir", Vector2(5, 5), "heir") == Vector2(5, 5), "the first sight of a thing draws it where it is")
	g.advance(1.0 / 60.0)
	var p := g.at("heir", Vector2(6, 5), "heir")
	ok(p.x > 5.0 and p.x < 6.0, "a step of a tile is drawn part of the way: %f" % p.x)
	ok(g.lag("heir") > 0.0, "with a lag the view can measure")
	for i in 90:
		g.advance(1.0 / 60.0)
		g.at("heir", Vector2(6, 5), "heir")
	ok(g.at("heir", Vector2(6, 5), "heir") == Vector2(6, 5), "and arrives and rests")
	g.advance(1.0 / 60.0)
	g.at("heir", Vector2(6, 5), "heir")
	ok(g.speed("heir") == 0.0 and g.lift("heir") == 0.0, "a thing at rest has no pace and no bob")
	g.advance(1.0 / 60.0)
	var far := g.at("heir", Vector2(106, 5), "heir")
	ok(far == Vector2(106, 5), "a jump over snap_tiles (a new place) is drawn there at once")
	var e := g.at("heir", Vector2(106, 5), "heir")
	ok(e == Vector2(106, 5), "asking again in the same frame moves nothing")
	g.clear()
	g.advance(0.016)
	ok(g.at("heir", Vector2(1, 1), "heir") == Vector2(1, 1), "a cleared glide starts where things stand")
	# another thing keeps its own state
	g.advance(0.016)
	g.at("c1", Vector2(10, 10), "creature")
	g.advance(0.016)
	var c := g.at("c1", Vector2(10.5, 10), "creature")
	ok(c.x > 10.0 and c.x < 10.5, "a creature glides over its own time")
	# forgetting
	for i in 400:
		g.advance(0.016)
		g.at("heir", Vector2(1, 1), "heir")
	ok(not g._st.has("c1"), "a thing not drawn for a while is forgotten")


func test_reduced_motion() -> void:
	UiSettings.set_access("reduced_motion", true)
	var g := Glide.new()
	g.advance(0.016)
	g.at("heir", Vector2(0, 0), "heir")
	g.advance(0.016)
	ok(g.at("heir", Vector2(1, 0), "heir") == Vector2(1, 0), "with reduced motion the drawn place is the real one")
	var lifted := false
	for i in 60:
		g.advance(0.016)
		g.at("heir", Vector2(2.0 + float(i) * 0.1, 0), "heir")
		if g.lift("heir") != 0.0:
			lifted = true
	ok(not lifted, "and nothing bobs")
	UiSettings.set_access("reduced_motion", false)


func _foot(key: String, kind: String, foot: int, tile: Vector2i, speed: float, near: float) -> void:
	_feet.append([key, kind, foot, tile, speed, near])


func test_footsteps() -> void:
	UiSettings.set_access("reduced_motion", false)
	var g := Glide.new()
	_feet = []
	g.footstep.connect(_foot)
	var xs := _walk(g, "heir", 0.0, 12, 0.2, 1.0 / 60.0)
	var n := _feet.size()
	ok(n >= 7 and n <= 12, "twelve tiles at a walk are about ten footsteps (%d)" % n)
	var alternate := true
	for i in range(1, n):
		if int(_feet[i][2]) == int(_feet[i - 1][2]):
			alternate = false
	ok(alternate, "the feet alternate")
	ok(str(_feet[0][1]) == "heir" and float(_feet[0][4]) > 0.0 and float(_feet[0][5]) == 0.0, "a footstep says who, how fast and how near")
	ok(xs[xs.size() - 1] == 12.0, "the walk ends on its tile")
	var mono := true
	for i in range(1, xs.size()):
		if float(xs[i]) < float(xs[i - 1]) - 0.00001:
			mono = false
	ok(mono, "the drawn walk never steps back")
	# bob: lifted while walking, within the data's height
	var g2 := Glide.new()
	var top := 0.0
	var real := 0.0
	var t := 0.0
	for i in 200:
		t += 1.0 / 60.0
		real = floorf(t / 0.2)
		g2.advance(1.0 / 60.0)
		g2.at("heir", Vector2(real, 0), "heir")
		top = maxf(top, g2.lift("heir"))
		ok(g2.lift("heir") >= 0.0 and g2.lift("heir") <= Glide.setting("bob_tiles") + 0.0001, "the lift stays within bob_tiles")
	ok(top > 0.0, "walking lifts the figure (%f)" % top)
	# hearing: a thing far from the heir makes no sound, one near does
	var g3 := Glide.new()
	_feet = []
	g3.footstep.connect(_foot)
	g3.advance(0.016)
	g3.at("heir", Vector2(0, 0), "heir")
	g3.at("far", Vector2(0, 0), "creature")
	g3.at("near", Vector2(0, 0), "creature")
	var hear := Glide.setting("hear_tiles")
	for i in 240:
		g3.advance(1.0 / 60.0)
		g3.at("heir", Vector2(0, 0), "heir")
		g3.at("far", Vector2(hear + 20.0 + float(i) * 0.03, 0.0), "creature")
		g3.at("near", Vector2(float(i) * 0.03, 1.0), "creature")
	var heard_far := false
	var heard_near := false
	for f in _feet:
		if f[0] == "far":
			heard_far = true
		if f[0] == "near":
			heard_near = true
	ok(heard_near and not heard_far, "a creature near the heir is heard and one out of range is not")
	# reduced motion keeps the footsteps
	UiSettings.set_access("reduced_motion", true)
	var g4 := Glide.new()
	_feet = []
	g4.footstep.connect(_foot)
	_walk(g4, "heir", 0.0, 12, 0.2, 1.0 / 60.0)
	ok(_feet.size() >= 7, "with reduced motion the footsteps still come (%d)" % _feet.size())
	UiSettings.set_access("reduced_motion", false)


func test_run() -> void:
	ok(WorldInput.actions().has("world_run"), "there is a run action")
	ok(WorldInput.keys_of("world_run") == ["Shift"], "on Shift by default")
	ok(not WorldInput.events_for("world_run").is_empty(), "with events for the input map")
	var a: Dictionary = WorldInput.data()["actions"]["world_run"]
	ok(not (a.get("pad_axes", []) as Array).is_empty(), "and a gamepad trigger")
	ok(WorldInput.validate().is_empty(), "the input data is sound with it: %s" % str(WorldInput.validate()))
	WorldInput.install()
	ok(InputMap.has_action("world_run"), "it is in the input map")
	ok(WorldInput.read().has("run") and not bool(WorldInput.read()["run"]), "read() tells whether it is held (not now)")
	var walk := Glide.step_seconds(false)
	var run := Glide.step_seconds(true)
	ok(is_equal_approx(walk, float(GameSandbox.setting("walk_seconds"))), "a walk is the data's walk_seconds")
	ok(run < walk and is_equal_approx(run * Glide.run_multiplier(), walk), "a run steps faster by the data's multiplier (%f against %f)" % [run, walk])
	# a remapped key
	var r := WorldInput.remap("world_run", 0, "F7")
	ok(bool(r.get("ok", false)) and WorldInput.keys_of("world_run") == ["F7"], "the run key can be remapped")
	WorldInput.reset("world_run")
	ok(WorldInput.keys_of("world_run") == ["Shift"], "and put back")


func test_marker() -> void:
	UiSettings.set_access("reduced_motion", false)
	var m := MoveMarker.new()
	ok(m.alpha() == 0.0 and not m.active, "no mark to begin with")
	m.update(null, Vector2i(0, 0), false, 0.016)
	ok(not m.active, "no route, no mark")
	m.update(Vector2i(5, 0), Vector2i(0, 0), false, 0.016)
	ok(m.active and m.tile == Vector2i(5, 0) and m.alpha() == 1.0, "a route puts the mark at its end")
	m.update(Vector2i(5, 0), Vector2i(2, 0), false, 0.016)
	ok(m.alpha() == 1.0 and not m.fading, "and it stays while they walk")
	m.update(Vector2i(7, 0), Vector2i(2, 0), false, 0.016)
	ok(m.tile == Vector2i(7, 0), "a new click moves it")
	# arriving
	m.update(null, Vector2i(7, 0), false, 0.016)
	ok(m.fading and m.alpha() > 0.5, "arriving starts it fading")
	m.update(null, Vector2i(7, 0), false, MoveMarker.setting("fade_seconds") * 0.5)
	ok(m.alpha() > 0.0 and m.alpha() < 1.0, "part way through the fade it is part solid")
	m.update(null, Vector2i(7, 0), false, MoveMarker.setting("fade_seconds"))
	ok(not m.active and m.alpha() == 0.0, "and it is gone")
	# cancelling: faster than an arrival
	m.update(Vector2i(9, 0), Vector2i(0, 0), false, 0.016)
	m.update(null, Vector2i(3, 0), false, 0.016)
	ok(m.fading, "a walk ended before its tile fades the mark")
	m.update(null, Vector2i(3, 0), false, MoveMarker.setting("cancel_fade_seconds") + 0.01)
	ok(not m.active, "faster than an arrival would")
	# a click while it fades puts a fresh one
	m.update(Vector2i(9, 0), Vector2i(0, 0), false, 0.016)
	m.update(null, Vector2i(9, 0), false, 0.016)
	m.update(Vector2i(4, 4), Vector2i(9, 0), false, 0.016)
	ok(m.active and not m.fading and m.tile == Vector2i(4, 4) and m.alpha() == 1.0, "a click on a fading mark makes a new one")
	m.clear()
	# legs of a journey show no mark
	m.update(Vector2i(20, 0), Vector2i(0, 0), true, 0.016)
	ok(not m.active, "the legs of a walk to a town show no mark")
	# pulse
	m.update(Vector2i(5, 0), Vector2i(0, 0), false, 0.0)
	var seen := {}
	for i in 30:
		m.update(Vector2i(5, 0), Vector2i(0, 0), false, 0.05)
		seen[snappedf(m.pulse(), 0.01)] = true
	ok(seen.size() > 3, "the mark pulses")
	UiSettings.set_access("reduced_motion", true)
	var steady := true
	for i in 30:
		m.update(Vector2i(5, 0), Vector2i(0, 0), false, 0.05)
		if m.pulse() != 1.0:
			steady = false
	ok(steady, "with reduced motion it does not pulse")
	m.update(null, Vector2i(5, 0), false, 0.016)
	ok(not m.active, "and goes at once")
	UiSettings.set_access("reduced_motion", false)
	# drawing runs without error
	m.update(Vector2i(5, 0), Vector2i(0, 0), false, 0.016)
	var c := Painter.new()
	c.marker = m
	root.add_child(c)
	await process_frame
	ok(c.drawn, "the mark draws")
	c.queue_free()


func test_data() -> void:
	ok(Glide.validate().is_empty(), "the feel data is sound: %s" % str(Glide.validate()))
	var feel: Dictionary = GameSandbox.data()["feel"]
	var breaks := {"run_multiplier": 0.5, "heir_smooth_seconds": -1, "other_smooth_seconds": 5, "max_speed_tiles": 0, "snap_tiles": 0, "step_tiles": 0, "bob_tiles": 2, "bob_full_speed": 0, "hear_tiles": -1, "forget_frames": 0}
	for k in breaks:
		var was: Variant = feel[k]
		feel[k] = breaks[k]
		ok(not Glide.validate().is_empty(), "a bad %s is found" % k)
		feel[k] = was
	var was_m: Variant = feel["marker"]
	feel["marker"] = {"fade_seconds": 0}
	ok(not Glide.validate().is_empty(), "a bad marker table is found")
	feel.erase("marker")
	ok(not Glide.validate().is_empty(), "a missing marker is found")
	feel["marker"] = was_m
	var was_n: Variant = feel["bob_tiles"]
	feel["bob_tiles"] = "tall"
	ok(not Glide.validate().is_empty(), "a word for a number is found")
	feel["bob_tiles"] = was_n
	ok(Glide.validate().is_empty(), "and the data is back as it was")


func _click(map: Node, pos: Vector2, button: int) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	e.position = pos
	map._gui_input(e)
	var u := InputEventMouseButton.new()
	u.button_index = button
	u.pressed = false
	u.position = pos
	map._gui_input(u)


func test_screen() -> void:
	UiSettings.set_access("reduced_motion", false)
	WorldInput.reset_mouse()
	root.size = Vector2i(1280, 720)
	var app: Node = GameApp.new()
	root.add_child(app)
	await _frames(3)
	app.closed_badly = false
	app.new_game("Tess", "warrior", "faetouched", 7)
	await _frames(2)
	app.show_sandbox()
	await _frames(3)
	var map: Node = app.current
	ok(map is SandboxScreen, "the open world is up")
	var sb: GameSandbox = map.sb
	var d: GameDynasty = app.dynasty
	sb.creatures = []
	sb.companions = []
	await _frames(3)
	var keys_before := d.to_dict().keys()
	var state_before := d.rng.state
	var area := Vector2(map.size.x, map.size.y - map.BAR)
	var cell: float = map._cell()
	var centre := Vector2(0, map.BAR) + area * 0.5
	# the heir glides: a step leaves the view behind for a moment, then it catches up
	ok(map.heir_off.length() < 0.01, "at rest the view is on the heir (%s)" % str(map.heir_off))
	var before := sb.heir
	var r := {"ok": false}
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		r = sb.move(dir.x, dir.y)
		if bool(r["ok"]):
			break
	await process_frame
	await process_frame
	ok(bool(r["ok"]) and sb.heir != before, "the heir stepped")
	ok(map.heir_off.length() > 0.0 and map.heir_off.length() < 1.0, "the view trails the step (%s)" % str(map.heir_off))
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1500 and map.heir_off.length() > 0.0:
		await process_frame
	ok(map.heir_off.length() < 0.01, "and catches up (%s)" % str(map.heir_off))
	# the click's tile accounts for the glide: the same tile whether the view trails or not
	var tile_rest := SandboxScreen.tile_at(Vector2(300, 200), area, sb.heir, map.cam + map.heir_off, cell)
	ok(tile_rest == SandboxScreen.tile_at(Vector2(300, 200), area, sb.heir, map.cam, cell), "at rest a click's tile is as it was")
	# a click on bare ground (the select button, left by default) walks and puts the mark down
	ok(not map.move_marker.active, "no mark before a click")
	_click(map, centre + Vector2(0.0, -4.0 * cell), MOUSE_BUTTON_LEFT)
	ok(not sb.route.is_empty(), "a click on bare ground walks")
	await _frames(2)
	ok(map.move_marker.active and map.move_marker.tile == sb.route.back(), "and puts the mark where the route ends")
	# a key or the stick cancels: the walk ends and the mark goes quickly
	sb.cancel_walk()
	await process_frame
	await process_frame
	ok(map.move_marker.fading or not map.move_marker.active, "ending the walk fades the mark")
	await create_timer(MoveMarker.setting("cancel_fade_seconds") + 0.3).timeout
	ok(not map.move_marker.active, "which is gone soon")
	# arriving
	sb.cancel_walk()
	_click(map, centre + Vector2(2.0 * cell, 0.0), MOUSE_BUTTON_LEFT)
	await _frames(2)
	ok(map.move_marker.active, "a short walk has its mark: %s %s %s" % [str(sb.route), map.last_line, str(sb.heir)])
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000 and map.move_marker.active:
		await process_frame
	ok(not map.move_marker.active and sb.route.is_empty(), "and the mark is gone when they have arrived")
	# the mouse roles: with select on the right, the left button no longer walks and the right one does
	WorldInput.set_mouse("select", "right")
	sb.cancel_walk()
	_click(map, centre + Vector2(0.0, 3.0 * cell), MOUSE_BUTTON_LEFT)
	ok(sb.route.is_empty(), "with select remapped, the left button does not click to move")
	_click(map, centre + Vector2(0.0, 3.0 * cell), MOUSE_BUTTON_RIGHT)
	ok(not sb.route.is_empty(), "the remapped button does")
	await _frames(2)
	ok(map.move_marker.active, "with its mark")
	WorldInput.reset_mouse()
	sb.cancel_walk()
	# a footstep reaches the screen's signal with the ground under it
	var got: Array = []
	map.footstep.connect(func(who, kind, ground, foot, speed, near): got.append([who, kind, ground, foot, speed, near]))
	map.glide._step("heir", "heir", map.glide._st["heir"])
	ok(got.size() == 1 and str(got[0][0]) == "heir" and str(got[0][2]) != "", "a footstep comes with the ground it fell on: %s" % str(got))
	# nothing of it touches the dynasty or the save
	ok(d.rng.state == state_before, "no die of the dynasty was drawn")
	ok(d.to_dict().keys() == keys_before, "and the save has no new key")
	ok(JSON.stringify(d.to_dict()).find("heir_off") < 0 and JSON.stringify(d.to_dict()).find("move_marker") < 0, "nor a word of the look")
	# reduced motion: the view does not trail
	UiSettings.set_access("reduced_motion", true)
	sb.move(0, 1)
	await process_frame
	await process_frame
	ok(map.heir_off.length() < 0.001, "with reduced motion the view is on the heir at once")
	UiSettings.set_access("reduced_motion", false)
	app.queue_free()
	await _frames(2)


## A control that draws the mark, for the test (drawing is allowed only in _draw).
class Painter extends Control:
	var marker
	var drawn := false

	func _draw() -> void:
		marker.paint(self, Vector2(10, 10), 16.0, Color.WHITE)
		drawn = true
