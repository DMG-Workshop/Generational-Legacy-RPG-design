## The step cache for many movers (roadmap item 49): a cached router gives exactly the answers the plain one does, finds each
## (from, to) once while the ground holds and reuses it after (so a crowd heading for one goal pays for one search a tile), is
## cleared when the ground changes (built, taken down, damaged, dug) and held to `cache_max` entries; the sandbox keeps one for its
## companions and its readout says what it holds.
## Run: godot --headless --path . -s res://tests/test_game_path_cache.gd
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
	test_same_answers()
	test_reuse()
	test_invalidation()
	test_bound()
	test_sandbox()
	print("path cache tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh() -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


func test_data() -> void:
	ok(GamePath.validate().is_empty(), "the shipped data passes: %s" % str(GamePath.validate()))
	var s: Dictionary = GamePath.data()["settings"]
	var keep: Variant = s["cache_max"]
	s["cache_max"] = 0
	ok(not GamePath.validate().is_empty(), "a cache of no entries is caught")
	s["cache_max"] = keep
	var t: Variant = GamePath.data()["text"]["cache_line"]
	GamePath.data()["text"].erase("cache_line")
	ok(not GamePath.validate().is_empty(), "missing readout text is caught")
	GamePath.data()["text"]["cache_line"] = t
	ok(GamePath.validate().is_empty(), "and mending the data clears it")


func test_same_answers() -> void:
	var d := _fresh()
	var b := GameBuild.base()
	var ground := GamePath.world_ground(d)
	var cache := GamePath.new_cache()
	var plain := GamePath.router(ground)
	var cached := GamePath.cached_router(ground, cache)
	var same := true
	var n := 0
	for i in 12:
		var from := Vector2(float(b["x"]) + float(i), float(b["z"]) - 3.0)
		var to := Vector2(float(b["x"]) + 9.0, float(b["z"]) + 7.0)
		if plain.call(from, to) != cached.call(from, to):
			same = false
		n += 1
	ok(same and n == 12, "twelve routes: the cached router answers as the plain one does")
	ok(int(cache["misses"]) == 12 and int(cache["hits"]) == 0, "each was found once: %d found" % int(cache["misses"]))


func test_reuse() -> void:
	var d := _fresh()
	var b := GameBuild.base()
	var ground := GamePath.world_ground(d)
	var cache := GamePath.new_cache()
	var cached := GamePath.cached_router(ground, cache)
	var from := Vector2(float(b["x"]) + 0.5, float(b["z"]) + 0.5)
	var to := Vector2(float(b["x"]) + 8.5, float(b["z"]) + 8.5)
	var first: Vector2 = cached.call(from, to)
	for i in 50:
		cached.call(from, to)
	ok(int(cache["misses"]) == 1 and int(cache["hits"]) == 50, "fifty more of the same trip are reused: %d found, %d reused" % [int(cache["misses"]), int(cache["hits"])])
	ok(cached.call(from, to) == first, "with the same answer")
	# a different mover is its own entry
	var flier := GamePath.cached_router(ground, cache, "flier")
	flier.call(from, to)
	ok(int(cache["misses"]) == 2, "a flier's step is kept apart from a walker's")
	ok(cache["steps"].size() == 2, "two entries kept")
	ok(GamePath.cache_line(cache).contains("2 steps kept") and GamePath.cache_line(cache).contains("51 reused"), "the readout says so: %s" % GamePath.cache_line(cache))


func test_invalidation() -> void:
	var d := _fresh()
	var b := GameBuild.base()
	var cache := GamePath.new_cache()
	GamePath.sync(cache, d)
	var cached := GamePath.cached_router(GamePath.world_ground(d), cache)
	cached.call(Vector2(float(b["x"]) + 0.5, float(b["z"]) + 0.5), Vector2(float(b["x"]) + 6.5, float(b["z"]) + 0.5))
	ok(cache["steps"].size() == 1, "(one step kept)")
	GamePath.sync(cache, d)
	ok(cache["steps"].size() == 1, "syncing with the ground unchanged keeps it")
	d.built[GameBuild.key(int(b["x"]) + 3, GameBuild.SURFACE, int(b["z"]))] = "wall"
	GamePath.sync(cache, d)
	ok(cache["steps"].is_empty(), "building clears it")
	cached.call(Vector2(float(b["x"]) + 0.5, float(b["z"]) + 0.5), Vector2(float(b["x"]) + 6.5, float(b["z"]) + 0.5))
	d.damage[GameBuild.key(int(b["x"]) + 3, GameBuild.SURFACE, int(b["z"]))] = 1
	d.built.erase(GameBuild.key(int(b["x"]) + 3, GameBuild.SURFACE, int(b["z"])))
	GamePath.sync(cache, d)
	ok(cache["steps"].is_empty(), "taking it down clears it")
	cached.call(Vector2(float(b["x"]) + 0.5, float(b["z"]) + 0.5), Vector2(float(b["x"]) + 6.5, float(b["z"]) + 0.5))
	GameMine.dig(d, GameWorldGen.MINE_SITE, int(b["x"]), 0, int(b["z"]))
	GamePath.sync(cache, d)
	ok(cache["steps"].is_empty(), "digging clears it")
	ok(int(cache["clears"]) == 4, "and the readout counts the clearings: %d" % int(cache["clears"]))
	# a wall in the way changes the answer, which the cache then gives
	var d2 := _fresh()
	var c2 := GamePath.new_cache()
	var from := Vector2(float(b["x"]) + 0.5, float(b["z"]) + 0.5)
	var to := Vector2(float(b["x"]) + 4.5, float(b["z"]) + 0.5)
	GamePath.sync(c2, d2)
	var before: Vector2 = GamePath.cached_router(GamePath.world_ground(d2), c2).call(from, to)
	for dz in range(-6, 7):
		d2.built[GameBuild.key(int(b["x"]) + 2, GameBuild.SURFACE, int(b["z"]) + dz)] = "wall"
	GamePath.sync(c2, d2)
	var after: Vector2 = GamePath.cached_router(GamePath.world_ground(d2), c2).call(from, to)
	var plain: Vector2 = GamePath.router(GamePath.world_ground(d2)).call(from, to)
	ok(after == plain, "after a wall goes up the cache gives the new answer, not the old (%s then %s)" % [str(before), str(after)])


func test_bound() -> void:
	var d := _fresh()
	var b := GameBuild.base()
	var cache := GamePath.new_cache()
	var cached := GamePath.cached_router(GamePath.world_ground(d), cache)
	var cap := int(GamePath.setting("cache_max"))
	GamePath.data()["settings"]["cache_max"] = 5
	for i in 12:
		cached.call(Vector2(float(b["x"]) + float(i) + 0.5, float(b["z"]) + 0.5), Vector2(float(b["x"]) + 14.5, float(b["z"]) + 3.5))
	ok(cache["steps"].size() <= 5, "the cache is held to cache_max: %d" % cache["steps"].size())
	GamePath.data()["settings"]["cache_max"] = cap


func test_sandbox() -> void:
	var d := _fresh()
	var s := GameSandbox.start(d)
	ok(s.path_line().contains("0 steps kept"), "a new sandbox's cache is empty: %s" % s.path_line())
	s.creatures.clear()
	for i in 5:
		s.step(1)
	ok(int(s.path_cache["stamp"]) != 0, "stepping the sandbox syncs the cache with the ground")
