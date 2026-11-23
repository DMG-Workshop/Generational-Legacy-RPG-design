## The wilds' merchant (core/game/game_wilds_trade.gd, ui/play/merchant_panel.gd, the `merchant` blocks of data/world/wilds.json): wares generated from
## the landmark's pool and the renewal period (the same while it stays, new when it renews), bought one at a time and gone until it renews; selling what
## the trader wants from the pack and the stores; barter; every refusal; no dice of the dynasty's; the marks save and load clean and do not clash with a
## town shelf's; the panel draws and its buttons reach the dynasty; Use opens it; and a break of each rule.
## Run: godot --headless --path . -s res://tests/test_game_wilds_trade.gd
extends SceneTree

const MerchantPanel := preload("res://ui/play/merchant_panel.gd")

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
	test_wares()
	test_buy()
	test_sell()
	test_barter()
	test_marks()
	test_use()
	await test_panel()
	test_breaks()
	print("wilds trade tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(seed_value: int = 7, gen: int = 1) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 100000
	d.gen = gen
	return d


## A landmark of a kind in an area, found by looking at the area's cells ({} when there is none on this seed).
func _lm(d: GameDynasty, area: String, kind: String) -> Dictionary:
	var a := GameWorldGen.anchor(area)
	for r in range(0, 90, 6):
		for ang in 16:
			var x := int(a["x"]) + int(round(cos(float(ang) / 16.0 * TAU) * r))
			var z := int(a["z"]) + int(round(sin(float(ang) / 16.0 * TAU) * r))
			for lm in GameWildsSites.within(d, x, z, 14.0):
				if str(lm["kind"]) == kind and str(lm["area"]) == area:
					return lm
	return {}


func _trader(d: GameDynasty) -> Dictionary:
	for area in ["elderglade", "greenvale", "whisperwood", "mirefen"]:
		for kind in ["merchant", "traders_camp"]:
			var lm := _lm(d, area, kind)
			if not lm.is_empty():
				return lm
	return {}


func test_data() -> void:
	ok(GameWildsTrade.validate().is_empty(), "the data is sound: %s" % str(GameWildsTrade.validate()))
	ok(GameWilds.validate().is_empty(), "and so are the wilds: %s" % str(GameWilds.validate()))
	var d := _dyn()
	var lm := _trader(d)
	ok(not lm.is_empty() and GameWildsTrade.is_trader(lm), "a trader to deal with")
	ok(not GameWildsTrade.is_trader(_lm(d, "elderglade", "shrine")), "a shrine is no trader")


func test_wares() -> void:
	var d := _dyn()
	var lm := _trader(d)
	var w := GameWildsTrade.wares(d, lm)
	var c: Array = GameWildsTrade.def_of(lm)["stock_count"]
	ok(w.size() >= int(c[0]), "it has at least %d wares (%d)" % [int(c[0]), w.size()])
	var keys := {}
	for x in w:
		ok(not keys.has(str(x["key"])) and int(x["price"]) > 0, "each ware is once, with a price")
		keys[str(x["key"])] = true
	var st := d.rng.state
	ok(GameWildsTrade.wares(d, lm) == w and d.rng.state == st, "the same wares again, and no die of the dynasty's drawn")
	var later := _dyn(7, 1 + int(GameWilds.setting("renew_gens")))
	var w2 := GameWildsTrade.wares(later, lm)
	ok(w2.map(func(x): return x["key"]) != w.map(func(x): return x["key"]), "a new set when the trader renews")
	var same := _dyn(7, int(GameWilds.setting("renew_gens")))
	ok(GameWildsTrade.wares(same, lm).map(func(x): return x["key"]) == w.map(func(x): return x["key"]), "the same set for every generation of one period")
	var other := _dyn(8)
	ok(GameWildsTrade.wares(other, lm).size() > 0, "another seed has wares too")
	ok(GameWildsTrade.wares(d, {}).is_empty(), "no landmark, no wares")


func test_buy() -> void:
	var d := _dyn()
	var lm := _trader(d)
	var w := GameWildsTrade.wares(d, lm)
	var first: Dictionary = w[0]
	var g := d.heir.gold
	var line := GameWildsTrade.buy(d, lm, str(first["key"]))
	ok(d.heir.inventory.has(str(first["id"])) and d.heir.gold == g - int(first["price"]), "buying takes the price and gives the item: %s" % line)
	ok(GameWildsTrade.sold_out(d, lm, str(first["key"])) and GameWildsTrade.wares(d, lm).size() == w.size() - 1, "and it is gone from the wares")
	ok(GameWildsTrade.buy(d, lm, str(first["key"])).contains("no longer"), "it cannot be bought twice")
	ok(GameWildsSites.available(d, str(lm["id"])), "the trader is not used up by a purchase: another can be bought")
	if w.size() > 1:
		var second: Dictionary = w[1]
		GameWildsTrade.buy(d, lm, str(second["key"]))
		ok(GameWildsTrade.wares(d, lm).size() == w.size() - 2, "a second one too")
	var poor := _dyn()
	poor.heir.gold = 0
	var pw := GameWildsTrade.wares(poor, lm)
	ok(GameWildsTrade.buy(poor, lm, str(pw[0]["key"])).contains("cannot pay") and poor.shop_sold.is_empty(), "no gold, no sale, nothing marked")
	# price follows the markup and the world's prices
	var id := str(first["id"])
	var expect := maxi(1, int(round(float(GameItems.item_def(id).get("price", 0)) * float(GameWilds.setting("markup")) * GameItems.price_mult(d))))
	ok(GameWildsTrade.price_of(d, id) == expect and int(first["price"]) in [expect, int(round(float(expect) * 1.1))], "the price is the item's x the markup x the world's prices")
	# a renewal brings it back
	var later := _dyn(7, 1 + int(GameWilds.setting("renew_gens")))
	later.shop_sold = d.shop_sold.duplicate(true)
	ok(not GameWildsTrade.sold_out(later, lm, str(first["key"])), "a period on, what was bought is for sale again")
	# an item the heir already owns (non-stackable)
	var o := _dyn()
	var ow := GameWildsTrade.wares(o, lm)
	for x in ow:
		if GameItems.stack_max(str(x["id"])) <= 0:
			o.heir.inventory.append(str(x["id"]))
			ok(GameWildsTrade.buy(o, lm, str(x["key"])).contains("already"), "a piece the heir already has is refused")
			break


func test_sell() -> void:
	var d := _dyn()
	var lm := _trader(d)
	d.heir.inventory.append("iron_sword")
	var s := GameWildsTrade.sellable(d, lm)
	ok(s.any(func(x): return str(x["id"]) == "iron_sword"), "a sword is something it wants")
	var g := d.heir.gold
	var price := GameWildsTrade.sell_price(d, lm, "iron_sword")
	var line := GameWildsTrade.sell(d, lm, "iron_sword")
	ok(not d.heir.inventory.has("iron_sword") and d.heir.gold == g + price and price > 0, "selling gives gold and takes the item: %s" % line)
	ok(price < GameItems.price(d, "iron_sword"), "for less than it costs")
	ok(GameWildsTrade.sell(d, lm, "iron_sword").contains("no "), "an item not in the pack is refused")
	d.heir.inventory.append("willowbark_tonic")
	ok(GameWildsTrade.sell(d, lm, "willowbark_tonic") != "", "a remedy is dealt with")
	# materials
	GameCraft.add_material(d, "iron", 10)
	var m := GameWildsTrade.sellable_materials(d, lm)
	ok(m.any(func(x): return str(x["id"]) == "iron"), "iron is something it buys from the stores")
	var before := d.heir.gold
	GameWildsTrade.sell_material(d, lm, "iron", 4)
	ok(GameCraft.have(d, "iron") == 6 and d.heir.gold > before, "four of it sold")
	ok(GameWildsTrade.sell_material(d, lm, "oak", 1).contains("no use"), "a material it does not buy is refused")
	# a unique piece is never taken
	ok(not GameWildsTrade.wants(lm, "no_such_item"), "an unknown item is not wanted")


func test_barter() -> void:
	var d := _dyn()
	var lm := _trader(d)
	var rows := GameWildsTrade.barters(d, lm)
	ok(rows.size() >= 2 and not bool(rows[0]["ok"]), "the barter rows are listed, shut while the stores lack the materials")
	ok(GameWildsTrade.barter(d, lm, 0).contains("does not have"), "so a trade is refused")
	for r in rows:
		for mid in r["give"]:
			GameCraft.add_material(d, str(mid), int(r["give"][mid]) + 1)
	rows = GameWildsTrade.barters(d, lm)
	ok(bool(rows[0]["ok"]), "with the materials it is open")
	var g := d.heir.gold
	for i in rows.size():
		var r: Dictionary = rows[i]
		var gold_row: bool = (r["get"] as Dictionary).has("gold")
		var inv := d.heir.inventory.size()
		var held := {}
		for mid in r["give"]:
			held[mid] = GameCraft.have(d, str(mid))
		var line := GameWildsTrade.barter(d, lm, i)
		var spent := true
		for mid in r["give"]:
			spent = spent and GameCraft.have(d, str(mid)) == int(held[mid]) - int(r["give"][mid])
		ok(spent and (d.heir.gold > g if gold_row else d.heir.inventory.size() == inv + 1), "row %d trades the materials for its due: %s" % [i, line])
		g = d.heir.gold
	ok(GameWildsTrade.barter(d, lm, 99).contains("no longer"), "a row that does not exist is refused")


func test_marks() -> void:
	var d := _dyn()
	var lm := _trader(d)
	var w := GameWildsTrade.wares(d, lm)
	GameWildsTrade.buy(d, lm, str(w[0]["key"]))
	var key := GameWildsTrade.PREFIX + str(lm["id"])
	ok(d.shop_sold.has(key), "the purchase is marked under the landmark")
	# a town shop's purchase does not wipe it
	d.world.location = "hearthmere"
	d.world_seconds = 0.0
	d.world.year += 1.0
	GameShops.buy(d, "bakery", "bread_loaf")
	ok(d.shop_sold.has(key), "and a town shelf's purchase leaves it be")
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(GameWildsTrade.sold_out(back, lm, str(w[0]["key"])), "it survives a save and load")
	ok(GameShops.load_sold({key: {"period": "g0", "keys": ["item:x"]}}).has(key), "and loads clean")
	ok(not _dyn().to_dict().has("shop_sold"), "nothing is saved until something is bought")


func test_use() -> void:
	var d := _dyn()
	var lm := _trader(d)
	var s := GameSandbox.start(d)
	s.creatures.clear()
	s.heir = Vector2i(int(lm["x"]) + 1, int(lm["z"]) + 1)
	s.refresh()
	var r := s.use()
	ok(bool(r["ok"]) and str(r.get("open", "")) == "merchant" and r.get("landmark", {}) == lm, "Use beside the trader opens the panel: %s" % r["text"])
	ok(s.place_line().find("Use to") >= 0, "and the place line still says what Use does: %s" % s.place_line())


func test_panel() -> void:
	var d := _dyn()
	var lm := _trader(d)
	d.heir.inventory.append("iron_sword")
	GameCraft.add_material(d, "iron", 7)
	var panel: Control = MerchantPanel.new()
	panel.dynasty = d
	panel.landmark = lm
	root.add_child(panel)
	await process_frame
	ok(panel.rows.get_child_count() >= 6, "the panel has its sections (%d rows)" % panel.rows.get_child_count())
	var w := GameWildsTrade.wares(d, lm)
	panel._act(GameWildsTrade.buy(d, lm, str(w[0]["key"])))
	await process_frame
	ok(d.heir.inventory.has(str(w[0]["id"])) and panel.note.text != "", "a buy through the panel reaches the dynasty and is told")
	panel._act(GameWildsTrade.sell(d, lm, "iron_sword"))
	await process_frame
	ok(not d.heir.inventory.has("iron_sword"), "and a sale")
	d.heir.gold = 0
	panel._rebuild()
	await process_frame
	ok(true, "the panel draws with no gold")
	var none: Control = MerchantPanel.new()
	none.dynasty = d
	root.add_child(none)
	await process_frame
	ok(none.rows.get_child_count() == 1, "with no trader it says so")
	none.queue_free()
	panel.queue_free()


func test_breaks() -> void:
	var good := GameWilds._cache.duplicate(true)
	var md: Dictionary = GameWilds._cache["landmarks"]["merchant"]["merchant"]
	md["stock_count"] = [0, 3]
	ok(not GameWildsTrade.validate().is_empty(), "a stock count that starts at 0 is refused")
	GameWilds._cache = good.duplicate(true)
	GameWilds._cache["landmarks"]["merchant"]["merchant"]["barter"][0]["give"] = {"nonsuch": 2}
	ok(not GameWildsTrade.validate().is_empty(), "an unknown barter material is refused")
	GameWilds._cache = good.duplicate(true)
	GameWilds._cache["landmarks"]["merchant"]["merchant"]["buy_share"] = 0
	ok(not GameWildsTrade.validate().is_empty(), "a buy share of 0 is refused")
	GameWilds._cache = good.duplicate(true)
	GameWilds._cache["landmarks"]["shrine"]["trade"] = true
	ok(not GameWildsTrade.validate().is_empty(), "a trader with no merchant block is refused")
	GameWilds._cache = good.duplicate(true)
	GameWilds._cache["text"].erase("sold_mats")
	ok(not GameWildsTrade.validate().is_empty(), "a missing line is refused")
	GameWilds._cache = good
	ok(GameWildsTrade.validate().is_empty(), "and the data is sound again")
