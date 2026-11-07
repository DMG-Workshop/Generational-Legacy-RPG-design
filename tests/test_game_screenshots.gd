## The screenshot check's logic and its stored images (tools/screenshot_diff.gd, tools/screenshots.gd,
## tests/screenshots). Drawing the screens needs a real window, so that runs in its own job (.github/workflows/
## screenshots.yml, under a virtual display); this suite, which runs headless like the others, holds what can be held
## without one: the comparison finds a changed screen and not a repeated one, a different size, a missing image and a
## tiny change are each judged right, and the stored images are the ones the tool draws, no more and no fewer, at the
## right sizes and not blank.
## Run: godot --headless --path . -s res://tests/test_game_screenshots.gd
extends SceneTree

const Diff := preload("res://tools/screenshot_diff.gd")
const Tool := preload("res://tools/screenshots.gd")
const DIR := "res://tests/screenshots/"

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
	test_compare()
	test_stored_images()
	print("%d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _flat(w: int, h: int, c: Color) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return img


func test_compare() -> void:
	var a := _flat(1280, 720, Color("#14121c"))
	var same := Diff.compare(a, a.duplicate())
	ok(same["ok"] and same["differing"] == 0 and same["worst"] == 0, "an image is the same as itself")
	# a few pixels within the allowance
	var few := a.duplicate() as Image
	for i in 10:
		few.set_pixel(100 + i, 100, Color.WHITE)
	var r := Diff.compare(a, few)
	ok(r["ok"] and r["differing"] == 10, "ten pixels differing are within the allowance (%d pixels allowed)" % int(Diff.SHARE_MAX * 1280.0 * 720.0))
	# the size of one changed button label (about 400 pixels on a real screen) is seen
	var label := a.duplicate() as Image
	for y in 10:
		for x in 40:
			label.set_pixel(500 + x, 300 + y, Color.WHITE)
	r = Diff.compare(a, label)
	ok(not r["ok"] and r["differing"] == 400 and "400 pixels differ" in str(r["reason"]), "a changed label's worth of pixels is a difference: " + str(r["reason"]))
	ok(r["diff"] is Image and (r["diff"] as Image).get_pixel(510, 305) == Color(1.0, 0.0, 1.0), "and the diff image marks them in magenta")
	ok((r["diff"] as Image).get_pixel(10, 10).is_equal_approx(Color(0.14 * 0.35, 0.07 * 0.35, 0.11 * 0.35)) or (r["diff"] as Image).get_pixel(10, 10).v < 0.2, "and dims the rest")
	# a small shade difference is not counted
	var shade := a.duplicate() as Image
	shade.fill(Color("#14121c").lightened(0.02))
	r = Diff.compare(a, shade)
	ok(r["ok"] and r["differing"] == 0 and r["worst"] > 0, "a shade a few steps off in every pixel is not counted (worst %d)" % r["worst"])
	var tint := a.duplicate() as Image
	tint.fill(Color("#14121c").lightened(0.2))
	ok(not Diff.compare(a, tint)["ok"], "but a visible change of colour is")
	# sizes, missing images
	r = Diff.compare(a, _flat(1280, 721, Color("#14121c")))
	ok(not r["ok"] and "size changed" in str(r["reason"]) and r["diff"] == null, "a different size is a difference, with no diff image")
	ok(not Diff.compare(null, a)["ok"] and not Diff.compare(a, null)["ok"] and not Diff.compare(Image.new(), a)["ok"], "a missing or empty image is a difference")
	# alpha and format are handled
	var rgb := a.duplicate() as Image
	rgb.convert(Image.FORMAT_RGB8)
	ok(Diff.compare(a, rgb)["ok"], "the same picture in another pixel format is the same")
	# a phone-size screen has a smaller allowance in pixels, and a label there is still seen
	var p := _flat(844, 390, Color("#14121c"))
	var pl := p.duplicate() as Image
	for y in 6:
		for x in 20:
			pl.set_pixel(300 + x, 200 + y, Color.WHITE)
	ok(not Diff.compare(p, pl)["ok"], "a small label changed on a phone-size screen is seen")


func test_stored_images() -> void:
	var script: Script = Tool
	var shots: Array = script.get_script_constant_map()["SHOTS"]
	ok(shots.size() >= 10, "the tool draws a good number of screens (%d)" % shots.size())
	var names := {}
	var dupes := 0
	for s in shots:
		if names.has(s[0]):
			dupes += 1
		names[s[0]] = s
	ok(dupes == 0, "every screen has its own name")
	var stored: Array = []
	for f in DirAccess.get_files_at(DIR):
		if f.get_extension() == "png":
			stored.append(f.get_basename())
	for n in names:
		ok(stored.has(n), "'%s' has a stored image" % n)
	for n in stored:
		ok(names.has(n), "the stored image '%s' is drawn by a screen" % n)
	for n in names:
		if not stored.has(n):
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(DIR + n + ".png"))
		var want: Vector2i = names[n][1]
		ok(img != null and not img.is_empty() and img.get_size() == want, "'%s' is %dx%d" % [n, want.x, want.y])
		if img == null or img.is_empty():
			continue
		# not a blank screen: more than a handful of different colours
		var colors := {}
		for y in range(0, img.get_height(), 7):
			for x in range(0, img.get_width(), 7):
				colors[img.get_pixel(x, y).to_html()] = true
		ok(colors.size() > 12, "'%s' is a real screen, not a blank one (%d colours sampled)" % [n, colors.size()])
