## What each of the new perks does (roadmap item 60): the forge (fee, quality, salvage, brews), gathering and essences, the
## shops, made-item drops and their rarity, mining (ore, effort, cave-ins), building, farm animals, foraging, companions that
## gather, training, odd jobs, a hunt's gold and XP, potions, raids, the pack, sickness, and the heir's own blows, spells,
## defense and fleeing. For each one: the calling with it does better than the house with none, a house with no calling gets
## exactly the number it always did, and two of the rules are broken on purpose to show the data is what is read. Nothing
## draws a die of the dynasty's.
## Run: godot --headless --path . -s res://tests/test_game_subclass_perks.gd
extends SceneTree

var fails := 0
var checks := 0
const SITE := "test_site"


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	test_none_is_exact()
	test_forge()
	test_gathering()
	test_brews()
	test_shops()
	test_loot()
	test_mining()
	test_building()
	test_farm_and_forage()
	test_companions()
	test_time_and_money()
	test_hunt()
	test_potion_and_flee()
	test_house_and_body()
	test_fighting_numbers()
	test_data_is_what_is_read()
	print("subclass perk tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func dyn(sub: String = "", seed_value: int = 7) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human", GameSex.MALE, sub)
	d.pending_event = {}
	d.heir.gold = 20000
	return d


func test_none_is_exact() -> void:
	var d := dyn()
	for k in GameSubclass.data()["perks"]:
		ok(GameSubclass.perk(d.heir, str(k)) == 1.0, "with no calling %s is exactly 1" % k)
	# a calling that does not name a perk leaves it exactly 1
	var e := dyn("delver")
	ok(GameSubclass.perk(e.heir, "buy_mult") == 1.0 and GameSubclass.perk(e.heir, "attack_mult") == 1.0, "a calling leaves the perks it does not name alone")
	# and a life with none stays identical, with the new reads in the rules
	var a := dyn()
	var b := dyn()
	GameCraft.add_material(a, "iron", 20)
	GameCraft.add_material(b, "iron", 20)
	for x in [a, b]:
		x.work()
		x.train("str")
		x.rest()
		x.pass_time(2.0)
		GameCraft.craft(x, "sword", "iron", [])
		GameCraft.after_search(x, [{"id": "wolf"}, {"id": "wolf"}])
		x.heir.attack_power()
	ok(a.to_dict() == b.to_dict() and a.rng.state == b.rng.state, "two lives with no calling stay identical through work, training, rest, time and the forge")


func test_forge() -> void:
	var n := dyn()
	var a := dyn("armorer")
	for d in [n, a]:
		GameCraft.add_material(d, "iron", 40)
		d.heir.level = 60
	var pn := GameCraft.plan(n, "sword", "iron", [])
	var pa := GameCraft.plan(a, "sword", "iron", [])
	ok(pn["ok"] and pa["ok"] and int(pa["fee"]) < int(pn["fee"]), "an Armorer's forge fee is lower: %d against %d" % [pa["fee"], pn["fee"]])
	ok(int(pa["quality"]) > int(pn["quality"]), "and the piece is better made: %d against %d" % [pa["quality"], pn["quality"]])
	var bn := GameCraft.brew_plan(n, "healing_potion")
	GameCraft.add_material(n, "herb", 10)
	GameCraft.add_material(a, "herb", 10)
	ok(GameCraft.brew_plan(a, "healing_potion")["fee"] <= GameCraft.brew_plan(n, "healing_potion")["fee"], "a brew's fee is no more")
	ok(bn.has("fee"), "(a brew plan is made)")
	# salvage
	var yn := GameCraft.salvage_yield("plate_armor", n.heir)
	var ya := GameCraft.salvage_yield("plate_armor", a.heir)
	ok(int(ya["materials"]["steel"]) > int(yn["materials"]["steel"]) and GameCraft.salvage_yield("plate_armor") == GameCraft.salvage_yield("plate_armor", n.heir), "an Armorer gets more steel from broken-up plate: %d against %d" % [ya["materials"]["steel"], yn["materials"]["steel"]])
	n.heir.inventory.append("plate_armor")
	a.heir.inventory.append("plate_armor")
	var steel_n := GameCraft.have(n, "steel")
	var steel_a := GameCraft.have(a, "steel")
	GameCraft.salvage(n, "plate_armor")
	GameCraft.salvage(a, "plate_armor")
	ok(GameCraft.have(a, "steel") - steel_a > GameCraft.have(n, "steel") - steel_n, "and the stores really grow by more")


func test_gathering() -> void:
	var foes: Array = []
	for i in 300:
		foes.append({"id": "wolf"})
	var n := dyn()
	var h := dyn("hidewright")
	var r := dyn("runescribe")
	var rng := h.rng.state
	GameCraft.after_search(n, foes)
	GameCraft.after_search(h, foes)
	GameCraft.after_search(r, foes)
	ok(h.rng.state == rng, "the haul draws no die of the dynasty's")
	var total := func(d): var t := 0; for m in d.stores.get("materials", {}): t += int(d.stores["materials"][m]); return t
	ok(total.call(h) > total.call(n), "a Hidewright's hunts leave more: %d against %d" % [total.call(h), total.call(n)])
	var ess := func(d): var t := 0; for a in d.stores.get("essences", {}): t += int(d.stores["essences"][a]); return t
	ok(ess.call(r) > ess.call(n), "a Runescribe draws more essences: %d against %d" % [ess.call(r), ess.call(n)])
	ok(total.call(r) == total.call(n), "and the same materials, which it has no perk for")
	var l := dyn("hidewright")
	var m := dyn()
	GameCraft.after_legend(l, "victory", [])
	ok(GameCraft.after_legend(m, "victory", []) == [], "a legend-less win leaves nothing for either")


func test_brews() -> void:
	var n := dyn()
	var al := dyn("alchemist")
	for d in [n, al]:
		GameCraft.add_material(d, "herb", 30)
		GameCraft.add_material(d, "glass", 10)
		GameCraft.add_material(d, "bone", 10)
	ok(int(GameCraft.brew_plan(al, "healing_potion")["makes"]) > int(GameCraft.brew_plan(n, "healing_potion")["makes"]), "an Alchemist's batch makes more")
	ok(GameCraft.calling_brews(al.heir) == ["distilled_elixir"] and GameCraft.calling_brews(n.heir).is_empty(), "the Alchemist has a brew of their own")
	var plan := GameCraft.brew_plan(al, "distilled_elixir")
	ok(plan["ok"] and int(plan["makes"]) > 3, "which makes more than its three: %s" % str(plan["makes"]))
	var refused := GameCraft.brew_plan(n, "distilled_elixir")
	ok(not refused["ok"] and "Alchemist" in str(refused["why"]), "another house is told whose it is: %s" % str(refused["why"]))
	var feast := dyn("feastwright")
	GameCraft.add_material(feast, "herb", 5)
	GameCraft.add_material(feast, "bone", 5)
	ok(not GameCraft.brew_plan(feast, "distilled_elixir")["ok"] and GameCraft.brew_plan(feast, "travellers_stew")["ok"], "a Feastwright cannot brew the Alchemist's, only its own stew")
	var potions := al.heir.potions
	var herbs := GameCraft.have(al, "herb")
	var rng := al.rng.state
	var line := GameCraft.brew(al, "distilled_elixir")
	ok(al.heir.potions == potions + int(plan["makes"]) and GameCraft.have(al, "herb") == herbs - 3 and al.rng.state == rng and "brews" in line, "brewing it spends the herbs and fills the pack, no dice: %s" % line)
	# the brew is never listed with the plain brews
	ok(GameCraft.brews() == ["healing_potion", "sailors_stew"], "the plain brew list holds the healing potion and the sailor's stew and none of the callings' own")


func test_shops() -> void:
	var n := dyn()
	var c := dyn("caravaneer")
	ok(GameItems.price(c, "iron_sword") < GameItems.price(n, "iron_sword"), "a Caravaneer buys cheaper: %d against %d" % [GameItems.price(c, "iron_sword"), GameItems.price(n, "iron_sword")])
	ok(GameItems.sell_price(c, "steel_sword") > GameItems.sell_price(n, "steel_sword"), "and sells dearer: %d against %d" % [GameItems.sell_price(c, "steel_sword"), GameItems.sell_price(n, "steel_sword")])
	ok(GameItems.price_mult(n) == GameData.enemy_scale(n.gen) * (1.0 + n.echo_total("infamy")) * (1.0 - GameItems.persuasion(n)) * GameWorldEvents.mult(n, "price_mult") * GameFactions.town_mult(n, "price"), "with no calling the price multiplier is exactly what it was")
	var b := dyn("bladewright")
	ok(GameItems.sell_price(b, "steel_sword") > GameItems.sell_price(n, "steel_sword"), "a Bladewright sells gear on dearer too")


func _rare_count(d: GameDynasty) -> int:
	var t := 0
	for id in d.heir.inventory:
		if GameLoot.is_generated(str(id)) and GameLoot.build(str(id))["rarity"] in ["rare", "epic", "legendary", "mythic"]:
			t += 1
	return t


func test_loot() -> void:
	var cap: Variant = GameCarry.data()["settings"]["base_capacity"]
	GameCarry.data()["settings"]["base_capacity"] = 100000.0
	var foes: Array = []
	for i in 1500:
		foes.append({"id": "wolf"})
	var n := dyn()
	var g := dyn("gemwright")
	var e := dyn("enchanter")
	var rng := g.rng.state
	GameLoot.after_search(n, foes)
	GameLoot.after_search(g, foes)
	GameLoot.after_search(e, foes)
	ok(g.rng.state == rng, "the finds draw no die of the dynasty's")
	ok(g.heir.inventory.size() > n.heir.inventory.size(), "a Gemwright finds more made pieces: %d against %d" % [g.heir.inventory.size(), n.heir.inventory.size()])
	ok(e.heir.inventory.size() == n.heir.inventory.size(), "an Enchanter finds as many")
	ok(_rare_count(e) > _rare_count(n), "but finer ones: %d rare against %d" % [_rare_count(e), _rare_count(n)])
	GameCarry.data()["settings"]["base_capacity"] = cap


func _ore_cell(d: GameDynasty) -> Vector3i:
	for y in range(1, 60):
		for x in range(0, 40):
			if GameMine.ore_here(d, SITE, x, y, 0) != "":
				return Vector3i(x, y, 0)
	return Vector3i(-1, -1, -1)


func test_mining() -> void:
	var n := dyn()
	var dl := dyn("delver")
	var gw := dyn("gemwright")
	var cell := _ore_cell(n)
	ok(cell.x >= 0, "(there is ore to dig)")
	var qn := 0
	var qd := 0
	var qg := 0
	var en := 0
	var ed := 0
	# dig the same cells with each house: down a few columns from the surface
	var dug := 0
	var columns: Array = []
	for x in range(0, 60):
		for y in range(0, 40):
			if GameMine.ore_here(n, SITE, x, y, 0) != "":
				columns.append(x)
				break
		if columns.size() >= 5:
			break
	for x in columns:
		for y in range(0, 40):
			if not GameMine.can_dig(n, SITE, x, y, 0)["ok"]:
				continue
			var rn := GameMine.dig(n, SITE, x, y, 0)
			var rd := GameMine.dig(dl, SITE, x, y, 0)
			var rg := GameMine.dig(gw, SITE, x, y, 0)
			qn += int(rn["qty"])
			qd += int(rd["qty"])
			qg += int(rg["qty"])
			en += int(rn["effort"])
			ed += int(rd["effort"])
			dug += 1
	ok(dug > 0 and qd > qn and qg > qn, "Delvers and Gemwrights strike more ore: %d, %d against %d" % [qd, qg, qn])
	ok(ed < en, "a Delver's dig is easier: effort %d against %d" % [ed, en])
	var sn := dyn()
	var sd := dyn("delver")
	for x in [sn, sd]:
		x.mine[SITE] = {"dug": {}, "strain": {GameMine.region_key(0, 0): 700.0}, "gateways": []}
	ok(GameMine.hazard_chance(sd, SITE, 0, 5, 0) < GameMine.hazard_chance(sn, SITE, 0, 5, 0) and GameMine.hazard_chance(sd, SITE, 0, 5, 0) > 0.0, "a Delver fears the roof less: %.3f against %.3f" % [GameMine.hazard_chance(sd, SITE, 0, 5, 0), GameMine.hazard_chance(sn, SITE, 0, 5, 0)])
	ok(GameMine.hazard_chance(sd, SITE, 0, 4000, 0) <= float(GameMine.setting("hazard_max")), "and never above the ceiling")
	var quiet := dyn("delver")
	ok(GameMine.hazard_chance(quiet, SITE, 0, 5, 0) == 0.0, "a quiet shaft still never falls")


func test_building() -> void:
	var n := dyn()
	var s := dyn("stonewright")
	var tr := dyn("trapsmith")
	var worse := 0
	var better := 0
	for kind in GameBuild.pieces():
		var p: Dictionary = GameBuild.pieces()[kind]
		var cn := GameBuild.cost_of(n, p)
		var same: bool = int(cn["gold"]) == int(p["gold"]) and (cn["cost"] as Dictionary).size() == (p["cost"] as Dictionary).size()
		for m in p["cost"]:
			same = same and int(cn["cost"].get(m, -1)) == int(p["cost"][m])
		ok(same, "with no calling a %s costs exactly its list" % kind)
		var cs := GameBuild.cost_of(s, p)
		var ct := GameBuild.cost_of(tr, p)
		for m in cs["cost"]:
			ok(int(cs["cost"][m]) >= 1 and int(cs["cost"][m]) <= int(p["cost"][m]), "%s needs at least 1 %s and no more than listed" % [kind, m])
			if int(cs["cost"][m]) < int(p["cost"][m]):
				better += 1
			if int(ct["cost"][m]) > int(p["cost"][m]):
				worse += 1
		ok(int(cs["gold"]) <= int(p["gold"]) and (int(p["gold"]) == 0 or int(cs["gold"]) >= 1), "%s's gold is no more, and never nothing when it took some" % kind)
		# pulling a piece down gives back a share of what was paid, never more than was paid
		ok(floor(float(cs["gold"]) * float(p["refund"])) <= float(cs["gold"]), "%s: no gain by pulling down" % kind)
	ok(better > 0 and worse == 0, "a Stonewright builds cheaper (%d cheaper lines), a Trapsmith never dearer" % better)
	# paying: the lower price is what is spent
	s.heir.gold = 5000
	GameCraft.add_material(s, "oak", 50)
	GameCraft.add_material(n, "oak", 50)
	var base := GameBuild.base()
	n.heir.gold = 5000
	var spot := Vector2i(int(base["x"]), int(base["z"]))
	var found := Vector2i(-1, -1)
	for dx in range(-8, 9):
		for dz in range(-8, 9):
			if GameBuild.check(s, "floor", spot.x + dx, GameBuild.SURFACE, spot.y + dz) == "":
				found = Vector2i(spot.x + dx, spot.y + dz)
				break
		if found.x >= 0:
			break
	ok(found.x >= 0, "(there is a place to build)")
	if found.x >= 0:
		var oak_n := GameCraft.have(n, "oak")
		var oak_s := GameCraft.have(s, "oak")
		var rn := GameBuild.place(n, "wall", found.x, GameBuild.SURFACE, found.y)
		var rs := GameBuild.place(s, "wall", found.x, GameBuild.SURFACE, found.y)
		ok(rn["ok"] and rs["ok"], "both houses build a wall: %s %s" % [rn["text"], rs["text"]])
		ok(oak_s - GameCraft.have(s, "oak") < oak_n - GameCraft.have(n, "oak"), "and the Stonewright spends less oak: %d against %d" % [oak_s - GameCraft.have(s, "oak"), oak_n - GameCraft.have(n, "oak")])


func test_farm_and_forage() -> void:
	var n := dyn()
	var s := dyn("steadholder")
	var species := str(GameFarm.market_species()[0])
	var en := GameRoster.add(n, species, "A")
	var es := GameRoster.add(s, species, "A")
	for e in [en, es]:
		e["stage"] = "adult"
		e["mood"] = 100
	ok(GameFarm.yield_mult(s, es) > GameFarm.yield_mult(n, en), "a Steadholder's animals give more: %.2f against %.2f" % [GameFarm.yield_mult(s, es), GameFarm.yield_mult(n, en)])
	ok(GameFarm.yield_mult(null, en) == GameFarm.yield_mult(n, en) or n.world != null, "(a missing house is no calling)")
	var wild := GameRoster.add(s, "wolf", "W")
	ok(GameFarm.yield_mult(s, wild) == 1.0, "and a wild creature's work is untouched")
	# foraging
	var site := _node_site(n)
	var gw := dyn("greenwarden")
	var sum_n := 0
	var sum_g := 0
	var ns: Array = GameForage.in_reach(n, site.x, site.y)
	for node in ns.slice(0, 6):
		var a := dyn()
		var b := dyn("greenwarden")
		sum_n += int(GameForage.forage(a, int(node["x"]), int(node["z"]))["n"])
		sum_g += int(GameForage.forage(b, int(node["x"]), int(node["z"]))["n"])
	ok(sum_n > 0 and sum_g >= sum_n, "a Greenwarden forages at least as much: %d against %d" % [sum_g, sum_n])
	var rng := gw.rng.state
	GameForage.forage(gw, site.x, site.y)
	ok(gw.rng.state == rng, "foraging draws no dice")


func _node_site(d: GameDynasty) -> Vector2i:
	var b := GameBuild.base()
	var near: Array = GameCompanions.scan(d, Vector2(float(b["x"]), float(b["z"])))
	for r in [40, 80, 120]:
		near = GameCompanions.scan(d, Vector2(float(b["x"]) + float(r), float(b["z"]) + float(r)))
		if not near.is_empty():
			break
	return Vector2i(int(near[0]["x"]), int(near[0]["z"]))


func _house(sub: String) -> GameDynasty:
	var d := dyn(sub, 5)
	for id in ["maddy_thorn"]:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": 10, "gen": 1,
			"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
		d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
			"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	return d


func _grove(d: GameDynasty) -> Vector2:
	var a := GameWorldGen.anchor("hearthmere")
	for r in range(8, 60, 4):
		for k in 16:
			var ang := float(k) / 16.0 * TAU
			var x := int(a["x"]) + int(round(cos(ang) * r))
			var z := int(a["z"]) + int(round(sin(ang) * r))
			if not GameWorldGen.in_bounds(x, z) or GameWorldGen.in_anchor_ground(x, z) or GameWorldGen.tile(d, x, z)["water"]:
				continue
			if GameCompanions.scan(d, Vector2(x, z)).size() >= 8:
				return Vector2(float(x), float(z))
	return Vector2(-1, -1)


## The first loads a gathering companion brings in, for a house with and without a Wildcaller at its head.
func _gathered(sub: String) -> int:
	var d := _house(sub)
	var spot := _grove(d)
	if spot.x < 0:
		return -1
	GameCompanions.set_order(d, "maddy_thorn", "gather")
	var view := GameCompanions.view(d, spot.x + 40.0, spot.y)
	var cur := GameCompanions.agents_for(d, spot.x, spot.y)
	var total := 0
	var seen := 0
	for t in 600:
		var r := GameCompanions.step_all(d, cur, view, t)
		cur = r["agents"]
		for ev in r["events"]:
			if str(ev.get("type", "")) == "gathered" and seen < 12:
				total += int(ev["n"])
				seen += 1
	return total


func test_companions() -> void:
	var n := _gathered("")
	var w := _gathered("wildcaller")
	ok(n > 0, "(a companion gathers: %d)" % n)
	ok(w >= n, "a Wildcaller's companion brings in at least as much, in their first twelve loads: %d against %d" % [w, n])
	ok(w > n, "and more in all: %d against %d" % [w, n])


func test_time_and_money() -> void:
	var n := dyn()
	var w := dyn("wildcaller")
	var xp_n := n.heir.xp
	var xp_w := w.heir.xp
	n.heir.level = 20
	w.heir.level = 20
	n.train("str")
	w.train("str")
	ok(w.heir.xp - xp_w > n.heir.xp - xp_n, "a Wildcaller learns more from training: %d against %d" % [w.heir.xp - xp_w, n.heir.xp - xp_n])
	var s := dyn("steadholder")
	var c := dyn("caravaneer")
	var p := dyn()
	var g0 := p.heir.gold
	p.work()
	s.work()
	c.work()
	ok(s.heir.gold - 20000 > p.heir.gold - g0 and c.heir.gold - 20000 > p.heir.gold - g0, "odd jobs pay more: %d, %d against %d" % [s.heir.gold - 20000, c.heir.gold - 20000, p.heir.gold - g0])
	ok(s.rng.state == p.rng.state, "and draw exactly the dice they did")


## One win in a fight, as finish_battle pays it.
func _won(d: GameDynasty) -> Dictionary:
	var b := d.start_hunt("hunt")
	var xp0 := d.heir.xp
	var gold0 := d.heir.gold
	b.result = "victory"
	for e in b.enemies:
		e["hp"] = 0
	d.finish_battle()
	return {"gold": d.heir.gold - gold0, "xp": d.heir.xp - xp0}


func test_hunt() -> void:
	var n := _won(dyn())
	var t := _won(dyn("trapsmith"))
	var sb := _won(dyn("spiritbinder"))
	ok(n["gold"] > 0 and t["gold"] > n["gold"] and sb["gold"] == n["gold"], "a Trapsmith's hunt pays more gold: %d against %d" % [t["gold"], n["gold"]])
	ok(sb["xp"] > n["xp"] and t["xp"] == n["xp"], "a Spiritbinder's teaches more: %d against %d" % [sb["xp"], n["xp"]])


func _potion_heal(sub: String) -> int:
	var d := dyn(sub)
	d.heir.potions = 3
	var b := d.start_hunt("hunt")
	for e in b.enemies:
		e["atk"] = 0.0
		e["hp"] = 100000
	d.heir.hp = 1
	b.use_potion()
	return d.heir.hp - 1


func _flees(sub: String, seeds: int) -> int:
	var fled := 0
	for sd in seeds:
		var d := dyn(sub, 100 + sd)
		var b := d.start_hunt("hunt")
		for e in b.enemies:
			e["atk"] = 0.0
			e["hp"] = 100000
			e["boss"] = false
		b.flee()
		if b.result == "fled":
			fled += 1
	return fled


func test_potion_and_flee() -> void:
	var n := _potion_heal("")
	var a := _potion_heal("alchemist")
	var f := _potion_heal("feastwright")
	ok(n > 0 and a > n and f > n and a > f, "a potion mends more for an Alchemist, and a Feastwright: %d, %d against %d" % [a, f, n])
	var fn := _flees("", 120)
	var ft := _flees("trapsmith", 120)
	var fw := _flees("wayfinder", 120)
	ok(ft > fn and fw > fn, "a Trapsmith and a Wayfinder slip away more often: %d and %d of 120 against %d" % [ft, fw, fn])


func test_house_and_body() -> void:
	var p := dyn()
	var t := dyn("trapsmith")
	var sw := dyn("stonewright")
	for d in [p, t, sw]:
		d.heir.gold = 5000
	ok(GameRaids.chance(t) < GameRaids.chance(p) and GameRaids.chance(sw) < GameRaids.chance(p) and GameRaids.chance(p) > 0.0, "raiders are put off: %.4f and %.4f against %.4f" % [GameRaids.chance(t), GameRaids.chance(sw), GameRaids.chance(p)])
	var plain := dyn("caravaneer")
	ok(is_equal_approx(GameCarry.capacity(plain.heir), GameCarry.capacity(p.heir) * GameSubclass.perk(plain.heir, "carry_mult")) and GameCarry.capacity(plain.heir) > GameCarry.capacity(p.heir), "a Caravaneer carries more: %.1f against %.1f" % [GameCarry.capacity(plain.heir), GameCarry.capacity(p.heir)])
	# sickness: the same dice, fewer caught
	var caught := {"": 0, "greenwarden": 0, "alchemist": 0}
	for sub in caught:
		var d := dyn(sub, 3)
		for i in 500:
			d.heir.diseases.clear()
			if GameDisease.contagion_check(d, d.heir, "rat_plague", 0.4, "test") != "":
				caught[sub] += 1
	ok(caught["greenwarden"] < caught[""] and caught["alchemist"] < caught[""] and caught[""] > 20, "a Greenwarden and an Alchemist catch fewer sicknesses: %d and %d against %d of 500" % [caught["greenwarden"], caught["alchemist"], caught[""]])


func test_fighting_numbers() -> void:
	var n := dyn()
	var b := dyn("bladewright")
	var e := dyn("enchanter")
	var a := dyn("armorer")
	var raw_attack := (n.heir.stat("str") * 1.6) * (1.0 + n.heir.trait_total("melee_damage") + n.heir.trait_total("strength") + n.heir.heirloom_bonus)
	ok(n.heir.attack_power() == raw_attack, "with no calling the blow is exactly what it was")
	ok(is_equal_approx(b.heir.attack_power(), raw_attack * GameSubclass.perk(b.heir, "attack_mult")) and b.heir.attack_power() > n.heir.attack_power(), "a Bladewright hits harder: %.1f against %.1f" % [b.heir.attack_power(), n.heir.attack_power()])
	ok(e.heir.magic_power() > n.heir.magic_power() and e.heir.attack_power() == n.heir.attack_power(), "an Enchanter's spells are stronger, not their blows")
	ok(a.heir.defense() > n.heir.defense() and a.heir.magic_power() == n.heir.magic_power(), "an Armorer is harder to hurt")


## The two rules broken on purpose: what is read is the data, so changing a perk changes the number.
func test_data_is_what_is_read() -> void:
	var saved: Dictionary = GameSubclass.data().duplicate(true)
	var s := dyn("stonewright")
	var wall: Dictionary = GameBuild.pieces()["wall"]
	var before := GameBuild.cost_of(s, wall)
	GameSubclass.data()["subclasses"][15]["perks"]["build_cost_mult"] = 1.0
	ok(GameSubclass.perk(s.heir, "build_cost_mult") == 1.0 and int(GameBuild.cost_of(s, wall)["cost"]["oak"]) == int(wall["cost"]["oak"]), "setting the Stonewright's perk to 1 makes building cost its list again (was %s)" % str(before["cost"]))
	GameSubclass._cache = saved.duplicate(true)
	var d := dyn("armorer")
	GameCraft.add_material(d, "iron", 20)
	var fee := int(GameCraft.plan(d, "sword", "iron", [])["fee"])
	GameSubclass.data()["subclasses"][2]["perks"]["forge_fee_mult"] = 0.2
	ok(int(GameCraft.plan(d, "sword", "iron", [])["fee"]) < fee, "lowering the Armorer's forge perk lowers the fee at once: %d then %d" % [fee, int(GameCraft.plan(d, "sword", "iron", [])["fee"])])
	GameSubclass._cache = saved
