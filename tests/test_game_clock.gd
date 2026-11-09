## The world clock (GameClock): real time fed to the world passes the same spans of years that actions pass,
## through the one call GameDynasty.pass_time. Seconds add up to whole spans with the rest carried (and saved);
## feeding a span is the same as passing it (same ageing, wages, weather, dice); the clock holds still during a
## fight, a waiting event and a succession; left running it carries a line from heir to heir with the Ages
## recording each death; the carry loads from old and damaged saves.
## Run: godot --headless --path . -s res://tests/test_game_clock.gd
extends SceneTree

const Scen := preload("res://tests/round_scenarios.gd")
const TRIO := ["sister_oriel", "bren_cask"]

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
	test_tunables()
	test_spans()
	test_same_as_an_action_span()
	test_holds()
	test_old_age()
	test_saving()
	print("%d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## A dynasty out of any fight with a party on the payroll.
func _house(seed_val: int) -> GameDynasty:
	var d := GameDynasty.new_game(seed_val, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 5000
	d.world.visit("kingshold")
	for id in TRIO:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": 10, "gen": 1,
			"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
		d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
			"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	d.party.rest(d)
	return d


## What a dynasty came to, dice included, without the clock's own carry.
func _digest(d: GameDynasty) -> String:
	var v: Dictionary = Scen.drop_sex(d.to_dict())
	v.erase("clock_carry")
	v.erase("world_seconds")   # the seconds the clock ran (GameDay) are the clock's own too
	return JSON.stringify(v) + str(d.rng.state)


func test_tunables() -> void:
	ok(GameClock.seconds_per_year() > 0.0 and GameClock.span_years() > 0.0, "the clock has a rate and a span")
	ok(is_equal_approx(GameClock.span_years(), 1.0), "a span is a year, what an action's year already is")


func test_spans() -> void:
	var d := _house(3)
	var spy := GameClock.seconds_per_year()
	var age := d.heir.age
	var year := d.world.year
	GameClock.feed(d, spy * 0.4)
	ok(is_equal_approx(d.heir.age, age) and is_equal_approx(d.world.year, year), "less than a span passes nothing")
	ok(is_equal_approx(GameClock.carried(d), 0.4), "and is carried")
	GameClock.feed(d, spy * 0.7)
	ok(is_equal_approx(d.world.year, year + 1.0) and is_equal_approx(d.heir.age, age + 1.0), "carried time and more make a span: a year passes")
	ok(is_equal_approx(GameClock.carried(d), 0.1), "and the rest is carried")
	GameClock.feed(d, spy * 3.0)
	ok(is_equal_approx(d.world.year, year + 4.0), "three more spans pass three more years")
	GameClock.feed(d, 0.0)
	GameClock.feed(d, -50.0)
	ok(is_equal_approx(d.world.year, year + 4.0) and is_equal_approx(GameClock.carried(d), 0.1), "no time and negative time pass nothing")
	# the same time fed in small pieces or all at once ends alike
	var a := _house(5)
	var b := _house(5)
	for i in 119:
		GameClock.feed(a, 1.0)
	GameClock.feed(b, 119.0)
	ok(_digest(a) == _digest(b), "119 seconds fed one at a time end as 119 fed at once")
	ok(absf(GameClock.carried(a) - GameClock.carried(b)) < 0.000001, "with the same time carried")


func test_same_as_an_action_span() -> void:
	var a := _house(9)
	var b := _house(9)
	ok(_digest(a) == _digest(b), "two houses of one seed start alike")
	GameClock.feed(a, GameClock.seconds_per_year() * 5.0)
	for i in 5:
		b.pass_time(1.0)
	ok(_digest(a) == _digest(b), "five spans fed are five years passed: the same heir, party, wages, weather and dice")
	ok(a.heir.gold < 5000 or a.party.members.size() != 2 or a.party.members.any(func(m): return float(m["due"]) != 0.0), "and the party's wages did run")
	# a longer lump of years rolls the weather and the death once, so it is not the same dice as two spans, but the
	# calendar and the heir's age agree
	var c := _house(11)
	var e := _house(11)
	c.pass_time(2.0)
	GameClock.feed(e, GameClock.seconds_per_year() * 2.0)
	ok(is_equal_approx(c.world.year, e.world.year) and is_equal_approx(c.heir.age, e.heir.age), "two years passed at once and two spans fed reach the same date and age")


func test_holds() -> void:
	var spy := GameClock.seconds_per_year()
	var d := Scen.make(4, "warrior", 1, "hunt")
	ok(d.battle != null and not GameClock.running(d), "a fight holds the clock")
	var age := d.heir.age
	GameClock.feed(d, spy * 10.0)
	ok(is_equal_approx(d.heir.age, age) and is_equal_approx(GameClock.carried(d), 0.0), "feeding during a fight passes no years and banks none")
	var e := _house(6)
	e.pending_event = {"id": "wait"}
	ok(not GameClock.running(e), "an event waiting for an answer holds the clock")
	GameClock.feed(e, spy * 10.0)
	var age2 := e.heir.age
	GameClock.feed(e, spy * 10.0)
	ok(is_equal_approx(e.heir.age, age2) and is_equal_approx(GameClock.carried(e), 0.0), "feeding it passes no years and banks none")
	var f := _house(7)
	f.state = "succession"
	var age3 := f.heir.age
	GameClock.feed(f, spy * 10.0)
	ok(is_equal_approx(f.heir.age, age3) and not GameClock.running(f), "a succession holds the clock")


func test_old_age() -> void:
	var d := _house(2)
	d.world.visit("kingshold")
	var spy := GameClock.seconds_per_year()
	var fed := 0.0
	var deaths := 0
	var guard := 0
	while deaths < 3 and guard < 4000:
		guard += 1
		if d.state == "succession":
			d.choose_heir(0)
			deaths += 1
			continue
		if d.state != "life":
			break
		GameClock.feed(d, spy * 0.5)
		fed += spy * 0.5
	ok(deaths == 3, "left running, the clock carries a line through three deaths (%d)" % deaths)
	ok(d.history.size() == 3 and d.history.all(func(r): return r["cause"] == "old age"), "each ending of old age, recorded in the history")
	ok(d.gen == 4, "into the fourth generation")
	ok(d.ages != null and not d.ages.to_dict().is_empty(), "with the Ages keeping their record")
	var years := d.world.year
	ok(years > 30.0 and years < fed / spy + 0.001, "the calendar moved with the clock, never faster than it was fed (%.1f years)" % years)
	ok(d.rng.state != 0, "and the world's dice were used")


func test_saving() -> void:
	var d := _house(8)
	ok(not d.to_dict().has("clock_carry"), "a clock holding no time adds nothing to the save")
	GameClock.feed(d, GameClock.seconds_per_year() * 0.25)
	var parsed = JSON.parse_string(JSON.stringify(d.to_dict()))
	ok(parsed.has("clock_carry"), "time held is in the save")
	var back := GameDynasty.from_dict(parsed)
	ok(is_equal_approx(GameClock.carried(back), 0.25), "and loads back")
	GameClock.feed(back, GameClock.seconds_per_year() * 0.75)
	GameClock.feed(d, GameClock.seconds_per_year() * 0.75)
	ok(_digest(back) == _digest(d), "a reloaded clock goes on exactly as one never saved")
	for bad in ["soon", -3, null, [1], {"a": 1}, INF, NAN]:
		var src: Dictionary = JSON.parse_string(JSON.stringify(_house(8).to_dict()))
		src["clock_carry"] = bad
		var g := GameDynasty.from_dict(src)
		ok(g != null and GameClock.carried(g) == 0.0, "a damaged carry (%s) loads as none" % str(bad))
