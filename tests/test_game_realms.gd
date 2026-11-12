## Creatures of the realms (roadmap item 58, first part): the data and the ways to break it, which realm each
## creature is of, that a creature of another world sells for more at home and nothing else changes while the worlds
## are not linked (no crossing, no marks, the same saves, the same dice); and, with the worlds linked in the test,
## taking a creature to a realm, settling there, young of two worlds and their marks, unstable marks by the year,
## what marks do, and saving.
## Run: godot --headless --path . -s res://tests/test_game_realms.gd
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
	test_realm_of()
	test_reward()
	test_off()
	test_move()
	test_settling()
	test_cross()
	test_births()
	test_unstable()
	test_marks()
	test_saving()
	test_untouched()
	print("realms tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func dyn(seed_value: int = 5) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 100000
	d.house[GameHouse.RANCH] = 3
	return d


func _with(edit: Callable, body: Callable) -> void:
	var saved: Dictionary = GameRealms.data().duplicate(true)
	edit.call(GameRealms.data())
	body.call()
	GameRealms._cache = saved


func _link(x: Dictionary) -> void:
	x["settings"]["linked"] = true


func _adult(d: GameDynasty, species: String, sex: String, name: String = "") -> Dictionary:
	var e := GameRoster.add(d, species, name if name != "" else species + "_" + sex)
	e["sex"] = sex
	e["stage"] = "adult"
	e["age"] = (GameRanch.egg_years(e) + float(GameRanch.size_of(species)["young"]) + GameRanch.adult_at(e)) * 0.5
	return e


func _broken(edit: Callable) -> bool:
	var bad := [false]
	_with(edit, func(): bad[0] = not GameRealms.validate().is_empty())
	return bad[0]


func test_data() -> void:
	ok(GameRealms.validate().is_empty(), "the realm data is sound: %s" % str(GameRealms.validate()))
	ok(GameRealms.linked(), "the worlds are linked: their gates decide who crosses")
	ok(GameRealms.gate_open(dyn(), "material") and not GameRealms.gate_open(dyn(), "verdant"), "home's gate is open and the Verdant gate starts shut")
	ok(GameRealms.ids().size() == 8 and GameRealms.home() == "material", "eight realms, home the Material Realm")
	ok(_broken(func(x): x["settings"]["home"] = "nowhere"), "a home that is no realm is refused")
	ok(_broken(func(x): x["realms"]["material"]["mark"] = "glamoured"), "a home with a mark is refused")
	ok(_broken(func(x): x["realms"]["void"]["mark"] = ""), "a realm with no mark is refused")
	ok(_broken(func(x): x["realms"]["void"]["mark"] = "glamoured"), "two realms sharing a mark are refused")
	ok(_broken(func(x): x["realms"]["void"]["adapt_years"] = 0), "a realm that needs no adapting to is refused")
	ok(_broken(func(x): x["marks"]["glamoured"]["speed_mult"] = 2.0), "a mark that changes a number nothing reads is refused")
	ok(_broken(func(x): x["marks"]["glamoured"].erase("value_mult")), "a mark that does nothing is refused")
	ok(_broken(func(x): x["marks"]["lonely"] = {"name": "lonely", "about": "x", "value_mult": 2.0}), "a mark of no realm is refused")
	ok(_broken(func(x): x["of"]["unicorn"] = "verdant"), "a realm for a creature that does not exist is refused")
	ok(_broken(func(x): x["of"]["wolf"] = "material"), "listing a creature as of home is refused")
	ok(_broken(func(x): x["of"]["sheep"] = "void"), "a farm animal of another realm is refused")
	ok(_broken(func(x): x["of"]["wolf"] = "moon"), "a creature of a realm that does not exist is refused")
	ok(_broken(func(x): x["settings"]["awake_chance"] = 1.0), "an unstable mark that never changes is refused")
	ok(_broken(func(x): x["settings"]["max_marks"] = 1), "too few marks for two worlds is refused")
	ok(_broken(func(x): x["settings"]["linked"] = "yes"), "a link that is not yes or no is refused")
	ok(_broken(func(x): x["unsettled"]["speed_mult"] = 2.0), "an unsettled number nothing reads is refused")


func test_realm_of() -> void:
	ok(GameRealms.of("wolf") == "material" and GameRealms.of("sheep") == "material", "a wolf and a sheep are of home")
	ok(GameRealms.of("drake") == "dragon_isles" and GameRealms.of("void_stalker") == "void" and GameRealms.of("ghoul") == "hollow", "a drake, a void stalker and a ghoul are of their realms")
	ok(GameRealms.of("no_such_creature") == "material", "an unknown species falls back to home")
	for c in GameData.creatures:
		ok(GameRealms.has(GameRealms.of(str(c["id"]))), "%s is of a realm that exists" % c["id"])
	var d := dyn()
	var w := _adult(d, "wolf", "female")
	var k := _adult(d, "drake", "male")
	ok(not GameRealms.foreign(w) and GameRealms.foreign(k), "a kept wolf is of home, a kept drake is not")
	ok(GameRealms.describe(w) == "" and GameRealms.describe(k) == "of the Dragon Isles", "and the drake says so: %s" % GameRealms.describe(k))
	ok(GameRealms.where(k) == "material" and GameRealms.settled(k) and GameRealms.adapt_left(k) == 0.0, "a drake found at home lives there and is at ease")
	ok(not GameRealms.unstable("glamoured") and GameRealms.unstable("void_marked") and GameRealms.unstable("dream_touched"), "the Void's and the Dreaming's marks are unstable, the Court's is not")


func test_reward() -> void:
	var d := dyn()
	var k := _adult(d, "drake", "male")
	var w := _adult(d, "wolf", "male")
	var with_reward := GameRanch.sell_price(k, d)
	var wolf := GameRanch.sell_price(w, d)
	var plain := [0, 0]
	_with(func(x): x["settings"]["foreign_value_mult"] = 1.0, func():
		plain[0] = GameRanch.sell_price(k, d)
		plain[1] = GameRanch.sell_price(w, d))
	ok(plain[0] > 0 and with_reward == int(round(plain[0] * 1.2)), "a creature of another world sells for a fifth more at home: %d against %d" % [with_reward, plain[0]])
	ok(wolf == plain[1], "a creature of home sells for what it did")
	ok(GameRealms.mult(k, "keep_mult") == 1.0 and GameRealms.mult(k, "mood_loss_mult") == 1.0 and GameRealms.mult(k, "work_mult") == 1.0 and GameRealms.mult(k, "guard_mult") == 1.0 and GameRealms.mult(k, "fertility_mult") == 1.0, "and nothing else about it changes")
	for key in GameRealms.MULT_KEYS:
		ok(GameRealms.mult(w, key) == 1.0, "a creature of home has %s 1" % key)


func test_off() -> void:
	_with(func(x): x["settings"]["linked"] = false, _off_body)


func _off_body() -> void:
	var d := dyn()
	var k := _adult(d, "drake", "male")
	var got := GameRealms.move(d, int(k["id"]), "dragon_isles")
	ok(not got["ok"] and got["text"] == GameRealms.text("not_linked") and not k.has("in_realm"), "no creature crosses while the worlds are not linked")
	# a pair of two realms has young, and the young carry nothing of it
	var saved: Dictionary = GameBreeding.data().duplicate(true)
	GameBreeding.data()["settings"]["fertility"] = {"pure": 1.0, "hybrid": 1.0, "cross": 1.0}
	var m := _adult(d, "plague_rat", "female", "Mother")
	var f := _adult(d, "shard_crawler", "male", "Father")
	m["breeding"] = true
	f["breeding"] = true
	ok(GameRealms.of("plague_rat") != GameRealms.of("shard_crawler") and GameBreeding.kind("plague_rat", "shard_crawler") == "cross", "a rat and a shard crawler are kin of two realms")
	GameBreeding.on_years(d, 1.0, [], 1.0)
	GameBreeding._cache = saved
	var young: Array = d.roster.filter(func(e): return e.get("bred", false))
	ok(young.size() == 1 and not young[0].has("realms") and not young[0].has("marks"), "their young carry no realms and no marks while the worlds are not linked")
	GameRealms.on_years(d, 3.0, [], 3.0)
	ok(d.roster.all(func(e): return not e.has("adapt") and not e.has("dormant") and not e.has("settled")), "and passing years writes nothing on a roster that has crossed nothing")


func test_move() -> void:
	_with(_link, func():
		var d := dyn()
		var k := _adult(d, "drake", "male", "Ember")
		var w := _adult(d, "wolf", "male", "Grey")
		var egg := GameRoster.add(d, "drake", "Shell")
		ok(GameRealms.why_not(d, 999, "void") == GameRealms.text("no_creature"), "no such creature")
		ok(GameRealms.why_not(d, int(w["id"]), "moon") == GameRealms.text("no_realm"), "no such realm")
		ok(GameRealms.why_not(d, int(w["id"]), "material") != "", "it is already at home")
		ok(GameRealms.why_not(d, int(egg["id"]), "void") == GameRealms.text("egg"), "an egg cannot cross")
		ok(not GameRealms.move(d, int(k["id"]), "dragon_isles")["ok"], "a drake is not taken through a shut gate")
		GameRealms.open_gate(d, "dragon_isles")
		GameRealms.open_gate(d, "void")
		var a := GameRealms.move(d, int(k["id"]), "dragon_isles")
		ok(a["ok"] and k["in_realm"] == "dragon_isles" and GameRealms.settled(k) and a["text"] == "Ember is taken to the Dragon Isles.", "a drake taken to the Dragon Isles is at ease at once: %s" % a["text"])
		var b := GameRealms.move(d, int(w["id"]), "void")
		ok(b["ok"] and not GameRealms.settled(w) and GameRealms.adapt_left(w) == 5.0 and "5 years" in str(b["text"]), "a wolf taken to the Void needs five years: %s" % b["text"])
		ok(GameRealms.mult(w, "keep_mult") == 1.5 and GameRealms.mult(w, "mood_loss_mult") == 1.5 and GameRealms.mult(w, "work_mult") == 0.5 and GameRealms.mult(w, "fertility_mult") == 0.5, "unsettled, it costs more, sours faster, works and breeds less")
		ok(GameRanch.yearly_keep(w, d) > GameRanch.yearly_keep(_adult(d, "wolf", "male"), d), "and the ranch charges more for it")
		ok(GameRealms.mult(w, "value_mult") == 1.0, "a wolf abroad is still a creature of home")
		w["adapt"] = 2.0
		var c := GameRealms.move(d, int(w["id"]), "material")
		ok(c["ok"] and not w.has("in_realm") and not w.has("adapt") and GameRealms.settled(w), "brought home it is at ease, and the years spent adapting are lost")
		d.state = "battle"
		ok(GameRealms.why_not(d, int(w["id"]), "void") != "", "nothing is moved outside a life"))


func test_settling() -> void:
	_with(_link, func():
		var d := dyn()
		var w := _adult(d, "wolf", "male", "Grey")
		GameRealms.open_gate(d, "verdant")
		GameRealms.open_gate(d, "hollow")
		GameRealms.move(d, int(w["id"]), "verdant")
		var msgs: Array = []
		GameRealms.on_years(d, 1.0, msgs, 1.0)
		ok(w["adapt"] == 1.0 and GameRealms.adapt_left(w) == 1.0 and msgs.is_empty(), "a year in the Court is a year adapted")
		GameRealms.on_years(d, 1.0, msgs, 2.0)
		ok(GameRealms.settled(w) and w["settled"] == ["verdant"] and not w.has("adapt") and msgs == ["Grey has settled in the Verdant Court."], "after two it has settled: %s" % str(msgs))
		ok(GameRealms.mult(w, "keep_mult") == 1.0, "and costs what it did")
		GameRealms.move(d, int(w["id"]), "material")
		GameRealms.move(d, int(w["id"]), "verdant")
		ok(GameRealms.settled(w), "a realm once adapted to stays adapted to")
		GameRealms.move(d, int(w["id"]), "hollow")
		ok(not GameRealms.settled(w) and GameRealms.adapt_left(w) == 4.0, "another realm must be adapted to afresh")
		# through the world clock
		d.pass_time(4.0)
		ok("hollow" in w.get("settled", []), "pass_time reaches adapting through the ranch"))
	var x := dyn(11)
	var y := dyn(11)
	var yw := _adult(y, "wolf", "male", "Grey")
	_adult(x, "wolf", "male", "Grey")
	_with(_link, func():
		GameRealms.open_gate(y, "hollow")
		GameRealms.move(y, int(yw["id"]), "hollow")
		for i in 6:
			x.pass_time(1.0)
			y.pass_time(1.0))
	ok(x.rng.state == y.rng.state, "adapting draws nothing from the dynasty's dice")


func test_cross() -> void:
	var d := dyn()
	var rat := _adult(d, "plague_rat", "female")
	var shard := _adult(d, "shard_crawler", "male")
	var rat2 := _adult(d, "plague_rat", "male")
	var a := GameRealms.cross(rat, shard)
	ok(a["realms"] == ["material", "void"] and a["marks"] == ["void_marked"], "a rat and a shard crawler: both worlds, the Void's mark (home has none): %s" % str(a))
	ok(GameRealms.cross(shard, rat)["realms"] == ["void", "material"], "the mother's world comes first")
	var b := GameRealms.cross(rat, rat2)
	ok(b["realms"].is_empty() and b["marks"].is_empty(), "two of one world: nothing")
	var half := {"species": "plague_rat", "realms": ["material", "void"], "marks": ["void_marked"]}
	var c := GameRealms.cross(half, rat2)
	ok(c["realms"] == ["material", "void"] and c["marks"] == ["void_marked"], "a half-Void mother passes both worlds and her mark on")
	var drake := {"species": "drake"}
	half["marks"] = ["void_marked", "glamoured"]
	var e := GameRealms.cross(half, drake)
	ok(e["realms"].size() == 2 and e["marks"].size() == 2, "never more than two worlds or two marks: %s" % str(e))
	var marked := {"species": "plague_rat", "marks": ["glamoured"]}
	ok(GameRealms.cross(marked, rat2)["marks"] == ["glamoured"], "a parent's mark passes on within one world")
	ok(GameRealms.cross(rat, shard) == GameRealms.cross(rat, shard), "the same pair, the same young")


func test_births() -> void:
	var saved: Dictionary = GameBreeding.data().duplicate(true)
	GameBreeding.data()["settings"]["fertility"] = {"pure": 1.0, "hybrid": 1.0, "cross": 1.0}
	_with(_link, func():
		var d := dyn()
		GameRealms.open_gate(d, "void")
		var m := _adult(d, "plague_rat", "female", "Mother")
		var f := _adult(d, "shard_crawler", "male", "Father")
		m["breeding"] = true
		f["breeding"] = true
		var before := d.rng.state
		var msgs: Array = []
		GameBreeding.on_years(d, 1.0, msgs, 1.0)
		var young: Array = d.roster.filter(func(e): return e.get("bred", false))
		ok(young.size() == 1 and young[0]["realms"] == ["material", "void"] and young[0]["marks"] == ["void_marked"], "linked, their young carry both worlds and the Void's mark: %s" % str(young))
		ok(msgs.any(func(l): return "carries two worlds: void-marked" in str(l)), "and it is told: %s" % str(msgs))
		ok(d.rng.state == before, "with nothing drawn from the dynasty's dice")
		ok(GameRealms.foreign(young[0]) and GameRealms.describe(young[0]) == "of the Material Realm and the Void", "the young is of two worlds: %s" % GameRealms.describe(young[0]))
		ok(GameRealms.settled(young[0]), "and at ease at home, where it was born")
		var p := dyn()
		var pm := _adult(p, "wolf", "female")
		var pf := _adult(p, "wolf", "male")
		pm["breeding"] = true
		pf["breeding"] = true
		GameBreeding.on_years(p, 1.0, [], 1.0)
		var pups: Array = p.roster.filter(func(e): return e.get("bred", false))
		ok(pups.size() == 1 and not pups[0].has("realms") and not pups[0].has("marks"), "wolves of home have plain young, linked or not"))
	GameBreeding._cache = saved


func test_unstable() -> void:
	var awake := 0
	for y in 400:
		if GameRealms.awake_in(7, y, 3, "void_marked"):
			awake += 1
	ok(awake > 200 and awake < 280, "an unstable mark is awake about six years in ten: %d of 400" % awake)
	ok(GameRealms.awake_in(7, 12, 3, "void_marked") == GameRealms.awake_in(7, 12, 3, "void_marked"), "the same year, the same answer")
	var differs := false
	for y in 40:
		if GameRealms.awake_in(7, y, 3, "void_marked") != GameRealms.awake_in(8, y, 3, "void_marked"):
			differs = true
	ok(differs, "another seed, another run of years")
	var d := dyn(7)
	var e := _adult(d, "plague_rat", "female", "Flicker")
	e["marks"] = ["void_marked", "glamoured"]
	var before := d.rng.state
	var woke := 0
	var slept := 0
	for y in 60:
		var msgs: Array = []
		GameRealms.on_years(d, 1.0, msgs, float(y))
		var is_awake: bool = "void_marked" not in e.get("dormant", [])
		ok(is_awake == GameRealms.awake_in(7, y, int(e["id"]), "void_marked"), "year %d: the mark is as the year says" % y)
		for l in msgs:
			if "stirs" in str(l):
				woke += 1
			if "goes quiet" in str(l):
				slept += 1
		if not is_awake:
			ok(GameRealms.mult(e, "value_mult") == 1.3 and GameRealms.mult(e, "mood_loss_mult") == 1.0, "year %d: dormant, only the stable mark counts" % y)
	ok(woke > 3 and slept > 3 and absi(woke - slept) <= 1, "it wakes and sleeps, and each change is told once: %d and %d" % [woke, slept])
	ok("glamoured" not in e.get("dormant", []), "a stable mark never sleeps")
	ok(d.rng.state == before, "and none of it draws the dynasty's dice")


func test_marks() -> void:
	var d := dyn()
	var e := _adult(d, "wolf", "male")
	var base_price := GameRanch.sell_price(e, d)
	var base_keep := GameRanch.yearly_keep(e, d)
	e["marks"] = ["glamoured"]
	ok(GameRanch.sell_price(e, d) == int(round(base_price * 1.3)), "glamoured sells for more")
	e["marks"] = ["geared"]
	ok(is_equal_approx(GameRanch.yearly_keep(e, d), base_keep * 0.8), "geared costs less to keep")
	e["marks"] = ["sky_born"]
	ok(GameBreeding.trait_mult(e, "guard_mult") == 1.3, "sky-born guards better")
	e["marks"] = ["ember_hearted"]
	ok(GameBreeding.trait_mult(e, "work_mult") == 1.2, "ember-hearted works harder")
	e["marks"] = ["grave_cold"]
	ok(GameBreeding.trait_mult(e, "mood_loss_mult") == 0.7, "grave-cold minds neglect less")
	e["marks"] = ["dream_touched"]
	ok(GameBreeding.trait_mult(e, "fertility_mult") == 1.4, "dream-touched has young more often")
	e["traits"] = ["fruitful"]
	ok(is_equal_approx(GameBreeding.trait_mult(e, "fertility_mult"), 1.4 * 1.4), "a mark multiplies with a trait")
	e["dormant"] = ["dream_touched"]
	ok(is_equal_approx(GameBreeding.trait_mult(e, "fertility_mult"), 1.4), "and a dormant one does not")
	for m in GameRealms.data()["marks"]:
		var one := {"species": "wolf", "marks": [m]}
		var any := false
		for key in GameRealms.MULT_KEYS:
			if GameRealms.mult(one, key) != 1.0:
				any = true
		ok(any, "the mark %s does something" % m)


func test_saving() -> void:
	var d := dyn()
	var a := _adult(d, "plague_rat", "female", "A")
	var b := _adult(d, "wolf", "male", "B")
	var c := _adult(d, "drake", "male", "C")
	a["realms"] = ["material", "void"]
	a["marks"] = ["void_marked", "glamoured"]
	a["dormant"] = ["void_marked"]
	b["in_realm"] = "hollow"
	b["adapt"] = 1.5
	b["settled"] = ["verdant"]
	c["in_realm"] = "dragon_isles"
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(back.roster == d.roster, "realms, marks, dormancy, where it lives and how far it has adapted survive a save and load")
	var plain := dyn()
	_adult(plain, "drake", "male")
	var saved: Dictionary = plain.to_dict()
	for k in ["realms", "marks", "dormant", "in_realm", "adapt", "settled"]:
		ok(not saved["roster"][0].has(k), "a creature that has crossed nothing saves no '%s'" % k)
	var bad: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	bad["roster"][0]["realms"] = ["void", "void"]
	bad["roster"][0]["marks"] = ["nonesuch", 4, "glamoured", "glamoured", "void_marked", "sky_born"]
	bad["roster"][0]["dormant"] = ["glamoured", "void_marked", "geared", 9]
	bad["roster"][1]["in_realm"] = "moon"
	bad["roster"][1]["adapt"] = "long"
	bad["roster"][1]["settled"] = ["material", "verdant", "verdant", "moon", 3]
	bad["roster"][2]["in_realm"] = 7
	bad["roster"][2]["adapt"] = 2.0
	var r := GameDynasty.from_dict(bad).roster
	ok(not r[0].has("realms"), "two realms that are one are dropped")
	ok(r[0]["marks"] == ["glamoured", "void_marked"], "unknown, repeated and surplus marks are dropped: %s" % str(r[0]["marks"]))
	ok(r[0]["dormant"] == ["void_marked"], "only an unstable mark it holds can be dormant: %s" % str(r[0].get("dormant")))
	ok(not r[1].has("in_realm") and not r[1].has("adapt"), "a realm that does not exist is home, with nothing to adapt to")
	ok(r[1]["settled"] == ["verdant"], "settled keeps known realms once, and never home: %s" % str(r[1]["settled"]))
	ok(not r[2].has("in_realm") and not r[2].has("adapt"), "a realm that is not text is home")
	var more: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	more["roster"][2]["adapt"] = 3.0   # a drake in the Dragon Isles has nothing to adapt to
	more["roster"][1]["adapt"] = -2
	more["roster"][0]["marks"] = "all of them"
	more["roster"][0]["realms"] = "both"
	var r2 := GameDynasty.from_dict(more).roster
	ok(not r2[2].has("adapt") and r2[2]["in_realm"] == "dragon_isles", "years adapting are dropped where it is already at ease")
	ok(not r2[1].has("adapt") and r2[1]["in_realm"] == "hollow", "negative years adapting are dropped")
	ok(not r2[0].has("marks") and not r2[0].has("dormant") and not r2[0].has("realms"), "marks and realms that are no list are dropped")


func test_untouched() -> void:
	# the autopilot keeps no creature and meets none of this
	var a := GameDynasty.new_game(31, "Auto", "warrior", "noble", "human")
	for i in 400:
		if a.state == "dead" or a.gen > 2:
			break
		GameBot.step(a)
	ok(a.roster.is_empty(), "an autopilot life keeps no creature, so no realm rule is ever asked")
	# a ranch at home: years pass exactly as before, whatever realm its creatures are of
	var x := dyn(4)
	var y := dyn(4)
	for dd in [x, y]:
		_adult(dd, "drake", "male")
		_adult(dd, "void_stalker", "female")
	_with(func(v): v["of"] = {}, func():
		for i in 6:
			x.pass_time(1.0))
	for i in 6:
		y.pass_time(1.0)
	ok(x.to_dict() == y.to_dict() and x.rng.state == y.rng.state, "a ranch of creatures of other worlds lives its years exactly as one where every creature is of home")
