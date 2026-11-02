## The family house's core rules, with no screens: the costs rise per level and stop at the top, buying
## takes the heir's gold and changes nothing else, the Hall adds party places and the Yard adds training
## XP, a house with nothing bought plays exactly as before, and the house survives a save, while an old
## save or a damaged house value loads with nothing bought.
## Run: godot --headless --path . -s res://tests/test_game_house.gd
extends SceneTree

var checks := 0
var fails := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	GameData.load_all()
	test_costs()
	test_buying()
	test_hall_party_places()
	test_yard_training()
	test_nothing_bought_changes_nothing()
	test_save_round_trip_and_old_saves()
	print("house tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(gold: int = 5000) -> GameDynasty:
	var d := GameDynasty.new_game(21, "", GameData.starting_ids(GameData.classes)[0], "faetouched", "human")
	d.heir.gold = gold
	return d


func test_costs() -> void:
	var d := _dyn()
	var base := int(GameData.bal("house_base_cost"))
	ok(GameHouse.cost(d, GameHouse.HALL) == base, "the first level costs the base price")
	d.house[GameHouse.HALL] = 1
	ok(GameHouse.cost(d, GameHouse.HALL) == int(round(base * float(GameData.bal("house_cost_growth")))), "the next level costs more")
	d.house[GameHouse.HALL] = GameHouse.max_level()
	ok(GameHouse.cost(d, GameHouse.HALL) == -1, "the top level has no next price")
	ok(GameHouse.buy_error(d, GameHouse.HALL) != "", "and cannot be bought")
	ok(GameHouse.buy_error(d, "moat") != "" and GameHouse.cost(d, "moat") == -1 and GameHouse.level(d, "moat") == 0, "an unknown track is refused")


func test_buying() -> void:
	var d := _dyn(500)
	var price := GameHouse.cost(d, GameHouse.YARD)
	var msg := GameHouse.buy(d, GameHouse.YARD)
	ok(GameHouse.level(d, GameHouse.YARD) == 1, "buying raises the track one level")
	ok(d.heir.gold == 500 - price, "and takes the price from the heir's gold")
	ok(msg.contains("Training Yard") and msg.contains("level 1"), "the message names the track and level")
	ok(GameHouse.level(d, GameHouse.HALL) == 0, "other tracks are untouched")
	d.heir.gold = 1
	ok(GameHouse.buy_error(d, GameHouse.HALL) != "", "without the gold, nothing is bought")
	var before := GameHouse.level(d, GameHouse.HALL)
	GameHouse.buy(d, GameHouse.HALL)
	ok(GameHouse.level(d, GameHouse.HALL) == before and d.heir.gold == 1, "and nothing is taken")


func test_hall_party_places() -> void:
	var d := _dyn()
	var base := int(GameData.bal("party_max_size"))
	ok(GameParty.max_size(d) == base, "a new house has the base party size")
	d.house[GameHouse.HALL] = 2
	ok(GameParty.max_size(d) == base + 2 * int(GameData.bal("house_hall_slots_per_level")), "each Hall level adds a companion place")
	d.house[GameHouse.HALL] = 99
	ok(GameHouse.level(d, GameHouse.HALL) == GameHouse.max_level(), "a level past the top is capped")


func test_yard_training() -> void:
	var d := _dyn()
	ok(is_equal_approx(GameHouse.train_xp_mult(d), 1.0), "no Yard, no change to training XP")
	d.house[GameHouse.YARD] = 2
	var want := 1.0 + 2.0 * float(GameData.bal("house_yard_train_xp_per_level"))
	ok(is_equal_approx(GameHouse.train_xp_mult(d), want), "each Yard level adds to training XP")
	var plain := _dyn()
	plain.train("str")
	var yard := _dyn()
	yard.house[GameHouse.YARD] = 3
	yard.train("str")
	ok(yard.heir.xp > plain.heir.xp or yard.heir.level > plain.heir.level, "training with a Yard earns more XP than without")
	ok(plain.heir.training["str"] == yard.heir.training["str"], "the Yard changes XP, not the training itself")


func test_nothing_bought_changes_nothing() -> void:
	var a := _dyn()
	var b := _dyn()
	b.house = GameHouse.from_dict({})
	for i in 3:
		a.train("str")
		b.train("str")
	ok(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()), "an empty house trains exactly as before")
	ok(not a.to_dict().has("house"), "and is not written to the save")


func test_save_round_trip_and_old_saves() -> void:
	var d := _dyn()
	GameHouse.buy(d, GameHouse.HALL)
	GameHouse.buy(d, GameHouse.YARD)
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(back.house == d.house and GameHouse.level(back, GameHouse.HALL) == 1, "the house survives a save")
	var old := d.to_dict()
	old.erase("house")
	var o := GameDynasty.from_dict(old)
	ok(o.house.is_empty() and GameHouse.level(o, GameHouse.HALL) == 0, "an old save loads with nothing bought")
	ok(GameHouse.from_dict("nonsense").is_empty() and GameHouse.from_dict({"hall": "lots", "moat": 4}).is_empty(), "damaged house values are dropped")
	var clamp := GameHouse.from_dict({"hall": 99, "yard": -3})
	ok(clamp.get("hall", 0) == GameHouse.max_level() and not clamp.has("yard"), "levels are kept within range")
