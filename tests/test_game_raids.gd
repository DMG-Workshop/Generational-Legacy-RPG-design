## Raids and theft on the house (roadmap item 61, first part): the data and its validator, the chance (none with
## nothing kept, more with more stock, less with guards), that a raid comes with the years on keyed dice and never
## to a house that keeps nothing or while an event waits, what each kind can take, trusting the guards (beaten off
## or a loss, the gold loss cut by the guards), the three raid events and their choices (including a fight), and the
## event screen. Raid events are never found while exploring, and a house with no animals plays exactly as before.
## Run: godot --headless --path . -s res://tests/test_game_raids.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const EventPanel := preload("res://ui/play/event_panel.gd")
const DIR := "user://test_raids/"

var fails := 0
var checks := 0
var app: Node


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	GameData.load_all()
	test_data()
	test_chance()
	test_coming()
	test_kinds()
	test_defend()
	test_events()
	test_untouched()
	await test_screen()
	print("%d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func dyn(seed_value: int = 5) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 1000
	d.house[GameHouse.RANCH] = 3
	return d


func _with(edit: Callable, body: Callable) -> void:
	var saved: Dictionary = GameRaids.data().duplicate(true)
	edit.call(GameRaids.data())
	body.call()
	GameRaids._cache = saved


## A raid certain to come, so a test can see what it does.
func _sure(x: Dictionary) -> void:
	x["settings"]["base_chance"] = 1.0
	x["settings"]["max_chance"] = 1.0


func _animal(d: GameDynasty, species: String = "wolf", name: String = "") -> Dictionary:
	var e := GameRoster.add(d, species, name if name != "" else species.capitalize())
	e["stage"] = "adult"
	e["age"] = 6.0
	e["mood"] = 100
	return e


## `n` grown guards (wolves are guards), content.
func _guards(d: GameDynasty, n: int) -> void:
	for i in n:
		_animal(d, "wolf", "Guard%d" % i)


func test_data() -> void:
	ok(GameRaids.validate().is_empty(), "raids.json is sound: %s" % str(GameRaids.validate()))
	ok(GameRaids.kinds() == ["beasts", "rustlers", "thieves"], "three kinds of raid")
	_with(func(x): x["settings"]["max_chance"] = 0.01, func(): ok(not GameRaids.validate().is_empty(), "a ceiling below the base is found"))
	_with(func(x): x["settings"]["beat_off_max"] = 2.0, func(): ok(not GameRaids.validate().is_empty(), "a chance above 1 is found"))
	_with(func(x): x["kinds"]["thieves"]["event"] = "tavern_brawl", func(): ok(not GameRaids.validate().is_empty(), "a raid kind whose event is not marked raid is found"))
	_with(func(x): x["kinds"]["thieves"]["event"] = "nonesuch", func(): ok(not GameRaids.validate().is_empty(), "a kind whose event does not exist is found"))
	_with(func(x): x["kinds"]["thieves"]["takes"] = "souls", func(): ok(not GameRaids.validate().is_empty(), "a kind that takes something unknown is found"))
	_with(func(x): x["kinds"]["thieves"]["weight"] = 0, func(): ok(not GameRaids.validate().is_empty(), "a kind with no weight is found"))
	_with(func(x): x["kinds"].erase("beasts"), func(): ok(not GameRaids.validate().is_empty(), "a raid event used by no kind is found"))
	_with(func(x): x["text"].erase("stole_gold"), func(): ok(not GameRaids.validate().is_empty(), "missing text is found"))
	ok(GameRaids.validate().is_empty(), "the data is put back")
	for id in ["raid_thieves", "raid_rustlers", "raid_beasts"]:
		ok(GameEvents.event_def(id).get("raid", false) == true, "%s is a raid event" % id)


func test_chance() -> void:
	var d := dyn()
	ok(GameRaids.chance(d) == 0.0 and GameRaids.stock_value(d) == 0, "a house that keeps nothing is never raided")
	_animal(d, "slime")
	var small := GameRaids.chance(d)
	ok(small > float(GameRaids.setting("base_chance")) * 0.999, "a little stock draws a raid at about the base chance: %s" % small)
	var rich := dyn()
	for i in 5:
		_animal(rich, "ogre", "O%d" % i)
	ok(GameRaids.chance(rich) > small and GameRaids.stock_value(rich) > GameRaids.stock_value(d), "more stock, more raids")
	ok(GameRaids.chance(rich) <= float(GameRaids.setting("max_chance")) + 0.0001, "never above the ceiling")
	var plain := dyn()
	var guarded := dyn()
	for dd in [plain, guarded]:
		_animal(dd, "slime", "Big")   # slimes keep no guard
	_animal(guarded, "wolf", "G1")
	_animal(guarded, "bog_troll", "G2")
	_animal(plain, "slime", "S1")
	_animal(plain, "slime", "S2")
	ok(GameRaids.deterrence(plain) == 0.0 and GameRaids.deterrence(guarded) > 0.0, "guards put raiders off, nothing else does")
	# compare one house with and without a guard, the same stock otherwise
	var a := dyn()
	var b := dyn()
	_animal(a, "slime", "S")
	_animal(b, "slime", "S")
	_guards(b, 3)
	var stock_a := GameRaids.stock_value(a)
	var raw_b: float = minf(float(GameRaids.setting("max_chance")), float(GameRaids.setting("base_chance")) + float(GameRaids.setting("per_stock_gold")) * float(GameRaids.stock_value(b)))
	ok(GameRaids.chance(b) < raw_b and stock_a >= 0, "guards cut the chance below what the stock alone would draw")
	ok(is_equal_approx(GameRaids.deterrence(b), 0.5 * minf(1.0, GameRanch.guard_cut(b) / 0.6)), "by up to half at full guard")
	ok(GameRaids.beat_off_chance(plain) == 0.0 and GameRaids.beat_off_chance(guarded) > 0.0, "and only guards beat a raid off")
	var full := dyn()
	_guards(full, 4)
	ok(is_equal_approx(GameRaids.beat_off_chance(full), float(GameRaids.setting("beat_off_max"))), "up to the most at full guard: %s" % GameRaids.beat_off_chance(full))
	var young := dyn()
	var y := GameRoster.add(young, "wolf", "Pup")
	y["stage"] = "young"
	ok(GameRaids.beat_off_chance(young) == 0.0, "a pup guards nothing")


func test_coming() -> void:
	_with(_sure, func():
		var d := dyn()
		_animal(d, "slime")
		var msgs: Array = []
		GameRaids.on_years(d, 1.0, msgs, 1.0)
		ok(d.has_pending_event() and str(d.pending_event["source"]) == "raid" and str(d.pending_event["id"]).begins_with("raid_"), "a raid comes as a waiting event: %s" % str(d.pending_event))
		ok(msgs.size() == 1 and "Trouble at the ranch" in msgs[0] and d.journal.back() == msgs[0], "and is told and journalled: %s" % str(msgs))
		ok(int(d.flags.get("raid_count", 0)) == 1, "and counted")
		var again: Array = []
		GameRaids.on_years(d, 5.0, again, 6.0)
		ok(again.is_empty() and int(d.flags.get("raid_count", 0)) == 1, "no second raid while one waits")
		var none := dyn()
		GameRaids.on_years(none, 3.0, [], 3.0)
		ok(not none.has_pending_event(), "a house that keeps nothing is never raided, however sure")
		var dead := dyn()
		_animal(dead, "slime")
		dead.state = "succession"
		GameRaids.on_years(dead, 1.0, [], 1.0)
		ok(not dead.has_pending_event(), "nor outside a life")
		var none_yet := dyn()
		_animal(none_yet, "slime")
		GameRaids.on_years(none_yet, 0.4, [], 0.4)
		ok(not none_yet.has_pending_event(), "no year ended, no raid")
		GameRaids.on_years(none_yet, 0.4, [], 1.2)
		ok(none_yet.has_pending_event(), "the year ending is the roll")
		# through the world clock
		var w := dyn(3)
		_animal(w, "slime")
		w.pass_time(2.0)
		ok(w.has_pending_event() or int(w.flags.get("raid_count", 0)) > 0, "pass_time reaches raids through the ranch"))
	# the rate matches the chance
	var came := 0
	var c_expect := 0.0
	for s in range(1, 1501):
		var d := dyn(s)
		_animal(d, "slime")
		c_expect = GameRaids.chance(d)
		GameRaids.on_years(d, 1.0, [], 1.0)
		if d.has_pending_event():
			came += 1
	var rate := float(came) / 1500.0
	ok(absf(rate - c_expect) < 0.03, "the raid rate over 1,500 seeds matches the chance (%.3f against %.3f)" % [rate, c_expect])
	# keyed: the same seed and year the same raid, and no die from the dynasty
	var same := true
	_with(_sure, func():
		for s in range(1, 30):
			var a := dyn(s)
			var b := dyn(s)
			for dd in [a, b]:
				_animal(dd, "slime")
				_animal(dd, "wolf")
				GameRaids.on_years(dd, 1.0, [], 4.0)
			same = same and a.pending_event == b.pending_event)
	ok(same, "the same seed and year bring the same raid")
	_with(_sure, func():
		var d := dyn(9)
		_animal(d, "slime")
		var before := d.rng.state
		GameRaids.on_years(d, 1.0, [], 1.0)
		ok(d.rng.state == before and d.has_pending_event(), "a raid draws nothing from the dynasty's dice"))
	# an event already waiting is never overwritten, even by an explore that spends the year
	_with(_sure, func():
		var e := dyn(4)
		_animal(e, "slime")
		e.world.location = "greenvale"
		e.explore()
		ok(e.has_pending_event() and str(e.pending_event["id"]).begins_with("raid_"), "a raid that comes while exploring keeps its place: %s" % str(e.pending_event.get("id")))
		var b := e.explore()
		ok(b.size() == 1 and "must first settle" in b[0], "and the heir must settle it first"))


func test_kinds() -> void:
	var d := dyn()
	ok(not GameRaids.applicable(d, "rustlers") and not GameRaids.applicable(d, "beasts") and GameRaids.applicable(d, "thieves"), "with gold and no animals only thieves have anything to take")
	d.heir.gold = 0
	ok(not GameRaids.applicable(d, "thieves"), "with no gold thieves have nothing")
	_animal(d, "slime")
	ok(GameRaids.applicable(d, "rustlers") and GameRaids.applicable(d, "beasts"), "with an animal, rustlers and beasts do")
	# every kind is picked sometimes, none that has nothing to take
	var seen := {}
	_with(_sure, func():
		for s in range(1, 200):
			var h := dyn(s)
			_animal(h, "slime")
			GameRaids.on_years(h, 1.0, [], 1.0)
			seen[str(h.pending_event.get("id", ""))] = true)
	ok(seen.has("raid_thieves") and seen.has("raid_rustlers") and seen.has("raid_beasts"), "every kind of raid comes: %s" % str(seen.keys()))
	var broke := {}
	_with(_sure, func():
		for s in range(1, 100):
			var h := dyn(s)
			h.heir.gold = 0
			_animal(h, "slime")
			GameRaids.on_years(h, 1.0, [], 1.0)
			broke[str(h.pending_event.get("id", ""))] = true)
	ok(not broke.has("raid_thieves"), "thieves do not come to a house with no gold")


func test_defend() -> void:
	# no guards: the raid takes what it came for
	var d := dyn()
	_animal(d, "slime", "Gloop")
	var gold := d.heir.gold
	var out := GameRaids.defend(d, "thieves")
	ok(out.size() == 1 and out[0]["k"] == "bad" and "get away with" in out[0]["t"], "unguarded, thieves take gold: %s" % str(out))
	ok(gold - d.heir.gold == 150, "a share of it (15%% of 1000): %d" % (gold - d.heir.gold))
	var small := dyn()
	small.heir.gold = 20
	_animal(small, "slime")
	GameRaids.defend(small, "thieves")
	ok(small.heir.gold == 10, "never less than the minimum while there is that much: %d" % small.heir.gold)
	var broke := dyn()
	broke.heir.gold = 0
	_animal(broke, "slime")
	ok(GameRaids.defend(broke, "thieves")[0]["k"] == "info", "thieves find nothing in an empty purse")
	var r := dyn()
	_animal(r, "slime", "Gloop")
	var out2 := GameRaids.defend(r, "rustlers")
	ok(r.roster.is_empty() and "drive off Gloop the green slime" in out2[0]["t"], "rustlers drive an animal off: %s" % out2[0]["t"])
	var b := dyn()
	_animal(b, "slime", "Gloop")
	var out3 := GameRaids.defend(b, "beasts")
	ok(b.roster.is_empty() and "kill Gloop the green slime" in out3[0]["t"], "beasts kill one: %s" % out3[0]["t"])
	ok(GameRaids.defend(dyn(), "rustlers")[0]["k"] == "info", "rustlers find an empty pen")
	ok(GameRaids.defend(dyn(), "nonesuch").is_empty(), "an unknown kind does nothing")
	var dead := dyn()
	_animal(dead, "slime")
	dead.state = "succession"
	ok(GameRaids.defend(dead, "rustlers").is_empty() and dead.roster.size() == 1, "nothing happens outside a life")
	# guards: certain to beat it off with the most guard when the chance is raised
	_with(func(x): x["settings"]["beat_off_max"] = 1.0, func():
		var g := dyn()
		_guards(g, 4)
		var before := g.roster.size()
		var beaten := GameRaids.defend(g, "rustlers")
		ok(g.roster.size() == before and beaten[0]["k"] == "good" and "drive the rustlers off" in beaten[0]["t"], "with the most guards and a sure chance the raid is beaten off: %s" % beaten[0]["t"])
		var gold_before := g.heir.gold
		ok(GameRaids.defend(g, "thieves")[0]["k"] == "good" and g.heir.gold == gold_before, "and thieves get nothing"))
	# partial guards cut the gold taken, and the loss says so
	var p := dyn()
	_guards(p, 1)   # a fifth of the loss turned away
	_with(func(x): x["settings"]["beat_off_max"] = 0.0, func():
		var g2 := p.heir.gold
		var taken := GameRaids.defend(p, "thieves")
		ok(g2 - p.heir.gold == 120 and "The guards saved 30" in taken[0]["t"], "one guard turns away a fifth of what thieves take: %d, %s" % [g2 - p.heir.gold, taken[0]["t"]]))
	# keyed: the same raid the same loss, no die from the dynasty
	var a := dyn(8)
	var c := dyn(8)
	for dd in [a, c]:
		for i in 4:
			_animal(dd, "slime", "S%d" % i)
	GameRaids.defend(a, "rustlers")
	GameRaids.defend(c, "rustlers")
	ok(a.roster == c.roster, "the same raid takes the same animal")
	var before := a.rng.state
	GameRaids.defend(a, "rustlers")
	ok(a.rng.state == before, "defending draws nothing from the dynasty's dice")


func test_events() -> void:
	var d := dyn()
	_animal(d, "slime")
	for id in ["raid_thieves", "raid_rustlers", "raid_beasts"]:
		ok(not GameEvents.is_eligible(d, GameEvents.event_def(id)), "%s is never found while exploring" % id)
	ok(not GameEvents.eligible(d).any(func(e): return str(e["id"]).begins_with("raid_")), "no raid in any explore pool")
	for place in ["hearthmere", "greenvale", "whisperwood", "emberpeak"]:
		d.world.location = place
		ok(not GameEvents.eligible(d).any(func(e): return e.get("raid", false)), "none at %s" % place)
	# each choice of each event resolves
	for id in ["raid_thieves", "raid_rustlers", "raid_beasts"]:
		var ev := GameEvents.event_def(id)
		for i in ev["choices"].size():
			var e := dyn(i + 3)
			_animal(e, "slime")
			_animal(e, "slime", "Two")
			e.heir.gold = 1000
			GameEvents.begin(e, id, "raid")
			var msgs := GameEvents.resolve_as(e, i, "failure" if ev["choices"][i].has("check") else "always")
			ok(not msgs.is_empty(), "%s: choice %d resolves" % [id, i])
	# trusting the guards uses them; a failed trick falls back to them; a clean trick loses nothing
	var t := dyn()
	_animal(t, "slime")
	GameEvents.begin(t, "raid_thieves", "raid")
	var g0 := t.heir.gold
	GameEvents.resolve_as(t, 0, "always")
	ok(t.heir.gold < g0, "trusting the guards with none costs the thieves' share")
	var t2 := dyn()
	_animal(t2, "slime")
	GameEvents.begin(t2, "raid_thieves", "raid")
	GameEvents.resolve_as(t2, 3, "success")
	ok(t2.heir.gold == 1000, "a clean trick loses nothing")
	var t3 := dyn()
	_animal(t3, "slime")
	GameEvents.begin(t3, "raid_thieves", "raid")
	GameEvents.resolve_as(t3, 3, "failure")
	ok(t3.heir.gold < 1000, "a failed one leaves it to the guards (none here)")
	# paying
	var pay := dyn()
	_animal(pay, "slime")
	GameEvents.begin(pay, "raid_thieves", "raid")
	GameEvents.resolve_as(pay, 2, "always")
	ok(pay.heir.gold == 1000, "(the purse is paid in the event's own text, no gold effect to break)")
	# the fight
	var f := dyn()
	_animal(f, "slime")
	GameEvents.begin(f, "raid_thieves", "raid")
	GameEvents.resolve_as(f, 1, "always")
	ok(f.battle != null and f.pending_event["result"]["fight"].size() == 2, "riding out starts a fight with two raiders: %s" % str(f.pending_event["result"]["fight"]))
	ok(f.roster.size() == 1, "and nothing is taken while the heir fights")


func test_untouched() -> void:
	var a := dyn(9)
	var b := dyn(9)
	for i in 20:
		a.pass_time(1.0)
		b.pass_time(1.0)
	ok(a.to_dict() == b.to_dict() and not a.flags.has("raid_count"), "two houses that keep nothing stay identical and are never raided")
	var c := dyn(9)
	var e := dyn(9)
	_animal(e, "slime")
	for i in 5:
		c.pass_time(1.0)
		e.pass_time(1.0)
		if e.has_pending_event():
			e.pending_event = {}
	ok(c.rng.state == e.rng.state, "keeping animals, raids included, draws nothing from the dynasty's dice")


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
	app = GameApp.new()
	root.add_child(app)
	await _frames(3)
	app.new_game("Tess", "warrior", "faetouched", 77, "human")
	var d: GameDynasty = app.dynasty
	d.pending_event = {}
	_animal(d, "slime")
	GameEvents.begin(d, "raid_rustlers", "raid")
	app.show_state()
	await _frames(4)
	var found := _find_label(app.current, "Rustlers at the Fence")
	ok(found != null or _find_label(app.current.get_parent(), "Rustlers at the Fence") != null or _has_text(app, "Rustlers at the Fence"), "a raid is shown on the event screen")
	ok(_has_button(app, "Trust the guards") and _has_button(app, "Ride out and fight them"), "with its choices")
	app.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(DIR + "save.json")


func _find_label(n: Node, text: String) -> Label:
	if n is Label and (n as Label).is_visible_in_tree() and (n as Label).text == text:
		return n
	for c in n.get_children():
		var l := _find_label(c, text)
		if l != null:
			return l
	return null


func _has_text(n: Node, text: String) -> bool:
	if (n is Label and (n as Label).text == text) or (n is RichTextLabel and text in (n as RichTextLabel).text):
		return true
	for c in n.get_children():
		if _has_text(c, text):
			return true
	return false


func _has_button(n: Node, prefix: String) -> bool:
	if n is Button and (n as Button).text.contains(prefix):
		return true
	for c in n.get_children():
		if _has_button(c, prefix):
			return true
	return false
