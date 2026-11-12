## Sound and music (roadmap item 15): the data and ways to break it; every cue and track builds a buffer of the
## right length that is not silence, stays in range and starts and ends quietly; streams are built once and kept;
## the cue of every listed battle event; the track of each Age, of Ages beyond the listed ones, of the title, a
## fight and the ended saga; the settings kept, defaulted and read from a damaged file; nothing played with sound
## off; a fight shown on the battle screen asks for its events' cues in order and ends exactly as the same fight
## with sound off and with no screen; the death and saga's-end stings, once each; the menu's rows; none of it in
## the save. No audio device is needed: the suite reads what was asked for (`cue_log`, `music_log`).
## Run: godot --headless --path . -s res://tests/test_game_sound.gd
extends SceneTree

const Scen := preload("res://tests/round_scenarios.gd")
const GameApp := preload("res://ui/play/game_app.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const TouchHint := preload("res://ui/play/touch_hint.gd")
const Sound := preload("res://ui/play/sound.gd")
const MenuPanel := preload("res://ui/play/menu_panel.gd")
const CheckData := preload("res://tools/check_data.gd")
const DIR := "user://test_sound/"

## What each battle event sounds like when nothing more is known of it; an event not here is silent.
const PLAIN := {"damage": "hit", "miss": "miss", "heal": "heal", "tick": "tick", "cast": "cast", "defend": "guard",
	"cover": "guard", "death": "fall", "ko": "ko", "flee": "flee"}

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
	test_build()
	test_cache()
	test_events()
	test_tracks()
	test_settings()
	await test_playing()
	await test_fight()
	await test_stings()
	await test_menu()
	_wipe()
	print("sound tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _wipe() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)


func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


# ---------------------------------------------------------------- the data

func _broken(change: Callable, what: String) -> void:
	var saved: Dictionary = Sound.data().duplicate(true)
	change.call(Sound.data())
	ok(not Sound.validate().is_empty(), what)
	Sound._cache = saved


func test_data() -> void:
	ok(Sound.validate().is_empty(), "the data is sound: %s" % str(Sound.validate()))
	ok(CheckData.problems().is_empty(), "and the whole data check, which asks it, finds nothing")
	ok(FileAccess.get_file_as_string("res://tools/check_data.gd").contains("Sound.validate()"), "(the data check does ask it)")
	_broken(func(dat): dat["events"]["wallop"] = "hit", "an event that is not a battle event is found")
	_broken(func(dat): dat["events"]["miss"] = "whoosh", "an event that plays a cue that does not exist is found")
	_broken(func(dat): dat["events"]["damage"]["variants"][0]["field"] = "mood", "a variant on a field the event does not have is found")
	_broken(func(dat): dat["events"]["damage"]["variants"][0]["is"] = 3, "a variant that compares with a number is found")
	_broken(func(dat): dat["events"]["heal"] = 7, "an event that names no cue is found")
	_broken(func(dat): dat["results"]["victory"] = "fanfare", "a result that plays a cue that does not exist is found")
	_broken(func(dat): dat["results"]["draw"] = "hit", "a result no fight ends in is found")
	_broken(func(dat): dat["stings"].erase("succession"), "a death with no sting is found")
	_broken(func(dat): dat["screens"]["title"] = "overture", "a screen whose track does not exist is found")
	_broken(func(dat): dat["ages"].append("age_9"), "an Age whose track does not exist is found")
	_broken(func(dat): dat["ages"].clear(), "no Age tracks at all is found")
	_broken(func(dat): dat["cues"]["spare"] = dat["cues"]["hit"].duplicate(true), "a cue nothing plays is found")
	_broken(func(dat): dat["cues"]["hit"]["wave"] = "organ", "a wave the builder does not know is found")
	_broken(func(dat): dat["cues"]["hit"]["volume"] = 1.5, "a volume above 1 is found")
	_broken(func(dat): dat["cues"]["hit"]["notes"] = [0, 0], "a sound that is all rests is found")
	_broken(func(dat): dat["cues"]["hit"]["notes"] = [200], "a note no ear would hear is found")
	_broken(func(dat): dat["cues"]["hit"]["release"] = 1.0, "an envelope longer than its note is found")
	_broken(func(dat): dat["cues"]["hit"].erase("step"), "a sound with no length is found")
	_broken(func(dat): dat["cues"]["death"]["step"] = 2.0, "a cue longer than a cue may be is found")
	_broken(func(dat): dat["tracks"]["title"]["step"] = 3.0, "a track longer than a track may be is found")
	_broken(func(dat): dat["limits"]["max_total_seconds"] = 10.0, "more sound in all than the cap is found")
	_broken(func(dat): dat["rate"] = 100, "a sample rate too low is found")
	_broken(func(dat): dat["default_level"] = "deafening", "a default volume that is not a step is found")
	_broken(func(dat): dat["levels"]["high"]["db"] = 12.0, "a volume step louder than full is found")
	_broken(func(dat): dat["level_order"].erase("low"), "a volume step the menu would not offer is found")
	_broken(func(dat): dat["voices"] = 0, "no voices to play on is found")
	_broken(func(dat): dat.erase("tracks"), "a missing part is found")
	ok(Sound.validate().is_empty(), "(and the data is whole again after)")


# ---------------------------------------------------------------- building

func test_build() -> void:
	var dat := Sound.data()
	var names: Array = Sound.cue_ids() + Sound.track_ids()
	ok(Sound.cue_ids().size() >= 10 and Sound.track_ids().size() >= 4, "there are cues and tracks to build (%d and %d)" % [Sound.cue_ids().size(), Sound.track_ids().size()])
	var total := 0.0
	for name in names:
		var def := Sound.def_of(name)
		var rate := Sound.rate_of(name)
		var s := Sound.samples(def, rate)
		var want := (def["notes"] as Array).size() * int(round(float(def["step"]) * rate))
		total += Sound.seconds(def)
		ok(s.size() == want and want > 0, "%s: %d samples, as its notes and step say (%d)" % [name, s.size(), want])
		var peak := 0.0
		for x in s:
			peak = maxf(peak, absf(x))
		ok(peak > 0.05, "%s is not silence (peak %.3f)" % [name, peak])
		ok(peak <= float(def["volume"]) + 0.0001, "%s stays within its volume (peak %.3f of %.2f)" % [name, peak, float(def["volume"])])
		ok(absf(s[0]) < 0.02 and absf(s[s.size() - 1]) < 0.02, "%s starts and ends quietly, so it does not click" % name)
		ok(Sound.samples(def, rate) == s, "%s is the same every time it is built" % name)
		var w := Sound.stream(name)
		ok(w != null and w.data.size() == want * 2 and w.mix_rate == rate and w.format == AudioStreamWAV.FORMAT_16_BITS and not w.stereo, "%s becomes a 16-bit stream of that length" % name)
		var loud := false
		for i in range(0, w.data.size(), 2):
			if w.data.decode_s16(i) != 0:
				loud = true
				break
		ok(loud, "%s's stream holds sound" % name)
		if Sound.is_track(name):
			ok(w.loop_mode == AudioStreamWAV.LOOP_FORWARD and w.loop_begin == 0 and w.loop_end == want, "%s loops from end to start" % name)
		else:
			ok(w.loop_mode == AudioStreamWAV.LOOP_DISABLED, "%s plays once" % name)
	ok(total <= float(dat["limits"]["max_total_seconds"]), "all of it is %.1f seconds, within the cap" % total)
	ok(Sound.rate_of("title") == int(dat["music_rate"]) and Sound.rate_of("hit") == int(dat["rate"]), "tracks are built at the music rate, cues at the cue rate")
	# the pieces of the builder
	var one := {"wave": "sine", "notes": [69], "step": 0.1, "attack": 0.0, "release": 0.0, "volume": 1.0}
	var s1 := Sound.samples(one, 8000)
	var crossings := 0
	for i in range(1, s1.size()):
		if s1[i - 1] < 0.0 and s1[i] >= 0.0:
			crossings += 1
	ok(s1.size() == 800 and absi(crossings - 44) <= 1, "note 69 is 440 cycles a second (%d in a tenth)" % crossings)
	var rest := Sound.samples({"wave": "square", "notes": [0, 60], "step": 0.1, "attack": 0.0, "release": 0.0, "volume": 0.5}, 8000)
	var quiet := true
	for i in 800:
		quiet = quiet and rest[i] == 0.0
	ok(quiet and absf(rest[1000]) == 0.5, "a rest is silent and the note after it sounds at the volume")
	var chord := Sound.samples({"wave": "square", "notes": [[60, 60]], "step": 0.1, "attack": 0.0, "release": 0.0, "volume": 0.5}, 8000)
	ok(absf(chord[100]) <= 0.5001 and absf(chord[100]) > 0.49, "a chord's notes share the volume")
	var up := Sound.samples({"wave": "sine", "notes": [57], "step": 0.2, "attack": 0.0, "release": 0.0, "volume": 1.0, "slide": 12}, 8000)
	var first := 0
	var second := 0
	for i in range(1, up.size()):
		if up[i - 1] < 0.0 and up[i] >= 0.0:
			if i < 800:
				first += 1
			else:
				second += 1
	ok(second > first, "a slide upward raises the pitch as the note goes (%d then %d cycles)" % [first, second])
	var n1 := Sound.samples(Sound.def_of("miss"), 8000)
	ok(n1 == Sound.samples(Sound.def_of("miss"), 8000), "noise rolls the same dice every time")
	ok(Sound.samples({}, 8000).is_empty() and Sound.samples({"notes": [60], "step": 0.0}, 8000).is_empty(), "a description with nothing in it builds nothing")
	var bytes := Sound.pcm(PackedFloat32Array([0.0, 1.0, -1.0, 3.0, -3.0, 0.5]))
	ok(bytes.size() == 12 and bytes.decode_s16(0) == 0 and bytes.decode_s16(2) == 32767 and bytes.decode_s16(4) == -32767 and bytes.decode_s16(6) == 32767 and bytes.decode_s16(8) == -32767 and bytes.decode_s16(10) == 16383, "samples become 16-bit sound, clipped at full")


func test_cache() -> void:
	Sound.forget()
	var before := Sound.built
	var t0 := Time.get_ticks_msec()
	var a := Sound.stream("hit")
	ok(Sound.built == before + 1, "a stream is built when first wanted")
	ok(Sound.stream("hit") == a and Sound.built == before + 1, "and handed out again without building")
	Sound.stream("title")
	Sound.stream("title")
	ok(Sound.built == before + 2, "each sound is built once")
	ok(Sound.stream("no_such_sound") == null and Sound.stream("") == null and Sound.built == before + 2, "a name that is no sound builds nothing")
	for name in Sound.cue_ids() + Sound.track_ids():
		Sound.stream(name)
	var took := Time.get_ticks_msec() - t0
	ok(took < 5000, "building every sound is quick (%d ms)" % took)
	Sound.forget()
	ok(Sound.stream("hit") != a, "forgetting builds afresh")


# ---------------------------------------------------------------- what plays when

func test_events() -> void:
	var spec := GameEventSpec.spec()
	ok(spec.size() >= 20, "the battle events are listed (%d)" % spec.size())
	for t in spec:
		ok(Sound.cue_for({"type": t}) == str(PLAIN.get(t, "")), "a plain '%s' event plays '%s'" % [t, PLAIN.get(t, "")])
		var c := Sound.cue_for({"type": t})
		ok(c == "" or Sound.data()["cues"].has(c), "and that is a cue or silence")
	for t in PLAIN:
		ok(spec.has(t), "'%s' is a battle event" % t)
	ok(Sound.cue_for({"type": "damage", "side": "enemy", "index": 0, "amount": 5, "crit": false}) == "hit", "a blow on a foe is a hit")
	ok(Sound.cue_for({"type": "damage", "side": "enemy", "index": 0, "amount": 5, "crit": true}) == "crit", "a critical blow has its own")
	ok(Sound.cue_for({"type": "damage", "side": "player", "index": 0, "amount": 5}) == "hurt", "a blow on the heir is a hurt")
	ok(Sound.cue_for({"type": "damage", "side": "ally", "index": 0, "ally": 1, "amount": 5, "crit": true}) == "hurt", "and on a companion, critical or not")
	ok(Sound.cue_for({"type": "damage", "side": "enemy", "crit": "true"}) == "hit" and Sound.cue_for({"type": "damage", "side": 1, "crit": 1}) == "hit", "a field of the wrong kind matches no variant")
	ok(Sound.cue_for({"type": "tick", "ref": "player", "id": "regen", "amount": 3, "heal": true}) == "heal" and Sound.cue_for({"type": "tick", "ref": "e0", "id": "burn", "amount": 3}) == "tick", "a healing tick heals, a burning one ticks")
	ok(Sound.cue_for({"type": "status", "ref": "e0", "id": "burn", "applied": true}) == "" and Sound.cue_for({"type": "round", "n": 1}) == "", "statuses and round markers are silent")
	ok(Sound.cue_for({}) == "" and Sound.cue_for({"type": "no_such_event"}) == "" and Sound.cue_for({"type": 5}) == "", "an event with no type, or an unknown one, is silent")
	ok(Sound.result_cue("victory") == "victory" and Sound.result_cue("defeat") == "defeat" and Sound.result_cue("fled") == "" and Sound.result_cue("") == "", "a won fight and a lost one have their cues; an escape has only its event's")
	ok(Sound.sting_for("succession") == "death" and Sound.sting_for("ended") == "saga_end" and Sound.sting_for("life") == "" and Sound.sting_for("succession") != Sound.sting_for("ended"), "a death and the saga's end have different stings; a life has none")


func test_tracks() -> void:
	var ages: Array = Sound.data()["ages"]
	ok(ages.size() >= 2, "more than one Age has a track (%d)" % ages.size())
	var seen: Dictionary = {}
	for i in ages.size():
		ok(Sound.age_track(i + 1) == str(ages[i]), "Age %d plays %s" % [i + 1, ages[i]])
		seen[str(ages[i])] = true
	ok(seen.size() == ages.size(), "each listed Age has a track of its own")
	ok(Sound.age_track(ages.size() + 1) == str(ages[0]) and Sound.age_track(ages.size() * 3 + 2) == str(ages[1]), "Ages beyond the last go round again")
	ok(Sound.age_track(0) != "" and Sound.age_track(-5) != "" and Sound.age_track(909) != "", "any Age number gets a track")
	ok(Sound.track_for(null) == "title", "with no dynasty it is the title's")
	var d := GameDynasty.new_game(5, "Tess", "warrior", "faetouched", "human")
	ok(d.age_number() == 1 and Sound.track_for(d) == "age_1", "a new house hears the first Age")
	GameAges.jump_to(d, GameAges.age_length() + 1)
	ok(d.age_number() == 2 and Sound.track_for(d) == "age_2", "in the second Age, the second")
	GameAges.jump_to(d, GameAges.age_length() * ages.size() + 1)
	ok(d.age_number() == ages.size() + 1 and Sound.track_for(d) == "age_1", "past the last listed Age, the first again")
	d.state = "ended"
	ok(Sound.track_for(d) == "", "an ended saga is left in silence")
	var f := Scen.make(6, "paladin", 2, "hunt")
	ok(f.battle != null and Sound.track_for(f) == "battle", "a fight has its own track")
	for name in ["title", "battle"] + ages:
		ok(Sound.is_track(name), "%s is a track" % name)


# ---------------------------------------------------------------- settings

func test_settings() -> void:
	_wipe()
	ok(Sound.on("sound") and Sound.on("music"), "with no settings file both are on")
	ok(Sound.level("sound") == "medium" and Sound.level("music") == "medium" and Sound.choice("sound") == "medium", "at the middle volume")
	ok(Sound.db("sound") < 0.0 and Sound.db("sound") == float(Sound.data()["levels"]["medium"]["db"]), "which is below full")
	ok(Sound.level_ids() == ["low", "medium", "high"], "three volume steps, quietest first")
	ok(Sound.db("sound") > float(Sound.data()["levels"]["low"]["db"]) and Sound.db("sound") < float(Sound.data()["levels"]["high"]["db"]), "each louder than the last")
	ok(Sound.set_on("sound", false) and not Sound.on("sound") and Sound.on("music"), "sound effects switch off on their own")
	ok(Sound.set_level("music", "low") and Sound.level("music") == "low" and Sound.level("sound") == "medium", "and each has its own volume")
	var cf := ConfigFile.new()
	cf.load(UiSettings.path)
	ok(str(cf.get_value("ui", "sound", "")) == "off" and str(cf.get_value("ui", "music_volume", "")) == "low", "both are kept in the settings file")
	ok(not Sound.set_level("music", "deafening") and Sound.level("music") == "low", "an unknown volume is refused")
	ok(not Sound.set_on("noise", true) and not Sound.set_level("noise", "low") and not Sound.on("noise"), "and an unknown kind")
	ok(Sound.choose("sound", "high") and Sound.on("sound") and Sound.level("sound") == "high" and Sound.choice("sound") == "high", "choosing a volume switches it on at that volume")
	ok(Sound.choose("sound", "off") and not Sound.on("sound") and Sound.level("sound") == "high" and Sound.choice("sound") == "off", "choosing Off keeps the volume for next time")
	ok(not Sound.choose("sound", "eleven") and Sound.choice("sound") == "off", "choosing a step that does not exist changes nothing")
	for junk in [7, ["off"], true, "", "loud", 0.5]:
		UiSettings.store("sound", junk)
		UiSettings.store("music_volume", junk)
		ok(Sound.on("sound"), "a damaged on or off in the file (%s) reads as on" % str(junk))
		ok(Sound.level("music") == "medium" and Sound.db("music") == float(Sound.data()["levels"]["medium"]["db"]), "a damaged volume (%s) reads as the default" % str(junk))
	_wipe()


# ---------------------------------------------------------------- playing

func test_playing() -> void:
	_wipe()
	var s: Node = Sound.new()
	root.add_child(s)
	await _frames(1)
	ok(s.cue_log.is_empty() and s.music_log.is_empty() and s.playing == "", "nothing plays until asked")
	s.cue("hit")
	s.cue("heal")
	ok(s.cue_log == ["hit", "heal"], "cues play in the order asked: %s" % str(s.cue_log))
	s.cue("no_such_cue")
	s.cue("")
	s.cue("title")
	ok(s.cue_log.size() == 2, "a name that is no cue plays nothing")
	for i in 20:
		s.cue("tick")   # more at once than there are voices
	ok(s.cue_log.size() == 22, "many cues at once are all taken")
	s.event({"type": "damage", "side": "enemy", "index": 0, "amount": 4, "crit": true})
	s.event({"type": "status", "ref": "e0", "id": "burn", "applied": true})
	ok(s.cue_log.size() == 23 and s.cue_log[22] == "crit", "a battle event plays its cue, a silent one nothing")
	Sound.set_on("sound", false)
	s.cue("hit")
	s.event({"type": "death", "side": "enemy", "index": 0})
	ok(s.cue_log.size() == 23, "with sound effects off nothing is played")
	s.music("age_1")
	ok(s.playing == "age_1" and s.music_log == ["age_1"], "music still plays with only the effects off")
	s.music("age_1")
	ok(s.music_log.size() == 1, "the track already playing is not started again")
	s.music("battle")
	ok(s.playing == "battle" and s.music_log == ["age_1", "battle"], "another track takes over")
	s.music("no_such_track")
	ok(s.playing == "" and s.music_log.size() == 2, "a name that is no track is silence")
	s.music("age_2")
	Sound.set_on("music", false)
	s.refresh()
	ok(s.playing == "" and s.wanted == "age_2", "switching music off stops it and remembers what was wanted")
	s.music("age_3")
	ok(s.playing == "" and s.music_log.size() == 3, "with music off no track is started")
	Sound.set_on("sound", true)
	s.cue("hit")
	ok(s.cue_log.size() == 24, "cues still play with only the music off")
	Sound.set_on("music", true)
	s.refresh()
	ok(s.playing == "age_3" and s.music_log.size() == 4, "switching it on again starts the track that was wanted")
	Sound.set_level("music", "low")
	s.refresh()
	ok(s.music_log.size() == 4 and s._music.volume_db == Sound.db("music") and s._music.volume_db == float(Sound.data()["levels"]["low"]["db"]), "a new volume reaches the track playing without starting it again")
	Sound.set_level("sound", "high")
	s.cue("hit")
	var used: AudioStreamPlayer = s._voices[(s._next - 1) % s._voices.size()]
	var jitter := float(Sound.data()["pitch_jitter"])
	ok(used.volume_db == float(Sound.data()["levels"]["high"]["db"]) and used.stream == Sound.stream("hit") and absf(used.pitch_scale - 1.0) <= jitter + 0.0001, "a cue plays its own stream at the chosen volume, its pitch within the wander allowed")
	ok(s._voices.size() == int(Sound.data()["voices"]), "there are as many voices as the data says")
	s.stop_music()
	ok(s.playing == "", "the music can be stopped")
	s.queue_free()
	_wipe()


# ---------------------------------------------------------------- a fight, heard or not

## What a fight left behind, in a form that compares.
func _end(d: GameDynasty, b: GameBattle) -> Dictionary:
	var state := Scen.state_of(b)
	state.erase("rng")
	var flat := func(v: Variant) -> String: return JSON.stringify(JSON.parse_string(JSON.stringify(v)))
	return {"log": flat.call(b.log), "state": flat.call(state), "rng": str(b.rng.state), "dynasty": flat.call(Scen.drop_sex(d.to_dict()))}


func _bare(c: Array) -> Dictionary:
	var d := Scen.make(c[0], c[1], c[2], c[3])
	var b := d.battle
	var guard := 0
	while not b.is_over() and guard < Scen.GUARD:
		guard += 1
		GameTactics.auto_turn(b)
	d.finish_battle()
	return _end(d, b)


## The same fight on the battle screen, a turn at a time. Returns its end and the cues its events should
## have asked for, in order.
func _shown(c: Array) -> Dictionary:
	var d := Scen.make(c[0], c[1], c[2], c[3])
	app.dynasty = d
	d.auto_battle = false
	app.show_state()
	await _frames(4)
	app.sound.cue_log.clear()
	var bv: Control = app.current
	var b := d.battle
	var want: Array = []
	var types: Dictionary = {}
	var guard := 0
	while not b.is_over() and guard < Scen.GUARD:
		guard += 1
		await bv._do(func(): GameTactics.auto_turn(b))
		for ev in b.events:
			types[ev["type"]] = true
			if Sound.cue_for(ev) != "":
				want.append(Sound.cue_for(ev))
	await _frames(2)
	if Sound.result_cue(b.result) != "":
		want.append(Sound.result_cue(b.result))
	var out := _end(d, b)
	out["want"] = want
	out["types"] = types
	out["result"] = b.result
	return out


func test_fight() -> void:
	_wipe()
	UiSettings.set_access("reduced_motion", false)
	await _frames(2)
	app = GameApp.new()
	root.add_child(app)
	await _frames(2)
	ok(app.sound != null and app.sound.get_parent() == app and app.sound.playing == "title" and app.sound.music_log == ["title"], "the game starts with its sound in place and the title's track")
	app.new_game("Tess", "warrior", "faetouched", 77, "human")
	await _frames(2)
	ok(app.sound.playing == "age_1", "a new house hears its Age")
	var heard_types: Dictionary = {}
	for c in [[6, "paladin", 2, "hunt"], [9, "mage", 1, "legend"]]:
		var tag := "%d %s x%d %s" % c
		var bare := _bare(c)
		Sound.choose("sound", "medium")
		Sound.choose("music", "medium")
		app.sound.refresh()
		var on: Dictionary = await _shown(c)
		var heard: Array = app.sound.cue_log.duplicate()
		ok(app.sound.playing == "battle", "%s: the fight's track plays" % tag)
		ok(heard == on["want"], "%s: the screen asked for its events' cues in order (%d heard, %d wanted)" % [tag, heard.size(), on["want"].size()])
		ok(heard.size() > 5 and heard.has("hit") and heard[heard.size() - 1] == on["result"], "%s: blows were heard and the last cue is the %s" % [tag, on["result"]])
		for t in on["types"]:
			heard_types[t] = true
		Sound.choose("sound", "off")
		Sound.choose("music", "off")
		app.sound.refresh()
		var music_before: int = app.sound.music_log.size()
		var off: Dictionary = await _shown(c)
		ok(app.sound.cue_log.is_empty() and app.sound.playing == "" and app.sound.music_log.size() == music_before, "%s: with sound and music off nothing is played" % tag)
		ok(off["want"] == on["want"], "%s: (the silent fight had the same events)" % tag)
		for key in ["log", "state", "rng", "dynasty"]:
			ok(on[key] == off[key], "%s: heard or not, the same %s" % [tag, key])
			ok(on[key] == bare[key], "%s: and the same %s as with no screen" % [tag, key])
	var mapped := 0
	for t in heard_types:
		if PLAIN.has(t):
			mapped += 1
	ok(mapped >= 4, "the fights had several kinds of event with a cue (%d: %s)" % [mapped, str(heard_types.keys())])
	Sound.choose("sound", "medium")
	Sound.choose("music", "medium")
	app.sound.refresh()


# ---------------------------------------------------------------- the stings

func test_stings() -> void:
	app.new_game("Tess", "warrior", "faetouched", 41)
	await _frames(3)
	app.sound.cue_log.clear()
	app.show_state()
	await _frames(2)
	ok(app.sound.cue_log.is_empty() and app.sound.playing == "age_1", "a life has no sting, only its Age's track")
	app.dynasty._die("old age")
	ok(app.dynasty.state == "succession", "(the heir dies)")
	app.show_state()
	await _frames(3)
	ok(app.sound.cue_log == ["death"], "the death is shown with its sting: %s" % str(app.sound.cue_log))
	app.set_access("high_contrast", true)   # a setting changed: the screen is laid out again
	await _frames(3)
	app.show_state()
	await _frames(3)
	ok(app.sound.cue_log == ["death"], "the same death laid out again does not play it twice")
	app.set_access("high_contrast", false)
	await _frames(3)
	app.go_back()
	await _frames(2)
	app.dynasty.choose_heir(0)
	app.show_state()
	await _frames(3)
	ok(app.dynasty.state == "life" and app.sound.cue_log == ["death"], "the next heir's life is quiet")
	app.dynasty._die("old age")
	app.show_state()
	await _frames(3)
	ok(app.sound.cue_log == ["death", "death"], "the next death has its sting again")
	app.dynasty.choose_heir(0)
	GameAges.jump_to(app.dynasty, GameAges.max_generations())
	app.show_state()
	await _frames(3)
	ok(app.sound.playing == Sound.age_track(app.dynasty.age_number()), "the last Age has a track like any other")
	app.dynasty._die("old age")
	ok(app.dynasty.state == "ended", "(the last heir dies)")
	app.show_state()
	await _frames(3)
	ok(app.sound.cue_log == ["death", "death", "saga_end"] and app.sound.playing == "", "the saga's end has its own sting, and then silence")
	app.show_state()
	await _frames(3)
	ok(app.sound.cue_log.size() == 3, "played once")
	Sound.choose("sound", "off")
	app.new_game("Tess", "warrior", "faetouched", 42)
	await _frames(3)
	app.dynasty._die("old age")
	app.show_state()
	await _frames(3)
	ok(app.sound.cue_log.size() == 3, "with sound effects off a death has no sting")
	Sound.choose("sound", "medium")
	app.show_title()
	await _frames(3)
	ok(app.sound.playing == "title", "back at the title, its track")


# ---------------------------------------------------------------- the menu

func _texts(n: Node, out: Array = []) -> Array:
	if n is Label and (n as Label).is_visible_in_tree():
		out.append((n as Label).text)
	if n is Button and (n as Button).is_visible_in_tree():
		out.append((n as Button).text)
	for c in n.get_children():
		_texts(c, out)
	return out


## The button `which` in the row that follows the heading `heading`.
func _row_button(n: Node, heading: String, which: String) -> Button:
	var kids := n.get_children()
	for i in kids.size():
		if kids[i] is Label and (kids[i] as Label).text == heading and i + 1 < kids.size() and kids[i + 1] is HBoxContainer:
			for c in kids[i + 1].get_children():
				if c is Button and (c as Button).text == which:
					return c
	for c in kids:
		var b := _row_button(c, heading, which)
		if b != null:
			return b
	return null


func _menu() -> Control:
	for c in app.current.get_children():
		if c is MenuPanel and not c.is_queued_for_deletion():
			return c
	return null


func _marked(heading: String) -> String:
	var out := ""
	for which in ["Off", "Low", "Medium", "High"]:
		var b := _row_button(_menu(), heading, which)
		if b != null and b.has_theme_color_override("font_color"):
			out += which
	return out


func test_menu() -> void:
	_wipe()
	app.sound.refresh()
	var m: Control = app.open_menu()
	await _frames(3)
	var texts := _texts(m)
	var text: Dictionary = Sound.data()["text"]
	ok(texts.has("Sound effects") and texts.has("Music") and texts.has(str(text["about"])), "the menu has Sound effects and Music, and says what they are")
	ok(texts.find("Sound effects") > texts.find("Graphics") and texts.find("Music") < texts.find("Problems"), "after Graphics and before Problems")
	for heading in ["Sound effects", "Music"]:
		for which in ["Off", "Low", "Medium", "High"]:
			var b := _row_button(m, heading, which)
			ok(b != null and b.custom_minimum_size.y >= 40.0, "%s offers %s, as tall as the other choices" % [heading, which])
		ok(_marked(heading) == "Medium", "%s starts marked Medium" % heading)
	_row_button(m, "Sound effects", "Off").pressed.emit()
	await _frames(4)
	ok(not Sound.on("sound") and Sound.on("music") and _marked("Sound effects") == "Off" and _marked("Music") == "Medium", "Off for the effects stores it and marks it, the music untouched")
	_row_button(_menu(), "Music", "High").pressed.emit()
	await _frames(4)
	ok(Sound.level("music") == "high" and _marked("Music") == "High" and app.sound.playing == "title" and app.sound._music.volume_db == Sound.db("music"), "High for the music stores it and the track playing takes the volume at once")
	_row_button(_menu(), "Music", "Off").pressed.emit()
	await _frames(4)
	ok(not Sound.on("music") and app.sound.playing == "" and _marked("Music") == "Off", "Off for the music stops it")
	_row_button(_menu(), "Music", "Low").pressed.emit()
	await _frames(4)
	ok(Sound.on("music") and Sound.level("music") == "low" and app.sound.playing == "title", "a volume starts it again")
	_row_button(_menu(), "Sound effects", "Low").pressed.emit()
	await _frames(4)
	ok(Sound.on("sound") and Sound.level("sound") == "low" and _marked("Sound effects") == "Low", "and the effects come back at the volume chosen")
	var cf := ConfigFile.new()
	cf.load(UiSettings.path)
	ok(str(cf.get_value("ui", "sound", "")) == "on" and str(cf.get_value("ui", "sound_volume", "")) == "low" and str(cf.get_value("ui", "music", "")) == "on" and str(cf.get_value("ui", "music_volume", "")) == "low", "all four are in the settings file")
	app.new_game("Tess", "warrior", "faetouched", 43)
	await _frames(3)
	var save := JSON.stringify(app.dynasty.to_save())
	ok(not save.contains("sound") and not save.contains("music") and not save.contains("volume"), "none of it is in the save")
	# nothing in the rules knows of the sound
	var core_use := 0
	for f in DirAccess.get_files_at("res://core/game/"):
		if f.ends_with(".gd") and FileAccess.get_file_as_string("res://core/game/" + f).contains("sound.gd"):
			core_use += 1
	ok(core_use == 0, "no file of the rules refers to the sound")
	app.queue_free()
	await _frames(2)
