## The visual effects of the battle's basic actions: a slash arc on a blow, a spark where it lands, a gathering
## ring, a bolt and a burst in the spell's element colour, a shield, a puff of dust, a plume where a foe falls.
## Each is a few frames of small pixel art made here in code from data/art/effects.json (the shapes, sizes
## and frame counts; which effect an action and an element use; the element colours come from
## data/combat/elements.json), tinted when asked for and drawn at the same pixel size as the figures. They
## are looked at, never decided: the events and the log are the same with or without them, and with reduced
## motion none is shown. Rendering only: nothing here touches the game's state or its dice.
extends RefCounted

const PATH := "res://data/art/effects.json"
const SpriteArt := preload("res://ui/play/sprite_art.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const BattleSpeed := preload("res://ui/play/battle_speed.gd")
const SHAPES := ["arc", "ring", "rays", "puff", "plus", "shield", "ellipse", "diamond", "zap", "star"]
const AT := ["target", "caster", "path"]
const CLEAR := Color(0, 0, 0, 0)

static var _data: Dictionary = {}
static var _loaded := false
static var _cache: Dictionary = {}   # "id:tint" -> [Texture2D]


static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		var v = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = v if typeof(v) == TYPE_DICTIONARY else {}
	return _data


static func reset() -> void:
	_loaded = false
	_data = {}
	_cache = {}


## The elements of data/combat/elements.json: every one has a bolt and a burst.
static func element_ids() -> Array:
	var v = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat/elements.json"))
	return (v.get("elements", {}) as Dictionary).keys() if typeof(v) == TYPE_DICTIONARY and typeof(v.get("elements")) == TYPE_DICTIONARY else []


## The actions that have an effect.
static func actions() -> Array:
	return (data().get("actions", {}) as Dictionary).keys()


## The id of the effect an action shows for a spell of `element` ("" for none): "" when the action has none.
static func effect_id(action: String, element: String = "") -> String:
	var a: Variant = (data().get("actions", {}) as Dictionary).get(action)
	if typeof(a) != TYPE_DICTIONARY:
		return ""
	var e := str(a.get("effect", ""))
	if e.begins_with("element:"):
		var table: Dictionary = data().get("elements", {})
		var row: Variant = table.get(element, table.get("none", {}))
		return str((row as Dictionary).get(e.trim_prefix("element:"), "")) if typeof(row) == TYPE_DICTIONARY else ""
	return e


## Where the action's effect appears: "target", "caster" or "path" (from the caster to the target).
static func place(action: String) -> String:
	var a: Variant = (data().get("actions", {}) as Dictionary).get(action, {})
	return str((a as Dictionary).get("at", "target")) if typeof(a) == TYPE_DICTIONARY else "target"


## The colour of an action's effect: its own, or the spell element's from data/combat/elements.json.
static func tint_of(action: String, element: String = "") -> Color:
	var a: Variant = (data().get("actions", {}) as Dictionary).get(action, {})
	var t := str((a as Dictionary).get("tint", "")) if typeof(a) == TYPE_DICTIONARY else ""
	if t == "element":
		t = GameCombat.element_color(element) if element != "" else str(data().get("neutral_tint", "#e8e4f4"))
	return Color.html(t) if Color.html_is_valid(t) else Color.WHITE


## How many art pixels wide and high an effect is, (0, 0) when there is no such effect.
static func size_of(id: String) -> Vector2i:
	var e: Variant = (data().get("effects", {}) as Dictionary).get(id)
	if typeof(e) != TYPE_DICTIONARY or typeof(e.get("size")) != TYPE_ARRAY or (e["size"] as Array).size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(e["size"][0]), int(e["size"][1]))


static func frame_count(id: String) -> int:
	var e: Variant = (data().get("effects", {}) as Dictionary).get(id, {})
	return int((e as Dictionary).get("frames", 0)) if typeof(e) == TYPE_DICTIONARY else 0


## The frames of an effect as images (art pixels, facing right), in `tint`.
static func images(id: String, tint: Color) -> Array:
	var out: Array = []
	var e: Variant = (data().get("effects", {}) as Dictionary).get(id)
	var sz := size_of(id)
	if typeof(e) != TYPE_DICTIONARY or sz == Vector2i.ZERO:
		return out
	var pal := {"m": tint, "l": tint.lightened(0.5), "d": tint.darkened(0.45), "w": Color(1, 1, 1).lerp(tint, 0.12)}
	for i in frame_count(id):
		var img := Image.create_empty(sz.x, sz.y, false, Image.FORMAT_RGBA8)
		_draw(img, e, i, frame_count(id), pal)
		out.append(img)
	return out


## The frames as textures in the sprite atlas (scaled up by whole pixels like every sprite), made once.
static func textures(id: String, tint: Color) -> Array:
	var key := "%s:%s" % [id, tint.to_html(false)]
	if not _cache.has(key):
		var out: Array = []
		for img in images(id, tint):
			var big := (img as Image).duplicate() as Image
			big.resize(img.get_width() * SpriteArt.UPSCALE, img.get_height() * SpriteArt.UPSCALE, Image.INTERPOLATE_NEAREST)
			out.append(SpriteArt.atlas().add(big))
		_cache[key] = out
	return _cache[key]


## Makes every effect in every colour a fight can ask for, in one batch (a screen that wants them all ready; the battle screen makes each on its first use, in the middle of the events, never in a draw).
static func warm() -> void:
	SpriteArt.begin_batch()
	for el in element_ids() + [""]:
		for action in actions():
			var id := effect_id(action, str(el))
			if id != "":
				textures(id, tint_of(action, str(el)))
	SpriteArt.end_batch()


## Shows an action's effect in `parent` (a Control; positions are in its units): centred on `at`, `px` units to the art
## pixel, travelling to `to` when given (a bolt), mirrored when `flip`, starting after `delay` seconds. Frames
## step like a sprite's, a jump each. Returns the node, or null when there is none to show (no such effect,
## or reduced motion, which keeps only the figures' quick state changes).
static func play(parent: Control, action: String, element: String, at: Vector2, px: float, to: Vector2 = Vector2.INF, flip: bool = false, delay: float = 0.0) -> Control:
	if UiSettings.reduced_motion() or parent == null or not parent.is_inside_tree():
		return null
	var id := effect_id(action, element)
	var texs := textures(id, tint_of(action, element)) if id != "" else []
	if texs.is_empty():
		return null
	var e: Dictionary = data()["effects"][id]
	var size := Vector2(size_of(id)) * px
	var node := TextureRect.new()
	node.texture = texs[0]
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size = size
	node.pivot_offset = size * 0.5
	node.position = at - size * 0.5
	node.z_index = 2
	if flip and (to != Vector2.INF or bool(e.get("flip_for_foes", false))):
		node.scale.x = -1.0
	node.visible = delay <= 0.0
	parent.add_child(node)
	var step := float(data().get("frame_time", 0.05))
	var travel := float(data().get("travel_seconds", 0.2)) if to != Vector2.INF else 0.0
	var count := texs.size() if travel <= 0.0 else maxi(texs.size(), int(ceil(travel / step)))
	var t := BattleSpeed.tune(node.create_tween())
	if delay > 0.0:
		t.tween_interval(delay)
		t.tween_callback(func(): node.visible = true)
	for i in count:
		var tex: Texture2D = texs[i % texs.size()]
		t.tween_callback(func(): node.texture = tex)
		t.tween_interval(step)
	t.tween_callback(node.queue_free)
	if travel > 0.0:
		var m := BattleSpeed.tune(node.create_tween())
		m.tween_property(node, "position", to - size * 0.5, travel).set_delay(delay)
	return node


# ---------------------------------------------------------------- drawing the shapes

static func _dot(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


## One frame `i` of `n` of the shape `e` describes, drawn with the colours `pal` (m main, l light, d dark, w white).
static func _draw(img: Image, e: Dictionary, i: int, n: int, pal: Dictionary) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var cx := float(w - 1) * 0.5
	var cy := float(h - 1) * 0.5
	var last := float(maxi(1, n - 1))
	var life := float(i) / last   # 0 on the first frame, 1 on the last
	match str(e.get("shape", "")):
		"arc":
			var r0 := float(e.get("radius", 8))
			var half := float(e.get("width", 2)) * 0.5
			var start := float(e.get("start", -60))
			var sweep := float(e.get("sweep", 120))
			var end := start + sweep * float(i + 1) / float(n)
			var tail := start + sweep * float(maxi(0, i - 1)) / float(n) * 0.9
			for y in h:
				for x in w:
					var dx := float(x) - cx
					var dy := float(y) - cy
					var ang := rad_to_deg(atan2(dy, dx))
					if ang < tail or ang > end:
						continue
					var rel := (ang - tail) / maxf(1.0, end - tail)
					if absf(sqrt(dx * dx + dy * dy) - r0) <= half * (0.45 + 0.55 * rel):
						img.set_pixel(x, y, pal["w"] if rel > 0.66 else (pal["l"] if rel > 0.33 else pal["m"]))
		"ring":
			var r := float(e.get("radius", 4)) + float(e.get("step", 3)) * float(i)
			var wd := float(e.get("width", 1)) * 0.5 + 0.25
			for y in h:
				for x in w:
					var dx := float(x) - cx
					var dy := float(y) - cy
					if absf(sqrt(dx * dx + dy * dy) - r) <= wd:
						var thin := i == n - 1 and (x + y) % 2 == 1   # the last frame breaks up
						if not thin:
							img.set_pixel(x, y, pal["w"] if i == 0 else (pal["l"] if i < n - 1 else pal["m"]))
		"rays":
			var count := int(e.get("rays", 8))
			var from := float(e.get("inner", 1)) + float(e.get("step", 1)) * float(i)
			var len := float(e.get("length", 3))
			for k in count:
				var a := TAU * float(k) / float(count)
				for s in range(int(len) + 1):
					var r := from + float(s)
					_dot(img, roundi(cx + cos(a) * r), roundi(cy + sin(a) * r), pal["w"] if s == int(len) else pal["l"] if s > 0 else pal["m"])
		"puff":
			var blobs := int(e.get("blobs", 5))
			var spread := float(e.get("spread", 8))
			var rad := float(e.get("radius", 3))
			var rise := float(e.get("rise", 0))
			var grow := 0.45 + 0.55 * life
			for k in blobs:
				var a := 2.399963 * float(k) + 0.6   # the golden angle: an even scatter
				var d := spread * grow * (0.45 + 0.55 * fposmod(float(k) * 0.618, 1.0))
				var bx := cx + cos(a) * d
				var by := cy + sin(a) * d * 0.6 - rise * float(i)
				var br := maxf(1.0, rad * (1.0 - 0.45 * life) * (0.7 + 0.3 * fposmod(float(k) * 0.37, 1.0)))
				for y in range(int(by - br) - 1, int(by + br) + 2):
					for x in range(int(bx - br) - 1, int(bx + br) + 2):
						var dx := float(x) - bx
						var dy := float(y) - by
						if dx * dx + dy * dy <= br * br + 0.3:
							_dot(img, x, y, pal["l"] if (dx + dy) < -br * 0.5 else (pal["d"] if (dx + dy) > br * 0.7 else pal["m"]))
		"plus":
			var count := int(e.get("count", 4))
			var spread := float(e.get("spread", 8))
			for k in count:
				var a := 2.399963 * float(k)
				var d := spread * (0.35 + 0.65 * fposmod(float(k) * 0.618, 1.0))
				var sx := roundi(cx + cos(a) * d)
				var sy := roundi(cy + sin(a) * d * 1.1 - float(i) * 0.6)
				var phase := (i + k) % n   # each sparkle grows and shrinks on its own beat
				var arm := 1 if phase == 0 or phase == n - 1 else (2 if phase == 1 or phase == n - 2 else 1)
				if phase == 0 and k % 2 == 1:
					continue
				for s in range(1, arm + 1):
					for d4 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						_dot(img, sx + d4.x * s, sy + d4.y * s, pal["m"] if s == arm and arm > 1 else pal["l"])
				_dot(img, sx, sy, pal["w"])
		"shield":
			var r := float(e.get("radius", 8))
			var half := float(e.get("width", 2)) * 0.5
			var grow := minf(1.0, 0.5 + 0.5 * float(i))
			for y in h:
				for x in w:
					var dx := float(x) - 3.0
					var dy := float(y) - cy
					if dx < 0.0:
						continue
					var dist := sqrt(dx * dx + dy * dy)
					if absf(dist - r * grow) <= half and absf(rad_to_deg(atan2(dy, dx))) <= 75.0:
						img.set_pixel(x, y, pal["w"] if i == 1 else (pal["l"] if i < n - 1 else pal["m"]))
		"ellipse":
			var rx := float(e.get("rx", 3))
			var ry := float(e.get("ry", 3))
			if bool(e.get("tumble", false)) and i % 2 == 1:
				var t := rx
				rx = ry
				ry = t
			elif i % 2 == 1:
				rx = maxf(1.0, rx - 0.6)
				ry = maxf(1.0, ry - 0.6)   # a flicker
			var hx := float(w) - rx - 1.5   # the head leads at the right; the tail trails to the left
			for s in range(1, int(e.get("tail", 0)) + 1):
				_dot(img, roundi(hx - rx - float(s) + 1.0), roundi(cy), pal["d"] if s > 2 else pal["m"])
			for y in h:
				for x in w:
					var dx := (float(x) - hx) / rx
					var dy := (float(y) - cy) / ry
					var q := dx * dx + dy * dy
					if bool(e.get("square", false)):
						q = maxf(absf(dx), absf(dy)) * maxf(absf(dx), absf(dy))
					if q <= 1.05:
						if bool(e.get("hollow", false)) and q < 0.45:
							continue
						img.set_pixel(x, y, pal["w"] if q < 0.3 else (pal["l"] if q < 0.65 else pal["m"]))
		"diamond":
			var a := float(e.get("half_length", 5))
			var b := float(e.get("half_height", 2))
			var hx := float(w) - a - 1.0
			for s in range(1, int(e.get("tail", 0)) + 1):
				_dot(img, roundi(hx - a - float(s)), roundi(cy), pal["d"])
			for y in h:
				for x in w:
					var q := absf(float(x) - hx) / a + absf(float(y) - cy) / b
					if q <= 1.0:
						img.set_pixel(x, y, pal["w"] if q < 0.4 else (pal["l"] if q < 0.75 else pal["m"]))
		"zap":
			var segs := int(e.get("segments", 5))
			var amp := int(e.get("amplitude", 3))
			var vertical := bool(e.get("vertical", false))
			var length := (h if vertical else w) - 1
			var prev := Vector2i.ZERO
			for s in range(segs + 1):
				var along := roundi(float(length) * float(s) / float(segs))
				var off := 0 if s == 0 or s == segs else ((s * 5 + i * 3) % (amp * 2 + 1)) - amp
				var p := Vector2i(roundi(cy), along) if not vertical else Vector2i(roundi(cx), along)
				p.x += off if vertical else 0
				var q := Vector2i(along, roundi(cy) + off) if not vertical else Vector2i(roundi(cx) + off, along)
				if s > 0:
					_line(img, prev, q, pal)
				prev = q
		"star":
			var arm := int(e.get("arm", 4))
			var sx := roundi(cx)
			var sy := roundi(cy)
			var long := arm if i % 2 == 0 else arm - 1
			for s in range(1, long + 1):
				for d4 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					_dot(img, sx + d4.x * s, sy + d4.y * s, pal["l"] if s < long else pal["m"])
			for d4 in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				_dot(img, sx + d4.x, sy + d4.y, pal["m"])
			_dot(img, sx, sy, pal["w"])


## A line of pixels from `a` to `b`: the glow in the main colour, the core in white.
static func _line(img: Image, a: Vector2i, b: Vector2i, pal: Dictionary) -> void:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for s in range(steps + 1):
		var p := Vector2(a) + Vector2(b - a) * (float(s) / float(maxi(1, steps)))
		var x := roundi(p.x)
		var y := roundi(p.y)
		for d4 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if img.get_pixel(clampi(x + d4.x, 0, img.get_width() - 1), clampi(y + d4.y, 0, img.get_height() - 1)).a <= 0.0:
				_dot(img, x + d4.x, y + d4.y, pal["m"])
		_dot(img, x, y, pal["w"])


# ---------------------------------------------------------------- the data's checks

## Problems with effects.json, one readable line each; [] when it is sound.
static func validate() -> Array:
	var out: Array = []
	var d := data()
	if d.is_empty():
		return ["effects: data/art/effects.json is missing or unreadable"]
	if not Color.html_is_valid(str(d.get("neutral_tint", ""))):
		out.append("effects: neutral_tint must be a colour")
	for k in ["frame_time", "travel_seconds"]:
		if not (d.get(k) is float or d.get(k) is int) or float(d[k]) <= 0.0:
			out.append("effects: %s must be a number above 0" % k)
	var effects: Variant = d.get("effects", {})
	if typeof(effects) != TYPE_DICTIONARY or (effects as Dictionary).is_empty():
		return out + ["effects: effects must be a table"]
	for id in effects:
		var e: Variant = effects[id]
		if typeof(e) != TYPE_DICTIONARY or not SHAPES.has(str((e as Dictionary).get("shape", ""))):
			out.append("effects: %s needs a shape, one of %s" % [id, ", ".join(SHAPES)])
			continue
		var sz := size_of(str(id))
		if sz.x < 3 or sz.y < 3 or sz.x > 40 or sz.y > 40:
			out.append("effects: %s needs a size [w, h] from 3 to 40 a side" % id)
		if int(e.get("frames", 0)) < 2 or int(e.get("frames", 0)) > 8:
			out.append("effects: %s needs from 2 to 8 frames" % id)
		else:
			var made := images(str(id), Color.WHITE)
			if made.size() != int(e["frames"]) or made.any(func(img): return _blank(img)):
				out.append("effects: %s draws a blank frame" % id)
	var actions_t: Variant = d.get("actions", {})
	if typeof(actions_t) != TYPE_DICTIONARY:
		return out + ["effects: actions must be a table"]
	var elements: Variant = d.get("elements", {})
	if typeof(elements) != TYPE_DICTIONARY or not (elements as Dictionary).has("none"):
		out.append("effects: elements needs a row for 'none' (a spell with no element)")
		elements = {}
	for el in element_ids():
		if not (elements as Dictionary).has(el):
			out.append("effects: the element %s has no bolt and burst" % el)
	for el in elements:
		var row: Variant = elements[el]
		for k in ["bolt", "burst"]:
			if typeof(row) != TYPE_DICTIONARY or not (effects as Dictionary).has(str((row as Dictionary).get(k, ""))):
				out.append("effects: element %s needs a %s that is an effect" % [el, k])
	for a in ["attack", "hit", "cast", "bolt", "burst", "guard", "flee", "defeat", "heal", "dodge"]:
		if not (actions_t as Dictionary).has(a):
			out.append("effects: the action %s has no effect" % a)
	for a in actions_t:
		var row: Variant = actions_t[a]
		if typeof(row) != TYPE_DICTIONARY:
			out.append("effects: action %s must be a table" % a)
			continue
		var eff := str(row.get("effect", ""))
		if eff.begins_with("element:"):
			if not ["bolt", "burst"].has(eff.trim_prefix("element:")):
				out.append("effects: action %s names %s, which is not element:bolt or element:burst" % [a, eff])
		elif not (effects as Dictionary).has(eff):
			out.append("effects: action %s names the effect '%s', which does not exist" % [a, eff])
		if str(row.get("tint", "")) != "element" and not Color.html_is_valid(str(row.get("tint", ""))):
			out.append("effects: action %s needs a tint that is a colour or 'element'" % a)
		if not AT.has(str(row.get("at", ""))):
			out.append("effects: action %s needs an 'at' of %s" % [a, ", ".join(AT)])
	return out


static func _blank(img: Image) -> bool:
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				return false
	return true
