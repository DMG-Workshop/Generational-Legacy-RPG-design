## Combat: battlefield geometry and formations, the shared ability pipeline (class skills and the
## spellbook on 1-5 foes), statuses (apply, tick, expire, stack, control, immunity, bosses),
## elements, packs, spell learning and costs from level 1 to 5000, save/load and old saves,
## tactics for the autopilot and companions, determinism, and the battle screen's controls.
## Run: godot --headless --path . -s res://tests/test_game_combat.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")

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
	test_geometry()
	test_reach_and_ranks()
	test_formation()
	test_every_ability_runs()
	test_aoe_each_target_rolls()
	test_status_ticks_and_expiry()
	test_status_stacking()
	test_control()
	test_bosses_and_levels_resist()
	test_shield_regen_haste()
	test_heir_loses_turn()
	test_creature_inflicts()
	test_added_status()
	test_elements()
	test_party_of_three()
	test_foe_dodge()
	test_disease_saps_power()
	test_disease_chances_low()
	test_costs_and_learning()
	test_spells_save_load()
	test_companion_spells()
	test_packs()
	test_pack_threat()
	test_tactics()
	test_bot_all_classes()
	test_determinism()
	_ui_tests.call_deferred()


func _done() -> void:
	print("combat tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(cls: String = "mage", level: int = 30, seed_val: int = 41) -> GameDynasty:
	var d := GameDynasty.new_game(seed_val, "Tess", cls, "faetouched", "human")
	d.pending_event = {}
	d.heir.level = level
	d.heir.spells = []
	d.heir.learn_spells()
	d.heir.full_heal()
	return d


## A battle against `n` copies of a creature at the heir's level (no party, fixed seed).
func _battle(d: GameDynasty, n: int, creature: String = "wolf", power: float = 1.0) -> GameBattle:
	var c := GameCombat.creature_def(creature)
	var foes: Array = []
	for i in n:
		foes.append(d._make_enemy(c, power, 1.0, d.heir.level))
	d._begin_battle(foes, "hunt")
	return d.battle


func _sturdy(b: GameBattle) -> void:
	for e in b.enemies:
		e["hp"] = 10000000
		e["max_hp"] = 10000000
		e["atk"] = 0.0


# ---------------------------------------------------------------- data

func test_data() -> void:
	var errs := GameCombat.validate()
	ok(errs.is_empty(), "the combat data validates: %s" % str(errs))
	var ids := GameCombat.spell_ids()
	ok(ids.size() >= 22 and ids.size() <= 28, "about two dozen spells (%d)" % ids.size())
	var groups := {}
	for id in ids:
		var sp := GameCombat.spell(id)
		groups[sp["group"]] = int(groups.get(sp["group"], 0)) + 1
		ok(GameCombat.shape(sp) != "self", "%s has a target block" % id)
		ok(GameCombat.describe(sp) != "", "%s has a one-line effect" % id)
	ok(int(groups.get("elemental", 0)) >= 8 and int(groups.get("control", 0)) >= 5 and int(groups.get("utility", 0)) >= 6, "three groups: %s" % str(groups))
	for want in ["burn", "poison", "bleed", "stun", "freeze", "slow", "weaken", "vulnerable", "shield", "regen", "haste"]:
		ok(not GameCombat.status_def(want).is_empty(), "status %s defined" % want)
	var areas := 0
	for cid in GameData.classes:
		for s in GameData.classes[cid]["skills"]:
			if GameCombat.is_aoe(s):
				areas += 1
	ok(areas >= 6, "several class skills are areas (%d)" % areas)
	# A broken spell is reported line by line, not skipped.
	var broken := {"id": "test_broken", "name": "Broken", "group": "nowhere", "school": "x", "element": "plasma", "type": "damage", "mp": 1,
		"mult": 1.0, "target": {"shape": "blob"}, "is_aoe": true, "hits": 2, "statuses": [{"id": "no_such_status"}],
		"learn": {"classes": ["no_such_class"], "levels": {"mage": 3}}}
	GameData.combat["spells"]["spells"].append(broken)
	GameCombat.reindex()
	errs = GameCombat.validate()
	for want in ["unknown group", "unknown shape", "is_aoe does not match", "takes no hits", "unknown element", "unknown status", "unknown class", "not on its class list"]:
		ok(errs.any(func(e): return str(e).begins_with("spell test_broken") and str(e).find(want) >= 0), "a broken spell is reported: %s" % want)
	GameData.combat["spells"]["spells"].pop_back()
	var wolf := GameCombat.creature_def("wolf")
	wolf["row"] = "middle"
	var cap = GameData.balance["party_max_size"]
	GameData.balance["party_max_size"] = 4
	GameCombat.reindex()
	errs = GameCombat.validate()
	ok(errs.has("creature wolf: row must be front or back"), "a creature in no row is reported")
	ok(errs.any(func(e): return str(e).begins_with("formation: 3 companion places for a party of 4")), "a party larger than the formation is reported")
	wolf.erase("row")
	GameData.balance["party_max_size"] = cap
	GameCombat.reindex()
	ok(GameCombat.validate().is_empty() and GameCombat.spell("test_broken").is_empty(), "and the real data is back")


# ---------------------------------------------------------------- geometry

func _fp(ab: Dictionary, origin: Vector2, aim: int, pts: Dictionary) -> Array:
	return GameCombat.footprint(ab, origin, aim, pts).map(func(h): return h[0])


func test_geometry() -> void:
	var o := Vector2.ZERO
	var burst := {"target": {"shape": "burst", "radius": 3.5}}
	ok(_fp(burst, o, 0, {0: Vector2(9, 0), 1: Vector2(12.49, 0), 2: Vector2(12.51, 0)}) == [0, 1], "burst: just inside the radius is hit, just outside is not")
	ok(_fp(burst, o, 0, {0: Vector2(9, 0), 1: Vector2(9, 3.49), 2: Vector2(9, -3.51)}) == [0, 1], "burst measures across the field too")
	var falloff := GameCombat.footprint({"target": {"shape": "burst", "radius": 4.0, "falloff": 0.25}}, o, 0, {0: Vector2(9, 0), 1: Vector2(13, 0)})
	ok(is_equal_approx(float(falloff[0][1]), 1.0) and is_equal_approx(float(falloff[1][1]), 0.75), "falloff: full at the centre, 75%% at the edge (%s)" % str(falloff))
	var cone := {"target": {"shape": "cone", "angle": 60, "range": 16}}
	var inside := Vector2.from_angle(deg_to_rad(29.9)) * 12.0
	var outside := Vector2.from_angle(deg_to_rad(30.1)) * 12.0
	ok(_fp(cone, o, 0, {0: Vector2(10, 0), 1: inside, 2: outside}) == [0, 1], "cone: just inside half the angle is hit, just outside is not")
	ok(_fp(cone, o, 0, {0: Vector2(10, 0), 1: Vector2(15.99, 0), 2: Vector2(16.01, 0)}) == [0, 1], "cone: range is measured from the caster")
	ok(_fp(cone, o, 0, {0: Vector2(10, 0), 1: Vector2(-5, 0)}) == [0], "cone: nothing behind the caster")
	ok(_fp(cone, o, 1, {0: Vector2(9, 9), 1: Vector2(30, 0)}).is_empty(), "a cone aimed past its range does not reach the foe it points at")
	ok(_fp(cone, o, 1, {0: Vector2(9, 0.5), 1: Vector2(30, 0)}) == [0], "but catches what stands within reach that way")
	var line := {"target": {"shape": "line", "width": 3, "length": 18}}
	ok(_fp(line, o, 0, {0: Vector2(9, 0), 1: Vector2(12, 1.49), 2: Vector2(12, 1.51)}) == [0, 1], "line: just inside half the width is hit, just outside is not")
	ok(_fp(line, o, 0, {0: Vector2(9, 0), 1: Vector2(17.99, 0), 2: Vector2(18.01, 0), 3: Vector2(-0.5, 0)}) == [0, 1], "line: out to its length, never behind the caster")
	var diag := _fp(line, o, 0, {0: Vector2(9, 3), 1: Vector2(12, 4), 2: Vector2(12, 0)})
	ok(diag == [0, 1], "line: runs from the caster through the aimed foe (%s)" % str(diag))
	ok(_fp({"target": {"shape": "all"}}, o, 0, {0: Vector2(9, 0), 1: Vector2(40, 30)}) == [0, 1], "all: every foe")
	ok(_fp({"mult": 1.0}, o, 1, {0: Vector2(9, 0), 1: Vector2(9, 3)}) == [1], "a strike with no target block: a single foe")
	var short_line := {"target": {"shape": "line", "width": 3, "length": 10}}
	ok(_fp(short_line, o, 1, {0: Vector2(9, 0.5), 1: Vector2(13, 0)}) == [0], "a line stops at its length, even short of the foe it points at")
	# Through a live battle: dead foes are never caught.
	var d := _dyn("mage", 30)
	var b := _battle(d, 5)
	var fb := GameCombat.spell("fireball")
	b.enemies[1]["hp"] = 0
	ok(1 not in b.aoe_targets(fb, -1, 0), "the fallen are not in an area")
	ok(b.aoe_targets(fb, -1, 1) == b.aoe_targets(fb, -1, b.first_target()), "aiming at a fallen foe aims at the first standing one")
	ok(b.aoe_targets(GameCombat.spell("ward"), -1, 0).is_empty(), "a party spell catches no foes")
	# On a full field (three in front, two behind) each shape keeps its own reach.
	b.enemies[1]["hp"] = b.enemies[1]["max_hp"]
	var best := func(ab: Dictionary) -> int:
		var n := 0
		for i in 5:
			n = maxi(n, b.aoe_targets(ab, -1, i).size())
		return n
	ok(best.call(GameCombat.spell("earthshatter")) == 5, "a field-wide spell reaches all five")
	ok(best.call(GameCombat.spell("cone_of_frost")) == 3, "a front-rank cone reaches the front rank only")
	for i in 5:
		if b.enemies[i]["row"] == "back":
			ok(i not in b.aoe_targets(GameCombat.spell("cone_of_frost"), -1, i), "Cone of Frost aimed at back-row foe %d falls short of it" % i)
	ok(best.call(fb) == 3, "a fireball catches a row")
	ok(best.call(GameCombat.spell("chain_lightning")) == 2, "a line runs from the front rank to the back")
	ok(best.call(GameCombat.spell("sleep")) == 1, "sleep holds one foe")
	var mend: Dictionary = GameData.classes["warrior"]["skills"][1]
	ok(GameCombat.shape(mend) == "self" and GameCombat.shape_text(mend) == "Self" and b.aoe_targets(mend, -1, 0).is_empty(), "a class heal is its user's own and catches no foe")
	ok(GameCombat.shape(GameData.classes["warrior"]["skills"][0]) == "single", "a class strike with no target block hits one foe")


## A cone or line reaches no further than its range: aimed at a foe beyond it, it falls short. When
## the front rank falls, the back rank steps up. An area that reaches no one is never cast.
func test_reach_and_ranks() -> void:
	var d := _dyn("mage", 30, 71)
	var foes: Array = []
	for k in ["wolf", "harpy", "wolf", "harpy"]:
		foes.append(d._make_enemy(GameCombat.creature_def(k), 1.0, 1.0, 30))
	d._begin_battle(foes, "hunt")
	var b := d.battle
	_sturdy(b)
	var cone := GameCombat.spell("cone_of_frost")
	ok(b.enemies[1]["row"] == "back" and b.enemies[3]["row"] == "back", "harpies keep back behind the wolves")
	var toward := b.aoe_targets(cone, -1, 1)
	ok(1 not in toward and not toward.is_empty() and toward.all(func(i): return b.enemies[i]["row"] == "front"), "Cone of Frost toward a harpy reaches the wolves in front of it (%s)" % str(toward))
	# A strike so strong the autopilot would always want it, if only it reached.
	var pinhole := {"id": "test_pinhole", "name": "Pinhole", "group": "elemental", "school": "x", "element": "", "type": "damage", "mp": 1,
		"stat": "mag", "mult": 9.0, "target": {"shape": "cone", "angle": 2, "range": 3}, "is_aoe": true, "learn": {"classes": []}}
	GameData.combat["spells"]["spells"].append(pinhole)
	GameCombat.reindex()
	d.heir.spells.append("test_pinhole")
	ok(GameTactics.choose(b, -1).get("spell", "") != "test_pinhole", "the autopilot never picks an area that reaches no one")
	var mp := d.heir.mp
	var turn := b.turn
	var log0 := b.log.size()
	b.cast_spell("test_pinhole", 0)
	ok(d.heir.mp == mp and b.turn == turn and b.log.size() == log0, "nor is it cast: no MP spent, no turn lost")
	d.heir.spells.erase("test_pinhole")
	GameData.combat["spells"]["spells"].pop_back()
	GameCombat.reindex()
	# The front rank falls: the harpies step up and the cone reaches them.
	for i in [0, 2]:
		b.events = []
		b._lose_hp(GameBattle.enemy_ref(i), int(b.enemies[i]["hp"]))
	var front := float(GameCombat.formation()["field"]["rows"]["front"])
	ok(b.enemies[1]["row"] == "front" and b.enemies[3]["row"] == "front" and is_equal_approx(float(b.enemies[1]["x"]), front), "the back rank steps up when the front rank falls")
	ok(b.events.any(func(ev): return ev["type"] == "advance" and ev["indices"] == [1, 3]), "the screen is told who moved")
	ok(b.log.slice(log0).has("The back rank steps up to the front."), "and the log tells it")
	ok(1 in b.aoe_targets(cone, -1, 1), "now the cone reaches them")
	d.battle = null
	# A companion standing behind the heir acts from the heir's line.
	var w := _dyn("warrior", 30, 72)
	_full_party(w, ["varn_deepdelver", "ysolde_marrow", "tarsk_ember_eye"])
	var wb := _battle(w, 3, "goblin")
	_sturdy(wb)
	var cleave: Dictionary = GameData.classes["warden"]["skills"][0]
	for i in 3:
		var best := 0
		for j in 3:
			best = maxi(best, wb.aoe_targets(cleave, i, j).size())
		ok(best >= 2, "Hunter's Cleave from companion %d's place sweeps %d of the front rank" % [i, best])
	w.battle = null


func test_formation() -> void:
	var d := _dyn("warrior", 10)
	for n in range(1, 6):
		var b := _battle(d, n)
		var rows := {"front": 0, "back": 0}
		var seen := {}
		for e in b.enemies:
			rows[e["row"]] += 1
			seen[Vector2(e["x"], e["y"])] = true
		ok(rows["front"] <= 3 and rows["back"] <= 3 and rows["front"] + rows["back"] == n, "%d foes: rows %s" % [n, str(rows)])
		ok(seen.size() == n, "%d foes stand in %d different places" % [n, seen.size()])
		ok(n < 4 or rows["back"] == n - 3, "%d foes: the front fills first, the rest stand behind" % n)
		d.battle = null
	var b2 := _battle(d, 2, "harpy")
	ok(b2.enemies.all(func(e): return e["row"] == "front"), "with no one to stand behind, creatures that keep back face the party")
	d.battle = null
	var mixed: Array = []
	for k in ["harpy", "wolf", "harpy"]:
		mixed.append(d._make_enemy(GameCombat.creature_def(k), 1.0, 1.0, d.heir.level))
	d._begin_battle(mixed, "hunt")
	ok(d.battle.enemies.map(func(e): return e["row"]) == ["back", "front", "back"], "behind a front rank they keep back")
	d.battle = null
	var b3 := _battle(d, 4, "harpy")
	ok(b3.enemies.filter(func(e): return e["row"] == "back").size() == 3, "a full back row spills forward")
	d.battle = null
	var places := {}
	for i in int(GameData.bal("party_max_size")):
		var p := GameCombat.ally_point(i)
		places[p] = true
		ok(p.x < GameCombat.heir_point().x, "companion %d stands beside and behind the heir (%s)" % [i, str(p)])
	ok(places.size() == int(GameData.bal("party_max_size")) and not places.has(GameCombat.heir_point()), "a full party has a place each: %s" % str(places.keys()))


# ---------------------------------------------------------------- abilities

func _all_abilities() -> Array:
	var out: Array = []
	for id in GameCombat.spell_ids():
		out.append(GameCombat.spell(id))
	for cid in GameData.classes:
		for s in GameData.classes[cid]["skills"]:
			out.append(s)
	return out


func test_every_ability_runs() -> void:
	var count := 0
	for n in range(1, 6):
		for ab in _all_abilities():
			var d := _dyn("mage", 40, 900 + n)
			d.heir.gold = 99999
			d.party.members.append({"id": "bren_cask", "name": "Bren", "hp": 1, "mp": 0, "level": 40, "gen": 1, "due": 0.0, "battles": 0, "hired_gen": 1})
			d.party.rest(d)
			var b := _battle(d, n, "goblin", 0.4)
			var before := b.enemies.map(func(e): return e["hp"])
			b.heir.mp = 100000
			b.use_ability(ab, n - 1, 0)
			count += 1
			ok(b.events.any(func(ev): return ev["type"] == "cast" and ev["name"] == ab["name"]), "%s on %d foes: cast" % [ab["name"], n])
			if float(ab.get("mult", 0.0)) > 0.0:
				var hit := false
				for i in n:
					hit = hit or int(b.enemies[i]["hp"]) < int(before[i])
				ok(hit, "%s on %d foes: deals damage" % [ab["name"], n])
			# The same ability from a companion's hands.
			if not b.is_over() and not b.conscious_allies().is_empty():
				b.events = []
				b.resolve_ability(0, ab, b.first_target())
				ok(b.events.size() > 0, "%s used by a companion" % ab["name"])
	ok(count == 5 * _all_abilities().size(), "every spell and skill ran on 1 to 5 foes (%d casts)" % count)


func test_aoe_each_target_rolls() -> void:
	var d := _dyn("mage", 40)
	var b := _battle(d, 5)
	_sturdy(b)
	var fb := GameCombat.spell("earthshatter")
	b.heir.mp = 100000
	b.cast_spell("earthshatter", 0) if "earthshatter" in d.heir.spells else b.use_ability(fb, 0, 0)
	var dmg: Array = b.events.filter(func(ev): return ev["type"] == "damage" and ev["side"] == "enemy" and int(ev.get("cast", 0)) > 0)
	ok(dmg.size() == 5, "an all-foes spell lands one hit on each of 5 foes (%d)" % dmg.size())
	var amounts := {}
	var casts := {}
	for ev in dmg:
		amounts[int(ev["amount"])] = true
		casts[int(ev["cast"])] = true
	ok(amounts.size() > 1, "each foe's hit is rolled on its own (%s)" % str(amounts.keys()))
	ok(casts.size() == 1, "the hits share one cast number, so the screen shows them together")
	ok(b.log.any(func(l): return str(l) == "Tess casts Earthshatter."), "the cast is told in the log")
	d.battle = null
	# A single-target skill with several hits still rolls over to the next foe.
	var r := _dyn("rogue", 10)
	var b2 := _battle(r, 2)
	b2.enemies[0]["hp"] = 1
	b2.heir.mp = 1000
	b2.use_skill(0, 0)
	ok(b2.enemies[0]["hp"] == 0 and b2.enemies[1]["hp"] < b2.enemies[1]["max_hp"], "Twin Fangs rolls over to the next foe when the first falls")


# ---------------------------------------------------------------- statuses

func test_status_ticks_and_expiry() -> void:
	var d := _dyn("mage", 30)
	var b := _battle(d, 2)
	_sturdy(b)
	var ref := GameBattle.enemy_ref(0)
	ok(b.apply_status(ref, "burn", 0.2, 3, "heir", 500.0), "burn applied")
	ok(is_equal_approx(float(b.status_of(ref, "burn")["amount"]), 100.0), "power-based burn: 20% of the caster's 500 power a turn")
	var hp: int = b.enemies[0]["hp"]
	b._enemy_turn(0)
	ok(hp - int(b.enemies[0]["hp"]) == 100, "burn ticks at the start of the foe's own turn (%d)" % (hp - int(b.enemies[0]["hp"])))
	ok(int(b.status_of(ref, "burn")["turns"]) == 2, "one turn used")
	ok(b.log.any(func(l): return str(l).find("burns for 100") >= 0), "the tick is in the log")
	b._enemy_turn(0)
	b._enemy_turn(0)
	ok(not b.has_status(ref, "burn"), "burn expires after its turns")
	ok(b.log.any(func(l): return str(l).find("gutter out") >= 0), "the end is told")
	# Poison scales with the victim's max HP.
	b.apply_status(ref, "poison", 0.03, 2, "heir")
	ok(is_equal_approx(float(b.status_of(ref, "poison")["amount"]), 300000.0), "poison: 3% of max HP a turn")
	# A tick can kill: the foe falls without acting and the battle can be won that way.
	var d2 := _dyn("mage", 30)
	var b2 := _battle(d2, 1)
	b2.enemies[0]["hp"] = 5
	b2.apply_status(GameBattle.enemy_ref(0), "burn", 1.0, 3, "heir", 50.0)
	b2.defend()
	ok(b2.enemies[0]["hp"] == 0 and b2.result == "victory", "a foe burned to death ends the battle in victory")
	ok(not b2.events.any(func(ev): return ev["type"] == "damage" and ev["side"] == "player"), "it never struck")
	# On the heir: the tick lands as the heir's turn begins.
	var d3 := _dyn("warrior", 20)
	var b3 := _battle(d3, 1)
	_sturdy(b3)
	b3.apply_status("heir", "poison", 0.05, 2, "enemy:0")
	b3.defend()
	var ticks: Array = b3.events.filter(func(ev): return ev["type"] == "tick" and ev["ref"] == "heir")
	ok(ticks.size() == 1 and int(ticks[0]["amount"]) == int(round(float(d3.heir.max_hp()) * 0.05)), "poison on the heir ticks at the start of the next turn")
	var last_blow := -1
	for k in b3.events.size():
		if b3.events[k]["type"] in ["damage", "miss"]:
			last_blow = k
	ok(not ticks.is_empty() and b3.events.find(ticks[0]) > last_blow, "after the foes have acted")
	b3.defend()
	ok(not b3.has_status("heir", "poison"), "and wears off")


func test_status_stacking() -> void:
	var d := _dyn("mage", 30)
	var b := _battle(d, 1)
	_sturdy(b)
	var ref := GameBattle.enemy_ref(0)
	for k in 5:
		b.apply_status(ref, "bleed", 0.1, 3, "heir", 100.0)
	ok(b.status_list(ref).size() == 1 and int(b.status_of(ref, "bleed")["stacks"]) == 3, "bleed stacks, up to three")
	var hp: int = b.enemies[0]["hp"]
	b._enemy_turn(0)
	ok(hp - int(b.enemies[0]["hp"]) == 30, "each stack bleeds (%d)" % (hp - int(b.enemies[0]["hp"])))
	b.apply_status(ref, "burn", 0.1, 4, "heir", 100.0)
	b.apply_status(ref, "burn", 0.3, 2, "heir", 100.0)
	var burn := b.status_of(ref, "burn")
	ok(int(burn["turns"]) == 4 and is_equal_approx(float(burn["amount"]), 30.0), "refresh keeps the longer time and the stronger burn")
	b.apply_status(ref, "burn", 0.1, 50, "heir", 100.0)
	ok(int(b.status_of(ref, "burn")["turns"]) == int(GameCombat.setting("status_turns_max")), "turns are capped")


func test_control() -> void:
	var d := _dyn("mage", 30)
	var b := _battle(d, 2)
	for e in b.enemies:
		e["hp"] = 100000
		e["max_hp"] = 100000
		e["atk"] = 50.0
	var ref := GameBattle.enemy_ref(0)
	b.apply_status(ref, "stun", 1.0, 1, "heir")
	b.events = []
	b._enemy_turn(0)
	ok(b.events.any(func(ev): return ev["type"] == "skip" and ev["ref"] == ref), "a stunned foe loses its turn")
	ok(not b.events.any(func(ev): return ev["type"] in ["damage", "miss"] and int(ev.get("index", -1)) == 0), "and does not attack")
	ok(not b.has_status(ref, "stun"), "a one-turn stun is spent")
	ok(not b.apply_status(ref, "stun", 1.0, 1, "heir"), "just freed: immune to being locked down again")
	ok(b.status_chance(ref, {"id": "sleep", "chance": 1.0}, "heir") == 0.0, "immunity shows as no chance")
	b._enemy_turn(0)
	ok(b.apply_status(ref, "stun", 1.0, 1, "heir"), "after acting once it can be stunned again")
	# Freeze: the next blow shatters it for extra damage.
	var d2 := _dyn("warrior", 30)
	var b2 := _battle(d2, 1)
	_sturdy(b2)
	var r2 := GameBattle.enemy_ref(0)
	var plain := b2.estimate(-1, {}, 0)
	b2.apply_status(r2, "freeze", 1.0, 1, "heir")
	ok(b2.estimate(-1, {}, 0) > plain * 1.5, "a frozen foe takes more from the next blow")
	b2._hit_enemy(0, d2.heir.attack_power(), 1.0, 0.0, 0.0)
	ok(not b2.has_status(r2, "freeze") and b2.events.any(func(ev): return ev.get("shatter", false)), "the blow shatters the ice")
	ok(b2.log.any(func(l): return str(l).find("shatters") >= 0), "shattering is told")
	# Sleep: a blow wakes the sleeper.
	b2.immune = {}
	b2.apply_status(r2, "sleep", 1.0, 2, "heir")
	ok(b2.is_held(r2), "asleep")
	b2._hit_enemy(0, 1.0, 1.0, 0.0, 0.0)
	ok(not b2.has_status(r2, "sleep"), "a blow wakes it")
	# Slow: every other turn lost, and slower to dodge on the heir.
	var d3 := _dyn("warrior", 30)
	var b3 := _battle(d3, 1)
	_sturdy(b3)
	var r3 := GameBattle.enemy_ref(0)
	b3.apply_status(r3, "slow", 0.2, 4, "heir")
	var skips := 0
	for k in 4:
		b3.events = []
		b3._enemy_turn(0)
		if b3.events.any(func(ev): return ev["type"] == "skip"):
			skips += 1
	ok(skips == 2, "slowed for four turns: acts on two of them (%d skipped)" % skips)
	b3.apply_status("heir", "slow", 0.2, 3, "enemy:0")
	ok(is_equal_approx(b3.status_mod("heir", "dodge"), -0.2), "slow takes from dodging")
	# Fear: a chance each turn to do nothing.
	var feared := 0
	for k in 200:
		b3.statuses.erase(r3)
		b3.immune = {}
		b3.apply_status(r3, "fear", 0.5, 2, "heir")
		b3.events = []
		b3._enemy_turn(0)
		if b3.events.any(func(ev): return ev["type"] == "skip"):
			feared += 1
	ok(feared > 70 and feared < 130, "fear of 50%% costs about half the turns (%d of 200)" % feared)
	# Weaken and vulnerable shift damage both ways.
	b3.statuses = {}
	var base := b3.estimate(-1, {}, 0)
	b3.apply_status(r3, "vulnerable", 0.3, 3, "heir")
	ok(absf(b3.estimate(-1, {}, 0) / base - 1.3) < 0.01, "vulnerable: 30% more damage taken")
	b3.apply_status("heir", "weaken", 0.25, 3, "enemy:0")
	ok(absf(b3.estimate(-1, {}, 0) / base - 1.3 * 0.75) < 0.01, "weaken: 25% less damage dealt")


func test_bosses_and_levels_resist() -> void:
	var d := _dyn("cleric", 15)
	d.world.visit("whisperwood")
	d.start_legend()
	var b := d.battle
	var ref := GameBattle.enemy_ref(0)
	ok(b.enemies[0]["boss"], "a legend")
	var entry := {"id": "stun", "chance": 0.75, "turns": 3}
	var want := 0.75 * float(GameCombat.setting("boss_control_chance"))
	ok(absf(b.status_chance(ref, entry, "heir") - want) < 0.001, "legends resist control (%.3f vs %.3f)" % [b.status_chance(ref, entry, "heir"), want])
	ok(absf(b.status_chance(ref, {"id": "burn", "chance": 0.5}, "heir") - 0.5) < 0.001, "but not harm over time")
	b.apply_status(ref, "stun", 1.0, 3, "heir")
	ok(int(b.status_of(ref, "stun")["turns"]) == int(GameCombat.setting("boss_control_max_turns")), "a legend is held one turn at most")
	b.apply_status(ref, "poison", 0.04, 3, "heir")
	ok(absf(float(b.status_of(ref, "poison")["amount"]) - 0.04 * float(b.enemies[0]["max_hp"]) * float(GameCombat.setting("boss_max_hp_tick_mult"))) < 0.01, "poison bites a legend less")
	d.battle = null
	# Foes far above the caster's level shrug off harm; never below the floor.
	var d2 := _dyn("mage", 100)
	var b2 := _battle(d2, 2)
	b2.enemies[1]["level"] = 160
	var even := b2.status_chance(GameBattle.enemy_ref(0), {"id": "slow", "chance": 0.8}, "heir")
	var above := b2.status_chance(GameBattle.enemy_ref(1), {"id": "slow", "chance": 0.8}, "heir")
	ok(absf(even - 0.8) < 0.001 and above < even and above >= 0.8 * float(GameCombat.setting("resist_floor")) - 0.0001, "level resistance: %.2f vs %.2f" % [even, above])
	b2.enemies[1]["level"] = 100000
	ok(absf(b2.status_chance(GameBattle.enemy_ref(1), {"id": "slow", "chance": 0.8}, "heir") - 0.8 * float(GameCombat.setting("resist_floor"))) < 0.0001, "a floor keeps some chance")
	ok(is_equal_approx(b2.status_chance("heir", {"id": "shield", "chance": 1.0}, "heir"), 1.0), "help for the party always lands")
	# Over many tries the rolled chance shows.
	var landed := 0
	for k in 400:
		b2.statuses = {}
		b2.immune = {}
		if b2.try_status(GameBattle.enemy_ref(0), {"id": "slow", "chance": 0.5, "turns": 2, "potency": 0.2}, "heir"):
			landed += 1
	ok(landed > 160 and landed < 240, "a 50%% status lands about half the time (%d of 400)" % landed)


func test_shield_regen_haste() -> void:
	var d := _dyn("cleric", 30)
	var b := _battle(d, 1)
	_sturdy(b)
	b.heir.mp = 100000
	b.cast_spell("ward", 0)
	ok(b.has_status("heir", "shield"), "Ward shields the heir")
	var pool := float(b.status_of("heir", "shield")["amount"]) if b.has_status("heir", "shield") else 0.0
	var full := 0.15 * float(d.heir.max_hp())
	ok(pool <= full and pool >= full - 1.0, "the shield holds 15%% of max HP, less the one point a toothless foe took (%.1f of %.1f)" % [pool, full])
	b.statuses = {}
	b.apply_status("heir", "shield", 0.1, 3, "heir")
	var cap := int(floor(0.1 * float(d.heir.max_hp())))
	var hp := d.heir.hp
	b.enemies[0]["atk"] = float(cap) * 10.0 + d.heir.defense() * 0.6
	b.weather = {"dodge": -1.0}
	b.events = []
	var log0 := b.log.size()
	b._enemy_act(0)
	var dmg: Array = b.events.filter(func(ev): return ev["type"] == "damage" and ev["side"] == "player")
	ok(dmg.size() == 1 and int(dmg[0]["absorbed"]) == cap and d.heir.hp == hp - int(dmg[0]["amount"]), "the shield soaks its fill, the rest gets through")
	ok(not b.has_status("heir", "shield"), "a spent shield is gone")
	var told: Array = b.log.slice(log0)
	ok(told.size() >= 2 and str(told[0]).find("(%d absorbed)" % cap) >= 0 and str(told[1]).find("fades") >= 0, "the blow is told with what the ward took, then the ward fades: %s" % str(told.slice(0, 2)))
	b.apply_status("heir", "shield", 0.5, 3, "heir")
	b.enemies[0]["atk"] = d.heir.defense() * 0.6 + 10.0
	log0 = b.log.size()
	b._enemy_act(0)
	ok(str(b.log[log0]).find("and the ward absorbs all") >= 0, "a blow the ward takes whole is told so: %s" % str(b.log[log0]))
	# Regeneration heals as the turn begins.
	d.heir.hp = 10
	b.statuses = {}
	b.apply_status("heir", "regen", 0.06, 2, "heir")
	b._start_heir_turn()
	ok(d.heir.hp == 10 + int(round(0.06 * float(d.heir.max_hp()))), "regen mends 6% of max HP a turn")
	# Haste: about the potency's share of extra actions.
	var extra := 0
	b.enemies[0]["atk"] = 0.0
	for k in 300:
		d.heir.hp = d.heir.max_hp()
		b.statuses = {}
		b.apply_status(GameBattle.enemy_ref(0), "haste", 0.4, 2, "enemy:0")
		b.events = []
		b._enemy_turn(0)
		if b.events.filter(func(ev): return ev["type"] in ["damage", "miss"]).size() >= 2:
			extra += 1
	ok(extra > 90 and extra < 150, "haste 0.4: a second action about 40%% of the time (%d of 300)" % extra)


func test_heir_loses_turn() -> void:
	var d := _dyn("warrior", 20)
	var b := _battle(d, 1)
	_sturdy(b)
	b.apply_status("heir", "stun", 1.0, 1, "enemy:0")
	b._start_heir_turn()
	ok(b.heir_skip, "a stunned heir loses the coming turn")
	ok(b.log.has("%s is stunned and loses the turn." % d.heir.name), "and is told so")
	var hp: int = b.enemies[0]["hp"]
	var mp := d.heir.mp
	b.use_skill(0, 0)
	ok(b.enemies[0]["hp"] == hp and d.heir.mp == mp, "any action just lets the turn pass")
	ok(not b.heir_skip and b.turn == 1, "the round went on without the heir")
	b.attack(0)
	ok(b.enemies[0]["hp"] < hp, "next turn the heir acts again")
	# Death from a tick at the start of the heir's turn is a defeat.
	var d2 := _dyn("warrior", 5)
	var b2 := _battle(d2, 1)
	_sturdy(b2)
	d2.heir.hp = 3
	b2.apply_status("heir", "burn", 1.0, 3, "enemy:0", 50.0)
	b2.defend()
	ok(b2.result == "defeat" and d2.heir.hp == 0, "burned to death: defeat")
	d2.finish_battle()
	ok(d2.state == "life" or d2.state == "succession", "and it settles like any defeat")


func test_creature_inflicts() -> void:
	var d := _dyn("warrior", 40)
	d.gen = 40
	var burned := 0
	var hits := 0
	for k in 60:
		var b := _battle(d, 1, "fire_imp")
		b.enemies[0]["hp"] = 1000000
		b.weather = {"dodge": -1.0}
		b._enemy_act(0)
		hits += 1
		if b.has_status("heir", "burn"):
			burned += 1
		d.battle = null
		d.heir.full_heal()
	ok(burned > 3 and burned < 30, "fire imps sometimes set the heir alight (%d of %d blows)" % [burned, hits])
	# What creatures inflict stays light: none of it ever costs the heir a turn.
	for c in GameData.creatures:
		for entry in c.get("inflicts", []):
			var b2 := _battle(d, 1)
			_sturdy(b2)
			b2.apply_status("heir", str(entry["id"]), float(entry.get("potency", 1.0)), int(entry.get("turns", 1)), "enemy:0", 10.0)
			var lost := 0
			for k in 4:
				b2._start_heir_turn()
				if b2.heir_skip:
					lost += 1
			ok(lost == 0, "%s's %s never costs the heir a turn (%d lost)" % [c["id"], entry["id"], lost])
			d.battle = null


func test_added_status() -> void:
	GameCombat.add_statuses([{"id": "test_toxin", "name": "Marsh Toxin", "tag": "TOX", "color": "#88aa44", "harmful": true,
		"tick": "damage", "basis": "max_hp", "stack": "stack", "max_stacks": 2, "default_turns": 2, "default_potency": 0.05,
		"text": {"apply": "{t} breathes the marsh air.", "tick": "The toxin burns in {t}'s blood for {n}.", "end": "{t} clears the toxin."}}])
	var d := _dyn("warrior", 20)
	var b := _battle(d, 1)
	_sturdy(b)
	ok(b.apply_status("heir", "test_toxin", 0.05, 2, ""), "a status from another system's data applies")
	b.apply_status("heir", "test_toxin", 0.05, 2, "")
	var hp := d.heir.hp
	b._start_heir_turn()
	ok(hp - d.heir.hp == int(round(0.05 * float(d.heir.max_hp()) * 2.0)), "and ticks with its own rules, both stacks (%d)" % (hp - d.heir.hp))
	ok(b.log.any(func(l): return str(l).find("toxin burns") >= 0), "in its own words")
	ok(b.cleanse("heir") == 1 and not b.has_status("heir", "test_toxin"), "and Cleanse washes it away")


func test_elements() -> void:
	ok(GameCombat.element_mult("frost", "fire") == 1.5 and GameCombat.element_mult("fire", "fire") == 0.5, "fire foes: weak to frost, resist fire")
	ok(GameCombat.element_mult("holy", "shadow") == 1.5 and GameCombat.element_mult("", "shadow") == 1.0 and GameCombat.element_mult("fire", "") == 1.0, "holy burns the dead; plain blows and plain foes are unchanged")
	var d := _dyn("mage", 40)
	d.gen = 40
	var b := _battle(d, 1, "fire_imp")
	_sturdy(b)
	var frost := b.estimate(-1, GameCombat.spell("cone_of_frost"), 0)
	var fire := b.estimate(-1, GameCombat.spell("cone_of_frost").merged({"element": "fire"}, true), 0)
	ok(absf(frost / fire - 3.0) < 0.01, "the same spell does three times as much as frost than as fire to a fire imp")
	# Ticks carry their element too: a fire imp shrugs off half a burn, poison bites it in full.
	var imp := GameBattle.enemy_ref(0)
	b.apply_status(imp, "burn", 0.2, 3, "heir", 500.0)
	var hp: int = b.enemies[0]["hp"]
	b._enemy_turn(0)
	ok(hp - int(b.enemies[0]["hp"]) == 50, "a burn of 100 a turn does 50 to a fire imp (%d)" % (hp - int(b.enemies[0]["hp"])))
	ok(b._tick_resisted(imp, 100, "nature") == 100, "poison is not resisted by fire")
	d.heir.traits.append("draconic_form")
	ok(b._tick_resisted("heir", 100, "fire") == 40, "the heir's draconic scales (60%% fire resistance) cool a burn of 100 to %d" % b._tick_resisted("heir", 100, "fire"))


# ---------------------------------------------------------------- party, dodging, sickness

func _full_party(d: GameDynasty, ids: Array = ["bren_cask", "sister_oriel", "corwin_saltmere"]) -> void:
	d.heir.gold = 1000000
	for id in ids:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": d.heir.level, "gen": d.gen, "due": 0.0, "battles": 0, "hired_gen": d.gen})
	d.party.rest(d)


## The heir and a full party of three against one to five foes: everyone has a place, every
## companion can use all it knows from where it stands, and the autopilot sees each fight through.
func test_party_of_three() -> void:
	var results := {}
	for n in range(1, 6):
		var d := _dyn("druid", 30, 610 + n)
		_full_party(d)
		var b := _battle(d, n, "goblin")
		ok(b.allies.size() == 3, "%d foes: three companions fight" % n)
		ok(is_equal_approx(b.foe_hp_mult, 1.0 + 3.0 * float(GameData.bal("companion_foe_hp"))), "%d foes: toughened for a party of three" % n)
		var spots := {b.unit_point(-1): true}
		for i in 3:
			spots[b.unit_point(i)] = true
		ok(spots.size() == 4, "%d foes: the heir and three companions stand apart" % n)
		ok(b.allies[1].spells == GameCombat.class_spells("cleric", 30) and b.allies[2].spells == GameCombat.class_spells("arcane_trickster", 30), "companions know their own class's spells")
		_sturdy(b)
		for i in 3:
			for o in GameTactics.options(b, i):
				b.events = []
				b.allies[i].mp = 100000
				b.resolve_ability(i, o["ab"], n - 1)
				ok(b.events.any(func(ev): return ev["type"] == "cast" and int(ev["by"]) == i), "%s used by companion %d on %d foes" % [o["ab"]["name"], i, n])
		# Companions step up to the heir's line to act: a front-rank cone reaches the front rank
		# from every place, a line reaches every foe it is aimed at.
		for i in 3:
			ok(is_equal_approx(b.cast_point(i).x, GameCombat.heir_point().x) and is_equal_approx(b.cast_point(i).y, b.unit_point(i).y), "companion %d acts from the front line" % i)
			for j in n:
				ok(j in b.aoe_targets(GameCombat.spell("chain_lightning"), i, j), "Chain Lightning from companion %d reaches foe %d" % [i, j])
				ok((j in b.aoe_targets(GameCombat.spell("cone_of_frost"), i, j)) == (b.enemies[j]["row"] == "front"), "Cone of Frost from companion %d reaches foe %d only in the front rank" % [i, j])
		d.battle = null
		d.party.rest(d)
		d.heir.full_heal()
		var fight := _battle(d, n, "goblin")
		GameBot.fight(d)
		results[fight.result] = int(results.get(fight.result, 0)) + 1
		ok(fight.result in ["victory", "defeat", "fled"], "a party of four against %d ends (%s)" % [n, fight.result])
	ok(int(results.get("victory", 0)) >= 4, "a party of four wins even fights: %s" % str(results))


func test_foe_dodge() -> void:
	var per := float(GameCombat.setting("foe_dodge_per_agi"))
	var d := _dyn("warrior", 30)
	var b := _battle(d, 3, "wolf")
	_sturdy(b)
	ok(is_equal_approx(b.foe_dodge(0), float(b.enemies[0]["agi"]) * per), "a foe dodges by its agility (%.3f)" % b.foe_dodge(0))
	b.apply_status(GameBattle.enemy_ref(1), "slow", 0.2, 3, "heir")
	ok(b.foe_dodge(1) == 0.0, "a slowed wolf cannot dodge")
	b.apply_status(GameBattle.enemy_ref(2), "stun", 1.0, 1, "heir")
	ok(b.foe_dodge(2) == 0.0, "nor can a stunned one")
	b.statuses = {}
	b.enemies[0]["agi"] = 20
	var plain := b.estimate(-1, {}, 0)
	b.enemies[0]["agi"] = 0
	ok(absf(plain / b.estimate(-1, {}, 0) - (1.0 - 20.0 * per)) < 0.001, "expected damage counts the dodge")
	b.enemies[0]["agi"] = 20
	var missed := 0
	for k in 1000:
		b.events = []
		if b._hit_enemy(0, 100.0, 1.0, 0.0, 0.0) < 0:
			missed += 1
			ok(b.events.size() == 1 and b.events[0]["type"] == "miss" and b.events[0]["side"] == "enemy", "a dodge is told as a miss on the foe")
	var want := 1000.0 * 20.0 * per
	ok(absf(float(missed) - want) < want * 0.4, "agility 20 dodges about %d of 1000 blows (%d)" % [int(want), missed])
	# A foe that slips an area blow slips what rides on it; a spell with no blow cannot be dodged.
	var s := GameCombat.settings()
	var keep := [s["foe_dodge_per_agi"], s["foe_dodge_max"]]
	s["foe_dodge_per_agi"] = 1.0
	s["foe_dodge_max"] = 1.0
	b.events = []
	b.resolve_ability(-1, {"name": "Test Blast", "mult": 1.0, "target": {"shape": "all"}, "is_aoe": true, "statuses": [{"id": "burn", "chance": 1.0, "turns": 2, "potency": 0.1}]}, 0)
	ok(b.events.filter(func(ev): return ev["type"] == "miss").size() == 3 and not b.events.any(func(ev): return ev["type"] == "damage"), "every foe dodged the blast")
	ok(range(3).all(func(i): return not b.has_status(GameBattle.enemy_ref(i), "burn")), "and none caught fire")
	b.resolve_ability(-1, {"name": "Test Hush", "mult": 0.0, "target": {"shape": "all"}, "is_aoe": true, "statuses": [{"id": "sleep", "chance": 1.0, "turns": 2}]}, 0)
	ok(range(3).all(func(i): return b.has_status(GameBattle.enemy_ref(i), "sleep")), "a hush with no blow is not dodged")
	s["foe_dodge_per_agi"] = keep[0]
	s["foe_dodge_max"] = keep[1]


## Sickness weakens what the heir and companions do with spells and skills.
func test_disease_saps_power() -> void:
	var d := _dyn("mage", 40)
	var b := _battle(d, 1)
	_sturdy(b)
	var mag := float(b.unit_numbers(-1)["mag"])
	var fireball := b.estimate(-1, GameCombat.spell("fireball"), 0)
	var firebolt := b.estimate(-1, b.skill_info(0), 0)
	d.battle = null
	ok(GameDisease.infect(d.heir, "shaking_ague", "test", 2), "the heir has a shaking ague (element power -10%)")
	var b2 := _battle(d, 1)
	_sturdy(b2)
	ok(float(b2.unit_numbers(-1)["mag"]) < mag and is_equal_approx(float(b2.unit_numbers(-1)["mag"]), d.heir.magic_power()), "spell power drops (%.1f -> %.1f)" % [mag, float(b2.unit_numbers(-1)["mag"])])
	ok(b2.estimate(-1, GameCombat.spell("fireball"), 0) < fireball, "Fireball hits softer")
	ok(b2.estimate(-1, b2.skill_info(0), 0) < firebolt, "so does the class skill")
	d.battle = null
	var w := _dyn("warrior", 40)
	var wb := _battle(w, 1)
	_sturdy(wb)
	var strike := wb.estimate(-1, wb.skill_info(0), 0)
	var mend := GameBattle.heal_amount(w.heir, w.heir, w.heir.cls()["skills"][1])
	w.battle = null
	GameDisease.infect(w.heir, "red_flux", "test", 2)
	GameDisease.infect(w.heir, "grave_rot", "test", 2)
	var wb2 := _battle(w, 1)
	_sturdy(wb2)
	ok(wb2.estimate(-1, wb2.skill_info(0), 0) < strike, "a flux weakens the warrior's strike")
	ok(GameBattle.heal_amount(w.heir, w.heir, w.heir.cls()["skills"][1]) < mend, "grave rot weakens healing")
	w.battle = null


## The player asked for low odds of sickness: nothing a fight can hand out passes 2%.
func test_disease_chances_low() -> void:
	for id in GameData.items:
		var it: Dictionary = GameData.items[id]
		if it.has("vial"):
			ok(float(it["vial"].get("splash", 0.0)) <= 0.02, "%s: a thrower catches it at most 2%% of the time" % id)
		if it.has("toxin"):
			ok(float(it["toxin"].get("backfire", {}).get("chance", 0.0)) <= 0.02, "%s: a toxin backfires at most 2%% of the time" % id)


# ---------------------------------------------------------------- learning and costs

func test_costs_and_learning() -> void:
	var fb := GameCombat.spell("fireball")
	var growth := float(GameData.bal("skill_cost_growth_per_level"))
	ok(GameCombat.ability_cost(fb, 1) == int(fb["mp"]), "level 1 pays the listed cost")
	ok(GameCombat.ability_cost(fb, 5000) == int(round(float(fb["mp"]) * (1.0 + growth * 4999.0))), "costs grow with level like class skills")
	for cid in GameData.classes:
		var plan := GameCombat.class_spell_plan(cid)
		for lv in [1, 30, 5000]:
			var u := GameHeir.new()
			u.class_id = cid
			u.level = lv
			for id in GameCombat.class_spells(cid, lv):
				var c := GameCombat.ability_cost(GameCombat.spell(id), lv)
				ok(c <= u.max_mp(), "%s L%d can afford %s (%d of %d MP)" % [cid, lv, id, c, u.max_mp()])
		var levels: Array = plan.map(func(p): return p[1])
		var sorted := levels.duplicate()
		sorted.sort()
		ok(levels == sorted, "%s learns in level order" % cid)
	var casters := ["mage", "cleric", "druid", "necromancer", "warlock", "shaman"]
	for cid in casters:
		var plan := GameCombat.class_spell_plan(cid)
		ok(plan.size() >= 7, "%s has a full spell list (%d)" % [cid, plan.size()])
		ok(int(plan[0][1]) <= 3, "%s starts with a spell early (level %d)" % [cid, plan[0][1]])
		ok(plan.filter(func(p): return int(p[1]) <= 30).size() >= 4, "%s learns several spells in the first 30 levels" % cid)
		ok(plan.filter(func(p): return int(p[1]) > 30).size() >= 2, "%s still has spells to learn later" % cid)
	for cid in ["spellblade", "paladin", "arcane_trickster", "dread_knight", "templar", "beastmaster"]:
		var plan := GameCombat.class_spell_plan(cid)
		ok(plan.size() >= 3 and plan.size() <= 7, "%s, a half-caster, has a short list (%d)" % [cid, plan.size()])
	for cid in ["warrior", "rogue", "ranger", "monk", "duelist", "ninja", "warden"]:
		ok(GameCombat.class_spell_plan(cid).is_empty(), "%s learns no spells" % cid)
	var mage := GameCombat.class_spell_plan("mage")
	ok(mage.any(func(p): return int(p[1]) >= 100 and int(p[1]) < 1000) and mage.any(func(p): return int(p[1]) >= 1000), "the mage's last spells wait for very high levels")
	# Learning by levelling, announced once in the journal.
	var d := GameDynasty.new_game(5, "Tess", "mage", "faetouched", "human")
	d.pending_event = {}
	ok(d.heir.spells == GameCombat.class_spells("mage", 1), "a founder knows the level-1 spells")
	d.heir.gain_xp(400)
	var lv := d.heir.level
	ok(lv >= 4 and "sleep" in d.heir.spells, "levelling to %d teaches Sleep" % lv)
	var j0 := d.journal.size()
	d.work()
	var lines := d.journal.slice(j0).filter(func(l): return str(l).find("learns to cast") >= 0)
	ok(lines.size() == 1 and str(lines[0]).find("Sleep") >= 0, "the journal tells of the new spells once: %s" % str(lines))
	ok(d.heir.spell_news.is_empty(), "and the news is spent")
	# A new heir starts over with their own class's spells.
	var d2 := GameDynasty.new_game(6, "Tess", "warrior", "faetouched", "human")
	d2.pending_event = {}
	ok(d2.heir.spells.is_empty(), "a warrior founder knows no spells")


func test_spells_save_load() -> void:
	var d := _dyn("druid", 1)
	d.heir.gain_xp(3000)
	var known := d.heir.spells.duplicate()
	ok(known.size() >= 3, "a druid of level %d knows %d spells" % [d.heir.level, known.size()])
	var text := JSON.stringify(d.to_dict())
	var e := GameDynasty.from_dict(JSON.parse_string(text))
	ok(e.heir.spells == known, "known spells survive save and load")
	ok(JSON.stringify(e.to_dict()) == text, "the dynasty round-trips exactly")
	# Pending news survives a reload, so the journal tells the same story.
	var raw: Dictionary = JSON.parse_string(text)
	raw["heir"]["spell_news"] = ["acid_rain"]
	var f := GameDynasty.from_dict(raw)
	ok(f.heir.spell_news == ["acid_rain"], "unannounced spells survive a reload")
	# Saves from before the spellbook: the heir knows what the level allows; children nothing yet.
	var old: Dictionary = JSON.parse_string(text)
	old["heir"].erase("spells")
	old["heir"].erase("spell_news")
	var g := GameDynasty.from_dict(old)
	ok(g.heir.spells == GameCombat.class_spells("druid", g.heir.level), "an old save derives the spells from the level")
	ok(g.heir.spell_news.is_empty(), "without announcing them")
	g.start_hunt("hunt")
	GameBot.fight(g)
	ok(g.state == "life" or g.state == "succession", "an old save fights on")
	# A spell list that grew since the save teaches the heir at once and says so; a spell gone from
	# the data is forgotten.
	var grown: Dictionary = JSON.parse_string(text)
	var dropped: String = known[known.size() - 1]
	grown["heir"]["spells"] = known.slice(0, known.size() - 1) + ["no_such_spell"]
	grown["heir"]["spell_news"] = ["no_such_spell"]
	var k := GameDynasty.from_dict(grown)
	ok(dropped in k.heir.spells and "no_such_spell" not in k.heir.spells, "a loaded heir knows every spell the level allows, and only real ones")
	ok(k.heir.spell_news == [dropped], "the spell new to this save is announced: %s" % str(k.heir.spell_news))
	var j0 := k.journal.size()
	k.pending_event = {}
	k.work()
	ok(k.journal.slice(j0).any(func(l): return str(l).find("learns to cast %s" % GameCombat.spell(dropped)["name"]) >= 0), "in the journal")
	# A fixture save from before this system loads and its heir can cast.
	var fx := FileAccess.open("res://tests/fixtures/save_pr4_life.json", FileAccess.READ)
	if fx != null:
		var h := GameDynasty.from_dict(JSON.parse_string(fx.get_as_text()))
		ok(h.heir.spells == GameCombat.class_spells(h.heir.class_id, h.heir.level), "the old fixture heir knows the spells of a %s of level %d" % [h.heir.class_id, h.heir.level])


func test_companion_spells() -> void:
	var d := _dyn("warrior", 20)
	d.heir.gold = 100000
	for id in ["sister_oriel", "old_netta"]:
		d.party.members.append({"id": id, "name": id, "hp": 1, "mp": 0, "level": 20, "gen": 1, "due": 0.0, "battles": 0, "hired_gen": 1})
	d.party.rest(d)
	d.start_hunt("hunt")
	var b := d.battle
	ok(b.allies[0].spells == GameCombat.class_spells("cleric", 20), "a cleric companion knows the cleric's spells for level 20: %s" % str(b.allies[0].spells))
	ok(b.allies[1].spells == GameCombat.class_spells("druid", 20), "a druid companion likewise")
	ok(JSON.stringify(d.party.to_dict()).find("spells") < 0, "companion spells are never saved: they follow class and level")
	d.battle = null


# ---------------------------------------------------------------- packs

func test_packs() -> void:
	var d := _dyn("warrior", 20)
	var sizes := {}
	var packs := 0
	var tries := 400
	var pool := GameData.creatures.filter(func(c): return not c.get("boss", false) and int(c["min_gen"]) <= 1)
	for k in tries:
		var p := GameCombat.roll_pack(d, "hunt_hard", pool)
		if p.is_empty():
			continue
		packs += 1
		sizes[p["size"]] = true
		ok(p["creature"].get("swarm", false), "packs come from swarming kinds when the land has them")
		ok(absf(float(p["power"]) * float(p["size"]) - float(GameCombat.formation()["packs"]["kinds"]["hunt_hard"]["power"])) < 0.001, "a pack shares one power budget")
	ok(packs > tries * 0.3 and packs < tries * 0.75, "hard hunts often meet packs (%d of %d)" % [packs, tries])
	ok(sizes.keys().all(func(s): return int(s) >= 4 and int(s) <= 5), "hard-hunt packs are 4-5 strong (%s)" % str(sizes.keys()))
	var plain := 0
	for k in tries:
		if not GameCombat.roll_pack(d, "hunt", pool).is_empty():
			plain += 1
	ok(plain > tries * 0.08 and plain < tries * 0.4, "plain hunts meet packs now and then (%d of %d)" % [plain, tries])
	ok(GameCombat.roll_pack(d, "legend", pool).is_empty(), "legends never come as packs")
	# Through real hunts: packs are one kind of foe, and the spoils weigh about what a usual hunt's do.
	var pack_xp: Array = []
	var usual_xp: Array = []
	var d2 := _dyn("warrior", 30, 77)
	d2.world.visit("whisperwood")
	for k in 300:
		d2.start_hunt("hunt")
		var b := d2.battle
		var xp := 0
		for e in b.enemies:
			xp += int(e["xp"])
		if b.enemies.size() >= 3:
			ok(b.enemies.all(func(e): return e["id"] == b.enemies[0]["id"]), "a pack is one kind of creature")
			pack_xp.append(xp)
		else:
			usual_xp.append(xp)
		d2.battle = null
	var mean := func(a: Array) -> float:
		var t := 0.0
		for x in a:
			t += float(x)
		return t / maxf(1.0, float(a.size()))
	ok(not pack_xp.is_empty(), "packs turn up in plain hunts (%d of 300)" % pack_xp.size())
	var ratio: float = mean.call(pack_xp) / mean.call(usual_xp)
	ok(ratio > 0.75 and ratio < 1.35, "a pack is worth about a usual hunt's XP (%.2f)" % ratio)


## A pack hurts about as much as the usual foes of the same hunt, though armour blunts each of its
## smaller blows: the same heirs (fixed seeds, the autopilot, alone or with three companions) lose
## about as much HP to either, a defeat counting as all of it.
func test_pack_threat() -> void:
	var packs: Dictionary = GameCombat.formation()["packs"]
	var keep := {"swarm_bonus": packs["swarm_bonus"], "biomes": packs["biomes"].duplicate(), "chance": {}}
	packs["swarm_bonus"] = 0.0
	for k in packs["biomes"]:
		packs["biomes"][k] = 0.0
	for k in packs["kinds"]:
		keep["chance"][k] = packs["kinds"][k]["chance"]
	for kind in ["hunt", "hunt_hard"]:
		var lost := {"usual": 0.0, "pack": 0.0}
		for mode in lost:
			for k in packs["kinds"]:
				packs["kinds"][k]["chance"] = 1.0 if mode == "pack" else 0.0
			for cls in ["warrior", "mage", "ranger", "cleric", "rogue", "druid"]:
				for spec in [[8, 1], [60, 1], [1200, 100]]:
					for k in 4:
						var d := _dyn(cls, spec[0], 500 + k * 31 + spec[0] + cls.length())
						d.gen = spec[1]
						d.heir.gen = spec[1]
						d.heir.full_heal()
						d.heir.potions = 2
						d.world.visit(["whisperwood", "goblin_warrens", "mirefen", "the_rift"][k])
						if k % 2 == 1:
							_full_party(d)
						d.rng.seed = 900 + k * 7 + spec[0]
						var b := d.start_hunt(kind)
						var guard := 0
						while not b.is_over() and guard < 300:
							guard += 1
							GameTactics.act(b, GameTactics.choose(b, -1))
						lost[mode] += 1.0 if b.result == "defeat" else 1.0 - float(d.heir.hp) / float(d.heir.max_hp())
						d.battle = null
		var ratio := float(lost["pack"]) / maxf(0.001, float(lost["usual"]))
		ok(ratio > 0.8 and ratio < 1.35, "%s: a pack costs about the HP the usual foes do (x%.2f)" % [kind, ratio])
	packs["swarm_bonus"] = keep["swarm_bonus"]
	packs["biomes"] = keep["biomes"]
	for k in packs["kinds"]:
		packs["kinds"][k]["chance"] = keep["chance"][k]


# ---------------------------------------------------------------- tactics

func test_tactics() -> void:
	# Five even foes in reach: an area that catches several beats any single blow.
	var d := _dyn("mage", 30)
	var b := _battle(d, 5, "goblin")
	for e in b.enemies:
		e["hp"] = 2000
		e["max_hp"] = 2000
	var plan := GameTactics.choose(b, -1)
	ok(plan["act"] == "ability" and GameCombat.is_aoe(plan["ab"]) and b.aoe_targets(plan["ab"], -1, int(plan["target"])).size() >= 2, "against a pack the mage casts an area: %s" % str(plan.get("ab", {}).get("name", plan["act"])))
	d.battle = null
	var b1 := _battle(d, 1, "goblin")
	b1.enemies[0]["hp"] = 5000
	b1.enemies[0]["max_hp"] = 5000
	var single := GameTactics.choose(b1, -1)
	ok(single["act"] == "ability" and not GameCombat.is_aoe(single["ab"]), "against one foe, a single-target strike: %s" % str(single.get("ab", {}).get("name", single["act"])))
	d.battle = null
	# Low on HP with no potions: heal; with the party hurt too: the party heal.
	var c := _dyn("cleric", 30)
	c.heir.gold = 100000
	c.party.hire(c, "bren_cask")
	var cb := _battle(c, 2)
	_sturdy(cb)
	c.heir.potions = 0
	c.heir.hp = int(c.heir.max_hp() * 0.2)
	var heal := GameTactics.choose(cb, -1)
	ok(heal["act"] == "ability" and heal["ab"].has("pct_max_hp") and not heal["ab"].get("party", false), "a lone hurt heir uses the class heal: %s" % str(heal.get("ab", {}).get("name", "")))
	cb.allies[0].hp = int(cb.allies[0].max_hp() * 0.2)
	var group := GameTactics.choose(cb, -1)
	ok(group["act"] == "ability" and group["ab"].get("party", false), "with the companion hurt too, Mass Heal: %s" % str(group.get("ab", {}).get("name", "")))
	c.heir.potions = 2
	ok(GameTactics.choose(cb, -1)["act"] == "potion", "a potion first while there are any")
	# A heavy affliction is cleansed.
	c.heir.hp = c.heir.max_hp()
	cb.allies[0].hp = cb.allies[0].max_hp()
	cb.apply_status("heir", "poison", 0.08, 3, "enemy:0")
	cb.apply_status("heir", "burn", 0.2, 3, "enemy:0", float(c.heir.max_hp()) * 0.5)
	var wash := GameTactics.choose(cb, -1)
	ok(wash["act"] == "ability" and wash["ab"].get("cleanse", false), "a heavy affliction is cleansed: %s" % str(wash.get("ab", {}).get("name", wash["act"])))
	cb.use_ability(wash["ab"], -1, 0)
	ok(cb.status_list("heir").is_empty(), "Cleanse clears it")
	c.battle = null
	# The most dangerous foe is held when the party can press on without it.
	var m := _dyn("mage", 30)
	m.heir.gold = 100000
	m.party.hire(m, "bren_cask")
	m.party.hire(m, "maddy_thorn")
	var mb := _battle(m, 2, "goblin")
	mb.enemies[0]["atk"] = float(mb.enemies[0]["atk"]) * 6.0
	for e in mb.enemies:
		e["hp"] = 4000
		e["max_hp"] = 4000
	var hold := GameTactics.choose(mb, -1)
	var holds := false
	if hold["act"] == "ability":
		for st in hold["ab"].get("statuses", []):
			holds = holds or GameCombat.status_def(str(st["id"])).has("skip")
	ok(holds and 0 in mb.aoe_targets(hold["ab"], -1, int(hold["target"])), "the brute is held: %s" % str(hold.get("ab", {}).get("name", hold["act"])))
	# Companions: press the heir's focus, never wake a sleeper while another foe stands.
	mb.focus = 0
	mb.apply_status(GameBattle.enemy_ref(0), "sleep", 1.0, 2, "heir")
	var ally := GameTactics.choose(mb, 0)
	ok(int(ally.get("target", -1)) == 1, "a companion leaves the sleeper and strikes the other foe")
	m.battle = null
	# A companion mage uses areas against a pack.
	var w := _dyn("warrior", 30)
	w.heir.gold = 100000
	w.party.members.append({"id": "corwin_saltmere", "name": "Corwin", "hp": 1, "mp": 0, "level": 30, "gen": 1, "due": 0.0, "battles": 0, "hired_gen": 1})
	w.party.rest(w)
	var wb := _battle(w, 5, "goblin")
	for e in wb.enemies:
		e["hp"] = 3000
		e["max_hp"] = 3000
	var cast := GameTactics.choose(wb, 0)
	ok(cast["act"] == "ability" and GameCombat.is_aoe(cast["ab"]), "a companion caster hits a pack with an area: %s" % str(cast.get("ab", {}).get("name", cast["act"])))
	w.battle = null


func test_bot_all_classes() -> void:
	var results := {}
	for cid in GameData.classes:
		for spec in [[1, 1], [30, 1], [5000, 300]]:
			var d := _dyn(cid, spec[0], 300 + spec[0])
			d.gen = spec[1]
			d.heir.gen = spec[1]
			d.heir.full_heal()
			for n in [1, 3, 5]:
				var b := _battle(d, n, "goblin", 0.6)
				GameBot.fight(d)
				results[b.result] = int(results.get(b.result, 0)) + 1
				ok(b.result in ["victory", "defeat", "fled"], "%s L%d vs %d: the fight ends (%s)" % [cid, spec[0], n, b.result])
				if d.state != "life":
					break
				d.heir.full_heal()
	ok(int(results.get("victory", 0)) > int(results.get("defeat", 0)) * 4, "the autopilot mostly wins even fights: %s" % str(results))


func test_determinism() -> void:
	var runs: Array = []
	for k in 2:
		var d := GameDynasty.new_game(4242, "Tess", "shaman", "faetouched", "human")
		d.pending_event = {}
		d.heir.gold = 5000
		d.party.hire(d, "sister_oriel")
		for s in 120:
			if d.state != "life":
				break
			GameBot.step(d)
		runs.append([JSON.stringify(d.to_dict()), "\n".join(d.journal)])
	ok(runs[0][0] == runs[1][0] and runs[0][1] == runs[1][1], "same seed, same dynasty and journal through spells, packs and statuses")
	# One battle replayed from the same RNG state plays out the same way.
	var logs: Array = []
	for k in 2:
		var d := _dyn("mage", 40, 99)
		d.rng.seed = 12345
		var b := _battle(d, 5)
		GameBot.fight(d)
		logs.append("\n".join(b.log))
	ok(logs[0] == logs[1] and logs[0].length() > 0, "a battle replays exactly")


# ---------------------------------------------------------------- screen

func _frames(n: int = 4) -> void:
	for i in n:
		await process_frame


func _button(n: Node, prefix: String) -> Button:
	if n is Button and n.is_visible_in_tree() and not n.disabled and n.text.begins_with(prefix):
		return n
	for c in n.get_children():
		var b := _button(c, prefix)
		if b != null:
			return b
	return null


func _ui_tests() -> void:
	var real := GameDynasty.save_path
	GameDynasty.save_path = "user://test_combat_ui_save.json"
	root.size = Vector2i(1280, 720)
	var app = GameApp.new()
	root.add_child(app)
	await _frames()
	app.new_game("Tess", "mage", "faetouched", 31, "human")
	var d: GameDynasty = app.dynasty
	d.pending_event = {}
	d.heir.level = 40
	d.heir.spells = []
	d.heir.learn_spells()
	d.heir.full_heal()
	_full_party(d)
	var foes: Array = []
	for i in 5:
		foes.append(d._make_enemy(GameCombat.creature_def("goblin"), 1.0, 1.0, 40))
	d._begin_battle(foes, "hunt")
	for e in d.battle.enemies:
		e["hp"] = 100000
		e["max_hp"] = 100000
		e["atk"] = 0.0
	app.show_state()
	await _frames(6)
	var view: Control = app.current
	ok(view.enemy_nodes.size() == 5 and view.ally_nodes.size() == 3, "five foes and three companions on screen")
	ok(view.hero_info.text == "HP %s  MP %s" % [GameText.num(d.heir.hp), GameText.num(d.heir.mp)], "the heir's HP and MP in numbers: %s" % view.hero_info.text)
	var figures: Array = [["the heir", view.hero_node]]
	for i in 3:
		figures.append(["companion %d" % i, view.ally_nodes[i]["root"]])
	for i in 5:
		figures.append(["foe %d" % i, view.enemy_nodes[i]["root"]])
	var arena_rect: Rect2 = view.arena.get_global_rect()
	for i in figures.size():
		var r: Rect2 = figures[i][1].get_global_rect()
		ok(arena_rect.grow(1.0).encloses(r), "%s fits in the arena (%s)" % [figures[i][0], str(r)])
		for j in range(i + 1, figures.size()):
			ok(not r.intersects(figures[j][1].get_global_rect()), "%s and %s do not overlap" % [figures[i][0], figures[j][0]])
	var spells := _button(view, "Spells")
	ok(spells != null, "a Spells command")
	spells.pressed.emit()
	await _frames(3)
	ok(view.spell_list != null, "the spell list opens")
	var fireball := _button(view.spell_list, "Fireball")
	ok(fireball != null, "Fireball is listed and affordable")
	fireball.pressed.emit()
	await _frames(3)
	ok(not view.aiming.is_empty() and view.spell_list == null, "choosing an area spell starts aiming")
	var marked := 0
	for en in view.enemy_nodes:
		if en["mark"].visible:
			marked += 1
	var want: int = d.battle.aoe_targets(GameCombat.spell("fireball"), -1, view.aim_at).size()
	ok(marked == want and marked >= 2, "every foe the burst would catch is outlined before casting (%d of %d)" % [marked, want])
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	view.enemy_nodes[1]["body"].gui_input.emit(ev)
	await _frames(2)
	ok(view.aim_at == 1, "a click on another foe moves the aim")
	var mp := d.heir.mp
	view.enemy_nodes[1]["body"].gui_input.emit(ev)
	await _frames(2)
	ok(d.heir.mp < mp and d.battle.log.any(func(l): return str(l) == "Tess casts Fireball."), "a second click casts it")
	for k in 60:
		if not view.busy:
			break
		await create_timer(0.2).timeout
	ok(view.aiming.is_empty() and _button(view, "Attack") != null, "the commands come back after the turn")
	# Hovering a strike outlines the foe it would hit; hovering a heal outlines none.
	var marks := func() -> int:
		return view.enemy_nodes.filter(func(en): return en["mark"].visible).size()
	d.heir.mp = d.heir.max_mp()
	view._build_commands()
	await _frames(2)
	var bolt := _button(view, "Firebolt")
	bolt.mouse_entered.emit()
	await _frames(2)
	ok(marks.call() == 1 and view.enemy_nodes[view.target]["mark"].visible, "hovering Firebolt outlines its target")
	bolt.mouse_exited.emit()
	var mend := _button(view, "Mend")
	mend.mouse_entered.emit()
	await _frames(2)
	ok(marks.call() == 0, "hovering Mend outlines no foe")
	mend.mouse_exited.emit()
	var chip_texts: Array = []
	d.battle.apply_status("heir", "haste", 0.4, 3, "heir")
	view._refresh_chips()
	for c in view.hero_chips.get_children():
		chip_texts.append(c.text)
	ok(chip_texts.has("HST 3"), "status chips show tag and turns left: %s" % str(chip_texts))
	# A stunned heir: the round passes on its own.
	d.battle.apply_status("heir", "stun", 1.0, 2, "enemy:0")
	var turn := d.battle.turn
	_button(view, "Defend").pressed.emit()
	for k in 80:
		if d.battle.turn >= turn + 2 and not view.busy:
			break
		await create_timer(0.2).timeout
	ok(d.battle.turn >= turn + 2, "a stunned heir's turn passes without a click (turn %d -> %d)" % [turn, d.battle.turn])
	await _ui_reach_and_ranks(view, d, ev)
	app.queue_free()
	GameDynasty.save_path = real
	_done()


## A cone aimed past its reach outlines only the foes it reaches and says so; an area that reaches
## no one cannot be cast; a long row of statuses folds into "+N"; the back rank's figures step up.
func _ui_reach_and_ranks(view: Control, d: GameDynasty, ev: InputEventMouseButton) -> void:
	var b: GameBattle = d.battle
	b.statuses = {}
	b.immune = {}
	for e in b.enemies:
		e["agi"] = 0
	var back := -1
	for i in b.enemies.size():
		if b.enemies[i]["row"] == "back" and b.enemies[i]["hp"] > 0:
			back = i
	d.heir.mp = d.heir.max_mp()
	view._build_commands()
	await _frames(2)
	_button(view, "Spells").pressed.emit()
	await _frames(3)
	_button(view.spell_list, "Cone of Frost").pressed.emit()
	await _frames(3)
	view.enemy_nodes[back]["body"].gui_input.emit(ev)
	await _frames(2)
	var caught := b.aoe_targets(GameCombat.spell("cone_of_frost"), -1, back)
	var outlined: Array = []
	for i in view.enemy_nodes.size():
		if view.enemy_nodes[i]["mark"].visible:
			outlined.append(i)
	ok(view.aim_at == back and back not in caught and not caught.is_empty() and outlined == caught, "a cone aimed at the back row outlines the front foes it reaches (%s), not the one beyond (%d)" % [str(outlined), back])
	ok(view.aim_info.text.find("beyond reach") >= 0, "and the panel says so: %s" % view.aim_info.text)
	_button(view, "Cancel").pressed.emit()
	await _frames(2)
	var pinhole := {"name": "Pinhole", "mult": 1.0, "target": {"shape": "cone", "angle": 2, "range": 3}, "is_aoe": true}
	view._begin_aim(pinhole, -1, "test")
	await _frames(2)
	var go: Button = null
	for btn in view.command_box.find_children("*", "Button", true, false):
		if btn.text == "Cast":
			go = btn
	var mp := d.heir.mp
	var turn := b.turn
	view._confirm_aim()
	await _frames(2)
	ok(go != null and go.disabled and view.aim_info.text.find("reaches no foe") >= 0 and d.heir.mp == mp and b.turn == turn, "an area that reaches no one cannot be cast: %s" % view.aim_info.text)
	view._cancel_aim()
	await _frames(2)
	for id in ["burn", "poison", "bleed", "weaken", "vulnerable", "slow", "fear"]:
		b.apply_status(GameBattle.enemy_ref(0), id, 0.1, 3, "heir", 50.0)
	view._refresh_chips()
	await _frames(2)
	var box: HBoxContainer = view.enemy_nodes[0]["chips"]
	var last: Label = box.get_child(box.get_child_count() - 1)
	ok(last.text.begins_with("+") and box.get_combined_minimum_size().x <= float(view.enemy_nodes[0]["w"]) + 52.0 + 1.0, "seven statuses fold into a +N chip beside the figure (%s, %.0f px)" % [last.text, box.get_combined_minimum_size().x])
	b.statuses = {}
	for i in b.enemies.size():
		if b.enemies[i]["row"] == "front":
			b.enemies[i]["hp"] = 1
	var was: float = view.enemy_nodes[back]["root"].position.x
	view._do(func(): b.use_ability({"name": "Test Quake", "mult": 1.0, "target": {"shape": "all"}, "is_aoe": true}, 0, 0))
	for k in 60:
		if not view.busy:
			break
		await create_timer(0.2).timeout
	await _frames(4)
	ok(b.enemies[back]["row"] == "front" and view.enemy_nodes[back]["root"].position.x < was - 20.0, "the back rank steps up on the screen too (%.0f -> %.0f)" % [was, view.enemy_nodes[back]["root"].position.x])
