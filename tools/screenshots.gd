## Screenshots of the game's key screens, drawn by the real renderer on a virtual display, for comparing with the
## ones kept in tests/screenshots so a change to a screen or to the art is seen in review.
##
## Needs a window, so under a virtual display (software rendering is enough):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy -s res://tools/screenshots.gd -- [mode=check|update|render] [dir=tests/screenshots] [out=/tmp/shots] [only=name,name]
##   mode=render  just draw the screens into `out`
##   mode=check   draw them into `out`, compare each with `dir`/<name>.png and exit 1 on any that differ, any
##                with no stored image and any stored image no screen draws (differences go to out/diff)
##   mode=update  draw them into `dir`: the new stored images (commit them with the change that moved them)
## The screens are drawn with reduced motion, fixed seeds and the game's own fonts, so a run is repeatable.
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const TouchHint := preload("res://ui/play/touch_hint.gd")
const Diff := preload("res://tools/screenshot_diff.gd")
const ShopPanel := preload("res://ui/play/shop_panel.gd")
const ChroniclePanel := preload("res://ui/play/chronicle_panel.gd")
const HousePanel := preload("res://ui/play/house_panel.gd")
const LooksPanel := preload("res://ui/play/looks_panel.gd")
const MapPanel := preload("res://ui/play/map_panel.gd")
const SkillTreePanel := preload("res://ui/play/skill_tree_panel.gd")
const TMP := "user://screenshots_tmp/"
const DESKTOP := Vector2i(1280, 720)
const PHONE := Vector2i(844, 390)

## name, size, touch (the phone layout), and the screen to show.
const SHOTS := [
	["title", DESKTOP, false, "title"],
	["life", DESKTOP, false, "life"],
	["shop", DESKTOP, false, "shop"],
	["map", DESKTOP, false, "map"],
	["house", DESKTOP, false, "house"],
	["looks", DESKTOP, false, "looks"],
	["skill_tree", DESKTOP, false, "skills"],
	["chronicle", DESKTOP, false, "chronicle"],
	["chronicle_titles", DESKTOP, false, "titles"],
	["chronicle_creatures", DESKTOP, false, "creatures"],
	["chronicle_farm", DESKTOP, false, "farm"],
	["menu", DESKTOP, false, "menu"],
	["report", DESKTOP, false, "report"],
	["event", DESKTOP, false, "event"],
	["battle_town", DESKTOP, false, "battle:kingshold"],
	["battle_swamp", DESKTOP, false, "battle:mirefen"],
	["phone_life", PHONE, true, "life"],
	["phone_battle", PHONE, true, "battle:kingshold"],
]

var app: Node
var d: GameDynasty


func _init() -> void:
	_run.call_deferred()


func _arg(key: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return default


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	GameData.load_all()
	var mode := _arg("mode", "render")
	var dir := _arg("dir", "tests/screenshots")
	var out := _arg("out", "/tmp/shots")
	var only := _arg("only", "")
	var names: Array = Array(only.split(",", false))
	if DisplayServer.get_name() == "headless":
		print("This needs a window: run it under a virtual display (see the top of tools/screenshots.gd).")
		quit(2)
		return
	var target := dir if mode == "update" else out
	DirAccess.make_dir_recursive_absolute(target)
	DirAccess.make_dir_recursive_absolute(TMP)
	GameDynasty.save_path = TMP + "save.json"
	UiSettings.path = TMP + "settings.cfg"
	UiSettings.scale = 1.0
	TouchHint.finger = false
	UiSettings.set_access("reduced_motion", true)
	var made: Array = []
	for shot in SHOTS:
		if not names.is_empty() and shot[0] not in names:
			continue
		var img := await _shoot(shot)
		if img == null:
			print("FAILED to draw %s" % shot[0])
			quit(1)
			return
		img.save_png("%s/%s.png" % [target, shot[0]])
		made.append(shot[0])
		print("drew %s (%dx%d)" % [shot[0], img.get_width(), img.get_height()])
	for f in DirAccess.get_files_at(TMP):
		DirAccess.remove_absolute(TMP + f)
	if mode != "check":
		quit(0)
		return
	quit(_check(dir, out, made, not names.is_empty()))


## Compares what was drawn in `out` with `dir`. Returns the exit code.
func _check(dir: String, out: String, made: Array, partial: bool) -> int:
	var bad := 0
	DirAccess.make_dir_recursive_absolute(out + "/diff")
	for n in made:
		var stored := "%s/%s.png" % [dir, n]
		if not FileAccess.file_exists(stored):
			print("NEW      %s has no stored image in %s" % [n, dir])
			bad += 1
			continue
		var r := Diff.compare(Image.load_from_file(stored), Image.load_from_file("%s/%s.png" % [out, n]))
		if r["ok"]:
			print("same     %s (%d pixels differ, worst %d)" % [n, r["differing"], r["worst"]])
		else:
			print("DIFFERS  %s: %s" % [n, r["reason"]])
			bad += 1
			if r["diff"] != null:
				(r["diff"] as Image).save_png("%s/diff/%s.png" % [out, n])
	if not partial:
		var drawn := {}
		for s in SHOTS:
			drawn[s[0]] = true
		for f in DirAccess.get_files_at(dir):
			if f.get_extension() == "png" and not drawn.has(f.get_basename()):
				print("STALE    %s is stored but no screen draws it" % f)
				bad += 1
	print("%d screens, %d not as stored." % [made.size(), bad])
	return 1 if bad > 0 else 0


## Draws one screen and returns the window's image.
func _shoot(shot: Array) -> Image:
	UiSettings.force_mobile = 1 if shot[2] else 0
	UiSettings.force_touch = 1 if shot[2] else 0
	root.size = shot[1]
	if app != null:
		app.queue_free()
		await _frames(2)
	app = GameApp.new()
	root.add_child(app)
	await _frames(3)
	var what: String = shot[3]
	if what == "title":
		app.show_title()
	else:
		_game()
		await _screen(what)
	await _frames(8)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


## A founded house with a party, always the same: a warrior of seed 77 in the king's town.
func _game() -> void:
	app.new_game("Tess", "warrior", "faetouched", 77, "human")
	d = app.dynasty
	d.pending_event = {}
	d.heir.level = 18
	d.heir.gold = 1800
	d.world.visit("kingshold")
	d.world.weather_id = "clear"
	for id in ["bren_cask", "sister_oriel"]:
		d.party.members.append({"id": id, "name": GameParty.def(id)["name"], "hp": 1, "mp": 0, "level": 18, "gen": 1,
			"due": 0.0, "battles": 0, "hired_gen": 1, "diseases": []})
		d.party.history[id] = {"name": GameParty.def(id)["name"], "status": "serving", "gen": 1, "first_gen": 1, "battles": 0,
			"fallen": [], "line": 0, "past": [], "born": d.world.year - 30.0, "rolled": d.world.year}
	d.party.rest(d)
	d.heir.full_heal()
	d.heir.age = maxf(d.heir.age, d.heir.family_min_age())
	d.found_family()
	d.journal.clear()
	d.heir.equipment["weapon"] = "steel_sword"
	d.heir.equipment["armor"] = "chainmail"


func _screen(what: String) -> void:
	app.show_state()
	await _frames(3)
	match what:
		"life":
			pass
		"menu":
			app.open_menu()
		"report":
			app.open_menu()
			app.open_report()
		"event":
			GameEvents.begin(d, "elven_wardens")
			app.show_state()
		"titles":
			d.heir.battles_won = 30   # the Blooded and the Veteran, one worn; the house's first titles come with its generations
			d.gen = 10
			GameTitles.update(d)
			GameTitles.wear(d, "veteran")
			var c := ChroniclePanel.new()
			c.dynasty = d
			c.on_change = func(): pass
			app.current.add_child(c)
			await _frames(3)
			for tc in c.get_children():
				_select_tab(tc, "Titles")
		"creatures":
			GameRoster.add(d, "wolf", "Ash")
			GameRoster.add(d, "drake", "Ember")
			d.heir.gold = 1000
			GameRanch.on_years(d, 4.0, [])   # the wolf is grown, the egg has hatched, the whelp is still young
			var ash: Dictionary = d.roster[0]
			var fen := GameRoster.add(d, "frost_wolf", "Fen")   # a grown frost wolf; the pair's young is a cross-breed
			fen["stage"] = "adult"
			fen["age"] = 5.0
			fen["sex"] = GameSex.opposite(str(ash["sex"]))
			ash["breeding"] = true
			fen["breeding"] = true
			var pair_rng := RandomNumberGenerator.new()
			pair_rng.seed = 7
			if str(ash["sex"]) == GameSex.FEMALE:
				GameBreeding._birth(d, ash, fen, pair_rng)
			else:
				GameBreeding._birth(d, fen, ash, pair_rng)
			var cp := ChroniclePanel.new()
			cp.dynasty = d
			cp.on_change = func(): pass
			app.current.add_child(cp)
			await _frames(3)
			for tc in cp.get_children():
				_select_tab(tc, "Creatures")
		"farm":
			d.heir.gold = 1000
			for pair in [["sheep", "Dolly"], ["cattle", "Bluebell"], ["chicken", "Hen"]]:
				GameFarm.buy(d, str(pair[0]))
				d.roster.back()["name"] = str(pair[1])
			d.roster[0]["stage"] = "adult"   # the sheep is grown and gives wool
			d.roster[0]["age"] = 4.0
			d.roster[0]["mood"] = 90
			var fp := ChroniclePanel.new()
			fp.dynasty = d
			fp.on_change = func(): pass
			app.current.add_child(fp)
			await _frames(3)
			for tc in fp.get_children():
				_select_tab(tc, "Creatures")
			await _frames(2)
			var tab_node := fp.find_child("Creatures", true, false)
			if tab_node is ScrollContainer:
				(tab_node as ScrollContainer).scroll_vertical = 100000   # down to the Market
			await _frames(2)
		"shop", "map", "house", "looks", "skills", "chronicle":
			var cls = {"shop": ShopPanel, "map": MapPanel, "house": HousePanel, "looks": LooksPanel, "skills": SkillTreePanel, "chronicle": ChroniclePanel}[what]
			var p: Control = cls.new()
			if "dynasty" in p:
				p.dynasty = d
			if "on_change" in p:
				p.on_change = func(): pass
			if "on_travel" in p:
				p.on_travel = func(_to): pass
			app.current.add_child(p)
		_:
			if what.begins_with("battle:"):
				d.world.visit(what.get_slice(":", 1))
				d.world.location = what.get_slice(":", 1)
				d.start_hunt("hunt")
				d.auto_battle = false
				app.show_state()


## Opens the tab called `name` of the first TabContainer found under `n`.
func _select_tab(n: Node, name: String) -> void:
	if n is TabContainer:
		var tab := (n as TabContainer).get_node_or_null(name)
		if tab != null:
			(n as TabContainer).current_tab = tab.get_index()
		return
	for c in n.get_children():
		_select_tab(c, name)
