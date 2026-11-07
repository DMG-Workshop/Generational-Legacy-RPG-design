## Cosmetic randomness stays apart from the game's (ui/play/cosmetic_rng.gd). No file of the game's view
## draws the dynasty's dice or Godot's global ones: the only dice in ui/play are CosmeticRng's. Keyed dice
## roll the same every time; a fight played through the battle screen, with its poses, scenery and effects
## on, ends exactly as the same fight played with no view (same log, same end, same dice, same dynasty), so
## the golden digests do not depend on whether anything is drawn.
## Run: godot --headless --path . -s res://tests/test_game_cosmetic.gd
extends SceneTree

const Scen := preload("res://tests/round_scenarios.gd")
const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const TouchHint := preload("res://ui/play/touch_hint.gd")
const DIR := "user://test_cosmetic/"
const ALLOWED := "res://ui/play/cosmetic_rng.gd"

var fails := 0
var checks := 0
var app: Node


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	GameData.load_all()
	DirAccess.make_dir_recursive_absolute(DIR)
	test_keyed_dice()
	test_source()
	await test_view_on_or_off()
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
	print("%d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- the dice

func test_keyed_dice() -> void:
	var a := CosmeticRng.keyed("plains:day")
	var b := CosmeticRng.keyed("plains:day")
	var c := CosmeticRng.keyed("marsh:day")
	var ra: Array = [a.randi(), a.randf(), a.randi_range(0, 99)]
	var rb: Array = [b.randi(), b.randf(), b.randi_range(0, 99)]
	ok(ra == rb, "dice keyed alike roll alike")
	ok(c.randi() != CosmeticRng.keyed("plains:day").randi(), "dice keyed differently roll differently")
	ok(CosmeticRng.loose() != null, "loose dice can be had")


# ---------------------------------------------------------------- the source

func _files(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + f)


## Code lines of a file (comments cut off), so a word in a comment is no use of the dice.
func _code(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	var out: Array = []
	if f == null:
		return out
	var n := 0
	for line in f.get_as_text().split("\n"):
		n += 1
		var cut := line.find("#")
		out.append([n, line if cut < 0 else line.substr(0, cut)])
	return out


func test_source() -> void:
	var files: Array = ["res://main.gd"]
	_files("res://ui/play/", files)
	ok(files.size() > 20, "the game's view files are found (%d)" % files.size())
	var global := RegEx.new()
	global.compile("(^|[^.\\w])(randf|randi|randf_range|randi_range|randomize|rand_from_seed|pick_random)\\(|\\.shuffle\\(|\\.pick_random\\(|RandomNumberGenerator\\.new\\(")
	var dyn := RegEx.new()
	dyn.compile("(\\w+)\\.rng\\b")
	var found := 0
	for path in files:
		if path == ALLOWED:
			continue
		for pair in _code(path):
			var line: String = pair[1]
			if global.search(line) != null:
				found += 1
				ok(false, "%s:%d draws global or its own dice, not CosmeticRng's: %s" % [path, pair[0], line.strip_edges()])
			for m in dyn.search_all(line):
				if m.get_string(1) != "cv":   # cv is the scenery canvas, whose dice are CosmeticRng's
					found += 1
					ok(false, "%s:%d reaches for a .rng that is not the canvas's: %s" % [path, pair[0], line.strip_edges()])
	ok(found == 0, "no file of the view draws the dynasty's dice or Godot's global ones")
	var sc := FileAccess.get_file_as_string("res://ui/play/scenery_art.gd")
	ok(sc.contains("CosmeticRng.keyed("), "the scenery's dice are CosmeticRng's")


# ---------------------------------------------------------------- the view on or off

## What a fight left behind, in a form that compares.
func _end(d: GameDynasty, b: GameBattle) -> Dictionary:
	var state := Scen.state_of(b)
	state.erase("rng")
	var flat := func(v: Variant) -> String: return JSON.stringify(JSON.parse_string(JSON.stringify(v)))
	return {"log": flat.call(b.log), "state": flat.call(state), "rng": str(b.rng.state), "dynasty": flat.call(Scen.drop_sex(d.to_dict()))}


func _bare(seed_val: int, cls: String, n: int, kind: String) -> Dictionary:
	var d := Scen.make(seed_val, cls, n, kind)
	var b := d.battle
	var guard := 0
	while not b.is_over() and guard < Scen.GUARD:
		guard += 1
		GameTactics.auto_turn(b)
	d.finish_battle()
	return _end(d, b)


## The same fight shown on the battle screen a turn at a time, every pose, effect and float on.
func _shown(seed_val: int, cls: String, n: int, kind: String) -> Dictionary:
	var d := Scen.make(seed_val, cls, n, kind)
	app.dynasty = d
	d.auto_battle = false
	app.show_state()
	await _frames(4)
	var bv: Control = app.current
	var b := d.battle
	var guard := 0
	while not b.is_over() and guard < Scen.GUARD:
		guard += 1
		await bv._do(func(): GameTactics.auto_turn(b))
	await _frames(2)
	d.finish_battle()
	return _end(d, b)


func test_view_on_or_off() -> void:
	GameDynasty.save_path = DIR + "save.json"
	UiSettings.path = DIR + "settings.cfg"
	UiSettings.scale = 1.0
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	TouchHint.finger = false
	UiSettings.set_access("reduced_motion", false)
	root.size = Vector2i(1280, 720)
	await _frames(2)
	app = GameApp.new()
	root.add_child(app)
	await _frames(2)
	app.new_game("Tess", "warrior", "faetouched", 77, "human")
	for c in [[6, "paladin", 2, "hunt"], [9, "mage", 1, "legend"]]:
		var tag := "%d %s x%d %s" % c
		var bare := _bare(c[0], c[1], c[2], c[3])
		var shown: Dictionary = await _shown(c[0], c[1], c[2], c[3])
		ok(shown["log"] == bare["log"], "%s: shown on the battle screen, the same log" % tag)
		ok(shown["state"] == bare["state"] and shown["rng"] == bare["rng"], "%s: shown, the same end and the same dice" % tag)
		ok(shown["dynasty"] == bare["dynasty"], "%s: shown, the same dynasty afterwards" % tag)
