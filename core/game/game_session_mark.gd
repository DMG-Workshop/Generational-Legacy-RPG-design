## Whether the game closed properly last time. A small mark file is written when a session begins and removed when it
## ends (the window is closed, or a phone puts the app in the background, from where it may be killed without a word);
## if the mark is still there at the next start, the last session ended without warning: a crash, or a kill while it
## was in front. Nothing else is recorded: no time, no error, nothing about the session. No UI and no dynasty.
class_name GameSessionMark
extends RefCounted

const RUNNING := "running"


## Begins a session. Returns true when the last one did not end properly.
static func begin(path: String) -> bool:
	var unclean := FileAccess.file_exists(path) and FileAccess.get_file_as_string(path).strip_edges() == RUNNING
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(RUNNING)
		f.close()
	return unclean


## Ends a session properly (also when the app goes to the background).
static func end(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func running(path: String) -> bool:
	return FileAccess.file_exists(path)
