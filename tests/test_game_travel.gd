## Travel and the pin (core/game/game_travel.gd, data/world/worldmap.json): the towns and cities are named on the world map from the start,
## the fare of a booked coach (tiles, rate, minimum, the shop price multiplier), when booking is refused, where the heir is set down (inside
## the gate nearest where they set out, on walkable ground, the party beside them), the gold and the world clock it takes and that it draws
## no dice, the map pin (set, cleared on arrival or by unpinning, saved only when set and loaded clean from old and corrupt saves), the
## minimap's bearing to it, and walking there in legs (a route starts; a gate shut for the night stops the walk outside the wall).
## Run: godot --headless --path . -s res://tests/test_game_travel.gd
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
	test_towns_named()
	test_fare()
	test_refusals()
	test_arrival_tiles()
	test_book()
	test_pin()
	test_pin_save()
	test_bearing()
	test_compass()
	test_walk()
	test_walk_shut_gate()
	test_pin_clears()
	print("travel tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh(seed_value: int = 7) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 5000
	return d


## A sandbox with the heir standing on a town's ground, day.
func _at(place: String, d: GameDynasty = null) -> GameSandbox:
	d = _fresh() if d == null else d
	d.world_seconds = _time(d, false)
	var s := GameSandbox.start(d)
	s.creatures.clear()
	var a := GameTravel.anchor_tile(place)
	s.heir = a
	return s


func _time(d: GameDynasty, night: bool) -> float:
	var span := float(GameDay.setting("day_seconds"))
	var keep := d.world_seconds
	for i in 48:
		d.world_seconds = span * float(i) / 48.0
		if GameDay.is_night(d) == night:
			var found := d.world_seconds
			d.world_seconds = keep
			return found
	d.world_seconds = keep
	return keep


func test_data() -> void:
	ok(GameWorldMap.validate().is_empty(), "the shipped data passes: %s" % str(GameWorldMap.validate()))
	var t: Dictionary = GameWorldMap.data()["travel"]
	var keep: Variant = t["gold_per_tile"]
	t["gold_per_tile"] = 0.0
	ok(not GameWorldMap.validate().is_empty(), "a free rate is caught")
	t["gold_per_tile"] = keep
	keep = t["leg_min_gain"]
	t["leg_min_gain"] = 500
	ok(not GameWorldMap.validate().is_empty(), "a leg that must gain more than it is long is caught")
	t["leg_min_gain"] = keep
	var s: Dictionary = GameWorldMap.data()["settings"]
	keep = s["pin_clear_tiles"]
	s["pin_clear_tiles"] = 10
	ok(not GameWorldMap.validate().is_empty(), "a pin that comes off before the gate is caught")
	s["pin_clear_tiles"] = keep
	var cities: Variant = GameWorldMap.data()["cities"]
	GameWorldMap.data()["cities"] = ["the_wilds_of_nowhere"]
	ok(not GameWorldMap.validate().is_empty(), "a city that is no town is caught")
	GameWorldMap.data()["cities"] = cities
	var line: Variant = GameWorldMap.data()["text"]["booked"]
	GameWorldMap.data()["text"]["booked"] = ""
	ok(not GameWorldMap.validate().is_empty(), "missing text is caught")
	GameWorldMap.data()["text"]["booked"] = line
	ok(GameWorldMap.validate().is_empty(), "and mending the data clears it")


func test_towns_named() -> void:
	var d := _fresh()
	ok(GameTravel.towns().size() == 4, "four towns: %s" % str(GameTravel.towns()))
	ok(GameTravel.is_city("kingshold") and not GameTravel.is_city("hearthmere") and not GameTravel.is_town("greenvale"), "Kingshold is the city, the wilds are no town")
	var named := 0
	var wild_named := 0
	for m in GameWorldMap.markers(d):
		if str(m["kind"]) in ["town", "city"]:
			if str(m["name"]) == GameTravel.name_of(str(m["id"])) and bool(m["known"]):
				named += 1
		elif str(m["name"]) != GameWorldMap.text("unknown") and not bool(m["visited"]):
			wild_named += 1
	ok(named == 4, "all four towns are named before any is visited")
	ok("ironford" not in d.world.visited and str((GameWorldMap.markers(d).filter(func(m): return m["id"] == "ironford"))[0]["name"]) == "Ironford", "Ironford, unvisited, is named")
	ok(wild_named == 0, "the wilds and dungeons stay unnamed until visited")
	ok(GameWorldMap.town_markers(d).size() == 4, "four selectable markers")
	var k: Dictionary = GameWorldMap.markers(d).filter(func(m): return m["id"] == "kingshold")[0]
	ok(str(k["kind"]) == "city", "Kingshold's marker is a city's")
	var near := GameWorldMap.town_near_cell(d, Vector2(k["cell"]) + Vector2(0.5, 0.5), 1.0)
	ok(str(near.get("id", "")) == "kingshold", "the marker nearest a cell is found")
	ok(GameWorldMap.town_near_cell(d, Vector2(0.5, 0.5), 2.0).is_empty(), "and a corner of the map holds none")
	var card := GameTravel.card(d, Vector2i(10, 10), "kingshold")
	ok(card["name"] == "Kingshold" and int(card["tiles"]) > 0 and str(card["dir"]) != "" and int(card["fare"]) >= 15, "a card gives name, tiles, direction and fare: %s" % str(card))
	ok(GameTravel.card(d, Vector2i(10, 10), "greenvale").is_empty(), "the wilds have no card")


func test_fare() -> void:
	var d := _fresh()
	var min_fee := int(GameTravel.setting("min_fee"))
	var rate := float(GameTravel.setting("gold_per_tile"))
	var home := GameTravel.anchor_tile("hearthmere")
	var tiles := GameTravel.tiles(home, GameTravel.anchor_tile("ironford"))
	var mult := GameItems.price_mult(d)
	var want := maxi(1, int(round(float(maxi(min_fee, int(ceil(float(tiles) * rate)))) * mult)))
	ok(GameTravel.fare(d, home, "ironford") == want, "the fare is the tiles times the rate, times the price multiplier (%d)" % want)
	ok(GameTravel.fare(d, GameTravel.anchor_tile("ironford") + Vector2i(1, 0), "ironford") >= maxi(1, int(round(float(min_fee) * mult))), "never under the minimum")
	ok(GameTravel.fare(d, GameTravel.anchor_tile("ironford") + Vector2i(1, 0), "ironford") == maxi(1, int(round(float(min_fee) * mult))), "right beside a town it is the minimum")
	var far := GameTravel.fare(d, home, "brinehaven")
	ok(far > GameTravel.fare(d, home, "ironford"), "a farther town costs more (%d over %d)" % [far, GameTravel.fare(d, home, "ironford")])
	var before := GameTravel.fare(d, home, "kingshold")
	d.echoes.append({"kind": "infamy", "key": "x", "text": "x", "strength": 0.5, "gen": 1})
	ok(GameItems.price_mult(d) > mult and GameTravel.fare(d, home, "kingshold") > before, "the shop price multiplier counts (an infamous house pays more)")
	d.echoes.clear()
	ok(GameTravel.fare(d, home, "kingshold") == before, "and goes again with it")


func test_refusals() -> void:
	var s := _at("hearthmere")
	var d := s.d
	ok(not s.book_travel("greenvale")["ok"] and GameTravel.refusal(s, "greenvale") == GameWorldMap.text("book_no_town"), "a place that is no town is refused")
	ok(not s.book_travel("nowhere")["ok"], "an unknown place is refused")
	ok(not s.book_travel("")["ok"], "and no place")
	ok(GameTravel.refusal(s, "hearthmere").contains("already"), "the town the heir is in is refused")
	# not in a town
	var wild := _at("hearthmere")
	wild.heir = Vector2i(250, 300)
	if GameTravel.town_at(wild.heir.x, wild.heir.y) != "":
		wild.heir = Vector2i(40, 40)
	ok(GameTravel.town_at(wild.heir.x, wild.heir.y) == "", "(a tile that is nobody's ground)")
	var r := wild.book_travel("ironford")
	ok(not r["ok"] and str(r["text"]).contains("town's ground"), "out in the open it is refused: %s" % r["text"])
	# indoors
	var t := _at("hearthmere")
	t.heir = _door_of("hearthmere", "forge")
	t.enter()
	ok(t.space != "world", "(the heir is in the forge)")
	ok(not t.book_travel("ironford")["ok"] and GameTravel.refusal(t, "ironford") == GameWorldMap.text("book_indoors", {"heir": t.d.heir.name}), "indoors it is refused")
	# upstairs
	var u := _at("hearthmere")
	u.heir_y = GameBuild.SURFACE - 2
	ok(GameTravel.refusal(u, "ironford") != "" and not u.book_travel("ironford")["ok"], "upstairs it is refused")
	# in a fight
	var f := _at("hearthmere")
	f.d.battle = GameBattle.new(f.d.heir, [], f.d.rng)
	ok(GameTravel.refusal(f, "ironford") == GameWorldMap.text("book_fight", {"heir": f.d.heir.name}), "in a fight it is refused")
	f.d.battle = null
	# an answer waiting
	f.d.pending_event = {"id": "x"}
	ok(GameTravel.refusal(f, "ironford") == GameWorldMap.text("book_busy"), "with an event waiting for an answer it is refused")
	f.d.pending_event = {}
	# poor
	d.heir.gold = GameTravel.fare(d, s.heir, "ironford") - 1
	var poor := s.book_travel("ironford")
	ok(not poor["ok"] and str(poor["text"]).contains("gold") and d.heir.gold == GameTravel.fare(d, s.heir, "ironford") - 1, "without the fare it is refused and nothing is taken: %s" % poor["text"])
	d.heir.gold = GameTravel.fare(d, s.heir, "ironford")
	ok(GameTravel.refusal(s, "ironford") == "", "with exactly the fare it is allowed")


func _door_of(place: String, service: String) -> Vector2i:
	var door: Dictionary = GameSpaces.space("world/%s/%s" % [place, service])["door"]
	return Vector2i(int(door["x"]), int(door["z"]))


func test_arrival_tiles() -> void:
	var d := _fresh()
	var ground := GamePath.world_ground(d)
	var mover := {"water": false, "ignore_blocks": false}
	var bad := 0
	var seen := 0
	for place in GameTravel.towns():
		var a := GameTravel.anchor_tile(place)
		for from_name in GameTravel.towns():
			if from_name == place:
				continue
			var t := GameTravel.arrival_tile(GameTravel.anchor_tile(from_name), place)
			seen += 1
			var inside := Vector2(t - a).length() < GameWalls.radius(place) - 1.0
			if not inside or not GamePath.passable(ground, Vector3i(t.x, -1, t.y), mover) or GameWalls.blocks(t.x, t.y) or GameTown.blocks(t.x, t.y):
				bad += 1
				print("  bad arrival at %s from %s: %s" % [place, from_name, str(t)])
			if GameTravel.town_at(t.x, t.y) != place:
				bad += 1
				print("  arrival not on the town's ground: ", place, t)
			# nobody is walled in: a walker can get from the arrival tile to the anchor
			var f := GamePath.find(ground, Vector3i(t.x, -1, t.y), Vector3i(a.x, -1, a.y), "walker", 4000)
			if not f["found"]:
				bad += 1
				print("  walled in at ", place, t)
	ok(seen == 12 and bad == 0, "12 arrivals, each inside the wall, walkable, on the town's ground and not walled in (%d bad)" % bad)
	# the gate nearest the origin: Brinehaven is east of Hearthmere, so the way in is by its west side
	var t2 := GameTravel.arrival_tile(GameTravel.anchor_tile("hearthmere"), "brinehaven")
	ok(t2.x < GameTravel.anchor_tile("brinehaven").x, "coming from the west, the heir is set down inside the west of Brinehaven")
	# at night the same
	d.world_seconds = _time(d, true)
	ok(GameTravel.arrival_tile(GameTravel.anchor_tile("hearthmere"), "brinehaven") == t2, "and by night the same tile, just inside the (shut) gate")


func test_book() -> void:
	var s := _at("hearthmere")
	var d := s.d
	s.d.party.members.append({"id": "bren_cask", "name": GameParty.def("bren_cask")["name"], "hp": 1, "mp": 0, "level": 10, "gen": 1, "due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
	d.party.history["bren_cask"] = {"name": "Bren Cask", "status": "serving", "gen": 1, "first_gen": 1, "battles": 0, "fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	s.companions = GameCompanions.agents_for(d, float(s.heir.x) + 0.5, float(s.heir.y) + 0.5)
	s.creatures.append(GameBehaviour.new_agent(900, "wolf", float(s.heir.x) + 5.5, float(s.heir.y) + 0.5))
	var gold := d.heir.gold
	var fare := GameTravel.fare(d, s.heir, "ironford")
	var secs := GameTravel.seconds(s.heir, "ironford")
	var rng_state := d.rng.state
	var seconds_before := d.world_seconds
	var carry_before := d.clock_carry
	var year_before := d.world.year
	var logged := s.log.size()
	s.route = [Vector2i(1, 1)]
	var r := s.book_travel("ironford")
	ok(r["ok"], "booking from Hearthmere to Ironford works: %s" % r["text"])
	ok(d.heir.gold == gold - fare, "the fare comes out of the heir's gold (%d)" % fare)
	ok(d.rng.state == rng_state, "no dice are drawn")
	ok(absf((d.world_seconds - seconds_before) - secs) < 0.001, "the world clock runs %.1f seconds" % secs)
	ok(d.world.year > year_before or d.clock_carry != carry_before or secs < 1.0, "and ages and weather move on with it")
	ok(GameTravel.town_at(s.heir.x, s.heir.y) == "ironford" and d.world.location == "ironford", "the heir stands on Ironford's ground and it is the family's place")
	ok("ironford" in d.world.visited, "visited")
	ok(s.route.is_empty() and s.walk_goal == GameTravel.NONE, "any route is dropped")
	ok(s.companions.size() == 1 and Vector2(float(s.companions[0]["x"]), float(s.companions[0]["z"])).distance_to(s.heir_point()) < 3.0, "the companion stands beside the heir")
	var far := true
	for a in s.creatures:
		if Vector2(float(a["x"]), float(a["z"])).distance_to(Vector2(1000.0, 1000.0)) < 1.0 or str(a["id"]) == "wolf" and int(a["uid"]) == 900:
			far = false
	ok(far, "the creature of the old place is left behind")
	ok(s.log.size() > logged + 1 and str(s.log[s.log.size() - 1]["text"]).contains("Ironford") and str(s.log[s.log.size() - 1]["text"]).contains(str(fare)), "the log says so: %s" % str(s.log[s.log.size() - 1]["text"]))
	ok(str(s.log[logged]["text"]).contains("Ironford"), "with the arrival line before it")
	# on, from Ironford to the city by night
	d.world_seconds = _time(d, true)
	ok(GameWalls.shut_now(d), "(night: the gates are shut)")
	var r2 := s.book_travel("kingshold")
	ok(r2["ok"] and GameTravel.town_at(s.heir.x, s.heir.y) == "kingshold", "booking works by night, and the heir is set down inside the wall")
	ok(Vector2(s.heir - GameTravel.anchor_tile("kingshold")).length() < GameWalls.radius("kingshold"), "inside it")
	ok(s.can_step(0, 1)["ok"] or s.can_step(0, -1)["ok"] or s.can_step(1, 0)["ok"] or s.can_step(-1, 0)["ok"], "and can step on from there")


func test_pin() -> void:
	var d := _fresh()
	ok(d.map_pin.is_empty() and not GameTravel.has_pin(d), "no pin to begin with")
	ok(GameTravel.set_pin(d, "kingshold") and GameTravel.pin_place(d) == "kingshold" and GameTravel.pin_name(d) == "Kingshold", "a town can be pinned")
	ok(GameTravel.pin_tile(d) == GameTravel.anchor_tile("kingshold"), "the pin is on its anchor")
	ok(not GameTravel.set_pin(d, "nowhere") and GameTravel.pin_place(d) == "kingshold", "an unknown place leaves the pin as it was")
	var line := GameTravel.pin_line(d, GameTravel.anchor_tile("hearthmere"))
	ok(line.begins_with("Pin: Kingshold, ") and line.contains("tiles"), "the line says where: %s" % line)
	ok(GameTravel.pin_line(d, GameTravel.anchor_tile("kingshold")).contains("here"), "and 'here' on top of it")
	GameTravel.clear_pin(d)
	ok(d.map_pin.is_empty() and GameTravel.pin_line(d, Vector2i.ZERO) == "", "unpinning clears it, and the line is gone")
	ok(GameTravel.set_pin_point(d, 100, 200, "the old mill") and GameTravel.pin_name(d) == "the old mill" and GameTravel.pin_tile(d) == Vector2i(100, 200), "a bare point can be pinned with a name")
	ok(not GameTravel.set_pin_point(d, -5, 20, "x") and GameTravel.pin_tile(d) == Vector2i(100, 200), "a point off the world is refused")
	var rng_state := d.rng.state
	GameTravel.set_pin(d, "ironford")
	ok(d.rng.state == rng_state, "pinning draws no dice")


func test_pin_save() -> void:
	var d := _fresh()
	ok(not d.to_dict().has("map_pin"), "no pin: nothing saved (old saves and golden digests are as they were)")
	GameTravel.set_pin(d, "brinehaven")
	var saved := d.to_dict()
	ok(saved.has("map_pin"), "a pin is saved")
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(saved)))
	ok(back.map_pin == {"place": "brinehaven"}, "and loads back: %s" % str(back.map_pin))
	GameTravel.set_pin_point(d, 10, 12, "the well")
	back = GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(back.map_pin == {"x": 10, "z": 12, "name": "the well"}, "a point's pin loads back: %s" % str(back.map_pin))
	for bad in [{"place": "nowhere"}, {"place": 7}, {"x": "a", "z": 1}, {"x": 99999, "z": 1}, {"x": 1.0e30, "z": 4}, "kingshold", 5, [1, 2], {}, {"foo": 1}, null, {"x": 5}]:
		var s := d.to_dict()
		s["map_pin"] = bad
		var g := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(s)) if bad != null else s)
		ok(g != null and g.map_pin.is_empty(), "a corrupt pin %s is ignored" % str(bad))
	var old := d.to_dict()
	old.erase("map_pin")
	ok(GameDynasty.from_dict(old).map_pin.is_empty(), "an old save with no pin loads with none")
	var long := {"x": 10, "z": 12, "name": "n".repeat(300)}
	ok(GameTravel.clean_pin(long)["name"].length() == int(GameWorldMap.setting("pin_name_max")), "a long name is cut")


func test_bearing() -> void:
	var d := _fresh()
	ok(GameMiniMap.pin_bearing(d, Vector2i(100, 100)).is_empty(), "no pin, no bearing")
	var r := int(GameSandbox.data()["view"]["minimap_radius"])
	GameTravel.set_pin_point(d, 100 + 5, 100 - 3, "near")
	var b := GameMiniMap.pin_bearing(d, Vector2i(100, 100))
	ok(bool(b["inside"]) and b["offset"] == Vector2i(5, -3) and str(b["place"]) == "near", "a pin close by is inside the picture: %s" % str(b))
	ok(int(b["distance"]) == 6 and absf(float(b["angle"]) - atan2(-3.0, 5.0)) < 0.0001, "with its distance and angle")
	GameTravel.set_pin_point(d, 100 + r, 100, "edge")
	ok(bool(GameMiniMap.pin_bearing(d, Vector2i(100, 100))["inside"]), "on the radius it is still inside")
	GameTravel.set_pin_point(d, 100 + r + 1, 100, "out")
	var o := GameMiniMap.pin_bearing(d, Vector2i(100, 100))
	ok(not bool(o["inside"]) and absf(float(o["angle"])) < 0.0001 and str(o["dir"]) == "E", "just past it, it is outside, due east")
	for case in [[0, 100, "S", PI / 2.0], [-100, 0, "W", PI], [0, -100, "N", -PI / 2.0], [100, 100, "SE", PI / 4.0], [-100, -100, "NW", -3.0 * PI / 4.0], [100, -100, "NE", -PI / 4.0], [-100, 100, "SW", 3.0 * PI / 4.0]]:
		GameTravel.set_pin_point(d, 300 + int(case[0]), 300 + int(case[1]), "far")
		var f := GameMiniMap.pin_bearing(d, Vector2i(300, 300))
		ok(not bool(f["inside"]) and str(f["dir"]) == str(case[2]) and absf(float(f["angle"]) - float(case[3])) < 0.0001, "pin %s: angle %.3f, %s" % [str(case[2]), float(f["angle"]), str(f["dir"])])
	ok(int(GameMiniMap.pin_bearing(d, Vector2i(300, 300), 500)["distance"]) == 141 and bool(GameMiniMap.pin_bearing(d, Vector2i(300, 300), 500)["inside"]), "a wider radius can be asked for")
	var rng_state := d.rng.state
	GameMiniMap.pin_bearing(d, Vector2i(1, 2))
	ok(d.rng.state == rng_state, "no dice")


func test_compass() -> void:
	var o := Vector2i(50, 50)
	ok(GameTravel.compass(o, Vector2i(80, 50)) == "E" and GameTravel.compass(o, Vector2i(50, 80)) == "S" and GameTravel.compass(o, Vector2i(20, 50)) == "W" and GameTravel.compass(o, Vector2i(50, 20)) == "N", "the four points")
	ok(GameTravel.compass(o, Vector2i(80, 80)) == "SE" and GameTravel.compass(o, Vector2i(20, 20)) == "NW" and GameTravel.compass(o, Vector2i(80, 20)) == "NE" and GameTravel.compass(o, Vector2i(20, 80)) == "SW", "the four between")
	ok(GameTravel.compass(o, o) == "E", "no distance falls back to the first point")


func test_walk() -> void:
	var s := _at("hearthmere")
	s.heir = GameTravel.anchor_tile("hearthmere") + Vector2i(60, 0)   # outside the wall
	var d := s.d
	var rng_state := d.rng.state
	var start := Time.get_ticks_msec()
	var r := s.walk_there("ironford")
	ok(r["ok"], "walking there starts: %s" % r["text"])
	ok(GameTravel.pin_place(d) == "ironford", "and pins the town")
	ok(not s.route.is_empty() and s.walk_goal == GameTravel.anchor_tile("ironford"), "with a route and a goal")
	ok(s.route.size() <= int(GameSandbox.setting("route_nodes")), "the route is one leg")
	# walk it all
	var steps := 0
	var legs := 1
	var worst := 0
	while s.walk_goal != GameTravel.NONE and steps < 6000:
		var t0 := Time.get_ticks_usec()
		var was := s.route.size()
		if not s.walk_one() and s.route.is_empty():
			break
		steps += 1
		if was == 1 and s.route.size() > 0:
			legs += 1
			worst = maxi(worst, Time.get_ticks_usec() - t0)
	ok(s.walk_goal == GameTravel.NONE, "the walk ends (after %d steps, %d legs)" % [steps, legs])
	ok(Vector2(s.heir - GameTravel.anchor_tile("ironford")).length() <= 2.0, "at Ironford's anchor: %s" % str(s.heir))
	ok(d.world.location == "ironford", "the town is the family's place")
	ok(d.map_pin.is_empty(), "and the pin has come off")
	ok(d.rng.state == rng_state, "no dice drawn on the way")
	ok(str(s.log[s.log.size() - 1]["text"]).length() > 0, "the log says it (%s)" % str(s.log[s.log.size() - 1]["text"]))
	print("  (walk took %d ms, the slowest leg %d ms)" % [Time.get_ticks_msec() - start, worst / 1000])
	# a walk is cancelled by a route of its own
	var s2 := _at("hearthmere")
	s2.heir = GameTravel.anchor_tile("hearthmere") + Vector2i(60, 0)
	s2.walk_there("brinehaven")
	ok(s2.walk_goal != GameTravel.NONE, "(a walk on)")
	s2.cancel_walk()
	ok(s2.route.is_empty() and s2.walk_goal == GameTravel.NONE, "cancelling drops the route and the goal")
	ok(GameTravel.pin_place(s2.d) == "brinehaven", "the pin stays")
	s2.walk_there("brinehaven")
	s2.set_route(s2.heir + Vector2i(3, 0))
	ok(s2.walk_goal == GameTravel.NONE, "a route of the player's own ends the walk")
	# indoors: pinned only
	var s3 := _at("hearthmere")
	s3.heir = _door_of("hearthmere", "forge")
	s3.enter()
	var r3 := s3.walk_there("kingshold")
	ok(not r3["ok"] and GameTravel.pin_place(s3.d) == "kingshold" and s3.route.is_empty(), "indoors the town is pinned and no walk begins: %s" % r3["text"])
	ok(not s3.walk_there("greenvale")["ok"] and GameTravel.pin_place(s3.d) == "kingshold", "a place that is no town is not pinned")


func test_walk_shut_gate() -> void:
	var s := _at("hearthmere")
	var d := s.d
	d.world_seconds = _time(d, true)
	ok(GameWalls.shut_now(d), "(night)")
	s.heir = GameTravel.anchor_tile("hearthmere") + Vector2i(62, 0)
	var r := s.walk_there("hearthmere")
	var steps := 0
	while s.walk_goal != GameTravel.NONE and steps < 3000:
		if not s.walk_one() and s.route.is_empty():
			break
		steps += 1
	ok(s.walk_goal == GameTravel.NONE, "the walk ends")
	var outside := Vector2(s.heir - GameTravel.anchor_tile("hearthmere")).length()
	ok(outside > GameWalls.radius("hearthmere"), "outside the wall (%.1f tiles from the anchor), at the shut gate" % outside)
	var shut_line := GameWorldMap.text("walk_shut", {"heir": d.heir.name, "name": "Hearthmere"})
	var said := false
	for e in s.log:
		if str(e["text"]) == shut_line:
			said = true
	ok(said, "the log says the gates are shut: %s" % str(s.log[s.log.size() - 1]["text"]))
	var gate := GameWalls.gate_near(float(s.heir.x) + 0.5, float(s.heir.y) + 0.5, 3.0)
	ok(not gate.is_empty(), "the heir stands at a gate")
	# by day it opens
	d.world_seconds = _time(d, false)
	ok(not GameWalls.shut_now(d), "(day)")
	var r2 := s.walk_there("hearthmere")
	steps = 0
	while s.walk_goal != GameTravel.NONE and steps < 3000:
		if not s.walk_one() and s.route.is_empty():
			break
		steps += 1
	ok(Vector2(s.heir - GameTravel.anchor_tile("hearthmere")).length() <= 2.0, "by day the walk goes through the gate to the anchor: %s" % str(s.heir))


func test_pin_clears() -> void:
	var s := _at("hearthmere")
	var d := s.d
	GameTravel.set_pin(d, "hearthmere")
	s.heir = GameTravel.anchor_tile("hearthmere") + Vector2i(int(GameWorldMap.setting("pin_clear_tiles")) + 5, 0)
	s.move(-1, 0)
	ok(not d.map_pin.is_empty(), "a step that is still far from the pin leaves it")
	s.heir = GameTravel.anchor_tile("hearthmere") + Vector2i(int(GameWorldMap.setting("pin_clear_tiles")), 0)
	s.heir = s.heir + Vector2i(1, 0)
	var moved := s.move(-1, 0)
	ok(moved["ok"] and d.map_pin.is_empty(), "coming within pin_clear_tiles of its anchor clears the pin")
	ok(str(s.log[s.log.size() - 1]["text"]).contains("Hearthmere"), "and says so")
	GameTravel.set_pin_point(d, s.heir.x + 8, s.heir.y, "spot")
	s.move(1, 0)
	ok(not d.map_pin.is_empty(), "a point pin is not cleared from 7 tiles")
	for i in 5:
		s.move(1, 0)
	ok(d.map_pin.is_empty(), "but is within a few tiles of it")
