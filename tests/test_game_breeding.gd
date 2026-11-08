## Breeding at the ranch (roadmap item 57, first part): who may pair (one species, kin of a family, a recipe), the
## pairs the roster makes, how often they have young, what the young are (species, birth, line, cross-breed lines,
## traits passed and mutated, sterility), that every roll is keyed and draws nothing from the dynasty's dice, what the
## traits do, and saving. A ranch that breeds nothing is exactly what it was.
## Run: godot --headless --path . -s res://tests/test_game_breeding.gd
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
	test_compatible()
	test_able_and_pairs()
	test_fertility()
	test_births()
	test_young()
	test_cross()
	test_traits()
	test_hybrid()
	test_untouched()
	test_saving()
	test_effects()
	test_set()
	print("%d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func dyn(seed_value: int = 5) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 100000
	d.house[GameHouse.RANCH] = 3   # pens enough for the tests' many creatures
	return d


func _with(edit: Callable, body: Callable) -> void:
	var saved: Dictionary = GameBreeding.data().duplicate(true)
	edit.call(GameBreeding.data())
	body.call()
	GameBreeding._cache = saved


## Makes breeding certain, so a pair always has young.
func _sure(x: Dictionary) -> void:
	x["settings"]["fertility"] = {"pure": 1.0, "hybrid": 1.0, "cross": 1.0}


## A grown creature of a sex, set to breed.
func _adult(d: GameDynasty, species: String, sex: String, name: String = "") -> Dictionary:
	var e := GameRoster.add(d, species, name if name != "" else species + "_" + sex)
	e["sex"] = sex
	e["stage"] = "adult"
	e["age"] = (GameRanch.egg_years(e) + float(GameRanch.size_of(species)["young"]) + GameRanch.adult_at(e)) * 0.5
	e["breeding"] = true
	return e


func test_data() -> void:
	ok(GameBreeding.validate().is_empty(), "breeding_rules.json is sound: %s" % str(GameBreeding.validate()))
	_with(func(x): x["settings"]["fertility"]["cross"] = 2.0, func(): ok(not GameBreeding.validate().is_empty(), "a fertility above 1 is found"))
	_with(func(x): x["settings"]["mutation_chance"] = -0.1, func(): ok(not GameBreeding.validate().is_empty(), "a negative chance is found"))
	_with(func(x): x["settings"]["min_stage"] = "grown", func(): ok(not GameBreeding.validate().is_empty(), "an unknown stage is found"))
	_with(func(x): x["settings"]["max_traits"] = 0, func(): ok(not GameBreeding.validate().is_empty(), "no room for traits is found"))
	_with(func(x): x["families"]["canine"].append("skeleton"), func(): ok(not GameBreeding.validate().is_empty(), "a family naming a creature that is not born is found"))
	_with(func(x): x["families"]["giant"].append("wolf"), func(): ok(not GameBreeding.validate().is_empty(), "a species in two families is found"))
	_with(func(x): x["traits"]["hardy"]["mood_loss_mult"] = 0.0, func(): ok(not GameBreeding.validate().is_empty(), "a trait effect of zero is found"))
	_with(func(x): x["traits"]["hardy"]["telepathy"] = 2.0, func(): ok(not GameBreeding.validate().is_empty(), "an unknown trait effect is found"))
	_with(func(x): x["text"].erase("bred"), func(): ok(not GameBreeding.validate().is_empty(), "missing text is found"))
	_with(func(x): x["settings"]["cooldown"].erase("egg"), func(): ok(not GameBreeding.validate().is_empty(), "a missing cooldown is found"))
	ok(GameBreeding.validate().is_empty(), "the data is put back")
	var in_family := 0
	for c in GameData.creatures:
		if GameBirth.born(str(c["id"])) != "none" and GameBreeding.family_of(str(c["id"])) != "":
			in_family += 1
	var born := GameData.creatures.filter(func(c): return GameBirth.born(str(c["id"])) != "none").size()
	ok(in_family == born and born == 19, "every born creature is in a family (%d of %d)" % [in_family, born])


func test_compatible() -> void:
	ok(GameBreeding.kind("wolf", "wolf") == "pure" and GameBreeding.compatible("wolf", "wolf"), "one species breeds true")
	ok(GameBreeding.kind("wolf", "frost_wolf") == "cross", "kin of one family make a cross-breed")
	ok(GameBreeding.kind("drake", "ash_wyrm") == "cross", "the draconic kin cross")
	ok(GameBreeding.kind("wolf", "drake") == "" and not GameBreeding.compatible("wolf", "drake"), "creatures of different families cannot")
	ok(GameBreeding.kind("skeleton", "skeleton") == "" and GameBreeding.kind("wolf", "skeleton") == "", "the unborn cannot")
	ok(GameBreeding.compatible("frost_wolf", "wolf") == GameBreeding.compatible("wolf", "frost_wolf"), "either way round")
	var cross := 0
	var all := 0
	for a in GameData.creatures:
		for b in GameData.creatures:
			if GameBreeding.compatible(str(a["id"]), str(b["id"])):
				all += 1
				if str(a["id"]) != str(b["id"]):
					cross += 1
	ok(all > 15 and cross > 0 and cross < 112, "only kin cross: %d pairings, %d of them cross-breeds (not the 112 of any two)" % [all, cross])
	ok(GameBreeding.family_of("harpy") == "winged" and GameBreeding.family_of("skeleton") == "", "a family, or none")


func test_able_and_pairs() -> void:
	var d := dyn()
	var f := _adult(d, "wolf", "female", "Mother")
	var m := _adult(d, "wolf", "male", "Father")
	ok(GameBreeding.able(f) and GameBreeding.able(m), "a grown, content, rested creature set to breed is able")
	var p := GameBreeding.pairs(d)
	ok(p.size() == 1 and p[0][0]["name"] == "Mother" and p[0][1]["name"] == "Father", "they make a pair, the mother first")
	f["breeding"] = false
	ok(not GameBreeding.able(f) and GameBreeding.pairs(d).is_empty(), "not set to breed, not able")
	f["breeding"] = true
	for stage in ["egg", "young", "elder"]:
		var s: String = f["stage"]
		f["stage"] = stage
		ok(not GameBreeding.able(f), "a%s %s is not able" % ["n" if stage in ["egg", "elder"] else "", stage])
		f["stage"] = s
	f["mood"] = 49
	ok(not GameBreeding.able(f), "an unhappy creature is not able")
	f["mood"] = 50
	ok(GameBreeding.able(f), "and is at the threshold")
	f["cooldown"] = 1.0
	ok(not GameBreeding.able(f), "one still resting is not able")
	f["cooldown"] = 0.0
	f["sterile"] = true
	ok(not GameBreeding.able(f), "a sterile one is not able")
	f["sterile"] = false
	# two of one sex, and strangers, make no pair
	var d2 := dyn()
	_adult(d2, "wolf", "female")
	_adult(d2, "wolf", "female")
	ok(GameBreeding.pairs(d2).is_empty(), "two of one sex make no pair")
	var d3 := dyn()
	_adult(d3, "wolf", "female")
	_adult(d3, "drake", "male")
	ok(GameBreeding.pairs(d3).is_empty(), "creatures of different families make no pair")
	# each creature in at most one pair, in id order
	var d4 := dyn()
	var a := _adult(d4, "wolf", "female", "A")
	var b := _adult(d4, "wolf", "female", "B")
	var c := _adult(d4, "wolf", "male", "C")
	var e := _adult(d4, "wolf", "male", "D")
	var ps := GameBreeding.pairs(d4)
	ok(ps.size() == 2 and ps[0][0]["name"] == "A" and ps[0][1]["name"] == "C" and ps[1][0]["name"] == "B" and ps[1][1]["name"] == "D", "four make two pairs, first with first: %s" % str(ps.map(func(x): return x[0]["name"] + x[1]["name"])))
	var d5 := dyn()
	_adult(d5, "wolf", "female")
	_adult(d5, "frost_wolf", "male")
	ok(GameBreeding.pairs(d5).size() == 1, "kin pair")


func test_fertility() -> void:
	var d := dyn()
	var pure := GameBreeding.fertility(_adult(d, "wolf", "female"), _adult(d, "wolf", "male"))
	var cross := GameBreeding.fertility(_adult(d, "wolf", "female"), _adult(d, "frost_wolf", "male"))
	ok(is_equal_approx(pure, 0.45) and is_equal_approx(cross, 0.2), "pure pairs are more fertile than cross-breeds: %s and %s" % [pure, cross])
	ok(GameBreeding.fertility(_adult(d, "wolf", "female"), _adult(d, "drake", "male")) == 0.0, "strangers are not fertile")
	var f := _adult(d, "wolf", "female")
	f["traits"] = ["fruitful"]
	ok(GameBreeding.fertility(f, _adult(d, "wolf", "male")) > pure, "a fruitful parent raises it")
	var g := _adult(d, "wolf", "female")
	var h := _adult(d, "wolf", "male")
	g["traits"] = ["fruitful"]
	h["traits"] = ["fruitful"]
	_with(func(x): x["settings"]["fertility"]["pure"] = 0.9, func(): ok(GameBreeding.fertility(g, h) == 1.0, "and never above 1"))


func test_births() -> void:
	_with(_sure, func():
		var d := dyn()
		_adult(d, "wolf", "female", "Mother")
		_adult(d, "wolf", "male", "Father")
		var msgs: Array = []
		GameBreeding.on_years(d, 1.0, msgs, 1.0)
		ok(d.roster.size() == 3 and msgs.size() >= 1 and "Mother bears a pup" in msgs[0], "a pair with certain fertility has young: %s" % str(msgs))
		ok(d.journal.has(msgs[0]), "and it is journalled")
		var pup: Dictionary = d.roster[2]
		ok(pup["species"] == "wolf" and pup["stage"] == "young" and pup["born"] == "live" and pup["age"] == 0.0, "a wolf's young is a live pup")
		ok(pup["bred"] == true and pup["parents"] == ["Mother", "Father"], "who bore it is kept")
		ok(pup["line"] == "Mother" and not pup.has("lines"), "the line is the mother's name, and it is no cross")
		ok(not pup["breeding"] and not pup["sterile"], "and it does not breed until it is grown and set to")
		var mother: Dictionary = d.roster[0]
		ok(float(mother["cooldown"]) == 3.0, "the mother rests for three years after a live birth")
		var again: Array = []
		GameBreeding.on_years(d, 1.0, again, 2.0)
		ok(d.roster.size() == 3, "and has no more young while she rests")
		GameBreeding.on_years(d, 3.0, again, 5.0)   # cooldown runs out; a year ended
		ok(d.roster.size() == 4, "but does after")
		# eggs
		var e := dyn()
		_adult(e, "drake", "female", "Ember")
		_adult(e, "drake", "male", "Cinder")
		var em: Array = []
		GameBreeding.on_years(e, 1.0, em, 1.0)
		ok(e.roster.size() == 3 and e.roster[2]["stage"] == "egg" and e.roster[2]["born"] == "egg" and "lays a clutch" in em[0], "a drake lays an egg of hatchlings: %s" % str(em))
		ok(float(e.roster[0]["cooldown"]) == 2.0, "and rests two years")
		# no whole year passes: no roll
		var n := dyn()
		_adult(n, "wolf", "female")
		_adult(n, "wolf", "male")
		GameBreeding.on_years(n, 0.4, [], 0.4)
		ok(n.roster.size() == 2, "no year ended, no young")
		GameBreeding.on_years(n, 0.4, [], 1.2)
		ok(n.roster.size() == 3, "the year ending is the roll")
		var q := dyn()
		_adult(q, "wolf", "female")
		_adult(q, "wolf", "male")
		GameBreeding.on_years(q, 3.0, [], 3.0)
		ok(q.roster.size() == 3, "three years at once roll for each year, but the mother then rests")
		# a full roster takes no young
		var full := dyn()
		_adult(full, "wolf", "female")
		_adult(full, "wolf", "male")
		for i in GameRoster.cap(full) - 2:
			GameRoster.add(full, "slime", "S%d" % i)
		GameBreeding.on_years(full, 1.0, [], 1.0)
		ok(full.roster.size() == GameRoster.cap(full), "a full ranch has no room for young")
		# not set to breed
		var off := dyn()
		var fe := _adult(off, "wolf", "female")
		_adult(off, "wolf", "male")
		fe["breeding"] = false
		GameBreeding.on_years(off, 1.0, [], 1.0)
		ok(off.roster.size() == 2, "a creature not set to breed does not"))
	# the rate matches the fertility
	var born := 0
	for s in range(1, 1201):
		var d := dyn(s)
		_adult(d, "wolf", "female")
		_adult(d, "wolf", "male")
		GameBreeding.on_years(d, 1.0, [], 1.0)
		if d.roster.size() == 3:
			born += 1
	var rate := float(born) / 1200.0
	ok(absf(rate - 0.45) < 0.05, "the birth rate over 1,200 seeds matches the fertility (%.3f)" % rate)
	# the same seed and year always give the same young
	var same := true
	for s in range(1, 40):
		var a := dyn(s)
		var b := dyn(s)
		for dd in [a, b]:
			_adult(dd, "wolf", "female", "M")
			_adult(dd, "wolf", "male", "F")
			GameBreeding.on_years(dd, 1.0, [], 1.0)
		same = same and a.roster == b.roster
	ok(same, "the same seed and year give the same young")


func test_young() -> void:
	_with(func(x): _sure(x); x["settings"]["mutation_chance"] = 0.0; x["settings"]["trait_pass_chance"] = 1.0, func():
		var d := dyn()
		var f := _adult(d, "wolf", "female", "Mother")
		var m := _adult(d, "wolf", "male", "Father")
		f["traits"] = ["hardy"]
		m["traits"] = ["fierce", "prized"]
		GameBreeding.on_years(d, 1.0, [], 1.0)
		var y: Dictionary = d.roster[2]
		ok(y["traits"].size() == 3 and "hardy" in y["traits"] and "fierce" in y["traits"] and "prized" in y["traits"], "with every trait passed, the young have all of theirs: %s" % str(y["traits"]))
		var d2 := dyn()
		var f2 := _adult(d2, "wolf", "female", "Mother")
		var m2 := _adult(d2, "wolf", "male", "Father")
		f2["traits"] = ["hardy", "fierce", "prized"]
		m2["traits"] = ["industrious", "fruitful"]
		GameBreeding.on_years(d2, 1.0, [], 1.0)
		ok(d2.roster[2]["traits"].size() == 3, "never more than three: %s" % str(d2.roster[2]["traits"]))
		var d3 := dyn()
		var f3 := _adult(d3, "wolf", "female", "Mother")
		f3["line"] = "Old Ash"
		_adult(d3, "wolf", "male", "Father")
		GameBreeding.on_years(d3, 1.0, [], 1.0)
		ok(d3.roster[2]["line"] == "Old Ash", "a line is kept down the generations"))
	_with(func(x): _sure(x); x["settings"]["mutation_chance"] = 0.0; x["settings"]["trait_pass_chance"] = 0.0, func():
		var d := dyn()
		var f := _adult(d, "wolf", "female")
		f["traits"] = ["hardy"]
		_adult(d, "wolf", "male")
		GameBreeding.on_years(d, 1.0, [], 1.0)
		ok(d.roster[2]["traits"].is_empty(), "with none passed and no mutation, the young have none"))
	_with(func(x): _sure(x); x["settings"]["mutation_chance"] = 1.0; x["settings"]["trait_pass_chance"] = 0.0, func():
		var d := dyn()
		_adult(d, "wolf", "female")
		_adult(d, "wolf", "male")
		var msgs: Array = []
		GameBreeding.on_years(d, 1.0, msgs, 1.0)
		ok(d.roster[2]["traits"].size() == 1 and msgs.any(func(m): return "is born" in str(m)), "a certain mutation gives a trait neither parent had, and says so: %s" % str(msgs)))
	_with(func(x): _sure(x); x["settings"]["sterile_chance"]["pure"] = 1.0, func():
		var d := dyn()
		_adult(d, "wolf", "female")
		_adult(d, "wolf", "male")
		var msgs: Array = []
		GameBreeding.on_years(d, 1.0, msgs, 1.0)
		ok(d.roster[2]["sterile"] == true and msgs.any(func(m): return "never have young" in str(m)), "sterile young are said to be")
		d.roster[2]["stage"] = "adult"
		ok(not GameBreeding.able(d.roster[2]) and not GameBreeding.can_set(d.roster[2]), "and cannot breed"))


func test_cross() -> void:
	_with(func(x): _sure(x); x["settings"]["sterile_chance"]["cross"] = 0.0, func():
		var d := dyn()
		_adult(d, "wolf", "female", "Wolfmother")
		_adult(d, "frost_wolf", "male", "Frostfather")
		var msgs: Array = []
		GameBreeding.on_years(d, 1.0, msgs, 1.0)
		var y: Dictionary = d.roster[2]
		ok(y["species"] == "wolf" and y["lines"] == ["wolf", "frost_wolf"], "a cross-breed takes the mother's species and carries both lines")
		ok(y["born"] == "live" and y["stage"] == "young", "and is born as the mother is")
		var other := dyn()
		_adult(other, "frost_wolf", "female", "Frostmother")
		_adult(other, "wolf", "male", "Wolffather")
		GameBreeding.on_years(other, 1.0, [], 1.0)
		ok(other.roster[2]["species"] == "frost_wolf" and other.roster[2]["lines"] == ["frost_wolf", "wolf"], "with the mother the other way round, the other way round")
		var line: String = GameRoster.describe(y)["line"]
		ok("A cross of the dire wolf and the frost wolf." in line, "its entry says what it is a cross of: %s" % line)
		ok("Born at the ranch in generation 1, to Wolfmother and Frostfather." in line, "and who bore it")
		# a draconic cross: mother egg, father egg
		var dr := dyn()
		_adult(dr, "drake", "female")
		_adult(dr, "ash_wyrm", "male")
		GameBreeding.on_years(dr, 1.0, [], 1.0)
		ok(dr.roster[2]["lines"] == ["drake", "ash_wyrm"] and dr.roster[2]["stage"] == "egg", "a draconic cross is an egg"))
	_with(func(x): _sure(x); x["settings"]["sterile_chance"]["cross"] = 1.0, func():
		var d := dyn()
		_adult(d, "wolf", "female")
		_adult(d, "frost_wolf", "male")
		GameBreeding.on_years(d, 1.0, [], 1.0)
		ok(d.roster[2]["sterile"] == true, "a cross-breed can be sterile"))
	# the birth rule still decides: a drake mother and a wolf father cannot pair (families), so use the rule on a cross of eggs
	_with(func(x): _sure(x), func():
		var d := dyn()
		_adult(d, "wolf", "female")
		_adult(d, "frost_wolf", "male")
		GameBreeding.on_years(d, 1.0, [], 1.0)
		ok(d.roster[2]["born"] == GameBirth.mode("wolf", "frost_wolf"), "the young are born as GameBirth says"))


func test_traits() -> void:
	var d := dyn()
	var e := _adult(d, "wolf", "female")
	ok(GameBreeding.trait_mult(e, "value_mult") == 1.0, "no traits, no change")
	e["traits"] = ["prized", "sickly"]
	ok(is_equal_approx(GameBreeding.trait_mult(e, "value_mult"), 1.5 * 0.7), "traits multiply: %s" % GameBreeding.trait_mult(e, "value_mult"))
	ok(GameBreeding.trait_mult(e, "work_mult") == 1.0 and GameBreeding.trait_mult(e, "nonesuch") == 1.0, "and only the effects they name")
	ok(GameBreeding.trait_mult({"traits": ["nonesuch"]}, "value_mult") == 1.0, "an unknown trait does nothing")


func test_hybrid() -> void:
	var saved: Array = GameData.breeding["recipes"].duplicate(true)
	GameData.breeding["recipes"] = [{"id": "test_hound", "name": "Test hound", "parents": ["wolf", "drake"], "born": "egg", "young": "hatchling", "species": "plague_rat"}]
	_with(_sure, func():
		ok(GameBreeding.kind("wolf", "drake") == "hybrid" and GameBreeding.compatible("drake", "wolf"), "a recipe makes unlike creatures compatible, either way round")
		var d := dyn()
		_adult(d, "wolf", "female", "Wolfmother")
		_adult(d, "drake", "male", "Drakefather")
		var msgs: Array = []
		GameBreeding.on_years(d, 1.0, msgs, 1.0)
		var y: Dictionary = d.roster[2]
		ok(y["species"] == "plague_rat" and y["born"] == "egg" and y["stage"] == "egg" and y["young"] == "hatchling", "a hybrid is the recipe's species, born as it says: %s" % str(y))
		ok(not y.has("lines"), "it is no cross-breed"))
	_with(func(x): _sure(x); x["settings"]["sterile_chance"]["hybrid"] = 1.0, func():
		var d := dyn()
		_adult(d, "wolf", "female")
		_adult(d, "drake", "male")
		GameBreeding.on_years(d, 1.0, [], 1.0)
		ok(d.roster[2]["sterile"] == true, "a hybrid can be sterile"))
	GameData.breeding["recipes"] = [{"id": "bad", "name": "Bad", "parents": ["wolf", "drake"], "born": "egg", "young": "x", "species": "skeleton"}]
	ok(not GameBreeding.validate().is_empty(), "a recipe making a creature that is not born is found")
	GameData.breeding["recipes"] = saved
	ok(GameBreeding.validate().is_empty(), "the recipes are put back")


func test_untouched() -> void:
	# a roster that breeds nothing: no change, no die, no births, whatever passes
	var a := dyn(9)
	var b := dyn(9)
	for dd in [a, b]:
		_adult(dd, "wolf", "female")["breeding"] = false
		_adult(dd, "wolf", "male")["breeding"] = false
	for i in 20:
		a.pass_time(1.0)
	for i in 20:
		b.pass_time(1.0)
	ok(a.roster.size() == b.roster.size() and a.to_dict() == b.to_dict(), "two ranches that breed nothing stay identical")
	ok(a.roster.all(func(e): return not e.get("bred", false)), "and nothing was born (the wolves may have grown old and died in the twenty years)")
	# breeding draws nothing from the dynasty's dice
	var c := dyn(9)
	var e := dyn(9)
	_adult(e, "wolf", "female")
	_adult(e, "wolf", "male")
	for i in 5:
		c.pass_time(1.0)
		e.pass_time(1.0)
	ok(c.rng.state == e.rng.state, "breeding draws nothing from the dynasty's dice")
	var s := dyn(9)
	_adult(s, "wolf", "female")
	_adult(s, "wolf", "male")
	var before := s.rng.state
	_with(_sure, func(): GameBreeding.on_years(s, 1.0, [], 1.0))
	ok(s.rng.state == before, "not even when there are young")
	# an empty roster does nothing
	var z := dyn()
	GameBreeding.on_years(z, 5.0, [], 5.0)
	ok(z.roster.is_empty(), "an empty roster does nothing")
	# through the world clock: pass_time reaches breeding
	var w := dyn(3)
	_adult(w, "wolf", "female")
	_adult(w, "wolf", "male")
	_with(_sure, func():
		for i in 4:
			w.pass_time(1.0))
	ok(w.roster.size() > 2, "pass_time reaches breeding through the ranch")


func test_saving() -> void:
	_with(func(x): _sure(x); x["settings"]["sterile_chance"]["cross"] = 0.0; x["settings"]["mutation_chance"] = 1.0, func():
		var d := dyn()
		_adult(d, "wolf", "female", "Mother")
		_adult(d, "frost_wolf", "male", "Father")
		GameBreeding.on_years(d, 1.0, [], 1.0)
		var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
		ok(back.roster == d.roster, "breeding, traits, lines, cooldowns and who bore whom survive a save and load")
		var old := d.to_dict()
		for e in old["roster"]:
			for k in ["traits", "breeding", "cooldown", "sterile", "bred", "parents", "line", "lines"]:
				e.erase(k)
		var o := GameDynasty.from_dict(old).roster
		ok(o.size() == 3 and not o[0]["breeding"] and o[0]["traits"] == [] and o[0]["cooldown"] == 0.0 and not o[0]["sterile"], "a roster saved before breeding loads with none of it")
		var bad := d.to_dict()
		bad["roster"][0]["traits"] = ["nonesuch", 5, "hardy", "hardy", "fierce", "prized", "sickly"]
		bad["roster"][0]["cooldown"] = "soon"
		bad["roster"][0]["breeding"] = "yes"
		bad["roster"][0]["sterile"] = 1
		bad["roster"][1]["cooldown"] = -4
		bad["roster"][2]["lines"] = ["wolf", "drake"]
		bad["roster"][2]["parents"] = [1, 2]
		bad["roster"][2]["line"] = 7
		var r := GameDynasty.from_dict(bad).roster
		ok(r[0]["traits"] == ["hardy", "fierce", "prized"], "unknown, repeated and surplus traits are dropped: %s" % str(r[0]["traits"]))
		ok(r[0]["cooldown"] == 0.0 and r[1]["cooldown"] == 0.0, "a damaged or negative rest becomes none")
		ok(r[0]["breeding"] == false and r[0]["sterile"] == false, "a flag that is not a bool is off")
		ok(not r[2].has("lines") and not r[2].has("line") and (not r[2].has("parents") or r[2]["parents"].is_empty()), "lines that are no cross, a line that is no name and parents that are no names are dropped")
		var born_wrong := d.to_dict()
		born_wrong["roster"][0]["born"] = "egg"   # a plain wolf is born live whatever was saved
		ok(GameDynasty.from_dict(born_wrong).roster[0]["born"] == "live", "a creature with no lines is born as its species is"))


func test_effects() -> void:
	var d := dyn()
	var e := _adult(d, "frost_wolf", "female")
	var plain := GameRanch.sell_price(e)
	e["traits"] = ["prized"]
	ok(GameRanch.sell_price(e) > plain, "prized sells for more")
	e["traits"] = ["sickly"]
	ok(GameRanch.sell_price(e) < plain, "sickly for less")
	var w := dyn()
	var wolf := _adult(w, "harpy", "female")   # eggs 4
	var base := float(GameRanch.yearly_work(w)["gold"])
	wolf["traits"] = ["industrious"]
	ok(float(GameRanch.yearly_work(w)["gold"]) > base and "gold a year" in GameRanch.work_text(wolf), "industrious works harder")
	var g := dyn()
	var guard := _adult(g, "wolf", "female")
	var cut := GameRanch.guard_cut(g)
	guard["traits"] = ["fierce"]
	ok(GameRanch.guard_cut(g) > cut and "30%" in GameRanch.work_text(guard), "fierce guards better (%s then %s)" % [cut, GameRanch.guard_cut(g)])
	var calm := dyn()
	var hard := dyn()
	calm.heir.gold = 0
	hard.heir.gold = 0
	var c := _adult(calm, "wolf", "female")
	var h := _adult(hard, "wolf", "female")
	h["traits"] = ["hardy"]
	c["breeding"] = false
	h["breeding"] = false
	GameRanch.on_years(calm, 1.0, [])
	GameRanch.on_years(hard, 1.0, [])
	ok(h["mood"] > c["mood"], "hardy takes neglect better")
	var s := dyn()
	var sick := dyn()
	s.heir.gold = 0
	sick.heir.gold = 0
	var a := _adult(s, "wolf", "female")
	var b := _adult(sick, "wolf", "female")
	b["traits"] = ["sickly"]
	a["breeding"] = false
	b["breeding"] = false
	GameRanch.on_years(s, 1.0, [])
	GameRanch.on_years(sick, 1.0, [])
	ok(b["mood"] < a["mood"], "sickly sours quickly")
	var traits_line: String = GameRoster.describe({"species": "wolf", "stage": "adult", "traits": ["hardy", "fierce"], "mood": 70, "sex": "male", "age": 5.0, "young": "pup", "born": "live"})["line"]
	ok("Traits: hardy, fierce." in traits_line, "traits are told in the entry: %s" % traits_line)
	var sterile_line: String = GameRoster.describe({"species": "wolf", "stage": "adult", "sterile": true, "mood": 70, "sex": "male", "age": 5.0, "young": "pup", "born": "live"})["line"]
	ok("Sterile." in sterile_line, "and sterility")
	var line_line: String = GameRoster.describe({"species": "wolf", "stage": "adult", "line": "Ash", "mood": 70, "sex": "male", "age": 5.0, "young": "pup", "born": "live"})["line"]
	ok("Of the Ash line." in line_line, "and the line")


func test_set() -> void:
	var d := dyn()
	var e := GameRoster.add(d, "wolf", "Ash")
	ok(not GameBreeding.can_set(e) and not GameBreeding.set_breeding(d, int(e["id"]), true), "a young creature cannot be set to breed")
	e["stage"] = "adult"
	ok(GameBreeding.can_set(e) and GameBreeding.set_breeding(d, int(e["id"]), true) and e["breeding"] == true, "a grown one can")
	ok(GameBreeding.set_breeding(d, int(e["id"]), false) and e["breeding"] == false, "and be set to rest")
	e["sterile"] = true
	ok(not GameBreeding.can_set(e), "a sterile one cannot")
	e["sterile"] = false
	ok(not GameBreeding.set_breeding(d, 999, true), "an unknown creature is refused")
	d.state = "succession"
	ok(not GameBreeding.set_breeding(d, int(e["id"]), true), "and nothing changes outside a life")
