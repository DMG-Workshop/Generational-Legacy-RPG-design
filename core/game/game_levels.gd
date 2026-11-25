## Creature levels in the open world (data/world/sandbox.json `levels`). Each creature the open world spawns has a level of its own: the
## heir's level times a ratio drawn from the weighted bands (most near the heir's, some far below, a few above) times the place's
## danger. The ratio is a keyed hash of the dynasty's seed and the spawn tile, never the dynasty's dice, so a tile holds the same
## kind of creature every time. A fight begun by contact builds its foes at those levels, scales their xp by how the level stands
## against the heir's (`con`, the band id), and lets the weak ones run away (GameBattle). Nothing here is used by hunts, legends,
## dungeons or the autopilot, so their seeded play is exactly what it was.
## Run: godot --headless --path . -s res://tests/test_game_levels.gd
class_name GameLevels
extends RefCounted


static func data() -> Dictionary:
	return GameSandbox.data()["levels"]


static func bands() -> Array:
	return data()["bands"]


static func band(id: String) -> Dictionary:
	for b in bands():
		if str(b["id"]) == id:
			return b
	return {}


## The ratio of a creature's level to the heir's for the creature the tile (x, z) holds: a band by weight, then a point in its range.
static func ratio_at(seed_value: int, x: int, z: int) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, "creature_level", x, z])
	var total := 0.0
	for b in bands():
		total += float(b["weight"])
	var pick := r.randf() * total
	var chosen: Dictionary = bands().back()
	for b in bands():
		pick -= float(b["weight"])
		if pick < 0.0:
			chosen = b
			break
	return lerpf(float(chosen["lo"]), float(chosen["hi"]), r.randf())


## The level of the creature on tile (x, z) when the heir is at `heir_level` in a place of `danger`.
static func level_at(seed_value: int, x: int, z: int, heir_level: int, danger: float) -> int:
	return maxi(1, int(round(float(heir_level) * ratio_at(seed_value, x, z) * danger)))


## The danger of the place the dynasty is in (1 when it has none).
static func danger_of(d: GameDynasty) -> float:
	return float(d.world.here().get("danger", 1.0))


## The level the open world gives the creature on a tile for this dynasty now.
static func level_for(d: GameDynasty, x: int, z: int) -> int:
	return level_at(d.seed_value, x, z, d.heir.level, danger_of(d))


## The band id of a creature of `level` against a heir of `heir_level`: the first band whose `con_below` its ratio is under, else the last.
static func con(level: int, heir_level: int) -> String:
	var ratio := float(level) / float(maxi(1, heir_level))
	var list := bands()
	for i in list.size() - 1:
		if ratio < float(list[i]["con_below"]):
			return str(list[i]["id"])
	return str(list.back()["id"])


## The share of its xp a foe of that band gives.
static func con_xp(id: String) -> float:
	return float(band(id).get("con_xp", 1.0))


static func fearful_band(id: String) -> bool:
	return id in (data()["flee_bands"] as Array)


static func flee_share() -> float:
	return float(data()["flee_hp_share"])


static func flee_chance() -> float:
	return float(data()["flee_chance"])


static func mark(id: String) -> String:
	return str(band(id).get("mark", ""))


static func band_name(id: String) -> String:
	return str(band(id).get("name", id))


## A foe built by GameDynasty._make_enemy, given its band, its share of xp (at least 1) and, in a fearful band, the nerve to run.
static func dress(foe: Dictionary, heir_level: int) -> void:
	var id := con(int(foe["level"]), heir_level)
	foe["con"] = id
	foe["xp"] = maxi(1, int(round(float(foe["xp"]) * con_xp(id)))) if int(foe["xp"]) > 0 else 0
	if fearful_band(id) and not bool(foe.get("boss", false)):
		foe["fearful"] = true


## The text colour token of a band as a name for the screen (dim, good, text, accent, bad).
static func color_token(id: String) -> String:
	return str(band(id).get("color", "text"))


static func validate() -> Array:
	var bad: Array = []
	var lv: Variant = GameSandbox.data().get("levels", null)
	if typeof(lv) != TYPE_DICTIONARY:
		return ["sandbox.json: levels is missing"]
	for k in ["bands", "flee_bands", "flee_hp_share", "flee_chance"]:
		if not (lv as Dictionary).has(k):
			bad.append("sandbox.json: levels.%s is missing" % k)
	if not bad.is_empty():
		return bad
	var seen := {}
	var last := 0.0
	var list: Array = lv["bands"]
	if list.size() < 2:
		bad.append("sandbox.json: levels.bands needs at least two bands")
	for i in list.size():
		var b: Dictionary = list[i]
		for k in ["id", "name", "lo", "hi", "weight", "con_below", "con_xp", "mark", "color"]:
			if not b.has(k):
				bad.append("sandbox.json: a level band has no %s" % k)
		if not bad.is_empty():
			return bad
		var id := str(b["id"])
		if seen.has(id):
			bad.append("sandbox.json: level band '%s' is listed twice" % id)
		seen[id] = true
		if float(b["lo"]) <= 0.0 or float(b["hi"]) < float(b["lo"]):
			bad.append("sandbox.json: level band '%s' needs 0 < lo <= hi" % id)
		if float(b["weight"]) <= 0.0:
			bad.append("sandbox.json: level band '%s' needs a weight above 0" % id)
		if float(b["con_xp"]) <= 0.0:
			bad.append("sandbox.json: level band '%s' needs a con_xp above 0" % id)
		if str(b["mark"]) == "":
			bad.append("sandbox.json: level band '%s' needs a mark (colour is never the only cue)" % id)
		if str(b["color"]) not in ["dim", "good", "text", "accent", "bad"]:
			bad.append("sandbox.json: level band '%s' has the unknown colour '%s'" % [id, b["color"]])
		if i < list.size() - 1:
			if float(b["con_below"]) <= last:
				bad.append("sandbox.json: con_below must rise from band to band ('%s')" % id)
			last = float(b["con_below"])
	for id in lv["flee_bands"]:
		if not seen.has(str(id)):
			bad.append("sandbox.json: flee band '%s' is not a band" % id)
	if float(lv["flee_hp_share"]) <= 0.0 or float(lv["flee_hp_share"]) >= 1.0:
		bad.append("sandbox.json: flee_hp_share must be between 0 and 1")
	if float(lv["flee_chance"]) <= 0.0 or float(lv["flee_chance"]) > 1.0:
		bad.append("sandbox.json: flee_chance must be above 0 and at most 1")
	return bad
