## Replay files (GameReplay): a recorded run plays back to exactly the same dynasty. The autopilot's whole
## three-generation lives, and hand-given commands (rest, train, travel, hunts fought a turn at a time with
## the autopilot's tactics and with the heir's own commands, the world clock, a succession), are recorded, written
## as one line of text, read back and played: every fingerprint and the end match. A changed command or a
## missing one is found at the command where the run goes differently; a damaged, foreign, newer or hand-made
## replay is turned away with a reason and never run into a crash; commands the game does not allow are refused.
## Run: godot --headless --path . -s res://tests/test_game_replay.gd
extends SceneTree

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	test_bot_lives()
	test_hand_commands()
	test_text()
	test_divergence()
	test_refusals()
	test_damaged()
	print("%d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## Reads a replay's text and plays it.
func _play_text(text: String, stop_at: int = -1) -> Dictionary:
	var r := GameReplay.from_text(text)
	if not r["ok"]:
		return {"ok": false, "error": r["error"], "dynasty": null, "played": 0, "diverged_at": -1}
	return GameReplay.play(r["replay"], stop_at)


# ---------------------------------------------------------------- the autopilot's lives

func test_bot_lives() -> void:
	for c in [[1, "warrior", "human", "male"], [7, "mage", "elf", "female"], [12, "cleric", "dwarf", "male"]]:
		var tag := "seed %d %s %s" % [c[0], c[1], c[2]]
		var bloodline: String = GameData.traits_in(["bloodline"])[c[0] % GameData.traits_in(["bloodline"]).size()]
		var rec := GameReplay.begin(c[0], "Tess", c[1], bloodline, c[2], c[3], 10)
		rec.bot_on(400)
		var gens := rec.dynasty.gen
		ok(rec.commands.size() > 50 and gens >= 2, "%s: the autopilot lived %d commands over %d generations" % [tag, rec.commands.size(), gens])
		ok(rec.checks.size() >= rec.commands.size() / 10 - 1, "%s: fingerprints were kept along the way" % tag)
		var played := _play_text(rec.to_text())
		ok(played["ok"], "%s: the replay plays back exactly (%s)" % [tag, played["error"]])
		if played["ok"]:
			ok(GameReplay.fingerprint(played["dynasty"]) == GameReplay.fingerprint(rec.dynasty), "%s: to the very same dynasty" % tag)
			ok(JSON.stringify(played["dynasty"].to_save(), "", true) == JSON.stringify(rec.dynasty.to_save(), "", true), "%s: byte for byte, as it would be saved" % tag)
			ok(played["played"] == rec.commands.size(), "%s: every command ran" % tag)


# ---------------------------------------------------------------- commands by hand

func test_hand_commands() -> void:
	var rec := GameReplay.begin(21, "Ann", "warrior", GameData.traits_in(["bloodline"])[0], "human", GameSex.FEMALE, 1)
	var d := rec.dynasty
	var script: Array = [{"op": "train", "stat": "str"}, {"op": "rest"}, {"op": "work"}, {"op": "buy_potion"}, {"op": "explore"}]
	for c in script:
		rec.do(c)
		if d.has_pending_event():
			rec.do({"op": "resolve", "choice": 0})
	rec.do({"op": "hunt", "kind": "hunt"})
	ok(d.battle != null, "a hunt starts a fight")
	var turns := 0
	while d.battle != null and not d.battle.is_over() and turns < 60:
		turns += 1
		if turns % 3 == 0:
			rec.do({"op": "act", "act": "attack", "target": "enemy:%d" % d.battle.first_target()})
		elif turns % 5 == 0:
			rec.do({"op": "act", "act": "defend"})
		else:
			rec.do({"op": "turn"})
	ok(d.battle.is_over(), "the fight is fought to its end by hand")
	ok(rec.do({"op": "finish"})["ok"] and d.battle == null, "and settled")
	rec.do({"op": "clock", "seconds": 150.0})
	var a := d.heir.age
	rec.do({"op": "rest"})
	ok(d.heir.age > a - 0.001, "the world clock and a rest went on")
	for i in 4:
		rec.do({"op": "hunt", "kind": "hunt_hard" if i == 2 else "hunt"})
		if d.battle != null:
			rec.do({"op": "bot_fight"})
	for i in 20:
		if d.state != "life":
			break
		rec.do({"op": "bot_step"})
	var text := rec.to_text()
	var played := _play_text(text)
	ok(played["ok"], "hand-given commands play back exactly (%s)" % played["error"])
	ok(rec.commands.size() > 25, "a fair number of commands (%d)" % rec.commands.size())
	if played["ok"]:
		ok(GameReplay.fingerprint(played["dynasty"]) == GameReplay.fingerprint(d), "to the same dynasty")
	# a fight stopped halfway reads the same: fingerprints inside a fight include the fight
	var mid := _play_text(text, 12)
	ok(mid["ok"] and mid["played"] == 12, "a replay can be played part of the way")


# ---------------------------------------------------------------- the text

func test_text() -> void:
	var rec := GameReplay.begin(3, "Bo", "rogue", GameData.traits_in(["bloodline"])[1], "human", GameSex.MALE, 5)
	rec.bot_on(60)
	var text := rec.to_text()
	ok(text.begins_with("GLRP1:") and not "\n" in text, "a replay is one line starting GLRP1:")
	var wrapped := text.substr(0, 40) + "\n " + text.substr(40, 40) + "\r\n\t" + text.substr(80)
	ok(_play_text(wrapped)["ok"], "a block pasted with spaces and line breaks still plays")
	ok(text.length() < 40000, "and stays small (%d characters for %d commands)" % [text.length(), rec.commands.size()])
	var read := GameReplay.from_text(text)
	ok(read["ok"] and read["replay"]["commands"].size() == rec.commands.size(), "it reads back with all its commands")
	ok(read["replay"]["start"]["seed"] == 3, "and says how the dynasty began")


# ---------------------------------------------------------------- where it goes wrong

func test_divergence() -> void:
	var rec := GameReplay.begin(5, "Cy", "mage", GameData.traits_in(["bloodline"])[2], "elf", GameSex.FEMALE, 1)
	rec.bot_on(80)
	var rep := rec.to_dict()
	ok(GameReplay.play(rep)["ok"], "a fine replay plays")
	# an op swapped for another: the run goes differently, and the check after that command says so
	var cmds: Array = rep["commands"]
	var at := -1
	for i in range(10, cmds.size()):
		if cmds[i]["op"] == "bot_step":
			at = i
			break
	ok(at >= 0, "there is a step to change (%d)" % at)
	var changed: Dictionary = rep.duplicate(true)
	changed["commands"][at] = {"op": "rest"}
	var res := GameReplay.play(changed)
	ok(not res["ok"] and res["diverged_at"] == at, "a changed command is found at that command (%d, found %d)" % [at, res["diverged_at"]])
	ok("differently" in res["error"], "with a reason")
	# a command taken out
	var cut: Dictionary = rep.duplicate(true)
	cut["commands"].remove_at(at)
	var res2 := GameReplay.play(cut)
	ok(not res2["ok"], "a command missing is found")
	# the end alone is wrong
	var tail: Dictionary = rep.duplicate(true)
	tail["end"] = "0000000000000000"
	tail["checks"] = []
	var res3 := GameReplay.play(tail)
	ok(not res3["ok"] and "ended differently" in res3["error"], "a wrong ending is found without any checks")
	# sparse checks put the divergence at or after the real one
	var sparse := GameReplay.begin(5, "Cy", "mage", GameData.traits_in(["bloodline"])[2], "elf", GameSex.FEMALE, 20)
	sparse.bot_on(80)
	var sp := sparse.to_dict()
	var at2 := 31
	sp["commands"][at2] = {"op": "rest"} if sp["commands"][at2]["op"] != "rest" else {"op": "work"}
	var res4 := GameReplay.play(sp)
	ok(not res4["ok"] and res4["diverged_at"] >= at2 and res4["diverged_at"] < at2 + 20, "with sparse checks it is found at the next one (%d)" % res4["diverged_at"])


# ---------------------------------------------------------------- what the game does not allow

func test_refusals() -> void:
	var rec := GameReplay.begin(9, "Di", "warrior", GameData.traits_in(["bloodline"])[0], "human", GameSex.MALE, 1)
	var d := rec.dynasty
	var before := GameReplay.fingerprint(d)
	var bad: Array = [
		{"op": "nonsense"}, {}, {"op": 5}, {"op": "finish"}, {"op": "turn"}, {"op": "act", "act": "attack"},
		{"op": "choose_heir", "index": 0}, {"op": "choose_best"}, {"op": "resolve", "choice": 0},
		{"op": "train", "stat": "luck"}, {"op": "train"}, {"op": "travel", "to": ""}, {"op": "travel"},
		{"op": "hunt", "kind": "slaughter"}, {"op": "hunt"}, {"op": "clock", "seconds": -4}, {"op": "clock", "seconds": "soon"},
		{"op": "clock", "seconds": INF}, {"op": "clock", "seconds": NAN}, {"op": "retire"}, {"op": "found_family"}, {"op": "legend"}]
	for c in bad:
		var res := rec.do(c)
		ok(not res["ok"] and str(res["error"]) != "", "refused with a reason: %s" % str(c))
	ok(GameReplay.fingerprint(d) == before and rec.commands.is_empty(), "and none of them touched the dynasty or the replay")
	# inside a fight
	rec.do({"op": "hunt", "kind": "hunt"})
	ok(d.battle != null, "a hunt began")
	var fp := GameReplay.fingerprint(d)
	for c in [{"op": "rest"}, {"op": "hunt", "kind": "hunt"}, {"op": "explore"}, {"op": "bot_step"}, {"op": "finish"},
			{"op": "act", "act": "fireball"}, {"op": "act", "act": "attack", "target": "enemy:99"},
			{"op": "act", "act": "ability", "kind": "spell", "id": "no_such_spell"}, {"op": "act", "act": "ability", "kind": "cheat", "id": "x"},
			{"op": "act", "act": "ability", "kind": "skill", "id": "no_such_skill"}, {"op": "act", "act": "ability", "kind": "feat", "id": "none"},
			{"op": "act", "act": "ability", "kind": "vial", "id": "no_such_vial"}]:
		var res := rec.do(c)
		ok(not res["ok"], "in a fight, refused: %s" % JSON.stringify(c))
	ok(GameReplay.fingerprint(d) == fp, "the fight was not touched by them")


# ---------------------------------------------------------------- damaged replays

func test_damaged() -> void:
	var rec := GameReplay.begin(2, "Ed", "cleric", GameData.traits_in(["bloodline"])[0], "human", GameSex.MALE, 5)
	rec.bot_on(30)
	var good := rec.to_dict()
	ok(not GameReplay.from_text("hello")["ok"], "text that is not a replay is turned away")
	ok(not GameReplay.from_text("GLBK1:AAAA")["ok"], "so is a house backup")
	ok(not GameReplay.from_text("GLRP1:")["ok"], "an empty block")
	ok(not GameReplay.from_text("GLRP1:!!!!")["ok"], "a block that is not base64")
	ok(not GameReplay.from_text("GLRP1:AAAA")["ok"], "a block that does not unpack")
	var text := rec.to_text()
	ok(not GameReplay.from_text(text.substr(0, text.length() - 12))["ok"], "a block cut short")
	var variants := {
		"another format": func(r): r["format"] = "XXXX",
		"a newer game": func(r): r["version"] = GameSaveVersion.CURRENT + 1,
		"no version": func(r): r.erase("version"),
		"no start": func(r): r.erase("start"),
		"a start without a seed": func(r): r["start"].erase("seed"),
		"a seed that is text": func(r): r["start"]["seed"] = "abc",
		"a class that does not exist": func(r): r["start"]["class"] = "dragon",
		"a race that does not exist": func(r): r["start"]["race"] = "robot",
		"a bloodline that does not exist": func(r): r["start"]["bloodline"] = "none",
		"a name that is a number": func(r): r["start"]["name"] = 4,
		"commands that are not a list": func(r): r["commands"] = "rest",
		"a command that is not a command": func(r): r["commands"][0] = 5,
		"a command without an op": func(r): r["commands"][0] = {"x": 1},
		"checks that are not a list": func(r): r["checks"] = 3,
		"a check of the wrong shape": func(r): r["checks"] = [[1]],
		"an end that is not text": func(r): r["end"] = 5,
	}
	for name in variants:
		var r: Dictionary = good.duplicate(true)
		variants[name].call(r)
		var res := GameReplay.play(r)
		ok(not res["ok"] and str(res["error"]) != "", "turned away with a reason: %s" % name)
	ok(not GameReplay.check(null)["ok"] and not GameReplay.check([])["ok"] and not GameReplay.check("x")["ok"], "things that are not a replay at all")
	# a replay whose commands are not allowed where they come stops there, with the number
	var r2: Dictionary = good.duplicate(true)
	r2["commands"].insert(3, {"op": "choose_heir", "index": 0})
	var res2 := GameReplay.play(r2)
	ok(not res2["ok"] and res2["played"] == 3 and "Command 3" in res2["error"], "a command not allowed there stops the replay at it")
	# a fresh read of a good one still plays after all that
	ok(GameReplay.play(good)["ok"], "and the good one still plays")
