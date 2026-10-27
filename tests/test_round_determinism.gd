## Determinism of the battle engine around party command rounds.
##
## Proof obligations (reasoning; the runs below are the evidence):
##  1. Outside a round (round_on, round_cmds, braced, round_marks all at rest) the hunks in GameBattle
##     are inert: _begin_action clears events as before, _end_player_turn's guard falls through,
##     _ally_act takes GameTactics.choose and hands it to _ally_do whose ability/blow arms are the old
##     body verbatim, braced.has() is false so no damage is touched, the marker ifs change no state.
##     No RNG call is added, removed or reordered, so every autopilot and balance-harness fight is
##     byte for byte the old one.
##  2. A round with the heir manual and every companion Auto: the heir's effect is the same public
##     method as before; then _end_player_turn runs unmodified with an empty round_cmds.
##
## Evidence:
##  A. baseline: digests captured from origin/main 48f615d BEFORE any game code changed
##     (tests/fixtures/round_baseline.json, made by capture_round_baseline.gd) are recomputed on this
##     tree: GameBot.fight, stepped auto_turn, a scripted manual heir, and autopilot lives. Any
##     difference fails and prints the first differing log line.
##  B. a scripted heir played through GameRound with companions Auto equals the direct calls.
##  C. all-Auto GameRound rounds equal auto_turn round for round (markers filtered out).
##  D. the same seed and script twice give the same digest.
## Run: godot --headless --path . -s res://tests/test_round_determinism.gd [-- seeds=N]
extends SceneTree

const Scen := preload("res://tests/round_scenarios.gd")
const FIXTURE := "res://tests/fixtures/round_baseline.json"

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	GameData.load_all()
	var seeds := 0   # 0 = every captured seed
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = int(a.get_slice("=", 1))
	test_baseline(seeds)
	test_manual_heir_through_rounds(seeds)
	test_all_auto_rounds(seeds)
	test_flee_through_rounds(seeds)
	test_flee_chance_pinned()
	test_replay()
	print("round determinism tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fixture() -> Dictionary:
	var f := FileAccess.open(FIXTURE, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


# ---------------------------------------------------------------- A: the old tree's digests

func test_baseline(seeds: int) -> void:
	var fx := _fixture()
	ok(not fx.is_empty(), "the baseline fixture loads")
	if fx.is_empty():
		return
	var digests: Dictionary = fx["digests"]
	var logs: Dictionary = fx["logs"]
	var seen := 0
	var drift := 0
	for k in digests:
		var seed_part: String = str(k).get_slice("|", 1)
		if seeds > 0 and int(seed_part) > seeds:
			continue
		seen += 1
		var first := seed_part == "1" and not str(k).begins_with("live")
		var r := Scen.run_key(k, first)
		if r["digest"] == digests[k]:
			continue
		drift += 1
		if drift <= 5:
			print("  drift in ", k, first_difference(logs.get(k, []), r.get("log", [])))
	ok(seen > 100, "the baseline holds many scenarios (%d)" % seen)
	ok(drift == 0, "no scenario drifted from origin/main (%d of %d differ)" % [drift, seen])


func first_difference(old_log: Array, new_log: Array) -> String:
	if old_log.is_empty():
		return " (no stored log for this scenario)"
	for i in maxi(old_log.size(), new_log.size()):
		var a := str(old_log[i]) if i < old_log.size() else "<end>"
		var b := str(new_log[i]) if i < new_log.size() else "<end>"
		if a != b:
			return " at log line %d:\n    was: %s\n    now: %s" % [i, a, b]
	return " (logs match; state or events differ)"


# ---------------------------------------------------------------- B, C, D: GameRound against the direct calls

const MARKERS := ["round", "act", "foes"]


## Events of one round without GameRound's markers: what the direct calls produce.
func _plain(events: Array) -> Array:
	return events.filter(func(e): return e["type"] not in MARKERS).duplicate(true)


## The scripted heir or auto_turn through the battle's own calls: [log, trail, state, dynasty].
func _direct(mode: String, seed_val: int, cls: String, n: int, kind: String) -> Dictionary:
	var d := Scen.make(seed_val, cls, n, kind)
	var b := d.battle
	var trail: Array = []
	var guard := 0
	while not b.is_over() and guard < Scen.GUARD:
		guard += 1
		if mode == "auto_turn":
			GameTactics.auto_turn(b)
		elif mode == "flee":
			var before := b.turn
			if Scen.flee_now(b, seed_val):
				b.flee()
			else:
				b.attack(b.first_target())
			if b.result == "" and b.turn == before:
				b.attack(b.first_target())
		else:
			var coat := Scen.script_coat(b, seed_val)
			if coat != "":
				b.coat_blade(coat)
				trail.append([b.log.size(), b.events.duplicate(true)])
			var before := b.turn
			Scen.direct(b, Scen.script_cmd(b, seed_val))
			if b.result == "" and b.turn == before:
				b.attack(b.first_target())
		trail.append([b.log.size(), b.events.duplicate(true)])
	d.finish_battle()
	return {"log": b.log, "trail": trail, "state": Scen.state_of(b), "dynasty": d.to_dict()}


## The same through GameRound: the heir by hand (or Auto too), the companions Auto.
func _rounds(mode: String, seed_val: int, cls: String, n: int, kind: String) -> Dictionary:
	var d := Scen.make(seed_val, cls, n, kind)
	var b := d.battle
	d.auto_party = {"companion_default": true}
	if mode == "auto_turn":
		d.auto_party["heir"] = true
	var r := d.battle_round()
	var trail: Array = []
	var guard := 0
	var refused := 0
	while not b.is_over() and guard < Scen.GUARD:
		guard += 1
		if mode == "flee":
			r.queue(-1, {"act": "flee"} if Scen.flee_now(b, seed_val) else {"act": "attack", "target": "enemy:%d" % b.first_target()})
		if mode == "manual":
			var coat := Scen.script_coat(b, seed_val)
			if coat != "":
				r.coat(coat)
				trail.append([b.log.size(), b.events.duplicate(true)])
			if r.state_of(-1) == "ready" and r.queue(-1, Scen.script_cmd(b, seed_val)) != "":
				refused += 1
				r.queue(-1, {"act": "attack", "target": "enemy:%d" % b.first_target()})
		if not r.resolve()["played"]:
			break
		trail.append([b.log.size(), _plain(b.events)])
	var hold_left := b.round_on or b.round_marks or not b.round_cmds.is_empty() or not b.braced.is_empty()
	d.finish_battle()
	d.auto_party = {}
	return {"log": b.log, "trail": trail, "state": Scen.state_of(b), "dynasty": d.to_dict(), "refused": refused, "hold": hold_left}


func _compare(mode: String, seed_val: int, cls: String, n: int, kind: String) -> void:
	var tag := "%s %d %s x%d %s" % [mode, seed_val, cls, n, kind]
	var a := _direct(mode, seed_val, cls, n, kind)
	var b := _rounds(mode, seed_val, cls, n, kind)
	ok(not b["hold"], "%s: the hold is off after the fight" % tag)
	ok(b["refused"] == 0, "%s: the script's commands are all legal" % tag)
	var same_log: bool = a["log"] == b["log"]
	ok(same_log, "%s: same log%s" % [tag, "" if same_log else first_difference(a["log"], b["log"])])
	ok(Scen.digest(a["state"]) == Scen.digest(b["state"]), "%s: same end state and RNG" % tag)
	ok(Scen.digest(a["trail"]) == Scen.digest(b["trail"]), "%s: same events round by round" % tag)
	ok(Scen.digest(a["dynasty"]) == Scen.digest(b["dynasty"]), "%s: same dynasty afterwards" % tag)


func test_manual_heir_through_rounds(seeds: int) -> void:
	var top := 8 if seeds <= 0 else mini(seeds, 8)
	for s in range(1, top + 1):
		for ci in Scen.CLASSES.size():
			for n in [1, 3]:
				_compare("manual", s, Scen.CLASSES[ci], n, Scen.KINDS[(s + ci + n) % Scen.KINDS.size()])


func test_all_auto_rounds(seeds: int) -> void:
	var top := 6 if seeds <= 0 else mini(seeds, 6)
	for s in range(1, top + 1):
		for ci in Scen.CLASSES.size():
			for n in [0, 1, 3]:
				_compare("auto_turn", s, Scen.CLASSES[ci], n, Scen.KINDS[(s + ci + n) % Scen.KINDS.size()])


func test_replay() -> void:
	for s in [3, 9]:
		var a := _rounds("manual", s, "warrior", 3, "hunt")
		var b := _rounds("manual", s, "warrior", 3, "hunt")
		ok(Scen.digest(a) == Scen.digest(b), "the same seed and script replay identically (seed %d)" % s)
	var c := _rounds("manual", 3, "warrior", 3, "hunt")
	var d := _rounds("manual", 4, "warrior", 3, "hunt")
	ok(Scen.digest(c) != Scen.digest(d), "and another seed does not")


## The old flow when the heir flees with companions on their own (flee_covers_party is false by default).
func test_flee_through_rounds(seeds: int) -> void:
	var top := 20 if seeds <= 0 else mini(seeds, 20)
	for s in range(1, top + 1):
		for n in [1, 3]:
			_compare("flee", s, Scen.CLASSES[(s + n) % Scen.CLASSES.size()], n, "hunt")


## The flee roll's base chance is pinned: a roll just either side of it decides the fight.
func test_flee_chance_pinned() -> void:
	for n in [0, 3]:
		for want in [true, false]:
			var probe := Scen.make(5, "warrior", n, "hunt")
			var h := probe.heir
			var chance := clampf(0.45 + h.trait_total("stealth") + h.trait_total("intimidation") * 0.5 + h.dodge_chance() * 0.3, 0.1, 0.9)
			var found := -1
			for sd in range(1, 100000):
				var p := RandomNumberGenerator.new()
				p.seed = sd
				var roll := p.randf()
				if (want and roll >= chance - 0.009 and roll <= chance - 0.001) or (not want and roll >= chance + 0.001 and roll <= chance + 0.009):
					found = sd
					break
			ok(found > 0, "a roll beside the flee chance exists (%d companions, success %s)" % [n, want])
			var d := Scen.make(5, "warrior", n, "hunt")
			d.battle.rng.seed = found
			d.auto_party = {"companion_default": true}
			var r := d.battle_round()
			r.queue(-1, {"act": "flee"})
			r.resolve()
			ok((d.battle.result == "fled") == want, "the flee chance sits at %.3f: a roll of %s it %s (%d companions)" % [chance, "just under" if want else "just over", "escapes" if want else "fails", n])
			var e := Scen.make(5, "warrior", n, "hunt")
			e.battle.rng.seed = found
			e.battle.flee()
			ok((e.battle.result == "fled") == want, "(the old call agrees)")
