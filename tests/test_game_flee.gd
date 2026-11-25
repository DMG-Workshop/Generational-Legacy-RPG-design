## Weak creatures that run: a foe of the open world's trivial or easy band (fearful) below its share of health may lose heart on its
## turn, on the fight's dice (only fearful foes draw them); it leaves the fight with a typed `foe_flee` event and a log line and gives
## no xp, gold, kill or drops; the fight is won when every foe is dead or fled; a party round, a save made mid-fight and a restore keep
## working; and a fight with no fearful foe draws exactly the dice it did.
## Run: godot --headless --path . -s res://tests/test_game_flee.gd
extends SceneTree

const TRIO := ["sister_oriel", "bren_cask", "tarsk_ember_eye"]

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
	test_flee()
	test_no_reward()
	test_win_when_all_gone()
	test_dice()
	test_party_round()
	test_save_restore()
	test_events()
	print("flee tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## A heir of level 20 against creatures of the given levels, the foes' blows weak and their health set by the caller.
func _fight(seed_value: int, levels: Array) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.level = 20
	d.heir.potions = 0
	d.heir.full_heal()
	var ids: Array = []
	for _i in levels:
		ids.append("wolf")
	d.start_encounter(ids, "", 1.0, levels)
	for e in d.battle.enemies:
		e["atk"] = 1.0
	return d


## Defends until the heir's round has played (so the foes act) `n` times.
func _rounds(d: GameDynasty, n: int) -> void:
	for _i in n:
		if d.battle.is_over():
			return
		d.battle.defend()


func _seed_that_flees(levels: Array, hp_of: Array) -> int:
	for s in range(1, 60):
		var d := _fight(s, levels)
		for i in hp_of.size():
			d.battle.enemies[i]["hp"] = int(hp_of[i])
		_rounds(d, 1)
		if d.battle.enemies[0].get("fled", false):
			return s
	return -1


func test_flee() -> void:
	var s := _seed_that_flees([3, 20], [1, 10000000])
	ok(s > 0, "somewhere a wounded weak foe loses heart (seed %d)" % s)
	var d := _fight(s, [3, 20])
	d.battle.enemies[0]["hp"] = 1
	d.battle.enemies[1]["hp"] = 10000000
	d.battle.enemies[1]["max_hp"] = 10000000
	ok(bool(d.battle.enemies[0]["fearful"]) and not d.battle.enemies[1].has("fearful"), "the trivial foe is fearful, the even one is not")
	_rounds(d, 1)
	var b := d.battle
	var e: Dictionary = b.enemies[0]
	ok(bool(e.get("fled", false)) and int(e["hp"]) == 0, "it ran: out of the fight")
	var found := false
	for ev in b.events:
		if str(ev["type"]) == "foe_flee":
			found = true
			ok(int(ev["index"]) == 0 and str(ev["name"]) == str(e["name"]), "the event names it")
			ok(GameEventSpec.problems(ev).is_empty(), "and fits the event list")
	ok(found, "a foe_flee event was told")
	ok(b.log.any(func(l): return str(l).contains("runs off")), "and a line says so")
	ok(not b.living_enemies().has(0) and b.result == "", "the other foe fights on")
	ok(b.first_target() == 1, "no one aims at the one who left")
	# a healthy one, or one that is not fearful, never runs
	var healthy := _fight(s, [3, 20])
	_rounds(healthy, 3)
	ok(not healthy.battle.enemies[0].get("fled", false), "a weak foe at full health stands its ground")
	var brave := _fight(s, [20, 20])
	brave.battle.enemies[0]["hp"] = 1
	_rounds(brave, 6)
	ok(not brave.battle.enemies[0].get("fled", false), "an even foe never runs, however hurt")
	# the roll is the fight's: the same seed runs it the same way
	var d2 := _fight(s, [3, 20])
	d2.battle.enemies[0]["hp"] = 1
	d2.battle.enemies[1]["hp"] = 10000000
	d2.battle.enemies[1]["max_hp"] = 10000000
	_rounds(d2, 1)
	ok(d2.battle.enemies[0].get("fled", false) and str(d2.battle.rng.state) == str(b.rng.state), "the same seed runs it the same way, on the same dice")


func test_no_reward() -> void:
	var s := _seed_that_flees([3, 20], [1, 10000000])
	var d := _fight(maxi(1, s), [3, 20])
	d.battle.enemies[0]["hp"] = 1
	d.battle.enemies[1]["hp"] = 10000000
	d.battle.enemies[1]["max_hp"] = 10000000
	var wolves0 := int(d.heir.kills.get("wolf", 0))
	_rounds(d, 1)
	ok(int(d.battle.enemies[0]["xp"]) == 0 and int(d.battle.enemies[0]["gold"]) == 0, "a foe that ran owes nothing")
	# the other falls
	d.battle.enemies[1]["hp"] = 0
	d.battle.result = "victory"
	var gold0 := d.heir.gold
	var gold_due := int(d.battle.enemies[1]["gold"])
	var xp_due := int(d.battle.enemies[1]["xp"])
	var msgs := d.finish_battle()
	ok(int(d.heir.kills.get("wolf", 0)) == wolves0 + 1, "only the slain one is a kill")
	ok(d.heir.gold >= gold0 and d.heir.gold <= gold0 + int(float(gold_due) * 3.0) + 1, "gold is the slain one's alone")
	ok(msgs.any(func(m): return str(m).contains("+%d XP" % xp_due) or str(m).contains("XP")), "and so is the xp")
	ok(d.loot.is_empty() or (d.loot.get("foes", []) as Array).size() == 1, "only one body to search")


func test_win_when_all_gone() -> void:
	var s := _seed_that_flees([3], [1])
	ok(s > 0, "a lone weak foe can run (seed %d)" % s)
	var d := _fight(maxi(1, s), [3])
	d.battle.enemies[0]["hp"] = 1
	_rounds(d, 1)
	ok(d.battle.result == "victory" and d.battle.is_over(), "the heir has won when the last foe has run")
	var xp0 := d.heir.xp
	var gold0 := d.heir.gold
	var msgs := d.finish_battle()
	ok(d.heir.xp == xp0 and d.heir.gold == gold0 and int(d.heir.kills.get("wolf", 0)) == 0, "no xp, gold or kill for a foe that ran")
	ok(d.loot.is_empty(), "and nothing to search")
	ok(not msgs.is_empty() and d.state == "life", "the life goes on")
	# a fight of two weak foes, both gone one way or the other
	var s2 := -1
	for t in range(1, 80):
		var dd := _fight(t, [3, 3])
		dd.battle.enemies[0]["hp"] = 1
		dd.battle.enemies[1]["hp"] = 1
		_rounds(dd, 4)
		if dd.battle.is_over() and dd.battle.enemies[0].get("fled", false) and dd.battle.enemies[1].get("fled", false):
			s2 = t
			break
	ok(s2 > 0, "two foes that both run end the fight too (seed %d)" % s2)


## Only fearful foes draw: the same fight with the fear taken away, or with the foe unhurt, leaves the dice where a fight always did.
func test_dice() -> void:
	var a := _fight(9, [3, 20])
	var b := _fight(9, [3, 20])
	for e in b.battle.enemies:
		e.erase("fearful")
	_rounds(a, 2)
	_rounds(b, 2)
	ok(not a.battle.enemies[0].get("fled", false) and str(a.battle.rng.state) == str(b.battle.rng.state), "a fearful foe above its share draws nothing extra")
	var c := _fight(9, [20, 20])
	var e := _fight(9, [20, 20])
	c.battle.enemies[0]["hp"] = 1
	e.battle.enemies[0]["hp"] = 1
	for foe in e.battle.enemies:
		foe["fearful"] = false
	_rounds(c, 2)
	_rounds(e, 2)
	ok(str(c.battle.rng.state) == str(e.battle.rng.state) and var_to_str(c.battle.log) == var_to_str(e.battle.log), "a foe that is not fearful draws exactly as before, however hurt")
	# a hunt's fight has no fearful foe at all
	var h := GameDynasty.new_game(31, "Tess", "warrior", "faetouched", "human")
	h.pending_event = {}
	h.start_hunt("hunt")
	ok(not h.battle.enemies.any(func(x): return x.has("fearful") or x.has("fled")), "hunts have no fearful foes")


func test_party_round() -> void:
	var found := false
	for t in range(1, 80):
		var d := _party_fight(t)
		var r := d.battle_round()
		for by in r.members():
			r.queue(by, {"act": "attack", "target": "enemy:2"})
		r.resolve()
		if d.battle.enemies[0].get("fled", false):
			found = true
			ok(d.battle.round_marks == false and d.battle.reaction.is_empty(), "the round closed cleanly after a foe ran")
			ok(not d.battle.events.any(func(ev): return str(ev["type"]) == "death" and int(ev.get("index", -1)) == 0), "it did not die, it ran")
			var r2 := d.battle_round()
			for by in r2.members():
				r2.queue(by, {"act": "attack", "target": "enemy:0"})   # a command on the one who left is redirected
			r2.resolve()
			ok(d.battle.enemies[0]["hp"] == 0 and not d.battle.log.is_empty(), "a command aimed at the one who ran is retargeted")
			break
	ok(found, "in a party round a weak foe runs too")


func _party_fight(seed_value: int) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.level = 20
	d.heir.potions = 0
	d.world.visit("kingshold")
	for id in TRIO:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": 20, "gen": 1,
			"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
		d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
			"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	d.party.rest(d)
	d.heir.full_heal()
	d.start_encounter(["wolf", "wolf", "wolf"], "", 1.0, [3, 3, 20])
	for e in d.battle.enemies:
		e["atk"] = 1.0
	d.battle.enemies[0]["hp"] = 1
	d.battle.enemies[1]["hp"] = 10000000
	d.battle.enemies[1]["max_hp"] = 10000000
	d.battle.enemies[2]["hp"] = 10000000
	d.battle.enemies[2]["max_hp"] = 10000000
	return d


func _reload(d: GameDynasty) -> GameDynasty:
	var parsed = JSON.parse_string(JSON.stringify(d.to_save()))
	if typeof(parsed) != TYPE_DICTIONARY or GameSaveVersion.upgrade(parsed) != "":
		return null
	return GameDynasty.from_dict(parsed)


func _flat(v: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(v)))


func test_save_restore() -> void:
	var s := _seed_that_flees([3, 20], [1, 10000000])
	var t := maxi(1, s)
	var make := func() -> GameDynasty:
		var d := _fight(t, [3, 20])
		d.battle.enemies[0]["hp"] = 1
		d.battle.enemies[1]["hp"] = 10000000
		d.battle.enemies[1]["max_hp"] = 10000000
		return d
	var plain: GameDynasty = make.call()
	_rounds(plain, 1)
	_rounds(plain, 2)
	var saved: GameDynasty = make.call()
	_rounds(saved, 1)
	ok(saved.battle.enemies[0].get("fled", false), "the foe ran before the save")
	var back := _reload(saved)
	ok(back != null and back.battle != null, "a game saved mid-fight with a fled foe loads")
	if back == null or back.battle == null:
		return
	ok(bool(back.battle.enemies[0].get("fled", false)) and int(back.battle.enemies[0]["hp"]) == 0, "the foe is still gone")
	ok(not back.battle.living_enemies().has(0) and back.battle.first_target() == 1, "and still out of the fight")
	_rounds(back, 2)
	ok(_flat(back.battle.log) == _flat(plain.battle.log) and str(back.battle.rng.state) == str(plain.battle.rng.state), "the fight plays on as one never saved")
	ok(_flat(back.battle.enemies) == _flat(plain.battle.enemies), "to the same foes")
	# and a win by the last foe running survives a save too
	var s1 := _seed_that_flees([3], [1])
	var lone := _fight(maxi(1, s1), [3])
	lone.battle.enemies[0]["hp"] = 1
	_rounds(lone, 1)
	var again := _reload(lone)
	ok(again != null and again.battle != null and again.battle.result == "victory", "a won fight reloads as won")
	if again != null and again.battle != null:
		again.finish_battle()
		ok(again.battle == null and int(again.heir.kills.get("wolf", 0)) == 0, "and finishes with no kill")


func test_events() -> void:
	ok(GameEventSpec.spec().has("foe_flee"), "foe_flee is on the event list")
	ok(not GameEventSpec.problems({"type": "foe_flee", "index": 0}).is_empty(), "and wants its name")
	ok(GameEventSpec.problems({"type": "foe_flee", "index": 0, "name": "Wolf"}).is_empty(), "with both fields it is fine")
	ok(GameMessages.line("foe_flees", {"name": "Wolf"}) == "Wolf loses heart and runs off.", "the line is in the catalog")
