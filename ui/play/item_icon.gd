## Item icons (docs/PLAYER_INTERFACE.md, slice 4; data/art/icons.json): a small pixel picture for every item, made in code from the
## data and kept. Rendering only. A numbered bag (`satchel#2`) is drawn as its base item.
extends RefCounted

const PATH := "res://data/art/icons.json"

static var _cache: Dictionary = {}
static var _textures: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				_cache = parsed
	return _cache


## The name of the glyph an item is drawn with: its slot's, else its kind's, else the default.
static func glyph_of(id: String) -> String:
	var def := GameItems.item_def(id)
	var slot := str(def.get("slot", ""))
	if slot != "" and data()["slot_glyph"].has(slot):
		return str(data()["slot_glyph"][slot])
	var kind := str(def.get("kind", ""))
	if data()["kind_glyph"].has(kind):
		return str(data()["kind_glyph"][kind])
	return "default"


## The main colour of an item: its material's first listed tag, brightened a little by its tier.
static func color_of(id: String) -> Color:
	var base: Array = data()["default_color"]
	for t in GameMaterials.tags_of(GameItems.material_of(id)):
		if data()["tag_colors"].has(str(t)):
			base = data()["tag_colors"][str(t)]
			break
	var c := Color(float(base[0]), float(base[1]), float(base[2]))
	var tier := int(GameItems.item_def(id).get("tier", 1))
	return c.lightened(clampf(float(tier - 1) * 0.04, 0.0, 0.25))


## The icon of an item (12 by 12 pixels), made once for each look.
static func texture(id: String) -> Texture2D:
	var glyph := glyph_of(id)
	var col := color_of(id)
	var key := "%s|%s" % [glyph, col.to_html()]
	if _textures.has(key):
		return _textures[key]
	var rows: Array = data()["glyphs"][glyph]
	var o: Array = data()["outline"]
	var palette := {"a": col, "b": col.lightened(0.35), "c": col.darkened(0.35), "o": Color(float(o[0]), float(o[1]), float(o[2]))}
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for y in 12:
		for x in 12:
			var ch := str(rows[y])[x]
			img.set_pixel(x, y, palette[ch] if palette.has(ch) else Color(0, 0, 0, 0))
	var tex := ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex


static func validate() -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["slot_glyph", "kind_glyph", "tag_colors", "default_color", "outline", "glyphs"]:
		if not dat.has(k):
			bad.append("icons.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	if not dat["glyphs"].has("default"):
		bad.append("icons.json: there is no default glyph")
	for name in dat["glyphs"]:
		var rows: Variant = dat["glyphs"][name]
		if typeof(rows) != TYPE_ARRAY or (rows as Array).size() != 12:
			bad.append("icons.json: glyph %s needs 12 rows" % name)
			continue
		for r in rows:
			if str(r).length() != 12:
				bad.append("icons.json: a row of glyph %s is not 12 wide" % name)
			for ch in str(r):
				if ch not in ".abco":
					bad.append("icons.json: glyph %s uses '%s', not one of . a b c o" % [name, ch])
	for map in ["slot_glyph", "kind_glyph"]:
		for k in dat[map]:
			if not dat["glyphs"].has(str(dat[map][k])):
				bad.append("icons.json: %s %s names the glyph %s, which does not exist" % [map, k, dat[map][k]])
	for k in dat["tag_colors"]:
		if typeof(dat["tag_colors"][k]) != TYPE_ARRAY or (dat["tag_colors"][k] as Array).size() != 3:
			bad.append("icons.json: tag colour %s needs three numbers" % k)
	return bad
