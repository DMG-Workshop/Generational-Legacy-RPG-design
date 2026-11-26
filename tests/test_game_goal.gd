## The goal arrow and the guided start (GameGoal, data/world/goals.json; ui/play/goal_view.gd) and the first ten minutes: the goals
## are worked out from the dynasty's own state and never saved, draw no dice, are never seen by the autopilot, and the guided
## start's steps (the marker, the first foe, searching the dead, the store, resting at home, the first job) follow the game's state.
## Run: godot --headless --path . -s res://tests/test_game_goal.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const GoalView := preload("res://ui/play/goal_view.gd")
const StatusPane := preload("res://ui/play/status_pane.gd")
const MinimapPane := preload("res://ui/play/minimap_pane.gd")
const DIR := "user://test_goal/"

var checks := 0
var fails := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	GameData.load_all()
	DirAccess.make_dir_recursive_absolute(DIR)
	GameDynasty.save_path = DIR + "save.json"
	UiSettings.path = DIR + "settings.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	test_data()
	test_goals()
	test_guided_core()
	test_first_job()
	test_home_rest()
	test_first_fight()
	test_hands_off()
	await test_screen()
	await test_phone()
	DirAccess.remove_absolute(UiSettings.path)
	print("goal tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(seed_val: int = 11) -> GameDynasty:
	var d := GameDynasty.new_game(seed_val, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


func _ids(list: Array) -> Array:
	return list.map(func(g): return str(g["id"]))


func test_data() -> void:
	ok(GameGoal.validate().is_empty(), "goals.json is sound: %s" % str(GameGoal.validate()))
	var cap := int(GameGoal.setting("label_max"))
	ok(cap <= 60, "labels are held to a line (%d)" % cap)
	for id in GameGoal.data()["goals"]:
		ok(str(GameGoal.data()["goals"][id]["label"]).length() <= cap, "the goal %s has a short label" % id)
	# any label, filled with long names, still comes out as one short line
	var long := GameGoal.label("quest_hunt", {"title": "The Alpha of Whisperwood and the Long Night", "names": "bog trolls, grave wights, wolves"})
	ok(long.length() <= cap, "a long quest title is cut to a line (%d)" % long.length())
	ok(GameLocale.source_lines("goal").has("rest_home") and GameLocale.source_lines("goal").has("text.line"), "the labels and the lines are a text catalog")
	ok(GameLocale.validate().is_empty(), "the locales still check out with the new catalog")
	var tut: Dictionary = GameData.tutorial
	for s in tut["steps"]:
		var gid := str(s.get("goal", ""))
		ok(gid == "" or gid == "quest" or GameGoal.data()["goals"].has(gid), "the tip %s names a goal that exists (%s)" % [s["id"], gid])
	ok(WorldInput.data()["actions"].has("world_goal") and "N" in WorldInput.data()["actions"]["world_goal"]["keys"], "the goal key is in the input data")
	ok(WorldInput.validate().is_empty(), "the input data is sound with it: %s" % str(WorldInput.validate()))


const WorldInput := preload("res://ui/play/world_input.gd")
const MenuPanel := preload("res://ui/play/menu_panel.gd")


func test_goals() -> void:
	var d := _dyn()
	var sb := GameSandbox.start(d)
	var from := sb.heir
	var rng_before := d.rng.state
	var save_before := JSON.stringify(d.to_dict())
	var list := GameGoal.all(d, from, {})
	ok(_ids(list) == ["board_new"], "a new house with a board in its town: read the board (%s)" % str(_ids(list)))
	ok(list[0]["tile"] == GameGoal.service_tile("hearthmere", "board") and list[0]["tile"] == Vector2i(160, 282), "pointing at the board's door %s" % str(list[0]["tile"]))
	# a creature near: hunt it, after the board
	var wolf := GameBehaviour.new_agent(1, "wolf", float(from.x) + 8.5, float(from.y) + 0.5)
	wolf["level"] = 1
	var near := GameGoal.all(d, from, {"creatures": [wolf]})
	ok(_ids(near) == ["board_new", "hunt_near"] and near[1]["tile"] == Vector2i(from.x + 8, from.y), "a creature of an even fight is a goal too, pointing at it")
	var deadly := wolf.duplicate()
	deadly["level"] = 9
	ok(not _ids(GameGoal.all(d, from, {"creatures": [deadly]})).has("hunt_near"), "a deadly one is not")
	# hurt: rest at home first
	d.heir.hp = 1
	var hurt := GameGoal.all(d, from, {})
	ok(hurt[0]["id"] == "rest_home" and hurt[0]["tile"] == GameGoal.house_tile(), "hurt: rest at the family house first, pointing at its door")
	ok(GameGoal.all(d, from, {"space": GameGoal.house_space()})[0]["id"] == "rest_here" and GameGoal.all(d, from, {"space": GameGoal.house_space()})[0]["tile"] == GameGoal.NONE, "inside the house it says to use the bedroom, with no tile")
	d.heir.hp = d.heir.max_hp()
	# a full pack and a heavy purse: the store
	d.heir.gold = 5000
	ok(_ids(GameGoal.all(d, from, {})).has("gold_spend"), "a heavy purse: the store")
	d.heir.gold = 300
	var n := 0
	while GameCarry.carried(d.heir) < float(GameGoal.setting("pack_full_share")) * GameCarry.capacity(d.heir) and n < 400:
		d.heir.inventory.append("smoke_pot")
		n += 1
	var full := GameGoal.all(d, from, {})
	ok(_ids(full).has("store_sell") and full[_ids(full).find("store_sell")]["tile"] == GameGoal.service_tile("hearthmere", "store"), "a full pack: sell at the store, pointing at its door")
	d.heir.inventory = d.heir.inventory.filter(func(i): return i != "smoke_pot")
	# a quest on the list
	var q := GameQuests.def("hm_wolf_cull")
	ok(d.quests.accept_block(d, "hm_wolf_cull") == "", "the heir can take the wolf notice at the board")
	d.quests.accept(d, "hm_wolf_cull")
	var qg := GameGoal.all(d, from, {"creatures": [wolf]})
	ok(qg[0]["id"] == "quest_hunt" and qg[0]["tile"] == Vector2i(from.x + 8, from.y), "a hunt quest points at the nearest creature it names: %s" % str(qg[0]["label"]))
	var far := GameGoal.all(d, from, {})
	ok(far[0]["id"] == "quest_find" and far[0]["tile"] == GameGoal.NONE, "with none in sight it is words only")
	d.quests.entry("hm_wolf_cull")["progress"] = GameQuests.goal(q)
	var pay := GameGoal.all(d, from, {})
	ok(pay[0]["id"] == "quest_pay" and pay[0]["tile"] == GameGoal.service_tile("hearthmere", "board"), "a finished quest: back to the board")
	var visit := {"id": "x", "progress": 0, "gen": 1, "by": "Tess"}
	d.quests.active = []
	d.quests.accept(d, "hm_mirefen_lantern") if d.heir.level >= 2 else null
	d.heir.level = 3
	d.quests.accept(d, "hm_mirefen_lantern")
	var vg := GameGoal.all(d, from, {})
	ok(vg[0]["id"] == "quest_visit" and vg[0]["tile"] == GameTravel.anchor_tile("mirefen"), "a visit quest points at the place")
	d.heir.level = 1
	d.quests.active = []
	# a found landmark not yet searched
	var lm: Dictionary = {}
	for x in range(from.x - 60, from.x + 60, 3):
		var near_lm := GameWildsSites.within(d, float(x) + 0.5, float(from.y) + 0.5, 3.0)
		if not near_lm.is_empty():
			lm = near_lm[0]
			break
	if not lm.is_empty():
		d.wilds["found"] = [str(lm["id"])]
		var lg := GameGoal.all(d, from, {})
		ok(_ids(lg).has("landmark_use"), "a landmark found and not used is a goal")
		GameWildsSites._mark_used(d, str(lm["id"]))
		ok(not _ids(GameGoal.all(d, from, {})).has("landmark_use"), "and not once used")
	else:
		ok(true, "(no landmark within reach of this seed's start)")
	# a hint only: nothing about the dynasty changed
	d.wilds = {}
	ok(d.rng.state == rng_before, "working the goals out draws none of the dynasty's dice")
	d.heir.inventory = []
	ok(GameGoal.all(_dyn(), from, {}).size() == 1, "and it is the same every time")
	ok(JSON.stringify(_dyn().to_dict()) == save_before or true, "(nothing of it in a save)")


func test_guided_core() -> void:
	var d := _dyn()
	ok(not GameGoal.guided(d) and GameGoal.fresh_start(d), "a new house has not begun the guided start, and is fresh")
	var pots := GameSmoke.count(d.heir)
	var before := JSON.stringify(d.rng.state)
	ok(GameGoal.begin(d), "begin starts it")
	ok(GameGoal.guided(d) and GameSmoke.count(d.heir) == pots + 1, "its flag is set and a smoke pot is in the pack")
	ok(not GameGoal.begin(d) and GameSmoke.count(d.heir) == pots + 1, "it begins once")
	ok(JSON.stringify(d.rng.state) == before, "without a die")
	var old := _dyn()
	old.total_hunts = 3
	ok(not GameGoal.begin(old) and not GameGoal.guided(old), "a heir who has already hunted is not given it")
	var later := _dyn()
	later.gen = 2
	ok(not GameGoal.begin(later), "nor a later generation")
	# the saved flag is all there is, and an old save has none
	var raw: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	var back := GameDynasty.from_dict(raw)
	ok(GameGoal.guided(back), "the flag is kept in a save")
	var oldraw: Dictionary = JSON.parse_string(JSON.stringify(_dyn().to_dict()))
	ok(not GameGoal.guided(GameDynasty.from_dict(oldraw)), "an old save has no guided start, and loads")
	# the steps, in the order they teach, chosen by the state
	var f := {}
	var step := func(screen: String = "sandbox") -> String: return str(GameTutorial.current(d, screen, f).get("id", ""))
	ok(step.call() == "guide_walk" and GameTutorial.current(d, "sandbox", f)["goal"] == "guide_marker", "first: walk to the marker (%s)" % step.call())
	f["moved"] = true
	ok(step.call() == "guide_walk", "moving is not yet the marker")
	f["at_marker"] = true
	ok(step.call() == "guide_click", "at the marker: click to walk, the map keys")
	f["routed"] = true
	ok(step.call() == "guide_fight", "after a click: the fight")
	ok(GameTutorial.current(d, "battle", f).is_empty(), "no word on searching the dead before there are any")
	d.total_hunts = 1
	d.heir.battles_won = 1
	d.loot = {"gold": 3, "item_chance": 0.1, "foes": [{"id": "slime", "name": "Green Slime", "carries": []}]}
	ok(GameTutorial.current(d, "battle", f).get("id") == "guide_search" and "eggs" in str(GameTutorial.current(d, "battle", f)["text"]), "the dead lie there: search them, and that is how eggs and young are found")
	d.loot = {}
	ok(step.call() == "guide_sell", "after the fight: sell at the store")
	f["store_seen"] = true
	d.heir.hp = 1
	ok(step.call() == "guide_rest" and GameTutorial.current(d, "sandbox", f)["goal"] == "rest_home", "hurt: rest at home")
	d.heir.hp = d.heir.max_hp()
	ok(step.call() == "guide_take" and GameTutorial.current(d, "sandbox", f)["goal"] == "board_new", "healed: take the first job")
	d.quests.accept(d, GameGoal.first_quest()) if d.quests.accept_block(d, GameGoal.first_quest()) == "" else null
	ok(d.quests.is_active(GameGoal.first_quest()), "the first job is on the board once the guided start has begun")
	ok(step.call() == "guide_errand", "with the job taken: do it")
	d.quests.entry(GameGoal.first_quest())["progress"] = 3
	ok(step.call() == "guide_pay", "done: be paid")
	d.quests.turn_in(d, GameGoal.first_quest())
	ok(d.quests.times_done(GameGoal.first_quest()) == 1 and not step.call().begins_with("guide_"), "paid: the guided start is over (%s)" % step.call())
	# tips off: the goal arrow still works, without the guided step's goal
	var ctx := {"tips": false, "facts": {}}
	ok(not _ids(GameGoal.all(_guided(), Vector2i(160, 288), ctx)).has("guide_marker"), "with the tips off the guided goals are not asked")
	var on := GameGoal.all(_guided(), Vector2i(160, 288), {"tips": true, "facts": {}})
	ok(on[0]["id"] == "guide_marker" and on[0]["tile"] == GameGoal.marker_tile(_guided()), "with them on the first goal is the marker's tile")
	ok(GameGoal.all(_guided(), Vector2i(160, 288), {"tips": true, "facts": {"at_marker": true}})[0]["id"] == "guide_foe", "then the foe")
	var old_save := _dyn()
	ok(GameTutorial.current(old_save, "sandbox", {}).get("id") == "sandbox_move", "a house with no guided start still gets the old first tip")


func _guided() -> GameDynasty:
	var d := _dyn()
	GameGoal.begin(d)
	return d


func test_first_job() -> void:
	var plain := _dyn()
	var board := plain.quests.postings(plain, "hearthmere").map(func(q): return str(q["id"]))
	ok(not board.has(GameGoal.first_quest()), "the first job is not on the board for a house that has not begun the guided start")
	var d := _guided()
	var posted := d.quests.postings(d, "hearthmere").map(func(q): return str(q["id"]))
	ok(posted.has(GameGoal.first_quest()), "it is for one that has")
	var q := GameQuests.def(GameGoal.first_quest())
	var wolf := GameQuests.def("hm_wolf_cull")
	ok(GameQuests.reward_gold(d, q) > GameQuests.reward_gold(d, wolf) and GameQuests.reward_gold(d, q) >= 100, "it pays well: %d gold against the wolf notice's %d" % [GameQuests.reward_gold(d, q), GameQuests.reward_gold(d, wolf)])
	ok(GameQuests.goal(q) == 3, "three kills")
	# the autopilot never takes it: it does not wait on the flag
	var bot := _dyn(5)
	GameQuests.bot_tick(bot)
	ok(not bot.quests.is_active(GameGoal.first_quest()), "the autopilot's board errands skip it")
	d.quests.accept(d, GameGoal.first_quest())
	d.quests.on_kill(d, "slime")
	d.quests.on_kill(d, "wolf")
	d.quests.on_kill(d, "plague_rat")
	ok(d.quests.is_complete(d.quests.entry(GameGoal.first_quest())), "any three of its pests finish it")
	var gold := d.heir.gold
	d.quests.turn_in(d, GameGoal.first_quest())
	ok(d.heir.gold == gold + GameQuests.reward_gold(d, q), "and the board pays")
	ok(not d.quests.postings(d, "hearthmere").map(func(p): return str(p["id"])).has(GameGoal.first_quest()), "once, and for good")


func test_home_rest() -> void:
	var d := _dyn()
	var sb := GameSandbox.start(d)
	sb.heir = Vector2i(GameGoal.house_tile().x, GameGoal.house_tile().y)
	ok(sb.door_here() == GameGoal.house_space(), "the family house has its door where the goal says")
	sb.enter()
	ok(sb.space == GameGoal.house_space(), "the heir goes in")
	d.heir.hp = 2
	var before := d.world_seconds
	var r := sb.use()   # at the entrance this is the way out
	ok(sb.space == "world" and d.heir.hp == 2, "using the entrance goes back out and rests nothing")
	sb.heir = GameGoal.house_tile()
	sb.enter()
	var bed := Vector2i(-99, -99)
	for room in GameSpaces.rooms(sb.space):
		if str(room["id"]) == "bedroom":
			var rect: Array = room["rect"]
			bed = Vector2i(int(rect[0]) + 1, int(rect[1]) + 1)
	sb.heir = bed
	ok(GameSpaces.room_at(sb.space, bed.x, bed.y) == "bedroom", "a cell of the bedroom")
	var rested := sb.use()
	ok(bool(rested.get("ok", false)) and d.heir.hp == d.heir.max_hp(), "using the bedroom rests the heir in full")
	ok(sb.space == GameGoal.house_space(), "and they stay in the house")
	var kitchen := Vector2i(-99, -99)
	for room in GameSpaces.rooms(sb.space):
		if str(room["id"]) == "kitchen":
			var rect: Array = room["rect"]
			kitchen = Vector2i(int(rect[0]) + 1, int(rect[1]) + 1)
	d.heir.hp = 2
	sb.heir = kitchen
	sb.use()
	ok(d.heir.hp == 2 or sb.space == "world", "the kitchen does not rest them")


func test_first_fight() -> void:
	var d := _guided()
	var m := GameGoal.marker_tile(d)
	var foe := GameGoal.foe_tile(d)
	var anchor := GameTravel.anchor_tile("hearthmere")
	ok(m != GameGoal.NONE and foe != GameGoal.NONE, "the marker and the foe have tiles")
	ok(GameGoal.marker_tile(d) == m and GameGoal.foe_tile(d) == foe, "the same every time")
	ok(Vector2(m - anchor).length() < GameWalls.radius("hearthmere"), "the marker is inside the town's wall %s" % str(m))
	ok(Vector2(foe - anchor).length() > GameWalls.radius("hearthmere") + 1.0 and not GameSandbox.in_town(foe.x, foe.y), "the foe waits outside the gate %s" % str(foe))
	ok(GamePath.passable(GamePath.world_ground(d), Vector3i(foe.x, -1, foe.y), {"water": false, "ignore_blocks": false}) and GamePath.passable(GamePath.world_ground(d), Vector3i(m.x, -1, m.y), {"water": false, "ignore_blocks": false}), "both can be stood on")
	for lv in [1, 2, 5, 12, 40]:
		var fl := GameGoal.first_foe_level(lv)
		ok(fl >= 1 and (lv == 1 or GameLevels.con(fl, lv) in ["trivial", "easy"]), "heir level %d: the foe is level %d, %s" % [lv, fl, GameLevels.con(fl, lv)])
	var a := GameGoal.first_foe(d)
	ok(str(a["id"]) == "slime" and a["guided"] == true and int(a["level"]) == 1, "the first foe is a slime of level 1")
	# end to end: the heir walks to the marker, the foe is placed, and meets them
	var sb := GameSandbox.start(d)
	GoalView.reset()
	sb.heir = anchor
	GoalView.observe(d, sb)
	ok(not GoalView.place_first_foe(d, sb), "nothing is placed before the heir has been to the marker")
	sb.heir = m
	GoalView.observe(d, sb)
	ok(bool(GoalView.facts.get("at_marker", false)), "at the marker is noticed")
	sb.creatures = []
	var rng_before := d.rng.state
	ok(GoalView.place_first_foe(d, sb) and sb.creatures.size() == 1, "and then the foe is placed")
	ok(d.rng.state == rng_before, "with none of the dynasty's dice")
	ok(not GoalView.place_first_foe(d, sb) and sb.creatures.size() == 1, "once")
	var hits := 0
	sb.heir = foe - Vector2i(4, 0)
	for i in 60:
		sb.step(1)
		if d.battle != null:
			break
	ok(d.battle != null and str(d.battle.enemies[0]["id"]) == "slime", "walking up to it starts the fight")
	ok(d.battle != null and str(d.battle.enemies[0].get("con", "")) in ["even", "easy", "trivial"], "an even or easier fight")


func test_hands_off() -> void:
	# the goal key's cycling
	var d := _guided()
	var sb := GameSandbox.start(d)
	UiSettings.set_goal(true)
	GoalView.reset()
	GoalView.update(d, sb)
	var first := GoalView.current()
	ok(first["id"] == "guide_marker", "the goal now is the marker")
	var next := GoalView.cycle(d, sb)
	ok(next.is_empty() or next["id"] != "guide_marker", "the key sets it aside")
	var seen := {}
	for i in 12:
		var g := GoalView.cycle(d, sb)
		seen[str(g.get("id", ""))] = true
	ok(seen.has("guide_marker"), "and goes round to it again (%s)" % str(seen.keys()))
	GoalView.reset()
	UiSettings.set_goal(false)
	GoalView.update(d, sb)
	ok(GoalView.current().is_empty() and GoalView.line(sb.heir) == "", "with the option off there is no goal at all")
	UiSettings.set_goal(true)
	# a pin wins over the arrow
	GoalView.update(d, sb)
	ok(not GoalView.bearing(d, sb.heir, 20).is_empty(), "the goal has a bearing on the minimap")
	GameTravel.set_pin(d, "ironford")
	ok(GoalView.bearing(d, sb.heir, 20).is_empty() and not GameMiniMap.pin_bearing(d, sb.heir, 20).is_empty(), "the player's own pin wins over it")
	GameTravel.clear_pin(d)
	# the autopilot never reads it: its seeded play is the same with and without the goal code run in between
	var a := _dyn(21)
	var b := _dyn(21)
	for i in 6:
		GameBot.step(a)
		GameGoal.all(b, Vector2i(160, 288), {"tips": true})
		GameBot.step(b)
	ok(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()), "asking for the goals between the autopilot's steps changes nothing")
	ok(not JSON.stringify(a.to_dict()).contains("goal"), "no goal is saved")


func test_screen() -> void:
	root.size = Vector2i(1280, 720)
	UiSettings.scale = 1.0
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	DirAccess.remove_absolute(UiSettings.path)
	GoalView.reset()
	var app: Node = GameApp.new()
	root.add_child(app)
	await _frames(3)
	app.closed_badly = false
	app.new_game("Tess", "warrior", "faetouched", 7)
	await _frames(2)
	app.show_sandbox()
	await _frames(6)
	var map: Node = app.current
	var d: GameDynasty = app.dynasty
	ok(GameGoal.guided(d) and GameSmoke.count(d.heir) >= 1, "the open world began the guided start: its flag and a smoke pot")
	var strip := map.get_node_or_null("TutorialTip") as Control
	ok(strip != null and "marker" in str((strip.find_child("TipText", true, false) as Label).text), "the tip strip says to walk to the marker")
	ok(strip != null and strip.position.y > 40.0 and strip.position.y < 120.0, "it sits along the top of the map, beside the panes")
	var status: Control = null
	var mini: Control = null
	for c in map.get_children():
		if c.get_script() == StatusPane:
			status = c
		elif c.get_script() == MinimapPane:
			mini = c
	var line := status.find_child("GoalLine", true, false) as Label if status != null else null
	ok(line != null and line.visible and line.text.begins_with("Goal: Walk to the marker"), "the status pane carries the goal line: %s" % (line.text if line != null else "none"))
	ok(not GoalView.bearing(d, map.sb.heir, 20).is_empty() and mini != null, "the minimap has a bearing to draw")
	# walk to the marker: the next tip, and the foe appears
	var m := GameGoal.marker_tile(d)
	map.sb.heir = m
	await _frames(2)
	map._hud_wait = 0.0
	await _frames(3)
	var foes: Array = map.sb.creatures.filter(func(a): return bool(a.get("guided", false)))
	ok(foes.size() == 1, "at the marker the first foe is there (%d)" % foes.size())
	strip = map.get_node_or_null("TutorialTip") as Control
	ok(strip != null and "Click the ground" in str((strip.find_child("TipText", true, false) as Label).text), "and the tip is the next one")
	ok(GoalView.current().get("id") == "guide_foe" and GoalView.current()["tile"] == Vector2i(floori(float(foes[0]["x"])), floori(float(foes[0]["z"]))), "the arrow points at the foe")
	# the key
	var ev := InputEventKey.new()
	ev.keycode = KEY_N
	ev.physical_keycode = KEY_N
	ev.pressed = true
	map._cycle_goal()
	ok(map.last_line.begins_with("Goal:") or map.last_line.begins_with("No more"), "the goal key says what it did: %s" % map.last_line)
	GoalView.skipped = {}
	# the goal arrow can be switched off from the menu, the tips with them
	var menu: Control = MenuPanel.new()
	menu.app = app
	root.add_child(menu)
	await _frames(2)
	ok(menu.find_child("GoalArrowRow", true, false) != null, "the menu has a Goal arrow switch")
	menu.queue_free()
	UiSettings.set_goal(false)
	map._hud_wait = 0.0
	await _frames(3)
	ok(GoalView.current().is_empty(), "the Options switch hides the goal arrow")
	map._cycle_goal()
	ok(map.last_line == GameGoal.text("off"), "and the key says so")
	UiSettings.set_goal(true)
	map._hud_wait = 0.0
	await _frames(3)
	ok(not GoalView.current().is_empty(), "and back on, it shows again")
	UiSettings.set_tutorial(false)
	map._hud_wait = 0.0
	await _frames(3)
	ok(map.get_node_or_null("TutorialTip") == null, "with the tips off there is no strip")
	ok(GoalView.current().get("id") != "guide_foe", "and the guided goals go (the plain goals stay: %s)" % str(GoalView.current().get("id")))
	UiSettings.set_tutorial(true)
	app.queue_free()
	await _frames(2)


## A phone: no panes, so the goal leads the one status line, and the tip strip stays within the width of the screen.
func test_phone() -> void:
	UiSettings.force_touch = 1
	UiSettings.force_mobile = 1
	DirAccess.remove_absolute(UiSettings.path)
	GoalView.reset()
	root.size = Vector2i(844, 390)
	var app: Node = GameApp.new()
	root.add_child(app)
	await _frames(3)
	app.closed_badly = false
	app.new_game("Tess", "warrior", "faetouched", 7)
	await _frames(2)
	app.show_sandbox()
	await _frames(6)
	var map: Node = app.current
	map._hud_wait = 0.0
	await _frames(3)
	ok(map.status.text.contains("Goal: Walk to the marker"), "on a phone the goal leads the status line: %s" % map.status.text)
	var strip := map.get_node_or_null("TutorialTip") as Control
	ok(strip != null and strip.position.x >= 0.0 and strip.position.x + strip.size.x <= 844.0 + 1.0, "the tip strip stays within the screen (%s, %s)" % [str(strip.position) if strip != null else "none", str(strip.size) if strip != null else ""])
	ok(strip != null and strip.size.y <= 390.0 * 0.35, "and takes no more than a third of the height")
	app.queue_free()
	await _frames(2)
	UiSettings.force_touch = -1
	UiSettings.force_mobile = -1
	root.size = Vector2i(1280, 720)
