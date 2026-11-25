## The interface skin on the workshop, heirlooms, trials and looks panels (PanelSkin; docs/ART_DIRECTION.md): the workshop's wooden tabs,
## slot rows and coin prices, a shut key's reason as readable text, the heirlooms' slots with a level bar and a coin, the trials as slots with
## the hours as a segmented bar, the looks panel's wooden tabs and slots with the shirt colours kept, the high-contrast variant, and the
## old look kept on a compact window.
## Run: godot --headless --path . -s res://tests/test_game_skin_overlays_a.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const UiSkin := preload("res://ui/play/ui_skin.gd")
const PanelSkin := preload("res://ui/play/panel_skin.gd")
const SpriteArt := preload("res://ui/play/sprite_art.gd")
const HousePanel := preload("res://ui/play/house_panel.gd")
const CraftPanel := preload("res://ui/play/craft_panel.gd")
const HeirloomPanel := preload("res://ui/play/heirloom_panel.gd")
const TrialsPanel := preload("res://ui/play/trials_panel.gd")
const LooksPanel := preload("res://ui/play/looks_panel.gd")

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
	UiSettings.path = "user://test_skin_overlays_a.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	GameDynasty.save_path = "user://test_skin_overlays_a_save.json"
	UiSettings.scale = 1.0
	test_helpers()
	await test_skinned()
	await test_high_contrast()
	await test_old_look()
	DirAccess.remove_absolute(UiSettings.path)
	print("skin overlays a tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


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


func _all(n: Node, out: Array) -> Array:
	out.append(n)
	for c in n.get_children():
		_all(c, out)
	return out


func _rows(p: Node) -> Array:
	return _all(p, []).filter(func(n): return n is PanelContainer and n.has_meta("skin_row"))


func _pane_of(map: Node, script: Script) -> Control:
	for c in map.get_children():
		if c.get_script() == script and not c.is_queued_for_deletion():
			return c
	return null


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


func _coins(p: Node) -> Array:
	return _all(p, []).filter(func(n): return n is TextureRect and n.texture == UiSkin.icon_tex("coin"))


func _tabs_of(p: Node) -> TabContainer:
	for n in _all(p, []):
		if n is TabContainer:
			return n
	return null


func test_helpers() -> void:
	ok(UiSkin.validate().is_empty(), "the skin's data is valid: %s" % str(UiSkin.validate()))
	var plain := Control.new()
	var h: Control = PanelSkin.heading(plain, "Make")
	ok(h is Label and (h as Label).text == "Make", "unskinned, a heading is the kit's gold label")
	h.free()
	var r := PanelSkin.reason(plain, "Not yet.")
	ok(r.text == "Not yet." and r.autowrap_mode != TextServer.AUTOWRAP_OFF, "a reason is wrapped text")
	r.free()
	plain.free()


func _stock(d: GameDynasty) -> void:
	d.heir.gold = 5000
	GameCraft.add_material(d, "iron", 6)
	d.heir.inventory.append("steel_sword")
	d.heirlooms.append({"name": "Wolfsbane", "boss": "the Wolf King", "gen": 1})
	d.heirlooms.append({"name": "Ashen Crown", "boss": "the Ash Queen", "gen": 1, "level": 1, "worked_gen": 1, "smiths": ["Tess"]})


func test_skinned() -> void:
	root.size = Vector2i(1280, 720)
	UiSettings.scale = 1.0
	UiSettings.apply(root)
	await _frames(2)
	var app := await _map()
	var map: Node = app.current
	var d: GameDynasty = app.dynasty
	_stock(d)
	# opened from the house, the workshop, heirlooms and trials are panes of their own
	map._open_popup(HousePanel)
	await _frames(3)
	var house := _pane_of(map, HousePanel)
	house._workshop()
	house._heirlooms()
	house._trials()
	await _frames(4)
	var shop := _pane_of(map, CraftPanel)
	var looms := _pane_of(map, HeirloomPanel)
	var trials := _pane_of(map, TrialsPanel)
	ok(shop != null and UiSkin.active(shop) and looms != null and UiSkin.active(looms) and trials != null and UiSkin.active(trials), "opened over the house they are skinned panes")
	# the workshop: wooden tabs, slots, a coin price on the key
	var tc := _tabs_of(shop)
	ok(tc != null and tc.get_tab_count() >= 3 and tc.get_theme_stylebox("tab_selected") == UiSkin.tab_box("on"), "the workshop's sections are wooden tabs, the open one lit")
	ok(_rows(shop).size() >= 2, "its lines sit in inset slots: %d" % _rows(shop).size())
	ok(not _coins(shop).is_empty(), "the price of making a piece carries a coin")
	var make := shop.find_child("MakeButton", true, false) as Button
	ok(make != null and make.get_theme_stylebox("normal") == UiSkin.button_box("normal"), "Make it is a raised key")
	ok(shop.find_child("FormPick", true, false) is OptionButton, "the form is still a dropdown")
	ok(_slot_reads(shop), "every workshop line reads on its slot")
	tc.current_tab = 1
	await _frames(2)
	var brews := shop.find_children("Brew", "Button", true, false)
	ok(not brews.is_empty() and brews.all(func(b): return b.disabled) and shop.find_children("*", "Label", true, false).any(func(l): return str(l.text).begins_with("Not enough")), "a brew that cannot be made says why, as text")
	ok(_slot_reads(shop), "the brew lines read too")
	shop._say("Test")
	await _frames(2)
	var tc2 := _tabs_of(shop)
	ok(tc2 != null and tc2.current_tab == 1, "a rebuild keeps the tab that was open")
	# the heirlooms
	ok(_rows(looms).size() == 2, "each heirloom is a slot: %d" % _rows(looms).size())
	var bars := _all(looms, []).filter(func(n): return n is ProgressBar and n.has_meta("skin_bar"))
	ok(bars.size() == 2, "its level is a segmented bar")
	ok(_coins(looms).size() >= 2 and _slot_reads(looms), "a coin marks the price, and every line reads")
	d.heir.gold = 0
	looms._build()
	await _frames(2)
	var reasons := _all(looms, []).filter(func(n): return n is Label and n.name == "Reason" and str(n.text) != "")
	ok(not reasons.is_empty() and reasons.all(func(l): return UiSkin.contrast(l.get_theme_color("font_color"), UiSkin.pal("slot_bg")) >= 4.5), "a heirloom that cannot be reworked says why in readable ink")
	var dis := _all(looms, []).filter(func(n): return n is Button and n.disabled and str(n.text).begins_with("Rework"))
	ok(not dis.is_empty() and dis.all(func(b): return b.get_theme_color("font_disabled_color") == UiSkin.pal("ink_dim")), "and its key is flat with readable words")
	d.heir.gold = 5000
	# the trials
	var listed := GameTrials.listing(d).size()
	ok(_rows(trials).size() == listed and listed > 0, "each trial is a slot: %d" % _rows(trials).size())
	ok(_slot_reads(trials), "every trial line reads on its slot")
	ok(_all(trials, []).filter(func(n): return n is HSeparator).is_empty(), "no rule between rows: the slots part them")
	var frames := trials.find_children("Master", "PanelContainer", true, false)
	ok(not frames.is_empty() and frames.all(func(f): return f.get_theme_stylebox("panel") == UiSkin.inset_box(false)), "the master's portrait is in an inset frame")
	# the looks
	var looks: Control = LooksPanel.new()
	looks.dynasty = d
	looks.on_change = func(): pass
	looks.set_meta("pane", "looks_panel")
	map.add_child(looks)
	await _frames(3)
	var tabs := _all(looks, []).filter(func(n): return n is Button and n.toggle_mode)
	ok(tabs.size() == 1 + d.party.members.size() and tabs.all(func(b): return b.get_theme_stylebox("pressed") == UiSkin.tab_box("on")), "who is chosen: wooden tabs")
	ok(not tabs.is_empty() and tabs[0].button_pressed, "the one chosen is lit")
	var sw := _all(looks, []).filter(func(n): return n is Button and n.has_meta("shirt"))
	ok(sw.size() == SpriteArt.shirts().size() and sw.all(func(b): return b.get_theme_stylebox("normal") != UiSkin.button_box("normal")), "the shirt colours keep their own colours")
	ok(_rows(looks).size() == 2 and _slot_reads(looks), "the figure and the swatches sit in slots that read")
	ok(looks.find_child("Reason", true, false) != null, "Random, shut, says why as text")
	looks.queue_free()
	house.queue_free()
	shop.queue_free()
	looms.queue_free()
	trials.queue_free()
	app.queue_free()
	await _frames(2)


func test_high_contrast() -> void:
	UiSettings.set_access("high_contrast", true)
	var app := await _map()
	var map: Node = app.current
	_stock(app.dynasty)
	map._open_popup(CraftPanel)
	map._open_popup(HeirloomPanel)
	map._open_popup(TrialsPanel)
	await _frames(3)
	for s in [CraftPanel, HeirloomPanel, TrialsPanel]:
		var p := _pane_of(map, s)
		ok(p != null and _rows(p).size() > 0 and _slot_reads(p), "in high contrast the slots' words read (%s)" % str(s.resource_path.get_file()))
	app.queue_free()
	await _frames(2)
	UiSettings.set_access("high_contrast", false)


func test_old_look() -> void:
	UiSettings.set_scale(1.5)
	UiSettings.apply(root)
	await _frames(2)
	var app := await _map()
	var map: Node = app.current
	_stock(app.dynasty)
	ok(UiSettings.compact(map), "(a window at the larger scale is compact)")
	map._open_popup(CraftPanel)
	map._open_popup(HeirloomPanel)
	map._open_popup(TrialsPanel)
	await _frames(3)
	for s in [CraftPanel, HeirloomPanel, TrialsPanel]:
		var p := _pane_of(map, s)
		ok(p != null and _rows(p).is_empty() and _all(p, []).all(func(n): return not (n is TabContainer) and not (n is ProgressBar and n.has_meta("skin_bar"))), "a compact window keeps the old look (%s)" % str(s.resource_path.get_file()))
	var craft := _pane_of(map, CraftPanel)
	ok(craft.find_child("MakeButton", true, false) != null and craft.find_child("FormPick", true, false) != null, "and the workshop is the one long list it was")
	app.queue_free()
	await _frames(2)
	UiSettings.set_scale(1.0)
	UiSettings.apply(root)
