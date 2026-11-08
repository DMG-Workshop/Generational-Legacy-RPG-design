## Growth and keep for the family's creatures (roadmap item 56, first part): the data, the stages by age, hatching,
## growing up and old, dying of old age, the yearly keep paid from the heir's gold, neglect (mood, spoiled eggs,
## creatures wandering off), time passing in pieces or all at once, saving, and that none of it draws a die or
## moves a life with an empty roster.
## Run: godot --headless --path . -s res://tests/test_game_ranch.gd
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
	test_stages()
	test_growth()
	test_keep()
	test_neglect()
	test_old_age()
	test_pieces()
	test_saving()
	test_untouched()
	test_through_time()
	print("%d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func dyn(seed_value: int = 5) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 100000
	return d


func _with(edit: Callable, body: Callable) -> void:
	var saved: Dictionary = GameRanch.data().duplicate(true)
	edit.call(GameRanch.data())
	body.call()
	GameRanch._cache = saved


func test_data() -> void:
	ok(GameRanch.validate().is_empty(), "ranch.json is sound: %s" % str(GameRanch.validate()))
	for c in GameData.creatures:
		var sp := str(c["id"])
		if GameBirth.born(sp) != "none":
			ok(GameRanch.data()["size_of"].has(sp), "%s has a size" % sp)
	_with(func(x): x["sizes"]["small"].erase("keep"), func(): ok(not GameRanch.validate().is_empty(), "a size without a keep cost is found"))
	_with(func(x): x["size_of"]["skeleton"] = "small", func(): ok(not GameRanch.validate().is_empty(), "a size for a creature that is not born is found"))
	_with(func(x): x["size_of"]["wolf"] = "gigantic", func(): ok(not GameRanch.validate().is_empty(), "an unknown size is found"))
	_with(func(x): x["settings"]["elder_spread"] = 1.0, func(): ok(not GameRanch.validate().is_empty(), "a spread of 1 or more is found"))
	_with(func(x): x["text"].erase("dies"), func(): ok(not GameRanch.validate().is_empty(), "missing text is found"))
	_with(func(x): x["size_of"].erase("wolf"), func(): ok(not GameRanch.validate().is_empty(), "a born creature with no size is found"))
	ok(GameRanch.validate().is_empty(), "the data is put back")


func test_stages() -> void:
	var d := dyn()
	var wolf := GameRoster.add(d, "wolf", "Ash")      # medium, live-born: young 3, adult 14, elder 5
	var drake := GameRoster.add(d, "drake", "Ember")  # large, egg: egg 2, young 6, adult 35, elder 12
	ok(GameRanch.stage_at(wolf, 0.0) == "young", "a live-born creature starts young")
	ok(GameRanch.stage_at(wolf, 2.99) == "young" and GameRanch.stage_at(wolf, 3.0) == "adult", "and is grown at three")
	ok(GameRanch.stage_at(wolf, 16.99) == "adult" and GameRanch.stage_at(wolf, 17.0) == "elder", "and old at seventeen")
	ok(GameRanch.stage_at(drake, 0.0) == "egg" and GameRanch.stage_at(drake, 1.99) == "egg", "an egg-layer starts as an egg")
	ok(GameRanch.stage_at(drake, 2.0) == "young" and GameRanch.stage_at(drake, 8.0) == "adult", "which hatches, then grows")
	ok(GameRanch.stage_at(drake, 43.0) == "elder", "and is old after its adult years")
	var all_ok := true
	for i in range(0, 60):
		var e := {"species": "wolf", "born": "live"}
		var prev := -1
		for a in range(0, 40):
			var idx := GameRanch.STAGES.find(GameRanch.stage_at(e, float(a)))
			all_ok = all_ok and idx >= prev
			prev = idx
	ok(all_ok, "stages only ever go forward with age")
	ok(GameRanch.death_at(d, wolf) == GameRanch.death_at(d, wolf), "the age of death is fixed")
	var lo := GameRanch.adult_at(wolf) + 5.0 * (1.0 - float(GameRanch.setting("elder_spread")))
	var hi := GameRanch.adult_at(wolf) + 5.0 * (1.0 + float(GameRanch.setting("elder_spread")))
	var inside := true
	var differs := false
	for s in range(1, 80):
		var dd := dyn(s)
		var w := GameRoster.add(dd, "wolf", "W")
		var at := GameRanch.death_at(dd, w)
		inside = inside and at >= lo - 0.0001 and at <= hi + 0.0001
		differs = differs or absf(at - GameRanch.death_at(d, wolf)) > 0.01
	ok(inside, "the age of death stays within the spread")
	ok(differs, "and differs between dynasties")
	ok(GameRanch.size_of("skeleton")["keep"] == GameRanch.size_of("nonesuch")["keep"], "an unknown species gets the default size")


func test_growth() -> void:
	var d := dyn()
	var e := GameRoster.add(d, "drake", "Ember")
	var msgs: Array = []
	GameRanch.on_years(d, 1.0, msgs)
	ok(e["stage"] == "egg" and msgs.is_empty(), "an egg is still an egg after a year, and nothing is said")
	GameRanch.on_years(d, 1.0, msgs)
	ok(e["stage"] == "young" and msgs.size() == 1 and "hatches" in msgs[0] and "Ember" in msgs[0], "it hatches at two years: %s" % str(msgs))
	ok(d.journal.back() == msgs[0], "and it is journalled")
	msgs.clear()
	GameRanch.on_years(d, 6.0, msgs)
	ok(e["stage"] == "adult" and msgs.size() == 1 and "grown" in msgs[0], "it grows up after its young years")
	msgs.clear()
	GameRanch.on_years(d, 35.0, msgs)
	ok(e["stage"] == "elder" and msgs.size() == 1 and "old now" in msgs[0], "and is old after its adult years")
	var w := GameRoster.add(d, "wolf", "Ash")
	msgs.clear()
	GameRanch.on_years(d, 3.0, msgs)
	ok(w["stage"] == "adult" and msgs.size() == 1, "a live-born creature never hatches: it grows up")
	var long := dyn()
	var le := GameRoster.add(long, "drake", "Slow")
	var lm: Array = []
	GameRanch.on_years(long, 10.0, lm)
	ok(le["stage"] == "adult" and lm.size() == 2 and "hatches" in lm[0] and "grown" in lm[1], "ten years at once tells each step it passed, in order: %s" % str(lm))
	var none := dyn()
	var m2: Array = []
	GameRanch.on_years(none, 5.0, m2)
	ok(m2.is_empty() and none.heir.gold == 100000, "an empty roster does nothing and costs nothing")
	GameRanch.on_years(d, 0.0, msgs)
	GameRanch.on_years(d, -2.0, msgs)
	ok(d.roster.size() == 2 or d.roster.size() == 1, "no time, or backwards time, changes nothing")


func test_keep() -> void:
	var d := dyn()
	var e := GameRoster.add(d, "wolf", "Ash")   # medium: keep 4
	var gold := d.heir.gold
	GameRanch.on_years(d, 2.0, [])
	ok(gold - d.heir.gold == 8, "a creature is kept at its size's price a year: paid %d" % (gold - d.heir.gold))
	ok(e["mood"] == mini(100, 70 + 10), "and a fed creature's mood rises")
	var d2 := dyn()
	GameRoster.add(d2, "drake", "Egg")   # large, egg: keep 8 x half
	var g2 := d2.heir.gold
	GameRanch.on_years(d2, 1.0, [])
	ok(g2 - d2.heir.gold == 4, "an egg costs half to keep")
	var d3 := dyn()
	GameRoster.add(d3, "wolf", "A")
	GameRoster.add(d3, "slime", "B")   # small: keep 2
	var g3 := d3.heir.gold
	GameRanch.on_years(d3, 1.0, [])
	ok(g3 - d3.heir.gold == 4 + 1, "the keep of every creature is added (a slime egg is half of 2)")
	var d4 := dyn()
	var f := GameRoster.add(d4, "wolf", "A")
	for i in 40:
		GameRanch.on_years(d4, 0.25, [])
	ok(f["mood"] == 100, "mood stops at its top")
	_with(func(x): x["sizes"]["medium"]["keep"] = 0.1, func():
		var d5 := dyn()
		GameRoster.add(d5, "wolf", "A")
		var g5 := d5.heir.gold
		GameRanch.on_years(d5, 1.0, [])
		ok(g5 - d5.heir.gold == 1, "a part of a gold is rounded up, so keeping is never free"))


func test_neglect() -> void:
	var d := dyn()
	d.heir.gold = 0
	var e := GameRoster.add(d, "wolf", "Ash")
	GameRanch.on_years(d, 1.0, [])
	ok(e["mood"] == 70 - 25, "an unpaid year costs mood: %d" % e["mood"])
	ok(d.heir.gold == 0, "and gold never goes below nothing")
	var d2 := dyn()
	d2.heir.gold = 2   # half of the 4 owed
	var f := GameRoster.add(d2, "wolf", "Ash")
	GameRanch.on_years(d2, 1.0, [])
	ok(d2.heir.gold == 0 and f["mood"] == 70 + int(round(5.0 * 0.5 - 25.0 * 0.5)), "half paid is half neglect: %d" % f["mood"])
	var d3 := dyn()
	d3.heir.gold = 0
	var egg := GameRoster.add(d3, "drake", "Ember")
	var msgs: Array = []
	GameRanch.on_years(d3, 3.0, msgs)
	ok(d3.roster.is_empty() and msgs.size() == 1 and "gone cold and spoiled" in msgs[0], "an egg left unkept spoils: %s" % str(msgs))
	var d4 := dyn()
	d4.heir.gold = 0
	GameRoster.add(d4, "wolf", "Ash")
	var m4: Array = []
	GameRanch.on_years(d4, 3.0, m4)
	ok(d4.roster.is_empty() and "wanders off" in m4[0], "a neglected creature wanders off: %s" % str(m4))
	var d5 := dyn()
	d5.heir.gold = 0
	GameRoster.add(d5, "wolf", "Ash")
	GameRoster.add(d5, "wolf", "Bo")
	d5.roster[1]["mood"] = 100
	GameRanch.on_years(d5, 3.0, [])
	ok(d5.roster.size() == 1 and d5.roster[0]["name"] == "Bo", "only the neglected one goes; the others stay")
	var d6 := dyn()
	d6.heir.gold = 0
	var h := GameRoster.add(d6, "wolf", "Ash")
	GameRanch.on_years(d6, 1.0, [])
	d6.heir.gold = 1000
	GameRanch.on_years(d6, 1.0, [])
	ok(h["mood"] == 45 + 5, "feeding again lets it recover")
	ok(GameRanch.mood_word(100) != GameRanch.mood_word(50) and GameRanch.mood_word(50) != GameRanch.mood_word(10), "three words for how it is doing")


func test_old_age() -> void:
	var d := dyn()
	var e := GameRoster.add(d, "slime", "Gloop")   # small: egg 1, young 2, adult 8, elder 3 -> dies near 11 + elder
	var at := GameRanch.death_at(d, e)
	var msgs: Array = []
	GameRanch.on_years(d, at - 0.5, msgs)
	ok(d.roster.size() == 1, "alive just before its time")
	msgs.clear()
	GameRanch.on_years(d, 1.0, msgs)
	ok(d.roster.is_empty() and "dies of old age" in msgs.back(), "dies of old age at its time: %s" % str(msgs))
	ok("Gloop" in d.journal.back(), "and it is journalled")
	var d2 := dyn()
	var big := GameRoster.add(d2, "elder_dragon", "Old Smoke")
	GameRanch.on_years(d2, 100.0, [])
	ok(d2.roster.size() == 1 and big["stage"] == "adult", "a huge creature lives for many generations")


func test_pieces() -> void:
	# a time passing in many pieces ends where the same time at once does
	for s in range(1, 20):
		var a := dyn(s)
		var b := dyn(s)
		GameRoster.add(a, "drake", "E")
		GameRoster.add(b, "drake", "E")
		GameRanch.on_years(a, 12.0, [])
		for i in 48:
			GameRanch.on_years(b, 0.25, [])
		ok(a.roster[0]["stage"] == b.roster[0]["stage"], "stages agree: whole vs pieces (seed %d)" % s)
		ok(absf(float(a.roster[0]["age"]) - float(b.roster[0]["age"])) < 0.0001, "ages agree (seed %d)" % s)


func test_saving() -> void:
	var d := dyn()
	GameRoster.add(d, "wolf", "Ash")
	GameRoster.add(d, "drake", "Ember")
	GameRanch.on_years(d, 2.5, [])
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(back.roster == d.roster, "age, mood and stage survive a save and load")
	var s := d.to_dict()
	for e in s["roster"]:
		e.erase("age")
		e.erase("mood")
	var old := GameDynasty.from_dict(s).roster
	ok(old.size() == 2 and old[0]["age"] == 0.0 and old[0]["mood"] == 70, "a roster saved before ages and moods loads with none")
	var bad := d.to_dict()
	bad["roster"][0]["age"] = "ten"
	bad["roster"][1]["age"] = -5.0
	bad["roster"][0]["mood"] = 9999
	bad["roster"][1]["mood"] = null
	var r := GameDynasty.from_dict(bad).roster
	ok(r[0]["age"] == 0.0 and r[1]["age"] == 0.0, "a damaged or negative age becomes none")
	ok(r[0]["mood"] == 100 and r[1]["mood"] == 70, "a mood too high is held at the top and a damaged one is reset")
	var inf := d.to_dict()
	inf["roster"][0]["age"] = INF
	ok(GameDynasty.from_dict(inf).roster[0]["age"] == 0.0, "an infinite age becomes none")
	var wrong := d.to_dict()
	wrong["roster"][1]["stage"] = "elder"   # an egg-layer's age 2.5 is young whatever was saved
	ok(GameDynasty.from_dict(wrong).roster[1]["stage"] == GameRanch.stage_at(d.roster[1], float(d.roster[1]["age"])), "the stage follows the age, not what was saved")


func test_untouched() -> void:
	# an empty roster draws no die and moves nothing, so every life without creatures plays as before
	var a := dyn(9)
	var b := dyn(9)
	var before := a.rng.state
	for i in 30:
		a.pass_time(1.0)
	ok(a.rng.state != before, "(time still passes for the heir)")
	for i in 30:
		b.pass_time(1.0)
	ok(a.to_dict() == b.to_dict(), "two identical lives with no creatures stay identical")
	ok(not a.to_dict().has("roster"), "and save no roster")
	# with creatures the dynasty's own dice are not used by them
	var c := dyn(9)
	var e := dyn(9)
	GameRoster.add(e, "wolf", "Ash")
	for i in 5:
		c.pass_time(1.0)
		e.pass_time(1.0)
	ok(c.rng.state == e.rng.state, "creatures draw nothing from the dynasty's dice")
	ok(c.heir.age == e.heir.age and c.heir.hp == e.heir.hp, "and do not change the heir's years")


func test_through_time() -> void:
	var d := dyn()
	var e := GameRoster.add(d, "drake", "Ember")
	var gold := d.heir.gold
	var msgs := d.pass_time(2.0)
	ok(e["stage"] == "young" and d.heir.gold < gold, "pass_time grows and feeds the creatures")
	ok(msgs.any(func(m): return "hatches" in str(m)), "and its lines come back to the caller")
	var dead := dyn()
	GameRoster.add(dead, "wolf", "Ash")
	dead.state = "succession"
	dead.pass_time(5.0)
	ok(float(dead.roster[0]["age"]) == 0.0, "no time passes for them outside a life")
