## The mate picker on the life screen: Found family opens the candidates (not a random spouse), a pick
## marries that candidate and closes the panel, and the screen shows the family afterwards.
## Run: godot --headless --path . -s res://tests/test_game_mates_ui.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const MatePanel := preload("res://ui/play/mate_panel.gd")
const DIR := "user://test_mates_ui/"

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
	app.new_game("Tess", "warrior", "faetouched", 31, "human", GameSex.MALE)
	app.dynasty.heir.age = maxf(app.dynasty.heir.age, app.dynasty.heir.family_min_age())
	app.show_state()
	await _frames(3)
	var d: GameDynasty = app.dynasty
	var panel := _panel()
	ok(panel == null, "no picker before Found family is pressed")
	_press_family()
	await _frames(3)
	panel = _panel()
	ok(panel != null, "Found family opens the mate picker")
	ok(d.heir.spouse == null, "and nothing is married until a mate is picked")
	var want: GameHeir = d.mate_candidates()[1]
	var pick: Button = null
	for b in _buttons(panel):
		if b.text.begins_with(want.name + " " + want.surname):
			pick = b
	ok(pick != null, "the second candidate is offered as a button")
	if pick != null:
		pick.pressed.emit()
	await _frames(3)
	ok(_panel() == null, "picking closes the picker")
	ok(d.heir.spouse != null and d.heir.spouse.name == want.name, "the picked candidate is married")
	ok(d.heir.family_founded, "and the family is founded")
	_wipe()
	print("mates ui tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _wipe() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)


func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


func _panel() -> Node:
	for c in app.current.get_children():
		if c.get_script() == MatePanel:
			return c
	return null


func _press_family() -> void:
	for b in _buttons(app.current):
		if b.text.begins_with("Found family"):
			b.pressed.emit()
			return


func _buttons(n: Node, out: Array = []) -> Array:
	if n is Button and (n as Button).is_visible_in_tree():
		out.append(n)
	for c in n.get_children():
		_buttons(c, out)
	return out
