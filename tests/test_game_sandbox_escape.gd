## Getting away from a fight in the open world (roadmap item 48): a creature's contact records where the heir would fall back to,
## `escape_tiles` away on the far side of the creature (stopping short of anything in the way); fleeing the fight keeps that, any
## other end drops it; a new visit to the open world after a flight puts the heir there and says so; after anything else the heir
## is where they were; nothing is saved; and the text game's own flight is unchanged.
## Run: godot --headless --path . -s res://tests/test_game_sandbox_escape.gd
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
	test_tile()
	test_flight()
	test_other_ends()
	test_not_saved()
	print("sandbox escape tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _sandbox(seed_value: int = 7) -> GameSandbox:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	var s := GameSandbox.start(d)
	s.creatures.clear()
	return s


## A wolf `dx` tiles east of the heir, hunting.
func _wolf(s: GameSandbox, dx: float) -> Dictionary:
	var p := s.heir_point()
	var a := GameBehaviour.new_agent(900 + s.creatures.size(), "wolf", p.x + dx, p.y)
	a["mode"] = "chase"
	s.creatures.append(a)
	return a


func test_tile() -> void:
	var s := _sandbox()
	var n := int(GameSandbox.setting("escape_tiles"))
	var from := Vector2(s.heir_point().x + 1.0, s.heir_point().y)
	var t := s._escape_tile(from)
	ok(t.y == s.heir.y and s.heir.x - t.x == n, "on open ground the escape tile is the full %d tiles on the far side of the creature: %s from %s" % [n, str(t), str(s.heir)])
	ok(GamePath.passable(GamePath.world_ground(s.d), Vector3i(t.x, -1, t.y), GamePath.data()["movers"]["walker"]), "and can be stood on")
	var boxed := _sandbox()
	var big := Vector2(boxed.heir_point().x + 1.0, boxed.heir_point().y)
	GameCraft.add_material(boxed.d, "oak", 20)
	for dz in range(-1, 2):
		ok(GameBuild.place(boxed.d, "wall", boxed.heir.x - 1, -1, boxed.heir.y + dz)["ok"], "(a wall is built behind them)")
	var stuck := boxed._escape_tile(big)
	ok(stuck == boxed.heir, "with a wall right behind them there is nowhere to go: %s" % str(stuck))
	ok(s._escape_tile(s.heir_point()) != Vector2i(-99, -99), "a creature right on top of them is no problem")


func test_flight() -> void:
	var s := _sandbox()
	var d := s.d
	_wolf(s, 0.5)
	ok(d.sandbox_escape.is_empty(), "nothing is recorded before a fight")
	ok(s._contact() and d.battle != null, "a hunter reaches the heir and the fight begins")
	ok(not d.sandbox_escape.is_empty(), "and the way out is recorded")
	var fell_back := Vector2i(int(d.sandbox_escape["x"]), int(d.sandbox_escape["z"]))
	ok(fell_back != s.heir, "somewhere other than where the fight is")
	d.battle.result = "fled"
	d.finish_battle()
	ok(not d.sandbox_escape.is_empty(), "fleeing keeps it")
	var again := GameSandbox.start(d)
	ok(again.heir == fell_back, "the next visit puts the heir there, clear of the fight: %s" % str(again.heir))
	ok(d.sandbox_escape.is_empty(), "and uses it up")
	ok(again.log.size() > 0 and str(again.log[-1]["text"]).contains("clear of the fight"), "and says so (%d lines in the log)" % again.log.size())
	again.remember()   # the screen does this when it is left
	var third := GameSandbox.start(d)
	ok(third.heir == fell_back and third.log.is_empty(), "a visit after that is just where they are, with nothing said")


func test_other_ends() -> void:
	var s := _sandbox()
	var d := s.d
	_wolf(s, 0.5)
	s._contact()
	for e in d.battle.enemies:
		e["hp"] = 0
	d.battle.result = "victory"
	d.finish_battle()
	ok(d.sandbox_escape.is_empty(), "winning the fight drops it")
	var heir_then := s.heir
	d.sandbox_at = {"x": heir_then.x, "z": heir_then.y, "gen": d.gen, "place": str(d.world.location)}
	var after := GameSandbox.start(d)
	ok(after.heir == heir_then and after.log.is_empty(), "and the next visit starts where they were")
	var t := _sandbox()
	_wolf(t, 0.5)
	t._contact()
	t.d.battle = null   # a fight that is simply over (no result to flee from): handled like any other end
	t.d.sandbox_escape = {"x": 1, "z": 1}
	ok(GameSandbox.start(t.d).heir == Vector2i(1, 1), "a record left behind is used once there is no fight")
	var u := _sandbox()
	_wolf(u, 0.5)
	u._contact()
	var keep := u.d.sandbox_escape.duplicate()
	var during := GameSandbox.start(u.d)
	ok(during.heir == u.heir and u.d.sandbox_escape == keep, "while the fight is still on nothing is used")


func test_not_saved() -> void:
	var s := _sandbox()
	_wolf(s, 0.5)
	s._contact()
	ok(not s.d.sandbox_escape.is_empty(), "(there is a way out recorded)")
	var saved := s.d.to_dict()
	ok(not JSON.stringify(saved).contains("sandbox_escape"), "it is not in the save")
	var back := GameDynasty.from_dict(saved)
	ok(back.sandbox_escape.is_empty(), "and a loaded dynasty has none")
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.start_encounter(["wolf"])
	d.battle.result = "fled"
	var msgs := d.finish_battle()
	ok(not msgs.is_empty() and d.sandbox_escape.is_empty(), "the text game's own flight is as it was")
