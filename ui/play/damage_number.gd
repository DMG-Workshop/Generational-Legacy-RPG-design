## The floating numbers and words of a fight: a damage number that pops and rises (bigger and gold with "!" for a crit,
## the word "miss" or "block" for a blow that did nothing, a green "+8" for a heal) and the small badge that pops where a
## status lands. Every one says what it is in text, so colour is never the only cue. Look only: nothing here touches the
## fight. Motion goes through UiSettings.motion_time (with reduced motion a number stays where it is and fades), and the
## sideways drift of a number comes from a CosmeticRng keyed hash, not from the dynasty's dice.
extends RefCounted

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const CosmeticRng := preload("res://ui/play/cosmetic_rng.gd")
const HitFx := preload("res://ui/play/hit_fx.gd")


## The colour a number kind is drawn in. `against_party` is a blow that lands on the heir or a companion.
static func color_of(kind: String, against_party: bool) -> Color:
	match kind:
		"crit":
			return Color(str((HitFx.data().get("numbers", {}) as Dictionary).get("crit_color", "#ffd24a")))
		"heal":
			return Kit.good()
		"miss", "block":
			return Kit.dim()
		"hit", "tick":
			return Kit.bad() if against_party else Color.WHITE
	return Color.WHITE


## Where the k-th number on one figure within one action starts, so a flurry fans out rather than piles up.
static func stagger(k: int) -> Vector2:
	var rows := maxi(1, int(HitFx.num("numbers", "stagger_rows")))
	var px := HitFx.num("numbers", "stagger_px")
	return Vector2(px * float(k / rows), -px * float(k % rows) * 0.5)


## Floats `text` up from `pos` (in `parent`'s units) and frees it. `key` makes the drift the same for the same event.
## Returns the label.
static func spawn(parent: Control, pos: Vector2, text: String, color: Color, size: int, kind: String = "hit", key: String = "") -> Label:
	var l := Kit.label(text, size, color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = pos
	l.z_index = 3
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	var life := HitFx.num("numbers", "life")
	var t := parent.create_tween()
	t.set_parallel(true)
	if not UiSettings.reduced_motion():   # with reduced motion the number stays put and fades
		l.pivot_offset = l.get_combined_minimum_size() * 0.5
		var pop := HitFx.num("numbers", "crit_pop_scale") if kind == "crit" else HitFx.num("numbers", "pop_scale")
		l.scale = Vector2(pop, pop)
		t.tween_property(l, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var drift := float(CosmeticRng.keyed("num:" + key + text).randi_range(-7, 7))
		if kind == "miss":   # a dodge slides away rather than rising
			t.tween_property(l, "position:x", pos.x + 24.0, life)
			t.tween_property(l, "position:y", pos.y - 14.0, life)
		else:
			t.tween_property(l, "position:y", pos.y - HitFx.num("numbers", "rise"), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(l, "position:x", pos.x + drift, life)
	t.tween_property(l, "modulate:a", 0.0, life)
	t.chain().tween_callback(l.queue_free)
	return l


## The short mark of a status in its badge: its first letters, so the badge says what it is without its colour.
static func letters(status_name: String) -> String:
	var n := maxi(1, int(HitFx.num("status_pop", "letters")))
	return status_name.substr(0, n).to_upper()


## A badge for a status that lands (or "resisted"): a small coloured plate with the status's letters and its name beside
## it, popping in above the figure and rising as it fades. Returns the badge.
static func status_pop(parent: Control, pos: Vector2, status_name: String, color: Color, key: String = "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = pos
	row.z_index = 3
	var plate := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.55)
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	plate.add_theme_stylebox_override("panel", sb)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(Kit.label(letters(status_name), int(HitFx.num("status_pop", "size")), Color.WHITE))
	row.add_child(plate)
	var name_l := Kit.label(status_name, int(HitFx.num("numbers", "status_size")), color)
	name_l.add_theme_color_override("font_outline_color", Color.BLACK)
	name_l.add_theme_constant_override("outline_size", 5)
	row.add_child(name_l)
	parent.add_child(row)
	var life := maxf(0.2, HitFx.num("status_pop", "seconds"))
	var t := parent.create_tween()
	t.set_parallel(true)
	if not UiSettings.reduced_motion():
		row.pivot_offset = Vector2(12, 10)
		var pop := HitFx.num("status_pop", "pop_scale")
		row.scale = Vector2(pop, pop)
		t.tween_property(row, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(row, "position:y", pos.y - HitFx.num("status_pop", "rise"), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(row, "modulate:a", 0.0, life).set_delay(life * 0.45)
	t.chain().tween_callback(row.queue_free)
	return row
