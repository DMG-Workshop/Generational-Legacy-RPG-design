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
	var base := float(GameFinding.setting("base_chance"))
	ok(is_equal_approx(GameFinding.chance(d.heir, "wolf"), base), "a wolf's litter is the base chance for a warrior")
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
	for i in range(GameRoster.cap() - 2):
		GameRoster.add(d, "slime", "S%d" % i)
	ok(GameRoster.full(d) and GameRoster.add(d, "wolf", "Over").is_empty(), "a full roster takes no more")
	_with(func(x): x["base_chance"] = 1.0; x["max_chance"] = 1.0, func():
		var lines := GameFinding.after_search(d, foes(["wolf"]))
		ok(lines.size() == 1 and "nowhere to keep" in lines[0], "a full roster is told, and nothing is added")
		ok(d.roster.size() == GameRoster.cap(), "the roster stays at its cap"))
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
	ok(_find_label(tab, "Kept: 0 of %d" % GameRoster.cap()) != null, "it shows how many places are used")
	ok(_find_label(tab, GameFinding.text("empty", {})) != null, "and says how to find young when there are none")
	GameRoster.add(d, "wolf", "Ash")
	GameRoster.add(d, "drake", "Ember")
	var tab2 := await _panel(d)
	ok(_find_label(tab2, "Kept: 2 of %d" % GameRoster.cap()) != null, "the count follows the roster")
	ok(_find_label(tab2, "Ash  (pup)") != null and _find_label(tab2, "Ember  (hatchling egg)") != null, "each creature is listed with its stage")
	ok(_find_label(tab2, GameRanch.text("keep", {"gold": str(GameRanch.keep_total(d))})) != null, "and what they cost to keep a year")
	d.heir.gold = 1000
	GameRanch.on_years(d, 4.0, [])
	var tab3 := await _panel(d)
	ok(_find_label(tab3, "Ash  (dire wolf)") != null and _find_label(tab3, "Ember  (hatchling)") != null, "the stage follows the years: grown, hatched")
	ok(_find_label(tab2, GameFinding.text("empty", {})) == null, "and the empty note is gone")
	var before := d.roster.duplicate(true)
	await _frames(2)
	ok(d.roster == before, "looking at the tab changes nothing")
	app.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(DIR + "save.json")
