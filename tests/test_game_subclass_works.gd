## A calling's own works (roadmap item 60): the forty items only the twenty callings can make. Every work of every calling is
## made from its recipe at a forge (a town's, or the family's own at a part of the fee), by that calling alone, at its level,
## once if it is gear; every reason it cannot be made leaves everything as it was; what is made is gear that does what it says
## (and is wearable, with a kind and a look), travels through a save, and the workshop and the Chronicle's Subclass tab show
## it. The calling brews are the same. No dice of the dynasty's are drawn, and the shops sell none of it.
## Run: godot --headless --path . -s res://tests/test_game_subclass_works.gd
extends SceneTree

const CraftPanel := preload("res://ui/play/craft_panel.gd")
const HousePanel := preload("res://ui/play/house_panel.gd")
const ChroniclePanel := preload("res://ui/play/chronicle_panel.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const DIR := "user://test_subclass_works/"

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
	test_every_work()
	test_refusals()
	test_fee_and_forge()
	test_wearing()
	test_saving()
	test_breaks()
	await test_screens()
	print("subclass works tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func dyn(sub: String, level: int = 99) -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human", GameSex.MALE, sub)
	d.pending_event = {}
	d.heir.gold = 100000
	d.heir.level = level
	return d


func _stock(d: GameDynasty, recipe: Dictionary, times: int = 1) -> void:
	for m in recipe:
		GameCraft.add_material(d, str(m), int(recipe[m]) * times)


func _total(d: GameDynasty) -> int:
	var t := 0
	for m in d.stores.get("materials", {}):
		t += int(d.stores["materials"][m])
	return t


func test_every_work() -> void:
	var made := 0
	for s in GameSubclass.defs():
		var id := str(s["id"])
		for w in GameSubclass.works(id):
			var d := dyn(id)
			var recipe: Dictionary = GameData.items[w]["recipe"]["cost"]
			var plan := GameSubclass.work_plan(d, w)
			ok(not plan["ok"] and "short of" in str(plan["why"]).to_lower(), "%s: with an empty store it says what is short: %s" % [w, plan["why"]])
			_stock(d, recipe)
			plan = GameSubclass.work_plan(d, w)
			ok(plan["ok"] and int(plan["fee"]) >= 1 and plan["name"] == GameData.items[w]["name"], "%s can be made from its recipe" % w)
			var gold := d.heir.gold
			var mats := _total(d)
			var rng := d.rng.state
			var line := GameSubclass.make(d, w)
			var expect := 0
			for m in recipe:
				expect += int(recipe[m])
			ok(w in d.heir.inventory and d.heir.gold == gold - int(plan["fee"]) and _total(d) == mats - expect, "%s: made, paid for in materials and gold" % w)
			ok(d.rng.state == rng, "%s: no die of the dynasty's drawn" % w)
			ok(GameData.items[w]["name"] in line and s["name"] in line and d.journal.back() == line, "%s: the line says what and by whom: %s" % [w, line])
			ok(not GameSubclass.work_plan(d, w)["ok"] and "Already" in str(GameSubclass.work_plan(d, w)["why"]), "%s: a second one is refused while the first is held" % w)
			made += 1
	ok(made == 40, "all forty works were made (%d)" % made)


func test_refusals() -> void:
	# another calling, no calling, too low a level, no forge, no gold, no room: nothing changes
	var item := "wrights_edge"
	var recipe: Dictionary = GameData.items[item]["recipe"]["cost"]
	var level_needed := int(GameData.items[item]["recipe"]["min_level"])
	var cases := {
		"another calling": dyn("armorer"),
		"no calling": dyn(""),
		"too low a level": dyn("bladewright", level_needed - 1),
		"no gold": dyn("bladewright"),
		"no room": dyn("bladewright"),
		"no forge": dyn("bladewright"),
	}
	for k in cases:
		var d: GameDynasty = cases[k]
		_stock(d, recipe)
	cases["no gold"].heir.gold = 1
	cases["no forge"].world.location = "whisperwood"
	ok(not cases["no forge"].world.has_service("forge"), "(somewhere with no town forge)")
	var weight := GameItems.weight_of(item)
	cases["no room"].heir.inventory.append("plate_armor")
	cases["no room"].heir.inventory.append("plate_armor")
	cases["no room"].heir.inventory.append("plate_armor")
	var room: float = GameCarry.room(cases["no room"].heir)
	GameData.items["lead_weight"] = {"id": "lead_weight", "name": "Lead", "slot": "trinket", "tier": 1, "material": "iron", "weight": maxf(0.01, room - weight + 0.5), "effects": []}
	cases["no room"].heir.inventory.append("lead_weight")
	ok(not GameCarry.can_carry(cases["no room"].heir, item), "(a pack that is full)")
	var wants := {"another calling": "Bladewright", "no calling": "Bladewright", "too low a level": "level", "no gold": "Not enough gold", "no room": "carry", "no forge": "forge"}
	for k in cases:
		var d: GameDynasty = cases[k]
		var gold := d.heir.gold
		var mats := _total(d)
		var packed := d.heir.inventory.size()
		var p := GameSubclass.work_plan(d, item)
		var line := GameSubclass.make(d, item)
		ok(not p["ok"] and str(p["why"]) != "" and wants[k] in str(p["why"]), "%s: refused with a reason (%s)" % [k, p["why"]])
		ok(line == p["why"] and d.heir.gold == gold and _total(d) == mats and d.heir.inventory.size() == packed and item not in d.heir.inventory, "%s: nothing is spent or made" % k)
	# at the family's own forge there is no need for a town's
	var far: GameDynasty = cases["no forge"]
	ok(GameSubclass.work_plan(far, item, "home")["ok"] and GameSubclass.make(far, item, "home") != "" and item in far.heir.inventory, "the family's own forge needs no town forge")
	GameData.items.erase("lead_weight")
	# unknown things
	var d2 := dyn("bladewright")
	ok(not GameSubclass.work_plan(d2, "iron_sword")["ok"] and not GameSubclass.work_plan(d2, "nonesuch")["ok"], "an item that is nobody's work, or none, cannot be made")
	ok(GameSubclass.make(d2, "nonesuch") == GameSubclass.text("work_unknown"), "and says so")
	var dead := dyn("bladewright")
	_stock(dead, recipe)
	dead.state = "succession"
	ok(not GameSubclass.work_plan(dead, item)["ok"], "nothing is made outside a life")
	# a calling lost is a calling gone: the work cannot be made by one who changed
	var turn := dyn("bladewright")
	_stock(turn, recipe)
	GameSubclass.take(turn, "armorer")
	ok(not GameSubclass.work_plan(turn, item)["ok"], "one who has become an Armorer cannot make a Bladewright's work")
	# the calling brews
	var al := dyn("alchemist")
	var n := dyn("")
	for d in [al, n]:
		GameCraft.add_material(d, "herb", 5)
		GameCraft.add_material(d, "glass", 5)
	ok(GameCraft.brew_plan(al, "distilled_elixir")["ok"] and not GameCraft.brew_plan(n, "distilled_elixir")["ok"], "only an Alchemist brews the elixir")
	var before := n.heir.potions
	GameCraft.brew(n, "distilled_elixir")
	ok(n.heir.potions == before and _total(n) == 10, "and a refused brew makes and spends nothing")


func test_fee_and_forge() -> void:
	var item := "journeymans_cuirass"
	var recipe: Dictionary = GameData.items[item]["recipe"]["cost"]
	var arm := dyn("armorer")
	var other := dyn("armorer")
	_stock(arm, recipe)
	_stock(other, recipe)
	var base := float(GameData.items[item]["recipe"]["fee"])
	var town := GameSubclass.work_plan(arm, item)
	var home := GameSubclass.work_plan(arm, item, "home")
	ok(int(town["fee"]) == int(round(base * GameSubclass.perk(arm.heir, "forge_fee_mult"))), "an Armorer's fee is the recipe's, less the calling's cut: %d (of %d)" % [town["fee"], int(base)])
	ok(int(home["fee"]) == int(round(base * float(GameCraft.setting("home_fee_mult")) * GameSubclass.perk(arm.heir, "forge_fee_mult"))) and int(home["fee"]) < int(town["fee"]), "the family's forge charges the share: %d" % home["fee"])
	# the Smithy cuts it further
	other.house[GameHouse.SMITHY] = 3
	ok(int(GameSubclass.work_plan(other, item)["fee"]) < int(town["fee"]), "and a Smithy cuts it more")
	var gold := arm.heir.gold
	GameSubclass.make(arm, item, "home")
	ok(gold - arm.heir.gold == int(home["fee"]), "making it at home pays the home fee")


func test_wearing() -> void:
	for s in GameSubclass.defs():
		for w in GameSubclass.works(str(s["id"])):
			var d := dyn(str(s["id"]))
			var def: Dictionary = GameData.items[w]
			var slot := str(def["slot"])
			ok(slot in GameItems.SLOTS, "%s is gear for a slot" % w)
			_stock(d, def["recipe"]["cost"])
			GameSubclass.make(d, w)
			var before := {}
			for e in def["effects"]:
				before[e["stat"]] = d.heir.trait_total(str(e["stat"]))
			var line := GameItems.equip(d, w)
			ok(GameItems.equipped(d.heir, slot) == w, "%s can be worn: %s" % [w, line])
			for e in def["effects"]:
				ok(is_equal_approx(d.heir.trait_total(str(e["stat"])), float(before[e["stat"]]) + float(e["value"])), "%s adds its %s" % [w, e["stat"]])
			if slot == "weapon":
				ok(GameFeats.weapon_kind(w) != "", "%s has a weapon kind (%s)" % [w, GameFeats.weapon_kind(w)])
			ok(GameItems.describe(w) != "" and GameItems.sell_price(d, w) >= 1 and not GameItems.sold_here(d, w), "%s can be told and sold on but is not in a shop" % w)
	# the craftsmanship it gives is felt at the forge: the Hammer-Mark Brooch is a point of quality
	var d2 := dyn("armorer", 1)
	GameCraft.add_material(d2, "iron", 40)
	var q := GameCraft.quality(d2)
	_stock(d2, GameData.items["hammer_mark_brooch"]["recipe"]["cost"])
	GameSubclass.make(d2, "hammer_mark_brooch")
	GameItems.equip(d2, "hammer_mark_brooch")
	ok(GameCraft.quality(d2) == q + 1, "the brooch adds a point of craftsmanship: %d then %d" % [q, GameCraft.quality(d2)])
	ok(GameItems.describe("hammer_mark_brooch").contains("craftsmanship"), "and says so: %s" % GameItems.describe("hammer_mark_brooch"))


func test_saving() -> void:
	var d := dyn("enchanter")
	_stock(d, GameData.items["enchanters_wand"]["recipe"]["cost"])
	GameSubclass.make(d, "enchanters_wand")
	GameItems.equip(d, "enchanters_wand")
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(back.heir.subclass == "enchanter" and GameItems.equipped(back.heir, "weapon") == "enchanters_wand", "a work worn through a save and load")
	ok(is_equal_approx(back.heir.trait_total("element_power"), d.heir.trait_total("element_power")), "does what it did")
	# a save from before holds none of this and loads as it did
	var old := dyn("")
	var od := old.to_dict()
	ok(not JSON.stringify(od).contains("subclass"), "a house with no calling saves nothing of it")
	ok(GameDynasty.from_dict(JSON.parse_string(JSON.stringify(od))).heir.subclass == "", "and loads with none")
	# a save that holds a work whose calling has since gone: the item is simply gear
	var odd := d.to_dict()
	odd["heir"]["subclass"] = "nonesuch"
	var loaded := GameDynasty.from_dict(odd)
	ok(loaded.heir.subclass == "" and GameItems.equipped(loaded.heir, "weapon") == "enchanters_wand", "an unknown calling loads as none and the work is still worn")
	# the heir's work is the heir's: a child does not inherit the item, only (perhaps) the calling
	ok(GameSubclass.work_plan(loaded, "wrights_edge")["why"] != "", "(and cannot make another's)")


func _break(what: String, change: Callable) -> void:
	var saved_items := GameData.items.duplicate(true)
	var saved_sub: Dictionary = GameSubclass.data().duplicate(true)
	change.call()
	ok(not GameSubclass.validate().is_empty(), "the validator finds %s" % what)
	GameData.items = saved_items
	GameSubclass._cache = saved_sub
	ok(GameSubclass.validate().is_empty(), "and is clean again")


func test_breaks() -> void:
	_break("a work the shops would sell (and so the autopilot could buy)", func(): GameData.items["springhammer"]["shop"] = "store")
	_break("a work made unique", func(): GameData.items["springhammer"]["unique"] = true)
	_break("a missing work text", func(): GameSubclass.data()["text"].erase("work_made"))
	_break("a work with no fee", func(): GameData.items["springhammer"]["recipe"].erase("fee"))


func _find(n: Node, name: String) -> Node:
	if n.name == name:
		return n
	for c in n.get_children():
		var f := _find(c, name)
		if f != null:
			return f
	return null


func _all(n: Node, name: String, out: Array) -> void:
	if n.name == name:
		out.append(n)
	for c in n.get_children():
		_all(c, name, out)


func _find_label(n: Node, text: String) -> Label:
	if n is Label and (n as Label).text.begins_with(text):
		return n
	for c in n.get_children():
		var l := _find_label(c, text)
		if l != null:
			return l
	return null


func test_screens() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	GameSaves.base = DIR + "save.json"
	GameDynasty.save_path = GameSaves.base
	UiSettings.path = DIR + "settings.cfg"
	UiSettings.scale = 1.0
	root.size = Vector2i(1280, 720)
	var d := dyn("bladewright")
	_stock(d, GameData.items["wrights_edge"]["recipe"]["cost"])
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
	ok(panel != null, "it opens the workshop")
	if panel == null:
		host.queue_free()
		return
	ok(_find_label(panel, "The Bladewright's works") != null, "it lists the calling's works")
	var rows: Array = []
	_all(panel, "Work", rows)
	ok(rows.size() == 2, "a button for each of the two works (%d)" % rows.size())
	var edge := -1
	for i in rows.size():
		if not (rows[i] as Button).disabled:
			edge = i
	ok(edge >= 0, "one of them is ready")
	var packed := d.heir.inventory.size()
	(rows[edge] as Button).pressed.emit()
	await _frames(3)
	ok(d.heir.inventory.size() == packed + 1 and "wrights_edge" in d.heir.inventory, "pressing it makes the work")
	# no calling, no section
	var plain := dyn("")
	var host2 := Control.new()
	root.add_child(host2)
	var house2: Control = HousePanel.new()
	house2.dynasty = plain
	host2.add_child(house2)
	await _frames(3)
	(_find(house2, "Workshop") as Button).pressed.emit()
	await _frames(3)
	var panel2: Control = null
	for c in host2.get_children():
		if c.get_script() == CraftPanel:
			panel2 = c
	var rows2: Array = []
	_all(panel2, "Work", rows2)
	ok(panel2 != null and rows2.is_empty() and _find_label(panel2, "The Bladewright") == null, "a house with no calling sees no works in the workshop")
	# the alchemist's brew has a row of its own
	var al := dyn("alchemist")
	var host3 := Control.new()
	root.add_child(host3)
	var p3 := CraftPanel.new()
	p3.dynasty = al
	host3.add_child(p3)
	await _frames(3)
	var brews: Array = []
	_all(p3, "Brew", brews)
	ok(brews.size() == 2, "an Alchemist's workshop has two brews: the potion and the elixir (%d)" % brews.size())
	# the Chronicle's tab
	var c := ChroniclePanel.new()
	c.dynasty = d
	host3.add_child(c)
	await _frames(3)
	var tabs: TabContainer = _find(c, "Subclass").get_parent()
	tabs.current_tab = _find(c, "Subclass").get_index()
	await _frames(2)
	ok(_find_label(c, "The Bladewright's works") != null and _find_label(c, "Wright's Edge (level 6)") != null and _find_label(c, "Whetstone Charm (level 1)") != null, "the Chronicle lists the calling's works with their levels")
	host.queue_free()
	host2.queue_free()
	host3.queue_free()
	await _frames(2)
	DirAccess.remove_absolute(DIR + "save.json")


func _find_button_text(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text == text:
		return n
	for c in n.get_children():
		var b := _find_button_text(c, text)
		if b != null:
			return b
	return null
