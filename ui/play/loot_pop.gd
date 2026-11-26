## The loot that pops out of the fallen: what a fight's spoils added to the pack (found by comparing the pack before and after,
## so who gets what stays the business of GameLoot, GameFinding and GamePlague), drawn as chips with the item's picture, its
## name and its rarity as a word and a mark ("** Epic ...") in the rarity's colour, so colour is never the only cue. Items
## from rare up also throw a short beam of light. Each chip's picture flies from a fallen foe to its place. Look only, and
## with reduced motion the chips are simply there. Numbers and colours are in data/ui/hit_fx.json ("loot").
extends RefCounted

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const ItemIcon := preload("res://ui/play/item_icon.gd")
const HitFx := preload("res://ui/play/hit_fx.gd")


static func table() -> Dictionary:
	var l: Variant = HitFx.data().get("loot", {})
	return (l as Dictionary).get("rarity", {}) if typeof(l) == TYPE_DICTIONARY else {}


## The rarity id of an item ("common" for one with none, or an unknown one).
static func rarity_of(id: String) -> String:
	var r := str(GameItems.item_def(id).get("rarity", "common"))
	return r if table().has(r) else "common"


## What to show for a rarity: {id, word (its name from the loot data), mark ("", "+", "*", ...), color, beam}.
static func info(rarity: String) -> Dictionary:
	var row: Dictionary = table().get(rarity, table().get("common", {}))
	var names: Dictionary = GameLoot.data()["_rarity"]
	var word := str((names.get(rarity, {}) as Dictionary).get("name", rarity.capitalize()))
	return {"id": rarity, "word": word, "mark": str(row.get("mark", "")), "color": Color(str(row.get("color", "#ffffff"))), "beam": rank(rarity) >= rank(str((HitFx.data().get("loot", {}) as Dictionary).get("beam_from", "rare")))}


## Where a rarity sits in the loot data's order (common first).
static func rank(rarity: String) -> int:
	var rows: Array = GameLoot.data()["rarities"]
	for i in rows.size():
		if str(rows[i]["id"]) == rarity:
			return i
	return 0


## "** Epic Iron Sword": the mark, the rarity's word and the item's name.
static func text_of(id: String) -> String:
	var inf := info(rarity_of(id))
	var tag := str(inf["word"]) if str(inf["mark"]) == "" else "%s %s" % [inf["mark"], inf["word"]]
	return GameHitWords.find(tag, GameItems.item_name(id))


## What `after` holds that `before` did not (a pack as lists of ids), each id as often as it was added, in pack order.
static func gained(before: Array, after: Array) -> Array:
	var had := {}
	for id in before:
		had[str(id)] = int(had.get(str(id), 0)) + 1
	var out: Array = []
	for id in after:
		var k := str(id)
		if int(had.get(k, 0)) > 0:
			had[k] = int(had[k]) - 1
		else:
			out.append(k)
	return out


## One chip: the item's picture and its words in a plate edged in the rarity's colour.
static func chip(id: String) -> PanelContainer:
	var inf := info(rarity_of(id))
	var col: Color = inf["color"]
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.78)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(5)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var px := int(HitFx.num("loot", "icon_px"))
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = ItemIcon.texture(id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(px, px)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var l := Kit.label(text_of(id), 15, col.lightened(0.25))
	l.name = "Words"
	row.add_child(l)
	return p


## Builds the strip of chips for `ids` in `parent` (a heading, then chips that wrap) and, unless motion is reduced,
## flies a picture from each of `origins` (points in `host`'s units; foes' places, used in turn) to its chip, with a beam on
## the rare ones. `host` is the layer the flying pictures live in. Returns the strip, or null when there is nothing found.
## Run without await: it carries on over the next frames.
static func pop_out(host: Control, parent: Control, ids: Array, origins: Array) -> Control:
	if ids.is_empty():
		return null
	var strip := VBoxContainer.new()
	strip.name = "LootPop"
	strip.add_theme_constant_override("separation", 4)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(Kit.label(GameHitWords.found(), 15, Kit.dim()))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(flow)
	var chips: Array = []
	for id in ids:
		var c := chip(str(id))
		flow.add_child(c)
		chips.append(c)
	parent.add_child(strip)
	if UiSettings.reduced_motion() or host == null or not host.is_inside_tree():
		return strip
	_fly(host, strip, chips, ids, origins)
	return strip


static func _fly(host: Control, strip: Control, chips: Array, ids: Array, origins: Array) -> void:
	for c in chips:
		(c as Control).modulate.a = 0.0
	var tree := host.get_tree()
	await tree.process_frame
	await tree.process_frame   # the strip has its places once laid out
	for i in chips.size():
		if not is_instance_valid(host) or not is_instance_valid(strip):
			return
		var c: Control = chips[i]
		if not is_instance_valid(c):
			continue
		var rid := rarity_of(str(ids[i]))
		var inf := info(rid)
		var to := host.make_canvas_position_local(c.get_global_rect().position + Vector2(HitFx.num("loot", "icon_px") * 0.75, c.size.y * 0.5))
		var from: Vector2 = origins[i % origins.size()] if not origins.is_empty() else to + Vector2(0, 120)
		var delay := HitFx.num("loot", "stagger_seconds") * float(i)
		_one(host, c, str(ids[i]), inf, from, to, delay)


static func _one(host: Control, chip_node: Control, id: String, inf: Dictionary, from: Vector2, to: Vector2, delay: float) -> void:
	var px := HitFx.num("loot", "icon_px")
	var ghost := TextureRect.new()
	ghost.texture = ItemIcon.texture(id)
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.size = Vector2(px, px)
	ghost.pivot_offset = ghost.size * 0.5
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.position = from - ghost.size * 0.5
	ghost.modulate.a = 0.0
	ghost.z_index = 20
	host.add_child(ghost)
	var secs := UiSettings.motion_time(HitFx.num("loot", "pop_seconds"))
	var arc := HitFx.num("loot", "arc_px")
	var t := ghost.create_tween()
	t.tween_interval(delay)
	t.tween_property(ghost, "modulate:a", 1.0, 0.04)
	t.tween_method(func(k: float):
		var p := from.lerp(to, k) + Vector2(0, -4.0 * arc * k * (1.0 - k))   # a hop: up and over
		ghost.position = p - ghost.size * 0.5
		ghost.scale = Vector2.ONE * (1.0 + 0.5 * sin(k * PI)), 0.0, 1.0, secs)
	t.tween_callback(func():
		if is_instance_valid(chip_node):
			chip_node.modulate.a = 1.0
			chip_node.pivot_offset = chip_node.size * 0.5
			chip_node.scale = Vector2(1.18, 1.18)
			chip_node.create_tween().tween_property(chip_node, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ghost.queue_free()
		if bool(inf["beam"]):
			beam(host, to, inf["color"]))


## A short column of light at `at` (bottom centre) in `host`'s units, which rises and fades.
static func beam(host: Control, at: Vector2, color: Color) -> Control:
	var w := HitFx.num("loot", "beam_width")
	var h := HitFx.num("loot", "beam_height")
	var g := Gradient.new()
	g.set_color(0, Color(color, 0.0))
	g.set_color(1, Color(color.lightened(0.4), 0.85))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 64
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(w, h)
	r.position = at - Vector2(w * 0.5, h)
	r.pivot_offset = Vector2(w * 0.5, h)
	r.z_index = 19
	r.scale = Vector2(1.0, 0.1)
	host.add_child(r)
	var secs := UiSettings.motion_time(HitFx.num("loot", "beam_seconds"))
	var t := r.create_tween()
	t.set_parallel(true)
	t.tween_property(r, "scale:y", 1.0, secs * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(r, "modulate:a", 0.0, secs).set_delay(secs * 0.25)
	t.chain().tween_callback(r.queue_free)
	return r
