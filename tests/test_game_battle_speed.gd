## The battle screen's speed and Skip (ui/play/battle_speed.gd, data/ui/battle_ui.json, UiSettings.battle_speed / battle_skip):
## the speed is 1x, 2x or 4x and is kept in settings.cfg (never the save), a damaged value reads as 1x; it divides the screen's
## animation and wait times and shrinks the hit-stop and the shake (none at 4x); Skip shows each round as its result and the log
## only; reduced motion shortens the waits; the controls and their keys work; and above all that a seeded fight ends with the
## same result, log, event list, dice and dynasty at 1x, at 4x and with Skip on, and that the faster ones really take less time.
## Run: godot --headless --path . -s res://tests/test_game_battle_speed.gd
extends SceneTree

const Scen := preload("res://tests/round_scenarios.gd")
const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const TouchHint := preload("res://ui/play/touch_hint.gd")
const HitFx := preload("res://ui/play/hit_fx.gd")
const BattleSpeed := preload("res://ui/play/battle_speed.gd")
const DIR := "user://test_battle_speed/"

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
	test_data()
	test_settings()
	test_times()
	test_hit_fx_shrinks()
	test_reduced_motion()
	await test_same_fight()
	await test_controls()
	await test_skip_view()
	BattleSpeed.active = false
	UiSettings.set_battle_speed(1)
	UiSettings.set_battle_skip(false)
	UiSettings.set_access("reduced_motion", false)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
	print("battle speed tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func test_data() -> void:
	BattleSpeed.reset()
	ok(BattleSpeed.validate().is_empty(), "battle_ui.json passes its own check %s" % str(BattleSpeed.validate()))
	ok(BattleSpeed.steps() == [1, 2, 4], "the speeds are 1x, 2x and 4x")
	# The check catches a broken file.
	var good := BattleSpeed._data.duplicate(true)
	BattleSpeed._data["speed"]["steps"] = [2, 4]
	ok(not BattleSpeed.validate().is_empty(), "steps that do not start at 1x are refused")
	BattleSpeed._data = good.duplicate(true)
	BattleSpeed._data["speed"]["fx_scale"]["4"] = 3.0
	ok(not BattleSpeed.validate().is_empty(), "a shake that grows with speed is refused")
	BattleSpeed._data = good.duplicate(true)
	BattleSpeed._data["speed"]["keys"]["speed"] = BattleSpeed._data["speed"]["keys"]["skip"]
	ok(not BattleSpeed.validate().is_empty(), "two controls on one key are refused")
	BattleSpeed._data = good.duplicate(true)
	BattleSpeed._data["speed"]["waits"]["event"] = 0.0
	ok(not BattleSpeed.validate().is_empty(), "a wait of nothing is refused")
	BattleSpeed.reset()
	ok(BattleSpeed.validate().is_empty(), "and the data is back to sound")


func test_settings() -> void:
	DirAccess.remove_absolute(UiSettings.path)
	ok(UiSettings.battle_speed() == 1 and not UiSettings.battle_skip(), "with no file: 1x and Skip off")
	BattleSpeed.set_speed(4)
	UiSettings.set_battle_skip(true)
	ok(UiSettings.battle_speed() == 4 and UiSettings.battle_skip(), "the speed and Skip are kept in settings.cfg")
	var cf := ConfigFile.new()
	cf.load(UiSettings.path)
	ok(cf.get_value("ui", "battle_speed", 0) == 4 and cf.get_value("ui", "battle_skip", false) == true, "under the ui section")
	ok(not FileAccess.file_exists(GameDynasty.save_path), "and never the save")
	BattleSpeed.set_speed(3)
	ok(BattleSpeed.chosen() == 1, "a speed that is not a step is 1x")
	UiSettings.store("battle_speed", "fast")
	UiSettings.store("battle_skip", 7)
	ok(UiSettings.battle_speed() == 1 and not UiSettings.battle_skip(), "damaged values read as 1x and off")
	UiSettings.store("battle_speed", 99)
	ok(BattleSpeed.chosen() == 1, "an unlisted speed in the file reads as 1x")
	BattleSpeed.set_speed(1)
	var seen: Array = []
	for i in 4:
		seen.append(BattleSpeed.cycle())
	ok(seen == [2, 4, 1, 2], "the button goes 1x, 2x, 4x and round again: %s" % str(seen))
	BattleSpeed.set_speed(1)
	UiSettings.set_battle_skip(false)


func test_times() -> void:
	BattleSpeed.active = false
	BattleSpeed.set_speed(4)
	UiSettings.set_battle_skip(true)
	ok(BattleSpeed.mult() == 1.0 and not BattleSpeed.skip() and BattleSpeed.time(0.5) == 0.5 and BattleSpeed.pause(0.5) == 0.5, "outside a battle screen nothing is sped up")
	BattleSpeed.active = true
	ok(BattleSpeed.skip() and BattleSpeed.time(0.5) == 0.0 and BattleSpeed.pause(0.5) == 0.0, "Skip: no animation and no wait")
	UiSettings.set_battle_skip(false)
	for n in [1, 2, 4]:
		BattleSpeed.set_speed(n)
		ok(is_equal_approx(BattleSpeed.time(0.8), 0.8 / n) and is_equal_approx(BattleSpeed.pause(0.4), 0.4 / n), "%dx: animations and waits take 1/%d of the time" % [n, n])
	var node := Control.new()
	root.add_child(node)
	for n in [4, 1]:
		BattleSpeed.set_speed(n)
		node.position = Vector2.ZERO
		var tw := BattleSpeed.tune(node.create_tween())
		tw.tween_property(node, "position:x", 100.0, 0.2)
		tw.pause()
		tw.custom_step(0.06)
		ok(is_equal_approx(node.position.x, 100.0 if n == 4 else 30.0), "a tuned tween runs %d times as fast (x is %s after 0.06 s)" % [n, str(node.position.x)])
		tw.kill()
	node.queue_free()
	BattleSpeed.set_speed(1)
	BattleSpeed.active = false


func test_hit_fx_shrinks() -> void:
	BattleSpeed.active = true
	var base := HitFx.num("hit_stop", "kill_seconds")
	BattleSpeed.set_speed(1)
	ok(is_equal_approx(HitFx.stop_seconds(false, false), base), "1x: the hit-stop is the data's")
	BattleSpeed.set_speed(2)
	ok(HitFx.stop_seconds(false, false) < base * 0.5 + 0.0001 and HitFx.stop_seconds(false, false) > 0.0, "2x: the hit-stop is shorter than half")
	BattleSpeed.set_speed(4)
	ok(HitFx.stop_seconds(true, false) == 0.0, "4x: no hit-stop at all")
	var holder := Control.new()
	root.add_child(holder)
	var node := Control.new()
	holder.add_child(node)
	HitFx.shake(node, 8.0, "k")
	ok(not node.has_meta("fx_shake_tween"), "4x: no shake")
	BattleSpeed.set_speed(2)
	HitFx.shake(node, 8.0, "k")
	ok(node.has_meta("fx_shake_tween"), "2x: a shake, smaller")
	ok(is_equal_approx(BattleSpeed.fx_scale(), 0.5), "the shake is half its size at 2x")
	BattleSpeed.set_speed(1)
	UiSettings.set_battle_skip(true)
	ok(BattleSpeed.fx_scale() == 0.0 and HitFx.stop_seconds(true, false) == 0.0, "Skip: no shake or hit-stop")
	UiSettings.set_battle_skip(false)
	ok(BattleSpeed.fx_scale() == 1.0, "1x: the whole shake")
	holder.queue_free()
	BattleSpeed.active = false


func test_reduced_motion() -> void:
	BattleSpeed.active = true
	BattleSpeed.set_speed(1)
	var normal := BattleSpeed.pause(0.35)
	UiSettings.set_access("reduced_motion", true)
	ok(BattleSpeed.time(0.5) == 0.0, "reduced motion: no animation time")
	ok(BattleSpeed.pause(0.35) < normal and BattleSpeed.pause(0.35) > 0.0, "reduced motion: the waits between events are shorter")
	UiSettings.set_access("reduced_motion", false)
	BattleSpeed.active = false


# ---------------------------------------------------------------- the same fight at every speed

func _flat(v: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(v)))


func _end(d: GameDynasty, b: GameBattle, events: Array) -> Dictionary:
	var state := Scen.state_of(b)
	state.erase("rng")
	return {"log": _flat(b.log), "events": _flat(events), "state": _flat(state), "rng": str(b.rng.state), "dynasty": _flat(Scen.drop_sex(d.to_dict())), "result": b.result}


func _labels(n: Node, out: Array) -> Array:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_labels(c, out)
	return out


## One scenario played through the battle screen at `speed` (skip: Skip on), every action of an auto turn, the events of each
## action gathered. Returns {end, ms, numbers (damage numbers seen), bv}.
func _screen_fight(c: Array, speed: int, skip: bool) -> Dictionary:
	BattleSpeed.set_speed(speed)
	UiSettings.set_battle_skip(skip)
	var d := Scen.make(c[0], c[1], c[2], c[3])
	app.dynasty = d
	d.auto_battle = false
	app.show_state()
	await _frames(4)
	var bv: Control = app.current
	var b := d.battle
	var events: Array = []
	var guard := 0
	var numbers := 0
	var t0 := Time.get_ticks_msec()
	while not b.is_over() and guard < Scen.GUARD:
		guard += 1
		await bv._do(func(): GameTactics.auto_turn(b))
		events.append_array(b.events.duplicate(true))
		for t in _labels(bv.arena, []):
			if t.strip_edges().is_valid_int() or t.ends_with("!") or t == "miss" or t == "block":
				numbers += 1
	var ms := Time.get_ticks_msec() - t0
	await _frames(2)
	var view_ok: bool = bv.enemy_nodes.all(func(e): return e["root"].modulate.a < 0.05 or not e["root"].visible or e["hp"].value > 0.0)
	d.finish_battle()
	return {"end": _end(d, b, events), "ms": ms, "numbers": numbers, "view_ok": view_ok}


func _bare(c: Array) -> Dictionary:
	var d := Scen.make(c[0], c[1], c[2], c[3])
	var b := d.battle
	var events: Array = []
	var guard := 0
	while not b.is_over() and guard < Scen.GUARD:
		guard += 1
		GameTactics.auto_turn(b)
		events.append_array(b.events.duplicate(true))
	d.finish_battle()
	return _end(d, b, events)


func test_same_fight() -> void:
	root.size = Vector2i(1280, 720)
	await _frames(2)
	app = GameApp.new()
	root.add_child(app)
	await _frames(2)
	app.new_game("Tess", "warrior", "faetouched", 77, "human")
	for c in [[6, "paladin", 2, "hunt"], [9, "mage", 1, "legend"]]:
		var tag := "%d %s x%d %s" % [c[0], c[1], c[2], c[3]]
		var bare := _bare(c)
		var slow: Dictionary = await _screen_fight(c, 1, false)
		var fast: Dictionary = await _screen_fight(c, 4, false)
		var skipped: Dictionary = await _screen_fight(c, 1, true)
		var both: Dictionary = await _screen_fight(c, 4, true)
		for pair in [["1x", slow], ["4x", fast], ["skip", skipped], ["skip at 4x", both]]:
			var e: Dictionary = pair[1]["end"]
			ok(e["result"] == bare["result"] and e["events"] == bare["events"], "%s at %s: the same result and event list as the bare fight" % [tag, pair[0]])
			ok(e["log"] == bare["log"] and e["state"] == bare["state"] and e["rng"] == bare["rng"] and e["dynasty"] == bare["dynasty"], "%s at %s: the same log, end, dice and dynasty" % [tag, pair[0]])
		ok(slow["end"] == fast["end"] and slow["end"] == skipped["end"], "%s: 1x, 4x and Skip end exactly alike" % tag)
		ok(int(fast["ms"]) < int(slow["ms"]) * 0.6, "%s: 4x takes much less time than 1x (%d ms against %d)" % [tag, fast["ms"], slow["ms"]])
		ok(int(skipped["ms"]) < int(fast["ms"]) + 50 and int(skipped["ms"]) < int(slow["ms"]) * 0.3, "%s: Skip takes the least (%d ms)" % [tag, skipped["ms"]])
		ok(int(slow["numbers"]) > 0 and int(fast["numbers"]) > 0, "%s: numbers show at 1x and 4x" % tag)
		ok(int(skipped["numbers"]) == 0, "%s: Skip floats no numbers, only the result and the log" % tag)
		ok(skipped["view_ok"], "%s: with Skip the fallen are off the field" % tag)
	UiSettings.set_battle_skip(false)
	BattleSpeed.set_speed(1)


func test_controls() -> void:
	BattleSpeed.set_speed(1)
	UiSettings.set_battle_skip(false)
	var d := Scen.make(6, "paladin", 2, "hunt")
	app.dynasty = d
	d.auto_battle = false
	app.show_state()
	await _frames(4)
	var bv: Control = app.current
	ok(BattleSpeed.active, "a battle screen turns the speed on")
	ok(bv.speed_button != null and bv.skip_button != null and bv.speed_button.is_inside_tree(), "the controls are in the top bar")
	ok(bv.speed_button.text == "Speed 1x" and bv.skip_button.text == "Skip: OFF", "they say what is set: %s, %s" % [bv.speed_button.text, bv.skip_button.text])
	bv.speed_button.pressed.emit()
	ok(UiSettings.battle_speed() == 2 and bv.speed_button.text == "Speed 2x", "the speed button goes to 2x and is remembered")
	bv.skip_button.pressed.emit()
	ok(UiSettings.battle_skip() and bv.skip_button.text == "Skip: ON", "the skip button turns Skip on")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = BattleSpeed.key("skip")
	bv._unhandled_input(key)
	ok(not UiSettings.battle_skip(), "the skip key turns it off again")
	var key2 := InputEventKey.new()
	key2.pressed = true
	key2.keycode = BattleSpeed.key("speed")
	bv._unhandled_input(key2)
	ok(UiSettings.battle_speed() == 4 and bv.speed_button.text == "Speed 4x", "the speed key goes on to 4x")
	var other := InputEventKey.new()
	other.pressed = true
	other.keycode = KEY_Q
	bv._unhandled_input(other)
	ok(UiSettings.battle_speed() == 4 and not UiSettings.battle_skip(), "another key does nothing")
	# Auto-battle's fast-forward.
	bv.set_auto(true)
	await _frames(2)
	var ff: Button = bv.forward_button
	ok(ff != null and is_instance_valid(ff) and ff.is_inside_tree(), "auto-battle has a fast-forward")
	BattleSpeed.set_speed(1)
	bv._show_speed()
	ff.pressed.emit()
	ok(UiSettings.battle_speed() == 4, "it goes to the top speed")
	ff.pressed.emit()
	ok(UiSettings.battle_speed() == 1, "and back to 1x")
	# Compact windows get the short words.
	var wide: float = bv.speed_button.custom_minimum_size.x
	ok(wide >= float(BattleSpeed.speed_data()["widths"]["speed_compact"]), "the speed button is wide enough for its words")
	# Leaving the screen ends it.
	d.battle = null
	app.dynasty = GameDynasty.new_game(5, "Ann", "mage", "faetouched", "elf")
	app.show_state()
	await _frames(3)
	ok(not BattleSpeed.active, "leaving the battle screen leaves the world's own motion alone")
	BattleSpeed.set_speed(1)


## Skip, mid-way: a round the player skips while the screen is playing it settles the rest at once.
func test_skip_view() -> void:
	var d := Scen.make(6, "paladin", 2, "hunt")
	app.dynasty = d
	d.auto_battle = false
	app.show_state()
	await _frames(4)
	var bv: Control = app.current
	var b := d.battle
	BattleSpeed.set_speed(1)
	UiSettings.set_battle_skip(false)
	var t0 := Time.get_ticks_msec()
	bv._do(func(): GameTactics.auto_turn(b))   # not awaited: it plays on while the player presses Skip
	await create_timer(0.1).timeout
	UiSettings.set_battle_skip(true)
	var guard := 0
	while bv.busy and guard < 400:
		guard += 1
		await process_frame
	ok(not bv.busy, "a round skipped half-way finishes")
	ok(Time.get_ticks_msec() - t0 < 1800, "and does not wait out the rest of its animations")
	for i in b.enemies.size():
		var e: Dictionary = bv.enemy_nodes[i]
		ok(is_equal_approx(float(e["hp"].value), float(maxi(0, b.enemies[i]["hp"]))), "foe %d's bar shows the true health" % i)
	ok(is_equal_approx(float(bv.hero_hp.value), float(d.heir.hp)), "the hero's bar shows the true health")
	UiSettings.set_battle_skip(false)
