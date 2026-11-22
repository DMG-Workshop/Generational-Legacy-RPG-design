## Reach across walls (core/game/game_walls.gd `line_clear`, GameSandbox.reaches_heir, docs/REACH.md): a creature that is hunting the
## heir cannot start a fight through a wall, a tower, a building or a shut gate, however thin; it can through an open gate and across
## open ground; a diagonal never squeezes between two solid tiles; and the fight starts as before in the open.
## Run: godot --headless --path . -s res://tests/test_game_reach.gd
extends SceneTree

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
	test_wall()
	test_gate()
	test_corner()
	test_sandbox()
	print("reach tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## A column of the north wall of Hearthmere away from its gate: {x, wall_z_first, wall_z_last}.
func _north_wall() -> Dictionary:
	var a := GameWorldGen.anchor("hearthmere")
	var x := int(a["x"]) + 12
	var first := -1
	var last := -1
	for z in range(int(a["z"]) - 45, int(a["z"])):
		if GameWalls.kind_at(x, z) == "wall":
			if first < 0:
				first = z
			last = z
	return {"x": x, "first": first, "last": last}


func test_wall() -> void:
	var w := _north_wall()
	ok(int(w["first"]) > 0, "found the north wall")
	var x := float(w["x"]) + 0.5
	var outside := Vector2(x, float(w["first"]) - 0.5)
	var inside := Vector2(x, float(w["last"]) + 1.5)
	ok(not GameWalls.line_clear(outside, inside, false), "a blow does not pass through the wall")
	ok(not GameWalls.line_clear(inside, outside, false), "nor the other way")
	ok(GameWalls.line_clear(outside, outside + Vector2(0.0, -3.0), false), "open ground outside is clear")
	ok(GameWalls.line_clear(inside, inside + Vector2(0.0, 2.0), false), "and inside")
	var slant_out := Vector2(x - 2.0, float(w["first"]) - 0.5)
	var slant_in := Vector2(x + 2.0, float(w["last"]) + 1.5)
	ok(not GameWalls.line_clear(slant_out, slant_in, false), "a slanting line through the wall is stopped too")
	ok(GameWalls.line_clear(inside, inside, false), "a point reaches itself")


func test_gate() -> void:
	var g: Dictionary = GameWalls.gates("hearthmere")[0]
	var inner: Vector2i = g["inner"]
	var outer: Vector2i = g["outer"]
	var a := Vector2(float(inner.x) + 0.5, float(inner.y) + 0.5)
	var b := Vector2(float(outer.x) + 0.5, float(outer.y) + 0.5)
	ok(GameWalls.line_clear(a, b, false), "an open gate lets a blow through")
	ok(not GameWalls.line_clear(a, b, true), "a shut gate does not")
	var c: Vector2i = g["centre"]
	ok(GameWalls.line_clear(Vector2(float(c.x) + 0.5, float(c.y) + 0.5), b, true), "a creature standing in a shut gate's own passage is not walled off from outside it")


func test_corner() -> void:
	# two solid tiles that touch only at a corner (a diagonal wall): nothing squeezes between them, however thin the gap
	var solid := func(x: int, z: int) -> bool: return (x == 0 and z == 0) or (x == 1 and z == 1)
	ok(not GameWalls.line_clear(Vector2(1.5, 0.5), Vector2(0.5, 1.5), false, 0.25, solid), "a diagonal does not squeeze between two walls that meet at a corner")
	ok(GameWalls.line_clear(Vector2(1.5, 0.5), Vector2(2.5, 0.5), false, 0.25, solid), "beside them is clear")
	ok(not GameWalls.line_clear(Vector2(-0.5, 0.5), Vector2(1.5, 0.5), false, 0.25, solid), "through one is not")
	var thin := func(x: int, _z: int) -> bool: return x == 5   # a wall one tile thick, the thinnest there is
	ok(not GameWalls.line_clear(Vector2(4.9, 3.0), Vector2(6.1, 3.0), false, 0.25, thin), "a wall one tile thick stops a reach")
	var ring := func(x: int, z: int) -> bool: return (x + z) % 2 == 0 and absi(x) <= 3 and absi(z) <= 3   # a chequer: every step is a corner
	ok(not GameWalls.line_clear(Vector2(-0.5, 0.5), Vector2(0.5, -0.5), false, 0.25, ring), "a chequer of walls is no gap either")


func test_sandbox() -> void:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	var s := GameSandbox.start(d)
	s.creatures.clear()
	var p := s.heir_point()
	var near := GameBehaviour.new_agent(901, str(GameSpawn.wild()[0]["id"]), p.x + 0.5, p.y)
	near["mode"] = "chase"
	s.creatures.append(near)
	ok(s.reaches_heir(near, 1.5), "in the open a creature beside the heir reaches them")
	ok(s._contact(), "and starts the fight as before")
	# the same creature with a wall between: pretend the heir stands just inside the north wall
	var w := _north_wall()
	var d2 := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d2.pending_event = {}
	var s2 := GameSandbox.start(d2)
	s2.creatures.clear()
	s2.heir = Vector2i(int(w["x"]), int(w["last"]) + 1)
	var out := GameBehaviour.new_agent(902, str(GameSpawn.wild()[0]["id"]), float(w["x"]) + 0.5, float(w["first"]) - 0.5)
	out["mode"] = "chase"
	s2.creatures.append(out)
	ok(s2.heir_point().distance_to(Vector2(out["x"], out["z"])) < 6.0, "the creature is just outside the wall")
	ok(not s2.reaches_heir(out, 6.0), "it cannot reach a heir on the other side of it")
	var before := s2.creatures.size()
	ok(not s2._contact() and s2.creatures.size() == before, "so no fight starts and the creature stays in the world")
