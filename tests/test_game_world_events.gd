## Random world events (roadmap item 19): the data and the ways to break it; that with no event running every
## number is exactly what it was; each effect where the rules read it (shop, potion, temple and cure prices, what a
## won fight and work pay, how easily sickness takes hold); beginning, lasting, ending and the rest between; the
## grace years and the windows; that the dice are keyed on the seed and the year and the dynasty's own are not
## drawn; how often events come over a long run; saving, old saves and damaged values; and the life screen's line.
## Run: godot --headless --path . -s res://tests/test_game_world_events.gd
extends SceneTree

const DIR := "user://test_world_events/"
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
	test_quiet()
	test_effects()
	test_course()
	test_rolls()
	test_dice()
	test_saving()
	await test_screen()
	print("world events tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func dyn(seed_value: int = 5) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


func _broken(edit: Callable, word: String) -> bool:
	var saved: Dictionary = GameWorldEvents.data().duplicate(true)
	edit.call(GameWorldEvents.data())
	var found := GameWorldEvents.validate()
	GameWorldEvents._cache = saved
	return found.any(func(p): return word in str(p))


func _with(edit: Callable, body: Callable) -> void:
	var saved: Dictionary = GameWorldEvents.data().duplicate(true)
	edit.call(GameWorldEvents.data())
	body.call()
	GameWorldEvents._cache = saved


func test_data() -> void:
	ok(GameWorldEvents.validate().is_empty(), "the world events are sound: %s" % str(GameWorldEvents.validate()))
	ok(GameWorldEvents.ids().size() == 5, "five kinds of event")
	for k in GameWorldEvents.EFFECTS:
		ok(GameWorldEvents.ids().any(func(id): return GameWorldEvents.event(id)["effects"].has(k)), "some event changes %s" % k)
	var war := func(x): return x["events"]["war"]
	ok(_broken(func(x): war.call(x)["effects"]["luck_mult"] = 2.0, "which nothing reads"), "an effect nothing reads is refused")
	ok(_broken(func(x): war.call(x)["effects"]["price_mult"] = 9.0, "between 0.25 and 4"), "a wild effect is refused")
	ok(_broken(func(x): war.call(x)["effects"]["price_mult"] = 1.0, "and not 1"), "an effect that changes nothing is refused")
	ok(_broken(func(x): war.call(x)["effects"] = {}, "changes nothing"), "an event with no effect is refused")
	ok(_broken(func(x): war.call(x)["years"] = [4, 2], "years must be"), "years the wrong way round are refused")
	ok(_broken(func(x): war.call(x)["years"] = [0, 2], "years must be"), "an event of no length is refused")
	ok(_broken(func(x): war.call(x)["weight"] = 0, "weight above 0"), "an event that can never be picked is refused")
	ok(_broken(func(x): war.call(x)["begins"] = "", "needs begins"), "an event that begins in silence is refused")
	ok(_broken(func(x): war.call(x)["min_gen"] = 9; war.call(x)["max_gen"] = 3, "ends before it begins"), "a window that ends before it begins is refused")
	ok(_broken(func(x):
		for id in x["events"]:
			x["events"][id]["min_gen"] = 2, "none can begin in every generation"), "a generation with no event to pick is refused")
	ok(_broken(func(x): x["settings"]["chance_per_year"] = 0.9, "chance_per_year"), "events every year are refused")
	ok(_broken(func(x): x["settings"]["rest_years"] = 0, "must rest"), "no rest between events is refused")
	ok(_broken(func(x): x["text"].erase("now"), "text 'now'"), "missing text is refused")


func test_quiet() -> void:
	var d := dyn()
	ok(GameWorldEvents.active(d) == "" and d.world_event.is_empty(), "a new house's world is quiet")
	for k in GameWorldEvents.EFFECTS:
		ok(GameWorldEvents.mult(d, k) == 1.0, "%s is 1 with no event" % k)
	ok(GameWorldEvents.describe(d) == "The world is at peace.", "and the screens say so")
	ok(not d.to_dict().has("world_event"), "and nothing of it is saved")
	d.world_event = {"id": "", "until": 30}
	ok(GameWorldEvents.active(d) == "" and GameWorldEvents.mult(d, "price_mult") == 1.0, "the rest after an event changes nothing")
	d.world_event = {"id": "nonesuch", "until": 30}
	ok(GameWorldEvents.active(d) == "" and GameWorldEvents.mult(d, "price_mult") == 1.0, "an event the game does not know changes nothing")


func test_effects() -> void:
	var d := dyn()
	d.world.location = "hearthmere"
	var price_mult := GameItems.price_mult(d)
	var potion := d.potion_price()
	GameWorldEvents.begin(d, "famine", 20)
	ok(is_equal_approx(GameItems.price_mult(d), price_mult * 1.5), "a famine puts shop prices up by half")
	ok(absi(d.potion_price() - int(round(potion * 1.5))) <= 1, "and potions with them: %d against %d" % [d.potion_price(), potion])
	ok(GameWorldEvents.mult(d, "disease_mult") == 1.5 and GameWorldEvents.mult(d, "work_gold_mult") == 0.8 and GameWorldEvents.mult(d, "hunt_gold_mult") == 1.0, "it also touches sickness and work, and not what fights pay")
	# work pays less in a famine: the same dice, a smaller purse
	var a := dyn(9)
	var b := dyn(9)
	GameWorldEvents.begin(b, "famine", 20)
	b.journal = a.journal.duplicate()
	var ga := a.heir.gold
	var gb := b.heir.gold
	a.work()
	b.work()
	var earned_a := a.heir.gold - ga
	var earned_b := b.heir.gold - gb
	ok(earned_b < earned_a and absi(earned_b - int(round(earned_a * 0.8))) <= 1, "work pays a fifth less in a famine: %d against %d" % [earned_b, earned_a])
	# a won fight pays more gold in a war and more XP in a golden age
	var pay := func(event_id: String) -> Array:
		var x := dyn(12)
		x.heir.level = 30
		x.heir.hp = x.heir.max_hp()
		if event_id != "":
			GameWorldEvents.begin(x, event_id, 20)
		var g := x.heir.gold
		var xp_before := x.heir.xp
		var lv := x.heir.level
		var bt := x.start_hunt("hunt")
		var guard := 0
		while bt != null and not bt.is_over() and guard < 300:
			guard += 1
			GameTactics.auto_turn(bt)
		x.finish_battle()
		return [x.heir.gold - g, x.heir.level - lv, x.heir.xp - xp_before]
	var plain: Array = pay.call("")
	var war: Array = pay.call("war")
	ok(plain[0] > 0, "(the plain fight was won and paid %d gold)" % plain[0])
	ok(war[0] > plain[0] and absi(war[0] - int(round(plain[0] * 1.3))) <= 2, "the same fight pays 30%% more gold in a war: %d against %d" % [war[0], plain[0]])
	# sickness: the same roll catches in a pestilence and not without
	var caught := [0, 0]
	for i in 300:
		var p := dyn(100 + i)
		var q := dyn(100 + i)
		GameWorldEvents.begin(q, "pestilence", 20)
		var id := "bog_fever"
		if GameDisease._expose(p, p.heir, id, 0.2) == "caught":
			caught[0] += 1
		if GameDisease._expose(q, q.heir, id, 0.2) == "caught":
			caught[1] += 1
		if i == 0:
			ok(p.rng.state == q.rng.state, "an exposure draws the same die with or without a pestilence")
	ok(caught[1] > caught[0] * 2 and caught[0] > 20, "a pestilence makes an exposure take about two and a half times as often: %d against %d of 300" % [caught[1], caught[0]])


func test_course() -> void:
	var d := dyn()
	var msgs: Array = []
	var journal := d.journal.size()
	var line := GameWorldEvents.begin(d, "war", 20, msgs)
	var len := GameWorldEvents.length(d, "war", 20)
	ok(len >= 3 and len <= 8 and d.world_event == {"id": "war", "began": 20, "until": 20 + len}, "a war beginning in year 20 lasts three to eight years: %s" % str(d.world_event))
	ok(line == GameWorldEvents.event("war")["begins"] and d.journal.size() == journal + 1 and msgs == [line], "and its beginning is told")
	ok(int(d.flags.get("world_events_seen", 0)) == 1, "and counted")
	ok(GameWorldEvents.describe(d) == "The War of the River Lords (prices up a quarter, fights pay 30%% more gold), until year %d." % (21 + len), "the screens name it: %s" % GameWorldEvents.describe(d))
	msgs.clear()
	GameWorldEvents.on_years(d, float(len - 1), msgs, float(20 + len - 1))
	ok(GameWorldEvents.active(d) == "war" and msgs.is_empty(), "it runs its years")
	GameWorldEvents.on_years(d, 1.0, msgs, float(20 + len))
	ok(GameWorldEvents.active(d) == "" and msgs == [GameWorldEvents.event("war")["ends"]], "and ends, and that is told: %s" % str(msgs))
	ok(d.world_event == {"id": "", "until": 20 + len + 6}, "the world then rests six years: %s" % str(d.world_event))
	ok(GameItems.price_mult(d) == GameItems.price_mult(dyn()), "and prices are what they were")
	# nothing begins during the rest, whatever the dice say
	_with(func(x): x["settings"]["chance_per_year"] = 0.5, func():
		var r := dyn()
		r.world_event = {"id": "", "until": 60}
		GameWorldEvents.on_years(r, 39.0, [], 59.0)
		ok(GameWorldEvents.active(r) == "" and r.world_event == {"id": "", "until": 60}, "nothing begins while the world rests")
		GameWorldEvents.on_years(r, 30.0, [], 89.0)
		ok(int(r.flags.get("world_events_seen", 0)) >= 1, "and something does once it has rested"))
	ok(GameWorldEvents.begin(d, "nonesuch", 50) == "", "an unknown event does not begin")
	var dead := dyn()
	dead.state = "succession"
	_with(func(x): x["settings"]["chance_per_year"] = 0.5, func():
		GameWorldEvents.on_years(dead, 50.0, [], 80.0))
	ok(dead.world_event.is_empty(), "nothing turns while there is no living heir")


func test_rolls() -> void:
	var d := dyn(3)
	for y in 15:
		ok(GameWorldEvents.rolled(d, y) == "", "year %d: nothing begins in the house's first years" % y)
	var began := {}
	var n := 0
	for y in range(15, 4015):
		var id := GameWorldEvents.rolled(d, y)
		if id != "":
			n += 1
			began[id] = int(began.get(id, 0)) + 1
	ok(n > 140 and n < 260, "about one free year in twenty begins an event: %d of 4000" % n)
	ok(not began.has("golden_age"), "no golden age in the first two generations")
	ok(began.size() == 4 and began["war"] > began["great_fair"], "the other four all come, wars most often: %s" % str(began))
	d.gen = 3
	var golden := 0
	for y in range(15, 4015):
		if GameWorldEvents.rolled(d, y) == "golden_age":
			golden += 1
	ok(golden > 10, "from the third generation golden ages come too (%d)" % golden)
	ok(GameWorldEvents.rolled(d, 777) == GameWorldEvents.rolled(d, 777), "the same year, the same answer")
	var other := dyn(4)
	other.gen = 3
	var differs := false
	for y in range(15, 400):
		if GameWorldEvents.rolled(d, y) != GameWorldEvents.rolled(other, y):
			differs = true
	ok(differs, "another seed, another history")
	for id in GameWorldEvents.ids():
		var span: Array = GameWorldEvents.event(id)["years"]
		var seen := {}
		for y in 300:
			var l := GameWorldEvents.length(d, id, y)
			seen[l] = true
			if l < int(span[0]) or l > int(span[1]):
				ok(false, "%s lasted %d years, outside %s" % [id, l, str(span)])
		ok(seen.size() == int(span[1]) - int(span[0]) + 1, "%s lasts every length from %d to %d" % [id, span[0], span[1]])
	# a long life: events come, end, and the share of years under one is modest
	var w := dyn(8)
	var under := 0
	var count := 0
	for y in range(1, 601):
		w.world.year = float(y)
		GameWorldEvents.on_years(w, 1.0, [], float(y))
		if GameWorldEvents.active(w) != "":
			under += 1
	count = int(w.flags.get("world_events_seen", 0))
	ok(count >= 8 and count <= 40, "six hundred years see a fair number of events: %d" % count)
	ok(under > 30 and under < 330, "and well under half of them are lived under one: %d of 600" % under)


func test_dice() -> void:
	var a := dyn(21)
	var b := dyn(21)
	_with(func(x): x["settings"]["chance_per_year"] = 0.0001, func():
		for i in 40:
			a.pass_time(1.0))
	_with(func(x): x["settings"]["chance_per_year"] = 0.5; x["settings"]["grace_years"] = 0, func():
		for i in 40:
			b.pass_time(1.0))
	ok(int(b.flags.get("world_events_seen", 0)) > 0 and int(a.flags.get("world_events_seen", 0)) == 0, "one house saw events and the other none")
	ok(a.rng.state == b.rng.state, "and both drew exactly the same of the dynasty's dice: events use their own")
	var c := dyn(21)
	var before := c.rng.state
	GameWorldEvents.on_years(c, 200.0, [], 200.0)
	ok(c.rng.state == before, "rolling two hundred years of events draws none of the dynasty's dice")
	var w := dyn(21)
	_with(func(x): x["settings"]["chance_per_year"] = 0.5; x["settings"]["grace_years"] = 0, func():
		w.pass_time(30.0))
	ok(int(w.flags.get("world_events_seen", 0)) > 0, "pass_time reaches the world's events")


func test_saving() -> void:
	var d := dyn()
	GameWorldEvents.begin(d, "war", 20)
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(back.world_event == d.world_event and GameWorldEvents.active(back) == "war", "a running event survives a save and load")
	d.world_event = {"id": "", "until": 44}
	ok(GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict()))).world_event == {"id": "", "until": 44}, "and so does the rest after one")
	var old: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	old.erase("world_event")
	ok(GameDynasty.from_dict(old).world_event.is_empty(), "a save from before world events loads with a quiet world")
	for junk in ["war", 7, [1], null, {}, {"id": "war"}, {"id": "war", "until": "soon"}, {"id": 4, "until": 9}, {"id": "nonesuch", "until": 9}]:
		var bad: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
		bad["world_event"] = junk
		ok(GameDynasty.from_dict(bad).world_event.is_empty(), "a world event saved as %s loads as a quiet world" % str(junk))
	var odd: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	odd["world_event"] = {"id": "famine", "until": 31.0, "began": "then", "extra": 1}
	ok(GameDynasty.from_dict(odd).world_event == {"id": "famine", "began": 31, "until": 31}, "a damaged beginning falls back and nothing else is kept")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


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
	app.show_state()
	await _frames(3)
	var quiet: String = app.current.where.text
	ok("War" not in quiet and "at peace" not in quiet, "the life screen says nothing of the world while it is quiet: %s" % quiet)
	GameWorldEvents.begin(d, "war", 20)
	app.show_state()
	await _frames(3)
	var now: String = app.current.where.text
	ok(now.begins_with(quiet) and now.ends_with(GameWorldEvents.describe(d)), "and names the war beside the weather while it runs: %s" % now)
	app.queue_free()
	await _frames(2)
