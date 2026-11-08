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
	test_ranch_levels()
	test_selling()
	test_work()
	test_guards()
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
	var told := msgs.filter(func(m): return "ranch earns" not in str(m))   # the drake also worked, and that is told too
	ok(e["stage"] == "elder" and told.size() == 1 and "old now" in told[0], "and is old after its adult years")
	var w := GameRoster.add(d, "wolf", "Ash")
	msgs.clear()
	GameRanch.on_years(d, 3.0, msgs)
	ok(w["stage"] == "adult" and msgs.filter(func(m): return "ranch earns" not in str(m)).size() == 1, "a live-born creature never hatches: it grows up")
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


func _build(d: GameDynasty, level: int) -> void:
	d.house[GameHouse.RANCH] = level


func test_ranch_levels() -> void:
	var d := dyn()
	ok(GameHouse.TRACKS.has(GameHouse.RANCH) and GameHouse.track_name(GameHouse.RANCH) == "Ranch", "the Ranch is a house track")
	ok(GameRoster.cap(d) == int(GameFinding.setting("roster_cap")) and GameRanch.extra_pens(d) == 0, "with nothing built there are the family's own places")
	var prev := GameRoster.cap(d)
	for lv in range(1, GameHouse.max_level() + 1):
		_build(d, lv)
		ok(GameRoster.cap(d) > prev, "each Ranch level adds pens (level %d: %d)" % [lv, GameRoster.cap(d)])
		prev = GameRoster.cap(d)
	_build(d, 99)
	ok(GameRanch.extra_pens(d) == GameRanch.extra_pens(_built(GameHouse.max_level())), "a level past the top is the top")
	# buying it through the house
	var b := dyn()
	b.heir.gold = 100000
	var price := GameHouse.cost(b, GameHouse.RANCH)
	var before := b.heir.gold
	GameHouse.buy(b, GameHouse.RANCH)
	ok(GameHouse.level(b, GameHouse.RANCH) == 1 and before - b.heir.gold == price, "the Ranch is bought with gold like the other tracks")
	ok(GameHouse.level(b, GameHouse.HALL) == 0 and GameHouse.level(b, GameHouse.YARD) == 0, "and the others are untouched")
	# a full roster takes more once the pens are built
	var f := dyn()
	for i in GameRoster.cap(f):
		GameRoster.add(f, "slime", "S%d" % i)
	ok(GameRoster.full(f) and GameRoster.add(f, "slime", "Over").is_empty(), "a full roster takes no more")
	_build(f, 1)
	ok(not GameRoster.full(f) and not GameRoster.add(f, "slime", "More").is_empty(), "but takes more when the pens are built")
	# the hatchery: eggs cost less and spoil slowly
	var plain := dyn()
	var warm := dyn()
	_build(warm, 1)
	GameRoster.add(plain, "drake", "E")
	GameRoster.add(warm, "drake", "E")
	var gp := plain.heir.gold
	var gw := warm.heir.gold
	GameRanch.on_years(plain, 1.0, [])
	GameRanch.on_years(warm, 1.0, [])
	ok(gw - warm.heir.gold < gp - plain.heir.gold, "a hatchery makes an egg cheaper to keep")
	plain.heir.gold = 0
	warm.heir.gold = 0
	GameRanch.on_years(plain, 1.0, [])
	GameRanch.on_years(warm, 1.0, [])
	ok(warm.roster[0]["mood"] > plain.roster[0]["mood"], "and an unkept egg sours more slowly")
	# the nursery: the young cost less and take neglect better
	var np := dyn()
	var nn := dyn()
	_build(nn, 2)
	GameRoster.add(np, "wolf", "Y")
	GameRoster.add(nn, "wolf", "Y")
	var g1 := np.heir.gold
	var g2 := nn.heir.gold
	GameRanch.on_years(np, 1.0, [])
	GameRanch.on_years(nn, 1.0, [])
	ok(g2 - nn.heir.gold < g1 - np.heir.gold, "a nursery makes the young cheaper to keep")
	var level1 := dyn()
	_build(level1, 1)
	GameRoster.add(level1, "wolf", "Y")
	var g3 := level1.heir.gold
	GameRanch.on_years(level1, 1.0, [])
	ok(g3 - level1.heir.gold == g1 - np.heir.gold, "a hatchery alone does not cheapen the young")
	# grown creatures have no discount at any level
	var top := dyn()
	_build(top, GameHouse.max_level())
	var adult := GameRoster.add(top, "wolf", "A")
	adult["age"] = 5.0
	adult["stage"] = "adult"
	ok(GameRanch.yearly_keep(adult, top) == GameRanch.yearly_keep(adult), "the grown cost the same at any level")
	# the key to old saves: level 0 plays as it did
	var z := dyn()
	GameRoster.add(z, "wolf", "A")
	ok(GameRanch.yearly_keep(z.roster[0], z) == GameRanch.yearly_keep(z.roster[0]), "with nothing built the keep is exactly what it was")
	# saving
	var saved := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(b.to_dict())))
	ok(GameHouse.level(saved, GameHouse.RANCH) == 1, "the Ranch level survives a save and load")
	# validation
	_with(func(x): x["ranch"]["levels"].pop_back(), func(): ok(not GameRanch.validate().is_empty(), "a missing Ranch level is found"))
	_with(func(x): x["ranch"]["levels"][2]["pens"] = 1, func(): ok(not GameRanch.validate().is_empty(), "pens that fall are found"))
	_with(func(x): x["ranch"]["levels"][1]["egg_keep"] = 2.0, func(): ok(not GameRanch.validate().is_empty(), "a factor above 1 is found"))
	_with(func(x): x["ranch"]["levels"][0]["pens"] = 2, func(): ok(not GameRanch.validate().is_empty(), "level 0 giving pens is found"))
	_with(func(x): x["sizes"]["small"].erase("value"), func(): ok(not GameRanch.validate().is_empty(), "a size with no value is found"))
	_with(func(x): x["settings"]["stage_value"].erase("egg"), func(): ok(not GameRanch.validate().is_empty(), "a stage with no value is found"))


func _built(level: int) -> GameDynasty:
	var d := dyn()
	_build(d, level)
	return d


func test_selling() -> void:
	var d := dyn()
	var wolf := GameRoster.add(d, "wolf", "Ash")   # medium, value 80, young x0.7, mood 70
	var egg := GameRoster.add(d, "drake", "Ember")   # large, value 250, egg x0.5
	ok(GameRanch.sell_price(wolf) == int(round(80.0 * 0.7 * 0.7)), "a young creature sells for its value by stage and mood: %d" % GameRanch.sell_price(wolf))
	ok(GameRanch.sell_price(egg) == int(round(250.0 * 0.5 * 0.7)), "an egg sells for less")
	wolf["mood"] = 100
	var well := GameRanch.sell_price(wolf)
	wolf["mood"] = 10
	ok(GameRanch.sell_price(wolf) < well, "a neglected creature sells for less")
	wolf["mood"] = 70
	wolf["stage"] = "adult"
	var adult := GameRanch.sell_price(wolf)
	wolf["stage"] = "elder"
	ok(GameRanch.sell_price(wolf) < adult, "an old one sells for less than a grown one")
	wolf["stage"] = "adult"
	ok(GameRanch.sell_price(wolf) >= 1 and GameRanch.sell_price({"species": "nonesuch", "stage": "adult", "mood": 1}) >= 1, "a price is never nothing")
	var gold := d.heir.gold
	var line := GameRanch.sell(d, int(wolf["id"]))
	ok(d.heir.gold == gold + adult and "sells Ash" in line and str(adult) in line, "selling pays the price and says so: %s" % line)
	ok(d.roster.size() == 1 and d.roster[0]["name"] == "Ember", "and the creature is gone")
	ok(d.journal.back() == line, "it is journalled")
	ok(GameRanch.sell(d, 999) == "" and GameRanch.release(d, 999) == "", "a creature that is not there cannot be sold or freed")
	var free := GameRanch.release(d, int(d.roster[0]["id"]))
	ok(d.roster.is_empty() and "sets Ember" in free and "free" in free and d.heir.gold == gold + adult, "setting free pays nothing and is told: %s" % free)
	var dead := dyn()
	GameRoster.add(dead, "wolf", "A")
	dead.state = "succession"
	ok(GameRanch.sell(dead, 1) == "" and GameRanch.release(dead, 1) == "" and dead.roster.size() == 1, "nothing is sold or freed outside a life")
	# freeing one leaves the others' ids alone
	var r := dyn()
	GameRoster.add(r, "wolf", "A")
	GameRoster.add(r, "wolf", "B")
	GameRanch.release(r, 1)
	ok(GameRoster.add(r, "wolf", "C")["id"] == 3, "ids keep counting up after one is freed")


## A creature of this species, grown to the stage, in this mood.
func _grown(d: GameDynasty, species: String, stage: String = "adult", mood: int = 70) -> Dictionary:
	var e := GameRoster.add(d, species, "W")
	e["stage"] = stage
	e["mood"] = mood
	var sz := GameRanch.size_of(species)
	var adult_from := GameRanch.egg_years(e) + float(sz["young"])
	e["age"] = (adult_from + GameRanch.adult_at(e)) * 0.5 if stage == "adult" else GameRanch.adult_at(e) + 0.5   # mid-adult, so a year or two keeps the stage
	return e


func test_work() -> void:
	ok(GameRanch.validate().is_empty(), "the data with work is sound: %s" % str(GameRanch.validate()))
	var d := dyn()
	var sheep := _grown(d, "sheep")   # wool 12, by the season and how it is kept
	_grown(d, "drake")                # eggs 20
	_grown(d, "ash_wyrm")             # venom 60
	var wool := 12.0 * GameFarm.yield_mult(d, sheep)
	var y := GameRanch.yearly_work(d)
	ok(is_equal_approx(float(y["gold"]), 80.0 + wool) and y["kinds"].size() == 3, "the grown earn by wool, eggs and venom: %s" % str(y))
	ok(GameRanch.kinds_text(y["kinds"]) == "eggs 20, venom 60, wool %d" % int(ceil(wool)), "told by kind: %s" % GameRanch.kinds_text(y["kinds"]))
	var young := dyn()
	_grown(young, "drake", "young")
	var egg := dyn()
	GameRoster.add(egg, "drake", "E")
	ok(float(GameRanch.yearly_work(young)["gold"]) == 0.0 and float(GameRanch.yearly_work(egg)["gold"]) == 0.0, "eggs and the young do no work")
	var old := dyn()
	_grown(old, "drake", "elder")
	ok(is_equal_approx(float(GameRanch.yearly_work(old)["gold"]), 10.0), "an old one does half")
	var sad := dyn()
	_grown(sad, "drake", "adult", 39)
	ok(float(GameRanch.yearly_work(sad)["gold"]) == 0.0, "an unhappy creature does not work")
	var happy := dyn()
	_grown(happy, "drake", "adult", 40)
	ok(float(GameRanch.yearly_work(happy)["gold"]) > 0.0, "and does at the threshold")
	var none := dyn()
	_grown(none, "slime")
	ok(float(GameRanch.yearly_work(none)["gold"]) == 0.0 and GameRanch.work_text(none.roster[0]) == "", "a species with no work earns nothing")
	# paid as the years pass, before the keep
	var p := dyn()
	_grown(p, "drake")   # eggs 20, keep 8
	var gold := p.heir.gold
	var msgs: Array = []
	GameRanch.on_years(p, 1.0, msgs)
	ok(p.heir.gold == gold + 20 - 8, "a year pays the work and the keep: %d" % (p.heir.gold - gold))
	ok(msgs.size() == 1 and "ranch earns 20 gold" in msgs[0] and "eggs 20" in msgs[0], "and tells it: %s" % str(msgs))
	ok(p.journal.back() == msgs[0], "in the journal too")
	var q := dyn()
	_grown(q, "drake")
	var g2 := q.heir.gold
	GameRanch.on_years(q, 0.5, [])
	ok(q.heir.gold == g2 + 10 - 4, "half a year pays half")
	# a working ranch keeps itself when the heir has nothing
	var poor := dyn()
	poor.heir.gold = 0
	var grown := _grown(poor, "drake")   # earns 20 against 8 keep
	GameRanch.on_years(poor, 1.0, [])
	ok(poor.heir.gold == 12 and grown["mood"] > 70, "a working ranch pays its own keep even when the heir has no gold")
	var m := dyn()
	_grown(m, "drake")
	var before := GameRanch.work_text(m.roster[0])
	ok("20 gold a year" in before, "the creature's entry says what it does: %s" % before)
	ok("Lays eggs" in GameRoster.describe(m.roster[0])["line"], "and the entry carries it")
	ok(GameRanch.work_text(GameRoster.add(dyn(), "drake", "E")) == "", "an egg's says nothing")
	# validation
	_with(func(x): x["work_of"]["drake"]["kind"] = "shearing", func(): ok(not GameRanch.validate().is_empty(), "an unknown work kind is found"))
	_with(func(x): x["work_of"]["skeleton"] = {"kind": "guard"}, func(): ok(not GameRanch.validate().is_empty(), "work for a creature that is not born is found"))
	_with(func(x): x["work_of"]["drake"]["gold"] = 0, func(): ok(not GameRanch.validate().is_empty(), "work that earns nothing is found"))
	_with(func(x): x["work"]["guard_cut_max"] = 1.0, func(): ok(not GameRanch.validate().is_empty(), "guards that stop every loss are found"))
	_with(func(x): x["work"].erase("min_mood"), func(): ok(not GameRanch.validate().is_empty(), "a missing work setting is found"))
	_with(func(x): x["work"]["kinds"]["eggs"].erase("about"), func(): ok(not GameRanch.validate().is_empty(), "a work kind with no text is found"))


func test_guards() -> void:
	var d := dyn()
	ok(GameRanch.guard_cut(d) == 0.0 and GameRanch.guarded_loss(d, 40) == 40, "with no guards a loss is whole")
	_grown(d, "wolf")
	ok(is_equal_approx(GameRanch.guard_cut(d), 0.2) and GameRanch.guarded_loss(d, 40) == 32, "a guard turns away a fifth: %d" % GameRanch.guarded_loss(d, 40))
	_grown(d, "grimfang")
	_grown(d, "ogre")
	_grown(d, "bog_troll")
	ok(is_equal_approx(GameRanch.guard_cut(d), 0.6), "guards add up to a ceiling of 60%")
	_grown(d, "elder_dragon")
	ok(is_equal_approx(GameRanch.guard_cut(d), 0.6) and GameRanch.guarded_loss(d, 40) == 16, "and no more: %d" % GameRanch.guarded_loss(d, 40))
	ok(GameRanch.guarded_loss(d, 1) == 1, "a loss rounds in the house's favour, never to nothing")
	ok(GameRanch.guarded_loss(d, 0) == 0 and GameRanch.guarded_loss(d, -5) == -5, "no loss, or a gain, is left alone")
	var young := dyn()
	_grown(young, "wolf", "young")
	var sad := dyn()
	_grown(sad, "wolf", "adult", 10)
	ok(GameRanch.guard_cut(young) == 0.0 and GameRanch.guard_cut(sad) == 0.0, "young and unhappy guards do not guard")
	var old := dyn()
	_grown(old, "wolf", "elder")
	ok(is_equal_approx(GameRanch.guard_cut(old), 0.1), "an old guard is half a guard")
	# in an event's outcome: the same gold with no guards, less with them
	var plain := dyn()
	plain.heir.gold = 500
	var fx := GameEvents._apply(plain, {}, {"gold": -40.0}, [])
	var lost := 500 - plain.heir.gold
	var guarded := dyn()
	guarded.heir.gold = 500
	_grown(guarded, "wolf")
	var fx2 := GameEvents._apply(guarded, {}, {"gold": -40.0}, [])
	var lost2 := 500 - guarded.heir.gold
	ok(lost2 < lost and lost > 0, "an event takes less gold from a house with a guard (%d against %d)" % [lost2, lost])
	ok(fx2.any(func(f): return "Guards save" in str(f["t"])), "and says the guards saved some: %s" % str(fx2))
	ok(not fx.any(func(f): return "Guards save" in str(f["t"])), "and says nothing without them")
	var gains := dyn()
	gains.heir.gold = 100
	_grown(gains, "wolf")
	GameEvents._apply(gains, {}, {"gold": 30.0}, [])
	ok(gains.heir.gold == 100 + GameEvents.gold_amount(gains, 30.0), "a gain is whole whatever the guards")
	# a house that keeps no creatures plays exactly as before
	var a := dyn(12)
	var b := dyn(12)
	a.heir.gold = 500
	b.heir.gold = 500
	GameEvents._apply(a, {}, {"gold": -40.0}, [])
	ok(a.heir.gold == 500 - GameEvents.gold_amount(a, 40.0) and a.rng.state == b.rng.state, "with no creatures the loss is the event's own and no die is drawn")
