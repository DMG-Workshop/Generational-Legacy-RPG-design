## Furniture and room types (roadmap item 50): furniture goes only inside a room and is solid; a room is named for what
## stands in it (forge, kennel, bedroom, or just a room), the most demanding type first, and the size must fit; taking the
## furniture away takes the name away; the line a tile gives; saving and loading; and the data checks catch a bad type.
## Run: godot --headless --path . -s res://tests/test_game_build_rooms.gd
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
	test_data()
	test_inside_only()
	test_naming()
	test_size_and_removal()
	test_solid_and_saving()
	print("build room tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh() -> GameDynasty:
	var d := GameDynasty.new_game(5, "Tess", "warrior", "faetouched", "human")
	for m in ["oak", "iron", "linen", "copper"]:
		GameCraft.add_material(d, m, 200)
	d.heir.gold = 500
	return d


func _base() -> Vector2i:
	var b := GameBuild.base()
	return Vector2i(int(b["x"]), int(b["z"]))


## A square ring of walls `n` across with its top-left corner at x, z.
func _ring(d: GameDynasty, x: int, z: int, n: int) -> void:
	for i in n:
		for pos in [Vector2i(x + i, z), Vector2i(x + i, z + n - 1), Vector2i(x, z + i), Vector2i(x + n - 1, z + i)]:
			if GameBuild.kind_at(d, pos.x, GameBuild.SURFACE, pos.y) == "":
				GameBuild.place(d, "wall", pos.x, GameBuild.SURFACE, pos.y)


func _put(d: GameDynasty, kind: String, x: int, z: int) -> bool:
	return bool(GameBuild.place(d, kind, x, GameBuild.SURFACE, z)["ok"])


func test_data() -> void:
	ok(GameBuild.validate().is_empty(), "the shipped data passes its checks: %s" % str(GameBuild.validate()))
	var types: Array = GameBuild.data()["room_types"]
	ok(types.size() >= 3, "there are room types")
	var saved: Array = types.duplicate(true)
	GameBuild.data()["room_types"] = [{"id": "x", "name": "X", "phrase": "an x", "needs": {"wall": 1}, "min_area": 4}]
	ok(not GameBuild.validate().is_empty(), "a type that needs a wall (not furniture) is caught")
	GameBuild.data()["room_types"] = [{"id": "x", "name": "X", "phrase": "an x", "needs": {"bed": 1}, "min_area": 4}, {"id": "x", "name": "X", "phrase": "an x", "needs": {"bed": 1}, "min_area": 4}]
	ok(not GameBuild.validate().is_empty(), "a type listed twice is caught")
	GameBuild.data()["room_types"] = [{"id": "x", "name": "X", "phrase": "an x", "needs": {"bed": 1}, "min_area": 4000}]
	ok(not GameBuild.validate().is_empty(), "a type too big for any room is caught")
	GameBuild.data()["room_types"] = saved
	ok(GameBuild.validate().is_empty(), "and putting them back clears it")
	var pj: Dictionary = GamePath.data()["built"]
	var solid: bool = pj["bed"]["solid"]
	pj["bed"]["solid"] = false
	ok(not GameBuild.validate().is_empty(), "furniture that can be walked through is caught")
	pj["bed"]["solid"] = solid
	ok(GameBuild.validate().is_empty(), "and mending it clears it")


func test_inside_only() -> void:
	var d := _fresh()
	var b := _base()
	ok(GameBuild.check(d, "bed", b.x, GameBuild.SURFACE, b.y) != "", "no bed on open ground")
	ok(GameBuild.check(d, "bed", b.x, GameBuild.SURFACE, b.y).contains("inside a room"), "and the reason says why")
	_ring(d, b.x - 2, b.y - 2, 6)
	ok(GameBuild.check(d, "bed", b.x, GameBuild.SURFACE, b.y) == "", "a bed may go inside a ring of walls")
	ok(GameBuild.check(d, "bed", b.x - 2, GameBuild.SURFACE, b.y) != "", "but not on the wall itself")
	ok(GameBuild.check(d, "bed", b.x + 5, GameBuild.SURFACE, b.y) != "", "nor just outside it")
	GameBuild.remove(d, b.x, GameBuild.SURFACE, b.y - 2)   # a gap in the north side
	ok(GameBuild.check(d, "bed", b.x, GameBuild.SURFACE, b.y) != "", "a room with a gap is not a room: no bed")
	ok(GameBuild.check(d, "wall", b.x, GameBuild.SURFACE, b.y) == "", "while a wall may still go anywhere")
	ok(GameBuild.check(d, "bed", b.x, 0, b.y) != "", "and furniture does not go underground")


func test_naming() -> void:
	var d := _fresh()
	var b := _base()
	_ring(d, b.x - 2, b.y - 2, 6)   # 4 x 4 = 16 inside
	var r := GameBuild.room_at(d, b.x, b.y)
	ok(GameBuild.room_type(d, r).is_empty(), "an empty room has no type")
	ok(GameBuild.room_line(d, b.x, b.y) == "You are in a room.", "and is just a room: %s" % GameBuild.room_line(d, b.x, b.y))
	ok(GameBuild.room_line(d, b.x + 8, b.y) == "", "open ground says nothing")
	ok(_put(d, "bed", b.x - 1, b.y - 1), "a bed goes in")
	ok(str(GameBuild.room_type(d, GameBuild.room_at(d, b.x, b.y)).get("id", "")) == "bedroom", "a room with a bed is a bedroom")
	ok(GameBuild.room_line(d, b.x, b.y) == "You are in a bedroom.", "and says so: %s" % GameBuild.room_line(d, b.x, b.y))
	ok(_put(d, "anvil", b.x, b.y - 1), "an anvil goes in")
	ok(str(GameBuild.room_type(d, GameBuild.room_at(d, b.x, b.y)).get("id", "")) == "bedroom", "an anvil alone does not make a forge")
	ok(_put(d, "hearth", b.x + 1, b.y - 1), "a hearth goes in")
	ok(str(GameBuild.room_type(d, GameBuild.room_at(d, b.x, b.y)).get("id", "")) == "forge", "anvil and hearth make a forge, ahead of the bed (the first type that fits wins)")
	ok(_put(d, "trough", b.x - 1, b.y), "a trough goes in")
	ok(str(GameBuild.room_type(d, GameBuild.room_at(d, b.x, b.y)).get("id", "")) == "forge", "and the forge stays a forge")
	var d2 := _fresh()
	_ring(d2, b.x - 2, b.y - 2, 6)
	_put(d2, "trough", b.x, b.y)
	ok(str(GameBuild.room_type(d2, GameBuild.room_at(d2, b.x, b.y)).get("id", "")) == "kennel", "a trough makes a kennel")


func test_size_and_removal() -> void:
	var d := _fresh()
	var b := _base()
	_ring(d, b.x - 2, b.y - 2, 4)   # 2 x 2 = 4
	_put(d, "trough", b.x - 1, b.y - 1)
	ok(GameBuild.room_type(d, GameBuild.room_at(d, b.x - 1, b.y - 1)).is_empty(), "a kennel needs 6 tiles: a 4-tile room with a trough is just a room")
	_put(d, "bed", b.x, b.y)
	ok(str(GameBuild.room_type(d, GameBuild.room_at(d, b.x, b.y)).get("id", "")) == "bedroom", "but the same room is big enough for a bedroom")
	var d2 := _fresh()
	_ring(d2, b.x - 2, b.y - 2, 6)
	_put(d2, "bed", b.x, b.y)
	var r := GameBuild.remove(d2, b.x, GameBuild.SURFACE, b.y)
	ok(r["ok"], "the bed can be taken down: %s" % r["text"])
	ok(GameBuild.room_type(d2, GameBuild.room_at(d2, b.x, b.y)).is_empty(), "and the room is just a room again")
	ok(GameCraft.have(d2, "linen") == 199, "half the bed's linen came back: %d" % GameCraft.have(d2, "linen"))


func test_solid_and_saving() -> void:
	var d := _fresh()
	var b := _base()
	_ring(d, b.x - 2, b.y - 2, 6)
	_put(d, "bed", b.x, b.y)
	GameBuild.remove(d, b.x - 2, GameBuild.SURFACE, b.y)
	GameBuild.place(d, "door", b.x - 2, GameBuild.SURFACE, b.y)
	var g2 := GamePath.world_ground(d)
	var bed_cell := Vector3i(b.x, GamePath.SURFACE, b.y)
	var way := GamePath.find(g2, Vector3i(b.x - 4, GamePath.SURFACE, b.y), Vector3i(b.x + 2, GamePath.SURFACE, b.y), "walker", 3000)
	ok(way["found"] and not way["path"].has(bed_cell), "a walker goes round the bed, not through it")
	var back := GameDynasty.from_dict(d.to_dict())
	ok(GameBuild.kind_at(back, b.x, GameBuild.SURFACE, b.y) == "bed", "a bed survives a save and load")
	ok(GameBuild.room_line(back, b.x + 1, b.y) == "You are in a bedroom.", "and so does the room's name")
	var data := d.to_dict()
	data["built"]["%d,%d,%d" % [b.x + 1, GameBuild.SURFACE, b.y]] = "sofa"
	var odd := GameDynasty.from_dict(data)
	ok(GameBuild.kind_at(odd, b.x + 1, GameBuild.SURFACE, b.y) == "", "a saved piece of a kind that no longer exists is dropped")
