## Bags (core/game/game_bags.gd; data/items/bags.json and the `bag` blocks of items.json): the data and its validator;
## that a plain bag id in the pack becomes a bag of its own; putting things in and taking them out; slots; bags in bags
## without limit and what that does to weight and to the most the heir can carry; the magic bag (lightens, and goes in
## no other bag, but other bags go in it); that a bag is not sold or left behind with things in it; saving and loading
## (and an old save with no bags, and a damaged one); and that the autopilot never meets a bag.
## Run: godot --headless --path . -s res://tests/test_game_bags.gd
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
	test_naming()
	test_put_and_take()
	test_nesting()
	test_magic()
	test_weight_and_room()
	test_let_go()
	test_saving()
	test_autopilot()
	print("bag tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _heir() -> GameHeir:
	return GameDynasty.new_game(5, "Tess", "warrior", "faetouched", "human").heir


func _dyn() -> GameDynasty:
	var d := GameDynasty.new_game(5, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


func _unbox(h: GameHeir, id: String) -> String:
	h.inventory.append(id)
	GameBags.normalize(h)
	return str(h.inventory.back())


func test_data() -> void:
	ok(GameBags.validate().is_empty(), "the bag data is sound: %s" % str(GameBags.validate()))
	for id in ["pouch", "satchel", "travel_sack", "bag_of_holding"]:
		ok(GameBags.is_bag(id), "%s is a bag" % id)
	ok(not GameBags.is_bag("iron_sword") and not GameBags.is_bag("") and not GameBags.is_bag("no_such_thing"), "a sword, nothing and a made-up id are no bag")
	ok(GameBags.is_magic("bag_of_holding") and not GameBags.is_magic("satchel"), "only the Bag of Holding is magic")
	ok(GameBags.lighten("bag_of_holding") > 0.0 and GameBags.lighten("satchel") == 0.0, "only the magic bag lightens")
	for id in ["pouch", "satchel", "travel_sack", "bag_of_holding"]:
		ok(GameBags.slots(id) >= 1 and GameItems.weight_of(id) > 0.0, "%s has slots and a weight" % id)
	var kept: Dictionary = (GameData.items["pouch"]["bag"] as Dictionary).duplicate(true)
	GameData.items["pouch"]["bag"] = {"slots": 0, "carry": 1.0, "lighten": 0.0, "magic": false}
	ok(not GameBags.validate().is_empty(), "a bag with no slots is found")
	GameData.items["pouch"]["bag"] = {"slots": 3, "carry": 1.0, "lighten": 0.3, "magic": false}
	ok(not GameBags.validate().is_empty(), "a plain bag that lightens is found")
	GameData.items["pouch"]["bag"] = kept
	ok(GameBags.validate().is_empty(), "and the data is whole again after")


func test_naming() -> void:
	var h := _heir()
	ok(GameBags.base_id("satchel#3") == "satchel" and GameBags.base_id("satchel") == "satchel" and GameBags.is_instance("satchel#3"), "satchel#3 is a satchel")
	ok(GameItems.item_name("satchel#3") == "Leather Satchel" and GameItems.weight_of("satchel#3") == GameItems.weight_of("satchel"), "a numbered bag is its base item to everything that reads items")
	var a := _unbox(h, "satchel")
	var b := _unbox(h, "satchel")
	var c := _unbox(h, "pouch")
	ok(a == "satchel#1" and b == "satchel#2" and c == "pouch#3", "each plain bag becomes a bag of its own: %s %s %s" % [a, b, c])
	GameBags.normalize(h)
	ok(h.inventory.count("satchel#1") == 1 and h.inventory.count("satchel#2") == 1, "normalising again changes nothing")
	var plain := _heir()
	plain.inventory.append("iron_sword")
	GameBags.normalize(plain)
	ok(plain.inventory == ["iron_sword"] or plain.inventory.has("iron_sword"), "an ordinary item is left alone")


func test_put_and_take() -> void:
	var h := _heir()
	h.inventory = ["iron_sword"]
	var bag := _unbox(h, "pouch")
	var r := GameBags.put(h, "iron_sword", bag)
	ok(r["ok"] and GameBags.contents(h, bag) == ["iron_sword"] and "iron_sword" not in h.inventory, "a thing goes into a bag, out of the pack: %s" % r["text"])
	ok(GameBags.where(h, "iron_sword") == bag and GameBags.where(h, bag) == "" and GameBags.where(h, "nothing") == null, "where says where things are")
	var t := GameBags.take(h, "iron_sword")
	ok(t["ok"] and "iron_sword" in h.inventory and GameBags.contents(h, bag).is_empty() and not h.bags.has(bag), "and comes out again into the pack: %s" % t["text"])
	ok(not GameBags.take(h, "iron_sword")["ok"], "a thing already loose cannot be taken out")
	ok(not GameBags.put(h, "no_such_thing", bag)["ok"], "a thing the heir does not carry cannot be put in")
	ok(not GameBags.put(h, "iron_sword", "nope#9")["ok"] and not GameBags.put(h, "iron_sword", "iron_sword")["ok"], "nor into a bag they do not have, nor into a sword")
	# slots
	var small := bag
	var cap := GameBags.slots(small)
	for i in cap:
		h.inventory.append("iron_sword")
	var filled := 0
	for i in cap + 2:
		var item := str(h.inventory[h.inventory.size() - 1 - (i % maxi(1, cap))]) if false else ""
	for i in cap + 3:
		if GameBags.put(h, "iron_sword", small)["ok"]:
			filled += 1
	ok(filled == cap and GameBags.free_slots(h, small) == 0, "a bag takes only as many as it has slots (%d of %d)" % [filled, cap])
	h.inventory.append("iron_sword")
	var full := GameBags.put(h, "iron_sword", small)
	ok(not full["ok"] and "full" in str(full["text"]), "a full bag says so: %s" % full["text"])


func test_nesting() -> void:
	var h := _heir()
	h.inventory = []
	var chain: Array = []
	for i in 8:   # eight bags, each in the one before: nothing limits how deep
		chain.append(_unbox(h, "satchel"))
	for i in range(chain.size() - 1, 0, -1):
		ok(GameBags.put(h, chain[i], chain[i - 1])["ok"], "bag %d goes into bag %d" % [i + 1, i])
	ok(h.inventory == [chain[0]] and GameBags.inside(h, chain[0]).size() == 7, "eight bags deep, with one in the pack")
	ok(GameBags.reachable(h, chain[7]) and GameBags.all_bags(h).size() == 8, "the deepest bag is reachable, and all eight count")
	h.inventory.append("iron_sword")
	ok(GameBags.put(h, "iron_sword", chain[7])["ok"] and GameBags.where(h, "iron_sword") == chain[7], "a sword goes into the deepest bag")
	ok(not GameBags.put(h, chain[0], chain[0])["ok"], "a bag does not go inside itself")
	ok(not GameBags.put(h, chain[0], chain[7])["ok"] and not GameBags.put(h, chain[1], chain[5])["ok"], "nor inside what it holds, however deep")
	var r := GameBags.put(h, chain[3], chain[7])
	ok(not r["ok"], "a bag cannot go inside its own descendant: %s" % r["text"])
	# a bag moved from one bag into another carries what is in it
	var other := _unbox(h, "pouch")
	ok(GameBags.put(h, chain[4], other)["ok"] and GameBags.inside(h, other).size() == 4 and GameBags.where(h, "iron_sword") == chain[7], "moving a bag takes what it holds with it")
	ok(GameBags.take(h, "iron_sword")["ok"] and "iron_sword" in h.inventory, "and things come out from any depth")


func test_magic() -> void:
	var h := _heir()
	h.inventory = []
	var holding := _unbox(h, "bag_of_holding")
	var sack := _unbox(h, "travel_sack")
	var r := GameBags.put(h, holding, sack)
	ok(not r["ok"] and "magic" in str(r["text"]), "a magic bag goes in no other bag: %s" % r["text"])
	ok(GameBags.put(h, sack, holding)["ok"] and GameBags.where(h, sack) == holding, "but other bags go in it")
	var pouch := _unbox(h, "pouch")
	ok(GameBags.put(h, pouch, sack)["ok"] and GameBags.reachable(h, pouch), "and bags go in those, as deep as you like")
	ok(not GameBags.put(h, holding, pouch)["ok"], "the magic bag still goes in none of them")


func test_weight_and_room() -> void:
	var h := _heir()
	h.inventory = []
	var base_cap := GameCarry.capacity(h)
	var base_w := GameCarry.carried(h)
	var sack := _unbox(h, "satchel")
	ok(is_equal_approx(GameCarry.carried(h), base_w + GameItems.weight_of("satchel")), "an empty bag weighs its own weight")
	ok(is_equal_approx(GameCarry.capacity(h), base_cap + float(GameBags.def("satchel")["carry"])), "and adds its carry bonus to the most the heir can carry")
	h.inventory.append("iron_sword")
	var with_sword := GameCarry.carried(h)
	GameBags.put(h, "iron_sword", sack)
	ok(is_equal_approx(GameCarry.carried(h), with_sword), "a plain bag changes nothing about the weight of what is in it")
	var inner := _unbox(h, "pouch")
	GameBags.put(h, inner, sack)
	ok(is_equal_approx(GameCarry.capacity(h), base_cap + float(GameBags.def("satchel")["carry"]) + float(GameBags.def("pouch")["carry"])), "a bag in a bag adds its bonus too")
	ok(is_equal_approx(GameCarry.carried(h), base_w + GameItems.weight_of("satchel") + GameItems.weight_of("pouch") + GameItems.weight_of("iron_sword")), "weight counts every bag and everything in them")
	# the magic bag lightens
	var holding := _unbox(h, "bag_of_holding")
	var before := GameCarry.carried(h)
	GameBags.put(h, sack, holding)
	var lightened := (GameItems.weight_of("satchel") + GameItems.weight_of("pouch") + GameItems.weight_of("iron_sword")) * GameBags.lighten("bag_of_holding")
	ok(is_equal_approx(GameCarry.carried(h), before - lightened), "what is in a magic bag weighs less (%.2f lighter)" % lightened)
	ok(GameCarry.room(h) > 0.0 and not GameCarry.burdened(h), "and the heir is not burdened")
	# room: the bags let the heir carry more than they could
	var plain := _heir()
	plain.inventory = []
	var heavy := "iron_sword"
	var carried_plain := 0
	while GameCarry.can_carry(plain, heavy) and carried_plain < 100:
		plain.inventory.append(heavy)
		carried_plain += 1
	var packed := _heir()
	packed.inventory = []
	for i in 3:
		_unbox(packed, "satchel")
	var carried_packed := 0
	while GameCarry.can_carry(packed, heavy) and carried_packed < 100:
		packed.inventory.append(heavy)
		carried_packed += 1
	ok(carried_packed > carried_plain, "a heir with bags can carry more swords (%d against %d)" % [carried_packed, carried_plain])


func test_let_go() -> void:
	var d := _dyn()
	var h := d.heir
	h.inventory = []
	var bag := _unbox(h, "pouch")
	h.inventory.append("iron_sword")
	GameBags.put(h, "iron_sword", bag)
	ok("empty it first" in GameCarry.drop(d, bag) and bag in h.inventory, "a bag with something in it is not left behind: %s" % GameCarry.drop(d, bag))
	d.world.visit("hearthmere")
	var line := GameItems.sell(d, bag)
	ok(bag in h.inventory and GameBags.contents(h, bag) == ["iron_sword"], "nor sold: %s" % line)
	GameBags.take(h, "iron_sword")
	ok("leaves the" in GameCarry.drop(d, bag) and bag not in h.inventory, "an empty bag may be left behind")


func test_saving() -> void:
	var h := _heir()
	h.inventory = ["iron_sword"]
	var a := _unbox(h, "satchel")
	var b := _unbox(h, "pouch")
	var holding := _unbox(h, "bag_of_holding")
	GameBags.put(h, "iron_sword", b)
	GameBags.put(h, b, a)
	GameBags.put(h, a, holding)
	var saved := h.to_dict()
	ok(saved.has("bags") and (saved["bags"] as Dictionary).size() == 3, "a heir with things in bags saves them")
	var back := GameHeir.from_dict(JSON.parse_string(JSON.stringify(saved)))
	ok(back.inventory == h.inventory and back.bags == h.bags, "and loads the same, through text: %s" % str(back.bags))
	ok(GameBags.where(back, "iron_sword") == b and GameBags.reachable(back, b), "with everything where it was")
	ok(is_equal_approx(GameCarry.carried(back), GameCarry.carried(h)) and is_equal_approx(GameCarry.capacity(back), GameCarry.capacity(h)), "and the same weight and room")
	var plain := _heir().to_dict()
	ok(not plain.has("bags"), "a heir with no bag saves no bags key")
	var old := GameHeir.from_dict(JSON.parse_string(JSON.stringify(plain)))
	ok(old.bags.is_empty(), "an old save with no bags loads with none")
	# damaged saves
	var bad := saved.duplicate(true)
	bad["bags"] = "not a dictionary"
	ok(GameHeir.from_dict(JSON.parse_string(JSON.stringify(bad))).bags.is_empty(), "a damaged bags value is dropped")
	bad = saved.duplicate(true)
	bad["bags"] = {b: ["iron_sword", "iron_sword", "no_such_thing", 7], "ghost#40": ["iron_sword"], holding: [a, "satchel"], a: [b, holding]}
	var cleaned := GameHeir.from_dict(JSON.parse_string(JSON.stringify(bad)))
	ok(GameBags.contents(cleaned, b) == ["iron_sword"], "a thing is kept once, and unknown or odd things are dropped: %s" % str(cleaned.bags.get(b)))
	ok(not cleaned.bags.has("ghost#40"), "contents of a bag that does not exist are dropped")
	ok(GameBags.contents(cleaned, holding) == [a] and GameBags.contents(cleaned, a) == [b], "a plain bag id, and a bag put inside what holds it, are dropped: %s" % str(cleaned.bags))
	var magic_inside := saved.duplicate(true)
	magic_inside["bags"] = {a: [holding]}
	var m := GameHeir.from_dict(JSON.parse_string(JSON.stringify(magic_inside)))
	ok(GameBags.contents(m, a).is_empty(), "a magic bag found inside another bag in a save is taken out of it")
	var over := saved.duplicate(true)
	var many: Array = []
	for i in 12:
		many.append("iron_sword")
	over["bags"] = {b: many}
	ok(GameBags.contents(GameHeir.from_dict(JSON.parse_string(JSON.stringify(over))), b).size() <= GameBags.slots(b), "a bag in a save holds no more than its slots")


func test_autopilot() -> void:
	var classes := GameData.starting_ids(GameData.classes)
	var met := 0
	var steps_run := 0
	for sd in 3:
		var d := GameDynasty.new_game(sd + 1, "", classes[sd % classes.size()], "faetouched", "human")
		for g in 3:
			var steps := 0
			while d.state == "life" and steps < 4000:
				GameBot.step(d)
				steps += 1
				steps_run += 1
			for id in d.heir.inventory:
				if GameBags.is_bag(str(id)):
					met += 1
			if d.state != "succession":
				break
			GameBot.choose_best(d)
		ok(d.heir.bags.is_empty(), "the autopilot's heir holds nothing in bags")
	ok(steps_run > 500 and met == 0, "the autopilot never meets a bag (%d steps)" % steps_run)
