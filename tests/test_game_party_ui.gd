## The party command screen (BattleView + PartyStrip over GameRound): a solo hunt is today's screen
## (no strip, one tap plays the round); with companions the screen asks each member in turn from
## their own skills, spells and feats, queues the choices and plays the round on Fight!. Covers the
## step-through states (active member, Back, Repeat, Auto, Flee, held and fallen members, one manual
## member plays at once), the touch sizes, that nothing is clipped at the phone and tablet shapes and
## every text size for one to four members with long names, that a text-size or touch-layout change
## mid-round keeps the queue, the heal and area aims, hold-for-details on the chips, and a scripted
## fight to the end through the buttons.
## Run: godot --headless --path . -s res://tests/test_game_party_ui.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const MenuPanel := preload("res://ui/play/menu_panel.gd")
const TouchHint := preload("res://ui/play/touch_hint.gd")
const Kit := preload("res://ui/play/ui_kit.gd")
const DIR := "user://test_party_ui/"
const LONG := ["tarsk_ember_eye", "corwin_saltmere", "hulda_stonebrow"]   # the longest names in the data
const MIXED := ["sister_oriel", "bren_cask", "tarsk_ember_eye"]          # cleric, warrior, spellblade

var checks := 0
var fails := 0
var app: Node
var d: GameDynasty
var bv: Control


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
	await _frames(2)
	var only: PackedStringArray = []   # -- only=a,b runs just those tests (used to check a test against a mutation)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5).split(",")
	for name in ["solo_is_today", "step_through", "auto_and_single_manual", "repeat_and_back", "flee", "held_and_fallen", "master_auto",
			"aims", "chip_hold", "relayout_keeps_state", "chips_lit_and_cleared", "double_taps", "busy_guards", "round_hint", "take_over_and_turns",
			"cues", "touch_and_fit", "end_to_end"]:
		if only.is_empty() or name in only:
			await call("test_" + name)
	print("party ui tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


# ---------------------------------------------------------------- scaffolding

## A battle of `foes` wolves against the heir and the companions `ids` (all at `level`). Sturdy wolves
## bite for little, so rounds can be played without anyone falling.
func _fight(cls: String, ids: Array, foes: int = 3, level: int = 40, sturdy: bool = true, heir_name: String = "Tess") -> void:
	app.new_game(heir_name, cls, "faetouched", 77, "human")
	d = app.dynasty
	d.pending_event = {}
	d.heir.level = level
	d.heir.potions = 3
	d.heir.learn_spells()
	d.world.visit("kingshold")
	for id in ids:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": level, "gen": 1,
			"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
		d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
			"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	d.party.rest(d)
	d.heir.full_heal()
	var list: Array = []
	for i in foes:
		list.append(d._make_enemy(GameCombat.creature_def("wolf"), 1.0, 1.0, level))
	d._begin_battle(list, "hunt")
	if sturdy:
		for e in d.battle.enemies:
			e["hp"] = 10000000
			e["max_hp"] = 10000000
			e["atk"] = 4.0
	d.auto_battle = false
	app.show_state()
	await _frames(5)
	bv = app.current


func _buttons(n: Node, prefix: String = "", out: Array = []) -> Array:
	if n is Button and (n as Button).is_visible_in_tree() and (n as Button).text.begins_with(prefix):
		out.append(n)
	for c in n.get_children():
		_buttons(c, prefix, out)
	return out


func _texts(n: Node) -> Array:
	return _buttons(n).map(func(x): return (x as Button).text.replace("\n", " / "))


func _find(n: Node, prefix: String) -> Button:
	var all := _buttons(n, prefix)
	return null if all.is_empty() else all[0]


## Presses the visible, enabled command button whose text starts with `prefix`.
func _press(prefix: String, host: Node = null) -> bool:
	for btn in _buttons(host if host != null else bv.command_box, prefix):
		if not (btn as Button).disabled:
			(btn as Button).pressed.emit()
			await _frames(3)
			return true
	return false


func _idle() -> void:
	for k in 200:
		if not bv.busy:
			break
		await create_timer(0.1).timeout
	await _frames(3)


func _chip(by: int) -> Button:
	return bv.strip.chips[by]["btn"]


func _view() -> Dictionary:
	return bv.cmd_round.view()


# ---------------------------------------------------------------- the tests

## No companions: no strip, no confirm, no round controls; one tap plays the round.
func test_solo_is_today() -> void:
	await _fight("warrior", [])
	ok(bv.strip == null, "a solo hunt has no strip")
	var texts := _texts(bv.command_box)
	ok(texts.has("Attack") and texts.has("Defend") and texts.has("Flee"), "the usual commands: %s" % str(texts))
	ok(_find(bv.command_box, "Auto") == null and _find(bv.command_box, "Back") == null and _find(bv.command_box, "Repeat") == null, "no round controls")
	ok(bv.hint.text == "Commands  (click an enemy to target it)", "the plain hint: %s" % bv.hint.text)
	var turn: int = d.battle.turn
	await _press("Attack")
	ok(d.battle.turn == turn + 1, "one tap plays the round at once")
	await _idle()
	ok(_find(bv.command_box, "Fight!") == null and _find(bv.command_box, "Attack") != null, "and the commands come back, no Fight! step")
	ok(_find(bv.command_box, "Repeat") == null, "a solo hunt never offers Repeat")


## Heir, then each companion from their own kit; Fight! plays everyone's choice together.
func test_step_through() -> void:
	await _fight("warrior", MIXED)
	ok(bv.strip != null and bv.strip.chips.size() == 4, "a party of four has four chips")
	ok(int(_view()["cursor"]) == -1 and bv.active_by == -1, "the heir is asked first")
	ok(_find(bv.command_box, "Back") == null, "no Back for the first member")
	ok(_find(bv.command_box, "Auto") != null, "but Auto")
	ok(_find(bv.command_box, "Fight!") == null, "no Fight! until everyone has chosen")
	var turn: int = d.battle.turn
	await _press("Attack")
	ok(d.battle.turn == turn and int(_view()["cursor"]) == 0, "Attack queues and asks the next member (turn unchanged)")
	ok(bv.hint.text.begins_with("Sister Oriel (2 of 4)"), "the hint names her: %s" % bv.hint.text)
	ok(_find(bv.command_box, "Heal") != null and _find(bv.command_box, "Power Strike") == null, "the cleric's own heal is offered, not the heir's skills: %s" % str(_texts(bv.command_box)))
	ok(_find(bv.command_box, "Back") != null, "Back is there from the second member on")
	ok(_chip(-1).text.contains("Attack"), "the heir's chip says what was chosen: %s" % _chip(-1).text)
	await _press("Defend")
	await _press("Power Strike")
	ok(bv.hint.text.begins_with("Tarsk"), "the spellblade is last: %s" % bv.hint.text)
	ok(_find(bv.command_box, "Spells") != null, "with spells")
	await _press("Attack")
	var fight := _find(bv.command_box, "Fight!")
	ok(fight != null and not fight.disabled and d.battle.turn == turn, "everyone chose: Fight! waits, nothing has played")
	ok(_find(bv.command_box, "Back") != null, "Back stays beside it")
	var log_from: int = d.battle.log.size()
	fight.pressed.emit()
	await _frames(2)
	await _idle()
	ok(d.battle.turn == turn + 1, "Fight! plays exactly one round")
	var lines: String = "\n".join(d.battle.log.slice(log_from))
	ok(lines.contains("Tess") and lines.contains("Oriel") and lines.contains("Bren") and lines.contains("Tarsk"), "the log has a line for each member")
	ok(int(_view()["cursor"]) == -1 and bv.hint.text.begins_with("Tess (1 of 4)"), "the next round asks the heir again")
	ok(not bv.strip.get_children().is_empty() and _chip(0).text.contains("Choose"), "and the chips are empty again")


## Auto on a member skips them; with one manual member a pick plays at once; an Auto chip takes over.
func test_auto_and_single_manual() -> void:
	await _fight("warrior", MIXED)
	await _press("Auto")
	ok(bool(bv.cmd_round.auto[-1]) and int(_view()["cursor"]) == 0, "Auto on the heir asks the cleric next")
	ok(_chip(-1).text.contains("Auto"), "the heir's chip says Auto: %s" % _chip(-1).text)
	await _press("Auto")
	await _press("Auto")
	ok(int(_view()["cursor"]) == 2, "the warrior is next, then the spellblade")
	await _press("Auto")
	ok(_find(bv.command_box, "Fight!") != null and bv.hint.text == "Everyone fights on their own.", "everyone Auto: Fight! only")
	var turn: int = d.battle.turn
	# Tap the cleric's Auto chip: she is asked again; she is the only manual member, so a pick plays at once.
	_chip(0).pressed.emit()
	await _frames(3)
	ok(not bool(bv.cmd_round.auto[0]) and int(_view()["cursor"]) == 0, "tapping an Auto chip takes over")
	ok(_find(bv.command_box, "Fight!") == null, "and asks her")
	await _press("Attack")
	ok(d.battle.turn == turn + 1, "one manual member: the pick plays the round at once")
	await _idle()
	ok(bool(bv.cmd_round.auto[-1]) and not bool(bv.cmd_round.auto[0]), "the switches are remembered for the next round")
	ok(d.auto_party.get("heir", false) == true, "and kept for the dynasty")


## Repeat on the second round, Back after a choice; never both; Back goes to the member before.
func test_repeat_and_back() -> void:
	await _fight("warrior", MIXED)
	ok(_find(bv.command_box, "Repeat") == null, "no Repeat on the first round")
	for k in 4:
		await _press("Attack")
	await _press("Fight!", bv.command_box)
	await _idle()
	ok(_find(bv.command_box, "Repeat") != null and _find(bv.command_box, "Back") == null, "round two: Repeat, no Back")
	await _press("Repeat")
	ok(_find(bv.command_box, "Fight!") != null, "Repeat queues everyone and waits for Fight!")
	ok(_find(bv.command_box, "Repeat") == null, "Repeat is gone once used")
	var turn: int = d.battle.turn
	await _press("Back")
	ok(int(_view()["cursor"]) == 2 and d.battle.turn == turn, "Back asks the last member again")
	ok(_find(bv.command_box, "Repeat") == null and _find(bv.command_box, "Back") != null, "never Repeat beside Back")
	ok(bv.back() and int(_view()["cursor"]) == 1, "the Android back button undoes a member too")
	ok(not bv.cmd_round.view()["can_repeat"], "nothing to repeat while choices stand")


## A Flee from any member covers the party; the button reads Flee!.
func test_flee() -> void:
	await _fight("warrior", MIXED)
	await _press("Attack")
	await _press("Flee")
	var go := _find(bv.command_box, "Flee!")
	ok(go != null and _find(bv.command_box, "Fight!") == null, "the confirm reads Flee!")
	ok(bv.hint.text == "The party flees.", "and says the party flees: %s" % bv.hint.text)
	ok(_chip(1).text.contains("Covers") or _chip(1).text.contains("Cover"), "the others are covered: %s" % _chip(1).text)
	await _press("Back")
	ok(_find(bv.command_box, "Flee!") == null and int(_view()["cursor"]) == 0, "Back takes the Flee back")


## A held member is never asked; a fallen one is greyed and inert; one falling in a round shows next round.
func test_held_and_fallen() -> void:
	await _fight("warrior", MIXED)
	d.battle.heir_skip = true
	bv.cmd_round.begin_round()
	bv._build_commands()
	await _frames(3)
	ok(int(_view()["cursor"]) == 0 and bv.hint.text.begins_with("Sister Oriel"), "a stunned heir is skipped; the cleric is asked first: %s" % bv.hint.text)
	ok(_chip(-1).text.contains("Held"), "the heir's chip says Held: %s" % _chip(-1).text)
	var before := str(bv.cmd_round.cursor)
	_chip(-1).pressed.emit()
	await _frames(2)
	ok(str(bv.cmd_round.cursor) == before, "a held chip is inert")
	d.battle.heir_skip = false
	d.battle.allies[1].hp = 0
	bv.cmd_round.begin_round()
	bv._build_commands()
	await _frames(3)
	ok(_chip(1).disabled and _chip(1).text.contains("Down"), "a fallen companion's chip is greyed: %s" % _chip(1).text)
	for k in 3:
		await _press("Attack")
	ok(_find(bv.command_box, "Fight!") != null and not bv.hint.text.contains("Bren"), "the fallen are never asked: 3 choices and Fight!")
	# A solo held heir waits its moment, then passes.
	await _fight("warrior", [])
	d.battle.heir_skip = true
	bv.cmd_round.begin_round()
	var turn: int = d.battle.turn
	bv._build_commands()
	await _frames(2)
	ok(bv.hint.text.ends_with("cannot act this turn.") and _buttons(bv.command_box).is_empty(), "a solo heir held: no commands, '%s'" % bv.hint.text)
	await create_timer(float(UiSettings.setting("held_pass_seconds")) + 0.4).timeout
	await _idle()
	ok(d.battle.turn == turn + 1, "and the turn passes by itself")


func test_master_auto() -> void:
	await _fight("warrior", MIXED)
	d.auto_battle = true
	bv.set_auto(true)
	await _frames(3)
	ok(not bv.strip.visible, "the strip is out of the way while auto-battle fights")
	ok(_find(bv.command_box, "Take over") != null and _find(bv.command_box, "Fight!") == null, "only Take over is offered")
	bv.set_auto(false)
	await _frames(3)
	ok(bv.strip.visible and _find(bv.command_box, "Attack") != null, "taking over brings the strip and a fresh round back")
	await _fight("warrior", MIXED)
	d.auto_battle = true
	d.command_round = null
	app.show_state()
	await _frames(4)
	ok(app.current.cmd_round == null and d.command_round == null, "a hunt that starts on auto-battle never creates a command round")
	d.battle = null


## A mage companion's area spell previews from her own place; a heal asks whom and picks by chip.
func test_aims() -> void:
	await _fight("warrior", ["sister_oriel", "tarsk_ember_eye"], 4)
	await _press("Attack")
	ok(await _press("Heal"), "the cleric has Heal")
	ok(not bv.aiming.is_empty() and str(bv.aiming["aim"]) == "ally", "a single heal asks whom: %s" % bv.hint.text)
	ok(_find(bv.command_box, "Most hurt") != null and _find(bv.command_box, "Cancel") != null, "with Most hurt and Cancel")
	_chip(-1).pressed.emit()
	await _frames(3)
	ok(bv.aiming.is_empty() and int(_view()["cursor"]) == 1, "a chip picks the target and the next member is asked")
	ok(bv.cmd_round.entries[0]["cmd"]["target"] == "heir", "the heal is aimed at the heir")
	await _press("Back")
	ok(await _press("Heal"), "Heal again")
	await _press("Cancel")
	ok(bv.aiming.is_empty() and int(_view()["cursor"]) == 0 and not bv.cmd_round.entries.has(0), "Cancel returns to the same member, nothing queued")
	await _press("Attack")
	# The spellblade's area skill or spell, aimed from her own place.
	var area := {}
	for row in bv.cmd_round.menu(1):
		if row["enabled"] and row["aim"] == "area" and row["group"] in ["skill", "spell"]:
			area = row
			break
	ok(not area.is_empty(), "the spellblade has an area move")
	if area.is_empty():
		return
	bv._choose(area)
	await _frames(3)
	ok(not bv.aiming.is_empty() and int(bv.aiming["by"]) == 1, "aiming it for the spellblade")
	ok(not bv.shown.is_empty() and int(bv.shown["by"]) == 1, "the preview is drawn for her: %s" % str(bv.shown.get("by")))
	var origin: Vector2 = d.battle.cast_point(1)
	ok(origin != d.battle.cast_point(-1), "from a place of her own")
	bv._confirm_aim()
	await _frames(3)
	ok(bv.aiming.is_empty() and bv.cmd_round.entries.has(1), "confirming queues it (nothing is cast yet)")
	ok(str(bv.cmd_round.entries[1]["cmd"]["target"]).begins_with("enemy:"), "aimed at a foe")


func test_chip_hold() -> void:
	await _fight("warrior", MIXED)
	var btn := _chip(0)
	app.hints.set_process(false)
	app.hints.hide_hint()
	var at := btn.get_global_rect().get_center()
	var t := InputEventScreenTouch.new()
	t.position = root.get_final_transform() * at
	t.pressed = true
	Input.parse_input_event(t)
	await _frames(1)
	app.hints.tick(0.6)
	ok(app.hints.shown_text == btn.tooltip_text and btn.tooltip_text.contains("Sister Oriel"), "a hold on a chip shows its tooltip: %s" % app.hints.shown_text.left(60))
	t = t.duplicate()
	t.pressed = false
	Input.parse_input_event(t)
	await _frames(2)
	app.hints.hide_hint()
	ok(int(_view()["cursor"]) == -1 and _view()["can_back"] == false, "and changes nothing")
	app.hints.set_process(true)


## A text-size or touch-layout change mid-round keeps the queue and the asked member.
func test_relayout_keeps_state() -> void:
	await _fight("warrior", MIXED)
	await _press("Attack")
	await _press("Defend")
	var snap := JSON.stringify([bv.cmd_round.entries, bv.cmd_round.cursor, bv.cmd_round._order])
	var tall_before: int = bv.command_box.get_children().filter(func(c): return c is VBoxContainer and c.get_child_count() > 2).size()
	ok(tall_before > 0, "at 100%% the room is tall: columns of three (%d)" % tall_before)
	var m: Control = app.open_menu()
	await _frames(2)
	for b in _buttons(m, "150%"):
		(b as Button).pressed.emit()
	await _frames(4)
	ok(app.current == bv and JSON.stringify([bv.cmd_round.entries, bv.cmd_round.cursor, bv.cmd_round._order]) == snap, "the queue and the asked member survive a text-size change")
	ok(bv.hint.text.begins_with("Bren Cask (3 of 4)"), "the same member is asked: %s" % bv.hint.text)
	ok(_chip(-1).text.contains("Atk") or _chip(-1).text.contains("Attack"), "the chips still show the choices: %s" % _chip(-1).text)
	ok(_buttons(bv.command_box, "Attack").size() == 1, "one command grid, no duplicates")
	var tall_cols: int = bv.command_box.get_children().filter(func(c): return c is VBoxContainer and c.get_child_count() > 2).size()
	ok(tall_cols == 0, "the commands were laid out again for the short room (no column of three, %d)" % tall_cols)
	UiSettings.force_touch = 1
	bv.relayout()
	await _frames(4)
	ok(JSON.stringify([bv.cmd_round.entries, bv.cmd_round.cursor, bv.cmd_round._order]) == snap, "nor a touch-layout change")
	UiSettings.force_touch = 0
	app.set_ui_scale(1.0)
	await _frames(3)
	for c in bv.get_children():
		if c is MenuPanel:
			c.queue_free()
	await _frames(2)


# ---------------------------------------------------------------- sizes

func _clipped(n: Node, within: Rect2, out: Array = []) -> Array:
	if n is Button and (n as Button).is_visible_in_tree():
		var btn := n as Button
		var font := btn.get_theme_font("font")
		var fs := btn.get_theme_font_size("font_size")
		var inner := btn.size.x - btn.get_theme_stylebox("normal").get_minimum_size().x
		var longest := 0.0
		var lines := btn.text.split("\n")
		for line in lines:
			longest = maxf(longest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		if longest > inner + 0.5:
			out.append("'%s' needs %.0f of %.0f" % [btn.text.replace("\n", " / "), longest, inner])
		elif not within.grow(1.0).encloses(btn.get_global_rect()):
			out.append("'%s' sticks out %s of %s" % [btn.text.replace("\n", " / "), str(btn.get_global_rect()), str(within)])
		var tall := font.get_height(fs) * lines.size() + float(btn.get_theme_constant("line_spacing")) * float(lines.size() - 1) + btn.get_theme_stylebox("normal").get_minimum_size().y
		if btn.get_parent() is HBoxContainer and btn.get_parent().get_script() != null and tall > btn.size.y + 0.5:   # a chip: two lines in its height
			out.append("'%s' is %.0f tall in %.0f" % [btn.text.replace("\n", " / "), tall, btn.size.y])
	for c in n.get_children():
		_clipped(c, within, out)
	return out


func _outside(n: Node, room: Rect2, out: Array) -> void:
	if n is Control and (n as Control).is_visible_in_tree():
		var c := n as Control
		var r := c.get_global_rect()
		var p := c.get_parent()
		var clipped := false
		while p != null:
			if p is ScrollContainer or (p is Control and (p as Control).clip_contents):
				clipped = true
				break
			p = p.get_parent()
		if r.size.x > 0 and r.size.y > 0 and not clipped and not room.grow(1.0).encloses(r):
			out.append("%s '%s' %s" % [c.get_class(), str(c.get("text")).left(24) if c.get("text") != null else "", str(r)])
	for ch in n.get_children():
		_outside(ch, room, out)


const SHAPES := [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(2400, 1080), Vector2i(1280, 800)]


## Touch targets at every shape and text size, and nothing clipped, for one to four members with
## long names, at the first member, a later one, an aim and the confirm.
func test_touch_and_fit() -> void:
	UiSettings.force_touch = 1
	var tap := float(UiSettings.setting("touch_target_px"))
	for wsize in SHAPES:
		root.size = wsize
		for s in UiSettings.scales():
			app.set_ui_scale(s)
			await _frames(3)
			var tag := "%dx%d %d%%" % [wsize.x, wsize.y, int(round(s * 100.0))]
			for n in [1, 2, 3, 4]:
				var cls: String = ["mage", "warrior", "rogue", "paladin"][n - 1] if wsize.x != 2400 else "spellblade"
				await _fight(cls, LONG.slice(0, n - 1), 3, 120, true, "Bartholomew Ironwood-Vance")
				d.heir.potions = 7
				var room := Rect2(UiSettings.insets.position, UiSettings.room(app))
				var who := "%s %s x%d" % [tag, cls, n]
				var states: Array = ["first"]
				if n > 1:
					states.append_array(["later", "aim", "confirm"])
				for st in states:
					match st:
						"later":
							await _press("Attack")
							await _frames(3)
							ok(_chip(-1).text.contains("Attack"), "%s: the heir's chip keeps the word Attack: %s" % [who, _chip(-1).text.replace("\n", " / ")])
							if n > 2:
								await _press("Defend")
						"aim":
							bv.aiming = {}
							var area: Dictionary = {}
							for row in bv.cmd_round.menu(bv.cmd_round.cursor):
								if row["aim"] == "area" and row["enabled"]:
									area = row
									break
							if not area.is_empty():
								bv._choose(area)
								await _frames(3)
						"confirm":
							if not bv.aiming.is_empty():
								bv._cancel_aim()
							for k in 4:
								if bv.cmd_round.ready():
									break
								await _press("Attack")
					await _frames(3)
					var where := "%s %s" % [who, st]
					var bad := _clipped(bv.command_box, bv.cmd_panel.get_global_rect())
					ok(bad.is_empty(), "%s: no command text is cut off %s" % [where, str(bad)])
					if bv.strip != null:
						bad = _clipped(bv.strip, room)
						ok(bad.is_empty(), "%s: no chip text is cut off %s" % [where, str(bad)])
						ok(bv.strip.chips.size() == n, "%s: %d chips" % [where, n])
						var short: Array = _buttons(bv.strip).filter(func(x): return (x as Button).size.y < tap - 0.5)
						ok(short.is_empty(), "%s: chips are a fingertip tall" % where)
					var small: Array = _buttons(bv.command_box).filter(func(x): return (x as Button).size.y < tap - 0.5)
					ok(small.is_empty(), "%s: round and command buttons are a fingertip tall %s" % [where, str(small.map(func(x): return (x as Button).text))])
					var out: Array = []
					_outside(app.frame, room, out)
					ok(out.is_empty(), "%s: nothing off the screen %s" % [where, str(out.slice(0, 3))])
					ok(bv.arena.size.y >= 120.0, "%s: the arena keeps %.0f px" % [where, bv.arena.size.y])
				d.battle = null
	root.size = Vector2i(1280, 720)
	UiSettings.force_touch = 0
	app.set_ui_scale(1.0)
	await _frames(3)
	# The desktop's chips are 38+ too.
	await _fight("warrior", MIXED)
	ok(_buttons(bv.strip).all(func(x): return (x as Button).size.y >= 38.0), "desktop chips are at least the designed height")
	d.battle = null


## A whole fight through the buttons: four members, Fight! each round, the hunt is won, the loot
## panel comes as ever.
func test_end_to_end() -> void:
	await _fight("warrior", MIXED, 2, 40, false)
	for e in d.battle.enemies:
		e["hp"] = 400
		e["max_hp"] = 400
	var rounds := 0
	for k in 40:
		if bv.result_shown:
			break
		if _find(bv.command_box, "Fight!") != null:
			await _press("Fight!")
			rounds += 1
		elif _find(bv.command_box, "Attack") != null:
			await _press("Attack")
		await _idle()
	ok(bv.result_shown, "the fight ended through the screen")
	ok(rounds >= 1, "after %d rounds of Fight!" % rounds)
	await _frames(4)
	ok(_find(bv, "Continue") != null or _find(bv, "Search") != null, "the result panel offers its usual way on")
	ok(d.loot.is_empty() or _find(bv, "Search the bodies") != null, "the loot choice, if any, is the usual one")
	if _find(bv, "Search the bodies") != null:
		(_find(bv, "Search the bodies")).pressed.emit()
		await _frames(3)
		ok(_find(bv, "Continue") != null, "searching ends in Continue")
	app.show_state()
	await _frames(3)


# ---------------------------------------------------------------- review fixes

func _border(btn: Button) -> Color:
	return (btn.get_theme_stylebox("normal") as StyleBoxFlat).border_color


## A round's lighting ends with it: dimmed foes' phase and the lit acting chip are cleared, and a
## queued chip is green, the asked one gold.
func test_chips_lit_and_cleared() -> void:
	await _fight("warrior", MIXED)
	ok(_border(_chip(-1)) == Kit.ACCENT, "the asked member's chip has the gold outline")
	await _press("Attack")
	ok(_border(_chip(-1)) == Kit.GOOD and _border(_chip(0)) == Kit.ACCENT, "a queued chip is green, the next one gold")
	bv.strip.mark_acting(0)
	ok(_chip(0).modulate.r > 1.0 and _chip(-1).modulate.r < 1.0 and _chip(1).modulate.r < 1.0, "the acting member's chip is lit, the others dimmed")
	bv.strip.mark_acting(-2)
	ok(_buttons(bv.strip).all(func(x): return (x as Button).modulate.r < 1.0), "the foes' phase dims every chip")
	bv.strip.mark_acting(-3)
	ok(_buttons(bv.strip).all(func(x): return (x as Button).modulate == Color.WHITE), "and -3 clears the lighting")
	for k in 3:
		await _press("Attack")
	await _press("Fight!")
	await _idle()
	ok(_buttons(bv.strip).all(func(x): return (x as Button).modulate == Color.WHITE), "chips are not dimmed when the next round is asked")
	bv.strip.mark_acting(-2)   # even if something left them dim, the strip is redrawn clean
	bv.strip.refresh(_view(), int(_view()["cursor"]))
	ok(_buttons(bv.strip).all(func(x): return (x as Button).modulate == Color.WHITE), "a redraw resets the lighting")


func _touch_at(p: Vector2, up: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = root.get_final_transform() * p
	t.pressed = not up
	Input.parse_input_event(t)
	Input.flush_buffered_events()
	await _frames(1)


## Two taps of a finger on the same spot, one frame apart: the second lands on whatever the first built.
func _double_tap(c: Control) -> void:
	await create_timer(float(UiSettings.setting("tap_guard_ms")) / 1000.0 + 0.1).timeout   # the first tap finds the panel settled
	var at := c.get_global_rect().get_center()
	for k in 2:
		await _touch_at(at, false)
		await _touch_at(at, true)
	await _frames(2)
	TouchHint.finger = false


func test_double_taps() -> void:
	UiSettings.force_touch = 1
	await _fight("warrior", MIXED)
	var flee := _find(bv.command_box, "Flee")
	var turn: int = d.battle.turn
	await _double_tap(flee)
	ok(d.battle.result == "" and d.battle.turn == turn, "a double tap on Flee does not run the party away")
	ok(int(bv.cmd_round.flee_by) == -1 and _find(bv.command_box, "Flee!") != null, "the Flee is queued and waits for its confirm")
	await _press("Back")
	# Potion for the heir: one queued choice, the second tap must not hit Flee for the next member.
	await _double_tap(_find(bv.command_box, "Potion"))
	ok(bv.cmd_round.entries.size() == 1 and bv.cmd_round.entries.has(-1) and bv.cmd_round.flee_by == -2 and int(_view()["cursor"]) == 0, "a double tap on Potion queues one potion and no flee (entries %s)" % str(bv.cmd_round.entries.keys()))
	await _press("Back")
	await _double_tap(_find(bv.command_box, "Attack"))
	ok(bv.cmd_round.entries.size() == 1 and int(_view()["cursor"]) == 0, "a double tap on Attack queues one member's choice")
	for k in 3:
		await _press("Attack")
	await _double_tap(_find(bv.command_box, "Back"))
	ok(bv.cmd_round._order.size() == 3, "a double tap on Back undoes one member only (%d queued)" % bv.cmd_round._order.size())
	await _press("Attack")
	turn = d.battle.turn
	await _double_tap(_find(bv.command_box, "Fight!"))
	await _idle()
	ok(d.battle.turn == turn + 1 and bv.cmd_round.entries.is_empty() and int(_view()["cursor"]) == -1, "a double tap on Fight! plays one round and picks nothing after it")
	# A mouse is not held up: clicks right after a rebuild still act.
	TouchHint.finger = false
	await _press("Attack")
	ok(bv.cmd_round.entries.has(-1), "a click is never ignored")
	UiSettings.force_touch = 0


func test_busy_guards() -> void:
	await _fight("warrior", MIXED)
	for k in 4:
		await _press("Attack")
	await _press("Fight!")
	ok(bv.busy, "the round is playing")
	var turn: int = d.battle.turn
	bv._on_chip(0)
	bv._undo()
	bv._commit()
	ok(_buttons(bv.command_box).is_empty(), "taps on chips or buttons while it plays build nothing")
	await _idle()
	ok(d.battle.turn == turn and int(_view()["cursor"]) == -1 and _view()["can_back"] == false, "and change nothing")


## The first-use hint is kept with the device's settings (not the story flags), told once and only
## when the strip is shown.
func test_round_hint() -> void:
	DirAccess.remove_absolute(UiSettings.path)
	await _fight("warrior", MIXED)
	var text: String = bv.log_label.get_parsed_text()
	ok(text.contains("then click Fight! to play the round"), "the hint is told: %s" % text.right(160))
	ok(bool(UiSettings.stored("round_hint", false)) and not d.flags.has("round_hint"), "kept in the settings file, not the story flags")
	ok(not JSON.stringify(d.to_dict()).contains("round_hint"), "nor in the dynasty save")
	await _fight("warrior", MIXED)
	ok(not bv.log_label.get_parsed_text().contains("to play the round"), "and not told again")
	DirAccess.remove_absolute(UiSettings.path)
	await _fight("warrior", MIXED)
	d.battle = null
	DirAccess.remove_absolute(UiSettings.path)
	app.new_game("Tess", "warrior", "faetouched", 77, "human")
	d = app.dynasty
	for id in MIXED:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": 40, "gen": 1, "due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
	d.party.rest(d)
	d._begin_battle([d._make_enemy(GameCombat.creature_def("wolf"), 1.0, 1.0, 40)], "hunt")
	d.auto_battle = true
	d.command_round = null
	app.show_state()
	await _frames(4)
	ok(not bool(UiSettings.stored("round_hint", false)), "an auto-battle that hides the strip does not use up the hint")
	d.battle = null
	DirAccess.remove_absolute(UiSettings.path)


## Taking over from auto-battle starts a fresh round; a turn that passes outside a round reopens it;
## Back does nothing while auto-battle fights.
func test_take_over_and_turns() -> void:
	await _fight("warrior", MIXED)
	await _press("Attack")
	await _press("Defend")
	bv.set_auto(true)
	ok(not bv.back(), "the Android back button undoes nothing while auto-battle fights")
	ok(bv.cmd_round.entries.size() == 2, "and the queue is untouched")
	bv.set_auto(false)
	await _frames(3)
	ok(bv.cmd_round.entries.is_empty() and int(_view()["cursor"]) == -1, "taking over starts a fresh round")
	await _press("Attack")
	var turn: int = d.battle.turn
	bv._do(func(): d.battle.defend())
	await _idle()
	ok(d.battle.turn == turn + 1 and bv.cmd_round.number == d.battle.turn and bv.cmd_round.entries.is_empty(), "a turn that passed outside the round reopens it")
	ok(int(_view()["cursor"]) == -1, "and the heir is asked again")


## What the screen says: why Flee is greyed, how Auto is turned off, who to tap.
func test_cues() -> void:
	await _fight("warrior", MIXED)
	d.battle.heir_skip = true
	bv.cmd_round.begin_round()
	bv._build_commands()
	await _frames(3)
	ok(bv.hint.text.contains("Held fast"), "a greyed Flee says why in the hint: %s" % bv.hint.text)
	d.battle.heir_skip = false
	bv.cmd_round.begin_round()
	bv._build_commands()
	await _press("Auto")
	ok(_chip(-1).text.contains("take over") or _chip(-1).text.contains("(click)") or _chip(-1).text.contains("Auto"), "the Auto chip shows Auto: %s" % _chip(-1).text)
	ok(_chip(-1).tooltip_text.contains("take over"), "its tooltip says how to take over")
	await _press("Auto")
	await _press("Auto")
	await _press("Auto")
	ok(bv.hint.text.contains("take over"), "the confirm says how to take over from Auto: %s" % bv.hint.text)
	await _press("Fight!")
	await _idle()
	# The Heal's "Most hurt" sends no name.
	await _fight("warrior", ["sister_oriel", "tarsk_ember_eye"], 3)
	await _press("Attack")
	await _press("Heal")
	await _press("Most hurt")
	ok(bv.cmd_round.entries[0]["cmd"]["target"] == "", "Most hurt leaves the heal's target to the round")
