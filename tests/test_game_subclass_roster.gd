## The twenty subclasses (roadmap item 60): the roster itself and the data around it. Twenty callings with their own
## names (none of the generic ones), every perk key in the catalog given by a calling and read by a place in the rules,
## every calling with at least two works (items that carry a `subclass` and a `recipe`) that no shop sells in any town,
## the validators that hold all of it together and 12 ways to break them, every calling taken at the founding, the
## take price following `price_mult`, the replay's founding keeping the calling, and that the autopilot (which takes no
## calling) finds and makes none of their items.
## Run: godot --headless --path . -s res://tests/test_game_subclass_roster.gd
extends SceneTree

var fails := 0
var checks := 0

const NAMES := ["Tamer", "Runescribe", "Armorer", "Bladewright", "Enchanter", "Alchemist", "Artificer", "Gemwright", "Hidewright", "Trapsmith", "Spiritbinder", "Wildcaller", "Feastwright", "Wayfinder", "Delver", "Stonewright", "Greenwarden", "Steadholder", "Caravaneer", "Venomwright"]


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	test_roster()
	test_perks_are_read()
	test_strength_bands()
	test_works()
	test_no_shop_sells_them()
	test_breaks()
	test_founding_each()
	test_price()
	test_replay_founding()
	test_autopilot()
	print("subclass roster tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func dyn(sub: String = "", seed_value: int = 5) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human", GameSex.MALE, sub)
	d.pending_event = {}
	d.heir.gold = 100000
	return d


func test_roster() -> void:
	var defs := GameSubclass.defs()
	ok(defs.size() == 20, "there are twenty callings (%d)" % defs.size())
	ok(GameSubclass.validate().is_empty(), "the data is sound: %s" % str(GameSubclass.validate()))
	var names: Array = defs.map(func(s): return str(s["name"]))
	ok(names == NAMES, "they are the ones named: %s" % str(names))
	for generic in GameSubclass.GENERIC_NAMES:
		ok(generic not in names, "no calling is called '%s'" % generic)
	var ids := {}
	for s in defs:
		ids[str(s["id"])] = true
		var legacy: bool = str(s["id"]) == "breeder" and str(s["name"]) == "Tamer"   # renamed after saves, replays and the harness already used the id
		ok(legacy or str(s["id"]) == str(s["name"]).to_lower(), "%s has an id that is its name in lower case" % s["name"])
		ok(str(s["about"]).length() > 40, "%s says what it is" % s["name"])
		ok((s["perks"] as Dictionary).size() >= 3 and (s["perks"] as Dictionary).size() <= 5, "%s has three to five perks" % s["name"])
		ok(float(s.get("price_mult", 1.0)) > 0.0, "%s has a price" % s["name"])
		for k in s["perks"]:
			ok(GameSubclass.data()["perks"].has(k), "%s's perk %s is in the catalog" % [s["name"], k])
			var m := float(s["perks"][k])
			ok(m > 0.0 and m != 1.0 and m >= 0.5 and m <= 1.6, "%s's perk %s is a real change, not a wild one (%s)" % [s["name"], k, m])
	ok(ids.size() == 20, "twenty distinct ids")
	# no two callings share the same set of perks
	var sets := {}
	for s in defs:
		var keys: Array = (s["perks"] as Dictionary).keys()
		keys.sort()
		sets[str(keys)] = true
	ok(sets.size() == 20, "each calling has its own mix of perks")


## Every perk key is given by some calling and read, through GameSubclass.perk, by some place in the rules.
func test_perks_are_read() -> void:
	var src := ""
	for f in DirAccess.get_files_at("res://core/game/"):
		if f.ends_with(".gd") and f != "game_subclass.gd":
			src += FileAccess.get_file_as_string("res://core/game/" + f) + "\n"
	var catalog: Dictionary = GameSubclass.data()["perks"]
	ok(catalog.size() == 34, "34 perks in the catalog (%d)" % catalog.size())
	for k in catalog:
		ok(src.contains("perk(") and (src.contains('"%s"' % k)), "the perk %s is named by a place in the rules" % k)
		var read := false
		for line in src.split("\n"):
			if line.contains("GameSubclass.perk(") and line.contains('"%s"' % k):
				read = true
				break
		ok(read, "a place reads the perk %s through GameSubclass.perk" % k)
	# spread: the callings reach the systems the brief names
	var used := {}
	for s in GameSubclass.defs():
		for k in s["perks"]:
			used[k] = (int(used.get(k, 0)) + 1)
	ok(used.size() == catalog.size(), "every perk in the catalog is given by a calling")


## Strength bands from the balance pass (docs/BALANCE.md, Subclasses): no founded perk moves a number by more
## than 2x either way, a perk that acts in the heir's fights or training stays within 25% (founded), and a
## calling's price stays in the shop-like range. A new calling or retune that breaks one needs a harness run.
func test_strength_bands() -> void:
	var fs := float(GameSubclass.setting("founder_scale"))
	var fight := ["attack_mult", "spell_mult", "defense_mult", "train_mult", "hunt_gold_mult", "hunt_xp_mult"]
	for s in GameSubclass.defs():
		ok(float(s.get("price_mult", 1.0)) >= 0.5 and float(s.get("price_mult", 1.0)) <= 1.5, "%s: price in range" % s["id"])
		for k in s["perks"]:
			var founded := 1.0 + (float(s["perks"][k]) - 1.0) * fs
			ok(founded >= 0.4 and founded <= 2.0, "%s: founded %s %.2f within 0.4-2.0" % [s["id"], k, founded])
			if k in fight:
				ok(absf(founded - 1.0) <= 0.25, "%s: founded %s %.2f within 25%% of 1 (it acts in the autopilot's life)" % [s["id"], k, founded])


func test_works() -> void:
	var total := 0
	for s in GameSubclass.defs():
		var id := str(s["id"])
		var works := GameSubclass.works(id)
		ok(works.size() >= 2, "%s has works (%d)" % [s["name"], works.size()])
		total += works.size()
		var last := 0
		for w in works:
			var it: Dictionary = GameData.items[w]
			ok(str(it["subclass"]) == id and GameSubclass.calling_of(w) == id, "%s belongs to %s" % [w, id])
			ok(str(it["shop"]) == "" and not it.get("unique", false), "%s is sold nowhere" % w)
			ok(GameMaterials.has(str(it["material"])) and float(it["weight"]) > 0.0, "%s has a material and a weight" % w)
			ok(int(it["recipe"]["min_level"]) >= last, "%s's works come easiest first" % id)
			last = int(it["recipe"]["min_level"])
			ok(not (it["effects"] as Array).is_empty(), "%s does something" % w)
			ok(str(it["description"]).length() > 20, "%s has a description" % w)
			for m in it["recipe"]["cost"]:
				ok(GameMaterials.has(str(m)), "%s's recipe uses a listed material (%s)" % [w, m])
	ok(total == 40, "forty works in all (%d)" % total)
	# a plain item is nobody's work
	ok(GameSubclass.calling_of("iron_sword") == "" and GameSubclass.works("nonesuch").is_empty(), "a shop item belongs to no calling")
	# the calling brews
	var brews := 0
	for s in GameSubclass.defs():
		var h := GameHeir.new()
		h.subclass = str(s["id"])
		brews += GameCraft.calling_brews(h).size()
	ok(brews == 5 and GameCraft.calling_brews(null).is_empty() and GameCraft.calling_brews(GameHeir.new()).is_empty(), "five callings brew something of their own; no calling brews none")


## No town's shops stock a calling's work, whatever the tier of the town.
func test_no_shop_sells_them() -> void:
	var d := dyn()
	var seen := 0
	for loc in GameData.world["locations"]:
		d.world.location = str(loc["id"])
		for svc in GameItems.SHOPS:
			for id in GameItems.stock(d, svc):
				seen += 1
				ok(GameSubclass.calling_of(str(id)) == "", "%s is not for sale at %s (%s)" % [id, loc["id"], svc])
	ok(seen > 20, "(the shops were looked through: %d wares)" % seen)
	for id in GameData.items:
		if str(GameData.items[id].get("subclass", "")) != "":
			ok(not GameItems.sold_here(d, str(id)) and str(GameData.items[id].get("shop", "")) == "", "%s is in no shop" % id)


## Breaks the data in memory, asks the validator, and puts it back.
func _breaks(what: String, change: Callable, validator: Callable) -> void:
	var saved_items := GameData.items.duplicate(true)
	var saved_sub: Dictionary = GameSubclass.data().duplicate(true)
	var saved_craft: Dictionary = GameCraft.data().duplicate(true)
	change.call()
	ok(not (validator.call() as Array).is_empty(), "the validator finds: %s" % what)
	GameData.items = saved_items
	GameSubclass._cache = saved_sub
	GameCraft._cache = saved_craft
	ok((validator.call() as Array).is_empty(), "and the data is put back after: %s" % what)


func test_breaks() -> void:
	var sv := func(): return GameSubclass.validate()
	var cv := func(): return GameCraft.validate()
	_breaks("a calling with no works", func(): GameData.items.erase("whetstone_charm"); GameData.items.erase("wrights_edge"), sv)
	_breaks("a calling with one work", func(): GameData.items.erase("wrights_edge"), sv)
	_breaks("a work sold in a shop", func(): GameData.items["wrights_edge"]["shop"] = "forge", sv)
	_breaks("a work that is unique", func(): GameData.items["wrights_edge"]["unique"] = true, sv)
	_breaks("a work of an unknown calling", func(): GameData.items["wrights_edge"]["subclass"] = "nonesuch", sv)
	_breaks("a work with no recipe", func(): GameData.items["wrights_edge"].erase("recipe"), sv)
	_breaks("a recipe with no cost", func(): GameData.items["wrights_edge"]["recipe"]["cost"] = {}, sv)
	_breaks("a recipe of an unknown material", func(): GameData.items["wrights_edge"]["recipe"]["cost"] = {"unobtainium": 1}, sv)
	_breaks("a recipe of a level below 1", func(): GameData.items["wrights_edge"]["recipe"]["min_level"] = 0, sv)
	_breaks("a generic name", func(): GameSubclass.data()["subclasses"][3]["name"] = "Blacksmith", sv)
	_breaks("a name used twice", func(): GameSubclass.data()["subclasses"][3]["name"] = "Armorer", sv)
	_breaks("a perk no calling gives", func(): GameSubclass.data()["perks"]["telepathy"] = "what the mind hears", sv)
	_breaks("a price of nothing", func(): GameSubclass.data()["subclasses"][3]["price_mult"] = 0.0, sv)
	_breaks("a calling brew of an unknown calling", func(): GameCraft.data()["calling_brews"]["green_tincture"]["subclass"] = "nonesuch", cv)
	_breaks("a calling brew of an unknown material", func(): GameCraft.data()["calling_brews"]["green_tincture"]["cost"] = {"unobtainium": 1}, cv)
	_breaks("a calling brew that makes nothing", func(): GameCraft.data()["calling_brews"]["green_tincture"]["makes"] = 0, cv)
	_breaks("a calling brew that is also a plain brew", func(): GameCraft.data()["brews"]["green_tincture"] = GameCraft.data()["calling_brews"]["green_tincture"].duplicate(), cv)
	# the other validators still hold with the new items (gear art, weapon kinds, materials, carry)
	ok(GameFeats.validate().is_empty(), "every new weapon has a kind: %s" % str(GameFeats.validate()))
	ok(GameMaterials.validate().is_empty(), "every new item reaches a listed material: %s" % str(GameMaterials.validate()))
	ok(GameCarry.validate().is_empty(), "the heaviest new work is carriable")
	ok(GameDisease.validate().is_empty(), "the disease data still holds")


func test_founding_each() -> void:
	for s in GameSubclass.defs():
		var id := str(s["id"])
		var d := dyn(id)
		ok(d.heir.subclass == id and d.heir.subclass_founded, "%s can be the founding calling" % id)
		var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
		ok(back.heir.subclass == id and back.heir.subclass_founded, "%s survives a save and load" % id)
		# the perks are told for each, and at the founded strength
		var lines := GameSubclass.perk_lines(d.heir, id, true)
		ok(lines.size() == (s["perks"] as Dictionary).size() and not lines.any(func(l): return "{" in l or l.begins_with(":")), "%s tells its perks: %s" % [id, str(lines)])
		# a year of life with it runs
		d.pass_time(1.0)
		ok(d.state == "life" and d.heir.subclass == id, "%s lives a year" % id)


func test_price() -> void:
	var d := dyn()
	var base := float(GameSubclass.setting("take_cost")) * GameData.enemy_scale(d.gen)
	for s in GameSubclass.defs():
		var id := str(s["id"])
		ok(GameSubclass.cost(d, id) == int(round(base * float(s.get("price_mult", 1.0)))), "%s costs its own price" % id)
	ok(GameSubclass.cost(d, "enchanter") > GameSubclass.cost(d, "feastwright"), "the finer callings cost more to take")
	var line := GameSubclass.take(d, "delver")
	ok(d.heir.subclass == "delver" and "Delver" in line, "a calling can be taken: %s" % line)
	ok(GameSubclass.cost(d, "wayfinder") == int(round(base * 0.9 * 2.0)), "changing costs double its own price")


func test_replay_founding() -> void:
	var r := GameReplay.begin(3, "Tess", "warrior", "faetouched", "human", GameSex.MALE, 25, {}, "delver")
	ok(r.start["subclass"] == "delver" and r.dynasty.heir.subclass == "delver", "a replay founded in a calling keeps it")
	var plain := GameReplay.begin(3, "Tess", "warrior", "faetouched", "human")
	ok(not plain.start.has("subclass") and plain.dynasty.heir.subclass == "", "a replay with none writes no key")
	ok(not GameReplay.begin(3, "Tess", "warrior", "faetouched", "human", GameSex.MALE, 25, {}, "nonesuch").start.has("subclass"), "an unknown calling is not written")
	var text := r.to_text()
	var back := GameReplay.from_text(text)
	ok(back["ok"] and str(back["replay"]["start"]["subclass"]) == "delver", "it reads back from text")
	var data: Dictionary = (back["replay"] as Dictionary).duplicate(true)
	data["start"]["subclass"] = "nonesuch"
	ok(not GameReplay.check(data)["ok"], "a replay of an unknown calling is refused")
	data["start"]["subclass"] = 5
	ok(GameReplay.found(data["start"]).heir.subclass == "", "a founding calling that is not text founds none")


## The autopilot takes no calling, finds no work and makes none: three lives of it leave no calling's item anywhere.
func test_autopilot() -> void:
	var classes := GameData.starting_ids(GameData.classes)
	var touched := 0
	for sd in 3:
		var d := GameDynasty.new_game(sd + 1, "", classes[sd % classes.size()], "faetouched", "human")
		for g in 3:
			GameBot.live_life(d)
			for id in d.heir.inventory + d.heir.equipment.values():
				if GameSubclass.calling_of(str(id)) != "":
					touched += 1
			ok(d.heir.subclass == "", "the autopilot takes no calling")
	ok(touched == 0, "the autopilot never meets a calling's work")
