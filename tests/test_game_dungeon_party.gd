## Companions in the dungeons: the party goes in with the heir (seated on the floor nearest the way in), follows on the dungeon's own
## floor (never in a wall), a guard fights a creature of the room and a win kills it for good measure (a `k` mark and its drops), a
## gather order keeps close (a dungeon has no nodes), and they come out with the heir beside the door. The fights are the guard's own
## dice (keyed on the seed), so the dynasty's are not drawn.
## Run: godot --headless --path . -s res://tests/test_game_dungeon_party.gd
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
	test_enter_leave()
	test_follow()
	test_guard()
	test_no_party()
	print("dungeon party tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _sandbox(ids: Array, place: String = "goblin_warrens") -> GameSandbox:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.gen = 1
	for id in ids:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 9999, "mp": 0, "level": 40, "gen": 1,
			"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
		d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
			"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	var s := GameSandbox.start(d)
	var door: Dictionary = GameSpaces.space("world/" + place)["door"]
	s.heir = Vector2i(int(door["x"]), int(door["z"]))
	s.use()
	s.denizens.clear()
	return s


func _on_floor(s: GameSandbox) -> bool:
	for a in s.companions:
		if not GameInterior.passable(s.interior, floori(float(a["x"])), floori(float(a["z"]))):
			return false
	return true


func test_enter_leave() -> void:
	var s := _sandbox(["bren_cask", "maddy_thorn"])
	ok(s.space == "world/goblin_warrens" and s.companions.size() == 2, "both companions go in")
	ok(_on_floor(s), "and stand on the floor")
	var cells := {}
	for a in s.companions:
		cells["%d,%d" % [floori(float(a["x"])), floori(float(a["z"]))]] = true
	ok(cells.size() == 2 and not cells.has("0,0"), "each on a cell of their own, not on the way out")
	var out := s.use()
	ok(out["ok"] and s.space == "world" and s.companions.size() == 2, "they come out with the heir")
	var near := true
	for a in s.companions:
		near = near and Vector2(float(a["x"]), float(a["z"])).distance_to(s.heir_point()) < 6.0
	ok(near, "beside the door on the open world")
	# a shop's interior leaves the open world's companions alone
	var before := s.companions.duplicate(true)
	var fd: Dictionary = GameSpaces.space("world/hearthmere/forge")["door"]
	s.heir = Vector2i(int(fd["x"]), int(fd["z"]))
	s.use()
	ok(s.companions == before, "a town's forge changes nothing for them")


func test_follow() -> void:
	var s := _sandbox(["bren_cask", "maddy_thorn"])
	var rng_before := s.d.rng.state
	for t in GameDungeons.layout(s.space)["traps"]:
		GameDungeons.mark(s.d, "t", "goblin_warrens", str(t["id"]))
	var path: Array = [Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 0)]
	var floor_ok := true
	var near := true
	for st in path:
		s.move(st.x, st.y)
		for _i in 3:
			s.step()
			floor_ok = floor_ok and _on_floor(s)
	for a in s.companions:
		near = near and Vector2(float(a["x"]), float(a["z"])).distance_to(s.heir_point()) <= float(GameCompanions.setting("follow_catchup")) + 1.0
	ok(floor_ok, "they are never in a wall")
	ok(near, "and keep up with the heir")
	GameCompanions.set_order(s.d, "bren_cask", "gather")
	for _i in 6:
		s.step()
	ok(_on_floor(s) and s.d.stores.is_empty(), "a gather order gathers nothing here and they stay on the floor")
	ok(s.d.rng.state == rng_before, "no die of the dynasty's was drawn")


func test_guard() -> void:
	var s := _sandbox(["bren_cask"])
	var mult: float = GameCompanions.data()["settings"]["guard_foe_level_mult"]
	GameCompanions.data()["settings"]["guard_foe_level_mult"] = 0.25   # a strong guard against a weak foe: a clear win
	s.d.heir.level = 40
	GameCompanions.set_order(s.d, "bren_cask", "guard")
	s._dungeon_companions()
	var a: Dictionary = s.companions[0]
	var spot := Vector2(-99.0, -99.0)
	for dir in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var c: Vector2i = Vector2i(floori(float(a["x"])), floori(float(a["z"]))) + dir
		if GameInterior.passable(s.interior, c.x, c.y) and spot.x < -90.0 and GameInterior.room_at(s.space, c.x, c.y) == GameInterior.room_at(s.space, floori(float(a["x"])), floori(float(a["z"]))):
			spot = Vector2(float(c.x) + 0.5, float(c.y) + 0.5)
	ok(spot.x > -90.0, "there is floor beside the guard")
	var room := GameInterior.room_at(s.space, floori(float(a["x"])), floori(float(a["z"])))
	var foe := GameBehaviour.new_agent(900, "goblin", spot.x, spot.y)
	foe["key"] = "%s#99" % room
	foe["room"] = room
	foe["boss"] = false
	foe["mode"] = "idle"
	s.denizens = [foe]
	var rng_before := s.d.rng.state
	var gold := s.d.heir.gold
	for _i in 30:
		if s.denizens.is_empty() or s.d.battle != null:
			break
		s._dungeon_companions()
	ok(s.denizens.is_empty(), "the guard fought it and won")
	ok(GameDungeons.is_marked(s.d, "k", "goblin_warrens", "%s#99" % room), "it is marked killed")
	ok(s.log.any(func(l): return str(l["kind"]) == "guard"), "the log says so: %s" % str(s.log.filter(func(l): return str(l["kind"]) == "guard").map(func(l): return l["text"])))
	ok(s.d.heir.gold >= gold, "(and the family's share of gold is not less)")
	ok(s.d.rng.state == rng_before, "no die of the dynasty's was drawn")
	GameCompanions.data()["settings"]["guard_foe_level_mult"] = mult
	# a boss is left to the heir
	var boss := GameBehaviour.new_agent(901, "goblin", spot.x, spot.y)
	boss["key"] = "x#boss"
	boss["room"] = room
	boss["boss"] = true
	boss["mode"] = "idle"
	s.denizens = [boss]
	for _i in 10:
		s._dungeon_companions()
	ok(s.denizens.size() == 1, "a lair's boss is not taken on by a guard")


func test_no_party() -> void:
	var s := _sandbox([])
	ok(s.companions.is_empty(), "a heir alone has no companions in")
	s.step(3)
	s.use()
	ok(s.space == "world" and s.companions.is_empty(), "and none come out")
