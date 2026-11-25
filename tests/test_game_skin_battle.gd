## The interface skin on the battle screen (BattleSkin over BattleView; docs/ART_DIRECTION.md): the button piece and its states, the
## frame (a parchment command panel under a crimson ribbon, gold-studded buttons, parchment log with the newest line lit, slim
## segmented bars on the plates, slots for the rows of a list, the result as a ribbon on parchment), the high-contrast variant, a
## touch screen and a compact window keeping the older look, and that dressing the screen changes no die, event or log line.
## Run: godot --headless --path . -s res://tests/test_game_skin_battle.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const UiSkin := preload("res://ui/play/ui_skin.gd")
const BattleSkin := preload("res://ui/play/battle_skin.gd")

var fails := 0
var checks := 0
var app: Node = null


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
	UiSettings.path = "user://test_skin_battle.cfg"
	DirAccess.remove_absolute(UiSettings.path)
	GameDynasty.save_path = "user://test_skin_battle_save.json"
	UiSettings.scale = 1.0
	UiSettings.set_access("reduced_motion", true)
	root.size = Vector2i(1280, 720)
	test_piece()
	await test_frame()
	await test_result()
	await test_hc()
	await test_old_look()
	await test_same_fight()
	if app != null:
		app.queue_free()
	DirAccess.remove_absolute(UiSettings.path)
	print("battle skin tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _battle(party: bool = true, seed_: int = 77) -> Node:
	if app != null:
		app.queue_free()
		await _frames(2)
	app = GameApp.new()
	root.add_child(app)
	await _frames(3)
	app.closed_badly = false
	app.new_game("Tess", "warrior", "faetouched", seed_, "human")
	var d: GameDynasty = app.dynasty
	d.pending_event = {}
	d.heir.level = 18
	d.world.visit("kingshold")
	d.world.location = "kingshold"
	if party:
		for id in ["bren_cask", "sister_oriel"]:
			d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": 18, "gen": 1, "due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
			d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0, "fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
		d.party.rest(d)
	d.heir.full_heal()
	d.start_hunt("hunt")
	d.auto_battle = false
	app.show_state()
	await _frames(4)
	return app.current


## Waits until the screen has played what it was asked (a blow's animation and the pause after it).
func _settle(bv: Node) -> void:
	await _frames(2)
	var n := 0
	while bv.busy and n < 600:
		await _frames(1)
		n += 1


func _all(n: Node, out: Array) -> Array:
	out.append(n)
	for c in n.get_children():
		_all(c, out)
	return out


func _textured(n: Node) -> int:
	var k := 0
	for x in _all(n, []):
		if x is PanelContainer and x.has_theme_stylebox_override("panel") and x.get_theme_stylebox("panel") is StyleBoxTexture:
			k += 1
	return k


func _button(n: Node, text: String) -> Button:
	for b in n.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(text):
			return b
	return null


func test_piece() -> void:
	ok(UiSkin.validate().is_empty(), "the skin's data is sound with the button piece: %s" % str(UiSkin.validate()))
	var bad: Dictionary = UiSkin.data().duplicate(true)
	bad["pieces"]["button"]["base"] = [4, 4]
	ok(not UiSkin.validate(bad).is_empty(), "a button piece with no middle is found")
	var bad2: Dictionary = UiSkin.data().duplicate(true)
	bad2["pieces"]["button"] = "x"
	ok(not UiSkin.validate(bad2).is_empty(), "a button piece that is not an object is found")
	var p := UiSkin.pixel()
	var base: Array = UiSkin.piece("button")["base"]
	var seen := {}
	for st in ["normal", "hover", "pressed", "disabled"]:
		var t := UiSkin.button_tex(int(base[0]) * p, int(base[1]) * p, st, "parch")
		ok(t.get_width() % p == 0 and t.get_height() % p == 0, "the %s button is a whole multiple of the pixel" % st)
		ok(UiSkin.button_tex(int(base[0]) * p, int(base[1]) * p, st, "parch") == t, "and is made once")
		seen[t.get_image().get_data().hex_encode().sha1_text()] = true
	ok(seen.size() == 4, "the four states look different")
	var sb := UiSkin.button_box("hover", "parch")
	ok(sb.texture_margin_left == float(int(UiSkin.piece("button")["margin"]) * p), "the button's border is not stretched")
	var lit := UiSkin.button_tex(int(base[0]) * p, int(base[1]) * p, "hover", "parch").get_image().get_pixel(2 * p, 2 * p)
	ok(lit == UiSkin.pal("gold_hi"), "a pointed-at button has lit gold studs")
	ok(UiSkin.contrast(UiSkin.pal("crimson_dk"), UiSkin.pal("parch_hi")) >= 7.0, "a lit button's text reads")


func test_frame() -> void:
	var bv: Node = await _battle(true)
	ok(bv.skinned and BattleSkin.on(bv), "a wide window with a mouse draws the battle in the skin")
	ok(bv.cmd_panel.get_theme_stylebox("panel") is StyleBoxTexture, "the command panel is parchment")
	ok(bv.hint.get_parent() is PanelContainer and bv.hint.get_parent().get_theme_stylebox("panel") is StyleBoxTexture, "its title is a ribbon")
	ok(bv.hint.get_theme_color("font_color") == UiSkin.pal("gold_hi"), "in the ribbon's gold")
	var atk := _button(bv.command_box, "Attack")
	ok(atk != null and atk.get_theme_stylebox("normal") is StyleBoxTexture and atk.get_theme_stylebox("hover") is StyleBoxTexture, "Attack is a gold-studded button")
	ok(atk.get_theme_stylebox("hover") != atk.get_theme_stylebox("normal"), "that lights when pointed at")
	ok(atk.get_theme_stylebox("focus") == UiSkin.button_focus(), "and has a gold focus ring")
	ok(atk.custom_minimum_size.y >= 38.0, "it keeps its height")
	var touch_h := float(UiSettings.setting("touch_target_px"))
	ok(float(atk.get_meta("tap_base")) >= 1.0 and touch_h > 0.0, "its touch height still comes from the kit")
	ok(bv.hero_hp.has_meta("skin_bar") and bv.hero_mp.has_meta("skin_bar"), "the heir's bars are segmented")
	ok(bv.hero_hp.get_meta("skin_bar").thin and bv.hero_hp.get_meta("skin_bar").kind == "hp" and bv.hero_mp.get_meta("skin_bar").kind == "mp", "red for health, blue for mana")
	ok(bv.ally_nodes.size() == 2 and bv.ally_nodes[0]["hp"].has_meta("skin_bar"), "and the companions'")
	ok(bv.strip != null and bv.strip.skinned, "the party strip takes the skin's palette")
	ok(bv.log_lines.size() >= 2, "the log keeps its lines")
	var parsed: String = bv.log_label.get_parsed_text().strip_edges()
	ok(parsed.contains("A battle begins!") and parsed.contains("fight beside"), "all of them are shown: %s" % parsed.left(60))
	var bb := BattleSkin.log_bb("[color=#e0605a]ouch[/color]", true)
	ok(bb.contains("bgcolor=#" + UiSkin.pal("gold").to_html(false)) and not bb.contains("e0605a"), "the newest line is lit gold, its colours put on parchment")
	ok(not BattleSkin.log_bb("old", false).contains("bgcolor"), "older lines are plain ink")
	bv._open_skills()
	await _frames(2)
	ok(bv.skill_list != null, "the skills list opens")
	var panel: Node = null
	for n in _all(bv.skill_list, []):
		if n is PanelContainer and n.has_meta("battle_face"):
			panel = n
	ok(panel != null and panel.get_theme_stylebox("panel") is StyleBoxTexture, "a list is a parchment panel")
	var ribbons := 0
	for n in _all(panel if panel != null else bv, []):
		if n is PanelContainer and n.get_theme_stylebox("panel") == UiSkin.ribbon_box():
			ribbons += 1
	ok(ribbons == 1, "with a ribbon title")
	var close := _button(bv.skill_list, "Close")
	ok(close != null and close.get_theme_stylebox("normal") is StyleBoxTexture, "and gold-studded buttons")
	bv._close_skills()
	# every colour set on a label under a parchment panel can be read
	var worst := 99.0
	for l in _all(bv.cmd_panel, []):
		if l is Label and l != bv.hint and l.has_theme_color_override("font_color") and not (l.get_parent() is BaseButton):
			worst = minf(worst, UiSkin.contrast(l.get_theme_color("font_color"), UiSkin.pal("parch")))
	ok(worst >= 3.0 or worst == 99.0, "the command panel's words read on parchment (%.1f)" % worst)


func test_result() -> void:
	var bv: Node = await _battle(false)
	for k in 80:
		if bv.b.is_over():
			break
		await _settle(bv)
		bv._do(func(): GameTactics.auto_turn(bv.b))
	await _settle(bv)
	ok(bv.result_shown and bv.result_panel != null, "the fight ends in a result")
	ok(bv.result_panel.get_theme_stylebox("panel") is StyleBoxTexture, "on parchment")
	var rib: Control = bv.result_panel.get_child(0).get_child(0)
	ok(rib is PanelContainer and rib.get_theme_stylebox("panel") == UiSkin.ribbon_box(), "under a ribbon")
	var title := rib.get_child(0) as Label
	ok(title != null and title.text in ["VICTORY", "DEFEAT", "ESCAPED"], "carrying the verdict in words: %s" % str(title.text if title != null else ""))
	ok(title.get_theme_color("font_color") == UiSkin.pal("gold_hi") or bv.b.result == "defeat", "gold for a win or an escape")
	var btns: Array = bv.result_panel.find_children("*", "Button", true, false)
	ok(not btns.is_empty() and btns.all(func(x): return x.get_theme_stylebox("normal") is StyleBoxTexture), "its choices are gold-studded buttons")
	var labels: Array = bv.result_panel.find_children("*", "Label", true, false).filter(func(x): return x != title and not (x.get_parent() is BaseButton))
	ok(labels.all(func(x): return UiSkin.contrast(x.get_theme_color("font_color"), UiSkin.pal("parch")) >= 4.5), "the story's lines read on parchment")


func test_hc() -> void:
	UiSettings.set_access("high_contrast", true)
	var bv: Node = await _battle(true)
	var atk := _button(bv.command_box, "Attack")
	ok(atk != null and atk.get_theme_color("font_color") == Color("#000000"), "high contrast: black ink on the buttons")
	ok(UiSkin.pal("parch") == Color("#ffffff") and bv.cmd_panel.get_theme_stylebox("panel") is StyleBoxTexture, "on white parchment")
	ok(UiSkin.validate().is_empty(), "and its contrast figures hold: %s" % str(UiSkin.validate()))
	UiSettings.set_access("high_contrast", false)
	UiSettings.set_access("colour_blind", true)
	var bv2: Node = await _battle(true)
	ok(bv2.skinned and bv2.hero_hp.has_meta("skin_bar"), "colour-blind mode keeps the skin (good and bad come from the kit)")
	UiSettings.set_access("colour_blind", false)


func test_old_look() -> void:
	UiSettings.force_touch = 1
	var bv: Node = await _battle(true)
	ok(not bv.skinned, "a touch screen keeps the older look")
	ok(_textured(bv) == 0, "no parchment or ribbon is drawn on it")
	ok(not bv.hero_hp.has_meta("skin_bar") and bv.log_lines.is_empty(), "or segmented bars, and the log is plain")
	var atk := _button(bv.command_box, "Attack")
	ok(atk != null and not (atk.get_theme_stylebox("normal") is StyleBoxTexture) and atk.custom_minimum_size.y >= float(UiSettings.setting("touch_target_px")), "its buttons stay the kit's, at touch height")
	UiSettings.force_touch = -1
	UiSettings.force_mobile = 1
	var bv2: Node = await _battle(true)
	ok(not bv2.skinned, "a phone too")
	UiSettings.force_mobile = -1
	UiSettings.set_scale(1.5)   # the same window at 150% has 850 units of room: compact
	UiSettings.apply(root)
	await _frames(2)
	var bv3: Node = await _battle(true)
	ok(not bv3.skinned, "and a compact window (%s wide)" % str(UiSettings.room(bv3).x))
	ok(_textured(bv3) == 0, "with nothing in the parchment either")
	UiSettings.set_scale(1.0)
	UiSettings.apply(root)
	await _frames(2)
	var bv4: Node = await _battle(true)
	ok(bv4.skinned, "and back to 100% the skin returns")


## The skin dresses the screen and nothing else: the same seed fights the same fight with it on and off.
func test_same_fight() -> void:
	var logs: Array = []
	for touch in [-1, 1]:
		UiSettings.force_touch = touch
		var bv: Node = await _battle(true, 31)
		for k in 6:
			if bv.b.is_over():
				break
			await _settle(bv)
			bv._do(func(): GameTactics.auto_turn(bv.b))
		await _settle(bv)
		logs.append([bv.b.log.duplicate(), bv.b.events.size(), app.dynasty.heir.hp])
	UiSettings.force_touch = -1
	ok(logs[0][0].size() > 0 and logs[0] == logs[1], "the log, the events and the heir's health are the same in and out of the skin")
