## Starting in the 2D open world (ui/play/game_app.gd, title_screen.gd, menu_panel.gd, ui_settings.gd): New game and Continue open the map
## rather than the life screen's text when the menu's Start in says so (the default), but only for a house that is in its life: a fight
## in progress, a succession or the saga's end come first. Calls that do not ask (the tests and tools that found a house) still
## land on the life screen. The setting is the player's, in settings.cfg, never the save.
## Run: godot --headless --path . -s res://tests/test_game_start_world.gd
extends SceneTree

const SandboxScreen := preload("res://ui/play/sandbox_screen.gd")
const LifeScreen := preload("res://ui/play/life_screen.gd")
const BattleView := preload("res://ui/play/battle_view.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const GameApp := preload("res://ui/play/game_app.gd")
const SUCCESSION := "succession"

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
	UiSettings.path = "user://test_start_world.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	GameDynasty.save_path = "user://test_start_world_save.json"
	test_setting()
	await test_app()
	await test_title()
	await test_menu()
	DirAccess.remove_absolute(UiSettings.path)
	print("start world tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _app() -> Node:
	var app: Node = GameApp.new()
	root.add_child(app)
	await _frames(3)
	app.closed_badly = false
	return app


func test_setting() -> void:
	ok(UiSettings.open_world_first(), "a new player starts in the open world")
	UiSettings.set_open_world_first(false)
	ok(not UiSettings.open_world_first(), "and the life screen can be chosen")
	UiSettings.set_open_world_first(true)
	ok(UiSettings.open_world_first(), "and the open world chosen again")
	UiSettings.store("start_in", "something else")
	ok(UiSettings.open_world_first(), "a stored value that is not 'life' reads as the open world")
	UiSettings.store("start_in", 7)
	ok(UiSettings.open_world_first(), "and so does one of the wrong kind")
	UiSettings.set_open_world_first(true)


func test_app() -> void:
	var app := await _app()
	app.new_game("Tess", "warrior", "faetouched", 7)
	await _frames(2)
	ok(app.current is LifeScreen, "a call that does not ask opens the life screen, as it always did")
	app.new_game("Tess", "warrior", "faetouched", 7, "human", GameSex.MALE, "", {}, true)
	await _frames(2)
	ok(app.current is SandboxScreen, "New game asking for the open world opens it")
	app.show_state()
	await _frames(2)
	ok(app.current is LifeScreen, "and Back from the map is the life screen")
	app.continue_game()
	await _frames(2)
	ok(app.current is LifeScreen, "Continue that does not ask opens the life screen")
	app.continue_game(true)
	await _frames(2)
	ok(app.current is SandboxScreen, "Continue asking for the open world opens it")
	# a house that is not in its life comes first
	app.show_state()
	await _frames(2)
	app.dynasty.state = SUCCESSION   # (only the decision is asked: no succession screen is built for a house with no heirs waiting)
	app._open_world_first()
	await _frames(2)
	ok(not (app.current is SandboxScreen), "a succession is not skipped for the map")
	app.dynasty.state = "ended"
	app._open_world_first()
	await _frames(2)
	ok(not (app.current is SandboxScreen), "nor the saga's end")
	app.dynasty.state = "life"
	app.dynasty.start_hunt("hunt")
	app.dynasty.save_to_disk()
	app.continue_game(true)
	await _frames(3)
	ok(app.dynasty.battle != null and app.current is BattleView, "a fight in progress comes back as the fight, not the map")
	app.queue_free()
	await _frames(2)


func test_title() -> void:
	var app := await _app()
	app.new_game("Tess", "warrior", "faetouched", 7)   # (saves a house to continue)
	app.show_title()
	await _frames(3)
	var title: Control = app.current
	UiSettings.set_open_world_first(true)
	title.cont.pressed.emit()
	await _frames(3)
	ok(app.current is SandboxScreen, "the title's Continue opens the map when Start in is the open world")
	app.show_title()
	await _frames(3)
	UiSettings.set_open_world_first(false)
	app.current.cont.pressed.emit()
	await _frames(3)
	ok(app.current is LifeScreen, "and the life screen when it is the life screen")
	app.show_title()
	await _frames(3)
	UiSettings.set_open_world_first(true)
	app.current._begin()
	await _frames(3)
	ok(app.current is SandboxScreen, "a new dynasty from the title opens the map too")
	app.show_title()
	await _frames(3)
	UiSettings.set_open_world_first(false)
	app.current._begin()
	await _frames(3)
	ok(app.current is LifeScreen, "and the life screen when that is chosen")
	app.queue_free()
	await _frames(2)


func _button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for c in node.get_children():
		var b := _button(c, text)
		if b != null:
			return b
	return null


func test_menu() -> void:
	var app := await _app()
	app.new_game("Tess", "warrior", "faetouched", 7)
	await _frames(2)
	UiSettings.set_open_world_first(true)
	app.open_menu()
	await _frames(3)
	var life := _button(app, "Life screen")
	var world := _button(app, "Open world")
	ok(life != null and world != null, "the menu has a Start in row")
	if life != null:
		life.pressed.emit()
		ok(not UiSettings.open_world_first(), "choosing the life screen is kept")
	app.open_menu()
	await _frames(3)
	var world2 := _button(app, "Open world")
	if world2 != null:
		world2.pressed.emit()
		ok(UiSettings.open_world_first(), "and the open world again")
	var d: GameDynasty = app.dynasty
	var before := JSON.stringify(d.to_dict())
	UiSettings.set_open_world_first(false)
	ok(JSON.stringify(d.to_dict()) == before, "the choice is not in the save")
	UiSettings.set_open_world_first(true)
	app.queue_free()
	await _frames(2)
