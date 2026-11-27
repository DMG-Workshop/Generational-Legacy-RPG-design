## What weather does in the open world (data/world/weather_effects.json, GameWeatherFx): rain brings herbs back sooner and slows fire
## creatures, snow slows the heir's walk a little and leaves footprints, fog shortens how far creatures and the heir see, storms send
## fliers home. Every effect is a multiplier that is exactly 1 in clear weather and with no weather context, and none of it can reach
## the text game: the seeded autopilot lives the same life whatever this data says. Run:
## godot --headless --path . -s res://tests/test_game_weather_effects.gd
extends SceneTree

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
	test_data()
	test_neutral()
	test_regrowth()
	test_creatures()
	test_walking()
	test_view()
	test_notes()
	test_autopilot_untouched()
	await test_screen()
	print("weather effects tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh(weather: String = "clear") -> GameDynasty:
	var d := GameDynasty.new_game(7, "Tess", "ranger", "faetouched", "human")
	d.pending_event = {}
	d.world.weather_id = weather
	return d


func test_data() -> void:
	ok(GameWeatherFx.validate().is_empty(), "the shipped data passes: %s" % str(GameWeatherFx.validate()))
	var w: Dictionary = GameWeatherFx.data()["weather"]
	w["clear"] = {"text": "x"}
	ok(not GameWeatherFx.validate().is_empty(), "an effect on clear weather is caught")
	w.erase("clear")
	w["hail"] = {"text": "x"}
	ok(not GameWeatherFx.validate().is_empty(), "a weather that does not exist is caught")
	w.erase("hail")
	w["fog"]["text"] = ""
	ok(not GameWeatherFx.validate().is_empty(), "an effect with no words for the status is caught (nothing is opaque)")
	w["fog"]["text"] = "Fog: you and the creatures see less far."
	w["rain"]["slow"]["water"] = 0.5
	ok(not GameWeatherFx.validate().is_empty(), "slowing an element no creature has is caught")
	w["rain"]["slow"].erase("water")
	w["rain"]["herb_regrow"] = 0.0
	ok(not GameWeatherFx.validate().is_empty(), "a regrowth of nothing is caught")
	w["rain"]["herb_regrow"] = 1.5
	w["rain"]["sparkle"] = 2
	ok(not GameWeatherFx.validate().is_empty(), "an effect the code does not know is caught")
	w["rain"].erase("sparkle")
	ok(GameWeatherFx.validate().is_empty(), "and mending the data clears it")


func test_neutral() -> void:
	# clear and overcast weather (and a dynasty with no weather context at all) change nothing: every multiplier is exactly 1
	for id in ["clear", "overcast"]:
		var d := _fresh(id)
		ok(GameWeatherFx.walk_mult(d) == 1.0, "%s: the walk is 1" % id)
		ok(GameWeatherFx.regrow_mult(d, 120, 130) == 1.0, "%s: regrowth is 1" % id)
		ok(GameWeatherFx.speed_by(d).is_empty(), "%s: no creature is slowed" % id)
		ok(not GameWeatherFx.shelter_fliers(d), "%s: no fliers shelter" % id)
		ok(GameWeatherFx.view_radius(d) < 0.0 and GameWeatherFx.seen_by_heir(d, Vector2.ZERO, 500.0, 500.0), "%s: the heir sees everything" % id)
		ok(not GameWeatherFx.prints_now(d), "%s: no footprints" % id)
		var v := GameWeatherFx.apply(d, {"targets": []})
		ok(float(v["sight_mult"]) == 1.0 and (v["speed_by"] as Dictionary).is_empty() and not bool(v["shelter_fliers"]), "%s: the behaviour view says nothing" % id)
		ok(GameWeatherFx.notes(d).is_empty(), "%s: the status has nothing to add by day" % id)
	var fresh := GameDynasty.new_game(3, "Tess", "warrior", "faetouched", "human")
	ok(GameWeatherFx.walk_mult(fresh) == 1.0 and GameWeatherFx.speed_by(fresh).is_empty() or fresh.world.weather_id != "clear", "a new dynasty is at ease (whatever the year's weather: only listed weathers act)")
	ok(GameWeatherFx.effects("nonesuch").is_empty(), "an unknown weather has no effects")
	# a behaviour view with no weather in it plays as before (the keys are optional)
	var a := GameBehaviour.new_agent(1, "fire_imp", 0.0, 0.0)
	var bare := GameBehaviour.step_all([a], {"targets": [{"x": 6.0, "z": 0.0}], "night": false}, 7, 1)
	var clear := GameBehaviour.step_all([a], GameWeatherFx.apply(_fresh(), {"targets": [{"x": 6.0, "z": 0.0}], "night": false}), 7, 1)
	ok(bare == clear, "a clear-weather view moves a creature exactly as a bare one does")
	# the day-cycle's own sight multiplier is the one the view carries
	for id in ["clear", "rain", "fog", "storm", "snow", "heat"]:
		ok(float(GameWeatherFx.apply(_fresh(id), {})["sight_mult"]) == GameDay.sight_mult(_fresh(id)), "%s: the view carries GameDay's sight" % id)


## A herb node and an oak node: [x, z] of each, found from the base outwards.
func _nodes(d: GameDynasty) -> Dictionary:
	var out := {}
	var b := GameBuild.base()
	for r in [0, 40, 80, 120, 160]:
		for n in GameCompanions.scan(d, Vector2(float(b["x"]) + float(r), float(b["z"]) + float(r))):
			if not out.has(str(n["material"])):
				out[str(n["material"])] = Vector2i(int(n["x"]), int(n["z"]))
		if out.has("herb") and out.has("oak"):
			break
	return out


func test_regrowth() -> void:
	var d := _fresh()
	var nodes := _nodes(d)
	ok(nodes.has("herb") and nodes.has("oak"), "the world has herbs and oaks to gather")
	var herb: Vector2i = nodes["herb"]
	var oak: Vector2i = nodes["oak"]
	var years := float(GameCompanions.setting("regrow_years"))
	d.gathered[GameCompanions.node_key(herb.x, herb.y)] = 10.0
	d.gathered[GameCompanions.node_key(oak.x, oak.y)] = 10.0
	d.world.year = 10.0 + years * 0.7   # 70% of the way to regrowing: not yet in clear weather, but in rain (1.5x: 67%)
	ok(GameCompanions.depleted(d, herb.x, herb.y) and GameCompanions.depleted(d, oak.x, oak.y), "clear: both are still bare")
	d.world.weather_id = "rain"
	ok(GameWeatherFx.regrow_mult(d, herb.x, herb.y) == 1.5, "rain: a herb patch regrows 1.5 times as fast")
	ok(not GameCompanions.depleted(d, herb.x, herb.y), "rain: the herb patch is back")
	ok(GameCompanions.depleted(d, oak.x, oak.y) and GameWeatherFx.regrow_mult(d, oak.x, oak.y) == 1.0, "rain: an oak is no quicker")
	d.world.weather_id = "storm"
	ok(GameWeatherFx.regrow_mult(d, herb.x, herb.y) == 1.25, "storm: a little quicker")
	d.world.weather_id = "snow"
	ok(GameWeatherFx.regrow_mult(d, herb.x, herb.y) == 1.0, "snow: no change")
	ok(GameCompanions.depleted(d, herb.x, herb.y), "snow: still bare")
	# the heir's Forage and a gathering companion see the same (one clock)
	d.world.weather_id = "rain"
	ok(GameForage.in_reach(d, herb.x, herb.y).any(func(n): return int(n["x"]) == herb.x and int(n["z"]) == herb.y), "rain: Forage can take the patch again")
	# nothing about it is saved
	var save := JSON.stringify(d.to_save())
	ok(not save.contains("regrow_mult") and not save.contains("herb_regrow"), "no weather effect is written into a save")


func _move(id: String, view: Dictionary, target_x: float, home: Vector2 = Vector2.ZERO) -> Dictionary:
	var a := GameBehaviour.new_agent(1, id, home.x, home.y)
	return GameBehaviour.step_all([a], view, 7, 1)[0]


func test_creatures() -> void:
	var targets := [{"x": 6.0, "z": 0.0}]
	# rain slows fire creatures (a fire imp chases; its step is 0.7 of the clear one) and leaves the rest alone
	var clear_view := GameWeatherFx.apply(_fresh("clear"), {"targets": targets, "night": false})
	var rain_view := GameWeatherFx.apply(_fresh("rain"), {"targets": targets, "night": false})
	var imp_clear := _move("fire_imp", clear_view, 6.0)
	var imp_rain := _move("fire_imp", rain_view, 6.0)
	ok(imp_clear["mode"] == "chase" and imp_rain["mode"] == "chase", "the imp chases in both")
	ok(is_equal_approx(float(imp_rain["x"]), float(imp_clear["x"]) * 0.7), "in rain the imp covers 0.7 of the ground (%s vs %s)" % [imp_rain["x"], imp_clear["x"]])
	var gob_clear := _move("goblin", clear_view, 6.0)
	var gob_rain := _move("goblin", GameWeatherFx.apply(_fresh("rain"), {"targets": [{"x": 6.0, "z": 0.0}], "night": false}), 6.0)
	ok(float(gob_rain["x"]) == float(gob_clear["x"]) and gob_rain["mode"] == gob_clear["mode"], "a goblin is not slowed by rain")
	# the table is built from the creatures' own elements
	var table := GameWeatherFx.speed_by(_fresh("rain"))
	ok(table.has("fire_imp") and table.has("drake") and table.has("ash_wyrm") and not table.has("wolf"), "rain slows exactly the fire creatures")
	for id in table:
		ok(_element(str(id)) == "fire" and float(table[id]) == 0.7, "%s is fire" % id)
	# fog: sight is halved, so the goblin 6 tiles off (sight 9) is seen in clear weather and not in fog (4.5)
	var fog_view := GameWeatherFx.apply(_fresh("fog"), {"targets": targets, "night": false})
	ok(_move("goblin", clear_view, 6.0)["mode"] == "chase" and _move("goblin", fog_view, 6.0)["mode"] != "chase", "fog: a goblin no longer sees a target at 6 tiles")
	# a storm sends fliers home: a harpy away from home heads back, and one at home stays; a ground creature carries on
	var storm_view := GameWeatherFx.apply(_fresh("storm"), {"targets": [{"x": 4.0, "z": 0.0}], "night": false})
	ok(bool(storm_view["shelter_fliers"]), "the storm view has fliers sheltering")
	var h := GameBehaviour.new_agent(1, "harpy", 3.0, 0.0)
	h["home_x"] = 0.0
	h["home_z"] = 0.0
	var moved: Dictionary = GameBehaviour.step_all([h], storm_view, 7, 1)[0]
	ok(float(moved["x"]) < 3.0 and moved["mode"] == "return" and (moved["target"] as Dictionary).is_empty(), "the harpy flies home in the storm instead of at the target")
	var calm_h: Dictionary = GameBehaviour.step_all([h], GameWeatherFx.apply(_fresh("clear"), {"targets": [{"x": 4.0, "z": 0.0}], "night": false}), 7, 1)[0]
	ok(calm_h["mode"] != "return" or float(calm_h["x"]) >= 3.0, "in clear weather it does not")
	var home := GameBehaviour.new_agent(2, "harpy", 0.0, 0.0)
	var rest: Dictionary = GameBehaviour.step_all([home], storm_view, 7, 1)[0]
	ok(rest["mode"] == "idle" and float(rest["x"]) == 0.0, "at home it waits")
	var wolf_clear := _move("wolf", GameWeatherFx.apply(_fresh("clear"), {"targets": [{"x": 3.0, "z": 0.0}]}), 3.0)
	var wolf_storm := _move("wolf", GameWeatherFx.apply(_fresh("storm"), {"targets": [{"x": 3.0, "z": 0.0}]}), 3.0)
	ok(wolf_clear["mode"] == "chase" and wolf_storm["mode"] == "chase", "a ground creature is not sheltered")


func _element(id: String) -> String:
	for c in GameData.creatures:
		if str(c["id"]) == id:
			return str(c.get("element", ""))
	return ""


func test_walking() -> void:
	var d := _fresh("snow")
	var sb := GameSandbox.start(d)
	sb.creatures.clear()
	ok(sb.step_pace() == 1.15, "snow: a step takes 15 percent longer")
	d.world.weather_id = "clear"
	ok(sb.step_pace() == 1.0, "clear: a step takes the usual time")
	d.world.weather_id = "rain"
	ok(sb.step_pace() == 1.0, "rain does not slow the heir")
	# footprints (the look only): kept in snow, capped, and cleared when it stops
	d.world.weather_id = "snow"
	sb.prints.clear()
	var moves := 0
	for i in 60:
		var dx := 1 if i % 2 == 0 else -1
		if sb.move(dx, 0)["ok"]:
			moves += 1
	ok(moves > 10 and sb.prints.size() == mini(moves, int(GameWeatherFx.setting("max_prints"))), "snow: a print for each tile left, up to the cap (%d moves, %d prints)" % [moves, sb.prints.size()])
	d.world.weather_id = "clear"
	sb.move(1, 0)
	ok(sb.prints.is_empty(), "clear: the prints are gone")
	ok(not JSON.stringify(d.to_save()).contains("prints"), "footprints are not saved")
	# every weather steps the world without a fault
	for id in ["clear", "overcast", "rain", "storm", "fog", "heat", "snow"]:
		d.world.weather_id = id
		sb.creatures.clear()
		sb.refresh()
		sb.step(3)
	ok(true, "the open world steps in every weather")


func test_view() -> void:
	var d := _fresh("fog")
	var r := GameWeatherFx.view_radius(d)
	ok(is_equal_approx(r, GameWeatherFx.setting("view_tiles") * 0.5), "fog: the heir sees half as far (%.1f tiles)" % r)
	ok(GameWeatherFx.seen_by_heir(d, Vector2(10, 10), 10.0 + r, 10.0), "a creature at the edge is seen")
	ok(not GameWeatherFx.seen_by_heir(d, Vector2(10, 10), 10.0 + r * 1.5, 10.0), "one far past it is not")
	d.world.weather_id = "storm"
	ok(GameWeatherFx.view_radius(d) > 0.0 and GameWeatherFx.view_radius(d) < GameWeatherFx.setting("view_tiles"), "a storm shortens it too")
	d.world.weather_id = "clear"
	ok(GameWeatherFx.view_radius(d) < 0.0, "clear: no veil")


func test_notes() -> void:
	for id in ["rain", "storm", "snow", "fog"]:
		var d := _fresh(id)
		d.world_seconds = 30.0   # noon
		var lines := GameWeatherFx.notes(d)
		ok(lines.size() == 1 and str(lines[0]).begins_with(str(GameData.world["weather"].filter(func(w): return w["id"] == id)[0]["name"]).split(" ")[0].capitalize().substr(0, 3)), "%s: the status says what it does (%s)" % [id, str(lines)])
	var rain := GameWeatherFx.notes(_fresh("rain"))
	ok("herbs regrow faster" in str(rain), "'Rain: herbs regrow faster'")


## The seeded autopilot never walks the open world or feeds the clock: it lives the same life whatever the night's and the weather's
## data say (the golden digests are test_round_determinism's, which must stay as they are).
func test_autopilot_untouched() -> void:
	var first := _bot_life()
	var nl: Dictionary = GameNightLife.data()
	var wx: Dictionary = GameWeatherFx.data()
	var saved_off: Array = (nl["day_only_off"] as Array).duplicate()
	var saved_adds: Dictionary = (nl["night_adds"] as Dictionary).duplicate(true)
	var saved_weather: Dictionary = (wx["weather"] as Dictionary).duplicate(true)
	nl["day_only_off"] = []
	nl["night_adds"] = {"plains": {"wraith": 50.0}}
	wx["weather"] = {"rain": {"walk": 3.0, "herb_regrow": 3.0, "text": "x"}}
	var second := _bot_life()
	nl["day_only_off"] = saved_off
	nl["night_adds"] = saved_adds
	wx["weather"] = saved_weather
	ok(first == second, "the autopilot's life does not depend on the night or the weather: %s vs %s" % [first, second])
	ok(first == _bot_life(), "and is the same each time")
	# the hunt's pool is the same function of the era and the place it always was
	ok(GameSpawn.hunt_pool(100, ["swamp"]).map(func(c): return c["id"]) == GameSpawn.wild().filter(func(c): return c["min_gen"] <= 100 and 100 <= c["max_gen"] and (c.get("biomes", []) as Array).has("swamp")).map(func(c): return c["id"]), "the hunt pool is still the plain filter")


func _bot_life() -> String:
	var d := GameDynasty.new_game(11, "Tess", "warrior", "faetouched", "human")
	GameBot.live_life(d)
	return GameReplay.fingerprint(d)


func test_screen() -> void:
	var d := _fresh("fog")
	d.world_seconds = 105.0   # night
	var scr: Control = load("res://ui/play/sandbox_screen.gd").new()
	var fake := FakeApp.new()
	fake.dynasty = d
	root.add_child(fake)
	scr.app = fake
	scr.size = Vector2(1280, 720)
	root.add_child(scr)
	await process_frame
	await process_frame
	scr.queue_redraw()
	scr.sky_layer.queue_redraw()
	scr.glow_layer.queue_redraw()
	await process_frame
	await process_frame
	ok(scr.status.text.contains("Night:") or scr.status.tooltip_text.contains("Night:"), "the status says it is night")
	ok(scr.status.tooltip_text.contains("Fog:"), "and what the fog does (tooltip: %s)" % scr.status.tooltip_text)
	d.world.weather_id = "snow"
	d.world_seconds = 30.0
	scr.sb.move(1, 0)
	scr.sb.move(0, 1)
	await process_frame
	await process_frame
	ok(not scr.sb.prints.is_empty(), "the screen shows the prints it was given")
	scr.queue_free()
	fake.queue_free()


class FakeApp extends Node:
	var dynasty: GameDynasty

	func show_state() -> void:
		pass
