## People inside rooms (roadmap item 41; data/world/people.json). Each service interior has a person at a fixed cell of its
## entrance room. They are solid (GameInterior.cells marks the cell `person`); the heir talks to the one beside them and, when
## the family is in that interior's town, the service opens (the screen reads `open` and `tab`). Pure: nothing random, nothing
## saved.
class_name GamePeople
extends RefCounted

const OPENS := ["shop", "workshop", "tavern", "board"]
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json("res://data/world/people.json")
	return _cache


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


## The people of an interior (its layout's), as the data rows. [] for a space with none.
static func in_space(space_id: String) -> Array:
	var layout := str(GameSpaces.space(space_id).get("layout", ""))
	var out: Array = []
	for p in data()["people"]:
		if str(p["layout"]) == layout:
			out.append(p)
	return out


static func cell_of(p: Dictionary) -> Vector2i:
	return Vector2i(int(p["at"][0]), int(p["at"][1]))


## The person standing on a cell of an interior, or {}.
static func at(space_id: String, x: int, z: int) -> Dictionary:
	for p in in_space(space_id):
		if cell_of(p) == Vector2i(x, z):
			return p
	return {}


## The person on a cell beside (x, z), or {}.
static func near(space_id: String, x: int, z: int) -> Dictionary:
	for dir in DIRS:
		var p := at(space_id, x + dir.x, z + dir.y)
		if not p.is_empty():
			return p
	return {}


## Talking to a person: {ok, text, open, tab}. `open` is "" unless the family is in the interior's own town and that town has
## the service, then one of OPENS.
static func talk(d: GameDynasty, space_id: String, p: Dictionary) -> Dictionary:
	if p.is_empty():
		return {"ok": false, "text": text("nobody"), "open": "", "tab": ""}
	var here := str(GameSpaces.space(space_id).get("place", "")) == d.world.location
	var service := str(GameSpaces.space(space_id).get("service", ""))
	if not here or service == "" or not d.world.has_service(service):
		return {"ok": true, "text": text("only_talk", {"name": str(p["name"])}), "open": "", "tab": ""}
	return {"ok": true, "text": text("talk", {"greet": str(p["greet"])}), "open": str(p["open"]), "tab": str(p["tab"])}


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["people", "text"]:
		if not dat.has(k):
			bad.append("people.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	for k in ["talk", "only_talk", "near", "nobody"]:
		if not dat["text"].has(k):
			bad.append("people.json: text.%s is missing" % k)
	var seen := {}
	var layouts := {}
	for p in dat["people"]:
		for k in ["layout", "id", "name", "at", "open", "tab", "greet"]:
			if not p.has(k):
				bad.append("people.json: a person has no %s" % k)
		if not bad.is_empty():
			return bad
		var id := "%s/%s" % [p["layout"], p["id"]]
		if seen.has(id):
			bad.append("people.json: '%s' twice" % id)
		seen[id] = true
		if layouts.has(str(p["layout"])):
			bad.append("people.json: layout '%s' has more than one person" % p["layout"])
		layouts[str(p["layout"])] = true
		if str(p["open"]) not in OPENS:
			bad.append("people.json: '%s' opens '%s', which is not one of %s" % [id, p["open"], str(OPENS)])
		if str(p["open"]) == "shop" and str(p["tab"]) not in ["forge", "store", "temple", "black_market"]:
			bad.append("people.json: '%s' opens a shop tab '%s' that does not exist" % [id, p["tab"]])
		if not GameSpaces.data()["rooms"].has(str(p["layout"])):
			bad.append("people.json: '%s' stands in no known layout" % id)
			continue
		# on a floor cell of the entrance room, away from the origin (the way out) and from doors
		var layout: Dictionary = GameSpaces.data()["rooms"][str(p["layout"])]
		var c := cell_of(p)
		var in_entrance := false
		for r in layout["rooms"]:
			if bool(r.get("entrance", false)):
				var rect: Array = r["rect"]
				if c.x >= int(rect[0]) and c.x < int(rect[0]) + int(rect[2]) and c.y >= int(rect[1]) and c.y < int(rect[1]) + int(rect[3]):
					in_entrance = true
		if not in_entrance:
			bad.append("people.json: '%s' does not stand in the entrance room" % id)
		if c == GameInterior.entry():
			bad.append("people.json: '%s' stands on the way out" % id)
		for door in layout["doors"]:
			if Vector2i(int(door["at"][0]), int(door["at"][1])).distance_to(Vector2(c)) <= 1.0:
				bad.append("people.json: '%s' stands in a doorway or beside one" % id)
	return bad
