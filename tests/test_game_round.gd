## Party command rounds (GameRound): the queue and its legality, back/undo, repeat last, retargeting,
## fallen and held members, flee as a party decision, items reserved when queued and used when played,
## Auto members decided at their own turn, saves (old and new), and that the solo hunt is today's.
## Run: godot --headless --path . -s res://tests/test_game_round.gd
extends SceneTree

const Scen := preload("res://tests/round_scenarios.gd")

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
	test_members_and_order()
	test_menu()
	test_menu_gates()
	test_check_and_queue()
	test_queue_is_pure()
	test_back_and_clear()
	test_resolve_events()
	test_repeat_last()
	test_auto_switch()
	test_auto_decided_at_slot()
	test_all_auto_is_auto_turn()
	test_solo_is_today()
	test_retarget()
	test_fallen_and_held()
	test_flee()
	test_items()
	test_defend()
	test_haste()
	test_hold_flag_always_released()
	test_view_and_chips()
	test_saves()
	test_review_fixes()
	test_old_save_plays()
	ok(ran == 1, "the review-fix tests ran to the end")
	print("round tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- scaffolding

## A dynasty with the companions `ids` (cleric Oriel, warrior Bren, spellblade Tarsk...) at `level`.
func _dynasty(cls: String, ids: Array, level: int = 30, seed_val: int = 77) -> GameDynasty:
	var d := GameDynasty.new_game(seed_val, "Tess", cls, "faetouched", "human")
	d.pending_event = {}
	d.heir.level = level
	d.heir.gold = 5000
	d.heir.potions = 3
	d.heir.learn_spells()
	d.world.visit("kingshold")
	for id in ids:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": level, "gen": 1,
			"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
		d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
			"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	d.party.rest(d)
	d.heir.full_heal()
	return d


## A battle of `n` foes of one kind. Sturdy foes have HP no round can take and a weak bite.
func _battle(d: GameDynasty, n: int = 3, sturdy: bool = true, creature: String = "wolf") -> GameBattle:
	var foes: Array = []
	for i in n:
		foes.append(d._make_enemy(GameCombat.creature_def(creature), 1.0, 1.0, d.heir.level))
	d._begin_battle(foes, "hunt")
	if sturdy:
		for e in d.battle.enemies:
			e["hp"] = 10000000
			e["max_hp"] = 10000000
			e["atk"] = 4.0
	return d.battle


const TRIO := ["sister_oriel", "bren_cask", "tarsk_ember_eye"]


func _party_round(cls: String = "warrior", level: int = 30, foes: int = 3, sturdy: bool = true) -> Array:
	var d := _dynasty(cls, TRIO, level)
	var b := _battle(d, foes, sturdy)
	return [d, b, d.battle_round()]


func _attack(i: int = 0) -> Dictionary:
	return {"act": "attack", "target": "enemy:%d" % i}


func _all_attack(r: GameRound, i: int = 0) -> void:
	for by in r.members():
		r.queue(by, _attack(i))


func _row(r: GameRound, by: int, group: String, label: String) -> Dictionary:
	for row in r.menu(by):
		if row["group"] == group and row["label"] == label:
			return row
	return {}


func _snapshot(b: GameBattle) -> String:
	return JSON.stringify(Scen.state_of(b), "", true) + "|" + str(b.log.size()) + "|" + JSON.stringify(b.events)


func _acts(b: GameBattle) -> Array:
	return b.events.filter(func(e): return e["type"] == "act").map(func(e): return e["by"])


# ---------------------------------------------------------------- data

func test_data() -> void:
	ok(GameRound.validate().is_empty(), "rounds.json is sound: %s" % str(GameRound.validate()))
	ok(not GameData.combat["rounds"]["settings"].has("party_order"), "initiative is fixed in the engine, not a setting")
	ok(GameRound.setting("flee_covers_party") == false, "a failed flee costs the companions nothing by default")
	ok(float(GameRound.setting("defend_mp_pct")) == 0.15, "the companion's Defend returns the heir's 15% MP")
	var s: Dictionary = GameData.combat["rounds"]["settings"]
	var saved: Variant = s["brace_taken"]
	s["brace_taken"] = 1.5
	ok(GameRound.validate().size() == 1 and "brace_taken" in str(GameRound.validate()), "a brace above 1 is reported")
	ok("brace_taken" in str(GameCombat.validate()), "and the combat data checks include it")
	s["brace_taken"] = saved
	saved = s["default_auto"]
	s["default_auto"] = {"heir": 1}
	ok("default_auto" in str(GameRound.validate()), "default_auto needs booleans")
	s["default_auto"] = saved
	var gone: Variant = s["chip_texts"]
	s.erase("chip_texts")
	ok("chip_texts" in str(GameRound.validate()), "a missing key is reported")
	s["chip_texts"] = gone
	ok(GameRound.validate().is_empty(), "the data is whole again")


# ---------------------------------------------------------------- members

func test_members_and_order() -> void:
	var made := _party_round()
	var b: GameBattle = made[1]
	var r: GameRound = made[2]
	ok(r.members() == [-1, 0, 1, 2], "the heir then the companions by party index")
	ok(r.next_unset() == -1 and r.cursor == -1, "the heir is asked first")
	ok(r.manual_count() == 4 and not r.ready(), "four members take input; nothing is queued")
	b.allies[1].hp = 0
	r.begin_round()
	ok(r.members() == [-1, 0, 2], "a fallen companion is not asked")
	ok(r.state_of(1) == "ko" and r.state_of(0) == "ready", "the fallen show as ko")
	var v := r.view()
	ok(v["members"].size() == 4 and v["members"][2]["decision"] == "ko", "view keeps the fallen in index order")
	ok(r.menu(1).is_empty(), "a fallen member has no menu")
	ok(r.queue(1, _attack()) != "", "a fallen member cannot be given a command")
	ok(r.state_of(7) == "ko" and r.state_of(-3) == "ko", "unknown members read as fallen")


# ---------------------------------------------------------------- menus

func test_menu() -> void:
	var d := _dynasty("warrior", TRIO, 30)
	d.heir.inventory.append_array(["nightshade_oil", "plague_vial"])
	for id in GameFeats.ids():
		if GameFeats.requirement_block(d.heir, id) == "" and d.heir.equipped_feats.size() < GameFeats.slots(d.heir):
			d.heir.known_feats.append(id)
			d.heir.equipped_feats.append(id)
	var b := _battle(d)
	var r := d.battle_round()
	var rows := r.menu(-1)
	var groups := {}
	for row in rows:
		groups[row["group"]] = int(groups.get(row["group"], 0)) + 1
		for key in ["cmd", "group", "label", "cost", "enabled", "why", "aim", "ab", "first", "level", "tip"]:
			ok(row.has(key), "a row carries %s" % key)
		ok(row["enabled"] == (row["why"] == ""), "enabled and why agree for %s" % row["label"])
	ok(_row(r, -1, "basic", "Attack")["enabled"] and _row(r, -1, "basic", "Defend")["enabled"], "the heir may attack and defend")
	ok(_row(r, -1, "basic", "Potion")["cost"] == "3 left", "the potion row counts the stock")
	ok(_row(r, -1, "basic", "Flee")["enabled"], "the heir may flee")
	ok(groups["skill"] == GameSkillTree.skills(d.heir).size(), "every class skill is a row")
	ok(groups.get("feat", 0) == d.heir.equipped_feats.size() and groups.get("feat", 0) > 0, "every readied feat is a row")
	ok(groups.get("spell", 0) == d.heir.spells.size(), "every known spell is a row")
	ok(groups.get("item", 0) == 1 and _row(r, -1, "item", "Rat-Plague Vial").get("aim", "") == "area", "the vial is an item row aimed as an area")
	ok(_row(r, -1, "item", "Nightshade Oil").is_empty(), "a toxin is coated, not queued")
	var firsts := 0
	for row in rows:
		if row["group"] == "skill" and row["first"]:
			firsts += 1
	ok(firsts == GameSkills.first_count("warrior"), "the level-1 skills get their own button (%d)" % firsts)
	# A companion's menu comes from its own class.
	var oriel := r.menu(0)
	var heal := {}
	for row in oriel:
		if row["group"] == "skill" and row["ab"].has("pct_max_hp") and not row["ab"].get("party", false):
			heal = row
	ok(not heal.is_empty() and heal["aim"] == "ally", "the cleric ally lists its single heal, aimed at an ally")
	ok(_row(r, -1, "skill", heal.get("label", "?")).is_empty(), "the warrior heir does not")
	ok(r.menu(0).filter(func(x): return x["group"] == "item").is_empty(), "a companion carries no vials")
	var tarsk := r.menu(2)
	ok(tarsk.any(func(x): return x["group"] == "spell"), "the spellblade ally lists spells")
	ok(r.menu(1).filter(func(x): return x["group"] == "spell").size() == b.allies[1].spells.size(), "the warrior ally lists exactly its spells")
	for row in r.menu(0):
		ok(row["cmd"].get("act", "") != "", "a companion row carries a command")
	# Rows queue as listed.
	var fine := 0
	for row in rows:
		if row["enabled"]:
			var cmd: Dictionary = row["cmd"].duplicate()
			if row["aim"] in ["foe", "area"]:
				cmd["target"] = "enemy:0"
			if r.check(-1, cmd) == "":
				fine += 1
	ok(fine > 6, "enabled rows pass check (%d)" % fine)


func test_menu_gates() -> void:
	# Level gates, once-a-battle skills, feat cooldowns, Blood Magic.
	var d := _dynasty("warrior", [], 3)
	_battle(d)
	var r := d.battle_round()
	var swb := _row(r, -1, "skill", "Sweeping Blow")
	ok(not swb.is_empty() and not swb["enabled"] and swb["why"] == "Opens at level 5.", "a skill above the level says when it opens: %s" % swb.get("why", "?"))
	ok(swb["level"] == 5 and not swb["first"], "the opening level is told and it is not a first skill")
	d = _dynasty("mage", [], 30)
	var b := _battle(d)
	r = d.battle_round()
	var focus := _row(r, -1, "skill", "Arcane Focus")
	ok(focus.get("enabled", false), "a once-a-battle skill is open at first")
	b.uses["heir/Arcane Focus"] = 1
	r.begin_round()
	focus = _row(r, -1, "skill", "Arcane Focus")
	ok(not focus["enabled"] and focus["why"] == "Used this battle.", "a once skill is closed after its use")
	d.heir.mp = 1
	var fb := _row(r, -1, "skill", "Firebolt")
	ok(not fb["enabled"] and "MP" in fb["why"], "an unaffordable skill says so: %s" % fb["why"])
	ok(r.queue(-1, fb["cmd"].merged({"target": "enemy:0"})) == fb["why"], "queue gives the same reason")
	# Feats: cooldown reason equals the battle's.
	d = _dynasty("warrior", [], 30)
	for id in GameFeats.ids():
		if GameFeats.requirement_block(d.heir, id) == "" and d.heir.equipped_feats.size() < GameFeats.slots(d.heir):
			d.heir.known_feats.append(id)
			d.heir.equipped_feats.append(id)
	b = _battle(d)
	r = d.battle_round()
	var feat_id: String = d.heir.equipped_feats[0]
	b._spend_feat(-1, feat_id)
	var frow := _row(r, -1, "feat", GameFeats.feat_name(feat_id))
	ok(not frow["enabled"] and frow["why"] == b.feat_block(-1, feat_id) and frow["why"] != "", "a feat on cooldown gives the battle's own reason: %s" % frow["why"])
	# Blood Magic shows HP.
	d = _dynasty("warlock", [], 500)
	d.heir.tree_points = 100
	for id in ["m_focus", "m_searing", "m_lore", "m_mastery", "m_blood_magic"]:
		GameSkillTree.take(d.heir, id)
	b = _battle(d)
	r = d.battle_round()
	if b.pays_in_hp(-1):
		var costs := r.menu(-1).filter(func(x): return x["group"] in ["skill", "spell"] and x["cost"] not in ["", "0 MP"])
		ok(not costs.is_empty() and costs.all(func(x): return str(x["cost"]).ends_with(" HP")), "Blood Magic shows costs in HP")
	else:
		ok(false, "the warlock took Blood Magic")


# ---------------------------------------------------------------- check and queue

func test_check_and_queue() -> void:
	var made := _party_round()
	var d: GameDynasty = made[0]
	var b: GameBattle = made[1]
	var r: GameRound = made[2]
	ok(r.queue(-1, _attack(0)) == "", "a plain attack queues")
	ok(r.entries[-1]["src"] == "manual" and r.cursor == 0, "the cursor moves to the next member")
	ok(r.queue(-1, _attack(1)) == "" and r.entries[-1]["cmd"]["target"] == "enemy:1", "a later choice replaces the earlier one")
	ok(r.queue(-1, {"act": "attack", "target": "enemy:9"}) != "", "a foe that is not there is refused")
	ok(r.entries[-1]["cmd"]["target"] == "enemy:1", "a refused command changes nothing")
	ok(r.queue(0, {"act": "dance"}) != "", "an unknown command is refused")
	ok(r.queue(0, {"act": "pass"}) != "" and not r.entries.has(0), "a pass is not a choice")
	# Unaffordable.
	d.heir.mp = 0
	var power := {"act": "ability", "kind": "skill", "id": "power_strike", "target": "enemy:0"}
	ok(r.queue(-1, power) != "" and r.entries[-1]["cmd"]["act"] == "attack", "an unaffordable skill is refused and the old choice stays")
	ok(r.check(-1, {"act": "ability", "kind": "skill", "id": "nonesuch", "target": ""}) == "No such skill.", "an unknown skill id is refused")
	ok(r.check(-1, {"act": "ability", "kind": "spell", "id": "nonesuch", "target": ""}) == "Not known.", "an unknown spell is refused")
	d.heir.mp = d.heir.max_mp()
	# An area that reaches no one.
	var cone := {"act": "ability", "kind": "skill", "id": "sweeping_blow", "target": "enemy:0"}
	ok(r.check(-1, cone) == "", "a cone at a foe in reach is fine")
	for e in b.enemies:
		e["x"] = 400.0
		e["y"] = 400.0
	ok(r.check(-1, cone) == "Out of reach.", "an area that reaches no one is refused")
	# Potions beyond the stock.
	d.heir.potions = 1
	ok(r.queue(0, {"act": "potion"}) == "" and r.queue(1, {"act": "potion"}) != "", "the second potion is refused when one is left")
	ok(r.check(1, {"act": "potion"}) == "No potions left.", "and says why")
	r.unqueue(0)
	ok(r.check(1, {"act": "potion"}) == "", "a potion given back can be promised again")
	# Flee while held.
	b.heir_skip = true
	r.begin_round()
	ok(r.state_of(-1) == "held" and r.entries[-1]["src"] == "held", "a held heir is filled in, not asked")
	ok(r.check(1, {"act": "flee"}) == "Held fast.", "no fleeing while the heir is held fast")
	ok(r.check(-1, _attack()) == "Held fast.", "a held member takes no command")
	# A fallen ally target for a heal.
	b.heir_skip = false
	r.begin_round()
	var heal := {"act": "ability", "kind": "skill", "id": "heal", "target": "ally:2"}
	var heal_id := ""
	for row in r.menu(0):
		if row["group"] == "skill" and row["aim"] == "ally":
			heal_id = row["cmd"]["id"]
	heal = {"act": "ability", "kind": "skill", "id": heal_id, "target": "ally:2"}
	ok(r.check(0, heal) == "", "a heal at a standing companion is fine")
	b.allies[2].hp = 0
	ok(r.check(0, heal) == "Out of the fight.", "a heal at a fallen companion is refused")
	ok(r.check(0, {"act": "defend"}) == "", "Defend is open to companions")
	var s: Dictionary = GameData.combat["rounds"]["settings"]
	s["ally_defend"] = false
	ok(r.check(0, {"act": "defend"}) != "" and r.check(-1, {"act": "defend"}) == "", "the data can close Defend to companions, never to the heir")
	s["ally_defend"] = true
	ok(r.aim_of(_attack(), -1) == "foe" and r.aim_of({"act": "defend"}) == "none", "aim_of for the basics")
	ok(r.aim_of(cone, -1) == "area" and r.aim_of({"act": "ability", "kind": "skill", "id": heal_id}, 0) == "ally", "aim_of for a cone and a heal")


func test_queue_is_pure() -> void:
	var made := _party_round()
	var b: GameBattle = made[1]
	var r: GameRound = made[2]
	var before := _snapshot(b)
	var rng_before := b.rng.state
	r.queue(-1, _attack(1))
	r.queue(0, {"act": "defend"})
	r.queue(1, {"act": "potion"})
	r.queue(2, {"act": "flee"})
	r.back()
	r.set_auto(1, true)
	r.clear()
	r.repeat_last()
	ok(b.rng.state == rng_before, "choosing throws no dice")
	ok(_snapshot(b) == before, "choosing changes nothing in the battle")
	ok(not b.round_on and b.events.is_empty(), "the hold flag is off while choosing")


func test_back_and_clear() -> void:
	var made := _party_round()
	var r: GameRound = made[2]
	r.queue(-1, _attack())
	r.queue(0, {"act": "defend"})
	r.queue(1, _attack(1))
	ok(r.view()["can_back"] and r.cursor == 2, "three queued, the fourth is asked")
	ok(r.back() == 1 and not r.entries.has(1) and r.cursor == 1, "back takes the last one back and asks them again")
	ok(r.back() == 0 and r.back() == -1, "back pops in reverse order")
	ok(not r.view()["can_back"] and r.back() == r.cursor, "with nothing queued back asks the same member")
	r.queue(2, _attack())
	r.queue(-1, _attack())
	r.unqueue(2)
	ok(not r.entries.has(2) and r.cursor == 2 and r.entries.has(-1), "unqueue drops one member")
	r.clear()
	ok(r.entries.is_empty() and r.cursor == -1, "clear drops every choice")
	# Held members stay through clear.
	var b: GameBattle = made[1]
	b.heir_skip = true
	r.begin_round()
	r.queue(0, _attack())
	r.clear()
	ok(r.entries.has(-1) and r.entries[-1]["src"] == "held" and not r.entries.has(0), "a held member stays through clear")
	ok(r.next_unset() == 0, "the others are asked again")
	# Back restores what a Flee covered.
	_covers(true)
	b.heir_skip = false
	r.begin_round()
	r.queue(-1, _attack())
	r.queue(0, {"act": "defend"})
	ok(r.queue(1, {"act": "flee"}) == "", "a companion may call the flee")
	ok(r.flee_by == 1 and r.entries[2]["src"] == "cover" and r.entries[0]["src"] == "cover" and r.entries[-1]["src"] == "cover", "everyone else is covered")
	ok(r.ready() and r.view()["flee"], "a flee is a complete round")
	ok(r.back() == 1 and r.flee_by == -2, "back takes the flee back")
	ok(r.entries[-1]["cmd"]["act"] == "attack" and r.entries[0]["cmd"]["act"] == "defend" and not r.entries.has(2), "and the covered get their own choices back")
	r.queue(1, {"act": "flee"})
	ok(r.queue(2, _attack()) == "" and r.flee_by == -2, "any other choice takes a queued flee back")
	ok(not r.entries.has(1), "the one who called it is asked again")
	r.queue(1, {"act": "flee"})
	r.set_auto(1, true)
	ok(r.flee_by == -2, "switching the caller to Auto takes the flee back")
	r.set_auto(1, false)
	_covers(false)


# ---------------------------------------------------------------- playing a round

func test_resolve_events() -> void:
	var made := _party_round()
	var b: GameBattle = made[1]
	var r: GameRound = made[2]
	var res := r.resolve()
	ok(not res["played"] and b.turn == 0, "an unready round does not play")
	# Queue in reverse: initiative does not follow the order of choosing.
	for by in [2, 1, 0, -1]:
		r.queue(by, _attack(mini(by + 1, 2)))
	ok(r.ready() and r.next_unset() == -2, "all four decided")
	var log_before := b.log.size()
	res = r.resolve()
	ok(res["played"] and res["log_from"] == log_before and not res["over"] and res["result"] == "", "resolve reports where its log starts")
	ok(b.turn == 1, "exactly one round passed")
	ok(_acts(b) == [-1, 0, 1, 2], "initiative is the heir, then the companions by index")
	var types: Array = b.events.map(func(e): return e["type"])
	ok(types[0] == "round" and b.events[0]["n"] == 0, "the round opens with a round marker")
	ok(types.find("foes") > types.rfind("act"), "foes act after every member")
	ok(types.count("foes") == 1, "one foes marker")
	var heir_dmg := b.events.filter(func(e): return e["type"] == "damage" and e.get("side", "") == "enemy" and e.get("by", -9) == -1)
	var ally_dmg := b.events.filter(func(e): return e["type"] == "damage" and e.get("side", "") == "enemy" and e.get("by", -9) == 1)
	ok(heir_dmg.size() == 1 and heir_dmg[0]["index"] == 0, "the heir struck the foe chosen for the heir")
	ok(ally_dmg.size() >= 1 and ally_dmg[0]["index"] == 2, "the companion struck the foe chosen for it")
	ok(b.log.size() > log_before, "the log grew")
	ok(r.number == 1 and r.entries.is_empty() and r.cursor == -1, "the next round opens clean")
	ok(r.last.size() == 4 and r.last[0]["act"] == "attack", "the choices are kept for Repeat")
	ok(not b.round_on and not b.round_marks and b.round_cmds.is_empty(), "the hold is released")
	for e in b.events:
		if e["type"] == "act":
			ok(e.has("manual") and e["manual"] == true, "every act was by hand")


func test_repeat_last() -> void:
	var made := _party_round()
	var d: GameDynasty = made[0]
	var b: GameBattle = made[1]
	var r: GameRound = made[2]
	ok(not r.can_repeat() and r.repeat_last() == {"repeated": [], "fallback": []}, "nothing to repeat in the first round")
	r.queue(-1, _attack(1))
	r.queue(0, {"act": "defend"})
	r.queue(1, _attack(2))
	r.queue(2, {"act": "ability", "kind": "skill", "id": "arcane_edge", "target": "enemy:0"})
	r.resolve()
	ok(r.can_repeat() and r.view()["can_repeat"], "after a round Repeat is offered")
	var got := r.repeat_last()
	ok(got["repeated"] == [-1, 0, 1, 2] and got["fallback"].is_empty(), "every choice is queued again: %s" % str(got))
	ok(r.ready() and r.entries[-1]["src"] == "repeat" and r.entries[1]["cmd"]["target"] == "enemy:2", "as the same commands")
	ok(not r.can_repeat(), "Repeat is gone once something is queued")
	ok(r.back() == 2 and r.back() == 1, "back undoes a repeated member at a time")
	r.clear()
	# A fallen foe is replaced by the nearest living one.
	b.enemies[2]["hp"] = 0
	b.enemies[2]["x"] = b.enemy_point(1).x + 1.0
	b.enemies[2]["y"] = b.enemy_point(1).y
	got = r.repeat_last()
	ok(not r.entries.is_empty() and r.entries[1]["cmd"]["target"] != "enemy:2" and r.entries[1]["cmd"]["target"] in ["enemy:0", "enemy:1"], "a fallen target is moved to a living foe (%s)" % str(r.entries[1]["cmd"]["target"]))
	r.clear()
	# What cannot be done again becomes Auto for this round only.
	d.heir.mp = 0
	b.heir.potions = 0
	r.last[-1] = {"act": "ability", "kind": "skill", "id": "power_strike", "target": "enemy:0"}
	r.last[0] = {"act": "potion"}
	r.last[1] = _attack(0)
	got = r.repeat_last()
	ok(-1 in got["fallback"] and 0 in got["fallback"], "no MP and no potion: those two fall back (%s)" % str(got))
	ok(1 in got["repeated"], "the attack still repeats")
	ok(r.entries[-1]["src"] == "auto_once" and not r.auto[-1], "a fallback is for this round only; the Auto switch is untouched")
	ok(r.view()["members"][0]["decision"] == "fallback" and r.view()["members"][0]["kind"] == "auto", "and shows as Auto")
	var res := r.resolve()
	ok(res["played"], "a round with fallbacks plays")
	# A feat cooling down, a once skill used, a heal for a fallen friend.
	var d2 := _dynasty("mage", ["sister_oriel"], 30)
	var b2 := _battle(d2)
	var r2 := d2.battle_round()
	r2.queue(-1, {"act": "ability", "kind": "skill", "id": "arcane_focus", "target": ""})
	r2.queue(0, _attack())
	r2.resolve()
	got = r2.repeat_last()
	ok(-1 in got["fallback"], "a once-a-battle skill falls back the second time")
	var heal_id := ""
	for row in r2.menu(0):
		if row["group"] == "skill" and row["aim"] == "ally":
			heal_id = row["cmd"]["id"]
	r2.clear()
	r2.last = {0: {"act": "ability", "kind": "skill", "id": heal_id, "target": "heir"}}
	d2.heir.hp = 5
	got = r2.repeat_last()
	ok(0 in got["repeated"], "a heal for the heir repeats")


# ---------------------------------------------------------------- Auto

func test_auto_switch() -> void:
	var made := _party_round()
	var d: GameDynasty = made[0]
	var r: GameRound = made[2]
	ok(not r.auto[-1] and not r.auto[0], "by default every member takes orders")
	r.queue(0, _attack())
	r.set_auto(0, true)
	ok(r.auto[0] and not r.entries.has(0), "Auto drops the member's choice")
	ok(r.needs_input(0) == false and r.manual_count() == 3, "an Auto member is not asked")
	ok(r.view()["members"][1]["decision"] == "auto" and r.view()["members"][1]["chip"]["short"] == "Auto", "its chip says Auto")
	r.queue(-1, _attack())
	r.queue(1, _attack())
	r.queue(2, _attack())
	ok(r.ready(), "Auto members count as decided")
	r.set_auto(0, false)
	ok(not r.ready() and r.cursor == 0, "turning Auto off asks the member")
	r.set_auto(0, true)
	r.set_auto(-1, true)
	ok(d.auto_party.get("heir", false) == true, "the heir's switch is kept in the dynasty")
	ok(d.party.members[0].get("auto", false) == true and not d.party.members[1].has("auto"), "a companion's is kept in its record")
	# Remembered by the next battle.
	d.battle = null
	d.command_round = null
	var b2 := _battle(d)
	var r2 := d.battle_round()
	ok(r2.auto[-1] and r2.auto[0] and not r2.auto[1] and not r2.auto[2], "the next battle restores the switches")
	ok(r2.view()["members"][0]["auto"], "and the view shows them")
	# The global preference and the data default.
	d.auto_party = {"companion_default": true}
	d.party.members[0].erase("auto")
	d.battle = null
	d.command_round = null
	_battle(d)
	r2 = d.battle_round()
	ok(not r2.auto[-1] and r2.auto[0] and r2.auto[1] and r2.auto[2], "a companion default covers companions who were never set")
	d.party.members[1]["auto"] = false
	d.battle = null
	d.command_round = null
	_battle(d)
	r2 = d.battle_round()
	ok(not r2.auto[1] and r2.auto[0], "a companion's own switch beats the default")
	# The round object lives with the battle.
	ok(d.battle_round() == d.battle_round(), "one round per battle")
	var first := d.battle_round()
	d.finish_battle()
	ok(d.command_round == null and d.battle_round() == null, "finishing the battle drops the round")
	ok(first != null, "(the old round object is just unreferenced)")
	# The autopilot never makes one.
	var d3 := _dynasty("warrior", TRIO, 30)
	_battle(d3, 2, false)
	GameBot.fight(d3)
	ok(d3.command_round == null, "the autopilot never opens a command round")
	var d4 := _dynasty("warrior", TRIO, 30)
	var b4 := _battle(d4, 2, false)
	GameTactics.auto_turn(b4)
	ok(d4.command_round == null, "auto-battle never opens a command round")


func test_auto_decided_at_slot() -> void:
	# An Auto companion presses the heir's focus, which is only set when the heir strikes: so it
	# was chosen at its own turn, not at queue time.
	var d := _dynasty("warrior", ["bren_cask"], 30)
	var b := _battle(d, 3)
	var r := d.battle_round()
	r.set_auto(0, true)
	r.queue(-1, _attack(2))
	ok(b.focus == -1, "(no focus yet)")
	r.resolve()
	var ally_hits := b.events.filter(func(e): return e["type"] == "damage" and e.get("side", "") == "enemy" and e.get("by", -9) == 0)
	ok(ally_hits.size() >= 1 and ally_hits[0]["index"] == 2, "the Auto companion struck the foe the heir had just struck")
	ok(b.events.any(func(e): return e["type"] == "act" and e["by"] == 0 and e["manual"] == false), "its act marker says it chose for itself")
	ok(b.events.any(func(e): return e["type"] == "act" and e["by"] == -1 and e["manual"] == true), "the heir's says by hand")


func _covers(on: bool) -> void:
	GameData.combat["rounds"]["settings"]["flee_covers_party"] = on


func _same_start(seed_val: int, cls: String, n: int) -> Array:
	var out: Array = []
	for k in 2:
		var d := Scen.make(seed_val, cls, n, "hunt")
		out.append(d)
	return out


func test_all_auto_is_auto_turn() -> void:
	for spec in [[3, "warrior", 3], [5, "cleric", 1], [8, "mage", 3], [11, "rogue", 0], [14, "spellblade", 3]]:
		var pair := _same_start(spec[0], spec[1], spec[2])
		var da: GameDynasty = pair[0]
		var db: GameDynasty = pair[1]
		db.auto_party = {"heir": true, "companion_default": true}
		var ba := da.battle
		var bb := db.battle
		var r := db.battle_round()
		var same := true
		var rounds := 0
		while not ba.is_over() and rounds < 120:
			rounds += 1
			GameTactics.auto_turn(ba)
			var res := r.resolve()
			same = same and res["played"] and ba.log == bb.log and ba.rng.state == bb.rng.state and ba.turn == bb.turn
			if not same:
				break
		ok(same and ba.result == bb.result, "an all-Auto round is auto_turn, round for round (%s, %d rounds)" % [spec, rounds])
		ok(not bb.round_on, "the hold is off afterwards")


func test_solo_is_today() -> void:
	for seed_val in [2, 3, 6]:
		var da := Scen.make(seed_val, "warrior", 0, "hunt")
		var db := Scen.make(seed_val, "warrior", 0, "hunt")
		var ba := da.battle
		var bb := db.battle
		var r := db.battle_round()
		ok(r.members() == [-1] and r.manual_count() == 1 and r.auto_commits(), "a solo heir: one member, the pick commits")
		var turns := 0
		var same := true
		while not ba.is_over() and turns < 60:
			turns += 1
			var cmd := Scen.script_cmd(ba, seed_val)
			Scen.direct(ba, cmd)
			if r.state_of(-1) == "ready":
				same = same and r.queue(-1, cmd) == "" and r.ready()
			same = same and r.resolve()["played"]
			same = same and ba.log == bb.log and ba.rng.state == bb.rng.state
			if not same:
				break
		ok(same and ba.result == bb.result and ba.result != "", "a solo fight through GameRound is the old fight (seed %d, %d rounds)" % [seed_val, turns])


# ---------------------------------------------------------------- retargeting

func test_retarget() -> void:
	var made := _party_round()
	var b: GameBattle = made[1]
	var r: GameRound = made[2]
	# Geometry first: ties go to the lowest index.
	b.enemies[0]["hp"] = 0
	b.enemies[0]["x"] = 0.0
	b.enemies[0]["y"] = 0.0
	b.enemies[1]["x"] = 3.0
	b.enemies[1]["y"] = 0.0
	b.enemies[2]["x"] = -3.0
	b.enemies[2]["y"] = 0.0
	ok(GameRound.retarget_foe(b, "enemy:0") == 1, "the nearest living foe, lowest index on ties")
	b.enemies[2]["x"] = -2.0
	ok(GameRound.retarget_foe(b, "enemy:0") == 2, "the nearer of two")
	ok(GameRound.retarget_foe(b, "enemy:1") == 1, "a living foe stays")
	b.enemies[1]["hp"] = 0
	b.enemies[2]["hp"] = 0
	ok(GameRound.retarget_foe(b, "enemy:0") == -1, "no living foe: -1")
	# Heal target: the most hurt, the heir wins ties.
	var made2 := _party_round()
	var b2: GameBattle = made2[1]
	ok(GameRound.retarget_ally(b2) == -1, "everyone hale: the heir")
	b2.allies[1].hp = b2.allies[1].max_hp() / 2
	ok(GameRound.retarget_ally(b2) == 1, "the most hurt member")
	b2.allies[1].hp = 0
	b2.allies[2].hp = b2.allies[2].max_hp() / 3
	ok(GameRound.retarget_ally(b2) == 2, "a fallen one is not a target")
	# The heir fells foe 0; the companion's blow moves on.
	var made3 := _party_round()
	var b3: GameBattle = made3[1]
	var r3: GameRound = made3[2]
	b3.enemies[0]["hp"] = 1
	b3.enemies[1]["x"] = b3.enemy_point(0).x + 1.0
	b3.enemies[1]["y"] = b3.enemy_point(0).y
	b3.enemies[2]["x"] = b3.enemy_point(0).x + 9.0
	b3.enemies[2]["y"] = b3.enemy_point(0).y
	for by in r3.members():
		r3.queue(by, _attack(0))
	r3.resolve()
	var late := b3.events.filter(func(e): return e["type"] == "damage" and e.get("side", "") == "enemy" and e.get("by", -9) >= 0)
	ok(b3.enemies[0]["hp"] == 0 and late.size() >= 2 and late.all(func(e): return e["index"] == 1), "the companions' queued blows moved to the nearest living foe")
	# An area follows too, and one that reaches no one lets the member improvise.
	var d4 := _dynasty("warrior", ["bren_cask"], 30)
	var b4 := _battle(d4, 3)
	var r4 := d4.battle_round()
	b4.enemies[0]["hp"] = 1
	r4.queue(-1, _attack(0))
	r4.queue(0, {"act": "ability", "kind": "skill", "id": "sweeping_blow", "target": "enemy:0"})
	ok(r4.ready(), "the cone is queued while its target stands")
	b4.enemies[1]["x"] = 300.0
	b4.enemies[1]["y"] = 300.0
	b4.enemies[2]["x"] = -300.0
	b4.enemies[2]["y"] = 300.0
	var mp: int = d4.battle.allies[0].mp
	r4.resolve()
	ok("Bren Cask improvises." in b4.log, "an area that reaches no one any more: the member improvises (%s)" % str(b4.log.slice(-3)))
	ok(b4.events.any(func(e): return e["type"] == "act" and e["by"] == 0 and e.get("fallback", false)), "and the act marker says so")
	ok(not b4.events.any(func(e): return e["type"] == "cast" and e["name"] == "Sweeping Blow"), "the dropped command was not played (%d MP before)" % mp)
	# The last foe falls: later commands never run and spend nothing.
	var d5 := _dynasty("warrior", TRIO, 30)
	var b5 := _battle(d5, 1)
	b5.enemies[0]["hp"] = 1
	var r5 := d5.battle_round()
	r5.queue(-1, _attack(0))
	r5.queue(0, {"act": "ability", "kind": "skill", "id": "smite", "target": "enemy:0"})
	r5.queue(1, {"act": "ability", "kind": "skill", "id": "power_strike", "target": "enemy:0"})
	r5.queue(2, {"act": "defend"})
	var mps: Array = b5.allies.map(func(a): return a.mp)
	var res := r5.resolve()
	ok(res["over"] and res["result"] == "victory", "the last foe fell")
	ok(_acts(b5) == [-1], "no companion acted after it")
	ok(b5.allies.map(func(a): return a.mp) == mps, "and none spent anything")
	ok(not b5.round_on, "the hold is released on victory")
	# A heal aimed at a companion who fell goes to the most hurt member.
	var d6 := _dynasty("warrior", TRIO, 30)
	var b6 := _battle(d6, 2)
	var r6 := d6.battle_round()
	var heal_id := ""
	for row in r6.menu(0):
		if row["group"] == "skill" and row["aim"] == "ally":
			heal_id = row["cmd"]["id"]
	r6.queue(-1, _attack(0))
	r6.queue(0, {"act": "ability", "kind": "skill", "id": heal_id, "target": "ally:1"})
	r6.queue(1, {"act": "defend"})
	r6.queue(2, {"act": "defend"})
	b6.allies[1].hp = 0
	b6.allies[2].hp = b6.allies[2].max_hp() / 4
	var hp2: int = b6.allies[2].hp
	r6.resolve()
	ok(b6.allies[2].hp > hp2, "the heal for a fallen companion mended the most hurt member instead")


# ---------------------------------------------------------------- fallen and held

func test_fallen_and_held() -> void:
	# A companion who falls after choosing is dropped, nothing spent.
	var made := _party_round()
	var b: GameBattle = made[1]
	var r: GameRound = made[2]
	_all_attack(r)
	var mp1: int = b.allies[1].mp
	b.allies[1].hp = 0
	r.resolve()
	ok(not _acts(b).has(1) and not b.log.any(func(l): return l.begins_with("Bren Cask hits")), "a fallen companion does not act (%d MP)" % mp1)
	# An ally who dies at its own turn to a poison: command dropped.
	var made2 := _party_round()
	var b2: GameBattle = made2[1]
	var r2: GameRound = made2[2]
	for by in r2.members():
		r2.queue(by, {"act": "ability", "kind": "skill", "id": "power_strike", "target": "enemy:0"} if by == 1 else _attack())
	b2.apply_status("ally:1", "poison", 50.0, 3)
	var mp: int = b2.allies[1].mp
	r2.resolve()
	ok(b2.allies[1].hp == 0 and b2.allies[1].mp == mp, "dead at its own turn: no cost")
	ok(not _acts(b2).has(1), "and no act")
	# Stunned companion: Held, not asked, and the round plays.
	var made3 := _party_round()
	var b3: GameBattle = made3[1]
	var r3: GameRound = made3[2]
	b3.apply_status("ally:1", "stun", 1.0, 2)
	r3.begin_round()
	ok(r3.state_of(1) == "held" and r3.entries[1]["src"] == "held", "a stunned companion is held")
	ok(r3.view()["members"][2]["decision"] == "held" and r3.view()["members"][2]["chip"]["short"] == "Held", "and shows Held")
	r3.queue(-1, _attack())
	ok(r3.cursor == 0, "the held one is skipped when asking")
	r3.queue(0, _attack())
	r3.queue(2, _attack())
	ok(r3.ready(), "a round with a held member is complete")
	ok(r3.queue(1, _attack()) == "Held fast.", "a held member takes no command")
	r3.resolve()
	ok(_acts(b3) == [-1, 0, 2], "the held companion did not act")
	# A held member freed before its turn acts as Auto.
	var made4 := _party_round()
	var b4: GameBattle = made4[1]
	var r4: GameRound = made4[2]
	b4.apply_status("ally:1", "stun", 1.0, 2)
	r4.begin_round()
	_all_attack(r4)
	b4.remove_status("ally:1", "stun")
	r4.resolve()
	ok(_acts(b4) == [-1, 0, 1, 2], "a member freed before its turn acts")
	ok(b4.events.any(func(e): return e["type"] == "act" and e["by"] == 1 and e["manual"] == false), "as Auto")
	# A chance-to-skip status that rolls a skip drops the command.
	var made5 := _party_round()
	var b5: GameBattle = made5[1]
	var r5: GameRound = made5[2]
	b5.apply_status("ally:2", "fear", 5.0, 2)
	r5.begin_round()
	ok(r5.state_of(2) == "ready", "a chance to skip is not certain: the member is still asked")
	_all_attack(r5)
	var mp2: int = b5.allies[2].mp
	r5.resolve()
	ok(not _acts(b5).has(2) and b5.allies[2].mp == mp2, "when the skip rolls, the command is dropped at no cost")
	# A stunned heir: the heir's slot is a pass, the others still act.
	var made6 := _party_round()
	var b6: GameBattle = made6[1]
	var r6: GameRound = made6[2]
	b6.heir_skip = true
	r6.begin_round()
	ok(r6.state_of(-1) == "held" and r6.next_unset() == 0, "a held heir is not asked; the party is")
	r6.queue(0, _attack())
	r6.queue(1, _attack())
	r6.queue(2, _attack())
	ok(r6.ready(), "complete")
	r6.resolve()
	ok(not b6.heir_skip, "the heir's lost turn is spent")
	ok(b6.events.any(func(e): return e["type"] == "act" and e["by"] == -1 and e.get("held", false)), "marked as held")
	ok(_acts(b6).count(0) >= 1 and b6.turn == 1, "the companions acted and the round passed")
	ok(not b6.events.any(func(e): return e["type"] == "damage" and e.get("by", -9) == -1 and e.get("side", "") == "enemy"), "the heir struck nothing")
	# Solo and held: complete at once.
	var d7 := _dynasty("warrior", [], 30)
	var b7 := _battle(d7, 2)
	b7.heir_skip = true
	var r7 := d7.battle_round()
	r7.begin_round()
	ok(r7.ready() and r7.manual_count() == 0, "a held solo heir needs no command")
	ok(r7.resolve()["played"] and b7.turn == 1, "the round passes")
	# Everyone held.
	var d8 := _dynasty("warrior", ["bren_cask"], 30)
	var b8 := _battle(d8, 2)
	b8.heir_skip = true
	b8.apply_status("ally:0", "sleep", 1.0, 2)
	var r8 := d8.battle_round()
	r8.begin_round()
	ok(r8.ready() and r8.resolve()["played"], "a fully held party passes the round")


# ---------------------------------------------------------------- flee

func _flee_seed(b: GameBattle, succeed: bool) -> void:
	b.weather["flee"] = 10.0 if succeed else -10.0
	for s in range(1, 400):
		var p := RandomNumberGenerator.new()
		p.seed = s
		var roll := p.randf()
		if (succeed and roll < 0.9) or (not succeed and roll >= 0.1):
			b.rng.seed = s
			return


func test_flee() -> void:
	# Success: one roll, everyone gone, nothing else spent.
	var made := _party_round()
	var b: GameBattle = made[1]
	var r: GameRound = made[2]
	_flee_seed(b, true)
	var probe := RandomNumberGenerator.new()
	probe.seed = b.rng.seed
	probe.state = b.rng.state
	probe.randf()
	var mps: Array = b.allies.map(func(a): return a.mp)
	var foes: Array = b.enemies.map(func(e): return e["hp"])
	r.queue(0, {"act": "flee"})
	ok(r.view()["flee"] and r.ready(), "one companion's flee is the whole party's decision")
	ok(r.describe(0, {"act": "flee"})["full"] == "Flee", "its chip reads Flee")
	var res := r.resolve()
	ok(res["over"] and res["result"] == "fled" and b.result == "fled", "the party escapes")
	ok(b.rng.state == probe.state, "the flee roll was consumed exactly once")
	ok(b.allies.map(func(a): return a.mp) == mps and b.enemies.map(func(e): return e["hp"]) == foes, "nothing else was spent or struck")
	ok(_acts(b) == [-1] and b.events.any(func(e): return e["type"] == "flee"), "only the flee was played")
	ok(not b.round_on, "the hold is released after a flee")
	# Failure: the heir and the covered lose the turn, the foes act.
	_covers(true)
	var made2 := _party_round()
	var b2: GameBattle = made2[1]
	var r2: GameRound = made2[2]
	b2.enemies[0]["atk"] = 40.0
	_flee_seed(b2, false)
	r2.queue(-1, {"act": "flee"})
	res = r2.resolve()
	ok(not res["over"] and b2.turn == 1, "a failed flee passes the round")
	ok("Tess fails to escape!" in b2.log, "told")
	ok(b2.log.any(func(l): return " covers the retreat." in l), "the companions cover the retreat")
	ok(not b2.events.any(func(e): return e["type"] == "damage" and e.get("side", "") == "enemy"), "no blow of the party landed")
	ok(b2.events.any(func(e): return e["type"] == "damage" and e.get("side", "") in ["player", "ally"]), "the foes struck")
	ok(b2.events.filter(func(e): return e["type"] == "foes").size() == 1, "the foes had their turn")
	# By default (and in the data) the companions act on their own instead.
	_covers(false)
	var made3 := _party_round()
	var b3: GameBattle = made3[1]
	var r3: GameRound = made3[2]
	_flee_seed(b3, false)
	r3.queue(-1, {"act": "flee"})
	r3.resolve()
	ok(not b3.log.any(func(l): return " covers the retreat." in l), "no one covers when the data says so")
	ok(b3.events.any(func(e): return e["type"] == "damage" and e.get("side", "") == "enemy"), "the companions struck on their own")
	# Not while the heir is held.
	var made4 := _party_round()
	var b4: GameBattle = made4[1]
	var r4: GameRound = made4[2]
	b4.heir_skip = true
	r4.begin_round()
	ok(r4.queue(1, {"act": "flee"}) == "Held fast.", "no flee while the heir is held")
	ok(not _row(r4, 1, "basic", "Flee")["enabled"], "the Flee row is closed too")


# ---------------------------------------------------------------- items

func test_items() -> void:
	var d := _dynasty("warrior", TRIO, 30)
	d.heir.inventory.append_array(["nightshade_oil", "plague_vial", "plague_vial"])
	var b := _battle(d)
	var r := d.battle_round()
	d.heir.potions = 2
	ok(r.queue(-1, {"act": "potion"}) == "" and r.queue(0, {"act": "potion"}) == "", "two members may promise the two potions")
	ok(r.queue(1, {"act": "potion"}) != "" and not r.entries.has(1), "the third is refused")
	ok(_row(r, 2, "basic", "Potion")["cost"] == "0 left" and not _row(r, 2, "basic", "Potion")["enabled"], "the row counts what is promised")
	ok(d.heir.potions == 2, "queuing used nothing")
	# Consumed at resolve; a companion's potion heals the companion.
	d.heir.hp = d.heir.max_hp() / 2
	b.allies[0].hp = b.allies[0].max_hp() / 2
	var hh: int = d.heir.hp
	var ah: int = b.allies[0].hp
	r.queue(1, _attack())
	r.queue(2, _attack())
	r.resolve()
	ok(d.heir.potions == 0, "both potions were used when the round played")
	ok(d.heir.hp > hh and b.allies[0].hp > ah, "the heir and the companion were each healed")
	ok(b.log.any(func(l): return "Sister Oriel restores" in l and "(Potion)" in l), "the companion's potion is told")
	# The stock can run out before a member's turn: the member improvises.
	var made := _party_round()
	var d2: GameDynasty = made[0]
	var b2: GameBattle = made[1]
	var r2: GameRound = made[2]
	d2.heir.potions = 1
	r2.queue(0, {"act": "potion"})
	r2.queue(-1, _attack())
	r2.queue(1, _attack())
	r2.queue(2, _attack())
	d2.heir.potions = 0
	r2.resolve()
	ok("Sister Oriel improvises." in b2.log, "no potion left at its turn: the member improvises")
	# Vials: queued by the heir, thrown when the round plays; the coat is immediate.
	var d3 := _dynasty("warrior", ["bren_cask"], 30)
	d3.heir.inventory.append_array(["nightshade_oil", "plague_vial"])
	var b3 := _battle(d3)
	var r3 := d3.battle_round()
	r3.coat("nightshade_oil")
	ok(not b3.coating.is_empty() and not d3.heir.inventory.has("nightshade_oil"), "the coat goes on at once")
	ok(b3.events.any(func(e): return e["type"] == "coat"), "and its events are in the battle for the UI to play")
	r3.queue(-1, {"act": "ability", "kind": "vial", "id": "plague_vial", "target": "enemy:0"})
	r3.queue(0, _attack())
	r3.clear()
	ok(not b3.coating.is_empty(), "clear does not take the coat off")
	ok(d3.heir.inventory.has("plague_vial"), "a queued vial is still in the pack")
	r3.queue(-1, {"act": "ability", "kind": "vial", "id": "plague_vial", "target": "enemy:0"})
	ok(r3.queue(0, {"act": "ability", "kind": "vial", "id": "plague_vial", "target": "enemy:0"}) != "", "a companion throws no vials")
	r3.queue(0, _attack())
	r3.resolve()
	ok(not d3.heir.inventory.has("plague_vial"), "the vial was thrown when the round played")
	ok(b3.events.any(func(e): return e["type"] == "cast" and e["by"] == -1 and e["aoe"] == true), "as an area")
	# Two vials of one kind are promised once each.
	var d4 := _dynasty("warrior", [], 30)
	d4.heir.inventory.append_array(["plague_vial"])
	_battle(d4)
	var r4 := d4.battle_round()
	ok(r4.check(-1, {"act": "ability", "kind": "vial", "id": "plague_vial", "target": "enemy:0"}) == "", "a vial in the pack may be queued")
	ok(r4.check(-1, {"act": "ability", "kind": "vial", "id": "ghost_vial", "target": "enemy:0"}) != "", "one not in the pack may not")


# ---------------------------------------------------------------- defend and haste

func test_defend() -> void:
	var made := _party_round()
	var b: GameBattle = made[1]
	var r: GameRound = made[2]
	b.allies[0].mp = 0
	r.queue(-1, _attack())
	r.queue(0, {"act": "defend"})
	r.queue(1, _attack())
	r.queue(2, _attack())
	r.resolve()
	ok(b.allies[0].mp >= int(ceil(float(b.allies[0].max_mp()) * 0.15)), "a companion's Defend returns 15% of its MP")
	ok(b.log.any(func(l): return l == "Sister Oriel braces for impact."), "and is told")
	ok(b.events.any(func(e): return e["type"] == "defend" and e["by"] == 0), "with its member in the event")
	ok(b.braced.is_empty(), "the brace lasts the round")
	# Halved damage: the same blow with the same dice, braced and not.
	var d := _dynasty("warrior", ["bren_cask"], 30)
	var b2 := _battle(d, 1)
	b2.enemies[0]["atk"] = 500.0
	var amounts: Array = []
	for braced in [false, true]:
		b2.allies[0].hp = b2.allies[0].max_hp()
		b2.braced = {"ally:0": true} if braced else {}
		b2.rng.seed = 99
		b2.events = []
		b2._enemy_hit_ally(0, 0)
		var dmg := b2.events.filter(func(e): return e["type"] == "damage")
		amounts.append(dmg[0]["amount"] if not dmg.is_empty() else -1)
	ok(amounts[0] > 0 and amounts[1] > 0 and absi(amounts[1] * 2 - amounts[0]) <= 1, "a braced companion takes half (%s)" % str(amounts))
	# The heir's Defend is as it was.
	var d3 := _dynasty("warrior", ["bren_cask"], 30)
	var b3 := _battle(d3, 1)
	var r3 := d3.battle_round()
	r3.queue(-1, {"act": "defend"})
	r3.queue(0, _attack())
	r3.resolve()
	ok(b3.log.any(func(l): return l == "Tess braces for impact."), "the heir braces as before")
	ok(not b3.defending and b3.braced.is_empty(), "and it ends with the round")
	ok(b3.events.any(func(e): return e["type"] == "defend" and not e.has("by")), "the heir's event is the old one")


func test_haste() -> void:
	var d := _dynasty("warrior", ["bren_cask"], 30)
	var b := _battle(d, 2)
	var r := d.battle_round()
	b.apply_status("ally:0", "haste", 50.0, 3)
	r.queue(-1, _attack())
	r.queue(0, {"act": "defend"})
	r.resolve()
	ok(b.log.filter(func(l): return l == "Bren Cask braces for impact.").size() == 1, "the chosen command is used once")
	var again := b.log.find("Bren Cask moves again!")
	ok(again >= 0 and again + 1 < b.log.size() and b.log[again + 1].begins_with("Bren Cask hits"), "the bonus act is the class's own choice, not the command again")
	ok(b.round_cmds.is_empty(), "the command was consumed by the first act")
	ok(_acts(b) == [-1, 0], "one act marker per member")


# ---------------------------------------------------------------- the hold flag

func test_hold_flag_always_released() -> void:
	# Defeat.
	var d := _dynasty("warrior", ["bren_cask"], 5)
	var b := _battle(d, 3)
	for e in b.enemies:
		e["atk"] = 100000.0
	d.heir.hp = 1
	var r := d.battle_round()
	r.queue(-1, {"act": "defend"})
	r.queue(0, {"act": "defend"})
	var res := r.resolve()
	ok(res["over"] and res["result"] == "defeat" and not b.round_on and not b.round_marks and b.round_cmds.is_empty(), "defeat releases the hold")
	ok(not r.ready() and not r.resolve()["played"], "a finished fight plays no more rounds")
	ok(r.queue(-1, _attack()) != "", "and takes no more commands")
	# A normal round and a victory.
	var made := _party_round()
	var b2: GameBattle = made[1]
	var r2: GameRound = made[2]
	_all_attack(r2)
	r2.resolve()
	ok(not b2.round_on, "a normal round releases the hold")
	# Autopilot afterwards still works on the same battle.
	var before := b2.turn
	GameTactics.auto_turn(b2)
	ok(b2.turn == before + 1 or b2.is_over(), "auto_turn plays a whole round after a command round")
	ok(not b2.round_on, "and leaves the hold off")


# ---------------------------------------------------------------- view and chips

func test_view_and_chips() -> void:
	var made := _party_round()
	var b: GameBattle = made[1]
	var r: GameRound = made[2]
	var v := r.view()
	for key in ["number", "cursor", "ready", "can_back", "can_repeat", "flee", "auto_commit", "manual_count", "members", "over"]:
		ok(v.has(key), "view has %s" % key)
	var m: Dictionary = v["members"][0]
	for key in ["by", "ref", "name", "hp", "max_hp", "mp", "max_mp", "state", "auto", "decision", "chip", "kind", "statuses", "tip"]:
		ok(m.has(key), "a member has %s" % key)
	ok(m["decision"] == "empty" and m["chip"]["full"] == "Choose" and m["kind"] == "empty", "an undecided member shows Choose")
	ok(not v["auto_commit"], "four members: no auto commit")
	r.queue(-1, {"act": "ability", "kind": "skill", "id": "power_strike", "target": "enemy:1"})
	m = r.view()["members"][0]
	ok(m["decision"] == "queued" and m["kind"] == "skill" and m["chip"]["full"] == "Power Strike > %s" % b.enemies[1]["name"] or m["chip"]["full"].begins_with("Power Strike > "), "a queued skill names its target: %s" % m["chip"]["full"])
	ok(m["chip"]["short"].length() <= int(GameRound.setting("chip_texts")["short_chars"]) and m["chip"]["tiny"].length() <= int(GameRound.setting("chip_texts")["tiny_chars"]), "chip variants fit their budgets (%s)" % str(m["chip"]))
	ok(m["tip"].contains("Tess") and m["tip"].contains("HP"), "the tip tells HP")
	for cmd in [{"act": "attack", "target": "enemy:0"}, {"act": "defend"}, {"act": "potion"}, {"act": "flee"}]:
		var c := r.describe(0, cmd)
		ok(c["full"] != "" and c["short"] != "" and c["tiny"] != "" and c["tiny"].length() <= 5, "describe(%s) = %s" % [cmd["act"], str(c)])
	# Same-name foes get numbers.
	ok(r.describe(0, _attack(2))["full"].ends_with(" 3") or b.enemies[2]["name"] != b.enemies[0]["name"], "foes of one name are numbered")
	# A single manual member commits at once.
	var d := _dynasty("warrior", ["bren_cask"], 30)
	_battle(d)
	var r2 := d.battle_round()
	r2.set_auto(0, true)
	ok(r2.auto_commits() and r2.manual_count() == 1, "heir manual, companion Auto: the pick commits")
	GameData.combat["rounds"]["settings"]["confirm_single"] = true
	ok(not r2.auto_commits(), "the data can ask for a confirm even then")
	GameData.combat["rounds"]["settings"]["confirm_single"] = false
	r2.set_auto(-1, true)
	ok(r2.ready() and r2.manual_count() == 0 and r2.next_unset() == -2, "everyone Auto: ready with nothing queued")
	ok(r2.focus(0) and r2.cursor == 0 and not r2.focus(5), "focus jumps to a member")


# ---------------------------------------------------------------- saves

func test_saves() -> void:
	var d := _dynasty("warrior", TRIO, 30)
	var plain: Dictionary = d.to_dict()
	ok(not plain.has("auto_party"), "a dynasty that never set a switch saves no auto_party")
	ok(not d.party.members.any(func(m): return m.has("auto")), "and no member carries one")
	_battle(d)
	var r := d.battle_round()
	r.set_auto(0, true)
	r.set_auto(-1, true)
	var text := JSON.stringify(d.to_dict())
	var parsed: Dictionary = JSON.parse_string(text)
	ok(parsed["auto_party"]["heir"] == true, "the heir's switch is saved")
	var g := GameDynasty.from_dict(parsed)
	ok(g.auto_party.get("heir", false) == true and g.party.members[0].get("auto", false) == true and not g.party.members[1].has("auto"), "and read back")
	var again := g.to_dict()
	ok(again["auto_party"] == d.auto_party, "a save round-trips")
	# Saving mid-battle is refused as before.
	ok(not d.save_to_disk(), "no save during a battle")
	# Keys removed: defaults.
	var stripped: Dictionary = JSON.parse_string(text)
	stripped.erase("auto_party")
	for m in stripped["party"]["members"]:
		m.erase("auto")
	var h := GameDynasty.from_dict(stripped)
	ok(h.auto_party.is_empty() and not h.party.members.any(func(m): return m.has("auto")), "a save without the keys loads with the defaults")
	_battle(h)
	var r2 := h.battle_round()
	ok(not r2.auto[-1] and not r2.auto[0], "and plays with every member taking orders")
	# Junk is dropped.
	var junk: Dictionary = JSON.parse_string(text)
	junk["auto_party"] = {"heir": true, "nonsense": true}
	junk["party"]["members"][0]["mystery"] = 7
	var k := GameDynasty.from_dict(junk)
	ok(k.auto_party == {"heir": true}, "unknown keys in auto_party are dropped")
	ok(not k.party.members[0].has("mystery"), "an unknown member key is still dropped")
	junk["auto_party"] = "yes"
	ok(GameDynasty.from_dict(junk).auto_party.is_empty(), "a mistyped auto_party is ignored")


func test_old_save_plays() -> void:
	for tag in ["pr4_life", "pr3_life", "party_preaging"]:
		var path := "res://tests/fixtures/old_save_%s.json" % tag
		if not FileAccess.file_exists(path):
			continue
		var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(raw) != TYPE_DICTIONARY or not raw.has("seed"):
			continue
		ok(not raw.has("auto_party"), "(%s predates auto_party)" % tag)
		var g := GameDynasty.from_dict(raw)
		ok(g.auto_party.is_empty(), "%s loads without Auto switches" % tag)
		if g.state != "life":
			continue
		g.start_hunt("hunt")
		var rr := g.battle_round()
		ok(rr != null and rr.members().size() >= 1, "%s: a round opens" % tag)
		var guard := 0
		while not g.battle.is_over() and guard < 80:
			guard += 1
			for by in rr.members():
				if rr.needs_input(by):
					rr.queue(by, _attack(g.battle.first_target()))
			if not rr.resolve()["played"]:
				break
		ok(g.battle.is_over(), "%s: the old save plays a fight through command rounds" % tag)
		g.finish_battle()


# ---------------------------------------------------------------- review fixes

func _ally_blows(b: GameBattle) -> Array:
	return b.events.filter(func(e): return e["type"] == "damage" and e.get("side", "") == "enemy" and e.get("by", -9) >= 0)


func test_review_fixes() -> void:
	# A member covered by a Flee stays covered when their Auto switch is touched, and a hasted one
	# gets no bonus action either.
	_covers(true)
	var made := _party_round()
	var b: GameBattle = made[1]
	var r: GameRound = made[2]
	b.enemies[0]["atk"] = 40.0
	b.apply_status("ally:0", "haste", 50.0, 3)
	_flee_seed(b, false)
	r.queue(-1, {"act": "flee"})
	r.set_auto(1, true)
	ok(r.flee_by == -1 and r.entries[1]["src"] == "cover" and r.entries[0]["src"] == "cover", "Auto on a covered member leaves them covered")
	r.set_auto(1, false)
	ok(r.entries[1]["src"] == "cover" and r.ready(), "and so does turning it off")
	r.resolve()
	ok("Tess fails to escape!" in b.log and _ally_blows(b).is_empty(), "no covered companion struck after the failed flee")
	ok(not b.log.any(func(l): return "moves again" in l), "a hasted covered companion takes no bonus action")
	ok(b.log.filter(func(l): return " covers the retreat." in l).size() == 3, "all three covered")
	# Potions are not promised twice through a Flee.
	var made2 := _party_round()
	var d2: GameDynasty = made2[0]
	var r2: GameRound = made2[2]
	d2.heir.potions = 1
	r2.queue(0, {"act": "potion"})
	r2.queue(1, {"act": "flee"})
	ok(r2.queue(2, {"act": "potion"}) != "" and r2.entries[2]["src"] == "cover", "the potion Flee set aside is still promised")
	ok(r2.check(2, {"act": "potion"}) == "No potions left.", "(and says so)")
	r2.back()
	ok(r2.entries[0]["cmd"]["act"] == "potion", "taking the flee back returns the potion")
	_covers(false)
	# With covering off nobody is set aside: choices stand, and unset members act on their own.
	var made3 := _party_round()
	var b3: GameBattle = made3[1]
	var r3: GameRound = made3[2]
	r3.queue(0, {"act": "defend"})
	ok(r3.queue(1, {"act": "flee"}) == "", "a companion calls the flee")
	ok(r3.entries[0]["src"] == "manual" and not r3.entries.has(2) and not r3.entries.has(-1), "no one is marked covered")
	ok(r3.ready() and r3.next_unset() == -2, "the unset members do not hold the flee up")
	var views: Array = r3.view()["members"].map(func(m): return m["decision"])
	ok(views == ["fallback", "queued", "queued", "fallback"], "chips: own choice kept, others act on their own (%s)" % str(views))
	_flee_seed(b3, false)
	r3.resolve()
	ok(b3.events.any(func(e): return e["type"] == "defend" and e["by"] == 0), "a failed flee leaves a companion's own choice to play")
	ok(not b3.log.any(func(l): return " covers the retreat." in l), "nobody is told to cover")
	# Repeat after a failed flee repeats the round before it.
	var made4 := _party_round()
	var b4: GameBattle = made4[1]
	var r4: GameRound = made4[2]
	_all_attack(r4, 1)
	r4.resolve()
	var kept: Dictionary = r4.last.duplicate(true)
	_flee_seed(b4, false)
	r4.queue(-1, {"act": "flee"})
	r4.resolve()
	ok(r4.last == kept and r4.last[-1]["act"] == "attack", "a flee round leaves the last real round for Repeat")
	ok(r4.repeat_last()["repeated"] == [-1, 0, 1, 2], "and Repeat brings it back")
	# One manual member commits at once; two do not.
	var d5 := _dynasty("warrior", TRIO, 30)
	_battle(d5)
	var r5 := d5.battle_round()
	r5.set_auto(0, true)
	r5.set_auto(1, true)
	r5.set_auto(2, true)
	ok(r5.manual_count() == 1 and r5.auto_commits(), "one member by hand: the pick commits")
	r5.set_auto(2, false)
	ok(r5.manual_count() == 2 and not r5.auto_commits(), "two by hand: a confirm")
	# Companion MP regenerates at the round's end like the heir's.
	var d6 := _dynasty("warrior", ["bren_cask"], 30)
	var b6 := _battle(d6, 2)
	var r6 := d6.battle_round()
	b6.allies[0].mp = 0
	b6.heir.mp = 0
	var nums := b6.unit_numbers(0)
	var regen := maxf(0.0, float(GameData.bal("mp_regen_per_turn_pct")) + float(b6.weather.get("mp_regen", 0.0)))
	var want: int = mini(int(nums["max_mp"]), int(ceil(float(nums["max_mp"]) * (regen + float(nums["mp_regen"])))))
	_all_attack(r6)
	r6.resolve()
	ok(want > 0 and b6.allies[0].mp == want, "a companion's MP regenerates by the same rule (%d of %d)" % [b6.allies[0].mp, want])
	var hn := b6.unit_numbers(-1)
	ok(b6.heir.mp == mini(int(hn["max_mp"]), int(ceil(float(hn["max_mp"]) * (regen + float(hn["mp_regen"]))))), "and the heir's")
	# The heir's Defend reads the setting too.
	var amounts: Array = []
	for pct in [0.15, 0.5]:
		GameData.combat["rounds"]["settings"]["defend_mp_pct"] = pct
		var d7 := _dynasty("warrior", [], 30)
		var b7 := _battle(d7, 1)
		b7.heir.mp = 0
		b7.defend()
		amounts.append(b7.heir.mp)
	GameData.combat["rounds"]["settings"]["defend_mp_pct"] = 0.15
	ok(amounts[1] > amounts[0], "the heir's Defend follows defend_mp_pct (%s)" % str(amounts))
	# The Auto switch survives a dismissal and a new hire.
	var d8 := _dynasty("warrior", [], 30)
	d8.heir.gold = 100000
	d8.world.location = "hearthmere"
	d8.party.hire(d8, "bren_cask")
	d8.party.members[0]["auto"] = true
	d8.party.dismiss(d8, "bren_cask")
	ok(d8.party.members.is_empty() and d8.party.history["bren_cask"]["away"].get("auto", false) == true, "a dismissed companion's switch is kept")
	var saved := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d8.to_dict())))
	d8.party.hire(d8, "bren_cask")
	ok(d8.party.members[0].get("auto", false) == true, "and comes back with them")
	saved.heir.gold = 100000
	saved.party.hire(saved, "bren_cask")
	ok(saved.party.members[0].get("auto", false) == true, "through a save too")
	var d9 := _dynasty("warrior", [], 30)
	d9.heir.gold = 100000
	d9.world.location = "hearthmere"
	d9.party.hire(d9, "bren_cask")
	d9.party.dismiss(d9, "bren_cask")
	d9.party.hire(d9, "bren_cask")
	ok(not d9.party.members[0].has("auto"), "no switch set, none appears")
	# Corrupt saves do not crash.
	var raw := _dynasty("warrior", TRIO, 30).to_dict()
	var text := JSON.stringify(raw)
	var bad: Dictionary = JSON.parse_string(text)
	bad["auto_party"] = {"companion_default": "yes", "heir": 1}
	bad["party"]["members"][0]["auto"] = "yes"
	bad["party"]["members"][1]["auto"] = 1
	bad["party"]["members"][2]["auto"] = true
	var g := GameDynasty.from_dict(bad)
	ok(g.auto_party.is_empty(), "mistyped Auto switches in auto_party read as unset")
	ok(not g.party.members[0].has("auto") and not g.party.members[1].has("auto") and g.party.members[2]["auto"] == true, "and in member records")
	ran += 1


var ran := 0
