## Save slots on the real screens: the title lists the slots, picks one, starts and continues in it, asks
## before covering or erasing a house, copies a backup to the clipboard and restores one from it, and
## the game menu copies a backup of the house being played. (How the title sits at every window size and
## text size is checked for all screens in test_game_mobile.)
## Run: godot --headless --path . -s res://tests/test_game_saves_ui.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const Clipboard := preload("res://ui/play/clipboard.gd")
const DIR := "user://test_saves_ui/"

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
	GameDynasty.save_path = DIR + "save.json"
	UiSettings.path = DIR + "settings.cfg"
	UiSettings.scale = 1.0
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	Clipboard.fake = true
	root.size = Vector2i(1280, 720)
	await _frames(2)
	app = GameApp.new()
	root.add_child(app)
	await _frames(3)
	await test_empty_title()
	await test_start_and_continue_in_slots()
	await test_confirmations()
	await test_backup_and_restore()
	await test_game_menu_backup()
	_wipe()
	print("saves ui tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _wipe() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)


func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


## The first visible button whose text starts with `start`.
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
	var t = app.current
	return t.slot_note.text if t.get("slot_note") != null else ""


func _title() -> void:
	app.show_title()
	await _frames(3)


func test_empty_title() -> void:
	await _title()
	ok(_btn("Slot 1") != null and _btn("Slot 2") != null and _btn("Slot 3") != null and _btn("Slot 4") == null, "the title lists three slots")
	ok(_btn("Slot 1").text.contains("empty"), "all empty to begin with")
	ok(_btn("Continue").disabled, "Continue waits for a house")
	ok(_btn("Copy backup").disabled and _btn("Delete").disabled, "nothing to copy or delete in an empty slot")
	ok(app.slot == 1, "slot 1 is picked")


func test_start_and_continue_in_slots() -> void:
	ok(_press("Begin Dynasty"), "Begin in the empty slot 1 starts at once, without asking")
	await _frames(3)
	var one: GameDynasty = app.dynasty
	ok(FileAccess.file_exists(GameSaves.path_for(1)) and not FileAccess.file_exists(GameSaves.path_for(2)), "and saves to slot 1's file")
	await _title()
	ok(_btn("Slot 1").text.contains("House %s" % one.dynasty_name), "slot 1 now names its house")
	ok(not _btn("Continue").disabled, "Continue is ready")
	_press("Slot 2")
	await _frames(2)
	ok(app.slot == 2 and GameDynasty.save_path == GameSaves.path_for(2), "picking slot 2 points saving at its file")
	ok(_btn("Continue").disabled, "slot 2 is empty: nothing to continue")
	app.current.name_edit.text = "Mara"
	app.current.seed_edit.text = "4242"
	ok(_press("Begin Dynasty"), "begin in slot 2")
	await _frames(3)
	var two: GameDynasty = app.dynasty
	ok(two.dynasty_name != one.dynasty_name or two.seed_value != one.seed_value, "a different house")
	ok(FileAccess.file_exists(GameSaves.path_for(2)), "saved in slot 2's file")
	ok(GameSaves.load_file(GameSaves.path_for(1)).dynasty_name == one.dynasty_name, "slot 1 untouched")
	await _title()
	_press("Slot 1")
	await _frames(2)
	_press("Continue")
	await _frames(3)
	ok(app.dynasty.dynasty_name == one.dynasty_name and app.slot == 1, "Continue plays the picked slot")
	app.dynasty.heir.gold = 777
	app.autosave()
	ok(GameSaves.load_file(GameSaves.path_for(1)).heir.gold == 777 and GameSaves.load_file(GameSaves.path_for(2)).heir.gold != 777, "autosave goes to that slot only")


func test_confirmations() -> void:
	await _title()
	_press("Slot 1")
	await _frames(2)
	var before := FileAccess.get_file_as_string(GameSaves.path_for(1))
	_press("Begin Dynasty")
	await _frames(2)
	ok(app.current is Control and app.current.confirm_row.visible, "beginning over a house asks first")
	ok(FileAccess.get_file_as_string(GameSaves.path_for(1)) == before, "and has changed nothing")
	_press("No")
	await _frames(2)
	ok(not app.current.confirm_row.visible and FileAccess.get_file_as_string(GameSaves.path_for(1)) == before, "No leaves the house alone")
	_press("Delete")
	await _frames(2)
	ok(app.current.confirm_row.visible, "Delete asks first")
	_press("Yes")
	await _frames(2)
	ok(not GameSaves.peek(1)["exists"] and _btn("Slot 1").text.contains("empty"), "Yes erases the slot")
	ok(_note().contains("empty"), "and says so")
	ok(GameSaves.peek(2)["exists"], "slot 2 is still there")


func test_backup_and_restore() -> void:
	await _title()
	_press("Slot 2")
	await _frames(2)
	var original := GameSaves.load_file(GameSaves.path_for(2))
	Clipboard.fake_text = ""
	_press("Copy backup")
	await _frames(2)
	ok(Clipboard.fake_text.begins_with(GameSaves.BACKUP_PREFIX) and _note().contains("copied"), "Copy backup puts the backup on the clipboard")
	_press("Slot 1")
	await _frames(2)
	ok(_press("Restore backup"), "restore into the empty slot 1")
	await _frames(2)
	ok(not app.current.confirm_row.visible, "an empty slot is restored into without asking")
	var restored := GameSaves.load_file(GameSaves.path_for(1))
	ok(restored != null and JSON.stringify(restored.to_dict()) == JSON.stringify(original.to_dict()), "the restored house is the one copied")
	ok(_btn("Slot 1").text.contains("House %s" % original.dynasty_name) and _note().contains("Restored"), "the list and the note show it")
	Clipboard.fake_text = "just some words"
	_press("Restore backup")
	await _frames(2)
	if app.current.confirm_row.visible:
		_press("Yes")
		await _frames(2)
	ok(_note().contains("not a house backup"), "words that are not a backup are turned away with a reason")
	ok(JSON.stringify(GameSaves.load_file(GameSaves.path_for(1)).to_dict()) == JSON.stringify(original.to_dict()), "and the slot is not touched")
	# Restoring over a house keeps the old one as .bak.
	var other := GameDynasty.new_game(99, "Zed", "warrior", "faetouched", "human")
	GameSaves.write_atomic(GameSaves.path_for(3), JSON.stringify(other.to_dict()))
	_press("Slot 3")
	await _frames(2)
	Clipboard.fake_text = GameSaves.export_text(2)
	_press("Restore backup")
	await _frames(2)
	ok(app.current.confirm_row.visible, "restoring over a house asks first")
	_press("Yes")
	await _frames(2)
	ok(GameSaves.load_file(GameSaves.path_for(3)).dynasty_name == original.dynasty_name, "Yes restores it")
	ok(GameSaves.read_json(GameSaves.path_for(3) + ".bak")["dynasty_name"] == other.dynasty_name, "and the house it covered stays as the slot's .bak")


func test_game_menu_backup() -> void:
	await _title()
	_press("Slot 2")
	await _frames(2)
	_press("Continue")
	await _frames(3)
	app.open_menu()
	await _frames(3)
	Clipboard.fake_text = ""
	ok(_press("Copy backup"), "the game menu has Copy backup")
	await _frames(2)
	var r := GameSaves.import_text(Clipboard.fake_text)
	ok(r["ok"] and r["house"] == app.dynasty.dynasty_name, "it copies the house being played")
