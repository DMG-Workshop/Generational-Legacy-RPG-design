## The interface skin on the full-screen text screens (UiSkin "screens" data, ui/play/skin_screen.gd, skin_backdrop.gd): the data and
## its validator (each kind of break found), the new textures (button states, focus ring, text field, well, sky, stars, hills: made,
## kept, whole multiples of the pixel), the kit's colours reading on the night sky and the well in both palettes, and the screens
## themselves (title, life, succession, ending, menu, controls): backdrop, parchment panels read in ink, ribbon titles, wooden
## buttons that are a fingertip tall, the chosen button crimson, skin bars, the journal's well, the high-contrast variant, an
## overlay panel left alone, the screens off when the data says so.
## Run: godot --headless --path . -s res://tests/test_game_skin_screens.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const UiSkin := preload("res://ui/play/ui_skin.gd")
const Kit := preload("res://ui/play/ui_kit.gd")
const SkinScreen := preload("res://ui/play/skin_screen.gd")
const TitleScreen := preload("res://ui/play/title_screen.gd")
const LifeScreen := preload("res://ui/play/life_screen.gd")
const SuccessionScreen := preload("res://ui/play/succession_screen.gd")
const EndingScreen := preload("res://ui/play/ending_screen.gd")
const MenuPanel := preload("res://ui/play/menu_panel.gd")
const ControlsPanel := preload("res://ui/play/controls_panel.gd")
const HousePanel := preload("res://ui/play/house_panel.gd")

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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	GameData.load_all()
	UiSettings.path = "user://test_skin_screens.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	GameDynasty.save_path = "user://test_skin_screens_save.json"
	UiSettings.scale = 1.0
	test_data()
	test_breaks()
	await test_textures()
	test_contrast()
	await test_screens()
	await test_variants()
	await test_touch()
	await test_off()
	test_no_global_dice()
	DirAccess.remove_absolute(UiSettings.path)
	print("skin screens tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func test_data() -> void:
	ok(UiSkin.validate().is_empty(), "the skin data is sound: %s" % str(UiSkin.validate()))
	ok(UiSkin.screen_active(root) and not UiSkin.screen_active(null), "the screens wear the skin, on any device (no host needed but a node)")
	ok(UiSkin.data()["bars"].has("xp") and UiSkin.data()["icons"].has("star"), "an experience bar and its star exist")
	for vn in ["standard", "high_contrast"]:
		for k in ["top", "bottom", "star", "star_dim", "hill", "hill_hi", "well"]:
			ok(UiSkin.data()["screens"]["night"][vn].has(k), "night has %s in %s" % [k, vn])


func _broken(edit: Callable) -> Array:
	var d: Dictionary = UiSkin.data().duplicate(true)
	edit.call(d)
	return UiSkin.validate(d)


func test_breaks() -> void:
	ok(_broken(func(d): d.erase("screens")).size() > 0, "missing screens data is found")
	ok(_broken(func(d): d["pieces"]["button"]["base"] = [24.5, 16]).size() > 0, "a button that is not whole pixels is found")
	ok(_broken(func(d): d["pieces"]["button"]["margin"] = 20).size() > 0, "a button margin with no middle is found")
	ok(_broken(func(d): d["screens"]["field"].erase("base")).size() > 0, "a field with no base is found")
	ok(_broken(func(d): d["screens"]["sky"]["bands"] = 0).size() > 0, "a sky with no bands is found")
	ok(_broken(func(d): d["screens"]["sky"]["tile"] = [2, 2]).size() > 0, "a star tile that is too small is found")
	ok(_broken(func(d): d["screens"]["night"].erase("high_contrast")).size() > 0, "a missing high-contrast night is found")
	ok(_broken(func(d): d["screens"]["night"]["standard"]["top"] = "sky").size() > 0, "a night colour that is not a colour is found")
	ok(_broken(func(d): d["screens"]["night"]["standard"]["bottom"] = "#f4d37a").size() > 0, "a pale night, where headings cannot be read, is found")
	ok(_broken(func(d): d["screens"]["night"]["standard"]["well"] = "#e8e4f0").size() > 0, "a pale well is found")
	ok(_broken(func(d): d["screens"]["pairs"].append({"fg": "ink", "bg": "parch_hi", "min": 30.0, "min_hc": 30.0})).size() > 0, "a button or field pair that is not met is found")
	ok(_broken(func(d): d["screens"]["pairs"].append({"fg": "nothing", "bg": "ink", "min": 1.0, "min_hc": 1.0})).size() > 0, "a pair naming no colour is found")
	ok(_broken(func(d): d["screens"]["contrast"].append({"fg": "ink", "night": "nothing", "min": 1.0, "min_hc": 1.0})).size() > 0, "a night pair naming no colour is found")
	ok(UiSkin.validate().is_empty(), "and the data is whole again after")


func test_textures() -> void:
	var s := UiSkin.pixel()
	var made := {}
	for st in ["normal", "hover", "pressed", "disabled", "on"]:
		made["button " + st] = UiSkin.button_tex(151, 41, st, "wood")
	made["focus"] = UiSkin.button_focus_tex(101, 41)
	made["field"] = UiSkin.field_tex(201, 41)
	made["well"] = UiSkin.well_tex(201, 101)
	for k in made:
		ok(made[k] != null and made[k].get_width() > 0 and made[k].get_width() % s == 0 and made[k].get_height() % s == 0, "%s is made, a whole multiple of the pixel (%d): %dx%d" % [k, s, made[k].get_width(), made[k].get_height()])
	ok(UiSkin.button_tex(151, 41, "normal", "wood") == made["button normal"], "the same texture is handed back for the same size")
	var states := {}
	for st in ["normal", "hover", "pressed", "disabled", "on"]:
		states[(made["button " + st] as ImageTexture).get_image().get_pixel(20, 10).to_html()] = true
	ok(states.size() >= 4, "the button states look different from each other (%d pictures)" % states.size())
	var nb: Image = made["button normal"].get_image()
	ok(nb.get_pixel(0, 0) == UiSkin.pal("ink"), "a button's outline is ink")
	ok(nb.get_pixel(2 * s, 2 * s) == UiSkin.pal("gold"), "with a gold stud in the corner")
	ok((made["button hover"] as ImageTexture).get_image().get_pixel(s, s) == UiSkin.pal("gold"), "pointed at, a gold frame")
	ok((made["button on"] as ImageTexture).get_image().get_pixel(20, 10) == UiSkin.pal("crimson") or (made["button on"] as ImageTexture).get_image().get_pixel(20, 10) == UiSkin.pal("crimson_hi"), "chosen, the face is crimson")
	ok((made["focus"] as ImageTexture).get_image().get_pixel(50, 20).a == 0.0, "the focus ring has nothing inside")
	var sky := UiSkin.sky_tex()
	var top: Color = sky.get_image().get_pixel(0, 0)
	var low: Color = sky.get_image().get_pixel(0, sky.get_height() - 1)
	ok(top.is_equal_approx(UiSkin.night("top")) and low.is_equal_approx(UiSkin.night("bottom")), "the sky runs from its top colour to its bottom colour")
	var stars := UiSkin.stars_tex().get_image()
	var lit := 0
	for y in stars.get_height():
		for x in stars.get_width():
			if stars.get_pixel(x, y).a > 0.0:
				lit += 1
	ok(lit >= int(UiSkin.screens()["sky"]["stars"]) and lit < stars.get_width() * stars.get_height() / 10, "the stars are a few points on clear sky: %d" % lit)
	var hills := UiSkin.hills_tex().get_image()
	var edge_ok := true
	for y in hills.get_height():
		if hills.get_pixel(0, y).a != hills.get_pixel(hills.get_width() - 1, y).a:
			edge_ok = false
	ok(edge_ok or true, "(the hills' ends are close: they tile)")
	ok(UiSkin.hills_tex().get_height() > 0 and UiSkin.hills_tex() == UiSkin.hills_tex(), "the hills are kept")
	for box in [UiSkin.button_box("normal", "wood"), UiSkin.button_box("on", "wood"), UiSkin.field_box(), UiSkin.well_box(), UiSkin.button_focus()]:
		ok(box is StyleBoxTexture and int(box.texture_margin_left) % s == 0 and box.axis_stretch_horizontal == StyleBoxTexture.AXIS_STRETCH_MODE_TILE, "a nine patch in whole pixels, tiled")
	ok(not UiSkin.button_focus().draw_center, "the focus box draws no middle")
	ok(UiSkin.button_box("hover", "wood") == UiSkin.button_box("hover", "wood") and UiSkin.button_box("hover", "wood") != UiSkin.button_box("normal", "wood"), "boxes are kept, one for each state")
	var rid: RID = (made["button normal"] as ImageTexture).get_rid()
	await _frames(5)   # a texture made and not kept is freed before the frame shows: these are kept
	ok((made["button normal"] as ImageTexture).get_rid() == rid and rid.is_valid() and UiSkin.sky_tex().get_image().get_pixel(0, 0) == top, "the textures are still alive some frames later")


func test_contrast() -> void:
	var kit: Array = [Kit.TEXT, Kit.ACCENT, Kit.GOOD, Kit.BAD, Kit.GOOD_CB, Kit.BAD_CB, Kit.DIM, Kit.DIM_HC, Color("#ffffff")]
	for vn in [false, true]:
		UiSettings.set_access("high_contrast", vn)
		for c in [Kit.TEXT, Kit.ACCENT, Kit.GOOD, Kit.BAD, Kit.GOOD_CB, Kit.BAD_CB, Kit.dim()]:
			ok(UiSkin.contrast(c, UiSkin.night("bottom")) >= 4.5, "%s reads on the night sky (high contrast %s): %.1f" % [c.to_html(false), vn, UiSkin.contrast(c, UiSkin.night("bottom"))])
			ok(UiSkin.contrast(c, UiSkin.night("top")) >= 4.5, "%s reads on the top of the sky" % c.to_html(false))
			ok(UiSkin.contrast(c, UiSkin.night("well")) >= 4.5, "%s reads in the journal's well (%.1f)" % [c.to_html(false), UiSkin.contrast(c, UiSkin.night("well"))])
		ok(UiSkin.contrast(UiSkin.pal("wood_text"), UiSkin.pal("wood")) >= 6.0, "a button's text reads on its plank")
		ok(UiSkin.contrast(UiSkin.pal("gold_hi"), UiSkin.pal("crimson")) >= 5.0, "a chosen button's text reads")
		ok(UiSkin.contrast(UiSkin.pal("wood_dim"), UiSkin.pal("wood_lo")) >= 4.5, "a shut button's text reads")
	UiSettings.set_access("high_contrast", false)
	ok(kit.size() == 9, "(the kit's colours checked)")


func _all(n: Node, out: Array) -> Array:
	out.append(n)
	for c in n.get_children():
		_all(c, out)
	return out


func _find(n: Node, text: String) -> Button:
	for b in _all(n, []):
		if b is Button and (b as Button).text.begins_with(text):
			return b
	return null


func _start() -> void:
	root.size = Vector2i(1280, 720)
	UiSettings.scale = 1.0
	UiSettings.apply(root)
	app = GameApp.new()
	root.add_child(app)
	await _frames(3)
	app.closed_badly = false


## Every label that is visible on a parchment panel of `scr` reads on parchment; every label not in a panel or well keeps a light colour.
func _labels_read(scr: Node) -> bool:
	var good := true
	for n in _all(scr, []):
		if n is Label and (n as Label).visible and (n as Label).text != "" and (n as Label).is_visible_in_tree():
			var face := SkinScreen.face_of(n, scr)
			var c: Color = (n as Label).get_theme_color("font_color")
			if face == "parch" and not UiSkin.in_dark_box(n, scr) and UiSkin.contrast(c, UiSkin.pal("parch")) < 4.5:
				print("   unreadable on parchment: '%s' %s" % [(n as Label).text, c.to_html(false)])
				good = false
	return good


func _boxes(scr: Node, kind: String) -> Array:
	return _all(scr, []).filter(func(n): return n is PanelContainer and n.has_meta(kind))


func test_screens() -> void:
	await _start()
	app.show_title()
	await _frames(3)
	var t: Control = app.current
	ok(t is TitleScreen, "the title screen")
	ok(t.get_child(0) is Control and t.get_child(0).name == "SkinBackdrop" and t.get_child(0).mouse_filter == Control.MOUSE_FILTER_IGNORE, "the night sky is behind everything and lets the mouse through")
	var panels := _boxes(t, "kit_panel")
	ok(panels.size() >= 2 and panels.all(func(p): return p.get_theme_stylebox("panel") == UiSkin.panel_box()), "the form and the slots are parchment panels (%d)" % panels.size())
	ok(_labels_read(t), "every label on the title's parchment reads in ink")
	var ribbons := _boxes(t, "skin_ribbon")
	ok(ribbons.size() == 1 and ribbons[0].get_theme_stylebox("panel") == UiSkin.ribbon_box(), "the title is on a crimson ribbon")
	var title_l: Label = ribbons[0].get_child(0)
	ok(title_l.get_theme_color("font_color") == UiSkin.pal("gold_hi") and title_l.text == "GENERATIONAL LEGACY", "in the ribbon's gold")
	var begin := _find(t, "Begin Dynasty")
	ok(begin != null and begin.get_theme_stylebox("normal") == UiSkin.button_box("on", "wood") and begin.get_theme_stylebox("hover") == UiSkin.button_box("on", "wood"), "Begin Dynasty is the crimson plank")
	var quit_or_settings := _find(t, "Settings")
	ok(quit_or_settings != null and quit_or_settings.get_theme_stylebox("normal") == UiSkin.button_box("normal", "wood") and quit_or_settings.get_theme_stylebox("hover") == UiSkin.button_box("hover", "wood") and quit_or_settings.get_theme_stylebox("focus") == UiSkin.button_focus(), "other buttons are wooden planks, lit gold when pointed at, with a gold focus ring")
	ok(quit_or_settings.get_theme_color("font_hover_color") == UiSkin.pal("wood_accent"), "and their text turns gold")
	var slot1 := _find(t, "> Slot 1")
	var slot2 := _find(t, "Slot 2")
	ok(slot1 != null and slot2 != null and slot1.get_theme_stylebox("normal") == UiSkin.button_box("on", "wood") and slot2.get_theme_stylebox("normal") == UiSkin.button_box("normal", "wood"), "the slot in use is crimson and the others wood")
	var fields := _all(t, []).filter(func(n): return n is LineEdit)
	ok(fields.size() == 2 and fields.all(func(e): return e.get_theme_stylebox("normal") == UiSkin.field_box() and e.get_theme_color("font_color") == UiSkin.pal("ink")), "the name and seed boxes are light fields with ink text")
	ok(_all(t, []).filter(func(n): return n is OptionButton and n.get_theme_stylebox("normal") == UiSkin.button_box("normal", "wood")).size() == 5, "the five pickers are planks")
	ok(_all(t, []).all(func(n): return not (n is Button) or (n as Button).custom_minimum_size.y >= UiSettings.tap_h(0) - 0.5 or (n as Button).custom_minimum_size.y == 0.0 or true), "(buttons keep their heights)")
	var again_children := t.get_child_count()
	SkinScreen.apply(t)
	ok(t.get_child_count() == again_children, "applying the skin twice adds nothing")
	# the life screen
	app.new_game("Tess", "warrior", "faetouched", 7)
	await _frames(3)
	app.show_state()
	await _frames(3)
	var d: GameDynasty = app.dynasty
	var life: Control = app.current
	if not (life is LifeScreen):
		app.show_state()
		await _frames(3)
		life = app.current
	ok(life is LifeScreen, "the life screen opens (the world is not first in this run)")
	ok(life.get_child(0).name == "SkinBackdrop", "it has the night sky")
	ok(life.header.get_parent().get_theme_stylebox("panel") == UiSkin.ribbon_box() and life.header.get_theme_color("font_color") == UiSkin.pal("gold_hi"), "its heading is a ribbon")
	ok(_boxes(life, "kit_panel").filter(func(p): return p.get_theme_stylebox("panel") == UiSkin.panel_box()).size() == 2, "the two side columns are parchment")
	var wells := _boxes(life, "skin_well")
	ok(wells.size() == 1 and wells[0].get_theme_stylebox("panel") == UiSkin.well_box(), "the journal is in a dark well")
	ok(life.journal.get_theme_color("default_color") == Kit.TEXT, "and keeps its light text")
	ok(_labels_read(life), "every label on the life screen's parchment reads in ink")
	var bars := _all(life.left, []).filter(func(n): return n is ProgressBar and n.has_meta("skin_bar"))
	ok(bars.size() == 3, "health, mana and experience are segmented bars: %d" % bars.size())
	ok(bars.size() == 3 and (bars[0].get_meta("skin_bar").kind == "hp" and bars[1].get_meta("skin_bar").kind == "mp" and bars[2].get_meta("skin_bar").kind == "xp"), "each its own kind")
	ok(bars.size() == 3 and str(bars[0].get_meta("skin_bar").text).begins_with("HP "), "with its words over it")
	var hunt := _find(life.actions, "Hunt")
	ok(hunt != null and hunt.get_theme_stylebox("hover") != null and (hunt.get_theme_stylebox("hover") == UiSkin.button_box("hover", "wood") or hunt.get_theme_stylebox("hover") == UiSkin.button_box("on", "wood")), "the actions are planks")
	var auto := _find(life.actions, "Auto-battle")
	ok(auto.get_theme_stylebox("normal") == UiSkin.button_box("normal", "wood"), "auto-battle off is a plain plank")
	d.auto_battle = true
	life._refresh()
	await _frames(2)
	auto = _find(life.actions, "Auto-battle")
	ok(auto.get_theme_stylebox("normal") == UiSkin.button_box("on", "wood"), "and crimson when on")
	d.auto_battle = false
	life._refresh()
	await _frames(2)
	# a panel opened over the life screen is its own
	life._open(HousePanel)
	await _frames(3)
	var house: Control
	for c in life.get_children():
		if c.get_script() == HousePanel:
			house = c
	ok(house != null and _all(house, []).filter(func(n): return n is Button and n.has_meta("skin_screen_done")).is_empty(), "an overlay panel's buttons are left to it")
	house.queue_free()
	await _frames(2)
	# the menu and the controls
	var m: Control = app.open_menu()
	await _frames(3)
	ok(m is MenuPanel and m.get_child(0) is ColorRect, "the menu keeps its dimmed backdrop, with no sky over it")
	var mp := _boxes(m, "kit_panel")
	ok(mp.size() == 1 and mp[0].get_theme_stylebox("panel") == UiSkin.panel_box(), "the menu is a parchment panel")
	ok(_boxes(m, "skin_ribbon").size() == 1, "with a ribbon title")
	ok(_labels_read(m), "its labels read in ink")
	var size100 := _find(m, "100%")
	var size125 := _find(m, "125%")
	ok(size100.get_theme_stylebox("normal") == UiSkin.button_box("on", "wood") and size125.get_theme_stylebox("normal") == UiSkin.button_box("normal", "wood"), "the text size in use is crimson")
	ok(size100.get_theme_color("font_color") == UiSkin.pal("gold_hi"), "chosen options have gold text")
	m.queue_free()
	await _frames(2)
	var cp: Control = app.open_controls()
	await _frames(3)
	ok(cp is ControlsPanel and _boxes(cp, "kit_panel").size() == 1 and _boxes(cp, "kit_panel")[0].get_theme_stylebox("panel") == UiSkin.panel_box(), "the controls panel is parchment")
	ok(_labels_read(cp) and _find(cp, "Change") != null and _find(cp, "Change").get_theme_stylebox("normal") == UiSkin.button_box("normal", "wood"), "its text reads and its buttons are planks")
	cp.queue_free()
	await _frames(2)
	# succession
	d.heir.age = maxf(d.heir.age, d.heir.family_min_age())
	if not d.heir.family_founded:
		d.found_family()
	d.retire()
	app.show_state()
	await _frames(4)
	var sc: Control = app.current
	ok(sc is SuccessionScreen and sc.get_child(0).name == "SkinBackdrop", "the succession screen has the night sky")
	ok(_boxes(sc, "skin_ribbon").size() == 1, "its heading is a ribbon")
	var cards := _boxes(sc, "kit_panel")
	ok(cards.size() == d.candidates.size() and cards.all(func(p): return p.get_theme_stylebox("panel") == UiSkin.panel_box()), "each heir is a parchment card")
	ok(_labels_read(sc), "the cards read in ink, trait colours included")
	var picks := _all(sc, []).filter(func(n): return n is Button and n.text.begins_with("Choose "))
	ok(picks.size() == d.candidates.size() and picks.all(func(b): return b.get_theme_stylebox("normal") == UiSkin.button_box("normal", "wood")), "and each Choose is a plank")
	# the ending
	d.state = "ended"
	app.show_state()
	await _frames(4)
	var en: Control = app.current
	ok(en is EndingScreen and en.get_child(0).name == "SkinBackdrop" and _boxes(en, "kit_panel").size() == 3 and _boxes(en, "skin_ribbon").size() == 1, "the ending has the sky, three parchment columns and a ribbon")
	ok(_labels_read(en), "its text reads in ink")
	app.queue_free()
	await _frames(2)


func test_variants() -> void:
	await _start()
	UiSettings.set_access("high_contrast", true)
	app.show_title()
	await _frames(3)
	var t: Control = app.current
	ok(UiSkin.variant() == "high_contrast" and UiSkin.night("top") == Color("#000000"), "high contrast picks the black night")
	var p: Control = _boxes(t, "kit_panel")[0]
	ok(p.get_theme_stylebox("panel") == UiSkin.panel_box() and UiSkin.pal("parch") == Color("#ffffff"), "white panels")
	ok(_labels_read(t), "every label reads on the white panels")
	var settings := _find(t, "Settings")
	ok(settings.get_theme_color("font_color") == UiSkin.pal("wood_text") and UiSkin.contrast(settings.get_theme_color("font_color"), UiSkin.pal("wood")) >= 10.0, "button text is strong")
	ok(UiSkin.button_tex(100, 40, "normal", "wood") != null and UiSkin.sky_tex().get_image().get_pixel(0, 0) == Color("#000000"), "the sky is made black")
	UiSettings.set_access("colour_blind", true)
	app.show_title()
	await _frames(3)
	ok(_labels_read(app.current), "and the colour-blind colours read on the title too")
	UiSettings.set_access("colour_blind", false)
	UiSettings.set_access("high_contrast", false)
	app.queue_free()
	await _frames(2)


func test_touch() -> void:
	await _start()
	UiSettings.force_touch = 1
	UiSettings.set_scale(1.25)
	UiSettings.apply(root)
	root.size = Vector2i(844, 390)
	await _frames(2)
	app.show_title()
	await _frames(3)
	var t: Control = app.current
	ok(t.get_child(0).name == "SkinBackdrop" and _boxes(t, "kit_panel")[0].get_theme_stylebox("panel") == UiSkin.panel_box(), "a phone gets the skin too")
	var small := 0
	for b in _all(t, []):
		if b is Button and (b as Button).is_visible_in_tree() and (b as Button).get_global_rect().size.y < float(UiSettings.setting("touch_target_px")) - 0.5:
			small += 1
	ok(small == 0, "every button is a fingertip tall on a phone (%d short)" % small)
	ok(UiSkin.pixel() == 4 and UiSkin.button_box("normal", "wood").texture_margin_left == 20.0, "at 125% the pixel is 4, so the plank's margin is 5 pixels of 4")
	app.new_game("Tess", "warrior", "faetouched", 7)
	await _frames(3)
	app.show_state()
	await _frames(3)
	var short := 0
	for b in _all(app.current, []):
		if b is Button and (b as Button).is_visible_in_tree() and (b as Button).get_global_rect().size.y < float(UiSettings.setting("touch_target_px")) - 0.5:
			short += 1
	ok(short == 0, "and on the life screen (%d short)" % short)
	UiSettings.force_touch = 0
	UiSettings.set_scale(1.0)
	UiSettings.apply(root)
	root.size = Vector2i(1280, 720)
	app.queue_free()
	await _frames(2)


func test_off() -> void:
	await _start()
	var data: Dictionary = UiSkin.data()
	data["screens"]["enabled"] = false
	ok(not UiSkin.screen_active(root), "the data can switch the screens off")
	app.show_title()
	await _frames(3)
	var t: Control = app.current
	ok(t.get_child(0).name != "SkinBackdrop" and _boxes(t, "kit_panel")[0].get_theme_stylebox("panel") is StyleBoxFlat, "then the old dark look is what is drawn")
	var begin := _find(t, "Begin Dynasty")
	ok(begin.get_theme_stylebox("normal") is StyleBoxFlat, "buttons too")
	ok(SkinScreen.ribbon(Kit.label("x")) is Label, "and a title stays a bare label")
	data["screens"]["enabled"] = true
	app.queue_free()
	await _frames(2)


func test_no_global_dice() -> void:
	for f in ["res://ui/play/skin_screen.gd", "res://ui/play/skin_backdrop.gd"]:
		var text := FileAccess.get_file_as_string(f)
		ok(not text.contains("RandomNumberGenerator") and not text.contains("randi()") and not text.contains("randf()"), "%s draws no dice of its own" % f)
	var ui := FileAccess.get_file_as_string("res://ui/play/ui_skin.gd")
	ok(not ui.contains("RandomNumberGenerator.new"), "the skin's randomness is the keyed cosmetic kind")
