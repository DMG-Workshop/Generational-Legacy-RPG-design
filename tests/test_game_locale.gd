## Localisation (roadmap item 40): the data and ways to break it; the game's own language changing nothing; the
## pseudo-language (accents on every letter, a third longer, bracketed, placeholders untouched, the same each time)
## reaching the fight's lines and the tutorial's tips; a translation's lines used when their placeholders match and
## the source line when they do not or are missing; checking a translation; the choice kept in the settings file and
## applied at start; the menu offering a language only when there is a second one; and the font having every letter
## the first languages and the pseudo-language need.
## Run: godot --headless --path . -s res://tests/test_game_locale.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const MenuPanel := preload("res://ui/play/menu_panel.gd")
const DIR := "user://test_locale/"

var checks := 0
var fails := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
	GameData.load_all()
	GameDynasty.save_path = DIR + "save.json"
	UiSettings.path = DIR + "settings.cfg"
	UiSettings.scale = 1.0
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	root.size = Vector2i(1280, 720)
	test_data()
	test_source_unchanged()
	test_pseudo()
	test_translation()
	test_font()
	await test_setting_and_menu()
	GameLocale.current = ""
	GameLocale._cache = {}
	GameLocale._translations = {}
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
	print("locale tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


func test_data() -> void:
	ok(GameLocale.validate().is_empty(), "the data is sound: %s" % str(GameLocale.validate()))
	var saved: Dictionary = GameLocale.data().duplicate(true)
	GameLocale.data()["source"] = "tlh"
	ok(not GameLocale.validate().is_empty(), "a source language that is not listed is found")
	GameLocale._cache = saved.duplicate(true)
	GameLocale.data()["pseudo"]["map"]["{"] = "("
	ok(not GameLocale.validate().is_empty(), "a pseudo-language that would break placeholders is found")
	GameLocale._cache = saved.duplicate(true)
	GameLocale.data()["pseudo"]["expand"] = 0.0
	ok(not GameLocale.validate().is_empty(), "a pseudo-language no longer than the source is found")
	GameLocale._cache = saved.duplicate(true)
	GameLocale.data()["locales"]["pseudo"]["hidden"] = false
	ok(not GameLocale.validate().is_empty(), "a pseudo-language offered to players is found")
	GameLocale._cache = saved.duplicate(true)
	GameLocale.data()["catalogs"].append("recipes")
	ok(not GameLocale.validate().is_empty(), "a catalog with no text behind it is found")
	GameLocale._cache = saved.duplicate(true)
	GameLocale.data()["locales"]["fr"] = {"name": "Français"}
	ok(str(GameLocale.validate()).contains("has no line for"), "a language listed with no translation is found (every line is missing)")
	GameLocale._cache = {}
	GameLocale._translations = {}
	ok(GameLocale.validate().is_empty(), "(and the data is whole again after)")
	ok(GameLocale.source() == "en" and GameLocale.offered() == ["en"] and GameLocale.ids().has("pseudo"), "English is the source and the only language offered; the pseudo-language is there but hidden")
	ok(GameLocale.source_lines("battle").size() >= 25 and GameLocale.source_lines("tutorial").size() >= 10, "the catalogs are the fight's lines (%d) and the tips (%d)" % [GameLocale.source_lines("battle").size(), GameLocale.source_lines("tutorial").size()])


func test_source_unchanged() -> void:
	GameLocale.current = ""
	ok(GameLocale.locale() == "en", "a game that never chose a language is in English")
	var same := true
	for key in GameLocale.source_lines("battle"):
		var src := str(GameLocale.source_lines("battle")[key])
		if GameLocale.text("battle", key, src) != src:
			same = false
	ok(same, "and every line of the fight reads exactly as written")
	ok(GameMessages.line("foe_defeated", {"name": "Dire Wolf"}) == "Dire Wolf is defeated.", "through GameMessages too: %s" % GameMessages.line("foe_defeated", {"name": "Dire Wolf"}))
	ok(not GameLocale.set_locale("tlh") and GameLocale.locale() == "en", "an unknown language is refused")


func test_pseudo() -> void:
	var line := "{who} hits {whom} for {n}{tail}."
	var p := GameLocale.pseudo(line)
	ok(p.begins_with("[") and p.ends_with("]"), "a pseudo line is bracketed, so one cut off at either end shows: %s" % p)
	ok(GameLocale.placeholders(p) == GameLocale.placeholders(line) and p.contains("{who}") and p.contains("{tail}"), "its placeholders are untouched")
	ok(not p.contains("hits") and p.contains("ĥíţš"), "its letters are accented")
	ok(GameLocale.pseudo(line) == p, "the same line is the same every time")
	var longer := true
	var kept := true
	for catalog in ["battle", "tutorial"]:
		for key in GameLocale.source_lines(catalog):
			var src := str(GameLocale.source_lines(catalog)[key])
			var ps := GameLocale.pseudo(src)
			if ps.length() < int(float(src.length()) * 1.2):
				longer = false
			if GameLocale.placeholders(ps) != GameLocale.placeholders(src):
				kept = false
	ok(longer, "every line of both catalogs comes out at least a fifth longer")
	ok(kept, "and keeps its placeholders")
	ok(GameLocale.set_locale("pseudo") and GameLocale.locale() == "pseudo", "the pseudo-language can be chosen")
	var said := GameMessages.line("foe_defeated", {"name": "Dire Wolf"})
	ok(said.contains("Dire Wolf") and said.begins_with("[") and not said.contains("defeated"), "a line of the fight is then pseudo, with the name filled in as it is: %s" % said)
	ok(GameMessages.problems.is_empty(), "and no placeholder went unfilled")
	var d := GameDynasty.new_game(11, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	var tip := GameTutorial.current(d)
	ok(str(tip["text"]).begins_with("[") and str(tip["text"]).contains("Tess") and not str(tip["text"]).contains("Welcome"), "so is the tutorial's tip: %s" % str(tip["text"]))
	GameLocale.set_locale("en")
	ok(str(GameTutorial.current(d)["text"]).begins_with("Welcome, Tess"), "and back in English it reads as before")


func test_translation() -> void:
	GameLocale.data()["locales"]["xx"] = {"name": "Test"}
	GameLocale._translations["xx"] = {
		"battle": {
			"foe_defeated": "Vaincu: {name}!",
			"hit": "{whom} is hit by {who}: {n}{tail}.",
			"hit_ward": "{who} hits {whom}.",
			"no_such_line": "nothing",
		},
		"tutorial": {},
	}
	GameLocale.set_locale("xx")
	ok(GameMessages.line("foe_defeated", {"name": "Dire Wolf"}) == "Vaincu: Dire Wolf!", "a translated line is used")
	ok(GameMessages.line("hit", {"who": "Tess", "whom": "the wolf", "n": 12, "tail": ""}) == "the wolf is hit by Tess: 12.", "a translation may put its placeholders in another order")
	var fallback := GameMessages.line("hit_ward", {"who": "Tess", "whom": "the wolf", "n": 12, "absorbed": 3, "tail": ""})
	ok(fallback == "Tess hits the wolf for 12 (3 absorbed).", "a line that drops a placeholder is not used: the source line is (%s)" % fallback)
	ok(GameMessages.line("hit_ward_all", {"who": "Tess", "whom": "the wolf", "absorbed": 9}) == "Tess hits the wolf, and the ward absorbs all 9.", "a line with no translation falls back to the source")
	var c := GameLocale.check("xx")
	ok(c["problems"].size() == 2 and str(c["problems"]).contains("no_such_line") and str(c["problems"]).contains("hit_ward"), "checking the translation finds the unknown line and the wrong placeholders: %s" % str(c["problems"]))
	ok(c["missing"].size() == GameLocale.source_lines("battle").size() - 3 + GameLocale.source_lines("life").size() + GameLocale.source_lines("tutorial").size(), "and lists every line still to translate (%d)" % c["missing"].size())
	GameLocale.set_locale("en")
	GameLocale._cache = {}
	GameLocale._translations = {}
	ok(GameMessages.line("foe_defeated", {"name": "Dire Wolf"}) == "Dire Wolf is defeated.", "back in English nothing of it remains")


func test_font() -> void:
	var font: Font = ThemeDB.fallback_font
	var missing := ""
	var sample := str(GameLocale.data()["sample_chars"])
	for i in sample.length():
		if not font.has_char(sample.unicode_at(i)):
			missing += sample[i]
	ok(missing == "", "the game's font has every letter of the first languages meant (%d checked; missing: '%s')" % [sample.length(), missing])
	var pseudo_missing := ""
	var p: Dictionary = GameLocale.data()["pseudo"]
	for ch in (p["map"].values() + [p["pad"], p["open"], p["close"]]):
		if not font.has_char(str(ch).unicode_at(0)):
			pseudo_missing += str(ch)
	ok(pseudo_missing == "", "and every letter the pseudo-language uses, so a box on screen means missing text and not a missing glyph (missing: '%s')" % pseudo_missing)


func _texts(n: Node, out: Array = []) -> Array:
	if n is Label and (n as Label).is_visible_in_tree():
		out.append((n as Label).text)
	if n is Button and (n as Button).is_visible_in_tree():
		out.append((n as Button).text)
	for c in n.get_children():
		_texts(c, out)
	return out


func test_setting_and_menu() -> void:
	ok(UiSettings.locale() == "en", "the settings start in English")
	ok(UiSettings.set_locale("pseudo") and UiSettings.locale() == "pseudo", "a language is kept in the settings file")
	ok(not UiSettings.set_locale("tlh") and UiSettings.locale() == "pseudo", "an unknown one is not")
	for junk in ["tlh", 5, ["en"], true]:
		UiSettings.store("locale", junk)
		ok(UiSettings.locale() == "en", "a damaged choice in the file (%s) reads as English" % str(junk))
	UiSettings.set_locale("pseudo")
	GameLocale.current = ""
	var app := GameApp.new()
	root.add_child(app)
	await _frames(3)
	ok(GameLocale.locale() == "pseudo", "a game that starts takes the stored language")
	app.new_game("Tess", "warrior", "faetouched", 51)
	await _frames(3)
	var all := str(_texts(app.current))
	ok(all.contains("[Ŵéľçöмé"), "and the life screen's tip is shown in it")
	var save := JSON.stringify(app.dynasty.to_save())
	ok(not save.contains("locale") and not save.contains("pseudo"), "the language is not in the save")
	var m: Control = app.open_menu()
	await _frames(3)
	ok(not _texts(m).has("Language"), "with one language to offer the menu has no Language row")
	m.queue_free()
	GameLocale.data()["locales"]["xx"] = {"name": "Test"}
	GameLocale._translations["xx"] = {"battle": {}, "tutorial": {}}
	m = app.open_menu()
	await _frames(3)
	var texts := _texts(m)
	ok(texts.has("Language") and texts.has("English") and texts.has("Test") and not texts.has("Pseudo-language (test)"), "with a second one it has, and never lists the pseudo-language")
	app.set_locale("xx")
	await _frames(4)
	ok(UiSettings.locale() == "xx" and GameLocale.locale() == "xx", "choosing one stores it and applies it at once")
	app.set_locale("en")
	await _frames(4)
	ok(UiSettings.locale() == "en" and GameLocale.locale() == "en", "and back to English")
	app.queue_free()
	await _frames(2)
