## Faction reputation (roadmap item 17, first part): the data and the ways to break it; a new house is known to no
## one; each kind of rule; ancestors fading by the generation; the living heir's own deeds; the house's echoes,
## legends and milestones; ranks; the gift (once per heir, in a town, by rank, scaled) and the title at the top; that
## nothing is saved but the gift taken, old saves and damaged values load; that no die is drawn and the autopilot
## takes nothing; and the Chronicle's Factions tab.
## Run: godot --headless --path . -s res://tests/test_game_factions.gd
extends SceneTree

const DIR := "user://test_factions/"
const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const ChroniclePanel := preload("res://ui/play/chronicle_panel.gd")

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
	test_new_house()
	test_rules()
	test_fading()
	test_house()
	test_ranks()
	test_gift()
	test_titles()
	test_saving()
	test_untouched()
	await test_screen()
	print("factions tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func dyn(seed_value: int = 5, cls: String = "ranger") -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", cls, "faetouched", "human")
	d.pending_event = {}
	return d


func anc(d: GameDynasty, cls: String, ago: int = 1, more: Dictionary = {}) -> void:
	var r := {"gen": d.gen - ago, "class_id": cls, "level": 1, "battles_won": 0, "kills": {}, "gold": 0, "cause": "old age"}
	r.merge(more, true)
	d.history.append(r)


func _broken(edit: Callable, word: String) -> bool:
	var saved: Dictionary = GameFactions.data().duplicate(true)
	var titles: Dictionary = GameData.titles.duplicate(true)
	edit.call(GameFactions.data())
	var found := GameFactions.validate()
	GameFactions._cache = saved
	GameData.titles = titles
	return found.any(func(p): return word in str(p))


func test_data() -> void:
	ok(GameFactions.validate().is_empty(), "the factions are sound: %s" % str(GameFactions.validate()))
	ok(GameTitles.validate().is_empty(), "and the titles they confer: %s" % str(GameTitles.validate()))
	ok(GameFactions.ids().size() == 6, "six factions")
	var w := func(x): return x["factions"]["warriors_order"]
	ok(_broken(func(x): w.call(x)["remembers"][0]["what"] = "luck", "not something it can weigh"), "an unknown rule is refused")
	ok(_broken(func(x): w.call(x)["remembers"][0]["classes"] = ["bard"], "no class called"), "a class that does not exist is refused")
	ok(_broken(func(x): w.call(x)["remembers"][0]["each"] = 0, "adds nothing"), "a rule that adds nothing is refused")
	ok(_broken(func(x): w.call(x)["remembers"][1]["per"] = 0, "'per' above 0"), "a count per nothing is refused")
	ok(_broken(func(x): w.call(x)["remembers"][1]["cap"] = -3, "cap must be above 0"), "a cap below nothing is refused")
	ok(_broken(func(x): w.call(x)["remembers"][0].erase("say"), "does not say"), "a rule that says nothing is refused")
	ok(_broken(func(x): w.call(x)["memory"] = 1.5, "memory must be"), "a memory that grows is refused")
	ok(_broken(func(x): w.call(x)["remembers"] = [], "remembers nothing"), "a faction that remembers nothing is refused")
	ok(_broken(func(x): w.call(x)["boon"] = {"gold": 0}, "gives nothing"), "a gift of nothing is refused")
	ok(_broken(func(x): w.call(x)["boon"]["horse"] = 1, "cannot hold"), "a gift of something else is refused")
	ok(_broken(func(x): w.call(x)["title"] = "blooded", "must be a personal title earned by"), "a title earned another way is refused")
	ok(_broken(func(x): w.call(x)["title"] = "", "does not confer it"), "a title left without its faction is refused")
	ok(_broken(func(x): x["factions"]["church"]["remembers"][1]["tags"] = ["fish"], "no creature has the tag"), "a tag no creature has is refused")
	ok(_broken(func(x): x["factions"]["draconic_council"]["house"][0]["ids"] = ["wolf"], "is not a legend"), "a legend that is none is refused")
	ok(_broken(func(x): x["factions"]["church"]["house"][0]["kind"] = "slayer", "glory or infamy"), "an echo of another kind is refused")
	ok(_broken(func(x): x["ranks"][1]["min"] = -100, "does not start above"), "ranks out of order are refused")
	ok(_broken(func(x): x["ranks"][0]["min"] = -90, "lowest rank must start at -100"), "a standing with no rank is refused")
	ok(_broken(func(x): x["settings"]["boon_rank"] = "neutral", "knows nothing of"), "a gift for a stranger is refused")
	ok(_broken(func(x): x["settings"]["top_rank"] = "trusted", "not the highest"), "a top rank that is not the top is refused")
	ok(_broken(func(x): x["factions"]["draconic_council"]["remembers"].pop_back(), "never think well"), "a faction that can never think well of anyone is refused")
	ok(_broken(func(x): x["text"].erase("gift"), "text 'gift'"), "missing text is refused")


func test_new_house() -> void:
	var d := dyn()
	d.heir.titles = []
	for id in GameFactions.ids():
		var s := GameFactions.standing(d, id)
		ok(GameFactions.rank(d, id) == "neutral" and absi(s) < 15, "%s holds a new house as neutral (%d)" % [id, s])
		ok(GameFactions.gift_text(GameFactions.gift(d, id)) == "", "%s offers it nothing" % id)
	ok(GameFactions.standing(d, "warriors_order") == 0 and GameFactions.reasons(d, "warriors_order").is_empty(), "the Order knows nothing of a ranger with no deeds")
	ok(GameFactions.describe(d, "warriors_order")["remembers"] == "It knows nothing of the house yet.", "and says so")
	ok(GameFactions.standing(d, "draconic_council") == 4, "the Council thinks a little of a ranger")
	ok(GameFactions.standing(d, "nonesuch") == 0 and GameFactions.rank(d, "nonesuch") == "neutral", "an unknown faction is nothing")


func test_rules() -> void:
	var h := {"ago": 0, "class_id": "warrior", "level": 47, "battles_won": 60, "kills": {"skeleton": 30, "ghoul": 25, "wolf": 400, "drake": 12}, "gold": 45000, "cause": "slain in battle", "titles": 3}
	ok(GameFactions.heir_points({"what": "class", "classes": ["warrior"], "each": 6}, h) == 6.0, "class: once")
	ok(GameFactions.heir_points({"what": "class", "classes": ["mage"], "each": 6}, h) == 0.0, "class: not theirs")
	ok(GameFactions.heir_points({"what": "level", "per": 20, "each": 2}, h) == 4.0, "level: each full twenty")
	ok(GameFactions.heir_points({"what": "battles", "per": 25, "each": 2}, h) == 4.0, "battles: each full twenty-five")
	ok(GameFactions.heir_points({"what": "kills", "tags": ["undead"], "per": 25, "each": 2}, h) == 4.0, "kills by tag: 55 undead is two lots")
	ok(GameFactions.heir_points({"what": "kills", "creatures": ["drake"], "per": 5, "each": -3}, h) == -6.0, "kills by name, against")
	ok(GameFactions.heir_points({"what": "kills", "creatures": ["wolf"], "per": 5, "each": 1, "cap": 10}, h) == 10.0, "a cap holds it")
	ok(GameFactions.heir_points({"what": "kills", "creatures": ["wolf"], "per": 5, "each": -1, "cap": 10}, h) == -10.0, "either way")
	ok(GameFactions.heir_points({"what": "gold", "per": 20000, "each": 2}, h) == 4.0, "gold: each full lot")
	ok(GameFactions.heir_points({"what": "cause", "causes": ["slain in battle"], "each": 3}, h) == 3.0, "cause: how they died")
	ok(GameFactions.heir_points({"what": "titles", "each": 2}, h) == 6.0, "titles: each")
	ok(GameFactions.heir_points({"what": "nonsense", "each": 2}, h) == 0.0, "an unknown rule adds nothing")
	# the living heir's own deeds count in full
	var d := dyn(5, "warrior")
	ok(GameFactions.standing(d, "warriors_order") == 6, "a warrior is known to the Order for bearing arms: %d" % GameFactions.standing(d, "warriors_order"))
	d.heir.battles_won = 75
	ok(GameFactions.standing(d, "warriors_order") == 12, "and their battles add to it as they are won: %d" % GameFactions.standing(d, "warriors_order"))
	ok(GameFactions.remembered(d).size() == 1 and GameFactions.remembered(d)[0]["ago"] == 0, "one heir remembered, the living one")


func test_fading() -> void:
	var d := dyn()
	d.gen = 10
	anc(d, "warrior", 1)
	ok(GameFactions.standing(d, "warriors_order") == int(round(6 * 0.85)), "a warrior parent, one generation faded: %d" % GameFactions.standing(d, "warriors_order"))
	var far := dyn()
	far.gen = 10
	anc(far, "warrior", 8)
	ok(GameFactions.standing(far, "warriors_order") < GameFactions.standing(d, "warriors_order"), "eight generations back counts for less")
	var many := dyn()
	many.gen = 10
	for i in 6:
		anc(many, "warrior", i + 1)
	var s := GameFactions.standing(many, "warriors_order")
	ok(s >= 20 and GameFactions.rank(many, "warriors_order") == "trusted", "six generations of warriors are trusted by the Order: %d" % s)
	ok(GameFactions.describe(many, "warriors_order")["remembers"] == "It remembers 6 of the line bore arms.", "and it says what it remembers: %s" % GameFactions.describe(many, "warriors_order")["remembers"])
	# the Church forgets slowly, the Guild fast
	var c := dyn()
	c.gen = 20
	anc(c, "cleric", 15)
	anc(c, "rogue", 15)
	ok(GameFactions.standing(c, "church") > GameFactions.standing(c, "thieves_guild"), "the Church remembers a cleric of fifteen generations ago better than the Guild a rogue")
	# bad legacy
	var dark := dyn()
	dark.gen = 5
	for i in 4:
		anc(dark, "necromancer", i + 1)
	ok(GameFactions.standing(dark, "church") <= -15 and GameFactions.rank(dark, "church") in ["wary", "hostile"], "a line of necromancers is held warily by the Church: %d" % GameFactions.standing(dark, "church"))
	ok(GameFactions.standing(dark, "mages_circle") > 0, "and well by the Circle")
	# only what the chronicle keeps is remembered
	var folded := dyn()
	folded.gen = 400
	folded.ages.summaries = [{"age": 1, "heirs": 300, "legends": [], "causes": {}}]
	ok(GameFactions.standing(folded, "warriors_order") == 0, "heirs folded into the Ages are forgotten")
	# damaged records do not crash
	var odd := dyn()
	odd.history.append({"gen": "x", "kills": "many", "titles": 9})
	odd.history.append({})
	ok(GameFactions.standing(odd, "warriors_order") == 0, "a damaged record is weighed as nothing")


func test_house() -> void:
	var d := dyn()
	d._add_echo("glory", "x", "x", 0.5)
	ok(GameFactions.standing(d, "warriors_order") == 15, "glory counts with the Order: %d" % GameFactions.standing(d, "warriors_order"))
	d._add_echo("infamy", "y", "y", 0.5)
	ok(GameFactions.standing(d, "church") == -20 and GameFactions.standing(d, "thieves_guild") == 20, "infamy counts against the house with the Church and for it with the Guild")
	d._add_echo("infamy", "z", "z", 1.0)
	ok(GameFactions.standing(d, "church") == -30, "within the rule's cap: %d" % GameFactions.standing(d, "church"))
	var k := dyn()
	k.slain_bosses["vaerthax"] = 1
	ok(GameFactions.standing(k, "draconic_council") == -46 and GameFactions.rank(k, "draconic_council") == "hostile", "the Council does not forgive Vaerthax: %d" % GameFactions.standing(k, "draconic_council"))
	ok("Vaerthax, slain by the house" in str(GameFactions.describe(k, "draconic_council")["remembers"]), "and says why")
	var m := dyn()
	m.achievements = {"line_5": {}, "years_50": {}, "legend_1": {}}
	ok(GameFactions.standing(m, "noble_houses") == 3, "milestones count with the Noble Houses")
	var big := dyn()
	big.gen = 3
	for i in 40:
		anc(big, "warrior", 1, {"battles_won": 1000})
	ok(GameFactions.standing(big, "warriors_order") == 100, "a standing never passes 100")


func test_ranks() -> void:
	for pair in [[-100, "hostile"], [-41, "hostile"], [-40, "wary"], [-16, "wary"], [-15, "neutral"], [0, "neutral"], [19, "neutral"], [20, "trusted"], [49, "trusted"], [50, "honoured"], [100, "honoured"]]:
		ok(GameFactions.rank_at(pair[0])["id"] == pair[1], "%d is %s" % pair)
	var d := dyn()
	d._add_echo("glory", "x", "x", 1.0)
	ok(GameFactions.at_least(d, "warriors_order", "trusted") and not GameFactions.at_least(d, "warriors_order", "honoured"), "trusted is at least trusted and not honoured")
	ok(GameFactions.at_least(d, "warriors_order", "hostile") and not GameFactions.at_least(d, "warriors_order", "nonesuch") and not GameFactions.at_least(d, "nonesuch", "hostile"), "an unknown rank or faction is never reached")


func test_gift() -> void:
	var d := dyn(5, "warrior")
	d.world.location = "hearthmere"
	ok(GameFactions.why_not(d, "warriors_order") == "The Warrior's Order offers nothing to an heir it only holds as neutral.", "no gift for a stranger: %s" % GameFactions.why_not(d, "warriors_order"))
	d._add_echo("glory", "x", "x", 0.6)   # 18 + 6 for a warrior = 24: trusted
	ok(GameFactions.rank(d, "warriors_order") == "trusted", "trusted")
	d.heir.level = 3
	var g := GameFactions.gift(d, "warriors_order")
	ok(g == {"gold": int(round(60 * GameData.enemy_scale(1))), "potions": 1, "xp": 120}, "the Order's gift, gold by the generation and XP by the level: %s" % str(g))
	var gold := d.heir.gold
	var potions := d.heir.potions
	var before := d.rng.state
	var got := GameFactions.take(d, "warriors_order")
	ok(got["ok"] and d.heir.gold == gold + g["gold"] and d.heir.potions == potions + 1, "taken: %s" % got["text"])
	ok("The Warrior's Order honours Tess: " in str(got["text"]) and d.journal[-1] == got["text"], "and told in the journal")
	ok(d.heir.boons == ["warriors_order"], "and marked on the heir")
	ok(not GameFactions.take(d, "warriors_order")["ok"] and d.heir.gold == gold + g["gold"], "once in a life")
	ok(GameFactions.why_not(d, "warriors_order") == "The Warrior's Order has already honoured Tess.", "and it says so")
	ok(d.rng.state == before, "no die is drawn")
	# honoured gives double
	var h := dyn(5, "warrior")
	h.world.location = "hearthmere"
	h.gen = 4
	for i in 12:
		anc(h, "warrior", 1, {"battles_won": 200})
	ok(GameFactions.rank(h, "warriors_order") == "honoured", "a great line is honoured")
	ok(GameFactions.gift(h, "warriors_order")["potions"] == 2 and GameFactions.gift(h, "warriors_order")["gold"] == int(round(120 * GameData.enemy_scale(4))), "and given twice as much, at its generation's prices")
	# not outside a town, not when dead, not a faction that is none
	var wild := dyn(5, "warrior")
	wild._add_echo("glory", "x", "x", 1.0)
	var wilds: Array = GameData.world["locations"].filter(func(l): return l["type"] != "town")
	wild.world.location = str(wilds[0]["id"])
	ok(GameFactions.why_not(wild, "warriors_order") == "The Warrior's Order receives an heir only in a town.", "only in a town")
	wild.world.location = "hearthmere"
	wild.state = "dead"
	ok(not GameFactions.take(wild, "warriors_order")["ok"], "not for the dead")
	ok(not GameFactions.take(d, "nonesuch")["ok"], "not from a faction that is none")
	# the next heir may be honoured again
	var next := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	next.heir.boons = []
	ok(GameFactions.why_not(next, "warriors_order") == "", "an heir who has not been honoured can be")


func test_titles() -> void:
	var d := dyn(5, "warrior")
	d.gen = 4
	ok("order_knight" not in GameTitles.update(d), "no title for a stranger")
	for i in 12:
		anc(d, "warrior", 1, {"battles_won": 200})
	ok("order_knight" in GameTitles.update(d) and "order_knight" in d.heir.titles, "honoured by the Order, the heir is a Knight of the Order")
	for id in GameFactions.ids():
		var t := str(GameFactions.faction(id).get("title", ""))
		if t == "":
			continue
		ok(GameTitles.def(t)["kind"] == "personal" and GameTitles.def(t)["when"] == {"faction": id}, "%s confers %s on the heir" % [id, t])


func test_saving() -> void:
	var d := dyn(5, "warrior")
	d.world.location = "hearthmere"
	ok(not d.to_dict()["heir"].has("boons"), "an heir no faction has honoured saves nothing of it")
	d._add_echo("glory", "x", "x", 1.0)
	GameFactions.take(d, "warriors_order")
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(back.heir.boons == ["warriors_order"] and GameFactions.standing(back, "warriors_order") == GameFactions.standing(d, "warriors_order"), "the gift taken survives a save and load, and the standing is worked out the same")
	var keys: Array = d.to_dict().keys()
	ok(not keys.any(func(k): return "faction" in str(k) or "standing" in str(k)), "no standing is saved")
	for junk in ["x", 4, {"a": 1}, null, ["nonesuch", 3, "church", "church"]]:
		var bad: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
		bad["heir"]["boons"] = junk
		var want: Array = ["church"] if typeof(junk) == TYPE_ARRAY else []
		ok(GameDynasty.from_dict(bad).heir.boons == want, "gifts saved as %s load as %s" % [str(junk), str(want)])
	var old: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	old["heir"].erase("boons")
	ok(GameDynasty.from_dict(old).heir.boons.is_empty(), "a save from before factions loads with none taken")


func _bot(d: GameDynasty) -> void:
	if d.state == "succession":
		GameBot.choose_best(d)
	else:
		GameBot.step(d)


func test_untouched() -> void:
	var a := GameDynasty.new_game(31, "Auto", "warrior", "noble", "human")
	var b := GameDynasty.new_game(31, "Auto", "warrior", "noble", "human")
	var seen := {}
	for i in 2500:
		_bot(a)
		_bot(b)
		for id in GameFactions.ids():
			seen[GameFactions.rank(b, id)] = true   # looking changes nothing
	ok(a.gen >= 3, "the autopilot plays generations (%d)" % a.gen)
	ok(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()) and a.rng.state == b.rng.state, "a house whose standings are looked at lives exactly the life of one that is never asked")
	ok(a.heir.boons.is_empty() and a.history.all(func(r): return not r.has("boons")), "and the autopilot takes no gift")
	var any := false
	for id in GameFactions.ids():
		if GameFactions.standing(a, id) != 0:
			any = true
	ok(any, "by then the factions have an opinion of the house: %s" % str(GameFactions.ids().map(func(id): return GameFactions.standing(a, id))))


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _texts(n: Node, out: Array) -> void:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_texts(c, out)


func _buttons(n: Node, out: Array) -> void:
	if n is Button:
		out.append(n)
	for c in n.get_children():
		_buttons(c, out)


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
	d.world.location = "hearthmere"
	d._add_echo("glory", "x", "x", 1.0)
	app.show_state()
	await _frames(3)
	var changed := [0]
	var c := ChroniclePanel.new()
	c.dynasty = d
	c.on_change = func(): changed[0] += 1
	app.current.add_child(c)
	await _frames(3)
	var tab := _find(c, "Factions")
	ok(tab != null, "the Chronicle has a Factions tab")
	var texts: Array = []
	_texts(tab, texts)
	for id in GameFactions.ids():
		var f := GameFactions.describe(d, id)
		ok(texts.has("%s: %s" % [f["name"], f["line"]]), "%s is listed with its standing" % id)
	ok(texts.any(func(t): return t.begins_with("It remembers the house's glory") and "Gift: " in t), "the Order's row says what it remembers and what it offers")
	var buttons: Array = []
	_buttons(tab, buttons)
	var accept: Array = buttons.filter(func(b): return b.text == "Accept" and not b.disabled)
	ok(accept.size() >= 1, "a faction that trusts the heir has an Accept button (%d)" % accept.size())
	var gold := d.heir.gold
	var taken_before: int = d.heir.boons.size()
	accept[0].pressed.emit()
	await _frames(3)
	ok(d.heir.boons.size() == taken_before + 1 and changed[0] == 1, "pressing it takes the gift and tells the screen behind")
	buttons.clear()
	_buttons(tab, buttons)
	ok(buttons.any(func(b): return b.text == "Honoured" and b.disabled), "and the row now shows the heir has been honoured")
	ok(d.heir.gold >= gold, "with the gift in hand")
	app.queue_free()
	await _frames(2)
