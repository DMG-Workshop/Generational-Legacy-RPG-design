## Faction standings in towns (roadmap item 17, second part): the data and the ways to break it; that a town with a
## faction moves shop and temple prices, companions' hire fees and training XP by the heir's standing with that
## faction, and that nowhere else does; that no die is drawn and nothing new is saved.
## Run: godot --headless --path . -s res://tests/test_game_faction_towns.gd
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
	test_town()
	test_effects()
	test_untouched()
	print("faction towns tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func dyn() -> GameDynasty:
	var d := GameDynasty.new_game(5, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 100000
	return d


func _broken(edit: Callable, word: String) -> bool:
	var saved: Dictionary = GameFactions.data().duplicate(true)
	edit.call(GameFactions.data())
	var found := GameFactions.validate()
	GameFactions._cache = saved
	return found.any(func(p): return word in str(p))


# Puts the house at a rank by the faction's own rules: rogues raise the Thieves' Guild (Brinehaven), necromancers
# lower the Church (Hearthmere). Returns the town the faction keeps.
func _put_at(d: GameDynasty, rank_id: String) -> String:
	d.history.clear()
	d.echoes.clear()
	var cls := ""
	var n := 0
	var town := "brinehaven"
	match rank_id:
		"honoured":
			cls = "rogue"
			n = 7
		"trusted":
			cls = "rogue"
			n = 3
		"wary":
			cls = "necromancer"
			n = 2
			town = "hearthmere"
		"hostile":
			cls = "necromancer"
			n = 5
			town = "hearthmere"
	for i in n:
		d.history.append({"gen": d.gen, "class_id": cls, "level": 1, "battles_won": 0, "kills": {}, "gold": 0, "cause": "old age", "titles": []})
	d.world.location = town
	var faction := str(GameFactions.data()["towns"][town])
	return town


func test_data() -> void:
	ok(GameFactions.validate().is_empty(), "the faction data is sound: %s" % str(GameFactions.validate()))
	ok(_broken(func(x): x["towns"]["kingshold"] = "nobody", "is not a faction"), "a town kept by no faction is refused")
	ok(_broken(func(x): x["towns"]["moon"] = "church", "is not a town"), "a faction's town that is no town is refused")
	ok(_broken(func(x): x["town_effects"]["trusted"]["price"] = 3.0, "between 0.5 and 2"), "a town effect far off is refused")
	ok(_broken(func(x): x["town_effects"]["trusted"]["luck"] = 1.1, "which nothing reads"), "an effect nothing reads is refused")
	ok(_broken(func(x): x["town_effects"].erase("hostile"), "has none"), "a rank with no town effect is refused")


func test_town() -> void:
	var d := dyn()
	d.world.location = "kingshold"
	ok(GameFactions.town_faction(d) == "noble_houses", "Kingshold is the Noble Houses' town")
	d.world.location = "ironford"
	ok(GameFactions.town_faction(d) == "warriors_order", "Ironford is the Order's town")
	d.world.location = "lonely_moor"
	ok(GameFactions.town_faction(d) == "" and GameFactions.town_mult(d, "price") == 1.0, "a wild place has none, and its prices stand")
	d.world.location = "kingshold"
	d.state = "succession"
	ok(GameFactions.town_faction(d) == "" and GameFactions.town_mult(d, "fee") == 1.0, "a dead heir has no town effect")


func test_effects() -> void:
	var d := dyn()
	var before := d.rng.state
	for rank_id in ["honoured", "trusted", "neutral", "wary", "hostile"]:
		_put_at(d, rank_id)
		var fx: Dictionary = GameFactions.data()["town_effects"][rank_id]
		ok(is_equal_approx(GameFactions.town_mult(d, "price"), float(fx["price"])), "%s: prices are %s" % [rank_id, str(fx["price"])])
		ok(is_equal_approx(GameFactions.town_mult(d, "fee"), float(fx["fee"])), "%s: hire fees are %s" % [rank_id, str(fx["fee"])])
		ok(is_equal_approx(GameFactions.town_mult(d, "train"), float(fx["train"])), "%s: training is %s" % [rank_id, str(fx["train"])])
	# the same house pays more in Hearthmere when the Church holds it hostile than where it is trusted by the guild
	_put_at(d, "trusted")
	var p_trusted := GameItems.price_mult(d)
	_put_at(d, "hostile")
	var p_hostile := GameItems.price_mult(d)
	ok(p_hostile > p_trusted, "the same house pays more in a town its faction holds hostile: %.3f against %.3f" % [p_hostile, p_trusted])
	ok(d.rng.state == before, "no die is drawn by any town effect")
	# the fee and the training move with the town, and not away from it
	var party: GameParty = d.party
	_put_at(d, "hostile")
	var fee_here := party.fee(d, "sister_oriel")
	d.world.location = "lonely_moor"
	var fee_away := party.fee(d, "sister_oriel")
	ok(fee_here > fee_away and fee_away == int(round(float(GameParty.def("sister_oriel").get("fee", 0)) * GameData.enemy_scale(d.gen))), "a hire fee is dearer in a hostile town than away from it: %d against %d" % [fee_here, fee_away])
	# the same heir at the same level both times, so only the town differs
	d.heir.level = 5
	d.heir.xp = 0
	d.world.location = "lonely_moor"
	d.train("str")
	var away := d.heir.xp
	d.heir.level = 5
	d.heir.xp = 0
	d.world.location = "hearthmere"
	d.train("str")
	var here := d.heir.xp
	ok(here < away, "training in a town its faction holds hostile earns less XP than away from it: %d against %d" % [here, away])


func test_untouched() -> void:
	# a house away from every town is priced, hired and trained exactly as before
	var a := dyn()
	_put_at(a, "honoured")
	a.world.location = "lonely_moor"
	var b := dyn()
	_put_at(b, "hostile")
	b.world.location = "lonely_moor"
	ok(GameItems.price_mult(a) == GameItems.price_mult(b) and a.party.fee(a, "sister_oriel") == b.party.fee(b, "sister_oriel"), "away from the towns, a standing changes nothing")
	# and saving carries no new key
	ok(not a.to_dict().has("towns") and not a.to_dict()["heir"].has("town"), "nothing town-related is saved")
