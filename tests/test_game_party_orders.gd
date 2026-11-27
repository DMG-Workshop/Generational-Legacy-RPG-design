## The party's one-tap orders and focus (GamePartyOrders, GameRound.set_pin, GameBattle.press_target): the commands the
## Attack / Defend / Skill / Auto buttons give, the All Auto switch, the focus companions on Auto or Attack prefer
## until it falls, its save and old saves, and above all that a fight nobody gave a focus to plays exactly as before.
## Run: godot --headless --path . -s res://tests/test_game_party_orders.gd
extends SceneTree

const Scen := preload("res://tests/round_scenarios.gd")
const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const TouchHint := preload("res://ui/play/touch_hint.gd")
const AllyOrders := preload("res://ui/play/ally_orders.gd")
const BattleSpeed := preload("res://ui/play/battle_speed.gd")
const DIR := "user://test_party_orders/"
const TRIO := ["sister_oriel", "bren_cask", "tarsk_ember_eye"]

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
	DirAccess.make_dir_recursive_absolute(DIR)
	GameDynasty.save_path = DIR + "save.json"
	UiSettings.path = DIR + "settings.cfg"
	UiSettings.scale = 1.0
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	TouchHint.finger = false
	test_data()
	test_rows()
	test_commands()
	test_give_and_auto()
	test_pin_rules()
	test_no_pin_plays_as_before()
	test_pin_steers_auto_and_attack()
	test_pin_saves()
	await test_screen()
	await test_touch_and_solo()
	UiSettings.force_touch = -1
	UiSettings.force_mobile = -1
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
	print("orders tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dynasty(cls: String, level: int = 30, seed_val: int = 77) -> GameDynasty:
	var d := GameDynasty.new_game(seed_val, "Tess", cls, "faetouched", "human")
	d.pending_event = {}
	d.heir.level = level
	d.heir.gold = 5000
	d.heir.potions = 3
	d.heir.learn_spells()
	d.world.visit("kingshold")
	for id in TRIO:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": level, "gen": 1,
			"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
		d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
			"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	d.party.rest(d)
	d.heir.full_heal()
	return d


## A battle of three sturdy wolves with a weak bite, and its command round.
func _round(seed_val: int = 77) -> Array:
	var d := _dynasty("warrior", 30, seed_val)
	var foes: Array = []
	for i in 3:
		foes.append(d._make_enemy(GameCombat.creature_def("wolf"), 1.0, 1.0, d.heir.level))
	d._begin_battle(foes, "hunt")
	for e in d.battle.enemies:
		e["hp"] = 10000000
		e["max_hp"] = 10000000
		e["atk"] = 4.0
	return [d, d.battle, d.battle_round()]


func test_data() -> void:
	ok(GameRound.validate().is_empty(), "the rounds data (pin included) is sound: %s" % str(GameRound.validate()))
	ok(bool(GameRound.setting("pin")["auto"]) and bool(GameRound.setting("pin")["attack"]), "Auto and Attack members follow the focus")


func test_commands() -> void:
	var s := _round()
	var r: GameRound = s[2]
	ok(GamePartyOrders.command(r, 1, "attack") == {"act": "attack", "target": ""}, "Attack with no foe aimed leaves the target to the heir's focus")
	ok(GamePartyOrders.command(r, 1, "attack", "enemy:2") == {"act": "attack", "target": "enemy:2"}, "Attack goes at the foe asked")
	ok(GamePartyOrders.command(r, 1, "attack", "enemy:9") == {"act": "attack", "target": ""}, "a foe that is not there is left to the heir's focus")
	ok(GamePartyOrders.command(r, 1, "defend") == {"act": "defend"}, "Defend")
	ok(GamePartyOrders.command(r, 1, "auto").is_empty(), "Auto is no command")
	var row := GamePartyOrders.skill_row(r, 1)
	ok(not row.is_empty() and str(row["group"]) == "skill" and bool(row["enabled"]), "the skill button takes the first class skill the member can use")
	var sk := GamePartyOrders.command(r, 1, "skill", "enemy:1")
	ok(str(sk.get("act")) == "ability" and str(sk.get("kind")) == "skill" and str(sk["id"]) == str(row["cmd"]["id"]), "Skill is that skill's command")
	if str(row["aim"]) in ["foe", "area"]:
		ok(str(sk["target"]) == "enemy:1", "aimed at the foe asked")
	ok(r.check(1, sk) == "", "and it can be queued")
	r.set_pin("enemy:2")
	ok(GamePartyOrders.command(r, 1, "attack", "enemy:0")["target"] == "enemy:2", "with a focus set, Attack goes to it")
	ok(r.check(-1, GamePartyOrders.command(r, -1, "skill", "enemy:0")) == "" or GamePartyOrders.command(r, -1, "skill", "enemy:0").is_empty(), "the heir's skill is a legal command too")


func test_give_and_auto() -> void:
	var s := _round()
	var r: GameRound = s[2]
	ok(GamePartyOrders.give(r, 0, "attack", "enemy:1") == "", "giving Attack queues it")
	ok(r.entries[0]["cmd"]["target"] == "enemy:1" and r.entries[0]["src"] == "manual", "as a manual choice at the foe")
	ok(GamePartyOrders.give(r, 1, "defend") == "", "giving Defend queues it")
	ok(r.entries[1]["cmd"]["act"] == "defend", "as Defend")
	ok(GamePartyOrders.give(r, 2, "skill", "enemy:0") == "", "giving Skill queues it")
	ok(r.entries[2]["cmd"]["act"] == "ability", "as a skill")
	ok(GamePartyOrders.give(r, 0, "auto") == "" and bool(r.auto[0]) and not r.entries.has(0), "giving Auto switches the member and drops their choice")
	ok(GamePartyOrders.give(r, 0, "defend") == "" and not bool(r.auto[0]) and r.entries[0]["cmd"]["act"] == "defend", "and an order after that takes them off Auto")
	GamePartyOrders.give(r, 0, "auto")
	ok(GamePartyOrders.give(r, 5, "attack") != "" and GamePartyOrders.give(r, 5, "auto") != "", "someone who is not in the fight is refused")
	ok(not GamePartyOrders.all_auto(r), "not everyone is on Auto yet")
	GamePartyOrders.set_all_auto(r, true)
	ok(GamePartyOrders.all_auto(r) and bool(r.auto[0]) and bool(r.auto[1]) and bool(r.auto[2]), "All Auto puts every companion on Auto")
	ok(not bool(r.auto[-1]), "and leaves the heir's own switch")
	ok(r.entries.is_empty() or not r.entries.has(1), "their queued choices are dropped")
	GamePartyOrders.set_all_auto(r, false)
	ok(not GamePartyOrders.all_auto(r) and not bool(r.auto[0]) and not bool(r.auto[2]), "and All Auto off hands them back")
	# A solo hunt has no companions: nothing to switch.
	var d := GameDynasty.new_game(5, "Solo", "warrior", "faetouched", "human")
	d.pending_event = {}
	d._begin_battle([d._make_enemy(GameCombat.creature_def("wolf"), 1.0, 1.0, d.heir.level)], "hunt")
	ok(not GamePartyOrders.all_auto(d.battle_round()), "a lone heir has no companions to be on Auto")


func test_pin_rules() -> void:
	var s := _round()
	var b: GameBattle = s[1]
	var r: GameRound = s[2]
	ok(b.pin == -1 and r.pin_ref() == "", "no focus at first")
	ok(r.set_pin("enemy:1") == "" and b.pin == 1 and r.pin_ref() == "enemy:1", "a standing foe can be the focus")
	ok(r.view()["pin"] == "enemy:1", "the view says so")
	ok(r.set_pin("enemy:7") != "" and b.pin == 1, "a foe that is not there is refused and the focus stays")
	ok(r.set_pin("heir") != "" and b.pin == 1, "so is a member of the party")
	b.enemies[1]["hp"] = 0
	ok(r.pin_ref() == "" and b.press_target("auto") != 1 and b.press_target("attack") != 1, "when it dies nobody follows it any more")
	ok(r.set_pin("enemy:1") != "", "a fallen foe cannot be picked")
	ok(r.set_pin("enemy:2") == "" and b.pin == 2, "another can")
	ok(r.set_pin("") == "" and b.pin == -1, "and the focus can be cleared")


## A battle played through to the end with every companion on Auto, as the dynasty's autopilot would.
func _play(use_pin_api: bool) -> Dictionary:
	var s := _round(31)
	var d: GameDynasty = s[0]
	var b: GameBattle = s[1]
	var r: GameRound = s[2]
	for by in [-1, 0, 1, 2]:
		r.set_auto(by, true)
	if use_pin_api:
		r.set_pin("")
	var events: Array = []
	for i in 6:
		if b.is_over():
			break
		r.resolve()
		events.append_array(b.events.duplicate(true))
	return {"log": b.log.duplicate(), "events": JSON.stringify(events), "state": JSON.stringify(Scen.state_of(b)), "save": JSON.stringify(b.to_dict())}


func test_no_pin_plays_as_before() -> void:
	var a := _play(false)
	var c := _play(true)
	ok(a["log"] == c["log"] and a["events"] == c["events"] and a["state"] == c["state"], "asking for no focus changes nothing in the fight")
	ok(not (JSON.parse_string(a["save"]) as Dictionary).has("pin"), "a fight nobody focused saves with no pin key, as it always did")


## Damage the allies (not the heir) dealt to each foe in a run of rounds.
func _ally_blows(pin_at: int, rounds: int, all_auto: bool) -> Dictionary:
	var s := _round(31)
	var b: GameBattle = s[1]
	var r: GameRound = s[2]
	r.set_auto(-1, false)
	for by in [0, 1, 2]:
		r.set_auto(by, all_auto)
	if pin_at >= 0:
		r.set_pin("enemy:%d" % pin_at)
	var hits := {0: 0, 1: 0, 2: 0}
	for i in rounds:
		if b.is_over():
			break
		for by in r.members():
			if by == -1:
				r.queue(-1, {"act": "attack", "target": "enemy:0"})
			elif not all_auto:
				r.queue(by, {"act": "attack", "target": ""})
		r.resolve()
		var who := -2
		for ev in b.events:
			if str(ev["type"]) == "act":
				who = int(ev["by"])
			elif str(ev["type"]) == "damage" and str(ev.get("side", "")) == "enemy" and who >= 0:
				hits[int(ev["index"])] = int(hits[int(ev["index"])]) + 1
	return hits


func test_pin_steers_auto_and_attack() -> void:
	for all_auto in [true, false]:
		var label := "Auto" if all_auto else "Attack"
		var plain := _ally_blows(-1, 3, all_auto)
		var pinned := _ally_blows(2, 3, all_auto)
		ok(int(pinned[2]) > int(plain[2]), "%s companions land more on the focused foe: %s against %s" % [label, str(pinned), str(plain)])
		if not all_auto:   # a class's area skill on Auto still catches the others it reaches
			ok(int(pinned[1]) == 0, "%s companions leave the other foes alone while the focus stands: %s" % [label, str(pinned)])
	# Until it dies: then they carry on with the heir's focus.
	var s := _round(31)
	var b: GameBattle = s[1]
	var r: GameRound = s[2]
	for by in [-1, 0, 1, 2]:
		r.set_auto(by, true)
	r.set_pin("enemy:2")
	b.enemies[2]["hp"] = 1
	r.resolve()
	ok(b.turn > 0, "the round plays")
	ok(r.pin_ref() == "" or b.enemies[2]["hp"] > 0, "a fallen focus is no focus")


func test_pin_saves() -> void:
	var s := _round()
	var d: GameDynasty = s[0]
	var b: GameBattle = s[1]
	var r: GameRound = s[2]
	r.set_pin("enemy:1")
	var parsed = JSON.parse_string(JSON.stringify(d.to_save()))
	ok(typeof(parsed) == TYPE_DICTIONARY and GameSaveVersion.upgrade(parsed) == "", "a fight with a focus saves")
	var g := GameDynasty.from_dict(parsed)
	ok(g.battle != null and g.battle.pin == 1, "and loads with the focus kept")
	ok(g.battle_round().pin_ref() == "enemy:1", "the round sees it")
	# An old save has no key; a junk one is ignored.
	var old: Dictionary = JSON.parse_string(JSON.stringify(d.to_save()))
	var h := GameDynasty.from_dict(_edited(old, func(bd: Dictionary): bd.erase("pin")))
	ok(h.battle != null and h.battle.pin == -1, "a save from before the focus loads with none")
	var k := GameDynasty.from_dict(_edited(old, func(bd: Dictionary): bd["pin"] = "two"))
	ok(k.battle != null and k.battle.pin == -1, "a damaged focus is ignored")
	var m := GameDynasty.from_dict(_edited(old, func(bd: Dictionary): bd["pin"] = 99))
	ok(m.battle != null and m.battle.pin == -1, "and so is one past the foes")
	ok(b.pin == 1, "(the live fight is untouched)")


## A save whose fight has been changed by `edit` (the fight is kept as Godot's own encoding).
func _edited(save: Dictionary, edit: Callable) -> Dictionary:
	var out := save.duplicate(true)
	var fight: Dictionary = Marshalls.base64_to_variant(str(out["battle"]))
	edit.call(fight["battle"])
	out["battle"] = Marshalls.variant_to_base64(fight)
	return out


func test_rows() -> void:
	var s := _round()
	var r: GameRound = s[2]
	var rows := GamePartyOrders.rows(r)
	ok(rows.size() == 4 and int(rows[0]["by"]) == -1 and int(rows[3]["by"]) == 2, "one entry for the heir and each companion")
	ok(str(rows[1]["decision"]) == "empty" and str(rows[1]["active"]) == "" and str(rows[1]["mark"]) == "", "nobody has an order yet")
	ok(str(rows[1]["skill"]) != "" and str(rows[0]["skill"]) == "", "a companion's Skill button names the skill; the heir has none")
	GamePartyOrders.give(r, 0, "attack", "enemy:1")
	GamePartyOrders.give(r, 1, "defend")
	GamePartyOrders.give(r, 2, "auto")
	rows = GamePartyOrders.rows(r)
	ok(str(rows[1]["active"]) == "attack" and str(rows[1]["mark"]) == "attack", "an Attack is lit and shown")
	ok(str(rows[2]["active"]) == "defend" and str(rows[2]["mark"]) == "defend", "so is a Defend")
	ok(str(rows[3]["active"]) == "auto" and str(rows[3]["mark"]) == "auto", "and an Auto")
	GamePartyOrders.give(r, 0, "skill", "enemy:0")
	ok(str(GamePartyOrders.rows(r)[1]["active"]) == "skill", "and a Skill")
	var spell := r.menu(1).filter(func(x): return x["group"] == "spell" and x["enabled"])
	if not spell.is_empty():
		var c: Dictionary = (spell[0]["cmd"] as Dictionary).duplicate()
		c["target"] = "enemy:0"
		r.queue(0, c)
		ok(str(GamePartyOrders.rows(r)[1]["active"]) == "" and str(GamePartyOrders.rows(r)[1]["mark"]) == "skill", "a spell lights no button but shows as a skill on the figure")
	var b: GameBattle = s[1]
	b.allies[2].hp = 0
	ok(str(GamePartyOrders.rows(r)[3]["state"]) == "ko" and str(GamePartyOrders.rows(r)[3]["mark"]) == "" and str(GamePartyOrders.rows(r)[3]["skill"]) == "", "a fallen member has nothing to show")


# ---------------------------------------------------------------- on the battle screen

func _open_screen(d: GameDynasty) -> Control:
	app.dynasty = d
	d.auto_battle = false
	app.show_state()
	await _frames(4)
	return app.current


func _button(bv: Control, by: int, kind: String) -> Button:
	return bv.orders.cells[by]["buttons"][kind]


func _flag_text(node: Dictionary) -> String:
	return str(node["label"].text) if node["box"].visible else ""


var app: Node


func test_screen() -> void:
	root.size = Vector2i(1280, 720)
	await _frames(2)
	app = GameApp.new()
	root.add_child(app)
	await _frames(2)
	app.new_game("Tess", "warrior", "faetouched", 77, "human")
	ok(AllyOrders.validate().is_empty(), "the orders data passes its own check: %s" % str(AllyOrders.validate()))
	var d := Scen.make(6, "paladin", 2, "hunt")
	var bv: Control = await _open_screen(d)
	var b := d.battle
	var r := d.battle_round()
	ok(bv.orders != null and bv.orders.is_inside_tree() and bv.orders.visible, "a battle with companions has the orders row")
	ok(bv.orders.cells.size() == 3 and bv.orders.focus_button != null and bv.orders.all_auto_button != null, "a cell for each member: the heir's has Focus and All Auto")
	for by in [0, 1]:
		for kind in ["attack", "defend", "skill", "auto"]:
			var btn := _button(bv, by, kind)
			ok(btn.icon != null and btn.text != "" and btn.custom_minimum_size.y >= 40.0, "%s's %s button has an icon, a word and room to tap" % [str(b.unit(by).name), kind])
	ok(_button(bv, 0, "attack").text == "Attack" and _button(bv, 0, "auto").text == "Auto", "the words are short")
	ok(_flag_text(bv.ally_nodes[0]["mark"]) == "", "no order on the figures yet")
	# One tap each.
	_button(bv, 0, "attack").pressed.emit()
	ok(r.entries.has(0) and r.entries[0]["cmd"]["act"] == "attack", "Attack queues the companion's attack")
	ok(_flag_text(bv.ally_nodes[0]["mark"]) == "Attack", "and the figure says Attack")
	ok(bool(_button(bv, 0, "attack").get_meta("lit")) and not bool(_button(bv, 0, "defend").get_meta("lit")), "the button is lit")
	_button(bv, 0, "defend").pressed.emit()
	ok(r.entries[0]["cmd"]["act"] == "defend" and _flag_text(bv.ally_nodes[0]["mark"]) == "Defend", "Defend replaces it and shows")
	_button(bv, 1, "skill").pressed.emit()
	ok(r.entries.has(1) and r.entries[1]["cmd"]["act"] == "ability" and _flag_text(bv.ally_nodes[1]["mark"]) == "Skill", "Skill queues a class skill and shows")
	_button(bv, 1, "auto").pressed.emit()
	ok(bool(r.auto[1]) and not r.entries.has(1) and _flag_text(bv.ally_nodes[1]["mark"]) == "Auto", "Auto switches them over and shows")
	_button(bv, 1, "attack").pressed.emit()
	ok(r.entries.has(1) and not bool(r.auto[1]) and _flag_text(bv.ally_nodes[1]["mark"]) == "Attack", "an order for a companion on Auto takes them off Auto")
	# Focus.
	var foes: Array = b.living_enemies()
	bv.target = int(foes[-1])
	bv._update_marks()
	ok(not bv.enemy_nodes[int(foes[-1])]["focus"]["box"].visible, "no foe is flagged at first")
	bv.orders.focus_button.pressed.emit()
	ok(b.pin == int(foes[-1]) and r.pin_ref() == "enemy:%d" % int(foes[-1]), "Focus pins the foe picked")
	ok(bv.enemy_nodes[int(foes[-1])]["focus"]["box"].visible and bv.enemy_nodes[int(foes[-1])]["focus"]["label"].text == "FOCUS", "and flags it with a word")
	ok(bv.orders.focus_button.text.begins_with("Focus: "), "the button names it: %s" % bv.orders.focus_button.text)
	_button(bv, 0, "attack").pressed.emit()
	ok(r.entries[0]["cmd"]["target"] == "enemy:%d" % int(foes[-1]), "an Attack with a focus set goes to it")
	bv.orders.focus_button.pressed.emit()
	ok(b.pin == -1 and not bv.enemy_nodes[int(foes[-1])]["focus"]["box"].visible and bv.orders.focus_button.text == "Focus", "Focus again lets go")
	# All Auto.
	bv.orders.all_auto_button.pressed.emit()
	ok(GamePartyOrders.all_auto(r) and bv.orders.all_auto_button.text == "All Auto: ON", "All Auto puts the companions on Auto and says so")
	ok(_flag_text(bv.ally_nodes[0]["mark"]) == "Auto" and _flag_text(bv.ally_nodes[1]["mark"]) == "Auto", "and each figure says Auto")
	bv.orders.all_auto_button.pressed.emit()
	ok(not GamePartyOrders.all_auto(r) and bv.orders.all_auto_button.text == "All Auto", "again hands them back")
	# While the round plays the row is off; in auto-battle it is gone.
	_button(bv, 0, "attack").pressed.emit()
	bv.busy = true
	bv._sync_orders()
	ok(_button(bv, 0, "attack").disabled and bv.orders.focus_button.disabled, "the row is off while a round plays")
	_button(bv, 0, "defend").pressed.emit()
	ok(r.entries[0]["cmd"]["act"] == "attack", "and a tap does nothing then")
	bv.busy = false
	bv._sync_orders()
	ok(not _button(bv, 0, "attack").disabled, "and back on after")
	b.allies[1].hp = 0
	bv._sync_orders()
	ok(_button(bv, 1, "attack").disabled and _button(bv, 1, "skill").disabled, "a fallen companion's buttons are off")
	b.allies[1].hp = 50
	bv.set_auto(true)
	await _frames(2)
	ok(not bv.orders.visible and not bv.ally_nodes[0]["mark"]["box"].visible, "auto-battle hides the row and the marks")
	bv.set_auto(false)
	await _frames(2)
	ok(bv.orders.visible, "and taking over brings them back")
	# Everything chosen: the round plays with the one-tap orders, as chosen.
	UiSettings.set_battle_skip(true)
	_button(bv, 0, "attack").pressed.emit()
	_button(bv, 1, "defend").pressed.emit()
	bv.orders.focus_button.pressed.emit()
	var guard := 0
	while r.cursor != -2 and not r.ready() and guard < 6:
		guard += 1
		r.queue(r.cursor, {"act": "attack", "target": ""})
	var turn := b.turn
	r.ask_reactions = false   # (a hurt companion would stop the round on a question; this is about the orders)
	bv._commit()
	await _frames(3)
	guard = 0
	while bv.busy and guard < 200:
		guard += 1
		await process_frame
	ok(b.turn > turn or b.is_over(), "the round played")
	ok(b.events.any(func(ev): return str(ev["type"]) == "defend" and int(ev.get("by", -9)) == 1) or b.is_over(), "the companion who was told to defend defended")
	UiSettings.set_battle_skip(false)
	BattleSpeed.set_speed(1)


func test_touch_and_solo() -> void:
	UiSettings.force_touch = 1
	var d := Scen.make(6, "paladin", 2, "hunt")
	var bv: Control = await _open_screen(d)
	var tall := float(UiSettings.setting("touch_target_px"))
	var all_tall := true
	for by in bv.orders.cells:
		for btn in (bv.orders.cells[by]["buttons"] as Dictionary).values():
			all_tall = all_tall and (btn as Button).custom_minimum_size.y >= tall
	all_tall = all_tall and bv.orders.focus_button.custom_minimum_size.y >= tall and bv.orders.all_auto_button.custom_minimum_size.y >= tall
	ok(all_tall, "on a touch screen every order button is at least %d tall" % int(tall))
	ok(bv.speed_button.custom_minimum_size.y >= tall and bv.skip_button.custom_minimum_size.y >= tall, "and so are the speed and skip buttons")
	UiSettings.force_touch = 0
	# A lone heir has no orders.
	var solo := Scen.make(6, "paladin", 0, "hunt")
	var sv: Control = await _open_screen(solo)
	ok(sv.orders == null, "a solo hunt has no orders row")
	ok(sv.get("strip") == null, "and no party strip, as ever")
