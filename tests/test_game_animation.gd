## Animation: the walk and idle frames of the map's figures and creatures (ui/play/sprite_motion.gd, data in
## data/art/animation.json) and the effects of the battle's basic actions (ui/play/battle_fx.gd, data in
## data/art/effects.json). Every frame keeps the sprite's style rules; the sequences and timing come from the
## data; a still frame shows with reduced motion; idle and walk are told apart by whether something moved; every
## action and every element has an effect; the validators catch each kind of break; and a fight played through
## the battle screen with the effects on ends as the same fight played bare.
## Run: godot --headless --path . -s res://tests/test_game_animation.gd
extends SceneTree

const Scen := preload("res://tests/round_scenarios.gd")
const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const TouchHint := preload("res://ui/play/touch_hint.gd")
const SpriteArt := preload("res://ui/play/sprite_art.gd")
const SpriteMotion := preload("res://ui/play/sprite_motion.gd")
const BattleFx := preload("res://ui/play/battle_fx.gd")
const DIR := "user://test_animation/"

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
	GameDynasty.save_path = DIR + "save.json"
	UiSettings.path = DIR + "settings.cfg"
	UiSettings.scale = 1.0
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	TouchHint.finger = false
	UiSettings.set_access("reduced_motion", false)
	test_frames_follow_the_style()
	test_frames_differ()
	test_sequences_and_timing()
	test_reduced_motion_and_selection()
	test_frame_textures()
	test_effects()
	test_validators()
	await test_events_unchanged()
	UiSettings.set_access("reduced_motion", false)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
	print("animation tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- the frames

func test_frames_follow_the_style() -> void:
	SpriteArt.reset()
	var problems := SpriteArt.frame_problems()
	for p in problems.slice(0, 10):
		print("  ", p)
	ok(problems.is_empty(), "every frame of every class figure (in every race) and creature keeps the style rules (%d problems)" % problems.size())
	ok(SpriteArt.style_problems().is_empty(), "the style checks as a whole, frames included, pass")
	for id in ["warrior", "mage", "rogue"]:
		var img := SpriteArt.hero_image("human", id, Color("#cc3333"))
		for f in SpriteMotion.images(img, "figure", id).values():
			ok((f as Image).get_size() == img.get_size(), "%s: a frame keeps the figure's size" % id)


func test_frames_differ() -> void:
	var moving := 0
	var total := 0
	for id in GameData.classes:
		if not SpriteArt.has_class(str(id)):
			continue
		var img := SpriteArt.hero_image("human", str(id), Color("#cc3333"))
		var set := SpriteMotion.images(img, "figure", str(id))
		total += 1
		ok(set["squash"].get_data() != img.get_data(), "%s breathes: its squash frame differs" % id)
		ok(set["lift_a"].get_data() != set["lift_b"].get_data(), "%s steps: its two lifted frames differ" % id)
	for c in GameData.creatures:
		var id := str(c["id"])
		if not SpriteArt.has_creature(id):
			continue
		var img := SpriteArt.creature_frames(id)
		ok(img.has("base") and img.has("squash") and img.has("lift_a") and img.has("lift_b"), "%s has every frame name" % id)
		if img["squash"] != img["base"]:
			moving += 1
	ok(total > 10, "figures were checked")
	ok(moving >= 25, "most creatures breathe or beat (%d)" % moving)
	var slime := SpriteMotion.images(SpriteArt._paint(SpriteArt._creatures["slime"], {}), "creature", "slime")
	ok(slime["lift_a"] == slime["base"], "a slime has no feet to lift (its data says it is a blob)")
	var wolf := SpriteMotion.images(SpriteArt._paint(SpriteArt._creatures["wolf"], {}), "creature", "wolf")
	ok(wolf["lift_a"].get_data() != wolf["base"].get_data(), "a wolf lifts feet")


func test_frame_textures() -> void:
	var a := SpriteArt.hero_frames("human", "warrior", Color("#cc3333"))
	var b := SpriteArt.hero_frames("human", "warrior", Color("#cc3333"))
	ok(a.size() == SpriteMotion.NAMES.size() and a == b, "the frames of a figure are made once and kept")
	ok(a["base"] == SpriteArt.hero("human", "warrior", Color("#cc3333")), "the base frame is the figure itself")
	ok(a["squash"].get_size() == a["base"].get_size(), "a frame texture has the figure's size")
	ok(SpriteArt.hero_frames("human", "nothing", Color.WHITE).is_empty(), "a class with no figure has no frames")
	ok(SpriteArt.creature_frames("nothing").is_empty(), "a creature with no art has no frames")


# ---------------------------------------------------------------- the choice

func test_sequences_and_timing() -> void:
	SpriteMotion.reset()
	var walk := SpriteMotion.sequence("walk")
	var idle := SpriteMotion.sequence("idle")
	ok(walk.size() == 4 and idle.size() == 2, "a four-frame walk and a two-frame idle, from the data")
	var wt := SpriteMotion.timing("walk_frame")
	var seen: Array = []
	for i in 4:
		seen.append(SpriteMotion.frame_name("k", true, wt * (float(i) + 0.5)))
	ok(seen == walk, "walking steps through the data's sequence in order: %s" % str(seen))
	ok(SpriteMotion.frame_name("k", true, wt * 4.5) == walk[0], "the walk loops")
	var it := SpriteMotion.timing("idle_frame")
	var names := {}
	for i in 8:
		names[SpriteMotion.frame_name("k", false, it * float(i) * 0.5)] = true
	ok(names.size() == 2, "idle alternates its two frames")
	var offsets := {}
	for k in ["a", "b", "c", "d", "e", "f"]:
		offsets[SpriteMotion.frame_name("c" + k, false, 0.1)] = true
	ok(SpriteMotion.frame_name("a", false, 0.3) == SpriteMotion.frame_name("a", false, 0.3), "a key's idle is the same each time asked")
	ok(offsets.size() == 2, "different things breathe out of step")


func test_reduced_motion_and_selection() -> void:
	var frames := SpriteArt.hero_frames("human", "warrior", Color("#cc3333"))
	var moved := SpriteMotion.pick(frames, "x", true, SpriteMotion.timing("walk_frame") * 0.5)
	ok(moved == frames["lift_a"], "a mover shows a walk frame")
	var still := SpriteMotion.pick(frames, "x", false, 0.0)
	ok(still == frames["base"] or still == frames["squash"], "something still shows an idle frame")
	ok(SpriteMotion.still_moving(10.0, 10.1) and not SpriteMotion.still_moving(10.0, 11.0), "moving lasts a moment after the last move")
	UiSettings.set_access("reduced_motion", true)
	var all_base := true
	for i in 20:
		all_base = all_base and SpriteMotion.pick(frames, "x", i % 2 == 0, float(i) * 0.07) == frames["base"]
	ok(all_base, "with reduced motion every frame is the plain sprite")
	ok(BattleFx.play(Control.new(), "attack", "", Vector2.ZERO, 3.0) == null, "with reduced motion no effect is shown")
	UiSettings.set_access("reduced_motion", false)


# ---------------------------------------------------------------- the effects

func test_effects() -> void:
	BattleFx.reset()
	ok(BattleFx.validate().is_empty(), "effects.json is sound: %s" % str(BattleFx.validate().slice(0, 3)))
	for action in ["attack", "hit", "cast", "bolt", "burst", "guard", "flee", "defeat", "heal", "dodge"]:
		var id := BattleFx.effect_id(action, "fire")
		ok(id != "" and BattleFx.frame_count(id) >= 2, "the action %s has an effect of two frames or more" % action)
		ok(BattleFx.textures(id, BattleFx.tint_of(action, "fire")).size() == BattleFx.frame_count(id), "%s: its frames are made" % action)
	for el in BattleFx.element_ids() + [""]:
		for action in ["bolt", "burst", "cast"]:
			var id := BattleFx.effect_id(action, str(el))
			ok(id != "" and not BattleFx.images(id, Color.WHITE).is_empty(), "%s for element '%s' exists" % [action, el])
		if el != "":
			ok(BattleFx.tint_of("bolt", str(el)).to_html(false) == GameCombat.element_color(str(el)).trim_prefix("#"), "the %s bolt is in the element's colour" % el)
	ok(BattleFx.effect_id("bolt", "fire") != BattleFx.effect_id("bolt", "frost"), "elements have bolts of their own")
	ok(BattleFx.element_ids().size() >= 7, "every element of elements.json is covered")
	var holder := Control.new()
	root.add_child(holder)
	var node := BattleFx.play(holder, "attack", "", Vector2(50, 50), 3.0)
	ok(node != null and node.get_parent() == holder and node.size == Vector2(BattleFx.size_of("slash")) * 3.0, "an effect is drawn at the figures' pixel size")
	var bolt := BattleFx.play(holder, "bolt", "fire", Vector2(0, 0), 3.0, Vector2(100, 0))
	ok(bolt != null, "a bolt flies to its target")
	holder.queue_free()


func test_validators() -> void:
	var good := SpriteMotion.data().duplicate(true)
	ok(SpriteMotion.validate().is_empty(), "animation.json is sound: %s" % str(SpriteMotion.validate().slice(0, 3)))
	var breaks := {
		"a frame name that does not exist": func(d): d["sequences"]["walk"] = ["lift_a", "stride"],
		"a one-frame idle": func(d): d["sequences"]["idle"] = ["base"],
		"a missing timing": func(d): d["timing"].erase("walk_frame"),
		"a shape with no squash": func(d): d["shapes"]["walker"]["squash"] = "sideways",
		"a creature of an unknown shape": func(d): d["creatures"]["wolf"] = {"shape": "swimmer"},
		"a creature that does not exist": func(d): d["creatures"]["unicorn_x"] = {"shape": "blob"},
		"a lift of too many rows": func(d): d["figure"]["lift_rows"] = 40,
		"a class that does not exist": func(d): d["classes"]["bard_x"] = {"lift_rows": 3},
	}
	for what in breaks:
		var d: Dictionary = good.duplicate(true)
		breaks[what].call(d)
		SpriteMotion._data = d
		SpriteMotion._loaded = true
		ok(not SpriteMotion.validate().is_empty(), "animation.json: %s is caught" % what)
	SpriteMotion.reset()
	var fx := BattleFx.data().duplicate(true)
	var fbreaks := {
		"an unknown shape": func(d): d["effects"]["slash"]["shape"] = "spiral",
		"one frame": func(d): d["effects"]["slash"]["frames"] = 1,
		"an action with no effect": func(d): d["actions"].erase("guard"),
		"an action naming a missing effect": func(d): d["actions"]["hit"]["effect"] = "nothing",
		"a bad tint": func(d): d["actions"]["hit"]["tint"] = "blue-ish",
		"an element with no bolt": func(d): d["elements"].erase("frost"),
		"no row for no element": func(d): d["elements"].erase("none"),
		"a bad size": func(d): d["effects"]["spark"]["size"] = [1, 1],
		"a bad place": func(d): d["actions"]["hit"]["at"] = "nowhere",
	}
	for what in fbreaks:
		var d: Dictionary = fx.duplicate(true)
		fbreaks[what].call(d)
		BattleFx._data = d
		BattleFx._loaded = true
		ok(not BattleFx.validate().is_empty(), "effects.json: %s is caught" % what)
	BattleFx.reset()


# ---------------------------------------------------------------- the battle's events

func _end(d: GameDynasty, b: GameBattle) -> Dictionary:
	var state := Scen.state_of(b)
	state.erase("rng")
	var flat := func(v: Variant) -> String: return JSON.stringify(JSON.parse_string(JSON.stringify(v)))
	return {"log": flat.call(b.log), "events": flat.call(b.events), "state": flat.call(state), "rng": str(b.rng.state), "dynasty": flat.call(Scen.drop_sex(d.to_dict()))}


func test_events_unchanged() -> void:
	root.size = Vector2i(1280, 720)
	await _frames(2)
	app = GameApp.new()
	root.add_child(app)
	await _frames(2)
	app.new_game("Tess", "warrior", "faetouched", 77, "human")
	for c in [[6, "paladin", 2, "hunt"], [9, "mage", 1, "legend"]]:
		var tag := "%d %s x%d %s" % c
		var d := Scen.make(c[0], c[1], c[2], c[3])
		var b := d.battle
		var guard := 0
		while not b.is_over() and guard < Scen.GUARD:
			guard += 1
			GameTactics.auto_turn(b)
		d.finish_battle()
		var bare := _end(d, b)
		var d2 := Scen.make(c[0], c[1], c[2], c[3])
		app.dynasty = d2
		d2.auto_battle = false
		app.show_state()
		await _frames(4)
		var bv: Control = app.current
		var b2 := d2.battle
		guard = 0
		while not b2.is_over() and guard < Scen.GUARD:
			guard += 1
			await bv._do(func(): GameTactics.auto_turn(b2))
		await _frames(2)
		d2.finish_battle()
		var shown := _end(d2, b2)
		ok(shown["events"] == bare["events"], "%s: the same battle events with the animation layer on" % tag)
		ok(shown["log"] == bare["log"] and shown["state"] == bare["state"] and shown["rng"] == bare["rng"] and shown["dynasty"] == bare["dynasty"], "%s: the same log, end, dice and dynasty" % tag)
