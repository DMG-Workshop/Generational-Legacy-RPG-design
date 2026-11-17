## Brewing consumables at the forge (roadmap item 44): a brew in craft.json costs materials and a fee, a town forge or the family's
## own (at `home_fee_mult` of the fee) will do it, it puts potions in the heir's pack and counts as brewed, nothing is spent when
## it cannot be done, the count saves and loads clean, and the craft panel offers it. No dice are drawn.
## Run: godot --headless --path . -s res://tests/test_game_brew.gd
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
	test_brew()
	test_failures()
	test_saving()
	await test_panel()
	print("brew tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh() -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 500
	GameCraft.add_material(d, "herb", 10)
	return d


func test_data() -> void:
	ok(GameCraft.validate().is_empty(), "the shipped data passes: %s" % str(GameCraft.validate()))
	ok(GameCraft.brews() == ["healing_potion"], "one brew ships: the healing potion")
	var row: Dictionary = GameCraft.data()["brews"]["healing_potion"]
	var keep: Variant = row["cost"]
	row["cost"] = {"unobtainium": 1}
	ok(not GameCraft.validate().is_empty(), "a brew costing an unknown material is caught")
	row["cost"] = keep
	var makes: Variant = row["makes"]
	row["makes"] = 0
	ok(not GameCraft.validate().is_empty(), "a brew that makes nothing is caught")
	row["makes"] = makes
	ok(GameCraft.validate().is_empty(), "and mending the data clears it")


func test_brew() -> void:
	var d := _fresh()
	ok(d.world.has_service("forge"), "(Hearthmere has a forge)")
	var town := GameCraft.brew_plan(d, "healing_potion")
	var home := GameCraft.brew_plan(d, "healing_potion", "home")
	ok(town["ok"] and home["ok"], "both forges can brew it")
	ok(int(home["fee"]) == int(round(float(town["fee"]) * float(GameCraft.setting("home_fee_mult")))) and int(home["fee"]) < int(town["fee"]), "the family's forge charges a share of the fee: %d against %d" % [home["fee"], town["fee"]])
	var gold := d.heir.gold
	var herbs := GameCraft.have(d, "herb")
	var potions := d.heir.potions
	var rng_state := d.rng.state
	var line := GameCraft.brew(d, "healing_potion", "home")
	ok(line.contains("brews") and line.contains("healing potion"), "the line says so: %s" % line)
	ok(d.heir.potions == potions + 1, "a potion is in the pack")
	ok(d.heir.gold == gold - int(home["fee"]) and GameCraft.have(d, "herb") == herbs - 2, "the fee and two herbs are spent")
	ok(int(d.stores.get("brewed", 0)) == 1 and int(d.stores.get("crafted", 0)) == 0, "it counts as brewed, not as a piece crafted")
	ok(d.rng.state == rng_state, "no dice of the dynasty's are drawn")
	d.world.location = "whisperwood"
	ok(not d.world.has_service("forge"), "(somewhere with no town forge)")
	ok(GameCraft.brew(d, "healing_potion").contains("no forge") and d.heir.potions == potions + 1, "away from a forge, a town brew is refused and makes nothing")
	ok(GameCraft.brew(d, "healing_potion", "home").contains("brews") and d.heir.potions == potions + 2, "but the family's forge needs no town forge")


func test_failures() -> void:
	var d := _fresh()
	GameCraft.add_material(d, "herb", -GameCraft.have(d, "herb"))
	GameCraft.add_material(d, "herb", 1)
	var gold := d.heir.gold
	var have_potions := d.heir.potions
	var p := GameCraft.brew_plan(d, "healing_potion", "home")
	ok(not p["ok"] and str(p["why"]).contains("herb"), "short of herbs, it says which: %s" % p["why"])
	ok(GameCraft.brew(d, "healing_potion", "home") == str(p["why"]) and d.heir.potions == have_potions and d.heir.gold == gold and GameCraft.have(d, "herb") == 1, "and nothing is spent or made")
	GameCraft.add_material(d, "herb", 5)
	d.heir.gold = 0
	p = GameCraft.brew_plan(d, "healing_potion", "home")
	ok(not p["ok"] and str(p["why"]).contains("gold"), "with no gold the fee still has to be paid: %s" % p["why"])
	ok(not GameCraft.brew_plan(d, "elixir_of_nothing")["ok"], "an unknown brew is refused")


func test_saving() -> void:
	var d := _fresh()
	GameCraft.brew(d, "healing_potion", "home")
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(int(back.stores.get("brewed", 0)) == 1 and back.heir.potions == d.heir.potions, "the count and the potion come back through JSON")
	ok(GameCraft.load_stores({"brewed": -3}) == {} and GameCraft.load_stores({"brewed": "x"}) == {}, "a bad count loads as nothing")
	ok(GameCraft.load_stores({"brewed": 4}) == {"brewed": 4}, "a good one loads")
	ok(not _fresh().to_dict().has("stores") or not _fresh().to_dict()["stores"].has("brewed"), "a house that has brewed nothing keeps no count")


func test_panel() -> void:
	var d := _fresh()
	d.world.location = "whisperwood"
	var CraftPanel := load("res://ui/play/craft_panel.gd")
	var panel: Control = CraftPanel.new()
	panel.dynasty = d
	panel.on_change = func(): pass
	panel.forge = "home"
	root.add_child(panel)
	await process_frame
	var b: Button = panel.find_child("Brew", true, false)
	ok(b != null and not b.disabled, "the panel offers Brew at the family's forge")
	var potions := d.heir.potions
	if b != null:
		b.pressed.emit()
	ok(d.heir.potions == potions + 1, "pressing it brews a potion")
	panel.queue_free()
	await process_frame
	var away: Control = CraftPanel.new()
	away.dynasty = d
	away.on_change = func(): pass
	root.add_child(away)
	await process_frame
	var b2: Button = away.find_child("Brew", true, false)
	ok(b2 != null and b2.disabled, "away from any forge the button is shut")
	away.queue_free()
