## World spaces, part 2 (roadmap item 41): where the heir is and where a route puts it (heir_at, along); the rooms of every
## interior and the data that breaks them (rooms overlapping, a door to a missing room, a room nothing reaches, an interior
## with no entrance or two, a door that joins nothing, a realm not in realms.json, a shaft on a town's ground, a band that
## is the surface); the underworld as bands down a shaft; the realms as spaces and their gates as steps; and that none of
## it draws dice or saves anything.
## Run: godot --headless --path . -s res://tests/test_game_spaces_2.gd
extends SceneTree

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
	test_heir()
	test_rooms()
	test_room_data()
	test_underworld()
	test_realms()
	test_along()
	test_pure()
	print("spaces 2 tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _reset() -> void:
	GameSpaces._cache = {}
	GameSpaces._spaces = {}
	GameSpaces._order = []


func _break(change: Callable) -> Array:
	_reset()
	change.call(GameSpaces.data())
	GameSpaces._spaces = {}
	GameSpaces._order = []
	var problems := GameSpaces.validate()
	_reset()
	return problems


func _steps(route: Array) -> Array:
	return route.map(func(s): return "%s %s" % [s["step"], s["space"]])


func test_heir() -> void:
	var d := GameDynasty.new_game(5, "Tess", "warrior", "faetouched", "human")
	var h := GameSpaces.heir_at(d)
	var w := GameSpaces.where(d)
	ok(h["space"] == w["space"] and h["x"] == w["x"] and h["z"] == w["z"], "at a place the heir is that place's space at its door tile, as where says")
	ok(h["on_route"] == false and h["space"] == "world/hearthmere", "the heir is at Hearthmere and not on a route")
	d.world.visit("goblin_warrens")
	var g := GameSpaces.heir_at(d)
	ok(g["space"] == "world/goblin_warrens" and Vector2i(g["x"], g["z"]) == GameSpaces.map_tile("world/goblin_warrens"), "the heir in the Goblin Warrens is at the dungeon's door")


func test_along() -> void:
	var r := GameSpaces.route("world/hearthmere/forge", "world/hearthmere/tavern")
	var forge := GameSpaces.map_tile("world/hearthmere/forge")
	var tavern := GameSpaces.map_tile("world/hearthmere/tavern")
	var start := GameSpaces.along(r, 0.0)
	var end := GameSpaces.along(r, 1.0)
	var mid := GameSpaces.along(r, 0.5)
	ok(start["x"] == forge.x and start["z"] == forge.y and start["on_route"] == true, "a route at fraction 0 is at its first door")
	ok(end["x"] == tavern.x and end["z"] == tavern.y, "at fraction 1 it is at the last door")
	var half := Vector2i((forge.x + tavern.x) / 2, (forge.y + tavern.y) / 2)
	ok(absi(int(mid["x"]) - half.x) <= 1 and absi(int(mid["z"]) - half.y) <= 1 and mid["space"] == "world/hearthmere", "half way along the walk is half way between the doors, on the town's ground")
	ok(GameSpaces.along(r, 2.0) == end and GameSpaces.along(r, -1.0) == start, "a fraction outside 0 to 1 is held at the ends")
	ok(GameSpaces.along([], 0.5).is_empty(), "an empty route has no position")
	var up := GameSpaces.route("world/hearthmere/house", "world/hearthmere")
	ok(_steps(up) == ["leave world/hearthmere/house"] and GameSpaces.along(up, 0.2)["x"] == GameSpaces.map_tile("world/hearthmere/house").x, "a route with no walking is at its first step under half way, its last after")
	var far := GameSpaces.route("world/hearthmere", "world/goblin_warrens")
	var across := GameSpaces.along(far, 0.5)
	ok(across["space"] == "world" and across["on_route"] == true, "a long walk across the open world is on the open world")
	var deep := GameSpaces.route("world/hearthmere", "world/underworld/deep")
	var shaft := GameSpaces.along(deep, 1.0)
	ok(shaft["space"] == "world/underworld/underground" and shaft["depth"] == 160, "half a route down the shaft is in the underground band at its depth")
	var dr := GameSpaces.route("world/underworld/underground", "world/underworld/deep")
	ok(GameSpaces.along(dr, 0.5)["depth"] == 86 and GameSpaces.along(dr, 0.0)["depth"] == 12, "down the shaft the depth runs from the band's top to the next band's (12 to 160, halfway at 86)")


func test_rooms() -> void:
	var interiors := 0
	var all_ok := true
	for id in GameSpaces.ids():
		if GameSpaces.kind(id) != "interior":
			continue
		interiors += 1
		var rs := GameSpaces.rooms(id)
		var entrance := GameSpaces.entrance_room(id)
		if rs.is_empty() or entrance == "" or rs.size() > 4:
			all_ok = false
			print("  no rooms or entrance: ", id)
		elif GameSpaces.room_at(id, 0, 0) != entrance:
			all_ok = false
			print("  the door tile is not in the entrance: ", id)
	ok(interiors == 28 and all_ok, "all %d interiors have one to four rooms and an entrance, and the door's tile is in it" % interiors)
	ok(GameSpaces.rooms("world/hearthmere").is_empty() and GameSpaces.rooms("world/hearthmere/forge").size() == 3, "an area has no rooms; the forge has its three")
	ok(GameSpaces.room_at("world/hearthmere/forge", 0, 0) == "yard" and GameSpaces.room_at("world/hearthmere/forge", 4, 0) == "smithy", "the forge's yard is at its door and the smithy to the east")
	ok(GameSpaces.room_at("world/hearthmere/forge", 2, 0) == "" and GameSpaces.room_at("world/hearthmere/forge", 90, 90) == "", "a door gap is in no room, and far from the floor none")
	var path := GameSpaces.route_rooms("world/hearthmere/forge", "coal_store", "smithy")
	ok(path.size() == 2 and path[0]["from"] == "coal_store" and path[0]["to"] == "yard" and path[1]["to"] == "smithy", "from the coal store to the smithy is two doors, through the yard")
	ok(GameSpaces.route_rooms("world/hearthmere/forge", "yard", "yard").is_empty() and GameSpaces.route_rooms("world/hearthmere/forge", "yard", "nowhere").is_empty(), "the same room, or a room that is not there, has no route")
	ok(GameSpaces.route_rooms("world/hearthmere", "yard", "smithy").is_empty(), "an area has no floor to walk")
	var with_rooms := GameSpaces.route("world/hearthmere/forge", "world/hearthmere/tavern", "coal_store", "upstairs")
	ok(_steps(with_rooms) == ["walk world/hearthmere/forge", "leave world/hearthmere/forge", "walk world/hearthmere", "enter world/hearthmere/tavern", "walk world/hearthmere/tavern"], "leaving the forge from the coal store walks across its floor first, and entering the tavern walks to the upstairs (%s)" % str(_steps(with_rooms)))
	ok(with_rooms[0]["doors"] == 1 and with_rooms[-1]["to_room"] == "upstairs" and with_rooms[-1]["doors"] == 1, "each floor walk is counted in doors")
	ok(GameSpaces.route("world/hearthmere/forge", "world/hearthmere/tavern", "yard", "taproom").size() == 3, "from and to the entrance rooms there is no floor walk")


func _any(problems: Array, word: String) -> bool:
	for p in problems:
		if str(p).contains(word):
			return true
	return false


func test_room_data() -> void:
	ok(GameSpaces.validate().is_empty(), "the room data is sound: %s" % str(GameSpaces.validate()))
	ok(_any(_break(func(d): d["rooms"]["forge"]["rooms"][1]["rect"] = [0, -1, 4, 3]), "overlap"), "overlapping rooms are refused, and named as overlapping")
	ok(_any(_break(func(d): d["rooms"]["forge"]["doors"].append({"from": "yard", "to": "vault", "at": [2, 1]})), "is no room"), "a door to a room that is not there is refused")
	ok(_any(_break(func(d): d["rooms"]["forge"]["doors"] = [{"from": "yard", "to": "smithy", "at": [2, 0]}]), "cannot be reached"), "a room nothing reaches from the entrance is refused")
	ok(_any(_break(func(d): d["rooms"]["forge"]["rooms"][0].erase("entrance")), "exactly one entrance"), "an interior with no entrance room is refused")
	ok(_any(_break(func(d): d["rooms"]["forge"]["rooms"][1]["entrance"] = true), "exactly one entrance"), "an interior with two entrance rooms is refused")
	ok(_any(_break(func(d): d["rooms"]["forge"]["doors"][0]["at"] = [10, 10]), "does not join"), "a door that joins no two rooms is refused")
	ok(_any(_break(func(d): d["rooms"].erase("forge")), "has no rooms"), "an interior with no rooms at all is refused")
	ok(_any(_break(func(d): d["rooms"]["ghost_hall"] = d["rooms"]["forge"]), "which is no interior"), "rooms for an interior that does not exist are refused")
	ok(_any(_break(func(d): d["realm_gates"]["atlantis"] = [10, 10]), "not a realm in realms.json"), "a realm that is not in realms.json is refused")
	ok(not _break(func(d): d["realm_gates"]["material"] = [10, 10]).is_empty(), "a gate to the home realm is refused")
	ok(_any(_break(func(d): d["realm_gates"].erase("void")), "has no gate tile"), "a realm with no gate is refused")
	ok(_any(_break(func(d): d["underworld"]["shaft"] = [160, 288]), "cleared ground"), "a shaft on a town's cleared ground is refused")
	ok(_any(_break(func(d): d["underworld"]["bands"] = ["surface", "deep"]), "surface zone"), "the surface zone as a band of the underworld is refused")
	ok(GameSpaces.validate().is_empty(), "(and the data is whole again after)")


func test_underworld() -> void:
	var u := GameSpaces.space("world/underworld/underground")
	var dp := GameSpaces.space("world/underworld/deep")
	ok(u["kind"] == "underworld" and u["parent"] == "world" and u["depth"] == {"from": 12, "to": 159}, "the underground band is an underworld space under the open world, from depth 12 to 159")
	ok(dp["kind"] == "underworld" and dp["parent"] == "world/underworld/underground" and dp["depth"] == {"from": 160, "to": 400}, "the deep band lies under the underground, from 160 to the mine's deepest cell")
	ok(GameSpaces.map_tile("world/underworld/underground") == GameSpaces.map_tile("world/underworld/deep") and GameSpaces.map_tile("world/underworld/deep") == Vector2i(316, 316), "both bands are entered at the shaft's tile on the open world")
	ok(GameSpaces.chain("world/underworld/deep") == ["world/underworld/deep", "world/underworld/underground", "world"], "the deep band's chain runs up through the underground to the open world")
	var down := GameSpaces.route("world/hearthmere", "world/underworld/deep")
	ok(_steps(down) == ["leave world/hearthmere", "walk world", "enter world/underworld/underground", "walk world/underworld/underground", "enter world/underworld/deep"], "from Hearthmere down two bands: out to the shaft, down the underground, into the deep (%s)" % str(_steps(down)))
	ok(down[3]["cells"] == 148 and down[3]["depth"] == [12, 160] and not down[3].has("tiles"), "the walk down the underground is 148 cells, from depth 12 to 160")
	var up := GameSpaces.route("world/underworld/deep", "world/hearthmere")
	ok(_steps(up) == ["leave world/underworld/deep", "walk world/underworld/underground", "leave world/underworld/underground", "walk world", "enter world/hearthmere"], "and back: up through the underground, out to the open world, home (%s)" % str(_steps(up)))
	ok(up[1]["cells"] == 148 and up[1]["depth"] == [160, 12], "the way up walks the same 148 cells")
	var across := GameSpaces.route("world/underworld/deep", "world/underworld/underground")
	ok(_steps(across) == ["leave world/underworld/deep", "walk world/underworld/underground"] and across[1]["cells"] == 148, "from the deep to the band above it, the heir walks up to that band's top")
	ok(GameSpaces.route("world/underworld/underground", "world/underworld/deep").size() == 2, "from the underground to the deep is a walk down and an entry")
	ok(GameSpaces.map_tile("world/underworld/nowhere").x == -1 and GameSpaces.space("world/underworld/deep") != {}, "an unknown band is nowhere; the deep band is a space")
	ok(GameSpaces.band_span("deep")["to"] == 400 and GameSpaces.band_span("underground")["name"] == "Underground" and GameSpaces.band_span("atlantis").is_empty(), "bands take their depths and names from the mine's zones")
	ok(not GameWorldGen.in_anchor_ground(316, 316), "the shaft is clear of every place's ground")


func test_realms() -> void:
	var ids := GameRealms.ids()
	var all := true
	for r in ids:
		var s := GameSpaces.space("realm/" + str(r))
		if s.is_empty() or s["kind"] != "realm" or s["realm"] != r:
			all = false
	ok(all and ids.size() == 8, "each of the eight realms of realms.json is a realm space, realm/<id>")
	ok(GameSpaces.of_realm("verdant") == "realm/verdant" and GameSpaces.of_realm("atlantis") == "", "a realm the data does not have is no space")
	ok(GameSpaces.kind("realm/verdant") == "realm" and GameSpaces.parent("realm/verdant") == "world", "a realm is a child of the open world at its gate, not an area or interior")
	ok(GameSpaces.space("realm/material")["door"].is_empty() and GameSpaces.route("realm/material", "world").is_empty(), "the home realm has no gate and no route: the open world is its ground")
	var d := GameDynasty.new_game(5, "Tess", "warrior", "faetouched", "human")
	var r := GameSpaces.route("world/hearthmere", "realm/verdant")
	ok(_steps(r) == ["leave world/hearthmere", "walk world", "gate realm/verdant"], "from Hearthmere to the Verdant Court: out of the town, across the world, through the gate (%s)" % str(_steps(r)))
	ok(r[2]["way"] == "in" and r[2]["realm"] == "verdant" and r[2]["flag"] == "gate_verdant", "the gate step names the realm and the flag that opens it")
	ok(r[1]["to"] == [GameSpaces.map_tile("realm/verdant").x, GameSpaces.map_tile("realm/verdant").y], "the walk ends at the gate's tile")
	ok(not GameSpaces.gates_open(d, r), "with its flag unset the gate is shut")
	ok(GameSpaces.gates_open(d, GameSpaces.route("world/hearthmere", "world/goblin_warrens")), "a route with no gate is open")
	GameRealms.open_gate(d, "verdant")
	ok(GameSpaces.gates_open(d, r), "once the Standing Stones have opened the gate the route is open")
	var back := GameSpaces.route("realm/verdant", "world/hearthmere")
	ok(_steps(back) == ["gate realm/verdant", "walk world", "enter world/hearthmere"] and back[0]["way"] == "out", "back out of the Verdant Court through its gate, and home")
	ok(GameSpaces.route("realm/verdant", "realm/hollow")[0]["step"] == "gate", "from one realm to another goes out of the first gate")


func test_pure() -> void:
	var d := GameDynasty.new_game(5, "Tess", "warrior", "faetouched", "human")
	var rng_before := d.rng.state
	var save_before := JSON.stringify(d.to_dict())
	GameSpaces.heir_at(d)
	GameSpaces.rooms("world/hearthmere/forge")
	GameSpaces.room_at("world/hearthmere/forge", 0, 0)
	GameSpaces.route_rooms("world/hearthmere/forge", "coal_store", "smithy")
	GameSpaces.route("world/underworld/deep", "realm/verdant", "", "")
	GameSpaces.along(GameSpaces.route("world/hearthmere", "world/underworld/deep"), 0.4)
	GameSpaces.gates_open(d, GameSpaces.route("world/hearthmere", "realm/void"))
	GameSpaces.validate()
	ok(d.rng.state == rng_before and JSON.stringify(d.to_dict()) == save_before, "the new functions draw no dice and save nothing")
	var first := JSON.stringify(GameSpaces.ids().map(func(id): return GameSpaces.space(id)))
	_reset()
	ok(JSON.stringify(GameSpaces.ids().map(func(id): return GameSpaces.space(id))) == first, "built again, the spaces are the same")
