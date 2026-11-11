## Heirloom upgrades across generations (roadmap item 18): the data and the ways to break it; that a hall with no
## levels gives exactly the power it always did; the price; reworking (gold, level, power, who worked it, told);
## once in each heir's life and again for the next; the forge, the top level and the other refusals; the cap on
## how many heirlooms count; saving, old saves and damaged values; that the autopilot reworks nothing; and the
## panel opened from the family house.
## Run: godot --headless --path . -s res://tests/test_game_heirlooms.gd
extends SceneTree

const DIR := "user://test_heirlooms/"
const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const HousePanel := preload("res://ui/play/house_panel.gd")

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
	test_unchanged()
	test_cost()
	test_upgrade()
	test_generations()
	test_refusals()
	test_saving()
	test_autopilot()
	await test_screen()
	print("heirlooms tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func dyn(looms: int = 1) -> GameDynasty:
	var d := GameDynasty.new_game(5, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.world.location = _forge_town()
	d.heir.gold = 1000000
	var names := ["Grimfang's Fang", "Crown of the Hollow King", "Vaerthax's Scale", "Heart of Stone", "Shard of the Unmade"]
	for i in looms:
		d.heirlooms.append({"name": names[i % names.size()] + ("" if i < names.size() else " %d" % i), "boss": "a legend", "gen": 1})
	d.heir.heirloom_bonus = d.heirloom_bonus()
	return d


func _forge_town() -> String:
	for l in GameData.world["locations"]:
		if "forge" in l.get("services", []):
			return str(l["id"])
	return ""


func _no_forge() -> String:
	for l in GameData.world["locations"]:
		if "forge" not in l.get("services", []):
			return str(l["id"])
	return ""


func _broken(edit: Callable, word: String) -> bool:
	var saved: Dictionary = GameHeirlooms.data().duplicate(true)
	edit.call(GameHeirlooms.data())
	var found := GameHeirlooms.validate()
	GameHeirlooms._cache = saved
	return found.any(func(p): return word in str(p))


func test_data() -> void:
	ok(GameHeirlooms.validate().is_empty(), "the heirloom rules are sound: %s" % str(GameHeirlooms.validate()))
	ok(_forge_town() != "" and _no_forge() != "", "there is a place with a forge and one without")
	ok(_broken(func(x): x["settings"]["max_level"] = 0, "at least 1"), "no levels is refused")
	ok(_broken(func(x): x["levels"].pop_back(), "a name for each level"), "a level with no name is refused")
	ok(_broken(func(x): x["levels"][2] = " ", "a level has no name"), "a blank level name is refused")
	ok(_broken(func(x): x["settings"]["level_bonus"] = 0, "must add power"), "a level that adds nothing is refused")
	ok(_broken(func(x): x["settings"]["cost_base"] = 0, "must cost gold"), "free reworking is refused")
	ok(_broken(func(x): x["settings"]["needs_service"] = "mint", "no place has the service"), "a service no place has is refused")
	ok(_broken(func(x): x["settings"]["level_bonus"] = 0.2, "more than double"), "heirlooms that would more than double an heir are refused")
	ok(_broken(func(x): x["text"].erase("done"), "text 'done'"), "missing text is refused")


func test_unchanged() -> void:
	var base := float(GameData.bal("heirloom_bonus"))
	for n in 14:
		var d := dyn(n)
		var old := float(mini(n, int(GameData.bal("heirloom_max")))) * base   # the sum as it was written before levels
		ok(d.heirloom_bonus() == old, "%d heirlooms with no levels give exactly what they did (%s)" % [n, str(d.heirloom_bonus())])
	var d := dyn(2)
	ok(GameHeirlooms.level(d.heirlooms[0]) == 0 and GameHeirlooms.level_name(0) == "as it was taken", "an heirloom starts as it was taken")
	ok(not d.to_dict()["heirlooms"][0].has("level"), "and saves no level")
	ok(GameHeirlooms.level("x") == 0 and GameHeirlooms.level({"level": "high"}) == 0 and GameHeirlooms.level({"level": 99}) == 5 and GameHeirlooms.level({"level": -3}) == 0, "a level that is damaged or out of bounds is held within them")


func test_cost() -> void:
	var d := dyn()
	ok(GameHeirlooms.cost(d, 0) == 400, "the first level costs the base in the first generation: %d" % GameHeirlooms.cost(d, 0))
	d.heirlooms[0]["level"] = 2
	ok(GameHeirlooms.cost(d, 0) == 3600, "the third costs nine times it: %d" % GameHeirlooms.cost(d, 0))
	d.gen = 11
	ok(GameHeirlooms.cost(d, 0) == int(round(3600 * GameData.enemy_scale(11))), "and more in a later generation, as shop prices are")
	d.heirlooms[0]["level"] = 5
	ok(GameHeirlooms.cost(d, 0) == -1 and GameHeirlooms.cost(d, 7) == -1 and GameHeirlooms.cost(d, -1) == -1, "nothing at the top, and nothing for an heirloom that is not there")


func test_upgrade() -> void:
	var d := dyn(2)
	var before := d.rng.state
	var gold := d.heir.gold
	var hp := d.heir.max_hp()
	var got := GameHeirlooms.upgrade(d, 0)
	ok(got["ok"] and d.heirlooms[0]["level"] == 1 and d.heir.gold == gold - 400, "reworked: a level for 400 gold")
	ok(got["text"] == "Tess has Grimfang's Fang reworked: it is now reforged, and gives every heir 4% power." and d.journal[-1] == got["text"], "told in the journal: %s" % got["text"])
	ok(is_equal_approx(d.heirloom_bonus(), 0.03 + 0.03 + 0.01) and d.heir.heirloom_bonus == d.heirloom_bonus(), "the hall gives 7%% and the heir has it at once (%s)" % str(d.heirloom_bonus()))
	ok(d.heirlooms[0]["smiths"] == ["Tess"] and d.heirlooms[0]["worked_gen"] == 1, "and the heirloom remembers who worked it")
	ok(not d.heirlooms[1].has("level"), "the other heirloom is untouched")
	ok(d.rng.state == before, "no die is drawn")
	var m := GameHeirlooms.describe(d, 0)
	ok(m["line"] == "Grimfang's Fang, reforged: +4% power. Taken from a legend in generation 1." and m["worked"] == "Reworked by Tess.", "the screen's lines: %s / %s" % [m["line"], m["worked"]])
	ok(d.heir.max_hp() > hp, "and the heir is the stronger for it (%d health, was %d)" % [d.heir.max_hp(), hp])


func test_generations() -> void:
	var d := dyn()
	ok(GameHeirlooms.upgrade(d, 0)["ok"], "the first heir reworks it")
	var again := GameHeirlooms.upgrade(d, 0)
	ok(not again["ok"] and again["text"] == "Grimfang's Fang has already been reworked in Tess's life. Their heir may take it further.", "but not twice in one life: %s" % again["text"])
	var names := ["Aldo", "Bree", "Cael", "Dara"]
	for i in names.size():
		d.gen += 1
		d.heir.name = names[i]
		ok(GameHeirlooms.upgrade(d, 0)["ok"], "generation %d takes it a level further" % d.gen)
		ok(not GameHeirlooms.upgrade(d, 0)["ok"], "once")
	ok(d.heirlooms[0]["level"] == 5 and d.heirlooms[0]["smiths"] == ["Tess", "Aldo", "Bree", "Cael", "Dara"], "five heirs, five levels, five names: %s" % str(d.heirlooms[0]["smiths"]))
	ok(GameHeirlooms.level_name(5) == "legendary" and is_equal_approx(GameHeirlooms.bonus_of(d.heirlooms[0]), 0.08), "it is legendary and gives 8%")
	d.gen += 1
	var top := GameHeirlooms.upgrade(d, 0)
	ok(not top["ok"] and top["text"] == "Grimfang's Fang can be made no finer.", "and can be made no finer: %s" % top["text"])
	ok(GameHeirlooms.describe(d, 0)["cost"] == -1, "the screen shows it finished")
	# two heirlooms, one heir: each once
	var two := dyn(2)
	ok(GameHeirlooms.upgrade(two, 0)["ok"] and GameHeirlooms.upgrade(two, 1)["ok"] and not GameHeirlooms.upgrade(two, 1)["ok"], "an heir may rework each heirloom once")
	# only the first heirloom_max count
	var many := dyn(14)
	many.heirlooms[13]["level"] = 5
	ok(is_equal_approx(many.heirloom_bonus(), 12 * 0.03), "an heirloom beyond the twelve that count adds nothing, levels and all")
	many.heirlooms[0]["level"] = 5
	ok(is_equal_approx(many.heirloom_bonus(), 12 * 0.03 + 0.05), "one that counts adds its levels")


func test_refusals() -> void:
	var d := dyn()
	ok(GameHeirlooms.why_not(d, 3) == "There is no such heirloom." and GameHeirlooms.why_not(d, -1) == "There is no such heirloom.", "no such heirloom")
	d.heir.gold = 399
	ok(GameHeirlooms.why_not(d, 0) == "Not enough gold (400 needed)." and not GameHeirlooms.upgrade(d, 0)["ok"] and d.heir.gold == 399, "not enough gold, and none is taken")
	d.heir.gold = 400
	d.world.location = _no_forge()
	ok(GameHeirlooms.why_not(d, 0) == "An heirloom is reworked at a forge.", "only at a forge")
	d.world.location = _forge_town()
	d.state = "succession"
	ok(GameHeirlooms.why_not(d, 0) == "Only a living heir can have an heirloom reworked.", "only a living heir")
	d.state = "life"
	d.heirlooms.append("junk")
	ok(GameHeirlooms.why_not(d, 1) == "There is no such heirloom." and GameHeirlooms.describe(d, 1).is_empty(), "an entry that is no heirloom is refused, not crashed on")
	ok(GameHeirlooms.upgrade(d, 0)["ok"] and d.heir.gold == 0, "with exactly the price it is done")


func test_saving() -> void:
	var d := dyn(2)
	GameHeirlooms.upgrade(d, 0)
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(back.heirlooms == d.heirlooms and back.heir.heirloom_bonus == d.heir.heirloom_bonus, "levels, who worked them and the power survive a save and load")
	var old: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	for h in old["heirlooms"]:
		for k in ["level", "worked_gen", "smiths"]:
			h.erase(k)
	var o := GameDynasty.from_dict(old)
	ok(o.heirlooms == [{"name": "Grimfang's Fang", "boss": "a legend", "gen": 1}, {"name": "Crown of the Hollow King", "boss": "a legend", "gen": 1}] and is_equal_approx(o.heirloom_bonus(), 0.06), "a save from before upgrades loads as it always did")
	var bad: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	bad["heirlooms"][0]["level"] = 40
	bad["heirlooms"][0]["worked_gen"] = "then"
	bad["heirlooms"][0]["smiths"] = ["A", 3, "B", "C", "D", "E", "F", "G"]
	bad["heirlooms"][1]["level"] = "fine"
	bad["heirlooms"][1]["smiths"] = ["Nobody"]
	bad["heirlooms"][1]["worked_gen"] = 9
	var r := GameDynasty.from_dict(bad).heirlooms
	ok(r[0]["level"] == 5 and r[0]["worked_gen"] == 1 and r[0]["smiths"] == ["A", "B", "C", "D", "E"], "a level too high is held at the top, a damaged generation falls back, and no more names than levels are kept: %s" % str(r[0]))
	ok(not r[1].has("level") and not r[1].has("smiths") and not r[1].has("worked_gen"), "a level that is no number is none, and takes its names with it")
	ok(r[0]["name"] == "Grimfang's Fang" and r[0]["boss"] == "a legend", "the rest of the heirloom is left as it was")


func _bot(d: GameDynasty) -> void:
	if d.state == "succession":
		GameBot.choose_best(d)
	else:
		GameBot.step(d)


func test_autopilot() -> void:
	var a := GameDynasty.new_game(31, "Auto", "warrior", "noble", "human")
	a.heirlooms.append({"name": "Grimfang's Fang", "boss": "Grimfang", "gen": 1})
	a.heir.heirloom_bonus = a.heirloom_bonus()
	for i in 2500:
		_bot(a)
	ok(a.gen >= 3, "the autopilot plays generations with an heirloom in the hall (%d)" % a.gen)
	ok(a.heirlooms.all(func(h): return not h.has("level")), "and has none reworked")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _find(n: Node, name: String) -> Node:
	if str(n.name) == name:
		return n
	for c in n.get_children():
		var f := _find(c, name)
		if f != null:
			return f
	return null


func _buttons(n: Node, out: Array) -> void:
	if n is Button:
		out.append(n)
	for c in n.get_children():
		_buttons(c, out)


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
	d.world.location = _forge_town()
	d.heir.gold = 5000
	app.show_state()
	await _frames(3)
	var plain := HousePanel.new()
	plain.dynasty = d
	plain.on_change = func(): pass
	app.current.add_child(plain)
	await _frames(3)
	ok(_find(plain, "Heirlooms") == null, "a house with no heirloom has no Heirlooms button")
	plain.queue_free()
	await _frames(2)
	d.heirlooms.append({"name": "Grimfang's Fang", "boss": "Grimfang", "gen": 1})
	var changed := [0]
	var house := HousePanel.new()
	house.dynasty = d
	house.on_change = func(): changed[0] += 1
	app.current.add_child(house)
	await _frames(3)
	var open := _find(house, "Heirlooms")
	ok(open != null, "a house with one has the button")
	(open as Button).pressed.emit()
	await _frames(3)
	var buttons: Array = []
	_buttons(app.current, buttons)
	var rework: Array = buttons.filter(func(b): return b.text == "Rework (400 gold)")
	ok(rework.size() == 1 and not rework[0].disabled, "the panel offers the rework at its price")
	rework[0].pressed.emit()
	await _frames(3)
	ok(d.heirlooms[0].get("level", 0) == 1 and d.heir.gold == 4600 and changed[0] == 1, "pressing it reworks the heirloom and tells the screen behind")
	buttons.clear()
	_buttons(app.current, buttons)
	ok(buttons.any(func(b): return b.text.begins_with("Rework (") and b.disabled), "and the row is now shut for this heir")
	app.queue_free()
	await _frames(2)
