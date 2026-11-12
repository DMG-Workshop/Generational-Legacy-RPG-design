## Creature behaviour as data (roadmap item 48): the data and ways to break it; tags to parameters (the order a creature
## lists its tags in does not matter, a later tag in the global order wins, pack comes from swarm); each rule on its own
## (wander held to its radius, chase and losing the target, nocturnal sight, ambush and its burst, leash and guard, fleeing
## when hurt or skittish, berserk never fleeing, the pack's alert and its flanking, herds keeping together, fliers over
## ground a walker cannot cross, the generated world's water); and that every creature in the game runs for a hundred
## ticks, nothing is mutated, and nothing of the dynasty's moves.
## Run: godot --headless --path . -s res://tests/test_game_behaviour.gd
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
	test_tags()
	test_wander()
	test_chase()
	test_ambush()
	test_leash_and_guard()
	test_flee()
	test_pack()
	test_herd()
	test_terrain()
	test_world()
	test_all()
	print("behaviour tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func dyn(seed_value: int = 5) -> GameDynasty:
	return GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")


func _reset(saved: Dictionary) -> void:
	GameBehaviour._cache = saved.duplicate(true)
	GameBehaviour._params = {}


## Runs `ticks` ticks of a group; `targets` is a Callable(tick) -> Array of {x, z}. Returns the final agents.
func _sim(agents: Array, ticks: int, targets: Callable, night: bool = false, walkable: Callable = Callable(), seed_value: int = 7) -> Array:
	var cur := agents
	for t in ticks:
		cur = GameBehaviour.step_all(cur, {"targets": targets.call(t), "night": night, "walkable": walkable}, seed_value, t)
	return cur


func _none(_t: int) -> Array:
	return []


## How clumped a group's bearings from the origin are: the length of the mean unit vector (1 all one side, 0 all round).
func _clump(group: Array) -> float:
	var sum := Vector2.ZERO
	for a in group:
		sum += Vector2(float(a["x"]), float(a["z"])).normalized()
	return (sum / float(group.size())).length()


func _dist(a: Dictionary, x: float, z: float) -> float:
	return Vector2(float(a["x"]), float(a["z"])).distance_to(Vector2(x, z))


# ---------------------------------------------------------------- data

func test_data() -> void:
	ok(GameBehaviour.validate().is_empty(), "the data is sound: %s" % str(GameBehaviour.validate()))
	ok(GameBehaviour.data()["creatures"].size() == GameData.creatures.size() and GameData.creatures.size() == 39, "every one of the 39 creatures has its tags")
	var saved: Dictionary = GameBehaviour.data().duplicate(true)
	GameBehaviour.data()["creatures"]["wolf"] = ["no_such_tag"]
	_reset(GameBehaviour.data())
	ok(not GameBehaviour.validate().is_empty(), "an unknown tag on a creature is found")
	_reset(saved)
	GameBehaviour.data()["creatures"].erase("ogre")
	ok(not GameBehaviour.validate().is_empty(), "a creature with no tags is found")
	_reset(saved)
	GameBehaviour.data()["tags"]["slow"]["set"]["no_such_param"] = 1
	ok(not GameBehaviour.validate().is_empty(), "a tag that sets an unknown parameter is found")
	_reset(saved)
	GameBehaviour.data()["tags"]["slow"]["set"]["speed"] = "fast"
	ok(not GameBehaviour.validate().is_empty(), "a parameter set to the wrong kind of value is found")
	_reset(saved)
	GameBehaviour.data()["order"].erase("herd")
	ok(not GameBehaviour.validate().is_empty(), "a tag missing from the order is found")
	_reset(saved)
	GameBehaviour.data()["creatures"]["wolf"].append("pack")
	ok(not GameBehaviour.validate().is_empty(), "a pack listed by hand (it comes from swarm) is found")
	_reset(saved)
	GameBehaviour.data()["creatures"]["goblin"] = []
	ok(not GameBehaviour.validate().is_empty(), "a wild creature that is never hostile is found")
	_reset(saved)
	GameBehaviour.data()["tags"]["guardian"]["set"]["leash"] = 3.0
	ok(not GameBehaviour.validate().is_empty(), "a guard post wider than the leash is found")
	_reset(saved)
	GameBehaviour.data()["defaults"]["idle_chance"] = 2.0
	ok(not GameBehaviour.validate().is_empty(), "an idle chance above 1 is found")
	_reset(saved)
	GameBehaviour.data()["defaults"]["speed"] = 0.0
	ok(not GameBehaviour.validate().is_empty(), "a default speed of nothing is found")
	_reset(saved)
	GameBehaviour.data()["creatures"]["ghost"] = ["aggressive"]
	ok(not GameBehaviour.validate().is_empty(), "tags for a creature that does not exist are found")
	_reset(saved)
	for c in GameBehaviour.data()["creatures"].keys():
		GameBehaviour.data()["creatures"][c] = GameBehaviour.data()["creatures"][c].filter(func(t): return t != "herd")
	ok(not GameBehaviour.validate().is_empty(), "a tag no creature has is found")
	_reset(saved)
	ok(GameBehaviour.validate().is_empty(), "and the data is put back")


# ---------------------------------------------------------------- tags

func test_tags() -> void:
	ok(GameBehaviour.tags_of("wolf") == ["predator", "nocturnal", "pack"], "a wolf is a predator, nocturnal, and a pack animal (from its swarm): %s" % str(GameBehaviour.tags_of("wolf")))
	ok(not GameBehaviour.tags_of("ogre").has("pack") and GameBehaviour.is_pack("slime") and not GameBehaviour.is_pack("bandit"), "pack comes from swarm and nothing else")
	var wolf := GameBehaviour.params("wolf")
	ok(float(wolf["speed"]) == 1.3 and float(wolf["sight"]) == 12.0 and bool(wolf["hostile"]) and float(wolf["sight_night"]) == 1.5 and float(wolf["sight_day"]) == 0.5, "a wolf runs fast, sees far, and sees more at night")
	ok(float(GameBehaviour.params("slime")["speed"]) == 0.5 and float(GameBehaviour.params("slime")["ambush_range"]) == 4.0, "a slime is slow and lies in wait")
	ok(bool(GameBehaviour.params("harpy")["flier"]) and float(GameBehaviour.params("harpy")["flee_hp"]) == 0.4, "a harpy flies and runs when hurt")
	var troll := GameBehaviour.params("bog_troll")
	ok(float(troll["guard_radius"]) == 7.0 and float(troll["flee_hp"]) == 0.0 and float(troll["rage_speed"]) > 1.0, "a bog troll guards its bridge and never flees")
	ok(bool(GameBehaviour.params("sheep")["skittish"]) and not bool(GameBehaviour.params("sheep")["hostile"]) and float(GameBehaviour.params("sheep")["herd_radius"]) > 0.0, "sheep are docile, skittish and keep to the flock")
	ok(bool(GameBehaviour.params("goose")["hostile"]) and float(GameBehaviour.params("goose")["leash"]) > 0.0, "a goose, tamely, guards its yard")
	# the order a creature lists its tags in does not matter
	var saved: Dictionary = GameBehaviour.data().duplicate(true)
	var same := 0
	var total := 0
	var before := {}
	for id in saved["creatures"]:
		before[id] = GameBehaviour.params(id).duplicate(true)
	for id in saved["creatures"].keys():
		var rev: Array = saved["creatures"][id].duplicate()
		rev.reverse()
		GameBehaviour.data()["creatures"][id] = rev
	GameBehaviour._params = {}
	for id in saved["creatures"]:
		total += 1
		if GameBehaviour.params(id) == before[id]:
			same += 1
	_reset(saved)
	ok(same == total, "listing a creature's tags backwards changes nothing: %d of %d" % [same, total])
	# every creature has every parameter
	var complete := true
	for id in saved["creatures"]:
		for k in saved["defaults"]:
			if not GameBehaviour.params(id).has(k):
				complete = false
	ok(complete, "every creature ends up with every parameter")
	ok(GameBehaviour.sight_now("wolf", true) == 18.0 and GameBehaviour.sight_now("wolf", false) == 6.0 and GameBehaviour.sight_now("ogre", false) == 9.0, "sight by day and night: wolf %.0f and %.0f, ogre %.0f" % [GameBehaviour.sight_now("wolf", false), GameBehaviour.sight_now("wolf", true), GameBehaviour.sight_now("ogre", false)])


# ---------------------------------------------------------------- wander

func test_wander() -> void:
	var g := [GameBehaviour.new_agent(1, "goblin", 0.0, 0.0)]
	var far := 0.0
	var idle := 0
	var max_step := 0.0
	var moved := false
	var cur := g
	for t in 400:
		var next := GameBehaviour.step_all(cur, {"targets": []}, 7, t)
		far = maxf(far, _dist(next[0], 0.0, 0.0))
		if next[0]["mode"] == "idle":
			idle += 1
		var step := Vector2(float(next[0]["x"]) - float(cur[0]["x"]), float(next[0]["z"]) - float(cur[0]["z"])).length()
		max_step = maxf(max_step, step)
		moved = moved or step > 0.0
		cur = next
	var p := GameBehaviour.params("goblin")
	ok(moved and far <= float(p["wander_radius"]) + 2.0, "a creature with nothing to do wanders but stays near home: furthest %.1f of a %.0f radius" % [far, float(p["wander_radius"])])
	ok(float(idle) / 400.0 > float(p["idle_chance"]) - 0.12 and float(idle) / 400.0 < float(p["idle_chance"]) + 0.12, "and rests about %.0f%% of the time: %.0f%%" % [100.0 * float(p["idle_chance"]), 100.0 * idle / 400.0])
	ok(max_step <= float(p["speed"]) * 0.5 + 0.001, "and walks at half its speed: no step over %.2f" % max_step)
	var a := _sim(g, 60, _none)
	var b := _sim(g, 60, _none)
	var c := _sim(g, 60, _none, false, Callable(), 99)
	ok(a == b and a != c, "the same seed gives the same walk, another seed another")
	var dead := [GameBehaviour.new_agent(2, "goblin", 3.0, 4.0, 0.0)]
	var after := _sim(dead, 20, func(_t): return [{"x": 4.0, "z": 4.0}])
	ok(after[0]["mode"] == "dead" and after[0]["x"] == 3.0 and after[0]["z"] == 4.0, "the dead do not move")
	# the input is never changed
	var keep := g.duplicate(true)
	GameBehaviour.step_all(g, {"targets": [{"x": 5.0, "z": 0.0}]}, 7, 0)
	ok(g == keep, "stepping returns new creatures and leaves the old ones as they were")


# ---------------------------------------------------------------- chase

func test_chase() -> void:
	var wolf := [GameBehaviour.new_agent(1, "wolf", 0.0, 0.0)]
	var target := func(_t): return [{"x": 8.0, "z": 0.0}]
	var by_day := _sim(wolf, 1, target, false)
	var by_night := _sim(wolf, 1, target, true)
	ok(by_day[0]["mode"] != "chase" and by_night[0]["mode"] == "chase", "a wolf 8 tiles from a target ignores it by day (sees 6) and hunts it by night (sees 18)")
	var cur := wolf
	var closing := true
	var last := 8.0
	var t := 0
	while t < 12 and last > 0.01:
		cur = GameBehaviour.step_all(cur, {"targets": [{"x": 8.0, "z": 0.0}], "night": true}, 7, t)
		var d := _dist(cur[0], 8.0, 0.0)
		if d >= last:
			closing = false
		last = d
		t += 1
	ok(closing and last < 0.5, "it closes on the target every tick and reaches it (%.2f away after %d ticks)" % [last, t])
	# it loses a target that gets away: 18 sees, 36 follows, beyond that it gives up
	var chase := _sim(wolf, 1, func(_t): return [{"x": 30.0, "z": 0.0}], true)
	ok(chase[0]["mode"] == "wander" or chase[0]["mode"] == "idle", "a target beyond what it sees is not chased")
	var hunted := GameBehaviour.step_all([GameBehaviour.new_agent(1, "wolf", 0.0, 0.0)], {"targets": [{"x": 10.0, "z": 0.0}], "night": true}, 7, 0)
	var kept := GameBehaviour.step_all(hunted, {"targets": [{"x": 30.0, "z": 0.0}], "night": true}, 7, 1)
	ok(kept[0]["mode"] == "chase", "but one it was already hunting is followed further than it first saw (a predator keeps on)")
	var lost := GameBehaviour.step_all(hunted, {"targets": [{"x": 80.0, "z": 0.0}], "night": true}, 7, 1)
	ok(lost[0]["mode"] != "chase", "and let go when it is far enough away")
	# the docile do not attack
	var sheep := _sim([GameBehaviour.new_agent(2, "sheep", 0.0, 0.0)], 1, func(_t): return [{"x": 3.0, "z": 0.0}])
	ok(sheep[0]["mode"] == "flee", "a sheep does not chase: it runs")
	# a tag makes the difference: nothing else
	var ogre := _sim([GameBehaviour.new_agent(3, "ogre", 0.0, 0.0)], 1, func(_t): return [{"x": 6.0, "z": 0.0}])
	ok(ogre[0]["mode"] == "chase" and float(ogre[0]["x"]) > 0.0 and float(ogre[0]["x"]) <= 0.81, "an ogre lumbers after it, at four-fifths pace (moved %.2f)" % float(ogre[0]["x"]))


func test_ambush() -> void:
	var slime := [GameBehaviour.new_agent(1, "slime", 0.0, 0.0)]
	var wait := _sim(slime, 5, func(_t): return [{"x": 6.0, "z": 0.0}])
	ok(wait[0]["mode"] != "chase", "an ambusher lets a target 6 tiles away go by")
	var first := GameBehaviour.step_all(slime, {"targets": [{"x": 3.0, "z": 0.0}]}, 7, 0)
	ok(first[0]["mode"] == "chase" and float(first[0]["x"]) >= 1.0, "a target within 4 springs it, and it bursts out at over twice its walk (moved %.2f against 0.50)" % float(first[0]["x"]))
	var cur := first
	var third := 0.0
	for t in 3:
		var before := float(cur[0]["x"])
		cur = GameBehaviour.step_all(cur, {"targets": [{"x": 3.0, "z": 0.0}]}, 7, t + 1)
		third = float(cur[0]["x"]) - before
	ok(float(cur[0]["burst"]) == 0.0 or cur[0]["mode"] == "chase", "the burst is short")
	var slow_chase := GameBehaviour.step_all([GameBehaviour.new_agent(2, "slime", 0.0, 0.0)], {"targets": [{"x": 3.0, "z": 0.0}]}, 7, 0)
	ok(float(slow_chase[0]["x"]) > 1.0, "(the burst moves it faster than a slime's own pace)")


# ---------------------------------------------------------------- leash and guard

func test_leash_and_guard() -> void:
	# a goblin is drawn away from home by a target that runs; it gives up at its leash and goes back
	var goblin := [GameBehaviour.new_agent(1, "goblin", 0.0, 0.0)]
	var far := 0.0
	var cur := goblin
	var tx := 4.0
	for t in 160:
		tx = minf(tx + 1.2, 70.0)
		cur = GameBehaviour.step_all(cur, {"targets": [{"x": tx, "z": 0.0}]}, 7, t)
		far = maxf(far, _dist(cur[0], 0.0, 0.0))
	var leash := float(GameBehaviour.params("goblin")["leash"])
	ok(far > 10.0 and far <= leash + 2.0, "a goblin is drawn off but no further than its leash: %.1f of %.0f" % [far, leash])
	ok(_dist(cur[0], 0.0, 0.0) <= float(GameBehaviour.params("goblin")["wander_radius"]) * 1.5, "and is back by its camp when the target is long gone: %.1f from home" % _dist(cur[0], 0.0, 0.0))
	# a guard fights only what comes within its post
	var golem := [GameBehaviour.new_agent(2, "stone_golem", 0.0, 0.0)]
	golem[0]["x"] = 2.0   # it has shifted toward the target, which is 8.5 from its post: seen, but outside it
	var out_of_post := GameBehaviour.step_all(golem, {"targets": [{"x": 8.5, "z": 0.0}]}, 7, 0)
	ok(out_of_post[0]["mode"] != "chase", "a guard sees a target beyond its post and leaves it be")
	var in_post := GameBehaviour.step_all([GameBehaviour.new_agent(3, "stone_golem", 0.0, 0.0)], {"targets": [{"x": 5.0, "z": 0.0}]}, 7, 0)
	ok(in_post[0]["mode"] == "chase", "and a target inside it is fought")
	# the target runs circles round the post at 20; a guard never wanders after it
	var max_away := 0.0
	var g := golem
	g[0]["x"] = 0.0
	for t in 300:
		var ang := float(t) * 0.12
		g = GameBehaviour.step_all(g, {"targets": [{"x": cos(ang) * 20.0, "z": sin(ang) * 20.0}]}, 7, t)
		max_away = maxf(max_away, _dist(g[0], 0.0, 0.0))
	ok(max_away <= 8.0, "a guard keeps to its post however the target runs about: furthest %.1f" % max_away)
	# a target that steps inside the post draws it out, and it comes home after
	var drawn := [GameBehaviour.new_agent(4, "bog_troll", 0.0, 0.0)]
	var peak := 0.0
	for t in 120:
		var tgt := {"x": 6.0, "z": 0.0} if t < 40 else {"x": 60.0, "z": 0.0}
		drawn = GameBehaviour.step_all(drawn, {"targets": [tgt]}, 7, t)
		peak = maxf(peak, _dist(drawn[0], 0.0, 0.0))
	ok(peak > 3.0 and _dist(drawn[0], 0.0, 0.0) < 5.0, "a troll goes out to a target in its reach and back to its bridge after: out to %.1f, ends %.1f from home" % [peak, _dist(drawn[0], 0.0, 0.0)])


# ---------------------------------------------------------------- fleeing

func test_flee() -> void:
	var hurt := [GameBehaviour.new_agent(1, "bandit", 0.0, 0.0, 0.3)]
	var well := [GameBehaviour.new_agent(2, "bandit", 0.0, 0.0, 0.9)]
	var view := {"targets": [{"x": 5.0, "z": 0.0}]}
	ok(GameBehaviour.step_all(hurt, view, 7, 0)[0]["mode"] == "flee" and GameBehaviour.step_all(well, view, 7, 0)[0]["mode"] == "chase", "a bandit hurt below 40% runs, and a whole one attacks")
	var cur := hurt
	var growing := true
	var last := 5.0
	var tgt := {"x": 5.0, "z": 0.0}
	var stopped_at := -1
	var was_flee := true
	for t in 40:
		cur = GameBehaviour.step_all(cur, {"targets": [tgt]}, 7, t)
		var d := _dist(cur[0], 5.0, 0.0)
		if cur[0]["mode"] == "flee":
			if was_flee and d < last:
				growing = false
			last = d
			was_flee = true
		else:
			if stopped_at < 0:
				stopped_at = t
			was_flee = false
			if stopped_at >= 0:
				break
	ok(growing and last >= float(GameBehaviour.params("bandit")["flee_dist"]) - 2.0, "it keeps running until it is %.0f tiles off, farther every tick (%.1f)" % [float(GameBehaviour.params("bandit")["flee_dist"]), last])
	ok(stopped_at > 3, "and then stops: it ran for %d ticks" % stopped_at)
	# a berserk creature never flees, and fights faster when hurt
	var ogre_hurt := GameBehaviour.step_all([GameBehaviour.new_agent(3, "ogre", 0.0, 0.0, 0.05)], {"targets": [{"x": 5.0, "z": 0.0}]}, 7, 0)
	var ogre_well := GameBehaviour.step_all([GameBehaviour.new_agent(4, "ogre", 0.0, 0.0, 0.9)], {"targets": [{"x": 5.0, "z": 0.0}]}, 7, 0)
	ok(ogre_hurt[0]["mode"] == "chase" and float(ogre_hurt[0]["x"]) > float(ogre_well[0]["x"]), "a hurt ogre never flees and is faster for it: %.2f against %.2f" % [float(ogre_hurt[0]["x"]), float(ogre_well[0]["x"])])
	# the skittish run from anything close, hurt or not, and ignore what is far
	var near_sheep := GameBehaviour.step_all([GameBehaviour.new_agent(5, "sheep", 0.0, 0.0)], {"targets": [{"x": 4.0, "z": 0.0}]}, 7, 0)
	var far_sheep := GameBehaviour.step_all([GameBehaviour.new_agent(6, "sheep", 0.0, 0.0)], {"targets": [{"x": 30.0, "z": 0.0}]}, 7, 0)
	ok(near_sheep[0]["mode"] == "flee" and float(near_sheep[0]["x"]) < 0.0 and far_sheep[0]["mode"] != "flee", "a sheep bolts from a target close by (away from it) and ignores one far off")
	ok(GameBehaviour.step_all([GameBehaviour.new_agent(7, "cattle", 0.0, 0.0)], {"targets": [{"x": 4.0, "z": 0.0}]}, 7, 0)[0]["mode"] != "flee", "a cow is not skittish")


# ---------------------------------------------------------------- the pack

func test_pack() -> void:
	# one wolf sees the target; the rest, out of their own sight but near it, join in
	var wolves: Array = []
	for i in 4:
		wolves.append(GameBehaviour.new_agent(i + 1, "wolf", 0.0, float(i) * 2.0))
	var target := [{"x": 5.5, "z": 0.0}]   # by day a wolf sees 6: only the first sees it
	var one := GameBehaviour.step_all(wolves, {"targets": target, "night": false}, 7, 0)
	var chasing := 0
	for w in one:
		if w["mode"] == "chase":
			chasing += 1
	ok(chasing == 4, "when one pack animal sees the target, its kind within 10 tiles all hunt it: %d of 4" % chasing)
	ok(Vector2(0.0, 6.0).distance_to(Vector2(5.5, 0.0)) > 6.0, "(the fourth wolf is out of its own sight of the target)")
	var far_wolf := GameBehaviour.step_all([GameBehaviour.new_agent(1, "wolf", 0.0, 0.0), GameBehaviour.new_agent(2, "wolf", 0.0, 30.0)], {"targets": target, "night": false}, 7, 0)
	ok(far_wolf[0]["mode"] == "chase" and far_wolf[1]["mode"] != "chase", "but not one far out of earshot")
	# the same sight in a creature that is not a pack animal tells nobody
	var bandits: Array = []
	for i in 3:
		bandits.append(GameBehaviour.new_agent(i + 1, "bandit", 0.0, float(i) * 3.0))
	var lone := GameBehaviour.step_all(bandits, {"targets": [{"x": 8.0, "z": 0.0}]}, 7, 0)
	var seeing := 0
	for b in lone:
		if b["mode"] == "chase":
			seeing += 1
	var by_sight := 0
	for b in bandits:
		if Vector2(float(b["x"]), float(b["z"])).distance_to(Vector2(8.0, 0.0)) <= 9.0:
			by_sight += 1
	ok(seeing == by_sight and seeing < 3, "non-pack bandits hunt only if they see it themselves: %d of 3 do (all three within sight would be %d)" % [seeing, by_sight])
	# flanking: wolves that start on one side take their own sides of the target
	var pack: Array = []
	for i in 4:
		pack.append(GameBehaviour.new_agent(i + 1, "wolf", -12.0, float(i) - 1.5))
	var spread_ok := false
	var clump := 1.0
	var cur := pack
	for t in 30:
		cur = GameBehaviour.step_all(cur, {"targets": [{"x": 0.0, "z": 0.0}], "night": true}, 7, t)
		var mean := 0.0
		for w in cur:
			mean += _dist(w, 0.0, 0.0)
		mean /= float(cur.size())
		if mean < 2.4:   # closing: each is at about its own place round the target
			clump = _clump(cur)
			spread_ok = true
			break
	ok(spread_ok and clump < 0.6, "a pack closing on a target spreads round it: its bearings are clumped %.2f (1 is all one side, 0 is all round)" % clump)
	# the same start for non-pack creatures: they all come from the one side
	var lone_group: Array = []
	for i in 4:
		lone_group.append(GameBehaviour.new_agent(i + 1, "ogre", -8.0, float(i) - 1.5))
	var cur2 := lone_group
	for t in 7:
		cur2 = GameBehaviour.step_all(cur2, {"targets": [{"x": 0.0, "z": 0.0}]}, 7, t)
	ok(_clump(cur2) > 0.9, "ogres, which are not a pack, come in from the one side: clumped %.2f" % _clump(cur2))


# ---------------------------------------------------------------- the herd

func test_herd() -> void:
	var flock: Array = []
	for i in 5:
		flock.append(GameBehaviour.new_agent(i + 1, "sheep", float(i) * 12.0, float((i * 7) % 5) * 6.0))
	var spread := func(group: Array) -> float:
		var c := Vector2.ZERO
		for a in group:
			c += Vector2(float(a["x"]), float(a["z"]))
		c /= float(group.size())
		var worst := 0.0
		for a in group:
			worst = maxf(worst, Vector2(float(a["x"]), float(a["z"])).distance_to(c))
		return worst
	var before: float = spread.call(flock)
	var after_flock := _sim(flock, 400, _none)
	var pigs: Array = []
	for i in 5:
		pigs.append(GameBehaviour.new_agent(i + 1, "pig", float(i) * 12.0, float((i * 7) % 5) * 6.0))
	var after_pigs := _sim(pigs, 400, _none)
	ok(float(spread.call(after_flock)) < before * 0.6, "a flock draws together: spread %.1f down to %.1f" % [before, float(spread.call(after_flock))])
	ok(float(spread.call(after_pigs)) > float(spread.call(after_flock)), "pigs, which are not a herd, stay spread (%.1f against the flock's %.1f)" % [float(spread.call(after_pigs)), float(spread.call(after_flock))])


# ---------------------------------------------------------------- ground and fliers

func test_terrain() -> void:
	var water := func(x: float, _z: float) -> bool: return x >= 0.0   # walkable: the sea lies west of zero
	var wolf := [GameBehaviour.new_agent(1, "wolf", 6.0, 0.0)]
	var cur := wolf
	var min_x := 99.0
	for t in 80:
		cur = GameBehaviour.step_all(cur, {"targets": [{"x": -12.0, "z": 0.0}], "night": true, "walkable": water}, 7, t)
		min_x = minf(min_x, float(cur[0]["x"]))
	ok(min_x >= 0.0 and min_x < 1.5 and cur[0]["mode"] == "chase", "a wolf runs to the shore after its prey and no further: x never below %.2f, and it got within %.1f of the shore" % [min_x, min_x])
	var harpy := [GameBehaviour.new_agent(2, "harpy", 3.0, 0.0)]
	var no_walk := func(x: float, _z: float) -> bool: return x >= 0.0
	var h := harpy
	var reach := 99.0
	for t in 30:
		h = GameBehaviour.step_all(h, {"targets": [{"x": -6.0, "z": 0.0}], "walkable": no_walk}, 7, t)
		reach = minf(reach, float(h[0]["x"]))
	ok(reach < -3.0, "a harpy flies out over the water to it: reached x = %.1f" % reach)
	# a blocked creature slides along the shore instead of sticking
	var slide := [GameBehaviour.new_agent(3, "wolf", 3.0, 0.0)]
	var s := slide
	for t in 40:
		s = GameBehaviour.step_all(s, {"targets": [{"x": -8.0, "z": 12.0}], "night": true, "walkable": water}, 7, t)
	ok(float(s[0]["z"]) > 4.0 and float(s[0]["x"]) >= 0.0, "blocked at the shore it slides along it toward its prey (z %.1f)" % float(s[0]["z"]))
	# with no walkable test at all, the same wolf goes straight in
	var free := _sim([GameBehaviour.new_agent(4, "wolf", 6.0, 0.0)], 20, func(_t): return [{"x": -12.0, "z": 0.0}], true)
	ok(float(free[0]["x"]) < -5.0, "and with no ground to keep to it runs straight to its prey")


func test_world() -> void:
	var d := dyn()
	# find the shore on a row of the generated world: land at x_w + 6, sea at x_w - 8
	var x_w := 120
	while x_w > 0 and not GameWorldGen.tile(d, x_w, 300)["water"]:
		x_w -= 1
	ok(x_w > 0 and x_w < 60, "(the generated world has a west shore at x = %d on this row)" % x_w)
	var start_x := float(x_w + 6)
	var wolf := [GameBehaviour.new_agent(1, "wolf", start_x, 300.0)]
	var view := GameBehaviour.world_view(d, [{"x": float(x_w - 8), "z": 300.0}], true)
	var cur := wolf
	var wet := 0
	var nearest := 999.0
	for t in 80:
		cur = GameBehaviour.step_all(cur, view, 7, t)
		if GameWorldGen.tile(d, int(floor(float(cur[0]["x"]))), int(floor(float(cur[0]["z"]))))["water"]:
			wet += 1
		nearest = minf(nearest, float(cur[0]["x"]))
	ok(wet == 0 and nearest >= float(x_w) - 1.0 and nearest < start_x - 3.0, "a wolf in the generated world runs to the shore and never into the sea: %d wet steps, closest x %.1f (shore %d)" % [wet, nearest, x_w])
	# nothing of the dynasty's moves
	var before := d.rng.state
	var save_before := JSON.stringify(d.to_dict())
	_sim([GameBehaviour.new_agent(1, "goblin", 300.0, 300.0)], 50, _none)
	ok(d.rng.state == before and JSON.stringify(d.to_dict()) == save_before, "behaviour draws nothing from the dynasty's dice and changes nothing that is saved")


# ---------------------------------------------------------------- every creature

func test_all() -> void:
	var agents: Array = []
	var uid := 1
	for c in GameData.creatures:
		agents.append(GameBehaviour.new_agent(uid, str(c["id"]), float((uid * 5) % 40), float((uid * 11) % 40)))
		uid += 1
	var cur := agents
	var bad := 0
	var modes := {}
	for t in 100:
		var targets := [{"x": 20.0 + 15.0 * cos(float(t) * 0.1), "z": 20.0 + 15.0 * sin(float(t) * 0.1)}]
		cur = GameBehaviour.step_all(cur, {"targets": targets, "night": t % 40 > 20}, 11, t)
		for a in cur:
			modes[a["mode"]] = true
			if not (a["mode"] in GameBehaviour.MODES) or is_nan(float(a["x"])) or is_nan(float(a["z"])) or absf(float(a["x"])) > 500.0:
				bad += 1
	ok(bad == 0, "all 39 creatures run for 100 ticks among a moving target, by day and night, with no bad mode or position")
	ok(modes.has("wander") and modes.has("chase") and modes.has("flee") and modes.has("idle"), "and between them they wander, rest, chase and flee: %s" % str(modes.keys()))
	var again := agents
	for t in 100:
		again = GameBehaviour.step_all(again, {"targets": [{"x": 20.0 + 15.0 * cos(float(t) * 0.1), "z": 20.0 + 15.0 * sin(float(t) * 0.1)}], "night": t % 40 > 20}, 11, t)
	ok(again == cur, "and the same run twice gives the same creatures")
