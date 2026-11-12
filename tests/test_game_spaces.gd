## World spaces and coordinates (roadmap item 41): the data and ways to break it; every authored place a space with an
## id, a kind, a parent and a door; towns and wilds areas of the open world, dungeons interiors; the services and the
## family house interiors of their town with doors on its cleared ground; where a space is on the map; which space a
## tile is in; where the heir is; the way from one space to another as leave, walk and enter; the text game's roads as
## walks; agreement with the generated world, the mine and the building claim; and that nothing is saved or rolled.
## Run: godot --headless --path . -s res://tests/test_game_spaces.gd
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
	test_data()
	test_places()
	test_interiors()
	test_map()
	test_where()
	test_routes()
	test_agreement()
	test_pure()
	print("spaces tests: %d checks, %d failures" % [checks, fails])
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


func test_data() -> void:
	ok(GameSpaces.validate().is_empty(), "the data is sound: %s" % str(GameSpaces.validate()))
	ok(not _break(func(d): d["service_doors"]["forge"] = [40, 0]).is_empty(), "a door outside its town's cleared ground is found")
	ok(not _break(func(d): d["service_doors"]["tavern"] = d["service_doors"]["forge"]).is_empty(), "two services behind one door are found")
	ok(not _break(func(d): d["service_doors"].erase("temple")).is_empty(), "a service with no door is found")
	ok(not _break(func(d): d["service_names"].erase("board")).is_empty(), "a service with no name is found")
	ok(not _break(func(d): d["kind_of_type"].erase("dungeon")).is_empty(), "a place type with no kind is found")
	ok(not _break(func(d): d["kind_of_type"]["town"] = "world").is_empty(), "a town that is a whole world is found")
	ok(not _break(func(d): d["root"]["id"] = "overworld").is_empty(), "a root that is not the generated world's own id is found")
	ok(not _break(func(d): d["house"]["door"] = [0, 0]).is_empty(), "a house on the town's own middle tile is found")
	ok(not _break(func(d): d["house"]["id"] = "forge").is_empty(), "a house named as a service is found")
	ok(GameSpaces.validate().is_empty(), "(and the data is whole again after)")


func test_places() -> void:
	var ids := GameSpaces.ids()
	ok(ids[0] == "world" and GameSpaces.kind("world") == "world" and GameSpaces.parent("world") == "", "the open world is the first space and has no parent")
	var places: Array = GameData.world["locations"]
	var all := true
	var areas := 0
	var interiors := 0
	for l in places:
		var id := GameSpaces.of_place(str(l["id"]))
		var s := GameSpaces.space(id)
		if id != "world/" + str(l["id"]) or s.is_empty() or s["parent"] != "world" or s["place"] != l["id"] or s["name"] != l["name"]:
			all = false
		if s.get("kind", "") == "area":
			areas += 1
		elif s.get("kind", "") == "interior":
			interiors += 1
	ok(all, "each of the %d authored places is a space, world/<id>, a child of the open world, with its name" % places.size())
	var dungeons := places.filter(func(l): return l["type"] == "dungeon").size()
	ok(dungeons == 6 and interiors == dungeons and areas == places.size() - dungeons, "towns and wilds are areas of the open world (%d), dungeons are interiors (%d)" % [areas, interiors])
	ok(GameSpaces.kind("world/hearthmere") == "area" and GameSpaces.kind("world/greenvale") == "area" and GameSpaces.kind("world/goblin_warrens") == "interior", "Hearthmere and Greenvale are walked into; the Goblin Warrens are entered")
	var unique := {}
	for id in ids:
		unique[id] = true
	ok(unique.size() == ids.size(), "every id is its own (%d spaces)" % ids.size())
	ok(GameSpaces.of_place("atlantis") == "" and GameSpaces.space("world/atlantis").is_empty() and not GameSpaces.has("nowhere"), "a place the game does not have has no space")
	ok(GameSpaces.chain("world/goblin_warrens") == ["world/goblin_warrens", "world"], "a space's chain runs up to the open world")
	var want := []
	for l in places:
		want.append("world/" + str(l["id"]))
	want.append("world/underworld/underground")
	for r in GameRealms.ids():
		if GameSpaces.of_realm(str(r)) != "" and not GameSpaces.space(GameSpaces.of_realm(str(r)))["door"].is_empty():
			want.append("realm/" + str(r))
	want.sort()
	var got := GameSpaces.children("world")
	got.sort()
	ok(got == want, "the open world's children are the places, the underworld's first band and the realms with a gate (%d)" % want.size())


func test_interiors() -> void:
	var count := 0
	var on_ground := true
	for l in GameData.world["locations"]:
		var town := GameSpaces.of_place(str(l["id"]))
		var a := GameWorldGen.anchor(str(l["id"]))
		for service in l.get("services", []):
			var id := GameSpaces.of_service(str(l["id"]), str(service))
			var s := GameSpaces.space(id)
			count += 1
			if s.is_empty() or s["kind"] != "interior" or s["parent"] != town or s["door"]["space"] != town:
				on_ground = false
			elif not GameWorldGen.in_anchor_ground(int(s["door"]["x"]), int(s["door"]["z"])) or (int(s["door"]["x"]) == int(a["x"]) and int(s["door"]["z"]) == int(a["z"])):
				on_ground = false
	ok(count == 21 and on_ground, "each town's services are interiors of the town (%d), each with a door on the town's cleared ground" % count)
	ok(GameSpaces.space("world/hearthmere/forge")["name"] == "Forge" and GameSpaces.space("world/kingshold/black_market")["name"] == "Black market", "they are named for what they are")
	ok(GameSpaces.of_service("hearthmere", "black_market") == "" and GameSpaces.of_service("greenvale", "forge") == "", "a town has only its own services, and the wilds none")
	var house := GameSpaces.space(GameSpaces.house())
	ok(GameSpaces.house() == "world/hearthmere/house" and house["kind"] == "interior" and house["parent"] == "world/hearthmere" and house["place"] == "hearthmere", "the family house is an interior of the home town")
	ok(GameWorldGen.in_anchor_ground(int(house["door"]["x"]), int(house["door"]["z"])), "with its door on the town's ground")
	var doors := {}
	for id in GameSpaces.children("world/hearthmere"):
		var t := GameSpaces.map_tile(str(id))
		doors["%d,%d" % [t.x, t.y]] = true
	ok(doors.size() == GameSpaces.children("world/hearthmere").size() and GameSpaces.children("world/hearthmere").size() == 6, "Hearthmere's five services and the house have six different doors")
	ok(GameSpaces.chain("world/hearthmere/forge") == ["world/hearthmere/forge", "world/hearthmere", "world"], "the forge is in the town, which is in the world")
	ok(GameSpaces.place_of("world/hearthmere/forge") == "hearthmere" and GameSpaces.place_of("world") == "", "an interior belongs to its town's place")


func test_map() -> void:
	var all := true
	for l in GameData.world["locations"]:
		var a := GameWorldGen.anchor(str(l["id"]))
		if GameSpaces.map_tile(GameSpaces.of_place(str(l["id"]))) != Vector2i(int(a["x"]), int(a["z"])):
			all = false
	ok(all, "every place is on the map at its anchor tile in the generated world")
	var h := GameSpaces.map_tile("world/hearthmere")
	ok(GameSpaces.map_tile("world/hearthmere/forge") == h + Vector2i(-4, -2), "the forge's door is 4 west and 2 north of Hearthmere's middle")
	ok(GameSpaces.map_tile("world") == Vector2i(-1, -1) and GameSpaces.map_tile("nowhere") == Vector2i(-1, -1), "the open world itself, and a space that does not exist, are nowhere on it")
	ok(GameSpaces.at_tile(h.x, h.y) == "world/hearthmere" and GameSpaces.at_tile(h.x + 5, h.y - 5) == "world/hearthmere", "a tile on a town's ground is in the town")
	ok(GameSpaces.at_tile(h.x + 30, h.y) == "world", "one well outside it is in the open world")
	var g := GameSpaces.map_tile("world/greenvale")
	ok(GameSpaces.at_tile(g.x, g.y) == "world", "the wilds have no bounded ground: a tile there is the open world's")
	ok(GameSpaces.tiles_between(Vector2i(0, 0), Vector2i(3, 4)) == 5, "tiles are counted as the crow flies")


func test_where() -> void:
	var d := GameDynasty.new_game(5, "Tess", "warrior", "faetouched", "human")
	var w := GameSpaces.where(d)
	var h := GameSpaces.map_tile("world/hearthmere")
	ok(w == {"space": "world/hearthmere", "place": "hearthmere", "x": h.x, "z": h.y}, "a new heir is in Hearthmere, at its tile: %s" % str(w))
	d.world.visit("goblin_warrens")
	var w2 := GameSpaces.where(d)
	ok(w2["space"] == "world/goblin_warrens" and w2["place"] == "goblin_warrens" and Vector2i(w2["x"], w2["z"]) == GameSpaces.map_tile("world/goblin_warrens"), "one who has travelled is in the place they went to")
	var all := true
	for l in GameData.world["locations"]:
		d.world.visit(str(l["id"]))
		if GameSpaces.where(d)["space"] != "world/" + str(l["id"]):
			all = false
	ok(all, "wherever the text game says the heir is, there is a space for it")


func _steps(route: Array) -> Array:
	return route.map(func(s): return "%s %s" % [s["step"], s["space"]])


func test_routes() -> void:
	ok(GameSpaces.route("world/hearthmere", "world/hearthmere").is_empty() and GameSpaces.route("world/hearthmere", "nowhere").is_empty(), "there is no way from a space to itself or to one that does not exist")
	var r := GameSpaces.route("world/hearthmere/forge", "world/hearthmere/tavern")
	ok(_steps(r) == ["leave world/hearthmere/forge", "walk world/hearthmere", "enter world/hearthmere/tavern"], "forge to tavern: leave one, walk across the town, enter the other (%s)" % str(_steps(r)))
	var forge := GameSpaces.map_tile("world/hearthmere/forge")
	var tavern := GameSpaces.map_tile("world/hearthmere/tavern")
	ok(r[1]["from"] == [forge.x, forge.y] and r[1]["to"] == [tavern.x, tavern.y] and r[1]["tiles"] == GameSpaces.tiles_between(forge, tavern) and r[1]["tiles"] > 0, "the walk is from door to door (%d tiles)" % r[1]["tiles"])
	var far := GameSpaces.route("world/hearthmere/house", "world/goblin_warrens")
	ok(_steps(far) == ["leave world/hearthmere/house", "leave world/hearthmere", "walk world", "enter world/goblin_warrens"], "house to the Goblin Warrens: out of the house, out of the town, across the world, into the dungeon (%s)" % str(_steps(far)))
	var warrens := GameSpaces.map_tile("world/goblin_warrens")
	ok(far[2]["to"] == [warrens.x, warrens.y] and far[2]["tiles"] > 100, "the walk across the world ends at the dungeon's door (%d tiles)" % far[2]["tiles"])
	var into := GameSpaces.route("world/greenvale", "world/kingshold/temple")
	ok(_steps(into) == ["leave world/greenvale", "walk world", "enter world/kingshold", "walk world/kingshold", "enter world/kingshold/temple"], "from the wilds into a town's temple: to the town, into it, to the temple's door, in (%s)" % str(_steps(into)))
	var back := GameSpaces.route("world/kingshold/temple", "world/greenvale")
	ok(_steps(back).front() == "leave world/kingshold/temple" and _steps(back).back() == "enter world/greenvale", "and the way back starts by leaving and ends by entering")
	var roads := 0
	var good := true
	for l in GameData.world["locations"]:
		for link in l.get("links", []):
			var w := GameSpaces.road_walk(str(l["id"]), str(link["to"]))
			roads += 1
			if w.is_empty() or w["space"] != "world" or int(w["tiles"]) <= 0 or not is_equal_approx(float(w["years"]), float(link["years"])):
				good = false
	ok(roads > 30 and good, "every one of the text game's %d roads is a walk on the open world between two places' tiles, with the years it takes" % roads)
	ok(GameSpaces.road_walk("hearthmere", "the_rift").is_empty(), "where there is no road there is no walk")
	var hg := GameSpaces.road_walk("hearthmere", "greenvale")
	ok(hg["tiles"] == GameSpaces.tiles_between(GameSpaces.map_tile("world/hearthmere"), GameSpaces.map_tile("world/greenvale")), "Hearthmere to Greenvale is %d tiles" % hg["tiles"])


func test_agreement() -> void:
	ok(GameSpaces.root_id() == GameWorldGen.MINE_SITE, "the open world's id is the one the generated world and the mine already use")
	var d := GameDynasty.new_game(5, "Tess", "warrior", "faetouched", "human")
	var base := GameBuild.base()
	ok(GameSpaces.map_tile("world/hearthmere") == Vector2i(int(base["x"]), int(base["z"])), "the home town's tile is the middle of the family's building ground")
	var house := GameSpaces.map_tile(GameSpaces.house())
	ok(GameBuild.in_claim(d, house.x, house.y), "and the family house's door is on it")
	for id in ["world/hearthmere", "world/ironford", "world/kingshold", "world/brinehaven"]:
		var t := GameSpaces.map_tile(id)
		var tile := GameWorldGen.tile(d, t.x, t.y)
		ok(not tile["water"] and tile["place"] == GameSpaces.place_of(id), "%s's tile is dry land the generated world calls by the same name" % id)


func test_pure() -> void:
	var d := GameDynasty.new_game(5, "Tess", "warrior", "faetouched", "human")
	var rng_before := d.rng.state
	var save_before := JSON.stringify(d.to_dict())
	GameSpaces.where(d)
	GameSpaces.route("world/hearthmere/house", "world/the_rift")
	GameSpaces.ids()
	ok(d.rng.state == rng_before and JSON.stringify(d.to_dict()) == save_before, "asking about spaces draws no dice and saves nothing")
	var first := JSON.stringify(GameSpaces.ids().map(func(id): return GameSpaces.space(id)))
	_reset()
	ok(JSON.stringify(GameSpaces.ids().map(func(id): return GameSpaces.space(id))) == first, "built again, the spaces are the same")
