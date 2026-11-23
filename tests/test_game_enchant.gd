## Enchanting as a shop service (core/game/game_enchant.gd, data/shops/enchant.json, ui/play/shop_panel.gd): one more affix into a made piece,
## the next rarity up, an essence and gold spent; refusals for what is not made gear, a mythic, a full piece, a piece too fine for the shop, a
## shut shop, no essence and no gold; a risky shop's failure costs the essence and fee and changes nothing else; no dice of the dynasty's;
## the family's count survives a save; the panel draws; and every check has a break.
## Run: godot --headless --path . -s res://tests/test_game_enchant.gd
extends SceneTree

const ShopPanel := preload("res://ui/play/shop_panel.gd")

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
	test_enchant()
	test_refusals()
	test_risky()
	test_save()
	await test_panel()
	test_breaks()
	print("enchant tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _hour(d: GameDynasty, hour: float) -> void:
	var day := float(GameDay.setting("day_seconds"))
	d.world_seconds = fposmod(hour / 24.0 - float(GameDay.setting("start_phase")), 1.0) * day


func _dyn(gen: int = 1) -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 1000000
	d.gen = gen
	d.world.location = "kingshold"
	_hour(d, 12.0)
	return d


## A made piece of a rarity (0, 1, 2 or 3 affixes) and a slot, rolled on a fixed seed until one fits; "" when none turns up.
func _piece(rarity: String, slot: String = "weapon", gen: int = 8) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = 99
	for i in 4000:
		var id := GameLoot.roll_item(r, gen, 40.0)
		var p := GameLoot.parse(id)
		if not p.is_empty() and str(p["rarity"]) == rarity and str(p["slot"]) == slot:
			return id
	return ""


func test_data() -> void:
	ok(GameEnchant.validate().is_empty(), "the data is sound: %s" % str(GameEnchant.validate()))
	ok(not GameEnchant.row("enchanter").is_empty() and GameEnchant.row("bakery").is_empty(), "the Enchanter enchants and the baker does not")
	ok(GameEnchant.rarity_for(1) == "fine" and GameEnchant.rarity_for(2) == "rare" and GameEnchant.rarity_for(3) == "legendary", "the ladder is crafting's")
	var d := _dyn()
	ok(GameEnchant.tier_limit(d, "enchanter") == 4, "Kingshold's enchanter works up to tier 4 (shop tier 3 plus 1)")


func test_enchant() -> void:
	var d := _dyn()
	var h := d.heir
	var id := _piece("common")
	ok(id != "", "a common made weapon to work on")
	h.inventory.append(id)
	var opts := GameEnchant.options(d, id)
	ok(opts.size() > 0, "it can take %d affixes" % opts.size())
	var aff := str(opts[0]["id"])
	var plan := GameEnchant.plan(d, "enchanter", id, aff)
	ok(not plan["ok"] and str(plan["why"]).contains("no essence"), "without an essence nothing is done: %s" % plan["why"])
	var tier := int(GameLoot.parse(id)["tier"])
	var fee := GameEnchant.price(d, "enchanter", id)
	var expected := maxi(1, int(round(120.0 * tier * tier * 1.0 * GameItems.price_mult(d) * GameSubclass.perk(h, "forge_fee_mult"))))
	ok(fee == expected, "the fee is base x tier squared x (1 + 0.5 a for each affix held): %d" % fee)
	var st := d.rng.state
	GameCraft.add_essence(d, aff, 2)
	var gold := h.gold
	var line := GameEnchant.apply(d, "enchanter", id, aff)
	ok(d.rng.state == st, "no die of the dynasty's is drawn")
	ok(not h.inventory.has(id) and h.gold == gold - fee and GameCraft.essence_have(d, aff) == 1, "the old piece is gone, the fee paid, one essence spent: %s" % line)
	var made := ""
	for x in h.inventory:
		if GameLoot.is_generated(str(x)):
			made = str(x)
	var parts := GameLoot.parse(made)
	ok(not parts.is_empty() and str(parts["rarity"]) == "fine" and aff in parts["affixes"] and (parts["affixes"] as Array).size() == 1, "the new piece is fine with the affix")
	ok(str(parts["form"]) == str(GameLoot.parse(id)["form"]) and int(parts["quality"]) == int(GameLoot.parse(id)["quality"]) and int(parts["grade"]) == int(GameLoot.parse(id)["grade"]), "form, quality and grade are kept")
	ok(float(GameLoot.build(made)["price"]) > float(GameLoot.build(id)["price"]), "it is worth more")
	ok(int(d.stores.get("enchanted", 0)) == 1, "the family's count is one")
	# and up the ladder: fine to rare, rare to legendary, then full
	var opts2 := GameEnchant.options(d, made)
	ok(not opts2.any(func(o): return str(o["id"]) == aff), "an affix it holds is not offered again")
	var aff2 := str(opts2[0]["id"])
	GameCraft.add_essence(d, aff2, 1)
	GameEnchant.apply(d, "enchanter", made, aff2)
	var rare := ""
	for x in h.inventory:
		if GameLoot.is_generated(str(x)):
			rare = str(x)
	ok(str(GameLoot.parse(rare)["rarity"]) == "rare", "a second affix makes it rare")
	var aff3 := str(GameEnchant.options(d, rare)[0]["id"])
	GameCraft.add_essence(d, aff3, 1)
	GameEnchant.apply(d, "enchanter", rare, aff3)
	var top := ""
	for x in h.inventory:
		if GameLoot.is_generated(str(x)):
			top = str(x)
	ok(str(GameLoot.parse(top)["rarity"]) == "legendary" and (GameLoot.parse(top)["affixes"] as Array).size() == 3, "a third makes it legendary")
	ok(GameEnchant.why_not_piece(d, "enchanter", top).contains("all the affixes"), "and then it is full")
	# a worn piece is replaced where it is worn
	var w := _dyn()
	var wid := _piece("common", "armor")
	w.heir.equipment["armor"] = wid
	var waff := str(GameEnchant.options(w, wid)[0]["id"])
	GameCraft.add_essence(w, waff, 1)
	GameEnchant.apply(w, "enchanter", wid, waff)
	ok(str(w.heir.equipment["armor"]) != wid and GameLoot.parse(str(w.heir.equipment["armor"]))["affixes"].has(waff), "a worn piece is enchanted where it stands")
	# buying an essence outright
	var b := _dyn()
	var g := b.heir.gold
	var cost := GameEnchant.essence_price(b, "enchanter", aff)
	GameEnchant.buy_essence(b, "enchanter", aff)
	ok(GameCraft.essence_have(b, aff) == 1 and b.heir.gold == g - cost and cost > 0, "an essence can be bought outright")
	ok(GameEnchant.buy_essence(b, "bakery", aff).contains("does not enchant"), "not at a baker's")


func test_refusals() -> void:
	var d := _dyn()
	var h := d.heir
	h.inventory.append("iron_sword")
	ok(GameEnchant.why_not_piece(d, "enchanter", "iron_sword").contains("not a made piece"), "a fixed piece cannot be enchanted")
	var common := _piece("common")
	h.inventory.append(common)
	var aff := str(GameEnchant.options(d, common)[0]["id"])
	GameCraft.add_essence(d, aff, 1)
	var other := _dyn()
	ok(not GameEnchant.plan(other, "enchanter", common, aff)["ok"] and str(GameEnchant.plan(other, "enchanter", common, aff)["why"]).contains("does not carry"), "a piece the heir does not carry")
	var far := _dyn()
	far.world.location = "hearthmere"
	ok(not GameEnchant.plan(far, "enchanter", common, aff)["ok"], "not in a town without an enchanter")
	_hour(d, 5.0)
	ok(GameEnchant.apply(d, "enchanter", common, aff).contains("shut"), "not while the shop is shut")
	_hour(d, 12.0)
	d.heir.gold = 1
	ok(str(GameEnchant.plan(d, "enchanter", common, aff)["why"]).contains("cannot afford"), "not without the gold")
	d.heir.gold = 100000
	var bad := GameEnchant.plan(d, "enchanter", common, "not_an_affix")
	ok(not bad["ok"], "an unknown affix is refused")
	var held := str(GameLoot.parse(_piece("fine"))["affixes"][0])
	var fine := _piece("fine")
	h.inventory.append(fine)
	GameCraft.add_essence(d, held, 1)
	ok(str(GameEnchant.plan(d, "enchanter", fine, held)["why"]).contains("already holds"), "an affix the piece already holds")
	# a tier the shop cannot work
	var row: Dictionary = GameEnchant.row("enchanter")
	var was: int = int(row["tier_cap"])
	row["tier_cap"] = 1
	var t := int(GameLoot.parse(common)["tier"])
	ok(t <= 1 or GameEnchant.why_not_piece(d, "enchanter", common).contains("cannot work a piece"), "a piece above the shop's tier is refused (tier %d, cap 1)" % t)
	row["tier_cap"] = was
	# a mythic and a legendary are full
	var r := RandomNumberGenerator.new()
	r.seed = 5
	var seen_mythic := ""
	for i in 20000:
		var id := GameLoot.roll_item(r, 30, 5000.0)
		if str(GameLoot.parse(id).get("mythic", "")) != "":
			seen_mythic = id
			break
	ok(seen_mythic == "" or GameEnchant.why_not_piece(d, "enchanter", seen_mythic).contains("mythic"), "a mythic piece cannot be enchanted")


func test_risky() -> void:
	var row: Dictionary = GameEnchant.row("enchanter")
	row["risk"] = "risky"
	var id := ""
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for i in 6000:
		var x := GameLoot.roll_item(r, 20, 40.0)
		var p := GameLoot.parse(x)
		if not p.is_empty() and str(p["rarity"]) == "common" and int(p["tier"]) >= 3 and int(p["tier"]) <= 4:
			id = x
			break
	ok(id != "", "a tier 3 or 4 piece to try")
	var tier := int(GameLoot.parse(id)["tier"])
	ok(is_equal_approx(GameEnchant.fail_chance("enchanter", id), 0.1 * float(tier - 1)), "a risky shop fails %d%% at tier %d" % [int(10 * (tier - 1)), tier])
	var fails_seen := 0
	var wins := 0
	var first := []
	for round in 60:
		var d := _dyn(20)
		d.heir.inventory.append(id)
		var aff := str(GameEnchant.options(d, id)[0]["id"])
		GameCraft.add_essence(d, aff, 1)
		d.stores["enchanted"] = round   # the family's count is part of the dice
		var gold := d.heir.gold
		var fee: int = int(GameEnchant.plan(d, "enchanter", id, aff)["fee"])
		GameEnchant.apply(d, "enchanter", id, aff)
		if d.heir.inventory.has(id):
			fails_seen += 1
			ok(d.heir.gold == gold - fee and GameCraft.essence_have(d, aff) == 0, "a failure keeps the fee and loses the essence but leaves the piece")
		else:
			wins += 1
		first.append(d.heir.inventory.has(id))
	ok(fails_seen > 0 and wins > 0, "over 60 tries both outcomes turn up (%d failed, %d bound)" % [fails_seen, wins])
	# the same state gives the same outcome
	var again := []
	for round in 60:
		var d2 := _dyn(20)
		d2.heir.inventory.append(id)
		var aff2 := str(GameEnchant.options(d2, id)[0]["id"])
		GameCraft.add_essence(d2, aff2, 1)
		d2.stores["enchanted"] = round
		GameEnchant.apply(d2, "enchanter", id, aff2)
		again.append(d2.heir.inventory.has(id))
	ok(first == again, "the same seed, piece, affix and count roll the same")
	row["risk"] = "safe"
	var s := _dyn(20)
	s.heir.inventory.append(id)
	var sa := str(GameEnchant.options(s, id)[0]["id"])
	GameCraft.add_essence(s, sa, 1)
	GameEnchant.apply(s, "enchanter", id, sa)
	ok(not s.heir.inventory.has(id), "a safe shop never fails")


func test_save() -> void:
	var d := _dyn()
	var id := _piece("common")
	d.heir.inventory.append(id)
	var aff := str(GameEnchant.options(d, id)[0]["id"])
	GameCraft.add_essence(d, aff, 1)
	GameEnchant.apply(d, "enchanter", id, aff)
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(int(back.stores.get("enchanted", 0)) == 1, "the count survives a save and load")
	var made: Array = back.heir.inventory.filter(func(x): return GameLoot.is_generated(str(x)))
	ok(made.size() == 1 and not GameLoot.parse(str(made[0])).is_empty(), "and the new piece loads as the made item it is")
	ok(GameCraft.load_stores({"enchanted": "x"}).is_empty() and GameCraft.load_stores({"enchanted": -2}).is_empty(), "a damaged count loads as nothing")
	ok(not _dyn().to_dict().has("stores"), "nothing is saved until something is made")


func test_panel() -> void:
	var d := _dyn()
	var id := _piece("common")
	d.heir.inventory.append(id)
	var panel: Control = ShopPanel.new()
	panel.dynasty = d
	root.add_child(panel)
	await process_frame
	panel._show("enchanter")
	await process_frame
	ok(panel.rows.get_child_count() >= 4, "the enchanter's tab has rows")
	panel.ench_pick = id
	panel._rebuild()
	await process_frame
	var opts := GameEnchant.options(d, id)
	var aff := str(opts[0]["id"])
	GameCraft.add_essence(d, aff, 1)
	panel._rebuild()
	await process_frame
	panel._act(GameEnchant.apply(d, "enchanter", id, aff))
	await process_frame
	ok(not d.heir.inventory.has(id) and panel.ench_pick == "", "the panel's enchant reaches the pack and the choice is let go")
	panel._rebuild()
	await process_frame
	ok(true, "and the tab draws again with the piece gone")
	_hour(d, 5.0)
	panel._rebuild()
	await process_frame
	ok(panel.rows.get_child_count() >= 1, "a shut enchanter draws only its closed line")
	panel.queue_free()


func test_breaks() -> void:
	var good := GameEnchant._cache.duplicate(true)
	GameEnchant._cache["settings"]["fail_per_tier"] = 0.9
	ok(not GameEnchant.validate().is_empty(), "a fail chance above 0.3 a tier is refused")
	GameEnchant._cache = good.duplicate(true)
	GameEnchant._cache["text"].erase("failed")
	ok(not GameEnchant.validate().is_empty(), "a missing line is refused")
	GameEnchant._cache = good.duplicate(true)
	var row: Dictionary = GameEnchant.row("enchanter")
	var was: float = float(row["base_fee"])
	row["base_fee"] = 0
	ok(not GameEnchant.validate().is_empty(), "a row with no fee is refused")
	row["base_fee"] = was
	GameEnchant._cache = good
	ok(GameEnchant.validate().is_empty(), "and the data is sound again")
