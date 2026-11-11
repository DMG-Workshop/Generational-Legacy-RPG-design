## Achievements and dynasty milestones (roadmap item 16): the data and the ways to break it; every count; reaching
## (once, kept for good, with who and when, told in the journal); progress; the titles a milestone awards (through
## GameTitles' `achievement` condition, in the same pass); saving, old saves and damaged values; that the autopilot
## reaches nothing and no die is drawn; and the Chronicle's Milestones tab.
## Run: godot --headless --path . -s res://tests/test_game_achievements.gd
extends SceneTree

const DIR := "user://test_achievements/"
const ChroniclePanel := preload("res://ui/play/chronicle_panel.gd")
const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")

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
	test_counts()
	test_reaching()
	test_progress()
	test_titles()
	test_saving()
	test_autopilot()
	await test_screen()
	print("achievements tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func dyn(seed_value: int = 5) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


func _broken(edit: Callable, word: String) -> bool:
	var saved: Dictionary = GameAchievements.data().duplicate(true)
	var titles: Dictionary = GameData.titles.duplicate(true)
	edit.call(GameAchievements.data())
	var found := GameAchievements.validate()
	GameAchievements._cache = saved
	GameData.titles = titles
	return found.any(func(p): return word in str(p))


func _a(x: Dictionary, id: String) -> Dictionary:
	for a in x["achievements"]:
		if a["id"] == id:
			return a
	return {}


func test_data() -> void:
	ok(GameAchievements.validate().is_empty(), "the milestones are sound: %s" % str(GameAchievements.validate()))
	ok(GameTitles.validate().is_empty(), "and so are the titles they award: %s" % str(GameTitles.validate()))
	ok(GameAchievements.defs().size() >= 20, "there are many milestones (%d)" % GameAchievements.defs().size())
	for c in GameAchievements.COUNTS:
		ok(GameAchievements.defs().any(func(a): return a["count"] == c), "something counts %s" % c)
	ok(_broken(func(x): _a(x, "line_5")["count"] = "luck", "not something the house counts"), "an unknown count is refused")
	ok(_broken(func(x): _a(x, "line_5")["goal"] = 0, "goal above 0"), "a goal of nothing is refused")
	ok(_broken(func(x): _a(x, "line_5")["goal"] = "many", "goal above 0"), "a goal that is no number is refused")
	ok(_broken(func(x): _a(x, "line_5")["name"] = " ", "needs name"), "a milestone with no name is refused")
	ok(_broken(func(x): x["achievements"].append(_a(x, "line_5").duplicate()), "listed twice"), "a milestone listed twice is refused")
	ok(_broken(func(x): _a(x, "line_25")["goal"] = 5, "same milestone"), "two milestones that are one are refused")
	ok(_broken(func(x): _a(x, "house_full")["goal_from"] = "the sky", "cannot be taken from"), "a goal from nowhere is refused")
	ok(_broken(func(x): _a(x, "line_5")["title"] = "nonesuch", "does not exist"), "a title that does not exist is refused")
	ok(_broken(func(x): _a(x, "line_5")["title"] = "house_ten", "must be a house title earned by"), "a title earned another way is refused")
	ok(_broken(func(x): _a(x, "years_1000").erase("title"), "does not award it"), "a title waiting on a milestone that does not award it is refused")
	ok(_broken(func(x): _a(x, "milestones_12")["goal"] = 500, "more milestones than there are"), "a milestone no house could reach is refused")
	ok(_broken(func(x): x["text"].erase("reached"), "text 'reached'"), "missing text is refused")
	var saved: Dictionary = GameData.titles.duplicate(true)
	GameData.titles["titles"].append({"id": "bad", "name": "x", "kind": "house", "about": "x", "when": {"achievement": "nonesuch"}})
	ok(GameTitles.validate().any(func(p): return "no milestone called" in p), "a title waiting on a milestone that does not exist is refused")
	GameData.titles = saved


func test_counts() -> void:
	var d := dyn()
	ok(GameAchievements.count(d, "generations") == 1.0 and GameAchievements.count(d, "heirs") == 1.0, "a new house: one generation, one heir")
	d.gen = 7
	d.world.year = 61.5
	d.slain_bosses = {"grimfang": 2, "vaerthax": 6}
	d.house = {"hall": 2, "yard": 1, "ranch": 3}
	d.roster = [{"id": 1, "species": "wolf"}, {"id": 2, "species": "wolf", "bred": true}]
	d.stores = {"crafted": 4}
	d.built = {"1,-1,1": "wall", "2,-1,1": "wall"}
	d.heirlooms = [{"name": "a"}]
	d.house_titles = ["house_ten"]
	d.heir.titles = ["blooded", "veteran"]
	d.heir.gold = 321
	d.achievements = {"line_5": {"gen": 5, "year": 40, "heir": "x"}}
	var want := {"generations": 7.0, "years": 61.5, "legends": 2.0, "house": 6.0, "creatures": 2.0, "bred": 1.0, "crafted": 4.0,
		"built": 2.0, "heirlooms": 1.0, "titles": 3.0, "gold": 321.0, "milestones": 1.0}
	for k in want:
		ok(GameAchievements.count(d, k) == want[k], "%s counts %s (%s)" % [k, str(want[k]), str(GameAchievements.count(d, k))])
	ok(GameAchievements.count(d, "ages") == float(d.age_number()), "ages is the Age the world is in")
	ok(GameAchievements.count(d, "legend_kills") == float(GameStats.summary(d)["legends"]), "legend kills are the statistics' own")
	ok(GameAchievements.count(d, "nonsense") == 0.0, "an unknown count is 0")
	d.stores = {"crafted": "lots"}
	ok(GameAchievements.count(d, "crafted") == 0.0, "a damaged count is 0")
	ok(GameAchievements.goal(GameAchievements.def("house_full")) == float(GameHouse.max_level() * 3), "the whole house is every level of every track")


func test_reaching() -> void:
	var d := dyn()
	var before := d.rng.state
	ok(GameAchievements.update(d).is_empty() and d.achievements.is_empty(), "a new house has reached nothing")
	d.gen = 5
	d.world.year = 52.9
	var journal := d.journal.size()
	var got := GameAchievements.announce(d)
	ok(got == ["line_5", "years_50"], "the fifth generation and fifty years are reached, in the data's order: %s" % str(got))
	ok(d.achievements["line_5"] == {"gen": 5, "year": 52, "heir": d.heir.name}, "with the generation, the year and the heir: %s" % str(d.achievements["line_5"]))
	ok(d.journal.size() == journal + 2 and "The house reaches a milestone: A Line of Five." in d.journal, "and each is told in the journal")
	ok(GameAchievements.announce(d).is_empty() and d.journal.size() == journal + 2, "once only")
	d.world.year = 3.0
	d.gen = 1
	ok(GameAchievements.reached(d, "years_50") and GameAchievements.update(d).is_empty(), "a milestone reached is kept though the count falls")
	ok(d.rng.state == before, "and no die is drawn")
	var dead := dyn()
	dead.gen = 30
	dead.state = "dead"
	ok(GameAchievements.update(dead).is_empty(), "a house with no living heir reaches nothing")
	# the milestone that counts milestones
	var m := dyn()
	m.gen = 80
	m.world.year = 1200.0
	m.heir.gold = 2000000
	m.house = {"hall": 3, "yard": 3, "ranch": 3}
	m.heirlooms = [1, 2, 3, 4, 5]
	m.stores = {"crafted": 30}
	var first := GameAchievements.update(m)
	ok(first.size() >= 13 and first[-1] == "milestones_12", "a great house reaches a dozen at once, and the milestone that counts them, listed last, with them (%d)" % first.size())
	ok(GameAchievements.update(m).is_empty(), "and nothing more on the next look")
	# every milestone can be reached
	var all := dyn()
	all.gen = 2300
	all.world.year = 2000.0
	all.heir.gold = 2000000
	all.house = {"hall": 3, "yard": 3, "ranch": 3}
	all.heirlooms = [1, 2, 3, 4, 5]
	all.stores = {"crafted": 30}
	for c in GameData.creatures:
		if c.get("boss", false):
			all.slain_bosses[str(c["id"])] = 3
	all.ages.summaries = [{"age": 1, "heirs": 60, "legends": [{"id": "grimfang", "times": 12}], "causes": {}}]
	for i in 6:
		all.roster.append({"id": i, "species": "wolf", "bred": true})
	for i in 25:
		all.built["%d,-1,0" % i] = "wall"
	all.heir.titles = GameTitles.defs().filter(func(t): return t["kind"] == "personal").map(func(t): return t["id"])
	GameAchievements.update(all)
	var missing: Array = GameAchievements.defs().filter(func(a): return not all.achievements.has(a["id"])).map(func(a): return a["id"])
	ok(missing.is_empty(), "every milestone can be reached; left: %s" % str(missing))


func test_progress() -> void:
	var d := dyn()
	d.gen = 3
	var p := GameAchievements.progress(d, "line_5")
	ok(p["have"] == 3.0 and p["goal"] == 5.0 and is_equal_approx(p["share"], 0.6) and not p["done"], "three generations of five: %s" % str(p))
	ok(GameAchievements.describe(d, "line_5")["line"] == "3 of 5", "and the screen's line says so: %s" % GameAchievements.describe(d, "line_5")["line"])
	d.gen = 9
	ok(GameAchievements.progress(d, "line_5")["share"] == 1.0 and not GameAchievements.progress(d, "line_5")["done"], "past the goal but not yet looked at: full, not done")
	ok(GameAchievements.describe(d, "line_5")["line"] == "5 of 5", "the line never shows more than the goal")
	GameAchievements.update(d)
	var m := GameAchievements.describe(d, "line_5")
	ok(m["done"] and m["line"] == "Reached by %s, generation 9, year 0." % d.heir.name, "reached, it says who and when: %s" % m["line"])
	ok(not GameAchievements.progress(d, "nonesuch")["done"] and GameAchievements.progress(d, "nonesuch")["goal"] == 0.0, "an unknown milestone is nothing")


func test_titles() -> void:
	var d := dyn()
	ok(not GameTitles.met(d, {"achievement": "years_1000"}), "the title waits for its milestone")
	d.world.year = 1000.0
	var journal := d.journal.size()
	var got := GameTitles.announce(d)
	ok("house_millennial" in got and "house_millennial" in d.house_titles, "a thousand years brings the Millennial House in the same pass: %s" % str(got))
	var told: Array = d.journal.slice(journal)
	var at_m := told.find("The house reaches a milestone: A Thousand Years.")
	var at_t := told.find("%s earns a title: the Millennial House." % d.heir.name)
	ok(at_m >= 0 and at_t > at_m, "the milestone is told, then the title")
	ok(GameTitles.wear(d, "house_millennial") and GameTitles.perk(d, "persuasion") == 0.02, "and worn, it helps in the shops")
	d.world.year = 1.0
	var heir := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok("house_millennial" in heir.house_titles and heir.achievements.has("years_1000"), "both stay with the house")
	for a in GameAchievements.defs():
		if a.has("title"):
			var x := dyn()
			x.achievements[str(a["id"])] = {"gen": 1, "year": 0, "heir": "x"}
			ok(str(a["title"]) in GameTitles.update(x), "%s awards %s" % [a["id"], a["title"]])


func test_saving() -> void:
	var d := dyn()
	ok(not d.to_dict().has("achievements"), "a house that has reached nothing saves nothing of it")
	d.gen = 5
	d.world.year = 60.0
	GameAchievements.update(d)
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(back.achievements == d.achievements and back.achievements.keys() == d.achievements.keys(), "what is reached survives a save and load")
	var old: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	old.erase("achievements")
	ok(GameDynasty.from_dict(old).achievements.is_empty(), "a save from before milestones loads with none")
	for junk in ["x", 4, [1, 2], null]:
		var bad: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
		bad["achievements"] = junk
		ok(GameDynasty.from_dict(bad).achievements.is_empty(), "milestones saved as %s load as none" % str(junk))
	var odd: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	odd["achievements"] = {"nonesuch": {"gen": 1, "year": 1, "heir": "x"}, "line_5": "yes", "years_50": {"gen": "old", "year": -9, "heir": 7},
		"line_25": {"gen": 3.0, "year": 12.0, "heir": "Ann"}}
	var got := GameDynasty.from_dict(odd).achievements
	ok(got.keys() == ["line_25", "years_50"], "unknown ids and records that are no record are dropped, the rest in the data's order: %s" % str(got.keys()))
	ok(got["years_50"] == {"gen": 1, "year": 0, "heir": ""} and got["line_25"] == {"gen": 3, "year": 12, "heir": "Ann"}, "and damaged fields fall back: %s" % str(got))


func test_autopilot() -> void:
	var a := GameDynasty.new_game(31, "Auto", "warrior", "noble", "human")
	for i in 20000:
		if a.state == "dead" or a.gen > 6:
			break
		_bot(a)
	ok(a.gen > 5, "the autopilot plays five generations (%d)" % a.gen)
	ok(a.achievements.is_empty() and not a.to_dict().has("achievements"), "and reaches no milestone: only a screen asks")
	var x := GameDynasty.new_game(31, "Auto", "warrior", "noble", "human")
	var y := GameDynasty.new_game(31, "Auto", "warrior", "noble", "human")
	for i in 2500:
		_bot(x)
		_bot(y)
		GameTitles.announce(y)
	ok(not y.achievements.is_empty() or y.gen < 5, "(the asking house did reach something: %s)" % str(y.achievements.keys()))
	var yd := y.to_dict()
	var xd := x.to_dict()
	for k in ["achievements", "house_titles", "journal"]:
		yd.erase(k)
		xd.erase(k)
	for dd in [xd, yd]:
		dd["heir"].erase("titles")
		for rec in dd.get("history", []):
			rec.erase("titles")
	ok(x.rng.state == y.rng.state and JSON.stringify(xd) == JSON.stringify(yd), "a house whose screens ask lives exactly the life of one whose screens do not, but for what it is told and awarded")


func _bot(d: GameDynasty) -> void:
	if d.state == "succession":
		GameBot.choose_best(d)
	else:
		GameBot.step(d)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _texts(n: Node, out: Array) -> void:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_texts(c, out)


func _find(n: Node, name: String) -> Node:
	if str(n.name) == name:
		return n
	for c in n.get_children():
		var f := _find(c, name)
		if f != null:
			return f
	return null


func test_screen() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	GameSaves.base = DIR + "save.json"
	GameDynasty.save_path = GameSaves.base
	UiSettings.path = DIR + "settings.cfg"
	UiSettings.scale = 1.0
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	root.size = Vector2i(1280, 720)
	await _frames(2)
	var app := GameApp.new()
	root.add_child(app)
	await _frames(3)
	app.new_game("Tess", "warrior", "faetouched", 77, "human")
	var d: GameDynasty = app.dynasty
	d.pending_event = {}
	d.gen = 5
	app.show_state()
	await _frames(3)
	ok(d.achievements.has("line_5") and "The house reaches a milestone: A Line of Five." in d.journal, "showing the life screen reaches and tells a milestone")
	var c := ChroniclePanel.new()
	c.dynasty = d
	c.on_change = func(): pass
	app.current.add_child(c)
	await _frames(3)
	var tab := _find(c, "Milestones")
	ok(tab != null, "the Chronicle has a Milestones tab")
	var texts: Array = []
	if tab != null:
		_texts(tab, texts)
	ok(texts.has("Reached (1 of %d)" % GameAchievements.defs().size()) and texts.has("Still ahead (%d)" % (GameAchievements.defs().size() - 1)), "it counts what is reached and what is ahead: %s" % str(texts.slice(0, 3)))
	ok(texts.any(func(t): return "Reached by Tess, generation 5" in t), "says who reached A Line of Five and when")
	ok(texts.any(func(t): return t.ends_with("5 of 25")), "and how far along the next is")
	ok(texts.has("A Thousand Years  (title: the Millennial House)"), "and names the title a milestone brings")
	for a in GameAchievements.defs():
		ok(texts.any(func(t): return t.begins_with(str(a["name"]))), "%s is listed" % a["id"])
	app.queue_free()
	await _frames(2)
