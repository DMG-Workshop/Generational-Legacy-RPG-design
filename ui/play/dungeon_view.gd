## A dungeon's floor drawn in its own theme (rendering only; the look is GameDungeonArt, the contents GameDungeons). It is the
## interior view `TileView.set_interior` hands a dungeon to: a ground layer (floor in three looks, walls seen from the room or from
## above, doors and the way out) and a layer of things over it (ambient props, torches on walls, containers closed or open, traps
## that have gone off, features), from one atlas of 16 pixel tiles made from the theme's 8 by 8 glyphs. It reads the dynasty to
## know what is open; it changes nothing.
class_name DungeonView
extends Node2D

const PX := 16

var d: GameDynasty
var space_id := ""
var cells := {}
var tile_set: TileSet
var ground: TileMapLayer
var things: TileMapLayer
var names: Array = []        # the atlas order: the tile glyphs, the theme's props, the container shapes, "trap_sprung"


func setup(dyn: GameDynasty, id: String, grid: Dictionary) -> void:
	d = dyn
	space_id = id
	cells = grid
	_make_tileset()
	ground = TileMapLayer.new()
	ground.tile_set = tile_set
	add_child(ground)
	things = TileMapLayer.new()
	things.tile_set = tile_set
	add_child(things)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for k in cells:
		var p := GameInterior._parse(k)
		_set_ground(p.x, p.y)
		_set_thing(p.x, p.y)


## The glyph names of a theme in atlas order.
static func atlas_names(place: String) -> Array:
	var out: Array = GameDungeonArt.TILES.duplicate()
	var t := GameDungeonArt.theme(place)
	for g in t.get("glyphs", {}):
		if g not in out:
			out.append(g)
	for g in GameDungeonArt.data()["shared"]["containers"]:
		out.append(g)
	out.append("trap_sprung")
	return out


func _make_tileset() -> void:
	names = atlas_names(space_id)
	var img := Image.create(PX * names.size(), PX, false, Image.FORMAT_RGBA8)
	for i in names.size():
		var g := GameDungeonArt.glyph(space_id, str(names[i])) if str(names[i]) != "trap_sprung" else _trap_glyph()
		var block := PX / 8
		var rows: Array = g["rows"]
		for y in rows.size():
			var row := str(rows[y])
			for x in row.length():
				var ch := row.substr(x, 1)
				if g["palette"].has(ch):
					img.fill_rect(Rect2i(i * PX + x * block, y * block, block, block), g["palette"][ch])
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(PX, PX)
	for i in names.size():
		src.create_tile(Vector2i(i, 0))
	tile_set = TileSet.new()
	tile_set.tile_size = Vector2i(PX, PX)
	tile_set.add_source(src, 0)


static func _trap_glyph() -> Dictionary:
	return {"rows": ["........", "........", ".k.k.k..", ".kkkkkk.", "k.k.k.k.", ".kkkkkk.", "........", "........"], "palette": {"k": Color("#c8c4b0")}}


func _atlas(name: String) -> Vector2i:
	return Vector2i(names.find(name), 0)


## The ground tile name of a cell.
func ground_name(x: int, z: int) -> String:
	var kind := str(cells.get("%d,%d" % [x, z], ""))
	match kind:
		"floor", "person", "prop":
			return GameDungeonArt.floor_kind(space_id, x, z)
		"wall":
			return GameDungeonArt.wall_kind(cells, x, z)
		"door":
			return "door"
		"exit":
			return "exit"
	return ""


## The thing drawn over a cell: a container (closed or open), a sprung trap, or an ambient prop; "" for nothing.
func thing_name(x: int, z: int) -> String:
	var lay := GameDungeons.layout(space_id)
	for c in lay["containers"]:
		if int(c["x"]) == x and int(c["z"]) == z:
			return str(c["kind"]) + ("_open" if GameDungeons.container_open(d, space_id, str(c["id"])) else "")
	for t in lay["traps"]:
		if int(t["x"]) == x and int(t["z"]) == z and GameDungeons.trap_sprung(d, space_id, str(t["id"])):
			return "trap_sprung"
	return str(GameDungeonArt.props(space_id).get("%d,%d" % [x, z], ""))


func _set_ground(x: int, z: int) -> void:
	var n := ground_name(x, z)
	if n == "":
		ground.erase_cell(Vector2i(x, z))
	else:
		ground.set_cell(Vector2i(x, z), 0, _atlas(n))


func _set_thing(x: int, z: int) -> void:
	var n := thing_name(x, z)
	if n == "" or names.find(n) < 0:
		things.erase_cell(Vector2i(x, z))
	else:
		things.set_cell(Vector2i(x, z), 0, _atlas(n))


## Redraws one cell (a container opened, a trap sprung).
func refresh_cell(x: int, z: int) -> void:
	_set_thing(x, z)
