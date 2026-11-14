## Writes the game's errors to a file as they happen (user://crash_errors.txt), so a crash that follows an error can be read
## afterwards, on a device where the system log cannot be reached. Unlike GameErrorLog (memory only, on when the player
## turns error reports on), this is installed at every start and always on. Each error is appended the moment it is
## logged, one line with its time, kind, what went wrong and where (GameErrorLog.line_for), plus any script backtrace.
## The file is cut to its last half once it grows past `max_bytes`. Nothing is sent. Errors come from any thread, so the
## writes are guarded. Native crashes (the graphics driver, the engine itself) are not script errors and do not appear.
class_name GameErrorFile
extends Logger

const PATH := "user://crash_errors.txt"

static var _installed: GameErrorFile = null
static var _mutex := Mutex.new()
static var max_bytes := 200000


## Starts writing errors to the file (once). Writes a line marking the start of this session.
static func install() -> void:
	if _installed == null:
		_installed = GameErrorFile.new()
		OS.add_logger(_installed)
		_append("--- session start %s" % Time.get_datetime_string_from_system())


static func installed() -> bool:
	return _installed != null


## The whole file as text ("" when there is none).
static func text() -> String:
	if not FileAccess.file_exists(PATH):
		return ""
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return s


## Deletes the file (tests, and a player who wants it gone).
static func clear() -> void:
	_mutex.lock()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	_mutex.unlock()


static func _append(line: String) -> void:
	_mutex.lock()
	var f: FileAccess = null
	if FileAccess.file_exists(PATH):
		f = FileAccess.open(PATH, FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
	else:
		f = FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(line + "\n")
		var size := f.get_length()
		f.close()
		if size > max_bytes:
			_trim()
	_mutex.unlock()


## Keeps the newest whole lines that fit in half of max_bytes, oldest dropped first. Called with the lock held.
static func _trim() -> void:
	var lines := text().split("\n", false)
	var kept: Array = []
	var used := 0
	for i in range(lines.size() - 1, -1, -1):
		used += lines[i].length() + 1
		if used > max_bytes / 2:
			break
		kept.push_front(lines[i])
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(kept) + "\n" if not kept.is_empty() else "")
		f.close()


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array) -> void:
	var text_line := GameErrorLog.line_for(error_type, code, rationale, function, file, line)
	for bt in script_backtraces:
		if bt != null and bt.has_method("format") and not bt.is_empty():
			text_line += "\n" + str(bt.format())
	_append("%s %s" % [Time.get_datetime_string_from_system(), text_line])


func _log_message(_message: String, _error: bool) -> void:
	pass   # printed lines are not errors: nothing to keep
