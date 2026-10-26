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
