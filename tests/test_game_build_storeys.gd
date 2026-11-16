## Storeys and stairs (roadmap item 50): a piece above the ground needs support (a wall or stairs below it, or a room under
## it; higher up a wall, floor or stairs); stairs go only on or above the ground and not on the top storey; the top is
## max_storeys up; a piece that holds another up cannot be taken down; GamePath climbs the stairs and walks the upper floor;
## the sandbox's build level; saving, damaged saves; and the data checks.
## Run: godot --headless --path . -s res://tests/test_game_build_storeys.gd
extends SceneTree

var fails := 0
var checks := 0
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
	test_data()
	test_support()
	test_stairs_rules()
	test_removal()
	test_path()
	test_sandbox_level()
	test_saving()
	print("build storey tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh() -> GameDynasty:
	var d := GameDynasty.new_game(5, "Tess", "warrior", "faetouched", "human")
	for m in ["oak", "iron", "linen", "copper"]:
		GameCraft.add_material(d, m, 500)
	d.heir.gold = 500
	return d


func _base() -> Vector2i:
	var b := GameBuild.base()
	return Vector2i(int(b["x"]), int(b["z"]))


func _ring(d: GameDynasty, x: int, z: int, n: int) -> void:
	for i in n:
		for pos in [Vector2i(x + i, z), Vector2i(x + i, z + n - 1), Vector2i(x, z + i), Vector2i(x + n - 1, z + i)]:
			if GameBuild.kind_at(d, pos.x, S, pos.y) == "":
				GameBuild.place(d, "wall", pos.x, S, pos.y)


func test_data() -> void:
	ok(GameBuild.validate().is_empty(), "the shipped data passes: %s" % str(GameBuild.validate()))
	ok(GameBuild.top_y() == S - int(GameBuild.setting("max_storeys")), "the top layer is max_storeys above the surface")
	var set: Dictionary = GameBuild.data()["settings"]
	var keep: Array = set["upper_bearers"]
	set["upper_bearers"] = ["ghost"]
	ok(not GameBuild.validate().is_empty(), "a bearer that is not a piece is caught")
	set["upper_bearers"] = keep
	var st: Dictionary = GamePath.data()["built"]["stairs"]
	st["stairs"] = false
	ok(not GameBuild.validate().is_empty(), "stairs that pathing does not climb are caught")
	st["stairs"] = true
	ok(GameBuild.validate().is_empty(), "and mending that clears it")


func test_support() -> void:
	var d := _fresh()
	var b := _base()
	ok(GameBuild.check(d, "floor", b.x, S - 1, b.y) != "", "no floor floating over open ground")
	ok(GameBuild.check(d, "floor", b.x, S - 1, b.y).contains("holds that up"), "and the reason says why")
	GameBuild.place(d, "wall", b.x, S, b.y)
	ok(GameBuild.check(d, "floor", b.x, S - 1, b.y) == "", "a floor goes on a wall")
	ok(GameBuild.check(d, "wall", b.x, S - 1, b.y) == "", "and so does a wall")
	ok(GameBuild.check(d, "floor", b.x + 1, S - 1, b.y) != "", "but not on the next, empty tile")
	_ring(d, b.x + 3, b.y - 2, 6)
	ok(GameBuild.check(d, "floor", b.x + 5, S - 1, b.y) == "", "a floor goes over the middle of a room")
	ok(GameBuild.place(d, "floor", b.x + 5, S - 1, b.y)["ok"], "and is built")
	ok(GameBuild.check(d, "floor", b.x + 5, S - 2, b.y) == "", "a second storey goes on the floor of the first")
	ok(GameBuild.check(d, "floor", b.x + 5, S - 3, b.y) != "", "but nothing is above the top storey (out of range)")
	ok(GameBuild.check(d, "bed", b.x + 5, S - 1, b.y) != "", "furniture stays on the ground floor")
	ok(not GameBuild.remove(d, b.x + 3, S, b.y - 1)["ok"], "a room's wall cannot go while a floor rests over the room")
	var d2 := _fresh()
	_ring(d2, b.x + 3, b.y - 2, 6)
	GameBuild.remove(d2, b.x + 3, S, b.y - 1)
	ok(GameBuild.check(d2, "floor", b.x + 5, S - 1, b.y) != "", "a room with a gap has nothing over it")


func test_stairs_rules() -> void:
	var d := _fresh()
	var b := _base()
	ok(GameBuild.check(d, "stairs", b.x, S, b.y) == "", "stairs go on open ground")
	ok(GameBuild.check(d, "stairs", b.x, 0, b.y) != "", "but not down into the earth")
	GameBuild.place(d, "stairs", b.x, S, b.y)
	ok(GameBuild.check(d, "floor", b.x, S - 1, b.y) == "", "something goes over stairs")
	GameBuild.place(d, "stairs", b.x, S - 1, b.y)
	ok(GameBuild.check(d, "stairs", b.x, S - 2, b.y) != "", "stairs do not go on the top storey")
	ok(GameBuild.check(d, "stairs", b.x, S - 2, b.y).contains("top storey"), "and the reason says so")
	ok(GameBuild.check(d, "stairs", b.x, S - 1, b.y) != "", "one piece to a cell, up there too")


func test_removal() -> void:
	var d := _fresh()
	var b := _base()
	GameBuild.place(d, "wall", b.x, S, b.y)
	GameBuild.place(d, "floor", b.x, S - 1, b.y)
	var r := GameBuild.remove(d, b.x, S, b.y)
	ok(not r["ok"] and GameBuild.kind_at(d, b.x, S, b.y) == "wall", "a wall that holds a floor up stays: %s" % r["text"])
	ok(GameBuild.remove(d, b.x, S - 1, b.y)["ok"], "the floor comes down first")
	ok(GameBuild.remove(d, b.x, S, b.y)["ok"], "then the wall")
	var d2 := _fresh()
	_ring(d2, b.x + 3, b.y - 2, 6)
	GameBuild.place(d2, "floor", b.x + 5, S - 1, b.y)
	ok(not GameBuild.remove(d2, b.x + 3, S, b.y)["ok"], "a wall of the room under a floor cannot go: the room would open")
	ok(GameBuild.remove(d2, b.x + 5, S - 1, b.y)["ok"] and GameBuild.remove(d2, b.x + 3, S, b.y)["ok"], "with the floor down the wall can")


func test_path() -> void:
	var d := _fresh()
	var b := _base()
	GameBuild.place(d, "stairs", b.x, S, b.y)
	GameBuild.place(d, "stairs", b.x, S - 1, b.y)   # the stairs' top landing; the first storey is not the top one
	# a landing: walls under floors beside the stairs
	for i in range(1, 4):
		GameBuild.place(d, "wall", b.x + i, S, b.y)
		GameBuild.place(d, "floor", b.x + i, S - 1, b.y)
	var g := GamePath.world_ground(d)
	var start := Vector3i(b.x - 1, S, b.y)
	var up_goal := Vector3i(b.x + 3, S - 1, b.y)
	var way := GamePath.find(g, start, up_goal, "walker", 3000)
	ok(way["found"], "a walker climbs the stairs to the upper floor")
	ok(way["path"].has(Vector3i(b.x, S, b.y)) and way["path"].has(Vector3i(b.x, S - 1, b.y)), "by way of the stairs' two cells")
	var back := GamePath.find(g, up_goal, start, "walker", 3000)
	ok(back["found"], "and comes down again")
	var d2 := _fresh()
	for i in range(1, 4):
		GameBuild.place(d2, "wall", b.x + i, S, b.y)
		GameBuild.place(d2, "floor", b.x + i, S - 1, b.y)
	ok(not GamePath.find(GamePath.world_ground(d2), start, up_goal, "walker", 3000)["found"], "with no stairs there is no way up")


func test_sandbox_level() -> void:
	var d := _fresh()
	d.world.location = "hearthmere"
	var s := GameSandbox.start(d)
	ok(s.build_level == 0 and s.build_y() == S, "building starts on the ground")
	ok(s.cycle_level() == 1 and s.build_y() == S - 1, "the level steps up a storey")
	s.build_level = 0
	ok(s.build("stairs", 1, 0)["ok"] or s.build("stairs", -1, 0)["ok"], "stairs go up from the ground")
	s.cycle_level()
	ok(s.build_check("floor", 1, 0) == "" or s.build_check("floor", -1, 0) == "", "and the next level can take a floor over them")
	for i in 3:
		s.cycle_level()
	ok(s.build_level < int(GameBuild.setting("max_storeys")) + 1, "the level wraps round to the ground")


func test_saving() -> void:
	var d := _fresh()
	var b := _base()
	GameBuild.place(d, "wall", b.x, S, b.y)
	GameBuild.place(d, "floor", b.x, S - 1, b.y)
	GameBuild.place(d, "stairs", b.x + 2, S, b.y)
	var back := GameDynasty.from_dict(d.to_dict())
	ok(GameBuild.kind_at(back, b.x, S - 1, b.y) == "floor" and GameBuild.kind_at(back, b.x + 2, S, b.y) == "stairs", "upper pieces survive a save and load")
	var data := d.to_dict()
	data["built"]["%d,%d,%d" % [b.x + 4, S - 9, b.y]] = "floor"
	var odd := GameDynasty.from_dict(data)
	ok(GameBuild.kind_at(odd, b.x + 4, S - 9, b.y) == "", "a piece above the top storey is dropped on loading")
