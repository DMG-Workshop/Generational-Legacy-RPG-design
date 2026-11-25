## Creature levels in the open world: the bands and their weights, a level that is a pure function of the seed, the tile and the
## heir's level, the con scale, a fight begun by contact building its foes at those levels with their xp on the scale of the gap,
## and hunts and every other fight left exactly as they were. Also the thinner crowd, none in a town, and the breather after a fight.
## Run: godot --headless --path . -s res://tests/test_game_levels.gd
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
	test_ratio()
	test_con()
	test_spawn_levels()
	test_fight_levels()
	test_xp_scale()
	test_hunts_unchanged()
	test_crowd()
	print("level tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _game(seed_value: int = 11, level: int = 20) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.level = level
	return d


func _wild_id() -> String:
	return str(GameSpawn.wild()[0]["id"])


func test_data() -> void:
	ok(GameLevels.validate().is_empty(), "the level data is valid: %s" % str(GameLevels.validate()))
	ok(GameSandbox.validate().is_empty(), "the sandbox settings are valid: %s" % str(GameSandbox.validate()))
	var ids: Array = GameLevels.bands().map(func(b): return str(b["id"]))
	ok(ids == ["trivial", "easy", "even", "hard", "deadly"], "five bands, weakest first")
	ok(float(GameSandbox.setting("spawn_share")) <= 0.05 and int(GameSandbox.setting("max_creatures")) <= 7 and int(GameSandbox.setting("spawn_burst")) == 1, "the crowd is thinner")
	var old := GameLevels.bands().duplicate(true)
	var bad_data: Dictionary = GameSandbox.data()["levels"]
	bad_data["bands"][2]["mark"] = ""
	ok(not GameLevels.validate().is_empty(), "a band without its mark is refused")
	bad_data["bands"] = old


func test_ratio() -> void:
	var counts := {}
	var sum := 0.0
	var n := 4000
	for i in n:
		var r := GameLevels.ratio_at(5, i % 80, i / 80)
		if i < 20:
			ok(r == GameLevels.ratio_at(5, i % 80, i / 80), "the ratio of a tile is the same every time")
		sum += r
		var band := GameLevels.con(int(round(r * 1000.0)), 1000)
		counts[band] = int(counts.get(band, 0)) + 1
	var mean := sum / float(n)
	ok(mean > 0.85 and mean < 1.1, "most are near the heir's level: the mean ratio is %.2f" % mean)
	ok(int(counts.get("even", 0)) > int(counts.get("deadly", 0)) * 2, "far more even creatures than deadly ones: %s" % str(counts))
	ok(int(counts.get("trivial", 0)) > 0 and int(counts.get("easy", 0)) > 0 and int(counts.get("hard", 0)) > 0 and int(counts.get("deadly", 0)) > 0, "every band turns up: %s" % str(counts))
	var differs := false
	for i in 40:
		if GameLevels.ratio_at(5, i, 3) != GameLevels.ratio_at(6, i, 3):
			differs = true
	ok(differs, "another seed gives other levels")
	ok(GameLevels.level_at(5, 3, 4, 1, 1.0) >= 1 and GameLevels.level_at(5, 3, 4, 0, 0.1) >= 1, "a level is never below 1")
	var lv := GameLevels.level_at(5, 3, 4, 20, 1.0)
	ok(lv == maxi(1, int(round(20.0 * GameLevels.ratio_at(5, 3, 4)))), "level = round(heir level * ratio * danger)")
	ok(GameLevels.level_at(5, 3, 4, 20, 1.2) >= lv, "a more dangerous place raises it")
	var rolled := RandomNumberGenerator.new()
	rolled.seed = 99
	var before := rolled.randi()
	rolled.seed = 99
	GameLevels.ratio_at(5, 1, 1)
	ok(rolled.randi() == before, "no dice but its own are used")


func test_con() -> void:
	ok(GameLevels.con(5, 20) == "trivial", "a quarter of the heir's level is trivial")
	ok(GameLevels.con(14, 20) == "easy", "0.7 is easy")
	ok(GameLevels.con(20, 20) == "even", "equal is even")
	ok(GameLevels.con(26, 20) == "hard", "1.3 is hard")
	ok(GameLevels.con(40, 20) == "deadly", "double is deadly")
	ok(GameLevels.con(1, 1) == "even" and GameLevels.con(3, 1) == "deadly", "level 1 heirs are measured too")
	ok(GameLevels.con(5, 0) != "", "a zero level does not divide by zero")
	var s := GameSandbox.start(_game())
	ok(s.con(5) == "trivial" and s.con(40) == "deadly", "GameSandbox.con reads the heir's level")
	ok(GameLevels.con_xp("trivial") < GameLevels.con_xp("easy") and GameLevels.con_xp("easy") < GameLevels.con_xp("even") and GameLevels.con_xp("even") < GameLevels.con_xp("hard") and GameLevels.con_xp("hard") < GameLevels.con_xp("deadly"), "xp rises with the band")
	ok(GameLevels.con_xp("even") == 1.0, "an even foe pays its xp as it was")
	ok(GameLevels.con_gold("trivial") < GameLevels.con_gold("easy") and GameLevels.con_gold("easy") < GameLevels.con_gold("even") and GameLevels.con_gold("even") < GameLevels.con_gold("hard") and GameLevels.con_gold("hard") < GameLevels.con_gold("deadly"), "gold rises with the band")
	ok(GameLevels.con_gold("even") == 1.0, "an even foe carries its gold as it was")
	var dull := {"level": 5, "xp": 10, "gold": 20}
	GameLevels.dress(dull, 20)
	ok(dull["con"] == "trivial" and int(dull["gold"]) == 5, "a trivial foe carries a quarter of its gold: %s" % str(dull["gold"]))
	var rich := {"level": 40, "xp": 10, "gold": 20}
	GameLevels.dress(rich, 20)
	ok(rich["con"] == "deadly" and int(rich["gold"]) == 40, "a deadly foe carries double: %s" % str(rich["gold"]))
	var none := {"level": 20, "xp": 10, "gold": 0}
	GameLevels.dress(none, 20)
	ok(int(none["gold"]) == 0, "a foe with no gold still has none")
	ok(GameLevels.fearful_band("trivial") and GameLevels.fearful_band("easy") and not GameLevels.fearful_band("even") and not GameLevels.fearful_band("deadly"), "only the weak are fearful")


## A sandbox with the heir moved to a spot where the ground holds creatures, refreshed until the crowd is as big as it will get.
func _crowded(d: GameDynasty) -> GameSandbox:
	var s := GameSandbox.start(d)
	var a := GameWorldGen.anchor(str(d.world.location))
	var best: GameSandbox = null
	for i in 40:
		var t := Vector2i(int(a["x"]) + 60 + i * 9, int(a["z"]) + 40 + i * 5)
		if not GameWorldGen.in_bounds(t.x, t.y):
			continue
		var c := GameSandbox.start(d)
		c.creatures.clear()
		c.heir = t
		for k in 12:
			c.refresh()
		if best == null or c.creatures.size() > best.creatures.size():
			best = c
		if best.creatures.size() >= 3:
			break
	return best if best != null else s


func test_spawn_levels() -> void:
	var s := _crowded(_game())
	ok(s.creatures.size() > 0, "the open world has creatures to look at")
	for a in s.creatures:
		var lv := GameSandbox.level_of(a)
		ok(lv >= 1 and lv == GameLevels.level_for(s.d, int(floor(float(a["home_x"]))), int(floor(float(a["home_z"])))), "a creature's level is its tile's: %d" % lv)
	var s2 := GameSandbox.start(_game())
	s2.creatures.clear()
	s2.heir = s.heir
	for k in 12:
		s2.refresh()
	var same := s.creatures.size() == s2.creatures.size()
	for i in mini(s.creatures.size(), s2.creatures.size()):
		same = same and GameSandbox.level_of(s.creatures[i]) == GameSandbox.level_of(s2.creatures[i]) and str(s.creatures[i]["id"]) == str(s2.creatures[i]["id"])
	ok(same, "the same seed and tile give the same creature at the same level")
	var d_low := _game(11, 2)
	var d_high := _game(11, 60)
	var any_diff := false
	for i in 30:
		if GameLevels.level_for(d_high, 100 + i, 50) > GameLevels.level_for(d_low, 100 + i, 50):
			any_diff = true
	ok(any_diff, "a higher heir meets higher creatures")
	for a in s.creatures:
		ok(GameSandbox.level_of(a) == int(a["level"]), "the level is kept on the agent")
	var n0 := s.creatures.size()
	s.step(4)
	ok(s.creatures.size() == n0 or s.creatures.size() == n0 + 1 or s.d.battle != null, "stepping keeps the crowd")
	for a in s.creatures:
		ok(a.has("level"), "the agents the step returns keep their level")
	# dungeon denizens and hand-made agents have none, and keep the old fights
	ok(GameSandbox.level_of(GameBehaviour.new_agent(1, _wild_id(), 1.0, 1.0)) == 0, "an agent made elsewhere has no level of its own")


func test_fight_levels() -> void:
	var d := _game(11, 20)
	d.heir.hp = d.heir.max_hp()
	var fight := d.start_encounter([_wild_id(), _wild_id()], "", 1.0, [5, 28])
	ok(fight != null and fight.enemies.size() == 2, "a fight of two")
	ok(int(fight.enemies[0]["level"]) == 5 and int(fight.enemies[1]["level"]) == 28, "each foe is built at its own level")
	ok(str(fight.enemies[0]["con"]) == "trivial" and str(fight.enemies[1]["con"]) == "hard", "and knows its band: %s, %s" % [fight.enemies[0]["con"], fight.enemies[1]["con"]])
	ok(bool(fight.enemies[0].get("fearful", false)) and not fight.enemies[1].has("fearful"), "only the weak one is fearful")
	# through the sandbox's contact
	var s := GameSandbox.start(_game(11, 20))
	s.creatures.clear()
	var p := s.heir_point()
	var a := GameBehaviour.new_agent(900, _wild_id(), p.x + 1.0, p.y)
	a["mode"] = "chase"
	a["level"] = 4
	s.creatures.append(a)
	ok(s._contact() and s.d.battle != null, "contact starts the fight")
	ok(int(s.d.battle.enemies[0]["level"]) == 4 and str(s.d.battle.enemies[0]["con"]) == "trivial", "at the creature's own level")
	# a creature without a level fights by the hunt's old rules
	var s2 := GameSandbox.start(_game(11, 20))
	s2.creatures.clear()
	var b := GameBehaviour.new_agent(901, _wild_id(), s2.heir_point().x + 1.0, s2.heir_point().y)
	b["mode"] = "chase"
	s2.creatures.append(b)
	s2._contact()
	ok(not s2.d.battle.enemies[0].has("con") and not s2.d.battle.enemies[0].has("fearful"), "a creature with no level of its own fights as ever")
	# name_at carries the level
	var s3 := GameSandbox.start(_game(11, 20))
	s3.creatures.clear()
	var c := GameBehaviour.new_agent(902, _wild_id(), s3.heir_point().x + 0.6, s3.heir_point().y)
	c["level"] = 40
	s3.creatures.append(c)
	var named := s3.name_at(s3.heir_point().x + 0.6, s3.heir_point().y)
	ok(str(named.get("kind", "")) == "creature" and int(named.get("level", 0)) == 40 and str(named.get("con", "")) == "deadly", "a click names the creature with its level and band: %s" % str(named))


func test_xp_scale() -> void:
	var id := _wild_id()
	var base := _game(11, 20)
	var plain := base.start_encounter([id], "", 1.0, [20])
	var by_level := int(plain.enemies[0]["xp"])
	ok(str(plain.enemies[0]["con"]) == "even", "an equal foe is even")
	var raw := _game(11, 20)
	var hunted := raw.foe_for(id, 20)
	ok(by_level == int(hunted["xp"]), "an even foe pays exactly what the hunt's foe of that level pays")
	var xps := {}
	for lv in [4, 14, 20, 26, 40]:
		var d := _game(11, 20)
		var f := d.start_encounter([id], "", 1.0, [lv])
		xps[str(f.enemies[0]["con"])] = int(f.enemies[0]["xp"])
		var want := maxi(1, int(round(float(d.foe_for(id, lv)["xp"]) * GameLevels.con_xp(str(f.enemies[0]["con"])))))
		ok(int(f.enemies[0]["xp"]) == want, "level %d (%s) pays the hunt's xp times its band's share" % [lv, f.enemies[0]["con"]])
	ok(int(xps["trivial"]) < int(xps["easy"]) and int(xps["easy"]) < int(xps["even"]) and int(xps["even"]) < int(xps["hard"]), "xp climbs with the gap: %s" % str(xps))
	# winning pays it and writes the line
	var d := _game(11, 20)
	var f := d.start_encounter([id], "", 1.0, [14])
	var want_xp := int(f.enemies[0]["xp"])
	f.enemies[0]["hp"] = 0
	f.result = "victory"
	var xp0 := d.heir.xp
	var lv0 := d.heir.level
	d.finish_battle()
	ok(d.heir.xp != xp0 or d.heir.level != lv0, "the win paid xp")
	ok(d.last_xp_line.contains("XP") and d.last_xp_line.contains(str(want_xp)) and d.last_xp_line.contains("easy"), "and left a line with the xp and the band: %s" % d.last_xp_line)
	# the sandbox puts that line in the journal and takes a breather
	var s := GameSandbox.start(_game(11, 20))
	s.creatures.clear()
	var fb := s.d.start_encounter([id], "", 1.0, [14])
	fb.enemies[0]["hp"] = 0
	fb.result = "victory"
	s.d.finish_battle()
	s.d.world_seconds = 100.0
	s.after_fight()
	ok(str(s.log[-1]["text"]).contains("XP") and s.d.last_xp_line == "", "the journal gets the +N XP line once")
	ok(s.rest_until > s.d.world_seconds, "the fight's end starts a breather")


func test_hunts_unchanged() -> void:
	var a := _game(23, 20)
	var b := _game(23, 20)
	var fa := a.start_hunt("hunt")
	var fb := b.start_hunt("hunt")
	ok(fa != null and var_to_str(fa.enemies) == var_to_str(fb.enemies), "a hunt is the same hunt")
	for e in fa.enemies:
		ok(not e.has("con") and not e.has("fearful") and not e.has("fled"), "a hunt's foes have no band and no fear")
	var c := _game(23, 20)
	var e1 := c.start_encounter([_wild_id()])
	var d2 := _game(23, 20)
	var e2 := d2.start_encounter([_wild_id()], "", 1.0, [])
	ok(var_to_str(e1.enemies) == var_to_str(e2.enemies) and not e1.enemies[0].has("con"), "an encounter with no levels given is as before")


func test_crowd() -> void:
	# nothing spawns inside a town
	var town := ""
	for place in GameWalls.walled():
		town = str(place)
		break
	ok(town != "", "there is a walled town")
	var a := GameWorldGen.anchor(town)
	ok(GameSandbox.in_town(int(a["x"]), int(a["z"])), "a town's middle is in town")
	ok(GameSandbox.in_town(int(a["x"]) + int(GameWalls.radius(town)), int(a["z"])), "so is its wall ring")
	ok(not GameSandbox.in_town(int(a["x"]) + int(GameWalls.radius(town)) + 40, int(a["z"]) + 40), "and the country is not")
	var d := _game()
	var s := GameSandbox.start(d)
	s.creatures.clear()
	s.heir = Vector2i(int(a["x"]), int(a["z"]))
	for k in 30:
		s.refresh()
	var inside := 0
	for c in s.creatures:
		if GameSandbox.in_town(int(floor(float(c["x"]))), int(floor(float(c["z"])))):
			inside += 1
	ok(inside == 0, "no creature spawns inside the town: %d of %d" % [inside, s.creatures.size()])
	# the breather
	var c := _crowded(_game())
	ok(c.creatures.size() > 0, "a crowd to start with")
	var edge := c.creatures.size()
	c.creatures.clear()
	c.d.world_seconds = 500.0
	c.rest_until = 500.0 + float(GameSandbox.setting("spawn_rest_seconds"))
	for k in 12:
		c.refresh()
	ok(c.creatures.is_empty(), "nothing spawns during the breather (%d would have)" % edge)
	c.d.world_seconds = c.rest_until + 1.0
	for k in 12:
		c.refresh()
	ok(c.creatures.size() > 0, "and the crowd comes back after it")
	ok(c.creatures.size() <= int(GameSandbox.setting("max_creatures")), "never above the cap")
	# one at a time
	var one := _crowded(_game())
	one.creatures.clear()
	one.refresh()
	ok(one.creatures.size() <= int(GameSandbox.setting("spawn_burst")), "one at a refresh")
