## Saves made in the middle of a fight (GameDynasty.to_save, GameBattle and GameRound to_dict / restore) and save
## versions (GameSaveVersion). A fight saved after any turn and loaded again plays on exactly as one that was
## never saved: the same log, the same end, the same dice, for scripted heirs and auto-battle, solo and with a
## party, hunts and legends, and party rounds through GameRound with a "Cover this ally?" question waiting. The
## save file carries version 2 and an old (version 1) save still loads; a save from a newer game is turned away
## with a reason; a damaged fight or one whose companion has gone loads as the dynasty before the fight.
## Closing the game mid-fight and opening it again shows the fight going on.
## Run: godot --headless --path . -s res://tests/test_game_battle_saves.gd
extends SceneTree

const Scen := preload("res://tests/round_scenarios.gd")
const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const TouchHint := preload("res://ui/play/touch_hint.gd")
const DIR := "user://test_battle_saves/"
const TRIO := ["sister_oriel", "bren_cask", "tarsk_ember_eye"]

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	DirAccess.make_dir_recursive_absolute(DIR)
	test_versions()
	test_exact_direct()
	test_exact_rounds()
	test_question_waiting()
	test_damaged_fights()
	await test_close_and_reopen()
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
	print("battle saves tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## A dynasty through its save file and back, as the game does it: to_save, JSON, the version chain, from_dict.
func _reload(d: GameDynasty) -> GameDynasty:
	var parsed = JSON.parse_string(JSON.stringify(d.to_save()))
	if typeof(parsed) != TYPE_DICTIONARY or GameSaveVersion.upgrade(parsed) != "":
		return null
	return GameDynasty.from_dict(parsed)


## A value as a save would hold it, so ints and floats of the same worth compare alike.
func _flat(v: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(v)))


func _end(d: GameDynasty, b: GameBattle) -> Dictionary:
	var state := Scen.state_of(b)
	state.erase("rng")
	return {"log": _flat(b.log), "state": _flat(state), "rng": str(b.rng.state), "dynasty": _flat(Scen.drop_sex(d.to_dict()))}


# ---------------------------------------------------------------- versions

func test_versions() -> void:
	var d := GameDynasty.new_game(5, "Ann", "mage", "faetouched", "elf")
	d.pending_event = {}
	ok(int(d.to_save()["version"]) == GameSaveVersion.CURRENT and not d.to_save().has("battle"), "a save between fights is written at the current version, with no fight in it")
	ok(int(d.to_dict()["version"]) == 1, "to_dict keeps the shape the golden digests were taken from")
	var old: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	ok(GameSaveVersion.of(old) == 1 and GameSaveVersion.upgrade(old) == "" and int(old["version"]) == GameSaveVersion.CURRENT, "a version 1 save is upgraded step by step")
	var none: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	none.erase("version")
	ok(GameSaveVersion.of(none) == 1 and GameSaveVersion.upgrade(none) == "", "a save that names no version is taken as version 1")
	var odd: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	odd["battle"] = "anything"
	GameSaveVersion.upgrade(odd)
	ok(not odd.has("battle"), "a version 1 save never brings a fight with it")
	var path := DIR + "slot.json"
	GameSaves.write_atomic(path, JSON.stringify(d.to_dict()))
	var loaded := GameSaves.load_file(path)
	ok(loaded != null and loaded.heir.name == "Ann" and loaded.battle == null, "an old save file still loads")
	var newer: Dictionary = d.to_save()
	newer["version"] = GameSaveVersion.CURRENT + 1
	GameSaves.write_atomic(path, JSON.stringify(newer))
	ok(GameSaves.load_file(path) == null, "a save from a newer game is not read")
	var text := "GLBK1:" + Marshalls.raw_to_base64(JSON.stringify(newer).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	var res := GameSaves.import_text(text)
	ok(not bool(res["ok"]) and str(res["error"]).contains("newer version"), "and a backup from one is turned away with a reason: %s" % res["error"])
	var keep := GameSaves.base
	GameSaves.base = DIR + "peek.json"
	GameSaves.write_atomic(GameSaves.path_for(1), JSON.stringify(newer))
	ok(not bool(GameSaves.peek(1)["valid"]), "its slot shows as one this game cannot open")
	GameSaves.delete(1)
	GameSaves.base = keep


# ---------------------------------------------------------------- exact

## One fight played to its end, reloaded after every `every` turns when asked; the scripted heir as the golden
## scenarios play them, or auto_turn.
func _play(mode: String, seed_val: int, cls: String, n: int, kind: String, every: int) -> Dictionary:
	var d := Scen.make(seed_val, cls, n, kind)
	var guard := 0
	while not d.battle.is_over() and guard < Scen.GUARD:
		guard += 1
		var b := d.battle
		if mode == "auto_turn":
			GameTactics.auto_turn(b)
		else:
			var coat := Scen.script_coat(b, seed_val)
			if coat != "":
				b.coat_blade(coat)
			var before := b.turn
			Scen.direct(b, Scen.script_cmd(b, seed_val))
			if b.result == "" and b.turn == before:
				b.attack(b.first_target())
		if every > 0 and guard % every == 0:
			d = _reload(d)
			if d == null or d.battle == null:
				return {"broken": guard}
	var last := d.battle
	d.finish_battle()
	return _end(d, last)


func test_exact_direct() -> void:
	var cases := [["manual", 3, "warrior", 0, "hunt"], ["manual", 4, "mage", 1, "hunt"], ["manual", 8, "cleric", 3, "hunt_hard"],
		["manual", 11, "rogue", 3, "legend"], ["auto_turn", 6, "paladin", 3, "hunt"], ["auto_turn", 9, "spellblade", 1, "legend"],
		["manual", 14, "mage", 3, "legend"], ["auto_turn", 17, "warrior", 0, "hunt_hard"]]
	for c in cases:
		var tag := "%s %d %s x%d %s" % c
		var plain := _play(c[0], c[1], c[2], c[3], c[4], 0)
		for every in [1, 3]:
			var saved := _play(c[0], c[1], c[2], c[3], c[4], every)
			ok(not saved.has("broken"), "%s: the fight reloads after every %d turns" % [tag, every])
			if saved.has("broken"):
				continue
			ok(saved["log"] == plain["log"], "%s, saved every %d: the same log" % [tag, every])
			ok(saved["state"] == plain["state"] and saved["rng"] == plain["rng"], "%s, saved every %d: the same end and the same dice" % [tag, every])
			ok(saved["dynasty"] == plain["dynasty"], "%s, saved every %d: the same dynasty afterwards" % [tag, every])


## Party rounds through GameRound, the heir by hand and the companions on Auto, reloaded between rounds and
## also with commands queued but not yet played.
func _rounds(seed_val: int, cls: String, kind: String, reload: bool) -> Dictionary:
	var d := Scen.make(seed_val, cls, 3, kind)
	d.auto_party = {"companion_default": true}
	var guard := 0
	while not d.battle.is_over() and guard < Scen.GUARD:
		guard += 1
		var b := d.battle
		var r := d.battle_round()
		if r.state_of(-1) == "ready" and r.queue(-1, Scen.script_cmd(b, seed_val)) != "":
			r.queue(-1, {"act": "attack", "target": "enemy:%d" % b.first_target()})
		if reload:   # the heir's command is queued and the round not yet played
			d = _reload(d)
			if d == null or d.battle == null or d.command_round == null:
				return {"broken": guard}
			r = d.battle_round()
		if not r.resolve()["played"]:
			break
		if reload:
			d = _reload(d)
			if d == null or d.battle == null:
				return {"broken": guard}
	var last := d.battle
	d.finish_battle()
	d.auto_party = {}
	return _end(d, last)


func test_exact_rounds() -> void:
	for c in [[5, "warrior", "hunt"], [12, "cleric", "hunt_hard"], [21, "mage", "legend"]]:
		var tag := "rounds %d %s %s" % c
		var plain := _rounds(c[0], c[1], c[2], false)
		var saved := _rounds(c[0], c[1], c[2], true)
		ok(not saved.has("broken"), "%s: the fight and its round reload, queued commands and all" % tag)
		if saved.has("broken"):
			continue
		ok(saved["log"] == plain["log"] and saved["state"] == plain["state"] and saved["rng"] == plain["rng"], "%s: the same fight as one never saved" % tag)
		ok(saved["dynasty"] == plain["dynasty"], "%s: the same dynasty afterwards" % tag)


# ---------------------------------------------------------------- a question waiting

func _asking_round() -> GameDynasty:
	var d := GameDynasty.new_game(77, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.level = 30
	d.heir.potions = 0
	d.world.visit("kingshold")
	for id in TRIO:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": 30, "gen": 1,
			"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
		d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
			"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	d.party.rest(d)
	d.heir.full_heal()
	var foes: Array = []
	for i in 3:
		foes.append(d._make_enemy(GameCombat.creature_def("wolf"), 1.0, 1.0, d.heir.level))
	d._begin_battle(foes, "hunt")
	for e in d.battle.enemies:
		e["hp"] = 10000000
		e["max_hp"] = 10000000
		e["atk"] = 4.0
	d.heir.hp = maxi(1, int(float(d.battle.unit_numbers(-1)["max_hp"]) * 0.2))
	var r := d.battle_round()
	r.ask_reactions = true
	for by in r.members():
		r.queue(by, {"act": "attack", "target": "enemy:0"})
	r.resolve()
	return d


func test_question_waiting() -> void:
	var a := _asking_round()
	ok(a.battle_round().asking(), "a round stops to ask who steps in front of the hurt heir")
	var b := _reload(a)
	ok(b != null and b.battle != null and b.command_round != null, "the fight and its round load with the question waiting")
	if b == null or b.battle == null or b.command_round == null:
		return
	var r := b.battle_round()
	r.ask_reactions = true   # the battle screen sets it again
	ok(r.asking() and r.reaction_view().get("by", []) == a.battle_round().reaction_view().get("by", []), "the same question is asked")
	a.battle_round().answer(1)
	r.answer(1)
	a.battle_round().resolve()
	r.resolve()
	ok(_flat(b.battle.log) == _flat(a.battle.log) and str(b.rng.state) == str(a.rng.state), "answered the same way, both play on alike")


# ---------------------------------------------------------------- damaged fights

func test_damaged_fights() -> void:
	var d := Scen.make(31, "warrior", 3, "hunt")
	d.battle.attack(d.battle.first_target())
	var good: Dictionary = JSON.parse_string(JSON.stringify(d.to_save()))
	var broken := good.duplicate(true)
	broken["battle"] = "not a fight at all"
	var b := GameDynasty.from_dict(broken)
	ok(b != null and b.battle == null and b.heir.name == d.heir.name, "a damaged fight loads as the dynasty before it")
	var gone := good.duplicate(true)
	gone["party"]["members"] = (gone["party"]["members"] as Array).slice(1)
	var g := GameDynasty.from_dict(gone)
	ok(g != null and g.battle == null, "so does a fight whose companion has left the party")
	var kept := GameDynasty.from_dict(good.duplicate(true))
	ok(kept != null and kept.battle != null and kept.battle.resumed and kept.battle_kind == "hunt", "the whole save loads with its fight")
	var path := GameDynasty.save_path
	GameDynasty.save_path = DIR + "mid.json"
	ok(d.save_to_disk() and FileAccess.get_file_as_string(DIR + "mid.json").contains("\"battle\""), "the game now saves in the middle of a fight")
	GameDynasty.save_path = path


# ---------------------------------------------------------------- closing the game mid-fight

func test_close_and_reopen() -> void:
	GameDynasty.save_path = DIR + "save.json"
	UiSettings.path = DIR + "settings.cfg"
	UiSettings.scale = 1.0
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	TouchHint.finger = false
	root.size = Vector2i(1280, 720)
	var app: Node = GameApp.new()
	root.add_child(app)
	for i in 2:
		await process_frame
	app.new_game("Tess", "warrior", "faetouched", 77, "human")
	var d: GameDynasty = app.dynasty
	d.pending_event = {}
	d.auto_battle = false
	d._begin_battle([d._make_enemy(GameCombat.creature_def("wolf"), 1.0, 1.0, 10)], "hunt")
	d.battle.enemies[0]["hp"] = 1000000
	d.battle.enemies[0]["max_hp"] = 1000000
	d.battle.attack(0)
	var turn := d.battle.turn
	var foe_hp := int(d.battle.enemies[0]["hp"])
	app.show_state()
	for i in 3:
		await process_frame
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)   # the phone puts the game away
	app.queue_free()
	for i in 2:
		await process_frame
	var again: Node = GameApp.new()
	root.add_child(again)
	for i in 2:
		await process_frame
	again.continue_game()
	for i in 4:
		await process_frame
	var e: GameDynasty = again.dynasty
	ok(e != null and e.battle != null and e.battle.turn == turn and int(e.battle.enemies[0]["hp"]) == foe_hp, "opened again, the fight is where it was left")
	var bv: Node = again.current
	ok(bv != null and bv.get("hero_node") != null, "on the battle screen")
	var log_text := str(bv.log_label.get_parsed_text()) if bv != null and bv.get("log_label") != null else ""
	ok(log_text.contains("The battle goes on."), "which says the battle goes on")
	again.queue_free()
	for i in 2:
		await process_frame
