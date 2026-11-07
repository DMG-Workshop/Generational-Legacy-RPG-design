## The nightly long run's logic (tools/long_run.gd, data/game/budgets.json): a dynasty played for several generations is
## measured (generations reached, save size, load time, time per generation, journal) and held to the budgets;
## each budget catches what it is for, a within-budget run reports nothing, the death band is judged only when
## enough lives were played, and the budgets file is complete and leaves room over what the autopilot measures.
## Run: godot --headless --path . -s res://tests/test_game_long_run.gd
extends SceneTree

const LongRun := preload("res://tools/long_run.gd")

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
	test_budgets()
	test_run()
	test_judging()
	test_deaths()
	print("%d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func test_budgets() -> void:
	var b := LongRun.budgets()
	for k in ["max_save_bytes_base", "max_save_bytes_per_generation", "max_load_ms", "max_ms_per_generation", "max_journal_lines", "min_lives_for_death_band"]:
		ok(b.has(k) and (typeof(b[k]) == TYPE_FLOAT or typeof(b[k]) == TYPE_INT) and float(b[k]) > 0.0, "the budget '%s' is a positive number" % k)
	# the autopilot's journal is held at its cap, so the budget must leave room above it
	ok(int(b["max_journal_lines"]) > 300, "the journal budget is above the journal's own cap")


func test_run() -> void:
	var m := LongRun.run_one(3, "human", 5)
	ok(int(m["reached"]) == 6 and int(m["lives"]) == 5 and str(m["state"]) == "life", "five generations are played and the sixth heir is chosen (reached %d)" % int(m["reached"]))
	ok(bool(m["loaded"]), "the final save loads back to the same generation")
	ok(int(m["save_bytes"]) > 5000 and int(m["save_bytes"]) < 200000, "the save has a believable size (%d bytes)" % int(m["save_bytes"]))
	ok(float(m["load_ms"]) >= 0.0 and float(m["play_ms"]) > 0.0 and float(m["ms_per_gen"]) > 0.0, "the times are measured")
	ok(int(m["slain"]) >= 0 and int(m["slain"]) <= int(m["lives"]), "deaths in battle are counted among the lives")
	ok(LongRun.line(m).begins_with("seed 3"), "a run reports as a line")
	var again := LongRun.run_one(3, "human", 5)
	ok(int(again["save_bytes"]) == int(m["save_bytes"]) and int(again["slain"]) == int(m["slain"]), "the same seed measures the same size and deaths")
	var b := LongRun.budgets()
	ok(LongRun.judge(m, b).is_empty(), "a normal run is within the budgets (%s)" % str(LongRun.judge(m, b)))
	# room above what the autopilot does: the 5-generation run uses a fraction of each exact budget
	var max_bytes := int(b["max_save_bytes_base"]) + int(b["max_save_bytes_per_generation"]) * int(m["reached"])
	ok(int(m["save_bytes"]) * 1.2 < max_bytes, "the size budget leaves room (%d of %d)" % [int(m["save_bytes"]), max_bytes])
	ok(float(m["load_ms"]) * 4.0 < float(b["max_load_ms"]), "the load budget leaves room (%.1f of %.0f ms)" % [float(m["load_ms"]), float(b["max_load_ms"])])


func test_judging() -> void:
	var b := LongRun.budgets()
	var good := {"seed": 1, "race": "elf", "gens": 10, "reached": 11, "lives": 10, "slain": 0, "save_bytes": 20000, "load_ms": 5.0,
		"play_ms": 9000.0, "ms_per_gen": 900.0, "journal": 300, "history": 10, "state": "life", "loaded": true}
	ok(LongRun.judge(good, b).is_empty(), "a good run reports nothing")
	var cases := {
		"a save that is too big": {"save_bytes": 999999},
		"a load that is too slow": {"load_ms": 9999.0},
		"a generation that is too slow": {"ms_per_gen": 99999.0},
		"a journal that grew": {"journal": 5000},
		"a save that does not load back": {"loaded": false},
		"a line that stopped": {"reached": 4},
	}
	for name in cases:
		var m: Dictionary = good.duplicate()
		for k in cases[name]:
			m[k] = cases[name][k]
		var found := LongRun.judge(m, b)
		ok(found.size() == 1 and "seed 1 elf" in found[0], "%s is the one thing reported (%s)" % [name, str(found)])
	var done: Dictionary = good.duplicate()
	done["reached"] = 4
	done["state"] = "ended"
	ok(LongRun.judge(done, b).is_empty(), "a line that ended at the last generation is not a stop")
	# the size budget grows with the generations reached
	var long_run: Dictionary = good.duplicate()
	long_run["reached"] = 101
	long_run["gens"] = 100
	long_run["save_bytes"] = 60000
	ok(LongRun.judge(long_run, b).is_empty(), "a bigger save is allowed after more generations")
	var short: Dictionary = good.duplicate()
	short["save_bytes"] = 60000
	ok(not LongRun.judge(short, b).is_empty(), "but not after few")


func test_deaths() -> void:
	var b := LongRun.budgets()
	var enough := int(b["min_lives_for_death_band"])
	ok(LongRun.judge_deaths(enough - 1, enough - 1, b).is_empty(), "too few lives say nothing about the death band")
	ok(LongRun.judge_deaths(enough, int(enough * 0.05), b).is_empty(), "5% of enough lives is in the band")
	ok(LongRun.judge_deaths(enough, 0, b).size() == 1, "none slain in enough lives is below the band")
	ok(LongRun.judge_deaths(enough, int(enough * 0.2), b).size() == 1, "a fifth slain is above it")
