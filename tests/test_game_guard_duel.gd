## Guards that fight (roadmap item 52): a guard that reaches the threat it went out to meet fights it as a duel (the companion
## as a fighter against one foe of the creature, played out by GameTactics on dice of its own, so the dynasty's dice are not
## touched and the same fight comes out the same); a win drives the creature out of the world and brings the family a share of
## its gold; a loss leaves the guard hurt (1 hp at least) and resting at their post, the creature where it was; a guard hurt
## too much will not fight; a resting guard goes out to nothing; and the data checks.
## Run: godot --headless --path . -s res://tests/test_game_guard_duel.gd
extends SceneTree

var fails := 0
var checks := 0
const ID := "bren_cask"


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
	test_foe()
	test_duel()
	test_sandbox()
	test_resting()
	print("guard duel tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(level: int = 40) -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.level = level   # companions follow the heir's level (GameParty.sync)
	d.party.members.append({"id": ID, "name": GameParty.def(ID)["name"], "hp": 1, "mp": 0, "level": level, "gen": 1,
		"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
	d.party.history[ID] = {"name": GameParty.def(ID)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
		"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	d.party.rest(d)   # full health
	return d


func test_data() -> void:
	ok(GameCompanions.validate().is_empty(), "the shipped data passes: %s" % str(GameCompanions.validate()))
	var s: Dictionary = GameCompanions.data()["settings"]
	var keep: float = s["guard_gold_share"]
	s["guard_gold_share"] = 2.0
	ok(not GameCompanions.validate().is_empty(), "a share above 1 is caught")
	s["guard_gold_share"] = keep
	var rest: int = s["guard_rest_ticks"]
	s.erase("guard_rest_ticks")
	ok(not GameCompanions.validate().is_empty(), "a missing setting is caught")
	s["guard_rest_ticks"] = rest
	ok(GameCompanions.validate().is_empty(), "and putting them back clears it")


func test_foe() -> void:
	var d := _dyn()
	var state := d.rng.state
	var foe := d.foe_for("wolf", 12)
	ok(not foe.is_empty() and foe["level"] == 12 and foe["hp"] > 0 and foe["name"] != "", "a foe is built for a creature at a level: %s" % str(foe.get("name", "")))
	ok(d.rng.state == state, "with no dice")
	ok(d.foe_for("no_such_beast", 5).is_empty(), "and none for what is not a creature")
	ok(d.foe_for("wolf", 0)["level"] == 1, "a level below 1 is 1")


func test_duel() -> void:
	GameCompanions.data()["settings"]["guard_foe_level_mult"] = 0.25   # a strong guard against a weak foe: a clear win
	var d := _dyn(60)
	var state := d.rng.state
	var gold := d.heir.gold
	var r := GameCompanions.duel(d, ID, "wolf", 100)
	ok(r["ok"] and r["won"] and not r["refused"], "a strong guard beats a wolf: %s" % str(r))
	ok(r["gold"] > 0 and d.heir.gold == gold + int(r["gold"]), "and the family gets a share of its gold: %d" % int(r["gold"]))
	var foe := d.foe_for("wolf", int(round(float(d.party.member(ID)["level"]) * 0.25)))
	ok(int(r["gold"]) == int(round(float(foe["gold"]) * float(GameCompanions.setting("guard_gold_share")))), "which is guard_gold_share of it")
	ok(d.rng.state == state, "no dice of the dynasty's were drawn")
	ok(d.party.member(ID)["hp"] >= 1 and int(d.party.member(ID)["hp"]) == int(r["hp_after"]), "the guard's hp is kept on them")
	var again := _dyn(60)
	ok(JSON.stringify(GameCompanions.duel(again, ID, "wolf", 100)) == JSON.stringify(r), "the same fight comes out the same")
	var s: Dictionary = GameCompanions.data()["settings"]
	s["guard_foe_level_mult"] = 6.0
	var weak := _dyn(5)
	var lost := GameCompanions.duel(weak, ID, "wolf", 100)
	ok(lost["ok"] and not lost["won"] and lost["gold"] == 0 and weak.heir.gold == _dyn(5).heir.gold, "a guard against a foe six levels up loses and wins no gold: %s" % str(lost))
	ok(int(weak.party.member(ID)["hp"]) >= 1 and lost["hp_after"] < lost["hp_before"] and int(weak.party.member(ID)["hp"]) == lost["hp_after"], "and is hurt, never dead, and the hurt is kept on them (hp %d of %d)" % [lost["hp_after"], lost["hp_before"]])
	s["guard_foe_level_mult"] = 1.0
	var hurt := _dyn(60)
	hurt.party.member(ID)["hp"] = 1
	var hp := int(hurt.party.member(ID)["hp"])
	var refused := GameCompanions.duel(hurt, ID, "wolf", 100)
	ok(refused["refused"] and not refused["won"] and int(hurt.party.member(ID)["hp"]) == hp, "a guard hurt below the share will not fight, and is not hurt more: %s" % str(refused))
	ok(GameCompanions.duel(d, "nobody", "wolf", 1).is_empty() and GameCompanions.duel(d, ID, "no_such_beast", 1).is_empty(), "no fight with no companion or no creature")


## A sandbox with the guard hired and given the order, a post, and a wolf where the guard stands.
func _scene(level: int = 60) -> Dictionary:
	GameCompanions.data()["settings"]["guard_foe_level_mult"] = 0.25
	var d := _dyn(level)
	var s := GameSandbox.start(d)
	s.creatures.clear()
	s.order(ID, "guard")
	var at := s.heir_point() + Vector2(4, 0)
	var g := GameCompanions.new_agent(1, ID, at.x, at.y)
	g["order"] = "guard"
	s.companions = [g]
	var wolf := GameBehaviour.new_agent(900, "wolf", at.x + 0.8, at.y)
	s.creatures.append(wolf)
	return {"d": d, "s": s, "at": at}


func _engage(at: Vector2) -> Dictionary:
	return {"type": "engage", "id": ID, "x": at.x + 0.8, "z": at.y}


func test_sandbox() -> void:
	var sc := _scene()
	var s: GameSandbox = sc["s"]
	var d: GameDynasty = sc["d"]
	var gold := d.heir.gold
	var state := d.rng.state
	s._guard_fights(_engage(sc["at"]))
	ok(s.creatures.is_empty(), "a guard that wins drives the creature out of the world")
	ok(d.heir.gold > gold and str(s.log[-1]["text"]).contains("drives off") and str(s.log[-1]["text"]).contains("gold"), "and the family gets gold and is told: %s" % str(s.log[-1]["text"]))
	ok(d.rng.state == state, "with no dice of the dynasty's drawn")
	ok(int(s.companions[0]["rest_until"]) == 0, "a winner is not sent to rest")
	var far := _scene()
	far["s"]._guard_fights({"type": "engage", "id": ID, "x": far["at"].x + 9.0, "z": far["at"].y})
	ok(far["s"].creatures.size() == 1, "a fight with nothing at the place it names does nothing")
	var s2: Dictionary = GameCompanions.data()["settings"]
	var weak := _scene(5)
	s2["guard_foe_level_mult"] = 6.0
	weak["s"]._guard_fights(_engage(weak["at"]))
	ok(weak["s"].creatures.size() == 1, "a guard that loses leaves the creature where it is")
	ok(str(weak["s"].log[-1]["text"]).contains("hurt") and int(weak["s"].companions[0]["rest_until"]) == weak["s"].tick + int(GameCompanions.setting("guard_rest_ticks")), "and is hurt and sent to rest: %s" % str(weak["s"].log[-1]["text"]))
	var sick := _scene()
	sick["d"].party.member(ID)["hp"] = 1
	sick["s"]._guard_fights(_engage(sick["at"]))
	ok(sick["s"].creatures.size() == 1 and str(sick["s"].log[-1]["text"]).contains("too hurt") and int(sick["s"].companions[0]["rest_until"]) > 0, "a guard too hurt says so, rests and leaves it: %s" % str(sick["s"].log[-1]["text"]))
	var run := _scene()
	run["s"].creatures[0]["x"] = run["s"].heir_point().x + 2.0   # in sight of the heir, so a threat the guard goes out to
	run["s"].creatures[0]["z"] = run["s"].heir_point().y
	run["s"].companions[0]["x"] = run["at"].x
	var events: Array = []
	var guard := GameCompanions.new_agent(2, ID, run["s"].creatures[0]["x"] + 1.0, run["s"].creatures[0]["z"])
	guard["order"] = "guard"
	var view := GameCompanions.view(run["d"], run["s"].heir_point().x, run["s"].heir_point().y, [{"x": run["s"].creatures[0]["x"], "z": run["s"].creatures[0]["z"]}])
	GameCompanions._guard(guard, view, events, 100)
	ok(events.any(func(e): return e["type"] == "engage"), "a guard at the threat it went out to meet gives an engage event")
	ok(GameCompanions.event_text({"type": "engage", "id": ID, "name": "x"}) == "", "which says nothing itself (what the fight comes to is told)")


func test_resting() -> void:
	var d := _dyn()
	var s := GameSandbox.start(d)
	s.creatures.clear()
	var post := s.heir_point() + Vector2(3, 0)
	var g := GameCompanions.new_agent(1, ID, post.x, post.y)
	g["order"] = "guard"
	g["rest_until"] = 500
	var events: Array = []
	var view := GameCompanions.view(d, s.heir_point().x, s.heir_point().y, [{"x": post.x + 0.5, "z": post.y}])
	GameCompanions._guard(g, view, events, 100)
	ok(events.is_empty() and str(g["mode"]) in ["hold", "return"], "a guard that is resting goes out to nothing: %s" % str(g["mode"]))
	g["rest_until"] = 50
	GameCompanions._guard(g, view, events, 100)
	ok(events.any(func(e): return e["type"] == "engage"), "and goes out again once the rest is over")
	var old := GameCompanions.new_agent(3, ID, 1.0, 1.0)
	ok(int(old["rest_until"]) == 0, "a new companion agent is not resting")
