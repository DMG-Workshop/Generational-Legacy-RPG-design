## Hazards and tools in the mine (roadmap item 45): the roof may fall at a cell just dug, more in a shaken region and deeper
## down, never at the surface or in a quiet shaft; a timber prop takes the weight if the family has oak, otherwise the heir is
## struck but never killed; the roll is keyed on the seed and the cell, never the dynasty's dice; the Smithy's levels give the
## picks an extra ore every `tool_levels_per_ore`; the sandbox's dig logs the hazard.
## Run: godot --headless --path . -s res://tests/test_game_mine_hazards.gd
extends SceneTree

var fails := 0
var checks := 0
const SITE := "home"


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
	test_chance()
	test_hazard()
	test_tools()
	test_sandbox()
	print("mine hazard tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh() -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


## A dynasty whose region at (x, z) has strain enough for a stage.
func _strained(strain: float) -> GameDynasty:
	var d := _fresh()
	d.mine[SITE] = {"dug": {}, "strain": {GameMine.region_key(0, 0): strain}, "gateways": []}
	return d


func test_data() -> void:
	ok(GameMine.validate().is_empty(), "the shipped data passes: %s" % str(GameMine.validate()))
	var s: Dictionary = GameMine.data()["settings"]
	var keep: Variant = s["hazard_max"]
	s["hazard_max"] = 2.0
	ok(not GameMine.validate().is_empty(), "a hazard ceiling above 1 is caught")
	s["hazard_max"] = keep
	var prop: Variant = s["prop_material"]
	s["prop_material"] = "unobtainium"
	ok(not GameMine.validate().is_empty(), "a prop that is not a material is caught")
	s["prop_material"] = prop
	var st: Dictionary = GameMine.data()["stages"][1]
	var h: Variant = st["hazard"]
	st["hazard"] = -0.5
	ok(not GameMine.validate().is_empty(), "a stage with a negative hazard is caught")
	st["hazard"] = h
	var txt: Variant = GameMine.data()["text"]["cave_in"]
	GameMine.data()["text"].erase("cave_in")
	ok(not GameMine.validate().is_empty(), "missing hazard text is caught")
	GameMine.data()["text"]["cave_in"] = txt
	ok(GameMine.validate().is_empty(), "and mending the data clears it")


func test_chance() -> void:
	ok(GameMine.hazard_chance(_fresh(), SITE, 0, 5, 0) == 0.0 and GameMine.hazard_chance(_fresh(), SITE, 0, 200, 0) == 0.0, "a quiet shaft never falls, however deep")
	var d := _strained(150.0)
	var shallow := GameMine.hazard_chance(d, SITE, 0, 5, 0)
	var deep := GameMine.hazard_chance(d, SITE, 0, 200, 0)
	ok(shallow > 0.0 and deep > shallow, "a shaken region can fall, deeper more: %.3f then %.3f" % [shallow, deep])
	var worse := GameMine.hazard_chance(_strained(700.0), SITE, 0, 5, 0)
	ok(worse > shallow, "and a more shaken one more still: %.3f" % worse)
	ok(GameMine.hazard_chance(_strained(700.0), SITE, 0, 4000, 0) <= float(GameMine.setting("hazard_max")), "but never beyond the ceiling")


func test_hazard() -> void:
	var d := _strained(700.0)
	d.heir.hp = d.heir.max_hp()
	var hit := Vector2i(-1, -1)
	var miss := Vector2i(-1, -1)
	for y in range(0, 80):
		for x in range(0, 15):
			var probe := _strained(700.0)
			var r := GameMine.hazard(probe, SITE, x, y, 0)
			if bool(r["hit"]) and hit.x < 0:
				hit = Vector2i(x, y)
			if not bool(r["hit"]) and miss.x < 0:
				miss = Vector2i(x, y)
	ok(hit.x >= 0 and miss.x >= 0, "some cells fall and some do not (hit %s, miss %s)" % [str(hit), str(miss)])
	# no prop: the heir is struck
	var a := _strained(700.0)
	a.heir.hp = a.heir.max_hp()
	var before := a.heir.hp
	var rng := a.rng.state
	var r := GameMine.hazard(a, SITE, hit.x, hit.y, 0)
	ok(bool(r["hit"]) and not bool(r["propped"]) and int(r["damage"]) >= 1 and a.heir.hp == before - int(r["damage"]), "with no timber the heir is struck: %s" % str(r))
	ok(str(r["text"]).contains("loses") and str(r["text"]).contains(a.heir.name), "and told so: %s" % r["text"])
	ok(a.rng.state == rng, "no dice of the dynasty's are drawn")
	var expected := int(round(float(a.heir.max_hp()) * float(GameMine.setting("hazard_hp_pct"))))
	ok(int(r["damage"]) == maxi(1, expected), "by the share of their health the data says: %d" % int(r["damage"]))
	# the same cell is the same fall
	var b := _strained(700.0)
	b.heir.hp = b.heir.max_hp()
	var r2 := GameMine.hazard(b, SITE, hit.x, hit.y, 0)
	ok(r2 == r, "the same cell in the same ground falls the same way")
	var c := _strained(700.0)
	ok(not bool(GameMine.hazard(c, SITE, miss.x, miss.y, 0)["hit"]), "and a cell that held holds")
	# a prop
	var p := _strained(700.0)
	p.heir.hp = p.heir.max_hp()
	GameCraft.add_material(p, "oak", 3)
	var pr := GameMine.hazard(p, SITE, hit.x, hit.y, 0)
	ok(bool(pr["propped"]) and int(pr["damage"]) == 0 and p.heir.hp == p.heir.max_hp(), "with timber a prop takes the weight and the heir is unhurt")
	ok(GameCraft.have(p, "oak") == 2, "at the cost of one oak")
	# never killed
	var k := _strained(700.0)
	k.heir.hp = 1
	var kr := GameMine.hazard(k, SITE, hit.x, hit.y, 0)
	ok(bool(kr["hit"]) and k.heir.hp == 1 and int(kr["damage"]) == 0 and str(kr["text"]).contains("clear"), "an heir on 1 health is never killed by the roof: %s" % kr["text"])
	var k2 := _strained(700.0)
	k2.heir.hp = 3
	GameMine.hazard(k2, SITE, hit.x, hit.y, 0)
	ok(k2.heir.hp >= 1, "nor one on 3")


func test_tools() -> void:
	var plain := _fresh()
	var forged := _fresh()
	forged.house[GameHouse.SMITHY] = 2
	ok(GameMine.tool_bonus(plain) == 0 and GameMine.tool_bonus(forged) == 1, "a level-2 Smithy gives the picks one more ore")
	var one := _fresh()
	one.house[GameHouse.SMITHY] = 1
	ok(GameMine.tool_bonus(one) == 0, "level 1 gives none yet")
	# dig the same shafts in both and compare the yield at the first vein
	var found := false
	for x in range(0, 40):
		if found:
			break
		for y in range(0, 70):
			var ore := GameMine.ore_here(plain, SITE, x, y, 0)
			var q0 := int(GameMine.dig(plain, SITE, x, y, 0)["qty"])
			var q1 := int(GameMine.dig(forged, SITE, x, y, 0)["qty"])
			if ore != "" and q0 > 0:
				found = true
				ok(q1 == q0 + 1, "the same vein gives one more: %d against %d" % [q1, q0])
				break
	ok(found, "(found a vein in the shafts)")


func test_sandbox() -> void:
	var d := _fresh()
	d.mine[GameWorldGen.MINE_SITE] = {"dug": {}, "strain": {GameMine.region_key(0, 0): 700.0}, "gateways": []}
	d.heir.hp = d.heir.max_hp()
	var s := GameSandbox.start(d)
	s.creatures.clear()
	s.heir = Vector2i(0, 0)
	var seen := false
	for x in range(0, 15):
		if seen:
			break
		for z in range(0, 15):
			s.heir = Vector2i(x, z)
			var logged := s.log.size()
			var r := s.dig(0)
			if bool(r["ok"]) and bool(r["hazard"]["hit"]):
				seen = true
				ok(s.log.size() == logged + 2 and str(s.log[s.log.size() - 1]["kind"]) == "hazard", "a fall is logged after the dig")
				break
	ok(seen, "(a fall happened while digging a row of cells)")
