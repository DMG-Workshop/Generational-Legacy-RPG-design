## The art style (data/art/style.json, SpriteArt.style_problems) and the texture atlas (ui/play/texture_atlas.gd).
## Every class figure and creature keeps to the style numbers (size, an outline in the outline colour, no stray
## pixels, a cap on colours, clear margins, standing on the ground); each rule is shown to catch what it is for on
## sprites made here. The atlas packs images without overlap and with clear padding, keeps their pixels exactly,
## gives an oversized image a texture of its own, uploads once for a batch, and the sprites the game draws share
## a few pages.
## Run: godot --headless --path . -s res://tests/test_game_art_style.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const SpriteArt := preload("res://ui/play/sprite_art.gd")
const DIR := "user://test_art_style/"
const OUT := Color("#1b1626")

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
	test_style_numbers()
	test_real_art()
	test_rules_catch()
	test_atlas_packing()
	test_atlas_edges()
	test_atlas_batch()
	test_sprites_share_pages()
	await test_battle_uploads_once()
	print("%d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- the numbers

func test_style_numbers() -> void:
	SpriteArt.reset()
	var st := SpriteArt.style()
	ok(not st.is_empty(), "the style numbers load")
	ok(Color.html_is_valid(str(st["outline"])) and Color.html_is_valid(str(st["background"])), "the outline and background are colours")
	ok(int(st["colors_target"]) <= int(st["colors_max"]), "the colour target is within the cap")
	ok(st["figure"]["size"] == [24, 40] or (int(st["figure"]["size"][0]) == SpriteArt.FIGURE.x and int(st["figure"]["size"][1]) == SpriteArt.FIGURE.y), "the figure size is the code's")
	ok(int(st["creature"]["max_size"][0]) <= int(st["boss"]["max_size"][0]), "a boss may be bigger than a creature")
	ok(int(st["atlas"]["page"]) >= 256 and int(st["atlas"]["padding"]) >= 1, "the atlas has a page size and padding")
	ok(str(st["outline"]).to_lower() == "#1b1626", "the outline colour is the one docs/ART.md names")


# ---------------------------------------------------------------- the art as it is

func test_real_art() -> void:
	var found := SpriteArt.style_problems()
	ok(found.is_empty(), "every class figure and creature keeps to the style" + ("" if found.is_empty() else ": " + str(found.slice(0, 4))))
	var all := SpriteArt.validate()
	ok(all.is_empty(), "and the art data as a whole is sound" + ("" if all.is_empty() else ": " + str(all.slice(0, 3))))
	# the style check is part of validate, which tools/check_data.gd runs
	SpriteArt.reset()
	SpriteArt._load()
	var row: String = SpriteArt._classes["warrior"]["rows"][20]
	var rows: Array = SpriteArt._classes["warrior"]["rows"]
	rows[20] = row.substr(0, 1) + "k" + row.substr(2) if row[1] == "." else row
	# a stray pixel far from the body, in the headroom
	rows[1] = "." + "k" + ".".repeat(22)
	var broken := SpriteArt.validate()
	ok(broken.any(func(p): return "stray" in p and "warrior" in p), "a stray pixel put into a class figure is reported by validate")
	SpriteArt.reset()


# ---------------------------------------------------------------- the rules catch what they are for

## A filled box with a one-pixel outline, in a canvas, in two body colours. `box` is x0, y0 then x1, y1 (end not
## included) in a Rect2i's four numbers.
func _blob(canvas: Vector2i, box: Rect2i, extra_colors: int = 0) -> Image:
	var img := Image.create_empty(canvas.x, canvas.y, false, Image.FORMAT_RGBA8)
	var x0 := box.position.x
	var y0 := box.position.y
	var x1 := box.size.x
	var y1 := box.size.y
	for y in range(y0, y1):
		for x in range(x0, x1):
			var edge := x == x0 or y == y0 or x == x1 - 1 or y == y1 - 1
			img.set_pixel(x, y, OUT if edge else (Color("#6abf4b") if (x + y) % 2 == 0 else Color("#3f8f3c")))
	for i in extra_colors:   # more colours inside the body
		img.set_pixel(x0 + 2 + i, y0 + 2, Color(0.1 + 0.05 * i, 0.2, 0.9))
	return img


func _flagged(img: Image, kind: String, needle: String) -> bool:
	return SpriteArt.check_sprite("t", img, kind).any(func(p): return needle in p)


func test_rules_catch() -> void:
	SpriteArt.reset()
	SpriteArt._load()
	var good := _blob(Vector2i(32, 32), Rect2i(4, 6, 22, 32))   # standing on the bottom row
	ok(SpriteArt.check_sprite("good", good, "creature").is_empty(), "a clean creature passes: " + str(SpriteArt.check_sprite("good", good, "creature")))
	# an outlined figure of the right size standing on the bottom
	var fig := _blob(Vector2i(24, 40), Rect2i(4, 4, 16, 40))
	ok(SpriteArt.check_sprite("fig", fig, "figure").is_empty(), "a clean figure passes: " + str(SpriteArt.check_sprite("fig", fig, "figure")))
	var stray := good.duplicate() as Image
	stray.set_pixel(1, 1, Color("#ff00ff"))
	ok(_flagged(stray, "creature", "stray"), "a stray single pixel is caught")
	var plain := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	for y in range(6, 32):
		for x in range(4, 22):
			plain.set_pixel(x, y, Color("#6abf4b"))
	ok(_flagged(plain, "creature", "outlined"), "a silhouette with no outline is caught")
	ok(_flagged(_blob(Vector2i(32, 32), Rect2i(4, 6, 22, 32), 14), "creature", "colours"), "too many colours are caught")
	ok(not _flagged(_blob(Vector2i(32, 32), Rect2i(4, 6, 22, 32), 8), "creature", "colours"), "a few extra colours are fine")
	ok(_flagged(_blob(Vector2i(32, 32), Rect2i(0, 6, 22, 32)), "creature", "left edge"), "touching the left edge is caught")
	ok(_flagged(_blob(Vector2i(32, 32), Rect2i(4, 0, 22, 32)), "creature", "top edge"), "touching the top edge is caught")
	ok(_flagged(_blob(Vector2i(32, 32), Rect2i(4, 6, 32, 32)), "creature", "right edge"), "touching the right edge is caught")
	ok(not _flagged(_blob(Vector2i(32, 32), Rect2i(4, 6, 22, 32)), "creature", "edge"), "standing on the bottom row is allowed")
	ok(_flagged(_blob(Vector2i(32, 32), Rect2i(4, 2, 22, 16)), "creature", "floats"), "floating well above the ground is caught")
	ok(_flagged(_blob(Vector2i(24, 40), Rect2i(4, 4, 16, 34)), "figure", "floats"), "a figure must stand on its bottom row")
	ok(_flagged(_blob(Vector2i(24, 40), Rect2i(0, 4, 16, 40)), "figure", "left edge"), "a figure keeps its left margin")
	ok(not _flagged(_blob(Vector2i(24, 40), Rect2i(4, 4, 24, 40)), "figure", "right edge"), "but a weapon may reach a figure's right edge")
	ok(_flagged(_blob(Vector2i(20, 40), Rect2i(4, 4, 16, 40)), "figure", "must be 24x40"), "a figure must be 24x40")
	ok(_flagged(_blob(Vector2i(44, 30), Rect2i(4, 4, 30, 30)), "creature", "at most 40x40"), "a creature may not be bigger than 40x40")
	ok(not _flagged(_blob(Vector2i(64, 64), Rect2i(4, 4, 56, 64)), "boss", "at most"), "a boss may be 64x64")
	ok(_flagged(_blob(Vector2i(66, 64), Rect2i(4, 4, 56, 64)), "boss", "at most 64x64"), "but not bigger")
	ok(_flagged(Image.create_empty(8, 8, false, Image.FORMAT_RGBA8), "creature", "nothing is drawn"), "an empty sprite is caught")
	ok(SpriteArt.check_sprite("x", good, "dragon")[0].contains("no rules"), "a kind with no rules is reported")


# ---------------------------------------------------------------- the atlas

func _solid(w: int, h: int, c: Color) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return img


func test_atlas_packing() -> void:
	var a := TextureAtlas.new(256, 2)
	var rng := RandomNumberGenerator.new()   # a test's own dice
	rng.seed = 77
	var made: Array = []
	for i in 120:
		var w := rng.randi_range(8, 70)
		var h := rng.randi_range(8, 70)
		var c := Color.from_hsv(float(i) / 120.0, 0.8, 0.9)
		var src := _solid(w, h, c)
		made.append([a.add(src), w, h, src.get_pixel(0, 0)])   # the colour as the image holds it, in 8 bits
	var st := a.stats()
	ok(st["images"] == 120 and st["loners"] == 0 and st["pages"] >= 2, "120 images need a few pages (%d)" % st["pages"])
	ok(float(st["used"]) / float(st["capacity"]) > 0.55, "and fill them well (%.0f%%)" % (100.0 * float(st["used"]) / float(st["capacity"])))
	var bad := 0
	var rects: Array = []
	for m in made:
		var t: AtlasTexture = m[0]
		var r := t.region
		var page: Image = t.atlas.get_image()
		if not (r.size.x == m[1] and r.size.y == m[2]) or r.position.x < 2 or r.position.y < 2 or r.end.x + 2 > 256 or r.end.y + 2 > 256:
			bad += 1
			continue
		var got := t.get_image()
		if got.get_width() != m[1] or got.get_pixel(0, 0) != m[3] or got.get_pixel(m[1] - 1, m[2] - 1) != m[3]:
			bad += 1
		# the padding around it is clear
		for x in range(int(r.position.x) - 2, int(r.end.x) + 2):
			for y in [int(r.position.y) - 1, int(r.end.y)]:
				if page.get_pixel(x, y).a > 0.0:
					bad += 1
		rects.append([t.atlas, Rect2(r.position - Vector2(2, 2), r.size + Vector2(4, 4))])
	ok(bad == 0, "every image is where it says, intact, with clear padding around it (%d wrong)" % bad)
	var overlaps := 0
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i][0] == rects[j][0] and (rects[i][1] as Rect2).intersects(rects[j][1]):
				overlaps += 1
	ok(overlaps == 0, "no two images, padding included, overlap (%d)" % overlaps)
	ok(made.all(func(m): return (m[0] as AtlasTexture).filter_clip), "regions clip their filtering to themselves")
	var sizes_ok := a.pages.all(func(p): return (p["image"] as Image).get_width() == 256 and (p["image"] as Image).get_height() == 256)
	ok(sizes_ok, "every page is the page size")


func test_atlas_edges() -> void:
	# 4 cells fit a 64 page with no padding; the fifth starts a page
	var a := TextureAtlas.new(64, 0)
	for i in 4:
		a.add(_solid(32, 32, Color.RED))
	ok(a.stats()["pages"] == 1, "four 32x32 images fill one 64x64 page")
	a.add(_solid(32, 32, Color.BLUE))
	ok(a.stats()["pages"] == 2, "the fifth starts another")
	# one that exactly fills a page, one too big
	var b := TextureAtlas.new(64, 2)
	var fits := b.add(_solid(60, 60, Color.GREEN))
	ok(fits is AtlasTexture and b.stats()["loners"] == 0, "an image that fits a page with its padding is packed")
	var big := b.add(_solid(61, 20, Color.GREEN))
	ok(big is ImageTexture and b.stats()["loners"] == 1, "one that does not fit a page gets a texture of its own")
	ok(big.get_width() == 61 and big.get_image().get_pixel(60, 19) == Color.GREEN, "and keeps its pixels")
	# a short image goes on an existing shelf; a taller one starts a shelf of its own
	var c := TextureAtlas.new(128, 0)
	c.add(_solid(40, 40, Color.RED))
	c.add(_solid(40, 20, Color.BLUE))
	ok(c.stats()["pages"] == 1 and c.pages[0]["shelves"].size() == 1, "images up to the shelf's height share the shelf")
	c.add(_solid(40, 60, Color.GREEN))
	ok(c.pages[0]["shelves"].size() == 2, "a taller one starts the next shelf")
	c.add(_solid(60, 20, Color.YELLOW))   # does not fit the first shelf's last 48, fits the second's 88
	c.add(_solid(20, 20, Color.WHITE))
	ok(c.pages[0]["shelves"].size() == 2 and c.stats()["pages"] == 1, "later images go back to a shelf with room")


func test_atlas_batch() -> void:
	var a := TextureAtlas.new(128, 1)
	var t := a.add(_solid(10, 10, Color.RED))
	ok(a.uploads == 1 and t.get_image().get_pixel(0, 0) == Color.RED, "an add uploads its page and can be read at once")
	a.begin_batch()
	var u := a.add(_solid(10, 10, Color.BLUE))
	var v := a.add(_solid(10, 10, Color.GREEN))
	ok(a.uploads == 1, "within a batch nothing is uploaded")
	a.begin_batch()   # batches nest
	a.add(_solid(10, 10, Color.WHITE))
	a.end_batch()
	ok(a.uploads == 1, "and an inner end does not upload")
	a.end_batch()
	ok(a.uploads == 2, "the outer end uploads once for all three")
	ok(u.get_image().get_pixel(0, 0) == Color.BLUE and v.get_image().get_pixel(0, 0) == Color.GREEN and t.get_image().get_pixel(0, 0) == Color.RED, "and every image reads right, the earlier one too")
	a.end_batch()   # one too many does nothing
	a.flush()
	ok(a.uploads == 2, "flushing with nothing changed uploads nothing")


# ---------------------------------------------------------------- the game's sprites

func test_sprites_share_pages() -> void:
	SpriteArt.reset()
	SpriteArt._load()
	var first: Texture2D = null
	SpriteArt.begin_batch()
	var count := 0
	var area := 0
	for c in GameData.creatures:
		var t := SpriteArt.creature(str(c["id"]))
		if t != null:
			count += 1
			area += t.get_width() * t.get_height()
			if first == null:
				first = t
	for cls in GameData.classes:
		var t := SpriteArt.hero("human", str(cls), Color("#cc3333"))
		if t != null:
			count += 1
			area += t.get_width() * t.get_height()
	SpriteArt.end_batch()
	var st := SpriteArt.atlas().stats()
	var page: int = int(SpriteArt.style()["atlas"]["page"])
	ok(count >= 40, "the game's creatures and class figures all have art (%d)" % count)
	ok(first is AtlasTexture, "a sprite's texture is a region of an atlas page")
	ok(st["pages"] <= int(ceil(float(area) * 1.4 / float(page * page))) + 1, "%d sprites share %d page%s of %d" % [count, st["pages"], "" if st["pages"] == 1 else "s", page])
	ok(st["uploads"] == st["pages"], "a batch uploads each page once (%d uploads)" % st["uploads"])
	ok(SpriteArt.creature(str(GameData.creatures[0]["id"])) == SpriteArt.creature(str(GameData.creatures[0]["id"])), "asking again gives the same texture")
	var shared := 0
	var wolf := SpriteArt.creature("wolf") as AtlasTexture
	var slime := SpriteArt.creature("slime") as AtlasTexture
	if wolf != null and slime != null and wolf.atlas == slime.atlas:
		shared += 1
	ok(shared == 1, "two creatures are on the same page")
	SpriteArt.reset()


# ---------------------------------------------------------------- a screen

func _frames(n: int) -> void:
	for i in n:
		await process_frame


func test_battle_uploads_once() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	GameDynasty.save_path = DIR + "save.json"
	UiSettings.path = DIR + "settings.cfg"
	UiSettings.scale = 1.0
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	root.size = Vector2i(1280, 720)
	await _frames(2)
	var app := GameApp.new()
	root.add_child(app)
	await _frames(2)
	app.new_game("Tess", "warrior", "faetouched", 77, "human")
	var d: GameDynasty = app.dynasty
	d.pending_event = {}
	for id in ["sister_oriel", "bren_cask"]:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": 30, "gen": 1,
			"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
		d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
			"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	d.party.rest(d)
	SpriteArt.reset()
	var foes: Array = []
	for id in ["wolf", "slime", "goblin"]:
		foes.append(d._make_enemy(GameCombat.creature_def(id), 1.0, 1.0, 10))
	d._begin_battle(foes, "hunt")
	d.auto_battle = false
	app.show_state()
	await _frames(4)
	var st := SpriteArt.atlas().stats()
	ok(st["images"] >= 6, "the battle screen drew its party and foes from the atlas (%d sprites)" % st["images"])
	ok(st["uploads"] <= st["pages"], "and sent each page to the graphics card once, not once per sprite (%d uploads, %d pages)" % [st["uploads"], st["pages"]])
	ok(st["pages"] == 1, "all on one page")
	app.queue_free()
	await _frames(2)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
