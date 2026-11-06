## Battle sprites (ui/play/sprite_art.gd): the art in data/art/ is sound, every creature, class and race has
## art, a figure takes its race's skin and hair and its class's colour, textures are kept and scaled by whole
## pixels, sprites stand on the bottom of their box, and the battle screen draws the hero, the companions and
## the foes from them, keeping the old blocks for anything without art.
## Run: godot --headless --path . -s res://tests/test_game_art.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const TouchHint := preload("res://ui/play/touch_hint.gd")
const SpriteArt := preload("res://ui/play/sprite_art.gd")
const TRIO := ["sister_oriel", "bren_cask", "tarsk_ember_eye"]
const DIR := "user://test_art/"

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
	test_everyone_has_art()
	test_race_and_class_colours()
	test_kept_and_whole_pixels()
	test_fit_stands_on_the_bottom()
	await test_battle_screen()
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
	print("art tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- the data

func test_data_is_sound() -> void:
	var problems := SpriteArt.validate()
	ok(problems.is_empty(), "the art data is sound: %s" % str(problems.slice(0, 5)))


func test_everyone_has_art() -> void:
	var missing: Array = []
	for c in GameData.creatures:
		if not SpriteArt.has_creature(str(c["id"])):
			missing.append("creature " + str(c["id"]))
	for id in GameData.classes:
		if not SpriteArt.has_class(str(id)):
			missing.append("class " + str(id))
	for id in GameData.races:
		if not SpriteArt.has_race(str(id)):
			missing.append("race " + str(id))
	ok(missing.is_empty(), "every creature, class and race has art; missing: %s" % str(missing))


## A pixel the class figure leaves to the race (S) or the class (C), where no race layer covers it, comes out in
## that race's skin or that class's colour.
func test_race_and_class_colours() -> void:
	var classes: Dictionary = _json("res://data/art/classes.json").get("sprites", {})
	var races: Dictionary = _json("res://data/art/races.json").get("races", {})
	if not classes.has("warrior") or races.is_empty():
		ok(false, "the warrior figure and the races are there to test against")
		return
	var rows: Array = classes["warrior"]["rows"]
	for race_id in ["human", "orc", "elf", "dragonborn"]:
		if not races.has(race_id):
			ok(false, "race %s has art" % race_id)
			continue
		var r: Dictionary = races[race_id]
		var tex := SpriteArt.hero(race_id, "warrior", Color("#c0504d"))
		var img := tex.get_image()
		var skin := _free_pixel(rows, r, "S")
		var cloth := _free_pixel(rows, r, "C")
		ok(skin.x >= 0 and img.get_pixel(skin.x * SpriteArt.UPSCALE, skin.y * SpriteArt.UPSCALE).is_equal_approx(Color.html(str(r["skin"]))), "a %s warrior's skin is the %s skin colour" % [race_id, race_id])
		ok(cloth.x >= 0 and img.get_pixel(cloth.x * SpriteArt.UPSCALE, cloth.y * SpriteArt.UPSCALE).is_equal_approx(Color("#c0504d")), "and the garment is the warrior's red")


## The first pixel holding `key` in the class rows that the race's over layer leaves clear.
func _free_pixel(rows: Array, race: Dictionary, key: String) -> Vector2i:
	var over: Array = race.get("over", [])
	for y in rows.size():
		var line := str(rows[y])
		for x in line.length():
			if line[x] != key:
				continue
			if y < over.size() and str(over[y])[x] != ".":
				continue
			return Vector2i(x, y)
	return Vector2i(-1, -1)


func test_kept_and_whole_pixels() -> void:
	var a := SpriteArt.hero("human", "warrior", Color("#c0504d"))
	var b := SpriteArt.hero("human", "warrior", Color("#c0504d"))
	ok(a != null and a == b, "a figure is drawn once and kept")
	if a != null:
		ok(a.get_width() == SpriteArt.FIGURE.x * SpriteArt.UPSCALE and a.get_height() == SpriteArt.FIGURE.y * SpriteArt.UPSCALE, "a figure is scaled up by whole pixels")
	var wolf := SpriteArt.creature("wolf")
	var size: Array = _json("res://data/art/creatures.json").get("sprites", {}).get("wolf", {}).get("size", [0, 0])
	ok(wolf != null and wolf.get_width() == int(size[0]) * SpriteArt.UPSCALE and wolf.get_height() == int(size[1]) * SpriteArt.UPSCALE, "and so is a creature")
	ok(SpriteArt.creature("no_such_beast") == null and SpriteArt.hero("human", "no_such_class", Color.WHITE) == null, "nothing is made for art that does not exist")


func test_fit_stands_on_the_bottom() -> void:
	var tall := SpriteArt.fit(Vector2(10, 20), Vector2(100, 100))
	ok(tall.size == Vector2(50, 100) and tall.position == Vector2(25, 0), "a tall sprite fills the height, centred: %s" % str(tall))
	var wide := SpriteArt.fit(Vector2(40, 20), Vector2(100, 100))
	ok(wide.size == Vector2(100, 50) and wide.position == Vector2(0, 50), "a wide sprite stands on the bottom of its box: %s" % str(wide))


# ---------------------------------------------------------------- the battle screen

func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


func _has_sprite(n: Node) -> bool:
	for c in n.get_children():
		if c is TextureRect and (c as TextureRect).texture != null:
			return true
	return false


func _eyes(n: Node) -> int:
	return n.get_children().filter(func(c): return c is ColorRect).size()


func test_battle_screen() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	GameDynasty.save_path = DIR + "save.json"
	UiSettings.path = DIR + "settings.cfg"
	UiSettings.scale = 1.0
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	TouchHint.finger = false
	root.size = Vector2i(1280, 720)
	await _frames(2)
	app = GameApp.new()
	root.add_child(app)
	await _frames(2)
	app.new_game("Tess", "warrior", "faetouched", 77, "human")
	var d: GameDynasty = app.dynasty
	d.pending_event = {}
	d.world.visit("kingshold")
	for id in TRIO:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": 30, "gen": 1,
			"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
		d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
			"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	d.party.rest(d)
	var foes: Array = [d._make_enemy(GameCombat.creature_def("wolf"), 1.0, 1.0, 10), d._make_enemy(GameCombat.creature_def("slime"), 1.0, 1.0, 10)]
	var unknown: Dictionary = GameCombat.creature_def("goblin").duplicate(true)
	unknown["id"] = "no_such_beast"
	foes.append(d._make_enemy(unknown, 1.0, 1.0, 10))
	d._begin_battle(foes, "hunt")
	d.auto_battle = false
	app.show_state()
	await _frames(5)
	var bv: Control = app.current
	ok(_has_sprite(bv.hero_node.get_child(0)), "the hero is drawn from a sprite")
	for i in bv.ally_nodes.size():
		ok(_has_sprite(bv.ally_nodes[i]["body"]), "companion %d is drawn from a sprite" % i)
	for i in 2:
		var body: Control = bv.enemy_nodes[i]["body"]
		ok(_has_sprite(body) and _eyes(body) == 0, "foe %d is drawn from a sprite, without block eyes" % i)
		ok((body as ColorRect).color.a == 0.0, "and its body under the sprite is clear")
	var odd: ColorRect = bv.enemy_nodes[2]["body"]
	ok(not _has_sprite(odd) and _eyes(odd) == 2 and odd.color == Color(unknown["color"]), "a creature without art keeps the old block and its eyes")


func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if typeof(v) == TYPE_DICTIONARY else {}
