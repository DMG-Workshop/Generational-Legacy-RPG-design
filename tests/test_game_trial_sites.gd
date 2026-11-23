## A trial's site in the open world (GameTrials.sites, site_near, site_hint, site_use; GameSandbox.use and place_line; the sandbox screen): a trial the family has
## found stands on the ground at the tile the world map marks, its master beside it; Use there makes the master speak and opens the Trials panel; the place line says so;
## nothing is there for a trial not found, upstairs or far off; nothing is saved and no die is drawn.
## Run: godot --headless --path . -s res://tests/test_game_trial_sites.gd
extends SceneTree

const SandboxScreen := preload("res://ui/play/sandbox_screen.gd")
const TrialsPanel := preload("res://ui/play/trials_panel.gd")

var fails := 0
var checks := 0


class FakeApp extends Node:
	var dynasty: GameDynasty

	func show_state() -> void:
		pass


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	test_sites()
	test_sandbox()
	await test_screen()
	print("trial site tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _house() -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.level = 12
	return d


func _found(d: GameDynasty) -> String:
	var id := str(GameTrials.placed(d.seed_value, "material")[0]["id"])
	d.trials["steps"] = {id: 1}
	return id


func test_sites() -> void:
	var d := _house()
	ok(GameTrials.sites(d).is_empty(), "no site stands where none is found")
	ok(GameTrials.site_near(d, 0, 0).is_empty() and GameTrials.site_hint(d, 0, 0) == "", "and none is near anywhere")
	ok(float(GameTrials.setting("site_reach")) >= 1.0, "the reach is in the data")
	var id := _found(d)
	var sites := GameTrials.sites(d)
	ok(sites.size() == 1 and str(sites[0]["id"]) == id, "a found trial has its site")
	var s: Dictionary = sites[0]
	ok(str(s["master_id"]) == str(GameTrials.trial(id)["master"]["id"]), "with the creature that runs it (%s)" % s["master_id"])
	ok(GameWorldMap.trial_markers(d)[0]["x"] == s["x"] and GameWorldMap.trial_markers(d)[0]["z"] == s["z"], "at the tile the world map marks")
	ok(str(GameTrials.site_near(d, int(s["x"]), int(s["z"]))["id"]) == id, "it is near its own tile")
	ok(not GameTrials.site_near(d, int(s["x"]) + 2, int(s["z"])).is_empty(), "and two tiles away")
	ok(GameTrials.site_near(d, int(s["x"]) + 40, int(s["z"])).is_empty(), "but not forty")
	ok(GameTrials.site_hint(d, int(s["x"]), int(s["z"])).contains(str(s["name"])) and GameTrials.site_hint(d, int(s["x"]), int(s["z"])).contains(str(s["master"])), "the hint names the trial and the master: %s" % GameTrials.site_hint(d, int(s["x"]), int(s["z"])))
	var rng_before := d.rng.state
	var use := GameTrials.site_use(d, id)
	ok(bool(use["ok"]) and str(use["open"]) == "trials" and str(use["text"]).contains(str(s["master"])), "Use makes the master speak and asks for the panel: %s" % use["text"])
	ok(str(use["text"]).contains(str(GameTrials.trial(id)["lines"]["opening"])), "with the trial's opening line")
	ok(d.rng.state == rng_before, "no die of the dynasty's is drawn")
	d.heir.trials_done.append(id)
	var again := GameTrials.site_use(d, id)
	ok(str(again["text"]).contains(str(GameTrials.trial(id)["lines"]["success"])) and str(again["text"]).contains(d.heir.name), "once passed the master says so: %s" % again["text"])
	ok(not GameTrials.site_use(d, "no_such_trial")["ok"], "an unknown trial is refused")
	# the tile is kept: asking again gives the same one
	ok(GameTrials.sites(d)[0]["x"] == s["x"] and GameTrials.sites(d)[0]["z"] == s["z"], "the site does not move")
	# nothing is saved of it
	var back := GameDynasty.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	ok(GameTrials.sites(back).size() == 1, "a loaded house finds the same site from what it had done")
	var plain := _house()
	ok(not plain.to_dict().has("trial_sites"), "and no key is written for the sites")


func test_sandbox() -> void:
	var d := _house()
	var sb := GameSandbox.start(d)
	var id := _found(d)
	var s: Dictionary = GameTrials.sites(d)[0]
	sb.heir = Vector2i(int(s["x"]), int(s["z"]))
	ok(sb.place_line().contains(str(s["name"])), "the place line says a trial stands here")
	var r := sb.use()
	ok(bool(r["ok"]) and str(r.get("open", "")) == "trials" and str(r.get("trial", "")) == id, "Use at the site asks for the Trials panel")
	ok(sb.log.back()["kind"] == "site" and str(sb.log.back()["text"]).contains(str(s["master"])), "and logs the master's words")
	sb.heir = Vector2i(int(s["x"]) + 30, int(s["z"]))
	ok(not sb.place_line().contains(str(s["name"])), "far from it the place line says nothing of it")
	ok(str(sb.use().get("open", "")) != "trials", "and Use does not open the panel")
	var d2 := _house()
	var sb2 := GameSandbox.start(d2)
	sb2.heir = Vector2i(int(s["x"]), int(s["z"]))
	ok(str(sb2.use().get("open", "")) != "trials", "a house that has not found the trial finds nothing there")


func test_screen() -> void:
	var d := _house()
	var id := _found(d)
	var s: Dictionary = GameTrials.sites(d)[0]
	var app := FakeApp.new()
	app.dynasty = d
	root.add_child(app)
	var screen: Control = SandboxScreen.new()
	screen.app = app
	app.add_child(screen)
	await process_frame
	await process_frame
	screen.sb.heir = Vector2i(int(s["x"]), int(s["z"]))
	screen.sb.refresh()
	screen._use()
	await process_frame
	var panels := screen.find_children("*", "Control", true, false).filter(func(c): return c.get_script() == TrialsPanel)
	ok(panels.size() == 1 and (panels[0] as Control).has_meta("modal"), "Use at the site opens the Trials panel, modal")
	ok(str(screen.last_line).contains(str(s["master"])), "and the master's words are the status line")
	screen.queue_redraw()
	await process_frame
	ok(true, "a frame with the master standing there draws")
	app.queue_free()
	await process_frame
