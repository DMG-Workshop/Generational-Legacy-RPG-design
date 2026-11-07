## The nightly long run: the autopilot plays whole dynasties for many generations and each is measured against the
## budgets in data/game/budgets.json (save size, load time, time per generation, the journal's size, and the line
## carrying on). The battle-death share is judged against the 3-7% band when enough lives were played.
##
## Run: godot --headless --path . -s res://tools/long_run_check.gd -- [seeds=1-2] [gens=60] [races=human,elf] [check]
##      godot --headless --path . -s res://tools/long_run_check.gd -- list-races      (prints the starting races as JSON)
##   seeds  seeds to play, as a range (1-3) or a list (1,5,9); each seed plays one dynasty per race (default 1-2)
##   gens   generations per dynasty (default 60; a generation takes about a second to play)
##   races  starting races to play (default: all of them)
##   check  exit 1 when anything is over budget (default: only print)
## .github/workflows/long-runs.yml runs it every night, one race per job. The logic is in tools/long_run.gd.
extends SceneTree

const LongRun := preload("res://tools/long_run.gd")
const Balance := preload("res://tools/balance.gd")


func _init() -> void:
	GameData.load_all()
	var seeds: Array = Balance.seed_range(1, 2)
	var gens := 60
	var races: Array = GameData.starting_ids(GameData.races)
	var check := false
	for a in OS.get_cmdline_user_args():
		if a == "list-races":
			print(JSON.stringify(races))
			quit(0)
			return
		elif a == "check":
			check = true
		elif a.begins_with("seeds="):
			seeds = _seeds(a.substr(6))
		elif a.begins_with("gens="):
			gens = int(a.substr(5))
		elif a.begins_with("races="):
			races = Array(a.substr(6).split(",", false))
		else:
			print("Not understood: %s" % a)
			quit(2)
			return
	if seeds.is_empty() or gens < 1 or races.is_empty():
		print("Nothing to play: check seeds, gens and races.")
		quit(2)
		return
	for r in races:
		if not GameData.races.has(r):
			print("No such race: %s" % r)
			quit(2)
			return
	var b := LongRun.budgets()
	var problems: Array = []
	var lives := 0
	var slain := 0
	print("Long run: %d seeds x %d races x %d generations" % [seeds.size(), races.size(), gens])
	for s in seeds:
		for r in races:
			var m := LongRun.run_one(int(s), str(r), gens)
			print(LongRun.line(m))
			lives += int(m["lives"])
			slain += int(m["slain"])
			problems.append_array(LongRun.judge(m, b))
	problems.append_array(LongRun.judge_deaths(lives, slain, b))
	print("")
	print("%d lives, %d slain in battle (%.1f%%)." % [lives, slain, 100.0 * float(slain) / maxf(1.0, float(lives))])
	if problems.is_empty():
		print("Everything is within budget.")
	else:
		for p in problems:
			print("OVER BUDGET: %s" % p)
	quit(1 if check and not problems.is_empty() else 0)


func _seeds(text: String) -> Array:
	if "-" in text:
		var parts := text.split("-")
		return Balance.seed_range(int(parts[0]), int(parts[1])) if parts.size() == 2 else []
	var out: Array = []
	for p in text.split(",", false):
		out.append(int(p))
	return out
