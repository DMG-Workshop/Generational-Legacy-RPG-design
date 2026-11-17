## Realm-timed pens (roadmap follow-up to item 58): each realm has a `flow`, its years for each year at home, and a creature kept
## there ages, costs keep, works and adapts at that pace (a pen in the Verdant Court at half pace lives half as fast). At home, and for
## a creature kept nowhere else, the flow is exactly 1, so the ranch plays as it always did. No dice; the data is checked.
## Run: godot --headless --path . -s res://tests/test_game_realm_time.gd
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
	test_flow()
	test_ageing()
	test_keep_and_work()
	test_adapting()
	print("realm time tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh() -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 100000
	return d


func _kept(d: GameDynasty, species: String, realm: String = "") -> Dictionary:
	var e := GameRoster.add(d, species, "Pip")
	e["stage"] = "young"
	e["age"] = 0.0
	e["mood"] = int(GameRanch.setting("mood_max"))
	if realm != "":
		e["in_realm"] = realm
		e["settled"] = [realm]   # not unsettled: only the pace is being tried
	return e


func test_data() -> void:
	ok(GameRealms.validate().is_empty(), "the shipped data passes: %s" % str(GameRealms.validate()))
	var r: Dictionary = GameRealms.data()["realms"]
	var keep: Variant = r["verdant"]["flow"]
	r["verdant"]["flow"] = 0.0
	ok(not GameRealms.validate().is_empty(), "a realm whose time does not run is caught")
	r["verdant"]["flow"] = 9.0
	ok(not GameRealms.validate().is_empty(), "a flow of 9 is caught")
	r["verdant"]["flow"] = keep
	var home: Variant = r["material"]["flow"]
	r["material"]["flow"] = 2.0
	ok(not GameRealms.validate().is_empty(), "a home realm that runs at 2 is caught")
	r["material"]["flow"] = home
	r["void"].erase("flow")
	ok(not GameRealms.validate().is_empty(), "a realm with no flow is caught")
	r["void"]["flow"] = 0.25
	ok(GameRealms.validate().is_empty(), "and mending the data clears it")


func test_flow() -> void:
	var d := _fresh()
	var plain := _kept(d, "slime")
	ok(GameRealms.flow(plain) == 1.0, "a creature kept nowhere else keeps home time")
	ok(GameRealms.flow(_kept(d, "thornhound", "verdant")) == 0.5, "the Verdant Court runs at half pace")
	ok(GameRealms.flow(_kept(d, "slime", "void")) == 0.25 and GameRealms.flow(_kept(d, "slime", "elemental")) == 1.5, "the Void at a quarter, the Elemental Planes at one and a half")
	ok(GameRealms.flow({"in_realm": "nonesuch"}) == 1.0, "an unknown realm is home time")


func test_ageing() -> void:
	var d := _fresh()
	var home := _kept(d, "slime")
	var slow := _kept(d, "slime", "verdant")
	var fast := _kept(d, "slime", "elemental")
	GameRanch.on_years(d, 1.0, [])
	ok(absf(float(home["age"]) - 1.0) < 0.0001, "at home a year is a year of age")
	ok(absf(float(slow["age"]) - 0.5) < 0.0001, "in the Verdant Court it is half a year: %.3f" % float(slow["age"]))
	ok(absf(float(fast["age"]) - 1.5) < 0.0001, "in the Elemental Planes a year and a half: %.3f" % float(fast["age"]))
	var rng := d.rng.state
	GameRanch.on_years(d, 1.0, [])
	ok(d.rng.state == rng, "no dice are drawn")


func test_keep_and_work() -> void:
	var a := _fresh()
	var b := _fresh()
	var ea := _kept(a, "slime")
	var eb := _kept(b, "slime", "verdant")
	var gold_a := a.heir.gold
	var gold_b := b.heir.gold
	GameRanch.on_years(a, 2.0, [])
	GameRanch.on_years(b, 2.0, [])
	var paid_a := gold_a - a.heir.gold
	var paid_b := gold_b - b.heir.gold
	ok(paid_a > 0 and paid_b > 0 and paid_b * 2 <= paid_a + 1 and paid_b * 2 >= paid_a - 1, "a pen at half pace costs half to keep: %d against %d" % [paid_b, paid_a])
	# work: a hive makes honey, a sheep wool
	var c := _fresh()
	var d2 := _fresh()
	var hc := _kept(c, "sheep")
	var hd := _kept(d2, "sheep", "verdant")
	for e in [hc, hd]:
		e["stage"] = "adult"
		e["age"] = 3.0
	var wc := float(GameRanch.yearly_work(c)["gold"])
	var wd := float(GameRanch.yearly_work(d2)["gold"])
	ok(wc > 0.0 and absf(wd * 2.0 - wc) < 0.001, "and works at half pace: %.2f against %.2f" % [wd, wc])


func test_adapting() -> void:
	var d := _fresh()
	var e := _kept(d, "slime")
	e["in_realm"] = "verdant"
	e.erase("settled")
	e["adapt"] = 0.0
	ok(GameRealms.adapt_left(e) > 0.0, "(a stranger in the Verdant Court, 2 of its years to settle)")
	GameRealms.on_years(d, 3.0, [])
	ok(not GameRealms.settled(e) and absf(float(e["adapt"]) - 1.5) < 0.0001, "three years at home are a year and a half there: %s" % str(e.get("adapt")))
	GameRealms.on_years(d, 1.0, [])
	ok(GameRealms.settled(e), "and a fourth makes the two it needs")
