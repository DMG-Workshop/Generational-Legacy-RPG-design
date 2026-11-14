## The error file (GameErrorFile): an error the game logs is appended to user://crash_errors.txt the moment it happens, with
## its time, kind and place; a session start is marked; the file is cut to its last half once it passes max_bytes and never
## grows past it; and clear() removes it. Nothing is sent.
## Run: godot --headless --path . -s res://tests/test_game_error_file.gd
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
	GameErrorFile.clear()
	test_writes()
	test_trim()
	test_clear()
	GameErrorFile.max_bytes = 200000
	GameErrorFile.clear()
	print("error file tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func test_writes() -> void:
	GameErrorFile.install()
	ok(GameErrorFile.installed(), "the error file is installed")
	ok(GameErrorFile.text().begins_with("--- session start"), "a session start is marked at install")
	push_error("error file test one")
	var t := GameErrorFile.text()
	ok(t.find("error file test one") >= 0, "an error is written to the file as it happens")
	var error_line := ""
	for l in t.split("\n", false):
		if l.find("error file test one") >= 0:
			error_line = l
	ok(error_line.substr(0, 4).is_valid_int(), "the error line starts with the year, so it has a time")
	ok(error_line.find("ERROR:") >= 0, "the error line says it is an error")


func test_trim() -> void:
	GameErrorFile.clear()
	GameErrorFile.max_bytes = 2000
	for i in 60:
		push_error("trim test %d" % i)
	var size := GameErrorFile.text().length()
	ok(size <= 2000, "the file never grows past max_bytes (%d)" % size)
	var t := GameErrorFile.text()
	ok(t.find("trim test 59 (") >= 0, "the newest error is kept after a cut")
	ok(t.find("trim test 0 (") < 0, "the oldest errors are the ones cut")
	var first := t.split("\n", false)[0]
	ok(first.substr(0, 4).is_valid_int() or first.begins_with("GDScript") or first.begins_with(" ") or first.begins_with("--- "), "the cut starts at a whole line")


func test_clear() -> void:
	GameErrorFile.clear()
	ok(not FileAccess.file_exists(GameErrorFile.PATH), "clear() removes the file")
	ok(GameErrorFile.text() == "", "an empty file reads as nothing")
