## Captures the determinism baseline: digests of scripted fights and autopilot lives. Run ONCE, on the
## tree BEFORE party command rounds (origin/main 48f615d), and commit the result; test_round_determinism.gd
## recomputes the digests on the current tree and compares. Not rerun against new code.
## godot --headless --path . -s res://tests/capture_round_baseline.gd -- --out <file> [seeds=40]
extends SceneTree

const Scen := preload("res://tests/round_scenarios.gd")


func _init() -> void:
	var out_path := "res://tests/fixtures/round_baseline.json"
	var seeds := 40
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out_path = args[i + 1]
		elif args[i].begins_with("seeds="):
			seeds = int(args[i].get_slice("=", 1))
	var digests := {}
	var logs := {}
	for k in Scen.all_keys(seeds):
		var first: bool = (k.split("|")[1] == "1")
		var r: Dictionary = Scen.run_key(k, first)
		digests[k] = r["digest"]
		if first and r.has("log"):
			logs[k] = r["log"]
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"seeds": seeds, "digests": digests, "logs": logs}, "\t", true))
	f.close()
	print("captured %d scenarios -> %s" % [digests.size(), out_path])
	quit(0)
