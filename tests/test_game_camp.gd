## Camping (GameCamp, data/world/camp.json, the item `tent`): the data and the item (stocked by the hunters' lodge and the caravans, never by the old shops);
## a camp is pitched on open ground with the tent and refused in a town, indoors, upstairs, in a fight, in smoke, with none and where one stands; resting
## at it heals the heir and the party by a share and lets a little time pass, a limited number of times; the fire cooks a meal from the stores that
## heals and blesses the next fight; the camp is struck when the heir walks away or it burns out; a night camp keeps creatures from starting a fight
## and from spawning inside its ring, a day camp less; a fight fled from ends at the camp; nothing is saved; the pack's Use and the Camp key work; and
## the autopilot never meets a tent.
## Run: godot --headless --path . -s res://tests/test_game_camp.gd
extends SceneTree

var fails := 0
var checks := 0
const NIGHT := 105.0   # world-clock seconds at midnight (GameDay: start_phase 0.3, a day of 150 seconds)
const NOON := 30.0


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
	test_pitch()
	test_rest()
	test_cook()
	test_strike()
	test_safety()
	test_escape()
	test_use_and_menu()
	test_saving()
	test_autopilot()
	await test_screen()
	print("camp tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## An open-ground tile: dry, clear of every place and of anything standing, with room round it.
func _open_tile(d: GameDynasty) -> Vector2i:
	for z in range(180, 260):
		for x in range(190, 300):
			if GameWorldGen.body_at(d.seed_value, x, z) == "" and not GameCamp.near_place(Vector2(float(x) + 0.5, float(z) + 0.5)) \
					and GameWorldGen.tile(d, x, z)["node"].is_empty() and not GameSandbox.in_town(x, z):
				return Vector2i(x, z)
	return Vector2i(-1, -1)


func _sandbox(tents: int = 1) -> GameSandbox:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.level = 20
	for _i in tents:
		d.heir.inventory.append("tent")
	var s := GameSandbox.start(d)
	s.creatures.clear()
	var t := _open_tile(d)
	s.heir = t
	return s


func _wild_id() -> String:
	return str(GameSpawn.wild()[0]["id"])


func _put(s: GameSandbox, mode: String, at: Vector2) -> Dictionary:
	var a := GameBehaviour.new_agent(900 + s.creatures.size(), _wild_id(), at.x, at.y)
	a["mode"] = mode
	a["level"] = 20
	s.creatures.append(a)
	return a


func test_data() -> void:
	ok(GameCamp.validate().is_empty(), "the camp data is valid: %s" % str(GameCamp.validate()))
	var it := GameItems.item_def("tent")
	ok(not it.is_empty() and str(it["shop"]) == "" and bool(it.get("camp", false)) and GameItems.weight_of("tent") > 0.0 and int(it["price"]) > 0, "the tent is an item with a weight and a price that no old shop sells")
	ok(GameItems.SHOPS == ["forge", "store", "temple", "black_market"], "the old shops the autopilot knows are the same")
	var lodge := false
	for pool in GameShops.def("hunters_lodge")["stock"]:
		if str(pool["type"]) == "items" and "tent" in pool["ids"]:
			lodge = true
	ok(lodge, "the hunters' lodge stocks it")
	var van := false
	for list in GameWilds.data()["landmarks"]["caravan"]["stock"].values():
		van = van or "tent" in list
	ok(van, "and so do the caravans")
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	for l in GameData.world["locations"]:
		d.world.visit(l["id"])
		for svc in GameItems.SHOPS:
			ok("tent" not in GameItems.stock(d, svc), "the %s never stocks it (%s)" % [svc, l["id"]])
	var keep: float = GameCamp.data()["settings"]["heal_share"]
	GameCamp.data()["settings"]["heal_share"] = 1.5
	ok(not GameCamp.validate().is_empty(), "a rest that heals more than all is caught")
	GameCamp.data()["settings"]["heal_share"] = keep
	var night: float = GameCamp.data()["settings"]["night_radius"]
	GameCamp.data()["settings"]["night_radius"] = 99.0
	ok(not GameCamp.validate().is_empty(), "a fire wider than a smoke cloud is caught")
	GameCamp.data()["settings"]["night_radius"] = night
	var spell: String = GameCamp.data()["cook"]["spell"]
	GameCamp.data()["cook"]["spell"] = "fireball"
	ok(not GameCamp.validate().is_empty(), "a meal that blesses with a spell that is no blessing is caught")
	GameCamp.data()["cook"]["spell"] = spell
	ok(GameCamp.validate().is_empty(), "and mending the data clears it")


func test_pitch() -> void:
	var none := _sandbox(0)
	ok(none.heir.x >= 0, "there is open ground to camp on")
	var r := GameCamp.pitch(none)
	ok(not bool(r["ok"]) and str(r["text"]).contains("no tent") and none.camp.is_empty(), "with no tent nothing is pitched")
	var s := _sandbox()
	ok(GameCamp.count(s.d.heir) == 1, "one tent in the pack")
	r = GameCamp.pitch(s)
	ok(bool(r["ok"]) and GameCamp.active(s) and int(s.camp["x"]) == s.heir.x and int(s.camp["rests"]) == int(GameCamp.setting("rests")), "a camp is pitched where the heir stands")
	ok(GameCamp.count(s.d.heir) == 1, "and the tent is not used up")
	ok(str(s.log[-1]["text"]) == str(r["text"]), "and the journal says so")
	ok(not bool(GameCamp.pitch(s)["ok"]) and str(GameCamp.pitch(s)["text"]).contains("already"), "a second camp is refused while one stands")
	ok(GameCamp.at_fire(s) and GameCamp.point(s) == Vector2(float(s.heir.x) + 0.5, float(s.heir.y) + 0.5), "the heir is at the fire")
	# in a bag still counts
	var b := _sandbox(0)
	b.d.heir.bags["satchel"] = ["tent"]
	ok(GameCamp.count(b.d.heir) == 1, "a tent in a bag is counted")
	# the refusals
	var town := _sandbox()
	var a := GameWorldGen.anchor("ironford")
	town.heir = Vector2i(int(a["x"]) + 3, int(a["z"]))
	ok(not bool(GameCamp.pitch(town)["ok"]) and str(GameCamp.pitch(town)["text"]).contains("town"), "not in a town")
	var edge := _sandbox()
	edge.heir = Vector2i(int(a["x"]) + int(GameRoads._ground("ironford")) + 2, int(a["z"]))
	ok(not bool(GameCamp.pitch(edge)["ok"]), "nor just outside its wall")
	var inside := _sandbox()
	inside.space = "somewhere"
	ok(not bool(GameCamp.pitch(inside)["ok"]) and str(GameCamp.pitch(inside)["text"]).contains("indoors"), "not indoors")
	var up := _sandbox()
	up.heir_y = GameBuild.SURFACE - 2
	ok(not bool(GameCamp.pitch(up)["ok"]) and str(GameCamp.pitch(up)["text"]).contains("ground floor"), "not upstairs")
	var fight := _sandbox()
	_put(fight, "chase", fight.heir_point() + Vector2(0.8, 0.0))
	ok(fight._contact() and fight.d.battle != null, "a fight begins")
	ok(not bool(GameCamp.pitch(fight)["ok"]) and str(GameCamp.pitch(fight)["text"]).contains("fight"), "not in the middle of a fight")
	var smoky := _sandbox()
	smoky.d.heir.inventory.append("smoke_pot")
	smoky.use_smoke()
	ok(not bool(GameCamp.pitch(smoky)["ok"]) and str(GameCamp.pitch(smoky)["text"]).contains("smoke"), "nor in a smoke cloud")


func test_rest() -> void:
	var s := _sandbox()
	var h := s.d.heir
	var full := GameCamp.rest(s)
	ok(not bool(full["ok"]), "with no camp there is no rest")
	GameCamp.pitch(s)
	h.full_heal()
	full = GameCamp.rest(s)
	ok(not bool(full["ok"]) and str(full["text"]).contains("no need") and int(s.camp["rests"]) == 2, "no one hurt: no need, and no rest used")
	h.hp = 1
	h.mp = 0
	var age := h.age
	var r := GameCamp.rest(s)
	var want := 1 + int(ceil(GameCamp.setting("heal_share") * float(h.max_hp())))
	ok(bool(r["ok"]) and h.hp == mini(h.max_hp(), want) and h.hp < h.max_hp(), "it heals a share of the heir's health, not all of it (%d of %d)" % [h.hp, h.max_hp()])
	ok(h.mp > 0 and h.mp <= h.max_mp(), "and some of their mana")
	ok(is_equal_approx(h.age - age, GameCamp.setting("rest_years")) or h.age > age, "a little of a year goes by")
	ok(int(s.camp["rests"]) == 1, "and one of the camp's rests is spent")
	GameCamp.rest(s)
	h.hp = 1
	var spent := GameCamp.rest(s)
	ok(not bool(spent["ok"]) and str(spent["text"]).contains("no more rest") and h.hp == 1, "when the rests are spent, there is no more")
	# a companion is mended too
	var p := _sandbox()
	p.d.heir.gold = 1000
	p.d.party.hire(p.d, "bren_cask")
	var mate: Dictionary = p.d.party.members[0]
	var mate_max: int = p.d.party._body(p.d, mate).max_hp()
	mate["hp"] = 1
	GameCamp.pitch(p)
	GameCamp.rest(p)
	ok(int(mate["hp"]) > 1 and int(mate["hp"]) < mate_max, "a companion is mended by the same share (%d of %d)" % [int(mate["hp"]), mate_max])
	# away from the fire the camp does not rest
	var far := _sandbox()
	GameCamp.pitch(far)
	far.d.heir.hp = 1
	far.heir += Vector2i(5, 0)
	var f := GameCamp.rest(far)
	ok(not bool(f["ok"]) and str(f["text"]).contains("tiles away"), "away from the fire it says how far it is")


func test_cook() -> void:
	var s := _sandbox()
	GameCamp.pitch(s)
	var h := s.d.heir
	var r := GameCamp.cook(s)
	ok(not bool(r["ok"]) and str(r["text"]).contains("no ") and s.d.blessing.is_empty(), "with nothing in the stores there is no meal")
	GameCraft.add_material(s.d, "meat", 2)
	GameCraft.add_material(s.d, "herb", 1)
	h.hp = 1
	r = GameCamp.cook(s)
	ok(bool(r["ok"]) and h.hp > 1, "a meal heals: %s" % str(r["text"]))
	ok(GameCraft.have(s.d, "meat") == 1 and GameCraft.have(s.d, "herb") == 0, "and takes its materials from the stores")
	ok(str(s.d.blessing.get("spell", "")) == "rejuvenation" and int(s.d.blessing["fights"]) == 1 and int(s.d.blessing["gen"]) == s.d.gen, "and lays a blessing on the next fight")
	ok(GameCasting.blessing(s.d).has("spell"), "which the casting rules see")
	ok(int(s.camp["cooks"]) == 1, "and uses one of the camp's meals")
	var again := GameCamp.cook(s)
	ok(not bool(again["ok"]) and str(again["text"]).contains("herb"), "the herb is gone, so is the next meal")
	GameCraft.add_material(s.d, "herb", 3)
	GameCamp.cook(s)
	GameCraft.add_material(s.d, "meat", 3)
	var done := GameCamp.cook(s)
	ok(not bool(done["ok"]) and str(done["text"]).contains("cooked all"), "the fire cooks only so many")
	# the blessing is built into the next fight
	var f := _sandbox()
	GameCamp.pitch(f)
	GameCraft.add_material(f.d, "meat", 1)
	GameCraft.add_material(f.d, "herb", 1)
	GameCamp.cook(f)
	var fight := f.d.start_encounter([_wild_id()], "", 1.0, [10])
	ok(fight != null and f.d.blessing.is_empty(), "the blessing is spent as the fight begins")
	# the reload keeps it as any blessing is kept
	var g := _sandbox()
	GameCamp.pitch(g)
	GameCraft.add_material(g.d, "meat", 1)
	GameCraft.add_material(g.d, "herb", 1)
	GameCamp.cook(g)
	var parsed = JSON.parse_string(JSON.stringify(g.d.to_save()))
	var back := GameDynasty.from_dict(parsed)
	ok(back != null and str(back.blessing.get("spell", "")) == "rejuvenation", "the blessing comes back with a reloaded save")


func test_strike() -> void:
	var s := _sandbox()
	GameCamp.pitch(s)
	s.step(2)
	ok(GameCamp.active(s), "a camp stands while the heir is near")
	s.heir += Vector2i(int(GameCamp.setting("strike_tiles")) - 2, 0)
	s.step(1)
	ok(GameCamp.active(s), "a few tiles away it still stands")
	s.heir += Vector2i(5, 0)
	s.step(1)
	ok(not GameCamp.active(s) and str(s.log[-1]["text"]).contains("left behind"), "walking far away strikes it, and the journal says so")
	var t := _sandbox()
	GameCamp.pitch(t)
	t.d.world_seconds += GameCamp.setting("seconds") + 1.0
	t.step(1)
	ok(not GameCamp.active(t) and str(t.log[-1]["text"]).contains("burns out"), "and it burns out in time")
	var u := _sandbox()
	GameCamp.pitch(u)
	ok(bool(GameCamp.strike(u)["ok"]) and not GameCamp.active(u), "the heir may strike it")
	ok(not bool(GameCamp.strike(u)["ok"]), "and not twice")
	ok(bool(GameCamp.toggle(u)["ok"]) and GameCamp.active(u) and bool(GameCamp.toggle(u)["ok"]) and not GameCamp.active(u), "the toggle pitches and strikes")


func test_safety() -> void:
	# at night a creature next to the fire starts no fight
	var s := _sandbox()
	s.d.world_seconds = NIGHT
	ok(GameDay.is_night(s.d), "it is night")
	GameCamp.pitch(s)
	_put(s, "chase", s.heir_point() + Vector2(0.8, 0.0))
	ok(not s._contact() and s.d.battle == null, "a creature inside the ring starts no fight")
	s.step(3)
	ok(s.d.battle == null, "not by stepping either")
	# one outside the ring does
	var o := _sandbox()
	o.d.world_seconds = NIGHT
	GameCamp.pitch(o)
	o.heir += Vector2i(7, 0)   # beyond the ring, within strike range
	_put(o, "chase", o.heir_point() + Vector2(0.8, 0.0))
	ok(o._contact() and o.d.battle != null, "a heir who has walked beyond the ring is fought as ever")
	# by day the ring is smaller: a creature at the edge of the night's ring is no longer held off
	var day := _sandbox()
	day.d.world_seconds = NOON
	GameCamp.pitch(day)
	ok(not GameDay.is_night(day.d) and GameCamp.radius(day) == GameCamp.setting("day_radius") and GameCamp.radius(day) < GameCamp.setting("night_radius"), "the day's ring is the smaller")
	day.heir += Vector2i(3, 0)
	_put(day, "chase", day.heir_point() + Vector2(0.8, 0.0))
	ok(day._contact() and day.d.battle != null, "a creature beyond the day's ring fights")
	# no spawn inside the ring at night
	var sp := _sandbox()
	sp.d.world_seconds = NIGHT
	GameCamp.pitch(sp)
	ok(GameCamp.covers(sp, sp.heir_point().x + 2.0, sp.heir_point().y) and not GameCamp.covers(sp, sp.heir_point().x + 9.0, sp.heir_point().y), "the ring covers what is near the fire and not what is far")
	sp.refresh()
	var inside := 0
	for a in sp.creatures:
		if GameCamp.shields(sp, a):
			inside += 1
	ok(inside == 0, "nothing spawns inside the ring")
	# a spent camp (struck) holds nothing off
	var none := _sandbox()
	none.d.world_seconds = NIGHT
	ok(not GameCamp.covers(none, none.heir_point().x, none.heir_point().y), "with no camp there is no ring")


func test_escape() -> void:
	var s := _sandbox()
	GameCamp.pitch(s)
	var at := Vector2i(s.heir.x, s.heir.y)
	s.heir += Vector2i(10, 0)
	_put(s, "chase", s.heir_point() + Vector2(0.8, 0.0))
	ok(s._contact() and s.d.battle != null, "a fight begins away from the camp")
	ok(Vector2i(int(s.d.sandbox_escape["x"]), int(s.d.sandbox_escape["z"])) == at, "and a flight from it ends at the camp")
	var plain := _sandbox()
	plain.heir += Vector2i(10, 0)
	_put(plain, "chase", plain.heir_point() + Vector2(0.8, 0.0))
	ok(plain._contact() and Vector2i(int(plain.d.sandbox_escape["x"]), int(plain.d.sandbox_escape["z"])) != at, "with no camp the escape is as it was")
	var far := _sandbox()
	GameCamp.pitch(far)
	far.camp["x"] = far.heir.x - 100
	ok(GameCamp.escape_tile(far) == Vector2i(-1, -1), "a camp too far away is not the way out")


func test_use_and_menu() -> void:
	var s := _sandbox()
	ok(GameCamp.use(s).is_empty(), "with no camp Use at the fire is nothing")
	GameCamp.pitch(s)
	s.d.heir.hp = 1
	var r := s.use()
	ok(bool(r["ok"]) and s.d.heir.hp > 1 and int(s.camp["rests"]) == 1, "Use beside the fire rests when hurt")
	s.d.heir.full_heal()
	GameCraft.add_material(s.d, "meat", 1)
	GameCraft.add_material(s.d, "herb", 1)
	r = s.use()
	ok(bool(r["ok"]) and not s.d.blessing.is_empty(), "and cooks when not")
	r = s.use()
	ok(bool(r["ok"]) and str(r["text"]).contains("fire burns"), "and says how the camp stands when there is nothing to do")
	var named := s.name_at(float(s.heir.x) + 0.5, float(s.heir.y) + 0.5)
	ok(str(named.get("kind", "")) in ["camp", "heir"], "a click on the camp names it (or the heir standing there)")
	var m := {"kind": "camp", "name": "Camp", "id": "camp"}
	var ids: Array = s.thing_actions(m).map(func(a): return str(a["id"]))
	ok(ids == ["rest", "cook", "strike"], "the camp's menu is rest, cook and strike")
	var heir_ids: Array = s.thing_actions({"kind": "heir", "name": "Tess", "id": ""}).map(func(a): return str(a["id"]))
	ok("camp" in heir_ids, "the heir's menu offers to pitch or strike the camp")
	for id in ids + ["camp"]:
		ok(str(s._text("act_" + str(id))) != "", "the menu has words for '%s'" % id)
	ok(bool(GameCamp.act(s, "strike")["ok"]) and not GameCamp.active(s), "the menu's strike strikes it")
	ok(bool(GameCamp.act(s, "camp")["ok"]) and GameCamp.active(s), "and its camp pitches one")
	ok(preload("res://ui/play/world_input.gd").data()["actions"].has("world_camp") and "V" in preload("res://ui/play/world_input.gd").data()["actions"]["world_camp"]["keys"], "the Camp key is in the input data")


func test_saving() -> void:
	var s := _sandbox()
	GameCamp.pitch(s)
	var save := JSON.stringify(s.d.to_save())
	ok(save.find("camp") < 0 and save.find("\"rests\"") < 0, "a camp is not saved")
	var d := GameDynasty.new_game(5, "Old", "warrior", "faetouched", "human")
	ok(GameSandbox.start(d).camp.is_empty(), "and a fresh sandbox has none")


func test_autopilot() -> void:
	for seed_value in [3, 8]:
		var d := GameDynasty.new_game(seed_value, "Bot", "warrior", "faetouched", "human")
		d.pending_event = {}
		var met := false
		var hook := func(_dd: GameDynasty):
			if d.heir.inventory.has("tent"):
				met = true
		GameBot.live_life(d, hook)
		ok(not met and not d.heir.inventory.has("tent"), "the autopilot never meets a tent (seed %d)" % seed_value)


func test_screen() -> void:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.inventory.append("tent")
	var pane: Control = preload("res://ui/play/pack_pane.gd").new()
	pane.dynasty = d
	var said: Array = []
	pane.on_camp = func() -> String:
		said.append("camped")
		return "camped"
	root.add_child(pane)
	await process_frame
	pane._open("tent")
	ok(said.size() == 1, "a double click on the tent in the pack pitches a camp")
	pane._pick("tent")
	var uses := 0
	for c in pane._actions.get_children():
		if c is Button and (c as Button).text == "Use":
			uses += 1
			(c as Button).pressed.emit()
	ok(uses == 1 and said.size() == 2, "and so does its Use button")
	var lone: Control = preload("res://ui/play/pack_pane.gd").new()
	lone.dynasty = d
	root.add_child(lone)
	await process_frame
	ok(lone._pitch() == GameCamp.text("indoors"), "a pack with no open world says a tent is for open ground")
	pane.queue_free()
	lone.queue_free()
