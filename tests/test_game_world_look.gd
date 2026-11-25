## The world's look on the open-world map (ui/play/ground_art.gd, ui/play/world_look.gd, data/art/ground.json, data/art/light.json):
## ground variants chosen by a hash of the tile (the same every time, different between tiles, a look for every ground kind); soft
## edges chosen by the neighbours (a higher-ranked kind bleeds onto a lower one, foam where water meets land) and drawn in the tile
## view; water that plays its frames, and holds the first with reduced motion; shadows under what stands on the ground; the warm and
## cool grade, glow at night, weather, fog and vignette drawn without error and still or off with reduced motion; the data checks
## catching each kind of break; and the world itself untouched (GameWorldGen and GameRelief answer as they did).
## Run: godot --headless --path . -s res://tests/test_game_world_look.gd
extends SceneTree

const UiSettings := preload("res://ui/play/ui_settings.gd")
# A digest of GameWorldGen.tile and GameRelief over a window of tiles of two seeds, taken before the world look was added.
const WORLD_DIGEST := {7: 194272415, 77: 352431507}

var fails := 0
var checks := 0
var paints := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


## A control that draws with a function, so the draw calls happen where Godot allows them.
class Canvas extends Control:
	var fn: Callable

	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)


func _init() -> void:
	_run.call_deferred()


func _dyn(seed_value: int = 7) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


func _run() -> void:
	GameData.load_all()
	var was: bool = UiSettings.reduced_motion()
	test_data()
	test_variants()
	test_edges()
	test_edges_drawn()
	test_water()
	test_shadows()
	await test_drawn()
	test_weather()
	test_validator()
	test_world_untouched()
	await test_screen()
	UiSettings.set_access("reduced_motion", was)
	print("world look tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- the data and the variants

func test_data() -> void:
	ok(GroundArt.validate().is_empty(), "the ground and light data pass their checks: %s" % str(GroundArt.validate()))
	for k in GamePath.data()["terrain"].keys() + ["water", "deep", "snow", "ford"]:
		ok(GroundArt.has_kind(k), "ground kind '%s' has a look" % k)
		if GroundArt.has_kind(k):
			var n := GroundArt.variant_count(k)
			ok(n >= 2 and n <= int(GroundArt.setting("max_variants")), "'%s' has 2 to 4 variants: %d" % [k, n])
			ok(GroundArt.rank_of(k) >= 0, "'%s' has an edge rank" % k)
	ok(not GroundArt.has_kind("floor") and GroundArt.variant_count("floor") == 1 and GroundArt.variant_at("floor", 3, 4) == 0, "a built piece has no variants")


func test_variants() -> void:
	var seen := {}
	var same := true
	for z in 20:
		for x in 20:
			var v := GroundArt.variant_at("plains", x, z)
			seen[v] = true
			if GroundArt.variant_at("plains", x, z) != v:
				same = false
	ok(same, "a tile's variant is the same every time")
	ok(seen.size() == GroundArt.variant_count("plains"), "every variant of plains is used: %d" % seen.size())
	var rows := 0
	for x in 12:
		if GroundArt.variant_at("plains", x, 0) != GroundArt.variant_at("plains", 0, 0):
			rows += 1
	ok(rows > 0, "tiles side by side do not all look alike")
	ok(GroundArt.variant_at("plains", -5, -9) == GroundArt.variant_at("plains", -5, -9), "negative tiles work")
	ok(GroundArt.mix(1, 2, 3) == GroundArt.mix(1, 2, 3) and GroundArt.mix(1, 2, 3) != GroundArt.mix(2, 1, 3), "the hash is a function of its numbers")
	# The variants are different pictures.
	var all := TileView.kinds()
	var img := GroundArt.ground_image(all)
	var px := GroundArt.px()
	var col := all.find("plains")
	var differ := false
	for y in px:
		for x in px:
			if img.get_pixel(col * px + x, y) != img.get_pixel(col * px + x, px + y):
				differ = true
	ok(differ, "two variants of a kind are drawn differently")
	var base := GroundArt.base_color("plains")
	var specks := 0
	for y in px:
		for x in px:
			var got := img.get_pixel(col * px + x, y)
			if absf(got.r - base.r) + absf(got.g - base.g) + absf(got.b - base.b) > 0.02:
				specks += 1
	ok(specks > 4 and specks < px * px / 2, "a variant has specks on its colour, not a new colour: %d pixels" % specks)
	# The tile view puts them down: in the variants source, a column for the kind.
	var d := _dyn()
	var v := TileView.new()
	root.add_child(v)
	v.setup(d)
	v.show_view(Vector2(0, 0), Vector2(4, 4))
	var c := Vector2i(0, 0)
	var layer: TileMapLayer = v.layers[c]
	var rows_seen := {}
	var n := int(TileView.settings()["chunk"])
	var all_in_src1 := true
	for dz in n:
		for dx in n:
			var cell := Vector2i(dx, dz)
			if layer.get_cell_source_id(cell) != 1:
				all_in_src1 = false
			rows_seen[layer.get_cell_atlas_coords(cell).y] = true
			var kind := TileView.cell_kind(layer, cell)
			ok(layer.get_cell_atlas_coords(cell) == GroundArt.cell_for(all, kind, c.x * n + dx, c.y * n + dz) or GroundArt.has_kind(kind) == false, "the tile at %s is drawn as its hashed variant" % str(cell))
	ok(all_in_src1, "the open ground is drawn from the variants atlas")
	ok(rows_seen.size() > 1, "a chunk shows more than one variant")
	v.queue_free()


# ---------------------------------------------------------------- edges

func test_edges() -> void:
	var none := Vector2i(-1, -1)
	var foam_row := GroundArt.edge_row("foam")
	ok(GroundArt.edge_for("water", {"n": "plains"}) == Vector2i(0, foam_row), "water with land to its north has foam on that side")
	ok(GroundArt.edge_for("water", {"e": "coast", "s": "coast"}) == Vector2i(2 + 4 - 1, foam_row), "foam on the east and south sides")
	ok(GroundArt.edge_for("water", {"nw": "forest"}) == Vector2i(GroundArt.SIDE_COLS + 8 - 1, foam_row), "land at a corner only gives foam at that corner")
	ok(GroundArt.edge_for("water", {"n": "water", "e": "water"}) == none, "water beside water of its own kind has no edge")
	ok(GroundArt.edge_for("water", {"n": "water", "s": "deep"}) == none, "shallows beside deeper water is not edged (the deep gives way)")
	var deep := GroundArt.edge_for("deep", {"n": "water"})
	ok(deep == Vector2i(0, GroundArt.edge_row("water")), "deep water takes a soft band of the shallows beside it: %s" % str(deep))
	ok(GroundArt.edge_for("plains", {"e": "forest"}) == Vector2i(1, GroundArt.edge_row("forest")), "the higher-ranked forest bleeds onto the plains beside it")
	ok(GroundArt.edge_for("forest", {"e": "plains"}) == none, "and the plains does not bleed onto the forest")
	ok(GroundArt.edge_for("plains", {"e": "forest", "n": "hills", "w": "hills"}) == Vector2i((1 | 8) - 1, GroundArt.edge_row("hills")), "of several, the highest rank bleeds, along the sides it is on")
	ok(GroundArt.edge_for("plains", {"ne": "snow"}) == Vector2i(GroundArt.SIDE_COLS, GroundArt.edge_row("snow")), "a lone corner is a corner edge")
	ok(GroundArt.edge_for("plains", {"n": "plains", "e": "plains"}) == none, "a tile among its own kind has no edge")
	ok(GroundArt.edge_for("plains", {"n": "water"}) == none, "water never bleeds onto land (the water has the foam)")
	ok(GroundArt.edge_for("floor", {"n": "plains"}) == none, "a built piece has no edge")
	# The same neighbours always give the same edge.
	var near := {"n": "hills", "e": "forest", "s": "plains", "w": "swamp"}
	ok(GroundArt.edge_for("plains", near) == GroundArt.edge_for("plains", near), "an edge is a function of the neighbours")
	# The edge atlas: a band along the side, clear elsewhere, fading.
	var e: Dictionary = GroundArt.data()["edges"]
	var px := GroundArt.px()
	var side := GroundArt.edge_alphas(0, e["profile"], e["alphas"], int(e["corner_reach"]), px)   # a band on the north side
	ok(side[0] > 0.9 and side[px * (px - 1)] == 0.0 and side[px * 6] == 0.0, "a north edge is solid at the side and clear across the tile")
	var fade_ok := true
	for x in px:
		var last := 2.0
		for y in px:
			var a := side[y * px + x]
			if a > last + 0.0001:
				fade_ok = false
			if a > 0.0:
				last = a
	ok(fade_ok, "an edge fades going in")
	var corner := GroundArt.edge_alphas(GroundArt.SIDE_COLS, e["profile"], e["alphas"], int(e["corner_reach"]), px)
	ok(corner[px - 1] > 0.9 and corner[0] == 0.0 and corner[px * px - 1] == 0.0, "a north-east corner edge is in that corner only")


## A water tile with land beside it, found in the world.
func _shore(d: GameDynasty) -> Vector2i:
	for z in range(-60, 60):
		for x in range(-60, 60):
			var t := GameWorldGen.tile(d, x, z)
			if bool(t["water"]) and not bool(GameWorldGen.tile(d, x - 1, z)["water"]) and GameBuild.kind_at(d, x, GameBuild.SURFACE, z) == "":
				return Vector2i(x, z)
	return Vector2i(100000, 100000)


func test_edges_drawn() -> void:
	var d := _dyn(77)
	var s := _shore(d)
	ok(s.x != 100000, "a shore is found in the world")
	if s.x == 100000:
		return
	var v := TileView.new()
	root.add_child(v)
	v.setup(d)
	var c := TileView.chunk_of(s.x, s.y)
	v.show_view(Vector2(s.x, s.y), Vector2(2, 2))
	var n := int(TileView.settings()["chunk"])
	var local := Vector2i(s.x - c.x * n, s.y - c.y * n)
	ok(v.edges.has(c) and (v.edges[c] as TileMapLayer).get_cell_source_id(local) >= 0, "the water at the shore has an edge")
	if v.edges.has(c) and (v.edges[c] as TileMapLayer).get_cell_source_id(local) >= 0:
		var got := (v.edges[c] as TileMapLayer).get_cell_atlas_coords(local)
		ok(got.y == GroundArt.edge_row("foam") and (got.x + 1) & 8 != 0, "and it is foam on its west side: %s" % str(got))
	# A tile deep inside one kind of ground has none.
	var quiet := 0
	var drawn := 0
	for dz in n:
		for dx in n:
			if (v.edges[c] as TileMapLayer).get_cell_source_id(Vector2i(dx, dz)) >= 0:
				drawn += 1
			else:
				quiet += 1
	ok(quiet > drawn, "most of a chunk has no edge (%d with, %d without)" % [drawn, quiet])
	# A piece built on the shore covers its edge, and taking it down puts it back.
	d.heir.gold = 5000
	GameCraft.add_material(d, "oak", 100)
	d.built[GameBuild.key(s.x, GameBuild.SURFACE, s.y)] = "floor"
	v.refresh_cell(s.x, s.y)
	ok((v.edges[c] as TileMapLayer).get_cell_source_id(local) == -1, "a built piece covers the edge")
	d.built.erase(GameBuild.key(s.x, GameBuild.SURFACE, s.y))
	v.refresh_cell(s.x, s.y)
	ok((v.edges[c] as TileMapLayer).get_cell_source_id(local) >= 0, "and it is back when the piece is taken down")
	# The relief's brightness step is carried to the edge, as it is to the ground.
	var lit := 0
	for cc in v.layers:
		for dz in n:
			for dx in n:
				var lc := Vector2i(dx, dz)
				if (v.edges[cc] as TileMapLayer).get_cell_source_id(lc) >= 0:
					var ga := (v.layers[cc] as TileMapLayer).get_cell_alternative_tile(lc)
					if (v.edges[cc] as TileMapLayer).get_cell_alternative_tile(lc) != ga:
						lit -= 1000
					elif ga != 0:
						lit += 1
	ok(lit > 0, "an edge takes its tile's brightness step (%d on lit ground)" % lit)
	v.queue_free()


# ---------------------------------------------------------------- water

func test_water() -> void:
	var all := TileView.kinds()
	var px := GroundArt.px()
	var img := GroundArt.ground_image(all)
	var col := all.find("water")
	ok(GroundArt.frames() >= 2 and GroundArt.frames() <= 8, "water has 2 to 8 frames")
	var moved := 0
	for y in px:
		for x in px:
			if img.get_pixel(col * px + x, y) != img.get_pixel(col * px + x, px + y):
				moved += 1
	ok(moved > 0, "the water's frames are not all the same picture (%d pixels move between two)" % moved)
	var first := img.get_pixel(col * px + 1, 1)
	ok(GroundArt.row_of("water", 1) == GroundArt.frames(), "water's variants stand a loop apart")
	var was: bool = UiSettings.reduced_motion()
	UiSettings.set_access("reduced_motion", false)
	var ts := TileView.make_tileset()
	var src: TileSetAtlasSource = ts.get_source(1)
	var at := Vector2i(col, 0)
	ok(src.has_tile(at) and src.get_tile_animation_frames_count(at) == GroundArt.frames(), "the water plays its frames")
	ok(src.get_tile_animation_speed(at) > 0.0, "at a speed")
	ok(src.get_tile_animation_frames_count(Vector2i(all.find("plains"), 0)) == 1, "land is a single frame")
	UiSettings.set_access("reduced_motion", true)
	var still := TileView.make_tileset().get_source(1) as TileSetAtlasSource
	ok(still.get_tile_animation_frames_count(at) == 1, "with reduced motion the water holds its first frame")
	# A view made with the option off settles when it is turned on.
	UiSettings.set_access("reduced_motion", false)
	var d := _dyn()
	var v := TileView.new()
	root.add_child(v)
	v.setup(d)
	ok((v.tile_set.get_source(1) as TileSetAtlasSource).get_tile_animation_frames_count(at) == GroundArt.frames(), "a view built with motion plays")
	UiSettings.set_access("reduced_motion", true)
	v.show_view(Vector2(0, 0), Vector2(2, 2))
	ok((v.tile_set.get_source(1) as TileSetAtlasSource).get_tile_animation_frames_count(at) == 1, "and holds when the option is turned on")
	UiSettings.set_access("reduced_motion", false)
	v.show_view(Vector2(0, 0), Vector2(2, 2))
	ok((v.tile_set.get_source(1) as TileSetAtlasSource).get_tile_animation_frames_count(at) == GroundArt.frames(), "and plays again when it is turned off")
	UiSettings.set_access("reduced_motion", was)
	v.queue_free()
	ok(first.a == 1.0, "water is solid")
	ok(GroundArt.is_water("deep") and not GroundArt.is_water("plains"), "the kinds that move are the water kinds")


# ---------------------------------------------------------------- shadows

func test_shadows() -> void:
	var d := _dyn(77)
	var cast_tile := Vector2i(100000, 100000)
	var plain_tile := Vector2i(100000, 100000)
	var v := TileView.new()
	root.add_child(v)
	v.setup(d)
	for z in range(-40, 40):
		for x in range(-40, 40):
			var t := GameWorldGen.tile(d, x, z)
			var built := GameBuild.kind_at(d, x, GameBuild.SURFACE, z)
			var thing := v._thing_from(t, built, x, z)
			var ground := v._decor_from(t, built, x, z)
			var shape := TileView._shadow_shape(thing, ground)
			if shape != "" and cast_tile.x == 100000:
				cast_tile = Vector2i(x, z)
			if shape == "" and plain_tile.x == 100000 and not bool(t["water"]):
				plain_tile = Vector2i(x, z)
	ok(cast_tile.x != 100000, "something that throws a shadow stands in the world")
	if cast_tile.x == 100000:
		return
	var c := TileView.chunk_of(cast_tile.x, cast_tile.y)
	var n := int(TileView.settings()["chunk"])
	v.show_view(Vector2(cast_tile.x, cast_tile.y), Vector2(1, 1))
	var local := Vector2i(cast_tile.x - c.x * n, cast_tile.y - c.y * n)
	ok(v.shadows.has(c) and (v.shadows[c] as TileMapLayer).get_cell_source_id(local) >= 0, "a standing thing has a shadow under it")
	var pc := TileView.chunk_of(plain_tile.x, plain_tile.y)
	v.show_view(Vector2(plain_tile.x, plain_tile.y), Vector2(1, 1))
	var pl := Vector2i(plain_tile.x - pc.x * n, plain_tile.y - pc.y * n)
	ok((v.shadows[pc] as TileMapLayer).get_cell_source_id(pl) == -1, "bare ground has none")
	# The shadow is a soft low-alpha shape, offset to the south-east of the middle (the sun is in the north-west).
	var ts: TileSet = GroundArt.overlay_set()
	var img := (ts.get_source(0) as TileSetAtlasSource).texture.get_image()
	var px := GroundArt.px()
	var shapes := GroundArt.shadow_shapes()
	ok(shapes.size() >= 3, "there are shadow shapes")
	for sh in shapes:
		var cell := GroundArt.shadow_cell(sh)
		var west := 0.0
		var east := 0.0
		var peak := 0.0
		for y in px:
			for x in px:
				var a := img.get_pixel(cell.x * px + x, cell.y * px + y).a
				peak = maxf(peak, a)
				if x < px / 2:
					west += a
				else:
					east += a
		ok(peak > 0.1 and peak < 0.6, "the %s shadow is soft and light: %.2f" % [sh, peak])
		ok(east > west, "the %s shadow falls to the east (the light is from the north-west)" % sh)
	ok(GroundArt.shadow_of("oak_tree") == "tree" and GroundArt.shadow_of("dug") == "", "trees cast, a dug shaft does not")
	# What is built over a standing thing takes its shadow away.
	d.built[GameBuild.key(cast_tile.x, GameBuild.SURFACE, cast_tile.y)] = "floor"
	v.show_view(Vector2(cast_tile.x, cast_tile.y), Vector2(1, 1))
	v.refresh_cell(cast_tile.x, cast_tile.y)
	ok((v.shadows[c] as TileMapLayer).get_cell_source_id(local) == -1, "a piece built there covers it")
	v.set_level(1)
	ok(not (v.shadows[c] as TileMapLayer).visible, "a storey above is not shaded by the ground's trees")
	v.queue_free()


# ---------------------------------------------------------------- the light, drawn

func _look(sun: float, precip: String = "none", weather: String = "clear") -> Dictionary:
	return {"phase": "day", "hour": 12.0, "sun": sun, "light": sun, "tint": [0.12 + 0.88 * sun, 0.15 + 0.85 * sun, 0.32 + 0.68 * sun], "fog": 0.4 if weather == "fog" else 0.0, "precip": precip, "weather": weather, "season": "summer", "night": sun < 0.35}


func _paint_all(c: Control, looks: Array, sources: Array) -> void:
	var rect := Rect2(Vector2(0, 40), Vector2(640, 360))
	for look in looks:
		WorldLook.paint_grade(c, rect, look)
		WorldLook.paint_fog(c, rect, look)
		WorldLook.paint_weather(c, rect, look)
		WorldLook.paint_vignette(c, rect, look)
		WorldLook.paint_glow(c, sources, look, 24.0, Vector2(0, 40), Vector2(640, 360), Vector2(0, 0))
	WorldLook.paint_building_shadow(c, Rect2(100, 100, 72, 48), 24.0)
	paints += 1


func test_drawn() -> void:
	var d := _dyn()
	var looks: Array = []
	for sun in [0.0, 0.3, 1.0]:
		looks.append(_look(sun))
		looks.append(_look(sun, "rain", "rain"))
		looks.append(_look(sun, "rain", "storm"))
		looks.append(_look(sun, "snow", "snow"))
		looks.append(_look(sun, "none", "fog"))
	# Real looks from the day cycle too.
	for secs in [0.0, 20.0, 60.0, 100.0]:
		d.world_seconds = secs
		looks.append(GameDay.look(d))
	d.built[GameBuild.key(3, GameBuild.SURFACE, 3)] = "hearth"
	d.built[GameBuild.key(4, GameBuild.SURFACE, 3)] = "anvil"
	var sources := WorldLook.glow_sources(d, null, Rect2i(-20, -20, 60, 60))
	ok(sources.size() >= 2, "hearths and anvils shine: %d sources" % sources.size())
	var canvas := Canvas.new()
	canvas.size = Vector2(640, 400)
	canvas.fn = func(c: Control) -> void: _paint_all(c, looks, sources)
	root.add_child(canvas)
	var layer := WorldLook.make_layer(func(c: Control) -> void: _paint_all(c, looks, sources), true)
	root.add_child(layer)
	await process_frame
	await process_frame
	ok(paints >= 2, "the light is drawn by both a plain and an additive layer without error (%d paints)" % paints)
	ok(layer.material is CanvasItemMaterial and (layer.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "the glow layer adds its light to the picture")
	ok(layer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "and lets the mouse through")
	# glow
	ok(WorldLook.night_glow(_look(1.0)) == 0.0 and WorldLook.night_glow(_look(0.0)) == 1.0, "no glow by day, all of it at night")
	ok(WorldLook.night_glow(_look(0.3)) > 0.0 and WorldLook.night_glow(_look(0.3)) < 1.0, "the glow grows through the dusk")
	var spec: Dictionary = GroundArt.light_data()["glow"]["tiles"]["hearth"]
	var s0 := WorldLook.glow_strength(spec, Vector2(3, 3), 0.0)
	ok(WorldLook.glow_strength(spec, Vector2(3, 3), 0.0) == s0, "a flicker is a function of place and time")
	var varied := false
	for i in 20:
		if absf(WorldLook.glow_strength(spec, Vector2(3, 3), float(i) * 0.13) - s0) > 0.001:
			varied = true
	ok(varied, "a fire flickers")
	var top := float(spec["strength"]) * (1.0 + float(GroundArt.light_data()["glow"]["flicker"]))
	var low := float(spec["strength"]) * (1.0 - float(GroundArt.light_data()["glow"]["flicker"]))
	var inside := true
	for i in 60:
		var g := WorldLook.glow_strength(spec, Vector2(5, 9), float(i) * 0.07)
		if g > top + 0.0001 or g < low - 0.0001:
			inside = false
	ok(inside, "and stays within its range")
	var town_sources := WorldLook.glow_sources(d, null, Rect2i(-2000, -2000, 4000, 4000))
	ok(town_sources.size() > sources.size(), "the town's buildings have lit windows: %d sources" % town_sources.size())
	var forge_at := false
	for b in GameTown.all():
		if str(b["kind"]) == "forge":
			forge_at = true
	ok(forge_at and GroundArt.light_data()["glow"]["buildings"].has("forge"), "a forge glows its own colour")
	# the shadow of a building lies to its south-east and is made of soft layers
	var sb: Dictionary = GroundArt.light_data()["shadow"]["building"]
	ok(float(sb["dx"]) > 0.0 and float(sb["dy"]) > 0.0, "a building's shadow falls south-east")
	# the vignette is clear in the middle and dark at the corner
	var vt := GroundArt.vignette_texture().get_image()
	ok(vt.get_pixel(vt.get_width() / 2, vt.get_height() / 2).a < 0.01 and vt.get_pixel(0, 0).a > 0.9, "the vignette is clear in the middle and dark in the corners")
	var gt := GroundArt.glow_texture().get_image()
	ok(gt.get_pixel(gt.get_width() / 2, gt.get_height() / 2).a > 0.9 and gt.get_pixel(0, 0).a == 0.0, "a glow is bright in the middle and gone at the edge")
	# the grade: the sun is warm by day, the light cool at night
	var tint_day: Array = GameDay.look(_with_seconds(d, 75.0 - 45.0))["tint"]
	ok(tint_day.size() == 3, "the day's tint is a colour")
	canvas.queue_free()
	layer.queue_free()


func _with_seconds(d: GameDynasty, secs: float) -> GameDynasty:
	d.world_seconds = secs
	return d


func test_weather() -> void:
	var was: bool = UiSettings.reduced_motion()
	UiSettings.set_access("reduced_motion", false)
	ok(WorldLook.weather_shows(_look(1.0, "rain", "rain")) and WorldLook.weather_shows(_look(1.0, "snow", "snow")), "rain and snow are drawn")
	ok(not WorldLook.weather_shows(_look(1.0)), "a dry sky draws none")
	var size := Vector2(1280, 720)
	var rain := WorldLook.particle_count("rain", "rain", size)
	var storm := WorldLook.particle_count("rain", "storm", size)
	ok(rain > 20 and storm > rain, "a storm has more rain than a shower: %d and %d" % [rain, storm])
	ok(WorldLook.particle_count("rain", "rain", size * 0.5) < rain, "a smaller view has fewer streaks")
	ok(WorldLook.particle_count("none", "clear", size) == 0, "no sky, no particles")
	for precip in ["rain", "snow"]:
		var inside := true
		var moved := 0
		for i in 80:
			var a := WorldLook.particle(precip, i, 3.0, size)
			var b := WorldLook.particle(precip, i, 3.4, size)
			if a.x < 0.0 or a.y < 0.0 or a.x > size.x or a.y > size.y:
				inside = false
			if a != b:
				moved += 1
			if WorldLook.particle(precip, i, 3.0, size) != a:
				inside = false
		ok(inside, "%s stays in the view and is a function of its number and the time" % precip)
		ok(moved > 60, "%s moves with time: %d of 80" % [precip, moved])
	var fall := WorldLook.particle("snow", 5, 0.5, size).y
	ok(WorldLook.particle("snow", 5, 1.5, size).y != fall, "snow falls")
	# reduced motion: still, and the weather is not drawn
	UiSettings.set_access("reduced_motion", true)
	ok(not WorldLook.weather_shows(_look(1.0, "rain", "rain")), "with reduced motion no rain is drawn")
	ok(WorldLook.clock() == 0.0, "and the clock the light moves by stands still")
	var spec: Dictionary = GroundArt.light_data()["glow"]["tiles"]["hearth"]
	ok(WorldLook.glow_strength(spec, Vector2(3, 3), WorldLook.clock()) == WorldLook.glow_strength(spec, Vector2(3, 3), WorldLook.clock()), "so a fire holds its strength")
	UiSettings.set_access("reduced_motion", false)
	ok(WorldLook.clock() >= 0.0, "the clock runs without it")
	UiSettings.set_access("reduced_motion", was)


# ---------------------------------------------------------------- the data checks

func _breaks(label: String, fn: Callable, light: bool = false) -> void:
	var dat: Dictionary = GroundArt.data().duplicate(true)
	var lit: Dictionary = GroundArt.light_data().duplicate(true)
	fn.call(lit if light else dat)
	var bad := GroundArt.problems(dat, lit)
	ok(not bad.is_empty(), "the check catches: %s" % label)


func test_validator() -> void:
	ok(GroundArt.problems(GroundArt.data().duplicate(true), GroundArt.light_data().duplicate(true)).is_empty(), "the data as it is passes")
	_breaks("a ground kind with no look", func(d): d["kinds"].erase("plains"))
	_breaks("a look with no colour", func(d): d["kinds"]["nowhere"] = {"variants": [1, 1], "patterns": []})
	_breaks("no variants", func(d): d["kinds"]["plains"]["variants"] = [])
	_breaks("five variants", func(d): d["kinds"]["plains"]["variants"] = [1, 1, 1, 1, 1])
	_breaks("a variant weight of nothing", func(d): d["kinds"]["plains"]["variants"] = [1, 0])
	_breaks("an unknown pattern", func(d): d["kinds"]["plains"]["patterns"].append({"type": "swirl", "shift": 0.1, "count": 2}))
	_breaks("a pattern with no colour", func(d): d["kinds"]["plains"]["patterns"].append({"type": "speck", "count": 2}))
	_breaks("a pattern count out of range", func(d): d["kinds"]["plains"]["patterns"][0]["count"] = 400)
	_breaks("a colour that is not three numbers", func(d): d["kinds"]["plains"]["patterns"].append({"type": "tuft", "color": [1, 2], "count": 1}))
	_breaks("water without glints", func(d): d["kinds"]["water"].erase("glints"))
	_breaks("land with glints", func(d): d["kinds"]["plains"]["glints"] = d["kinds"]["water"]["glints"])
	_breaks("a sway of the wrong length", func(d): d["kinds"]["water"]["glints"]["sway"] = [0, 1])
	_breaks("a pulse of the wrong length", func(d): d["kinds"]["water"]["glints"]["pulse"] = [1.0])
	_breaks("one frame of water", func(d): d["settings"]["water_frames"] = 1)
	_breaks("no water speed", func(d): d["settings"]["water_fps"] = 0)
	_breaks("a missing setting", func(d): d["settings"].erase("max_variants"))
	_breaks("a kind with no rank", func(d): d["edges"]["rank"].erase("hills"))
	_breaks("a rank for a kind with no look", func(d): d["edges"]["rank"]["nowhere"] = 3)
	_breaks("a water kind with no look", func(d): d["edges"]["water_kinds"].append("lava"))
	_breaks("an edge reaching past its fade", func(d): d["edges"]["profile"] = [9, 9])
	_breaks("an edge with no profile", func(d): d["edges"]["profile"] = [])
	_breaks("an alpha above one", func(d): d["edges"]["alphas"] = [1.5])
	_breaks("foam with no colour", func(d): d["edges"].erase("foam"))
	_breaks("foam of the wrong colour", func(d): d["edges"]["foam"]["color"] = [1.0])
	_breaks("a corner reach of nothing", func(d): d["edges"]["corner_reach"] = 0)
	_breaks("no shadow shapes", func(d): d["shadow"]["shapes"] = {}, true)
	_breaks("a shadow of an unknown shape", func(d): d["shadow"]["kinds"]["oak_tree"] = "cloud", true)
	_breaks("a shadow of something that is not a glyph", func(d): d["shadow"]["kinds"]["unicorn"] = "tree", true)
	_breaks("a shadow shape with no radius", func(d): d["shadow"]["shapes"]["tree"].erase("rx"), true)
	_breaks("a shadow shape of nothing", func(d): d["shadow"]["shapes"]["tree"]["alpha"] = 0.0, true)
	_breaks("a glow with no default building", func(d): d["glow"]["buildings"].erase("default"), true)
	_breaks("a glow of a piece that is not one", func(d): d["glow"]["tiles"]["throne"] = {"color": [1, 1, 1], "radius": 2.0, "strength": 0.5}, true)
	_breaks("a glow of a glyph that is not one", func(d): d["glow"]["glyphs"]["unicorn"] = {"color": [1, 1, 1], "radius": 2.0, "strength": 0.5}, true)
	_breaks("a glow with no radius", func(d): d["glow"]["tiles"]["hearth"].erase("radius"), true)
	_breaks("a glow stronger than one", func(d): d["glow"]["tiles"]["hearth"]["strength"] = 3.0, true)
	_breaks("a glow that starts after the sun is full", func(d): d["glow"]["from_sun"] = 2.0, true)
	_breaks("no rain", func(d): d["weather"].erase("rain"), true)
	_breaks("rain with no fall", func(d): d["weather"]["rain"]["fall"] = 0.0, true)
	_breaks("snow with too many flakes", func(d): d["weather"]["snow"]["count"] = 99999, true)
	_breaks("snow of a colour with no alpha", func(d): d["weather"]["snow"]["color"] = [1, 1, 1], true)
	_breaks("an intensity of nothing", func(d): d["weather"]["intensity"]["storm"] = 0.0, true)
	_breaks("a vignette that begins past the edge", func(d): d["vignette"]["inner"] = 1.5, true)
	_breaks("a missing section of the light", func(d): d.erase("vignette"), true)


# ---------------------------------------------------------------- the world itself

func _digest(seed_value: int) -> int:
	var d := _dyn(seed_value)
	var h := 0
	for z in range(-30, 30):
		for x in range(-30, 30):
			var t := GameWorldGen.tile(d, x, z)
			h = (h * 31 + str(t).hash()) & 0x7fffffff
			h = (h * 31 + GameRelief.step_at(d, x, z) + 17) & 0x7fffffff
			h = (h * 31 + GameRelief.kind(t).hash()) & 0x7fffffff
	return h


func test_world_untouched() -> void:
	var d := _dyn(7)
	var before := JSON.stringify(d.to_dict())
	var v := TileView.new()
	root.add_child(v)
	v.setup(d)
	v.show_view(Vector2(0, 0), Vector2(40, 22))
	var count := v.fills
	ok(count > 4, "chunks are filled: %d" % count)
	ok(JSON.stringify(d.to_dict()) == before, "filling the view changes nothing in the dynasty (no die is drawn)")
	v.queue_free()
	for s in WORLD_DIGEST:
		ok(_digest(s) == int(WORLD_DIGEST[s]), "the world of seed %d answers as it did (GameWorldGen.tile, GameRelief): %d" % [s, _digest(s)])


# ---------------------------------------------------------------- the screen

class FakeApp extends Node:
	var dynasty: GameDynasty

	func show_state() -> void:
		pass


func test_screen() -> void:
	var d := _dyn()
	var app := FakeApp.new()
	app.dynasty = d
	root.add_child(app)
	var scr: Control = load("res://ui/play/sandbox_screen.gd").new()
	scr.app = app
	scr.size = Vector2(800, 500)
	root.add_child(scr)
	await process_frame
	await process_frame
	ok(scr.glow_layer != null and scr.sky_layer != null, "the sandbox screen has its glow and sky layers")
	ok(scr.glow_layer.material is CanvasItemMaterial, "the glow layer is additive")
	ok(scr.get_child_count() > 0 and scr.glow_layer.get_index() > scr.overlay.get_index() and scr.sky_layer.get_index() > scr.glow_layer.get_index(), "over the map: the overlay, then the glow, then the sky")
	for i in 3:
		d.world_seconds += 40.0
		await process_frame
	ok(scr.tile_view.edges.size() > 0 and scr.tile_view.shadows.size() > 0, "the view's chunks have edge and shadow layers")
	scr.queue_free()
	app.queue_free()
