## Carry limits (roadmap item 43): the data and ways to break it; capacity from Strength and what is carried (the
## pack, what is worn, the potions); a purchase refused when it will not fit and a find or drop sold where it lies;
## gifts always taken (and a heir over the limit simply taking no more); dropping from the pack; the pack screen's
## Drop button; and that the autopilot is never over the limit, so its results do not move.
## Run: godot --headless --path . -s res://tests/test_game_carry.gd
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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	GameData.load_all()
	test_data()
	test_weight()
	test_buy()
	test_finds()
	test_gifts()
	test_drop()
	await test_screen()
	test_autopilot()
	print("carry tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func dyn(seed_value: int = 5) -> GameDynasty:
	return GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")


## Fills the pack with plate until only `room` weight is left.
func _fill(d: GameDynasty, room: float) -> void:
	while GameCarry.room(d.heir) - GameItems.weight_of("plate_armor") > room:
		d.heir.inventory.append("plate_armor")
	var rest := GameCarry.room(d.heir) - room
	while rest > 0.25:
		d.heir.inventory.append("copper_ring")
		rest -= GameItems.weight_of("copper_ring")


func test_data() -> void:
	ok(GameCarry.validate().is_empty(), "the data is sound: %s" % str(GameCarry.validate()))
	var saved: Dictionary = GameCarry.data().duplicate(true)
	GameCarry.data()["settings"]["base_capacity"] = 5
	ok(not GameCarry.validate().is_empty(), "a capacity below the heaviest item is found")
	GameCarry._cache = saved.duplicate(true)
	GameCarry.data()["settings"]["per_strength"] = -1
	ok(not GameCarry.validate().is_empty(), "a negative setting is found")
	GameCarry._cache = saved.duplicate(true)
	GameCarry.data()["text"].erase("dropped")
	ok(not GameCarry.validate().is_empty(), "a missing line of text is found")
	GameCarry._cache = saved.duplicate(true)
	GameCarry.data()["settings"].erase("potion_weight")
	ok(not GameCarry.validate().is_empty(), "a missing setting is found")
	GameCarry._cache = saved
	ok(GameCarry.validate().is_empty(), "and the data is put back")


func test_weight() -> void:
	var d := dyn()
	var h := d.heir
	var cap := GameCarry.capacity(h)
	ok(cap >= float(GameCarry.setting("base_capacity")), "a heir carries at least the base: %.1f" % cap)
	var base := GameCarry.carried(h)
	h.inventory.append("plate_armor")
	ok(is_equal_approx(GameCarry.carried(h), base + GameItems.weight_of("plate_armor")), "an item in the pack weighs what it weighs")
	h.equipment["armor"] = "plate_armor"
	ok(is_equal_approx(GameCarry.carried(h), base + 2.0 * GameItems.weight_of("plate_armor")), "and what is worn counts too")
	h.inventory.clear()
	h.equipment["armor"] = ""
	h.potions = 10
	var w := GameCarry.carried(h)
	h.potions = 0
	ok(is_equal_approx(w - GameCarry.carried(h), 10.0 * float(GameCarry.setting("potion_weight"))), "potions weigh a little each")
	ok(is_equal_approx(GameCarry.room(h), GameCarry.capacity(h) - GameCarry.carried(h)), "room is what is left")
	var strong := dyn()
	strong.heir.level = 60
	ok(GameCarry.capacity(strong.heir) > cap, "a stronger heir carries more (%.1f against %.1f)" % [GameCarry.capacity(strong.heir), cap])
	# a stack weighs by the unit
	h.inventory.append("willowbark_tonic")
	var one := GameCarry.carried(h)
	h.inventory.append("willowbark_tonic")
	ok(is_equal_approx(GameCarry.carried(h) - one, GameItems.weight_of("willowbark_tonic")), "each of a stack weighs the same")
	ok(GameCarry.summary(h).contains(" of "), "the screens read '%s'" % GameCarry.summary(h))


func test_buy() -> void:
	var d := dyn()
	d.heir.gold = 100000
	ok(GameItems.sold_here(d, "iron_sword") and GameItems.sold_here(d, "padded_robe"), "(the starting town sells a sword and a robe)")
	_fill(d, 2.0)
	var gold := d.heir.gold
	var pack := d.heir.inventory.size()
	ok(not GameCarry.can_carry(d.heir, "iron_sword") and GameCarry.why_not(d.heir, "iron_sword").contains("cannot carry"), "a sword does not fit: %s" % GameCarry.why_not(d.heir, "iron_sword"))
	ok(GameCarry.can_carry(d.heir, "padded_robe") and GameCarry.why_not(d.heir, "padded_robe") == "", "a light robe still fits")
	var got := GameItems.buy(d, "iron_sword")
	ok(got.contains("cannot carry the Iron Sword"), "buying what will not fit is refused: %s" % got)
	ok(d.heir.gold == gold and d.heir.inventory.size() == pack, "and costs nothing and adds nothing")
	var ring := GameItems.buy(d, "padded_robe")
	ok(ring.contains("buys the Padded Robe") and d.heir.gold < gold and GameItems.owns(d.heir, "padded_robe"), "what fits is bought: %s" % ring)
	var e := dyn()
	e.heir.gold = 100000
	ok(GameItems.buy(e, "iron_sword").contains("buys the Iron Sword"), "an empty pack buys")


func test_finds() -> void:
	# the old search: a find that does not fit is sold where it lies
	var d := dyn()
	_fill(d, 0.0)
	d.heir.inventory = d.heir.inventory.filter(func(x): return true)
	d.heir.inventory.append("plate_armor")   # over the limit, so nothing fits
	var gold := d.heir.gold
	var pack := d.heir.inventory.size()
	var sold := 0
	for i in 60:
		d.rng.seed = i + 1
		d.loot = {"foes": [{"id": "slime", "name": "Slime", "carries": []}], "gold": 0, "item_chance": 1.0}
		var lines := GamePlague.search(d)
		for l in lines:
			if str(l).contains("cannot carry it"):
				sold += 1
	ok(sold > 0 and d.heir.inventory.size() == pack, "a find that does not fit is sold, not carried (%d sold)" % sold)
	ok(d.heir.gold > gold, "for gold")
	# a made drop that does not fit
	var m := dyn()
	_fill(m, 0.0)
	m.heir.inventory.append("plate_armor")
	var mpack := m.heir.inventory.size()
	var mg := m.heir.gold
	var foes: Array = []
	for i in 400:
		foes.append({"id": "slime"})
	var lines := GameLoot.after_search(m, foes)
	ok(lines.size() > 0 and m.heir.inventory.size() == mpack and m.heir.gold > mg, "a made drop that does not fit is sold where it lies (%d)" % lines.size())
	ok(str(lines[0]).contains("cannot carry it"), "and says so: %s" % lines[0])
	# with room, it is carried
	var r := dyn()
	var rl := GameLoot.after_search(r, foes)
	ok(r.heir.inventory.size() > 0 and not str(rl[0]).contains("cannot carry"), "with room, it goes in the pack")


func test_gifts() -> void:
	var d := dyn()
	_fill(d, 1.0)
	d.give_item("plate_armor")
	d.give_item("plate_armor")
	ok(GameCarry.burdened(d.heir) and d.heir.inventory.count("plate_armor") >= 2, "a gift is always taken, even over the limit")
	ok(not GameCarry.can_carry(d.heir, "copper_ring") and GameCarry.room(d.heir) < 0.0, "and then nothing more fits")
	var first := d.heir.inventory.size()
	d.heir.inventory.erase("plate_armor")
	d.heir.inventory.erase("plate_armor")
	ok(d.heir.inventory.size() == first - 2 and not GameCarry.burdened(dyn().heir), "putting things down lightens the load")
	# an old save with a heavy pack still loads
	var h := dyn().heir
	for i in 40:
		h.inventory.append("plate_armor")
	var h2 := GameHeir.from_dict(h.to_dict())
	ok(h2.inventory.size() == 40 and GameCarry.burdened(h2), "a save with too much loads, and is just burdened")


func test_drop() -> void:
	var d := dyn()
	d.heir.inventory.append("plate_armor")
	d.heir.inventory.append("plate_armor")
	var before := GameCarry.carried(d.heir)
	var line := GameCarry.drop(d, "plate_armor")
	ok(d.heir.inventory.count("plate_armor") == 1 and line.contains("leaves the Plate Armor behind"), "dropping leaves one behind: %s" % line)
	ok(GameCarry.carried(d.heir) < before, "and lightens the load")
	d.heir.equipment["armor"] = "chainmail"
	ok(GameCarry.drop(d, "chainmail").contains("no Chainmail in the pack") and d.heir.equipment["armor"] == "chainmail", "worn gear is not dropped")
	ok(GameCarry.drop(d, "iron_sword").contains("no Iron Sword"), "nor what is not carried")
	# a tainted bargain is forgotten once the last is gone
	d.heir.inventory.append("notched_falchion")
	d.heir.tainted_gear.append("notched_falchion")
	GameCarry.drop(d, "notched_falchion")
	ok(not d.heir.tainted_gear.has("notched_falchion"), "the taint goes with the last of it")


func test_screen() -> void:
	var d := dyn()
	d.heir.inventory.append("plate_armor")
	d.heir.inventory.append("willowbark_tonic")
	d.heir.inventory.append("willowbark_tonic")
	var shop: Control = ShopPanel.new()
	shop.dynasty = d
	root.add_child(shop)
	await _frames(4)
	shop._show("gear")
	await _frames(2)
	var drops := _find_all(shop, "Drop")
	ok(drops.size() == 2, "the pack lists a Drop button for the gear and the stack: %d" % drops.size())
	# the gear asks twice
	shop._drop("plate_armor")
	await _frames(2)
	ok(shop.confirm_drop == "plate_armor" and d.heir.inventory.has("plate_armor"), "the first tap on gear only asks")
	shop._drop("plate_armor")
	await _frames(2)
	ok(not d.heir.inventory.has("plate_armor") and shop.confirm_drop == "", "the second drops it")
	# a remedy goes one at a time, at once
	shop._drop("willowbark_tonic")
	await _frames(2)
	ok(d.heir.inventory.count("willowbark_tonic") == 1, "a remedy drops one at a time, with no question")
	ok(_has_text(shop, "Carrying "), "the side panel says how much is carried")
	shop.queue_free()
	await _frames(2)
	ok(not ShopPanel.summary_lines(d).filter(func(x): return str(x).contains("carrying")).is_empty(), "the life screen's summary says it too")


func _find_all(n: Node, text: String) -> Array:
	var out: Array = []
	if n is Button and (n as Button).text == text:
		out.append(n)
	for c in n.get_children():
		out.append_array(_find_all(c, text))
	return out


func _has_text(n: Node, text: String) -> bool:
	if n is Label and (n as Label).text.begins_with(text):
		return true
	for c in n.get_children():
		if _has_text(c, text):
			return true
	return false


# ---------------------------------------------------------------- the autopilot is never over the limit

func test_autopilot() -> void:
	var classes := GameData.starting_ids(GameData.classes)
	var worst := -1e9
	var steps_run := 0
	for sd in 4:
		for ri in 2:
			var d := GameDynasty.new_game(sd * 100 + ri + 1, "", classes[(sd + ri) % classes.size()], "faetouched", ["human", "dwarf"][ri])
			for g in 4:
				var steps := 0
				while d.state == "life" and steps < 5000:
					GameBot.step(d)
					steps += 1
					steps_run += 1
					worst = maxf(worst, GameCarry.carried(d.heir) - GameCarry.capacity(d.heir))
				if d.state != "succession":
					break
				GameBot.choose_best(d)
	ok(steps_run > 1000 and worst <= 0.0, "the autopilot is never over the limit (%d steps; closest it came: %.1f under)" % [steps_run, -worst])
