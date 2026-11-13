## World spaces and coordinates (roadmap item 41). Every place is a space with its own id and a position, so the text
## game's map and the sandbox speak of places the same way. Ids are paths: `world` (the open world: GameWorldGen's surface
## and GameMine's ground under it), `world/<place>` for each authored place (a town or wilds is an *area* of the open world
## round its anchor tile; a dungeon is an *interior*, a space of its own behind a door on the open world),
## `world/<town>/<service>` for a town's forge, temple and the rest, `world/<home town>/house` for the family house
## (interiors of the town, each with a door on the town's cleared ground), `world/underworld/<band>` for each band of the
## mine below the open world (an *underworld* space: the first entered from the open world at the shaft's tile, each deeper
## one from the band above it), and `realm/<id>` for each realm of data/creatures/realms.json (a *realm*, entered through its
## gate on the open world). A space says its kind, its parent, the authored place it belongs to and its `door`: the tile of
## its parent where it is entered. From those, `map_tile` puts any space on the open world's map, `where` and `heir_at` say
## where the heir is, `route` turns going from one space to another into leave, walk, enter and gate steps (with room
## steps inside an interior), and `along` says where on a route a fraction of its walking is. Interiors have rooms
## (`rooms`, `room_at`, `route_rooms`) on their own floor. Pure: built from data/world/world.json, data/world/spaces.json,
## data/mining/mining.json, data/creatures/realms.json and the anchors; nothing is saved and no dice are drawn. The text
## game has no journey in progress (travel moves the heir at once), so `heir_at` is always at a place; `along` gives the
## position on any route for any fraction, ready for a journey when one exists.
class_name GameSpaces
extends RefCounted

const PATH := "res://data/world/spaces.json"
const KINDS := ["world", "area", "interior", "underworld", "realm"]
const PLACE_KINDS := ["area", "interior"]

static var _cache: Dictionary = {}
static var _spaces: Dictionary = {}   # id -> record
static var _order: Array = []


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
		_spaces = {}
		_order = []
	return _cache


static func root_id() -> String:
	return str(data()["root"]["id"])


static func _build() -> void:
	if not _spaces.is_empty():
		return
	var dat := data()
	GameData.load_all()
	var root := root_id()
	_add({"id": root, "kind": "world", "name": str(dat["root"]["name"]), "parent": "", "place": "", "door": {}, "radius": 0})
	var home := str(GameData.world["start"])
	for l in GameData.world["locations"]:
		var pid := str(l["id"])
		var a := GameWorldGen.anchor(pid)
		var kind := str(dat["kind_of_type"].get(str(l["type"]), "area"))
		var id := root + "/" + pid
		_add({"id": id, "kind": kind, "name": str(l["name"]), "parent": root, "place": pid,
			"door": {"space": root, "x": int(a["x"]), "z": int(a["z"])}, "radius": int(a.get("radius", 0)),
			"layout": pid if kind == "interior" else ""})
		for service in l.get("services", []):
			var off: Array = dat["service_doors"].get(str(service), [0, 0])
			_add({"id": id + "/" + str(service), "kind": "interior", "name": str(dat["service_names"].get(str(service), str(service).capitalize())), "parent": id, "place": pid,
				"service": str(service), "door": {"space": id, "x": int(a["x"]) + int(off[0]), "z": int(a["z"]) + int(off[1])}, "radius": 0,
				"layout": str(service)})
		if pid == home:
			var h: Dictionary = dat["house"]
			_add({"id": id + "/" + str(h["id"]), "kind": "interior", "name": str(h["name"]), "parent": id, "place": pid,
				"door": {"space": id, "x": int(a["x"]) + int(h["door"][0]), "z": int(a["z"]) + int(h["door"][1])}, "radius": 0,
				"layout": str(h["id"])})
	_build_underworld(dat)
	_build_realms(dat)


static func _build_underworld(dat: Dictionary) -> void:
	var uw: Dictionary = dat["underworld"]
	var shaft := Vector2i(int(uw["shaft"][0]), int(uw["shaft"][1]))
	var above := root_id()
	for band in uw["bands"]:
		var span := band_span(str(band))
		var id := root_id() + "/" + str(uw["id"]) + "/" + str(band)
		_add({"id": id, "kind": "underworld", "name": str(span["name"]), "parent": above, "place": "", "band": str(band),
			"depth": {"from": int(span["from"]), "to": int(span["to"])},
			"door": {"space": above, "x": shaft.x, "z": shaft.y}, "radius": 0})
		above = id


static func _build_realms(dat: Dictionary) -> void:
	var gates: Dictionary = dat["realm_gates"]
	var root := root_id()
	for r in GameRealms.ids():
		var has_gate := gates.has(r)
		var door := {}
		if has_gate:
			door = {"space": root, "x": int(gates[r][0]), "z": int(gates[r][1])}
		_add({"id": "realm/" + str(r), "kind": "realm", "name": GameRealms.name_of(str(r)), "parent": root if has_gate else "",
			"place": "", "realm": str(r), "door": door, "radius": 0})


static func _add(record: Dictionary) -> void:
	_spaces[record["id"]] = record
	_order.append(record["id"])


## The way from one space to another across the open world along a road of the text game: a walk between the two places'
## tiles, with the years the road takes. {} when there is no such road.
static func road_walk(from_place: String, to_place: String) -> Dictionary:
	GameData.load_all()
	for link in GameWorld.place(from_place).get("links", []):
		if str(link["to"]) == to_place:
			var a := map_tile(of_place(from_place))
			var b := map_tile(of_place(to_place))
			return {"step": "walk", "space": root_id(), "from": [a.x, a.y], "to": [b.x, b.y], "tiles": tiles_between(a, b), "years": float(link["years"])}
	return {}


## The depth a mining zone covers, as {name, from, to}: from its first cell down to the cell above the next zone (or the
## mine's deepest cell). {} when the mine has no such zone.
static func band_span(zone: String) -> Dictionary:
	var zones: Array = GameMine.data()["zones"]
	var deepest := int(GameMine.setting("max_depth"))
	for i in zones.size():
		if str(zones[i]["id"]) == zone:
			var to := deepest
			if i + 1 < zones.size():
				to = int(zones[i + 1]["from"]) - 1
			return {"name": str(zones[i]["name"]), "from": int(zones[i]["from"]), "to": to}
	return {}


# ---------------------------------------------------------------- spaces

## Every space id, the open world first, then each place with its interiors after it.
static func ids() -> Array:
	_build()
	return _order.duplicate()


static func has(id: String) -> bool:
	_build()
	return _spaces.has(id)


## A space: {id, kind (world, area, interior, underworld or realm), name, parent, place, door: {space, x, z}, radius,
## service?, layout?, band? and depth? ({from, to}, for an underworld band), realm? (for a realm)}; {} when unknown.
static func space(id: String) -> Dictionary:
	_build()
	return _spaces.get(id, {})


static func kind(id: String) -> String:
	return str(space(id).get("kind", ""))


static func parent(id: String) -> String:
	return str(space(id).get("parent", ""))


static func children(id: String) -> Array:
	_build()
	return _order.filter(func(s): return str(_spaces[s]["parent"]) == id)


## From a space up to the open world, itself first.
static func chain(id: String) -> Array:
	var out: Array = []
	var at := id
	while at != "" and has(at) and out.size() < 16:
		out.append(at)
		at = parent(at)
	return out


## The space of an authored place (a town, a stretch of wilds, a dungeon); "" when it is not one.
static func of_place(place_id: String) -> String:
	var id := root_id() + "/" + place_id
	return id if has(id) else ""


## The space of a service in a town, or "" when the town has none.
static func of_service(place_id: String, service: String) -> String:
	var id := root_id() + "/" + place_id + "/" + service
	return id if has(id) else ""


## The family house's space.
static func house() -> String:
	GameData.load_all()
	return root_id() + "/" + str(GameData.world["start"]) + "/" + str(data()["house"]["id"])


## The space of a realm (`realm/<id>`); "" when there is no such realm.
static func of_realm(realm_id: String) -> String:
	var id := "realm/" + realm_id
	return id if has(id) else ""


## The authored place a space belongs to ("" for the open world itself).
static func place_of(id: String) -> String:
	return str(space(id).get("place", ""))


## Where a space is on the open world's map: the tile of its door, or of the door of the area it stands in. (-1, -1)
## for a space that is nowhere on it: the open world itself, the home realm, a space that does not exist.
static func map_tile(id: String) -> Vector2i:
	var s := space(id)
	if s.is_empty() or (s["door"] as Dictionary).is_empty():
		return Vector2i(-1, -1)
	return Vector2i(int(s["door"]["x"]), int(s["door"]["z"]))


## The space a tile of the open world is in: the area whose ground it stands on, else the open world.
static func at_tile(x: int, z: int) -> String:
	_build()
	var best := root_id()
	var best_d := 1e18
	for id in _order:
		var s: Dictionary = _spaces[id]
		if str(s["kind"]) != "area" or int(s["radius"]) <= 0:
			continue
		var dist := Vector2(x - int(s["door"]["x"]), z - int(s["door"]["z"])).length()
		if dist <= float(s["radius"]) and dist < best_d:
			best_d = dist
			best = id
	return best


## Where the heir is, in the sandbox's terms: {space, place, x, z}, from the text game's location.
static func where(d: GameDynasty) -> Dictionary:
	var place := str(d.world.location)
	var id := of_place(place)
	var tile := map_tile(id)
	return {"space": id, "place": place, "x": tile.x, "z": tile.y}


## Where the heir is as a position: {space, x, z, on_route}. At a place it is that place's space at its door tile (as
## `where` says), and never on a route: the text game holds no journey in progress (travel moves the heir at once).
static func heir_at(d: GameDynasty) -> Dictionary:
	var w := where(d)
	return {"space": w["space"], "x": w["x"], "z": w["z"], "on_route": false}


# ---------------------------------------------------------------- rooms

## The layout an interior uses, as its rooms and doors ({} for a space that is not an interior).
static func _layout(id: String) -> Dictionary:
	if kind(id) != "interior":
		return {}
	return data()["rooms"].get(str(space(id).get("layout", "")), {})


## The rooms of an interior: [{id, name, rect: [x, z, width, height], entrance?}], in tiles on its own floor (x east, z
## south, origin at its door). [] for a space that is not an interior.
static func rooms(id: String) -> Array:
	return _layout(id).get("rooms", []).duplicate(true)


## The room an interior's floor tile is in, or "" when it is in none.
static func room_at(id: String, x: int, z: int) -> String:
	for r in rooms(id):
		if _in_rect(r["rect"], x, z):
			return str(r["id"])
	return ""


## The room an interior is entered into ("" when it has none).
static func entrance_room(id: String) -> String:
	for r in rooms(id):
		if r.get("entrance", false) == true:
			return str(r["id"])
	return ""


## The doors from one room of an interior to another, in the order they are passed: [{from, to, at}]. Fewest doors, found
## breadth first. [] when the rooms are the same, or either does not exist, or they cannot be reached from each other.
static func route_rooms(id: String, from_room: String, to_room: String) -> Array:
	var out: Array = []
	var known := {}
	for r in rooms(id):
		known[str(r["id"])] = true
	if from_room == to_room or not known.has(from_room) or not known.has(to_room):
		return out
	var prev := {from_room: {}}
	var queue: Array = [from_room]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for door in _layout(id).get("doors", []):
			var other := ""
			if str(door["from"]) == cur:
				other = str(door["to"])
			elif str(door["to"]) == cur:
				other = str(door["from"])
			else:
				continue
			if prev.has(other):
				continue
			prev[other] = {"from": cur, "to": other, "at": door["at"]}
			queue.append(other)
	if not prev.has(to_room):
		return out
	var at := to_room
	while at != from_room:
		out.push_front(prev[at])
		at = str(prev[at]["from"])
	return out


static func _in_rect(rect: Array, x: int, z: int) -> bool:
	return x >= int(rect[0]) and x < int(rect[0]) + int(rect[2]) and z >= int(rect[1]) and z < int(rect[1]) + int(rect[3])


# ---------------------------------------------------------------- going from one to another

## The way from one space to another as steps. `leave` takes the heir out of a space by its door, `enter` takes it in,
## `gate` takes it through a realm's gate (`way` "in" or "out", with `realm` and the story `flag` that opens it), and
## `walk` crosses ground: {step: "walk", space, from: [x, z], to: [x, z], tiles} on the open world (or a town's), or
## {step: "walk", space, from, to, cells, depth: [from, to]} down or up a shaft, or {step: "walk", space, from_room,
## to_room, doors, path} across an interior's floor. Up from the first space to the one they share, a walk between the
## two doors there, and down into the second. `from_room` and `to_room` (rooms of the interiors the route starts or ends
## in) add a walk across that floor to its entrance, or from its entrance to the room. Empty when either is unknown or
## they are the same.
static func route(from_id: String, to_id: String, from_room: String = "", to_room: String = "") -> Array:
	var out: Array = []
	if from_id == to_id or not has(from_id) or not has(to_id):
		return out
	var up := chain(from_id)
	var down := chain(to_id)
	var shared := ""
	for s in up:
		if down.has(s):
			shared = str(s)
			break
	if shared == "":
		return out
	var at := Vector2i(-1, -1)
	var depth := -1   # the heir's depth down a shaft, -1 when it is not in one
	if kind(from_id) == "underworld":
		depth = _top(from_id)
	if from_room != "" and kind(from_id) == "interior" and shared != from_id:
		var lead := _room_walk(from_id, from_room, entrance_room(from_id))
		if not lead.is_empty():
			out.append(lead)
	for s in up:
		if s == shared:
			break
		if kind(s) == "underworld":
			if depth != _top(s):
				out.append(_shaft_walk(s, depth, _top(s)))
			depth = _top(s)
		if kind(s) == "realm":
			out.append(_gate(s, "out"))
		else:
			out.append({"step": "leave", "space": s})
		at = map_tile(str(s))
		if kind(parent(str(s))) != "underworld":
			depth = -1
	var descent: Array = []
	for s in down:
		if s == shared:
			break
		descent.push_front(s)
	if not descent.is_empty():
		var first := map_tile(str(descent[0]))
		if at != Vector2i(-1, -1) and at != first:
			out.append(_tile_walk(shared, at, first))
	elif kind(shared) == "underworld" and depth != -1 and depth != _top(shared):
		out.append(_shaft_walk(shared, depth, _top(shared)))
	for i in descent.size():
		var c := str(descent[i])
		var door := map_tile(c)
		if i > 0:
			var prev_door := map_tile(str(descent[i - 1]))
			if prev_door != door:
				out.append(_tile_walk(str(descent[i - 1]), prev_door, door))
		if kind(c) == "underworld":
			var p := parent(c)
			if kind(p) == "underworld" and depth != _top(c):
				out.append(_shaft_walk(p, depth, _top(c)))
			depth = _top(c)
		if kind(c) == "realm":
			out.append(_gate(c, "in"))
		else:
			out.append({"step": "enter", "space": c})
	if to_room != "" and not descent.is_empty() and str(descent.back()) == to_id and kind(to_id) == "interior":
		var inner := _room_walk(to_id, entrance_room(to_id), to_room)
		if not inner.is_empty():
			out.append(inner)
	return out


static func _top(id: String) -> int:
	return int(space(id).get("depth", {}).get("from", -1))


static func _tile_walk(space_id: String, a: Vector2i, b: Vector2i) -> Dictionary:
	return {"step": "walk", "space": space_id, "from": [a.x, a.y], "to": [b.x, b.y], "tiles": tiles_between(a, b)}


## A walk down or up the shaft through an underworld band: the shaft's tile, `cells` apart in depth.
static func _shaft_walk(band: String, from_depth: int, to_depth: int) -> Dictionary:
	var t := map_tile(band)
	return {"step": "walk", "space": band, "from": [t.x, t.y], "to": [t.x, t.y], "cells": absi(to_depth - from_depth), "depth": [from_depth, to_depth]}


static func _room_walk(id: String, from_room: String, to_room: String) -> Dictionary:
	var path := route_rooms(id, from_room, to_room)
	if path.is_empty():
		return {}
	return {"step": "walk", "space": id, "from_room": from_room, "to_room": to_room, "doors": path.size(), "path": path}


static func _gate(id: String, way: String) -> Dictionary:
	var realm := str(space(id).get("realm", ""))
	return {"step": "gate", "space": id, "realm": realm, "way": way, "flag": GameRealms.gate_flag(realm)}


## How far apart two tiles are, as the crow flies, in whole tiles.
static func tiles_between(a: Vector2i, b: Vector2i) -> int:
	return int(round(Vector2(a - b).length()))


## Whether every gate a route passes is open for the dynasty (GameRealms.gate_open). A route with no gate is open.
static func gates_open(d: GameDynasty, route_steps: Array) -> bool:
	for s in route_steps:
		if str(s["step"]) == "gate" and not GameRealms.gate_open(d, str(s["realm"])):
			return false
	return true


## The position a fraction of the way along a route is: {space, x, z, on_route: true}, with `depth` in a shaft and `room`
## on an interior's floor. Only walks take any way: the fraction is of the walking the route does (tiles on the open world,
## cells down a shaft, one tile per door on a floor), and the gates and doors between walks are where the walking meets
## them. A route with no walking is at its first step for a fraction under a half and at its last otherwise. {} for an
## empty route.
static func along(route_steps: Array, fraction: float) -> Dictionary:
	if route_steps.is_empty():
		return {}
	var f := clampf(fraction, 0.0, 1.0)
	var total := 0.0
	for s in route_steps:
		total += _walk_length(s)
	if total <= 0.0:
		return _step_spot(route_steps[0] if f < 0.5 else route_steps.back())
	var target := f * total
	var acc := 0.0
	for s in route_steps:
		var n := _walk_length(s)
		if n <= 0.0:
			continue
		if target <= acc + n:
			return _walk_spot(s, clampf((target - acc) / n, 0.0, 1.0))
		acc += n
	return _step_spot(route_steps.back())


static func _walk_length(s: Dictionary) -> float:
	if str(s["step"]) != "walk":
		return 0.0
	if s.has("cells"):
		return float(s["cells"])
	if s.has("doors"):
		return float(s["doors"])
	return float(s["tiles"])


static func _walk_spot(s: Dictionary, t: float) -> Dictionary:
	if s.has("path"):
		var path: Array = s["path"]
		var k := clampi(int(floor(t * path.size())), 0, path.size() - 1)
		var door: Dictionary = path[k]
		return {"space": s["space"], "x": int(door["at"][0]), "z": int(door["at"][1]), "room": str(door["to"]), "on_route": true}
	var a: Array = s["from"]
	var b: Array = s["to"]
	var out := {"space": s["space"], "x": int(round(lerpf(float(a[0]), float(b[0]), t))), "z": int(round(lerpf(float(a[1]), float(b[1]), t))), "on_route": true}
	if s.has("depth"):
		out["depth"] = int(round(lerpf(float(s["depth"][0]), float(s["depth"][1]), t)))
	return out


## The spot of a step that is not a walk: a space's door, in the space it is entered from (its parent).
static func _step_spot(s: Dictionary) -> Dictionary:
	if str(s["step"]) == "walk":
		return _walk_spot(s, 0.0)
	var id := str(s["space"])
	var t := map_tile(id)
	var out := {"space": parent(id), "x": t.x, "z": t.y, "on_route": true}
	if kind(id) == "underworld":
		out["depth"] = _top(id)
	return out


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = data()
	for k in ["root", "kind_of_type", "service_names", "service_doors", "house", "underworld", "realm_gates", "rooms"]:
		if not dat.has(k):
			bad.append("spaces.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	GameData.load_all()
	if str(dat["root"].get("id", "")) != GameWorldGen.MINE_SITE:
		bad.append("spaces.json: the root space must be '%s', the id the generated world and the mine already use" % GameWorldGen.MINE_SITE)
	for t in dat["kind_of_type"]:
		if not PLACE_KINDS.has(str(dat["kind_of_type"][t])):
			bad.append("spaces.json: place type '%s' must be an area or an interior" % t)
	var home := str(GameData.world["start"])
	var home_ok := false
	for l in GameData.world["locations"]:
		var pid := str(l["id"])
		if not dat["kind_of_type"].has(str(l["type"])):
			bad.append("spaces.json: place type '%s' (of %s) has no kind" % [l["type"], pid])
		if pid.contains("/"):
			bad.append("spaces.json: place id '%s' may not hold a '/': ids are paths" % pid)
		var a := GameWorldGen.anchor(pid)
		var doors := {}
		var radius := float(a.get("radius", 0))
		var inside: Array = []
		for service in l.get("services", []):
			inside.append([str(service), dat["service_doors"].get(str(service), null)])
			if not dat["service_names"].has(str(service)):
				bad.append("spaces.json: service '%s' (in %s) has no name" % [service, pid])
		if pid == home:
			home_ok = str(l["type"]) == "town"
			inside.append([str(dat["house"].get("id", "")), dat["house"].get("door", null)])
		for pair in inside:
			var off: Variant = pair[1]
			if typeof(off) != TYPE_ARRAY or (off as Array).size() != 2:
				bad.append("spaces.json: '%s' (in %s) has no door as [east, south]" % [pair[0], pid])
				continue
			var v := Vector2(float(off[0]), float(off[1]))
			if v.length() > radius:
				bad.append("spaces.json: the door of '%s' is %.1f tiles from the middle of %s, outside its cleared ground (%d)" % [pair[0], v.length(), pid, int(radius)])
			if v == Vector2.ZERO:
				bad.append("spaces.json: the door of '%s' is on the middle tile of %s, where the place itself is entered" % [pair[0], pid])
			var key := "%d,%d" % [int(off[0]), int(off[1])]
			if doors.has(key):
				bad.append("spaces.json: '%s' and '%s' share a door tile in %s" % [doors[key], pair[0], pid])
			doors[key] = pair[0]
	if not home_ok:
		bad.append("spaces.json: the family house needs a home town (world.json start '%s' is not a town)" % home)
	if str(dat["house"].get("id", "")) == "" or dat["service_doors"].has(str(dat["house"].get("id", ""))):
		bad.append("spaces.json: the house needs an id that is not a service's")
	bad.append_array(_validate_underworld(dat))
	bad.append_array(_validate_realms(dat))
	bad.append_array(_validate_rooms(dat))
	return bad


static func _pair_ok(v: Variant) -> bool:
	if typeof(v) != TYPE_ARRAY or (v as Array).size() != 2:
		return false
	for n in v:
		if typeof(n) != TYPE_INT and typeof(n) != TYPE_FLOAT:
			return false
	return true


static func _tile_ok(v: Variant) -> bool:
	return _pair_ok(v) and GameWorldGen.in_bounds(int(v[0]), int(v[1]))


static func _validate_underworld(dat: Dictionary) -> Array:
	var bad: Array = []
	var uw: Dictionary = dat["underworld"]
	if not _tile_ok(uw.get("shaft")):
		bad.append("spaces.json: the underworld's shaft must be a tile [x, z] of the open world")
	elif GameWorldGen.in_anchor_ground(int(uw["shaft"][0]), int(uw["shaft"][1])):
		bad.append("spaces.json: the underworld's shaft is on a place's cleared ground")
	var zone_ids: Array = []
	for z in GameMine.data()["zones"]:
		zone_ids.append(str(z["id"]))
	var bands: Array = uw.get("bands", [])
	if bands.is_empty():
		bad.append("spaces.json: the underworld needs at least one band (a mining zone)")
	var last := -1
	for b in bands:
		var i := zone_ids.find(str(b))
		if i < 0:
			bad.append("spaces.json: underworld band '%s' is not a zone of mining.json" % b)
			continue
		if i == 0:
			bad.append("spaces.json: underworld band '%s' is the surface zone, which is the open world's own ground" % b)
		if i <= last:
			bad.append("spaces.json: underworld bands must go deeper in order (%s)" % b)
		last = i
	return bad


static func _validate_realms(dat: Dictionary) -> Array:
	var bad: Array = []
	var gates: Dictionary = dat["realm_gates"]
	var home := GameRealms.home()
	var seen := {}
	if _tile_ok(dat["underworld"].get("shaft")):
		var sh: Array = dat["underworld"]["shaft"]
		seen["%d,%d" % [int(sh[0]), int(sh[1])]] = "the underworld's shaft"
	for r in gates:
		if not GameRealms.has(str(r)):
			bad.append("spaces.json: realm_gates names '%s', which is not a realm in realms.json" % r)
			continue
		if str(r) == home:
			bad.append("spaces.json: the home realm (%s) has no gate" % home)
			continue
		if not _tile_ok(gates[r]):
			bad.append("spaces.json: the gate of '%s' must be a tile [x, z] of the open world" % r)
			continue
		if GameWorldGen.in_anchor_ground(int(gates[r][0]), int(gates[r][1])):
			bad.append("spaces.json: the gate of '%s' is on a place's cleared ground" % r)
		var key := "%d,%d" % [int(gates[r][0]), int(gates[r][1])]
		if seen.has(key):
			bad.append("spaces.json: the gate of '%s' and %s share a tile" % [r, seen[key]])
		seen[key] = "the gate of '%s'" % r
	for r in GameRealms.ids():
		if str(r) != home and not gates.has(r):
			bad.append("spaces.json: realm '%s' has no gate tile in realm_gates" % r)
	return bad


static func _rect_ok(v: Variant) -> bool:
	if typeof(v) != TYPE_ARRAY or (v as Array).size() != 4:
		return false
	for n in v:
		if typeof(n) != TYPE_INT and typeof(n) != TYPE_FLOAT:
			return false
	return int(v[2]) >= 1 and int(v[3]) >= 1


static func _validate_rooms(dat: Dictionary) -> Array:
	var bad: Array = []
	var layouts: Dictionary = dat["rooms"]
	var needed := {}
	for l in GameData.world["locations"]:
		if str(dat["kind_of_type"].get(str(l["type"]), "")) == "interior":
			needed[str(l["id"])] = true
		for s in l.get("services", []):
			needed[str(s)] = true
	needed[str(dat["house"].get("id", ""))] = true
	for k in needed:
		if not layouts.has(k):
			bad.append("spaces.json: the interior '%s' has no rooms" % k)
	for k in layouts:
		if not needed.has(str(k)):
			bad.append("spaces.json: rooms are given for '%s', which is no interior's layout" % k)
		else:
			bad.append_array(_check_layout(str(k), layouts[k]))
	return bad


static func _check_layout(key: String, lay: Variant) -> Array:
	var bad: Array = []
	var tag := "spaces.json: the rooms of '%s'" % key
	if typeof(lay) != TYPE_DICTIONARY or typeof(lay.get("rooms")) != TYPE_ARRAY or typeof(lay.get("doors")) != TYPE_ARRAY:
		bad.append("%s need a rooms list and a doors list" % tag)
		return bad
	var rooms_list: Array = lay["rooms"]
	if rooms_list.is_empty() or rooms_list.size() > 4:
		bad.append("%s must be one to four rooms" % tag)
	var by_id := {}
	var entrances := 0
	var overlaps := false
	var valid: Array = []
	for r in rooms_list:
		if typeof(r) != TYPE_DICTIONARY or str(r.get("id", "")) == "":
			bad.append("%s: a room has no id" % tag)
			continue
		var rid := str(r["id"])
		if by_id.has(rid):
			bad.append("%s: room '%s' is listed twice" % [tag, rid])
		by_id[rid] = r
		if not _rect_ok(r.get("rect")):
			bad.append("%s: room '%s' needs a rect [x, z, width, height] of whole tiles, each side at least one" % [tag, rid])
			continue
		valid.append(r)
		if r.get("entrance", false) == true:
			entrances += 1
			if not _in_rect(r["rect"], 0, 0):
				bad.append("%s: the entrance room '%s' must hold the door's tile (0, 0)" % [tag, rid])
	if entrances != 1:
		bad.append("%s must have exactly one entrance room (it has %d)" % [tag, entrances])
	for i in valid.size():
		for j in range(i + 1, valid.size()):
			var a: Array = valid[i]["rect"]
			var b: Array = valid[j]["rect"]
			if int(a[0]) < int(b[0]) + int(b[2]) and int(b[0]) < int(a[0]) + int(a[2]) and int(a[1]) < int(b[1]) + int(b[3]) and int(b[1]) < int(a[1]) + int(a[3]):
				overlaps = true
				bad.append("%s: rooms '%s' and '%s' overlap" % [tag, valid[i]["id"], valid[j]["id"]])
	var adj := {}
	for door in lay["doors"]:
		if typeof(door) != TYPE_DICTIONARY or not door.has("from") or not door.has("to"):
			bad.append("%s: a door needs a from and a to" % tag)
			continue
		var a_id := str(door["from"])
		var b_id := str(door["to"])
		if not by_id.has(a_id) or not by_id.has(b_id):
			bad.append("%s: a door joins '%s' and '%s', and one of them is no room" % [tag, a_id, b_id])
			continue
		if a_id == b_id:
			bad.append("%s: a door joins room '%s' to itself" % [tag, a_id])
			continue
		if not _pair_ok(door.get("at")):
			bad.append("%s: the door between '%s' and '%s' needs its tile [x, z]" % [tag, a_id, b_id])
			continue
		var at: Vector2i = Vector2i(int(door["at"][0]), int(door["at"][1]))
		var ra: Array = by_id[a_id].get("rect", [])
		var rb: Array = by_id[b_id].get("rect", [])
		if not _rect_ok(ra) or not _rect_ok(rb):
			continue
		var inside := false
		for r in valid:
			if _in_rect(r["rect"], at.x, at.y):
				inside = true
		if inside:
			bad.append("%s: the door between '%s' and '%s' is inside a room" % [tag, a_id, b_id])
		elif not (_touches(ra, at) and _touches(rb, at)):
			bad.append("%s: the door at (%d, %d) does not join '%s' and '%s'" % [tag, at.x, at.y, a_id, b_id])
		adj[a_id] = adj.get(a_id, []) + [b_id]
		adj[b_id] = adj.get(b_id, []) + [a_id]
	if entrances == 1 and not overlaps:
		var entrance := ""
		for rid in by_id:
			if by_id[rid].get("entrance", false) == true:
				entrance = rid
		var seen := {entrance: true}
		var queue: Array = [entrance]
		while not queue.is_empty():
			var cur: String = queue.pop_front()
			for nxt in adj.get(cur, []):
				if not seen.has(nxt):
					seen[nxt] = true
					queue.append(nxt)
		for rid in by_id:
			if not seen.has(rid):
				bad.append("%s: room '%s' cannot be reached from the entrance" % [tag, rid])
	return bad


## Whether a tile is next to a room's floor (one step north, south, east or west of one of its tiles).
static func _touches(rect: Array, t: Vector2i) -> bool:
	return _in_rect(rect, t.x - 1, t.y) or _in_rect(rect, t.x + 1, t.y) or _in_rect(rect, t.x, t.y - 1) or _in_rect(rect, t.x, t.y + 1)
