## Mining as data (roadmap item 45): the data and ways to break it; the ground (layers, zones, which Age a depth is);
## ore (the same for the same seed and site, in veins, by depth band, the deep rarer and better, none in soil); digging
## (only beside open air or a dug cell, effort from hardness against Strength, ore into the family's stores); strain, the
## stages that soften rock and fatten veins, and the gateway; saving (compact, loaded clean, old saves); and that no
## dice of the dynasty's are drawn and the autopilot never digs.
## Run: godot --headless --path . -s res://tests/test_game_mine.gd
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
	test_ground()
	test_ore()
	test_dig()
	test_strain()
	test_gateway()
	test_save()
	test_untouched()
	print("mine tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func dyn(seed_value: int = 5) -> GameDynasty:
	return GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")


## Digs a straight shaft down at (x, z) from 0 to `to`.
func _shaft(d: GameDynasty, site: String, x: int, z: int, to: int) -> int:
	var n := 0
	for y in range(0, to + 1):
		if GameMine.dig(d, site, x, y, z)["ok"]:
			n += 1
	return n


# ---------------------------------------------------------------- data

func test_data() -> void:
	ok(GameMine.validate().is_empty(), "the data is sound: %s" % str(GameMine.validate()))
	var saved: Dictionary = GameMine.data().duplicate(true)
	GameMine.data()["ores"][0]["material"] = "unobtainium"
	ok(not GameMine.validate().is_empty(), "an ore of an unknown material is found")
	GameMine._cache = saved.duplicate(true)
	GameMine.data()["layers"][0]["from"] = 3
	ok(not GameMine.validate().is_empty(), "layers that do not start at the surface are found")
	GameMine._cache = saved.duplicate(true)
	GameMine.data()["layers"][2]["from"] = 2
	ok(not GameMine.validate().is_empty(), "layers out of order are found")
	GameMine._cache = saved.duplicate(true)
	GameMine.data()["stages"].pop_back()
	ok(not GameMine.validate().is_empty(), "stages that do not end at the gateway are found")
	GameMine._cache = saved.duplicate(true)
	GameMine.data()["stages"][1]["at"] = 0
	ok(not GameMine.validate().is_empty(), "stages that do not rise are found")
	GameMine._cache = saved.duplicate(true)
	GameMine.data()["ores"][0]["radius"] = 12.0
	ok(not GameMine.validate().is_empty(), "a vein bigger than a block is found")
	GameMine._cache = saved.duplicate(true)
	GameMine.data()["ores"] = GameMine.data()["ores"].filter(func(o): return o["material"] != "iron" and o["material"] != "copper")
	GameMine.data()["ores"][0]["from"] = 300
	ok(not GameMine.validate().is_empty(), "ground where no ore can form is found")
	GameMine._cache = saved.duplicate(true)
	GameMine.data()["ores"][0]["chance"] = 0.0
	ok(not GameMine.validate().is_empty(), "an ore that never forms is found")
	GameMine._cache = saved.duplicate(true)
	GameMine.data()["settings"]["yield_max"] = 0
	ok(not GameMine.validate().is_empty(), "a yield that is less than its minimum is found")
	GameMine._cache = saved.duplicate(true)
	GameMine.data()["text"].erase("gateway")
	ok(not GameMine.validate().is_empty(), "a missing line of text is found")
	GameMine._cache = saved.duplicate(true)
	GameMine.data()["stages"][2]["hardness_mult"] = 1.5
	ok(not GameMine.validate().is_empty(), "rock that gets harder with strain is found")
	GameMine._cache = saved
	ok(GameMine.validate().is_empty(), "and the data is put back")
	# every ore is a material the game has
	for o in GameMine.data()["ores"]:
		ok(GameMaterials.has(str(o["material"])), "%s is a material" % o["material"])


# ---------------------------------------------------------------- the ground

func test_ground() -> void:
	ok(GameMine.layer_at(0)["id"] == "topsoil" and GameMine.layer_at(5)["id"] == "clay" and GameMine.layer_at(20)["id"] == "stone", "the rock changes with depth")
	ok(GameMine.layer_at(399)["id"] == "worldroot" and GameMine.layer_at(60)["id"] == "deep_stone", "down to the bottom, each layer from its depth")
	var prev := 0.0
	for y in range(0, 400, 5):
		var h := float(GameMine.layer_at(y)["hardness"])
		ok(h >= prev, "the rock never gets softer going down (depth %d)" % y) if y % 100 == 0 else null
		prev = h
	ok(GameMine.zone_at(0)["id"] == "surface" and GameMine.zone_at(30)["id"] == "underground" and GameMine.zone_at(200)["id"] == "deep", "three zones: the surface, underground, the Deep")
	ok(not GameMine.layer_at(2)["ore"] and not GameMine.layer_at(8)["ore"] and GameMine.layer_at(30)["ore"], "ore forms in stone, not in soil or clay")
	# digging down goes back in time
	var d := dyn()
	d.gen = 3000   # Age 3 (an Age is 1100 generations)
	ok(d.age_number() == 3 and GameMine.age_at(d, 0) == 3, "at the surface it is the dynasty's own Age")
	ok(GameMine.age_at(d, 60) == 2 and GameMine.age_at(d, 120) == 1 and GameMine.age_at(d, 180) == 0, "and each depth_per_age down is an Age older")
	ok(GameMine.age_at(d, 399) == 0 and GameMine.age_at(dyn(), 100) == 0, "never below before the first Age; a first Age dynasty meets only that")


# ---------------------------------------------------------------- ore

func test_ore() -> void:
	var d := dyn()
	var a := GameMine.ore_at(d, "home", 10, 50, -7)
	var found := 0
	for i in 400:
		if GameMine.ore_at(d, "home", i % 30, 20 + i % 90, i / 30) != "":
			found += 1
	ok(found > 0 and found < 200, "ore is here and there, not everywhere: %d of 400" % found)
	ok(GameMine.ore_at(d, "home", 10, 50, -7) == a and GameMine.ore_at(dyn(), "home", 10, 50, -7) == a, "the same seed and site give the same ground")
	# another site or another seed is other ground
	var same_site := 0
	var same_seed := 0
	for i in 600:
		var x := i % 40
		var y := 15 + i / 40 * 10
		var base := GameMine.ore_at(d, "home", x, y, 3)
		if GameMine.ore_at(d, "elsewhere", x, y, 3) == base:
			same_site += 1
		if GameMine.ore_at(dyn(99), "home", x, y, 3) == base:
			same_seed += 1
	ok(same_site < 590 and same_seed < 590, "another site or another seed is other ground (%d and %d of 600 alike)" % [same_site, same_seed])
	# nothing in soil, above ground or below the bottom
	var none := true
	for i in 300:
		if GameMine.ore_at(d, "home", i, i % 12, i * 3) != "" or GameMine.ore_at(d, "home", i, -1 - i % 5, 0) != "" or GameMine.ore_at(d, "home", i, 401 + i, 0) != "":
			none = false
	ok(none, "no ore in the soil and clay, above the ground, or below the bottom")
	# the ore each depth band can give
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var shallow := {}
	var deep := {}
	var counts := {}
	var ore_shallow := 0
	var ore_deep := 0
	for i in 6000:
		var o1 := GameMine.ore_at(d, "home", r.randi_range(-80, 80), r.randi_range(12, 59), r.randi_range(-80, 80))
		var o2 := GameMine.ore_at(d, "home", r.randi_range(-80, 80), r.randi_range(280, 399), r.randi_range(-80, 80))
		if o1 != "":
			shallow[o1] = true
			ore_shallow += 1
		if o2 != "":
			deep[o2] = true
			ore_deep += 1
	ok(shallow.has("copper") and shallow.has("iron") and not shallow.has("gold") and not shallow.has("mithril") and not shallow.has("starmetal"), "shallow ground gives copper and iron, not gold or better: %s" % str(shallow.keys()))
	ok(deep.has("mithril") and deep.has("starmetal") and not deep.has("copper") and not deep.has("iron"), "the Deep gives mithril and starmetal, no copper or iron: %s" % str(deep.keys()))
	ok(ore_shallow > ore_deep * 3, "deep ore is rarer: %d shallow cells against %d deep" % [ore_shallow, ore_deep])
	# veins are clusters: a cell beside ore is likelier ore than a cell chosen at random
	var beside := 0
	var ore_cells := 0
	var plain := 0
	var samples := 0
	for i in 8000:
		var x := r.randi_range(-60, 60)
		var y := r.randi_range(14, 100)
		var z := r.randi_range(-60, 60)
		samples += 1
		if GameMine.ore_at(d, "home", x, y, z) != "":
			plain += 1
			ore_cells += 1
			if GameMine.ore_at(d, "home", x + 1, y, z) != "":
				beside += 1
	var base_rate := float(plain) / float(samples)
	ok(ore_cells > 50 and float(beside) / float(ore_cells) > base_rate * 4.0, "ore comes in veins: beside ore it is ore %.0f%% of the time, against %.1f%% anywhere" % [100.0 * beside / maxf(1, ore_cells), 100.0 * base_rate])
	# the veins swell with a bonus
	var swollen := 0
	var normal := 0
	for i in 3000:
		var x := r.randi_range(-60, 60)
		var y := r.randi_range(14, 100)
		var z := r.randi_range(-60, 60)
		if GameMine.ore_at(d, "home", x, y, z) != "":
			normal += 1
		if GameMine.ore_at(d, "home", x, y, z, 0.5) != "":
			swollen += 1
	ok(swollen > normal * 2, "a bonus makes the veins fatter: %d cells against %d" % [swollen, normal])
	# starmetal is the rarest of all
	for i in 20000:
		var o := GameMine.ore_at(d, "home", r.randi_range(-100, 100), r.randi_range(12, 399), r.randi_range(-100, 100))
		if o != "":
			counts[o] = int(counts.get(o, 0)) + 1
	ok(int(counts.get("starmetal", 0)) < int(counts.get("mithril", 0)) and int(counts.get("mithril", 0)) < int(counts.get("iron", 0)) and int(counts.get("starmetal", 0)) < int(counts.get("copper", 1)), "starmetal is rarer than mithril, which is rarer than iron: %s" % str(counts))
	# a vein is what the band says
	var vein := GameMine.vein_in(d, "home", 0, 40, 0)
	ok(vein.is_empty() or str(vein["ore"]) in ["starmetal", "mithril", "gold", "silver", "crystal", "iron", "copper"], "veins are of known ores")


# ---------------------------------------------------------------- digging

func test_dig() -> void:
	var d := dyn()
	d.heir.inventory.clear()
	ok(not GameMine.can_dig(d, "home", 0, -1, 0)["ok"] and GameMine.can_dig(d, "home", 0, -1, 0)["why"].contains("above"), "nothing above the ground can be dug")
	ok(not GameMine.can_dig(d, "home", 0, 401, 0)["ok"] and GameMine.can_dig(d, "home", 0, 401, 0)["why"].contains("below 400"), "nor below the bottom")
	ok(GameMine.can_dig(d, "home", 5, 0, 5)["ok"], "the first cell under the surface can be dug anywhere")
	var closed := GameMine.can_dig(d, "home", 5, 3, 5)
	ok(not closed["ok"] and closed["why"].contains("no way in"), "a cell with no open air beside it cannot: %s" % closed["why"])
	var r0 := GameMine.dig(d, "home", 5, 0, 5)
	ok(r0["ok"] and GameMine.is_dug(d, "home", 5, 0, 5) and r0["layer"] == "topsoil", "digging marks the cell: %s" % str(r0["lines"]))
	ok(not GameMine.dig(d, "home", 5, 0, 5)["ok"] and GameMine.dig(d, "home", 5, 0, 5)["why"].contains("already"), "and it cannot be dug twice")
	ok(GameMine.can_dig(d, "home", 5, 1, 5)["ok"] and GameMine.can_dig(d, "home", 6, 0, 5)["ok"] and not GameMine.can_dig(d, "home", 6, 1, 5)["ok"], "the next cell down, or beside, can; a diagonal cannot")
	ok(GameMine.dug_count(d, "home") == 1 and GameMine.dug_count(d, "elsewhere") == 0, "each site keeps its own count")
	# a shaft is a connected hole, and its runs are merged
	var n := _shaft(d, "home", 5, 5, 30)
	ok(n == 30 and GameMine.dug_count(d, "home") == 31, "a shaft digs straight down: %d more cells" % n)
	ok(d.mine["home"]["dug"]["5,5"] == [[0, 30]], "stored as one run: %s" % str(d.mine["home"]["dug"]["5,5"]))
	ok(GameMine.can_dig(d, "home", 5, 31, 5)["ok"] and not GameMine.can_dig(d, "home", 5, 33, 5)["ok"], "and the hole ends where the digging does")
	# a gap digs back in: dig a side tunnel that meets the shaft's run
	GameMine.dig(d, "home", 6, 20, 5)
	ok(GameMine.is_dug(d, "home", 6, 20, 5) and d.mine["home"]["dug"]["6,5"] == [[20, 20]], "a tunnel off the shaft is its own column")
	# effort: rock against Strength
	var weak := GameMine.effort(d, "home", 0, 100, 0, 1.0)
	var strong := GameMine.effort(d, "home", 0, 100, 0, 200.0)
	ok(weak > strong and strong >= 1, "a stronger digger needs less effort (%d against %d)" % [weak, strong])
	ok(GameMine.effort(d, "home", 0, 300, 0, 10.0) > GameMine.effort(d, "home", 0, 20, 0, 10.0) and GameMine.effort(d, "home", 0, 20, 0, 10.0) > GameMine.effort(d, "home", 0, 1, 0, 10.0), "and harder rock needs more")
	ok(GameMine.effort(d, "home", 0, 0, 0, 1000000.0) == 1, "never less than one stroke")
	# ore goes into the family's stores
	var rich := dyn()
	var got := 0
	for x in range(-20, 20):
		for y in range(12, 40):
			if GameMine.ore_at(rich, "home", x, y, 0) != "":
				got += 1
	ok(got > 0, "(there is ore to find in this ground)")
	var stored_before := GameCraft.materials(rich).duplicate()
	var ore_cell := Vector3i(0, 0, 0)
	var found := false
	for x in range(-20, 20):
		for y in range(12, 40):
			if not found and GameMine.ore_at(rich, "home", x, y, 0) != "":
				ore_cell = Vector3i(x, y, 0)
				found = true
	# open a path to it: dig down at its column
	var res := {}
	for y in range(0, ore_cell.y + 1):
		res = GameMine.dig(rich, "home", ore_cell.x, y, 0)
	ok(res["ok"] and res["ore"] != "" and int(res["qty"]) >= 1 and GameCraft.have(rich, str(res["ore"])) >= int(res["qty"]), "striking ore puts it in the stores: %s" % str(res["lines"]))
	ok(str(res["lines"][0]).contains("strikes"), "and says so: %s" % str(res["lines"][0]))
	ok(stored_before.is_empty(), "(and nothing was there before)")
	var plain := dyn()
	var pr := GameMine.dig(plain, "home", 0, 0, 0)
	ok(pr["ore"] == "" and pr["qty"] == 0 and GameCraft.materials(plain).is_empty(), "plain rock yields nothing")
	# a digger need not be the heir
	var anyone := GameMine.dig(dyn(), "home", 1, 0, 1, 50.0)
	ok(anyone["ok"] and int(anyone["effort"]) >= 1, "the digger's Strength can be given")


# ---------------------------------------------------------------- strain and the stages

func test_strain() -> void:
	var d := dyn()
	ok(GameMine.strain_at(d, "home", 0, 0) == 0.0 and GameMine.stage_of(0.0)["id"] == "quiet", "new ground is quiet")
	ok(GameMine.stage_of(40.0)["id"] == "tremors" and GameMine.stage_of(39.9)["id"] == "quiet" and GameMine.stage_of(120.0)["id"] == "cracked" and GameMine.stage_of(999.0)["id"] == "hollow" and GameMine.stage_of(5000.0)["id"] == "gateway", "stages begin at their strain")
	GameMine.dig(d, "home", 0, 0, 0)
	var s1 := GameMine.strain_at(d, "home", 0, 0)
	ok(s1 > 0.0 and s1 < 1.0, "a shallow stroke strains the ground a little: %.2f" % s1)
	_shaft(d, "home", 0, 0, 100)
	var s2 := GameMine.strain_at(d, "home", 0, 0)
	ok(s2 > 40.0, "a shaft to 100 builds real strain: %.1f" % s2)
	ok(GameMine.strain_at(d, "home", 15, 15) == s2 and GameMine.strain_at(d, "home", 16, 0) == 0.0 and GameMine.strain_at(d, "home", -1, 0) == 0.0, "strain is shared across a region (16 by 16) and stops at its edge")
	ok(GameMine.strain_at(d, "elsewhere", 0, 0) == 0.0, "another site is unmarked")
	# deeper digging strains more than shallow digging
	var shallow := dyn()
	var deep := dyn()
	for i in 40:
		GameMine.dig(shallow, "s", i, 0, 0)
	_shaft(deep, "s", 0, 0, 39)
	ok(GameMine.strain_at(deep, "s", 0, 0) > GameMine.strain_at(shallow, "s", 0, 0), "the deeper the stroke the greater the strain")
	# stages are announced once, as they are reached
	var d2 := dyn()
	var changes := 0
	var lines := 0
	for y in range(0, 101):
		var r := GameMine.dig(d2, "home", 0, y, 0)
		if r["stage_changed"]:
			changes += 1
			lines += 1 if str(r["lines"].back()).contains("The ground around the shaft is now") else 0
	ok(changes >= 1 and changes == lines, "each new stage is told once: %d" % changes)
	# the stages ease the rock and fatten the veins
	var quiet := GameMine.effort(dyn(), "x", 0, 150, 0, 5.0)
	var hardened := dyn()
	hardened.mine = {"x": {"strain": {"0,0": 700.0}}}
	ok(GameMine.effort(hardened, "x", 0, 150, 0, 5.0) < quiet, "rock cuts easier in a strained region: %d against %d" % [GameMine.effort(hardened, "x", 0, 150, 0, 5.0), quiet])
	var calm := dyn()
	var wild := dyn()
	wild.mine = {"x": {"strain": {"0,0": 700.0}}}
	var ore_calm := 0
	var ore_wild := 0
	for i in 2500:
		var x := i % 15
		var y := 14 + i / 15 % 90
		var z := i % 7
		if GameMine.ore_here(calm, "x", x, y, z) != "":
			ore_calm += 1
		if GameMine.ore_here(wild, "x", x, y, z) != "":
			ore_wild += 1
	ok(ore_wild > ore_calm, "and the veins are fatter: %d ore cells against %d" % [ore_wild, ore_calm])
	ok(GameMine.ore_here(calm, "x", 40, 50, 40) == GameMine.ore_at(calm, "x", 40, 50, 40), "(a quiet region reads as the plain ground)")


func test_gateway() -> void:
	var d := dyn()
	ok(GameMine.gateways(d, "home").is_empty() and not GameMine.gateway_in(d, "home", 0, 0), "no gateway at first")
	# put a region on the edge of the gateway stage and dig the cell that tips it
	d.mine = {"home": {"dug": {"3,3": [[0, 200]]}, "strain": {"0,0": 999.9}}}
	var r := GameMine.dig(d, "home", 3, 201, 3)
	ok(r["ok"] and r["gateway"] and r["stage"] == "gateway" and r["stage_changed"], "the stroke that tips the last stage opens a gateway: %s" % str(r["lines"]))
	ok(r["lines"].back().contains("underworld"), "and says so: %s" % r["lines"].back())
	ok(GameMine.gateway_in(d, "home", 3, 3) and GameMine.gateway_in(d, "home", 15, 15) and not GameMine.gateway_in(d, "home", 16, 0), "it is in that region and no other")
	ok(GameMine.gateways(d, "home")[0]["at"] == [3, 201, 3] and GameMine.gateways(d, "home")[0]["region"] == "0,0", "recorded where it opened")
	var again := GameMine.dig(d, "home", 3, 202, 3)
	ok(again["ok"] and not again["gateway"] and GameMine.gateways(d, "home").size() == 1, "digging on does not open it twice")
	# a region short of the stage does not open one
	var short := dyn()
	short.mine = {"home": {"dug": {"3,3": [[0, 200]]}, "strain": {"0,0": 500.0}}}
	var s := GameMine.dig(short, "home", 3, 201, 3)
	ok(s["ok"] and not s["gateway"] and s["stage"] == "weeping", "short of the last stage there is none")
	# another region has its own strain
	var other := dyn()
	other.mine = {"home": {"dug": {"40,40": [[0, 10]]}, "strain": {"0,0": 999.9}}}
	var o := GameMine.dig(other, "home", 40, 11, 40)
	ok(o["ok"] and not o["gateway"], "strain in one region does not open a gateway in another")


# ---------------------------------------------------------------- saving

func test_save() -> void:
	var d := dyn()
	ok(d.mine.is_empty() and not d.to_dict().has("mine"), "a new dynasty has dug nothing and saves nothing")
	_shaft(d, "home", 2, 2, 60)
	GameMine.dig(d, "home", 3, 30, 2)
	_shaft(d, "other", 0, 0, 5)
	var d2 := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(GameMine.dug_count(d2, "home") == GameMine.dug_count(d, "home") and GameMine.is_dug(d2, "home", 2, 45, 2) and GameMine.is_dug(d2, "home", 3, 30, 2) and not GameMine.is_dug(d2, "home", 2, 61, 2), "the dug ground survives a save and load")
	ok(is_equal_approx(GameMine.strain_at(d2, "home", 2, 2), GameMine.strain_at(d, "home", 2, 2)) and GameMine.dug_count(d2, "other") == 6, "and its strain, and each site")
	ok(JSON.stringify(d.to_dict()["mine"]).length() < 700, "as runs, not cells: %d characters for 70 cells" % JSON.stringify(d.to_dict()["mine"]).length())
	var g := dyn()
	g.mine = {"home": {"dug": {"0,0": [[0, 9]]}, "strain": {"0,0": 999.9}}}
	GameMine.dig(g, "home", 0, 10, 0)
	var g2 := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	ok(GameMine.gateway_in(g2, "home", 0, 0), "a gateway survives a save and load")
	# damaged and old saves
	var raw := d.to_dict()
	raw["mine"] = {"home": {"dug": {"1,1": [[0, 5], [3, 9], [-4, 2], [7, 9999], "x", [2]], "bad key": [[0, 1]], "2,2": "nope"}, "strain": {"1,1": 3.5, "0,0": -4.0, "x": 9.0}, "gateways": [{"region": "1,1", "at": [1, 2, 3]}, {"region": "zz", "at": [1, 2, 3]}, {"region": "2,2", "at": [1, 2]}]}, "": {"dug": {"0,0": [[0, 1]]}}, "junk": 5}
	var d3 := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(raw)))
	ok(d3.mine.keys() == ["home"] and d3.mine["home"]["dug"].keys() == ["1,1"] and d3.mine["home"]["dug"]["1,1"] == [[0, 9]], "damaged cells are dropped and good runs merged: %s" % str(d3.mine))
	ok(d3.mine["home"]["strain"] == {"1,1": 3.5} and d3.mine["home"]["gateways"].size() == 1 and d3.mine["home"]["gateways"][0]["at"] == [1, 2, 3], "and damaged strain and gateways with them")
	raw["mine"] = "garbage"
	ok(GameDynasty.from_dict(JSON.parse_string(JSON.stringify(raw))).mine.is_empty(), "a mine of the wrong type loads as none")
	var old := dyn().to_dict()
	old.erase("mine")
	ok(GameDynasty.from_dict(old).mine.is_empty(), "an old save with no mine loads")


# ---------------------------------------------------------------- nothing else moves

func test_untouched() -> void:
	var d := dyn()
	var before := d.rng.state
	_shaft(d, "home", 0, 0, 80)
	var probe := GameMine.ore_at(d, "home", 9, 70, 9)
	ok(d.rng.state == before and probe == GameMine.ore_at(d, "home", 9, 70, 9), "mining draws nothing from the dynasty's dice")
	var classes := GameData.starting_ids(GameData.classes)
	var dug := 0
	for sd in 3:
		var a := GameDynasty.new_game(sd + 1, "", classes[sd % classes.size()], "faetouched", "human")
		for g in 3:
			GameBot.live_life(a)
			dug += a.mine.size()
			if a.state != "succession":
				break
			GameBot.choose_best(a)
	ok(dug == 0, "an autopilot life digs nothing")
