## What a room does (roadmap item 50): a bedroom the family built lets the heir rest with Use: healed, the party rested, and a
## quarter of a year goes by (the text game's rest takes a year); a plain room, a forge, a kennel and open ground do nothing;
## a door still comes first; not upstairs or indoors; the place line says "Use to rest."; the rest of the text game is the same
## (rest() is still a year and the same effects); and the data checks catch a bad use.
## Run: godot --headless --path . -s res://tests/test_game_room_use.gd
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
	test_room_use()
	test_sandbox_rest()
	test_not_here()
	test_text_game_rest()
	print("room use tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _house() -> Dictionary:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 5000
	for m in ["oak", "iron", "linen", "copper"]:
		GameCraft.add_material(d, m, 200)
	var b := GameBuild.base()
	var x := int(b["x"]) - 8
	var z := int(b["z"]) - 8
	for i in 6:
		for pos in [Vector2i(x + i, z), Vector2i(x + i, z + 5), Vector2i(x, z + i), Vector2i(x + 5, z + i)]:
			if GameBuild.kind_at(d, pos.x, S, pos.y) == "":
				GameBuild.place(d, "wall", pos.x, S, pos.y)
	return {"d": d, "x": x, "z": z}


func test_data() -> void:
	ok(GameBuild.validate().is_empty(), "the shipped data passes: %s" % str(GameBuild.validate()))
	var types: Array = GameBuild.data()["room_types"]
	var bed: Dictionary = {}
	for t in types:
		if t["id"] == "bedroom":
			bed = t
	ok(bed.has("use") and bed["use"]["kind"] == "rest", "the bedroom has a use: rest")
	var keep: Dictionary = bed["use"].duplicate()
	bed["use"]["years"] = 0.0
	ok(not GameBuild.validate().is_empty(), "a rest of no time is caught")
	bed["use"]["years"] = 2.0
	ok(not GameBuild.validate().is_empty(), "a rest longer than a year is caught")
	bed["use"] = {"kind": "fly", "years": 0.25, "hint": "x"}
	ok(not GameBuild.validate().is_empty(), "a use the game does not know is caught")
	bed["use"] = {"kind": "rest", "years": 0.25}
	ok(not GameBuild.validate().is_empty(), "a use with no hint is caught")
	bed["use"] = keep
	ok(GameBuild.validate().is_empty(), "and putting it back clears it")


func test_room_use() -> void:
	var h := _house()
	var d: GameDynasty = h["d"]
	var x: int = h["x"]
	var z: int = h["z"]
	ok(GameBuild.room_use(d, x + 2, z + 2).is_empty(), "a plain room does nothing")
	GameBuild.place(d, "bed", x + 1, S, z + 1)
	var u := GameBuild.room_use(d, x + 2, z + 2)
	ok(u.get("kind", "") == "rest" and u["type"] == "bedroom" and float(u["years"]) == 0.25, "a room with a bed is a bedroom that rests: %s" % str(u))
	ok(GameBuild.room_use(d, x - 5, z - 5).is_empty(), "open ground does nothing")
	GameBuild.place(d, "anvil", x + 2, S, z + 1)
	GameBuild.place(d, "hearth", x + 3, S, z + 1)
	ok(GameBuild.room_use(d, x + 2, z + 2).get("kind", "") == "craft", "the same room as a forge crafts instead (the first type that fits wins)")
	var h2 := _house()
	GameBuild.place(h2["d"], "trough", h2["x"] + 1, S, h2["z"] + 1)
	ok(GameBuild.room_use(h2["d"], h2["x"] + 2, h2["z"] + 2).get("kind", "") == "keep", "a kennel's use is to look at who is kept")


func test_sandbox_rest() -> void:
	var h := _house()
	var d: GameDynasty = h["d"]
	var x: int = h["x"]
	var z: int = h["z"]
	GameBuild.place(d, "bed", x + 1, S, z + 1)
	var s := GameSandbox.start(d)
	s.creatures.clear()
	s.heir = Vector2i(x + 3, z + 3)
	ok(s.place_line().contains("bedroom") and s.place_line().contains("Use to rest."), "the place line says it is a bedroom and what Use does: %s" % s.place_line())
	d.heir.hp = 1
	var age := d.heir.age
	var year := d.world.year
	var r := s.use()
	ok(r["ok"] and d.heir.hp == d.heir.max_hp(), "Use heals the heir: %s" % r["text"])
	ok(absf(d.heir.age - age - 0.25) < 0.001, "a quarter of a year goes by (age %.3f to %.3f)" % [age, d.heir.age])
	ok(d.world.year > year and d.world.year - year < 0.3, "and the world's year moved the same")
	ok(s.log.back()["kind"] == "rest", "and it is in the log")
	ok(d.heir.downtime or d.state != "life", "the heir rests like the text game's rest does")


func test_not_here() -> void:
	var h := _house()
	var d: GameDynasty = h["d"]
	var x: int = h["x"]
	var z: int = h["z"]
	GameBuild.place(d, "bed", x + 1, S, z + 1)
	var s := GameSandbox.start(d)
	s.creatures.clear()
	s.heir = Vector2i(x - 6, z - 6)
	d.heir.hp = 1
	var age := d.heir.age
	var r := s.use()
	ok(not r["ok"] and r["text"].contains("nothing to use") and d.heir.hp == 1 and d.heir.age == age, "Use on open ground does nothing: %s" % r["text"])
	s.heir = Vector2i(x + 3, z + 3)
	s.heir_y = S - 1
	ok(not s.use()["ok"] and d.heir.hp == 1, "nor upstairs, where the room is not")
	s.heir_y = S
	s.space = "world/hearthmere/forge"
	s.interior = GameInterior.cells("world/hearthmere/forge")
	s.heir = Vector2i(1, 0)
	ok(not s.use()["ok"] and d.heir.hp == 1, "nor indoors in an interior (Use there is for the way out)")
	var s2 := GameSandbox.start(d)
	s2.creatures.clear()
	s2.heir = Vector2i(int(GameSpaces.space("world/hearthmere/forge")["door"]["x"]), int(GameSpaces.space("world/hearthmere/forge")["door"]["z"]))
	ok(s2.use()["ok"] and s2.space == "world/hearthmere/forge" and d.heir.hp == 1, "a door still comes first: Use goes in rather than resting")


func test_text_game_rest() -> void:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	var age := d.heir.age
	d.heir.hp = 1
	var msgs := d.rest()
	ok(d.heir.hp == d.heir.max_hp() and not msgs.is_empty(), "the text game's rest still heals")
	ok(absf(d.heir.age - age - float(d.years_for("rest"))) < 0.001, "and still takes its year (%d)" % d.years_for("rest"))
	var d2 := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d2.pending_event = {}
	d2.heir.hp = 1
	var m2 := d2.rest_for(float(d2.years_for("rest")))
	ok(JSON.stringify(m2) == JSON.stringify(msgs) and d2.rng.state == d.rng.state, "rest_for with a year is the same rest, the same words and the same dice")
