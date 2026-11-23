## A landmark that opens a dungeon's door (GameWildsSites.door_of, the `opens` of a landmark kind in data/world/wilds.json, GameWildsSites.use, GameSandbox.use): an
## explored cave whose guards are gone leads on to the door of the nearest dungeon whose entrance the open world draws (GameDungeonArt), the heir comes out on the door
## tile and can go in; an uncleared cave, a kind that does not open and a cave with no dungeon near lead nowhere; no dice of the dynasty's, nothing saved; a break is caught.
## Run: godot --headless --path . -s res://tests/test_game_wilds_portal.gd
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
	test_door()
	test_use()
	test_sandbox()
	test_none()
	test_breaks()
	print("wilds portal tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(seed_value: int = 7, gen: int = 1) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.gen = gen
	return d


## A cave on some seed, with a drawn dungeon near it (`with_dungeon`) or none: [dynasty, cave]; [] when none is found.
func _cave(with_dungeon: bool) -> Array:
	for seed_value in range(1, 30):
		var d := _dyn(seed_value)
		for area in ["greenvale", "whisperwood", "mirefen", "elderglade", "frostreach", "highcrag"]:
			var a := GameWorldGen.anchor(area)
			for r in range(0, 100, 6):
				for ang in 12:
					var x := int(a["x"]) + int(round(cos(float(ang) / 12.0 * TAU) * r))
					var z := int(a["z"]) + int(round(sin(float(ang) / 12.0 * TAU) * r))
					for lm in GameWildsSites.within(d, x, z, 12.0):
						if str(lm["kind"]) != "cave":
							continue
						var near := GameWildsSites.dungeon_near(lm)
						var drawn := not near.is_empty() and GameDungeonArt.entrance_rect(str(near["id"])).size != Vector2i.ZERO
						if drawn == with_dungeon:
							return [d, lm]
	return []


func test_data() -> void:
	ok(GameWildsFights.validate().is_empty(), "the data is sound: %s" % str(GameWildsFights.validate()))
	ok(bool(GameWilds.data()["landmarks"]["cave"]["opens"]), "a cave opens a way")
	ok(not bool(GameWilds.data()["landmarks"]["shrine"].get("opens", false)), "a shrine does not")


func test_door() -> void:
	var p := _cave(true)
	ok(p.size() == 2, "a cave with a drawn dungeon near it exists on some seed")
	if p.size() != 2:
		return
	var d: GameDynasty = p[0]
	var lm: Dictionary = p[1]
	var st := d.rng.state
	ok(GameWildsSites.door_of(d, lm).is_empty(), "an uncleared cave leads nowhere")
	GameWildsFights.won(d, lm)
	var door := GameWildsSites.door_of(d, lm)
	ok(not door.is_empty() and d.rng.state == st, "cleared, it leads on, with no die of the dynasty's drawn")
	var dungeon := GameWildsSites.dungeon_near(lm)
	ok(str(door["place"]) == str(dungeon["id"]), "to the nearest dungeon")
	var rect := GameDungeonArt.entrance_rect(str(door["place"]))
	ok(int(door["z"]) == rect.end.y - 1 and int(door["x"]) >= rect.position.x and int(door["x"]) < rect.end.x, "the door is the entrance's door tile on the open world")
	ok(GameWildsSites.door_of(d, lm) == door, "the same again")
	ok(GameWildsSites.door_of(d, {}).is_empty() and GameWildsSites.door_of(d, {"kind": "shrine", "id": "x", "x": 0, "z": 0}).is_empty(), "no landmark or a shrine: nowhere")
	var before := JSON.stringify(d.to_dict())
	GameWildsSites.door_of(d, lm)
	ok(JSON.stringify(d.to_dict()) == before, "nothing is saved by it")


func test_use() -> void:
	var p := _cave(true)
	if p.size() != 2:
		return
	var d: GameDynasty = p[0]
	var lm: Dictionary = p[1]
	var d2 := _dyn(int(d.seed_value))
	GameWildsFights.won(d, lm)
	d.wilds["used"] = {str(lm["id"]): {"gen": d.gen, "n": 1}}   # explored already
	var r := GameWildsSites.use(d, lm)
	ok(bool(r["ok"]) and r.has("door") and str(r["text"]).contains(str(GameWorld.place(str(r["door"]["place"]))["name"])), "using an explored, cleared cave leads on: %s" % r["text"])
	d2.wilds["used"] = {str(lm["id"]): {"gen": d2.gen, "n": 1}}
	var r2 := GameWildsSites.use(d2, lm)
	ok(not bool(r2["ok"]) and not r2.has("door"), "while its guards stand, an explored cave is just done")


func test_sandbox() -> void:
	var p := _cave(true)
	if p.size() != 2:
		return
	var d: GameDynasty = p[0]
	var lm: Dictionary = p[1]
	GameWildsFights.won(d, lm)
	d.wilds["used"] = {str(lm["id"]): {"gen": d.gen, "n": 1}}
	var s := GameSandbox.start(d)
	s.creatures.clear()
	s.heir = Vector2i(int(lm["x"]), int(lm["z"]))
	var r := s.use()
	ok(bool(r["ok"]) and r.has("door"), "Use at the cave leads on")
	ok(s.heir == Vector2i(int(r["door"]["x"]), int(r["door"]["z"])), "the heir stands on the dungeon's door tile")
	ok(s.door_here() != "", "where the door can be gone in by")
	var e := s.use()
	ok(bool(e["ok"]) and s.space != "world", "and Use again goes in")


func test_none() -> void:
	var p := _cave(false)
	if p.size() != 2:
		return
	var d: GameDynasty = p[0]
	var lm: Dictionary = p[1]
	GameWildsFights.won(d, lm)
	ok(GameWildsSites.door_of(d, lm).is_empty(), "a cave with no dungeon near leads nowhere")


func test_breaks() -> void:
	var data: Dictionary = GameWilds.data()
	var line: String = data["text"]["door_open"]
	data["text"].erase("door_open")
	ok(not GameWildsFights.validate().is_empty(), "a missing door line is caught")
	data["text"]["door_open"] = line
	ok(GameWildsFights.validate().is_empty(), "restored, sound again")
