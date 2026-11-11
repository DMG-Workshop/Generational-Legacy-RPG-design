## World spaces and coordinates (roadmap item 41). Every place is a space with its own id and a position, so the text
## game's map and the sandbox speak of places the same way. Ids are paths: `world` (the open world: GameWorldGen's
## surface and GameMine's ground under it), `world/<place>` for each authored place (a town or wilds is an *area* of
## the open world round its anchor tile; a dungeon is an *interior*, a space of its own behind a door on the open
## world), `world/<town>/<service>` for a town's forge, temple and the rest, and `world/<home town>/house` for the
## family house (interiors of the town, each with a door on the town's cleared ground). A space says its kind, its
## parent, the authored place it belongs to and its `door`: the tile of its parent where it is entered. From those,
## `map_tile` puts any space on the open world's map, `where` says where the heir is, and `route` turns going from
## one space to another into leaving, walking and entering. Pure: built from data/world/world.json,
## data/world/spaces.json and the anchors; nothing is saved and no dice are drawn.
class_name GameSpaces
extends RefCounted

const PATH := "res://data/world/spaces.json"
const KINDS := ["world", "area", "interior"]

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
			"door": {"space": root, "x": int(a["x"]), "z": int(a["z"])}, "radius": int(a.get("radius", 0))})
		for service in l.get("services", []):
			var off: Array = dat["service_doors"].get(str(service), [0, 0])
			_add({"id": id + "/" + str(service), "kind": "interior", "name": str(dat["service_names"].get(str(service), str(service).capitalize())), "parent": id, "place": pid,
				"service": str(service), "door": {"space": id, "x": int(a["x"]) + int(off[0]), "z": int(a["z"]) + int(off[1])}, "radius": 0})
		if pid == home:
			var h: Dictionary = dat["house"]
			_add({"id": id + "/" + str(h["id"]), "kind": "interior", "name": str(h["name"]), "parent": id, "place": pid,
				"door": {"space": id, "x": int(a["x"]) + int(h["door"][0]), "z": int(a["z"]) + int(h["door"][1])}, "radius": 0})


static func _add(record: Dictionary) -> void:
	_spaces[record["id"]] = record
	_order.append(record["id"])


# ---------------------------------------------------------------- spaces

## Every space id, the open world first, then each place with its interiors after it.
static func ids() -> Array:
	_build()
	return _order.duplicate()


static func has(id: String) -> bool:
	_build()
	return _spaces.has(id)


## A space: {id, kind (world, area or interior), name, parent, place, door: {space, x, z}, radius, service?}; {} when unknown.
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


## The authored place a space belongs to ("" for the open world itself).
static func place_of(id: String) -> String:
	return str(space(id).get("place", ""))


## Where a space is on the open world's map: the tile of its door, or of the door of the area it stands in.
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


# ---------------------------------------------------------------- going from one to another

## The way from one space to another as steps: {step: "leave", space}, {step: "walk", space, from: [x, z], to: [x, z],
## tiles} and {step: "enter", space}. Up from the first to the space they share, a walk between the two doors there,
## and down into the second. Empty when either is unknown or they are the same.
static func route(from_id: String, to_id: String) -> Array:
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
	for s in up:
		if s == shared:
			break
		out.append({"step": "leave", "space": s})
		at = map_tile(str(s))
	var descent: Array = []
	for s in down:
		if s == shared:
			break
		descent.push_front(s)
	if not descent.is_empty():
		var first := map_tile(str(descent[0]))
		if at != Vector2i(-1, -1) and at != first:
			out.append({"step": "walk", "space": shared, "from": [at.x, at.y], "to": [first.x, first.y], "tiles": tiles_between(at, first)})
		for i in descent.size():
			var door := map_tile(str(descent[i]))
			if i > 0:
				var prev := map_tile(str(descent[i - 1]))
				if prev != door:
					out.append({"step": "walk", "space": descent[i - 1], "from": [prev.x, prev.y], "to": [door.x, door.y], "tiles": tiles_between(prev, door)})
			out.append({"step": "enter", "space": descent[i]})
	return out


## How far apart two tiles are, as the crow flies, in whole tiles.
static func tiles_between(a: Vector2i, b: Vector2i) -> int:
	return int(round(Vector2(a - b).length()))


## The steps of a journey between two authored places along the text game's roads: each road is a walk on the open
## world between the two places' tiles. [] when there is no road.
static func road_walk(from_place: String, to_place: String) -> Dictionary:
	GameData.load_all()
	for link in GameWorld.place(from_place).get("links", []):
		if str(link["to"]) == to_place:
			var a := map_tile(of_place(from_place))
			var b := map_tile(of_place(to_place))
			return {"step": "walk", "space": root_id(), "from": [a.x, a.y], "to": [b.x, b.y], "tiles": tiles_between(a, b), "years": float(link["years"])}
	return {}


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = data()
	for k in ["root", "kind_of_type", "service_names", "service_doors", "house"]:
		if not dat.has(k):
			bad.append("spaces.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	GameData.load_all()
	if str(dat["root"].get("id", "")) != GameWorldGen.MINE_SITE:
		bad.append("spaces.json: the root space must be '%s', the id the generated world and the mine already use" % GameWorldGen.MINE_SITE)
	for t in dat["kind_of_type"]:
		if not KINDS.has(str(dat["kind_of_type"][t])) or str(dat["kind_of_type"][t]) == "world":
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
	return bad
