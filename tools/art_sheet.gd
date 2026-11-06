## A contact sheet of the battle art, drawn by the game's own SpriteArt on the game's background, for looking
## at the sprites together: every creature (in creatures.json order), or every race (rows) by class (columns).
## It first prints any problems SpriteArt.validate() finds. Runs headless: images only, no screen.
## godot --headless --path . -s res://tools/art_sheet.gd -- out=/abs/path/sheet.png [what=creatures|heroes]
extends SceneTree

const SpriteArt := preload("res://ui/play/sprite_art.gd")
const BG := Color("#14121c")
const CELL := Color("#221f30")
const PAD := 8


func _init() -> void:
	GameData.load_all()
	var problems := SpriteArt.validate()
	for p in problems:
		print("art problem: ", p)
	var what := _arg("what", "creatures")
	var out := _arg("out", "art_sheet.png")
	var tiles: Array = []
	var cols := 8
	if what == "heroes":
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


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(name + "="):
			return a.substr(name.length() + 1)
	return fallback
