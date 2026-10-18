## Phones and tablets: hold-for-details on touch screens (a hold shows the tooltip and is not a
## click, a tap still clicks, a drag scrolls), every tooltip and hover preview in the shipped UI
## reachable that way, the text-size setting (saved apart from the dynasty, applied as the content
## scale, no screen overflowing at 150%, touch-sized buttons), saving on pause, the Android back
## button, the safe area and the export presets.
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
const DIR := "user://test_mobile/"

var checks := 0
var fails := 0
var app: Node
var d: GameDynasty
var covered := {}     # script file -> tooltips proven reachable by a hold
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
	await test_hold_and_tap()
	await test_drag_scrolls()
	await test_hover_preview()
	test_static_scan()
	await test_every_tooltip_reachable()
	await test_back_button()
	await test_pause_saves()
	await test_safe_area()
	await test_scale_layouts()
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
	UiSettings.set_scale(1.0)


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
	await _tap(spb)
	ok(not bv.aiming.is_empty(), "a tap on the spell starts aiming")
	var last: int = d.battle.living_enemies().back()
	var foe: Control = bv.enemy_nodes[last]["body"]
	await _tap(foe)
	ok(bv.aim_at == last, "a tap on a foe aims there")
	ok(app.go_back() == "screen" and bv.aiming.is_empty(), "back drops the aim")
	d.battle = null


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
		var r := (n as Control).get_global_rect()
		if r.size.x > 0 and r.size.y > 0 and not room.encloses(r) and not _clipped(n):
			_outside += 1
			if _outside <= 3:
				print("  outside on %s: %s '%s' %s" % [where, n.get_class(), str(n.get("text")).left(30) if n.get("text") != null else "", str(r)])
		if UiSettings.touch() and n is BaseButton and r.size.y < float(UiSettings.setting("touch_target_px")) - 0.5:
			_outside += 1
			print("  small button on %s: '%s' %.0f tall" % [where, str(n.get("text")).left(30), r.size.y])
	for c in n.get_children():
		_walk_inside(c, room, where)


func _clipped(n: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if p is ScrollContainer or (p is Control and (p as Control).clip_contents):
			return true
		p = p.get_parent()
	return false


## Every screen at 125% and 150% on a 16:9 window, touch-sized: nothing runs off the screen and
## every button is a fingertip tall; the scale really is the window's content scale.
func test_scale_layouts() -> void:
	UiSettings.force_touch = 1
	for s in [1.25, 1.5]:
		app.set_ui_scale(s)
		await _frames(3)
		ok(is_equal_approx(root.content_scale_factor, s), "the window's content scale is %.2f" % s)
		var vis := root.get_visible_rect().size
		ok(vis.is_equal_approx(Vector2(1280, 720) / s), "the screens get %s of room at %d%%" % [str(vis), int(s * 100)])
		var tag := "%d%%" % int(round(s * 100.0))
		var room := Rect2(Vector2.ZERO, vis)
		var menu: Node = app.current.get_children().back()
		ok(menu is MenuPanel, "the menu reopens after the text size changes")
		app.show_title()
		await _frames(3)
		_check_inside(app.frame, room, "title " + tag)
		_game()
		d.heir.age = maxf(d.heir.age, d.heir.family_min_age())
		d.found_family()
		app.show_state()
		await _frames(3)
		_check_inside(app.frame, room, "life screen " + tag)
		for panel in [ShopPanel, TavernPanel, BoardPanel, FeatsPanel, SkillTreePanel, MapPanel]:
			var p: Control = panel.new()
			p.dynasty = d
			p.on_change = func(): pass
			if panel == MapPanel:
				p.on_travel = func(_to): pass
			app.current.add_child(p)
			await _frames(3)
			_check_inside(app.frame, room, "%s %s" % [panel.resource_path.get_file(), tag])
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
		await _frames(3)
		_check_inside(app.frame, room, "battle " + tag)
		bv._open_feats()
		await _frames(4)
		_check_inside(app.frame, room, "battle feats " + tag)
		bv._close_feats()
		d.battle = null
		d.retire()
		app.show_state()
		await _frames(4)
		_check_inside(app.frame, room, "succession " + tag)
	UiSettings.force_touch = 0
	app.set_ui_scale(1.0)
	await _frames(2)
	ok(is_equal_approx(root.content_scale_factor, 1.0), "back to 100%")


## The text size changed from the menu mid-fight: the commands are laid out for the new room, the
## menu reopens showing the new size, and it draws above the fight's raised lists.
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
	app.go_back()
	app.set_ui_scale(1.0)
	await _frames(2)
	for c in bv.get_children():
		if c is MenuPanel:
			c.queue_free()
	d.battle = null
	app.show_state()
	await _frames(2)
