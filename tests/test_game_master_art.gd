## The masters' art (data/art/masters.json, SpriteArt.master): each trial's master is its creature repainted, so every trial has a look of its own that is
## not the plain creature, it holds to the art style like any creature, a bad entry is caught by the validator, the Trials panel draws it and the fight with a master
## carries it, and a trial with no look falls back to the plain creature.
## Run: godot --headless --path . -s res://tests/test_game_master_art.gd
extends SceneTree

const SpriteArt := preload("res://ui/play/sprite_art.gd")
const TrialsPanel := preload("res://ui/play/trials_panel.gd")

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameData.load_all()
	test_looks()
	test_style()
	test_validator()
	await test_panel()
	test_fight()
	print("master art tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func test_looks() -> void:
	var ids := GameTrials.ids()
	ok(ids.size() >= 17, "there are trials (%d)" % ids.size())
	ok(ids.all(func(i): return SpriteArt.has_master(str(i))), "every trial has a master look")
	var seen := {}
	for id in ids:
		var t := GameTrials.trial(str(id))
		var img := SpriteArt.master_image(str(id))
		var plain := SpriteArt.creature(str(t["master"]["id"]))
		ok(SpriteArt.master(str(id)) != null and plain != null, "%s has a texture and so has its creature" % id)
		ok(img.get_width() > 1, "%s paints" % id)
		seen[str(id)] = hash(img.get_data())
	var distinct := {}
	for k in seen:
		distinct[seen[k]] = true
	ok(distinct.size() == seen.size(), "no two masters look the same, even when they share a creature (%d looks)" % distinct.size())
	ok(not SpriteArt.has_master("no_such_trial") and SpriteArt.master("no_such_trial") == null, "a trial with no look has none")
	# two masters of one creature differ from each other and from it
	var a := SpriteArt.master_image("court_of_seasons")
	var b := SpriteArt.master_image("antler_dance")
	ok(a.get_data() != b.get_data(), "the two Moss Stag masters differ")


func test_style() -> void:
	var problems := SpriteArt.style_problems().filter(func(p): return str(p).begins_with("master "))
	ok(problems.is_empty(), "every master holds to the art style: %s" % str(problems))
	ok(SpriteArt.validate().is_empty(), "and the art data is sound: %s" % str(SpriteArt.validate()))


func test_validator() -> void:
	var keep: Dictionary = SpriteArt._masters.duplicate(true)
	SpriteArt._masters["stone_lift"]["palette"]["Z"] = "#ffffff"
	ok(SpriteArt._master_problems().any(func(p): return str(p).contains("palette key 'Z'")), "a palette key the creature does not have is caught")
	SpriteArt._masters = keep.duplicate(true)
	SpriteArt._masters["stone_lift"]["palette"] = {"L": "#9bb08a", "M": "nonsense"}
	ok(SpriteArt._master_problems().any(func(p): return str(p).contains("is not a colour")), "a palette that is not a colour is caught")
	SpriteArt._masters = keep.duplicate(true)
	SpriteArt._masters["stone_lift"]["palette"] = {}
	ok(SpriteArt._master_problems().any(func(p): return str(p).contains("looks exactly like") or str(p).contains("needs a palette")), "a master that repaints nothing is caught")
	SpriteArt._masters = keep.duplicate(true)
	SpriteArt._masters["packs_road"]["marks"]["pixels"].append([0, 0, "s"])
	ok(SpriteArt._master_problems().any(func(p): return str(p).contains("outside the silhouette")), "a mark outside the creature is caught")
	SpriteArt._masters = keep.duplicate(true)
	SpriteArt._masters["stone_lift"]["base"] = "no_such_creature"
	ok(SpriteArt._master_problems().any(func(p): return str(p).contains("has no creature art")), "a master of a creature with no art is caught")
	SpriteArt._masters = keep.duplicate(true)
	SpriteArt._masters.erase("bone_duel")
	ok(SpriteArt._master_problems().any(func(p): return str(p).contains("trial bone_duel has no master look")), "a trial with no look is caught")
	SpriteArt._masters = keep.duplicate(true)
	SpriteArt._masters["no_such_trial"] = {"base": "wolf", "palette": {"W": "#ffffff"}}
	ok(SpriteArt._master_problems().any(func(p): return str(p).contains("there is no such trial")), "a look for no trial is caught")
	SpriteArt._masters = keep
	ok(SpriteArt._master_problems().is_empty(), "(restored)")


func test_panel() -> void:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.level = 12
	var panel: Control = TrialsPanel.new()
	panel.dynasty = d
	root.add_child(panel)
	await process_frame
	var frames := panel.find_children("Master", "PanelContainer", true, false)
	ok(frames.size() > 0 and frames.all(func(f): return f.find_children("*", "TextureRect", true, false).size() == 1), "each row shows a portrait (%d)" % frames.size())
	# the portrait is the master's look: the texture of the first row is the master texture of its trial
	var first: Dictionary = GameTrials.listing(d)[0]
	var tex := (frames[0].find_children("*", "TextureRect", true, false)[0] as TextureRect).texture
	ok(tex == SpriteArt.master(str(first["id"])), "and it is the master's own look, not the plain creature's")
	ok(tex != SpriteArt.creature(str(first["master_id"])), "(which it is not)")
	panel.queue_free()
	await process_frame


func test_fight() -> void:
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.level = 12
	d.trials = {"active": {"id": "ring_of_champions", "start": GameTrials.hours_now(d) - 10.0}}
	var b := GameTrials.begin_master(d)
	ok(b != null and b.enemies.size() == 1, "the master's fight begins")
	if b != null:
		var foe: Dictionary = b.enemies[0]
		ok(str(foe.get("master_of", "")) == "ring_of_champions" and str(foe["name"]) == "the Ring Champion", "the foe carries its trial, so the screen can draw its look (%s)" % str(foe.get("master_of", "")))
		ok(SpriteArt.master(str(foe["master_of"])) != null, "which has one")
	var plain := d.foe_for("ogre", 5)
	ok(not plain.has("master_of"), "a wild ogre carries none")
