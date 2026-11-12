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
	s.heir = t
	s.companions = GameCompanions.agents_for(dyn, float(t.x) + 0.5, float(t.y) + 0.5)
	s.refresh()
	return s


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


func heir_point() -> Vector2:
	return Vector2(float(heir.x) + 0.5, float(heir.y) + 0.5)


## Whether the heir can step onto a tile: a neighbour in the open world, dry and not blocked (a tree, a rock outcrop, a wall).
func can_step(dx: int, dz: int) -> Dictionary:
	if absi(dx) > 1 or absi(dz) > 1 or (dx == 0 and dz == 0):
		return {"ok": false, "why": _text("not_a_step")}
	var to := heir + Vector2i(dx, dz)
	if not GameWorldGen.in_bounds(to.x, to.y):
		return {"ok": false, "why": _text("edge")}
	var ground := GamePath.world_ground(d)
	if not GamePath.passable(ground, Vector3i(to.x, -1, to.y), {"water": false, "ignore_blocks": false}):
		return {"ok": false, "why": _text("blocked")}
	return {"ok": true, "why": ""}


## The heir takes one step. The creatures and companions catch up with the new place.
func move(dx: int, dz: int) -> Dictionary:
	var c := can_step(dx, dz)
	if not c["ok"]:
		return c
	heir += Vector2i(dx, dz)
	refresh()
	return {"ok": true, "why": ""}


## Spawns the creatures the world has in the square round the heir and lets go of those far behind.
func refresh() -> void:
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


## One tick of the open world: the creatures act, then the companions (told of the creatures near them), and their events
## go to the log.
func step(ticks: int = 1) -> void:
	for _i in ticks:
		tick += 1
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


## Digs the cell `depth` below the surface straight under the heir (`GameMine.dig`): {ok, why, ...}.
func dig(depth: int) -> Dictionary:
	var out := GameMine.dig(d, GameWorldGen.MINE_SITE, heir.x, depth, heir.y)
	if out["ok"]:
		log.append({"kind": "dig", "text": _text("dug", {"depth": depth})})
	return out


## Places a piece on the tile `dx, dz` from the heir at the surface (`GameBuild.place`): {ok, text}.
func build(kind: String, dx: int, dz: int) -> Dictionary:
	var to := heir + Vector2i(dx, dz)
	var out := GameBuild.place(d, kind, to.x, -1, to.y)
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
