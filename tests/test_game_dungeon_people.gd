## People in the dungeons (data/world/dungeons.json `people`): a prisoner to free for a reward, a healer, a hint-giver who names the room
## of the next key. They stand on floor cells of their room (solid, `person` cells), are talked to with Use, and what they have given
## is a `p` mark that comes back after `people_years`. No die of the dynasty's is drawn and nothing is saved until someone is helped.
## Run: godot --headless --path . -s res://tests/test_game_dungeon_people.gd
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
	test_talk()
	test_walk()
	print("dungeon people tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(gen: int = 5) -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.gen = gen
	d.heir.gold = 0
	return d


func _person(place: String, id: String) -> Dictionary:
	for p in GameDungeons.layout("world/" + place)["people"]:
		if str(p["id"]) == id:
			return p
	return {}


func test_data() -> void:
	ok(GameDungeons.validate().is_empty(), "the dungeon data is valid: %s" % str(GameDungeons.validate()))
	for place in GameDungeons.dungeon_ids():
		var sp: String = "world/" + place
		var lay: Dictionary = GameDungeons.layout(sp)
		var rows: Array = GameDungeons.data()["dungeons"][place]["people"]
		ok(lay["people"].size() == rows.size() and rows.size() >= 2, "%s: every person has a place (%d)" % [place, rows.size()])
		var kinds := {}
		for p in lay["people"]:
			kinds[str(p["kind"])] = true
			ok(GameInterior.room_at(sp, int(p["x"]), int(p["z"])) == str(p["room"]), "%s: %s stands in %s" % [place, p["id"], p["room"]])
			ok(lay["solid"].has("%d,%d" % [p["x"], p["z"]]) and GameDungeons.walk_cells(sp)["%d,%d" % [p["x"], p["z"]]] == "person", "%s: they are solid person cells" % place)
		ok(GameDungeons.solvable(sp), "%s: the floor is still walkable with people on it" % place)
		ok(kinds.size() >= 2, "%s: more than one kind of person" % place)
	var bad: Variant = GameDungeons.data()["dungeons"]["emberpeak"]["people"][0]["kind"]
	GameDungeons.data()["dungeons"]["emberpeak"]["people"][0]["kind"] = "ghost"
	ok(not GameDungeons.validate().is_empty(), "a person of an unknown kind fails the validator")
	GameDungeons.data()["dungeons"]["emberpeak"]["people"][0]["kind"] = bad
	ok(GameDungeons.validate().is_empty(), "(restored)")


func test_talk() -> void:
	var d := _dyn()
	var sp := "world/goblin_warrens"
	var rng_before := d.rng.state
	var marta := _person("goblin_warrens", "captive_trader")
	ok(GameDungeons.thing_near(sp, int(marta["x"]) + 1, int(marta["z"]), d).get("type", "") in ["person", "container", "feature", "lock"], "Use finds something beside a person")
	var t := GameDungeons.talk(d, sp, marta)
	ok(t["ok"] and t["did"] and t["text"].contains("frees") and (d.heir.gold > 0 or d.heir.inventory.size() > 0), "a prisoner is freed for a reward: %s" % t["text"])
	ok(GameDungeons.is_marked(d, "p", "goblin_warrens", "captive_trader"), "(marked)")
	var gold := d.heir.gold
	var again := GameDungeons.talk(d, sp, marta)
	ok(not again["did"] and d.heir.gold == gold and again["text"].contains("Hearthmere"), "freed once: then only thanks")
	d.world.year += 100.0
	ok(not GameDungeons.is_marked(d, "p", "goblin_warrens", "captive_trader"), "another captive comes after people_years")
	# the healer
	var bd := _dyn()
	var pil := _person("hollow_barrow", "lost_pilgrim")
	bd.heir.hp = 1
	var h := GameDungeons.talk(bd, "world/hollow_barrow", pil)
	ok(h["did"] and bd.heir.hp > 1, "a healer eases the heir: %s" % h["text"])
	var hp := bd.heir.hp
	ok(not GameDungeons.talk(bd, "world/hollow_barrow", pil)["did"] and bd.heir.hp == hp, "but once")
	var full := _dyn()
	ok(not GameDungeons.talk(full, "world/hollow_barrow", pil)["did"] and not GameDungeons.is_marked(full, "p", "hollow_barrow", "lost_pilgrim"), "a heir at full health is not charged the blessing")
	# the hint names the next key's room
	var gk := _person("hollow_barrow", "gravekeeper")
	var h1 := GameDungeons.talk(bd, "world/hollow_barrow", gk)
	ok(h1["text"].contains("ossuary") and h1["text"].contains("bone key"), "the gravekeeper says where the first key is: %s" % h1["text"])
	bd.dungeon_marks["y:hollow_barrow:bone_key"] = 1.0
	ok(GameDungeons.talk(bd, "world/hollow_barrow", gk)["text"].contains("knows that key"), "with the key in hand, what it is for")
	bd.dungeon_marks.erase("y:hollow_barrow:bone_key")
	bd.dungeon_marks["d:hollow_barrow:vault_door"] = 1.0
	ok(GameDungeons.talk(bd, "world/hollow_barrow", gk)["text"].contains("king's seal"), "then the next door's key")
	bd.dungeon_marks["d:hollow_barrow:tomb_door"] = 1.0
	ok(GameDungeons.talk(bd, "world/hollow_barrow", gk)["text"].contains("stands open"), "and when all is open, so they say")
	ok(d.rng.state == rng_before, "no die of the dynasty's was drawn")
	# saving
	var fresh := _dyn()
	ok(not fresh.to_dict().has("dungeon_marks"), "nobody helped: nothing saved")
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(bd.to_dict())))
	ok(back.dungeon_marks == bd.dungeon_marks, "marks come back")
	var junk := bd.to_dict()
	junk["dungeon_marks"] = {"p:a:b": 1.0, "p:a": 1.0, "p:a:b:c": 2.0}
	ok(GameDynasty.from_dict(JSON.parse_string(JSON.stringify(junk))).dungeon_marks.size() == 1, "damaged p marks are dropped")


func _go(s: GameSandbox, to: Vector2i) -> bool:
	var from := {s.heir: null}
	var queue: Array = [s.heir]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == to:
			break
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dir
			if not from.has(n) and GameInterior.passable(s.interior, n.x, n.y):
				from[n] = c
				queue.append(n)
	if not from.has(to):
		return false
	var steps: Array = []
	var cur := to
	while from[cur] != null:
		steps.push_front(cur)
		cur = from[cur]
	for st in steps:
		if not s.move(st.x - s.heir.x, st.y - s.heir.y)["ok"]:
			return false
	return s.heir == to


func test_walk() -> void:
	var d := _dyn()
	var s := GameSandbox.start(d)
	var door: Dictionary = GameSpaces.space("world/goblin_warrens")["door"]
	s.heir = Vector2i(int(door["x"]), int(door["z"]))
	s.use()
	s.denizens.clear()
	for t in GameDungeons.layout(s.space)["traps"]:
		GameDungeons.mark(d, "t", "goblin_warrens", str(t["id"]))
	var p := _person("goblin_warrens", "captive_trader")
	var pc := Vector2i(int(p["x"]), int(p["z"]))
	ok(s.interior["%d,%d" % [pc.x, pc.y]] == "person" and not GameInterior.passable(s.interior, pc.x, pc.y), "the person is a cell in the sandbox that cannot be walked into")
	var spot := Vector2i(-99, -99)
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = pc + dir
		if GameInterior.passable(s.interior, c.x, c.y) and spot.x == -99 and GameDungeons.thing_near(s.space, c.x, c.y, d).get("type", "") == "person":
			spot = c
	ok(_go(s, spot), "the heir walks up to the prisoner")
	var before := d.rng.state
	var r := s.use()
	ok(r["ok"] and r["text"].contains("frees"), "Use frees them: %s" % r["text"])
	ok(s.log.back()["kind"] == "dungeon" and d.rng.state == before, "the log says so and no die is drawn")
	var gen_a: Array = GameDungeons.layout(s.space)["people"].map(func(q): return [q["id"], q["x"], q["z"]])
	GameDungeons._layouts.clear()
	var gen_b: Array = GameDungeons.layout(s.space)["people"].map(func(q): return [q["id"], q["x"], q["z"]])
	ok(gen_a == gen_b, "where they stand is the same every time")
