## A fight played over the open world's map (roadmap item 48): when a creature catches the heir the battle screen opens over the
## map, as a child of it, under a stand-in app (the map is not swapped away, the creatures and the heir stay where they were);
## the world waits while it is on; when it is done the map comes back and the heir is where the fight left them, or clear of it
## if they fled; a heir who falls (or a line that ends) goes on to the life's next screen, and only then; and the stand-in
## gives the battle screen what it asks of an app.
## Run: godot --headless --path . -s res://tests/test_game_map_fight.gd
extends SceneTree

const MapFight := preload("res://ui/play/map_fight.gd")
const BattleView := preload("res://ui/play/battle_view.gd")

var fails := 0
var checks := 0


class FakeSound extends Node:
	func cue(_c: Variant) -> void:
		pass


class FakeApp extends Node:
	var dynasty: GameDynasty
	var sound := FakeSound.new()
	var hunt_stopped := false
	var current: Control = null
	var shown := 0
	var saved := 0

	func show_state() -> void:
		shown += 1

	func autosave() -> void:
		saved += 1


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	GameDynasty.save_path = "user://test_map_fight.json"
	test_host()
	await test_flow()
	await test_flight()
	await test_fall()
	print("map fight tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _screen() -> Dictionary:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	var app := FakeApp.new()
	app.dynasty = d
	app.add_child(app.sound)
	root.add_child(app)
	var scr: Control = load("res://ui/play/sandbox_screen.gd").new()
	scr.app = app
	scr.size = Vector2(1280, 720)
	root.add_child(scr)
	return {"app": app, "scr": scr, "d": d}


## A wolf hunting the heir right beside them, and the contact that starts the fight.
func _catch(scr: Control) -> void:
	scr.sb.creatures.clear()
	var p: Vector2 = scr.sb.heir_point()
	var a := GameBehaviour.new_agent(901, "wolf", p.x + 0.5, p.y)
	a["mode"] = "chase"
	scr.sb.creatures.append(a)
	scr.sb._contact()


func test_host() -> void:
	var host := MapFight.new()
	var app := FakeApp.new()
	host.app = app
	ok(host.hunt_stopped, "a fight on the map never chains into the next hunt")
	host.autosave()
	ok(app.saved == 1, "the stand-in saves through the real app")
	var done := [0]
	host.on_done = func(): done[0] += 1
	host.show_state()
	ok(done[0] == 1 and app.shown == 0, "and its show_state is the map's 'fight over', not the app's swap")
	host.free()
	app.sound.free()
	app.free()


func test_flow() -> void:
	var h := _screen()
	var app: FakeApp = h["app"]
	var scr: Control = h["scr"]
	var d: GameDynasty = h["d"]
	await process_frame
	await process_frame
	_catch(scr)
	ok(d.battle != null, "a hunter reaches the heir: a fight")
	var heir_then: Vector2i = scr.sb.heir
	await process_frame
	await process_frame
	ok(scr._fight != null and scr._fight.get_parent() == scr, "the battle screen is a child of the map")
	ok(scr._fight.app is MapFight and scr._fight.app.dynasty == d, "running under the stand-in app")
	ok(app.shown == 0, "and the app did not swap the screen")
	var tick: int = scr.sb.tick
	for i in 40:
		await process_frame
	ok(scr.sb.tick == tick and scr.sb.heir == heir_then, "the world waits while the fight is on")
	var running: Control = scr._fight
	scr._fight.app.show_state()   # the battle screen says it is done while the fight is still on: it is not over
	await process_frame
	ok(scr._fight == running and is_instance_valid(running) and not running.is_queued_for_deletion() and d.battle != null, "the map does not take the fight away while it is still on (the same battle screen is still running)")
	# the fight is won and the player presses Continue
	for e in d.battle.enemies:
		e["hp"] = 0
	d.battle.result = "victory"
	d.finish_battle()
	scr._fight.app.show_state()
	await process_frame
	await process_frame
	ok(scr._fight == null and d.battle == null, "when it is over the battle screen is gone")
	var left := 0
	for c in scr.get_children():
		if c is BattleView or c is MapFight:
			left += 1
	ok(left == 0, "and neither it nor its stand-in is left on the map (%d)" % left)
	ok(scr.sb.heir == heir_then and app.shown == 0, "and the heir is where they were, still on the map")
	for i in 80:
		await process_frame
	ok(scr.sb.tick > tick, "and the world goes on")
	scr.queue_free()
	app.queue_free()


func test_flight() -> void:
	var h := _screen()
	var app: FakeApp = h["app"]
	var scr: Control = h["scr"]
	var d: GameDynasty = h["d"]
	await process_frame
	await process_frame
	_catch(scr)
	var heir_then: Vector2i = scr.sb.heir
	var way := Vector2i(int(d.sandbox_escape["x"]), int(d.sandbox_escape["z"]))
	await process_frame
	await process_frame
	d.battle.result = "fled"
	d.finish_battle()
	scr._fight.app.show_state()
	await process_frame
	await process_frame
	ok(scr._fight == null and scr.sb.heir == way and way != heir_then, "fleeing puts the heir clear of the fight, on the map, at once: %s" % str(scr.sb.heir))
	ok(d.sandbox_escape.is_empty() and scr.sb.log.size() > 0 and str(scr.sb.log[-1]["text"]).contains("clear of the fight"), "and says so")
	ok(app.shown == 0, "without leaving the map")
	scr.queue_free()
	app.queue_free()


func test_fall() -> void:
	var h := _screen()
	var app: FakeApp = h["app"]
	var scr: Control = h["scr"]
	var d: GameDynasty = h["d"]
	await process_frame
	await process_frame
	_catch(scr)
	await process_frame
	await process_frame
	d.battle.result = "defeat"
	d.finish_battle()
	d.state = "succession"   # the heir fell
	for i in 20:
		await process_frame
	ok(scr._fight != null and app.shown == 0, "while the result is on screen the map does not take it away")
	scr._fight.app.show_state()
	await process_frame
	await process_frame
	ok(scr._fight == null and app.shown >= 1, "and once it is closed the life's next screen comes")
	scr.queue_free()
	app.queue_free()
