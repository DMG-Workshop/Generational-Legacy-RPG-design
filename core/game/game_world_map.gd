## The world map view (roadmap follow-up; data/world/worldmap.json): the open world sampled at a coarse step as a grid of kinds (a
## biome or water, the names the tile view has colours for) with a marker for each place on the map (unvisited ones marked but not
## named) and the cell the heir stands in. Pure functions of the dynasty's seed and what the family has visited: nothing is saved and
## no dice are drawn. ui/play/world_map_panel.gd draws it.
class_name GameWorldMap
extends RefCounted

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json("res://data/world/worldmap.json")
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


## Cells along one side of the picture.
static func cells() -> int:
	return int(ceil(float(GameWorldGen.size()) / float(int(setting("step")))))


## The world's tile that stands for a cell: its middle.
static func tile_of(cx: int, cz: int) -> Vector2i:
	var step := int(setting("step"))
	return Vector2i(mini(cx * step + step / 2, GameWorldGen.size() - 1), mini(cz * step + step / 2, GameWorldGen.size() - 1))


## The cell a tile falls in.
static func cell_of(x: int, z: int) -> Vector2i:
	var step := int(setting("step"))
	return Vector2i(clampi(x / step, 0, cells() - 1), clampi(z / step, 0, cells() - 1))


## The kind of one cell: "water" or the biome at its middle tile.
static func kind_at(d: GameDynasty, cx: int, cz: int) -> String:
	var t := tile_of(cx, cz)
	var body := GameWorldGen.body_at(d.seed_value, t.x, t.y)
	if body == "sea" or body == "lake":
		return "water"   # (a river is narrower than a cell: the map leaves it out)
	return GameWorldGen.biome_at(d.seed_value, t.x, t.y)


## The whole grid, rows of z each a row of x.
static func grid(d: GameDynasty) -> Array:
	var rows: Array = []
	for cz in cells():
		var row: Array = []
		for cx in cells():
			row.append(kind_at(d, cx, cz))
		rows.append(row)
	return rows


## A marker for every place on the map: {id, name, type, x, z, cell, visited, here}. An unvisited place has no name here, only the
## `unknown` line, so the map does not give away what the family has not found.
static func markers(d: GameDynasty) -> Array:
	var out: Array = []
	for a in GameWorldGen.anchors():
		var id := str(a["id"])
		var visited: bool = id in d.world.visited or id == str(d.world.location)
		var place: Dictionary = GameWorld.place(id)
		out.append({
			"id": id, "name": str(place.get("name", id)) if visited else text("unknown"), "type": str(place.get("type", "")),
			"x": int(a["x"]), "z": int(a["z"]), "cell": cell_of(int(a["x"]), int(a["z"])), "visited": visited, "here": id == str(d.world.location),
		})
	return out


## The line that says where the family is.
static func here_line(d: GameDynasty) -> String:
	return text("here", {"place": str(d.world.here().get("name", d.world.location))})


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["settings", "text"]:
		if not dat.has(k):
			bad.append("worldmap.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	for k in ["step", "marker_px", "heir_px"]:
		if not dat["settings"].has(k) or int(dat["settings"][k]) < 1:
			bad.append("worldmap.json: settings.%s must be at least 1" % k)
	if not bad.is_empty():
		return bad
	if int(dat["settings"]["step"]) > GameWorldGen.size() / 4:
		bad.append("worldmap.json: a step of %d leaves too few cells to be a map" % int(dat["settings"]["step"]))
	for k in ["unknown", "here", "heir", "title", "legend"]:
		if str(dat["text"].get(k, "")) == "":
			bad.append("worldmap.json: text.%s is missing" % k)
	return bad
