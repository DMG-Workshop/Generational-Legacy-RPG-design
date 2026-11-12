## Replay files (GameReplay): a recorded run plays back to exactly the same dynasty. The autopilot's whole
## three-generation lives, and hand-given commands (rest, train, travel, hunts fought a turn at a time with
## the autopilot's tactics and with the heir's own commands, the world clock, a succession), are recorded, written
## as one line of text, read back and played: every fingerprint and the end match. A changed command or a
## missing one is found at the command where the run goes differently; a damaged, foreign, newer or hand-made
## replay is turned away with a reason and never run into a crash; commands the game does not allow are refused.
## A house founded with hard-mode options records them in its start (`hard`) and plays back as that house; a
## plain replay is byte-identical to the one written before options were recorded (tests/fixtures/replay_plain.txt).
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
	test_plain_fixture()
	test_hard_replays()
	test_damaged_hard()
	test_house_differs()
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


# ---------------------------------------------------------------- hard-mode options

const HARD_SETS := [
	{"permadeath": true},
	{"ironman": true},
	{"gen_cap": 10},
	{"permadeath": true, "ironman": true, "gen_cap": 25},
]


## A plain replay (no options) is the text it was before options were recorded: the fixture was made by
## tools/replay.gd on the commit before this change, and must still be the same text and play.
func test_plain_fixture() -> void:
	var fixture := FileAccess.get_file_as_string("res://tests/fixtures/replay_plain.txt")
	var rec := GameReplay.begin(1, "Tess", "warrior", GameData.traits_in(["bloodline"])[1 % GameData.traits_in(["bloodline"]).size()], "human")
	rec.bot_on(120)
	ok(rec.to_text() == fixture, "a plain replay is byte-identical to the one from before options were recorded")
	ok(not rec.to_dict()["start"].has("hard"), "and its start holds no hard-mode entry")
	ok(GameReplay.play(GameReplay.from_text(fixture)["replay"])["ok"], "the old replay still plays")
	var none := GameReplay.begin(1, "Tess", "warrior", GameData.traits_in(["bloodline"])[1 % GameData.traits_in(["bloodline"]).size()], "human", GameSex.MALE, 25, {"permadeath": false})
	none.bot_on(120)
	ok(none.to_text() == fixture, "options that are all off record nothing: the text is the same")


## A house founded with each set of options records them, plays back to the same fingerprint and is that house.
func test_hard_replays() -> void:
	for opts in HARD_SETS:
		var tag := JSON.stringify(opts)
		var bloodline: String = GameData.traits_in(["bloodline"])[3]
		var rec := GameReplay.begin(3, "Tess", "warrior", bloodline, "human", GameSex.MALE, 10, opts)
		rec.bot_on(300)
		var start: Dictionary = rec.to_dict()["start"]
		ok(start.has("hard") and typeof(start["hard"]) == TYPE_DICTIONARY, "%s: the founding writes its options" % tag)
		ok(GameHardMode.any(rec.dynasty) and rec.dynasty.hard == start["hard"], "%s: the house holds them as GameHardMode keeps them" % tag)
		var played := _play_text(rec.to_text())
		ok(played["ok"], "%s: a hard-mode replay plays back exactly (%s)" % [tag, played["error"]])
		if played["ok"]:
			var d: GameDynasty = played["dynasty"]
			ok(GameReplay.fingerprint(d) == GameReplay.fingerprint(rec.dynasty), "%s: to the very same dynasty" % tag)
			ok(d.hard == rec.dynasty.hard, "%s: founded with the same options" % tag)
			ok(GameHardMode.permadeath(d) == opts.get("permadeath", false) and GameHardMode.ironman(d) == opts.get("ironman", false)
				and GameHardMode.gen_cap(d) == int(opts.get("gen_cap", 0)), "%s: the options read back as set" % tag)
	# the same founding without options is a different replay: the options are part of the run
	var with := GameReplay.begin(3, "Tess", "warrior", GameData.traits_in(["bloodline"])[3], "human", GameSex.MALE, 10, {"ironman": true})
	with.bot_on(40)
	var plain := GameReplay.begin(3, "Tess", "warrior", GameData.traits_in(["bloodline"])[3], "human", GameSex.MALE, 10)
	plain.bot_on(40)
	ok(with.to_text() != plain.to_text(), "a house with an option is not the plain house's replay")


## Each damaged or hand-made hard-mode entry is turned away with a reason, never a crash.
## "Both iron-man and no-death set" reads as iron-man on with permadeath written out as off, a shape a house
## never keeps; both options on together are fine and are tested above.
func test_damaged_hard() -> void:
	var good := GameReplay.begin(4, "Tess", "mage", GameData.traits_in(["bloodline"])[0], "elf", GameSex.FEMALE, 5, {"permadeath": true, "gen_cap": 25})
	good.bot_on(40)
	var base := good.to_dict()
	ok(GameReplay.play(base)["ok"], "the good hard-mode replay plays before it is damaged")
	var bad := {
		"a wrong type": "permadeath",
		"an unknown key": {"speed": true},
		"a cap not on the list": {"gen_cap": 7},
		"iron-man with permadeath written out as off": {"ironman": true, "permadeath": false},
		"a huge cap": {"gen_cap": 1.0e300},
		"a cap that is not a whole number": {"gen_cap": 25.5},
		"a cap that is text": {"gen_cap": "25"},
		"an option that is not yes or no": {"permadeath": "yes"},
		"an option written off": {"permadeath": true, "ironman": false},
	}
	for name in bad:
		var r: Dictionary = base.duplicate(true)
		r["start"]["hard"] = bad[name]
		var res := GameReplay.play(r)
		ok(not res["ok"] and "hard-mode" in res["error"] and res["dynasty"] == null, "turned away with a reason: %s (%s)" % [name, res["error"]])
		var chk := GameReplay.check(r)
		ok(not chk["ok"] and chk["error"] != "", "and the check says why: %s" % name)
	# the same damage as text: a pasted block is turned away at reading, with the reason
	var r3: Dictionary = base.duplicate(true)
	r3["start"]["hard"] = {"gen_cap": 7}
	var read := GameReplay.from_text(GameReplay.PREFIX + Marshalls.raw_to_base64(JSON.stringify(r3).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)))
	ok(not read["ok"] and "hard-mode" in read["error"], "a damaged block is refused as text, with the reason (%s)" % read["error"])
	# an empty entry means no options and plays as a plain house
	var r4: Dictionary = base.duplicate(true)
	r4["start"]["hard"] = {}
	ok(GameReplay.check(r4)["ok"], "an empty entry is no options")


## A hard-mode replay played on a house that differs says where the run first went differently.
func test_house_differs() -> void:
	# founded differently: the fingerprint includes the options, so the first check is where it differs
	var rec := GameReplay.begin(6, "Tess", "warrior", GameData.traits_in(["bloodline"])[2], "human", GameSex.MALE, 1, {"permadeath": true})
	rec.bot_on(30)
	var rep := rec.to_dict()
	var swapped: Dictionary = rep.duplicate(true)
	swapped["start"]["hard"] = {"ironman": true}
	var res := GameReplay.play(swapped)
	ok(not res["ok"] and res["diverged_at"] == 0 and "went differently after command 0" in res["error"],
		"a house founded with other options is found at its first command (%d: %s)" % [res["diverged_at"], res["error"]])
	var plain: Dictionary = rep.duplicate(true)
	plain["start"].erase("hard")
	var res2 := GameReplay.play(plain)
	ok(not res2["ok"] and res2["diverged_at"] == 0, "a house founded plain is found at its first command too")
	# a changed rule: a death the record survived (passed on) now ends the line. Find a run whose first death is one.
	var rep_changed := {}
	var cause := ""
	for sd in range(1, 13):
		var r2 := GameReplay.begin(sd, "Tess", "warrior", GameData.traits_in(["bloodline"])[sd % GameData.traits_in(["bloodline"]).size()], "human", GameSex.MALE, 1, {"permadeath": true})
		r2.bot_on(400)
		if not r2.dynasty.history.is_empty() and str(r2.dynasty.history[0]["cause"]) != "slain in battle":
			rep_changed = r2.to_dict()
			cause = str(r2.dynasty.history[0]["cause"])
			break
	ok(not rep_changed.is_empty(), "a permadeath run had a death it passed on (cause '%s')" % cause)
	if rep_changed.is_empty():
		return
	ok(GameReplay.play(rep_changed)["ok"], "that run plays under the rule it was made with")
	var causes: Array = GameHardMode.data()["settings"]["permadeath_causes"]
	GameHardMode.data()["settings"]["permadeath_causes"] = causes + [cause]
	var changed := GameReplay.play(rep_changed)
	GameHardMode.data()["settings"]["permadeath_causes"] = causes
	ok(not changed["ok"] and "went differently" in changed["error"] and changed["diverged_at"] >= 0,
		"under a changed rule it says where: %s" % changed["error"])
	ok(GameReplay.play(rep_changed)["ok"], "and with the rule put back the run plays again")
