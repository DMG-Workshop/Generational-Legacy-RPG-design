## Spawn tables (roadmap item 47): the data and ways to break it; that the hunt's pool is exactly what it always was (a copy
## of the old code is compared, place by place and era by era, in order); the weighted table by surface biome, depth, era,
## season, weather and night; picking by weight; the table at a dungeon's mouth being the hunt's own pool; the tile's
## context (water, towns, soil, the surface, the underground, a dungeon's mouth) and a keyed roll for each tile and time;
## depth getting more dangerous; and that nothing of the dynasty's moves.
## Run: godot --headless --path . -s res://tests/test_game_spawn.gd
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
	test_hunt_pool()
	test_table()
	test_modifiers()
	test_pick()
	test_place_table()
	test_context()
	test_spawn_at()
	test_depth()
	test_reach()
	test_untouched()
	print("spawn tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func dyn(seed_value: int = 5) -> GameDynasty:
	return GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")


func ids(rows: Array) -> Array:
	return rows.map(func(r): return str(r["id"]))


# ---------------------------------------------------------------- data

func test_data() -> void:
	ok(GameSpawn.validate().is_empty(), "the data is sound: %s" % str(GameSpawn.validate()))
	ok(GameSpawn.wild().size() == 27 and GameSpawn.data()["creatures"].size() == 27, "27 wild creatures, each with an entry")
	var saved: Dictionary = GameSpawn.data().duplicate(true)
	GameSpawn.data()["creatures"].erase("wolf")
	ok(not GameSpawn.validate().is_empty(), "a wild creature with no entry is found")
	GameSpawn._cache = saved.duplicate(true)
	GameSpawn.data()["creatures"]["wolf"]["surface"] = ["volcanic"]
	ok(not GameSpawn.validate().is_empty(), "a surface biome the creature's own biomes do not give is found")
	GameSpawn._cache = saved.duplicate(true)
	GameSpawn.data()["creatures"]["wolf"]["surface"] = ["no_such_biome"]
	ok(not GameSpawn.validate().is_empty(), "an unknown surface biome is found")
	GameSpawn._cache = saved.duplicate(true)
	GameSpawn.data()["creatures"]["wolf"]["depth"] = [20, 50]
	ok(not GameSpawn.validate().is_empty(), "an underground band for a creature with no underground biome is found")
	GameSpawn._cache = saved.duplicate(true)
	GameSpawn.data()["creatures"]["goblin"]["depth"] = [90, 20]
	ok(not GameSpawn.validate().is_empty(), "a depth band that runs backwards is found")
	GameSpawn._cache = saved.duplicate(true)
	GameSpawn.data()["creatures"]["goblin"]["depth"] = [20, 900]
	ok(not GameSpawn.validate().is_empty(), "a depth band below the mining ground is found")
	GameSpawn._cache = saved.duplicate(true)
	GameSpawn.data()["creatures"]["wolf"]["seasons"] = {"monsoon": 2.0}
	ok(not GameSpawn.validate().is_empty(), "an unknown season is found")
	GameSpawn._cache = saved.duplicate(true)
	GameSpawn.data()["creatures"]["wolf"]["weather"] = {"rain": 0}
	ok(not GameSpawn.validate().is_empty(), "a weather multiplier of nothing is found")
	GameSpawn._cache = saved.duplicate(true)
	GameSpawn.data()["creatures"]["wolf"]["weight"] = 0
	ok(not GameSpawn.validate().is_empty(), "a creature of no weight is found")
	GameSpawn._cache = saved.duplicate(true)
	GameSpawn.data()["creatures"]["wolf"]["surface"] = []
	ok(not GameSpawn.validate().is_empty(), "a creature that lives nowhere is found")
	GameSpawn._cache = saved.duplicate(true)
	GameSpawn.data()["settings"]["surface_density"].erase("swamp")
	ok(not GameSpawn.validate().is_empty(), "a surface biome with no density is found")
	GameSpawn._cache = saved.duplicate(true)
	GameSpawn.data()["creatures"]["ghost"] = {"surface": ["plains"], "weight": 1.0}
	ok(not GameSpawn.validate().is_empty(), "an entry for a creature that does not exist is found")
	GameSpawn._cache = saved
	ok(GameSpawn.validate().is_empty(), "and the data is put back")


# ---------------------------------------------------------------- the hunt's pool

## The pool as GameDynasty.start_hunt computed it before this item (a copy of that code, kept here as the reference).
func _old_pool(era: int, biomes: Array) -> Array:
	var in_era := GameData.creatures.filter(func(c): return not c.get("boss", false) and not c.get("farm", false) and c["min_gen"] <= era and era <= c["max_gen"])
	if in_era.is_empty():
		in_era = GameData.creatures.filter(func(c): return not c.get("boss", false) and not c.get("farm", false))
	var pool := in_era.filter(func(c): return (c.get("biomes", []) as Array).any(func(b): return b in biomes))
	if pool.is_empty():
		pool = in_era
	return pool


func test_hunt_pool() -> void:
	var same := 0
	var total := 0
	var eras := [1, 2, 24, 25, 29, 30, 54, 55, 56, 80, 81, 90, 100, 111, 149, 150, 159, 160, 200, 201, 349, 350, 360, 400, 401, 600, 650, 700, 701, 1000, 1100]
	for l in GameData.world["locations"]:
		for era in eras:
			total += 1
			if GameSpawn.hunt_pool(era, l["biomes"]) == _old_pool(era, l["biomes"]):
				same += 1
	ok(same == total, "the hunt's pool is the old pool, in the same order, at every place and in %d eras: %d of %d" % [eras.size(), same, total])
	# the fallbacks: a place of no known biome, and an era nothing roams
	ok(GameSpawn.hunt_pool(5, ["no_such_biome"]) == _old_pool(5, ["no_such_biome"]) and GameSpawn.hunt_pool(5, ["no_such_biome"]).size() > 3, "a place no creature roams falls back to everything in the era")
	ok(GameSpawn.hunt_pool(5000, ["plains"]) == _old_pool(5000, ["plains"]) and not GameSpawn.hunt_pool(5000, ["plains"]).is_empty(), "an era nothing roams falls back to everything wild")
	var pool := GameSpawn.hunt_pool(1, ["swamp"])
	ok(pool.all(func(c): return not c.get("boss", false) and not c.get("farm", false)), "no legend and no farm animal is ever in it")
	# and a hunt really draws from it: every foe of a seeded hunt is in the pool for its place and era
	var d := dyn(3)
	var from_pool := true
	for i in 12:
		var b := d.start_hunt("hunt")
		var legal := GameSpawn.hunt_pool(d.era_gen(), d.world.here().get("biomes", [])).map(func(c): return str(c["name"]))
		for e in b.enemies:
			if str(e["name"]).trim_prefix("Elite ") not in legal:
				from_pool = false
		d.battle = null
		d.loot = {}
		d.heir.hp = d.heir.max_hp()
	ok(from_pool, "a hunt's foes come from the pool for its place and era")


# ---------------------------------------------------------------- the weighted table

func test_table() -> void:
	var forest := GameSpawn.table(GameSpawn.context("forest", -1, 50))
	ok(ids(forest).has("wolf") and not ids(forest).has("ogre") and not ids(forest).has("fire_imp") and not ids(forest).has("harpy"), "a forest has wolves, not ogres, fire imps or harpies: %s" % str(ids(forest)))
	ok(ids(GameSpawn.table(GameSpawn.context("volcanic", -1, 400))).has("ash_wyrm") and ids(GameSpawn.table(GameSpawn.context("tundra", -1, 200))).has("frost_wolf") and not ids(GameSpawn.table(GameSpawn.context("tundra", -1, 200))).has("ash_wyrm"), "wyrms on the volcanic ground and frost wolves on the tundra")
	var sorted := true
	for i in range(1, forest.size()):
		if str(forest[i - 1]["id"]) > str(forest[i]["id"]):
			sorted = false
	ok(sorted and forest.all(func(r): return float(r["weight"]) > 0.0), "a table is sorted by id with every weight above 0")
	# the era: nothing is met before its time
	var early := ids(GameSpawn.table(GameSpawn.context("hills", -1, 5)))
	var mid := ids(GameSpawn.table(GameSpawn.context("hills", -1, 200)))
	ok(early.has("goblin") and not early.has("ogre") and mid.has("ogre") and not mid.has("goblin"), "the era sets who roams: goblins early, ogres later, goblins gone by 200: %s then %s" % [str(early), str(mid)])
	ok(GameSpawn.table(GameSpawn.context("hills", -1, 5000)).is_empty(), "past the last era nothing roams")
	# no legend and no farm animal, ever
	var all_ids := {}
	for biome in GameWorldGen.data()["biomes"]:
		for era in [1, 60, 200, 400, 700, 1000]:
			for row in GameSpawn.table(GameSpawn.context(str(biome), -1, era)):
				all_ids[row["id"]] = true
	for depth in [20, 100, 200, 350]:
		for row in GameSpawn.table(GameSpawn.context("", depth, 700)):
			all_ids[row["id"]] = true
	for id in all_ids:
		var spec: Dictionary = {}
		for c in GameData.creatures:
			if c["id"] == id:
				spec = c
		ok(not spec.get("boss", false) and not spec.get("farm", false), "%s is a wild creature" % id)
	# the surface and the underground are different tables
	var surf := ids(GameSpawn.table(GameSpawn.context("mountains", -1, 100)))
	var under := ids(GameSpawn.table(GameSpawn.context("", 100, 100)))
	ok(surf.has("harpy") and not under.has("harpy") and under.has("skeleton") and not surf.has("skeleton"), "harpies fly over mountains and skeletons walk underground")


func test_modifiers() -> void:
	var base := GameSpawn.weight_of("wolf", GameSpawn.context("forest", -1, 5))
	ok(base == 1.0, "a creature's base weight is its own")
	ok(GameSpawn.weight_of("wolf", GameSpawn.context("forest", -1, 5, "winter")) == 2.0 and GameSpawn.weight_of("wolf", GameSpawn.context("forest", -1, 5, "summer")) == 1.0, "wolves are twice as common in winter")
	ok(GameSpawn.weight_of("slime", GameSpawn.context("swamp", -1, 5, "", "rain")) == 2.5 and GameSpawn.weight_of("slime", GameSpawn.context("swamp", -1, 5, "", "clear")) == 1.0, "slimes love rain")
	ok(GameSpawn.weight_of("skeleton", GameSpawn.context("", 50, 50, "", "", true)) == 2.5 and GameSpawn.weight_of("skeleton", GameSpawn.context("", 50, 50, "", "", false)) == 1.0, "the undead are likelier at night")
	ok(GameSpawn.weight_of("frost_wolf", GameSpawn.context("tundra", -1, 200, "winter", "snow")) == 7.5, "modifiers multiply: winter and snow bring frost wolves out (2.5 x 3.0)")
	ok(GameSpawn.weight_of("frost_wolf", GameSpawn.context("tundra", -1, 200, "summer", "heat")) < 0.5, "and summer sends them away")
	ok(GameSpawn.weight_of("no_such", GameSpawn.context("forest", -1, 5)) == 0.0, "an unknown creature has no weight")
	# a table shifts with the season and the weather
	var calm := GameSpawn.table(GameSpawn.context("mountains", -1, 170, "summer", "clear"))
	var snow := GameSpawn.table(GameSpawn.context("mountains", -1, 170, "summer", "storm"))
	var share := func(rows: Array, id: String) -> float:
		var total := 0.0
		var mine := 0.0
		for r in rows:
			total += float(r["weight"])
			if r["id"] == id:
				mine += float(r["weight"])
		return mine / maxf(0.0001, total)
	ok(ids(calm).has("harpy") and ids(calm).has("ogre") and share.call(snow, "harpy") > share.call(calm, "harpy"), "in a storm harpies are a bigger share of the mountains (%.2f against %.2f)" % [share.call(snow, "harpy"), share.call(calm, "harpy")])
	var dusk := GameSpawn.table(GameSpawn.context("", 100, 300, "", "", false))
	var night := GameSpawn.table(GameSpawn.context("", 100, 300, "", "", true))
	ok(share.call(night, "wraith") > share.call(dusk, "wraith") and share.call(night, "wraith") > 0.0, "at night the wraiths are a bigger share underground")


func test_pick() -> void:
	var rows := [{"id": "a", "weight": 1.0}, {"id": "b", "weight": 3.0}]
	var r := RandomNumberGenerator.new()
	r.seed = 9
	var got := {"a": 0, "b": 0}
	for i in 8000:
		got[GameSpawn.pick(r, rows)] += 1
	ok(got["b"] > got["a"] * 2.5 and got["b"] < got["a"] * 3.6, "picking follows the weights: %s" % str(got))
	ok(GameSpawn.pick(r, []) == "" and GameSpawn.pick(r, [{"id": "x", "weight": 0.0}]) == "", "an empty table gives nothing")
	var r1 := RandomNumberGenerator.new()
	r1.seed = 4
	var r2 := RandomNumberGenerator.new()
	r2.seed = 4
	ok(GameSpawn.pick(r1, rows) == GameSpawn.pick(r2, rows), "the same dice pick the same creature")
	# the real table: forest wolves and goblins in proportion
	var forest := GameSpawn.table(GameSpawn.context("forest", -1, 10))
	var counts := {}
	var r3 := RandomNumberGenerator.new()
	r3.seed = 1
	for i in 6000:
		var id := GameSpawn.pick(r3, forest)
		counts[id] = int(counts.get(id, 0)) + 1
	ok(counts.has("wolf") and counts.has("goblin") and abs(counts["wolf"] - counts["goblin"]) < 500, "an early forest is wolves and goblins in even measure: %s" % str(counts))


# ---------------------------------------------------------------- the place's own table

func test_place_table() -> void:
	for l in GameData.world["locations"]:
		var pool_ids: Array = GameSpawn.hunt_pool(200, l["biomes"]).map(func(c): return str(c["id"]))
		var tbl := ids(GameSpawn.table(GameSpawn.context("", -1, 200, "", "", false, str(l["id"]))))
		var every := true
		for id in tbl:
			if id not in pool_ids:
				every = false
		ok(every, "%s's table holds only creatures of the hunt's pool there" % l["id"])
	var barrow := ids(GameSpawn.table(GameSpawn.context("", -1, 100, "", "", false, "hollow_barrow")))
	ok(barrow.has("skeleton") and barrow.has("ghoul") and not barrow.has("harpy"), "the barrow breeds the undead: %s" % str(barrow))
	var rift := ids(GameSpawn.table(GameSpawn.context("", -1, 400, "", "", false, "the_rift")))
	ok(rift.has("void_stalker") and rift.has("shard_crawler") and not barrow.has("void_stalker"), "the rift breeds its own: %s" % str(rift))


# ---------------------------------------------------------------- tiles

func test_context() -> void:
	var d := dyn()
	d.gen = 100
	ok(GameSpawn.context_at(d, -5, -1, 100).is_empty() and GameSpawn.context_at(d, 0, -1, 0).is_empty(), "open water spawns nothing")
	var h := GameWorldGen.anchor("hearthmere")
	ok(GameSpawn.context_at(d, int(h["x"]), -1, int(h["z"])).is_empty(), "a town is safe")
	var barrow := GameWorldGen.anchor("hollow_barrow")
	var bc := GameSpawn.context_at(d, int(barrow["x"]), -1, int(barrow["z"]))
	ok(bc["place"] == "hollow_barrow" and bc["zone"] == "place", "a dungeon's mouth is its place's own: %s" % str(bc))
	ok(GameSpawn.context_at(d, 300, 3, 300).is_empty() and GameSpawn.context_at(d, 300, 11, 300).is_empty(), "the soil and clay above the stone spawn nothing")
	var u := GameSpawn.context_at(d, 300, 50, 300)
	var deep := GameSpawn.context_at(d, 300, 200, 300)
	ok(u["zone"] == "underground" and u["depth"] == 50 and deep["zone"] == "deep" and deep["depth"] == 200, "underground, by zone and depth")
	# a surface tile in the wild
	var wild := {}
	for i in 400:
		var c := GameSpawn.context_at(d, 40 + i, -1, 300)
		if not c.is_empty() and c["zone"] == "surface":
			wild = c
			break
	ok(not wild.is_empty() and GameWorldGen.data()["biomes"].has(wild["surface"]), "a tile in the wild has a surface biome: %s" % str(wild.get("surface")))
	var probe_x := 40
	while GameSpawn.context_at(d, probe_x, -1, 300).is_empty() or GameSpawn.context_at(d, probe_x, -1, 300)["zone"] != "surface":
		probe_x += 1
	ok(GameSpawn.context_at(d, probe_x, -1, 300)["surface"] == GameWorldGen.tile(d, probe_x, 300)["biome"], "and it is the biome the world generator gives that tile")
	ok(wild["era"] == d.era_gen() and wild["season"] == d.world.season()["id"] and wild["weather"] == d.world.weather_id, "and the era, the season and the weather of the world")
	ok(GameSpawn.density({}) == 0.0 and GameSpawn.density(bc) == 0.3 and GameSpawn.density(u) == 0.12 and GameSpawn.density(deep) == 0.16, "the density by zone")
	var night := GameSpawn.context_at(d, 40, -1, 300, true)
	var day := GameSpawn.context_at(d, 40, -1, 300, false)
	ok(night.is_empty() or GameSpawn.density(night) > GameSpawn.density(day), "and more of it at night on the surface")


func test_spawn_at() -> void:
	var d := dyn()
	d.gen = 100
	# the same world, place and time give the same creature
	var same := 0
	var differ := 0
	var some := 0
	for i in 600:
		var x := 60 + (i * 37) % 500
		var z := 60 + (i * 91) % 500
		var a := GameSpawn.spawn_at(d, x, -1, z, 3)
		if GameSpawn.spawn_at(d, x, -1, z, 3) == a:
			same += 1
		if GameSpawn.spawn_at(d, x, -1, z, 4) != a:
			differ += 1
		if a != "":
			some += 1
	ok(same == 600, "the same tile and time give the same creature, every time")
	ok(some > 15 and some < 200 and differ > 15, "creatures are here and there, not everywhere, and the time slot moves them (%d of 600 hold one, %d change with the slot)" % [some, differ])
	# never in a town or the sea
	var town := GameWorldGen.anchor("kingshold")
	var none := true
	for slot in 200:
		if GameSpawn.spawn_at(d, int(town["x"]), -1, int(town["z"]), slot) != "" or GameSpawn.spawn_at(d, -10, -1, 10, slot) != "":
			none = false
	ok(none, "nothing spawns in a town or at sea")
	# a creature in a biome is one that lives in it
	var bad := 0
	var seen := 0
	for i in 3000:
		var x := 60 + (i * 53) % 500
		var z := 60 + (i * 131) % 500
		var id := GameSpawn.spawn_at(d, x, -1, z, i)
		if id == "":
			continue
		var ctx := GameSpawn.context_at(d, x, -1, z)
		seen += 1
		if ctx["zone"] == "surface" and ctx["surface"] not in GameSpawn.data()["creatures"][id]["surface"]:
			bad += 1
	ok(seen > 100 and bad == 0, "a creature on the surface is one that roams that biome (%d spawns, %d wrong)" % [seen, bad])
	# the dungeon mouth spawns from the place's pool, more densely
	var barrow := GameWorldGen.anchor("hollow_barrow")
	var at_mouth := 0
	for slot in 400:
		if GameSpawn.spawn_at(d, int(barrow["x"]), -1, int(barrow["z"]), slot) != "":
			at_mouth += 1
	ok(at_mouth > 80 and at_mouth < 170, "a dungeon's mouth is busy: %d of 400 slots (30%%)" % at_mouth)
	# underground: only creatures that live at that depth, and night makes no difference where it is always dark
	var wrong_depth := 0
	var below := 0
	var dark_same := true
	for slot in 1500:
		var depth := 12 + (slot * 13) % 380
		var id := GameSpawn.spawn_at(d, 10 + slot % 7, depth, 10, slot)
		if GameSpawn.spawn_at(d, 10 + slot % 7, depth, 10, slot, true) != id:
			dark_same = false
		if id == "":
			continue
		below += 1
		var band: Array = GameSpawn.data()["creatures"][id]["depth"]
		if depth < int(band[0]) or depth > int(band[1]):
			wrong_depth += 1
	ok(below > 100 and wrong_depth == 0, "underground, a creature is one that lives at that depth (%d spawns, %d wrong)" % [below, wrong_depth])
	ok(dark_same, "and night changes nothing underground, where it is always dark")


# ---------------------------------------------------------------- depth

func test_depth() -> void:
	# across the whole Age the deeper bands hold the later and tougher creatures: for each depth, the creatures whose band covers it
	var hp_by := {}
	var gen_by := {}
	for depth in [20, 60, 100, 150, 200, 260, 330]:
		var hp := 0.0
		var born := 0.0
		var n := 0
		for c in GameSpawn.wild():
			var spec: Dictionary = GameSpawn.data()["creatures"][str(c["id"])]
			if spec.has("depth") and depth >= int(spec["depth"][0]) and depth <= int(spec["depth"][1]):
				hp += float(c["hp"])
				born += float(c["min_gen"])
				n += 1
		hp_by[depth] = hp / maxf(1.0, float(n))
		gen_by[depth] = born / maxf(1.0, float(n))
	ok(hp_by[330] > hp_by[100] and hp_by[100] > hp_by[20] and hp_by[200] > hp_by[60], "the deeper the tougher: mean hp %.0f at 20, %.0f at 100, %.0f at 200, %.0f at 330" % [hp_by[20], hp_by[100], hp_by[200], hp_by[330]])
	ok(gen_by[330] > gen_by[150] and gen_by[150] > gen_by[20], "and the deeper the later in the Age they first appear: era %.0f at 20, %.0f at 150, %.0f at 330" % [gen_by[20], gen_by[150], gen_by[330]])
	var shallow := ids(GameSpawn.table(GameSpawn.context("", 20, 60)))
	var abyss := ids(GameSpawn.table(GameSpawn.context("", 330, 700)))
	ok(shallow.has("slime") and not shallow.has("star_eater") and abyss.has("star_eater") and abyss.has("abyssal_knight") and not abyss.has("slime"), "slimes are in the shallows and star-eaters at the bottom: %s" % str(abyss))
	ok(GameSpawn.table(GameSpawn.context("", 5, 60)).is_empty() and GameSpawn.table(GameSpawn.context("", 405, 700)).is_empty(), "nothing lives in the soil or below the bottom")
	ok(GameSpawn.setting("underground_density")["deep"] > GameSpawn.setting("underground_density")["underground"], "the Deep is busier than the shallows")


func test_reach() -> void:
	# every wild creature is met somewhere: on a surface, underground, or at the mouth of a place that breeds it
	var met := {}
	for biome in GameWorldGen.data()["biomes"]:
		for era in range(1, 1101, 25):
			for row in GameSpawn.table(GameSpawn.context(str(biome), -1, era)):
				met[row["id"]] = true
	for depth in range(12, 401, 8):
		for era in range(1, 1101, 50):
			for row in GameSpawn.table(GameSpawn.context("", depth, era)):
				met[row["id"]] = true
	var missing: Array = []
	for c in GameSpawn.wild():
		if not met.has(c["id"]):
			missing.append(c["id"])
	ok(missing.is_empty(), "every wild creature can be met somewhere in some era: missing %s" % str(missing))
	# and the era windows agree with creatures.json
	var wrong := 0
	for c in GameSpawn.wild():
		for era in [1, 50, 120, 300, 500, 900]:
			var in_window: bool = c["min_gen"] <= era and era <= c["max_gen"]
			var found := false
			for biome in GameWorldGen.data()["biomes"]:
				if str(c["id"]) in ids(GameSpawn.table(GameSpawn.context(str(biome), -1, era))):
					found = true
			for depth in range(12, 401, 20):
				if str(c["id"]) in ids(GameSpawn.table(GameSpawn.context("", depth, era))):
					found = true
			if found and not in_window:
				wrong += 1
	ok(wrong == 0, "no creature is ever met outside its era")


func test_untouched() -> void:
	var d := dyn()
	d.gen = 700
	var before := d.rng.state
	var save_before := JSON.stringify(d.to_dict())
	for i in 300:
		GameSpawn.spawn_at(d, 40 + i % 500, -1, 40 + (i * 7) % 500, i)
		GameSpawn.spawn_at(d, 10, 12 + i % 380, 10, i)
	ok(d.rng.state == before and JSON.stringify(d.to_dict()) == save_before, "spawning draws nothing from the dynasty's dice and changes nothing that is saved")
