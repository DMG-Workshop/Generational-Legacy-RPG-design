## What a dungeon looks like, as data (data/world/dungeon_themes.json): each dungeon has a theme with its own palette, floor,
## wall and door glyphs, props, light and its entrance drawn on the open world. Everything here is a pure function of the
## dungeon's id and the tile: which floor look a tile has, where the ambient props stand (rules by room role, placed from a
## hash of the id and the tile, never a die), which light sources there are and how dark a tile is for a heir standing at a
## given tile. Nothing is saved and no dice are drawn. `ui/play/dungeon_view.gd` draws it in the tile view and
## `ui/play/dungeon_entrance_art.gd` draws the entrance; neither works anything out.
## Run: godot --headless --path . -s res://tests/test_game_dungeon_art.gd
class_name GameDungeonArt
extends RefCounted

const PATH := "res://data/world/dungeon_themes.json"
const TILES := ["floor_a", "floor_b", "floor_c", "wall_face", "wall_top", "door", "exit"]
const WHERE := ["floor", "edge", "corner", "center", "pillar", "head", "wall_north"]
static var _cache: Dictionary = {}
static var _props: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


## The theme id of a dungeon (place id or space id), "" for anything that has none.
static func theme_id(dungeon: String) -> String:
	var place := dungeon.trim_prefix("world/")
	return str(data()["dungeons"].get(place, ""))


static func theme(dungeon: String) -> Dictionary:
	return data()["themes"].get(theme_id(dungeon), {})


static func has_glyph(dungeon: String, name: String) -> bool:
	var t := theme(dungeon)
	return t.get("glyphs", {}).has(name) or data()["shared"]["containers"].has(name)


## A glyph of a dungeon's theme: {rows: [8 strings], palette: {char: Color}}. A container's shape is coloured by the theme's
## container colours.
static func glyph(dungeon: String, name: String) -> Dictionary:
	var t := theme(dungeon)
	var pal: Dictionary = {}
	var rows: Array = []
	if t.get("glyphs", {}).has(name):
		rows = t["glyphs"][name]
		for ch in t["palette"]:
			pal[ch] = Color.html(str(t["palette"][ch]))
	elif data()["shared"]["containers"].has(name):
		rows = data()["shared"]["containers"][name]
		for ch in t["containers"]:
			pal[ch] = Color.html(str(t["containers"][ch]))
	return {"rows": rows, "palette": pal}


static func _key(x: int, z: int) -> String:
	return "%d,%d" % [x, z]


## Which of the three floor looks a floor tile has: a hash of the dungeon and the tile.
static func floor_kind(dungeon: String, x: int, z: int) -> String:
	return TILES[absi(hash([dungeon, "floor", x, z])) % 3]


## A wall seen from the room (floor to its south) or from above.
static func wall_kind(cells: Dictionary, x: int, z: int) -> String:
	return "wall_face" if str(cells.get(_key(x, z + 1), "")) in GameInterior.WALKABLE else "wall_top"


# ---------------------------------------------------------------- props

static func _rate(dungeon: String, x: int, z: int, rule: int) -> float:
	return float(absi(hash([dungeon, "prop", x, z, rule])) % 10007) / 10007.0


## The ambient props of a dungeon: {"x,z": prop id}, floor props and props hung on walls (`on_wall`), placed by the theme's
## rules and the rooms' roles. Solid ones never cut the floor in two. Cached; a pure function of the id.
static func props(space_id: String) -> Dictionary:
	var place := space_id.trim_prefix("world/")
	if _props.has(place):
		return _props[place]
	var out := {}
	var t := theme(space_id)
	if t.is_empty() or not GameDungeons.is_dungeon("world/" + place):
		return out
	var cells := GameInterior.cells("world/" + place)
	var lay := GameDungeons.layout("world/" + place)
	var solid: Dictionary = lay["solid"].duplicate()
	var taken: Dictionary = lay["reserved"].duplicate()
	for f in lay["features"]:
		out[_key(int(f["x"]), int(f["z"]))] = str(f["prop"])
	var defs: Dictionary = t["propdefs"]
	var near_door := {}
	for k in cells:
		if str(cells[k]) in ["door", "exit"]:
			var p := GameInterior._parse(k)
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					near_door[_key(p.x + dx, p.y + dz)] = true
	var rules: Array = t["ambient"]
	for room in GameSpaces.rooms("world/" + place):
		var role := str(room.get("role", ""))
		var rect: Array = room["rect"]
		var rx := int(rect[0])
		var rz := int(rect[1])
		var rw := int(rect[2])
		var rh := int(rect[3])
		for i in rules.size():
			var rule: Dictionary = rules[i]
			if not (rule.get("roles", []) as Array).is_empty() and role not in rule["roles"]:
				continue
			var prop := str(rule["prop"])
			var def: Dictionary = defs[prop]
			var where := str(rule["where"])
			for dz in rh:
				for dx in rw:
					var x := rx + dx
					var z := rz + dz
					var k := _key(x, z)
					if where == "wall_north":
						if dz != 0:
							continue
						var wk := _key(x, z - 1)
						if str(cells.get(wk, "")) != "wall" or str(cells.get(k, "")) != "floor" or out.has(wk) or near_door.has(k):
							continue
						if _rate(place, x, z - 1, i) < float(rule["chance"]):
							out[wk] = prop
						continue
					if str(cells.get(k, "")) != "floor" or taken.has(k) or near_door.has(k):
						continue
					if not _where_ok(cells, where, x, z, rx, rz, rw, rh):
						continue
					if _rate(place, x, z, i) >= float(rule["chance"]):
						continue
					if bool(def.get("solid", false)):
						solid[k] = true
						if not GameDungeons.still_connected(cells, solid):
							solid.erase(k)
							continue
					taken[k] = true
					out[k] = prop
	_props[place] = out
	return out


static func _where_ok(cells: Dictionary, where: String, x: int, z: int, rx: int, rz: int, rw: int, rh: int) -> bool:
	var walls := 0
	var ns := str(cells.get(_key(x, z - 1), "")) == "wall"
	var ss := str(cells.get(_key(x, z + 1), "")) == "wall"
	var es := str(cells.get(_key(x + 1, z), "")) == "wall"
	var ws := str(cells.get(_key(x - 1, z), "")) == "wall"
	for w in [ns, ss, es, ws]:
		if w:
			walls += 1
	match where:
		"floor":
			return true
		"edge":
			return walls >= 1
		"corner":
			return (ns or ss) and (es or ws)
		"center":
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					if str(cells.get(_key(x + dx, z + dz), "")) == "wall":
						return false
			return true
		"pillar":
			return rw >= 4 and rh >= 4 and (x - rx) % 3 == 1 and (z - rz) % 3 == 1
		"head":
			return z == rz and x == rx + rw / 2
	return false


## The cells with a solid prop (not on a wall): the heir cannot stand on them.
static func solid_props(space_id: String) -> Dictionary:
	var out := {}
	var t := theme(space_id)
	if t.is_empty():
		return out
	for k in props(space_id):
		var def: Dictionary = t["propdefs"].get(str(props(space_id)[k]), {})
		if bool(def.get("solid", false)) and not bool(def.get("on_wall", false)):
			out[k] = true
	return out


# ---------------------------------------------------------------- light

## The light sources of a dungeon: [{x, z, r}] from the props that give light.
static func lights(space_id: String) -> Array:
	var out: Array = []
	var t := theme(space_id)
	if t.is_empty():
		return out
	var ps := props(space_id)
	for k in ps:
		var def: Dictionary = t["propdefs"].get(str(ps[k]), {})
		if float(def.get("light", 0)) > 0.0:
			var p := GameInterior._parse(k)
			out.append({"x": p.x, "z": p.y, "r": float(def["light"])})
	return out


## How dark a tile is (0 light, up to the theme's `dark`), for a heir at (hx, hz): the heir's own light round them and the
## light of the props (torches, braziers, lava) round each of those.
static func darkness(space_id: String, x: int, z: int, hx: int, hz: int, light_list: Array = []) -> float:
	var t := theme(space_id)
	if t.is_empty():
		return 0.0
	var dark := float(t["light"]["dark"])
	var radius := float(t["light"]["radius"])
	var lit := 1.0 - smoothstep(radius * 0.45, radius, Vector2(float(x - hx), float(z - hz)).length())
	for s in (light_list if not light_list.is_empty() else lights(space_id)):
		var dist := Vector2(float(x) - float(s["x"]), float(z) - float(s["z"])).length()
		lit = maxf(lit, 0.85 * (1.0 - smoothstep(float(s["r"]) * 0.35, float(s["r"]), dist)))
	return dark * (1.0 - clampf(lit, 0.0, 1.0))


# ---------------------------------------------------------------- the entrance on the open world

## The tiles of the open world a dungeon's entrance is drawn over: its door tile at the bottom middle.
static func entrance_rect(place: String) -> Rect2i:
	var t := theme(place)
	if t.is_empty():
		return Rect2i()
	var e: Dictionary = t["entrance"]
	var door: Dictionary = GameSpaces.space("world/" + place).get("door", {})
	var w := int(e["w"])
	var h := int(e["h"])
	return Rect2i(int(door.get("x", 0)) - (w - 1) / 2, int(door.get("z", 0)) - (h - 1), w, h)


## The entrance's solid tiles: every tile of every entrance (`entrance_rect`) but its door tile, so the hillside, the mound or the gate-house is a body
## that stops walkers and blows like a tree or a building does, and the way in is the door tile alone, reached from the open ground below it.
## {"x,z": true}, built once (tests that change the data call `reload`).
static var _solid: Dictionary = {}


static func solid() -> Dictionary:
	if _solid.is_empty():
		for place in data()["dungeons"]:
			var r := entrance_rect(str(place))
			if r.size == Vector2i.ZERO:
				continue
			var door: Dictionary = GameSpaces.space("world/" + str(place)).get("door", {})
			for x in range(r.position.x, r.end.x):
				for z in range(r.position.y, r.end.y):
					if not (x == int(door.get("x", -1)) and z == int(door.get("z", -1))):
						_solid["%d,%d" % [x, z]] = true
	return _solid


## Whether a tile is the body of a dungeon's entrance (not its door).
static func blocks(x: int, z: int) -> bool:
	return solid().has("%d,%d" % [x, z])


static func reload() -> void:
	_cache = {}
	_solid = {}


## The dungeons whose entrance overlaps a rectangle of the open world's tiles: [{place, rect, entrance}].
static func entrances_in(view: Rect2i) -> Array:
	var out: Array = []
	for place in data()["dungeons"]:
		var r := entrance_rect(str(place))
		if r.size != Vector2i.ZERO and r.intersects(view):
			out.append({"place": str(place), "rect": r, "entrance": theme(str(place))["entrance"]})
	return out


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["dungeons", "shared", "themes"]:
		if not dat.has(k):
			bad.append("dungeon_themes.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	GameData.load_all()
	var shared: Dictionary = dat["shared"]["containers"]
	for n in shared:
		bad.append_array(_glyph_problems("shared container '%s'" % n, shared[n], {"M": 1, "N": 1, "H": 1, "T": 1, "P": 1}))
	for p in GameDungeons.dungeon_ids():
		if not dat["dungeons"].has(p) or not dat["themes"].has(str(dat["dungeons"].get(p, ""))):
			bad.append("dungeon_themes.json: the dungeon '%s' has no theme" % p)
	for tid in dat["themes"]:
		var t: Dictionary = dat["themes"][tid]
		var tag := "dungeon_themes.json: theme '%s'" % tid
		for k in ["name", "about", "palette", "containers", "glyphs", "propdefs", "ambient", "light", "entrance"]:
			if not t.has(k):
				bad.append("%s lacks %s" % [tag, k])
		if t.size() < 9:
			continue
		var pal: Dictionary = t["palette"]
		for ch in pal:
			if str(ch).length() != 1 or not str(pal[ch]).begins_with("#") or not Color.html_is_valid(str(pal[ch])):
				bad.append("%s has a bad palette entry '%s'" % [tag, ch])
		for ch in ["M", "N", "H", "T", "P"]:
			if not t["containers"].has(ch):
				bad.append("%s lacks the container colour %s" % [tag, ch])
		for g in TILES:
			if not t["glyphs"].has(g):
				bad.append("%s lacks the glyph %s" % [tag, g])
		for g in t["glyphs"]:
			bad.append_array(_glyph_problems("%s glyph '%s'" % [tag, g], t["glyphs"][g], pal))
			if g not in TILES:
				if not t["propdefs"].has(g):
					bad.append("%s has the glyph '%s' but no propdef" % [tag, g])
			else:
				for row in t["glyphs"][g]:
					if str(row).contains("."):
						bad.append("%s: the tile glyph '%s' has a clear pixel (it is the whole tile)" % [tag, g])
						break
		for g in t["propdefs"]:
			if not t["glyphs"].has(g):
				bad.append("%s has a propdef '%s' with no glyph" % [tag, g])
			var def: Dictionary = t["propdefs"][g]
			if str(def.get("name", "")) == "" or typeof(def.get("solid")) != TYPE_BOOL or float(def.get("light", -1)) < 0.0:
				bad.append("%s propdef '%s' needs a name, solid and light" % [tag, g])
		for rule in t["ambient"]:
			if not t["propdefs"].has(str(rule.get("prop", ""))) or str(rule.get("where", "")) not in WHERE or float(rule.get("chance", -1)) < 0.0 or float(rule["chance"]) > 1.0:
				bad.append("%s has a bad ambient rule %s" % [tag, str(rule)])
				continue
			if (str(rule["where"]) == "wall_north") != bool(t["propdefs"][str(rule["prop"])].get("on_wall", false)):
				bad.append("%s: the prop '%s' must be on_wall exactly when it goes on wall_north" % [tag, rule["prop"]])
			for r in rule.get("roles", []):
				if not GameDungeons.data()["roles"].has(str(r)) and str(r) not in ["charnel"]:
					bad.append("%s names the unknown role '%s'" % [tag, r])
		var l: Dictionary = t["light"]
		if float(l.get("dark", -1)) < 0.0 or float(l["dark"]) > 0.9 or float(l.get("radius", 0)) < 2.0 or (l.get("tint", []) as Array).size() != 3:
			bad.append("%s needs light dark (0 to 0.9), radius (2 or more) and a tint" % tag)
		var e: Dictionary = t["entrance"]
		var w := int(e.get("w", 0)) * 16
		var h := int(e.get("h", 0)) * 16
		if w <= 0 or h <= 0 or typeof(e.get("rows")) != TYPE_ARRAY or (e["rows"] as Array).size() != h:
			bad.append("%s: the entrance needs w and h tiles and %d rows" % [tag, h])
		else:
			for row in e["rows"]:
				if str(row).length() != w:
					bad.append("%s: an entrance row is not %d wide" % [tag, w])
					break
				for ch in str(row):
					if ch != "." and not e["palette"].has(ch):
						bad.append("%s: the entrance uses '%s', which its palette lacks" % [tag, ch])
						break
	# each dungeon's theme needs the glyphs of its containers and features
	for p in dat["dungeons"]:
		var dc: Dictionary = GameDungeons.data()["dungeons"].get(p, {})
		for role in dc.get("roles", {}):
			for c in dc["roles"][role].get("containers", []):
				for suffix in ["", "_open"]:
					if not shared.has(str(c["kind"]) + suffix):
						bad.append("dungeon_themes.json: no container shape '%s'" % (str(c["kind"]) + suffix))
	return bad


static func _glyph_problems(tag: String, rows: Variant, palette: Dictionary) -> Array:
	var bad: Array = []
	if typeof(rows) != TYPE_ARRAY or (rows as Array).size() != 8:
		return ["dungeon_themes.json: %s needs 8 rows" % tag]
	for row in rows:
		if str(row).length() != 8:
			bad.append("dungeon_themes.json: %s has a row that is not 8 wide" % tag)
			continue
		for ch in str(row):
			if ch != "." and not palette.has(ch):
				bad.append("dungeon_themes.json: %s uses '%s', which its palette lacks" % [tag, ch])
	return bad
