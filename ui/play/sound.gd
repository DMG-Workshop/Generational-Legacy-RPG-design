## Sound and music (roadmap item 15). There are no recorded files: every cue and track is described in
## data/ui/sound.json (a waveform, notes, an envelope, a length, a volume), built into an AudioStreamWAV the
## first time it is wanted and kept. `GameApp` adds one of these (`app.sound`) and the screens ask it: `cue`
## plays a sound once, `event` the cue of a battle event, `music` a looping track. Whether each is on, and how
## loud, is in settings.cfg beside the text size, never in the save. View side only: nothing in core/game
## knows of it, it reads a fight's events and never touches a dynasty, and its only dice are CosmeticRng's.
## With no audio device (headless runs, the screenshot tool) the players are never started; `cue_log`,
## `music_log`, `fx_log` and `bed_log` say what was asked for, which is what the tests read.
## Beyond the battle's cues it is the game's whole soundscape (what sounds when is data/ui/soundscape.json, worked out
## by sound_scape.gd): a click, a hover tick and a pane's opening and closing for every button and pane that comes
## into the tree; footsteps by the ground (`Sound.footstep(kind)`, for any code that moves the heir); a door, a pickup,
## coins, gear, a level, a quest and a creature's alert, read from changes in the world; music that follows the place
## and the time of day and crossfades; beds of rain, wind, snow, fog, night, town and dungeon under it. Each of the
## three kinds (sound effects, music, ambience) has its own volume. Tracks and beds are built on a worker thread.
extends Node

const UiSettings := preload("res://ui/play/ui_settings.gd")
const SoundScape := preload("res://ui/play/sound_scape.gd")
const TouchHint := preload("res://ui/play/touch_hint.gd")
const PATH := "res://data/ui/sound.json"
const KINDS := ["sound", "music", "ambience"]   # the three settings: sound effects, music and the beds under it
const RESULTS := ["victory", "defeat", "fled"]   # how a fight can end (GameBattle.result)
const STINGS := ["succession", "ended"]   # the dynasty states that open with a sting
const SCREENS := ["title", "battle", "ended"]   # the screens with a track of their own

static var _cache: Dictionary = {}
static var _streams: Dictionary = {}   # name -> AudioStreamWAV, built once
static var built := 0   # how many streams have been built (tests: the cache is used)

var cue_log: Array = []     # every battle cue started, in order (the last `LOG_KEEP` at most)
var music_log: Array = []   # every track started, in order
var fx_log: Array = []      # every other cue (the interface's, footsteps, the world's), in order
var bed_log: Array = []     # every bed started, in order
var caption_log: Array = [] # every caption shown, in order
var playing := ""           # the track sounding now, "" for none
var wanted := ""            # the track the screens last asked for, played when music is switched on
var app: Node               # the game app (set by it): the screen and dynasty the soundscape follows; null for none
var clock := -1.0           # tests: the time in seconds the soundscape reads instead of the real one (-1 for the real one)
var force_threads := false   # tests: build on a worker thread even with no output
var instant_fades := false  # tracks and beds swell at once (set when there is nothing to hear them on)
var _voices: Array = []
var _fx: Array = []         # the pool for everything but the battle: the interface, footsteps, the world
var _next := 0
var _fx_next := 0
var _mp: Array = []         # the two music players: one sounds, the other fades out
var _mi := 0                # which of them is the newest
var _mname: Array = ["", ""]
var _mgain: Array = [0.0, 0.0]
var _mtarget: Array = [0.0, 0.0]
var _music: AudioStreamPlayer   # the newest music player
var _beds: Array = []       # the bed channels: {p, name, gain, target, started}
var _dice: RandomNumberGenerator
var _jobs := {}             # name -> worker task building it
var _done := {}             # name -> built bytes, waiting to become a stream
var _mutex := Mutex.new()
var _last_step := -10.0
var _alt := false
var _ext_until := -10.0     # the time until which footsteps came from outside, so the screen's own are not added
var _last_hover := -10.0
var _last_tab := -10.0
var _hovered: Control
var _last_steps := {}      # walker -> the time of its last step heard
var _signal_steps := false # the screen tells its own steps (its `footstep` signal), so none are found from tile changes
var _quiet_until := -10.0
var _screen: Node
var _watch_wait := 0.0
var _snap: Dictionary = {}
var _tile := Vector2i(-99999, -99999)
var _tile_space := ""
var _caps: Array = []
var _cap_label: Label
var _cap_layer: CanvasLayer
var _warm: Array = []

static var instance: Node   # the soundscape in play, for the static hooks (`footstep`)
static var _scache: Dictionary = {}   # the settings file read once, until it changes
static var _skey := ""

const LOG_KEEP := 4096
const NO_OUTPUT := "Dummy"   # the engine's name for the audio driver that plays to nothing


# ---------------------------------------------------------------- the data

static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


## Built streams are forgotten (tests that change the data).
static func forget() -> void:
	_streams = {}


static func cue_ids() -> Array:
	return (data()["cues"] as Dictionary).keys()


static func track_ids() -> Array:
	return (data()["tracks"] as Dictionary).keys()


static func bed_ids() -> Array:
	return (data()["beds"] as Dictionary).keys()


## The description of a cue, a track or a bed, empty for a name that is none of them.
static func def_of(name: String) -> Dictionary:
	var dat := data()
	if dat["cues"].has(name):
		return dat["cues"][name]
	if dat["tracks"].has(name):
		return dat["tracks"][name]
	return dat["beds"].get(name, {})


static func is_track(name: String) -> bool:
	return data()["tracks"].has(name)


static func is_bed(name: String) -> bool:
	return data()["beds"].has(name)


## Tracks and beds are built at the music rate (they need no highs), cues at the cue rate.
static func rate_of(name: String) -> int:
	return int(data()["music_rate" if is_track(name) or is_bed(name) else "rate"])


## How long a described sound lasts, in seconds.
static func seconds(def: Dictionary) -> float:
	return float((def.get("notes", []) as Array).size()) * float(def.get("step", 0.0))


# ---------------------------------------------------------------- building

static func _hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


## The samples of a described sound, each from -1 to 1: one note (or chord) after another, each swelling over
## `attack` and dying away over `release` so it starts and ends in silence. Pure: the same description gives
## the same samples (noise rolls dice keyed on the description).
static func samples(def: Dictionary, rate: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var notes: Array = def.get("notes", [])
	var per := int(round(float(def.get("step", 0.0)) * float(rate)))
	if notes.is_empty() or per <= 0:
		return out
	out.resize(notes.size() * per)   # zero filled: a rest stays silent
	var wave := str(def.get("wave", "sine"))
	var volume := float(def.get("volume", 1.0))
	var attack := maxf(1.0, float(def.get("attack", 0.0)) * float(rate))
	var release := maxf(1.0, float(def.get("release", 0.0)) * float(rate))
	var bend := pow(2.0, float(def.get("slide", 0.0)) / 12.0 / float(per))   # per sample
	var lowpass := clampf(float(def.get("lowpass", 0.0)), 0.0, 1.0)   # noise only: how much of each sample the filter takes (less is duller)
	var norm := 0.8 / sqrt(lowpass / (2.0 - lowpass)) if lowpass > 0.0 else 1.0   # a dull noise is brought back up to a white one's level
	var floor_level := clampf(float(def.get("floor", 0.0)), 0.0, 0.95)   # a note's envelope never falls below this (a bed that swells and ebbs, not pulses)
	var dice: RandomNumberGenerator = CosmeticRng.keyed("sound:" + JSON.stringify(def)) if wave == "noise" else null
	var y := 0.0   # the noise filter's memory, kept across notes so they join
	for n in notes.size():
		var chord: Array = notes[n] if typeof(notes[n]) == TYPE_ARRAY else [notes[n]]
		var voices: Array = chord.filter(func(v): return float(v) > 0.0)
		if voices.is_empty():
			continue
		var gain := volume / float(voices.size())
		var base := n * per
		for v in voices:
			var inc := _hz(float(v)) / float(rate)   # cycles per sample
			var phase := 0.0
			for i in per:
				var env := minf(minf(float(i) / attack, float(per - i) / release), 1.0)
				if floor_level > 0.0:
					env = floor_level + (1.0 - floor_level) * env
				env *= gain
				var s := 0.0
				match wave:
					"sine":
						s = sin(TAU * phase)
					"triangle":
						s = 4.0 * absf(phase - 0.5) - 1.0
					"square":
						s = 1.0 if phase < 0.5 else -1.0
					"saw":
						s = 2.0 * phase - 1.0
					"noise":
						s = dice.randf_range(-1.0, 1.0)
						if lowpass > 0.0:
							y += lowpass * (s - y)
							s = clampf(y * norm, -1.0, 1.0)
				out[base + i] += s * env
				phase += inc
				phase -= floorf(phase)
				inc *= bend
	var edge := int(round(float(def.get("edge", 0.0)) * float(rate)))   # a loop that never falls silent fades at its ends, so it joins without a click
	for i in mini(edge, out.size()):
		var f := float(i) / float(edge)
		out[i] *= f
		out[out.size() - 1 - i] *= f
	return out


## Samples as 16-bit little-endian sound, clipped to what 16 bits hold.
static func pcm(s: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(s.size() * 2)
	for i in s.size():
		out.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
	return out


## The stream of a cue or track, built the first time and kept; null for a name the data does not have.
static func stream(name: String) -> AudioStreamWAV:
	if _streams.has(name):
		return _streams[name]
	var def := def_of(name)
	if def.is_empty():
		return null
	var rate := rate_of(name)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = pcm(samples(def, rate))
	# A track is not looped by the engine: its loop wrap crashed the Android audio thread (a native SIGSEGV
	# about one track length after launch). The music player starts it again when it ends (_music_done); a
	# track ends in silence, so the join is as clean as a loop.
	_streams[name] = w
	built += 1
	return w


# ---------------------------------------------------------------- what plays when

## The cue of a battle event: the event type's own, or the first variant whose field the event matches.
## "" for an event the data does not list, which is silent.
static func cue_for(ev: Dictionary) -> String:
	var entry: Variant = data()["events"].get(str(ev.get("type", "")), "")
	if typeof(entry) == TYPE_STRING:
		return entry
	if typeof(entry) != TYPE_DICTIONARY:
		return ""
	for v in entry.get("variants", []):
		var have: Variant = ev.get(str(v["field"]))
		if typeof(have) == typeof(v["is"]) and have == v["is"]:
			return str(v["cue"])
	return str(entry.get("cue", ""))


## The cue for how a fight ended ("" for an ending with none, such as an escape, which has its own event).
static func result_cue(result: String) -> String:
	return str(data()["results"].get(result, ""))


## The sting a dynasty state opens with: the heir's death, the saga's end. "" for any other.
static func sting_for(state: String) -> String:
	return str(data()["stings"].get(state, ""))


## The track of an Age of the world, counted from 1: the listed ones in turn, going round again after the last.
static func age_track(age: int) -> String:
	var ages: Array = data()["ages"]
	if ages.is_empty():
		return ""
	return str(ages[posmod(age - 1, ages.size())])


## The track for where the game is: the title's with no dynasty, the fight's in a fight, the ended saga's
## (silence, after its sting), else the track of the world's Age. "" means no music.
static func track_for(d: GameDynasty) -> String:
	var screens: Dictionary = data()["screens"]
	if d == null:
		return str(screens["title"])
	if d.battle != null:
		return str(screens["battle"])
	if d.state == "ended":
		return str(screens["ended"])
	return age_track(d.age_number())


# ---------------------------------------------------------------- settings

## One value of the settings file, read once and kept until the file changes (every cue asks, and the file is not
## read each time): the key of what is kept is the path, how many times this run has stored, and the file's time.
static func _stored(key: String, fallback: Variant) -> Variant:
	var k := "%s|%d|%d" % [UiSettings.path, UiSettings.revision, FileAccess.get_modified_time(UiSettings.path)]
	if k != _skey:
		_skey = k
		_scache = {}
		var cf := ConfigFile.new()
		if cf.load(UiSettings.path) == OK and cf.has_section("ui"):
			for name in cf.get_section_keys("ui"):
				_scache[name] = cf.get_value("ui", name)
	return _scache.get(key, fallback)


## Whether sound effects ("sound"), music ("music") or ambience ("ambience") are on: on unless the file says off.
static func on(kind: String) -> bool:
	var v: Variant = _stored(kind, "on")
	return KINDS.has(kind) and not (typeof(v) == TYPE_STRING and str(v) == "off")


static func set_on(kind: String, yes: bool) -> bool:
	return KINDS.has(kind) and UiSettings.store(kind, "on" if yes else "off")


static func level_ids() -> Array:
	return (data()["level_order"] as Array).duplicate()


## The volume step in use for a kind: the stored one if the game knows it, else the default.
static func level(kind: String) -> String:
	var v: Variant = _stored(kind + "_volume", "")
	return str(v) if typeof(v) == TYPE_STRING and data()["levels"].has(str(v)) else str(data()["default_level"])


static func set_level(kind: String, id: String) -> bool:
	return KINDS.has(kind) and data()["levels"].has(id) and UiSettings.store(kind + "_volume", id)


## The menu's choice for a kind: "off", or the volume step in use.
static func choice(kind: String) -> String:
	return level(kind) if on(kind) else "off"


## Stores a choice from the menu: "off" switches the kind off and keeps its volume; a step switches it on at that step.
static func choose(kind: String, id: String) -> bool:
	if id == "off":
		return set_on(kind, false)
	return set_level(kind, id) and set_on(kind, true)


static func db(kind: String) -> float:
	return float(data()["levels"][level(kind)]["db"])


## Whether a line is shown for each sound (the menu's Captions for sounds, an accessibility option): off unless the file says on.
static func captions_on() -> bool:
	var v: Variant = _stored("sound_captions", false)
	return typeof(v) == TYPE_BOOL and bool(v)


## A loudness as decibels, with -80 for none.
static func _lin_db(g: float) -> float:
	return -80.0 if g <= 0.0001 else linear_to_db(minf(g, 1.0))


# ---------------------------------------------------------------- playing

## Whether there is anything to play to. Headless runs and the screenshot tool use the engine's Dummy driver:
## the streams are still built and handed to the players, but never started, since a looping track started
## there is never let go by the audio server and is reported as leaked when the run ends.
static func has_output() -> bool:
	return AudioServer.get_driver_name() != NO_OUTPUT


func _ready() -> void:
	_dice = CosmeticRng.loose()
	var scape := SoundScape.data()
	for i in int(data()["voices"]):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	for i in int(scape["fx_voices"]):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_fx.append(p)
	for i in 2:
		var p := AudioStreamPlayer.new()
		add_child(p)
		p.finished.connect(_music_done.bind(i))
		_mp.append(p)
	_music = _mp[0]
	for i in int(scape["bed_voices"]):
		var p := AudioStreamPlayer.new()
		add_child(p)
		p.finished.connect(_bed_done.bind(i))
		_beds.append({"p": p, "name": "", "gain": 0.0, "target": 0.0, "started": false})
	instant_fades = not has_output()
	instance = self
	_quiet_until = _now() + float(scape["ui"]["quiet_seconds"])
	get_tree().node_added.connect(_on_node)
	_scan(get_tree().root)
	if has_output():   # the sounds heard all the time are built before they are wanted, one after another
		_warm = SoundScape.used_names().filter(func(n): return data()["cues"].has(n))
		_warm.append_array(["rain", "wind", "town_murmur", "night_crickets", "town", "wild_meadow"])


## Leaving the tree (the game closing, a test ending): everything stops, so the audio server lets the streams go.
func _exit_tree() -> void:
	if get_tree() != null and get_tree().node_added.is_connected(_on_node):
		get_tree().node_added.disconnect(_on_node)
	for id in _jobs.values():
		WorkerThreadPool.wait_for_task_completion(id)
	_jobs = {}
	for p in _voices + _fx + _mp:
		p.stop()
		p.stream = null
	for ch in _beds:
		ch["p"].stop()
		ch["p"].stream = null
		ch["name"] = ""
	playing = ""
	if instance == self:
		instance = null


## The time the soundscape works by, in seconds.
func _now() -> float:
	return clock if clock >= 0.0 else float(Time.get_ticks_msec()) / 1000.0


## The cue of a creature's cry ("" for a creature the data gives no voice).
static func creature_cue(creature_id: String) -> String:
	return str(data().get("creature_voices", {}).get(creature_id, ""))


## A creature's cry: when it is hurt, or lower and slower when it dies. Silent for a creature with no voice.
func creature(creature_id: String, dying: bool = false) -> void:
	cue(creature_cue(creature_id), 0.7 if dying else 1.0)


## Plays a cue once (`pitch` scales it: below 1 is lower). Nothing happens with sound effects off, or for a name that is no cue ("" included).
func cue(name: String, pitch: float = 1.0) -> void:
	if not data()["cues"].has(name):
		return
	_caption_cue(name)
	if not on("sound"):
		return
	cue_log.append(name)
	if cue_log.size() > LOG_KEEP:
		cue_log = cue_log.slice(LOG_KEEP / 2)
	var p: AudioStreamPlayer = _voices[_next % _voices.size()]
	_next += 1
	var jitter := float(data()["pitch_jitter"])
	p.stream = stream(name)
	p.volume_db = db("sound")
	p.pitch_scale = pitch * (1.0 + _dice.randf_range(-jitter, jitter))
	if has_output():
		p.play()


## Plays the cue of a battle event, if it has one.
func event(ev: Dictionary) -> void:
	cue(cue_for(ev))


## A sound of the interface, the ground or the world, on a voice of its own so it never cuts a fight's: nothing for a
## name that is no cue or with sound effects off, and (with a sound output) nothing yet for one still being built.
func fx(name: String, pitch: float = 1.0, db_extra: float = 0.0) -> bool:
	if not data()["cues"].has(name):
		return false
	_caption_cue(name)
	if not on("sound"):
		return false
	if not prepare(name):
		return false
	fx_log.append(name)
	if fx_log.size() > LOG_KEEP:
		fx_log = fx_log.slice(LOG_KEEP / 2)
	var p: AudioStreamPlayer = _fx[_fx_next % _fx.size()]
	_fx_next += 1
	var jitter := float(data()["pitch_jitter"])
	p.stream = stream(name)
	p.volume_db = db("sound") + db_extra
	p.pitch_scale = pitch * (1.0 + _dice.randf_range(-jitter, jitter))
	if has_output():
		p.play()
	return true


# ---------------------------------------------------------------- building off the main thread

## Whether a sound's stream is ready to play. With no output (headless) it is built here at once; with one, a track or
## a bed or a cue not built yet is handed to a worker thread and this says no until the thread is done (_poll).
func prepare(name: String) -> bool:
	if _streams.has(name):
		return true
	if def_of(name).is_empty():
		return false
	if not has_output() and not force_threads:
		return stream(name) != null
	if not _jobs.has(name):
		_jobs[name] = WorkerThreadPool.add_task(_build_job.bind(name, def_of(name).duplicate(true), rate_of(name)))
	return false


func _build_job(name: String, def: Dictionary, rate: int) -> void:
	var bytes := pcm(samples(def, rate))
	_mutex.lock()
	_done[name] = bytes
	_mutex.unlock()


## Streams the worker threads have finished become ready, and what was waiting for them starts.
func _poll() -> void:
	if _jobs.is_empty():
		return
	_mutex.lock()
	var ready := _done.keys()
	var bytes := _done.duplicate()
	_done = {}
	_mutex.unlock()
	for name in ready:
		WorkerThreadPool.wait_for_task_completion(_jobs[name])
		_jobs.erase(name)
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = rate_of(name)
		w.stereo = false
		w.data = bytes[name]
		_streams[name] = w
		built += 1
	if not ready.is_empty():
		_apply_music()
		_apply_beds()


# ---------------------------------------------------------------- music

## Asks for a looping track ("" for silence). The one already sounding plays on; with music off it is only
## remembered, and starts if music is switched on. A new track swells in as the old one fades out.
func music(track: String) -> void:
	wanted = track
	if not on("music") or not data()["tracks"].has(track):
		stop_music()
		return
	if playing != track:
		playing = track
		music_log.append(track)
		if music_log.size() > LOG_KEEP:
			music_log = music_log.slice(LOG_KEEP / 2)
	_apply_music()


## Starts `playing` on the other music player (fading the old one out) once its stream is ready, and sets the volumes.
## A track still fading out that is wanted again is swelled back rather than started over.
func _apply_music() -> void:
	if playing != "" and _mname[_mi] != playing and prepare(playing):
		var old := _mi
		_mi = 1 - _mi
		_music = _mp[_mi]
		_mtarget[old] = 0.0
		_mtarget[_mi] = 1.0
		if _mname[_mi] != playing:
			_mname[_mi] = playing
			_mgain[_mi] = 0.0
			_music.stream = stream(playing)
			if has_output():
				_music.play()
		if instant_fades:
			_mgain[_mi] = 1.0
			_mgain[old] = 0.0
	_set_music_volumes()


func _set_music_volumes() -> void:
	for i in 2:
		if _mname[i] == "":
			continue
		if _mgain[i] <= 0.0 and _mtarget[i] <= 0.0:
			_mp[i].stop()
			_mname[i] = ""
			continue
		_mp[i].volume_db = db("music") + _lin_db(_mgain[i])


## The track ran out: play it again (a track loops). Stopping or changing the music never gets here.
func _music_done(i: int) -> void:
	if _mname[i] != "" and has_output():
		_mp[i].play()


func stop_music() -> void:
	playing = ""
	for i in 2:
		_mtarget[i] = 0.0
		if instant_fades:
			_mgain[i] = 0.0
	_set_music_volumes()


## After a setting changed: the music and the beds follow it at once (started, stopped or at their new volume).
func refresh() -> void:
	music(wanted)
	ambience(_bed_wish)


## Moves the swelling of the tracks and beds on by `delta` seconds (the frame's; tests call it with their own).
func step_fades(delta: float) -> void:
	var fade: Dictionary = SoundScape.data()["fade"]
	var moving := false
	var m := delta / maxf(0.01, float(fade["music"]))
	for i in 2:
		if _mgain[i] != _mtarget[i]:
			_mgain[i] = move_toward(_mgain[i], _mtarget[i], m)
			moving = true
	if moving:
		_set_music_volumes()
	moving = false
	var b := delta / maxf(0.01, float(fade["bed"]))
	for ch in _beds:
		if ch["name"] != "" and float(ch["gain"]) != float(ch["target"]):
			ch["gain"] = move_toward(float(ch["gain"]), float(ch["target"]), b)
			moving = true
	if moving:
		_set_bed_volumes()


# ---------------------------------------------------------------- beds

var _bed_wish: Dictionary = {}   # what was last asked for: bed -> level

## Asks for the beds that should loop now, as {bed: level 0 to 1}; the others fade out. With ambience off nothing is kept.
func ambience(want: Dictionary) -> void:
	_bed_wish = want
	var live: Dictionary = want if on("ambience") else {}
	for ch in _beds:
		if ch["name"] != "" and not live.has(ch["name"]):
			ch["target"] = 0.0
			if instant_fades:
				ch["gain"] = 0.0
	for name in live:
		var ch := _bed_for(str(name))
		if ch.is_empty():
			continue   # all the channels are busy with louder beds
		if ch["name"] != name:
			ch["name"] = str(name)
			ch["gain"] = 0.0
			ch["started"] = false
			bed_log.append(str(name))
			if bed_log.size() > LOG_KEEP:
				bed_log = bed_log.slice(LOG_KEEP / 2)
			_caption_text(str(SoundScape.data()["captions"]["beds"].get(name, "")))
		ch["target"] = float(live[name])
		if instant_fades:
			ch["gain"] = ch["target"]
	_apply_beds()


## The channel playing a bed, else a free one, else one that is fading out; {} when there is none.
func _bed_for(name: String) -> Dictionary:
	for ch in _beds:
		if ch["name"] == name:
			return ch
	for ch in _beds:
		if ch["name"] == "":
			return ch
	for ch in _beds:
		if float(ch["target"]) <= 0.0:
			ch["p"].stop()
			return ch
	return {}


func _apply_beds() -> void:
	for ch in _beds:
		var name: String = ch["name"]
		if name == "":
			continue
		if not bool(ch["started"]) and float(ch["target"]) > 0.0 and prepare(name):
			ch["p"].stream = stream(name)
			ch["started"] = true
			if has_output():
				ch["p"].play()
	_set_bed_volumes()


func _set_bed_volumes() -> void:
	for ch in _beds:
		if ch["name"] == "":
			continue
		if float(ch["gain"]) <= 0.0 and float(ch["target"]) <= 0.0:
			ch["p"].stop()
			ch["name"] = ""
			ch["started"] = false
			continue
		ch["p"].volume_db = db("ambience") + _lin_db(float(ch["gain"]))


func _bed_done(i: int) -> void:
	var ch: Dictionary = _beds[i]
	if ch["name"] != "" and bool(ch["started"]) and has_output():
		ch["p"].play()


## The beds sounding or on the way in, as {bed: target level} (what is fading out is left out).
func beds_now() -> Dictionary:
	var out := {}
	for ch in _beds:
		if ch["name"] != "" and float(ch["target"]) > 0.0:
			out[ch["name"]] = float(ch["target"])
	return out


# ---------------------------------------------------------------- the interface

## A click, a tab, a pane opening or closing: `key` is one of the soundscape's ui entries.
func ui(key: String) -> void:
	fx(str(SoundScape.data()["ui"].get(key, "")))


## Nothing of the interface sounds for the soundscape's quiet seconds (a screen has just been swapped in, and
## the panes that open themselves are not heard).
func quiet() -> void:
	_quiet_until = _now() + float(SoundScape.data()["ui"]["quiet_seconds"])


func _on_node(n: Node) -> void:
	if n is BaseButton:
		_wire_button(n)
	elif n is TabBar or n is TabContainer:
		n.tab_changed.connect(_on_tab)   # (a container and its own bar both tell: _on_tab sounds once)
	elif n is Control and (n.has_meta("pane") or n.has_meta("modal")):
		if _now() >= _quiet_until:
			ui("open")
			n.tree_exiting.connect(_pane_closing)


func _scan(n: Node) -> void:
	if n != self:
		_on_node(n)
	for c in n.get_children():
		_scan(c)


func _wire_button(b: BaseButton) -> void:
	if b.has_meta("snd"):
		return
	b.set_meta("snd", true)
	b.pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if _now() >= _quiet_until:
		ui("click")


func _on_tab(_i: int) -> void:
	var now := _now()
	if now >= _quiet_until and now - _last_tab > 0.05:
		_last_tab = now
		ui("tab")


## The control under the pointer, looked at each frame (no hover signals of the buttons': touch screens have none,
## TouchHint owns them): a new enabled button under a mouse ticks, at most once each `hover_gap`.
func _poll_hover() -> void:
	var h: Control = get_viewport().gui_get_hovered_control() if get_viewport() != null else null
	if h == _hovered:
		return
	_hovered = h
	if h is BaseButton:
		hover_on(h)


func hover_on(b: BaseButton) -> void:
	if b.disabled or UiSettings.touch() or TouchHint.finger or _now() < _quiet_until:
		return
	var now := _now()
	if now - _last_hover < float(SoundScape.data()["ui"]["hover_gap"]):
		return
	_last_hover = now
	ui("hover")


func _pane_closing() -> void:
	if _now() >= _quiet_until:
		ui("close")


# ---------------------------------------------------------------- footsteps

## A footstep on `kind` of ground ("grass", "sand", "snow", "stone", "wood", "water", or an alias such as "ford" or
## "floor"; any other name is grass). THE HOOK for whatever moves the heir: call it once per step taken. A step too
## soon after the last is dropped, and while something outside calls it the screen's own detection of steps stands down.
static func footstep(kind: String) -> void:
	if instance != null and is_instance_valid(instance):
		instance.step_sound(kind, true)


func step_sound(kind: String, outside: bool = false) -> void:
	var now := _now()
	if outside:
		_ext_until = now + 1.5
	var f: Dictionary = SoundScape.data()["footsteps"]
	if now - _last_step < float(f["gap"]):
		return
	_last_step = now
	_alt = not _alt
	var alt := float(f["alternate"])
	fx(SoundScape.step_cue(kind), 1.0 + (alt if _alt else -alt))


## A step told by the open-world screen's `footstep` signal (who walked, what kind of thing, the ground under it, which
## foot, its pace in tiles a second, its distance from the heir in tiles). The heir's is full; others' are quieter and
## quieter again the further they are, and none is heard beyond the data's range. Each walker has its own gap.
func on_footstep(who: String, kind: String, ground: String, foot: int, speed: float, near: float) -> void:
	var f: Dictionary = SoundScape.data()["footsteps"]
	var heir := who == "heir" or kind == "heir"
	if not heir and near > float(f["hear_tiles"]):
		return
	var now := _now()
	if now - float(_last_steps.get(who, -10.0)) < float(f["gap"]):
		return
	_last_steps[who] = now
	if _last_steps.size() > 64:
		_last_steps = {who: now}
	var alt := float(f["alternate"])
	var extra := 0.0 if heir else float(f["others_db"]) - near * float(f["far_db"])
	fx(SoundScape.step_cue(ground), 1.0 + (alt if foot == 1 else -alt) + clampf(speed - 4.0, -2.0, 4.0) * 0.01, extra)


# ---------------------------------------------------------------- captions

func _caption_cue(name: String) -> void:
	if not captions_on():
		return
	var c: Dictionary = SoundScape.data()["captions"]
	if c["cues"].has(name):
		_caption_text(str(c["cues"][name]))
	elif name.begins_with("cry_"):
		_caption_text(str(c["creature"]))


## A line of caption, if captions are on: the same line is not shown twice at once; a few show at a time.
func _caption_text(text: String) -> void:
	if text == "" or not captions_on():
		return
	var c: Dictionary = SoundScape.data()["captions"]
	for l in _caps:
		if l["text"] == text and float(l["left"]) > float(c["seconds"]) - 0.6:
			return
	caption_log.append(text)
	if caption_log.size() > LOG_KEEP:
		caption_log = caption_log.slice(LOG_KEEP / 2)
	_caps.append({"text": text, "left": float(c["seconds"])})
	while _caps.size() > int(c["max_lines"]):
		_caps.pop_front()
	_show_captions()


func _show_captions() -> void:
	if _caps.is_empty():
		if _cap_layer != null:
			_cap_layer.visible = false
		return
	if _cap_layer == null:
		_cap_layer = CanvasLayer.new()
		_cap_layer.layer = 90
		add_child(_cap_layer)
		_cap_label = Label.new()
		_cap_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_cap_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_cap_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_cap_label.offset_bottom = -72
		_cap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_cap_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cap_label.add_theme_font_size_override("font_size", 18)
		_cap_label.add_theme_color_override("font_color", Color(1, 1, 1))
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0, 0, 0, 0.72)
		box.set_content_margin_all(8)
		box.set_corner_radius_all(6)
		_cap_label.add_theme_stylebox_override("normal", box)
		_cap_layer.add_child(_cap_label)
	_cap_layer.visible = true
	_cap_label.text = "\n".join(_caps.map(func(l): return "[%s]" % l["text"]))


func _tick_captions(delta: float) -> void:
	if _caps.is_empty():
		return
	for l in _caps:
		l["left"] = float(l["left"]) - delta
	_caps = _caps.filter(func(l): return float(l["left"]) > 0.0)
	_show_captions()


# ---------------------------------------------------------------- following the world

func _process(delta: float) -> void:
	_poll()
	_poll_hover()
	if not _warm.is_empty() and _jobs.size() < 2:
		prepare(str(_warm.pop_front()))
	step_fades(delta)
	_tick_captions(delta)
	if app == null or app.dynasty == null:
		return
	_watch(delta)


## The open-world screen's sandbox, null on any other screen.
func _sandbox() -> GameSandbox:
	if app == null or app.current == null:
		return null
	var c: Object = app.current
	if "sb" in c and c.sb is GameSandbox:
		return c.sb
	return null


## The track to play for where the dynasty is: the open world's (the place, the time, a fight), else the Age's, a
## fight's, the title's.
func track_here(d: GameDynasty) -> String:
	var sb := _sandbox()
	if sb != null and d != null:
		return SoundScape.track(SoundScape.context(d, sb))
	return track_for(d)


## What to do each frame in the open world: a footstep when the heir's tile changes; and every `watch_seconds`
## the sounds of what happened (a door, a pickup, coins, gear, a level, a quest, a creature's alert), the music
## of the place and the beds of the weather. Reads the dynasty and the sandbox, never writes them.
func _watch(delta: float) -> void:
	var d: GameDynasty = app.dynasty
	var sb := _sandbox()
	if app.current != _screen:   # a screen was swapped in: its own panes opening are not heard
		_screen = app.current
		quiet()
		_tile = Vector2i(-99999, -99999)
	if app.current != null and app.current.has_signal("footstep") and not app.current.footstep.is_connected(on_footstep):
		app.current.footstep.connect(on_footstep)   # the walk tells of its steps: they are heard as it tells them
		_signal_steps = true
	elif app.current == null or not app.current.has_signal("footstep"):
		_signal_steps = false
	if sb != null and d.state == "life":
		if _tile != sb.heir:
			if _tile.x != -99999 and _tile_space == sb.space and _now() > _ext_until and d.battle == null and not _signal_steps:
				step_sound(SoundScape.ground_kind(d, sb))
			_tile = sb.heir
			_tile_space = sb.space
	_watch_wait -= delta
	if _watch_wait > 0.0:
		return
	_watch_wait = float(SoundScape.data()["watch_seconds"])
	var now := SoundScape.snapshot(d, sb)
	var w: Dictionary = SoundScape.data()["world"]
	for e in SoundScape.events(_snap, now):
		fx(str(w[e]))
	_snap = now
	if sb == null:
		ambience({})
		return
	var ctx := SoundScape.context(d, sb)
	music(SoundScape.track(ctx))
	ambience(SoundScape.beds(ctx))


# ---------------------------------------------------------------- checking the data

static func _def_problems(kind: String, name: String, def: Variant, max_seconds: float) -> Array:
	var bad: Array = []
	var what := "sound.json: %s '%s'" % [kind, name]
	if typeof(def) != TYPE_DICTIONARY:
		return ["%s is not a description" % what]
	for k in ["wave", "notes", "step", "attack", "release", "volume"]:
		if not def.has(k):
			bad.append("%s has no %s" % [what, k])
	if not bad.is_empty():
		return bad
	if not (data()["waves"] as Array).has(str(def["wave"])):
		bad.append("%s has the unknown wave '%s'" % [what, def["wave"]])
	if typeof(def["notes"]) != TYPE_ARRAY or (def["notes"] as Array).is_empty():
		return bad + ["%s has no notes" % what]
	var sounding := 0
	for n in def["notes"]:
		for v in (n if typeof(n) == TYPE_ARRAY else [n]):
			if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
				bad.append("%s has a note that is not a number" % what)
			elif float(v) != 0.0 and (float(v) < 21.0 or float(v) > 108.0):
				bad.append("%s has the note %s, outside 21 to 108 (0 is a rest)" % [what, str(v)])
			elif float(v) != 0.0:
				sounding += 1
	if sounding == 0:
		bad.append("%s is all rests: it would be silence" % what)
	var step := float(def["step"])
	if step < 0.02 or step > 4.0:
		bad.append("%s step must be 0.02 to 4 seconds" % what)
	if float(def["attack"]) < 0.0 or float(def["release"]) < 0.0 or float(def["attack"]) + float(def["release"]) > step + 0.0001:
		bad.append("%s attack and release must fit inside a step" % what)
	if float(def["volume"]) <= 0.0 or float(def["volume"]) > 1.0:
		bad.append("%s volume must be above 0 and at most 1" % what)
	if absf(float(def.get("slide", 0.0))) > 24.0:
		bad.append("%s slide must be within 24 semitones" % what)
	if def.has("lowpass") and (str(def["wave"]) != "noise" or float(def["lowpass"]) <= 0.0 or float(def["lowpass"]) > 1.0):
		bad.append("%s lowpass must be above 0 and at most 1, and only noise has one" % what)
	if def.has("floor") and (float(def["floor"]) < 0.0 or float(def["floor"]) > 0.95):
		bad.append("%s floor must be 0 to 0.95" % what)
	if def.has("edge") and (float(def["edge"]) <= 0.0 or float(def["edge"]) * 2.0 > seconds(def)):
		bad.append("%s edge must be above 0 and within half its length" % what)
	if kind == "bed" and (not def.has("edge") or typeof(def["notes"]) != TYPE_ARRAY):
		bad.append("%s is a loop that never falls silent, so it needs an edge to join without a click" % what)
	if seconds(def) > max_seconds:
		bad.append("%s lasts %.1f seconds, more than the %.1f allowed" % [what, seconds(def), max_seconds])
	return bad


static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = data()
	for k in ["rate", "music_rate", "voices", "pitch_jitter", "waves", "limits", "level_order", "default_level", "levels", "text", "cues", "tracks", "beds", "events", "results", "stings", "screens", "ages"]:
		if not dat.has(k):
			bad.append("sound.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	for id in dat.get("creature_voices", {}):
		if not dat["cues"].has(str(dat["creature_voices"][id])):
			bad.append("sound.json: creature_voices gives '%s' the cue '%s', which does not exist" % [id, dat["creature_voices"][id]])
	for k in ["rate", "music_rate"]:
		if int(dat[k]) < 8000 or int(dat[k]) > 48000:
			bad.append("sound.json: %s must be 8000 to 48000 samples a second" % k)
	if int(dat["voices"]) < 1 or int(dat["voices"]) > 16:
		bad.append("sound.json: voices must be 1 to 16")
	if float(dat["pitch_jitter"]) < 0.0 or float(dat["pitch_jitter"]) > 0.2:
		bad.append("sound.json: pitch_jitter must be 0 to 0.2")
	for k in ["effects", "music", "ambience", "off", "about"]:
		if str(dat["text"].get(k, "")).strip_edges() == "":
			bad.append("sound.json: text has no %s" % k)
	# the volume steps
	for id in dat["level_order"]:
		if not dat["levels"].has(id):
			bad.append("sound.json: level_order names '%s', which is not a level" % id)
	for id in dat["levels"]:
		var l: Dictionary = dat["levels"][id]
		if not (dat["level_order"] as Array).has(id):
			bad.append("sound.json: level '%s' is not in level_order, so the menu would not offer it" % id)
		if str(l.get("name", "")) == "" or str(l.get("name", "")) == str(dat["text"].get("off", "")):
			bad.append("sound.json: level '%s' needs a name of its own" % id)
		if not l.has("db") or float(l["db"]) > 0.0 or float(l["db"]) < -60.0:
			bad.append("sound.json: level '%s' db must be -60 to 0" % id)
	if id_is_off(dat["levels"]):
		bad.append("sound.json: no level may be called 'off'")
	if not dat["levels"].has(str(dat["default_level"])):
		bad.append("sound.json: default_level '%s' is not a level" % dat["default_level"])
	# every sound, and how much there is to build
	var limits: Dictionary = dat["limits"]
	var total := 0.0
	for name in dat["cues"]:
		bad.append_array(_def_problems("cue", name, dat["cues"][name], float(limits.get("max_cue_seconds", 0.0))))
		if dat["tracks"].has(name) or dat["beds"].has(name):
			bad.append("sound.json: '%s' is both a cue and a track or a bed" % name)
		if typeof(dat["cues"][name]) == TYPE_DICTIONARY:
			total += seconds(dat["cues"][name])
	for name in dat["tracks"]:
		bad.append_array(_def_problems("track", name, dat["tracks"][name], float(limits.get("max_track_seconds", 0.0))))
		if typeof(dat["tracks"][name]) == TYPE_DICTIONARY:
			total += seconds(dat["tracks"][name])
	for name in dat["beds"]:
		bad.append_array(_def_problems("bed", name, dat["beds"][name], float(limits.get("max_track_seconds", 0.0))))
		if dat["tracks"].has(name):
			bad.append("sound.json: '%s' is both a track and a bed" % name)
		if typeof(dat["beds"][name]) == TYPE_DICTIONARY:
			total += seconds(dat["beds"][name])
	if total > float(limits.get("max_total_seconds", 0.0)):
		bad.append("sound.json: %.1f seconds of sound in all, more than the %.1f allowed" % [total, float(limits.get("max_total_seconds", 0.0))])
	# what plays when
	var used: Dictionary = {}
	var scape_bad := SoundScape.validate(dat)
	if scape_bad.is_empty():
		for name in SoundScape.used_names():
			used[name] = true
	var spec := GameEventSpec.spec()
	for t in dat["events"]:
		var entry: Variant = dat["events"][t]
		if not spec.has(t):
			bad.append("sound.json: events lists '%s', which is not a battle event" % t)
			continue
		var cues: Array = []
		if typeof(entry) == TYPE_STRING:
			cues.append(entry)
		elif typeof(entry) == TYPE_DICTIONARY and entry.has("cue"):
			cues.append(str(entry["cue"]))
			for v in entry.get("variants", []):
				if typeof(v) != TYPE_DICTIONARY or not v.has("field") or not v.has("is") or not v.has("cue"):
					bad.append("sound.json: event '%s' has a variant without field, is and cue" % t)
					continue
				if not spec[t].get("fields", {}).has(v["field"]) and not spec[t].get("optional", {}).has(v["field"]):
					bad.append("sound.json: event '%s' has a variant on '%s', which is not a field of it" % [t, v["field"]])
				if typeof(v["is"]) != TYPE_BOOL and typeof(v["is"]) != TYPE_STRING:
					bad.append("sound.json: event '%s' variant on '%s' must compare with true, false or text" % [t, v["field"]])
				cues.append(str(v["cue"]))
		else:
			bad.append("sound.json: event '%s' must name a cue or be {cue, variants}" % t)
		for c in cues:
			used[c] = true
			if not dat["cues"].has(c):
				bad.append("sound.json: event '%s' plays '%s', which is not a cue" % [t, c])
	for pair in [["results", RESULTS], ["stings", STINGS]]:
		for k in dat[pair[0]]:
			var c := str(dat[pair[0]][k])
			used[c] = true
			if not (pair[1] as Array).has(k):
				bad.append("sound.json: %s lists '%s', which the game never asks for" % [pair[0], k])
			if not dat["cues"].has(c):
				bad.append("sound.json: %s '%s' plays '%s', which is not a cue" % [pair[0], k, c])
	for k in STINGS:
		if not dat["stings"].has(k):
			bad.append("sound.json: stings has nothing for '%s'" % k)
	for k in SCREENS:
		if not dat["screens"].has(k):
			bad.append("sound.json: screens has nothing for '%s'" % k)
	for k in dat["screens"]:
		var tr := str(dat["screens"][k])
		used[tr] = true
		if not SCREENS.has(k):
			bad.append("sound.json: screens lists '%s', which the game never asks for" % k)
		if tr != "" and not dat["tracks"].has(tr):
			bad.append("sound.json: screen '%s' plays '%s', which is not a track" % [k, tr])
	if (dat["ages"] as Array).is_empty():
		bad.append("sound.json: ages lists no track")
	for tr in dat["ages"]:
		used[str(tr)] = true
		if not dat["tracks"].has(str(tr)):
			bad.append("sound.json: ages names '%s', which is not a track" % tr)
	for id in dat.get("creature_voices", {}):
		used[str(dat["creature_voices"][id])] = true
	for name in (dat["cues"] as Dictionary).keys() + (dat["tracks"] as Dictionary).keys() + (dat["beds"] as Dictionary).keys():
		if not used.has(name):
			bad.append("sound.json: '%s' is never played" % name)
	bad.append_array(scape_bad)
	return bad


static func id_is_off(levels: Dictionary) -> bool:
	return levels.has("off")
