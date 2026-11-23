## Creatures that live at landmarks (GameWildsFights.dwellers, the `dwell` of an `encounter` block in data/world/wilds.json, GameSandbox.landmark_dwellers): the
## foes a landmark would send are seen idling beside it, in the pool and the count, within the radius, on dice keyed on the seed, landmark, fights so far and the hour
## (never the dynasty's), moving only when the hour's slot turns; none once the landmark is cleared or on its cooldown, none at a kind with no `dwell`; the sandbox
## lists those in sight without making them chase or fight; nothing is saved; and a break of the rule is caught.
## Run: godot --headless --path . -s res://tests/test_game_wilds_dwellers.gd
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
	test_dwellers()
	test_hours()
	test_gone()
	test_sandbox()
	test_breaks()
	print("wilds dwellers tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(seed_value: int = 7, gen: int = 1) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.gen = gen
	return d


func _lm(d: GameDynasty, kind: String) -> Dictionary:
	for area in ["greenvale", "whisperwood", "mirefen", "elderglade", "frostreach", "highcrag"]:
		var a := GameWorldGen.anchor(area)
		for r in range(0, 100, 5):
			for ang in 16:
				var x := int(a["x"]) + int(round(cos(float(ang) / 16.0 * TAU) * r))
				var z := int(a["z"]) + int(round(sin(float(ang) / 16.0 * TAU) * r))
				for lm in GameWildsSites.within(d, x, z, 12.0):
					if str(lm["kind"]) == kind:
						return lm
	return {}


func test_data() -> void:
	ok(GameWildsFights.validate().is_empty(), "the data is sound: %s" % str(GameWildsFights.validate()))
	var d := _dyn()
	for kind in ["bandit_camp", "battlefield", "ruin", "cave"]:
		ok(not GameWildsFights.block(_lm(d, kind)).get("dwell", {}).is_empty(), "%s has dwellers" % kind)


func test_dwellers() -> void:
	var d := _dyn()
	var lm := _lm(d, "bandit_camp")
	var st := d.rng.state
	var before := JSON.stringify(d.to_dict())
	var list := GameWildsFights.dwellers(d, lm, 10.0)
	ok(d.rng.state == st, "no die of the dynasty's drawn")
	ok(JSON.stringify(d.to_dict()) == before, "and nothing is saved by looking")
	ok(list.size() > 0 and list.size() == GameWildsFights.foes_for(d, lm).size(), "as many live there as it would send: %d" % list.size())
	var radius := float(GameWildsFights.block(lm)["dwell"]["radius"])
	for i in list.size():
		var e: Dictionary = list[i]
		ok(str(e["id"]) == str(GameWildsFights.foes_for(d, lm)[i]) and str(e["mode"]) == "idle" and str(e["site"]) == str(lm["id"]), "%s idles at the landmark" % e["id"])
		var dist := Vector2(float(e["x"]) - float(lm["x"]) - 0.5, float(e["z"]) - float(lm["z"]) - 0.5).length()
		ok(dist >= 0.99 and dist <= radius + 0.01, "within the radius: %.2f" % dist)
	ok(GameWildsFights.dwellers(d, lm, 10.0) == list, "the same list again")
	ok(GameWildsFights.dwellers(_dyn(), lm, 10.0) == list, "and for the same seed anew")
	var other := GameWildsFights.dwellers(_dyn(8), lm, 10.0)
	ok(other.size() > 0, "another seed has its own")
	ok(GameWildsFights.dwellers(d, _lm(d, "shrine"), 10.0).is_empty(), "nobody lives at a shrine")
	ok(GameWildsFights.dwellers(d, {}, 10.0).is_empty(), "nor nowhere")


func test_hours() -> void:
	var d := _dyn()
	var lm := _lm(d, "bandit_camp")
	var slot := float(GameWildsFights.block(lm)["dwell"]["hours"])
	var a := GameWildsFights.dwellers(d, lm, 1.0)
	var same := GameWildsFights.dwellers(d, lm, slot - 0.1)
	ok(a == same, "within an hour's slot they stand still")
	var moved := false
	for k in range(1, int(24.0 / slot)):
		moved = moved or GameWildsFights.dwellers(d, lm, 1.0 + slot * k) != a
	ok(moved, "when the slot turns they have moved")


func test_gone() -> void:
	var d := _dyn()
	var lm := _lm(d, "bandit_camp")
	GameWildsFights.mark_fought(d, lm)
	ok(GameWildsFights.dwellers(d, lm, 10.0).is_empty(), "after a fight, in its cooldown, they are away")
	d.world.year += float(GameWildsFights.block(lm)["renew_years"]) + 0.1
	d.gen += 1
	ok(not GameWildsFights.dwellers(d, lm, 10.0).is_empty(), "when it runs out they live there again")
	GameWildsFights.won(d, lm)
	ok(GameWildsFights.dwellers(d, lm, 10.0).is_empty(), "a cleared landmark has none")
	d.gen += int(GameWilds.setting("renew_gens"))
	d.world.year += 5.0
	ok(not GameWildsFights.dwellers(d, lm, 10.0).is_empty(), "and they return when it renews")


func test_sandbox() -> void:
	var d := _dyn()
	var lm := _lm(d, "bandit_camp")
	var s := GameSandbox.start(d)
	s.creatures.clear()
	s.heir = Vector2i(int(lm["x"]), int(lm["z"]) + 6)
	var list := s.landmark_dwellers()
	var mine := list.filter(func(e): return str(e["site"]) == str(lm["id"]))
	ok(mine.size() == GameWildsFights.dwellers(d, lm, GameDay.hour(d)).size() and mine.size() > 0, "the sandbox lists those in sight")
	ok(s.creatures.is_empty() and d.battle == null, "they are not creatures of the field: nothing chases or fights")
	s.heir = Vector2i(int(lm["x"]) + 40, int(lm["z"]) + 40)
	ok(s.landmark_dwellers().filter(func(e): return str(e["site"]) == str(lm["id"])).is_empty(), "out of sight they are not listed")
	s.heir = Vector2i(int(lm["x"]), int(lm["z"]) + 6)
	s.space = "somewhere"
	ok(s.landmark_dwellers().is_empty(), "indoors none are listed")


func test_breaks() -> void:
	var data: Dictionary = GameWilds.data()
	var dw: Dictionary = data["landmarks"]["bandit_camp"]["encounter"]["dwell"]
	var was: float = dw["radius"]
	dw["radius"] = 0.5
	ok(not GameWildsFights.validate().is_empty(), "a radius under 1.5 is caught")
	dw["radius"] = was
	var h: float = dw["hours"]
	dw["hours"] = 0.0
	ok(not GameWildsFights.validate().is_empty(), "hours of 0 are caught")
	dw["hours"] = h
	ok(GameWildsFights.validate().is_empty(), "restored, sound again")
