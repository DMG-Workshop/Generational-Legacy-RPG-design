## The towns of the open world (core/game/game_town.gd, data/world/towns.json, ui/play/building_art.gd, data/art/buildings.json):
## each of the four towns has a building behind every service door, the home town has the family house, every town has its plain
## houses; a building is a body that blocks a walker, never the anchor or a door; each building is on dry, flat, clear ground
## inside the town; the family's homestead plot beside the home town (the ground it builds on); the pixel art of every kind; and the sandbox screen drawing the party, the creatures and the buildings.
## Run: godot --headless --path . -s res://tests/test_game_town.gd
extends SceneTree

const SandboxScreen := preload("res://ui/play/sandbox_screen.gd")
const SpriteArt := preload("res://ui/play/sprite_art.gd")

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
	test_layout()
	test_blocking()
	test_ground()
	test_walking()
	test_plot()
	test_art()
	test_data()
	await test_screen()
	print("town tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## Two colours within one step of 8-bit rounding.
func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01 and absf(a.a - b.a) < 0.01


func _dyn(seed_value: int = 77) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


func test_layout() -> void:
	var towns := GameTown.towns()
	ok(towns.size() == 4 and towns.has("hearthmere") and towns.has("kingshold") and towns.has("brinehaven") and towns.has("ironford"), "four towns have buildings: %s" % str(towns))
	var home := str(GameData.world["start"])
	for place in towns:
		var kinds := {}
		var houses := 0
		for b in GameTown.buildings(place):
			kinds[str(b["kind"])] = true
			if str(b["kind"]) == "house":
				houses += 1
		var services: Array = []
		for l in GameData.world["locations"]:
			if str(l["id"]) == place:
				services = l.get("services", [])
		for s in services:
			ok(kinds.has(str(s)), "%s has a %s building" % [place, s])
		ok(kinds.has("family") == (place == home), "%s: the family house is in the home town and only there" % place)
		ok(houses == (GameTown.data()["houses"] as Array).size(), "%s has its plain houses (%d)" % [place, houses])
		var count := 0
		for k in kinds:
			count += 1
		ok(count == services.size() + (1 if place == home else 0) + 1, "%s has nothing else (a building for each service, the house, plain houses)" % place)
	# each service building stands behind its own door: the door is the door tile in spaces.json and the body is above it
	for b in GameTown.all():
		if str(b["kind"]) == "house" or str(b["kind"]) == "family":
			continue
		var space := GameSpaces.root_id() + "/" + str(b["place"]) + "/" + str(b["kind"])
		var door: Dictionary = GameSpaces.space(space)["door"]
		ok(b["door"] == Vector2i(int(door["x"]), int(door["z"])), "%s's door is the door tile of its service" % b["id"])
		ok(int(b["x"]) + (int(b["w"]) - 1) / 2 == int(door["x"]) and int(b["z"]) + int(b["h"]) == int(door["z"]), "%s stands right behind its door" % b["id"])
	var family: Dictionary = {}
	for b in GameTown.buildings(home):
		if str(b["kind"]) == "family":
			family = b
	var hd: Dictionary = GameSpaces.space(GameSpaces.house())["door"]
	ok(not family.is_empty() and family["door"] == Vector2i(int(hd["x"]), int(hd["z"])), "the family house stands behind the house's door")
	var again := GameTown.all()
	ok(again.size() == GameTown.all().size() and (again[0] as Dictionary)["style"] == (GameTown.all()[0] as Dictionary)["style"], "the layout is the same each time it is asked")
	for b in again:
		ok(int(b["style"]) >= 0 and int(b["style"]) < int(GameTown.setting("styles")), "%s has a style in range" % b["id"])


func test_blocking() -> void:
	var b: Dictionary = GameTown.buildings("hearthmere")[0]
	ok(GameTown.blocks(int(b["x"]), int(b["z"])) and GameTown.blocks(int(b["x"]) + int(b["w"]) - 1, int(b["z"]) + int(b["h"]) - 1), "the corners of a building block")
	ok(not GameTown.blocks(int(b["x"]) - 1, int(b["z"])) and not GameTown.blocks(int(b["x"]) + int(b["w"]), int(b["z"])), "and the tiles beside it do not")
	ok(not GameTown.blocks(b["door"].x, b["door"].y), "nor does the tile in front of its door")
	ok(GameTown.at(int(b["x"]), int(b["z"]))["id"] == b["id"] and GameTown.at(0, 0).is_empty(), "at() finds the building a tile is in")
	var rect := Rect2i(int(b["x"]) - 2, int(b["z"]) - 2, 6, 6)
	var found := false
	for x in GameTown.in_rect(rect):
		if x["id"] == b["id"]:
			found = true
	ok(found and GameTown.in_rect(Rect2i(-500, -500, 3, 3)).is_empty(), "in_rect finds the buildings in a view")
	var d := _dyn()
	var ground := GamePath.world_ground(d)
	var walker: Dictionary = GamePath.data()["movers"]["walker"]
	ok(not GamePath.passable(ground, Vector3i(int(b["x"]), GamePath.SURFACE, int(b["z"])), walker), "a walker cannot stand in a building")
	ok(GamePath.passable(ground, Vector3i(b["door"].x, GamePath.SURFACE, b["door"].y), walker), "but can stand at its door")
	GameCraft.add_material(d, "oak", 50)
	d.heir.gold = 500
	ok(GameBuild.check(d, "floor", int(b["x"]), GameBuild.SURFACE, int(b["z"])) != "", "and nothing can be built inside one: %s" % GameBuild.check(d, "floor", int(b["x"]), GameBuild.SURFACE, int(b["z"])))


func test_ground() -> void:
	var s := int(GameTown.setting("w"))
	for sd in [77, 5, 12]:
		var d := _dyn(sd)
		var bad := 0
		var heights := {}
		for b in GameTown.all():
			for dz in int(b["h"]):
				for dx in int(b["w"]):
					var x := int(b["x"]) + dx
					var z := int(b["z"]) + dz
					var t := GameWorldGen.tile(d, x, z)
					heights["%s:%d" % [b["place"], int(t["height"])]] = true
					if t["water"] or t["body"] != "" or not t["node"].is_empty():
						bad += 1
		ok(bad == 0, "seed %d: every building stands on dry ground with no tree or rock on it (%d do not)" % [sd, bad])
		var per_town := {}
		for k in heights:
			var place := str(k).split(":")[0]
			per_town[place] = int(per_town.get(place, 0)) + 1
		var flat := true
		for p in per_town:
			if per_town[p] > 1:
				flat = false
		ok(flat, "seed %d: and on flat ground, one height in each town" % sd)
		for place in GameTown.towns():
			var a := GameWorldGen.anchor(place)
			var tile := GameWorldGen.tile(d, int(a["x"]), int(a["z"]))
			ok(not GameTown.blocks(int(a["x"]), int(a["z"])) and not tile["water"], "seed %d: the middle of %s is free" % [sd, place])
	ok(s == 3, "(a building is three tiles wide: a door in the middle)")


func test_walking() -> void:
	# From the middle of each town a walker reaches every door, and the heir cannot step into a building.
	for sd in [77, 5]:
		var d := _dyn(sd)
		var ground := GamePath.world_ground(d)
		for place in GameTown.towns():
			var a := GameWorldGen.anchor(place)
			var start := Vector3i(int(a["x"]), GamePath.SURFACE, int(a["z"]))
			var lost: Array = []
			for b in GameTown.buildings(place):
				var r := GamePath.find(ground, start, Vector3i(b["door"].x, GamePath.SURFACE, b["door"].y), "walker", 4000)
				if not bool(r["found"]):
					lost.append(str(b["id"]))
			ok(lost.is_empty(), "seed %d: from the middle of %s a walker reaches every door (cannot reach %s)" % [sd, place, str(lost)])
	var d := _dyn()
	var s := GameSandbox.start(d)
	var b: Dictionary = GameTown.buildings("hearthmere")[0]
	s.heir = b["door"]
	var c := s.can_step(0, -1)
	ok(not c["ok"], "the heir at a door cannot walk into the building behind it")
	ok(s.can_step(0, 1)["ok"] or s.can_step(1, 1)["ok"], "and can walk away from it")
	# the door still works
	var service := str(b["kind"])
	if service != "house" and service != "family":
		ok(s.door_here() == GameSpaces.root_id() + "/hearthmere/" + service, "the heir at the door of the %s is at its door" % service)


func test_plot() -> void:
	var plots := GameWorldGen.plots()
	ok(plots.size() == 1, "the home town has a homestead plot")
	var home := str(GameData.world["start"])
	var plot := GameWorldGen.plot(home)
	ok(not plot.is_empty() and str(plot["place"]) == home and str(plot["type"]) == "plot", "found beside the home town")
	ok(GameWorldGen.plot("kingshold").is_empty(), "and none beside the others")
	ok(GameBuild.base()["x"] == plot["x"] and GameBuild.base()["z"] == plot["z"], "the family builds round it, not in the town")
	ok(GameWorldGen.anchors().size() == 17 and GameWorldGen.zones().size() == 18, "it is not a place: 17 places and one plot of ground")
	var a := GameWorldGen.anchor(home)
	ok(Vector2(float(plot["x"]) - float(a["x"]), float(plot["z"]) - float(a["z"])).length() > float(a["radius"]) + float(plot["radius"]), "and it lies clear of the town's ground")
	for sd in [77, 5, 12, 31]:
		var d := _dyn(sd)
		var r := int(plot["radius"])
		var bad := 0
		var heights := {}
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if Vector2(dx, dz).length() > float(r):
					continue
				var x := int(plot["x"]) + dx
				var z := int(plot["z"]) + dz
				var t := GameWorldGen.tile(d, x, z)
				heights[int(t["height"])] = true
				if t["water"] or t["body"] != "" or not t["node"].is_empty() or GameTown.blocks(x, z):
					bad += 1
		ok(bad == 0, "seed %d: the plot is dry, clear of trees and rocks and of the town's buildings (%d tiles are not)" % [sd, bad])
		ok(heights.size() == 1, "seed %d: and flat (%d heights)" % [sd, heights.size()])
		ok(GameWorldGen.in_anchor_ground(int(plot["x"]), int(plot["z"])), "seed %d: the land treats it as cleared ground" % sd)
	# the data checks
	var list: Array = GameWorldGen.setting("plots")
	var keep: Array = list.duplicate(true)
	list[0]["dx"] = 3
	ok(not GameWorldGen.validate().is_empty(), "a plot on the town's own ground is refused")
	list[0]["dx"] = 18
	list[0]["near"] = "nowhere"
	ok(not GameWorldGen.validate().is_empty(), "a plot beside no place is refused")
	list[0]["near"] = "hearthmere"
	list[0]["radius"] = 0
	ok(not GameWorldGen.validate().is_empty(), "a plot with no ground is refused")
	list[0]["radius"] = 8
	list.append({"id": "hearthmere_homestead", "near": "hearthmere", "dx": 30, "dz": 0, "radius": 4})
	ok(not GameWorldGen.validate().is_empty(), "two plots with one id are refused")
	list.pop_back()
	list[0] = keep[0].duplicate(true)
	ok(GameWorldGen.validate().is_empty(), "and the data is back as it was")


func test_art() -> void:
	var kinds := ["house", "family", "forge", "temple", "store", "tavern", "board", "black_market"]
	var looks := {}
	for kind in kinds:
		var img := BuildingArt.image(kind, 0)
		var sz := GameTown.size_of(kind)
		img = BuildingArt.image(kind, 0, sz.x, sz.y)
		ok(img.get_width() == sz.x * BuildingArt.TILE and img.get_height() == sz.y * BuildingArt.TILE, "%s is %d by %d pixels" % [kind, img.get_width(), img.get_height()])
		var opaque := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.0:
					opaque += 1
		var share := float(opaque) / float(img.get_width() * img.get_height())
		ok(share > 0.35 and share < 0.98, "%s fills part of its tiles (%.0f%%)" % [kind, share * 100.0])
		var line := Color.html(str(BuildingArt.data()["outline"]))
		var outlined := 0
		for x in img.get_width():
			if img.get_pixel(x, img.get_height() - 1).a > 0.0 or img.get_pixel(x, 0).a > 0.0:
				outlined += 1
		ok(img.get_pixel(0, 8) != Color(0, 0, 0, 0) or kind == "board", "%s is outlined where it meets the edge" % kind)
		looks[kind] = img.get_data()
		ok(BuildingArt.image(kind, 0, sz.x, sz.y).get_data() == img.get_data(), "%s paints the same pixels every time" % kind)
		ok(BuildingArt.texture(kind, 0, sz.x, sz.y) == BuildingArt.texture(kind, 0, sz.x, sz.y), "%s's texture is kept" % kind)
	var seen := {}
	for kind in kinds:
		seen[looks[kind]] = true
	ok(seen.size() == kinds.size(), "every kind looks different from the others")
	ok(BuildingArt.image("house", 0).get_data() != BuildingArt.image("house", 1).get_data(), "a plain house has more than one style")
	ok(BuildingArt.image("forge", 0).get_data() == BuildingArt.image("forge", 3).get_data(), "and a forge has one")
	ok(BuildingArt.texture("house", 1) == BuildingArt.texture("house", 1 + (BuildingArt.data()["styles"] as Array).size()), "a style past the end comes round")
	# what the features paint
	var forge := BuildingArt.image("forge")
	ok(_near(forge.get_pixel(24, 26), Color.html(str(BuildingArt.data()["colors"]["glow"])).lightened(0.35)), "a forge's door glows")
	ok(_near(forge.get_pixel(21, 20), Color.html(str(BuildingArt.data()["colors"]["glow"]))) and not _near(BuildingArt.image("house").get_pixel(21, 20), Color.html(str(BuildingArt.data()["colors"]["glow"]))), "and only a forge's door is the colour of fire")
	var line := Color.html(str(BuildingArt.data()["outline"]))
	ok(_near(forge.get_pixel(10, 2), line) and _near(BuildingArt.image("board").get_pixel(10, 4), line) and _near(BuildingArt.image("family").get_pixel(10, 2), line), "a building and the notice board are outlined above their top edge")
	var temple := BuildingArt.image("temple")
	ok(temple.get_pixel(23, 4).is_equal_approx(Color.html(str(BuildingArt.data()["colors"]["gold"]))), "a temple has its cross")
	ok(BuildingArt.image("house").get_pixel(23, 4).a > 0.0 and not BuildingArt.image("house").get_pixel(38, 4).is_equal_approx(BuildingArt.image("temple").get_pixel(38, 4)), "a house has a chimney a temple has not")
	ok(BuildingArt.image("board").get_pixel(24, 2).a == 0.0, "the notice board has no roof over it")
	ok(BuildingArt.image("nothing").get_pixel(24, 16).a == 0.0, "a kind with no look paints nothing")
	var flag := Color.html(str(BuildingArt.data()["colors"]["flag"]))
	ok(BuildingArt.image("family").get_pixel(26, 1).is_equal_approx(flag), "the family house flies its flag")
	ok(BuildingArt.image("store").get_pixel(14, 17) != BuildingArt.image("store").get_pixel(17, 17), "a store's awning is striped")


func test_screen() -> void:
	var d := _dyn()
	d.world.visit("hearthmere")
	for id in ["bren_cask", "sister_oriel"]:   # two hired companions, as the screenshot tool does
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": 18, "gen": 1,
			"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
		d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
			"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	d.party.rest(d)
	var app := FakeApp.new()
	app.dynasty = d
	root.add_child(app)
	var scr: Control = SandboxScreen.new()
	scr.app = app
	scr.size = Vector2(1280, 720)
	root.add_child(scr)
	await process_frame
	await process_frame
	var b: Dictionary = GameTown.buildings("hearthmere")[0]
	scr.sb.heir = b["door"]
	scr.sb.creatures.clear()
	scr.sb.creatures.append(GameBehaviour.new_agent(901, "wolf", float(b["door"].x) + 3.5, float(b["door"].y) + 2.5))
	scr.sb.companions = GameCompanions.agents_for(d, float(b["door"].x) + 0.5, float(b["door"].y) + 0.5)
	scr.overlay.queue_redraw()
	await process_frame
	await process_frame
	ok(scr.sb.companions.size() >= 1 and not scr._figures.is_empty(), "the party's figures are made when the map is drawn (%d)" % scr._figures.size())
	var first: String = scr.sb.companions[0]["id"]
	ok(scr._party_figure(first) != null and scr._party_figure("nobody") == null, "a hired companion has a figure and a stranger has none")
	ok(scr._party_figure(first) == scr._party_figure(first), "and it is kept")
	var tex: Texture2D = SpriteArt.figure(d.heir)
	var box: Vector2 = scr._figure_size(tex, 16.0)
	ok(is_equal_approx(box.y, 16.0 * float(SandboxScreen.setting("figure_tiles"))) and is_equal_approx(box.x / box.y, float(tex.get_width()) / float(tex.get_height())), "a figure is figure_tiles tall and keeps its shape")
	ok(SpriteArt.creature("wolf") != null, "(a wolf has art)")
	# facing: the way it last went
	ok(not scr._faces_right("k", 10.0), "a thing first seen faces west (the creature art's way)")
	ok(not scr._faces_right("k", 10.0), "and still does when it has not moved")
	ok(scr._faces_right("k", 11.0), "and faces east after a step east")
	ok(scr._faces_right("k", 11.0), "and keeps facing that way standing still")
	ok(not scr._faces_right("k", 10.5), "and west after a step west")
	ok(scr._faces_right("other", 5.0) == false and scr._faces_right("k", 10.5) == false, "each has its own")
	# every setting the drawing needs is in the data
	for key in ["figure_tiles", "creature_pixel", "creature_max_tiles", "shadow_alpha", "night_dim"]:
		ok(GameSandbox.data()["view"].has(key), "view setting %s is in the data" % key)
	scr.queue_free()
	app.queue_free()


func test_data() -> void:
	ok(GameTown.validate().is_empty(), "the town data is sound: %s" % str(GameTown.validate()))
	ok(BuildingArt.validate().is_empty(), "the building art is sound: %s" % str(BuildingArt.validate()))
	# a house on a door, one off the edge of the town, two on each other
	var keep: Variant = GameTown.data()["houses"].duplicate(true)
	var h: Array = GameTown.data()["houses"]
	h.append([-9, -6])   # on the forge's door tile in every town that has a forge
	ok(not GameTown.validate().is_empty(), "a house on a door is refused")
	GameTown.data()["houses"] = keep.duplicate(true)
	GameTown.data()["houses"].append([20, 20])
	ok(not GameTown.validate().is_empty(), "a house out past the town is refused")
	GameTown.data()["houses"] = keep.duplicate(true)
	GameTown.data()["houses"].append(GameTown.data()["houses"][0].duplicate())
	ok(not GameTown.validate().is_empty(), "two houses on one place are refused")
	GameTown.data()["houses"] = keep.duplicate(true)
	GameTown.data()["houses"].append([0, 0])
	ok(not GameTown.validate().is_empty(), "a house on the middle of the town is refused")
	GameTown.data()["houses"] = keep.duplicate(true)
	ok(GameTown.validate().is_empty(), "and the data is back as it was")
	var s: Dictionary = GameTown.data()["settings"]
	for case in [["w", 0], ["h", 0], ["styles", 0]]:
		var old: Variant = s[case[0]]
		s[case[0]] = case[1]
		ok(not GameTown.validate().is_empty(), "%s of %s is refused" % [case[0], str(case[1])])
		s[case[0]] = old
	GameTown.validate()   # rebuilds the layout from the restored data
	var bd: Dictionary = BuildingArt.data()
	var colors: Dictionary = bd["colors"]
	var gone: Variant = colors["glow"]
	colors["glow"] = "not a colour"
	ok(not BuildingArt.validate().is_empty(), "a colour that is not one is refused")
	colors["glow"] = gone
	var kinds: Dictionary = bd["kinds"]
	var forge: Variant = kinds["forge"].duplicate(true)
	kinds["forge"]["features"] = ["chimney", "moat"]
	ok(not BuildingArt.validate().is_empty(), "a feature that does not exist is refused")
	kinds["forge"] = forge.duplicate(true)
	kinds.erase("tavern")
	ok(not BuildingArt.validate().is_empty(), "a town building with no look is refused")
	kinds["tavern"] = {"roof": ["#7a5a34", "#563d20"], "wall": ["#cfb48a", "#a58d63"], "features": ["chimney", "sign"], "furniture": ["bar", "tables"]}
	kinds["forge"] = forge
	ok(BuildingArt.validate().is_empty(), "and the art is back as it was")
