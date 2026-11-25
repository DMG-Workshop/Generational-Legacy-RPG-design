## The world map view (roadmap follow-up; data/world/worldmap.json): the open world sampled at a coarse step as a grid of kinds (a
## biome or water, the names the tile view has colours for) with a marker for each place on the map (unvisited ones marked but not
## named) and the cell the heir stands in. Pure functions of the dynasty's seed and what the family has visited: nothing is saved and
## no dice are drawn. ui/play/world_map_panel.gd draws it.
class_name GameWorldMap
extends RefCounted

static var _cache: Dictionary = {}
static var _tiles: Dictionary = {}   # "seed|trial" -> the tile a trial site stands on (a pure function, kept because the sandbox asks every frame)


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


## A marker for every place on the map: {id, name, type, kind, x, z, cell, visited, known, here}. A town or a city is known to everyone (named
## and marked from the start: `kind` "town" or "city"); any other place has no name here, only the `unknown` line, until the family has been
## there, so the map does not give away what the family has not found (`kind` "dungeon" or "wilds").
static func markers(d: GameDynasty) -> Array:
	var out: Array = []
	for a in GameWorldGen.anchors():
		var id := str(a["id"])
		var visited: bool = id in d.world.visited or id == str(d.world.location)
		var place: Dictionary = GameWorld.place(id)
		var town := GameTravel.is_town(id)
		var known := visited or town
		var kind := ("city" if GameTravel.is_city(id) else "town") if town else ("dungeon" if str(place.get("type", "")) == "dungeon" else "wilds")
		out.append({
			"id": id, "name": str(place.get("name", id)) if known else text("unknown"), "type": str(place.get("type", "")), "kind": kind,
			"x": int(a["x"]), "z": int(a["z"]), "cell": cell_of(int(a["x"]), int(a["z"])), "visited": visited, "known": known, "here": id == str(d.world.location),
		})
	return out


## The markers of the towns and cities, which can be selected on the map.
static func town_markers(d: GameDynasty) -> Array:
	return markers(d).filter(func(m): return str(m["kind"]) in ["town", "city"])


## The town marker nearest a point of the picture (in cells), within `reach` cells: {} for none. What a click or a tap selects.
static func town_near_cell(d: GameDynasty, at: Vector2, reach: float) -> Dictionary:
	var best := {}
	var best_d := reach
	for m in town_markers(d):
		var dist := ((Vector2(m["cell"]) + Vector2(0.5, 0.5)) - at).length()
		if dist <= best_d:
			best_d = dist
			best = m
	return best


## A marker for every landmark of the wilds the family has found (and none it has not): {id, name, kind, area, x, z, cell}.
static func landmark_markers(d: GameDynasty) -> Array:
	var out: Array = []
	for lm in GameWildsSites.found(d):
		out.append({"id": str(lm["id"]), "name": GameWildsSites.name_of(lm), "kind": str(lm["kind"]), "area": GameWildsSites.area_name(lm),
			"x": int(lm["x"]), "z": int(lm["z"]), "cell": cell_of(int(lm["x"]), int(lm["z"]))})
	return out


## Where a trial of the open world stands as a tile: its place in the trials' square, stretched over the world, and moved to the nearest cell
## that is not water (a site is never under the sea). A pure function of the seed.
static func trial_tile(d: GameDynasty, p: Dictionary) -> Vector2i:
	var key := "%d|%s" % [d.seed_value, str(p.get("id", ""))]
	if _tiles.has(key):
		return _tiles[key]
	var tile := _trial_tile(d, p)
	_tiles[key] = tile
	return tile


static func _trial_tile(d: GameDynasty, p: Dictionary) -> Vector2i:
	var area := maxi(1, int(GameTrials.setting("area")))
	var size := GameWorldGen.size()
	var x := clampi(int(p["x"]) * size / area, 0, size - 1)
	var z := clampi(int(p["z"]) * size / area, 0, size - 1)
	var c := cell_of(x, z)
	for r in cells():
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var cx := c.x + dx
				var cz := c.y + dz
				if cx < 0 or cz < 0 or cx >= cells() or cz >= cells():
					continue
				if kind_at(d, cx, cz) != "water":
					return Vector2i(x, z) if r == 0 else tile_of(cx, cz)
	return Vector2i(x, z)


## A marker for every trial of the open world whose site the family has found (the first step of its way in done) or has passed, and none it has not:
## {id, name, focus_name, master, x, z, cell, passed}. The other realms are spaces of their own and are not on this map.
static func trial_markers(d: GameDynasty) -> Array:
	var out: Array = []
	for p in GameTrials.placed(d.seed_value, "material"):
		var id := str(p["id"])
		var passed := GameTrials.done(d.heir, id)
		if GameTrials.quest_steps_done(d, id) < 1 and not passed:
			continue
		var t := GameTrials.trial(id)
		var tile := trial_tile(d, p)
		out.append({"id": id, "name": str(t["name"]), "focus_name": GameTrials.focus_name(str(t["focus"])), "master": str(t["master"]["name"]),
			"x": tile.x, "z": tile.y, "cell": cell_of(tile.x, tile.y), "passed": passed})
	return out


## The lines that list the trials found, `max_lines` at most, then how many more.
static func trial_lines(d: GameDynasty, max_lines: int) -> Array:
	var marks := trial_markers(d)
	if marks.is_empty():
		return [text("trial_none")]
	var out: Array = []
	for i in mini(max_lines, marks.size()):
		var m: Dictionary = marks[i]
		out.append(text("trial_line", {"name": m["name"], "focus": m["focus_name"], "state": text("trial_passed") if bool(m["passed"]) else text("trial_open"), "x": m["x"], "z": m["z"]}))
	if marks.size() > max_lines:
		out.append(text("trial_more", {"n": marks.size() - max_lines}))
	return out


## The lines that list them, `max_lines` at most, then how many more.
static func landmark_lines(d: GameDynasty, max_lines: int) -> Array:
	var marks := landmark_markers(d)
	var out: Array = []
	if marks.is_empty():
		return [GameWilds.text("map_none")]
	for i in mini(max_lines, marks.size()):
		out.append(GameWilds.text("map_line", {"name": marks[i]["name"], "area": marks[i]["area"]}))
	if marks.size() > max_lines:
		out.append(GameWilds.text("map_more", {"n": marks.size() - max_lines}))
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
	bad.append_array(GameTravel.validate())
	for k in ["unknown", "here", "heir", "title", "legend", "trial_title", "trial_none", "trial_line", "trial_more", "trial_passed", "trial_open"]:
		if str(dat["text"].get(k, "")) == "":
			bad.append("worldmap.json: text.%s is missing" % k)
	return bad
