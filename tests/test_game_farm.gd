## Farm animals and their worth (roadmap item 62, first part): the data and its validator, that farm animals are
## never fought or found beside the dead, the market (young stock bought in a town), the yearly yield by season and
## by how well the animal is kept, slaughter for meat and hide, that they breed like any creature, and the screens
## (the Market on the Creatures tab, the Slaughter button on a second tap). Wild creatures and houses that keep no
## farm animals are exactly what they were.
## Run: godot --headless --path . -s res://tests/test_game_farm.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const ChroniclePanel := preload("res://ui/play/chronicle_panel.gd")
const SpriteArt := preload("res://ui/play/sprite_art.gd")
const DIR := "user://test_farm/"

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
	test_pools()
	test_market()
	test_yield()
	test_slaughter()
	test_breeding()
	test_more_animals()
	test_untouched()
	await test_screens()
	print("%d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func dyn(seed_value: int = 5) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 100000
	d.house[GameHouse.RANCH] = 3
	return d


func _with(edit: Callable, body: Callable) -> void:
	var saved: Dictionary = GameFarm.data().duplicate(true)
	edit.call(GameFarm.data())
	body.call()
	GameFarm._cache = saved


## A grown farm animal of a species, in a mood.
func _grown(d: GameDynasty, species: String, stage: String = "adult", mood: int = 70) -> Dictionary:
	var e := GameRoster.add(d, species, species.capitalize())
	var sz := GameRanch.size_of(species)
	e["stage"] = stage
	e["mood"] = mood
	var adult_from := GameRanch.egg_years(e) + float(sz["young"])
	e["age"] = (adult_from + GameRanch.adult_at(e)) * 0.5 if stage == "adult" else (GameRanch.adult_at(e) + 0.5 if stage == "elder" else GameRanch.egg_years(e))
	return e


func test_data() -> void:
	ok(GameFarm.validate().is_empty(), "farm.json is sound: %s" % str(GameFarm.validate()))
	var farm := GameData.creatures.filter(func(c): return c.get("farm", false))
	ok(farm.size() == 7 and farm.map(func(c): return str(c["id"])) == ["sheep", "cattle", "pig", "chicken", "goat", "goose", "horse"], "seven farm animals: sheep, cattle, pig, chicken, goat, goose, horse")
	for c in farm:
		var id := str(c["id"])
		ok(GameBirth.born(id) != "none" and GameBirth.young_name(id) != "", "%s is born and its young have a name" % id)
		ok(SpriteArt.has_creature(id), "%s has art" % id)
		ok(GameRanch.data()["size_of"].has(id) and GameBreeding.family_of(id) != "", "%s has a size and a family" % id)
	_with(func(x): x["market"]["skeleton"] = 5, func(): ok(not GameFarm.validate().is_empty(), "a market selling a creature that is no farm animal is found"))
	_with(func(x): x["market"]["pig"] = 0, func(): ok(not GameFarm.validate().is_empty(), "a price of nothing is found"))
	_with(func(x): x["market"].erase("sheep"), func(): ok(not GameFarm.validate().is_empty(), "a farm animal not sold is found"))
	_with(func(x): x["slaughter"].erase("cattle"), func(): ok(not GameFarm.validate().is_empty(), "a farm animal with no meat is found"))
	_with(func(x): x["slaughter"]["wolf"] = {"meat": 5, "hide": 1}, func(): ok(not GameFarm.validate().is_empty(), "meat from a wild creature is found"))
	_with(func(x): x["settings"]["mood_floor"] = 0.0, func(): ok(not GameFarm.validate().is_empty(), "a mood floor of zero is found"))
	_with(func(x): x["settings"]["season_mult"]["wool"].erase("winter"), func(): ok(not GameFarm.validate().is_empty(), "a missing season is found"))
	_with(func(x): x["settings"]["season_mult"]["telepathy"] = {}, func(): ok(not GameFarm.validate().is_empty(), "a season table for no work kind is found"))
	_with(func(x): x["settings"]["slaughter_stage"]["egg"] = 0.5, func(): ok(not GameFarm.validate().is_empty(), "slaughtering an egg is found"))
	_with(func(x): x["text"].erase("bought"), func(): ok(not GameFarm.validate().is_empty(), "missing text is found"))
	_with(func(x): x["settings"]["no_slaughter"].append("wolf"), func(): ok(not GameFarm.validate().is_empty(), "no_slaughter naming a wild creature is found"))
	_with(func(x): x["settings"]["no_slaughter"].append("sheep"), func(): ok(not GameFarm.validate().is_empty(), "an animal with meat that is also in no_slaughter is found"))
	_with(func(x): x["settings"]["no_slaughter"].clear(), func(): ok(not GameFarm.validate().is_empty(), "a farm animal with no meat and not in no_slaughter is found (the horse)"))
	ok(GameFarm.validate().is_empty(), "the data is put back")
	ok(GameFarm.is_farm("sheep") and not GameFarm.is_farm("wolf") and not GameFarm.is_farm("nonesuch"), "only the farm animals are farm animals")


func test_pools() -> void:
	# no hunt ever meets a farm animal, in any place or era
	var met := {}
	for s in range(1, 40):
		var d := dyn(s)
		for place in ["hearthmere", "greenvale", "whisperwood", "ironford", "frostreach", "highcrag"]:
			d.world.location = place
			for gen in [1, 30, 90]:
				d.gen = gen
				var b := d.start_hunt("hunt")
				for e in b.enemies:
					met[str(e["id"])] = true
	ok(not met.has("sheep") and not met.has("cattle") and not met.has("pig") and not met.has("chicken"), "no hunt meets a farm animal (met %d kinds)" % met.size())
	# nor does an event fight
	var d2 := dyn()
	var picked := {}
	for i in 300:
		d2.gen = 1 + (i % 90)
		picked[str(GameEvents._creature_for(d2, "local")["id"])] = true
	ok(not picked.has("sheep") and not picked.has("cattle") and not picked.has("pig") and not picked.has("chicken"), "nor an event's fight")
	ok(GameData.creatures.filter(func(c): return not c.get("boss", false) and not c.get("farm", false)).size() == 24, "the wild creatures a hunt draws on are the same 24 as before")


func test_market() -> void:
	var d := dyn()
	ok(GameFarm.market_species() == ["cattle", "chicken", "goat", "goose", "horse", "pig", "sheep"], "the market sells seven kinds, in a fixed order")
	ok(GameFarm.price("sheep") == 40 and GameFarm.price("nonesuch") == 0, "sheep are forty gold")
	ok(GameFarm.why_not_buy(d, "sheep") == "", "a house in a town may buy")
	var gold := d.heir.gold
	var line := GameFarm.buy(d, "sheep")
	var lamb: Dictionary = d.roster[0]
	ok(d.roster.size() == 1 and lamb["species"] == "sheep" and lamb["stage"] == "young" and lamb["age"] == 0.0, "buying adds a young lamb")
	ok(gold - d.heir.gold == 40 and "buys a lamb sheep at the market for 40 gold" in line and d.journal.back() == line, "pays, says so and journals it: %s" % line)
	var chick_line := GameFarm.buy(d, "chicken")
	var chick: Dictionary = d.roster[1]
	ok(chick["stage"] == "young" and chick["born"] == "egg" and chick["age"] == GameRanch.egg_years(chick), "a chick skips its egg and starts young")
	ok(GameRanch.stage_at(chick, float(chick["age"])) == "young", "(and the stage follows the age)")
	var a := dyn(7)
	var b := dyn(7)
	GameFarm.buy(a, "pig")
	GameFarm.buy(b, "pig")
	ok(a.roster == b.roster, "the same seed and purchase give the same animal")
	var before := a.rng.state
	GameFarm.buy(a, "pig")
	ok(a.rng.state == before, "buying draws nothing from the dynasty's dice")
	var wilds := dyn()
	wilds.world.location = "greenvale"
	ok(GameFarm.why_not_buy(wilds, "sheep") == GameFarm.text("not_in_town") and GameFarm.buy(wilds, "sheep") == "" and wilds.roster.is_empty(), "the market is in a town, not the wilds")
	var poor := dyn()
	poor.heir.gold = 10
	ok("Not enough gold" in GameFarm.why_not_buy(poor, "cattle") and GameFarm.buy(poor, "cattle") == "" and poor.heir.gold == 10, "without the gold nothing is bought")
	var full := dyn()
	for i in GameRoster.cap(full):
		GameRoster.add(full, "slime", "S%d" % i)
	ok(GameFarm.why_not_buy(full, "pig") == GameFarm.text("no_room") and GameFarm.buy(full, "pig") == "", "a full ranch has no room")
	var dead := dyn()
	dead.state = "succession"
	ok(GameFarm.buy(dead, "pig") == "" and dead.roster.is_empty(), "nothing is bought outside a life")
	ok(GameFarm.buy(dyn(), "wolf") == "", "the market does not sell wild creatures")


func test_yield() -> void:
	var d := dyn()
	var sheep := _grown(d, "sheep", "adult", 100)
	var by_season := {}
	for i in 4:
		d.world.year = 10.0 + float(i) * 0.25 + 0.01
		by_season[d.world.season()["id"]] = GameFarm.yield_mult(d, sheep)
	ok(by_season.size() == 4 and by_season["spring"] > by_season["summer"] and by_season["summer"] > by_season["autumn"] and by_season["autumn"] > by_season["winter"], "wool pays by the season, best in spring, worst in winter: %s" % str(by_season))
	d.world.year = 10.01
	var spring_pay := float(GameRanch.yearly_work(d)["gold"])
	d.world.year = 10.76
	var winter_pay := float(GameRanch.yearly_work(d)["gold"])
	ok(spring_pay > winter_pay and is_equal_approx(spring_pay, 12.0 * 1.3) and is_equal_approx(winter_pay, 12.0 * 0.7), "and so does what the ranch earns (%s, %s)" % [spring_pay, winter_pay])
	# kept poorly
	var good := _grown(dyn(), "cattle", "adult", 100)
	var poor := _grown(dyn(), "cattle", "adult", 40)
	ok(GameFarm.mood_scale(good) == 1.0 and GameFarm.mood_scale(poor) < GameFarm.mood_scale(good) and GameFarm.mood_scale({"mood": 0}) == 0.5, "a poorly kept animal gives less, never under half")
	ok(is_equal_approx(GameFarm.mood_scale(poor), 0.5 + 0.5 * 0.4), "(by a line from the floor to full)")
	# the work text and each kind
	for pair in [["sheep", "wool"], ["cattle", "milk"], ["chicken", "eggs"]]:
		var w := dyn()
		var e := _grown(w, str(pair[0]))
		ok(str(pair[1]) in GameRanch.yearly_work(w)["kinds"], "%s give %s" % [pair[0], pair[1]])
		ok("gold a year" in GameRanch.work_text(e), "and the entry says so: %s" % GameRanch.work_text(e))
	ok(GameRanch.work_of("pig").is_empty(), "a pig gives no yearly work")
	# young animals do no work; an old one half
	var y := dyn()
	_grown(y, "sheep", "young", 100)
	ok(float(GameRanch.yearly_work(y)["gold"]) == 0.0, "a lamb does no work")
	# wild creatures: the yield is untouched
	var wild := dyn()
	var drake := _grown(wild, "drake", "adult", 70)
	ok(GameFarm.yield_mult(wild, drake) == 1.0 and is_equal_approx(float(GameRanch.yearly_work(wild)["gold"]), 20.0), "a drake's eggs are what they were")
	# paid as the years pass
	var p := dyn()
	_grown(p, "chicken", "adult", 100)
	p.world.year = 10.01
	var gold := p.heir.gold
	GameRanch.on_years(p, 1.0, [])
	ok(p.heir.gold - gold == int(round(4.0 * 1.3)) - 1, "a year pays the eggs and the keep: %d" % (p.heir.gold - gold))


func test_slaughter() -> void:
	var d := dyn()
	var sheep := _grown(d, "sheep", "adult", 100)
	ok(GameFarm.slaughter_value(sheep) == 46, "an adult sheep fetches meat and hide: %d" % GameFarm.slaughter_value(sheep))
	sheep["stage"] = "young"
	var lamb := GameFarm.slaughter_value(sheep)
	sheep["stage"] = "elder"
	var old := GameFarm.slaughter_value(sheep)
	ok(lamb < old and old < 46, "a lamb fetches least and an old one less than a grown one (%d, %d)" % [lamb, old])
	sheep["stage"] = "adult"
	sheep["mood"] = 40
	ok(GameFarm.slaughter_value(sheep) < 46, "a poorly kept animal fetches less")
	sheep["stage"] = "egg"
	ok(GameFarm.slaughter_value(sheep) == 0, "an egg cannot be slaughtered")
	var wolf := _grown(d, "wolf", "adult", 100)
	ok(GameFarm.slaughter_value(wolf) == 0 and GameFarm.slaughter(d, int(wolf["id"])) == "", "a wild creature has no meat to sell")
	var s := dyn()
	var cow := _grown(s, "cattle", "adult", 100)
	var gold := s.heir.gold
	var line := GameFarm.slaughter(s, int(cow["id"]))
	ok(s.heir.gold - gold == 130 and s.roster.is_empty(), "slaughter pays the meat and hide and ends the animal: %d" % (s.heir.gold - gold))
	ok("slaughters Cattle the cow: the meat and the hide fetch 130 gold" in line and s.journal.back() == line, "says so and journals it: %s" % line)
	ok(GameFarm.slaughter(s, 999) == "" and GameFarm.slaughter(s, int(cow["id"])) == "", "an animal that is not there cannot be")
	var dead := dyn()
	var x := _grown(dead, "pig")
	dead.state = "succession"
	ok(GameFarm.slaughter(dead, int(x["id"])) == "" and dead.roster.size() == 1, "nothing is slaughtered outside a life")
	# for an adult, slaughter beats selling it alive; for a lamb, selling does
	var cmp := dyn()
	var a := _grown(cmp, "sheep", "adult", 100)
	ok(GameFarm.slaughter_value(a) > GameRanch.sell_price(a), "an adult is worth more as meat and hide than sold alive")
	var l := _grown(cmp, "sheep", "young", 100)
	ok(GameRanch.sell_price(l) > GameFarm.slaughter_value(l), "but a lamb is worth more sold alive than as meat (%d against %d)" % [GameRanch.sell_price(l), GameFarm.slaughter_value(l)])


func test_breeding() -> void:
	var d := dyn()
	var f := _grown(d, "sheep", "adult", 100)
	var m := _grown(d, "sheep", "adult", 100)
	f["sex"] = GameSex.FEMALE
	m["sex"] = GameSex.MALE
	f["breeding"] = true
	m["breeding"] = true
	ok(GameBreeding.kind("sheep", "sheep") == "pure" and GameBreeding.compatible("sheep", "sheep") and not GameBreeding.compatible("sheep", "cattle"), "sheep breed true and not with cattle")
	var saved: Dictionary = GameBreeding.data().duplicate(true)
	GameBreeding.data()["settings"]["fertility"] = {"pure": 1.0, "hybrid": 1.0, "cross": 1.0}
	GameBreeding.on_years(d, 1.0, [], 1.0)
	GameBreeding._cache = saved
	ok(d.roster.size() == 3 and d.roster[2]["species"] == "sheep" and d.roster[2]["stage"] == "young" and d.roster[2]["young"] == "lamb", "a pair of sheep has a lamb")
	var c := dyn()
	var hen := _grown(c, "chicken", "adult", 100)
	var cock := _grown(c, "chicken", "adult", 100)
	hen["sex"] = GameSex.FEMALE
	cock["sex"] = GameSex.MALE
	hen["breeding"] = true
	cock["breeding"] = true
	GameBreeding.data()["settings"]["fertility"] = {"pure": 1.0, "hybrid": 1.0, "cross": 1.0}
	GameBreeding.on_years(c, 1.0, [], 1.0)
	GameBreeding._cache = saved
	ok(c.roster.size() == 3 and c.roster[2]["stage"] == "egg" and c.roster[2]["young"] == "chick", "a pair of chickens lays an egg of chicks")


func test_more_animals() -> void:
	# the goat, the goose and the horse, each with its own work, its market price and its young
	for row in [["goat", "milk", "kid", "live", 35], ["goose", "eggs", "gosling", "egg", 8], ["horse", "haul", "foal", "live", 120]]:
		var sp := str(row[0])
		ok(GameBirth.young_name(sp) == str(row[2]) and GameBirth.born(sp) == str(row[3]), "%s: its young are %ss, born by %s" % [sp, row[2], row[3]])
		ok(GameRanch.work_of(sp).get("kind", "") == str(row[1]), "%s does %s" % [sp, row[1]])
		ok(GameFarm.price(sp) == int(row[4]), "and costs %d at the market" % int(row[4]))
		var d := dyn()
		var e := _grown(d, sp)
		ok(str(row[1]) in GameRanch.yearly_work(d)["kinds"] and "gold a year" in GameRanch.work_text(e), "%s earns its keep: %s" % [sp, GameRanch.work_text(e)])
	var d2 := dyn()
	GameFarm.buy(d2, "goose")
	ok(d2.roster[0]["stage"] == "young" and d2.roster[0]["born"] == "egg" and GameRanch.stage_at(d2.roster[0], float(d2.roster[0]["age"])) == "young", "a bought gosling skips its egg like a chick")
	# the horse is never slaughtered
	var h := _grown(dyn(), "horse")
	ok(GameFarm.slaughter_value(h) == 0 and GameFarm.slaughter(dyn(), 1) == "", "a horse has no slaughter value")
	var hd := dyn()
	var horse := _grown(hd, "horse")
	var before := hd.roster.size()
	ok(GameFarm.slaughter(hd, int(horse["id"])) == "" and hd.roster.size() == before and hd.heir.gold == 100000, "and slaughtering one does nothing")
	# goats and geese can be, and pay by their own table
	var g := _grown(dyn(), "goat", "adult", 100)
	ok(GameFarm.slaughter_value(g) == 35, "a grown goat fetches meat and hide: %d" % GameFarm.slaughter_value(g))
	var gs := _grown(dyn(), "goose", "adult", 100)
	ok(GameFarm.slaughter_value(gs) == 12, "a grown goose: %d" % GameFarm.slaughter_value(gs))
	# the work follows the season: the horse most in spring
	var w := dyn()
	var hh := _grown(w, "horse", "adult", 100)
	w.world.year = 10.01
	var spring := GameFarm.yield_mult(w, hh)
	w.world.year = 10.76
	ok(spring > GameFarm.yield_mult(w, hh), "the horse hauls most in spring and least in winter")
	# each breeds true, and only with its own kind
	for sp in ["goat", "goose", "horse"]:
		ok(GameBreeding.compatible(sp, sp) and not GameBreeding.compatible(sp, "sheep") and not GameBreeding.compatible(sp, "wolf"), "%s breeds with its own kind only" % sp)
	# never fought, never found
	var met := {}
	for s in range(1, 30):
		var hunt := dyn(s)
		hunt.world.location = "greenvale"
		for e in hunt.start_hunt("hunt").enemies:
			met[str(e["id"])] = true
	ok(not met.has("goat") and not met.has("goose") and not met.has("horse"), "none of them is met in a hunt")
	# they can be raided, like the rest of the stock
	var r := dyn()
	_grown(r, "horse")
	ok(GameRaids.stock_value(r) > 0 and GameRaids.chance(r) > 0.0, "a horse in the pens draws raiders")


func test_untouched() -> void:
	# a house that keeps no farm animals: the same lives
	var a := dyn(9)
	var b := dyn(9)
	for i in 10:
		a.pass_time(1.0)
		b.pass_time(1.0)
	ok(a.to_dict() == b.to_dict() and not a.to_dict().has("roster"), "two houses that keep none stay identical")
	var c := dyn(9)
	var e := dyn(9)
	GameFarm.buy(e, "sheep")
	for i in 5:
		c.pass_time(1.0)
		e.pass_time(1.0)
	ok(c.rng.state == e.rng.state, "keeping farm animals draws nothing from the dynasty's dice")


func _find_label(n: Node, text: String) -> Label:
	if n is Label and (n as Label).is_visible_in_tree() and (n as Label).text == text:
		return n
	for c in n.get_children():
		var l := _find_label(c, text)
		if l != null:
			return l
	return null


func _find_button(n: Node, text: String) -> Button:
	if n is Button and (n as Button).is_visible_in_tree() and (n as Button).text == text:
		return n
	for c in n.get_children():
		var b := _find_button(c, text)
		if b != null:
			return b
	return null


func _tab(p: Node, name: String) -> Control:
	for c in p.get_children():
		if c is TabContainer:
			return (c as TabContainer).get_node_or_null(name) as Control
		var found := _tab(c, name)
		if found != null:
			return found
	return null


func _panel(d: GameDynasty, on_change: Callable = Callable()) -> Control:
	var c := ChroniclePanel.new()
	c.dynasty = d
	c.on_change = on_change
	app.current.add_child(c)
	await _frames(3)
	var tab := _tab(c, "Creatures")
	(tab.get_parent() as TabContainer).current_tab = tab.get_index()
	await _frames(2)
	return tab


func test_screens() -> void:
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
	d.heir.gold = 100000
	var changes := [0]
	var tab := await _panel(d, func(): changes[0] += 1)
	ok(_find_label(tab, "Market") != null, "the Creatures tab has a Market")
	var buy_label := "Buy a lamb (40 gold) - Sheep"
	var buy_btn := _find_button(tab, buy_label)
	ok(buy_btn != null and not buy_btn.disabled and _find_button(tab, "Buy a calf (100 gold) - Cow") != null and _find_button(tab, "Buy a chick (6 gold) - Chicken") != null and _find_button(tab, "Buy a piglet (35 gold) - Pig") != null, "it offers the four young animals with their prices, in a town")
	var gold := d.heir.gold
	buy_btn.pressed.emit()
	await _frames(2)
	ok(d.roster.size() == 1 and d.roster[0]["species"] == "sheep" and gold - d.heir.gold == 40 and changes[0] == 1, "buying a lamb adds it, pays, and tells the screen behind")
	ok(_find_label(tab, "Kept: 1 of %d" % GameRoster.cap(d)) != null, "and the tab shows it kept")
	ok(_find_button(tab, "Slaughter (%s gold)" % GameText.num(GameFarm.slaughter_value(d.roster[0]))) != null, "a lamb can be slaughtered")
	# slaughter on a second tap
	var value := GameFarm.slaughter_value(d.roster[0])
	var sl := _find_button(tab, "Slaughter (%s gold)" % GameText.num(value))
	var g2 := d.heir.gold
	sl.pressed.emit()
	await _frames(2)
	ok(d.roster.size() == 1 and d.heir.gold == g2, "the first tap slaughters nothing")
	var sure := _find_button(tab, "Slaughter for %s? Tap again" % GameText.num(value))
	ok(sure != null, "it asks again")
	sure.pressed.emit()
	await _frames(2)
	ok(d.roster.is_empty() and d.heir.gold == g2 + value and changes[0] == 2, "the second tap slaughters, pays and tells the screen behind")
	# a wild creature has no Slaughter button
	var wild := GameRoster.add(d, "wolf", "Ash")
	wild["stage"] = "adult"
	var tab2 := await _panel(d)
	ok(_find_label(tab2, "Ash  (dire wolf)") != null and not _find_button_prefix(tab2, "Slaughter"), "a wild creature has no Slaughter button")
	# outside a town the market is shut and says why
	d.world.location = "greenvale"
	var tab3 := await _panel(d)
	var shut := _find_button(tab3, buy_label)
	ok(shut != null and shut.disabled and _find_label(tab3, "The market is in a town.") != null, "away from a town the buttons are off and the tab says why")
	app.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(DIR + "save.json")


func _find_button_prefix(n: Node, prefix: String) -> bool:
	if n is Button and (n as Button).is_visible_in_tree() and (n as Button).text.begins_with(prefix):
		return true
	for c in n.get_children():
		if _find_button_prefix(c, prefix):
			return true
	return false
