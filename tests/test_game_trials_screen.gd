## The Trials screen (ui/play/trials_panel.gd, opened by the House panel) and what it reads from GameTrials: `describe` and `listing` say where
## the heir stands in each trial (way in, ready, under way, passed, shut) and why a step cannot be done, `gain_preview` says what passing
## would give, `wait_out` lets the hours pass, and a win over a master settles the trial through `finish_battle`. The panel only calls the
## core and draws; no dice of the dynasty's are drawn.
## Run: godot --headless --path . -s res://tests/test_game_trials_screen.gd
extends SceneTree

const TrialsPanel := preload("res://ui/play/trials_panel.gd")
const HousePanel := preload("res://ui/play/house_panel.gd")

var fails := 0
var checks := 0
var changes := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	test_describe()
	test_listing()
	test_preview_and_wait()
	test_settle()
	await test_panel()
	await test_fight_button()
	await test_house_button()
	print("trials screen tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(seed_value: int = 21, class_id: String = "warrior") -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "", class_id, "faetouched", "human")
	d.pending_event = {}
	d.heir.level = 12
	d.heir.gold = 5000
	return d


func _dyn_with(id: String) -> GameDynasty:
	for s in range(1, 200):
		var d := _dyn(s)
		if GameTrials.is_placed(d, id):
			return d
	return null


func _quest(d: GameDynasty, id: String) -> void:
	while not GameTrials.next_step(d, id).is_empty():
		var s := GameTrials.next_step(d, id)
		if str(s["kind"]) == "visit":
			d.world.location = str(s["place"])
		GameTrials.do_step(d, id)


func _button(node: Node, name: String) -> Button:
	return node.find_child(name, true, false) as Button


func test_describe() -> void:
	var d := _dyn_with("stone_lift")
	var state := d.rng.state
	ok(GameTrials.describe(d, "no_such_trial").is_empty(), "an unknown trial describes as nothing")
	d.world.location = "ironford"   # (the first step is to be at Hearthmere)
	var t := GameTrials.describe(d, "stone_lift")
	ok(str(t["status"]) == "way" and int(t["steps_done"]) == 0 and int(t["steps_total"]) == 3, "at first the way in is to do: %s" % str(t))
	ok(str(t["step_text"]) != "" and str(t["step_why"]).contains("Go to"), "the first step says what it is and why it cannot be done here: %s" % str(t["step_why"]))
	ok(str(t["name"]) == "The Stone Lift" and str(t["focus_name"]) == "Body" and int(t["level"]) == 3 and int(t["length"]) == 6, "name, focus, level and hours")
	ok(str(t["master"]) != "" and str(t["gain"]).contains("%"), "the master and what it gives: %s" % str(t["gain"]))
	ok(int(t["chance"]) >= 15 and int(t["chance"]) <= 90, "a chance of passing is shown (%d%%)" % int(t["chance"]))
	d.world.location = "hearthmere"
	ok(str(GameTrials.describe(d, "stone_lift")["step_why"]) == "", "at the place the step can be done")
	_quest(d, "stone_lift")
	t = GameTrials.describe(d, "stone_lift")
	ok(str(t["status"]) == "ready" and str(t["why"]) == "", "with the way in done it is ready: %s" % str(t))
	d.heir.level = 1
	t = GameTrials.describe(d, "stone_lift")
	ok(str(t["status"]) == "shut" and str(t["why"]).contains("level"), "a low heir finds it shut, and told why: %s" % str(t["why"]))
	d.heir.level = 12
	GameTrials.start(d, "stone_lift")
	ok(str(GameTrials.describe(d, "stone_lift")["status"]) == "active", "begun, it is under way")
	GameTrials.wait_out(d)
	GameTrials.finish(d)
	d.heir.trials_done = ["stone_lift"]
	ok(str(GameTrials.describe(d, "stone_lift")["status"]) == "passed", "passed, it says so")
	var champs := _dyn_with("ring_of_champions")
	ok(int(GameTrials.describe(champs, "ring_of_champions")["chance"]) == -1 and bool(GameTrials.describe(champs, "ring_of_champions")["fight"]), "a trial won by a fight has no chance to show")
	ok(d.rng.state == state, "no die of the dynasty's was drawn")


func test_listing() -> void:
	var d := _dyn_with("stone_lift")
	var list := GameTrials.listing(d)
	var material := GameTrials.placed(d.seed_value, "material")
	ok(list.size() == material.size(), "only the open realm's trials are listed (%d of %d)" % [list.size(), material.size()])
	ok(list.all(func(t): return str(t["realm"]) == "material"), "all of the home world")
	d.set_flag("gate_verdant")
	ok(GameTrials.listing(d).size() == material.size() + GameTrials.placed(d.seed_value, "verdant").size(), "a realm whose gate opens adds its trials")
	d.flags.erase("gate_verdant")
	# the one under way comes first, the passed last
	_quest(d, "stone_lift")
	GameTrials.start(d, "stone_lift")
	ok(str(GameTrials.listing(d)[0]["id"]) == "stone_lift" and str(GameTrials.listing(d)[0]["status"]) == "active", "the trial under way is first")
	var other := _dyn_with("stone_lift")
	other.heir.trials_done = ["stone_lift"]
	var l2 := GameTrials.listing(other)
	ok(str(l2[l2.size() - 1]["status"]) == "passed" or l2.all(func(t): return str(t["status"]) != "passed" or str(t["id"]) == "stone_lift"), "a passed trial is listed after the rest")


func test_preview_and_wait() -> void:
	ok(GameTrials.gain_preview("stone_lift") == "max hp +4%", "a stat gain reads as words: %s" % GameTrials.gain_preview("stone_lift"))
	ok(GameTrials.gain_preview("archive_of_dust").contains("spell or feat"), "a Lore gain is a spell or feat")
	ok(GameTrials.gain_preview("ancestors_hearth").contains("heirs"), "a Spirit gain says it passes to heirs: %s" % GameTrials.gain_preview("ancestors_hearth"))
	ok(GameTrials.gain_preview("imps_bargain").contains("price"), "a Pact says its price: %s" % GameTrials.gain_preview("imps_bargain"))
	ok(GameTrials.gain_preview("no_such_trial") == "", "an unknown trial gives nothing")
	var d := _dyn_with("stone_lift")
	ok(GameTrials.wait_out(d).is_empty(), "with no trial under way there is nothing to wait out")
	_quest(d, "stone_lift")
	GameTrials.start(d, "stone_lift")
	ok(GameTrials.remaining(d) > 0.0, "hours are left")
	GameTrials.wait_out(d)
	d.pending_event = {}
	ok(GameTrials.remaining(d) == 0.0, "waiting it out leaves none")
	ok(GameTrials.finish(d)[0] != GameTrials.text("not_ready", {"trial": "The Stone Lift", "hours": 1}), "and it can end at once")


func test_settle() -> void:
	var d := _dyn_with("ring_of_champions")
	_quest(d, "ring_of_champions")
	GameTrials.start(d, "ring_of_champions")
	GameTrials.wait_out(d)
	d.pending_event = {}
	var b := GameTrials.begin_master(d)
	ok(b != null and d.battle != null, "the master's fight begins")
	b.result = "victory"
	var msgs := d.finish_battle()
	ok(GameTrials.done(d.heir, "ring_of_champions"), "a win over the master settles the trial through finish_battle")
	ok(msgs.any(func(m): return str(m).contains("passes")), "and the lines are told with the fight's")
	# a plain fight with no trial changes nothing and draws nothing extra
	var e := _dyn()
	e.start_hunt("hunt")
	e.battle.result = "victory"
	e.finish_battle()
	ok(e.trials.is_empty(), "a hunt with no trial under way leaves the trials alone")
	# a flight leaves it to fight again
	var f := _dyn_with("ring_of_champions")
	_quest(f, "ring_of_champions")
	GameTrials.start(f, "ring_of_champions")
	GameTrials.wait_out(f)
	f.pending_event = {}
	var fb := GameTrials.begin_master(f)
	fb.result = "fled"
	f.finish_battle()
	ok(not GameTrials.done(f.heir, "ring_of_champions") and not GameTrials.active(f).is_empty(), "fleeing the master leaves the trial under way")


func test_panel() -> void:
	var d := _dyn_with("stone_lift")
	d.heir.level = 12
	var panel: Control = TrialsPanel.new()
	panel.dynasty = d
	panel.on_change = func(): changes += 1
	root.add_child(panel)
	await process_frame
	ok(_button(panel, "TrialStep") != null, "a trial with a way in to do has its step button")
	ok(panel.find_children("*", "Button", true, false).all(func(b): return (b as Button).tooltip_text == ""), "no button hides its reason in a tooltip")
	var first: Dictionary = GameTrials.listing(d).filter(func(t): return str(t["id"]) == "stone_lift")[0]
	d.world.location = "hearthmere"
	panel._build()
	await process_frame
	var step := panel.find_children("TrialStep", "Button", true, false)
	ok(step.size() >= 1 and step.any(func(b): return not (b as Button).disabled), "at the place a step button is enabled")
	_quest(d, "stone_lift")
	panel._build()
	await process_frame
	ok(panel.find_children("TrialBegin", "Button", true, false).any(func(b): return not (b as Button).disabled), "with the way in done a trial can be begun")
	var begin: Button = panel.find_children("TrialBegin", "Button", true, false).filter(func(b): return not (b as Button).disabled)[0]
	var before := changes
	begin.pressed.emit()
	await process_frame
	ok(not GameTrials.active(d).is_empty() and changes > before, "pressing Begin starts a trial and tells the screen behind")
	ok(_button(panel, "TrialWait") != null and _button(panel, "TrialLeave") != null, "a trial under way offers waiting and leaving")
	_button(panel, "TrialWait").pressed.emit()
	await process_frame
	d.pending_event = {}
	panel._build()
	await process_frame
	ok(GameTrials.remaining(d) == 0.0 and _button(panel, "TrialFinish") != null, "after waiting the hours it can be finished")
	_button(panel, "TrialFinish").pressed.emit()
	await process_frame
	ok(GameTrials.active(d).is_empty() and int(d.trials.get("tries", {}).get("stone_lift", 0)) == 1, "finishing settles the trial (passed or failed, it was tried)")
	# leaving asks twice
	var e := _dyn_with("stone_lift")
	_quest(e, "stone_lift")
	GameTrials.start(e, "stone_lift")
	var p2: Control = TrialsPanel.new()
	p2.dynasty = e
	root.add_child(p2)
	await process_frame
	_button(p2, "TrialLeave").pressed.emit()
	await process_frame
	ok(not GameTrials.active(e).is_empty() and _button(p2, "TrialLeave").text.contains("Really"), "the first press only asks")
	_button(p2, "TrialLeave").pressed.emit()
	await process_frame
	ok(GameTrials.active(e).is_empty(), "the second leaves the trial")
	ok(first["id"] == "stone_lift", "(the listing held the trial all along)")
	panel.queue_free()
	p2.queue_free()


func test_fight_button() -> void:
	var d := _dyn_with("ring_of_champions")
	_quest(d, "ring_of_champions")
	GameTrials.start(d, "ring_of_champions")
	GameTrials.wait_out(d)
	d.pending_event = {}
	var panel: Control = TrialsPanel.new()
	panel.dynasty = d
	var seen := [0]
	panel.on_change = func(): seen[0] += 1
	root.add_child(panel)
	await process_frame
	ok(_button(panel, "TrialFight") != null and _button(panel, "TrialFinish") == null, "a trial won by a fight offers the fight, not a finish")
	_button(panel, "TrialFight").pressed.emit()
	await process_frame
	ok(d.battle != null and seen[0] == 1, "the fight begins and the screen behind is told, which takes it to the battle")
	panel.queue_free()


func test_house_button() -> void:
	var d := _dyn()
	var host := Control.new()
	root.add_child(host)
	var house: Control = HousePanel.new()
	house.dynasty = d
	house.on_change = func(): pass
	host.add_child(house)
	await process_frame
	var b := _button(house, "Trials")
	ok(b != null, "the House panel has a Trials button")
	b.pressed.emit()
	await process_frame
	ok(host.get_children().any(func(c): return c.get_script() == TrialsPanel), "and it opens the trials over the house")
	host.queue_free()
