## Hit feedback and the loot pop-out (ui/play/hit_fx.gd, damage_number.gd, loot_pop.gd; data/ui/hit_fx.json): what a number
## says for a hit, a crit, a block, a miss and a heal (in words and marks, not colour alone); which blows are heavy and how
## hard they shake the screen; the hit-stop on a kill (none in auto-battle); that reduced motion turns every motion off and
## keeps the numbers; the loot chips (rarity word and mark, a beam only for rare and better); the data checks catch each
## kind of break; and a fight played through the battle screen with all of it on ends exactly as the same fight played bare.
## Run: godot --headless --path . -s res://tests/test_game_hit_fx.gd
extends SceneTree

const Scen := preload("res://tests/round_scenarios.gd")
const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const TouchHint := preload("res://ui/play/touch_hint.gd")
const Kit := preload("res://ui/play/ui_kit.gd")
const HitFx := preload("res://ui/play/hit_fx.gd")
const DamageNumber := preload("res://ui/play/damage_number.gd")
const LootPop := preload("res://ui/play/loot_pop.gd")
const DIR := "user://test_hit_fx/"

var fails := 0
var checks := 0
var app: Node


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	GameData.load_all()
	DirAccess.make_dir_recursive_absolute(DIR)
	GameDynasty.save_path = DIR + "save.json"
	UiSettings.path = DIR + "settings.cfg"
	UiSettings.scale = 1.0
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	TouchHint.finger = false
	UiSettings.set_access("reduced_motion", false)
	test_data()
	test_numbers()
	test_heavy_and_shake()
	test_hit_stop()
	await test_reduced_motion_nodes()
	await test_number_nodes()
	test_loot_text()
	await test_loot_chips()
	test_validator_catches()
	await test_screen_unchanged()
	UiSettings.set_access("reduced_motion", false)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
	print("hit fx tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func test_data() -> void:
	HitFx.reset()
	ok(HitFx.validate().is_empty(), "hit_fx.json passes its own check %s" % str(HitFx.validate()))


func test_numbers() -> void:
	var hit := HitFx.number({"type": "damage", "amount": 12, "crit": false}, 100)
	ok(hit["text"] == "12" and hit["kind"] == "hit", "a plain hit says its number")
	var crit := HitFx.number({"type": "damage", "amount": 12, "crit": true}, 100)
	ok(crit["text"] == "12!" and crit["kind"] == "crit" and crit["size"] > hit["size"], "a crit says 12! and is bigger")
	var miss := HitFx.number({"type": "miss", "side": "enemy", "index": 0}, 0)
	ok(miss["text"] == "miss" and miss["kind"] == "miss", "a miss says miss")
	var block := HitFx.number({"type": "damage", "amount": 0, "absorbed": 7, "crit": false}, 100)
	ok(block["text"] == "block" and block["kind"] == "block", "a blow the ward soaked up says block")
	var part := HitFx.number({"type": "damage", "amount": 5, "absorbed": 3, "crit": false}, 100)
	ok("5" in part["text"] and "3" in part["text"] and "blocked" in part["text"], "a part-blocked blow says both numbers: %s" % part["text"])
	var heal := HitFx.number({"type": "heal", "amount": 8}, 0)
	ok(heal["text"].begins_with("+") and "8" in heal["text"] and heal["kind"] == "heal", "a heal says +8")
	var shatter := HitFx.number({"type": "damage", "amount": 9, "crit": false, "shatter": true}, 100)
	ok("shatter" in shatter["text"], "a shatter says so")
	ok(HitFx.number({"type": "round", "n": 1}).is_empty(), "an event with no number floats none")
	# no kind rests on colour alone: every kind's text has a digit or a word
	for n in [hit, crit, miss, block, heal]:
		ok(str(n["text"]).length() > 0, "%s has text" % n["kind"])
	ok(DamageNumber.color_of("crit", false) != DamageNumber.color_of("hit", false), "a crit is drawn in another colour than a hit")
	ok(DamageNumber.color_of("hit", true) == Kit.bad(), "a blow on the party is drawn in the bad colour")
	ok(DamageNumber.stagger(0) == Vector2.ZERO and DamageNumber.stagger(1) != Vector2.ZERO, "the second number of a flurry starts apart")
	ok(DamageNumber.letters("Poisoned").length() == int(HitFx.num("status_pop", "letters")), "a status badge has its letters")


func test_heavy_and_shake() -> void:
	ok(HitFx.is_heavy({"amount": 30, "crit": false}, 100), "a blow of a quarter of the health is heavy")
	ok(not HitFx.is_heavy({"amount": 5, "crit": false}, 100), "a small blow is not heavy")
	ok(HitFx.is_heavy({"amount": 1, "crit": true}, 100), "a crit is heavy")
	ok(HitFx.shake_px({"amount": 5, "crit": false}, 100, false) == 0.0, "an ordinary blow does not shake the screen")
	ok(HitFx.shake_px({"amount": 30, "crit": false}, 100, false) == HitFx.num("shake", "heavy_px"), "a heavy blow shakes a little")
	ok(HitFx.shake_px({"amount": 5, "crit": true}, 100, false) == HitFx.num("shake", "crit_px"), "a crit shakes more")
	ok(HitFx.shake_px({"amount": 5, "crit": false}, 100, true) == HitFx.num("shake", "kill_px"), "a kill shakes")
	ok(HitFx.nudge_px({"amount": 5}, 100) == HitFx.num("nudge", "px") and HitFx.nudge_px({"amount": 40}, 100) == HitFx.num("nudge", "heavy_px"), "a heavy blow knocks back further")
	ok(HitFx.nudge_px({"amount": 0}, 100) == 0.0, "a blow that does nothing does not push")


func test_hit_stop() -> void:
	UiSettings.set_access("reduced_motion", false)
	ok(HitFx.stop_seconds(false, false) == HitFx.num("hit_stop", "kill_seconds"), "a kill stops the figures a moment")
	ok(HitFx.stop_seconds(true, false) > HitFx.stop_seconds(false, false), "a killing crit holds longer")
	ok(HitFx.stop_seconds(true, true) == 0.0, "auto-battle is not slowed by a hit-stop")
	UiSettings.set_access("reduced_motion", true)
	ok(HitFx.stop_seconds(true, false) == 0.0, "reduced motion has no hit-stop")
	UiSettings.set_access("reduced_motion", false)


func test_reduced_motion_nodes() -> void:
	var holder := Control.new()
	root.add_child(holder)
	var node := Control.new()
	node.position = Vector2(40, 40)
	holder.add_child(node)
	UiSettings.set_access("reduced_motion", true)
	HitFx.shake(node, 8.0, "k")
	HitFx.nudge(node, 12.0)
	HitFx.collapse(node, "k")
	ok(not node.has_meta("fx_shake_tween") and not node.has_meta("fx_nudge_tween") and node.rotation == 0.0, "reduced motion: no shake, nudge or collapse starts")
	var n := DamageNumber.spawn(holder, Vector2(10, 10), "12", Color.WHITE, 26, "hit", "k")
	ok(n.text == "12" and n.scale == Vector2.ONE, "reduced motion: the number is there, without a pop")
	var badge := DamageNumber.status_pop(holder, Vector2(10, 40), "Poisoned", Color.GREEN, "k")
	ok(badge.scale == Vector2.ONE, "reduced motion: a status badge shows without a pop")
	UiSettings.set_access("reduced_motion", false)
	HitFx.nudge(node, 12.0)
	ok(node.has_meta("fx_nudge_tween"), "with motion, a nudge starts")
	HitFx.shake(node, 8.0, "k")
	ok(node.has_meta("fx_shake_tween"), "with motion, a shake starts")
	await _frames(3)
	holder.queue_free()


func test_number_nodes() -> void:
	var holder := Control.new()
	root.add_child(holder)
	UiSettings.set_access("reduced_motion", false)
	var n := DamageNumber.spawn(holder, Vector2(10, 10), "12!", Color.WHITE, 36, "crit", "k")
	ok(n.scale.x > 1.5, "a crit number pops in large")
	var badge := DamageNumber.status_pop(holder, Vector2(10, 40), "Poisoned", Color.GREEN, "k")
	var words := ""
	for c in badge.get_children():
		words += " " + c.get_class() + ":" + (c.get_child(0).text if c is PanelContainer else (c as Label).text)
	ok("POI" in words and "Poisoned" in words, "a status badge has its letters and its name: %s" % words)
	await _frames(3)
	holder.queue_free()


# ---------------------------------------------------------------- loot

func test_loot_text() -> void:
	var rows: Array = GameLoot.data()["rarities"]
	var marks := {}
	for r in rows:
		var inf := LootPop.info(str(r["id"]))
		ok(str(inf["word"]) == str(r["name"]), "%s has its own word" % r["id"])
		if str(r["id"]) != "common":
			ok(str(inf["mark"]) != "", "%s has a mark besides its colour" % r["id"])
		marks[str(inf["mark"])] = true
	ok(marks.size() == rows.size(), "every rarity has its own mark")
	ok(LootPop.info("rare")["beam"] and LootPop.info("mythic")["beam"], "rare and better throw a beam")
	ok(not LootPop.info("common")["beam"] and not LootPop.info("fine")["beam"], "common and fine do not")
	ok(LootPop.rarity_of("not_an_item") == "common", "an unknown item is common")
	var before := ["a", "b", "b"]
	var after := ["a", "b", "b", "b", "c"]
	ok(LootPop.gained(before, after) == ["b", "c"], "what the pack gained: %s" % str(LootPop.gained(before, after)))
	ok(LootPop.gained(after, before).is_empty(), "nothing gained when the pack only shrank")
	var id := _generated("epic")
	ok(id != "", "an epic item can be built")
	var text := LootPop.text_of(id)
	ok("Epic" in text and "**" in text and GameItems.item_name(id) in text, "the item's line says its rarity as word and mark: %s" % text)


func _generated(rarity: String) -> String:
	for r in 200:
		var rng := RandomNumberGenerator.new()
		rng.seed = r + 1
		var id := GameLoot.roll_item(rng, 30, 1000.0)
		if GameLoot.rarity_name(id) == rarity:
			return id
	return ""


func test_loot_chips() -> void:
	var host := Control.new()
	host.size = Vector2(800, 600)
	root.add_child(host)
	var box := VBoxContainer.new()
	host.add_child(box)
	var ids: Array = []
	for rarity in ["common", "rare", "epic"]:
		var id := _generated(rarity)
		if id != "":
			ids.append(id)
	ok(ids.size() >= 2, "items of several rarities were built")
	UiSettings.set_access("reduced_motion", true)
	var strip := LootPop.pop_out(host, box, ids, [Vector2(100, 100)])
	var flow: Node = strip.get_child(1)
	ok(flow.get_child_count() == ids.size(), "one chip for each item found")
	for k in ids.size():
		var words: String = flow.get_child(k).find_child("Words", true, false).text
		ok(LootPop.info(LootPop.rarity_of(ids[k]))["word"] in words, "chip %d names its rarity: %s" % [k, words])
	ok(host.get_child_count() == 1, "reduced motion: nothing flies, nothing beams")
	ok(LootPop.pop_out(host, box, [], []) == null, "nothing found shows nothing")
	await _frames(3)
	strip.queue_free()
	UiSettings.set_access("reduced_motion", false)
	var strip2 := LootPop.pop_out(host, box, ids, [Vector2(100, 100), Vector2(160, 100)])
	await _frames(6)
	ok(host.get_child_count() > 1, "with motion, a picture flies for each item")
	var beams := 0
	await create_timer(2.0).timeout
	ok(host.get_child_count() == 1, "the flying pictures and beams clean themselves up (%d left)" % (host.get_child_count() - 1))
	var b := LootPop.beam(host, Vector2(50, 200), Color.AQUA)
	ok(b.size.y == HitFx.num("loot", "beam_height") and b.position.y < 200.0, "a beam stands above its place")
	await _frames(3)
	strip2.queue_free()
	host.queue_free()
	ok(beams == 0, "ok")


# ---------------------------------------------------------------- the data's check

func test_validator_catches() -> void:
	var base: Dictionary = HitFx.data().duplicate(true)
	var breaks := {
		"a missing section": func(d): d.erase("shake"),
		"a zero size": func(d): d["numbers"]["size"] = 0,
		"a shake that throws the arena": func(d): d["shake"]["crit_px"] = 40.0,
		"a stalling hit-stop": func(d): d["hit_stop"]["kill_seconds"] = 0.9,
		"a rarity with no mark": func(d): d["loot"]["rarity"]["epic"]["mark"] = "",
		"a rarity with no colour": func(d): d["loot"]["rarity"]["rare"]["color"] = "nope",
		"a missing rarity": func(d): d["loot"]["rarity"].erase("mythic"),
		"an unknown beam rarity": func(d): d["loot"]["beam_from"] = "shiny",
	}
	for what in breaks:
		var d: Dictionary = base.duplicate(true)
		breaks[what].call(d)
		HitFx._data = d
		HitFx._loaded = true
		ok(not HitFx.validate().is_empty(), "hit_fx.json: %s is caught" % what)
	HitFx.reset()
	ok(HitFx.validate().is_empty(), "the real data is fine again")


# ---------------------------------------------------------------- the screen

func _end(d: GameDynasty, b: GameBattle) -> Dictionary:
	var state := Scen.state_of(b)
	state.erase("rng")
	var flat := func(v: Variant) -> String: return JSON.stringify(JSON.parse_string(JSON.stringify(v)))
	return {"log": flat.call(b.log), "events": flat.call(b.events), "state": flat.call(state), "rng": str(b.rng.state), "dynasty": flat.call(Scen.drop_sex(d.to_dict()))}


func _labels(n: Node, out: Array) -> Array:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_labels(c, out)
	return out


func test_screen_unchanged() -> void:
	root.size = Vector2i(1280, 720)
	await _frames(2)
	app = GameApp.new()
	root.add_child(app)
	await _frames(2)
	app.new_game("Tess", "warrior", "faetouched", 77, "human")
	for reduced in [false, true]:
		UiSettings.set_access("reduced_motion", reduced)
		for c in [[6, "paladin", 2, "hunt"], [9, "mage", 1, "legend"]]:
			var tag := "%d %s x%d %s (reduced motion %s)" % [c[0], c[1], c[2], c[3], str(reduced)]
			var d := Scen.make(c[0], c[1], c[2], c[3])
			var b := d.battle
			var guard := 0
			while not b.is_over() and guard < Scen.GUARD:
				guard += 1
				GameTactics.auto_turn(b)
			d.finish_battle()
			var bare := _end(d, b)
			var d2 := Scen.make(c[0], c[1], c[2], c[3])
			app.dynasty = d2
			d2.auto_battle = false
			app.show_state()
			await _frames(4)
			var bv: Control = app.current
			var b2 := d2.battle
			guard = 0
			var seen_number := false
			var arena_pos: Vector2 = bv.arena.position
			while not b2.is_over() and guard < Scen.GUARD:
				guard += 1
				await bv._do(func(): GameTactics.auto_turn(b2))
				for t in _labels(bv.arena, []):
					if t.strip_edges().is_valid_int() or t.ends_with("!") or t == "miss" or t == "block" or t.begins_with("+"):
						seen_number = true
			await _frames(2)
			ok(seen_number, "%s: damage numbers were shown" % tag)
			await create_timer(0.6).timeout
			ok(bv.arena.position.distance_to(arena_pos) < 0.01 or bv.arena.has_meta("fx_shake_tween") == false, "%s: the arena is back in its place" % tag)
			ok(bv.arena.process_mode == Node.PROCESS_MODE_INHERIT, "%s: the hit-stop let the arena go" % tag)
			d2.finish_battle()
			var shown := _end(d2, b2)
			ok(shown["events"] == bare["events"], "%s: the same battle events" % tag)
			ok(shown["log"] == bare["log"] and shown["state"] == bare["state"] and shown["rng"] == bare["rng"] and shown["dynasty"] == bare["dynasty"], "%s: the same log, end, dice and dynasty" % tag)
	UiSettings.set_access("reduced_motion", false)
