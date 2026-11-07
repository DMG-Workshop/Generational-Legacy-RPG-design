## The long-run check's logic, apart from its command line (tools/long_run_check.gd), so a test can cover it:
## the autopilot plays a dynasty for many generations, and the run is measured against the budgets in
## data/game/budgets.json: how big the save grows, how long it takes to load, how long a generation takes to play,
## and whether the line carries on (the autopilot must reach every generation asked for).
extends RefCounted

const BLOODLINE := "faetouched"
const BUDGETS := "res://data/game/budgets.json"


static func budgets() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(BUDGETS))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## One dynasty played for up to `gens` generations. Returns the measurements:
## {seed, race, class, gens, reached, lives, slain, save_bytes, load_ms, play_ms, ms_per_gen, journal, history, state}.
static func run_one(seed_val: int, race: String, gens: int) -> Dictionary:
	GameData.load_all()
	var classes := GameData.starting_ids(GameData.classes)
	var cls: String = classes[seed_val % classes.size()]
	var d := GameDynasty.new_game(seed_val, "", cls, BLOODLINE, race)
	var lives := 0
	var slain := 0
	var t0 := Time.get_ticks_usec()
	for g in gens:
		GameBot.live_life(d)
		lives += 1
		if str(d.last_death.get("cause", "")) == "slain in battle":
			slain += 1
		if d.state != "succession":
			break
		GameBot.choose_best(d)
	var play_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	var text := JSON.stringify(d.to_save())
	var t1 := Time.get_ticks_usec()
	var parsed = JSON.parse_string(text)
	var loaded: GameDynasty = null
	if typeof(parsed) == TYPE_DICTIONARY and GameSaveVersion.upgrade(parsed) == "":
		loaded = GameDynasty.from_dict(parsed)
	var load_ms := float(Time.get_ticks_usec() - t1) / 1000.0
	return {"seed": seed_val, "race": race, "class": cls, "gens": gens, "reached": d.gen, "lives": lives, "slain": slain,
		"save_bytes": text.length(), "load_ms": load_ms, "play_ms": play_ms, "ms_per_gen": play_ms / maxf(1.0, float(lives)),
		"journal": d.journal.size(), "history": d.history.size(), "state": d.state, "loaded": loaded != null and loaded.gen == d.gen}


## What is over budget in one run: a list of readable lines, empty when it is within. Time budgets are generous
## (a shared machine is slow and noisy); size and carrying on are exact.
static func judge(m: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	var who := "seed %d %s" % [int(m["seed"]), m["race"]]
	if not bool(m.get("loaded", false)):
		out.append("%s: the final save did not load back to the same generation" % who)
	if int(m["reached"]) < int(m["gens"]) and str(m["state"]) != "ended":
		out.append("%s: the line stopped at generation %d of %d (state %s)" % [who, int(m["reached"]), int(m["gens"]), m["state"]])
	var max_bytes := int(b["max_save_bytes_base"]) + int(b["max_save_bytes_per_generation"]) * int(m["reached"])
	if int(m["save_bytes"]) > max_bytes:
		out.append("%s: the save is %s bytes, over the %s budget for %d generations" % [who, GameText.num(int(m["save_bytes"])), GameText.num(max_bytes), int(m["reached"])])
	if float(m["load_ms"]) > float(b["max_load_ms"]):
		out.append("%s: loading took %.0f ms, over the %.0f ms budget" % [who, float(m["load_ms"]), float(b["max_load_ms"])])
	if float(m["ms_per_gen"]) > float(b["max_ms_per_generation"]):
		out.append("%s: a generation took %.0f ms to play, over the %.0f ms budget" % [who, float(m["ms_per_gen"]), float(b["max_ms_per_generation"])])
	if int(m["journal"]) > int(b["max_journal_lines"]):
		out.append("%s: the journal holds %d lines, over %d" % [who, int(m["journal"]), int(b["max_journal_lines"])])
	return out


## The whole set's battle-death share judged against the band (by the balance tool's own rule), as a line.
## Empty when in band or when too few lives were played to say.
static func judge_deaths(all_lives: int, all_slain: int, b: Dictionary) -> Array:
	if all_lives < int(b["min_lives_for_death_band"]):
		return []
	var Balance := load("res://tools/balance.gd")
	var percent := 100.0 * float(all_slain) / float(all_lives)
	var verdict: String = Balance.verdict(percent, all_lives)
	return [] if verdict == "IN BAND" else ["battle deaths are %.1f%% of %d lives: %s" % [percent, all_lives, verdict]]


static func line(m: Dictionary) -> String:
	return "seed %-4d %-9s gen %-4d save %8s B  load %6.0f ms  %5.0f ms/gen  journal %d" % [int(m["seed"]), m["race"], int(m["reached"]), GameText.num(int(m["save_bytes"])), float(m["load_ms"]), float(m["ms_per_gen"]), int(m["journal"])]
