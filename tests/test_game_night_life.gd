## Night and day in the open world (data/world/night_life.json, GameNightLife): creatures met only by night (and none by day), night adds,
## glowcaps that can be gathered only while it is night, the day's market stall with its trader, and the status line. Nothing here may
## move the text game: the hunt's pool is the same, the multipliers are neutral without the context, and every choice is keyed
## on the seed and the tile.
## Run: godot --headless --path . -s res://tests/test_game_night_life.gd
extends SceneTree

const NIGHT := 105.0    # world seconds: midnight (start_phase 0.3 + 105/150 = 1.0)
const NOON := 30.0      # phase 0.5

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
	test_neutral()
	test_tables()
	test_glowcaps()
	test_stalls()
	test_notes()
	print("night life tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh(seed_value: int = 7) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "ranger", "faetouched", "human")
	d.pending_event = {}
	return d


func _ctx(surface: String, era: int, night: bool) -> Dictionary:
	var c := GameSpawn.context(surface, -1, era, "", "", night)
	c["zone"] = "surface"
	return c


func _ids(rows: Array) -> Array:
	return rows.map(func(r): return str(r["id"]))


func test_data() -> void:
	ok(GameNightLife.validate().is_empty(), "the shipped data passes: %s" % str(GameNightLife.validate()))
	var dat := GameNightLife.data()
	dat["day_only_off"].append("nonesuch")
	ok(not GameNightLife.validate().is_empty(), "a day-only creature that does not exist is caught")
	dat["day_only_off"].pop_back()
	dat["day_only_off"].append("moss_stag")
	ok(not GameNightLife.validate().is_empty(), "a creature the night does not favour cannot be night-only")
	dat["day_only_off"].pop_back()
	dat["night_adds"]["plains"]["slime_king"] = 1.0
	ok(not GameNightLife.validate().is_empty(), "a night-add that is no creature is caught")
	dat["night_adds"]["plains"].erase("slime_king")
	dat["night_adds"]["swamp"] = {"skeleton": 1.0}
	ok(not GameNightLife.validate().is_empty(), "a night-add on a surface none of its biomes has is caught")
	dat["night_adds"].erase("swamp")
	var mat: Variant = dat["glow"]["material"]
	dat["glow"]["material"] = "unobtainium"
	ok(not GameNightLife.validate().is_empty(), "a glowcap of an unknown material is caught")
	dat["glow"]["material"] = mat
	var close: Variant = dat["settings"]["stall_close"]
	dat["settings"]["stall_close"] = 3.0
	ok(not GameNightLife.validate().is_empty(), "a stall that closes before it opens is caught")
	dat["settings"]["stall_close"] = close
	ok(GameNightLife.validate().is_empty(), "and mending the data clears it")


func test_neutral() -> void:
	# without the context (no surface zone, nothing said of the night) every weight is exactly what it was
	for id in ["ghoul", "thornhound", "wolf", "skeleton", "wraith", "bandit"]:
		ok(GameNightLife.adjust_weight(id, {}, 1.37) == 1.37, "%s: no context, no change" % id)
		ok(GameNightLife.adjust_weight(id, {"zone": "underground", "night": false}, 1.37) == 1.37, "%s: underground, no change" % id)
		ok(GameNightLife.adjust_weight(id, {"zone": "place", "night": true}, 1.37) == 1.37, "%s: a dungeon's mouth, no change" % id)
	ok(GameNightLife.adds({}).is_empty() and GameNightLife.adds(_ctx("plains", 100, false)).is_empty(), "no night-adds by day or without a context")
	ok(GameNightLife.adjust_weight("wolf", _ctx("forest", 100, false), 1.37) == 1.37, "a creature that is not night-only is the same by day")
	ok(GameNightLife.adjust_weight("wolf", _ctx("forest", 100, true), 1.37) == 1.37, "and by night")
	# the text game's hunt pool is the old rule: both night creatures are in it, whatever the hour
	var swamp_pool := _ids(GameSpawn.hunt_pool(100, ["swamp"]))
	var forest_pool := _ids(GameSpawn.hunt_pool(100, ["forest"]))
	ok("ghoul" in swamp_pool and "thornhound" in forest_pool, "the hunt's pool still holds the night creatures")
	var d := _fresh()
	ok(not GameDay.is_night(d) and GameNightLife.glow_node(d, 100, 100).is_empty(), "a new dynasty's clock is at day and no glowcap grows")


func test_tables() -> void:
	var swamp_day := _ids(GameSpawn.table(_ctx("swamp", 100, false)))
	var swamp_night := _ids(GameSpawn.table(_ctx("swamp", 100, true)))
	ok("ghoul" not in swamp_day, "no ghouls in the swamp by day")
	ok("ghoul" in swamp_night, "ghouls at night")
	ok("bog_troll" in swamp_day and "bog_troll" in swamp_night, "the rest of the swamp is there both times")
	var forest_day := _ids(GameSpawn.table(_ctx("forest", 100, false)))
	var forest_night := _ids(GameSpawn.table(_ctx("forest", 100, true)))
	ok("thornhound" not in forest_day and "goblin" in forest_day, "no thornhounds in the forest by day, goblins yes")
	ok("thornhound" in forest_night, "thornhounds by night")
	ok("wraith" in _ids(GameSpawn.table(_ctx("forest", 155, true))) and "wraith" not in _ids(GameSpawn.table(_ctx("forest", 155, false))), "a wraith walks the forest by night only (the era lets it)")
	ok("wraith" not in forest_night, "and not before its era")
	ok("skeleton" in _ids(GameSpawn.table(_ctx("plains", 100, true))) and "skeleton" not in _ids(GameSpawn.table(_ctx("plains", 100, false))), "skeletons on the plains by night only")
	var w_night := 0.0
	for r in GameSpawn.table(_ctx("plains", 100, true)):
		if str(r["id"]) == "skeleton":
			w_night = float(r["weight"])
	ok(is_equal_approx(w_night, float(GameSpawn.data()["creatures"]["skeleton"]["weight"]) * float(GameNightLife.data()["night_adds"]["plains"]["skeleton"])), "a night-add has its own weight")
	# a tile's roll is keyed: the same world gives the same creature
	var d := _fresh()
	var a := GameSpawn.spawn_at(d, 120, -1, 140, 0, true)
	ok(a == GameSpawn.spawn_at(d, 120, -1, 140, 0, true), "the same tile and time give the same creature")


## A tile with a glowcap: [x, z].
func _glow_tile(d: GameDynasty) -> Vector2i:
	for z in range(10, 400, 3):
		for x in range(10, 400, 3):
			if not GameNightLife.glow_decision(d, x, z).is_empty():
				return Vector2i(x, z)
	return Vector2i(-1, -1)


func test_glowcaps() -> void:
	var d := _fresh()
	var t := _glow_tile(d)
	ok(t.x >= 0, "the world has glowcap ground")
	var dec := GameNightLife.glow_decision(d, t.x, t.y)
	var tile := GameWorldGen.tile(d, t.x, t.y)
	ok(str(tile["biome"]) in ["forest", "swamp"] and (tile["node"] as Dictionary).is_empty() and not tile["water"], "a glowcap grows on a forest or swamp tile with no node of its own")
	ok(str(dec["material"]) == "herb" and int(dec["amount"]) >= 2 and int(dec["amount"]) <= 4, "it gives 2 to 4 herbs")
	ok(GameNightLife.glow_decision(d, t.x, t.y) == dec, "the same tile always gives the same node")
	d.world_seconds = NOON
	ok(GameNightLife.glow_node(d, t.x, t.y).is_empty(), "by day nothing is there")
	ok(GameCompanions.scan(d, Vector2(float(t.x), float(t.y))).filter(func(n): return int(n["x"]) == t.x and int(n["z"]) == t.y).is_empty(), "by day the nodes in reach leave it out")
	ok(GameNightLife.glow_in(d, Rect2i(t.x - 3, t.y - 3, 7, 7)).is_empty(), "and the screen is given none")
	var by_day := GameForage.forage(d, t.x, t.y)
	ok(not by_day["ok"] or (by_day["ok"] and (int(by_day["x"]) != t.x or int(by_day["z"]) != t.y)), "Forage by day does not take it")
	d.gathered.clear()
	d.world_seconds = NIGHT
	ok(GameDay.is_night(d), "world second %d is night" % int(NIGHT))
	ok(not GameNightLife.glow_node(d, t.x, t.y).is_empty(), "by night it is there")
	ok(not GameNightLife.glow_in(d, Rect2i(t.x - 3, t.y - 3, 7, 7)).filter(func(g): return int(g["x"]) == t.x and int(g["z"]) == t.y).is_empty(), "and drawn")
	var near: Array = GameForage.in_reach(d, t.x, t.y)
	ok(near.any(func(n): return int(n["x"]) == t.x and int(n["z"]) == t.y), "the Forage action can reach it")
	# stand on it and gather: nothing else is in reach first
	var stores_before := GameCraft.describe(d)
	var got: Dictionary = GameForage.forage(d, t.x, t.y)
	ok(got["ok"], "the heir forages at night")
	ok(GameCraft.describe(d) != stores_before, "and the stores change")
	var key := GameCompanions.node_key(int(got["x"]), int(got["z"]))
	ok(d.gathered.has(key), "the node is marked gathered like any other")
	ok(GameCompanions.depleted(d, int(got["x"]), int(got["z"])), "and it is not there again")
	d.world.year += float(GameCompanions.setting("regrow_years")) + 0.1
	ok(not GameCompanions.depleted(d, int(got["x"]), int(got["z"])), "until the years bring it back")
	# nothing is saved of it but the mark every node already leaves
	var save := JSON.stringify(d.to_save())
	ok(not save.contains("glowcap") and not save.contains("stall"), "no glowcap or stall is written into a save")


func test_stalls() -> void:
	var d := _fresh()
	var list := GameNightLife.stalls(d)
	ok(list.size() >= 1, "the towns have market stalls (%d)" % list.size())
	for s in list:
		var t := GameWorldGen.tile(d, int(s["x"]), int(s["z"]))
		ok(not t["water"] and (t["node"] as Dictionary).is_empty() and not GameWalls.blocks(int(s["x"]), int(s["z"])), "%s stands on open dry ground" % s["id"])
		ok(GameTown.at(int(s["x"]), int(s["z"])).is_empty(), "%s is not inside a building" % s["id"])
		var g: Dictionary = GameWalls.gates(str(s["place"]))[0]
		ok(Vector2(float(int(s["x"])), float(int(s["z"]))).distance_to(Vector2(g["outer"])) <= 12.0, "%s is by its town's gate" % s["id"])
	ok(GameNightLife.stalls(d) == list, "the stalls are the same every time")
	var s: Dictionary = list[0]
	var here := Vector2i(int(s["x"]), int(s["z"]))
	d.world_seconds = NOON
	ok(GameNightLife.stalls_open(d), "the stall is open at noon")
	ok(not GameNightLife.stalls_in(d, Rect2i(here.x - 2, here.y - 2, 5, 5)).is_empty(), "and is drawn")
	ok(GameNightLife.stall_near(d, here.x, here.y).get("id", "") == s["id"], "the heir beside it can trade")
	ok(GameNightLife.stall_hint(d, here.x, here.y) != "", "the place line says so")
	ok(GameNightLife.stall_near(d, here.x + 8, here.y).is_empty(), "not from across the road")
	var use := GameNightLife.stall_use(d, s)
	ok(use["ok"] and use["open"] == "merchant" and use["landmark"]["id"] == s["id"], "using it opens the merchant's panel")
	ok(GameWildsTrade.is_trader(s), "it deals as a trader does")
	var wares := GameWildsTrade.wares(d, s)
	ok(not wares.is_empty(), "with wares (%d)" % wares.size())
	ok(wares == GameWildsTrade.wares(d, s), "the same wares each time")
	d.heir.gold = 100000
	var first: Dictionary = wares[0]
	var line := GameWildsTrade.buy(d, s, str(first["key"]))
	ok(line != "" and GameWildsTrade.sold_out(d, s, str(first["key"])), "a ware can be bought and is then gone")
	ok(GameWildsSites.name_of(s) == GameNightLife.text("stall_name"), "the panel calls it the market stall")
	# through the sandbox's Use
	var sb := GameSandbox.start(d)
	sb.creatures.clear()
	sb.heir = here
	var r := sb.use()
	sb.heir = here + Vector2i(3, 0)
	ok(str(r.get("open", "")) == "merchant", "the sandbox's Use at the stall opens the trader")
	ok(sb.name_at(float(here.x) + 0.5, float(here.y) + 0.5).get("name", "") == GameNightLife.text("trader"), "the trader is named when pointed at")
	d.world_seconds = NIGHT
	ok(not GameNightLife.stalls_open(d) and GameNightLife.stall_near(d, here.x, here.y).is_empty(), "at night the stall is shut and the trader gone")
	ok(GameNightLife.stalls_in(d, Rect2i(here.x - 2, here.y - 2, 5, 5)).is_empty(), "and not drawn")
	d.world_seconds = NOON
	d.world.weather_id = "storm"
	ok(not GameNightLife.stalls_open(d), "a storm shuts it too")
	d.world.weather_id = "clear"
	ok(GameNightLife.stalls_open(d), "clear weather opens it again")
	d.world_seconds = 3.0 * float(GameDay.setting("day_seconds")) + NOON
	ok(GameNightLife.stalls_open(d), "on another day it is open again")


func test_notes() -> void:
	var d := _fresh()
	d.world_seconds = NIGHT
	d.world.weather_id = "clear"
	var far := Vector2i(-5000, -5000)
	ok(GameNightLife.note(d, far).begins_with("Night:") and "glowcaps" in GameNightLife.note(d, far), "at night the status says glowcaps bloom")
	ok(GameWeatherFx.notes(d, far).size() == 1, "one line in clear weather at night")
	d.world_seconds = NOON
	ok(GameNightLife.note(d, far) == "", "by day, far from a stall, the status says nothing of it")
	var s: Dictionary = GameNightLife.stalls(d)[0]
	ok(GameNightLife.note(d, Vector2i(int(s["x"]), int(s["z"]))).begins_with("Day:"), "near the stall by day it says the stall trades")
	d.world.weather_id = "rain"
	ok(GameWeatherFx.notes(d, Vector2i(int(s["x"]), int(s["z"]))).size() == 2, "and the weather's line follows it")
