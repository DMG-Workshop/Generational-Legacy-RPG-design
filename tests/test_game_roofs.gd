## Roofs and rooms above the ground (roadmap item 50): a roof is its own piece that goes on a storey (one layer above the top
## storey is allowed), bears nothing and cannot be walked on; a room can stand on a storey (walls, a floor in every cell);
## furniture goes on that floor in place of it; a room is roofed when a roof or floor is over every cell.
## Run: godot --headless --path . -s res://tests/test_game_roofs.gd
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
	test_roof_rules()
	test_roofed()
	test_upper_rooms()
	test_upper_furniture()
	test_sandbox()
	test_data()
	print("roof tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh() -> GameDynasty:
	var d := GameDynasty.new_game(5, "Tess", "warrior", "faetouched", "human")
	for m in ["oak", "iron", "linen", "copper"]:
		GameCraft.add_material(d, m, 900)
	d.heir.gold = 500
	return d


func _base() -> Vector2i:
	var b := GameBuild.base()
	return Vector2i(int(b["x"]), int(b["z"]))


## A square ring of walls n wide at layer y from (x, z).
func _ring(d: GameDynasty, x: int, z: int, n: int, y: int) -> void:
	for i in n:
		for pos in [Vector2i(x + i, z), Vector2i(x + i, z + n - 1), Vector2i(x, z + i), Vector2i(x + n - 1, z + i)]:
			if GameBuild.kind_at(d, pos.x, y, pos.y) == "":
				d.built[GameBuild.key(pos.x, y, pos.y)] = "wall"


func _floors(d: GameDynasty, x: int, z: int, n: int, y: int) -> void:
	for i in range(1, n - 1):
		for j in range(1, n - 1):
			d.built[GameBuild.key(x + i, y, z + j)] = "floor"


func test_roof_rules() -> void:
	var d := _fresh()
	var b := _base()
	ok(GameBuild.check(d, "roof", b.x, S, b.y) == GameBuild.text("roof_low"), "a roof does not go on the ground")
	ok(GameBuild.check(d, "roof", b.x, 0, b.y) != "", "nor under it")
	ok(GameBuild.check(d, "roof", b.x, S - 1, b.y) == GameBuild.text("needs_support"), "a roof with nothing under it hangs: %s" % GameBuild.check(d, "roof", b.x, S - 1, b.y))
	d.built[GameBuild.key(b.x, S, b.y)] = "wall"
	ok(GameBuild.check(d, "roof", b.x, S - 1, b.y) == "", "a roof rests on a wall")
	var top := GameBuild.top_y()
	ok(GameBuild.check(d, "wall", b.x, top - 1, b.y) == GameBuild.text("out_of_range"), "a wall cannot go above the top storey")
	d.built[GameBuild.key(b.x, S - 1, b.y)] = "wall"
	d.built[GameBuild.key(b.x, top, b.y)] = "wall"
	ok(GameBuild.check(d, "roof", b.x, top - 1, b.y) == "", "but the roof of the top storey can")
	ok(GameBuild.check(d, "roof", b.x, top - 2, b.y) == GameBuild.text("out_of_range"), "and nothing goes higher")
	var r := GameBuild.place(d, "roof", b.x, top - 1, b.y)
	ok(bool(r["ok"]), "it is built")
	ok(GameBuild.check(d, "wall", b.x, top - 2, b.y) != "", "a roof bears nothing")
	ok(GameBuild.check(d, "stairs", b.x + 1, S - 1, b.y) != "", "no stairs on thin air")
	ok(bool(GamePath.data()["built"]["roof"]["solid"]), "a roof is solid to pathing")


func test_roofed() -> void:
	var d := _fresh()
	var b := _base()
	_ring(d, b.x, b.y, 4, S)
	var rs := GameBuild.rooms(d)
	ok(rs.size() == 1 and not bool(rs[0]["roofed"]), "a walled room with nothing over it is not roofed")
	ok(GameBuild.room_line(d, b.x + 1, b.y + 1) == "You are in a room.", "and says nothing of a roof")
	for c in rs[0]["cells"]:
		if c != rs[0]["cells"][0]:
			d.built[GameBuild.key(c.x, S - 1, c.y)] = "roof"
	ok(not bool(GameBuild.rooms(d)[0]["roofed"]), "one cell short is still not roofed")
	var first: Vector2i = rs[0]["cells"][0]
	d.built[GameBuild.key(first.x, S - 1, first.y)] = "floor"
	ok(bool(GameBuild.rooms(d)[0]["roofed"]), "a floor over a cell covers it as well")
	ok(GameBuild.room_line(d, b.x + 1, b.y + 1) == "You are in a room, under a roof.", "the line says so: %s" % GameBuild.room_line(d, b.x + 1, b.y + 1))
	d.built.erase(GameBuild.key(first.x, S - 1, first.y))
	ok(not bool(GameBuild.rooms(d)[0]["roofed"]), "taking it away opens the room to the sky")


func test_upper_rooms() -> void:
	var d := _fresh()
	var b := _base()
	_ring(d, b.x, b.y, 5, S)
	# a storey: the ground room's cells are held up by the room, walls on the walls
	ok(GameBuild.rooms_on(d, S - 1).is_empty(), "no storey, no upper rooms")
	_ring(d, b.x, b.y, 5, S - 1)
	ok(GameBuild.rooms_on(d, S - 1).is_empty(), "walls with no floor inside are not a room: nothing to stand on")
	_floors(d, b.x, b.y, 5, S - 1)
	var up := GameBuild.rooms_on(d, S - 1)
	ok(up.size() == 1 and int(up[0]["area"]) == 9 and int(up[0]["y"]) == S - 1, "walls and a floor make a room on the storey: %s" % str(up.size()))
	ok(GameBuild.room_at(d, b.x + 2, b.y + 2, S - 1).size() > 0 and GameBuild.room_at(d, b.x + 2, b.y + 2).size() > 0, "the same tile is in the ground room and the one above")
	ok(GameBuild.rooms_all(d).size() == 2, "rooms_all lists both")
	ok(GameBuild.describe(d).contains("2 rooms"), "and the summary counts both: %s" % GameBuild.describe(d))
	d.built.erase(GameBuild.key(b.x + 2, S - 1, b.y + 2))
	ok(GameBuild.rooms_on(d, S - 1).is_empty(), "a hole in the floor spoils the room")
	d.built[GameBuild.key(b.x + 2, S - 1, b.y + 2)] = "floor"
	d.built.erase(GameBuild.key(b.x + 1, S - 1, b.y))
	ok(GameBuild.rooms_on(d, S - 1).is_empty(), "so does a gap in the wall")


func test_upper_furniture() -> void:
	var d := _fresh()
	var b := _base()
	_ring(d, b.x, b.y, 5, S)
	_ring(d, b.x, b.y, 5, S - 1)
	_floors(d, b.x, b.y, 5, S - 1)
	var cell := Vector2i(b.x + 2, b.y + 2)
	ok(GameBuild.check(d, "bed", cell.x, S - 2, cell.y) != "", "no bed on a storey with no room under a roof of its own")
	ok(GameBuild.check(d, "bed", cell.x, S - 1, cell.y) == "", "a bed goes on the upper floor, in its place: %s" % GameBuild.check(d, "bed", cell.x, S - 1, cell.y))
	ok(GameBuild.check(d, "wall", cell.x, S - 1, cell.y) == GameBuild.text("occupied"), "but a wall may not")
	var gold := d.heir.gold
	ok(bool(GameBuild.place(d, "bed", cell.x, S - 1, cell.y)["ok"]), "it is built")
	ok(GameBuild.kind_at(d, cell.x, S - 1, cell.y) == "bed", "the bed stands in the floor's place")
	ok(GameBuild.rooms_on(d, S - 1).size() == 1, "and the room is still a room")
	ok(str(GameBuild.room_type(d, GameBuild.room_at(d, cell.x, cell.y, S - 1)).get("id", "")) == "bedroom", "which is a bedroom now")
	ok(not GameBuild.room_use(d, cell.x, cell.y, S - 1).is_empty() and GameBuild.room_use(d, cell.x, cell.y).is_empty(), "the use is upstairs, not in the ground room below")
	ok(GameBuild.room_line(d, cell.x, cell.y, S - 1) == "You are in a bedroom.", "and so is the line")
	ok(bool(GameBuild.remove(d, cell.x, S - 1, cell.y)["ok"]), "the bed comes down")
	ok(GameBuild.kind_at(d, cell.x, S - 1, cell.y) == "floor" and GameBuild.rooms_on(d, S - 1).size() == 1, "and the floor is left, so the room stands")
	ok(gold == d.heir.gold, "furniture costs materials, not gold")


func test_sandbox() -> void:
	var d := _fresh()
	var b := _base()
	var sb := GameSandbox.new()
	sb.start(d)
	ok(sb.level_name() == "ground", "the level button says ground")
	sb.build_level = 1
	ok(sb.level_name() == "1", "then the storey")
	sb.build_level = int(GameBuild.setting("max_storeys")) + 1
	ok(sb.level_name() == "roof", "then the roof layer")
	var n := 0
	sb.build_level = 0
	for i in 10:
		sb.cycle_level()
		n += 1
		if sb.build_level == 0:
			break
	ok(n == int(GameBuild.setting("max_storeys")) + 2, "the Level button cycles through the roof layer and back to the ground: %d" % n)
	ok(b.x >= 0, "base is known")


func test_data() -> void:
	ok(GameBuild.validate().is_empty(), "the shipped data passes: %s" % str(GameBuild.validate()))
	var set: Dictionary = GameBuild.data()["settings"]
	var keep: Array = set["upper_bearers"]
	set["upper_bearers"] = ["wall", "roof"]
	ok(not GameBuild.validate().is_empty(), "a roof that bears a storey is caught")
	set["upper_bearers"] = keep
	var cov: Array = set["roof_covers"]
	set["roof_covers"] = ["ghost"]
	ok(not GameBuild.validate().is_empty(), "a cover that is not a piece is caught")
	set["roof_covers"] = cov
	ok(GameBuild.validate().is_empty(), "and mending clears it")
