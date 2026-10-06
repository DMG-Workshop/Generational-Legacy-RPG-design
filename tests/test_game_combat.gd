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
	test_costs_and_learning()
	test_spells_save_load()
	test_companion_spells()
	test_packs()
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
	var ids := GameCombat.spell_ids()
	ok(ids.size() >= 22 and ids.size() <= 28, "about two dozen spells (%d)" % ids.size())
	var groups := {}
	for id in ids:
		var sp := GameCombat.spell(id)
		for key in ["id", "name", "group", "school", "element", "type", "mp", "target", "learn"]:
			ok(sp.has(key), "%s has %s" % [id, key])
		groups[sp["group"]] = int(groups.get(sp["group"], 0)) + 1
		var shape := GameCombat.shape(sp)
		ok(shape in ["single", "burst", "cone", "line", "all", "party"], "%s shape %s" % [id, shape])
		ok(bool(sp.get("is_aoe", false)) == (shape in ["burst", "cone", "line", "all"]), "%s is_aoe matches its shape" % id)
		for st in sp.get("statuses", []):
			ok(not GameCombat.status_def(str(st["id"])).is_empty(), "%s status %s defined" % [id, st["id"]])
		for c in sp["learn"]["classes"]:
			ok(GameData.classes.has(c), "%s learnable by a real class (%s)" % [id, c])
		ok(GameCombat.describe(sp) != "", "%s has a one-line effect" % id)
		if sp.get("element", "") != "":
			ok(GameData.combat["elements"]["elements"].has(sp["element"]), "%s element known" % id)
	ok(int(groups.get("elemental", 0)) >= 8 and int(groups.get("control", 0)) >= 5 and int(groups.get("utility", 0)) >= 6, "three groups: %s" % str(groups))
	for want in ["burn", "poison", "bleed", "stun", "freeze", "slow", "weaken", "vulnerable", "shield", "regen", "haste"]:
		ok(not GameCombat.status_def(want).is_empty(), "status %s defined" % want)
	for id in GameCombat.status_ids():
		var def := GameCombat.status_def(id)
		for key in ["name", "tag", "color", "stack", "basis", "default_turns", "default_potency", "text"]:
			ok(def.has(key), "status %s has %s" % [id, key])
	# Class skills: areas marked, everything else single.
	var areas := 0
	for cid in GameData.classes:
		for s in GameData.classes[cid]["skills"]:
			if GameCombat.is_aoe(s):
				areas += 1
				ok(s.has("target") and int(s.get("hits", 1)) == 1, "%s/%s: an area skill strikes each foe once" % [cid, s["id"]])
	ok(areas >= 6, "several class skills are areas (%d)" % areas)
	for c in GameData.creatures:
		ok(str(c.get("row", "front")) in ["front", "back"], "%s row" % c["id"])
		ok(c.get("element", "") == "" or GameData.combat["elements"]["elements"].has(c["element"]), "%s element known" % c["id"])
		for st in c.get("inflicts", []):
			ok(not GameCombat.status_def(str(st["id"])).is_empty(), "%s inflicts a known status" % c["id"])


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
	ok(_fp(cone, o, 1, {0: Vector2(9, 9), 1: Vector2(30, 0)}) == [1], "the aimed foe is always caught, even past the range")
	var line := {"target": {"shape": "line", "width": 3, "length": 18}}
	ok(_fp(line, o, 0, {0: Vector2(9, 0), 1: Vector2(12, 1.49), 2: Vector2(12, 1.51)}) == [0, 1], "line: just inside half the width is hit, just outside is not")
	ok(_fp(line, o, 0, {0: Vector2(9, 0), 1: Vector2(17.99, 0), 2: Vector2(18.01, 0), 3: Vector2(-0.5, 0)}) == [0, 1], "line: out to its length, never behind the caster")
	var diag := _fp(line, o, 0, {0: Vector2(9, 3), 1: Vector2(12, 4), 2: Vector2(12, 0)})
	ok(diag == [0, 1], "line: runs from the caster through the aimed foe (%s)" % str(diag))
	ok(_fp({"target": {"shape": "all"}}, o, 0, {0: Vector2(9, 0), 1: Vector2(40, 30)}) == [0, 1], "all: every foe")
	ok(_fp({}, o, 1, {0: Vector2(9, 0), 1: Vector2(9, 3)}) == [1], "no target block: a single foe")
	# Through a live battle: dead foes are never caught.
	var d := _dyn("mage", 30)
	var b := _battle(d, 5)
	var fb := GameCombat.spell("fireball")
	b.enemies[1]["hp"] = 0
	ok(1 not in b.aoe_targets(fb, -1, 0), "the fallen are not in an area")
	ok(b.aoe_targets(fb, -1, 1) == b.aoe_targets(fb, -1, b.first_target()), "aiming at a fallen foe aims at the first standing one")
	ok(b.aoe_targets(GameCombat.spell("ward"), -1, 0).is_empty(), "a party spell catches no foes")


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
	ok(b2.enemies.all(func(e): return e["row"] == "back"), "creatures that keep back stand in the back row")
	d.battle = null
	var b3 := _battle(d, 4, "harpy")
	ok(b3.enemies.filter(func(e): return e["row"] == "back").size() == 3, "a full back row spills forward")
	d.battle = null
	ok(GameCombat.ally_point(0) != GameCombat.ally_point(1) and GameCombat.ally_point(0).x <= GameCombat.heir_point().x, "companions stand beside and behind the heir")


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
	b._enemy_act(0)
	var dmg: Array = b.events.filter(func(ev): return ev["type"] == "damage" and ev["side"] == "player")
	ok(dmg.size() == 1 and int(dmg[0]["absorbed"]) == cap and d.heir.hp == hp - int(dmg[0]["amount"]), "the shield soaks its fill, the rest gets through")
	ok(not b.has_status("heir", "shield"), "a spent shield is gone")
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
	ok(view.enemy_nodes.size() == 5, "five foes on screen")
	for i in 5:
		var r: Rect2 = view.enemy_nodes[i]["root"].get_global_rect()
		ok(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(r), "foe %d fits on screen (%s)" % [i, str(r)])
		for j in range(i + 1, 5):
			ok(not r.intersects(view.enemy_nodes[j]["root"].get_global_rect()), "foes %d and %d do not overlap" % [i, j])
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
	app.queue_free()
	GameDynasty.save_path = real
	_done()
