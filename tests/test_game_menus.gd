## Menus that feel like a game (ui/play/menu_kit.gd, pause_panel.gd, slots_panel.gd, about_panel.gd, menu_panel.gd, title_screen.gd,
## toast.gd; data/ui/menus.json): the title's main menu with the page as its title, the open world's pause screen (Escape opens it, the world
## waits, Resume / Save / the text game / the main menu), the options in tabs, the save slots inside a game, toasts that stack and fade
## instead of boxes, and a Back on every panel (Escape closes the top one). Settings stay in settings.cfg, never in a save.
## Run: godot --headless --path . -s res://tests/test_game_menus.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const SandboxScreen := preload("res://ui/play/sandbox_screen.gd")
const LifeScreen := preload("res://ui/play/life_screen.gd")
const TitleScreen := preload("res://ui/play/title_screen.gd")
const MenuPanel := preload("res://ui/play/menu_panel.gd")
const PausePanel := preload("res://ui/play/pause_panel.gd")
const SlotsPanel := preload("res://ui/play/slots_panel.gd")
const AboutPanel := preload("res://ui/play/about_panel.gd")
const MenuKit := preload("res://ui/play/menu_kit.gd")
const Toast := preload("res://ui/play/toast.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const JournalPane := preload("res://ui/play/journal_pane.gd")

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
	UiSettings.path = "user://test_menus.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	GameDynasty.save_path = "user://test_menus_save.json"
	test_data()
	await test_toast()
	await test_title()
	await test_options()
	await test_pause()
	await test_slots()
	await test_toast_in_world()
	test_back_everywhere()
	for n in range(1, 4):
		GameSaves.delete(n)
	DirAccess.remove_absolute(UiSettings.path)
	print("menu tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _app() -> Node:
	UiSettings.force_touch = -1
	UiSettings.force_mobile = -1
	var app: Node = GameApp.new()
	root.add_child(app)
	await _frames(3)
	app.closed_badly = false
	GameSaves.base = "user://test_menus_save.json"
	app.use_slot(1)
	return app


func _button(n: Node, text: String) -> Button:
	if n is Button and (n as Button).is_visible_in_tree() and (n as Button).text == text:
		return n
	for c in n.get_children():
		var b := _button(c, text)
		if b != null:
			return b
	return null


func _child_of(n: Node, script: Script) -> Control:
	for c in n.get_children():
		if c.get_script() == script and not c.is_queued_for_deletion():
			return c
	return null


# ---------------------------------------------------------------- data

func test_data() -> void:
	ok(MenuKit.validate().is_empty(), "menus.json is valid: %s" % str(MenuKit.validate()))
	var keep: Dictionary = MenuKit.data().duplicate(true)
	MenuKit._cache["toast"]["max_visible"] = 0
	ok(not MenuKit.validate().is_empty(), "a toast stack that shows nothing is found")
	MenuKit._cache = keep.duplicate(true)
	MenuKit._cache["pause"]["rows"] = MenuKit._cache["pause"]["rows"].filter(func(r): return r["id"] != "resume")
	ok(not MenuKit.validate().is_empty(), "a pause screen with no Resume is found")
	MenuKit._cache = keep.duplicate(true)
	MenuKit._cache["main"]["rows"].append(MenuKit._cache["main"]["rows"][0].duplicate())
	ok(not MenuKit.validate().is_empty(), "a main-menu row listed twice is found")
	MenuKit._cache = keep
	ok(MenuKit.validate().is_empty(), "and the data reads clean again")
	var ids: Array = MenuKit.rows("options").map(func(r): return r["id"])
	ok(ids.has("sound") and ids.has("graphics") and ids.has("access") and ids.has("controls") and ids.has("text") and ids.has("touch") and ids.has("autopilot"), "the options group Sound, Graphics, Access, Controls, Text size, Touch and Autopilot")
	var main_ids: Array = MenuKit.rows("main").map(func(r): return r["id"])
	ok(main_ids == ["continue", "new", "slots", "options", "controls", "about", "quit"], "the main menu lists Continue, New dynasty, slots, Options, Controls, About and Quit")


# ---------------------------------------------------------------- toasts

func test_toast() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	root.add_child(host)
	var t: Control = Toast.attach(host)
	await _frames(2)
	Toast.history.clear()
	t.say("")
	t.say("   ")
	ok(t.count() == 0 and Toast.history.is_empty(), "an empty line says nothing")
	for i in 5:
		t.say("News %d" % i)
	ok(t.count() == int(MenuKit.toast("max_visible")), "at most %d toasts are up at once" % int(MenuKit.toast("max_visible")))
	ok(t.lines() == ["News 2", "News 3", "News 4"], "the oldest give way to the newest: %s" % str(t.lines()))
	ok(Toast.history.size() == 5, "but every line is kept in the history (%d)" % Toast.history.size())
	t.say("News 4")
	ok(Toast.history.size() == 5, "the same line twice in a row is told once")
	# stacked down from the top-right corner, none on top of another
	var nodes: Array = t.get_children()
	var ys: Array = nodes.map(func(n): return (n as Control).position.y)
	var sorted := ys.duplicate()
	sorted.sort()
	ok(ys == sorted and ys[0] >= float(MenuKit.toast("top")) - 0.5, "they stack downwards from the top (%s)" % str(ys))
	await _frames(2)
	for n in nodes:
		var r := Rect2((n as Control).position, (n as Control).size)
		ok(r.end.x <= 1280.0 + 0.5 and r.position.x >= 640.0, "a toast sits at the right edge, inside the screen")
	# they fade away by themselves
	t._process(float(MenuKit.toast("seconds")) + float(MenuKit.toast("fade_seconds")) + 0.1)
	ok(t.count() == 0, "toasts go when their time is up")
	# history is capped
	for i in int(MenuKit.toast("history_max")) + 20:
		t.say("Line number %d" % i)
	ok(Toast.history.size() == int(MenuKit.toast("history_max")), "the history keeps the last %d" % int(MenuKit.toast("history_max")))
	# reduced motion: shown at once, no sliding, and gone without a fade
	UiSettings.set_access("reduced_motion", true)
	t._process(100.0)
	t.say("Quiet news")
	var n: Control = t.get_children().back()
	ok(not n.has_meta("sliding") and is_equal_approx(n.modulate.a, 1.0), "with reduced motion a toast does not slide in or fade in")
	var x := n.position.x
	await _frames(3)
	ok(is_equal_approx(n.position.x, x), "and it does not move")
	t._process(float(MenuKit.toast("seconds")) + 0.01)
	ok(t.count() == 0, "and it goes at once when its time is up")
	UiSettings.set_access("reduced_motion", false)
	t.say("Moving news")
	var m: Control = t.get_children().back()
	ok(m.has_meta("sliding") or m.modulate.a < 1.0, "without it, a new toast slides in")
	var kinds: Array = []
	t.say("Good thing", "good")
	t.say("Bad thing", "bad")
	for c in t.get_children():
		kinds.append(c.get_meta("toast_kind", ""))
	ok(kinds.has("good") and kinds.has("bad"), "a toast has a kind that colours it")
	host.queue_free()
	await _frames(2)


# ---------------------------------------------------------------- the title

func test_title() -> void:
	var app: Node = await _app()
	GameSaves.delete(1)
	app.show_title()
	await _frames(3)
	var t: Control = app.current
	ok(t is TitleScreen and t.page == "menu", "the title opens on the main menu")
	ok(t.title_label.text == "GENERATIONAL LEGACY" and t.menu_box.visible and not t.new_box.visible, "its title is the game's and only the menu shows")
	for r in MenuKit.rows("main"):
		ok(_button(t, str(r["label"])) != null, "the main menu has %s" % r["label"])
	ok(_button(t, "Continue").disabled, "Continue is shut with no saved house")
	ok(not t.form_panel.visible, "the founding form is out of the way")
	_button(t, "New dynasty").pressed.emit()
	ok(t.page == "new" and t.title_label.text == "New dynasty" and t.form_panel.visible and not t.menu_box.visible, "New dynasty shows the form, and the screen's title says so")
	ok(app.go_back() == "screen" and t.page == "menu" and t.title_label.text == "GENERATIONAL LEGACY", "Escape (the app's back) steps back to the main menu")
	_button(t, "Load / Save slots").pressed.emit()
	ok(t.page == "slots" and t.title_label.text == "Save slots" and not t.form_panel.visible and t.slot_box.is_visible_in_tree(), "Load / Save slots shows the slots alone, titled so")
	ok(_button(t, "Back") != null, "with a Back button")
	_button(t, "Back").pressed.emit()
	ok(t.page == "menu", "that goes back to the menu")
	ok(not t.back(), "the main menu has nothing behind it")
	_button(t, "Options").pressed.emit()
	await _frames(2)
	ok(_child_of(t, MenuPanel) != null, "Options opens the options")
	_child_of(t, MenuPanel).queue_free()
	await _frames(2)
	_button(t, "Controls").pressed.emit()
	await _frames(2)
	ok(t.get_children().any(func(c): return c.get_script() != null and c.get_script().resource_path.ends_with("controls_panel.gd") and not c.is_queued_for_deletion()), "Controls opens the controls")
	app.go_back()
	await _frames(2)
	_button(t, "About").pressed.emit()
	await _frames(2)
	var about := _child_of(t, AboutPanel)
	ok(about != null and _button(about, "Back") != null, "About opens with a Back")
	ok(app.go_back() == "closed", "and Escape closes it")
	await _frames(2)
	# a saved house turns Continue on
	app.new_game("Tess", "warrior", "faetouched", 5)
	app.show_title()
	await _frames(3)
	ok(not _button(app.current, "Continue").disabled, "Continue opens once a house is saved")
	# a phone has no Quit
	UiSettings.force_mobile = 1
	app.show_title()
	await _frames(3)
	ok(_button(app.current, "Quit") == null, "a phone's main menu has no Quit")
	UiSettings.force_mobile = 0
	app.show_title()
	await _frames(3)
	ok(_button(app.current, "Quit") != null, "a desktop's has")
	# fingers
	UiSettings.force_touch = 1
	app.show_title()
	await _frames(3)
	var short: Array = []
	for r in MenuKit.rows("main"):
		var b := _button(app.current, str(r["label"]))
		if b != null and b.size.y < float(UiSettings.setting("touch_target_px")) - 0.5:
			short.append(b.text)
	ok(short.is_empty(), "on touch every main-menu button is a fingertip tall %s" % str(short))
	ok(_button(app.current, "Options").tooltip_text != "", "and each has its hint for a long press")
	UiSettings.force_touch = -1
	UiSettings.force_mobile = -1
	app.queue_free()
	await _frames(2)


# ---------------------------------------------------------------- the options

func test_options() -> void:
	var app: Node = await _app()
	app.new_game("Tess", "warrior", "faetouched", 5)
	await _frames(2)
	MenuPanel.last_tab = ""
	var m: Control = app.open_menu()
	await _frames(3)
	var ids: Array = MenuKit.rows("options").map(func(r): return r["id"])
	for id in ids:
		ok(m.pages.has(id), "the options have a %s page" % id)
		ok(_button(m, MenuKit.label_of("options", id)) != null, "and a tab for it")
	var shown := 0
	for id in m.pages:
		if (m.pages[id] as Control).visible:
			shown += 1
	ok(shown == 1, "one page shows at a time")
	m._select("autopilot")
	await _frames(2)
	ok(m.tab == "autopilot" and (m.pages["autopilot"] as Control).visible and not (m.pages["sound"] as Control).visible, "choosing a tab shows its page")
	var texts: Array = []
	for c in m.pages["autopilot"].get_children():
		for g in c.get_children():
			if g is Label:
				texts.append((g as Label).text)
	ok(texts.has("Auto: this life") and texts.has("Auto: 10 gens") and texts.has("Ready"), "the Autopilot tab lists both cooldowns: %s" % str(texts))
	m.queue_free()
	await _frames(2)
	m = app.open_menu()
	await _frames(3)
	ok(m.tab == "autopilot", "the options open on the tab last used")
	ok(m.pages.has("save"), "in a game there is a Save tab")
	var back := _button(m, "Back")
	ok(back != null, "the options have a Back")
	back.pressed.emit()
	await _frames(2)
	ok(not is_instance_valid(m) or m.is_queued_for_deletion(), "and it closes them")
	# the title has no Save tab
	app.show_title()
	await _frames(3)
	var m2: Control = app.open_menu()
	await _frames(2)
	ok(not m2.pages.has("save"), "the title's options have no Save tab")
	m2.queue_free()
	MenuPanel.last_tab = ""
	app.queue_free()
	await _frames(2)


# ---------------------------------------------------------------- the pause screen

func test_pause() -> void:
	var app: Node = await _app()
	app.new_game("Tess", "warrior", "faetouched", 7)
	await _frames(2)
	app.show_sandbox()
	await _frames(3)
	var map: Control = app.current
	ok(map is SandboxScreen, "the open world is up")
	ok(app.go_back() == "menu", "Escape (back) with nothing open pauses the world")
	await _frames(2)
	var p: Control = _child_of(map, PausePanel)
	ok(p != null and p.has_meta("modal") and map._modal_open(), "the pause screen is up and the world waits")
	var labels: Array = []
	for id in p.buttons:
		labels.append((p.buttons[id] as Button).text)
	ok(labels == MenuKit.rows("pause").map(func(r): return r["label"]), "it lists what the data says: %s" % str(labels))
	ok(map.open_pause() == p, "pausing again does not stack another")
	for id in p.buttons:
		ok((p.buttons[id] as Button).tooltip_text != "", "%s has a hint for hover and long press" % id)
	ok(app.go_back() == "closed", "Escape closes it")
	await _frames(2)
	ok(_child_of(map, PausePanel) == null and not map._modal_open(), "and the world goes on")
	# the key and the pause screen in the same frame: closing is not undone by the world's own Escape
	map.open_pause()
	await _frames(2)
	p = _child_of(map, PausePanel)
	p.close()
	ok(map.pause_closed_frame == Engine.get_process_frames(), "closing it marks the frame, so that frame's Escape does not reopen it")
	await _frames(2)
	# rows
	p = map.open_pause()
	await _frames(2)
	p.do("options")
	await _frames(2)
	ok(_child_of(map, MenuPanel) != null, "Options opens the options over the pause screen")
	ok(app.go_back() == "closed" and _child_of(map, PausePanel) != null, "Escape closes only the top one")
	await _frames(2)
	p.do("save")
	ok(p.note.text == "Saved." and GameSaves.peek(app.slot)["valid"], "Save writes the slot and says so")
	ok(map.toast.lines().has("Saved."), "and a toast tells it")
	p.do("text")
	await _frames(3)
	ok(app.current is LifeScreen, "Back to the text game leaves for the life screen")
	app.show_sandbox()
	await _frames(3)
	app.current.open_pause().do("main")
	await _frames(3)
	ok(app.current is TitleScreen and GameSaves.peek(app.slot)["valid"], "Main menu saves and goes to the title")
	# a phone has no Quit row; touch targets
	app.continue_game(true)
	await _frames(3)
	UiSettings.force_mobile = 1
	UiSettings.force_touch = 1
	var p2: Control = app.current.open_pause()
	await _frames(3)
	ok(not p2.buttons.has("quit"), "a phone's pause screen has no Quit")
	var short: Array = []
	for id in p2.buttons:
		if (p2.buttons[id] as Button).size.y < float(UiSettings.setting("touch_target_px")) - 0.5:
			short.append(id)
	ok(short.is_empty(), "every pause row is a fingertip tall %s" % str(short))
	UiSettings.force_mobile = -1
	UiSettings.force_touch = -1
	# changing a setting in the world keeps the world
	p2.queue_free()
	await _frames(2)
	app.current.open_pause().do("options")
	await _frames(2)
	app.set_ui_scale(1.25)
	await _frames(3)
	ok(app.current is SandboxScreen, "a text-size change in the world leaves the world where it is")
	ok(_child_of(app.current, MenuPanel) != null and _child_of(app.current, PausePanel) != null, "with the pause screen and the options back up")
	app.set_ui_scale(1.0)
	await _frames(2)
	app.queue_free()
	await _frames(2)


# ---------------------------------------------------------------- the slots in a game

func test_slots() -> void:
	var app: Node = await _app()
	for n in range(1, 4):
		GameSaves.delete(n)
	app.new_game("Tess", "warrior", "faetouched", 9)
	await _frames(2)
	app.show_sandbox()
	await _frames(3)
	var map: Control = app.current
	var p: Control = map.open_pause()
	await _frames(2)
	p.do("slots")
	await _frames(2)
	var s: Control = _child_of(p, SlotsPanel)
	ok(s != null and s.has_meta("back_close") and _button(s, "Back") != null, "the slots open over the pause screen, with a Back")
	ok(SlotsPanel.line(3).contains("empty") and SlotsPanel.line(1).contains("gen"), "each slot says what it holds: %s | %s" % [SlotsPanel.line(1), SlotsPanel.line(3)])
	ok(_button(s, "Load") != null and _button(s, "Save here") != null, "with Save here and Load")
	ok((s.find_child("Load_3", true, false) as Button).disabled, "an empty slot cannot be loaded")
	(s.find_child("Save_2", true, false) as Button).pressed.emit()
	ok(app.slot == 2 and GameSaves.peek(2)["valid"], "Save here puts the house in an empty slot and moves to it")
	ok(not s.confirm.visible, "an empty slot is not asked about")
	await _frames(2)
	s = _child_of(p, SlotsPanel)
	(s.find_child("Save_1", true, false) as Button).pressed.emit()
	ok(s.confirm.visible and app.slot == 2, "saving over another house asks first")
	s._confirmed()
	ok(app.slot == 1, "and Yes does it")
	(s.find_child("Load_2", true, false) as Button).pressed.emit()
	ok(s.confirm.visible, "loading asks first too")
	s._confirmed()
	await _frames(3)
	ok(app.slot == 2 and app.current is SandboxScreen, "and loads the slot into the world")
	app.queue_free()
	await _frames(2)


# ---------------------------------------------------------------- toasts in the world

func test_toast_in_world() -> void:
	var app: Node = await _app()
	app.new_game("Tess", "warrior", "faetouched", 11)
	await _frames(2)
	app.show_sandbox()
	await _frames(3)
	var map: Control = app.current
	ok(map.toast != null, "the open world has a toast layer")
	Toast.history.clear()
	map.last_line = "You find a coin."
	ok(map.toast.lines().has("You find a coin."), "a line the world says is a toast")
	map.last_line = ""
	ok(map.toast.count() == 1, "an empty line is not")
	map._refresh_status()
	ok(not map.status.text.contains("You find a coin."), "and the status strip no longer repeats it")
	var j: Control = JournalPane.new()
	j.dynasty = app.dynasty
	j.sb = map.sb
	map.add_child(j)
	await _frames(3)
	j.refresh()
	ok(j.text().contains("You find a coin."), "the journal keeps what was told")
	j.queue_free()
	app.queue_free()
	await _frames(2)


# ---------------------------------------------------------------- Back everywhere

## Every panel script that opens over a screen is closable by Escape and the pad's B: it makes its overlay with Kit.overlay or marks itself
## with back_close.
func test_back_everywhere() -> void:
	var dir := DirAccess.open("res://ui/play")
	var missing: Array = []
	var seen := 0
	for f in dir.get_files():
		if not f.ends_with(".gd") or not (f.ends_with("_panel.gd") or f.ends_with("_pane.gd")):
			continue
		if f in ["panel_skin.gd"]:
			continue
		var src := FileAccess.get_file_as_string("res://ui/play/" + f)
		seen += 1
		if not (src.contains("Kit.overlay(") or src.contains("back_close")):
			missing.append(f)
	ok(seen >= 25, "the panels are found (%d)" % seen)
	ok(missing.is_empty(), "every panel and pane closes with Back / Escape: %s" % str(missing))
	for f in ["menu_panel.gd", "controls_panel.gd", "report_panel.gd", "slots_panel.gd", "about_panel.gd"]:
		var src := FileAccess.get_file_as_string("res://ui/play/" + f)
		ok(src.contains('Kit.button("Back"'), "%s has a Back button" % f)
