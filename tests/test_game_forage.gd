## Foraging by the heir and the Smithy (roadmap item 44): the Forage action gathers the nearest ungathered node in reach into the
## stores with a class share and marks it gathered (the companions' marks), so it is not taken twice and regrows on the same
## calendar; not indoors or upstairs; no dice. The Smithy is a fourth house track: its levels raise the quality of a made piece
## and cut the forge's fee (and a brew's), and level 0 changes nothing.
## Run: godot --headless --path . -s res://tests/test_game_forage.gd
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
	test_forage()
	test_refusals()
	test_smithy()
	await test_screen()
	print("forage tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh(class_id: String = "warrior") -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", class_id, "faetouched", "human")
	d.pending_event = {}
	return d


## A tile with a gatherable node and a tile beside it: [node tile, standing tile].
func _node_site(d: GameDynasty) -> Array:
	var b := GameBuild.base()
	var near: Array = GameCompanions.scan(d, Vector2(float(b["x"]), float(b["z"])))
	for r in [40, 80, 120]:
		near = GameCompanions.scan(d, Vector2(float(b["x"]) + float(r), float(b["z"]) + float(r)))
		if not near.is_empty():
			break
	var n: Dictionary = near[0]
	return [n, Vector2i(int(n["x"]), int(n["z"]))]


func test_data() -> void:
	ok(GameForage.validate().is_empty(), "the shipped data passes: %s" % str(GameForage.validate()))
	var cls: Dictionary = GameForage.data()["classes"]
	cls["nonesuch"] = 1.0
	ok(not GameForage.validate().is_empty(), "a share for a class that does not exist is caught")
	cls.erase("nonesuch")
	cls["ranger"] = 0.0
	ok(not GameForage.validate().is_empty(), "a share of nothing is caught")
	cls["ranger"] = 1.5
	var dflt: Variant = cls["default"]
	cls.erase("default")
	ok(not GameForage.validate().is_empty(), "a table with no default share is caught")
	cls["default"] = dflt
	ok(GameForage.validate().is_empty(), "and mending the data clears it")


func test_forage() -> void:
	var d := _fresh()
	var site := _node_site(d)
	var node: Dictionary = site[0]
	var at: Vector2i = site[1]
	var mat := str(node["material"])
	var had := GameCraft.have(d, mat)
	var rng := d.rng.state
	var out := GameForage.forage(d, at.x, at.y)
	ok(bool(out["ok"]) and str(out["material"]) == mat, "the heir gathers the node they stand on")
	ok(GameCraft.have(d, mat) == had + int(out["n"]) and int(out["n"]) >= 1, "the stores grow by what it says")
	ok(d.rng.state == rng, "no dice are drawn")
	ok(GameCompanions.depleted(d, int(node["x"]), int(node["z"])), "and the node is marked gathered")
	var again := GameForage.in_reach(d, at.x, at.y)
	ok(not again.any(func(n): return int(n["x"]) == int(node["x"]) and int(n["z"]) == int(node["z"])), "so it is not gathered twice")
	# regrows on the companions' calendar
	d.world.year += float(GameCompanions.setting("regrow_years")) + 0.1
	ok(GameForage.in_reach(d, at.x, at.y).any(func(n): return int(n["x"]) == int(node["x"]) and int(n["z"]) == int(node["z"])), "and it regrows when the companions' nodes do")
	# class share
	var a := _fresh("warrior")
	var b := _fresh("ranger")
	ok(GameForage.share(b) > GameForage.share(a), "a ranger gathers more than a warrior")
	var ga := GameForage.forage(a, at.x, at.y)
	var gb := GameForage.forage(b, at.x, at.y)
	var amount := float(node["amount"])
	ok(int(ga["n"]) == maxi(1, int(round(amount * 0.9))) and int(gb["n"]) == maxi(1, int(round(amount * 1.5))), "each takes the node's %d times their share: %d and %d" % [int(amount), ga["n"], gb["n"]])
	var far := GameForage.forage(_fresh(), 0, 0)
	ok(not far["ok"] and far["text"] == GameForage.text("nothing"), "with nothing in reach it says so")


func test_refusals() -> void:
	var d := _fresh()
	var s := GameSandbox.start(d)
	s.creatures.clear()
	s.space = "world/hearthmere/store"
	ok(not s.forage()["ok"] and s.forage()["text"] == GameForage.text("indoors"), "indoors, nothing is gathered")
	s.space = "world"
	s.heir_y = GameBuild.SURFACE - 1
	ok(not s.forage()["ok"] and s.forage()["text"] == GameForage.text("upstairs"), "upstairs, nothing is gathered")
	s.heir_y = GameBuild.SURFACE
	var site := _node_site(d)
	s.heir = site[1]
	var logged := s.log.size()
	var r := s.forage()
	ok(bool(r["ok"]) and s.log.size() == logged + 1, "on the ground it gathers and logs a line: %s" % str(r["text"]))


func test_smithy() -> void:
	ok(GameHouse.TRACKS.has(GameHouse.SMITHY) and GameHouse.track_name(GameHouse.SMITHY) == "Smithy", "the Smithy is a house track")
	var d := _fresh()
	ok(GameHouse.smithy_quality(d) == 0 and GameHouse.smithy_fee_mult(d) == 1.0, "level 0 changes nothing")
	d.heir.gold = 100000
	var price := GameHouse.cost(d, GameHouse.SMITHY)
	var gold := d.heir.gold
	GameHouse.buy(d, GameHouse.SMITHY)
	ok(GameHouse.level(d, GameHouse.SMITHY) == 1 and gold - d.heir.gold == price, "it is bought with gold like the others")
	ok(GameHouse.level(d, GameHouse.HALL) == 0, "and the others are untouched")
	ok(GameHouse.smithy_quality(d) == 1 and absf(GameHouse.smithy_fee_mult(d) - 0.9) < 0.0001, "level 1: a point of quality, a tenth off the fee")
	# crafting reads it
	var plain := _fresh()
	plain.heir.gold = 100000
	d.heir.gold = 100000
	for dd in [plain, d]:
		for m in ["oak", "iron", "linen", "copper", "herb"]:
			GameCraft.add_material(dd, m, 100)
	var form := ""
	var mat := ""
	for f in GameLoot.data()["forms"]:
		for m in GameCraft.materials_for(str(f["id"])):
			if GameCraft.have(d, str(m)) >= 20 and form == "":
				form = str(f["id"])
				mat = str(m)
	var q0 := GameCraft.quality(plain)
	var q1 := GameCraft.quality(d)
	ok(q1 == mini(q0 + 1, GameLoot.QUALITY_MAX), "a made piece is a point better: %d against %d" % [q1, q0])
	var p0 := GameCraft.plan(plain, form, mat, [], "home")
	var p1 := GameCraft.plan(d, form, mat, [], "home")
	ok(int(p1["fee"]) < int(p0["fee"]), "and the forge fee is less: %d against %d" % [p1["fee"], p0["fee"]])
	var b0 := GameCraft.brew_plan(plain, "healing_potion")
	var b1 := GameCraft.brew_plan(d, "healing_potion")
	ok(int(b1["fee"]) <= int(b0["fee"]), "a brew's fee is no more")
	# save and load
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(GameHouse.level(back, GameHouse.SMITHY) == 1, "the level survives a save and load")
	var raw := d.to_dict()
	raw["house"] = {"smithy": 99, "nonesuch": 2}
	ok(GameHouse.level(GameDynasty.from_dict(raw), GameHouse.SMITHY) == GameHouse.max_level(), "a level past the top is held to the top, an unknown track dropped")


func test_screen() -> void:
	var d := _fresh()
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
	var site := _node_site(d)
	scr.sb.heir = site[1]
	ok(scr.slots.has("forage") and scr.slot_ids.find("forage") == 2, "the bar has a Forage slot (the third, key 3)")
	var stock := GameCraft.describe(d)
	scr.slots["forage"].pressed.call()
	ok(GameCraft.describe(d) != stock, "pressing it gathers")
	scr.queue_free()
	fake.queue_free()


class FakeApp extends Node:
	var dynasty: GameDynasty

	func show_state() -> void:
		pass
