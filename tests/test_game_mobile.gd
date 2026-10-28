## Phones and tablets: hold-for-details on touch screens (a hold shows the tooltip and is not a
## click, a tap still clicks, a drag scrolls), no engine tooltip or hover preview from a finger's
## emulated mouse while the mouse keeps both, every tooltip and hover preview in the shipped UI
## reachable that way, the text-size and touch-layout settings (saved apart from the dynasty, old
## files read as Auto), no Quit on mobile, every screen at every text size on phone, tablet and
## small windows (nothing off the safe area or cut off, touch-sized buttons and tabs), saving on
## pause, the Android back button, the safe area and the export presets.
## Run: godot --headless --path . -s res://tests/test_game_mobile.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const TouchHint := preload("res://ui/play/touch_hint.gd")
const Kit := preload("res://ui/play/ui_kit.gd")
const ShopPanel := preload("res://ui/play/shop_panel.gd")
const TavernPanel := preload("res://ui/play/tavern_panel.gd")
const BoardPanel := preload("res://ui/play/board_panel.gd")
const MapPanel := preload("res://ui/play/map_panel.gd")
const FeatsPanel := preload("res://ui/play/feats_panel.gd")
const SkillTreePanel := preload("res://ui/play/skill_tree_panel.gd")
const EventPanel := preload("res://ui/play/event_panel.gd")
const LootPanel := preload("res://ui/play/loot_panel.gd")
const MenuPanel := preload("res://ui/play/menu_panel.gd")
const BattleView := preload("res://ui/play/battle_view.gd")
const LifeScreen := preload("res://ui/play/life_screen.gd")
const Cooldown := preload("res://ui/play/autopilot_cooldown.gd")
const ChroniclePanel := preload("res://ui/play/chronicle_panel.gd")
const EndingScreen := preload("res://ui/play/ending_screen.gd")
const DIR := "user://test_mobile/"

var checks := 0
var fails := 0
var app: Node
var d: GameDynasty
var covered := {}     # script file -> tooltips proven reachable by a hold
var clock_t := 1.7e9  # the fake clock the autopilot cooldown tests read
var visited := {}     # script files whose screens were built and probed


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	GameDynasty.save_path = DIR + "save.json"
	UiSettings.path = DIR + "settings.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	UiSettings.scale = 1.0
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	root.size = Vector2i(1280, 720)
	await _frames(2)
	app = GameApp.new()
	root.add_child(app)
	app.hints.set_process(false)   # hold time is stepped by hand
	await _frames(2)
	test_project_and_presets()
	test_settings_file()
	await test_touch_layout_setting()
	await test_hold_and_tap()
	await test_drag_scrolls()
	await test_hover_preview()
	await test_no_native_tooltip_from_touch()
	test_static_scan()
	await test_quit_button()
	await test_every_tooltip_reachable()
	await test_back_button()
	await test_pause_saves()
	await test_safe_area()
	await test_scale_layouts()
	await test_command_text_fits()
	test_cooldown_logic()
	await test_cooldown_buttons()
	await test_cooldown_timer()
	await test_cooldown_text_fits()
	await test_scale_mid_fight()
	print("mobile tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _frames(n: int = 2) -> void:
	for i in n:
		await process_frame


func _game(cls: String = "warrior", level: int = 32, seed_val: int = 77) -> void:
	app.new_game("Tess", cls, "faetouched", seed_val, "human")
	d = app.dynasty
	d.pending_event = {}
	d.heir.level = level
	d.heir.gold = 5000
	d.world.visit("kingshold")
	for id in ["bren_cask", "sister_oriel"]:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": level, "gen": 1,
			"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
		d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
			"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	d.party.rest(d)
	d.heir.full_heal()
	for id in GameFeats.ids():
		if GameFeats.requirement_block(d.heir, id) == "" and d.heir.equipped_feats.size() < GameFeats.slots(d.heir):
			d.heir.known_feats.append(id)
			d.heir.equipped_feats.append(id)
	d.heir.inventory.append_array(["nightshade_oil", "plague_vial"])
	GameDisease.infect(d.heir, "rat_plague", "corpse", 1)
	app.show_state()


# ---------------------------------------------------------------- touch input

func _win(at: Vector2) -> Vector2:
	return root.get_final_transform() * at


func _down(at: Vector2) -> void:
	var t := InputEventScreenTouch.new()
	t.position = _win(at)
	t.pressed = true
	Input.parse_input_event(t)
	await _frames(1)


func _up(at: Vector2) -> void:
	var t := InputEventScreenTouch.new()
	t.position = _win(at)
	t.pressed = false
	Input.parse_input_event(t)
	await _frames(1)


func _drag(at: Vector2, rel: Vector2) -> void:
	var t := InputEventScreenDrag.new()
	t.position = _win(at)
	t.relative = rel
	Input.parse_input_event(t)
	await _frames(1)


func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


## A finger held on `c` for `secs`, then lifted. Returns the hint text seen while it was down.
func _hold(c: Control, secs: float) -> String:
	app.hints.hide_hint()
	var at := _center(c)
	await _down(at)
	app.hints.tick(secs)
	var seen: String = app.hints.shown_text if app.hints.is_showing() else ""
	await _up(at)
	return seen


func _tap(c: Control) -> String:
	return await _hold(c, 0.1)


func _find(n: Node, prefix: String) -> BaseButton:
	if n is Button and (n as Button).is_visible_in_tree() and (n as Button).text.begins_with(prefix):
		return n
	for c in n.get_children():
		var b := _find(c, prefix)
		if b != null:
			return b
	return null


func _labels_with_tip(n: Node, out: Array) -> Array:
	if n is Control and (n as Control).is_visible_in_tree() and (n as Control).tooltip_text != "":
		out.append(n)
	for c in n.get_children():
		_labels_with_tip(c, out)
	return out


func test_project_and_presets() -> void:
	ok(ProjectSettings.get_setting("display/window/handheld/orientation") == 4, "phones hold the game in sensor landscape")
	ok(ProjectSettings.get_setting("application/config/quit_on_go_back") == false, "Android back does not quit")
	ok(ProjectSettings.get_setting("display/window/stretch/aspect") == "expand", "the layout expands to any aspect")
	ok(str(ProjectSettings.get_setting("application/config/icon")) != "", "an icon is set (export needs one)")
	var cf := ConfigFile.new()
	ok(cf.load("res://export_presets.cfg") == OK, "export presets load")
	var by_name := {}
	for s in cf.get_sections():
		if s.begins_with("preset.") and not s.ends_with(".options"):
			by_name[cf.get_value(s, "name")] = s
	ok(by_name.has("Android") and by_name.has("iOS"), "an Android and an iOS preset")
	if not (by_name.has("Android") and by_name.has("iOS")):
		return
	var a: String = by_name["Android"]
	var i: String = by_name["iOS"]
	ok(cf.get_value(a + ".options", "architectures/arm64-v8a") == true and cf.get_value(a + ".options", "architectures/armeabi-v7a") == false, "Android builds arm64-v8a only")
	ok(cf.get_value(a + ".options", "package/unique_name") == "com.dmgworkshop.generationallegacy", "Android package name")
	ok(cf.get_value(i + ".options", "application/bundle_identifier") == "com.dmgworkshop.generationallegacy", "iOS bundle id matches")
	ok(cf.get_value(i + ".options", "application/app_store_team_id") == "", "no team id committed")
	for sec in [a, i]:
		var ex: String = cf.get_value(sec, "exclude_filter")
		ok("tests/*" in ex and "docs/*" in ex, "%s leaves tests and docs out of the pack" % cf.get_value(sec, "name"))
		for k in cf.get_section_keys(sec + ".options"):
			if "password" in k or "keystore" in k or k.ends_with("_user"):
				ok(str(cf.get_value(sec + ".options", k)) == "", "%s: no secret in %s" % [cf.get_value(sec, "name"), k])
	var text := FileAccess.get_file_as_string("res://export_presets.cfg")
	ok(not ("keystore/release_password=\"" in text and not "keystore/release_password=\"\"" in text), "no release password in the presets")


func test_settings_file() -> void:
	UiSettings.force_mobile = 1
	UiSettings.scale = -1.0
	ok(is_equal_approx(UiSettings.get_scale(), 1.25), "a phone without a settings file starts at 125%")
	UiSettings.force_mobile = 0
	UiSettings.scale = -1.0
	ok(is_equal_approx(UiSettings.get_scale(), 1.0), "a desktop starts at 100%")
	ok(is_equal_approx(UiSettings.nearest(1.31), 1.25) and is_equal_approx(UiSettings.nearest(9.0), 1.5), "only listed scales")
	UiSettings.set_scale(1.5)
	ok(FileAccess.file_exists(UiSettings.path), "the setting is written to its own file")
	UiSettings.scale = -1.0
	ok(is_equal_approx(UiSettings.get_scale(), 1.5), "and read back")
	var cf := ConfigFile.new()
	cf.load(UiSettings.path)
	cf.set_value("ui", "scale", 1.37)
	cf.save(UiSettings.path)
	UiSettings.load_settings()
	ok(is_equal_approx(UiSettings.get_scale(), 1.25), "a hand-edited scale snaps to a listed one")
	var dyn := GameDynasty.new_game(3, "Ana", "mage", "faetouched", "elf")
	var saved := JSON.stringify(dyn.to_dict())
	ok(not ("ui_scale" in saved) and not ("content_scale" in saved), "the dynasty save does not carry the UI scale")
	ok(not ("touch_layout" in saved), "nor the touch layout")
	UiSettings.set_scale(1.0)


## Menu > Touch layout: Auto (phones and tablets only, so a touch-screen laptop keeps the desktop
## layout), On or Off, saved beside the text size; files from before it load as Auto.
func test_touch_layout_setting() -> void:
	var keep_touch := UiSettings.force_touch
	UiSettings.force_touch = -1
	DirAccess.remove_absolute(UiSettings.path)
	UiSettings.touch_layout = ""
	UiSettings.scale = -1.0
	ok(UiSettings.get_touch_layout() == "auto", "no settings file: the touch layout is Auto")
	UiSettings.force_mobile = 0
	UiSettings.force_touchscreen = 0
	ok(not UiSettings.touch() and not UiSettings.touch_screen(), "Auto on a desktop without a touch screen: the desktop layout")
	UiSettings.force_touchscreen = 1
	ok(not UiSettings.touch() and UiSettings.touch_screen(), "Auto on a touchscreen laptop: still the desktop layout")
	UiSettings.set_touch_layout("on")
	ok(UiSettings.touch(), "a touchscreen laptop set to On: the touch layout")
	UiSettings.set_touch_layout("auto")
	UiSettings.force_touchscreen = -1
	UiSettings.force_mobile = 1
	ok(UiSettings.touch(), "Auto on a phone: the touch layout")
	UiSettings.set_touch_layout("off")
	ok(not UiSettings.touch(), "Off: the desktop layout even on a phone")
	UiSettings.force_mobile = 0
	UiSettings.set_touch_layout("on")
	ok(UiSettings.touch(), "On: the touch layout on a desktop")
	UiSettings.touch_layout = ""
	ok(UiSettings.get_touch_layout() == "on", "the choice is read back from the file")
	UiSettings.set_scale(1.25)
	UiSettings.touch_layout = ""
	UiSettings.scale = -1.0
	ok(UiSettings.get_touch_layout() == "on" and is_equal_approx(UiSettings.get_scale(), 1.25), "the text size and the touch layout are kept side by side")
	var cf := ConfigFile.new()
	cf.load(UiSettings.path)
	ok(cf.get_value("ui", "touch_layout", "") == "on", "stored as [ui] touch_layout")
	# A file written before the setting existed: only the scale.
	var old := ConfigFile.new()
	old.set_value("ui", "scale", 1.5)
	old.save(UiSettings.path)
	UiSettings.load_settings()
	ok(UiSettings.get_touch_layout() == "auto" and is_equal_approx(UiSettings.get_scale(), 1.5), "an old settings file loads as Auto and keeps its scale")
	old.set_value("ui", "touch_layout", "sideways")
	old.save(UiSettings.path)
	UiSettings.load_settings()
	ok(UiSettings.get_touch_layout() == "auto", "an unknown value loads as Auto")
	UiSettings.set_touch_layout("bogus")
	ok(UiSettings.get_touch_layout() == "auto", "and cannot be set")
	UiSettings.set_scale(1.0)
	app.set_ui_scale(1.0)
	await _frames(2)
	# The menu offers it next to Text size; a choice lays the screens out again.
	app.show_title()
	await _frames(2)
	var m: Control = app.open_menu()
	await _frames(2)
	var texts := _texts(m, [])
	var at := texts.find("Touch layout")
	ok(at > texts.find("Text size") and texts.find("Text size") >= 0, "the menu has Touch layout under Text size")
	var auto_b := _find(m, "Auto")
	ok(auto_b != null and auto_b.get_theme_color("font_color") == Kit.ACCENT, "Auto is marked as in use")
	ok(_find(m, "On") != null and _find(m, "Off") != null, "with On and Off beside it")
	ok(auto_b != null and auto_b.size.y < float(UiSettings.setting("touch_target_px")) - 0.5, "the desktop's buttons are their designed size")
	_find(m, "On").pressed.emit()
	await _frames(3)
	ok(UiSettings.get_touch_layout() == "on" and UiSettings.touch(), "On turns the touch layout on")
	var m2: Node = app.current.get_children().back()
	ok(m2 is MenuPanel and m2 != m, "the screens are laid out again and the menu reopens")
	var on_b := _find(m2, "On")
	ok(on_b != null and on_b.get_theme_color("font_color") == Kit.ACCENT, "showing On in use")
	ok(on_b != null and on_b.size.y >= float(UiSettings.setting("touch_target_px")) - 0.5, "and its buttons are now a fingertip tall")
	ok(Kit.click() == "tap", "the help says tap")
	_find(m2, "Off").pressed.emit()
	await _frames(3)
	ok(UiSettings.get_touch_layout() == "off" and not UiSettings.touch() and Kit.click() == "click", "Off: the desktop layout and words")
	# Long-press hints work on a real touch screen whatever the layout says.
	_game()
	await _frames(3)
	var btn := _find(app.current, "Auto-battle")
	var seen := await _hold(btn, float(UiSettings.setting("hold_seconds")) + 0.05)
	ok(seen != "" and seen == btn.tooltip_text, "with the touch layout Off a hold still shows the hint")
	app.hints.hide_hint()
	UiSettings.set_touch_layout("auto")
	UiSettings.force_touch = keep_touch
	app.show_state()
	await _frames(2)


func _texts(n: Node, out: Array) -> Array:
	if n is Label and (n as Label).is_visible_in_tree():
		out.append((n as Label).text)
	for c in n.get_children():
		_texts(c, out)
	return out


## A tap on the auto-battle toggle flips it; a hold shows its tooltip and leaves it alone.
func test_hold_and_tap() -> void:
	_game()
	await _frames(3)
	var life: Control = app.current
	var btn := _find(life, "Auto-battle")
	ok(btn != null, "the auto-battle button is on the life screen")
	if btn == null:
		return
	var before := d.auto_battle
	var tip := btn.tooltip_text
	var seen := await _tap(btn)
	ok(d.auto_battle != before, "a tap clicks")
	ok(seen == "", "a tap shows no hint")
	btn = _find(app.current, "Auto-battle")
	before = d.auto_battle
	seen = await _hold(btn, float(UiSettings.setting("hold_seconds")) + 0.05)
	ok(seen != "" and seen == btn.tooltip_text, "a hold shows the button's tooltip")
	ok(d.auto_battle == before, "a hold is not a click")
	ok(app.hints.is_showing(), "the hint stays up after the finger lifts")
	app.hints.tick(float(UiSettings.setting("hint_linger_seconds")) + 0.1)
	ok(not app.hints.is_showing(), "and then goes away")
	seen = await _hold(btn, float(UiSettings.setting("hold_seconds")) - 0.2)
	ok(seen == "", "a press shorter than the hold time shows nothing")
	ok(d.auto_battle != before, "and still clicks")
	# Trait labels: the life screen's own hover-for-details.
	var traits: Array = _labels_with_tip(app.current, []).filter(func(c): return c is Label and (c as Label).text.strip_edges() == GameData.trait_name(d.heir.all_traits()[0]))
	ok(not traits.is_empty(), "a trait label with its tooltip")
	if not traits.is_empty():
		var l: Label = traits[0]
		(l.get_parent().get_parent() as ScrollContainer).ensure_control_visible(l)
		await _frames(2)
		seen = await _hold(l, 0.6)
		ok(seen == Kit.trait_tooltip(d.heir.all_traits()[0]), "holding a trait shows what it does")
	# Mouse input is left alone: a long mouse press is a click as before.
	app.hints.hide_hint()
	btn = _find(app.current, "Auto-battle")
	before = d.auto_battle
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.position = _win(_center(btn))
	mb.pressed = true
	Input.parse_input_event(mb)
	await _frames(1)
	app.hints.tick(2.0)
	ok(not app.hints.is_showing(), "a held mouse button shows no touch hint")
	mb = mb.duplicate()
	mb.pressed = false
	Input.parse_input_event(mb)
	await _frames(2)
	ok(d.auto_battle != before, "a long mouse press still clicks")
	# A second finger cancels the hold, and the click.
	app.hints.hide_hint()
	btn = _find(app.current, "Auto-battle")
	before = d.auto_battle
	await _down(_center(btn))
	var two := InputEventScreenTouch.new()
	two.index = 1
	two.pressed = true
	two.position = _win(_center(btn) + Vector2(40, 0))
	Input.parse_input_event(two)
	await _frames(1)
	app.hints.tick(1.0)
	ok(not app.hints.is_showing(), "a second finger is a pinch, not a hold")
	two.pressed = false
	Input.parse_input_event(two)
	await _up(_center(btn))
	ok(d.auto_battle == before, "a pinch on a button does not press it")
	UiSettings.force_touch = 1
	ok(Kit.click() == "tap" and Kit.hover() == "hold", "touch screens are told to tap and hold")
	UiSettings.force_touch = 0
	ok(Kit.click() == "click" and Kit.hover() == "hover", "the desktop keeps click and hover")


## A finger dragged over a list of buttons scrolls it and presses nothing.
func test_drag_scrolls() -> void:
	_game()
	d.heir.inventory.append_array(["copper_ring", "iron_sword", "oak_staff", "leather_armor"])
	app.show_state()
	await _frames(2)
	var shop: Control = ShopPanel.new()
	shop.dynasty = d
	app.current.add_child(shop)
	await _frames(4)
	var sc: ScrollContainer = shop.scroll
	var btn := _find(sc, "Buy")
	ok(btn != null, "the forge lists wares with Buy buttons")
	if btn == null:
		return
	var gold := d.heir.gold
	var at := _center(btn)
	await _down(at)
	for k in 6:
		await _drag(at + Vector2(0, -12.0 * (k + 1)), Vector2(0, -12))
	await _frames(2)
	var scrolled := sc.scroll_vertical
	await _up(at + Vector2(0, -72))
	await _frames(2)
	ok(scrolled > 0, "dragging up scrolls the wares (%d)" % scrolled)
	ok(d.heir.gold == gold, "and buys nothing")
	shop.queue_free()
	await _frames(2)


## Holding a skill in battle draws its area, as hovering does; the area goes with the hint.
func test_hover_preview() -> void:
	_game("mage", 40, 12)
	for i in 200:
		d.start_hunt("hunt_hard")
		if d.battle.enemies.size() >= 3:
			break
		d.battle = null
	d.auto_battle = false
	app.show_state()
	await _frames(4)
	var bv: Control = app.current
	bv.set_auto(false)
	await _frames(2)
	bv._open_spells()
	await _frames(3)
	var aoe := ""
	for id in d.battle.known_spells():
		if GameCombat.is_aoe(d.battle.unit_spell(-1, id)) and d.battle.can_cast(id):
			aoe = str(d.battle.unit_spell(-1, id)["name"])
	ok(aoe != "", "the mage knows an area spell")
	if aoe == "":
		return
	var spb := _find(bv.spell_list, aoe)
	app.hints.hide_hint()
	await _down(_center(spb))
	app.hints.tick(0.6)
	ok(not bv.shown.is_empty(), "holding an area spell outlines where it lands")
	ok(app.hints.shown_text == spb.tooltip_text, "and tells what it does")
	await _up(_center(spb))
	ok(bv.aiming.is_empty(), "the hold did not cast or start aiming")
	app.hints.hide_hint()
	ok(bv.shown.is_empty(), "the outline goes with the hint")
	# A tap on it starts aiming; tapping a foe aims there, again casts (aiming unchanged by touch).
	await create_timer(float(UiSettings.setting("tap_guard_ms")) / 1000.0 + 0.1).timeout   # a finger's tap waits out the guard after a panel opens
	await _tap(spb)
	ok(not bv.aiming.is_empty(), "a tap on the spell starts aiming")
	var last: int = d.battle.living_enemies().back()
	var foe: Control = bv.enemy_nodes[last]["body"]
	await _tap(foe)
	ok(bv.aim_at == last, "a tap on a foe aims there")
	ok(app.go_back() == "screen" and bv.aiming.is_empty(), "back drops the aim")
	d.battle = null


## Godot moves an emulated mouse (InputEvent.DEVICE_ID_EMULATION) with the first finger: the
## touch's mouse button enters the control under it, the pointer rests there after the lift, and a
## resting motion there (Viewport.update_mouse_cursor_state sends one after a cursor change or a
## drag) starts the engine's tooltip timer. On touch only the long-press bubble may show: no native
## tooltip and no hover preview from a tap; the mouse keeps both.
func test_no_native_tooltip_from_touch() -> void:
	_game()
	await _frames(3)
	var host: Control = app.current
	var probe := Button.new()
	probe.text = "Probe"
	probe.tooltip_text = "Probe tooltip"
	probe.position = Vector2(300, 300)
	probe.size = Vector2(160, 60)
	probe.z_index = 50
	host.add_child(probe)
	var hover := {"in": 0, "out": 0, "seen": 0, "live": false}
	var enter := func():
		hover["in"] += 1
		hover["live"] = true
	var leave := func():
		hover["out"] += 1
		hover["live"] = false
	TouchHint.on_hover(probe, enter, leave)
	probe.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.device == InputEvent.DEVICE_ID_EMULATION: hover["seen"] += 1)
	var taps := [0]
	probe.pressed.connect(func(): taps[0] += 1)
	await _frames(2)
	var at := _center(probe)
	var delay := float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec"))
	var popped: Array = []   # the engine's tooltip popups as they enter the tree: freed there and then?
	var spy := func(n: Node): if n is PopupPanel and (n as Window).theme_type_variation == &"TooltipPanel": popped.append(n.is_queued_for_deletion())
	node_added.connect(spy)
	# A plain tap: Godot's emulated mouse button (device DEVICE_ID_EMULATION) enters the probe.
	await _down(at)
	await _up(at)
	ok(hover["seen"] == 2, "the tap reached the probe as the engine's emulated mouse button (%d)" % hover["seen"])
	ok(taps[0] == 1, "a tap clicks")
	ok(root.gui_get_hovered_control() == probe, "the emulated pointer rests on what was tapped")
	ok(TouchHint.finger, "the pointer is known to be a finger's")
	ok(hover["in"] == 0, "a tap plays no hover preview")
	root.update_mouse_cursor_state()   # the engine's own resting motion
	var rest := InputEventMouseMotion.new()   # and one as an emulated mouse would send it
	rest.device = InputEvent.DEVICE_ID_EMULATION
	rest.position = _win(at)
	Input.parse_input_event(rest)
	await create_timer(delay + 0.3).timeout
	ok(_tooltips(root, []).is_empty(), "no native tooltip after a tap and a resting pointer: %s" % str(_tooltips(root, [])))
	ok(not popped.is_empty() and not popped.has(false), "the engine did pop its tooltip, and it was freed the frame it came, never drawn (%s)" % str(popped))
	ok(hover["in"] == 0, "and still no preview")
	# A resting motion while the finger is still down (a cursor change under a held finger).
	popped.clear()
	await _down(at)
	root.update_mouse_cursor_state()
	await create_timer(delay + 0.3).timeout
	ok(_tooltips(root, []).is_empty() and not popped.has(false), "no native tooltip under a held finger (%s)" % str(popped))
	await _up(at)
	taps[0] = 0
	# A finger dragged with the button held reaches the GUI (scrolling needs it), no tooltip.
	var drags := [0]
	probe.gui_input.connect(func(ev): if ev is InputEventMouseMotion and ev.device == InputEvent.DEVICE_ID_EMULATION: drags[0] += 1)
	await _down(at)
	await _drag(at + Vector2(3, 2), Vector2(3, 2))
	await _drag(at + Vector2(6, 4), Vector2(3, 2))
	ok(drags[0] >= 2, "a finger's drag still reaches the GUI as emulated motion (%d)" % drags[0])
	await create_timer(delay + 0.3).timeout
	ok(_tooltips(root, []).is_empty(), "no native tooltip while a finger rests on it")
	await _up(at + Vector2(6, 4))
	# The long press still shows its bubble and plays the preview; taking it down ends it.
	app.hints.hide_hint()
	await _down(at)
	app.hints.tick(float(UiSettings.setting("hold_seconds")) + 0.05)
	ok(app.hints.shown_text == "Probe tooltip" and hover["in"] == 1, "a hold shows the bubble and the preview")
	await _up(at)
	await create_timer(delay + 0.3).timeout
	ok(_tooltips(root, []).is_empty(), "and no native tooltip beside it")
	app.hints.hide_hint()
	ok(hover["out"] == 1, "the preview ends with the bubble")
	# The mouse: hover plays the preview and the engine's tooltip shows, as on the desktop.
	var mm := InputEventMouseMotion.new()
	mm.position = _win(at + Vector2(-200, -150))
	Input.parse_input_event(mm)
	await _frames(1)
	ok(not TouchHint.finger, "a real mouse takes the pointer back")
	ok(hover["out"] == 1, "the finger's leaving played no exit of its own")
	mm = mm.duplicate()
	mm.position = _win(at)
	Input.parse_input_event(mm)
	await _frames(1)
	ok(hover["in"] == 2, "the mouse entering plays the preview")
	await create_timer(delay + 0.3).timeout
	ok(_tooltips(root, []) == ["Probe tooltip"], "and the engine's tooltip shows for the mouse: %s" % str(_tooltips(root, [])))
	ok(popped.back() == false, "the mouse's tooltip is left alone")
	# A touch elsewhere moves the pointer off: the mouse's preview ends once, and the tooltip goes.
	await _down(at + Vector2(-200, -150))
	await _up(at + Vector2(-200, -150))
	ok(hover["out"] == 2, "a finger moving the pointer off ends the mouse's preview, once (%d)" % hover["out"])
	await _frames(2)
	ok(_tooltips(root, []).is_empty(), "the mouse's tooltip goes with it")
	# A touchscreen laptop: a finger taps the probe, then the mouse moves inside it. The engine sends
	# no mouse_entered (the probe is hovered already), yet the mouse gets its preview.
	await _tap(probe)
	ok(not hover["live"], "the tap played no preview")
	var mouse := InputEventMouseMotion.new()
	mouse.position = _win(at + Vector2(4, 2))
	Input.parse_input_event(mouse)
	await _frames(1)
	ok(not TouchHint.finger and hover["live"], "the mouse moving on what a finger tapped plays its preview")
	mouse = mouse.duplicate()
	mouse.position = _win(at + Vector2(-200, -150))
	Input.parse_input_event(mouse)
	await _frames(1)
	ok(not hover["live"] and hover["in"] - hover["out"] == 0, "and leaving ends it, once (%d in, %d out)" % [hover["in"], hover["out"]])
	# The mouse hovers the probe and a finger holds it: when the hint goes the mouse keeps its preview.
	mouse = mouse.duplicate()
	mouse.position = _win(at)
	Input.parse_input_event(mouse)
	await _frames(1)
	await _down(at)
	app.hints.tick(float(UiSettings.setting("hold_seconds")) + 0.05)
	ok(app.hints.shown_text == "Probe tooltip" and hover["live"], "a hold over the mouse's hover shows the hint")
	await _up(at)
	app.hints.hide_hint()
	ok(hover["live"], "the hint going leaves the preview of the mouse still on it")
	mouse = mouse.duplicate()
	mouse.position = _win(at + Vector2(-200, -150))
	Input.parse_input_event(mouse)
	await _frames(1)
	ok(not hover["live"], "the mouse leaving ends it")
	node_added.disconnect(spy)
	probe.queue_free()
	app.hints.hide_hint()
	await _frames(2)


## The engine's tooltip popups on screen: a PopupPanel under the control that owns the tooltip.
func _tooltips(n: Node, out: Array) -> Array:
	for c in n.get_children(true):
		if c is PopupPanel and (c as Window).visible:
			var l: Label = null
			for x in c.get_children(true):
				if x is Label:
					l = x
			out.append(l.text if l != null else "?")
		_tooltips(c, out)
	return out


## Scripts the game can reach from main.gd, following preloads.
func _reachable() -> Array:
	var seen := {}
	var todo: Array = ["res://main.gd"]
	var re := RegEx.new()
	re.compile("(?:preload|load)\\(\"(res://[^\"]+\\.gd)\"\\)")
	while not todo.is_empty():
		var p: String = todo.pop_back()
		if seen.has(p):
			continue
		seen[p] = true
		for m in re.search_all(FileAccess.get_file_as_string(p)):
			todo.append(m.get_string(1))
	return seen.keys()


func test_static_scan() -> void:
	var scripts := _reachable()
	ok(scripts.size() >= 15, "the shipped UI scripts are found (%d)" % scripts.size())
	for p in scripts:
		var src := FileAccess.get_file_as_string(p)
		if p.ends_with("touch_hint.gd"):
			continue
		ok(not ("mouse_entered" in src or "mouse_exited" in src), "%s plays hover only through TouchHint.on_hover" % p.get_file())
		ok(not ("_make_custom_tooltip" in src), "%s has no custom tooltip the hint cannot show" % p.get_file())
	for p in scripts:
		if "res://ui/" in p:
			ok(p.begins_with("res://ui/play/"), "the game reaches only ui/play (the old prototype screens are not shipped): %s" % p)
	# iOS forbids an app quitting itself and Android leaves by Home or Back: the one Quit in the
	# shipped UI is the title's, behind is_mobile().
	var quits: Array = []
	for p in scripts:
		var src := FileAccess.get_file_as_string(p)
		if ".quit(" in src:
			quits.append(p.get_file())
	ok(quits == ["title_screen.gd"], "only the title screen can quit the game: %s" % str(quits))
	var title_src := FileAccess.get_file_as_string("res://ui/play/title_screen.gd")
	var at := title_src.find(".quit(")
	ok(at > 0 and title_src.rfind("if not UiSettings.is_mobile()", at) > title_src.rfind("\n\n", at), "and only off mobile")


## The title's Quit: there on a desktop, not on a phone or tablet.
func test_quit_button() -> void:
	UiSettings.force_mobile = 0
	app.show_title()
	await _frames(2)
	ok(_find(app.current, "Quit") != null, "a desktop title offers Quit")
	UiSettings.force_mobile = 1
	app.show_title()
	await _frames(2)
	ok(_find(app.current, "Quit") == null, "a phone's title has no Quit")
	ok(_find(app.current, "Settings") != null and _find(app.current, "Begin") != null, "and keeps its other buttons")
	for mode in ["title", "game"]:
		if mode == "game":
			_game()
			await _frames(2)
		var m: Control = app.open_menu()
		await _frames(2)
		ok(_find(m, "Quit") == null and _find(m, "Exit") == null, "the %s menu has no Quit on a phone" % mode)
		m.queue_free()
		await _frames(1)
	UiSettings.force_mobile = 0
	app.show_title()
	await _frames(2)


## Builds every screen and panel that sets a tooltip and holds a finger on each tooltip that a
## mouse could reach: the hint must show exactly that text.
func test_every_tooltip_reachable() -> void:
	_game()
	d.heir.age = maxf(d.heir.age, d.heir.family_min_age())
	d.found_family()
	d.heir.traits.append("cursed")
	app.show_state()
	await _frames(3)
	await _probe(app.current, "life_screen.gd")
	for panel in [ShopPanel, TavernPanel, BoardPanel, FeatsPanel, SkillTreePanel]:
		var p: Control = panel.new()
		p.dynasty = d
		p.on_change = func(): pass
		app.current.add_child(p)
		await _frames(3)
		await _probe(p, panel.resource_path.get_file())
		if panel == ShopPanel:
			for t in ["Temple", "Gear"]:
				var tb := _find(p, t)
				if tb != null:
					tb.pressed.emit()
					await _frames(3)
					await _probe(p, "shop_panel.gd")
		if panel == TavernPanel:
			var sk := _find(p, "Skill tree")
			if sk != null:
				sk.pressed.emit()
				await _frames(3)
				await _probe(p.get_children().back(), "skill_tree_panel.gd")
		p.queue_free()
		await _frames(2)
	var m: Control = MapPanel.new()
	m.dynasty = d
	m.on_travel = func(_to): pass
	m.on_change = func(): pass
	app.current.add_child(m)
	await _frames(3)
	await _probe(m, "map_panel.gd")
	m.queue_free()
	GameEvents.begin(d, "elven_wardens")
	app.show_state()
	await _frames(4)
	await _probe(app.current.get_children().back(), "event_panel.gd")
	GameEvents.dismiss(d)
	# Battle: commands, the feat list, the spell list, status chips.
	_game("mage", 40, 12)
	for i in 200:
		d.start_hunt("hunt_hard")
		if d.battle.enemies.size() >= 3:
			break
		d.battle = null
	d.auto_battle = false
	app.show_state()
	await _frames(4)
	var bv: Control = app.current
	bv.set_auto(false)
	await _frames(2)
	await _probe(bv, "battle_view.gd")
	ok(bv.strip != null, "a battle with companions has the party strip")
	await _probe(bv.strip, "party_strip.gd")
	bv._open_feats()
	await _frames(4)
	if bv.feat_list != null:
		await _probe(bv.feat_list, "battle_view.gd")
		bv._close_feats()
	bv._open_spells()
	await _frames(3)
	await _probe(bv.spell_list, "battle_view.gd")
	bv._close_spells()
	d.battle = null
	d.heir.age = maxf(d.heir.age, d.heir.family_min_age())
	if not d.heir.family_founded:
		d.found_family()
	d.retire()
	app.show_state()
	await _frames(4)
	await _probe(app.current, "succession_screen.gd")
	print("  tooltips proven by a hold: ", covered)
	for p in _reachable():
		var src := FileAccess.get_file_as_string(p)
		if "tooltip_text =" in src:
			ok(visited.has(p.get_file()), "%s sets tooltips and its screens were probed" % p.get_file())
			ok(int(covered.get(p.get_file(), 0)) > 0, "%s: a hold showed at least one of its tooltips (%d)" % [p.get_file(), int(covered.get(p.get_file(), 0))])


func _probe(host: Control, script_file: String) -> void:
	visited[script_file] = true
	var shown := 0
	for c in _labels_with_tip(host, []):
		var ctl := c as Control
		if not is_instance_valid(ctl) or not ctl.is_visible_in_tree():
			continue
		var at := _center(ctl)
		var picked: Control = app.hints.pick(at)
		var tip := TouchHint.tooltip_at(picked, at) if picked != null else {"text": "", "owner": null}
		# Only what a resting mouse would show here: a control under another one shows nothing.
		if tip["owner"] != ctl:
			continue
		var before := _state()
		app.hints.hide_hint()
		await _down(at)
		app.hints.tick(0.6)
		var seen: String = app.hints.shown_text
		ok(seen == ctl.tooltip_text, "%s: holding '%s' shows its tooltip" % [script_file, ctl.tooltip_text.left(40)])
		await _up(at)
		app.hints.hide_hint()
		ok(_state() == before, "%s: holding '%s' changed nothing" % [script_file, ctl.tooltip_text.left(40)])
		shown += 1
	covered[script_file] = int(covered.get(script_file, 0)) + shown


func _state() -> String:
	return JSON.stringify(d.to_dict()) + ("" if d.battle == null else str(d.battle.log.size()))


func test_back_button() -> void:
	_game()
	await _frames(2)
	var life: Control = app.current
	var shop: Control = ShopPanel.new()
	shop.dynasty = d
	life.add_child(shop)
	await _frames(2)
	ok(app.go_back() == "closed" and shop.is_queued_for_deletion(), "back closes the open panel")
	await _frames(2)
	ok(app.go_back() == "menu" and life.get_children().back() is MenuPanel, "with nothing open, back opens the menu")
	ok(app.go_back() == "closed", "and back again closes it")
	await _frames(2)
	var tav: Control = TavernPanel.new()
	tav.dynasty = d
	tav.on_change = func(): pass
	life.add_child(tav)
	await _frames(2)
	_find(tav, "Skill tree").pressed.emit()
	await _frames(2)
	var tree: Node = tav.get_children().back()
	ok(tree.get_script() == SkillTreePanel, "a skill tree opened from the tavern")
	ok(app.go_back() == "closed" and tree.is_queued_for_deletion() and not tav.is_queued_for_deletion(), "back closes the innermost panel first")
	await _frames(2)
	ok(app.go_back() == "closed" and tav.is_queued_for_deletion(), "then the tavern")
	await _frames(2)
	GameEvents.begin(d, "elven_wardens")
	app.show_state()
	await _frames(4)
	var ev: Node = app.current.get_children().back()
	ok(ev.get_script() == EventPanel, "an event waits for an answer")
	ok(app.go_back() == "menu" and not ev.is_queued_for_deletion(), "back does not dismiss an event: the menu opens over it")
	ok(app.go_back() == "closed" and not ev.is_queued_for_deletion(), "closing the menu leaves the event")
	GameEvents.dismiss(d)
	app.show_state()
	await _frames(2)
	# The real notification, as Android sends it.
	var before: int = app.current.get_child_count()
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(2)
	ok(app.current.get_child_count() == before + 1 and app.current.get_children().back() is MenuPanel, "the back notification opens the menu")
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(2)
	ok(not (app.current.get_children().back() is MenuPanel) or app.current.get_children().back().is_queued_for_deletion(), "and closes it")
	ok(app.is_inside_tree(), "back never quits")
	# Battle: back drops a list, then opens the menu; the fight goes on.
	for i in 200:
		d.start_hunt("hunt")
		if d.battle != null:
			break
	app.show_state()
	await _frames(3)
	var bv: Control = app.current
	bv.set_auto(false)
	bv._open_feats()
	await _frames(2)
	ok(bv.feat_list != null, "the feat list is open")
	ok(app.go_back() == "screen" and bv.feat_list == null, "back shuts the feat list")
	ok(app.go_back() == "menu" and app.menu_mode() == "battle", "then opens the menu (battle mode: no title exit)")
	ok(_find(app.current.get_children().back(), "Title screen") == null, "no way to the title mid-fight")
	app.go_back()
	d.battle = null
	app.show_title()
	await _frames(2)
	ok(app.go_back() == "menu" and app.menu_mode() == "title", "on the title, back opens settings")


func test_pause_saves() -> void:
	_game()
	await _frames(2)
	d.heir.gold = 4321
	d.heir.potions = 7
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var back := GameDynasty.load_from_disk()
	ok(back != null and back.heir.gold == 4321 and back.heir.potions == 7, "pausing the app saves the dynasty")
	d.heir.gold = 1234
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	back = GameDynasty.load_from_disk()
	ok(back != null and back.heir.gold == 1234, "the pause notification reaches the app and saves")
	d.heir.gold = 999
	UiSettings.force_mobile = 1
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	back = GameDynasty.load_from_disk()
	ok(back != null and back.heir.gold == 999, "a phone sent to the background saves")
	UiSettings.force_mobile = 0
	d.heir.gold = 555
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	back = GameDynasty.load_from_disk()
	ok(back != null and back.heir.gold == 999, "a desktop losing focus does not write the save")
	ok(JSON.stringify(back.to_dict()) == JSON.stringify(GameDynasty.from_dict(JSON.parse_string(JSON.stringify(back.to_dict()))).to_dict()), "the paused save round-trips")
	# Mid-fight the rule stands: battles are saved when they end, so the save on disk is the one
	# from before it, and pausing changes nothing.
	d.save_to_disk()
	var disk := FileAccess.get_file_as_string(GameDynasty.save_path)
	d.start_hunt("hunt")
	app.show_state()
	await _frames(2)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	ok(FileAccess.get_file_as_string(GameDynasty.save_path) == disk, "a pause mid-fight keeps the save from before the fight")
	d.battle = null
	app.show_state()
	await _frames(2)


func test_safe_area() -> void:
	app.safe_override = Rect2i(80, 0, 1280 - 80 - 40, 720 - 20)
	app.apply_safe_area()
	app.show_state()
	await _frames(3)
	ok(app.frame.get_global_rect().is_equal_approx(Rect2(80, 0, 1160, 700)), "screens sit inside the safe area (%s)" % str(app.frame.get_global_rect()))
	ok(is_equal_approx(UiSettings.room(app).x, 1160.0), "and lay themselves out for the room left")
	_check_inside(app.frame, Rect2(80, 0, 1160, 700), "life screen with a notch")
	app.safe_override = Rect2i()
	app.apply_safe_area()
	ok(app.frame.get_global_rect().is_equal_approx(Rect2(0, 0, 1280, 720)), "a desktop window has no inset")


var _outside := 0


func _check_inside(n: Node, room: Rect2, where: String) -> void:
	_outside = 0
	_walk_inside(n, room.grow(1.0), where)
	ok(_outside == 0, "%s: nothing outside the screen" % where)


func _walk_inside(n: Node, room: Rect2, where: String) -> void:
	if n is Control and (n as Control).is_visible_in_tree():
		var c := n as Control
		var r := c.get_global_rect()
		var clip := _clip_of(c)
		if r.size.x > 0 and r.size.y > 0 and not room.encloses(r) and clip == null:
			_outside += 1
			if _outside <= 3:
				print("  outside on %s: %s '%s' %s" % [where, n.get_class(), str(n.get("text")).left(30) if n.get("text") != null else "", str(r)])
		# Inside a clipping parent that does not scroll, what sticks out is cut off for good.
		if clip != null and not (clip is ScrollContainer) and r.size.x > 0 and r.size.y > 0 and not clip.get_global_rect().grow(1.0).encloses(r):
			_outside += 1
			if _outside <= 3:
				print("  cut off on %s: %s '%s' %s in %s %s" % [where, n.get_class(), str(n.get("text")).left(30) if n.get("text") != null else "", str(r), clip.get_class(), str(clip.get_global_rect())])
		if c is ScrollContainer:
			_check_scrolls(c as ScrollContainer, where)
		if UiSettings.touch() and n is BaseButton and r.size.y < float(UiSettings.setting("touch_target_px")) - 0.5:
			_outside += 1
			print("  small button on %s: '%s' %.0f tall" % [where, str(n.get("text")).left(30), r.size.y])
		if UiSettings.touch() and n is TabContainer and (n as TabContainer).get_tab_bar().size.y < float(UiSettings.setting("touch_target_px")) - 0.5:
			_outside += 1
			print("  small tabs on %s: %.0f tall" % [where, (n as TabContainer).get_tab_bar().size.y])
	for ch in n.get_children():
		_walk_inside(ch, room, where)


## A ScrollContainer whose content is longer than itself must scroll that way.
func _check_scrolls(sc: ScrollContainer, where: String) -> void:
	for ch in sc.get_children():
		if not (ch is Control) or not (ch as Control).visible or ch is ScrollBar:
			continue
		var want := (ch as Control).get_combined_minimum_size()
		if want.x > sc.size.x + 1.0 and sc.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
			_outside += 1
			print("  no sideways scroll on %s: %s wide in %s" % [where, str(want.x), str(sc.size.x)])
		if want.y > sc.size.y + 1.0 and sc.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
			_outside += 1
			print("  no scroll down on %s: %s tall in %s" % [where, str(want.y), str(sc.size.y)])


## The nearest parent that clips: a ScrollContainer or a control with clip_contents.
func _clip_of(n: Node) -> Control:
	var p := n.get_parent()
	while p != null:
		if p is ScrollContainer or (p is Control and (p as Control).clip_contents):
			return p
		p = p.get_parent()
	return null


const LAYOUT_SIZES := [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(2400, 1080), Vector2i(1280, 800), Vector2i(960, 540)]


## Every screen and panel at every text size on phone, tablet and small windows, touch-sized, the
## phone shapes with a notch and a home bar: nothing runs off the safe area or is cut off by a
## clipping parent (what does not fit must sit in a ScrollContainer that scrolls that way), and every
## button is a fingertip tall; the scale really is the window's content scale.
func test_scale_layouts() -> void:
	UiSettings.force_touch = 1
	for wsize in LAYOUT_SIZES:
		root.size = wsize
		var notch: bool = float(wsize.x) / float(wsize.y) > 2.0   # the 20:9 phones
		app.safe_override = Rect2i(int(wsize.x * 0.04), 0, wsize.x - int(wsize.x * 0.04) - int(wsize.x * 0.02), wsize.y - int(wsize.y * 0.03)) if notch else Rect2i()
		for s in UiSettings.scales():
			await _layout_pass(wsize, s)
	root.size = Vector2i(1280, 720)
	app.safe_override = Rect2i()
	UiSettings.force_touch = 0
	app.set_ui_scale(1.0)
	await _frames(2)
	ok(is_equal_approx(root.content_scale_factor, 1.0), "back to 100%")
	ok(app.frame.get_global_rect().is_equal_approx(Rect2(0, 0, 1280, 720)), "and to the plain window")


func _layout_pass(wsize: Vector2i, s: float) -> void:
	app.set_ui_scale(s)
	await _frames(3)
	var tag := "%dx%d %d%%" % [wsize.x, wsize.y, int(round(s * 100.0))]
	ok(is_equal_approx(root.content_scale_factor, s), "%s: the window's content scale is %.2f" % [tag, s])
	var vis := root.get_visible_rect().size
	var base := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	var fit := minf(float(wsize.x) / base.x, float(wsize.y) / base.y)   # canvas_items, expand
	ok(vis.is_equal_approx(Vector2(wsize) / fit / s), "%s: the screens get %s of room" % [tag, str(vis)])
	var room := Rect2(UiSettings.insets.position, UiSettings.room(app))
	ok(app.frame.get_global_rect().is_equal_approx(room), "%s: the screens sit in the safe area %s" % [tag, str(room)])
	var menu: Node = app.current.get_children().back()
	ok(menu is MenuPanel, "%s: the menu reopens after the text size changes" % tag)
	app.show_title()
	await _frames(3)
	_check_inside(app.frame, room, "title " + tag)
	app.open_menu()
	await _frames(2)
	_check_inside(app.frame, room, "title settings " + tag)
	_game()
	d.heir.age = maxf(d.heir.age, d.heir.family_min_age())
	d.found_family()
	app.show_state()
	await _frames(3)
	_check_inside(app.frame, room, "life screen " + tag)
	for panel in [ShopPanel, TavernPanel, BoardPanel, FeatsPanel, SkillTreePanel, MapPanel, ChroniclePanel]:
		var p: Control = panel.new()
		p.dynasty = d
		if panel != ChroniclePanel:
			p.on_change = func(): pass
		if panel == MapPanel:
			p.on_travel = func(_to): pass
		app.current.add_child(p)
		await _frames(3)
		var pname: String = panel.resource_path.get_file()
		_check_inside(app.frame, room, "%s %s" % [pname, tag])
		if panel == SkillTreePanel:   # the header moves aside on a short screen: the tree keeps the room
			var frame_h: float = (p.scroll.get_parent() as Control).size.y
			ok(frame_h >= room.size.y * 0.5, "%s: the skill tree gets half the height or more (%.0f of %.0f)" % [tag, frame_h, room.size.y])
		if panel == ShopPanel:
			for t in ["Temple", "Gear"]:
				var tb := _find(p, t)
				if tb != null:
					tb.pressed.emit()
					await _frames(3)
					_check_inside(app.frame, room, "%s %s %s" % [pname, t, tag])
		if panel == TavernPanel:
			var sk := _find(p, "Skill tree")
			if sk != null:
				sk.pressed.emit()
				await _frames(3)
				_check_inside(app.frame, room, "tavern skill tree " + tag)
		if panel == ChroniclePanel:
			var tabs := _tabs(p)
			for i in (tabs.get_tab_count() if tabs != null else 0):
				tabs.current_tab = i
				await _frames(2)
				_check_inside(app.frame, room, "chronicle tab %d %s" % [i, tag])
		p.queue_free()
		await _frames(1)
	app.open_menu()
	await _frames(2)
	_check_inside(app.frame, room, "menu " + tag)
	GameEvents.begin(d, "elven_wardens")
	app.show_state()
	await _frames(4)
	_check_inside(app.frame, room, "event " + tag)
	GameEvents.dismiss(d)
	await _fight(3)
	var bv: Control = app.current
	_check_inside(app.frame, room, "battle " + tag)
	bv._open_feats()
	await _frames(4)
	_check_inside(app.frame, room, "battle feats " + tag)
	bv._close_feats()
	await _frames(2)
	app.open_menu()
	await _frames(2)
	_check_inside(app.frame, room, "battle menu " + tag)
	app.go_back()
	for e in d.battle.enemies:
		e["hp"] = 0
	d.battle.result = "victory"
	d.finish_battle()
	app.show_state()
	await _frames(4)
	ok(_open_of(app.current, LootPanel) != null or d.loot.is_empty(), "%s: the dead wait in the loot panel" % tag)
	_check_inside(app.frame, room, "loot " + tag)
	d.loot = {}
	_game("mage", 40, 12)
	await _fight(3)
	app.current._open_spells()
	await _frames(3)
	_check_inside(app.frame, room, "battle spells " + tag)
	app.current._close_spells()
	d.battle = null
	d.heir.age = maxf(d.heir.age, d.heir.family_min_age())
	if not d.heir.family_founded:
		d.found_family()
	d.retire()
	app.show_state()
	await _frames(4)
	_check_inside(app.frame, room, "succession " + tag)
	# A big family (orcs and halflings have up to four) with traits and a fate mark: every card and
	# its Choose button fit beside each other.
	d.pending_archetype = GameFate.ARCHETYPES.keys()[0]
	for n in [3, 4]:
		while d.candidates.size() < n:
			d.candidates.append(GameHeir.from_dict(d.candidates[0].to_dict()))
		for c in d.candidates:
			for t in GameData.traits_in(["bloodline", "blessing"]).slice(0, 2):
				if t not in c.traits:
					c.traits.append(t)
		app.show_state()
		await _frames(4)
		var picks: Array = app.current.find_children("*", "Button", true, false).filter(func(b): return (b as Button).text.begins_with("Choose "))
		# Side by side within the room (a short screen scrolls them down to the buttons).
		ok(picks.size() == n and picks.all(func(b): return (b as Control).get_global_rect().position.x >= room.position.x - 1.0 and (b as Control).get_global_rect().end.x <= room.end.x + 1.0),
			"%s: all %d heirs can be chosen" % [tag, n])
		_check_inside(app.frame, room, "succession of %d %s" % [n, tag])
	d.pending_archetype = ""
	d.state = "ended"
	app.show_state()
	await _frames(4)
	ok(app.current is EndingScreen, "%s: the ending screen" % tag)
	_check_inside(app.frame, room, "ending " + tag)


func _fight(foes: int) -> void:
	for i in 200:
		d.start_hunt("hunt_hard")
		if d.battle.enemies.size() >= foes:
			break
		d.battle = null
	d.auto_battle = false
	app.show_state()
	await _frames(4)
	app.current.set_auto(false)
	await _frames(3)


func _tabs(n: Node) -> TabContainer:
	if n is TabContainer:
		return n
	for c in n.get_children():
		var t := _tabs(c)
		if t != null:
			return t
	return null


func _open_of(n: Node, script: Script) -> Node:
	for c in n.get_children():
		if c.get_script() == script and not c.is_queued_for_deletion():
			return c
	return null


## Buttons under `n` whose text does not fit: the longest line is wider than the room inside the
## button (a clipping button shows "Skills (3 re"), or the button sticks out of `within`.
func _clipped(n: Node, within: Rect2, out: Array = []) -> Array:
	if n is Button and (n as Button).is_visible_in_tree():
		var btn := n as Button
		var font := btn.get_theme_font("font")
		var size_px := btn.get_theme_font_size("font_size")
		var inner := btn.size.x - btn.get_theme_stylebox("normal").get_minimum_size().x
		var longest := 0.0
		for line in btn.text.split("\n"):
			longest = maxf(longest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x)
		if longest > inner + 0.5:
			out.append("'%s' needs %.0f of %.0f" % [btn.text.replace("\n", " / "), longest, inner])
		elif not within.grow(1.0).encloses(btn.get_global_rect()):
			out.append("'%s' sticks out %s of %s" % [btn.text.replace("\n", " / "), str(btn.get_global_rect()), str(within)])
	for c in n.get_children():
		_clipped(c, within, out)
	return out


## The battle commands (Attack, the class skills, Skills (n ready), Feats, Spells, Poisons, Potion,
## Flee) show their whole text at the small windows and every text size, for a caster, a martial
## and a hybrid, with feats readied, later skills and a toxin in the pack.
func test_command_text_fits() -> void:
	UiSettings.force_touch = 1
	for wsize in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1600, 720)]:
		root.size = wsize
		for s in UiSettings.scales():
			app.set_ui_scale(s)
			await _frames(3)
			for cls in ["mage", "warrior", "rogue", "paladin", "spellblade"]:
				_game(cls, 120, 31)
				d.heir.potions = 7
				await _fight(3)
				var bv: Control = app.current
				var tag := "%dx%d %d%% %s" % [wsize.x, wsize.y, int(round(s * 100.0)), cls]
				var buttons: Array = bv.command_box.find_children("*", "Button", true, false).filter(func(x): return (x as Button).is_visible_in_tree())
				var texts: Array = buttons.map(func(x): return (x as Button).text)
				ok(buttons.size() >= 4, "%s: the commands are shown (%s)" % [tag, ", ".join(texts).replace("\n", " / ")])
				var bad := _clipped(bv.command_box, bv.cmd_panel.get_global_rect())
				ok(bad.is_empty(), "%s: no command text is cut off %s" % [tag, str(bad)])
				d.battle = null
	root.size = Vector2i(1280, 720)
	UiSettings.force_touch = 0
	app.set_ui_scale(1.0)
	await _frames(2)


func _tick_clock() -> float:
	return clock_t


func _cool_fresh() -> void:
	DirAccess.remove_absolute(UiSettings.path)
	clock_t = 1.7e9
	Cooldown.clock = _tick_clock
	Cooldown.forget()


## The autopilot buttons' wait: remaining, ready, start, M:SS, kept in the settings file (old files
## have no key, absurd values are capped), no sleeping.
func test_cooldown_logic() -> void:
	_cool_fresh()
	ok(is_equal_approx(Cooldown.seconds("life"), 60.0) and is_equal_approx(Cooldown.seconds("gens"), 300.0), "the cooldowns come from the data: 60 and 300 seconds")
	ok(Cooldown.is_ready("life") and Cooldown.is_ready("gens") and Cooldown.remaining("life") == 0.0, "nothing is cooling down at first")
	ok(not Cooldown.any_active(), "so no timer is wanted")
	Cooldown.start("life")
	ok(is_equal_approx(Cooldown.remaining("life"), 60.0) and not Cooldown.is_ready("life"), "starting one makes it wait its 60 seconds")
	ok(Cooldown.is_ready("gens") and Cooldown.any_active(), "the other button has its own timer")
	clock_t += 59.5
	ok(is_equal_approx(Cooldown.remaining("life"), 0.5) and not Cooldown.is_ready("life"), "it counts down with the clock")
	clock_t += 0.5
	ok(Cooldown.is_ready("life") and not Cooldown.any_active(), "and is ready when the time is up")
	Cooldown.start("gens")
	ok(is_equal_approx(Cooldown.remaining("gens"), 300.0), "the ten-generation button waits 300 seconds")
	ok(Cooldown.format(272.0) == "4:32" and Cooldown.format(60.0) == "1:00" and Cooldown.format(300.0) == "5:00", "M:SS: 4:32, 1:00, 5:00")
	ok(Cooldown.format(0.2) == "0:01" and Cooldown.format(0.0) == "0:00" and Cooldown.format(-4.0) == "0:00" and Cooldown.format(9.0) == "0:09", "M:SS rounds up and pads: 0:01, 0:00, 0:09")
	ok(Cooldown.label("gens", "Auto: 10 gens") == "Auto: 10 gens (5:00)" and Cooldown.label("life", "Auto: this life") == "Auto: this life", "the label shows the time only while waiting")
	ok(Cooldown.tip("gens", "x") == "Ready in 5:00" and Cooldown.tip("life", "Plays a whole life on autopilot.") == "Plays a whole life on autopilot. Cooldown 1:00", "the tooltips")
	# kept in the settings file, apart from the dynasty save
	var due: float = Cooldown.ready_at["gens"]
	Cooldown.forget()
	clock_t += 28.0
	ok(is_equal_approx(Cooldown.remaining("gens"), 272.0), "reopening the game keeps the countdown (4:32 left)")
	var cf := ConfigFile.new()
	ok(cf.load(UiSettings.path) == OK and is_equal_approx(float(cf.get_value("ui", "autopilot_gens_ready_at", 0.0)), due), "the ready-at time is in the settings file")
	UiSettings.set_scale(1.5)
	UiSettings.set_touch_layout("off")
	Cooldown.forget()
	ok(is_equal_approx(Cooldown.remaining("gens"), 272.0), "saving the other settings keeps it")
	UiSettings.set_scale(1.0)
	UiSettings.set_touch_layout("auto")
	var dyn := GameDynasty.new_game(3, "Ana", "mage", "faetouched", "elf")
	ok(not ("autopilot" in JSON.stringify(dyn.to_dict())), "the dynasty save does not carry it")
	# a file from before the setting
	DirAccess.remove_absolute(UiSettings.path)
	cf = ConfigFile.new()
	cf.set_value("ui", "scale", 1.25)
	cf.save(UiSettings.path)
	Cooldown.forget()
	ok(Cooldown.is_ready("life") and Cooldown.is_ready("gens"), "an old settings file without the keys reads as ready")
	UiSettings.scale = -1.0
	ok(is_equal_approx(UiSettings.get_scale(), 1.25), "and its other settings still load")
	# absurd values
	for v in [1.0e15, clock_t + 100000.0, clock_t + 301.0]:
		UiSettings.store("autopilot_gens_ready_at", v)
		Cooldown.forget()
		ok(is_equal_approx(Cooldown.remaining("gens"), 300.0), "a ready-at time of %s is capped to one cooldown from now" % str(v))
	UiSettings.store("autopilot_life_ready_at", 1.0e15)
	Cooldown.forget()
	ok(is_equal_approx(Cooldown.remaining("life"), 60.0), "the short one is capped to 60 seconds")
	clock_t += 61.0
	ok(Cooldown.is_ready("life"), "and then runs down as usual")
	for v in ["soon", -5.0, 0, null, INF, NAN]:
		UiSettings.store("autopilot_life_ready_at", v)
		Cooldown.forget()
		ok(Cooldown.is_ready("life"), "a stored %s reads as ready" % str(v))
	# the harness never asks
	var bot_text := FileAccess.get_file_as_string("res://core/game/game_bot.gd")
	ok(not ("ooldown" in bot_text), "GameBot does not know about the cooldown")
	_cool_fresh()
	var g := GameDynasty.new_game(5, "Bo", "warrior", "faetouched", "human")
	Cooldown.start("life")
	Cooldown.start("gens")
	var age0 := g.heir.age
	GameBot.live_life(g)
	ok(g.state != "life" and g.heir.age > age0 + 20.0, "the harness's autopilot plays a whole life (ended at age %.0f from %.0f) while both buttons cool down" % [g.heir.age, age0])
	ok(not Cooldown.is_ready("life") and not Cooldown.is_ready("gens"), "and leaves the button cooldowns as they were")
	# anything but a number in the file reads as ready, quietly
	for v in [[1, 2], {"a": 1}, true, Vector2(5, 5), PackedByteArray([1]), "9"]:
		UiSettings.store("autopilot_life_ready_at", v)
		Cooldown.forget()
		ok(Cooldown.is_ready("life"), "a stored %s reads as ready" % type_string(typeof(v)))
	UiSettings.store("autopilot_life_ready_at", int(clock_t) + 30)
	Cooldown.forget()
	ok(Cooldown.remaining("life") > 28.0 and Cooldown.remaining("life") <= 30.0, "a stored whole number counts down")
	# the lengths are the data's
	var cfg: Dictionary = GameData.mobile["settings"]
	var keep_life = cfg["autopilot_life_cooldown_seconds"]
	var keep_gens = cfg["autopilot_gens_cooldown_seconds"]
	cfg["autopilot_life_cooldown_seconds"] = 20
	cfg["autopilot_gens_cooldown_seconds"] = 90
	_cool_fresh()
	ok(is_equal_approx(Cooldown.seconds("life"), 20.0) and is_equal_approx(Cooldown.seconds("gens"), 90.0), "the lengths follow data/ui/mobile.json")
	Cooldown.start("gens")
	Cooldown.start("life")
	ok(Cooldown.label("gens", "A") == "A (1:30)" and Cooldown.label("life", "A") == "A (0:20)", "and so do the labels")
	ok(Cooldown.tip("gens", "x") == "Ready in 1:30", "and the tooltips")
	cfg["autopilot_life_cooldown_seconds"] = keep_life
	cfg["autopilot_gens_cooldown_seconds"] = keep_gens
	Cooldown.clock = Callable()
	Cooldown.forget()
	DirAccess.remove_absolute(UiSettings.path)


## The life screen: a used button greys out and counts down in place, the other keeps its own timer,
## the handler refuses while waiting, and everything is restored when the time is up.
func test_cooldown_buttons() -> void:
	_cool_fresh()
	_game()
	await _frames(3)
	var life: Control = app.current
	var one := _find(life, "Auto: this life")
	var ten := _find(life, "Auto: 10 gens")
	ok(one != null and ten != null and not one.disabled and not ten.disabled, "both autopilot buttons start ready")
	ok(one.text == "Auto: this life" and one.tooltip_text == "Plays a whole life on autopilot. Cooldown 1:00", "ready: plain text and a tooltip with the cooldown")
	ok(life.cool_timer.is_stopped(), "no timer runs while nothing waits")
	var gen0 := d.gen
	one.pressed.emit()
	await _frames(3)
	ok(d.gen != gen0 or app.current != life, "the autopilot plays a life")
	ok(not Cooldown.is_ready("life") and Cooldown.is_ready("gens"), "using one starts only its own cooldown")
	_game()   # a new life screen: it reads the cooldown that is running
	await _frames(3)
	life = app.current
	one = _find(life, "Auto: this life")
	ten = _find(life, "Auto: 10 gens")
	ok(one.disabled and one.text == "Auto: this life (1:00)", "greyed out and counting: '%s'" % one.text)
	ok(one.tooltip_text == "Ready in 1:00", "its tooltip says when: '%s'" % one.tooltip_text)
	ok(not ten.disabled and ten.text == "Auto: 10 gens", "the other is untouched")
	ok(not life.cool_timer.is_stopped(), "the one-second timer runs")
	Cooldown.start("gens")
	clock_t += 18.0
	life.tick_cooldowns()
	ok(one.text == "Auto: this life (0:42)" and one.tooltip_text == "Ready in 0:42", "a tick updates the text in place: '%s'" % one.text)
	ok(ten.disabled and ten.text == "Auto: 10 gens (4:42)", "both count down: '%s'" % ten.text)
	ok(_find(app.current, "Auto: this life") == one, "without rebuilding the screen")
	var state0 := d.to_dict()
	life._autopilot("life", 1)
	life._autopilot("gens", 10)
	ok(d.to_dict() == state0 and app.current == life, "the handlers do nothing while cooling down")
	var bg: Color = (one.get_theme_stylebox("disabled") as StyleBoxFlat).bg_color
	var fg: Color = one.get_theme_color("font_disabled_color")
	ok(_contrast(fg, bg) >= 4.5, "the countdown is readable: contrast %.2f" % _contrast(fg, bg))
	ok(is_equal_approx(life.cool_timer.wait_time, 1.0), "the timer ticks every second")
	var hunt := _find(life, "Hunt")
	ok(hunt != null and not hunt.disabled, "the rest of the screen stays playable")
	clock_t += 42.0
	life.tick_cooldowns()
	ok(not one.disabled and one.text == "Auto: this life" and one.tooltip_text == "Plays a whole life on autopilot. Cooldown 1:00", "the short one is restored when its time is up")
	ok(ten.disabled and ten.text == "Auto: 10 gens (4:00)" and not life.cool_timer.is_stopped(), "the long one still counts, the timer runs on")
	clock_t += 241.0
	life.tick_cooldowns()
	ok(not ten.disabled and ten.text == "Auto: 10 gens" and life.cool_timer.is_stopped(), "all restored, and the timer stops")
	# nothing to play (not in a life): no autopilot and no wait
	var keep_state := d.state
	d.state = "succession"
	life._autopilot("gens", 10)
	d.state = keep_state
	ok(Cooldown.is_ready("gens"), "the handler starts no wait when there is no life to play")
	gen0 = d.gen
	ten.pressed.emit()
	await _frames(3)
	ok(d.gen != gen0 or app.current != life, "the ten-generation autopilot plays")
	ok(not Cooldown.is_ready("gens") and is_equal_approx(Cooldown.remaining("gens"), 300.0), "a ready button runs and starts its cooldown")
	# closed and reopened: the screen reads the file
	Cooldown.forget()
	clock_t += 30.0
	_game()
	await _frames(3)
	ten = _find(app.current, "Auto: 10 gens")
	ok(ten.disabled and ten.text == "Auto: 10 gens (4:30)", "a new screen after a restart shows the time left: '%s'" % ten.text)
	Cooldown.clock = Callable()
	Cooldown.forget()
	DirAccess.remove_absolute(UiSettings.path)


func _contrast(a: Color, b: Color) -> float:
	var la := _luma(a)
	var lb := _luma(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _luma(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


## The real one-second timer redraws the countdown with no manual tick, and a held tip's bubble
## follows it.
func test_cooldown_timer() -> void:
	_cool_fresh()
	_game()
	Cooldown.start("life")
	app.show_state()
	await _frames(3)
	var life: Control = app.current
	var one := _find(life, "Auto: this life")
	ok(one.text == "Auto: this life (1:00)" and not life.cool_timer.is_stopped(), "waiting: the timer runs")
	clock_t += 5.0
	await create_timer(1.2).timeout
	ok(one.text == "Auto: this life (0:55)", "the timer alone updates the text: '%s'" % one.text)
	life.actions_scroll.scroll_vertical = 100000
	await _frames(3)
	var seen := await _hold(one, float(UiSettings.setting("hold_seconds")) + 0.05)
	ok(seen == "Ready in 0:55", "a hold shows the time left: '%s'" % seen)
	app.hints.hide_hint()
	await _down(_center(one))
	app.hints.tick(float(UiSettings.setting("hold_seconds")) + 0.05)
	clock_t += 10.0
	await create_timer(1.2).timeout
	app.hints.tick(0.1)
	ok(app.hints.shown_text == "Ready in 0:45" and app.hints.text.text == "Ready in 0:45", "a bubble still up follows the countdown: '%s'" % app.hints.shown_text)
	await _up(_center(one))
	app.hints.hide_hint()
	clock_t += 100.0
	await create_timer(1.2).timeout
	ok(not one.disabled and one.text == "Auto: this life" and life.cool_timer.is_stopped(), "when the time is up the timer restores the button and stops")
	Cooldown.clock = Callable()
	Cooldown.forget()
	DirAccess.remove_absolute(UiSettings.path)


## The autopilot buttons' text, ready and counting down (widest: 5:00, 1:00 and a mid value), fits
## its button at every text size and the small windows.
func test_cooldown_text_fits() -> void:
	UiSettings.force_touch = 1
	for wsize in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1600, 720)]:
		root.size = wsize
		for s in UiSettings.scales():
			app.set_ui_scale(s)
			await _frames(3)
			for step in [0, 1, 2]:
				_cool_fresh()
				_game()
				if step > 0:
					Cooldown.start("life")
					Cooldown.start("gens")
					clock_t += 0.0 if step == 1 else 18.0
				app.show_state()
				await _frames(3)
				var life: Control = app.current
				var tag := "%dx%d %d%% %s" % [wsize.x, wsize.y, int(round(s * 100.0)), ["ready", "full", "0:42 / 4:42"][step]]
				var btns := [_find(life, "Auto: this life"), _find(life, "Auto: 10 gens")]
				ok(btns[0] != null and btns[1] != null, "%s: both buttons are there (%s / %s)" % [tag, btns[0].text, btns[1].text])
				var bad := _clipped(life.actions, Rect2(-100000, -100000, 200000, 200000))
				ok(bad.is_empty(), "%s: no action text is cut off %s" % [tag, str(bad)])
	Cooldown.clock = Callable()
	Cooldown.forget()
	DirAccess.remove_absolute(UiSettings.path)
	root.size = Vector2i(1280, 720)
	UiSettings.force_touch = 0
	app.set_ui_scale(1.0)
	await _frames(2)


## The text size changed from the menu mid-fight: the commands are laid out for the new room, the
## menu reopens showing the new size, and it draws above the fight's raised lists.
## Visible buttons of `n` (menus aside) shorter than the touch target.
func _short_buttons(n: Node, out: Array = []) -> Array:
	if n is MenuPanel:
		return out
	if n is Button and (n as Button).is_visible_in_tree() and (n as Button).size.y < float(UiSettings.setting("touch_target_px")) - 0.5:
		out.append("%s(%.0f)" % [(n as Button).text, (n as Button).size.y])
	for c in n.get_children():
		_short_buttons(c, out)
	return out


func test_scale_mid_fight() -> void:
	_game()
	for i in 200:
		d.start_hunt("hunt")
		if d.battle != null:
			break
	d.auto_battle = false
	app.show_state()
	await _frames(4)
	var bv: Control = app.current
	bv.set_auto(false)
	await _frames(2)
	var w100: float = bv.cmd_w
	var m: Control = app.open_menu()
	await _frames(2)
	_find(m, "150%").pressed.emit()
	await _frames(4)
	ok(app.current == bv and d.battle != null, "the fight goes on through a text-size change")
	ok(not is_equal_approx(bv.cmd_w, w100) and is_equal_approx(bv.cmd_panel.custom_minimum_size.x, bv.cmd_w), "the commands are sized for the new room (%.0f -> %.0f)" % [w100, bv.cmd_w])
	var menus := bv.get_children().filter(func(c): return c is MenuPanel and not c.is_queued_for_deletion())
	ok(menus.size() == 1, "one menu stays open")
	if menus.size() == 1:
		var cur := _find(menus[0], "150%")
		ok(cur != null and cur.get_theme_color("font_color") == Kit.ACCENT, "and it marks 150% as the size in use")
		ok((menus[0] as Control).z_index > 10, "the menu draws above the fight's lists and result")
	_check_inside(app.frame, Rect2(Vector2.ZERO, root.get_visible_rect().size), "battle after a text-size change")
	# Touch layout On mid-fight: buttons built once (Auto-battle) grow to a fingertip too.
	var keep_touch := UiSettings.force_touch
	UiSettings.force_touch = -1
	ok(_short_buttons(bv).size() > 0, "the desktop fight has buttons under a fingertip's height")
	if menus.size() == 1:
		_find(menus[0], "On").pressed.emit()
		await _frames(4)
		var short := _short_buttons(bv)
		ok(app.current == bv and UiSettings.touch() and short.is_empty(), "Touch layout On mid-fight: every button is a fingertip tall %s" % [short])
		_check_inside(app.frame, Rect2(Vector2.ZERO, root.get_visible_rect().size), "battle after Touch layout On")
	UiSettings.set_touch_layout("auto")
	UiSettings.force_touch = keep_touch
	bv.relayout()
	app.go_back()
	app.set_ui_scale(1.0)
	await _frames(2)
	for c in bv.get_children():
		if c is MenuPanel:
			c.queue_free()
	d.battle = null
	app.show_state()
	await _frames(2)
