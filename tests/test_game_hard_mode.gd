## Hard-mode dynasty options (roadmap item 20): the data and the ways to break it; the founder's choices and the
## ones turned away; that options are set at the founding only, never later and never off; whole-line permadeath
## (a heir slain in battle ends the saga, old age and sickness pass the line on); the generation cap (it overrides
## the saga's own length, and says so at the succession); the iron-man save (no backup out, none back in, nothing
## restored over it, no save before the last); that a house with nothing switched on plays and saves exactly as
## before; saving, old saves and damaged values; and the title's panel, the menu and the Chronicle.
## Run: godot --headless --path . -s res://tests/test_game_hard_mode.gd
extends SceneTree

const DIR := "user://test_hard_mode/"
const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const Clipboard := preload("res://ui/play/clipboard.gd")
const FilePicker := preload("res://ui/play/file_picker.gd")
const Chronicle := preload("res://ui/play/chronicle_panel.gd")
const HardModePanel := preload("res://ui/play/hard_mode_panel.gd")
const EndingScreen := preload("res://ui/play/ending_screen.gd")
const SuccessionScreen := preload("res://ui/play/succession_screen.gd")

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
	_wipe()
	GameSaves.base = DIR + "save.json"
	GameDynasty.save_path = GameSaves.base
	test_data()
	test_choices()
	test_founding()
	test_permadeath()
	test_gen_cap()
	test_unchanged()
	test_saving()
	test_ironman()
	await test_screen()
	_wipe()
	print("hard mode tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _wipe() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)


func dyn(hard: Dictionary = {}, p_seed: int = 5) -> GameDynasty:
	var d := GameDynasty.new_game(p_seed, "Tess", "warrior", "noble", "human", GameSex.FEMALE, "", hard)
	d.pending_event = {}
	return d


func _broken(edit: Callable, word: String) -> bool:
	var saved: Dictionary = GameHardMode.data().duplicate(true)
	edit.call(GameHardMode.data())
	var found := GameHardMode.validate()
	GameHardMode._cache = saved
	return found.any(func(p): return word in str(p))


func test_data() -> void:
	ok(GameHardMode.validate().is_empty(), "the data is sound: %s" % str(GameHardMode.validate()))
	ok(GameHardMode.caps() == [10, 25, 50, 100], "the caps a founder may choose are 10, 25, 50 and 100")
	ok(GameHardMode.setting("permadeath_causes") == ["slain in battle"], "only a death in battle ends the line")
	ok(_broken(func(d): d.erase("settings"), "no 'settings'"), "no settings is caught")
	ok(_broken(func(d): d["settings"]["gen_caps"] = [], "at least one cap"), "an empty list of caps is caught")
	ok(_broken(func(d): d["settings"]["gen_caps"] = [10, 0], "whole number"), "a cap of nothing is caught")
	ok(_broken(func(d): d["settings"]["gen_caps"] = [10, 12.5], "whole number"), "half a generation is caught")
	ok(_broken(func(d): d["settings"]["gen_caps"] = [25, 10], "must rise"), "caps out of order are caught")
	ok(_broken(func(d): d["settings"]["gen_caps"] = [10, 10], "must rise"), "a cap listed twice is caught")
	ok(_broken(func(d): d["settings"]["gen_caps"] = [10, 999999], "not below"), "a cap as long as the saga is caught")
	ok(_broken(func(d): d["settings"]["permadeath_causes"] = [], "at least one cause"), "permadeath with no cause is caught")
	ok(_broken(func(d): d["settings"]["permadeath_causes"] = ["slain in battle", "old age"], "old age"), "old age ending the line is caught")
	ok(_broken(func(d): d["options"].erase("ironman"), "'ironman' is missing"), "a missing option is caught")
	ok(_broken(func(d): d["options"]["permadeath"]["about"] = " ", "has no 'about'"), "an option that does not explain itself is caught")
	ok(_broken(func(d): d["options"]["nightmare"] = {"name": "x", "about": "x", "active": "x"}, "not an option"), "an option the game does not have is caught")
	ok(_broken(func(d): d["options"]["gen_cap"]["active"] = "A cap.", "{cap}"), "a cap line that does not say the cap is caught")
	ok(_broken(func(d): d["text"].erase("no_export"), "'no_export' is missing"), "a missing refusal is caught")
	ok(_broken(func(d): d["text"]["line_ends"] = "", "'line_ends' is missing"), "an empty ending line is caught")
	ok(GameHardMode.validate().is_empty(), "and the data is as it was after")


func test_choices() -> void:
	ok(GameHardMode.choices({}) == {"ok": true, "text": "", "hard": {}}, "no choices is no options")
	ok(GameHardMode.choices({"permadeath": false, "ironman": false, "gen_cap": 0})["hard"] == {}, "everything off keeps nothing")
	ok(GameHardMode.choices({"permadeath": true, "ironman": true, "gen_cap": 25})["hard"] == {"permadeath": true, "ironman": true, "gen_cap": 25}, "all three are kept")
	ok(GameHardMode.choices({"ironman": true, "permadeath": false})["hard"] == {"ironman": true}, "only what is on is kept")
	var cap := GameHardMode.choices({"gen_cap": 12})
	ok(not cap["ok"] and cap["text"] == "A generation cap must be one of: 10, 25, 50, 100." and cap["hard"] == {}, "a cap that is not on the list is turned away: %s" % cap["text"])
	ok(not GameHardMode.choices({"gen_cap": -10})["ok"] and not GameHardMode.choices({"gen_cap": "ten"})["ok"] and not GameHardMode.choices({"gen_cap": 10.5})["ok"], "so is a cap below nothing, in words, or of half a generation")
	var word := GameHardMode.choices({"permadeath": "yes"})
	ok(not word["ok"] and word["text"] == "'permadeath' must be switched on or off.", "an option is on or off, nothing else: %s" % word["text"])
	var odd := GameHardMode.choices({"nightmare": true})
	ok(not odd["ok"] and odd["text"] == "'nightmare' is not a hard-mode option.", "an unknown option is turned away: %s" % odd["text"])
	ok(GameHardMode.summary({}) == "off" and GameHardMode.summary({"gen_cap": 0}) == "off", "the title's button says off")
	ok(GameHardMode.summary({"permadeath": true, "ironman": true, "gen_cap": 50}) == "permadeath, iron-man, 50 generations", "or what is chosen: %s" % GameHardMode.summary({"permadeath": true, "ironman": true, "gen_cap": 50}))


func test_founding() -> void:
	var plain := dyn()
	ok(plain.hard == {} and not GameHardMode.any(plain) and GameHardMode.lines(plain).is_empty(), "a dynasty is founded with no options")
	ok(not GameHardMode.permadeath(plain) and not GameHardMode.ironman(plain) and GameHardMode.gen_cap(plain) == 0, "none of the three is on")
	var d := dyn({"permadeath": true, "ironman": true, "gen_cap": 10})
	ok(d.hard == {"permadeath": true, "ironman": true, "gen_cap": 10}, "the founding's last argument switches them on: %s" % str(d.hard))
	ok(GameHardMode.permadeath(d) and GameHardMode.ironman(d) and GameHardMode.gen_cap(d) == 10, "and each answers for itself")
	ok(GameHardMode.lines(d) == ["Whole-line permadeath: the house ends with the first heir slain in battle.", "Iron-man save: no backups, and no save to go back to.", "Generation cap: the saga ends with the heir of generation 10."], "each says what it does: %s" % str(GameHardMode.lines(d)))
	ok(d.journal.has("Iron-man save: no backups, and no save to go back to."), "and the founding is told in the journal")
	ok(dyn({"gen_cap": 12}).hard == {} and dyn({"nightmare": true}).hard == {}, "choices the rules turn away found a plain house")
	# never off, never changed
	var off := GameHardMode.found(d, {"permadeath": false, "ironman": false, "gen_cap": 0})
	ok(not off["ok"] and off["text"] == "This house's hard-mode options were set at its founding and cannot be changed." and d.hard.size() == 3, "an option cannot be switched off: %s" % off["text"])
	var one := dyn({"permadeath": true})
	ok(not GameHardMode.found(one, {"ironman": true})["ok"] and one.hard == {"permadeath": true}, "nor another added to a house that has one")
	# set right after the founding (the setter): allowed while the house has not lived
	var late := dyn()
	ok(GameHardMode.is_fresh(late) and GameHardMode.found(late, {"gen_cap": 25})["ok"] and late.hard == {"gen_cap": 25}, "a house that has not yet lived may still be founded with one")
	# never on for a house that lives
	var lived := dyn()
	lived.train("str")
	var too_late := GameHardMode.found(lived, {"permadeath": true})
	ok(not GameHardMode.is_fresh(lived) and not too_late["ok"] and lived.hard == {}, "after a year has passed no option can be switched on")
	ok(too_late["text"] == "Hard-mode options are chosen at the founding. They cannot be switched on for a house that already lives.", "and the house is told why: %s" % too_late["text"])
	ok(GameHardMode.found(lived, {})["ok"] and GameHardMode.found(lived, {"permadeath": false})["ok"] and lived.hard == {}, "asking for nothing is no refusal and changes nothing")
	var hunted := dyn()
	hunted.total_hunts = 1
	ok(not GameHardMode.found(hunted, {"ironman": true})["ok"], "nor after a hunt")
	var second := dyn()
	second._die("old age")
	ok(not GameHardMode.found(second, {"ironman": true})["ok"], "nor at a succession")
	second.choose_heir(0)
	ok(not GameHardMode.found(second, {"gen_cap": 10})["ok"] and second.hard == {}, "nor in a later generation")
	var loaded := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(lived.to_dict())))
	ok(not GameHardMode.found(loaded, {"permadeath": true})["ok"] and loaded.hard == {}, "nor for a loaded house")


func _slay(d: GameDynasty) -> Array:
	var chance: Variant = GameData.balance["death_chance_on_defeat"]
	GameData.balance["death_chance_on_defeat"] = 2.0   # a defeat is always a death, for this fight only
	d.heir.extra_life_used = true
	d.start_hunt("hunt")
	d.battle.result = "defeat"
	d.heir.hp = 0
	var msgs := d.finish_battle()
	GameData.balance["death_chance_on_defeat"] = chance
	return msgs


func test_permadeath() -> void:
	var d := dyn({"permadeath": true})
	d.found_family()
	var msgs := _slay(d)
	ok(d.state == "ended" and d.candidates.is_empty() and d.gen == 1, "a heir slain in battle ends the dynasty: state %s, %d candidates" % [d.state, d.candidates.size()])
	ok(d.last_death.get("cause") == "slain in battle" and d.history.size() == 1, "the death is recorded as any other")
	var said := "House %s was sworn to end with the first heir slain in battle: no child takes up the name of Tess." % d.dynasty_name
	ok(msgs.has(said) and d.journal.has(said), "the ending says why: %s" % str(msgs.slice(maxi(0, msgs.size() - 2))))
	ok(msgs.any(func(m): return str(m).begins_with("With Tess the chronicle of House")), "after the saga's own closing line")
	ok(d.choose_heir(0) is Array and d.state == "ended" and d.gen == 1, "no heir can be chosen after it")
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(back.state == "ended" and GameHardMode.permadeath(back), "an ended house loads ended")
	# old age and sickness pass the line on
	var old := dyn({"permadeath": true})
	old._die("old age")
	ok(old.state == "succession" and old.candidates.size() >= 2, "old age passes the line on")
	old.choose_heir(0)
	ok(old.state == "life" and old.gen == 2 and GameHardMode.permadeath(old), "the next heir lives under the same oath")
	var sick := dyn({"permadeath": true})
	sick._die("the wasting fever")
	ok(sick.state == "succession", "a death of sickness passes it on too")
	_slay(old)
	ok(old.state == "ended" and old.gen == 2, "and a later heir slain ends it then")
	# without the option a slain heir is succeeded
	var plain := dyn()
	var pm := _slay(plain)
	ok(plain.state == "succession" and not pm.any(func(m): return "sworn" in str(m)), "a plain house's slain heir is succeeded, as always")
	# a save tampered into a succession after such a death
	var cheat: Dictionary = JSON.parse_string(JSON.stringify(plain.to_dict()))
	cheat["hard"] = {"permadeath": true}
	ok(GameDynasty.from_dict(cheat).state == "ended", "a permadeath save cannot be opened at a succession after a death in battle")


func test_gen_cap() -> void:
	var plain := dyn()
	ok(GameHardMode.last_gen(plain) == GameAges.max_generations() and GameHardMode.last_gen(plain) == 999999, "with no cap the saga is as long as it always was")
	var d := dyn({"gen_cap": 10})
	ok(GameHardMode.last_gen(d) == 10, "a cap of 10 makes generation 10 the last")
	GameAges.jump_to(d, 9)
	d._die("old age")
	ok(d.state == "succession", "the ninth heir is succeeded")
	var msgs := d.choose_heir(0)
	ok(d.gen == 10 and msgs.any(func(m): return str(m).contains("is the last heir of the saga")), "the tenth is told to be the last")
	var end := d._die("old age")
	ok(d.state == "ended" and d.gen == 10 and d.candidates.is_empty(), "and the saga ends with them, of old age too")
	ok(end.any(func(m): return str(m).contains("after 10 generations")) and not end.any(func(m): return "sworn" in str(m)), "with the saga's own closing line: %s" % str(end))
	var over := dyn({"gen_cap": 25})
	GameAges.jump_to(over, 24)
	over._die("old age")
	var stuck: Dictionary = JSON.parse_string(JSON.stringify(over.to_dict()))
	stuck["gen"] = 25
	ok(GameDynasty.from_dict(stuck).state == "ended", "a save at a succession past the cap opens ended")
	var c100 := dyn({"gen_cap": 100})
	GameAges.jump_to(c100, 99)
	c100._die("old age")
	ok(c100.state == "succession", "generation 99 of 100 goes on")
	# the saga's own length still holds when it is the shorter
	var settings: Dictionary = GameData.ages["settings"]
	var was: Variant = settings["max_generations"]
	settings["max_generations"] = 3
	ok(GameHardMode.last_gen(d) == 3 and GameHardMode.last_gen(plain) == 3, "a saga shorter than the cap ends at its own length")
	settings["max_generations"] = was


func _bot(d: GameDynasty) -> void:
	if d.state == "succession":
		GameBot.choose_best(d)
	elif d.state == "life":
		GameBot.step(d)


func _plain(d: GameDynasty) -> String:
	var out := d.to_dict()
	out.erase("hard")
	out.erase("journal")
	return JSON.stringify(out)


func test_unchanged() -> void:
	var a := GameDynasty.new_game(31, "Auto", "warrior", "noble", "human")
	var b := GameDynasty.new_game(31, "Auto", "warrior", "noble", "human", GameSex.MALE, "", {"permadeath": false, "ironman": false, "gen_cap": 0})
	var c := GameDynasty.new_game(31, "Auto", "warrior", "noble", "human", GameSex.MALE, "", {"ironman": true, "gen_cap": 100})
	ok(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()) and not a.to_dict().has("hard"), "a house founded with everything off is the house it always was, and saves no key")
	ok(a.rng.state == c.rng.state and _plain(a) == _plain(c), "choosing options draws no dice at the founding")
	for i in 2500:
		_bot(a)
		_bot(b)
		_bot(c)
	ok(a.gen >= 3, "the autopilot plays generations (%d)" % a.gen)
	ok(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()) and a.rng.state == b.rng.state, "with the options off its lives are the same to the last die")
	ok(not b.to_dict().has("hard") and JSON.stringify(b.to_save()) == JSON.stringify(a.to_save()), "and the save is the same text")
	ok(_plain(a) == _plain(c) and a.rng.state == c.rng.state, "an iron-man house under a cap not yet reached lives the same lives too (only its journal says so)")
	ok(c.to_dict().get("hard") == {"ironman": true, "gen_cap": 100}, "and keeps its options through them")
	# the autopilot under permadeath: it plays until a heir is slain, then stops for good
	var p := GameDynasty.new_game(31, "Auto", "warrior", "noble", "human", GameSex.MALE, "", {"permadeath": true})
	var q := GameDynasty.new_game(31, "Auto", "warrior", "noble", "human")
	var slain := false
	for i in 20000:
		_bot(p)
		_bot(q)
		if q.state == "succession" and q.last_death.get("cause") == "slain in battle":
			slain = true
			break
		if _plain(p) != _plain(q):
			break
	ok(slain and p.state == "ended" and q.state == "succession", "the autopilot's permadeath house lives as the plain one until a heir is slain, and ends there (gen %d, %s)" % [p.gen, p.state])
	ok(p.history == q.history, "with the same heirs behind it")
	GameBot.step(p)
	GameBot.choose_best(p)
	ok(p.state == "ended", "and the autopilot cannot play it on")


func test_saving() -> void:
	var d := dyn({"permadeath": true, "ironman": true, "gen_cap": 50})
	var text := JSON.stringify(d.to_dict())
	var back := GameDynasty.from_dict(JSON.parse_string(text))
	ok(back.hard == {"permadeath": true, "ironman": true, "gen_cap": 50} and typeof(back.hard["gen_cap"]) == TYPE_INT, "the options survive a save and load: %s" % str(back.hard))
	ok(JSON.stringify(back.to_dict()) == text, "and save again as the same text")
	ok(GameSaves.shape_ok(JSON.parse_string(JSON.stringify(d.to_save()))), "the save is still shaped like a save")
	var old: Dictionary = JSON.parse_string(text)
	old.erase("hard")
	var o := GameDynasty.from_dict(old)
	ok(o.hard == {} and GameHardMode.last_gen(o) == GameAges.max_generations(), "a save from before hard mode loads with nothing on")
	for bad in ["yes", 7, [true], null, {"permadeath": "true", "ironman": 1, "gen_cap": "50"}, {"gen_cap": -3}, {"gen_cap": 0}, {"gen_cap": 12.5}, {"gen_cap": [10]}, {"permadeath": false, "ironman": null}, {"gen_cap": 1e300}]:
		var dmg: Dictionary = JSON.parse_string(text)
		dmg["hard"] = bad
		var g := GameDynasty.from_dict(dmg)
		ok(g != null and g.hard == {}, "a damaged value loads as nothing on: %s" % str(bad))
	var part: Dictionary = JSON.parse_string(text)
	part["hard"] = {"permadeath": true, "ironman": "no", "gen_cap": 33, "nightmare": true}
	ok(GameDynasty.from_dict(part).hard == {"permadeath": true, "gen_cap": 33}, "what is sound is kept, what is not is dropped, and a house keeps the cap it was founded with")
	ok(GameHardMode.load_state({"gen_cap": 25.0}) == {"gen_cap": 25}, "a cap read back from JSON is a whole number again")


func _slot_files(slot: int) -> Array:
	var p := GameSaves.path_for(slot)
	return [FileAccess.file_exists(p), FileAccess.file_exists(p + ".bak")]


func test_ironman() -> void:
	_wipe()
	# a plain house: backups as always
	GameDynasty.save_path = GameSaves.path_for(1)
	var plain := dyn()
	plain.save_to_disk()
	plain.train("str")
	plain.save_to_disk()
	ok(_slot_files(1) == [true, true], "a plain house keeps the save before the last")
	var block := GameSaves.export_text(1)
	ok(block.begins_with(GameSaves.BACKUP_PREFIX) and GameSaves.import_text(block)["ok"], "and can be backed up and read back")
	ok(not GameSaves.ironman(1) and GameSaves.why_no_export(1) == "" and GameSaves.why_no_restore(1) == "" and not GameSaves.peek(1)["ironman"], "nothing about it is locked")
	ok(GameSaves.restore_into(1, GameSaves.import_text(block)["json"]) == "", "a backup can be restored over it")
	# an iron-man house
	GameDynasty.save_path = GameSaves.path_for(2)
	var d := dyn({"ironman": true})
	ok(d.save_to_disk() and _slot_files(2) == [true, false], "an iron-man house saves")
	d.train("str")
	ok(d.save_to_disk() and _slot_files(2) == [true, false], "and keeps no save before the last to go back to")
	var loaded := GameDynasty.load_from_disk()
	ok(loaded != null and GameHardMode.ironman(loaded) and int(loaded.world.year) == int(d.world.year), "it loads as it was last saved")
	ok(GameSaves.ironman(2) and GameSaves.peek(2)["ironman"] and GameSaves.peek(2)["valid"], "the slot is marked iron-man")
	ok(GameSaves.export_text(2) == "", "it cannot be copied as a backup")
	ok(GameSaves.why_no_export(2) == "This house is an iron-man save: it cannot be copied or exported as a backup.", "and the reason is said: %s" % GameSaves.why_no_export(2))
	var out := DIR + "out.glsave"
	var ef := GameSaves.export_file(2, out)
	ok(not ef["ok"] and ef["error"] == GameSaves.why_no_export(2) and not FileAccess.file_exists(out), "nor exported to a file: %s" % ef["error"])
	var json := str(GameSaves.import_text(block)["json"])
	var before := FileAccess.get_file_as_string(GameSaves.path_for(2))
	var over := GameSaves.restore_into(2, json)
	ok(over == "This slot holds an iron-man save: nothing can be restored over it. Delete the house first to use the slot." and FileAccess.get_file_as_string(GameSaves.path_for(2)) == before, "nothing can be restored over it: %s" % over)
	# a backup of an iron-man house, however it was made, is not read back in
	var made := GameSaves.BACKUP_PREFIX + Marshalls.raw_to_base64(before.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	var imp := GameSaves.import_text(made)
	ok(not imp["ok"] and imp["error"] == "That backup holds an iron-man house, which cannot be restored." and imp["json"] == "", "a backup block of an iron-man house is turned away: %s" % imp["error"])
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(made)
	f.close()
	ok(not GameSaves.import_file(out)["ok"], "and so is a file of one")
	# a leftover ".bak" of the house still locks the slot
	DirAccess.rename_absolute(GameSaves.path_for(2), GameSaves.path_for(2) + ".bak")
	ok(GameSaves.ironman(2) and GameSaves.export_text(2) == "" and GameSaves.restore_into(2, json) != "", "a slot holding only the house's '.bak' is locked the same")
	DirAccess.rename_absolute(GameSaves.path_for(2) + ".bak", GameSaves.path_for(2))
	# a plain house's save is the text it always was; an iron-man mark that is damaged is no mark
	ok(not GameHardMode.saved_ironman(JSON.parse_string(FileAccess.get_file_as_string(GameSaves.path_for(1)))) and not FileAccess.get_file_as_string(GameSaves.path_for(1)).contains("\"hard\""), "a plain save holds no mark")
	ok(not GameHardMode.saved_ironman({"hard": {"ironman": "true"}}) and not GameHardMode.saved_ironman({"hard": 5}) and not GameHardMode.saved_ironman(null) and GameHardMode.saved_ironman({"hard": {"ironman": true}}), "only a true mark is a mark")
	# deleting the house frees the slot
	GameSaves.delete(2)
	ok(not GameSaves.ironman(2) and GameSaves.restore_into(2, json) == "" and GameSaves.peek(2)["valid"], "once the house is deleted the slot takes a backup again")
	_wipe()
	GameDynasty.save_path = GameSaves.base


func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


func _buttons(n: Node, out: Array) -> void:
	if n is Button and not n.is_queued_for_deletion():
		out.append(n)
	for c in n.get_children():
		if not c.is_queued_for_deletion():
			_buttons(c, out)


func _btn(host: Node, start: String) -> Button:
	var all: Array = []
	_buttons(host, all)
	for b in all:
		if (b as Button).text.begins_with(start):
			return b
	return null


func _text_in(n: Node, word: String) -> bool:
	if (n is Label or n is RichTextLabel) and str(n.text).contains(word):
		return true
	for c in n.get_children():
		if _text_in(c, word):
			return true
	return false


func test_screen() -> void:
	_wipe()
	UiSettings.path = DIR + "settings.cfg"
	UiSettings.scale = 1.0
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	Clipboard.fake = true
	FilePicker.fake = true
	FilePicker.fake_path = DIR + "picked.glsave"
	root.size = Vector2i(1280, 720)
	await _frames(2)
	var app := GameApp.new()
	root.add_child(app)
	await _frames(3)
	var title = app.current
	var hb := _btn(title, "Hard mode")
	ok(hb != null and hb.text == "Hard mode: off" and title.hard_opts == {}, "the title has one Hard mode button, off")
	ok(hb != null and hb.size.y >= UiSettings.tap_h(0) - 0.5, "tall enough to touch")
	hb.pressed.emit()
	await _frames(3)
	var panel: Control = null
	for c in title.get_children():
		if c is HardModePanel:
			panel = c
	ok(panel != null and _text_in(panel, "Whole-line permadeath") and _text_in(panel, "Iron-man save") and _text_in(panel, "Generation cap") and _text_in(panel, "can never be switched off"), "it opens a panel that names the three and says they are for good")
	var ons: Array = []
	_buttons(panel, ons)
	ok(ons.filter(func(b): return b.text == "> Off").size() == 2 and _btn(panel, "> No cap") != null and ons.filter(func(b): return b.text.ends_with(" generations")).size() == 4, "all off, with the four caps offered")
	_btn(panel, "On").pressed.emit()   # permadeath
	await _frames(3)
	ok(title.hard_opts == {"permadeath": true} and _btn(title, "Hard mode").text == "Hard mode: permadeath", "switching permadeath on is kept and the button says so")
	var all: Array = []
	_buttons(panel, all)
	all.filter(func(b): return b.text == "On")[0].pressed.emit()   # the one still off: iron-man
	await _frames(3)
	_btn(panel, "25 generations").pressed.emit()
	await _frames(3)
	ok(title.hard_opts == {"permadeath": true, "ironman": true, "gen_cap": 25} and _btn(title, "Hard mode").text == "Hard mode: permadeath, iron-man, 25 generations", "all three chosen: %s" % str(title.hard_opts))
	_btn(panel, "Off").pressed.emit()   # permadeath off again: a choice may be changed until the founding
	await _frames(3)
	ok(title.hard_opts == {"ironman": true, "gen_cap": 25}, "a choice can be taken back before the dynasty begins")
	_btn(panel, "On").pressed.emit()
	await _frames(3)
	_btn(panel, "Done").pressed.emit()
	await _frames(3)
	ok(not title.get_children().any(func(c): return c is HardModePanel and not c.is_queued_for_deletion()), "Done closes the panel")
	_btn(title, "Begin Dynasty").pressed.emit()
	await _frames(3)
	var d: GameDynasty = app.dynasty
	ok(d != null and d.hard == {"permadeath": true, "ironman": true, "gen_cap": 25}, "Begin Dynasty founds the house with them")
	ok(_slot_files(1) == [true, false] and GameSaves.ironman(1), "and its save is an iron-man save")
	d.pending_event = {}
	# the Chronicle's Statistics say what is on
	var c := Chronicle.new()
	c.dynasty = d
	app.current.add_child(c)
	await _frames(3)
	ok(_text_in(c, "Hard mode") and _text_in(c, "Generation cap: the saga ends with the heir of generation 25."), "the Chronicle's Statistics list the options")
	c.queue_free()
	await _frames(2)
	# the game menu refuses a backup, and says why
	app.autosave()
	var menu: Control = app.open_menu()
	await _frames(3)
	var copy := _btn(menu, "Copy backup")
	var export := _btn(menu, "Export to file")
	ok(copy != null and copy.disabled and export != null and export.disabled, "the menu's Copy backup and Export to file are shut")
	ok(_text_in(menu, "This house is an iron-man save: it cannot be copied or exported as a backup."), "with the reason under them")
	ok(_btn(menu, "Save") != null and not _btn(menu, "Save").disabled, "Save is still there")
	menu.queue_free()
	await _frames(2)
	# the title refuses too
	app.show_title()
	await _frames(3)
	title = app.current
	ok(_btn(title, "> Slot 1").text.ends_with("(iron-man)"), "the title marks the slot: %s" % _btn(title, "> Slot 1").text)
	for name in ["Copy backup", "Export to file", "Restore backup", "Import from file"]:
		ok(_btn(title, name) != null and _btn(title, name).disabled, "the title's %s is shut for it" % name)
	ok(title.slot_note.text.contains("it cannot be copied or exported as a backup") and title.slot_note.text.contains("nothing can be restored over it"), "and says why: %s" % title.slot_note.text)
	ok(not _btn(title, "Delete").disabled and not _btn(title, "Continue").disabled, "it can still be continued or deleted")
	Clipboard.fake_text = ""
	title._copy_backup()
	ok(Clipboard.fake_text == "" and title.slot_note.text.contains("iron-man"), "asked all the same, nothing reaches the clipboard")
	title._export_file()
	await _frames(2)
	ok(not FileAccess.file_exists(DIR + "picked.glsave") and title.slot_note.text.contains("iron-man"), "and no file is written")
	ok(_btn(title, "Hard mode").text == "Hard mode: off", "a new founding starts with hard mode off again")
	# a plain slot beside it is as it always was
	_btn(title, "Slot 2").pressed.emit()
	await _frames(3)
	title = app.current
	ok(not _btn(title, "Restore backup").disabled and not _btn(title, "Import from file").disabled and title.slot_note.text == "", "an empty slot beside it takes backups as always")
	_btn(title, "Begin Dynasty").pressed.emit()
	await _frames(3)
	ok(app.dynasty.hard == {} and not JSON.stringify(app.dynasty.to_save()).contains("\"hard\""), "a dynasty begun without the panel is a plain one")
	var plain_menu: Control = app.open_menu()
	await _frames(3)
	ok(not _btn(plain_menu, "Copy backup").disabled and not _text_in(plain_menu, "iron-man"), "and its menu backs it up as always")
	plain_menu.queue_free()
	var pc := Chronicle.new()
	pc.dynasty = app.dynasty
	app.current.add_child(pc)
	await _frames(3)
	ok(not _text_in(pc, "Hard mode"), "and its Chronicle says nothing of hard mode")
	pc.queue_free()
	await _frames(2)
	# continue the iron-man house and see it end: slain in battle, the ending screen
	app.use_slot(1)
	app.continue_game()
	await _frames(3)
	d = app.dynasty
	ok(d.hard == {"permadeath": true, "ironman": true, "gen_cap": 25}, "Continue brings the house back with its options")
	GameAges.jump_to(d, 23)
	d._die("old age")
	app.show_state()
	await _frames(3)
	ok(app.current is SuccessionScreen and _text_in(app.current, "generation 24."), "generation 23 of 25 goes to an ordinary succession")
	d.choose_heir(0)
	d._die("old age")
	app.show_state()
	await _frames(3)
	ok(app.current is SuccessionScreen and _text_in(app.current, "generation 25, the last of the saga"), "the succession into the cap says it is the last")
	GameAges.jump_to(d, 5)
	d.state = "life"
	d.candidates = []
	d.pending_event = {}
	_slay(d)
	app.autosave()
	app.show_state()
	await _frames(3)
	ok(d.state == "ended" and app.current is EndingScreen and _text_in(app.current, "The saga of House %s is over" % d.dynasty_name), "the heir slain, the game shows the saga's end")
	ok(_slot_files(1) == [true, false] and GameDynasty.load_from_disk().state == "ended", "and the only save is the ended one")
	app.queue_free()
	await _frames(2)
