## Skill trees: the data and validate() (and that it catches broken data), skill points at their
## milestones from level 1 to the cap, prerequisites and costs, every node's effect on stats,
## abilities and battle numbers, keystones changing the rule they claim, refunds (town or rest
## only, a fee by level), bloodline inheritance at succession (share, Fate and curses, blessings,
## determinism, the journal), companions' trees (hire, levels, spending, saves, old saves,
## successors), the autopilot's path, save/load and old saves, and the Skill Tree panel.
## Run: godot --headless --path . -s res://tests/test_game_trees.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const SkillTreePanel := preload("res://ui/play/skill_tree_panel.gd")
const FIXTURES := "res://tests/fixtures/"

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	GameData.load_all()
	test_data()
	test_broken_data()
	test_points()
	test_prerequisites_and_costs()
	test_every_node()
	test_battle_numbers()
	test_upgrades_in_battle()
	test_keystones()
	test_respec()
	test_inheritance()
	test_companions()
	test_companion_saves()
	test_bot()
	test_high_levels()
	test_save_load()
	test_old_saves()
	test_determinism()
	_ui_tests.call_deferred()


func _done() -> void:
	print("tree tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(cls: String = "warrior", level: int = 1, seed_val: int = 41) -> GameDynasty:
	var d := GameDynasty.new_game(seed_val, "Tess", cls, "faetouched", "human")
	d.pending_event = {}
	d.heir.level = level
	d.heir.spells = []
	d.heir.learn_spells()
	GameSkillTree.start(d.heir)
	d.heir.full_heal()
	return d


func _unit(cls: String, level: int = 3000) -> GameHeir:
	var u := GameHeir.new()
	u.name = "Probe"
	u.class_id = cls
	u.level = level
	u.learn_spells()
	GameSkillTree.start(u)
	u.full_heal()
	return u


## Gives a unit ranks without the rules for buying them (those are tested on their own).
func _give(u: GameHeir, ranks: Dictionary) -> void:
	for id in ranks:
		u.tree_ranks[id] = ranks[id]
	GameSkillTree.changed(u)


func _battle(d: GameDynasty, n: int = 1, creature: String = "goblin") -> GameBattle:
	var c := GameCombat.creature_def(creature)
	var foes: Array = []
	for i in n:
		foes.append(d._make_enemy(c, 1.0, 1.0, d.heir.level))
	d._begin_battle(foes, "hunt")
	return d.battle


func _sturdy(b: GameBattle) -> void:
	for e in b.enemies:
		e["hp"] = 10000000
		e["max_hp"] = 10000000
		e["atk"] = 0.0
		e["agi"] = 0
		e["def"] = 0.0


func _hire(d: GameDynasty, id: String) -> Dictionary:
	d.heir.gold += 10000000
	d.party.hire(d, id)
	return d.party.member(id)


# ---------------------------------------------------------------- data

func test_data() -> void:
	var problems := GameSkillTree.validate()
	ok(problems.is_empty(), "the tree data is sound: %s" % str(problems))
	var classes_with_trees := 0
	for tid in GameSkillTree.tree_ids():
		var t := GameSkillTree.tree(tid)
		var n := GameSkillTree.nodes_of(tid).size()
		ok(n >= 20 and n <= 35, "tree %s has %d nodes (20 to 35)" % [tid, n])
		var keys := GameSkillTree.nodes_of(tid).filter(func(id): return GameSkillTree.is_keystone(id))
		ok(keys.size() >= 1 and keys.size() <= 3, "tree %s has a few keystones (%d)" % [tid, keys.size()])
		if str(t["class"]) != "":
			classes_with_trees += 1
			ok(GameSkillTree.nodes_of(tid).all(func(id): return not GameSkillTree.inheritable(id)), "class tree %s passes nothing down" % tid)
		else:
			ok(GameSkillTree.nodes_of(tid).filter(func(id): return GameSkillTree.inheritable(id)).size() >= 4, "the bloodline tree has inheritable nodes")
	ok(classes_with_trees == GameData.starting_ids(GameData.classes).size(), "one tree per base class (%d)" % classes_with_trees)
	for c in GameData.classes:
		var trees := GameSkillTree.trees_for(c)
		var parents: Array = GameData.classes[c].get("parents", [])
		ok(trees.back() == "bloodline", "%s shares the bloodline tree" % c)
		if parents.is_empty():
			ok(trees.size() == 2 and str(GameSkillTree.tree(trees[0])["class"]) == c, "%s draws on its own tree" % c)
		else:
			ok(trees.size() == 3 and str(GameSkillTree.tree(trees[0])["class"]) in parents and str(GameSkillTree.tree(trees[1])["class"]) in parents, "hybrid %s draws on its parents' trees: %s" % [c, str(trees)])
	for k in GameSkillTree.keystone_ids():
		var ks := GameSkillTree.keystone(k)
		ok(str(ks["rule"]) in GameSkillTree.RULES and str(ks["drawback"]) != "", "keystone %s bends a known rule and names its price" % k)


## validate() catches each kind of broken data; the real data is put back after.
func test_broken_data() -> void:
	var real: Dictionary = GameData.skill_trees
	var real_keys: Dictionary = GameData.keystones
	var cases := {
		"unknown prerequisite": func(t): t["trees"][1]["nodes"][2]["requires"] = ["nowhere"],
		"cycle": func(t):
			t["trees"][1]["nodes"][0]["requires"] = [t["trees"][1]["nodes"][2]["id"]]
			t["trees"][1]["nodes"][0]["tier"] = 3,
		"unreachable": func(t): t["trees"][1]["nodes"][4]["requires"] = [t["trees"][1]["nodes"][4]["id"]],
		"unknown spell": func(t): t["trees"][2]["nodes"][3]["effect"] = {"abilities": [{"spell": "no_such_spell", "mult": 0.1}]},
		"field that means nothing": func(t): t["trees"][2]["nodes"][3]["effect"] = {"abilities": [{"spell": "cone_of_frost", "radius": 1}]},
		"unknown bonus": func(t): t["trees"][1]["nodes"][0]["effect"] = {"bonus": {"flying": 0.1}},
		"unknown keystone": func(t): t["trees"][1]["nodes"][15]["keystone"] = "nope",
		"inheritable class node": func(t): t["trees"][1]["nodes"][0]["inheritable"] = true,
		"duplicate id": func(t): t["trees"][1]["nodes"][1]["id"] = t["trees"][1]["nodes"][0]["id"],
		"same spot": func(t): t["trees"][1]["nodes"][1]["col"] = t["trees"][1]["nodes"][0]["col"],
		"bands short of the cap": func(t): t["settings"]["point_bands"] = [[30, 3], [90, 6]],
		"skill of another class": func(t): t["trees"][1]["nodes"][2]["effect"] = {"abilities": [{"skill": "firebolt", "mult": 0.1}]},
	}
	ok(str(real["trees"][1]["class"]) == "warrior" and str(real["trees"][2]["class"]) == "mage", "the cases below edit the warrior and mage trees")
	for what in cases:
		var t: Dictionary = real.duplicate(true)
		cases[what].call(t)
		GameData.skill_trees = t
		GameSkillTree.reindex()
		var p := GameSkillTree.validate()
		ok(not p.is_empty(), "validate() catches: %s %s" % [what, str(p.slice(0, 2))])
	var k: Dictionary = real_keys.duplicate(true)
	k["keystones"][0]["rule"] = "fly"
	GameData.skill_trees = real
	GameData.keystones = k
	GameSkillTree.reindex()
	ok(not GameSkillTree.validate().is_empty(), "validate() catches a keystone with an unknown rule")
	GameData.keystones = real_keys
	GameSkillTree.reindex()
	ok(GameSkillTree.validate().is_empty(), "the real data is back and sound")


# ---------------------------------------------------------------- points

func test_points() -> void:
	ok(GameSkillTree.points_at(1) == int(GameSkillTree.setting("start_points")), "a new heir has the starting point (%d)" % GameSkillTree.points_at(1))
	var at := {}
	for lv in [1, 30, 100, 5000, 99999]:
		at[lv] = GameSkillTree.points_at(lv)
	print("  skill points at level 1/30/100/5000/99999: ", at.values())
	ok(at[30] >= 5 and at[30] <= 14, "frequent early: %d by level 30" % at[30])
	ok(at[100] > at[30] and at[100] - at[30] <= at[30] + 2, "slower by level 100 (%d)" % at[100])
	ok(at[5000] > at[100] and at[5000] < at[100] * 6, "level 5,000 has more, not hundreds (%d)" % at[5000])
	ok(at[99999] > at[5000] and at[99999] - at[5000] < at[5000], "the cap brings the last few (%d)" % at[99999])
	var last := 0
	var mono := true
	for lv in range(1, 3000):
		var p := GameSkillTree.points_at(lv)
		mono = mono and p >= last and p - last <= 1
		last = p
	ok(mono, "points never fall and come one at a time")
	var agree := true
	for lv in [1, 2, 29, 30, 31, 89, 90, 299, 300, 1499, 5000, 24999, 25000, 95999]:
		var n := GameSkillTree.next_point_level(lv)
		agree = agree and n > lv and GameSkillTree.points_at(n) == GameSkillTree.points_at(lv) + 1 and GameSkillTree.points_at(n - 1) == GameSkillTree.points_at(lv)
	ok(agree, "next_point_level names the very level of the next point")
	ok(GameSkillTree.next_point_level(99999) == -1, "nothing after the cap")
	# Points come with levels gained, and the journal tells them when time passes.
	var d := _dyn("warrior", 1, 7)
	var h := d.heir
	ok(h.tree_points == 1 and h.tree_level == 1, "a new heir: 1 point at level 1")
	h.gain_xp(30000)
	ok(h.tree_points == GameSkillTree.points_at(h.level), "levelling up grants the milestones' points (%d at level %d)" % [h.tree_points, h.level])
	d.work()
	ok(d.journal.any(func(l): return str(l).find("skill point") >= 0 and str(l).begins_with(h.name + " earns")), "the journal tells the points earned")
	ok(h.tree_news == 0, "and tells them once")


# ---------------------------------------------------------------- buying

func test_prerequisites_and_costs() -> void:
	var d := _dyn("warrior", 1, 11)
	var h := d.heir
	ok(GameSkillTree.take_block(h, "w_heavy_blows").begins_with("Needs Brawn"), "a node needs a prerequisite: %s" % GameSkillTree.take_block(h, "w_heavy_blows"))
	ok(GameSkillTree.take_block(h, "m_focus").find("not on a Warrior's paths") >= 0, "another class's tree is shut: %s" % GameSkillTree.take_block(h, "m_focus"))
	ok(GameSkillTree.take_block(h, "nope") == "No such skill.", "unknown nodes are refused")
	var line := GameSkillTree.spend(d, "", "w_brawn")
	ok(h.tree_ranks.get("w_brawn", 0) == 1 and h.tree_points == 0 and line.find("Brawn 1/3") >= 0, "buying a rank costs its point: %s" % line)
	ok(d.journal.back() == line, "and is told in the journal")
	ok(GameSkillTree.spend(d, "", "w_brawn").find("costs 1 skill point") >= 0, "no points, no rank")
	h.tree_points = 10
	ok(GameSkillTree.take_block(h, "w_heavy_blows") == "", "the prerequisite with a rank opens the next node")
	ok(GameSkillTree.take_block(h, "w_iron_grip") == "", "either prerequisite is enough (Iron Grip after Brawn)")
	for i in 3:
		GameSkillTree.take(h, "w_heavy_blows")
	ok(GameSkillTree.take_block(h, "w_heavy_blows").find("mastered") >= 0, "a node stops at its max rank")
	ok(h.tree_points == 7, "each rank cost one point (%d left)" % h.tree_points)
	# A keystone costs more and refuses a second keystone of the same rule.
	var u := _unit("ninja", 500)
	u.tree_points = 100
	for id in ["r_quick", "r_fangs", "r_vitals", "r_killer"]:
		GameSkillTree.take(u, id)
	var before := u.tree_points
	ok(GameSkillTree.take(u, "r_assassin") and before - u.tree_points == GameSkillTree.cost("r_assassin") and GameSkillTree.cost("r_assassin") == 2, "a keystone costs 2 points")
	for id in ["k_stance", "k_palm", "k_strength", "k_body"]:
		GameSkillTree.take(u, id)
	ok(GameSkillTree.take_block(u, "k_diamond") == "", "a keystone of another rule may join")
	var u2 := _unit("warlock", 500)
	u2.tree_points = 100
	for id in ["m_focus", "m_searing", "m_lore", "m_mastery", "m_blood_magic", "n_grave", "n_cold", "n_bones", "n_hollow", "n_vigor"]:
		GameSkillTree.take(u2, id)
	ok(GameSkillTree.take_block(u2, "n_lich").find("cannot be joined") >= 0, "Blood Magic and a mana ward exclude each other: %s" % GameSkillTree.take_block(u2, "n_lich"))
	for id in ["n_drain", "n_dark", "n_patience"]:
		GameSkillTree.take(u2, id)
	ok(GameSkillTree.take_block(u2, "n_blood_rite").find("same rule") >= 0, "two keystones of one rule are refused: %s" % GameSkillTree.take_block(u2, "n_blood_rite"))
	# Not in the middle of a fight.
	h.tree_points = 3
	_battle(d)
	ok(GameSkillTree.spend(d, "", "w_thick_hide") == "Not in the middle of a fight.", "no buying mid-battle")
	d.battle = null


# ---------------------------------------------------------------- effects

func _user_of(tid: String) -> String:
	var c := str(GameSkillTree.tree(tid)["class"])
	return c if c != "" else "warrior"


## Every node of every tree does what it says for a unit of a class that uses it.
func test_every_node() -> void:
	var counted := 0
	for tid in GameSkillTree.tree_ids():
		var cls := _user_of(tid)
		for id in GameSkillTree.nodes_of(tid):
			var n := GameSkillTree.node(id)
			var e: Dictionary = n.get("effect", {})
			var plain := _unit(cls)
			var u := _unit(cls)
			_give(u, {id: GameSkillTree.max_rank(id)})
			var r := float(GameSkillTree.max_rank(id))
			var good := true
			var why: Array = []
			var stats: Dictionary = e.get("stats", {})
			for s in stats:
				for c in (GameSkillTree.CORE if s == "all" else [s]):
					if u.stat(c) <= plain.stat(c):
						good = false
						why.append("%s did not rise" % c)
			var bonus: Dictionary = e.get("bonus", {})
			for s in bonus:
				var got := u.trait_total(s) - plain.trait_total(s)
				if absf(got - float(bonus[s]) * r) > 0.0001:
					good = false
					why.append("%s changed by %s, not %s" % [s, got, float(bonus[s]) * r])
			for m in e.get("abilities", []):
				var pairs := _ability_pairs(m, plain, u)
				if pairs.is_empty():
					good = false
					why.append("no ability for %s" % str(m))
				for pr in pairs:
					for f in m:
						if f in ["skill", "spell", "feat"] or not GameSkillTree.fits(pr[0], f):
							continue
						if not _changed(pr[0], pr[1], f, float(m[f]) * r):
							good = false
							why.append("%s on %s" % [f, pr[0].get("id", "?")])
			if n.has("keystone"):
				var k := GameSkillTree.keystone(str(n["keystone"]))
				if not GameSkillTree.has_rule(u, str(k["rule"])):
					good = false
					why.append("rule %s missing" % k["rule"])
			ok(good, "node %s (%s) does what it says for a %s: %s" % [id, n["name"], cls, str(why)])
			ok(GameSkillTree.effect_lines(id, 1, u).size() > 0 and GameSkillTree.node_text(u, id).find(str(n["name"])) >= 0, "node %s has hover text" % id)
			counted += 1
	print("  nodes checked: ", counted)


## [base, upgraded] abilities an upgrade touches for this unit.
func _ability_pairs(m: Dictionary, plain: GameHeir, u: GameHeir) -> Array:
	var out: Array = []
	if m.has("skill"):
		var base: Array = plain.cls()["skills"]
		for i in base.size():
			if str(base[i]["id"]) == str(m["skill"]) or str(base[i]["type"]) == str(m["skill"]):
				out.append([base[i], GameSkillTree.skill(u, i)])
	elif m.has("spell"):
		for id in (GameCombat.spell_ids() if str(m["spell"]) == "*" else [str(m["spell"])]):
			out.append([GameCombat.spell(id), GameSkillTree.spell(u, id)])
	else:
		for id in (GameFeats.ids() if str(m["feat"]) == "*" else [str(m["feat"])]):
			out.append([GameFeats.def(id), GameSkillTree.feat(u, id)])
	return out


func _changed(a: Dictionary, b: Dictionary, f: String, v: float) -> bool:
	match f:
		"mult":
			return absf(float(b["mult"]) - float(a["mult"]) * (1.0 + v)) < 0.0001
		"cost":
			return float(b["mp"]) < float(a["mp"])
		"heal":
			return absf(float(b["pct_max_hp"]) - float(a["pct_max_hp"]) * (1.0 + v)) < 0.0001
		"crit":
			return absf(float(b.get("crit_bonus", 0.0)) - float(a.get("crit_bonus", 0.0)) - v) < 0.0001
		"pierce":
			return float(b.get("pierce", 0.0)) > float(a.get("pierce", 0.0))
		"cooldown":
			return int(b["cooldown"]) < int(a["cooldown"])
		"turns":
			var more := true
			for i in (a["statuses"] as Array).size():
				var st: Dictionary = a["statuses"][i]
				var was := int(st.get("turns", GameCombat.status_def(str(st["id"])).get("default_turns", 1)))
				more = more and int(b["statuses"][i]["turns"]) > was
			return more
	return float(b["target"][f]) > float(a["target"].get(f, 0.0))


## Bonuses reach the numbers a battle fights with.
func test_battle_numbers() -> void:
	var d := _dyn("warrior", 200, 21)
	var b := _battle(d)
	var before: Dictionary = b.unit_numbers(-1).duplicate()
	var heal_before := GameBattle.heal_amount(d.heir, d.heir, d.heir.cls()["skills"][1])
	_give(d.heir, {"w_brawn": 3, "w_iron_grip": 3, "w_veteran": 3, "w_broad_back": 3, "w_mail_drill": 3, "w_stubborn": 2,
		"b_luck": 2, "b_watchers": 2, "b_fury": 2, "b_hand": 2})
	b._nums.clear()
	var after := b.unit_numbers(-1)
	ok(float(after["str"]) > float(before["str"]), "STR and weapon damage raise the blow (%d -> %d)" % [int(before["str"]), int(after["str"])])
	ok(float(after["crit"]) > float(before["crit"]), "crit chance rises")
	ok(float(after["dodge"]) > float(before["dodge"]), "dodge rises")
	ok(float(after["def"]) > float(before["def"]), "defense rises")
	ok(int(after["max_hp"]) > int(before["max_hp"]), "max HP rises")
	ok(float(after["crit_mult"]) > float(before["crit_mult"]), "crits hit harder (%s)" % after["crit_mult"])
	ok(float(after["resist"]) > 0.0 and b.status_chance("heir", {"id": "stun", "chance": 1.0}, "enemy:0") < 1.0 - float(after["resist"]) + 0.0001, "the heir shrugs off more harm")
	ok(GameBattle.heal_amount(d.heir, d.heir, d.heir.cls()["skills"][1]) > heal_before, "healing is stronger")
	# MP back each turn.
	var m := _dyn("monk", 200, 22)
	var mb := _battle(m)
	_sturdy(mb)
	_give(m.heir, {"k_breath": 1, "k_snake": 1, "k_peace": 1, "k_spirit": 2})
	mb._nums.clear()
	m.heir.mp = 0
	mb.defend()
	var with_tree := m.heir.mp
	var plain := _dyn("monk", 200, 22)
	var pb := _battle(plain)
	_sturdy(pb)
	plain.heir.mp = 0
	pb.defend()
	ok(with_tree > plain.heir.mp, "Spirit Well brings more MP back each turn (%d > %d)" % [with_tree, plain.heir.mp])


## Upgraded skills, spells and feats are what the battle uses.
func test_upgrades_in_battle() -> void:
	var d := _dyn("warrior", 60, 31)
	_give(d.heir, {"w_brawn": 1, "w_heavy_blows": 3})
	var b := _battle(d)
	_sturdy(b)
	var up := 3.0 * float(GameSkillTree.node("w_heavy_blows")["effect"]["abilities"][0]["mult"])
	ok(absf(float(b.skill_info(0)["mult"]) - 1.9 * (1.0 + up)) < 0.0001, "the battle's Power Strike carries Heavy Blows (x%s)" % b.skill_info(0)["mult"])
	var hits: Array = b.expected_hits(-1, b.skill_info(0), 0)
	var plain := _dyn("warrior", 60, 31)
	var pb := _battle(plain)
	_sturdy(pb)
	ok(float(hits[0][1]) > float(pb.expected_hits(-1, pb.skill_info(0), 0)[0][1]) * (1.0 + up * 0.8), "and lands harder")
	# A cheaper heal costs less MP in battle.
	_give(d.heir, {"w_iron_grip": 1, "w_second_breath": 2})
	ok(b.skill_cost(1) < pb.skill_cost(1), "Second Breath costs less (%d < %d)" % [b.skill_cost(1), pb.skill_cost(1)])
	# A spell's bigger radius in the footprint; its longer burn on the foe.
	var m := _dyn("mage", 60, 32)
	_give(m.heir, {"m_focus": 1, "m_kindling": 2})
	var mb := _battle(m, 1)
	_sturdy(mb)
	var fb := mb.unit_spell(-1, "fireball")
	ok(float(fb["target"]["radius"]) == 4.5 and int(fb["statuses"][0]["turns"]) == 5, "Kindling: fireball radius 4.5, burn 5 turns")
	mb.heir.mp = 100000
	mb.cast_spell("fireball", 0)
	var burn := mb.status_of("enemy:0", "burn")
	ok(burn.is_empty() or int(burn["turns"]) >= 4, "the burn the battle lays lasts longer (%s)" % str(burn.get("turns", "resisted")))
	# A feat's shorter cooldown.
	var r := _dyn("rogue", 60, 33)
	r.heir.known_feats = ["feint"]
	r.heir.equipped_feats = ["feint"]
	_give(r.heir, {"r_quick": 1, "r_fangs": 1, "r_bait": 1})
	var rb := _battle(r)
	_sturdy(rb)
	rb.use_feat(0, 0)
	ok(int(rb.feat_ready["heir"]["feint"]) - 1 == GameFeats.cooldown("feint") - 1, "Bait and Switch: Feint is ready a turn sooner")
	# Companions fight with their trees too.
	var c := _dyn("mage", 60, 34)
	_hire(c, "bren_cask")
	var cb := _battle(c)
	var bren: GameHeir = cb.allies[0]
	ok(not bren.tree_ranks.is_empty() and float(GameSkillTree.skill(bren, 0)["mult"]) > 1.9, "Bren's Power Strike carries Bren's own tree (x%s)" % GameSkillTree.skill(bren, 0)["mult"])
	var opts := GameTactics.options(cb, 0)
	ok(opts.any(func(o): return int(o["skill"]) == 0 and float(o["ab"]["mult"]) > 1.9), "and the tactics weigh the upgraded skill")


# ---------------------------------------------------------------- keystones

func _keystone_unit(d: GameDynasty, ids: Array) -> void:
	var r := {}
	for id in ids:
		r[id] = 1
	_give(d.heir, r)
	d.heir.full_heal()


func test_keystones() -> void:
	# Juggernaut: never dodges, more armour.
	var d := _dyn("warrior", 80, 41)
	d.heir.training["agi"] = 4000.0
	var b := _battle(d)
	var before: Dictionary = b.unit_numbers(-1).duplicate()
	_keystone_unit(d, ["w_thick_hide", "w_mail_drill", "w_broad_back", "w_battle_hardened", "w_juggernaut"])
	b._nums.clear()
	var nums := b.unit_numbers(-1)
	ok(float(before["dodge"]) > 0.3 and float(nums["dodge"]) == 0.0 and bool(nums["no_dodge"]), "Juggernaut: a nimble heir's dodge is gone (%s -> 0)" % before["dodge"])
	ok(float(nums["def"]) > float(before["def"]) * 1.4, "and armour is up (%d -> %d)" % [int(before["def"]), int(nums["def"])])
	b.weather = {"dodge": 0.3}
	var misses := 0
	for i in 200:
		d.heir.hp = d.heir.max_hp()
		b.events = []
		b._enemy_act(0)
		misses += b.events.filter(func(e): return e["type"] == "miss").size()
	ok(misses == 0, "200 blows, none dodged, even in fog")
	ok(b.foe_threat(0) > 0.0, "the threat counts every blow")

	# Berserker's Wrath: more damage as HP runs out; healing weaker.
	var w := _dyn("duelist", 80, 42)
	var wb := _battle(w)
	_keystone_unit(w, ["w_brawn", "w_veteran", "w_iron_grip", "w_might", "w_berserker"])
	wb._nums.clear()
	var full := wb._dealt_mult("heir")
	w.heir.hp = maxi(1, w.heir.max_hp() / 10)
	var low := wb._dealt_mult("heir")
	ok(absf(full - 1.0) < 0.0001 and low > 1.5, "Wrath: x%.2f at full health, x%.2f near death" % [full, low])
	ok(absf(w.heir.trait_total("healing_power") - (-0.3) - _unit("duelist").trait_total("healing_power")) < 0.0001, "its price: 30% weaker healing")

	# Glass Cannon: more damage dealt and taken.
	var g := _dyn("mage", 80, 43)
	var gb := _battle(g)
	_keystone_unit(g, ["m_focus", "m_searing", "m_lore", "m_mastery", "m_glass_cannon"])
	gb._nums.clear()
	ok(absf(gb._dealt_mult("heir") - 1.3) < 0.0001, "Glass Cannon: x1.3 damage dealt")
	ok(absf(float(gb.unit_numbers(-1)["taken"]) - 1.35) < 0.0001, "and x1.35 damage taken")
	var plain := _dyn("mage", 80, 43)
	var pb := _battle(plain)
	ok(gb.foe_threat(0) > pb.foe_threat(0) * 1.3, "foes threaten more (%d vs %d)" % [int(gb.foe_threat(0)), int(pb.foe_threat(0))])

	# Blood Magic: skills cost HP, not MP.
	var n := _dyn("necromancer", 80, 44)
	var nb := _battle(n)
	_sturdy(nb)
	_keystone_unit(n, ["n_grave", "n_drain", "n_dark", "n_patience", "n_blood_rite"])
	nb._nums.clear()
	n.heir.hp = n.heir.max_hp()
	var mp := n.heir.mp
	var hp := n.heir.hp
	var cost := nb.blood_cost(-1, nb.skill_cost(0))
	ok(nb.pays_in_hp(-1) and cost > 0 and nb.pay_text(-1, nb.skill_cost(0)).ends_with("HP"), "Blood Rite: Soul Drain costs %s" % nb.pay_text(-1, nb.skill_cost(0)))
	nb.use_skill(0, 0)
	ok(n.heir.mp >= mp, "no MP is spent (%d -> %d)" % [mp, n.heir.mp])
	ok(nb.log.any(func(l): return str(l).find("Blood Rite") >= 0 or str(l).find("Blood Magic costs") >= 0), "the log tells the price in blood")
	ok(nb.events.any(func(e): return e["type"] == "hp_cost" and int(e["amount"]) == cost) or hp - n.heir.hp >= 0, "the HP is paid")
	n.heir.hp = cost
	ok(not nb.can_use_skill(0), "a cast that would take the last HP is refused")
	n.heir.mp = 0
	n.heir.hp = n.heir.max_hp()
	ok(nb.can_use_skill(0), "with no MP at all, blood still pays")

	# Eldritch Bastion: blows drain mana first; mana does not return each turn.
	var e := _dyn("mage", 80, 45)
	var eb := _battle(e)
	_keystone_unit(e, ["m_wellspring", "m_ebb", "m_steady", "m_robes", "m_bastion"])
	eb._nums.clear()
	e.heir.mp = e.heir.max_mp()
	var mp0 := e.heir.mp
	var hp0 := e.heir.hp
	eb.weather = {"dodge": -1.0}
	eb.enemies[0]["agi"] = 0
	eb._enemy_act(0)
	ok(e.heir.mp < mp0 and e.heir.hp < hp0, "Eldritch Bastion: the blow takes MP and HP (MP %d -> %d)" % [mp0, e.heir.mp])
	var taken_mp := mp0 - e.heir.mp
	var taken_hp := hp0 - e.heir.hp
	ok(absf(float(taken_mp) / float(taken_mp + taken_hp) - 0.5) < 0.05, "half of it from mana (%d MP, %d HP)" % [taken_mp, taken_hp])
	e.heir.mp = 0
	hp0 = e.heir.hp
	eb._enemy_act(0)
	ok(e.heir.mp == 0 and e.heir.hp < hp0 and not eb.log.back().find("mana takes") >= 0, "with no mana left the whole blow lands on HP")
	var plain_mage := _unit("mage", 80)
	ok(float(e.heir.max_hp()) < float(plain_mage.max_hp()), "its price: less max HP (%d < %d)" % [e.heir.max_hp(), plain_mage.max_hp()])

	# Assassin's Mark: crits x2.6.
	var a := _dyn("rogue", 80, 46)
	var ab := _battle(a)
	_keystone_unit(a, ["r_quick", "r_fangs", "r_vitals", "r_killer", "r_assassin"])
	ab._nums.clear()
	ok(absf(float(ab.unit_numbers(-1)["crit_mult"]) - (2.6 + 0.1)) < 0.0001, "Assassin's Mark: crits x2.6 (plus Killer's Instinct)")
	var crit := false
	for i in 400:
		var r := ab._calc_damage(1000.0, 1.0, 0, 1.0, 1.0)
		if r["crit"]:
			crit = true
			break
	ok(crit, "a certain crit rolls")
	ab.enemies[0]["def"] = 0.0
	var rolled := ab._calc_damage(1000.0, 1.0, 0, 1.0, 1.0)
	ok(rolled["crit"] and float(rolled["amount"]) >= 1000.0 * 0.9 * 2.7 - 1.0, "a crit lands for x2.7 (%d)" % int(rolled["amount"]))
	ok(absf(a.heir.trait_total("luck") - _unit("rogue").trait_total("luck") - (0.01 - 0.04)) < 0.0001, "its price: 4% less crit chance")

	# Martyr: the class heal mends the whole party.
	var c := _dyn("cleric", 80, 47)
	_hire(c, "bren_cask")
	_keystone_unit(c, ["c_faith", "c_hands", "c_devotion", "c_many_hands", "c_martyr"])
	var cb := _battle(c)
	_sturdy(cb)
	var heal := cb.skill_info(1)
	ok(heal.get("party", false) and absf(float(heal["pct_max_hp"]) - 0.5 * 1.1 * 0.6) < 0.0001, "Martyr: Heal reaches the party at 60%% (%s)" % heal["pct_max_hp"])
	ok(cb.skill_cost(1) > _battle(_dyn("cleric", 80, 47)).skill_cost(1), "and costs more")
	c.heir.hp = 1
	cb.allies[0].hp = 1
	c.heir.mp = c.heir.max_mp()
	cb.use_skill(1, -1)
	ok(c.heir.hp > 1 and cb.allies[0].hp > 1, "both the heir and Bren are mended")


# ---------------------------------------------------------------- refunds

func test_respec() -> void:
	var d := _dyn("warrior", 100, 51)
	var h := d.heir
	h.gold = 100000
	GameSkillTree.auto_spend(h)
	var spent := GameSkillTree.spent(h)
	ok(spent > 0 and h.tree_points == 0, "the heir spent %d points" % spent)
	h.tree_free = {"b_vigor": 1}
	GameSkillTree.changed(h)
	d.world.visit("whisperwood")
	h.downtime = false
	var why := GameSkillTree.respec_block(d)
	ok(why.find("no place to unlearn") >= 0 and why.find("town") >= 0, "in the wilds: %s" % why)
	ok(GameSkillTree.respec(d) == why and GameSkillTree.spent(h) == spent, "and nothing changes")
	d.rest()
	ok(GameSkillTree.respec_block(d) == "", "right after a rest it may be done")
	var fee := GameSkillTree.respec_fee(d, h)
	var gold := h.gold
	var line := GameSkillTree.respec(d)
	ok(h.gold == gold - fee and h.tree_points == spent and h.tree_ranks.is_empty(), "the fee is paid and every point comes back: %s" % line)
	ok(h.tree_free == {"b_vigor": 1}, "what the blood carries stays")
	ok(GameSkillTree.respec_block(d).find("nothing to refund") >= 0, "nothing bought, nothing to refund")
	GameSkillTree.auto_spend(h)
	d.work()
	ok(not h.downtime and GameSkillTree.respec_block(d) != "", "an action that takes time ends the quiet")
	d.world.visit("hearthmere")
	ok(GameSkillTree.respec_block(d) == "", "in a town it may be done")
	h.gold = 0
	ok(GameSkillTree.respec_block(d).find("gold") >= 0, "without the fee: %s" % GameSkillTree.respec_block(d))
	h.gold = 100000
	_battle(d)
	ok(GameSkillTree.respec_block(d) == "Not in the middle of a fight.", "not mid-battle")
	d.battle = null
	# The fee grows with level, and with the generation as gold does.
	var fees := []
	for lv in [1, 100, 5000, 99999]:
		var u := _unit("warrior", lv)
		fees.append(GameSkillTree.respec_fee(d, u))
	ok(fees[0] < fees[1] and fees[1] < fees[2] and fees[2] < fees[3], "the fee grows with level: %s" % str(fees))
	ok(fees[3] < fees[0] * 30, "but stays payable at the cap")
	d.gen = 300
	ok(GameSkillTree.respec_fee(d, _unit("warrior", 100)) > fees[1] * 5, "and with the generation")


# ---------------------------------------------------------------- the blood

func _parent_with_blood(d: GameDynasty) -> void:
	d.heir.level = 2000
	d.heir.tree_points = 0
	_give(d.heir, {"b_vigor": 3, "b_old_blood": 3, "b_hardy": 2, "b_steel": 3, "b_arcana": 3, "b_survivor": 3, "b_luck": 2, "b_memory": 4,
		"b_hand": 2, "b_grit": 3, "b_heroes": 5, "b_wits": 2, "b_trade": 2, "b_saga": 4, "w_brawn": 3, "w_heavy_blows": 3})


func _succeed(d: GameDynasty, archetype: String = "", traits: Array = []) -> GameHeir:
	d.heir.age = maxf(d.heir.age, d.heir.family_min_age())
	if not d.heir.family_founded:
		d.found_family()
	d.pending_archetype = archetype
	d._die("old age")
	var c: GameHeir = d.candidates[0]
	c.traits = traits.duplicate()
	d.choose_heir(0)
	return d.heir


func _inheritable_total(u: GameHeir) -> int:
	var n := 0
	for id in GameSkillTree.nodes_of("bloodline"):
		if GameSkillTree.inheritable(id):
			n += GameSkillTree.rank(u, id)
	return n


func test_inheritance() -> void:
	var d := _dyn("warrior", 1, 61)
	_parent_with_blood(d)
	var total := _inheritable_total(d.heir)
	ok(total == 33, "the parent holds 33 inheritable ranks (%d)" % total)
	var child := _succeed(d)
	var got := _inheritable_total(child)
	ok(got == total / 2 or got == total / 2 + 1, "a plain heir carries half: %d of %d" % [got, total])
	ok(child.tree_ranks.is_empty() and child.tree_points == GameSkillTree.points_at(1), "bought nothing, and has the points of level 1")
	ok(not child.tree_free.has("b_wits") and not child.tree_free.has("b_saga") and not child.tree_free.has("w_brawn"), "class nodes and uninheritable nodes do not pass")
	var closed := true
	for id in child.tree_free:
		var req: Array = GameSkillTree.node(id).get("requires", [])
		closed = closed and (req.is_empty() or req.any(func(q): return int(child.tree_free.get(q, 0)) > 0))
	ok(closed, "what passes holds together: every node's prerequisite came too")
	ok(child.stat("str") > _unit("warrior", 1).stat("str") * 0.99 and child.max_hp() > 0, "the free ranks count at once")
	var line := ""
	for l in d.journal:
		if str(l).begins_with("The blood remembers"):
			line = str(l)
	ok(line.find(child.name) >= 0 and line.find("Ancestral Vigor") >= 0 and line.find("%d of" % got) >= 0, "the journal says what passed down: %s" % line)
	# A failed fate thins it, a curse thins it, a blessing strengthens it.
	var shares := {}
	for spec in [["fate", "restorer", []], ["curse", "", ["cursed"]], ["blessing", "", ["blessed"]], ["two curses", "", ["cursed", GameData.traits_in(["curse"])[0]]]]:
		var e := _dyn("warrior", 1, 61)
		_parent_with_blood(e)
		var kid := _succeed(e, spec[1], spec[2])
		shares[spec[0]] = _inheritable_total(kid)
		var told := e.journal.filter(func(l): return str(l).begins_with("The blood remembers") or str(l).find("blood had awakened") >= 0)
		ok(not told.is_empty() and str(told.back()).find("thinned" if spec[0] != "blessing" else "strengthened") >= 0, "%s: the journal says why: %s" % [spec[0], str(told.back()) if not told.is_empty() else ""])
	print("  ranks passed of 33: plain %d, %s" % [got, str(shares)])
	ok(shares["fate"] < got, "a failed fate passes less (%d)" % shares["fate"])
	ok(shares["curse"] < got and shares["two curses"] < shares["curse"], "each curse passes less (%d, %d)" % [shares["curse"], shares["two curses"]])
	ok(shares["blessing"] > got, "a blessing passes more (%d)" % shares["blessing"])
	# Free ranks pass on again: the line keeps what each heir awakens, never more than the share.
	var f := _dyn("warrior", 1, 62)
	_parent_with_blood(f)
	var k1 := _succeed(f)
	var k2 := _succeed(f)
	ok(_inheritable_total(k2) <= _inheritable_total(k1) and _inheritable_total(k2) > 0, "a grandchild carries a share of the share (%d)" % _inheritable_total(k2))
	# The same seed passes the same ranks; the part rank is the dynasty's dice.
	var runs: Array = []
	for i in 2:
		var g := _dyn("warrior", 1, 63)
		_parent_with_blood(g)
		# 33 ranks: half is 16.5, so the last one is rolled.
		runs.append(_succeed(g).tree_free.duplicate())
	ok(runs[0] == runs[1], "the same seed passes the same ranks: %s" % str(runs[0]))
	# Nothing to pass: no line, no ranks.
	var z := _dyn("warrior", 1, 64)
	var zc := _succeed(z)
	ok(zc.tree_free.is_empty() and not z.journal.any(func(l): return str(l).begins_with("The blood remembers")), "an heir whose parent awakened nothing starts bare")


# ---------------------------------------------------------------- companions

func test_companions() -> void:
	var d := _dyn("mage", 40, 71)
	var m := _hire(d, "bren_cask")
	var u := d.party.unit(d, m)
	ok(int(m["tree"]["level"]) == 40 and GameSkillTree.spent(u) == GameSkillTree.companion_points_at(40), "a hired companion spends the points of its level along its path (%d)" % GameSkillTree.spent(u))
	ok(u.tree_points == 0 and u.tree_ranks.has("w_brawn"), "starting where a warrior would: %s" % str(u.tree_ranks.keys().slice(0, 4)))
	d.heir.gain_xp(400000)
	d.party.sync(d)
	var u2 := d.party.unit(d, m)
	ok(GameSkillTree.companion_points_at(d.heir.level) < GameSkillTree.points_at(d.heir.level), "a hireling has fewer points than an heir of its level")
	ok(int(m["tree"]["level"]) == d.heir.level and GameSkillTree.spent(u2) == GameSkillTree.companion_points_at(d.heir.level), "levels gained bring points it spends at once (%d at level %d)" % [GameSkillTree.spent(u2), d.heir.level])
	# The player spends and refunds for a companion; the heir pays the fee.
	m["tree"]["points"] = 3
	var line := GameSkillTree.spend(d, "bren_cask", "w_thick_hide")
	ok(line.begins_with("Bren") and int(m["tree"]["ranks"].get("w_thick_hide", 0)) >= 1, "the player buys a rank for Bren: %s" % line)
	ok(GameSkillTree.spend(d, "nobody", "w_brawn") == "No such companion.", "only for a companion in the party")
	d.world.visit("whisperwood")
	d.heir.downtime = false
	ok(GameSkillTree.respec_block(d, "bren_cask").find("no place") >= 0, "a companion unlearns only in a town or after a rest too")
	d.world.visit("hearthmere")
	var gold := d.heir.gold
	var back := GameSkillTree.spent(d.party.unit(d, m))
	GameSkillTree.respec(d, "bren_cask")
	ok(d.heir.gold < gold and (m["tree"]["ranks"] as Dictionary).is_empty() and int(m["tree"]["points"]) == back + 2, "the heir pays and Bren's points come back (%d)" % int(m["tree"]["points"]))
	var auto := GameSkillTree.auto(d, "bren_cask")
	ok(int(m["tree"]["points"]) == 0 and auto.begins_with("Bren") and auto.find("follows the well-worn path") > 0, "or are spent along the path: %s" % auto.left(60))
	# A companion brought down to a young heir's level learns again for that level.
	var young := _dyn("mage", 3, 72)
	var ym := _hire(young, "bren_cask")
	ym["tree"] = {"ranks": {"w_brawn": 3, "w_heavy_blows": 3, "w_iron_grip": 3}, "points": 0, "level": 500}
	var yu := young.party.unit(young, ym)
	ok(int(ym["tree"]["level"]) == 3 and GameSkillTree.spent(yu) <= GameSkillTree.companion_points_at(3), "a companion of a lower level holds no more than its level gives (%d)" % GameSkillTree.spent(yu))
	# A successor starts fresh.
	var s := _dyn("mage", 60, 73)
	var sm := _hire(s, "bren_cask")
	s.party.unit(s, sm)
	sm["tree"]["ranks"]["w_thick_hide"] = 3
	s.party._fall(s, sm)
	ok(not s.party.has_member("bren_cask"), "Bren falls")
	s.party.history["bren_cask"].erase("back_year")
	s.party.history["bren_cask"]["gen"] = -100
	var hired := s.party.hire(s, "bren_cask")
	var nm := s.party.member("bren_cask")
	if not nm.is_empty():
		var nu := s.party.unit(s, nm)
		ok(int(nu.tree_ranks.get("w_thick_hide", 0)) < 3 and GameSkillTree.spent(nu) == GameSkillTree.companion_points_at(60), "the successor starts fresh along the path (%s)" % hired.left(50))
	else:
		ok(true, "no successor at the tavern yet: %s" % hired.left(60))
	# Ageing still works with a tree.
	var a := _dyn("mage", 30, 74)
	var am := _hire(a, "bren_cask")
	a.heir.gold = 100000000
	for i in 40:
		a.world.advance(5.0, a.rng)
		a.party.on_years(a, 5.0, [])
	ok(not a.party.has_member("bren_cask") or a.party.decline(a, "bren_cask") > 0.0, "companions still grow old and leave")


func test_companion_saves() -> void:
	var d := _dyn("mage", 80, 81)
	var m := _hire(d, "bren_cask")
	d.party.unit(d, m)
	m["tree"]["points"] = 2
	var j := JSON.stringify(d.to_dict())
	var e := GameDynasty.from_dict(JSON.parse_string(j))
	var em := e.party.member("bren_cask")
	ok(em["tree"]["ranks"] == m["tree"]["ranks"] and int(em["tree"]["points"]) == 2 and typeof(em["tree"]["points"]) == TYPE_INT, "a companion's tree survives a save")
	ok(JSON.stringify(e.to_dict()) == j, "and round-trips exactly")
	# A save from before skill trees: the companion gets the points of its level, spent.
	var raw: Dictionary = JSON.parse_string(j)
	for mm in raw["party"]["members"]:
		mm.erase("tree")
	var f := GameDynasty.from_dict(raw)
	var fu := f.party.unit(f, f.party.member("bren_cask"))
	ok(GameSkillTree.spent(fu) == GameSkillTree.companion_points_at(fu.level), "an old companion gets the points of level %d (%d spent)" % [fu.level, GameSkillTree.spent(fu)])


# ---------------------------------------------------------------- the autopilot

func test_bot() -> void:
	for c in GameData.classes:
		var path := GameSkillTree.path_of(c)
		var seen := {}
		var good := true
		var rules := {}
		for id in path:
			seen[id] = int(seen.get(id, 0)) + 1
			var req: Array = GameSkillTree.node(id).get("requires", [])
			good = good and int(seen[id]) <= GameSkillTree.max_rank(id) and (req.is_empty() or req.any(func(q): return seen.has(q)))
			if GameSkillTree.is_keystone(id):
				var k := GameSkillTree.keystone(str(GameSkillTree.node(id)["keystone"]))
				good = good and c in k.get("suits", []) and not rules.has(k["rule"])
				rules[k["rule"]] = true
		ok(good and path.size() > 60, "%s: the path respects prerequisites, ranks and keystones that suit it (%d ranks)" % [c, path.size()])
	ok(not GameSkillTree.path_of("mage").any(func(id): return GameSkillTree.is_keystone(id)), "a Mage's path takes no keystone that does not suit it")
	ok(GameSkillTree.path_of("warrior").has("w_juggernaut") and not GameSkillTree.path_of("warrior").has("w_berserker"), "a Warrior's path takes Juggernaut, not Wrath")
	var style_ok := GameSkillTree.path_of("mage").slice(0, 6).all(func(id): return id.begins_with("m_") or id.begins_with("b_"))
	ok(style_ok and not GameSkillTree.path_of("mage").slice(0, 12).has("b_steel"), "a Mage starts with spellcraft, not steel")
	# Spending is cheap: a level-5000 heir spends everything quickly.
	var d := _dyn("paladin", 5000, 91)
	var t0 := Time.get_ticks_usec()
	GameSkillTree.bot_tick(d)
	var took := Time.get_ticks_usec() - t0
	ok(d.heir.tree_points == 0 and GameSkillTree.spent(d.heir) == GameSkillTree.points_at(5000), "the autopilot spends all %d points" % GameSkillTree.points_at(5000))
	t0 = Time.get_ticks_usec()
	for i in 1000:
		GameSkillTree.bot_tick(d)
	ok(Time.get_ticks_usec() - t0 < 50000, "with nothing to spend a tick costs next to nothing (%d us for 1000)" % (Time.get_ticks_usec() - t0))
	print("  first spend at level 5000: %d us" % took)
	# GameBot spends as the heir levels.
	var b := GameDynasty.new_game(92, "", "rogue", "faetouched", "human")
	for i in 120:
		if b.state != "life":
			break
		GameBot.step(b)
	ok(b.state != "life" or b.heir.tree_points == 0 and GameSkillTree.spent(b.heir) > 0, "the autopilot keeps its points spent (%d spent)" % GameSkillTree.spent(b.heir))


# ---------------------------------------------------------------- high levels

func test_high_levels() -> void:
	for spec in [["warrior", 30], ["warrior", 5000], ["mage", 5000], ["paladin", 99999]]:
		var u := _unit(spec[0], spec[1])
		var p := _unit(spec[0], spec[1])
		GameSkillTree.auto_spend(u)
		var hp := float(u.max_hp()) / float(p.max_hp())
		var main := "str" if GameSkillTree.style_of(spec[0]) != "mag" else "mag"
		var pw := (u.attack_power() if main == "str" else u.magic_power()) / (p.attack_power() if main == "str" else p.magic_power())
		print("  %s L%d: %d points, HP x%.2f, power x%.2f" % [spec[0], spec[1], GameSkillTree.spent(u), hp, pw])
		ok(hp >= 1.0 and hp < 2.5 and pw >= 1.0 and pw < 2.5, "%s at level %d: the tree helps, within reason (HP x%.2f, power x%.2f)" % [spec[0], spec[1], hp, pw])
		ok(u.stat("str") == u.stat("str") and is_finite(u.attack_power()), "numbers stay finite")


# ---------------------------------------------------------------- saves

func test_save_load() -> void:
	var d := _dyn("warrior", 300, 101)
	GameSkillTree.auto_spend(d.heir)
	d.heir.tree_points = 2
	d.heir.tree_free = {"b_vigor": 2}
	d.heir.tree_news = 3
	GameSkillTree.changed(d.heir)
	var hp := d.heir.max_hp()
	var j := JSON.stringify(d.to_dict())
	var e := GameDynasty.from_dict(JSON.parse_string(j))
	var h := e.heir
	ok(h.tree_ranks == d.heir.tree_ranks and h.tree_free == {"b_vigor": 2} and h.tree_points == 2 and h.tree_news == 3, "the tree survives a save")
	ok(typeof(h.tree_points) == TYPE_INT and h.tree_ranks.values().all(func(v): return typeof(v) == TYPE_INT), "with whole numbers")
	ok(h.max_hp() == hp and h.stat("str") == d.heir.stat("str"), "and the same numbers after loading")
	ok(JSON.stringify(e.to_dict()) == j, "a second round trip is identical")
	# Ranks the data no longer allows are refunded; unknown nodes dropped.
	var raw: Dictionary = JSON.parse_string(j)
	raw["heir"]["skill_tree"]["ranks"]["gone_node"] = 2
	raw["heir"]["skill_tree"]["ranks"]["w_brawn"] = 9
	var f := GameDynasty.from_dict(raw)
	ok(not f.heir.tree_ranks.has("gone_node") and int(f.heir.tree_ranks["w_brawn"]) == 3, "unknown nodes are dropped and ranks capped")
	# A save from before skill trees.
	var old: Dictionary = JSON.parse_string(j)
	old["heir"].erase("skill_tree")
	var g := GameDynasty.from_dict(old)
	ok(g.heir.tree_points == GameSkillTree.points_at(g.heir.level) and g.heir.tree_ranks.is_empty() and g.heir.tree_news == 0, "an old save gets the points of the heir's level (%d)" % g.heir.tree_points)


func test_old_saves() -> void:
	for tag in ["pr3_life", "pr3_succession", "pr4_life", "pr4_succession", "party_preaging"]:
		var txt := FileAccess.get_file_as_string(FIXTURES + "old_save_%s.json" % tag)
		if txt == "":
			ok(false, "fixture %s exists" % tag)
			continue
		var d := GameDynasty.from_dict(JSON.parse_string(txt))
		ok(d.heir.tree_points == GameSkillTree.points_at(d.heir.level) and d.heir.tree_ranks.is_empty(), "%s: the heir has the points of level %d" % [tag, d.heir.level])
		for m in d.party.members:
			var u := d.party.unit(d, m)
			ok(GameSkillTree.spent(u) == GameSkillTree.companion_points_at(u.level), "%s: %s gets the points of level %d" % [tag, m["name"], u.level])
		for i in 200:
			if d.state == "succession":
				d.choose_heir(0)
			elif d.state == "life":
				GameBot.step(d)
		var j := JSON.stringify(d.to_dict())
		ok(JSON.stringify(GameDynasty.from_dict(JSON.parse_string(j)).to_dict()) == j, "%s: plays on with trees and round-trips" % tag)


func test_determinism() -> void:
	var runs: Array = []
	for r in 2:
		var d := GameDynasty.new_game(4243, "", "cleric", "faetouched", "human")
		for i in 500:
			if d.state == "succession":
				d.choose_heir(0)
			elif d.state == "life":
				GameBot.step(d)
		runs.append([d.journal.duplicate(), JSON.stringify(d.to_dict()), d.gen])
	ok(runs[0][0] == runs[1][0] and runs[0][1] == runs[1][1], "the same seed tells the same story with trees (gen %d)" % runs[0][2])
	ok((runs[0][0] as Array).any(func(l): return str(l).find("skill point") >= 0), "skill points are part of that story")
	var a := GameDynasty.new_game(778, "", "druid", "faetouched", "human")
	for i in 60:
		GameBot.step(a)
	if a.state == "life":
		var b := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
		for i in 120:
			for x in [a, b]:
				if x.state == "succession":
					x.choose_heir(0)
				elif x.state == "life":
					GameBot.step(x)
		ok(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()), "a loaded copy plays on exactly like the original")


# ---------------------------------------------------------------- screens

func _frames(n: int = 4) -> void:
	for i in n:
		await process_frame


func _button(n: Node, prefix: String, enabled_only: bool = true) -> Button:
	if n is Button and (n as Button).is_visible_in_tree() and (not enabled_only or not (n as Button).disabled) and (n as Button).text.begins_with(prefix):
		return n
	for c in n.get_children():
		var b := _button(c, prefix, enabled_only)
		if b != null:
			return b
	return null


func _labels_text(n: Node, out: Array = []) -> Array:
	if n is Label and (n as Label).is_visible_in_tree():
		out.append((n as Label).text)
	for c in n.get_children():
		_labels_text(c, out)
	return out


func _ui_tests() -> void:
	var real := GameDynasty.save_path
	GameDynasty.save_path = "user://test_trees_ui_save.json"
	root.size = Vector2i(1280, 720)
	var app = GameApp.new()
	root.add_child(app)
	await _frames()
	app.new_game("Tess", "warrior", "faetouched", 31, "human")
	var d: GameDynasty = app.dynasty
	d.pending_event = {}
	d.heir.gold = 100000
	d.heir.gain_xp(60000)
	d.party.hire(d, "bren_cask")
	app.show_state()
	await _frames()
	var open := _button(app.current, "Skill trees")
	ok(open != null and open.text.find("(") > 0, "the life screen offers the skill trees with points to spend: %s" % (open.text if open != null else ""))
	ok(_labels_text(app.current).any(func(t): return str(t).find("skill point") >= 0), "and sums them up in the side column")
	open.pressed.emit()
	await _frames()
	var panel: Control = app.current.get_children().back()
	ok(panel.get_script() == SkillTreePanel, "the Skill Trees panel opens")
	var node := _button(panel, "Brawn")
	ok(node != null and node.tooltip_text.find("+2 STR") >= 0, "a node's hover text gives its exact effect: %s" % (node.tooltip_text.replace("\n", " | ") if node != null else ""))
	node.pressed.emit()
	await _frames()
	var learn := _button(panel, "Learn rank 1")
	ok(learn != null, "choosing it offers to learn it")
	var pts := d.heir.tree_points
	learn.pressed.emit()
	await _frames()
	ok(d.heir.tree_points == pts - 1 and int(d.heir.tree_ranks.get("w_brawn", 0)) == 1, "Learn buys the rank")
	ok(_labels_text(panel).any(func(t): return str(t).find("Tess takes Brawn") >= 0), "and says so")
	var locked := _button(panel, "Juggernaut", false)
	ok(locked != null and locked.tooltip_text.find("Needs a rank") >= 0, "a locked keystone says what it needs")
	_button(panel, "The Blood").pressed.emit()
	await _frames()
	ok(_button(panel, "Ancestral Vigor") != null, "the bloodline tab shows the house's tree")
	_button(panel, "Bren").pressed.emit()
	await _frames()
	ok(_labels_text(panel).any(func(t): return str(t).begins_with("Bren")), "a companion's tree opens from the same panel")
	_button(panel, "Close").pressed.emit()
	await _frames()
	# In the wilds the refund is refused with the reason.
	d.world.visit("whisperwood")
	d.heir.downtime = false
	app.show_state()
	await _frames()
	_button(app.current, "Skill trees").pressed.emit()
	await _frames()
	panel = app.current.get_children().back()
	var re := _button(panel, "Unlearn", false)
	ok(re != null and re.disabled and re.tooltip_text.find("no place to unlearn") >= 0, "Unlearn is shut in the wilds and says why")
	ok(_labels_text(panel).any(func(t): return str(t).find("no place to unlearn") >= 0), "the reason is on screen too")
	_button(panel, "Close").pressed.emit()
	await _frames()
	d.rest()
	app.show_state()
	await _frames()
	_button(app.current, "Skill trees").pressed.emit()
	await _frames()
	panel = app.current.get_children().back()
	var gold := d.heir.gold
	_button(panel, "Unlearn").pressed.emit()
	await _frames()
	ok(d.heir.gold < gold and d.heir.tree_ranks.is_empty(), "after a rest Unlearn refunds for the fee")
	_button(panel, "Spend along").pressed.emit()
	await _frames()
	ok(d.heir.tree_points == 0, "Spend along the path spends every point")
	_button(panel, "Close").pressed.emit()
	await _frames()
	# The tavern opens a companion's tree.
	d.world.visit("hearthmere")
	app.show_state()
	await _frames()
	_button(app.current, "Tavern").pressed.emit()
	await _frames()
	var tavern: Control = app.current.get_children().back()
	var tb := _button(tavern, "Skill tree")
	ok(tb != null, "each companion in the tavern has a Skill tree button")
	tb.pressed.emit()
	await _frames()
	var cp: Control = tavern.get_children().back()
	ok(cp.get_script() == SkillTreePanel and cp.who == "bren_cask", "it opens Bren's tree")
	# Level 5,000: the panel still builds.
	d.heir.level = 5000
	GameSkillTree.sync(d.heir)
	cp.queue_free()
	tavern.queue_free()
	app.show_state()
	await _frames()
	_button(app.current, "Skill trees").pressed.emit()
	await _frames()
	panel = app.current.get_children().back()
	ok(_labels_text(panel).any(func(t): return str(t).find("level 5,000") >= 0), "a level-5,000 heir's tree opens")
	GameDynasty.save_path = real
	_done()
