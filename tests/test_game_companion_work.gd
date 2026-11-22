## Companions that carry and keep watch (roadmap item 52): a gatherer carries what it gathers (it is not in the stores yet)
## until it holds `carry_capacity` units or has nothing left to gather, then walks it to the heir and hands it over, and
## goes back to work; a new order hands over what is carried; with no heir in view it is handed over at once; the `watch`
## order rests at its post by day and by night guards with a longer reach (`watch_reach_mult`) than a plain guard; the
## orders turn through all five; the data checks; and nothing here draws the dynasty's dice.
## Run: godot --headless --path . -s res://tests/test_game_companion_work.gd
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
	test_carry()
	test_deliver_and_orders()
	test_idle_haul_and_night()
	test_watch()
	print("companion work tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _house(ids: Array = ["maddy_thorn"]) -> GameDynasty:
	var d := GameDynasty.new_game(5, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 5000
	for id in ids:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": 10, "gen": 1,
			"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
		d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
			"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	return d


func _grove(d: GameDynasty) -> Vector2:
	var a := GameWorldGen.anchor("hearthmere")
	for r in range(8, 60, 4):
		for k in 16:
			var ang := float(k) / 16.0 * TAU
			var x := int(a["x"]) + int(round(cos(ang) * r))
			var z := int(a["z"]) + int(round(sin(ang) * r))
			if not GameWorldGen.in_bounds(x, z) or GameWorldGen.in_anchor_ground(x, z) or GameWorldGen.tile(d, x, z)["water"]:
				continue
			if Vector2(x - int(a["x"]), z - int(a["z"])).length() < GameWalls.radius("hearthmere") + 6.0:
				continue   # (the town's wall is in the way: a grove beside it is out of reach of the trees on its far side)
			if GameCompanions.scan(d, Vector2(x, z)).size() >= 8:
				return Vector2(float(x), float(z))
	return Vector2(-1, -1)


func _stores(d: GameDynasty) -> int:
	var n := 0
	for m in d.stores.get("materials", {}):
		n += int(d.stores["materials"][m])
	return n


func _run_ticks(d: GameDynasty, agents: Array, view: Dictionary, n: int, from_tick: int, events: Array) -> Array:
	var cur := agents
	for t in range(from_tick, from_tick + n):
		var r := GameCompanions.step_all(d, cur, view, t)
		cur = r["agents"]
		events.append_array(r["events"])
	return cur


func test_data() -> void:
	ok(GameCompanions.validate().is_empty(), "the shipped data passes: %s" % str(GameCompanions.validate()))
	ok(GameCompanions.ORDERS.has("watch") and GameCompanions.order_name("watch") == "Watch", "there is a watch order and it has a name")
	var s: Dictionary = GameCompanions.data()["settings"]
	var keep: int = s["carry_capacity"]
	s["carry_capacity"] = 0
	ok(not GameCompanions.validate().is_empty(), "a load of nothing is caught")
	s["carry_capacity"] = keep
	var mult: float = s["watch_reach_mult"]
	s["watch_reach_mult"] = 0.5
	ok(not GameCompanions.validate().is_empty(), "a watch that sees less far than a guard is caught")
	s["watch_reach_mult"] = mult
	ok(GameCompanions.validate().is_empty(), "and putting them back clears it")
	ok(GameCompanions.load_order("watch") == "watch" and GameCompanions.load_order("flying") == "", "a saved watch order loads, an unknown one is dropped (so the companion follows)")


func test_carry() -> void:
	var d := _house()
	var spot := _grove(d)
	ok(spot.x >= 0, "(there is a grove to gather in)")
	if spot.x < 0:
		return
	var state := d.rng.state
	GameCompanions.set_order(d, "maddy_thorn", "gather")
	var agents := GameCompanions.agents_for(d, spot.x, spot.y)
	# the heir far off, so a load has a way to go
	var view := GameCompanions.view(d, spot.x + 40.0, spot.y)
	var events: Array = []
	var cap := int(GameCompanions.setting("carry_capacity"))
	var seen_load := 0
	var seen_haul := false
	var cur := agents
	for t in 400:
		var r := GameCompanions.step_all(d, cur, view, t)
		cur = r["agents"]
		events.append_array(r["events"])
		seen_load = maxi(seen_load, GameCompanions._load_n(cur[0]))
		if str(cur[0]["mode"]) == "haul":
			seen_haul = true
		if seen_haul:
			break
	ok(seen_load >= cap, "a gatherer fills its load to the capacity (%d, most held %d)" % [cap, seen_load])
	ok(_stores(d) == 0, "and none of it is in the stores while it is carried")
	ok(seen_haul and bool(cur[0]["haul"]), "then it sets out with it (haul)")
	var gathered := events.filter(func(e): return e["type"] == "gathered")
	ok(gathered.size() >= 2, "(it gathered %d times)" % gathered.size())
	ok(d.rng.state == state, "no dice of the dynasty's were drawn")
	# it reaches the heir and hands it over
	var near := GameCompanions.view(d, float(cur[0]["x"]) + 1.0, float(cur[0]["z"]))
	var carried := GameCompanions._load_n(cur[0])
	var ev2: Array = []
	cur = _run_ticks(d, cur, near, 3, 500, ev2)
	ok(_stores(d) == carried and GameCompanions._load_n(cur[0]) == 0 and not bool(cur[0]["haul"]), "within reach of the heir it hands over all of it: %d in the stores" % _stores(d))
	ok(ev2.any(func(e): return e["type"] == "delivered") and GameCompanions.event_text(ev2.filter(func(e): return e["type"] == "delivered")[0].merged({"name": "Maddy"})).contains("brings back"), "and says so")
	var ev3: Array = []
	cur = _run_ticks(d, cur, near, 60, 600, ev3)
	ok(ev3.any(func(e): return e["type"] == "gathered"), "and goes back to work")


func test_deliver_and_orders() -> void:
	var d := _house()
	var a := GameCompanions.new_agent(1, "maddy_thorn", 10.0, 10.0)
	a["order"] = "gather"
	a["load"] = {"oak": 3, "iron": 2}
	GameCompanions.set_order(d, "maddy_thorn", "gather")
	var view := GameCompanions.view(d, 10.5, 10.0)
	var events: Array = []
	var r := GameCompanions.step_all(d, [a], view, 1)
	ok(_stores(d) == 0, "a companion with a small load still carries it while it works")
	a["haul"] = true
	r = GameCompanions.step_all(d, [a], view, 2)
	ok(_stores(d) == 5 and GameCompanions._load_n(r["agents"][0]) == 0, "a load handed over adds each material to the stores: %d" % _stores(d))
	var d2 := _house()
	GameCompanions.set_order(d2, "maddy_thorn", "stay")
	var b := GameCompanions.new_agent(2, "maddy_thorn", 10.0, 10.0)
	b["order"] = "gather"
	b["load"] = {"oak": 4}
	var r2 := GameCompanions.step_all(d2, [b], GameCompanions.view(d2, 80.0, 80.0), 1)
	ok(_stores(d2) == 4 and GameCompanions._load_n(r2["agents"][0]) == 0 and not bool(r2["agents"][0]["haul"]), "a new order hands over what is carried, wherever the heir is: it is not lost")
	var d3 := _house()
	GameCompanions.set_order(d3, "maddy_thorn", "gather")
	var c := GameCompanions.new_agent(3, "maddy_thorn", 10.0, 10.0)
	c["order"] = "gather"
	c["load"] = {"oak": 4}
	c["haul"] = true
	var view_none := {"threats": [], "router": null}
	var r3 := GameCompanions.step_all(d3, [c], view_none, 1)
	ok(_stores(d3) == 4, "with no heir in view a haul is handed over where they stand")


func test_idle_haul_and_night() -> void:
	var d := _house()
	var empty := Vector2(-1, -1)
	for x in range(2, 60, 3):
		for z in range(2, 60, 3):
			if empty.x < 0 and GameCompanions.scan(d, Vector2(float(x), float(z))).is_empty():
				empty = Vector2(float(x), float(z))
	ok(empty.x >= 0, "(there is a place with nothing to gather)")
	GameCompanions.set_order(d, "maddy_thorn", "gather")
	var a := GameCompanions.new_agent(1, "maddy_thorn", empty.x, empty.y)
	a["order"] = "gather"
	a["load"] = {"oak": 2}
	var view := GameCompanions.view(d, empty.x + 30.0, empty.y)
	var cur: Array = [a]
	var events: Array = []
	cur = _run_ticks(d, cur, view, 3, 0, events)
	ok(bool(cur[0]["haul"]) or str(cur[0]["mode"]) == "haul", "with nothing left to gather a small load is taken to the heir (mode %s)" % str(cur[0]["mode"]))
	ok(events.any(func(e): return e["type"] == "nothing"), "(and it said there was nothing)")
	var seen_night := false
	var seen_day := false
	for t in [0.0, 30.0, 60.0, 90.0, 120.0, 140.0]:
		d.world_seconds = t
		var night := GameDay.is_night(d)
		ok(bool(GameCompanions.view(d, 1.0, 1.0)["night"]) == night, "the view tells the companions whether it is night (%.0fs: %s)" % [t, str(night)])
		seen_night = seen_night or night
		seen_day = seen_day or not night
	ok(seen_night and seen_day, "(both a day and a night were looked at)")


func test_watch() -> void:
	var d := _house(["bren_cask", "maddy_thorn"])
	var post := GameCompanions.new_agent(1, "bren_cask", 50.0, 50.0)
	var reach := float(GameCompanions.setting("guard_radius")) * GameCompanions.class_mult("bren_cask", "guard")
	var far := reach * 1.25   # beyond a plain guard's post, inside a watch's at night
	var threat := [{"x": 50.0 + far, "z": 50.0}]
	GameCompanions.set_order(d, "bren_cask", "watch")
	var night := GameCompanions.view(d, 50.0, 55.0, threat)
	night["night"] = true
	var day := GameCompanions.view(d, 50.0, 55.0, threat)
	day["night"] = false
	var a1 := post.duplicate(true)
	a1["order"] = "watch"
	var r := GameCompanions.step_all(d, [a1], night, 1)
	ok(str(r["agents"][0]["mode"]) == "intercept" and r["events"].any(func(e): return e["type"] == "alert"), "by night a watch goes out to a threat beyond a guard's reach: %s" % str(r["agents"][0]["mode"]))
	var a2 := post.duplicate(true)
	a2["order"] = "watch"
	var r2 := GameCompanions.step_all(d, [a2], day, 1)
	ok(str(r2["agents"][0]["mode"]) == "hold" and r2["events"].is_empty() and r2["agents"][0]["x"] == 50.0, "by day the same watch rests at its post: %s" % str(r2["agents"][0]["mode"]))
	GameCompanions.set_order(d, "bren_cask", "guard")
	var a3 := post.duplicate(true)
	a3["order"] = "guard"
	var r3 := GameCompanions.step_all(d, [a3], night, 1)
	ok(str(r3["agents"][0]["mode"]) != "intercept", "a plain guard does not go that far (%s)" % str(r3["agents"][0]["mode"]))
	GameCompanions.set_order(d, "bren_cask", "watch")
	var near := [{"x": 50.0 + reach * 0.5, "z": 50.0}]
	var nv := GameCompanions.view(d, 50.0, 55.0, near)
	nv["night"] = true
	var a4 := post.duplicate(true)
	a4["order"] = "watch"
	a4["x"] = 50.0 + reach * 0.5 - 1.0   # already at the threat
	var r4 := GameCompanions.step_all(d, [a4], nv, 1)
	ok(r4["events"].any(func(e): return e["type"] == "engage"), "a watch at the threat by night fights it like a guard")
	var s := GameSandbox.start(d)
	s.creatures.clear()
	var seen: Array = []
	for i in GameCompanions.ORDERS.size():
		s.cycle_order("bren_cask")
		seen.append(GameCompanions.order_of(d, "bren_cask"))
	ok(seen.has("watch") and seen.size() == 5, "the sandbox's order button turns through the watch: %s" % ", ".join(seen))
