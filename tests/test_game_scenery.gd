## Battle scenery (ui/play/scenery_art.gd): the scenery data is sound, every place in the world has a scene, a
## scene is painted the same every time with its own dice (never the dynasty's), the weather and the season
## change it out of doors but not under the ground, scenes are kept and scaled by whole pixels, the cover fit
## keeps the sky in sight, and the battle screen draws the scene of the place a fight is in behind the
## figures, under a veil (thicker with high contrast), with plates under the names.
## Run: godot --headless --path . -s res://tests/test_game_scenery.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const TouchHint := preload("res://ui/play/touch_hint.gd")
const SceneryArt := preload("res://ui/play/scenery_art.gd")
const TRIO := ["sister_oriel", "bren_cask", "tarsk_ember_eye"]
const DIR := "user://test_scenery/"

var fails := 0
var checks := 0
var app: Node


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	test_data_is_sound()
	test_every_place_has_a_scene()
	test_same_every_time()
	test_weather_and_seasons()
	test_kept_and_whole_pixels()
	test_cover()
	await test_battle_screen()
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
	print("scenery tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _same(a: Image, b: Image) -> bool:
	return a.get_size() == b.get_size() and a.get_data() == b.get_data()


# ---------------------------------------------------------------- the data and the painting

func test_data_is_sound() -> void:
	var problems := SceneryArt.validate()
	ok(problems.is_empty(), "the scenery data is sound: %s" % str(problems.slice(0, 5)))


func test_every_place_has_a_scene() -> void:
	var missing: Array = []
	for l in GameData.world["locations"]:
		if SceneryArt.scene_id(str(l["id"])) == "":
			missing.append(l["id"])
	ok(missing.is_empty(), "every place in the world has a scene; missing: %s" % str(missing))
	ok(SceneryArt.scene_id("whisperwood") == "forest", "a place is drawn as its first biome")
	ok(SceneryArt.scene_id("elderglade") == "fae", "unless the place has a scene of its own")
	ok(SceneryArt.scene_id("no_such_place") != "", "and a place without either falls back to a scene")


func test_same_every_time() -> void:
	var d := GameDynasty.new_game(5, "Ann", "mage", "faetouched", "elf")
	var before := d.rng.state
	var a := SceneryArt.paint("whisperwood", "rain", "autumn")
	ok(_same(a, SceneryArt.paint("whisperwood", "rain", "autumn")), "a scene is painted the same every time")
	SceneryArt.reset()
	ok(SceneryArt.for_world(d.world) != null and d.rng.state == before, "and drawing one rolls none of the dynasty's dice")
	var sz := SceneryArt.canvas_size()
	ok(a.get_width() == sz.x and a.get_height() == sz.y, "it is painted at the scenery's own size")
	ok(not _same(SceneryArt.paint("hearthmere", "clear", "summer"), SceneryArt.paint("kingshold", "clear", "summer")), "two places on the same land look different")


func test_weather_and_seasons() -> void:
	var clear := SceneryArt.paint("hearthmere", "clear", "summer")
	for w in GameData.world["weather"]:
		if str(w["id"]) != "clear":
			ok(not _same(clear, SceneryArt.paint("hearthmere", str(w["id"]), "summer")), "%s weather changes the scene out of doors" % w["id"])
	ok(not _same(clear, SceneryArt.paint("hearthmere", "clear", "autumn")), "so does autumn")
	ok(not _same(clear, SceneryArt.paint("hearthmere", "clear", "winter")), "and winter")
	ok(_same(SceneryArt.paint("goblin_warrens", "clear", "summer"), SceneryArt.paint("goblin_warrens", "storm", "winter")), "but neither reaches under the ground")


func test_kept_and_whole_pixels() -> void:
	SceneryArt.reset()
	var a := SceneryArt.texture("mirefen", "fog", "spring")
	ok(a != null and a == SceneryArt.texture("mirefen", "fog", "spring"), "a scene is made once and kept")
	var sz := SceneryArt.canvas_size()
	ok(a != null and a.get_width() == sz.x * SceneryArt.UPSCALE and a.get_height() == sz.y * SceneryArt.UPSCALE, "scaled up by whole pixels")
	for p in ["hearthmere", "greenvale", "whisperwood", "highcrag"]:
		SceneryArt.texture(p, "clear", "summer")
	ok(SceneryArt.texture("mirefen", "fog", "spring") != a, "only the last few scenes are kept")


func test_cover() -> void:
	var r := SceneryArt.cover(Vector2(384, 120), Vector2(1200, 400))
	ok(r.size.x >= 1199.9 and r.size.y >= 399.9 and r.position.y == 0.0, "a scene covers its box from the top: %s" % str(r))
	ok(is_equal_approx(r.position.x, (1200.0 - r.size.x) * 0.5), "centred across it")
	var short := SceneryArt.cover(Vector2(384, 120), Vector2(1600, 300))
	ok(is_equal_approx(short.size.x, 1600.0) and short.position.y == 0.0 and short.size.y >= 299.9, "a short box loses the near ground, not the sky: %s" % str(short))


# ---------------------------------------------------------------- the battle screen

func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


func _plates(n: Node) -> int:
	return n.get_children().filter(func(c): return c is Panel and c.has_meta("plate")).size()


func _fight(place: String, weather: String) -> Control:
	var d: GameDynasty = app.dynasty
	d.world.location = place
	d.world.weather_id = weather
	var foes: Array = [d._make_enemy(GameCombat.creature_def("wolf"), 1.0, 1.0, 10), d._make_enemy(GameCombat.creature_def("slime"), 1.0, 1.0, 10)]
	d._begin_battle(foes, "hunt")
	d.auto_battle = false
	app.show_state()
	return app.current


func test_battle_screen() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	GameDynasty.save_path = DIR + "save.json"
	UiSettings.path = DIR + "settings.cfg"
	UiSettings.scale = 1.0
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	TouchHint.finger = false
	UiSettings.set_access("high_contrast", false)
	root.size = Vector2i(1280, 720)
	await _frames(2)
	app = GameApp.new()
	root.add_child(app)
	await _frames(2)
	app.new_game("Tess", "warrior", "faetouched", 77, "human")
	var d: GameDynasty = app.dynasty
	d.pending_event = {}
	for id in TRIO:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": 30, "gen": 1,
			"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
		d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
			"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	d.party.rest(d)
	var bv := _fight("emberpeak", "heat")
	await _frames(5)
	ok(bv.scenery != null and bv.scenery.texture == SceneryArt.for_world(d.world), "a fight is drawn in the scene of its place")
	ok(bv.arena.get_child(0) == bv.scenery, "behind everything in the arena")
	ok(bv.scenery.size.x >= bv.arena.size.x - 0.5 and bv.scenery.size.y >= bv.arena.size.y - 0.5 and bv.scenery.position.y == 0.0, "covering it from the top")
	var veil = bv.arena.get_child(1)
	ok(veil is ColorRect and is_equal_approx((veil as ColorRect).color.a, SceneryArt.veil(false)), "under a veil")
	ok(_plates(bv.hero_node) == 1 and _plates(bv.ally_nodes[0]["root"]) == 1 and _plates(bv.enemy_nodes[0]["root"]) == 1, "the names sit on plates")
	ok(bv.hero_node.get_child(0) is ColorRect, "and the hero's body is still the first thing in the hero")
	var tex: Texture2D = bv.scenery.texture
	UiSettings.set_access("high_contrast", true)
	bv = _fight("the_rift", "clear")
	await _frames(5)
	veil = bv.arena.get_child(1)
	ok(bv.scenery.texture != tex, "another place, another scene")
	ok(veil is ColorRect and is_equal_approx((veil as ColorRect).color.a, SceneryArt.veil(true)) and SceneryArt.veil(true) > SceneryArt.veil(false), "a thicker veil with high contrast on")
	UiSettings.set_access("high_contrast", false)
