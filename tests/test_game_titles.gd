## Titles (data/titles/titles.json, GameTitles): earned from the dynasty's own state, worn one at a time after the
## heir's name, personal (ending with the heir, kept in their record) or house (kept by the dynasty). The data is
## sound and every title can be earned; each kind of condition works and a malformed one is false; earning is
## idempotent, in the data's order and draws no die; a save holds only what was earned and loads from old and damaged
## saves; the worn title's perk lowers prices and is nothing when none is worn; the autopilot never earns a title
## so its lives are not changed; and on the screens the worn title shows under the name, a new title is told in the
## journal once, and the Chronicle's Titles tab lists, explains and puts titles on and off.
## Run: godot --headless --path . -s res://tests/test_game_titles.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const ChroniclePanel := preload("res://ui/play/chronicle_panel.gd")
const DIR := "user://test_titles/"

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
	test_conditions()
	test_earning()
	test_saving()
	test_wearing()
	test_perk()
	test_succession()
	test_autopilot_untouched()
	await test_screens()
	print("%d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh(seed_val: int = 5) -> GameDynasty:
	var d := GameDynasty.new_game(seed_val, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


## A dynasty with every count high and every legend slain by this heir, so every title's condition holds.
func _maxed() -> GameDynasty:
	var d := _fresh()
	d.heir.level = 1000
	d.heir.battles_won = 1000
	d.heir.kills = {"wolf": 500, "slime": 500}
	d.heir.gold = 1000000
	d.heir.clean_streak = 50
	d.heir.age = d.heir.lifespan
	d.heir.spells = GameCombat.spell_ids().slice(0, 12)
	for i in 6:
		d.heir.children.append(GameHeir.new())
	for id in ["bren_cask", "sister_oriel", "tarsk_ember_eye"]:
		d.party.members.append({"id": id, "name": id})
	d.gen = 1200
	for c in GameData.creatures:
		if c.get("boss", false):
			d.slain_bosses[str(c["id"])] = d.gen
	d.house = {"hall": 3, "yard": 3}
	d.world.year = 500.0
	d.heirlooms = [{"name": "a"}, {"name": "b"}, {"name": "c"}]
	return d


# ---------------------------------------------------------------- the data

func test_data() -> void:
	var found := GameTitles.validate()
	ok(found.is_empty(), "the titles data is sound" + ("" if found.is_empty() else ": " + str(found.slice(0, 4))))
	var list := GameTitles.defs()
	var personal := list.filter(func(t): return t["kind"] == "personal").size()
	var house := list.filter(func(t): return t["kind"] == "house").size()
	ok(list.size() >= 20 and personal >= 10 and house >= 5, "there are many titles of both kinds (%d personal, %d house)" % [personal, house])
	var d := _maxed()
	var got := GameTitles.update(d)
	ok(got.size() == list.size(), "every title can be earned: a dynasty with everything high earns all %d (%d)" % [list.size(), got.size()])
	ok(GameTitles.earned(d).size() == list.size(), "and holds them all")
	var legends := list.filter(func(t): return str(t["id"]).begins_with("slayer_")).size()
	ok(legends == GameData.creatures.filter(func(c): return c.get("boss", false)).size(), "there is a slayer title for each legend (%d)" % legends)
	# a broken title is found
	var saved: Dictionary = GameData.titles.duplicate(true)
	GameData.titles["titles"].append({"id": "bad", "name": "x", "kind": "weird", "about": "", "when": {"stat": "nonsense", "gte": 1}, "perk": {"magic": 1}})
	GameData.titles["titles"].append({"id": "blooded", "name": "dup", "kind": "personal", "about": "x", "when": {"boss": "no_such_legend"}})
	var problems := GameTitles.validate()
	ok(problems.any(func(p): return "kind must be" in p) and problems.any(func(p): return "not something titles count" in p) and problems.any(func(p): return "perk 'magic'" in p), "an unknown kind, stat and perk are each found")
	ok(problems.any(func(p): return "listed twice" in p) and problems.any(func(p): return "not a legend" in p) and problems.any(func(p): return "needs about" in p), "a duplicate id, a legend that does not exist and a missing text are found")
	GameData.titles = saved


# ---------------------------------------------------------------- the conditions

func test_conditions() -> void:
	var d := _fresh()
	d.heir.level = 30
	d.heir.gold = 500
	ok(GameTitles.met(d, {"stat": "level", "gte": 30}) and not GameTitles.met(d, {"stat": "level", "gte": 31}), "gte holds at the number and not above it")
	ok(GameTitles.met(d, {"stat": "gold", "lte": 500}) and not GameTitles.met(d, {"stat": "gold", "lte": 499}), "lte likewise")
	ok(GameTitles.met(d, {"stat": "level", "gte": 20, "lte": 40}) and not GameTitles.met(d, {"stat": "level", "gte": 20, "lte": 25}), "a range holds both ways")
	ok(not GameTitles.met(d, {"stat": "level"}), "a stat condition with no number is false")
	ok(not GameTitles.met(d, {"stat": "no_such_stat", "gte": 0}) or GameTitles.stat(d, "no_such_stat") == 0.0, "an unknown stat counts 0")
	var all_ok := GameTitles.met(d, {"all": [{"stat": "level", "gte": 30}, {"stat": "gold", "gte": 500}]})
	var all_no := GameTitles.met(d, {"all": [{"stat": "level", "gte": 30}, {"stat": "gold", "gte": 501}]})
	ok(all_ok and not all_no, "all needs every one")
	ok(GameTitles.met(d, {"any": [{"stat": "level", "gte": 99}, {"stat": "gold", "gte": 500}]}) and not GameTitles.met(d, {"any": [{"stat": "level", "gte": 99}]}), "any needs one")
	ok(GameTitles.met(d, {"not": {"stat": "level", "gte": 99}}) and not GameTitles.met(d, {"not": {"stat": "level", "gte": 1}}), "not turns it round")
	ok(GameTitles.met(d, [{"stat": "level", "gte": 1}, {"stat": "gold", "gte": 1}]) and not GameTitles.met(d, [{"stat": "level", "gte": 1}, {"stat": "gold", "gte": 9999}]), "a list means all of them")
	ok(GameTitles.met(d, []) and not GameTitles.met(d, {}), "an empty list holds and an empty condition does not")
	d.flags["saved_the_village"] = 1
	ok(GameTitles.met(d, {"flag": "saved_the_village"}) and not GameTitles.met(d, {"flag": "other"}), "a story flag")
	ok(GameTitles.met(d, {"trait": d.heir.traits[0]}) and not GameTitles.met(d, {"trait": "no_such_trait"}), "a trait the heir shows")
	ok(GameTitles.met(d, {"class": "warrior"}) and not GameTitles.met(d, {"class": "mage"}), "the heir's class")
	ok(GameTitles.met(d, {"race": "human"}) and not GameTitles.met(d, {"race": "elf"}), "and race")
	ok(GameTitles.met(d, {"family": false}) and not GameTitles.met(d, {"family": true}), "whether a family is founded")
	d.slain_bosses["grimfang"] = d.gen
	d.slain_bosses["vaerthax"] = d.gen - 1
	ok(GameTitles.met(d, {"boss": "grimfang"}) and GameTitles.met(d, {"boss": "vaerthax"}) and not GameTitles.met(d, {"boss": "hollow_king"}), "a legend the house has slain")
	ok(GameTitles.met(d, {"boss_by_heir": "grimfang"}) and not GameTitles.met(d, {"boss_by_heir": "vaerthax"}), "and one this heir slew, not an ancestor")
	for bad in ["a string", 5, null, {"unknown": 1}, {"all": "no"}, {"any": 3}]:
		ok(not GameTitles.met(d, bad), "a malformed condition is false: %s" % str(bad))
	ok(GameTitles.stat(d, "age_share") > 0.0 and GameTitles.stat(d, "party") == 0.0, "the other counts read the dynasty")


# ---------------------------------------------------------------- earning

func test_earning() -> void:
	var d := _fresh()
	var pot := d.rng.state
	ok(GameTitles.update(d).is_empty() and GameTitles.earned(d).is_empty(), "a new dynasty has earned nothing")
	ok(GameTitles.worn(d) == "" and GameTitles.display_name(d) == "Tess %s" % d.heir.surname and GameTitles.perk(d, "persuasion") == 0.0, "wears nothing, is called by name, and has no perk")
	d.heir.battles_won = 1
	var first := GameTitles.update(d)
	ok(first == ["blooded"], "a first win earns the Blooded: %s" % str(first))
	ok(GameTitles.update(d).is_empty(), "asking again earns nothing more")
	d.heir.level = 60
	d.heir.battles_won = 30
	var more := GameTitles.update(d)
	ok(more == ["veteran", "seasoned", "mighty"], "the rest come in the data's order: %s" % str(more))
	ok(GameTitles.earned(d) == ["blooded", "veteran", "seasoned", "mighty"], "and are all held")
	ok(d.rng.state == pot, "earning draws no die")
	d.gen = 10
	var h := GameTitles.update(d)
	ok(h == ["house_ten"] and d.house_titles == ["house_ten"] and "house_ten" not in d.heir.titles, "a house title goes to the house, not the heir")
	d.state = "succession"
	d.heir.battles_won = 5000
	ok(GameTitles.update(d).is_empty(), "a dead heir earns nothing")
	ok(GameTitles.update(null).is_empty(), "and nothing is earned of no dynasty")
	d.state = "life"
	# the journal tells it, once
	var e := _fresh()
	e.heir.battles_won = 1
	var before := e.journal.size()
	var told := GameTitles.announce(e)
	ok(told == ["blooded"] and e.journal.size() == before + 1 and "earns a title: the Blooded" in e.journal.back(), "announce tells a new title in the journal")
	ok(GameTitles.announce(e).is_empty() and e.journal.size() == before + 1, "and not again")


# ---------------------------------------------------------------- saving

func _reload(d: GameDynasty) -> GameDynasty:
	var parsed = JSON.parse_string(JSON.stringify(d.to_save()))
	if typeof(parsed) != TYPE_DICTIONARY or GameSaveVersion.upgrade(parsed) != "":
		return null
	return GameDynasty.from_dict(parsed)


func test_saving() -> void:
	var d := _fresh()
	var plain := d.to_dict()
	ok(not plain.has("house_titles") and not plain["heir"].has("titles") and not plain["heir"].has("title_worn"), "a dynasty with no titles saves none of the keys")
	d.heir.battles_won = 1
	d.gen = 10
	GameTitles.update(d)
	GameTitles.wear(d, "house_ten")
	var back := _reload(d)
	ok(back != null and back.heir.titles == ["blooded"] and back.house_titles == ["house_ten"] and back.heir.title_worn == "house_ten", "earned titles and the one worn survive a save and load")
	ok(GameTitles.display_name(back) == "Tess %s, Heir of Ten Generations" % back.heir.surname, "and the name shows it")
	# a save from before titles
	var old: Dictionary = JSON.parse_string(JSON.stringify(_fresh().to_save()))
	var o := GameDynasty.from_dict(old)
	ok(o != null and o.heir.titles.is_empty() and o.house_titles.is_empty() and o.heir.title_worn == "", "a save from before titles loads with none")
	# damaged saves
	for bad in ["blooded", 5, null, {"a": 1}, [1, "nope", "blooded", "blooded", null, ["x"]]]:
		var s: Dictionary = JSON.parse_string(JSON.stringify(_fresh().to_save()))
		s["heir"]["titles"] = bad
		s["house_titles"] = bad
		s["heir"]["title_worn"] = bad
		var g := GameDynasty.from_dict(s)
		var want: Array = ["blooded"] if typeof(bad) == TYPE_ARRAY else []
		ok(g != null and g.heir.titles == want and g.house_titles == want, "damaged title lists load clean: %s" % str(bad))
		ok(g != null and (g.heir.title_worn == "" or typeof(bad) == TYPE_STRING and g.heir.title_worn == bad), "and a damaged worn title is dropped: %s" % str(bad))
	var unknown: Dictionary = JSON.parse_string(JSON.stringify(_fresh().to_save()))
	unknown["heir"]["titles"] = ["blooded", "from_a_newer_game"]
	unknown["heir"]["title_worn"] = "from_a_newer_game"
	var u := GameDynasty.from_dict(unknown)
	ok(u.heir.titles == ["blooded"] and u.heir.title_worn == "", "a title this game does not know is dropped, not crashed on")
	# a title worn that is not held is not worn
	var s2: Dictionary = JSON.parse_string(JSON.stringify(_fresh().to_save()))
	s2["heir"]["title_worn"] = "veteran"
	var w := GameDynasty.from_dict(s2)
	ok(GameTitles.worn(w) == "" and GameTitles.display_name(w) == w.heir.full_name(), "a worn title the heir has not earned is not worn")


# ---------------------------------------------------------------- wearing

func test_wearing() -> void:
	var d := _fresh()
	ok(not GameTitles.wear(d, "blooded") and d.heir.title_worn == "", "a title not earned cannot be worn")
	ok(not GameTitles.wear(d, "no_such_title"), "nor one that does not exist")
	d.heir.battles_won = 1
	d.gen = 10
	GameTitles.update(d)
	ok(GameTitles.wear(d, "blooded") and GameTitles.worn(d) == "blooded", "an earned title is worn")
	ok(GameTitles.display_name(d) == "Tess %s, the Blooded" % d.heir.surname, "after the name, with a comma")
	ok(GameTitles.wear(d, "house_ten") and GameTitles.worn(d) == "house_ten", "wearing another puts the first away: one at a time")
	GameTitles.unwear(d)
	ok(GameTitles.worn(d) == "" and GameTitles.display_name(d) == d.heir.full_name(), "and it can be taken off")
	ok(GameTitles.perk_text({"perk": {"persuasion": 0.02}}) == "cheaper shops +2%" and GameTitles.perk_text({}) == "", "a perk is told in words")


# ---------------------------------------------------------------- the perk

func test_perk() -> void:
	var d := _maxed()
	d.heir.gold = 1000000
	GameTitles.update(d)
	var base_persuasion := GameItems.persuasion(d)
	var base_potion := d.potion_price()
	var base_mult := GameItems.price_mult(d)
	ok(GameTitles.worn(d) == "", "none is worn yet")
	GameTitles.wear(d, "wealthy")
	ok(is_equal_approx(GameTitles.perk(d, "persuasion"), 0.02) and GameTitles.perk(d, "nothing_else") == 0.0, "the Wealthy gives 2% off, and nothing else")
	ok(is_equal_approx(GameItems.persuasion(d), base_persuasion + 0.02), "which is added to the heir's own haggling")
	ok(d.potion_price() < base_potion and GameItems.price_mult(d) < base_mult, "so potions and shop prices are lower")
	GameTitles.unwear(d)
	ok(GameItems.persuasion(d) == base_persuasion and d.potion_price() == base_potion and GameItems.price_mult(d) == base_mult, "and nothing worn gives exactly what it did before")
	GameTitles.wear(d, "blooded") if "blooded" in GameTitles.earned(d) else null
	ok(GameItems.persuasion(d) == base_persuasion, "a title with no perk changes nothing")


# ---------------------------------------------------------------- succession

func test_succession() -> void:
	var d := _fresh()
	d.heir.battles_won = 30
	d.gen = 10
	GameTitles.update(d)
	GameTitles.wear(d, "veteran")
	var personal: Array = d.heir.titles.duplicate()
	ok(personal == ["blooded", "veteran"] and d.house_titles == ["house_ten"], "an heir with two personal titles and a house one")
	d._die("old age")
	ok(d.state == "succession" and d.history.back().get("titles", []) == personal, "the heir's personal titles go into their record")
	d.choose_heir(0)
	ok(d.state == "life" and d.heir.titles.is_empty() and d.heir.title_worn == "", "the next heir starts with none of them and wears nothing")
	ok(d.house_titles == ["house_ten"] and GameTitles.earned(d) == ["house_ten"], "but the house's titles are theirs to wear")
	ok(GameTitles.wear(d, "house_ten") and not GameTitles.wear(d, "veteran"), "they can wear the house's, and not their parent's own")
	# an heir with no titles leaves a record with no title key
	var e := _fresh()
	e._die("old age")
	ok(not e.history.back().has("titles"), "a record with no titles has no title key")


# ---------------------------------------------------------------- the autopilot

func test_autopilot_untouched() -> void:
	var a := GameDynasty.new_game(11, "Bot", "mage", "faetouched", "elf")
	var b := GameDynasty.new_game(11, "Bot", "mage", "faetouched", "elf")
	for d in [a, b]:
		GameBot.live_life(d)
	ok(a.heir.titles.is_empty() and a.house_titles.is_empty() and a.history.back().get("titles", []).is_empty(), "the autopilot's life earns no title: nothing in a life asks for one")
	ok(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()), "so two lives of one seed are the same, as they were")
	var dice := b.rng.state
	var earned := GameTitles.update(b)
	ok(b.rng.state == dice, "asking for titles afterwards draws no die")
	var plain: Dictionary = a.to_dict().duplicate(true)
	var with: Dictionary = b.to_dict().duplicate(true)
	for k in ["house_titles"]:
		with.erase(k)
	(with["heir"] as Dictionary).erase("titles")
	ok(JSON.stringify(plain) == JSON.stringify(with), "and the only thing it changes in the save is the titles (%d earned)" % earned.size())


# ---------------------------------------------------------------- the screens

func _find_button(n: Node, start: String) -> Button:
	if n is Button and (n as Button).is_visible_in_tree() and (n as Button).text.begins_with(start):
		return n
	for c in n.get_children():
		var b := _find_button(c, start)
		if b != null:
			return b
	return null


func _find_label(n: Node, text: String) -> Label:
	if n is Label and (n as Label).is_visible_in_tree() and (n as Label).text == text:
		return n
	for c in n.get_children():
		var l := _find_label(c, text)
		if l != null:
			return l
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
	app.new_game("Tess", "warrior", "faetouched", 77, "human")
	var d: GameDynasty = app.dynasty
	d.pending_event = {}
	# a new title is told when the screen is shown, once
	d.heir.battles_won = 1
	app.show_state()
	await _frames(3)
	ok(d.heir.titles == ["blooded"], "showing the screen awards the title the heir has earned")
	var told := d.journal.filter(func(l): return "earns a title: the Blooded" in str(l)).size()
	ok(told == 1, "and tells it in the journal")
	app.show_state()
	await _frames(3)
	ok(d.journal.filter(func(l): return "earns a title" in str(l)).size() == 1, "once, however often the screen is shown")
	ok(_find_label(app.current, "the Blooded") == null, "a title earned but not worn is not shown under the name")
	# the Chronicle's Titles tab
	var changes := [0]
	var c := ChroniclePanel.new()
	c.dynasty = d
	c.on_change = func(): changes[0] += 1
	app.current.add_child(c)
	await _frames(3)
	var tab := _tab(c, "Titles")
	ok(tab != null, "the Chronicle has a Titles tab")
	if tab == null:
		return
	(tab.get_parent() as TabContainer).current_tab = tab.get_index()   # a tab's contents show only when it is the one open
	await _frames(2)
	var wear := _find_button(tab, "Wear")
	ok(wear != null and not wear.disabled, "the earned title has a Wear button")
	ok(_find_label(tab, "the Blooded  (personal)") != null, "named, with its kind")
	ok(_find_label(tab, "Slayer of Grimfang  (personal)") != null, "and the titles not yet earned are listed with how to earn them")
	wear.pressed.emit()
	await _frames(2)
	ok(d.heir.title_worn == "blooded" and changes[0] == 1, "pressing it wears the title and tells the screen behind")
	var worn_btn := _find_button(tab, "Worn")
	ok(worn_btn != null and worn_btn.disabled, "the worn title shows Worn and cannot be worn again")
	ok(_find_label(tab, "Wearing: Tess %s, the Blooded" % d.heir.surname) != null, "and the tab says what is worn")
	var off := _find_button(tab, "Take off")
	ok(off != null, "there is a way to take it off")
	if off != null:
		off.pressed.emit()
		await _frames(2)
		ok(d.heir.title_worn == "" and changes[0] == 2, "taking it off")
	c.queue_free()
	await _frames(2)
	# on the life screen, the worn title shows under the name
	GameTitles.wear(d, "blooded")
	app.show_state()
	await _frames(3)
	ok(_find_label(app.current, "the Blooded") != null, "the worn title shows under the heir's name on the life screen")
	# a dead heir's tab cannot wear anything, and the lineage names the titles
	d._die("old age")
	var c2 := ChroniclePanel.new()
	c2.dynasty = d
	app.current.add_child(c2)
	await _frames(3)
	var tab2 := _tab(c2, "Titles")
	if tab2 != null:
		(tab2.get_parent() as TabContainer).current_tab = tab2.get_index()
		await _frames(2)
	var w2 := _find_button(tab2, "Wear") if tab2 != null else null
	var worn2 := _find_button(tab2, "Worn") if tab2 != null else null
	ok(w2 == null or w2.disabled, "after the heir has died nothing can be put on")
	ok(worn2 == null or worn2.disabled, "or taken off")
	var lineage := _tab(c2, "Lineage") as RichTextLabel
	if tab2 != null:
		(tab2.get_parent() as TabContainer).current_tab = 0
		await _frames(2)
	ok(lineage != null and "titles: the Blooded" in lineage.text, "the lineage names the titles of the heir who died")
	c2.queue_free()
	await _frames(2)
	app.queue_free()
	await _frames(2)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
