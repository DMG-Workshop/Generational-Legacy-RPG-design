## The open world as it runs (roadmap items 39, 45, 48, 49, 50, 52): the heir walks the generated ground, creatures are kept
## round them (spawned as the heir comes near, let go when they fall far behind), the companions follow or work by their
## orders, and the family digs and builds. Pure rules, no screen: the screen calls these and draws what they hold.
## Nothing here is saved and no die of the dynasty's is drawn; the heir starts where the text game has them. The autopilot
## never calls it, so a seeded life is unchanged.
## Run: godot --headless --path . -s res://tests/test_game_sandbox.gd
class_name GameSandbox
extends RefCounted

const PATH := "res://data/world/sandbox.json"
static var _cache: Dictionary = {}

var d: GameDynasty
var heir := Vector2i.ZERO          # the heir's tile on the open world
var creatures: Array = []          # GameBehaviour agents
var companions: Array = []         # GameCompanions agents
var tick := 0
var next_uid := 1
var log: Array = []                # {kind, text} lines for the screen, oldest first
var route: Array = []              # tiles still to walk to (set by set_route), the next one first
var space := "world"               # where the heir is: the open world, or the id of an interior they have gone into (never saved)
var outside := Vector2i.ZERO       # the open-world tile to come back to when the heir goes out of an interior
var interior: Dictionary = {}      # the cells of the interior the heir is in (GameInterior.cells), {} on the open world
var heir_y := GameBuild.SURFACE    # the heir's layer: the surface, or a storey above it (-2 and up); never saved, a visit starts on the ground
var _occupied := {}                # "x,z" -> true, the tiles a creature stands on at spawn time


## A sandbox for a dynasty, with the heir where the text game has them and the world kept round them.
static func start(dyn: GameDynasty) -> GameSandbox:
	var s := GameSandbox.new()
	s.d = dyn
	var w := GameSpaces.where(dyn)
	var t := Vector2i(int(w["x"]), int(w["z"]))
	if t.x < 0 or t.y < 0:
		var a := GameWorldGen.anchor(dyn.world.location)
		t = Vector2i(int(a.get("x", 0)), int(a.get("z", 0)))
	var back := s._remembered()
	if back != Vector2i(-1, -1):
		t = back
	s.heir = t
	s.companions = GameCompanions.agents_for(dyn, float(t.x) + 0.5, float(t.y) + 0.5)
	s.refresh()
	return s


## The saved position, checked: whole numbers inside the world, a generation and a place name; {} when anything is missing or
## of the wrong kind (a damaged save never crashes the load).
static func load_at(v: Variant) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	for k in ["x", "z", "gen"]:
		if not v.has(k) or typeof(v[k]) not in [TYPE_INT, TYPE_FLOAT] or is_nan(float(v[k])) or is_inf(float(v[k])):
			return {}
	if not v.has("place") or typeof(v["place"]) != TYPE_STRING:
		return {}
	var x := int(v["x"])
	var z := int(v["z"])
	if not GameWorldGen.in_bounds(x, z):
		return {}
	return {"x": x, "z": z, "gen": int(v["gen"]), "place": str(v["place"])}


## Where the heir stood last time, if that still holds: the same heir (generation) at the same place of the text game, on a
## tile they can stand on. (-1, -1) when there is none, and the heir starts at the place's door as before.
func _remembered() -> Vector2i:
	var at := d.sandbox_at
	if at.is_empty() or int(at["gen"]) != d.gen or str(at["place"]) != str(d.world.location):
		return Vector2i(-1, -1)
	var t := Vector2i(int(at["x"]), int(at["z"]))
	if not GamePath.passable(GamePath.world_ground(d), Vector3i(t.x, -1, t.y), {"water": false, "ignore_blocks": false}):
		return Vector2i(-1, -1)
	return t


## Writes where the heir stands onto the dynasty, to be saved with it. Upstairs it keeps the last place on the ground, because
## the storey is not saved and a column of floors is not a place to start from.
func remember() -> void:
	if heir_y != GameBuild.SURFACE or space != "world":
		return
	d.sandbox_at = {"x": heir.x, "z": heir.y, "gen": d.gen, "place": str(d.world.location)}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


func heir_point() -> Vector2:
	return Vector2(float(heir.x) + 0.5, float(heir.y) + 0.5)


## Which storey the heir is on: 0 is the ground, 1 and up are above it.
func storey() -> int:
	return GameBuild.SURFACE - heir_y


## "Upstairs, storey 1." while above the ground, else the room the heir is in (or "").
func place_line() -> String:
	if space != "world":
		var name := str(GameSpaces.space(space).get("name", space))
		var who := GamePeople.near(space, heir.x, heir.y)
		if not who.is_empty() and heir != GameInterior.entry():
			return GamePeople.text("near", {"name": str(who["name"])})
		var room := GameInterior.room_at(space, heir.x, heir.y)
		if room == "":
			return _text("inside_in", {"place": name})
		var room_name := room
		for r in GameSpaces.rooms(space):
			if str(r["id"]) == room:
				room_name = str(r["name"])
		return _text("inside_at", {"place": name, "room": room_name.to_lower()})
	var line := GameBuild.room_line(d, heir.x, heir.y, heir_y)
	if storey() > 0:
		line = _text("upstairs_at", {"n": storey()}) if line == "" else "%s %s" % [_text("upstairs_at", {"n": storey()}), line]
	var u := GameBuild.room_use(d, heir.x, heir.y, heir_y)
	return line if u.is_empty() else "%s %s" % [line, str(u["hint"])]


## Whether the heir can step onto a tile: a neighbour in the open world, dry and not blocked (a tree, a rock outcrop, a wall).
func can_step(dx: int, dz: int) -> Dictionary:
	if absi(dx) > 1 or absi(dz) > 1 or (dx == 0 and dz == 0):
		return {"ok": false, "why": _text("not_a_step")}
	var to := heir + Vector2i(dx, dz)
	if space != "world":
		# Indoors the heir walks the floor, a tile at a time, never cutting a corner of a wall.
		var diagonal := dx != 0 and dz != 0
		if not GameInterior.passable(interior, to.x, to.y) or (diagonal and not (GameInterior.passable(interior, heir.x + dx, heir.y) and GameInterior.passable(interior, heir.x, heir.y + dz))):
			return {"ok": false, "why": _text("blocked")}
		return {"ok": true, "why": ""}
	if not GameWorldGen.in_bounds(to.x, to.y):
		return {"ok": false, "why": _text("edge")}
	var ground := GamePath.world_ground(d)
	if storey() > 0:
		# On a storey the heir walks the same rules as everything else (GamePath): built floors, no cutting a corner.
		var here := Vector3i(heir.x, heir_y, heir.y)
		for nb in GamePath.neighbours(ground, here, GamePath.data()["movers"]["walker"]):
			if nb[0] == Vector3i(to.x, heir_y, to.y):
				return {"ok": true, "why": ""}
		return {"ok": false, "why": _text("blocked")}
	if not GamePath.passable(ground, Vector3i(to.x, -1, to.y), {"water": false, "ignore_blocks": false}):
		return {"ok": false, "why": _text("blocked")}
	return {"ok": true, "why": ""}


## The heir takes one step. The creatures and companions catch up with the new place.
func move(dx: int, dz: int) -> Dictionary:
	var c := can_step(dx, dz)
	if not c["ok"]:
		return c
	heir += Vector2i(dx, dz)
	_arrive()
	refresh()
	return {"ok": true, "why": ""}


## Walking into a place's ground (a town or the wilds round an anchor) is arriving there: the family's place becomes it, as a
## journey on the map would make it, but with no years spent (the open world has its own clock), no arrival event and no dice.
## The place is marked visited and its quests told. Leaving it for open ground changes nothing: the family is still at the last
## place walked into. Only on the ground of the open world.
func _arrive() -> void:
	if space != "world" or heir_y != GameBuild.SURFACE:
		return
	var place := str(GameSpaces.space(GameSpaces.at_tile(heir.x, heir.y)).get("place", ""))
	if place == "" or place == str(d.world.location) or GameWorld.place(place).is_empty():
		return
	var dest: Dictionary = GameWorld.place(place)
	var first: bool = place not in d.world.visited
	d.world.visit(place)
	var line := _text("arrived", {"heir": d.heir.name, "place": str(dest["name"])})
	log.append({"kind": "arrive", "text": line})
	if first:
		log.append({"kind": "arrive", "text": GameMessages.text("life", "no_one_walked", {"house": d.dynasty_name, "dest": dest["name"], "description": dest.get("description", "")})})
	var msgs: Array = []
	d.quests.on_arrive(d, place, msgs)
	for m in msgs:
		log.append({"kind": "arrive", "text": str(m)})
	arrived = place


## The place the heir has just walked into, until the screen has said so (runtime only).
var arrived := ""


## Spawns the creatures the world has in the square round the heir and lets go of those far behind.
func refresh() -> void:
	if space != "world":
		return   # nothing lives or spawns indoors
	var night := GameDay.is_night(d)
	var radius := int(setting("radius"))
	var kept: Array = []
	for a in creatures:
		if _distance(a, heir) <= radius + int(setting("keep")):
			kept.append(a)
	creatures = kept
	_occupied.clear()
	for a in creatures:
		_occupied[_key(int(floor(float(a["x"]))), int(floor(float(a["z"]))))] = true
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var x := heir.x + dx
			var z := heir.y + dz
			var k := _key(x, z)
			if _occupied.has(k) or not GameWorldGen.in_bounds(x, z):
				continue
			var id := GameSpawn.spawn_at(d, x, -1, z, 0, night)
			if id == "":
				continue
			creatures.append(GameBehaviour.new_agent(next_uid, id, float(x) + 0.5, float(z) + 0.5))
			next_uid += 1
			_occupied[k] = true


## The interior whose door is on the tile the heir stands on ("" when there is none): a dungeon's door on the open world, a
## town service's or the family house's in its town. Only from the open world's ground floor.
func door_here() -> String:
	if space != "world" or storey() > 0:
		return ""
	for id in GameSpaces.ids():
		if GameSpaces.kind(id) == "interior":
			var door: Dictionary = GameSpaces.space(id).get("door", {})
			if int(door.get("x", -1)) == heir.x and int(door.get("z", -1)) == heir.y:
				return id
	return ""


## Goes in by the door the heir stands at: the heir is on the interior's floor at its entrance, the open world waits. {ok, text}.
func enter() -> Dictionary:
	var id := door_here()
	if id == "":
		return {"ok": false, "text": _text("no_door")}
	var cells := GameInterior.cells(id)
	if cells.is_empty():
		return {"ok": false, "text": _text("no_door")}
	outside = heir
	space = id
	interior = cells
	heir = GameInterior.entry()
	route = []
	var line := _text("entered", {"heir": d.heir.name, "place": str(GameSpaces.space(id).get("name", id)).to_lower()})
	log.append({"kind": "door", "text": line})
	return {"ok": true, "text": line}


## Goes out by the entrance, back to the door on the open world. {ok, text}.
func leave() -> Dictionary:
	if space == "world":
		return {"ok": false, "text": _text("no_door")}
	if heir != GameInterior.entry():
		return {"ok": false, "text": _text("no_exit")}
	space = "world"
	interior = {}
	heir = outside
	route = []
	refresh()
	var line := _text("left", {"heir": d.heir.name})
	log.append({"kind": "door", "text": line})
	return {"ok": true, "text": line}


## The Use action: out by the entrance of an interior; on the open world, in by a door, else what the room the heir stands in
## lets them do (a bedroom the family built: rest). {ok, text}.
func use() -> Dictionary:
	if space != "world":
		if heir != GameInterior.entry():
			var p := GamePeople.near(space, heir.x, heir.y)
			if not p.is_empty():
				var t := GamePeople.talk(d, space, p)
				log.append({"kind": "talk", "text": str(t["text"])})
				return t
		return leave()
	if door_here() != "":
		return enter()
	var u := GameBuild.room_use(d, heir.x, heir.y, heir_y)
	if u.is_empty():
		return {"ok": false, "text": GameBuild.text("nothing_to_use")}
	match str(u["kind"]):
		"keep":
			return {"ok": true, "text": GameBuild.text("kennel_holds", {"places": GameBuild.kennel_places(d), "kept": d.roster.size(), "cap": GameRoster.cap(d)})}
		"craft":
			# The screen opens the workshop for it (GameCraft with forge "home"); nothing changes here.
			return {"ok": true, "text": GameBuild.text("forge_lit"), "open": "workshop", "forge": "home"}
		"rest":
			var msgs := d.rest_for(float(u["years"]))
			for m in msgs:
				log.append({"kind": "rest", "text": str(m)})
			return {"ok": true, "text": str(msgs[0]) if not msgs.is_empty() else ""}
	return {"ok": false, "text": GameBuild.text("nothing_to_use")}


## Climbs from where the heir stands: `dir` -1 up (the cell must be stairs and the one above something to stand on), +1 down
## (the cell below must be stairs). The build level follows the heir. {ok, why}.
func climb(dir: int) -> Dictionary:
	if space != "world":
		return {"ok": false, "why": _text("indoors")}
	var ground := GamePath.world_ground(d)
	var mover: Dictionary = GamePath.data()["movers"]["walker"]
	var here := Vector3i(heir.x, heir_y, heir.y)
	if dir < 0:
		if not GamePath._is_stairs(ground, here):
			return {"ok": false, "why": _text("no_stairs")}
		var up := Vector3i(heir.x, heir_y - 1, heir.y)
		if heir_y - 1 < GameBuild.top_y() or not GamePath.passable(ground, up, mover):
			return {"ok": false, "why": _text("stairs_blocked")}
		heir_y -= 1
	else:
		var below := Vector3i(heir.x, heir_y + 1, heir.y)
		if heir_y >= GameBuild.SURFACE or not GamePath._is_stairs(ground, below):
			return {"ok": false, "why": _text("stairs_bottom")}
		heir_y += 1
	route = []
	build_level = storey()
	var line := _text("climbed_up", {"heir": d.heir.name, "n": storey()}) if dir < 0 else (_text("climbed_down", {"heir": d.heir.name}) if storey() == 0 else _text("climbed_part", {"heir": d.heir.name, "n": storey()}))
	log.append({"kind": "climb", "text": line})
	return {"ok": true, "why": "", "text": line}


## If the floor the heir stands on has gone, they drop to the ground (to the nearest tile they can stand on, if a wall is there).
func check_footing() -> void:
	if heir_y == GameBuild.SURFACE:
		return
	var ground := GamePath.world_ground(d)
	var mover: Dictionary = GamePath.data()["movers"]["walker"]
	var cell := Vector3i(heir.x, heir_y, heir.y)
	if GamePath.passable(ground, cell, mover) and not GamePath._built_kind(ground, cell).is_empty():
		return
	heir_y = GameBuild.SURFACE
	build_level = 0
	route = []
	if not GamePath.passable(ground, Vector3i(heir.x, GameBuild.SURFACE, heir.y), mover):
		for r in range(1, 5):
			for dz in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if maxi(absi(dx), absi(dz)) == r and GamePath.passable(ground, Vector3i(heir.x + dx, GameBuild.SURFACE, heir.y + dz), mover):
						heir += Vector2i(dx, dz)
						log.append({"kind": "climb", "text": _text("fell", {"heir": d.heir.name})})
						refresh()
						return
	log.append({"kind": "climb", "text": _text("fell", {"heir": d.heir.name})})


## One tick of the open world: the creatures act, then the companions (told of the creatures near them), and their events
## go to the log.
func step(ticks: int = 1) -> void:
	for _i in ticks:
		tick += 1
		if space != "world":
			continue   # the open world is outside: its creatures and companions wait
		check_footing()
		var night := GameDay.is_night(d)
		var threats := _threats()
		var cview := GameBehaviour.world_view(d, [{"x": heir_point().x, "z": heir_point().y}], night)
		creatures = GameBehaviour.step_all(creatures, cview, d.seed_value, tick)
		companions = GameCompanions.reconcile(d, companions, heir_point().x, heir_point().y)
		var router := GamePath.router(GamePath.world_ground(d))
		var out := GameCompanions.step_all(d, companions, GameCompanions.view(d, heir_point().x, heir_point().y, threats, router), tick)
		companions = out["agents"]
		for e in out["events"]:
			log.append({"kind": "companion", "text": GameCompanions.event_text(e)})
		var keep_lines := int(setting("log_lines"))
		if log.size() > keep_lines:
			log = log.slice(log.size() - keep_lines)


## Plans a walk from the heir to a tile of the open world over the ground as it is now (GamePath, a walker). Sets the
## route when found and returns {ok, why, steps}; the heir then walks it one tile at a time with `walk_one`.
func set_route(target: Vector2i) -> Dictionary:
	route = []
	if space != "world":
		return {"ok": false, "why": _text("indoors"), "steps": 0}
	if storey() > 0:
		return {"ok": false, "why": _text("upstairs_route"), "steps": 0}
	if target == heir:
		return {"ok": true, "why": "", "steps": 0}
	if not GameWorldGen.in_bounds(target.x, target.y):
		return {"ok": false, "why": _text("edge"), "steps": 0}
	var found := GamePath.find(GamePath.world_ground(d), Vector3i(heir.x, -1, heir.y), Vector3i(target.x, -1, target.y),
		"walker", int(setting("route_nodes")))
	if not found["found"]:
		return {"ok": false, "why": _text("no_route"), "steps": 0}
	var path: Array = found["path"]
	for i in range(1, path.size()):
		route.append(Vector2i(path[i].x, path[i].z))
	return {"ok": true, "why": "", "steps": route.size()}


## The heir takes the next tile of the route. False when there is no route or the way is now blocked (the route is dropped).
func walk_one() -> bool:
	if route.is_empty():
		return false
	var next: Vector2i = route[0]
	var r := move(next.x - heir.x, next.y - heir.y)
	if not r["ok"]:
		route = []
		return false
	route.pop_front()
	return true


## Gives a companion an order (`GameCompanions.set_order`): {ok, text}.
func order(id: String, which: String) -> Dictionary:
	return GameCompanions.set_order(d, id, which)


## Gives a companion the next order in turn (follow, stay, gather, guard, then follow again): {ok, text}.
func cycle_order(id: String) -> Dictionary:
	if not d.party.has_member(id):
		return GameCompanions.set_order(d, id, GameCompanions.FOLLOW)   # not in the party: the same refusal
	var orders: Array = GameCompanions.ORDERS
	var next: String = orders[(orders.find(GameCompanions.order_of(d, id)) + 1) % orders.size()]
	return GameCompanions.set_order(d, id, next)


## The storey the build controls work on: 0 is the ground floor, 1 and up are above it (not saved; a visit starts on the ground).
var build_level := 0


## The layer of the build level (GameBuild's y).
func build_y() -> int:
	return GameBuild.SURFACE - build_level


## The build level as the Level button says it: "ground", the storey's number, or "roof" for the layer over the top storey.
func level_name() -> String:
	if build_level == 0:
		return "ground"
	return "roof" if build_level > int(GameBuild.setting("max_storeys")) else str(build_level)


## Steps the build level up a storey, and back to the ground after the top one.
func cycle_level() -> int:
	build_level = (build_level + 1) % (int(GameBuild.setting("max_storeys")) + 2)   # the last step is the roof layer
	return build_level


## The pieces the family may build, in the data's order (wall, floor, road, door).
func build_kinds() -> Array:
	return GameBuild.pieces().keys()


## Why a piece cannot go on the tile `dx, dz` from the heir (GameBuild.check), or "" when it can.
func build_check(kind: String, dx: int, dz: int) -> String:
	if space != "world":
		return _text("indoors")
	var t := heir + Vector2i(dx, dz)
	return GameBuild.check(d, kind, t.x, build_y(), t.y)


## Takes the piece on the tile `dx, dz` from the heir down, with its refund (GameBuild.remove): {ok, text}.
func remove_at(dx: int, dz: int) -> Dictionary:
	if space != "world":
		return {"ok": false, "text": _text("indoors")}
	var t := heir + Vector2i(dx, dz)
	var out := GameBuild.remove(d, t.x, build_y(), t.y)
	if out["ok"]:
		log.append({"kind": "build", "text": str(out["text"])})
	return out


## Mends the piece on the tile `dx, dz` from the heir (GameRepair.repair): {ok, text}.
func repair_at(dx: int, dz: int) -> Dictionary:
	if space != "world":
		return {"ok": false, "text": _text("indoors")}
	var t := heir + Vector2i(dx, dz)
	var out := GameRepair.repair(d, t.x, build_y(), t.y)
	if out["ok"]:
		log.append({"kind": "build", "text": str(out["text"])})
	return out


## Forages the nodes beside the heir (GameForage): {ok, text}. Not indoors or upstairs.
func forage() -> Dictionary:
	if space != "world":
		return {"ok": false, "text": GameForage.text("indoors")}
	if storey() > 0:
		return {"ok": false, "text": GameForage.text("upstairs")}
	var out := GameForage.forage(d, heir.x, heir.y)
	if out["ok"]:
		log.append({"kind": "forage", "text": str(out["text"])})
	return out


## Digs the cell `depth` below the surface straight under the heir (`GameMine.dig`): {ok, why, ...}.
func dig(depth: int) -> Dictionary:
	if space != "world":
		return {"ok": false, "why": _text("indoors"), "text": _text("indoors")}
	if storey() > 0:
		return {"ok": false, "why": _text("upstairs_dig"), "text": _text("upstairs_dig")}
	var out := GameMine.dig(d, GameWorldGen.MINE_SITE, heir.x, depth, heir.y)
	if out["ok"]:
		log.append({"kind": "dig", "text": _text("dug", {"depth": depth})})
	return out


## Places a piece on the tile `dx, dz` from the heir at the surface (`GameBuild.place`): {ok, text}.
func build(kind: String, dx: int, dz: int) -> Dictionary:
	if space != "world":
		return {"ok": false, "text": _text("indoors")}
	var to := heir + Vector2i(dx, dz)
	var out := GameBuild.place(d, kind, to.x, build_y(), to.y)
	if out["ok"]:
		log.append({"kind": "build", "text": str(out["text"])})
	return out


## The creatures within THREAT_NEAR tiles of the heir, as {x, z} points (the companions' threats).
func _threats() -> Array:
	var out: Array = []
	for a in creatures:
		if Vector2(float(a["x"]), float(a["z"])).distance_to(heir_point()) <= float(setting("threat_near")):
			out.append({"x": float(a["x"]), "z": float(a["z"])})
	return out


func _distance(a: Dictionary, t: Vector2i) -> float:
	return maxf(absf(float(a["x"]) - (float(t.x) + 0.5)), absf(float(a["z"]) - (float(t.y) + 0.5)))


func _key(x: int, z: int) -> String:
	return "%d,%d" % [x, z]


func _text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)
