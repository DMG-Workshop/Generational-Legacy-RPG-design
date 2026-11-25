## The interface skin on the big management panels (PanelSkin, FamilyTreeView; docs/ART_DIRECTION.md): the new pieces (raised button,
## wooden tab) and palette (slot text), rows as inset slots with a coin price, a disabled row's reason in readable ink, wooden tabs
## with the open one lit, the family tree drawn as cards, the high-contrast variant, and the old look kept on a compact window.
## Run: godot --headless --path . -s res://tests/test_game_skin_panels.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const UiSkin := preload("res://ui/play/ui_skin.gd")
const Kit := preload("res://ui/play/ui_kit.gd")
const HousePanel := preload("res://ui/play/house_panel.gd")
const ChroniclePanel := preload("res://ui/play/chronicle_panel.gd")
const ShopPanel := preload("res://ui/play/shop_panel.gd")
const FamilyTreeView := preload("res://ui/play/family_tree_view.gd")

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
	UiSettings.path = "user://test_skin_panels.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	GameDynasty.save_path = "user://test_skin_panels_save.json"
	UiSettings.scale = 1.0
	test_pieces()
	await test_skinned()
	await test_high_contrast()
	await test_old_look()
	DirAccess.remove_absolute(UiSettings.path)
	print("skin panels tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func test_pieces() -> void:
	ok(UiSkin.validate().is_empty(), "the skin's data is valid with the new pieces: %s" % str(UiSkin.validate()))
	for st in ["normal", "hover", "pressed", "disabled"]:
		ok(UiSkin.button_box(st) == UiSkin.button_box(st), "the %s button is made once and kept" % st)
	ok(UiSkin.button_box("normal") != UiSkin.button_box("hover") and UiSkin.tab_box("off") != UiSkin.tab_box("on"), "each state of a button and a tab is its own picture")
	var s := UiSkin.pixel()
	var t := UiSkin.tab_tex(32, 24, "on")
	ok(t.get_width() % s == 0 and t.get_height() % s == 0, "a tab is a whole multiple of the pixel")
	var bad: Dictionary = (UiSkin.data() as Dictionary).duplicate(true)
	(bad["variants"]["standard"] as Dictionary).erase("slot_dim")
	ok(not UiSkin.validate(bad).is_empty(), "a palette without the slot's quiet ink is found")
	var low: Dictionary = (UiSkin.data() as Dictionary).duplicate(true)
	low["variants"]["standard"]["slot_dim"] = "#5a4a3a"
	ok(UiSkin.validate(low).any(func(m): return str(m).contains("quiet text and a row")), "a quiet ink too dark for the slot is found")
	for v in ["standard", "high_contrast"]:
		var d: Dictionary = UiSkin.data()["variants"][v]
		ok(UiSkin.contrast(Color(d["slot_dim"]), Color(d["slot_bg"])) >= 4.5 and UiSkin.contrast(Color(d["slot_bad"]), Color(d["slot_bg"])) >= 4.5, "slot text reads on the slot in %s" % v)


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


func _all(n: Node, out: Array) -> Array:
	out.append(n)
	for c in n.get_children():
		_all(c, out)
	return out


func _rows(p: Node) -> Array:
	return _all(p, []).filter(func(n): return n is PanelContainer and n.has_meta("skin_row"))


## Whether every label and rich label in the slot rows reads on the slot (buttons keep their own keys).
func _slot_reads(p: Node) -> bool:
	var bg := UiSkin.pal("slot_bg")
	for row in _rows(p):
		for n in _all(row, []):
			if n is BaseButton:
				continue
			if n is Label and str(n.text) != "" and UiSkin.contrast(n.get_theme_color("font_color"), bg) < 4.5:
				print("   unreadable: '%s' %s" % [n.text, n.get_theme_color("font_color").to_html(false)])
				return false
	return true


func test_skinned() -> void:
	root.size = Vector2i(1280, 720)
	UiSettings.scale = 1.0
	UiSettings.apply(root)
	await _frames(2)
	var app := await _map()
	var map: Node = app.current
	var d: GameDynasty = app.dynasty
	# the house: a slot per track, a coin and a segmented level bar in each, a key to build
	d.heir.gold = 5000
	map._open_popup(HousePanel)
	await _frames(3)
	var house := _pane_of(map, HousePanel)
	ok(house != null and UiSkin.active(house), "the house opens as a skinned pane")
	var rows := _rows(house)
	ok(rows.size() == GameHouse.TRACKS.size(), "each track is an inset slot: %d" % rows.size())
	ok(rows.all(func(r): return r.get_theme_stylebox("panel").texture == UiSkin.inset_box(false).texture), "drawn with the inset picture")
	var coins := _all(house, []).filter(func(n): return n is TextureRect and n.texture == UiSkin.icon_tex("coin"))
	ok(coins.size() >= rows.size(), "a gold coin marks each price")
	var bars := _all(house, []).filter(func(n): return n is ProgressBar and n.has_meta("skin_bar"))
	ok(bars.size() == rows.size(), "the level is a segmented bar")
	var builds := _all(house, []).filter(func(n): return n is Button and str(n.text).begins_with("Build"))
	ok(not builds.is_empty() and builds.all(func(b): return b.get_theme_stylebox("normal") == UiSkin.button_box("normal")), "Build is a raised parchment key")
	ok(_slot_reads(house), "every line in the house's slots reads")
	# a house that cannot build says why in readable ink
	d.heir.gold = 0
	house._build(600.0)
	await _frames(2)
	var reasons := _all(house, []).filter(func(n): return n is Label and n.name == "Reason")
	ok(reasons.size() == rows.size(), "a track that cannot be built says why (%d)" % reasons.size())
	ok(reasons.all(func(l): return UiSkin.contrast(l.get_theme_color("font_color"), UiSkin.pal("slot_bg")) >= 4.5 and l.text != ""), "in ink that holds its contrast")
	var dis := _all(house, []).filter(func(n): return n is Button and n.disabled and str(n.text).begins_with("Build"))
	ok(not dis.is_empty() and dis.all(func(b): return b.get_theme_color("font_disabled_color") == UiSkin.pal("ink_dim") and b.custom_minimum_size.y >= UiSettings.tap_h(48.0)), "a disabled key is flat and its words stay readable, at the touch height")
	ok(_slot_reads(house), "and the whole house still reads")
	house.queue_free()
	# the chronicle: wooden tabs, the family tree as cards
	d.heir.gold = 5000
	for i in 2:
		d._die("old age")
		d.choose_heir(0)
	map._open_popup(ChroniclePanel)
	await _frames(3)
	var chron := _pane_of(map, ChroniclePanel)
	var tc: TabContainer = null
	for n in _all(chron, []):
		if n is TabContainer:
			tc = n
	ok(tc != null and tc.get_theme_stylebox("tab_selected") == UiSkin.tab_box("on") and tc.get_theme_stylebox("tab_unselected") == UiSkin.tab_box("off"), "the chronicle's tabs are wooden, the open one lit")
	ok(tc != null and tc.get_theme_color("font_selected_color") == UiSkin.pal("gold_hi") and UiSkin.contrast(tc.get_theme_color("font_unselected_color"), UiSkin.pal("wood")) >= 4.5, "with gold on the open one and readable words on the rest")
	var tree: Node = tc.get_node_or_null("Family Tree")
	ok(tree is ScrollContainer, "the family tree tab is drawn, not text")
	var view: Node = null
	for n in _all(tree, []):
		if n is VBoxContainer and n.get_script() == FamilyTreeView:
			view = n
	var heirs := 0
	for e in GameFamilyTree.tree(d)["generations"]:
		heirs += (e["heirs"] as Array).size()
	var cards := _all(tree, []).filter(func(n): return n is PanelContainer and n.get_theme_stylebox("panel") == UiSkin.panel_box() and n.has_meta("skin_face"))
	ok(view != null and cards.size() == heirs and heirs >= 3, "one parchment card per heir: %d of %d" % [cards.size(), heirs])
	var ink_ok := true
	for n in _all(tree, []):
		if n is Label and str(n.text) != "" and n.visible and UiSkin.contrast(n.get_theme_color("font_color"), UiSkin.pal("parch")) < 4.5 and not UiSkin.contrast(n.get_theme_color("font_color"), UiSkin.pal("crimson")) >= 4.5:
			ink_ok = false
	ok(ink_ok, "the cards' words read on parchment, and the names on the ribbon")
	tc.current_tab = tc.get_node("Statistics").get_index()
	await _frames(2)
	chron.queue_free()
	# the shops: wooden tabs, a slot per ware, a coin before each price
	map._open_popup(ShopPanel)
	await _frames(3)
	var shop := _pane_of(map, ShopPanel)
	ok(shop != null and UiSkin.active(shop), "the shops open as a skinned pane")
	var srows := _rows(shop)
	ok(srows.size() > 3, "the wares are slots: %d" % srows.size())
	var tabs := _all(shop, []).filter(func(n): return n is Button and n.toggle_mode)
	ok(not tabs.is_empty() and tabs.all(func(b): return b.get_theme_stylebox("pressed") == UiSkin.tab_box("on")), "the shops' tabs are wooden")
	ok(_all(shop, []).any(func(n): return n is TextureRect and n.texture == UiSkin.icon_tex("coin")), "prices carry a coin")
	ok(_slot_reads(shop), "every ware reads on its slot")
	var rich_ok := true
	for row in srows:
		for n in _all(row, []):
			if n is RichTextLabel and UiSkin.contrast(n.get_theme_color("default_color"), UiSkin.pal("slot_bg")) < 4.5:
				rich_ok = false
	ok(rich_ok, "and so does each effect text")
	shop.queue_free()
	app.queue_free()
	await _frames(2)


func test_high_contrast() -> void:
	UiSettings.set_access("high_contrast", true)
	var app := await _map()
	var map: Node = app.current
	map._open_popup(HousePanel)
	map._open_popup(ShopPanel)
	await _frames(3)
	var house := _pane_of(map, HousePanel)
	var shop := _pane_of(map, ShopPanel)
	ok(_rows(house).size() > 0 and _slot_reads(house) and _slot_reads(shop), "in high contrast the slots' words read")
	ok(UiSkin.contrast(UiSkin.pal("ink_dim"), UiSkin.pal("parch_hi")) >= 10.0, "and a disabled key's words are strong")
	app.queue_free()
	await _frames(2)
	UiSettings.set_access("high_contrast", false)


func test_old_look() -> void:
	UiSettings.set_scale(1.5)
	UiSettings.apply(root)
	await _frames(2)
	var app := await _map()
	var map: Node = app.current
	ok(UiSettings.compact(map), "(a window at the larger scale is compact)")
	map._open_popup(HousePanel)
	map._open_popup(ChroniclePanel)
	await _frames(3)
	var house := _pane_of(map, HousePanel)
	var chron := _pane_of(map, ChroniclePanel)
	ok(_rows(house).is_empty() and _all(house, []).all(func(n): return not (n is Button) or n.get_theme_stylebox("normal") != UiSkin.button_box("normal")), "a compact window has no slots and no parchment keys")
	var tree := chron.find_child("Family Tree", true, false)
	ok(tree is RichTextLabel, "and the family tree stays the text it was")
	app.queue_free()
	await _frames(2)
	UiSettings.set_scale(1.0)
	UiSettings.apply(root)
