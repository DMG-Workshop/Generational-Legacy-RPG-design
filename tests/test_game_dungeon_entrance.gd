## A dungeon's entrance is a body (core/game/game_dungeon_art.gd `solid`, `blocks`): every tile of its 5 by 3 picture but the door tile stops walkers
## (the heir, companions, creatures, the building rules, A* routes) and blows (GameWalls.line_clear), so the way in is the door tile alone, from the
## open ground below it; every dungeon's door can still be reached from open ground; entering and leaving still work; and nothing is drawn or saved.
## Run: godot --headless --path . -s res://tests/test_game_dungeon_entrance.gd
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
	test_body()
	test_walk()
	test_route()
	test_reach_and_creatures()
	test_enter_leave()
	test_breaks()
	print("dungeon entrance tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _places() -> Array:
	return GameDungeonArt.data()["dungeons"].keys()


func _door(place: String) -> Vector2i:
	var door: Dictionary = GameSpaces.space("world/" + place)["door"]
	return Vector2i(int(door["x"]), int(door["z"]))


func _dyn(seed_value: int = 7) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


func test_body() -> void:
	ok(_places().size() == 6, "six dungeons")
	for p in _places():
		var r := GameDungeonArt.entrance_rect(str(p))
		var door := _door(str(p))
		var solid := 0
		for x in range(r.position.x, r.end.x):
			for z in range(r.position.y, r.end.y):
				if GameDungeonArt.blocks(x, z):
					solid += 1
		ok(solid == r.size.x * r.size.y - 1, "%s: all %d tiles but the door are solid" % [p, solid])
		ok(not GameDungeonArt.blocks(door.x, door.y), "%s: the door tile is not" % p)
		ok(not GameDungeonArt.blocks(door.x, door.y + 1) and not GameDungeonArt.blocks(r.position.x - 1, door.y) and not GameDungeonArt.blocks(r.end.x, door.y), "%s: nothing is solid below or beside the picture" % p)
	ok(not GameDungeonArt.blocks(0, 0), "nothing at the world's corner")


func test_walk() -> void:
	for p in _places():
		var door := _door(str(p))
		var d := _dyn()
		var s := GameSandbox.start(d)
		s.heir = door
		ok(not s.can_step(0, -1)["ok"], "%s: from the door the heir cannot walk into the hill" % p)
		ok(not s.can_step(-1, 0)["ok"] and not s.can_step(1, 0)["ok"], "%s: nor along the front of it" % p)
		ok(not s.can_step(-1, -1)["ok"] and not s.can_step(1, -1)["ok"], "%s: nor across its corners" % p)
		ok(s.can_step(0, 1)["ok"], "%s: but back out to the open ground" % p)
		s.heir = Vector2i(door.x, door.y + 1)
		ok(s.can_step(0, -1)["ok"] and s.door_here() == "" , "%s: from the ground below, the door tile can be stepped on" % p)
		s.move(0, -1)
		ok(s.heir == door and s.door_here() != "", "%s: and standing on it the door can be used" % p)
		var g := GamePath.world_ground(d)
		var r := GameDungeonArt.entrance_rect(str(p))
		ok(not GamePath.passable(g, Vector3i(r.position.x + 1, -1, r.position.y), GamePath.data()["movers"]["walker"]), "%s: the hill blocks a walker in the pathing's own ground" % p)
		ok(GameBuild.check(d, "wall", r.position.x + 1, -1, r.position.y) != "", "%s: the family cannot build on it" % p)


func test_route() -> void:
	for p in _places():
		var door := _door(str(p))
		var d := _dyn()
		var g := GamePath.world_ground(d)
		var behind := Vector3i(door.x, -1, door.y - 4)   # on the far side of the hill
		var f := GamePath.find(g, behind, Vector3i(door.x, -1, door.y), "walker", 6000)
		ok(bool(f["found"]), "%s: a walker from behind the hill finds the door by going round" % p)
		var through := false
		for c in f["path"]:
			if GameDungeonArt.blocks(c.x, c.z):
				through = true
		ok(not through, "%s: and the way never crosses the hill" % p)
		ok(float(f["cost"]) > 6.0, "%s: it is longer than straight through (cost %.1f)" % [p, float(f["cost"])])
		var near := GamePath.find(g, Vector3i(door.x, -1, door.y + 3), Vector3i(door.x, -1, door.y), "walker", 600)
		ok(bool(near["found"]), "%s: and from the front it is a short walk" % p)


func test_reach_and_creatures() -> void:
	for p in _places():
		var door := _door(str(p))
		var behind := Vector2(float(door.x) + 0.5, float(door.y) - 2.5)
		var front := Vector2(float(door.x) + 0.5, float(door.y) + 1.5)
		ok(not GameWalls.line_clear(behind, front, false), "%s: a blow does not pass through the hill" % p)
		ok(GameWalls.line_clear(Vector2(float(door.x) + 0.5, float(door.y) + 3.5), front, false), "%s: but does across the open ground in front" % p)
		var d := _dyn()
		var view := GameBehaviour.world_view(d, [])
		var r := GameDungeonArt.entrance_rect(str(p))
		ok(not bool(view["walkable"].call(float(r.position.x) + 1.5, float(r.position.y) + 0.5)), "%s: creatures keep off the hill" % p)
		ok(bool(view["walkable"].call(float(door.x) + 0.5, float(door.y) + 2.5)), "%s: and may stand on the ground before it" % p)


func test_enter_leave() -> void:
	var p := str(_places()[0])
	var door := _door(p)
	var d := _dyn()
	d.pending_event = {}
	var s := GameSandbox.start(d)
	s.heir = door
	var r := s.use()
	ok(bool(r["ok"]) and s.space == "world/" + p, "the door still opens: %s" % r["text"])
	ok(s.heir == GameInterior.entry(), "the heir is inside at the way out")
	var l := s.leave()
	ok(bool(l["ok"]) and s.space == "world" and s.heir == door, "and out again to the door tile")
	ok(not d.to_dict().has("dungeon_entrance"), "nothing new is saved")


func test_breaks() -> void:
	var was := GameDungeonArt._solid.duplicate()
	GameDungeonArt._solid = {}
	ok(GameDungeonArt.solid().size() == 6 * 14, "reload rebuilds the same 14 solid tiles for each of six dungeons")
	GameDungeonArt.reload()
	ok(GameDungeonArt.solid().size() == was.size(), "and the same after a full reload")
