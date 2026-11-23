## The rest of the reach rules (core/game/game_reach.gd, docs/REACH.md): shots, spreads, sight, pathing, shoves, pulls and blinks across
## walls, bars and slits, on a made-up map (a probe) and on Hearthmere's own wall. Pure: no dice, nothing saved.
## Run: godot --headless --path . -s res://tests/test_game_reach_rules.gd
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
	ok(GameReach.validate().is_empty(), "the reach data validates: %s" % str(GameReach.validate()))
	test_channels()
	test_shots()
	test_area()
	test_sight()
	test_ai()
	test_knock()
	test_world()
	print("reach rules tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## A wall column at x == 5 whose tile at z == `kind_z` is of `kind`; everything else in that column is solid wall.
func _col(kind: String, kind_z: int = 3) -> Callable:
	return func(x: int, z: int) -> String:
		if x != 5:
			return ""
		return kind if z == kind_z else "wall"


func _all(kind: String) -> Callable:
	return func(x: int, _z: int) -> String: return kind if x == 5 else ""


func test_channels() -> void:
	ok(GameReach.stops("wall", "ranged") and GameReach.stops("wall", "sight") and GameReach.stops("wall", "area"), "a wall stops every channel")
	ok(GameReach.stops("bars", "melee") and GameReach.stops("bars", "walk"), "bars stop a step and a blow")
	ok(not GameReach.stops("bars", "ranged") and not GameReach.stops("bars", "area") and not GameReach.stops("bars", "sight"), "bars let a shot, a spell and a look through")
	ok(GameReach.stops("slit", "melee") and GameReach.stops("slit", "area"), "a slit stops a blow and a spread")
	ok(not GameReach.stops("slit", "ranged") and not GameReach.stops("slit", "sight"), "a slit lets a shot and a look through")
	ok(not GameReach.stops("", "walk") and not GameReach.stops("nonsense", "walk"), "open ground and an unknown kind stop nothing")
	var a := Vector2(2.5, 3.5)
	var b := Vector2(8.5, 3.5)
	for kind in ["wall", "tower", "jamb", "building"]:
		ok(not GameReach.line_clear(a, b, "melee", false, _all(kind)), "%s stops a blow" % kind)
		ok(not GameReach.line_clear(a, b, "ranged", false, _all(kind)), "%s stops a shot" % kind)
	ok(not GameReach.line_clear(a, b, "melee", false, _all("bars")), "bars stop melee")
	ok(GameReach.line_clear(a, b, "ranged", false, _all("bars")), "but not a shot")
	ok(GameReach.line_clear(a, b, "ranged", false, _all("slit")), "a slit passes a shot")
	ok(not GameReach.line_clear(a, b, "melee", false, _all("slit")), "and stops a blow")
	ok(GameReach.line_clear(a, a, "ranged", false, _all("wall")), "a point reaches itself")
	ok(GameReach.line_clear(Vector2(5.5, 3.5), Vector2(8.5, 3.5), "ranged", false, _all("wall")), "the starting tile is never tested (a shooter in a gate)")


func test_shots() -> void:
	var a := Vector2(2.5, 3.5)
	var b := Vector2(8.5, 3.5)
	ok(GameReach.shot_ok(a, b, 8.0, false), "open ground: a shot in range goes")
	ok(not GameReach.shot_ok(a, b, 5.0, false), "out of range, no")
	ok(not GameReach.shot_ok(a, b, 8.0, false, false, _all("wall")), "a shot is stopped by a wall")
	ok(GameReach.shot_ok(a, b, 8.0, false, false, _col("slit", 3)), "a shot goes through a slit in a wall")
	ok(not GameReach.shot_ok(a, Vector2(8.5, 5.5), 8.0, false, false, _col("slit", 3)), "but not through the wall beside the slit")
	ok(GameReach.shot_ok(a, b, 8.0, false, false, _all("bars")), "a shot goes through bars (a portcullis)")
	# an arc clears a low stopper (bars, 2.0 high) from min range out, but never a wall (3.0 high)
	ok(GameReach.shot_ok(a, b, 8.0, false, true, _all("wall")) == false, "a lobbed shot does not clear a wall")
	var low := func(x: int, _z: int) -> String: return "bars" if x == 5 else ""
	ok(GameReach.stops("bars", "ranged") == false, "bars never stopped a straight shot")
	ok(GameReach.shot_ok(a, b, 8.0, false, true, low), "a lobbed shot over bars")
	# a diagonal wall: two solids meeting at a corner stop a shot between them
	var diag := func(x: int, z: int) -> String: return "wall" if (x == 0 and z == 0) or (x == 1 and z == 1) else ""
	ok(not GameReach.line_clear(Vector2(1.5, 0.5), Vector2(0.5, 1.5), "ranged", false, diag), "no shot squeezes between two walls that meet at a corner")
	ok(GameReach.line_clear(Vector2(1.5, 0.5), Vector2(2.5, 0.5), "ranged", false, diag), "beside them is clear")
	# thin: one tile thick
	ok(not GameReach.line_clear(Vector2(4.9, 3.0), Vector2(6.1, 3.0), "ranged", false, _all("wall")), "the thinnest wall stops a shot")
	# a chequer
	var chq := func(x: int, z: int) -> String: return "wall" if (x + z) % 2 == 0 and absi(x) <= 3 and absi(z) <= 3 else ""
	ok(not GameReach.line_clear(Vector2(-0.5, 0.5), Vector2(0.5, -0.5), "sight", false, chq), "a chequer of walls is no gap for a look")
	# a flier ends on open ground only
	ok(GameReach.can_end_on(4, 3, false, _all("wall")) and not GameReach.can_end_on(5, 3, false, _all("wall")), "a flier cannot end a move on a wall")
	ok(GameReach.can_end_on(5, 3, false, _all("bars")) == false, "nor in a grille")


func test_area() -> void:
	var o := Vector2(2.5, 3.5)
	var wall := func(x: int, _z: int) -> String: return "wall" if x == 5 else ""
	var pts: Array = [Vector2(3.5, 3.5), Vector2(4.5, 3.5), Vector2(6.5, 3.5), Vector2(7.5, 3.5), Vector2(2.5, 9.5)]
	var burst := {"shape": "burst", "radius": 6.0}
	var open := GameReach.area_hits(o, burst, Vector2.RIGHT, pts, false)
	ok(open.size() == 5, "open ground: a burst hits all within its radius (%d)" % open.size())
	var shadow := GameReach.area_hits(o, burst, Vector2.RIGHT, pts, false, wall)
	ok(shadow.size() == 3 and Vector2(6.5, 3.5) not in shadow, "a wall casts a shadow: the points behind it are not hit")
	var bars := func(x: int, _z: int) -> String: return "bars" if x == 5 else ""
	ok(GameReach.area_hits(o, burst, Vector2.RIGHT, pts, false, bars).size() == 5, "a spread passes bars")
	var slit := func(x: int, _z: int) -> String: return "slit" if x == 5 else ""
	ok(GameReach.area_hits(o, burst, Vector2.RIGHT, pts, false, slit).size() == 3, "but not a slit")
	var cone := {"shape": "cone", "angle": 60, "range": 12}
	var cp: Array = [Vector2(6.5, 3.5), Vector2(6.5, 9.5), Vector2(-3.5, 3.5)]
	var hit := GameReach.area_hits(o, cone, Vector2.RIGHT, cp, false)
	ok(hit == [Vector2(6.5, 3.5)], "a cone hits only inside its angle (%s)" % str(hit))
	ok(GameReach.area_hits(o, cone, Vector2.RIGHT, cp, false, wall).is_empty(), "and a wall clips it")
	var line := {"shape": "line", "range": 10}
	var lp: Array = [Vector2(4.5, 3.5), Vector2(8.5, 3.5), Vector2(8.5, 6.5), Vector2(0.5, 3.5)]
	ok(GameReach.area_hits(o, line, Vector2.RIGHT, lp, false).size() == 2, "a line hits along its ray")
	ok(GameReach.area_hits(o, line, Vector2.RIGHT, lp, false, wall) == [Vector2(4.5, 3.5)], "a line stops at the first stopper")
	ok(GameReach.area_hits(o, {"shape": "all"}, Vector2.RIGHT, cp, false, wall).size() == 3, "all and party are not clipped")
	ok(GameReach.area_hits(o, {"shape": "party"}, Vector2.RIGHT, cp, false, wall).size() == 3, "party neither")
	ok(not GameReach.aimable(o, Vector2(8.5, 3.5), false, wall), "a spell cannot be aimed across a wall")
	ok(GameReach.aimable(o, Vector2(8.5, 3.5), false, bars), "but can through bars")
	ok(GameReach.area_hits(o, burst, Vector2.RIGHT, [o], false, wall).size() == 1, "the origin itself is always hit")
	# a wall broken between ticks changes the shape on the next
	var broken := func(_x: int, _z: int) -> String: return ""
	ok(GameReach.area_hits(o, burst, Vector2.RIGHT, pts, false, broken).size() == 5, "a wall broken during the effect lets the next tick through")


func test_sight() -> void:
	var a := Vector2(2.5, 3.5)
	var b := Vector2(8.5, 3.5)
	ok(GameReach.sees(a, b, 7.0, false), "open ground: seen within sight")
	ok(not GameReach.sees(a, b, 5.0, false), "beyond sight, not")
	ok(not GameReach.sees(a, b, 7.0, false, _all("wall")), "a creature does not see through a solid wall")
	ok(GameReach.sees(a, b, 7.0, false, _all("bars")), "bars allow sight")
	ok(GameReach.sees(a, b, 7.0, false, _all("slit")), "a slit allows sight")
	ok(GameReach.sees(a, b, 7.0, false, _col("slit", 3)), "a look through a slit in a wall")
	ok(GameReach.keeps(a, b, 5.0, 1.5), "an existing target is kept by distance alone (5 x 1.5 reaches 6)")
	ok(not GameReach.keeps(a, b, 3.0, 1.5), "and dropped beyond it")
	ok(GameReach.keeps(a, b, 5.0, 1.5) and not GameReach.sees(a, b, 5.0, false, _all("wall")), "keeping needs no line: a chase round a corner is not dropped")


func test_ai() -> void:
	ok(not GameReach.loses_interest(true, 5.0, 100.0, 4.0), "a clear strike line never loses interest")
	ok(not GameReach.loses_interest(false, 5.0, 12.0, 4.0), "a short way round keeps the chase")
	ok(GameReach.loses_interest(false, 5.0, 40.0, 4.0), "a long way round gives it up")
	ok(GameReach.loses_interest(false, 5.0, -1.0, 4.0), "no way round gives it up")
	ok(GameReach.loses_interest(false, 0.2, 5.0, 4.0), "a very short straight distance is floored at one tile")
	ok(float(GameBehaviour.data()["defaults"]["chase_detour_mult"]) > 1.0, "behaviour.json has chase_detour_mult")
	var wall := func(x: int, z: int) -> String: return "wall" if x == 5 and z <= 8 else ""
	var f := GameReach.flank_point(Vector2(5.5, 3.5), false, wall)
	ok(not GameReach.tile_stops(floori(f.x), floori(f.y), "walk", false, wall), "a flank point inside a wall is moved onto open ground")
	ok(f.distance_to(Vector2(5.5, 3.5)) <= 1.5, "to the nearest tile")
	ok(GameReach.flank_point(Vector2(2.5, 3.5), false, wall) == Vector2(2.5, 3.5), "and one on open ground stays")


func test_knock() -> void:
	var wall := func(x: int, _z: int) -> String: return "wall" if x == 5 else ""
	var r := GameReach.knock(Vector2(2.5, 3.5), Vector2.RIGHT, 6.0, false, wall)
	ok(bool(r["blocked"]) and r["pos"].x < 5.0 and r["pos"].x >= 4.4, "a shove stops at the wall face (%s)" % str(r))
	ok(floori(r["pos"].x) == 4, "and never ends inside or beyond the wall")
	var free := GameReach.knock(Vector2(2.5, 3.5), Vector2.RIGHT, 1.0, false, wall)
	ok(not bool(free["blocked"]) and is_equal_approx(float(free["moved"]), 1.0), "a short shove moves the whole way")
	ok(GameReach.knock(Vector2(2.5, 3.5), Vector2.ZERO, 3.0, false, wall)["moved"] == 0.0, "no direction, no move")
	ok(GameReach.knock(Vector2(2.5, 3.5), Vector2.LEFT, 3.0, false, wall)["pos"].x == -0.5, "away from the wall is free")
	var bars := func(x: int, _z: int) -> String: return "bars" if x == 5 else ""
	ok(bool(GameReach.knock(Vector2(2.5, 3.5), Vector2.RIGHT, 6.0, false, bars)["blocked"]), "bars stop a shoved body (it walks no further than a walker)")
	var diag := func(x: int, z: int) -> String: return "wall" if (x == 0 and z == 0) or (x == 1 and z == 1) else ""
	ok(bool(GameReach.knock(Vector2(1.45, 0.55), Vector2(-1, 1), 2.0, false, diag)["blocked"]), "a shove does not squeeze between two walls at a corner")
	var p := GameReach.pull(Vector2(8.5, 3.5), Vector2(1.5, 3.5), 10.0, false)
	ok(is_equal_approx(p["pos"].x, 2.5), "a pull ends a gap short of the caster (%s)" % str(p))
	var pw := GameReach.pull(Vector2(8.5, 3.5), Vector2(1.5, 3.5), 10.0, false, wall)
	ok(bool(pw["blocked"]) and floori(pw["pos"].x) == 6, "a pull ends in front of the wall")
	ok(GameReach.pull(Vector2(2.0, 3.5), Vector2(1.5, 3.5), 5.0, false)["moved"] == 0.0, "a pull on someone already at the caster's side moves nothing")
	ok(GameReach.blink_ok(Vector2(2.5, 3.5), Vector2(4.5, 3.5), 5.0, false, wall), "a blink in the open")
	ok(not GameReach.blink_ok(Vector2(2.5, 3.5), Vector2(8.5, 3.5), 9.0, false, wall), "a blink needs a clear line: not through a wall")
	ok(not GameReach.blink_ok(Vector2(2.5, 3.5), Vector2(5.5, 3.5), 9.0, false, wall), "nor onto a wall")
	ok(not GameReach.blink_ok(Vector2(2.5, 3.5), Vector2(8.5, 3.5), 5.0, false), "nor beyond its range")
	ok(GameReach.can_end_on(8, 3, false, wall), "a teleport needs only a tile to stand on (no line)")


func test_world() -> void:
	# on Hearthmere's own wall the melee channel agrees with GameWalls.line_clear everywhere we sample
	var a := GameWorldGen.anchor("hearthmere")
	var ax := float(a["x"])
	var az := float(a["z"])
	var same := true
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 60:
		var p := Vector2(ax + rng.randf_range(-40.0, 40.0), az + rng.randf_range(-40.0, 40.0))
		var q := p + Vector2(rng.randf_range(-9.0, 9.0), rng.randf_range(-9.0, 9.0))
		for shut in [false, true]:
			if GameReach.line_clear(p, q, "melee", shut) != GameWalls.line_clear(p, q, shut):
				same = false
	ok(same, "the melee channel is exactly GameWalls.line_clear on the world's tiles")
	var g: Dictionary = GameWalls.gates("hearthmere")[0]
	var inner: Vector2i = g["inner"]
	var outer: Vector2i = g["outer"]
	var pa := Vector2(float(inner.x) + 0.5, float(inner.y) + 0.5)
	var pb := Vector2(float(outer.x) + 0.5, float(outer.y) + 0.5)
	ok(GameReach.line_clear(pa, pb, "melee", false) and GameReach.line_clear(pa, pb, "ranged", false), "an open gate lets a blow and a shot through")
	ok(not GameReach.line_clear(pa, pb, "melee", true), "a shut gate stops a blow")
	ok(GameReach.line_clear(pa, pb, "ranged", true) and GameReach.sees(pa, pb, 20.0, true), "but not a shot or a look: it is a portcullis")
	# a wall tile away from the gates stops every channel
	var w := _north_wall()
	var x := float(w["x"]) + 0.5
	var out := Vector2(x, float(w["first"]) - 0.5)
	var inn := Vector2(x, float(w["last"]) + 1.5)
	for ch in ["melee", "ranged", "area", "sight"]:
		ok(not GameReach.line_clear(out, inn, ch, false), "Hearthmere's wall stops %s" % ch)
	ok(not GameReach.sees(out, inn, 20.0, false), "a creature outside the wall does not see the heir inside")
	ok(not GameReach.shot_ok(out, inn, 20.0, false), "nor shoot them")


func _north_wall() -> Dictionary:
	var a := GameWorldGen.anchor("hearthmere")
	var x := int(a["x"]) + 12
	var first := -1
	var last := -1
	for z in range(int(a["z"]) - 45, int(a["z"])):
		if GameWalls.kind_at(x, z) == "wall":
			if first < 0:
				first = z
			last = z
	return {"x": x, "first": first, "last": last}
