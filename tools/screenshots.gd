## Screenshots of the game's key screens, drawn by the real renderer on a virtual display, for comparing with the
## ones kept in tests/screenshots so a change to a screen or to the art is seen in review.
##
## Needs a window, so under a virtual display (software rendering is enough):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy -s res://tools/screenshots.gd -- [mode=check|update|render] [dir=tests/screenshots] [out=/tmp/shots] [only=name,name]
##   mode=render  just draw the screens into `out`
##   mode=check   draw them into `out`, compare each with `dir`/<name>.png and exit 1 on any that differ, any
##                with no stored image and any stored image no screen draws (differences go to out/diff)
##   mode=update  draw them into `dir`: the new stored images (commit them with the change that moved them)
##   mode=store   draw the store's pictures (STORE_SHOTS: a few screens at 1920x1080, and the phone layout at
##                2532x1170) into `out` (default build/store). The virtual display must be at least that big:
##                xvfb-run -a -s "-screen 0 2600x1200x24" ... -- mode=store
## The screens are drawn with reduced motion, fixed seeds and the game's own fonts, so a run is repeatable.
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const TouchHint := preload("res://ui/play/touch_hint.gd")
const Diff := preload("res://tools/screenshot_diff.gd")
const ShopPanel := preload("res://ui/play/shop_panel.gd")
const ChroniclePanel := preload("res://ui/play/chronicle_panel.gd")
const HousePanel := preload("res://ui/play/house_panel.gd")
const TrialsPanel := preload("res://ui/play/trials_panel.gd")
const LooksPanel := preload("res://ui/play/looks_panel.gd")
const CraftPanel := preload("res://ui/play/craft_panel.gd")
const HeirloomPanel := preload("res://ui/play/heirloom_panel.gd")
const MapPanel := preload("res://ui/play/map_panel.gd")
const SkillTreePanel := preload("res://ui/play/skill_tree_panel.gd")
const TavernPanel := preload("res://ui/play/tavern_panel.gd")
const BoardPanel := preload("res://ui/play/board_panel.gd")
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
	["trials", DESKTOP, false, "trials"],
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
	["town", DESKTOP, false, "town"],
	["river", DESKTOP, false, "river"],
	["gate", DESKTOP, false, "gate"],
	["homestead", DESKTOP, false, "homestead"],
	["dollhouse", DESKTOP, false, "dollhouse"],
	["trial_site", DESKTOP, false, "trial_site"],
	["turned", DESKTOP, false, "turned"],
	["wilds_forest", DESKTOP, false, "wilds_forest"],
	["wilds_swamp", DESKTOP, false, "wilds_swamp"],
	["wilds_fae", DESKTOP, false, "wilds_fae"],
	["wilds_tundra", DESKTOP, false, "wilds_tundra"],
	["wilds_farm", DESKTOP, false, "wilds_farm"],
	["dungeon_barrow", DESKTOP, false, "dungeon:hollow_barrow:0,3"],
	["dungeon_ember", DESKTOP, false, "dungeon:emberpeak:4,0"],
	["dungeon_warren", DESKTOP, false, "dungeon:goblin_warrens:5,-1"],
	["dungeon_entrance", DESKTOP, false, "entrance:the_rift"],
	["forge_inside", DESKTOP, false, "interior:hearthmere/forge"],
	["phone_life", PHONE, true, "life"],
	["phone_battle", PHONE, true, "battle:kingshold"],
]

## Look-only extras (never compared, never stored): the world map with a town's card up, and the town with a map pin set, whose minimap
## shows the arrow. Made only when named in `only=`.
const LOOK_SHOTS := [
	["world_map", DESKTOP, false, "worldmap"],
	["world_map_phone", PHONE, true, "worldmap"],
	["world_pin", DESKTOP, false, "worldpin"],
	["menu_pause", DESKTOP, false, "pause"],
	["menu_pause_phone", PHONE, true, "pause"],
	["menu_toasts", DESKTOP, false, "toasts"],
	["menu_title_new", DESKTOP, false, "title_new"],
	["menu_title_phone", PHONE, true, "title"],
	["menu_options_access", DESKTOP, false, "options:access"],
	["menu_options_phone", PHONE, true, "options:sound"],
]

## The pictures for a store page: the same screens, bigger. Nothing compares them; they are made on demand.
const STORE_DESKTOP := Vector2i(1920, 1080)
const STORE_PHONE := Vector2i(2532, 1170)
const STORE_SHOTS := [
	["store_life", STORE_DESKTOP, false, "life"],
	["store_battle", STORE_DESKTOP, false, "battle:kingshold"],
	["store_battle_swamp", STORE_DESKTOP, false, "battle:mirefen"],
	["store_map", STORE_DESKTOP, false, "map"],
	["store_skill_tree", STORE_DESKTOP, false, "skills"],
	["store_chronicle", STORE_DESKTOP, false, "chronicle"],
	["store_phone_life", STORE_PHONE, true, "life"],
	["store_phone_battle", STORE_PHONE, true, "battle:kingshold"],
]

## The wilds shots: the place whose anchor they are taken from, and the offset in tiles (the same seed always: 77).
const WILDS_SPOTS := {
	"wilds_forest": ["whisperwood", 14, -8],
	"wilds_swamp": ["mirefen", 6, 4],
	"wilds_fae": ["elderglade", 0, 3],
	"wilds_tundra": ["frostreach", 12, 8],
}

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
	var out := _arg("out", "build/store" if mode == "store" else "/tmp/shots")
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
	UiSettings.scale = float(OS.get_environment("SHOT_SCALE")) if OS.get_environment("SHOT_SCALE") != "" else 1.0
	TouchHint.finger = false
	UiSettings.set_access("reduced_motion", true)
	var made: Array = []
	var screen := DisplayServer.screen_get_size()
	for shot in (STORE_SHOTS if mode == "store" else SHOTS + (LOOK_SHOTS if mode == "render" and not names.is_empty() else [])):
		if shot[1].x > screen.x or shot[1].y > screen.y:
			print("The display is %dx%d, too small for %s (%dx%d): see the top of tools/screenshots.gd." % [screen.x, screen.y, shot[0], shot[1].x, shot[1].y])
			quit(2)
			return
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
	app.closed_badly = false   # a run of this tool that was killed is not something to draw on the title
	var what: String = shot[3]
	if _arg("show", "") != "":   # (look-only) draw another screen in this shot
		what = _arg("show", "")
	if what == "title":
		app.show_title()
	elif what == "title_new":   # (look-only) the founding form, the title's second page
		app.show_title()
		await _frames(2)
		app.current._show_page("new")
	elif what.begins_with("options:"):   # (look-only) the options on one tab
		app.show_title()
		await _frames(2)
		var om: Control = app.open_menu()
		om._select(what.get_slice(":", 1))
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
	if what.begins_with("dungeon:") or what.begins_with("entrance:"):
		await _dungeon(what)
		return
	if what.begins_with("interior:"):
		await _interior(what)
		return
	if what.begins_with("waygate_"):   # (look-only) a waygate: show=waygate_lit, waygate_ruined, waygate_night, waygate_panel or waygate_realm
		await _waygate(what)
		return
	match what:
		"worldmap", "worldpin", "town", "river", "homestead", "dollhouse", "trial_site", "turned", "gate", "smoke", "wilds_forest", "wilds_swamp", "wilds_fae", "wilds_tundra", "wilds_farm":
			await _open_world(what)
		"life":
			pass
		"menu":
			app.open_menu()
		"pause", "toasts":   # (look-only) the open world paused, or with news up
			await _open_world("homestead")
			if what == "pause":
				app.current.open_pause()
			else:
				for line in ["You find a coin.", "Hartwin greets you.", "The forge is hot.", "Rain begins."]:
					app.current.last_line = line
					await _frames(2)
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
			if _arg("pane", "") == "1":
				cp.set_meta("pane", "chronicle_panel")
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
			if _arg("pane", "") == "1":
				fp.set_meta("pane", "chronicle_panel")
			app.current.add_child(fp)
			await _frames(3)
			for tc in fp.get_children():
				_select_tab(tc, "Creatures")
			await _frames(2)
			var tab_node := fp.find_child("Creatures", true, false)
			if tab_node is ScrollContainer:
				(tab_node as ScrollContainer).scroll_vertical = 100000   # down to the Market
			await _frames(2)
		"shop", "map", "house", "trials", "looks", "skills", "chronicle", "tavern", "board":
			var cls = {"shop": ShopPanel, "map": MapPanel, "house": HousePanel, "trials": TrialsPanel, "looks": LooksPanel, "skills": SkillTreePanel, "chronicle": ChroniclePanel, "tavern": TavernPanel, "board": BoardPanel}[what]
			if _arg("panel", "") != "":   # (look-only) another panel in the "looks" shot: panel=craft or panel=heirlooms
				cls = {"craft": CraftPanel, "heirlooms": HeirloomPanel}[_arg("panel", "")]
				GameCraft.add_material(d, "iron", 6)
				GameCraft.add_material(d, "leather", 3)
				d.heirlooms.append({"name": "Wolfsbane", "boss": "the Wolf King", "gen": 1})
				d.heirlooms.append({"name": "Ashen Crown", "boss": "the Ash Queen", "gen": 1, "level": 2, "worked_gen": 1, "smiths": ["Tess"]})
				d.heir.inventory.append("steel_sword")
			if what == "board":   # (look-only) a notice or two taken up, so the board has progress to show
				var posted: Array = GameData.quests.filter(func(q): return d.quests.is_posted(d, q))
				if not posted.is_empty():
					var town: String = str(posted[0]["giver"])
					d.world.visit(town)
					d.world.location = town
					for q in d.quests.postings(d, town).slice(0, 2):
						d.quests.accept(d, str(q["id"]))
					if d.quests.postings(d, town).is_empty() and not d.quests.active.is_empty():
						d.quests.active[0]["progress"] = 1
			var p: Control = cls.new()
			if "dynasty" in p:
				p.dynasty = d
			if "on_change" in p:
				p.on_change = func(): pass
			if "on_travel" in p:
				p.on_travel = func(_to): pass
			if _arg("gens", "") != "":   # (look-only) a few generations on, so the tree has something to draw
				for i in int(_arg("gens", "0")):
					d._die("old age")
					d.choose_heir(0)
			if what == "shop" and _arg("shoptab", "") != "":   # (look-only) open on another of the town's shops
				p.start_tab = _arg("shoptab", "")
			if _arg("pane", "") == "1":   # as a pane over the world, where the interface skin is worn (a look-only option)
				p.set_meta("pane", p.get_script().resource_path.get_file().get_basename())
			app.current.add_child(p)
			if _arg("tab", "") != "":
				for tc in p.get_children():
					_select_tab(tc, _arg("tab", ""))
				await _frames(2)
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


## The open world with the party in it: the home town with its buildings and two creatures near, or a river with its fords.
func _open_world(what: String) -> void:
	var town := what in ["town", "worldmap", "worldpin"]
	var spot := Vector2i(160, 296) if town else Vector2i(143, 206)
	if WILDS_SPOTS.has(what):
		var wa := GameWorldGen.anchor(str(WILDS_SPOTS[what][0]))
		spot = Vector2i(int(wa["x"]) + int(WILDS_SPOTS[what][1]), int(wa["z"]) + int(WILDS_SPOTS[what][2]))   # the town: the street between the store and the tavern
	if what == "wilds_farm":   # the nearest abandoned farm to Greenvale's anchor: a cottage with a door a person can walk through, a haystack and wheat
		var ga := GameWorldGen.anchor("greenvale")
		var best := 1000000.0
		for r in range(0, 160, 8):
			for ang in 24:
				var px := int(ga["x"]) + int(round(cos(float(ang) / 24.0 * TAU) * r))
				var pz := int(ga["z"]) + int(round(sin(float(ang) / 24.0 * TAU) * r))
				for lm in GameWildsSites.within(d, px, pz, 10.0):
					if str(lm["kind"]) == "farm" and Vector2(float(lm["x"]) - float(ga["x"]), float(lm["z"]) - float(ga["z"])).length() < best:
						best = Vector2(float(lm["x"]) - float(ga["x"]), float(lm["z"]) - float(ga["z"])).length()
						spot = Vector2i(int(lm["x"]) + 2, int(lm["z"]) + 1)
	if what == "gate":
		var gate: Dictionary = GameWalls.gates("hearthmere")[0]   # the north gate, seen from inside the wall, its two guards at their posts
		spot = (gate["inner"] as Vector2i) + Vector2i(0, 5)
	if what == "homestead" or what == "dollhouse":
		var plot := GameBuild.base()
		spot = Vector2i(int(plot["x"]), int(plot["z"])) + (Vector2i.ZERO if what == "homestead" else Vector2i(0, 4))   # inside the house, or at its door with the roof half lifted
		_build_house()
	if what == "trial_site":   # a trial the family has found: its master stands at its ring of stones
		d.trials["steps"] = {str(GameTrials.placed(d.seed_value, "material")[0]["id"]): 1}
		var site: Dictionary = GameTrials.sites(d)[0]
		spot = Vector2i(int(site["x"]) + 2, int(site["z"]) + 2)
	d.world.visit("hearthmere")
	app.show_sandbox()
	await _frames(3)
	var scr: Control = app.current
	scr.set_process(false)   # nothing moves: the picture is the same every time
	d.world_seconds = 0.0   # (the few frames above ran the world clock a little: the status line shows the time)
	d.clock_carry = 0.0
	scr.sb.heir = spot
	scr.sb.creatures.clear()
	scr.sb.companions = GameCompanions.agents_for(d, float(spot.x) + 0.5, float(spot.y) + 0.5)
	scr._warm_figures()
	if town:
		scr.sb.creatures.append(GameBehaviour.new_agent(900, "wolf", float(spot.x) - 5.5, float(spot.y) + 2.5))
		scr.sb.creatures.append(GameBehaviour.new_agent(901, "slime", float(spot.x) + 7.5, float(spot.y) - 3.5))
	if WILDS_SPOTS.has(what):
		scr.sb.refresh()
		scr.sb.creatures.clear()
	if what == "smoke":   # (look only: `show=smoke`) creatures of every band with their level tags, and a smoke pot's cloud over the zone
		d.heir.inventory.append("smoke_pot")
		d.world_seconds = 20.0
		var at: Vector2 = scr.sb.heir_point()
		var bands := [[4, -6.5, -2.0, "slime"], [12, 6.5, -3.0, "wolf"], [18, -4.0, 4.0, "wolf"], [24, 5.0, 3.5, "slime"], [40, 0.5, -5.5, "wolf"]]
		for k in bands.size():
			var ag := GameBehaviour.new_agent(920 + k, str(bands[k][3]), at.x + float(bands[k][1]), at.y + float(bands[k][2]))
			ag["level"] = int(bands[k][0])
			scr.sb.creatures.append(ag)
		scr.sb.use_smoke()
		scr._refresh_panes()
	if what == "turned":   # the heir faces left (the art faces right): a turned figure must stand on its shadow, as an unturned one does
		scr.facing_dir = Vector2i(-1, 0)
	scr.zoom = 2.0 if what == "wilds_farm" else 1.3 if WILDS_SPOTS.has(what) else 1.8 if what == "homestead" or what == "dollhouse" or what == "trial_site" or what == "turned" else (1.0 if town or what == "smoke" else (1.5 if what == "gate" else 0.75))
	scr.cam = Vector2.ZERO
	scr._process(0.0)
	scr.queue_redraw()
	await _frames(2)   # (the world is held still, so the map is drawn again by hand once everything is made: a figure made while drawing blanks those drawn before it in that frame)
	scr.overlay.queue_redraw()
	await _frames(2)
	if what == "worldpin":   # (look-only) a pin on Kingshold: the arrow on the minimap, the line in the status pane
		GameTravel.set_pin(d, "kingshold")
		scr._refresh_panes()
		scr._refresh_status()
		await _frames(2)
	if what == "worldmap":   # (look-only) the world map with a town's card up
		scr._open_world_map()
		await _frames(3)
		for c in scr.get_children():
			if c.has_method("select"):
				c.select(_arg("town", "ironford"))
		await _frames(3)


## A waygate seen from in front (the heir two tiles from the arch): `waygate_lit` (Hearthmere's, which starts awake), `waygate_ruined` (Highcrag's, cracked and
## mossy among fallen stones), `waygate_night` (the lit one in the dark, its glow on the ground), `waygate_panel` (the panel open over the lit one) and
## `waygate_realm` (the Verdant Gate repaired and stepped through, the heir in the realm's arrival ground). Look-only: no stored picture is made from them.
func _waygate(what: String) -> void:
	var gid := "highcrag_arch" if what == "waygate_ruined" else ("verdant_gate" if what == "waygate_realm" else "hearthmere_arch")
	d.gen = 3
	d.heir.gold = 900
	d.world.visit("hearthmere")
	app.show_sandbox()
	await _frames(3)
	var scr: Control = app.current
	scr.set_process(false)
	d.world_seconds = 0.0
	d.clock_carry = 0.0
	if what == "waygate_night":
		d.world_seconds = float(GameDay.setting("day_seconds")) * fposmod(0.0 - float(GameDay.setting("start_phase")), 1.0)
	if what == "waygate_realm":
		var fixed := {}
		for i in GameGates.slot_count(gid):
			fixed["%s:%d" % [gid, i]] = 0
		d.gates["fixed"] = fixed
	var front := GameGates.front_of(d, gid)
	scr.sb.heir = front
	scr.sb.creatures.clear()
	scr.sb.companions = []
	scr.zoom = 2.0 if what != "waygate_realm" else 1.4
	if what == "waygate_realm":
		var r: Dictionary = scr.sb.step_through(gid, "realm:verdant")
		print("realm step: ", r["text"])
		scr._warm_figures()
	scr.cam = Vector2.ZERO
	scr._process(0.0)
	scr.queue_redraw()
	if what == "waygate_panel":
		scr._open_gate(gid)
	await _frames(3)
	scr.overlay.queue_redraw()
	scr.glow_layer.queue_redraw()
	await _frames(3)


## The inside of a town building (`interior:<town>/<service>`): the heir at the way out, the person who works there across the floor, both as
## figures (they were once a circle and a coloured block).
func _interior(what: String) -> void:
	var space := what.trim_prefix("interior:")
	d.world.visit(space.get_slice("/", 0))
	app.show_sandbox()
	await _frames(3)
	var scr: Control = app.current
	scr.set_process(false)
	d.world_seconds = 0.0
	d.clock_carry = 0.0
	var door: Dictionary = GameSpaces.space("world/" + space)["door"]
	scr.sb.creatures.clear()
	scr.sb.companions = []
	scr.sb.heir = Vector2i(int(door["x"]), int(door["z"]))
	scr.sb.use()
	scr.zoom = 2.5
	scr._warm_figures()
	scr.cam = Vector2.ZERO
	scr._process(0.0)
	scr.queue_redraw()
	await _frames(2)
	scr.overlay.queue_redraw()
	await _frames(2)


## A dungeon seen from inside (`dungeon:<place>:<x>,<z>`: the heir at that cell of its floor, in the dark of its theme, creatures
## standing still) or its entrance seen from the open world (`entrance:<place>`).
func _dungeon(what: String) -> void:
	var parts := what.split(":")
	var place := parts[1]
	d.gen = 60
	d.world.visit("hearthmere")
	app.show_sandbox()
	await _frames(3)
	var scr: Control = app.current
	scr.set_process(false)
	d.world_seconds = 0.0
	d.clock_carry = 0.0
	var door: Dictionary = GameSpaces.space("world/" + place)["door"]
	scr.sb.creatures.clear()
	scr.sb.companions = []
	if what.begins_with("entrance:"):
		scr.sb.heir = Vector2i(int(door["x"]), int(door["z"]) + 3)
		scr.zoom = 1.6
	else:
		scr.sb.heir = Vector2i(int(door["x"]), int(door["z"]))
		scr.sb.use()
		var xz := parts[2].split(",")
		scr.sb.heir = Vector2i(int(xz[0]), int(xz[1]))
		scr.zoom = 1.8
	scr._warm_figures()
	scr.cam = Vector2.ZERO
	scr._process(0.0)
	scr.queue_redraw()
	await _frames(2)
	scr.overlay.queue_redraw()
	await _frames(2)


## A family house on the homestead plot: walls round floor, two doors, a bed, an anvil and hearth, a trough, stairs, a road to the door, and an upper floor and roof.
func _build_house() -> void:
	var base := GameBuild.base()
	var ox := int(base["x"]) - 5
	var oz := int(base["z"]) - 4
	var s := GameBuild.SURFACE
	for x in 9:
		for z in 6:
			var edge := x == 0 or x == 8 or z == 0 or z == 5 or x == 4
			d.built[GameBuild.key(ox + x, s, oz + z)] = "wall" if edge else "floor"
			d.built[GameBuild.key(ox + x, s - 1, oz + z)] = "wall" if (x == 0 or x == 8 or z == 0 or z == 5) else "floor"
			d.built[GameBuild.key(ox + x, s - 2, oz + z)] = "roof"
	d.built[GameBuild.key(ox + 2, s, oz + 5)] = "door"
	d.built[GameBuild.key(ox + 4, s, oz + 2)] = "door"
	d.built[GameBuild.key(ox + 1, s, oz + 1)] = "bed"
	d.built[GameBuild.key(ox + 6, s, oz + 1)] = "anvil"
	d.built[GameBuild.key(ox + 7, s, oz + 1)] = "hearth"
	d.built[GameBuild.key(ox + 2, s, oz + 3)] = "stairs"
	d.built[GameBuild.key(ox + 6, s, oz + 3)] = "trough"
	for z in range(6, 10):
		d.built[GameBuild.key(ox + 2, s, oz + z)] = "road"
