## Opens an error report (core/game/game_report.gd).
##   godot --headless --path . -s res://tools/report.gd -- read FILE [OUT.glsave]
##        says what the report holds, checks its save can be played, and (with OUT) writes that save as a house
##        backup file to load through the game's own "Load from file".
##   godot --headless --path . -s res://tools/report.gd -- make SEED COMMANDS [FILE]
##        the autopilot lives from SEED for COMMANDS commands and a report on that house is printed, or written to FILE.
## `read` exits 1, saying why, when the file is not a report this game can read.
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	GameData.load_all()
	if args.size() >= 2 and args[0] == "read":
		quit(_read(args))
	elif args.size() >= 3 and args[0] == "make":
		quit(_make(args))
	else:
		print("usage: -- read FILE [OUT.glsave] | make SEED COMMANDS [FILE]")
		quit(2)


func _read(args: Array) -> int:
	if not FileAccess.file_exists(args[1]):
		print("There is no file %s" % args[1])
		return 1
	var read := GameReport.from_text(FileAccess.get_file_as_string(args[1]))
	if not read["ok"]:
		print(read["error"])
		return 1
	var report: Dictionary = read["report"]
	print(GameReport.summary(report))
	for k in report["env"]:
		print("  %s: %s" % [k, report["env"][k]])
	if report["note"] != "":
		print("Note: %s" % report["note"])
	for e in report["errors"]:
		print("  ! %s" % e)
	var d := GameReport.dynasty(report)
	if d == null:
		print(GameReport.text("no_save"))
		return 0
	print("The save loads: %s %s, %s, age %d, level %d%s." % [d.heir.name, d.heir.surname, d.world.date_text(), int(d.heir.age), d.heir.level, ", in a fight" if d.battle != null else ""])
	if args.size() > 2:
		var f := FileAccess.open(args[2], FileAccess.WRITE)
		if f == null:
			print("Cannot write %s" % args[2])
			return 1
		f.store_string(GameReport.backup_text(report))
		f.close()
		print("Its save is written to %s" % args[2])
	return 0


func _make(args: Array) -> int:
	var bloodlines := GameData.traits_in(["bloodline"])
	var seed_value := int(args[1])
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", bloodlines[seed_value % bloodlines.size()], "human")
	for i in int(args[2]):
		if d.state == "ended":
			break
		GameBot.step(d)
	var text := GameReport.to_text(GameReport.build(d, {"os": OS.get_name(), "model": "tools/report.gd"}, [], "Made by tools/report.gd from seed %d." % seed_value))
	if args.size() > 3:
		var f := FileAccess.open(args[3], FileAccess.WRITE)
		if f == null:
			print("Cannot write %s" % args[3])
			return 1
		f.store_string(text)
		f.close()
		print("Written to %s (%d characters)." % [args[3], text.length()])
	else:
		print(text)
	return 0
