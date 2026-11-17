## The open world drawn as tiles (roadmap item 3 of the open-world plan). The ground is split into square chunks of
## `chunk` tiles, each a TileMapLayer that is filled once from the generated world (GameWorldGen.tile) and kept while it is
## near the view; chunks beyond `keep` chunks of the view are freed. A tile's look is its kind: a biome, water, or the
## piece built on it (a built piece covers the ground). The atlas is one row of flat colours made in code (the colours are
## data, `tiles` in data/world/sandbox.json); sprite art later replaces `make_tileset` and nothing else. A rendering node:
## it reads the dynasty and draws, it never changes it. Chunk and kind rules are static so the tests need no scene. A storey
## above the ground is shown by `set_level`: the ground dims and that storey's pieces are drawn over it in layers of their own.
class_name TileView
extends Node2D

var d: GameDynasty
var layers := {}          # Vector2i chunk -> TileMapLayer
var tile_set: TileSet
var fills := 0            # chunks filled so far (for tests)
var interior_id := ""     # the interior shown instead of the open world ("" shows the world)
var interior := {}        # its cells, "x,z" -> floor, door, exit or wall (GameInterior.cells); nothing is drawn elsewhere
var level := 0            # the storey shown: 0 is the ground; above it the ground is dimmed and that storey's pieces are drawn over it
var uppers := {}          # Vector2i chunk -> TileMapLayer of the shown storey's pieces (empty cells where nothing is built)
var things := {}          # Vector2i chunk -> TileMapLayer of what stands on the ground: nodes (trees, herbs, bones, rock) and dug shafts


static func settings() -> Dictionary:
	return GameSandbox.data()["tiles"]


## The kinds a tile can look like, in atlas order: the biomes, water, then the buildable pieces.
static func kinds() -> Array:
	var out: Array = GamePath.data()["terrain"].keys()
	out.append("water")
	for id in GameBuild.pieces():
		out.append(id)
	var nodes: Array = GameWorldGen.data()["nodes"].keys()
	nodes.sort()
	for n in nodes:
		out.append(n)   # what GameWorldGen puts on a tile: drawn over the ground in `things`
	out.append("dug")   # a shaft dug at the first depth, also in `things`
	out.append("person")   # someone standing in an interior (GamePeople)
	out.append("exit")   # an interior's way out (its floor, doors and walls use the floor, door and wall colours)
	return out


## The kind a tile is drawn as: the piece built on it, else water, else its biome.
static func kind_for(tile: Dictionary, built: String) -> String:
	if built != "":
		return built
	if bool(tile.get("water", false)):
		return "water"
	return str(tile.get("biome", "plains"))


## The chunk a tile is in (floored, so negative tiles work).
static func chunk_of(x: int, z: int) -> Vector2i:
	var n := int(settings()["chunk"])
	return Vector2i(floori(float(x) / n), floori(float(z) / n))


## The chunks that cover a view centred on `centre` (in tiles) with `half` tiles each way, plus `keep` chunks all round.
static func wanted(centre: Vector2, half: Vector2, keep: int) -> Array:
	var lo := chunk_of(floori(centre.x - half.x), floori(centre.y - half.y))
	var hi := chunk_of(floori(centre.x + half.x), floori(centre.y + half.y))
	var out: Array = []
	for cz in range(lo.y - keep, hi.y + keep + 1):
		for cx in range(lo.x - keep, hi.x + keep + 1):
			out.append(Vector2i(cx, cz))
	return out


## The atlas: one `px` square of flat colour per kind, left to right, with a darker edge so the grid shows.
static func make_tileset() -> TileSet:
	var px := int(settings()["px"])
	var all := kinds()
	var img := Image.create(px * all.size(), px, false, Image.FORMAT_RGBA8)
	var colors: Dictionary = settings()["colors"]
	var glyphs: Dictionary = settings().get("glyphs", {})
	for i in all.size():
		if glyphs.has(all[i]):
			_paint_glyph(img, i * px, px, glyphs[all[i]])   # a thing on the ground: clear but for its drawing
			continue
		var c := Color(float(colors[all[i]][0]), float(colors[all[i]][1]), float(colors[all[i]][2]))
		img.fill_rect(Rect2i(i * px, 0, px, px), c.darkened(0.12))
		img.fill_rect(Rect2i(i * px + 1, 1, px - 2, px - 2), c)
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(px, px)
	for i in all.size():
		src.create_tile(Vector2i(i, 0))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(px, px)
	ts.add_source(src, 0)
	return ts


## Paints an 8 by 8 glyph into the atlas at x0, each pixel a block of px / 8 (a '.' or a character with no colour stays clear).
static func _paint_glyph(img: Image, x0: int, px: int, glyph: Dictionary) -> void:
	var rows: Array = glyph["rows"]
	var pal: Dictionary = glyph["palette"]
	var block := maxi(1, px / 8)
	for y in rows.size():
		var row := str(rows[y])
		for x in row.length():
			var ch := row.substr(x, 1)
			if not pal.has(ch):
				continue
			var c: Array = pal[ch]
			var col := Color(float(c[0]), float(c[1]), float(c[2]), float(c[3]) if c.size() > 3 else 1.0)
			img.fill_rect(Rect2i(x0 + x * block, y * block, block, block), col)


func setup(dyn: GameDynasty) -> void:
	d = dyn
	tile_set = make_tileset()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Keeps the chunks of a view (centre and half-size in tiles) and frees the others.
func show_view(centre: Vector2, half: Vector2) -> void:
	var want := wanted(centre, half, int(settings()["keep"]))
	for c in want:
		if not layers.has(c):
			_fill(c)   # a new chunk gets its storey layer here when a storey is shown
	for c in layers.keys():
		if not want.has(c):
			(layers[c] as TileMapLayer).queue_free()
			layers.erase(c)
			if uppers.has(c):
				(uppers[c] as TileMapLayer).queue_free()
				uppers.erase(c)
			if things.has(c):
				(things[c] as TileMapLayer).queue_free()
				things.erase(c)


## Shows a storey (0 is the ground). Above the ground, the ground tiles are dimmed by `below_shade` and the pieces built at that
## storey are drawn over them; going back to 0 puts the ground back and lets the storey's tiles go.
func set_level(n: int) -> void:
	var top := int(GameBuild.setting("max_storeys")) + 1   # one more for the roofs over the top storey
	n = clampi(n, 0, 0 if interior_id != "" else top)   # an interior has one floor
	if n == level:
		return
	level = n
	for c in uppers.keys():
		(uppers[c] as TileMapLayer).queue_free()
	uppers.clear()
	for c in things:
		(things[c] as TileMapLayer).visible = level == 0   # the ground's trees and shafts are not on a storey
	var shade := float(settings()["below_shade"]) if level > 0 else 1.0
	for c in layers:
		(layers[c] as TileMapLayer).modulate = Color(shade, shade, shade)
	for c in layers:
		if level > 0:
			_fill_upper(c)


## Shows an interior's floor in place of the open world (`id` "" goes back to the world). Everything drawn is dropped and
## drawn again from the new cells at the next `show_view`.
func set_interior(id: String, cells: Dictionary) -> void:
	if id == interior_id:
		return
	interior_id = id
	interior = cells
	for c in layers.keys():
		(layers[c] as TileMapLayer).queue_free()
	layers.clear()
	for c in uppers.keys():
		(uppers[c] as TileMapLayer).queue_free()
	uppers.clear()
	for c in things.keys():
		(things[c] as TileMapLayer).queue_free()
	things.clear()
	level = 0   # an interior has one floor


## Places the view: the tile `centre` goes to the middle of `area` (the map's rectangle, top-left at `origin`), `cell` pixels a tile.
func place(origin: Vector2, area: Vector2, centre: Vector2, cell: float, light: float) -> void:
	var px := float(int(settings()["px"]))
	scale = Vector2(cell / px, cell / px)
	position = origin + area * 0.5 - centre * cell
	modulate = Color(light, light, light)


func _fill(c: Vector2i) -> void:
	var n := int(settings()["chunk"])
	var layer := TileMapLayer.new()
	layer.tile_set = tile_set
	layer.position = Vector2(c.x * n, c.y * n) * float(int(settings()["px"]))
	add_child(layer)
	var all := kinds()
	var over: TileMapLayer = null
	if interior_id == "":
		over = TileMapLayer.new()
		over.tile_set = tile_set
		over.position = layer.position
		over.visible = level == 0
		add_child(over)
		things[c] = over
	for dz in n:
		for dx in n:
			var x := c.x * n + dx
			var z := c.y * n + dz
			if interior_id != "":
				var ik := _kind_at(x, z)
				if ik != "":
					layer.set_cell(Vector2i(dx, dz), 0, Vector2i(all.find(ik), 0))
				continue
			var tile := GameWorldGen.tile(d, x, z)   # once for the ground and what stands on it
			var built := GameBuild.kind_at(d, x, GameBuild.SURFACE, z)
			layer.set_cell(Vector2i(dx, dz), 0, Vector2i(all.find(kind_for(tile, built)), 0))
			var thing := _thing_from(tile, built, x, z)
			if thing != "":
				over.set_cell(Vector2i(dx, dz), 0, Vector2i(all.find(thing), 0))
	layers[c] = layer
	fills += 1
	if level > 0:
		var shade := float(settings()["below_shade"])
		layer.modulate = Color(shade, shade, shade)
		_fill_upper(c)


## The pieces of the shown storey in a chunk, as a layer over the ground's: a tile where something is built, none elsewhere.
func _fill_upper(c: Vector2i) -> void:
	var n := int(settings()["chunk"])
	var layer := TileMapLayer.new()
	layer.tile_set = tile_set
	layer.position = Vector2(c.x * n, c.y * n) * float(int(settings()["px"]))
	add_child(layer)
	var all := kinds()
	for dz in n:
		for dx in n:
			var kind := GameBuild.kind_at(d, c.x * n + dx, GameBuild.SURFACE - level, c.y * n + dz)
			if kind != "":
				layer.set_cell(Vector2i(dx, dz), 0, Vector2i(all.find(kind), 0))
	uppers[c] = layer


## What stands on a tile: its node (a tree, herb patch, bone pile or outcrop) unless it has been gathered or something is built
## there, else a shaft dug at the first depth, else nothing.
func _thing_from(tile: Dictionary, built: String, x: int, z: int) -> String:
	if built != "":
		return ""
	var node: Dictionary = tile.get("node", {})
	if not node.is_empty() and not bool(tile.get("water", false)) and not GameCompanions.depleted(d, x, z):
		return str(node["kind"])
	if GameMine.is_dug(d, GameWorldGen.MINE_SITE, x, 0, z):
		return "dug"
	return ""


func _thing_at(x: int, z: int) -> String:
	if interior_id != "":
		return ""
	return _thing_from(GameWorldGen.tile(d, x, z), GameBuild.kind_at(d, x, GameBuild.SURFACE, z), x, z)


func _kind_at(x: int, z: int) -> String:
	if interior_id != "":
		return str(interior.get("%d,%d" % [x, z], ""))   # nothing where the interior has no cell
	return kind_for(GameWorldGen.tile(d, x, z), GameBuild.kind_at(d, x, GameBuild.SURFACE, z))


## Redraws one tile (after something is built or taken down there), when its chunk is kept.
func refresh_cell(x: int, z: int) -> void:
	var c := chunk_of(x, z)
	if not layers.has(c):
		return
	var n := int(settings()["chunk"])
	var here := _kind_at(x, z)
	var local := Vector2i(x - c.x * n, z - c.y * n)
	if here == "":
		(layers[c] as TileMapLayer).erase_cell(local)
	else:
		(layers[c] as TileMapLayer).set_cell(local, 0, Vector2i(kinds().find(here), 0))
	if things.has(c):
		var thing := _thing_at(x, z)
		if thing == "":
			(things[c] as TileMapLayer).erase_cell(local)
		else:
			(things[c] as TileMapLayer).set_cell(local, 0, Vector2i(kinds().find(thing), 0))
	if level > 0 and uppers.has(c):
		var kind := GameBuild.kind_at(d, x, GameBuild.SURFACE - level, z)
		if kind == "":
			(uppers[c] as TileMapLayer).erase_cell(local)
		else:
			(uppers[c] as TileMapLayer).set_cell(local, 0, Vector2i(kinds().find(kind), 0))


static func validate() -> Array:
	var bad: Array = []
	var s: Dictionary = settings() if GameSandbox.data().has("tiles") else {}
	for k in ["px", "chunk", "keep", "colors", "below_shade"]:
		if not s.has(k):
			bad.append("sandbox.json: tiles.%s is missing" % k)
	if not bad.is_empty():
		return bad
	if int(s["px"]) < 4 or int(s["chunk"]) < 4 or int(s["keep"]) < 0:
		bad.append("sandbox.json: tiles px and chunk must be at least 4 and keep 0 or more")
	if float(s["below_shade"]) <= 0.0 or float(s["below_shade"]) > 1.0:
		bad.append("sandbox.json: tiles.below_shade must be above 0 and at most 1")
	var glyphs: Dictionary = s.get("glyphs", {})
	for k in glyphs:
		if not kinds().has(k):
			bad.append("sandbox.json: tiles.glyphs has '%s', which is not a kind" % k)
			continue
		var g: Dictionary = glyphs[k]
		if not g.has("rows") or not g.has("palette") or typeof(g["rows"]) != TYPE_ARRAY or (g["rows"] as Array).size() != 8:
			bad.append("sandbox.json: glyph '%s' needs 8 rows and a palette" % k)
			continue
		for row in g["rows"]:
			if str(row).length() != 8:
				bad.append("sandbox.json: glyph '%s' has a row that is not 8 wide" % k)
			for ch in str(row):
				if ch != "." and not g["palette"].has(ch):
					bad.append("sandbox.json: glyph '%s' uses '%s', which its palette lacks" % [k, ch])
		for ch in g["palette"]:
			var col: Array = g["palette"][ch]
			if col.size() < 3 or col.size() > 4:
				bad.append("sandbox.json: glyph '%s' palette '%s' needs [r, g, b] or [r, g, b, a]" % [k, ch])
	for nk in GameWorldGen.data()["nodes"]:
		if not glyphs.has(nk):
			bad.append("sandbox.json: the node '%s' has no glyph to be drawn with" % nk)
	if not glyphs.has("dug"):
		bad.append("sandbox.json: a dug shaft has no glyph")
	for k in kinds():
		if not s["colors"].has(k) or typeof(s["colors"][k]) != TYPE_ARRAY or (s["colors"][k] as Array).size() != 3:
			bad.append("sandbox.json: tiles.colors has no [r, g, b] for '%s'" % k)
	return bad
