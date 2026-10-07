## Diseases (GameDisease): catching, worsening, cures, contagion, the black market, saves.
## godot --headless --path . -s res://tests/test_game_disease.gd
extends SceneTree

const ShopPanel := preload("res://ui/play/shop_panel.gd")
const LifeScreen := preload("res://ui/play/life_screen.gd")

var failures := 0
var checks := 0


func _check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL: ", what)


func _near(a: float, b: float, eps: float = 0.0001) -> bool:
	return absf(a - b) <= eps


func _fresh(seed_value: int = 4242, class_id: String = "warrior", race: String = "human") -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Test", class_id, "faetouched", race)
	d.heir.traits = d.heir.traits.filter(func(t): return GameData.trait_def(t).get("category", "") == "bloodline")
	d.heir.dormant = []
	d.pending_event = {}
	d.echoes = []
	return d


## A disease with known numbers, added to the data for one test and removed after.
func _add_test_disease(id: String, natural: Array, death: float = 0.0, contagion: Dictionary = {}) -> void:
	var dz := {
		"id": id, "name": "Test Rot", "description": "For tests.",
		"stages": [
			{"name": "Mild", "years": 2, "effects": [{"stat": "max_hp", "value": -0.1}]},
			{"name": "Worse", "years": 1.5, "effects": [{"stat": "max_hp", "value": -0.2}, {"stat": "melee_damage", "value": -0.1}]},
			{"name": "Worst", "effects": [{"stat": "max_hp", "value": -0.3}, {"stat": "melee_damage", "value": -0.2}]},
		],
		"end": {"kind": "lethal", "death_per_year": death, "cause": "taken by Test Rot"} if death > 0.0 else {"kind": "chronic"},
		"contagion": {"spouse": float(contagion.get("spouse", 0.0)), "child": float(contagion.get("child", 0.0)), "companion": 0.0, "birth": float(contagion.get("birth", 0.0))},
		"cures": {"temple": 1.0, "remedies": ["willowbark_tonic"], "natural": natural, "rest": 1.0},
		"vectors": {},
	}
	GameData.diseases["diseases"].append(dz)


func _drop_test_disease(id: String) -> void:
	GameData.diseases["diseases"] = GameData.diseases["diseases"].filter(func(x): return x["id"] != id)


func _journal_has(d: GameDynasty, part: String) -> bool:
	return d.journal.any(func(l): return part in str(l))


func _init() -> void:
	GameData.load_all()
	_test_data()
	_test_catch_chances_are_low()
	_test_effects_on_stats()
	_test_progression()
	_test_lethal_stage()
	_test_natural_recovery()
	_test_rest()
	_test_healers_recover_faster()
	_test_resistance()
	_test_level_milestones()
	_test_contagion_check()
	_test_corpse_risk()
	_test_family_contagion()
	_test_birth_and_succession()
	_test_temple_cure()
	_test_remedies()
	_test_black_market()
	_test_bargains()
	_test_bot()
	_test_save_load()
	_test_old_saves()
	_test_determinism()
	_test_text()
	_test_autopilot()
	_ui_tests.call_deferred()


func _finish() -> void:
	print("%d checks, %d failures" % [checks, failures])
	print("ALL PASS" if failures == 0 else "TESTS FAILED")
	quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------- data

## The player asked for low odds: every random way of catching a sickness is at most 2%.
func _test_catch_chances_are_low() -> void:
	_check(float(GameDisease.setting("milestone_chance")) <= 0.02, "level milestone chance is at most 2%")
	_check(float(GameDisease.setting("corpse_chance")) <= 0.02, "corpse chance is at most 2%")
	for dz in GameDisease.all():
		for k in dz.get("contagion", {}):
			_check(float(dz["contagion"][k]) <= 0.02, "%s: %s contagion is at most 2%% a year" % [dz["id"], k])
		var corpse = dz.get("vectors", {}).get("corpse", null)
		if corpse is Dictionary and corpse.has("chance"):
			_check(float(corpse["chance"]) <= 0.02, "%s: corpse chance is at most 2%%" % dz["id"])


func _test_data() -> void:
	var bad := GameDisease.validate()
	_check(bad.is_empty(), "disease data is valid: %s" % str(bad))
	var ids: Array = GameDisease.all().map(func(x): return x["id"])
	_check(ids.size() >= 10, "about ten diseases (%d)" % ids.size())
	var vec := {"milestone": 0, "corpse": 0, "bargain": 0, "vial": 0, "toxin": 0}
	var lethal := 0
	for dz in GameDisease.all():
		for k in vec:
			if dz.get("vectors", {}).has(k):
				vec[k] += 1
		if GameDisease.is_lethal(dz["id"]):
			lethal += 1
			_check(GameDisease.natural_chance(dz["id"], GameDisease.stages(dz["id"]).size() - 1) == 0.0, "%s: a deadly last stage never clears alone" % dz["id"])
		else:
			_check(not GameDisease.def(dz["id"]).get("vectors", {}).has("milestone") or float(GameDisease.def(dz["id"])["cures"]["natural"][0]) >= 0.3, "%s: common sicknesses usually clear early" % dz["id"])
	for k in vec:
		_check(vec[k] > 0, "some disease spreads by %s" % k)
	_check(lethal >= 3 and lethal <= ids.size() / 2, "a few diseases can kill (%d)" % lethal)
	for dz in GameDisease.all():
		if dz.get("vectors", {}).has("milestone"):
			_check(not GameDisease.is_lethal(dz["id"]), "%s: level milestones only bring mild sickness" % dz["id"])
	# Every disease can be treated by something sold in a town.
	var d := _fresh()
	var sold := {}
	for town in ["hearthmere", "ironford", "kingshold", "brinehaven"]:
		d.world.visit(town)
		for s in GameItems.shops_here(d):
			for id in GameItems.stock(d, s):
				sold[id] = s
	for id in ids:
		var cures: Array = GameDisease.def(id)["cures"]["remedies"]
		_check(cures.any(func(r): return sold.has(r)), "%s has a remedy for sale somewhere" % id)
	for id in GameData.items:
		var it: Dictionary = GameData.items[id]
		if it.get("kind", "") in ["toxin", "vial"] or it.has("taint"):
			_check(sold.get(id, "") == "black_market", "%s sold only at the black market" % id)
		if it.get("kind", "") in ["remedy", "toxin", "vial"]:
			_check(GameItems.stack_max(id) > 0 and GameItems.slot_of(id) == "", "%s stacks in the pack" % id)
	_check(GameData.world["locations"].filter(func(l): return GameDisease.BLACK_MARKET in l.get("services", [])).size() == 2, "two towns have a black market")


# ---------------------------------------------------------------- stats

func _test_effects_on_stats() -> void:
	var d := _fresh()
	var h := d.heir
	h.full_heal()
	var hp := h.max_hp()
	var atk := h.attack_power()
	_check(GameDisease.infect(h, "rat_plague", "test"), "infect")
	_check(not GameDisease.infect(h, "rat_plague", "test"), "no second copy of the same disease")
	_check(not GameDisease.infect(h, "no_such_thing", "test"), "unknown disease refused")
	_check(_near(h.trait_total("max_hp"), -0.05 + _base_hp_mod(h)), "stage 1 effect in trait_total (%.3f)" % h.trait_total("max_hp"))
	_check(h.max_hp() < hp and h.attack_power() < atk, "plague lowers max HP and attack (%d -> %d)" % [hp, h.max_hp()])
	_check(h.hp == h.max_hp(), "a healthy heir stays at full health when max HP drops")
	var e := GameDisease.entry(h, "rat_plague")
	GameDisease._set_stage(h, e, 2)
	var hp2 := h.max_hp()
	_check(hp2 < h.max_hp() + 1 and float(hp2) < float(hp) * 0.85, "last stage hits hard (%d)" % hp2)
	_check(_near(h.attack_power() / atk, (1.0 + h.trait_total("melee_damage") - GameDisease.effect_total(h, "melee_damage") - 0.15) / (1.0 + h.trait_total("melee_damage") - GameDisease.effect_total(h, "melee_damage")), 0.001), "attack drops by the stage's share")
	GameDisease.cure(h, "rat_plague")
	_check(h.max_hp() == hp and _near(h.attack_power(), atk) and h.hp == hp, "cure restores everything")
	# The same share at level 5000, generation 300.
	d.gen = 300
	h.gen = 300
	h.level = 5000
	h.full_heal()
	var big := h.max_hp()
	GameDisease.infect(h, "camp_cough", "test")
	var mult := 1.0 + _base_hp_mod(h) + h.heirloom_bonus
	_check(_near(float(h.max_hp()) / float(big), (mult - 0.03) / mult, 0.0005), "level 5000: the same share of HP lost (%d -> %d)" % [big, h.max_hp()])
	h.hp = int(h.max_hp() / 3)
	var frac := float(h.hp) / float(h.max_hp())
	GameDisease._set_stage(h, GameDisease.entry(h, "camp_cough"), 2)
	_check(absf(float(h.hp) / float(h.max_hp()) - frac) < 0.01, "worsening keeps the share of health, not the number")


func _base_hp_mod(h: GameHeir) -> float:
	return h.trait_total("max_hp") - GameDisease.effect_total(h, "max_hp")


# ---------------------------------------------------------------- time

func _test_progression() -> void:
	_add_test_disease("__rot", [0.0, 0.0, 0.0])
	var d := _fresh()
	var h := d.heir
	GameDisease.infect(h, "__rot", "test")
	var msgs: Array = []
	GameDisease.on_years(d, 1.0, msgs)
	var e := GameDisease.entry(h, "__rot")
	_check(int(e["stage"]) == 0 and _near(float(e["years_in_stage"]), 1.0), "one year in: still stage 1")
	_check("worsens in 1.0 years" in GameDisease.outlook(e), "outlook counts down: %s" % GameDisease.outlook(e))
	GameDisease.on_years(d, 0.25, msgs)
	GameDisease.on_years(d, 0.75, msgs)
	_check(int(e["stage"]) == 1 and _near(float(e["years_in_stage"]), 0.0), "worsens after the stage's 2 years")
	_check(msgs.any(func(l): return "worsens: Worse" in str(l)) and _journal_has(d, "worsens: Worse"), "worsening is journaled: %s" % str(msgs))
	var hp_mid := h.max_hp()
	GameDisease.on_years(d, 4.0, msgs)
	_check(int(e["stage"]) == 2 and _near(float(e["years_in_stage"]), 2.5), "a long stretch carries into the last stage (%.2f)" % float(e["years_in_stage"]))
	_check(h.max_hp() < hp_mid, "the last stage hits harder")
	_check(msgs.any(func(l): return "may stay for life" in str(l)), "reaching a chronic end is spelled out")
	GameDisease.on_years(d, 30.0, msgs)
	_check(int(e["stage"]) == 2 and d.state == "life", "a chronic last stage lingers and never kills")
	_check(GameDisease.outlook(e) == "stays until cured", "chronic outlook: %s" % GameDisease.outlook(e))
	# Through the dynasty: actions pass the years.
	var d2 := _fresh(77)
	GameDisease.infect(d2.heir, "__rot", "test")
	d2.work()
	_check(int(GameDisease.entry(d2.heir, "__rot")["stage"]) == 1, "a job of work (2 years) worsens it")
	d2.train("vit")
	_check(int(GameDisease.entry(d2.heir, "__rot")["stage"]) == 2, "two more years of training reach the last stage")
	_drop_test_disease("__rot")


func _test_lethal_stage() -> void:
	_add_test_disease("__rot", [0.0, 0.0, 0.0], 1.0)
	var d := _fresh()
	var h := d.heir
	GameDisease.infect(h, "__rot", "test", 1)
	var msgs: Array = []
	GameDisease.on_years(d, 1.0, msgs)
	_check(d.state == "life", "no death before the last stage")
	GameDisease.on_years(d, 1.0, msgs)
	_check(d.state == "succession", "the deadly last stage kills")
	_check(str(d.last_death.get("cause", "")) == "taken by Test Rot", "death cause names the disease (%s)" % str(d.last_death.get("cause", "")))
	_check(_journal_has(d, "dies: taken by Test Rot"), "death journaled with the disease")
	_drop_test_disease("__rot")
	# A real deadly disease kills at about its yearly rate; the old-age roll never doubles a death.
	var deaths := 0
	var n := 400
	for i in n:
		var t := _fresh(5000 + i)
		GameDisease.infect(t.heir, "rat_plague", "test", 2)
		var m: Array = []
		GameDisease.on_years(t, 1.0, m)
		if t.state == "succession":
			deaths += 1
			_check(t.history.size() == 1, "one death recorded")
	var rate := float(deaths) / float(n)
	_check(rate > 0.0 and absf(rate - GameDisease.death_chance("rat_plague", 2)) < 0.05, "rat plague kills about 10%% a year at the end (%.3f)" % rate)
	var d3 := _fresh(9)
	GameDisease.infect(d3.heir, "rat_plague", "test", 2)
	GameDisease.entry(d3.heir, "rat_plague")["years_in_stage"] = 0.0
	var r: Array = []
	_check(GameDisease.advance(d3, d3.heir, 0.0, r) == "", "no time, no death")


func _test_natural_recovery() -> void:
	_add_test_disease("__rot", [1.0, 0.0, 0.0])
	var d := _fresh()
	GameDisease.infect(d.heir, "__rot", "test")
	var msgs: Array = []
	GameDisease.on_years(d, 0.25, msgs)
	_check(not GameDisease.has(d.heir, "__rot"), "a sure natural recovery clears it")
	_check(msgs.any(func(l): return "Test Rot" in str(l)), "clearing is journaled: %s" % str(msgs))
	GameDisease.infect(d.heir, "__rot", "test", 1)
	GameDisease.on_years(d, 1.0, msgs)
	_check(GameDisease.has(d.heir, "__rot"), "no natural recovery at a later stage")
	_drop_test_disease("__rot")
	# Camp cough's first stage clears about 45% of the time in a year for an untrained human.
	var cleared := 0
	var n := 600
	for i in n:
		var t := _fresh(7000 + i)
		t.heir.class_id = "warrior"
		GameDisease.infect(t.heir, "camp_cough", "test")
		var m: Array = []
		GameDisease.advance(t, t.heir, 1.0, m)
		if not GameDisease.has(t.heir, "camp_cough"):
			cleared += 1
	var expect := GameDisease.natural_chance("camp_cough", 0) * GameDisease.recovery_mult(_fresh().heir)
	_check(absf(float(cleared) / n - expect) < 0.06, "camp cough clears at its natural rate (%.3f vs %.3f)" % [float(cleared) / n, expect])
	_check(_near(GameDisease.over_years(0.5, 2.0), 0.75) and _near(GameDisease.over_years(0.5, 0.0), 0.0) and _near(GameDisease.over_years(1.0, 0.25), 1.0), "per-year chances compound over years")


func _test_rest() -> void:
	_add_test_disease("__rot", [0.01, 0.0, 0.0])
	var d := _fresh()
	var h := d.heir
	GameDisease.infect(h, "__rot", "test")
	var msgs := d.rest()
	_check(not GameDisease.has(h, "__rot"), "rest breaks an early stage (rest chance 1.0)")
	_check(_journal_has(d, "Bed rest breaks"), "rest's cure is journaled")
	GameDisease.infect(h, "__rot", "test", 1)
	GameDisease.entry(h, "__rot")["years_in_stage"] = 1.0
	d.rest()
	var e := GameDisease.entry(h, "__rot")
	_check(int(e["stage"]) == 1 and _near(float(e["years_in_stage"]), 1.0), "rest holds a later stage where it is (%.2f)" % float(e["years_in_stage"]))
	_check(_journal_has(d, "Bed rest keeps"), "holding is journaled")
	GameDisease._set_stage(h, e, 2)
	e["years_in_stage"] = 4.0
	var state := d.rng.state
	var lines: Array = []
	GameDisease.on_rest(d, lines)
	_check(lines.is_empty() and d.rng.state == state and _near(float(e["years_in_stage"]), 4.0), "rest does nothing for a last stage")
	_check(msgs.size() > 0, "rest returns its lines")
	_drop_test_disease("__rot")
	# With the real numbers, rest clears camp cough far more often than a year of work.
	var rest_clear := 0
	var work_clear := 0
	for i in 300:
		var a := _fresh(8000 + i)
		GameDisease.infect(a.heir, "camp_cough", "test")
		a.rest()
		if not GameDisease.has(a.heir, "camp_cough"):
			rest_clear += 1
		var b := _fresh(8000 + i)
		GameDisease.infect(b.heir, "camp_cough", "test")
		b._pass_years(1.0, [])
		if not GameDisease.has(b.heir, "camp_cough"):
			work_clear += 1
	_check(rest_clear > work_clear + 30, "rest helps recovery (%d vs %d of 300)" % [rest_clear, work_clear])


func _test_healers_recover_faster() -> void:
	var w := _fresh(1, "warrior")
	var c := _fresh(1, "cleric")
	_check(GameDisease.recovery_mult(c.heir) > GameDisease.recovery_mult(w.heir) + 0.3, "clerics recover faster (%.2f vs %.2f)" % [GameDisease.recovery_mult(c.heir), GameDisease.recovery_mult(w.heir)])
	for cls in ["cleric", "druid", "paladin", "shaman", "templar"]:
		var x := _fresh(1, cls)
		_check(GameDisease.recovery_mult(x.heir) > GameDisease.recovery_mult(w.heir), "%s recovers faster than a warrior" % cls)
	w.heir.inventory.append("prayer_beads")
	GameItems.equip(w, "prayer_beads")
	_check(_near(GameDisease.recovery_mult(w.heir), 1.1), "healing gear helps recovery (%.2f)" % GameDisease.recovery_mult(w.heir))
	GameDisease.infect(w.heir, "grave_rot", "test", 2)
	_check(GameDisease.recovery_mult(w.heir) < 1.0, "grave rot itself slows healing")


func _test_resistance() -> void:
	var human := _fresh(1, "mage", "human").heir
	var dwarf := _fresh(1, "mage", "dwarf").heir
	var orc := _fresh(1, "mage", "orc").heir
	_check(GameDisease.resistance(dwarf, "camp_cough") > GameDisease.resistance(human, "camp_cough") + 0.3, "dwarves are hardy (%.2f vs %.2f)" % [GameDisease.resistance(dwarf, "camp_cough"), GameDisease.resistance(human, "camp_cough")])
	_check(GameDisease.resistance(orc, "camp_cough") > GameDisease.resistance(human, "camp_cough") + 0.25, "orcs are hardy")
	_check(GameDisease.resist_sources(dwarf, "camp_cough")[0][1] == "dwarven hardiness", "resistance names its source")
	var necro := _fresh(1, "necromancer", "human").heir
	_check(GameDisease.resistance(necro, "grave_rot") > GameDisease.resistance(necro, "rat_plague") + 0.25, "a disease's own resistances count (necromancers and grave rot)")
	_check(GameDisease.resist_sources(necro, "grave_rot")[0][1] == "Necromancer training", "and are named: %s" % GameDisease.resist_sources(necro, "grave_rot")[0][1])
	var god := _fresh(1, "mage", "human").heir
	god.traits.append("demigod")
	_check(_near(GameDisease.resistance(god, "rat_plague"), 1.0), "divine blood is immune")
	var undead := _fresh(1, "mage", "human").heir
	undead.traits.append("undead")
	_check(_near(GameDisease.resistance(undead, "grave_rot"), 1.0), "the undead do not sicken")
	var cleric := _fresh(1, "cleric", "human").heir
	_check(GameDisease.resistance(cleric, "camp_cough") > GameDisease.resistance(human, "camp_cough"), "healers resist")
	var saint := _fresh(1, "mage", "dwarf").heir
	saint.traits.append_array(["saints_blood", "blessed"])
	saint.class_id = "cleric"
	_check(_near(GameDisease.resistance(saint, "camp_cough"), float(GameDisease.setting("resist_cap"))), "resistance is capped below immunity (%.2f)" % GameDisease.resistance(saint, "camp_cough"))
	# VIT: a warrior's frame resists more than a mage's, the same at level 1 and level 5000.
	var war := _fresh(1, "warrior", "human").heir
	var mage := _fresh(1, "mage", "human").heir
	var w1 := GameDisease._vit_resist(war)
	_check(w1 > GameDisease._vit_resist(mage) + 0.05, "VIT-heavy builds resist more (%.3f vs %.3f)" % [w1, GameDisease._vit_resist(mage)])
	war.level = 5000
	war.gen = 300
	_check(absf(GameDisease._vit_resist(war) - w1) < 0.06 and GameDisease._vit_resist(war) <= float(GameDisease.setting("vit_resist")["max"]), "VIT resistance holds its size at level 5000 (%.3f)" % GameDisease._vit_resist(war))
	var before := GameDisease._vit_resist(mage)
	for i in 20:
		mage.training["vit"] += 1.5
	_check(GameDisease._vit_resist(mage) > before, "training VIT raises resistance")


# ---------------------------------------------------------------- acquisition

func _test_level_milestones() -> void:
	var saved: float = GameDisease.setting("milestone_chance")
	GameData.diseases["settings"]["milestone_chance"] = 1.0
	var d := _fresh(31, "mage", "human")
	var h := d.heir
	_check(h.disease_level == 1, "a founder starts with no milestones rolled")
	h.level = 4
	var msgs: Array = []
	GameDisease.on_years(d, 1.0, msgs)
	_check(h.diseases.is_empty() and h.disease_level == 4, "no roll below the first milestone")
	h.level = 5
	GameDisease.on_years(d, 1.0, msgs)
	_check(h.diseases.size() == 1 and h.disease_level == 5, "level 5 brings a sure roll at chance 1.0 (%s)" % str(h.diseases))
	_check(str(h.diseases[0]["source"]) == "level", "the source is recorded")
	var mild: String = h.diseases[0]["id"]
	_check(GameDisease.def(mild)["vectors"].has("milestone"), "a level milestone brings a common sickness (%s)" % mild)
	_check(msgs.any(func(l): return GameDisease.disease_name(mild) in str(l)), "catching it is journaled: %s" % str(msgs))
	var before := h.diseases.size()
	var state := d.rng.state
	GameDisease._level_rolls(d, msgs)
	_check(h.diseases.size() == before and d.rng.state == state, "the same milestone is not rolled twice")
	h.level = 40
	GameDisease._level_rolls(d, msgs)
	_check(h.diseases.size() == before + 3 and h.disease_level == 40, "levels 10, 20 and 35 each roll once (%d)" % h.diseases.size())
	# The divine are never touched, and a resisted roll that mattered says so.
	var g := _fresh(32, "mage", "human")
	g.heir.traits.append("demigod")
	g.heir.level = 20
	var gm: Array = []
	GameDisease.on_years(g, 1.0, gm)
	_check(g.heir.diseases.is_empty(), "divine heirs shrug off every milestone")
	_check(gm.any(func(l): return "divine blood keeps" in str(l)), "and the journal says why: %s" % str(gm))
	GameData.diseases["settings"]["milestone_chance"] = saved
	# With the real chance, most rolls are shrugged off: about chance * (1 - resistance).
	var caught := 0
	var n := 500
	for i in n:
		var t := _fresh(9000 + i, "mage", "human")
		t.heir.level = 5
		GameDisease.on_years(t, 0.25, [])
		caught += 1 if not t.heir.diseases.is_empty() else 0
	var expect := saved * (1.0 - GameDisease.resistance(_fresh(1, "mage", "human").heir, "camp_cough"))
	_check(absf(float(caught) / n - expect) < 0.035, "milestone catch rate near %.3f (%.3f)" % [expect, float(caught) / n])
	_check(float(caught) / n < 0.15, "most milestone rolls are shrugged off")
	# Level milestones reach the level cap with sensible spacing.
	var ms: Array = GameDisease.setting("level_milestones")
	_check(int(ms[0]) >= 5 and int(ms.back()) == int(GameData.bal("level_cap")), "milestones run from early levels to the cap")
	_check(ms.filter(func(x): return int(x) <= 100).size() <= 7 and ms.filter(func(x): return int(x) > 1000).size() >= 6, "spaced wider as levels climb")
	# Swamps breed their own fevers.
	var bog := 0
	var plain := 0
	for i in 300:
		var a := _fresh(9500 + i)
		a.world.visit("mirefen")
		var p1 := GameDisease._milestone_pick(a)
		bog += 1 if p1 in ["bog_fever", "shaking_ague"] else 0
		a.world.visit("hearthmere")
		var p2 := GameDisease._milestone_pick(a)
		plain += 1 if p2 in ["bog_fever", "shaking_ague"] else 0
	_check(bog > plain * 3 / 2, "swamp fevers come up more in the swamp (%d vs %d)" % [bog, plain])


func _test_contagion_check() -> void:
	var d := _fresh()
	var h := d.heir
	var line := GameDisease.contagion_check(d, h, "grave_rot", 1.0, "corpse")
	_check(GameDisease.has(h, "grave_rot") and "Grave Rot" in line and "dead" in line, "a sure exposure infects: %s" % line)
	_check(str(GameDisease.entry(h, "grave_rot")["source"]) == "corpse", "source kept")
	_check(GameDisease.contagion_check(d, h, "grave_rot", 1.0, "corpse") == "", "no second infection, no line")
	var state := d.rng.state
	_check(GameDisease.contagion_check(d, h, "bog_fever", 0.0, "corpse") == "" and not GameDisease.has(h, "bog_fever"), "zero chance never infects")
	_check(d.rng.state == state, "a zero chance does not roll")
	var g := _fresh()
	g.heir.traits.append("demigod")
	line = GameDisease.contagion_check(g, g.heir, "rat_plague", 1.0, "vial")
	_check(not GameDisease.has(g.heir, "rat_plague") and "keeps it off" in line, "immunity turns a sure exposure away: %s" % line)
	var got := 0
	var n := 800
	for i in n:
		var t := _fresh(10000 + i, "mage", "human")
		GameDisease.contagion_check(t, t.heir, "grave_rot", 0.3, "corpse")
		got += 1 if GameDisease.has(t.heir, "grave_rot") else 0
	var expect := 0.3 * (1.0 - GameDisease.resistance(_fresh(1, "mage", "human").heir, "grave_rot"))
	_check(absf(float(got) / n - expect) < 0.05, "exposure rate matches chance x (1 - resistance) (%.3f vs %.3f)" % [float(got) / n, expect])


func _test_corpse_risk() -> void:
	var d := _fresh()
	d.world.visit("hearthmere")
	var r := GameDisease.corpse_risk(d, "skeleton")
	_check(r.get("id", "") == "grave_rot" and float(r.get("chance", 0.0)) > 0.0, "skeletons carry grave rot: %s" % str(r))
	_check(GameDisease.corpse_risk(d, "slime").get("id", "") == "bog_fever", "slimes carry bog fever")
	_check(GameDisease.corpse_risk(d, "wolf").is_empty(), "a plains wolf is clean")
	d.world.visit("hollow_barrow")
	_check(GameDisease.corpse_risk(d, "wolf").get("id", "") == "grave_rot", "anything dead in a crypt carries grave rot")
	d.world.visit("brinehaven")
	_check(GameDisease.corpse_risk(d, "bandit").get("id", "") == "rat_plague", "coast bandits carry plague")


func _test_family_contagion() -> void:
	_add_test_disease("__rot", [0.0, 0.0, 0.0], 0.0, {"spouse": 1.0, "child": 1.0})
	var d := _fresh(55, "mage", "human")
	var h := d.heir
	h.age = h.family_min_age()
	d.found_family()
	_check(h.spouse != null and not h.children.is_empty(), "a family")
	GameDisease.infect(h, "__rot", "test")
	var msgs: Array = []
	GameDisease._spread_home(d, 1.0, msgs)
	_check(GameDisease.has(h.spouse, "__rot"), "a sure contagion reaches the spouse")
	_check(h.children.all(func(c): return GameDisease.has(c, "__rot") or GameDisease.resistance(c, "__rot") > 0.0), "and the children")
	_check(msgs.any(func(l): return "'s spouse " in str(l)), "spreading is journaled: %s" % str(msgs))
	# The family is nursed at home and clears.
	GameDisease.cure(h, "__rot")
	for i in 20:
		GameDisease._mend_home(d, 1.0, msgs)
	_check(GameDisease.household(h).all(func(m): return m.diseases.is_empty()), "the family recovers at home")
	_check(int(GameDisease.entry(h.spouse, "__rot").get("stage", 0)) == 0, "family sickness never worsened")
	_drop_test_disease("__rot")
	# Real numbers: rat plague reaches a spouse at its data rate (at most 2% a year), less resistance.
	var got := 0
	var n := 400
	for i in n:
		var t := _fresh(11000 + i, "mage", "human")
		t.heir.age = t.heir.family_min_age()
		t.found_family()
		var sp := t.heir.spouse
		GameDisease.infect(t.heir, "rat_plague", "test")
		var res := GameDisease.resistance(sp, "rat_plague")
		if GameDisease.pass_on(t, t.heir, sp, "rat_plague", "spouse", 1.0) != "":
			got += 1
		_check(res < 1.0 or not GameDisease.has(sp, "rat_plague"), "an immune spouse never catches it")
	var rate := GameDisease.contagion_chance("rat_plague", "spouse")
	_check(absf(float(got) / n - rate * 0.85) < 0.02, "plague reaches a spouse about %.3f a year (%.3f)" % [rate, float(got) / n])
	_check(GameDisease.pass_on(_fresh(), _fresh().heir, _fresh().heir, "lockjaw", "spouse", 5.0) == "", "lockjaw is not catching")


func _test_birth_and_succession() -> void:
	_add_test_disease("__rot", [0.0, 0.0, 0.0], 0.0, {"birth": 1.0})
	var d := _fresh(66, "mage", "human")
	var h := d.heir
	h.age = h.family_min_age()
	GameDisease.infect(h, "__rot", "test")
	d.found_family()
	_check(_journal_has(d, "is born with Test Rot"), "births journaled")
	var baby := GameHeir.new()
	baby.class_id = "mage"
	baby.name = "Wren"
	var lines := GameDisease.on_birth(d, baby)
	_check(GameDisease.has(baby, "__rot") and lines == ["Wren is born with Test Rot."], "a sure birth contagion: born with it (%s)" % str(lines))
	_check(str(GameDisease.entry(baby, "__rot")["source"]) == "birth", "source is birth")
	var born_sick: Array = h.children.filter(func(c): return GameDisease.has(c, "__rot"))
	# The next heir starts out sick and the journal says so.
	var sick_child: GameHeir = born_sick[0] if not born_sick.is_empty() else h.children[0]
	GameDisease.infect(sick_child, "__rot", "birth")
	h.tainted_gear = ["dead_mans_hauberk"]
	d._die("old age")
	d.choose_heir(h.children.find(sick_child))
	_check(d.heir == sick_child and GameDisease.has(d.heir, "__rot"), "the chosen heir starts infected")
	_check(_journal_has(d, "still sick with Test Rot"), "the new heir's sickness is journaled")
	_check(d.heir.tainted_gear == ["dead_mans_hauberk"], "hidden taints pass with the gear")
	_check(d.heir.disease_level == 1, "the new heir's milestones start over")
	_check(d.heir.max_hp() == d.heir.hp, "the new heir starts at full (sick) health")
	_drop_test_disease("__rot")
	# Real numbers: a pox-sick parent's newborns are rarely born with it.
	var born := 0
	var kids := 0
	for i in 200:
		var t := _fresh(12000 + i, "mage", "human")
		t.heir.age = t.heir.family_min_age()
		GameDisease.infect(t.heir, "blister_pox", "test")
		t.found_family()
		kids += t.heir.children.size()
		born += t.heir.children.filter(func(c): return GameDisease.has(c, "blister_pox")).size()
	_check(kids > 0 and float(born) / kids <= 0.02, "few are born sick, at most 2%% (%d of %d)" % [born, kids])


# ---------------------------------------------------------------- treatment

func _test_temple_cure() -> void:
	var d := _fresh()
	var h := d.heir
	d.world.visit("hearthmere")
	GameDisease.infect(h, "rat_plague", "test")
	var p0 := GameDisease.cure_price(d, "rat_plague")
	_check(p0 == int(round(float(GameDisease.setting("cure_cost")) * 2.0)), "plague cure at gen 1 stage 1 (%d)" % p0)
	GameDisease._set_stage(h, GameDisease.entry(h, "rat_plague"), 2)
	var p2 := GameDisease.cure_price(d, "rat_plague")
	_check(p2 == int(round(p0 * (1.0 + 2.0 * float(GameDisease.setting("cure_stage_step"))))), "later stages cost more (%d)" % p2)
	GameDisease.infect(h, "camp_cough", "test")
	_check(GameDisease.cure_price(d, "camp_cough") < p0, "mild sicknesses cost less to cure")
	h.gold = 10
	var msg := GameDisease.temple_cure(d, "rat_plague")
	_check(GameDisease.has(h, "rat_plague") and h.gold == 10, "no cure without the gold (%s)" % msg)
	h.gold = 10000
	d.world.visit("ironford")
	GameDisease.temple_cure(d, "rat_plague")
	_check(GameDisease.has(h, "rat_plague") and h.gold == 10000, "no cure without a temple")
	d.world.visit("hearthmere")
	msg = GameDisease.temple_cure(d, "rat_plague")
	_check(not GameDisease.has(h, "rat_plague") and h.gold == 10000 - p2, "the priests cure it (%s)" % msg)
	_check(GameDisease.temple_cure(d, "rat_plague").contains("not sick"), "cannot cure what is not there")
	d.gen = 300
	h.gen = 300
	var p300 := GameDisease.cure_price(d, "camp_cough")
	_check(p300 == int(round(float(GameDisease.setting("cure_cost")) * 0.6 * GameData.enemy_scale(300))), "cure price scales with generation (%d)" % p300)
	print("  cures: plague gen1 stage1 %dg, stage3 %dg; cough gen300 %dg" % [p0, p2, p300])


func _test_remedies() -> void:
	var d := _fresh()
	var h := d.heir
	d.world.visit("hearthmere")
	h.gold = 1000
	h.inventory = []
	_check("willowbark_tonic" in GameItems.stock(d, "store") and "gravewort_poultice" in GameItems.stock(d, "temple"), "remedies at the store and temple")
	for i in 5:
		GameItems.buy(d, "willowbark_tonic")
	_check(GameItems.count(h, "willowbark_tonic") == 5, "remedies stack (%d)" % GameItems.count(h, "willowbark_tonic"))
	var g := h.gold
	var msg := GameItems.buy(d, "willowbark_tonic")
	_check(GameItems.count(h, "willowbark_tonic") == 5 and h.gold == g, "the stack is full at 5 (%s)" % msg)
	_check(h.equipment.values().all(func(x): return GameItems.stack_max(x) == 0), "remedies are never worn")
	msg = GameDisease.use_remedy(d, "willowbark_tonic")
	_check(GameItems.count(h, "willowbark_tonic") == 5, "a remedy with nothing to treat is not spent (%s)" % msg)
	GameDisease.infect(h, "camp_cough", "test")
	msg = GameDisease.use_remedy(d, "willowbark_tonic")
	_check(not GameDisease.has(h, "camp_cough") and GameItems.count(h, "willowbark_tonic") == 4, "a tonic clears a first-stage cough (%s)" % msg)
	GameDisease.infect(h, "camp_cough", "test", 2)
	GameDisease.entry(h, "camp_cough")["years_in_stage"] = 3.0
	msg = GameDisease.use_remedy(d, "willowbark_tonic")
	var e := GameDisease.entry(h, "camp_cough")
	_check(int(e["stage"]) == 1 and _near(float(e["years_in_stage"]), 0.0), "a tonic eases a later stage by one (%s)" % msg)
	GameDisease.infect(h, "grave_rot", "test")
	msg = GameDisease.use_remedy(d, "willowbark_tonic", "grave_rot")
	_check(GameDisease.has(h, "grave_rot") and GameItems.count(h, "willowbark_tonic") == 3, "the wrong remedy does nothing and is kept (%s)" % msg)
	h.inventory.append("smugglers_theriac")
	GameDisease.infect(h, "grey_veil", "test", 2)
	_check(GameDisease.remedy_target(h, "smugglers_theriac") == "grey_veil", "a remedy goes for the worst it can treat")
	GameDisease.use_remedy(d, "smugglers_theriac")
	_check(not GameDisease.has(h, "grey_veil"), "theriac (power 3) clears the last stage of the Grey Veil")
	_check(GameDisease.treatable_by("gravewort_poultice").has("grave_rot"), "poultice treats grave rot")
	# Remedies cost more in later generations, as everything does.
	d.gen = 300
	_check(GameItems.price(d, "willowbark_tonic") == int(round(20.0 * GameData.enemy_scale(300))), "remedy price scales")
	_check(GameItems.describe("willowbark_tonic").begins_with("Eases"), "a remedy describes what it does: %s" % GameItems.describe("willowbark_tonic"))


func _test_black_market() -> void:
	var d := _fresh()
	var h := d.heir
	d.world.visit("hearthmere")
	_check(GameDisease.BLACK_MARKET not in GameItems.shops_here(d), "no black market in Hearthmere")
	d.world.visit("brinehaven")
	_check(GameItems.shops_here(d).back() == GameDisease.BLACK_MARKET, "Brinehaven has a black market, listed last")
	var stock := GameItems.stock(d, GameDisease.BLACK_MARKET)
	_check(stock.has("nightshade_oil") and stock.has("plague_vial") and stock.has("dead_mans_hauberk") and stock.has("smugglers_theriac"), "toxins, vials, bargains and theriac: %s" % str(stock))
	_check(not stock.has("barrow_plate") and not stock.has("grey_veil_vial"), "tier 3 smuggling only in Kingshold")
	_check(GameItems.price(d, "dead_mans_hauberk") * 2 < GameItems.price(d, "chainmail"), "bargains are cheap")
	h.gold = 5000
	_check(d.echo_total("infamy") == 0.0, "no infamy yet")
	GameItems.buy(d, "nightshade_oil")
	var step := float(GameDisease.setting("black_market_infamy"))
	_check(_near(d.echo_total("infamy"), step), "a smuggler's deal nudges infamy (%.3f)" % d.echo_total("infamy"))
	for i in 6:
		GameItems.buy(d, "nightshade_oil")
	_check(GameItems.count(h, "nightshade_oil") == 5, "toxins stack to 5 (%d)" % GameItems.count(h, "nightshade_oil"))
	_check(_near(d.echo_total("infamy"), step * 5.0), "every deal counts, refused ones do not (%.3f)" % d.echo_total("infamy"))
	GameItems.buy(d, "plague_vial")
	_check(GameItems.count(h, "plague_vial") == 1 and GameItems.stack_max("plague_vial") == 3, "plague vials carried three at most")
	var vial: Dictionary = GameItems.item_def("plague_vial")["vial"]
	_check(GameDisease.def(str(vial["disease"])).size() > 0 and float(vial["splash"]) > 0.0, "a vial names its plague and its splash risk")
	var tox: Dictionary = GameItems.item_def("nightshade_oil")["toxin"]
	_check(float(tox["poison_pct"]) > 0.0 and int(tox["turns"]) > 0 and str(tox["backfire"]["disease"]) == "nightshade_palsy", "a toxin has its battle numbers")
	GameItems.buy(d, "steel_sword")
	_check(_near(d.echo_total("infamy"), step * 6.0), "the honest forge leaves the name alone")
	var price_before := GameItems.price(d, "iron_sword")
	_check(price_before > 50, "infamy raises honest prices (%d)" % price_before)
	_check(_near(d.echo_total("infamy"), step * 6.0) and d.describe_echo(d.echoes[0]).contains("smugglers"), "the echo reads: %s" % d.describe_echo(d.echoes[0]))
	# Selling and the gear tab treat stacks one at a time.
	var g := h.gold
	GameItems.sell(d, "nightshade_oil")
	_check(GameItems.count(h, "nightshade_oil") == 6 - 2 and h.gold > g, "selling one from a stack")


func _test_bargains() -> void:
	var d := _fresh(90, "warrior", "human")
	var h := d.heir
	d.world.visit("brinehaven")
	h.gold = 5000
	h.equipment["armor"] = ""
	h.inventory = []
	var saved: float = GameDisease.setting("bargain_taint_chance")
	GameData.diseases["settings"]["bargain_taint_chance"] = 1.0
	var msg := GameItems.buy(d, "dead_mans_hauberk")
	_check(h.equipment["armor"] == "dead_mans_hauberk", "the bargain goes on at once")
	_check(GameDisease.has(h, "weeping_sores") and "came cheap for a reason" in msg, "a tainted bargain shows itself when worn: %s" % msg)
	_check(str(GameDisease.entry(h, "weeping_sores")["source"]) == "bargain" and h.tainted_gear.is_empty(), "taint spent")
	GameItems.unequip(d, "armor")
	GameDisease.cure(h, "weeping_sores")
	GameItems.equip(d, "dead_mans_hauberk")
	_check(not GameDisease.has(h, "weeping_sores"), "the second wearing is safe")
	# Bought into the pack: it waits until worn. Selling it takes the taint away.
	h.equipment["weapon"] = "iron_sword"
	msg = GameItems.buy(d, "notched_falchion")
	_check(h.tainted_gear == ["notched_falchion"] and not GameDisease.has(h, "lockjaw") and not "reason" in msg, "a packed bargain hides its taint: %s" % msg)
	GameItems.sell(d, "notched_falchion")
	_check(h.tainted_gear.is_empty(), "selling a bargain drops its taint")
	GameItems.buy(d, "notched_falchion")
	msg = GameItems.equip(d, "notched_falchion")
	_check(GameDisease.has(h, "lockjaw") and "Notched Falchion" in msg, "equipping shows the taint: %s" % msg)
	GameData.diseases["settings"]["bargain_taint_chance"] = 0.0
	GameItems.buy(d, "pawned_amulet")
	_check(not h.tainted_gear.has("pawned_amulet") or float(GameItems.item_def("pawned_amulet")["taint"].get("chance", 0.0)) > 0.0, "an item's own taint chance wins over the default")
	GameData.diseases["settings"]["bargain_taint_chance"] = saved
	# About half of all bargains are tainted.
	var tainted := 0
	for i in 200:
		var t := _fresh(13000 + i)
		t.world.visit("brinehaven")
		t.heir.gold = 1000
		t.heir.equipment["armor"] = "leather_armor"
		GameItems.buy(t, "dead_mans_hauberk")
		tainted += 1 if t.heir.tainted_gear.has("dead_mans_hauberk") else 0
	_check(absf(float(tainted) / 200.0 - saved) < 0.1, "bargain taint rate near %.2f (%d of 200)" % [saved, tainted])
	# A save can list gear whose taint the data has since dropped: wearing it is harmless.
	var s := _fresh(91)
	s.heir.inventory = ["steel_sword"]
	s.heir.tainted_gear = ["steel_sword"]
	var sick := s.heir.diseases.size()
	msg = GameItems.equip(s, "steel_sword")
	_check(s.heir.tainted_gear.is_empty() and s.heir.diseases.size() == sick and s.heir.equipment["weapon"] == "steel_sword" and not "reason" in msg and not "carried" in msg, "a stale taint is dropped quietly: %s" % msg)


func _test_bot() -> void:
	# A mild first-stage cough: the bot buys a tonic (cheaper than the priests) and takes it.
	var d := _fresh(101)
	var h := d.heir
	d.world.visit("hearthmere")
	h.gold = 2000
	h.inventory = []
	GameDisease.infect(h, "camp_cough", "test")
	GameItems.bot_tick(d)
	_check(h.diseases.is_empty(), "the bot treats a cough")
	_check(_journal_has(d, "Willowbark Tonic"), "with a tonic, not the temple")
	# A carried remedy is used anywhere, even in the wilds.
	d.world.visit("whisperwood")
	h.inventory.append("willowbark_tonic")
	GameDisease.infect(h, "red_flux", "test")
	GameItems.bot_tick(d)
	_check(h.diseases.is_empty() and not h.inventory.has("willowbark_tonic"), "the bot takes a carried remedy in the wilds")
	GameDisease.infect(h, "grave_rot", "test", 1)
	GameItems.bot_tick(d)
	_check(GameDisease.has(h, "grave_rot"), "nothing to be done in the wilds without a remedy")
	# Deadly plague at its last stage in a temple town: treated at once.
	d.world.visit("hearthmere")
	GameDisease.infect(h, "rat_plague", "test", 2)
	GameItems.bot_tick(d)
	_check(h.diseases.is_empty(), "the bot cures plague and rot in town (%s)" % str(h.diseases))
	# The potion reserve is kept.
	h.gold = GameItems.bot_reserve(d) + 5
	GameDisease.infect(h, "rat_plague", "test", 2)
	GameItems.bot_tick(d)
	_check(GameDisease.has(h, "rat_plague") and h.gold == GameItems.bot_reserve(d) + 5, "no treatment that breaks the reserve")
	# Never a bargain, even rich in Kingshold with an empty kit.
	var k := _fresh(102)
	k.world.visit("kingshold")
	k.heir.gold = 100000
	k.heir.equipment = {"weapon": "", "armor": "", "trinket": ""}
	k.heir.inventory = ["barrow_plate"]
	GameItems.bot_tick(k)
	_check(not k.heir.equipment.values().any(func(x): return GameDisease.is_bargain(x)), "the bot never wears a bargain (%s)" % str(k.heir.equipment))
	_check(k.heir.inventory.filter(func(x): return GameDisease.is_bargain(x)) == ["barrow_plate"], "and never buys one")
	_check(k.echo_total("infamy") == 0.0, "the bot keeps away from smugglers")


# ---------------------------------------------------------------- saves

func _roundtrip(d: GameDynasty) -> GameDynasty:
	return GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))


func _test_save_load() -> void:
	var d := _fresh(111, "mage", "human")
	var h := d.heir
	h.age = h.family_min_age()
	d.found_family()
	GameDisease.infect(h, "camp_cough", "level")
	GameDisease.infect(h, "rat_plague", "corpse", 1)
	GameDisease.entry(h, "rat_plague")["years_in_stage"] = 0.3125
	GameDisease.infect(h.spouse, "camp_cough", "family")
	GameDisease.infect(h.children[0], "blister_pox", "birth")
	h.tainted_gear = ["pawned_amulet"]
	h.disease_level = 20
	d._pass_years(0.33, [])
	var g := _roundtrip(d)
	_check(JSON.stringify(g.heir.diseases) == JSON.stringify(h.diseases), "diseases survive save/load")
	_check(g.heir.tainted_gear == h.tainted_gear and g.heir.disease_level == h.disease_level, "taints and milestone level survive")
	_check(GameDisease.has(g.heir.spouse, "camp_cough") and GameDisease.has(g.heir.children[0], "blister_pox") == GameDisease.has(h.children[0], "blister_pox"), "family sickness survives")
	_check(typeof(g.heir.diseases[0]["stage"]) == TYPE_INT, "stage is an int again after JSON")
	_check(g.heir.max_hp() == h.max_hp() and _near(g.heir.attack_power(), h.attack_power()), "derived stats match after load")
	_check(JSON.stringify(g.to_dict()) == JSON.stringify(d.to_dict()), "a second save is identical")
	# Behaviour is identical after the round trip.
	for i in 40:
		for x in [d, g]:
			if x.state == "life":
				GameBot.step(x)
			elif x.state == "succession":
				x.choose_heir(0)
	_check(JSON.stringify(g.to_dict()) == JSON.stringify(d.to_dict()), "40 steps later, the loaded game played out the same")
	_check(d.journal.slice(-20) == g.journal.slice(-20), "same journal")
	# A bad save is cleaned rather than crashing.
	var raw := [{"id": "camp_cough", "stage": 9.0, "years_in_stage": 1.23456789}, {"id": "camp_cough", "stage": 0}, {"id": "gone_now"}, "junk"]
	var clean := GameDisease.load_list(raw)
	_check(clean.size() == 1 and int(clean[0]["stage"]) == 2 and _near(float(clean[0]["years_in_stage"]), 1.2346), "load_list clamps, snaps and drops junk: %s" % str(clean))
	_check(GameDisease.load_list(null).is_empty(), "missing list loads empty")


func _test_old_saves() -> void:
	for tag in ["pr3_life", "pr3_succession", "pr4_life", "pr4_succession"]:
		var txt := FileAccess.get_file_as_string("res://tests/fixtures/old_save_%s.json" % tag)
		if txt == "":
			_check(false, "%s fixture exists" % tag)
			continue
		var raw: Dictionary = JSON.parse_string(txt)
		var d := GameDynasty.from_dict(raw)
		_check(d.heir.diseases.is_empty() and d.heir.tainted_gear.is_empty(), "%s: an old save loads well" % tag)
		_check(d.heir.disease_level == d.heir.level, "%s: no flood of milestone rolls for levels already reached" % tag)
		var lines := d.journal.size()
		if d.state == "life":
			d.work()
			_check(not d.journal.slice(lines).any(func(l): return "comes down with" in str(l) or "picks up" in str(l)), "%s: loading does not roll old milestones" % tag)
		var j := JSON.stringify(d.to_dict())
		_check(JSON.stringify(GameDynasty.from_dict(JSON.parse_string(j)).to_dict()) == j, "%s round-trips with the new fields" % tag)


func _run(seed_value: int) -> Array:
	var d := GameDynasty.new_game(seed_value, "", "warrior", "faetouched", "human")
	var saved: float = GameDisease.setting("milestone_chance")
	GameData.diseases["settings"]["milestone_chance"] = 0.6
	for i in 400:
		if d.state == "succession":
			d.choose_heir(0)
		GameBot.step(d)
	GameData.diseases["settings"]["milestone_chance"] = saved
	return [d.journal.duplicate(), JSON.stringify(d.to_dict())]


func _test_determinism() -> void:
	var a := _run(4242)
	var b := _run(4242)
	_check(a[0] == b[0] and a[1] == b[1], "same seed, same sicknesses and saves")
	_check((a[0] as Array).any(func(l): return "Hard years" in str(l) or "picks up" in str(l) or "finds" in str(l) or "goes round" in str(l)), "the run saw some sickness")
	_check(_run(4243)[1] != a[1], "a different seed differs")


# ---------------------------------------------------------------- text

func _test_text() -> void:
	var d := _fresh(120)
	var h := d.heir
	GameDisease.infect(h, "rat_plague", "test", 2)
	var info := GameDisease.describe_entry(GameDisease.entry(h, "rat_plague"))
	_check(info["name"] == "Rat Plague" and info["stage"] == 3 and info["stages"] == 3 and info["stage_name"] == "Black Swellings", "describe_entry: %s" % str(info))
	_check(info["outlook"] == "can kill: 10% a year", "deadly outlook: %s" % info["outlook"])
	_check(str(info["effects"]).begins_with("-20% max HP"), "effects text: %s" % info["effects"])
	GameDisease.infect(h, "camp_cough", "test")
	_check(GameDisease.outlook(GameDisease.entry(h, "camp_cough")) == "worsens in 2.0 years; may clear with rest", "mild outlook: %s" % GameDisease.outlook(GameDisease.entry(h, "camp_cough")))
	_check(GameDisease.status_text(h) == "Rat Plague, Camp Cough", "status text")
	GameDisease.infect(h, "shaking_ague", "test", 2)
	_check(GameDisease.outlook(GameDisease.entry(h, "shaking_ague")) == "lingers; rarely clears without a cure", "chronic outlook with a slim natural chance")
	# Lines read their age.
	h.age = h.adult_age()
	_check(GameDisease.age_band(h) == "young" and GameDisease._caught_text(h, "camp_cough", "level").begins_with("Green to the road"), "a young heir's line")
	h.age = h.adult_age() + 20.0
	_check(GameDisease.age_band(h) == "adult" and GameDisease._caught_text(h, "camp_cough", "level").begins_with("Hard years"), "an adult's line")
	h.age = h.lifespan * 0.95
	_check(GameDisease.age_band(h) == "elder" and "slower to mend" in GameDisease._caught_text(h, "camp_cough", "level"), "an elder's line")
	_check(GameDisease._worse_text(h, GameDisease.entry(h, "camp_cough")).begins_with("At %d" % int(h.age)), "an elder's worsening line")
	for dz in GameDisease.all():
		for i in GameDisease.stages(dz["id"]).size():
			_check(not "_" in GameDisease._fx(dz["id"], i), "%s stage %d effects read cleanly: %s" % [dz["id"], i, GameDisease._fx(dz["id"], i)])


# ---------------------------------------------------------------- whole lives

func _test_autopilot() -> void:
	var lives := 0
	var sick_end := 0
	var disease_deaths := 0
	var caught := 0
	for s in 6:
		var d := GameDynasty.new_game(500 + s, "", ["warrior", "mage", "cleric"][s % 3], "faetouched", ["human", "elf", "orc"][s % 3])
		for gen in 3:
			var start := d.journal.size()
			GameBot.live_life(d)
			lives += 1
			if not d.heir.diseases.is_empty():
				sick_end += 1
			if str(d.last_death.get("cause", "")).begins_with("taken by"):
				disease_deaths += 1
			caught += d.journal.slice(start).filter(func(l): return "comes down with" in str(l) or "picks up" in str(l) or "slower to mend" in str(l)).size()
			if d.state != "succession":
				break
			d.choose_heir(0)
		_check(d.heir.max_hp() > 0 and d.heir.hp >= 0, "seed %d plays on" % s)
	print("  autopilot: %d lives, %d caught a milestone sickness, %d ended sick, %d died of disease" % [lives, caught, sick_end, disease_deaths])
	_check(sick_end <= lives / 3, "few heirs die sick (%d of %d)" % [sick_end, lives])


# ---------------------------------------------------------------- screens

func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


func _find(n: Node, prefix: String) -> Button:
	if n is Button and (n as Button).is_visible_in_tree() and (n as Button).text.begins_with(prefix):
		return n
	for c in n.get_children():
		var b := _find(c, prefix)
		if b != null:
			return b
	return null


func _labels(n: Node, out: Array) -> Array:
	if n is Label:
		out.append((n as Label).text)
	if n is RichTextLabel:
		out.append((n as RichTextLabel).text)
	for c in n.get_children():
		_labels(c, out)
	return out


func _ui_tests() -> void:
	root.size = Vector2i(1280, 720)
	var d := _fresh(130, "warrior", "human")
	d.world.visit("brinehaven")
	d.heir.gold = 3000
	d.heir.equipment = {"weapon": "iron_sword", "armor": "leather_armor", "trinket": "copper_ring"}
	GameDisease.infect(d.heir, "red_flux", "test", 1)
	var changed := [0]
	var p: Control = ShopPanel.new()
	p.dynasty = d
	p.on_change = func(): changed[0] += 1
	root.add_child(p)
	await _frames()
	var bm := _find(p, "Black Market")
	_check(bm != null, "the shop has a Black Market tab in Brinehaven")
	if bm != null:
		bm.pressed.emit()
		await _frames()
		_check(p.tab == "black_market", "the tab opens")
		var text := _labels(p, [])
		_check(text.has("Toxins") and text.has("Plague Vials") and text.has("Remedies"), "black market shelves are labelled")
		var buy := _find(p, "Buy")
		buy.pressed.emit()
		await _frames()
		_check(d.heir.inventory.size() + d.heir.equipment.values().filter(func(x): return x != "").size() > 0 and changed[0] == 1, "buying through the panel works")
	var temple := _find(p, "Temple")
	temple.pressed.emit()
	await _frames()
	var cure := _find(p, "Cure")
	_check(cure != null and not cure.disabled, "the temple offers a cure")
	if cure != null:
		var sick := d.heir.diseases.size()
		cure.pressed.emit()
		await _frames()
		_check(d.heir.diseases.size() == sick - 1, "the Cure button cures")
	var store := _find(p, "Store")
	store.pressed.emit()
	await _frames()
	d.heir.inventory = []
	GameItems.buy(d, "willowbark_tonic")
	GameItems.buy(d, "willowbark_tonic")
	GameDisease.infect(d.heir, "camp_cough", "test")
	var gear := _find(p, "Gear")
	gear.pressed.emit()
	await _frames()
	_check(_labels(p, []).any(func(t): return "Willowbark Tonic  x2" in t), "a stack shows its count in the pack")
	var use := _find(p, "Use")
	_check(use != null and not use.disabled, "a remedy can be used from the Gear tab")
	if use != null:
		use.pressed.emit()
		await _frames()
		_check(not GameDisease.has(d.heir, "camp_cough") and GameItems.count(d.heir, "willowbark_tonic") == 1, "using it cures and spends one")
	p.queue_free()
	await _frames()
	_finish()
