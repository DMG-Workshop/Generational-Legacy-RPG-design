## Gathering and crafting (roadmap item 44): the data and ways to break it; the family's stores (saved only when
## something is in them, loaded clean); what hunts and legends leave, on dice that never touch the dynasty's;
## salvaging gear into materials and essences; composing a piece (every reason it can be refused, the rarity from the
## essences, the quality previewed exactly, the same item as GameLoot builds); what is made works as gear; the workshop
## screen; and that the autopilot never gathers or makes anything.
## Run: godot --headless --path . -s res://tests/test_game_craft.gd
extends SceneTree

const HousePanel := preload("res://ui/play/house_panel.gd")
const CraftPanel := preload("res://ui/play/craft_panel.gd")

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	GameData.load_all()
	test_data()
	test_stores()
	test_gather()
	test_legend()
	test_salvage()
	test_plan()
	test_craft()
	test_use()
	await test_screen()
	test_autopilot()
	print("craft tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func dyn(seed_value: int = 5) -> GameDynasty:
	return GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")


func _stock(d: GameDynasty, mats: Dictionary, ess: Array = []) -> void:
	for m in mats:
		GameCraft.add_material(d, str(m), int(mats[m]))
	for a in ess:
		GameCraft.add_essence(d, str(a), 1)


# ---------------------------------------------------------------- data

func test_data() -> void:
	ok(GameCraft.validate().is_empty(), "the data is sound: %s" % str(GameCraft.validate()))
	var saved: Dictionary = GameCraft.data().duplicate(true)
	GameCraft.data()["drops"]["wolf"]["materials"][0]["material"] = "unobtainium"
	ok(not GameCraft.validate().is_empty(), "a drop of an unknown material is found")
	GameCraft._cache = saved.duplicate(true)
	GameCraft.data()["drops"]["wolf"]["essence"] = {"affix": "of_nothing", "chance": 0.1}
	ok(not GameCraft.validate().is_empty(), "an unknown essence is found")
	GameCraft._cache = saved.duplicate(true)
	GameCraft.data()["drops"].erase("ogre")
	ok(not GameCraft.validate().is_empty(), "a hunted creature with no drops is found")
	GameCraft._cache = saved.duplicate(true)
	GameCraft.data()["drops"]["nothing_at_all"] = {"materials": []}
	ok(not GameCraft.validate().is_empty(), "drops for a creature that does not exist are found")
	GameCraft._cache = saved.duplicate(true)
	GameCraft.data()["settings"]["rarity_by_essences"]["2"] = "mythic"
	ok(not GameCraft.validate().is_empty(), "a mythic that can be crafted is found")
	GameCraft._cache = saved.duplicate(true)
	GameCraft.data()["settings"]["rarity_by_essences"]["1"] = "rare"
	ok(not GameCraft.validate().is_empty(), "a rarity that needs the wrong number of affixes is found")
	GameCraft._cache = saved.duplicate(true)
	GameCraft.data()["settings"]["units_per_weight"] = 0
	ok(not GameCraft.validate().is_empty(), "units that cost nothing are found")
	GameCraft._cache = saved.duplicate(true)
	GameCraft.data()["drops"]["wolf"]["materials"][0]["chance"] = 3.0
	ok(not GameCraft.validate().is_empty(), "a chance above 1 is found")
	GameCraft._cache = saved.duplicate(true)
	for cid in GameCraft.data()["drops"]:
		GameCraft.data()["drops"][cid]["materials"] = GameCraft.data()["drops"][cid]["materials"].filter(func(m): return m["material"] != "mithril")
	ok(not GameCraft.validate().is_empty(), "a material nothing drops is found")
	GameCraft._cache = saved
	ok(GameCraft.validate().is_empty(), "and the data is put back")


# ---------------------------------------------------------------- stores

func test_stores() -> void:
	var d := dyn()
	ok(d.stores.is_empty() and not d.to_dict().has("stores"), "a new dynasty has no stores and saves none")
	GameCraft.add_material(d, "iron", 5)
	GameCraft.add_essence(d, "keen")
	ok(GameCraft.have(d, "iron") == 5 and GameCraft.essence_have(d, "keen") == 1 and d.to_dict().has("stores"), "stores hold what is added and are saved once there is something")
	GameCraft.add_material(d, "iron", -2)
	ok(GameCraft.have(d, "iron") == 3, "and what is taken")
	GameCraft.add_material(d, "iron", -50)
	ok(GameCraft.have(d, "iron") == 0 and not GameCraft.materials(d).has("iron"), "never below nothing, and an empty entry is dropped")
	GameCraft.add_essence(d, "keen", -1)
	ok(d.stores.is_empty() or not d.stores.has("essences"), "an empty table is dropped too")
	# save and load
	_stock(d, {"leather": 4, "bone": 2}, ["of_the_wolf", "of_the_wolf"])
	var d2 := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(GameCraft.have(d2, "leather") == 4 and GameCraft.essence_have(d2, "of_the_wolf") == 2, "the stores survive a save and load")
	ok(GameCraft.describe(d2).contains("4 leather") and GameCraft.describe(d2).contains("2 essence of wolf"), "and read well: %s" % GameCraft.describe(d2))
	# damaged and old saves
	var raw := d.to_dict()
	raw["stores"] = {"materials": {"iron": 3, "unobtainium": 9, "bone": -4, "leather": "lots"}, "essences": {"keen": 2, "of_nothing": 1}, "crafted": -3}
	var d3 := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(raw)))
	ok(GameCraft.have(d3, "iron") == 3 and GameCraft.have(d3, "unobtainium") == 0 and GameCraft.have(d3, "bone") == 0 and GameCraft.have(d3, "leather") == 0, "damaged entries are dropped on load")
	ok(GameCraft.essence_have(d3, "keen") == 2 and GameCraft.essence_have(d3, "of_nothing") == 0 and not d3.stores.has("crafted"), "and the good ones kept")
	raw["stores"] = "garbage"
	ok(GameDynasty.from_dict(JSON.parse_string(JSON.stringify(raw))).stores.is_empty(), "a stores value of the wrong type loads as none")
	var old := dyn().to_dict()
	old.erase("stores")
	ok(GameDynasty.from_dict(old).stores.is_empty(), "an old save with no stores loads")


# ---------------------------------------------------------------- gathering

func test_gather() -> void:
	var foes: Array = []
	for i in 600:
		foes.append({"id": "wolf", "name": "Wolf"})
	var d := dyn()
	var rng_before := d.rng.state
	var lines := GameCraft.after_search(d, foes)
	ok(lines.size() == 1 and lines[0].begins_with("Tess gathers "), "a hunt's dead leave one line: %s" % str(lines).left(80))
	ok(GameCraft.have(d, "leather") > 200 and GameCraft.have(d, "bone") > 100, "wolves leave leather and bone (%d, %d)" % [GameCraft.have(d, "leather"), GameCraft.have(d, "bone")])
	ok(GameCraft.essence_have(d, "of_the_wolf") > 10 and GameCraft.essence_have(d, "of_the_wolf") < 80, "and now and then the wolf itself: %d" % GameCraft.essence_have(d, "of_the_wolf"))
	ok(d.rng.state == rng_before, "the dynasty's dice are not touched")
	var again := dyn()
	GameCraft.after_search(again, foes)
	ok(again.stores == d.stores, "the same seed and hunt leave the same things")
	var other := dyn()
	other.total_hunts = 1
	GameCraft.after_search(other, foes)
	ok(other.stores != d.stores, "another hunt leaves other things")
	var dead := dyn()
	dead.state = "succession"
	ok(GameCraft.after_search(dead, foes).is_empty() and dead.stores.is_empty(), "nothing is gathered outside a life")
	var none := dyn()
	ok(GameCraft.after_search(none, [{"id": "sheep"}, {"id": "no_such"}]).is_empty() and none.stores.is_empty(), "farm animals and unknown foes leave nothing")
	# a foe's roll does not depend on the others
	var one := dyn()
	var three := dyn()
	GameCraft.after_search(one, [{"id": "wolf"}])
	GameCraft.after_search(three, [{"id": "wolf"}, {"id": "wolf"}, {"id": "wolf"}])
	ok(GameCraft.have(three, "leather") >= GameCraft.have(one, "leather"), "(a first foe's find is also found with more beside it)")
	# the screens' call: the whole search, then the made things, then the parts
	var s := dyn()
	var real: Array = []
	for i in 300:
		real.append({"id": "wolf", "name": "Wolf", "carries": []})
	s.loot = {"foes": real, "gold": 10, "item_chance": 0.0}
	var sl := GameLoot.search_dead(s)
	ok(GameCraft.have(s, "leather") > 0 and sl.any(func(x): return str(x).contains("gathers")), "search_dead gathers parts as well")


func test_legend() -> void:
	var d := dyn()
	d.slain_bosses["vaerthax"] = d.gen
	var lines := GameCraft.after_legend(d, "victory", [{"id": "vaerthax", "boss": true, "name": "Vaerthax"}])
	ok(lines.size() == 1 and GameCraft.have(d, "dragonscale") >= 2 and GameCraft.have(d, "gold") >= 1, "a slain legend always leaves its parts: %s" % GameCraft.describe(d))
	ok(d.flags.has("legend_gather_vaerthax") and GameCraft.after_legend(d, "victory", [{"id": "vaerthax", "boss": true}]).is_empty(), "once per legend")
	var f := dyn()
	ok(GameCraft.after_legend(f, "defeat", [{"id": "vaerthax", "boss": true}]).is_empty() and GameCraft.after_legend(f, "victory", [{"id": "wolf", "boss": false}]).is_empty(), "not on a defeat, nor for a plain foe")
	var g := dyn()
	g.slain_bosses["grimfang"] = g.gen
	GameCraft.after_legend(g, "victory", [{"id": "grimfang", "boss": true}])
	ok(GameCraft.essence_have(g, "mighty") == 1, "a legend can leave an essence for sure")


# ---------------------------------------------------------------- salvage

func test_salvage() -> void:
	var d := dyn()
	d.heir.inventory.append("iron_sword")
	var y := GameCraft.salvage_yield("iron_sword")
	ok(y["materials"].keys() == ["iron"] and int(y["materials"]["iron"]) >= 1 and y["essences"].is_empty(), "a shop sword gives its metal and no essence: %s" % str(y))
	var line := GameCraft.salvage(d, "iron_sword")
	ok(not d.heir.inventory.has("iron_sword") and GameCraft.have(d, "iron") == int(y["materials"]["iron"]) and line.contains("breaks up the Iron Sword"), "breaking it up takes it from the pack and stores the iron: %s" % line)
	# a made piece gives its affixes back as essences
	var id := "gen:rare:weapon:sword:steel:keen+of_the_wolf:-:0:5"
	d.heir.inventory.append(id)
	var y2 := GameCraft.salvage_yield(id)
	ok(y2["essences"] == ["keen", "of_the_wolf"] and y2["materials"].keys() == ["steel"], "a made piece gives its metal and its essences: %s" % str(y2))
	GameCraft.salvage(d, id)
	ok(GameCraft.essence_have(d, "keen") == 1 and GameCraft.essence_have(d, "of_the_wolf") == 1 and GameCraft.have(d, "steel") >= 1, "and they are stored")
	# a mythic gives its affixes and its metal, but there is no mythic essence
	var m := "gen:mythic:weapon:sword:starmetal:keen+of_the_wolf+arcane:dawnbringer:0:9"
	d.heir.inventory.append(m)
	GameCraft.salvage(d, m)
	ok(GameCraft.essence_have(d, "arcane") == 1 and GameCraft.have(d, "starmetal") >= 1 and not GameCraft.essences(d).has("dawnbringer"), "a mythic gives its affixes, never itself")
	# not worn, not absent, not unknown
	d.heir.equipment["armor"] = "chainmail"
	ok(GameCraft.salvage(d, "chainmail").contains("no Chainmail in the pack") and d.heir.equipment["armor"] == "chainmail", "worn gear is not broken up")
	ok(GameCraft.salvage(d, "plate_armor").contains("no Plate Armor"), "nor what is not carried")
	ok(GameCraft.salvage_yield("nothing_here").is_empty() and GameCraft.salvage_yield("gen:garbage").is_empty(), "an unknown item gives nothing")
	d.heir.inventory.append("gen:garbage")
	ok(GameCraft.salvage(d, "gen:garbage").contains("no gen:garbage") and d.heir.inventory.has("gen:garbage"), "and is left alone")
	# a heavier piece gives more
	ok(int(GameCraft.salvage_yield("plate_armor")["materials"]["steel"]) > int(GameCraft.salvage_yield("steel_sword")["materials"]["steel"]), "plate gives more steel than a sword")
	# it works anywhere, even over the carry limit
	var heavy := dyn()
	for i in 40:
		heavy.heir.inventory.append("plate_armor")
	ok(GameCarry.burdened(heavy.heir), "(a burdened heir)")
	GameCraft.salvage(heavy, "plate_armor")
	ok(heavy.heir.inventory.size() == 39, "a burdened heir can still break things up")
	var taint := dyn()
	taint.heir.inventory.append("notched_falchion")
	taint.heir.tainted_gear.append("notched_falchion")
	GameCraft.salvage(taint, "notched_falchion")
	ok(not taint.heir.tainted_gear.has("notched_falchion"), "a tainted bargain is forgotten with its last piece")


# ---------------------------------------------------------------- composing

func test_plan() -> void:
	var d := dyn()
	d.heir.gold = 100000
	ok(d.world.has_service("forge"), "(the starting town has a forge)")
	ok(not GameCraft.plan(d, "no_such_form", "iron", [])["ok"] and GameCraft.plan(d, "no_such_form", "iron", [])["why"].contains("No one can make"), "an unknown form is refused")
	ok(GameCraft.plan(d, "sword", "linen", [])["why"].contains("will not do for a sword"), "a material that does not fit the form is refused: %s" % GameCraft.plan(d, "sword", "linen", [])["why"])
	var short := GameCraft.plan(d, "sword", "iron", [])
	ok(not short["ok"] and short["why"].contains("Not enough iron"), "short of material is refused: %s" % short["why"])
	_stock(d, {"iron": 20, "steel": 20, "linen": 20})
	var p := GameCraft.plan(d, "sword", "iron", [])
	ok(p["ok"] and p["why"] == "" and p["item"]["name"] == "Iron Sword" and int(p["units"]) >= 1 and int(p["fee"]) >= 1, "with the material it is planned: %s, %d units, %d gold" % [p["item"]["name"], p["units"], p["fee"]])
	ok(GameCraft.have(d, "iron") == 20 and d.heir.gold == 100000, "planning spends nothing")
	ok(p["id"] == GameLoot.make_id("common", "weapon", "sword", "iron", [], "", GameLoot.grade_of(d.gen), p["quality"]) and GameLoot.build(p["id"]) == p["item"], "the plan is the item GameLoot builds")
	# essences
	ok(GameCraft.plan(d, "sword", "iron", ["keen"])["why"].contains("no essence of keen") or GameCraft.plan(d, "sword", "iron", ["keen"])["why"].contains("There is no essence"), "an essence not in the stores is refused: %s" % GameCraft.plan(d, "sword", "iron", ["keen"])["why"])
	_stock(d, {}, ["keen", "of_the_wolf", "arcane", "mighty", "of_the_owl", "of_the_dawn"])
	ok(GameCraft.plan(d, "sword", "iron", ["keen"])["item"]["rarity"] == "fine", "one essence makes a fine piece")
	ok(GameCraft.plan(d, "sword", "iron", ["keen", "of_the_wolf"])["item"]["rarity"] == "rare", "two make a rare one")
	ok(GameCraft.plan(d, "sword", "iron", ["keen", "of_the_wolf", "arcane"])["item"]["rarity"] == "legendary", "three make a legendary one")
	ok(GameCraft.plan(d, "sword", "iron", ["keen", "of_the_wolf", "arcane", "mighty"])["why"].contains("no more than 3"), "four are refused")
	ok(GameCraft.plan(d, "sword", "iron", ["keen", "keen"])["why"].contains("will not take"), "the same essence twice is refused")
	ok(GameCraft.plan(d, "sword", "iron", ["of_the_owl"])["why"].contains("will not take"), "an essence that needs a better material is refused (the owl wants tier 2): %s" % GameCraft.plan(d, "sword", "iron", ["of_the_owl"])["why"])
	ok(GameCraft.plan(d, "sword", "steel", ["of_the_owl"])["ok"], "and is taken by steel")
	ok(GameCraft.plan(d, "ring", "iron", ["mighty"]).get("why", "x").contains("will not take") or GameCraft.plan(d, "ring", "iron", ["mighty"]).get("ok", true) == false, "a weapon essence does not go in a ring")
	ok(not GameCraft.plan(d, "ring", "iron", ["of_the_dawn"])["ok"], "a tier 3 essence needs a tier 3 material")
	# the forge, the fee, the carry limit
	var poor := dyn()
	_stock(poor, {"iron": 20})
	poor.heir.gold = 0
	ok(GameCraft.plan(poor, "sword", "iron", [])["why"].contains("fee"), "no gold is refused: %s" % GameCraft.plan(poor, "sword", "iron", [])["why"])
	var far := dyn()
	far.heir.gold = 10000
	_stock(far, {"iron": 20})
	GameCraft.data()["settings"]["needs_service"] = "no_such_service"
	ok(GameCraft.plan(far, "sword", "iron", [])["why"].contains("no forge"), "where there is no forge it is refused")
	GameCraft._cache = {}
	var full := dyn()
	full.heir.gold = 10000
	_stock(full, {"steel": 40})
	while GameCarry.room(full.heir) > 3.0:
		full.heir.inventory.append("plate_armor")
	ok(GameCraft.plan(full, "warhammer", "steel", [])["why"].contains("could not carry"), "a piece that would not fit in the pack is refused before anything is spent: %s" % GameCraft.plan(full, "warhammer", "steel", [])["why"])
	ok(GameCraft.have(full, "steel") == 40, "(and nothing was spent)")
	ok(GameCraft.materials_for("sword").has("iron") and not GameCraft.materials_for("sword").has("linen") and GameCraft.materials_for("robe").has("silk"), "forms list the materials that fit them")
	ok(GameCraft.essences_for("sword", "iron").has("keen") and not GameCraft.essences_for("sword", "iron").has("sturdy"), "and the essences that fit them")


func test_craft() -> void:
	var d := dyn()
	d.heir.gold = 1000
	_stock(d, {"steel": 20}, ["keen", "of_the_wolf"])
	var p := GameCraft.plan(d, "sword", "steel", ["keen", "of_the_wolf"])
	var gold := d.heir.gold
	var line := GameCraft.craft(d, "sword", "steel", ["keen", "of_the_wolf"])
	ok(d.heir.inventory.has(p["id"]) and line.contains("makes a Keen Steel Sword of the Wolf"), "making it puts exactly the planned piece in the pack: %s" % line)
	ok(GameCraft.have(d, "steel") == 20 - int(p["units"]) and GameCraft.essence_have(d, "keen") == 0 and GameCraft.essence_have(d, "of_the_wolf") == 0 and d.heir.gold == gold - int(p["fee"]), "and spends the steel, the essences and the fee")
	ok(int(d.stores.get("crafted", 0)) == 1, "and counts it")
	ok(GameCraft.craft(d, "sword", "steel", ["keen"]).contains("no essence"), "making what cannot be made says why and spends nothing")
	# the quality is previewed exactly and moves with level and traits
	var q1 := dyn()
	var q2 := dyn()
	q2.heir.level = 90
	ok(GameCraft.quality(q2) > GameCraft.quality(q1) or GameCraft.quality(q2) >= 5, "a higher level makes better pieces (%d against %d)" % [GameCraft.quality(q2), GameCraft.quality(q1)])
	var q3 := dyn()
	q3.heir.traits.append("artificer")
	ok(GameCraft.quality(q3) >= GameCraft.quality(q1) + 2, "a Craft quality trait adds to it (%d against %d)" % [GameCraft.quality(q3), GameCraft.quality(q1)])
	var big := dyn()
	big.heir.level = 400
	big.heir.traits.append("artificer")
	ok(GameCraft.quality(big) == GameLoot.QUALITY_MAX, "and it never passes the top quality")
	var pre := GameCraft.quality(d)
	d.heir.gold = 1000
	_stock(d, {"iron": 10})
	var made := GameCraft.plan(d, "sword", "iron", [])
	GameCraft.craft(d, "sword", "iron", [])
	ok(int(GameLoot.parse(made["id"])["quality"]) == int(made["quality"]) and int(made["quality"]) == pre, "the quality previewed is the quality of the piece (%d)" % pre)
	ok(int(GameLoot.parse(str(d.heir.inventory.back()))["quality"]) == pre, "and of the piece that was made")
	# grade follows the world
	var late := dyn()
	late.gen = 200
	late.heir.gold = 10000
	_stock(late, {"iron": 10})
	ok(int(GameLoot.parse(GameCraft.plan(late, "sword", "iron", [])["id"])["grade"]) == GameLoot.grade_of(200) and GameLoot.grade_of(200) > 0, "a made piece takes the world's grade, as a drop does")
	# the dynasty's dice are not touched
	var r := dyn()
	r.heir.gold = 1000
	_stock(r, {"iron": 10})
	var before := r.rng.state
	GameCraft.craft(r, "sword", "iron", [])
	ok(r.rng.state == before, "crafting draws nothing from the dynasty's dice")


func test_use() -> void:
	var d := dyn()
	d.heir.gold = 1000
	_stock(d, {"steel": 20}, ["mighty"])
	GameCraft.craft(d, "sword", "steel", ["mighty"])
	var id := str(d.heir.inventory.back())
	ok(GameItems.slot_of(id) == "weapon" and GameFeats.weapon_kind(id) == "blade" and GameItems.sell_price(d, id) > 0, "a made sword is a blade, and worth gold")
	var before := d.heir.trait_total("melee_damage")
	GameItems.equip(d, id)
	ok(d.heir.trait_total("melee_damage") > before, "and wearing it adds its effects")
	ok(GameCraft.salvage_yield(id)["essences"] == ["mighty"], "and breaking it up gives the essence back")


# ---------------------------------------------------------------- the screen

func _find(n: Node, name: String) -> Node:
	if n.name == name:
		return n
	for c in n.get_children():
		var f := _find(c, name)
		if f != null:
			return f
	return null


func _buttons(n: Node, text: String) -> Array:
	var out: Array = []
	if n is Button and (n as Button).text == text:
		out.append(n)
	for c in n.get_children():
		out.append_array(_buttons(c, text))
	return out


func test_screen() -> void:
	var d := dyn()
	d.heir.gold = 1000
	_stock(d, {"iron": 12, "steel": 12}, ["keen"])
	d.heir.inventory.append("iron_sword")
	d.heir.inventory.append("gen:rare:weapon:sword:steel:keen+of_the_wolf:-:0:5")
	var host := Control.new()
	root.add_child(host)
	var house: Control = HousePanel.new()
	house.dynasty = d
	host.add_child(house)
	await _frames(3)
	var open := _find(house, "Workshop") as Button
	ok(open != null, "the House panel has a Workshop button")
	open.pressed.emit()
	await _frames(3)
	var panel: Control = null
	for c in host.get_children():
		if c.get_script() == CraftPanel:
			panel = c
	ok(panel != null, "it opens the workshop over the house")
	if panel == null:
		host.queue_free()
		return
	var make := _find(panel, "MakeButton") as Button
	ok(make != null and not make.disabled, "with iron in the stores the Make button is ready")
	# choose an essence and make a fine sword
	var form_pick := _find(panel, "FormPick") as OptionButton
	ok(form_pick != null and form_pick.item_count == GameLoot.data()["forms"].size(), "every form can be chosen")
	var ess := _find(panel, "EssencePick0") as OptionButton
	ok(ess != null and ess.item_count == 2, "the one essence owned is offered (and 'No essence')")
	ess.select(1)
	ess.item_selected.emit(1)
	await _frames(3)
	var make2 := _find(panel, "MakeButton") as Button
	ok(make2 != null and not make2.disabled, "with an essence chosen it can still be made")
	var packed := d.heir.inventory.size()
	make2.pressed.emit()
	await _frames(3)
	ok(d.heir.inventory.size() == packed + 1 and GameCraft.essence_have(d, "keen") == 0 and int(d.stores.get("crafted", 0)) == 1, "pressing it makes the piece and spends the essence")
	ok(GameLoot.build(str(d.heir.inventory.back()))["rarity"] == "fine", "a fine piece, from one essence")
	# a form the stores cannot make says why
	var form_pick2 := _find(panel, "FormPick") as OptionButton
	for i in form_pick2.item_count:
		if form_pick2.get_item_text(i).begins_with("Scale Coat"):
			form_pick2.select(i)
			form_pick2.item_selected.emit(i)
	await _frames(3)
	var reason := _find(panel, "MakeReason") as Label
	ok(reason != null and (reason.text.contains("Not enough") or reason.text.contains("will not")) and (_find(panel, "MakeButton") as Button).disabled, "what cannot be made shows the reason as text, with the button off: %s" % (reason.text if reason else "none"))
	# salvage: a plain sword goes at once, a rare piece asks twice
	var salv: Array = _buttons(panel, "Break up")
	ok(salv.size() == 3, "the pack lists gear to break up (the plain sword, the rare piece, the new fine sword): %d" % salv.size())
	var iron_before := GameCraft.have(d, "iron")
	for b in salv:
		var row := (b as Button).get_parent()
		if row.get_child(0) is Label and (row.get_child(0) as Label).text.begins_with("Iron Sword"):
			(b as Button).pressed.emit()
			break
	await _frames(3)
	ok(not d.heir.inventory.has("iron_sword") and GameCraft.have(d, "iron") > iron_before - 12, "a plain piece breaks up on one tap")
	var rare := "gen:rare:weapon:sword:steel:keen+of_the_wolf:-:0:5"
	var rare_btn: Button = null
	for b in _buttons(panel, "Break up"):
		var row2 := (b as Button).get_parent()
		if row2.get_child(0) is Label and (row2.get_child(0) as Label).text.begins_with("Keen Steel Sword of the Wolf"):
			rare_btn = b
	ok(rare_btn != null, "(the rare piece is listed)")
	rare_btn.pressed.emit()
	await _frames(3)
	ok(d.heir.inventory.has(rare) and panel.confirm_salvage == rare and _buttons(panel, "Sure?").size() == 1, "a rare piece only asks the first time")
	(_buttons(panel, "Sure?")[0] as Button).pressed.emit()
	await _frames(3)
	ok(not d.heir.inventory.has(rare) and GameCraft.essence_have(d, "of_the_wolf") == 1 and GameCraft.essence_have(d, "keen") == 1, "and the second breaks it up, keeping its essences")
	host.queue_free()
	await _frames(2)


# ---------------------------------------------------------------- the autopilot

func test_autopilot() -> void:
	var classes := GameData.starting_ids(GameData.classes)
	var touched := 0
	for sd in 3:
		var d := GameDynasty.new_game(sd + 1, "", classes[sd % classes.size()], "faetouched", "human")
		for g in 3:
			GameBot.live_life(d)
			if not d.stores.is_empty():
				touched += 1
			if d.state != "succession":
				break
			GameBot.choose_best(d)
	ok(touched == 0, "an autopilot life gathers and makes nothing (the screens ask, the rules of a life do not)")
