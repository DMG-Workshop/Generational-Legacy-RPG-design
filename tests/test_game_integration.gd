## Cross-system checks for the merged build: shops/gear, quests, events and companions together.
## godot --headless --path . -s res://tests/test_game_integration.gd
## Old-save fixtures: pr3 = the PR branch before shops, quests, events and companions (b7020c7);
## pr4 = after shops, quests and events but before companions (fa7de57).
extends SceneTree

const DIR := "res://tests/fixtures/"
const UI_SAVE := "user://test_integration_ui_save.json"
const GameApp := preload("res://ui/play/game_app.gd")

var checks := 0
var fails := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _new(s: int, cls: String = "warrior", race: String = "human") -> GameDynasty:
	var d := GameDynasty.new_game(s, "Tess", cls, "faetouched", race)
	d.pending_event = {}
	return d


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


func _go(d: GameDynasty, to: String) -> Array:
	var msgs := d.travel(to)
	if d.has_pending_event():
		GameEvents.dismiss(d)
	return msgs


func _index_of(lines: Array, prefix: String, from: int = 0) -> int:
	for i in range(from, lines.size()):
		if str(lines[i]).begins_with(prefix):
			return i
	return -1


func _init() -> void:
	GameData.load_all()
	test_event_fight_with_companions()
	test_quest_kills_from_hunts_and_bosses()
	test_journal_order_on_travel()
	test_upkeep_and_shopping_vs_gold()
	test_cleanse_event_curse()
	test_succession_carries_everything()
	test_full_round_trip()
	test_old_saves()
	test_determinism()
	test_setbacks_without_gold()
	test_journal_survives_reload()
	test_snapped_values_reload_exactly()
	test_long_continuity()
	test_flag_from_event_completes_quest()
	_ui_tests.call_deferred()


## Screens need a live scene tree, so these run once it is up. They save to a test file.
func _ui_tests() -> void:
	var real_path := GameDynasty.save_path
	GameDynasty.save_path = UI_SAVE
	root.size = Vector2i(1280, 720)   # headless starts tiny; clicks need the real window
	var app: Control = GameApp.new()
	root.add_child(app)
	await _frames()
	await test_ui_event_death_is_saved(app)
	await test_ui_map_purchase_is_saved(app)
	app.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(UI_SAVE))
	GameDynasty.save_path = real_path
	print("integration: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- events x companions x quests

func test_event_fight_with_companions() -> void:
	var d := _new(11)
	d.heir.gold = 5000
	ok(d.party.hire(d, "bren_cask").contains("joins"), "hire Bren in Hearthmere")
	ok(d.party.hire(d, "maddy_thorn").contains("joins"), "hire Maddy in Hearthmere")
	d.quests.accept(d, "hm_wolf_cull")
	ok(d.quests.is_active("hm_wolf_cull"), "wolf cull taken")
	_go(d, "whisperwood")
	ok(d.world.location == "whisperwood", "in Whisperwood")
	ok(GameEvents.begin(d, "wolf_den"), "wolf den event opens")
	var age := d.heir.age
	d.resolve_event(0)
	var b := d.battle
	ok(b != null, "the wolf den choice starts a fight")
	if b == null:
		return
	ok(d.battle_kind == "event", "battle kind is event")
	ok(b.allies.size() == 2, "both companions fight the event battle (%d)" % b.allies.size())
	ok(b.enemies.size() == 2 and b.enemies.all(func(e): return e["id"] == "wolf"), "two wolves")
	var msgs := _win(d)
	ok(d.battle == null and d.state == "life", "event fight won")
	ok(is_equal_approx(d.heir.age - age, float(GameData.bal("event_fight_years"))), "event fight costs event_fight_years after victory (%.2f)" % (d.heir.age - age))
	ok(int(d.quests.entry("hm_wolf_cull")["progress"]) == 2, "event fight kills count for the wolf cull (%d)" % int(d.quests.entry("hm_wolf_cull")["progress"]))
	ok(d.party.members.all(func(m): return int(m["battles"]) == 1), "companions record the event battle")
	ok(GameEvents.stage(d) == "result" or not d.has_pending_event(), "event left at its result")
	ok(_index_of(msgs, "Victory!") >= 0, "victory line returned")


func test_quest_kills_from_hunts_and_bosses() -> void:
	var d := _new(12)
	d.heir.gold = 5000
	d.heir.level = 20
	d.heir.full_heal()
	d.party.hire(d, "bren_cask")
	d.quests.accept(d, "hm_wolf_cull")
	d.quests.accept(d, "hm_grimfang")
	ok(d.quests.active.size() == 2, "cull and Grimfang both taken")
	_go(d, "whisperwood")
	var done_seen := false
	for i in 40:
		if d.quests.is_complete(d.quests.entry("hm_wolf_cull")):
			break
		var before := int(d.quests.entry("hm_wolf_cull")["progress"])
		d.start_hunt("hunt")
		var wolves := d.battle.enemies.filter(func(e): return e["id"] == "wolf").size()
		var msgs := _win(d)
		var after := int(d.quests.entry("hm_wolf_cull")["progress"])
		ok(after == mini(5, before + wolves), "hunt %d: progress %d -> %d with %d wolves" % [i, before, after, wolves])
		var qd := _index_of(msgs, "Quest done: Cull the Wolves")
		if qd >= 0:
			done_seen = true
			ok(qd > _index_of(msgs, "Victory!"), "the quest note follows the Victory line")
			var j := d.journal.size() - 1
			while j >= 0 and not str(d.journal[j]).begins_with("Quest done: Cull"):
				j -= 1
			ok(j > 0 and _index_of(d.journal, "Victory!", maxi(0, j - 4)) < j, "journal: Victory before Quest done")
		d.heir.full_heal()
	ok(done_seen, "the cull completed from hunts")
	ok(d.available_boss().get("id", "") == "grimfang", "Grimfang lairs here")
	d.start_legend()
	ok(d.battle != null and d.battle.allies.size() == 1, "legend fight with a companion")
	var msgs := _win(d)
	ok(d.slain_bosses.has("grimfang"), "Grimfang slain")
	ok(d.quests.is_complete(d.quests.entry("hm_grimfang")), "boss kill completes the bounty")
	ok(_index_of(msgs, "Quest done: The Alpha") > _index_of(msgs, "Victory!"), "boss quest note after Victory")
	_go(d, "hearthmere")
	var gold := d.heir.gold
	d.quests.turn_in(d, "hm_wolf_cull")
	d.quests.turn_in(d, "hm_grimfang")
	ok(d.quests.active.is_empty() and d.heir.gold > gold, "both paid at the board")
	ok(d.quests.times_done("hm_grimfang") == 1, "record kept")


func test_journal_order_on_travel() -> void:
	var d := _new(13)
	d.heir.level = 5
	d.quests.accept(d, "hm_mirefen_lantern")
	var msgs := _go(d, "mirefen")
	var t := _index_of(msgs, "Tess travels to Mirefen")
	var q := _index_of(msgs, "Quest done: The Mirefen Lantern")
	ok(t >= 0 and q > t, "returned: travel line %d before quest note %d" % [t, q])
	var jt := -1
	var jq := -1
	for i in d.journal.size():
		if str(d.journal[i]).begins_with("Tess travels to Mirefen"):
			jt = i
		if str(d.journal[i]).begins_with("Quest done: The Mirefen Lantern"):
			jq = i
	ok(jt >= 0 and jq > jt, "journal: travel line %d before quest note %d" % [jt, jq])
	ok(d.journal.filter(func(l): return str(l).begins_with("Quest done: The Mirefen")).size() == 1, "quest note journaled once")


func test_flag_from_event_completes_quest() -> void:
	# The Long Watch completes on rift_open; a flag set by an event outcome reports after it.
	var d := _new(14)
	d.gen = 60
	d.heir.gen = 60
	d.set_flag("rift_seal_seen")
	d.quests.accept(d, "hm_long_watch")
	ok(d.quests.is_active("hm_long_watch"), "Long Watch taken")
	var out: Array = []
	d.set_flag("rift_open", out)
	ok(out.size() == 1 and str(out[0]).begins_with("Quest done: The Long Watch"), "flag hook hands its note to the caller")
	ok(d.quests.is_complete(d.quests.entry("hm_long_watch")), "flag quest complete")


# ---------------------------------------------------------------- gold: upkeep and shops

func test_upkeep_and_shopping_vs_gold() -> void:
	var d := _new(21)
	d.heir.gold = 300
	var g0 := d.heir.gold
	var fee := d.party.fee(d, "bren_cask")
	d.party.hire(d, "bren_cask")
	ok(d.heir.gold == g0 - fee, "fee paid exactly")
	var price := GameItems.price(d, "iron_sword")
	var msg := GameItems.buy(d, "iron_sword")
	ok(msg.contains("buys"), "sword bought: " + msg)
	ok(d.heir.gold == g0 - fee - price, "sword price paid exactly")
	var before := d.heir.gold
	var years := float(d.years_for("rest"))
	d.rest()
	var upkeep := d.party.upkeep(d, "bren_cask")
	ok(d.heir.gold == before - int(floor(float(upkeep) * years)), "rest: upkeep %d x %.0f years paid (%d -> %d)" % [upkeep, years, before, d.heir.gold])
	d.heir.gold = 0
	d.rest()
	ok(d.party.members.is_empty(), "unpaid companion walks out")
	ok(d.party.history["bren_cask"]["status"] == "left", "walk-out recorded")
	ok(d.heir.gold >= 0, "gold never negative")
	ok(d.journal.any(func(l): return str(l).contains("walks out")), "walk-out journaled")
	ok(GameItems.buy(d, "steel_sword").begins_with("Not enough gold") or not GameItems.sold_here(d, "steel_sword"), "no buying on credit")
	# A long autopilot run with every system active never drives gold below zero.
	var e := _new(22)
	e.heir.gold = 500
	var low := 0
	for i in 2500:
		if e.state == "succession":
			e.choose_heir(0)
		elif e.state == "life":
			GameBot.step(e)
		low = mini(low, e.heir.gold)
	ok(low >= 0, "autopilot gold never negative (min %d)" % low)
	ok(e.gen > 2, "autopilot crossed generations (gen %d)" % e.gen)
	ok(e.party.history.size() > 0, "autopilot hired companions")
	ok(e.heir.equipment.values().any(func(x): return x != ""), "autopilot wears gear")


# ---------------------------------------------------------------- temple x events

func test_cleanse_event_curse() -> void:
	var d := _new(31)
	d.world.visit("hollow_barrow")
	ok(GameEvents.begin(d, "sealed_tomb"), "sealed tomb opens")
	GameEvents.resolve_as(d, 0, "crit_failure")
	ok("cursed" in d.heir.traits, "event curse gained")
	d.pending_event = {}
	d.world.visit("hearthmere")
	d.heir.gold = 5000
	var cost := GameItems.cleanse_price(d)
	var msg := GameItems.cleanse(d, "cursed")
	ok("cursed" not in d.heir.traits and "cursed" not in d.heir.dormant, "temple lifts the event curse: " + msg)
	ok(d.heir.gold == 5000 - cost, "cleanse charged")
	ok(GameItems.temple_uses(d, "cleanse") == 1, "use counted")


# ---------------------------------------------------------------- succession

func test_succession_carries_everything() -> void:
	var d := _new(41)
	d.heir.gold = 4000
	d.heir.level = 6
	d.party.hire(d, "bren_cask")
	GameItems.buy(d, "iron_sword")
	d.give_item("copper_ring")
	d.quests.accept(d, "hm_wolf_cull")
	d.quests.entry("hm_wolf_cull")["progress"] = 2
	d.world.visit("hearthmere")
	GameItems.pray(d)
	d.heir.age = d.heir.family_min_age()
	d.found_family()
	ok(d.heir.family_founded, "family founded")
	var eq := d.heir.equipment.duplicate()
	var inv := d.heir.inventory.duplicate()
	var party_ids: Array = d.party.members.map(func(m): return m["id"])
	d.retire()
	ok(d.state == "succession", "retired into succession")
	var g := d.heir.gold
	d.choose_heir(0)
	var h := d.heir
	ok(h.equipment == eq, "gear passes down")
	ok(h.inventory == inv, "pack passes down")
	ok(h.gold >= int(float(g) * float(GameData.bal("gold_inherit_fraction"))), "gold inherited (%d of %d)" % [h.gold, g])
	ok(d.quests.is_active("hm_wolf_cull") and int(d.quests.entry("hm_wolf_cull")["progress"]) == 2, "quest and progress carried")
	ok(d.party.members.map(func(m): return m["id"]) == party_ids, "party stays")
	ok(d.party.members.all(func(m): return int(m["level"]) == h.level and int(m["gen"]) == d.gen), "party resynced to the new heir")
	var u := d.party.unit(d, d.party.members[0])
	ok(u.hp == u.max_hp(), "party rested at succession")
	ok(GameItems.temple_uses(d, "prayer") == 0, "temple counts reset for the new heir")
	ok(h.attack_power() > 0.0 and GameItems.equipped(h, "weapon") == "iron_sword", "sword still works for the new heir")
	var j := "\n".join(d.journal.slice(maxi(0, d.journal.size() - 12)))
	ok(j.contains("stays with the family") and j.contains("inherits the house's obligations"), "succession journals party and quests")


# ---------------------------------------------------------------- save / load

func _populated(s: int) -> GameDynasty:
	var d := _new(s)
	d.heir.gold = 6000
	d.heir.level = 20
	d.heir.full_heal()
	d.party.hire(d, "bren_cask")
	d.party.hire(d, "maddy_thorn")
	d.party.dismiss(d, "maddy_thorn")
	d.party.hire(d, "sister_oriel")
	GameItems.buy(d, "iron_sword")
	GameItems.buy(d, "leather_armor")
	d.give_item("copper_ring")
	d.give_item("elven_bow")
	GameItems.pray(d)
	d.quests.accept(d, "hm_wolf_cull")
	d.quests.accept(d, "hm_grimfang")
	d.set_flag("rift_seal_seen")
	_go(d, "whisperwood")
	d.start_hunt("hunt")
	_win(d)
	d.start_legend()
	_win(d)
	d.world.visit("hearthmere")
	d.quests.turn_in(d, "hm_grimfang")
	_go(d, "whisperwood")
	GameEvents.begin(d, "wolf_den")
	return d


func test_full_round_trip() -> void:
	var d := _populated(51)
	ok(d.has_pending_event() and not d.party.members.is_empty() and not d.quests.active.is_empty(), "every system has state")
	ok(not d.shop_state.is_empty() and not d.flags.is_empty() and not d.heirlooms.is_empty(), "temple, flags and heirlooms populated")
	var j1 := JSON.stringify(d.to_dict())
	var e := GameDynasty.from_dict(JSON.parse_string(j1))
	var j2 := JSON.stringify(e.to_dict())
	ok(j1 == j2, "save -> JSON -> load -> save is identical")
	var f := GameDynasty.from_dict(JSON.parse_string(j2))
	ok(JSON.stringify(f.to_dict()) == j1, "second round trip identical")
	ok(e.heir.attack_power() == d.heir.attack_power() and e.heir.max_hp() == d.heir.max_hp(), "derived stats survive")
	ok(GameItems.price(e, "steel_sword") == GameItems.price(d, "steel_sword"), "prices survive")
	ok(e.party.upkeep_total(e) == d.party.upkeep_total(d), "party survives")
	# Both copies play on identically: the pending event, its fight with allies, then the autopilot.
	d.resolve_event(0)
	e.resolve_event(0)
	ok(d.battle != null and e.battle != null and e.battle.allies.size() == d.battle.allies.size(), "loaded copy fights with its party")
	GameBot.fight(d)
	GameBot.fight(e)
	for i in 120:
		for x in [d, e]:
			if x.state == "succession":
				x.choose_heir(0)
			elif x.state == "life":
				GameBot.step(x)
	ok(JSON.stringify(d.to_dict()) == JSON.stringify(e.to_dict()), "original and loaded copy stay identical after 120 steps")


func test_old_saves() -> void:
	for tag in ["pr3_life", "pr3_succession", "pr4_life", "pr4_succession"]:
		var path := DIR + "old_save_%s.json" % tag
		var txt := FileAccess.get_file_as_string(path)
		ok(txt != "", "%s exists" % tag)
		if txt == "":
			continue
		var raw: Dictionary = JSON.parse_string(txt)
		var d := GameDynasty.from_dict(raw)
		ok(d != null and d.heir != null, "%s loads" % tag)
		ok(d.gen == int(raw["gen"]) and d.heir.level >= int(raw["heir"]["level"]), "%s keeps gen and level" % tag)
		ok(d.heir.equipment.size() == 3, "%s has gear slots" % tag)
		if d.state == "succession":
			d.choose_heir(0)
			ok(d.state == "life", "%s: succession finishes" % tag)
		d.heir.gold += 500
		var town := d.world.location
		d.world.visit("hearthmere")
		ok(d.party.hire(d, "bren_cask").contains("joins") or d.party.has_member("bren_cask"), "%s: can hire" % tag)
		GameItems.buy(d, "iron_sword")
		ok(GameItems.owns(d.heir, "iron_sword"), "%s: can buy" % tag)
		d.world.visit(town)
		for i in 400:
			if d.state == "succession":
				d.choose_heir(0)
			elif d.state == "life":
				GameBot.step(d)
		var j := JSON.stringify(d.to_dict())
		var e := GameDynasty.from_dict(JSON.parse_string(j))
		ok(JSON.stringify(e.to_dict()) == j, "%s: plays on and round-trips (gen %d)" % [tag, d.gen])


func test_determinism() -> void:
	var a := _run(4242)
	var b := _run(4242)
	ok(a[0] == b[0], "same seed, identical journals (%d lines)" % (a[0] as Array).size())
	ok(a[1] == b[1], "same seed, identical saves")
	var c := _run(4243)
	ok(c[1] != a[1], "a different seed tells a different story")


## The Chronicle shows the last JOURNAL_SAVED lines; a reload must not cut that history short.
func test_journal_survives_reload() -> void:
	var d := _new(71)
	var guard := 0
	while d.journal.size() < GameDynasty.JOURNAL_SAVED + 20 and guard < 400:
		guard += 1
		if d.state == "succession":
			d.choose_heir(0)
		else:
			GameBot.step(d)
	ok(d.journal.size() > GameDynasty.JOURNAL_SAVED, "a long journal (%d lines)" % d.journal.size())
	var e := _reload(d)
	var shown: Array = d.journal.slice(d.journal.size() - GameDynasty.JOURNAL_SAVED)
	ok(e.journal == shown, "a reload keeps every journal line the Chronicle showed (%d of %d)" % [e.journal.size(), shown.size()])


## Every Fate setback, rolled with and without gold: a penniless heir is never told of a loss.
func test_setbacks_without_gold() -> void:
	var seen := {}
	for s in range(1, 3000):
		for gold in [0, 500]:
			var d := _new(1)
			d.heir.milestones_done.erase("first_quest")
			d.heir.gold = gold
			d.heir.fate_value = 0.2
			d.rng.seed = s
			var before := d.journal.size()
			d._check_milestone("first_quest")
			var lines: Array = d.journal.slice(before)
			if lines.size() < 2:
				continue
			var text := str(lines[0])
			var sev := "critical" if text.begins_with("DISASTER") else text.get_slice(" at ", 0)
			var key := "%s/%d" % [sev, gold]
			if seen.has(key):
				continue
			seen[key] = text
			if gold == 0:
				ok(not text.to_lower().contains("you lose") and not text.contains("wealth"), "no gold, no loss claimed: " + text)
			else:
				ok(d.heir.gold < gold and text.contains("lose"), "a loss is reported when gold is lost: " + text)
		if seen.size() >= 8:
			break
	ok(seen.has("critical/0") and seen.has("critical/500"), "critical setbacks rolled with and without gold (%s)" % str(seen.keys()))
	ok(str(seen.get("critical/500", "")).contains("lose most of your wealth"), "a disaster with gold takes most of it")


## Full precision: default-precision JSON hides a value that reloads one ulp away.
func _exact(d: GameDynasty) -> String:
	return JSON.stringify(d.to_dict(), "", true, true)


func _reload(d: GameDynasty) -> GameDynasty:
	return GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))


func test_snapped_values_reload_exactly() -> void:
	var d := _new(61)
	var fates := [0.0185, 0.0272, 0.1599, 0.1924]
	d.heir.fate_value = snappedf(fates[0], GameFate.STEP)
	d.heir.age = d.heir.family_min_age()
	d.found_family()
	for i in d.heir.children.size():
		d.heir.children[i].fate_value = snappedf(fates[1 + i % 3], GameFate.STEP)
	for k in [415, 600, 710, 2125]:
		d._add_echo("slayer", "m%d" % k, "test", float(k) * GameFate.STEP)
	var e := _reload(d)
	ok(e.heir.fate_value == d.heir.fate_value, "fate value reloads to the same double (%s vs %s)" % [var_to_str(d.heir.fate_value), var_to_str(e.heir.fate_value)])
	ok(e.heir.children.size() == d.heir.children.size() and range(d.heir.children.size()).all(func(i): return e.heir.children[i].fate_value == d.heir.children[i].fate_value), "children's fate values reload exactly")
	ok(range(d.echoes.size()).all(func(i): return float(e.echoes[i]["strength"]) == float(d.echoes[i]["strength"])), "echo strengths reload exactly")
	d._decay_echoes()
	e._decay_echoes()
	ok(_exact(d) == _exact(e), "a succession's echo decay matches after a reload")


## A player who saves and continues before every action lives the same dynasty as one who never
## stops: travel, events, fights, companions and several successions, compared at full precision.
func test_long_continuity() -> void:
	var gens := 0
	for s in 3:
		var a := GameDynasty.new_game(5000 + s, "", ["warrior", "mage", "cleric"][s], "faetouched", ["human", "orc", "beastkin"][s])
		var b := _reload(a)
		var pa := RandomNumberGenerator.new()
		pa.seed = s
		var pb := RandomNumberGenerator.new()
		pb.seed = s
		var same := -1
		for i in 450:
			_wander(a, pa)
			b = _reload(b)
			_wander(b, pb)
			if _exact(a) != _exact(b):
				same = i
				break
		ok(same < 0, "seed %d: saved-and-continued dynasty matches the unsaved one (first difference at step %d)" % [s, same])
		gens += a.gen - 1
	ok(gens >= 12, "continuity runs cross many successions (%d)" % gens)


## The autopilot, with random road travel and exploring mixed in; `r` is the policy's own seeded dice.
func _wander(d: GameDynasty, r: RandomNumberGenerator) -> void:
	if d.state == "succession":
		d.choose_heir(r.randi() % d.candidates.size())
		return
	var x := r.randi() % 10
	if x < 3 and not d.has_pending_event():
		var roads := d.world.roads(d.world.location, d.flags)
		d.travel(roads[r.randi() % roads.size()]["to"])
	elif x == 3 and not d.has_pending_event():
		d.explore()
	else:
		GameBot.step(d)
	if d.has_pending_event() and d.state == "life":
		GameEvents.bot_resolve(d)


func _run(s: int) -> Array:
	var d := _new(s, "mage", "elf")
	var lines: Array = []
	for life in 4:
		GameBot.live_life(d)
		lines.append_array(d.journal)
		GameBot.choose_best(d)
	return [lines, JSON.stringify(d.to_dict())]


# ---------------------------------------------------------------- screens

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


## Presses the first enabled button whose text starts with `prefix`; false if there is none.
func _press(from: Node, prefix: String) -> bool:
	var b := _button(from, prefix)
	if b == null:
		return false
	b.pressed.emit()   # the press may rebuild the screen and free `b`
	await _frames(3)
	return true


func _labels(n: Node, out: Array = []) -> Array:
	if n is Label and n.is_visible_in_tree():
		out.append(n.text)
	for c in n.get_children():
		_labels(c, out)
	return out


## An event choice whose year ends the heir's life is on disk at once, before Continue is pressed.
func test_ui_event_death_is_saved(app: Control) -> void:
	var d := GameDynasty.new_game(4321, "Ulla", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.world.visit("frostreach")
	d.heir.age = d.heir.lifespan * 1.6
	d.heir.hazard_age = d.heir.age
	GameEvents.begin(d, "frozen_courier")
	app.dynasty = d
	app.autosave()
	app.show_state()
	await _frames(6)
	ok(await _press(app.current, "Carry the satchel"), "the courier's choice is on screen")
	ok(d.state == "succession", "the year on the road ends an old heir's life")
	var disk := GameDynasty.load_from_disk()
	ok(disk != null and disk.state == "succession" and disk.history.size() == d.history.size(), "the death is saved before the result is dismissed")
	ok(await _press(app.current, "Continue"), "the result panel offers Continue")
	await _frames(3)
	ok(str(app.current.get_script().resource_path).ends_with("succession_screen.gd"), "Continue leads to the succession")


## A map bought from the map panel is saved and shows on the life screen behind it.
func test_ui_map_purchase_is_saved(app: Control) -> void:
	app.new_game("Tess", "warrior", "faetouched", 83, "human")
	var d: GameDynasty = app.dynasty
	d.pending_event = {}
	d.heir.gold = 40
	app.autosave()
	app.show_state()
	await _frames()
	await _press(app.current, "Travel / Map")
	ok(await _press(app.current.get_children().back(), "Valley Survey"), "the Valley Survey is for sale")
	ok(d.heir.gold == 10 and not d.world.charted.is_empty(), "the survey charts places for 30 gold")
	await _press(app.current.get_children().back(), "Close")
	ok(_labels(app.current).has("Gold 10    Potions %d" % d.heir.potions), "the life screen shows the gold left")
	var disk := GameDynasty.load_from_disk()
	ok(disk.heir.gold == 10 and disk.world.charted == d.world.charted, "the purchase is saved (gold %d, %d charted)" % [disk.heir.gold, disk.world.charted.size()])
