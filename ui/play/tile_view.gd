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
var dungeon: DungeonView = null   # a dungeon's floor in its own theme (GameDungeonArt), drawn in place of the chunks while the heir is in one
var level := 0            # the storey shown: 0 is the ground; above it the ground is dimmed and that storey's pieces are drawn over it
var uppers := {}          # Vector2i chunk -> TileMapLayer of the shown storey's pieces (empty cells where nothing is built)
var decor := {}           # Vector2i chunk -> TileMapLayer of what lies on the ground under the nodes: tones, tufts, flowers, a landmark (GameWilds, GameWildsSites)
var things := {}          # Vector2i chunk -> TileMapLayer of what stands on the ground: nodes (trees, herbs, bones, rock) and dug shafts
var roofs := {}           # Vector2i chunk -> TileMapLayer of the roofs seen from outside (a doll house's lid): shown on the ground floor only
var roof_steps := {}      # "x,z" -> how far a roof has lifted (GameReveal: 1 to steps; a roof not listed is whole)
var _heir_tile := Vector2i(-100000, -100000)
var _roofs_dirty := true

const JOINS := 16         # a wall's look by which sides have a wall or door beside it (N 1, E 2, S 4, W 8), the tiles after the kinds in the atlas
const ROOF_ALT := 100     # the alternative tile of a roof lifted k steps is ROOF_ALT + k (faded by k of `steps`)


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
	out.append("deep")   # water over a bed well under the sea level (GameRelief.kind)
	out.append("snow")   # the high peaks
	out.append("ford")   # the shallows across a river (GameRelief.kind), walked
	out.append_array(GameWilds.glyph_ids())   # the look of the wilds: ground tones and decor, tree looks, landmarks (wilds.json)
	return out


## Every glyph there is: those of sandbox.json and those of the wilds.
static func all_glyphs() -> Dictionary:
	var out: Dictionary = (settings().get("glyphs", {}) as Dictionary).duplicate()
	out.merge(GameWilds.glyphs())
	return out


## The kind a tile is drawn as: the piece built on it, else deep or shallow water, snow on the high peaks, or its biome
## (GameRelief.kind).
static func kind_for(tile: Dictionary, built: String) -> String:
	if built != "":
		return built
	return GameRelief.kind(tile)


## The alternative tile a brightness step is drawn with: 0 is the colour as it is, then +1, -1, +2, -2 and so on, so a tile
## set in without an alternative is never shaded by mistake.
static func alt_for(step: int) -> int:
	if step == 0:
		return 0
	return absi(step) * 2 - (1 if step > 0 else 0)


## The alternative a tile is set with: the light step of bare ground (land only; water, anything built and anything that is
## not the open world's ground are not shaded).
func _alt_at(x: int, z: int, built: String, water: bool) -> int:
	if built != "" or water or interior_id != "":
		return 0
	return alt_for(GameRelief.step_at(d, x, z))


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
	var img := Image.create(px * (all.size() + JOINS), px, false, Image.FORMAT_RGBA8)
	var colors: Dictionary = settings()["colors"]
	var glyphs: Dictionary = all_glyphs()
	for i in all.size():
		if glyphs.has(all[i]):
			_paint_glyph(img, i * px, px, glyphs[all[i]])   # a thing on the ground: clear but for its drawing
			continue
		var c := Color(float(colors[all[i]][0]), float(colors[all[i]][1]), float(colors[all[i]][2]))
		img.fill_rect(Rect2i(i * px, 0, px, px), c.darkened(0.12))
		img.fill_rect(Rect2i(i * px + 1, 1, px - 2, px - 2), c)
	_paint_joins(img, all.find("wall") * px, all.size() * px, px)
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(px, px)
	var steps := int(GameRelief.setting("steps"))
	for i in all.size():
		src.create_tile(Vector2i(i, 0))
		for step in range(-steps, steps + 1):
			if step == 0:
				continue
			var alt := alt_for(step)
			src.create_alternative_tile(Vector2i(i, 0), alt)
			var m := GameRelief.light(step)
			src.get_tile_data(Vector2i(i, 0), alt).modulate = Color(m, m, m)
	for m in JOINS:
		src.create_tile(Vector2i(all.size() + m, 0))   # the wall joined every way there is, no alternatives
	var roof_i := all.find("roof")
	var lift := int(GameReveal.setting("steps"))
	for k in range(1, lift):
		src.create_alternative_tile(Vector2i(roof_i, 0), ROOF_ALT + k)
		src.get_tile_data(Vector2i(roof_i, 0), ROOF_ALT + k).modulate = Color(1, 1, 1, 1.0 - float(k) / float(lift))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(px, px)
	ts.add_source(src, 0)
	return ts


## The wall at `from` (the wall's own tile) drawn again at `to` for each join mask: a side with no wall or door beside it gets an
## edge line (`wall_edge`), a side with one is open, so walls run on into each other and a corner is a corner.
static func _paint_joins(img: Image, from: int, to: int, px: int) -> void:
	var block := maxi(1, px / 8)
	var e: Array = settings().get("wall_edge", [0.2, 0.17, 0.15])
	var edge := Color(float(e[0]), float(e[1]), float(e[2]))
	for m in JOINS:
		var x0 := to + m * px
		img.blit_rect(img, Rect2i(from, 0, px, px), Vector2i(x0, 0))
		if m & 4:   # a wall to the south: the shadow row at the foot gives way to stone
			img.blit_rect(img, Rect2i(x0, px - 2 * block, px, block), Vector2i(x0, px - block))
		if not (m & 1):
			img.fill_rect(Rect2i(x0, 0, px, block), edge)
		if not (m & 4):
			img.fill_rect(Rect2i(x0, px - block, px, block), edge)
		if not (m & 2):
			img.fill_rect(Rect2i(x0 + px - block, 0, block, px), edge)
		if not (m & 8):
			img.fill_rect(Rect2i(x0, 0, block, px), edge)


## Which sides of a wall at (x, y, z) have a wall or a door beside them: N (z - 1) 1, E 2, S 4, W 8.
static func join_mask(dyn: GameDynasty, x: int, y: int, z: int) -> int:
	var m := 0
	for pair in [[1, 0, -1], [2, 1, 0], [4, 0, 1], [8, -1, 0]]:
		var k := GameBuild.kind_at(dyn, x + int(pair[1]), y, z + int(pair[2]))
		if k == "wall" or k == "door":
			m |= int(pair[0])
	return m


## The atlas cell of a kind at a place: a wall joined to its neighbours, anything else its own tile.
func _coords(kind: String, x: int, y: int, z: int) -> Vector2i:
	var all := kinds()
	if kind == "wall" and interior_id == "":
		return Vector2i(all.size() + join_mask(d, x, y, z), 0)
	return Vector2i(all.find(kind), 0)


## The kind a layer's cell shows (a joined wall is a wall), or "" for an empty cell.
static func cell_kind(layer: TileMapLayer, local: Vector2i) -> String:
	if layer.get_cell_source_id(local) < 0:
		return ""
	var all := kinds()
	var cx := layer.get_cell_atlas_coords(local).x
	return "wall" if cx >= all.size() else str(all[cx])


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
	if dungeon != null:
		return   # a dungeon is drawn whole
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
			if decor.has(c):
				(decor[c] as TileMapLayer).queue_free()
				decor.erase(c)
			if things.has(c):
				(things[c] as TileMapLayer).queue_free()
				things.erase(c)
			if roofs.has(c):
				(roofs[c] as TileMapLayer).queue_free()
				roofs.erase(c)


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
	for c in decor:
		(decor[c] as TileMapLayer).visible = level == 0
	for c in roofs:
		(roofs[c] as TileMapLayer).visible = level == 0   # a storey is looked at from inside: no lid
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
	for c in decor.keys():
		(decor[c] as TileMapLayer).queue_free()
	decor.clear()
	for c in things.keys():
		(things[c] as TileMapLayer).queue_free()
	things.clear()
	for c in roofs.keys():
		(roofs[c] as TileMapLayer).queue_free()
	roofs.clear()
	roof_steps.clear()
	level = 0   # an interior has one floor
	if dungeon != null:
		dungeon.queue_free()
		dungeon = null
	if id != "" and GameDungeons.is_dungeon(id):
		dungeon = DungeonView.new()
		dungeon.setup(d, id, cells)
		add_child(dungeon)


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
	var under: TileMapLayer = null
	if interior_id == "":
		under = TileMapLayer.new()
		under.tile_set = tile_set
		under.position = layer.position
		under.visible = level == 0
		add_child(under)
		decor[c] = under
		over = TileMapLayer.new()
		over.tile_set = tile_set
		over.position = layer.position
		over.visible = level == 0
		add_child(over)
		things[c] = over
		var lid := TileMapLayer.new()
		lid.tile_set = tile_set
		lid.position = layer.position
		lid.visible = level == 0
		add_child(lid)
		roofs[c] = lid
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
			layer.set_cell(Vector2i(dx, dz), 0, _coords(kind_for(tile, built), x, GameBuild.SURFACE, z), _alt_at(x, z, built, bool(tile["water"])))
			var ground := _decor_from(tile, built, x, z)
			if ground != "":
				under.set_cell(Vector2i(dx, dz), 0, Vector2i(all.find(ground), 0))
			var thing := _thing_from(tile, built, x, z)
			if thing != "":
				over.set_cell(Vector2i(dx, dz), 0, Vector2i(all.find(thing), 0))
			if not d.built.is_empty() and GameReveal.roofed(d, x, z):
				_set_roof(Vector2i(x, z), c)
	layers[c] = layer
	fills += 1
	if level > 0:
		var shade := float(settings()["below_shade"])
		layer.modulate = Color(shade, shade, shade)
		_fill_upper(c)


## Draws (or clears) the roof over a column in its chunk's lid layer, lifted as far as `roof_steps` says.
func _set_roof(cell: Vector2i, c: Vector2i) -> void:
	if not roofs.has(c):
		return
	var n := int(settings()["chunk"])
	var local := Vector2i(cell.x - c.x * n, cell.y - c.y * n)
	var layer: TileMapLayer = roofs[c]
	var step := int(roof_steps.get("%d,%d" % [cell.x, cell.y], 0))
	if not GameReveal.roofed(d, cell.x, cell.y) or step >= int(GameReveal.setting("steps")):
		layer.erase_cell(local)
	else:
		layer.set_cell(local, 0, Vector2i(kinds().find("roof"), 0), 0 if step == 0 else ROOF_ALT + step)


## Tells the view where the heir is (tiles): the roofs near them lift, those far off go back on. Only does work when the heir's tile
## changes or something was built or taken down.
func set_heir(x: float, z: float) -> void:
	if interior_id != "" or level != 0:
		return
	var t := Vector2i(floori(x), floori(z))
	if t == _heir_tile and not _roofs_dirty:
		return
	_heir_tile = t
	_roofs_dirty = false
	var want := GameReveal.roof_steps(d, float(t.x) + 0.5, float(t.y) + 0.5)
	var changed: Array = []
	for k in roof_steps:
		if int(want.get(k, 0)) != int(roof_steps[k]):
			changed.append(k)
	for k in want:
		if int(roof_steps.get(k, 0)) != int(want[k]):
			changed.append(k)
	roof_steps = want
	for k in changed:
		var parts := str(k).split(",")
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		_set_roof(cell, chunk_of(cell.x, cell.y))


## Whether a column is under a roof that is whole (what is under it is not seen: the screen draws nobody there).
func covered(x: int, z: int) -> bool:
	return interior_id == "" and level == 0 and not roof_steps.has("%d,%d" % [x, z]) and not d.built.is_empty() and GameReveal.roofed(d, x, z)


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
				layer.set_cell(Vector2i(dx, dz), 0, _coords(kind, c.x * n + dx, GameBuild.SURFACE - level, c.y * n + dz))
	uppers[c] = layer


## What stands on a tile: its node (a tree, herb patch, bone pile or outcrop) unless it has been gathered or something is built
## there, else a shaft dug at the first depth, else nothing.
func _thing_from(tile: Dictionary, built: String, x: int, z: int) -> String:
	if built != "":
		return ""
	var node: Dictionary = tile.get("node", {})
	if not node.is_empty() and not bool(tile.get("water", false)) and not GameCompanions.depleted(d, x, z):
		return GameWilds.node_look(d.seed_value, tile)   # the node's own glyph, or the look its biome's trees give it
	if GameMine.is_dug(d, GameWorldGen.MINE_SITE, x, 0, z):
		return "dug"
	return ""


## What lies on a tile's ground, under its node: a landmark's glyph, else a tone or decoration of the wilds, nothing where
## something is built.
func _decor_from(tile: Dictionary, built: String, x: int, z: int) -> String:
	if built != "":
		return ""
	var site := GameWildsSites.glyph_at(d, x, z)
	if site != "":
		return site
	return GameWilds.ground_glyph(d.seed_value, tile)


func _thing_at(x: int, z: int) -> String:
	if interior_id != "":
		return ""
	return _thing_from(GameWorldGen.tile(d, x, z), GameBuild.kind_at(d, x, GameBuild.SURFACE, z), x, z)


func _kind_at(x: int, z: int) -> String:
	if interior_id != "":
		return str(interior.get("%d,%d" % [x, z], ""))   # nothing where the interior has no cell
	return kind_for(GameWorldGen.tile(d, x, z), GameBuild.kind_at(d, x, GameBuild.SURFACE, z))


## Redraws one tile (after something is built or taken down there), when its chunk is kept.
func refresh_cell(x: int, z: int, spread: bool = true) -> void:
	if dungeon != null:
		dungeon.refresh_cell(x, z)
		return
	if spread and interior_id == "":
		for off in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var k := GameBuild.kind_at(d, x + off.x, GameBuild.SURFACE, z + off.y)
			var ku := GameBuild.kind_at(d, x + off.x, GameBuild.SURFACE - level, z + off.y) if level > 0 else ""
			if k == "wall" or ku == "wall":
				refresh_cell(x + off.x, z + off.y, false)   # a wall beside joins to this one
	var c := chunk_of(x, z)
	if not layers.has(c):
		return
	var n := int(settings()["chunk"])
	var here := _kind_at(x, z)
	var local := Vector2i(x - c.x * n, z - c.y * n)
	if here == "":
		(layers[c] as TileMapLayer).erase_cell(local)
	else:
		var wet := interior_id == "" and bool(GameWorldGen.tile(d, x, z)["water"])
		var built_here := GameBuild.kind_at(d, x, GameBuild.SURFACE, z) if interior_id == "" else "interior"
		(layers[c] as TileMapLayer).set_cell(local, 0, _coords(here, x, GameBuild.SURFACE, z), _alt_at(x, z, built_here, wet))
	if decor.has(c):
		var ground := "" if interior_id != "" else _decor_from(GameWorldGen.tile(d, x, z), GameBuild.kind_at(d, x, GameBuild.SURFACE, z), x, z)
		if ground == "":
			(decor[c] as TileMapLayer).erase_cell(local)
		else:
			(decor[c] as TileMapLayer).set_cell(local, 0, Vector2i(kinds().find(ground), 0))
	if things.has(c):
		var thing := _thing_at(x, z)
		if thing == "":
			(things[c] as TileMapLayer).erase_cell(local)
		else:
			(things[c] as TileMapLayer).set_cell(local, 0, Vector2i(kinds().find(thing), 0))
	if roofs.has(c) and interior_id == "":
		_set_roof(Vector2i(x, z), c)
		_roofs_dirty = true
	if level > 0 and uppers.has(c):
		var kind := GameBuild.kind_at(d, x, GameBuild.SURFACE - level, z)
		if kind == "":
			(uppers[c] as TileMapLayer).erase_cell(local)
		else:
			(uppers[c] as TileMapLayer).set_cell(local, 0, _coords(kind, x, GameBuild.SURFACE - level, z))


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
	var glyphs: Dictionary = all_glyphs()
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
	for pk in GameBuild.pieces():
		if glyphs.has(pk):
			for row in glyphs[pk].get("rows", []):
				for ch in str(row):
					if ch == "." or (glyphs[pk]["palette"].has(ch) and (glyphs[pk]["palette"][ch] as Array).size() > 3):
						bad.append("sandbox.json: the built piece '%s' has a glyph that is clear in places: it is the whole tile, so every pixel needs a colour" % pk)
						break
	for nk in GameWorldGen.data()["nodes"]:
		if not glyphs.has(nk):
			bad.append("sandbox.json: the node '%s' has no glyph to be drawn with" % nk)
	if not glyphs.has("dug"):
		bad.append("sandbox.json: a dug shaft has no glyph")
	for k in kinds():
		if GameWilds.glyphs().has(k) and not s["colors"].has(k):
			continue   # a glyph's kind is clear but for its drawing: it needs no flat colour
		if not s["colors"].has(k) or typeof(s["colors"][k]) != TYPE_ARRAY or (s["colors"][k] as Array).size() != 3:
			bad.append("sandbox.json: tiles.colors has no [r, g, b] for '%s'" % k)
	return bad
