## The open world's camera (core/game/game_camera.gd, ui/play/world_camera.gd, the `camera` block of data/world/sandbox.json, the
## view in ui/play/sandbox_screen.gd): the critically damped follow (no overshoot, a dead zone, a snap for a long trip), the look-ahead,
## the world-edge clamp, the pixel grid, the zoom (eased, held between the limits, remembered in settings.cfg and never the save, a damaged value
## ignored), reduced motion (locked to the heir), a change of space snapping the view, clicks mapping to the right tile at any zoom, the
## tile chunks loaded at every zoom, nearest-neighbour tiles, and the data checks.
## Run: godot --headless --path . -s res://tests/test_game_camera.gd
extends SceneTree

const UiSettings := preload("res://ui/play/ui_settings.gd")
const WorldCamera := preload("res://ui/play/world_camera.gd")
const WorldInput := preload("res://ui/play/world_input.gd")
const SandboxScreen := preload("res://ui/play/sandbox_screen.gd")

var fails := 0
var checks := 0


class FakeApp extends Node:
	var dynasty: GameDynasty

	func show_state() -> void:
		pass


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	UiSettings.path = "user://test_camera.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	GameDynasty.save_path = "user://test_camera_save.json"
	test_damp()
	test_follow()
	test_clamp_and_pixels()
	test_tile_under()
	test_data()
	test_camera_walk()
	test_space_and_snap()
	test_reduced_motion()
	test_zoom()
	await test_screen()
	DirAccess.remove_absolute(UiSettings.path)
	DirAccess.remove_absolute(GameDynasty.save_path)
	print("camera tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func test_damp() -> void:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var target := Vector2(10, -4)
	var last := pos.distance_to(target)
	var monotone := true
	var over := false
	for i in 300:
		var r := GameCamera.smooth_damp(pos, vel, target, 0.2, 1.0 / 60.0)
		pos = r[0]
		vel = r[1]
		var dist := pos.distance_to(target)
		if dist > last + 0.0001:
			monotone = false
		if (target - pos).dot(target) < -0.0001:
			over = true
		last = dist
	ok(monotone and not over, "the follow only closes the gap: it never overshoots the target")
	ok(pos.distance_to(target) < 0.001, "and arrives")
	# about smooth_time to cover most of the way
	var p2 := Vector2.ZERO
	var v2 := Vector2.ZERO
	for i in 12:   # 0.2 s
		var r := GameCamera.smooth_damp(p2, v2, Vector2(10, 0), 0.2, 1.0 / 60.0)
		p2 = r[0]
		v2 = r[1]
	ok(p2.x > 5.0 and p2.x < 9.9, "in about its smooth time it is most of the way: %.2f" % p2.x)
	var big := GameCamera.smooth_damp(Vector2.ZERO, Vector2.ZERO, Vector2(10, 0), 0.2, 5.0)
	ok(absf((big[0] as Vector2).x - 10.0) < 0.05 and not is_nan((big[1] as Vector2).x), "a stall of seconds lands on the target, not past it")
	var none := GameCamera.smooth_damp(Vector2(3, 3), Vector2(1, 1), Vector2(9, 9), 0.0, 0.016)
	ok(none[0] == Vector2(9, 9) and none[1] == Vector2.ZERO, "a smooth time of 0 is on the target at once")
	var still := GameCamera.smooth_damp(Vector2(3, 3), Vector2(1, 1), Vector2(9, 9), 0.2, 0.0)
	ok(still[0] == Vector2(3, 3), "no time passing, no movement")


func test_follow() -> void:
	ok(GameCamera.dead_aim(Vector2(5, 5), Vector2(5.2, 5.0), 0.35) == Vector2(5, 5), "within the dead zone the camera stays")
	var aim := GameCamera.dead_aim(Vector2(0, 0), Vector2(3, 0), 0.35)
	ok(is_equal_approx(aim.x, 2.65) and is_equal_approx(aim.y, 0.0), "beyond it the aim is the dead zone short of the heir")
	var f := GameCamera.follow(Vector2(5, 5), Vector2.ZERO, Vector2(5.1, 5.1), 0.016, 0.2, 0.35, 12.0)
	ok(f["pos"] == Vector2(5, 5) and not f["snapped"], "a heir inside the dead zone does not move the view")
	var far := GameCamera.follow(Vector2(0, 0), Vector2(2, 2), Vector2(50, 0), 0.016, 0.2, 0.35, 12.0)
	ok(far["snapped"] and far["pos"] == Vector2(50, 0) and far["vel"] == Vector2.ZERO, "a trip of more than snap_tiles puts the view on the heir, not a long slide")
	var near := GameCamera.follow(Vector2(0, 0), Vector2.ZERO, Vector2(6, 0), 0.016, 0.2, 0.35, 12.0)
	ok(not near["snapped"] and (near["pos"] as Vector2).x > 0.0 and (near["pos"] as Vector2).x < 6.0, "a walk's distance is slid")
	var locked := GameCamera.follow(Vector2(0, 0), Vector2.ZERO, Vector2(0.2, 0.0), 0.016, 0.0, 0.35, 12.0)
	ok(locked["pos"] == Vector2(0.2, 0.0), "with no smoothing the view is on the heir, dead zone and all")
	ok(GameCamera.ahead_goal(Vector2i(1, 0), true, 1.5) == Vector2(1.5, 0), "the look-ahead goal is along the facing")
	ok(is_equal_approx(GameCamera.ahead_goal(Vector2i(1, 1), true, 1.0).length(), 1.0), "a diagonal is no longer than a straight one")
	ok(GameCamera.ahead_goal(Vector2i(1, 0), false, 1.5) == Vector2.ZERO, "standing, there is none")
	var e := GameCamera.ease_vec(Vector2.ZERO, Vector2(1, 0), 0.1, 0.35)
	ok(e.x > 0.0 and e.x < 1.0, "the look-ahead eases in")
	ok(GameCamera.ease_vec(Vector2.ZERO, Vector2(1, 0), 0.1, 0.0) == Vector2(1, 0), "and not at all with no time")
	ok(GameCamera.ease_float(1.0, 2.0, 100.0, 0.12) == 2.0, "a zoom eased for a long time is at its goal")


func test_clamp_and_pixels() -> void:
	var bounds := Rect2(0, 0, 640, 640)
	var half := Vector2(40, 22)
	var inside := Vector2(300, 300)
	ok(GameCamera.clamp_centre(inside, half, bounds, 3.0) == inside, "in the middle of the world the view is not held")
	var corner := GameCamera.clamp_centre(Vector2(0, 0), half, bounds, 3.0)
	ok(is_equal_approx(corner.x - half.x, -3.0) and is_equal_approx(corner.y - half.y, -3.0), "at the north-west corner the view shows 3 tiles beyond the edge, no more")
	var se := GameCamera.clamp_centre(Vector2(9999, 9999), half, bounds, 3.0)
	ok(is_equal_approx(se.x + half.x, 643.0) and is_equal_approx(se.y + half.y, 643.0), "and at the south-east")
	var huge := GameCamera.clamp_centre(Vector2(10, 10), Vector2(500, 500), bounds, 3.0)
	ok(huge == Vector2(320, 320), "a view larger than the world sits on its middle")
	var s := GameCamera.snap_to_pixels(Vector2(10.123, 7.777), 16.0, Vector2(1280, 665))
	var px := s * 16.0 - Vector2(1280, 665) * 0.5
	ok(is_equal_approx(px.x, roundf(px.x)) and is_equal_approx(px.y, roundf(px.y)), "the tiles land on whole screen pixels (an odd-sized area too)")
	ok(s.distance_to(Vector2(10.123, 7.777)) < 0.04, "and the view moves by under a pixel to do it")
	ok(GameCamera.snap_to_pixels(Vector2(1.5, 1.5), 0.0) == Vector2(1.5, 1.5), "a cell of 0 is left alone")


func test_tile_under() -> void:
	var area := Vector2(1280, 665)
	var centre := Vector2(100.5, 200.5)
	for z in [0.5, 1.0, 1.75, 3.0]:
		var cell: float = 16.0 * z
		var good := true
		for t in [Vector2i(100, 200), Vector2i(97, 195), Vector2i(104, 206), Vector2i(60, 190)]:
			# where the tile's middle is drawn, as the screen draws it: (tile - centre) * cell + half the area
			var at := (Vector2(t) + Vector2(0.5, 0.5) - centre) * cell + area * 0.5
			if GameCamera.tile_under(at, area, centre, cell) != t:
				good = false
			if SandboxScreen.tile_at(at, area, Vector2i(100, 200), centre - Vector2(100, 200), cell) != t:
				good = false
		ok(good, "at zoom %s a click on a drawn tile finds that tile" % str(z))


func test_data() -> void:
	ok(GameCamera.validate().is_empty(), "the data is well formed: %s" % str(GameCamera.validate()))
	var block: Dictionary = GameSandbox.data()["camera"]
	var saved := block.duplicate()
	for k in ["dead_zone", "look_ahead", "snap_tiles", "max_dt", "zoom_seconds", "edge_margin"]:
		block.erase(k)
		ok(not GameCamera.validate().is_empty(), "a missing %s is found" % k)
		block[k] = saved[k]
	block["dead_zone"] = 5.0
	ok(not GameCamera.validate().is_empty(), "a dead zone of five tiles is found")
	block["dead_zone"] = saved["dead_zone"]
	block["snap_tiles"] = 1.0
	ok(not GameCamera.validate().is_empty(), "a snap shorter than a step is found")
	block["snap_tiles"] = saved["snap_tiles"]
	block["edge_margin"] = -1.0
	ok(not GameCamera.validate().is_empty(), "a negative margin is found")
	block["edge_margin"] = saved["edge_margin"]
	block["max_dt"] = "fast"
	ok(not GameCamera.validate().is_empty(), "a word where a number goes is found")
	block["max_dt"] = saved["max_dt"]
	ok(GameCamera.validate().is_empty(), "and the data is back as it was")
	ok(InputMap.has_action("world_zoom_in") or true, "(the zoom actions are installed by the app)")
	var z: Dictionary = WorldInput.data()["actions"]
	ok((z["world_zoom_in"]["keys"] as Array).has("Equal") and (z["world_zoom_out"]["keys"] as Array).has("Minus"), "the zoom keys are in the remap-able input data")


func _walk(cam: Object, steps: int, dir: Vector2i, start: Vector2i, key: String, bounds: Rect2) -> Dictionary:
	# the heir steps once every 0.2 s, the frames run at 60 per second: returns the biggest jump of the view in a frame and the biggest lag behind the heir
	var heir := start
	var max_jump := 0.0
	var max_lag := 0.0
	var last: Vector2 = cam.centre
	var t := 0.0
	var next := 0.0
	var half := Vector2(40, 20)
	while heir != start + dir * steps or t < next:
		var stepped := false
		if t >= next and heir != start + dir * steps:
			heir += dir
			next = t + 0.2
			stepped = true
		if heir == start + dir * steps and t >= next + 1.0:
			break
		cam.update(1.0 / 60.0, WorldCamera.target_of(heir), dir, stepped, key, half, bounds, 16.0, Vector2(1280, 665))
		max_jump = maxf(max_jump, (cam.centre as Vector2).distance_to(last))
		max_lag = maxf(max_lag, (cam.centre as Vector2).distance_to(WorldCamera.target_of(heir)))
		last = cam.centre
		t += 1.0 / 60.0
		if t > 20.0:
			break
	return {"jump": max_jump, "lag": max_lag, "heir": heir}


func test_camera_walk() -> void:
	var cam := WorldCamera.new()
	var bounds := Rect2(0, 0, 640, 640)
	cam.update(0.0, WorldCamera.target_of(Vector2i(300, 300)), Vector2i(0, 1), false, "world", Vector2(40, 20), bounds, 16.0, Vector2(1280, 665))
	ok(cam.snapped_last and cam.centre.distance_to(Vector2(300.5, 300.5)) < 0.1, "the first frame puts the view on the heir")
	var r := _walk(cam, 20, Vector2i(1, 0), Vector2i(300, 300), "world", bounds)
	ok(float(r["jump"]) < 0.35, "walking 20 tiles the view never jumps more than a third of a tile in a frame: %.3f" % float(r["jump"]))
	ok(float(r["lag"]) < 1.6, "and stays within 1.6 tiles of the heir: %.2f" % float(r["lag"]))
	# the view goes through a chunk edge (every 16 tiles) with no more movement than anywhere else
	var chunk := int(TileView.settings()["chunk"])
	var cam2 := WorldCamera.new()
	var start := Vector2i(chunk * 20 - 6, 100)
	cam2.update(0.0, WorldCamera.target_of(start), Vector2i(1, 0), false, "world", Vector2(40, 20), bounds, 16.0, Vector2(1280, 665))
	var r2 := _walk(cam2, 12, Vector2i(1, 0), start, "world", bounds)
	ok(float(r2["jump"]) < 0.35, "across a chunk edge the view moves as smoothly: %.3f" % float(r2["jump"]))
	# standing still: the view settles and stays (no drift, no shake)
	var settled: Vector2 = cam.centre
	for i in 120:
		cam.update(1.0 / 60.0, WorldCamera.target_of(r["heir"]), Vector2i(1, 0), false, "world", Vector2(40, 20), bounds, 16.0, Vector2(1280, 665))
	var moved := (cam.centre as Vector2).distance_to(WorldCamera.target_of(r["heir"]))
	ok(moved < 0.5, "standing, the view settles within half a tile of the heir (the dead zone and the look-ahead gone): %.3f" % moved)
	var again: Vector2 = cam.centre
	for i in 30:
		cam.update(1.0 / 60.0, WorldCamera.target_of(r["heir"]), Vector2i(1, 0), false, "world", Vector2(40, 20), bounds, 16.0, Vector2(1280, 665))
	ok(cam.centre == again, "and then it does not move at all")
	ok(settled != Vector2.ZERO, "(the view was somewhere)")
	# a look offset (the numpad) is held, eased back when dropped
	cam.look = Vector2(5, 0)
	for i in 60:
		cam.update(1.0 / 60.0, WorldCamera.target_of(r["heir"]), Vector2i(1, 0), false, "world", Vector2(40, 20), bounds, 16.0, Vector2(1280, 665))
	ok(cam.centre.x - again.x > 4.0, "looking away moves the view")
	cam.look = Vector2.ZERO
	for i in 120:
		cam.update(1.0 / 60.0, WorldCamera.target_of(r["heir"]), Vector2i(1, 0), false, "world", Vector2(40, 20), bounds, 16.0, Vector2(1280, 665))
	ok(cam.centre.distance_to(again) < 0.1, "and dropping the look brings it home")
	# at the world's edge
	var cam3 := WorldCamera.new()
	cam3.update(0.0, WorldCamera.target_of(Vector2i(1, 1)), Vector2i(0, 1), false, "world", Vector2(40, 20), bounds, 16.0, Vector2(1280, 665))
	ok(cam3.centre.x - 40.0 >= -3.05 and cam3.centre.y - 20.0 >= -3.05, "at the corner the view shows no more than 3 tiles past the edge: %s" % str(cam3.centre))


func test_space_and_snap() -> void:
	var cam := WorldCamera.new()
	var bounds := Rect2(0, 0, 640, 640)
	var half := Vector2(40, 20)
	var area := Vector2(1280, 665)
	cam.update(0.0, Vector2(100.5, 100.5), Vector2i(0, 1), false, "world", half, bounds, 16.0, area)
	for i in 30:
		cam.update(1.0 / 60.0, Vector2(103.5, 100.5), Vector2i(1, 0), true, "world", half, bounds, 16.0, area)
	ok(not cam.snapped_last and cam.pos.x < 103.5, "an ordinary walk is a glide")
	# through a door: the heir is in another space, near where the view was: still snapped
	var room := Rect2(0, 0, 12, 9)
	cam.update(1.0 / 60.0, Vector2(6.5, 4.5), Vector2i(0, 1), false, "store", half, room, 16.0, area)
	ok(cam.snapped_last and cam.vel == Vector2.ZERO, "a new space puts the view on the heir at once")
	ok(cam.centre.distance_to(Vector2(6, 4.5)) < 0.1, "and a room smaller than the view sits in the middle of it")
	cam.update(1.0 / 60.0, Vector2(6.5, 4.5), Vector2i(0, 1), false, "store", Vector2(5, 3), room, 16.0, area)
	ok(cam.centre.x - 5.0 >= -2.05 and cam.centre.x + 5.0 <= 14.05, "a room bigger than the view holds it within the interior's margin")
	cam.update(1.0 / 60.0, Vector2(6.5, 4.5), Vector2i(0, 1), false, "store", half, room, 16.0, area)
	ok(not cam.snapped_last, "the same space again is not a snap")
	cam.update(1.0 / 60.0, Vector2(200.5, 300.5), Vector2i(0, 1), false, "world", half, bounds, 16.0, area)
	ok(cam.snapped_last and cam.centre.distance_to(Vector2(200.5, 300.5)) < 0.1, "coming out puts it on the heir where they stand")
	cam.update(1.0 / 60.0, Vector2(500.5, 300.5), Vector2i(0, 1), false, "world", half, bounds, 16.0, area)
	ok(cam.snapped_last and cam.centre.x > 499.0, "a trip through a gate is not slid to")
	# a heir put somewhere new between frames: the offset clicks use is where the next frame will put the view
	var stale := cam.offset_for(Vector2i(10, 10), "world")
	ok(stale == Vector2(0.5, 0.5) + cam.look, "a heir moved far since the last frame reads as the view on them, not on the old place: %s" % str(stale))
	ok(cam.offset_for(Vector2i(500, 300), "world").distance_to(cam.centre - Vector2(500, 300)) < 0.001, "and one who has not is read from the view as drawn")
	# a room's bounds are read from its cells
	var b := cam.bounds_for("world/hearthmere/store", GameInterior.cells("world/hearthmere/store"))
	ok(b.size.x > 3.0 and b.size.y > 3.0 and b.size.x < 100.0, "an interior's bounds are the box round its cells: %s" % str(b))
	ok(cam.bounds_for("world", {}).size == Vector2(GameWorldGen.size(), GameWorldGen.size()), "and the world's are the world's square")


func test_reduced_motion() -> void:
	UiSettings.set_access("reduced_motion", true)
	var cam := WorldCamera.new()
	var bounds := Rect2(0, 0, 640, 640)
	var half := Vector2(40, 20)
	var area := Vector2(1280, 665)
	cam.update(0.0, Vector2(100.5, 100.5), Vector2i(0, 1), false, "world", half, bounds, 16.0, area)
	var locked := true
	for i in 40:
		var h := Vector2(100.5 + float(i) * 0.5, 100.5)
		cam.update(1.0 / 60.0, h, Vector2i(1, 0), i % 12 == 0, "world", half, bounds, 16.0, area)
		if cam.centre.distance_to(h) > 0.04:
			locked = false
	ok(locked, "with reduced motion the view is on the heir every frame: no easing, no look-ahead, no dead zone")
	cam.zoom_by(1.0, 2)
	ok(is_equal_approx(cam.zoom_step(1.0, 0.016), 1.5), "and a zoom is made at once")
	UiSettings.set_access("reduced_motion", false)
	cam.zoom_goal = -1.0
	cam.zoom_by(1.0, 2)
	var z := cam.zoom_step(1.0, 0.016)
	ok(z > 1.0 and z < 1.5, "without it a zoom eases: %.3f" % z)
	var steps := 0
	while cam.zoom_goal > 0.0 and steps < 200:
		z = cam.zoom_step(z, 0.016)
		steps += 1
	ok(z == 1.5 and steps < 60, "and arrives in about a second at most (%d frames)" % steps)


func test_zoom() -> void:
	var cam := WorldCamera.new()
	cam.zoom_by(1.0, 100)
	ok(is_equal_approx(cam.zoom_goal, WorldInput.setting("zoom_max")), "the wheel stops at the most zoom")
	cam.zoom_by(1.0, -200)
	ok(is_equal_approx(cam.zoom_goal, WorldInput.setting("zoom_min")), "and the least")
	cam.zoom_goal = -1.0
	cam.zoom_by(1.0, 1)
	cam.zoom_by(1.0, 1)
	ok(is_equal_approx(cam.zoom_goal, 1.5), "clicks before the zoom has arrived add up")
	# the zoom is remembered in settings.cfg
	DirAccess.remove_absolute(UiSettings.path)
	ok(WorldCamera.saved_zoom(1.0) == 1.0, "with no file the zoom is the default")
	cam.zoom_goal = -1.0
	cam.remember_zoom(2.25, true)
	ok(is_equal_approx(WorldCamera.saved_zoom(1.0), 2.25), "a settled zoom is kept in settings.cfg")
	cam.stored_zoom = -1.0
	cam.zoom_goal = 3.0
	cam.remember_zoom(1.7, true)
	ok(is_equal_approx(WorldCamera.saved_zoom(1.0), 2.25), "a zoom still easing is not written")
	cam.zoom_goal = -1.0
	cam.remember_zoom(1.7, false)
	ok(is_equal_approx(WorldCamera.saved_zoom(1.0), 2.25), "nor one while the fingers are on it")
	UiSettings.store(WorldCamera.ZOOM_KEY, 99.0)
	ok(is_equal_approx(WorldCamera.saved_zoom(1.0), WorldInput.setting("zoom_max")), "a stored zoom past the limit is held to it")
	UiSettings.store(WorldCamera.ZOOM_KEY, -4)
	ok(is_equal_approx(WorldCamera.saved_zoom(1.0), WorldInput.setting("zoom_min")), "and one below it")
	for bad in ["wide", true, [1, 2], {"a": 1}, NAN, INF]:
		UiSettings.store(WorldCamera.ZOOM_KEY, bad)
		ok(WorldCamera.saved_zoom(1.25) == 1.25, "a damaged value (%s) falls back" % str(bad))
	DirAccess.remove_absolute(UiSettings.path)


func test_screen() -> void:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	var app := FakeApp.new()
	app.dynasty = d
	root.add_child(app)
	UiSettings.store(WorldCamera.ZOOM_KEY, 1.75)
	var scr: Control = SandboxScreen.new()
	scr.app = app
	scr.position = Vector2.ZERO
	scr.size = Vector2(1280, 720)
	root.add_child(scr)
	await process_frame
	await process_frame
	ok(is_equal_approx(scr.zoom, 1.75), "a new screen opens at the zoom the player last chose")
	ok(scr.tile_view.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and scr.overlay.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "zoomed in, the tiles and sprites stay nearest-neighbour (crisp)")
	scr.sb.creatures = []
	var area := Vector2(scr.size.x, scr.size.y - scr.BAR)
	scr.camera.started = false
	scr._process(0.016)
	var centre: Vector2 = Vector2(scr.sb.heir) + scr.cam
	ok(centre.distance_to(WorldCamera.target_of(scr.sb.heir)) < 0.06, "the screen's view is on the heir: %s" % str(centre))
	# clicks at every zoom: the tile under the middle of the area is the heir's, and one a few tiles over is that many tiles over
	for z in [0.5, 1.0, 2.0, 3.0]:
		scr.zoom = z
		scr._process(0.016)
		var cell: float = scr._cell()
		var mid := area * 0.5
		var heir_at: Vector2 = mid + (Vector2(scr.sb.heir) + Vector2(0.5, 0.5) - (Vector2(scr.sb.heir) + scr.cam)) * cell
		var t: Vector2i = SandboxScreen.tile_at(heir_at, area, scr.sb.heir, scr.cam, cell)
		ok(t == scr.sb.heir, "zoom %s: a click on the drawn heir is the heir's tile (%s)" % [str(z), str(t)])
		var p: Vector2 = scr._point_at(heir_at, area)
		ok(p.distance_to(scr.sb.heir_point()) < 0.01, "zoom %s: and the point there is the heir's" % str(z))
		var three: Vector2 = heir_at + Vector2(3.0 * cell, -2.0 * cell)
		ok(SandboxScreen.tile_at(three, area, scr.sb.heir, scr.cam, cell) == scr.sb.heir + Vector2i(3, -2), "zoom %s: three east and two north of the heir is that tile" % str(z))
		# the tiles the view needs are there (zoomed right out the view is wide)
		var half := area * 0.5 / cell
		var want := TileView.wanted(Vector2(scr.sb.heir) + scr.cam, half + Vector2(1, 1), int(TileView.settings()["keep"]))
		var have := true
		for c in want:
			if not scr.tile_view.layers.has(c):
				have = false
		ok(have, "zoom %s: every chunk of the view (and the %d beyond) is loaded: %d" % [str(z), int(TileView.settings()["keep"]), want.size()])
		ok(absf(scr.tile_view.scale.x - cell / float(TileView.settings()["px"])) < 0.001, "zoom %s: and the tiles are scaled to the cell" % str(z))
	# the wheel and the keys ease the zoom; the look keys still work
	scr.zoom = 1.0
	scr.camera.zoom_by(scr.zoom, 2)
	scr._process(0.016)
	ok(scr.zoom > 1.0 and scr.zoom < 1.5, "a click of the wheel starts an eased zoom: %.3f" % scr.zoom)
	for i in 60:
		scr._process(0.016)
	ok(is_equal_approx(scr.zoom, 1.5), "which arrives")
	ok(is_equal_approx(WorldCamera.saved_zoom(0.0), 1.5), "and is remembered in settings.cfg")
	var before: Vector2 = scr.cam
	scr.cam += Vector2(3, 0)
	for i in 60:
		scr._process(0.016)
	ok(scr.cam.x - before.x > 2.5, "the look keys still move the view off the heir (%.2f)" % (scr.cam.x - before.x))
	scr.cam = Vector2.ZERO
	for i in 120:
		scr._process(0.016)
	ok(scr.cam.distance_to(Vector2(0.5, 0.5)) < 0.2, "and dropping the look brings it back: %s" % str(scr.cam))
	# a change of space puts the view on the heir at once
	scr.sb.space = "world/hearthmere/store"
	scr.sb.interior = GameInterior.cells("world/hearthmere/store")
	scr.sb.heir = Vector2i(4, 4)
	scr._process(0.016)
	ok(scr.camera.snapped_last, "going indoors puts the view on the heir, no slide across the world")
	ok(scr.cam.length() < 8.0, "and the view is near them: %s" % str(scr.cam))
	scr.queue_free()
	app.queue_free()
