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
const HousePanel := preload("res://ui/play/house_panel.gd")
const Chronicle := preload("res://ui/play/chronicle_panel.gd")
const SkillTreePanel := preload("res://ui/play/skill_tree_panel.gd")
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
	await test_boot()
	await test_map_menu()
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


const TitleScreen := preload("res://ui/play/title_screen.gd")


## The real game launches into the open world when a house is saved: main.gd sets boot_in_world; the tests and tools that make an app
## themselves do not, so they open the title as ever.
func test_boot() -> void:
	ok(FileAccess.get_file_as_string("res://main.gd").contains("boot_in_world = true"), "the game's entry point (main.gd) asks the app to boot into the world")
	DirAccess.remove_absolute(GameDynasty.save_path)
	DirAccess.remove_absolute(GameDynasty.save_path + ".bak")
	UiSettings.set_open_world_first(true)
	var none: Node = GameApp.new()
	none.boot_in_world = true
	root.add_child(none)
	await _frames(3)
	ok(none.current is TitleScreen, "with no house saved the real game opens the title (a new dynasty to found)")
	none.queue_free()
	await _frames(2)
	var maker: Node = await _app()
	maker.new_game("Tess", "warrior", "faetouched", 7)   # saves a house
	maker.queue_free()
	await _frames(2)
	var plain: Node = GameApp.new()
	root.add_child(plain)
	await _frames(3)
	ok(plain.current is TitleScreen, "an app made without boot_in_world (the tests, the tools) opens the title even with a house saved")
	plain.queue_free()
	await _frames(2)
	var boot: Node = GameApp.new()
	boot.boot_in_world = true
	root.add_child(boot)
	await _frames(3)
	ok(boot.current is SandboxScreen and boot.dynasty != null, "the real game with a house saved opens the 2D open world at once")
	boot.queue_free()
	await _frames(2)
	# a house saved in the middle of a fight does not launch into that fight: the title, whose Continue resumes it
	var fighter := await _app()
	fighter.new_game("Tess", "warrior", "faetouched", 7)
	fighter.dynasty.start_hunt("hunt")
	fighter.dynasty.save_to_disk()
	fighter.queue_free()
	await _frames(2)
	var fight_boot: Node = GameApp.new()
	fight_boot.boot_in_world = true
	root.add_child(fight_boot)
	await _frames(3)
	ok(fight_boot.current is TitleScreen and fight_boot.dynasty == null, "a saved fight does not open the game: the title does")
	fight_boot.continue_game(true)
	await _frames(3)
	ok(fight_boot.dynasty != null and fight_boot.dynasty.battle != null and fight_boot.current is BattleView, "and Continue from there resumes the fight")
	fight_boot.queue_free()
	await _frames(2)
	maker = await _app()
	maker.new_game("Tess", "warrior", "faetouched", 7)   # a house with no fight again
	maker.queue_free()
	await _frames(2)
	UiSettings.set_open_world_first(false)
	var life: Node = GameApp.new()
	life.boot_in_world = true
	root.add_child(life)
	await _frames(3)
	ok(life.current is TitleScreen, "and the title when the player chose the life screen")
	life.queue_free()
	await _frames(2)
	UiSettings.set_open_world_first(true)
	# a session that ended without warning leaves its mark: the title comes first, with the offer of a report
	var mark_path := UiSettings.path.get_base_dir().path_join("session.mark")
	var mark := FileAccess.open(mark_path, FileAccess.WRITE)
	mark.store_string("running")
	mark.close()
	var bad: Node = GameApp.new()
	bad.boot_in_world = true
	root.add_child(bad)
	await _frames(3)
	ok(bad.closed_badly and bad.current is TitleScreen, "after a bad close the title comes first (it offers the error report)")
	bad.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(mark_path)
	# a house that cannot be read falls back to the title
	var junk := FileAccess.open(GameDynasty.save_path, FileAccess.WRITE)
	junk.store_string("not a save")
	junk.close()
	DirAccess.remove_absolute(GameDynasty.save_path + ".bak")
	var broken: Node = GameApp.new()
	broken.boot_in_world = true
	root.add_child(broken)
	await _frames(3)
	ok(broken.current is TitleScreen, "a saved house that cannot be read falls back to the title")
	broken.queue_free()
	await _frames(2)


## Back and Escape in the open world open a menu of popups over the map; the player is not sent to the text game unless they pick it.
func test_map_menu() -> void:
	UiSettings.set_open_world_first(true)
	var app := await _app()
	app.new_game("Tess", "warrior", "faetouched", 7)
	await _frames(2)
	app.show_sandbox()
	await _frames(3)
	var map: Node = app.current
	ok(map is SandboxScreen, "the open world is up")
	map._open_menu()
	await _frames(2)
	var menu: PopupMenu = null
	for c in map.get_children():
		if c is PopupMenu:
			menu = c
	ok(menu != null and menu.has_meta("modal") and app.current == map, "Menu opens a popup over the map and stays on it")
	ok(menu != null and menu.item_count == 6 and menu.get_item_text(0) == "Back to the map" and menu.get_item_text(5) == "The text screen", "with the family's screens and the way back to the text game")
	ok(map._modal_open(), "and the world waits while it is open")
	for script in [HousePanel, Chronicle, SkillTreePanel]:
		map._open_popup(script)
		await _frames(2)
		var found := false
		for c in map.get_children():
			if c.get_script() == script and c.has_meta("modal"):
				found = true
				c.queue_free()
		ok(found and app.current == map, "%s opens over the map as a modal, not as a new screen" % script.resource_path.get_file())
		await _frames(2)
	map._open_gear()
	await _frames(2)
	ok(app.current == map and map._modal_open(), "Gear opens over the map too")
	app.queue_free()
	await _frames(2)
