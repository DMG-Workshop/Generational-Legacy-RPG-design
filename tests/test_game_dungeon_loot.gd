## The dungeons' loot tables and generator (data/items/dungeon_loot.json; GameDungeonLoot): a container's roll is a pure function of
## the seed, dungeon, container, tier and cycle (never the dynasty's dice), grows with the generation, is shaped by the dungeon's
## own table (slots, forms, material tags, tier, gold), every item is an ordinary item a merchant buys, the named uniques are found
## once each, and what a creature leaves uses the same generator.
## Run: godot --headless --path . -s res://tests/test_game_dungeon_loot.gd
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
	test_pure()
	test_valid_items()
	test_scaling()
	test_shape()
	test_uniques()
	test_give()
	test_drops()
	test_breaks()
	print("dungeon loot tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(gen: int = 1, seed_value: int = 7) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.gen = gen
	return d


func _all_items(gen: int, tier: String, n: int, dungeon: String = "deepstone_halls", kind: String = "chest") -> Array:
	var d := _dyn(gen)
	var out: Array = []
	for i in n:
		out.append_array(GameDungeonLoot.roll(d, dungeon, "hall#%d" % i, tier, kind, 1, 0)["items"])
	return out


func test_pure() -> void:
	var d := _dyn(20)
	var state := d.rng.state
	var a := GameDungeonLoot.roll(d, "hollow_barrow", "bone_vault#0", "rich")
	var b := GameDungeonLoot.roll(d, "hollow_barrow", "bone_vault#0", "rich")
	ok(a == b and a["gold"] > 0, "the same container rolls the same: %s" % str(a))
	ok(d.rng.state == state, "and draws no die of the dynasty's")
	ok(GameDungeonLoot.roll(d, "hollow_barrow", "bone_vault#1", "rich") != a, "another container differs")
	ok(GameDungeonLoot.roll(_dyn(20, 99), "hollow_barrow", "bone_vault#0", "rich") != a, "another seed differs")
	ok(GameDungeonLoot.roll(d, "hollow_barrow", "bone_vault#0", "rich", "chest", -1, 1) != GameDungeonLoot.roll(d, "hollow_barrow", "bone_vault#0", "rich", "chest", -1, 2), "the next refill gives other things")
	d.world.year += float(GameDungeons.setting("refill_years")) + 1.0
	ok(GameDungeonLoot.cycle_of(d) == 1 and GameDungeonLoot.roll(d, "hollow_barrow", "bone_vault#0", "rich") != a, "a refilled container gives new things (the cycle moves with the calendar)")
	ok(GameDungeonLoot.roll(d, "nowhere", "x#0", "rich")["gold"] == 0 and GameDungeonLoot.roll(d, "emberpeak", "x#0", "golden")["items"].is_empty(), "an unknown dungeon or tier gives nothing")
	ok(GameDungeonLoot.depth_of("hollow_barrow", "antechamber#0") == 0 and GameDungeonLoot.depth_of("hollow_barrow", "tomb#0") == 2, "the depth of a room is its doors from the entrance")


func test_valid_items() -> void:
	var d_by_gen := {}
	var bad := 0
	var total := 0
	var zero_price := 0
	for gen in [1, 20, 100, 400, 700]:
		var d := _dyn(gen)
		d_by_gen[gen] = d
		for p in GameDungeons.dungeon_ids():
			for tier in ["plain", "fine", "rich", "hoard"]:
				for i in 12:
					var r := GameDungeonLoot.roll(d, str(p), "room#%d" % i, tier, "chest", i % 4, 0)
					for id in r["items"]:
						total += 1
						if GameItems.item_def(str(id)).is_empty() or not GameLoot.is_generated(str(id)):
							bad += 1
						elif GameItems.sell_price(d, str(id)) < 1:
							zero_price += 1
					for m in r["materials"]:
						if not GameMaterials.has(str(m)) or int(r["materials"][m]) < 1:
							bad += 1
					if r["gold"] < 1:
						bad += 1
	ok(total > 1500 and bad == 0 and zero_price == 0, "%d items rolled, each one buildable and priced for a merchant (bad %d)" % [total, bad])


func test_scaling() -> void:
	var low := 0.0
	var high := 0.0
	var tier_low := 0.0
	var tier_high := 0.0
	var n_low := 0
	var n_high := 0
	var d1 := _dyn(1)
	var d2 := _dyn(100)
	for i in 80:
		low += float(GameDungeonLoot.roll(d1, "emberpeak", "gate#%d" % i, "fine", "chest", 0, 0)["gold"])
		high += float(GameDungeonLoot.roll(d2, "emberpeak", "gate#%d" % i, "fine", "chest", 0, 0)["gold"])
	ok(high > low * 2.0, "gold grows with the generation (%.0f then %.0f)" % [low / 80.0, high / 80.0])
	for id in _all_items(1, "rich", 80):
		tier_low += GameItems.item_def(str(id))["tier"]
		n_low += 1
	for id in _all_items(100, "rich", 80):
		tier_high += GameItems.item_def(str(id))["tier"]
		n_high += 1
	ok(n_low > 0 and n_high > 0 and tier_high / n_high > tier_low / n_low + 0.5, "better materials open with the generation (%.2f then %.2f)" % [tier_low / n_low, tier_high / n_high])
	var grades := 0
	for id in _all_items(400, "hoard", 40):
		grades = maxi(grades, int(GameLoot.parse(str(id))["grade"]))
	ok(grades > 0, "and grades after the top tier")
	var plain := 0.0
	var hoard := 0.0
	for i in 40:
		plain += float(GameDungeonLoot.roll(d2, "deepstone_halls", "x#%d" % i, "plain")["gold"])
		hoard += float(GameDungeonLoot.roll(d2, "deepstone_halls", "x#%d" % i, "hoard")["gold"])
	ok(hoard > plain * 4.0, "a hoard holds far more gold than a plain chest")
	var rarity_ok := true
	for id in _all_items(100, "hoard", 60):
		rarity_ok = rarity_ok and GameDungeonLoot._rarity_index(str(GameLoot.parse(str(id))["rarity"])) >= GameDungeonLoot._rarity_index("rare")
	ok(rarity_ok, "a hoard's items are rare or better")
	var deep := 0
	var shallow := 0
	for i in 200:
		for id in GameDungeonLoot.roll(d2, "the_rift", "x#%d" % i, "fine", "chest", 6, 0)["items"]:
			deep += GameDungeonLoot._rarity_index(str(GameLoot.parse(str(id))["rarity"]))
		for id in GameDungeonLoot.roll(d2, "the_rift", "x#%d" % i, "fine", "chest", 0, 0)["items"]:
			shallow += GameDungeonLoot._rarity_index(str(GameLoot.parse(str(id))["rarity"]))
	ok(deep > shallow, "deeper rooms give rarer things (%d against %d)" % [deep, shallow])


func test_shape() -> void:
	var slots := {}
	for id in _all_items(100, "fine", 200, "emberpeak", "rack"):
		slots[GameItems.slot_of(str(id))] = int(slots.get(GameItems.slot_of(str(id)), 0)) + 1
	ok(not slots.has("trinket") and slots.has("weapon") and slots.has("armor"), "a weapon rack holds weapons and armour, no trinkets: %s" % str(slots))
	var urn := {}
	for id in _all_items(100, "fine", 300, "hollow_barrow", "urn"):
		urn[GameItems.slot_of(str(id))] = int(urn.get(GameItems.slot_of(str(id)), 0)) + 1
	ok(int(urn.get("trinket", 0)) > int(urn.get("weapon", 0)) + int(urn.get("armor", 0)), "an urn holds mostly trinkets: %s" % str(urn))
	var magic := {}
	for p in ["goblin_warrens", "the_rift", "sunken_temple"]:
		var n := 0
		var tot := 0
		for id in _all_items(100, "fine", 300, p):
			tot += 1
			if GameItems.has_tag(str(id), "magic") or GameItems.has_tag(str(id), "gem"):
				n += 1
		magic[p] = float(n) / maxf(1.0, float(tot))
	ok(float(magic["the_rift"]) > float(magic["goblin_warrens"]) + 0.1 and float(magic["sunken_temple"]) > float(magic["goblin_warrens"]), "the rift and the temple hold magic and gems, the warrens do not: %s" % str(magic))
	var bone := 0
	var bone_rift := 0
	for id in _all_items(5, "fine", 300, "goblin_warrens"):
		bone += 1 if GameItems.has_tag(str(id), "bone") or GameItems.has_tag(str(id), "leather") else 0
	for id in _all_items(5, "fine", 300, "the_rift"):
		bone_rift += 1 if GameItems.has_tag(str(id), "bone") or GameItems.has_tag(str(id), "leather") else 0
	ok(bone > bone_rift, "the warrens hold bone and leather")
	var forms := {}
	for id in _all_items(60, "fine", 400, "deepstone_halls"):
		var f := str(GameLoot.parse(str(id))["form"])
		forms[f] = int(forms.get(f, 0)) + 1
	ok(int(forms.get("warhammer", 0)) > int(forms.get("bow", 0)) * 2, "the dwarf-halls favour hammers over bows: %s" % str(forms))
	var mats := {}
	for p in GameDungeons.dungeon_ids():
		var got := {}
		for i in 60:
			for m in GameDungeonLoot.roll(_dyn(400), str(p), "x#%d" % i, "rich")["materials"]:
				got[m] = true
		var keys: Array = got.keys()
		keys.sort()
		mats[str(keys)] = true
	ok(mats.size() >= 5, "each dungeon's rooms hold their own materials")


func test_uniques() -> void:
	var d := _dyn(100)
	var found := false
	var room := "tomb#0"
	var r := GameDungeonLoot.roll(d, "hollow_barrow", room, "hoard")
	ok("hollow_kings_crown_fragment" in r["uniques"], "the king's tomb holds his crown fragment")
	ok(GameDungeonLoot.roll(d, "hollow_barrow", "burial_hall#0", "hoard")["uniques"].is_empty(), "but no other room does")
	var lines := GameDungeonLoot.give(d, r)
	ok(GameDungeons.has_unique(d, "hollow_kings_crown_fragment") and "hollow_kings_crown_fragment" in d.heir.inventory, "it goes into the pack and is marked found: %s" % str(lines))
	ok(GameDungeonLoot.roll(d, "hollow_barrow", room, "hoard")["uniques"].is_empty() and GameDungeonLoot.give(d, r).size() < lines.size(), "and is found once only")
	var item := GameItems.item_def("hollow_kings_crown_fragment")
	ok(item["unique"] and GameItems.sell_price(d, "hollow_kings_crown_fragment") > 100, "it is a unique item a merchant buys")
	var every := 0
	for p in GameDungeons.dungeon_ids():
		for u in GameDungeonLoot.data()["dungeons"][p]["uniques"]:
			var def := GameItems.item_def(str(u["item"]))
			if not def.is_empty() and def["unique"] and not def["material"].is_empty() and def["weight"] > 0 and GameMaterials.has(def["material"]):
				every += 1
	ok(every >= 8, "eight named items, each with a listed material and a weight (%d)" % every)


func test_give() -> void:
	var d := _dyn(30)
	d.heir.gold = 0
	var before := d.heir.inventory.size()
	var got := {"gold": 120, "items": [GameDungeonLoot.roll(d, "deepstone_halls", "a#0", "hoard")["items"][0]], "materials": {"iron": 3}, "uniques": []}
	var lines := GameDungeonLoot.give(d, got)
	ok(d.heir.gold >= 120 and GameCraft.have(d, "iron") >= 3 and d.heir.inventory.size() + 0 >= before and lines.size() >= 3, "gold to the purse, materials to the stores, items to the pack: %s" % str(lines))
	ok(GameDungeonLoot.give(d, {}).is_empty(), "an empty roll gives nothing")
	# a merchant buys what was found
	var item: String = got["items"][0]
	var d2 := _dyn(30)
	d2.heir.inventory.append(item)
	d2.heir.gold = 0
	var line := GameItems.sell(d2, item)
	ok(d2.heir.gold == GameItems.sell_price(d2, item) and not (item in d2.heir.inventory), "the found item sells at a town's merchant: %s" % line)
	# a load too heavy is sold on the spot, not carried
	var heavy := _dyn(30)
	heavy.heir.gold = 0
	heavy.heir.inventory.append_array(["dragonscale_mail", "plate_armor", "chainmail"])
	var rolled := {"gold": 0, "items": ["gen:common:armor:plate:iron:-:-:0:0"], "materials": {}, "uniques": []}
	if GameCarry.can_carry(heavy.heir, "gen:common:armor:plate:iron:-:-:0:0"):
		heavy.heir.inventory.append_array(["gen:common:armor:plate:iron:-:-:0:0", "gen:common:armor:plate:iron:-:-:0:0", "gen:common:armor:plate:iron:-:-:0:0", "gen:common:armor:plate:iron:-:-:0:0"])
	if not GameCarry.can_carry(heavy.heir, "gen:common:armor:plate:iron:-:-:0:0"):
		var n := heavy.heir.inventory.size()
		GameDungeonLoot.give(heavy, rolled)
		ok(heavy.heir.inventory.size() == n and heavy.heir.gold > 0, "too heavy to carry: sold where it lies")
	else:
		ok(true, "(the heir could carry it all)")


func test_drops() -> void:
	var d := _dyn(100)
	var state := d.rng.state
	var hits := 0
	for i in 200:
		if not GameDungeonLoot.roll_drop(d, "deepstone_halls", "court#%d" % i, "ogre").is_empty():
			hits += 1
	ok(hits > 20 and hits < 120, "an ogre leaves something about a quarter of the time (%d of 200)" % hits)
	var boss := GameDungeonLoot.roll_drop(d, "deepstone_halls", "throne#boss", "stonefather", true)
	ok(not boss.is_empty() and "stonefathers_rune_maul" in boss["uniques"] and boss["gold"] > 0, "the lair's boss always leaves a hoard and its unique")
	ok(GameDungeonLoot.roll_drop(d, "nowhere", "a#0", "ogre").is_empty(), "nothing in an unknown dungeon")
	ok(d.rng.state == state, "and none of it draws a die of the dynasty's")
	ok(GameDungeonLoot.roll_drop(d, "deepstone_halls", "court#3", "ogre") == GameDungeonLoot.roll_drop(d, "deepstone_halls", "court#3", "ogre"), "the same creature leaves the same")


func test_breaks() -> void:
	var keep := GameDungeonLoot._cache
	var bad := GameDungeonLoot.data().duplicate(true)
	bad["tiers"]["rich"]["min_rarity"] = "godly"
	GameDungeonLoot._cache = bad
	ok(not GameDungeonLoot.validate().is_empty(), "break check: an unknown minimum rarity is refused")
	GameDungeonLoot._cache = keep
	var bad2 := GameDungeonLoot.data().duplicate(true)
	bad2["dungeons"]["emberpeak"]["uniques"][0]["item"] = "iron_sword"
	GameDungeonLoot._cache = bad2
	ok(not GameDungeonLoot.validate().is_empty(), "break check: a unique that is an ordinary sword is refused")
	GameDungeonLoot._cache = keep
	var bad3 := GameDungeonLoot.data().duplicate(true)
	bad3["dungeons"]["the_rift"]["material_tag_bias"]["sparkle"] = 2.0
	bad3["dungeons"]["goblin_warrens"]["form_bias"]["spoon"] = 2
	GameDungeonLoot._cache = bad3
	ok(GameDungeonLoot.validate().size() >= 2, "break check: an unknown material tag and an unknown form are refused")
	GameDungeonLoot._cache = keep
	var bad4 := GameDungeonLoot.data().duplicate(true)
	bad4["dungeons"].erase("sunken_temple")
	GameDungeonLoot._cache = bad4
	ok(not GameDungeonLoot.validate().is_empty(), "break check: a dungeon with no table is refused")
	GameDungeonLoot._cache = keep
	ok(GameDungeonLoot.validate().is_empty(), "(and the real data is whole again)")
