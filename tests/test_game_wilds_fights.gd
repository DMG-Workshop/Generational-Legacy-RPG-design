## Landmarks that start fights (core/game/game_wilds_fights.gd, the `encounter` blocks of data/world/wilds.json, GameSandbox's approach and use triggers): who
## is met (by pool, era and count, on keyed dice), the approach trigger and its once-per-visit hold, a use trigger that springs an ambush, the ambush's free first
## blow (and its limit), the cooldowns, a win that clears the landmark and pays its find, a flight that does not, the saved marks and a break of each rule.
## Run: godot --headless --path . -s res://tests/test_game_wilds_fights.gd
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
	test_plan()
	test_approach()
	test_ambush()
	test_use()
	test_win_and_flee()
	test_cooldown()
	test_save()
	test_level()
	test_breaks()
	print("wilds fights tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(seed_value: int = 7, gen: int = 1) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.gen = gen
	return d


## A landmark of a kind (near any wilds area), found by looking round the anchors; {} when this seed has none.
func _lm(d: GameDynasty, kind: String) -> Dictionary:
	for area in ["greenvale", "whisperwood", "mirefen", "elderglade", "frostreach", "highcrag"]:
		var a := GameWorldGen.anchor(area)
		for r in range(0, 100, 5):
			for ang in 16:
				var x := int(a["x"]) + int(round(cos(float(ang) / 16.0 * TAU) * r))
				var z := int(a["z"]) + int(round(sin(float(ang) / 16.0 * TAU) * r))
				for lm in GameWildsSites.within(d, x, z, 12.0):
					if str(lm["kind"]) == kind:
						return lm
	return {}


func _sandbox(d: GameDynasty, lm: Dictionary, dz: int = 1) -> GameSandbox:
	var s := GameSandbox.start(d)
	s.creatures.clear()
	s.heir = Vector2i(int(lm["x"]), int(lm["z"]) + dz)
	return s


func _end_fight(d: GameDynasty, s: GameSandbox, result: String) -> void:
	d.battle = null
	d.last_result = result
	s.after_fight()


func test_data() -> void:
	ok(GameWildsFights.validate().is_empty(), "the data is sound: %s" % str(GameWildsFights.validate()))
	var d := _dyn()
	for kind in ["bandit_camp", "battlefield", "ruin", "cave"]:
		var lm := _lm(d, kind)
		ok(not lm.is_empty() and not GameWildsFights.block(lm).is_empty(), "%s has an encounter" % kind)
	ok(GameWildsFights.block(_lm(d, "shrine")).is_empty(), "a shrine has none")
	ok(GameWildsFights.block({}).is_empty(), "no landmark, no block")


func test_plan() -> void:
	var d := _dyn()
	var lm := _lm(d, "bandit_camp")
	var st := d.rng.state
	var p := GameWildsFights.plan(d, lm, "approach")
	ok(not p.is_empty() and d.rng.state == st, "an approach plan, and no die of the dynasty's drawn")
	var c: Array = GameWildsFights.block(lm)["count"]
	ok((p["foes"] as Array).size() >= int(c[0]) and (p["foes"] as Array).size() <= int(c[1]), "the count is within %s: %d" % [str(c), (p["foes"] as Array).size()])
	ok(GameWildsFights.plan(d, lm, "approach") == p, "the same plan again")
	for id in p["foes"]:
		ok(str(id) in ["bandit", "goblin"], "%s is of the pool" % id)
	ok(GameWildsFights.plan(d, lm, "nonsense").is_empty(), "a trigger it does not have gives nothing")
	ok(str(p["text"]).contains("bar"), "the line names what happens: %s" % p["text"])
	# the era: a first-era house meets only first-era creatures
	var bf := _lm(d, "battlefield")
	var early := GameWildsFights.plan(d, bf, "approach")
	for id in early["foes"]:
		var min_gen := 99
		for cr in GameData.creatures:
			if str(cr["id"]) == str(id):
				min_gen = int(cr.get("min_gen", 1))
		ok(min_gen <= d.era_gen(), "%s is of the era" % id)
	# a later fight (a different count) rolls a different set
	GameWildsFights.mark_fought(d, lm)
	var next: Array = GameWildsFights.foes_for(d, lm)
	ok(next.size() > 0, "and a second time round the landmark still sends someone")


func test_approach() -> void:
	var d := _dyn()
	var lm := _lm(d, "bandit_camp")
	var s := _sandbox(d, lm, 2)
	s.step(1)
	ok(d.battle != null and not s.fight_site.is_empty() and str(s.fight_site["id"]) == str(lm["id"]), "within range the guards set on the heir")
	ok(not d.sandbox_escape.is_empty(), "with the heir's way clear behind them recorded")
	ok(not GameWildsFights.fought_info(d, str(lm["id"])).is_empty(), "and the landmark is marked fought")
	ok(s.armed.has(str(lm["id"])), "and held for this visit")
	ok(not d.battle.heir_skip, "a camp's guards on the approach take no free blow")
	# far away nothing happens
	var d2 := _dyn()
	var s2 := _sandbox(d2, lm, 30)
	s2.step(1)
	ok(d2.battle == null, "far from the camp nothing starts")
	# a landmark with no approach trigger (a ruin) does not fire by walking up
	var d3 := _dyn()
	var ruin := _lm(d3, "ruin")
	var s3 := _sandbox(d3, ruin, 1)
	s3.step(1)
	ok(d3.battle == null, "a ruin is not set off by walking up to it")
	# upstairs / indoors never
	var d4 := _dyn()
	var s4 := _sandbox(d4, lm, 1)
	s4.space = "world/somewhere"
	s4.step(1)
	ok(d4.battle == null, "never indoors")


func test_ambush() -> void:
	var d := _dyn()
	var lm := _lm(d, "battlefield")
	var s := _sandbox(d, lm, 1)
	s.step(1)
	ok(d.battle != null and d.battle.heir_skip, "a battlefield's dead ambush: the first blow is theirs")
	ok(s.log.any(func(e): return str(e["text"]).contains("caught off guard")), "and it is told")
	# a heir already hurt below the limit is not surprised
	var h := _dyn()
	h.heir.hp = int(float(h.heir.max_hp()) * 0.3)
	var s2 := _sandbox(h, lm, 1)
	s2.step(1)
	ok(h.battle != null and not h.battle.heir_skip, "a heir below %d%% health is not caught off guard" % int(float(GameWilds.setting("surprise_min_hp")) * 100.0))


func test_use() -> void:
	var sprung := false
	var quiet := false
	for sd in range(1, 80):
		var d := _dyn(sd)
		var lm := _lm(d, "ruin")
		if lm.is_empty():
			continue
		var r := GameWildsSites.use(d, lm)
		if r.has("fight"):
			sprung = true
			ok(not (r["fight"]["foes"] as Array).is_empty() and bool(r["fight"]["ambush"]), "a sprung ambush names its foes and is a surprise")
			var s := _sandbox(d, lm, 0)
			s.heir = Vector2i(int(lm["x"]), int(lm["z"]))
			var u := s.use()
			ok(d.battle != null and not s.fight_site.is_empty(), "Use in the sandbox starts the fight: %s" % u["text"])
		else:
			quiet = true
			ok(bool(r["ok"]) or str(r["text"]) != "", "otherwise the search plays out as before")
		if sprung and quiet:
			break
	ok(sprung and quiet, "over seeds a search sometimes springs it and sometimes does not (%s, %s)" % [sprung, quiet])
	# a cleared ruin is searched in peace
	var d2 := _dyn()
	var lm2 := _lm(d2, "ruin")
	GameWildsFights.won(d2, lm2)
	ok(not GameWildsFights.use_springs(d2, lm2), "a cleared ruin springs nothing")
	ok(not GameWildsSites.use(d2, lm2).has("fight"), "and its search is free")


func test_win_and_flee() -> void:
	var d := _dyn()
	var lm := _lm(d, "bandit_camp")
	var s := _sandbox(d, lm, 1)
	s.step(1)
	var gold := d.heir.gold
	_end_fight(d, s, "victory")
	ok(GameWildsFights.cleared(d, str(lm["id"])) and s.fight_site.is_empty(), "a win clears the landmark")
	ok(s.log.any(func(e): return str(e["text"]).contains("silent")), "and says so")
	ok(not GameWildsFights.can_trigger(d, lm, "approach") and not GameWildsFights.can_trigger(d, lm, "use"), "nothing more to fight there")
	ok(GameWildsSites.available(d, str(lm["id"])), "its search can be taken now")
	var renewed := _dyn(7, 1 + int(GameWilds.setting("renew_gens")))
	renewed.wilds = d.wilds.duplicate(true)
	ok(not GameWildsFights.cleared(renewed, str(lm["id"])), "renewed generations later it is no longer cleared")
	# a flight
	var f := _dyn()
	var sf := _sandbox(f, lm, 1)
	sf.step(1)
	_end_fight(f, sf, "fled")
	ok(not GameWildsFights.cleared(f, str(lm["id"])), "a flight does not clear it")
	ok(sf.log.any(func(e): return str(e["text"]).contains("breaks away")), "and says so")
	ok(not GameWildsFights.can_trigger(f, lm, "approach"), "but the cooldown runs: no new fight this generation")
	# a defeat
	var g := _dyn()
	var sg := _sandbox(g, lm, 1)
	sg.step(1)
	_end_fight(g, sg, "defeat")
	ok(not GameWildsFights.cleared(g, str(lm["id"])), "a defeat does not clear it either")
	ok(d.heir.gold >= gold, "(the find is a bonus: gold never falls)")


func test_cooldown() -> void:
	var d := _dyn()
	var lm := _lm(d, "cave")
	var id := str(lm["id"])
	ok(GameWildsFights.can_trigger(d, lm, "approach"), "a fresh cave can")
	GameWildsFights.mark_fought(d, lm)
	ok(not GameWildsFights.can_trigger(d, lm, "approach"), "just fought: it cannot")
	d.world.year += float(GameWildsFights.block(lm)["renew_years"]) + 0.1
	ok(not GameWildsFights.can_trigger(d, lm, "approach"), "a year on in the same generation: still not (once a generation)")
	d.gen += 1
	ok(GameWildsFights.can_trigger(d, lm, "approach"), "the next generation, after the calendar's wait, it can")
	d.world.year -= 1.0
	var block: Dictionary = GameWildsFights.block(lm)
	block["repeatable"] = true
	var r := _dyn()
	GameWildsFights.mark_fought(r, lm)
	r.world.year += float(block["renew_years"]) + 0.1
	ok(GameWildsFights.can_trigger(r, lm, "approach"), "a repeatable landmark may fight again the same generation, after the wait")
	block["repeatable"] = false
	# a second visit in the same generation is held by the cooldown, not by `armed`
	var v := _dyn()
	var sv := _sandbox(v, lm, 1)
	sv.step(1)
	_end_fight(v, sv, "fled")
	sv.armed.clear()
	sv.step(1)
	ok(v.battle == null or str(sv.fight_site.get("id", "")) != id, "coming back the same generation does not set them on again")
	ok(id != "", "(ids are text)")


func test_save() -> void:
	var d := _dyn()
	var lm := _lm(d, "bandit_camp")
	ok(not d.to_dict().has("wilds") or not (d.to_dict()["wilds"] as Dictionary).has("fought"), "nothing saved until a fight")
	GameWildsFights.mark_fought(d, lm)
	GameWildsFights.won(d, lm)
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(GameWildsFights.cleared(back, str(lm["id"])) and not GameWildsFights.fought_info(back, str(lm["id"])).is_empty(), "the marks survive a save and load")
	ok(int(GameWildsFights.fought_info(back, str(lm["id"]))["n"]) == 1 and int(GameWildsFights.fought_info(back, str(lm["id"]))["gen"]) == d.gen, "with their count and generation")
	var bad := GameWildsFights.load_marks({"fought": {"nope": {"year": 1, "gen": 1, "n": 1}, "lm:5:5": {"year": "x", "gen": 1, "n": 1}, "lm:6:6": {"year": 2.5, "gen": 3, "n": 0}}, "cleared": {"lm:1:1": "a", "lm:2:2": 4, "junk": 1}})
	ok((bad.get("fought", {}) as Dictionary).keys() == ["lm:6:6"] and int(bad["fought"]["lm:6:6"]["n"]) == 1, "damaged fought marks are dropped or mended")
	ok((bad.get("cleared", {}) as Dictionary) == {"lm:2:2": 4}, "and cleared marks")
	ok(GameWildsFights.load_marks("junk").is_empty(), "a damaged record loads as nothing")
	ok(GameWildsSites.load_state({"found": ["lm:3:3"], "fought": {"lm:3:3": {"year": 1.0, "gen": 1, "n": 1}}}).has("fought"), "wilds load_state keeps them with the rest")


func test_level() -> void:
	var a := _dyn()
	var b := _dyn()
	var fa := a.start_encounter(["bandit"], "greenvale", 1.0)
	var fb := b.start_encounter(["bandit"], "greenvale", 2.0)
	ok(fa != null and fb != null and int(fb.enemies[0]["level"]) >= int(fa.enemies[0]["level"]) * 2 - 1, "a level multiplier of 2 doubles the foes' levels (%d against %d)" % [int(fb.enemies[0]["level"]), int(fa.enemies[0]["level"])])
	var c := _dyn()
	var d := _dyn()
	var fc := c.start_encounter(["bandit"], "greenvale")
	var fd := d.start_encounter(["bandit"], "greenvale", 1.0)
	ok(int(fc.enemies[0]["level"]) == int(fd.enemies[0]["level"]) and c.rng.state == d.rng.state, "the default multiplier changes nothing")


func test_breaks() -> void:
	var good := GameWilds._cache.duplicate(true)
	var lms: Dictionary = GameWilds._cache["landmarks"]
	lms["cave"]["encounter"]["pool"] = []
	ok(not GameWildsFights.validate().is_empty(), "an empty pool is refused")
	GameWilds._cache = good.duplicate(true)
	GameWilds._cache["landmarks"]["cave"]["encounter"]["pool"] = [{"id": "nonsuch", "w": 1}]
	ok(not GameWildsFights.validate().is_empty(), "an unknown creature is refused")
	GameWilds._cache = good.duplicate(true)
	GameWilds._cache["landmarks"]["cave"]["encounter"]["pool"] = [{"id": "sheep", "w": 1}]
	ok(not GameWildsFights.validate().is_empty(), "a farm animal is refused")
	GameWilds._cache = good.duplicate(true)
	GameWilds._cache["landmarks"]["cave"]["encounter"]["triggers"] = ["bump"]
	ok(not GameWildsFights.validate().is_empty(), "an unknown trigger is refused")
	GameWilds._cache = good.duplicate(true)
	GameWilds._cache["landmarks"]["cave"]["encounter"]["count"] = [1, 99]
	ok(not GameWildsFights.validate().is_empty(), "a count over the contact cap is refused")
	GameWilds._cache = good.duplicate(true)
	GameWilds._cache["landmarks"]["cave"]["encounter"]["range"] = 0
	ok(not GameWildsFights.validate().is_empty(), "an approach trigger with no range is refused")
	GameWilds._cache = good.duplicate(true)
	GameWilds._cache["landmarks"]["cave"]["encounter"]["text"].erase("won")
	ok(not GameWildsFights.validate().is_empty(), "a missing line is refused")
	GameWilds._cache = good.duplicate(true)
	GameWilds._cache["landmarks"]["cave"]["encounter"]["pool"] = [{"id": "elder_dragon", "w": 1}]
	ok(not GameWildsFights.validate().is_empty(), "a pool with no first-era creature is refused")
	GameWilds._cache = good
	ok(GameWildsFights.validate().is_empty(), "and the data is sound again")
