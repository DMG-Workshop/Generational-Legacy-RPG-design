## The balance harness's logic (tools/balance.gd): seed lists, the 95% range, the verdict against the
## band, and a small autopilot batch that must be reproducible and add up. This keeps the tool from
## breaking unnoticed when the game code it calls changes.
## Run: godot --headless --path . -s res://tests/test_game_balance_tool.gd
extends SceneTree

const Balance := preload("res://tools/balance.gd")

var checks := 0
var fails := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	GameData.load_all()
	test_seeds()
	test_range_and_verdict()
	test_counting()
	test_batch()
	print("balance tool tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func test_seeds() -> void:
	ok(Balance.parse_seeds("1-3") == [1, 2, 3], "a range: %s" % str(Balance.parse_seeds("1-3")))
	ok(Balance.parse_seeds("1,5,9") == [1, 5, 9], "a list")
	ok(Balance.parse_seeds("1-3,9") == [1, 2, 3, 9], "a range and a number")
	ok(Balance.parse_seeds("7") == [7], "one seed")
	ok(Balance.parse_seeds("").is_empty(), "nothing")
	ok(Balance.parse_seeds("3-1").is_empty(), "a backwards range is empty, not an endless one")
	ok(Balance.seed_range(2, 4) == [2, 3, 4], "seed_range includes both ends")


func test_range_and_verdict() -> void:
	# 48 of 1200 (4.0%): the 95% Wilson range works out to 3.03-5.26%.
	var r := Balance.wilson(48, 1200)
	ok(absf(r.x - 3.03) < 0.05 and absf(r.y - 5.26) < 0.05, "the range for 48 of 1200 is about 3.0-5.3%%: %.2f-%.2f" % [r.x, r.y])
	ok(Balance.wilson(0, 0) == Vector2.ZERO, "no lives, no range")
	ok(Balance.wilson(0, 100).x == 0.0 or absf(Balance.wilson(0, 100).x) < 1e-9, "no deaths: the range starts at zero")
	ok(Balance.wilson(5, 100).x < 5.0 and Balance.wilson(5, 100).y > 5.0, "the range holds the share")
	ok(Balance.wilson(5, 1000).y - Balance.wilson(5, 1000).x < Balance.wilson(5, 100).y - Balance.wilson(5, 100).x, "more lives, a tighter range")
	ok(Balance.verdict(2.99, 10) == "BELOW BAND", "just under the floor")
	ok(Balance.verdict(3.0, 10) == "IN BAND", "the floor is in the band")
	ok(Balance.verdict(7.0, 10) == "IN BAND", "the ceiling is in the band")
	ok(Balance.verdict(7.01, 10) == "ABOVE BAND", "just over the ceiling")
	ok(Balance.verdict(5.0, 0) == "NO LIVES PLAYED", "no lives is not a pass")
	ok(Balance.BAND_LOW == 3.0 and Balance.BAND_HIGH == 7.0, "the band is the roadmap's 3-7%")
	var t := Balance.blank()
	t["lives"] = 200
	t["slain"] = 9
	ok(absf(Balance.share(t) - 4.5) < 1e-9, "share is slain over lives")
	var u := Balance.blank()
	u["lives"] = 100
	u["slain"] = 1
	Balance.add(t, u)
	ok(t["lives"] == 300 and t["slain"] == 10, "totals add")
	ok(Balance.share(Balance.blank()) == 0.0, "an empty total has a share of zero, not a division error")
	ok("300 lives" in Balance.line(t) and "slain  10" in Balance.line(t), "the line shows lives and slain: %s" % Balance.line(t))


## The harness counts lives whose cause is the game's "slain in battle"; a misspelling would make every
## run report 0%, so the count is tested on made-up records and the phrase is tied to the game's source.
func test_counting() -> void:
	var t := Balance.blank()
	Balance.record(t, {"cause": "slain in battle", "level": 40, "age": 30})
	Balance.record(t, {"cause": "old age", "level": 60, "age": 80})
	Balance.record(t, {"cause": "slain in battle", "level": 20, "age": 25})
	ok(t["lives"] == 3 and t["slain"] == 2, "two of three lives were slain: %s" % str(t))
	ok(absf(float(t["level"]) - 120.0) < 1e-9 and absf(float(t["age"]) - 135.0) < 1e-9, "levels and ages add up")
	var u := Balance.blank()
	Balance.record(u, {})
	Balance.record(u, {"cause": "Slain in battle"})
	ok(u["lives"] == 2 and u["slain"] == 0, "a record without the exact cause is a life, not a battle death")
	var source := FileAccess.get_file_as_string("res://core/game/game_dynasty.gd")
	ok(source.contains("_die(\"%s\")" % Balance.SLAIN), "the game still ends a defeated heir's life with the phrase '%s'" % Balance.SLAIN)


func test_batch() -> void:
	# One life each for two races: the first heir of a dynasty is the founder's race.
	var a := Balance.play_batch(1, ["human", "elf"], 1)
	ok(a["total"]["lives"] == 2, "two dynasties, one generation each: %d lives" % int(a["total"]["lives"]))
	ok(a["by_race"].has("human") and a["by_race"].has("elf") and a["by_race"]["human"]["lives"] == 1 and a["by_race"]["elf"]["lives"] == 1, "one life of each race")
	ok(float(a["total"]["level"]) > 0.0 and float(a["total"]["age"]) > 0.0, "levels and ages are recorded")
	ok(int(a["total"]["slain"]) in [0, 1, 2], "slain is a count of those lives")
	# The same seed plays the same lives.
	var b := Balance.play_batch(1, ["human", "elf"], 1)
	ok(a == b, "the same seed and arguments give the same batch")
	# More generations: the totals are the sum of the races, and the lives are counted once.
	var c := Balance.play_batch(2, ["human"], 3)
	var lives := 0
	var slain := 0
	for race in c["by_race"]:
		lives += int(c["by_race"][race]["lives"])
		slain += int(c["by_race"][race]["slain"])
	ok(lives == int(c["total"]["lives"]) and slain == int(c["total"]["slain"]), "the races add up to the total (%d lives)" % lives)
	ok(lives >= 1 and lives <= 3, "at most one life per generation asked for: %d" % lives)
	# A different founding seed starts a different dynasty: not the same ages, in practice.
	var d := Balance.play_batch(3, ["human", "elf"], 1)
	ok(d != a, "another seed tells another story")
