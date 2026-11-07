## Save slots and backups, below the screens: the slot files, atomic saving with its ".bak", loading that
## falls back to the ".bak", the slot summary, and backup text going out and coming back in (including
## every way a pasted backup can be wrong).
## Run: godot --headless --path . -s res://tests/test_game_saves.gd
extends SceneTree

const DIR := "user://test_saves/"

var checks := 0
var fails := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	GameData.load_all()
	DirAccess.make_dir_recursive_absolute(DIR)
	GameSaves.base = DIR + "save.json"
	GameDynasty.save_path = GameSaves.base
	_wipe()
	test_paths()
	test_atomic_write()
	test_save_and_load()
	test_bak_fallback()
	test_peek()
	test_newest_and_empty()
	test_backup_round_trip()
	test_bad_backups()
	test_old_save_loads()
	_wipe()
	print("saves tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _wipe() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)


func _dynasty(seed_value: int = 5, gens: int = 0) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "", "warrior", "faetouched", "human")
	for i in gens:
		GameBot.live_life(d)
		if d.state != "succession":
			break
		GameBot.choose_best(d)
	return d


func test_paths() -> void:
	ok(GameSaves.slots() == 3, "three slots by default")
	ok(GameSaves.path_for(1) == DIR + "save.json", "slot 1 is the original file")
	ok(GameSaves.path_for(2) == DIR + "save_2.json" and GameSaves.path_for(3) == DIR + "save_3.json", "the others number the file")
	ok(GameSaves.path_for(0) == GameSaves.path_for(1), "a slot below 1 is slot 1")


func test_atomic_write() -> void:
	var p := DIR + "a.json"
	ok(GameSaves.write_atomic(p, "one"), "writes a new file")
	ok(FileAccess.get_file_as_string(p) == "one" and not FileAccess.file_exists(p + ".tmp"), "with nothing left over")
	ok(not FileAccess.file_exists(p + ".bak"), "and no .bak the first time")
	GameSaves.write_atomic(p, "two")
	ok(FileAccess.get_file_as_string(p) == "two" and FileAccess.get_file_as_string(p + ".bak") == "one", "the next write keeps the one before as .bak")
	ok(not GameSaves.write_atomic("user://no_such_dir_xyz/a.json", "x"), "an unwritable place reports failure")


func test_save_and_load() -> void:
	var d := _dynasty(5, 2)
	ok(d.save_to_disk(), "saves")
	var back := GameDynasty.load_from_disk()
	ok(back != null and JSON.stringify(back.to_dict()) == JSON.stringify(d.to_dict()), "and loads back identical")
	d.start_hunt("hunt")
	ok(d.battle != null and d.save_to_disk(), "a fight is saved with the dynasty")
	var mid := GameDynasty.load_from_disk()
	ok(mid != null and mid.battle != null and mid.battle.turn == d.battle.turn, "and loads back still going (see test_game_battle_saves)")
	ok(GameDynasty.has_save(), "has_save sees the file")


func test_bak_fallback() -> void:
	_wipe()
	var d := _dynasty(6, 1)
	d.save_to_disk()
	var first := JSON.stringify(d.to_save())
	d.heir.gold += 1
	d.save_to_disk()
	ok(FileAccess.get_file_as_string(GameSaves.base + ".bak") == first, "the second save keeps the first as .bak")
	var f := FileAccess.open(GameSaves.base, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	var back := GameDynasty.load_from_disk()
	ok(back != null and JSON.stringify(back.to_save()) == first, "a damaged save loads from the .bak")
	DirAccess.remove_absolute(GameSaves.base)
	ok(GameDynasty.has_save() and GameDynasty.load_from_disk() != null, "a missing save with a .bak is still a save")
	_wipe()
	ok(not GameDynasty.has_save() and GameDynasty.load_from_disk() == null, "nothing at all: no save, null")
	f = FileAccess.open(GameSaves.base, FileAccess.WRITE)
	f.store_string("[1, 2]")
	f.close()
	ok(GameDynasty.load_from_disk() == null, "valid JSON that is not a save loads as null, not a crash")
	f = FileAccess.open(GameSaves.base, FileAccess.WRITE)
	f.store_string('{"gen": 1}')
	f.close()
	ok(GameDynasty.load_from_disk() == null, "a save missing its parts loads as null")


func test_peek() -> void:
	_wipe()
	var e := GameSaves.peek(2)
	ok(not e["exists"] and not e["valid"], "an empty slot")
	var d := _dynasty(7, 1)
	GameDynasty.save_path = GameSaves.path_for(2)
	d.save_to_disk()
	GameDynasty.save_path = GameSaves.base
	var p := GameSaves.peek(2)
	ok(p["exists"] and p["valid"] and p["gen"] == d.gen and p["house"] == d.dynasty_name, "a full slot names its house and generation")
	ok(p["heir"] == "%s %s" % [d.heir.name, d.heir.surname] and p["level"] == d.heir.level, "and its heir")
	ok(int(p["saved"]) > 0, "and when it was saved")
	ok(not GameSaves.peek(1)["exists"], "other slots are untouched")
	var f := FileAccess.open(GameSaves.path_for(3), FileAccess.WRITE)
	f.store_string("garbage")
	f.close()
	var g := GameSaves.peek(3)
	ok(g["exists"] and not g["valid"] and not g["restorable"], "a damaged slot exists but is not valid")
	GameSaves.delete(3)
	ok(not GameSaves.peek(3)["exists"], "delete empties it")
	GameSaves.write_atomic(GameSaves.path_for(3), JSON.stringify(d.to_dict()))
	GameSaves.write_atomic(GameSaves.path_for(3), "garbage")
	var r := GameSaves.peek(3)
	ok(r["valid"] and r["restorable"], "a damaged slot with a good .bak is playable")
	GameSaves.delete(3)
	ok(not FileAccess.file_exists(GameSaves.path_for(3) + ".bak"), "and delete removes the .bak too")


func test_newest_and_empty() -> void:
	_wipe()
	ok(GameSaves.newest() == 0 and GameSaves.first_empty() == 1, "nothing saved: no newest, slot 1 free")
	var d := _dynasty()
	GameSaves.write_atomic(GameSaves.path_for(1), JSON.stringify(d.to_dict()))
	ok(GameSaves.newest() == 1 and GameSaves.first_empty() == 2, "one slot used")
	for s in [2, 3]:
		GameSaves.write_atomic(GameSaves.path_for(s), JSON.stringify(d.to_dict()))
	ok(GameSaves.first_empty() == 0, "all full: none free")


func test_backup_round_trip() -> void:
	_wipe()
	var d := _dynasty(9, 4)
	d.save_to_disk()
	var text := GameSaves.export_text(1)
	ok(text.begins_with(GameSaves.BACKUP_PREFIX) and text.length() < 20000, "a backup is one short block of text (%d characters)" % text.length())
	ok(GameSaves.export_text(2) == "", "an empty slot has nothing to export")
	var r := GameSaves.import_text(text)
	ok(r["ok"] and r["house"] == d.dynasty_name and r["gen"] == d.gen, "it reads back with the house and generation")
	GameSaves.write_atomic(GameSaves.path_for(2), r["json"])
	var back := GameSaves.load_file(GameSaves.path_for(2))
	ok(back != null and JSON.stringify(back.to_dict()) == JSON.stringify(d.to_dict()), "restored into another slot, the dynasty is identical")
	# The same seed and commands play on the same after the restore.
	var a := _dynasty(9, 4)
	GameBot.live_life(a)
	GameBot.live_life(back)
	ok(JSON.stringify(a.to_dict()) == JSON.stringify(back.to_dict()), "and plays on exactly like the original")
	var wrapped := text.substr(0, 40) + "\n  " + text.substr(40, 100) + " \r\n" + text.substr(140)
	ok(GameSaves.import_text("  " + wrapped + "\n")["ok"], "line breaks and spaces from a pasted message are ignored")
	var bak_only := _dynasty(11)
	GameSaves.write_atomic(GameSaves.path_for(3), JSON.stringify(bak_only.to_dict()))
	GameSaves.write_atomic(GameSaves.path_for(3), "garbage")
	ok(GameSaves.export_text(3) != "", "a damaged slot with a good .bak still exports")


func test_bad_backups() -> void:
	var d := _dynasty()
	var good := GameSaves.BACKUP_PREFIX + Marshalls.raw_to_base64(JSON.stringify(d.to_dict()).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	ok(GameSaves.import_text(good)["ok"], "the reference backup is good")
	for bad in ["", "hello", "GLBK2:abcd", GameSaves.BACKUP_PREFIX, GameSaves.BACKUP_PREFIX + "!!!!", GameSaves.BACKUP_PREFIX + "AAAA"]:
		var r := GameSaves.import_text(bad)
		ok(not r["ok"] and str(r["error"]) != "" and r["json"] == "", "turned away with a reason: '%s'" % bad.left(20))
	ok(not GameSaves.import_text(good.left(good.length() / 2))["ok"], "a backup cut short is turned away")
	var not_a_house := GameSaves.BACKUP_PREFIX + Marshalls.raw_to_base64("{\"a\": 1}".to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	ok(not GameSaves.import_text(not_a_house)["ok"], "a block that is not a dynasty is turned away")
	var missing := d.to_dict()
	missing.erase("heir")
	var no_heir := GameSaves.BACKUP_PREFIX + Marshalls.raw_to_base64(JSON.stringify(missing).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	ok(not GameSaves.import_text(no_heir)["ok"], "a dynasty with no heir is turned away")
	var wrong := d.to_dict()
	wrong["history"] = "no"
	var bad_type := GameSaves.BACKUP_PREFIX + Marshalls.raw_to_base64(JSON.stringify(wrong).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	ok(not GameSaves.import_text(bad_type)["ok"], "a part of the wrong kind is turned away")
	var bomb := PackedByteArray()
	bomb.resize(GameSaves.MAX_BACKUP_BYTES + 1024)
	var big := GameSaves.BACKUP_PREFIX + Marshalls.raw_to_base64(bomb.compress(FileAccess.COMPRESSION_GZIP))
	ok(not GameSaves.import_text(big)["ok"], "a block that unpacks past the limit is turned away")


## A save from before slots, the shape every old file has, loads in slot 1 as it always did.
func test_old_save_loads() -> void:
	_wipe()
	var d := _dynasty(13, 1)
	var f := FileAccess.open(GameSaves.base, FileAccess.WRITE)
	f.store_string(JSON.stringify(d.to_dict()))
	f.close()
	var p := GameSaves.peek(1)
	ok(p["valid"] and GameSaves.newest() == 1, "an existing save file is slot 1")
	ok(GameDynasty.load_from_disk() != null, "and loads")
