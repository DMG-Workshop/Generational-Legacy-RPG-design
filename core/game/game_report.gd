## Error reports that carry a save (roadmap item 54). A report is made only when the player asks, and the game sends it
## nowhere: `to_text` turns it into one block of text ("GLER1:" and base64 of the gzipped JSON) to copy or save as a file.
## It holds the game's version, a few facts about the device (only the keys in data/ui/report.json `env_keys`, whatever
## else the caller offers), the player's note, the last errors logged (GameErrorLog), the last lines of the journal and
## the save itself (`GameDynasty.to_save()`, a fight in progress included), so the house can be opened elsewhere and the
## problem met again. `from_text` reads one back, cleaned and checked like a backup: a block that is not ours, damaged,
## from a newer game, or whose save cannot be played is turned away with a reason and never crashes. Pure: building a
## report draws no dice and changes nothing.
class_name GameReport
extends RefCounted

const PATH := "res://data/ui/report.json"
const PREFIX := "GLER1:"
const FORMAT := 1
const FILE_EXT := "glreport"
const MAX_BYTES := 8 * 1024 * 1024   # what a report may unpack to

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


static func setting(key: String) -> Variant:
	return data()["settings"][key]


static func text(key: String, vals: Dictionary = {}) -> String:
	return str(data()["text"][key]).format(vals)


## What the player is told a report holds, before making one.
static func holds() -> Array:
	return (data()["text"]["holds"] as Array).duplicate()


static func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


# ---------------------------------------------------------------- making one

## The facts about the device a report keeps: only the listed keys, each as a short line of text.
static func clean_env(env: Variant) -> Dictionary:
	var out := {}
	if typeof(env) != TYPE_DICTIONARY:
		return out
	for k in data()["env_keys"]:
		if (env as Dictionary).has(k) and typeof(env[k]) in [TYPE_STRING, TYPE_INT, TYPE_FLOAT, TYPE_BOOL]:
			var v: Variant = env[k]
			if typeof(v) == TYPE_FLOAT and is_finite(v) and v == floorf(v):
				v = int(v)   # a whole number that came through JSON reads as it was written
			out[str(k)] = _line(str(v), int(setting("max_env_chars")))
	return out


static func _line(s: String, limit: int) -> String:
	return s.replace("\r", " ").replace("\n", " ").substr(0, limit)


static func _lines(list: Variant, keep: int, limit: int) -> Array:
	var out: Array = []
	if typeof(list) != TYPE_ARRAY:
		return out
	for v in list:
		if typeof(v) == TYPE_STRING:
			out.append((v as String).substr(0, limit))
	return out.slice(maxi(0, out.size() - keep))


## A report on a dynasty (or on none, when the game could not even load one): {format, game, save_version, env, note,
## errors, journal, save}. `errors` are lines of text, the newest last; only the last few are kept.
static func build(d: GameDynasty, env: Dictionary = {}, errors: Array = [], note: String = "") -> Dictionary:
	var report := {
		"format": FORMAT, "game": game_version(), "save_version": GameSaveVersion.CURRENT,
		"env": clean_env(env), "note": note.substr(0, int(setting("max_note_chars"))),
		"errors": _lines(errors, int(setting("max_errors")), int(setting("max_error_chars"))),
		"journal": [], "save": null,
	}
	if d != null:
		report["journal"] = _lines(d.journal, int(setting("journal_lines")), int(setting("max_error_chars")))
		report["save"] = d.to_save()
	return report


static func to_text(report: Dictionary) -> String:
	return PREFIX + Marshalls.raw_to_base64(JSON.stringify(report).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))


# ---------------------------------------------------------------- reading one

## Reads a report block: {ok, error, report}. Spaces and line breaks are ignored. The report comes back cleaned (known
## keys, the right types, the same limits as `build`); its save is checked to be one this game can play, and
## `report.save` is null when it held none.
static func from_text(block: String) -> Dictionary:
	var fail := {"ok": false, "error": "", "report": {}}
	var t := block
	for ws in [" ", "\n", "\r", "\t"]:
		t = t.replace(ws, "")
	if not t.begins_with(PREFIX):
		fail["error"] = text("not_a_report")
		return fail
	var body := t.substr(PREFIX.length())
	var shape := RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")   # checked first so the engine never logs a decode error
	var packed := PackedByteArray()
	if body.length() % 4 == 0 and shape.search(body) != null:
		packed = Marshalls.base64_to_raw(body)
	if packed.is_empty():
		fail["error"] = text("damaged")
		return fail
	var raw := packed.decompress_dynamic(MAX_BYTES, FileAccess.COMPRESSION_GZIP)
	if raw.is_empty():
		fail["error"] = text("incomplete")
		return fail
	var json := JSON.new()
	if json.parse(raw.get_string_from_utf8()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		fail["error"] = text("damaged")
		return fail
	var src: Dictionary = json.data
	if typeof(src.get("format")) not in [TYPE_INT, TYPE_FLOAT] or int(src["format"]) < 1:
		fail["error"] = text("damaged")
		return fail
	if int(src["format"]) > FORMAT:
		fail["error"] = text("too_new")
		return fail
	var report := {
		"format": int(src["format"]),
		"game": _line(str(src.get("game", "")), 40) if typeof(src.get("game")) == TYPE_STRING else "",
		"save_version": int(src["save_version"]) if typeof(src.get("save_version")) in [TYPE_INT, TYPE_FLOAT] else 0,
		"env": clean_env(src.get("env", {})),
		"note": str(src["note"]).substr(0, int(setting("max_note_chars"))) if typeof(src.get("note")) == TYPE_STRING else "",
		"errors": _lines(src.get("errors", []), int(setting("max_errors")), int(setting("max_error_chars"))),
		"journal": _lines(src.get("journal", []), int(setting("journal_lines")), int(setting("max_error_chars"))),
		"save": null,
	}
	var save: Variant = src.get("save", null)
	if save != null:
		var why := save_problem(save)
		if why != "":
			fail["error"] = text("bad_save", {"why": why})
			return fail
		report["save"] = save
	return {"ok": true, "error": "", "report": report}


## Why a report's save cannot be played, or "".
static func save_problem(save: Variant) -> String:
	if not GameSaves.shape_ok(save):
		return GameMessages.text("life", "no_house")
	var copy: Dictionary = (save as Dictionary).duplicate(true)
	var too_new := GameSaveVersion.upgrade(copy)
	if too_new != "":
		return too_new
	if GameDynasty.from_dict(copy) == null:
		return GameMessages.text("life", "no_playable_house")
	return ""


## The report's house, loaded as the game would load it (a fight in progress included), or null when it holds none.
static func dynasty(report: Dictionary) -> GameDynasty:
	var save: Variant = report.get("save", null)
	if save == null or save_problem(save) != "":
		return null
	var copy: Dictionary = (save as Dictionary).duplicate(true)
	GameSaveVersion.upgrade(copy)
	return GameDynasty.from_dict(copy)


## The report's save as a house backup block (GameSaves' "GLBK1:"), to load through the game's own Load from text or
## file; "" when it holds none.
static func backup_text(report: Dictionary) -> String:
	if report.get("save", null) == null:
		return ""
	return GameSaves.BACKUP_PREFIX + Marshalls.raw_to_base64(JSON.stringify(report["save"]).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))


## One line about a report, for whoever opens it.
static func summary(report: Dictionary) -> String:
	var save: Variant = report.get("save", null)
	var house := GameMessages.text("life", "no_save")
	var gen := 0
	if typeof(save) == TYPE_DICTIONARY:
		house = GameMessages.text("life", "house_name", {"house": str(save.get("dynasty_name", "?"))})
		gen = int(save.get("gen", 0))
	return text("summary", {"game": str(report.get("game", "?")), "save_version": int(report.get("save_version", 0)), "house": house, "gen": gen,
		"errors": (report.get("errors", []) as Array).size()})


# ---------------------------------------------------------------- the data

static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = data()
	for k in ["settings", "env_keys", "text"]:
		if not dat.has(k):
			bad.append("report.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	for k in ["max_errors", "max_error_chars", "max_note_chars", "journal_lines", "max_env_chars"]:
		if not dat["settings"].has(k) or int(dat["settings"][k]) < 1:
			bad.append("report.json: settings.%s must be at least 1" % k)
	if typeof(dat["env_keys"]) != TYPE_ARRAY or (dat["env_keys"] as Array).is_empty():
		bad.append("report.json: env_keys must list what a report may keep about the device")
	for k in ["holds", "never_sent", "not_a_report", "damaged", "incomplete", "too_new", "no_save", "bad_save", "summary"]:
		if not dat["text"].has(k):
			bad.append("report.json: text.%s is missing" % k)
	if dat["text"].has("holds") and (typeof(dat["text"]["holds"]) != TYPE_ARRAY or (dat["text"]["holds"] as Array).size() < 4):
		bad.append("report.json: text.holds must say what a report holds, line by line")
	return bad
