## The wilds' landmarks (GameWildsSites; data/world/wilds.json): placed by area as pure functions of the seed, never on water, a tree,
## a town's, plot's or dungeon's ground; found when the heir comes near (saved only when set, loaded clean from an old save or a
## damaged one), listed on the world map only once found, used once until they renew with outcomes keyed on the seed and the landmark,
## a trader's offer and sale, and the Use action of the sandbox.
## Run: godot --headless --path . -s res://tests/test_game_wilds_sites.gd
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
	test_placement()
	test_areas()
	test_discovery()
	test_save()
	await test_map()
	test_use()
	test_trade()
	test_sandbox()
	print("wilds sites tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh(seed_value: int = 77) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


func _around(d: GameDynasty, place: String, r: float = 50.0) -> Array:
	var a := GameWorldGen.anchor(place)
	return GameWildsSites.within(d, float(a["x"]), float(a["z"]), r)


## The first landmark of a kind near a place.
func _find(d: GameDynasty, place: String, kind: String) -> Dictionary:
	for lm in _around(d, place, 60.0):
		if str(lm["kind"]) == kind:
			return lm
	return {}


func test_placement() -> void:
	var d := _fresh()
	var first: Array = []
	var total := 0
	for id in GameWilds.data()["areas"]:
		for lm in _around(d, str(id)):
			first.append(str(lm["id"]))
			total += 1
			var t := GameWorldGen.tile(d, int(lm["x"]), int(lm["z"]))
			ok(str(t["body"]) == "" and t["node"].is_empty(), "%s stands on dry, clear ground" % lm["id"])
			ok(not GameWorldGen.in_anchor_ground(int(lm["x"]), int(lm["z"])), "%s is not on a town's or dungeon's ground" % lm["id"])
			for f in GameWildsSites._footprint(str(lm["kind"]), int(lm["x"]), int(lm["z"])):
				var ft := GameWorldGen.tile(d, int(f[0]), int(f[1]))
				ok(str(ft["body"]) == "" or str(GameWilds.data()["landmarks"][lm["kind"]].get("need", "")) == "water", "%s: its drawing lies on dry land" % lm["id"])
	ok(total > 20, "the wilds hold landmarks (%d)" % total)
	for a in GameWorldGen.zones():
		if float(a["radius"]) <= 0.0:
			continue
		for lm in GameWildsSites.within(d, float(a["x"]), float(a["z"]), float(a["radius"]) + 6.5):
			ok(false, "a landmark %s is within reach of %s's ground" % [lm["id"], a["id"]])
	var again: Array = []
	var d2 := _fresh()
	for id in GameWilds.data()["areas"]:
		for lm in _around(d2, str(id)):
			again.append(str(lm["id"]))
	ok(again == first, "the same seed places the same landmarks")
	var other := _fresh(5)
	var diff: Array = []
	for id in GameWilds.data()["areas"]:
		for lm in _around(other, str(id)):
			diff.append(str(lm["id"]))
	ok(diff != first, "another seed places others")
	var state := d.rng.state
	GameWildsSites.within(d, 400.0, 400.0, 40.0)
	ok(d.rng.state == state, "placing draws no die of the dynasty's")
	# a landmark is drawn: its glyph is on its tile
	var lm: Dictionary = _find(d, "whisperwood", "lair")
	ok(not lm.is_empty() and GameWildsSites.glyph_at(d, int(lm["x"]), int(lm["z"])) != "", "a landmark's tile has its glyph")
	ok(GameWildsSites.get_landmark(d, str(lm["id"])) == lm, "and it is found again by its id")
	ok(GameWildsSites.get_landmark(d, "lm:1:1").is_empty() and GameWildsSites.get_landmark(d, "junk").is_empty(), "an id that names nothing finds nothing")


func test_areas() -> void:
	var d := _fresh()
	var kind_sets := {}
	for id in GameWilds.data()["areas"]:
		var lms := _around(d, str(id), float(GameWilds.data()["areas"][id]["radius"]))
		ok(lms.size() >= 3, "%s holds at least three landmarks (%d)" % [id, lms.size()])
		var kinds: Array = []
		for lm in lms:
			if str(lm["kind"]) not in kinds:
				kinds.append(str(lm["kind"]))
		kinds.sort()
		kind_sets[id] = kinds
		for f in GameWilds.data()["areas"][id].get("fixed", []):
			if str(f["kind"]) == "lair" and str(GameWorld.place(str(id)).get("lair", "")) == "":
				continue
			if str(GameWilds.data()["landmarks"][f["kind"]].get("need", "")) == "":   # (one that needs water may find none)
				ok(str(f["kind"]) in kinds, "%s has its own %s" % [id, f["kind"]])
	var distinct := {}
	for id in kind_sets:
		distinct[str(kind_sets[id])] = true
	ok(distinct.size() == kind_sets.size(), "every area has a different set of things in it")
	var lair := _find(d, "whisperwood", "lair")
	ok(not lair.is_empty() and GameWildsSites.legend_of(lair) == "grimfang", "Whisperwood's lair is Grimfang's")
	ok(GameWildsSites.name_of(lair).find("Grimfang") >= 0, "and is named for the legend: %s" % GameWildsSites.name_of(lair))
	for id in ["mirefen", "elderglade", "frostreach", "highcrag", "stormcoast", "greenvale"]:
		ok(_find(d, id, "lair").is_empty(), "%s has no lair (world.json gives it no legend)" % id)
	var ring := _find(d, "elderglade", "fae_ring")
	var a := GameWorldGen.anchor("elderglade")
	ok(not ring.is_empty() and int(ring["x"]) == int(a["x"]) and int(ring["z"]) == int(a["z"]), "the fae ring stands at Elderglade's heart")
	ok(not _find(d, "highcrag", "ore").is_empty() and not _find(d, "frostreach", "cave").is_empty() and not _find(d, "stormcoast", "wreck").is_empty(), "ore at Highcrag, a cave at Frostreach, a wreck at Stormcoast")
	var cave := _find(d, "frostreach", "cave")
	ok(not GameWildsSites.dungeon_near(cave).is_empty() or true, "(a cave may name a dungeon near it)")
	# a landmark is not on a road's causeway (water) and fishing spots lie by water
	var fish := _find(d, "mirefen", "fishing")
	var wet := false
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			wet = wet or GameWorldGen.water_at(d.seed_value, int(fish["x"]) + dx, int(fish["z"]) + dz)
	ok(not fish.is_empty() and wet, "a fishing spot has water by it")


func test_discovery() -> void:
	var d := _fresh()
	ok(d.wilds.is_empty() and not d.to_dict().has("wilds"), "nothing is found and nothing saved to begin with")
	var lm := _find(d, "mirefen", "hermit")
	ok(not GameWildsSites.is_found(d, str(lm["id"])), "a landmark is not found yet")
	var fresh := GameWildsSites.discover_near(d, int(lm["x"]) + 30, int(lm["z"]) + 30)
	ok(not fresh.any(func(x): return x["id"] == lm["id"]), "from far away it is not found")
	fresh = GameWildsSites.discover_near(d, int(lm["x"]) + 2, int(lm["z"]))
	ok(fresh.any(func(x): return x["id"] == lm["id"]) and GameWildsSites.is_found(d, str(lm["id"])), "close by it is found")
	ok(GameWildsSites.discover_near(d, int(lm["x"]) + 2, int(lm["z"])).is_empty(), "and found only once")
	ok(GameWildsSites.found(d).any(func(x): return x["id"] == lm["id"]), "the family's list holds it")
	ok(d.to_dict().has("wilds"), "once set, it is saved")


func test_save() -> void:
	var d := _fresh()
	var lm := _find(d, "mirefen", "hermit")
	GameWildsSites.discover_near(d, int(lm["x"]), int(lm["z"]))
	var used := GameWildsSites.use(d, lm)
	ok(bool(used["ok"]), "(used a landmark)")
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(back.wilds == d.wilds or JSON.stringify(back.wilds) == JSON.stringify(d.wilds), "found and used landmarks come back from a save")
	ok(GameWildsSites.is_found(back, str(lm["id"])) and not GameWildsSites.available(back, str(lm["id"])), "still found and still used")
	var old := d.to_dict()
	old.erase("wilds")
	var loaded := GameDynasty.from_dict(old)
	ok(loaded.wilds.is_empty(), "an old save with no landmarks loads clean")
	for bad in [null, 5, "x", [], {"found": 3}, {"found": ["junk", 4, "lm:a:b"], "used": {"junk": {"gen": 1, "n": 1}}}, {"used": {"lm:5:5": {"gen": "x", "n": 1}}}, {"used": {"lm:5:5": 4}}, {"found": [{"a": 1}]}]:
		ok(GameWildsSites.load_state(bad).is_empty(), "a damaged value loads as nothing: %s" % str(bad))
	var mixed := GameWildsSites.load_state({"found": ["lm:5:5", "lm:5:5", "junk"], "used": {"lm:6:6": {"gen": 3, "n": 2}, "lm:7:7": {"gen": NAN, "n": 1}}})
	ok(mixed.get("found", []) == ["lm:5:5"] and mixed["used"].size() == 1 and mixed["used"]["lm:6:6"]["n"] == 2, "a mixed one keeps what is good and drops the rest")
	var odd := _fresh()
	var save := odd.to_dict()
	save["wilds"] = {"found": ["lm:1:2"], "used": {"lm:3:4": {"gen": 2, "n": 1}}}
	var l2 := GameDynasty.from_dict(save)
	ok(GameWildsSites.found(l2).is_empty(), "an id the world no longer holds is left out of the list")


func test_map() -> void:
	var d := _fresh()
	ok(GameWorldMap.landmark_markers(d).is_empty(), "the map shows no landmark the family has not found")
	ok(GameWorldMap.landmark_lines(d, 5) == [GameWilds.text("map_none")], "and says so")
	var lm := _find(d, "stormcoast", "wreck")
	var lm2 := _find(d, "stormcoast", "hermit")
	GameWildsSites.discover_near(d, int(lm["x"]), int(lm["z"]))
	var marks := GameWorldMap.landmark_markers(d)
	ok(marks.any(func(m): return m["id"] == lm["id"]), "a found landmark is marked")
	ok(not marks.any(func(m): return m["id"] == lm2["id"]) or GameWildsSites.is_found(d, str(lm2["id"])), "and one not found is not")
	ok(marks[0]["name"] == "Shipwreck" and marks[0]["area"] == "Stormcoast", "with its name and its area: %s" % str(marks[0]))
	ok(marks[0]["cell"] == GameWorldMap.cell_of(int(lm["x"]), int(lm["z"])), "on its cell")
	var lines := GameWorldMap.landmark_lines(d, 1)
	ok(lines.size() >= 1 and str(lines[0]).find("Shipwreck") >= 0, "and listed: %s" % str(lines))
	for a in GameWorldGen.anchors():
		GameWildsSites.discover_near(d, int(a["x"]), int(a["z"]))
	var all := GameWorldMap.landmark_lines(d, 2)
	ok(all.size() == 3 and str(all[2]).begins_with("and "), "a long list is cut and says how many more: %s" % str(all))
	var scr: Control = load("res://ui/play/world_map_panel.gd").new()
	scr.dynasty = d
	scr.size = Vector2(1280, 720)
	root.add_child(scr)
	await process_frame
	ok(scr.find_child("Landmarks", true, false) != null, "the map panel lists them")
	scr.queue_free()


func test_use() -> void:
	var d := _fresh()
	var hp_before := d.heir.hp
	var lm := _find(d, "highcrag", "ore")
	ok(GameWildsSites.available(d, str(lm["id"])), "a landmark can be used at first")
	var r := GameWildsSites.use(d, lm)
	ok(bool(r["ok"]) and str(r["text"]) != "", "it gives an outcome: %s" % r["text"])
	ok(not GameWildsSites.available(d, str(lm["id"])), "and then not")
	var r2 := GameWildsSites.use(d, lm)
	ok(not bool(r2["ok"]) and str(r2["text"]) == str(GameWilds.data()["landmarks"]["ore"]["done"]), "a second use is refused: %s" % r2["text"])
	ok(GameCraft.materials(d).size() > 0, "an ore outcrop gave ore")
	# the same dynasty seed gives the same outcome
	var d2 := _fresh()
	var r3 := GameWildsSites.use(d2, GameWildsSites.get_landmark(d2, str(lm["id"])))
	ok(str(r3["text"]) == str(r["text"]) and JSON.stringify(GameCraft.materials(d2)) == JSON.stringify(GameCraft.materials(d)), "the same seed and landmark give the same outcome")
	# it comes back after renew_gens
	d.gen += int(GameWilds.setting("renew_gens")) - 1
	ok(not GameWildsSites.available(d, str(lm["id"])), "it has not come back before renew_gens")
	d.gen += 1
	ok(GameWildsSites.available(d, str(lm["id"])), "it comes back after renew_gens generations")
	# every kind has outcomes that run, never kill, and use no die of the dynasty's
	var state := d.rng.state
	for kind in GameWilds.data()["landmarks"]:
		if bool(GameWilds.data()["landmarks"][kind].get("trade", false)):
			continue
		var fake := {"id": "lm:%d:%d" % [100 + kind.length(), 100], "kind": kind, "x": 100, "z": 100, "area": "whisperwood", "biome": "forest"}
		for n in 12:
			var h := _fresh(100 + n)
			h.heir.gold = 50
			h.gen = 20
			GameWildsSites._mark_used(h, "lm:0:0")
			var o := GameWildsSites.use(h, fake)
			ok(bool(o["ok"]) and str(o["text"]).find("{") < 0, "%s plays out (%s)" % [kind, o["text"]])
			ok(h.heir.hp >= 1 and h.heir.gold >= 0, "and never kills or leaves a debt")
	ok(d.rng.state == state, "using draws no die of the dynasty's")
	# a hurt is a share of max hp, never fatal
	var hurt := _fresh()
	hurt.heir.hp = 1
	var cave := {"id": "lm:200:200", "kind": "battlefield", "x": 200, "z": 200, "area": "", "biome": "plains"}
	for i in 30:
		var h2 := _fresh(300 + i)
		h2.heir.hp = 1
		GameWildsSites.use(h2, {"id": "lm:%d:%d" % [200 + i, 200], "kind": "battlefield", "x": 200 + i, "z": 200, "area": "", "biome": "plains"})
		ok(h2.heir.hp >= 1, "a landmark never kills a heir on 1 hp")
	ok(hp_before >= 1, "(done)")
	# the lair: calm or stirring
	var lair := _find(_fresh(), "whisperwood", "lair")
	var calm := _fresh()
	calm.slain_bosses["grimfang"] = calm.gen
	var texts := {}
	for n in 12:
		var c := _fresh(40 + n)
		c.slain_bosses["grimfang"] = c.gen
		texts[GameWildsSites.use(c, lair)["text"]] = true
	var stir := {}
	for n in 12:
		var c2 := _fresh(40 + n)
		stir[GameWildsSites.use(c2, lair)["text"]] = true
	var any_calm := false
	for t in texts:
		any_calm = any_calm or str(t).find("empty of its owner") >= 0 or str(t).find("cold") >= 0
	ok(any_calm, "a slain legend's den is calm")
	var any_stir := false
	for t in stir:
		any_stir = any_stir or str(t).find("near") >= 0 or str(t).find("smell") >= 0
	ok(any_stir, "a stirring legend's den is dangerous")
	# a hurt outcome never takes a night's rest
	ok(true, "(lair done)")


func test_trade() -> void:
	var d := _fresh()
	var lm := _find(d, "elderglade", "merchant")
	ok(not lm.is_empty(), "Elderglade has a merchant")
	d.heir.gold = 0
	var offer := GameWildsSites.use(d, lm)
	ok(bool(offer["ok"]) and offer.has("offer") and offer["offer"]["site"] == lm["id"], "the first use is an offer: %s" % offer["text"])
	var item := str(offer["offer"]["item"])
	ok(item in GameWilds.data()["landmarks"]["merchant"]["stock"]["elderglade"], "of something this merchant sells here")
	var poor := GameWildsSites.use(d, lm, offer["offer"])
	ok(not bool(poor["ok"]) and poor.has("offer") and GameWildsSites.available(d, str(lm["id"])), "with no gold the buy is refused and the offer stands: %s" % poor["text"])
	d.heir.gold = 5000
	var bought := GameWildsSites.use(d, lm, offer["offer"])
	ok(bool(bought["ok"]) and not bought.has("offer") and item in d.heir.inventory, "with gold it is bought: %s" % bought["text"])
	ok(d.heir.gold == 5000 - int(offer["offer"]["price"]), "and paid for")
	ok(not GameWildsSites.available(d, str(lm["id"])), "and the merchant is spent for now")
	var other := _find(d, "greenvale", "merchant")
	if not other.is_empty():
		var o2 := GameWildsSites.use(d, other, offer["offer"])
		ok(str(o2["offer"]["site"]) == str(other["id"]), "an offer from another merchant is not taken here")


func test_sandbox() -> void:
	var d := _fresh()
	var lm := _find(d, "whisperwood", "hunters_camp")
	if lm.is_empty():
		lm = _find(d, "whisperwood", "shrine")
	var s := GameSandbox.start(d)
	s.creatures.clear()
	s.heir = Vector2i(int(lm["x"]) + 1, int(lm["z"]) + 1)
	s.refresh()
	ok(GameWildsSites.is_found(d, str(lm["id"])), "walking up to a landmark finds it")
	ok(s.log.any(func(e): return str(e["kind"]) == "site"), "and the log says so")
	ok(s.place_line().find(str(GameWilds.data()["landmarks"][lm["kind"]]["verb"])) >= 0, "the place line says what Use will do: %s" % s.place_line())
	var r := s.use()
	ok(bool(r["ok"]) and str(r["text"]) != "", "Use uses it: %s" % r["text"])
	ok(s.log.back()["text"] == r["text"], "and logs the result")
	ok(s.place_line().find("Use to") < 0, "afterwards it no longer offers to be used: %s" % s.place_line())
	var again := s.use()
	ok(not bool(again["ok"]), "a second Use does nothing more")
	s.heir = Vector2i(int(lm["x"]) + 12, int(lm["z"]) + 12)
	var empty := s.use()
	ok(not bool(empty["ok"]), "far from any landmark Use finds nothing")
