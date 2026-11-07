## The fixed list of battle events (data/game/battle_events.json, GameEventSpec): every event a fight emits is a
## listed type with exactly its listed fields, whatever the class, party or kind of fight, solo turns and party
## rounds alike; every type the source can emit is on the list and every listed type is emitted somewhere in
## the source; and the checker itself turns away an unlisted type, a missing or unlisted field and a wrong kind.
## Run: godot --headless --path . -s res://tests/test_game_event_list.gd
extends SceneTree

const Scen := preload("res://tests/round_scenarios.gd")
const SOURCES := ["res://core/game/game_battle.gd", "res://core/game/game_round.gd", "res://core/game/game_tactics.gd"]

var fails := 0
var checks := 0
var seen: Dictionary = {}      # type -> times emitted in the fights played here
var bad: Dictionary = {}       # problem -> true
var total := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	test_checker()
	test_source_matches_list()
	test_fights()
	test_rounds()
	print("%d events seen, %d of %d listed types among them" % [total, seen.size(), GameEventSpec.types().size()])
	print("%d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## Takes the battle's current events into account.
func _take(b: GameBattle) -> void:
	for ev in b.events:
		total += 1
		var t := str(ev.get("type", "?"))
		seen[t] = int(seen.get(t, 0)) + 1
		for p in GameEventSpec.problems(ev):
			bad[p] = true


# ---------------------------------------------------------------- the checker

func test_checker() -> void:
	ok(GameEventSpec.types().size() >= 20, "the list is loaded")
	ok(GameEventSpec.problems({"type": "round", "n": 2}).is_empty(), "a good event passes")
	ok(not GameEventSpec.problems({"type": "nonsense"}).is_empty(), "an unlisted type is turned away")
	ok(not GameEventSpec.problems({"type": "round"}).is_empty(), "a missing field is turned away")
	ok(not GameEventSpec.problems({"type": "round", "n": 1, "extra": 1}).is_empty(), "an unlisted field is turned away")
	ok(not GameEventSpec.problems({"type": "round", "n": "1"}).is_empty(), "a field of the wrong kind is turned away")
	ok(not GameEventSpec.problems({"type": "act", "by": -1, "manual": true, "held": 1}).is_empty(), "an optional field of the wrong kind is turned away")
	ok(not GameEventSpec.problems({"type": "cast", "by": -1, "name": "x", "cast": 1, "aoe": false, "element": "", "targets": [0, "a"]}).is_empty(), "an array of the wrong kind is turned away")
	ok(GameEventSpec.problems({"type": "ko", "side": "ally", "ally": 0, "foe_scale": 1}).is_empty(), "a number may be a whole number")
	ok(not GameEventSpec.problems("a log line").is_empty(), "a bare string is no event")
	for t in GameEventSpec.types():
		ok(str(GameEventSpec.spec()[t].get("about", "")) != "", "'%s' says what it is" % t)


# ---------------------------------------------------------------- the source

## Every `{"type": "x"` an `events.append(` writes in the core's battle code.
func _emitted_types() -> Array:
	var re := RegEx.new()
	re.compile("events\\.append\\(\\{\"type\": \"(\\w+)\"")
	var out: Array = []
	for path in SOURCES:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			ok(false, "%s can be read" % path)
			continue
		for m in re.search_all(f.get_as_text()):
			var t := m.get_string(1)
			if t not in out:
				out.append(t)
	return out


func test_source_matches_list() -> void:
	var emitted := _emitted_types()
	ok(emitted.size() >= 20, "the source's events are found (%d)" % emitted.size())
	for t in emitted:
		ok(GameEventSpec.types().has(t), "the source emits '%s' and it is on the list" % t)
	for t in GameEventSpec.types():
		ok(t in emitted, "the list's '%s' is emitted by the source" % t)


# ---------------------------------------------------------------- fights

## Solo turns, a turn at a time, for scripted heirs and auto_turn.
func test_fights() -> void:
	var cases := [["manual", 3, "warrior", 0, "hunt"], ["manual", 4, "mage", 1, "hunt"], ["manual", 8, "cleric", 3, "hunt_hard"],
		["manual", 11, "rogue", 3, "legend"], ["auto_turn", 6, "paladin", 3, "hunt"], ["auto_turn", 9, "spellblade", 1, "legend"],
		["manual", 14, "mage", 3, "legend"], ["auto_turn", 17, "warrior", 0, "hunt_hard"], ["auto_turn", 20, "necromancer", 2, "hunt"],
		["auto_turn", 23, "ranger", 2, "legend"], ["manual", 26, "rogue", 1, "hunt_hard"]]
	for c in cases:
		var d := Scen.make(c[1], c[2], c[3], c[4])
		var guard := 0
		while not d.battle.is_over() and guard < Scen.GUARD:
			guard += 1
			var b := d.battle
			if c[0] == "auto_turn":
				GameTactics.auto_turn(b)
				_take(b)
				continue
			var coat := Scen.script_coat(b, c[1])
			if coat != "":
				b.coat_blade(coat)
				_take(b)
			var before := b.turn
			Scen.direct(b, Scen.script_cmd(b, c[1]))
			_take(b)
			if b.result == "" and b.turn == before:
				b.attack(b.first_target())
				_take(b)
		ok(guard < Scen.GUARD, "%s %d %s x%d %s: the fight ends" % c)
	ok(bad.is_empty(), "every event of the solo fights is on the list as written" + ("" if bad.is_empty() else ": " + str(bad.keys())))


## Party rounds through GameRound (the round, act and foes markers, a companion's defend, covers).
func test_rounds() -> void:
	bad.clear()
	for c in [[5, "warrior", "hunt"], [12, "cleric", "hunt_hard"], [21, "mage", "legend"], [30, "rogue", "hunt"]]:
		var d := Scen.make(c[0], c[1], 3, c[2])
		d.auto_party = {"companion_default": true}
		var guard := 0
		while not d.battle.is_over() and guard < Scen.GUARD:
			guard += 1
			var b := d.battle
			var r := d.battle_round()
			if r.state_of(-1) == "ready" and r.queue(-1, Scen.script_cmd(b, c[0])) != "":
				r.queue(-1, {"act": "attack", "target": "enemy:%d" % b.first_target()})
			if not r.resolve()["played"]:
				break
			_take(b)
		d.auto_party = {}
		ok(guard < Scen.GUARD, "rounds %d %s %s: the fight ends" % c)
	ok(bad.is_empty(), "every event of the party rounds is on the list as written" + ("" if bad.is_empty() else ": " + str(bad.keys())))
	for t in ["round", "act", "foes", "damage", "cast"]:
		ok(int(seen.get(t, 0)) > 0, "the fights played here emitted '%s'" % t)
	var missing: Array = []
	for t in GameEventSpec.types():
		if not seen.has(t):
			missing.append(t)
	print("listed types these fights did not reach (checked against the source instead): ", missing)
