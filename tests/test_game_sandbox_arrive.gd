## Walking into a town's ground (roadmap item 41): the heir stepping onto the ground of a place (GameSpaces.at_tile) makes it the
## family's place, as a journey would, but with no years, no event and no dice; the place is marked visited (with the first-time
## line once), its quests are told, walking about inside it changes nothing, leaving it for open ground keeps the place, and
## nothing happens upstairs or indoors. Nothing here is saved beyond what a journey saves (location, visited).
## Run: godot --headless --path . -s res://tests/test_game_sandbox_arrive.gd
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
	test_arrive()
	test_real_step()
	test_not_arriving()
	print("sandbox arrive tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh() -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


## A tile just inside a town's ground, at its door.
func _door(place: String) -> Vector2i:
	var door: Dictionary = GameSpaces.space("world/%s" % place)["door"]
	return Vector2i(int(door["x"]), int(door["z"]))


func test_arrive() -> void:
	var d := _fresh()
	var s := GameSandbox.start(d)
	s.creatures.clear()
	ok(d.world.location == "hearthmere" and "ironford" not in d.world.visited, "(the family is at Hearthmere, Ironford unvisited)")
	var year := d.world.year
	var rng_state := d.rng.state
	var logged := s.log.size()
	s.heir = _door("ironford")
	s._arrive()
	ok(d.world.location == "ironford", "standing on Ironford's ground makes it the family's place")
	ok("ironford" in d.world.visited, "and it is visited")
	ok(d.world.year == year and d.rng.state == rng_state, "no years pass and no dice are drawn")
	ok(s.arrived == "ironford" and s.log.size() == logged + 2 and str(s.log[logged]["text"]).contains("Ironford"), "the log says so, with the first-time line: %s" % str(s.log.slice(logged)))
	ok(str(s.log[logged + 1]["text"]).contains(d.dynasty_name), "naming the house")
	var count := s.log.size()
	s.heir += Vector2i(1, 0)
	s._arrive()
	ok(s.log.size() == count, "stepping about inside it says nothing more")
	s.heir = _door("hearthmere")
	s._arrive()
	ok(d.world.location == "hearthmere" and s.log.size() == count + 1, "walking back to Hearthmere arrives again, with no first-time line")
	s.heir = _door("ironford")
	s._arrive()
	ok(s.log.size() == count + 2, "and Ironford again says only the arrival")
	# open ground between towns keeps the last place
	s.heir = Vector2i(250, 300)
	s._arrive()
	ok(d.world.location == "ironford", "leaving a town for open ground keeps the last place")


func test_real_step() -> void:
	var d := _fresh()
	var s := GameSandbox.start(d)
	s.creatures.clear()
	var door := _door("ironford")
	var r := int(GameSpaces.space("world/ironford")["radius"])
	var found := false
	for dz in range(-r - 2, r + 3):
		for dx in range(-r - 2, r + 3):
			var out := door + Vector2i(dx, dz)
			var inside := out + Vector2i(1, 0)
			if found or GameSpaces.at_tile(out.x, out.y) != GameSpaces.root_id() or GameSpaces.at_tile(inside.x, inside.y) != "world/ironford":
				continue
			s.heir = out
			if s.can_step(1, 0)["ok"]:
				found = true
				ok(s.move(1, 0)["ok"], "(a real step across the edge)")
	ok(found, "(found a walkable edge tile)")
	ok(d.world.location == "ironford", "a real step across the edge arrives")


func test_not_arriving() -> void:
	var d := _fresh()
	var s := GameSandbox.start(d)
	s.creatures.clear()
	s.heir = _door("ironford")
	s.heir_y = GameBuild.SURFACE - 1
	s._arrive()
	ok(d.world.location == "hearthmere", "upstairs, nothing happens")
	s.heir_y = GameBuild.SURFACE
	s.space = "world/hearthmere/store"
	s._arrive()
	ok(d.world.location == "hearthmere", "indoors, nothing happens")
	s.space = "world"
	# a place the world does not know
	s.heir = Vector2i(0, 0)
	s._arrive()
	ok(d.world.location == "hearthmere", "open ground far from any town changes nothing")
