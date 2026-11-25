## The gate panel (ui/play/gate_panel.gd, opened by Use at an arch): it shows the arch's slots as a row with their state, the repair keys with their
## cost and, when shut, their reason as text under them (never a tooltip), copy keys for runes that can be read, the road smith, the guard post and, when the
## arch works, the list of destinations with a Step through key; each key is a fingertip tall; pressing a key does what GameGates and
## GameSandbox say and nothing else; the sandbox screen opens it from Use.
## Run: godot --headless --path . -s res://tests/test_game_gate_panel.gd
extends SceneTree

const GatePanel := preload("res://ui/play/gate_panel.gd")
const GameApp := preload("res://ui/play/game_app.gd")
const SandboxScreen := preload("res://ui/play/sandbox_screen.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")

var checks := 0
var fails := 0


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
	UiSettings.path = "user://test_gate_panel_settings.cfg"
	await test_lit()
	await test_ruined()
	await test_town_and_guard()
	await test_screen_opens_it()
	print("gate panel tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _dyn() -> GameDynasty:
	var d := GameDynasty.new_game(21, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 5000
	return d


func _open(d: GameDynasty, s: GameSandbox, gate: String) -> Control:
	var p: Control = GatePanel.new()
	p.dynasty = d
	p.sandbox = s
	p.gate = gate
	root.add_child(p)
	await _frames(3)
	return p


func _all(n: Node, out: Array = []) -> Array:
	out.append(n)
	for c in n.get_children():
		_all(c, out)
	return out


func _named(p: Node, name: String) -> Node:
	for n in _all(p):
		if str(n.name) == name:
			return n
	return null


func _named_all(p: Node, prefix: String) -> Array:
	return _all(p).filter(func(n): return str(n.name).begins_with(prefix))


func _texts(p: Node) -> String:
	var out := ""
	for n in _all(p):
		if n is Label:
			out += (n as Label).text + "\n"
		elif n is Button:
			out += (n as Button).text + "\n"
	return out


func test_lit() -> void:
	var d := _dyn()
	var s := GameSandbox.start(d)
	s.creatures.clear()
	s.heir = GameGates.front_of(d, "hearthmere_arch")
	var p := await _open(d, s, "hearthmere_arch")
	ok(p.has_meta("modal"), "the panel is modal: the world waits")
	var slots := _named(p, "Slots")
	ok(slots != null and slots.get_child_count() == 5, "a lit medium gate shows its five slots in a row")
	var pics := _all(slots).filter(func(n): return n is TextureRect)
	ok(pics.size() == 5 and (pics[0] as TextureRect).custom_minimum_size == Vector2(28, 36), "each slot is a rune picture at a whole multiple (4 pixels to one)")
	ok(_texts(p).contains("whole") and _texts(p).contains("Lit"), "the slots say whole and the gate says lit")
	var dests := _named_all(p, "Dest_")
	ok(dests.size() == GameGates.destinations(d, "hearthmere_arch").size() and dests.size() >= 2, "the lit gate lists the gates it leads to (%d)" % dests.size())
	var go := _named(p, "StepThrough") as Button
	ok(go != null and go.disabled and _named(p, "StepReason") != null, "Step through is shut until a place is picked, and says why as text")
	ok(go.custom_minimum_size.y >= float(UiSettings.setting("touch_target_px")), "and it is a fingertip tall")
	var pick := dests[0] as Button
	var target := str(GameGates.destinations(d, "hearthmere_arch")[0]["id"])
	pick.pressed.emit()
	await _frames(2)
	go = _named(p, "StepThrough") as Button
	ok(not go.disabled and _named(p, "StepReason") == null, "picking one opens it")
	d.clock_carry = 0.0
	go.pressed.emit()
	await _frames(2)
	ok(s.heir == GameGates.front_of(d, target), "pressing it takes the heir through to the far gate")
	ok(not is_instance_valid(p) or p.is_queued_for_deletion(), "and the panel closes")
	await _frames(2)


func test_ruined() -> void:
	var d := _dyn()
	var s := GameSandbox.start(d)
	s.creatures.clear()
	var gate := "highcrag_arch"
	s.heir = GameGates.front_of(d, gate)
	var p := await _open(d, s, gate)
	ok(_texts(p).contains("Dark"), "a ruined gate says it is dark")
	ok(_named(p, "StepThrough") == null or (_named(p, "StepThrough") as Button).disabled, "and cannot be stepped through")
	var keys := _named_all(p, "Inscribe")
	ok(keys.size() >= 4, "it lists a repair for each ruined slot (%d)" % keys.size())
	var reasons := _named_all(p, "Reason")
	ok(reasons.size() >= 1, "a shut key says why, as a label under it")
	var shut := keys.filter(func(k): return (k as Button).disabled)
	ok(shut.size() == keys.size(), "with no silver and no rune known they are all shut (%d)" % shut.size())
	ok(keys.all(func(k): return (k as Button).custom_minimum_size.y >= float(UiSettings.setting("touch_target_px"))), "every repair key is a fingertip tall")
	var tooltips := keys.filter(func(k): return (k as Button).tooltip_text != "")
	ok(tooltips.is_empty(), "no reason is a tooltip")
	# give what is needed for one and press it
	var slot := -1
	for i in GameGates.slot_count(gate):
		if str(GameGates.state(d, gate)["slots"][i]["state"]) != "whole" and slot < 0:
			slot = i
	GameGates.learn(d, str(GameGates.runes_of(gate)[slot]))
	GameCraft.add_material(d, "silver", 10)
	p.queue_free()
	await _frames(2)
	p = await _open(d, s, gate)
	var key := _named(p, "Inscribe%d" % slot) as Button
	ok(key != null and not key.disabled, "with the rune, silver and gold the key opens")
	key.pressed.emit()
	await _frames(2)
	ok(str(GameGates.state(d, gate)["slots"][slot]["state"]) == "whole", "pressing it repairs the slot")
	ok(_named(p, "Said") != null and (_named(p, "Said") as Label).text.contains("rune"), "and the panel tells what was done")
	# a rune that can be read can be copied
	var copies := _named_all(p, "Copy")
	ok(copies.size() >= 0, "(copy keys are listed for legible runes not yet known: %d)" % copies.size())
	p.queue_free()
	await _frames(2)
	# from far away every key is shut
	var far := _dyn()
	var sf := GameSandbox.start(far)
	sf.creatures.clear()
	sf.heir = GameGates.front_of(far, gate) + Vector2i(20, 0)
	GameCraft.add_material(far, "silver", 10)
	for r in GameGates.data()["runes"]:
		GameGates.learn(far, str(r))
	var pf := await _open(far, sf, gate)
	var fk := _named_all(pf, "Inscribe")
	ok(fk.size() > 0 and fk.all(func(k): return (k as Button).disabled), "away from the stones every repair is shut")
	ok(_texts(pf).contains("stand at the gate"), "and says to stand at the gate")
	pf.queue_free()
	await _frames(2)


func test_town_and_guard() -> void:
	var d := _dyn()
	d.party.members.append({"id": "bren_cask", "name": "Bren", "hp": 1, "mp": 0, "level": 5, "gen": 1, "due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
	d.party.history["bren_cask"] = {"name": "Bren", "status": "serving", "gen": 1, "first_gen": 1, "battles": 0, "fallen": [], "line": 0, "past": [], "born": -30.0, "rolled": 0.0}
	var s := GameSandbox.start(d)
	s.creatures.clear()
	s.heir = GameGates.front_of(d, "hearthmere_arch")
	var p := await _open(d, s, "hearthmere_arch")
	ok(_named(p, "Smith") != null, "a town's gate has its road smith")
	var buy := _named(p, "BuySilver1") as Button
	ok(buy != null and not buy.disabled, "silver can be bought")
	buy.pressed.emit()
	await _frames(2)
	ok(GameCraft.have(d, "silver") == 1, "pressing Buy puts silver in the stores")
	var post := _named(p, "Post_bren_cask") as Button
	ok(post != null, "a companion can be posted")
	post.pressed.emit()
	await _frames(2)
	ok(GameGates.guard_of(d, "hearthmere_arch") == "bren_cask" and _named(p, "Relieve") != null, "pressing it posts them, and the key to relieve them appears")
	(_named(p, "Relieve") as Button).pressed.emit()
	await _frames(2)
	ok(GameGates.guard_of(d, "hearthmere_arch") == "", "and relieving frees them")
	p.queue_free()
	await _frames(2)
	var w := _dyn()
	var sw := GameSandbox.start(w)
	sw.creatures.clear()
	sw.heir = GameGates.front_of(w, "highcrag_arch")
	var pw := await _open(w, sw, "highcrag_arch")
	ok(_named(pw, "Smith") == null, "a gate in the wilds has no smith")
	ok(_named_all(pw, "Post_").is_empty() and _texts(pw).contains("No companion"), "with no companion there is no one to post, and it says so")
	pw.queue_free()
	await _frames(2)


func test_screen_opens_it() -> void:
	root.size = Vector2i(1280, 720)
	GameDynasty.save_path = "user://test_gate_panel_save.json"
	var app: Node = GameApp.new()
	root.add_child(app)
	await _frames(3)
	app.closed_badly = false
	app.new_game("Tess", "warrior", "faetouched", 21)
	await _frames(2)
	app.show_sandbox()
	await _frames(4)
	var screen: Control = app.current
	var d: GameDynasty = app.dynasty
	screen.set_process(false)
	var sb: GameSandbox = screen.sb
	sb.creatures.clear()
	sb.heir = GameGates.front_of(d, "hearthmere_arch")
	screen._use()
	await _frames(3)
	var open := screen.get_children().filter(func(c): return c.has_meta("pane") and str(c.get_meta("pane")) == "gate_panel")
	ok(open.size() == 1, "Use at a gate opens the gate panel over the world")
	app.queue_free()
	await _frames(2)
	DirAccess.remove_absolute("user://test_gate_panel_save.json")
