## Subclasses (roadmap item 60, first part): the data and its validator, the perk arithmetic (plain and founded, with a
## floor), what taking one costs and who can, picking one at the founding, a child born to the calling (on dice that
## are not the dynasty's), what the Breeder's perks do to finding, keeping, breeding and selling, saving (old and
## damaged saves), and the screens (the title screen's pick, the Chronicle's Subclass tab). With no subclass every
## number is exactly what it was.
## Run: godot --headless --path . -s res://tests/test_game_subclass.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const ChroniclePanel := preload("res://ui/play/chronicle_panel.gd")
const TitleScreen := preload("res://ui/play/title_screen.gd")
const DIR := "user://test_subclass/"

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
	test_perks()
	test_cost_and_take()
	test_founding()
	test_succession()
	test_effects()
	test_saving()
	await test_screens()
	print("%d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func dyn(seed_value: int = 5, sub: String = "") -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human", GameSex.MALE, sub)
	d.pending_event = {}
	d.heir.gold = 100000
	d.house[GameHouse.RANCH] = 3
	return d


func _with(edit: Callable, body: Callable) -> void:
	var saved: Dictionary = GameSubclass.data().duplicate(true)
	edit.call(GameSubclass.data())
	body.call()
	GameSubclass._cache = saved


func test_data() -> void:
	ok(GameSubclass.validate().is_empty(), "subclasses.json is sound: %s" % str(GameSubclass.validate()))
	ok(GameSubclass.has("breeder") and not GameSubclass.has("nonesuch") and GameSubclass.name_of("breeder") == "Breeder", "the Breeder exists")
	_with(func(x): x["subclasses"][0]["perks"]["telepathy"] = 2.0, func(): ok(not GameSubclass.validate().is_empty(), "an unknown perk is found"))
	_with(func(x): x["subclasses"][0]["perks"]["find_mult"] = 0.0, func(): ok(not GameSubclass.validate().is_empty(), "a perk of zero is found"))
	_with(func(x): x["subclasses"][0]["perks"] = {}, func(): ok(not GameSubclass.validate().is_empty(), "a subclass with no perks is found"))
	_with(func(x): x["subclasses"].append(x["subclasses"][0].duplicate(true)), func(): ok(not GameSubclass.validate().is_empty(), "a repeated id is found"))
	_with(func(x): x["settings"]["founder_scale"] = 0.5, func(): ok(not GameSubclass.validate().is_empty(), "a founded strength below plain is found"))
	_with(func(x): x["settings"]["inherit_chance"] = 2.0, func(): ok(not GameSubclass.validate().is_empty(), "a chance above 1 is found"))
	_with(func(x): x["settings"]["change_cost_mult"] = 0.5, func(): ok(not GameSubclass.validate().is_empty(), "changing for less than taking is found"))
	_with(func(x): x["text"].erase("taken"), func(): ok(not GameSubclass.validate().is_empty(), "missing text is found"))
	_with(func(x): x["subclasses"][0].erase("about"), func(): ok(not GameSubclass.validate().is_empty(), "a subclass with no about is found"))
	ok(GameSubclass.validate().is_empty(), "the data is put back")


func test_perks() -> void:
	var d := dyn()
	ok(GameSubclass.perk(d.heir, "find_mult") == 1.0 and GameSubclass.perk(null, "find_mult") == 1.0, "with no subclass every perk is exactly 1")
	d.heir.subclass = "breeder"
	d.heir.subclass_founded = false
	ok(is_equal_approx(GameSubclass.perk(d.heir, "find_mult"), 1.4), "taken later, a perk is at its plain strength")
	d.heir.subclass_founded = true
	ok(is_equal_approx(GameSubclass.perk(d.heir, "find_mult"), 1.0 + 0.4 * 1.5), "founded, it is stronger: %s" % GameSubclass.perk(d.heir, "find_mult"))
	ok(is_equal_approx(GameSubclass.perk(d.heir, "keep_mult"), 1.0 - 0.15 * 1.5), "a perk below 1 is cheaper still when founded")
	ok(GameSubclass.perk(d.heir, "nonesuch") == 1.0, "a perk the subclass does not name is 1")
	_with(func(x): x["subclasses"][0]["perks"]["keep_mult"] = 0.2, func(): ok(GameSubclass.perk(d.heir, "keep_mult") >= 0.1, "a perk never falls below the floor"))
	var plain := GameSubclass.perk_lines(d.heir, "breeder", false)
	var founded := GameSubclass.perk_lines(d.heir, "breeder", true)
	ok(plain.size() == 5 and founded.size() == 5, "five perks")
	ok(plain.any(func(l): return l == "The chance of finding eggs and young: 40% more") and founded.any(func(l): return l == "The chance of finding eggs and young: 60% more"), "told in words, at either strength: %s | %s" % [plain, founded])
	ok(plain.any(func(l): return "15% less" in l), "a perk below 1 is told as less")


func test_cost_and_take() -> void:
	var d := dyn()
	var base := int(round(300.0 * GameData.enemy_scale(d.gen)))
	ok(GameSubclass.cost(d, "breeder") == base, "taking one costs the base price, scaled by the generation")
	var later := dyn()
	later.gen = 30
	ok(GameSubclass.cost(later, "breeder") > base, "dearer in a later generation")
	var gold := d.heir.gold
	var line := GameSubclass.take(d, "breeder")
	ok(d.heir.subclass == "breeder" and not d.heir.subclass_founded and gold - d.heir.gold == base, "taking pays and sets it, not founded")
	ok("takes up the calling of a Breeder" in line and d.journal.back() == line, "and tells it, in the journal too: %s" % line)
	ok(GameSubclass.why_not(d, "breeder") != "" and GameSubclass.take(d, "breeder") == "", "taking the same again is refused")
	var poor := dyn()
	poor.heir.gold = 10
	ok("Not enough gold" in GameSubclass.why_not(poor, "breeder") and GameSubclass.take(poor, "breeder") == "" and poor.heir.subclass == "" and poor.heir.gold == 10, "without the gold, nothing is taken")
	ok(GameSubclass.take(dyn(), "nonesuch") == "", "an unknown subclass is refused")
	var dead := dyn()
	dead.state = "succession"
	ok(GameSubclass.take(dead, "breeder") == "" and "living heir" in GameSubclass.why_not(dead, "breeder"), "nothing is taken outside a life")
	# changing costs more, and loses the founded strength
	_with(func(x): x["subclasses"].append({"id": "keeper", "name": "Keeper", "about": "x", "perks": {"keep_mult": 0.9}}), func():
		var c := dyn(5, "breeder")
		ok(c.heir.subclass_founded, "(founded)")
		var price := GameSubclass.cost(c, "keeper")
		ok(price == int(round(300.0 * GameData.enemy_scale(c.gen) * 2.0)), "changing costs double")
		var before := c.heir.gold
		var l := GameSubclass.take(c, "keeper")
		ok(c.heir.subclass == "keeper" and not c.heir.subclass_founded and before - c.heir.gold == price and "gives up the calling of a Breeder" in l, "a change pays double and is no longer founded: %s" % l))


func test_founding() -> void:
	var d := dyn(5, "breeder")
	ok(d.heir.subclass == "breeder" and d.heir.subclass_founded, "a dynasty can be founded in a subclass, at the stronger strength")
	ok(dyn(5, "").heir.subclass == "" and dyn(5, "nonesuch").heir.subclass == "", "none, or an unknown one, leaves none")
	# the founding pick changes no dice
	var a := GameDynasty.new_game(11, "Tess", "warrior", "faetouched", "human")
	var b := GameDynasty.new_game(11, "Tess", "warrior", "faetouched", "human", GameSex.MALE, "breeder")
	ok(a.rng.state == b.rng.state and a.heir.surname == b.heir.surname and a.heir.traits == b.heir.traits, "picking one at the founding changes nothing else about the dynasty")
	ok(not a.to_dict()["heir"].has("subclass"), "a dynasty with none saves no subclass keys")


func test_succession() -> void:
	var born := 0
	var tries := 600
	for s in range(1, tries + 1):
		var d := dyn(s, "breeder")
		var c := GameHeir.new()
		c.id = 999
		var line := GameSubclass.on_succession(d, d.heir, c)
		if line != "":
			born += 1
			ok(c.subclass == "breeder" and c.subclass_founded and "is born to the calling of a Breeder" in line, "a child born to it is founded") if born == 1 else null
	var rate := float(born) / float(tries)
	ok(absf(rate - 0.5) < 0.07, "about half the children are born to the calling (%.3f)" % rate)
	var p := dyn(3)
	var kid := GameHeir.new()
	kid.id = 5
	ok(GameSubclass.on_succession(p, p.heir, kid) == "" and kid.subclass == "", "a parent with none passes none")
	var a := dyn(8, "breeder")
	var b := dyn(8, "breeder")
	var k1 := GameHeir.new()
	var k2 := GameHeir.new()
	k1.id = 7
	k2.id = 7
	GameSubclass.on_succession(a, a.heir, k1)
	GameSubclass.on_succession(b, b.heir, k2)
	ok(k1.subclass == k2.subclass, "the same seed and child give the same answer")
	var before := a.rng.state
	GameSubclass.on_succession(a, a.heir, k1)
	ok(a.rng.state == before, "the roll draws nothing from the dynasty's dice")
	# a whole succession: a child may be born to the calling, and the rest is the same as without it
	var seen_inherit := false
	var seen_none := false
	for s2 in range(1, 60):
		var q := dyn(s2, "breeder")
		q.heir.age = maxf(q.heir.age, 25.0)
		q.found_family()
		if q.heir.children.is_empty():
			continue
		q.state = "succession"
		q.candidates = q.heir.children
		q.choose_heir(0)
		if q.heir.subclass == "breeder":
			seen_inherit = true
			ok(q.heir.subclass_founded, "a child born to it is founded")
		else:
			seen_none = true
	ok(seen_inherit and seen_none, "through a real succession some heirs are born to the calling and some are not")


func test_effects() -> void:
	var none := dyn()
	var br := dyn(5, "breeder")
	var tk := dyn()
	GameSubclass.take(tk, "breeder")
	for dd in [none, br, tk]:
		dd.house.erase(GameHouse.RANCH)   # no hatchery or nursery discounts muddying the comparison
	none.heir.traits = []
	none.heir.dormant = []
	br.heir.traits = []
	br.heir.dormant = []
	tk.heir.traits = []
	tk.heir.dormant = []
	var base := GameFinding.chance(none.heir, "wolf")
	var plain := GameFinding.chance(tk.heir, "wolf")
	var founded := GameFinding.chance(br.heir, "wolf")
	ok(is_equal_approx(plain, base * 1.4) and is_equal_approx(founded, base * 1.6), "a Breeder finds young more often, a founded one more so (%s, %s, %s)" % [base, plain, founded])
	# keep
	var e0 := GameRoster.add(none, "wolf", "A")
	var e1 := GameRoster.add(tk, "wolf", "A")
	var e2 := GameRoster.add(br, "wolf", "A")
	ok(GameRanch.yearly_keep(e0, none) == GameRanch.yearly_keep(e0) and GameRanch.yearly_keep(e1, tk) < GameRanch.yearly_keep(e0, none) and GameRanch.yearly_keep(e2, br) < GameRanch.yearly_keep(e1, tk), "keeping costs less for a Breeder, and still less for a founded one")
	# selling
	for e in [e0, e1, e2]:
		e["stage"] = "adult"
		e["mood"] = 100
	ok(GameRanch.sell_price(e1, tk) > GameRanch.sell_price(e0, none) and GameRanch.sell_price(e2, br) > GameRanch.sell_price(e1, tk), "a Breeder sells creatures dearer")
	ok(GameRanch.sell_price(e0) == GameRanch.sell_price(e0, none), "with no subclass a price is exactly what it was")
	# fertility
	var m := {"species": "wolf", "traits": []}
	var f := {"species": "wolf", "traits": []}
	ok(GameBreeding.fertility(m, f, none) == GameBreeding.fertility(m, f) and GameBreeding.fertility(m, f, tk) > GameBreeding.fertility(m, f, none), "a Breeder's pairs are more fertile, others exactly as before")
	# mutation: with a certain-ish chance the perk shows in the births
	var muts := [0, 0]
	for s in range(1, 401):
		for i in 2:
			var d := dyn(s, "breeder" if i == 1 else "")
			var fe := GameRoster.add(d, "wolf", "M")
			var ma := GameRoster.add(d, "wolf", "F")
			fe["stage"] = "adult"; ma["stage"] = "adult"
			fe["sex"] = GameSex.FEMALE; ma["sex"] = GameSex.MALE
			fe["breeding"] = true; ma["breeding"] = true
			var saved: Dictionary = GameBreeding.data().duplicate(true)
			GameBreeding.data()["settings"]["fertility"] = {"pure": 1.0, "hybrid": 1.0, "cross": 1.0}
			GameBreeding.on_years(d, 1.0, [], 1.0)
			GameBreeding._cache = saved
			if d.roster.size() > 2 and not d.roster[2]["traits"].is_empty():
				muts[i] += 1
	ok(muts[1] > muts[0], "a Breeder's young mutate more often (%d against %d of 400)" % [muts[1], muts[0]])
	# no subclass: the whole pipeline is unchanged
	var a := dyn(9)
	var b := dyn(9)
	for dd in [a, b]:
		var x := GameRoster.add(dd, "wolf", "A")
		x["stage"] = "adult"
	for i in 5:
		a.pass_time(1.0)
		b.pass_time(1.0)
	ok(a.to_dict() == b.to_dict(), "two lives with no subclass stay identical")


func test_saving() -> void:
	var d := dyn(5, "breeder")
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(back.heir.subclass == "breeder" and back.heir.subclass_founded, "a subclass and its strength survive a save and load")
	var t := dyn()
	GameSubclass.take(t, "breeder")
	ok(GameDynasty.from_dict(JSON.parse_string(JSON.stringify(t.to_dict()))).heir.subclass_founded == false, "a taken one stays plain")
	var old := d.to_dict()
	old["heir"].erase("subclass")
	old["heir"].erase("subclass_founded")
	ok(GameDynasty.from_dict(old).heir.subclass == "", "an old save loads with none")
	for bad in [5, null, ["breeder"], {"a": 1}, "nonesuch", ""]:
		var s := d.to_dict()
		s["heir"]["subclass"] = bad
		ok(GameDynasty.from_dict(s).heir.subclass == "", "a damaged subclass loads as none: %s" % str(bad))
	var s2 := d.to_dict()
	s2["heir"]["subclass_founded"] = "yes"
	ok(GameDynasty.from_dict(s2).heir.subclass_founded == false, "a founded flag that is not a bool is off")
	ok(not dyn().to_dict()["heir"].has("subclass_founded"), "a heir with none saves neither key")


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
	# the title screen: a subclass pick that founds the dynasty in it
	var title: Control = null
	for c in app.get_children():
		if c is TitleScreen or c.get_script() == TitleScreen:
			title = c
	if title == null:
		for c in app.find_children("*", "Control", true, false):
			if c.get_script() == TitleScreen:
				title = c
	ok(title != null, "the title screen is up")
	if title != null:
		ok(title.subclass_pick.item_count == 2 and title.subclass_pick.get_item_text(1) == "Breeder", "it offers None and the Breeder")
		ok(title.subclass_ids == ["", "breeder"] and title.subclass_pick.selected == 0, "with none chosen to begin with")
		title.subclass_pick.selected = 1
		title._refresh()
		ok("Raises creatures for a living" in title.subclass_desc.text and "60% more" in title.subclass_desc.text, "and shows what it does at the founded strength: %s" % title.subclass_desc.text)
		title.subclass_pick.selected = 0
		title._refresh()
		ok("Anyone can take one later" in title.subclass_desc.text, "and says anyone can take one later")
		title.subclass_pick.selected = 1
		title.seed_edit.text = "5"
		title._begin()
		await _frames(3)
		ok(app.dynasty != null and app.dynasty.heir.subclass == "breeder" and app.dynasty.heir.subclass_founded, "beginning from it founds the dynasty in the subclass")
	else:
		app.new_game("Tess", "warrior", "faetouched", 77, "human")
	var d: GameDynasty = app.dynasty
	d.pending_event = {}
	d.heir.subclass = ""
	d.heir.subclass_founded = false
	d.heir.gold = 100000
	# the Chronicle's Subclass tab
	var changes := [0]
	var c := ChroniclePanel.new()
	c.dynasty = d
	c.on_change = func(): changes[0] += 1
	app.current.add_child(c)
	await _frames(3)
	var tab := _tab(c, "Subclass")
	ok(tab != null, "the Chronicle has a Subclass tab")
	if tab == null:
		return
	(tab.get_parent() as TabContainer).current_tab = tab.get_index()
	await _frames(2)
	ok(_find_label(tab, "No subclass.") != null, "it says there is none")
	var price := GameText.num(GameSubclass.cost(d, "breeder"))
	var btn := _find_button(tab, "Take up the Breeder (%s gold)" % price)
	ok(btn != null and not btn.disabled, "and offers the Breeder, with its price")
	btn.pressed.emit()
	await _frames(2)
	ok(d.heir.subclass == "breeder" and not d.heir.subclass_founded and changes[0] == 1, "taking it sets it, and tells the screen behind")
	ok(_find_label(tab, "Subclass: Breeder (taken up).") != null, "the tab says what the heir is")
	ok(_find_label(tab, "The chance of finding eggs and young: 40% more") != null, "and what it does at its plain strength")
	d.heir.gold = 5
	d.heir.subclass = ""
	c.queue_free()
	var c2 := ChroniclePanel.new()
	c2.dynasty = d
	app.current.add_child(c2)
	await _frames(3)
	var tab2 := _tab(c2, "Subclass")
	(tab2.get_parent() as TabContainer).current_tab = tab2.get_index()
	await _frames(2)
	var poor := _find_button(tab2, "Take up the Breeder (%s gold)" % price)
	ok(poor != null and poor.disabled and _find_label(tab2, "Not enough gold (%s needed)." % price) != null, "without the gold the button is off and says why")
	app.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(DIR + "save.json")
