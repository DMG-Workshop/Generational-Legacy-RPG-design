## Trials (roadmap item 67): placement is a pure function of the world seed, a trial is refused until its quest is done, the
## trial-master speaks the lines from data, time runs on the world clock, the check uses its own dice (the dynasty's never
## move), gains are capped per focus, Lore picks what the class suits, a fight trial is won by beating the master, Spirit gains
## pass to heirs, saves keep only what is sound, and the autopilot never takes a trial.
## Run: godot --headless --path . -s res://tests/test_game_trials.gd
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
	test_data()
	test_placement()
	test_quest_gate_and_master()
	test_time_and_dice()
	test_failure()
	test_caps()
	test_lore()
	test_fight_trial()
	test_legacy()
	test_save_and_old_saves()
	test_bot_never_takes_one()
	print("trials tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(class_id: String = "warrior", seed_value: int = 21) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "", class_id, "faetouched", "human")
	d.heir.level = 12
	d.heir.gold = 5000
	return d


## A dynasty whose world stands `id`.
func _dyn_with(id: String, class_id: String = "warrior") -> GameDynasty:
	for s in range(1, 200):
		var d := _dyn(class_id, s)
		if GameTrials.is_placed(d, id):
			return d
	return null


## Does the whole quest of a trial, walking to each place.
func _quest(d: GameDynasty, id: String) -> void:
	while not GameTrials.next_step(d, id).is_empty():
		var s := GameTrials.next_step(d, id)
		if str(s["kind"]) == "visit":
			d.world.location = str(s["place"])
		GameTrials.do_step(d, id)


func _clean_up_clock(d: GameDynasty) -> void:
	d.pending_event = {}


func test_data() -> void:
	ok(GameTrials.validate().is_empty(), "the trial data is sound: %s" % str(GameTrials.validate()))
	ok(GameTrials.realm_ids().size() >= 3, "the base world and two realms have trials")
	var focuses := {}
	for id in GameTrials.ids():
		focuses[str(GameTrials.trial(id)["focus"])] = true
	for f in ["body", "will", "lore", "mastery", "spirit", "wild", "pact"]:
		ok(focuses.has(f), "there is a %s trial" % f)
	for id in GameTrials.ids():
		var t := GameTrials.trial(id)
		ok(not (t["quest"]["steps"] as Array).is_empty() and GameData.creatures.any(func(c): return c["id"] == t["master"]["id"]), "%s has a quest and a master creature" % id)
		if str(t["focus"]) == "pact":
			ok(t.has("drawback"), "%s carries a drawback" % id)


func test_placement() -> void:
	for realm in GameTrials.realm_ids():
		var a := GameTrials.placed(77, realm)
		var b := GameTrials.placed(77, realm)
		ok(a == b, "%s: the same seed places the same trials" % realm)
		ok(a.size() >= 3 and a.size() <= 6, "%s: 3 to 6 trials stand (%d)" % [realm, a.size()])
		var ids: Array = a.map(func(p): return p["id"])
		var uniq := {}
		for i in ids:
			uniq[i] = true
		ok(uniq.size() == ids.size(), "%s: no trial stands twice" % realm)
	var differs := false
	for s in range(1, 30):
		if GameTrials.placed(s, "material") != GameTrials.placed(s + 100, "material"):
			differs = true
	ok(differs, "other seeds place trials elsewhere")
	var d := _dyn()
	var state := d.rng.state
	GameTrials.placed_all(d.seed_value)
	ok(d.rng.state == state, "placing trials draws nothing from the dynasty's dice")


func test_quest_gate_and_master() -> void:
	var d := _dyn_with("stone_lift")
	ok(d != null, "a world with the Stone Lift exists")
	var t := GameTrials.trial("stone_lift")
	var why := GameTrials.start(d, "stone_lift")
	ok(GameTrials.active(d).is_empty(), "a trial is refused while its quest is not done")
	ok(why.contains(str(t["master"]["name"])), "the refusal is the master's: %s" % why)
	d.world.location = "greenvale"
	ok(GameTrials.step_block(d, "stone_lift") != "", "a visit step needs the heir at the place")
	ok(GameTrials.do_step(d, "stone_lift").begins_with("Not yet"), "and says so")
	ok(GameTrials.quest_steps_done(d, "stone_lift") == 0, "nothing was done")
	var gold := d.heir.gold
	_quest(d, "stone_lift")
	ok(GameTrials.quest_complete(d, "stone_lift"), "the quest is done step by step")
	ok(d.heir.gold < gold, "the offering was paid")
	ok(d.flags.has("trial_stone_lift_way"), "finishing the way in sets a story flag")
	d.heir.level = 1
	ok(GameTrials.start(d, "stone_lift") == GameTrials.text("low_level", {"level": 3}), "the level gate holds after the quest")
	d.heir.level = 12
	var line := GameTrials.start(d, "stone_lift")
	ok(GameTrials.active(d).get("id", "") == "stone_lift", "with the quest done the trial starts")
	ok(line.contains(str(t["lines"]["opening"])), "the master's opening line is spoken")
	ok(GameTrials.start(d, "stone_lift") == GameTrials.text("one_at_a_time", {"name": d.heir.name}), "only one trial at a time")
	ok(GameTrials.stage_line(d).contains(str(t["lines"]["stages"][0])), "the first stage line is the master's")
	ok(GameTrials.leave(d) != "" and GameTrials.active(d).is_empty(), "a trial can be left")
	ok(GameTrials.quest_complete(d, "stone_lift"), "leaving does not undo the way in")
	var other := _dyn("warrior", 3)
	ok(GameTrials.start(other, "no_such_trial") == GameTrials.text("no_trial"), "an unknown trial is refused")


func test_time_and_dice() -> void:
	var d := _dyn_with("stone_lift")
	_quest(d, "stone_lift")
	GameTrials.start(d, "stone_lift")
	var len := float(GameTrials.trial("stone_lift")["length"])
	ok(is_equal_approx(GameTrials.remaining(d), len), "the whole length remains at the start")
	ok(GameTrials.finish(d)[0] == GameTrials.text("not_ready", {"trial": "The Stone Lift", "hours": int(len)}), "it cannot end early")
	var rng_state := d.rng.state
	GameTrials.wait(d, len * 0.5)
	_clean_up_clock(d)
	ok(GameTrials.spent(d) > len * 0.4 and GameTrials.remaining(d) > 0.0, "half the hours pass on the world clock (%.2f)" % GameTrials.spent(d))
	ok(GameTrials.stage_line(d).contains(str(GameTrials.trial("stone_lift")["lines"]["stages"][1])), "the master's second stage is spoken half way")
	GameTrials.wait(d, len)
	_clean_up_clock(d)
	ok(GameTrials.remaining(d) == 0.0, "the hours are spent")
	var state_before := d.rng.state
	var hp_before := d.heir.max_hp()
	d.heir.stat("vit")
	var expect_pass := GameTrials.dice(d, "stone_lift").randf() < GameTrials.chance(d.heir, "stone_lift")
	var out := GameTrials.finish(d)
	ok(d.rng.state == state_before, "the check draws nothing from the dynasty's dice")
	ok(GameTrials.done(d.heir, "stone_lift") == expect_pass, "the seeded check decides: %s" % str(out))
	if expect_pass:
		ok(out[0].contains(str(GameTrials.trial("stone_lift")["lines"]["success"])), "the master's success line is spoken")
		ok(d.heir.max_hp() > hp_before, "the gain raises max HP (%d to %d)" % [hp_before, d.heir.max_hp()])
		ok(d.flags.has("trial_stone_lift"), "a flag marks the trial passed")
		ok(GameTrials.start(d, "stone_lift") == GameTrials.text("done_already", {"name": d.heir.name}), "a trial is passed once per heir")
	var c := GameTrials.chance(d.heir, "stone_lift")
	ok(c >= float(GameTrials.setting("check_min")) and c <= float(GameTrials.setting("check_max")), "the chance stays within its limits")
	ok(rng_state != 0, "sanity")


func test_failure() -> void:
	var d := _dyn_with("stone_lift")
	_quest(d, "stone_lift")
	d.heir.level = 12
	d.heir.hp = d.heir.max_hp()
	# Find a try that fails by lowering the stat: a heir with no vitality fails on the floor chance often; walk tries until it does.
	var failed := false
	for i in 60:
		d.trials.erase("retry")
		d.trials.erase("active")
		d.heir.hp = d.heir.max_hp()
		d.heir.trials_done = []
		GameTrials.start(d, "stone_lift")
		GameTrials.wait(d, 7.0)
		_clean_up_clock(d)
		var out := GameTrials.finish(d)
		ok(d.heir.hp >= 1, "a setback never kills")
		if not GameTrials.done(d.heir, "stone_lift"):
			failed = true
			ok(out[0].contains(str(GameTrials.trial("stone_lift")["lines"]["failure"])), "the master's failure line is spoken")
			ok(d.heir.hp < d.heir.max_hp(), "a hurt setback costs health")
			ok(GameTrials.start(d, "stone_lift").begins_with("Wait"), "a retry waits")
			GameTrials.wait(d, float(GameTrials.setting("retry_hours")) + 1.0)
			_clean_up_clock(d)
			ok(GameTrials.start_block(d, "stone_lift") == "", "and may be tried again after the delay")
			break
	ok(failed, "a failed try turned up")


func test_caps() -> void:
	var d := _dyn()
	d.heir.trials_done = ["stone_lift", "weight_of_stone"]
	var hp := GameTrials.bonus(d.heir, "max_hp")
	ok(is_equal_approx(hp, 0.06), "a Body trial adds its max HP gain (%f)" % hp)
	ok(is_equal_approx(GameTrials.bonus(d.heir, "carry_weight"), 0.075), "and its carry gain")
	var carry := GameCarry.capacity(d.heir)
	d.heir.trials_done = []
	ok(carry > GameCarry.capacity(d.heir), "carry weight is raised by the Body trial")
	# Three Will trials would give 0.135 of a cap of 0.12: the cap holds.
	d.heir.trials_done = ["embers_vigil", "thorn_vigil", "dark_descent"]
	ok(GameTrials.bonus(d.heir, "resist") <= float(GameTrials.focus_cap("will")["resist"]) + 0.000001, "a focus never passes its cap")
	ok(is_equal_approx(GameTrials.bonus(d.heir, "resist"), 0.12), "and three Will trials reach it exactly (%f)" % GameTrials.bonus(d.heir, "resist"))
	d.heir.trials_done = ["imps_bargain"]
	ok(is_equal_approx(GameTrials.bonus(d.heir, "max_hp"), -0.05), "a Pact's drawback is applied")
	ok(GameTrials.bonus(d.heir, "melee_damage") > 0.0, "and its strong perk")
	d.heir.trials_done = []
	ok(d.heir.trait_total("max_hp") == _dyn().heir.trait_total("max_hp"), "no trial changes nothing")


func test_lore() -> void:
	var spells := {}
	for cls in ["mage", "warrior"]:
		var d := _dyn_with("archive_of_dust", cls)
		_quest(d, "archive_of_dust")
		GameTrials.start(d, "archive_of_dust")
		GameTrials.wait(d, 6.0)
		_clean_up_clock(d)
		var before_spells := d.heir.spells.duplicate()
		var before_feats := d.heir.known_feats.duplicate()
		d.heir.trials_done = []
		var pick := GameTrials._lore_pick(d, "archive_of_dust")
		ok(not pick.is_empty(), "%s: Lore finds something that suits" % cls)
		if str(pick.get("kind", "")) == "spell":
			ok(cls in GameCombat.spell(str(pick["id"]))["learn"]["classes"], "%s: the spell is on the class's list" % cls)
		elif not pick.is_empty():
			ok(GameFeats.class_may(cls, str(pick["id"])), "%s: the feat is open to the class" % cls)
		ok(GameTrials._lore_pick(d, "archive_of_dust") == pick, "the pick is the same each time")
		# Force the pass.
		d.heir.trials_done = []
		var passed := false
		for i in 40:
			d.trials.erase("retry")
			d.trials.erase("active")
			GameTrials.start(d, "archive_of_dust")
			GameTrials.wait(d, 6.0)
			_clean_up_clock(d)
			GameTrials.finish(d)
			if GameTrials.done(d.heir, "archive_of_dust"):
				passed = true
				break
		ok(passed, "%s: the Archive was passed in a few tries" % cls)
		ok(d.heir.spells.size() > before_spells.size() or d.heir.known_feats.size() > before_feats.size() or d.heir.trials_done.has("archive_of_dust:fb"), "%s: an unlock or the fallback was given" % cls)
		spells[cls] = pick
	# A class nothing on the list fits gets the fallback gain.
	var d2 := _dyn("monk", 5)
	d2.heir.spells = GameData.classes["monk"].get("skills", []).map(func(s): return str(s["id"]))
	var p := GameTrials._lore_pick(d2, "shadow_ledger")
	ok(p.is_empty() or GameFeats.class_may("monk", str(p["id"])), "a class with no spell on the list gets only what it may use")


func test_fight_trial() -> void:
	var d := _dyn_with("ring_of_champions")
	_quest(d, "ring_of_champions")
	GameTrials.start(d, "ring_of_champions")
	ok(GameTrials.begin_master(d) == null, "the master is not met before the hours are spent")
	GameTrials.wait(d, 5.0)
	_clean_up_clock(d)
	ok(GameTrials.finish(d)[0].contains("must be beaten"), "a fight trial is not won without the fight")
	var b := GameTrials.begin_master(d)
	ok(b != null and b.enemies.size() == 1 and b.enemies[0]["name"] == "the Ring Champion", "the master is the foe: %s" % str(b.enemies if b != null else null))
	ok(b.enemies[0]["id"] == "ogre", "of the creature the data names")
	d.battle = null
	d.last_result = "fled"
	ok(GameTrials.settle_master(d).is_empty() and not GameTrials.active(d).is_empty(), "fleeing leaves the trial to fight again")
	GameTrials.begin_master(d)
	d.battle = null
	d.last_result = "victory"
	var out := GameTrials.settle_master(d)
	ok(GameTrials.done(d.heir, "ring_of_champions") and not out.is_empty(), "beating the master wins the trial")
	ok(out[0].contains("fight like you mean it"), "and the master speaks its success line")


func test_legacy() -> void:
	var d := _dyn()
	d.heir.trials_done = ["ancestors_hearth", "stone_lift"]
	d.trials["legacy"] = ["ancestors_hearth"]
	d.trials["active"] = {"id": "stone_lift", "start": 1.0}
	var c := GameHeir.new()
	GameTrials.on_succession(d, c)
	ok(c.trials_done == ["ancestors_hearth"], "only a Spirit gain marked legacy passes to the heir")
	ok(not d.trials.has("active"), "a trial under way is lost with its heir")
	ok(GameTrials.bonus(c, "luck") > 0.0, "and it still works for them")


func test_save_and_old_saves() -> void:
	var d := _dyn_with("stone_lift")
	var plain := d.to_dict()
	ok(not plain.has("trials") and not plain["heir"].has("trials_done"), "nothing is saved until something is done")
	_quest(d, "stone_lift")
	d.heir.trials_done = ["stone_lift", "archive_of_dust:fb"]
	d.trials["legacy"] = ["ancestors_hearth"]
	d.trials["active"] = {"id": "stone_lift", "start": 2.5}
	d.trials["tries"] = {"stone_lift": 2}
	d.trials["retry"] = {"stone_lift": 30.0}
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(back.heir.trials_done == d.heir.trials_done, "the passed trials come back")
	ok(GameTrials.quest_steps_done(back, "stone_lift") == GameTrials.quest_steps_done(d, "stone_lift"), "the quest steps come back")
	ok(GameTrials.active(back).get("id", "") == "stone_lift" and float(GameTrials.active(back)["start"]) == 2.5, "the trial under way comes back")
	ok(back.trials.get("legacy", []) == ["ancestors_hearth"] and int(back.trials["tries"]["stone_lift"]) == 2, "legacy and tries come back")
	var raw := d.to_dict()
	raw.erase("trials")
	raw["heir"].erase("trials_done")
	var old := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(raw)))
	ok(old.trials.is_empty() and old.heir.trials_done.is_empty(), "an old save loads clean")
	var bad := d.to_dict()
	bad["trials"] = {"steps": {"nope": 2, "stone_lift": "x"}, "legacy": ["nope", 5, "archive_of_dust:fb"], "active": {"id": "nope", "start": 1}, "tries": {"stone_lift": -3}, "retry": 7}
	bad["heir"]["trials_done"] = ["stone_lift", "stone_lift", "nope", 4, "stone_lift:fb", "archive_of_dust:fb", "packs_road:fb"]
	var dam := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(bad)))
	ok(dam.trials.is_empty(), "damaged trial state is dropped (%s)" % str(dam.trials))
	ok(dam.heir.trials_done == ["stone_lift", "archive_of_dust:fb"], "damaged trial ids are dropped (%s)" % str(dam.heir.trials_done))
	var worse := d.to_dict()
	worse["trials"] = "oops"
	worse["heir"]["trials_done"] = 12
	var w := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(worse)))
	ok(w.trials.is_empty() and w.heir.trials_done.is_empty(), "values of the wrong type are dropped")


func test_bot_never_takes_one() -> void:
	var src := FileAccess.get_file_as_string("res://core/game/game_bot.gd")
	ok(not src.contains("GameTrials"), "the autopilot never mentions a trial")
	var d := _dyn("warrior", 9)
	d.heir.level = 1
	d.heir.gold = 0
	GameBot.live_life(d)
	ok(d.trials.is_empty() and not d.to_dict().has("trials") and d.heir.trials_done.is_empty(), "a whole autopilot life starts no trial")
	var board := GameData.quests.any(func(q): return str(q["id"]).begins_with("trial"))
	ok(not board, "no trial quest stands on a town board for the autopilot")
