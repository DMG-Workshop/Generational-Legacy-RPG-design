## Records and plays replay files (core/game/game_replay.gd).
##   godot --headless --path . -s res://tools/replay.gd -- play FILE      plays a file holding a replay block ("GLRP1:...")
##   godot --headless --path . -s res://tools/replay.gd -- record SEED CLASS RACE COMMANDS [FILE]
##        the autopilot lives from SEED for up to COMMANDS commands; the block is printed, or written to FILE
## `play` exits 1 and says where the run went differently when the replay does not hold on this version of the game.
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	GameData.load_all()
	if args.size() >= 2 and args[0] == "play":
		quit(_play(args[1]))
	elif args.size() >= 5 and args[0] == "record":
		quit(_record(args))
	else:
		print("usage: -- play FILE | record SEED CLASS RACE COMMANDS [FILE]")
		quit(2)


func _play(path: String) -> int:
	var text := FileAccess.get_file_as_string(path)
	var read := GameReplay.from_text(text)
	if not read["ok"]:
		print(read["error"])
		return 1
	var res := GameReplay.play(read["replay"])
	if res["ok"]:
		print("The replay holds: %d commands, generation %d." % [res["played"], res["dynasty"].gen])
		return 0
	print(res["error"])
	return 1


func _record(args: Array) -> int:
	var bloodlines := GameData.traits_in(["bloodline"])
	var rec := GameReplay.begin(int(args[1]), "Tess", args[2], bloodlines[int(args[1]) % bloodlines.size()], args[3])
	rec.bot_on(int(args[4]))
	var text := rec.to_text()
	if args.size() > 5:
		var f := FileAccess.open(args[5], FileAccess.WRITE)
		if f == null:
			print("Cannot write %s" % args[5])
			return 1
		f.store_string(text)
		print("Wrote %d commands, generation %d, to %s" % [rec.commands.size(), rec.dynasty.gen, args[5]])
	else:
		print(text)
	return 0
