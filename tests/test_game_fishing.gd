## Fishing (core/game/game_fishing.gd, ui/play/fishing_panel.gd, data/world/fishing.json): the data and its validator; twelve fish that are
## items with icons, a rod and bait the old shops never stock; the bank (water within reach, never a ford, a rod needed); what bites as a pure
## function of the water, biome, season, hour and weather, rolled on keyed dice that leave the dynasty's alone; the timing bar; a catch going to the
## pack or the stores and into the record book (levels, bests); saving only once something is caught and loading clean; worms found while
## foraging; Use at a bank and the thing menu on water; the panel itself (cast, wait, bite, reel, no timing, a miss costing the bait); the
## Chronicle's Fishing tab; and the autopilot never fishing.
## Run: godot --headless --path . -s res://tests/test_game_fishing.gd
extends SceneTree

const FishingPanel := preload("res://ui/play/fishing_panel.gd")
const Chronicle := preload("res://ui/play/chronicle_panel.gd")
const ItemIcon := preload("res://ui/play/item_icon.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const WorldInput := preload("res://ui/play/world_input.gd")

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
	UiSettings.path = "user://test_fishing_settings.cfg"
	test_data()
	test_items()
	test_bank()
	test_odds()
	test_keyed()
	test_reel()
	test_land()
	test_save()
	test_bait()
	test_sandbox()
	await test_panel()
	await test_screen()
	test_chronicle()
	test_autopilot()
	DirAccess.remove_absolute("user://test_fishing_settings.cfg")
	print("fishing tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh() -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


## A land tile beside water of `body`: the tile, found by looking across the world.
func _bank_tile(d: GameDynasty, body: String) -> Vector2i:
	var n := GameWorldGen.size()
	for z in range(2, n - 2, 2):
		for x in range(2, n - 2, 2):
			if GameWorldGen.body_at(d.seed_value, x, z) != "":
				continue
			var sp := GameFishing.spot(d, x, z)
			if not sp.is_empty() and str(sp["body"]) == body:
				return Vector2i(x, z)
	return Vector2i(-1, -1)


func _cond(body: String, biome: String = "plains", season: String = "summer", hour: int = 12, weather: String = "clear") -> Dictionary:
	return {"body": body, "biome": biome, "season": season, "hour": hour, "weather": weather}


func _items_of(table: Array) -> Array:
	return table.map(func(o): return str(o["item"]))


func test_data() -> void:
	ok(GameFishing.validate().is_empty(), "the shipped data passes: %s" % str(GameFishing.validate()))
	var n: int = GameFishing.species().size()
	ok(n >= 8 and n <= 12, "the book lists 8 to 12 fish (%d)" % n)
	var sp: Array = GameFishing.species()
	var keep: Variant = sp[0]["text"]
	sp[0]["text"] = ""
	ok(not GameFishing.validate().is_empty(), "a fish with no text is caught")
	sp[0]["text"] = keep
	var item: Variant = sp[0]["item"]
	sp[0]["item"] = "nonesuch"
	ok(not GameFishing.validate().is_empty(), "a fish that is no item is caught")
	sp[0]["item"] = item
	var bodies: Variant = sp[0]["bodies"]
	sp[0]["bodies"] = ["pond"]
	ok(not GameFishing.validate().is_empty(), "a fish in an unknown water is caught")
	sp[0]["bodies"] = bodies
	var w: Variant = sp[0].get("weather", {})
	sp[0]["weather"] = {"hail": 2.0}
	ok(not GameFishing.validate().is_empty(), "an unknown weather is caught")
	sp[0]["weather"] = w
	var st: Dictionary = GameFishing.data()["settings"]
	var mn: Variant = st["wait_min"]
	st["wait_min"] = 99.0
	ok(not GameFishing.validate().is_empty(), "a wait that ends before it starts is caught")
	st["wait_min"] = mn
	ok(GameFishing.validate().is_empty(), "mending the data clears it")
	ok(ItemIcon.validate().is_empty(), "the icon data passes: %s" % str(ItemIcon.validate()))


func test_items() -> void:
	var seen := {}
	for s in GameFishing.species():
		var id := str(s["item"])
		var def := GameItems.item_def(id)
		ok(not def.is_empty() and str(def["material"]) == "fish" and int(def["price"]) > 0 and float(def["weight"]) > 0.0, "%s is a priced fish item" % id)
		ok(ItemIcon.glyph_of(id) == "fish", "%s has the fish picture" % id)
		seen[ItemIcon.color_of(id).to_html()] = true
		ok("fish" in def["tags"], "%s is tagged fish (the fishmonger buys it)" % id)
	ok(seen.size() >= 10, "the fish are drawn in their own colours (%d)" % seen.size())
	ok(ItemIcon.glyph_of("worm_bait") == "worm" and GameItems.item_def("worm_bait")["stack"] == 20, "the bait has its own picture and stacks")
	ok(GameItems.SHOPS == ["forge", "store", "temple", "black_market"], "the old services are the ones the autopilot knows, unchanged")
	for id in ["fishing_rod", "worm_bait"] + GameFishing.species().map(func(s): return str(s["item"])):
		ok(str(GameItems.item_def(str(id))["shop"]) == "", "%s is stocked by none of the six old services" % id)
	ok(GameCraft.brews().has("sailors_stew") and GameCraft.data()["brews"]["sailors_stew"]["cost"].has("fish"), "the sailor's stew brews from the fish in the stores")
	var shelf_ok := 0
	for sid in ["fishmonger", "hunters_lodge"]:
		for shop in GameShops.data()["shops"]:
			if str(shop["id"]) == sid:
				for pool in shop["stock"]:
					if pool.get("ids", []).has("fishing_rod") and pool["ids"].has("worm_bait") and int(pool["count"][0]) == 2:
						shelf_ok += 1
	ok(shelf_ok == 2, "the fishmonger and the hunter's lodge both always stock a rod and bait")


func test_bank() -> void:
	var d := _fresh()
	for body in ["sea", "lake", "river"]:
		var t := _bank_tile(d, body)
		ok(t.x >= 0, "the world has a bank of the %s" % body)
		if t.x >= 0:
			var sp := GameFishing.spot(d, t.x, t.y)
			ok(str(sp["body"]) == body and Vector2(sp["x"] - t.x, sp["z"] - t.y).length() <= float(GameFishing.setting("bank_reach")) + 0.01, "the %s bank offers the %s" % [body, body])
	var far := Vector2i(-1, -1)
	var n := GameWorldGen.size()
	for z in range(4, n - 4, 5):
		for x in range(4, n - 4, 5):
			if far.x < 0 and GameWorldGen.body_at(d.seed_value, x, z) == "" and GameFishing.spot(d, x, z).is_empty():
				far = Vector2i(x, z)
	ok(far.x >= 0 and GameFishing.why_not(d, far.x, far.y) != "", "away from water there is nothing to fish")
	# a ford is shallow wading, not a place to fish
	var ford := Vector2i(-1, -1)
	for z in range(2, n - 2, 2):
		for x in range(2, n - 2, 2):
			if ford.x < 0 and GameWorldGen.body_at(d.seed_value, x, z) == "ford":
				ford = Vector2i(x, z)
	if ford.x >= 0:
		var sp := GameFishing.spot(d, ford.x, ford.y)
		ok(sp.is_empty() or str(sp["body"]) != "ford", "a ford is never the water fished")
	var lake := _bank_tile(d, "lake")
	d.heir.inventory.erase("fishing_rod")
	ok(GameFishing.why_not(d, lake.x, lake.y).contains("rod"), "without a rod the bank says so")
	d.heir.inventory.append("fishing_rod")
	ok(GameFishing.why_not(d, lake.x, lake.y) == "", "with a rod at the bank there is nothing in the way")
	var bag_heir := _fresh()
	bag_heir.heir.inventory.clear()
	bag_heir.heir.bags = {"satchel": ["fishing_rod"]}
	ok(GameFishing.rod_count(bag_heir.heir) == 1, "a rod in a bag counts")


func test_odds() -> void:
	ok(_items_of(GameFishing.odds(_cond("sea"))).has("fish_sardine") and not _items_of(GameFishing.odds(_cond("sea"))).has("fish_trout"), "the sea has sardines and no trout")
	ok(not _items_of(GameFishing.odds(_cond("river"))).has("fish_tuna") and not _items_of(GameFishing.odds(_cond("lake"))).has("fish_cod"), "no tuna in a river, no cod in a lake")
	ok(_items_of(GameFishing.odds(_cond("river", "forest", "autumn"))).has("fish_salmon") and not _items_of(GameFishing.odds(_cond("river", "forest", "summer"))).has("fish_salmon"), "salmon run in autumn, not summer")
	ok(_items_of(GameFishing.odds(_cond("lake", "plains", "summer", 23))).has("fish_eel") and not _items_of(GameFishing.odds(_cond("lake", "plains", "summer", 12))).has("fish_eel"), "eels bite at night (the window wraps past midnight)")
	ok(_items_of(GameFishing.odds(_cond("lake", "plains", "summer", 2))).has("fish_eel"), "and after it")
	ok(_items_of(GameFishing.odds(_cond("river", "plains", "summer", 6))).has("fish_sturgeon") and not _items_of(GameFishing.odds(_cond("river", "plains", "summer", 14))).has("fish_sturgeon"), "the sturgeon rises at dawn")
	ok(_items_of(GameFishing.odds(_cond("river", "plains", "summer", 8))).has("fish_trout") and not _items_of(GameFishing.odds(_cond("river", "swamp", "summer", 8))).has("fish_trout"), "trout want clear country, not a swamp")
	ok(not _items_of(GameFishing.odds(_cond("sea", "coast", "winter"))).has("fish_mackerel") and _items_of(GameFishing.odds(_cond("sea", "coast", "winter"))).has("fish_cod"), "cod in winter, mackerel not")
	var clear := _weight_of(GameFishing.odds(_cond("lake", "plains", "summer", 12, "clear")), "fish_carp")
	var heat := _weight_of(GameFishing.odds(_cond("lake", "plains", "summer", 12, "heat")), "fish_carp")
	ok(heat > clear, "a heat wave stirs the carp (%.1f against %.1f)" % [heat, clear])
	var plain_eel := _weight_of(GameFishing.odds(_cond("lake", "plains", "summer", 23)), "fish_eel")
	var swamp_eel := _weight_of(GameFishing.odds(_cond("lake", "swamp", "summer", 23)), "fish_eel")
	ok(swamp_eel > plain_eel, "eels favour a swamp")
	var base := GameFishing.odds(_cond("sea"), false)
	var baited := GameFishing.odds(_cond("sea"), true)
	ok(_weight_of(baited, "fish_cod") == 0.0 or _weight_of(baited, "fish_tuna") > _weight_of(base, "fish_tuna"), "bait raises the odds of the rarer fish")
	ok(_weight_of(baited, "fish_sardine") == _weight_of(base, "fish_sardine"), "and leaves the common ones as they were")
	# every water has something to bite in every season and at every hour and weather
	var empty := 0
	for body in ["sea", "lake", "river"]:
		for season in ["spring", "summer", "autumn", "winter"]:
			for hour in [0, 6, 12, 18]:
				for weather in ["clear", "rain", "snow", "fog"]:
					if GameFishing.odds(_cond(body, "forest", season, hour, weather)).is_empty():
						empty += 1
	ok(empty == 0, "something always bites (%d empty tables)" % empty)


func _weight_of(table: Array, item: String) -> float:
	for o in table:
		if str(o["item"]) == item:
			return float(o["weight"])
	return 0.0


func test_keyed() -> void:
	var d := _fresh()
	var lake := _bank_tile(d, "lake")
	var sp := GameFishing.spot(d, lake.x, lake.y)
	var rng_before := d.rng.state
	var a := GameFishing.bite(d, sp, 3, false)
	var b := GameFishing.bite(d, sp, 3, false)
	ok(a == b and not a.is_empty(), "the same cast on the same water and hour gives the same fish and size")
	ok(GameFishing.wait_seconds(d, sp, 3, false) == GameFishing.wait_seconds(d, sp, 3, false), "and the same wait")
	ok(GameFishing.zone_centre(d, sp, 3) == GameFishing.zone_centre(d, sp, 3), "and the same bar")
	var kinds := {}
	var waits := {}
	for i in 80:
		kinds[str(GameFishing.bite(d, sp, i, false)["item"])] = true
		waits[snappedf(GameFishing.wait_seconds(d, sp, i, false), 0.01)] = true
	ok(kinds.size() >= 3, "different casts bring different fish (%d kinds in 80)" % kinds.size())
	ok(waits.size() > 20, "and different waits")
	var lo := 99.0
	var hi := 0.0
	for i in 80:
		var wt := GameFishing.wait_seconds(d, sp, i, false)
		lo = minf(lo, wt)
		hi = maxf(hi, wt)
	ok(lo >= float(GameFishing.setting("wait_min")) - 0.001 and hi <= float(GameFishing.setting("wait_max")) + 0.001, "the wait stays in its range (%.2f to %.2f)" % [lo, hi])
	ok(GameFishing.wait_seconds(d, sp, 5, true) < GameFishing.wait_seconds(d, sp, 5, false), "bait shortens the wait")
	var other := _fresh()
	other.seed_value = 12345
	var diff := 0
	for i in 30:
		if str(GameFishing.bite(other, sp, i, false).get("item", "")) != str(GameFishing.bite(d, sp, i, false)["item"]):
			diff += 1
	ok(diff > 0, "another seed gives other fish")
	for i in 40:
		var f := GameFishing.bite(d, sp, i, false)
		var span: Array = GameFishing.row(str(f["item"]))["size"]
		if f["cm"] < float(span[0]) - 0.001 or f["cm"] > float(span[1]) + 0.001:
			ok(false, "a size outside its species' range")
	ok(GameFishing.size_id(0.0) == "small" and GameFishing.size_id(1.0) == "trophy" and GameFishing.size_id(0.5) == "fair", "the size tiers read off the data")
	ok(d.rng.state == rng_before, "no roll touched the dynasty's dice")
	# the hour changes the fish: the eel is only there at night
	d.world_seconds = 0.0
	ok(typeof(GameFishing.conditions(d, sp)["hour"]) == TYPE_INT, "the hour is a whole hour")


func test_reel() -> void:
	ok(is_equal_approx(GameFishing.marker(0.0), 0.0) and is_equal_approx(GameFishing.marker(float(GameFishing.setting("bar_period")) * 0.5), 1.0), "the marker sweeps from one end to the other and back")
	ok(is_equal_approx(GameFishing.marker(float(GameFishing.setting("bar_period"))), 0.0), "and comes round")
	ok(GameFishing.hits(0.5, 0.5, 0.3) and GameFishing.hits(0.64, 0.5, 0.3) and not GameFishing.hits(0.7, 0.5, 0.3), "a tap in the zone hits, outside misses")
	var d := _fresh()
	var w0 := GameFishing.zone_width(d)
	d.fishing = {"caught": {"fish_perch": {"n": 1, "best": 20.0}}, "points": 400}
	ok(GameFishing.zone_width(d) > w0 and GameFishing.zone_width(d) <= float(GameFishing.setting("zone_max")), "the Angler level widens the zone, up to a limit")
	var lake := _bank_tile(d, "lake")
	var sp := GameFishing.spot(d, lake.x, lake.y)
	for i in 30:
		var c := GameFishing.zone_centre(d, sp, i)
		if c - GameFishing.zone_width(d) * 0.5 < -0.001 or c + GameFishing.zone_width(d) * 0.5 > 1.001:
			ok(false, "the zone lies on the bar")


func test_land() -> void:
	var d := _fresh()
	d.heir.inventory.clear()
	ok(GameFishing.caught(d).is_empty() and GameFishing.level(d) == 0, "a new house has caught nothing and is at level 0")
	var journal := d.journal.size()
	var r := GameFishing.land(d, {"item": "fish_carp", "cm": 40.0, "size": "fair"})
	ok(r["new"] and r["to"] == "pack" and d.heir.inventory.has("fish_carp"), "a carp goes to the pack and is a new species")
	ok(str(r["text"]).contains("carp") and str(r["text"]).contains("40 cm") and str(r["text"]).contains("new species"), "and the line says so: %s" % r["text"])
	var r2 := GameFishing.land(d, {"item": "fish_carp", "cm": 55.5, "size": "fine"})
	ok(not r2["new"] and r2["best"] and str(r2["text"]).contains("biggest"), "a bigger one is the biggest yet")
	var r3 := GameFishing.land(d, {"item": "fish_carp", "cm": 30.0, "size": "small"})
	ok(not r3["best"] and float(GameFishing.caught(d)["fish_carp"]["best"]) == 55.5 and int(GameFishing.caught(d)["fish_carp"]["n"]) == 3, "a smaller one counts but leaves the best")
	ok(d.journal.size() == journal, "no journal line is written (replay fingerprints do not move)")
	var before := GameCraft.have(d, "fish")
	var m := GameFishing.land(d, {"item": "fish_minnow", "cm": 6.0, "size": "fair"})
	ok(m["to"] == "stores" and GameCraft.have(d, "fish") == before + 1 and not d.heir.inventory.has("fish_minnow"), "a minnow goes to the stores as fish")
	# a heavy pack sends a pack fish to the stores
	d.heir.inventory.clear()
	var cap := GameCarry.capacity(d.heir)
	d.heir.inventory.append("fishing_net")
	var guard := 0
	while GameCarry.can_carry(d.heir, "fish_tuna") and guard < 400:
		d.heir.inventory.append("fishing_net")
		guard += 1
	var stock := GameCraft.have(d, "fish")
	var h := GameFishing.land(d, {"item": "fish_tuna", "cm": 150.0, "size": "fine"})
	ok(h["to"] == "stores" and GameCraft.have(d, "fish") == stock + 1 and str(h["text"]).contains("too heavy"), "a fish the pack cannot carry goes to the stores (%s)" % str(cap))
	# points and levels
	var e := _fresh()
	GameFishing.land(e, {"item": "fish_minnow", "cm": 5.0, "size": "small"})
	ok(GameFishing.points(e) == 1 and GameFishing.level(e) == 0, "a common fish is one point")
	var up := false
	for i in 6:
		var landed := GameFishing.land(e, {"item": "fish_sardine", "cm": 12.0, "size": "small"})
		up = up or bool(landed["level_up"])
	ok(GameFishing.level(e) == 1 and up, "six points make a Bank-sitter, and the catch that did it says so")
	GameFishing.land(e, {"item": "fish_tuna", "cm": 150.0, "size": "fine"})
	ok(GameFishing.points(e) == 7 + 10 and GameFishing.points_to_next(e) == 20 - 17, "a rare fish is ten points (%d), %d to the next level" % [GameFishing.points(e), GameFishing.points_to_next(e)])
	ok(GameFishing.level_for(10000) == GameFishing.data()["levels"].size() - 1 and GameFishing.points_to_next(_with_points(10000)) == 0, "the top level has nothing after it")
	var book := GameFishing.book(e)
	ok(book.size() == GameFishing.species().size() and book[0]["caught"] and not book[3]["caught"], "the book has a row for every fish, caught or not")
	ok(GameFishing.book_line(book[3]) == "???" and GameFishing.book_line(book[0]).contains("Minnow"), "an unseen fish is ???")
	ok(GameFishing.book_head(e).contains("Bank-sitter") or GameFishing.book_head(e).contains("Angler"), "the head names the level")


func _with_points(n: int) -> GameDynasty:
	var d := _fresh()
	d.fishing = {"caught": {"fish_perch": {"n": 1, "best": 20.0}}, "points": n}
	return d


func test_save() -> void:
	var fresh := _fresh()
	ok(not fresh.to_dict().has("fishing"), "a house that has caught nothing saves no book")
	var d := _fresh()
	GameFishing.land(d, {"item": "fish_pike", "cm": 70.0, "size": "fair"})
	GameFishing.land(d, {"item": "fish_pike", "cm": 80.0, "size": "fine"})
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(int(GameFishing.caught(back)["fish_pike"]["n"]) == 2 and float(GameFishing.caught(back)["fish_pike"]["best"]) == 80.0 and GameFishing.points(back) == GameFishing.points(d), "the book survives a save and load")
	var old: Dictionary = d.to_dict()
	old.erase("fishing")
	var loaded := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(old)))
	ok(loaded.fishing.is_empty() and GameFishing.level(loaded) == 0, "an old save with no book loads clean")
	for junk in ["text", 5, [1, 2], {"caught": 5}, {"caught": {"nonesuch": {"n": 3, "best": 5.0}}}, {"caught": {"fish_pike": "x"}}, {"caught": {"fish_pike": {"n": -2, "best": 5.0}}},
			{"caught": {"fish_pike": {"n": 1, "best": "big"}}}, {"caught": {"fish_pike": {"n": 1, "best": 0.0}}}, {"caught": {"fish_pike": {"n": 1, "best": 20.0}}, "points": "lots"},
			{"caught": {"fish_pike": {"n": 1, "best": 20.0}}, "points": -9}]:
		var raw: Dictionary = old.duplicate(true)
		raw["fishing"] = junk
		var g := GameDynasty.from_dict(raw)
		ok(typeof(g.fishing) == TYPE_DICTIONARY and (g.fishing.is_empty() or (int(g.fishing["points"]) >= 0 and GameFishing.caught(g).has("fish_pike"))), "a damaged book loads clean: %s" % str(junk))
	ok(GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict()))).fishing_casts == 0, "the cast number is never saved")


func test_bait() -> void:
	var d := _fresh()
	d.heir.inventory.clear()
	ok(GameFishing.bait_count(d.heir) == 0 and not GameFishing.take_bait(d.heir), "no bait to take")
	d.heir.inventory.append_array(["worm_bait", "worm_bait"])
	ok(GameFishing.bait_count(d.heir) == 2 and GameFishing.take_bait(d.heir) and GameFishing.bait_count(d.heir) == 1, "bait is taken one at a time")
	d.heir.inventory.clear()
	d.heir.bags = {"satchel": ["worm_bait"]}
	ok(GameFishing.bait_count(d.heir) == 1 and GameFishing.take_bait(d.heir) and GameFishing.bait_count(d.heir) == 0, "and from a bag")
	var found := 0
	var tiles := 0
	var again := true
	for x in 60:
		var one := _fresh()
		one.heir.inventory.clear()
		var n := GameFishing.bait_find(one, 100 + x, 200)
		tiles += 1
		found += 1 if n > 0 else 0
		ok(n == GameFishing.bait_count(one.heir), "the worms found are the worms in the pack")
		var two := _fresh()
		two.heir.inventory.clear()
		again = again and GameFishing.bait_find(two, 100 + x, 200) == n
	ok(again, "the same node gives the same worms")
	ok(found > 5 and found < tiles, "some foraging turns up worms and some does not (%d of %d)" % [found, tiles])
	var e := _fresh()
	var rng_before := e.rng.state
	GameFishing.bait_find(e, 10, 10)
	ok(e.rng.state == rng_before, "and none of the dynasty's dice")


func test_sandbox() -> void:
	var d := _fresh()
	var lake := _bank_tile(d, "lake")
	var sb := GameSandbox.start(d)
	sb.creatures.clear()
	sb.heir = lake
	d.heir.inventory.erase("fishing_rod")
	var r := sb.use()
	ok(not r["ok"] and str(r["text"]).contains("rod") and not r.has("open"), "Use at a bank with no rod says a rod is needed")
	d.heir.inventory.append("fishing_rod")
	r = sb.use()
	ok(r["ok"] and str(r.get("open", "")) == "fishing" and str(r["spot"]["body"]) == "lake", "Use at a bank with a rod opens the fishing panel for the water")
	var rng_before := d.rng.state
	sb.fish()
	ok(d.rng.state == rng_before and d.fishing.is_empty(), "asking to fish changes nothing")
	sb.space = "somewhere"
	ok(not sb.fish()["ok"], "not indoors")
	sb.space = "world"
	var named := sb.name_at(float(sb.heir.x) + 0.5, float(sb.heir.y) + 0.5)
	ok(str(named.get("kind", "")) == "heir", "the heir is still named first")
	var sp := GameFishing.spot(d, lake.x, lake.y)
	var w := sb.name_at(float(sp["x"]) + 0.5, float(sp["z"]) + 0.5)
	ok(str(w.get("kind", "")) == "water" and str(w["name"]) == "The lake" and sb.thing_actions(w).size() == 1 and sb.thing_actions(w)[0]["id"] == "fish", "water is named and the thing menu offers Fish")
	var dry := Vector2i(-1, -1)
	for z in range(4, GameWorldGen.size() - 4, 5):
		for x in range(4, GameWorldGen.size() - 4, 5):
			if dry.x < 0 and GameWorldGen.body_at(d.seed_value, x, z) == "" and GameFishing.spot(d, x, z).is_empty() and GameTown.at(x, z).is_empty():
				dry = Vector2i(x, z)
	sb.heir = dry
	var nothing := sb.use()
	ok(not nothing["ok"] and not nothing.has("open"), "Use on dry land far from water is as it was")
	ok(sb.name_at(float(dry.x) + 3.5, float(dry.y) + 0.5).is_empty() or str(sb.name_at(float(dry.x) + 3.5, float(dry.y) + 0.5)["kind"]) != "water", "dry ground is not water")
	var actions: Dictionary = GameSandbox.data()["thing_menu"]
	ok(actions["water"] == ["fish"], "the data gives water one action")


func test_panel() -> void:
	var d := _fresh()
	var lake := _bank_tile(d, "lake")
	var sp := GameFishing.spot(d, lake.x, lake.y)
	UiSettings.set_access("easy_fishing", false)
	UiSettings.set_access("reduced_motion", false)
	var host := Control.new()
	host.size = Vector2(1280, 720)
	root.add_child(host)
	var p: Control = FishingPanel.new()
	p.dynasty = d
	p.spot = sp
	var changes := [0]
	p.on_change = func(): changes[0] += 1
	host.add_child(p)
	await process_frame
	ok(p.stage == "ready" and p.has_meta("modal"), "the panel opens with the rod in hand and is modal (the world waits)")
	ok(UiSettings.ACCESS_KEYS.has("easy_fishing"), "no timing is an accessibility option")
	d.heir.inventory.clear()
	ok(not p.cast(), "no rod, no cast")
	d.heir.inventory.append_array(["fishing_rod", "worm_bait"])
	var rng_before := d.rng.state
	ok(p.cast() and p.stage == "wait", "casting starts the wait")
	ok(GameFishing.bait_count(d.heir) == 0 and d.fishing_casts == 1, "the bait is used up")
	ok(not p.cast() and not p.tap(), "a tap during the wait does nothing")
	p.step(p.wait - 0.01)
	ok(p.stage == "wait", "the wait runs its time")
	p.step(0.02)
	ok(p.stage == "bite" and not p.got.is_empty(), "then something bites")
	# a tap with the marker in the green lands the fish
	p.t = _time_for(p.zone)
	ok(GameFishing.hits(GameFishing.marker(p.t), p.zone, GameFishing.zone_width(d)), "(the marker is in the zone)")
	var item := str(p.got["item"])
	var held := d.heir.inventory.count(item)
	var stores := GameCraft.have(d, "fish")
	ok(p.tap() and p.stage == "done", "a tap in the green reels it in")
	ok(GameFishing.total_caught(d) == 1 and (d.heir.inventory.count(item) == held + 1 or GameCraft.have(d, "fish") == stores + 1), "and the fish is in the pack or the stores")
	ok(str(p.line).contains(GameFishing.fish_name(item).to_lower()), "the line names it: %s" % p.line)
	ok(d.rng.state == rng_before, "the dynasty's dice stayed still through a cast")
	# a miss costs only the bait
	d.heir.inventory.append("worm_bait")
	ok(p.tap() and p.stage == "wait", "a tap after a catch casts again")
	p.step(p.wait + 0.01)
	var caught_before := GameFishing.total_caught(d)
	p.t = _time_for(fposmod(p.zone + 0.5, 1.0))
	if GameFishing.hits(GameFishing.marker(p.t), p.zone, GameFishing.zone_width(d)):
		p.t = _time_for(1.0 - p.zone if p.zone < 0.5 else 0.0)
	var pack_before := d.heir.inventory.size()
	p.tap()
	ok(p.stage == "done" and GameFishing.total_caught(d) == caught_before and str(p.line).contains("slips"), "a tap outside the green loses the fish")
	ok(d.heir.inventory.size() == pack_before, "and nothing else")
	# no timing: the fish always comes
	UiSettings.set_access("easy_fishing", true)
	var q: Control = FishingPanel.new()
	q.dynasty = d
	q.spot = sp
	host.add_child(q)
	await process_frame
	ok(q.easy, "with no timing on, the panel is easy")
	var landed_before := GameFishing.total_caught(d)
	q.cast()
	q.step(q.wait + 0.01)
	ok(q.stage == "done" and GameFishing.total_caught(d) == landed_before + 1, "after the wait the fish always comes in")
	ok(q.wait >= float(GameFishing.setting("wait_min")) + float(GameFishing.setting("no_timing_extra_wait")) - 0.001, "(after a slightly longer wait)")
	q.queue_free()
	UiSettings.set_access("easy_fishing", false)
	UiSettings.set_access("reduced_motion", true)
	var r: Control = FishingPanel.new()
	r.dynasty = d
	r.spot = sp
	host.add_child(r)
	await process_frame
	ok(r.easy, "reduced motion has no sweeping bar either")
	r.queue_free()
	UiSettings.set_access("reduced_motion", false)
	ok(changes[0] >= 2, "the screen was told of the bait and the catch (%d)" % changes[0])
	for c in host.get_children():
		if c != p:
			c.queue_free()
	host.queue_free()
	await process_frame


## A time since the bite at which the marker stands at `pos`.
func _time_for(pos: float) -> float:
	return pos * 0.5 * float(GameFishing.setting("bar_period"))


func test_screen() -> void:
	UiSettings.store("world_zoom", 1.0)
	var d := _fresh()
	var lake := _bank_tile(d, "lake")
	var scr: Control = load("res://ui/play/sandbox_screen.gd").new()
	var fake := FakeApp.new()
	fake.dynasty = d
	root.add_child(fake)
	scr.app = fake
	scr.size = Vector2(1280, 720)
	root.add_child(scr)
	await process_frame
	await process_frame
	scr.sb.creatures.clear()
	scr.sb.heir = lake
	d.heir.inventory.erase("fishing_rod")
	scr._use()
	ok(scr.get_children().filter(func(c): return c.has_meta("pane") and str(c.get_meta("pane")) == "fishing_panel").is_empty(), "Use at a bank with no rod opens nothing")
	ok(str(scr.last_line).contains("rod"), "and says why: %s" % scr.last_line)
	d.heir.inventory.append("fishing_rod")
	scr._use()
	await process_frame
	var open: Array = scr.get_children().filter(func(c): return c.has_meta("pane") and str(c.get_meta("pane")) == "fishing_panel")
	ok(open.size() == 1, "Use at a bank with a rod opens the fishing panel")
	for c in open:
		c.queue_free()
	await process_frame
	scr._fish()
	await process_frame
	ok(scr.get_children().filter(func(c): return c.has_meta("pane") and str(c.get_meta("pane")) == "fishing_panel").size() == 1, "the Fish key's action opens it too")
	for c in scr.get_children():
		if c.has_meta("pane"):
			c.queue_free()
	await process_frame
	ok(InputMap.has_action("world_fish") and WorldInput.keys_of("world_fish") == ["V"], "the Fish key is in the input map")
	scr.queue_free()
	fake.queue_free()
	await process_frame


class FakeApp extends Node:
	var dynasty: GameDynasty

	func show_state() -> void:
		pass


func test_chronicle() -> void:
	var d := _fresh()
	d.heir.inventory.erase("fishing_rod")
	var c: Control = Chronicle.new()
	c.dynasty = d
	root.add_child(c)
	ok(_find_tab(c, "Fishing") == null, "with no rod and no catch the Chronicle has no Fishing tab")
	c.queue_free()
	d.heir.inventory.append("fishing_rod")
	GameFishing.land(d, {"item": "fish_trout", "cm": 33.0, "size": "fair"})
	var c2: Control = Chronicle.new()
	c2.dynasty = d
	root.add_child(c2)
	var tab := _find_tab(c2, "Fishing")
	ok(tab != null, "with a catch the Chronicle has a Fishing tab")
	if tab != null:
		var text := _all_text(tab)
		ok(text.contains("Trout") and text.contains("33") and text.contains("???"), "it lists the trout with its best and hides the rest")
	c2.queue_free()


func _find_tab(n: Node, name: String) -> Node:
	if n is TabContainer:
		return (n as TabContainer).get_node_or_null(name)
	for ch in n.get_children():
		var f := _find_tab(ch, name)
		if f != null:
			return f
	return null


func _all_text(n: Node) -> String:
	var s := ""
	if n is Label:
		s += (n as Label).text + "\n"
	elif n is RichTextLabel:
		s += (n as RichTextLabel).text + "\n"
	for ch in n.get_children():
		s += _all_text(ch)
	return s


func test_autopilot() -> void:
	var d := _fresh()
	d.heir.inventory.append("fishing_rod")
	GameBot.live_life(d)
	ok(d.fishing.is_empty() and d.fishing_casts == 0, "the autopilot never fishes")
	ok(not d.to_dict().has("fishing"), "and its save has no book")
