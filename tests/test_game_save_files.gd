## Save files: a slot's house written to a .glsave file and read back into any slot (GameSaves.export_file and
## import_file, the file picker's fallback folder, and the title screen's and game menu's buttons). A file holds the
## same block as Copy backup, so the two are interchangeable; damaged, foreign, newer, empty and oversized files are
## turned away with a reason and the slot is not touched.
## Run: godot --headless --path . -s res://tests/test_game_save_files.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const Clipboard := preload("res://ui/play/clipboard.gd")
const FilePicker := preload("res://ui/play/file_picker.gd")
const DIR := "user://test_save_files/"

var checks := 0
var fails := 0
var app: Node


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_wipe()
	GameData.load_all()
	GameSaves.base = DIR + "save.json"
	GameDynasty.save_path = GameSaves.base
	UiSettings.path = DIR + "settings.cfg"
	UiSettings.scale = 1.0
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	Clipboard.fake = true
	FilePicker.fake = true
	FilePicker.fake_dir = DIR + "folder"
	DirAccess.make_dir_recursive_absolute(DIR + "folder")
	test_core()
	test_damaged()
	test_picker()
	root.size = Vector2i(1280, 720)
	await _frames(2)
	app = GameApp.new()
	root.add_child(app)
	await _frames(3)
	await test_title()
	await test_menu()
	_wipe()
	print("save files tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _wipe() -> void:
	var todo: Array = [DIR]
	while not todo.is_empty():
		var dir: String = todo.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			todo.append(dir + sub + "/")
		for f in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + f)


func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


func _house(slot: int, seed_val: int, name: String) -> GameDynasty:
	var d := GameDynasty.new_game(seed_val, name, "mage", "faetouched", "elf")
	d.pending_event = {}
	GameBot.live_life(d)
	GameBot.choose_best(d)
	d.dynasty_name = name
	GameSaves.write_atomic(GameSaves.path_for(slot), JSON.stringify(d.to_save()))
	return d


# ---------------------------------------------------------------- the files

func test_core() -> void:
	var d := _house(1, 5, "Ashford Keep")
	ok(GameSaves.file_name(1) == "house-ashford-keep-gen%d.glsave" % d.gen, "a slot's file is named for its house and generation (%s)" % GameSaves.file_name(1))
	ok(GameSaves.file_name(3) == "save.glsave", "an empty slot's is plain")
	var path := DIR + "out.glsave"
	var w := GameSaves.export_file(1, path)
	ok(w["ok"] and FileAccess.file_exists(path), "a slot is written to a file")
	var text := FileAccess.get_file_as_string(path)
	ok(text.begins_with(GameSaves.BACKUP_PREFIX), "the file holds the same block as Copy backup")
	ok(GameSaves.import_text(text)["ok"] and GameSaves.import_text(GameSaves.export_text(1))["json"] == GameSaves.import_text(text)["json"], "so the two are interchangeable")
	var r := GameSaves.import_file(path)
	ok(r["ok"] and r["house"] == "Ashford Keep" and r["gen"] == d.gen, "the file reads back")
	GameSaves.write_atomic(GameSaves.path_for(2), r["json"])
	var back := GameSaves.load_file(GameSaves.path_for(2))
	ok(back != null and JSON.stringify(back.to_dict()) == JSON.stringify(GameSaves.load_file(GameSaves.path_for(1)).to_dict()), "into another slot, the same house")
	ok(not GameSaves.export_file(3, DIR + "empty.glsave")["ok"] and not FileAccess.file_exists(DIR + "empty.glsave"), "an empty slot writes nothing")
	ok(not GameSaves.export_file(1, DIR + "no/such/folder/x.glsave")["ok"], "a folder that is not there is a reason, not a crash")
	# a fight in the save goes in the file too
	var fight := GameDynasty.new_game(8, "Mid", "warrior", "faetouched", "human")
	fight.pending_event = {}
	fight.start_hunt("hunt")
	GameTactics.auto_turn(fight.battle)
	GameSaves.write_atomic(GameSaves.path_for(3), JSON.stringify(fight.to_save()))
	GameSaves.export_file(3, DIR + "fight.glsave")
	var fr := GameSaves.import_file(DIR + "fight.glsave")
	ok(fr["ok"] and JSON.parse_string(fr["json"]).has("battle"), "a fight in progress goes in the file and comes back with it")


func test_damaged() -> void:
	var cases := {
		"a file that is not there": [DIR + "missing.glsave", null],
		"an empty path": ["", null],
		"an empty file": [DIR + "e.glsave", ""],
		"words": [DIR + "w.glsave", "just some words"],
		"a block cut short": [DIR + "c.glsave", FileAccess.get_file_as_string(DIR + "out.glsave").substr(0, 60)],
		"a replay": [DIR + "r.glsave", "GLRP1:AAAA"],
		"json that is not a house": [DIR + "j.glsave", "{\"a\": 1}"],
	}
	for name in cases:
		var c: Array = cases[name]
		if c[1] != null:
			var f := FileAccess.open(c[0], FileAccess.WRITE)
			f.store_string(c[1])
			f.close()
		var r := GameSaves.import_file(c[0])
		ok(not r["ok"] and str(r["error"]) != "", "%s is turned away with a reason" % name)
	# a block from a newer game
	var d := GameDynasty.new_game(2, "New", "mage", "faetouched", "elf")
	var save := d.to_save()
	save["version"] = GameSaveVersion.CURRENT + 1
	var packed := GameSaves.BACKUP_PREFIX + Marshalls.raw_to_base64(JSON.stringify(save).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	var f2 := FileAccess.open(DIR + "n.glsave", FileAccess.WRITE)
	f2.store_string(packed)
	f2.close()
	var rn := GameSaves.import_file(DIR + "n.glsave")
	ok(not rn["ok"] and "newer" in str(rn["error"]).to_lower(), "a save from a newer game is turned away as such")


# ---------------------------------------------------------------- the picker

func test_picker() -> void:
	FilePicker.fake = false
	ok(not FilePicker.native(), "headless there is no native file dialog")
	var got: Array = []
	FilePicker.save("t", "x.glsave", func(p: String): got.append(p))
	ok(got == [DIR + "folder/x.glsave"], "without a dialog the file goes to the fallback folder (%s)" % str(got))
	FilePicker.open("t", func(p: String): got.append(p))
	ok(got[1] == "", "and with nothing there, opening finds nothing")
	var f := FileAccess.open(DIR + "folder/old.glsave", FileAccess.WRITE)
	f.store_string("x")
	f.close()
	var g := FileAccess.open(DIR + "folder/notes.txt", FileAccess.WRITE)
	g.store_string("x")
	g.close()
	ok(FilePicker.newest(DIR + "folder") == DIR + "folder/old.glsave", "it opens the newest .glsave there and ignores other files")
	DirAccess.remove_absolute(DIR + "folder/old.glsave")
	FilePicker.fake = true
	FilePicker.fake_path = DIR + "chosen.glsave"
	FilePicker.save("t", "x", func(p: String): got.append(p))
	ok(got[2] == DIR + "chosen.glsave", "a fake dialog answers with its path")


# ---------------------------------------------------------------- the screens

func _btn(start: String, n: Node = null) -> Button:
	if n == null:
		n = app.current
	if n is Button and (n as Button).is_visible_in_tree():
		var t := (n as Button).text
		if t.begins_with(start) or t.begins_with("> " + start):
			return n
	for c in n.get_children():
		var b := _btn(start, c)
		if b != null:
			return b
	return null


func _press(start: String) -> bool:
	var b := _btn(start)
	if b == null or b.disabled:
		return false
	b.pressed.emit()
	return true


func _note() -> String:
	return app.current.slot_note.text


func test_title() -> void:
	_wipe_slots()
	var d := _house(2, 5, "Ashford Keep")
	app.show_title()
	await _frames(3)
	_press("Slot 2")
	await _frames(2)
	ok(_btn("Export to file") != null and not _btn("Export to file").disabled, "the title has Export to file for a slot with a house")
	FilePicker.fake_path = DIR + "folder/title.glsave"
	_press("Export to file")
	await _frames(2)
	ok(FileAccess.file_exists(DIR + "folder/title.glsave") and _note().contains("Saved to"), "it writes the file and says where")
	FilePicker.fake_path = ""
	_press("Export to file")
	await _frames(2)
	ok(_note().contains("Nothing was saved"), "cancelling the dialog saves nothing and says so")
	FilePicker.fake_path = DIR + "no/such/folder/x.glsave"
	_press("Export to file")
	await _frames(2)
	ok(_note().contains("could not be written") and _note().contains("Copy backup"), "a path that cannot be written says so and points to Copy backup")
	_press("Slot 1")
	await _frames(2)
	ok(_btn("Export to file").disabled, "an empty slot cannot be exported")
	FilePicker.fake_path = DIR + "folder/title.glsave"
	ok(_press("Import from file"), "Import from file is there")
	await _frames(2)
	ok(not app.current.confirm_row.visible, "an empty slot is imported into without asking")
	var imported := GameSaves.load_file(GameSaves.path_for(1))
	ok(imported != null and imported.dynasty_name == d.dynasty_name and _note().contains("Restored"), "the house comes in and the note says so")
	# over a house: asks first, keeps the old one as .bak
	_house(3, 99, "Zed Hold")
	_press("Slot 3")
	await _frames(2)
	_press("Import from file")
	await _frames(2)
	ok(app.current.confirm_row.visible, "importing over a house asks first")
	ok(GameSaves.load_file(GameSaves.path_for(3)).dynasty_name == "Zed Hold", "and nothing has changed yet")
	_press("Yes")
	await _frames(2)
	ok(GameSaves.load_file(GameSaves.path_for(3)).dynasty_name == d.dynasty_name, "Yes imports it")
	ok(GameSaves.read_json(GameSaves.path_for(3) + ".bak")["dynasty_name"] == "Zed Hold", "and the house it covered stays as the slot's .bak")
	# a bad file is a reason and the slot is untouched
	var bad := FileAccess.open(DIR + "folder/bad.glsave", FileAccess.WRITE)
	bad.store_string("not a save")
	bad.close()
	FilePicker.fake_path = DIR + "folder/bad.glsave"
	_press("Import from file")
	await _frames(2)
	if app.current.confirm_row.visible:
		_press("Yes")
		await _frames(2)
	ok(_note().contains("not a house backup") and GameSaves.load_file(GameSaves.path_for(3)).dynasty_name == d.dynasty_name, "a file that is not a save is turned away and the slot is not touched")
	FilePicker.fake_path = ""
	_press("Import from file")
	await _frames(2)
	if app.current.confirm_row.visible:
		_press("Yes")
		await _frames(2)
	ok(_note().contains("No save file was chosen"), "cancelling the dialog imports nothing and says so")


func _wipe_slots() -> void:
	for n in range(1, GameSaves.slots() + 1):
		GameSaves.delete(n)


func test_menu() -> void:
	app.show_title()
	await _frames(3)
	_press("Slot 2")
	await _frames(2)
	_press("Continue")
	await _frames(3)
	app.open_menu()
	await _frames(3)
	FilePicker.fake_path = DIR + "folder/menu.glsave"
	ok(_press("Export to file"), "the game menu has Export to file")
	await _frames(2)
	var r := GameSaves.import_file(DIR + "folder/menu.glsave")
	ok(r["ok"] and r["house"] == app.dynasty.dynasty_name, "it writes the house being played")
