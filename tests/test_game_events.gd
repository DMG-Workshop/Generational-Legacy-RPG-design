## Events with skill checks (GameEvents): check math, gating, every outcome of every event,
## event fights, triggers, the autopilot and save/load.
## godot --headless --path . -s res://tests/test_game_events.gd
extends SceneTree

var failures := 0
var checks := 0


func _check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL: ", what)


func _near(a: float, b: float, eps: float = 0.0001) -> bool:
	return absf(a - b) <= eps


func _fresh(class_id: String = "warrior", race_id: String = "human", p_seed: int = 4242) -> GameDynasty:
	var d := GameDynasty.new_game(p_seed, "Test", class_id, "warriors_steel", race_id)
	d.heir.traits = ["warriors_steel"]
	d.heir.dormant = []
	d.echoes = []
	return d


func _init() -> void:
	GameData.load_all()
	_test_content()
	_test_degrees()
	_test_bonus()
	_test_odds()
	_test_gating()
	_test_every_outcome()
	_test_event_fight()
	_test_explore_and_arrive()
	_test_save_load()
	_test_stale()
	_test_bot()
	_test_high_level()
	_test_determinism()
	_test_once_and_chains()
	_test_curse_removal()
	_test_text_and_journal()
	_test_gate_coverage()
	_test_validator()
	_test_old_save()
	print("%d checks, %d failures" % [checks, failures])
	print("ALL PASS" if failures == 0 else "TESTS FAILED")
	quit(1 if failures > 0 else 0)


func _test_content() -> void:
	var errs := GameEvents.validate()
	for e in errs:
		print("  content: ", e)
	_check(errs.is_empty(), "event data validates")
	_check(GameData.events.size() >= 30, "at least 30 events (%d)" % GameData.events.size())
	for l in GameData.world["locations"]:
		var n := GameData.events.filter(func(e): return GameEvents.place_matches(e, l)).size()
		_check(n >= 2, "%s has at least two events (%d)" % [l["id"], n])
	# Harmful traits only on critical failures, and only a few of them.
	var harmful := 0
	for ev in GameData.events:
		for c in ev["choices"]:
			for k in c["outcomes"]:
				var o: Dictionary = c["outcomes"][k]
				if o.has("add_trait") and GameEvents.is_harmful_trait(o["add_trait"]):
					harmful += 1
					_check(k == "crit_failure", "%s: harmful trait only on a critical failure" % ev["id"])
	_check(harmful <= 4, "harmful trait outcomes are rare (%d)" % harmful)


func _test_degrees() -> void:
	var di := func(die: int, total: int, dc: int) -> int: return GameEvents.degree_index(die, total, dc)
	_check(di.call(10, 25, 15) == 3, "DC+10 is a critical success")
	_check(di.call(10, 24, 15) == 2, "DC+9 is a success")
	_check(di.call(10, 15, 15) == 2, "meeting the DC is a success")
	_check(di.call(10, 14, 15) == 1, "DC-1 is a failure")
	_check(di.call(10, 6, 15) == 1, "DC-9 is a failure")
	_check(di.call(10, 5, 15) == 0, "DC-10 is a critical failure")
	_check(di.call(20, 14, 15) == 2, "natural 20 raises failure to success")
	_check(di.call(20, 20, 15) == 3, "natural 20 raises success to critical")
	_check(di.call(20, 30, 15) == 3, "natural 20 cannot go past critical success")
	_check(di.call(20, 3, 15) == 1, "natural 20 raises critical failure to failure")
	_check(di.call(1, 15, 15) == 1, "natural 1 lowers success to failure")
	_check(di.call(1, 26, 15) == 2, "natural 1 lowers critical success to success")
	_check(di.call(1, 8, 15) == 0, "natural 1 lowers failure to critical failure")
	_check(di.call(1, 2, 15) == 0, "natural 1 cannot go below critical failure")
	_check(GameEvents.roll_text({"die": 14, "bonus": 9, "total": 23, "dc": 15, "degree": "success"}) == "d20 (14) +9 = 23 vs DC 15: Success", "roll text")
	_check(GameEvents.roll_text({"die": 3.0, "bonus": -2.0, "total": 1.0, "dc": 12.0, "degree": "crit_failure"}) == "d20 (3) -2 = 1 vs DC 12: Critical failure", "roll text from JSON floats")
	_check(GameEvents.roll_text({"die": 1, "bonus": 9, "total": 10, "dc": 13, "degree": "crit_failure"}) == "d20 (1) +9 = 10 vs DC 13: Critical failure (natural 1)", "a natural 1 that moved the result is named")
	_check(GameEvents.roll_text({"die": 20, "bonus": -6, "total": 14, "dc": 15, "degree": "success"}).ends_with("Success (natural 20)"), "a natural 20 that moved the result is named")
	_check(not GameEvents.roll_text({"die": 20, "bonus": 10, "total": 30, "dc": 15, "degree": "crit_success"}).contains("natural"), "a natural 20 that changed nothing is not named")


func _test_bonus() -> void:
	var step := int(GameData.bal("event_proficiency_step"))
	_check(GameEvents.proficiency(1) == 1 * step, "proficiency at level 1")
	_check(GameEvents.proficiency(2) == 1 * step, "proficiency at level 2")
	_check(GameEvents.proficiency(3) == 2 * step, "proficiency at level 3")
	_check(GameEvents.proficiency(31) == 5 * step, "proficiency at level 31")
	_check(GameEvents.proficiency(45) == 5 * step, "proficiency at level 45")
	_check(GameEvents.proficiency(5000) == 12 * step, "proficiency at level 5000")
	_check(GameEvents.proficiency(99999) == 16 * step, "proficiency at the level cap")
	var d := _fresh("warrior")
	var h := d.heir
	_check(GameEvents.attr_bonus(h, "str") == 8, "a warrior's best stat gives +8")
	_check(GameEvents.attr_bonus(h, "mag") < GameEvents.attr_bonus(h, "str"), "weaker stat gives less")
	_check(GameEvents.attr_bonus(h, "persuasion") == 0, "no persuasion without traits")
	h.traits = ["noble_blood"]
	_check(GameEvents.attr_bonus(h, "persuasion") == 5, "Noble Blood: +5 persuasion")
	_check(GameEvents.attr_bonus(h, "persuasion") <= GameEvents.attr_bonus(h, "str"), "a skill never beats the best-stat part")
	h.traits = ["the_sight"]
	_check(GameEvents.attr_bonus(h, "prophecy_strength") == int(GameData.bal("event_skill_bonus_cap")), "skill bonus is capped")
	var o := _fresh("warrior", "orc")
	_check(GameEvents.attr_bonus(o.heir, "persuasion") == -2, "orcs are poor talkers")
	# bonus_if: a half-orc counts as an orc; a dread knight counts as a necromancer and a warrior.
	var ho := _fresh("dread_knight", "half_orc")
	GameEvents.begin(ho, "toll_rope")
	var check: Dictionary = GameEvents.event_def("toll_rope")["choices"][1]["check"]
	var parts := GameEvents.check_parts(ho, check)
	var labels: Array = parts.map(func(p): return p[0])
	_check("Orc" in labels and "Warrior" in labels and "Necromancer" in labels, "hybrid race and class bonuses apply (%s)" % str(labels))
	var sum := 0
	for p in parts:
		sum += int(p[1])
	_check(GameEvents.check_bonus(ho, check) == sum, "bonus is the sum of its parts")
	_check(GameEvents.check_bonus(ho, check) == GameEvents.proficiency(1) + GameEvents.attr_bonus(ho.heir, "intimidation") + 4 + 2 + 2, "toll stare-down bonus for a half-orc dread knight")
	# DC rises with a place's danger.
	ho.world.visit("hearthmere")
	ho.pending_event["place"] = "hearthmere"
	_check(GameEvents.check_dc(ho, {"attr": "str", "dc": 15}) == 14, "safe town lowers the DC")
	ho.pending_event["place"] = "the_rift"
	_check(GameEvents.check_dc(ho, {"attr": "str", "dc": 15}) == 19, "the Rift raises the DC")
	ho.pending_event["place"] = "hollow_barrow"
	_check(GameEvents.check_dc(ho, {"attr": "str", "dc": 15}) == 17, "danger 1.15 rounds half up to +2, not float-jittered to +1")
	ho.pending_event["place"] = "mirefen"
	_check(GameEvents.check_dc(ho, {"attr": "str", "dc": 15}) == 16, "danger 1.05 adds 1")


func _test_odds() -> void:
	var d := _fresh()
	GameEvents.begin(d, "tavern_brawl")
	d.pending_event["place"] = "whisperwood"   # danger 1.0: the DC is as written
	var c := {"attr": "str", "dc": 15}
	_check(GameEvents.check_dc(d, c) == 15, "DC as written at danger 1.0")
	var odds := GameEvents.degree_odds(d, c)
	var total := 0.0
	for p in odds:
		total += float(p)
	_check(_near(total, 1.0), "degree odds sum to 1")
	var bonus := GameEvents.check_bonus(d, c)
	var expect := 0
	for die in range(1, 21):
		if GameEvents.degree_index(die, die + bonus, 15) >= 2:
			expect += 1
	_check(_near(GameEvents.success_chance(d, c), expect / 20.0), "success chance matches enumeration")
	d.heir.level = 99999
	_check(_near(GameEvents.success_chance(d, {"attr": "str", "dc": 15}), 1.0), "level cap: always succeeds at DC 15")
	_check(_near(float(GameEvents.degree_odds(d, {"attr": "str", "dc": 15})[3]), 0.95), "level cap: natural 1 still drops a critical")
	d.heir.level = 1
	_check(_near(GameEvents.success_chance(d, {"attr": "persuasion", "dc": 60}), 0.0), "impossible DC: never succeeds")
	var label := GameEvents.choice_label(d, 0)
	_check(label.begins_with("Wade in and crack heads  [STR vs DC "), "choice label shows the check (%s)" % label)
	_check(label.ends_with("%]"), "choice label ends with the chance")


func _test_gating() -> void:
	var d := _fresh("warrior", "human")
	d.world.visit("kingshold")
	GameEvents.begin(d, "noble_supper")
	var ev := GameEvents.current(d)
	var st := GameEvents.choice_status(d, ev["choices"][0])
	_check(not st["ok"], "Noble Blood choice closed to a commoner")
	_check(st["reason"] == "Requires: Noble Blood, Usurper or Bastard Line" or st["reason"].begins_with("Requires: Noble Blood"), "reason names the trait (%s)" % st["reason"])
	_check(GameEvents.choice_label(d, 0).contains("(Requires: Noble Blood"), "disabled label shows the reason")
	_check(GameEvents.resolve(d, 0).is_empty() and GameEvents.stage(d) == "choose", "a closed choice cannot be taken")
	d.heir.traits.append("noble_blood")
	st = GameEvents.choice_status(d, ev["choices"][0])
	_check(st["ok"] and st["tag"] == "Noble Blood", "Noble Blood opens it, tagged")
	_check(GameEvents.choice_label(d, 0).begins_with("[Noble Blood] Take the chair"), "open label carries the tag")
	# any-of gates: class OR trait
	var pilgrim: Dictionary = GameEvents.event_def("wounded_pilgrim")["choices"][1]
	_check(not GameEvents.choice_status(d, pilgrim)["ok"], "warrior cannot rob the pilgrim")
	_check(GameEvents.choice_status(d, pilgrim)["reason"].contains(" or "), "any-of reason uses 'or'")
	var rogue := _fresh("rogue")
	_check(GameEvents.choice_status(rogue, pilgrim)["ok"], "rogue can")
	var ninja := _fresh("ninja")
	_check(GameEvents.choice_status(ninja, pilgrim)["ok"] and GameEvents.choice_status(ninja, pilgrim)["tag"] == "Ninja", "a ninja counts as a rogue")
	d.heir.traits.append("outlaws_cunning")
	_check(GameEvents.choice_status(d, pilgrim)["ok"] and GameEvents.choice_status(d, pilgrim)["tag"] == "Outlaw's Cunning", "Outlaw's Cunning opens it too")
	# race gates and hybrids
	var elf_choice: Dictionary = GameEvents.event_def("elven_wardens")["choices"][0]
	_check(not GameEvents.choice_status(_fresh("warrior", "human"), elf_choice)["ok"], "human cannot answer in the old tongue")
	_check(GameEvents.choice_status(_fresh("warrior", "elf"), elf_choice)["ok"], "elf can")
	_check(GameEvents.choice_status(_fresh("warrior", "half_elf"), elf_choice)["ok"], "half-elf can")
	var levy: Dictionary = GameEvents.event_def("border_levy")["choices"][0]
	_check(GameEvents.choice_status(_fresh("warrior", "dwarf"), levy)["reason"].begins_with("Requires: Human ("), "custom reason text")
	# gold gate scales with the generation
	var toll: Dictionary = GameEvents.event_def("toll_rope")["choices"][0]
	var poor := _fresh()
	poor.heir.gold = 0
	_check(GameEvents.choice_status(poor, toll)["reason"] == "Requires: 15 gold", "gold gate reason")
	poor.gen = 101
	_check(GameEvents.choice_status(poor, toll)["reason"] == "Requires: %d gold" % int(round(15.0 * GameData.enemy_scale(101))), "gold gate scales with generation")
	poor.heir.gold = 10000
	_check(GameEvents.choice_status(poor, toll)["ok"], "rich heir can pay")
	# item gate
	var ig := GameEvents.choice_status(poor, {"requires": {"item": "lucky_charm"}})
	_check(not ig["ok"] and ig["reason"] == "Requires: Lucky Charm", "item gate")
	poor.heir.equipment["trinket"] = "lucky_charm"
	_check(GameEvents.choice_status(poor, {"requires": {"item": "lucky_charm"}})["ok"], "equipped item counts")
	# event-level gates
	var e := _fresh()
	e.world.visit("whisperwood")
	_check(not GameEvents.is_eligible(e, GameEvents.event_def("dream_with_teeth")), "Sight-only event needs the Sight")
	e.heir.traits.append("the_sight")
	_check(GameEvents.is_eligible(e, GameEvents.event_def("dream_with_teeth")), "...and then it can happen")
	_check(GameEvents.is_eligible(e, GameEvents.event_def("wolf_den")), "wolf den in the forest at gen 1")
	e.gen = 200
	_check(not GameEvents.is_eligible(e, GameEvents.event_def("wolf_den")), "no wolf den once wolves are gone")
	_check(not GameEvents.is_eligible(e, GameEvents.event_def("goblin_market")), "goblin market only in caves")
	e.gen = 1
	_check(not GameEvents.is_eligible(e, GameEvents.event_def("ancestor_shade")), "ancestor shade needs ancestors")
	# once-per-generation for repeatable events
	GameEvents.begin(e, "wolf_den")
	GameEvents.dismiss(e)
	_check(not GameEvents.is_eligible(e, GameEvents.event_def("wolf_den")), "a repeatable event waits for the next generation")
	e.gen = 2
	_check(GameEvents.is_eligible(e, GameEvents.event_def("wolf_den")), "...and comes back")


## Place the heir somewhere the event can happen and meet every gate of choice `ci`.
func _setup_for(ev: Dictionary, ci: int) -> GameDynasty:
	var c: Dictionary = ev["choices"][ci]
	var r: Dictionary = c.get("requires", {})
	var any: bool = r.get("any", false)
	var race_id: String = r["race"][0] if r.has("race") else "human"
	var class_id: String = "warrior"
	if r.has("class") and not (any and r.has("race")):
		class_id = r["class"][0]
	var d := _fresh(class_id, race_id, 77 + ci)
	var er: Dictionary = ev.get("requires", {})
	d.gen = int(er.get("min_gen", 1))
	for t in er.get("traits", []).slice(0, 1):
		d.heir.traits.append(t)
	d.heir.level = maxi(10, int(er.get("min_level", 1)))
	d.heir.full_heal()
	if d.gen >= 3:
		d.history = [{"name": "Old Mother Test"}, {"name": "Grandsire Test"}]
	if r.has("traits") and not (any and (r.has("class") or r.has("race"))):
		d.heir.traits.append(r["traits"][0])
	if r.has("item"):
		d.heir.inventory.append(GameEvents._ids(r["item"])[0])
	if r.has("flag"):
		d.set_flag(r["flag"])
	for f in er.get("flags", []):
		d.set_flag(f)
	if r.has("min_level"):
		d.heir.level = maxi(d.heir.level, int(r["min_level"]))
	d.heir.gold = 5000
	for l in GameData.world["locations"]:
		if GameEvents.place_matches(ev, l):
			d.world.visit(l["id"])
			break
	return d


func _test_every_outcome() -> void:
	var runs := 0
	var fights := 0
	for ev in GameData.events:
		var choices: Array = ev["choices"]
		for ci in choices.size():
			var c: Dictionary = choices[ci]
			var degrees: Array = GameEvents.DEGREES if c.has("check") else ["always"]
			for deg in degrees:
				var d := _setup_for(ev, ci)
				_check(GameEvents.begin(d, ev["id"]), "%s opens" % ev["id"])
				var st := GameEvents.choice_status(d, c)
				_check(st["ok"], "%s/%d can be met (%s)" % [ev["id"], ci, st["reason"]])
				var label := GameEvents.choice_label(d, ci)
				_check(label != "" and not label.contains("{"), "%s/%d label" % [ev["id"], ci])
				_check(not GameEvents.event_text(d).contains("{") and not GameEvents.event_title(d).contains("{"), "%s text placeholders filled" % ev["id"])
				var h := d.heir
				var gold_before := h.gold
				var age_before := h.age
				var traits_before: Array = h.traits.duplicate()
				var o := GameEvents.outcome_for(c, deg)
				var msgs := GameEvents.resolve_as(d, ci, deg) if deg != "always" else GameEvents.resolve(d, ci)
				runs += 1
				var where := "%s/%d/%s" % [ev["id"], ci, deg]
				_check(not msgs.is_empty(), "%s returns messages" % where)
				_check(GameEvents.stage(d) == "result", "%s stores a result" % where)
				var r: Dictionary = d.pending_event.get("result", {})
				_check(str(r.get("degree", "")) == deg, "%s degree stored" % where)
				_check(not str(r.get("text", "")).contains("{"), "%s outcome text filled" % where)
				_check((r.get("roll", {}) as Dictionary).is_empty() == (deg == "always"), "%s roll stored for checks" % where)
				if o.has("gold") and d.state == "life":
					var g := GameEvents.gold_amount(d, float(o["gold"]))
					_check(h.gold - gold_before == g, "%s gold %d -> %d (expected %+d)" % [where, gold_before, h.gold, g])
				_check(h.hp >= 1 or d.state != "life", "%s never kills by hp loss" % where)
				if o.has("add_trait") and o["add_trait"] not in traits_before:
					_check(o["add_trait"] in h.traits, "%s adds %s" % [where, o["add_trait"]])
				if o.has("remove_trait"):
					var held: Array = GameEvents._ids(o["remove_trait"]).filter(func(t): return t in traits_before)
					_check(not held.is_empty(), "%s: the heir carries something to remove" % where)
					if not held.is_empty():
						_check(held[0] not in h.traits, "%s removes %s" % [where, held[0]])
				if o.has("item"):
					_check(o["item"] in h.inventory or h.gold > gold_before, "%s gives %s" % [where, o["item"]])
				if o.has("flag"):
					_check(d.flags.has(o["flag"]), "%s sets flag" % where)
				if o.has("years") and d.state == "life":
					_check(_near(h.age - age_before, float(o["years"])), "%s passes %s years" % [where, str(o["years"])])
				if o.has("fight"):
					if d.state == "life":
						_check(d.battle != null, "%s starts a battle" % where)
						_check(d.battle_kind == "event", "%s battle kind is event" % where)
						_check(d.battle.enemies.size() == (o["fight"]["foes"] as Array).size(), "%s foe count" % where)
						for e in d.battle.enemies:
							_check(not e["boss"], "%s no bosses in event fights" % where)
						GameEvents.dismiss(d)
						var before := h.age
						GameBot.fight(d)
						fights += 1
						_check(d.battle == null, "%s battle finished" % where)
						if d.state == "life":
							_check(h.age - before >= float(GameData.bal("event_fight_years")) - 0.0001, "%s fight takes time" % where)
				else:
					_check(d.battle == null, "%s no battle" % where)
				GameEvents.dismiss(d)
				_check(not d.has_pending_event(), "%s dismissed" % where)
	print("  forced %d outcomes, %d event fights" % [runs, fights])


func _test_event_fight() -> void:
	var d := _fresh("warrior", "human", 5)
	d.world.visit("whisperwood")
	d.heir.level = 12
	d.heir.full_heal()
	GameEvents.begin(d, "wolf_den")
	GameEvents.resolve(d, 0)   # smoke them out: always a fight
	_check(d.battle != null and d.battle_kind == "event", "fight choice starts an event battle")
	_check(d.years_for("event") == int(GameData.bal("event_fight_years")), "event battles take event_fight_years")
	var r: Dictionary = d.pending_event["result"]
	_check((r["fight"] as Array).size() == 2, "result lists the foes")
	for e in d.battle.enemies:
		_check(e["id"] == "wolf", "wolves in the den at gen 1")
		_check(int(e["level"]) == int(round(12.0 * 1.0 * 1.0)), "foes at the heir's level times danger")
	var json := JSON.stringify(d.to_dict())
	_check(json != "", "dynasty serialises mid-event-battle")
	GameEvents.dismiss(d)
	var age := d.heir.age
	var wins := d.heir.battles_won
	GameBot.fight(d)
	_check(d.battle == null, "battle over")
	if d.state == "life" and d.heir.battles_won > wins:
		_check(_near(d.heir.age - age, float(GameData.bal("event_fight_years"))), "victory costs event_fight_years")
	# Fleeing and losing an event fight settle like any other battle.
	for outcome in ["fled", "defeat"]:
		for k in 6:
			var f := _fresh("warrior", "human", 300 + k)
			f.world.visit("whisperwood")
			GameEvents.begin(f, "wolf_den")
			GameEvents.resolve(f, 0)
			GameEvents.dismiss(f)
			var a := f.heir.age
			f.battle.result = outcome
			var out := f.finish_battle()
			_check(f.battle == null and not out.is_empty(), "%s: event battle finishes" % outcome)
			if f.state == "life":
				var spent := float(f.years_for("rest")) if outcome == "fled" else float(GameData.bal("defeat_years")) + float(f.years_for("event"))
				_check(_near(f.heir.age - a, spent), "%s: %.1f years pass (%.2f)" % [outcome, spent, f.heir.age - a])
			else:
				_check(outcome == "defeat" and f.state == "succession", "only a defeat can end the line here")
	# Creatures out of their era are replaced by local ones.
	var late := _fresh()
	late.gen = 400
	late.world.visit("frostreach")
	late.heir.level = 50
	GameEvents.begin(late, "frozen_courier")
	GameEvents.resolve_as(late, 1, "crit_failure")
	_check(late.battle != null, "local foes battle")
	for e in late.battle.enemies:
		var cdef: Dictionary = {}
		for c in GameData.creatures:
			if c["id"] == e["id"]:
				cdef = c
		_check(int(cdef["min_gen"]) <= 400 and 400 <= int(cdef["max_gen"]), "local foe %s roams at gen 400" % e["id"])
	var late2 := _fresh()
	late2.gen = 500
	late2.world.visit("greenvale")
	GameEvents.begin(late2, "spice_caravan")
	GameEvents.resolve(late2, 0)
	for e in late2.battle.enemies:
		_check(e["id"] != "bandit", "bandits replaced after their era")


func _test_explore_and_arrive() -> void:
	var explore_chance: float = GameData.bal("event_explore_chance")
	var arrive_chance: float = GameData.bal("event_arrive_chance")
	var d := _fresh("ranger", "human", 11)
	d.world.visit("whisperwood")
	GameData.balance["event_explore_chance"] = 1.0
	var age := d.heir.age
	var msgs := d.explore()
	_check(d.has_pending_event(), "explore with chance 1 finds an event")
	_check(_near(d.heir.age - age, float(d.years_for("explore"))), "exploring takes a year")
	_check(msgs.size() >= 2, "explore reports the event")
	var age2 := d.heir.age
	var again := d.explore()
	_check(_near(d.heir.age, age2) and again.size() == 1, "cannot explore with an event pending")
	GameEvents.dismiss(d)
	GameData.balance["event_explore_chance"] = 0.0
	var xp_before := d.heir.xp
	var lvl := d.heir.level
	d.explore()
	_check(not d.has_pending_event(), "chance 0: nothing happens")
	_check(d.heir.xp != xp_before or d.heir.level != lvl, "a quiet year still teaches something")
	GameData.balance["event_explore_chance"] = explore_chance
	# Arrival
	GameData.balance["event_arrive_chance"] = 1.0
	var t := _fresh("warrior", "human", 12)
	t.heir.gold = 1000
	t.travel("greenvale")
	_check(t.has_pending_event() or t.state != "life", "arriving in the wilds can bring an event")
	GameEvents.dismiss(t)
	t.travel("hearthmere")
	_check(not t.has_pending_event(), "no arrival events in towns")
	GameData.balance["event_arrive_chance"] = arrive_chance
	# Exploring a town works too.
	var town := _fresh("warrior", "human", 13)
	GameData.balance["event_explore_chance"] = 1.0
	town.explore()
	_check(town.has_pending_event(), "towns have events")
	_check(GameEvents.current(town)["where"].get("types", []).has("town") or GameEvents.current(town)["where"].get("places", []).has("hearthmere"), "a town event")
	GameData.balance["event_explore_chance"] = explore_chance


func _test_save_load() -> void:
	var d := _fresh("cleric", "human", 21)
	d.world.visit("hearthmere")
	GameEvents.begin(d, "plague_ward")
	var json := JSON.stringify(d.to_dict())
	var l := GameDynasty.from_dict(JSON.parse_string(json))
	_check(l.has_pending_event() and str(l.pending_event["id"]) == "plague_ward", "pending event survives save/load")
	_check(GameEvents.stage(l) == "choose", "stage survives")
	GameEvents.drop_stale(l)
	_check(l.has_pending_event(), "a reloaded event is not stale")
	_check(GameEvents.choice_label(l, 1) == GameEvents.choice_label(d, 1), "labels match after load")
	# The same choice after load gives the same roll (the RNG state is saved).
	var a := GameEvents.resolve(d, 0)
	var b := GameEvents.resolve(l, 0)
	_check(a == b, "same roll after load")
	var json2 := JSON.stringify(l.to_dict())
	var l2 := GameDynasty.from_dict(JSON.parse_string(json2))
	_check(GameEvents.stage(l2) == "result", "result stage survives save/load")
	var rt := GameEvents.roll_text(l2.pending_event["result"]["roll"])
	_check(rt == GameEvents.roll_text(l.pending_event["result"]["roll"]) and rt.begins_with("d20 ("), "roll text after load (%s)" % rt)
	_check((l2.pending_event["result"]["effects"] as Array).size() == (l.pending_event["result"]["effects"] as Array).size(), "effects survive")
	# Old saves without a pending_event key still load.
	var old: Dictionary = JSON.parse_string(json)
	old.erase("pending_event")
	var lo := GameDynasty.from_dict(old)
	_check(not lo.has_pending_event(), "old save loads with no event")


func _test_stale() -> void:
	var d := _fresh("warrior", "human", 31)
	d.world.visit("whisperwood")
	GameEvents.begin(d, "wolf_den")
	d._die("old age")
	d.choose_heir(0)
	_check(d.has_pending_event(), "(the dynasty itself does not clear it)")
	GameEvents.drop_stale(d)
	_check(not d.has_pending_event(), "a dead heir's event is dropped")
	d.pending_event = {"id": "no_such_event", "heir": d.heir.id, "stage": "choose"}
	GameEvents.bot_resolve(d)
	_check(not d.has_pending_event(), "unknown event dropped")


func _test_bot() -> void:
	var d := _fresh("warrior", "human", 41)
	_check(not GameEvents.bot_wants_explore(d), "bot does not explore in town")
	d.world.visit("whisperwood")
	var yes := 0
	for i in 600:
		d.heir.age = 20.0 + float(i) * 0.25
		if GameEvents.bot_wants_explore(d):
			yes += 1
	_check(yes > 60 and yes < 160, "bot explores roughly one step in six (%d/600)" % yes)
	# bot never picks a closed choice, and settles the event fully
	for ev in GameData.events:
		var b := _setup_for(ev, 0)
		b.heir.traits = ["warriors_steel"]
		GameEvents.begin(b, ev["id"])
		GameEvents.bot_resolve(b)
		_check(not b.has_pending_event(), "%s settled by the bot" % ev["id"])
		_check(b.battle == null, "%s bot fought any battle" % ev["id"])
	# with low HP the bot avoids picking a fight
	var w := _fresh("warrior", "human", 42)
	w.world.visit("whisperwood")
	w.heir.hp = 1
	GameEvents.begin(w, "wolf_den")
	var best := -1
	var best_v := -INF
	var choices: Array = GameEvents.current(w)["choices"]
	for i in choices.size():
		if GameEvents.choice_status(w, choices[i])["ok"]:
			var v := GameEvents.choice_value(w, choices[i])
			if v > best_v:
				best_v = v
				best = i
	_check(best != 0, "wounded bot does not smoke out wolves")
	# bot prefers a sure gain over a coin toss with a curse in it
	var cursed := _fresh("warrior", "human", 43)
	cursed.world.visit("sunken_temple")
	GameEvents.begin(cursed, "tide_altar")
	var vals: Array = []
	for c in GameEvents.current(cursed)["choices"]:
		vals.append(GameEvents.choice_value(cursed, c))
	_check(vals[2] < 45.0 * 0.5, "robbing the altar is discounted for its curse risk")


func _test_high_level() -> void:
	var d := _fresh("mage", "elf", 51)
	d.gen = 700
	d.heir.level = 5000
	d.heir.full_heal()
	d.world.visit("the_rift")
	GameEvents.begin(d, "rift_voices")
	var label := GameEvents.choice_label(d, 0)
	_check(label.contains("vs DC 17"), "rift DC is 13 + 4 for danger (%s)" % label)
	var xp_before := d.heir.level
	GameEvents.resolve_as(d, 0, "success")
	var fx: Array = d.pending_event["result"]["effects"]
	var xp_line: String = ""
	for f in fx:
		if str(f["t"]).ends_with(" XP"):
			xp_line = f["t"]
	_check(xp_line == "+%d XP" % int(round(50.0 * GameData.xp_level_scale(5000))), "XP scales with level (%s)" % xp_line)
	_check(d.heir.level >= xp_before, "no level loss")
	var g := _fresh()
	g.gen = 999
	_check(GameEvents.gold_amount(g, 40.0) == int(round(40.0 * GameData.enemy_scale(999))), "gold scales with generation")


func _test_determinism() -> void:
	var runs: Array = []
	for k in 2:
		var d := _fresh("ranger", "human", 61)
		d.world.visit("whisperwood")
		var log: Array = []
		for i in 12:
			if d.state != "life":
				break
			d.explore()
			if d.has_pending_event():
				log.append(str(d.pending_event["id"]))
				GameEvents.bot_resolve(d)
				log.append(str(d.heir.gold))
		runs.append(log)
	_check(runs[0] == runs[1] and not runs[0].is_empty(), "same seed, same events (%s)" % str(runs[0]))


func _test_once_and_chains() -> void:
	# The Drowned Bell rings once a generation until someone hears it; then the Bell Below opens, once ever.
	var d := _fresh("warrior", "human", 71)
	d.heir.gold = 1000
	d.world.visit("stormcoast")
	var bell := GameEvents.event_def("drowned_bell")
	var below := GameEvents.event_def("bell_below")
	_check(GameEvents.is_eligible(d, bell), "drowned bell on the coast")
	d.world.visit("sunken_temple")
	_check(not GameEvents.is_eligible(d, below), "the bell below needs the bell heard first")
	d.world.visit("stormcoast")
	GameEvents.begin(d, "drowned_bell")
	GameEvents.resolve_as(d, 0, "failure")
	GameEvents.dismiss(d)
	_check(not d.flags.has("heard_drowned_bell"), "a failed dive learns nothing")
	d.gen = 2
	_check(GameEvents.is_eligible(d, bell), "the bell rings again for the next heir")
	GameEvents.begin(d, "drowned_bell")
	GameEvents.resolve_as(d, 0, "success")
	GameEvents.dismiss(d)
	_check(d.flags.has("heard_drowned_bell"), "a good dive finds the way")
	d.gen = 3
	_check(not GameEvents.is_eligible(d, bell), "not_flags: the bell is not heard twice")
	d.world.visit("sunken_temple")
	_check(GameEvents.is_eligible(d, below), "flags: the bell below opens")
	GameEvents.begin(d, "bell_below")
	_check(d.flags.has(GameEvents.SEEN + "bell_below"), "a once event is marked when it opens")
	var l := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	GameEvents.dismiss(l)
	l.gen = 40
	_check(not GameEvents.is_eligible(l, below), "a once event never comes back, even after a reload")
	# A choice gated on a flag from the chain: the sea's debt at the shipwreck.
	var wreck := _fresh("warrior", "human", 73)
	wreck.world.visit("stormcoast")
	GameEvents.begin(wreck, "shipwreck")
	var debt := -1
	for i in GameEvents.current(wreck)["choices"].size():
		if GameEvents.current(wreck)["choices"][i].get("requires", {}).has("flag"):
			debt = i
	_check(debt >= 0, "the shipwreck has a flag-gated choice")
	var st := GameEvents.choice_status(wreck, GameEvents.current(wreck)["choices"][debt])
	_check(not st["ok"] and st["reason"].contains("House " + wreck.dynasty_name), "flag gate reason is filled in (%s)" % st["reason"])
	GameEvents.resolve_as(d, 0, "success")
	_check(d.flags.has("drowned_priest_rests"), "ringing the bell lays the priest to rest")
	wreck.set_flag("drowned_priest_rests")
	_check(GameEvents.choice_status(wreck, GameEvents.current(wreck)["choices"][debt])["ok"], "...which opens the sea's debt")
	# Breaking the smuggling ring ends the cove and brings revenge.
	var s := _fresh("warrior", "human", 72)
	s.world.visit("brinehaven")
	var cove := GameEvents.event_def("smugglers_cove")
	var revenge := GameEvents.event_def("smugglers_revenge")
	_check(GameEvents.is_eligible(s, cove) and not GameEvents.is_eligible(s, revenge), "casks at the cove; no revenge yet")
	GameEvents.begin(s, "smugglers_cove")
	GameEvents.resolve_as(s, 0, "crit_success")
	GameEvents.dismiss(s)
	s.gen = 2
	_check(not GameEvents.is_eligible(s, cove), "a broken ring lands no more casks")
	_check(GameEvents.is_eligible(s, revenge), "and comes back for revenge")


func _test_curse_removal() -> void:
	var d := _fresh("warrior", "human", 81)
	d.world.visit("mirefen")
	var witch := GameEvents.event_def("hedge_witch")
	_check(not GameEvents.is_eligible(d, witch), "the hedge-witch only finds the cursed")
	d.heir.traits.append("cursed")
	d.heir.traits.append("blood_debt")
	_check(GameEvents.is_eligible(d, witch), "a cursed heir meets her")
	d.heir.gold = 0
	GameEvents.begin(d, "hedge_witch")
	_check(not GameEvents.choice_status(d, witch["choices"][0])["ok"], "silver needs silver")
	_check(GameEvents.choice_label(d, 1) == "Pay her in years  [2 years]", "a choice that costs years says so (%s)" % GameEvents.choice_label(d, 1))
	d.heir.gold = 100000
	_check(GameEvents.choice_value(d, witch["choices"][0]) > GameEvents.choice_value(d, witch["choices"][3]), "the bot values lifting a curse")
	var before := d.heir.gold
	GameEvents.resolve(d, 0)
	_check("blood_debt" not in d.heir.traits and "cursed" in d.heir.traits, "the worse curse goes first")
	_check(before - d.heir.gold == GameEvents.gold_amount(d, 80.0), "she takes her price")
	var fx: Array = d.pending_event["result"]["effects"]
	_check(fx.any(func(f): return f["t"] == "Trait lost: " + GameData.trait_name("blood_debt") and f["k"] == "good"), "losing a curse shows as good")
	GameEvents.dismiss(d)
	# The temple in town does the same, and the autopilot takes the offer.
	var t := _fresh("cleric", "human", 82)
	t.heir.traits.append("fae_contract")
	t.heir.gold = 100000
	_check(GameEvents.is_eligible(t, GameEvents.event_def("temple_exorcism")), "the temple sees a curse")
	GameEvents.begin(t, "temple_exorcism")
	GameEvents.bot_resolve(t)
	_check("fae_contract" not in t.heir.traits, "the bot pays to lift a curse")


func _test_text_and_journal() -> void:
	var d := _fresh("warrior", "human", 91)
	d.world.visit("whisperwood")
	GameEvents.begin(d, "hermit_seer")
	GameEvents.resolve(d, 0)
	var t: String = d.pending_event["result"]["text"]
	_check(t.contains("your forebears") and not t.contains("{"), "ancestor fallback without ancestors (%s)" % t)
	# The XP line comes before the level-up it caused, in the journal and on the panel.
	var xi := -1
	var li := -1
	for i in d.journal.size():
		if str(d.journal[i]).begins_with("+") and str(d.journal[i]).contains(" XP"):
			xi = i
		if str(d.journal[i]).begins_with("Level up!"):
			li = i
	_check(xi >= 0 and li > xi, "journal: XP, then level up (%d, %d)" % [xi, li])
	var labels: Array = (d.pending_event["result"]["effects"] as Array).map(func(f): return f["t"])
	_check(str(labels[0]).ends_with(" XP") and str(labels[1]).begins_with("Level up!"), "panel: XP, then level up (%s)" % str(labels))
	var e := _fresh("warrior", "human", 92)
	e.history = [{"name": "Wulfric Test"}]
	e.world.visit("whisperwood")
	GameEvents.begin(e, "hermit_seer")
	GameEvents.resolve(e, 0)
	_check(str(e.pending_event["result"]["text"]).contains("Wulfric Test"), "an ancestor named in an outcome")
	var f := _fresh()
	f.gen = 12
	f.history = [{"name": "Founder Test"}, {"name": "Second Test"}]
	_check(GameEvents.is_eligible(f, GameEvents.event_def("founders_cairn")), "the cairn appears in Hearthmere by gen 12")
	GameEvents.begin(f, "founders_cairn")
	_check(GameEvents.event_text(f).contains("Founder Test"), "the founder is named")
	# item gates accept any of several items, carried or worn
	var g := _fresh("warrior", "human", 93)
	g.world.visit("hollow_barrow")
	GameEvents.begin(g, "sealed_tomb")
	var token: Dictionary = {}
	for c in GameEvents.current(g)["choices"]:
		if c.get("requires", {}).has("item"):
			token = c
	var st := GameEvents.choice_status(g, token)
	_check(not st["ok"] and st["reason"].contains(" or "), "item gate lists the items (%s)" % st["reason"])
	g.heir.equipment["trinket"] = "holy_symbol"
	st = GameEvents.choice_status(g, token)
	_check(st["ok"] and st["tag"] == GameItems.item_def("holy_symbol")["name"], "a worn holy symbol opens it")


func _test_gate_coverage() -> void:
	var races := {}
	var classes := {}
	var traits := {}
	var n := {"once": 0, "not_flags": 0, "flags": 0, "item": 0, "flag_gate": 0, "remove": 0, "min_gold": 0}
	for ev in GameData.events:
		if ev.get("once", false):
			n["once"] += 1
		for k in ["flags", "not_flags"]:
			if ev.get("requires", {}).has(k):
				n[k] += 1
		for c in ev["choices"]:
			var r: Dictionary = c.get("requires", {})
			for x in r.get("race", []):
				races[x] = true
			for x in r.get("class", []):
				classes[x] = true
			for x in r.get("traits", []):
				traits[x] = true
			for k in ["item", "min_gold"]:
				if r.has(k):
					n[k] += 1
			if r.has("flag"):
				n["flag_gate"] += 1
			for o in c["outcomes"].values():
				if o.has("remove_trait"):
					n["remove"] += 1
	for x in ["elf", "dwarf", "orc", "halfling", "gnome", "dragonborn", "beastkin", "human"]:
		_check(races.has(x), "a choice only %s heirs can take" % x)
	for x in ["mage", "cleric", "rogue", "warrior", "ranger", "monk", "necromancer", "druid"]:
		_check(classes.has(x), "a choice for the %s class" % x)
	var hybrids: Array = classes.keys().filter(func(x): return GameData.classes[x].has("parents"))
	_check(hybrids.size() >= 6, "choices for hybrid classes (%s)" % str(hybrids))
	for x in ["the_sight", "faetouched", "noble_blood", "outlaws_cunning", "divine_favor", "mageblood", "dragonblood", "warriors_steel", "marked_by_death", "craftmaster_hands", "saints_blood"]:
		_check(traits.has(x), "a choice opened by %s" % x)
	for k in n:
		_check(n[k] >= 1, "content uses %s (%d)" % [k, n[k]])


func _test_validator() -> void:
	var saved: Array = GameData.events
	var bad := {
		"id": "broken", "title": "Broken", "text": "x", "where": {"places": ["nowhere"]}, "requires": {"flags": ["never_set"]},
		"choices": [
			{"text": "a", "requires": {"traits": ["no_such_trait"], "flag": "also_never", "item": ["no_such_item"]}, "outcomes": {"always": {"text": "t", "add_trait": "nope", "fight": {"foes": ["grimfang"]}}}},
			{"text": "b", "check": {"attr": "charm", "dc": 10}, "outcomes": {"success": {"text": "s", "gold": 5, "glitter": 1}}},
		],
	}
	GameData.events = saved + [bad]
	var errs := GameEvents.validate()
	GameData.events = saved
	var joined := "\n".join(errs)
	for want in ["unknown place nowhere", "matches no place", "requires flag never_set", "unknown trait no_such_trait", "unknown item no_such_item",
			"requires flag also_never", "needs a reason", "unknown trait nope", "boss creature grimfang", "unknown check attribute charm",
			"needs success and failure", "unknown effect glitter"]:
		_check(joined.contains(want), "validator catches: %s" % want)
	_check(GameEvents.validate().is_empty(), "real content still validates")


func _test_old_save() -> void:
	# A save from before events existed: no pending_event, no flags at all.
	var d := _fresh("ranger", "human", 101)
	d.world.visit("whisperwood")
	var old: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	old.erase("pending_event")
	old.erase("flags")
	var l := GameDynasty.from_dict(old)
	_check(not l.has_pending_event() and l.flags.is_empty(), "an old save loads clean")
	var chance: float = GameData.bal("event_explore_chance")
	GameData.balance["event_explore_chance"] = 1.0
	l.explore()
	GameData.balance["event_explore_chance"] = chance
	_check(l.has_pending_event(), "an old save finds events")
	var id := str(l.pending_event["id"])
	GameEvents.bot_resolve(l)
	_check(not l.has_pending_event() and l.battle == null, "and settles them")
	var again := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(l.to_dict())))
	_check(again.flags.keys() == l.flags.keys(), "event bookkeeping survives a save")
	_check(again.state != "life" or not GameEvents.is_eligible(again, GameEvents.event_def(id)), "a repeatable event still waits a generation after a reload")
	# A pending event saved without a stage still waits for its choice: the panel has no Close button.
	var s := _fresh("warrior", "human", 102)
	s.world.visit("whisperwood")
	s.pending_event = {"id": "wounded_pilgrim", "heir": s.heir.id, "place": "whisperwood"}
	s = GameDynasty.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	GameEvents.drop_stale(s)
	_check(GameEvents.stage(s) == "choose", "a stage-less pending event reopens at the choice")
	_check(not GameEvents.resolve(s, 3).is_empty() and GameEvents.stage(s) == "result", "and can be settled")
	# The cairn's text counts ten generations back to the founder.
	var c := _fresh("warrior", "human", 103)
	c.world.visit("hearthmere")
	c.gen = 10
	_check(not GameEvents.is_eligible(c, GameEvents.event_def("founders_cairn")), "no cairn while the founder is only nine generations back")
	c.gen = 11
	_check(GameEvents.is_eligible(c, GameEvents.event_def("founders_cairn")), "the cairn from generation 11")
