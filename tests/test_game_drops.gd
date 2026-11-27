## Loot on the open world's ground (core/game/game_drops.gd, data/world/drops.json, ui/play/drop_art.gd): a won open-world fight leaves what
## the dead carried as drops where they fell (the search of the bodies played on a copy, so the gains and the dynasty's dice are exactly a search's),
## the heir takes them by walking over them (carry limits, a too-heavy line once, the sickness a search risks paid with the first thing taken), they go
## when their time runs out and never upstairs or indoors, the saved list loads from old and damaged saves, the look is data, and the screen over the map.
## Run: godot --headless --path . -s res://tests/test_game_drops.gd
extends SceneTree

const MapFight := preload("res://ui/play/map_fight.gd")
const DropArt := preload("res://ui/play/drop_art.gd")

var fails := 0
var checks := 0


class FakeSound extends Node:
	func cue(_c: Variant) -> void:
		pass


class FakeApp extends Node:
	var dynasty: GameDynasty
	var sound := FakeSound.new()
	var hunt_stopped := false
	var current: Control = null
	var shown := 0

	func show_state() -> void:
		shown += 1

	func autosave() -> void:
		pass


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	GameDynasty.save_path = "user://test_drops.json"
	test_data()
	test_same_search()
	test_scatter()
	test_pickup()
	test_heavy()
	test_sickness()
	test_egg()
	test_time()
	test_sandbox()
	test_save()
	await test_look()
	await test_screen()
	print("drops tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(seed_value: int = 7) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


func _loot(d: GameDynasty, n: int = 3, carries: Array = []) -> void:
	var foes: Array = []
	for i in n:
		foes.append({"id": "wolf", "name": "Wolf", "carries": carries})
	d.loot = {"gold": 90 * n, "item_chance": 1.0, "foes": foes}
	d.last_result = "victory"


func _copy(d: GameDynasty) -> GameDynasty:
	return GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))


func _walk_all(d: GameDynasty) -> void:
	for p in d.drops.duplicate():
		GameDrops.collect(d, Vector2(float(p["x"]), float(p["z"])))


func test_data() -> void:
	ok(GameDrops.validate().is_empty(), "the data is sound: %s" % str(GameDrops.validate()))
	var saved: Dictionary = GameDrops.data().duplicate(true)
	var bad: Dictionary = saved.duplicate(true)
	bad["settings"]["reach"] = 0.0
	GameDrops._cache = bad
	ok(not GameDrops.validate().is_empty(), "a reach of nothing is refused")
	bad = saved.duplicate(true)
	bad["settings"]["beam_from"] = "godly"
	GameDrops._cache = bad
	ok(not GameDrops.validate().is_empty(), "a rarity the loot data does not know is refused")
	bad = saved.duplicate(true)
	bad["kinds"]["egg"]["shape"] = "cube"
	GameDrops._cache = bad
	ok(not GameDrops.validate().is_empty(), "an unknown shape is refused")
	bad = saved.duplicate(true)
	(bad["text"] as Dictionary).erase("heavy")
	GameDrops._cache = bad
	ok(not GameDrops.validate().is_empty(), "a missing text is refused")
	GameDrops._cache = saved
	ok(GameDrops.validate().is_empty(), "and the data is back")


## The ground gives what the search of the bodies gives: the same gold, potions, finds and materials, and the dynasty's own dice end where a search leaves them.
func test_same_search() -> void:
	for seed_value in [3, 7, 11, 19, 23]:
		var a := _dyn(seed_value)
		_loot(a, 4)
		var b := _copy(a)
		var gold0 := a.heir.gold
		var lines := GameLoot.search_dead(a)   # the text game's way
		var made := GameDrops.scatter(b, [Vector2(10.5, 10.5)])
		var gold := 0
		var items: Array = []
		for p in made:
			if p["kind"] == "gold":
				gold += int(p["gold"])
			if p["kind"] == "item":
				items.append(p["item"])
		ok(a.heir.gold - gold0 == gold, "seed %d: the gold on the ground is the gold a search gives (%d)" % [seed_value, gold])
		ok(items.size() >= 0 and a.heir.inventory.size() >= items.size(), "seed %d: the finds are the search's" % seed_value)
		ok(a.rng.state == b.rng.state, "seed %d: the dynasty's dice end where a search leaves them" % seed_value)
		ok(b.loot.is_empty() and b.heir.gold == _dyn(seed_value).heir.gold, "seed %d: nothing is taken until it is picked up" % seed_value)
		ok(lines.size() > 0, "seed %d: the search told something" % seed_value)
	# and what picking everything up adds is what the search added (this pack is far from full)
	var s1 := _dyn(5)
	_loot(s1, 3)
	var s2 := _copy(s1)
	var inv0 := s1.heir.inventory.size()
	var pot0 := s1.heir.potions
	var gold1 := s1.heir.gold
	GameLoot.search_dead(s1)
	GameDrops.scatter(s2, [Vector2(4.5, 4.5)])
	_walk_all(s2)
	ok(s2.heir.gold == s1.heir.gold and s2.heir.inventory == s1.heir.inventory and s2.heir.potions == s1.heir.potions, "taking it all is the search's result (gold %d, pack %d, potions %d)" % [s2.heir.gold - gold1, s2.heir.inventory.size() - inv0, s2.heir.potions - pot0])
	ok(GameCraft.materials(s2) == GameCraft.materials(s1) and GameCraft.essences(s2) == GameCraft.essences(s1), "and the materials too")
	ok(s2.roster.size() == s1.roster.size(), "and the young")


func test_scatter() -> void:
	var d := _dyn()
	_loot(d, 3)
	var spots := [Vector2(20.5, 30.5), Vector2(21.5, 30.5)]
	var made := GameDrops.scatter(d, spots)
	ok(not made.is_empty() and d.drops.size() == made.size(), "drops are made and kept on the dynasty")
	ok(d.loot.is_empty(), "the bodies are searched: no choice is left to make")
	var near := true
	for p in made:
		near = near and absf(float(p["x"]) - 21.0) <= 2.6 and absf(float(p["z"]) - 30.5) <= 1.6
	ok(near, "they lie round where the foes fell")
	var tiles := {}
	var uniq := true
	for p in made:
		var k := "%d,%d" % [floori(float(p["x"])), floori(float(p["z"]))]
		uniq = uniq and not tiles.has(k)
		tiles[k] = true
	ok(uniq, "no two on a tile")
	ok(made.any(func(p): return p["kind"] == "gold"), "the gold is among them")
	for p in made:
		ok(float(p["until"]) > d.world_seconds, "each has a time")
		break
	var e := _dyn()
	_loot(e, 3)
	var again := GameDrops.scatter(e, spots)
	ok(JSON.stringify(again) == JSON.stringify(made), "the same fight on the same seed leaves the same drops, in the same places")
	ok(GameDrops.scatter(_dyn(), spots).is_empty(), "no bodies, no drops")
	var dead := _dyn()
	_loot(dead, 2)
	dead.state = "succession"
	ok(GameDrops.scatter(dead, spots).is_empty(), "nothing is left by a heir who is not in a life")
	# a blocked tile is not landed on
	var f := _dyn()
	_loot(f, 3)
	var blocked := func(t: Vector2i): return t.x != 20
	var got := GameDrops.scatter(f, [Vector2(20.5, 30.5)], blocked)
	ok(got.all(func(p): return floori(float(p["x"])) != 20), "a tile that cannot be stood on is passed by")
	# more than the cap: the oldest go
	var g := _dyn()
	for i in 20:
		_loot(g, 6)
		g.total_hunts += 1
		GameDrops.scatter(g, [Vector2(40.5 + i, 40.5)])
	ok(g.drops.size() <= int(GameDrops.setting("max_drops")), "only so many lie about (%d)" % g.drops.size())


func test_pickup() -> void:
	var d := _dyn()
	_loot(d, 3)
	var made := GameDrops.scatter(d, [Vector2(20.5, 30.5)])
	var gold_drop: Dictionary = made.filter(func(p): return p["kind"] == "gold")[0]
	var at := Vector2(float(gold_drop["x"]), float(gold_drop["z"]))
	ok(GameDrops.collect(d, at + Vector2(3, 0)).is_empty(), "out of reach: nothing is taken")
	var gold := d.heir.gold
	var news := GameDrops.collect(d, at + Vector2(0.5, 0.0))
	ok(d.heir.gold == gold + int(gold_drop["gold"]), "walking over the coins takes them")
	ok(news.size() >= 1 and "gold" in str(news[0]["text"]), "and says so")
	ok(not d.drops.has(gold_drop), "and they are gone from the ground")
	ok(GameDrops.collect(d, at).is_empty() or d.drops.size() < made.size(), "once")
	# the kinds of look
	for p in made:
		ok(GameDrops.shape_of(p) in GameDrops.SHAPES and GameDrops.label_of(p) != "", "%s has a shape and a name" % p["kind"])
	var common := {"kind": "gold", "gold": 5, "uid": 1}
	var rare := {"kind": "item", "item": GameLoot.make_id("epic", "weapon", "sword", "iron", [], "", 1, 5), "uid": 2}
	ok(GameDrops.rarity_of(common) == "common" and not GameDrops.beams(common), "gold is common and throws no beam")
	ok(GameDrops.rarity_of({"kind": "essence", "uid": 3}) == "rare" and GameDrops.beams({"kind": "essence", "uid": 3}), "essence is rare and throws a beam")
	ok(GameDrops.shape_of({"kind": "item", "item": "no_such_item", "uid": 4}) == "bundle", "an ordinary find is a bundle")
	ok(rare["kind"] == "item", "a made item is an item")


func test_heavy() -> void:
	var d := _dyn()
	var id := GameLoot.roll_item(_rng(5), 1)
	var drop := {"uid": 1, "gid": 1, "kind": "item", "item": id, "x": 5.5, "z": 5.5, "until": 999.0, "sick": []}
	d.drops = [drop]
	var weighed := d.heir.potions
	d.heir.potions = 100000   # a pack nobody can lift
	var warned := {}
	var first := GameDrops.collect(d, Vector2(5.5, 5.5), warned)
	ok(first.size() == 1 and bool(first[0]["bad"]) and "too heavy" in str(first[0]["text"]), "an item too heavy stays with a line that says so: %s" % [str(first)])
	ok(d.drops.size() == 1 and not d.heir.inventory.has(id), "and stays on the ground")
	ok(GameDrops.collect(d, Vector2(5.5, 5.5), warned).is_empty(), "the heir standing there is told once")
	GameDrops.collect(d, Vector2(20.5, 20.5), warned)
	ok(not warned.has(1), "walking away forgets it, so the next visit tells again")
	d.heir.potions = weighed
	var pack := d.heir.inventory.size()
	GameDrops.collect(d, Vector2(5.5, 5.5), warned)
	ok(d.heir.inventory.size() == pack + 1 and d.drops.is_empty(), "with room again it is taken")


func _rng(n: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = n
	return r


func test_sickness() -> void:
	var sick_id := str(GameDisease.all()[0]["id"])
	var found := false
	for seed_value in range(1, 80):
		var d := _dyn(seed_value)
		_loot(d, 4, [{"disease": sick_id, "chance": 1.0}])
		var made := GameDrops.scatter(d, [Vector2(20.5, 30.5)])
		if made.is_empty() or (made[0]["sick"] as Array).is_empty():
			continue
		found = true
		ok(not GameDisease.has(d.heir, sick_id), "seed %d: the sickness is not caught by leaving the dead alone" % seed_value)
		ok(made.all(func(p): return p["sick"] == made[0]["sick"]), "it waits in every drop of that fight")
		var first: Dictionary = made[0]
		var news := GameDrops.collect(d, Vector2(float(first["x"]), float(first["z"])))
		ok(GameDisease.has(d.heir, sick_id), "the first thing taken costs the sickness")
		ok(news.any(func(n): return bool(n["bad"]) and "catches" in str(n["text"])), "and it is told")
		ok(d.drops.all(func(p): return (p["sick"] as Array).is_empty()), "once for the whole fight")
		break
	ok(found, "some seed's search caught the sickness")
	# a clean fight never makes anyone ill
	var c := _dyn(9)
	_loot(c, 3)
	GameDrops.scatter(c, [Vector2(3.5, 3.5)])
	_walk_all(c)
	ok(c.heir.diseases.is_empty(), "the clean dead sicken no one")


func test_egg() -> void:
	var species := ""
	for c in GameData.creatures:
		if GameBirth.born(str(c["id"])) != "none":
			species = str(c["id"])
			break
	var d := _dyn()
	d.drops = [{"uid": 1, "gid": 1, "kind": "egg", "species": species, "name": "Pip", "born": GameBirth.born(species), "x": 6.5, "z": 6.5, "until": 999.0, "sick": []}]
	var news := GameDrops.collect(d, Vector2(6.5, 6.5))
	ok(d.roster.size() == 1 and str(d.roster[0]["name"]) == "Pip" and d.drops.is_empty(), "an egg is taken into the house with its name")
	ok(d.flags.has(str(GameFinding.setting("found_flag"))), "and the house has found young")
	ok(news.size() == 1 and "Pip" in str(news[0]["text"]), "and says so")
	var full := _dyn()
	while not GameRoster.full(full):
		GameRoster.add(full, species, "x")
	full.drops = [{"uid": 1, "gid": 1, "kind": "egg", "species": species, "name": "Pip", "born": "egg", "x": 6.5, "z": 6.5, "until": 999.0, "sick": []}]
	var w := {}
	var n2 := GameDrops.collect(full, Vector2(6.5, 6.5), w)
	ok(full.drops.size() == 1 and n2.size() == 1 and bool(n2[0]["bad"]), "with no room it stays and says so")
	ok(GameDrops.collect(full, Vector2(6.5, 6.5), w).is_empty(), "once")


func test_time() -> void:
	var d := _dyn()
	_loot(d, 2)
	GameDrops.scatter(d, [Vector2(8.5, 8.5)])
	var n := d.drops.size()
	d.world_seconds += float(GameDrops.setting("ttl_seconds")) - 1.0
	ok(GameDrops.lying(d).size() == n, "just before its time it still lies")
	d.world_seconds += 2.0
	ok(GameDrops.lying(d).is_empty(), "past its time it is not there to see")
	var news := GameDrops.collect(d, Vector2(50.5, 50.5))
	ok(d.drops.is_empty() and news.size() == 1 and str(news[0]["kind"]) == "gone", "and the ground is cleared, with a line")
	# the clock never goes backwards, but a drop made later lives its own time
	d.world_seconds = 100.0
	_loot(d, 2)
	d.total_hunts += 1
	var made := GameDrops.scatter(d, [Vector2(8.5, 8.5)])
	ok(float(made[0]["until"]) == 100.0 + float(GameDrops.setting("ttl_seconds")), "a drop lives the data's time from when it fell")


func _sandbox_with_loot(seed_value: int = 7) -> GameSandbox:
	var d := _dyn(seed_value)
	var s := GameSandbox.start(d)
	s.creatures.clear()
	_loot(d, 3)
	return s


func test_sandbox() -> void:
	var s := _sandbox_with_loot()
	s.fight_spots = [Vector2(float(s.heir.x) + 1.5, float(s.heir.y) + 0.5)]
	s.after_fight()
	ok(not s.d.drops.is_empty() and s.d.loot.is_empty(), "a won open-world fight leaves its loot on the ground")
	ok(s.fight_spots.is_empty(), "the spots are used up")
	ok(s.log.any(func(l): return l["kind"] == "drop"), "and the log says where it is")
	var gold := s.d.heir.gold
	# walk over it: the sandbox's tick takes what is in reach
	for p in s.d.drops.duplicate():
		s.heir = Vector2i(floori(float(p["x"])), floori(float(p["z"])))
		s.step(1)
	ok(s.d.drops.is_empty() or s.d.drops.size() < 3, "stepping on it on the ground takes it")
	ok(s.d.heir.gold > gold, "the gold is the heir's")
	ok(not s.drop_news.is_empty(), "the screen is told")
	# not upstairs, not indoors
	var up := _sandbox_with_loot()
	up.after_fight()
	var left := up.d.drops.size()
	up.heir_y = GameBuild.SURFACE - 2
	var p0: Dictionary = up.d.drops[0]
	up.heir = Vector2i(floori(float(p0["x"])), floori(float(p0["z"])))
	up._take_drops()
	ok(up.d.drops.size() == left, "nothing is taken from upstairs")
	up.heir_y = GameBuild.SURFACE
	up.space = "somewhere_inside"
	up._take_drops()
	ok(up.d.drops.size() == left, "nor from indoors")
	# a flight leaves nothing; a dungeon's dead are not the ground's
	var fled := _sandbox_with_loot()
	fled.d.last_result = "fled"
	fled.after_fight()
	ok(fled.d.drops.is_empty() and not fled.d.loot.is_empty(), "a flight leaves no loot on the ground")
	var dun := _sandbox_with_loot()
	dun.fight_foes = [{"x": 1.0}]
	dun.after_fight()
	ok(dun.d.drops.is_empty() and not dun.d.loot.is_empty(), "a dungeon's fight is not the open ground's: its loot is as it was")
	# a fight with no recorded place leaves the loot at the heir
	var nowhere := _sandbox_with_loot()
	nowhere.after_fight()
	ok(nowhere.d.drops.all(func(p): return absf(float(p["x"]) - nowhere.heir_point().x) <= 2.6), "with no place recorded the loot falls by the heir")
	# the autopilot never plays an open-world fight: a life played by the bot never holds a drop
	var bot := _dyn(13)
	for i in 5:
		GameBot.step(bot)
	ok(bot.drops.is_empty() and not bot.to_dict().has("drops"), "the autopilot leaves none, and a save without drops has no key")


func test_save() -> void:
	var d := _dyn()
	ok(not d.to_dict().has("drops"), "no drops, no key")
	_loot(d, 3)
	GameDrops.scatter(d, [Vector2(20.5, 30.5)])
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(JSON.stringify(back.drops) == JSON.stringify(d.drops.map(func(p): return GameDrops.load_list([p])[0])), "the drops come back as they lay")
	ok(back.drops.size() == d.drops.size(), "all of them")
	var old: Dictionary = d.to_dict()
	old.erase("drops")
	ok(GameDynasty.from_dict(old).drops.is_empty(), "an old save has none")
	for junk in ["x", 5, {"a": 1}, [1, "z", null, {"kind": "gold"}, {"kind": "nope", "uid": 1, "gid": 1, "x": 1.0, "z": 1.0, "until": 5.0}, {"kind": "gold", "uid": 1, "gid": 1, "x": NAN, "z": 1.0, "until": 5.0}, {"kind": "gold", "uid": 2, "gid": 1, "x": -50.0, "z": 1.0, "until": 5.0, "gold": 3}, {"kind": "item", "uid": 3, "gid": 1, "x": 5.5, "z": 5.5, "until": 5.0, "item": "no_such"}]]:
		ok(GameDrops.load_list(junk).is_empty(), "damaged drops load as none (%s)" % str(junk).left(30))
	var good := GameDrops.load_list([{"kind": "gold", "uid": 2, "gid": 1, "x": 5.5, "z": 5.5, "until": 5.0, "gold": "7", "sick": ["nonsense"]}, {"kind": "gold", "uid": 2, "gid": 1, "x": 6.5, "z": 5.5, "until": 5.0, "gold": 1}])
	ok(good.size() == 1 and int(good[0]["gold"]) == 7 and (good[0]["sick"] as Array).is_empty(), "a repeated id and an unknown sickness are dropped, a number as text is read")


func test_look() -> void:
	var gem := {"kind": "essence", "uid": 1}
	ok(DropArt.tag_of(gem).contains("Rare") and DropArt.tag_of(gem).begins_with("*"), "a rare drop wears its mark and word: %s" % DropArt.tag_of(gem))
	ok(DropArt.tag_of({"kind": "gold", "uid": 1, "gold": 3}) == "Common", "a common one wears its word")
	ok(DropArt.color_of(gem) != DropArt.color_of({"kind": "gold", "uid": 1}), "and its colour")
	var canvas := Control.new()
	root.add_child(canvas)
	var seen := [0]
	canvas.draw.connect(func():
		for kind in ["gold", "potion", "essence", "material", "egg"]:
			DropArt.paint(canvas, {"kind": kind, "uid": 3, "gold": 4, "n": 1, "mats": {}, "species": "wolf"}, Vector2(50, 50), 40.0, Color.WHITE, 1.3, 100.0)
		DropArt.paint(canvas, {"kind": "gold", "uid": 5, "gold": 4}, Vector2(100, 50), 40.0, Color.WHITE, 1.3, 5.0)   # about to go: blinks
		DropArt.paint(canvas, {"kind": "gold", "uid": 5, "gold": 4}, Vector2(100, 50), 12.0, Color.WHITE, 1.3, 100.0)   # tiny: no label
		seen[0] += 1)
	canvas.queue_redraw()
	await process_frame
	await process_frame
	ok(seen[0] > 0, "every kind of drop draws (with a blink, a bob and a tiny size without a label)")
	canvas.free()


func test_screen() -> void:
	var d := _dyn()
	var app := FakeApp.new()
	app.dynasty = d
	app.add_child(app.sound)
	root.add_child(app)
	var scr: Control = load("res://ui/play/sandbox_screen.gd").new()
	scr.app = app
	scr.size = Vector2(1280, 720)
	root.add_child(scr)
	await process_frame
	await process_frame
	scr.sb.creatures.clear()
	var p: Vector2 = scr.sb.heir_point()
	var a := GameBehaviour.new_agent(901, "wolf", p.x + 0.5, p.y)
	a["mode"] = "chase"
	scr.sb.creatures.append(a)
	scr.sb._contact()
	ok(d.battle != null and not scr.sb.fight_spots.is_empty(), "a fight begun on the ground knows where the creatures stood")
	await process_frame
	await process_frame
	ok(scr._fight != null and scr._fight.app.ground_loot, "the fight over the map leaves its spoils on the ground")
	for e in d.battle.enemies:
		e["hp"] = 0
	d.battle.result = "victory"
	d.finish_battle()
	ok(not d.loot.is_empty(), "the dead are offered as ever when the fight ends")
	scr._fight._show_result()
	await process_frame
	var note: Array = scr._fight.find_children("*", "Label", true, false).filter(func(l): return (l as Label).text == GameDrops.text("ground_note"))
	var searches: Array = scr._fight.find_children("*", "Button", true, false).filter(func(b): return (b as Button).text == "Search the bodies")
	ok(note.size() == 1 and searches.is_empty(), "the result says the spoils are on the ground and offers no search")
	scr._fight.app.show_state()
	await process_frame
	await process_frame
	ok(scr._fight == null and not d.drops.is_empty() and d.loot.is_empty(), "when the map has the fight back, the spoils lie on the ground")
	scr.overlay.queue_redraw()
	await process_frame
	await process_frame
	scr.sb.heir = Vector2i(floori(float(d.drops[0]["x"])), floori(float(d.drops[0]["z"])))
	var n0 := d.drops.size()
	scr.sb.step(1)
	await process_frame
	ok(d.drops.size() < n0, "the heir walks onto one and takes it")
	ok(scr.sb.drop_news.is_empty() and scr.last_line != "", "and the screen toasts it (%s)" % scr.last_line)
	# the text game's own fight keeps its choice
	var text_game := _dyn(9)
	var tapp := FakeApp.new()
	tapp.dynasty = text_game
	ok(not ("ground_loot" in tapp), "a stand-in without the flag (the real app) keeps the search choice")
	app.free()
	tapp.free()
	scr.free()
