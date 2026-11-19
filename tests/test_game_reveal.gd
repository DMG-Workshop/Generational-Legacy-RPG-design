## Doll houses (core/game/game_reveal.gd, ui/play/tile_view.gd, ui/play/building_art.gd): a house has its roof on from outside and
## the roof thins and goes as the heir comes close, so the rooms show. The arithmetic is pure; the family's roofs lift as one house;
## nobody under a whole roof is drawn; a town building has an inside to show. Nothing is saved and no dice are drawn.
## Run: godot --headless --path . -s res://tests/test_game_reveal.gd
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
	test_arithmetic()
	test_roofs()
	await test_view()
	test_buildings()
	test_data()
	print("reveal tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _house(d: GameDynasty, ox: int, oz: int, w: int, h: int) -> void:
	for x in w:
		for z in h:
			d.built[GameBuild.key(ox + x, GameBuild.SURFACE - 2, oz + z)] = "roof"


func test_arithmetic() -> void:
	var near := float(GameReveal.setting("near"))
	var far := float(GameReveal.setting("far"))
	var steps := int(GameReveal.setting("steps"))
	ok(GameReveal.alpha(far) == 1.0 and GameReveal.alpha(far + 5.0) == 1.0, "at far or more a roof is whole")
	ok(GameReveal.alpha(near) == 0.0 and GameReveal.alpha(0.0) == 0.0, "at near or less it is gone")
	var mid := GameReveal.alpha((near + far) * 0.5)
	ok(mid > 0.4 and mid < 0.6, "and half way between it is half there: %.2f" % mid)
	ok(GameReveal.step_for(far) == 0 and GameReveal.step_for(near) == steps, "step 0 is whole and `steps` is gone")
	var last := -1
	var rising := true
	for i in 40:
		var s := GameReveal.step_for(far - float(i) * 0.1)
		if s < last:
			rising = false
		last = s
	ok(rising, "the roof only goes further as the heir comes closer")
	var r := Rect2i(10, 10, 3, 2)
	ok(GameReveal.distance_to(r, 11.5, 10.5) == 0.0, "inside a footprint the distance is 0")
	ok(is_equal_approx(GameReveal.distance_to(r, 11.5, 15.0), 3.0), "south of it, the gap to its edge")
	ok(is_equal_approx(GameReveal.distance_to(r, 16.0, 16.0), 5.0), "and diagonally, the straight way to its corner (3, 4)")


func test_roofs() -> void:
	var d := GameDynasty.new_game(7, "T", "warrior", "faetouched")
	ok(GameReveal.roof_steps(d, 50.0, 50.0).is_empty(), "no houses, no roofs to lift")
	_house(d, 50, 50, 9, 6)
	ok(GameReveal.roofed(d, 50, 50) and GameReveal.roofed(d, 58, 55), "a column with a roof piece is roofed")
	ok(not GameReveal.roofed(d, 59, 50) and not GameReveal.roofed(d, 50, 56), "and one beside it is not")
	ok(GameReveal.roof_steps(d, 54.5, 70.5).is_empty(), "far off the roof is whole (nothing listed)")
	var inside := GameReveal.roof_steps(d, 54.5, 52.5)
	ok(inside.size() == 54, "inside, every roofed column of the house is listed: %d" % inside.size())
	var all_gone := true
	for k in inside:
		if int(inside[k]) != int(GameReveal.setting("steps")):
			all_gone = false
	ok(all_gone, "and all of them gone")
	var edge := GameReveal.roof_steps(d, 54.5, 58.5)   # 3 tiles from the south edge: part way
	var steps_seen := {}
	for k in edge:
		steps_seen[int(edge[k])] = true
	ok(edge.size() == 54 and steps_seen.size() == 1, "near the edge the whole house lifts together, to one step")
	ok(int(edge.values()[0]) > 0 and int(edge.values()[0]) < int(GameReveal.setting("steps")), "part way")
	_house(d, 70, 50, 3, 3)
	var near_a := GameReveal.roof_steps(d, 54.5, 52.5)
	ok(not near_a.has("70,50"), "a second house stays whole while the heir is in the first")
	var b := GameReveal.roof_steps(d, 71.5, 51.5)
	ok(b.has("70,50") and not b.has("50,50"), "and the first stays whole while the heir is in the second")
	var before := JSON.stringify(d.to_dict())
	GameReveal.roof_steps(d, 54.5, 52.5)
	ok(JSON.stringify(d.to_dict()) == before, "asking changes nothing in the dynasty")
	# the lift is capped
	var big := GameDynasty.new_game(7, "T", "warrior", "faetouched")
	_house(big, 0, 0, 40, 20)
	var keep: Variant = GameSandbox.data()["reveal"]["max_roof_cells"]
	GameSandbox.data()["reveal"]["max_roof_cells"] = 10
	var capped := GameReveal.roof_steps(big, 1.5, 1.5)
	ok(capped.size() < 800, "a huge roof is searched only so far: %d of 800" % capped.size())
	GameSandbox.data()["reveal"]["max_roof_cells"] = keep


func test_view() -> void:
	var d := GameDynasty.new_game(7, "T", "warrior", "faetouched")
	var base := GameBuild.base()
	var ox := int(base["x"]) - 4
	var oz := int(base["z"]) - 3
	_house(d, ox, oz, 6, 4)
	var v := TileView.new()
	v.setup(d)
	root.add_child(v)
	v.show_view(Vector2(float(ox), float(oz)), Vector2(8, 8))
	var n := int(TileView.settings()["chunk"])
	var c := TileView.chunk_of(ox, oz)
	var lid: TileMapLayer = v.roofs[c]
	var local := Vector2i(ox - c.x * n, oz - c.y * n)
	ok(lid.get_cell_source_id(local) == 0, "the roof is drawn over the house from outside")
	ok(v.covered(ox, oz), "and nobody there is seen")
	ok(not v.covered(ox - 3, oz), "but beside it they are")
	v.set_heir(float(ox) - 6.5, float(oz) + 1.5)
	ok(lid.get_cell_source_id(local) == 0 and lid.get_cell_alternative_tile(local) == 0, "with the heir far off it is whole")
	v.set_heir(float(ox) - 2.5, float(oz) + 1.5)
	var alt := lid.get_cell_alternative_tile(local)
	ok(lid.get_cell_source_id(local) == 0 and alt > TileView.ROOF_ALT, "coming near it thins: alternative %d" % alt)
	ok(not v.covered(ox, oz), "and what is under it is no longer hidden")
	v.set_heir(float(ox) + 2.5, float(oz) + 1.5)
	ok(lid.get_cell_source_id(local) == -1, "inside it is gone")
	v.set_heir(float(ox) - 6.5, float(oz) + 1.5)
	ok(lid.get_cell_source_id(local) == 0 and lid.get_cell_alternative_tile(local) == 0, "walking away puts it back")
	# a roof built or taken down shows at once
	var cell := Vector2i(ox + 8, oz)
	var c2 := TileView.chunk_of(cell.x, cell.y)
	var lid2: TileMapLayer = v.roofs[c2]
	d.built[GameBuild.key(cell.x, GameBuild.SURFACE - 2, cell.y)] = "roof"
	v.refresh_cell(cell.x, cell.y)
	ok(lid2.get_cell_source_id(Vector2i(cell.x - c2.x * n, cell.y - c2.y * n)) == 0, "a new roof is drawn")
	d.built.erase(GameBuild.key(cell.x, GameBuild.SURFACE - 2, cell.y))
	v.refresh_cell(cell.x, cell.y)
	ok(lid2.get_cell_source_id(Vector2i(cell.x - c2.x * n, cell.y - c2.y * n)) == -1, "and one taken down goes")
	# on a storey the lids are off, and the atlas has the fades
	v.set_level(1)
	ok(not lid.visible, "on a storey there is no lid")
	v.set_level(0)
	ok(lid.visible, "and back on the ground it is there again")
	var src: TileSetAtlasSource = v.tile_set.get_source(0)
	var ri := TileView.kinds().find("roof")
	var fades := true
	for k in range(1, int(GameReveal.setting("steps"))):
		if not src.has_alternative_tile(Vector2i(ri, 0), TileView.ROOF_ALT + k):
			fades = false
	ok(fades, "the atlas has a fainter roof for every step")
	v.queue_free()
	await process_frame


func test_buildings() -> void:
	var kinds: Dictionary = BuildingArt.data()["kinds"]
	for k in kinds:
		var sz := GameTown.size_of(k)
		var tex: Texture2D = BuildingArt.inside(k, 0, sz.x, sz.y)
		if str(kinds[k].get("shape", "")) == "board":
			ok(tex == null, "the notice board has no inside")
			continue
		ok(tex != null and tex.get_width() == sz.x * BuildingArt.TILE and tex.get_height() == sz.y * BuildingArt.TILE, "'%s' has an inside as big as its outside" % k)
		var img := BuildingArt.inside_image(k, sz.x, sz.y)
		var clear := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a < 1.0:
					clear += 1
		ok(clear == 0, "and it is solid, a floor to the walls ('%s')" % k)
	ok(BuildingArt.inside_image("forge", 4, 3).get_data() != BuildingArt.inside_image("temple", 4, 3).get_data(), "a forge's inside is not a temple's")
	var f: Array = kinds["forge"]["furniture"]
	f.append("sofa")
	ok(not BuildingArt.validate().is_empty(), "furniture the art does not know is caught")
	f.erase("sofa")
	ok(BuildingArt.validate().is_empty(), "and mending it clears that")


func test_data() -> void:
	ok(GameReveal.validate().is_empty(), "the shipped reveal settings pass")
	var s: Dictionary = GameSandbox.data()["reveal"]
	var keep: Variant = s["far"]
	s["far"] = 0.5
	ok(not GameReveal.validate().is_empty(), "a far not above near is caught")
	s["far"] = keep
	s.erase("steps")
	ok(not GameReveal.validate().is_empty(), "a missing setting is caught")
	s["steps"] = 4
	ok(GameReveal.validate().is_empty(), "and mending it clears that")
