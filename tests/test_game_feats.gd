## Feats: the data and its checks, feats by class (own, a hybrid's parents', the few open to all;
## gates, companions, the autopilot's lives, old saves' class migration), MAG scaling and drain,
## power from STR, AGI and the weapon's tier at level 1 and 5000,
## the battle pipeline (turn, no MP, cooldowns, HP costs, statuses, taunt, rally), areas, feats of
## the ground by biome, feat points and slots at their milestones, loadout rules (a town or right
## after a rest; slots, duplicates, requirements, unknown ids), companions' loadouts, the
## autopilot, save/load and old saves, determinism, and the Feats panel and battle commands.
## Run: godot --headless --path . -s res://tests/test_game_feats.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const FeatsPanel := preload("res://ui/play/feats_panel.gd")
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
	test_power_scaling()
	test_numbers_at_every_level()
	test_battle_pipeline()
	test_cooldowns()
	test_hp_cost()
	test_statuses_and_wounds()
	test_taunt_and_rally()
	test_areas()
	test_fields()
	test_ground()
	test_points_and_slots()
	test_new_heir_starts_over()
	test_loadout_rules()
	test_validation()
	test_class_feats()
	test_class_gates()
	test_mag_and_drain()
	test_class_companions()
	test_class_bot_lives()
	test_class_migration()
	test_companions()
	test_companion_choices()
	test_tactics()
	test_bot()
	test_save_load()
	test_old_saves()
	test_determinism()
	test_auto_battle()
	test_lost_turn_and_quiet()
	_ui_tests.call_deferred()


func _done() -> void:
	print("feats tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(cls: String = "warrior", level: int = 1, seed_val: int = 41, weapon: String = "") -> GameDynasty:
	var d := GameDynasty.new_game(seed_val, "Tess", cls, "faetouched", "human")
	d.pending_event = {}
	d.heir.level = level
	d.heir.spells = []
	d.heir.learn_spells()
	GameFeats.start(d.heir)
	d.heir.equipment["weapon"] = weapon
	d.heir.full_heal()
	return d


## A battle against `n` copies of a creature at the heir's level, where the heir stands now.
func _battle(d: GameDynasty, n: int, creature: String = "goblin", power: float = 1.0) -> GameBattle:
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
		e["agi"] = 0


## Readies feats on the heir directly (the rules for doing it are tested on their own).
func _ready_feats(d: GameDynasty, feats: Array) -> void:
	d.heir.known_feats = feats.duplicate()
	d.heir.equipped_feats = feats.duplicate()


func _full_party(d: GameDynasty, ids: Array = ["bren_cask", "sister_oriel", "corwin_saltmere"]) -> void:
	for id in ids:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": d.heir.level, "gen": d.gen, "due": 0.0, "battles": 0, "hired_gen": d.gen})
	d.party.rest(d)


## Lets the turns pass in which the heir catches breath after a feat.
func _catch_breath(b: GameBattle) -> void:
	for k in int(GameFeats.setting("recovery_turns")):
		b.defend()


func _feat_casts(b: GameBattle, by: int = -2) -> Array:
	return b.events.filter(func(ev): return ev["type"] == "cast" and (by == -2 or int(ev["by"]) == by) and not GameFeats.def(_feat_id(ev["name"])).is_empty())


func _feat_id(feat_name: String) -> String:
	for id in GameFeats.ids():
		if GameFeats.feat_name(id) == feat_name:
			return id
	return ""


# ---------------------------------------------------------------- data

func test_data() -> void:
	var errs := GameFeats.validate()
	ok(errs.is_empty(), "the feat data validates: %s" % str(errs))
	ok(GameCombat.validate().is_empty(), "the combat data still validates with the feats' statuses: %s" % str(GameCombat.validate()))
	var ids := GameFeats.ids()
	ok(ids.size() >= 80 and ids.size() <= 110, "about ninety feats (%d)" % ids.size())
	var kinds := {}
	var shapes := {}
	for id in ids:
		var f := GameFeats.def(id)
		kinds[f["kind"]] = int(kinds.get(f["kind"], 0)) + 1
		shapes[GameCombat.shape(f)] = true
		ok(GameFeats.describe(id) != "" and str(f["description"]) != "", "%s has a description and a one-line effect" % id)
		ok(GameFeats.requirement_parts(id)[0].begins_with("Level"), "%s names its level" % id)
		for lv in [1, 100, 5000, 99999]:
			ok(GameCombat.ability_cost(f, lv) == 0, "%s costs no MP at level %d" % [id, lv])
		ok(not f.has("mp") and not f.has("mana") and not f.has("group"), "%s uses no spell resources" % id)
	for k in ["physical", "tactical", "environmental"]:
		ok(int(kinds.get(k, 0)) >= 3, "several %s feats (%d)" % [k, int(kinds.get(k, 0))])
	for sh in ["single", "burst", "cone", "line", "all", "party", "self"]:
		ok(shapes.has(sh), "some feat has the %s shape" % sh)
	# The brief's examples, each doing what it is known for.
	var want := {
		"cleave": func(f): return GameCombat.shape(f) == "cone",
		"whirlwind": func(f): return GameCombat.around_self(f),
		"shield_bash": func(f): return _has_status(f, "stun"),
		"aimed_shot": func(f): return float(f["scaling"].get("agi", 0.0)) > 0.0 and float(f.get("crit_bonus", 0.0)) > 0.0,
		"rain_of_arrows": func(f): return GameCombat.shape(f) == "burst",
		"hamstring": func(f): return _has_status(f, "slow"),
		"sunder": func(f): return _has_status(f, "vulnerable"),
		"execute": func(f): return f.has("vs_wounded"),
		"charge": func(f): return GameCombat.shape(f) == "line",
		"caltrops": func(f): return GameCombat.shape(f) == "burst" and _has_status(f, "bleed"),
		"rockslide": func(f): return f["kind"] == "environmental",
		"pommel_strike": func(f): return _has_status(f, "stun"),
		"feint": func(f): return not f.get("statuses", []).is_empty(),
		"rally": func(f): return f["kind"] == "tactical" and GameCombat.shape(f) == "party",
		"taunt": func(f): return f["statuses"][0]["id"] == "taunt",
	}
	for id in want:
		var f := GameFeats.def(id)
		ok(not f.is_empty() and want[id].call(f), "%s is there and does its work" % id)
	var env := ids.filter(func(id): return GameFeats.def(id)["kind"] == "environmental")
	var grounds := {}
	for id in env:
		for bm in GameFeats.requires(id)["biomes"]:
			grounds[bm] = true
		ok(str(GameFeats.def(id).get("terrain", "")) != "", "%s names its ground" % id)
	for bm in ["mountains", "cave", "swamp", "forest"]:
		ok(grounds.has(bm), "a feat of the %s" % bm)
	# Every weapon in the game has a kind; bare hands are tier 0.
	for item in GameData.items:
		if GameItems.slot_of(item) == "weapon":
			ok(GameFeats.weapon_kind(item) != "", "weapon %s has a kind" % item)
	var bare := GameHeir.new()
	ok(GameFeats.weapon_tier(bare) == 0, "bare hands are tier 0")
	ok(GameFeats.weapon_text(["blade", "blunt"]) == "a blade or mace" and GameFeats.weapon_text(["bow"]) == "a bow", "weapon kinds read as text")


static func _has_status(f: Dictionary, id: String) -> bool:
	for st in f.get("statuses", []):
		if st["id"] == id:
			return true
	return false


func test_broken_data() -> void:
	var broken := {"id": "test_broken", "name": "Broken", "kind": "magical", "description": "x", "cost": 0, "cooldown": -1, "mp": 3,
		"scaling": {"vit": 1.0}, "mult": 1.0, "hp_cost": 0.9, "companion": "no", "drain": 1.5,
		"target": {"shape": "party", "center": "self"},
		"statuses": [{"id": "no_such_status"}, {"id": "stun", "on": "everyone"}],
		"vs_wounded": {"below": 1.5, "mult": 0.5}, "field": {"turns": 2},
		"requires": {"min_level": 0, "classes": ["no_such_class"], "weapon": ["spoon"], "biomes": ["moon"]}}
	GameData.feats["feats"].append(broken)
	GameFeats.reindex()
	var errs := GameFeats.validate()
	for want in ["unknown kind", "never uses 'mp'", "scaling 'vit'", "none of STR, AGI or MAG", "drain is a share", "not aimed at a foe", "cost must be",
			"hp_cost", "companion is true or false", "unknown status", "only a burst can be centred", "vs_wounded", "is on 'everyone'",
			"min_level", "unknown class", "unknown weapon kind", "biome 'moon'", "environmental feats, and only they",
			"a field is left by a burst"]:
		ok(errs.any(func(e): return str(e).begins_with("feat test_broken") and str(e).find(want) >= 0), "a broken feat is reported: %s" % want)
	GameData.feats["feats"].pop_back()
	var long_field: Dictionary = GameFeats.def("caltrops").duplicate(true)
	long_field["id"] = "test_long_field"
	long_field["field"] = {"turns": 99}
	GameData.feats["feats"].append(long_field)
	GameFeats.reindex()
	ok(GameFeats.validate().any(func(e): return str(e).begins_with("feat test_long_field") and str(e).find("a field lasts from 1 to") >= 0), "a field that never clears is reported")
	GameData.feats["feats"].pop_back()
	var dup: Dictionary = GameData.feats["feats"][0].duplicate(true)
	GameData.feats["feats"].append(dup)
	GameFeats.reindex()
	ok(GameFeats.validate().any(func(e): return str(e).find("defined twice") >= 0), "a feat defined twice is reported")
	GameData.feats["feats"].pop_back()
	GameData.items["test_club"] = {"id": "test_club", "name": "Club", "slot": "weapon", "tier": 1, "effects": []}
	GameFeats.reindex()
	ok(GameFeats.validate().any(func(e): return str(e).find("weapon test_club has no kind") >= 0), "a weapon without a kind is reported")
	GameData.items.erase("test_club")
	var s := GameFeats.settings()
	var keep: Array = s["point_levels"]
	s["point_levels"] = [5, 3, 200000]
	ok(GameFeats.validate().any(func(e): return str(e).find("point_levels must rise") >= 0), "milestones out of order are reported")
	s["point_levels"] = keep
	GameFeats.reindex()
	ok(GameFeats.validate().is_empty(), "the data is sound again")


# ---------------------------------------------------------------- power

func test_power_scaling() -> void:
	for spec in [[1, 1], [5000, 1], [5000, 300]]:
		var lv: int = spec[0]
		var d := _dyn("warrior", lv, 51)
		d.gen = spec[1]
		d.heir.gen = spec[1]
		var h := d.heir
		var tag := "level %d gen %d" % [lv, spec[1]]
		# STR feats land as hard as a plain blow per point of weight; bare hands add nothing.
		var cleave := GameFeats.def("cleave")
		ok(is_equal_approx(GameFeats.power(h, "cleave"), h.attack_power() * float(cleave["scaling"]["str"])), "%s: bare-handed Cleave is a plain blow's power" % tag)
		# AGI feats weigh AGI the way a blow weighs STR, with the same bonuses.
		var per := h.attack_power() / h.stat("str")
		ok(is_equal_approx(GameFeats.power(h, "aimed_shot"), per * h.stat("agi") * float(GameFeats.def("aimed_shot")["scaling"]["agi"])), "%s: Aimed Shot follows AGI" % tag)
		var agi_before := GameFeats.power(h, "aimed_shot")
		var str_before := GameFeats.power(h, "cleave")
		h.training["agi"] += 50.0
		ok(GameFeats.power(h, "aimed_shot") > agi_before and is_equal_approx(GameFeats.power(h, "cleave"), str_before), "%s: more AGI raises AGI feats only" % tag)
		h.training["agi"] -= 50.0
		h.training["str"] += 50.0
		ok(GameFeats.power(h, "cleave") > str_before and is_equal_approx(GameFeats.power(h, "aimed_shot"), agi_before), "%s: more STR raises STR feats only" % tag)
		h.training["str"] -= 50.0
		var mixed := GameFeats.def("hamstring")
		var want: float = (h.attack_power() * float(mixed["scaling"]["str"]) + per * h.stat("agi") * float(mixed["scaling"]["agi"]))
		ok(is_equal_approx(GameFeats.power(h, "hamstring"), want), "%s: a mixed feat adds both weights" % tag)
		# The weapon's tier: each tier adds the feat's weight, on top of the weapon's own bonus.
		var last := 0.0
		for w in ["", "iron_sword", "steel_sword", "mithril_blade", "sunblade"]:
			h.equipment["weapon"] = w
			var tier := GameFeats.weapon_tier(h)
			var p := GameFeats.power(h, "cleave")
			ok(is_equal_approx(p, h.attack_power() * (1.0 + 0.08 * float(tier))), "%s: Cleave with %s (tier %d) gains 8%% a tier" % [tag, w if w != "" else "bare hands", tier])
			ok(p > last, "%s: a better blade, a harder Cleave (%s)" % [tag, w])
			last = p
		h.equipment["weapon"] = ""


## A feat on a foe of its own level takes a sensible share of the foe's HP at level 1 and level
## 5,000, in the first generation and the 300th: the numbers never run away or vanish.
func test_numbers_at_every_level() -> void:
	var shares := []
	for spec in [[1, 1], [60, 1], [5000, 1], [5000, 300]]:
		var d := _dyn("warrior", spec[0], 61, "steel_sword")
		d.gen = spec[1]
		d.heir.gen = spec[1]
		d.heir.full_heal()
		_ready_feats(d, ["cleave", "aimed_shot", "execute"])
		var b := _battle(d, 1, "goblin")
		var e: Dictionary = b.enemies[0]
		var share := b.estimate(-1, GameFeats.def("cleave"), 0) / float(e["max_hp"])
		var blow := b.estimate(-1, {}, 0) / float(e["max_hp"])
		shares.append(share / blow)
		ok(share > 0.08 and share < 0.9, "level %d gen %d: Cleave takes %.0f%% of a level-matched goblin" % [spec[0], spec[1], share * 100.0])
		ok(share > blow and share < blow * 2.0, "level %d gen %d: a Cleave beats a plain blow but not by double (%.2f vs %.2f)" % [spec[0], spec[1], share, blow])
		d.battle = null
	ok(absf(float(shares[0]) / float(shares[2]) - 1.0) < 0.15 and absf(float(shares[3]) / float(shares[2]) - 1.0) < 0.15, "against a plain blow, Cleave weighs the same at level 1, level 5,000 and generation 300 (%s)" % str(shares))


# ---------------------------------------------------------------- the battle pipeline

func test_battle_pipeline() -> void:
	var d := _dyn("warrior", 20, 71, "steel_sword")
	_ready_feats(d, ["cleave", "flurry", "rally"])
	var b := _battle(d, 3, "goblin")
	_sturdy(b)
	d.heir.mp = 0
	ok(b.can_use_feat(0), "a feat needs no MP")
	var turn := b.turn
	b.use_feat(0, 1)
	ok(b.turn == turn + 1, "a feat takes the heir's turn")
	ok(b.log.any(func(l): return str(l) == "Tess uses Cleave."), "the log tells the feat")
	ok(_feat_casts(b, -1).size() == 1, "one cast event for the feat")
	var hits := b.events.filter(func(ev): return ev["type"] in ["damage", "miss"] and ev["side"] == "enemy" and int(ev.get("cast", 0)) > 0)
	ok(hits.size() == b.aoe_targets(GameFeats.def("cleave"), -1, 1).size() and hits.size() == 3, "Cleave rolls a blow on each foe it catches (%d)" % hits.size())
	var regen := maxf(0.0, float(GameData.bal("mp_regen_per_turn_pct")) + float(b.weather.get("mp_regen", 0.0)))
	ok(d.heir.mp == mini(d.heir.max_mp(), int(ceil(float(d.heir.max_mp()) * regen))), "no MP was spent, only the turn's regen came back (%d)" % d.heir.mp)
	# Several hits on one foe once the heir has caught breath; then a feat for the party.
	_catch_breath(b)
	b.use_feat(1, 0)
	var cast: Dictionary = _feat_casts(b, -1)[0] if _feat_casts(b, -1).size() == 1 else {}
	var flurry := b.events.filter(func(ev): return ev["type"] in ["damage", "miss"] and ev["side"] == "enemy" and int(ev.get("cast", 0)) == int(cast.get("cast", -1)))
	ok(str(cast.get("name", "")) == "Flurry" and flurry.size() == 3, "Flurry strikes three times (%d)" % flurry.size())
	_catch_breath(b)
	b.use_feat(2, -1)
	ok(b.has_status("heir", "rallied"), "Rally takes heart in the heir")
	ok(b.feat_in_slot(5) == "" and b.feat_block(-1, "sunder") != "", "an empty slot or an unreadied feat is no feat")
	turn = b.turn
	b.use_feat(5, 0)
	ok(b.turn == turn, "an empty slot does nothing")
	d.battle = null


func test_cooldowns() -> void:
	var d := _dyn("warrior", 20, 72, "steel_sword")
	_ready_feats(d, ["cleave", "rally"])
	var b := _battle(d, 2, "goblin")
	_sturdy(b)
	var cd := GameFeats.cooldown("cleave")
	b.use_feat(0, 0)
	ok(b.feat_wait(-1, "cleave") == cd and not b.can_use_feat(0), "Cleave waits %d turns after use (%d)" % [cd, b.feat_wait(-1, "cleave")])
	ok(b.feat_block(-1, "cleave").begins_with("Ready in %d turns" % cd), "the wait is told: %s" % b.feat_block(-1, "cleave"))
	var turn := b.turn
	var lines := b.log.size()
	b.use_feat(0, 0)
	ok(b.turn == turn and b.log.size() == lines, "a cooling feat cannot be used and costs nothing")
	var rec := int(GameFeats.setting("recovery_turns"))
	ok(rec < cd and b.feat_wait(-1, "rally") == rec, "after a feat the heir catches breath for %d turn%s before any other" % [rec, "" if rec == 1 else "s"])
	if rec > 0:
		ok(b.feat_block(-1, "rally").begins_with("Catching breath: ready in %d turn" % rec), "and says so: %s" % b.feat_block(-1, "rally"))
	for k in cd:
		ok(not b.can_use_feat(0), "still cooling after %d turn%s" % [k, "" if k == 1 else "s"])
		ok(b.can_use_feat(1) == (k >= rec), "the other feat is ready once the breath is caught (turn %d)" % k)
		b.defend()
	ok(b.can_use_feat(0) and b.feat_wait(-1, "cleave") == 0, "ready again after %d turns" % cd)
	# Each unit's cooldowns are its own, and each battle starts fresh.
	_full_party(d, ["bren_cask"])
	d.battle = null
	var b2 := _battle(d, 2, "goblin")
	_sturdy(b2)
	ok(b2.can_use_feat(0), "a new battle starts with every feat ready")
	var ally_feat: String = b2.unit_feats(0)[0] if not b2.unit_feats(0).is_empty() else ""
	ok(ally_feat != "", "the companion carries feats")
	b2.use_feat(0, 0)
	ok(b2.feat_ready.get("heir", {}).has("cleave") and not b2.feat_ready.get("ally:0", {}).has("cleave"), "the heir's Cleave cools only the heir")
	if ally_feat != "":
		b2.feat_ready.erase("ally:0")
		ok(b2.feat_wait(0, ally_feat) == 0, "the heir catching breath does not hold the companion back")
		b2._spend_feat(0, ally_feat)
		ok(b2.feat_wait(0, ally_feat) == GameFeats.cooldown(ally_feat) + 1 and b2.feat_block(0, ally_feat).begins_with("Ready in"), "the companion's %s cools on its own" % ally_feat)
		ok(not b2.feat_ready.get("heir", {}).has(ally_feat), "and not the heir's")
	d.battle = null


func test_hp_cost() -> void:
	var d := _dyn("warrior", 30, 73, "steel_sword")
	_ready_feats(d, ["whirlwind"])
	var b := _battle(d, 3, "goblin")
	_sturdy(b)
	var max_hp := d.heir.max_hp()
	var cost := GameFeats.hp_cost(d.heir, "whirlwind")
	ok(cost == int(ceil(float(max_hp) * float(GameFeats.def("whirlwind")["hp_cost"]))), "Whirlwind costs its share of max HP (%d of %d)" % [cost, max_hp])
	var hp := d.heir.hp
	b.use_feat(0, 0)
	var struck := 0
	for ev in b.events:
		if ev["type"] == "damage" and ev["side"] == "player":
			struck += int(ev["amount"])
	ok(d.heir.hp == hp - cost - struck, "the HP is paid (%d -> %d, %d of it from blows)" % [hp, d.heir.hp, struck])
	ok(b.events.any(func(ev): return ev["type"] == "hp_cost" and int(ev["amount"]) == cost), "an event shows the price")
	for k in 4:
		b.defend()
	d.heir.hp = cost
	ok(b.feat_block(-1, "whirlwind").begins_with("Too hurt"), "a feat that would take the last HP is refused: %s" % b.feat_block(-1, "whirlwind"))
	d.heir.hp = cost + 1
	ok(b.can_use_feat(0), "with HP to spare it can be paid")
	ok(GameFeats.hp_cost(d.heir, "cleave") == 0, "most feats cost no HP")
	d.battle = null


func test_statuses_and_wounds() -> void:
	var d := _dyn("warrior", 30, 74, "iron_mace")
	_ready_feats(d, ["sunder", "execute", "shield_bash"])
	var landed := 0
	for k in 20:
		var b := _battle(d, 1, "goblin")
		for e in b.enemies:
			e["atk"] = 0.0
			e["agi"] = 0
			e["hp"] = 1000000
			e["max_hp"] = 1000000
		b.use_feat(0, 0)
		if b.has_status(GameBattle.enemy_ref(0), "vulnerable"):
			landed += 1
		d.battle = null
	ok(landed >= 12, "Sunder leaves a level-matched foe exposed most of the time (%d of 20)" % landed)
	var b := _battle(d, 1, "goblin")
	_sturdy(b)
	var ex := GameFeats.def("execute")
	var fresh := b.estimate(-1, ex, 0)
	b.enemies[0]["hp"] = int(float(b.enemies[0]["max_hp"]) * 0.2)
	var wounded := float(b.expected_hits(-1, ex, 0)[0][1])
	ok(wounded > fresh * 2.5, "Execute hits a staggering foe about three times as hard (%.0f vs %.0f)" % [wounded, fresh])
	d.battle = null
	# Bosses shrug off most stuns, as they do every hold.
	var boss := GameCombat.creature_def("grimfang")
	var stunned := 0
	for k in 30:
		d._begin_battle([d._make_enemy(boss, 1.0, 1.0, 30)], "legend")
		var lb := d.battle
		lb.enemies[0]["atk"] = 0.0
		lb.enemies[0]["agi"] = 0
		lb.use_feat(2, 0)
		if lb.events.any(func(ev): return ev["type"] == "status" and ev["id"] == "stun" and ev.get("applied", false)):
			stunned += 1
		d.battle = null
	ok(stunned <= 12, "a legend is seldom stunned by Shield Bash (%d of 30)" % stunned)


func test_taunt_and_rally() -> void:
	var d := _dyn("warrior", 30, 75, "steel_sword")
	_ready_feats(d, ["taunt", "rally"])
	_full_party(d)
	var b := _battle(d, 3, "goblin")
	for e in b.enemies:
		e["hp"] = 10000000
		e["max_hp"] = 10000000
	b.use_feat(0, -1)
	ok(b.has_status("heir", "taunt") and b._taunting() == -1, "Taunt draws every foe onto the heir")
	var on_allies := 0
	var on_heir := 0
	for k in 2:
		for ev in b.events:
			if ev["type"] in ["damage", "miss"] and ev["side"] == "ally":
				on_allies += 1
			if ev["type"] in ["damage", "miss"] and ev["side"] == "player":
				on_heir += 1
		if k == 0:
			b.defend()
	ok(on_allies == 0 and on_heir >= 3, "while it holds, every blow goes to the heir (%d on the heir, %d on companions)" % [on_heir, on_allies])
	for k in 3:
		b.defend()
	ok(not b.has_status("heir", "taunt"), "the taunt wears off")
	b.use_feat(1, -1)
	var rallied := ["heir"] + b.conscious_allies().map(func(ai): return GameBattle.ref_of(ai))
	ok(rallied.all(func(r): return b.has_status(r, "rallied")), "Rally reaches the whole party")
	var lift := float(GameFeats.def("rally")["statuses"][0]["potency"])
	ok(lift > 0.0 and is_equal_approx(b._dealt_mult("heir"), 1.0 + lift), "rallied, the heir hits %d%% harder (%.2f)" % [int(round(lift * 100.0)), b._dealt_mult("heir")])
	d.battle = null


# ---------------------------------------------------------------- areas

func test_areas() -> void:
	var d := _dyn("warrior", 40, 76, "steel_sword")
	_ready_feats(d, ["cleave", "whirlwind", "charge", "earthshaker"])
	var b := _battle(d, 5, "goblin")   # three in front, two behind
	_sturdy(b)
	var front: Array = []
	var back: Array = []
	for i in b.enemies.size():
		(front if b.enemies[i]["row"] == "front" else back).append(i)
	ok(front.size() == 3 and back.size() == 2, "five goblins stand three and two")
	var mid: int = front[1]
	var cleave := GameFeats.def("cleave")
	var caught := b.aoe_targets(cleave, -1, mid)
	ok(caught.size() == 3 and front.all(func(i): return i in caught), "Cleave aimed at the middle catches the front rank only: %s" % str(caught))
	var spin := GameFeats.def("whirlwind")
	var around: Array = b.aoe_targets(spin, -1, front[0])
	for i in b.living_enemies():
		ok(b.aoe_targets(spin, -1, i) == around, "Whirlwind catches the same foes wherever it is aimed (at %d)" % i)
	ok(around.size() == 3 and back.all(func(i): return i not in around), "Whirlwind reaches the foes around the heir, not the back rank: %s" % str(around))
	var line := b.aoe_targets(GameFeats.def("charge"), -1, int(back[0]))
	ok(line.size() >= 2 and int(back[0]) in line and line.any(func(i): return i in front), "Charge goes through the front rank to the foe behind: %s" % str(line))
	ok(b.aoe_targets(GameFeats.def("earthshaker"), -1, mid).size() == 5, "Earthshaker reaches every foe")
	# An area that reaches no one is not used; nothing is spent.
	for e in b.enemies:
		e["x"] = 40.0
	var turn := b.turn
	b.use_feat(0, mid)
	ok(b.turn == turn and b.can_use_feat(0) and b.log.all(func(l): return str(l) != "Tess uses Cleave."), "a Cleave that reaches no foe is not used")
	d.battle = null


## Caltrops leave a field: from the next round, for as long as it holds, every foe that starts its
## turn inside takes the bleed and slow again; a foe outside never does; then it is gone.
func test_fields() -> void:
	var d := _dyn("rogue", 20, 78, "steel_sword")
	_ready_feats(d, ["caltrops"])
	var b := _battle(d, 3, "goblin")
	_sturdy(b)
	b.enemies[2]["y"] = 40.0   # well clear of anything aimed at the others
	var aim := 0
	var ab := GameFeats.def("caltrops")
	ok(b.aoe_targets(ab, -1, aim) == [0, 1], "the spikes reach the two foes together, not the one apart: %s" % str(b.aoe_targets(ab, -1, aim)))
	var laid_turn := b.turn
	b.use_feat(0, aim)
	ok(b.fields.size() == 1 and is_equal_approx(float(b.fields[0]["x"]), b.enemy_point(aim).x) and is_equal_approx(float(b.fields[0]["radius"]), float(ab["target"]["radius"])), "the field lies where the spikes were thrown: %s" % str(b.fields))
	ok(b.log.has(str(ab["field"]["text"]["lay"])), "and the journal of the fight says so")
	var thrown := b.events.filter(func(ev): return ev["type"] == "status" and ev.get("applied", false) and str(ev["ref"]).begins_with("enemy"))
	var by_foe := {}
	for ev in thrown:
		by_foe[ev["ref"]] = int(by_foe.get(ev["ref"], 0)) + 1
	ok(by_foe.values().all(func(n): return n <= 2), "in the round it is thrown no foe is struck twice by it: %s" % str(by_foe))
	var rounds := int(ab["field"]["turns"])
	var again := 0
	for k in rounds:
		ok(b.fields.size() == 1 and b.field_turns_left(b.fields[0]) == rounds - k, "round %d: the field holds %d more" % [k + 1, rounds - k])
		b.defend()
		for ev in b.events:
			if ev["type"] == "status" and ev.get("applied", false) and str(ev["id"]) in ["bleed", "slow"]:
				ok(ev["ref"] != GameBattle.enemy_ref(2), "the foe standing apart is never caught")
				if ev["ref"] in [GameBattle.enemy_ref(0), GameBattle.enemy_ref(1)]:
					again += 1
	ok(again >= 2, "foes starting their turns on the spikes take them again (%d times)" % again)
	ok(b.fields.is_empty() and b.log.has(str(ab["field"]["text"]["end"])), "after %d rounds the field is gone" % rounds)
	ok(b.turn == laid_turn + rounds + 1, "the field lasted the rounds the data gives")
	b.defend()
	ok(not b.events.any(func(ev): return ev["type"] == "status" and ev.get("applied", false) and str(ev["id"]) in ["bleed", "slow"]), "and strikes no more")
	ok(GameFeats.describe("caltrops").find("the ground holds it %d more turns" % rounds) >= 0, "the feat's text tells the field: %s" % GameFeats.describe("caltrops"))
	d.battle = null


func test_ground() -> void:
	var cases := [["rockslide", "highcrag", "hearthmere"], ["rockslide", "goblin_warrens", "mirefen"], ["mire_trap", "mirefen", "whisperwood"],
		["brushfire", "whisperwood", "brinehaven"], ["undertow", "brinehaven", "highcrag"], ["falling_masonry", "hollow_barrow", "kingshold"]]
	for c in cases:
		var id: String = c[0]
		var d := _dyn("warrior", 40, 77)
		_ready_feats(d, [id])
		d.world.visit(c[1])
		var b := _battle(d, 3, "goblin")
		ok(b.biomes == GameWorld.place(c[1])["biomes"], "the battle knows its ground (%s)" % c[1])
		ok(b.can_use_feat(0), "%s works in %s" % [id, c[1]])
		_sturdy(b)
		b.use_feat(0, 0)
		ok(_feat_casts(b, -1).size() == 1, "%s is used in %s" % [id, c[1]])
		d.battle = null
		d.world.visit(c[2])
		var b2 := _battle(d, 3, "goblin")
		var why := b2.feat_block(-1, id)
		ok(not b2.can_use_feat(0) and why.begins_with("Needs ") and why.find(str(GameFeats.def(id)["terrain"]).left(8)) >= 0, "%s does not work in %s: %s" % [id, c[2], why])
		ok(GameTactics.options(b2, -1).all(func(o): return str(o.get("feat", "")) != id), "the autopilot does not offer %s on the wrong ground" % id)
		d.battle = null


# ---------------------------------------------------------------- points and slots

func test_points_and_slots() -> void:
	var start := int(GameFeats.setting("start_points"))
	ok(GameFeats.points_at(1) == start and start >= 1, "a level-1 heir has %d points" % start)
	var levels: Array = GameFeats.setting("point_levels")
	for k in levels.size():
		var lv := int(levels[k])
		ok(GameFeats.points_at(lv) == start + k + 1 and GameFeats.points_at(lv - 1) == start + k, "a point at level %d" % lv)
	var early := levels.filter(func(lv): return int(lv) <= 100).size()
	var late := levels.filter(func(lv): return int(lv) > 10000).size()
	ok(early >= 12 and late <= 15 and int(levels[-1]) == int(GameData.bal("level_cap")), "frequent early (%d by level 100), sparse late (%d past 10,000), the last at the cap" % [early, late])
	# Logarithmic: each point comes a near-constant factor of levels after the last.
	for k in range(8, levels.size()):
		var ratio := float(levels[k]) / float(levels[k - 1])
		ok(ratio > 1.1 and ratio < 1.5, "milestone %d (level %d) is %.2fx the last" % [k, int(levels[k]), ratio])
	ok(GameFeats.slots_at(1) == 2, "two slots at level 1")
	var most := 0
	for lv in [1, 5, 10, 40, 100, 250, 1000, 2000, 5000, 99999]:
		ok(GameFeats.slots_at(lv) >= most, "slots never shrink (level %d: %d)" % [lv, GameFeats.slots_at(lv)])
		most = GameFeats.slots_at(lv)
	ok(most == 6, "about six slots in the end (%d)" % most)
	# Levelling up grants the milestones' points and tells them when time next passes.
	var d := _dyn("warrior", 1, 81)
	var h := d.heir
	ok(h.feat_points == start, "a founder starts with the points of level 1")
	var xp := 0
	while h.level < 10:
		xp = h.xp_to_next() - h.xp
		h.gain_xp(xp)
	ok(h.feat_points == GameFeats.points_at(h.level), "points for every milestone up to level %d (%d)" % [h.level, h.feat_points])
	ok(not h.feat_news.is_empty(), "the milestones wait for the journal")
	var msgs := d.train("str")
	ok(msgs.any(func(m): return str(m).find("feat point") >= 0 and str(m).find("can now ready 3 feats") >= 0), "the journal tells the points and the third slot: %s" % str(msgs))
	ok(h.feat_news.is_empty(), "and the news is told once")


func test_new_heir_starts_over() -> void:
	var d := _dyn("warrior", 30, 82, "steel_sword")
	var h := d.heir
	GameFeats.learn(d, "cleave")
	GameFeats.learn(d, "charge")
	ok(h.known_feats.size() == 2, "the parent knows two feats")
	h.age = h.family_min_age()
	d.found_family()
	if d.state == "life":
		d.retire()
	ok(d.state == "succession", "the parent's life ends")
	d.choose_heir(0)
	var c := d.heir
	ok(c != h and c.known_feats.is_empty() and c.equipped_feats.is_empty(), "the new heir knows no feats: they are personal")
	ok(c.feat_points == GameFeats.points_at(c.level) and c.feat_level == c.level, "and starts with the points of their own level (%d)" % c.feat_points)


# ---------------------------------------------------------------- loadout rules

func test_loadout_rules() -> void:
	var d := _dyn("warrior", 12, 83, "steel_sword")
	var h := d.heir
	ok(d.world.is_town() and GameFeats.manage_block(d) == "", "feats can be changed in a town")
	var pts := h.feat_points
	var msg := GameFeats.learn(d, "cleave")
	ok("cleave" in h.known_feats and "cleave" in h.equipped_feats and h.feat_points == pts - GameFeats.cost("cleave"), "learning spends the points and readies the feat: %s" % msg)
	ok(d.journal.back() == msg, "and is journaled")
	ok(GameFeats.unequip(d, "cleave").find("aside") >= 0 and "cleave" not in h.equipped_feats and "cleave" in h.known_feats, "set aside, a feat stays learned")
	ok(GameFeats.equip(d, "cleave").find("readies") >= 0 and "cleave" in h.equipped_feats, "and can be readied again")
	# The wilds: nothing changes there.
	d.world.visit("whisperwood")
	var why := GameFeats.manage_block(d)
	ok(why.find("Whisperwood") >= 0 and why.find("town") >= 0 and why.find("rest") >= 0, "the wilds give a clear reason: %s" % why)
	var before := JSON.stringify(h.to_dict())
	ok(GameFeats.learn(d, "charge") == why and GameFeats.equip(d, "charge") == why and GameFeats.unequip(d, "cleave") == why, "learn, ready and set aside are all refused there")
	ok(JSON.stringify(h.to_dict()) == before, "and nothing changed")
	# Right after a rest it can be done, until the next thing that takes time.
	d.rest()
	ok(h.downtime and GameFeats.manage_block(d) == "", "after a rest in the wilds feats can be changed")
	ok(GameFeats.learn(d, "charge").find("learns Charge") >= 0, "Charge is learned after the rest")
	d.train("agi")
	ok(not h.downtime and GameFeats.manage_block(d) != "", "training ends the quiet")
	d.rest()
	d.start_hunt("hunt")
	ok(GameFeats.manage_block(d) == "Not in the middle of a fight.", "never in a fight")
	GameBot.fight(d)
	if d.state == "life":
		ok(not h.downtime and GameFeats.manage_block(d) != "", "a hunt ends the quiet too")
		d.rest()
		d.travel("hearthmere")
		ok(not h.downtime and d.world.is_town() and GameFeats.manage_block(d) == "", "travel ends the quiet, and a town allows it again")


func test_validation() -> void:
	var d := _dyn("warrior", 12, 84, "steel_sword")
	var h := d.heir
	ok(GameFeats.learn(d, "no_such_feat") == "No such feat." and GameFeats.equip(d, "no_such_feat") == "No such feat." and GameFeats.unequip(d, "no_such_feat") == "No such feat.", "unknown ids are refused")
	GameFeats.learn(d, "cleave")
	ok(GameFeats.learn(d, "cleave").find("already knows") >= 0, "a feat cannot be learned twice")
	ok(GameFeats.equip(d, "cleave").find("already readied") >= 0 and h.equipped_feats.count("cleave") == 1, "or readied twice")
	ok(GameFeats.equip(d, "charge").find("not learned") >= 0, "an unlearned feat cannot be readied")
	ok(GameFeats.learn(d, "execute").begins_with("Needs level 30"), "the level is enforced: %s" % GameFeats.learn(d, "execute"))
	ok(GameFeats.learn(d, "sunder").find("mace in hand") >= 0, "the weapon is enforced: %s" % GameFeats.learn(d, "sunder"))
	ok(GameFeats.learn(d, "aimed_shot").begins_with("Taught only to a Ranger"), "the class comes before the weapon: %s" % GameFeats.learn(d, "aimed_shot"))
	var m := _dyn("mage", 12, 85)
	ok(GameFeats.learn(m, "shield_bash").begins_with("Taught only to a Warrior"), "the class is enforced: %s" % GameFeats.learn(m, "shield_bash"))
	ok(GameFeats.learn(d, "unequip") == "No such feat.", "a feat is only what the data names")
	# Slots: three at level 12, then full.
	for id in ["charge", "feint"]:
		GameFeats.learn(d, id)
	ok(h.equipped_feats.size() == GameFeats.slots(h) and GameFeats.slots(h) == 3, "three slots at level 12 are filled: %s" % str(h.equipped_feats))
	var left := h.feat_points
	var learned := GameFeats.learn(d, "hamstring")
	ok(learned.find("learns Hamstring (") >= 0 and "hamstring" not in h.equipped_feats, "learned with every slot full, a feat waits set aside: %s" % learned)
	ok(GameFeats.equip(d, "hamstring").find("slots are full") >= 0, "the slot limit is enforced")
	h.feat_points = 0
	ok(GameFeats.learn(d, "taunt").find("costs 1 feat point") >= 0, "without points nothing is learned: %s" % GameFeats.learn(d, "taunt"))
	ok(left > 0 and h.feat_points == 0, "points never go below zero")
	# A readied feat that asks for another weapon stays readied, but cannot be used with this one.
	d.heir.equipment["weapon"] = "longbow"
	var b := _battle(d, 2, "goblin")
	ok(b.feat_block(-1, "cleave").find("blade or mace") >= 0, "Cleave with a bow in hand: %s" % b.feat_block(-1, "cleave"))
	d.battle = null


# ---------------------------------------------------------------- companions

# ---------------------------------------------------------------- feats by class

const UNIVERSAL := ["feint", "pommel_strike", "taunt", "hamstring", "mire_trap", "charge", "rally", "rockslide", "brushfire",
	"undertow", "falling_masonry"]


func _base_classes() -> Array:
	return GameData.classes.keys().filter(func(c): return not GameData.classes[c].has("parents"))


func test_class_feats() -> void:
	ok(GameFeats.universal_feats() == UNIVERSAL, "the feats open to every class are exactly the tactical basics and the ground's: %s" % str(GameFeats.universal_feats()))
	var seen := {}
	for id in GameFeats.ids():
		ok(not seen.has(id), "feat id %s is used once" % id)
		seen[id] = true
	ok(GameData.classes.size() == 19, "19 classes to give feats to (%d)" % GameData.classes.size())
	for cid in GameData.classes:
		var mine := GameFeats.class_feats(cid)
		ok(mine.size() >= 6, "%s can learn %d feats of a class's own" % [cid, mine.size()])
		ok(mine.all(func(id): return id not in UNIVERSAL), "%s's class feats are not the open ones" % cid)
		var c: Dictionary = GameData.classes[cid]
		if not c.has("parents"):
			var own := GameFeats.feats_from(cid, cid)
			ok(own.size() >= 6 and own.size() <= 9, "base class %s has %d feats of its own" % [cid, own.size()])
			var lvs: Array = own.map(func(id): return int(GameFeats.requires(id)["min_level"]))
			ok(lvs.min() == 1 or lvs.min() <= 3, "%s's craft starts by level 3 (%s)" % [cid, str(lvs)])
			ok(lvs.max() >= 200, "%s's craft reaches into the late game (%s)" % [cid, str(lvs)])
		else:
			var own := GameFeats.feats_from(cid, cid)
			ok(own.size() >= 1 and own.size() <= 2, "hybrid %s has its signature feats: %s" % [cid, str(own)])
			for p in c["parents"]:
				var from := GameFeats.feats_from(str(p), str(p))
				ok(from.all(func(id): return id in mine), "hybrid %s learns every %s feat" % [cid, p])
				ok(GameFeats.feats_from(cid, str(p)).size() > 0, "hybrid %s lists feats from the %s" % [cid, p])
	# A class with no craft of its own is reported.
	GameData.classes["test_base"] = {"id": "test_base", "name": "Tester"}
	GameData.classes["test_hybrid"] = {"id": "test_hybrid", "name": "Mixed Tester", "parents": ["warrior", "mage"]}
	var errs := GameFeats.validate()
	ok(errs.has("class test_base is taught only 0 feats of its own; it needs at least 6") and errs.has("class test_base has no damaging feat by level 3 that asks for no weapon"), "a base class with no feats is reported: %s" % str(errs))
	ok(errs.has("hybrid class test_hybrid has no feat of its own"), "and a hybrid with none of its own")
	GameData.classes.erase("test_base")
	GameData.classes.erase("test_hybrid")
	ok(GameFeats.validate().is_empty(), "and the real data is sound again")
	# Two parents' crafts and a signature of its own.
	var sb := GameFeats.class_feats("spellblade")
	ok("cleave" in sb and "arcane_strike" in sb and "spellstrike" in sb, "a spellblade has Cleave, Arcane Strike and Spellstrike")
	var nj := GameFeats.class_feats("ninja")
	ok("flurry" in nj and "cheap_shot" in nj and "leg_sweep" in nj and "shuriken" in nj, "a ninja has Flurry, Cheap Shot, Leg Sweep and Shuriken")
	ok("cleave" not in GameFeats.class_feats("ninja") and "spellstrike" not in GameFeats.class_feats("paladin"), "and nothing of other houses")
	# Two base classes never share their whole craft.
	var bases := _base_classes()
	for i in bases.size():
		for k in range(i + 1, bases.size()):
			ok(GameFeats.feats_from(bases[i], bases[i]) != GameFeats.feats_from(bases[k], bases[k]), "%s and %s have their own feats" % [bases[i], bases[k]])
	# The feats panel lists only what the class may learn, grouped.
	var d := _dyn("spellblade", 20, 140)
	var groups: Array = FeatsPanel.learn_groups(d.heir)
	ok(groups.map(func(g): return g["title"]) == ["Spellblade feats", "From the Warrior", "From the Mage", "Open to every class", "Of the land"], "a spellblade's feats in their groups: %s" % str(groups.map(func(g): return g["title"])))
	var listed := {}
	for g in groups:
		for id in g["ids"]:
			ok(not listed.has(id), "%s is listed once" % id)
			listed[id] = true
	ok(listed.size() == GameFeats.class_feats("spellblade").size() + UNIVERSAL.size() and not listed.has("flurry") and not listed.has("radiant_strike"), "only what a spellblade may learn is listed (%d)" % listed.size())
	ok(GameFeats.next_class_feat(d.heir) == "Arcane Detonation at level 24", "the next class feat is told: %s" % GameFeats.next_class_feat(d.heir))
	ok(FeatsPanel.summary_lines(d).has("Next class feat: Arcane Detonation at level 24"), "and on the life screen: %s" % str(FeatsPanel.summary_lines(d)))
	d.heir.level = 99999
	d.heir.known_feats = GameFeats.class_feats("spellblade").duplicate()
	ok(GameFeats.next_class_feat(d.heir) == "", "with every class feat known, nothing is next")


func test_class_gates() -> void:
	var m := _dyn("mage", 30, 141, "oak_staff")
	ok(GameFeats.learn(m, "cleave").begins_with("Taught only to a Warrior"), "a mage is not taught Cleave: %s" % GameFeats.learn(m, "cleave"))
	ok(GameFeats.learn(m, "arcane_strike").find("learns Arcane Strike") >= 0, "a mage is taught Arcane Strike")
	ok(GameFeats.learn(m, "feint").find("learns Feint") >= 0, "and the feats open to all")
	var w := _dyn("warrior", 30, 142, "steel_sword")
	ok(GameFeats.learn(w, "arcane_strike").begins_with("Taught only to a Mage"), "a warrior is not taught Arcane Strike: %s" % GameFeats.learn(w, "arcane_strike"))
	var p := _dyn("paladin", 30, 143, "iron_mace")
	ok(GameFeats.learn_block(p.heir, "shield_bash") == "" and GameFeats.learn_block(p.heir, "radiant_strike") == "", "a paladin may learn Shield Bash and Radiant Strike")
	ok(GameFeats.learn_block(p.heir, "smiting_blow") == "" and GameFeats.learn_block(p.heir, "spellstrike").begins_with("Taught only to a Spellblade"), "its own Smiting Blow, not a spellblade's Spellstrike")
	# Level and weapon still apply on top.
	var r := _dyn("ranger", 45, 144, "")
	ok(GameFeats.learn_block(r.heir, "called_shot").begins_with("Needs a bow"), "Called Shot needs a bow: %s" % GameFeats.learn_block(r.heir, "called_shot"))
	r.heir.equipment["weapon"] = "longbow"
	ok(GameFeats.learn_block(r.heir, "called_shot") == "", "with a bow and the level, it can be learned")
	r.heir.level = 10
	ok(GameFeats.learn_block(r.heir, "called_shot").begins_with("Needs level 40"), "the level comes first")
	ok(GameFeats.requirement_parts("smiting_blow").has("Paladin"), "the class is told among the requirements: %s" % str(GameFeats.requirement_parts("smiting_blow")))


func test_mag_and_drain() -> void:
	var d := _dyn("mage", 40, 145)
	var h := d.heir
	var sc: Dictionary = GameFeats.def("arcane_strike")["scaling"]
	var want := h.magic_power() * float(sc["mag"]) + h.attack_power() * float(sc.get("str", 0.0))
	ok(is_equal_approx(GameFeats.power(h, "arcane_strike"), want), "Arcane Strike is MAG and a little STR (%.1f vs %.1f)" % [GameFeats.power(h, "arcane_strike"), want])
	var before := GameFeats.power(h, "arcane_strike")
	h.training["mag"] = float(h.training.get("mag", 0.0)) + 50.0
	var by_mag := GameFeats.power(h, "arcane_strike") - before
	h.training["mag"] -= 50.0
	h.training["str"] = float(h.training.get("str", 0.0)) + 50.0
	var by_str := GameFeats.power(h, "arcane_strike") - before
	h.training["str"] -= 50.0
	ok(by_mag > 0.0 and by_str > 0.0 and by_mag > by_str * 3.0, "MAG raises it far more than STR (%.1f vs %.1f)" % [by_mag, by_str])
	ok(GameFeats.scaling_text("arcane_strike") == "STR x0.2, MAG x0.8", "MAG is told: %s" % GameFeats.scaling_text("arcane_strike"))
	ok(GameFeats.describe("life_leech").find("drains 50%") >= 0, "drain is told: %s" % GameFeats.describe("life_leech"))
	# A hurt necromancer drinks back what Life Leech deals.
	var n := _dyn("necromancer", 20, 146)
	_ready_feats(n, ["life_leech"])
	var b := _battle(n, 1, "goblin")
	_sturdy(b)
	n.heir.hp = int(n.heir.max_hp() * 0.3)
	var hp := n.heir.hp
	b.use_feat(0, 0)
	var dealt: int = b.events.filter(func(ev): return ev["type"] == "damage" and ev["side"] == "enemy").reduce(func(t, ev): return t + int(ev.get("amount", 0)), 0)
	ok(dealt > 0 and n.heir.hp > hp, "Life Leech heals the necromancer (%d -> %d after %d dealt)" % [hp, n.heir.hp, dealt])
	n.battle = null


func test_class_companions() -> void:
	for cid in _base_classes():
		for lv in [10, 60, 300]:
			var u := GameHeir.new()
			u.class_id = cid
			u.race_id = "human"
			u.level = lv
			u.gen = 1
			GameFeats.ready_companion(u, ["plains", "forest"], 3)
			for id in u.equipped_feats:
				ok(GameFeats.class_may(cid, id), "a %s hireling readies only what its class is taught (%s)" % [cid, id])
				ok((GameFeats.requires(id).get("weapon", []) as Array).is_empty(), "a %s hireling takes no feat that asks for a weapon (%s)" % [cid, id])
			if lv >= 60 and cid != "ranger":
				ok(u.equipped_feats.any(func(id): return id in GameFeats.class_feats(cid)), "a %s hireling at level %d carries its class's craft: %s" % [cid, lv, str(u.equipped_feats)])


## Three generations of the autopilot for each base class: every heir learns feats, and only ones
## their own class is taught (hybrid heirs born of a marriage included).
func test_class_bot_lives() -> void:
	var learned := {}
	for k in _base_classes().size():
		var cid: String = _base_classes()[k]
		var d := GameDynasty.new_game(300 + k, "", cid, "faetouched", "human")
		var bad: Array = []
		var guard := 0
		while d.gen <= 3 and d.state != "ended" and guard < 3000:
			guard += 1
			if d.state == "succession":
				d.choose_heir(0)
				continue
			if d.state != "life":
				break
			GameBot.step(d)
			if d.state == "life":
				for id in d.heir.known_feats:
					if not GameFeats.class_may(d.heir.class_id, id):
						bad.append("%s/%s" % [d.heir.class_id, id])
				if d.heir.class_id == cid and not d.heir.known_feats.is_empty():
					var seen: Array = learned.get(cid, [])
					for id in d.heir.known_feats:
						if id not in seen:
							seen.append(id)
					learned[cid] = seen
		ok(bad.is_empty(), "%s house: every known feat is one the heir's class is taught: %s" % [cid, str(bad)])
		ok(d.gen > 1, "%s house: generations pass (%d)" % [cid, d.gen])
		ok(learned.has(cid), "%s house: a %s heir learns feats: %s" % [cid, cid, str(learned.get(cid, []))])
		if learned.has(cid):
			ok((learned[cid] as Array).any(func(id): return id in GameFeats.class_feats(cid)), "%s house: among them its class's own: %s" % [cid, str(learned[cid])])
	# The same seed learns the same feats.
	var runs: Array = []
	for r in 2:
		var d := GameDynasty.new_game(333, "", "necromancer", "faetouched", "human")
		for i in 250:
			if d.state == "succession":
				d.choose_heir(0)
			elif d.state == "life":
				GameBot.step(d)
		runs.append([d.heir.known_feats.duplicate(), d.heir.equipped_feats.duplicate(), d.heir.feat_points])
	ok(runs[0] == runs[1] and not (runs[0][0] as Array).is_empty(), "the same seed learns the same feats: %s" % str(runs[0]))


## Saves from before feats were bound to classes: what the heir's class is not taught is forgotten
## and refunded, and the journal tells it once.
func test_class_migration() -> void:
	var d := _dyn("mage", 30, 147)
	var raw: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	raw["heir"]["known_feats"] = ["cleave", "charge", "flurry"]
	raw["heir"]["equipped_feats"] = ["cleave", "charge", "flurry"]
	raw["heir"]["feat_points"] = 1
	var e := GameDynasty.from_dict(raw)
	var h := e.heir
	ok(h.known_feats == ["charge"] and h.equipped_feats == ["charge"], "a mage keeps only Charge of Cleave, Charge and Flurry: %s" % str(h.known_feats))
	ok(h.feat_points == 1 + GameFeats.cost("cleave") + GameFeats.cost("flurry"), "Cleave's and Flurry's points come back (%d)" % h.feat_points)
	var msgs: Array = []
	GameFeats.on_years(e, msgs)
	var want := "With the old drills set aside, %s forgets Cleave and Flurry, which no Mage is taught (2 feat points back)." % h.name
	ok(msgs.size() >= 1 and msgs[0] == want and e.journal.has(want), "the journal tells it: %s" % str(msgs))
	msgs = []
	GameFeats.on_years(e, msgs)
	ok(not msgs.any(func(l): return str(l).find("old drills") >= 0), "once")
	ok(JSON.stringify(GameDynasty.from_dict(JSON.parse_string(JSON.stringify(e.to_dict()))).to_dict()) == JSON.stringify(e.to_dict()), "the migrated save round-trips")
	# A warrior's old save keeps what a warrior is taught.
	var w := _dyn("warrior", 30, 148, "steel_sword")
	var wr: Dictionary = JSON.parse_string(JSON.stringify(w.to_dict()))
	wr["heir"]["known_feats"] = ["cleave", "charge"]
	wr["heir"]["equipped_feats"] = ["cleave"]
	var x := GameDynasty.from_dict(wr)
	ok(x.heir.known_feats == ["cleave", "charge"] and x.heir.equipped_feats == ["cleave"] and x.heir.feat_points == int(wr["heir"]["feat_points"]) and not x.heir.has_meta("feat_forgot"), "a warrior keeps Cleave")
	# A hybrid keeps its parents' feats.
	var s := _dyn("spellblade", 30, 149)
	var sr: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	sr["heir"]["known_feats"] = ["cleave", "arcane_strike", "spellstrike", "flurry"]
	var y := GameDynasty.from_dict(sr)
	ok(y.heir.known_feats == ["cleave", "arcane_strike", "spellstrike"], "a spellblade keeps the Warrior's, the Mage's and its own, not Flurry: %s" % str(y.heir.known_feats))


func test_companions() -> void:
	var seen := {}
	var uses := 0
	for k in 8:
		var d := _dyn("mage", [5, 12, 40, 300][k % 4], 90 + k)
		_full_party(d)
		var b := _battle(d, 3, "goblin")
		for ai in b.allies.size():
			var a: GameHeir = b.allies[ai]
			ok(a.equipped_feats.size() <= mini(GameFeats.slots_at(a.level), int(GameFeats.setting("companion_slots"))), "%s carries no more feats than its slots" % a.name)
			for id in a.equipped_feats:
				seen[id] = true
				ok(GameFeats.requirement_block(a, id) == "", "%s meets what %s asks" % [a.name, id])
				ok((GameFeats.requires(id).get("weapon", []) as Array).is_empty(), "%s takes no feat that needs a weapon (%s)" % [a.name, id])
				ok(GameFeats.def(id).get("companion", true), "%s never readies %s" % [a.name, id])
				ok(float(GameFeats.def(id)["mult"]) > 0.0, "%s's feats are blows, not calls to the party (%s)" % [a.name, id])
		var guard := 0
		while not b.is_over() and guard < 200:
			guard += 1
			GameTactics.act(b, GameTactics.choose(b, -1))
			for ai in b.allies.size():
				uses += _feat_casts(b, ai).size()
		d.battle = null
	ok(not seen.is_empty(), "companions carry feats: %s" % str(seen.keys()))
	ok(uses > 0, "and use them (%d times)" % uses)
	ok("taunt" not in seen and "rally" not in seen, "no hireling taunts or rallies")
	# A loadout is worked out once for each make of companion and ground, and the same afresh.
	for spec in [["bren_cask", 47, ["plains"]], ["grull_one_tusk", 300, ["mountains"]], ["maddy_thorn", 5, ["swamp"]]]:
		var u := GameParty.build_unit(spec[0], spec[1], 1)
		GameFeats.ready_companion(u, spec[2], 3)
		var kept: Array = u.equipped_feats.duplicate()
		GameFeats.reindex()
		var fresh := GameParty.build_unit(spec[0], spec[1], 1)
		GameFeats.ready_companion(fresh, spec[2], 3)
		ok(fresh.equipped_feats == kept and kept == GameFeats.ranked(fresh, spec[2], 3, true, false).slice(0, kept.size()), "%s at level %d carries the same feats worked out again: %s" % [spec[0], spec[1], str(kept)])
	# What they carry is never saved.
	var d := _dyn("warrior", 40, 99)
	_full_party(d)
	_battle(d, 2, "goblin")
	GameBot.fight(d)
	ok(JSON.stringify(d.party.to_dict()).find("feat") < 0, "companions' loadouts are not saved")


## A companion with nothing else to weigh keeps to the simple way of fighting: its feat when it
## lands harder than its other blows, else the class strike or a plain blow, never waking a sleeper.
func test_companion_choices() -> void:
	var d := _dyn("mage", 40, 98)
	d.world.visit("highcrag")
	_full_party(d, ["bren_cask"])
	var b := _battle(d, 3, "goblin")
	_sturdy(b)
	var bren: GameHeir = b.allies[0]
	bren.tree_ranks = {}   # the weighing below is about feats, not what Bren's skill tree adds
	GameSkillTree.changed(bren)
	ok(not bren.equipped_feats.is_empty(), "Bren carries feats: %s" % str(bren.equipped_feats))
	bren.known_feats = ["rockslide"]
	bren.equipped_feats = ["rockslide"]
	b._nums.erase(0)
	b.focus = 1
	var plan := GameTactics.choose(b, 0)
	var caught := b.aoe_targets(GameFeats.def("rockslide"), 0, 1)
	ok(str(plan.get("feat", "")) == "rockslide" and caught.size() == 3, "Rockslide on the heir's target catches all three, so Bren uses it: %s" % str(plan.get("ab", {}).get("name", plan["act"])))
	var strike := b.estimate(0, bren.cls()["skills"][0], 1)
	ok(b.estimate(0, GameFeats.def("rockslide"), 1) > strike, "it lands harder than his class strike")
	b._spend_feat(0, "rockslide")
	plan = GameTactics.choose(b, 0)
	ok(str(plan.get("feat", "")) == "" and plan["act"] != "wait", "cooling, it gives way to a class strike or a blow")
	b.feat_ready.clear()
	b.apply_status(GameBattle.enemy_ref(0), "sleep", 1.0, 2, "heir")
	plan = GameTactics.choose(b, 0)
	ok(str(plan.get("feat", "")) == "" or int(plan.get("target", -1)) != 0, "Bren will not aim the slope at a sleeping foe")
	b.remove_status(GameBattle.enemy_ref(0), "sleep")
	# Execute is kept for a foe that is already staggering.
	bren.known_feats = ["execute"]
	bren.equipped_feats = ["execute"]
	b._nums.erase(0)
	b.immune.clear()
	ok(str(GameTactics.choose(b, 0).get("feat", "")) == "", "Bren keeps Execute while the foe is fresh")
	b.enemies[1]["hp"] = int(float(b.enemies[1]["max_hp"]) * 0.2)
	ok(str(GameTactics.choose(b, 0).get("feat", "")) == "execute", "and uses it on a staggering one")
	d.battle = null


# ---------------------------------------------------------------- tactics

func test_tactics() -> void:
	# A free area that catches the whole front rank is used against a pack.
	var d := _dyn("warrior", 30, 101, "steel_sword")
	_ready_feats(d, ["cleave"])
	var b := _battle(d, 3, "goblin")
	for e in b.enemies:
		e["hp"] = 5000
		e["max_hp"] = 5000
	d.heir.mp = 0
	var plan := GameTactics.choose(b, -1)
	ok(str(plan.get("feat", "")) == "cleave" and b.aoe_targets(GameFeats.def("cleave"), -1, int(plan["target"])).size() == 3, "out of MP against three, the autopilot cleaves all three: %s" % str(plan))
	GameTactics.act(b, plan)
	ok(b.feat_wait(-1, "cleave") > 0, "and the feat is used through the battle's own action")
	ok(str(GameTactics.choose(b, -1).get("feat", "")) == "", "a cooling feat is not chosen")
	d.battle = null
	# Execute waits for a wounded foe.
	_ready_feats(d, ["execute"])
	var b2 := _battle(d, 1, "goblin")
	b2.enemies[0]["hp"] = 100000
	b2.enemies[0]["max_hp"] = 100000
	ok(str(GameTactics.choose(b2, -1).get("feat", "")) != "execute", "Execute is kept for later on a fresh foe")
	b2.enemies[0]["hp"] = 20000
	d.heir.mp = 0
	ok(str(GameTactics.choose(b2, -1).get("feat", "")) == "execute", "and used on a staggering one")
	d.battle = null
	# A feat paid in HP is weighed with its price: not when the heir is low.
	_ready_feats(d, ["whirlwind"])
	var b3 := _battle(d, 3, "goblin")
	for e in b3.enemies:
		e["hp"] = 5000
		e["max_hp"] = 5000
	d.heir.mp = 0
	d.heir.potions = 0
	ok(str(GameTactics.choose(b3, -1).get("feat", "")) == "whirlwind", "Whirlwind against three at full health")
	var opts := GameTactics.options(b3, -1)
	ok(opts.any(func(o): return str(o.get("feat", "")) == "whirlwind" and int(o["hp"]) == GameFeats.hp_cost(d.heir, "whirlwind")), "the option carries its HP price")
	d.heir.hp = GameFeats.hp_cost(d.heir, "whirlwind")
	ok(GameTactics.options(b3, -1).all(func(o): return str(o.get("feat", "")) != "whirlwind"), "too hurt to pay, it is not an option")
	d.battle = null


func test_bot() -> void:
	# In a town the autopilot learns feats that suit how it fights.
	var styles := {"warrior": "steel_sword", "rogue": "steel_sword", "ranger": "longbow", "mage": "oak_staff"}
	for cls in styles:
		var d := _dyn(cls, 30, 111, styles[cls])
		GameFeats.bot_tick(d)
		var h := d.heir
		var once := JSON.stringify(h.to_dict())
		GameFeats.bot_tick(d)
		h.remove_meta("feat_bot")
		GameFeats.bot_tick(d)
		ok(JSON.stringify(h.to_dict()) == once, "%s: a second look, remembered or afresh, changes nothing" % cls)
		ok(h.equipped_feats.size() <= GameFeats.slots(h) and h.equipped_feats.all(func(id): return id in h.known_feats), "%s: readied feats are known and fit the slots" % cls)
		ok(h.feat_points >= 0 and h.feat_points == GameFeats.points_at(h.level) - h.known_feats.reduce(func(t, id): return t + GameFeats.cost(id), 0), "%s: points spent add up" % cls)
		var dmg := h.equipped_feats.filter(func(id): return float(GameFeats.def(id)["mult"]) > 0.0)
		match cls:
			"warrior":
				ok(dmg.size() >= 2 and dmg.all(func(id): return float(GameFeats.def(id)["scaling"].get("str", 0.0)) >= float(GameFeats.def(id)["scaling"].get("agi", 0.0))), "the warrior readies STR feats: %s" % str(h.equipped_feats))
			"rogue":
				ok(dmg.any(func(id): return float(GameFeats.def(id)["scaling"].get("agi", 0.0)) > float(GameFeats.def(id)["scaling"].get("str", 0.0))), "the rogue readies an AGI feat: %s" % str(h.equipped_feats))
			"ranger":
				ok("aimed_shot" in h.equipped_feats, "the ranger with a bow readies Aimed Shot: %s" % str(h.equipped_feats))
			"mage":
				ok(not dmg.is_empty() and dmg.all(func(id): return float(GameFeats.def(id)["scaling"].get("mag", 0.0)) > float(GameFeats.def(id)["scaling"].get("str", 0.0)) + float(GameFeats.def(id)["scaling"].get("agi", 0.0))),
					"the mage readies spellwork, not weapon work: %s" % str(h.equipped_feats))
		# Nothing changes where loadouts may not change.
		d.world.visit("whisperwood")
		d.heir.level += 30
		var before := JSON.stringify(h.to_dict())
		GameFeats.bot_tick(d)
		ok(JSON.stringify(h.to_dict()) == before, "%s: the autopilot keeps its loadout in the wilds" % cls)
	# Whole lives: feats learned and used, never an unusable one, the books always balanced.
	var used := 0
	var bad := 0
	for k in 4:
		var d := GameDynasty.new_game(120 + k, "", ["warrior", "rogue", "ranger", "monk"][k], "faetouched", "human")
		d.pending_event = {}
		var guard := 0
		while d.state == "life" and guard < 1200:
			guard += 1
			if d.battle == null and d.heir.age >= d.heir.lifespan * 0.9 and d.can_retire():
				d.retire()
				break
			if d.has_pending_event():
				GameEvents.bot_resolve(d)
				continue
			var h := d.heir
			GameItems.bot_tick(d)
			GameQuests.bot_tick(d)
			GameParty.bot_tick(d)
			GameFeats.bot_tick(d)
			if float(h.hp) / float(h.max_hp()) < 0.55:
				d.rest()
				continue
			d.start_hunt("hunt")
			var b := d.battle
			var g2 := 0
			while not b.is_over() and g2 < 300:
				g2 += 1
				var plan := GameTactics.choose(b, -1)
				if str(plan.get("feat", "")) != "":
					if b.feat_block(-1, str(plan["feat"])) != "":
						bad += 1
					used += 1
				GameTactics.act(b, plan)
			d.finish_battle()
			if d.state == "life":
				ok(h.equipped_feats.size() <= GameFeats.slots(h) and h.feat_points >= 0, "loadout and points stay sound")
		ok(not d.heir.known_feats.is_empty(), "%s learned feats over a life: %s" % [d.heir.cls()["name"], str(d.heir.known_feats)])
	ok(used > 20 and bad == 0, "the autopilot uses its feats (%d times) and never one it cannot (%d)" % [used, bad])


# ---------------------------------------------------------------- save / load

func test_save_load() -> void:
	var d := _dyn("warrior", 30, 131, "steel_sword")
	GameFeats.learn(d, "cleave")
	GameFeats.learn(d, "charge")
	GameFeats.unequip(d, "charge")
	d.world.visit("whisperwood")
	d.rest()
	d.heir.feat_news = [43, 50]
	var j := JSON.stringify(d.to_dict())
	var e := GameDynasty.from_dict(JSON.parse_string(j))
	var h := e.heir
	ok(h.known_feats == ["cleave", "charge"] and h.equipped_feats == ["cleave"], "the loadout survives a save: %s %s" % [str(h.known_feats), str(h.equipped_feats)])
	ok(h.feat_points == d.heir.feat_points and typeof(h.feat_points) == TYPE_INT and h.feat_level == d.heir.feat_level, "points and the milestone mark too")
	ok(h.feat_news == [43, 50] and typeof(h.feat_news[0]) == TYPE_INT, "untold milestones stay whole numbers")
	ok(h.downtime, "the quiet after a rest survives a save")
	ok(JSON.stringify(e.to_dict()) == j, "a second round trip is identical")
	# A save edited by hand or from other data: unknown ids, doubles, too many readied.
	var raw: Dictionary = JSON.parse_string(j)
	raw["heir"]["known_feats"] = ["cleave", "gone_feat", "cleave", "charge", "feint", "flurry", "rally"]
	raw["heir"]["equipped_feats"] = ["gone_feat", "cleave", "cleave", "charge", "feint", "flurry", "rally", "hamstring"]
	var f := GameDynasty.from_dict(raw)
	ok(f.heir.known_feats == ["cleave", "charge", "feint", "rally"], "unknown, doubled and other classes' feats are dropped: %s" % str(f.heir.known_feats))
	ok(f.heir.feat_points == int(raw["heir"]["feat_points"]) + GameFeats.cost("flurry"), "a warrior's old Flurry is refunded (%d)" % f.heir.feat_points)
	ok(f.heir.equipped_feats.size() == GameFeats.slots(f.heir) and f.heir.equipped_feats.all(func(id): return id in f.heir.known_feats), "only known feats are readied, no more than the slots: %s" % str(f.heir.equipped_feats))
	# Readied feats the heir's level no longer allows (the data changed) stay known, set aside.
	raw["heir"]["known_feats"] = ["earthshaker", "shield_bash", "cleave"]
	raw["heir"]["equipped_feats"] = ["earthshaker", "shield_bash", "cleave"]
	var m := GameDynasty.from_dict(raw)
	ok(m.heir.known_feats == ["earthshaker", "shield_bash", "cleave"] and m.heir.equipped_feats == ["shield_bash", "cleave"], "a readied feat beyond the heir's level is set aside on load: %s" % str(m.heir.equipped_feats))
	ok(m.heir.feat_points == int(raw["heir"]["feat_points"]) and not m.heir.has_meta("feat_forgot"), "a feat beyond the level is never refunded")
	# A save from before feats.
	var old: Dictionary = JSON.parse_string(j)
	for key in ["known_feats", "equipped_feats", "feat_points", "feat_level", "feat_news", "downtime"]:
		old["heir"].erase(key)
	var g := GameDynasty.from_dict(old)
	ok(g.heir.feat_points == GameFeats.points_at(g.heir.level) and g.heir.known_feats.is_empty() and g.heir.feat_level == g.heir.level, "an old save gets the points of the heir's level (%d)" % g.heir.feat_points)
	ok(g.heir.feat_news.is_empty(), "and no flood of old milestones")
	var j2 := JSON.stringify(g.to_dict())
	ok(JSON.stringify(GameDynasty.from_dict(JSON.parse_string(j2)).to_dict()) == j2, "the old save round-trips once loaded")


func test_old_saves() -> void:
	for tag in ["pr3_life", "pr3_succession", "pr4_life", "pr4_succession", "party_preaging"]:
		var txt := FileAccess.get_file_as_string(FIXTURES + "old_save_%s.json" % tag)
		if txt == "":
			ok(false, "fixture %s exists" % tag)
			continue
		var raw: Dictionary = JSON.parse_string(txt)
		var d := GameDynasty.from_dict(raw)
		ok(d.heir.feat_points == GameFeats.points_at(d.heir.level) and d.heir.known_feats.is_empty(), "%s: the heir has the points of level %d" % [tag, d.heir.level])
		if d.state == "succession":
			d.choose_heir(0)
		ok(d.heir.feat_points == GameFeats.points_at(d.heir.level), "%s: so does whoever leads the house next" % tag)
		for i in 200:
			if d.state == "succession":
				d.choose_heir(0)
			elif d.state == "life":
				GameBot.step(d)
		var j := JSON.stringify(d.to_dict())
		ok(JSON.stringify(GameDynasty.from_dict(JSON.parse_string(j)).to_dict()) == j, "%s: plays on with feats and round-trips" % tag)


func test_determinism() -> void:
	var runs: Array = []
	for r in 2:
		var d := GameDynasty.new_game(4242, "", "warrior", "faetouched", "human")
		for i in 400:
			if d.state == "succession":
				d.choose_heir(0)
			elif d.state == "life":
				GameBot.step(d)
		runs.append([d.journal.duplicate(), JSON.stringify(d.to_dict())])
	ok(runs[0][0] == runs[1][0] and runs[0][1] == runs[1][1], "the same seed tells the same story with feats (%d journal lines)" % (runs[0][0] as Array).size())
	ok((runs[0][0] as Array).any(func(l): return str(l).find("feat point") >= 0 or str(l).find(" learns ") >= 0), "feats are part of that story")
	# A loaded copy plays on exactly like the original.
	var a := GameDynasty.new_game(777, "", "rogue", "faetouched", "human")
	for i in 60:
		GameBot.step(a)
	if a.state == "life":
		var b := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
		for i in 80:
			for x in [a, b]:
				if x.state == "succession":
					x.choose_heir(0)
				elif x.state == "life":
					GameBot.step(x)
		ok(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()), "a loaded copy plays on like the original")


# ---------------------------------------------------------------- auto-battle

func test_auto_battle() -> void:
	# Each auto turn is the autopilot's own choice, carried out the same way.
	var pair: Array = []
	for k in 2:
		var d := _dyn("warrior", 30, 515, "steel_sword")
		_ready_feats(d, ["cleave", "charge", "rend"])
		_full_party(d, ["bren_cask"])
		pair.append(_battle(d, 3, "goblin", 1.4))
	var a: GameBattle = pair[0]
	var c: GameBattle = pair[1]
	var turns := 0
	var feats_used := 0
	while not a.is_over() and turns < 80:
		turns += 1
		var plan := GameTactics.choose(c, -1)
		GameTactics.act(c, plan)
		var done := GameTactics.auto_turn(a)
		ok(str(done.get("act")) == str(plan.get("act")) and str(done.get("feat", "")) == str(plan.get("feat", "")), "auto turn %d takes the tactics choice: %s" % [turns, str(done.get("act"))])
		feats_used += 1 if str(done.get("feat", "")) != "" else 0
	ok(a.is_over() and a.log == c.log and a.result == c.result, "an auto battle runs exactly as the autopilot's (%d turns, %s)" % [turns, a.result])
	ok(feats_used > 0, "and uses feats on its own (%d)" % feats_used)
	# A plan the battle turns down still takes the turn as a plain blow.
	var d2 := _dyn("warrior", 30, 516, "steel_sword")
	var b2 := _battle(d2, 2)
	_sturdy(b2)
	var t0 := b2.turn
	GameTactics.act(b2, {"act": "ability", "feat": "cleave", "target": 0})
	ok(b2.turn == t0, "an unreadied feat is turned down by the battle")
	# Only hunts begin on their own; the switch is saved with the game, off in older saves.
	var d := _dyn("warrior", 10, 517)
	ok(not d.auto_battle, "auto-battle starts off")
	_battle(d, 1)
	ok(not GameTactics.auto_from_start(d), "and a hunt is then the player's to fight")
	d.battle = null
	d.auto_battle = true
	for kind in ["hunt", "hunt_hard", "legend", "event"]:
		d._begin_battle([d._make_enemy(GameCombat.creature_def("goblin"), 1.0, 1.0, 10)], kind)
		ok(GameTactics.auto_from_start(d) == (kind in ["hunt", "hunt_hard"]), "a %s battle %s on its own" % [kind, "begins" if kind.begins_with("hunt") else "does not begin"])
		d.battle = null
	var raw: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	ok(GameDynasty.from_dict(raw).auto_battle, "the switch survives a save")
	raw.erase("auto_battle")
	ok(not GameDynasty.from_dict(raw).auto_battle, "an older save loads with it off")


## A heir who lost the turn and presses a feat only lets the turn pass: the feat is not spent. And
## every action that takes time ends the quiet after a rest, working and exploring included.
func test_lost_turn_and_quiet() -> void:
	var d := _dyn("warrior", 20, 518, "steel_sword")
	_ready_feats(d, ["cleave", "flurry"])
	var b := _battle(d, 3)
	_sturdy(b)
	b.heir_skip = true
	var t := b.turn
	b.use_feat(0, 0)
	ok(b.turn == t + 1 and not b.heir_skip, "a lost turn passes when a feat is pressed")
	ok(b.feat_wait(-1, "cleave") == 0 and b.feat_wait(-1, "flurry") == 0 and _feat_casts(b).is_empty(), "and the feat is neither used nor cooling")
	d.battle = null
	var r := _dyn("rogue", 15, 519, "iron_sword")
	r.world.visit("whisperwood")
	for what in ["work", "explore"]:
		r.rest()
		ok(r.heir.downtime and GameFeats.manage_block(r) == "", "rested in the wilds before %s" % what)
		if what == "work":
			r.work()
		else:
			r.explore()
		ok(r.state != "life" or (not r.heir.downtime and GameFeats.manage_block(r) != ""), "%s ends the quiet" % what)
		if not r.pending_event.is_empty():
			r.resolve_event(0)


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


func _buttons(n: Node, prefix: String, out: Array = []) -> Array:
	if n is Button and (n as Button).is_visible_in_tree() and (n as Button).text.begins_with(prefix):
		out.append(n)
	for c in n.get_children():
		_buttons(c, prefix, out)
	return out


func _labels_text(n: Node, out: Array = []) -> Array:
	if n is Label and (n as Label).is_visible_in_tree():
		out.append((n as Label).text)
	for c in n.get_children():
		_labels_text(c, out)
	return out


func _wait_idle(view: Control) -> void:
	for k in 60:
		if not view.busy:
			return
		await create_timer(0.1).timeout


func _auto_ui(app: Node, d: GameDynasty) -> void:
	d.battle = null
	d.auto_battle = false
	d.heir.full_heal()
	app.show_state()
	await _frames(4)
	var toggle := _button(app.current, "Auto-battle: OFF")
	ok(toggle != null, "the life screen shows auto-battle off")
	toggle.pressed.emit()
	await _frames(3)
	ok(d.auto_battle and _button(app.current, "Auto-battle: ON") != null, "pressing it switches it on and says so")
	ok(GameDynasty.load_from_disk().auto_battle, "and the game is saved with it")
	_button(app.current, "Hunt").pressed.emit()
	await _frames(4)
	var view: Control = app.current
	ok(d.battle != null and view.auto and _button(view, "Auto-battle: ON") != null, "a hunt begins with auto-battle on")
	ok(_button(view, "Attack") == null and _button(view, "Take over") != null, "the heir's commands give way to a Take over button")
	for e in d.battle.enemies:
		e["hp"] = 100000
		e["max_hp"] = 100000
		e["atk"] = 0.0
	await create_timer(2.5).timeout
	var t1: int = d.battle.turn
	ok(t1 >= 2, "the heir fights turn after turn unprompted (%d turns in 2.5 s)" % t1)
	ok(t1 <= 8, "at a pace that can be followed")
	_button(view, "Auto-battle: ON").pressed.emit()
	await _wait_idle(view)
	await _frames(3)
	var t2: int = d.battle.turn
	ok(not view.auto and not d.auto_battle and _button(view, "Auto-battle: OFF") != null, "switching it off mid-battle shows it off")
	ok(_button(view, "Attack") != null, "and hands the commands back at once")
	await create_timer(1.2).timeout
	ok(d.battle.turn == t2, "no turn is taken for the player once it is off")
	_button(view, "Attack").pressed.emit()
	await _wait_idle(view)
	ok(d.battle.turn == t2 + 1, "the player's own command plays")
	_button(view, "Auto-battle: OFF").pressed.emit()
	await _frames(2)
	ok(d.auto_battle, "switched on again in battle")
	for e in d.battle.enemies:
		e["hp"] = 1
	for k in 40:
		if view.result_shown:
			break
		await create_timer(0.2).timeout
	ok(view.result_shown and d.battle == null, "it fights on to the end")
	_button(view, "Continue").pressed.emit()
	await _frames(3)
	ok(_button(app.current, "Auto-battle: ON") != null, "and stays on for the hunts after")
	d.auto_battle = false


func _ui_tests() -> void:
	var real := GameDynasty.save_path
	GameDynasty.save_path = "user://test_feats_ui_save.json"
	root.size = Vector2i(1280, 720)
	var app = GameApp.new()
	root.add_child(app)
	await _frames()
	app.new_game("Tess", "warrior", "faetouched", 31, "human")
	var d: GameDynasty = app.dynasty
	d.pending_event = {}
	d.heir.level = 12
	GameFeats.sync(d.heir)
	d.heir.equipment["weapon"] = "steel_sword"
	d.heir.full_heal()
	app.show_state()
	await _frames(4)
	var open := _button(app.current, "Feats")
	ok(open != null, "the life screen has a Feats action")
	open.pressed.emit()
	await _frames(4)
	var panel: Node = app.current.get_children().back()
	ok(panel.get_script() == FeatsPanel, "it opens the Feats panel")
	var texts := _labels_text(panel)
	ok(texts.any(func(t): return t == "Feat points %d" % d.heir.feat_points) and texts.any(func(t): return t.begins_with("Readied 0 / 3")), "the panel shows points and slots: %s" % str(texts.slice(0, 4)))
	var learn := _button(panel, "Learn")
	ok(learn != null, "a feat can be learned in town")
	var pts := d.heir.feat_points
	learn.pressed.emit()
	await _frames(4)
	ok(d.heir.known_feats.size() == 1 and d.heir.feat_points < pts, "pressing Learn learns it: %s" % str(d.heir.known_feats))
	ok(_button(panel, "Set aside") != null, "a readied feat can be set aside")
	ok(_buttons(panel, "Learn").any(func(b): return b.disabled), "feats out of reach show a disabled Learn")
	_button(panel, "Close").pressed.emit()
	await _frames(4)
	ok(app.current.get_children().all(func(c): return c.get_script() != FeatsPanel), "Close shuts the panel")
	# The wilds: every control disabled, the reason shown.
	d.world.visit("whisperwood")
	app.show_state()
	await _frames(4)
	_button(app.current, "Feats").pressed.emit()
	await _frames(4)
	panel = app.current.get_children().back()
	var why := GameFeats.manage_block(d)
	ok(_labels_text(panel).has(why), "outside a town the panel says why: %s" % why)
	var all_btns: Array = _buttons(panel, "Learn") + _buttons(panel, "Set aside") + _buttons(panel, "Ready")
	ok(not all_btns.is_empty() and all_btns.all(func(b): return b.disabled), "every Learn, Ready and Set aside is disabled there")
	var set_aside: Array = _buttons(panel, "Set aside")
	ok(not set_aside.is_empty() and set_aside.all(func(b): return b.tooltip_text == why), "a readied feat's button gives the place as the reason")
	ok(_buttons(panel, "Learn").filter(func(b): return b.tooltip_text == why).size() >= 3, "and so do the feats that could be learned in a town")
	_button(panel, "Close").pressed.emit()
	await _frames(2)
	# Battle: the Feats command, the list with cooldowns, aiming an area.
	d.world.visit("hearthmere")
	d.heir.level = 30
	GameFeats.sync(d.heir)
	d.heir.known_feats = ["cleave", "whirlwind", "charge"]
	d.heir.equipped_feats = ["cleave", "whirlwind", "charge"]
	d.heir.full_heal()
	var foes: Array = []
	for i in 5:
		foes.append(d._make_enemy(GameCombat.creature_def("goblin"), 1.0, 1.0, 30))
	d._begin_battle(foes, "hunt")
	for e in d.battle.enemies:
		e["hp"] = 100000
		e["max_hp"] = 100000
		e["atk"] = 0.0
	app.show_state()
	await _frames(6)
	var view: Control = app.current
	var fb := _button(view, "Feats (3 ready)")
	ok(fb != null, "a Feats command with what is ready")
	fb.pressed.emit()
	await _frames(3)
	ok(view.feat_list != null, "the feat list opens")
	var list_rect: Rect2 = view.feat_list.get_global_rect()
	ok(d.battle.living_enemies().all(func(i): return not list_rect.intersects(view.enemy_nodes[i]["body"].get_global_rect())), "the list leaves every foe in sight: %s" % str(list_rect))
	ok(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(list_rect), "and fits the window")
	fb.pressed.emit()
	await _frames(2)
	ok(view.feat_list == null, "the Feats command closes it again")
	fb.pressed.emit()
	await _frames(2)
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	view._unhandled_input(esc)
	await _frames(2)
	ok(view.feat_list == null, "and so does Escape")
	fb.pressed.emit()
	await _frames(3)
	var cleave := _button(view.feat_list, "Cleave")
	ok(cleave != null and _labels_text(view.feat_list).has("Ready"), "readied feats are listed as ready")
	cleave.mouse_entered.emit()
	await _frames(2)
	var marked: int = view.enemy_nodes.filter(func(en): return en["mark"].visible).size()
	ok(marked == d.battle.aoe_targets(GameFeats.def("cleave"), -1, view.target).size() and marked >= 2, "hovering Cleave outlines the foes it would catch (%d)" % marked)
	cleave.mouse_exited.emit()
	cleave.pressed.emit()
	await _frames(3)
	ok(not view.aiming.is_empty() and int(view.aiming["feat"]) == 0 and view.feat_list == null, "choosing an area feat starts aiming")
	_button(view, "Use").pressed.emit()
	for k in 60:
		if not view.busy:
			break
		await create_timer(0.2).timeout
	ok(d.battle.log.any(func(l): return str(l) == "Tess uses Cleave."), "Use strikes with it")
	var still := 2 if int(GameFeats.setting("recovery_turns")) == 0 else 0
	ok(_button(view, "Feats (%d ready)" % still, false) != null, "the command counts what is still ready (%d)" % still)
	_button(view, "Feats").pressed.emit()
	await _frames(3)
	var cooling := _button(view.feat_list, "Cleave", false)
	ok(cooling != null and cooling.disabled and _labels_text(view.feat_list).any(func(t): return t.begins_with("Ready in")), "a cooling feat is listed with its wait")
	if still == 0:
		ok(_labels_text(view.feat_list).any(func(t): return t.begins_with("Catching breath")), "the others wait for the heir's breath")
		view._close_feats()
		_button(view, "Defend").pressed.emit()
		for k in 60:
			if not view.busy:
				break
			await create_timer(0.2).timeout
		_button(view, "Feats").pressed.emit()
		await _frames(3)
	# Whirlwind is drawn around the heir, whichever foe is hovered.
	var spin := _button(view.feat_list, "Whirlwind")
	ok(spin != null, "Whirlwind is ready")
	spin.pressed.emit()
	await _frames(3)
	ok(view.shown.get("ab", {}).get("id", "") == "whirlwind", "aiming Whirlwind shows its area")
	var first: Array = view.enemy_nodes.map(func(en): return en["mark"].visible)
	view._on_foe_hover(4, true)
	await _frames(2)
	ok(view.enemy_nodes.map(func(en): return en["mark"].visible) == first, "the area stays around the heir whatever is hovered")
	ok(view.aim_info.text.begins_with("Around Tess"), "and says so: %s" % view.aim_info.text)
	view._cancel_aim()
	await _frames(2)
	await _auto_ui(app, d)
	app.queue_free()
	GameDynasty.save_path = real
	_done()
