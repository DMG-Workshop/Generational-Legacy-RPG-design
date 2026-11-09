## Companions in the world (roadmap item 52): the data and ways to break it; orders on party members (follow, stay,
## gather, guard), saved only once given, with damaged ones loading as follow; following (keeping up with a heir on the
## move, settling when they stop, regrouping when far behind, not stacking, using a router); staying; guarding (going out
## to a threat near the post and no further than its reach, a class's share widening it, an alert once, going home);
## gathering (nodes into the stores by class share, once until they regrow, two companions on two nodes, nothing to
## gather); the party changing under the agents; saving the gathered nodes; and that none of it draws a die, changes its
## inputs, or moves an autopilot life.
## Run: godot --headless --path . -s res://tests/test_game_companions.gd
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
	test_orders()
	test_saving()
	test_follow()
	test_stay()
	test_guard()
	test_gather()
	test_party_changes()
	test_pure()
	print("companion tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## A dynasty with companions on the payroll: Bren Cask (a warrior), Maddy Thorn (a rogue) and Sister Oriel (a cleric).
func _house(ids: Array = ["bren_cask", "maddy_thorn"]) -> GameDynasty:
	var d := GameDynasty.new_game(5, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 5000
	for id in ids:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": 10, "gen": 1,
			"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
		d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
			"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	return d


func _home() -> Vector2:
	var a := GameWorldGen.anchor("hearthmere")
	return Vector2(float(a["x"]), float(a["z"]))


func _run_ticks(d: GameDynasty, agents: Array, view: Dictionary, n: int, from_tick: int = 0, all_events: Array = []) -> Array:
	var cur := agents
	for t in range(from_tick, from_tick + n):
		var r := GameCompanions.step_all(d, cur, view, t)
		cur = r["agents"]
		all_events.append_array(r["events"])
	return cur


func _by(agents: Array, id: String) -> Dictionary:
	for a in agents:
		if a["id"] == id:
			return a
	return {}


func _dist(a: Dictionary, x: float, z: float) -> float:
	return Vector2(float(a["x"]), float(a["z"])).distance_to(Vector2(x, z))


# ---------------------------------------------------------------- data

func test_data() -> void:
	ok(GameCompanions.validate().is_empty(), "the data is sound: %s" % str(GameCompanions.validate()))
	var saved: Dictionary = GameCompanions.data().duplicate(true)
	GameCompanions.data()["settings"]["follow_min"] = 7.0
	ok(not GameCompanions.validate().is_empty(), "followers that would never settle (min above max) are found")
	GameCompanions._cache = saved.duplicate(true)
	GameCompanions.data()["settings"]["gather_reach"] = 20.0
	ok(not GameCompanions.validate().is_empty(), "a reach longer than the gathering radius is found")
	GameCompanions._cache = saved.duplicate(true)
	GameCompanions.data()["classes"]["juggler"] = {"gather": 1.0, "guard": 1.0}
	ok(not GameCompanions.validate().is_empty(), "work shares for a class that does not exist are found")
	GameCompanions._cache = saved.duplicate(true)
	GameCompanions.data()["classes"].erase("druid")
	ok(not GameCompanions.validate().is_empty(), "a companion class with no shares is found")
	GameCompanions._cache = saved.duplicate(true)
	GameCompanions.data()["classes"]["warrior"]["guard"] = 0.0
	ok(not GameCompanions.validate().is_empty(), "a class that cannot guard at all is found")
	GameCompanions._cache = saved.duplicate(true)
	GameCompanions.data()["orders"].erase("guard")
	ok(not GameCompanions.validate().is_empty(), "an order with no name is found")
	GameCompanions._cache = saved.duplicate(true)
	GameCompanions.data()["orders"]["dance"] = "Dance"
	ok(not GameCompanions.validate().is_empty(), "a named order the code does not know is found")
	GameCompanions._cache = saved.duplicate(true)
	GameCompanions.data()["text"].erase("alert")
	ok(not GameCompanions.validate().is_empty(), "a missing line of text is found")
	GameCompanions._cache = saved.duplicate(true)
	GameCompanions.data()["settings"]["regrow_years"] = 0.0
	ok(not GameCompanions.validate().is_empty(), "nodes that regrow at once are found")
	GameCompanions._cache = {}
	ok(GameCompanions.validate().is_empty(), "(and the data is whole again after)")


# ---------------------------------------------------------------- orders

func test_orders() -> void:
	var d := _house()
	ok(GameCompanions.order_of(d, "bren_cask") == "follow" and not d.party.member("bren_cask").has("order"), "a hired companion follows, and has no order saved")
	var r := GameCompanions.set_order(d, "bren_cask", "gather")
	ok(r["ok"] and GameCompanions.order_of(d, "bren_cask") == "gather" and r["text"] == "Bren Cask will gather.", "an order is given: %s" % r["text"])
	ok(GameCompanions.order_of(d, "maddy_thorn") == "follow", "and only to the one")
	ok(not GameCompanions.set_order(d, "bren_cask", "dance")["ok"] and GameCompanions.order_of(d, "bren_cask") == "gather", "an unknown order is refused and changes nothing")
	var nobody := GameCompanions.set_order(d, "old_netta", "stay")
	ok(not nobody["ok"] and nobody["text"].contains("not in the party"), "so is one for a companion who is not in the party: %s" % nobody["text"])
	GameCompanions.set_order(d, "maddy_thorn", "guard")
	var lines := GameCompanions.describe(d)
	ok(lines.contains("Bren Cask: Gather") and lines.contains("Maddy Thorn: Guard"), "the orders read back: %s" % lines.replace("\n", " / "))
	GameCompanions.set_order(d, "bren_cask", "follow")
	ok(not d.party.member("bren_cask").has("order") and GameCompanions.order_of(d, "bren_cask") == "follow", "follow takes the order away again")
	ok(GameCompanions.describe(GameDynasty.new_game(5, "T", "warrior", "faetouched", "human")) == "No companions.", "with no party there is nothing to say")
	ok(is_equal_approx(GameCompanions.class_mult("bren_cask", "guard"), 1.4) and is_equal_approx(GameCompanions.class_mult("maddy_thorn", "gather"), 1.5), "a warrior guards better and a rogue gathers better")


# ---------------------------------------------------------------- saving

func test_saving() -> void:
	var d := _house()
	ok(not JSON.stringify(d.to_dict()).contains("\"order\"") and not d.to_dict().has("gathered"), "with no orders and nothing gathered, a save holds neither")
	GameCompanions.set_order(d, "maddy_thorn", "stay")
	d.gathered["10,12"] = 3.5
	var json := JSON.parse_string(JSON.stringify(d.to_dict())) as Dictionary
	var back := GameDynasty.from_dict(json)
	ok(GameCompanions.order_of(back, "maddy_thorn") == "stay" and GameCompanions.order_of(back, "bren_cask") == "follow", "an order is saved and comes back through JSON")
	ok(back.gathered == {"10,12": 3.5}, "so do the gathered nodes")
	var old := json.duplicate(true)
	for m in old["party"]["members"]:
		m.erase("order")
	old.erase("gathered")
	var older := GameDynasty.from_dict(old)
	ok(GameCompanions.order_of(older, "maddy_thorn") == "follow" and older.gathered.is_empty(), "an old save with neither loads with everyone following")
	for junk in [5, "dance", "follow", "", null, [], {"a": 1}, true, "GUARD"]:
		var damaged := json.duplicate(true)
		for m in damaged["party"]["members"]:
			m["order"] = junk
		var g := GameDynasty.from_dict(damaged)
		ok(GameCompanions.order_of(g, "maddy_thorn") == "follow" and not g.party.member("maddy_thorn").has("order"), "a damaged order (%s) loads as follow" % str(junk))
	for junk2 in [5, "x", [], null, {"1,2": "soon"}, {"a,b": 1.0}, {"1,2": NAN}, {"1,2": INF}, {"1.5,2": 1.0}]:
		var damaged2 := json.duplicate(true)
		damaged2["gathered"] = junk2
		ok(GameDynasty.from_dict(damaged2).gathered.is_empty(), "damaged gathered nodes (%s) load as none" % str(junk2))
	var mixed := json.duplicate(true)
	mixed["gathered"] = {"1,2": 4.0, "x": 1.0, "3,4": "late", "5,6": 2}
	ok(GameDynasty.from_dict(mixed).gathered == {"1,2": 4.0, "5,6": 2.0}, "only the good nodes of a mixed list are kept")


# ---------------------------------------------------------------- following

func test_follow() -> void:
	var d := _house()
	var h := _home()
	var agents := GameCompanions.agents_for(d, h.x, h.y)
	ok(agents.size() == 2 and _dist(agents[0], h.x, h.y) < 3.0 and _dist(agents[1], h.x, h.y) < 3.0, "companions start beside the heir, one agent each")
	ok(_dist(agents[0], agents[1]["x"], agents[1]["z"]) > 1.0, "and not on the same spot")
	var fmax := float(GameCompanions.setting("follow_max"))
	var fmin := float(GameCompanions.setting("follow_min"))
	var worst := 0.0
	var heir := h
	var cur := agents
	for t in 24:
		heir = Vector2(h.x, h.y + float(t))   # the heir walks south, a tile a tick
		cur = GameCompanions.step_all(d, cur, GameCompanions.view(d, heir.x, heir.y), t)["agents"]
		for a in cur:
			worst = maxf(worst, _dist(a, heir.x, heir.y))
	ok(worst <= fmax + 2.0, "a heir who walks away is kept up with: never more than %.1f off (follow_max %.1f)" % [worst, fmax])
	cur = _run_ticks(d, cur, GameCompanions.view(d, heir.x, heir.y), 20, 100)
	var settled := true
	for a in cur:
		if _dist(a, heir.x, heir.y) > fmax or a["mode"] != "hold":
			settled = false
	ok(settled, "and once the heir stops they settle within follow_max, holding")
	var before := JSON.stringify(cur)
	cur = _run_ticks(d, cur, GameCompanions.view(d, heir.x, heir.y), 10, 200)
	ok(JSON.stringify(cur) == before, "settled companions stand still (no fidgeting)")
	var events: Array = []
	var far := Vector2(heir.x, heir.y + 60.0)
	cur = _run_ticks(d, cur, GameCompanions.view(d, far.x, far.y), 1, 300, events)
	var regroups := events.filter(func(e: Dictionary) -> bool: return e["type"] == "regrouped")
	ok(regroups.size() == 2 and _dist(cur[0], far.x, far.y) <= fmin + 0.01, "a heir who is far off (over follow_catchup) is caught up with at once (%d regrouped)" % regroups.size())
	ok(not regroups.is_empty() and GameCompanions.event_text(regroups[0]).contains("catches up"), "and it is told: catches up")
	var calls := [0]
	var router := func(from: Vector2, to: Vector2) -> Vector2:
		calls[0] += 1
		return to
	var trail := GameCompanions.agents_for(d, h.x, h.y)
	_run_ticks(d, trail, GameCompanions.view(d, h.x + 12.0, h.y, [], router), 3)
	ok(calls[0] > 0, "a router in the view is used to find the way")
	var wolf_view := GameCompanions.view(d, h.x, h.y)
	ok(wolf_view["heir"] == {"x": h.x, "z": h.y} and wolf_view.has("walkable") and wolf_view["threats"] == [], "the view carries the heir, the threats and the ground")


# ---------------------------------------------------------------- staying

func test_stay() -> void:
	var d := _house(["bren_cask"])
	var h := _home()
	var agents := GameCompanions.agents_for(d, h.x, h.y)
	GameCompanions.set_order(d, "bren_cask", "stay")
	agents = _run_ticks(d, agents, GameCompanions.view(d, h.x + 80.0, h.y), 1)
	var post := Vector2(float(agents[0]["post_x"]), float(agents[0]["post_z"]))
	var start := Vector2(float(agents[0]["x"]), float(agents[0]["z"]))
	ok(post.is_equal_approx(start), "the place they stand when told to stay is their post")
	agents = _run_ticks(d, agents, GameCompanions.view(d, h.x + 80.0, h.y + 40.0), 50, 1)
	ok(_dist(agents[0], post.x, post.y) < 0.001, "an heir who goes away does not take them along")
	var pushed: Array = [agents[0].duplicate(true)]
	pushed[0]["x"] = post.x + 6.0
	pushed = _run_ticks(d, pushed, GameCompanions.view(d, h.x, h.y), 10, 60)
	ok(_dist(pushed[0], post.x, post.y) <= float(GameCompanions.setting("stay_radius")) + 0.01, "one moved off the post goes back to it")
	GameCompanions.set_order(d, "bren_cask", "follow")
	var again := _run_ticks(d, pushed, GameCompanions.view(d, post.x + 20.0, post.y), 20, 100)
	ok(_dist(again[0], post.x + 20.0, post.y) < float(GameCompanions.setting("follow_max")) + 0.01, "and back to follow, they come after the heir")


# ---------------------------------------------------------------- guarding

func test_guard() -> void:
	var d := _house(["bren_cask", "maddy_thorn"])   # a warrior and a rogue
	var h := _home()
	var agents := GameCompanions.agents_for(d, h.x, h.y)
	GameCompanions.set_order(d, "bren_cask", "guard")
	GameCompanions.set_order(d, "maddy_thorn", "guard")
	var events: Array = []
	agents = _run_ticks(d, agents, GameCompanions.view(d, h.x, h.y), 1, 0, events)
	var posts := {}
	for a in agents:
		posts[a["id"]] = Vector2(float(a["post_x"]), float(a["post_z"]))
	ok(events.is_empty() and agents[0]["mode"] == "hold", "a guard with nothing to meet holds the post")
	var reach_w := float(GameCompanions.setting("guard_radius")) * 1.4
	var reach_r := float(GameCompanions.setting("guard_radius")) * 0.8
	var threat := {"x": posts["bren_cask"].x + 12.0, "z": posts["bren_cask"].y}   # 12 from the warrior's post: in his reach (14) not the rogue's (8)
	var r_post: Vector2 = posts["maddy_thorn"]
	var threat_r := {"x": r_post.x + 12.0, "z": r_post.y}
	events = []
	var view := GameCompanions.view(d, h.x, h.y, [threat, threat_r])
	agents = _run_ticks(d, agents, view, 20, 1, events)
	var warrior := _by(agents, "bren_cask")
	var rogue := _by(agents, "maddy_thorn")
	ok(warrior["mode"] == "intercept" and _dist(warrior, posts["bren_cask"].x, posts["bren_cask"].y) > 3.0, "a warrior goes out to a threat 12 tiles from his post (his reach is %.0f)" % reach_w)
	ok(rogue["mode"] != "intercept" and _dist(rogue, r_post.x, r_post.y) < 1.5, "a rogue (reach %.0f) holds her post against the same distance" % reach_r)
	var alerts := events.filter(func(e: Dictionary) -> bool: return e["type"] == "alert")
	ok(alerts.size() == 1 and alerts[0]["id"] == "bren_cask" and GameCompanions.event_text(alerts[0]) == "Bren Cask sees something coming.", "one alert, from the one who goes out: %s" % GameCompanions.event_text(alerts[0]) if not alerts.is_empty() else "one alert, from the one who goes out")
	var nearest := minf(_dist(warrior, threat["x"], threat["z"]), _dist(warrior, threat_r["x"], threat_r["z"]))
	ok(nearest <= float(GameCompanions.setting("guard_engage")) + 1.2 and nearest > 0.3, "and he stops at the threat, not through it (%.1f away)" % nearest)
	var far_threat := {"x": posts["bren_cask"].x + 40.0, "z": posts["bren_cask"].y}
	var far := _run_ticks(d, GameCompanions.agents_for(d, h.x, h.y), GameCompanions.view(d, h.x, h.y, [far_threat]), 3)
	ok(far[0]["mode"] != "intercept", "a threat out of reach is ignored (it is a long way off)")
	# a guard knocked out beyond his reach, with a threat at its edge, is not led further out
	var edge := {"x": posts["bren_cask"].x + reach_w - 0.2, "z": posts["bren_cask"].y}
	var knocked: Array = [_by(agents, "bren_cask").duplicate(true)]
	knocked[0]["x"] = posts["bren_cask"].x + reach_w + 6.0
	knocked[0]["z"] = posts["bren_cask"].y
	knocked[0]["mode"] = "hold"
	knocked = _run_ticks(d, knocked, GameCompanions.view(d, h.x, h.y, [edge]), 10, 60)
	ok(_dist(knocked[0], posts["bren_cask"].x, posts["bren_cask"].y) <= reach_w + 0.01, "(drawn out by a threat at the edge of his reach, he is held to it: %.1f of %.1f)" % [_dist(knocked[0], posts["bren_cask"].x, posts["bren_cask"].y), reach_w])
	# never drawn beyond the reach, however the threat moves
	var cur := agents
	var worst := 0.0
	for t in 40:
		var running := {"x": posts["bren_cask"].x + 13.5 + float(t % 5), "z": posts["bren_cask"].y + float(t % 7) - 3.0}
		cur = GameCompanions.step_all(d, cur, GameCompanions.view(d, h.x, h.y, [running]), 20 + t)["agents"]
		worst = maxf(worst, _dist(_by(cur, "bren_cask"), posts["bren_cask"].x, posts["bren_cask"].y))
	ok(worst <= reach_w + 0.01, "a guard is never drawn further than the reach of his post (%.1f of %.1f)" % [worst, reach_w])
	events = []
	cur = _run_ticks(d, cur, GameCompanions.view(d, h.x, h.y, []), 40, 100, events)
	ok(_dist(_by(cur, "bren_cask"), posts["bren_cask"].x, posts["bren_cask"].y) < 0.8 and _by(cur, "bren_cask")["mode"] == "hold", "when the threat is gone he goes back to the post")
	events = []
	_run_ticks(d, cur, GameCompanions.view(d, h.x, h.y, [threat]), 2, 200, events)
	ok(events.filter(func(e: Dictionary) -> bool: return e["type"] == "alert").size() == 1, "and sees the next one coming (an alert again)")


# ---------------------------------------------------------------- gathering

## A spot with plenty of nodes to gather round it.
func _grove(d: GameDynasty) -> Vector2:
	for x in range(60, 600, 14):
		for z in range(60, 600, 14):
			if GameWorldGen.in_anchor_ground(x, z):
				continue
			var tile := GameWorldGen.tile(d, x, z)
			if tile["water"]:
				continue
			if GameCompanions.scan(d, Vector2(x, z)).size() >= 8:
				return Vector2(float(x), float(z))
	return Vector2(-1, -1)


func test_gather() -> void:
	var d := _house(["maddy_thorn", "bren_cask"])
	var spot := _grove(d)
	ok(spot.x >= 0, "(there is a grove to gather in)")
	if spot.x < 0:
		return
	var nodes := GameCompanions.scan(d, spot)
	ok(nodes[0]["dist"] <= nodes[1]["dist"] and nodes[1]["dist"] <= nodes[2]["dist"], "scanning gives the nodes nearest the post first")
	var one := _house(["maddy_thorn"])
	var agents := GameCompanions.agents_for(one, spot.x, spot.y)
	GameCompanions.set_order(one, "maddy_thorn", "gather")
	var events: Array = []
	var view := GameCompanions.view(one, spot.x, spot.y)
	agents = _run_ticks(one, agents, view, 200, 0, events)
	var got := events.filter(func(e: Dictionary) -> bool: return e["type"] == "gathered")
	ok(got.size() >= 3, "a gathering companion works one node after another (%d in 200 ticks)" % got.size())
	var first: Dictionary = got[0]
	var node: Dictionary = GameWorldGen.tile(one, int(first["x"]), int(first["z"]))["node"]
	var expect := maxi(1, int(round(float(node["amount"]) * 1.5)))
	ok(int(first["n"]) == expect and str(first["material"]) == str(node["material"]), "and takes the node's material, a rogue's share more: %d %s from a node of %d" % [int(first["n"]), first["material"], int(node["amount"])])
	var total := 0
	for e in got:
		total += int(e["n"])
	var stocks := 0
	for m in one.stores.get("materials", {}):
		stocks += int(one.stores["materials"][m])
	ok(stocks == total and total > 0, "all of it goes into the family's stores (%d)" % total)
	var key := GameCompanions.node_key(int(first["x"]), int(first["z"]))
	ok(one.gathered.has(key) and GameCompanions.depleted(one, int(first["x"]), int(first["z"])), "a gathered node is marked")
	var twice := got.filter(func(e: Dictionary) -> bool: return e["x"] == first["x"] and e["z"] == first["z"])
	ok(twice.size() == 1, "and not taken again at once")
	one.world.year += float(GameCompanions.setting("regrow_years")) + 0.1
	ok(not GameCompanions.depleted(one, int(first["x"]), int(first["z"])), "after regrow_years of the calendar it has grown back")
	ok(GameCompanions.event_text(first).begins_with("Maddy Thorn gathered "), "the event reads: %s" % GameCompanions.event_text(first))
	# a warrior takes less from the same kind of node
	var brute := _house(["bren_cask"])
	GameCompanions.set_order(brute, "bren_cask", "gather")
	var brute_events: Array = []
	_run_ticks(brute, GameCompanions.agents_for(brute, spot.x, spot.y), GameCompanions.view(brute, spot.x, spot.y), 200, 0, brute_events)
	var brute_got := brute_events.filter(func(e: Dictionary) -> bool: return e["type"] == "gathered")
	var b0: Dictionary = brute_got[0]
	var bnode: Dictionary = GameWorldGen.tile(brute, int(b0["x"]), int(b0["z"]))["node"]
	ok(int(b0["n"]) == maxi(1, int(round(float(bnode["amount"]) * 0.8))), "a warrior takes a smaller share (%d from a node of %d)" % [int(b0["n"]), int(bnode["amount"])])
	# two gatherers do not work the same node
	GameCompanions.set_order(d, "maddy_thorn", "gather")
	GameCompanions.set_order(d, "bren_cask", "gather")
	var pair_events: Array = []
	_run_ticks(d, GameCompanions.agents_for(d, spot.x, spot.y), GameCompanions.view(d, spot.x, spot.y), 60, 0, pair_events)
	var seen := {}
	var dup := false
	for e in pair_events.filter(func(e: Dictionary) -> bool: return e["type"] == "gathered"):
		var k := GameCompanions.node_key(int(e["x"]), int(e["z"]))
		if seen.has(k):
			dup = true
		seen[k] = true
	ok(seen.size() >= 2 and not dup, "two companions gather different nodes (%d nodes, none twice)" % seen.size())
	var started := _run_ticks(d, GameCompanions.agents_for(d, spot.x, spot.y), GameCompanions.view(d, spot.x, spot.y), 2)
	ok(not started[0]["target"].is_empty() and not started[1]["target"].is_empty() and started[0]["target"] != started[1]["target"], "and they are sent to different nodes from the start, not the same one")
	# nothing to gather: a town's flat, with a short reach
	var saved: Dictionary = GameCompanions.data().duplicate(true)
	GameCompanions.data()["settings"]["gather_radius"] = 3
	var h := _home()
	var lone := _house(["bren_cask"])
	GameCompanions.set_order(lone, "bren_cask", "gather")
	var none_events: Array = []
	var idle := _run_ticks(lone, GameCompanions.agents_for(lone, h.x, h.y), GameCompanions.view(lone, h.x, h.y), 100, 0, none_events)
	ok(idle[0]["mode"] == "idle" and none_events.filter(func(e: Dictionary) -> bool: return e["type"] == "nothing").size() == 1 and lone.stores.is_empty(), "with nothing in reach they say so once and wait (%s)" % GameCompanions.event_text(none_events[0]) if not none_events.is_empty() else "with nothing in reach they say so once and wait")
	GameCompanions._cache = saved


# ---------------------------------------------------------------- the party changing

func test_party_changes() -> void:
	var d := _house(["bren_cask", "maddy_thorn"])
	var h := _home()
	var agents := GameCompanions.agents_for(d, h.x, h.y)
	agents = _run_ticks(d, agents, GameCompanions.view(d, h.x + 15.0, h.y), 5)
	var kept := JSON.stringify(_by(agents, "maddy_thorn"))
	d.party.members.erase(d.party.member("bren_cask"))
	d.party.members.append({"id": "sister_oriel", "name": "Sister Oriel", "hp": 1, "mp": 0, "level": 10, "gen": 1, "due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
	var now := GameCompanions.reconcile(d, agents, h.x + 15.0, h.y)
	ok(now.size() == 2 and _by(now, "bren_cask").is_empty() and not _by(now, "sister_oriel").is_empty(), "a companion who left is dropped and a new one joins")
	ok(JSON.stringify(_by(now, "maddy_thorn")) == kept, "and the one who stayed is as she was")
	ok(_dist(_by(now, "sister_oriel"), h.x + 15.0, h.y) < 3.0, "the new one stands beside the heir")
	ok(GameCompanions.reconcile(d, now, h.x, h.y).size() == 2, "reconciling again changes nothing")


# ---------------------------------------------------------------- pure

func test_pure() -> void:
	var d := _house(["bren_cask", "maddy_thorn"])
	var h := _home()
	GameCompanions.set_order(d, "bren_cask", "guard")
	var agents := GameCompanions.agents_for(d, h.x, h.y)
	var snapshot := JSON.stringify(agents)
	var rng_before := d.rng.state
	var view := GameCompanions.view(d, h.x + 5.0, h.y, [{"x": h.x + 4.0, "z": h.y}])
	var r := GameCompanions.step_all(d, agents, view, 0)
	ok(JSON.stringify(agents) == snapshot, "stepping does not change the agents it is given")
	for t in 30:
		r = GameCompanions.step_all(d, r["agents"], view, t + 1)
	ok(d.rng.state == rng_before, "following and guarding draw none of the dynasty's dice")
	var a := _house(["bren_cask", "maddy_thorn"])
	var b := _house(["bren_cask", "maddy_thorn"])
	GameCompanions.set_order(a, "bren_cask", "gather")
	GameCompanions.set_order(b, "bren_cask", "gather")
	var spot := _grove(a)
	var ra := _run_ticks(a, GameCompanions.agents_for(a, spot.x, spot.y), GameCompanions.view(a, spot.x, spot.y), 80)
	var rb := _run_ticks(b, GameCompanions.agents_for(b, spot.x, spot.y), GameCompanions.view(b, spot.x, spot.y), 80)
	ok(JSON.stringify(ra) == JSON.stringify(rb) and JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()), "the same dynasty and ticks give the same companions, stores and nodes")
	var life := GameDynasty.new_game(7, "Bot", "warrior", "faetouched", "human")
	for i in 200:
		if life.state != "life":
			break
		GameBot.step(life)
	var ordered := false
	for m in life.party.members:
		if m.has("order"):
			ordered = true
	ok(not ordered and life.gathered.is_empty() and not life.to_dict().has("gathered"), "an autopilot life gives no orders and gathers nothing")
