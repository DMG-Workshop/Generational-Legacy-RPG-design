## Choosing a save file to write or read. Where the platform has its own file dialog (Windows, macOS, Linux, and
## Android where the engine offers it) that is used. Where it has none, the file goes to, and is read from, one
## known folder: the Downloads folder if there is one, else the game's own `exports` folder, and the screen says
## which. Tests switch on `fake` so no dialog opens and no real folder is touched. Rendering only.
extends RefCounted

const EXT := "glsave"
const FILTER := "*.glsave ; Generational Legacy save"

static var fake := false
static var fake_path := ""          # what the fake "dialog" answers; "" is the same as cancelling
static var fake_dir := ""           # the folder the fallback uses under test


## The folder used when there is no dialog.
static func fallback_dir() -> String:
	if fake_dir != "":
		return fake_dir
	var dl := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if dl != "" and DirAccess.dir_exists_absolute(dl):
		return dl
	DirAccess.make_dir_recursive_absolute("user://exports")
	return "user://exports"


static func native() -> bool:
	return not fake and DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)


## Asks where to write `file_name`. `done` is called with the chosen path, or "" when cancelled.
static func save(title: String, file_name: String, done: Callable) -> void:
	if fake:
		done.call(fake_path)
	elif native():
		DisplayServer.file_dialog_show(title, fallback_dir(), file_name, false, DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, PackedStringArray([FILTER]),
			func(status: bool, paths: PackedStringArray, _filter: int): done.call(paths[0] if status and paths.size() > 0 else ""))
	else:
		done.call(fallback_dir().path_join(file_name))


## Asks which save file to read. `done` is called with the chosen path, or "" when cancelled or when there is
## nothing to read (without a dialog, the newest save file in the fallback folder).
static func open(title: String, done: Callable) -> void:
	if fake:
		done.call(fake_path)
	elif native():
		DisplayServer.file_dialog_show(title, fallback_dir(), "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, PackedStringArray([FILTER]),
			func(status: bool, paths: PackedStringArray, _filter: int): done.call(paths[0] if status and paths.size() > 0 else ""))
	else:
		done.call(newest(fallback_dir()))


## The most recently changed save file in `dir`, or "".
static func newest(dir: String) -> String:
	var best := ""
	var best_time := -1
	for f in DirAccess.get_files_at(dir):
		if f.get_extension().to_lower() != EXT:
			continue
		var t := FileAccess.get_modified_time(dir.path_join(f))
		if t > best_time:
			best_time = t
			best = dir.path_join(f)
	return best
