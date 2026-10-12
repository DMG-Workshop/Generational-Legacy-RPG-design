## The battle side of sickness (GamePlague): carriers, searching the dead, toxins, plague vials,
## sick companions, saves and determinism.
## godot --headless --path . -s res://tests/test_game_plague.gd
extends SceneTree

var failures := 0
var checks := 0


func _check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL: ", what)


func _fresh(seed_value: int = 4242, class_id: String = "warrior", race: String = "human") -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Test", class_id, "faetouched", race)
	d.heir.traits = d.heir.traits.filter(func(t): return GameData.trait_def(t).get("category", "") == "bloodline")
	d.heir.dormant = []
	d.pending_event = {}
	d.echoes = []
	return d


## `n` foes of one creature at the heir's level, begun as a hunt.
func _hunt(d: GameDynasty, creature: String, n: int) -> GameBattle:
	var foes: Array = []
	for i in n:
		foes.append(d._make_enemy(GameCombat.creature_def(creature), 1.0, 1.0, d.heir.level))
	return d._begin_battle(foes, "hunt")


func _win(d: GameDynasty) -> Array:
	for e in d.battle.enemies:
		e["hp"] = 0
	d.battle.result = "victory"
	return d.finish_battle()


func _tune(key: String, v: Variant) -> Variant:
	var s: Dictionary = GameData.plague["settings"]
	var old: Variant = s[key]
	s[key] = v
	return old


func _roundtrip(d: GameDynasty) -> GameDynasty:
	return GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))


func _init() -> void:
	GameData.load_all()
	_test_chances_are_low()
	_test_data()
	_test_infected_foes()
	_test_loot_offer()
	_test_search_and_leave()
	_test_contagion_rates()
	_test_resistance()
	_test_loot_worth_the_risk()
	_test_bot_loot()
	_test_loot_saves()
	_test_coat_blade()
	_test_toxin_backfire()
	_test_vials()
	_test_tactics()
	_test_tactics_cost()
	_test_companion_state()
	_test_companion_contagion()
	_test_companion_death()
	_test_companion_cure()
	_test_companion_rehire()
	_test_old_saves()
	_test_determinism()
	print("%d checks, %d failures" % [checks, failures])
	print("ALL PASS" if failures == 0 else "TESTS FAILED")
	quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------- data

## The player's rule: every random chance of catching a sickness is at most 2%. Black-market
## bargains (20%) are the player's one exception and are left as they are.
func _test_chances_are_low() -> void:
	_check(float(GamePlague.setting("infected_chance")) <= 0.02, "an infected foe passes its sickness at most 2% of the time")
	for c in GameData.creatures:
		for x in c.get("carries", []):
			_check(float(x["chance"]) <= 0.02, "%s carries %s at most 2%%" % [c["id"], x["disease"]])
	for dz in GameDisease.all():
		_check(float(dz["contagion"].get("companion", 0.0)) <= 0.02, "%s: companion contagion at most 2%% a year" % dz["id"])
	for id in GameData.items:
		var it: Dictionary = GameData.items[id]
		if it.has("toxin"):
			_check(float(it["toxin"].get("backfire", {}).get("chance", 0.0)) <= 0.02, "%s backfires at most 2%%" % id)
		if it.has("vial"):
			_check(float(it["vial"].get("splash", 0.0)) <= 0.02, "%s splashes its thrower at most 2%%" % id)
		if it.has("taint"):
			_check(float(it["taint"].get("chance", 0.2)) <= 0.2, "%s: its own taint chance is at most 20%%" % id)
	_check(is_equal_approx(float(GameDisease.setting("bargain_taint_chance")), 0.2), "bargains stay tainted 20% of the time")


func _test_data() -> void:
	_check(GameCombat.validate().is_empty(), "combat data is sound: %s" % str(GameCombat.validate()))
	_check(GameDisease.validate().is_empty(), "disease data is sound: %s" % str(GameDisease.validate()))
	for c in GameData.creatures:
		for x in c.get("carries", []):
			_check(not GameDisease.def(str(x["disease"])).is_empty(), "%s carries a known sickness" % c["id"])
	for p in GamePlague.setting("infected_pool"):
		_check(not GameDisease.def(str(p["disease"])).is_empty(), "infected pool: %s is known" % p["disease"])
	GamePlague.data()
	for st in GameData.plague["statuses"]:
		_check(not GameCombat.status_def(st["id"]).is_empty(), "status %s is registered" % st["id"])
	for id in GameData.items:
		if GameData.items[id].has("vial"):
			var ab := GamePlague.vial_ability(id)
			_check(GameCombat.shape(ab) == "burst" and GameCombat.is_aoe(ab), "%s is thrown as a burst" % id)
			_check(not GameCombat.status_def(str(ab["statuses"][0]["id"])).is_empty(), "%s sickens with a known status" % id)
	for id in ["plague_rat", "ghoul", "skeleton", "wraith", "bog_troll"]:
		_check(not (GameCombat.creature_def(id).get("carries", []) as Array).is_empty(), "%s carries sickness" % id)


# ---------------------------------------------------------------- carriers

func _test_infected_foes() -> void:
	var d := _fresh(31)
	d.heir.level = 20
	var old: Variant = _tune("infected_spawn", 1.0)
	var b := _hunt(d, "skeleton", 3)
	for e in b.enemies:
		_check(str(e.get("infected", "")) == "grave_rot", "a skeleton spawns infected with its own grave rot")
		_check(str(e["name"]).begins_with("Plague-touched"), "and its name says so: %s" % e["name"])
		var c := GamePlague.carried(e)
		_check(c.size() == 1 and is_equal_approx(float(c[0]["chance"]), float(GamePlague.setting("infected_chance"))), "infected odds replace the base odds: %s" % str(c))
	d.battle = null
	b = _hunt(d, "wolf", 2)
	_check(b.enemies.all(func(e): return str(e.get("infected", "")) != ""), "a clean creature is infected from the pool")
	d.battle = null
	var foes := [d._make_enemy(GameCombat.creature_def("grimfang"), 1.0, 1.0, 10)]
	b = d._begin_battle(foes, "legend")
	_check(not b.enemies[0].has("infected"), "legends are never plague-touched")
	d.battle = null
	var elite := d._make_enemy(GameCombat.creature_def("wolf"), 1.0, 1.0, 10)
	elite["name"] = "Elite " + elite["name"]
	GamePlague.mark_infected(d, [elite])
	_check(elite["name"] == "Elite Plague-touched Dire Wolf", "an elite stays an elite first: %s" % elite["name"])
	_tune("infected_spawn", 0.0)
	b = _hunt(d, "skeleton", 2)
	_check(GamePlague.carried(b.enemies[0]) == [{"disease": "grave_rot", "chance": float(GameCombat.creature_def("skeleton")["carries"][0]["chance"])}], "an uninfected skeleton carries at its base odds")
	d.battle = null
	_tune("infected_spawn", old)


# ---------------------------------------------------------------- searching the dead

func _test_loot_offer() -> void:
	var d := _fresh(32)
	d.heir.level = 12
	_hunt(d, "wolf", 3)
	var base := 0
	for e in d.battle.enemies:
		base += int(e["gold"])
	var before := d.heir.gold
	var msgs := _win(d)
	_check(d.heir.gold > before, "the victory's own gold comes at once")
	_check(not d.loot.is_empty() and int(d.loot["gold"]) == base and (d.loot["foes"] as Array).size() == 3, "the dead wait to be searched: %s" % str(d.loot))
	_check(msgs.any(func(m): return "Victory" in str(m)), "victory is told as before")
	var foes := [d._make_enemy(GameCombat.creature_def("grimfang"), 1.0, 1.0, 10)]
	d._begin_battle(foes, "legend")
	_check(d.loot.is_empty(), "a new battle leaves the old dead behind")
	_win(d)
	_check(d.loot.is_empty(), "a legend's body is not searched")
	_hunt(d, "wolf", 1)
	d.battle.result = "fled"
	d.finish_battle()
	_check(d.loot.is_empty(), "fleeing leaves nothing to search")
	_hunt(d, "wolf", 1)
	_win(d)
	_check(not d.loot.is_empty(), "won again")
	d.rest()
	_check(d.loot.is_empty(), "moving on (any action that takes time) leaves the dead unsearched")
	_hunt(d, "wolf", 2)
	_win(d)
	_check(not d.loot.is_empty(), "won before retiring")
	var first := d.heir.name
	d.heir.age = d.heir.lifespan
	d.retire()
	_check(d.state == "succession" and d.loot.is_empty(), "a retiring heir leaves their dead behind")
	if d.state == "succession" and not d.candidates.is_empty():
		d.choose_heir(0)
		_check(d.state == "life" and d.gen == 2, "a new heir took over from %s" % first)
		_check(d.loot.is_empty() and GamePlague.search(d).is_empty(), "the new heir finds no bodies from a fight they never fought")
	var stale := _fresh(34)
	stale.heir.level = 10
	_hunt(stale, "wolf", 2)
	_win(stale)
	var sd: Dictionary = JSON.parse_string(JSON.stringify(stale.to_dict()))
	sd["state"] = "succession"
	_check((GameDynasty.from_dict(sd).loot as Dictionary).is_empty(), "an old save in succession drops the last heir's dead")
	# Generation scaling: the purse grows with the foes' own gold.
	var late := _fresh(33)
	late.gen = 300
	late.heir.gen = 300
	late.heir.level = 3000
	_hunt(late, "wolf", 3)
	_win(late)
	_check(int(late.loot["gold"]) > int(GameData.enemy_scale(300) * 8.0), "at generation 300 the dead carry generation-300 gold: %d" % int(late.loot["gold"]))


func _test_search_and_leave() -> void:
	var d := _fresh(34)
	d.heir.level = 12
	_hunt(d, "wolf", 3)
	_win(d)
	var loot := d.loot.duplicate(true)
	var gold := d.heir.gold
	var lines := GamePlague.search(d)
	var got := d.heir.gold - gold
	var share := float(GamePlague.setting("loot_gold_share"))
	var spread := float(GamePlague.setting("loot_gold_spread"))
	_check(got >= int(floor(float(loot["gold"]) * share * (1.0 - spread))) and got <= int(ceil(float(loot["gold"]) * share * (1.0 + spread))) + 400, "searching pays a share of the hunt's gold: %d of %d" % [got, int(loot["gold"])])
	_check(d.loot.is_empty() and not lines.is_empty() and "searches the bodies" in str(lines[0]), "searched once: %s" % str(lines))
	_check(GamePlague.search(d).is_empty(), "the same dead cannot be searched twice")
	_hunt(d, "wolf", 2)
	_win(d)
	gold = d.heir.gold
	lines = GamePlague.leave(d)
	_check(d.heir.gold == gold and d.loot.is_empty() and "leaves the dead" in str(lines[0]), "leaving them costs and pays nothing")
	# Finds: always found at chance 1, and a full stack turns into gold.
	var old: Variant = _tune("loot_item_chance", 1.0)
	var finds := {}
	for i in 60:
		d.heir.age = d.heir.adult_age()
		d.heir.hazard_age = d.heir.age
		_hunt(d, "wolf", 1)
		_win(d)
		var potions := d.heir.potions
		var pack := d.heir.inventory.size()
		gold = d.heir.gold
		lines = GamePlague.search(d)
		_check(lines.size() >= 2, "a find is told: %s %s" % [str(lines), d.state])
		if d.heir.potions > potions:
			finds["potion"] = true
		elif d.heir.inventory.size() > pack:
			finds[d.heir.inventory.back()] = true
		else:
			finds["sold"] = true
	_check(finds.has("potion") and finds.size() >= 3, "the dead give up potions and remedies: %s" % str(finds.keys()))
	_check(finds.has("sold"), "a full stack is sold on instead")
	_tune("loot_item_chance", old)


## Measured: an exposure at the data's odds catches about that often, and never more.
func _test_contagion_rates() -> void:
	var d := _fresh(35, "warrior", "human")
	var caught := 0
	var n := 4000
	for i in n:
		d.loot = {"gold": 10, "item_chance": 0.0, "foes": [{"id": "plague_rat", "name": "Plague Rat", "carries": [{"disease": "rat_plague", "chance": 0.01}]}]}
		d.heir.diseases = []
		GamePlague.search(d)
		if GameDisease.has(d.heir, "rat_plague"):
			caught += 1
	var rate := float(caught) / float(n)
	var res := GameDisease.resistance(d.heir, "rat_plague")
	var want := 0.01 * (1.0 - res)
	_check(absf(rate - want) < 0.005, "a 1%% carrier infects about 1%% of searches: %.4f (want %.4f)" % [rate, want])
	_check(GamePlague.risk(d) == 0.0, "nothing left to search, no risk")
	d.loot = {"gold": 10, "item_chance": 0.0, "foes": [
		{"id": "skeleton", "name": "Skeleton", "carries": [{"disease": "grave_rot", "chance": 0.01}]},
		{"id": "ghoul", "name": "Ghoul", "carries": [{"disease": "grave_rot", "chance": 0.015}, {"disease": "red_flux", "chance": 0.01}]},
		{"id": "wolf", "name": "Wolf", "carries": []}]}
	d.heir.diseases = []
	var r := GamePlague.risk(d)
	var exp := maxf(0.015 * (1.0 - GameDisease.resistance(d.heir, "grave_rot")), 0.01 * (1.0 - GameDisease.resistance(d.heir, "red_flux")))
	_check(absf(r - exp) < 0.000001, "a search is one exposure, to the likeliest sickness among the dead: %.4f" % r)
	_check(GamePlague.exposure(d.heir, d.loot)["disease"] == "grave_rot", "and that is the ghoul's grave rot")
	GameDisease.infect(d.heir, "grave_rot", "test")
	_check(GamePlague.exposure(d.heir, d.loot)["disease"] == "red_flux", "a sickness the heir already has is not risked again")
	d.heir.diseases = []
	# However many carriers lie there, a search catches about as often as the likeliest alone.
	var pack := {"gold": 10, "item_chance": 0.0, "foes": []}
	for i in 4:
		pack["foes"].append({"id": "plague_rat", "name": "Plague Rat", "carries": [{"disease": "rat_plague", "chance": 0.02}]})
	var got := 0
	for i in n:
		d.loot = pack.duplicate(true)
		d.heir.diseases = []
		GamePlague.search(d)
		got += 0 if d.heir.diseases.is_empty() else 1
	var one := 0.02 * (1.0 - GameDisease.resistance(d.heir, "rat_plague"))
	_check(absf(float(got) / float(n) - one) < 0.006, "four 2%% carriers: %.4f of searches catch it, as one would (%.4f)" % [float(got) / float(n), one])
	d.loot = {"gold": 10, "item_chance": 0.0, "foes": [
		{"id": "skeleton", "name": "Skeleton", "carries": [{"disease": "grave_rot", "chance": 0.01}]},
		{"id": "ghoul", "name": "Ghoul", "carries": [{"disease": "grave_rot", "chance": 0.015}, {"disease": "red_flux", "chance": 0.01}]},
		{"id": "wolf", "name": "Wolf", "carries": []}]}
	_check(GamePlague.risk_diseases(d) == ["grave_rot", "red_flux"], "the deadly one is named first")
	var t := GamePlague.risk_text(d)
	_check("2 of the dead carry" in t and "Grave Rot" in t and "%" in t, "the risk is told: %s" % t)
	d.loot["foes"] = [{"id": "wolf", "name": "Wolf", "carries": []}]
	_check(GamePlague.risk_text(d) == str(GameData.plague["text"]["clean"]), "clean dead are said to be clean")


func _test_resistance() -> void:
	var dwarf := _fresh(36, "warrior", "dwarf")
	var human := _fresh(36, "warrior", "human")
	_check(GameDisease.resistance(dwarf.heir, "rat_plague") > GameDisease.resistance(human.heir, "rat_plague"), "dwarves resist")
	var counts := {}
	for d in [dwarf, human]:
		var n := 0
		for i in 3000:
			d.loot = {"gold": 1, "item_chance": 0.0, "foes": [{"id": "x", "name": "x", "carries": [{"disease": "rat_plague", "chance": 0.02}]}]}
			d.heir.diseases = []
			GamePlague.search(d)
			n += 1 if GameDisease.has(d.heir, "rat_plague") else 0
		counts[d.heir.race_id] = n
	_check(int(counts["dwarf"]) < int(counts["human"]), "a dwarf catches less from the dead: %s" % str(counts))
	var dead := _fresh(37)
	dead.heir.traits.append("undead")
	dead.loot = {"gold": 1, "item_chance": 0.0, "foes": [{"id": "x", "name": "x", "carries": [{"disease": "grave_rot", "chance": 0.02}]}]}
	_check(GamePlague.risk(dead) == 0.0, "the undead cannot catch it")


## On average the extra gold of a search is worth more than the sickness it risks costs to cure,
## at generation 1 and generation 300, for the worst carriers.
func _test_loot_worth_the_risk() -> void:
	for spec in [[1, 10], [300, 3000]]:
		var d := _fresh(38)
		d.gen = spec[0]
		d.heir.gen = spec[0]
		d.heir.level = spec[1]
		d.world.visit("hollow_barrow")
		_hunt(d, "skeleton", 3)
		_win(d)
		var exp_gold := float(d.loot["gold"]) * float(GamePlague.setting("loot_gold_share"))
		var x := GamePlague.exposure(d.heir, d.loot)
		var cost := float(x["risk"]) * float(GameDisease.cure_price(d, str(x["disease"])))
		_check(exp_gold > cost * 2.0, "gen %d: searching skeletons pays %.0f gold against %.1f expected cure cost" % [spec[0], exp_gold, cost])


func _test_bot_loot() -> void:
	var d := _fresh(39)
	d.heir.level = 30
	var low := float(GamePlague.setting("bot_loot_max_risk"))
	d.loot = {"gold": 100, "item_chance": 0.0, "foes": [{"id": "wolf", "name": "Wolf", "carries": [{"disease": "red_flux", "chance": low}]}]}
	d.heir.gold = 0
	_check(GamePlague.bot_wants_search(d), "low risk: the autopilot searches, even with no gold for a cure")
	d.loot = {"gold": 100, "item_chance": 0.0, "foes": []}
	for i in 3:
		d.loot["foes"].append({"id": "ghoul", "name": "Ghoul", "carries": [{"disease": "grave_rot", "chance": 0.02}, {"disease": "rat_plague", "chance": 0.02}]})
	d.heir.gold = 0
	_check(not GamePlague.bot_wants_search(d), "high risk and no gold for a cure: it leaves them")
	d.heir.gold = 1000000
	_check(GamePlague.bot_wants_search(d), "high risk but a cure is affordable: it searches")
	var lines := GamePlague.bot_loot(d)
	_check(d.loot.is_empty() and "searches" in str(lines[0]), "bot_loot searched")
	# The autopilot settles the dead after its own fights.
	var e := _fresh(40)
	for i in 30:
		if e.state != "life":
			break
		GameBot.step(e)
		_check(e.loot.is_empty(), "after a step the autopilot has searched or left the dead")
	_check(e.journal.any(func(l): return "searches the bodies" in str(l) or "leaves the dead" in str(l)), "and says so")


func _test_loot_saves() -> void:
	var d := _fresh(41)
	d.heir.level = 25
	_hunt(d, "ghoul", 3)
	_win(d)
	var g := _roundtrip(d)
	_check(JSON.stringify(g.loot) == JSON.stringify(d.loot), "the waiting dead survive a save")
	_check(typeof(g.loot["gold"]) == TYPE_INT and typeof(g.loot["foes"][0]["carries"][0]["chance"]) == TYPE_FLOAT, "with their numbers' types")
	var a := GamePlague.search(d)
	var b := GamePlague.search(g)
	_check(a == b and d.heir.gold == g.heir.gold and JSON.stringify(d.heir.diseases) == JSON.stringify(g.heir.diseases), "searching after a load turns out the same")
	_check(GamePlague.load_loot({"gold": 5, "foes": [{"id": "x", "carries": [{"disease": "no_such", "chance": 1.0}, "junk"]}, 3]}) == {"gold": 5, "item_chance": 0.0, "foes": [{"id": "x", "name": "", "carries": []}]}, "a bad save is cleaned")
	_check(GamePlague.load_loot(null).is_empty() and GamePlague.load_loot({}).is_empty(), "no loot loads empty")


# ---------------------------------------------------------------- toxins

func _test_coat_blade() -> void:
	for n in range(1, 6):
		var d := _fresh(50 + n)
		d.heir.level = 20
		d.heir.inventory = ["nightshade_oil", "nightshade_oil"]
		var b := _hunt(d, "ogre", n)
		for e in b.enemies:
			e["hp"] = 1000000
			e["max_hp"] = 1000000
			e["agi"] = 0
			e["atk"] = 0.0
		var turn := b.turn
		_check(b.can_coat("nightshade_oil") and not b.can_coat("willowbark_tonic"), "%d foes: a toxin can coat the blade, a tonic cannot" % n)
		b.coat_blade("nightshade_oil")
		_check(b.turn == turn and b.result == "", "%d foes: coating takes no turn" % n)
		_check(GameItems.count(d.heir, "nightshade_oil") == 1 and int(b.coating["hits"]) == int(GamePlague.setting("coat_hits")), "%d foes: one toxin spent, the blade coated" % n)
		_check(not b.can_coat("nightshade_oil"), "%d foes: no second coat on a coated blade" % n)
		var hits := 0
		var guard := 0
		while not b.coating.is_empty() and guard < 30:
			guard += 1
			b.attack(hits % n)
			hits += 1
		_check(b.coating.is_empty() and hits == int(GamePlague.setting("coat_hits")), "%d foes: the coating lasts %d blows" % [n, hits])
		var venomed := b.log.filter(func(l): return "Venom gets into" in str(l)).size()
		_check(venomed == hits, "%d foes: each blade blow envenoms its foe (%d)" % [n, venomed])
		_check(b.log.any(func(l): return "is spent" in str(l)), "%d foes: the coating's end is told" % n)
		d.battle = null
	# Pure spells do not carry it; the venom ticks.
	var m := _fresh(60, "mage")
	m.heir.level = 30
	m.heir.inventory = ["wyvern_venom"]
	var b := _hunt(m, "ogre", 1)
	b.enemies[0]["hp"] = 1000000
	b.enemies[0]["max_hp"] = 1000000
	b.enemies[0]["agi"] = 0
	b.enemies[0]["atk"] = 0.0
	b.coat_blade("wyvern_venom")
	var mag := GameBattle.unit_skill_of(m.heir, "damage")
	m.heir.mp = 100000
	if str(m.heir.cls()["skills"][mag].get("stat", "str")) == "mag":
		b.use_skill(mag, 0)
		_check(int(b.coating["hits"]) == int(GamePlague.setting("coat_hits")) and not b.has_status("enemy:0", "venom"), "a spell does not carry the blade's venom")
	b.attack(0)
	_check(b.has_status("enemy:0", "venom"), "a blade blow does")
	var hp := int(b.enemies[0]["hp"])
	b.defend()
	_check(int(b.enemies[0]["hp"]) < hp, "the venom eats at the foe on its turn")
	var tick := hp - int(b.enemies[0]["hp"])
	_check(tick >= int(1000000 * 0.06 * 0.9), "wyvern venom takes about 6%% of max HP a turn (%d)" % tick)


func _test_toxin_backfire() -> void:
	var d := _fresh(61, "warrior", "human")
	d.heir.level = 10
	d.heir.inventory = ["nightshade_oil"]
	var b := _hunt(d, "wolf", 1)
	b.coat_blade("nightshade_oil")
	_check(b.exposures.size() == 1 and b.exposures[0]["disease"] == "nightshade_palsy" and float(b.exposures[0]["chance"]) <= 0.02, "the toxin's handling is an exposure: %s" % str(b.exposures))
	b.exposures[0]["chance"] = 1.0
	var msgs := _win(d)
	_check(GameDisease.has(d.heir, "nightshade_palsy"), "a sure backfire makes the heir sick when the battle is settled")
	_check(msgs.any(func(m): return "Poison gets into" in str(m)), "and is told on the result screen: %s" % str(msgs))


# ---------------------------------------------------------------- vials

func _test_vials() -> void:
	for n in range(1, 6):
		var d := _fresh(70 + n, "warrior", "human")
		d.heir.level = 40
		d.heir.inventory = ["plague_vial"]
		var b := _hunt(d, "ogre", n)
		for e in b.enemies:
			e["hp"] = 1000000
			e["max_hp"] = 1000000
			e["atk"] = 0.0
		var ab := GamePlague.vial_ability("plague_vial")
		var aim := 0
		for i in n:
			if b.aoe_targets(ab, -1, i).size() > b.aoe_targets(ab, -1, aim).size():
				aim = i
		var caught := b.aoe_targets(ab, -1, aim)
		_check(b.can_throw("plague_vial") and not b.can_throw("nightshade_oil"), "%d foes: a vial can be thrown, a toxin cannot" % n)
		var turn := b.turn
		b.throw_vial("plague_vial", aim)
		_check(b.turn == turn + 1, "%d foes: throwing takes the turn" % n)
		_check(GameItems.count(d.heir, "plague_vial") == 0, "%d foes: the vial is spent" % n)
		var sick := 0
		var weak := 0
		for i in n:
			if b.has_status(GameBattle.enemy_ref(i), "plague_fever"):
				sick += 1
			if b.has_status(GameBattle.enemy_ref(i), "weaken"):
				weak += 1
		_check(sick == caught.size() and weak == caught.size() and caught.size() == n, "%d foes: every foe in the burst sickens and weakens (%d of %d caught)" % [n, sick, caught.size()])
		_check(b.exposures.size() == 1 and float(b.exposures[0]["chance"]) <= 0.02 and b.exposures[0]["source"] == "vial", "%d foes: the thrower risks the splash" % n)
		var hp := int(b.enemies[0]["hp"])
		b.defend()
		_check(int(b.enemies[0]["hp"]) < hp, "%d foes: the fever eats at a foe" % n)
		d.battle = null
	# Aimed where it reaches no one, it is not thrown.
	var e := _fresh(80)
	e.heir.inventory = ["plague_vial"]
	var b := _hunt(e, "wolf", 1)
	b.enemies[0]["hp"] = 0
	b.throw_vial("plague_vial", 0)
	_check(GameItems.count(e.heir, "plague_vial") == 1, "no living foe: the vial stays in the pack")
	# A legend shrugs off most of a max-HP tick.
	var l := _fresh(81)
	l.heir.level = 60
	l.heir.inventory = ["grey_veil_vial", "grey_veil_vial"]
	var foes := [l._make_enemy(GameCombat.creature_def("hollow_king"), 1.0, 1.0, 60)]
	b = l._begin_battle(foes, "legend")
	b.throw_vial("grey_veil_vial", 0)
	var inst := b.status_of("enemy:0", "grey_choke")
	if not inst.is_empty():
		_check(float(inst["amount"]) < float(b.enemies[0]["max_hp"]) * 0.06 * 0.5, "a legend takes a reduced tick")
	_check(b.log.any(func(x): return "Vial of the Grey Veil" in str(x)), "the throw is told")


# ---------------------------------------------------------------- tactics

func _test_tactics() -> void:
	# A long fight: auto-battle coats the blade at once.
	var d := _fresh(90)
	d.heir.level = 30
	d.heir.full_heal()
	d.heir.inventory = ["nightshade_oil"]
	var b := _hunt(d, "ogre", 3)
	for e in b.enemies:
		e["hp"] = int(e["hp"]) * 4
		e["max_hp"] = e["hp"]
	GameTactics.auto_turn(b)
	_check(GameItems.count(d.heir, "nightshade_oil") == 0, "a long fight: the autopilot coats its blade")
	_check(not b.events.is_empty() and b.events[0]["type"] == "coat" and b.events.size() > 1, "auto-battle keeps the coating's event ahead of the blow, so it is shown: %s" % str(b.events.map(func(e): return e["type"])))
	d.battle = null
	# A quick one: it keeps the toxin.
	d.heir.inventory = ["nightshade_oil"]
	b = _hunt(d, "wolf", 1)
	b.enemies[0]["hp"] = 1
	GameTactics.auto_turn(b)
	_check(GameItems.count(d.heir, "nightshade_oil") == 1, "a one-blow fight: the toxin is kept")
	d.battle = null
	# A vial into a crowd of hard foes, not at one weak one.
	var thrown := 0
	var kept := 0
	for k in 4:
		var x := _fresh(91 + k, ["warrior", "rogue", "ranger", "monk"][k])
		x.heir.level = 40
		x.heir.full_heal()
		x.heir.inventory = ["plague_vial"]
		b = _hunt(x, "ogre", 4)
		for e in b.enemies:
			e["hp"] = int(e["hp"]) * 3
			e["max_hp"] = e["hp"]
		var guard := 0
		while not b.is_over() and guard < 6:
			guard += 1
			GameTactics.auto_turn(b)
		if GameItems.count(x.heir, "plague_vial") == 0:
			thrown += 1
		x.battle = null
		x.heir.full_heal()
		x.heir.inventory = ["plague_vial"]
		b = _hunt(x, "wolf", 1)
		guard = 0
		while not b.is_over() and guard < 50:
			guard += 1
			GameTactics.auto_turn(b)
		if GameItems.count(x.heir, "plague_vial") == 1:
			kept += 1
		x.battle = null
	_check(thrown >= 3, "a vial goes into a crowd of hard foes (%d of 4)" % thrown)
	_check(kept == 4, "and is kept against a single wolf (%d of 4)" % kept)
	# A thrown vial starts aimed where it catches the most foes, the current target on a tie.
	var z := _fresh(98)
	z.heir.level = 40
	b = _hunt(z, "ogre", 5)
	var vab := GamePlague.vial_ability("plague_vial")
	for i in 5:
		var aim := GamePlague.best_aim(b, vab, i)
		var most := 0
		for j in 5:
			most = maxi(most, b.aoe_targets(vab, -1, j).size())
		_check(b.aoe_targets(vab, -1, aim).size() == most, "aim from foe %d catches the most foes (%d)" % [i, most])
		if b.aoe_targets(vab, -1, i).size() == most:
			_check(aim == i, "a target that already catches the most stays the aim")
	z.battle = null
	# A plan with a vial is carried out by act().
	var y := _fresh(99)
	y.heir.level = 40
	_party(y, ["bren_cask"])
	y.heir.inventory = ["plague_vial"]
	b = _hunt(y, "ogre", 3)
	var o: Dictionary = GameTactics.options(b, -1).filter(func(op): return str(op.get("item", "")) != "")[0]
	GameTactics.act(b, GameTactics._plan(o, 1))
	_check(GameItems.count(y.heir, "plague_vial") == 0 and b.has_status("enemy:1", "plague_fever"), "act() throws a planned vial")
	_check(GameTactics.options(b, 0).all(func(op): return str(op.get("item", "")) == ""), "companions never throw the heir's vials")


## Carrying a vial must not make a decision much dearer.
func _test_tactics_cost() -> void:
	var times := {}
	for carry in [false, true]:
		var d := _fresh(100)
		d.heir.level = 40
		d.heir.inventory = ["plague_vial", "grey_veil_vial"] if carry else []
		var b := _hunt(d, "ogre", 5)
		var t0 := Time.get_ticks_usec()
		for i in 200:
			GameTactics.choose(b, -1)
		times[carry] = float(Time.get_ticks_usec() - t0) / 200.0
		d.battle = null
	_check(float(times[true]) < float(times[false]) * 2.0 + 200.0, "a decision with two vials costs %.0fus against %.0fus" % [times[true], times[false]])


# ---------------------------------------------------------------- companions

func _party(d: GameDynasty, ids: Array = ["bren_cask", "sister_oriel"]) -> void:
	d.heir.gold = 1000000
	for id in ids:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": d.heir.level, "gen": d.gen,
			"due": 0.0, "battles": 0, "hired_gen": d.gen, "diseases": []})
		d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": d.gen, "first_gen": d.gen, "battles": 0,
			"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	d.party.rest(d)


func _test_companion_state() -> void:
	var d := _fresh(110)
	d.heir.level = 20
	_party(d)
	var m: Dictionary = d.party.members[0]
	var well := d.party.unit(d, m).max_hp()
	GameDisease.infect(d.party.sick_body(d, m), "rat_plague", "corpse", 1)
	_check(GameDisease.has(d.party.unit(d, m), "rat_plague"), "a companion's sickness is theirs to keep")
	_check(d.party.unit(d, m).max_hp() < well, "and lowers their health in battle")
	_hunt(d, "wolf", 1)
	_check(GameDisease.has(d.battle.allies[0], "rat_plague") and not GameDisease.has(d.battle.allies[1], "rat_plague"), "a sick companion fights sick")
	d.battle = null
	(m["diseases"][0] as Dictionary)["years_in_stage"] = 0.3125
	var g := _roundtrip(d)
	_check(JSON.stringify(g.party.members[0]["diseases"]) == JSON.stringify(m["diseases"]), "a companion's sickness survives a save")
	_check(typeof(g.party.members[0]["diseases"][0]["stage"]) == TYPE_INT, "with its stage an int")
	_check(JSON.stringify(g.to_dict()) == JSON.stringify(d.to_dict()), "a second save is identical")
	for i in 30:
		for x in [d, g]:
			if x.state == "life":
				GameBot.step(x)
			elif x.state == "succession":
				x.choose_heir(0)
	_check(JSON.stringify(g.to_dict()) == JSON.stringify(d.to_dict()), "30 steps later, the loaded game played out the same")
	d.party.dismiss(d, m["id"])
	_check(not d.party.has_member(m["id"]), "a dismissed companion takes their sickness home")


func _test_companion_contagion() -> void:
	# Measured odds: the heir passes a sickness to a companion at its yearly companion rate.
	var n := 0
	var trials := 600
	var rate := GameDisease.contagion_chance("rat_plague", "companion")
	for i in trials:
		var d := _fresh(200 + i)
		d.heir.level = 10
		_party(d, ["bren_cask"])
		GameDisease.infect(d.heir, "rat_plague", "corpse")
		var msgs: Array = []
		GamePlague.party_years(d, d.party, 1.0, msgs)
		if not d.party.members.is_empty() and GameDisease.has(d.party.sick_body(d, d.party.members[0]), "rat_plague"):
			n += 1
	_check(float(n) / float(trials) <= rate * 3.0 + 0.01, "heir to companion: about %.3f a year, measured %.3f" % [rate, float(n) / float(trials)])
	# With the odds forced up, it spreads both ways and is told.
	var dz: Dictionary = GameDisease.def("blister_pox")
	var keep: float = dz["contagion"]["companion"]
	dz["contagion"]["companion"] = 1.0
	var d := _fresh(300)
	d.heir.level = 10
	_party(d, ["bren_cask", "sister_oriel"])
	GameDisease.infect(d.party.sick_body(d, d.party.members[0]), "blister_pox", "corpse")
	var msgs: Array = []
	var nat: Array = dz["cures"]["natural"]
	dz["cures"]["natural"] = [0.0, 0.0, 0.0]
	GamePlague.party_years(d, d.party, 1.0, msgs)
	_check(GameDisease.has(d.heir, "blister_pox"), "a companion passes it to the heir")
	_check(GameDisease.has(d.party.sick_body(d, d.party.members[1]), "blister_pox"), "and to the other companion")
	_check(msgs.any(func(l): return "catches Blister Pox from" in str(l)), "and it is told: %s" % str(msgs))
	dz["contagion"]["companion"] = keep
	dz["cures"]["natural"] = nat
	# Not catching: lockjaw never spreads.
	var e := _fresh(301)
	_party(e, ["bren_cask"])
	GameDisease.infect(e.heir, "lockjaw", "bargain")
	for i in 50:
		GamePlague.party_years(e, e.party, 1.0, [])
	_check(not GameDisease.has(e.party.sick_body(e, e.party.members[0]), "lockjaw"), "lockjaw is not catching")


func _test_companion_death() -> void:
	var d := _fresh(310)
	d.heir.level = 10
	_party(d, ["bren_cask"])
	var m: Dictionary = d.party.members[0]
	var nm: String = m["name"]
	var dz: Dictionary = GameDisease.def("grave_rot")
	var keep: float = dz["end"]["death_per_year"]
	dz["end"]["death_per_year"] = 1.0
	GameDisease.infect(d.party.sick_body(d, m), "grave_rot", "corpse", 2)
	var msgs: Array = []
	d.party.on_years(d, 1.0, msgs)
	dz["end"]["death_per_year"] = keep
	_check(not d.party.has_member("bren_cask"), "a deadly last stage takes a companion")
	_check(msgs.any(func(l): return nm in str(l) and "Grave Rot" in str(l)), "the journal tells it: %s" % str(msgs))
	_check(d.journal.any(func(l): return nm in str(l) and "Grave Rot" in str(l)), "in the house's journal")
	var rec: Dictionary = d.party.history["bren_cask"]
	var past: Dictionary = (rec["past"] as Array).back()
	_check(rec["status"] == "dead" and past["end"] == "sick" and "Grave Rot" in str(past["cause"]) and past["name"] == nm, "the past hires record it: %s" % str(past))
	var g := _roundtrip(d)
	_check(JSON.stringify(g.party.history["bren_cask"]) == JSON.stringify(rec), "and keep it through a save")
	var Tavern := preload("res://ui/play/tavern_panel.gd")
	var tp = Tavern.new()
	tp.dynasty = d
	_check(tp._past_line("bren_cask", past).find("Grave Rot") >= 0, "the tavern's record reads it: %s" % tp._past_line("bren_cask", past))
	var talk: String = tp._rumour("bren_cask")
	_check("Grave Rot" in talk and not "old age" in talk, "the barkeep tells it too: %s" % talk)
	var heir_line: String = tp._heritage("bren_cask")
	_check("Grave Rot" in heir_line and not "fell for" in heir_line, "and so does the successor's card: %s" % heir_line)
	tp.free()


func _test_companion_cure() -> void:
	var d := _fresh(320)
	d.heir.level = 10
	d.world.visit("hearthmere")
	_party(d, ["bren_cask"])
	var m: Dictionary = d.party.members[0]
	GameDisease.infect(d.party.sick_body(d, m), "rat_plague", "corpse", 1)
	var cost := GameDisease.cure_price(d, "rat_plague", d.party.sick_body(d, m))
	_check(cost > GameDisease.cure_price(d, "rat_plague"), "a later stage costs more to cure")
	d.heir.gold = cost - 1
	var line := GamePlague.cure_companion(d, "bren_cask", "rat_plague")
	_check("ask" in line and GameDisease.has(d.party.sick_body(d, m), "rat_plague"), "not enough gold: %s" % line)
	d.heir.gold = cost
	line = GamePlague.cure_companion(d, "bren_cask", "rat_plague")
	_check(d.heir.gold == 0 and (m["diseases"] as Array).is_empty() and "cure" in line, "the temple cures a companion: %s" % line)
	d.world.visit("greenvale")
	GameDisease.infect(d.party.sick_body(d, m), "red_flux", "corpse")
	d.heir.gold = 100000
	_check("no temple" in GamePlague.cure_companion(d, "bren_cask", "red_flux"), "no temple, no cure")
	d.world.visit("hearthmere")
	GameDisease.bot_tick(d)
	_check((m["diseases"] as Array).is_empty(), "the autopilot pays the temple to cure a companion")
	# The temple shows a cure row for the companion.
	var Shop := preload("res://ui/play/shop_panel.gd")
	GameDisease.infect(d.party.sick_body(d, m), "red_flux", "corpse")
	var sp = Shop.new()
	sp.dynasty = d
	_check(sp.has_method("_build_cures"), "the temple builds cure rows")
	sp.free()


func _test_old_saves() -> void:
	for tag in ["pr3_life", "pr4_life", "pr4_succession"]:
		var txt := FileAccess.get_file_as_string("res://tests/fixtures/old_save_%s.json" % tag)
		if txt == "":
			continue
		var raw: Dictionary = JSON.parse_string(txt)
		var d := GameDynasty.from_dict(raw)
		_check(d.loot.is_empty(), "%s: an old save has no dead waiting" % tag)
		for m in d.party.members:
			_check(m.has("diseases") and (m["diseases"] as Array).is_empty(), "%s: old companions are well" % tag)
		var j := JSON.stringify(d.to_dict())
		_check(JSON.stringify(GameDynasty.from_dict(JSON.parse_string(j)).to_dict()) == j, "%s round-trips" % tag)
	var d := _fresh(330)
	_party(d, ["bren_cask"])
	var raw := d.to_dict()
	raw.erase("loot")
	for m in raw["party"]["members"]:
		m.erase("diseases")
	var g := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(raw)))
	_check(g.loot.is_empty() and (g.party.members[0]["diseases"] as Array).is_empty(), "a save from before plague loads well")


func _run(seed_value: int) -> Array:
	var d := GameDynasty.new_game(seed_value, "", "warrior", "faetouched", "human")
	var old: Variant = _tune("infected_spawn", 0.5)
	var old2: Variant = _tune("infected_chance", 0.02)
	for i in 300:
		if d.state == "succession":
			d.choose_heir(0)
		GameBot.step(d)
	_tune("infected_spawn", old)
	_tune("infected_chance", old2)
	return [d.journal.duplicate(), JSON.stringify(d.to_dict())]


func _test_determinism() -> void:
	var a := _run(777)
	var b := _run(777)
	_check(a[0] == b[0] and a[1] == b[1], "same seed, same dead, same sickness, same saves")
	_check((a[0] as Array).any(func(l): return "Plague-touched" in str(l)), "plague-touched foes turned up")
	_check((a[0] as Array).any(func(l): return "searches the bodies" in str(l)), "the dead were searched")
	_check(_run(778)[1] != a[1], "another seed differs")


## Dismissing and hiring back the same holder is no cure: the sickness and the wounds come back.
func _test_companion_rehire() -> void:
	var d := _fresh(115)
	d.heir.level = 20
	d.heir.gold = 1000000
	var found := ""
	for pid in ["hearthmere", d.world.location]:
		d.world.visit(pid)
		for id in d.party.at_tavern(d, pid):
			if d.party.hire_block(d, id) == "":
				found = id
				break
		if found != "":
			break
	_check(found != "", "someone to hire")
	if found == "":
		return
	d.party.hire(d, found)
	var m: Dictionary = d.party.member(found)
	GameDisease.infect(d.party.sick_body(d, m), "rat_plague", "corpse", 2)
	m["hp"] = 1
	var was: String = JSON.stringify(m["diseases"])
	d.party.dismiss(d, found)
	var g := _roundtrip(d)
	for x in [d, g]:
		x.party.hire(x, found)
		var back: Dictionary = x.party.member(found)
		_check(JSON.stringify(back["diseases"]) == was, "a rehired companion is still sick: %s" % str(back["diseases"]))
		_check(int(back["hp"]) <= 2, "and still wounded: %d" % int(back["hp"]))
		_check(typeof(back["diseases"][0]["stage"]) == TYPE_INT, "with its stage an int")
	_check(JSON.stringify(g.to_dict()) == JSON.stringify(d.to_dict()), "a saved dismissal brings back the same companion")
	# Years away mend wounds but not sickness.
	d.party.dismiss(d, found)
	d.world.year += 5.0
	d.party.hire(d, found)
	var later: Dictionary = d.party.member(found)
	_check(int(later["hp"]) > 2 and GameDisease.has(d.party.unit(d, later), "rat_plague"), "years away mend the wounds, not the plague")
	# A new holder of the role starts healthy.
	d.party.dismiss(d, found)
	var rec: Dictionary = d.party.history[found]
	d.party._close_line(d, found, {"name": rec["name"], "end": "died", "age": 70, "year": 1, "gen": d.gen, "served": false})
	_check(not rec.has("away"), "a closed line forgets the old holder's sickness")
