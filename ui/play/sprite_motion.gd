## Walk and idle frames for the figures and creatures drawn on the open-world map, made in code from the
## sprites already there (no extra art to keep): a frame is the sprite with a row taken out where the data
## says. Taking a row out of the upper body lowers it a pixel (a breath, a step's bob, a wing beat; a held
## item goes with it) and taking one out of a leg's columns lifts that foot, so every frame keeps the
## sprite's size, margins and outline and is held to the same style checks (SpriteArt.check_sprite). The
## numbers are in data/art/animation.json: the frame names in each sequence, their timing, the shape of each
## kind of sprite and the overrides per class and creature. Which frame shows depends on the clock and a
## key, never on the dynasty's dice, and with reduced motion it is the plain sprite. Rendering only: nothing
## here touches the game's state or its dice.
extends RefCounted

const PATH := "res://data/art/animation.json"
const UiSettings := preload("res://ui/play/ui_settings.gd")
## The frames a sprite is made into; the data's sequences name them.
const NAMES := ["base", "squash", "lift_a", "lift_b"]
const CLEAR := Color(0, 0, 0, 0)

static var _data: Dictionary = {}
static var _loaded := false
static var _phase: Dictionary = {}   # key -> its idle offset, in seconds


static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		var v = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = v if typeof(v) == TYPE_DICTIONARY else {}
	return _data


static func reset() -> void:
	_loaded = false
	_data = {}
	_phase = {}


## The numbers of one sprite: its own override, then its kind's ("figure" or "creature"), then its shape's.
static func params(kind: String, id: String) -> Dictionary:
	var d := data()
	var out: Dictionary = {}
	var base: Variant = d.get(kind, {})
	if typeof(base) == TYPE_DICTIONARY:
		out = (base as Dictionary).duplicate()
	var table: Variant = d.get("classes" if kind == "figure" else "creatures", {})
	var over: Variant = (table as Dictionary).get(id, {}) if typeof(table) == TYPE_DICTIONARY else {}
	if typeof(over) == TYPE_DICTIONARY:
		out.merge(over, true)
	var shapes: Variant = d.get("shapes", {})
	var shape: Variant = (shapes as Dictionary).get(str(out.get("shape", "")), {}) if typeof(shapes) == TYPE_DICTIONARY else {}
	if typeof(shape) == TYPE_DICTIONARY:
		for k in shape:
			if not out.has(k):
				out[k] = shape[k]
	return out


## The frames of `img` (a sprite facing its own way): name -> Image, one for every name in NAMES. A sprite
## that cannot move in some way has that frame equal to its base.
static func images(img: Image, kind: String, id: String) -> Dictionary:
	var p := params(kind, id)
	var top := _top_row(img)
	var base := _bottom_row(img)
	var out := {"base": img, "squash": img, "lift_a": img, "lift_b": img}
	if top < 0:
		return out
	var w := img.get_width()
	var hi := -1
	match str(p.get("squash", "none")):
		"above_legs":
			hi = base - int(p.get("lift_rows", 3)) - 1
		"fraction":
			hi = top + int(floor(float(base - top + 1) * float(p.get("squash_fraction", 0.6))))
	var lo := maxi(top + 2, hi - int(p.get("squash_window", 5)))
	if hi >= lo:
		out["squash"] = _delete_row(img, _best_row(img, lo, hi, 0, w - 1), 0, w - 1, true, base)
	var lift := int(p.get("lift_rows", 3))
	if bool(p.get("legs", false)) and lift >= 2:
		var runs := _runs(img, base)
		if runs.size() >= 2:
			var groups := [[], []]
			for i in runs.size():
				groups[i % 2].append(runs[i])
			out["lift_a"] = _lift(img, groups[0], base, lift)
			out["lift_b"] = _lift(img, groups[1], base, lift)
	return out


## `img` with row `r` taken out of the columns x0..x1: the rows above it drop one (`down`), or the rows
## below it, down to `base`, rise one.
static func _delete_row(img: Image, r: int, x0: int, x1: int, down: bool, base: int) -> Image:
	var out := img.duplicate() as Image
	for x in range(x0, x1 + 1):
		if down:
			for y in range(r, 0, -1):
				out.set_pixel(x, y, img.get_pixel(x, y - 1))
			out.set_pixel(x, 0, CLEAR)
		else:
			for y in range(r, base):
				out.set_pixel(x, y, img.get_pixel(x, y + 1))
			out.set_pixel(x, base, CLEAR)
	return out


## Lifts the feet in the leg columns `runs` (each [x0, x1]) by taking a row out of the last `rows` rows.
static func _lift(img: Image, runs: Array, base: int, rows: int) -> Image:
	var out := img
	for run in runs:
		var r := _best_row(img, base - rows + 1, base - 1, int(run[0]), int(run[1]))
		out = _delete_row(out, r, int(run[0]), int(run[1]), false, base)
	return out


## The row in lo..hi whose neighbours above and below differ least in the columns x0..x1: taking it out
## shows the least.
static func _best_row(img: Image, lo: int, hi: int, x0: int, x1: int) -> int:
	var best := lo
	var best_score := 1 << 30
	for r in range(maxi(1, lo), hi + 1):
		var score := 0
		for x in range(x0, x1 + 1):
			var a := img.get_pixel(x, r - 1)
			var b := img.get_pixel(x, r + 1) if r + 1 < img.get_height() else CLEAR
			if (a.a > 0.0) != (b.a > 0.0):
				score += 4
			elif a.a > 0.0 and not a.is_equal_approx(b):
				score += 1
		if score < best_score:
			best_score = score
			best = r
	return best


## The legs: runs of opaque columns [x0, x1] on `row`.
static func _runs(img: Image, row: int) -> Array:
	var out: Array = []
	var start := -1
	for x in range(img.get_width() + 1):
		var on := x < img.get_width() and img.get_pixel(x, row).a > 0.0
		if on and start < 0:
			start = x
		elif not on and start >= 0:
			out.append([start, x - 1])
			start = -1
	return out


static func _top_row(img: Image) -> int:
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				return y
	return -1


static func _bottom_row(img: Image) -> int:
	for y in range(img.get_height() - 1, -1, -1):
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				return y
	return -1


# ---------------------------------------------------------------- choosing the frame

## One of the timing numbers, from the data (0 when missing).
static func timing(key: String) -> float:
	var t: Variant = data().get("timing", {})
	return float((t as Dictionary).get(key, 0.0)) if typeof(t) == TYPE_DICTIONARY else 0.0


## The sequence of frame names called `name` ("walk" or "idle").
static func sequence(name: String) -> Array:
	var seqs: Variant = data().get("sequences", {})
	var s: Variant = (seqs as Dictionary).get(name, []) if typeof(seqs) == TYPE_DICTIONARY else []
	return s if typeof(s) == TYPE_ARRAY else []


## The frame name to show at time `t` (seconds) for the thing called `key`: the walk sequence while it
## moves, the idle one otherwise (each key on a beat of its own, so a herd does not breathe together), and
## the plain "base" with reduced motion.
static func frame_name(key: String, moving: bool, t: float) -> String:
	if UiSettings.reduced_motion():
		return "base"
	var seq := sequence("walk" if moving else "idle")
	var step := timing("walk_frame" if moving else "idle_frame")
	if seq.is_empty() or step <= 0.0:
		return "base"
	var at := t + (0.0 if moving else _offset(key))
	return str(seq[posmod(int(floor(at / step)), seq.size())])


## The texture to draw: `frames` is name -> Texture2D (SpriteArt.hero_frames or creature_frames).
static func pick(frames: Dictionary, key: String, moving: bool, t: float) -> Texture2D:
	return frames.get(frame_name(key, moving, t), frames.get("base"))


## Whether something that was last seen to move at `moved_at` (seconds) still counts as moving at `now`.
static func still_moving(moved_at: float, now: float) -> bool:
	return now - moved_at < timing("move_hold")


## A key's own idle offset: a keyed cosmetic roll, kept.
static func _offset(key: String) -> float:
	if not _phase.has(key):
		var span := timing("idle_frame") * float(sequence("idle").size()) * timing("idle_spread")
		_phase[key] = CosmeticRng.keyed("idle:" + key).randf() * span
	return float(_phase[key])


# ---------------------------------------------------------------- the data's checks

## Problems with animation.json, one readable line each; [] when it is sound.
static func validate() -> Array:
	var out: Array = []
	var d := data()
	if d.is_empty():
		return ["animation: data/art/animation.json is missing or unreadable"]
	var t: Variant = d.get("timing", {})
	if typeof(t) != TYPE_DICTIONARY:
		out.append("animation: timing must be a table")
		t = {}
	for k in ["walk_frame", "idle_frame", "move_hold"]:
		if not (t.get(k) is float or t.get(k) is int) or float(t[k]) <= 0.0:
			out.append("animation: timing %s must be a number above 0" % k)
	if not (t.get("idle_spread") is float or t.get("idle_spread") is int) or float(t["idle_spread"]) < 0.0:
		out.append("animation: timing idle_spread must be a number, 0 or more")
	var seqs: Variant = d.get("sequences", {})
	for s in ["walk", "idle"]:
		if typeof(seqs) != TYPE_DICTIONARY or typeof(seqs.get(s)) != TYPE_ARRAY or (seqs[s] as Array).size() < 2:
			out.append("animation: sequence %s needs at least two frame names" % s)
			continue
		for n in seqs[s]:
			if not NAMES.has(str(n)):
				out.append("animation: sequence %s names the frame '%s', which is not one of %s" % [s, n, ", ".join(NAMES)])
	var shapes: Variant = d.get("shapes", {})
	if typeof(shapes) != TYPE_DICTIONARY or (shapes as Dictionary).is_empty():
		out.append("animation: shapes must be a table")
		shapes = {}
	for id in shapes:
		var sh: Variant = shapes[id]
		if typeof(sh) != TYPE_DICTIONARY or typeof(sh.get("legs")) != TYPE_BOOL or not ["above_legs", "fraction", "none"].has(str(sh.get("squash", ""))):
			out.append("animation: shape %s needs legs (true or false) and a squash of above_legs, fraction or none" % id)
		elif str(sh["squash"]) == "fraction" and not (float(sh.get("squash_fraction", 0.0)) > 0.0 and float(sh.get("squash_fraction", 0.0)) < 1.0):
			out.append("animation: shape %s needs a squash_fraction between 0 and 1" % id)
	for kind in ["figure", "creature"]:
		var base: Variant = d.get(kind)
		if typeof(base) != TYPE_DICTIONARY or not shapes.has(str(base.get("shape", ""))):
			out.append("animation: %s needs a shape that exists" % kind)
			continue
		out.append_array(_number_problems(kind, base))
	for group in [["classes", "figure"], ["creatures", "creature"]]:
		var table: Variant = d.get(group[0], {})
		if typeof(table) != TYPE_DICTIONARY:
			out.append("animation: %s must be a table" % group[0])
			continue
		for id in table:
			var o: Variant = table[id]
			if typeof(o) != TYPE_DICTIONARY:
				out.append("animation: %s %s must be a table" % [group[0], id])
				continue
			if o.has("shape") and not shapes.has(str(o["shape"])):
				out.append("animation: %s %s has the unknown shape '%s'" % [group[0], id, o["shape"]])
			out.append_array(_number_problems("%s %s" % [group[0], id], o))
			if group[0] == "classes" and not GameData.classes.has(str(id)):
				out.append("animation: there is no class called %s" % id)
			if group[0] == "creatures" and not GameData.creatures.any(func(c): return str(c.get("id", "")) == str(id)):
				out.append("animation: there is no creature called %s" % id)
	return out


static func _number_problems(name: String, p: Dictionary) -> Array:
	var out: Array = []
	for k in ["lift_rows", "squash_window"]:
		if p.has(k) and (not (p[k] is float or p[k] is int) or int(p[k]) < 1 or int(p[k]) > 12):
			out.append("animation: %s %s must be a whole number from 1 to 12" % [name, k])
	return out
