## The tile view (ui/play/tile_view.gd): the kinds a tile can look like and the colour each needs; a tile's kind (a built piece
## over water over biome); chunks (floored, negative tiles too) and the chunks a view wants; the atlas; chunks filled once
## and freed when far from the view; a changed tile redrawn; the view placed by cell size, centre and light; the data checks;
## and the sandbox screen built over it, with the map clipped and under the bar.
## Run: godot --headless --path . -s res://tests/test_game_tile_view.gd
extends SceneTree

var fails := 0
var checks := 0


class FakeApp extends Node:
	var dynasty: GameDynasty

	func show_state() -> void:
		pass


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	test_data()
	test_rules()
	test_atlas()
	test_chunks()
	test_cells()
	test_place()
	test_levels()
	await test_screen()
	print("tile view tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn() -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 5000
	GameCraft.add_material(d, "oak", 100)
	return d


func test_data() -> void:
	ok(TileView.validate().is_empty(), "the shipped data passes: %s" % str(TileView.validate()))
	var colors: Dictionary = TileView.settings()["colors"]
	for k in TileView.kinds():
		if GameWilds.glyphs().has(k):
			continue   # a glyph of the wilds is clear but for its drawing: no flat colour
		ok(colors.has(k), "'%s' has a colour" % k)
	var keep: Array = colors["wall"]
	colors.erase("wall")
	ok(not TileView.validate().is_empty(), "a kind with no colour is caught")
	colors["wall"] = [1.0, 2.0]
	ok(not TileView.validate().is_empty(), "a colour that is not r, g, b is caught")
	colors["wall"] = keep
	var chunk: int = TileView.settings()["chunk"]
	TileView.settings()["chunk"] = 1
	ok(not TileView.validate().is_empty(), "a chunk too small is caught")
	TileView.settings()["chunk"] = chunk
	ok(TileView.validate().is_empty(), "and putting them back clears it")


func test_rules() -> void:
	ok(TileView.kind_for({"water": false, "biome": "forest"}, "") == "forest", "a dry tile looks like its biome")
	ok(TileView.kind_for({"water": true, "biome": "forest"}, "") == "water", "a wet one looks like water")
	ok(TileView.kind_for({"water": true, "biome": "forest"}, "floor") == "floor", "a piece built on it covers the ground, a bridge included")
	ok(TileView.kind_for({}, "") == "plains", "a tile with nothing known is plains")
	var n: int = TileView.settings()["chunk"]
	ok(TileView.chunk_of(0, 0) == Vector2i(0, 0) and TileView.chunk_of(n - 1, n - 1) == Vector2i(0, 0) and TileView.chunk_of(n, n) == Vector2i(1, 1), "chunks are chunk tiles across")
	ok(TileView.chunk_of(-1, -1) == Vector2i(-1, -1) and TileView.chunk_of(-n, -n - 1) == Vector2i(-1, -2), "and floor for tiles below zero")
	var w := TileView.wanted(Vector2(0.5, 0.5), Vector2(1, 1), 0)
	ok(w.has(Vector2i(0, 0)) and w.has(Vector2i(-1, -1)) and w.size() == 4, "a view over a corner wants the four chunks it touches: %d" % w.size())
	ok(TileView.wanted(Vector2(5, 5), Vector2(1, 1), 1).size() == 9, "and `keep` adds a ring all round it")


func test_atlas() -> void:
	var ts := TileView.make_tileset()
	var src: TileSetAtlasSource = ts.get_source(0)
	var px: int = TileView.settings()["px"]
	ok(ts.tile_size == Vector2i(px, px), "tiles are px square")
	ok(src.get_tiles_count() == TileView.kinds().size() + TileView.JOINS, "the atlas has one tile per kind and one per way a wall can join")
	var img := src.texture.get_image()
	var i := TileView.kinds().find("water")
	var c: Array = TileView.settings()["colors"]["water"]
	var got := img.get_pixel(i * px + px / 2, px / 2)
	ok(absf(got.r - float(c[0])) < 0.01 and absf(got.g - float(c[1])) < 0.01 and absf(got.b - float(c[2])) < 0.01, "a kind's tile is its colour")
	ok(img.get_pixel(i * px, 0) != got, "with a darker edge")


func test_chunks() -> void:
	var d := _dyn()
	var v := TileView.new()
	v.setup(d)
	var b := GameBuild.base()
	var at := Vector2(float(b["x"]), float(b["z"]))
	v.show_view(at, Vector2(8, 6))
	var n := v.layers.size()
	ok(n >= 4 and v.fills == n, "a view fills the chunks it covers: %d" % n)
	v.show_view(at, Vector2(8, 6))
	ok(v.fills == n, "showing the same view fills nothing again")
	v.show_view(at + Vector2(200, 0), Vector2(8, 6))
	ok(not v.layers.has(TileView.chunk_of(int(at.x), int(at.y))), "chunks far from a moved view are let go")
	ok(v.layers.size() <= n + 2, "and the kept ones stay about as many as the view needs: %d" % v.layers.size())
	v.free()


func test_cells() -> void:
	var d := _dyn()
	var v := TileView.new()
	v.setup(d)
	var b := GameBuild.base()
	var x := int(b["x"]) + 2
	var z := int(b["z"])
	v.show_view(Vector2(x, z), Vector2(4, 4))
	var c := TileView.chunk_of(x, z)
	var n: int = TileView.settings()["chunk"]
	var layer: TileMapLayer = v.layers[c]
	var local := Vector2i(x - c.x * n, z - c.y * n)
	var before := layer.get_cell_atlas_coords(local)
	ok(before.x == TileView.kinds().find(v._kind_at(x, z)), "a tile is the kind the world says")
	ok(GameBuild.place(d, "wall", x, GameBuild.SURFACE, z)["ok"], "a wall is built there")
	ok(layer.get_cell_atlas_coords(local) == before, "the view does not know until it is told")
	v.refresh_cell(x, z)
	ok(TileView.cell_kind(layer, local) == "wall", "and then it shows the wall")
	GameBuild.remove(d, x, GameBuild.SURFACE, z)
	v.refresh_cell(x, z)
	ok(layer.get_cell_atlas_coords(local) == before, "taken down, the ground is back")
	v.refresh_cell(x + 900, z)   # a chunk that is not kept: nothing to do and no error
	ok(true, "a tile in a chunk that is not kept is left alone")
	v.free()


func test_place() -> void:
	var v := TileView.new()
	v.setup(_dyn())
	var px: int = TileView.settings()["px"]
	v.place(Vector2(0, 56), Vector2(800, 400), Vector2(10, 20), float(px) * 2.0, 0.5)
	ok(v.scale == Vector2(2, 2), "the view is scaled to the cell size")
	ok(v.position == Vector2(0, 56) + Vector2(400, 200) - Vector2(10, 20) * float(px) * 2.0, "and put so the centre tile is at the middle of the area")
	ok(v.modulate == Color(0.5, 0.5, 0.5), "and dimmed by the light")
	v.free()


func test_levels() -> void:
	var d := _dyn()
	GameCraft.add_material(d, "oak", 100)
	var b := GameBuild.base()
	var x := int(b["x"]) + 1
	var z := int(b["z"])
	GameBuild.place(d, "wall", x, GameBuild.SURFACE, z)
	GameBuild.place(d, "floor", x, GameBuild.SURFACE - 1, z)
	GameBuild.place(d, "floor", x + 1, GameBuild.SURFACE, z)   # a ground-floor piece beside it
	var v := TileView.new()
	v.setup(d)
	v.show_view(Vector2(x, z), Vector2(4, 4))
	ok(v.level == 0 and v.uppers.is_empty(), "on the ground there are no storey layers")
	var c := TileView.chunk_of(x, z)
	var n: int = TileView.settings()["chunk"]
	var local := Vector2i(x - c.x * n, z - c.y * n)
	var shade: float = TileView.settings()["below_shade"]
	v.set_level(1)
	ok(v.level == 1 and v.uppers.size() == v.layers.size(), "at storey 1 each chunk has a layer for it: %d" % v.uppers.size())
	var up: TileMapLayer = v.uppers[c]
	ok(up.get_cell_atlas_coords(local).x == TileView.kinds().find("floor"), "the floor built at that storey is drawn")
	ok(up.get_cell_source_id(local + Vector2i(1, 0)) == -1 and up.get_cell_source_id(local + Vector2i(0, 1)) == -1, "and nothing is drawn where nothing is built (the ground shows through)")
	ok((v.layers[c] as TileMapLayer).modulate == Color(shade, shade, shade), "the ground is dimmed")
	GameBuild.place(d, "wall", x, GameBuild.SURFACE - 1, z + 1)   # needs support: a wall below it
	ok(GameBuild.kind_at(d, x, GameBuild.SURFACE - 1, z + 1) == "", "(a piece with nothing under it is not built)")
	GameBuild.place(d, "wall", x, GameBuild.SURFACE, z + 1)
	GameBuild.place(d, "wall", x, GameBuild.SURFACE - 1, z + 1)
	v.refresh_cell(x, z + 1)
	ok(TileView.cell_kind(up, local + Vector2i(0, 1)) == "wall", "a piece built at the storey shows once the tile is refreshed")
	GameBuild.remove(d, x, GameBuild.SURFACE - 1, z + 1)
	v.refresh_cell(x, z + 1)
	ok(up.get_cell_source_id(local + Vector2i(0, 1)) == -1, "and goes when it is taken down")
	v.set_level(2)
	ok((v.uppers[c] as TileMapLayer).get_cell_source_id(local) == -1, "storey 2 has none of storey 1's pieces")
	v.set_level(99)
	ok(v.level == int(GameBuild.setting("max_storeys")) + 1, "a level above the top is the roof layer over the top storey")
	v.set_level(0)
	ok(v.uppers.is_empty() and (v.layers[c] as TileMapLayer).modulate == Color(1, 1, 1), "back on the ground the layers go and the ground is bright")
	v.set_level(1)
	v.show_view(Vector2(x + 300, z), Vector2(4, 4))
	ok(not v.uppers.has(c) and v.uppers.size() == v.layers.size(), "a chunk that is let go loses its storey layer, a new one gets one: %d of %d" % [v.uppers.size(), v.layers.size()])
	var shade_of_new: float = (v.layers.values()[0] as TileMapLayer).modulate.r
	ok(absf(shade_of_new - shade) < 0.001, "and a new chunk's ground is dimmed at once")
	var keep: float = TileView.settings()["below_shade"]
	TileView.settings()["below_shade"] = 0.0
	ok(not TileView.validate().is_empty(), "a shade of nothing is caught")
	TileView.settings()["below_shade"] = keep
	ok(TileView.validate().is_empty(), "and putting it back clears it")
	v.free()


func test_screen() -> void:
	var d := _dyn()
	var app := FakeApp.new()
	app.dynasty = d
	root.add_child(app)
	var scr: Control = load("res://ui/play/sandbox_screen.gd").new()
	scr.app = app
	scr.position = Vector2.ZERO
	scr.size = Vector2(1280, 720)
	root.add_child(scr)
	await process_frame
	await process_frame
	ok(scr.tile_view != null and scr.tile_view.get_parent() == scr.map, "the screen has a tile view in its map")
	ok(scr.map.clip_contents and scr.map.position.y == scr.BAR, "the map is clipped and starts under the bar")
	ok(scr.tile_view.layers.size() >= 4, "and its chunks are filled: %d" % scr.tile_view.layers.size())
	var kids := scr.get_children()
	ok(kids.find(scr.map) < kids.find(scr.overlay), "the overlay is drawn over the map")
	var bar_index := -1
	for i in kids.size():
		if kids[i] is HBoxContainer and bar_index < 0:
			bar_index = i
	ok(kids.find(scr.overlay) < bar_index, "and the buttons over both")
	ok(scr.overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE and scr.map.mouse_filter == Control.MOUSE_FILTER_IGNORE, "so neither takes the taps")
	scr.sb.build_level = 1
	await process_frame
	ok(scr.tile_view.level == 1 and not scr.tile_view.uppers.is_empty(), "the screen shows the storey the build level is on")
	scr.sb.build_level = 0
	await process_frame
	ok(scr.tile_view.level == 0 and scr.tile_view.uppers.is_empty(), "and goes back to the ground")
	scr.zoom = 2.0
	await process_frame
	ok(absf(scr.tile_view.scale.x - float(scr._cell()) / float(TileView.settings()["px"])) < 0.001, "zooming rescales the tiles")
	scr.queue_free()
	app.queue_free()
