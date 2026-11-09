## Error reports that carry a save (roadmap item 54): the data and ways to break it; what a report holds and the limits
## on it (only listed facts about the device, a short note, the last errors and journal lines); the block of text and
## reading it back; the save inside it loading as the same house, a fight in progress included, and as a house backup
## the game can load; every kind of damage turned away with a reason; the error log catching what the engine logs; and
## that making a report changes nothing.
## Run: godot --headless --path . -s res://tests/test_game_report.gd
extends SceneTree

const Scen := preload("res://tests/round_scenarios.gd")

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
	test_data()
	test_build()
	test_round_trip()
	test_the_save()
	test_damage()
	test_error_log()
	test_pure()
	print("report tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _lived(seed_value: int = 7, steps: int = 40) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	for i in steps:
		if d.state == "ended":
			break
		GameBot.step(d)
	return d


func _pack(v: Variant) -> String:
	return GameReport.PREFIX + Marshalls.raw_to_base64(JSON.stringify(v).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))


# ---------------------------------------------------------------- data

func test_data() -> void:
	ok(GameReport.validate().is_empty(), "the data is sound: %s" % str(GameReport.validate()))
	var saved: Dictionary = GameReport.data().duplicate(true)
	GameReport.data()["settings"]["max_errors"] = 0
	ok(not GameReport.validate().is_empty(), "a report that keeps no errors is found")
	GameReport._cache = saved.duplicate(true)
	GameReport.data()["env_keys"] = []
	ok(not GameReport.validate().is_empty(), "no list of what may be kept about the device is found")
	GameReport._cache = saved.duplicate(true)
	GameReport.data()["text"].erase("never_sent")
	ok(not GameReport.validate().is_empty(), "a missing line of text is found")
	GameReport._cache = saved.duplicate(true)
	GameReport.data()["text"]["holds"] = ["Everything."]
	ok(not GameReport.validate().is_empty(), "a consent text that does not say what is held is found")
	GameReport._cache = {}
	ok(GameReport.validate().is_empty(), "(and the data is whole again after)")
	ok(GameReport.holds().size() >= 4 and str(GameReport.holds()).contains("save") and GameReport.text("never_sent").contains("does not send"), "the player is told what a report holds and that it is not sent")


# ---------------------------------------------------------------- what a report holds

func test_build() -> void:
	var d := _lived()
	var env := {"os": "Android", "model": "Pixel 8", "screen": "1080x2400", "text_size": 1.25, "email": "someone@example.com", "user": "tess", "path": "/home/tess"}
	var errors: Array = []
	for i in 30:
		errors.append("ERROR: thing %d went wrong" % i)
	var r := GameReport.build(d, env, errors, "It froze when I opened the pack.")
	ok(r["format"] == GameReport.FORMAT and r["game"] == GameReport.game_version() and r["game"] != "" and r["save_version"] == GameSaveVersion.CURRENT, "a report names the game's version and the save's format (%s, %d)" % [r["game"], r["save_version"]])
	ok(r["env"] == {"os": "Android", "model": "Pixel 8", "screen": "1080x2400", "text_size": "1.25"}, "of the device it keeps only the listed facts: %s" % str(r["env"]))
	ok(not JSON.stringify(r["env"]).contains("example.com") and not JSON.stringify(r["env"]).contains("/home"), "(an email or a path offered by the screen is not kept)")
	ok(r["note"] == "It froze when I opened the pack.", "the player's note is kept")
	ok(r["errors"].size() == 20 and r["errors"].back() == "ERROR: thing 29 went wrong" and r["errors"][0] == "ERROR: thing 10 went wrong", "the last 20 errors are kept, the newest last")
	ok(r["journal"].size() <= 30 and r["journal"].size() > 0 and r["journal"].back() == d.journal.back(), "and the last lines of the journal (%d)" % r["journal"].size())
	ok(r["save"] == d.to_save(), "and the save itself")
	var long := GameReport.build(d, {"model": "x".repeat(500) + "\nsecond line"}, ["e".repeat(5000), 7, null, {"a": 1}], "n".repeat(5000))
	ok(long["note"].length() == 500 and long["errors"].size() == 1 and long["errors"][0].length() == 600 and long["env"]["model"].length() == 80 and not long["env"]["model"].contains("\n"), "long notes, errors and device facts are cut short, and things that are not text are dropped")
	var none := GameReport.build(null, {"os": "iOS"}, ["ERROR: could not load"], "It will not open.")
	ok(none["save"] == null and none["journal"].is_empty() and none["errors"].size() == 1, "a report can be made with no house at all (the game could not load one)")
	ok(GameReport.clean_env("nope").is_empty() and GameReport.clean_env({"os": ["a"]}).is_empty(), "facts that are not plain values are not kept")


# ---------------------------------------------------------------- the block of text

func test_round_trip() -> void:
	var d := _lived()
	var r := GameReport.build(d, {"os": "Android", "model": "Pixel 8"}, ["ERROR: one", "SCRIPT ERROR: two"], "A note.")
	var text := GameReport.to_text(r)
	ok(text.begins_with("GLER1:") and not text.contains("\n") and text.length() < 40000, "a report is one line of text (%d characters)" % text.length())
	var read := GameReport.from_text(text)
	ok(read["ok"] and read["error"] == "", "and reads back")
	var back: Dictionary = read["report"]
	ok(back["game"] == r["game"] and back["env"] == r["env"] and back["note"] == r["note"] and back["errors"] == r["errors"] and back["journal"] == r["journal"], "with the same version, device, note, errors and journal")
	ok(JSON.stringify(back["save"]) == JSON.stringify(JSON.parse_string(JSON.stringify(r["save"]))), "and the same save")
	var wrapped := ""
	for i in range(0, text.length(), 60):
		wrapped += text.substr(i, 60) + "\n  "
	ok(GameReport.from_text(wrapped)["ok"], "a block wrapped by a message (spaces and line breaks) still reads")
	ok(GameReport.summary(back).contains("House %s" % d.dynasty_name) and GameReport.summary(back).contains("2 errors") and GameReport.summary(back).contains("generation %d" % d.gen), "its summary names the house: %s" % GameReport.summary(back))
	var empty := GameReport.from_text(GameReport.to_text(GameReport.build(null, {}, [], "")))
	ok(empty["ok"] and empty["report"]["save"] == null and GameReport.summary(empty["report"]).contains("No save") and GameReport.dynasty(empty["report"]) == null and GameReport.backup_text(empty["report"]) == "", "a report with no save reads, and says so")


# ---------------------------------------------------------------- the save inside it

func test_the_save() -> void:
	var d := _lived(9, 60)
	var read := GameReport.from_text(GameReport.to_text(GameReport.build(d)))
	var again := GameReport.dynasty(read["report"])
	ok(again != null and JSON.stringify(again.to_dict()) == JSON.stringify(GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_save()))).to_dict()) and again.rng.state == d.rng.state, "the house in a report loads as the same house, dice and all")
	GameBot.step(d)
	GameBot.step(again)
	ok(JSON.stringify(d.to_dict()) == JSON.stringify(again.to_dict()), "and plays on the same way (the problem can be met again)")
	var fighting: GameDynasty = Scen.make(4, "warrior", 1, "hunt")
	ok(fighting.battle != null, "(a house in a fight)")
	var mid := GameReport.dynasty(GameReport.from_text(GameReport.to_text(GameReport.build(fighting)))["report"])
	ok(mid != null and mid.battle != null and mid.battle.enemies.size() == fighting.battle.enemies.size(), "a report made in a fight opens in that fight")
	var backup := GameReport.backup_text(read["report"])
	var imported := GameSaves.import_text(backup)
	ok(backup.begins_with(GameSaves.BACKUP_PREFIX) and imported["ok"] and imported["house"] == d.dynasty_name, "the save comes out as a house backup the game's own Load reads (%s)" % str(imported["error"]))


# ---------------------------------------------------------------- damage

func test_damage() -> void:
	var d := _lived()
	var good := GameReport.build(d, {"os": "Android"}, ["ERROR: x"], "note")
	var text := GameReport.to_text(good)
	for junk in ["", "hello", "GLBK1:abcd", "GLER1:", "GLER1:!!!!", "GLER1:abc", "GLER1:AAAA", text.substr(0, text.length() / 2), text + "A", "GLER1:" + Marshalls.raw_to_base64("not gzip at all, just text".to_utf8_buffer())]:
		var r := GameReport.from_text(junk)
		ok(not r["ok"] and r["error"] != "" and r["report"].is_empty(), "'%s' is turned away: %s" % [junk.substr(0, 24), r["error"]])
	ok(GameReport.from_text(GameSaves.BACKUP_PREFIX + text.substr(6))["error"] == GameReport.text("not_a_report"), "a house backup is not a report")
	for bad in [[1, 2], "text", 5, {}, {"format": "one"}, {"format": 0}, {"format": -3}]:
		ok(not GameReport.from_text(_pack(bad))["ok"], "a block that unpacks to %s is not a report" % str(bad))
	var newer := good.duplicate(true)
	newer["format"] = GameReport.FORMAT + 1
	ok(GameReport.from_text(_pack(newer))["error"] == GameReport.text("too_new"), "a report from a newer game says so")
	var bad_save := good.duplicate(true)
	bad_save["save"] = {"dynasty_name": "X"}
	var r1 := GameReport.from_text(_pack(bad_save))
	ok(not r1["ok"] and r1["error"].contains("cannot be played"), "a report whose save is not a house is turned away: %s" % r1["error"])
	var future := good.duplicate(true)
	future["save"]["version"] = GameSaveVersion.CURRENT + 5
	var r2 := GameReport.from_text(_pack(future))
	ok(not r2["ok"] and r2["error"].contains("cannot be played"), "so is one whose save is from a newer game: %s" % r2["error"])
	for junk_save in [5, "save", [1], true]:
		var js := good.duplicate(true)
		js["save"] = junk_save
		ok(not GameReport.from_text(_pack(js))["ok"], "and one whose save is %s" % str(junk_save))
	var messy := good.duplicate(true)
	messy["env"] = {"os": "Android", "secret": "hunter2", "model": 5}
	messy["errors"] = ["ERROR: a", 5, null, ["x"], "ERROR: b"]
	messy["note"] = 12
	messy["journal"] = "not a list"
	messy["game"] = ["x"]
	messy["extra"] = {"anything": true}
	var r3 := GameReport.from_text(_pack(messy))
	ok(r3["ok"] and r3["report"]["env"] == {"os": "Android", "model": "5"} and r3["report"]["errors"] == ["ERROR: a", "ERROR: b"] and r3["report"]["note"] == "" and r3["report"]["journal"].is_empty() and r3["report"]["game"] == "" and not r3["report"].has("extra"), "a report with odd fields reads, cleaned: unknown keys and wrong types dropped")
	var huge := good.duplicate(true)
	huge["errors"] = []
	for i in 500:
		huge["errors"].append("ERROR: %d" % i)
	ok(GameReport.from_text(_pack(huge))["report"]["errors"].size() == 20, "and one stuffed with errors keeps the last 20")


# ---------------------------------------------------------------- the error log

func test_error_log() -> void:
	ok(not GameErrorLog.installed() and GameErrorLog.recent().is_empty(), "the error log is off until it is asked for")
	push_warning("(test) a warning before the log is on")
	ok(GameErrorLog.recent().is_empty(), "and remembers nothing while off")
	GameErrorLog.install(5)
	GameErrorLog.install(5)
	ok(GameErrorLog.installed(), "installed (twice over is once)")
	push_error("(test) the forge is cold")
	push_warning("(test) the well is low")
	print("an ordinary line")
	var got := GameErrorLog.recent()
	ok(got.size() == 2, "an error and a warning are remembered, a printed line is not (%d)" % got.size())
	ok(got.size() == 2 and str(got[0]).begins_with("ERROR: (test) the forge is cold") and str(got[1]).begins_with("WARNING: (test) the well is low"), "each as a line with its kind and its words: %s" % str(got).substr(0, 120))
	ok(got.size() == 2 and str(got[0]).contains("test_game_report.gd"), "and where in the game's scripts it came from")
	for i in 8:
		push_warning("(test) warning %d" % i)
	got = GameErrorLog.recent()
	ok(got.size() == 5 and str(got.back()).contains("warning 7") and str(got[0]).contains("warning 3"), "only the last few are kept, the newest last")
	var report := GameReport.build(_lived(7, 5), {}, GameErrorLog.recent(), "")
	ok(report["errors"].size() == 5 and str(report["errors"].back()).contains("warning 7"), "they go into a report as they are")
	GameErrorLog.clear()
	ok(GameErrorLog.recent().is_empty() and GameErrorLog.installed(), "the log can be emptied")
	GameErrorLog.remove()
	push_warning("(test) a warning after the log is off")
	ok(not GameErrorLog.installed() and GameErrorLog.recent().is_empty(), "and taken out again, after which nothing is remembered")
	ok(GameErrorLog.line_for(2, "Invalid call", "", "_go", "res://x.gd", 12) == "SCRIPT ERROR: Invalid call (_go, res://x.gd:12)" and GameErrorLog.line_for(99, "c", "why", "f", "g", 1).begins_with("ERROR: why"), "a line names the kind, the reason and the place")


# ---------------------------------------------------------------- pure

func test_pure() -> void:
	var d := _lived()
	var rng_before := d.rng.state
	var before := JSON.stringify(d.to_save())
	var text := GameReport.to_text(GameReport.build(d, {"os": "x"}, ["e"], "n"))
	GameReport.dynasty(GameReport.from_text(text)["report"])
	ok(d.rng.state == rng_before and JSON.stringify(d.to_save()) == before, "making and reading a report draws no dice and changes nothing")
	ok(GameReport.to_text(GameReport.build(d, {"os": "x"}, ["e"], "n")) == text, "the same house makes the same report")
