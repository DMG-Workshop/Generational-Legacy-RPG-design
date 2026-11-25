## Smoke pots: using one lights a cloud on the heir's tile (refused indoors, upstairs, in a fight, with none); while it burns nothing
## spawns inside it, the creatures in it give up the chase and are driven out, and a creature outside cannot start a fight with a
## heir inside it; the heir who walks out is exposed again; the cloud saves only while it burns and loads clean (an old save, a bad
## value); the shops stock the pot and the autopilot never meets one.
## Run: godot --headless --path . -s res://tests/test_game_smoke.gd
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
	test_use()
	test_radius()
	test_spawns()
	test_chasers()
	test_contact()
	test_expiry()
	test_saving()
	test_shops()
	test_autopilot()
	print("smoke tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _sandbox(pots: int = 2) -> GameSandbox:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.level = 20
	for _i in pots:
		d.heir.inventory.append("smoke_pot")
	var s := GameSandbox.start(d)
	s.creatures.clear()
	return s


func _wild_id() -> String:
	return str(GameSpawn.wild()[0]["id"])


func _put(s: GameSandbox, mode: String, at: Vector2) -> Dictionary:
	var a := GameBehaviour.new_agent(900 + s.creatures.size(), _wild_id(), at.x, at.y)
	a["mode"] = mode
	a["level"] = 20
	s.creatures.append(a)
	return a


func test_data() -> void:
	ok(GameSmoke.validate().is_empty(), "the smoke data is valid: %s" % str(GameSmoke.validate()))
	var it := GameItems.item_def("smoke_pot")
	ok(not it.is_empty() and str(it["shop"]) == "" and int(it["stack"]) > 1 and bool(it.get("smoke", false)), "the pot is a stacking item the old shops do not sell")
	ok(GameItems.has_tag("smoke_pot", "smoke") or GameItems.tags_of("smoke_pot").has("tool"), "with tags from its material and its own")
	ok(GameItems.weight_of("smoke_pot") > 0.0, "and a weight")
	ok(GameSmoke.radius() >= 10.0 and float(GameSmoke.data()["seconds"]) >= 60.0, "a cloud of some size that lasts")
	ok(GameSmoke.clock_text(130.0) == "2:10" and GameSmoke.clock_text(5.0) == "0:05", "the timer reads minutes and seconds")


func test_use() -> void:
	var none := _sandbox(0)
	var r: Dictionary = none.use_smoke()
	ok(not bool(r["ok"]) and str(r["text"]).contains("no smoke pot") and none.d.smoke.is_empty(), "with none, nothing happens")
	var s := _sandbox(2)
	s.d.world_seconds = 100.0
	var n0 := GameSmoke.count(s.d.heir)
	r = s.use_smoke()
	ok(bool(r["ok"]) and GameSmoke.count(s.d.heir) == n0 - 1, "using one takes one")
	ok(GameSmoke.active(s.d) and is_equal_approx(float(s.d.smoke["until"]), 100.0 + float(GameSmoke.data()["seconds"])), "and lights a cloud for its seconds of the world clock")
	ok(is_equal_approx(float(s.d.smoke["x"]), s.heir_point().x) and is_equal_approx(float(s.d.smoke["z"]), s.heir_point().y), "on the heir's tile")
	ok(str(s.log[-1]["kind"]) == "smoke" and str(s.log[-1]["text"]).contains("smoke pot"), "and the journal says so")
	var again: Dictionary = s.use_smoke()
	ok(not bool(again["ok"]) and GameSmoke.count(s.d.heir) == n0 - 1, "a second pot is not wasted in thick smoke")
	s.d.world_seconds = 100.0 + float(GameSmoke.data()["seconds"]) * 0.8
	ok(bool(s.use_smoke()["ok"]) and GameSmoke.count(s.d.heir) == n0 - 2, "once it thins, another can be lit")
	# refusals
	var a := _sandbox(1)
	a.space = "tavern"
	ok(not bool(a.use_smoke()["ok"]) and GameSmoke.count(a.d.heir) == 1, "not indoors")
	var b := _sandbox(1)
	b.heir_y = -2
	ok(not bool(b.use_smoke()["ok"]) and GameSmoke.count(b.d.heir) == 1, "not upstairs")
	var c := _sandbox(1)
	c.d.start_encounter([_wild_id()])
	ok(not bool(c.use_smoke()["ok"]) and GameSmoke.count(c.d.heir) == 1, "not in a fight")
	# a pot in a bag counts, and is the one taken
	var d := _sandbox(0)
	d.d.heir.inventory.append("satchel")
	GameBags.normalize(d.d.heir)
	var bag := ""
	for i in d.d.heir.inventory:
		if GameBags.is_bag(str(i)):
			bag = str(i)
	if bag != "":
		d.d.heir.inventory.append("smoke_pot")
		ok(bool(GameBags.put(d.d.heir, "smoke_pot", bag)["ok"]) and GameSmoke.count(d.d.heir) == 1, "a pot in a bag is counted")
		ok(bool(d.use_smoke()["ok"]) and GameSmoke.count(d.d.heir) == 0, "and used from it")
	else:
		ok(false, "the test heir has a bag to put a pot in")


func test_radius() -> void:
	var s := _sandbox()
	s.use_smoke()
	var c := s.heir_point()
	var r := GameSmoke.radius()
	ok(GameSmoke.covers(s.d, c.x, c.y) and GameSmoke.covers(s.d, c.x + r - 0.1, c.y), "the heir and the ground to the radius are in the cloud")
	ok(not GameSmoke.covers(s.d, c.x + r + 0.5, c.y) and not GameSmoke.covers(s.d, c.x, c.y - r - 1.0), "beyond it is not")
	ok(not GameSmoke.covers(_sandbox().d, 5.0, 5.0), "with no cloud nowhere is covered")


func _spawned(s: GameSandbox) -> int:
	s.creatures.clear()
	for k in 14:
		s.refresh()
	return s.creatures.size()


func _crowded_spot(d: GameDynasty) -> Vector2i:
	var a := GameWorldGen.anchor(str(d.world.location))
	for i in 60:
		var t := Vector2i(int(a["x"]) + 60 + i * 9, int(a["z"]) + 40 + i * 5)
		if not GameWorldGen.in_bounds(t.x, t.y):
			continue
		var c := GameSandbox.start(d)
		c.creatures.clear()
		c.heir = t
		if _spawned(c) > 0:
			return t
	return Vector2i(-1, -1)


func test_spawns() -> void:
	var s := _sandbox()
	var spot := _crowded_spot(s.d)
	ok(spot.x >= 0, "there is ground that spawns creatures")
	if spot.x < 0:
		return
	s.heir = spot
	ok(_spawned(s) > 0, "without smoke they spawn")
	s.creatures.clear()
	s.use_smoke()
	ok(_spawned(s) == 0, "inside a cloud nothing spawns (the whole spawn square is within its radius)")
	# the heir walks 30 tiles off: the cloud stays, and the ground out there spawns again
	var far := GameSandbox.start(s.d)
	far.creatures.clear()
	var found_far := false
	for i in 40:
		far.heir = Vector2i(spot.x + 30 + i * 3, spot.y + 5 + i)
		if GameWorldGen.in_bounds(far.heir.x, far.heir.y) and _spawned(far) > 0:
			found_far = true
			for a in far.creatures:
				ok(not GameSmoke.covers(far.d, float(a["x"]), float(a["z"])), "none of what spawns is in the cloud")
			break
	ok(found_far, "away from the cloud the ground spawns again")


func test_chasers() -> void:
	var s := _sandbox()
	s.use_smoke()
	var c := s.heir_point()
	var a := _put(s, "chase", c + Vector2(4.0, 0.0))
	var start := Vector2(float(a["x"]), float(a["z"])).distance_to(c)
	s.step(1)
	var after: Dictionary = s.creatures[0]
	ok(str(after["mode"]) != "chase", "a chaser in the cloud gives up the chase (now %s)" % after["mode"])
	var d1 := Vector2(float(after["x"]), float(after["z"])).distance_to(c)
	ok(d1 > start, "and goes away from the middle")
	for k in 40:
		s.step(1)
		if s.creatures.is_empty():
			break
	var left_cloud := true
	for cr in s.creatures:
		left_cloud = left_cloud and Vector2(float(cr["x"]), float(cr["z"])).distance_to(c) > GameSmoke.radius() * 0.5
	ok(s.d.battle == null and left_cloud, "it is driven well out and never reaches the heir")
	# a flier is driven out too, and a dead creature is left alone
	var s2 := _sandbox()
	s2.use_smoke()
	var dead := _put(s2, "dead", s2.heir_point() + Vector2(2.0, 0.0))
	dead["hp"] = 0.0
	s2.step(1)
	ok(Vector2(float(s2.creatures[0]["x"]), float(s2.creatures[0]["z"])).is_equal_approx(s2.heir_point() + Vector2(2.0, 0.0)), "a dead creature is not driven")
	# no dice: the dynasty's rng does not move
	var s3 := _sandbox()
	s3.use_smoke()
	_put(s3, "chase", s3.heir_point() + Vector2(3.0, 0.0))
	var before := s3.d.rng.state
	s3.step(5)
	ok(s3.d.rng.state == before, "the dynasty's dice are untouched")
	# and without smoke the chaser does reach the heir
	var s4 := _sandbox()
	_put(s4, "chase", s4.heir_point() + Vector2(1.0, 0.0))
	s4.step(1)
	ok(s4.d.battle != null, "without smoke the same creature starts the fight")


func test_contact() -> void:
	# the heir stands at the cloud's edge, a creature just outside it, close to the heir
	var s := _sandbox(0)
	var r := GameSmoke.radius()
	s.d.smoke = {"x": s.heir_point().x - (r - 0.2), "z": s.heir_point().y, "until": s.d.world_seconds + 100.0}
	ok(GameSmoke.covers(s.d, s.heir_point().x, s.heir_point().y), "the heir is inside")
	_put(s, "chase", s.heir_point() + Vector2(0.8, 0.0))
	ok(not GameSmoke.covers(s.d, float(s.creatures[0]["x"]), float(s.creatures[0]["z"])), "the creature is just outside")
	ok(not s._contact() and s.d.battle == null, "it cannot start a fight with a heir inside")
	s.step(3)
	ok(s.d.battle == null, "not by stepping either")
	# the heir walks out of the radius: exposed again
	var e := _sandbox(0)
	e.d.smoke = {"x": e.heir_point().x - (r + 1.0), "z": e.heir_point().y, "until": e.d.world_seconds + 100.0}
	_put(e, "chase", e.heir_point() + Vector2(0.8, 0.0))
	ok(e._contact() and e.d.battle != null, "a heir outside the radius is fought as ever")
	# a creature inside the cloud next to a heir inside is no fight either
	var i := _sandbox()
	i.use_smoke()
	_put(i, "chase", i.heir_point() + Vector2(0.8, 0.0))
	ok(not i._contact(), "nor one inside it")


func test_expiry() -> void:
	var s := _sandbox()
	s.d.world_seconds = 50.0
	s.use_smoke()
	var until := float(s.d.smoke["until"])
	ok(GameSmoke.left(s.d) > 170.0 and GameSmoke.left(s.d) <= float(GameSmoke.data()["seconds"]), "the time left counts down from the whole")
	s.d.world_seconds = until - 1.0
	ok(GameSmoke.active(s.d), "it burns to its last second")
	s.d.world_seconds = until + 1.0
	ok(not GameSmoke.active(s.d) and not GameSmoke.covers(s.d, s.heir_point().x, s.heir_point().y), "then it is out")
	s.step(1)
	ok(s.d.smoke.is_empty() and str(s.log[-1]["text"]).contains("clears"), "and the step puts it away and says so")
	_put(s, "chase", s.heir_point() + Vector2(1.0, 0.0))
	s.step(1)
	ok(s.d.battle != null, "with the smoke gone the creature fights")


func _reload(d: GameDynasty) -> GameDynasty:
	var parsed = JSON.parse_string(JSON.stringify(d.to_save()))
	if typeof(parsed) != TYPE_DICTIONARY or GameSaveVersion.upgrade(parsed) != "":
		return null
	return GameDynasty.from_dict(parsed)


func test_saving() -> void:
	var s := _sandbox()
	ok(not s.d.to_dict().has("smoke") and not s.d.to_save().has("smoke"), "with no cloud nothing is saved for it")
	s.d.world_seconds = 80.0
	s.use_smoke()
	ok(s.d.to_dict().has("smoke"), "a burning cloud is saved")
	var back := _reload(s.d)
	ok(back != null and GameSmoke.active(back) and is_equal_approx(float(back.smoke["until"]), float(s.d.smoke["until"])) and is_equal_approx(float(back.smoke["x"]), float(s.d.smoke["x"])), "and comes back as it was")
	s.d.world_seconds = float(s.d.smoke["until"]) + 5.0
	ok(not s.d.to_dict().has("smoke"), "one that has burned out is not saved")
	# an old save has no cloud
	var old := _sandbox(0)
	var dict := old.d.to_dict()
	dict.erase("smoke")
	var loaded: GameDynasty = GameDynasty.from_dict(JSON.parse_string(JSON.stringify(dict)))
	ok(loaded != null and loaded.smoke.is_empty(), "a save from before smoke pots loads with no cloud")
	# bad values are ignored
	var now := 100.0
	var good := {"x": 300.0, "z": 300.0, "until": 200.0}
	ok(not GameSmoke.load_state(good, now).is_empty(), "a good cloud loads")
	for bad in [
		"smoke", 5, null, [], {}, {"x": 300.0}, {"x": "a", "z": 300.0, "until": 200.0}, {"x": 300.0, "z": 300.0, "until": "soon"},
		{"x": NAN, "z": 300.0, "until": 200.0}, {"x": 300.0, "z": INF, "until": 200.0}, {"x": 300.0, "z": 300.0, "until": NAN},
		{"x": -50.0, "z": 300.0, "until": 200.0}, {"x": 300.0, "z": 9999999.0, "until": 200.0}, {"x": 300.0, "z": 300.0, "until": 50.0},
		{"x": 300.0, "z": 300.0, "until": true}, {"x": [1], "z": 300.0, "until": 200.0},
	]:
		ok(GameSmoke.load_state(bad, now).is_empty(), "a bad cloud is ignored: %s" % str(bad))
	var far := GameSmoke.load_state({"x": 300.0, "z": 300.0, "until": 1.0e12}, now)
	ok(not far.is_empty() and float(far["until"]) <= now + float(GameSmoke.data()["seconds"]) + 0.001, "a time too far off is cut to the longest a cloud can burn")
	var raw: Dictionary = JSON.parse_string(JSON.stringify(old.d.to_dict()))
	raw["smoke"] = {"x": "bad", "z": 1, "until": 5}
	var bad_load := GameDynasty.from_dict(raw)
	ok(bad_load != null and bad_load.smoke.is_empty(), "a damaged cloud in a save loads as none")


func test_shops() -> void:
	var seen := {}
	for shop in ["apothecary", "guild_hall"]:
		var found := false
		for place in ["kingshold", "stonebridge", "port_alder"]:
			for shelf in GameShopStock.build(7, 1, place, 3, shop, 3, "spring"):
				if str(shelf.get("id", "")) == "smoke_pot":
					found = true
		seen[shop] = found
	ok(bool(seen["apothecary"]), "the apothecary stocks smoke pots")
	ok(bool(seen["guild_hall"]), "so does the guild hall, the adventurers' general stores")
	ok(GameItems.SHOPS == ["forge", "store", "temple", "black_market"], "the old shops the autopilot knows are the same")
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	for svc in GameItems.SHOPS:
		ok("smoke_pot" not in GameItems.stock(d, svc), "the old %s never sells one" % svc)
	ok(GameShops.validate().is_empty(), "the shop data is valid: %s" % str(GameShops.validate()))


func test_autopilot() -> void:
	for seed_value in [3, 8]:
		var d := GameDynasty.new_game(seed_value, "Bot", "warrior", "faetouched", "human")
		d.pending_event = {}
		var met := false
		var hook := func(_dd: GameDynasty):
			if d.heir.inventory.has("smoke_pot") or d.smoke.size() > 0:
				met = true
		GameBot.live_life(d, hook)
		ok(not met and not d.heir.inventory.has("smoke_pot") and d.smoke.is_empty(), "the autopilot never meets a smoke pot (seed %d)" % seed_value)
