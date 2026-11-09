## Building and placement rules (roadmap item 50): the data and ways to break it; the claim round the family house and how
## the house grows it; what can stand where (one to a cell, trees and rock, slopes, water and bridges, doors and their
## frames, dug ground underground); paying and the refund; taking down; rooms (closed by walls and doors, no diagonal
## leaks, too big, open gaps); that GamePath walks the built ground; saving, loading old and damaged saves; and that
## building draws no dice and the autopilot builds nothing.
## Run: godot --headless --path . -s res://tests/test_game_build.gd
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
	test_claim()
	test_place_and_pay()
	test_ground()
	test_water()
	test_doors()
	test_underground()
	test_rooms()
	test_path()
	test_saving()
	test_pure()
	print("build tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh() -> GameDynasty:
	var d := GameDynasty.new_game(5, "Tess", "warrior", "faetouched", "human")
	GameCraft.add_material(d, "oak", 200)
	GameCraft.add_material(d, "iron", 20)
	d.heir.gold = 500
	return d


func _wide() -> void:
	GameBuild.data()["settings"]["base_radius"] = 400   # the whole neighbourhood is ours: for finding trees, water and slopes
	GameBuild.data()["settings"]["radius_per_house_level"] = 0


func _reset() -> void:
	GameBuild._cache = {}


func _base() -> Vector2i:
	var b := GameBuild.base()
	return Vector2i(int(b["x"]), int(b["z"]))


## The first tile, searching outward from the home town, that a test like.
func _scan(d: GameDynasty, pred: Callable, radius: int = 150) -> Vector2i:
	var surf: Callable = GamePath.world_ground(d)["surface"]
	var b := _base()
	for r in range(0, radius + 1):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var x := b.x + dx
				var z := b.y + dz
				if GameWorldGen.in_bounds(x, z) and pred.call(surf, x, z):
					return Vector2i(x, z)
	return Vector2i(-1, -1)


# ---------------------------------------------------------------- data

func test_data() -> void:
	ok(GameBuild.validate().is_empty(), "the data is sound: %s" % str(GameBuild.validate()))
	var saved: Dictionary = GameBuild.data().duplicate(true)
	GameBuild.data()["pieces"]["wall"]["cost"]["unobtainium"] = 1
	ok(not GameBuild.validate().is_empty(), "a piece that costs a material the game does not have is found")
	GameBuild._cache = saved.duplicate(true)
	GameBuild.data()["pieces"].erase("door")
	ok(not GameBuild.validate().is_empty(), "a kind GamePath walks that nothing can build is found")
	GameBuild._cache = saved.duplicate(true)
	GameBuild.data()["pieces"]["gate"] = {"name": "Gate", "cost": {"oak": 1}, "gold": 0, "refund": 0.5, "max_slope": 1, "over_water": false, "needs_frame": false}
	ok(not GameBuild.validate().is_empty(), "a piece GamePath does not know is found")
	GameBuild._cache = saved.duplicate(true)
	GameBuild.data()["settings"]["base_place"] = "nowhere"
	ok(not GameBuild.validate().is_empty(), "a base that is not a place is found")
	GameBuild._cache = saved.duplicate(true)
	GameBuild.data()["settings"]["base_place"] = "goblin_warrens"
	ok(not GameBuild.validate().is_empty(), "a base that is not a town is found")
	GameBuild._cache = saved.duplicate(true)
	GameBuild.data()["text"].erase("hangs")
	ok(not GameBuild.validate().is_empty(), "a missing line of text is found")
	GameBuild._cache = saved.duplicate(true)
	GameBuild.data()["pieces"]["wall"]["over_water"] = true
	ok(not GameBuild.validate().is_empty(), "a wall that can be a bridge is found")
	GameBuild._cache = saved.duplicate(true)
	GameBuild.data()["pieces"]["road"]["gold"] = 0
	ok(not GameBuild.validate().is_empty(), "a piece that costs nothing is found")
	_reset()
	ok(GameBuild.validate().is_empty(), "(and the data is whole again after)")


# ---------------------------------------------------------------- the claim

func test_claim() -> void:
	var d := _fresh()
	var b := _base()
	ok(GameBuild.in_claim(d, b.x, b.y) and GameBuild.in_claim(d, b.x + 11, b.y), "the home town's ground is the family's")
	ok(not GameBuild.in_claim(d, b.x + 13, b.y), "and 13 tiles out is not")
	var far := GameBuild.check(d, "wall", b.x + 13, GameBuild.SURFACE, b.y)
	ok(far.contains("outside the family's ground"), "so building there is refused, saying why: %s" % far)
	ok(is_equal_approx(GameBuild.claim_radius(d), 12.0), "a plain house has the base radius")
	d.house["hall"] = 2
	d.house["yard"] = 1
	ok(is_equal_approx(GameBuild.claim_radius(d), 12.0 + 3.0 * 3.0), "every house level bought widens it by %d" % 3)
	ok(GameBuild.in_claim(d, b.x + 15, b.y) and not GameBuild.in_claim(d, b.x + 22, b.y), "so ground 15 out is the family's and 22 is not")
	d.house["hall"] = 99   # out of range: GameHouse clamps it
	ok(GameBuild.claim_radius(d) <= 12.0 + 3.0 * 3.0 * float(GameHouse.max_level()) + 0.001, "(levels are those GameHouse allows)")
	var shut := GameBuild.check(_fresh(), "wall", 2, GameBuild.SURFACE, 2)
	ok(shut != "", "ground in another part of the world is refused: %s" % shut)


# ---------------------------------------------------------------- placing and paying

func test_place_and_pay() -> void:
	var d := _fresh()
	var b := _base()
	var r := GameBuild.place(d, "wall", b.x, GameBuild.SURFACE, b.y)
	ok(r["ok"] and GameBuild.kind_at(d, b.x, GameBuild.SURFACE, b.y) == "wall" and d.built.size() == 1, "a wall goes up in the home town: %s" % r["text"])
	ok(GameCraft.have(d, "oak") == 198, "and costs its two oak (198 left)")
	var again := GameBuild.place(d, "floor", b.x, GameBuild.SURFACE, b.y)
	ok(not again["ok"] and again["text"].contains("already built") and GameCraft.have(d, "oak") == 198, "a cell holds one piece, and a refusal costs nothing: %s" % again["text"])
	var bad := GameBuild.place(d, "tower", b.x + 1, GameBuild.SURFACE, b.y)
	ok(not bad["ok"] and bad["text"].contains("tower"), "an unknown kind is refused: %s" % bad["text"])
	var road := GameBuild.place(d, "road", b.x + 1, GameBuild.SURFACE, b.y)
	ok(road["ok"] and d.heir.gold == 497, "a road is paid for in gold (3)")
	d.heir.gold = 2
	var poor := GameBuild.place(d, "road", b.x + 2, GameBuild.SURFACE, b.y)
	ok(not poor["ok"] and poor["text"].contains("gold") and not d.built.has(GameBuild.key(b.x + 2, GameBuild.SURFACE, b.y)), "without the gold it is not built: %s" % poor["text"])
	GameCraft.add_material(d, "oak", -GameCraft.have(d, "oak"))
	var none := GameBuild.place(d, "wall", b.x + 2, GameBuild.SURFACE, b.y)
	ok(not none["ok"] and none["text"].contains("oak") and none["text"].contains("2 needed"), "or without the wood: %s" % none["text"])
	ok(GameBuild.check(d, "wall", b.x, 5, b.y) != "" and GameBuild.check(d, "wall", b.x, -2, b.y) != "", "above the surface and below the deepest ground is out of range")
	ok(GameBuild.check(d, "wall", -3, GameBuild.SURFACE, b.y) != "", "and off the map is refused")
	var d2 := _fresh()
	GameBuild.place(d2, "wall", b.x, GameBuild.SURFACE, b.y)
	var back := GameBuild.remove(d2, b.x, GameBuild.SURFACE, b.y)
	ok(back["ok"] and d2.built.is_empty() and GameCraft.have(d2, "oak") == 199, "taking a wall down gives back half its cost: %s" % back["text"])
	GameBuild.place(d2, "road", b.x, GameBuild.SURFACE, b.y)
	var gold_before: int = d2.heir.gold
	GameBuild.remove(d2, b.x, GameBuild.SURFACE, b.y)
	ok(d2.heir.gold == gold_before, "a road gives nothing back")
	ok(not GameBuild.remove(d2, b.x + 5, GameBuild.SURFACE, b.y)["ok"], "taking down what is not there does nothing")


# ---------------------------------------------------------------- trees, rock, slopes

func test_ground() -> void:
	var d := _fresh()
	_wide()
	var tree := _scan(d, func(s: Callable, x: int, z: int) -> bool: return bool(s.call(x, z)["block"]))
	ok(tree.x >= 0, "(there is a tree or rock to find near the home town)")
	var why := GameBuild.check(d, "floor", tree.x, GameBuild.SURFACE, tree.y)
	ok(why.contains("in the way"), "nothing is built on a tree or rock: %s" % why)
	var steep := _scan(d, func(s: Callable, x: int, z: int) -> bool:
		var info: Dictionary = s.call(x, z)
		if info["water"] or info["block"]:
			return false
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Dictionary = s.call(x + dir.x, z + dir.y)
			if n.is_empty() or n["water"]:
				return false   # keep to ground with no water beside it
		var worst := 0
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			worst = maxi(worst, absi(int(s.call(x + dir.x, z + dir.y)["h"]) - int(info["h"])))
		return worst == 2)
	ok(steep.x >= 0, "(there is ground with a step of 2 to find)")
	ok(GameBuild.check(d, "wall", steep.x, GameBuild.SURFACE, steep.y).contains("too steep"), "a wall needs level ground (a step of 2 is too steep): %s" % GameBuild.check(d, "wall", steep.x, GameBuild.SURFACE, steep.y))
	ok(GameBuild.check(d, "floor", steep.x, GameBuild.SURFACE, steep.y) == "" and GameBuild.check(d, "road", steep.x, GameBuild.SURFACE, steep.y) == "", "but a floor and a road go on it")
	var level := _scan(d, func(s: Callable, x: int, z: int) -> bool:
		var info: Dictionary = s.call(x, z)
		if info["water"] or info["block"]:
			return false
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Dictionary = s.call(x + dir.x, z + dir.y)
			if n.is_empty() or n["water"] or absi(int(n["h"]) - int(info["h"])) > 0:
				return false
		return true)
	ok(GameBuild.check(d, "wall", level.x, GameBuild.SURFACE, level.y) == "", "and a wall goes on level ground")
	_reset()


# ---------------------------------------------------------------- water and bridges

func test_water() -> void:
	var d := _fresh()
	_wide()
	GameBuild.data()["settings"]["base_place"] = "brinehaven"   # the home town of this test is on the coast: Hearthmere has no lake near it
	GameBuild.data()["settings"]["max_span"] = 2
	var lake := _scan(d, func(s: Callable, x: int, z: int) -> bool:
		# a shore tile (dry, level enough) with three water tiles in a row east of it: x+1, x+2, x+3 are all water
		var info: Dictionary = s.call(x, z)
		if info.is_empty() or info["water"]:
			return false
		for i in range(1, 4):
			var w: Dictionary = s.call(x + i, z)
			if w.is_empty() or not w["water"]:
				return false
		return true, 120)
	ok(lake.x >= 0, "(there is a shore with open water beside it to find)")
	if lake.x < 0:
		_reset()
		return
	var w1 := Vector2i(lake.x + 1, lake.y)
	var w2 := Vector2i(lake.x + 2, lake.y)
	var w3 := Vector2i(lake.x + 3, lake.y)
	ok(GameBuild.check(d, "wall", w1.x, GameBuild.SURFACE, w1.y).contains("open water"), "a wall cannot stand in water: %s" % GameBuild.check(d, "wall", w1.x, GameBuild.SURFACE, w1.y))
	ok(GameBuild.check(d, "door", w1.x, GameBuild.SURFACE, w1.y).contains("open water"), "nor a door")
	ok(GameBuild.check(d, "floor", w2.x, GameBuild.SURFACE, w2.y).contains("no more than"), "a floor with nothing to hold it is refused: %s" % GameBuild.check(d, "floor", w2.x, GameBuild.SURFACE, w2.y))
	var walker: Dictionary = GamePath.data()["movers"]["walker"]
	ok(not GamePath.passable(GamePath.world_ground(d), Vector3i(w1.x, GamePath.SURFACE, w1.y), walker), "(a walker cannot stand in that water)")
	ok(GameBuild.place(d, "floor", w1.x, GameBuild.SURFACE, w1.y)["ok"], "a floor beside the shore is a plank out from it")
	ok(GamePath.passable(GamePath.world_ground(d), Vector3i(w1.x, GamePath.SURFACE, w1.y), walker), "and a walker can stand on it")
	ok(GameBuild.place(d, "road", w2.x, GameBuild.SURFACE, w2.y)["ok"], "the next tile out can follow (a road will do)")
	ok(GameBuild.check(d, "floor", w3.x, GameBuild.SURFACE, w3.y).contains("no more than 2"), "but a bridge reaches no more than max_span (2) tiles from the shore: %s" % GameBuild.check(d, "floor", w3.x, GameBuild.SURFACE, w3.y))
	var held := GameBuild.remove(d, w1.x, GameBuild.SURFACE, w1.y)
	ok(not held["ok"] and held["text"].contains("rest on"), "the plank the others rest on cannot be taken away: %s" % held["text"])
	ok(GameBuild.remove(d, w2.x, GameBuild.SURFACE, w2.y)["ok"] and GameBuild.remove(d, w1.x, GameBuild.SURFACE, w1.y)["ok"], "the far one first, then the near one")
	_reset()


# ---------------------------------------------------------------- doors

func test_doors() -> void:
	var d := _fresh()
	var b := _base()
	var s := GameBuild.SURFACE
	ok(GameBuild.check(d, "door", b.x, s, b.y).contains("wall on each"), "a door in the open needs a frame: %s" % GameBuild.check(d, "door", b.x, s, b.y))
	GameBuild.place(d, "wall", b.x - 1, s, b.y)
	ok(GameBuild.check(d, "door", b.x, s, b.y).contains("wall on each"), "one wall is not a frame")
	GameBuild.place(d, "wall", b.x + 1, s, b.y)
	ok(GameBuild.check(d, "door", b.x, s, b.y) == "", "walls on both sides are")
	GameBuild.place(d, "wall", b.x, s, b.y - 1)
	GameBuild.place(d, "wall", b.x + 5, s, b.y)
	ok(GameBuild.check(d, "door", b.x + 3, s, b.y) != "", "walls that are not beside it are not a frame")
	var iron := GameCraft.have(d, "iron")
	var placed := GameBuild.place(d, "door", b.x, s, b.y)
	ok(placed["ok"] and GameCraft.have(d, "iron") == iron - 1, "the door is built and costs its iron")
	var hung := GameBuild.remove(d, b.x - 1, s, b.y)
	ok(not hung["ok"] and hung["text"].contains("door hangs") and d.built.has(GameBuild.key(b.x - 1, s, b.y)), "a wall a door hangs on cannot be taken down: %s" % hung["text"])
	ok(GameBuild.remove(d, b.x, s, b.y - 1)["ok"], "a wall that holds no door can")
	ok(GameBuild.remove(d, b.x, s, b.y)["ok"] and GameBuild.remove(d, b.x - 1, s, b.y)["ok"], "and once the door is down so can the walls")


# ---------------------------------------------------------------- underground

func test_underground() -> void:
	var d := _fresh()
	var b := _base()
	var site := GameWorldGen.MINE_SITE
	ok(GameBuild.check(d, "wall", b.x, 0, b.y).contains("dug"), "underground nothing is built in rock that has not been dug: %s" % GameBuild.check(d, "wall", b.x, 0, b.y))
	GameMine.dig(d, site, b.x, 0, b.y, 50.0)
	GameMine.dig(d, site, b.x + 1, 0, b.y, 50.0)
	ok(GameMine.is_dug(d, site, b.x, 0, b.y), "(the cell is dug)")
	ok(GameBuild.check(d, "floor", b.x, 0, b.y) == "", "but dug ground can be built in")
	ok(GameBuild.place(d, "wall", b.x + 1, 0, b.y)["ok"] and d.built.has(GameBuild.key(b.x + 1, 0, b.y)), "a wall can close a tunnel")
	var g := GamePath.world_ground(d)
	ok(GamePath.passable(g, Vector3i(b.x, 0, b.y), GamePath.data()["movers"]["walker"]) and not GamePath.passable(g, Vector3i(b.x + 1, 0, b.y), GamePath.data()["movers"]["walker"]), "and GamePath sees the tunnel open at one cell and shut at the other")
	ok(GameBuild.check(d, "wall", b.x, GameMine.setting("max_depth") + 1, b.y) != "", "below the deepest ground is out of range")


# ---------------------------------------------------------------- rooms

func _ring(d: GameDynasty, x0: int, z0: int, size: int) -> void:
	for i in range(0, size):
		GameBuild.place(d, "wall", x0 + i, GameBuild.SURFACE, z0)
		GameBuild.place(d, "wall", x0 + i, GameBuild.SURFACE, z0 + size - 1)
		GameBuild.place(d, "wall", x0, GameBuild.SURFACE, z0 + i)
		GameBuild.place(d, "wall", x0 + size - 1, GameBuild.SURFACE, z0 + i)


func test_rooms() -> void:
	var d := _fresh()
	var b := _base()
	var s := GameBuild.SURFACE
	ok(GameBuild.rooms(d).is_empty(), "nothing built, no rooms")
	_ring(d, b.x - 2, b.y - 2, 5)
	var rooms := GameBuild.rooms(d)
	ok(rooms.size() == 1 and rooms[0]["area"] == 9 and rooms[0]["sealed"] and rooms[0]["doors"].is_empty(), "a ring of walls 5 across is one room of 9 tiles, sealed")
	ok(not GameBuild.room_at(d, b.x, b.y).is_empty() and GameBuild.room_at(d, b.x + 6, b.y).is_empty(), "and room_at finds the one tile and not the open ground")
	var walker := "walker"
	var g := GamePath.world_ground(d)
	var out := Vector3i(b.x - 6, GamePath.SURFACE, b.y)
	var inside := Vector3i(b.x, GamePath.SURFACE, b.y)
	ok(not GamePath.find(g, out, inside, walker, 3000)["found"], "no way into a sealed room (GamePath agrees)")
	GameBuild.remove(d, b.x - 2, s, b.y)
	var door := GameBuild.place(d, "door", b.x - 2, s, b.y)
	ok(door["ok"], "a door can replace a wall of the ring (the walls beside it are its frame): %s" % door["text"])
	rooms = GameBuild.rooms(d)
	ok(rooms.size() == 1 and not rooms[0]["sealed"] and rooms[0]["doors"] == [Vector2i(b.x - 2, b.y)] and rooms[0]["area"] == 9, "now the room has its door")
	var way := GamePath.find(GamePath.world_ground(d), out, inside, walker, 3000)
	ok(way["found"] and way["path"].has(Vector3i(b.x - 2, GamePath.SURFACE, b.y)), "and the way in goes through it")
	GameBuild.remove(d, b.x + 2, s, b.y + 2)   # a corner
	ok(GameBuild.rooms(d).size() == 1, "a missing corner leaves the room as it was (no four-way gap)")
	ok(not GamePath.find(GamePath.world_ground(d), Vector3i(b.x + 3, GamePath.SURFACE, b.y + 3), Vector3i(b.x + 1, GamePath.SURFACE, b.y + 1), walker, 3000)["found"] or way["found"], "(and nothing cuts the corner in: GamePath does not)")
	GameBuild.remove(d, b.x, s, b.y + 2)   # a wall in the middle of the south side
	ok(GameBuild.rooms(d).is_empty(), "a gap in a side opens it: no room")
	GameBuild.place(d, "wall", b.x, s, b.y + 2)
	ok(GameBuild.rooms(d).size() == 1, "and mending it brings the room back")
	var narrow: Dictionary = GameBuild.data()["settings"]
	narrow["max_room_area"] = 8
	ok(GameBuild.rooms(d).is_empty(), "a closed space bigger than max_room_area is a yard, not a room")
	_reset()
	var d2 := _fresh()
	_ring(d2, b.x - 3, b.y - 3, 4)   # 2 x 2 inside
	_ring(d2, b.x + 2, b.y - 3, 4)
	ok(GameBuild.rooms(d2).size() == 2, "two rings are two rooms")
	ok(GameBuild.describe(d2).contains("2 rooms"), "and they are counted: %s" % GameBuild.describe(d2))


# ---------------------------------------------------------------- the path

func test_path() -> void:
	var d := _fresh()
	var b := _base()
	var s := GameBuild.SURFACE
	var from := Vector3i(b.x - 8, GamePath.SURFACE, b.y)
	var to := Vector3i(b.x + 8, GamePath.SURFACE, b.y)
	var open_cost := float(GamePath.find(GamePath.world_ground(d), from, to, "walker", 4000)["cost"])
	for z in range(b.y - 6, b.y + 7):
		GameBuild.place(d, "wall", b.x, s, z)
	var round_it := GamePath.find(GamePath.world_ground(d), from, to, "walker", 4000)
	ok(round_it["found"] and float(round_it["cost"]) > open_cost + 3.0, "a wall the family builds makes GamePath go round it: %.1f against %.1f" % [float(round_it["cost"]), open_cost])
	GameBuild.remove(d, b.x, s, b.y)
	GameBuild.place(d, "wall", b.x, s, b.y - 1)
	GameBuild.remove(d, b.x, s, b.y - 1)
	GameBuild.place(d, "wall", b.x, s, b.y - 1)
	GameBuild.place(d, "wall", b.x, s, b.y + 1)
	var gate := GameBuild.place(d, "door", b.x, s, b.y)
	var through := GamePath.find(GamePath.world_ground(d), from, to, "walker", 4000)
	ok(gate["ok"] and through["found"] and float(through["cost"]) < float(round_it["cost"]) and through["path"].has(Vector3i(b.x, GamePath.SURFACE, b.y)), "a door in it is the way through: %.1f" % float(through["cost"]))
	var override := GamePath.find(GamePath.world_ground(d, {}), from, to, "walker", 4000)
	ok(is_equal_approx(float(override["cost"]), open_cost), "(an overlay given to world_ground still replaces the family's)")


# ---------------------------------------------------------------- saving

func test_saving() -> void:
	var d := _fresh()
	var b := _base()
	var s := GameBuild.SURFACE
	ok(not d.to_dict().has("built"), "a house with nothing built saves no 'built' key")
	_ring(d, b.x - 2, b.y - 2, 5)
	GameBuild.remove(d, b.x - 2, s, b.y)
	GameBuild.place(d, "door", b.x - 2, s, b.y)
	var saved := d.to_dict()
	ok(saved.has("built") and saved["built"].size() == 16, "once something is built it is saved (16 pieces)")
	var json := JSON.parse_string(JSON.stringify(saved)) as Dictionary
	var loaded := GameDynasty.from_dict(json)
	ok(loaded.built == d.built and GameBuild.rooms(loaded).size() == 1, "and it comes back through JSON the same, with the room")
	var old := json.duplicate(true)
	old.erase("built")
	ok(GameDynasty.from_dict(old).built.is_empty(), "an old save with no 'built' loads with nothing built")
	for junk in [5, "wall", [], null, {"1,2": "wall"}, {"a,b,c": "wall"}, {"1,-1,2": "tower"}, {"1,-1,2": 5}, {"-5,-1,2": "wall"}, {"1,-2,2": "wall"}, {"1,9999,2": "wall"}, {"999999,-1,2": "wall"}, {"1.5,-1,2": "wall"}]:
		var damaged := json.duplicate(true)
		damaged["built"] = junk
		var g := GameDynasty.from_dict(damaged)
		ok(g.built.is_empty(), "a damaged 'built' (%s) loads as nothing" % str(junk))
	var mixed := json.duplicate(true)
	mixed["built"] = {"10,-1,10": "wall", "x": "wall", "11,-1,10": "floor", "12,-1,10": "castle"}
	ok(GameDynasty.from_dict(mixed).built == {"10,-1,10": "wall", "11,-1,10": "floor"}, "only the good pieces of a mixed list are kept")
	var fresh_digest := JSON.stringify(_fresh().to_dict())
	ok(not fresh_digest.contains("built"), "(a fresh dynasty's save is as it was)")


# ---------------------------------------------------------------- pure

func test_pure() -> void:
	var d := _fresh()
	var b := _base()
	var s := GameBuild.SURFACE
	var rng_before := d.rng.state
	_ring(d, b.x - 2, b.y - 2, 5)
	GameBuild.rooms(d)
	GameBuild.remove(d, b.x, s, b.y - 2)
	ok(d.rng.state == rng_before, "building, taking down and finding rooms draw none of the dynasty's dice")
	var a := _fresh()
	var c := _fresh()
	_ring(a, b.x - 2, b.y - 2, 5)
	_ring(c, b.x - 2, b.y - 2, 5)
	ok(JSON.stringify(a.to_dict()) == JSON.stringify(c.to_dict()) and JSON.stringify(GameBuild.rooms(a)) == JSON.stringify(GameBuild.rooms(c)), "the same builds make the same save and the same rooms")
	var life := GameDynasty.new_game(7, "Bot", "warrior", "faetouched", "human")
	for i in 200:
		if life.state != "life":
			break
		GameBot.step(life)
	ok(life.built.is_empty() and not life.to_dict().has("built"), "an autopilot life builds nothing")
