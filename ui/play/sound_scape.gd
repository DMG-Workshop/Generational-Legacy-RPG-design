## What sounds where and when (the data is data/ui/soundscape.json): the music of a place, the beds of weather,
## night, town and dungeon that loop under it, the ground a footstep falls on, and the sounds of things that
## happen to the heir, read by comparing one snapshot of the world with the last. Pure functions of the dynasty
## and the open-world screen's sandbox: no node, no dice, nothing saved, nothing written to the dynasty. Sound
## (ui/play/sound.gd) owns the players and calls these.
extends RefCounted

const PATH := "res://data/ui/soundscape.json"

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = GameData.load_json(PATH)
	return _cache


## Built data is forgotten (tests that change it).
static func forget() -> void:
	_cache = {}


# ---------------------------------------------------------------- the ground under a step

## The kind of ground a name stands for: a kind itself, an alias of one, else the default.
static func kind_of(name: String) -> String:
	var f: Dictionary = data()["footsteps"]
	if (f["kinds"] as Dictionary).has(name):
		return name
	return str(f["aliases"].get(name, f["default"]))


## The cue of a footstep on a kind of ground (any name kind_of knows).
static func step_cue(name: String) -> String:
	return str(data()["footsteps"]["kinds"][kind_of(name)])


## The ground the heir stands on, from the screen's sandbox: a room's floor, a dungeon's stone, water, a town's
## cobbles, snow while it snows, else the biome's. "grass" for anything unknown.
static func ground_kind(d: GameDynasty, sb: GameSandbox) -> String:
	var f: Dictionary = data()["footsteps"]
	var ctx := context(d, sb)
	if bool(ctx["dungeon"]):
		return kind_of(str(f["dungeon"]))
	if bool(ctx["indoors"]):
		return kind_of(str(f["indoors"]))
	if sb != null and sb.storey() > 0:
		return kind_of(str(f["upstairs"]))
	if bool(ctx["water"]):
		return kind_of(str(f["water"]))
	if bool(ctx["town"]):
		return kind_of(str(f["town"]))
	if str(ctx["precip"]) == "snow":
		return kind_of(str(f["snowing"]))
	return kind_of(str(f["biomes"].get(str(ctx["biome"]), f["default"])))


# ---------------------------------------------------------------- where the heir is

## Where the heir is, for the music and the beds: {fight, indoors, dungeon, town, biome, water, night, precip, fog,
## weather}. Without a sandbox (the text game's screens) the heir is in the open wilds of the plains.
static func context(d: GameDynasty, sb: GameSandbox) -> Dictionary:
	var look := GameDay.look(d)
	var ctx := {"fight": d.battle != null, "indoors": false, "dungeon": false, "town": false, "biome": "plains", "water": false,
		"night": bool(look["night"]), "precip": str(look["precip"]), "fog": float(look["fog"]), "weather": str(look["weather"])}
	if sb == null:
		return ctx
	if sb.space != "world":
		ctx["indoors"] = true
		ctx["dungeon"] = GameDungeons.is_dungeon(sb.space)
		return ctx
	var t := GameWorldGen.tile(d, sb.heir.x, sb.heir.y)
	ctx["biome"] = str(t["biome"])
	ctx["water"] = bool(t["water"])
	ctx["town"] = _in_town(sb.heir.x, sb.heir.y)
	return ctx


## Whether a tile is in a town: the ground of a place that is a town, or a town's cleared ground.
static func _in_town(x: int, z: int) -> bool:
	if GameWalls.cleared(x, z):
		return true
	var id := GameSpaces.at_tile(x, z)
	if id == GameSpaces.root_id():
		return false
	return str(GameWorld.place(str(GameSpaces.space(id).get("place", ""))).get("type", "")) == "town"


# ---------------------------------------------------------------- music and beds

## The track for a place (a context): the fight's, a dungeon's, a room's, a town's, the night's in the wilds, else the biome's.
static func track(ctx: Dictionary) -> String:
	var s: Dictionary = data()["scape"]
	if bool(ctx["fight"]):
		return str(s["fight"])
	if bool(ctx["dungeon"]):
		return str(s["dungeon"])
	if bool(ctx["indoors"]):
		return str(s["indoors"])
	if bool(ctx["town"]):
		return str(s["town"])
	if bool(ctx["night"]):
		return str(s["night"])
	return str(s["biomes"].get(str(ctx["biome"]), s["default"]))


static func _put(out: Dictionary, name: String, level: float) -> void:
	out[name] = maxf(float(out.get(name, 0.0)), clampf(level, 0.0, 1.0))


## The beds under the music, as {bed: level 0 to 1}, from the weather (GameDay.look: precipitation, fog), the biome's
## wind, the night, the town and the dungeon. Weather and night are quieter indoors.
static func beds(ctx: Dictionary) -> Dictionary:
	var a: Dictionary = data()["ambience"]
	var out := {}
	if bool(ctx["dungeon"]):
		for b in a["dungeon"]:
			_put(out, str(b[0]), float(b[1]))
		return out
	var weather := {}
	for b in a["precip"].get(str(ctx["precip"]), []):
		_put(weather, str(b[0]), float(b[1]))
	for b in a["weather"].get(str(ctx["weather"]), []):
		_put(weather, str(b[0]), float(b[1]))
	if float(ctx["fog"]) > float(a["fog"]["above"]):
		for b in a["fog"]["beds"]:
			_put(weather, str(b[0]), float(b[1]))
	if not bool(ctx["indoors"]):
		_put(weather, "wind", float(a["wind_biomes"].get(str(ctx["biome"]), 0.0)))
	var night := {}
	if bool(ctx["night"]) and not bool(ctx["indoors"]):
		var nb: Dictionary = a["night"]["biomes"]
		for b in nb.get(str(ctx["biome"]), a["night"]["default"]):
			_put(night, str(b[0]), float(b[1]) * (float(a["town_night"]) if bool(ctx["town"]) else 1.0))
	var muffle := float(a["indoors_muffle"]) if bool(ctx["indoors"]) else 1.0
	for src in [weather, night]:
		for k in src:
			if float(src[k]) > 0.0:
				_put(out, str(k), float(src[k]) * muffle)
	if bool(ctx["indoors"]):
		for b in a["indoors"]:
			_put(out, str(b[0]), float(b[1]))
	elif bool(ctx["town"]):
		for b in a["town"]:
			_put(out, str(b[0]), float(b[1]))
	return out


# ---------------------------------------------------------------- what happened

## What is read from the world to tell what happened since the last look: {heir, level, gold, bag, gear, quests, chasers, space, fight}.
static func snapshot(d: GameDynasty, sb: GameSandbox) -> Dictionary:
	var h := d.heir
	var chasers := 0
	var space := "world"
	if sb != null:
		space = sb.space
		for a in sb.creatures:
			if str(a.get("mode", "")) == "chase":
				chasers += 1
		for a in sb.denizens:
			if str(a.get("mode", "")) == "chase":
				chasers += 1
	return {"heir": h.id, "level": h.level, "gold": h.gold, "bag": h.inventory.size(),
		"gear": [str(h.equipment.get("weapon", "")), str(h.equipment.get("armor", "")), str(h.equipment.get("trinket", ""))],
		"quests": d.quests.done.size(), "chasers": chasers, "space": space, "fight": d.battle != null}


## The things that happened between two snapshots, in the order they are heard: door_open, door_close, pickup, coins,
## spend, equip, level_up, quest, alert, fight. Nothing for the first look ({}) or when the heir is another one
## (a succession is not a purchase).
static func events(prev: Dictionary, now: Dictionary) -> Array:
	var out: Array = []
	if prev.is_empty() or int(prev["heir"]) != int(now["heir"]):
		return out
	if str(prev["space"]) != str(now["space"]):
		if str(prev["space"]) == "world":
			out.append("door_open")
		elif str(now["space"]) == "world":
			out.append("door_close")
	if int(now["bag"]) > int(prev["bag"]):
		out.append("pickup")
	if int(now["gold"]) > int(prev["gold"]):
		out.append("coins")
	elif int(now["gold"]) < int(prev["gold"]):
		out.append("spend")
	for i in 3:
		if str(now["gear"][i]) != "" and str(now["gear"][i]) != str(prev["gear"][i]):
			out.append("equip")
			break
	if int(now["level"]) > int(prev["level"]):
		out.append("level_up")
	if int(now["quests"]) > int(prev["quests"]):
		out.append("quest")
	if bool(now["fight"]) and not bool(prev["fight"]):
		out.append("fight")
	elif int(now["chasers"]) > 0 and int(prev["chasers"]) == 0:
		out.append("alert")
	return out


# ---------------------------------------------------------------- the data

## Every cue and track the soundscape names, so nothing it plays is left out of the sounds' own check.
static func used_names() -> Array:
	var dat := data()
	var out: Array = []
	for k in ["click", "hover", "tab", "open", "close"]:
		out.append(str(dat["ui"][k]))
	out.append_array((dat["footsteps"]["kinds"] as Dictionary).values())
	out.append_array((dat["world"] as Dictionary).values())
	var s: Dictionary = dat["scape"]
	for k in ["fight", "dungeon", "indoors", "town", "night", "default"]:
		out.append(str(s[k]))
	out.append_array((s["biomes"] as Dictionary).values())
	var a: Dictionary = dat["ambience"]
	var lists: Array = [a["dungeon"], a["town"], a["indoors"], a["fog"]["beds"], a["night"]["default"]]
	lists.append_array((a["precip"] as Dictionary).values())
	lists.append_array((a["weather"] as Dictionary).values())
	lists.append_array((a["night"]["biomes"] as Dictionary).values())
	for l in lists:
		for b in l:
			out.append(str(b[0]))
	if not (a["wind_biomes"] as Dictionary).is_empty():
		out.append("wind")
	return out


## Problems with the soundscape data against the sounds in `snd` (sound.json's data), one readable line each; [] when it is sound.
static func validate(snd: Dictionary) -> Array:
	var bad: Array = []
	var dat := data()
	for k in ["fx_voices", "bed_voices", "watch_seconds", "fade", "ui", "footsteps", "world", "scape", "ambience", "captions"]:
		if not dat.has(k):
			bad.append("soundscape.json: %s is missing" % k)
	if not bad.is_empty():
		return bad
	var cues: Dictionary = snd["cues"]
	var tracks: Dictionary = snd["tracks"]
	var bed_defs: Dictionary = snd["beds"]
	if int(dat["fx_voices"]) < 1 or int(dat["fx_voices"]) > 16 or int(dat["bed_voices"]) < 1 or int(dat["bed_voices"]) > 8:
		bad.append("soundscape.json: fx_voices must be 1 to 16 and bed_voices 1 to 8")
	if float(dat["watch_seconds"]) <= 0.0 or float(dat["watch_seconds"]) > 2.0:
		bad.append("soundscape.json: watch_seconds must be above 0 and at most 2")
	for k in ["music", "bed"]:
		if not dat["fade"].has(k) or float(dat["fade"][k]) < 0.0 or float(dat["fade"][k]) > 10.0:
			bad.append("soundscape.json: fade.%s must be 0 to 10 seconds" % k)
	for k in ["click", "hover", "tab", "open", "close"]:
		if not cues.has(str(dat["ui"].get(k, ""))):
			bad.append("soundscape.json: ui.%s is not a cue" % k)
	for k in ["hover_gap", "quiet_seconds"]:
		if not dat["ui"].has(k) or float(dat["ui"][k]) < 0.0 or float(dat["ui"][k]) > 10.0:
			bad.append("soundscape.json: ui.%s must be 0 to 10 seconds" % k)
	var f: Dictionary = dat["footsteps"]
	for k in f["kinds"]:
		if not cues.has(str(f["kinds"][k])):
			bad.append("soundscape.json: footsteps kind '%s' plays '%s', which is not a cue" % [k, f["kinds"][k]])
	if not (f["kinds"] as Dictionary).has(str(f["default"])):
		bad.append("soundscape.json: footsteps.default is not a kind")
	for k in f["aliases"]:
		if not (f["kinds"] as Dictionary).has(str(f["aliases"][k])):
			bad.append("soundscape.json: footsteps alias '%s' names '%s', which is not a kind" % [k, f["aliases"][k]])
		if (f["kinds"] as Dictionary).has(str(k)):
			bad.append("soundscape.json: footsteps alias '%s' is a kind already" % k)
	for k in ["water", "town", "dungeon", "indoors", "upstairs", "snowing"]:
		if not (f["kinds"] as Dictionary).has(str(f.get(k, ""))):
			bad.append("soundscape.json: footsteps.%s is not a kind" % k)
	for b in GameWorldGen.data()["biomes"]:
		if not f["biomes"].has(str(b)):
			bad.append("soundscape.json: footsteps has no ground for the biome '%s'" % b)
		if not dat["scape"]["biomes"].has(str(b)):
			bad.append("soundscape.json: scape has no track for the biome '%s'" % b)
	for b in f["biomes"]:
		if not (f["kinds"] as Dictionary).has(str(f["biomes"][b])):
			bad.append("soundscape.json: biome '%s' has the ground '%s', which is not a kind" % [b, f["biomes"][b]])
	if float(f["gap"]) < 0.0 or float(f["gap"]) > 2.0 or float(f["alternate"]) < 0.0 or float(f["alternate"]) > 0.3:
		bad.append("soundscape.json: footsteps gap must be 0 to 2 seconds and alternate 0 to 0.3")
	for k in ["door_open", "door_close", "pickup", "coins", "spend", "equip", "level_up", "quest", "alert", "fight"]:
		if not cues.has(str(dat["world"].get(k, ""))):
			bad.append("soundscape.json: world.%s is not a cue" % k)
	var s: Dictionary = dat["scape"]
	for k in ["fight", "dungeon", "indoors", "town", "night", "default"]:
		if not tracks.has(str(s.get(k, ""))):
			bad.append("soundscape.json: scape.%s is not a track" % k)
	for b in s["biomes"]:
		if not tracks.has(str(s["biomes"][b])):
			bad.append("soundscape.json: scape biome '%s' plays '%s', which is not a track" % [b, s["biomes"][b]])
	var a: Dictionary = dat["ambience"]
	var lists: Array = [a["dungeon"], a["town"], a["indoors"], a["fog"]["beds"], a["night"]["default"]]
	lists.append_array((a["precip"] as Dictionary).values())
	lists.append_array((a["weather"] as Dictionary).values())
	lists.append_array((a["night"]["biomes"] as Dictionary).values())
	for l in lists:
		for b in l:
			if typeof(b) != TYPE_ARRAY or (b as Array).size() != 2 or not bed_defs.has(str(b[0])) or float(b[1]) <= 0.0 or float(b[1]) > 1.0:
				bad.append("soundscape.json: an ambience entry %s must be [a bed, a level above 0 and at most 1]" % str(b))
	for k in a["precip"]:
		if not ["rain", "snow"].has(str(k)):
			bad.append("soundscape.json: ambience.precip lists '%s', which GameDay never gives" % k)
	for k in a["weather"]:
		if not GameData.world["weather"].any(func(w): return str(w["id"]) == str(k)):
			bad.append("soundscape.json: ambience.weather lists '%s', which is not a weather" % k)
	for k in a["wind_biomes"]:
		if not GameWorldGen.data()["biomes"].has(str(k)) or float(a["wind_biomes"][k]) <= 0.0 or float(a["wind_biomes"][k]) > 1.0:
			bad.append("soundscape.json: ambience.wind_biomes '%s' must be a biome with a level above 0 and at most 1" % k)
	for k in a["night"]["biomes"]:
		if not GameWorldGen.data()["biomes"].has(str(k)):
			bad.append("soundscape.json: ambience.night lists '%s', which is not a biome" % k)
	if not bed_defs.has("wind"):
		bad.append("soundscape.json: there is no 'wind' bed, which the biomes' wind plays")
	if float(a["fog"]["above"]) < 0.0 or float(a["fog"]["above"]) > 1.0:
		bad.append("soundscape.json: ambience.fog.above must be 0 to 1")
	for k in ["indoors_muffle", "town_night"]:
		if float(a[k]) < 0.0 or float(a[k]) > 1.0:
			bad.append("soundscape.json: ambience.%s must be 0 to 1" % k)
	var c: Dictionary = dat["captions"]
	for k in c["cues"]:
		if not cues.has(str(k)):
			bad.append("soundscape.json: a caption for '%s', which is not a cue" % k)
		if str(c["cues"][k]).strip_edges() == "":
			bad.append("soundscape.json: the caption for '%s' is empty" % k)
	for k in c["beds"]:
		if not bed_defs.has(str(k)):
			bad.append("soundscape.json: a caption for '%s', which is not a bed" % k)
	for k in bed_defs:
		if not c["beds"].has(str(k)):
			bad.append("soundscape.json: the bed '%s' has no caption" % k)
	if float(c["seconds"]) <= 0.0 or float(c["seconds"]) > 10.0 or int(c["max_lines"]) < 1 or int(c["max_lines"]) > 6 or str(c.get("creature", "")) == "":
		bad.append("soundscape.json: captions need seconds above 0 and at most 10, max_lines 1 to 6 and a creature line")
	return bad
