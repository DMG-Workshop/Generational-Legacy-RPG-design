## What the battle screen adds for a fight with some drama to it: a legend's title card as the fight opens, the words and pulses
## of the open world's telegraphs (a heavy blow winding up, a call for help, a guard braced), a foe that joins the fight, a legend
## entering a new phase, and the card that shows a legend's fall and the heirloom it leaves. Look only: nothing here touches the
## fight, and every motion goes through UiSettings.motion_time (with reduced motion the card just shows, then goes). The words
## are floated beside the log's own full sentence, so no cue rests on colour or motion alone; the card's text comes from
## GameVariety (the intro and the beat), never from here. `v` is the battle view.
extends RefCounted

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const HitFx := preload("res://ui/play/hit_fx.gd")

const CARD_SECONDS := 2.2


## The title card of a legend, over the arena as the fight opens: its short name large, its epithet under it. Nothing for a
## fight without a legend or for a fight reloaded mid-way.
static func intro(v) -> void:
	if v.b.resumed:
		return
	var card: Dictionary = GameVariety.intro(v.b)
	if card.is_empty():
		return
	var band := ColorRect.new()
	band.color = Color(Kit.BG, 0.82)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.z_index = 8
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = 0.28
	band.anchor_bottom = 0.28
	band.offset_top = 0
	band.offset_bottom = 116
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(box)
	var title := Kit.label(str(card["name"]), 44, Kit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 6)
	box.add_child(title)
	if str(card["epithet"]) != "":
		var sub := Kit.label(str(card["epithet"]), 20, Kit.dim())
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(sub)
	v.arena.add_child(band)
	if UiSettings.reduced_motion():
		v.get_tree().create_timer(CARD_SECONDS).timeout.connect(band.queue_free)
		return
	band.modulate.a = 0.0
	var t: Tween = v.create_tween()
	t.tween_property(band, "modulate:a", 1.0, 0.3)
	t.tween_interval(CARD_SECONDS - 0.6)
	t.tween_property(band, "modulate:a", 0.0, 0.3)
	t.tween_callback(band.queue_free)


## The words a blow that was announced shows as it lands: a heavy blow shakes the arena and says so beside its number.
static func heavy(v, ev: Dictionary) -> void:
	var ref := "heir"
	if str(ev.get("side", "")) == "ally":
		ref = "ally:%d" % int(ev.get("ally", 0))
	v._float_text(v._side_point(ref) + Vector2(0, -40), "HEAVY BLOW", Kit.bad(), 22)
	HitFx.shake(v.arena, HitFx.num("shake", "crit_px"), "heavy%d" % int(ev.get("index", 0)))


## An event of the open world's variety: wind_up, guard_up, summon, phase.
static func play(v, ev: Dictionary) -> void:
	var i := int(ev.get("index", -1))
	match str(ev["type"]):
		"wind_up":
			if i < 0 or i >= v.enemy_nodes.size():
				return
			var en: Dictionary = v.enemy_nodes[i]
			v._float_text(en["root"].position + Vector2(0, -8), "winding up!" if str(ev["pattern"]) == "heavy" else "calling for help!", Kit.bad(), 20)
			v._pulse(en["mark"])
		"guard_up":
			if i >= 0 and i < v.enemy_nodes.size():
				v._float_text(v.enemy_nodes[i]["root"].position + Vector2(0, -8), "braced", Kit.MP_BLUE, 20)
		"summon":
			v._build_foes(v.enemy_nodes.size())   # the new foe is on the field from now on
			v._layout()
			if i >= 0 and i < v.enemy_nodes.size():
				v._float_text(v.enemy_nodes[i]["root"].position + Vector2(0, -8), "joins the fight!", Kit.ACCENT, 20)
		"phase":
			if i >= 0 and i < v.enemy_nodes.size():
				v._float_text(v.enemy_nodes[i]["root"].position + Vector2(0, -24), "PHASE %s" % GameText.num(int(ev["step"]) + 1), Kit.bad(), 26)
				v._pulse(v.enemy_nodes[i]["mark"])
			HitFx.shake(v.arena, HitFx.num("shake", "crit_px"), "phase%d" % int(ev["step"]))


## The legend's fall at the head of the result: its title and the heirloom it leaves, in large type, put into `into`.
static func victory(into: VBoxContainer, beat: Dictionary) -> void:
	if beat.is_empty():
		return
	var p := Kit.panel(Color("#2a2415"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	p.add_child(col)
	var title := Kit.label(str(beat["title"]), 26, Kit.ACCENT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	if str(beat["line"]) != "":
		var l := Kit.label(str(beat["line"]), 20, Kit.good() if bool(beat["claimed"]) else Kit.dim())
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
	into.add_child(p)
