## Kennels (roadmap item 50): a built room with a trough, six tiles or more, is a kennel and gives the family places for
## creatures (`places` each, up to `max_kennels`), on top of the family's own and the Ranch's pens; too small a room, a lone
## trough and a forge that has a trough in it give none; taking the trough away takes the places away; Use in a kennel says
## who is kept; nothing is saved; and the data checks.
## Run: godot --headless --path . -s res://tests/test_game_kennel.gd
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
	test_places()
	test_use()
	print("kennel tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn() -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 5000
	for m in ["oak", "iron", "linen", "copper"]:
		GameCraft.add_material(d, m, 300)
	return d


## A walled room `n` across with its top-left corner `(x, z)` tiles from the base.
func _room(d: GameDynasty, ox: int, oz: int, n: int) -> Vector2i:
	var b := GameBuild.base()
	var x := int(b["x"]) + ox
	var z := int(b["z"]) + oz
	for i in n:
		for pos in [Vector2i(x + i, z), Vector2i(x + i, z + n - 1), Vector2i(x, z + i), Vector2i(x + n - 1, z + i)]:
			if GameBuild.kind_at(d, pos.x, S, pos.y) == "":
				GameBuild.place(d, "wall", pos.x, S, pos.y)
	return Vector2i(x, z)


func test_data() -> void:
	ok(GameBuild.validate().is_empty(), "the shipped data passes: %s" % str(GameBuild.validate()))
	var kennel: Dictionary = {}
	for t in GameBuild.data()["room_types"]:
		if t["id"] == "kennel":
			kennel = t
	ok(int(kennel["places"]) >= 1 and kennel["use"]["kind"] == "keep", "the kennel gives places and its use is to look at who is kept")
	kennel["places"] = 0
	ok(not GameBuild.validate().is_empty(), "a kennel that gives no places is caught")
	kennel["places"] = 2
	var keep: int = GameBuild.setting("max_kennels")
	GameBuild.data()["settings"]["max_kennels"] = 0
	ok(not GameBuild.validate().is_empty(), "no kennels allowed at all is caught")
	GameBuild.data()["settings"]["max_kennels"] = keep
	ok(GameBuild.validate().is_empty(), "and putting them back clears it")


func test_places() -> void:
	var d := _dyn()
	var base_cap := GameRoster.cap(d)
	ok(GameBuild.kennel_places(d) == 0 and base_cap == int(GameFinding.setting("roster_cap")) + GameRanch.extra_pens(d), "with nothing built there are no kennel places and the roster is as it was: %d" % base_cap)
	var one := _room(d, -8, -8, 6)   # 4 x 4 inside
	ok(GameBuild.kennel_places(d) == 0, "a walled room with no trough is just a room")
	GameBuild.place(d, "trough", one.x + 1, S, one.y + 1)
	ok(GameBuild.kennel_places(d) == 2 and GameRoster.cap(d) == base_cap + 2, "a trough in it makes a kennel: two more places (%d)" % GameRoster.cap(d))
	var two := _room(d, 2, -8, 6)
	GameBuild.place(d, "trough", two.x + 1, S, two.y + 1)
	ok(GameBuild.kennel_places(d) == 4, "a second kennel gives two more")
	var three := _room(d, -8, 2, 6)
	GameBuild.place(d, "trough", three.x + 1, S, three.y + 1)
	ok(GameBuild.kennel_places(d) == 6, "and a third")
	var four := _room(d, 2, 2, 6)
	GameBuild.place(d, "trough", four.x + 1, S, four.y + 1)
	ok(GameBuild.kennel_places(d) == int(GameBuild.setting("max_kennels")) * 2, "a fourth gives nothing more: the most is %d kennels" % int(GameBuild.setting("max_kennels")))
	GameBuild.remove(d, three.x + 1, S, three.y + 1)
	GameBuild.remove(d, four.x + 1, S, four.y + 1)
	ok(GameBuild.kennel_places(d) == 4, "taking a trough out takes that kennel's places away")
	var d2 := _dyn()
	var small := _room(d2, -8, -8, 4)   # 2 x 2 inside: under the 6 tiles a kennel needs
	GameBuild.place(d2, "trough", small.x + 1, S, small.y + 1)
	ok(GameBuild.kennel_places(d2) == 0, "a room under six tiles is no kennel")
	var d3 := _dyn()
	var big := _room(d3, -8, -8, 6)
	GameBuild.place(d3, "trough", big.x + 1, S, big.y + 1)
	GameBuild.place(d3, "anvil", big.x + 2, S, big.y + 1)
	GameBuild.place(d3, "hearth", big.x + 3, S, big.y + 1)
	ok(GameBuild.kennel_places(d3) == 0, "a forge that has a trough in it is a forge, not a kennel")
	var d4 := _dyn()
	GameBuild.place(d4, "trough", int(GameBuild.base()["x"]) + 5, S, int(GameBuild.base()["z"]) + 5)
	ok(GameBuild.kennel_places(d4) == 0, "a lone trough on open ground gives nothing (it is not in a room)")
	var saved := JSON.stringify(d.to_dict())
	ok(not saved.contains("kennel"), "nothing about kennels is saved (the pieces are, as they were)")
	ok(GameRoster.cap(GameDynasty.from_dict(d.to_dict())) == GameRoster.cap(d), "and a loaded dynasty has the same places")
	var full := _dyn()
	var room := _room(full, -8, -8, 6)
	var cap0 := GameRoster.cap(full)
	for i in cap0:
		GameRoster.add(full, "wolf", "w%d" % i)
	ok(GameRoster.full(full), "(the roster is full at %d)" % cap0)
	GameBuild.place(full, "trough", room.x + 1, S, room.y + 1)
	ok(not GameRoster.full(full), "a new kennel makes room for more: %d of %d" % [full.roster.size(), GameRoster.cap(full)])


func test_use() -> void:
	var d := _dyn()
	var room := _room(d, -8, -8, 6)
	GameBuild.place(d, "trough", room.x + 1, S, room.y + 1)
	var s := GameSandbox.start(d)
	s.creatures.clear()
	s.heir = room + Vector2i(3, 3)
	ok(s.place_line().contains("kennel") and s.place_line().contains("Use to see who is kept."), "the place line says what Use does: %s" % s.place_line())
	var age: float = d.heir.age
	var r := s.use()
	ok(r["ok"] and r["text"].contains("2 places") and r["text"].contains("%d of %d" % [d.roster.size(), GameRoster.cap(d)]), "Use says the places and who is kept: %s" % r["text"])
	ok(not r.has("open"), "and opens nothing")
	ok(d.heir.age == age, "and takes no time")
