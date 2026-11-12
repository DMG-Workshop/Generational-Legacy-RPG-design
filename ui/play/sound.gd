## Sound and music (roadmap item 15). There are no recorded files: every cue and track is described in
## data/ui/sound.json (a waveform, notes, an envelope, a length, a volume), built into an AudioStreamWAV the
## first time it is wanted and kept. `GameApp` adds one of these (`app.sound`) and the screens ask it: `cue`
## plays a sound once, `event` the cue of a battle event, `music` a looping track. Whether each is on, and how
## loud, is in settings.cfg beside the text size, never in the save. View side only: nothing in core/game
## knows of it, it reads a fight's events and never touches a dynasty, and its only dice are CosmeticRng's.
## With no audio device (headless runs, the screenshot tool) the players are never started; `cue_log` and
## `music_log` say what was asked for, which is what the tests read.
extends Node

const UiSettings := preload("res://ui/play/ui_settings.gd")
const PATH := "res://data/ui/sound.json"
const KINDS := ["sound", "music"]   # the two settings: sound effects and music
const RESULTS := ["victory", "defeat", "fled"]   # how a fight can end (GameBattle.result)
const STINGS := ["succession", "ended"]   # the dynasty states that open with a sting
const SCREENS := ["title", "battle", "ended"]   # the screens with a track of their own

static var _cache: Dictionary = {}
static var _streams: Dictionary = {}   # name -> AudioStreamWAV, built once
static var built := 0   # how many streams have been built (tests: the cache is used)

var cue_log: Array = []     # every cue started, in order (the last `LOG_KEEP` at most)
var music_log: Array = []   # every track started, in order
var playing := ""           # the track sounding now, "" for none
var wanted := ""            # the track the screens last asked for, played when music is switched on
var _voices: Array = []
var _next := 0
var _music: AudioStreamPlayer
var _dice: RandomNumberGenerator

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


## The description of a cue or a track, empty for a name that is neither.
static func def_of(name: String) -> Dictionary:
	var dat := data()
	if dat["cues"].has(name):
		return dat["cues"][name]
	return dat["tracks"].get(name, {})


static func is_track(name: String) -> bool:
	return data()["tracks"].has(name)


static func rate_of(name: String) -> int:
	return int(data()["music_rate" if is_track(name) else "rate"])


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
	var dice: RandomNumberGenerator = CosmeticRng.keyed("sound:" + JSON.stringify(def)) if wave == "noise" else null
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
				var env := minf(minf(float(i) / attack, float(per - i) / release), 1.0) * gain
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
				out[base + i] += s * env
				phase += inc
				phase -= floorf(phase)
				inc *= bend
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
	if is_track(name):
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / 2
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

## Whether sound effects ("sound") or music ("music") are on: on unless the file says off.
static func on(kind: String) -> bool:
	var v: Variant = UiSettings.stored(kind, "on")
	return KINDS.has(kind) and not (typeof(v) == TYPE_STRING and str(v) == "off")


static func set_on(kind: String, yes: bool) -> bool:
	return KINDS.has(kind) and UiSettings.store(kind, "on" if yes else "off")


static func level_ids() -> Array:
	return (data()["level_order"] as Array).duplicate()


## The volume step in use for a kind: the stored one if the game knows it, else the default.
static func level(kind: String) -> String:
	var v: Variant = UiSettings.stored(kind + "_volume", "")
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


# ---------------------------------------------------------------- playing

## Whether there is anything to play to. Headless runs and the screenshot tool use the engine's Dummy driver:
## the streams are still built and handed to the players, but never started, since a looping track started
## there is never let go by the audio server and is reported as leaked when the run ends.
static func has_output() -> bool:
	return AudioServer.get_driver_name() != NO_OUTPUT


func _ready() -> void:
	_dice = CosmeticRng.loose()
	for i in int(data()["voices"]):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)


## Leaving the tree (the game closing, a test ending): everything stops, so the audio server lets the streams go.
func _exit_tree() -> void:
	for p in _voices:
		p.stop()
		p.stream = null
	_music.stop()
	_music.stream = null
	playing = ""


## Plays a cue once. Nothing happens with sound effects off, or for a name that is no cue ("" included).
func cue(name: String) -> void:
	if not on("sound") or not data()["cues"].has(name):
		return
	cue_log.append(name)
	if cue_log.size() > LOG_KEEP:
		cue_log = cue_log.slice(LOG_KEEP / 2)
	var p: AudioStreamPlayer = _voices[_next % _voices.size()]
	_next += 1
	var jitter := float(data()["pitch_jitter"])
	p.stream = stream(name)
	p.volume_db = db("sound")
	p.pitch_scale = 1.0 + _dice.randf_range(-jitter, jitter)
	if has_output():
		p.play()


## Plays the cue of a battle event, if it has one.
func event(ev: Dictionary) -> void:
	cue(cue_for(ev))


## Asks for a looping track ("" for silence). The one already sounding plays on; with music off it is only
## remembered, and starts if music is switched on.
func music(track: String) -> void:
	wanted = track
	if not on("music") or not data()["tracks"].has(track):
		stop_music()
		return
	_music.volume_db = db("music")
	if playing == track:
		return
	playing = track
	music_log.append(track)
	if music_log.size() > LOG_KEEP:
		music_log = music_log.slice(LOG_KEEP / 2)
	_music.stream = stream(track)
	if has_output():
		_music.play()


func stop_music() -> void:
	playing = ""
	_music.stop()


## After a setting changed: the music follows it at once (started, stopped or at its new volume).
func refresh() -> void:
	music(wanted)


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
	if seconds(def) > max_seconds:
		bad.append("%s lasts %.1f seconds, more than the %.1f allowed" % [what, seconds(def), max_seconds])
	return bad


static func validate() -> Array:
	var bad: Array = []
	var dat: Dictionary = data()
	for k in ["rate", "music_rate", "voices", "pitch_jitter", "waves", "limits", "level_order", "default_level", "levels", "text", "cues", "tracks", "events", "results", "stings", "screens", "ages"]:
		if not dat.has(k):
			bad.append("sound.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	for k in ["rate", "music_rate"]:
		if int(dat[k]) < 8000 or int(dat[k]) > 48000:
			bad.append("sound.json: %s must be 8000 to 48000 samples a second" % k)
	if int(dat["voices"]) < 1 or int(dat["voices"]) > 16:
		bad.append("sound.json: voices must be 1 to 16")
	if float(dat["pitch_jitter"]) < 0.0 or float(dat["pitch_jitter"]) > 0.2:
		bad.append("sound.json: pitch_jitter must be 0 to 0.2")
	for k in ["effects", "music", "off", "about"]:
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
		if dat["tracks"].has(name):
			bad.append("sound.json: '%s' is both a cue and a track" % name)
		if typeof(dat["cues"][name]) == TYPE_DICTIONARY:
			total += seconds(dat["cues"][name])
	for name in dat["tracks"]:
		bad.append_array(_def_problems("track", name, dat["tracks"][name], float(limits.get("max_track_seconds", 0.0))))
		if typeof(dat["tracks"][name]) == TYPE_DICTIONARY:
			total += seconds(dat["tracks"][name])
	if total > float(limits.get("max_total_seconds", 0.0)):
		bad.append("sound.json: %.1f seconds of sound in all, more than the %.1f allowed" % [total, float(limits.get("max_total_seconds", 0.0))])
	# what plays when
	var used: Dictionary = {}
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
	for name in (dat["cues"] as Dictionary).keys() + (dat["tracks"] as Dictionary).keys():
		if not used.has(name):
			bad.append("sound.json: '%s' is never played" % name)
	return bad


static func id_is_off(levels: Dictionary) -> bool:
	return levels.has("off")
