## Reactions that ask first (roadmap item 22): with ask_reactions on, a foe about to strike a member below
## settings.cover_below stops the round to ask which member on manual control steps in front, once per
## covered member a round. Off (tests, scenarios, autopilots), rounds play through as before; letting the
## blow land plays exactly as the old round did. Then the battle screen: the question, and the round
## going on after a button.
## Run: godot --headless --path . -s res://tests/test_game_reaction_prompt.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const TouchHint := preload("res://ui/play/touch_hint.gd")
const TRIO := ["sister_oriel", "bren_cask", "tarsk_ember_eye"]
const DIR := "user://test_reaction_prompt/"

var fails := 0
var checks := 0
var _chance_was: Variant = null


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	_chance_was = GameData.balance["companion_heir_target_chance"]
	GameData.balance["companion_heir_target_chance"] = 1.0   # every foe swings at the heir, so the questions can be counted
	test_off_by_default()
	test_asks_and_waits()
	test_answer_covers()
	test_let_it_land_is_the_old_round()
	test_auto_members_are_not_asked()
	test_standing_cover_first()
	test_fight_ends_on_the_waiting_blow()
	await test_battle_screen()
	GameData.balance["companion_heir_target_chance"] = _chance_was
	print("reaction prompt tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- scaffolding (as in test_game_round)

func _dynasty(seed_val: int = 77) -> GameDynasty:
	var d := GameDynasty.new_game(seed_val, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.level = 30
	d.heir.potions = 0
	d.world.visit("kingshold")
	for id in TRIO:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": 30, "gen": 1,
			"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
		d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
			"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	d.party.rest(d)
	d.heir.full_heal()
	return d


func _foes(d: GameDynasty, atk: float = 4.0) -> void:
	var foes: Array = []
	for i in 3:
		foes.append(d._make_enemy(GameCombat.creature_def("wolf"), 1.0, 1.0, d.heir.level))
	d._begin_battle(foes, "hunt")
	for e in d.battle.enemies:
		e["hp"] = 10000000
		e["max_hp"] = 10000000
		e["atk"] = atk


## A party round against three sturdy foes; the heir is hurt below the cover line.
func _round(seed_val: int = 77, ask: bool = true) -> Array:
	var d := _dynasty(seed_val)
	_foes(d)
	var b := d.battle
	b.heir.hp = maxi(1, int(float(b.unit_numbers(-1)["max_hp"]) * 0.2))
	var r := d.battle_round()
	r.ask_reactions = ask
	for by in r.members():
		r.queue(by, {"act": "attack", "target": "enemy:0"})
	return [d, b, r]


func _events(b: GameBattle, type: String) -> Array:
	return b.events.filter(func(e): return str(e.get("type", "")) == type)


# ---------------------------------------------------------------- the rules

func test_off_by_default() -> void:
	var d := _dynasty()
	_foes(d)
	ok(not d.battle_round().ask_reactions, "a round does not ask unless its caller can answer")
	var t := _round(77, false)
	var r: GameRound = t[2]
	var out := r.resolve()
	ok(bool(out["played"]) and not bool(out["asking"]) and not r.asking(), "with asking off the round plays through")
	ok(_events(t[1], "cover").is_empty(), "and nobody steps in")


func test_asks_and_waits() -> void:
	var t := _round()
	var b: GameBattle = t[1]
	var r: GameRound = t[2]
	var turn := b.turn
	var out := r.resolve()
	ok(bool(out["played"]) and bool(out["asking"]) and r.asking(), "a foe about to strike the hurt heir stops the round to ask")
	var q := r.reaction_view()
	ok(int(q.get("for", -9)) == -1 and q.get("by", []) == [0, 1, 2], "it asks who of the companions steps in front of the heir: %s" % str(q.get("by")))
	ok((q.get("names", []) as Array).size() == 3 and str(q.get("foe_name", "")) != "", "with their names and the foe's")
	ok(b.turn == turn, "the round has not ended while it waits")
	ok(not r.ready() and bool(r.view()["asking"]), "nothing can be queued or played while it waits")
	ok(not bool(r.resolve()["played"]), "a second resolve does nothing")
	var idle := _round(77, true)
	ok(not bool((idle[2] as GameRound).answer(0)["played"]), "an answer with no question does nothing")


func test_answer_covers() -> void:
	var t := _round()
	var b: GameBattle = t[1]
	var r: GameRound = t[2]
	var turn := b.turn
	r.resolve()
	var from := b.events.size()
	var out := r.answer(1)
	var covers := _events(b, "cover")
	ok(covers.size() == 1 and int(covers[0]["by"]) == 1 and int(covers[0]["for"]) == -1, "Bren steps in front of the heir")
	var after: Array = b.events.slice(from)
	var hit := after.filter(func(e): return str(e["type"]) in ["damage", "miss"])
	ok(not hit.is_empty() and str(hit[0]["side"]) == "ally" and int(hit[0].get("ally", -1)) == 1, "and takes the waiting blow")
	ok(bool(out["played"]) and not bool(out["asking"]), "the heir is not asked about again this round, so it plays out")
	ok(b.turn == turn + 1 and r.number == b.turn and not r.asking(), "the round ends and the next one opens")
	ok(b.log.any(func(l): return str(l).contains("steps in front of")), "the log says who stepped in")


## Letting the blow land plays exactly as a round that never asked: same log, health, events and turn.
func test_let_it_land_is_the_old_round() -> void:
	var a := _round(91, false)
	var c := _round(91, true)
	(a[2] as GameRound).resolve()
	var rc: GameRound = c[2]
	var out := rc.resolve()
	var asked := 0
	while bool(out.get("asking", false)) and asked < 10:
		asked += 1
		out = rc.answer(-2)
	ok(asked >= 1, "the round with asking on did ask (%d)" % asked)
	var ba: GameBattle = a[1]
	var bc: GameBattle = c[1]
	ok(ba.log == bc.log, "letting it land leaves the log as the old round wrote it")
	ok(ba.heir.hp == bc.heir.hp and ba.turn == bc.turn, "and the health and turn")
	ok(JSON.stringify(ba.events) == JSON.stringify(bc.events), "and the events, with no trace of the question")


func test_auto_members_are_not_asked() -> void:
	var t := _round()
	var r: GameRound = t[2]
	for by in [0, 1, 2]:
		r.set_auto(by, true)
	r.queue(-1, {"act": "attack", "target": "enemy:0"})
	var out := r.resolve()
	ok(bool(out["played"]) and not bool(out["asking"]), "with only the (hurt) heir on manual control nobody is asked")


func test_standing_cover_first() -> void:
	var t := _round()
	var b: GameBattle = t[1]
	var r: GameRound = t[2]
	r.set_cover(1, "heir")
	var out := r.resolve()
	var covers := _events(b, "cover")
	ok(covers.size() == 1 and int(covers[0]["by"]) == 1, "Bren's standing cover takes the first blow without asking")
	ok(bool(out["asking"]) and r.reaction_view().get("by", []) == [0, 2], "the next blow asks the others: %s" % str(r.reaction_view().get("by")))


func test_fight_ends_on_the_waiting_blow() -> void:
	var d := _dynasty(55)
	_foes(d, 100000.0)
	var b := d.battle
	b.heir.hp = 1
	var r := d.battle_round()
	r.ask_reactions = true
	for by in r.members():
		r.queue(by, {"act": "defend"} if by >= 0 else {"act": "attack", "target": "enemy:0"})
	var out := r.resolve()
	var n := 0
	while bool(out.get("asking", false)) and n < 10:
		n += 1
		out = r.answer(-2)
	ok(n >= 1, "the heir at 1 HP is asked about")
	ok(bool(out["over"]) == b.is_over() and (not b.is_over() or b.result == "defeat"), "if the blow fells the heir the fight is lost: %s" % b.result)
	ok(not r.asking(), "and nothing is left waiting")


# ---------------------------------------------------------------- the battle screen

var app: Node


func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


func _buttons(n: Node, prefix: String = "", out: Array = []) -> Array:
	if n is Button and (n as Button).is_visible_in_tree() and (n as Button).text.begins_with(prefix):
		out.append(n)
	for c in n.get_children():
		_buttons(c, prefix, out)
	return out


func _idle(bv: Control) -> void:
	var guard := 0
	while bv.busy and guard < 2000:
		guard += 1
		await process_frame


func test_battle_screen() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	GameDynasty.save_path = DIR + "save.json"
	UiSettings.path = DIR + "settings.cfg"
	UiSettings.scale = 1.0
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	TouchHint.finger = false
	root.size = Vector2i(1280, 720)
	await _frames(2)
	app = GameApp.new()
	root.add_child(app)
	await _frames(2)
	app.new_game("Tess", "warrior", "faetouched", 77, "human")
	var d: GameDynasty = app.dynasty
	var built := _dynasty(77)
	d.party = built.party
	d.pending_event = {}
	d.heir.level = 30
	d.world.visit("kingshold")
	d.party.rest(d)
	d.heir.full_heal()
	_foes(d)
	d.heir.hp = maxi(1, int(float(d.battle.unit_numbers(-1)["max_hp"]) * 0.2))
	d.auto_battle = false
	app.show_state()
	await _frames(5)
	var bv: Control = app.current
	ok(bv.cmd_round != null and bv.cmd_round.ask_reactions, "the battle screen asks reactions")
	var guard := 0
	while not _buttons(bv.command_box, "Attack").is_empty() and guard < 8:
		guard += 1
		(_buttons(bv.command_box, "Attack")[0] as Button).pressed.emit()
		await _frames(2)
	var fight := _buttons(bv.command_box, "Fight!")
	ok(fight.size() == 1, "everyone has chosen: Fight!")
	if fight.is_empty():
		return
	(fight[0] as Button).pressed.emit()
	await _frames(2)
	await _idle(bv)
	ok(bv.cmd_round.asking(), "the round stopped to ask")
	ok(_buttons(bv.command_box, "Bren Cask covers").size() == 1 and _buttons(bv.command_box, "Let it land").size() == 1, "one button per member who can step in, and one to let it land: %s" % str(_buttons(bv.command_box).map(func(x): return x.text)))
	ok(bv.auto_button.disabled, "Auto waits until the question is answered")
	ok(str(bv.hint.text).contains("Tess"), "the hint names whom the blow is aimed at: %s" % bv.hint.text)
	bv.set_auto(true)
	ok(not bv.auto and bv.cmd_round.asking(), "switching to Auto is refused while the question is open")
	var cover := _buttons(bv.command_box, "Bren Cask covers")
	if cover.is_empty():
		return
	(cover[0] as Button).pressed.emit()
	await _frames(2)
	await _idle(bv)
	ok(not bv.cmd_round.asking(), "the answer plays the round on")
	ok(d.battle.log.any(func(l): return str(l).contains("Bren Cask steps in front of Tess")), "Bren steps in front of Tess")
	ok(not _buttons(bv.command_box, "Attack").is_empty() and not bv.auto_button.disabled, "the next round's commands are back, with Auto")
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
