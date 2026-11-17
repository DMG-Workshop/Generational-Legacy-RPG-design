## What stands on the ground in the tile view (roadmap: tiles): trees, herb patches, bone piles and outcrops (GameWorldGen's nodes)
## and dug shafts are drawn in a layer over the ground from small pixel glyphs, a gathered node is not drawn until it regrows, a
## built piece covers what was there, the layer is hidden upstairs and absent indoors, a tile redraws when the sandbox says it
## changed (a node foraged, a shaft dug), and the data's glyphs are checked.
## Run: godot --headless --path . -s res://tests/test_game_tile_things.gd
extends SceneTree

var fails := 0
var checks := 0


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
	test_atlas()
	test_layer()
	test_changes()
	test_sandbox()
	await test_screen()
	print("tile things tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh() -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


## A land tile with a node, near the family's base: {x, z, kind}.
func _node_tile(d: GameDynasty, want: String = "") -> Dictionary:
	var b := GameBuild.base()
	for r in [0, 30, 60, 90]:
		for dz in range(-30, 31):
			for dx in range(-30, 31):
				var x: int = int(b["x"]) + dx + r
				var z: int = int(b["z"]) + dz + r
				var t := GameWorldGen.tile(d, x, z)
				if not t["node"].is_empty() and not bool(t["water"]) and (want == "" or str(t["node"]["kind"]) == want):
					return {"x": x, "z": z, "kind": str(t["node"]["kind"])}
	return {}


func _view(d: GameDynasty) -> TileView:
	var v := TileView.new()
	v.setup(d)
	root.add_child(v)
	return v


func test_data() -> void:
	ok(TileView.validate().is_empty(), "the shipped data passes: %s" % str(TileView.validate()))
	var kinds := TileView.kinds()
	for k in GameWorldGen.data()["nodes"]:
		ok(kinds.has(k), "the node '%s' is a kind" % k)
	ok(kinds.has("dug"), "and so is a dug shaft")
	var g: Dictionary = TileView.settings()["glyphs"]
	var keep: Variant = g["oak_tree"]
	g.erase("oak_tree")
	ok(not TileView.validate().is_empty(), "a node with no glyph is caught")
	g["oak_tree"] = keep
	var rows: Array = g["oak_tree"]["rows"]
	var row0: Variant = rows[0]
	rows[0] = "..ggg"
	ok(not TileView.validate().is_empty(), "a glyph row of the wrong width is caught")
	rows[0] = "..gggg?."
	ok(not TileView.validate().is_empty(), "a glyph character the palette lacks is caught")
	rows[0] = row0
	g["ghost"] = keep
	ok(not TileView.validate().is_empty(), "a glyph for something that is not a kind is caught")
	g.erase("ghost")
	ok(TileView.validate().is_empty(), "and mending the data clears it")


func test_atlas() -> void:
	var ts := TileView.make_tileset()
	var src: TileSetAtlasSource = ts.get_source(0)
	var img: Image = src.texture.get_image()
	var kinds := TileView.kinds()
	var px := int(TileView.settings()["px"])
	var tree := kinds.find("oak_tree")
	ok(img.get_pixel(tree * px, 0).a == 0.0, "a node's tile is clear where its glyph has nothing")
	ok(img.get_pixel(tree * px + 7, 7).a > 0.9, "and drawn where it has (the middle of the crown)")
	var plains := kinds.find("plains")
	ok(img.get_pixel(plains * px + 4, 4).a == 1.0, "a ground tile is solid as before")
	var dug := kinds.find("dug")
	var a := img.get_pixel(dug * px + 6, 6).a
	ok(a > 0.5 and a < 1.0, "a shaft is a dark mark with some of the ground showing: %.2f" % a)


func test_layer() -> void:
	var d := _fresh()
	var site := _node_tile(d)
	ok(not site.is_empty(), "(found a node tile)")
	var v := _view(d)
	var c := TileView.chunk_of(site["x"], site["z"])
	var n := int(TileView.settings()["chunk"])
	v.show_view(Vector2(float(site["x"]), float(site["z"])), Vector2(4, 4))
	ok(v.things.has(c), "each chunk has a layer for what stands on it")
	var local := Vector2i(site["x"] - c.x * n, site["z"] - c.y * n)
	var kinds := TileView.kinds()
	ok((v.things[c] as TileMapLayer).get_cell_atlas_coords(local).x == kinds.find(site["kind"]), "the node is drawn as its kind (%s)" % site["kind"])
	ok((v.layers[c] as TileMapLayer).get_cell_atlas_coords(local).x == kinds.find(TileView.kind_for(GameWorldGen.tile(d, site["x"], site["z"]), "")), "over the ground it stands on")
	# no node, nothing
	var empty := Vector2i(-1, -1)
	for dx in range(1, n):
		var t := GameWorldGen.tile(d, c.x * n + dx, c.y * n)
		if t["node"].is_empty():
			empty = Vector2i(dx, 0)
			break
	ok(empty.x >= 0 and (v.things[c] as TileMapLayer).get_cell_source_id(empty) == -1, "a tile with no node has nothing on it")
	# upstairs the layer is hidden, downstairs shown
	v.set_level(1)
	ok(not (v.things[c] as TileMapLayer).visible, "upstairs the ground's things are hidden")
	v.set_level(0)
	ok((v.things[c] as TileMapLayer).visible, "and shown again on the ground")
	# a chunk made while upstairs is hidden too
	v.set_level(1)
	v.show_view(Vector2(float(site["x"]) + 60.0, float(site["z"])), Vector2(4, 4))
	var far := TileView.chunk_of(int(site["x"]) + 60, int(site["z"]))
	ok(v.things.has(far) and not (v.things[far] as TileMapLayer).visible, "a chunk filled upstairs is hidden")
	ok(not v.things.has(c), "and chunks left behind lose theirs")
	# an interior has none
	v.set_level(0)
	v.set_interior("world/hearthmere/store", GameInterior.cells("world/hearthmere/store"))
	v.show_view(Vector2(0, 0), Vector2(8, 6))
	ok(v.things.is_empty(), "indoors there is no layer of things")
	v.free()


func test_changes() -> void:
	var d := _fresh()
	var site := _node_tile(d)
	var v := _view(d)
	var c := TileView.chunk_of(site["x"], site["z"])
	var n := int(TileView.settings()["chunk"])
	var local := Vector2i(site["x"] - c.x * n, site["z"] - c.y * n)
	v.show_view(Vector2(float(site["x"]), float(site["z"])), Vector2(4, 4))
	var kinds := TileView.kinds()
	# gathered: not drawn until it regrows
	d.gathered[GameCompanions.node_key(site["x"], site["z"])] = float(d.world.year)
	v.refresh_cell(site["x"], site["z"])
	ok((v.things[c] as TileMapLayer).get_cell_source_id(local) == -1, "a gathered node is not drawn")
	d.world.year += float(GameCompanions.setting("regrow_years")) + 0.1
	v.refresh_cell(site["x"], site["z"])
	ok((v.things[c] as TileMapLayer).get_cell_atlas_coords(local).x == kinds.find(site["kind"]), "and is drawn again when it has regrown")
	# a built piece covers it
	d.built[GameBuild.key(site["x"], GameBuild.SURFACE, site["z"])] = "floor"
	v.refresh_cell(site["x"], site["z"])
	ok((v.things[c] as TileMapLayer).get_cell_source_id(local) == -1 and (v.layers[c] as TileMapLayer).get_cell_atlas_coords(local).x == kinds.find("floor"), "a piece built there covers it")
	d.built.erase(GameBuild.key(site["x"], GameBuild.SURFACE, site["z"]))
	# a shaft dug on a tile with no node shows as a shaft
	var bare := Vector2i(-1, -1)
	for dx in range(0, n):
		var t := GameWorldGen.tile(d, c.x * n + dx, c.y * n)
		if t["node"].is_empty() and not bool(t["water"]):
			bare = Vector2i(c.x * n + dx, c.y * n)
			break
	ok(bare.x >= 0, "(found a bare land tile)")
	GameMine.dig(d, GameWorldGen.MINE_SITE, bare.x, 0, bare.y)
	v.refresh_cell(bare.x, bare.y)
	ok((v.things[c] as TileMapLayer).get_cell_atlas_coords(Vector2i(bare.x - c.x * n, 0)).x == kinds.find("dug"), "a shaft dug at the first depth is drawn")
	v.free()


func test_sandbox() -> void:
	var d := _fresh()
	var site := _node_tile(d)
	var s := GameSandbox.start(d)
	s.creatures.clear()
	s.heir = Vector2i(site["x"], site["z"])
	ok(s.dirty.is_empty(), "nothing is dirty to begin with")
	var f := s.forage()
	ok(bool(f["ok"]) and s.dirty.has(Vector2i(int(f["x"]), int(f["z"]))), "foraging marks the node's tile")
	s.dirty.clear()
	var bare := Vector2i(site["x"] + 40, site["z"] + 40)
	s.heir = bare
	var r := s.dig(0)
	ok(bool(r["ok"]) and s.dirty.has(bare), "digging marks the heir's tile")


class FakeApp extends Node:
	var dynasty: GameDynasty

	func show_state() -> void:
		pass


func test_screen() -> void:
	var d := _fresh()
	var site := _node_tile(d)
	var app := FakeApp.new()
	app.dynasty = d
	root.add_child(app)
	var scr: Control = load("res://ui/play/sandbox_screen.gd").new()
	scr.app = app
	scr.size = Vector2(1280, 720)
	root.add_child(scr)
	await process_frame
	await process_frame
	scr.sb.creatures.clear()
	scr.sb.heir = Vector2i(site["x"], site["z"])
	scr.tile_view.show_view(Vector2(float(site["x"]), float(site["z"])), Vector2(6, 6))
	var c := TileView.chunk_of(site["x"], site["z"])
	var n := int(TileView.settings()["chunk"])
	var local := Vector2i(site["x"] - c.x * n, site["z"] - c.y * n)
	ok((scr.tile_view.things[c] as TileMapLayer).get_cell_source_id(local) != -1, "(the node is drawn)")
	scr.sb.forage()
	await process_frame
	await process_frame
	ok(scr.sb.dirty.is_empty(), "the screen takes what the sandbox says changed")
	ok(scr.tile_view.things.has(c) and (scr.tile_view.things[c] as TileMapLayer).get_cell_source_id(local) == -1, "and the foraged node goes from the map")
	scr.queue_free()
	app.queue_free()
