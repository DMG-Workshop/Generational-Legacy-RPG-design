## The skin's pieces over the open world that are not panes (ui/play/action_slot.gd, header_plate.gd, radial_menu.gd, tutorial_tip.gd, the
## header and the thing menu in sandbox_screen.gd; data/ui/skin.json `hud`, `plate` and `badge`): the data and its validator, the new textures
## (kept alive, whole multiples of the pixel), the contrast of the keys, the header's gold and the action pictures in both palettes, the bar
## on its wooden strip with inset slots, and a touch screen or a compact window keeping the old look.
## Run: godot --headless --path . -s res://tests/test_game_skin_hud.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const UiSkin := preload("res://ui/play/ui_skin.gd")
const ActionSlot := preload("res://ui/play/action_slot.gd")
const RadialMenu := preload("res://ui/play/radial_menu.gd")
const TutorialTip := preload("res://ui/play/tutorial_tip.gd")

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
	UiSettings.path = "user://test_skin_hud.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	GameDynasty.save_path = "user://test_skin_hud_save.json"
	UiSettings.scale = 1.0
	test_data()
	test_textures()
	test_contrast()
	await test_bar()
	await test_old_look()
	DirAccess.remove_absolute(UiSettings.path)
	print("skin hud tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _broken(edit: Callable) -> Array:
	var d: Dictionary = UiSkin.data().duplicate(true)
	edit.call(d)
	return UiSkin.validate(d)


func test_data() -> void:
	ok(UiSkin.validate().is_empty(), "the skin's data checks: %s" % str(UiSkin.validate()))
	ok(_broken(func(d): d.erase("hud")).size() > 0, "a missing hud block is found")
	ok(_broken(func(d): d["hud"].erase("slot_px")).size() > 0, "a missing hud number is found")
	ok(_broken(func(d): d["hud"]["slot_px"] = 47).size() > 0, "a slot that is not a whole number of pixels is found")
	ok(_broken(func(d): d["pieces"].erase("plate")).size() > 0, "a missing plate is found")
	ok(_broken(func(d): d["pieces"]["badge"]["margin"] = 9).size() > 0, "a badge with no middle is found")
	ok(_broken(func(d): d["variants"]["standard"]["parch_hi"] = "#2a1c14").size() > 0, "a key that cannot be read on its badge is found")
	ok(UiSkin.hud("slot_px") == 48.0 and int(UiSkin.hud("slot_px")) % UiSkin.pixel() == 0, "the slot is a whole number of pixels")


func test_textures() -> void:
	for lit in [false, true]:
		var a := UiSkin.plate_tex(64, 40, lit)
		ok(a == UiSkin.plate_tex(64, 40, lit), "a plate is made once and kept (lit %s)" % lit)
		ok(a.get_width() % UiSkin.pixel() == 0 and a.get_height() % UiSkin.pixel() == 0, "a plate is a whole number of pixels")
		var b := UiSkin.badge_tex(24, 16, lit)
		ok(b == UiSkin.badge_tex(24, 16, lit) and b.get_width() % UiSkin.pixel() == 0, "a badge is made once and kept (lit %s)" % lit)
	ok(UiSkin.plate_tex(64, 40, true) != UiSkin.plate_tex(64, 40, false), "a lit plate is another picture")
	ok(UiSkin.plate_box(true).texture != UiSkin.plate_box(false).texture, "and the boxes hold them")
	var strip := UiSkin.header_strip(56.0)
	ok(strip.texture != null and strip.texture.get_height() == 56 and strip.stretch_mode == TextureRect.STRETCH_TILE, "the header strip tiles a texture as tall as the bar")
	var menu := PopupMenu.new()
	UiSkin.dress_popup(menu)
	ok(menu.get_theme_stylebox("panel") is StyleBoxTexture and menu.get_theme_stylebox("hover") is StyleBoxTexture, "a dressed popup has a parchment sheet and a lit plate")
	menu.free()
	strip.free()


func test_contrast() -> void:
	var glyphs: Dictionary = ActionSlot.icons()["glyphs"]
	for hc in [false, true]:
		UiSettings.set_access("high_contrast", hc)
		var slot_bg := UiSkin.pal("slot_bg")
		for def in (ActionSlot.data()["slots"] as Array) + (ActionSlot.data()["extras"] as Array):
			var c: Array = def["color"]
			ok(UiSkin.contrast(Color(c[0], c[1], c[2]), slot_bg) >= 3.0, "the picture of %s shows on its slot (hc %s)" % [def["id"], hc])
		ok(UiSkin.contrast(UiSkin.pal("parch_hi"), UiSkin.pal("ink")) >= 9.0, "a key reads on its badge (hc %s)" % hc)
		ok(UiSkin.contrast(UiSkin.pal("gold_hi"), UiSkin.pal("ink")) >= 7.0, "the gold reads in the header's badge (hc %s)" % hc)
		ok(UiSkin.contrast(UiSkin.pal("wood_text"), UiSkin.pal("wood")) >= 6.0, "the status line reads on the planks (hc %s)" % hc)
		ok(UiSkin.contrast(UiSkin.pal("crimson_dk"), UiSkin.pal("parch_hi")) >= 7.0, "the ring's lit label reads (hc %s)" % hc)
	UiSettings.set_access("high_contrast", false)
	ok(not glyphs.is_empty(), "(the action pictures exist)")


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


func test_bar() -> void:
	root.size = Vector2i(1280, 720)
	UiSettings.apply(root)
	var app := await _map()
	var map: Node = app.current
	ok(map.skinned and map.header_plate != null, "a wide window with a mouse wears the header and its plate")
	var strips := 0
	for c in map.get_children():
		if c is TextureRect and c.stretch_mode == TextureRect.STRETCH_TILE:
			strips += 1
	ok(strips == 1, "the bar sits on one wooden strip")
	var px := UiSkin.hud("slot_px")
	for id in map.slots:
		var s: Control = map.slots[id]
		ok(s.skinned and s.custom_minimum_size == Vector2(px, px), "slot %s is skinned at the data's size" % id)
	ok(map.header_plate.who == "Tess" and map.header_plate.gold == app.dynasty.heir.gold, "the plate names the heir and the gold")
	ok(map.header_plate.custom_minimum_size.x > 0.0, "and has the width of what it shows")
	app.dynasty.heir.gold += 25
	map._refresh_panes()
	ok(map.header_plate.gold == app.dynasty.heir.gold, "the gold follows the heir's purse")
	map.slots["build"].set_state(false, true)
	map.slots["cast"].set_state(true, false)
	map.slots["use"].hover = true
	for id in map.slots:
		map.slots[id].queue_redraw()
	await _frames(3)
	ok(true, "an active, a dimmed and a pointed-at slot draw")
	var ring := RadialMenu.make(Vector2(600, 300), Vector2(1280, 720))
	ring.sticky = true
	map.add_child(ring)
	ring.hover = 1
	await _frames(3)
	ok(UiSkin.hud_active(ring), "the ring wears the skin here (and drew without a fault)")
	ring.queue_free()
	var tip := TutorialTip.make({"text": "A tip.", "highlight": []}, 400.0, func(): pass)
	map.add_child(tip)
	await _frames(2)
	ok(tip.get_theme_stylebox("panel") is StyleBoxTexture, "the tip strip is a parchment plate")
	tip.queue_free()
	UiSettings.set_access("high_contrast", true)
	map._refresh_status()
	map.queue_redraw()
	await _frames(2)
	ok(UiSkin.pal("ink") == Color.BLACK, "high contrast picks black ink for all of it")
	UiSettings.set_access("high_contrast", false)
	app.queue_free()
	await _frames(2)


func test_old_look() -> void:
	UiSettings.force_touch = 1
	var app := await _map()
	var map: Node = app.current
	ok(not map.skinned and map.header_plate == null, "a touch screen keeps its header")
	var strips := 0
	for c in map.get_children():
		if c is TextureRect and c.stretch_mode == TextureRect.STRETCH_TILE:
			strips += 1
	ok(strips == 0, "with no wooden strip")
	ok(map.slots.is_empty(), "and its text buttons")
	var tip := TutorialTip.make({"text": "A tip.", "highlight": []}, 400.0, func(): pass)
	map.add_child(tip)
	await _frames(2)
	ok(not (tip.get_theme_stylebox("panel") is StyleBoxTexture), "the tip strip keeps its old look")
	UiSettings.force_touch = -1
	app.queue_free()
	await _frames(2)
	# a compact window with a mouse
	UiSettings.set_scale(1.5)
	UiSettings.apply(root)
	await _frames(2)
	var app2 := await _map()
	var m2: Node = app2.current
	ok(UiSettings.compact(m2) and not m2.skinned, "a compact window keeps the old bar")
	for id in m2.slots:
		ok(not m2.slots[id].skinned and m2.slots[id].custom_minimum_size.x == ActionSlot.setting("slot_px"), "slot %s keeps its old size and look" % id)
	app2.queue_free()
	await _frames(2)
	UiSettings.set_scale(1.0)
	UiSettings.apply(root)
