## Class skills by level and class styles: the data (5-7 skills a class, the old ids in their old
## places, no two classes alike), unlock gates for the heir and for companions, once-a-battle
## skills, the journal's news of new skills (and old saves), every skill running as its data says,
## the tactics' worth of the new blessings and the guard floor, and auto-battle fighting each
## class's way: casters cast, fighters swing and use feats, hybrids do both. Deterministic.
## Run: godot --headless --path . -s res://tests/test_game_skills.gd
extends SceneTree

var fails := 0
var checks := 0

## Skill ids that saves and plans index by, in their places since before skills opened by level.
const KEPT := {
	"warrior": ["power_strike", "second_wind"], "mage": ["firebolt", "mend"], "rogue": ["backstab", "shadow_step"],
	"cleric": ["smite", "heal"], "ranger": ["volley", "field_dressing"], "monk": ["palm_strike", "inner_peace"],
	"necromancer": ["soul_drain", "bone_ward"], "druid": ["thornlash", "regrowth"], "spellblade": ["arcane_edge", "mana_shield"],
	"paladin": ["holy_strike", "lay_on_hands"], "duelist": ["riposte", "second_wind"], "arcane_trickster": ["phantom_blades", "blink"],
	"dread_knight": ["grave_cleave", "unholy_vigor"], "warlock": ["hex_bolt", "siphon_life", "dark_pact"],
	"shaman": ["storm_call", "spirit_mend"], "beastmaster": ["pack_hunt", "wild_remedy"], "ninja": ["shadow_flurry", "smoke_veil"],
	"templar": ["judgement_palm", "sanctuary"], "warden": ["hunters_cleave", "bulwark_breath"],
}
## A weapon that suits each class in the style fights (bare hands for the monk and the rest).
const WEAPON := {"warrior": "iron_sword", "rogue": "iron_sword", "ranger": "hunting_bow", "mage": "oak_staff",
	"necromancer": "oak_staff", "druid": "oak_staff", "cleric": "iron_mace", "duelist": "iron_sword",
	"ninja": "iron_sword", "spellblade": "iron_sword", "paladin": "iron_mace", "warlock": "oak_staff"}
const OFFENSIVE := ["attack", "spell", "magic_skill", "weapon_skill", "both_skill", "feat_magic", "feat_weapon", "support"]


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	GameData.load_all()
	test_data()
	test_unlocks()
	test_once_a_battle()
	test_companions_gated()
	test_news()
	test_every_skill_runs()
	test_blessing_values()
	test_guard_floor()
	test_styles()
	test_class_mix()
	test_caster_dry_and_potions()
	test_areas_on_packs()
	test_determinism()
	test_tends_allies()
	test_undead()
	test_stealth()
	test_openers()
	test_every_skill_gets_used()
	print("skills tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(cls: String, level: int, seed_val: int = 41) -> GameDynasty:
	var d := GameDynasty.new_game(seed_val, "Tess", cls, "faetouched", "human")
	d.pending_event = {}
	d.heir.level = level
	d.heir.spells = []
	d.heir.learn_spells()
	d.heir.full_heal()
	return d


func _battle(d: GameDynasty, n: int, creature: String = "wolf") -> GameBattle:
	var c := GameCombat.creature_def(creature)
	var foes: Array = []
	for i in n:
		foes.append(d._make_enemy(c, 1.0, 1.0, d.heir.level))
	d._begin_battle(foes, "hunt")
	return d.battle


## Foes that neither fall nor strike back nor dodge: what a skill does can be read off them.
func _sturdy(b: GameBattle) -> void:
	for e in b.enemies:
		e["hp"] = 10000000
		e["max_hp"] = 10000000
		e["atk"] = 0.0
		e["agi"] = 0


# ---------------------------------------------------------------- data

func test_data() -> void:
	var problems := GameSkills.validate()
	ok(problems.is_empty(), "class skills and styles are sound: %s" % str(problems))
	ok(GameCombat.validate().is_empty(), "the combat data, class skills included, is sound")
	for w in GameSkills.warnings():
		print("note: ", w)
	for cid in GameData.classes:
		var all: Array = GameSkills.list(cid)
		ok(all.size() >= 5 and all.size() <= 7, "%s has 5 to 7 class skills (%d)" % [cid, all.size()])
		ok(KEPT.has(cid), "%s is on the list of old skill ids" % cid)
		var kept: Array = KEPT.get(cid, [])
		for k in kept.size():
			ok(str(all[k]["id"]) == kept[k] and GameSkills.level_of(all[k]) == 1, "%s keeps %s at place %d, open from level 1" % [cid, kept[k], k])
		ok(GameSkills.first_count(cid) == kept.size(), "%s has only its old skills open at level 1" % cid)
		var st := GameSkills.style(cid)
		ok(str(st["kind"]) in GameSkills.KINDS, "%s has a style (%s)" % [cid, st["kind"]])
		var parents: Array = GameData.classes[cid].get("parents", [])
		if parents.is_empty():
			ok(all.size() == 7, "base class %s has 7 skills" % cid)
	# The style a class has with no "style" entry follows its first strike's stat.
	var keep: Dictionary = GameData.classes["mage"]["style"]
	GameData.classes["mage"].erase("style")
	ok(GameSkills.style("mage")["kind"] == "caster", "a class without a style follows its first strike: mag is a caster")
	GameData.classes["mage"]["style"] = keep
	keep = GameData.classes["paladin"]["style"]
	GameData.classes["paladin"].erase("style")
	ok(GameSkills.style("paladin")["kind"] == "hybrid", "both is a hybrid")
	GameData.classes["paladin"]["style"] = keep
	# A broken entry is caught.
	var w: Array = GameData.classes["warrior"]["skills"]
	w.append({"id": "power_strike", "name": "Twice", "type": "zap", "level": 2, "mp": 1})
	var bad := GameSkills.validate()
	w.pop_back()
	ok(bad.any(func(l): return "used twice" in l) and bad.any(func(l): return "unknown type" in l) and bad.any(func(l): return "before the skill above" in l), "a repeated id, an unknown type and an early level are caught: %s" % str(bad))
	# Texts.
	ok(GameSkills.plan_text("warrior").begins_with("Power Strike, Second Wind; later Sweeping Blow (5), Iron Stance (12)"), "plan text: %s" % GameSkills.plan_text("warrior"))
	var d := _dyn("warrior", 13)
	var lines := GameSkills.summary_lines(d.heir)
	ok(lines[0] == "Known: Power Strike, Second Wind, Sweeping Blow, Iron Stance." and lines[1] == "Next: Sundering Strike at level 28, then Crushing Blow at 60.", "life screen lines: %s" % str(lines))
	ok(GameSkills.next_unlock(d.heir) == {"name": "Sundering Strike", "level": 28}, "the next unlock")
	ok(GameSkills.between("warrior", 4, 13) == ["sweeping_blow", "iron_stance"], "skills opened between 4 and 13")
	ok(GameSkills.unlocked_ids("mage", 12) == ["firebolt", "mend", "frost_lance", "arcane_missiles"], "a level-12 mage's skills")


# ---------------------------------------------------------------- unlocks

func test_unlocks() -> void:
	var d := _dyn("warrior", 4)
	var b := _battle(d, 1)
	b.heir.mp = 1000
	var usable := range(b.skill_count()).filter(func(i): return b.can_use_skill(i)).size()
	ok(usable == 2, "a level-4 warrior can use 2 skills (%d)" % usable)
	var hp_before: int = b.enemies[0]["hp"]
	var turn := b.turn
	b.use_skill(2, 0)
	ok(b.heir.mp == 1000 and b.turn == turn and b.enemies[0]["hp"] == hp_before, "a locked skill does nothing: no MP, no turn, no harm")
	ok(GameTactics.options(b, -1).all(func(o): return int(o["skill"]) < 2), "the autopilot never weighs a locked skill")
	ok(not b.skill_unlocked(2) and b.skill_unlocked(1), "the battle tells locked from open")
	d.battle = null
	var d5 := _dyn("warrior", 5)
	var b5 := _battle(d5, 1)
	b5.heir.mp = 1000
	usable = range(b5.skill_count()).filter(func(i): return b5.can_use_skill(i)).size()
	ok(usable == 3, "a level-5 warrior can use 3 (%d)" % usable)
	_sturdy(b5)
	b5.use_skill(2, 0)
	ok(b5.events.any(func(ev): return ev["type"] == "cast" and ev["name"] == "Sweeping Blow"), "and Sweeping Blow lands")
	d5.battle = null


func test_once_a_battle() -> void:
	var d := _dyn("mage", 26)
	var b := _battle(d, 1)
	_sturdy(b)
	b.heir.mp = 1
	var i := GameSkills.unlocked_ids("mage", 26).find("arcane_focus")
	ok(i == 4 and b.can_use_skill(i), "Arcane Focus is open at 26")
	var before := b.heir.mp
	b.use_skill(i, 0)
	ok(b.heir.mp > before and b.has_status("heir", "focused"), "it draws MP and focuses the heir (%d -> %d)" % [before, b.heir.mp])
	ok(b.skill_used_up(i) and not b.can_use_skill(i), "then it is used up for this battle")
	var turn := b.turn
	var mp := b.heir.mp
	b.use_skill(i, 0)
	ok(b.turn == turn and b.heir.mp == mp, "a second use does nothing")
	ok(GameTactics.options(b, -1).all(func(o): return int(o["skill"]) != i), "and the autopilot no longer weighs it")
	d.battle = null
	var b2 := _battle(d, 1)
	ok(b2.can_use_skill(i), "a new battle gives it back")
	d.battle = null


func test_companions_gated() -> void:
	var d := _dyn("mage", 60)
	var b := _battle(d, 2)
	b.add_allies([GameParty.build_unit("bren_cask", 4, 1), GameParty.build_unit("hulda_stonebrow", 30, 1)])
	for u in b.allies:
		u.mp = u.max_mp()
	var low := GameTactics.options(b, 0).filter(func(o): return int(o["skill"]) >= 0).map(func(o): return int(o["skill"]))
	var high := GameTactics.options(b, 1).filter(func(o): return int(o["skill"]) >= 0).map(func(o): return int(o["skill"]))
	ok(low.all(func(i): return i < 2), "a level-4 companion warrior weighs only the level-1 skills: %s" % str(low))
	ok(high.has(2) and high.has(4) and not high.has(5), "a level-30 one has Sweeping Blow and Sundering Strike, not Crushing Blow: %s" % str(high))
	ok(GameTactics._plain(b.allies[0]) and not GameTactics._plain(b.allies[1]), "the young one fights the simple way, the seasoned one weighs its skills")
	d.battle = null


# ---------------------------------------------------------------- news

func test_news() -> void:
	var d := _dyn("warrior", 4)
	d.heir.skill_news = []
	d.heir.xp = 0
	var guard := 0
	while d.heir.level < 13 and guard < 100:
		guard += 1
		d.heir.gain_xp(maxi(1, d.heir.xp_to_next() - d.heir.xp))
	ok(d.heir.level == 13, "leveled 4 -> 13 (%d)" % d.heir.level)
	ok(d.heir.skill_news == ["sweeping_blow", "iron_stance"], "Sweeping Blow and Iron Stance are news: %s" % str(d.heir.skill_news))
	var msgs := d._pass_years(0.1, [])
	ok(msgs.has("Tess can now use Sweeping Blow and Iron Stance (class skills)."), "and the journal tells them: %s" % str(msgs))
	ok(d.heir.skill_news.is_empty(), "once")
	var again := d._pass_years(0.1, [])
	ok(not again.any(func(m): return "can now use" in str(m)), "and not again")
	# A single skill reads in the singular.
	d.heir.skill_news = ["sundering_strike"]
	ok(GameSkills.news_text(d.heir, d.heir.skill_news) == "Tess can now use Sundering Strike (class skill).", "one skill")
	# An old save without skill news tells once what the heir's level has already opened.
	var o := _dyn("warrior", 30)
	var raw := o.to_dict()
	(raw["heir"] as Dictionary).erase("skill_news")
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(raw)))
	ok(back.heir.skill_news == ["sweeping_blow", "iron_stance", "sundering_strike"], "an old save's heir has news of the skills its level opened: %s" % str(back.heir.skill_news))
	var told := back._pass_years(0.1, [])
	ok(told.any(func(m): return str(m) == "Tess can now use Sweeping Blow, Iron Stance and Sundering Strike (class skills)."), "told once on the first years: %s" % str(told))
	ok(not back._pass_years(0.1, []).any(func(m): return "can now use" in str(m)), "and never again")
	# A save with news keeps it; a saved level-1 child has none.
	o.heir.skill_news = ["iron_stance"]
	var kept := GameHeir.from_dict(JSON.parse_string(JSON.stringify(o.heir.to_dict())))
	ok(kept.skill_news == ["iron_stance"], "saved news survives a load")
	var child := GameHeir.from_dict(JSON.parse_string(JSON.stringify(_dyn("mage", 1).heir.to_dict())))
	ok(child.skill_news.is_empty(), "a level-1 heir has no news")


# ---------------------------------------------------------------- every skill runs

## Each class's every skill, at its own unlock level, on 1 and on 3 wolves, through use_skill with
## its statuses forced to land: damage lands, statuses stick, blessings reach who they say,
## drain heals, a field is laid, heals mend, mana flows.
func test_every_skill_runs() -> void:
	var count := 0
	for cid in GameData.classes:
		var all: Array = GameSkills.list(cid)
		for i in all.size():
			var real: Dictionary = all[i]
			var sure: Dictionary = real.duplicate(true)
			for st in sure.get("statuses", []):
				st["chance"] = 1.0
			for n in [1, 3]:
				var d := _dyn(cid, GameSkills.level_of(real), 300 + i * 7 + n)
				d.heir.gold = 99999
				d.party.members.append({"id": "sister_oriel", "name": "Oriel", "hp": 1, "mp": 0, "level": d.heir.level, "gen": 1, "due": 0.0, "battles": 0, "hired_gen": 1})
				d.party.rest(d)
				var b := _battle(d, n)
				_sturdy(b)
				all[i] = sure
				b.heir.mp = 1 if real.get("mana", false) else 100000   # a mana draw needs room to fill
				b.heir.hp = maxi(1, b.heir.max_hp() / 2)
				var hp0 := b.heir.hp
				var what := "%s %s on %d" % [cid, real["id"], n]
				ok(b.can_use_skill(i), "%s: usable at level %d" % [what, d.heir.level])
				b.use_skill(i, -1 if real.has("pct_max_hp") and not real.get("party", false) else 0)   # a single heal aimed at the heir, not at the companion
				all[i] = real
				count += 1
				ok(b.events.any(func(ev): return ev["type"] == "cast" and ev["name"] == real["name"]), what + ": cast")
				if float(real.get("mult", 0.0)) > 0.0:
					ok(b.enemies.any(func(e): return int(e["hp"]) < int(e["max_hp"])), what + ": deals damage")
				for st in real.get("statuses", []):
					var on := str(st.get("on", "target"))
					var landed: Array = b.events.filter(func(ev): return ev["type"] == "status" and ev["id"] == st["id"] and ev.get("applied", false))
					match on:
						"self":
							ok(landed.any(func(ev): return ev["ref"] == "heir"), "%s: %s on the heir" % [what, st["id"]])
						"party":
							for r in b.party_refs():
								ok(landed.any(func(ev): return ev["ref"] == r), "%s: %s on %s" % [what, st["id"], r])
						_:
							ok(landed.any(func(ev): return str(ev["ref"]).begins_with("enemy")), "%s: %s on a foe" % [what, st["id"]])
				if float(real.get("drain", 0.0)) > 0.0 or real.has("pct_max_hp"):
					ok(b.heir.hp > hp0, "%s: mends the heir (%d -> %d)" % [what, hp0, b.heir.hp])
				if real.has("field"):
					ok(not b.fields.is_empty(), what + ": lays a field")
				if real.get("mana", false):
					ok(b.events.any(func(ev): return ev["type"] == "mana" and int(ev["amount"]) > 0), what + ": draws MP")
				d.battle = null
	ok(count == 2 * GameData.classes.keys().reduce(func(a, c): return a + GameSkills.list(c).size(), 0), "every class skill ran on 1 and 3 wolves (%d)" % count)


# ---------------------------------------------------------------- tactics

func test_blessing_values() -> void:
	var d := _dyn("warrior", 200)
	d.heir.gold = 99999
	d.party.members.append({"id": "sister_oriel", "name": "Oriel", "hp": 1, "mp": 0, "level": 200, "gen": 1, "due": 0.0, "battles": 0, "hired_gen": 1})
	d.party.rest(d)
	var b := _battle(d, 3)
	for e in b.enemies:
		e["hp"] = 100000
		e["max_hp"] = 100000
	var ctx := GameTactics._context(b, -1)
	for id in ["guarded", "focused", "evasive", "empowered"]:
		for on in ["self", "party"]:
			var ab := {"name": "Test " + id, "type": "buff", "target": {"shape": on}, "statuses": [{"id": id, "chance": 1.0, "turns": 3, "potency": 0.25, "on": on}]}
			var v := GameTactics._blessing_value(b, -1, ab, ctx)
			ok(v > 0.0 and v < INF, "%s on %s is worth something while foes stand (%.1f)" % [id, on, v])
			b.apply_status("heir", id, 0.25, 3, "heir")
			ok(GameTactics._blessing_value(b, -1, ab, ctx) == -INF, "%s on %s is worth nothing while it holds" % [id, on])
			b.remove_status("heir", id)
	# A class stance may be cast again once it has run out; a spell blessing stays once a battle.
	var stance: Dictionary = GameSkills.list("warrior")[3]
	b.uses["heir/" + str(stance["name"])] = 1
	ok(GameTactics._blessing_value(b, -1, stance, ctx) > 0.0, "Iron Stance again once it has run out")
	var ward := GameCombat.spell("ward")
	b.uses["heir/" + str(ward["name"])] = 1
	ok(GameTactics._blessing_value(b, -1, ward, ctx) == -INF, "a ward spell stays once a battle")
	d.battle = null


func test_guard_floor() -> void:
	var d := _dyn("warrior", 30)
	var b := _battle(d, 1)
	b.apply_status("heir", "guarded", 0.4, 3, "heir")
	b.apply_status("heir", "shield", 0.0, 3, "heir")
	ok(is_equal_approx(b._taken_mult("heir"), 0.6), "one guard takes off its share (x%.2f)" % b._taken_mult("heir"))
	b.statuses["heir"][0]["amount"] = 0.95
	ok(is_equal_approx(b._taken_mult("heir"), float(GameCombat.setting("party_taken_floor"))), "stacked guards never take off more than half (x%.2f)" % b._taken_mult("heir"))
	b.apply_status(GameBattle.enemy_ref(0), "vulnerable", 0.5, 3, "heir")
	ok(is_equal_approx(b._taken_mult(GameBattle.enemy_ref(0)), 1.5), "foes are not floored that way")
	d.battle = null


func test_styles() -> void:
	ok(GameSkills.style_text(_dyn("mage", 5).heir).contains("caster"), "a mage fights as a caster")
	ok(GameSkills.style_text(_dyn("warrior", 5).heir).contains("fighter"), "a warrior as a fighter")
	ok(GameSkills.style_text(_dyn("spellblade", 5).heir).contains("spellblade"), "a spellblade as a spellblade")
	var d := _dyn("spellblade", 40)
	var nums := {"str": 100.0, "mag": 10.0}
	var lo := GameSkills.lean(d.heir, nums)
	var hi := GameSkills.lean(d.heir, {"str": 10.0, "mag": 100.0})
	var span: Array = GameCombat.setting("bot_style_lean")
	ok(lo < hi and lo >= float(span[0]) and hi <= float(span[1]), "a hybrid leans by its build, within bounds (%.2f, %.2f)" % [lo, hi])
	var wm := GameSkills.weights(_dyn("warrior", 5).heir, nums)
	var wc := GameSkills.weights(_dyn("mage", 5).heir, nums)
	ok(float(wm["attack"]) > float(wc["attack"]) and float(wc["spell"]) > float(wm["spell"]) and float(wc["mp_price"]) < float(wm["mp_price"]), "fighters weigh blows, casters spells and spend MP freely")
	var plan := {"act": "ability", "ab": GameFeats.def("cleave"), "feat": "cleave", "skill": -1, "spell": ""}
	ok(GameSkills.category(plan) == "feat_weapon", "a feat of steel")
	ok(GameSkills.category({"act": "ability", "ab": {"scaling": {"mag": 1.0}, "mult": 1.0}, "feat": "x", "skill": -1, "spell": ""}) == "feat_magic", "a feat of MAG")
	ok(GameSkills.category({"act": "ability", "ab": GameCombat.spell("ward"), "spell": "ward", "skill": -1}) == "support", "a ward is support")
	ok(GameSkills.category({"act": "ability", "ab": GameCombat.spell("fireball"), "spell": "fireball", "skill": -1}) == "spell", "a fireball is a spell")
	ok(GameSkills.category({"act": "ability", "ab": GameSkills.list("paladin")[0], "spell": "", "skill": 0}) == "both_skill", "Holy Strike is body and spell")


## The share of each kind of action over 40 seeded fights: levels 8 and 40, 1 and 3 wolves,
## seeds 100..109, a fitting weapon, feats readied in town.
func _mix(cid: String) -> Dictionary:
	var tally := {}
	var feats := 0
	for lv in [8, 40]:
		for s in 10:
			for n in [1, 3]:
				var d := _dyn(cid, lv, 100 + s)
				d.heir.equipment["weapon"] = WEAPON.get(cid, "")
				d.heir.downtime = true
				GameFeats.bot_tick(d)
				feats = maxi(feats, d.heir.equipped_feats.size())
				d.heir.full_heal()
				var b := _battle(d, n)
				var g := 0
				while not b.is_over() and g < 80:
					g += 1
					var k := GameSkills.category(GameTactics.auto_turn(b))
					tally[k] = int(tally.get(k, 0)) + 1
				d.battle = null
	var tot := 0
	for k in tally:
		if k in OFFENSIVE:
			tot += int(tally[k])
	var share := {"feats_readied": feats}
	for k in OFFENSIVE:
		share[k] = float(tally.get(k, 0)) / float(maxi(1, tot))
	return share


func test_class_mix() -> void:
	for cid in ["warrior", "mage", "rogue", "cleric", "ranger", "monk", "necromancer", "druid", "spellblade", "paladin", "duelist", "warlock", "ninja"]:
		var m := _mix(cid)
		var magic := float(m["spell"]) + float(m["magic_skill"]) + float(m["feat_magic"]) + float(m["both_skill"]) * 0.5
		var steel := float(m["attack"]) + float(m["weapon_skill"]) + float(m["feat_weapon"]) + float(m["both_skill"]) * 0.5
		var text := "%s: %s" % [cid, str(OFFENSIVE.map(func(k): return "%s %d%%" % [k, int(round(float(m[k]) * 100.0))]))]
		match str(GameSkills.style(cid)["kind"]):
			"caster":
				ok(magic >= 0.75, "a caster casts: magic %d%% (%s)" % [int(magic * 100.0), text])
				ok(float(m["attack"]) <= 0.15, "a caster rarely swings its staff: %d%%" % int(float(m["attack"]) * 100.0))
			"martial":
				ok(float(m["spell"]) == 0.0 and float(m["magic_skill"]) == 0.0, "a fighter casts nothing (%s)" % text)
				ok(steel >= 0.8, "a fighter fights with steel (stances and wards are the rest): %d%%" % int(steel * 100.0))
				if int(m["feats_readied"]) > 0:
					ok(float(m["feat_weapon"]) + float(m["feat_magic"]) >= 0.08, "a fighter with feats uses them: %d%% (%s)" % [int((float(m["feat_weapon"]) + float(m["feat_magic"])) * 100.0), text])
			"hybrid":
				ok(steel >= 0.2 and magic >= 0.2, "a hybrid does both: steel %d%%, magic %d%% (%s)" % [int(steel * 100.0), int(magic * 100.0), text])


func test_caster_dry_and_potions() -> void:
	# A caster at 0 MP never picks anything that costs MP.
	for cid in ["mage", "necromancer", "cleric", "druid", "warlock", "shaman"]:
		var d := _dyn(cid, 40)
		var b := _battle(d, 3)
		_sturdy(b)
		d.heir.mp = 0
		var plan := GameTactics.choose(b, -1)
		ok(int(plan.get("mp", plan.get("cost", 0))) == 0, "%s at 0 MP picks a free action: %s" % [cid, str(plan.get("ab", {}).get("name", plan["act"]))])
		d.battle = null
	# Low with potions: drink first.
	var d2 := _dyn("mage", 40)
	var b2 := _battle(d2, 2)
	d2.heir.potions = 2
	d2.heir.hp = maxi(1, int(float(d2.heir.max_hp()) * float(GameCombat.setting("bot_heal_below")) * 0.5))
	ok(GameTactics.choose(b2, -1)["act"] == "potion", "a hurt caster with potions drinks first")
	d2.battle = null
	# Hurt but not yet at the heal mark, a caster keeps the MP for its heal.
	var d3 := _dyn("mage", 40)
	var b3 := _battle(d3, 2)
	_sturdy(b3)
	d3.heir.potions = 0
	d3.heir.hp = int(float(d3.heir.max_hp()) * 0.4)
	var heal := GameBattle.unit_skill_cost(d3.heir, 1)
	d3.heir.mp = heal + 3
	var p3 := GameTactics.choose(b3, -1)
	ok(d3.heir.mp - int(p3.get("mp", 0)) >= heal, "below half, a caster keeps enough MP for Mend: %s" % str(p3.get("ab", {}).get("name", p3["act"])))
	d3.battle = null


## Five wolves bunched: a class with an area uses one at least once a fight.
func test_areas_on_packs() -> void:
	for cid in ["mage", "ranger", "warrior", "shaman", "druid", "necromancer", "spellblade"]:
		var fights := 0
		var with_area := 0
		for s in 6:
			var d := _dyn(cid, 60, 200 + s)
			d.heir.equipment["weapon"] = WEAPON.get(cid, "")
			var b := _battle(d, 5)
			var g := 0
			var area := false
			while not b.is_over() and g < 80:
				g += 1
				var p := GameTactics.auto_turn(b)
				if p["act"] == "ability" and p.has("ab") and GameCombat.is_aoe(p["ab"]):
					area = true
			fights += 1
			with_area += 1 if area else 0
			d.battle = null
		ok(with_area == fights, "%s uses an area against five wolves in every fight (%d of %d)" % [cid, with_area, fights])


func test_determinism() -> void:
	var runs: Array = []
	for r in 2:
		var plans: Array = []
		for cid in ["mage", "warrior", "spellblade"]:
			var d := _dyn(cid, 40, 77)
			d.heir.downtime = true
			GameFeats.bot_tick(d)
			var b := _battle(d, 3)
			var g := 0
			while not b.is_over() and g < 60:
				g += 1
				var p := GameTactics.auto_turn(b)
				plans.append("%s:%s:%s" % [p["act"], str(p.get("ab", {}).get("name", "")), str(p.get("target", ""))])
			plans.append(b.result)
			d.battle = null
		runs.append(plans)
	ok(runs[0] == runs[1] and not runs[0].is_empty(), "the same seed gives the same plans")


# ---------------------------------------------------------------- identity of the autopilot

## A cleric (style heal_below) mends a hurt companion before it strikes, even with the heir hale; a
## class without the style does not.
func test_tends_allies() -> void:
	for cid in ["cleric", "druid", "warrior"]:
		var mended := 0
		var fights := 6
		for s in fights:
			var d := _dyn(cid, 40, 300 + s)
			var b := _battle(d, 3, "wolf" if s % 2 == 0 else "skeleton")
			b.add_allies([GameParty.build_unit("bren_cask", 30, 1)])
			b.allies[0].hp = maxi(1, int(float(b.allies[0].max_hp()) * 0.15))
			var p := GameTactics.choose(b, -1)
			if p.get("act", "") == "ability" and p["ab"].has("pct_max_hp") and int(p.get("target", -2)) == 0:
				GameTactics.act(b, p)
				if b.events.any(func(e): return e.get("type", "") == "heal" and e.get("side", "") == "ally" and int(e.get("amount", 0)) > 0):
					mended += 1
			d.battle = null
		if float(GameSkills.style(cid)["heal_below"]) > 0.0:
			ok(mended == fights, "%s mends the hurt companion first, in every fight (%d of %d)" % [cid, mended, fights])
		else:
			ok(mended == 0, "%s does not stop to mend a companion (%d)" % [cid, mended])


## Holy work bites undead harder (creatures carry tags; abilities a "bane"), so a cleric turns to
## it against skeletons: the same blow is worth more, and the autopilot reaches for holy things.
func test_undead() -> void:
	ok(GameCombat.creature_def("skeleton").get("tags", []).has("undead") and GameCombat.creature_def("ghoul").get("tags", []).has("undead"), "skeletons and ghouls are tagged undead")
	ok(not GameCombat.creature_def("wolf").has("tags"), "a wolf is not")
	var d := _dyn("cleric", 40, 5)
	var bs := _battle(d, 1, "skeleton")
	var smite: Dictionary = GameSkillTree.skill(d.heir, 0)
	var vs_bone := 0.0
	for h in bs.expected_hits(-1, smite, 0):
		vs_bone += float(h[1])
	var plain := smite.duplicate()
	plain.erase("bane")
	var no_bane := 0.0
	for h in bs.expected_hits(-1, plain, 0):
		no_bane += float(h[1])
	ok(vs_bone > no_bane * 1.3, "Smite does more to a skeleton with its bane than without (%.0f vs %.0f)" % [vs_bone, no_bane])
	d.battle = null
	var holy := {}
	for foe in ["wolf", "skeleton"]:
		var n := 0
		var h := 0
		for s in 8:
			var d2 := _dyn("cleric", 60, 400 + s)
			d2.heir.downtime = true
			GameFeats.bot_tick(d2)
			var b := _battle(d2, 3, foe)
			var g := 0
			while not b.is_over() and g < 60:
				g += 1
				var p := GameTactics.auto_turn(b)
				if p.get("act", "") == "ability" and str(p["ab"].get("element", "")) == "holy":
					h += 1
				n += 1
			d2.battle = null
		holy[foe] = float(h) / float(maxi(1, n))
	ok(float(holy["skeleton"]) > float(holy["wolf"]), "a cleric works more holy ability against skeletons than wolves (%d%% vs %d%%)" % [int(float(holy["skeleton"]) * 100.0), int(float(holy["wolf"]) * 100.0)])
	var turn: Dictionary = GameFeats.def("turn_undead")
	ok(float(turn.get("bane", {}).get("undead", 1.0)) >= 1.5, "Turn Undead has a bane against the undead")


## Hiding: the next blow from the shadows is a certain crit and ends the hiding.
func test_stealth() -> void:
	var d := _dyn("rogue", 30, 9)
	var b := _battle(d, 1, "bandit")
	_sturdy(b)
	d.heir.equipped_feats = ["shadow_slip"]
	d.heir.known_feats = ["shadow_slip"]
	b.use_feat(0, 0)
	ok(b.has_status("heir", "hidden"), "Slip into Shadow hides the rogue")
	var crits := 0
	var before := b.turn
	b.attack(0)
	for e in b.events:
		if e.get("type", "") == "damage" and bool(e.get("crit", false)):
			crits += 1
	ok(crits == 1, "the first blow from hiding is a crit (%d)" % crits)
	ok(not b.has_status("heir", "hidden"), "and it ends the hiding")
	ok(b.turn > before, "the battle went on")
	ok(GameFeats.def("shadow_slip").get("requires", {}).get("classes", []) == ["rogue"], "Slip into Shadow is the rogue's own")
	d.battle = null


## The rogue opens with poison, then stealth, and then strikes; a warrior opens with its stance.
## Only where the fight is worth preparing for.
func test_openers() -> void:
	var first := {}
	var second := {}
	for s in 8:
		var d := _dyn("rogue", 20, 500 + s)
		d.heir.downtime = true
		d.heir.known_feats = []
		d.heir.feat_points = 5
		GameFeats.bot_tick(d)
		var b := _battle(d, 1, "ogre")
		for e in b.enemies:
			e["hp"] = 60000
			e["max_hp"] = 60000
			e["atk"] = 1.0
		var p1 := GameTactics.auto_turn(b)
		var p2 := GameTactics.auto_turn(b)
		var n1 := str(p1.get("ab", {}).get("name", p1["act"]))
		var n2 := str(p2.get("ab", {}).get("name", p2["act"]))
		first[n1] = int(first.get(n1, 0)) + 1
		second[n2] = int(second.get(n2, 0)) + 1
		d.battle = null
	ok(int(first.get("Envenom", 0)) == 8, "a rogue opens a long fight with Envenom: %s" % str(first))
	ok(int(second.get("Slip into Shadow", 0)) == 8, "then slips into shadow: %s" % str(second))
	var d3 := _dyn("warrior", 30, 3)
	var b3 := _battle(d3, 1, "ogre")
	for e in b3.enemies:
		e["hp"] = 60000
		e["max_hp"] = 60000
		e["atk"] = 1.0
	ok(str(GameTactics.auto_turn(b3).get("ab", {}).get("name", "")) == "Iron Stance", "a warrior sets its stance first in a long fight")
	d3.battle = null
	# A fight over in a round is not opened with a stance.
	var d4 := _dyn("warrior", 60, 3)
	var b4 := _battle(d4, 1, "slime")
	ok(str(GameTactics.auto_turn(b4).get("ab", {}).get("name", "")) != "Iron Stance", "a trivial fight is not opened with a stance")
	d4.battle = null
	# The rogue keeps both opening moves, but only plays them where the foes' round is cheap: its own, tighter pace limit.
	var rp := float(GameSkills.style("rogue")["opener_max_pace"].get("shadow_slip", 0.0))
	ok(rp > 0.0 and rp < float(GameCombat.setting("bot_opener_max_pace")), "the rogue's stealth opener has a tighter pace limit than the default, and poison keeps the default: %s" % str(rp))
	ok(not GameSkills.style("rogue")["opener_max_pace"].has("envenom"), "the rogue's poison opener has no pace limit of its own")
	ok(GameSkills.style("rogue")["opener"] == ["envenom", "shadow_slip"], "the rogue still opens with poison, then stealth")
	for cid in GameData.classes:
		for id in GameSkills.style(cid)["opener"]:
			ok(GameSkills.list(cid).any(func(sk): return str(sk["id"]) == str(id)) or not GameFeats.def(str(id)).is_empty(), "%s: opener %s exists" % [cid, id])
	test_rogue_opener_in_play()


## What the rogue really plays: poison first against mid-pace foes (the pace limit of stealth must
## not take poison with it), stealth next only where the foes' round is cheap.
func test_rogue_opener_in_play() -> void:
	for lv in [25, 80]:
		for sc in [["skeleton", 2, 1.08], ["ogre", 1, 1.44]]:
			var d := _dyn("rogue", lv, 100)
			d.heir.downtime = true
			GameSkillTree.bot_tick(d)
			GameFeats.bot_tick(d)
			d.heir.full_heal()
			var foes: Array = []
			for i in int(sc[1]):
				foes.append(d._make_enemy(GameCombat.creature_def(str(sc[0])), float(sc[2]), 1.0, lv))
			d._begin_battle(foes, "hunt")
			var b: GameBattle = d.battle
			var pace := float(GameTactics._context(b, -1)["total"]) / float(maxi(1, int(b.unit_numbers(-1)["max_hp"])))
			var what := "L%d %s x%d (pace %.2f)" % [lv, sc[0], sc[1], pace]
			ok(pace > float(GameSkills.style("rogue")["opener_max_pace"]["shadow_slip"]) and pace < float(GameCombat.setting("bot_opener_max_pace")), "%s is a mid-pace fight" % what)
			var p1 := GameTactics.auto_turn(b)
			ok(str(p1.get("ab", {}).get("name", "")) == "Envenom", "%s: turn 1 is Envenom, got %s" % [what, str(p1.get("ab", {}).get("name", p1["act"]))])
			var p2 := GameTactics.auto_turn(b)
			ok(str(p2.get("ab", {}).get("name", "")) != "Slip into Shadow", "%s: stealth is skipped where the foes bite hard" % what)
			d.battle = null
		# A long, cheap fight: poison, then stealth.
		var d2 := _dyn("rogue", lv, 100)
		d2.heir.downtime = true
		GameSkillTree.bot_tick(d2)
		GameFeats.bot_tick(d2)
		d2.heir.full_heal()
		var b2 := _battle(d2, 2, "skeleton")
		for e in b2.enemies:
			e["hp"] = 60000
			e["max_hp"] = 60000
			e["atk"] = 0.0
		# Foes that hit softly (a round costs a tenth of the heir's HP at most) but last long.
		var a := 0.0
		while a < 2000.0:
			a += 10.0
			for e in b2.enemies:
				e["atk"] = a
			if float(GameTactics._context(b2, -1)["total"]) >= 0.07 * float(b2.unit_numbers(-1)["max_hp"]):
				break
		var q1 := GameTactics.auto_turn(b2)
		var q2 := GameTactics.auto_turn(b2)
		ok(str(q1.get("ab", {}).get("name", "")) == "Envenom" and str(q2.get("ab", {}).get("name", "")) == "Slip into Shadow", "L%d: a long cheap fight opens poison, then stealth: %s, %s" % [lv, str(q1.get("ab", {}).get("name", q1["act"])), str(q2.get("ab", {}).get("name", q2["act"]))])
		d2.battle = null


## Over seeded fights of every sort, the autopilot reaches for each class skill that is not a
## heal, so no skill is dead data. Fights run at the level the skill opens at and a little above it.
func test_every_skill_gets_used() -> void:
	var scen := [["wolf", 1, 1.0], ["wolf", 3, 2.5], ["bandit", 3, 4.0], ["ogre", 1, 3.0], ["stone_golem", 1, 4.0], ["skeleton", 3, 3.0],
		["wolf", 5, 5.0], ["bandit", 1, 6.0], ["wolf", 3, 1.0], ["bandit", 3, 1.0], ["ogre", 1, 1.0], ["stone_golem", 1, 1.5],
		["skeleton", 3, 1.5], ["wolf", 5, 1.5], ["bandit", 1, 2.0], ["ogre", 3, 2.0], ["wolf", 1, 1.0]]
	for cid in GameData.classes:
		var used := {}
		var levels := {}
		for sk in GameSkills.list(cid):
			levels[GameSkills.level_of(sk)] = true
			levels[int(GameSkills.level_of(sk) * 1.6) + 2] = true
		for lv in levels:
			for sc in scen:
				for s in 3:
					var d := GameDynasty.new_game(100 + s, "P", cid, "faetouched", "human")
					d.pending_event = {}
					d.heir.level = lv
					d.heir.spells = []
					d.heir.learn_spells()
					d.heir.downtime = true
					GameSkillTree.bot_tick(d)
					GameFeats.bot_tick(d)
					d.heir.full_heal()
					var foes: Array = []
					for i in int(sc[1]):
						foes.append(d._make_enemy(GameCombat.creature_def(str(sc[0])), float(sc[2]), 1.0, d.heir.level))
					d._begin_battle(foes, "hunt")
					var g := 0
					while not d.battle.is_over() and g < 60:
						g += 1
						var p := GameTactics.auto_turn(d.battle)
						if p.get("act", "") == "ability":
							used[str(p["ab"].get("name", "?"))] = true
					d.battle = null
		var dead: Array = []
		for sk in GameSkills.list(cid):
			if str(sk["type"]) != "heal" and not used.has(str(sk["name"])):
				dead.append(str(sk["name"]))
		ok(dead.is_empty(), "%s: every strike, control and stance gets used by the autopilot; never chosen: %s" % [cid, str(dead)])
