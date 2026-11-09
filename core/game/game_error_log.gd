## The last errors the game logged, kept in memory for an error report (GameReport). `install` hooks Godot's logger so
## that every error, warning and script error (with where it happened) is remembered as one line of text, the newest
## last, and only the last `keep` of them. Nothing is written to disk and nothing is sent. The game installs it only
## when the player has turned error reports on; tests install and remove it themselves. Errors can be logged from any
## thread, so the list is guarded.
class_name GameErrorLog
extends Logger

const KINDS := ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"]

static var _installed: GameErrorLog = null
static var _lines: Array = []
static var _mutex := Mutex.new()
static var _keep := 50


## Starts remembering errors (once: a second call changes nothing but `keep`).
static func install(keep: int = 50) -> void:
	_keep = maxi(1, keep)
	if _installed == null:
		_installed = GameErrorLog.new()
		OS.add_logger(_installed)


## Stops remembering, and forgets.
static func remove() -> void:
	if _installed != null:
		OS.remove_logger(_installed)
		_installed = null
	clear()


static func installed() -> bool:
	return _installed != null


## The errors remembered, the newest last.
static func recent() -> Array:
	_mutex.lock()
	var out := _lines.duplicate()
	_mutex.unlock()
	return out


static func clear() -> void:
	_mutex.lock()
	_lines.clear()
	_mutex.unlock()


## One error as a line: its kind, what went wrong, and where.
static func line_for(kind: int, code: String, rationale: String, function: String, file: String, line: int) -> String:
	var what := rationale if rationale != "" else code
	var label: String = KINDS[kind] if kind >= 0 and kind < KINDS.size() else "ERROR"
	return "%s: %s (%s, %s:%d)" % [label, what, function, file, line]


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array) -> void:
	var text := line_for(error_type, code, rationale, function, file, line)
	for bt in script_backtraces:
		if bt != null and bt.has_method("format") and not bt.is_empty():
			text += "\n" + str(bt.format())
	_mutex.lock()
	_lines.append(text)
	if _lines.size() > _keep:
		_lines = _lines.slice(_lines.size() - _keep)
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass   # printed lines are not errors: nothing to remember
