## Houses of every size, the people in them and walls that join (core/game/game_town.gd sizes, core/game/game_villagers.gd,
## ui/play/building_art.gd, ui/play/tile_view.gd wall joins). Buildings are not all one size: a hut is small and a temple large, the
## art is drawn to each one's size, the door is always in front of the bottom middle; plain houses have residents by the size of
## their body, standing where GameVillagers says by the hour; a built wall is drawn joined to the walls and doors beside it.
## Run: godot --headless --path . -s res://tests/test_game_house_look.gd
extends SceneTree

const SpriteArt := preload("res://ui/play/sprite_art.gd")

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
	test_sizes()
	test_villagers()
	await test_walls()
	test_data()
	print("house look tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func test_sizes() -> void:
	var seen := {}
	for b in GameTown.all():
		seen["%dx%d" % [b["w"], b["h"]]] = true
		ok(b["door"] == Vector2i(int(b["x"]) + (int(b["w"]) - 1) / 2, int(b["z"]) + int(b["h"])), "%s's door is in front of its bottom middle" % b["id"])
		for dz in int(b["h"]):
			for dx in int(b["w"]):
				ok(GameTown.blocks(int(b["x"]) + dx, int(b["z"]) + dz), "%s blocks its whole body" % b["id"])
	ok(seen.size() >= 5, "the buildings come in many sizes: %s" % str(seen.keys()))
	ok(GameTown.size_of("temple").x * GameTown.size_of("temple").y > GameTown.size_of("black_market").x * GameTown.size_of("black_market").y, "a temple is larger than a market hut")
	for place in GameTown.towns():
		var sizes := {}
		for b in GameTown.buildings(place):
			if str(b["kind"]) == "house":
				sizes["%dx%d" % [b["w"], b["h"]]] = true
		ok(sizes.size() >= 3, "%s's plain houses are not all alike" % place)
	# the art is as big as the body, and is not a stretched copy
	var small := BuildingArt.image("house", 0, 2, 2)
	var big := BuildingArt.image("house", 0, 4, 3)
	ok(small.get_size() == Vector2i(32, 32) and big.get_size() == Vector2i(64, 48), "house art is drawn to its size")
	ok(BuildingArt.texture("house", 0, 2, 2) != BuildingArt.texture("house", 0, 4, 3), "and each size has its own texture")
	var door_px := func(img: Image, w: int) -> bool:
		var cx := ((w - 1) / 2) * 16 + 8
		return img.get_pixel(cx - 2, img.get_height() - 4).a > 0.0
	ok(door_px.call(small, 2) and door_px.call(big, 4), "the door is at the bottom middle of each")
	var windows := func(img: Image) -> int:
		var n := 0
		var glass := Color.html(str(BuildingArt.data()["colors"]["glass"]))
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).is_equal_approx(glass):
					n += 1
		return n
	ok(windows.call(big) > windows.call(small), "a wider house has more windows")
	for b in GameTown.all():
		var inside := BuildingArt.inside(str(b["kind"]), int(b["style"]), int(b["w"]), int(b["h"]))
		if str(b["kind"]) != "board":
			ok(inside != null and inside.get_width() == int(b["w"]) * 16 and inside.get_height() == int(b["h"]) * 16, "%s has an inside as big as its body" % b["id"])


func test_villagers() -> void:
	var houses := 0
	var by_size := {}
	for b in GameTown.all():
		var who := GameVillagers.residents(b)
		var kind := str(b["kind"])
		if kind == "family" or kind == "board":
			ok(who.is_empty(), "%s has no villagers (the family's own, or a board)" % b["id"])
			continue
		ok(not who.is_empty(), "%s has someone in it" % b["id"])
		if kind == "house":
			houses += 1
			by_size[int(b["w"]) * int(b["h"])] = who.size()
			var need := 0.0
			for r in who:
				need += GameVillagers.need_of(float(r["scale"]))
			ok(who.size() <= int(GameVillagers.data()["settings"]["max_residents"]) and (need <= float(int(b["w"]) * int(b["h"])) or who.size() == 1), "%s's people fit in it (%.0f of %d tiles)" % [b["id"], need, int(b["w"]) * int(b["h"])])
		else:
			ok(who.size() == 1 and str(who[0]["service"]) == kind, "%s has its one person" % b["id"])
			var person := GamePeople.in_space(GameSpaces.root_id() + "/" + str(b["place"]) + "/" + kind)
			ok(not person.is_empty(), "%s's person is the one the interior has" % b["id"])
		ok(who == GameVillagers.residents(b), "%s's people are the same every time" % b["id"])
		for i in who.size():
			if str(who[i]["creature"]) != "":
				ok(SpriteArt.has_creature(str(who[i]["creature"])), "%s's monster has art" % b["id"])
			else:
				ok(SpriteArt.has_class(str(who[i]["class"])) and SpriteArt.has_race(str(who[i]["race"])), "%s's people have art" % b["id"])
	ok(houses > 0, "there are plain houses")
	ok(GameVillagers.count_for(10) < GameVillagers.count_for(40), "a larger house has more people")
	test_sizes_of_people()
	# where they are
	for b in GameTown.all():
		var who := GameVillagers.residents(b)
		for i in who.size():
			for hour in [3.0, 9.0, 13.0, 19.0]:
				var night: bool = hour < 6.0 or hour > 18.0
				var sp := GameVillagers.spot(b, i, hour, night)
				var c: Vector2i = sp["cell"]
				ok(c.x >= 0 and c.x < int(b["w"]) and c.y >= 0 and c.y < int(b["h"]), "%s's person %d stands inside the body at %.0f" % [b["id"], i, hour])
				ok(bool(sp["asleep"]) == (night and str(who[i]["service"]) == ""), "only a resident sleeps, and only by night (%s)" % b["id"])
				if not night and str(who[i]["service"]) == "" and int(b["h"]) > 1:
					ok(c.y >= 1, "by day a resident is below the furniture row")
	var house: Dictionary = {}
	for b in GameTown.all():
		if str(b["kind"]) == "house" and GameVillagers.residents(b).size() >= 2:
			house = b
			break
	var cells := {}
	for hr in range(0, 24, 2):
		cells[GameVillagers.spot(house, 0, float(hr) + 8.0, false)["cell"]] = true
	ok(cells.size() > 1, "a resident moves about the house through the day")
	ok(GameVillagers.spot(house, 0, 9.0, false) == GameVillagers.spot(house, 0, 9.9, false), "and keeps to a place for the hours of one slot")
	ok(GameVillagers.spot(house, 99, 9.0, false).is_empty(), "nobody is a resident who does not exist")
	var before := GameDynasty.new_game(7, "T", "warrior", "faetouched")
	var json := JSON.stringify(before.to_dict())
	GameVillagers.spot(house, 0, 9.0, false)
	ok(JSON.stringify(before.to_dict()) == json, "asking draws no dice and changes nothing")


func test_sizes_of_people() -> void:
	ok(GameVillagers.scale_of("halfling") < GameVillagers.scale_of("human") and GameVillagers.scale_of("human") < GameVillagers.scale_of("orc") and GameVillagers.scale_of("dragonborn") > GameVillagers.scale_of("dwarf"), "the small races are smaller than people and the large ones larger")
	ok(GameVillagers.scale_of("nobody") == 1.0, "an unknown race is a human's size")
	ok(GameVillagers.need_of(2.0) == 4.0 * GameVillagers.need_of(1.0), "a floor goes by the square of the size: twice as tall needs four times the room")
	var monsters := {}
	var biggest_need := 0.0
	for b in GameTown.all():
		if str(b["kind"]) != "house":
			continue
		var area := float(int(b["w"]) * int(b["h"]))
		for r in GameVillagers.residents(b):
			if str(r["creature"]) != "":
				monsters[str(r["creature"])] = true
				ok(GameVillagers.need_of(float(r["scale"])) <= area, "a %s lives only where there is room for it (%s)" % [r["creature"], b["id"]])
				biggest_need = maxf(biggest_need, GameVillagers.need_of(float(r["scale"])))
		ok(GameVillagers.door_scale(b) >= 1.0, "a door is at least a human's")
	ok(not monsters.is_empty(), "monsters live in the villages too: %s" % str(monsters.keys()))
	# a house for the large has a taller, wider door than a hut for the small
	var tall := BuildingArt.image("house", 0, 6, 5, 1.8)
	var normal := BuildingArt.image("house", 0, 6, 5, 1.0)
	var door_height := func(img: Image) -> int:
		var door := Color.html(str(BuildingArt.data()["colors"]["door_dark"]))
		var cx := ((6 - 1) / 2) * 16 + 8
		var n := 0
		for y in img.get_height():
			if img.get_pixel(cx - 1, y).is_equal_approx(door):
				n += 1
		return n
	ok(door_height.call(tall) > door_height.call(normal), "a door made for an ogre is taller than a human's")
	ok(BuildingArt.texture("house", 0, 6, 5, 1.8) != BuildingArt.texture("house", 0, 6, 5, 1.0), "and is its own picture")
	var keep: Variant = GameVillagers.data()["monsters"].duplicate(true)
	GameVillagers.data()["monsters"].append({"creature": "ogre", "scale": 3.0, "places": ["ironford"]})
	ok(not GameVillagers.validate().is_empty(), "a monster no house is big enough for is caught")
	GameVillagers.data()["monsters"] = keep
	ok(GameVillagers.validate().is_empty(), "and mending the data clears it")


func test_walls() -> void:
	var d := GameDynasty.new_game(7, "T", "warrior", "faetouched")
	var s := GameBuild.SURFACE
	var base := GameBuild.base()
	var x := int(base["x"]) - 3
	var z := int(base["z"]) - 3
	d.built[GameBuild.key(x, s, z)] = "wall"
	ok(TileView.join_mask(d, x, s, z) == 0, "a lone wall has nothing beside it")
	d.built[GameBuild.key(x + 1, s, z)] = "wall"
	d.built[GameBuild.key(x, s, z + 1)] = "door"
	ok(TileView.join_mask(d, x, s, z) == 2 + 4, "a wall to the east and a door to the south join it there")
	d.built[GameBuild.key(x - 1, s, z)] = "floor"
	ok(TileView.join_mask(d, x, s, z) == 2 + 4, "a floor beside it does not")
	# the atlas draws each way of joining
	var ts := TileView.make_tileset()
	var src: TileSetAtlasSource = ts.get_source(0)
	var img: Image = src.texture.get_image()
	var px := int(TileView.settings()["px"])
	var all := TileView.kinds()
	var edge := Color(float((TileView.settings()["wall_edge"] as Array)[0]), float((TileView.settings()["wall_edge"] as Array)[1]), float((TileView.settings()["wall_edge"] as Array)[2]))
	var alone := (all.size() + 0) * px
	var joined := (all.size() + 15) * px
	var near := func(a: Color, b: Color) -> bool:
		return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01
	ok(near.call(img.get_pixel(alone + 8, 0), edge) and near.call(img.get_pixel(alone + 0, 8), edge), "a wall with nothing beside it has an edge on its sides")
	ok(not near.call(img.get_pixel(joined + 8, 0), edge) and not near.call(img.get_pixel(joined + 0, 8), edge) and not near.call(img.get_pixel(joined + px - 1, 8), edge), "and one joined every way has none")
	ok(not near.call(img.get_pixel(joined + 8, 0), img.get_pixel(alone + 8, 0)), "so the two do not look alike")
	var all_look := {}
	for m in TileView.JOINS:
		var piece := img.get_region(Rect2i((all.size() + m) * px, 0, px, px))
		all_look[piece.get_data()] = true
	ok(all_look.size() == TileView.JOINS, "each of the %d joins looks different" % TileView.JOINS)
	# the view: a wall set beside another redraws the other, and a wall taken down lets it go
	var v := TileView.new()
	v.setup(d)
	root.add_child(v)
	v.show_view(Vector2(float(x), float(z)), Vector2(6, 6))
	var n := int(TileView.settings()["chunk"])
	var c := TileView.chunk_of(x, z)
	var layer: TileMapLayer = v.layers[c]
	var local := Vector2i(x - c.x * n, z - c.y * n)
	v.refresh_cell(x, z)
	ok(TileView.cell_kind(layer, local) == "wall" and layer.get_cell_atlas_coords(local).x == all.size() + 6, "the wall is drawn joined east and south")
	d.built[GameBuild.key(x, s, z - 1)] = "wall"
	v.refresh_cell(x, z - 1)
	ok(layer.get_cell_atlas_coords(local).x == all.size() + 7, "a wall built to its north redraws it: its own tile was not touched")
	d.built.erase(GameBuild.key(x, s, z - 1))
	v.refresh_cell(x, z - 1)
	ok(layer.get_cell_atlas_coords(local).x == all.size() + 6, "and taken down it lets go")
	v.queue_free()
	await process_frame


func test_data() -> void:
	ok(GameVillagers.validate().is_empty(), "the villagers' data is sound: %s" % str(GameVillagers.validate()))
	var keep: Variant = GameVillagers.data()["classes"].duplicate()
	GameVillagers.data()["classes"].append("necro_hat")
	ok(not GameVillagers.validate().is_empty(), "a class with no art is refused")
	GameVillagers.data()["classes"] = keep
	var sizes: Dictionary = GameTown.data()["sizes"]
	sizes["forge"] = [30, 30]
	ok(not GameTown.validate().is_empty(), "a building too big is refused")
	sizes["forge"] = [4, 3]
	ok(GameTown.validate().is_empty(), "and mending it clears that")
