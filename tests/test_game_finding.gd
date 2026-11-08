## Finding eggs and young beside the dead (roadmap item 55, first part): the chance, the roll on its own dice,
## the roster and its saving, and the search the screens call. Nothing here may move a life: the search plays as
## before and the find draws nothing from the dynasty's dice.
## The Chronicle's Creatures tab lists what is kept, and says so when nothing is.
## Run: godot --headless --path . -s res://tests/test_game_finding.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const ChroniclePanel := preload("res://ui/play/chronicle_panel.gd")
const DIR := "user://test_finding/"

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


func _run() -> void:
	GameData.load_all()
	test_data()
	test_chance()
	test_roll()
	test_roster()
	test_saving()
	test_search()
	test_describe()
	test_more()
	await test_screens()
	print("%d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func dyn(seed_value: int = 5, cls: String = "") -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", cls if cls != "" else GameData.starting_ids(GameData.classes)[0], "faetouched", "human")
	return d


## Runs `body` with settings changed as `edit` says, then puts them back.
func _with(edit: Callable, body: Callable) -> void:
	var saved: Dictionary = GameFinding.data().duplicate(true)
	edit.call(GameFinding.data()["settings"])
	body.call()
	GameFinding._cache = saved


func foes(ids: Array) -> Array:
	return ids.map(func(i): return {"id": i, "name": "Foe " + str(i)})


func test_data() -> void:
	ok(GameFinding.validate().is_empty(), "finding.json is sound: %s" % str(GameFinding.validate()))
	var s: Dictionary = GameFinding.data()["settings"]
	ok(int(s["roster_cap"]) >= 1, "the roster has room")
	_with(func(x): x["max_chance"] = 2.0, func(): ok(not GameFinding.validate().is_empty(), "a chance above 1 is found"))
	_with(func(x): x["rarity"]["goblin"] = 1.0, func(): ok(not GameFinding.validate().is_empty(), "rarity for a creature that is not born is found"))
	_with(func(x): x["class_bonus"]["nonesuch"] = 2.0, func(): ok(not GameFinding.validate().is_empty(), "a bonus for an unknown class is found"))
	_with(func(x): x.erase("roster_cap"), func(): ok(not GameFinding.validate().is_empty(), "a missing setting is found"))
	ok(GameFinding.validate().is_empty(), "the data is put back after those edits")


func test_chance() -> void:
	var d := dyn(5, "warrior")
	d.heir.traits = []
	d.heir.dormant = []
	var base := float(GameFinding.setting("base_chance")) * (1.25 if "faetouched" in d.heir.all_traits() else 1.0)   # the test bloodline is faetouched
	ok(is_equal_approx(GameFinding.chance(d.heir, "wolf"), base), "a wolf's litter is the base chance for a warrior (%s)" % GameFinding.chance(d.heir, "wolf"))
	ok(GameFinding.chance(d.heir, "skeleton") == 0.0, "a creature that is not born leaves nothing")
	ok(GameFinding.chance(d.heir, "nonesuch") == 0.0, "an unknown creature leaves nothing")
	ok(GameFinding.chance(d.heir, "elder_dragon") < GameFinding.chance(d.heir, "wolf"), "a dragon's clutch is rarer than a wolf's litter")
	d.heir.class_id = "ranger"
	ok(GameFinding.chance(d.heir, "wolf") > base, "a ranger finds more")
	d.heir.class_id = "beastmaster"
	ok(GameFinding.chance(d.heir, "wolf") > GameFinding.chance(dyn(5, "ranger").heir, "wolf"), "a beastmaster finds more than a ranger")
	_with(func(x): x["base_chance"] = 0.4; x["max_chance"] = 0.45, func(): ok(is_equal_approx(GameFinding.chance(d.heir, "wolf"), 0.45), "the chance is capped"))
	_with(func(x): x["trait_bonus"]["keen"] = 3.0, func():
		var h := dyn(5, "warrior").heir
		h.traits = ["keen"]
		ok(GameFinding.chance(h, "wolf") > base, "a trait in the data raises it"))
	_with(func(x): x["places"]["search"] = 0.0, func(): ok(GameFinding.chance(d.heir, "wolf") == 0.0, "a place can be switched off"))


func test_roll() -> void:
	# with a certain chance, the first foe that is born leaves young
	_with(func(x): x["base_chance"] = 1.0; x["max_chance"] = 1.0, func():
		var d := dyn()
		var lines := GameFinding.after_search(d, foes(["goblin", "wolf", "drake"]))
		ok(lines.size() == 1, "one find at most")
		ok(d.roster.size() == 1 and d.roster[0]["species"] == "wolf", "the goblin leaves nothing and the wolf does")
		ok(d.roster[0]["stage"] == "young" and d.roster[0]["born"] == "live" and d.roster[0]["young"] == "pup", "a wolf's litter is a pup, already born")
		ok("pup" in lines[0] and d.roster[0]["name"] in lines[0], "the line names the young and its name")
		ok(d.journal.back() == lines[0], "it is told in the journal")
		var e := GameFinding.after_search(dyn(), foes(["drake"]))
		ok(e.size() == 1, "a drake's clutch is found")
		var d2 := dyn()
		GameFinding.after_search(d2, foes(["drake"]))
		ok(d2.roster[0]["stage"] == "egg" and "egg" in e[0] and d2.roster[0]["young"] == "hatchling", "a drake's find is an egg of a hatchling")
		ok(GameFinding.after_search(dyn(), foes(["skeleton", "ghoul"])).is_empty(), "the unborn leave nothing even when sure"))
	# a chance of nothing finds nothing, however many foes
	_with(func(x): x["base_chance"] = 0.0, func():
		var d := dyn()
		ok(GameFinding.after_search(d, foes(["wolf", "wolf", "wolf"])).is_empty() and d.roster.is_empty(), "no chance, no find"))
	# draws no die from the dynasty
	_with(func(x): x["base_chance"] = 1.0; x["max_chance"] = 1.0, func():
		var d := dyn()
		var before := d.rng.state
		GameFinding.after_search(d, foes(["wolf"]))
		ok(d.rng.state == before, "finding draws nothing from the dynasty's dice"))
	# the same seed and hunt give the same find; another hunt can differ
	var same := true
	var differ := false
	for s in range(1, 60):
		var a := dyn(s)
		var b := dyn(s)
		var la := GameFinding.after_search(a, foes(["wolf", "slime", "wolf"]))
		var lb := GameFinding.after_search(b, foes(["wolf", "slime", "wolf"]))
		same = same and la == lb and a.roster == b.roster
		var c := dyn(s)
		c.total_hunts = 7
		GameFinding.after_search(c, foes(["wolf", "slime", "wolf"]))
		differ = differ or c.roster != a.roster
	ok(same, "the same seed and hunt always give the same find")
	ok(differ, "a different hunt gives a different roll")
	# rate: about the chance, over many seeds
	var hits := 0
	for s in range(1, 2001):
		var d := dyn(s)
		if not GameFinding.after_search(d, foes(["wolf"])).is_empty():
			hits += 1
	var rate := float(hits) / 2000.0
	ok(absf(rate - float(GameFinding.setting("base_chance"))) < 0.03, "the find rate matches the chance (%.3f)" % rate)
	# not in a life
	_with(func(x): x["base_chance"] = 1.0; x["max_chance"] = 1.0, func():
		var d := dyn()
		d.state = "succession"
		ok(GameFinding.after_search(d, foes(["wolf"])).is_empty(), "nothing is found outside a life"))


func test_roster() -> void:
	var d := dyn()
	ok(d.roster.is_empty(), "a new dynasty keeps no creatures")
	ok(GameRoster.add(d, "skeleton", "X").is_empty(), "a creature that is not born cannot be kept")
	ok(GameRoster.add(d, "nonesuch", "X").is_empty(), "an unknown one cannot")
	var a := GameRoster.add(d, "wolf", "Ash")
	var b := GameRoster.add(d, "drake", "Ember")
	ok(a["id"] == 1 and b["id"] == 2, "ids count up from one")
	ok(GameSex.valid(a["sex"]) and GameSex.valid(b["sex"]), "each has a sex")
	ok(a["found_by"] == "Tess" and a["found_gen"] == 1, "who found it and when is kept")
	for i in range(GameRoster.cap(d) - 2):
		GameRoster.add(d, "slime", "S%d" % i)
	ok(GameRoster.full(d) and GameRoster.add(d, "wolf", "Over").is_empty(), "a full roster takes no more")
	_with(func(x): x["base_chance"] = 1.0; x["max_chance"] = 1.0, func():
		var lines := GameFinding.after_search(d, foes(["wolf"]))
		ok(lines.size() == 1 and "nowhere to keep" in lines[0], "a full roster is told, and nothing is added")
		ok(d.roster.size() == GameRoster.cap(d), "the roster stays at its cap"))
	var s1: String = GameRoster.add(dyn(5), "wolf", "A")["sex"]
	ok(s1 == GameRoster.add(dyn(5), "wolf", "A")["sex"], "a creature's sex is a function of the seed and its id")


func test_saving() -> void:
	var fresh := dyn()
	ok(not fresh.to_dict().has("roster"), "a dynasty with no creatures saves no roster key")
	var d := dyn()
	GameRoster.add(d, "wolf", "Ash")
	GameRoster.add(d, "drake", "Ember")
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(back.roster == d.roster, "the roster survives a save and load through JSON")
	var old := d.to_dict()
	old.erase("roster")
	ok(GameDynasty.from_dict(old).roster.is_empty(), "an old save loads with none")
	for bad in [5, "x", null, {"a": 1}, [1, "x", null, []], [{"id": 1}], [{"species": "wolf"}],
			[{"id": "1", "species": "wolf"}], [{"id": 1, "species": 3}]]:
		var s := d.to_dict()
		s["roster"] = bad
		ok(GameDynasty.from_dict(s).roster.is_empty(), "a damaged roster loads as none: %s" % str(bad))
	var s2 := d.to_dict()
	s2["roster"] = [
		{"id": 1, "species": "skeleton", "name": "Bones"},
		{"id": 2, "species": "nonesuch"},
		{"id": 3, "species": "wolf", "name": "Ash", "stage": "egg", "sex": "robot"},
		{"id": 3, "species": "wolf", "name": "Dup"},
		{"id": 4, "species": "drake", "stage": "grown"},
	]
	var r := GameDynasty.from_dict(s2).roster
	ok(r.size() == 2, "the unborn, the unknown and repeated ids are dropped")
	ok(r[0]["species"] == "wolf" and r[0]["stage"] == "young", "a live-bearer cannot be an egg")
	ok(GameSex.valid(r[0]["sex"]), "a bad sex is made good")
	ok(r[1]["species"] == "drake" and r[1]["stage"] == "egg", "an unknown stage becomes the species' own start")
	ok(GameDynasty.from_dict(s2).to_dict()["roster"] == r, "what was cleaned saves cleaned")


func test_search() -> void:
	# the search plays exactly as GamePlague.search does: same lines, same gold, same dice
	for s in range(1, 30):
		var a := dyn(s)
		var b := dyn(s)
		a.loot = {"gold": 40, "item_chance": 0.5, "foes": [{"id": "wolf", "name": "Wolf", "carries": []}]}
		b.loot = a.loot.duplicate(true)
		var plain := GamePlague.search(a)
		var full := GameFinding.search_dead(b)
		ok(full.slice(0, plain.size()) == plain, "the search lines are the plain search's (seed %d)" % s)
		ok(a.heir.gold == b.heir.gold and a.rng.state == b.rng.state, "gold and the dynasty's dice are as the plain search leaves them (seed %d)" % s)
		ok(b.loot.is_empty(), "the dead are searched once")
	_with(func(x): x["base_chance"] = 1.0; x["max_chance"] = 1.0, func():
		var d := dyn()
		d.loot = {"gold": 10, "item_chance": 0.0, "foes": [{"id": "wolf", "name": "Wolf", "carries": []}]}
		var lines := GameFinding.search_dead(d)
		ok(d.roster.size() == 1 and "pup" in lines.back(), "a sure find is added and told after the search")
		var e := dyn()
		e.loot = {}
		ok(GameFinding.search_dead(e).is_empty() and e.roster.is_empty(), "nothing to search, nothing found"))


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func test_describe() -> void:
	var d := dyn()
	var w := GameRoster.add(d, "wolf", "Ash")
	var e := GameRoster.add(d, "drake", "Ember")
	var dw := GameRoster.describe(w)
	var de := GameRoster.describe(e)
	ok(dw["name"] == "Ash" and dw["stage"] == "pup", "a litter is called by its young's name: %s" % dw["stage"])
	ok(de["name"] == "Ember" and de["stage"] == "hatchling egg", "a clutch is called an egg of its young: %s" % de["stage"])
	ok("Pup of a dire wolf" in dw["line"] and w["sex"] in dw["line"] and "Tess" in dw["line"] and "generation 1" in dw["line"], "the line says what it is, its sex and who found it: %s" % dw["line"])
	var grown := w.duplicate()
	grown["stage"] = "adult"
	var dg := GameRoster.describe(grown)
	ok(dg["stage"] == "dire wolf" and dg["line"].begins_with("Dire wolf, "), "a grown creature is not 'of a' itself: %s" % dg["line"])
	grown["stage"] = "elder"
	ok(GameRoster.describe(grown)["line"].begins_with("Old dire wolf, "), "an old one is called old: %s" % GameRoster.describe(grown)["line"])
	ok(GameRoster.describe({}).has("line"), "an empty entry still describes without crashing")


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


func _find_button(n: Node, text: String) -> Button:
	if n is Button and (n as Button).is_visible_in_tree() and (n as Button).text == text:
		return n
	for c in n.get_children():
		var b := _find_button(c, text)
		if b != null:
			return b
	return null


func _panel(d: GameDynasty) -> Control:
	var c := ChroniclePanel.new()
	c.dynasty = d
	app.current.add_child(c)
	await _frames(3)
	var tab := _tab(c, "Creatures")
	if tab != null:
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
	var tab := await _panel(d)
	ok(tab != null, "the Chronicle has a Creatures tab")
	if tab == null:
		return
	ok(_find_label(tab, "Kept: 0 of %d" % GameRoster.cap(d)) != null, "it shows how many places are used")
	ok(_find_label(tab, GameFinding.text("empty", {})) != null, "and says how to find young when there are none")
	GameRoster.add(d, "wolf", "Ash")
	GameRoster.add(d, "drake", "Ember")
	var tab2 := await _panel(d)
	ok(_find_label(tab2, "Kept: 2 of %d" % GameRoster.cap(d)) != null, "the count follows the roster")
	ok(_find_label(tab2, "Ash  (pup)") != null and _find_label(tab2, "Ember  (hatchling egg)") != null, "each creature is listed with its stage")
	ok(_find_label(tab2, GameRanch.text("keep", {"gold": str(GameRanch.keep_total(d))})) != null, "and what they cost to keep a year")
	d.heir.gold = 1000
	GameRanch.on_years(d, 4.0, [])
	var tab3 := await _panel(d)
	ok(_find_label(tab3, "Ash  (dire wolf)") != null and _find_label(tab3, "Ember  (hatchling)") != null, "the stage follows the years: grown, hatched")
	ok(_find_label(tab3, GameRanch.text("guard_head", {"cut": "20"})) != null, "a grown guard shows what the guards turn away")
	ok(_find_label(tab3, "Dire wolf, male. Found by Tess in generation 1. 4 years old, content. Guards the house: turns away 20% of a theft or fine.") != null, "and its own entry says it guards")
	ok(_find_label(tab2, GameFinding.text("empty", {})) == null, "and the empty note is gone")
	# breeding from the tab: a grown wolf can be set to breed, and a mate makes a pair
	var wolf: Dictionary = d.roster[0]
	var breed_btn := _find_button(tab3, GameBreeding.text("breed_off", {}))
	ok(breed_btn != null and wolf["breeding"] == false, "a grown creature has a Breeding button, off")
	ok(_find_button(tab3, GameBreeding.text("breed_on", {})) == null and d.roster.size() == 2, "and a young one or an egg has none")
	if breed_btn != null:
		breed_btn.pressed.emit()
		await _frames(2)
		ok(wolf["breeding"] == true and _find_button(tab3, GameBreeding.text("breed_on", {})) != null, "pressing it sets the creature to breed and the button says so")
		ok(_find_label(tab3, GameBreeding.text("pairs", {"n": "1"})) == null, "with no mate there is no pair")
		var mate := GameRoster.add(d, "wolf", "Fen")
		mate["stage"] = "adult"
		mate["age"] = 5.0
		mate["breeding"] = true
		mate["sex"] = GameSex.opposite(str(wolf["sex"]))
		var tab4 := await _panel(d)
		ok(_find_label(tab4, GameBreeding.text("pairs", {"n": "1"})) != null, "a mate makes a pair, and the tab says so")
		d.roster.erase(mate)
		_find_button(tab4, GameBreeding.text("breed_on", {})).pressed.emit()
		await _frames(2)
		ok(wolf["breeding"] == false, "pressing it again sets the creature to rest")
	var before := d.roster.duplicate(true)
	await _frames(2)
	ok(d.roster == before, "looking at the tab changes nothing")
	# selling and setting free, each on a second tap
	var changes := [0]
	var cp := ChroniclePanel.new()
	cp.dynasty = d
	cp.on_change = func(): changes[0] += 1
	app.current.add_child(cp)
	await _frames(3)
	var ctab := _tab(cp, "Creatures")
	(ctab.get_parent() as TabContainer).current_tab = ctab.get_index()
	await _frames(2)
	var sell_label := GameRanch.text("sell", {"gold": GameText.num(GameRanch.sell_price(d.roster[0]))})
	var sell_btn := _find_button(ctab, sell_label)
	ok(sell_btn != null and _find_button(ctab, GameRanch.text("free", {})) != null, "each creature has Sell and Set free")
	if sell_btn == null:
		return
	var gold := d.heir.gold
	sell_btn.pressed.emit()
	await _frames(2)
	ok(d.roster.size() == 2 and d.heir.gold == gold, "the first tap sells nothing")
	var sure := _find_button(ctab, GameRanch.text("sure_sell", {"gold": GameText.num(GameRanch.sell_price(d.roster[0]))}))
	ok(sure != null, "it asks again")
	if sure == null:
		return
	var price := GameRanch.sell_price(d.roster[0])
	sure.pressed.emit()
	await _frames(2)
	ok(d.roster.size() == 1 and d.heir.gold == gold + price, "the second tap sells it and pays")
	ok(changes[0] == 1, "and tells the screen behind")
	ok(_find_label(ctab, "Kept: 1 of %d" % GameRoster.cap(d)) != null and _find_label(ctab, "Ash  (pup)") == null, "and the tab shows what is left")
	var free1 := _find_button(ctab, GameRanch.text("free", {}))
	free1.pressed.emit()
	await _frames(2)
	var other := _find_button(ctab, GameRanch.text("sure_free", {}))
	ok(other != null and d.roster.size() == 1, "Set free asks again too")
	var sell2 := _find_button(ctab, GameRanch.text("sell", {"gold": GameText.num(GameRanch.sell_price(d.roster[0]))}))
	sell2.pressed.emit()
	await _frames(2)
	ok(d.roster.size() == 1 and _find_button(ctab, GameRanch.text("free", {})) != null, "tapping the other button starts that question instead")
	_find_button(ctab, GameRanch.text("free", {})).pressed.emit()
	await _frames(2)
	_find_button(ctab, GameRanch.text("sure_free", {})).pressed.emit()
	await _frames(2)
	ok(d.roster.is_empty() and changes[0] == 2 and _find_label(ctab, GameFinding.text("empty", {})) != null, "setting free empties the roster and says how to find young")
	# the Ranch in the house panel
	var HousePanel := preload("res://ui/play/house_panel.gd")
	var hp := HousePanel.new()
	hp.dynasty = d
	hp.on_change = func(): pass
	app.current.add_child(hp)
	await _frames(3)
	ok(_find_label(hp, "Ranch: level 0 of %d" % GameHouse.max_level()) != null, "the house panel has a Ranch row")
	ok(_find_label(hp, str(GameRanch.data()["ranch"]["levels"][1]["about"])) != null or hp.find_children("*", "Label", true, false).any(func(l): return str(GameRanch.data()["ranch"]["levels"][1]["about"]) in (l as Label).text), "that says what the next level builds")
	d.heir.gold = 100000
	var builds := hp.find_children("*", "Button", true, false).filter(func(b): return (b as Button).text == "Build (%s gold)" % GameText.num(GameHouse.cost(d, GameHouse.RANCH)))
	var build: Button = builds.back() if not builds.is_empty() else null   # the three tracks cost the same: the Ranch's is the last
	ok(build != null and builds.size() == 3, "and a button to build it, after the Hall's and the Yard's")
	if build != null:
		build.pressed.emit()
		await _frames(2)
		ok(GameHouse.level(d, GameHouse.RANCH) == 1, "which builds the Ranch")
	app.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(DIR + "save.json")


## The two things after_battle reads of a fight: its result and its foes.
func _fight(boss: String, result: String = "victory") -> Array:
	return [result, [{"id": boss, "name": GameCombat.creature_def(boss).get("name", boss), "boss": true}]]


func test_more() -> void:
	ok(GameFinding.validate().is_empty(), "the data with the new keys is sound: %s" % str(GameFinding.validate()))
	_with(func(x): x["trait_bonus"]["nonesuch"] = 2.0, func(): ok(not GameFinding.validate().is_empty(), "a bonus for an unknown trait is found"))
	_with(func(x): x["places"].erase("legend"), func(): ok(not GameFinding.validate().is_empty(), "a missing legend place is found"))
	_with(func(x): x.erase("found_flag"), func(): ok(not GameFinding.validate().is_empty(), "a missing found flag is found"))
	# traits that help
	var h := dyn(5, "warrior").heir
	h.traits = []
	h.dormant = []
	var base := GameFinding.chance(h, "wolf")
	h.traits = ["wild_instincts"]
	ok(GameFinding.chance(h, "wolf") > base, "Wild Instincts raise the chance")
	# take: an event outcome
	var d := dyn()
	ok(not d.flags.has("found_young"), "a new house has not found young")
	var lines := GameFinding.take(d, ["wolf", "frost_wolf"], "test_event")
	ok(lines.size() == 1 and d.roster.size() == 1 and d.roster[0]["species"] in ["wolf", "frost_wolf"], "taking in young adds a creature of one of the species: %s" % str(lines))
	ok("takes in a pup" in lines[0], "and tells it: %s" % lines[0])
	ok(d.flags.has("found_young"), "and the house has found young")
	var d2 := dyn()
	var egg := GameFinding.take(d2, ["drake"], "test_event")
	ok("egg of the cinder drake" in egg[0] and d2.roster[0]["stage"] == "egg", "an egg is told as one: %s" % egg[0])
	var a := dyn(7)
	var b := dyn(7)
	GameFinding.take(a, ["wolf", "frost_wolf", "harpy"], "k")
	GameFinding.take(b, ["wolf", "frost_wolf", "harpy"], "k")
	ok(a.roster == b.roster, "the same seed and event give the same young")
	var rng_before := a.rng.state
	GameFinding.take(a, ["wolf"], "k2")
	ok(a.rng.state == rng_before, "taking draws nothing from the dynasty's dice")
	var full := dyn()
	for i in GameRoster.cap(full):
		GameRoster.add(full, "slime", "S%d" % i)
	var fl := GameFinding.take(full, ["wolf"], "k")
	ok(fl.size() == 1 and "nowhere to keep" in fl[0] and full.roster.size() == GameRoster.cap(full) and not full.flags.has("found_young"), "a full ranch is told and takes none")
	ok(GameFinding.take(dyn(), [], "k").is_empty(), "no species, no find")
	var dead := dyn()
	dead.state = "succession"
	ok(GameFinding.take(dead, ["wolf"], "k").is_empty() and dead.roster.is_empty(), "nothing is taken outside a life")
	# a search that finds sets the flag too
	_with(func(x): x["base_chance"] = 1.0; x["max_chance"] = 1.0, func():
		var s := dyn()
		GameFinding.after_search(s, foes(["wolf"]))
		ok(s.flags.has("found_young"), "a find beside the dead counts"))
	# legends
	var any_found := false
	var any_missed := false
	for seed_value in range(1, 80):
		var l := dyn(seed_value)
		l.slain_bosses["vaerthax"] = l.gen
		var out := GameFinding.after_battle(l, _fight("vaerthax")[0], _fight("vaerthax")[1])
		any_found = any_found or not out.is_empty()
		any_missed = any_missed or out.is_empty()
	ok(any_found and any_missed, "a legend's clutch is found by some and missed by others")
	_with(func(x): x["base_chance"] = 0.5; x["max_chance"] = 1.0; x["places"]["legend"] = 10.0, func():   # certain
		var l := dyn()
		l.slain_bosses["vaerthax"] = l.gen
		var out := GameFinding.after_battle(l, _fight("vaerthax")[0], _fight("vaerthax")[1])
		ok(out.size() == 1 and "Beside the dead vaerthax" in out[0] and "one great clutch survives" in out[0] and l.roster[0]["species"] == "vaerthax" and l.roster[0]["stage"] == "egg", "a legend's clutch is its own egg: %s" % str(out))
		ok(l.flags.has("legend_clutch_vaerthax") and l.flags.has("found_young"), "once only, and the house has found young")
		ok(GameFinding.after_battle(l, _fight("vaerthax")[0], _fight("vaerthax")[1]).is_empty() and l.roster.size() == 1, "and not again")
		var g := dyn()
		g.slain_bosses["grimfang"] = g.gen
		var gl := GameFinding.after_battle(g, _fight("grimfang")[0], _fight("grimfang")[1])
		ok(gl.size() == 1 and "a pup still lives" in gl[0], "a legend of live young leaves a pup: %s" % str(gl))
		var u := dyn()
		u.slain_bosses["hollow_king"] = u.gen
		ok(GameFinding.after_battle(u, _fight("hollow_king")[0], _fight("hollow_king")[1]).is_empty() and u.roster.is_empty(), "a legend that is not born leaves nothing")
		var n := dyn()
		ok(GameFinding.after_battle(n, _fight("vaerthax")[0], _fight("vaerthax")[1]).is_empty(), "a legend not slain by this fight leaves nothing")
		var lost := dyn()
		lost.slain_bosses["vaerthax"] = lost.gen
		ok(GameFinding.after_battle(lost, _fight("vaerthax", "defeat")[0], _fight("vaerthax")[1]).is_empty(), "nor does a lost fight")
		var f := dyn()
		for i in GameRoster.cap(f):
			GameRoster.add(f, "slime", "S%d" % i)
		f.slain_bosses["vaerthax"] = f.gen
		var fo := GameFinding.after_battle(f, _fight("vaerthax")[0], _fight("vaerthax")[1])
		ok(fo.size() == 1 and "nowhere to keep" in fo[0] and f.roster.size() == GameRoster.cap(f), "a full ranch is told: %s" % str(fo)))
	var rl := dyn()
	rl.slain_bosses["vaerthax"] = rl.gen
	var before := rl.rng.state
	GameFinding.after_battle(rl, _fight("vaerthax")[0], _fight("vaerthax")[1])
	ok(rl.rng.state == before, "a legend's roll draws nothing from the dynasty's dice")
	# events
	var ev := GameEvents.event_def("nest_on_the_ledge")
	ok(not ev.is_empty() and ev["requires"]["flags"] == ["found_young"], "the nest event exists and needs a house that has found young")
	var fresh := dyn()
	ok(not GameEvents.eligible(fresh).any(func(e): return str(e["id"]) in ["nest_on_the_ledge", "litter_in_the_den"]), "a house that has found no young is never offered them")
	var keeper := dyn()
	GameFinding.take(keeper, ["wolf"], "x")
	var offered := false
	for place_id in ["whisperwood", "emberpeak"]:
		keeper.world.location = place_id
		offered = offered or GameEvents.eligible(keeper).any(func(e): return str(e["id"]) in ["nest_on_the_ledge", "litter_in_the_den"])
	ok(offered, "but a house that has is, in the right places")
	# an outcome with find adds the creature and tells it
	var o := dyn()
	var fx := GameEvents._apply(o, ev, {"text": "t", "find": {"species": ["harpy"]}}, [])
	ok(o.roster.size() == 1 and o.roster[0]["species"] == "harpy" and fx.any(func(f): return "harpy" in str(f["t"]) or "chick" in str(f["t"])), "an event outcome's find adds the creature: %s" % str(fx))
	# the validator
	ok(GameEvents.validate().is_empty(), "the events are sound with the new ones: %s" % str(GameEvents.validate()))
	var saved: Array = GameData.events.duplicate(true)
	for bad in [{"species": ["skeleton"]}, {"species": ["grimfang"]}, {"species": []}, {"species": ["nonesuch"]}]:
		var copy: Array = saved.duplicate(true)
		var idx := copy.map(func(e): return e["id"]).find("nest_on_the_ledge")
		copy[idx]["choices"][1]["outcomes"]["always"]["find"] = bad
		GameData.events = copy
		ok(not GameEvents.validate().is_empty(), "a find with %s is found by the validator" % str(bad))
	GameData.events = saved
	ok(GameEvents.validate().is_empty(), "and the events are put back")
