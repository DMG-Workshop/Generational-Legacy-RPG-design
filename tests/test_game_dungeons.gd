## What is in each dungeon (data/world/dungeons.json; GameDungeons): rooms with roles, creatures by room and era, the lair's boss
## where world.json gives one, containers placed by role, traps and features; the marks of what the heir opened, sprung, used and
## killed (saved only when set, loading clean from old saves and from damaged ones); and that none of it draws a die of the
## dynasty's.
## Run: godot --headless --path . -s res://tests/test_game_dungeons.gd
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
	test_rooms()
	test_layout()
	test_inhabitants()
	test_marks()
	test_use()
	test_traps()
	test_save()
	test_no_dice()
	test_breaks()
	print("dungeon tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(gen: int = 1) -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.gen = gen
	return d


func test_data() -> void:
	ok(GameDungeons.validate().is_empty(), "the contents validate: %s" % str(GameDungeons.validate()))
	ok(GameSpaces.validate().is_empty(), "the floor plans validate: %s" % str(GameSpaces.validate()))
	ok(GameDungeonLoot.validate().is_empty(), "the loot tables validate: %s" % str(GameDungeonLoot.validate()))
	ok(GameDungeons.is_dungeon("world/hollow_barrow") and not GameDungeons.is_dungeon("world/hearthmere/forge") and not GameDungeons.is_dungeon("world"), "only a dungeon is a dungeon")
	ok(GameDungeons.place_of("world/the_rift") == "the_rift" and GameDungeons.place_of("x") == "", "place_of")


func test_rooms() -> void:
	var roles_all := {}
	for p in GameDungeons.dungeon_ids():
		var rooms := GameSpaces.rooms("world/" + str(p))
		ok(rooms.size() >= 8 and rooms.size() <= 10, "%s has %d rooms" % [p, rooms.size()])
		var roles := {}
		for r in rooms:
			roles[str(r["role"])] = true
			roles_all[str(r["role"])] = true
		ok(roles.has("entrance_hall") and roles.has("treasure_vault") and roles.has("shrine"), "%s has an entrance hall, a vault and a shrine" % p)
		var lair := str(GameWorld.place(str(p)).get("lair", ""))
		ok((lair != "") == roles.has("boss_lair"), "%s has a boss_lair room exactly when world.json gives it a lair (%s)" % [p, lair])
	for want in ["entrance_hall", "guard_room", "treasure_vault", "boss_lair", "shrine", "prison", "armoury", "nest"]:
		ok(roles_all.has(want), "some dungeon has a %s" % want)


func test_layout() -> void:
	var sigs := {}
	for p in GameDungeons.dungeon_ids():
		var id := "world/" + str(p)
		var lay := GameDungeons.layout(id)
		var cells := GameInterior.cells(id)
		ok(lay["containers"].size() >= 6 and lay["foes"].size() >= 8 and lay["traps"].size() >= 3, "%s: %d containers, %d foes, %d traps" % [p, lay["containers"].size(), lay["foes"].size(), lay["traps"].size()])
		var seen := {}
		var clash := 0
		var bad := 0
		for c in lay["containers"]:
			var k := "%d,%d" % [int(c["x"]), int(c["z"])]
			clash += 1 if seen.has(k) else 0
			seen[k] = true
			bad += 0 if cells.get(k, "") == "floor" else 1
		for f in lay["foes"]:
			var k := "%d,%d" % [int(f["x"]), int(f["z"])]
			clash += 1 if seen.has(k) else 0
			seen[k] = true
			bad += 0 if cells.get(k, "") == "floor" else 1
			ok(Vector2(float(f["x"]), float(f["z"])).length() >= float(GameDungeons.setting("min_foe_distance")), "%s: a foe does not start by the way in" % p)
		for t in lay["traps"]:
			var k := "%d,%d" % [int(t["x"]), int(t["z"])]
			bad += 0 if cells.get(k, "") == "floor" else 1
		ok(clash == 0 and bad == 0, "%s: everything stands on its own floor cell" % p)
		var lair := str(GameWorld.place(str(p)).get("lair", ""))
		ok(lay["boss"].is_empty() == (lair == ""), "%s: a boss spot exactly where there is a lair" % p)
		if not lay["boss"].is_empty():
			ok(GameInterior.room_at(id, int(lay["boss"]["x"]), int(lay["boss"]["z"])) == str(lay["boss"]["room"]) and GameSpaces.rooms(id).any(func(r): return r["id"] == lay["boss"]["room"] and r["role"] == "boss_lair"), "%s: the boss is in the lair room" % p)
		# placed by role: vault chests are rich or better, shrine features sit in shrine rooms
		for c in lay["containers"]:
			if str(c["role"]) == "treasure_vault":
				ok(str(c["tier"]) in ["rich", "hoard"], "%s: a vault's %s is rich" % [p, c["kind"]])
		var sig := []
		for c in lay["containers"]:
			sig.append("%s/%s/%s" % [c["room"], c["kind"], c["tier"]])
		sigs[str(sig)] = true
		ok(JSON.stringify(GameDungeons.layout(id)) == JSON.stringify(lay), "%s: the layout is the same every time" % p)
	ok(sigs.size() == 6, "no two dungeons hold the same things")


func test_inhabitants() -> void:
	var d := _dyn(1)
	var id := "world/hollow_barrow"
	var early := GameDungeons.inhabitants(d, id)
	ok(early.size() > 0 and not early.any(func(h): return h["boss"]), "at generation 1 the barrow has its rats and no king (he is not stirring)")
	ok(early.all(func(h): return h["creature"] in ["plague_rat", "bandit"]), "only creatures of the era: %s" % str(early.map(func(h): return h["creature"])))
	d.gen = 60
	var mid := GameDungeons.inhabitants(d, id)
	ok(mid.any(func(h): return h["boss"] and h["creature"] == "hollow_king"), "from generation 40 the Hollow King lies in his tomb")
	ok(mid.any(func(h): return h["creature"] in ["skeleton", "ghoul"]), "with the dead of the era")
	var boss: Dictionary = mid.filter(func(h): return h["boss"])[0]
	ok(GameInterior.room_at(id, int(boss["x"]), int(boss["z"])) == "tomb", "in the tomb")
	d.slain_bosses["hollow_king"] = 60
	ok(not GameDungeons.inhabitants(d, id).any(func(h): return h["boss"]), "a slain king is not there")
	ok(JSON.stringify(GameDungeons.inhabitants(d, id)) == JSON.stringify(GameDungeons.inhabitants(d, id)), "the same every time")
	var other := _dyn(60)
	other.seed_value = 12345
	ok(JSON.stringify(GameDungeons.inhabitants(other, id)) != JSON.stringify(GameDungeons.inhabitants(_dyn(60), id)), "another seed meets other creatures")
	var rift1 := GameDungeons.inhabitants(_dyn(1), "world/the_rift")
	ok(rift1.is_empty(), "the Rift is quiet before its creatures come (generation 1)")
	ok(GameDungeons.inhabitants(_dyn(100), "world/the_rift").size() > 5, "and busy once they have")
	ok(GameDungeons.inhabitants(_dyn(700), "world/the_rift").any(func(h): return h["boss"] and h["creature"] == "the_unmade"), "with the Unmade at last")
	var g1 := GameDungeons.inhabitants(_dyn(1), "world/goblin_warrens")
	ok(g1.size() >= 8 and g1.all(func(h): return h["creature"] in ["goblin", "plague_rat", "bandit", "slime"]), "the warrens swarm with goblins and rats")
	ok(not g1.any(func(h): return h["boss"]), "(the warrens have no lair)")
	var kinds := {}
	for p in GameDungeons.dungeon_ids():
		var names := {}
		for h in GameDungeons.inhabitants(_dyn(400), "world/" + str(p)):
			names[h["creature"]] = true
		var keys: Array = names.keys()
		keys.sort()
		kinds[str(keys)] = true
	ok(kinds.size() == 6, "each dungeon has its own creatures (at generation 400)")


func test_marks() -> void:
	var d := _dyn(60)
	var id := "world/hollow_barrow"
	var before := GameDungeons.inhabitants(d, id)
	var gone: Dictionary = before.filter(func(h): return not h["boss"])[0]
	GameDungeons.mark(d, "k", "hollow_barrow", str(gone["key"]))
	var after := GameDungeons.inhabitants(d, id)
	ok(after.size() == before.size() - 1 and not after.any(func(h): return h["key"] == gone["key"]), "a killed creature is not there")
	d.world.year += float(GameDungeons.setting("foe_years")) + 1.0
	ok(GameDungeons.inhabitants(d, id).size() == before.size(), "and comes back after foe_years")
	var m := {"o:hollow_barrow:a#0": 3.0, "t:x:y": 1.5, "u:warchiefs_cleaver": 2, "k:a:b": NAN, "bad": 1, "o:a": 2.0, "f:a:b": "x", 5: 1.0, "q:a:b": 1.0}
	var clean := GameDungeons.load_marks(m)
	ok(clean.size() == 3 and clean.has("o:hollow_barrow:a#0") and clean.has("u:warchiefs_cleaver"), "damaged marks are dropped on load: %s" % str(clean))
	ok(GameDungeons.load_marks("x").is_empty() and GameDungeons.load_marks(null).is_empty() and GameDungeons.load_marks([1]).is_empty(), "and a mark list of the wrong kind is nothing")


func _beside(d: GameDynasty, id: String, c: Dictionary) -> Vector2i:
	var walk := GameDungeons.walk_cells(id)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if walk.get("%d,%d" % [int(c["x"]) + dx, int(c["z"]) + dz], "") in GameInterior.WALKABLE:
				return Vector2i(int(c["x"]) + dx, int(c["z"]) + dz)
	return Vector2i.ZERO


func test_use() -> void:
	var d := _dyn(30)
	d.heir.gold = 0
	var id := "world/goblin_warrens"
	var c: Dictionary = GameDungeons.layout(id)["containers"][0]
	var at := _beside(d, id, c)
	var near := GameDungeons.thing_near(id, at.x, at.y)
	ok(not near.is_empty() and near["type"] == "container", "beside a container the Use action finds it")
	ok(GameDungeons.thing_near(id, 0, 0).is_empty(), "and finds nothing at the way in")
	var inv := d.heir.inventory.size()
	var r := GameDungeons.use_thing(d, id, near)
	ok(r["ok"] and GameDungeons.container_open(d, id, str(c["id"])) and d.heir.gold > 0, "opening it gives its loot and marks it open: %s" % r["text"])
	ok(d.dungeon_marks.size() >= 1 and r["dirty"].size() == 1, "(and says which tile to redraw)")
	var r2 := GameDungeons.use_thing(d, id, near)
	ok(not r2["ok"] and r2["text"].contains("empty"), "it is empty the second time: %s" % r2["text"])
	d.world.year += float(GameDungeons.setting("refill_years")) + 1.0
	ok(not GameDungeons.container_open(d, id, str(c["id"])), "and fills again after refill_years")
	# every container of every dungeon can be opened and gives something
	var empty := 0
	for p in GameDungeons.dungeon_ids():
		var dd := _dyn(100)
		dd.heir.gold = 0
		for cc in GameDungeons.layout("world/" + str(p))["containers"]:
			var got := GameDungeons.use_thing(dd, "world/" + str(p), {"type": "container", "thing": cc})
			if not got["ok"] or dd.heir.inventory.size() + dd.heir.gold == 0:
				empty += 1
	ok(empty == 0, "every container in every dungeon opens")
	# a shrine heals once
	var barrow := "world/hollow_barrow"
	var f: Dictionary = GameDungeons.layout(barrow)["features"].filter(func(x): return x["kind"] == "shrine")[0]
	d.heir.hp = 1
	var h := GameDungeons.use_thing(d, barrow, {"type": "feature", "thing": f})
	ok(h["ok"] and d.heir.hp > 1, "a shrine heals the heir: %s" % h["text"])
	var hp := d.heir.hp
	var h2 := GameDungeons.use_thing(d, barrow, {"type": "feature", "thing": f})
	ok(not h2["ok"] and d.heir.hp == hp, "and only once")
	var lore: Dictionary = GameDungeons.layout("world/deepstone_halls")["features"][0]
	ok(GameDungeons.use_thing(d, "world/deepstone_halls", {"type": "feature", "thing": lore})["text"].length() > 20, "an inscription tells its story")


func test_traps() -> void:
	var d := _dyn(10)
	var id := "world/emberpeak"
	var t: Dictionary = GameDungeons.layout(id)["traps"][0]
	d.heir.hp = d.heir.max_hp()
	d.heir.stat("agi")
	var hit := 0
	var r := GameDungeons.step_on(d, id, int(t["x"]), int(t["z"]))
	ok(r["text"] != "" and (r["hit"] == (r["damage"] > 0)), "stepping on a trap springs it: %s" % r["text"])
	var again := GameDungeons.step_on(d, id, int(t["x"]), int(t["z"]))
	ok(not again["hit"] and again["text"] == "", "and only once")
	ok(GameDungeons.trap_sprung(d, id, str(t["id"])), "it is marked sprung")
	ok(not GameDungeons.step_on(d, id, 0, 0)["hit"], "no trap at the way in")
	d.heir.hp = 1
	for tt in GameDungeons.layout(id)["traps"]:
		GameDungeons.step_on(d, id, int(tt["x"]), int(tt["z"]))
	ok(d.heir.hp >= 1, "a trap never kills")
	var all_hurt := 0
	for p in GameDungeons.dungeon_ids():
		var dd := _dyn(1)
		dd.heir.hp = dd.heir.max_hp()
		for tt in GameDungeons.layout("world/" + str(p))["traps"]:
			all_hurt += int(GameDungeons.step_on(dd, "world/" + str(p), int(tt["x"]), int(tt["z"]))["damage"])
	ok(all_hurt > 0, "traps hurt")


func test_save() -> void:
	var d := _dyn(30)
	ok(not d.to_dict().has("dungeon_marks"), "a house that has opened nothing saves no marks (old saves and new alike)")
	GameDungeons.mark(d, "o", "goblin_warrens", "mouth#0")
	GameDungeons.mark_unique(d, "warchiefs_cleaver")
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(back.dungeon_marks == d.dungeon_marks and GameDungeons.has_unique(back, "warchiefs_cleaver"), "marks come back from a save")
	var old := d.to_dict()
	old.erase("dungeon_marks")
	ok(GameDynasty.from_dict(JSON.parse_string(JSON.stringify(old))).dungeon_marks.is_empty(), "an old save without the key loads clean")
	var junk := d.to_dict()
	junk["dungeon_marks"] = {"o:a:b": "x", "zzz": 1, "t:a:b": 4.0}
	var jb := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(junk)))
	ok(jb.dungeon_marks.size() == 1, "damaged marks are dropped")
	junk["dungeon_marks"] = 5
	ok(GameDynasty.from_dict(JSON.parse_string(JSON.stringify(junk))).dungeon_marks.is_empty(), "and a mark list of the wrong kind is nothing")


func test_no_dice() -> void:
	var d := _dyn(60)
	var state := d.rng.state
	for p in GameDungeons.dungeon_ids():
		var id := "world/" + str(p)
		GameDungeons.inhabitants(d, id)
		for c in GameDungeons.layout(id)["containers"]:
			GameDungeons.use_thing(d, id, {"type": "container", "thing": c})
		for t in GameDungeons.layout(id)["traps"]:
			GameDungeons.step_on(d, id, int(t["x"]), int(t["z"]))
	ok(d.rng.state == state, "opening every container, springing every trap and meeting every creature drew no die of the dynasty's")
	var a := _dyn(60)
	var b := _dyn(60)
	GameDungeons.use_thing(a, "world/emberpeak", {"type": "container", "thing": GameDungeons.layout("world/emberpeak")["containers"][0]})
	ok(JSON.stringify(a.rng.state) != "" and a.rng.state == b.rng.state, "a life that opened a chest goes on with the same dice as one that did not")


func test_breaks() -> void:
	var keep := GameDungeons._cache
	var bad := GameDungeons.data().duplicate(true)
	bad["dungeons"]["the_rift"]["roles"]["boss_lair"]["foes"]["pool"].append({"id": "hollow_king", "weight": 1})
	GameDungeons._cache = bad
	ok(not GameDungeons.validate().is_empty(), "break check: a boss in a room's pool is refused")
	GameDungeons._cache = keep
	var bad2 := GameDungeons.data().duplicate(true)
	bad2["dungeons"]["goblin_warrens"]["roles"]["guard_room"]["containers"].append({"kind": "chest", "tier": "golden", "count": [1, 1]})
	GameDungeons._cache = bad2
	ok(not GameDungeons.validate().is_empty(), "break check: an unknown loot tier is refused")
	GameDungeons._cache = keep
	var bad3 := GameDungeons.data().duplicate(true)
	bad3["dungeons"]["emberpeak"]["roles"]["boss_lair"].erase("foes")
	bad3["dungeons"]["emberpeak"]["roles"]["shrine"]["features"][0]["pct"] = 5.0
	GameDungeons._cache = bad3
	ok(not GameDungeons.validate().is_empty(), "break check: a shrine that heals more than everything is refused")
	GameDungeons._cache = keep
	ok(GameDungeons.validate().is_empty(), "(and the real data is whole again)")
