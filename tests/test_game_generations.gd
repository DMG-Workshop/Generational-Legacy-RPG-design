## The long count: Ages, content gates on the generation within the Age, scaling on the true
## generation, history folded into Age summaries, bounded saves, and the end of the saga.
## godot --headless --path . -s res://tests/test_game_generations.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const ChroniclePanel := preload("res://ui/play/chronicle_panel.gd")
const UI_SAVE := "user://test_generations_ui_save.json"
const EXACT_INT := 9007199254740992   # 2^53: whole numbers above this do not survive a JSON round trip

var checks := 0
var fails := 0
var _saved_settings: Dictionary = {}


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _new(s: int, cls: String = "warrior", race: String = "human") -> GameDynasty:
	var d := GameDynasty.new_game(s, "Tess", cls, "faetouched", race)
	d.pending_event = {}
	return d


## Temporarily changes an Ages setting; _restore() puts every one back.
func _override(key: String, value: int) -> void:
	if not _saved_settings.has(key):
		_saved_settings[key] = GameAges.settings()[key]
	GameAges.settings()[key] = value


func _restore() -> void:
	for k in _saved_settings:
		GameAges.settings()[k] = _saved_settings[k]
	_saved_settings = {}


func _reload(d: GameDynasty) -> GameDynasty:
	return GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))


## Wins the battle in progress: foes drop to 1 HP and stop hitting, then the heir attacks.
func _win(d: GameDynasty) -> Array:
	var b := d.battle
	for e in b.enemies:
		e["hp"] = 1
		e["atk"] = 0.0
	var guard := 0
	while not b.is_over() and guard < 50:
		guard += 1
		b.attack(b.first_target())
	return d.finish_battle()


func _creature(id: String) -> Dictionary:
	for c in GameData.creatures:
		if c["id"] == id:
			return c
	return {}


func _init() -> void:
	GameData.load_all()
	test_age_math()
	test_content_gates_use_era()
	test_scaling_uses_true_gen()
	test_legends_reawaken()
	test_quests_across_ages()
	test_once_per_age_events()
	test_history_folding()
	test_save_size_bounded()
	test_old_save_long_history()
	test_real_lives_bounded()
	test_party_records_bounded()
	test_numbers_at_the_cap()
	test_ending_at_the_cap()
	test_determinism_across_ages()
	_ui_tests.call_deferred()


func _ui_tests() -> void:
	var real_path := GameDynasty.save_path
	GameDynasty.save_path = UI_SAVE
	root.size = Vector2i(1280, 720)
	var app: Control = GameApp.new()
	root.add_child(app)
	await _frames()
	await test_ui_life_and_chronicle(app)
	await test_ui_ending(app)
	app.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(UI_SAVE))
	GameDynasty.save_path = real_path
	print("generations: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- the long count

func test_age_math() -> void:
	ok(GameAges.validate().is_empty(), "ages data and content windows validate: %s" % str(GameAges.validate()))
	ok(GameAges.max_generations() == 999999 and GameAges.age_length() == 1100, "the saga runs 999,999 generations in Ages of 1,100")
	var cases := [[1, 1, 1], [2, 2, 1], [1099, 1099, 1], [1100, 1100, 1], [1101, 1, 2], [1102, 2, 2], [2200, 1100, 2], [2201, 1, 3], [999998, 98, 910], [999999, 99, 910]]
	for c in cases:
		ok(GameAges.era_of(c[0]) == c[1] and GameAges.age_of(c[0]) == c[2], "generation %d is era %d of Age %d (got %d, %d)" % [c[0], c[1], c[2], GameAges.era_of(c[0]), GameAges.age_of(c[0])])
	ok(GameAges.era_of(0) == 1 and GameAges.age_of(0) == 1, "an unset generation 0 counts as the first")
	var d := _new(1)
	for g in [1, 1100, 1101, 999999]:
		d.gen = g
		ok(d.era_gen() == GameAges.era_of(g) and d.age_number() == GameAges.age_of(g), "the dynasty reads era and Age at generation %d" % g)
	_override("age_length", 7)
	ok(GameAges.era_of(7) == 7 and GameAges.era_of(8) == 1 and GameAges.age_of(15) == 3, "age_length is read from data")
	_restore()
	ok(GameText.num(0) == "0" and GameText.num(999) == "999" and GameText.num(1000) == "1,000", "thousands separators from 1,000")
	ok(GameText.num(999999) == "999,999" and GameText.num(-1234567) == "-1,234,567" and GameText.num(123456789012345) == "123,456,789,012,345", "long and negative numbers group in threes")
	ok(GameText.signed(25) == "+25" and GameText.signed(-40) == "-40" and GameText.signed(1234567) == "+1,234,567", "signed amounts keep their sign")
	var line := GameText.group_numbers("Tess hits Elder Dragon for 13620509978 (CRIT!). Wolf hits Tess for 999. Heals 1000.")
	ok(line == "Tess hits Elder Dragon for 13,620,509,978 (CRIT!). Wolf hits Tess for 999. Heals 1,000.", "log lines group their long numbers: %s" % line)
	line = GameText.group_numbers("[color=#1a1828]Heir2024 restores 12345 HP.[/color] 12345678901234567890")
	ok(line == "[color=#1a1828]Heir2024 restores 12,345 HP.[/color] 12345678901234567890", "colours, names and runs too long for a number are left alone: %s" % line)


# ---------------------------------------------------------------- gates and scaling

func test_content_gates_use_era() -> void:
	var d := _new(2)
	d.heir.level = 30
	GameAges.jump_to(d, 1101)
	ok(d.era_gen() == 1 and d.age_number() == 2, "jumped to the first generation of Age 2")
	ok(d.stirring_legends().map(func(c): return c["id"]) == ["grimfang"], "Age 2 opens with the first era's legend: %s" % str(d.stirring_legends().map(func(c): return c["id"])))
	var early := ["slime", "wolf", "goblin", "bandit"]
	var late := ["abyssal_knight", "star_eater", "time_wraith", "elder_dragon"]
	for place in ["whisperwood", "greenvale", "goblin_warrens"]:
		d.world.visit(place)
		for i in 6:
			var b := d.start_hunt("hunt")
			ok(b.enemies.all(func(e): return e["id"] in early), "%s hunt in era 1 of Age 2 meets first-era beasts: %s" % [place, str(b.enemies.map(func(e): return e["id"]))])
			d.battle = null
	GameAges.jump_to(d, 2200)
	d.world.visit("highcrag")
	for i in 6:
		var b := d.start_hunt("hunt_hard")
		ok(b.enemies.all(func(e): return e["id"] in late), "the last era of Age 2 meets the last era's beasts: %s" % str(b.enemies.map(func(e): return e["id"])))
		d.battle = null
	ok(not d.stirring_legends().any(func(c): return c["id"] == "grimfang") and d.stirring_legends().any(func(c): return c["id"] == "the_unmade"), "era 1,100 stirs the Unmade, not Grimfang")
	# Quests: the wolf cull runs to generation 85 of every Age.
	d.world.visit("hearthmere")
	for c in [[1101, true], [1185, true], [1186, false], [85, true], [86, false], [2201, true]]:
		GameAges.jump_to(d, c[0])
		var posted := d.quests.postings(d, "hearthmere").any(func(q): return q["id"] == "hm_wolf_cull")
		ok(posted == c[1], "the wolf cull is %s at generation %d (era %d)" % ["posted" if c[1] else "gone", c[0], d.era_gen()])
	ok(GameQuests.roams(d, "wolf") and not GameQuests.roams(d, "elder_dragon"), "era 1 of Age 3: wolves roam, elder dragons do not")
	# Events: scorched stone wakes at generation 120 of each Age.
	d.world.visit("emberpeak")
	var ev := GameEvents.event_def("scorched_stone")
	for c in [[119, false], [120, true], [1219, false], [1220, true], [999999, false]]:
		GameAges.jump_to(d, c[0])
		ok(GameEvents.is_eligible(d, ev) == c[1], "scorched stone %s at generation %d (era %d)" % ["eligible" if c[1] else "not yet", c[0], d.era_gen()])
	GameAges.jump_to(d, 1650)
	var foe := GameEvents._creature_for(d, "wolf")
	ok(foe["id"] != "wolf" and int(foe["min_gen"]) <= 550 and 550 <= int(foe["max_gen"]), "an event's wolf is swapped for a beast of era 550 (%s)" % foe["id"])
	# Companions: Ysolde Marrow comes to Kingshold from generation 25 of each Age.
	d.world.visit("kingshold")
	for c in [[1124, false], [1125, true], [2224, false], [2225, true], [2201, false]]:
		GameAges.jump_to(d, c[0])
		var lock := d.party.locked_reason(d, "ysolde_marrow")
		ok((lock == "") == c[1], "Ysolde at generation %d (era %d): '%s'" % [c[0], d.era_gen(), lock])


func test_scaling_uses_true_gen() -> void:
	var a := _new(3)
	var b := _new(3)
	GameAges.jump_to(b, 1101)
	ok(a.era_gen() == b.era_gen(), "both at era 1")
	var r := GameData.enemy_scale(1101) / GameData.enemy_scale(1)
	var near := func(x: float, y: float, what: String) -> void:
		ok(y >= 1.0 and absf(x / y - r) <= r * 0.03, "%s scales with the true generation: %.1f vs %.1f (x%.2f, want x%.2f)" % [what, x, y, x / maxf(1.0, y), r])
	var slime := _creature("slime")
	near.call(float(b._make_enemy(slime, 1.0, 1.0, 10)["hp"]), float(a._make_enemy(slime, 1.0, 1.0, 10)["hp"]), "a slime's HP")
	near.call(float(b._make_enemy(slime, 1.0, 1.0, 10)["gold"]), float(a._make_enemy(slime, 1.0, 1.0, 10)["gold"]), "a slime's gold")
	near.call(float(GameItems.price(b, "steel_sword")), float(GameItems.price(a, "steel_sword")), "a steel sword's price")
	near.call(float(b.potion_price()), float(a.potion_price()), "a potion")
	near.call(float(b.party.fee(b, "ser_aldric_vane")), float(a.party.fee(a, "ser_aldric_vane")), "a companion's fee")
	near.call(float(b.party.upkeep(b, "pale_warden")), float(a.party.upkeep(a, "pale_warden")), "a companion's upkeep")
	near.call(float(GameQuests.reward_gold(b, GameQuests.def("hm_wolf_cull"))), float(GameQuests.reward_gold(a, GameQuests.def("hm_wolf_cull"))), "a bounty")
	near.call(float(GameEvents.gold_amount(b, 120.0)), float(GameEvents.gold_amount(a, 120.0)), "an event's gold")
	near.call(float(b.map_price(GameData.world["maps"][0])), float(a.map_price(GameData.world["maps"][0])), "a map")
	ok(is_equal_approx(b.heir.stat("str") / a.heir.stat("str"), GameData.heir_scale(1101)), "heir stats scale with the true generation (x%.2f)" % (b.heir.stat("str") / a.heir.stat("str")))
	ok(b._make_enemy(slime, 1.0, 1.0, 10)["xp"] == a._make_enemy(slime, 1.0, 1.0, 10)["xp"], "XP follows the level, not the generation")
	# HP: in the first Age exactly as before; in a later Age it grows by heir_scale, not its square,
	# so a beast's blow takes the same share of an heir's health at the same era of every Age.
	var h := GameHeir.new()
	h.class_id = "warrior"
	h.level = 60
	h.training = {"str": 9.0, "mag": 0.0, "agi": 3.0, "vit": 12.0}
	for g in [1, 300, 1100]:
		h.gen = g
		var old := (h.base_of("hp") + h.growth_of("hp") * float(h.level - 1) + h.stat("vit") * 2.0) * GameData.heir_scale(g) * (1.0 + h.trait_total("max_hp"))
		ok(h.max_hp() == maxi(10, int(round(old))), "Age 1 HP unchanged at generation %d (%d)" % [g, h.max_hp()])
		var old_mp := (h.base_of("mp") + h.growth_of("mp") * float(h.level - 1) + h.stat("mag") * 0.5) * (1.0 + h.trait_total("max_mp"))
		ok(h.max_mp() == maxi(0, int(round(old_mp))), "Age 1 MP unchanged at generation %d (%d)" % [g, h.max_mp()])
	# MP pays for skills whose cost follows the level alone: the same era of any Age holds as many casts.
	for era in [50, 1000]:
		h.gen = era
		var mp1 := h.max_mp()
		h.gen = era + 909 * GameAges.age_length()
		ok(absi(h.max_mp() - mp1) <= 1, "era %d: MP in Age 910 matches Age 1 (%d vs %d)" % [era, h.max_mp(), mp1])
	# AGI meets fixed odds: dodge and crit read the same at the same era of every Age, Age 1 untouched.
	for g in [1, 300, 1100]:
		h.gen = g
		var agi := h.stat("agi")
		ok(h.dodge_chance() == clampf(agi / (agi + 60.0) * 0.5, 0.0, 0.6) and h.crit_chance() == clampf(0.05 + agi / (agi + 100.0) * 0.2, 0.0, 0.6), "Age 1 dodge and crit unchanged at generation %d" % g)
	for era in [1, 50, 1000]:
		h.gen = era
		var dodge1 := h.dodge_chance()
		var crit1 := h.crit_chance()
		for age in [2, 910]:
			h.gen = era + (age - 1) * GameAges.age_length()
			ok(is_equal_approx(h.dodge_chance(), dodge1) and is_equal_approx(h.crit_chance(), crit1), "era %d of Age %d dodges and crits as Age 1 did (%.3f/%.3f vs %.3f/%.3f)" % [era, age, h.dodge_chance(), h.crit_chance(), dodge1, crit1])
	var drake := _creature("drake")
	for era in [50, 400, 1000]:
		var share := []
		for age in [1, 2, 10, 910]:
			var g: int = era + (age - 1) * GameAges.age_length()
			h.gen = g
			var e := GameDynasty.new()
			e.gen = g
			share.append(float(e._make_enemy(drake, 1.0, 1.0, 60)["atk"]) / float(h.max_hp()))
		var spread: float = share.max() / share.min()
		ok(spread < 1.12, "era %d: a drake's blow takes a like share of HP in Ages 1, 2, 10 and 910 (%s)" % [era, str(share.map(func(x): return snappedf(x, 0.0001)))])


# ---------------------------------------------------------------- a new Age

## Real successions across the turn of an Age: legends rise again, heirlooms stay, no copies.
func test_legends_reawaken() -> void:
	var d := _new(4)
	d.heir.level = 70
	d.heir.full_heal()
	GameAges.jump_to(d, 1099)
	d.slain_bosses = {"grimfang": 40, "stonefather": 500}   # the Unmade still stirs: a notice hunts it
	d.heirlooms = [{"name": "Grimfang's Fang", "boss": "Grimfang", "gen": 40}, {"name": "Heart of Stone", "boss": "The Stonefather", "gen": 500}]
	d.set_flag("rift_open")
	d.quests.active.append({"id": "ks_the_unmade", "progress": 0, "gen": 1099, "by": d.heir.name})
	d._die("old age")
	d.choose_heir(0)
	ok(d.gen == 1100 and d.age_number() == 1 and d.slain_bosses.size() == 2 and d.quests.is_active("ks_the_unmade"), "the last generation of Age 1 keeps its slain legends and the Unmade's notice")
	ok(not d.journal.any(func(l): return str(l).begins_with("Age ")), "no Age line before the Age turns")
	d._die("old age")
	var before := d.journal.size()
	d.choose_heir(0)
	ok(d.gen == 1101 and d.era_gen() == 1 and d.age_number() == 2, "succession crosses into Age 2")
	var lines: Array = d.journal.slice(before)
	ok(lines.any(func(l): return str(l).begins_with("Age 2 begins")), "the journal marks the new Age: %s" % str(lines.slice(0, 3)))
	ok(lines.find("Generation 1,101: %s takes up the family name." % d.heir.full_name()) == 0, "the generation line comes first, grouped in thousands")
	ok(d.slain_bosses.is_empty(), "legends reawaken: slain_bosses cleared")
	ok(d.heirlooms.size() == 2 and d.heir.heirloom_bonus > 0.0, "heirlooms kept across the Age")
	ok(not d.quests.is_active("ks_the_unmade") and lines.any(func(l): return str(l).contains("none of that quarry is left")), "a hunt for the Unmade lapses when its era is over")
	ok(d.stirring_legends().any(func(c): return c["id"] == "grimfang"), "Grimfang stirs again")
	d.heir.level = 40
	d.world.visit("whisperwood")
	ok(d.available_boss().get("id", "") == "grimfang", "Grimfang can be fought in his lair")
	d.start_legend()
	var msgs := _win(d)
	ok(d.slain_bosses.get("grimfang", 0) == 1101, "Grimfang slain again in Age 2")
	ok(d.heirlooms.size() == 2, "no second Grimfang's Fang (%d heirlooms)" % d.heirlooms.size())
	ok(msgs.any(func(m): return str(m) == "Grimfang's Fang already hangs in the hall of House %s." % d.dynasty_name), "the house is told it already holds the fang")
	ok(msgs.any(func(m): return str(m).begins_with("Legend: ")), "the kill is still a legend's death")
	ok(d.available_boss().is_empty(), "slain once in this Age, Grimfang stays dead until the next")
	d.heir.full_heal()
	GameAges.jump_to(d, 2201)
	ok(d.age_number() == 3 and d.stirring_legends().any(func(c): return c["id"] == "grimfang"), "a jump into Age 3 wakes him again")


## Story notices come back in a later Age; lasting deeds and reward copies do not.
func test_quests_across_ages() -> void:
	var d := _new(5)
	d.heir.gold = 100000
	d.heir.level = 30
	d.heir.full_heal()
	d.quests.accept(d, "hm_grimfang")
	d.world.visit("whisperwood")
	d.start_legend()
	_win(d)
	d.world.visit("hearthmere")
	d.quests.turn_in(d, "hm_grimfang")
	ok(d.heir.inventory.count("elven_bow") + d.heir.equipment.values().count("elven_bow") == 1, "the lodge's bow, once")
	ok(not d.quests.postings(d, "hearthmere").any(func(q): return q["id"] == "hm_grimfang"), "the Alpha's notice is done for this Age")
	d.quests.record["rift_1_sealed_road"] = {"times": 1, "gen": 70}
	d.quests.record["hm_mirefen_lantern"] = {"times": 1, "gen": 50}
	ok(not d.quests.postings(d, "hearthmere").any(func(q): return q["id"] == "hm_mirefen_lantern"), "the lantern's notice is done for this Age")
	GameAges.jump_to(d, 1101)
	ok(d.quests.postings(d, "hearthmere").any(func(q): return q["id"] == "hm_grimfang"), "Age 2: the Alpha's notice goes up again")
	ok(d.quests.postings(d, "hearthmere").any(func(q): return q["id"] == "hm_mirefen_lantern"), "and so does the lantern's")
	d.heir.level = 70
	GameAges.jump_to(d, 1160)
	ok(not d.quests.is_posted(d, GameQuests.def("rift_1_sealed_road")), "a lasting deed (the Sealed Road) is never posted again")
	GameAges.jump_to(d, 1101)
	d.heir.level = 30
	ok(d.quests.accept(d, "hm_grimfang")[0].contains("takes down the notice"), "the Alpha's notice taken in Age 2")
	d.world.visit("whisperwood")
	d.heir.full_heal()
	d.start_legend()
	_win(d)
	d.world.visit("hearthmere")
	var gold := d.heir.gold
	var msgs := d.quests.turn_in(d, "hm_grimfang")
	var bows := d.heir.inventory.count("elven_bow") + d.heir.equipment.values().count("elven_bow")
	ok(bows == 1, "no second bow in the pack (%d)" % bows)
	ok(msgs.any(func(m): return str(m).contains("already has the Elven Bow") and str(m).contains("gold for it instead")), "the bow is paid in gold: %s" % str(msgs))
	ok(d.heir.gold > gold + GameQuests.reward_gold(d, GameQuests.def("hm_grimfang")), "and the gold arrives")
	ok(d.quests.times_done("hm_grimfang") == 2, "the record counts both Ages")


func test_once_per_age_events() -> void:
	var d := _new(6)
	d.world.visit("hearthmere")
	var cairn := GameEvents.event_def("founders_cairn")
	GameAges.jump_to(d, 20)
	ok(GameEvents.is_eligible(d, cairn), "the Founder's Cairn waits at generation 20")
	GameEvents.begin(d, "founders_cairn")
	d.pending_event = {}
	ok(int(d.flags[GameEvents.SEEN + "founders_cairn"]) == 20, "seen in generation 20")
	GameAges.jump_to(d, 900)
	ok(not GameEvents.is_eligible(d, cairn), "once in Age 1")
	GameAges.jump_to(d, 1105)
	ok(not GameEvents.is_eligible(d, cairn), "not before generation 11 of Age 2")
	GameAges.jump_to(d, 1111)
	ok(GameEvents.is_eligible(d, cairn), "once again in Age 2")
	GameEvents.begin(d, "founders_cairn")
	d.pending_event = {}
	ok(int(d.flags[GameEvents.SEEN + "founders_cairn"]) == 1111, "the seen mark moves to Age 2")
	GameAges.jump_to(d, 1500)
	ok(not GameEvents.is_eligible(d, cairn), "and only once in Age 2")
	# A lasting once-event (the smugglers' revenge) never returns.
	d.world.visit("brinehaven")
	d.set_flag("smugglers_broken")
	var revenge := GameEvents.event_def("smugglers_revenge")
	GameAges.jump_to(d, 1600)
	ok(GameEvents.is_eligible(d, revenge), "the smugglers wait once")
	GameEvents.begin(d, "smugglers_revenge")
	d.pending_event = {}
	GameAges.jump_to(d, 2300)
	ok(not GameEvents.is_eligible(d, revenge), "a lasting event does not come back in Age 3")
	# The bell below rings again in a new Age only while its priest has no rest.
	d.world.visit("sunken_temple")
	d.set_flag("heard_drowned_bell")
	var bell := GameEvents.event_def("bell_below")
	ok(GameEvents.is_eligible(d, bell), "the bell below waits")
	GameEvents.begin(d, "bell_below")
	GameEvents.resolve_as(d, 0, "failure")
	d.pending_event = {}
	GameAges.jump_to(d, 3301)
	ok(GameEvents.is_eligible(d, bell), "unrung, the bell waits again in Age 4")
	GameEvents.begin(d, "bell_below")
	GameEvents.resolve_as(d, 0, "success")
	d.pending_event = {}
	ok(d.flags.has("drowned_priest_rests"), "the priest is at rest")
	GameAges.jump_to(d, 4401)
	ok(not GameEvents.is_eligible(d, bell), "a priest at rest is not woken in a later Age")
	ok(GameEvents.validate().is_empty(), "event data still validates: %s" % str(GameEvents.validate()))


# ---------------------------------------------------------------- history

## One generation through the real death and succession path without living the life: the heir
## gets a level, kills and a cause of death from `i`, dies, and the first candidate succeeds.
func _synthetic_gen(d: GameDynasty, i: int) -> Dictionary:
	var h := d.heir
	h.level = 1 + (i * 7919) % 397
	h.kills = {"wolf": 1 + i % 3}
	if i % 50 == 7:
		h.kills["grimfang"] = 1
	if i % 230 == 11:
		h.kills["the_unmade"] = 1
	d._die("slain in battle" if i % 9 == 4 else "old age")
	var rec: Dictionary = d.last_death
	if d.state == "succession":
		d.choose_heir(0)
	return rec


func test_history_folding() -> void:
	var d := _new(7)
	var founder := d.heir.full_name()
	var keep := int(GameAges.setting("history_full_keep"))
	var expect := {}   # age -> {heirs, best, causes, legends}
	var all_levels: Array = []
	for i in 2300:
		var rec := _synthetic_gen(d, i)
		var age := GameAges.age_of(int(rec["gen"]))
		if not expect.has(age):
			expect[age] = {"heirs": 0, "best": rec, "causes": {}, "legends": 0}
		var x: Dictionary = expect[age]
		x["heirs"] += 1
		if int(rec["level"]) > int(x["best"]["level"]):
			x["best"] = rec
		x["causes"][rec["cause"]] = int(x["causes"].get(rec["cause"], 0)) + 1
		x["legends"] += (rec["kills"] as Dictionary).keys().filter(func(k): return GameAges.is_legend(k)).size()
		all_levels.append([int(rec["level"]), int(rec["gen"]), rec["name"]])
	ok(d.gen == 2301, "2,300 synthetic generations lived (gen %d)" % d.gen)
	ok(d.history.size() == keep + 1, "the founder and the last %d heirs kept in full (%d)" % [keep, d.history.size()])
	ok(d.history[0]["gen"] == 1 and d.history[0]["name"] == founder, "the founder's record is kept for good")
	ok(int(d.history[1]["gen"]) == 2300 - keep + 1 and int(d.history.back()["gen"]) == 2300, "the full records are the latest heirs")
	ok(d.ancestor_count() == 2300, "every ancestor is counted (%d)" % d.ancestor_count())
	ok(GameEvents.fill(d, "{founder}") == founder, "events still name the founder")
	var rows := d.ages.age_rows(d)
	ok(rows.size() == 3 and rows.map(func(r): return r["age"]) == [1, 2, 3], "three Ages told: %s" % str(rows.map(func(r): return r["age"])))
	for row in rows:
		var x: Dictionary = expect[int(row["age"])]
		ok(int(row["heirs"]) == int(x["heirs"]), "Age %d: %d heirs (want %d)" % [row["age"], row["heirs"], x["heirs"]])
		ok(int(row["greatest"]["level"]) == int(x["best"]["level"]) and row["greatest"]["name"] == x["best"]["name"], "Age %d: the greatest heir is %s, level %d" % [row["age"], x["best"]["name"], x["best"]["level"]])
		ok(row["causes"] == x["causes"], "Age %d: causes of death %s" % [row["age"], str(row["causes"])])
		var n := 0
		for l in row["legends"]:
			n += int(l.get("times", 1))
		ok(n == int(x["legends"]), "Age %d: %d legends slain (want %d)" % [row["age"], n, x["legends"]])
	ok(int(rows[0]["from"]) == 1 and int(rows[0]["to"]) == 1100 and int(rows[1]["from"]) == 1101 and int(rows[1]["to"]) == 2200, "the Ages span 1-1,100 and 1,101-2,200")
	ok(d.ages.summaries.size() == 2 and int(d.ages.summaries[0]["from"]) == 2, "summaries hold the folded heirs only (the founder stays in full)")
	all_levels.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	var top: Array = all_levels.slice(0, int(GameAges.setting("hall_of_fame"))).map(func(x): return x[2])
	ok(d.ages.hall.map(func(h): return h["name"]) == top, "the hall keeps the greatest heirs of the saga: %s" % str(top))
	var totals := d.ages.cause_totals(d)
	ok(int(totals.get("old age", 0)) + int(totals.get("slain in battle", 0)) == 2300, "cause totals add up")
	ok(int(d.ages.legend_totals(d).get("grimfang", 0)) == 46, "legend totals add up (%d Grimfangs)" % int(d.ages.legend_totals(d).get("grimfang", 0)))
	var e := _reload(d)
	ok(JSON.stringify(e.to_dict()) == JSON.stringify(d.to_dict()), "a folded history round-trips exactly")
	ok(e.ancestor_count() == 2300 and e.ages.hall == d.ages.hall, "the count and the hall survive a reload")


## Thousands of synthetic generations through the real path: the save stops growing with the
## generations, and even more Ages than the cap holds stay under a fixed size.
func test_save_size_bounded() -> void:
	var d := _new(8)
	var sizes := {}
	for i in 2300:
		_synthetic_gen(d, i)
		if d.gen in [400, 1200, 2190]:
			sizes[d.gen] = JSON.stringify(d.to_dict()).length()
	print("  save size at gen 400 / 1,200 / 2,190: %s" % str(sizes))
	ok(int(sizes[2190]) - int(sizes[1200]) < 20000, "990 more generations add under 20 KB, not a record each (%d bytes)" % (int(sizes[2190]) - int(sizes[1200])))
	ok(int(sizes[2190]) < 400000, "save at generation 2,190 under 400 KB (%d)" % int(sizes[2190]))
	# More Ages than the whole saga has: 3,000 generations in Ages of 3 fold into over 910 summaries.
	var cap_ages := GameAges.age_of(GameAges.max_generations())
	_override("age_length", 3)
	var e := _new(9)
	for i in 3000:
		_synthetic_gen(e, i)
	var bytes := JSON.stringify(e.to_dict()).length()
	print("  %d Age summaries: save %d bytes" % [e.ages.summaries.size(), bytes])
	ok(e.ages.summaries.size() >= cap_ages, "%d Ages told, more than the saga's %d" % [e.ages.summaries.size(), cap_ages])
	ok(bytes < 1000000, "with %d Ages and %d full records the save stays under 1 MB (%d bytes)" % [e.ages.summaries.size(), e.history.size(), bytes])
	ok(e.ages.legend_totals(e).has("grimfang") and e.history.size() == int(GameAges.setting("history_full_keep")) + 1, "summaries still tell the legends")
	_restore()


func _fake_record(g: int) -> Dictionary:
	return {"gen": g, "name": "Heir%d Old" % g, "class_id": "mage", "race_id": "elf", "traits": ["Fae-Touched"],
		"level": 10 + (g * 31) % 500, "age": 300, "cause": "old age" if g % 5 else "slain in battle", "gold": 100,
		"battles_won": 5, "kills": {"wolf": 2, "hollow_king": 1} if g % 100 == 50 else {"wolf": 2},
		"parents": ["A", "B"], "archetype": "", "children": ["C"], "spouse": "D"}


## A save from before the Ages, with 900 heirs in full: it folds on load and plays on.
func test_old_save_long_history() -> void:
	var d := _new(10)
	GameAges.jump_to(d, 901)
	var raw: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	raw.erase("ages")
	var hist: Array = []
	for g in range(1, 901):
		hist.append(_fake_record(g))
	raw["history"] = hist
	raw["party"]["history"] = {"bren_cask": {"name": "Bren Cask", "status": "fallen", "gen": 800, "first_gen": 3, "battles": 9,
		"fallen": ["A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8", "A9", "A10"]}}
	var e := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(raw)))
	var keep := int(GameAges.setting("history_full_keep"))
	ok(e.history.size() == keep + 1 and e.history[0]["name"] == "Heir1 Old", "the old history folds on load, founder first (%d)" % e.history.size())
	ok(int(e.history[1]["gen"]) == 900 - keep + 1, "the latest heirs stay in full")
	ok(e.ancestor_count() == 900 and e.ages.summaries.size() == 1 and int(e.ages.summaries[0]["heirs"]) == 900 - keep - 1, "the rest are one Age-1 summary")
	var best := 0
	for r in hist.slice(1, 900 - keep):
		best = maxi(best, int(r["level"]))
	ok(int(e.ages.summaries[0]["greatest"]["level"]) == best, "the summary's greatest is the best folded heir (level %d)" % best)
	var top := 0
	for r in hist:
		top = maxi(top, int(r["level"]))
	ok(int(e.ages.hall[0]["level"]) == top, "the hall ranks every heir of the old save")
	ok(e.ages.legend_totals(e).get("hollow_king", 0) == 9, "the old heirs' legends are counted (%d)" % int(e.ages.legend_totals(e).get("hollow_king", 0)))
	var r1: Dictionary = e.party.history["bren_cask"]
	ok((r1["fallen"] as Array).size() == int(GameAges.setting("party_fallen_kept")) and r1["fallen"].back() == "A10" and int(r1["line"]) == 10, "an old companion record keeps its last fallen and the full line (%s, line %d)" % [str(r1["fallen"]), int(r1["line"])])
	var j := JSON.stringify(e.to_dict())
	ok(JSON.stringify(_reload(e).to_dict()) == j, "the folded old save round-trips exactly")
	for i in 300:
		if e.state == "succession":
			e.choose_heir(0)
		elif e.state == "life":
			GameBot.step(e)
	var dead := e.gen - 1 if e.state == "life" else e.gen
	ok(e.gen > 901 and e.history.size() == keep + 1 and e.ancestor_count() == dead, "it plays on, still folding (gen %d, %d ancestors)" % [e.gen, e.ancestor_count()])


## The save without its Age summaries, which grow by one entry an Age.
func _rest_of_save(d: GameDynasty) -> int:
	var raw := d.to_dict()
	raw["ages"] = {}
	return JSON.stringify(raw).length()


## Real autopilot lives in short Ages (companions hired and lost, notices, events, sickness,
## legends rising again): every list a save keeps stays within what the data allows.
func test_real_lives_bounded() -> void:
	_override("age_length", 25)
	_override("history_full_keep", 12)
	var d := _new(31, "ranger", "human")
	var rest := {}
	var guard := 0
	while d.gen < 120 and guard < 1000:
		guard += 1
		if d.state == "succession":
			if d.gen in [60, 119]:
				rest[d.gen] = _rest_of_save(d)
			GameBot.choose_best(d)
		elif d.state == "life":
			GameBot.live_life(d)
		else:
			break
	var keep := int(GameAges.setting("history_full_keep"))
	ok(d.gen == 120 and d.ancestor_count() == 119 and d.history.size() == keep + 1, "119 lives lived by the autopilot, %d in full (gen %d, %d records)" % [keep + 1, d.gen, d.history.size()])
	ok(d.ages.summaries.size() == GameAges.age_of(int(d.history[1]["gen"]) - 1), "one summary for each Age folded away (%d)" % d.ages.summaries.size())
	var legends := GameData.creatures.filter(func(c): return c.get("boss", false))
	for s in d.ages.summaries:
		ok((s["legends"] as Array).size() <= legends.size() and (s["causes"] as Dictionary).size() <= 8, "Age %d's summary stays small" % int(s["age"]))
	var names: Array = d.heirlooms.map(func(x): return x["name"])
	ok(names.size() <= legends.size() and names.all(func(n): return names.count(n) == 1), "no heirloom twice, however often its legend rises (%s)" % str(names))
	var echo_keys := GameData.creatures.size() + GameData.quests.size() + GameData.events.size() + 3
	ok(d.echoes.size() <= echo_keys, "echoes are bounded by the content that makes them (%d)" % d.echoes.size())
	ok(d.flags.size() <= GameEvents.content_flags().size() + GameData.events.size(), "flags are bounded by the content that sets them (%d)" % d.flags.size())
	for id in d.party.history:
		var r: Dictionary = d.party.history[id]
		ok((r["fallen"] as Array).size() <= int(GameAges.setting("party_fallen_kept")) and (r["past"] as Array).size() <= int(GameParty.setting("past_kept")), "%s's record is capped" % id)
	ok(d.quests.active.size() <= int(GameData.bal("quest_max_active")) and d.quests.record.size() <= GameData.quests.size(), "the quest log is bounded")
	print("  real lives: save without summaries %s bytes at gen 60, %s at gen 119; %d summaries, %d echoes, %d flags, %d party records" % [GameText.num(rest.get(60, 0)), GameText.num(rest.get(119, 0)), d.ages.summaries.size(), d.echoes.size(), d.flags.size(), d.party.history.size()])
	ok(rest.has(60) and rest.has(119) and float(rest[119]) < float(rest[60]) * 1.5 and int(rest[119]) < 150000, "sixty more lives do not grow the rest of the save (%s)" % str(rest))
	var e := _reload(d)
	ok(JSON.stringify(e.to_dict()) == JSON.stringify(d.to_dict()), "the long run round-trips exactly")
	_restore()


func test_party_records_bounded() -> void:
	var d := _new(11)
	d.heir.gold = 10000000
	d.world.visit("hearthmere")
	var kept := int(GameAges.setting("party_fallen_kept"))
	for i in 15:
		if d.party.history.has("bren_cask"):
			d.party.history["bren_cask"]["gen"] = d.gen - 10   # the mourning is over
		var hired := d.party.hire(d, "bren_cask")
		var m := d.party.member("bren_cask")
		ok(not m.is_empty(), "Bren's line hired again (%d): %s" % [i, hired])
		if m.is_empty():
			return
		d.party._fall(d, m)
	var r: Dictionary = d.party.history["bren_cask"]
	ok((r["fallen"] as Array).size() == kept and int(r["line"]) == 15, "15 fell, the last %d are named and the line counts 15 (%d)" % [kept, int(r["line"])])
	ok((r["past"] as Array).size() <= int(GameParty.setting("past_kept")), "the past list stays capped")
	var e := _reload(d)
	ok(e.party.history["bren_cask"]["fallen"] == r["fallen"] and int(e.party.history["bren_cask"]["line"]) == 15, "the capped record round-trips")


# ---------------------------------------------------------------- the end of the saga

## Generation 999,999, level 99,999: every number stays a positive whole number a save keeps exactly.
func test_numbers_at_the_cap() -> void:
	var d := _new(12)
	GameAges.jump_to(d, 999999)
	var h := d.heir
	h.level = 99999
	h.training = {"str": 300.0, "mag": 300.0, "agi": 300.0, "vit": 300.0}
	d.heirlooms = [{"name": "a", "boss": "x", "gen": 1}, {"name": "b", "boss": "x", "gen": 1}, {"name": "c", "boss": "x", "gen": 1}, {"name": "d", "boss": "x", "gen": 1}, {"name": "e", "boss": "x", "gen": 1}]
	h.heirloom_bonus = d.heirloom_bonus()
	h.archetype_bonus = {"hp": 0.15, "all_stats": 0.05}
	h.full_heal()
	h.gold = 1000000000000
	var nums := {
		"max HP": h.max_hp(), "max MP": h.max_mp(), "attack": int(h.attack_power()), "magic": int(h.magic_power()), "defense": int(h.defense()),
		"XP to next level": h.xp_to_next(), "potion": d.potion_price(), "sword": GameItems.price(d, "steel_sword"),
		"sell": GameItems.sell_price(d, "steel_sword"), "cleanse": GameItems.cleanse_price(d), "prayer": GameItems.prayer_price(d),
		"fee": d.party.fee(d, "pale_warden"), "upkeep": d.party.upkeep(d, "pale_warden"), "bounty": GameQuests.reward_gold(d, GameQuests.def("ks_the_unmade")),
		"quest XP": GameQuests.reward_xp(d, GameQuests.def("ks_the_unmade")), "event gold": GameEvents.gold_amount(d, 120.0), "map": d.map_price(GameData.world["maps"][0]),
		"cure": GameDisease.cure_price(d, "grave_rot"),
	}
	var foe := d._make_enemy(_creature("elder_dragon"), 1.44, 2.0, int(99999 * 1.2 * 1.6))
	nums["foe HP"] = int(foe["hp"])
	nums["foe attack"] = int(foe["atk"])
	nums["foe XP"] = int(foe["xp"])
	nums["foe gold"] = int(foe["gold"])
	var boss := d._make_enemy(_creature("the_unmade"), 1.0, 1.0, 60)
	nums["legend HP"] = int(boss["hp"])
	for k in nums:
		ok(int(nums[k]) > 0 and int(nums[k]) < EXACT_INT, "%s at the cap is %s" % [k, GameText.num(int(nums[k]))])
	print("  at the cap: HP %s, attack %s, foe HP %s, foe attack %s, sword %s gold" % [GameText.num(nums["max HP"]), GameText.num(nums["attack"]), GameText.num(nums["foe HP"]), GameText.num(nums["foe attack"]), GameText.num(nums["sword"])])
	# The messages a player reads group those numbers in thousands.
	d.world.visit("hearthmere")
	var cost := GameItems.price(d, "iron_sword")
	var bought := GameItems.buy(d, "iron_sword")
	ok(cost >= 1000000 and bought.contains(" for %s gold" % GameText.num(cost)), "a forge price reads in thousands: %s" % bought)
	var g := GameEvents.gold_amount(d, 120.0)
	var fx := GameEvents._apply(d, {"id": "probe"}, {"text": "A purse.", "gold": 120}, [])
	ok(str(fx[0]["t"]) == "+%s gold" % GameText.num(g) and g >= 1000000, "an event's purse reads %s" % str(fx[0]["t"]))
	var label: String = GameEvents.check_parts(d, {"attr": "agi", "dc": 12})[0][0]
	ok(label == "Proficiency (level 99,999)", "a check's proficiency names the level in thousands: %s" % label)
	var w := GameWorld.new()
	w.year = 151234567.25
	ok(w.date_text() == "%s of year 151,234,568" % w.season()["name"], "the calendar groups the year: %s" % w.date_text())
	# A fight at those numbers runs to its end, and the save keeps every value.
	ok(d.party.hire(d, "bren_cask").contains("joins"), "a companion hired at the cap")
	d.world.visit("whisperwood")
	d.start_hunt("hunt")
	var b := d.battle
	ok(b != null and b.enemies.all(func(e): return int(e["hp"]) > 0 and int(e["hp"]) < EXACT_INT), "hunt foes at the cap are built")
	GameBot.fight(d)
	ok(d.battle == null and h.hp >= 0 and h.hp <= h.max_hp() and h.gold > 0, "the fight resolves (%s after %d turns, HP %s, gold %s)" % [b.result, b.turn, GameText.num(h.hp), GameText.num(h.gold)])
	ok(b.log.all(func(l): return not str(l).contains("for -") and not str(l).contains("+-")), "no negative damage or healing in the log")
	if d.state == "life":
		var e := _reload(d)
		ok(JSON.stringify(e.to_dict()) == JSON.stringify(d.to_dict()) and e.heir.max_hp() == h.max_hp(), "the cap's numbers round-trip exactly")


## A dynasty moved to generation 999,990 plays to the cap, and the saga ends there.
func test_ending_at_the_cap() -> void:
	var d := _new(13, "cleric", "elf")
	GameAges.jump_to(d, 999990)
	var guard := 0
	var last_line := false
	while d.state != "ended" and guard < 40:
		guard += 1
		if d.state == "succession":
			ok(d.candidates.size() > 0, "an heir to choose at generation %d" % d.gen)
			GameBot.choose_best(d)
			if d.gen == 999999:
				last_line = d.journal.any(func(l): return str(l).ends_with("the chronicle of House %s closes with them." % d.dynasty_name))
		else:
			GameBot.live_life(d)
	ok(d.state == "ended" and d.gen == 999999, "the saga ends at generation 999,999 (state %s, gen %d)" % [d.state, d.gen])
	ok(last_line, "the last heir is told they are the last")
	ok(d.candidates.is_empty() and int(d.last_death["gen"]) == 999999 and d.history.back() == d.last_death, "no one succeeds; the last heir is in the history")
	ok(str(d.journal.back()) == "With %s the chronicle of House %s closes, after 999,999 generations and 910 Ages." % [d.heir.name, d.dynasty_name], "the journal closes the saga: %s" % str(d.journal.back()))
	ok(d.choose_heir(0).is_empty() and d.state == "ended" and d.gen == 999999, "no heir can be chosen after the end")
	ok(not GameBot.step(d) and d.state == "ended", "the autopilot has nothing left to do")
	var e := _reload(d)
	ok(e.state == "ended" and e.gen == 999999 and JSON.stringify(e.to_dict()) == JSON.stringify(d.to_dict()), "the finished save loads as finished")
	ok(e.ages.hall.size() == 5 and e.ancestor_count() == 10, "the ending's tallies survive (%d heirs)" % e.ancestor_count())
	# A save left in succession at or past the cap (the data lowered later) is finished on load.
	var f := _new(14)
	f.heir.age = f.heir.lifespan
	f.retire()
	ok(f.state == "succession", "a succession at generation 1")
	_override("max_generations", 1)
	var g := _reload(f)
	ok(g.state == "ended" and g.candidates.is_empty(), "loaded with a cap of 1, the saga is over")
	_restore()
	# The cap is data: a short saga ends where the data says.
	_override("max_generations", 3)
	var s := _new(15)
	for i in 10:
		if s.state == "ended":
			break
		_synthetic_gen(s, i)
	ok(s.state == "ended" and s.gen == 3 and s.ancestor_count() == 3, "max_generations 3 ends after the third heir (gen %d, %s)" % [s.gen, s.state])
	_restore()


func _bot_run(s: int, steps: int, reload_every: int) -> String:
	var d := _new(s, "mage", "human")
	for i in steps:
		if reload_every > 0 and i % reload_every == 0:
			d = _reload(d)
		if d.state == "succession":
			d.choose_heir(i % d.candidates.size())
		elif d.state == "life":
			GameBot.step(d)
	return JSON.stringify(d.to_dict(), "", true, true)


## Ages of 4 and a short history: the same seed lives the same saga, saved and continued or not.
func test_determinism_across_ages() -> void:
	_override("age_length", 4)
	_override("history_full_keep", 3)
	var a := _bot_run(77, 1400, 0)
	var b := _bot_run(77, 1400, 0)
	var c := _bot_run(77, 1400, 37)
	var parsed: Dictionary = JSON.parse_string(a)
	ok(int(parsed["gen"]) > 9 and (parsed["ages"]["summaries"] as Array).size() >= 2, "the run crosses several Ages (gen %d)" % int(parsed["gen"]))
	ok(a == b, "same seed, same saga across Ages")
	ok(a == c, "saving and reloading every 37 steps changes nothing")
	_restore()


# ---------------------------------------------------------------- screens

func _frames(n: int = 4) -> void:
	for i in n:
		await process_frame


func _labels(n: Node, out: Array = []) -> Array:
	if n is Label and n.is_visible_in_tree():
		out.append(n.text)
	for c in n.get_children():
		_labels(c, out)
	return out


func _button(n: Node, prefix: String) -> Button:
	if n is Button and n.is_visible_in_tree() and not n.disabled and n.text.begins_with(prefix):
		return n
	for c in n.get_children():
		var b := _button(c, prefix)
		if b != null:
			return b
	return null


func _press(from: Node, prefix: String) -> bool:
	var b := _button(from, prefix)
	if b == null:
		return false
	b.pressed.emit()
	await _frames(3)
	return true


func _find_rich(n: Node, tab: String) -> RichTextLabel:
	if n is RichTextLabel and n.name == tab:
		return n
	for c in n.get_children():
		var r := _find_rich(c, tab)
		if r != null:
			return r
	return null


func test_ui_life_and_chronicle(app: Control) -> void:
	var d := _new(21)
	for i in 30:
		_synthetic_gen(d, i)
	GameAges.jump_to(d, 999998)
	d.heir.gold = 123456789
	app.dynasty = d
	app.show_state()
	await _frames(6)
	var labels := _labels(app.current)
	ok(labels.any(func(t): return str(t).begins_with("House %s  -  Generation 999,998  -  Age 910  -  " % d.dynasty_name)), "the life screen shows the generation and the Age")
	ok(labels.has("Gold 123,456,789    Potions %d" % d.heir.potions), "gold is grouped in thousands")
	ok(labels.has("Ancestors: 30"), "every ancestor is counted on the life screen")
	ok(await _press(app.current, "Chronicle"), "the Chronicle opens")
	var chron: Node = app.current.get_children().back()
	ok(chron.get_script() == ChroniclePanel, "the Chronicle is on top")
	var ages := _find_rich(chron, "Ages")
	ok(ages != null and ages.text.contains("[b]Age 1[/b]  generations 1-30") and ages.text.contains("Age 910"), "the Ages tab tells Age 1 and the current Age")
	await _press(chron, "Close")


func test_ui_ending(app: Control) -> void:
	_override("max_generations", 2)
	var d := _new(22)
	_synthetic_gen(d, 0)
	d.heir.level = 12
	d._die("old age")
	ok(d.state == "ended", "the second heir ends a two-generation saga")
	app.dynasty = d
	d.save_to_disk()
	app.show_title()
	await _frames(4)
	ok(await _press(app.current, "Continue"), "Continue is offered for a finished save")
	await _frames(4)
	ok(str(app.current.get_script().resource_path).ends_with("ending_screen.gd"), "Continue opens the ending")
	var labels := _labels(app.current)
	ok(labels.has("The saga of House %s is over" % app.dynasty.dynasty_name), "the ending names the house")
	ok(labels.any(func(t): return str(t).begins_with("2 generations and 1 Age, ")), "it counts the generations and Ages")
	ok(labels.has("Greatest heirs") and labels.has("Legends slain") and labels.has("How they died"), "greatest heirs, legends and deaths are summed up")
	ok(labels.has("No legend fell to House %s." % app.dynasty.dynasty_name) and not labels.any(func(t): return str(t).begins_with("0 in all")), "a house that slew no legend is told so plainly")
	ok(await _press(app.current, "Chronicle"), "the Chronicle opens from the ending")
	await _press(app.current.get_children().back(), "Close")
	ok(await _press(app.current, "Main menu"), "and the ending leads back to the menu")
	_restore()
