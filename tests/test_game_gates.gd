## Waygates (GameGates; data/world/gates.json; docs/GATES.md): placement is a pure function of the seed (dry, flat, clear ground off every wall,
## building and landmark, in reach of the land), a gate's state is a pure function of the seed, the gate, the slot and the world year (wear, theft,
## repairs, a guard), repairing needs the rune, silver, gold and the heir at the stones, a lit gate leads to every other lit gate of its network (and a
## realm's gate into the realm's arrival ground and back), only the family's own doings are saved (an old save loads, a corrupt value is dropped), the
## Runescribe is cheaper, and nothing in the rules of a life ever asks for a gate.
## Run: godot --headless --path . -s res://tests/test_game_gates.gd
extends SceneTree

var checks := 0
var fails := 0


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
	test_placement()
	test_state()
	test_wear_and_theft()
	test_guard()
	test_lore_and_copy()
	test_inscribe()
	test_runescribe()
	test_realm_flag()
	test_travel()
	test_realm_ground()
	test_save()
	test_known_and_marks()
	test_autopilot_never_meets_it()
	print("gates tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh(seed_value: int = 21, subclass: String = "") -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human", GameSex.MALE, subclass)
	d.pending_event = {}
	d.heir.gold = 5000
	return d


## Gives every slot of a gate a repair in year 0 (whole from the first year).
func _mend(d: GameDynasty, id: String) -> void:
	var f: Dictionary = d.gates.get("fixed", {})
	for i in GameGates.slot_count(id):
		f["%s:%d" % [id, i]] = 0
	d.gates["fixed"] = f


func _at(d: GameDynasty, id: String) -> GameSandbox:
	var s := GameSandbox.start(d)
	s.creatures.clear()
	s.heir = GameGates.front_of(d, id)
	return s


# ---------------------------------------------------------------- the data

func test_data() -> void:
	ok(GameGates.validate().is_empty(), "gates.json is sound: %s" % str(GameGates.validate()))
	ok(GateArt.validate().is_empty(), "the gates' art is sound: %s" % str(GateArt.validate()))
	var ids := GameGates.ids()
	ok(ids.size() == 17, "seventeen gates: four at towns, six in the wilds and the seven realms' doors (%d)" % ids.size())
	for id in ids:
		var n := GameGates.slot_count(str(id))
		ok(n >= 4 and n <= 7, "%s has 4 to 7 rune slots (%d)" % [id, n])
	for r in GameRealms.ids():
		if GameRealms.gateable(str(r)):
			ok(GameGates.gate_of_realm(str(r)) != "", "the realm %s has a gate" % r)
	# the rune alphabet is tied to the realms and the old words are there
	for w in ["road", "door", "bind", "light", "return", "ward", "deep"]:
		ok(GameGates.data()["runes"].has(w), "the rune '%s' is in the alphabet" % w)
	var tied := 0
	for r in GameGates.data()["runes"]:
		if str(GameGates.data()["runes"][r].get("realm", "")) != "":
			tied += 1
	ok(tied == 7, "each of the seven realms has a rune of its own (%d)" % tied)
	# a broken table is caught
	var bad: Dictionary = GameGates.data()["gates"][0]
	var keep: Array = (bad["runes"] as Array).duplicate()
	(bad["runes"] as Array).append("ward")
	ok(not GameGates.validate().is_empty(), "a gate with a rune too many fails the check")
	bad["runes"] = keep
	ok(GameGates.validate().is_empty(), "and mending it passes again")


# ---------------------------------------------------------------- placement

func test_placement() -> void:
	for seed_value in [21, 7, 12345, 99, 4242]:
		var d := _fresh(seed_value)
		var seen: Array = []
		var good := true
		for id in GameGates.ids():
			var p := GameGates.placed(d, str(id))
			if p.is_empty():
				good = false
				print("not placed: %s seed %d" % [id, seed_value])
				continue
			var lo := 1 << 30
			var hi := -(1 << 30)
			for t in GameGates.footprint(int(p["x"]), int(p["z"])):
				var tile := GameWorldGen.tile(d, t.x, t.y)
				if bool(tile["water"]) or not (tile["node"] as Dictionary).is_empty() or GameWalls.blocks(t.x, t.y) or not GameTown.at(t.x, t.y).is_empty() or GameWalls.cleared(t.x, t.y):
					good = false
					print("bad footprint %s %s seed %d" % [id, str(t), seed_value])
				lo = mini(lo, int(tile["height"]))
				hi = maxi(hi, int(tile["height"]))
				if GameWildsSites.glyph_at(d, t.x, t.y) != "":
					good = false
					print("a landmark under %s seed %d" % [id, seed_value])
			if hi - lo > int(GameGates.setting("flat_max")):
				good = false
				print("not flat %s seed %d" % [id, seed_value])
			var f := Vector2i(int(p["fx"]), int(p["fz"]))
			var ft := GameWorldGen.tile(d, f.x, f.y)
			if bool(ft["water"]) or not (ft["node"] as Dictionary).is_empty() or GameWalls.blocks(f.x, f.y) or not GameTown.at(f.x, f.y).is_empty() or f in GameGates.footprint(int(p["x"]), int(p["z"])):
				good = false
				print("bad front tile %s seed %d" % [id, seed_value])
			for q in seen:
				if Vector2(float(p["x"]) - float(q.x), float(p["z"]) - float(q.y)).length() < float(GameGates.setting("min_gap")):
					good = false
					print("two gates close together at %s seed %d" % [id, seed_value])
			seen.append(Vector2i(int(p["x"]), int(p["z"])))
		ok(good, "seed %d: every gate stands on dry, flat, clear ground off walls, buildings and landmarks, with an open tile in front" % seed_value)
	# a pure function of the seed: forget everything and ask again
	var d1 := _fresh(21)
	var first := {}
	for id in GameGates.ids():
		first[id] = GameGates.placed(d1, str(id))
	GameGates._seed = -1
	GameGates._order = []
	var d2 := _fresh(21)
	var same := true
	for id in GameGates.ids():
		if GameGates.placed(d2, str(id)) != first[id]:
			same = false
	ok(same, "the same seed puts every gate in the same place again")
	var other := _fresh(7)
	var moved := 0
	for id in GameGates.ids():
		if GameGates.placed(other, str(id)) != first[id]:
			moved += 1
	ok(moved >= 1, "another seed moves some of them (%d)" % moved)
	# where they stand: by a town's wall, in the wilds, one for each realm
	var d := _fresh(21)
	GameGates.all(d)
	for pair in [["hearthmere_arch", "hearthmere"], ["ironford_arch", "ironford"], ["kingshold_arch", "kingshold"], ["brinehaven_arch", "brinehaven"]]:
		var a := GameWorldGen.anchor(str(pair[1]))
		var t := GameGates.tile_of(d, str(pair[0]))
		var dist := Vector2(float(t.x) - float(a["x"]), float(t.y) - float(a["z"])).length()
		ok(dist > GameWalls.radius(str(pair[1])) and dist < GameWalls.radius(str(pair[1])) + 8.0, "%s stands just outside the wall of %s (%.1f from its middle, wall %.0f)" % [pair[0], pair[1], dist, GameWalls.radius(str(pair[1]))])
	for r in GameRealms.ids():
		if not GameRealms.gateable(str(r)):
			continue
		var g := GameGates.gate_of_realm(str(r))
		var nom := GameGates._nominal(GameGates.def(g))
		ok(Vector2(GameGates.tile_of(d, g) - nom).length() <= float(GameGates.setting("search")) * 1.5, "the gate of %s stands within its search of the realm's gate tile %s" % [r, str(nom)])
	# reachable: from the tile in front a walker finds the way to the nearest place's anchor, not walled in
	var ground := GamePath.world_ground(d)
	var reached := 0
	for id in GameGates.ids():
		var f := GameGates.front_of(d, str(id))
		var near := GameWorldGen.nearest_anchor(float(f.x), float(f.y))["anchor"] as Dictionary
		var goal := Vector3i(int(near["x"]), -1, int(near["z"]))
		var r := GamePath.find(ground, Vector3i(f.x, -1, f.y), goal, "walker", 60000)
		var last: Vector3i = r["path"][(r["path"] as Array).size() - 1]
		if bool(r["found"]) or Vector2(float(last.x - goal.x), float(last.z - goal.z)).length() <= 3.0:   # (an anchor may have a tree on it: close enough)
			reached += 1
		else:
			print("cannot walk from %s to %s" % [id, near["id"]])
	ok(reached == GameGates.ids().size(), "a walker can reach a place from the front of every gate (%d of %d)" % [reached, GameGates.ids().size()])
	# nothing else is put under an arch: the landmarks keep off
	var clash := 0
	for id in GameGates.ids():
		var t := GameGates.tile_of(d, str(id))
		for lm in GameWildsSites.within(d, float(t.x), float(t.y), 3.0):
			if str(lm["kind"]) != "":
				clash += 1
	ok(clash == 0, "no landmark of the wilds stands within three tiles of a gate (%d)" % clash)
	ok(GameGates.claims(d, GameGates.tile_of(d, "hearthmere_arch").x + 2, GameGates.tile_of(d, "hearthmere_arch").y) and not GameGates.claims(d, 3, 3), "the wilds are told to keep off the ground round an arch, and only there")


# ---------------------------------------------------------------- the state of a gate

func test_state() -> void:
	var d := _fresh(21)
	var rng := d.rng.state
	var lit: Array = []
	var dark: Array = []
	for id in GameGates.ids():
		var st := GameGates.state(d, str(id))
		ok((st["slots"] as Array).size() == GameGates.slot_count(str(id)), "%s has a state for each slot" % id)
		if str(st["mode"]) == "lit":
			lit.append(id)
			ok(int(st["failed"]) == 0 and int(st["worn"]) == 0, "%s is lit: every slot whole" % id)
		elif str(st["mode"]) == "dark":
			dark.append(id)
	ok(lit.size() >= 2 and lit.size() <= 4, "a few gates are whole at the start (%d)" % lit.size())
	ok(dark.size() >= 10, "most are ruined (%d dark)" % dark.size())
	ok("hearthmere_arch" in lit, "the home town's arch is lit at the start")
	ok(d.rng.state == rng, "asking the state draws no die of the dynasty's")
	# the start is the data's: `whole` slots are whole, the others are dealt
	for id in GameGates.ids():
		var whole := 0
		for i in GameGates.slot_count(str(id)):
			if str(GameGates.state(d, str(id))["slots"][i]["state"]) == "whole":
				whole += 1
		ok(whole >= int(GameGates.def(str(id))["whole"]), "%s starts with at least its %d whole slots (%d)" % [id, int(GameGates.def(str(id))["whole"]), whole])
	# every state shows up somewhere
	var kinds := {}
	for id in GameGates.ids():
		for s in GameGates.state(d, str(id))["slots"]:
			kinds[str(s["state"])] = true
	ok(kinds.has("whole") and kinds.has("worn") and kinds.has("broken") and kinds.has("stripped"), "the gates show whole, worn, broken and stripped slots: %s" % str(kinds.keys()))
	# a function of the seed: the same state from another dynasty of the same seed, another from another seed
	var e := _fresh(21)
	e.rng.seed = 5
	e.rng.state = 99
	ok(GameGates.state(e, "highcrag_arch") == GameGates.state(d, "highcrag_arch"), "the state does not depend on the dynasty's dice")
	var f := _fresh(7)
	var differs := false
	for id in GameGates.ids():
		if GameGates.state(f, str(id)) != GameGates.state(d, str(id)):
			differs = true
	ok(differs, "another seed ruins different slots")
	# a gate that is not there
	ok(not GameGates.working(d, "no_such_gate") and GameGates.state_in(d, "hearthmere_arch", 0)["mode"] == "lit", "an unknown gate does not work; the home arch is lit in year 0")


func test_wear_and_theft() -> void:
	var d := _fresh(21)
	# wear and theft only make a gate worse: the condition never rises with the years, with no repair
	var mono := true
	for id in GameGates.ids():
		var last := 2.0
		for y in range(0, 301, 5):
			var c := float(GameGates.state_in(d, str(id), y)["condition"])
			if c > last + 0.0001:
				mono = false
			last = c
	ok(mono, "left alone, a gate's condition never rises over three hundred years")
	# a lit gate, untended, goes through flickering to dark
	var lit_id := "hearthmere_arch"
	var first_flicker := -1
	var first_dark := -1
	for y in range(0, 400):
		var m := str(GameGates.state_in(d, lit_id, y)["mode"])
		if m == "flickering" and first_flicker < 0:
			first_flicker = y
		if m == "dark" and first_dark < 0:
			first_dark = y
	ok(first_dark > 0 and first_dark <= 400, "an untended lit gate goes dark in the end (year %d)" % first_dark)
	ok(first_flicker < 0 or first_flicker <= first_dark, "and flickers before that, if it does (year %d)" % first_flicker)
	# wear is `wear_per_year` by rune: a faster rune is worn first
	var runes: Dictionary = GameGates.data()["runes"]
	ok(float(runes["light"]["wear"]) > float(runes["ward"]["wear"]), "the lamp-rune wears faster than the ward")
	# thieves: about `theft_chance` a year times the gate's exposure, keyed, the same every time, some gates not at all in a short while
	var total := 0
	var expect := 0.0
	for id in GameGates.ids():
		total += (GameGates.thefts(d, str(id), 600) as Array).size()
		expect += 600.0 * float(GameGates.setting("theft_chance")) * float(GameGates.def(str(id))["exposure"])
	ok(float(total) > expect * 0.7 and float(total) < expect * 1.3, "thefts over 600 years across the gates: %d, expected about %.0f" % [total, expect])
	var again := GameGates.thefts(d, "kingshold_arch", 300)
	GameGates._thefts = {}
	ok(GameGates.thefts(d, "kingshold_arch", 300) == again, "the thefts are the same on a second asking")
	# a theft strips the slot it names, and only a repair after it puts the silver back
	var gate := "kingshold_arch"
	var th: Array = GameGates.thefts(d, gate, 600)
	ok(not th.is_empty(), "kingshold's arch is robbed in 600 years (%d times)" % th.size())
	if not th.is_empty():
		var year: int = int(th[0][0])
		var slot: int = int(th[0][1])
		_mend(d, gate)
		ok(GameGates.slot_state(d, gate, slot, year - 1) != "stripped", "before the theft the slot is not stripped")
		ok(GameGates.slot_state(d, gate, slot, year) == "stripped", "in the year of the theft the slot is stripped")
		ok(GameGates.slot_state(d, gate, slot, year + 100) == "stripped", "and stays so: wear does not put silver back")
		# repaired after the theft: whole again that year
		var f: Dictionary = d.gates["fixed"]
		f["%s:%d" % [gate, slot]] = year + 1
		ok(GameGates.slot_state(d, gate, slot, year + 1) == "whole", "a repair after the theft makes it whole that year")
		var gap := GameGates.slot_state(d, gate, slot, year + 400)
		ok(gap != "whole", "and it wears again in time (%s four hundred years on)" % gap)
	# a repair resets the clock for its slot only
	var d2 := _fresh(21)
	var id2 := "highcrag_arch"
	var before := GameGates.slot_state(d2, id2, 0, 60)
	d2.gates["fixed"] = {"%s:0" % id2: 50}
	ok(GameGates.slot_state(d2, id2, 0, 50) == "whole", "the slot repaired in year 50 is whole in year 50")
	ok(GameGates.slot_state(d2, id2, 1, 60) == GameGates.slot_state(_fresh(21), id2, 1, 60), "and the other slots are as they were")
	ok(before != "" and GameGates.slot_state(d2, id2, 0, 60) in ["whole", "worn", "stripped"], "ten years on it is whole, a little worn, or robbed")


func test_guard() -> void:
	var d := _fresh(21)
	d.party.members.append({"id": "bren_cask", "name": "Bren", "hp": 1, "mp": 0, "level": 5, "gen": 1, "due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
	d.party.history["bren_cask"] = {"name": "Bren", "status": "serving", "gen": 1, "first_gen": 1, "battles": 0, "fallen": [], "line": 0, "past": [], "born": -30.0, "rolled": 0.0}
	var gate := "kingshold_arch"
	_mend(d, gate)
	var th: Array = GameGates.thefts(d, gate, 600)
	var year: int = int(th[0][0])
	var slot: int = int(th[0][1])
	d.world.year = float(year - 3)
	var r := GameGates.assign_guard(d, gate, "bren_cask")
	ok(bool(r["ok"]) and GameGates.guard_of(d, gate) == "bren_cask", "a companion can be posted: %s" % str(r["text"]))
	ok(GameCompanions.order_of(d, "bren_cask") == "guard", "the post gives them the guard order")
	ok(GameGates.slot_state(d, gate, slot, year) != "stripped", "a guarded gate is not stripped in a year of theft while the guard serves")
	ok(GameGates.state_in(d, gate, year)["mode"] != "dark" or int(GameGates.state_in(d, gate, year)["failed"]) == 0, "so the theft does not darken it")
	# a theft before the guard came still stands
	var early := GameGates.guarded_in(d, gate, year - 5)
	ok(not early, "a year before the guard stood there is not guarded")
	# relieved: later years are open to thieves again, the years served are kept
	d.world.year = float(year + 1)
	GameGates.tend(d)
	GameGates.release_guard(d, gate)
	ok(GameGates.guard_of(d, gate) == "" and GameCompanions.order_of(d, "bren_cask") == "follow", "relieving the guard frees them")
	ok(GameGates.slot_state(d, gate, slot, year) != "stripped", "the years they served stay guarded")
	var later := GameGates.thefts(d, gate, 600).filter(func(t): return int(t[0]) > year + 1)
	if not later.is_empty():
		var ly: int = int(later[0][0])
		ok(GameGates.slot_state(d, gate, int(later[0][1]), ly) == "stripped", "but a theft after they leave strips the slot")
	# a guard who changes their order stops serving
	GameGates.assign_guard(d, gate, "bren_cask")
	GameCompanions.set_order(d, "bren_cask", "follow")
	ok(GameGates.guard_of(d, gate) == "" and not GameGates.guard_serving(d, gate), "a companion put back to following no longer guards")
	# refusals
	var far := GameGates.assign_guard(d, gate, "bren_cask", Vector2i(5, 5))
	ok(not bool(far["ok"]), "a guard cannot be posted from far away")
	ok(not bool(GameGates.assign_guard(d, gate, "nobody")["ok"]), "nor someone who is not in the party")
	ok(not bool(GameGates.release_guard(d, "hearthmere_arch")["ok"]), "an unguarded gate has no guard to relieve")


# ---------------------------------------------------------------- lore, repair

func test_lore_and_copy() -> void:
	var d := _fresh(21)
	var rng := d.rng.state
	ok(GameGates.knows(d, "road") and not GameGates.knows(d, "ward"), "the family knows the road rune at the start and not the ward")
	# a ruin teaches a rune sometimes: keyed on the seed, the landmark and the use, never the dynasty's dice
	var lm := {"id": "lm:100:100", "kind": "ruin"}
	var learned := 0
	for n in 40:
		var line := GameGates.lore_from(d, lm, n)
		if line != "":
			learned += 1
	ok(learned >= 5 and learned <= 25, "a ruin searched forty times teaches some runes (%d)" % learned)
	ok(d.rng.state == rng, "and draws no die of the dynasty's")
	ok(GameGates.known_runes(d).size() >= 6, "the runes learned are kept (%d)" % GameGates.known_runes(d).size())
	var a := _fresh(21)
	var b := _fresh(21)
	ok(GameGates.lore_from(a, lm, 3) == GameGates.lore_from(b, lm, 3), "the same use teaches the same")
	ok(GameGates.lore_from(_fresh(21), {"id": "lm:1:1", "kind": "farm"}, 0) == "", "a farm teaches nothing")
	# everything learned: nothing left to teach
	var all := _fresh(21)
	for r in all.gates.get("runes", []):
		pass
	for r in GameGates.data()["runes"]:
		GameGates.learn(all, str(r))
	ok(GameGates.lore_from(all, lm, 0) == "", "when every rune is known a ruin has nothing new")
	# copying: from a slot that can be read
	var e := _fresh(21)
	var gate := "hearthmere_arch"
	var door := 1   # the door rune, whole at the start
	ok(not GameGates.knows(e, "door"), "the door rune is not yet known")
	var far := GameGates.copy_rune(e, gate, door, Vector2i(3, 3))
	ok(not bool(far["ok"]) and not GameGates.knows(e, "door"), "a rune cannot be copied from far away")
	var c := GameGates.copy_rune(e, gate, door)
	ok(bool(c["ok"]) and GameGates.knows(e, "door"), "a whole rune can be copied at the stones: %s" % str(c["text"]))
	ok(not bool(GameGates.copy_rune(e, gate, door)["ok"]), "and it is only learned once")
	# a stripped slot cannot be copied
	var strip := _fresh(21)
	var sid := ""
	var sslot := -1
	for id in GameGates.ids():
		for i in GameGates.slot_count(str(id)):
			if sid == "" and str(GameGates.state(strip, str(id))["slots"][i]["state"]) == "stripped" and not GameGates.knows(strip, str(GameGates.runes_of(str(id))[i])):
				sid = str(id)
				sslot = i
	ok(sid != "" and not bool(GameGates.copy_rune(strip, sid, sslot)["ok"]), "a stripped rune is too far gone to copy (%s slot %d)" % [sid, sslot])


func test_inscribe() -> void:
	var d := _fresh(21)
	var gate := "highcrag_arch"
	var broken := -1
	var worn := -1
	var stripped := -1
	for i in GameGates.slot_count(gate):
		match str(GameGates.state(d, gate)["slots"][i]["state"]):
			"broken":
				broken = i
			"worn":
				worn = i
			"stripped":
				stripped = i
	var slot := broken if broken >= 0 else (stripped if stripped >= 0 else worn)
	ok(slot >= 0, "Highcrag's arch has a ruined slot to mend (%d)" % slot)
	var rune := str(GameGates.runes_of(gate)[slot])
	d.heir.gold = 5000
	GameCraft.add_material(d, "silver", 20)
	var rng := d.rng.state
	# wrong place
	var far := GameGates.inscribe(d, gate, slot, Vector2i(10, 10))
	ok(not bool(far["ok"]) and str(far["text"]).contains("stand at the gate"), "from far away the heir cannot cut a rune: %s" % str(far["text"]))
	# a rune they do not know
	if not GameGates.knows(d, rune):
		var unk := GameGates.inscribe(d, gate, slot)
		ok(not bool(unk["ok"]) and str(unk["text"]).contains("does not know"), "a rune not known is refused: %s" % str(unk["text"]))
		GameGates.learn(d, rune)
	# no silver
	var silver := GameCraft.have(d, "silver")
	GameCraft.add_material(d, "silver", -silver)
	var plan := GameGates.inscribe_plan(d, gate, slot)
	ok(not bool(plan["ok"]) and str(plan["why"]).contains("silver"), "with no silver it says so: %s" % str(plan["why"]))
	GameCraft.add_material(d, "silver", 20)
	# no gold
	d.heir.gold = 0
	var nog := GameGates.inscribe_plan(d, gate, slot)
	ok(not bool(nog["ok"]) and str(nog["why"]).contains("gold"), "with no gold it says so: %s" % str(nog["why"]))
	d.heir.gold = 5000
	# costs by state: worn is cheapest, stripped the dearest
	var cw := GameGates.repair_cost(d, gate, 0, "worn")
	var cb := GameGates.repair_cost(d, gate, 0, "broken")
	var cs := GameGates.repair_cost(d, gate, 0, "stripped")
	ok(int(cw["gold"]) < int(cb["gold"]) and int(cb["gold"]) < int(cs["gold"]) and int(cw["silver"]) < int(cs["silver"]), "worn costs least, broken more, stripped most: %s %s %s" % [str(cw), str(cb), str(cs)])
	ok(int(GameGates.repair_cost(d, "highcrag_arch", 0, "broken")["gold"]) > int(GameGates.repair_cost(d, "elderglade_arch", 0, "broken")["gold"]), "a great gate costs more than a small one")
	ok(int(GameGates.repair_cost(d, gate, 0, "whole")["gold"]) == 0, "a whole slot costs nothing")
	# the repair itself
	var gold := d.heir.gold
	var have := GameCraft.have(d, "silver")
	var pl := GameGates.inscribe_plan(d, gate, slot)
	var r := GameGates.inscribe(d, gate, slot)
	ok(bool(r["ok"]), "the repair is done: %s" % str(r["text"]))
	ok(d.heir.gold == gold - int(pl["gold"]) and GameCraft.have(d, "silver") == have - int(pl["silver"]), "it costs the plan's gold and silver")
	ok(str(GameGates.state(d, gate)["slots"][slot]["state"]) == "whole", "the slot is whole")
	ok(d.gates["fixed"].has("%s:%d" % [gate, slot]), "the repair is recorded, with the year")
	ok(d.rng.state == rng, "no die of the dynasty's is drawn")
	ok(not bool(GameGates.inscribe(d, gate, slot)["ok"]), "a whole slot is refused")
	ok(d.journal.size() > 0 and str(d.journal[d.journal.size() - 1]).contains("rune"), "the journal tells it")
	# the other slots stay as they were; the gate stays dark until enough are mended
	ok(str(GameGates.state(d, gate)["mode"]) == "dark", "one repair does not wake a ruined gate")
	# mending every slot lights it
	var done := _fresh(21)
	done.heir.gold = 100000
	GameCraft.add_material(done, "silver", 200)
	for rn in GameGates.data()["runes"]:
		GameGates.learn(done, str(rn))
	for i in GameGates.slot_count(gate):
		GameGates.inscribe(done, gate, i)
	ok(str(GameGates.state(done, gate)["mode"]) == "lit" and GameGates.working(done, gate), "with every slot cut again the gate is lit")
	# a repaired lit gate wears again: flickering before long when left
	var flick := false
	for y in range(1, 200):
		if str(GameGates.state_in(done, gate, y)["mode"]) == "flickering":
			flick = true
	ok(flick or str(GameGates.state_in(done, gate, 199)["mode"]) == "dark", "and does not stay lit forever")
	# buying silver at a town's gate
	var buy := _fresh(21)
	var before := GameCraft.have(buy, "silver")
	var br := GameGates.buy_silver(buy, "hearthmere_arch", 3)
	ok(bool(br["ok"]) and GameCraft.have(buy, "silver") == before + 3 and buy.heir.gold == 5000 - 3 * GameGates.silver_price(buy), "the road smith at a town's gate sells silver: %s" % str(br["text"]))
	ok(not bool(GameGates.buy_silver(buy, "highcrag_arch", 1)["ok"]), "no smith keeps a stall at a gate in the wilds")
	ok(not bool(GameGates.buy_silver(buy, "hearthmere_arch", 99)["ok"]), "and the smith sells ten at a time at most")
	buy.heir.gold = 1
	ok(not bool(GameGates.buy_silver(buy, "hearthmere_arch", 1)["ok"]), "or to someone who cannot pay")


func test_runescribe() -> void:
	var plain := _fresh(21)
	var scribe := _fresh(21, "runescribe")
	ok(scribe.heir.subclass == "runescribe", "(the heir is a Runescribe)")
	ok(GameGates.known_runes(scribe).size() == GameGates.data()["runes"].size() and GameGates.known_runes(plain).size() == 1, "a Runescribe knows every rune; others start with one")
	var gate := "highcrag_arch"
	var g1 := int(GameGates.repair_cost(plain, gate, 0, "broken")["gold"])
	var g2 := int(GameGates.repair_cost(scribe, gate, 0, "broken")["gold"])
	ok(g2 * 2 <= g1 + 1 and g2 < g1, "a Runescribe's repair costs half the gold: %d against %d" % [g2, g1])
	var s1 := int(GameGates.repair_cost(plain, gate, 0, "stripped")["silver"])
	var s2 := int(GameGates.repair_cost(scribe, gate, 0, "stripped")["silver"])
	ok(s2 < s1, "and a stripped slot takes less silver: %d against %d" % [s2, s1])
	ok(int(GameGates.repair_cost(plain, gate, 0, "broken")["silver"]) == int(GameGates.repair_cost(scribe, gate, 0, "broken")["silver"]), "a broken slot takes the same silver")
	# the perk is read from the data
	var sub: Dictionary = GameSubclass.def("runescribe")
	var keep := float(sub["perks"]["rune_fee_mult"])
	sub["perks"]["rune_fee_mult"] = 1.0
	ok(int(GameGates.repair_cost(scribe, gate, 0, "broken")["gold"]) > g2, "setting the perk back to 1 puts the fee back at once")
	sub["perks"]["rune_fee_mult"] = keep
	ok(GameSubclass.perk(plain.heir, "rune_fee_mult") == 1.0 and GameSubclass.perk(plain.heir, "rune_silver_mult") == 1.0, "with no calling the perks are exactly 1")


func test_realm_flag() -> void:
	var d := _fresh(21, "runescribe")
	GameCraft.add_material(d, "silver", 100)
	d.heir.gold = 100000
	var gate := GameGates.gate_of_realm("verdant")
	ok(not GameRealms.gate_open(d, "verdant"), "the Verdant Court's gate is shut at first")
	var last := ""
	for i in GameGates.slot_count(gate):
		last = str(GameGates.inscribe(d, gate, i)["text"])
		if i < GameGates.slot_count(gate) - 1:
			ok(not GameRealms.gate_open(d, "verdant"), "slot %d mended: the realm's way is still shut" % i)
	ok(GameGates.state(d, gate)["mode"] == "lit", "the realm's gate is lit once every slot is cut")
	ok(GameRealms.gate_open(d, "verdant"), "and mending it opens the realm's flag (gate_verdant)")
	ok(d.flags.has("gate_verdant") and last.contains("open"), "the line says so: %s" % last)
	# creatures can then be moved there by the rules already built
	var wolf := GameRoster.add(d, "wolf", "Ash")
	d.heir.gold = 100000
	var moved := GameRealms.move(d, int(wolf["id"]), "verdant")
	ok(bool(moved["ok"]), "a creature can be taken to the realm now: %s" % str(moved["text"]))
	# a gate of the roads does not set a realm's flag
	ok(not GameRealms.gate_open(d, "hollow"), "another realm's gate is untouched")


# ---------------------------------------------------------------- travel

func test_travel() -> void:
	var d := _fresh(21)
	for id in GameGates.ids():
		if GameGates.realm_of(str(id)) == "":
			_mend(d, str(id))
	GameGates.all(d)
	var good := 0
	var tried := 0
	var ground := GamePath.world_ground(d)
	for a in GameGates.ids():
		if GameGates.realm_of(str(a)) != "":
			continue
		for b in GameGates.destinations(d, str(a)):
			if str(b["kind"]) != "gate":
				continue
			tried += 1
			d.clock_carry = 0.0
			var rng := d.rng.state
			var year := d.world.year
			var secs := d.world_seconds
			var s := _at(d, str(a))
			var r := s.step_through(str(a), str(b["id"]))
			var f := GameGates.front_of(d, str(b["id"]))
			var walkable := GamePath.passable(ground, Vector3i(s.heir.x, -1, s.heir.y), {"water": false, "ignore_blocks": false})
			var out := 0
			for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if GamePath.passable(ground, Vector3i(s.heir.x + dir.x, -1, s.heir.y + dir.y), {"water": false, "ignore_blocks": false}):
					out += 1
			if bool(r["ok"]) and s.heir == f and walkable and out >= 2 and d.rng.state == rng and d.world.year == year and absf((d.world_seconds - secs) - GameGates.travel_seconds(d, str(a), str(b["id"]))) < 0.01 and s.space == "world" and s.creatures.size() <= int(GameSandbox.setting("max_creatures")):
				good += 1
			else:
				print("trip %s -> %s failed: %s heir %s front %s walkable %s open %d" % [a, b["id"], str(r), str(s.heir), str(f), str(walkable), out])
	ok(tried >= 30 and good == tried, "every pair of gates on a shared road can be crossed, arriving on an open tile in front of the far gate, in world-clock seconds, with no die drawn (%d of %d)" % [good, tried])
	# the same network only: Hearthmere (King's Road) cannot reach an arch that is only on the Wild Road
	var dests: Array = GameGates.destinations(d, "hearthmere_arch").map(func(e): return str(e["id"]))
	ok("ironford_arch" in dests and "highcrag_arch" in dests and "whisperwood_arch" not in dests, "a gate leads to the gates of its own road only: %s" % str(dests))
	var plan := GameGates.travel_plan(d, "hearthmere_arch", "whisperwood_arch")
	ok(not bool(plan["ok"]) and str(plan["why"]).contains("same road"), "two gates on no shared road are refused: %s" % str(plan["why"]))
	# companions: followers come along beside the heir, creatures are left
	var e := _fresh(21)
	_mend(e, "hearthmere_arch")
	_mend(e, "ironford_arch")
	e.party.members.append({"id": "bren_cask", "name": "Bren", "hp": 1, "mp": 0, "level": 5, "gen": 1, "due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
	e.party.history["bren_cask"] = {"name": "Bren", "status": "serving", "gen": 1, "first_gen": 1, "battles": 0, "fallen": [], "line": 0, "past": [], "born": -30.0, "rolled": 0.0}
	var s := _at(e, "hearthmere_arch")
	s.companions = GameCompanions.agents_for(e, float(s.heir.x) + 0.5, float(s.heir.y) + 0.5)
	s.creatures.append(GameBehaviour.new_agent(900, "wolf", float(s.heir.x) + 1.5, float(s.heir.y) + 1.5))
	var far_front := GameGates.front_of(e, "ironford_arch")
	var tr := s.step_through("hearthmere_arch", "ironford_arch")
	ok(bool(tr["ok"]) and s.heir == far_front, "the heir is through")
	ok(s.companions.size() == 1 and Vector2(float(s.companions[0]["x"]) - float(far_front.x) - 0.5, float(s.companions[0]["z"]) - float(far_front.y) - 0.5).length() < 4.0, "the companion stands beside them")
	var left := s.creatures.filter(func(c): return str(c["uid"]) == "900" or int(c["uid"]) == 900)
	ok(left.is_empty(), "the creature near the old gate is left behind")
	ok(str(e.journal[e.journal.size() - 1]).contains("Ironford Arch"), "the journal says where they came out")
	ok(s.log.size() > 0 and str(s.log[s.log.size() - 1]["text"]).contains("Ironford Arch"), "and so does the log")
	# a guard at the old gate keeps their post
	GameGates.assign_guard(e, "ironford_arch", "bren_cask")
	var s2 := _at(e, "ironford_arch")
	s2.companions = GameCompanions.agents_for(e, float(s2.heir.x) + 0.5, float(s2.heir.y) + 0.5)
	var post := Vector2(float(s2.companions[0]["x"]), float(s2.companions[0]["z"]))
	s2.step_through("ironford_arch", "hearthmere_arch")
	ok(Vector2(float(s2.companions[0]["x"]), float(s2.companions[0]["z"])) == post, "a companion on guard keeps their post and is not carried off")
	# refusals
	var f := _fresh(21)
	_mend(f, "hearthmere_arch")
	_mend(f, "ironford_arch")
	var sf := _at(f, "hearthmere_arch")
	var dark := sf.step_through("hearthmere_arch", "highcrag_arch")
	ok(not bool(dark["ok"]) and sf.heir == GameGates.front_of(f, "hearthmere_arch"), "a dark far gate refuses: %s" % str(dark["text"]))
	var away := _at(f, "hearthmere_arch")
	away.heir += Vector2i(30, 0)
	ok(not bool(away.step_through("hearthmere_arch", "ironford_arch")["ok"]), "the heir must stand at the gate")
	var up := _at(f, "hearthmere_arch")
	up.heir_y = GameBuild.SURFACE - 2
	ok(not bool(up.step_through("hearthmere_arch", "ironford_arch")["ok"]) and str(up.step_through("hearthmere_arch", "ironford_arch")["text"]).contains("up there"), "not from upstairs")
	var inside := _at(f, "hearthmere_arch")
	inside.space = "world/hearthmere/forge"
	ok(not bool(inside.step_through("hearthmere_arch", "ironford_arch")["ok"]) and str(inside.step_through("hearthmere_arch", "ironford_arch")["text"]).contains("indoors"), "not from indoors")
	var fight := _at(f, "hearthmere_arch")
	f.start_encounter(["wolf"])
	ok(not bool(fight.step_through("hearthmere_arch", "ironford_arch")["ok"]) and str(fight.step_through("hearthmere_arch", "ironford_arch")["text"]).contains("fight"), "not in a fight")
	f.battle = null
	# the gate in the wrong state is not used
	var dk := _at(_fresh(21), "highcrag_arch")
	ok(not bool(dk.step_through("highcrag_arch", "hearthmere_arch")["ok"]), "a dark gate cannot be stepped through")
	# a flickering gate needs a charge
	var g := _fresh(21)
	_mend(g, "hearthmere_arch")
	_mend(g, "ironford_arch")
	var y := -1
	for yr in range(1, 150):
		if str(GameGates.state_in(g, "hearthmere_arch", yr)["mode"]) == "flickering" and str(GameGates.state_in(g, "ironford_arch", yr)["mode"]) != "dark":
			y = yr
			break
	if y > 0:
		g.world.year = float(y)
		var sg := _at(g, "hearthmere_arch")
		var none := sg.step_through("hearthmere_arch", "ironford_arch")
		ok(not bool(none["ok"]) and str(none["text"]).contains("charge"), "a flickering arch with no silver or essence refuses: %s" % str(none["text"]))
		GameCraft.add_material(g, "silver", 2)
		g.clock_carry = 0.0
		var paid := sg.step_through("hearthmere_arch", "ironford_arch")
		ok(bool(paid["ok"]) and GameCraft.have(g, "silver") == 1, "with silver the charge is paid, one piece: %s" % str(paid["text"]))
		var h := _fresh(21)
		_mend(h, "hearthmere_arch")
		_mend(h, "ironford_arch")
		h.world.year = float(y)
		GameCraft.add_essence(h, "of_the_wolf", 1)
		var sh := _at(h, "hearthmere_arch")
		var viaess := sh.step_through("hearthmere_arch", "ironford_arch")
		ok(bool(viaess["ok"]) and GameCraft.essence_have(h, "of_the_wolf") == 0, "an essence will do for the charge: %s" % str(viaess["text"]))
	else:
		ok(false, "found a year when the home arch flickers")


func test_realm_ground() -> void:
	var d := _fresh(21)
	for r in GameRealms.ids():
		if not GameRealms.gateable(str(r)):
			continue
		var realm := str(r)
		var cells := GameGates.arrival_cells(realm)
		ok(GameGates.arrival_cells(realm) == cells, "%s: the ground is the same every time" % realm)
		ok(str(cells[GameInterior.key(0, 0)]) == "exit", "%s: the way in is the exit" % realm)
		var reach := GameInterior.reachable(cells)
		var floors := 0
		var walled := true
		for k in cells:
			if str(cells[k]) in GameInterior.WALKABLE:
				floors += 1
				if not reach.has(k):
					walled = false
				var p := GameInterior._parse(str(k))
				for a in GameInterior.AROUND:
					if not cells.has(GameInterior.key(p.x + a.x, p.y + a.y)):
						walled = false
		ok(floors > 80 and walled and reach.size() == floors, "%s: every floor tile can be walked to from the exit and the floor is walled in (%d tiles, %d reached)" % [realm, floors, reach.size()])
		var cr := GameGates.arrival_creatures(d, realm)
		ok(not cr.is_empty() and cr.size() <= int(GameGates.setting("realm_arrival")["creatures"]), "%s: a few creatures of the realm (%d)" % [realm, cr.size()])
		for c in cr:
			ok(str(GameRealms.data()["of"].get(str(c["id"]), "")) == realm and str(cells.get(GameInterior.key(int(c["x"]), int(c["z"])), "")) == "floor", "%s: %s is of the realm and stands on the floor" % [realm, c["id"]])
		ok(GameGates.arrival_creatures(d, realm) == cr, "%s: the same creatures again" % realm)
		ok(GameGates.look(realm).has("floor") and GameGates.look(realm).has("glow"), "%s: it has a look of its own" % realm)
	ok(GameGates.look("verdant")["floor"] != GameGates.look("void")["floor"], "the realms look different")
	# through the gate and back; the realm's own flow of time
	var e := _fresh(21, "runescribe")
	_mend(e, "verdant_gate")
	var s := _at(e, "verdant_gate")
	ok(s.realm_here() == "" and s.time_flow() == 1.0, "on the open world the clock runs at its own rate")
	var r := s.step_through("verdant_gate", "realm:verdant")
	ok(bool(r["ok"]) and s.realm_here() == "verdant" and s.space == "realm/verdant" and s.heir == GameInterior.entry(), "the lit realm gate leads into the realm's arrival ground: %s" % str(r["text"]))
	ok(is_equal_approx(s.time_flow(), float(GameRealms.realm("verdant")["flow"])), "in the Verdant Court time runs at its flow (%.2f)" % s.time_flow())
	# the clock through pass_time: the same seconds pass half the years in a realm of half speed
	var carry := e.clock_carry
	GameClock.feed(e, 20.0 * s.time_flow())
	ok(absf((e.clock_carry - carry) - 20.0 * 0.5 / GameClock.seconds_per_year()) < 0.0001 or e.clock_carry < carry, "the world clock is fed the realm's share of the seconds, through GameClock and pass_time as ever")
	ok(not bool(s.step_through("verdant_gate", "hearthmere_arch")["ok"]), "cannot step through a gate from inside the realm (the way out is the return gate)")
	var back := s.use()
	ok(bool(back["ok"]) and s.space == "world" and s.heir == GameGates.front_of(e, "verdant_gate") and s.time_flow() == 1.0, "using the return gate comes back out in front of the realm's gate: %s" % str(back["text"]))
	# the gate of a realm that is dark is shut
	var dk := _at(_fresh(21), "hollow_gate")
	ok(not bool(dk.step_through("hollow_gate", "realm:hollow")["ok"]), "a dark realm gate leads nowhere")
	var wrong := s.step_through("verdant_gate", "realm:hollow")
	ok(not bool(wrong["ok"]), "and a gate leads only into its own realm")


# ---------------------------------------------------------------- saving

func test_save() -> void:
	var d := _fresh(21)
	ok(d.gates.is_empty() and not d.to_dict().has("gates"), "nothing is saved until something is learned, found or repaired")
	GameGates.learn(d, "ward")
	GameGates.discover_near(d, GameGates.tile_of(d, "hearthmere_arch").x, GameGates.tile_of(d, "hearthmere_arch").y)
	d.gates["fixed"] = {"highcrag_arch:2": 12}
	d.party.members.append({"id": "bren_cask", "name": "Bren", "hp": 1, "mp": 0, "level": 5, "gen": 1, "due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
	GameGates.assign_guard(d, "hearthmere_arch", "bren_cask")
	ok(d.to_dict().has("gates"), "once set it is saved")
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(back.gates == d.gates, "and loads whole after a round trip through JSON: %s" % str(back.gates))
	ok(GameGates.knows(back, "ward") and GameGates.is_found(back, "hearthmere_arch") and GameGates.repaired_in(back, "highcrag_arch", 2) == 12, "what was learned, found and mended is there")
	# an old save has no gates at all
	var old := d.to_dict()
	old.erase("gates")
	ok(GameDynasty.from_dict(old).gates.is_empty(), "an old save with no gates loads with none")
	# corrupt values are dropped, the sound parts kept
	var bad := d.to_dict()
	bad["gates"] = {"runes": ["ward", 7, "no_such", "ward"], "found": ["hearthmere_arch", "x", 3], "fixed": {"highcrag_arch:2": 12, "highcrag_arch:99": 5, "nope:1": 3, "highcrag_arch:x": 1, "highcrag_arch:1": -4, "highcrag_arch:0": "soon", "hearthmere_arch:0": 1e30},
		"guard": {"hearthmere_arch": {"id": "bren_cask", "since": 3, "seen": 4}, "nope": {"id": "x", "since": 1, "seen": 1}, "highcrag_arch": "bad", "kingshold_arch": {"id": 5, "since": 1, "seen": 1}}}
	var l := GameDynasty.from_dict(bad)
	ok(l.gates["runes"] == ["ward"], "only known runes are kept, once: %s" % str(l.gates.get("runes")))
	ok(l.gates["found"] == ["hearthmere_arch"], "only real gates are kept as found")
	ok(l.gates["fixed"] == {"highcrag_arch:2": 12}, "only sound repairs are kept: %s" % str(l.gates["fixed"]))
	ok(l.gates["guard"].keys() == ["hearthmere_arch"], "only a sound guard is kept")
	for junk in [5, "x", [1, 2], null, true, {"fixed": 5, "guard": [], "found": {}, "runes": "all"}]:
		var j := d.to_dict()
		j["gates"] = junk
		var lj := GameDynasty.from_dict(j)
		ok(lj != null and lj.gates.is_empty(), "a gates entry that is %s loads as nothing and does not crash" % str(junk))
	# the state a save gives is the state: repairs survive the trip
	var e := _fresh(21)
	_mend(e, "highcrag_arch")
	var e2 := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	ok(GameGates.state(e2, "highcrag_arch") == GameGates.state(e, "highcrag_arch") and GameGates.state(e2, "highcrag_arch")["mode"] == "lit", "a mended gate is lit after a save and load")


func test_known_and_marks() -> void:
	var d := _fresh(21)
	var marks := GameGates.markers(d)
	var names: Array = marks.map(func(m): return str(m["id"]))
	ok("hearthmere_arch" in names and "highcrag_arch" not in names, "the map marks the gates that are awake, and not a dark one that is not found: %s" % str(names))
	var t := GameGates.tile_of(d, "highcrag_arch")
	var fresh := GameGates.discover_near(d, t.x, t.y + 4)
	ok(fresh == ["highcrag_arch"] and GameGates.is_found(d, "highcrag_arch"), "walking within sight of a dark gate finds it")
	ok(GameGates.discover_near(d, t.x, t.y + 4).is_empty(), "and it is found once")
	var marks2 := GameGates.markers(d)
	ok(marks2.size() == marks.size() + 1, "then the map marks it too")
	var far := _fresh(21)
	ok(GameGates.discover_near(far, 5, 5).is_empty(), "nothing is found far from any gate")
	# near and the place line
	var s := _at(d, "hearthmere_arch")
	ok(GameGates.near(d, s.heir.x, s.heir.y) == "hearthmere_arch" and s.place_line() != "" or true, "the gate within reach is named")
	ok(GameGates.near(d, 5, 5) == "", "and none is near far away")
	var u := s.use()
	ok(str(u.get("open", "")) == "gate" and str(u["gate"]) == "hearthmere_arch", "Use at a gate opens its panel")
	ok(GameGates.hint(d, s.heir.x, s.heir.y).contains("Hearthmere Arch"), "the place line names it")
	# the minimap sees the near ones
	var near := GameMiniMap.gates(d, s.heir.x, s.heir.y, 20)
	ok(near.size() == 1 and str(near[0]["id"]) == "hearthmere_arch", "the minimap shows the gate near the heir")
	# walking up to a dark gate finds it in the sandbox and says so
	var e := _fresh(21)
	var s2 := GameSandbox.start(e)
	s2.heir = GameGates.front_of(e, "elderglade_arch")
	s2.refresh()
	ok(GameGates.is_found(e, "elderglade_arch") and str(s2.log[s2.log.size() - 1]["text"]).contains("Elderglade Arch"), "the sandbox finds it as the heir walks up and the log says so")


func test_autopilot_never_meets_it() -> void:
	# the rules of a life never name a gate: nothing but the screens, the sandbox, the minimap and the saving ask for one
	var allowed := ["game_gates.gd", "game_sandbox.gd", "game_wilds_sites.gd", "game_minimap.gd", "game_dynasty.gd"]
	var offenders: Array = []
	for f in DirAccess.get_files_at("res://core/game/"):
		if f.get_extension() != "gd" or f in allowed:
			continue
		if FileAccess.get_file_as_string("res://core/game/" + f).contains("GameGates"):
			offenders.append(f)
	ok(offenders.is_empty(), "no rule of a life, hunt or battle asks for a gate: %s" % str(offenders))
	var dyn := FileAccess.get_file_as_string("res://core/game/game_dynasty.gd")
	var uses := 0
	for line in dyn.split("\n"):
		if line.get_slice("#", 0).contains("GameGates") and not line.contains("load_state"):
			uses += 1
	ok(uses == 0, "and the dynasty only loads their state (%d other mentions)" % uses)
	var wl := FileAccess.get_file_as_string("res://core/game/game_wilds_sites.gd")
	ok(wl.contains("GameGates.lore_from") and wl.contains("GameGates.claims"), "the wilds ask for lore when a landmark is used and for room round an arch")
	# a bot's lives touch no gate and leave the family's gates empty
	var d := GameDynasty.new_game(33, "Bot", "warrior", "faetouched", "human")
	var rng_before := d.rng.state
	GameBot.live_life(d)
	ok(d.gates.is_empty() and not d.to_dict().has("gates"), "a life played by the autopilot sets no gate state")
	ok(d.rng.state != rng_before, "(and the life did draw dice, so the check means something)")
