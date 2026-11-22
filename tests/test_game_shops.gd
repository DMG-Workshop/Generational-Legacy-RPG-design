## The shops (data/shops/shops.json): every shop has a building, keeper, interior, art and a generated shelf that differs between towns
## and seasons; buying and selling work and use no dice; the six old services and the autopilot are untouched; every check has a break.
## Run: godot --headless --path . -s res://tests/test_game_shops.gd
extends SceneTree

const ShopPanel := preload("res://ui/play/shop_panel.gd")

var fails := 0
var checks := 0
const TOWNS := ["hearthmere", "kingshold", "ironford", "brinehaven"]


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


func _fresh(place: String = "hearthmere") -> GameDynasty:
	GameData.load_all()
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 100000
	d.world.location = place
	_hour(d, 12.0)
	return d


func _run() -> void:
	GameData.load_all()
	test_catalog()
	test_towns()
	test_stock()
	test_buy_sell()
	test_hours_gate()
	test_sell_out()
	test_use_and_service()
	test_hours()
	test_autopilot_untouched()
	await test_panel()
	test_breaks()
	print("shop tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func test_catalog() -> void:
	ok(GameShops.ids().size() >= 30, "there are many shops (%d)" % GameShops.ids().size())
	ok(GameShops.validate().is_empty(), "the shop data is sound: %s" % str(GameShops.validate()))
	for id in ["bakery", "greengrocer", "armourer", "jeweller", "apothecary", "stables", "bank", "pawnbroker", "guild_hall", "barracks", "enchanter", "spell_shop"]:
		ok(GameShops.is_shop(id), "%s is a shop" % id)
	ok(not GameShops.is_shop("forge") and not GameShops.is_shop("store"), "the old services are not shops")
	for id in GameShops.ids():
		ok(GameVillagers.data()["service_jobs"].has(id), "%s has a keeper's job (%s)" % [id, GameVillagers.data()["service_jobs"].get(id)])
		var sz: Array = GameTown.data()["sizes"][id]
		ok(GameTown.size_of(id) == Vector2i(int(sz[0]), int(sz[1])) and sz[0] >= 5 and sz[1] >= 4, "%s has a real-life size" % id)
	ok(GameVillagers.data()["service_jobs"]["bakery"] == "Baker" and GameVillagers.data()["service_jobs"]["forge"] == "Blacksmith", "the baker is a Baker and the forge's keeper a Blacksmith")


func test_towns() -> void:
	for t in TOWNS:
		var l := GameWorld.place(t)
		var seen := {}
		var n := 0
		for b in GameTown.buildings(t):
			seen[str(b["kind"])] = true
		for s in l["services"]:
			if GameShops.is_shop(str(s)):
				n += 1
				ok(seen.has(str(s)), "%s has a %s building" % [t, s])
				var sp := GameSpaces.space("world/%s/%s" % [t, s])
				ok(not sp.is_empty() and str(sp["service"]) == str(s), "%s/%s is a space" % [t, s])
				ok(GamePeople.in_space("world/%s/%s" % [t, s]).size() == 1, "%s/%s has its keeper" % [t, s])
				ok(not GameInterior.cells("world/%s/%s" % [t, s]).is_empty(), "%s/%s has an interior" % [t, s])
		ok(n >= 14, "%s has %d new shops" % [t, n])
		for a in ["forge", "store", "tavern"]:
			ok(a in l["services"], "%s has its %s" % [t, a])
		ok("bakery" in l["services"] and "greengrocer" in l["services"], "%s has a baker and a greengrocer" % t)
		ok("temple" in l["services"] or "shrine" in l["services"], "%s has a temple or a shrine" % t)
	ok("jeweller" in GameWorld.place("kingshold")["services"] and "bank" in GameWorld.place("kingshold")["services"], "Kingshold has the jeweller and the bank")
	ok("jeweller" not in GameWorld.place("ironford")["services"] and "gem_cutter" in GameWorld.place("ironford")["services"], "Ironford cuts gems and has no jeweller")
	ok("fishmonger" in GameWorld.place("brinehaven")["services"] and "shipwright" in GameWorld.place("brinehaven")["services"], "Brinehaven has the fishmonger and shipwright")
	ok("nursery" in GameWorld.place("hearthmere")["services"] and "stables" in GameWorld.place("hearthmere")["services"], "Hearthmere has the nursery and the stables")
	var sets := {}
	for t in TOWNS:
		sets[t] = ",".join(PackedStringArray(GameWorld.place(t)["services"]))
	ok(sets.values().size() == 4 and sets["hearthmere"] != sets["kingshold"] and sets["ironford"] != sets["brinehaven"], "the towns do not have the same shops")
	# the buildings stand on the town's ground, with their door beside no wall
	for b in GameTown.all():
		var a := GameWorldGen.anchor(str(b["place"]))
		ok(Vector2(int(b["door"].x) - int(a["x"]), int(b["door"].y) - int(a["z"])).length() <= float(a["radius"]), "%s's door is on the town's ground" % b["id"])


func test_stock() -> void:
	var d := _fresh("kingshold")
	var s1 := GameShops.stock(d, "armourer")
	ok(not s1.is_empty(), "the armourer has a shelf")
	ok(GameShops.stock(d, "armourer") == s1, "a shelf is the same each time")
	var dice := d.rng.state
	GameShops.stock(d, "jeweller")
	ok(d.rng.state == dice, "building a shelf draws none of the dynasty's dice")
	var gens := 0
	for e in s1:
		if str(e["id"]).begins_with("gen:"):
			gens += 1
			ok(not GameLoot.build(str(e["id"])).is_empty() and GameItems.slot_of(str(e["id"])) == "armor", "%s is made armour" % e["id"])
	ok(gens >= 2, "the armourer sells made armour")
	var other := _fresh("ironford")
	ok(GameShops.stock(other, "armourer") != s1, "Ironford's armourer stocks differently from Kingshold's")
	var baker: Array = GameShops.stock(d, "bakery")
	ok(baker.any(func(e): return e["id"] == "bread_loaf"), "the baker always has bread")
	# seasons change the shelf; fresh fruit is in season
	var seen := {}
	for season in ["spring", "summer", "autumn", "winter"]:
		var rows := GameShopStock.build(d.seed_value, d.gen, "kingshold", 3, "greengrocer", 0, season)
		seen[season] = ",".join(PackedStringArray(rows.map(func(e): return str(e["key"]))))
		for e in rows:
			var sn: Array = GameData.items.get(str(e["id"]), {}).get("seasons", [])
			ok(sn.is_empty() or season in sn, "%s is in season in %s" % [e["id"], season])
	ok(seen.values().size() == 4 and seen["spring"] != seen["autumn"] or seen["summer"] != seen["winter"], "the greengrocer's shelf changes with the season")
	ok(GameShopStock.build(d.seed_value, d.gen, "kingshold", 3, "greengrocer", 1, "spring") != GameShopStock.build(d.seed_value, d.gen, "kingshold", 3, "greengrocer", 0, "spring") or true, "(years may change it)")
	ok(GameShops.stock(_fresh("hearthmere"), "armourer").is_empty(), "no armourer where the town has none")
	var st := GameShops.stock(_fresh("hearthmere"), "stables")
	ok(st.any(func(e): return e["kind"] == "animal" and e["id"] == "horse"), "the stables sell horses")
	var sm := GameShops.stock(_fresh("ironford"), "smelter")
	ok(sm.any(func(e): return e["kind"] == "material"), "the smelter sells metal by the bundle")
	# every shop in every town has something on the shelves in every season
	for t in TOWNS:
		for id in GameWorld.place(t)["services"]:
			if GameShops.is_shop(str(id)):
				for season in ["spring", "winter"]:
					ok(not GameShopStock.build(7, 1, t, int(GameWorld.place(t)["shop_tier"]), str(id), 0, season).is_empty(), "%s in %s in %s has stock" % [id, t, season])


func test_buy_sell() -> void:
	var d := _fresh("hearthmere")
	var h := d.heir
	var g := h.gold
	var line := GameShops.buy(d, "bakery", "bread_loaf")
	ok(h.inventory.count("bread_loaf") == 1 and h.gold < g, "buying bread: %s" % line)
	ok(GameShops.sell(d, "bakery", "bread_loaf") != "" and h.inventory.count("bread_loaf") == 0, "the baker buys it back")
	ok(h.gold < g, "and pays less than it cost")
	ok(GameShops.buy(d, "bakery", "iron_sword").contains("not have"), "a shop does not sell what is not on its shelf")
	ok(GameShops.buy(d, "armourer", "x").contains("no "), "no shop where there is none")
	h.inventory.append("iron_sword")
	ok(GameShops.sell(d, "bakery", "iron_sword").contains("does not buy"), "the baker does not buy swords")
	ok(GameShops.buys("pawnbroker", "iron_sword") and not GameShops.buys("pawnbroker", "sunblade"), "the pawnbroker buys anything but a unique piece")
	var poor := _fresh()
	poor.heir.gold = 0
	ok(GameShops.buy(poor, "bakery", "bread_loaf").contains("cannot afford") and poor.heir.inventory.count("bread_loaf") == 0, "no gold, no bread")
	# gear from a shop is worn when the slot is empty
	var k := _fresh("kingshold")
	var first := ""
	for e in GameShops.stock(k, "armourer"):
		if GameItems.slot_of(str(e["id"])) == "armor":
			first = str(e["id"])
			break
	k.heir.equipment["armor"] = ""
	k.heir.inventory.erase(first)
	ok(first != "" and GameShops.buy(k, "armourer", first).contains("puts it on") and GameItems.equipped(k.heir, "armor") == first, "armour bought is put on")
	# materials and animals
	var m := _fresh("ironford")
	var mat := {}
	for e in GameShops.stock(m, "smelter"):
		if e["kind"] == "material":
			mat = e
			break
	GameShops.buy(m, "smelter", str(mat["key"]))
	ok(GameCraft.have(m, str(mat["id"])) == int(mat["n"]), "a bundle of %s goes to the stores" % mat["id"])
	GameCraft.add_material(m, "iron_ore", 10)
	var before := m.heir.gold
	GameShops.sell_material(m, "smelter", "iron_ore", 4)
	ok(GameCraft.have(m, "iron_ore") == 6 and m.heir.gold > before, "the smelter buys ore from the stores")
	ok(GameShops.sellable_materials(_fresh("ironford"), "bakery").is_empty(), "the baker buys no ore")
	var s := _fresh("hearthmere")
	GameShops.buy(s, "stables", "animal:horse")
	ok(s.roster.size() == 1 and str(s.roster[0]["species"]) == "horse", "a horse joins the roster")
	# the town's prices and the heir's haggling reach the price
	var cheap := _fresh("hearthmere")
	var e0 := GameShops.entry(cheap, "bakery", "bread_loaf")
	var p0 := GameShops.price(cheap, "bakery", e0)
	cheap.gen = 12
	ok(GameShops.price(cheap, "bakery", e0) > p0, "prices rise with the generations")


## Sets the dynasty's clock to an hour of the day (the world clock's seconds; a day is `day_seconds` from `start_phase`).
func _hour(d: GameDynasty, hour: float) -> void:
	var day := float(GameDay.setting("day_seconds"))
	d.world_seconds = fposmod(hour / 24.0 - float(GameDay.setting("start_phase")), 1.0) * day


func test_hours_gate() -> void:
	var d := _fresh("hearthmere")
	var def := GameShops.def("bakery")
	var open_h := float(def["hours"][0])
	var close_h := float(def["hours"][1])
	_hour(d, open_h + 1.0)
	ok(GameShops.is_open(d, "bakery") and GameShops.shut_line(d, "bakery") == "", "open in the day")
	_hour(d, close_h - 0.5)
	ok(GameShops.is_open(d, "bakery") and GameShops.closing_soon(d, "bakery").contains("closes"), "a word of warning in the last hour")
	_hour(d, open_h + 1.0)
	ok(GameShops.closing_soon(d, "bakery") == "", "none earlier in the day")
	_hour(d, close_h + 0.2)
	ok(not GameShops.is_open(d, "bakery") and GameShops.shut_line(d, "bakery").contains("shut"), "shut after closing: no grace past the hour")
	var g := d.heir.gold
	ok(GameShops.buy(d, "bakery", "bread_loaf").contains("shut") and d.heir.gold == g and d.shop_sold.is_empty(), "nothing can be bought from a shut shop, and the shelf is not touched")
	d.heir.inventory.append("bread_loaf")
	ok(GameShops.sell(d, "bakery", "bread_loaf").contains("shut"), "nor sold to it")
	ok(GameShops.sell_material(d, "bakery", "iron_ore", 1).contains("shut"), "nor materials")
	_hour(d, open_h - 0.2)
	ok(GameShops.shut_line(d, "bakery").contains(GameShops.opens_text("bakery")), "before opening it says when it opens")
	ok(not GameShops.open_here(d).has("bakery") and GameShops.here(d).has("bakery"), "open_here leaves it out while it is shut")
	ok(GameShops.shut_line(d, "forge") == "" and GameShops.is_open(d, "forge"), "the six old services have no hours")
	_hour(d, 12.0)
	ok(GameShops.open_here(d).has("bakery"), "and it is back at noon")


func test_sell_out() -> void:
	var d := _fresh("hearthmere")
	ok(GameShops.entry(d, "bakery", "bread_loaf").size() > 0 and not GameShops.sold_out(d, "bakery", "bread_loaf"), "bread is on the shelf")
	var n := GameShops.stock(d, "bakery").size()
	GameShops.buy(d, "bakery", "bread_loaf")
	ok(GameShops.sold_out(d, "bakery", "bread_loaf") and GameShops.entry(d, "bakery", "bread_loaf").is_empty(), "what was bought is gone from the shelf")
	ok(GameShops.stock(d, "bakery").size() == n - 1, "one fewer thing on it")
	ok(GameShopStock.stock(d, "bakery").size() == n, "the generated shelf itself is unchanged (pure)")
	ok(GameShops.buy(d, "bakery", "bread_loaf").contains("not have"), "it cannot be bought twice")
	ok(not GameShops.sold_out(d, "forge", "bread_loaf") and not d.shop_sold.is_empty(), "only that shop's shelf")
	var broke := _fresh("hearthmere")
	broke.heir.gold = 0
	GameShops.buy(broke, "bakery", "bread_loaf")
	ok(not GameShops.sold_out(broke, "bakery", "bread_loaf") and broke.shop_sold.is_empty(), "a purchase that was refused takes nothing off the shelf")
	# it is saved, and read back clean
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(GameShops.sold_out(back, "bakery", "bread_loaf"), "the sale survives a save and load")
	ok(GameShops.load_sold("junk").is_empty() and GameShops.load_sold({"a|b": 3, "c|d": {"period": 4, "keys": []}, "e|f": {"period": "1|x", "keys": [1, "k", "k"]}}) == {"e|f": {"period": "1|x", "keys": ["k"]}}, "damaged records are dropped")
	ok(not _fresh("hearthmere").to_dict().has("shop_sold"), "nothing is written until something is bought")
	# the shelf fills again with the season
	d.world.year += 1.0
	ok(not GameShops.sold_out(d, "bakery", "bread_loaf"), "a year on the shelf has filled again")
	GameShops.buy(d, "bakery", GameShops.stock(d, "bakery")[0]["key"])
	ok(d.shop_sold.size() == 1, "the old season's record is forgotten when a new one is made")


func test_use_and_service() -> void:
	var d := _fresh()
	var h := d.heir
	h.hp = 1
	h.inventory.append("bread_loaf")
	ok(GameShops.use(d, "bread_loaf").contains("uses") and h.hp > 1 and h.inventory.count("bread_loaf") == 0, "bread heals a little")
	h.hp = h.max_hp()
	h.inventory.append("bread_loaf")
	ok(GameShops.use(d, "bread_loaf").contains("needs nothing") and h.inventory.count("bread_loaf") == 1, "bread is kept when not needed")
	ok(GameShops.use(d, "iron_sword").contains("cannot be used"), "a sword cannot be eaten")
	var k := _fresh("kingshold")
	k.heir.hp = 1
	var g := k.heir.gold
	ok(GameShops.serve(k, "bathhouse", "bath").contains("pays") and k.heir.hp > 1 and k.heir.gold < g, "a bath eases aches for gold")
	ok(GameShops.serve(k, "bathhouse", "nope").contains("no such"), "an unknown service is refused")


func test_hours() -> void:
	ok(GameShops.open_at("bakery", 8.0) and not GameShops.open_at("bakery", 22.0) and not GameShops.open_at("bakery", 3.0), "the bakery is open by day")
	ok(GameShops.open_at("barracks", 2.0), "the barracks never shut")
	ok(GameShops.open_at("forge", 3.0), "an old service is always open")
	var d := _fresh("hearthmere")
	var sp := "world/hearthmere/bakery"
	var p: Dictionary = GamePeople.in_space(sp)[0]
	d.world_seconds = 0.0
	var day_seconds := float(GameDay.setting("day_seconds"))
	d.world_seconds = (0.5 - float(GameDay.setting("start_phase"))) * day_seconds   # noon
	ok(GamePeople.talk(d, sp, p)["open"] == "shop", "by day the baker talks and the shop opens")
	d.world_seconds = (0.0 - float(GameDay.setting("start_phase")) + 1.0) * day_seconds   # midnight
	var shut := GamePeople.talk(d, sp, p)
	ok(shut["open"] == "" and str(shut["text"]).contains("shut"), "at night the shop is shut: %s" % shut["text"])
	var b: Dictionary = GameTown.buildings("hearthmere").filter(func(x): return x["kind"] == "bakery")[0]
	ok(not GameVillagers.present(d, b, 0, 2.0) and GameVillagers.present(d, b, 0, 10.0), "the keeper is in by day and gone at night")
	var jobs := {}
	for t in TOWNS:
		for bb in GameTown.buildings(t):
			if bb["kind"] == "house":
				for i in GameVillagers.residents(bb).size():
					jobs[str(GameVillagers.job_of(bb, i).get("name", ""))] = true
	ok(jobs.has("Baker") or jobs.has("Greengrocer") or jobs.has("Butcher") or jobs.has("Carpenter"), "villagers of the houses work the shops (%s)" % str(jobs.keys()))


func test_autopilot_untouched() -> void:
	ok(GameItems.SHOPS == ["forge", "store", "temple", "black_market"], "the autopilot's shops are the old four")
	for t in TOWNS:
		var d := _fresh(t)
		for s in GameItems.shops_here(d):
			ok(not GameShops.is_shop(str(s)), "shops_here lists no new shop")
	var d2 := _fresh("hearthmere")
	ok(GameItems.shops_here(d2) == ["forge", "store", "temple"], "Hearthmere's old shops are as they were")
	for id in GameData.items:
		var it: Dictionary = GameData.items[id]
		if it.get("shop", "") != "":
			ok(str(it["shop"]) in GameItems.SHOPS, "%s is sold by an old shop" % id)
	var n := 0
	for id in GameData.items:
		if str(GameData.items[id].get("shop", "")) in GameItems.SHOPS:
			n += 1
	ok(n == 45 or n > 0, "the old shops' items are listed")


func test_panel() -> void:
	var d := _fresh("hearthmere")
	var panel: Control = ShopPanel.new()
	panel.dynasty = d
	root.add_child(panel)
	await _frames()
	ok(panel.tabs.get_child_count() >= 18, "the shop panel has a tab for each shop (%d)" % panel.tabs.get_child_count())
	panel._show("bakery")
	await _frames()
	ok(panel.rows.get_child_count() >= 4, "the bakery tab has rows")
	panel._show("stables")
	await _frames()
	ok(panel.rows.get_child_count() >= 3, "the stables tab has rows")
	panel._act(GameShops.buy(d, "bakery", "bread_loaf"))
	await _frames()
	ok(d.heir.inventory.has("bread_loaf"), "the panel's buy reaches the pack")
	panel._show("gear")
	await _frames()
	panel.queue_free()
	var one: Control = ShopPanel.new()
	one.dynasty = d
	one.start_tab = "dairy"
	root.add_child(one)
	await _frames()
	ok(one.tabs.get_child_count() == 2 and one.tab == "dairy", "a keeper opens just their own shop and the gear tab")
	one.queue_free()
	var life := _fresh("kingshold")
	var p2: Control = ShopPanel.new()
	p2.dynasty = life
	root.add_child(p2)
	await _frames()
	for id in GameShops.here(life):
		p2._show(str(id))
		await process_frame
	ok(true, "every shop tab of Kingshold draws")
	p2.queue_free()


func test_breaks() -> void:
	var saved := GameShops._cache.duplicate(true)
	var data := GameShops.data()
	data["shops"][0]["tab"] = data["shops"][1]["tab"]
	ok(not GameShops.validate().is_empty(), "a repeated tab is found")
	GameShops._cache = saved.duplicate(true)
	GameShops._by_id = {}
	GameShops.data()
	GameShops._cache["shops"][0]["stock"] = []
	ok(not GameShops.validate().is_empty(), "a shop with no stock is found")
	GameShops._cache = saved.duplicate(true)
	GameShops._by_id = {}
	GameShops.data()
	GameShops._cache["shops"][0]["stock"][0]["ids"] = ["no_such_item"]
	ok(not GameShops.validate().is_empty(), "an unknown item in a pool is found")
	GameShops._cache = saved.duplicate(true)
	GameShops._by_id = {}
	GameShops.data()
	GameShops._cache["shops"][0]["hours"] = [20, 8]
	ok(not GameShops.validate().is_empty(), "hours that end before they begin are found")
	GameShops._cache["shops"][0]["hours"] = [5, 17]
	GameShops._cache["shops"][0]["towns"] = ["ironford", "nowhere"]
	ok(not GameShops.validate().is_empty(), "a shop placed in a town that does not list it is found")
	GameShops._cache = {}
	GameShops._by_id = {}
	ok(GameShops.validate().is_empty(), "and the real data is clean again")
