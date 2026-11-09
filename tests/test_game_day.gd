## Day, night and weather (roadmap item 51): the data and ways to break it; the day on the world clock (midnight to noon
## to midnight, dawn and dusk, night about two fifths of the day, the clock face); the clock feeding it and holding it
## still; saving the seconds (and old and damaged saves); the look of the world in each weather (light never above the
## sun, fog, rain and snow, tint); weather shortening what creatures see; the spawn tables changing by night and weather;
## and that none of it draws a die or moves an autopilot life.
## Run: godot --headless --path . -s res://tests/test_game_day.gd
extends SceneTree

const Scen := preload("res://tests/round_scenarios.gd")

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
	test_cycle()
	test_clock()
	test_saving()
	test_look()
	test_creatures()
	test_spawn()
	test_pure()
	print("day tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh() -> GameDynasty:
	return GameDynasty.new_game(5, "Tess", "warrior", "faetouched", "human")


## A dynasty whose clock stands at a phase of a day (0 midnight, 0.5 noon).
func _at(phase: float, day: int = 0) -> GameDynasty:
	var d := _fresh()
	var length := float(GameDay.setting("day_seconds"))
	d.world_seconds = (fposmod(phase - float(GameDay.setting("start_phase")), 1.0) + float(day)) * length
	return d


# ---------------------------------------------------------------- data

func test_data() -> void:
	ok(GameDay.validate().is_empty(), "the data is sound: %s" % str(GameDay.validate()))
	var saved: Dictionary = GameDay.data().duplicate(true)
	GameDay.data()["weather_look"].erase("fog")
	ok(not GameDay.validate().is_empty(), "a weather with no look is found")
	GameDay._cache = saved.duplicate(true)
	GameDay.data()["weather_look"]["hail"] = {"light": 1.0, "fog": 0.0, "precip": "none", "sight": 1.0}
	ok(not GameDay.validate().is_empty(), "a look for a weather that does not exist is found")
	GameDay._cache = saved.duplicate(true)
	GameDay.data()["weather_look"]["rain"]["precip"] = "frogs"
	ok(not GameDay.validate().is_empty(), "an unknown kind of precipitation is found")
	GameDay._cache = saved.duplicate(true)
	GameDay.data()["weather_look"]["storm"]["sight"] = 0.0
	ok(not GameDay.validate().is_empty(), "weather that blinds creatures completely is found")
	GameDay._cache = saved.duplicate(true)
	GameDay.data()["settings"]["twilight"] = 0.0
	ok(not GameDay.validate().is_empty(), "a day with no twilight (it would divide by it) is found")
	GameDay._cache = saved.duplicate(true)
	GameDay.data()["settings"]["day_seconds"] = 1.0
	ok(not GameDay.validate().is_empty(), "a day of one second is found")
	GameDay._cache = saved.duplicate(true)
	GameDay.data()["tints"]["night"] = [0.1, 2.0, 0.3]
	ok(not GameDay.validate().is_empty(), "a colour outside 0 to 1 is found")
	GameDay._cache = saved.duplicate(true)
	GameDay.data()["text"].erase("dusk")
	ok(not GameDay.validate().is_empty(), "a missing line of text is found")
	GameDay._cache = {}
	ok(GameDay.validate().is_empty(), "(and the data is whole again after)")


# ---------------------------------------------------------------- the day

func test_cycle() -> void:
	var fresh := _fresh()
	ok(GameDay.seconds(fresh) == 0.0 and GameDay.day_number(fresh) == 1 and not GameDay.is_night(fresh) and GameDay.phase_name(fresh) == "day", "a new world starts on its first morning, in daylight")
	ok(GameDay.phase_name(_at(0.0)) == "night" and GameDay.is_night(_at(0.0)) and GameDay.sun_light(0.0) == 0.0, "midnight is night and dark")
	ok(GameDay.phase_name(_at(0.25)) == "dawn" and is_equal_approx(GameDay.sun_light(0.25), 0.5), "a quarter in is dawn, half lit")
	ok(GameDay.phase_name(_at(0.5)) == "day" and GameDay.sun_light(0.5) == 1.0 and not GameDay.is_night(_at(0.5)), "noon is day, fully lit")
	ok(GameDay.phase_name(_at(0.75)) == "dusk" and is_equal_approx(GameDay.sun_light(0.75), 0.5), "three quarters in is dusk, half lit")
	ok(GameDay.phase_name(_at(0.95)) == "night" and GameDay.is_night(_at(0.95)), "and late evening is night again")
	var rising := true
	var last := -1.0
	for i in range(0, 51):
		var l := GameDay.sun_light(float(i) / 100.0)
		if l < last:
			rising = false
		last = l
	ok(rising, "the light only rises from midnight to noon")
	var symmetric := true
	for i in range(0, 50):
		if not is_equal_approx(GameDay.sun_light(float(i) / 100.0), GameDay.sun_light(1.0 - float(i) / 100.0)):
			symmetric = false
	ok(symmetric, "and falls the same way back")
	var night := 0
	var seen := {}
	for i in 1000:
		var d := _at(float(i) / 1000.0)
		seen[GameDay.phase_name(d)] = true
		if GameDay.is_night(d):
			night += 1
	ok(seen.size() == 4 and night > 450 and night < 520, "over a day all four phases come and about half of it is night, the dark and the dim of it (%d of 1000)" % night)
	var d1 := _at(0.1)
	var d2 := _at(0.1, 1)
	ok(GameDay.day_number(d2) == GameDay.day_number(d1) + 1 and is_equal_approx(GameDay.phase(d1), GameDay.phase(d2)), "a day later is the next day at the same hour")
	ok(GameDay.time_text(_at(0.5)) == "Day 1, 12:00 (Day)" or GameDay.time_text(_at(0.5)).contains("12:00"), "the clock face reads noon: %s" % GameDay.time_text(_at(0.5)))
	ok(GameDay.time_text(_at(0.0, 2)).contains("00:00") and GameDay.time_text(_at(0.0, 2)).contains("(Night)"), "and midnight of a later day: %s" % GameDay.time_text(_at(0.0, 2)))
	ok(is_equal_approx(GameDay.hour(_at(0.25)), 6.0), "a quarter in is six o'clock")


# ---------------------------------------------------------------- the clock

func test_clock() -> void:
	var d := _fresh()
	GameClock.feed(d, 30.0)
	ok(is_equal_approx(d.world_seconds, 30.0), "the world clock feeds the day: 30 seconds fed is 30 seconds of day")
	GameClock.feed(d, 0.0)
	GameClock.feed(d, -5.0)
	ok(is_equal_approx(d.world_seconds, 30.0), "nothing fed, no time (and none runs backwards)")
	var before := d.world_seconds
	d.pending_event = {"id": "x"}
	GameClock.feed(d, 60.0)
	ok(d.world_seconds == before, "the day holds still while an event waits for an answer")
	d.pending_event = {}
	d.state = "succession"
	GameClock.feed(d, 60.0)
	ok(d.world_seconds == before, "and while the line is choosing an heir")
	d.state = "life"
	var fighting: GameDynasty = Scen.make(4, "warrior", 1, "hunt")
	GameClock.feed(fighting, 60.0)
	ok(fighting.battle != null and fighting.world_seconds == 0.0, "and in a fight")
	GameClock.feed(d, float(GameDay.setting("day_seconds")))
	ok(GameDay.day_number(d) == 2, "a whole day of seconds later it is the next day (day %d)" % GameDay.day_number(d))
	var p1 := GameDay.phase(d)
	GameClock.feed(d, float(GameDay.setting("day_seconds")))
	ok(is_equal_approx(GameDay.phase(d), p1) or absf(GameDay.phase(d) - p1) > 0.999, "and another whole day brings the same hour round")
	var a := _fresh()
	var b := _fresh()
	for i in 20:
		GameClock.feed(a, 7.5)
	GameClock.feed(b, 150.0)
	ok(is_equal_approx(a.world_seconds, b.world_seconds) and GameDay.look(a) == GameDay.look(b), "the same seconds in small or large feeds are the same time")


# ---------------------------------------------------------------- saving

func test_saving() -> void:
	var d := _fresh()
	ok(not d.to_dict().has("world_seconds"), "a world whose clock has not run saves no 'world_seconds' key")
	GameClock.feed(d, 42.5)
	var saved := d.to_dict()
	ok(saved.has("world_seconds") and is_equal_approx(float(saved["world_seconds"]), 42.5), "once it has run the seconds are saved")
	var json := JSON.parse_string(JSON.stringify(saved)) as Dictionary
	var loaded := GameDynasty.from_dict(json)
	ok(is_equal_approx(loaded.world_seconds, 42.5) and GameDay.time_text(loaded) == GameDay.time_text(d), "and come back through JSON the same")
	var old := json.duplicate(true)
	old.erase("world_seconds")
	ok(GameDynasty.from_dict(old).world_seconds == 0.0, "an old save with no seconds loads at the first morning")
	for junk in [-5, "noon", [], null, {"a": 1}, true, NAN, INF, -INF]:
		var damaged := json.duplicate(true)
		damaged["world_seconds"] = junk
		ok(GameDynasty.from_dict(damaged).world_seconds == 0.0, "a damaged value (%s) loads as the first morning" % str(junk))
	var huge := json.duplicate(true)
	huge["world_seconds"] = 1.0e30
	ok(GameDynasty.from_dict(huge).world_seconds <= 1.0e9, "an absurd value is held to a sane one")


# ---------------------------------------------------------------- the look of the world

func test_look() -> void:
	var d := _at(0.5)
	d.world.weather_id = "clear"
	var clear := GameDay.look(d)
	ok(clear["phase"] == "day" and is_equal_approx(float(clear["light"]), 1.0) and float(clear["fog"]) == 0.0 and clear["precip"] == "none" and not clear["night"], "noon in clear weather is full light with no fog or rain")
	ok(clear["tint"] == [1.0, 1.0, 1.0], "and the light is white")
	var every := true
	for w in GameData.world["weather"]:
		d.world.weather_id = str(w["id"])
		var l := GameDay.look(d)
		if float(l["light"]) > float(l["sun"]) + 0.0001 or float(l["light"]) <= 0.0 or l["weather"] != w["id"]:
			every = false
	ok(every, "in every weather the light is some of the sun's, never more, and not none by day")
	d.world.weather_id = "storm"
	var storm := GameDay.look(d)
	d.world.weather_id = "fog"
	var fog := GameDay.look(d)
	ok(float(storm["light"]) < float(clear["light"]) and float(fog["fog"]) > 0.5 and storm["precip"] == "rain", "a storm darkens the day and rains; fog is thick")
	d.world.weather_id = "snow"
	ok(GameDay.look(d)["precip"] == "snow", "snow snows")
	var night := _at(0.0)
	night.world.weather_id = "clear"
	var dark := GameDay.look(night)
	ok(float(dark["light"]) == 0.0 and dark["night"] and dark["phase"] == "night" and float(dark["tint"][2]) > float(dark["tint"][0]), "midnight is dark and tinted blue")
	var dawn := _at(0.25)
	dawn.world.weather_id = "clear"
	var warm := GameDay.look(dawn)
	ok(float(warm["tint"][0]) > float(warm["tint"][2]) and float(warm["sun"]) > 0.4 and float(warm["sun"]) < 0.6, "dawn is half lit and warm")
	night.world.weather_id = "storm"
	ok(GameDay.look(night)["night"] and not GameDay.is_night(d), "weather does not make a night, and a night is a night in any weather")
	var seasoned := true
	for yr in [0.0, 0.3, 0.6, 0.9]:
		d.world.year = yr
		if GameDay.look(d)["season"] != d.world.season()["id"]:
			seasoned = false
	ok(seasoned, "the look names the world's season")


# ---------------------------------------------------------------- creatures

func test_creatures() -> void:
	var d := _at(0.5)
	d.world.weather_id = "clear"
	ok(is_equal_approx(GameDay.sight_mult(d), 1.0), "clear weather does not shorten sight")
	d.world.weather_id = "fog"
	ok(is_equal_approx(GameDay.sight_mult(d), 0.5), "fog halves it")
	var targets := [{"x": 5.0, "z": 0.0}]
	var view_fog := GameDay.view(d, targets)
	ok(view_fog["sight_mult"] == 0.5 and view_fog["night"] == false and view_fog.has("walkable") and view_fog["targets"] == targets, "the view gives behaviour the targets, the night and the weather's sight")
	d.world.weather_id = "clear"
	var view_clear := GameDay.view(d, targets)
	var wolf := [GameBehaviour.new_agent(1, "wolf", 0.0, 0.0)]
	var clear_step := GameBehaviour.step_all(wolf, view_clear, 7, 0)
	var fog_step := GameBehaviour.step_all(wolf, view_fog, 7, 0)
	ok(clear_step[0]["mode"] == "chase", "by day in clear weather a wolf sees a target 5 tiles off (its sight is 6) and hunts it")
	ok(fog_step[0]["mode"] != "chase", "in fog its sight is 3 and it does not")
	var night := _at(0.0)
	night.world.weather_id = "fog"
	var night_view := GameDay.view(night, targets)
	ok(night_view["night"] == true and GameBehaviour.step_all(wolf, night_view, 7, 0)[0]["mode"] == "chase", "at night even fog does not hide it (the wolf sees 18 by night, 9 in fog)")
	var plain := view_clear.duplicate()
	plain.erase("sight_mult")
	ok(GameBehaviour.step_all(wolf, plain, 7, 0) == clear_step, "a view with no weather in it plays exactly as before")
	plain["sight_mult"] = 1.0
	ok(GameBehaviour.step_all(wolf, plain, 7, 0) == clear_step, "and so does one that says 1")


# ---------------------------------------------------------------- spawn tables

func _forest(d: GameDynasty) -> Vector2i:
	for x in range(0, 640, 7):
		for z in range(0, 640, 7):
			var t := GameWorldGen.tile(d, x, z)
			if str(t["biome"]) == "forest" and not t["water"] and not GameWorldGen.in_anchor_ground(x, z):
				return Vector2i(x, z)
	return Vector2i(-1, -1)


func _weight(table: Array, id: String) -> float:
	for e in table:
		if e["id"] == id:
			return float(e["weight"])
	return 0.0


func test_spawn() -> void:
	var day := _at(0.5)
	day.world.weather_id = "clear"
	var f := _forest(day)
	ok(f.x >= 0, "(there is forest to find)")
	var night := _at(0.0)
	night.world.weather_id = "clear"
	var ctx_day := GameDay.spawn_context(day, f.x, GamePath.SURFACE, f.y)
	var ctx_night := GameDay.spawn_context(night, f.x, GamePath.SURFACE, f.y)
	ok(ctx_day["night"] == false and ctx_night["night"] == true and ctx_night["weather"] == "clear", "the spawn context carries the night, and the weather of the world")
	var by_day := GameSpawn.table(ctx_day)
	var by_night := GameSpawn.table(ctx_night)
	ok(not by_day.is_empty() and _weight(by_night, "wolf") > _weight(by_day, "wolf") and _weight(by_day, "wolf") > 0.0, "wolves are likelier in the forest by night (%.2f against %.2f by day)" % [_weight(by_night, "wolf"), _weight(by_day, "wolf")])
	var changed := false
	for w in GameData.world["weather"]:
		day.world.weather_id = str(w["id"])
		var table := GameSpawn.table(GameDay.spawn_context(day, f.x, GamePath.SURFACE, f.y))
		if JSON.stringify(table) != JSON.stringify(by_day):
			changed = true
	ok(changed, "and some weather changes what lives there")
	night.world.weather_id = "snow"
	ok(_weight(GameSpawn.table(GameDay.spawn_context(night, f.x, GamePath.SURFACE, f.y)), "wolf") > _weight(by_night, "wolf"), "wolves like snow: more of them on a snowy night")
	ok(GameDay.spawn_context(_at(0.5), f.x, 3, f.y).get("zone", "") != "" or GameDay.spawn_context(_at(0.5), f.x, 3, f.y).is_empty(), "underground a context is still given (or none in the soil)")


# ---------------------------------------------------------------- pure

func test_pure() -> void:
	var d := _at(0.3)
	var rng_before := d.rng.state
	var save_before := JSON.stringify(d.to_dict())
	for i in 20:
		GameDay.look(d)
		GameDay.view(d, [])
		GameDay.time_text(d)
		GameDay.spawn_context(d, 100, GamePath.SURFACE, 100)
	ok(d.rng.state == rng_before and JSON.stringify(d.to_dict()) == save_before, "reading the day draws no dice and changes nothing")
	var a := _at(0.3)
	var b := _at(0.3)
	ok(GameDay.look(a) == GameDay.look(b), "the same seconds give the same look")
	var life := GameDynasty.new_game(7, "Bot", "warrior", "faetouched", "human")
	for i in 200:
		if life.state != "life":
			break
		GameBot.step(life)
	ok(life.world_seconds == 0.0 and not life.to_dict().has("world_seconds"), "an autopilot life never runs the world clock")
