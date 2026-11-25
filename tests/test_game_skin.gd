## The interface skin (UiSkin, data/ui/skin.json; docs/ART_DIRECTION.md): the data and its validator (and that each kind of break is
## found), the textures (made, kept alive across frames, whole multiples of the pixel size, the same one handed back), the pixel at
## the player's UI scale, the contrast figures of the brief, the high-contrast variant, the colours a label gets on parchment and
## wood, and that panes wear the skin on a desktop-sized window while a compact window or a touch screen keeps the old look.
## Run: godot --headless --path . -s res://tests/test_game_skin.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const UiSkin := preload("res://ui/play/ui_skin.gd")
const Kit := preload("res://ui/play/ui_kit.gd")
const SandboxScreen := preload("res://ui/play/sandbox_screen.gd")
const HousePanel := preload("res://ui/play/house_panel.gd")
const StatusPane := preload("res://ui/play/status_pane.gd")
const PackPane := preload("res://ui/play/pack_pane.gd")
const FigurePane := preload("res://ui/play/figure_pane.gd")
const MinimapPane := preload("res://ui/play/minimap_pane.gd")
const ItemSlot := preload("res://ui/play/item_slot.gd")

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
	UiSettings.path = "user://test_skin.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	GameDynasty.save_path = "user://test_skin_save.json"
	UiSettings.scale = 1.0
	test_data()
	test_breaks()
	await test_textures()
	test_pixel()
	test_contrast()
	test_text_colours()
	test_variants()
	await test_panes()
	await test_old_look()
	DirAccess.remove_absolute(UiSettings.path)
	print("skin tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func test_data() -> void:
	ok(UiSkin.validate().is_empty(), "the skin data is sound: %s" % str(UiSkin.validate()))
	ok(UiSkin.pal("ink") == Color("#2a1c14") and UiSkin.pal("parch") == Color("#d9c597"), "the palette is the brief's")
	ok(UiSkin.face_for("minimap_pane") == "wood" and UiSkin.face_for("status_pane") == "parch" and UiSkin.face_for("pack_pane:bag1") == "parch", "the minimap has a wooden face and the rest parchment")
	for k in UiSkin.PALETTE_KEYS:
		ok(UiSkin.data()["variants"]["standard"].has(k) and UiSkin.data()["variants"]["high_contrast"].has(k), "both palettes have %s" % k)


func _broken(edit: Callable) -> Array:
	var d: Dictionary = UiSkin.data().duplicate(true)
	edit.call(d)
	return UiSkin.validate(d)


func test_breaks() -> void:
	ok(_broken(func(d): d.erase("pixel")).size() > 0, "a missing pixel size is found")
	ok(_broken(func(d): d["pixel"] = 1.5).size() > 0, "a fractional pixel size is found")
	ok(_broken(func(d): d["pixel"] = 0).size() > 0, "a pixel size under 1 is found")
	ok(_broken(func(d): d["pieces"].erase("ribbon")).size() > 0, "a missing piece is found")
	ok(_broken(func(d): d["pieces"]["panel"]["base"] = [48.5, 48]).size() > 0, "a piece that is not a whole number of pixels is found")
	ok(_broken(func(d): d["pieces"]["inset"]["margin"] = 20).size() > 0, "a margin with no middle is found")
	ok(_broken(func(d): d["variants"].erase("high_contrast")).size() > 0, "a missing high-contrast palette is found")
	ok(_broken(func(d): d["variants"]["standard"]["gold"] = "not a colour").size() > 0, "a colour that is not a colour is found")
	ok(_broken(func(d): d["variants"]["standard"].erase("ink")).size() > 0, "a missing palette colour is found")
	ok(_broken(func(d): d["variants"]["standard"]["hp"] = ["#ff0000"]).size() > 0, "a bar colour set of the wrong size is found")
	ok(_broken(func(d): d["variants"]["standard"]["ink"] = "#d9c597").size() > 0, "ink as pale as the parchment (contrast too low) is found")
	ok(_broken(func(d): d["variants"]["high_contrast"]["ink_dim"] = "#cccccc").size() > 0, "a high-contrast figure that is not met is found")
	ok(_broken(func(d): d["contrast"].append({"fg": "nothing", "bg": "ink", "min": 1.0, "min_hc": 1.0})).size() > 0, "a contrast pair naming no colour is found")
	ok(_broken(func(d): d["contrast"].append({"fg": "ink"})).size() > 0, "a contrast pair with no figures is found")
	ok(_broken(func(d): d["icons"]["heart"] = ["##"]).size() > 0, "an icon of the wrong size is found")
	ok(_broken(func(d): d["bars"]["hp"]["icon"] = "nothing").size() > 0, "a bar naming no icon is found")
	ok(_broken(func(d): d["text_maps"]["parch"]["#e8e4f0"] = "nothing").size() > 0, "a text map naming no colour is found")
	ok(_broken(func(d): d["faces"]["status_pane"] = "marble").size() > 0, "a face that is neither parchment nor wood is found")
	ok(UiSkin.validate().is_empty(), "and the data is whole again after")


func test_textures() -> void:
	var s := UiSkin.pixel()
	var made := {
		"panel": UiSkin.panel_tex(301, 187), "frame": UiSkin.frame_tex(150, 99), "ribbon": UiSkin.ribbon_tex(251, 31),
		"inset": UiSkin.inset_tex(47, 47, false), "lit inset": UiSkin.inset_tex(47, 47, true), "header": UiSkin.header_tex(1280, 56),
		"bar": UiSkin.bar_tex(211, 21, 0.5, "hp"), "icon": UiSkin.icon_tex("heart"),
	}
	for k in made:
		ok(made[k] != null and made[k].get_width() > 0, "%s texture is made" % k)
	for k in made:
		if k != "icon":
			ok(made[k].get_width() % s == 0 and made[k].get_height() % s == 0, "%s is a whole multiple of the pixel (%d): %dx%d" % [k, s, made[k].get_width(), made[k].get_height()])
	ok(made["panel"].get_width() == 302 and made["panel"].get_height() == 188, "a panel is rounded up to the pixel: 301x187 becomes 302x188")
	ok(UiSkin.panel_tex(301, 187) == made["panel"], "the same texture is handed back for the same size")
	ok(UiSkin.bar_tex(211, 21, 0.5, "hp") == made["bar"], "and for the same bar")
	ok(UiSkin.bar_tex(211, 21, 0.9, "hp") != made["bar"], "a bar filled differently is another texture")
	ok(UiSkin.inset_tex(47, 47, true) != UiSkin.inset_tex(47, 47, false), "a lit slot differs from an unlit one")
	var img: Image = made["panel"].get_image()
	ok(img.get_pixel(0, 0) == UiSkin.pal("ink"), "a panel's outline is ink")
	ok(img.get_pixel(1, 1) == UiSkin.pal("ink"), "(drawn at whole pixels: the first two screen pixels are one)")
	var rid: RID = (made["panel"] as ImageTexture).get_rid()
	await _frames(5)   # a texture made and not kept is freed before the frame shows: these are kept
	ok((made["panel"] as ImageTexture).get_rid() == rid and rid.is_valid() and UiSkin.panel_tex(301, 187) == made["panel"], "textures are still alive some frames later")
	ok(made["panel"].get_image().get_pixel(10, 10).a == 1.0, "and still hold their picture")
	for box in [UiSkin.panel_box(), UiSkin.frame_box(), UiSkin.ribbon_box(), UiSkin.inset_box(false), UiSkin.inset_box(true)]:
		ok(box is StyleBoxTexture and box.texture != null and int(box.texture_margin_left) % s == 0 and box.axis_stretch_horizontal == StyleBoxTexture.AXIS_STRETCH_MODE_TILE, "a nine patch with its margin in whole pixels, tiled and never stretched")
	ok(UiSkin.panel_box() == UiSkin.panel_box(), "boxes are kept too")


func test_pixel() -> void:
	UiSettings.scale = 1.0
	ok(UiSkin.pixel() == 2, "at the default scale a pixel of the skin is 2")
	UiSettings.scale = 1.5
	ok(UiSkin.pixel() == 2, "at 1.5 it is still 2 (3 screen pixels)")
	UiSettings.scale = 1.25
	ok(UiSkin.pixel() == 4, "at 1.25 it is 4 (5 screen pixels), never 2.5")
	for sc: float in UiSettings.scales():
		UiSettings.scale = sc
		var screen: float = float(UiSkin.pixel()) * sc
		ok(is_equal_approx(screen, roundf(screen)), "at scale %s a pixel is a whole number of screen pixels (%s)" % [sc, screen])
	UiSettings.scale = 1.0
	var a := UiSkin.panel_tex(200, 100)
	UiSettings.scale = 1.25
	var b := UiSkin.panel_tex(200, 100)
	ok(a != b and b.get_width() == 200, "another pixel size makes another texture, still whole")
	UiSettings.scale = 1.0


func test_contrast() -> void:
	var ink := UiSkin.pal("ink")
	ok(UiSkin.contrast(Color.BLACK, Color.WHITE) > 20.9, "the contrast of black on white is 21")
	ok(UiSkin.contrast(ink, UiSkin.pal("parch")) >= 9.6, "ink on parchment is 9.7 to 1 (%.2f)" % UiSkin.contrast(ink, UiSkin.pal("parch")))
	ok(UiSkin.contrast(UiSkin.pal("crimson_dk"), UiSkin.pal("parch")) >= 7.5, "dark crimson on parchment is 7.6 to 1")
	ok(UiSkin.contrast(UiSkin.pal("gold_hi"), UiSkin.pal("crimson")) >= 5.5, "the ribbon's gold on crimson is 5.6 to 1")
	ok(UiSkin.contrast(UiSkin.pal("gold"), UiSkin.pal("crimson")) < 4.5, "plain gold on crimson is under 4.5, which is why the ribbon uses the lighter gold")
	for pair in UiSkin.data()["contrast"]:
		for vn in ["standard", "high_contrast"]:
			var v: Dictionary = UiSkin.data()["variants"][vn]
			var need := float(pair["min_hc"] if vn == "high_contrast" else pair["min"])
			ok(UiSkin.contrast(Color(str(v[pair["fg"]])), Color(str(v[pair["bg"]]))) >= need, "%s: %s on %s meets %.1f" % [vn, pair["fg"], pair["bg"], need])


func test_text_colours() -> void:
	# every colour the dark look gives text, put on parchment and on wood, can be read there
	var kit: Array = [Kit.TEXT, Kit.DIM, Kit.DIM_HC, Kit.ACCENT, Kit.GOOD, Kit.BAD, Kit.MP_BLUE, Kit.GOOD_CB, Kit.BAD_CB, Kit.good_muted()]
	for c in kit:
		ok(UiSkin.contrast(Kit.ink(c), UiSkin.pal("parch")) >= 4.5, "%s reads on parchment as %s" % [c.to_html(false), Kit.ink(c).to_html(false)])
		ok(UiSkin.contrast(Kit.on_wood(c), UiSkin.pal("wood")) >= 4.5, "%s reads on wood" % c.to_html(false))
	ok(Kit.ink(Kit.TEXT) == UiSkin.pal("ink"), "the kit's light text becomes ink on parchment")
	ok(UiSkin.contrast(Kit.ink(Color("#ffe0a0")), UiSkin.pal("parch")) >= 4.5, "a colour the map does not know is darkened until it reads")
	ok(Kit.quiet_bb("hush", true) != Kit.quiet_bb("hush"), "quiet BBCode has a parchment form")
	ok(Kit.quiet_bb("hush") == "[color=#%s]hush[/color]" % Kit.dim().to_html(false), "and the old form is as it was")


func test_variants() -> void:
	ok(UiSkin.variant() == "standard", "the standard palette is used with the option off")
	var plain := UiSkin.panel_tex(200, 100)
	var ink_std := UiSkin.pal("ink")
	UiSettings.set_access("high_contrast", true)
	ok(UiSkin.variant() == "high_contrast", "high contrast picks its palette")
	ok(UiSkin.pal("parch") == Color("#ffffff") and UiSkin.pal("ink") == Color("#000000") and UiSkin.pal("ink") != ink_std, "white panels and black ink")
	var hc := UiSkin.panel_tex(200, 100)
	ok(hc != plain and hc.get_image().get_pixel(0, 0) == UiSkin.pal("ink") and hc.get_image().get_pixel(10, 10) != plain.get_image().get_pixel(10, 10), "the high-contrast panel is another picture")
	ok(UiSkin.contrast(Kit.ink(Kit.DIM_HC), UiSkin.pal("parch")) >= 10.0, "quiet text on a white panel is strong")
	ok(UiSkin.bar_tex(200, 22, 0.5, "hp") != UiSkin.bar_tex(200, 22, 0.5, "mp"), "the bars keep their own colours")
	UiSettings.set_access("high_contrast", false)
	ok(UiSkin.panel_tex(200, 100) == plain, "and the standard picture is back, and the same one, with it off")


func _map() -> Node:
	var app: Node = GameApp.new()
	root.add_child(app)
	await _frames(3)
	app.closed_badly = false
	app.new_game("Tess", "warrior", "faetouched", 7)
	await _frames(2)
	app.show_sandbox()
	await _frames(3)
	return app


func _pane_of(map: Node, script: Script) -> Control:
	for c in map.get_children():
		if c.get_script() == script and not c.is_queued_for_deletion():
			return c
	return null


func _face(pane: Control) -> PanelContainer:
	for c in pane.get_children():
		if c is PanelContainer:
			return c
	return null


func _all(n: Node, out: Array) -> Array:
	out.append(n)
	for c in n.get_children():
		_all(c, out)
	return out


func _inks_read(pane: Control, bg: Color) -> bool:
	for n in _all(pane, []):
		if n is Label and str(n.text) != "" and n.visible and not UiSkin.in_dark_box(n, pane):
			var c: Color = n.get_theme_color("font_color")
			if UiSkin.contrast(c, bg) < 4.5:
				print("   unreadable: '%s' %s" % [n.text, c.to_html(false)])
				return false
	return true


func test_panes() -> void:
	root.size = Vector2i(1280, 720)
	UiSettings.scale = 1.0
	UiSettings.apply(root)
	await _frames(2)
	var app := await _map()
	var map: Node = app.current
	var status := _pane_of(map, StatusPane)
	var mini := _pane_of(map, MinimapPane)
	ok(status != null and UiSkin.active(status), "the status pane wears the skin on a wide window with a mouse")
	ok(status != null and _face(status).get_theme_stylebox("panel") == UiSkin.panel_box(), "its face is the parchment panel")
	ok(mini != null and _face(mini).get_theme_stylebox("panel") == UiSkin.frame_box(), "the minimap's face is the wooden frame")
	ok(status != null and status.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "drawn with no smoothing")
	var has_shadow := false
	for c in status.get_children():
		if c is Panel:
			has_shadow = true
	ok(has_shadow and status.get_child(0) is Panel and status.get_child(0).mouse_filter == Control.MOUSE_FILTER_IGNORE, "a shadow behind it that the mouse passes through")
	var ribbons := 0
	for n in _all(status, []):
		if n is PanelContainer and n.get_theme_stylebox("panel") == UiSkin.ribbon_box():
			ribbons += 1
	ok(ribbons == 1, "the title is a ribbon")
	var bars := 0
	for n in _all(status, []):
		if n is ProgressBar and n.has_meta("skin_bar"):
			bars += 1
	ok(bars == 3, "health, mana and carrying are segmented bars: %d" % bars)
	ok(_inks_read(status, UiSkin.pal("parch")), "every label on the status pane reads on parchment")
	ok(_inks_read(mini, UiSkin.pal("wood")), "and on the minimap's wood")
	# a panel that is not one of the kit's own: its labels and buttons are dressed as they are added
	map._open_popup(HousePanel)
	await _frames(3)
	var house := _pane_of(map, HousePanel)
	ok(house != null and UiSkin.active(house) and _inks_read(house, UiSkin.pal("parch")), "a panel opened as a pane reads on parchment")
	# BBCode colours in a rich label's text are made to read, whenever the text is set
	var rich := Kit.rich()
	house.add_child(rich)
	rich.text = "plain [color=#8d88a0]quiet[/color] and [color=#6fcf6f]good[/color]"
	await _frames(4)
	ok(rich.text.contains("[color=#" + UiSkin.pal("ink_dim").to_html(false) + "]") and rich.text.contains(UiSkin.pal("ink_good").to_html(false)), "quiet and good BBCode become inks on parchment: %s" % rich.text)
	ok(rich.get_theme_color("default_color") == UiSkin.pal("ink"), "and its own text is ink")
	rich.queue_free()
	# the character and the pack
	map._open_figure()
	map._open_pack("")
	await _frames(3)
	var fig := _pane_of(map, FigurePane)
	var pack := _pane_of(map, PackPane)
	ok(fig != null and pack != null, "the figure and pack panes open")
	var slots := 0
	var inset := 0
	for n in _all(pack, []):
		if n is ItemSlot:
			slots += 1
			if n.get_theme_stylebox("normal") == UiSkin.inset_box(false) and n.get_theme_stylebox("hover") == UiSkin.inset_box(true):
				inset += 1
	ok(slots >= 24 and inset == slots, "every square of the pack is an inset slot, gold when pointed at: %d of %d" % [inset, slots])
	var fslots := 0
	for n in _all(fig, []):
		if n is ItemSlot and n.get_theme_stylebox("normal") == UiSkin.inset_box(false):
			fslots += 1
	ok(fslots >= 3, "and so is each place for gear on the character")
	ok(_inks_read(fig, UiSkin.pal("parch")) and _inks_read(pack, UiSkin.pal("parch")), "their text reads on parchment")
	# the high-contrast variant reaches a pane opened after it is chosen
	UiSettings.set_access("high_contrast", true)
	house.queue_free()
	await _frames(2)
	map._open_popup(HousePanel)
	await _frames(3)
	var panes: Array = []
	for c in map.get_children():
		if c.get_script() == HousePanel and not c.is_queued_for_deletion():
			panes.append(c)
	ok(_face(panes[0]).get_theme_stylebox("panel").texture == UiSkin.panel_box().texture and UiSkin.pal("parch") == Color("#ffffff"), "(its panel is the high-contrast one)")
	UiSettings.set_access("high_contrast", false)
	app.queue_free()
	await _frames(2)


func test_old_look() -> void:
	# a compact window (a larger scale holds fewer UI units) keeps the old dark overlay look
	root.size = Vector2i(1280, 720)
	UiSettings.set_scale(1.5)
	UiSettings.apply(root)
	await _frames(2)
	var app := await _map()
	var map: Node = app.current
	ok(UiSettings.compact(map), "(a window at the larger scale is compact)")
	map._open_popup(HousePanel)
	await _frames(3)
	var house := _pane_of(map, HousePanel)
	ok(house != null and not UiSkin.active(house), "a compact window does not use the skin")
	var textured := 0
	for n in _all(house, []):
		if n is PanelContainer and n.has_theme_stylebox_override("panel") and n.get_theme_stylebox("panel") is StyleBoxTexture:
			textured += 1
	ok(textured == 0, "and no parchment, ribbon or frame is drawn")
	ok(Kit.dim() == Kit.DIM and Kit.TEXT == Color("#e8e4f0"), "the kit's colours are what they were")
	app.queue_free()
	await _frames(2)
	UiSettings.set_scale(1.0)
	UiSettings.apply(root)
	await _frames(2)
	# a touch screen too, on a wide window
	UiSettings.force_touch = 1
	var app2 := await _map()
	var map2: Node = app2.current
	map2._open_popup(HousePanel)
	await _frames(3)
	var h2 := _pane_of(map2, HousePanel)
	ok(h2 != null and not UiSkin.active(h2), "a touch screen does not use the skin")
	var skinned := 0
	for n in _all(map2, []):
		if (n is PanelContainer and n.has_theme_stylebox_override("panel") and n.get_theme_stylebox("panel") is StyleBoxTexture) or n.has_meta("skin_bar"):
			skinned += 1
	ok(skinned == 0, "nothing on a touch screen is dressed in the skin: %d" % skinned)
	var plain: Control = HousePanel.new()   # a panel that did not ask to be a pane
	plain.dynasty = GameDynasty.new_game(3, "A", "warrior", "faetouched", "human")
	root.add_child(plain)
	await _frames(2)
	ok(not UiSkin.active(plain), "a panel that is not a pane is never skinned")
	UiSettings.force_touch = -1
	app2.queue_free()
	plain.queue_free()
	await _frames(2)
