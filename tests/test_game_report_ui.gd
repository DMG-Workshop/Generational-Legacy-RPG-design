## Report a problem on the real screens: the menu's Problems section (the error log is off until switched on, the
## choice is kept, switching it off forgets), the report panel (says what a report holds and that nothing is sent,
## takes a note, copies a report that reads back with the house being played, saves one to a file), a report from the
## title with no house, one made mid-fight, and the facts about the device.
## Run: godot --headless --path . -s res://tests/test_game_report_ui.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const Clipboard := preload("res://ui/play/clipboard.gd")
const FilePicker := preload("res://ui/play/file_picker.gd")
const MenuPanel := preload("res://ui/play/menu_panel.gd")
const ReportPanel := preload("res://ui/play/report_panel.gd")
const ReportEnv := preload("res://ui/play/report_env.gd")
const DIR := "user://test_report_ui/"

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
	FilePicker.fake = true
	root.size = Vector2i(1280, 720)
	await _frames(2)
	app = GameApp.new()
	root.add_child(app)
	await _frames(3)
	await test_off_by_default()
	await test_switching_the_log()
	await test_report_from_a_game()
	await test_report_to_a_file()
	await test_report_from_the_title()
	await test_report_in_a_fight()
	test_env()
	GameErrorLog.remove()
	_wipe()
	print("report ui tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _wipe() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)


func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


func _texts(n: Node, out: Array = []) -> Array:
	if n is Label and (n as Label).is_visible_in_tree():
		out.append((n as Label).text)
	if n is Button and (n as Button).is_visible_in_tree():
		out.append((n as Button).text)
	for c in n.get_children():
		_texts(c, out)
	return out


func _btn(text: String, n: Node) -> Button:
	if n is Button and (n as Button).is_visible_in_tree() and (n as Button).text == text:
		return n
	for c in n.get_children():
		var b := _btn(text, c)
		if b != null:
			return b
	return null


func _menu() -> Control:
	for c in app.current.get_children():
		if c is MenuPanel and not c.is_queued_for_deletion():
			return c
	return null


func _panel() -> Control:
	for c in app.current.get_children():
		if c is ReportPanel and not c.is_queued_for_deletion():
			return c
	return null


## The On or Off button of the menu's Error log row.
func _log_button(menu: Control, which: String) -> Button:
	return _row_button(menu, "Error log", which)


func _row_button(n: Node, row_label: String, which: String) -> Button:
	if n is HBoxContainer:
		var named := false
		for c in n.get_children():
			if c is Label and (c as Label).text == row_label:
				named = true
		if named:
			for c in n.get_children():
				if c is Button and (c as Button).text == which:
					return c
	for c in n.get_children():
		var b := _row_button(c, row_label, which)
		if b != null:
			return b
	return null


func _is_marked(b: Button) -> bool:
	return b != null and b.has_theme_color_override("font_color")


func test_off_by_default() -> void:
	app.show_title()
	await _frames(3)
	ok(not UiSettings.error_log_on() and not GameErrorLog.installed(), "a new install keeps no error log")
	var m: Control = app.open_menu()
	await _frames(3)
	var texts := _texts(m)
	ok(texts.has("Problems") and texts.has("Error log") and texts.has("Report a problem"), "the menu has a Problems section with the error log and Report a problem")
	ok(_is_marked(_log_button(m, "Off")) and not _is_marked(_log_button(m, "On")), "the error log shows as off")
	ok(str(texts).contains("nothing is sent"), "and says that nothing is sent")
	m.queue_free()
	await _frames(2)


func test_switching_the_log() -> void:
	var m: Control = app.open_menu()
	await _frames(3)
	_log_button(m, "On").pressed.emit()
	await _frames(4)
	ok(UiSettings.error_log_on() and GameErrorLog.installed(), "switching it on starts the log")
	var m2 := _menu()
	ok(m2 != null and _is_marked(_log_button(m2, "On")), "the menu comes back showing it on")
	var cf := ConfigFile.new()
	cf.load(UiSettings.path)
	ok(str(cf.get_value("ui", "error_log", "")) == "on", "the choice is kept in the settings file")
	push_warning("(test) something creaked")
	ok(GameErrorLog.recent().size() == 1, "an error is remembered while it is on")
	_log_button(m2, "Off").pressed.emit()
	await _frames(4)
	ok(not UiSettings.error_log_on() and not GameErrorLog.installed() and GameErrorLog.recent().is_empty(), "switching it off stops the log and forgets what it had")
	_log_button(_menu(), "On").pressed.emit()
	await _frames(4)
	_menu().queue_free()
	await _frames(2)


func test_report_from_a_game() -> void:
	app.new_game("Tess", "warrior", "faetouched", 21)
	await _frames(3)
	push_error("(test) the kettle boiled over")
	var m: Control = app.open_menu()
	await _frames(3)
	_btn("Report a problem", m).pressed.emit()
	await _frames(3)
	var p := _panel()
	ok(p != null, "Report a problem opens the report panel")
	var texts := _texts(p)
	var all := str(texts)
	ok(texts.has(GameReport.text("never_sent")), "it says the report is not sent anywhere")
	var held := true
	for line in GameReport.holds():
		if not texts.has("- " + str(line)):
			held = false
	ok(held, "and lists everything a report holds")
	ok(texts.has("The error log is on: 1 remembered."), "and how many errors it will carry")
	p.note_box.text = "The pack would not open."
	Clipboard.fake_text = ""
	_btn("Copy report", p).pressed.emit()
	await _frames(2)
	var read := GameReport.from_text(Clipboard.fake_text)
	ok(read["ok"], "Copy report puts a report on the clipboard that reads back (%s)" % str(read["error"]))
	var r: Dictionary = read["report"]
	ok(r["note"] == "The pack would not open.", "with the note")
	ok(r["errors"].size() == 1 and str(r["errors"][0]).contains("the kettle boiled over"), "the logged error")
	ok(r["env"].get("os", "") == OS.get_name() and r["env"].get("screen", "") == "1280x720" and r["env"].get("text_size", "") == "100%", "the device facts (%s)" % str(r["env"]))
	var d := GameReport.dynasty(r)
	ok(d != null and d.dynasty_name == app.dynasty.dynasty_name and d.heir.name == "Tess" and d.rng.state == app.dynasty.rng.state, "and the house being played, dice and all")
	ok(p.said.text.contains("copied"), "the panel says it was copied")
	_btn("Close", p).pressed.emit()
	await _frames(2)
	ok(_panel() == null and _menu() != null, "Close goes back to the menu")
	_menu().queue_free()
	await _frames(2)


func test_report_to_a_file() -> void:
	app.open_menu()
	await _frames(2)
	_btn("Report a problem", _menu()).pressed.emit()
	await _frames(3)
	var p := _panel()
	FilePicker.fake_path = ""
	_btn("Save report to a file", p).pressed.emit()
	await _frames(2)
	ok(p.said.text == "Nothing was saved.", "cancelling the file dialog saves nothing")
	var path := DIR + "problem.glreport"
	FilePicker.fake_path = path
	_btn("Save report to a file", p).pressed.emit()
	await _frames(2)
	ok(FileAccess.file_exists(path) and p.said.text.contains("Saved to"), "Save report to a file writes it")
	var read := GameReport.from_text(FileAccess.get_file_as_string(path))
	ok(read["ok"] and GameReport.dynasty(read["report"]) != null, "and the file is a report with the house in it")
	FilePicker.fake_path = "user://no_such_folder_at_all/x.glreport"
	_btn("Save report to a file", p).pressed.emit()
	await _frames(2)
	ok(p.said.text.contains("could not be written"), "a file that cannot be written says so, and offers Copy")
	ok(app.go_back() != "" and (_panel() == null or _panel().is_queued_for_deletion()), "the back button closes the panel")
	await _frames(2)
	if _menu() != null:
		_menu().queue_free()
	await _frames(2)


func test_report_from_the_title() -> void:
	app.show_title()
	await _frames(3)
	var m: Control = app.open_menu()
	await _frames(3)
	ok(_btn("Report a problem", m) != null, "the title's settings have Report a problem too (a game that will not load can still be reported)")
	_btn("Report a problem", m).pressed.emit()
	await _frames(3)
	Clipboard.fake_text = ""
	_btn("Copy report", _panel()).pressed.emit()
	await _frames(2)
	var read := GameReport.from_text(Clipboard.fake_text)
	ok(read["ok"] and read["report"]["save"] == null and read["report"]["env"].has("os"), "a report from the title reads back, with no house in it")
	_panel().queue_free()
	_menu().queue_free()
	await _frames(2)


func test_report_in_a_fight() -> void:
	app.new_game("Tess", "warrior", "faetouched", 22)
	await _frames(3)
	app.dynasty.start_hunt("hunt")
	app.show_state()
	await _frames(3)
	ok(app.dynasty.battle != null and app.menu_mode() == "battle", "(a fight is on)")
	var m: Control = app.open_menu()
	await _frames(3)
	_btn("Report a problem", m).pressed.emit()
	await _frames(3)
	Clipboard.fake_text = ""
	_btn("Copy report", _panel()).pressed.emit()
	await _frames(2)
	var read := GameReport.from_text(Clipboard.fake_text)
	var d := GameReport.dynasty(read["report"]) if read["ok"] else null
	ok(d != null and d.battle != null and d.battle.enemies.size() == app.dynasty.battle.enemies.size(), "a report made in a fight opens in that fight")
	_panel().queue_free()
	_menu().queue_free()
	await _frames(2)


func test_env() -> void:
	var facts := ReportEnv.facts(root)
	var kept := GameReport.clean_env(facts)
	ok(kept.size() == facts.size(), "every fact the screen offers is one a report is allowed to keep (%d of %d)" % [kept.size(), facts.size()])
	for k in ["os", "model", "screen", "text_size", "layout", "time"]:
		ok(kept.has(k), "the device facts include %s" % k)
	var all := JSON.stringify(facts)
	ok(not all.contains(OS.get_user_data_dir()) and not all.contains(OS.get_environment("HOME") if OS.get_environment("HOME") != "" else "//none//"), "and no folder of the player's")
