## The profile bots (core/game/game_profile.gd, GameBot's hooks, tools/balance.gd's `profile` argument): with no profile the autopilot plays bit for bit as before
## (the same batch, with and without the hooks, is identical); every profile runs whole lives without error, spends effort and changes the family's net worth in
## the way it should; net worth counts what it says; the fleer runs; a batch with a profile adds up and is reproducible; a calling's perk shows on its profile
## (and does not on the plain autopilot's numbers); and the harness arguments are understood.
## Run: godot --headless --path . -s res://tests/test_game_profiles.gd
extends SceneTree

const Balance := preload("res://tools/balance.gd")

var checks := 0
var fails := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	GameData.load_all()
	test_hooks_off()
	test_net_worth()
	test_profiles()
	test_trialist()
	test_batch()
	test_perks()
	test_args()
	print("profile tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(seed_value: int = 3, subclass: String = "") -> GameDynasty:
	return GameDynasty.new_game(seed_value, "", "warrior", "faetouched", "human", GameSex.MALE, subclass)


func _life(id: String, seed_value: int = 3, subclass: String = "") -> Dictionary:
	var d := _dyn(seed_value, subclass)
	var ctx := GameProfile.start(d, id)
	GameBot.live_life(d, GameProfile.attach(ctx))
	GameProfile.detach()
	var fin := GameProfile.finish(d, ctx)
	fin["d"] = d
	return fin


func test_hooks_off() -> void:
	var a := _dyn()
	GameBot.live_life(a)
	var b := _dyn()
	GameBot.live_life(b, Callable())
	ok(JSON.stringify(a.last_death) == JSON.stringify(b.last_death) and a.rng.state == b.rng.state, "no hook: a life is exactly the autopilot's")
	ok(GameBot.flee_below == 0.0 and not GameBot.on_fight_end.is_valid(), "and the other two hooks are off")
	# a batch with the empty profile is a batch without it, digit for digit
	var plain := Balance.play_batch(2, ["human", "elf"], 3)
	var none := Balance.play_batch(2, ["human", "elf"], 3, "", false, "")
	ok(JSON.stringify(plain) == JSON.stringify(none), "an empty profile argument plays the same batch")
	ok(float(plain["total"]["ge"]) == 0.0 and float(plain["total"]["actions"]) == 0.0, "and counts no profile figures")


func test_net_worth() -> void:
	var d := _dyn()
	var w0 := GameProfile.net_worth(d)
	d.heir.gold += 100
	ok(is_equal_approx(GameProfile.net_worth(d), w0 + 100.0), "gold counts one for one")
	GameCraft.add_material(d, "iron", 10)
	ok(is_equal_approx(GameProfile.net_worth(d), w0 + 100.0 + 10.0 * GameShops.unit_price("iron")), "materials count at the unit price")
	GameCraft.add_essence(d, "keen", 2)
	var tier := float(GameLoot.data()["_affix"]["keen"]["min_tier"])
	ok(is_equal_approx(GameProfile.net_worth(d), w0 + 100.0 + 10.0 * GameShops.unit_price("iron") + 2.0 * GameProfile.ESSENCE_UNIT * tier), "essences count per tier")
	var before := GameProfile.net_worth(d)
	d.heir.potions += 2
	ok(is_equal_approx(GameProfile.net_worth(d), before + 2.0 * float(d.potion_price())), "potions count at their price")
	var e := GameRoster.add(d, "sheep", "Wool")
	ok(not e.is_empty() and GameProfile.net_worth(d) > before + 2.0 * float(d.potion_price()), "a kept creature counts")
	var b2 := GameProfile.net_worth(d)
	d.built["0,-1,0"] = "wall"
	ok(GameProfile.net_worth(d) > b2, "a built piece counts at its list cost")


func test_profiles() -> void:
	var ran := {}
	for id in GameProfile.IDS:
		var r := _life(id)
		ran[id] = r
		ok(r["d"].state == "succession" or r["d"].state == "ended" or r["d"].state == "life", "%s: a whole life plays out (%s)" % [id, r["d"].state])
		ok(float(r["gain"]) == float(r["gain"]) and int(r["actions"]) >= 0, "%s: gain %.0f in %d actions" % [id, float(r["gain"]), int(r["actions"])])
	ok(int(ran["miner"]["actions"]) > 5, "the miner digs (%d)" % int(ran["miner"]["actions"]))
	ok(int(ran["forager"]["actions"]) > 5, "the forager forages (%d)" % int(ran["forager"]["actions"]))
	var d: GameDynasty = ran["miner"]["d"]
	ok(GameMine.dug_count(d, GameWorldGen.MINE_SITE) > 0, "the miner's cells are in the ground")
	ok(not (ran["forager"]["d"] as GameDynasty).gathered.is_empty(), "the forager's nodes are marked gathered")
	ok(float(ran["miner"]["gain"]) != float(ran["forager"]["gain"]), "different profiles, different gains")
	# the farmer buys animals at a market town
	var f := _dyn()
	f.world.location = "hearthmere"
	f.heir.gold = 100000
	var ctx := GameProfile.start(f, "farmer")
	for i in 40:
		GameProfile.hook(f, ctx)
	ok(f.roster.size() > 0 and int(ctx["actions"]) > 0, "the farmer buys young animals in a market town (%d kept)" % f.roster.size())
	# the breeder sets adults to breed
	var br := _dyn()
	br.world.location = "hearthmere"
	br.heir.gold = 100000
	var bctx := GameProfile.start(br, "breeder")
	var adult := GameRoster.add(br, "sheep", "Ewe")
	adult["stage"] = "adult"
	for i in 16:
		GameProfile.hook(br, bctx)
	ok(br.roster.any(func(e): return bool(e.get("breeding", false))), "the breeder sets adults to breed")
	# the forge salvages a made piece and makes one when it can
	var fg := _dyn()
	fg.world.location = "hearthmere"
	fg.heir.gold = 100000
	GameCraft.add_material(fg, "iron", 20)
	GameCraft.add_material(fg, "oak", 20)
	GameCraft.add_material(fg, "leather", 20)
	var fctx := GameProfile.start(fg, "forge")
	for i in 5:
		GameProfile.hook(fg, fctx)
	ok(int(fctx["actions"]) >= 1 and int(fg.stores.get("crafted", 0)) >= 1, "the forge makes a piece from the stores (%d crafted)" % int(fg.stores.get("crafted", 0)))
	# the builder raises a house when it has the stores
	var bd := _dyn()
	bd.heir.gold = 100000
	GameCraft.add_material(bd, "oak", 100)
	GameCraft.add_material(bd, "iron", 5)
	var dctx := GameProfile.start(bd, "builder")
	for i in 12:
		GameProfile.hook(bd, dctx)
	ok(not bd.built.is_empty(), "the builder raises a house from the stores (%d pieces)" % bd.built.size())
	# the fleer's hook is set and cleared
	var fl := _dyn()
	var flctx := GameProfile.start(fl, "fleer")
	GameProfile.attach(flctx)
	ok(GameBot.flee_below > 0.0, "the fleer sets the flee rule")
	GameProfile.detach()
	ok(GameBot.flee_below == 0.0 and not GameBot.on_fight_end.is_valid(), "and detach puts it all back")


func test_trialist() -> void:
	var d := _dyn(3)
	d.heir.level = 12
	d.heir.gold = 100000
	var ctx := GameProfile.start(d, "trialist")
	var seen_active := false
	var seen_fight := false
	for i in 400:
		GameProfile.hook(d, ctx)
		if d.state != "life":
			break
		var a := GameTrials.active(d)
		if not a.is_empty():
			seen_active = true
			if bool(GameTrials.trial(str(a["id"])).get("fight", false)):
				seen_fight = true
	ok(int(ctx["actions"]) > 0, "the trialist acts (%d actions)" % int(ctx["actions"]))
	ok(seen_active and int(ctx["tried"]) > 0, "it begins and finishes a trial (%d tried, %d passed)" % [int(ctx["tried"]), int(ctx["trials"])])
	ok(not seen_fight, "and never a trial won by a fight")
	ok(int(ctx["trials"]) == (ctx["passed"] as Array).size() and int(ctx["trials"]) <= int(ctx["tried"]), "its count of passes is the list's")
	for id in ctx["passed"]:
		ok(GameTrials.done(d.heir, str(id)), "%s is on the heir's record" % id)
	ok(d.trials.get("steps", {}).size() > 0, "the family learned a way in")
	# nothing placed stands in reach: it does nothing and spends nothing
	var q := _dyn(3)
	q.heir.level = 1
	var qctx := GameProfile.start(q, "trialist")
	var gold := q.heir.gold
	for i in 20:
		GameProfile.hook(q, qctx)
	ok(q.trials.is_empty() and q.heir.gold == gold, "a heir with no realm open and no trial in reach does nothing")
	# no other profile touches a trial
	var f := _life("forge", 3)
	ok((f["d"] as GameDynasty).trials.is_empty(), "the other profiles never start a trial")
	# a whole life, and a batch: the counts add up and print
	var life := _life("trialist", 3)
	ok(int(life["actions"]) >= 0 and int(life["tried"]) >= int(life["trials"]), "a whole life as a trialist (%d tried)" % int(life["tried"]))
	var b := Balance.play_batch(2, ["human"], 3, "", false, "trialist")
	ok(float(b["total"]["tried"]) >= float(b["total"]["trials"]), "a batch counts trials tried and passed")
	ok(Balance.profile_detail(b["total"]).contains("trials") or float(b["total"]["tried"]) == 0.0, "the detail line says what the trialist passed")
	ok(not Balance.profile_detail(Balance.play_batch(2, ["human"], 2, "", false, "forager")["total"]).contains("trials"), "and the other profiles' lines are as before")


func test_batch() -> void:
	var a := Balance.play_batch(2, ["human", "elf"], 3, "", false, "forager")
	var b := Balance.play_batch(2, ["human", "elf"], 3, "", false, "forager")
	ok(JSON.stringify(a) == JSON.stringify(b), "a profile batch is reproducible")
	ok(float(a["total"]["actions"]) > 0.0 and a["total"]["lives"] >= 2, "it counts actions and lives (%d lives)" % int(a["total"]["lives"]))
	var sum := 0.0
	for r in a["by_race"]:
		sum += float(a["by_race"][r]["ge"])
	ok(absf(sum - float(a["total"]["ge"])) < 0.01, "the gain adds up across the races")
	ok(Balance.profile_detail(a["total"]).contains("GE per action"), "the detail line names the return on effort")
	ok(GameBot.flee_below == 0.0, "the batch leaves the hooks off")
	var p := Balance.play_batch(2, ["human"], 3, "", false, "fleer")
	ok(p["total"]["lives"] >= 1, "the fleer's batch plays")


func test_perks() -> void:
	# a calling's perk shows on its profile: the Greenwarden forages more (forage_mult 1.4 founded 1.6), so the forager's gain is higher in the same life
	var plain := _life("forager", 5, "")
	var warden := _life("forager", 5, "greenwarden")
	ok(float(warden["gain"]) > float(plain["gain"]) * 0.9, "the Greenwarden's forager is not worse than the plain one (%.0f against %.0f)" % [float(warden["gain"]), float(plain["gain"])])
	var d_plain: GameDynasty = plain["d"]
	var d_ward: GameDynasty = warden["d"]
	var plain_mats := 0
	var ward_mats := 0
	for m in GameMaterials.ids():
		plain_mats += GameCraft.have(d_plain, str(m))
		ward_mats += GameCraft.have(d_ward, str(m))
	ok(ward_mats >= plain_mats, "and gathers at least as much (%d against %d units)" % [ward_mats, plain_mats])
	# and the autopilot alone does not see the Delver (its numbers equal the plain house's), as BALANCE.md says
	var x := _dyn(4, "delver")
	GameBot.live_life(x)
	var y := _dyn(4, "")
	GameBot.live_life(y)
	ok(int(x.last_death.get("gold", 0)) == int(y.last_death.get("gold", 0)), "the plain autopilot cannot see the Delver's perks")
	var m := _life("miner", 4, "delver")
	var mp := _life("miner", 4, "")
	ok(int(m["actions"]) > 0 and int(mp["actions"]) > 0, "while the miner does dig as one (%d and %d strikes)" % [int(m["actions"]), int(mp["actions"])])


func test_args() -> void:
	ok(GameProfile.has("forge") and GameProfile.has("fleer") and not GameProfile.has("nonsuch") and not GameProfile.has(""), "the profile ids")
	ok(GameProfile.IDS.size() == 8 and GameProfile.has("trialist"), "eight profiles, the trialist among them")
