## Variety in the open world's fights (data/combat/elites.json, GameVariety): elite foes, attack patterns telegraphed the round
## before, a guard that braces, a creature that calls for help, a legend's phases, and the legend's stage (title card, lair
## scenery, victory beat). The balance rule: every rule applies only to a fight with `variety` on, which only the open world sets;
## a hunt, a hunt-board legend and a fight the autopilot plays are exactly what they were (the hooks draw nothing and change
## nothing without it), rolls are keyed hashes of the seed and never the dynasty's dice, and a fight saved mid-round reloads.
## Run: godot --headless --path . -s res://tests/test_game_variety.gd
extends SceneTree

const Scen := preload("res://tests/round_scenarios.gd")

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
	test_dress()
	test_flag()
	test_inert()
	test_heavy()
	test_brace()
	test_call()
	test_mods()
	test_phases()
	test_stage()
	test_save()
	test_open_world()
	print("variety tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _game(seed_value: int = 11, level: int = 20) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.level = level
	return d


## A fight with one foe of `id` that cannot die, a heir that cannot either, and `pattern` given to the foe at `off` in its cycle.
func _duel(id: String, pattern: String, off: int, seed_value: int = 3) -> GameDynasty:
	var d := _game(seed_value)
	var b := d.start_encounter([id], "", 1.0, [d.heir.level], [[0, 0]])
	var e: Dictionary = b.enemies[0]
	e.erase("v")
	e.erase("elite")
	e["hp"] = 100000
	e["max_hp"] = 100000
	e["fearful"] = false
	d.heir.hp = 100000
	GameVariety.add_pattern(d, e, pattern, GameVariety.keyed(1, "t", 0))
	if pattern != "call":
		e["v"]["pt"][pattern]["off"] = off
	b.variety = true
	return d


func _types(events: Array, t: String) -> Array:
	return events.filter(func(ev): return str(ev["type"]) == t)


# ---------------------------------------------------------------- the data

func test_data() -> void:
	ok(GameVariety.validate().is_empty(), "the data is valid: %s" % str(GameVariety.validate()))
	var dat := GameVariety.data()
	var sav: Variant = dat["patterns"]["heavy"]["every"]
	dat["patterns"]["heavy"]["every"] = 2
	ok(not GameVariety.validate().is_empty(), "a pattern that cannot be telegraphed first is refused")
	dat["patterns"]["heavy"]["every"] = sav
	var m: Dictionary = dat["mods"]["swift"]
	m["reward"] = 0.5
	ok(not GameVariety.validate().is_empty(), "an elite that pays less than an ordinary foe is refused")
	m["reward"] = 1.35
	dat["bosses"]["grimfang"]["phases"].append({"at": 0.9})
	ok(not GameVariety.validate().is_empty(), "a phase that rises, or does nothing, is refused")
	dat["bosses"]["grimfang"]["phases"].pop_back()
	dat["assign"]["wolf"].append("nonsense")
	ok(not GameVariety.validate().is_empty(), "an assignment to an unknown pattern is refused")
	dat["assign"]["wolf"].pop_back()
	ok(GameVariety.validate().is_empty(), "and the data is whole again")
	var bosses: Array = GameData.creatures.filter(func(c): return c.get("boss", false))
	for c in bosses:
		ok(dat["bosses"].has(c["id"]) and str(dat["bosses"][c["id"]]["epithet"]) != "", "%s has an epithet and phases" % c["id"])
	for id in dat["mods"]:
		ok(float(dat["mods"][id]["reward"]) >= 1.3, "%s pays more" % id)


# ---------------------------------------------------------------- elites

func test_dress() -> void:
	var elites := 0
	var total := 0
	var named := true
	var paid := true
	for key in 600:
		var d := _game(5, 20)
		var foe := d.foe_for("wolf", 20)
		foe["con"] = "even"
		var base_xp := int(foe["xp"])
		var base_name := str(foe["name"])
		GameVariety.dress(d, [foe], [[key, 1]])
		total += 1
		if foe.has("elite"):
			elites += 1
			named = named and str(foe["name"]).ends_with(base_name) and str(foe["name"]) != base_name
			paid = paid and int(foe["xp"]) > base_xp
	var share := float(elites) / float(total)
	ok(share > 0.07 and share < 0.18, "about the elite chance of foes are elite: %.3f" % share)
	ok(named and paid, "an elite wears its prefix and pays more")
	# keyed, never the dynasty's dice
	var d1 := _game(5, 20)
	var d2 := _game(5, 20)
	var state_before := d1.rng.state
	var f1 := d1.foe_for("wolf", 20)
	var f2 := d2.foe_for("wolf", 20)
	f1["con"] = "even"
	f2["con"] = "even"
	GameVariety.dress(d1, [f1], [[7, 7]])
	GameVariety.dress(d2, [f2], [[7, 7]])
	ok(d1.rng.state == state_before and d2.rng.state == state_before, "dressing a foe draws nothing from the dynasty's dice")
	ok(JSON.stringify(f1) == JSON.stringify(f2), "the same seed and tile dress the same foe")
	var differs := false
	for k in 40:
		var a := _game(5, 20).foe_for("wolf", 20)
		var c := _game(6, 20).foe_for("wolf", 20)
		a["con"] = "even"
		c["con"] = "even"
		GameVariety.dress(_game(5, 20), [a], [[k, 0]])
		GameVariety.dress(_game(6, 20), [c], [[k, 0]])
		differs = differs or JSON.stringify(a) != JSON.stringify(c)
	ok(differs, "another seed dresses other foes")
	# who is never an elite
	var trivial := 0
	var boss_elite := false
	for key in 300:
		var d := _game(5, 20)
		var f := d.foe_for("wolf", 20)
		f["con"] = "trivial"
		f["fearful"] = true
		GameVariety.dress(d, [f], [[key, 1]])
		trivial += 1 if f.has("elite") or f.has("v") else 0
		var bs := d.foe_for("grimfang", 20)
		GameVariety.dress(d, [bs], [[key, 2]])
		boss_elite = boss_elite or bs.has("elite")
	ok(trivial == 0, "a fearful foe is never elite and has no pattern")
	ok(not boss_elite, "a legend is never made an elite")
	# a pack leader needs a pack
	var leaders := 0
	var lone := 0
	for key in 200:
		var d := _game(5, 20)
		var pack: Array = []
		for k in 3:
			var f := d.foe_for("wolf", 18 + k)
			f["con"] = "even"
			pack.append(f)
		GameVariety.dress(d, pack, [[key, 0], [key, 1], [key, 2]])
		for f in pack:
			leaders += 1 if str(f.get("elite", "")) == "pack_leader" else 0
		var one := d.foe_for("wolf", 20)
		one["con"] = "even"
		GameVariety.dress(d, [one], [[key, 9]])
		lone += 1 if str(one.get("elite", "")) == "pack_leader" else 0
	ok(leaders > 20 and leaders < 100 and lone == 0, "a pack of three sometimes has a leader (%d of 200), a lone foe never" % leaders)


# ---------------------------------------------------------------- the flag

func test_flag() -> void:
	var d := _game()
	ok(not d.start_hunt("hunt").variety, "a hunt has no variety")
	d = _game()
	ok(not d.start_hunt("hunt_hard").variety, "nor a hard hunt")
	d = _game(11, 30)
	d.heir.level = 40
	ok(d.start_legend() == null or not d.battle.variety, "nor a hunt-board legend")
	d = _game()
	ok(not d.start_encounter(["wolf"]).variety, "an encounter given no keys has none")
	d = _game()
	ok(not d.start_encounter(["wolf"], "", 1.0, [10]).variety, "nor one with only levels")
	d = _game()
	ok(d.start_encounter(["wolf"], "", 1.0, [10], [[1, 1]]).variety, "an encounter given keys has it")
	var b := _game().start_encounter(["wolf"], "", 1.0, [10], [[1, 1]])
	ok(b.to_dict().has("variety") and bool(b.to_dict()["variety"]), "and it is saved")


## The hooks do nothing without variety on foes: a fight with the flag on and plain foes plays exactly as with it off, byte
## for byte, whatever the class, party or kind (so no hook draws a die or changes a number).
func test_inert() -> void:
	var same := true
	var played := 0
	for seed_value in range(1, 13):
		for kind in ["hunt", "hunt_hard", "legend"]:
			var cls: String = Scen.CLASSES[seed_value % Scen.CLASSES.size()]
			var n: int = Scen.PARTY_SIZES[seed_value % Scen.PARTY_SIZES.size()]
			var runs: Array = []
			for on in [false, true]:
				var d := Scen.make(seed_value, cls, n, kind)
				d.battle.variety = on
				GameBot.fight(d)
				runs.append(Scen.digest({"log": d.battle.log if d.battle != null else d.journal, "dynasty": Scen.drop_sex(d.to_dict())}))
			played += 1
			same = same and runs[0] == runs[1]
	ok(same, "%d fights play the same with the flag on and plain foes" % played)
	# and a seeded autopilot life is what it always was: nothing in it starts a variety fight
	var a := Scen.live(3)
	var b := Scen.live(3)
	ok(a["digest"] == b["digest"], "a seeded autopilot life is the same twice")
	var d2 := GameDynasty.new_game(4, "Tess", "warrior", "faetouched", "human")
	var seen := false
	for g in 2:
		GameBot.live_life(d2)
		seen = seen or (d2.battle != null and d2.battle.variety)
		if d2.state == "succession":
			GameBot.choose_best(d2)
	ok(not seen, "the autopilot never meets variety")


# ---------------------------------------------------------------- patterns

func test_heavy() -> void:
	# off 0 with every 3: it winds up on a round where (turn + 0) % 3 == 1, the heavy blow the round after
	var d := _duel("ogre", "heavy", 0)
	var b := d.battle
	var wind_turn := -1
	var heavy_turn := -1
	var plain_amount := 0
	var heavy_amount := 0
	for r in 9:
		var t := b.turn
		b.attack(0)
		for ev in b.events:
			if str(ev["type"]) == "wind_up":
				ok(str(ev["pattern"]) == "heavy" and int(ev["index"]) == 0, "the telegraph names the foe and the blow")
				wind_turn = t
			if str(ev["type"]) == "damage" and str(ev["side"]) == "player":
				if bool(ev.get("heavy", false)):
					heavy_turn = t
					heavy_amount = int(ev["amount"])
				elif plain_amount == 0:
					plain_amount = int(ev["amount"])
		if heavy_turn >= 0:
			break
	ok(wind_turn >= 0 and heavy_turn == wind_turn + 1, "the heavy blow lands the round after it was announced (%d, %d)" % [wind_turn, heavy_turn])
	ok(heavy_amount > plain_amount * 1.4, "and hits much harder: %d against %d" % [heavy_amount, plain_amount])
	var said := b.log.filter(func(l): return str(l).contains("winding up a heavy blow"))
	ok(not said.is_empty(), "the log says it is winding up")
	# the player's answer: defending halves the heavy blow
	var plain := _duel("ogre", "heavy", 0)
	var guarded := _duel("ogre", "heavy", 0)
	var amounts: Array = []
	for fight in [plain, guarded]:
		var bb: GameBattle = fight.battle
		var got := 0
		for r in 9:
			var winding := false
			for ev in bb.events:
				winding = winding or str(ev["type"]) == "wind_up"
			if fight == guarded and winding:
				bb.defend()   # answered: the heir braces the round the blow comes
			else:
				bb.attack(0)
			for ev in bb.events:
				if str(ev["type"]) == "damage" and bool(ev.get("heavy", false)):
					got = int(ev["amount"])
			if got > 0:
				break
		amounts.append(got)
	ok(amounts[0] > 0 and amounts[1] > 0 and float(amounts[1]) < float(amounts[0]) * 0.7, "defending the round it comes takes the sting out: %s" % str(amounts))
	# it repeats, and never without a telegraph
	var d2 := _duel("ogre", "heavy", 1)
	var heavies := 0
	var winds := 0
	for r in 12:
		d2.battle.attack(0)
		heavies += _types(d2.battle.events, "damage").filter(func(ev): return bool(ev.get("heavy", false))).size()
		winds += _types(d2.battle.events, "wind_up").size()
	ok(heavies >= 3 and winds >= heavies and winds <= heavies + 1, "it comes every few rounds, each announced (%d blows, %d warnings)" % [heavies, winds])
	# with variety off the pattern does nothing at all
	var off := _duel("ogre", "heavy", 0)
	off.battle.variety = false
	var any := false
	for r in 8:
		off.battle.attack(0)
		any = any or not _types(off.battle.events, "wind_up").is_empty()
	ok(not any, "without the flag, no telegraph")


func test_brace() -> void:
	var d := _duel("skeleton", "brace", 0)
	var b := d.battle
	var braced_turn := -1
	for r in 8:
		var t := b.turn
		b.attack(0)
		if not _types(b.events, "guard_up").is_empty() and braced_turn < 0:
			braced_turn = t
			ok(_types(b.events, "damage").filter(func(ev): return str(ev["side"]) == "player").is_empty(), "a foe that braces spends its turn on it")
			ok(b.log.any(func(l): return str(l).contains("braces behind its guard")), "and the log says so")
			break
	ok(braced_turn >= 0, "the foe braces")
	ok(is_equal_approx(GameVariety.taken_mult(b, 0), 0.5), "and takes half until its next turn")
	var before := int(b.enemies[0]["hp"])
	b.attack(0)   # the heir's blow of the next round: the foe's guard is still up when it lands, and drops as the foe acts
	var after_guard := before - int(b.enemies[0]["hp"])
	ok(after_guard > 0, "the heir still hurts it")
	ok(is_equal_approx(GameVariety.taken_mult(b, 0), 1.0), "then the guard comes down")


func test_call() -> void:
	var d := _duel("wolf", "call", 0)
	var b := d.battle
	b.enemies[0]["hp"] = 100000
	ok(b.enemies.size() == 1, "one foe to begin with")
	for r in 4:
		b.attack(0)
	ok(b.enemies.size() == 1, "healthy, it calls no one")
	b.enemies[0]["hp"] = 30000   # below half
	var called := -1
	var joined := -1
	for r in 6:
		var t := b.turn
		b.attack(0)
		if not _types(b.events, "wind_up").is_empty() and called < 0:
			called = t
			ok(b.enemies.size() == 1, "the call is only announced the round it is made")
		if not _types(b.events, "summon").is_empty() and joined < 0:
			joined = t
			var ev: Dictionary = _types(b.events, "summon")[0]
			ok(int(ev["index"]) == b.enemies.size() - 1 and int(ev["by"]) == 0, "the summon event names the new foe's place and the caller")
	ok(called >= 0 and joined == called + 1, "help arrives the round after the call (%d, %d)" % [called, joined])
	ok(b.enemies.size() == 2 and int(b.enemies[1]["hp"]) > 0, "a second foe is in the fight")
	ok(float(b.enemies[1]["atk"]) < float(b.enemies[0]["atk"]) and int(b.enemies[1]["xp"]) < int(b.enemies[0]["xp"]), "weaker and worth less than the caller")
	ok(b.enemies[1].has("x") and b.enemies[1].has("y"), "it has a place on the field")
	for r in 6:
		b.attack(0)
	ok(b.enemies.size() == 2, "a call is made once")
	# killing the caller before the help comes stops it
	var d2 := _duel("wolf", "call", 0)
	var b2 := d2.battle
	b2.enemies[0]["hp"] = 40000
	b2.enemies[0]["max_hp"] = 100000
	b2.attack(0)
	ok(not _types(b2.events, "wind_up").is_empty() or b2.enemies.size() == 1, "announced")
	b2.enemies[0]["hp"] = 0
	b2.attack(0)
	ok(b2.enemies.size() == 1, "a caller felled in between brings no one")


func test_mods() -> void:
	var d := _game()
	var b := d.start_encounter(["goblin", "goblin"], "", 1.0, [20, 20], [[1, 1], [2, 2]])
	b.variety = true
	var a: Dictionary = b.enemies[0]
	var c: Dictionary = b.enemies[1]
	a.erase("v")
	c.erase("v")
	a["hp"] = 500
	a["max_hp"] = 1000
	ok(is_equal_approx(GameVariety.blow_mult(b, 0), 1.0) and is_equal_approx(GameVariety.taken_mult(b, 0), 1.0), "a plain foe is plain")
	a["v"] = {"rage": 0.8}
	ok(is_equal_approx(GameVariety.blow_mult(b, 0), 1.4), "a berserker at half health hits 40% harder")
	a["hp"] = 1000
	ok(is_equal_approx(GameVariety.blow_mult(b, 0), 1.0), "and not at all harder at full health")
	a["v"] = {"taken": 0.75}
	ok(is_equal_approx(GameVariety.taken_mult(b, 0), 0.75), "a warded foe takes a quarter less")
	a["v"] = {"lead": 0.12}
	ok(is_equal_approx(GameVariety.blow_mult(b, 1), 1.12) and is_equal_approx(GameVariety.blow_mult(b, 0), 1.0), "a pack leader's pack hits harder, the leader as it did")
	c["hp"] = 0
	a["hp"] = 0
	ok(is_equal_approx(GameVariety.blow_mult(b, 1), 1.0), "and not once the leader has fallen")
	a["hp"] = 400
	a["max_hp"] = 1000
	a["v"] = {"drain": 0.5}
	b.events = [{"type": "damage", "side": "player", "index": 0, "amount": 40, "crit": false, "absorbed": 0}]
	GameVariety.landed(b, 0, 40)
	ok(int(a["hp"]) == 420, "a vampire heals half of what it deals")
	a["hp"] = 995
	GameVariety.landed(b, 0, 40)
	ok(int(a["hp"]) == 1000, "never past its full health")
	# a real vampire in a real fight drinks
	var d2 := _duel("goblin", "heavy", 0)
	var b2 := d2.battle
	b2.enemies[0]["v"]["drain"] = 0.5
	b2.enemies[0]["hp"] = 50000
	b2.attack(0)
	ok(b2.log.any(func(l): return str(l).contains("drinks in")), "the log shows it drinking")


func test_phases() -> void:
	var d := _game(11, 40)
	d.heir.level = 40
	var ids := GameData.creatures.filter(func(c): return c.get("boss", false)).map(func(c): return str(c["id"]))
	var foe := d._make_enemy(GameCombat.creature_def("grimfang"), 1.0, 1.0, 15)
	GameVariety.dress_boss(d, foe)
	ok(foe["v"].has("reserve") and foe["v"]["reserve"].has("0"), "a legend's servants are made ahead")
	var b := d._begin_battle([foe], "legend")
	b.variety = true
	d.heir.hp = 100000
	var e: Dictionary = b.enemies[0]
	e["max_hp"] = 100000
	e["hp"] = 60000   # below its first phase (0.66)
	var atk0 := float(e["atk"])
	b.attack(0)
	var phases := _types(b.events, "phase")
	ok(phases.size() == 1 and int(phases[0]["step"]) == 1, "it takes up its first phase as its turn begins")
	ok(b.enemies.size() == 3, "and calls two wolves")
	ok(b.log.any(func(l): return str(l).contains("calls for its servants")), "the log says so")
	b.attack(0)
	ok(_types(b.events, "phase").is_empty() and b.enemies.size() == 3, "a phase is taken once")
	e["hp"] = 30000
	b.attack(0)
	ok(_types(b.events, "phase").size() == 1 and float(e["atk"]) > atk0 * 1.2, "the last phase enrages it")
	ok(e["v"]["pt"].has("heavy"), "and gives it a heavy blow")
	# with the flag off, none of it
	var d2 := _game(11, 40)
	var foe2 := d2._make_enemy(GameCombat.creature_def("grimfang"), 1.0, 1.0, 15)
	var b2 := d2._begin_battle([foe2], "legend")
	d2.heir.hp = 100000
	b2.enemies[0]["hp"] = int(float(b2.enemies[0]["max_hp"]) * 0.2)
	b2.attack(0)
	ok(_types(b2.events, "phase").is_empty() and b2.enemies.size() == 1, "a hunt-board legend has no phases")
	# a dungeon's legend, made through the dynasty, has them and the flag
	var d3 := _game(11, 40)
	d3.heir.level = 60
	var made := false
	for id in ids:
		d3.slain_bosses.erase(id)
	for c in d3.stirring_legends():
		var fight := d3.start_legend_at(str(c["id"]), true)
		made = fight != null and fight.variety and fight.enemies[0]["v"].has("phase")
		d3.battle = null
		break
	ok(made or d3.stirring_legends().is_empty(), "start_legend_at with variety gives the legend its phases")
	var plain := _game(11, 40)
	for c in plain.stirring_legends():
		var fight := plain.start_legend_at(str(c["id"]))
		ok(not fight.variety and not fight.enemies[0].has("v"), "and without it, none")
		break


# ---------------------------------------------------------------- the legend's stage

func test_stage() -> void:
	var d := _game(11, 40)
	var foe := d._make_enemy(GameCombat.creature_def("hollow_king"), 1.0, 1.0, 25)
	var b := d._begin_battle([foe], "legend")
	var card := GameVariety.intro(b)
	ok(str(card["name"]) == "Hollow King" and str(card["epithet"]) != "", "the title card has the legend's name and epithet: %s" % str(card))
	ok(GameVariety.arena_place(b) == "hollow_barrow", "a legend is fought in its lair")
	var hunt := _game().start_hunt("hunt")
	ok(GameVariety.intro(hunt).is_empty() and GameVariety.arena_place(hunt) == "", "a hunt has neither card nor lair")
	ok(GameVariety.victory_beat(d, b, 0).is_empty(), "no beat before the fight is won")
	var held := d.heirlooms.size()
	b.enemies[0]["hp"] = 0
	b.result = "victory"
	d.heirlooms.append({"name": str(foe["heirloom"]), "boss": "x", "gen": 1})
	var beat := GameVariety.victory_beat(d, b, held)
	ok(str(beat["title"]) == "Hollow King has fallen!" and bool(beat["claimed"]) and str(beat["line"]).contains(str(foe["heirloom"])), "the beat names the fall and the heirloom claimed: %s" % str(beat))
	var held_again := GameVariety.victory_beat(d, b, d.heirlooms.size())
	ok(not bool(held_again["claimed"]) and str(held_again["line"]).contains("already holds"), "a legend risen again leaves no second copy, and says so")
	# every legend has a lair that is a place with a scene
	for c in GameData.creatures:
		if c.get("boss", false):
			var db := _game(11, 60)
			var bb := db._begin_battle([db._make_enemy(c, 1.0, 1.0, 20)], "legend")
			ok(GameVariety.arena_place(bb) != "", "%s has an arena" % c["id"])
	# the screen's own pieces are made without error from a real fight (a fight with every kind of event)
	var view_events: Array = []
	var dv := _duel("ogre", "heavy", 0)
	for r in 6:
		dv.battle.attack(0)
		view_events.append_array(dv.battle.events)
	var bad := false
	for ev in view_events:
		if not GameEventSpec.problems(ev).is_empty():
			bad = true
	ok(not bad and not _types(view_events, "wind_up").is_empty(), "the telegraph events are on the list and well formed")


# ---------------------------------------------------------------- saving

func test_save() -> void:
	var d := _duel("wolf", "heavy", 0)
	d.heir.hp = d.heir.max_hp()
	d.battle.enemies[0]["hp"] = 40
	d.battle.enemies[0]["max_hp"] = 100
	d.battle.attack(0)
	d.battle.attack(0)
	var saved := d.to_save()
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(saved)))
	ok(back.battle != null and back.battle.variety, "a variety fight reloads with its flag")
	ok(back.battle.enemies[0].has("v") and back.battle.enemies[0]["v"]["pt"].has("heavy"), "and its foe's pattern")
	var a := d.battle
	var c := back.battle
	for r in 5:
		a.attack(0)
		c.attack(0)
	ok(JSON.stringify(a.events) == JSON.stringify(c.events) and a.log == c.log, "and plays on exactly as the one that was not saved")
	# an older save has no flag; a damaged one is not trusted
	var fight: Variant = Marshalls.base64_to_variant(str(saved["battle"]), false)
	fight["battle"].erase("variety")
	var old := saved.duplicate(true)
	old["battle"] = Marshalls.variant_to_base64(fight)
	var loaded := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(old)))
	ok(loaded.battle != null and not loaded.battle.variety, "a save from before has an ordinary fight")
	fight["battle"]["variety"] = "yes"
	old["battle"] = Marshalls.variant_to_base64(fight)
	loaded = GameDynasty.from_dict(JSON.parse_string(JSON.stringify(old)))
	ok(loaded.battle != null and not loaded.battle.variety, "a flag of the wrong kind is ignored")
	# and a fight saved in the middle of a round (the party's) keeps the foe's winding up
	var mid := _duel("ogre", "heavy", 0)
	mid.heir.hp = mid.heir.max_hp()
	for r in 8:
		mid.battle.attack(0)
		if not _types(mid.battle.events, "wind_up").is_empty():
			break
	var round_back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(mid.to_save())))
	round_back.battle.attack(0)
	mid.battle.attack(0)
	ok(_types(round_back.battle.events, "damage").any(func(ev): return bool(ev.get("heavy", false))) and JSON.stringify(round_back.battle.events) == JSON.stringify(mid.battle.events), "a reloaded fight delivers the blow it had announced")


# ---------------------------------------------------------------- the open world starts them

func test_open_world() -> void:
	var d := _game(11, 20)
	var s := GameSandbox.start(d)
	s.creatures.clear()
	var a := GameBehaviour.new_agent(1, "wolf", s.heir_point().x + 0.4, s.heir_point().y)
	a["mode"] = "chase"
	a["level"] = 20
	s.creatures.append(a)
	ok(s._contact() and d.battle != null and d.battle.variety, "a fight begun by contact has variety")
	var hunt := _game(11, 20)
	hunt.start_hunt("hunt")
	ok(not hunt.battle.variety, "a hunt does not")
	# a whole contact fight plays to an end with variety, events well formed
	var guard := 0
	var bad := false
	while d.battle != null and not d.battle.is_over() and guard < 300:
		guard += 1
		GameTactics.auto_turn(d.battle)
		for ev in d.battle.events:
			if not GameEventSpec.problems(ev).is_empty():
				bad = true
	ok(guard < 300 and not bad, "it plays to an end with well-formed events")
	# the same tile, the same seed: the same dressed foes
	var one: Array = []
	for k in 2:
		var dd := _game(11, 20)
		var fight := dd.start_encounter(["wolf", "wolf", "wolf"], "", 1.0, [20, 20, 20], [[3, 4], [3, 5], [3, 6]])
		one.append(JSON.stringify(fight.enemies))
	ok(one[0] == one[1], "the same tiles give the same fight")
