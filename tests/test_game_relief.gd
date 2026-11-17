## The lie of the land (open-world terrain; core/game/game_relief.gd, data/world/relief.json): a land tile's light step (slopes
## facing the north-west sun bright, slopes turned away dark, high ground lighter), deep and shallow water, snow on the high
## mountains; the view that draws them as alternative tiles (and leaves water, built pieces and interiors unshaded); the
## generator's kept heights giving what they always gave; the data checks.
## Run: godot --headless --path . -s res://tests/test_game_relief.gd
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
	test_steps()
	test_kinds()
	test_world_has_relief()
	test_kept_heights()
	test_tileset()
	test_view()
	test_data()
	print("relief tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn(seed_value: int = 77) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


func test_steps() -> void:
	var sea := int(GameWorldGen.setting("sea_level"))
	var mid := sea + int(float(GameRelief.setting("alt_span")) * float(GameRelief.setting("alt_mid")))
	var n := int(GameRelief.setting("steps"))
	ok(GameRelief.step_of(mid, mid, mid, mid, mid) == 0, "flat ground at the middle height is the colour as it is")
	var lit := GameRelief.step_of(mid, mid - 2, mid + 2, mid - 2, mid + 2)
	var dark := GameRelief.step_of(mid, mid + 2, mid - 2, mid + 2, mid - 2)
	ok(lit > 0, "ground that rises away to the east and south faces the north-west sun: brighter (%d)" % lit)
	ok(dark < 0, "ground that falls away to the east and south is turned from it: darker (%d)" % dark)
	ok(lit == -dark, "and the two are mirror images")
	var one := GameRelief.step_of(mid, mid, mid + 1, mid, mid + 1)
	var two := GameRelief.step_of(mid, mid, mid + 3, mid, mid + 3)
	ok(two > one, "a steeper slope is brighter than a gentle one (%d, %d)" % [one, two])
	ok(GameRelief.step_of(mid, 0, 200, 0, 200) == n and GameRelief.step_of(mid, 200, 0, 200, 0) == -n, "a cliff is held to the brightest and darkest steps")
	ok(GameRelief.step_of(sea + 60, sea + 60, sea + 60, sea + 60, sea + 60) > GameRelief.step_of(sea + 2, sea + 2, sea + 2, sea + 2, sea + 2), "high flat ground is lighter than low")
	ok(GameRelief.step_of(sea + 2, sea + 2, sea + 2, sea + 2, sea + 2) < 0, "a flat valley floor is a little darker than the colour")
	ok(GameRelief.light(0) == 1.0 and GameRelief.light(1) > 1.0 and GameRelief.light(-1) < 1.0, "a step makes a colour lighter above 0 and darker below")
	ok(GameRelief.light(-n) > 0.0, "the darkest step is not black")
	var d := _dyn()
	var wet := Vector2i(-1, -1)
	for x in range(0, 60):
		if GameWorldGen.tile(d, x, 300)["water"]:
			wet = Vector2i(x, 300)
			break
	ok(wet.x >= 0 and GameRelief.step_at(d, wet.x, wet.y) == 0, "water has no step")
	var a := GameWorldGen.anchor("hearthmere")
	var tx := int(a["x"])
	var tz := int(a["z"])
	ok(GameRelief.step_at(d, tx, tz) == GameRelief.step_of(GameWorldGen.height_at(d.seed_value, tx, tz), GameWorldGen.height_at(d.seed_value, tx - 1, tz), GameWorldGen.height_at(d.seed_value, tx + 1, tz), GameWorldGen.height_at(d.seed_value, tx, tz - 1), GameWorldGen.height_at(d.seed_value, tx, tz + 1)), "a tile's step is worked from its own height and its four neighbours'")


func test_kinds() -> void:
	var sea := int(GameWorldGen.setting("sea_level"))
	var deep := int(GameRelief.setting("deep_depth"))
	ok(GameRelief.depth(sea - 3) == 3 and GameRelief.depth(sea + 9) == 0, "depth is the bed under the sea level, 0 on dry land")
	ok(GameRelief.kind({"water": true, "height": sea - 1, "biome": "plains"}) == "water", "a shallow bed is shallow water")
	ok(GameRelief.kind({"water": true, "height": sea - deep, "biome": "plains"}) == "deep", "and a bed `deep_depth` under is deep")
	ok(GameRelief.kind({"water": true, "height": sea - deep + 1, "biome": "ocean"}) == "water", "one less is still shallow")
	ok(GameRelief.kind({"water": true, "biome": "ocean"}) == "water", "water of no known height is shallow")
	var lake_deep := int(GameRelief.setting("lake_deep"))
	ok(GameRelief.kind({"water": true, "body": "lake", "depth": lake_deep, "height": sea + 20, "biome": "hills"}) == "deep", "the middle of a lake is deep, even high in the hills")
	ok(GameRelief.kind({"water": true, "body": "lake", "depth": lake_deep - 1, "height": sea + 20, "biome": "hills"}) == "water", "and one less is shallow")
	ok(GameRelief.kind({"water": true, "body": "river", "depth": lake_deep + 5, "height": sea + 20, "biome": "hills"}) == "water", "a river is shallow whatever its depth field says")
	ok(GameRelief.kind({"water": false, "body": "ford", "height": sea + 2, "biome": "plains"}) == "ford", "the shallows of a river are a ford")
	var line := int(GameRelief.setting("snow_line"))
	ok(GameRelief.kind({"water": false, "height": line, "biome": "mountains"}) == "snow", "mountain ground at the snow line is snow")
	ok(GameRelief.kind({"water": false, "height": line - 1, "biome": "mountains"}) == "mountains", "and one under it is bare rock")
	ok(GameRelief.kind({"water": false, "height": line + 20, "biome": "plains"}) == "plains", "high ground of a biome that takes no snow is not snow")
	ok(GameRelief.kind({"water": false, "height": line + 20, "biome": "volcanic"}) == "volcanic", "and a volcano keeps its rock")
	ok(GameRelief.kind({"water": false, "biome": "forest"}) == "forest", "a tile of no height is its biome")
	ok(TileView.kind_for({"water": true, "height": sea - deep, "biome": "plains"}, "") == "deep", "the view draws what GameRelief says")
	ok(TileView.kind_for({"water": true, "height": sea - deep, "biome": "plains"}, "road") == "road", "but a built piece comes first")


func test_world_has_relief() -> void:
	var d := _dyn()
	# The mountains rise high and the plains lie low: the land is not flat.
	var hc := GameWorldGen.anchor("highcrag")
	var lo := 999
	var hi := 0
	var snow := 0
	var tiles := 0
	for z in range(int(hc["z"]) - 40, int(hc["z"]) + 40, 2):
		for x in range(int(hc["x"]) - 40, int(hc["x"]) + 40, 2):
			var t := GameWorldGen.tile(d, x, z)
			lo = mini(lo, int(t["height"]))
			hi = maxi(hi, int(t["height"]))
			tiles += 1
			if GameRelief.kind(t) == "snow":
				snow += 1
	ok(hi - lo >= 25, "the mountains round Highcrag span %d to %d" % [lo, hi])
	ok(snow > 0 and snow < tiles, "and have snow on part of them: %d of %d" % [snow, tiles])
	# Light steps vary over hilly ground (a map of one shade would show nothing).
	var seen := {}
	var ir := GameWorldGen.anchor("ironford")
	for z in range(int(ir["z"]) + 12, int(ir["z"]) + 60):
		for x in range(int(ir["x"]) + 12, int(ir["x"]) + 60):
			seen[GameRelief.step_at(d, x, z)] = true
	ok(seen.size() >= 3, "hills are lit in at least three steps: %s" % str(seen.keys()))
	# A town's flat is flat: no slope in its light.
	var hm := GameWorldGen.anchor("hearthmere")
	var r := int(hm["radius"]) - 2
	var flat := true
	var first := GameRelief.step_at(d, int(hm["x"]), int(hm["z"]))
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if GameRelief.step_at(d, int(hm["x"]) + dx, int(hm["z"]) + dz) != first:
				flat = false
	ok(flat, "a town's cleared ground is one light")


func test_kept_heights() -> void:
	var d := _dyn()
	var seed_value := d.seed_value
	var probe: Array = []
	for i in 40:
		probe.append(Vector2i(37 + i * 13, 211 + i * 7))
	var first: Array = []
	for p in probe:
		first.append(GameWorldGen.tile(d, p.x, p.y))
	GameWorldGen._surf.clear()
	for i in probe.size():
		var again := GameWorldGen.tile(d, probe[i].x, probe[i].y)
		ok(again["height"] == first[i]["height"] and again["biome"] == first[i]["biome"] and again["water"] == first[i]["water"], "a tile is the same with the kept heights cleared (%s)" % str(probe[i]))
	# Another seed in between does not leak into this one.
	var other := GameWorldGen.height_at(seed_value + 1, probe[3].x, probe[3].y)
	var back := GameWorldGen.height_at(seed_value, probe[3].x, probe[3].y)
	ok(back == int(first[3]["height"]), "a height asked for another seed in between is still this seed's")
	var moved := false
	for p in probe:
		if GameWorldGen.height_at(seed_value + 1, p.x, p.y) != GameWorldGen.height_at(seed_value, p.x, p.y):
			moved = true
	ok(moved, "and another seed gives another land (%d against %d)" % [other, back])
	ok(GameWorldGen.height_at(seed_value, -1, 300) >= 0 and GameWorldGen.height_at(seed_value, 700, 300) >= 0, "a tile outside the world has a height too (a view's neighbour)")


func test_tileset() -> void:
	var ts := TileView.make_tileset()
	var src: TileSetAtlasSource = ts.get_source(0)
	var n := int(GameRelief.setting("steps"))
	var kinds := TileView.kinds()
	ok(kinds.has("deep") and kinds.has("snow"), "deep water and snow are kinds with a colour")
	var seen := {}
	for step in range(-n, n + 1):
		var alt := TileView.alt_for(step)
		ok(not seen.has(alt), "step %d has an alternative of its own (%d)" % [step, alt])
		seen[alt] = true
	ok(TileView.alt_for(0) == 0, "step 0 is the plain tile (a tile set with no alternative is never shaded)")
	var i := kinds.find("plains")
	for step in [-n, -1, 1, n]:
		var alt := TileView.alt_for(step)
		ok(src.has_alternative_tile(Vector2i(i, 0), alt), "plains has the alternative for step %d" % step)
		var m: Color = src.get_tile_data(Vector2i(i, 0), alt).modulate
		ok(is_equal_approx(m.r, GameRelief.light(step)), "and it is lit as the data says (%f)" % m.r)
	ok(src.get_tile_data(Vector2i(i, 0), 0).modulate == Color(1, 1, 1), "the plain tile is not tinted")


func test_view() -> void:
	var d := _dyn()
	var v := TileView.new()
	v.setup(d)
	var ir := GameWorldGen.anchor("ironford")
	var at := Vector2(float(ir["x"]) + 30.0, float(ir["z"]) + 30.0)
	v.show_view(at, Vector2(8, 6))
	var n := int(TileView.settings()["chunk"])
	var alts := {}
	var wrong := 0
	for c in v.layers:
		var layer: TileMapLayer = v.layers[c]
		for dz in n:
			for dx in n:
				var x: int = c.x * n + dx
				var z: int = c.y * n + dz
				var tile := GameWorldGen.tile(d, x, z)
				var want := 0 if bool(tile["water"]) else TileView.alt_for(GameRelief.step_at(d, x, z))
				var got := layer.get_cell_alternative_tile(Vector2i(dx, dz))
				alts[got] = true
				if got != want:
					wrong += 1
	ok(wrong == 0, "every ground tile is set with its own light (%d wrong)" % wrong)
	ok(alts.size() >= 3, "and over hills they differ: %s" % str(alts.keys()))
	# A built piece and water are not shaded; a refreshed tile is lit again when the piece goes. (On a slope: on flat ground
	# the step is 0 whatever is drawn, so it would prove nothing.)
	var hill := Vector2i(-1, -1)
	for zz in range(int(ir["z"]) + 12, int(ir["z"]) + 60):
		for xx in range(int(ir["x"]) + 12, int(ir["x"]) + 60):
			if hill.x < 0 and absi(GameRelief.step_at(d, xx, zz)) >= 2 and not GameWorldGen.tile(d, xx, zz)["water"]:
				hill = Vector2i(xx, zz)
	ok(hill.x >= 0, "there is a slope to try it on")
	var step := GameRelief.step_at(d, hill.x, hill.y)
	ok(v._alt_at(hill.x, hill.y, "", false) == TileView.alt_for(step) and TileView.alt_for(step) != 0, "bare ground on the slope is lit")
	ok(v._alt_at(hill.x, hill.y, "wall", false) == 0, "a built piece on it is not")
	ok(v._alt_at(hill.x, hill.y, "", true) == 0, "water is not")
	v.show_view(Vector2(hill.x, hill.y), Vector2(4, 4))
	var c := TileView.chunk_of(hill.x, hill.y)
	var local := Vector2i(hill.x - c.x * n, hill.y - c.y * n)
	var layer: TileMapLayer = v.layers[c]
	var lit := layer.get_cell_alternative_tile(local)
	ok(lit == TileView.alt_for(step), "the slope is drawn lit")
	d.built[GameBuild.key(hill.x, GameBuild.SURFACE, hill.y)] = "wall"   # (put there directly: the build rules would refuse a slope)
	v.refresh_cell(hill.x, hill.y)
	ok(layer.get_cell_alternative_tile(local) == 0, "a wall there is drawn as it is, not shaded as the hill under it")
	ok(layer.get_cell_atlas_coords(local).x == TileView.kinds().find("wall"), "and it is a wall")
	d.built.erase(GameBuild.key(hill.x, GameBuild.SURFACE, hill.y))
	v.refresh_cell(hill.x, hill.y)
	ok(layer.get_cell_alternative_tile(local) == lit, "and the ground is lit again when it comes down")
	# The same for the ground by the home (flat there, so the step is what GameRelief says, 0 or not).
	var b := GameBuild.base()
	v.show_view(Vector2(float(b["x"]), float(b["z"])), Vector2(4, 4))
	var bc := TileView.chunk_of(int(b["x"]) + 2, int(b["z"]))
	ok(v.layers[bc].get_cell_alternative_tile(Vector2i(int(b["x"]) + 2 - bc.x * n, int(b["z"]) - bc.y * n)) == TileView.alt_for(GameRelief.step_at(d, int(b["x"]) + 2, int(b["z"]))), "ground by the home is lit as GameRelief says")
	var wet := Vector2i(-1, -1)
	for xx in range(0, 60):
		if GameWorldGen.tile(d, xx, 300)["water"]:
			wet = Vector2i(xx, 300)
			break
	v.show_view(Vector2(wet.x, wet.y), Vector2(4, 4))
	var wc := TileView.chunk_of(wet.x, wet.y)
	var wl: TileMapLayer = v.layers[wc]
	var wlocal := Vector2i(wet.x - wc.x * n, wet.y - wc.y * n)
	ok(wl.get_cell_alternative_tile(wlocal) == 0, "water is drawn flat")
	var kind: int = wl.get_cell_atlas_coords(wlocal).x
	ok(kind == TileView.kinds().find("deep") or kind == TileView.kinds().find("water"), "as deep or shallow water")
	v.free()


func test_data() -> void:
	ok(GameRelief.validate().is_empty(), "the relief data is sound: %s" % str(GameRelief.validate()))
	var s: Dictionary = GameRelief.data()["settings"]
	var keep: Variant
	for case in [["steps", 0], ["steps", 9], ["step_gain", 0.0], ["step_gain", 0.3], ["alt_span", 0.0], ["alt_mid", 1.5], ["deep_depth", 0], ["lake_deep", 0], ["snow_line", 5], ["snow_line", 999]]:
		keep = s[case[0]]
		s[case[0]] = case[1]
		ok(not GameRelief.validate().is_empty(), "%s of %s is refused" % [case[0], str(case[1])])
		s[case[0]] = keep
	keep = s["snow_biomes"]
	s["snow_biomes"] = ["mars"]
	ok(not GameRelief.validate().is_empty(), "snow on a biome that does not exist is refused")
	s["snow_biomes"] = keep
	var gone: Variant = s["slope_k"]
	s.erase("slope_k")
	ok(not GameRelief.validate().is_empty(), "a missing setting is refused")
	s["slope_k"] = gone
	ok(GameRelief.validate().is_empty(), "and the data is back as it was")
