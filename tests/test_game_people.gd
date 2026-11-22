## People inside rooms (roadmap item 41): each service interior has a person at a fixed floor cell of its entrance room, solid and
## drawn as `person`; the heir talks to the one beside them (Use), the service opens when the family is in that town and the line
## only talks away from it; the place line names them; leaving by the exit still works; the data checks; the screen opens the
## service over the map and the world waits. No dice, nothing saved.
## Run: godot --headless --path . -s res://tests/test_game_people.gd
extends SceneTree

var fails := 0
var checks := 0


class FakeApp extends Node:
	var dynasty: GameDynasty

	func show_state() -> void:
		pass


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	test_data()
	test_cells()
	test_talk()
	test_not_here()
	test_exit()
	await test_screen()
	print("people tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh() -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


func _inside(d: GameDynasty, id: String) -> GameSandbox:
	var s := GameSandbox.start(d)
	s.creatures.clear()
	var door: Dictionary = GameSpaces.space(id)["door"]
	s.heir = Vector2i(int(door["x"]), int(door["z"]))
	var r := s.use()
	ok(bool(r["ok"]) and s.space == id, "(went in to %s)" % id)
	return s


## The interior of a layout in the town where the family is, or in any town that has it.
func _space_of(layout: String) -> String:
	for id in GameSpaces.ids():
		if GameSpaces.kind(id) == "interior" and str(GameSpaces.space(id).get("layout", "")) == layout and str(GameSpaces.space(id).get("place", "")) == "hearthmere":
			return id
	for id in GameSpaces.ids():
		if GameSpaces.kind(id) == "interior" and str(GameSpaces.space(id).get("layout", "")) == layout:
			return id
	return ""


func test_data() -> void:
	ok(GamePeople.validate().is_empty(), "the shipped data passes: %s" % str(GamePeople.validate()))
	ok(GamePeople.data()["people"].size() == 6 + GameShops.ids().size(), "a person for each service interior: the six old services and the shops")
	var rows: Array = GamePeople.data()["people"]
	var keep: Variant = rows[0]["at"]
	rows[0]["at"] = [0, 0]
	ok(not GamePeople.validate().is_empty(), "a person on the way out is caught")
	rows[0]["at"] = [20, 20]
	ok(not GamePeople.validate().is_empty(), "a person outside the entrance room is caught")
	rows[0]["at"] = keep
	var open: Variant = rows[0]["open"]
	rows[0]["open"] = "spell"
	ok(not GamePeople.validate().is_empty(), "a service that does not exist is caught")
	rows[0]["open"] = open
	var tab: Variant = rows[1]["tab"]
	rows[1]["tab"] = "nonesuch"
	ok(not GamePeople.validate().is_empty(), "a shop tab that does not exist is caught")
	rows[1]["tab"] = tab
	ok(GamePeople.validate().is_empty(), "and mending the data clears it")


func test_cells() -> void:
	for p in GamePeople.data()["people"]:
		var id := _space_of(str(p["layout"]))
		var cells := GameInterior.cells(id)
		var c := GamePeople.cell_of(p)
		ok(str(cells.get(GameInterior.key(c.x, c.y), "")) == "person", "%s stands at their cell in %s" % [p["name"], p["layout"]])
		ok(not GameInterior.passable(cells, c.x, c.y), "and is solid")
		var reach := GameInterior.reachable(cells)
		var floors := 0
		var reached := 0
		for k in cells:
			if str(cells[k]) in ["floor", "door", "exit"]:
				floors += 1
				if reach.has(k):
					reached += 1
		ok(floors == reached, "every floor tile is still reachable round them (%d of %d)" % [reached, floors])
	ok(not GameInterior.cells("world/hearthmere/house").values().has("person"), "the family house has nobody yet")


func test_talk() -> void:
	var d := _fresh()
	d.world.location = "hearthmere"
	var s := _inside(d, "world/hearthmere/store")
	var keeper: Dictionary = GamePeople.data()["people"][2]
	ok(str(keeper["layout"]) == "store", "(the storekeeper)")
	var c := GamePeople.cell_of(keeper)
	s = _inside(d, "world/hearthmere/store")
	s.heir = c + Vector2i(1, 0)
	ok(s.place_line().contains("Odo") and s.place_line().contains("Use to talk"), "beside them the line names them: %s" % s.place_line())
	var step := s.can_step(-1, 0)
	ok(not step["ok"], "the heir cannot walk into them")
	var rng_state := d.rng.state
	var r := s.use()
	ok(bool(r["ok"]) and str(r["open"]) == "shop" and str(r["tab"]) == "store", "Use opens their shop on its tab: %s" % str(r))
	ok(str(r["text"]).contains("Odo"), "with their greeting: %s" % r["text"])
	ok(s.space == "world/hearthmere/store", "and the heir is still inside")
	ok(d.rng.state == rng_state, "no dice are drawn")
	var far := s.heir
	s.heir = Vector2i(2, 0)
	ok(s.place_line().contains("You are") or not s.place_line().contains("Odo"), "away from them the line does not name them")
	s.heir = far
	# each person opens what the data says
	for p in GamePeople.data()["people"]:
		var dd := _fresh()
		dd.world_seconds = (0.5 - float(GameDay.setting("start_phase"))) * float(GameDay.setting("day_seconds"))   # noon: every shop is open
		var sid := _space_of(str(p["layout"]))
		dd.world.location = str(GameSpaces.space(sid)["place"])
		var ss := _inside(dd, sid)
		var pc := GamePeople.cell_of(p)
		for dir in GamePeople.DIRS:
			if GameInterior.passable(ss.interior, pc.x + dir.x, pc.y + dir.y) and Vector2i(pc.x + dir.x, pc.y + dir.y) != GameInterior.entry():
				ss.heir = pc + dir
				break
		var t := ss.use()
		ok(str(t["open"]) == str(p["open"]) and str(t["tab"]) == str(p["tab"]), "%s opens %s: %s" % [p["name"], p["open"], str(t)])


func test_not_here() -> void:
	var d := _fresh()
	d.world.location = "whisperwood"
	var s := _inside(d, "world/hearthmere/store")
	var keeper: Dictionary = GamePeople.data()["people"][2]
	s.heir = GamePeople.cell_of(keeper) + Vector2i(1, 0)
	var r := s.use()
	ok(bool(r["ok"]) and str(r["open"]) == "" and str(r["text"]).contains("not in this town"), "with the family elsewhere they only talk: %s" % r["text"])
	ok(GamePeople.talk(d, "world/hearthmere/store", {})["ok"] == false, "and talking to nobody says so")
	# in another town that has a store of its own, Hearthmere's keeper still only talks
	var other := ""
	for place in GameData.world["locations"]:
		d.world.location = str(place["id"])
		if str(place["id"]) != "hearthmere" and d.world.has_service("store"):
			other = str(place["id"])
			break
	ok(other != "", "(another town has a store: %s)" % other)
	d.world.location = other
	ok(str(s.use()["open"]) == "", "the family in %s: Hearthmere's keeper has nothing for them" % other)


func test_exit() -> void:
	var d := _fresh()
	d.world.location = "hearthmere"
	var s := _inside(d, "world/hearthmere/store")
	var r := s.use()
	ok(bool(r["ok"]) and s.space == "world", "Use on the way out leaves, as before")


func test_screen() -> void:
	var d := _fresh()
	d.world.location = "hearthmere"
	var app := FakeApp.new()
	app.dynasty = d
	root.add_child(app)
	var scr: Control = load("res://ui/play/sandbox_screen.gd").new()
	scr.app = app
	scr.size = Vector2(1280, 720)
	root.add_child(scr)
	await process_frame
	await process_frame
	scr.sb.creatures.clear()
	var door: Dictionary = GameSpaces.space("world/hearthmere/store")["door"]
	scr.sb.heir = Vector2i(int(door["x"]), int(door["z"]))
	scr._use()
	await process_frame
	var keeper: Dictionary = GamePeople.data()["people"][2]
	scr.sb.heir = GamePeople.cell_of(keeper) + Vector2i(1, 0)
	ok(not scr._modal_open(), "no panel to begin with")
	scr._use()
	await process_frame
	await process_frame
	ok(scr._modal_open(), "talking to the storekeeper opens the shop over the map")
	var panel: Control = null
	for c in scr.get_children():
		if c.has_meta("modal"):
			panel = c
	ok(panel != null and panel.start_tab == "store" and panel.tab == "store", "on the Store tab")
	var tick: int = scr.sb.tick
	for i in 60:
		await process_frame
	ok(scr.sb.tick == tick, "while it is open the world waits")
	panel.queue_free()
	await process_frame
	await process_frame
	ok(not scr._modal_open(), "closing it gives the map back")
	scr.queue_free()
	app.queue_free()
