## Creature contact in the open world (roadmap items 48 and 52): a creature that is hunting the heir and reaches them starts a
## fight with it (and others hunting within reach, to a cap), taken out of the open world; one that only wanders, flees or
## is still far off does not; nothing starts while a fight is on; the fight is the hunt's own (rewards, levels) and plays out
## to a finish; and the same seed gives the same fight.
## Run: godot --headless --path . -s res://tests/test_game_sandbox_contact.gd
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
	test_rules()
	test_step()
	test_fight()
	print("sandbox contact tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _sandbox(seed_value: int = 7) -> GameSandbox:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	var s := GameSandbox.start(d)
	s.creatures.clear()
	return s


## A creature in a given mode `dx` tiles east of the heir.
func _put(s: GameSandbox, id: String, mode: String, dx: float) -> Dictionary:
	var p := s.heir_point()
	var a := GameBehaviour.new_agent(900 + s.creatures.size(), id, p.x + dx, p.y)
	a["mode"] = mode
	s.creatures.append(a)
	return a


func _wild_id() -> String:
	return str(GameSpawn.wild()[0]["id"])


func test_rules() -> void:
	var id := _wild_id()
	var s := _sandbox()
	ok(not s._contact(), "nothing near, nothing starts")
	_put(s, id, "wander", 0.5)
	_put(s, id, "flee", 0.5)
	_put(s, id, "idle", 0.5)
	ok(not s._contact() and s.d.battle == null, "creatures that wander, flee or stand are no fight")
	s.creatures.clear()
	_put(s, id, "chase", 6.0)
	ok(not s._contact(), "a hunter still far off is no fight")
	s.creatures.clear()
	var a := _put(s, id, "chase", 1.0)
	ok(s._contact(), "a hunter that has reached the heir starts a fight")
	ok(s.d.battle != null and s.d.battle.enemies.size() == 1, "of one foe")
	ok(not s.creatures.has(a) and s.creatures.is_empty(), "and it leaves the open world")
	ok(s.log.size() > 0 and str(s.log[-1]["kind"]) == "fight" and str(s.log[-1]["text"]).contains("Tess"), "and the log says so: %s" % str(s.log[-1]["text"]))
	var again := s._contact()
	ok(not again, "no second fight while one is on")
	var s2 := _sandbox()
	for i in 6:
		_put(s2, id, "chase", 1.0 + 0.2 * i)
	ok(s2._contact() and s2.d.battle.enemies.size() == int(GameSandbox.setting("contact_max")), "a pack joins, to the cap")
	ok(s2.creatures.size() == 6 - int(GameSandbox.setting("contact_max")), "and the rest stay in the world")
	var s3 := _sandbox()
	_put(s3, id, "chase", 1.0)
	_put(s3, id, "chase", 8.0)
	_put(s3, id, "wander", 1.0)
	s3._contact()
	ok(s3.d.battle.enemies.size() == 1 and s3.creatures.size() == 2, "a far hunter and a wanderer do not join")
	var s4 := _sandbox()
	s4.d.state = "dead"
	_put(s4, id, "chase", 1.0)
	ok(not s4._contact() and s4.creatures.size() == 1, "nothing starts when the heir is not in life")
	ok(_sandbox().d.start_encounter([]) == null and _sandbox().d.start_encounter(["no_such_beast"]) == null, "a fight with nothing known is no fight")


func test_step() -> void:
	var s := _sandbox()
	_put(s, "wolf", "wander", 0.6)
	s.step()
	ok(s.d.battle != null, "a wolf beside the heir hunts them and a tick brings the fight")
	ok(s.creatures.is_empty() and str(s.log[-1]["kind"]) == "fight", "and it is out of the world and in the log")
	var calm := _sandbox()
	calm.step(5)
	ok(calm.d.battle == null and calm.log.is_empty(), "an empty world's ticks start no fight")


func test_fight() -> void:
	var s := _sandbox()
	_put(s, _wild_id(), "chase", 1.0)
	s._contact()
	var b: GameBattle = s.d.battle
	ok(s.d.battle_kind == "hunt", "it is a hunt, so its rewards and finish are the hunt's")
	var heir_level: int = s.d.heir.level
	ok(int(b.enemies[0]["level"]) >= 1 and int(b.enemies[0]["level"]) <= heir_level * 2 + 2, "its foe is built round the heir's level")
	var guard := 0
	while s.d.battle != null and s.d.battle.result == "" and guard < 400:
		GameBot.step(s.d)
		guard += 1
	ok(guard < 400 and (s.d.battle == null or s.d.battle.result != ""), "the autopilot plays the fight to an end")
	# the same seed gives the same foes
	var s5 := _sandbox(11)
	var s6 := _sandbox(11)
	_put(s5, _wild_id(), "chase", 1.0)
	_put(s6, _wild_id(), "chase", 1.0)
	s5._contact()
	s6._contact()
	ok(s5.d.battle.enemies[0]["hp"] == s6.d.battle.enemies[0]["hp"] and s5.d.battle.enemies[0]["level"] == s6.d.battle.enemies[0]["level"], "the same seed gives the same fight")
