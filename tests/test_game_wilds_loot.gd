## Loot of the wilds' landmarks (GameWildsLoot; data/items/wilds_loot.json): deterministic from the seed, the area, the landmark and its
## use count and never the dynasty's dice, built on GameLoot (so it grows with the generation), bent by the kind of landmark (slots,
## rarity floor) and the place (preferred materials, themed uniques), with the uniques defined, never sold and never rolled twice.
## Run: godot --headless --path . -s res://tests/test_game_wilds_loot.gd
extends SceneTree

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
	test_breaks()
	test_roll()
	test_shape()
	test_growth()
	test_uniques()
	test_give()
	print("wilds loot tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh(seed_value: int = 77, gen: int = 1) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.gen = gen
	return d


func test_data() -> void:
	ok(GameWildsLoot.validate().is_empty(), "the shipped data passes: %s" % str(GameWildsLoot.validate()))
	var uniques := GameWildsLoot.unique_ids()
	ok(uniques.size() >= 14, "there are themed uniques (%d)" % uniques.size())
	for id in uniques:
		var it: Dictionary = GameData.items.get(id, {})
		ok(not it.is_empty() and it.get("unique", false) and str(it.get("shop", "x")) == "", "%s is a unique that no shop sells" % id)
		for town in ["hearthmere", "ironford", "kingshold", "brinehaven"]:
			var d := _fresh()
			d.world.visit(town)
			ok(not GameItems.sold_here(d, id), "%s is not sold in %s" % [id, town])
	for a in GameWilds.data()["areas"]:
		ok((GameWildsLoot.data()["areas"][a]["uniques"] as Array).size() >= 2, "%s has two or more themed uniques" % a)


func _with(change: Callable) -> void:
	var saved: Dictionary = GameWildsLoot.data().duplicate(true)
	change.call()
	ok(not GameWildsLoot.validate().is_empty(), "a break is found")
	GameWildsLoot._cache = saved


func test_breaks() -> void:
	_with(func(): GameWildsLoot.data()["areas"]["whisperwood"]["uniques"][0]["id"] = "iron_sword")
	_with(func(): GameWildsLoot.data()["areas"]["mirefen"]["uniques"] = [])
	_with(func(): GameWildsLoot.data()["kinds"]["ruin"]["slots"]["helmet"] = 5)
	_with(func(): GameWildsLoot.data()["kinds"]["lair"]["min_rarity"] = "godly")
	_with(func(): GameWildsLoot.data()["areas"]["highcrag"]["prefer"] = ["unobtainium"])
	_with(func(): GameWildsLoot.data()["areas"].erase("stormcoast"))
	_with(func(): GameWildsLoot.data()["biomes"].erase("coast"))
	_with(func(): GameWildsLoot.data()["areas"]["greenvale"]["uniques"][0] = {"id": "iron_sword", "min_gen": 1})
	ok(GameWildsLoot.validate().is_empty(), "and mending it clears them all")


func test_roll() -> void:
	var d := _fresh()
	var state := d.rng.state
	var a := GameWildsLoot.roll(d, "whisperwood", "lm:1:1", "ruin", {"n": 0})
	ok(a != "" and not GameLoot.build(a).is_empty() or GameData.items.has(a), "a roll gives an item that builds: %s" % a)
	ok(GameWildsLoot.roll(d, "whisperwood", "lm:1:1", "ruin", {"n": 0}) == a, "the same keys give the same item")
	ok(GameWildsLoot.roll(_fresh(), "whisperwood", "lm:1:1", "ruin", {"n": 0}) == a, "in another dynasty of the same seed")
	var seen := {}
	for i in 40:
		seen[GameWildsLoot.roll(d, "whisperwood", "lm:%d:1" % i, "ruin", {"n": 0})] = true
	ok(seen.size() > 20, "other landmarks give other things (%d of 40)" % seen.size())
	var uses := {}
	for n in 20:
		uses[GameWildsLoot.roll(d, "whisperwood", "lm:1:1", "ruin", {"n": n})] = true
	ok(uses.size() > 10, "and another use of the same one does")
	ok(GameWildsLoot.roll(_fresh(5), "whisperwood", "lm:1:1", "ruin", {"n": 0}) != a, "another seed differs")
	ok(d.rng.state == state, "no die of the dynasty's is drawn")
	ok(GameWildsLoot.roll(d, "", "lm:9:9", "well", {"biome": "plains"}) != "", "generic land rolls on its biome's table")


func _slot_share(area: String, kind: String, slot: String, n: int) -> float:
	var d := _fresh(77, 10)
	var hits := 0
	for i in n:
		var id := GameWildsLoot.roll(d, area, "lm:%d:%d" % [i, 7], kind, {"n": 0})
		if GameData.items.has(id):
			continue
		if str(GameLoot.parse(id).get("slot", "")) == slot:
			hits += 1
	return float(hits) / float(n)


func test_shape() -> void:
	ok(_slot_share("", "battlefield", "weapon", 150) > 0.55, "a battlefield gives weapons")
	ok(_slot_share("", "shrine", "trinket", 150) > 0.5, "a shrine gives trinkets")
	ok(_slot_share("", "shrine", "weapon", 150) < 0.2, "and few weapons")
	# a lair gives rare things at least
	var d := _fresh(77, 10)
	var low := 0
	for i in 60:
		var id := GameWildsLoot.roll(d, "whisperwood", "lm:%d:3" % i, "lair", {"n": 0})
		if GameData.items.has(id):
			continue
		if GameLoot.parse(id)["rarity"] in ["common", "fine"]:
			low += 1
	ok(low < 25, "a lair's finds are mostly rare or better (%d of 60 are not)" % low)
	# the place bends the materials: Mirefen gives herb, bone and glass things (trinkets of them) more than Highcrag
	var tags := {}
	for area in ["mirefen", "highcrag"]:
		var hit := 0
		for i in 120:
			var id := GameWildsLoot.roll(d, area, "lm:%d:5" % i, "cave", {"n": 0, "slots": {"trinket": 1}})
			if GameData.items.has(id):
				continue
			var p := GameLoot.parse(id)
			if "herb" in GameMaterials.tags_of(str(p["material"])) or "bone" in GameMaterials.tags_of(str(p["material"])) or "glass" in GameMaterials.tags_of(str(p["material"])):
				hit += 1
		tags[area] = hit
	ok(tags["mirefen"] > tags["highcrag"], "Mirefen's finds are of its own materials (%d against %d)" % [tags["mirefen"], tags["highcrag"]])
	# the boost lifts rarity
	var plain := 0
	var lucky := 0
	for i in 200:
		var a := GameWildsLoot.roll(d, "", "lm:%d:9" % i, "farm", {"n": 0, "biome": "plains", "boost": 1.0})
		var b := GameWildsLoot.roll(d, "", "lm:%d:9" % i, "farm", {"n": 0, "biome": "plains", "boost": 40.0})
		if not GameData.items.has(a) and GameLoot.parse(a)["rarity"] not in ["common", "fine"]:
			plain += 1
		if not GameData.items.has(b) and GameLoot.parse(b)["rarity"] not in ["common", "fine"]:
			lucky += 1
	ok(lucky > plain, "a bigger boost gives rarer things (%d against %d)" % [lucky, plain])


func test_growth() -> void:
	var early := _fresh(77, 1)
	var late := _fresh(77, 80)
	var top_early := 0
	var top_late := 0
	var grade_late := 0
	for i in 80:
		var a := GameWildsLoot.roll(early, "", "lm:%d:11" % i, "ruin", {"n": 0, "biome": "hills"})
		var b := GameWildsLoot.roll(late, "", "lm:%d:11" % i, "ruin", {"n": 0, "biome": "hills"})
		if not GameData.items.has(a):
			top_early = maxi(top_early, int(GameLoot.parse(a)["tier"]))
		if not GameData.items.has(b):
			top_late = maxi(top_late, int(GameLoot.parse(b)["tier"]))
			grade_late = maxi(grade_late, int(GameLoot.parse(b)["grade"]))
	ok(top_early <= GameLoot.tier_ceiling(1) + 2, "early finds stay within what the generator allows (tier %d)" % top_early)
	ok(top_late > top_early, "later finds are of higher tiers (%d against %d)" % [top_late, top_early])
	ok(GameLoot.grade_of(80) >= 0 and grade_late == GameLoot.grade_of(80), "and carry the world's grade (%d)" % grade_late)


func test_uniques() -> void:
	var d := _fresh(77, 10)
	var got := {}
	for i in 600:
		var id := GameWildsLoot.roll(d, "whisperwood", "lm:%d:13" % i, "lair", {"n": 0})
		if GameData.items.has(id):
			got[id] = true
	var allowed := ["whispering_bow", "heartwood_jerkin"]
	ok(got.size() > 0, "a lair gives themed uniques (%s)" % str(got.keys()))
	for id in got:
		ok(id in allowed, "and only Whisperwood's own: %s" % id)
	# min_gen holds an item back
	var young := _fresh(77, 1)
	var mid := _fresh(77, 10)
	var early_hits := {}
	var later_hits := {}
	for i in 800:
		var a := GameWildsLoot.roll(young, "frostreach", "lm:%d:17" % i, "lair", {"n": 0})
		var b := GameWildsLoot.roll(mid, "frostreach", "lm:%d:17" % i, "lair", {"n": 0})
		if GameData.items.has(a):
			early_hits[a] = true
		if GameData.items.has(b):
			later_hits[b] = true
	ok(not early_hits.has("rimeblade") and later_hits.has("rimeblade"), "Rimeblade is held back until generation 6")
	# an owned unique is not rolled again
	var owner := _fresh(77, 10)
	owner.heir.inventory.append("whispering_bow")
	var twice := 0
	for i in 600:
		if GameWildsLoot.roll(owner, "whisperwood", "lm:%d:13" % i, "lair", {"n": 0}) == "whispering_bow":
			twice += 1
	ok(twice == 0, "an unique the heir has is not given again")
	# every area's uniques come up
	for area in GameWilds.data()["areas"]:
		var seen := {}
		var h := _fresh(77, 40)
		for i in 700:
			var id := GameWildsLoot.roll(h, str(area), "lm:%d:19" % i, "lair", {"n": 0})
			if GameData.items.has(id):
				seen[id] = true
		var want: Array = GameWildsLoot.data()["areas"][area]["uniques"].map(func(u): return str(u["id"]))
		var all := true
		for w in want:
			all = all and seen.has(w)
		ok(all, "%s gives all its uniques over time (%s)" % [area, str(seen.keys())])


func test_give() -> void:
	var d := _fresh()
	var r := GameWildsLoot.give(d, "whispering_bow")
	ok("whispering_bow" in d.heir.inventory and r["name"] == "Whispering Bow", "a find goes in the pack: %s" % r["line"])
	var id := GameWildsLoot.roll(d, "mirefen", "lm:3:3", "ruin", {"n": 0})
	var before := d.heir.inventory.size()
	GameWildsLoot.give(d, id)
	ok(d.heir.inventory.size() == before + 1 or d.heir.gold > 0, "a made item goes in the pack (or is sold where it lies when too heavy)")
	d.heir.gold = 0
	d.heir.inventory.clear()
	var heavy := _fresh()
	heavy.heir.inventory.append("plate_armor")
	for i in 40:
		heavy.heir.inventory.append("plate_armor")
	var g0 := heavy.heir.gold
	GameWildsLoot.give(heavy, "plate_armor")
	ok(heavy.heir.gold > g0 or heavy.heir.inventory.size() == 42, "a load too heavy to carry is sold where it lies")
	# the autopilot meets nothing of it
	var life := _fresh(3)
	var bot_before := life.heir.inventory.size()
	ok(life.wilds.is_empty() and bot_before >= 0, "a new house has found and used nothing")
