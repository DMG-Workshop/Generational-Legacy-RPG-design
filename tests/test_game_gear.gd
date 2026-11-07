## Gear on figures (ui/play/sprite_art.gd, data/art/gear.json): the gear data is sound and every weapon and
## armour has a look; the armour's finish goes on the figure's metal and leather outside the weapon's box and
## the weapon's finish on the blade or the wood inside it, each only where it belongs; some armour adds a cape
## behind the figure and a magic weapon a glow; nothing changes without gear or for an item without a look;
## figures are kept per gear; and the heir is drawn in what they wear, on the battle screen too.
## Run: godot --headless --path . -s res://tests/test_game_gear.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const TouchHint := preload("res://ui/play/touch_hint.gd")
const SpriteArt := preload("res://ui/play/sprite_art.gd")
const DIR := "user://test_gear/"
const RED := Color("#c0504d")

var fails := 0
var checks := 0
var gear: Dictionary = {}
var warrior: Dictionary = {}


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	gear = _json("res://data/art/gear.json")
	warrior = _json("res://data/art/classes.json")["sprites"]["warrior"]
	test_data()
	test_finishes()
	test_cape_and_glow()
	test_kept_per_gear()
	await test_heir_wears_their_gear()
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
	print("gear tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _json(path: String) -> Dictionary:
	var v = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if typeof(v) == TYPE_DICTIONARY else {}


## The colour of art pixel (x, y) of a figure.
func _px(tex: Texture2D, x: int, y: int) -> Color:
	return tex.get_image().get_pixel(x * SpriteArt.UPSCALE, y * SpriteArt.UPSCALE)


## The first pixel of the warrior's figure holding `key`, inside its weapon box or outside it.
func _key_at(key: String, inside: bool) -> Vector2i:
	var w: Array = gear["classes"]["warrior"]["weapon"]
	var box := Rect2i(int(w[0]), int(w[1]), int(w[2]) - int(w[0]) + 1, int(w[3]) - int(w[1]) + 1)
	var rows: Array = warrior["rows"]
	for y in rows.size():
		for x in str(rows[y]).length():
			if str(rows[y])[x] == key and box.has_point(Vector2i(x, y)) == inside:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


# ---------------------------------------------------------------- the data

func test_data() -> void:
	var problems := SpriteArt.validate()
	ok(problems.is_empty(), "the art data, gear included, is sound: %s" % str(problems.slice(0, 5)))
	var missing: Array = []
	for id in GameData.items:
		var slot := str(GameData.items[id].get("slot", ""))
		if slot in ["weapon", "armor"] and not gear["items"].has(id):
			missing.append(id)
	ok(missing.is_empty(), "every weapon and armour has a look; missing: %s" % str(missing))
	var notes: Array = GameData.classes.keys().filter(func(c): return not gear["classes"].has(str(c)))
	ok(notes.is_empty(), "every class has a gear note; missing: %s" % str(notes))


# ---------------------------------------------------------------- how gear changes a figure

func test_finishes() -> void:
	var plain := SpriteArt.hero("human", "warrior", RED)
	ok(SpriteArt.hero("human", "warrior", RED, {}) == plain, "a figure without gear is the plain figure")
	var armour_px := _key_at("A", false)
	var blade_px := _key_at("A", true)
	ok(armour_px.x >= 0 and blade_px.x >= 0, "the warrior has metal on its armour and on its sword")
	var dragon := SpriteArt.hero("human", "warrior", RED, {"armor": "dragonscale_mail"})
	var dragon_light := Color(str(gear["metals"]["dragon"][0]))
	ok(_px(dragon, armour_px.x, armour_px.y).is_equal_approx(dragon_light), "dragonscale turns the armour's metal dragon-red")
	ok(_px(dragon, blade_px.x, blade_px.y).is_equal_approx(_px(plain, blade_px.x, blade_px.y)), "but not the sword")
	var sun := SpriteArt.hero("human", "warrior", RED, {"weapon": "sunblade"})
	ok(_px(sun, blade_px.x, blade_px.y).is_equal_approx(Color(str(gear["metals"]["sun"][0]))), "the Sunblade's blade is sun-gold")
	ok(_px(sun, armour_px.x, armour_px.y).is_equal_approx(_px(plain, armour_px.x, armour_px.y)), "and the armour stays as it was")
	var leather_px := _key_at("L", false)
	var scout := SpriteArt.hero("human", "warrior", RED, {"armor": "scout_leathers"})
	ok(leather_px.x >= 0 and _px(scout, leather_px.x, leather_px.y).is_equal_approx(Color(str(gear["leathers"]["green"][0]))), "scout leathers dye the leather green")
	var staff_px := Vector2i(-1, -1)
	var mage: Dictionary = _json("res://data/art/classes.json")["sprites"]["mage"]
	for y in mage["rows"].size():
		var x := str(mage["rows"][y]).find("L")
		if x >= 0:
			staff_px = Vector2i(x, y)
			break
	var archmage := SpriteArt.hero("human", "mage", RED, {"weapon": "archmage_staff"})
	ok(staff_px.x >= 0 and _px(archmage, staff_px.x, staff_px.y).is_equal_approx(Color(str(gear["woods"]["pale"][0]))), "the archmage's staff is pale wood")
	ok(SpriteArt.hero("human", "warrior", RED, {"armor": "padded_robe"}) != null, "an armour with no finish draws the figure as it is")
	var robe_img := SpriteArt.hero("human", "warrior", RED, {"armor": "padded_robe"}).get_image()
	ok(robe_img.get_data() == plain.get_image().get_data(), "and changes nothing on it")


func test_cape_and_glow() -> void:
	var plain := SpriteArt.hero("human", "warrior", RED)
	var plate := SpriteArt.hero("human", "warrior", RED, {"armor": "plate_armor"})
	var behind := 0
	var pi := plain.get_image()
	var qi := plate.get_image()
	for y in range(17, 37):
		for x in range(0, 8):
			if pi.get_pixel(x * SpriteArt.UPSCALE, y * SpriteArt.UPSCALE).a == 0.0 and qi.get_pixel(x * SpriteArt.UPSCALE, y * SpriteArt.UPSCALE).a > 0.0:
				behind += 1
	ok(behind >= 8, "plate armour hangs a cape behind the figure: %d pixels show at its back" % behind)
	var no_cape := SpriteArt.hero("human", "warrior", RED, {"armor": "chainmail"}).get_image()
	var none := 0
	for y in range(17, 37):
		for x in range(0, 8):
			if pi.get_pixel(x * SpriteArt.UPSCALE, y * SpriteArt.UPSCALE).a == 0.0 and no_cape.get_pixel(x * SpriteArt.UPSCALE, y * SpriteArt.UPSCALE).a > 0.0:
				none += 1
	ok(none == 0, "chainmail has none")
	ok(_glowing(SpriteArt.hero("human", "warrior", RED, {"weapon": "sunblade"})) > 0, "a magic weapon glows")
	ok(_glowing(SpriteArt.hero("human", "warrior", RED, {"weapon": "steel_sword"})) == 0, "a plain one does not")


## Pixels of the see-through glow around the warrior's weapon box.
func _glowing(tex: Texture2D) -> int:
	var img := tex.get_image()
	var n := 0
	for y in img.get_height() / SpriteArt.UPSCALE:
		for x in img.get_width() / SpriteArt.UPSCALE:
			var a := img.get_pixel(x * SpriteArt.UPSCALE, y * SpriteArt.UPSCALE).a
			if a > 0.0 and a < 1.0:
				n += 1
	return n


func test_kept_per_gear() -> void:
	var a := SpriteArt.hero("elf", "ranger", RED, {"weapon": "elven_bow", "armor": "scout_leathers"})
	ok(a == SpriteArt.hero("elf", "ranger", RED, {"weapon": "elven_bow", "armor": "scout_leathers"}), "a dressed figure is made once and kept")
	ok(a != SpriteArt.hero("elf", "ranger", RED, {"weapon": "longbow", "armor": "scout_leathers"}), "and another weapon makes another")


# ---------------------------------------------------------------- the heir

func test_heir_wears_their_gear() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	GameDynasty.save_path = DIR + "save.json"
	UiSettings.path = DIR + "settings.cfg"
	UiSettings.scale = 1.0
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	TouchHint.finger = false
	root.size = Vector2i(1280, 720)
	var app: Node = GameApp.new()
	root.add_child(app)
	for i in 2:
		await process_frame
	app.new_game("Tess", "warrior", "faetouched", 77, "human")
	var d: GameDynasty = app.dynasty
	d.pending_event = {}
	var bare := SpriteArt.figure(d.heir)
	d.heir.equipment["weapon"] = "sunblade"
	d.heir.equipment["armor"] = "dragonscale_mail"
	d.heir.equipment["trinket"] = "lucky_charm"
	ok(SpriteArt.gear_of(d.heir) == {"weapon": "sunblade", "armor": "dragonscale_mail"}, "the heir shows their weapon and armour, not their trinket")
	var dressed := SpriteArt.figure(d.heir)
	ok(dressed != bare and dressed == SpriteArt.hero("human", "warrior", SpriteArt.shirt_color(d.heir), {"weapon": "sunblade", "armor": "dragonscale_mail"}), "and is drawn in them")
	d.heir.equipment["weapon"] = "no_such_item"
	ok(SpriteArt.gear_of(d.heir) == {"armor": "dragonscale_mail"}, "an item without a look is not shown")
	d.heir.equipment["weapon"] = "sunblade"
	d._begin_battle([d._make_enemy(GameCombat.creature_def("wolf"), 1.0, 1.0, 10)], "hunt")
	d.auto_battle = false
	app.show_state()
	for i in 5:
		await process_frame
	var bv: Control = app.current
	var shown: TextureRect = null
	for c in bv.hero_node.get_child(0).get_children():
		if c is TextureRect:
			shown = c
		elif not (c is ColorRect):
			for g in c.get_children():
				if g is TextureRect:
					shown = g
	ok(shown != null and shown.texture == dressed, "the battle screen draws the heir in their gear")
	app.queue_free()
	for i in 2:
		await process_frame
