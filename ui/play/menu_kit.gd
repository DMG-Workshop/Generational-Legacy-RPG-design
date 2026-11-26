## The data behind the game's menus and toasts (data/ui/menus.json): the toast settings, the main menu's, the pause screen's and the options'
## rows and tabs, and the About lines. Rendering only: nothing here touches the dynasty.
extends RefCounted

const PATH := "res://data/ui/menus.json"

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				_cache = parsed
	return _cache


static func toast(key: String) -> Variant:
	return data()["toast"][key]


## The rows (or tabs) of "main", "pause" or "options", in order: each {id, label, hint?}.
static func rows(kind: String) -> Array:
	return data()[kind]["tabs" if kind == "options" else "rows"]


static func label_of(kind: String, id: String) -> String:
	for r in rows(kind):
		if str(r["id"]) == id:
			return str(r["label"])
	return id


static func hint_of(kind: String, id: String) -> String:
	for r in rows(kind):
		if str(r["id"]) == id:
			return str(r.get("hint", ""))
	return ""


static func validate() -> Array:
	var bad: Array = []
	var d := data()
	for k in ["toast", "main", "pause", "options", "slots_panel", "about", "confirm"]:
		if not d.has(k):
			bad.append("menus.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var t: Dictionary = d["toast"]
	for k in ["max_visible", "seconds", "fade_seconds", "slide_px", "width", "margin", "top", "gap", "history_max", "font_size", "repeat_seconds"]:
		if not t.has(k) or typeof(t[k]) not in [TYPE_INT, TYPE_FLOAT]:
			bad.append("menus.json: toast.%s must be a number" % k)
		elif float(t[k]) < 0.0:
			bad.append("menus.json: toast.%s must not be negative" % k)
	if bad.is_empty():
		if int(t["max_visible"]) < 1 or int(t["max_visible"]) > 5:
			bad.append("menus.json: toast.max_visible must be 1 to 5")
		if float(t["seconds"]) < 1.0 or float(t["width"]) < 160.0 or int(t["history_max"]) < 10 or int(t["font_size"]) < 10:
			bad.append("menus.json: a toast needs seconds >= 1, width >= 160, history_max >= 10 and font_size >= 10")
	for kind in ["main", "pause", "options"]:
		var list: Variant = d[kind].get("tabs" if kind == "options" else "rows")
		if typeof(list) != TYPE_ARRAY or (list as Array).is_empty():
			bad.append("menus.json: %s needs a list of rows" % kind)
			continue
		var seen := {}
		for r in list:
			if typeof(r) != TYPE_DICTIONARY or str(r.get("id", "")) == "" or str(r.get("label", "")) == "":
				bad.append("menus.json: every %s row needs an id and a label" % kind)
				continue
			if seen.has(str(r["id"])):
				bad.append("menus.json: %s row %s is listed twice" % [kind, r["id"]])
			seen[str(r["id"])] = true
			if str(r["label"]).length() > 28:
				bad.append("menus.json: the label of %s row %s is longer than 28 characters" % [kind, r["id"]])
	for id in ["resume", "options", "text", "main", "quit"]:
		if label_of("pause", id) == id:
			bad.append("menus.json: the pause screen needs a %s row" % id)
	for id in ["continue", "new", "options", "quit"]:
		if label_of("main", id) == id:
			bad.append("menus.json: the main menu needs a %s row" % id)
	if typeof(d["confirm"].get("big_gold")) not in [TYPE_INT, TYPE_FLOAT] or float(d["confirm"]["big_gold"]) < 1.0:
		bad.append("menus.json: confirm.big_gold must be a positive amount of gold")
	if typeof(d["about"].get("lines")) != TYPE_ARRAY or (d["about"]["lines"] as Array).is_empty():
		bad.append("menus.json: about.lines must be a list")
	return bad
