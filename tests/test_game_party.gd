## Companions: data, hire/dismiss/rehire, upkeep and walking out, level sync, rest, succession,
## battles with allies (acting, being targeted, KO, death or recovery), message order, save/load
## (old saves, mid-run continuity), autopilot and scaling from level 1 to 5000, gen 1 to 300.
## Run: godot --headless --path . -s res://tests/test_game_party.gd
extends SceneTree

const Tavern := preload("res://ui/play/tavern_panel.gd")

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _new(seed_val: int = 77) -> GameDynasty:
	var d := GameDynasty.new_game(seed_val, "Aldo", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


func _init() -> void:
	GameData.load_all()
	test_data()
	test_hire_dismiss()
	test_requirements()
	test_upkeep()
	test_level_sync_and_rest()
	test_battle_allies()
	test_targeting()
	test_ko_outcomes()
	test_ally_heals_and_drain()
	test_battle_rules()
	test_fallen_ally_sheds_foe_hp()
	test_party_never_riskier()
	test_message_order()
	test_succession()
	test_save_load()
	test_bot()
	test_scaling()
	test_determinism()
	test_save_load_continuity()
	print("party tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func test_data() -> void:
	ok(GameData.companions.size() >= 10 and GameData.companions.size() <= 12, "10-12 companions authored")
	var hybrid := false
	for c in GameData.companions:
		for key in ["id", "name", "race", "class", "personality", "where", "fee", "upkeep", "requires"]:
			ok(c.has(key), "%s has %s" % [c.get("id", "?"), key])
		ok(GameData.races.has(c["race"]), "race exists for %s" % c["id"])
		ok(GameData.classes.has(c["class"]), "class exists for %s" % c["id"])
		hybrid = hybrid or GameData.classes[c["class"]].has("parents")
		for w in c["where"]:
			ok("tavern" in GameWorld.place(w).get("services", []), "%s drinks at a tavern town (%s)" % [c["id"], w])
			ok(not GameParty.tavern(w).is_empty(), "tavern described for %s" % w)
		for place_id in c["requires"].get("visited", []):
			ok(not GameWorld.place(place_id).is_empty(), "%s requires a real place" % c["id"])
	ok(hybrid, "some companions follow hybrid classes")
	for town in ["hearthmere", "ironford", "kingshold", "brinehaven"]:
		ok(GameData.companions.any(func(c): return town in c["where"]), "someone drinks in %s" % town)
	# The Rift-gated legend costs the most, so she must outlast every other hireling and outhit Bren.
	for lg in [[45, 300], [5000, 300], [99999, 999]]:
		var warden := GameParty.build_unit("pale_warden", lg[0], lg[1])
		var bren := GameParty.build_unit("bren_cask", lg[0], lg[1])
		ok(warden.attack_power() > bren.attack_power(), "the Pale Warden outhits Bren at L%d" % lg[0])
		for c in GameData.companions:
			if c["id"] != "pale_warden":
				ok(warden.max_hp() > GameParty.build_unit(c["id"], lg[0], lg[1]).max_hp(), "the Pale Warden outlasts %s at L%d" % [c["id"], lg[0]])


func test_hire_dismiss() -> void:
	var d := _new()
	var p := d.party
	ok(d.world.location == "hearthmere", "starts in Hearthmere")
	var here := p.available_here(d)
	ok("bren_cask" in here and "maddy_thorn" in here, "Bren and Maddy available at level 1")
	ok("sister_oriel" not in here, "Oriel locked below level 5")
	ok(p.locked_reason(d, "sister_oriel").find("level 5") >= 0, "lock reason names the level")
	d.heir.gold = 0
	ok(p.hire_block(d, "bren_cask").begins_with("Not enough gold"), "cannot hire without gold")
	ok(p.hire(d, "bren_cask").begins_with("Not enough gold") and p.members.is_empty(), "failed hire changes nothing")
	d.heir.gold = 1000
	var fee := p.fee(d, "bren_cask")
	ok(fee == int(round(40.0 * GameData.enemy_scale(d.gen))), "fee scales with enemy_scale")
	var text := p.hire(d, "bren_cask")
	ok(p.members.size() == 1 and d.heir.gold == 1000 - fee, "hire charges the fee")
	ok(text.find("joins") >= 0 and d.journal.back() == text, "hire is in the journal: %s" % text)
	ok(p.hire_block(d, "bren_cask").find("already rides") >= 0, "cannot hire a member twice")
	p.hire(d, "maddy_thorn")
	ok(p.members.size() == 2, "two hired")
	ok(GameParty.max_size() == 3, "a party holds three companions")
	d.heir.level = 6
	ok(p.hire(d, "sister_oriel").contains("joins") and p.members.size() == 3, "a third joins")
	d.world.visit("brinehaven")
	ok(p.hire_block(d, "grull_one_tusk") == "The party is full (3).", "party cap enforced: %s" % p.hire_block(d, "grull_one_tusk"))
	ok(p.hire(d, "grull_one_tusk") != "" and p.members.size() == 3 and not p.has_member("grull_one_tusk"), "a fourth is refused")
	d.world.visit("hearthmere")
	ok("bren_cask" not in p.available_here(d), "members are not offered again")
	text = p.dismiss(d, "bren_cask")
	ok(p.members.size() == 2 and p.history["bren_cask"]["status"] == "dismissed", "dismissed goes home")
	ok(text.find("paid off") >= 0, "dismissal is announced")
	ok(p.fee(d, "bren_cask") == 0, "rehire is free")
	var g := d.heir.gold
	text = p.hire(d, "bren_cask")
	ok(p.members.size() == 3 and d.heir.gold == g, "rehired for free")
	ok(text.find("asks no fee") >= 0, "free rehire is announced")
	ok(p.history["bren_cask"]["status"] == "serving", "status serving after rehire")
	ok(p.hire_block(d, "hulda_stonebrow").find("does not drink here") >= 0, "Ironford companion not in Hearthmere")
	ok(p.dismiss(d, "hulda_stonebrow") == "No such companion.", "cannot dismiss a stranger")
	d.world.location = "greenvale"
	ok(p.available_here(d).is_empty(), "no tavern in the wilds")


func test_requirements() -> void:
	var d := _new(70)
	var p := d.party
	d.heir.gold = 100000
	d.heir.level = 20
	d.world.visit("ironford")
	ok(p.locked_reason(d, "varn_deepdelver").find("Deepstone Halls") >= 0, "Varn waits for a Deepstone visit")
	d.world.visited.append("deepstone_halls")
	ok(p.locked_reason(d, "varn_deepdelver") == "", "Varn talks once the house has been to Deepstone")
	ok(p.hire_block(d, "varn_deepdelver") == "", "Varn hireable in Ironford")
	d.world.visit("kingshold")
	ok(p.locked_reason(d, "ysolde_marrow") == "Not yet in this Age.", "Ysolde waits for her generation")
	d.gen = 300
	d.heir.level = 50
	ok(p.locked_reason(d, "pale_warden").find("deed") >= 0, "the Pale Warden waits for the Rift")
	d.set_flag("rift_open")
	ok(p.locked_reason(d, "pale_warden") == "", "the Pale Warden comes once the Rift is open")
	ok("pale_warden" in p.available_here(d), "offered in Kingshold")
	# She keeps pace with the Rift chain: once a house opens it she is in this age, whenever that is.
	var rift_gen := 1
	for q in GameData.quests:
		if q.get("chain", "") == "rift":
			rift_gen = maxi(rift_gen, int(q["requires"].get("min_gen", 1)))
	var w := _new(71)
	w.world.visit("kingshold")
	w.gen = rift_gen
	w.heir.gen = rift_gen
	w.heir.level = 10
	w.set_flag("rift_open")
	ok(w.party.locked_reason(w, "pale_warden").begins_with("Wants an heir of level"), "after the Rift opens at gen %d only her level gate remains (%s)" % [rift_gen, w.party.locked_reason(w, "pale_warden")])
	var hint: String = GameParty.def("pale_warden")["hint"]
	ok(not hint.contains("waiting for the Rift"), "her rumour does not claim the Rift is still sealed: " + hint)
	w.heir.level = 45
	ok(w.party.locked_reason(w, "pale_warden") == "", "she rides with a level-45 heir from gen %d" % rift_gen)


func test_upkeep() -> void:
	var d := _new(78)
	var p := d.party
	d.heir.gold = 1000
	p.hire(d, "bren_cask")
	p.hire(d, "maddy_thorn")
	var g := d.heir.gold
	var msgs: Array = []
	p.on_years(d, 4.0, msgs)
	ok(d.heir.gold == g - p.upkeep_total(d) * 4, "upkeep paid per year (%d -> %d)" % [g, d.heir.gold])
	ok(msgs.is_empty(), "no messages when wages are paid")
	p.on_years(d, 0.25, msgs)
	p.on_years(d, 0.25, msgs)
	ok(float(p.members[0]["due"]) > 0.0 and float(p.members[0]["due"]) < 1.0, "part-year upkeep accrues")
	g = d.heir.gold
	d.work()
	ok(d.heir.gold > g, "work still pays with a party")
	d.heir.gold = 0
	msgs = []
	d._pass_years(2.0, msgs)
	ok(p.members.is_empty(), "unpaid companions leave")
	var outs := msgs.filter(func(m): return str(m).find("walks out") >= 0)
	ok(outs.size() == 2, "each walk-out is announced: %s" % str(msgs))
	ok(d.journal.any(func(l): return str(l).find("Wages go unpaid and Bren Cask walks out") >= 0), "walking out is in the journal")
	ok(p.history["bren_cask"]["status"] == "left" and p.fee(d, "bren_cask") > 0, "walked-out companion wants a fee again")
	# The gold a house has is spent before anyone walks.
	var d2 := _new(79)
	d2.heir.gold = 1000
	d2.party.hire(d2, "bren_cask")
	d2.heir.gold = 1
	d2.party.on_years(d2, 1.0, [])
	ok(d2.party.members.size() == 1 and d2.heir.gold == 0, "a single year's wage is paid with the last coin")


func test_level_sync_and_rest() -> void:
	var d := _new(79)
	var p := d.party
	d.heir.gold = 1000
	p.hire(d, "bren_cask")
	var m: Dictionary = p.members[0]
	var hp1 := int(m["hp"])
	var u1 := p.unit(d, m)
	ok(u1.level == d.heir.level and u1.hp == u1.max_hp(), "hired at heir level, full health")
	ok(u1.traits.is_empty() and u1.class_id == "warrior" and u1.race_id == "human", "a companion is a traitless GameHeir of its race and class")
	d.heir.gain_xp(5000)
	ok(d.heir.level > 5, "heir levelled (%d)" % d.heir.level)
	ok(p.unit(d, m).level == d.heir.level, "companion level follows the heir at once")
	d.rest()
	ok(int(m["level"]) == d.heir.level, "companion record rebuilt to heir level")
	var u2 := p.unit(d, m)
	ok(u2.max_hp() > hp1 and u2.hp == u2.max_hp(), "stronger and fully rested (%d > %d)" % [u2.max_hp(), hp1])
	m["hp"] = u2.max_hp() / 2
	d.heir.gain_xp(20000)
	p.sync(d)
	var u3 := p.unit(d, m)
	ok(absf(float(u3.hp) / float(u3.max_hp()) - 0.5) < 0.02, "level sync keeps the wound share")
	m["hp"] = 1
	m["mp"] = 0
	d.rest()
	var u4 := p.unit(d, m)
	ok(u4.hp == u4.max_hp() and u4.mp == u4.max_mp(), "rest heals companions fully")
	m["hp"] = 1
	p.on_years(d, 1.0, [])
	ok(int(m["hp"]) > 1 and int(m["hp"]) < u4.max_hp(), "companions mend a little with each year")
	# A data bonus makes a companion stronger than a plain one of the same build.
	var knight := GameParty.build_unit("ser_aldric_vane", 30, 1)
	var plain := GameHeir.new()
	plain.class_id = "paladin"
	plain.level = 30
	plain.archetype_bonus = {"all_stats": float(GameData.bal("companion_power")) - 1.0, "hp": float(GameData.bal("companion_power")) - 1.0}
	ok(knight.max_hp() > plain.max_hp() and knight.stat("str") > plain.stat("str"), "data bonus applies")
	# Companions are hirelings: a step behind an untrained heir of the same build.
	var heir_like := GameHeir.new()
	heir_like.class_id = "warrior"
	heir_like.level = 30
	var bren := GameParty.build_unit("bren_cask", 30, 1)
	var ratio := bren.attack_power() / heir_like.attack_power()
	ok(absf(ratio - float(GameData.bal("companion_power"))) < 0.01, "companion_power sets their strength (%.2f)" % ratio)


func _fight_out(d: GameDynasty) -> Dictionary:
	var stats := {"ally_hits": 0, "on_ally": 0, "on_heir": 0, "ko": 0}
	var b := d.battle
	var guard := 0
	while not b.is_over() and guard < 200:
		guard += 1
		b.attack(b.first_target())
		for ev in b.events:
			if ev["type"] == "damage" and ev["side"] == "enemy" and int(ev.get("by", -1)) >= 0:
				stats["ally_hits"] += 1
			if ev["type"] in ["damage", "miss"] and ev["side"] == "ally":
				stats["on_ally"] += 1
			if ev["type"] in ["damage", "miss"] and ev["side"] == "player":
				stats["on_heir"] += 1
			if ev["type"] == "ko":
				stats["ko"] += 1
	return stats


func test_battle_allies() -> void:
	var d := _new(80)
	var p := d.party
	d.heir.gold = 5000
	d.heir.gain_xp(3000)
	p.hire(d, "bren_cask")
	p.hire(d, "maddy_thorn")
	var tot := {"ally_hits": 0, "on_ally": 0}
	for k in 8:
		d.heir.full_heal()
		p.rest(d)
		d.heir.gold = 5000
		for id in ["bren_cask", "maddy_thorn"]:
			if not p.has_member(id) and p.hire_block(d, id) == "":
				p.hire(d, id)
		d.start_hunt("hunt_hard")
		ok(d.battle.allies.size() == p.members.size(), "every member fights")
		for a in d.battle.allies:
			ok(a.level == d.heir.level and a.gen == d.gen, "allies fight at the heir's level and generation")
		var s := _fight_out(d)
		tot["ally_hits"] += s["ally_hits"]
		tot["on_ally"] += s["on_ally"]
		d.finish_battle()
		if d.state != "life":
			break
	ok(tot["ally_hits"] > 0, "allies strike enemies (%d)" % tot["ally_hits"])
	ok(tot["on_ally"] > 0, "enemies go for allies (%d)" % tot["on_ally"])
	ok(int(p.history.get("bren_cask", {}).get("battles", 0)) + int(p.member("bren_cask").get("battles", 0)) > 0, "battles counted")
	# Allies press the heir's target.
	var d3 := _new(83)
	d3.heir.gold = 5000
	d3.party.hire(d3, "bren_cask")
	d3.start_hunt("hunt_hard")
	var b3 := d3.battle
	for e in b3.enemies:
		e["hp"] = 100000
		e["max_hp"] = 100000
	var last := b3.enemies.size() - 1
	b3.attack(last)
	var ally_target := -1
	for ev in b3.events:
		if ev["type"] == "damage" and ev["side"] == "enemy" and int(ev.get("by", -1)) == 0:
			ally_target = int(ev["index"])
	ok(ally_target == last, "the ally strikes the heir's target (%d vs %d)" % [ally_target, last])
	# A battle with no party is the same as before.
	var d2 := _new(81)
	d2.start_hunt("hunt")
	ok(d2.battle.allies.is_empty(), "no allies without a party")
	ok(d2.battle.enemies.all(func(e): return e["hp"] == e["max_hp"]), "foes start whole")
	GameBot.fight(d2)
	ok(d2.battle == null, "battle without allies finishes")


## Foes split their blows between the heir and standing allies, favouring the heir.
func test_targeting() -> void:
	var on_heir := 0
	var on_allies := 0
	for k in 30:
		var d := _new(300 + k)
		d.heir.gold = 1000
		d.party.hire(d, "bren_cask")
		d.party.hire(d, "maddy_thorn")
		d.start_hunt("hunt_hard")
		var b := d.battle
		for e in b.enemies:
			e["hp"] = 100000
			e["max_hp"] = 100000
			e["atk"] = 0.0
		for t in 10:
			b.defend()
			for ev in b.events:
				if ev["type"] in ["damage", "miss"] and ev["side"] == "player":
					on_heir += 1
				if ev["type"] in ["damage", "miss"] and ev["side"] == "ally":
					on_allies += 1
		d.battle = null
	var share := float(on_heir) / float(on_heir + on_allies)
	var want := float(GameData.bal("companion_heir_target_chance"))
	ok(absf(share - want) < 0.05, "heir takes about %d%% of the blows (%.1f%% of %d)" % [int(want * 100.0), share * 100.0, on_heir + on_allies])
	# With three companions the rest of the blows spread over all of them, and none on the fallen.
	var per := [0, 0, 0]
	var heir_hits := 0
	var on_fallen := 0
	for k in 30:
		var d := _new(340 + k)
		d.heir.gold = 1000
		d.heir.level = 5
		for id in ["bren_cask", "maddy_thorn", "sister_oriel"]:
			d.party.hire(d, id)
		d.start_hunt("hunt_hard")
		var b := d.battle
		ok(b.allies.size() == 3, "three allies in battle")
		for e in b.enemies:
			e["hp"] = 100000
			e["max_hp"] = 100000
			e["atk"] = 0.0
		if k % 2 == 1:
			b.allies[1].hp = 0
		for t in 10:
			b.defend()
			for ev in b.events:
				if ev["type"] in ["damage", "miss"] and ev["side"] == "player":
					heir_hits += 1
				if ev["type"] in ["damage", "miss"] and ev["side"] == "ally":
					per[int(ev["ally"])] += 1
					if k % 2 == 1 and int(ev["ally"]) == 1:
						on_fallen += 1
		d.battle = null
	var total: int = heir_hits + per[0] + per[1] + per[2]
	ok(absf(float(heir_hits) / float(total) - want) < 0.05, "with three, the heir still takes about %d%% (%.1f%%)" % [int(want * 100.0), 100.0 * heir_hits / total])
	ok(per[0] > 0 and per[1] > 0 and per[2] > 0 and absi(per[0] - per[2]) < (per[0] + per[2]) / 4, "every companion draws blows (%s)" % str(per))
	ok(on_fallen == 0, "no blows on a companion already knocked out")


func test_ko_outcomes() -> void:
	var died := 0
	var recovered := 0
	for k in 60:
		var d := _new(200 + k * 7)
		var p := d.party
		d.heir.gold = 1000
		p.hire(d, "maddy_thorn")
		d.start_hunt("hunt")
		var b := d.battle
		ok(b.allies.size() == 1, "one ally in battle")
		var a: GameHeir = b.allies[0]
		a.hp = 1
		for e in b.enemies:
			e["hp"] = 100000
			e["max_hp"] = 100000
		var guard := 0
		var saw_ko := false
		while not b.is_over() and a.hp > 0 and guard < 80:
			guard += 1
			d.heir.hp = d.heir.max_hp()
			b.defend()
			for ev in b.events:
				if ev["type"] == "ko":
					saw_ko = true
		ok(a.hp == 0 and saw_ko, "ally knocked out with a ko event")
		ok(b.conscious_allies().is_empty() and not b.is_over(), "the fight goes on without the ally")
		var mp_before := a.mp
		d.heir.hp = d.heir.max_hp()
		b.defend()
		ok(a.hp == 0 and a.mp == mp_before, "a knocked-out ally stays down and does not act")
		ok(not b.events.any(func(ev): return int(ev.get("by", -1)) == 0), "no actions from the knocked-out ally")
		for e in b.enemies:
			e["hp"] = 1
		var g2 := 0
		while not b.is_over() and g2 < 10:
			g2 += 1
			d.heir.hp = d.heir.max_hp()
			b.attack(b.first_target())
		ok(b.result == "victory", "victory once enemies fall (got %s)" % b.result)
		var msgs := d.finish_battle()
		if p.members.is_empty():
			died += 1
			ok(p.history["maddy_thorn"]["status"] == "fallen", "fallen recorded")
			ok(p.history["maddy_thorn"]["fallen"] == ["Maddy Thorn"], "fallen name kept")
			ok(str(p.history["maddy_thorn"]["name"]).ends_with(" Thorn"), "kin named after the line: %s" % p.history["maddy_thorn"]["name"])
			ok(p.locked_reason(d, "maddy_thorn").begins_with("In mourning"), "fallen not hireable at once")
			ok(msgs.any(func(m): return str(m).find("does not rise") >= 0), "death message returned")
			ok(d.journal.any(func(l): return str(l).find("does not rise") >= 0), "death in the journal")
			d.gen += int(GameData.bal("companion_kin_gens"))
			ok(p.locked_reason(d, "maddy_thorn") == "", "kin hireable later")
			ok(p.fee(d, "maddy_thorn") > 0, "kin costs a fee")
		else:
			recovered += 1
			var m: Dictionary = p.members[0]
			var u := p.unit(d, m)
			var cap := float(GameData.bal("companion_ko_recover_hp")) + float(GameData.bal("companion_mend_per_year")) * float(d.years_for("hunt")) + 0.02
			ok(int(m["hp"]) >= 1 and float(m["hp"]) <= float(u.max_hp()) * cap, "recovers at low HP, then mends (%d/%d)" % [int(m["hp"]), u.max_hp()])
			ok(msgs.any(func(x): return str(x).find("carried from the field") >= 0), "recovery message")
	ok(died > 0 and recovered > died, "both KO outcomes seen, recovery more often (died %d, recovered %d)" % [died, recovered])
	print("  KO outcomes over 60: died %d, recovered %d" % [died, recovered])


func test_ally_heals_and_drain() -> void:
	var d := _new(90)
	var p := d.party
	d.heir.gold = 5000
	d.heir.level = 8
	p.hire(d, "sister_oriel")
	d.start_hunt("hunt")
	var b := d.battle
	for e in b.enemies:
		e["hp"] = 100000
		e["max_hp"] = 100000
		e["atk"] = 0.0
	d.heir.hp = int(d.heir.max_hp() * 0.2)
	var before := d.heir.hp
	var a: GameHeir = b.allies[0]
	var mp_before := a.mp
	b.defend()
	var healed := b.events.any(func(ev): return ev["type"] == "heal" and ev["side"] == "player" and int(ev.get("by", -1)) == 0)
	ok(healed and d.heir.hp > before, "cleric companion heals a hurt heir")
	ok(a.mp < mp_before and mp_before - a.mp <= GameBattle.unit_skill_cost(a, GameBattle.unit_skill_of(a, "heal")), "the heal costs the companion MP")
	ok(b.log.any(func(l): return str(l).find("Sister Oriel tends Aldo") >= 0), "the heal is logged")
	a.mp = 0
	d.heir.hp = int(d.heir.max_hp() * 0.2)
	b.defend()
	ok(b.events.any(func(ev): return ev["type"] == "damage" and ev["side"] == "enemy" and int(ev.get("by", -1)) == 0), "without MP the companion attacks instead")
	a.mp = a.max_mp()
	d.heir.hp = d.heir.max_hp()
	a.hp = 1
	b.defend()
	ok(not b.events.any(func(ev): return ev["type"] == "heal"), "a healthy heir is not healed, and companions do not heal themselves")
	ok(b.events.any(func(ev): return ev["type"] == "damage" and ev["side"] == "enemy" and int(ev.get("by", -1)) == 0), "a hurt companion keeps fighting")
	d.battle = null

	# Drain heals the companion by the HP actually taken, not the overkill.
	var heir := GameHeir.new()
	heir.name = "Aldo"
	heir.level = 20
	heir.full_heal()
	var foe := {"id": "wolf", "name": "Wolf", "hp": 5, "max_hp": 5, "atk": 0.0, "def": 0.0, "agi": 0, "element": "", "boss": false}
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var b2 := GameBattle.new(heir, [foe, foe.duplicate()], rng)
	var necro := GameParty.build_unit("ysolde_marrow", 20, 1)
	necro.hp = 10
	b2.allies = [necro]
	b2.defend()
	var drained := 0
	for ev in b2.events:
		if ev["type"] == "heal" and ev["side"] == "ally":
			drained += int(ev["amount"])
	var cap := int(ceil(5.0 * float(necro.cls()["skills"][0]["drain"])))
	ok(drained > 0 and drained <= cap, "drain heals from the HP removed (%d <= %d)" % [drained, cap])
	ok(b2.enemies[0]["hp"] == 0, "the drain struck the heir's target first")


func test_battle_rules() -> void:
	# Foes facing a party are hardier.
	var d := _new(95)
	d.heir.gold = 5000
	d.party.hire(d, "bren_cask")
	d.party.hire(d, "maddy_thorn")
	var foes := [d._make_enemy(GameData.creatures[1], 1.0, 1.0, 5)]
	var base_hp: int = foes[0]["max_hp"]
	var base_atk: float = foes[0]["atk"]
	var base_xp: int = foes[0]["xp"]
	d._begin_battle(foes, "hunt")
	var mult := 1.0 + float(GameData.bal("companion_foe_hp")) * 2.0
	var e0: Dictionary = d.battle.enemies[0]
	ok(e0["max_hp"] == int(round(base_hp * mult)) and e0["hp"] == e0["max_hp"], "foe HP grows with the party (%d -> %d)" % [base_hp, e0["max_hp"]])
	ok(float(e0["atk"]) == base_atk, "a party never makes a foe's blows heavier")
	ok(e0["xp"] == base_xp, "the spoils do not change")
	# The battle is lost only when the heir falls.
	var b := d.battle
	for a in b.allies:
		a.hp = 0
	ok(b.conscious_allies().is_empty(), "all allies down")
	d.heir.hp = d.heir.max_hp()
	b.defend()
	ok(b.result == "", "allies down is not a defeat")
	for a in b.allies:
		a.hp = a.max_hp()
	for e in b.enemies:
		e["atk"] = 1000000.0
	d.heir.hp = 1
	var g := 0
	while not b.is_over() and g < 20:
		g += 1
		b.defend()
	ok(b.result == "defeat", "the heir falling loses the battle even with allies standing")
	d.battle = null
	# Rewards stay with the heir.
	var d2 := _new(96)
	d2.heir.gold = 5000
	d2.party.hire(d2, "bren_cask")
	d2.start_hunt("hunt")
	var xp := 0
	var gold := 0
	for e in d2.battle.enemies:
		xp += int(e["xp"])
		gold += int(e["gold"])
		e["hp"] = 1
	d2.battle.attack(0)
	while not d2.battle.is_over():
		d2.battle.attack(d2.battle.first_target())
	var h := d2.heir
	gold = int(round(float(gold) * (1.0 + h.trait_total("luck") + h.trait_total("theft") * 0.3 + d2.echo_total("glory"))))
	var lv := h.level
	var xp0 := h.xp
	var msgs := d2.finish_battle()
	var want := "Victory! +%d XP, +%d gold." % [xp, gold]
	ok(msgs.has(want), "full rewards to the heir (%s): %s" % [want, str(msgs)])
	ok(h.level > lv or h.xp > xp0, "the XP is the heir's")
	ok(d2.party.unit(d2, d2.party.members[0]).level == h.level, "companion keeps pace after a level-up")
	# Fleeing takes the party along.
	var d3 := _new(97)
	d3.heir.gold = 5000
	d3.party.hire(d3, "bren_cask")
	d3.start_hunt("hunt")
	var fled := false
	for t in 40:
		if d3.battle.is_over():
			break
		for e in d3.battle.enemies:
			e["hp"] = 100000
			e["atk"] = 0.0
		d3.battle.flee()
		fled = d3.battle.result == "fled"
	ok(fled and d3.battle.log.back() == "Aldo and the party escape!", "the party escapes together")
	d3.finish_battle()
	ok(d3.party.members.size() == 1, "fleeing keeps the party")


## Foes are tougher only for the companions still standing: when one is knocked out, every living
## foe sheds that share and keeps the fraction of HP it had. Legends never scale with the party.
func test_fallen_ally_sheds_foe_hp() -> void:
	var d := _new(99)
	d.heir.gold = 5000
	d.heir.level = 5
	d.party.hire(d, "bren_cask")
	d.party.hire(d, "maddy_thorn")
	d.party.hire(d, "sister_oriel")
	var foes := [d._make_enemy(GameData.creatures[1], 1.0, 1.0, 5), d._make_enemy(GameData.creatures[1], 1.0, 1.0, 5)]
	var base: int = foes[0]["max_hp"]
	d._begin_battle(foes, "hunt")
	var b := d.battle
	var k := float(GameData.bal("companion_foe_hp"))
	ok(b.enemies[0]["max_hp"] == int(round(base * (1.0 + 3.0 * k))), "three companions: foes start with the party's share")
	b.enemies[0]["hp"] = int(b.enemies[0]["max_hp"] / 2)
	b.enemies[1]["hp"] = 0
	for i in 3:
		b.allies[i].hp = 1
		b.enemies[0]["atk"] = 1000000.0
		b.events = []
		var guard := 0
		while b.allies[i].hp > 0 and guard < 50:   # dodges are rolled; keep swinging until the blow lands
			guard += 1
			b._enemy_hit_ally(0, i)
		var up := 2 - i
		var want := int(round(base * (1.0 + float(up) * k)))
		var e0: Dictionary = b.enemies[0]
		ok(absi(int(e0["max_hp"]) - want) <= 1, "%d standing: foe max HP back to %d (got %d)" % [up, want, e0["max_hp"]])
		ok(absf(float(e0["hp"]) / float(e0["max_hp"]) - 0.5) < 0.01, "the foe keeps the share of HP it had (%d / %d)" % [e0["hp"], e0["max_hp"]])
		ok(b.enemies[1]["hp"] == 0 and b.enemies[1]["max_hp"] == int(round(base * (1.0 + 3.0 * k))), "a slain foe is left alone")
		var ko: Array = b.events.filter(func(ev): return ev["type"] == "ko")
		ok(ko.size() == 1 and float(ko[0].get("foe_scale", 1.0)) < 1.0, "the knock-out tells the screen how far the foes shrank")
	ok(is_equal_approx(b.foe_hp_mult, 1.0), "with the party down the foes are as tough as for a lone heir")
	d.battle = null
	# Legends are fought at full strength, band or no band.
	var g := _new(100)
	g.heir.gold = 5000
	g.heir.level = 15
	g.party.hire(g, "bren_cask")
	g.world.visit("whisperwood")
	var boss := g.available_boss()
	var lone: int = g._make_enemy(boss, 1.0, 1.0, int(boss["min_level"]))["max_hp"]
	g.start_legend()
	ok(g.battle.allies.size() == 1 and g.battle.enemies[0]["max_hp"] == lone, "a legend's HP ignores the party (%d)" % lone)
	g.battle = null


## Hiring help never makes the heir likelier to lose: a legend at its level, and a fresh heir's first
## hunts in a late era, fought by the autopilot alone and with two or three hirelings on the same seeds.
func test_party_never_riskier() -> void:
	var band := ["maddy_thorn", "bren_cask", "sister_oriel"]
	for spec in [["warrior", 300, 45, "deepstone_halls", "legend"], ["ranger", 1, 15, "whisperwood", "legend"], ["warrior", 150, 1, "hearthmere", "hunt"], ["mage", 1, 1, "hearthmere", "hunt"]]:
		var lost := [0, 0, 0]
		for size in [0, 2, 3]:
			for t in 40:
				var d := GameDynasty.new_game(7000 + t * 17, "T", spec[0], "faetouched", "human")
				d.pending_event = {}
				d.heir.traits = []
				d.heir.dormant = []
				d.gen = spec[1]
				d.heir.gen = spec[1]
				d.heir.level = spec[2]
				d.heir.potions = 3
				if spec[1] > 1:
					d.heir.equipment = {"weapon": "steel_sword", "armor": "chainmail", "trinket": "ring_of_vigor"}
				d.world.visit(spec[3])
				d.world.weather_id = "clear"
				for id in band.slice(0, size):
					d.party.members.append({"id": id, "name": id, "hp": 1, "mp": 0, "level": spec[2], "gen": spec[1], "due": 0.0, "battles": 0, "hired_gen": spec[1]})
				d.party.rest(d)
				d.heir.full_heal()
				if spec[4] == "legend":
					d.start_legend()
				else:
					d.start_hunt("hunt")
				var b := d.battle
				ok(b.allies.size() == size, "%d allies fight" % size)
				GameBot.fight(d)
				if b.result == "defeat":
					lost[[0, 2, 3].find(size)] += 1
		ok(lost[1] <= lost[0] + 2, "%s gen %d level %d %s: two hirelings lost %d of 40, alone %d" % [spec[0], spec[1], spec[2], spec[4], lost[1], lost[0]])
		ok(lost[2] <= lost[0] + 2, "%s gen %d level %d %s: three hirelings lost %d of 40, alone %d" % [spec[0], spec[1], spec[2], spec[4], lost[2], lost[0]])
		print("  %s gen %d L%d %s: lost alone %d, with two %d, with three %d (of 40)" % [spec[0], spec[1], spec[2], spec[4], lost[0], lost[1], lost[2]])


## A companion's fate is told after the battle's own result, in the returned lines and the journal.
func test_message_order() -> void:
	var saved := float(GameData.bal("companion_death_chance"))
	for chance in [1.0, 0.0]:
		GameData.balance["companion_death_chance"] = chance
		var d := _new(98)
		d.heir.gold = 1000
		d.party.hire(d, "bren_cask")
		d.start_hunt("hunt")
		var b := d.battle
		b.allies[0].hp = 0
		for e in b.enemies:
			e["hp"] = 1
		while not b.is_over():
			d.heir.hp = d.heir.max_hp()
			b.attack(b.first_target())
		var j0 := d.journal.size()
		var msgs := d.finish_battle()
		var key := "does not rise" if chance > 0.5 else "carried from the field"
		var at_win := -1
		var at_fate := -1
		for i in msgs.size():
			if str(msgs[i]).begins_with("Victory!"):
				at_win = i
			if str(msgs[i]).find(key) >= 0:
				at_fate = i
		var expect := at_win + 1
		if at_win >= 0 and expect < msgs.size() and str(msgs[expect]).begins_with("Level up"):
			expect += 1
		ok(at_win >= 0 and at_fate == expect, "companion fate follows the victory line: %s" % str(msgs))
		var journal := d.journal.slice(j0)
		var jw := journal.find(msgs[at_win])
		var jf := journal.find(msgs[at_fate])
		ok(jw >= 0 and jf > jw, "journal tells the victory first, then the companion (%d, %d)" % [jw, jf])
		ok(journal.count(msgs[at_fate]) == 1, "companion fate journaled once")
	GameData.balance["companion_death_chance"] = saved
	# A battle ended without a result still reports the companion's fate.
	var d2 := _new(99)
	d2.heir.gold = 1000
	d2.party.hire(d2, "maddy_thorn")
	d2.start_hunt("hunt")
	d2.battle.allies[0].hp = 0
	var msgs2 := d2.finish_battle()
	ok(msgs2.size() == 1 and d2.journal.back() == msgs2[0], "unfinished battle still reports the companion: %s" % str(msgs2))
	ok(d2.party.members.size() + int(d2.party.history["maddy_thorn"]["status"] == "fallen") == 1, "the companion was either carried off or fell")


func test_succession() -> void:
	var d := _new(91)
	var p := d.party
	d.heir.gold = 1000
	d.heir.gain_xp(20000)
	p.hire(d, "bren_cask")
	p.hire(d, "maddy_thorn")
	var lv := d.heir.level
	ok(lv > 10, "heir high level before death")
	p.hire(d, "sister_oriel")
	p.members[0]["hp"] = 1
	d._die("test")
	ok(d.state == "succession", "succession")
	ok(p.hire_block(d, "grull_one_tusk") == "No one hires in mourning.", "no hiring during succession")
	var msgs := d.choose_heir(0)
	ok(p.members.size() == 3, "companions stay with the family")
	for m in p.members:
		var u := p.unit(d, m)
		ok(u.level == d.heir.level and u.level == 1 and int(m["gen"]) == d.gen, "rebuilt to the new heir's level and gen")
		ok(u.hp == u.max_hp(), "fresh at succession")
	ok(msgs.has("Bren Cask, Maddy Thorn and Sister Oriel stay with the family and swear to serve %s." % d.heir.name), "succession message: %s" % str(msgs))
	var lines: Array = Tavern.summary_lines(d)
	var bren_age := int(p.age(d, "bren_cask"))
	ok(lines.size() == 3 and str(lines[0]).begins_with("Bren Cask (%d), Human Warrior Lv1  HP\u00a0" % bren_age), "summary line: %s" % str(lines))
	ok(str(lines[2]).begins_with("Sister Oriel (%d), Human Cleric Lv1" % int(p.age(d, "sister_oriel"))), "a third line for the third companion: %s" % str(lines))
	var u0 := p.unit(d, p.members[0])
	ok(str(lines[0]).ends_with("%d/%d" % [u0.hp, u0.max_hp()]), "summary line ends with HP now/max")
	ok(GameParty.names_text(["A"]) == "A" and GameParty.names_text(["A", "B"]) == "A and B" and GameParty.names_text([]) == "", "names read naturally")
	# One or two companions read the same as before.
	p.dismiss(d, "sister_oriel")
	var two: Array = []
	p.on_succession(d, two)
	ok(two == ["Bren Cask and Maddy Thorn stay with the family and swear to serve %s." % d.heir.name], "two names: %s" % str(two))
	p.dismiss(d, "maddy_thorn")
	var one: Array = []
	p.on_succession(d, one)
	ok(one == ["Bren Cask stays with the family and swears to serve %s." % d.heir.name], "one name: %s" % str(one))


func test_save_load() -> void:
	var d := _new(92)
	var p := d.party
	d.heir.gold = 5000
	d.heir.gain_xp(4000)
	p.hire(d, "bren_cask")
	p.hire(d, "maddy_thorn")
	p.dismiss(d, "maddy_thorn")
	p.hire(d, "maddy_thorn")
	p.on_years(d, 0.5, [])
	p.members[1]["hp"] = 7
	p.history["old_netta"] = {"name": "Young Wren", "status": "fallen", "gen": 1, "first_gen": 1, "battles": 3, "fallen": ["Old Netta"], "line": 1, "past": []}
	var text := JSON.stringify(d.to_dict())
	var d2 := GameDynasty.from_dict(JSON.parse_string(text))
	var p2 := d2.party
	ok(p2.members.size() == 2, "members survive save/load")
	ok(typeof(p2.members[0]["hp"]) == TYPE_INT and typeof(p2.members[0]["level"]) == TYPE_INT, "ints restored")
	ok(int(p2.members[1]["hp"]) == 7, "wounds survive save/load")
	ok(absf(float(p2.members[0]["due"]) - float(p.members[0]["due"])) < 0.0001, "owed upkeep survives")
	ok(p2.history["old_netta"]["fallen"] == ["Old Netta"] and p2.history["old_netta"]["name"] == "Young Wren", "history survives")
	ok(p2.display_name("old_netta") == "Young Wren", "kin name survives")
	ok(p2.fee(d2, "maddy_thorn") == p.fee(d, "maddy_thorn"), "fees survive")
	ok(JSON.stringify(d2.to_dict()["party"]) == JSON.stringify(d.to_dict()["party"]), "party round-trips exactly")
	d2.start_hunt("hunt")
	ok(d2.battle.allies.size() == 2, "loaded party fights")
	GameBot.fight(d2)
	# Old saves: no party key, the skeleton's empty party, members missing newer keys.
	var raw: Dictionary = JSON.parse_string(text)
	raw.erase("party")
	var old := GameDynasty.from_dict(raw)
	ok(old.party.members.is_empty() and old.party.history.is_empty(), "save without party loads")
	old.start_hunt("hunt")
	GameBot.fight(old)
	ok(old.state == "life" or old.state == "succession", "old save plays on")
	raw["party"] = {"members": []}
	ok(GameDynasty.from_dict(raw).party.history.is_empty(), "skeleton party loads")
	raw["party"] = {"members": [{"id": "bren_cask"}, {"id": "no_such_companion", "hp": 3}]}
	var thin := GameDynasty.from_dict(raw)
	ok(thin.party.members.size() == 1, "unknown companion dropped on load")
	var u := thin.party.unit(thin, thin.party.members[0])
	ok(u.level == thin.heir.level and u.hp >= 1, "a sparse member record still fights")
	ok(thin.party.members[0]["name"] == "Bren Cask", "name filled from data")
	raw["party"] = {"members": [], "history": {"maddy_thorn": {"status": "dismissed"}, "old_netta": {}}}
	var sparse := GameDynasty.from_dict(raw)
	ok(sparse.party.display_name("maddy_thorn") == "Maddy Thorn" and sparse.party.fee(sparse, "maddy_thorn") == 0, "sparse history: name from data, rehire still free")
	ok(int(sparse.party.history["old_netta"]["battles"]) == 0 and (sparse.party.history["old_netta"]["fallen"] as Array).is_empty(), "sparse history filled with defaults")
	# The house's records render from such a save.
	var tavern = Tavern.new()
	tavern.dynasty = sparse
	ok(tavern._records().size() == 2, "records list both past hires")
	tavern.free()
	# Malformed records: a fallen entry without names, an unknown id, a non-dictionary, a duplicate member.
	raw["party"] = {"members": [{"id": "bren_cask"}, {"id": "bren_cask", "hp": 2}],
		"history": {"grull_one_tusk": {"status": "fallen", "gen": 1}, "ghost": {"status": "left"}, "maddy_thorn": "junk"}}
	var odd := GameDynasty.from_dict(raw)
	ok(odd.party.members.size() == 1, "a duplicated member loads once")
	ok(odd.party.history.keys() == ["grull_one_tusk", "bren_cask"], "unknown and malformed history dropped, members get a record (%s)" % str(odd.party.history.keys()))
	ok(odd.party.history["grull_one_tusk"]["fallen"] == ["Grull One-Tusk"], "a fallen record always names the fallen")
	odd.world.location = "brinehaven"
	var t2 = Tavern.new()
	t2.dynasty = odd
	ok(t2._records().size() == 1 and str(t2._records()[0]).begins_with("Grull One-Tusk: fell"), "fallen record renders: %s" % str(t2._records()))
	ok(t2._rumour("grull_one_tusk").contains("Grull One-Tusk"), "mourning rumour renders")
	t2.free()


func test_bot() -> void:
	var d := _new(93)
	var p := d.party
	d.heir.gold = 10
	GameParty.bot_tick(d)
	ok(p.members.is_empty(), "bot does not hire when poor")
	d.heir.gold = 2000
	GameParty.bot_tick(d)
	ok(p.members.size() == 1, "bot hires when gold covers fee and reserve")
	GameParty.bot_tick(d)
	ok(p.members.size() == 2, "bot hires a second")
	GameParty.bot_tick(d)
	ok(p.members.size() == 2, "Hearthmere has no third for a level-1 heir")
	d.heir.level = 5
	GameParty.bot_tick(d)
	ok(p.members.size() == 3, "bot fills the party with a third (%s)" % str(p.members.map(func(m): return m["id"])))
	GameParty.bot_tick(d)
	ok(p.members.size() == 3, "bot respects the cap")
	# A third is hired only when its wages fit the reserve too.
	var e := _new(193)
	e.heir.level = 5
	e.heir.gold = 2000
	GameParty.bot_tick(e)
	GameParty.bot_tick(e)
	var third := ""
	for id in e.party.available_here(e):
		third = id
	var reserve := e.potion_price() * 3 + int(float(e.party.upkeep_total(e) + e.party.upkeep(e, third)) * float(GameData.bal("companion_bot_reserve_years")))
	e.heir.gold = e.party.fee(e, third) + reserve - 1
	GameParty.bot_tick(e)
	ok(e.party.members.size() == 2, "no third without the reserve (%d gold)" % e.heir.gold)
	e.heir.gold += 1
	GameParty.bot_tick(e)
	ok(e.party.members.size() == 3, "a third once it can be paid for")
	d.heir.gold = 1
	GameParty.bot_tick(d)
	ok(p.members.is_empty(), "bot dismisses when upkeep cannot be paid")
	ok(p.history.values().all(func(r): return r["status"] == "dismissed"), "bot dismissal is honourable")
	d.world.location = "greenvale"
	d.heir.gold = 2000
	GameParty.bot_tick(d)
	ok(p.members.is_empty(), "bot hires only at a tavern")


func test_scaling() -> void:
	for spec in [[1, 1], [1, 45], [300, 45], [300, 5000]]:
		var gen: int = spec[0]
		var level: int = spec[1]
		var d := _new(94)
		d.heir.gold = 100000000
		d.gen = gen
		d.heir.gen = gen
		d.heir.level = level
		d.heir.full_heal()
		d.party.hire(d, "bren_cask")
		d.party.hire(d, "maddy_thorn")
		var u := d.party.unit(d, d.party.members[0])
		ok(u.level == level and u.gen == gen, "companion at level %d gen %d" % [level, gen])
		var hp_ratio := float(u.max_hp()) / float(d.heir.max_hp())
		ok(hp_ratio > 0.4 and hp_ratio < 1.0, "companion HP keeps pace with the heir at L%d g%d (%.2f)" % [level, gen, hp_ratio])
		# Against an untrained heir of the same build the share is exact at every level and age.
		var plain := GameHeir.new()
		plain.class_id = "warrior"
		plain.race_id = "human"
		plain.gen = gen
		plain.level = level
		var power := float(GameData.bal("companion_power"))
		ok(absf(float(u.max_hp()) / float(plain.max_hp()) - power) < 0.02, "health share is companion_power at L%d g%d (%.3f)" % [level, gen, float(u.max_hp()) / float(plain.max_hp())])
		ok(absf(u.attack_power() / plain.attack_power() - power) < 0.01, "attack share is companion_power at L%d g%d" % [level, gen])
		var cost := GameBattle.unit_skill_cost(u, 0)
		ok(cost > 0 and cost <= u.max_mp(), "skills affordable at L%d (%d of %d MP)" % [level, cost, u.max_mp()])
		ok(d.party.fee(d, "sister_oriel") == int(round(70.0 * GameData.enemy_scale(gen))), "fee scales with the generation")
		ok(d.party.upkeep(d, "bren_cask") >= 1, "upkeep at least 1")
		d.start_hunt("hunt")
		GameBot.fight(d)
		ok(d.battle == null, "battle at L%d g%d finishes" % [level, gen])
		print("  L%d g%d: companion hp %d (heir %d), fee(oriel) %d, upkeep(bren) %d" % [level, gen, u.max_hp(), d.heir.max_hp(), d.party.fee(d, "sister_oriel"), d.party.upkeep(d, "bren_cask")])


func test_determinism() -> void:
	var a := _run_seed(4321)
	var b := _run_seed(4321)
	ok(a == b, "same seed, same story with companions")


func _run_seed(s: int) -> String:
	var d := _new(s)
	d.heir.gold = 400
	for i in 150:
		if d.state != "life":
			break
		GameBot.step(d)
	return JSON.stringify(d.to_dict())


func _steps(d: GameDynasty, n: int) -> void:
	for i in n:
		if d.state == "succession":
			d.choose_heir(0)
		elif d.state == "life":
			GameBot.step(d)


## Saving and loading mid-dynasty, party and all, changes nothing that follows.
func test_save_load_continuity() -> void:
	for s in [501, 503]:
		var a := _new(s)
		a.heir.gold = 3000
		var b := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
		_steps(a, 300)
		_steps(b, 120)
		ok(not b.party.members.is_empty() or not b.party.history.is_empty(), "seed %d has party state to save" % s)
		b = GameDynasty.from_dict(JSON.parse_string(JSON.stringify(b.to_dict())))
		_steps(b, 180)
		ok(a.gen > 1, "seed %d crossed a succession (gen %d)" % [s, a.gen])
		ok(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()), "seed %d: a save and load mid-run changes nothing" % s)
