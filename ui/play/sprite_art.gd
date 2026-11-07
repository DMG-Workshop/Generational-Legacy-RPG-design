## Battle sprites: pixel art kept as text grids in data/art/ (one character per pixel, "." clear) and turned
## into textures the first time they are asked for. A hero or companion is a class figure (24x40, facing
## right) with the race's skin and hair in its S/s/H/h pixels, its shirt colour in its C/c pixels, and the
## race's own layers drawn under and over it. Creatures face left. The grids are scaled up by whole pixels
## (UPSCALE) before the screen shrinks them to fit, so every pixel stays the same size. Rendering only:
## nothing here touches the game's state or its dice.
extends RefCounted

const CLASSES := "res://data/art/classes.json"
const RACES := "res://data/art/races.json"
const CREATURES := "res://data/art/creatures.json"
const SHIRTS := "res://data/art/shirts.json"
const FIGURE := Vector2i(24, 40)   # every class figure and race layer
const UPSCALE := 4
const RESERVED := "SsHhCc"

static var _classes: Dictionary = {}
static var _races: Dictionary = {}
static var _creatures: Dictionary = {}
static var _shirts: Array = []
static var _loaded := false
static var _cache: Dictionary = {}   # key -> Texture2D


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_classes = _read(CLASSES).get("sprites", {})
	_races = _read(RACES).get("races", {})
	_creatures = _read(CREATURES).get("sprites", {})
	_shirts = []
	for s in _read(SHIRTS).get("shirts", []):
		if typeof(s) == TYPE_DICTIONARY and Color.html_is_valid(str(s.get("color", ""))) and str(s.get("id", "")) != "":
			_shirts.append(s)


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if typeof(v) == TYPE_DICTIONARY else {}


## Forget everything loaded (tests change the data in between).
static func reset() -> void:
	_loaded = false
	_classes = {}
	_races = {}
	_creatures = {}
	_shirts = []
	_cache = {}


static func has_creature(id: String) -> bool:
	_load()
	return _creatures.has(id)


static func has_class(id: String) -> bool:
	_load()
	return _classes.has(id)


static func has_race(id: String) -> bool:
	_load()
	return _races.has(id)


## A creature's sprite (facing left), or null when it has none and the screen keeps the old block.
static func creature(id: String) -> Texture2D:
	_load()
	if not _creatures.has(id):
		return null
	var key := "creature:" + id
	if not _cache.has(key):
		var s: Dictionary = _creatures[id]
		_cache[key] = _texture(_paint(s, {}))
	return _cache[key]


## A hero's or companion's figure: the class figure in the race's colours with the race's layers, or null
## when the class has no figure. A race with no entry is drawn with the class figure's own colours.
static func hero(race_id: String, class_id: String, class_color: Color) -> Texture2D:
	_load()
	if not _classes.has(class_id):
		return null
	var key := "hero:%s:%s:%s" % [race_id, class_id, class_color.to_html(false)]
	if not _cache.has(key):
		var r: Dictionary = _races.get(race_id, {})
		var fill := {"C": class_color, "c": class_color.darkened(0.32)}
		for k in RACE_KEYS:
			fill[k] = Color.html(str(r.get(RACE_KEYS[k], DEFAULTS[k])))
		var img := Image.create_empty(FIGURE.x, FIGURE.y, false, Image.FORMAT_RGBA8)
		var rp: Dictionary = r.get("palette", {})
		if r.has("under"):
			_blend(img, _paint({"size": [FIGURE.x, FIGURE.y], "palette": rp, "rows": r["under"]}, fill))
		_blend(img, _paint(_classes[class_id], fill))
		if r.has("over"):
			_blend(img, _paint({"size": [FIGURE.x, FIGURE.y], "palette": rp, "rows": r["over"]}, fill))
		_cache[key] = _texture(img)
	return _cache[key]


## A hero's or companion's figure: their class figure in their race's colours, wearing their shirt. Null when
## the class has no figure.
static func figure(u: GameHeir) -> Texture2D:
	return hero(u.race_id, u.class_id, shirt_color(u))


## The shirts a figure can wear, as data/art/shirts.json lists them: [{id, name, color}].
static func shirts() -> Array:
	_load()
	return _shirts


## A figure's shirt colour: the one chosen for them, else one picked from who they are, never from the game's
## dice, so the same person always wears the same shirt and two people seldom match. The class colour when
## there are no shirts at all.
static func shirt_color(u: GameHeir) -> Color:
	_load()
	if _shirts.is_empty():
		return Color(str(u.cls().get("color", "#888888")))
	return Color.html(str(_shirts[shirt_index(u)]["color"]))


## The place in shirts() of the shirt a figure wears.
static func shirt_index(u: GameHeir) -> int:
	_load()
	for i in _shirts.size():
		if str(_shirts[i]["id"]) == u.shirt:
			return i
	return posmod(shirt_key(u).hash(), maxi(1, _shirts.size()))


## Who a figure is, for picking their shirt: a companion by their id and name, anyone else by id and name.
static func shirt_key(u: GameHeir) -> String:
	if u.has_meta("companion"):
		return "companion:%s:%s" % [str(u.get_meta("companion")), u.name]
	return "heir:%d:%s" % [u.id, u.name]


## Skin and hair for a figure whose race has no entry: the human look of the reference figure.
const DEFAULTS := {"S": "#e8b98f", "s": "#c48d68", "H": "#5a3a24", "h": "#3e2718"}
## The race entry's colour for each reserved key.
const RACE_KEYS := {"S": "skin", "s": "skin_shade", "H": "hair", "h": "hair_shade"}


## One grid as an image: its palette, with the reserved keys from `fill` ("." and anything unknown stay clear).
static func _paint(s: Dictionary, fill: Dictionary) -> Image:
	var size: Array = s.get("size", [1, 1])
	var w := int(size[0])
	var h := int(size[1])
	var img := Image.create_empty(maxi(1, w), maxi(1, h), false, Image.FORMAT_RGBA8)
	var pal := {}
	var raw: Dictionary = s.get("palette", {})
	for k in raw:
		pal[k] = Color.html(str(raw[k]))
	for k in fill:
		pal[k] = fill[k]
	var rows: Array = s.get("rows", [])
	for y in mini(h, rows.size()):
		var line := str(rows[y])
		for x in mini(w, line.length()):
			var ch := line[x]
			if ch != "." and pal.has(ch):
				img.set_pixel(x, y, pal[ch])
	return img


## Draws `top` over `base` where `top` has a pixel.
static func _blend(base: Image, top: Image) -> void:
	for y in mini(base.get_height(), top.get_height()):
		for x in mini(base.get_width(), top.get_width()):
			var c := top.get_pixel(x, y)
			if c.a > 0.0:
				base.set_pixel(x, y, c)


static func _texture(img: Image) -> Texture2D:
	var big := img.duplicate() as Image
	big.resize(img.get_width() * UPSCALE, img.get_height() * UPSCALE, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(big)


## Where a sprite of `tex_size` sits inside a box: as large as fits, centred, standing on the box's bottom.
static func fit(tex_size: Vector2, box: Vector2) -> Rect2:
	var k := minf(box.x / maxf(1.0, tex_size.x), box.y / maxf(1.0, tex_size.y))
	var size := tex_size * k
	return Rect2(Vector2((box.x - size.x) * 0.5, box.y - size.y), size)


## A sprite as a node filling `box` (as `fit` places it), ignoring the mouse so the figure under it gets the taps.
static func sprite_node(tex: Texture2D, box: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := fit(Vector2(tex.get_width(), tex.get_height()), box)
	t.position = r.position
	t.size = r.size
	return t


## Problems with the art data, one readable line each; [] when it is sound.
static func validate() -> Array:
	_load()
	var out: Array = []
	for id in _classes:
		var s: Dictionary = _classes[id]
		var size: Array = s.get("size", [])
		if size.size() != 2 or int(size[0]) != FIGURE.x or int(size[1]) != FIGURE.y:
			out.append("class %s: a class figure is %dx%d" % [id, FIGURE.x, FIGURE.y])
		out.append_array(_grid_problems("class " + id, s.get("rows", []), s.get("size", [0, 0]), s.get("palette", {}), true))
	for id in _creatures:
		var s: Dictionary = _creatures[id]
		var size: Array = s.get("size", [0, 0])
		if size.size() != 2 or int(size[0]) < 1 or int(size[1]) < 1 or int(size[0]) > 64 or int(size[1]) > 64:
			out.append("creature %s: size must be 1 to 64 a side" % id)
		out.append_array(_grid_problems("creature " + id, s.get("rows", []), size, s.get("palette", {}), false))
	var raw_shirts: Array = _read(SHIRTS).get("shirts", [])
	var seen := {}
	if raw_shirts.size() < 2:
		out.append("shirts: at least two shirts are needed")
	for s in raw_shirts:
		if typeof(s) != TYPE_DICTIONARY or str(s.get("id", "")) == "" or str(s.get("name", "")) == "" or not Color.html_is_valid(str(s.get("color", ""))):
			out.append("shirts: %s needs an id, a name and a colour" % str(s))
		elif seen.has(str(s["id"])):
			out.append("shirts: %s is listed twice" % s["id"])
		else:
			seen[str(s["id"])] = true
	for id in _races:
		var r: Dictionary = _races[id]
		for k in ["skin", "skin_shade", "hair", "hair_shade"]:
			if not Color.html_is_valid(str(r.get(k, ""))):
				out.append("race %s: %s must be a colour" % [id, k])
		for layer in ["under", "over"]:
			if r.has(layer):
				out.append_array(_grid_problems("race %s %s" % [id, layer], r[layer], [FIGURE.x, FIGURE.y], r.get("palette", {}), true))
	return out


static func _grid_problems(name: String, rows: Variant, size: Variant, palette: Variant, reserved_ok: bool) -> Array:
	var out: Array = []
	if typeof(rows) != TYPE_ARRAY or typeof(size) != TYPE_ARRAY or (size as Array).size() != 2 or typeof(palette) != TYPE_DICTIONARY:
		return ["%s: needs size [w, h], a palette and rows" % name]
	var w := int(size[0])
	var h := int(size[1])
	if (rows as Array).size() != h:
		out.append("%s: %d rows for a height of %d" % [name, (rows as Array).size(), h])
	for k in palette:
		if str(k).length() != 1 or str(k) == "." or RESERVED.contains(str(k)):
			out.append("%s: palette key '%s' must be one character, not '.' or reserved" % [name, k])
		elif not Color.html_is_valid(str(palette[k])):
			out.append("%s: palette '%s' is not a colour" % [name, k])
	for y in (rows as Array).size():
		var line := str(rows[y])
		if line.length() != w:
			out.append("%s: row %d is %d wide, not %d" % [name, y, line.length(), w])
			continue
		for x in line.length():
			var ch := line[x]
			if ch == ".":
				continue
			if RESERVED.contains(ch):
				if not reserved_ok:
					out.append("%s: reserved '%s' at %d,%d" % [name, ch, x, y])
			elif not (palette as Dictionary).has(ch):
				out.append("%s: '%s' at %d,%d is not in the palette" % [name, ch, x, y])
	return out
