## What stands in a town of the open world: a building for each of its services behind the door the heir uses, the family
## house in the home town, and a few plain houses. A building is a body of tiles that blocks a walker as a tree does
## (GamePath's ground asks `blocks`); its door is the tile in front of its bottom middle, which is the service's own door
## tile in GameSpaces. Pure functions of the data and the place: no dice, nothing saved. Data: data/world/towns.json.
class_name GameTown
extends RefCounted

const PATH := "res://data/world/towns.json"

static var _cache: Dictionary = {}
static var _all: Array = []
static var _index: Dictionary = {}   # "x,z" -> index into _all, for each tile of a body


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
		_all = []
		_index = {}
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


## The towns that have buildings: the places of the town type (the ones with cleared ground round their anchor).
static func towns() -> Array:
	var out: Array = []
	for a in GameWorldGen.anchors():
		if str(a["type"]) == "town" and int(a["radius"]) > 0:
			out.append(str(a["id"]))
	return out


## Every building of every town: {id, kind, place, x, z, w, h, door (Vector2i, the tile in front of it), style}. `kind` is a
## service's name (forge, temple, store, tavern, board, black_market), "family" or "house".
static func all() -> Array:
	if _all.is_empty():
		_build()
	return _all


static func buildings(place_id: String) -> Array:
	var out: Array = []
	for b in all():
		if str(b["place"]) == place_id:
			out.append(b)
	return out


## The size in tiles (w, h) of a building of `kind`: `sizes` in towns.json, else the default `w` by `h`. Buildings differ in size,
## a hut being small and a temple or the family house large; the door is always the tile in front of the bottom middle.
static func size_of(kind: String) -> Vector2i:
	var sizes: Dictionary = data().get("sizes", {})
	if sizes.has(kind):
		return Vector2i(int(sizes[kind][0]), int(sizes[kind][1]))
	return Vector2i(int(setting("w")), int(setting("h")))


static func _build() -> void:
	var home := str(GameData.world["start"])
	for place in towns():
		var a := GameWorldGen.anchor(place)
		var ax := int(a["x"])
		var az := int(a["z"])
		var n := 0
		for id in GameSpaces.ids():
			var s := GameSpaces.space(id)
			if str(s.get("place", "")) != place or str(s["kind"]) != "interior" or str(s["parent"]) != GameSpaces.root_id() + "/" + place:
				continue
			var kind := str(s.get("service", ""))
			if kind == "":
				kind = "family" if place == home and str(s.get("layout", "")) == str(GameSpaces.data()["house"]["id"]) else ""
			if kind == "":
				continue
			var door := Vector2i(int(s["door"]["x"]), int(s["door"]["z"]))
			var size := size_of(kind)
			_add(place, kind, door.x - (size.x - 1) / 2, door.y - size.y, size.x, size.y, door, n)
			n += 1
		for off in data()["houses"]:
			var x := ax + int(off[0])
			var z := az + int(off[1])
			var w := int(off[2]) if off.size() > 2 else int(setting("w"))
			var h := int(off[3]) if off.size() > 3 else int(setting("h"))
			_add(place, "house", x, z, w, h, Vector2i(x + (w - 1) / 2, z + h), n)
			n += 1


static func _add(place: String, kind: String, x: int, z: int, w: int, h: int, door: Vector2i, n: int) -> void:
	var b := {"id": "%s/%s%d" % [place, kind, n], "kind": kind, "place": place, "x": x, "z": z, "w": w, "h": h, "door": door,
		"style": absi(hash("%s:%d" % [place, n])) % int(setting("styles"))}
	for dz in h:
		for dx in w:
			_index["%d,%d" % [x + dx, z + dz]] = _all.size()
	_all.append(b)


## Whether a tile is inside a building (a walker cannot stand there).
static func blocks(x: int, z: int) -> bool:
	all()
	return _index.has("%d,%d" % [x, z])


## The building a tile is inside, or {}.
static func at(x: int, z: int) -> Dictionary:
	all()
	var i: Variant = _index.get("%d,%d" % [x, z])
	return {} if i == null else _all[int(i)]


## The buildings with a tile inside the rectangle (tiles; position and size).
static func in_rect(rect: Rect2i) -> Array:
	var out: Array = []
	for b in all():
		if Rect2i(int(b["x"]), int(b["z"]), int(b["w"]), int(b["h"])).intersects(rect):
			out.append(b)
	return out


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "houses"]:
		if not dat.has(k):
			bad.append("towns.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var s: Dictionary = dat["settings"]
	for k in ["w", "h", "max_reach", "styles"]:
		if not s.has(k):
			bad.append("towns.json: settings.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if int(s["w"]) < 1 or int(s["h"]) < 1 or int(s["styles"]) < 1:
		bad.append("towns.json: w, h and styles are at least 1")
	var biggest := int(s.get("max_size", 6))
	for off in dat["houses"]:
		if typeof(off) != TYPE_ARRAY or (off.size() != 2 and off.size() != 4):
			bad.append("towns.json: a house is [dx, dz] or [dx, dz, w, h]")
		elif off.size() == 4 and (int(off[2]) < 1 or int(off[3]) < 1 or int(off[2]) > biggest or int(off[3]) > biggest):
			bad.append("towns.json: a house of %d by %d is not between 1 and %d tiles a side" % [int(off[2]), int(off[3]), biggest])
	var sizes: Dictionary = dat.get("sizes", {})
	for k in sizes:
		var sz: Variant = sizes[k]
		if typeof(sz) != TYPE_ARRAY or sz.size() != 2 or int(sz[0]) < 1 or int(sz[1]) < 1 or int(sz[0]) > biggest or int(sz[1]) > biggest:
			bad.append("towns.json: sizes.%s is [w, h], each 1 to %d" % [k, biggest])
	if not bad.is_empty():
		return bad
	_all = []
	_index = {}
	_build()
	var taken := {}
	var doors := {}
	for place in towns():
		var a := GameWorldGen.anchor(place)
		doors["%d,%d" % [int(a["x"]), int(a["z"])]] = "the anchor of " + place
	for b in _all:
		doors["%d,%d" % [int(b["door"].x), int(b["door"].y)]] = str(b["id"]) + "'s door"
	for b in _all:
		var a := GameWorldGen.anchor(str(b["place"]))
		for dz in int(b["h"]):
			for dx in int(b["w"]):
				var x := int(b["x"]) + dx
				var z := int(b["z"]) + dz
				var key := "%d,%d" % [x, z]
				if taken.has(key):
					bad.append("towns.json: %s and %s share the tile %s" % [b["id"], taken[key], key])
				taken[key] = str(b["id"])
				if doors.has(key):
					bad.append("towns.json: %s stands on %s" % [b["id"], doors[key]])
				if Vector2(x - int(a["x"]), z - int(a["z"])).length() > float(s["max_reach"]):
					bad.append("towns.json: %s reaches past max_reach of the anchor of %s" % [b["id"], b["place"]])
	return bad
