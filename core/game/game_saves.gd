## Save slots and backups, with no UI. Each slot is its own file. Slot 1 is the original single save
## file, so nobody's save moves when slots arrive. GameDynasty.save_path stays "the file in use": the
## app points it at the slot the player chose, and saving and loading go through it as before.
##
## Saving writes a new file beside the old one and swaps it in, keeping the one before as ".bak", so a
## phone killed in the middle of a save cannot leave a dynasty half written; loading falls back to the
## ".bak" when the main file is missing or unreadable. A backup is a house's save as one block of text
## ("GLBK1:" and a compressed, base64 copy of it) that can be kept in a note and restored into any slot.
class_name GameSaves
extends RefCounted

const BACKUP_PREFIX := "GLBK1:"
const FILE_EXT := "glsave"                      # a save file is the backup block in a text file with this ending
const MAX_FILE_BYTES := 16 * 1024 * 1024        # the biggest save file read: the backup block is base64 of a gzip
const MAX_BACKUP_BYTES := 8 * 1024 * 1024   # what a backup may unpack to; real saves are about 20 KB

## What a saved dynasty must hold, and of what kind, before from_dict may read it: it indexes these
## directly, so a damaged or hand-made file must be turned away first. (The heir's own keys are checked too.)
const REQUIRED := {
	"seed": [TYPE_FLOAT, TYPE_INT], "rng_state": [TYPE_STRING], "dynasty_name": [TYPE_STRING],
	"gen": [TYPE_FLOAT, TYPE_INT], "heir": [TYPE_DICTIONARY], "state": [TYPE_STRING], "history": [TYPE_ARRAY],
	"echoes": [TYPE_ARRAY], "heirlooms": [TYPE_ARRAY], "slain_bosses": [TYPE_DICTIONARY],
	"pending_archetype": [TYPE_STRING], "candidates": [TYPE_ARRAY], "last_death": [TYPE_DICTIONARY],
	"journal": [TYPE_ARRAY], "next_id": [TYPE_FLOAT, TYPE_INT], "total_hunts": [TYPE_FLOAT, TYPE_INT],
}
const REQUIRED_HEIR := ["name", "surname", "class_id", "race_id", "level", "age"]

## Slot 1's file. The app sets it from GameDynasty.save_path when it starts, so a test that points the
## save somewhere else keeps every slot there too.
static var base: String = "user://dynasty_save.json"


static func slots() -> int:
	return maxi(1, int(GameData.bal("save_slots")))


## The file of a slot (1 to slots()): slot 1 is `base`, the others `base` with _2, _3 before the extension.
static func path_for(slot: int) -> String:
	if slot <= 1:
		return base
	return "%s_%d.%s" % [base.get_basename(), slot, base.get_extension()]


# ---------------------------------------------------------------- writing and reading a file

## Writes `text` to `path` without ever leaving it half written: a new file beside it is swapped in,
## and the file it replaces is kept as path + ".bak".
static func write_atomic(path: String, text: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.rename_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(tmp, path) == OK


## The dynasty in a file, or null when it is missing, not JSON, or not shaped like a save.
static func load_file(path: String) -> GameDynasty:
	var parsed: Variant = read_json(path)
	if not shape_ok(parsed) or GameSaveVersion.upgrade(parsed) != "":
		return null
	return GameDynasty.from_dict(parsed)


## The JSON in a file as a Variant, or null.
static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return parse(FileAccess.get_file_as_string(path))


## JSON text as a Variant, or null when it is not JSON (quietly: a damaged file is expected here, not an error).
static func parse(text: String) -> Variant:
	var j := JSON.new()
	if j.parse(text) != OK:
		return null
	return j.data


## A save this game can load: shaped like one, and not from a newer game.
static func _loadable(d: Variant) -> bool:
	return shape_ok(d) and GameSaveVersion.readable(d)


## True when `d` is a dictionary with the keys a saved dynasty has, of the right kinds.
static func shape_ok(d: Variant) -> bool:
	if typeof(d) != TYPE_DICTIONARY:
		return false
	for key in REQUIRED:
		if not d.has(key) or not (REQUIRED[key] as Array).has(typeof(d[key])):
			return false
	for key in REQUIRED_HEIR:
		if not (d["heir"] as Dictionary).has(key):
			return false
	return true


# ---------------------------------------------------------------- slots

## What a slot holds, for the list the player picks from: {slot, exists, valid, house, heir, class,
## race, level, age, gen, saved (unix time), restorable, ironman}. `valid` is false for a file that cannot be
## read (it is left alone); `restorable` says the ".bak" beside it can be.
static func peek(slot: int) -> Dictionary:
	var path := path_for(slot)
	var out := {"slot": slot, "exists": false, "valid": false, "house": "", "heir": "", "class": "", "race": "",
		"level": 0, "age": 0, "gen": 0, "saved": 0, "restorable": false, "ironman": false}
	var has_main := FileAccess.file_exists(path)
	var has_bak := FileAccess.file_exists(path + ".bak")
	if not has_main and not has_bak:
		return out
	out["exists"] = true
	var parsed: Variant = read_json(path)
	if not _loadable(parsed):
		parsed = read_json(path + ".bak")   # a damaged main file with a good ".bak": the slot is still playable
		out["restorable"] = _loadable(parsed)
		if not _loadable(parsed):
			return out
	out["valid"] = true
	var h: Dictionary = parsed["heir"]
	out["house"] = str(parsed["dynasty_name"])
	out["heir"] = "%s %s" % [h["name"], h["surname"]]
	out["class"] = str(GameData.classes.get(str(h["class_id"]), {}).get("name", h["class_id"]))
	out["race"] = str(GameData.races.get(str(h["race_id"]), {}).get("name", h["race_id"]))
	out["level"] = int(h["level"])
	out["age"] = int(h["age"])
	out["gen"] = int(parsed["gen"])
	out["ironman"] = GameHardMode.saved_ironman(parsed)
	out["saved"] = FileAccess.get_modified_time(path if has_main else path + ".bak")
	return out


## The slot saved most recently that can be read, or 0.
static func newest() -> int:
	var best := 0
	var best_time := -1
	for s in range(1, slots() + 1):
		var p := peek(s)
		if p["valid"] and int(p["saved"]) > best_time:
			best = s
			best_time = int(p["saved"])
	return best


## The first slot with nothing in it, or 0 when every slot holds a file.
static func first_empty() -> int:
	for s in range(1, slots() + 1):
		if not peek(s)["exists"]:
			return s
	return 0


## Erases a slot: its file, its ".bak" and any half-written leftover.
static func delete(slot: int) -> void:
	var path := path_for(slot)
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


# ---------------------------------------------------------------- iron-man houses (see GameHardMode)

## True when a slot's file, or the ".bak" beside it, holds an iron-man house.
static func ironman(slot: int) -> bool:
	var path := path_for(slot)
	return GameHardMode.saved_ironman(read_json(path)) or GameHardMode.saved_ironman(read_json(path + ".bak"))


## Why a slot's house cannot be copied or exported as a backup, or "".
static func why_no_export(slot: int) -> String:
	return GameHardMode.text("no_export") if ironman(slot) else ""


## Why nothing can be restored or imported over a slot's house, or "".
static func why_no_restore(slot: int) -> String:
	return GameHardMode.text("no_import_over") if ironman(slot) else ""


## Writes a read backup (import_text's `json`) into a slot. Returns "" or why it was not written.
static func restore_into(slot: int, json: String) -> String:
	var why := why_no_restore(slot)
	if why != "":
		return why
	return "" if write_atomic(path_for(slot), json) else GameMessages.text("life", "backup_not_written")


# ---------------------------------------------------------------- backups as text

## A slot's save as one block of text to keep elsewhere, or "" when the slot holds nothing readable.
static func export_text(slot: int) -> String:
	if ironman(slot):   # an iron-man house has no backups
		return ""
	var path := path_for(slot)
	var text := FileAccess.get_file_as_string(path) if shape_ok(read_json(path)) else FileAccess.get_file_as_string(path + ".bak")
	if not shape_ok(parse(text)):
		return ""
	return BACKUP_PREFIX + Marshalls.raw_to_base64(text.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))


## A name for a slot's save file, from its house and generation: "house-ashford-gen12.glsave" ("save.glsave" when the
## slot holds nothing readable). Letters and digits only, so it is a safe name on every system.
static func file_name(slot: int) -> String:
	var info := peek(slot)
	if not info["valid"]:
		return "save." + FILE_EXT
	var clean := RegEx.create_from_string("[^a-z0-9]+").sub(str(info["house"]).to_lower(), "-", true).trim_prefix("-").trim_suffix("-")
	return "house-%s-gen%d.%s" % [clean if clean != "" else "unnamed", int(info["gen"]), FILE_EXT]


## Writes a slot's backup block to `path` as a text file. Returns {ok, error}.
static func export_file(slot: int, path: String) -> Dictionary:
	var text := export_text(slot)
	if text.is_empty():
		var why := why_no_export(slot)
		return {"ok": false, "error": why if why != "" else "Nothing in this slot can be saved to a file."}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": GameMessages.text("life", "file_not_written", {"path": path})}
	f.store_string(text)
	f.close()
	return {"ok": true, "error": ""}


## Reads a save file, with the same checks and the same result as import_text, plus a reason when the file cannot
## be opened or is too big to be a save.
static func import_file(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {"ok": false, "error": GameMessages.text("life", "file_not_there"), "json": "", "house": "", "gen": 0}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": GameMessages.text("life", "file_not_opened"), "json": "", "house": "", "gen": 0}
	if f.get_length() > MAX_FILE_BYTES:
		return {"ok": false, "error": GameMessages.text("life", "file_too_big"), "json": "", "house": "", "gen": 0}
	return import_text(f.get_as_text())


## Reads a backup block. Returns {ok, error, json, house, gen}: `json` is the save to write into a slot.
## Spaces and line breaks are ignored (a block pasted through a message may be wrapped). A block that is
## not ours, damaged, or that does not make a playable dynasty is turned away with a reason, never loaded.
static func import_text(text: String) -> Dictionary:
	var fail := {"ok": false, "error": "", "json": "", "house": "", "gen": 0}
	var t := text
	for ws in [" ", "\n", "\r", "\t"]:
		t = t.replace(ws, "")
	if not t.begins_with(BACKUP_PREFIX):
		fail["error"] = "That is not a house backup."
		return fail
	var body := t.substr(BACKUP_PREFIX.length())
	var shape := RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")   # checked first so the engine never logs a decode error
	var packed := PackedByteArray()
	if body.length() % 4 == 0 and shape.search(body) != null:
		packed = Marshalls.base64_to_raw(body)
	if packed.is_empty():
		fail["error"] = "The backup is damaged: it could not be read."
		return fail
	var raw := packed.decompress_dynamic(MAX_BACKUP_BYTES, FileAccess.COMPRESSION_GZIP)
	if raw.is_empty():
		fail["error"] = "The backup is damaged or incomplete (some of it is missing)."
		return fail
	var json := raw.get_string_from_utf8()
	var parsed: Variant = parse(json)
	if not shape_ok(parsed):
		fail["error"] = "The backup does not hold a house."
		return fail
	if GameHardMode.saved_ironman(parsed):   # however the block was made, an iron-man house is not restored
		fail["error"] = GameHardMode.text("no_import")
		return fail
	var too_new := GameSaveVersion.upgrade((parsed as Dictionary).duplicate())
	if too_new != "":
		fail["error"] = too_new
		return fail
	GameSaveVersion.upgrade(parsed)
	var d := GameDynasty.from_dict(parsed)
	if d == null:
		fail["error"] = "The backup does not hold a playable house."
		return fail
	return {"ok": true, "error": "", "json": json, "house": str(parsed["dynasty_name"]), "gen": int(parsed["gen"])}
