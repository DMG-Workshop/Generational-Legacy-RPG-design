## The one button family of the skin (UiSkin.button_tex, button_box, tab_box, button_focus, dress_button; the `button` and `tab` pieces
## in data/ui/skin.json): two faces (parchment key, wooden plank) with the same states, textures kept alive at whole multiples of the
## pixel, the contrast of every face and state in both palettes and the high-contrast variant (and a broken piece or a faint label
## found), the focus ring, dressing a button on each face (`on` crimson, a shut button readable), touch-tall buttons on a phone and
## the old sets gone.
## Run: godot --headless --path . -s res://tests/test_game_skin_buttons.gd
extends SceneTree

const UiSettings := preload("res://ui/play/ui_settings.gd")
const UiSkin := preload("res://ui/play/ui_skin.gd")
const Kit := preload("res://ui/play/ui_kit.gd")

const STATES := ["normal", "hover", "pressed", "disabled", "on"]
const FACES := ["parch", "wood"]

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	GameData.load_all()
	UiSettings.path = "user://test_skin_buttons.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	test_data()
	test_old_sets_gone()
	await test_textures()
	test_boxes()
	test_dressing()
	test_contrast()
	test_touch()
	DirAccess.remove_absolute(UiSettings.path)
	print("skin buttons tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _broken(edit: Callable) -> Array:
	var d: Dictionary = UiSkin.data().duplicate(true)
	edit.call(d)
	return UiSkin.validate(d)


func test_data() -> void:
	ok(UiSkin.validate().is_empty(), "the skin's data is valid: %s" % str(UiSkin.validate()))
	ok(_broken(func(d): d["pieces"]["button"]["base"] = [24.5, 16]).size() > 0, "a button that is not whole pixels is found")
	ok(_broken(func(d): d["pieces"]["button"]["margin"] = 20).size() > 0, "a button margin with no middle is found")
	ok(_broken(func(d): d["pieces"]["button"].erase("faces")).size() > 0, "a button with no faces is found")
	ok(_broken(func(d): d["pieces"]["button"]["faces"].erase("wood")).size() > 0, "a button with no wooden face is found")
	ok(_broken(func(d): d["pieces"]["button"]["faces"]["parch"]["stud_at"] = 5).size() > 0, "a stud outside the margin is found")
	ok(_broken(func(d): d["pieces"]["button"].erase("focus")).size() > 0, "a button with no focus ring is found")
	ok(_broken(func(d): d["pieces"]["button"]["text"]["wood"].erase("on")).size() > 0, "a face with no text colour for a state is found")
	ok(_broken(func(d): d["pieces"]["button"]["text"]["parch"].erase("disabled")).size() > 0, "a parchment key with no shut text is found")
	ok(_broken(func(d): d["pieces"]["button"]["text"]["wood"]["hover"] = ["nothing", "wood_hi", 4.5, 7.0]).size() > 0, "a label colour that does not exist is found")
	ok(_broken(func(d): d["pieces"]["button"]["text"]["parch"]["normal"] = ["parch_lo", "parch_hi", 4.5, 7.0]).size() > 0, "a faint label on parchment is found")
	ok(_broken(func(d): d["pieces"]["button"]["text"]["wood"]["normal"] = ["wood", "wood", 6.0, 10.0]).size() > 0, "a label as dark as its plank is found")
	ok(_broken(func(d): d["variants"]["high_contrast"]["ink_dim"] = "#c8b890").size() > 0, "a high-contrast palette that dims a shut label is found")
	ok(_broken(func(d): d["pieces"]["tab"].erase("text")).size() > 0, "a tab with no text colours is found")
	ok(_broken(func(d): d["pieces"]["tab"]["text"]["on"] = ["wood", "wood_hi", 4.5, 7.0]).size() > 0, "a faint open tab is found")
	ok(_broken(func(d): d["pieces"].erase("tab")).size() > 0, "a missing tab piece is found")
	ok(UiSkin.validate().is_empty(), "and the data is whole again after")


func test_old_sets_gone() -> void:
	var pieces: Dictionary = UiSkin.data()["pieces"]
	ok(not pieces.has("stud"), "there is no stud piece any more")
	ok(not UiSkin.screens().has("plank") and not UiSkin.screens().has("focus"), "and no plank or focus piece in the screens' data")
	var src := FileAccess.get_file_as_string("res://ui/play/ui_skin.gd")
	for gone in ["func stud_tex", "func stud_box", "func plank_tex", "func plank_box", "func focus_tex", "func focus_box", "func dress_battle_button", "func dress_screen_button"]:
		ok(src.find(gone) < 0, "%s is gone" % gone)


func test_textures() -> void:
	var s := UiSkin.pixel()
	var base: Array = UiSkin.piece("button")["base"]
	var w := int(base[0]) * s
	var h := int(base[1]) * s
	for f in FACES:
		var seen := {}
		for st in STATES:
			var t := UiSkin.button_tex(w, h, st, f)
			ok(t != null and t.get_width() % s == 0 and t.get_height() % s == 0, "the %s %s button is a whole multiple of the pixel" % [f, st])
			ok(UiSkin.button_tex(w, h, st, f) == t, "the %s %s button is made once and kept" % [f, st])
			seen[t.get_image().get_data().hex_encode().sha1_text()] = true
			ok(t.get_image().get_pixel(0, 0) == (UiSkin.pal("brown") if (f == "parch" and st == "disabled") else UiSkin.pal("ink")), "the %s %s button has an ink outline (a shut parchment key, brown)" % [f, st])
		ok(seen.size() == 5, "the five states of the %s face look different (%d)" % [f, seen.size()])
		ok(UiSkin.button_tex(w, h, "normal", f).get_image().get_pixel(2 * s, 2 * s) == UiSkin.pal("gold"), "the %s face has a gold stud in the corner" % f)
		ok(UiSkin.button_tex(w, h, "hover", f).get_image().get_pixel(s, s) == UiSkin.pal("gold"), "pointed at, the %s face has a gold frame" % f)
		var mid := UiSkin.button_tex(w, h, "on", f).get_image().get_pixel(w / 2, h / 2)
		ok(mid == UiSkin.pal("crimson"), "chosen, the %s face is crimson" % f)
	ok(UiSkin.button_tex(w, h, "normal", "parch").get_image().get_pixel(w / 2, h / 2) == UiSkin.pal("parch_hi"), "a parchment key is parchment")
	ok(UiSkin.button_tex(w, h, "normal", "wood").get_image().get_pixel(w / 2, h / 2) == UiSkin.pal("wood"), "a wooden plank is wood")
	ok(UiSkin.button_tex(w, h, "normal") == UiSkin.button_tex(w, h, "normal", "parch"), "the parchment key is the default face")
	var ids := {}
	for st in ["normal", "hover", "on"]:
		for t in [UiSkin.tab_tex(64, 48, st)]:
			ok(t.get_width() % s == 0 and t.get_height() % s == 0, "the %s tab is a whole multiple of the pixel" % st)
			ids[t] = true
	ok(ids.size() == 3, "a tab has its own picture for each state")
	ok(UiSkin.tab_tex(64, 48, "off") == UiSkin.tab_tex(64, 48, "normal"), "off is an older name for a tab's normal state")
	var f := UiSkin.button_focus()
	ok(f.texture != null and not f.draw_center and f.get_expand_margin(SIDE_LEFT) > 0.0, "the focus ring has no middle and sits outside the button")
	ok(f == UiSkin.button_focus(), "and is kept")
	var rid: RID = UiSkin.button_tex(w, h, "hover", "wood").get_rid()
	await _frames(5)   # a texture made and not kept is freed before the frame shows: these are kept
	ok(rid.is_valid() and UiSkin.button_tex(w, h, "hover", "wood").get_rid() == rid, "the pictures are still alive some frames later")


func test_boxes() -> void:
	var s := UiSkin.pixel()
	var m := int(UiSkin.piece("button")["margin"]) * s
	for f in FACES:
		for st in STATES:
			var b := UiSkin.button_box(st, f)
			ok(b is StyleBoxTexture and int(b.texture_margin_left) == m and b.axis_stretch_horizontal == StyleBoxTexture.AXIS_STRETCH_MODE_TILE, "the %s %s box is a tiled nine patch in whole pixels" % [f, st])
			ok(UiSkin.button_box(st, f) == b, "and is kept")
	ok(UiSkin.button_box("hover", "parch") != UiSkin.button_box("hover", "wood"), "each face has its own box")
	ok(UiSkin.button_box("normal") == UiSkin.button_box("normal", "parch"), "button_box(state) is the parchment key")
	ok(UiSkin.tab_box("off") == UiSkin.tab_box("normal") and UiSkin.tab_box("normal") != UiSkin.tab_box("on"), "tab boxes by state")
	var c := UiSkin.button_box("normal", "wood")
	ok(c.content_margin_left >= float(2 * s) and c.content_margin_top >= float(s), "a button keeps room for its text")


func _dressed(face: String, on: bool = false, shut: bool = false) -> Button:
	var b := Kit.button("Go", func(): pass)
	if on:
		b.set_meta("skin_on", true)
	b.disabled = shut
	UiSkin.dress_button(b, face)
	return b


func test_dressing() -> void:
	for f in FACES:
		var b := _dressed(f)
		ok(b.get_theme_stylebox("normal") == UiSkin.button_box("normal", f) and b.get_theme_stylebox("hover") == UiSkin.button_box("hover", f), "a %s button wears the %s states" % [f, f])
		ok(b.get_theme_stylebox("pressed") == UiSkin.button_box("pressed", f) and b.get_theme_stylebox("disabled") == UiSkin.button_box("disabled", f), "and its pressed and shut ones")
		ok(b.get_theme_stylebox("focus") == UiSkin.button_focus(), "and the gold focus ring")
		ok(b.get_theme_color("font_color") == UiSkin.button_text(f, "normal") or f == "wood", "the %s button's label colour comes from the data" % f)
		ok(b.get_theme_color("font_hover_color") == UiSkin.button_text(f, "hover") and b.get_theme_color("font_focus_color") == UiSkin.button_text(f, "hover"), "lit when pointed at or focused")
		ok(b.get_theme_color("font_disabled_color") == UiSkin.button_text(f, "disabled") and b.get_theme_color("font_pressed_color") == UiSkin.button_text(f, "pressed"), "and its shut and pressed text")
		ok(b.has_meta("skin_done"), "it is marked as dressed")
		var on := _dressed(f, true)
		ok(on.get_theme_stylebox("normal") == UiSkin.button_box("on", f) and on.get_theme_stylebox("hover") == UiSkin.button_box("on", f), "a chosen %s button is crimson" % f)
		ok(on.get_theme_color("font_color") == UiSkin.pal("gold_hi"), "with gold text")
	ok(_dressed("slot").get_theme_stylebox("normal") != UiSkin.button_box("normal", "parch"), "the dark slot kit buttons under a pane wear is still its own look")
	var host := Button.new()
	root.add_child(host)
	host.set_meta("skin_button_face", "parch")
	UiSkin.mark_on(host, true)
	ok(host.get_theme_stylebox("normal") == UiSkin.button_box("on", "parch"), "mark_on keeps the face the button wears")
	UiSkin.mark_on(host, false)
	ok(host.get_theme_stylebox("normal") == UiSkin.button_box("normal", "parch"), "and takes the crimson off")
	host.queue_free()
	ok(UiSkin.tab_text("on") == UiSkin.pal("gold_hi") and UiSkin.tab_text("off") == UiSkin.tab_text("normal"), "a tab's text comes from the data")


func test_contrast() -> void:
	for v in ["standard", "high_contrast"]:
		UiSettings.set_access("high_contrast", v == "high_contrast")
		var hc: bool = v == "high_contrast"
		for f in FACES:
			var table: Dictionary = UiSkin.piece("button")["text"][f]
			for st in STATES:
				var e: Array = table[st]
				var got := UiSkin.contrast(UiSkin.pal(str(e[0])), UiSkin.pal(str(e[1])))
				ok(got >= (7.0 if hc else 4.5), "%s button, %s: %s on %s is %.1f in %s" % [f, st, e[0], e[1], got, v])
		for st in ["normal", "hover", "on", "disabled"]:
			var e: Array = UiSkin.piece("tab")["text"][st]
			ok(UiSkin.contrast(UiSkin.pal(str(e[0])), UiSkin.pal(str(e[1]))) >= (7.0 if hc else 4.5), "tab, %s, reads in %s" % [st, v])
		ok(UiSkin.validate().is_empty(), "the data is valid in %s" % v)
		# the face under the text is the one the picture is drawn with
		ok(UiSkin.button_tex(96, 64, "normal", "parch").get_image().get_pixel(48, 32) == UiSkin.pal("parch_hi"), "the parchment key is drawn from the palette of %s" % v)
		ok(UiSkin.button_tex(96, 64, "normal", "wood").get_image().get_pixel(48, 32) == UiSkin.pal("wood"), "the plank is drawn from the palette of %s" % v)
		if hc:
			ok(UiSkin.button_tex(96, 64, "normal", "wood").get_image().get_pixel(0, 0) == Color("#000000"), "the high-contrast outline is black")
	UiSettings.set_access("high_contrast", false)


func test_touch() -> void:
	# a skinned button keeps the height touch rules ask for: the kit's minimum size is the larger of the two
	var need := float(GameData.mobile.get("touch_target_px", 44))
	var b := Kit.button("Go", func(): pass, Vector2(0, need))
	UiSkin.dress_button(b, "wood")
	ok(b.get_combined_minimum_size().y >= need, "a wooden plank is at least touch_target_px tall")
	var p := Kit.button("Go", func(): pass, Vector2(0, need))
	UiSkin.dress_button(p, "parch")
	ok(p.get_combined_minimum_size().y >= need, "and so is a parchment key")
	b.free()
	p.free()
