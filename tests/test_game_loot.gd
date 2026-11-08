## The loot generator (GameLoot, data/items/loot.json): the data and 10 ways to break it; that an item is built from
## its own id and a damaged id is refused; what the world allows (tiers by generation, then grades); rarity out of a
## million with the top one ten in a million; that every roll builds a sound item; that a made item works wherever an
## item does (wear, sell, tags, weapon kind, save and load); drops on their own dice that never touch the dynasty's;
## and that the autopilot never meets any of it.
## Run: godot --headless --path . -s res://tests/test_game_loot.gd
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
	test_build()
	test_world()
	test_rarity()
	test_rolls()
	test_use()
	test_drops()
	test_legend()
	test_untouched()
	print("loot tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func dyn(seed_value: int = 5) -> GameDynasty:
	return GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")


func _stat(item: Dictionary, stat: String) -> float:
	for e in item["effects"]:
		if e["stat"] == stat:
			return float(e["value"])
	return 0.0


func _id(rarity: String = "rare", slot: String = "weapon", form: String = "sword", mat: String = "steel", affixes: String = "keen+of_the_wolf", mythic: String = "-", grade: int = 0, q: int = 5) -> String:
	return "gen:%s:%s:%s:%s:%s:%s:%d:%d" % [rarity, slot, form, mat, affixes, mythic, grade, q]


# ---------------------------------------------------------------- the data

func test_data() -> void:
	ok(GameLoot.validate().is_empty(), "the data is sound: %s" % str(GameLoot.validate()))
	var total := 0.0
	for r in GameLoot.data()["rarities"]:
		total += float(r["weight"])
	ok(total == 1000000.0, "the rarity weights make a million")
	ok(float(GameLoot.data()["_rarity"]["mythic"]["weight"]) == 10.0, "the top rarity is ten in a million")
	ok(GameLoot.top_tier() == 4 and GameLoot.is_generated("gen:x") and not GameLoot.is_generated("iron_sword"), "four tiers; ids are told apart by their prefix")


func _with(change: Callable, check: Callable) -> void:
	var saved: Dictionary = GameLoot.data().duplicate(true)
	change.call()
	check.call()
	GameLoot._cache = saved


func test_breaks() -> void:
	_with(func(): GameLoot.data()["forms"][0]["effects"][0]["stat"] = "no_such_stat",
		func(): ok(not GameLoot.validate().is_empty(), "an unknown stat is found"))
	_with(func(): GameLoot.data()["rarities"][0]["weight"] = 5,
		func(): ok(not GameLoot.validate().is_empty(), "rarity weights that do not add up are found"))
	_with(func(): GameLoot.data()["settings"]["tier_gens"][0] = 3,
		func(): ok(not GameLoot.validate().is_empty(), "tiers that do not start at generation 1 are found"))
	_with(func(): GameLoot.data()["settings"]["tier_gens"] = [1, 9, 5, 30],
		func(): ok(not GameLoot.validate().is_empty(), "tiers that do not rise are found"))
	_with(func(): GameLoot.data()["forms"][0]["needs"] = ["no_such_tag"],
		func(): ok(not GameLoot.validate().is_empty(), "a form needing an unknown tag is found"))
	_with(func(): GameLoot.data()["forms"][0]["weapon_kind"] = "spear",
		func(): ok(not GameLoot.validate().is_empty(), "a weapon of an unknown kind is found"))
	_with(func(): GameLoot.data()["affixes"][0]["slots"] = ["pocket"],
		func(): ok(not GameLoot.validate().is_empty(), "an affix for a slot that does not exist is found"))
	_with(func(): GameLoot.data()["mythics"] = GameLoot.data()["mythics"].filter(func(m): return "armor" not in m["slots"]),
		func(): ok(not GameLoot.validate().is_empty(), "a slot with no mythic is found"))
	_with(func(): GameLoot.data()["rarities"][1]["mythic"] = true,
		func(): ok(not GameLoot.validate().is_empty(), "two mythic rarities are found"))
	_with(func(): GameLoot.data()["text"].erase("find_mythic"),
		func(): ok(not GameLoot.validate().is_empty(), "a missing line of text is found"))
	_with(func(): GameLoot.data()["forms"][1]["id"] = GameLoot.data()["forms"][0]["id"],
		func(): ok(not GameLoot.validate().is_empty(), "a repeated form is found"))
	ok(GameLoot.validate().is_empty(), "and the data is put back")


# ---------------------------------------------------------------- building from an id

func test_build() -> void:
	var id := _id()
	var d := GameLoot.build(id)
	ok(d["name"] == "Keen Steel Sword of the Wolf" and d["slot"] == "weapon" and d["tier"] == 2 and d["rarity"] == "rare", "an id builds a named item: %s" % d.get("name"))
	ok(d["id"] == id and d["generated"] and d["material"] == "steel" and d["weight"] > 0.0 and d["price"] > 0, "it carries its id, material, weight and price")
	ok(GameLoot.build(id) == d and GameLoot.build(id)["effects"] == d["effects"], "building twice gives the same item")
	var stats := {}
	for e in d["effects"]:
		stats[e["stat"]] = e["value"]
	ok(stats.has("melee_damage") and stats.has("luck") and stats.has("reflexes"), "its effects are the form's and its affixes': %s" % str(stats))
	# a plain one has no affixes and a plain name
	var plain := GameLoot.build(_id("common", "weapon", "sword", "iron", "-"))
	ok(plain["name"] == "Iron Sword" and plain["tier"] == 1 and plain["effects"].size() == 1, "a common item is plain: %s" % plain.get("name"))
	# a grade, a quality and a rarity each make it stronger
	var base := _stat(plain, "melee_damage")
	ok(_stat(GameLoot.build(_id("common", "weapon", "sword", "iron", "-", "-", 5, 5)), "melee_damage") > base * 1.4, "a grade makes it stronger")
	ok(GameLoot.build(_id("common", "weapon", "sword", "iron", "-", "-", 5, 5))["name"].ends_with(" +5"), "and shows in its name")
	ok(float(GameLoot.build(_id("common", "weapon", "sword", "iron", "-", "-", 0, 9))["effects"][0]["value"]) > float(GameLoot.build(_id("common", "weapon", "sword", "iron", "-", "-", 0, 0))["effects"][0]["value"]), "a better quality is stronger")
	ok(_stat(GameLoot.build(_id("legendary", "weapon", "sword", "iron", "keen+of_the_wolf+arcane", "-", 0, 5)), "melee_damage") > _stat(plain, "melee_damage"), "a legendary is stronger than a common of the same make")
	ok(GameLoot.build(_id("legendary", "weapon", "sword", "iron", "keen+of_the_wolf+arcane", "-", 0, 5))["description"].contains("Also arcane"), "its third affix is told in the description")
	# higher tiers hit harder, as the shops' gear does
	ok(float(GameLoot.build(_id("common", "weapon", "sword", "mithril", "-"))["effects"][0]["value"]) > float(GameLoot.build(_id("common", "weapon", "sword", "steel", "-"))["effects"][0]["value"]) and GameLoot.build(_id("common", "weapon", "sword", "mithril", "-"))["price"] > GameLoot.build(_id("common", "weapon", "sword", "steel", "-"))["price"], "a mithril sword beats a steel one and costs more")
	# the mythic
	var m := GameLoot.build(_id("mythic", "weapon", "sword", "starmetal", "keen+of_the_wolf+arcane", "dawnbringer", 0, 9))
	ok(m["name"] == "Dawnbringer, Starmetal Sword" and m["unique"] and m["price"] > 100000 / 100, "a mythic has a name of its own and is unique: %s" % m.get("name"))
	ok(float(m["effects"][0]["value"]) > 0.0, "and effects")
	# damaged ids build nothing
	for bad in ["", "iron_sword", "gen:", "gen:rare:weapon:sword:steel:keen+of_the_wolf:-:0", _id("rare", "weapon", "sword", "steel", "keen"), _id("rare", "weapon", "sword", "steel", "keen+keen"),
			_id("rare", "armor", "sword", "steel", "keen+of_the_wolf"), _id("rare", "weapon", "sword", "glass", "keen+of_the_wolf"), _id("rare", "weapon", "sword", "steel", "keen+of_nothing"),
			_id("common", "weapon", "sword", "steel", "keen"), _id("rare", "weapon", "sword", "steel", "keen+of_the_wolf", "dawnbringer"), _id("mythic", "weapon", "sword", "steel", "keen+of_the_wolf+arcane", "-"),
			_id("rare", "weapon", "sword", "steel", "keen+of_the_wolf", "-", 99), _id("rare", "weapon", "sword", "steel", "keen+of_the_wolf", "-", 0, 12), _id("rare", "weapon", "sword", "steel", "keen+of_the_wolf", "-", -1),
			_id("rare", "weapon", "sword", "steel", "keen+of_the_dawn", "-", 0, 3), _id("rare", "weapon", "sword", "copper", "keen+of_the_dawn")]:
		ok(GameLoot.build(bad).is_empty(), "a damaged id builds nothing: %s" % bad)
	ok(GameItems.item_def("gen:garbage").is_empty() and GameItems.item_name("gen:garbage") == "gen:garbage", "an unknown made id is just unknown")


# ---------------------------------------------------------------- the world

func test_world() -> void:
	ok(GameLoot.tier_ceiling(1) == 1 and GameLoot.tier_ceiling(5) == 1 and GameLoot.tier_ceiling(6) == 2 and GameLoot.tier_ceiling(14) == 3 and GameLoot.tier_ceiling(30) == 4 and GameLoot.tier_ceiling(5000) == 4, "material tiers open by generation")
	ok(GameLoot.grade_of(1) == 0 and GameLoot.grade_of(41) == 0 and GameLoot.grade_of(42) == 1 and GameLoot.grade_of(54) == 2, "grades follow once the top tier has been open a while")
	ok(GameLoot.grade_of(100000) == int(GameLoot.setting("max_grade")), "and stop at the cap")
	# what comes from an early world is plain; from a late one, more
	var early_tiers := {}
	var late_tiers := {}
	var late_grade := 0
	for i in 400:
		var r := RandomNumberGenerator.new()
		r.seed = i
		var e := GameLoot.build(GameLoot.roll_item(r, 1))
		early_tiers[e["tier"]] = true
		var r2 := RandomNumberGenerator.new()
		r2.seed = i
		var l := GameLoot.build(GameLoot.roll_item(r2, 400))
		late_tiers[l["tier"]] = true
		late_grade = maxi(late_grade, int(GameLoot.parse(l["id"])["grade"]))
	ok(not early_tiers.has(3) and not early_tiers.has(4), "an early world makes nothing above tier 2 (a lucky rare may reach 2): %s" % str(early_tiers.keys()))
	ok(late_tiers.has(4) and late_grade == int(GameLoot.setting("max_grade")), "a late world makes tier 4 things at the top grade: %s, grade %d" % [str(late_tiers.keys()), late_grade])
	# no commons above the ceiling
	var over := 0
	for i in 600:
		var r := RandomNumberGenerator.new()
		r.seed = 5000 + i
		var id := GameLoot.roll_item(r, 3)
		var parts := GameLoot.parse(id)
		var rarity: Dictionary = GameLoot.data()["_rarity"][parts["rarity"]]
		if int(parts["tier"]) > GameLoot.tier_ceiling(3) + int(rarity["overreach"]):
			over += 1
	ok(over == 0, "nothing is made above what the world allows (and the rarity's reach)")


# ---------------------------------------------------------------- rarity

func test_rarity() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 424242
	var counts := {}
	var n := 400000
	for i in n:
		var k := GameLoot.pick_rarity(r, 1.0)
		counts[k] = int(counts.get(k, 0)) + 1
	var common := float(counts["common"]) / n
	ok(common > 0.69 and common < 0.71, "about 70%% are common: %.3f" % common)
	ok(int(counts.get("legendary", 0)) > 250 and int(counts.get("legendary", 0)) < 550, "about one in a thousand is legendary: %d of %d" % [counts.get("legendary", 0), n])
	ok(int(counts.get("mythic", 0)) <= 15, "a mythic is ten in a million: %d of %d" % [counts.get("mythic", 0), n])
	var order := ["common", "fine", "rare", "epic", "legendary", "mythic"]
	var prev := 1e12
	for k in order:
		ok(float(GameLoot.data()["_rarity"][k]["weight"]) < prev, "%s is rarer than the one before" % k)
		prev = float(GameLoot.data()["_rarity"][k]["weight"])
	# legends and bosses raise the odds of the rare ones
	var r2 := RandomNumberGenerator.new()
	r2.seed = 424242
	var rare_plain := 0
	var rare_boost := 0
	for i in 20000:
		if GameLoot.pick_rarity(r, 1.0) not in ["common", "fine"]:
			rare_plain += 1
		if GameLoot.pick_rarity(r2, 25.0) not in ["common", "fine"]:
			rare_boost += 1
	ok(rare_boost > rare_plain * 4, "a legend's boost makes the rare ones far likelier: %d against %d" % [rare_boost, rare_plain])


# ---------------------------------------------------------------- every roll builds

func test_rolls() -> void:
	var labels := GameItems._effect_labels()
	var bad := 0
	var slots := {}
	var forms := {}
	var mats := {}
	var weapons_kind_ok := true
	for i in 3000:
		var r := RandomNumberGenerator.new()
		r.seed = i * 7 + 1
		var gen: int = [1, 6, 14, 30, 60, 400][i % 6]
		var id := GameLoot.roll_item(r, gen, 1.0 if i % 3 != 0 else 25.0)
		var d := GameLoot.build(id)
		if d.is_empty() or d["effects"].is_empty() or int(d["price"]) < 1 or float(d["weight"]) <= 0.0:
			bad += 1
			continue
		for e in d["effects"]:
			if not labels.has(e["stat"]):
				bad += 1
		slots[d["slot"]] = true
		forms[GameLoot.parse(id)["form"]] = true
		mats[d["material"]] = true
		if d["slot"] == "weapon" and GameFeats.weapon_kind(id) == "":
			weapons_kind_ok = false
	ok(bad == 0, "every one of 3,000 rolls builds a sound item (%d bad)" % bad)
	ok(slots.size() == 3 and forms.size() >= 14 and mats.size() >= 12, "and they cover the slots (%d), forms (%d) and materials (%d)" % [slots.size(), forms.size(), mats.size()])
	ok(weapons_kind_ok, "every made weapon has a weapon kind")
	# the same dice make the same item
	var a := RandomNumberGenerator.new()
	a.seed = 77
	var b := RandomNumberGenerator.new()
	b.seed = 77
	ok(GameLoot.roll_item(a, 20) == GameLoot.roll_item(b, 20), "the same dice make the same item")


# ---------------------------------------------------------------- a made item is an item

func test_use() -> void:
	var d := dyn()
	var id := _id("rare", "weapon", "sword", "steel", "keen+of_the_wolf")
	d.heir.inventory.append(id)
	ok(GameItems.slot_of(id) == "weapon" and GameItems.kind_of(id) == "weapon" and GameItems.item_name(id) == "Keen Steel Sword of the Wolf" and GameItems.stack_max(id) == 0, "the item code reads a made item: %s" % GameItems.item_name(id))
	ok(GameItems.material_of(id) == "steel" and GameItems.weight_of(id) > 0.0 and GameItems.has_tag(id, "metal") and GameItems.has_tag(id, "sword") and GameItems.has_tag(id, "rare") and GameItems.has_tag(id, "weapon"), "and its tags: %s" % str(GameItems.tags_of(id)))
	ok(GameFeats.weapon_kind(id) == "blade", "a made sword is a blade for the feats")
	var before := d.heir.trait_total("melee_damage")
	var msg := GameItems.equip(d, id)
	ok(GameItems.equipped(d.heir, "weapon") == id and d.heir.trait_total("melee_damage") > before, "wearing it adds its effects: %s" % msg)
	ok(id not in d.heir.inventory, "and takes it out of the pack")
	ok(GameItems.sell_price(d, id) > 0 and GameItems.describe(id) != "", "it has a sell price and a description")
	ok(GameItems.gear_score(id, "melee", d.heir) > 0.0, "the autopilot's gear score can read it")
	# save and load
	var h2 := GameHeir.from_dict(d.heir.to_dict())
	ok(h2.equipment["weapon"] == id and h2.trait_total("melee_damage") == d.heir.trait_total("melee_damage"), "it survives a save and load, worn")
	d.heir.inventory.append(_id("common", "armor", "plate", "iron", "-"))
	var dd := d.to_dict()
	var d2 := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(dd)))
	ok(d2 != null and d2.heir.equipment["weapon"] == id and _id("common", "armor", "plate", "iron", "-") in d2.heir.inventory, "and through the whole dynasty, carried")
	# a damaged id in an old or edited save does not crash anything
	d.heir.inventory.append("gen:nonsense:::::::")
	var d3 := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(d3 != null and GameItems.item_def("gen:nonsense:::::::").is_empty() and d3.heir.trait_total("melee_damage") > 0.0, "a damaged id in a save loads as an unknown item")
	GameItems.sell(d3, "gen:nonsense:::::::")


# ---------------------------------------------------------------- drops

func test_drops() -> void:
	var d := dyn()
	var foes: Array = []
	for i in 4000:
		foes.append({"id": "slime", "name": "Slime"})
	var rng_before := d.rng.state
	var lines := GameLoot.after_search(d, foes)
	var chance := float(GameLoot.setting("drop_chance"))
	ok(lines.size() > 4000 * chance * 0.7 and lines.size() < 4000 * chance * 1.3, "about %.0f%% of foes leave something: %d of 4,000" % [chance * 100.0, lines.size()])
	ok(d.heir.inventory.size() == lines.size(), "each goes into the pack")
	ok(d.rng.state == rng_before, "and the dynasty's dice are not touched")
	ok(d.heir.inventory.all(func(x): return not GameLoot.build(str(x)).is_empty()), "every one is a sound item")
	ok(lines[0].begins_with("Tess finds a "), "told as a find: %s" % lines[0])
	var again := dyn()
	ok(GameLoot.after_search(again, foes) == lines and again.heir.inventory == d.heir.inventory, "the same seed and hunt leave the same things")
	var other := dyn()
	other.total_hunts = 1
	GameLoot.after_search(other, foes)
	ok(other.heir.inventory != d.heir.inventory, "another hunt leaves other things")
	# a foe's roll does not depend on the others
	var one := dyn()
	var many := dyn()
	GameLoot.after_search(one, [{"id": "slime"}])
	GameLoot.after_search(many, [{"id": "slime"}, {"id": "slime"}, {"id": "slime"}])
	ok(one.heir.inventory.is_empty() or many.heir.inventory.size() >= 1, "(a first foe's find is also found with more beside it)")
	var dead := dyn()
	dead.state = "succession"
	ok(GameLoot.after_search(dead, foes).is_empty() and dead.heir.inventory.is_empty(), "nothing is found outside a life")
	# the screens' call: the search as it plays, then the made things
	var s := dyn()
	var real: Array = []
	for i in 400:
		real.append({"id": "slime", "name": "Slime", "carries": []})
	s.loot = {"foes": real, "gold": 10, "item_chance": 0.0}
	var sl := GameLoot.search_dead(s)
	ok(not sl.is_empty() and s.heir.gold > dyn().heir.gold and s.heir.inventory.size() > 0 and s.loot.is_empty(), "search_dead searches the dead and then the made things")


func test_legend() -> void:
	var d := dyn()
	d.slain_bosses["dragon"] = d.gen
	var lines := GameLoot.after_legend(d, "victory", [{"id": "dragon", "boss": true, "name": "Dragon"}])
	ok(lines.size() == 1 and d.heir.inventory.size() == 1 and d.flags.has("legend_loot_dragon"), "a slain legend leaves one thing: %s" % str(lines))
	ok(GameLoot.after_legend(d, "victory", [{"id": "dragon", "boss": true}]).is_empty(), "once per legend")
	var f := dyn()
	ok(GameLoot.after_legend(f, "defeat", [{"id": "dragon", "boss": true}]).is_empty() and GameLoot.after_legend(f, "victory", [{"id": "slime", "boss": false}]).is_empty(), "not on a defeat, and not for a plain foe")
	var rare := 0
	for i in 300:
		var dd := dyn(i + 1)
		dd.slain_bosses["dragon"] = dd.gen
		GameLoot.after_legend(dd, "victory", [{"id": "dragon", "boss": true}])
		if GameLoot.build(str(dd.heir.inventory[0]))["rarity"] not in ["common", "fine"]:
			rare += 1
	ok(rare > 150, "a legend's find is usually a rare one: %d of 300" % rare)


# ---------------------------------------------------------------- the autopilot never meets it

func test_untouched() -> void:
	var classes := GameData.starting_ids(GameData.classes)
	var met := 0
	for sd in 3:
		var d := GameDynasty.new_game(sd + 1, "", classes[sd % classes.size()], "faetouched", "human")
		for g in 3:
			GameBot.live_life(d)
			for x in d.heir.inventory:
				if GameLoot.is_generated(str(x)):
					met += 1
			for x in d.heir.equipment.values():
				if GameLoot.is_generated(str(x)):
					met += 1
			if d.state != "succession":
				break
			GameBot.choose_best(d)
	ok(met == 0, "an autopilot life meets no made item (the screens ask for drops, the rules of a life do not)")
