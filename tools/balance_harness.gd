## The balance harness: the autopilot plays whole dynasties, and the share of heirs slain in battle is
## compared with the roadmap's 3-7% band. Run it after any change that could move a seeded fight.
##
## Run: godot --headless --path . -s res://tools/balance_harness.gd -- [seeds=1-12] [gens=10] [races=human,elf] [jobs=4] [subclass=<id|all|none>] [keep] [profile=<id|none>] [check]
##   seeds  base seeds, as a range (1-12) or a list (1,5,9). Each seed is a batch that plays one dynasty
##          per starting race, so a batch is 8 dynasties and, at 10 generations, about 80 lives (default 1-12)
##   gens   generations played per dynasty (default 10)
##   races  starting races to play (default: all of them)
##   jobs   batches run at the same time, each in its own process (default: one per processor)
##   subclass  found each dynasty in a calling: one of the twenty ids, "none", or "all" for a sweep (the baseline and
##          each calling in turn, one line each); the calling passes down at the game's own 50% chance
##   keep   with subclass: every heir carries the calling, not only the ones it is passed down to
##   profile  play the lives as a profile bot (forge, miner, builder, farmer, breeder, forager, fleer: GameProfile), and report the gold-equivalent gain and the
##          effort per life beside the usual figures; "none" is the plain autopilot
##   check  exit 1 when the overall share is outside the band (default: only print)
##
## The numbers are this tool's own baseline: they follow from the seeds it plays, so compare before and
## after a change on the same arguments, not with figures quoted from older tools. One batch is only about
## 80 lives, so a single seed swings by several points; read the overall figure and its range. The harness
## writes small temporary files (one per batch) to the system temp folder and removes them. See docs/BALANCE.md.
## The logic is in tools/balance.gd, which tests/test_game_balance_tool.gd covers.
extends SceneTree

const Balance := preload("res://tools/balance.gd")

var _seeds: Array = []
var _gens := 10
var _races: Array = []
var _jobs := 0
var _check := false
var _subclass := ""   # "" none, a subclass id, or "all" for the sweep
var _profile := ""    # a profile bot (GameProfile id), "" for the plain autopilot
var _keep := false     # the calling on every heir, not only the ones it is passed down to
var _out := ""   # worker mode: write this batch's totals here as JSON instead of printing a report


func _init() -> void:
	GameData.load_all()
	_races = GameData.starting_ids(GameData.races)
	_seeds = Balance.seed_range(1, 12)
	if not _read_args():
		quit(2)
		return
	if _out != "":
		_work()
		quit(0)
		return
	var started := Time.get_ticks_msec()
	if _subclass == "all":
		_sweep(started)
		return
	var batches := _run_batches(_subclass)
	var all := Balance.blank()
	var by_race := {}
	var what := "" if _subclass == "" else ", subclass %s%s" % [_subclass, " on every heir" if _keep else ""]
	print("Balance harness: %d races x %d seeds x %d generations (%s%s)" % [_races.size(), _seeds.size(), _gens, ", ".join(_races.map(func(r): return str(r))), what])
	for i in _seeds.size():
		var b: Dictionary = batches[i]
		if b.is_empty():
			print("  seed %-4d FAILED: the batch produced no result" % int(_seeds[i]))
			continue
		Balance.add(all, b["total"])
		for race in b["by_race"]:
			if not by_race.has(race):
				by_race[race] = Balance.blank()
			Balance.add(by_race[race], b["by_race"][race])
		print("  seed %-4d %s" % [int(_seeds[i]), Balance.line(b["total"])])
	print("")
	print("Overall:   %s" % Balance.line(all))
	print("           %s" % Balance.detail(all))
	if _profile != "":
		print("           profile %s: %s" % [_profile, Balance.profile_detail(all)])
	print("")
	print("By race of the heir (hybrids appear through marriages):")
	var ids: Array = by_race.keys()
	ids.sort()
	for id in ids:
		print("  %-12s %s" % [id, Balance.line(by_race[id])])
	_report(all, (Time.get_ticks_msec() - started) / 1000.0)


## subclass=all: the baseline (no subclass) and then each of the twenty callings on the same seeds, races and
## generations, one summary line each, with the battle deaths' difference from the baseline in points.
func _sweep(started: int) -> void:
	var ids: Array = [""]
	for s in GameSubclass.defs():
		ids.append(str(s["id"]))
	print("Subclass sweep: %d races x %d seeds x %d generations%s" % [_races.size(), _seeds.size(), _gens, ", the calling on every heir" if _keep else ", the calling passed down at the game's own chance"])
	var base := Balance.blank()
	for id in ids:
		var all := Balance.blank()
		for b in _run_batches(str(id)):
			if not b.is_empty():
				Balance.add(all, b["total"])
		if id == "":
			base = all
		var diff := Balance.share(all) - Balance.share(base)
		var range_ := Balance.wilson(int(all["slain"]), int(all["lives"]))
		print("%-12s %s (%.1f-%.1f%%, %+.1f pts) | level %5.1f | %s" % ["none" if id == "" else id, Balance.line(all).split(", mean level")[0], range_.x, range_.y, diff, float(all["level"]) / maxf(1.0, float(all["lives"])), Balance.detail(all)] + ("" if _profile == "" else " | " + Balance.profile_detail(all)))
	print("")
	print("Sweep took %.0f s." % ((Time.get_ticks_msec() - started) / 1000.0))
	quit(0)


func _report(all: Dictionary, seconds: float) -> void:
	var percent := Balance.share(all)
	var range_ := Balance.wilson(int(all["slain"]), int(all["lives"]))
	var verdict := Balance.verdict(percent, int(all["lives"]))
	print("")
	print("Battle deaths %.1f%% of %d lives (95%% range %.1f-%.1f%%). The band is %.0f-%.0f%%: %s. (%.0f s)" % [percent, int(all["lives"]), range_.x, range_.y, Balance.BAND_LOW, Balance.BAND_HIGH, verdict, seconds])
	if all["lives"] > 0 and (range_.x < Balance.BAND_LOW or range_.y > Balance.BAND_HIGH):
		print("The range reaches past the band's edge, so this run cannot tell near-misses from noise: add seeds.")
	quit(1 if _check and verdict != "IN BAND" else 0)


## Reads the arguments after `--`. False (with the reason printed) when one is not understood.
func _read_args() -> bool:
	for a in OS.get_cmdline_user_args():
		if a == "check":
			_check = true
		elif a.begins_with("seeds="):
			_seeds = Balance.parse_seeds(a.substr(6))
		elif a.begins_with("gens="):
			_gens = maxi(1, int(a.substr(5)))
		elif a.begins_with("jobs="):
			_jobs = maxi(1, int(a.substr(5)))
		elif a == "keep":
			_keep = true
		elif a.begins_with("profile="):
			_profile = a.substr(8) if a.substr(8) != "none" else ""
			if _profile != "" and not GameProfile.has(_profile):
				printerr("Unknown profile '%s'. Use one of: %s or none" % [_profile, ", ".join(GameProfile.IDS)])
				return false
		elif a.begins_with("subclass="):
			_subclass = a.substr(9) if a.substr(9) != "none" else ""
			if not Balance.valid_subclass(_subclass):
				printerr("Unknown subclass '%s'. Use one of: %s, all or none" % [_subclass, ", ".join(GameSubclass.defs().map(func(d): return str(d["id"])))])
				return false
		elif a.begins_with("out="):
			_out = a.substr(4)
		elif a.begins_with("races="):
			var want := Array(a.substr(6).split(",", false))
			for r in want:
				if not GameData.races.has(r):
					printerr("Unknown race '%s'. Starting races: %s" % [r, ", ".join(GameData.starting_ids(GameData.races))])
					return false
			_races = want
		else:
			printerr("Unknown argument '%s'. Arguments: seeds=1-12 gens=10 races=human,elf jobs=4 subclass=<id|all|none> keep profile=<id|none> check" % a)
			return false
	if _seeds.is_empty() or _races.is_empty():
		printerr("Nothing to play: seeds and races must not be empty.")
		return false
	return true


## One result per seed, in order. With more than one job each batch is its own Godot process; they only
## read the project, so they do not disturb each other.
func _run_batches(sub: String) -> Array:
	var results: Array = []
	results.resize(_seeds.size())
	results.fill({})
	var jobs := _jobs if _jobs > 0 else OS.get_processor_count()
	if jobs <= 1 or _seeds.size() == 1:
		for i in _seeds.size():
			results[i] = Balance.play_batch(int(_seeds[i]), _races, _gens, sub, _keep, _profile)
		return results
	var dir := OS.get_temp_dir().path_join("balance_harness_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(dir)
	var project := ProjectSettings.globalize_path("res://")
	var running := {}   # seed index -> process id
	var next := 0
	while next < _seeds.size() or not running.is_empty():
		while next < _seeds.size() and running.size() < jobs:
			var args := ["--headless", "--quiet", "--path", project, "-s", "res://tools/balance_harness.gd", "--",
				"seeds=%d" % int(_seeds[next]), "gens=%d" % _gens, "races=%s" % ",".join(_races.map(func(r): return str(r))),
				"out=%s" % dir.path_join("%d.json" % next)]
			if sub != "":
				args.append("subclass=%s" % sub)
			if _keep:
				args.append("keep")
			if _profile != "":
				args.append("profile=%s" % _profile)
			running[next] = OS.create_process(OS.get_executable_path(), args)
			next += 1
		OS.delay_msec(300)
		for i in running.keys():
			if not OS.is_process_running(int(running[i])):
				running.erase(i)
				results[i] = _load(dir.path_join("%d.json" % i))
	DirAccess.remove_absolute(dir)
	return results


## Worker mode: play the one batch asked for and leave it as JSON for the parent.
func _work() -> void:
	var batch := Balance.play_batch(int(_seeds[0]), _races, _gens, _subclass, _keep, _profile)
	var file := FileAccess.open(_out, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(batch))


func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	DirAccess.remove_absolute(path)
	if not (parsed is Dictionary):
		return {}
	return parsed
