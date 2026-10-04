## Shops, equipment and the temple (GameItems).
## godot --headless --path . -s res://tests/test_game_items.gd
extends SceneTree

var failures := 0
var checks := 0


func _check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL: ", what)


func _near(a: float, b: float, eps: float = 0.0001) -> bool:
	return absf(a - b) <= eps


func _fresh(class_id: String = "warrior") -> GameDynasty:
	var d := GameDynasty.new_game(4242, "Test", class_id, GameData.traits_in(["bloodline"])[0], "human")
	d.heir.traits = d.heir.traits.filter(func(t): return not GameItems.is_curse(t))
	d.heir.dormant = d.heir.dormant.filter(func(t): return not GameItems.is_curse(t))
	d.echoes = []
	return d


func _init() -> void:
	GameData.load_all()
	_test_stock()
	_test_prices()
	_test_describe()
	_test_buy_equip_sell()
	_test_effects()
	_test_temple()
	_test_save_load()
	_test_succession()
	_test_bot()
	_test_high_gen()
	print("%d checks, %d failures" % [checks, failures])
	print("ALL PASS" if failures == 0 else "TESTS FAILED")
	quit(1 if failures > 0 else 0)


func _test_stock() -> void:
	var d := _fresh()
	d.world.visit("hearthmere")
	_check(GameItems.shops_here(d) == ["forge", "store", "temple"], "hearthmere has forge, store, temple")
	for s in ["forge", "store", "temple"]:
		var st := GameItems.stock(d, s)
		_check(not st.is_empty(), "hearthmere %s has stock" % s)
		for id in st:
			var it := GameItems.item_def(id)
			_check(it["shop"] == s, "%s sold by its own shop" % id)
			_check(int(it["tier"]) <= 1, "%s within tier 1" % id)
			_check(not it.get("unique", false), "%s not unique" % id)
			if s == "forge":
				_check(it["slot"] in ["weapon", "armor"], "forge sells weapons and armour")
			else:
				_check(it["slot"] == "trinket", "%s sells trinkets" % s)
	d.world.visit("kingshold")
	var forge3 := GameItems.stock(d, "forge")
	_check("mithril_blade" in forge3 and "plate_armor" in forge3, "kingshold forge sells tier 3")
	_check("sunblade" not in forge3 and "dragonscale_mail" not in forge3, "unique gear never for sale")
	d.world.visit("ironford")
	_check(GameItems.stock(d, "temple").is_empty(), "ironford has no temple wares")
	_check("steel_sword" in GameItems.stock(d, "forge") and "mithril_blade" not in GameItems.stock(d, "forge"), "ironford forge tier 2")
	d.world.visit("whisperwood")
	_check(GameItems.shops_here(d).is_empty(), "no shops in the wilds")
	for id in GameData.items:
		if GameData.items[id].get("unique", false):
			for town in ["hearthmere", "ironford", "kingshold", "brinehaven"]:
				d.world.visit(town)
				_check(not GameItems.sold_here(d, id), "%s not sold in %s" % [id, town])


func _test_prices() -> void:
	var d := _fresh()
	var p1 := GameItems.price(d, "iron_sword")
	_check(p1 == 50, "iron sword costs 50 at gen 1 (got %d)" % p1)
	var s1 := GameItems.sell_price(d, "iron_sword")
	_check(s1 == int(round(50.0 * float(GameData.bal("sell_fraction")))), "sell price is the sell fraction")
	_check(s1 < p1, "selling pays less than buying")
	d.gen = 300
	var p300 := GameItems.price(d, "iron_sword")
	_check(p300 == int(round(50.0 * GameData.enemy_scale(300))), "price scales with generation (gen 300: %d)" % p300)
	_check(p300 > p1 * 10, "gen 300 prices are much higher")
	_check(GameItems.sell_price(d, "iron_sword") < p300, "gen 300 sell < buy")
	print("  iron sword: gen 1 %dg (sells %dg), gen 300 %dg (sells %dg); cleanse gen1 %dg" % [p1, s1, p300, GameItems.sell_price(d, "iron_sword"), GameItems.cleanse_price(_fresh())])
	d.gen = 1
	d.heir.inventory.append("silver_tongue_brooch")
	GameItems.equip(d, "silver_tongue_brooch")
	_check(GameItems.price(d, "iron_sword") == int(round(50.0 * 0.85)), "persuasion lowers prices")
	d.heir.traits.append("__haggler")
	GameData.traits["__haggler"] = {"id": "__haggler", "name": "Haggler", "category": "acquired", "effects": [{"stat": "persuasion", "value": 2.0}]}
	_check(GameItems.price(d, "iron_sword") == int(round(50.0 * (1.0 - float(GameData.bal("shop_persuasion_cap"))))), "persuasion is capped")
	_check(GameItems.sell_price(d, "iron_sword") < GameItems.price(d, "iron_sword"), "no buy/sell profit even at the persuasion cap")
	d.heir.traits.erase("__haggler")
	GameData.traits.erase("__haggler")
	GameItems.unequip(d, "trinket")
	d._add_echo("infamy", "test", "test", 0.3)
	_check(GameItems.price(d, "iron_sword") == int(round(50.0 * 1.3)), "infamy raises prices")
	_check(GameItems.sell_price(d, "iron_sword") == int(round(50.0 * float(GameData.bal("sell_fraction")) / 1.3)), "infamy lowers what merchants pay")


func _test_describe() -> void:
	_check(GameItems.describe("iron_sword") == "+10% damage", "describe iron sword: " + GameItems.describe("iron_sword"))
	_check(GameItems.describe("hunting_bow") == "+6% damage, +3% crit", "describe hunting bow: " + GameItems.describe("hunting_bow"))
	_check(GameItems.describe("warhammer") == "+26% damage, -3% dodge", "describe warhammer: " + GameItems.describe("warhammer"))
	_check(GameItems.effect_text("max_hp", 0.025) == "+2.5% max HP", "fractional percent: " + GameItems.effect_text("max_hp", 0.025))
	_check(GameItems.effect_text("odd_stat", 0.1) == "+10% odd stat", "unknown stat falls back to its id")
	for id in GameData.items:
		_check(GameItems.describe(id) != "" and not ("_" in GameItems.describe(id)), "every item describes cleanly: %s -> %s" % [id, GameItems.describe(id)])


func _test_buy_equip_sell() -> void:
	var d := _fresh()
	var h := d.heir
	h.equipment = {"weapon": "", "armor": "", "trinket": ""}
	h.inventory = []
	h.gold = 1000
	var msg := GameItems.buy(d, "iron_sword")
	_check(h.equipment["weapon"] == "iron_sword", "buying into an empty slot equips it (%s)" % msg)
	_check(h.gold == 950, "gold spent on the sword")
	_check(not ("iron_sword" in h.inventory), "equipped item is not also in the pack")
	msg = GameItems.buy(d, "oak_staff")
	_check(h.equipment["weapon"] == "iron_sword" and "oak_staff" in h.inventory, "second weapon goes to the pack (%s)" % msg)
	var g := h.gold
	GameItems.buy(d, "iron_sword")
	_check(h.gold == g and h.inventory.count("iron_sword") == 0, "cannot buy what is already owned")
	GameItems.buy(d, "steel_sword")
	_check(h.gold == g and not GameItems.owns(h, "steel_sword"), "tier 2 not sold in a tier 1 town")
	GameItems.buy(d, "sunblade")
	_check(h.gold == g and not GameItems.owns(h, "sunblade"), "unique not sold")
	h.gold = 10
	GameItems.buy(d, "leather_armor")
	_check(h.gold == 10 and not GameItems.owns(h, "leather_armor"), "cannot buy without the gold")
	h.gold = g
	msg = GameItems.equip(d, "oak_staff")
	_check(h.equipment["weapon"] == "oak_staff" and "iron_sword" in h.inventory and not ("oak_staff" in h.inventory), "equip swaps with the pack (%s)" % msg)
	msg = GameItems.unequip(d, "weapon")
	_check(h.equipment["weapon"] == "" and "oak_staff" in h.inventory, "unequip moves to the pack (%s)" % msg)
	_check(GameItems.unequip(d, "weapon") == "Nothing is worn there.", "unequip empty slot is refused")
	g = h.gold
	var sp := GameItems.sell_price(d, "oak_staff")
	msg = GameItems.sell(d, "oak_staff")
	_check(h.gold == g + sp and not GameItems.owns(h, "oak_staff"), "selling pays and removes (%s)" % msg)
	g = h.gold
	GameItems.sell(d, "oak_staff")
	_check(h.gold == g, "cannot sell what is not in the pack")
	d.world.visit("whisperwood")
	GameItems.sell(d, "iron_sword")
	_check(h.gold == g and "iron_sword" in h.inventory, "no selling in the wilds")
	GameItems.equip(d, "iron_sword")
	_check(h.equipment["weapon"] == "iron_sword", "equipping works anywhere")
	h.full_heal()
	var full := h.max_hp()
	h.inventory.append("ring_of_vigor")
	GameItems.equip(d, "ring_of_vigor")
	_check(h.max_hp() > full and h.hp == h.max_hp(), "a healthy heir stays at full HP when max HP rises")
	h.hp = int(h.max_hp() / 2)
	GameItems.unequip(d, "trinket")
	_check(h.hp >= 1 and h.hp <= h.max_hp(), "HP stays within bounds after unequip")
	# Shop wares that are not gear go in the pack and are never worn.
	d.world.visit("hearthmere")
	GameData.items["__trail_map"] = {"id": "__trail_map", "name": "Trail Map", "slot": "", "tier": 1, "shop": "store", "price": 30, "effects": [{"stat": "luck", "value": 0.5}]}
	var luck := h.trait_total("luck")
	msg = GameItems.buy(d, "__trail_map")
	_check("__trail_map" in h.inventory and not h.equipment.has(""), "a non-gear ware stays in the pack (%s)" % msg)
	_check(_near(h.trait_total("luck"), luck), "a non-gear ware in the pack has no effect")
	GameItems.equip(d, "__trail_map")
	_check("__trail_map" in h.inventory and not h.equipment.has(""), "a non-gear ware cannot be worn")
	GameData.items.erase("__trail_map")
	h.inventory.erase("__trail_map")


func _test_effects() -> void:
	var d := _fresh()
	var h := d.heir
	h.equipment = {"weapon": "", "armor": "", "trinket": ""}
	h.inventory = ["mithril_blade", "plate_armor", "archmage_vestments", "band_of_the_fox", "lucky_charm", "ring_of_vigor", "amulet_of_focus", "archmage_staff"]
	var atk := h.attack_power()
	var mag := h.magic_power()
	var def := h.defense()
	var hp := h.max_hp()
	var mp := h.max_mp()
	var dodge := h.dodge_chance()
	var crit := h.crit_chance()
	GameItems.equip(d, "mithril_blade")
	_check(h.attack_power() > atk * 1.3, "mithril blade raises attack (%.1f -> %.1f)" % [atk, h.attack_power()])
	GameItems.equip(d, "archmage_staff")
	_check(h.magic_power() > mag * 1.3 and _near(h.attack_power(), atk), "staff raises magic, sword's bonus gone")
	_check(h.max_mp() > mp, "archmage staff raises max MP")
	GameItems.equip(d, "plate_armor")
	_check(h.defense() > def * 1.3, "plate raises defense (%.1f -> %.1f)" % [def, h.defense()])
	_check(h.max_hp() > hp, "plate raises max HP")
	_check(h.dodge_chance() < dodge, "plate costs dodge")
	GameItems.equip(d, "band_of_the_fox")
	var d2 := h.dodge_chance()
	GameItems.unequip(d, "armor")
	_check(h.dodge_chance() > dodge and h.crit_chance() > crit, "band of the fox raises dodge and crit")
	GameItems.equip(d, "lucky_charm")
	_check(_near(h.crit_chance() - crit, 0.03, 0.0005), "lucky charm adds 3% crit")
	GameItems.equip(d, "ring_of_vigor")
	_check(h.max_hp() > hp, "ring of vigor raises max HP")
	GameItems.equip(d, "amulet_of_focus")
	_check(h.max_mp() > mp, "amulet raises max MP")
	_check(d2 > 0.0, "dodge measured")


func _test_temple() -> void:
	var d := _fresh()
	var h := d.heir
	h.gold = 100000
	h.traits.append_array(["cursed", "blood_debt"])
	h.dormant.append("fae_contract")
	var curses := GameItems.curses_on(h)
	_check(curses == ["cursed", "blood_debt", "fae_contract"], "curses listed, expressed first: %s" % str(curses))
	var hp_cursed := h.max_hp()
	var c0 := GameItems.cleanse_price(d)
	_check(c0 == int(GameData.bal("cleanse_cost")), "first cleanse at base price (%d)" % c0)
	var msg := GameItems.cleanse(d, "blood_debt")
	_check(not ("blood_debt" in h.traits) and not ("blood_debt" in h.dormant), "blood debt lifted entirely (%s)" % msg)
	_check(h.max_hp() > hp_cursed, "lifting blood debt restores max HP")
	_check(h.gold == 100000 - c0, "cleansing charged")
	var c1 := GameItems.cleanse_price(d)
	_check(c1 > c0 and GameItems.temple_uses(d, "cleanse") == 1, "second cleanse costs more (%d -> %d)" % [c0, c1])
	GameItems.cleanse(d, "fae_contract")
	_check(not ("fae_contract" in h.dormant), "dormant curse lifted")
	var g := h.gold
	GameItems.cleanse(d, "warrior_blood")
	_check(h.gold == g, "cannot cleanse a non-curse")
	d.world.visit("ironford")
	GameItems.cleanse(d, "cursed")
	_check("cursed" in h.traits and h.gold == g, "no cleansing without a temple")
	GameItems.pray(d)
	_check(h.gold == g, "no prayer without a temple")
	d.world.visit("hearthmere")
	GameItems.cleanse(d, "cursed")
	_check(not ("cursed" in h.traits), "the 'cursed' mark can be cleansed")
	h.gold = 0
	h.traits.append("werewolf_curse")
	GameItems.cleanse(d, "werewolf_curse")
	_check("werewolf_curse" in h.traits, "cleansing needs the gold")
	h.gold = 100000
	h.fate_value = 0.15
	var p0 := GameItems.prayer_price(d)
	msg = GameItems.pray(d)
	_check(_near(h.fate_value, 0.15 - float(GameData.bal("prayer_fate_drop"))), "prayer lowers fate (%s)" % msg)
	var p1 := GameItems.prayer_price(d)
	_check(p1 > p0, "prayer price escalates (%d -> %d)" % [p0, p1])
	for i in 20:
		GameItems.pray(d)
	_check(_near(h.fate_value, float(GameData.bal("fate_min"))), "fate never drops below fate_min (%.4f)" % h.fate_value)
	_check(not GameItems.can_pray(d), "cannot pray at the floor")
	g = h.gold
	GameItems.pray(d)
	_check(h.gold == g, "no charge for a refused prayer")
	_check(GameItems.temple_uses(d, "prayer") >= 2, "prayers counted")


func _roundtrip(d: GameDynasty) -> GameDynasty:
	var parsed = JSON.parse_string(JSON.stringify(d.to_dict()))
	return GameDynasty.from_dict(parsed)


func _test_save_load() -> void:
	var d := _fresh()
	var h := d.heir
	h.gold = 5000
	h.equipment = {"weapon": "", "armor": "", "trinket": ""}
	h.inventory = []
	GameItems.buy(d, "iron_sword")
	GameItems.buy(d, "leather_armor")
	GameItems.buy(d, "oak_staff")
	GameItems.buy(d, "prayer_beads")
	h.fate_value = 0.18
	GameItems.pray(d)
	h.traits.append("cursed")
	GameItems.cleanse(d, "cursed")
	var g := _roundtrip(d)
	_check(g.heir.equipment == d.heir.equipment, "equipment survives save/load")
	_check(g.heir.inventory == d.heir.inventory, "pack survives save/load")
	_check(g.heir.gold == d.heir.gold, "gold survives save/load")
	_check(GameItems.temple_uses(g, "prayer") == 1 and GameItems.temple_uses(g, "cleanse") == 1, "temple counts survive save/load")
	_check(GameItems.prayer_price(g) == GameItems.prayer_price(d) and GameItems.cleanse_price(g) == GameItems.cleanse_price(d), "temple prices survive save/load")
	_check(_near(g.heir.attack_power(), d.heir.attack_power()) and g.heir.max_hp() == d.heir.max_hp(), "derived stats match after load")
	_check(_near(g.heir.fate_value, d.heir.fate_value), "prayed fate value survives save/load")
	var old := d.to_dict()
	old.erase("shop_state")
	var g2 := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(old)))
	_check(g2.shop_state.is_empty() and GameItems.temple_uses(g2, "prayer") == 0, "old saves without shop state load")
	GameItems.pray(g2)
	_check(GameItems.temple_uses(g2, "prayer") == 1, "temple works after loading an old save")


func _test_succession() -> void:
	var d := _fresh()
	var h := d.heir
	h.gold = 5000
	h.equipment = {"weapon": "", "armor": "", "trinket": ""}
	h.inventory = []
	GameItems.buy(d, "iron_sword")
	GameItems.buy(d, "leather_armor")
	GameItems.buy(d, "copper_ring")
	GameItems.buy(d, "oak_staff")
	h.fate_value = 0.18
	GameItems.pray(d)
	GameItems.pray(d)
	var price_before := GameItems.prayer_price(d)
	d._die("old age")
	d.choose_heir(0)
	var c := d.heir
	_check(c != h, "a new heir")
	_check(c.equipment["weapon"] == "iron_sword" and c.equipment["armor"] == "leather_armor" and c.equipment["trinket"] == "copper_ring", "gear carries to the next heir")
	_check("oak_staff" in c.inventory, "the pack carries to the next heir")
	var bare := c.attack_power()
	GameItems.unequip(d, "weapon")
	_check(bare > c.attack_power(), "the inherited sword works for the new heir")
	GameItems.equip(d, "iron_sword")
	_check(GameItems.temple_uses(d, "prayer") == 0, "temple counts reset for a new heir")
	_check(GameItems.prayer_price(d) < price_before, "temple prices reset for a new heir")
	var g := _roundtrip(d)
	_check(g.heir.equipment == c.equipment, "inherited gear survives save/load")


func _test_bot() -> void:
	var d := _fresh("warrior")
	var h := d.heir
	h.equipment = {"weapon": "", "armor": "", "trinket": ""}
	h.inventory = []
	h.gold = 800
	d.world.visit("hearthmere")
	GameItems.bot_tick(d)
	_check(h.equipment["weapon"] != "" and h.equipment["armor"] != "", "bot buys a weapon and armour (%s)" % str(h.equipment))
	_check(GameItems.fighting_style(h) == "melee" and GameItems.item_def(h.equipment["weapon"])["effects"][0]["stat"] == "melee_damage", "warrior bot picks a melee weapon (%s)" % h.equipment["weapon"])
	_check(h.gold >= GameItems.bot_reserve(d), "bot keeps the potion reserve (%d >= %d)" % [h.gold, GameItems.bot_reserve(d)])
	h.gold = 20000
	d.world.visit("kingshold")
	var before: Dictionary = h.equipment.duplicate()
	GameItems.bot_tick(d)
	_check(int(GameItems.item_def(h.equipment["weapon"])["tier"]) == 3, "bot upgrades to tier 3 in Kingshold (%s)" % str(h.equipment))
	_check(h.inventory.is_empty(), "bot sold what it outgrew (%s)" % str(h.inventory))
	h.inventory.append("oak_staff")
	GameItems.bot_tick(d)
	_check("oak_staff" in h.inventory, "bot leaves gear the player put in the pack")
	h.inventory.erase("oak_staff")
	_check(before["weapon"] != h.equipment["weapon"], "weapon changed")
	var gold_after := h.gold
	GameItems.bot_tick(d)
	_check(h.gold == gold_after, "bot does not churn once geared")
	h.traits.append("blood_debt")
	GameItems.bot_tick(d)
	_check(not ("blood_debt" in h.traits), "bot cleanses a curse at the temple")
	d.world.visit("ironford")
	h.traits.append("cursed")
	GameItems.bot_tick(d)
	_check("cursed" in h.traits, "bot cannot cleanse without a temple")
	var m := _fresh("mage")
	m.heir.equipment = {"weapon": "", "armor": "", "trinket": ""}
	m.heir.inventory = []
	m.heir.gold = 20000
	m.world.visit("kingshold")
	GameItems.bot_tick(m)
	_check(GameItems.fighting_style(m.heir) == "magic", "mage fights with spells")
	_check(m.heir.equipment["weapon"] == "archmage_staff", "mage bot picks the archmage staff (%s)" % str(m.heir.equipment))
	m.heir.inventory.append("staff_of_ages")
	m.world.visit("whisperwood")
	GameItems.bot_tick(m)
	_check(m.heir.equipment["weapon"] == "staff_of_ages" and "archmage_staff" in m.heir.inventory, "bot wears a better reward from the pack anywhere")
	# A few autopilot lives: gold gets spent and the house ends up geared.
	var a := GameDynasty.new_game(777, "", "warrior", GameData.traits_in(["bloodline"])[0], "human")
	var spent := 0
	for gen in 6:
		var guard := 0
		while a.state == "life" and guard < 5000:
			guard += 1
			var g0 := a.heir.gold
			GameItems.bot_tick(a)
			spent += maxi(0, g0 - a.heir.gold)
			GameBot.step(a)
		var e: Dictionary = a.heir.equipment
		print("  autopilot gen %d: L%d, gold %d, gear %s / %s / %s, pack %d" % [a.gen, a.heir.level, a.heir.gold, e["weapon"], e["armor"], e["trinket"], a.heir.inventory.size()])
		if a.state != "succession":
			break
		a.choose_heir(0)
	_check(spent > 0, "the autopilot spends gold on gear (%d)" % spent)
	_check(a.heir.equipment["weapon"] != "" and a.heir.equipment["armor"] != "", "the autopilot house is geared")


func _test_high_gen() -> void:
	var d := _fresh()
	var h := d.heir
	d.gen = 300
	h.gen = 300
	h.level = 5000
	h.full_heal()
	h.gold = 1000000
	h.equipment = {"weapon": "", "armor": "", "trinket": ""}
	h.inventory = []
	var atk := h.attack_power()
	GameItems.buy(d, "iron_sword")
	_check(_near(h.attack_power() / atk, 1.1, 0.001), "a gear bonus is the same share at level 5000")
	_check(h.hp == h.max_hp(), "full heir stays full at level 5000")
	var cp := GameItems.cleanse_price(d)
	_check(cp == int(round(float(GameData.bal("cleanse_cost")) * GameData.enemy_scale(300))), "cleanse scales with generation (%d)" % cp)
	var s := GameItems.sell_price(d, "iron_sword")
	_check(s > 0 and s < GameItems.price(d, "iron_sword"), "gen 300 resale sane")
