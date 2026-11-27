## The death summary (core/game/game_death.gd, data/ui/death.json, ui/play/death_panel.gd): shown when an heir dies, before the succession
## screen. It tells who died and how (the journal's own cause line), what killed them (the foe and its band and level while the fight is known),
## what the life came to, what the heir leaves the family and what carries over, and its button goes on into the unchanged succession. It reads the
## dynasty and changes nothing: the rules of death and succession are the game's own.
## Run: godot --headless --path . -s res://tests/test_game_death_panel.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const DeathPanel := preload("res://ui/play/death_panel.gd")
const SuccessionScreen := preload("res://ui/play/succession_screen.gd")

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
	GameDynasty.save_path = "user://test_death_panel.json"
	test_data()
	test_old_age()
	test_slain()
	test_leaves()
	test_reads_only()
	test_carry_text()
	await test_flow()
	print("death panel tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(seed_value: int = 7) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


## A house that has an heir with a family, then the heir's death by `cause`.
func _dead(cause: String, seed_value: int = 7) -> GameDynasty:
	var d := _dyn(seed_value)
	d.heir.age = maxf(d.heir.age, d.heir.family_min_age())
	if not d.heir.family_founded:
		d.found_family()
	d.heir.level = 12
	d.heir.battles_won = 9
	d.heir.kills = {"wolf": 4, "bandit": 2}
	d.heir.gold = 321
	d.killer_id = ""
	d._die(cause)
	return d


func test_data() -> void:
	ok(GameDeath.validate().is_empty(), "the data is sound: %s" % str(GameDeath.validate()))
	var saved: Dictionary = GameDeath.data().duplicate(true)
	var bad: Dictionary = saved.duplicate(true)
	(bad["text"] as Dictionary).erase("killer")
	GameDeath._cache = bad
	ok(not GameDeath.validate().is_empty(), "a missing text is refused")
	GameDeath._cache = saved
	ok(not GameDeath.has_death(_dyn()), "a living house has no death to tell")


func test_old_age() -> void:
	var d := _dead("old age")
	ok(d.state == "succession" and GameDeath.has_death(d), "an old age death is between heirs")
	var s := GameDeath.summary(d)
	ok(str(s["title"]) == "Tess has passed.", "who died: %s" % s["title"])
	ok("Human" in str(s["who"]) and "Warrior" in str(s["who"]) and "level 12" in str(s["who"]) and "Generation 1" in str(s["who"]), "their line, class and level: %s" % s["who"])
	ok(str(s["how"]) == GameMessages.text("life", "dies_old_age", {"name": "Tess", "age": int(d.last_death["age"])}), "how: the very line the journal has (%s)" % s["how"])
	ok("old age" in str(s["killer"]), "what killed me: %s" % s["killer"])
	ok((s["sections"] as Array).size() == 3, "three sections")
	var life: Array = s["sections"][0]["lines"]
	ok("6 foes slain" in str(life[0]) and "9 battles won" in str(life[0]) and "321 gold" in str(life[1]), "the life in numbers: %s" % str(life))
	ok(s["heirs"].size() == d.candidates.size() and not (s["heirs"] as Array).is_empty(), "the heirs are named")
	for c in d.candidates:
		ok(str(c.name) in str(s["carry_on"]) or d.candidates.size() > 3, "the button names who carries on")
		break


func test_slain() -> void:
	var d := _dyn()
	d.heir.age = maxf(d.heir.age, d.heir.family_min_age())
	if not d.heir.family_founded:
		d.found_family()
	d.killer_id = "wolf"
	d.killer_info = {"id": "wolf", "name": "Elite Wolf", "level": 14, "con": "hard"}
	d._die("slain in battle")
	var s := GameDeath.summary(d)
	ok(str(s["how"]) == GameMessages.text("life", "dies_cause", {"name": "Tess", "cause": GameMessages.text("life", "cause_slain"), "age": int(d.last_death["age"])}), "how: slain in battle, as the journal says it")
	ok("Elite Wolf" in str(s["killer"]) and "hard" in str(s["killer"]) and "level 14" in str(s["killer"]), "what killed me names the foe, its band and level: %s" % s["killer"])
	d.killer_info = {"id": "wolf", "name": "Wolf", "level": 0, "con": ""}
	ok(str(GameDeath.killer_line(d, "slain in battle")) == "What killed me: Wolf.", "with no band or level, just the foe: %s" % GameDeath.killer_line(d, "slain in battle"))
	d.killer_info = {"id": "wolf", "name": "Wolf", "level": 6, "con": ""}
	ok("level 6" in GameDeath.killer_line(d, "slain in battle"), "a level alone is told")
	d.killer_info = {"id": "wolf", "name": "Wolf", "level": 0, "con": "easy"}
	ok("easy" in GameDeath.killer_line(d, "slain in battle"), "a band alone is told")
	d.killer_info = {}
	var wolf := d._creature_name("wolf")
	ok(wolf in GameDeath.killer_line(d, "slain in battle"), "after a load (nothing kept of the fight) the saved killer's name still shows: %s" % GameDeath.killer_line(d, "slain in battle"))
	d.killer_id = ""
	ok("no one saw" in GameDeath.killer_line(d, "slain in battle"), "and when nothing is known it says so")
	ok("plague" in GameDeath.killer_line(d, "the plague"), "another cause is named")
	# the battle sets the killer on a real defeat (runtime, not saved)
	var e := _dyn(11)
	e.heir.age = 40.0
	e.heir.hp = 1
	var fight := e.start_encounter(["wolf"], "", 1.0, [9])
	ok(fight != null, "a fight starts")
	fight.result = "defeat"
	e.rng.seed = 5
	var told := false
	for i in 12:
		var copy := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))   # (the saved battle comes back with the dynasty)
		copy.battle = null
		copy.battle = copy.start_encounter(["wolf"], "", 1.0, [9])
		copy.battle.result = "defeat"
		copy.battle.enemies[0]["hp"] = 5
		copy.rng.seed = i + 100
		copy.finish_battle()
		if copy.state == "succession":
			told = copy.killer_info.get("id", "") == "wolf" and int(copy.killer_info.get("level", 0)) == 9 and copy.killer_info.get("con", "") != "" and "wolf" in GameDeath.killer_line(copy, "slain in battle").to_lower()
			ok(not copy.to_dict().has("killer_info"), "the fight's foe is not a new field of the save")
			break
	ok(told, "a real defeat that kills keeps the foe, its band and level for the summary")


func test_leaves() -> void:
	var d := _dyn()
	d.heir.age = maxf(d.heir.age, d.heir.family_min_age())
	if not d.heir.family_founded:
		d.found_family()
	d.heirlooms.append({"name": "Crown of Ash", "boss": "Ash King", "gen": 1})
	d.house = {"hall": 2, "yard": 1}
	d.house_titles = [str(GameTitles.defs()[0]["id"])]
	d.heir.potions = 3
	d.heir.inventory = ["sword", "sword", "potion_small"]
	d._die("old age")
	var s := GameDeath.summary(d)
	var leaves: Array = s["sections"][1]["lines"]
	var carries: Array = s["sections"][2]["lines"]
	ok("Crown of Ash" in str(leaves[0]), "the heirlooms: %s" % leaves[0])
	ok("Hall 2" in str(leaves[1]) or "House Hall 2" in str(leaves[1]), "the house: %s" % leaves[1])
	ok(str(GameTitles.defs()[0]["name"]) in str(leaves[2]), "the titles: %s" % leaves[2])
	ok("Echoes in the family" in str(leaves[3]) or "Echoes: none" in str(leaves[3]), "the echoes: %s" % leaves[3])
	ok("321" in str(carries[0]) or "gold" in str(carries[0]), "what carries over: gold (%s)" % carries[0])
	ok(carries.any(func(l): return "3 healing potions" in str(l)), "and the potions")
	ok(carries.any(func(l): return "3 things in the pack" in str(l)), "and the pack")
	var empty := _dead("old age", 9)
	var e: Array = GameDeath.summary(empty)["sections"][1]["lines"]
	ok("none yet" in str(e[0]) and "nothing built" in str(e[1]) and "none earned" in str(e[2]), "a house with nothing says so: %s" % str(e))


func test_reads_only() -> void:
	var d := _dead("old age")
	var before := JSON.stringify(d.to_dict())
	var rng := d.rng.state
	GameDeath.summary(d)
	GameDeath.summary(d)
	ok(JSON.stringify(d.to_dict()) == before and d.rng.state == rng, "the summary changes nothing and draws no die")
	# the same death is told whether the rules ran in the open world, the text game or by the autopilot: the record is the dynasty's
	var bot := _dyn(21)
	for i in 400:
		if bot.state != "life":
			break
		GameBot.step(bot)
	ok(bot.state != "succession" or GameDeath.has_death(bot), "a death the autopilot reaches can be told")


func test_carry_text() -> void:
	ok(GameDeath.carry_text(["Ann"]) == "Carry on as Ann", "one heir: %s" % GameDeath.carry_text(["Ann"]))
	ok(GameDeath.carry_text(["Ann", "Bo"]) == "Carry on as Ann / Bo", "two heirs")
	ok(GameDeath.carry_text(["A", "B", "C", "D"]) == "Carry on: choose the heir", "many heirs: the plain choice")
	ok(GameDeath.carry_text([]) == "Carry on: choose the heir", "none")


func test_flow() -> void:
	var app: Node = GameApp.new()
	root.add_child(app)
	await process_frame
	await process_frame
	app.hints.set_process(false)
	app.new_game("Tess", "warrior", "faetouched", 31, "human")
	var d: GameDynasty = app.dynasty
	d.pending_event = {}
	d.heir.age = maxf(d.heir.age, d.heir.family_min_age())
	if not d.heir.family_founded:
		d.found_family()
	d.retire()
	app.show_state()
	await process_frame
	await process_frame
	ok(app.current is DeathPanel, "an heir's death shows the summary first")
	var panel: Control = app.current
	ok(panel.find_child("Title", true, false) != null and (panel.find_child("Title", true, false) as Label).text == "Tess has passed.", "with who died")
	ok(panel.find_child("Killer", true, false) != null, "and what killed them")
	var btn := panel.find_child("CarryOn", true, false) as Button
	ok(btn != null and btn.text.begins_with("Carry on"), "and the button that carries on: %s" % (btn.text if btn != null else ""))
	var state := d.state
	var cand := d.candidates.size()
	btn.pressed.emit()
	await process_frame
	await process_frame
	ok(app.current is SuccessionScreen and d.state == state and d.candidates.size() == cand, "carrying on goes to the unchanged succession screen")
	app.show_state()
	await process_frame
	ok(app.current is SuccessionScreen, "and the same death is not told twice (a screen laid out again, a chronicle closed)")
	d.choose_heir(0)
	app.show_state()
	await process_frame
	ok(not (app.current is DeathPanel or app.current is SuccessionScreen), "the new heir lives")
	d.heir.age = maxf(d.heir.age, d.heir.family_min_age())
	if not d.heir.family_founded:
		d.found_family()
	d.retire()
	app.show_state()
	await process_frame
	await process_frame
	ok(app.current is DeathPanel, "the next heir's death is told again")
	app.death_panel_on = false
	app._death_seen = -1
	app.show_state()
	await process_frame
	ok(app.current is SuccessionScreen, "with the summary off, the succession is first")
	app.queue_free()
