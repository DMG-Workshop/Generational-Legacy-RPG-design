## The heir upstairs (open-world plan): stairs are climbed up and down only where there are stairs and something to stand on
## above; on a storey the heir walks built floor and nothing else (no corner cutting); routes, digging and saving the place
## are ground-only; the build level follows the heir; if the floor goes the heir drops to the ground (off a wall, to the
## nearest free tile); a visit starts on the ground; and the climb actions are in the input data.
## Run: godot --headless --path . -s res://tests/test_game_sandbox_climb.gd
extends SceneTree

var fails := 0
var checks := 0
const WorldInput := preload("res://ui/play/world_input.gd")
const S := -1


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	test_climb()
	test_walk()
	test_guards()
	test_footing()
	test_input()
	print("sandbox climb tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## A house with stairs at the base and a landing of three floors on walls beside the upper stairs.
func _scene() -> Dictionary:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 5000
	for m in ["oak", "iron", "linen", "copper"]:
		GameCraft.add_material(d, m, 500)
	var b := GameBuild.base()
	var x := int(b["x"])
	var z := int(b["z"])
	GameBuild.place(d, "stairs", x, S, z)
	GameBuild.place(d, "stairs", x, S - 1, z)
	for i in range(1, 4):
		GameBuild.place(d, "wall", x + i, S, z)
		GameBuild.place(d, "floor", x + i, S - 1, z)
	var s := GameSandbox.start(d)
	s.creatures.clear()
	s.heir = Vector2i(x - 1, z)
	return {"d": d, "s": s, "x": x, "z": z}


func test_climb() -> void:
	var sc := _scene()
	var s: GameSandbox = sc["s"]
	var x: int = sc["x"]
	var z: int = sc["z"]
	ok(s.storey() == 0 and s.heir_y == S, "a visit starts on the ground")
	ok(not s.climb(-1)["ok"] and s.climb(-1)["why"].contains("no stairs"), "no climbing off the stairs: %s" % s.climb(-1)["why"])
	ok(not s.climb(1)["ok"], "and no going down from the ground")
	ok(s.move(1, 0)["ok"] and s.heir == Vector2i(x, z), "the heir steps onto the stairs")
	var up := s.climb(-1)
	ok(up["ok"] and s.storey() == 1 and s.heir_y == S - 1, "and climbs to the first storey: %s" % str(up))
	ok(s.build_level == 1, "the build level follows the heir up")
	ok(s.log.back()["text"].contains("storey 1"), "and the log says so: %s" % s.log.back()["text"])
	ok(s.place_line().contains("storey 1"), "the place line says which storey")
	s.heir_y = S - 1
	s.build_level = 1
	ok(not s.climb(-1)["ok"] and s.climb(-1)["why"].contains("nothing to stand on"), "stairs with nothing above them go nowhere: %s" % s.climb(-1)["why"])
	var down := s.climb(1)
	ok(down["ok"] and s.storey() == 0 and s.build_level == 0, "and the heir comes back down: %s" % str(down))
	ok(not s.climb(1)["ok"], "with no stairs below at the bottom")


func test_walk() -> void:
	var sc := _scene()
	var s: GameSandbox = sc["s"]
	var x: int = sc["x"]
	var z: int = sc["z"]
	s.move(1, 0)
	s.climb(-1)
	ok(s.move(1, 0)["ok"] and s.heir == Vector2i(x + 1, z) and s.heir_y == S - 1, "upstairs the heir walks onto a floor")
	ok(s.move(1, 0)["ok"] and s.move(1, 0)["ok"], "along the landing")
	ok(not s.move(1, 0)["ok"] and s.heir == Vector2i(x + 3, z), "and stops where the floor ends: %s" % s.can_step(1, 0)["why"])
	ok(not s.can_step(0, 1)["ok"] and not s.can_step(1, 1)["ok"], "nowhere to step on the empty air round it, diagonals too")
	ok(not s.can_step(2, 0)["ok"] and not s.can_step(0, 0)["ok"], "and only one tile at a time")
	ok(s.heir_y == S - 1 and s.storey() == 1, "the heir is still on the first storey")


func test_guards() -> void:
	var sc := _scene()
	var s: GameSandbox = sc["s"]
	var d: GameDynasty = sc["d"]
	var x: int = sc["x"]
	var z: int = sc["z"]
	s.remember()
	var on_ground := d.sandbox_at.duplicate()
	s.move(1, 0)
	s.climb(-1)
	s.move(1, 0)
	s.remember()
	ok(d.sandbox_at == on_ground, "the saved place is not moved upstairs")
	var r := s.set_route(Vector2i(x - 3, z))
	ok(not r["ok"] and s.route.is_empty() and str(r["why"]).contains("ground"), "no routes upstairs: %s" % r["why"])
	var dig := s.dig(0)
	ok(not dig["ok"] and str(dig["why"]).contains("dig from the ground"), "no digging upstairs: %s" % dig["why"])
	ok(s.place_line().contains("storey 1"), "and the place line keeps saying where")


func test_footing() -> void:
	var sc := _scene()
	var s: GameSandbox = sc["s"]
	var d: GameDynasty = sc["d"]
	var x: int = sc["x"]
	var z: int = sc["z"]
	s.move(1, 0)
	s.climb(-1)
	s.move(1, 0)
	ok(s.heir_y == S - 1 and s.heir == Vector2i(x + 1, z), "the heir stands on a floor over a wall")
	s.check_footing()
	ok(s.heir_y == S - 1, "with a floor under them they stay up")
	GameBuild.remove(d, x + 1, S - 1, z)
	s.step()
	ok(s.heir_y == S and s.storey() == 0 and s.build_level == 0, "if the floor goes the heir drops to the ground")
	ok(s.heir != Vector2i(x + 1, z), "but not into the wall that held it up: they are put on the nearest free tile")
	ok(GamePath.passable(GamePath.world_ground(d), Vector3i(s.heir.x, S, s.heir.y), {"water": false, "ignore_blocks": false}), "which they can stand on")
	ok(s.log.back()["text"].contains("floor gave way"), "and the log says so: %s" % s.log.back()["text"])
	s.step()
	ok(s.heir_y == S, "and stays down")


func test_input() -> void:
	var acts: Dictionary = WorldInput.data()["actions"]
	ok(acts.has("world_climb_up") and acts.has("world_climb_down"), "the input data has the climb actions")
	ok(WorldInput.validate().is_empty(), "and the input data passes its checks: %s" % str(WorldInput.validate()))
	var keep: Dictionary = acts["world_climb_up"]
	acts.erase("world_climb_up")
	ok(not WorldInput.validate().is_empty(), "without the action the data is caught")
	acts["world_climb_up"] = keep
	ok(WorldInput.validate().is_empty(), "and putting it back clears it")
