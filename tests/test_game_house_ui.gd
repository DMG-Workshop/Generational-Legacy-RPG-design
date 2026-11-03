## The family house on the life screen: House opens the panel, a row's Build button raises that track
## and takes the gold, and a row that cannot be built is disabled.
## Run: godot --headless --path . -s res://tests/test_game_house_ui.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const HousePanel := preload("res://ui/play/house_panel.gd")
const DIR := "user://test_house_ui/"

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
	app.show_state()
	await _frames(3)
	var d: GameDynasty = app.dynasty
	ok(_panel() == null, "no house panel before House is pressed")

	# Without gold the Hall cannot be built: its Build button is disabled.
	d.heir.gold = 0
	_press("House")
	await _frames(3)
	ok(_panel() != null, "House opens the family house panel")
	var hall_build := _button_starting(_panel(), "Build")
	ok(hall_build != null and hall_build.disabled, "with no gold, the Build button is disabled")
	ok(_shows_text(_panel(), "Not enough gold"), "and the reason is shown as text, not only a tooltip")
	_panel().queue_free()
	await _frames(2)

	# With enough gold, building the Hall raises it a level and takes the gold.
	d.heir.gold = 10000
	_press("House")
	await _frames(3)
	hall_build = _button_starting(_panel(), "Build")
	ok(hall_build != null and not hall_build.disabled, "with gold, the Build button is enabled")
	var before := d.heir.gold
	var price := GameHouse.cost(d, GameHouse.HALL)
	hall_build.pressed.emit()
	await _frames(2)
	ok(GameHouse.level(d, GameHouse.HALL) == 1, "building the Hall raises it to level 1")
	ok(d.heir.gold == before - price, "and takes its price in gold")
	ok(_panel() != null, "the panel stays open after a purchase")
	ok(GameParty.max_size(d) == int(GameData.bal("party_max_size")) + 1, "the Hall adds a companion place")

	_wipe()
	print("house ui tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _wipe() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)


func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


func _panel() -> Node:
	for c in app.current.get_children():
		if c.get_script() == HousePanel:
			return c
	return null


func _press(text: String) -> void:
	for b in _buttons(app.current):
		if b.text.begins_with(text):
			b.pressed.emit()
			return


func _shows_text(n: Node, text: String) -> bool:
	if n is Label and (n as Label).text.begins_with(text):
		return true
	for c in n.get_children():
		if _shows_text(c, text):
			return true
	return false


func _button_starting(panel: Node, text: String) -> Button:
	if panel == null:
		return null
	for b in _buttons(panel):
		if b.text.begins_with(text):
			return b
	return null


func _buttons(n: Node, out: Array = []) -> Array:
	if n is Button and (n as Button).is_visible_in_tree():
		out.append(n)
	for c in n.get_children():
		_buttons(c, out)
	return out
