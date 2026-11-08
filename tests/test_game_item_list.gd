## The one item and material list (roadmap item 42): data/items/materials.json and the material, weight and tags every
## item in items.json carries. Checks the data and 10 ways to break it, that every item reaches a real material, the
## tags an item gets (its material's plus its slot or kind), and that the list changes nothing the game plays: prices,
## effects and stacks are as they were.
## Run: godot --headless --path . -s res://tests/test_game_item_list.gd
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
	test_items()
	test_tags()
	test_queries()
	print("item list tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func test_data() -> void:
	ok(GameMaterials.validate().is_empty(), "the material list and the items are sound: %s" % str(GameMaterials.validate()))
	ok(GameMaterials.ids().size() >= 20, "there are materials (%d)" % GameMaterials.ids().size())
	var tiers := {}
	for id in GameMaterials.ids():
		tiers[GameMaterials.tier_of(str(id))] = true
	ok(tiers.has(1) and tiers.has(2) and tiers.has(3) and tiers.has(4), "the materials span tiers 1 to 4")
	ok(GameMaterials.name_of("mithril") == "Mithril" and GameMaterials.tier_of("mithril") == 3, "mithril is a tier 3 metal")
	ok("metal" in GameMaterials.tags_of("iron") and GameMaterials.has("iron") and not GameMaterials.has("unobtainium"), "iron is a metal; unobtainium is not listed")
	ok(GameMaterials.of_tier(4).has("starmetal") and GameMaterials.with_tag("cloth").has("silk"), "a tier or a tag finds its materials")
	ok(GameMaterials.tier_of("unobtainium") == 0 and GameMaterials.tags_of("unobtainium").is_empty(), "an unknown material has no tier or tags")


## Breaks the data in memory, asks the validator, and puts it back.
func _with_items(change: Callable, check: Callable) -> void:
	var saved := GameData.items.duplicate(true)
	change.call()
	check.call()
	GameData.items = saved


func test_breaks() -> void:
	_with_items(func(): GameData.items["iron_sword"]["material"] = "unobtainium",
		func(): ok(not GameMaterials.validate().is_empty(), "an item naming a material that is not listed is found"))
	_with_items(func(): GameData.items["iron_sword"].erase("material"),
		func(): ok(not GameMaterials.validate().is_empty(), "an item with no material is found"))
	_with_items(func(): GameData.items["iron_sword"]["weight"] = 0.0,
		func(): ok(not GameMaterials.validate().is_empty(), "an item that weighs nothing is found"))
	_with_items(func(): GameData.items["iron_sword"].erase("weight"),
		func(): ok(not GameMaterials.validate().is_empty(), "an item with no weight is found"))
	_with_items(func(): GameData.items["iron_sword"]["tier"] = 0,
		func(): ok(not GameMaterials.validate().is_empty(), "an item of tier 0 is found"))
	_with_items(func(): GameData.items["iron_sword"]["stack"] = 5,
		func(): ok(not GameMaterials.validate().is_empty(), "gear that stacks is found"))
	_with_items(func(): GameData.items["willowbark_tonic"]["stack"] = 0,
		func(): ok(not GameMaterials.validate().is_empty(), "a consumable that cannot stack is found"))
	_with_items(func(): GameData.items["iron_sword"]["material"] = "glass",
		func(): ok(GameMaterials.validate().is_empty(), "a different listed material is fine (control)"))
	# a material left unused is found: point every item that used oak at iron
	_with_items(func():
		for id in GameData.items:
			if GameData.items[id]["material"] == "oak":
				GameData.items[id]["material"] = "iron",
		func(): ok(not GameMaterials.validate().is_empty(), "a material no item uses is found"))
	ok(GameMaterials.validate().is_empty(), "and the data is put back")


func test_items() -> void:
	var n := 0
	for id in GameData.items:
		n += 1
		var m := GameItems.material_of(str(id))
		ok(GameMaterials.has(m) and GameItems.weight_of(str(id)) > 0.0, "%s has a listed material and a weight" % id)
	ok(n == 53, "the 53 items are all still there (%d)" % n)
	ok(GameItems.material_of("iron_sword") == "iron" and GameItems.material_of("mithril_blade") == "mithril", "swords are made of their metal")
	ok(GameItems.material_of("dragonscale_mail") == "dragonscale", "the dragonscale mail is dragonscale")
	ok(GameItems.weight_of("plate_armor") > GameItems.weight_of("leather_armor") and GameItems.weight_of("leather_armor") > GameItems.weight_of("copper_ring"), "plate is heavier than leather, which is heavier than a ring")
	ok(GameItems.material_of("nothing_here") == "" and GameItems.weight_of("nothing_here") == 0.0, "an unknown item has no material and no weight")
	# nothing the game plays moved
	ok(GameItems.item_def("iron_sword")["price"] == 50 and GameItems.stack_max("willowbark_tonic") == 5 and GameItems.slot_of("iron_sword") == "weapon", "prices, stacks and slots are as they were")


func test_tags() -> void:
	var t := GameItems.tags_of("iron_sword")
	ok("metal" in t and "weapon" in t and "heavy" in t, "an iron sword is a heavy metal weapon: %s" % str(t))
	ok(GameItems.has_tag("willowbark_tonic", "herb") and GameItems.has_tag("willowbark_tonic", "remedy"), "a tonic is an herb remedy")
	ok(GameItems.has_tag("phoenix_feather", "holy") and GameItems.has_tag("phoenix_feather", "trinket"), "the phoenix feather is a holy trinket")
	ok(not GameItems.has_tag("iron_sword", "cloth") and GameItems.tags_of("nothing_here").is_empty(), "tags are not invented")
	var seen := {}
	for t2 in t:
		ok(not seen.has(t2), "a tag is listed once: %s" % t2)
		seen[t2] = true


func test_queries() -> void:
	var weapons := 0
	var metal := 0
	for id in GameData.items:
		if GameItems.has_tag(str(id), "weapon"):
			weapons += 1
		if GameItems.has_tag(str(id), "metal") and GameItems.has_tag(str(id), "weapon"):
			metal += 1
	ok(weapons == 17, "17 weapons are found by tag (%d)" % weapons)
	ok(metal > 0 and metal < weapons, "some but not all weapons are metal (%d of %d)" % [metal, weapons])
