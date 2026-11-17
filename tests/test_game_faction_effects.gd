## Faction standings change quests and who comes for the house (roadmap follow-up to item 17): the standing with the faction of the
## town that posted a quest scales its gold and XP by rank (`quest_effects`), a giver no faction keeps pays as before, and the
## Thieves' Guild's standing scales the chance of a raid (`raid_effects`). Neutral is exactly 1, no living heir is 1, no dice are
## drawn, the data is checked, and the board shows what is paid now.
## Run: godot --headless --path . -s res://tests/test_game_faction_effects.gd
extends SceneTree

var fails := 0
var checks := 0
const RANKS := ["hostile", "wary", "neutral", "trusted", "honoured"]


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
	test_quest()
	test_raid()
	test_untouched()
	print("faction effect tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh() -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


## Holds every faction at one rank by moving the thresholds, and gives back what it moved.
func _hold(rank_id: String) -> Array:
	var ranks: Array = GameFactions.data()["ranks"]
	var saved: Array = []
	for r in ranks:
		saved.append(int(r["min"]))
	for i in ranks.size():
		if str(ranks[i]["id"]) == rank_id:
			ranks[i]["min"] = -101
		elif i > 0:
			ranks[i]["min"] = 101 if RANKS.find(str(ranks[i]["id"])) > RANKS.find(rank_id) else -101
	# the highest rank whose min is reached wins: those below the chosen one must not outrank it
	for i in ranks.size():
		if RANKS.find(str(ranks[i]["id"])) > RANKS.find(rank_id):
			ranks[i]["min"] = 101
		elif RANKS.find(str(ranks[i]["id"])) < RANKS.find(rank_id):
			ranks[i]["min"] = -102
	return saved


func _release(saved: Array) -> void:
	var ranks: Array = GameFactions.data()["ranks"]
	for i in ranks.size():
		ranks[i]["min"] = saved[i]


func test_data() -> void:
	ok(GameFactions.validate().is_empty(), "the shipped data passes: %s" % str(GameFactions.validate()))
	var qfx: Dictionary = GameFactions.data()["quest_effects"]
	var keep: Variant = qfx["wary"]
	qfx.erase("wary")
	ok(not GameFactions.validate().is_empty(), "a rank with no quest effect is caught")
	qfx["wary"] = keep
	qfx["wary"] = {"gold": 3.0, "xp": 1.0}
	ok(not GameFactions.validate().is_empty(), "a quest gold multiplier of 3 is caught")
	qfx["wary"] = {"gold": 1.0, "xp": 1.0, "fame": 2.0}
	ok(not GameFactions.validate().is_empty(), "an effect nothing reads is caught")
	qfx["wary"] = keep
	var rfx: Dictionary = GameFactions.data()["raid_effects"]
	var fac: Variant = rfx["faction"]
	rfx["faction"] = "nonesuch"
	ok(not GameFactions.validate().is_empty(), "a raid effect for a faction that does not exist is caught")
	rfx["faction"] = fac
	var ch: Variant = rfx["chance"]["hostile"]
	rfx["chance"]["hostile"] = 9.0
	ok(not GameFactions.validate().is_empty(), "a raid multiplier of 9 is caught")
	rfx["chance"]["hostile"] = ch
	ok(GameFactions.validate().is_empty(), "and mending the data clears it")


func _church_quest() -> Dictionary:
	for q in GameData.quests:
		if str(GameFactions.data()["towns"].get(str(q["giver"]), "")) != "" and float(q["reward"].get("gold", 0)) > 0.0 and float(q["reward"].get("xp", 0)) > 0.0:
			return q
	return {}


func test_quest() -> void:
	var d := _fresh()
	var q := _church_quest()
	ok(not q.is_empty(), "(a quest from a faction's town: %s)" % str(q.get("giver", "")))
	var base_gold := float(q["reward"]["gold"]) * GameData.enemy_scale(d.gen) * float(GameData.bal("quest_gold_mult"))
	var base_xp := float(q["reward"]["xp"]) * GameData.xp_level_scale(d.heir.level) * float(GameData.bal("quest_xp_mult"))
	var rng := d.rng.state
	var pay := {}
	for r in RANKS:
		var saved := _hold(r)
		ok(GameFactions.rank(d, GameFactions.data()["towns"][q["giver"]]) == r, "(held at %s)" % r)
		pay[r] = [GameQuests.reward_gold(d, q), GameQuests.reward_xp(d, q)]
		ok(GameFactions.quest_mult(d, q, "gold") == float(GameFactions.data()["quest_effects"][r]["gold"]), "%s: the gold multiplier is the data's" % r)
		_release(saved)
	ok(pay["neutral"][0] == int(round(base_gold)) and pay["neutral"][1] == int(round(base_xp)), "neutral pays exactly as before: %s" % str(pay["neutral"]))
	ok(pay["hostile"][0] < pay["wary"][0] and pay["wary"][0] < pay["neutral"][0] and pay["neutral"][0] < pay["trusted"][0] and pay["trusted"][0] < pay["honoured"][0], "gold rises with standing: %s" % str(pay))
	ok(pay["hostile"][1] < pay["neutral"][1] and pay["neutral"][1] < pay["honoured"][1], "and so does XP")
	ok(d.rng.state == rng, "no dice are drawn")
	var saved2 := _hold("honoured")
	ok(GameQuests.reward_text(d, q).contains(GameText.num(GameQuests.reward_gold(d, q))), "the board's reward text shows what is paid now: %s" % GameQuests.reward_text(d, q))
	_release(saved2)
	# a giver no faction keeps
	var free := q.duplicate(true)
	free["giver"] = "nowhere"
	var saved3 := _hold("honoured")
	ok(GameFactions.quest_mult(d, free, "gold") == 1.0 and GameQuests.reward_gold(d, free) == int(round(float(free["reward"]["gold"]) * GameData.enemy_scale(d.gen) * float(GameData.bal("quest_gold_mult")))), "a giver no faction keeps pays as before")
	_release(saved3)


func test_raid() -> void:
	var d := _fresh()
	d.heir.gold = 5000
	var by := {}
	for r in RANKS:
		var saved := _hold(r)
		by[r] = GameRaids.chance(d)
		ok(GameFactions.raid_mult(d) == float(GameFactions.data()["raid_effects"]["chance"][r]), "%s: the raid multiplier is the data's" % r)
		_release(saved)
	ok(by["neutral"] > 0.0, "(a house with gold can be raided: %.4f)" % by["neutral"])
	ok(by["hostile"] > by["wary"] and by["wary"] > by["neutral"] and by["neutral"] > by["trusted"] and by["trusted"] > by["honoured"], "the Guild's contempt brings raiders, its honour keeps them off: %s" % str(by))
	ok(absf(by["hostile"] / by["neutral"] - float(GameFactions.data()["raid_effects"]["chance"]["hostile"])) < 0.001, "by the data's share")
	# a house with no purse worth taking and nothing kept is never raided, whatever the Guild thinks
	var poor := _fresh()
	poor.heir.gold = 0
	var saved := _hold("hostile")
	ok(GameRaids.chance(poor) == 0.0, "no purse, nothing kept or built: no raid, even from a hostile Guild")
	_release(saved)


func test_untouched() -> void:
	var d := _fresh()
	d.state = "dead"
	var q := _church_quest()
	var saved := _hold("honoured")
	ok(GameFactions.quest_mult(d, q, "gold") == 1.0 and GameFactions.raid_mult(d) == 1.0, "with no living heir both are 1")
	_release(saved)
	ok(GameFactions.quest_mult(null, q, "gold") == 1.0 and GameFactions.raid_mult(null) == 1.0, "and with no dynasty")
	var fresh := _fresh()
	ok(GameFactions.rank(fresh, "church") == "neutral" and GameFactions.quest_mult(fresh, q, "gold") == 1.0, "a new house is neutral with everyone and paid as before")
