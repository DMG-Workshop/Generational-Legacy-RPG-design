## The few facts about the device that go into an error report (GameReport keeps only the keys it lists, whatever is
## offered here): the system, the model, the window, the text size and layout in use, the renderer and the time.
## Rendering side only: it asks the engine, never the dynasty.
extends RefCounted

const UiSettings := preload("res://ui/play/ui_settings.gd")


static func facts(win: Window = null) -> Dictionary:
	var out := {
		"os": OS.get_name(),
		"os_version": OS.get_version(),
		"model": OS.get_model_name(),
		"text_size": "%d%%" % int(round(UiSettings.get_scale() * 100.0)),
		"layout": "touch" if UiSettings.touch() else "desktop",
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		"time": Time.get_datetime_string_from_system(true),
	}
	if win != null:
		out["screen"] = "%dx%d" % [win.size.x, win.size.y]
	return out
