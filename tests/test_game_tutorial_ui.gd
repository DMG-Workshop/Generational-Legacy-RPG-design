## The first-heir tutorial on the real screens: the life screen's tip strip follows the game and marks
## the buttons it points at, Skip tips and the menu switch it off and on (kept in the settings file, not
## the save), and the succession screen carries the last tip.
## Run: godot --headless --path . -s res://tests/test_game_tutorial_ui.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const MenuPanel := preload("res://ui/play/menu_panel.gd")
const LifeScreen := preload("res://ui/play/life_screen.gd")
const SuccessionScreen := preload("res://ui/play/succession_screen.gd")
const DIR := "user://test_tutorial_ui/"

var checks := 0
var fails := 0
var app: Node
var d: GameDynasty


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	GameDynasty.save_path = DIR + "save.json"
	UiSettings.path = DIR + "settings.cfg"
	UiSettings.scale = 1.0
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	root.size = Vector2i(1280, 720)
	await _frames(2)
	app = GameApp.new()
	root.add_child(app)
	await _frames(2)
	await test_default_and_first_tip()
	await test_tips_follow_the_game()
	await test_skip_and_menu()
	await test_succession()
	await test_later_generations()
	await test_layout()
	print("tutorial ui tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


## A new house with the tips on (the settings file is wiped first), on its life screen.
func _fresh() -> void:
	DirAccess.remove_absolute(UiSettings.path)
	app.new_game("Tess", "warrior", "faetouched", 77, "human")
	d = app.dynasty
	d.pending_event = {}
	app.show_state()
	await _frames(3)


func _buttons(n: Node, out: Array = []) -> Array:
	if n is Button and (n as Button).is_visible_in_tree():
		out.append(n)
	for c in n.get_children():
		_buttons(c, out)
	return out


func _button(prefix: String, host: Node = null) -> Button:
	for b in _buttons(host if host != null else app.current):
		if (b as Button).text.begins_with(prefix):
			return b
	return null


func _strip(host: Node = null) -> Node:
	return (host if host != null else app.current).find_child("TutorialTip", true, false)


func _tip_text() -> String:
	var strip := _strip()
	if strip == null:
		return ""
	return (strip.find_child("TipText", true, false) as Label).text


func _marked() -> Array:
	return _buttons(app.current).filter(func(b): return b.get_meta("tutorial_mark", false)).map(func(b): return (b as Button).text.split(" (")[0])


func test_default_and_first_tip() -> void:
	DirAccess.remove_absolute(UiSettings.path)
	ok(UiSettings.tutorial_on(), "with no settings file the tips are on")
	var cf := ConfigFile.new()
	cf.set_value("ui", "scale", 1.0)   # a file from before the tips has no key for them
	cf.save(UiSettings.path)
	ok(UiSettings.tutorial_on(), "so they are with an older settings file")
	await _fresh()
	ok(app.current is LifeScreen, "a new house opens on the life screen")
	ok(_strip() != null, "which shows a tip")
	ok("Welcome, Tess" in _tip_text() and "Hunt" in _tip_text(), "the first tip welcomes the heir and says Hunt: %s" % _tip_text())
	ok(_marked() == ["Hunt"], "and marks the Hunt button, not Hard hunt: %s" % str(_marked()))
	ok(_button("Skip tips") != null, "with a way to skip the tips")
	ok(not FileAccess.get_file_as_string(GameDynasty.save_path).contains("tutorial"), "nothing of it is in the save")


func test_tips_follow_the_game() -> void:
	await _fresh()
	d.total_hunts = 1
	app.show_state()
	await _frames(3)
	ok("Train" in _tip_text(), "after a hunt the tip is about training: %s" % _tip_text())
	ok(_marked().size() == 4 and _marked().all(func(t): return t.begins_with("Train")), "and all four Train buttons are marked: %s" % str(_marked()))
	d.heir.hp = 1
	app.show_state()
	await _frames(3)
	ok("badly hurt" in _tip_text(), "a hurt heir is told to rest: %s" % _tip_text())
	ok("Rest" in _marked() and _marked().any(func(t): return t.begins_with("Potion")), "marking Rest and Potion: %s" % str(_marked()))
	d.heir.full_heal()
	app.show_state()
	await _frames(3)
	_button("Train STR").pressed.emit()
	await _frames(3)
	ok(app.current is LifeScreen, "training keeps the life screen")
	ok("needs age" in _tip_text() and _marked().is_empty(), "trained but too young: the tip gives the age and marks nothing: %s" % _tip_text())
	d.heir.age = d.heir.family_min_age()
	app.show_state()
	await _frames(3)
	ok("can found a family" in _tip_text() and _marked() == ["Found family"], "old enough: found a family, marked: %s" % str(_marked()))
	_button("Found family").pressed.emit()
	await _frames(3)
	var mate_pick: Button = null
	for b in _buttons(app.current):
		if b.text.begins_with(d.mate_candidates()[0].name):
			mate_pick = b
	ok(mate_pick != null, "the button offers the mates first")
	if mate_pick != null:
		mate_pick.pressed.emit()
	await _frames(3)
	ok(d.heir.family_founded, "a mate picked from the button founds the family")
	ok("Retire" in _tip_text() and _marked() == ["Retire"], "then the tip is Retire, marked: %s" % _tip_text())


func test_skip_and_menu() -> void:
	await _fresh()
	_button("Skip tips").pressed.emit()
	await _frames(3)
	ok(_strip() == null and _marked().is_empty(), "Skip tips hides the strip and the marks")
	ok(not UiSettings.tutorial_on(), "and switches the tips off")
	ok(FileAccess.get_file_as_string(UiSettings.path).contains("tutorial=\"off\""), "in the settings file")
	app.show_state()
	await _frames(3)
	ok(_strip() == null, "a rebuilt screen still has none")
	# Another house, started later, stays quiet.
	app.new_game("Ann", "warrior", "faetouched", 78, "human")
	await _frames(3)
	ok(_strip() == null, "a new house has no tips while they are off")
	# The menu turns them back on and off.
	var menu: Control = app.open_menu()
	await _frames(3)
	var row := _tutorial_row(menu)
	ok(row != null and row.get_child_count() == 2, "the menu has a Tutorial tips row with two choices")
	if row == null:
		return
	(row.get_child(0) as Button).pressed.emit()   # On
	await _frames(3)
	ok(UiSettings.tutorial_on() and _strip() != null, "On brings the tips back")
	ok(app.current.get_children().back() is MenuPanel, "with the menu still open")
	var row2 := _tutorial_row(app.current.get_children().back())
	ok(row2 != null and (row2.get_child(0) as Button).get_theme_stylebox("normal") != (row2.get_child(1) as Button).get_theme_stylebox("normal"), "the choice in use is marked")
	(row2.get_child(1) as Button).pressed.emit()   # Off
	await _frames(3)
	ok(not UiSettings.tutorial_on() and _strip() == null, "Off hides them")
	for c in app.current.get_children():
		if c is MenuPanel:
			c.queue_free()
	await _frames(2)


## The Tutorial tips row of the menu: the row of buttons that follows its heading.
func _tutorial_row(menu: Node) -> HBoxContainer:
	var heading: Node = null
	var stack: Array = [menu]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label and (n as Label).text == "Tutorial tips":
			heading = n
			break
		stack.append_array(n.get_children())
	if heading == null:
		return null
	return heading.get_parent().get_child(heading.get_index() + 1) as HBoxContainer


func test_succession() -> void:
	await _fresh()
	d._die("old age")
	app.show_state()
	await _frames(3)
	ok(app.current is SuccessionScreen, "a death opens the succession screen")
	ok(_strip() != null and "Pick the child" in _tip_text(), "which carries the last tip: %s" % _tip_text())
	ok(not (str(d.last_death["name"]) in _tip_text()), "without repeating the title's news of who has died")
	_button("Skip tips").pressed.emit()
	await _frames(3)
	ok(_strip() == null and not UiSettings.tutorial_on(), "Skip tips works there too")
	# Choosing the first heir ends the tutorial for good.
	await _fresh()
	d._die("old age")
	app.show_state()
	await _frames(3)
	ok(UiSettings.tutorial_on() and _strip() != null, "with the tips on, the tip shows")
	app.current._choose(0)
	await _frames(3)
	ok(d.gen == 2 and app.current is LifeScreen, "the first succession is made")
	ok(not UiSettings.tutorial_on(), "and the tips are off from then on")
	ok(_strip() == null, "none on the new heir's screen")


## A later generation is never taught, even with the tips switched on.
func test_later_generations() -> void:
	await _fresh()
	d.gen = 2
	app.show_state()
	await _frames(3)
	ok(UiSettings.tutorial_on() and _strip() == null, "tips on, generation 2: no strip")
	ok(_marked().is_empty(), "and nothing marked")


## The strip stays inside a small phone screen at large text, with its text whole and the buttons reachable.
func test_layout() -> void:
	for wsize in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(2400, 1080)]:
		for s in [1.0, 1.5]:
			root.size = wsize
			app.set_ui_scale(s)
			await _fresh()
			var tag := "%dx%d at %d%%" % [wsize.x, wsize.y, int(s * 100.0)]
			var strip := _strip() as Control
			ok(strip != null, "%s: the strip shows" % tag)
			if strip == null:
				continue
			var room := Rect2(UiSettings.insets.position, UiSettings.room(app))
			var r := strip.get_global_rect()
			ok(room.encloses(r.grow(-1.0)), "%s: the strip is inside the screen (%s in %s)" % [tag, str(r), str(room)])
			var body := strip.find_child("TipText", true, false) as Label
			ok(body.size.y + 1.0 >= body.get_minimum_size().y and body.size.x > 100.0, "%s: its text has the room it wraps to (%s)" % [tag, str(body.size)])
			var hunt := _button("Hunt")
			ok(hunt != null and hunt.get_global_rect().size.x > 20.0, "%s: Hunt is still there" % tag)
	root.size = Vector2i(1280, 720)
	app.set_ui_scale(1.0)
	await _frames(3)
