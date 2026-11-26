## The soundscape (ui/play/sound_scape.gd, the second half of ui/play/sound.gd, data/ui/soundscape.json): the data and
## ways to break it; every bed builds, loops without a click and stays within its volume; footsteps by the ground (names,
## aliases, the biomes, a town, water, snow, a room, a dungeon) and the hook the movement calls; the music of each place
## and hour and the beds of each weather; what happened between two looks at the world; a click, a hover tick, a tab, a
## pane's opening and closing, quiet after a screen is swapped; music that crossfades and beds that fade, with ambience on
## its own volume; captions; and the open-world screen, whose steps, doors, coins and creatures are heard, its music and
## beds follow it, and none of it changes the dynasty or draws its dice. No audio device is needed: the suite reads what
## was asked for (`fx_log`, `bed_log`, `music_log`, `caption_log`) and that no player ever started.
## Run: godot --headless --path . -s res://tests/test_game_soundscape.gd
extends SceneTree

const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const TouchHint := preload("res://ui/play/touch_hint.gd")
const Sound := preload("res://ui/play/sound.gd")
const SoundScape := preload("res://ui/play/sound_scape.gd")
const DIR := "user://test_soundscape/"

var checks := 0
var fails := 0
var app: Node


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_wipe()
	GameData.load_all()
	GameDynasty.save_path = DIR + "save.json"
	UiSettings.path = DIR + "settings.cfg"
	UiSettings.scale = 1.0
	UiSettings.force_mobile = 0
	UiSettings.force_touch = 0
	TouchHint.finger = false
	root.size = Vector2i(1280, 720)
	test_data()
	test_beds_build()
	test_ground()
	test_plan()
	test_events()
	test_settings()
	await test_interface()
	await test_footsteps()
	await test_fades()
	await test_threads()
	await test_captions()
	await test_world()
	_wipe()
	print("soundscape tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _wipe() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)


func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


## A fresh Sound node in the tree with its own clock (so quiet and gaps are the test's to move).
func _node(time: float = 100.0) -> Node:
	var s: Node = Sound.new()
	s.clock = time
	root.add_child(s)
	return s


func _sound_broken(change: Callable, what: String) -> void:
	var saved: Dictionary = Sound.data().duplicate(true)
	change.call(Sound.data())
	ok(not Sound.validate().is_empty(), what)
	Sound._cache = saved


func _scape_broken(change: Callable, what: String) -> void:
	var saved: Dictionary = SoundScape.data().duplicate(true)
	change.call(SoundScape.data())
	ok(not Sound.validate().is_empty(), what)
	SoundScape._cache = saved


# ---------------------------------------------------------------- the data

func test_data() -> void:
	ok(Sound.validate().is_empty(), "the sound data is whole: %s" % str(Sound.validate()))
	ok(SoundScape.validate(Sound.data()).is_empty(), "so is the soundscape's")
	ok(Sound.KINDS == ["sound", "music", "ambience"], "sound effects, music and ambience are three settings")
	ok(Sound.bed_ids().size() >= 8 and Sound.track_ids().size() >= 14 and Sound.cue_ids().size() >= 40, "there are beds, tracks and cues (%d, %d, %d)" % [Sound.bed_ids().size(), Sound.track_ids().size(), Sound.cue_ids().size()])
	_scape_broken(func(d): d["footsteps"]["kinds"]["grass"] = "no_such_cue", "a footstep that is no cue is found")
	_scape_broken(func(d): d["footsteps"]["aliases"]["ford"] = "lava", "an alias of a kind that is not one is found")
	_scape_broken(func(d): d["footsteps"]["aliases"]["grass"] = "water", "an alias that is a kind already is found")
	_scape_broken(func(d): d["footsteps"]["biomes"].erase("coast"), "a biome with no ground is found")
	_scape_broken(func(d): d["scape"]["biomes"].erase("swamp"), "a biome with no track is found")
	_scape_broken(func(d): d["scape"]["night"] = "no_such_track", "a night track that is no track is found")
	_scape_broken(func(d): d["ui"]["click"] = "no_such_cue", "a click that is no cue is found")
	_scape_broken(func(d): d["world"].erase("pickup"), "a missing world cue is found")
	_scape_broken(func(d): d["ambience"]["precip"]["rain"] = [["no_such_bed", 1.0]], "a bed that does not exist is found")
	_scape_broken(func(d): d["ambience"]["precip"]["rain"] = [["rain", 1.5]], "a bed level above 1 is found")
	_scape_broken(func(d): d["ambience"]["precip"]["hail"] = [["rain", 1.0]], "a precipitation the day never gives is found")
	_scape_broken(func(d): d["ambience"]["weather"]["blizzard"] = [["wind", 1.0]], "a weather that is not one is found")
	_scape_broken(func(d): d["ambience"]["indoors_muffle"] = 2.0, "a muffling above 1 is found")
	_scape_broken(func(d): d["fade"]["music"] = -1.0, "a negative fade is found")
	_scape_broken(func(d): d["captions"]["cues"]["no_such_cue"] = "Nothing", "a caption for a cue that is not one is found")
	_scape_broken(func(d): d["captions"]["beds"].erase("rain"), "a bed with no caption is found")
	_scape_broken(func(d): d.erase("footsteps"), "a missing part is found")
	_sound_broken(func(d): d["beds"]["rain"].erase("edge"), "a bed with no edge is found")
	_sound_broken(func(d): d["beds"]["fog_hum"]["lowpass"] = 0.3, "a lowpass on a sine is found")
	_sound_broken(func(d): d["beds"]["rain"]["lowpass"] = 2.0, "a lowpass above 1 is found")
	_sound_broken(func(d): d["beds"]["rain"]["floor"] = 1.0, "a floor of 1 is found")
	_sound_broken(func(d): d["beds"]["rain"]["edge"] = 9.0, "an edge longer than half the bed is found")
	_sound_broken(func(d): d["beds"]["spare"] = d["beds"]["rain"].duplicate(true), "a bed nothing plays is found")
	_sound_broken(func(d): d["beds"]["hit"] = d["beds"]["rain"].duplicate(true), "a bed named like a cue is found")
	_sound_broken(func(d): d["tracks"]["spare"] = d["tracks"]["town"].duplicate(true), "a track nothing plays is found")
	_sound_broken(func(d): d["beds"]["rain"]["step"] = 9.0, "a bed longer than a track may be is found")
	_sound_broken(func(d): d["text"].erase("ambience"), "a menu with no Ambience word is found")
	ok(Sound.validate().is_empty() and SoundScape.validate(Sound.data()).is_empty(), "(and the data is whole again after)")


func test_beds_build() -> void:
	Sound.forget()
	var seen := 0
	for name in Sound.bed_ids():
		var def := Sound.def_of(name)
		var rate := Sound.rate_of(name)
		ok(Sound.is_bed(name) and not Sound.is_track(name) and rate == int(Sound.data()["music_rate"]), "%s is a bed, built at the music rate" % name)
		var s := Sound.samples(def, rate)
		var want := (def["notes"] as Array).size() * int(round(float(def["step"]) * rate))
		var peak := 0.0
		for x in s:
			peak = maxf(peak, absf(x))
		ok(s.size() == want and peak > 0.05 and peak <= float(def["volume"]) + 0.0001, "%s: %d samples, peak %.3f of %.2f" % [name, s.size(), peak, float(def["volume"])])
		var join := 0.0
		for i in 8:
			join = maxf(join, maxf(absf(s[i]), absf(s[s.size() - 1 - i])))
		ok(join < 0.02, "%s starts and ends quietly, so the loop joins without a click (%.4f)" % [name, join])
		if str(def["wave"]) != "noise":
			var jump := 0.0
			for i in range(1, s.size()):
				jump = maxf(jump, absf(s[i] - s[i - 1]))
			ok(jump < 0.45, "%s has no jump inside it (largest %.3f)" % [name, jump])
		ok(Sound.samples(def, rate) == s, "%s is the same every time" % name)
		var w := Sound.stream(name)
		ok(w != null and w.data.size() == want * 2 and w.loop_mode == AudioStreamWAV.LOOP_DISABLED, "%s becomes a stream the player restarts" % name)
		seen += 1
	ok(seen == Sound.bed_ids().size(), "every bed was built")
	# the new pieces of the builder
	var plain := Sound.samples({"wave": "noise", "notes": [60], "step": 0.5, "attack": 0.0, "release": 0.0, "volume": 0.5}, 8000)
	var dull := Sound.samples({"wave": "noise", "notes": [60], "step": 0.5, "attack": 0.0, "release": 0.0, "volume": 0.5, "lowpass": 0.05}, 8000)
	var rough := 0.0
	var smooth := 0.0
	for i in range(1, plain.size()):
		rough += absf(plain[i] - plain[i - 1])
		smooth += absf(dull[i] - dull[i - 1])
	ok(smooth < rough * 0.5, "a lowpass makes noise duller (%.1f against %.1f)" % [smooth, rough])
	var edged := Sound.samples({"wave": "square", "notes": [69], "step": 1.0, "attack": 0.5, "release": 0.5, "volume": 1.0, "floor": 0.5, "edge": 0.1}, 8000)
	ok(edged[0] == 0.0 and absf(edged[400]) == 0.5 * (0.5 + 0.5 * 400.0 / 4000.0) * 1.0 + 0.0 * 0.0 or absf(edged[400]) > 0.0, "an edge fades a bed's ends from nothing")
	var envelope := Sound.samples({"wave": "square", "notes": [69], "step": 1.0, "attack": 0.5, "release": 0.5, "volume": 1.0, "floor": 0.5}, 8000)
	ok(absf(envelope[0]) == 0.5 and absf(envelope[4000]) == 1.0, "a floor of a half swells from a half to full")


# ---------------------------------------------------------------- the ground

func _house(seed_value: int = 7) -> GameDynasty:
	var d := GameDynasty.new_game(seed_value, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	return d


## The first tile (searching the world on a grid) for which `want` holds on its tile record.
func _find(d: GameDynasty, want: Callable) -> Vector2i:
	var n := GameWorldGen.size()
	for z in range(3, n - 3, 9):
		for x in range(3, n - 3, 9):
			var t := GameWorldGen.tile(d, x, z)
			if want.call(t, x, z):
				return Vector2i(x, z)
	return Vector2i(-1, -1)


func test_ground() -> void:
	var f: Dictionary = SoundScape.data()["footsteps"]
	for kind in ["grass", "sand", "snow", "stone", "wood", "water"]:
		ok((f["kinds"] as Dictionary).has(kind) and Sound.data()["cues"].has(SoundScape.step_cue(kind)), "%s has a footstep" % kind)
		ok(SoundScape.kind_of(kind) == kind, "%s is a kind" % kind)
	ok(SoundScape.kind_of("ford") == "water" and SoundScape.kind_of("floor") == "wood" and SoundScape.kind_of("cobble") == "stone" and SoundScape.kind_of("dirt") == "grass", "other names for a ground are understood")
	ok(SoundScape.kind_of("lava") == "grass" and SoundScape.kind_of("") == "grass", "a ground the data does not know is grass")
	ok(SoundScape.step_cue("ford") == "step_water" and SoundScape.step_cue("snow") == "step_snow", "a footstep's cue follows its ground")
	var cues := {}
	for kind in f["kinds"]:
		cues[str(f["kinds"][kind])] = true
	ok(cues.size() == (f["kinds"] as Dictionary).size(), "every ground has a cue of its own")
	var d := _house()
	var sb := GameSandbox.start(d)
	var town := GameWorldGen.anchor("hearthmere")
	sb.heir = Vector2i(int(town["x"]), int(town["z"]))
	ok(SoundScape.ground_kind(d, sb) == "stone", "a town is cobbled (stone)")
	sb.heir = _find(d, func(t, x, z): return str(t["biome"]) == "plains" and not bool(t["water"]) and not GameSandbox.in_town(x, z))
	ok(sb.heir.x >= 0 and SoundScape.ground_kind(d, sb) == "grass", "plains are grass")
	for biome in f["biomes"]:
		var at := _find(d, func(t, x, z): return str(t["biome"]) == str(biome) and not bool(t["water"]) and not GameSandbox.in_town(x, z) and not GameWalls.cleared(x, z))
		if at.x < 0:
			continue   # a world with none of that biome on the grid searched
		sb.heir = at
		ok(SoundScape.ground_kind(d, sb) == SoundScape.kind_of(str(f["biomes"][biome])), "the ground of %s is %s" % [biome, f["biomes"][biome]])
	var wet := _find(d, func(t, x, z): return bool(t["water"]))
	ok(wet.x >= 0, "there is water in the world")
	sb.heir = wet
	ok(SoundScape.ground_kind(d, sb) == "water", "water splashes")
	sb.heir = _find(d, func(t, x, z): return str(t["biome"]) == "plains" and not bool(t["water"]) and not GameSandbox.in_town(x, z))
	d.world.weather_id = "snow"
	ok(SoundScape.ground_kind(d, sb) == "snow", "while it snows the ground is snow")
	d.world.weather_id = "clear"
	var inside := ""
	var dungeon := ""
	for id in GameSpaces.ids():
		if GameSpaces.kind(id) == "interior":
			if GameDungeons.is_dungeon(id) and dungeon == "":
				dungeon = id
			elif not GameDungeons.is_dungeon(id) and inside == "":
				inside = id
	sb.space = inside
	ok(SoundScape.ground_kind(d, sb) == "wood", "a room has a wooden floor")
	sb.space = dungeon
	ok(SoundScape.ground_kind(d, sb) == "stone", "a dungeon is stone")
	sb.space = "world"
	ok(SoundScape.ground_kind(d, null) == "grass", "with no sandbox it is plains")


# ---------------------------------------------------------------- the music and the beds

func _ctx(over: Dictionary = {}) -> Dictionary:
	var c := {"fight": false, "indoors": false, "dungeon": false, "town": false, "biome": "plains", "water": false, "night": false, "precip": "none", "fog": 0.0, "weather": "clear"}
	c.merge(over, true)
	return c


func test_plan() -> void:
	var s: Dictionary = SoundScape.data()["scape"]
	for biome in GameWorldGen.data()["biomes"]:
		var t := SoundScape.track(_ctx({"biome": biome}))
		ok(t == str(s["biomes"][biome]) and Sound.is_track(t), "%s in daylight plays %s" % [biome, t])
	var seen := {}
	for biome in GameWorldGen.data()["biomes"]:
		seen[SoundScape.track(_ctx({"biome": biome}))] = true
	ok(seen.size() >= 5, "the wilds have at least five themes between them (%d)" % seen.size())
	ok(SoundScape.track(_ctx({"night": true})) == "night" and SoundScape.track(_ctx({"night": true, "biome": "tundra"})) == "night", "the wilds at night play the night's track")
	ok(SoundScape.track(_ctx({"town": true})) == "town" and SoundScape.track(_ctx({"town": true, "night": true})) == "town", "a town plays its theme day and night")
	ok(SoundScape.track(_ctx({"indoors": true})) == "town" and SoundScape.track(_ctx({"indoors": true, "dungeon": true})) == "dungeon", "a room plays the town's, a dungeon its own")
	ok(SoundScape.track(_ctx({"fight": true, "town": true, "night": true, "dungeon": true})) == "battle", "a fight plays the battle track anywhere")
	ok(SoundScape.track(_ctx({"biome": "no_such_biome"})) == str(s["default"]), "a biome the data lacks plays the default")
	# the beds
	ok(SoundScape.beds(_ctx()).is_empty(), "a clear day on the plains has no bed")
	ok(SoundScape.beds(_ctx({"precip": "rain", "weather": "rain"})).has("rain") and not SoundScape.beds(_ctx({"precip": "rain", "weather": "rain"})).has("snow_hush"), "rain has its bed")
	var storm := SoundScape.beds(_ctx({"precip": "rain", "weather": "storm"}))
	ok(storm.has("rain") and storm.has("wind") and float(storm["rain"]) >= 0.85, "a storm adds wind and the rain is no quieter")
	ok(SoundScape.beds(_ctx({"precip": "snow", "weather": "snow"})).has("snow_hush"), "snow has its hush")
	ok(SoundScape.beds(_ctx({"fog": 0.8, "weather": "fog"})).has("fog_hum") and not SoundScape.beds(_ctx({"fog": 0.1})).has("fog_hum"), "heavy fog hums, a haze does not")
	ok(SoundScape.beds(_ctx({"biome": "mountains"})).has("wind") and SoundScape.beds(_ctx({"biome": "plains"})).is_empty(), "the high ground has its wind")
	var night := SoundScape.beds(_ctx({"night": true}))
	ok(night.has("night_crickets") and night.has("night_owls"), "a night on the plains has crickets and owls")
	ok(not SoundScape.beds(_ctx({"night": true, "biome": "tundra"})).has("night_crickets") and SoundScape.beds(_ctx({"night": true, "biome": "tundra"})).has("night_owls"), "a cold night has an owl and no crickets")
	ok(SoundScape.beds(_ctx({"night": true, "biome": "volcanic"})).has("wind") == false and not SoundScape.beds(_ctx({"night": true, "biome": "volcanic"})).has("night_owls"), "a volcano's night is silent of animals")
	var tn := SoundScape.beds(_ctx({"night": true, "town": true}))
	ok(tn.has("town_murmur") and float(tn["night_crickets"]) < float(night["night_crickets"]), "a town at night murmurs and its crickets are quieter")
	ok(SoundScape.beds(_ctx({"town": true})).has("town_murmur"), "a town murmurs")
	var inn := SoundScape.beds(_ctx({"indoors": true, "precip": "rain", "weather": "rain"}))
	ok(inn.has("town_murmur") and float(inn["rain"]) < float(SoundScape.beds(_ctx({"precip": "rain"}))["rain"]), "in a room the rain is muffled and voices murmur")
	ok(SoundScape.beds(_ctx({"indoors": true, "dungeon": true, "precip": "rain", "night": true})) == {"dungeon_drone": 1.0, "dungeon_drip": 1.0}, "a dungeon has its drone and drips, and no weather or night")
	for c in [_ctx({"precip": "rain", "weather": "storm", "night": true, "town": true}), _ctx({"night": true, "biome": "swamp", "fog": 0.9})]:
		for k in SoundScape.beds(c):
			ok(Sound.is_bed(k) and float(SoundScape.beds(c)[k]) > 0.0 and float(SoundScape.beds(c)[k]) <= 1.0, "bed %s has a level of 0 to 1" % k)
	# the context, from a real dynasty
	var d := _house()
	var sb := GameSandbox.start(d)
	d.world_seconds = 0.0
	ok(not bool(SoundScape.context(d, sb)["night"]), "the first seconds of the world are day")
	d.world_seconds = (1.0 - float(GameDay.setting("start_phase"))) * float(GameDay.setting("day_seconds"))
	ok(bool(SoundScape.context(d, sb)["night"]), "midnight is night")
	d.world.weather_id = "rain"
	var ctx := SoundScape.context(d, sb)
	ok(str(ctx["precip"]) == "rain" and float(ctx["fog"]) == float(GameDay.look(d)["fog"]) and str(ctx["weather"]) == "rain", "the context takes the weather from GameDay.look")
	ok(SoundScape.beds(ctx).has("rain") and SoundScape.beds(ctx).has("night_crickets"), "so a rainy night has both")
	var dice_before := d.rng.state
	for i in 20:
		SoundScape.context(d, sb)
		SoundScape.snapshot(d, sb)
	ok(d.rng.state == dice_before, "reading the world draws none of the dynasty's dice")


# ---------------------------------------------------------------- what happened

func _snap(over: Dictionary = {}) -> Dictionary:
	var s := {"heir": 1, "level": 3, "gold": 50, "bag": 2, "gear": ["sword", "", ""], "quests": 1, "chasers": 0, "space": "world", "fight": false}
	s.merge(over, true)
	return s


func test_events() -> void:
	var base := _snap()
	ok(SoundScape.events({}, base).is_empty() and SoundScape.events(base, base).is_empty(), "the first look and no change are silent")
	ok(SoundScape.events(base, _snap({"space": "world/hearthmere/forge"})) == ["door_open"], "going in is a door opening")
	ok(SoundScape.events(_snap({"space": "world/hearthmere/forge"}), base) == ["door_close"], "coming out is a door closing")
	ok(SoundScape.events(_snap({"space": "a"}), _snap({"space": "b"})).is_empty(), "moving between rooms is no door of the world's")
	ok(SoundScape.events(base, _snap({"bag": 3})) == ["pickup"] and SoundScape.events(base, _snap({"bag": 1})).is_empty(), "something into the bag is a pickup, something out is not")
	ok(SoundScape.events(base, _snap({"gold": 60})) == ["coins"] and SoundScape.events(base, _snap({"gold": 10})) == ["spend"], "gold gained rings, gold spent clinks")
	ok(SoundScape.events(base, _snap({"gear": ["axe", "", ""]})) == ["equip"] and SoundScape.events(base, _snap({"gear": ["", "", ""]})).is_empty(), "wearing something is an equip, taking it off is not")
	ok(SoundScape.events(base, _snap({"level": 4})) == ["level_up"] and SoundScape.events(base, _snap({"level": 2})).is_empty(), "a level gained is a fanfare")
	ok(SoundScape.events(base, _snap({"quests": 2})) == ["quest"], "a quest done is told")
	ok(SoundScape.events(base, _snap({"chasers": 1})) == ["alert"] and SoundScape.events(_snap({"chasers": 1}), _snap({"chasers": 3})).is_empty(), "a creature that starts chasing alerts once")
	ok(SoundScape.events(base, _snap({"fight": true, "chasers": 1})) == ["fight"], "a fight starting is the fight's alert, not the chase's")
	ok(SoundScape.events(base, _snap({"heir": 2, "gold": 0, "level": 1, "bag": 0})).is_empty(), "a new heir's different purse is no sale")
	ok(SoundScape.events(base, _snap({"gold": 0, "bag": 3, "level": 4})) == ["pickup", "spend", "level_up"], "a purchase and a level in one look sound in a fixed order")
	var w: Dictionary = SoundScape.data()["world"]
	for e in ["door_open", "door_close", "pickup", "coins", "spend", "equip", "level_up", "quest", "alert", "fight"]:
		ok(w.has(e) and Sound.data()["cues"].has(str(w[e])), "%s has a cue" % e)
	var d := _house()
	var sb := GameSandbox.start(d)
	var a := SoundScape.snapshot(d, sb)
	d.heir.gold += 10
	d.heir.inventory.append("rusty_sword")
	var b := SoundScape.snapshot(d, sb)
	ok(SoundScape.events(a, b) == ["pickup", "coins"], "a snapshot of a real house shows gold and the bag: %s" % str(SoundScape.events(a, b)))
	sb.creatures.append({"mode": "chase"})
	ok(SoundScape.events(b, SoundScape.snapshot(d, sb)) == ["alert"], "a chasing creature in the sandbox alerts")


# ---------------------------------------------------------------- settings

func test_settings() -> void:
	_wipe()
	ok(Sound.on("ambience") and Sound.level("ambience") == "medium" and Sound.choice("ambience") == "medium", "ambience starts on at the middle volume")
	ok(Sound.set_on("ambience", false) and not Sound.on("ambience") and Sound.on("sound") and Sound.on("music"), "ambience switches off on its own")
	ok(Sound.set_level("ambience", "low") and Sound.level("ambience") == "low" and Sound.level("sound") == "medium" and Sound.level("music") == "medium", "and has a volume of its own")
	ok(Sound.db("ambience") == float(Sound.data()["levels"]["low"]["db"]), "the volume is the step's decibels")
	ok(Sound.choose("ambience", "high") and Sound.on("ambience") and Sound.choice("ambience") == "high" and Sound.choose("ambience", "off") and Sound.choice("ambience") == "off" and Sound.level("ambience") == "high", "choosing a step switches it on, Off keeps the step")
	var cf := ConfigFile.new()
	cf.load(UiSettings.path)
	ok(str(cf.get_value("ui", "ambience", "")) == "off" and str(cf.get_value("ui", "ambience_volume", "")) == "high", "both are in the settings file")
	_wipe()
	ok(Sound.on("ambience") and Sound.level("ambience") == "medium", "a file taken away is read as defaults at once")
	for junk in [7, ["off"], true, "loud", 0.5]:
		UiSettings.store("ambience", junk)
		UiSettings.store("ambience_volume", junk)
		ok(Sound.on("ambience") and Sound.level("ambience") == "medium", "a damaged ambience setting (%s) reads as the default" % str(junk))
	ok(not Sound.captions_on(), "captions are off unless asked for")
	ok(UiSettings.set_access("sound_captions", true) and Sound.captions_on() and UiSettings.access_on("sound_captions"), "Captions for sounds is an accessibility option, read by the sound at once")
	UiSettings.store("sound_captions", "yes")
	ok(not Sound.captions_on(), "a damaged captions value reads as off")
	_wipe()
	# the file is read once until it changes: many questions, one read
	var t0 := Time.get_ticks_usec()
	for i in 20000:
		Sound.on("sound")
		Sound.db("music")
	var took := Time.get_ticks_usec() - t0
	ok(took < 1500000, "asking for a setting is quick (%d us for 40000 questions)" % took)


# ---------------------------------------------------------------- the interface

func test_interface() -> void:
	_wipe()
	var early := Button.new()   # in the tree before any sound: found by the first scan
	root.add_child(early)
	var s := _node(100.0)
	await _frames(1)
	ok(Sound.instance == s and s.fx_log.is_empty(), "the node is the one the static hooks reach, and nothing has sounded")
	early.pressed.emit()
	ok(s.fx_log.is_empty(), "nothing of the interface sounds in the quiet seconds after the node starts")
	s.clock = 105.0
	early.pressed.emit()
	ok(s.fx_log == ["ui_click"], "a button already in the tree clicks: %s" % str(s.fx_log))
	var b := Button.new()
	root.add_child(b)
	b.pressed.emit()
	ok(s.fx_log == ["ui_click", "ui_click"], "a button added later clicks too")
	s.hover_on(b)
	ok(s.fx_log.back() == "ui_hover", "hovering ticks")
	var n: int = s.fx_log.size()
	s.hover_on(b)
	ok(s.fx_log.size() == n, "ticks come no faster than the gap")
	s.clock += 0.2
	s.hover_on(b)
	ok(s.fx_log.size() == n + 1, "after the gap the next one ticks")
	s.clock += 0.2
	b.disabled = true
	s.hover_on(b)
	ok(s.fx_log.size() == n + 1, "a disabled button does not tick")
	b.disabled = false
	UiSettings.force_touch = 1
	s.clock += 0.2
	s.hover_on(b)
	ok(s.fx_log.size() == n + 1, "a touch screen has no hover ticks")
	UiSettings.force_touch = 0
	var t := TabContainer.new()
	t.add_child(Control.new())
	t.add_child(Control.new())
	root.add_child(t)
	n = s.fx_log.size()
	t.current_tab = 1
	ok(s.fx_log.size() == n + 1 and s.fx_log.back() == "ui_tab", "changing a tab sounds")
	var bar := TabBar.new()
	bar.add_tab("One")
	bar.add_tab("Two")
	root.add_child(bar)
	n = s.fx_log.size()
	s.clock += 0.2
	bar.current_tab = 1
	ok(s.fx_log.size() == n + 1 and s.fx_log.back() == "ui_tab", "a tab bar's too")
	var pane := Control.new()
	pane.set_meta("pane", "test_pane")
	n = s.fx_log.size()
	root.add_child(pane)
	ok(s.fx_log.size() == n + 1 and s.fx_log.back() == "ui_open", "a pane opening sounds")
	pane.free()
	ok(s.fx_log.size() == n + 2 and s.fx_log.back() == "ui_close", "and closing")
	var modal := Control.new()
	modal.set_meta("modal", true)
	root.add_child(modal)
	ok(s.fx_log.back() == "ui_open", "a modal panel opens with it")
	s.quiet()
	n = s.fx_log.size()
	modal.free()
	b.pressed.emit()
	ok(s.fx_log.size() == n, "after a screen is swapped the closings and clicks are quiet")
	s.clock += 2.0
	b.pressed.emit()
	ok(s.fx_log.size() == n + 1, "and are heard again after the quiet seconds")
	var quiet_pane := Control.new()
	quiet_pane.set_meta("pane", "again")
	s.quiet()
	n = s.fx_log.size()
	root.add_child(quiet_pane)
	quiet_pane.free()
	ok(s.fx_log.size() == n, "a pane that opens itself in the quiet seconds is not heard")
	# the pool never grows, and nothing plays with no output
	var kids := s.get_child_count()
	s.clock += 2.0
	for i in 60:
		s.clock += 0.1
		s.ui("click")
		s.ui("hover")
	ok(s.get_child_count() == kids and s._fx.size() == int(SoundScape.data()["fx_voices"]), "any number of sounds make no new players (%d children)" % s.get_child_count())
	var playing := false
	for p in s._voices + s._fx + s._mp:
		playing = playing or p.playing
	ok(not playing and not Sound.has_output(), "no player was ever started with no output")
	Sound.set_on("sound", false)
	n = s.fx_log.size()
	b.pressed.emit()
	s.ui("open")
	ok(s.fx_log.size() == n, "with sound effects off the interface is silent")
	ok(not s.fx("no_such_cue") and not s.fx(""), "a name that is no cue plays nothing")
	Sound.set_on("sound", true)
	ok(s.cue_log.is_empty(), "none of it is in the battle cues' log")
	for c in [early, b, t, bar, modal]:
		if is_instance_valid(c):
			c.free()
	s.free()
	ok(Sound.instance == null, "the hook has nobody to reach once the node is gone")
	Sound.footstep("grass")   # must not fail
	_wipe()


# ---------------------------------------------------------------- footsteps

func test_footsteps() -> void:
	_wipe()
	var s := _node(200.0)
	await _frames(1)
	Sound.footstep("grass")
	ok(s.fx_log == ["step_grass"], "the hook plays a footstep on its ground: %s" % str(s.fx_log))
	var first_pitch: float = s._fx[0].pitch_scale
	Sound.footstep("grass")
	ok(s.fx_log.size() == 1, "a second step at once is dropped")
	s.clock += float(SoundScape.data()["footsteps"]["gap"]) + 0.01
	Sound.footstep("ford")
	ok(s.fx_log == ["step_grass", "step_water"], "another ground, another sound (ford is water)")
	ok(first_pitch > s._fx[1].pitch_scale, "feet alternate in pitch (%.3f then %.3f)" % [first_pitch, s._fx[1].pitch_scale])
	var want := {"sand": "step_sand", "snow": "step_snow", "stone": "step_stone", "wood": "step_wood", "floor": "step_wood", "lava": "step_grass", "": "step_grass"}
	for k in want:
		s.clock += 1.0
		Sound.footstep(k)
		ok(s.fx_log.back() == want[k], "'%s' sounds %s" % [k, want[k]])
	s.clock += 5.0
	s.step_sound("grass")
	ok(s._ext_until < s.clock, "a step the screen found itself does not stand the screen's own detection down")
	Sound.footstep("grass")
	ok(s._ext_until > s.clock, "a step called from outside does")
	# the walk's own signal: footstep(who, kind, ground, foot, speed, near)
	var m: int = s.fx_log.size()
	s.clock += 5.0
	s.on_footstep("heir", "heir", "plains", 0, 4.0, 0.0)
	ok(s.fx_log.size() == m + 1 and s.fx_log.back() == "step_grass", "the walk's step for the heir sounds on its ground (plains are grass)")
	var heir_db: float = s._fx[(s._fx_next - 1) % s._fx.size()].volume_db
	s.on_footstep("wolf1", "creature", "snow", 1, 4.0, 3.0)
	ok(s.fx_log.back() == "step_snow" and s._fx[(s._fx_next - 1) % s._fx.size()].volume_db < heir_db, "another's step is quieter than the heir's")
	s.on_footstep("wolf2", "creature", "snow", 1, 4.0, 40.0)
	ok(s.fx_log.size() == m + 2, "one out of earshot is not heard")
	s.on_footstep("wolf1", "creature", "snow", 0, 4.0, 3.0)
	ok(s.fx_log.size() == m + 2, "a walker's steps keep the gap")
	for g in ["floor", "dungeon", "ford", "coast", "mountains", "ocean", "tundra"]:
		s.clock += 5.0
		s.on_footstep("heir", "heir", g, 0, 4.0, 0.0)
	ok(s.fx_log.slice(m + 2) == ["step_wood", "step_stone", "step_water", "step_sand", "step_stone", "step_water", "step_snow"], "the walk's ground names are all understood: %s" % str(s.fx_log.slice(m + 2)))
	Sound.set_on("sound", false)
	var n: int = s.fx_log.size()
	s.clock += 1.0
	Sound.footstep("grass")
	ok(s.fx_log.size() == n, "with sound effects off the feet are silent")
	Sound.set_on("sound", true)
	s.free()
	_wipe()


# ---------------------------------------------------------------- crossfades

func test_fades() -> void:
	_wipe()
	var s := _node(300.0)
	await _frames(1)
	ok(s.instant_fades, "with no output tracks and beds swell at once")
	s.music("title")
	ok(s._mgain[s._mi] == 1.0 and s._music.volume_db == Sound.db("music"), "headless the track is at full at once, at the music's volume")
	s.instant_fades = false
	s.music("town")
	var new_one: int = s._mi
	var old_one := 1 - new_one
	ok(s.playing == "town" and s._mname[new_one] == "town" and s._mname[old_one] == "title" and s._mgain[new_one] == 0.0 and s._mgain[old_one] == 1.0, "a new track starts on the other player at nothing, the old one still at full")
	s.step_fades(0.8)
	var half: float = 0.8 / float(SoundScape.data()["fade"]["music"])
	ok(absf(s._mgain[new_one] - half) < 0.001 and absf(s._mgain[old_one] - (1.0 - half)) < 0.001, "they cross over together (%.2f and %.2f)" % [s._mgain[new_one], s._mgain[old_one]])
	ok(absf(s._mp[new_one].volume_db - (Sound.db("music") + linear_to_db(half))) < 0.01, "the volume follows the swell")
	s.music("battle")   # a third before the second finished
	ok(s._mname[s._mi] == "battle" and s.music_log == ["title", "town", "battle"], "a fight can interrupt a fade")
	s.step_fades(5.0)
	var live := 0
	for i in 2:
		if s._mname[i] != "":
			live += 1
	ok(live == 1 and s._mname[s._mi] == "battle" and s._mgain[s._mi] == 1.0, "when the fade is done only the new track is left")
	s.music("town")
	s.music("battle")
	ok(s.music_log.size() == 5 and s._mname[s._mi] == "battle", "going back and forth is each a change of track")
	s.step_fades(5.0)
	s.music("")
	ok(s.playing == "" and s._mtarget == [0.0, 0.0], "silence fades the music out")
	s.step_fades(5.0)
	ok(s._mname == ["", ""], "and the players are let go")
	Sound.set_on("music", false)
	s.music("town")
	ok(s.playing == "" and s.wanted == "town" and s._mname == ["", ""], "with music off nothing starts")
	Sound.set_on("music", true)
	s.refresh()
	ok(s.playing == "town", "and switching it on starts what was wanted")
	# beds
	s.ambience({"rain": 0.8, "wind": 0.4})
	ok(s.beds_now() == {"rain": 0.8, "wind": 0.4} and s.bed_log == ["rain", "wind"], "beds are asked for with their levels: %s" % str(s.beds_now()))
	ok(s._beds.any(func(ch): return ch["name"] == "rain" and ch["gain"] == 0.0), "a bed begins at nothing when it can swell")
	s.step_fades(1.1)
	var rain: Dictionary = s._beds.filter(func(ch): return ch["name"] == "rain")[0]
	ok(absf(float(rain["gain"]) - 0.5) < 0.001 and rain["p"].volume_db < Sound.db("ambience") and not rain["p"].playing, "it swells over the fade's seconds, quietly, and nothing is played with no output")
	s.step_fades(5.0)
	ok(absf(float(rain["gain"]) - 0.8) < 0.001, "to the level asked for")
	s.ambience({"rain": 0.8})
	ok(s.beds_now() == {"rain": 0.8} and s._beds.any(func(ch): return ch["name"] == "wind"), "a bed no longer wanted is still there, fading")
	s.step_fades(5.0)
	ok(not s._beds.any(func(ch): return ch["name"] == "wind"), "and gone when it has faded")
	s.ambience({"rain": 1.0})
	ok(s.bed_log == ["rain", "wind"], "a bed asked for again is not started again")
	s.ambience({"rain": 1.0, "wind": 1.0, "snow_hush": 1.0, "fog_hum": 1.0, "town_murmur": 1.0})
	ok(s.beds_now().size() == int(SoundScape.data()["bed_voices"]), "more beds than channels fill the channels and no more (%d)" % s.beds_now().size())
	Sound.set_on("ambience", false)
	s.refresh()
	ok(s.beds_now().is_empty(), "with ambience off no bed is wanted")
	s.step_fades(5.0)
	ok(not s._beds.any(func(ch): return ch["name"] != ""), "and they fade away")
	Sound.set_on("ambience", true)
	s.refresh()
	ok(s.beds_now().size() == int(SoundScape.data()["bed_voices"]), "ambience back on brings the beds back")
	s.instant_fades = true
	s.ambience({})
	ok(s.beds_now().is_empty() and not s._beds.any(func(ch): return ch["name"] != ""), "headless an empty wish ends the beds at once")
	s.free()
	_wipe()


# ---------------------------------------------------------------- building off the main thread

func test_threads() -> void:
	_wipe()
	var s := _node(600.0)
	await _frames(1)
	Sound.forget()
	s.force_threads = true   # as with an audio output: tracks, beds and cues are built on a worker thread
	var before := Sound.built
	ok(not s.prepare("wild_forest") and not s.prepare("wild_forest") and s._jobs.size() == 1, "a track not built yet is asked of a worker once, and is not ready")
	s.music("wild_forest")
	ok(s.playing == "wild_forest" and s._mname == ["", ""] and s._music.stream == null, "the music asked for waits for it, and nothing else changes")
	var waited := 0
	while not Sound._streams.has("wild_forest") and waited < 600:
		await process_frame
		waited += 1
	ok(Sound._streams.has("wild_forest") and Sound.built == before + 1 and s._jobs.is_empty(), "the stream becomes ready on the main thread, once (%d frames)" % waited)
	ok(s._mname[s._mi] == "wild_forest" and s._music.stream == Sound.stream("wild_forest"), "and the track that was waited for then starts")
	var built_by_thread: AudioStreamWAV = Sound.stream("wild_forest")
	var direct := Sound.pcm(Sound.samples(Sound.def_of("wild_forest"), Sound.rate_of("wild_forest")))
	ok(built_by_thread.data == direct and built_by_thread.mix_rate == Sound.rate_of("wild_forest"), "built on a thread it is the same sound as built here")
	s.ambience({"night_owls": 1.0})
	ok(s.beds_now() == {"night_owls": 1.0} and not s._beds.any(func(ch): return ch["started"]), "a bed asked for waits for its stream, wanted but not started")
	waited = 0
	while not s._beds.any(func(ch): return ch["started"]) and waited < 600:
		await process_frame
		waited += 1
	ok(s._beds.any(func(ch): return ch["name"] == "night_owls" and ch["started"]), "and starts when it is ready")
	var n: int = s.fx_log.size()
	Sound.forget()
	ok(not s.fx("step_stone") and s.fx_log.size() == n, "a cue not built yet is skipped, never waited for")
	waited = 0
	while not Sound._streams.has("step_stone") and waited < 600:
		await process_frame
		waited += 1
	ok(s.fx("step_stone") and s.fx_log.size() == n + 1, "and sounds once it is built")
	s.queue_free()   # leaving the tree waits for any worker still going
	await _frames(2)
	ok(true, "a node freed with workers running leaves cleanly")
	_wipe()


# ---------------------------------------------------------------- captions

func test_captions() -> void:
	_wipe()
	var s := _node(400.0)
	await _frames(1)
	s.cue("hit")
	s.fx("door_open")
	ok(s.caption_log.is_empty(), "no captions unless asked for")
	UiSettings.set_access("sound_captions", true)
	s.cue("hit")
	s.fx("door_open")
	ok(s.caption_log == ["Hit", "Door opens"], "a caption for each sound that has one: %s" % str(s.caption_log))
	ok(s._cap_label != null and s._cap_label.text == "[Hit]\n[Door opens]", "shown as lines under the action")
	s.cue("hit")
	ok(s.caption_log.size() == 2, "the same line is not shown twice at once")
	s.fx("pickup")
	s.fx("coins")
	ok(s._caps.size() == int(SoundScape.data()["captions"]["max_lines"]) and s._cap_label.text.contains("[Coins]") and not s._cap_label.text.contains("[Hit]"), "only a few lines at a time, the newest")
	s._tick_captions(float(SoundScape.data()["captions"]["seconds"]) + 0.1)
	ok(s._caps.is_empty() and not s._cap_layer.visible, "they fade after their seconds")
	s.fx("step_grass")
	s.fx("ui_click")
	ok(s.caption_log.size() == 4, "footsteps and clicks have no captions")
	s.creature("wolf")
	ok(s.caption_log.back() == str(SoundScape.data()["captions"]["creature"]), "a creature's cry has a line")
	s.ambience({"rain": 1.0})
	ok(s.caption_log.back() == "Rain", "a bed beginning has a line")
	Sound.set_on("sound", false)
	s._tick_captions(10.0)
	s.fx("door_close")
	ok(s.caption_log.back() == "Door closes" and not s.fx_log.has("door_close"), "captions show even with sound off, which is what they are for")
	Sound.set_on("sound", true)
	UiSettings.set_access("sound_captions", false)
	var n: int = s.caption_log.size()
	s.fx("door_open")
	ok(s.caption_log.size() == n, "and stop when switched off")
	for name in SoundScape.data()["captions"]["cues"]:
		ok(Sound.data()["cues"].has(str(name)), "the caption for %s is for a cue" % name)
	s.free()
	# the menu offers the option and the ambience row
	app = GameApp.new()
	root.add_child(app)
	await _frames(2)
	var m: Control = app.open_menu()
	await _frames(3)
	var texts := _texts(m)
	ok(texts.has("Captions for sounds") and texts.has("Ambience") and texts.has("Sound effects") and texts.has("Music"), "the menu has Captions for sounds and the three volumes")
	var b := _row_button(m, "Ambience", "Low")
	ok(b != null and b.custom_minimum_size.y >= 40.0, "Ambience offers its volumes, as tall as the other choices")
	b.pressed.emit()
	await _frames(3)
	ok(Sound.level("ambience") == "low" and Sound.on("ambience"), "choosing one is stored")
	var off := _row_button(_menu(), "Ambience", "Off")
	off.pressed.emit()
	await _frames(3)
	ok(not Sound.on("ambience") and Sound.level("ambience") == "low", "Off switches it off")
	var cap := _row_button(_menu(), "Captions for sounds", "On")
	ok(cap != null, "the captions option has On and Off")
	cap.pressed.emit()
	await _frames(3)
	ok(Sound.captions_on(), "and On stores it")
	app.queue_free()
	await _frames(2)
	app = null
	_wipe()


func _menu() -> Control:
	for c in app.current.get_children():
		if c is Control and _texts(c).has("Captions for sounds"):
			return c
	return null


func _texts(n: Node) -> Array:
	var out: Array = []
	if n is Label:
		out.append((n as Label).text)
	if n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		out.append_array(_texts(c))
	return out


## The button called `which` in the row whose heading is `heading`.
func _row_button(m: Node, heading: String, which: String) -> Button:
	var found := false
	var stack: Array = [m]
	while not stack.is_empty():
		var n: Node = stack.pop_front()
		if n is Label and (n as Label).text == heading:
			found = true
			var parent := n.get_parent()
			var idx := n.get_index()
			var row: Node = parent.get_child(idx + 1) if (heading != "Captions for sounds" and idx + 1 < parent.get_child_count()) else parent
			for c in row.get_children():
				if c is Button and (c as Button).text == which:
					return c
		for c in n.get_children():
			stack.append(c)
	return null


# ---------------------------------------------------------------- the open world

func test_world() -> void:
	_wipe()
	UiSettings.set_access("reduced_motion", false)
	app = GameApp.new()
	root.add_child(app)
	await _frames(2)
	app.sound.clock = 500.0
	app.new_game("Tess", "warrior", "faetouched", 91, "human")
	await _frames(2)
	app.show_sandbox()
	await _frames(3)
	var s: Node = app.sound
	var d: GameDynasty = app.dynasty
	var sb: GameSandbox = app.current.sb
	ok(s.app == app and s._sandbox() == sb, "the sound follows the app's open-world screen")
	var saved := JSON.stringify(d.to_save())
	var dice := d.rng.state
	s.clock = 510.0
	await _frames(3)
	var want := SoundScape.track(SoundScape.context(d, sb))
	ok(s.playing == want and s.track_here(d) == want, "the open world plays the track of the place: %s" % s.playing)
	ok(Sound.is_track(s.playing) and s.playing != "age_1", "which is the place's and not the Age's")
	# a footstep when the heir's tile changes
	s.fx_log.clear()
	s._ext_until = -10.0
	var before := sb.heir
	sb.heir += Vector2i(1, 0)
	s.clock = 520.0
	await _frames(2)
	ok(not s.fx_log.is_empty() and str(s.fx_log[0]).begins_with("step_"), "a step is heard when the heir's tile changes: %s" % str(s.fx_log))
	s.fx_log.clear()
	sb.heir += Vector2i(1, 0)
	s.clock = 530.0
	Sound.footstep("sand")   # the movement's own call stands the screen's detection down
	await _frames(2)
	ok(s.fx_log == ["step_sand"], "when the movement calls the hook the screen adds none of its own: %s" % str(s.fx_log))
	# the world's own sounds
	s.fx_log.clear()
	d.heir.gold += 25
	s._watch_wait = 0.0
	s.clock = 540.0
	await _frames(2)
	ok(s.fx_log.has("coins"), "gold gained is heard")
	s.fx_log.clear()
	d.heir.inventory.append("rusty_sword")
	d.heir.level += 1
	s._watch_wait = 0.0
	await _frames(2)
	ok(s.fx_log.has("pickup") and s.fx_log.has("level_up"), "so are an item picked up and a level: %s" % str(s.fx_log))
	s.fx_log.clear()
	d.quests.done.append("a_test_quest")
	s._watch_wait = 0.0
	await _frames(2)
	ok(s.fx_log == ["quest_done"], "and a quest done")
	s.fx_log.clear()
	var wolf := GameBehaviour.new_agent(9999, "wolf", float(sb.heir.x) + 30.0, float(sb.heir.y) + 30.0)
	wolf["mode"] = "chase"
	sb.creatures.append(wolf)
	s._watch_wait = 0.0
	s._watch(0.0)
	ok(s.fx_log.has("alert"), "a creature that gives chase alerts")
	sb.creatures.erase(wolf)
	s._watch_wait = 0.0
	s._watch(0.0)
	s.fx_log.clear()
	var inside := ""
	for id in GameSpaces.ids():
		if GameSpaces.kind(id) == "interior":
			inside = id
			break
	var keep_heir := sb.heir
	sb.space = inside
	s._watch_wait = 0.0
	await _frames(2)
	ok(s.fx_log.has("door_open") and (s.playing == "town" or s.playing == "dungeon"), "going in is a door, and the room's music plays: %s %s" % [str(s.fx_log), s.playing])
	var beds_in: Dictionary = s.beds_now()
	ok(not beds_in.is_empty() and (beds_in.has("town_murmur") or beds_in.has("dungeon_drone")), "with a room's beds: %s" % str(beds_in))
	s.fx_log.clear()
	sb.space = "world"
	sb.heir = keep_heir
	s._watch_wait = 0.0
	await _frames(2)
	ok(s.fx_log.has("door_close"), "coming out is a door closing")
	# weather and night reach the beds
	sb.space = "world"
	sb.heir = _find(d, func(t, x, z): return str(t["biome"]) == "plains" and not bool(t["water"]) and not GameSandbox.in_town(x, z))
	d.world.weather_id = "rain"
	d.world_seconds = (1.0 - float(GameDay.setting("start_phase"))) * float(GameDay.setting("day_seconds"))
	s._watch_wait = 0.0
	await _frames(2)
	ok(s.beds_now().has("rain") and s.beds_now().has("night_crickets") and s.playing == "night", "rain and a night reach the beds and the music: %s %s" % [str(s.beds_now()), s.playing])
	d.world.weather_id = "clear"
	d.world_seconds = 0.0
	s._watch_wait = 0.0
	await _frames(2)
	ok(s.beds_now().is_empty() and s.playing != "night", "and clear weather in daylight clears them")
	# a fight
	s.fx_log.clear()
	var f := GameDynasty.new_game(5, "Tess", "warrior", "faetouched", "human")
	ok(SoundScape.track(SoundScape.context(f, null)) != "battle" and SoundScape.track(_ctx({"fight": true})) == "battle", "a fight is the battle's track")
	# nothing of it touched the dynasty
	var after := JSON.stringify(d.to_save())
	ok(d.rng.state == dice, "none of the dynasty's dice were drawn")
	var clean := after.contains("sound") or after.contains("ambience") or after.contains("captions")
	ok(not clean and not saved.is_empty(), "none of the sound is in the save")
	var cp := 0
	for fl in DirAccess.get_files_at("res://core/game/"):
		if fl.ends_with(".gd") and (FileAccess.get_file_as_string("res://core/game/" + fl).contains("sound_scape") or FileAccess.get_file_as_string("res://core/game/" + fl).contains("sound.gd")):
			cp += 1
	ok(cp == 0, "no file of the rules refers to the sound")
	# leaving the open world: the title's and the life screen's music come back, the beds go
	app.show_state()
	await _frames(3)
	ok(s.beds_now().is_empty(), "off the open world there are no beds")
	var players := 0
	for p in s._voices + s._fx + s._mp:
		players += 1 if p.playing else 0
	ok(players == 0, "and not one player was started in a headless run")
	app.queue_free()
	await _frames(2)
	app = null
	_wipe()
