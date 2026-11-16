## Where the heir last stood in the open world (GameDynasty.sandbox_at, GameSandbox.remember and load_at): a house that has
## never walked the world saves no key and so is the text it always was; a position saves and loads and the next walk
## starts there; an old save with no key loads clean; damaged values load as nothing and never crash; and the saved position is
## only used for the same heir (generation) at the same place, on a tile they can stand on, else the heir starts at the door.
## Run: godot --headless --path . -s res://tests/test_game_sandbox_position.gd
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
	test_unset()
	test_round_trip()
	test_old_and_damaged()
	test_when_it_applies()
	print("sandbox position tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _house() -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


func _step_to_land(s: GameSandbox, n: int) -> int:
	var moved := 0
	for dz in [-1, 0, 1]:
		for dx in [1, 0, -1]:
			if moved < n and (dx != 0 or dz != 0) and s.move(dx, dz)["ok"]:
				moved += 1
	return moved


func test_unset() -> void:
	var d := _house()
	ok(d.sandbox_at.is_empty(), "a new house has no saved position")
	ok(not d.to_dict().has("sandbox_at"), "so its save has no sandbox_at key and is the text it always was")
	var s := GameSandbox.start(d)
	ok(d.sandbox_at.is_empty(), "starting the sandbox does not set one by itself")
	var door := s.heir
	s.step(30)
	ok(d.sandbox_at.is_empty() and s.heir == door, "walking nothing and stepping time does not either")


func test_round_trip() -> void:
	var d := _house()
	var s := GameSandbox.start(d)
	var door := s.heir
	ok(_step_to_land(s, 2) >= 1, "the heir can walk a step or two")
	var spot := s.heir
	ok(spot != door, "the heir is not at the door now")
	s.remember()
	ok(d.sandbox_at["x"] == spot.x and d.sandbox_at["z"] == spot.y and d.sandbox_at["gen"] == d.gen, "remember writes the tile and the generation")
	var save := d.to_dict()
	ok(save.has("sandbox_at"), "a house that has walked saves its position")
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(save)))
	ok(back.sandbox_at == d.sandbox_at, "it comes back the same after a save and load")
	var s2 := GameSandbox.start(back)
	ok(s2.heir == spot, "the next walk starts where the heir stood")
	var s3 := GameSandbox.start(d)
	ok(s3.heir == spot, "and so does a walk on the same house without a save and load")


func test_old_and_damaged() -> void:
	var d := _house()
	var save := d.to_dict()
	ok(not save.has("sandbox_at"), "(an old save has no key)")
	var old := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(save)))
	ok(old.sandbox_at.is_empty(), "an old save loads with no position")
	var s := GameSandbox.start(old)
	ok(GameWorldGen.in_bounds(s.heir.x, s.heir.y), "and the heir starts at the door as before")
	var good := {"x": 10, "z": 20, "gen": 1, "place": "hearthmere"}
	ok(GameSandbox.load_at(good) == good, "a good position loads as it is")
	var bad: Array = [
		"text", 5, null, [], {},
		{"x": "10", "z": 20, "gen": 1, "place": "hearthmere"},
		{"x": 10, "z": 20, "gen": 1},
		{"x": 10, "z": 20, "gen": 1, "place": 7},
		{"x": 10, "z": 20, "place": "hearthmere"},
		{"x": 1e300, "z": 20, "gen": 1, "place": "hearthmere"},
		{"x": NAN, "z": 20, "gen": 1, "place": "hearthmere"},
		{"x": -5, "z": 20, "gen": 1, "place": "hearthmere"},
		{"x": 10, "z": 999999, "gen": 1, "place": "hearthmere"},
		{"x": true, "z": 20, "gen": 1, "place": "hearthmere"},
	]
	for v in bad:
		ok(GameSandbox.load_at(v).is_empty(), "a damaged position loads as nothing: %s" % str(v))
	var loose := GameSandbox.load_at({"x": 10.0, "z": 20.0, "gen": 1.0, "place": "hearthmere", "extra": 1})
	ok(loose == good, "whole numbers written as floats are read as whole, and extra keys are dropped")


func test_when_it_applies() -> void:
	var d := _house()
	var door := GameSandbox.start(d).heir
	var s := GameSandbox.start(d)
	_step_to_land(s, 2)
	var spot := s.heir
	s.remember()
	# the next heir (another generation) starts at the door
	d.gen += 1
	ok(GameSandbox.start(d).heir == door, "a later generation starts at the door, not where an ancestor stood")
	d.gen -= 1
	ok(GameSandbox.start(d).heir == spot, "(back to the same heir, the position applies again)")
	# the text game moved the heir to another place
	var other := ""
	for l in GameData.world["locations"]:
		if str(l["id"]) != str(d.world.location):
			other = str(l["id"])
			break
	var here := str(d.world.location)
	d.world.location = other
	ok(GameSandbox.start(d).heir != spot, "at another place the heir does not start at the old tile")
	d.world.location = here
	# the saved tile is water: a tile the heir cannot stand on
	var wet := Vector2i(-1, -1)
	var world := GameWorldGen.size()
	for z in range(0, world, 4):
		for x in range(0, world, 4):
			if wet.x < 0 and GameWorldGen.tile(d, x, z)["water"]:
				wet = Vector2i(x, z)
	if wet.x < 0:
		print("note: no water anywhere on this seed; the water fallback was not checked")
	else:
		d.sandbox_at = {"x": wet.x, "z": wet.y, "gen": d.gen, "place": here}
		ok(GameSandbox.start(d).heir == door, "a saved tile in the water falls back to the door")
