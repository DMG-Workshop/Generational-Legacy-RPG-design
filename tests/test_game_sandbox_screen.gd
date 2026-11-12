## The sandbox screen (roadmap items 39 and 51; ui/play/sandbox_screen.gd and GameSandbox's routes): the view's numbers are
## data; the map's tile under a point is the heir's tile at the centre and moves a cell per cell; a move vector means one of
## eight steps (or none under the threshold); a tap's route walks the heir to the tile over land, one tile at a time, and
## refuses water and the same tile sensibly; the day's light and tint are there for the view; and the screen can be made
## without a window. The drawing itself is checked by the screenshot tool, not here.
## Run: godot --headless --path . -s res://tests/test_game_sandbox_screen.gd
extends SceneTree

const SandboxScreen := preload("res://ui/play/sandbox_screen.gd")

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	test_data()
	test_tiles()
	test_steps()
	test_routes()
	test_day()
	print("sandbox screen tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _house() -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 5000
	return d


func test_data() -> void:
	var view: Dictionary = GameSandbox.data()["view"]
	for key in ["cell_px", "cam_tiles_per_second", "move_threshold", "save_seconds", "dim_floor"]:
		ok(view.has(key), "view setting %s is in the data" % key)
	var colors: Dictionary = GameSandbox.data()["colors"]
	for key in ["water", "land", "built", "route", "heir", "creature", "companion"]:
		ok(colors.has(key) and (colors[key] as Array).size() == 3, "colour %s has three parts" % key)
	ok(GameSandbox.data()["text"].has("no_route"), "the no-route text is in the data")


func test_tiles() -> void:
	var area := Vector2(320, 240)
	var heir := Vector2i(10, -4)
	var cell := 16.0
	ok(SandboxScreen.tile_at(area * 0.5, area, heir, Vector2.ZERO, cell) == heir, "the centre of the view is the heir's tile")
	ok(SandboxScreen.tile_at(area * 0.5 + Vector2(cell, 0), area, heir, Vector2.ZERO, cell) == heir + Vector2i(1, 0), "one cell right is the next tile east")
	ok(SandboxScreen.tile_at(area * 0.5 + Vector2(0, -cell), area, heir, Vector2.ZERO, cell) == heir + Vector2i(0, -1), "one cell up is the tile north")
	ok(SandboxScreen.tile_at(area * 0.5 + Vector2(cell * 0.5, 0), area, heir, Vector2.ZERO, cell) == heir, "half a cell to the right is still the heir's tile")
	ok(SandboxScreen.tile_at(area * 0.5, area, heir, Vector2(3, 0), cell) == heir + Vector2i(3, 0), "a camera offset moves the view")


func test_steps() -> void:
	ok(SandboxScreen.step_for(Vector2.ZERO) == Vector2i.ZERO, "no move is no step")
	ok(SandboxScreen.step_for(Vector2(0.05, 0.05)) == Vector2i.ZERO, "a move under the threshold is no step")
	ok(SandboxScreen.step_for(Vector2(1, 0.1)) == Vector2i(1, 0), "a move mostly east is one step east")
	ok(SandboxScreen.step_for(Vector2(-1, -1)) == Vector2i(-1, -1), "a diagonal move is one diagonal step")
	ok(SandboxScreen.step_for(Vector2(0, 1)) == Vector2i(0, 1), "a move south is one step south")


func test_routes() -> void:
	var d := _house()
	var s := GameSandbox.start(d)
	var from := s.heir
	ok(s.set_route(from)["ok"] and s.route.is_empty(), "a route to the tile the heir stands on is empty and fine")
	ok(not s.walk_one(), "walking with no route does nothing")
	# A dry target a few tiles away, found by looking, so the test follows the seed and never hard-codes a map.
	var target := Vector2i(-99, -99)
	var planned := {"ok": false, "why": "", "steps": 0}
	for r in range(2, 9):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if target.x != -99 or (absi(dx) != r and absi(dz) != r):
					continue
				var t := from + Vector2i(dx, dz)
				if GameWorldGen.tile(d, t.x, t.y)["water"] or not GameWorldGen.in_bounds(t.x, t.y):
					continue
				var p := s.set_route(t)
				if p["ok"] and int(p["steps"]) >= 2:
					target = t
					planned = p
	ok(target.x != -99, "a dry tile a few steps away can be routed to")
	if target.x == -99:
		return
	ok(planned["steps"] == s.route.size() and s.route.back() == target, "the route ends at the target")
	var walked := 0
	while not s.route.is_empty() and walked < 200:
		ok(s.walk_one(), "each step of the route is taken")
		walked += 1
	ok(s.heir == target, "walking the route brings the heir to the target")
	# Water: find a wet tile near the heir on this seed; a route there is refused (the walker keeps off water).
	var wet := Vector2i(-99, -99)
	for dz in range(-6, 7):
		for dx in range(-6, 7):
			var t := s.heir + Vector2i(dx, dz)
			if wet.x == -99 and GameWorldGen.in_bounds(t.x, t.y) and GameWorldGen.tile(d, t.x, t.y)["water"]:
				wet = t
	if wet.x == -99:
		print("note: no water within six tiles of the heir on this seed; the water route was not checked")
	else:
		var refused := s.set_route(wet)
		ok(not refused["ok"] and str(refused["why"]) != "", "a route onto water is refused with a reason")
		ok(s.route.is_empty(), "a refused route leaves no route")


func test_day() -> void:
	var d := _house()
	var look := GameDay.look(d)
	ok(look.has("light") and look.has("weather") and look.has("tint"), "the day gives its light, weather and tint")
	ok((look["tint"] as Array).size() == 3, "the tint has three parts")
	ok(float(look["light"]) >= 0.0 and float(look["light"]) <= 1.0, "the light is between 0 and 1")
	var screen := SandboxScreen.new()
	ok(is_equal_approx(float(SandboxScreen.setting("cell_px")), 16.0), "the screen can be made without a window")
	screen.free()
