## A contact sheet of the battle art, drawn by the game's own SpriteArt on the game's background, for looking
## at the sprites together: every creature (in creatures.json order), or every race (rows) by class (columns).
## what=scenery draws every place's battle scenery (in a weather and season, clear summer by default), or with
## place=<id> that place in every weather and then every season; scale=<n> enlarges each scene.
## It first prints any problems SpriteArt.validate() and SceneryArt.validate() find. Runs headless: images
## only, no screen.
## godot --headless --path . -s res://tools/art_sheet.gd -- out=/abs/path/sheet.png [what=creatures|heroes|scenery]
extends SceneTree

const SpriteArt := preload("res://ui/play/sprite_art.gd")
const SceneryArt := preload("res://ui/play/scenery_art.gd")
const BG := Color("#14121c")
const CELL := Color("#221f30")
const PAD := 8


func _init() -> void:
	GameData.load_all()
	var problems := SpriteArt.validate()
	problems.append_array(SceneryArt.validate())
	for p in problems:
		print("art problem: ", p)
	var what := _arg("what", "creatures")
	var out := _arg("out", "art_sheet.png")
	var tiles: Array = []
	var cols := 8
	if what == "scenery":
		var place := _arg("place", "")
		var names: Array = []
		if place == "":
			cols = 3
			for l in GameData.world["locations"]:
				tiles.append(_scene(str(l["id"]), _arg("weather", "clear"), _arg("season", "summer")))
				names.append("%s (%s)" % [l["id"], SceneryArt.scene_id(str(l["id"]))])
		else:
			cols = 4
			for w in GameData.world["weather"]:
				tiles.append(_scene(place, str(w["id"]), "summer"))
				names.append(str(w["id"]))
			for s in GameData.world["seasons"]:
				tiles.append(_scene(place, "clear", str(s["id"])))
				names.append(str(s["id"]))
		print("in order: %s" % ", ".join(names))
	elif what == "heroes":
		var classes: Array = GameData.classes.keys()
		cols = classes.size()
		for r in GameData.races:
			for c in classes:
				tiles.append(SpriteArt.hero(str(r), str(c), Color(GameData.classes[c]["color"])))
		print("rows: %s\ncolumns: %s" % [", ".join(GameData.races.keys()), ", ".join(classes)])
	else:
		for c in GameData.creatures:
			tiles.append(SpriteArt.creature(str(c["id"])))
		print("in order: %s" % ", ".join(GameData.creatures.map(func(c): return str(c["id"]))))
	var cw := 0
	var ch := 0
	for t in tiles:
		if t != null:
			cw = maxi(cw, (t as Texture2D).get_width())
			ch = maxi(ch, (t as Texture2D).get_height())
	cw += PAD * 2
	ch += PAD * 2
	var rows := ceili(float(tiles.size()) / float(cols))
	var sheet := Image.create_empty(cols * cw + PAD, rows * ch + PAD, false, Image.FORMAT_RGBA8)
	sheet.fill(BG)
	for n in tiles.size():
		var x := PAD + (n % cols) * cw
		var y := PAD + (n / cols) * ch
		sheet.fill_rect(Rect2i(x, y, cw - PAD, ch - PAD), CELL)
		var t: Texture2D = tiles[n]
		if t == null:
			continue
		var img := t.get_image()
		img.convert(Image.FORMAT_RGBA8)
		var at := Vector2i(x + (cw - PAD - img.get_width()) / 2, y + ch - PAD - img.get_height() - PAD / 2)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	sheet.save_png(out)
	print("saved %s (%d tiles, %d problems)" % [out, tiles.size(), problems.size()])
	quit(1 if not problems.is_empty() else 0)


## A place's scene as a texture, enlarged by whole pixels.
func _scene(place: String, weather: String, season: String) -> Texture2D:
	var img := SceneryArt.paint(place, weather, season)
	var k := maxi(1, int(_arg("scale", "1")))
	img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(name + "="):
			return a.substr(name.length() + 1)
	return fallback
