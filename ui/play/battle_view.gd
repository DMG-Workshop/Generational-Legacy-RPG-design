## Side-view battle rendering. All rules live in GameBattle; this only draws and forwards input.
## Every combatant stands where the battle placed it (paces, see GameCombat); an area ability is
## shown on the field, with every foe it would catch outlined, before it is cast.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const TouchHint := preload("res://ui/play/touch_hint.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const AREA := Color("#ff9a3c")
const MIN_COMMAND_FONT := 11   # the smallest a command shrinks to before its text is clipped

var app: Node
var d: GameDynasty
var b: GameBattle
var arena: Control
var field: Control             # draws the area being aimed, under the figures
var hero_node: Control
var hero_hp: ProgressBar
var hero_mp: ProgressBar
var hero_label: Label
var hero_info: Label           # the heir's HP and MP in numbers, as companions show theirs
var hero_chips: HBoxContainer
var enemy_nodes: Array = []    # [{root, body, hp, sel, mark, chips, w, h}]
var ally_nodes: Array = []     # [{root, body, hp, mp, info, ko, down, chips}] - companions, same order as b.allies
var log_label: RichTextLabel
var hint: Label
var command_box: HBoxContainer
var target: int = 0
var busy: bool = false
var result_shown: bool = false
var aiming: Dictionary = {}    # {ab, skill, spell, feat (slot or -1)} while the player picks where an ability lands
var aim_at: int = -1
var shown: Dictionary = {}     # {ab, at}: the area drawn on the field
var spell_list: Control = null
var skill_list: Control = null  # every class skill: the open ones to use, the rest by the level that opens them
var poison_list: Control = null # the toxins and vials in the pack
var feat_list: Control = null
var aim_info: Label = null      # the aim panel's "catches N foes" line
var floats: Dictionary = {}     # ref -> status words floated this action, so they stack instead of overlap
var auto: bool = false          # the heir fights on their own (GameTactics), one action every AUTO_PACE
var auto_button: Button
var result_scroll: ScrollContainer = null   # the result panel's story, capped to the window
var result_panel: Control = null
var _auto_waiting: bool = false # an auto action is due once AUTO_PACE has passed
var cmd_w := 600.0              # the command panel's width: narrower on a narrow screen
var figure_scale := 1.0         # figures shrink to fit a short arena (a phone, large text)
var bottom: HBoxContainer       # the log and the command panel
var cmd_panel: PanelContainer

const AUTO_PACE := 0.4


func _ready() -> void:
	d = app.dynasty
	b = d.battle
	_size_commands()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	var title := Kit.label("Battle: %s" % _foe_list(), 22, Kit.ACCENT)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	auto = GameTactics.auto_from_start(d)
	auto_button = Kit.button("", func(): set_auto(not auto), Vector2(190, 34))
	auto_button.add_theme_font_size_override("font_size", 15)
	top.add_child(auto_button)
	_show_auto()

	var ap := Kit.panel(Color("#191726"))
	ap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ap.clip_contents = true
	root.add_child(ap)
	arena = Control.new()
	arena.clip_contents = true
	ap.add_child(arena)
	field = Control.new()
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field.draw.connect(_draw_field)
	arena.add_child(field)
	arena.resized.connect(_layout)

	bottom = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)
	var lp := Kit.panel(Color("#1a1828"))
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(lp)
	log_label = Kit.rich()
	lp.add_child(log_label)
	cmd_panel = Kit.panel()
	bottom.add_child(cmd_panel)
	var cv := VBoxContainer.new()
	cmd_panel.add_child(cv)
	hint = Kit.label("", 14, Kit.DIM)
	hint.clip_text = true
	cv.add_child(hint)
	command_box = HBoxContainer.new()
	command_box.add_theme_constant_override("separation", 8)
	cv.add_child(command_box)
	_fit_bottom()
	_build_actors()
	_build_commands()
	target = b.first_target()
	_update_view()
	call_deferred("_layout")
	_say("A battle begins!")
	if not b.allies.is_empty():
		var party: Array = b.allies.map(func(a): return a.name)
		_say("%s fight%s beside %s." % [GameParty.names_text(party), "s" if party.size() == 1 else "", d.heir.name])


## "Dire Wolf x3, Elite Dire Wolf" - the same foe is counted, not repeated.
func _foe_list() -> String:
	var order: Array = []
	var count := {}
	for e in b.enemies:
		if not count.has(e["name"]):
			order.append(e["name"])
		count[e["name"]] = int(count.get(e["name"], 0)) + 1
	return ", ".join(order.map(func(n): return n if count[n] == 1 else "%s x%d" % [n, count[n]]))


func _say(text: String) -> void:
	log_label.append_text(GameText.group_numbers(text) + "\n")


## The command panel's width for the room the screen has.
func _size_commands() -> void:
	var room := UiSettings.room(self)
	cmd_w = clampf(room.x - 420.0, 480.0, 600.0)
	if room.y < float(UiSettings.setting("short_height")):   # four or five columns of commands
		cmd_w = clampf(room.x - 330.0, 480.0, 760.0)


func _fit_bottom() -> void:
	bottom.custom_minimum_size = Vector2(0, 170 if not _short() else 0)
	cmd_panel.custom_minimum_size = Vector2(cmd_w, 0)
	hint.custom_minimum_size = Vector2(cmd_w - 40.0, 0)


## The text size changed mid-fight: the commands are laid out again for the new room (the field
## follows on its own as the arena resizes). Open lists close, as they were placed for the old size.
func relayout() -> void:
	Kit.retap(self)   # buttons built once (Auto-battle, the result's) take the touch layout's height
	_size_commands()
	_fit_bottom()
	if result_shown or busy:
		return
	_close_spells()
	_close_skills()
	_close_feats()
	_close_poisons()
	_build_commands()


## Android's back button: drop an aim, else shut an open list. False when there is nothing to undo.
func back() -> bool:
	if result_shown:
		return false
	if not aiming.is_empty():
		_cancel_aim()
	elif feat_list != null:
		_close_feats()
	elif spell_list != null:
		_close_spells()
	elif skill_list != null:
		_close_skills()
	elif poison_list != null:
		_close_poisons()
	else:
		return false
	return true


func _unhandled_input(ev: InputEvent) -> void:
	if not ev.is_action_pressed("ui_cancel"):
		return
	if not aiming.is_empty():
		_cancel_aim()
		get_viewport().set_input_as_handled()
	elif feat_list != null:
		_close_feats()
		get_viewport().set_input_as_handled()
	elif poison_list != null:
		_close_poisons()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- figures

func _chips() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


func _build_actors() -> void:
	var cls := d.heir.cls()
	hero_node = Control.new()
	hero_node.size = Vector2(124, 220)
	var hero_body := ColorRect.new()
	hero_body.color = Color(cls["color"])
	hero_body.size = Vector2(80, 110)
	hero_body.position = Vector2(22, 34)
	hero_node.add_child(hero_body)
	var head := ColorRect.new()
	head.color = Color("#f0d9b5")
	head.size = Vector2(40, 40)
	head.position = Vector2(42, 0)
	hero_node.add_child(head)
	hero_label = Kit.label("%s  Lv%s" % [d.heir.name, GameText.num(d.heir.level)], 14)
	hero_label.position = Vector2(0, 146)
	hero_label.size = Vector2(124, 20)
	hero_label.clip_text = true
	hero_node.add_child(hero_label)
	hero_info = Kit.label("", 12, Kit.DIM)
	hero_info.position = Vector2(0, 165)
	hero_node.add_child(hero_info)
	hero_hp = _thin_bar(Kit.GOOD, d.heir.max_hp(), d.heir.hp, Vector2(124, 9))
	hero_hp.position = Vector2(0, 184)
	hero_node.add_child(hero_hp)
	hero_mp = _thin_bar(Kit.MP_BLUE, maxf(1.0, d.heir.max_mp()), d.heir.mp, Vector2(124, 5))
	hero_mp.position = Vector2(0, 195)
	hero_node.add_child(hero_mp)
	hero_chips = _chips()
	hero_chips.position = Vector2(0, 203)
	hero_node.add_child(hero_chips)
	arena.add_child(hero_node)

	for a in b.allies:
		ally_nodes.append(_build_ally(a))

	var solo := b.enemies.size() == 1
	for i in b.enemies.size():
		var e: Dictionary = b.enemies[i]
		var root := Control.new()
		var w := 170.0 if e["boss"] else (120.0 if solo else 88.0)
		var h := 190.0 if e["boss"] else (110.0 if solo else 76.0)
		root.size = Vector2(w, h + 50)
		var mark := Panel.new()
		mark.add_theme_stylebox_override("panel", Kit.style(Color(AREA, 0.12), 10, AREA))
		mark.size = Vector2(w + 18, h + 18)
		mark.position = Vector2(-9, -9)
		mark.visible = false
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(mark)
		var sel := Panel.new()
		sel.add_theme_stylebox_override("panel", Kit.style(Color(0, 0, 0, 0), 8, Kit.ACCENT))
		sel.size = Vector2(w + 10, h + 10)
		sel.position = Vector2(-5, -5)
		sel.visible = false
		sel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(sel)
		var body := ColorRect.new()
		body.color = Color(e["color"])
		body.size = Vector2(w, h)
		body.mouse_filter = Control.MOUSE_FILTER_STOP
		var idx := i
		body.gui_input.connect(func(ev: InputEvent): _on_foe_input(idx, ev))
		TouchHint.on_hover(body, func(): _on_foe_hover(idx, true), func(): _on_foe_hover(idx, false))
		root.add_child(body)
		for ex in [0.28, 0.62]:
			var eye := ColorRect.new()
			eye.color = Color("#101010")
			eye.size = Vector2(w * 0.1, w * 0.1)
			eye.position = Vector2(w * ex, h * 0.22)
			eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
			body.add_child(eye)
		var lv_text := "Lv %s" % GameText.num(int(e.get("level", 1)))
		# Late-generation levels are long: the text shrinks to stay inside the body. It is inked
		# against the body's colour, no outline: an outline smears once a full arena is shrunk to fit.
		var lv_size := 13
		var font := get_theme_default_font()
		while lv_size > 8 and font.get_string_size(lv_text, HORIZONTAL_ALIGNMENT_LEFT, -1, lv_size).x > w - 8.0:
			lv_size -= 1
		var pale := Color(e["color"]).get_luminance() > 0.45
		var elite := str(e["name"]).begins_with("Elite")
		var lv := Kit.label(lv_text, lv_size, (Kit.ACCENT.darkened(0.6) if elite else Kit.BG) if pale else (Kit.ACCENT if elite else Kit.TEXT))
		lv.position = Vector2(4, h - 22)
		lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(lv)
		var lbl := Kit.label(e["name"], 13, GamePlague.infected_color() if e.has("infected") else Kit.TEXT)
		lbl.position = Vector2(0, h + 3)
		lbl.size = Vector2(w + 64, 18)
		lbl.clip_text = true
		lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lbl.z_index = 1
		root.add_child(lbl)
		var hp := _thin_bar(Kit.BAD, e["max_hp"], e["hp"], Vector2(w, 8))
		hp.position = Vector2(0, h + 23)
		root.add_child(hp)
		var chips := _chips()
		chips.position = Vector2(0, h + 33)
		chips.z_index = 1
		root.add_child(chips)
		arena.add_child(root)
		enemy_nodes.append({"root": root, "body": body, "hp": hp, "sel": sel, "mark": mark, "chips": chips, "w": w, "h": h})


## A companion: smaller figure in class colours with a race-tinted head, name, level and HP.
func _build_ally(a: GameHeir) -> Dictionary:
	var root := Control.new()
	root.size = Vector2(110, 172)
	var body := ColorRect.new()
	body.color = Color(a.cls()["color"])
	body.size = Vector2(58, 72)
	body.position = Vector2(26, 28)
	root.add_child(body)
	var head := ColorRect.new()
	head.color = Color(a.race().get("color", "#f0d9b5"))
	head.size = Vector2(30, 30)
	head.position = Vector2(40, 0)
	root.add_child(head)
	var ko := Kit.label("KO", 22, Kit.BAD)
	ko.add_theme_color_override("font_outline_color", Color.BLACK)
	ko.add_theme_constant_override("outline_size", 6)
	ko.position = Vector2(38, 46)
	ko.visible = a.hp <= 0
	root.add_child(ko)
	var nm := Kit.label(a.name, 13)
	nm.position = Vector2(0, 103)
	nm.size = Vector2(110, 18)
	nm.clip_text = true
	root.add_child(nm)
	var info := Kit.label("", 12, Kit.DIM)
	info.position = Vector2(0, 120)
	root.add_child(info)
	var hp := _thin_bar(Kit.GOOD, a.max_hp(), a.hp, Vector2(110, 8))
	hp.position = Vector2(0, 139)
	root.add_child(hp)
	var mp := _thin_bar(Kit.MP_BLUE, maxf(1.0, a.max_mp()), a.mp, Vector2(110, 5))
	mp.position = Vector2(0, 149)
	root.add_child(mp)
	var chips := _chips()
	chips.position = Vector2(0, 156)
	root.add_child(chips)
	if a.hp <= 0:
		body.modulate = Color(0.35, 0.35, 0.4)
	arena.add_child(root)
	return {"root": root, "body": body, "hp": hp, "mp": mp, "info": info, "ko": ko, "down": a.hp <= 0, "chips": chips}


## A bar exactly `size` tall (Kit bars pad to the stylebox margins).
func _thin_bar(color: Color, max_value: float, value: float, size: Vector2) -> ProgressBar:
	var pb := Kit.bar(color, max_value, value, size)
	for k in ["background", "fill"]:
		(pb.get_theme_stylebox(k) as StyleBoxFlat).set_content_margin_all(0)
	return pb


# ---------------------------------------------------------------- the field

## Paces on the field to pixels in the arena: the rearmost companion at the left edge, the back
## row near the right, and every place in the formation inside the arena's height.
func _px(p: Vector2) -> Vector2:
	var f: Dictionary = GameCombat.formation()["field"]
	var x0 := GameCombat.heir_point().x
	var reach := float(f["spacing"]) * float(maxi(int(f["row_max"]["front"]), int(f["row_max"]["back"])) - 1) * 0.5
	for i in maxi(1, b.allies.size()):
		var a := GameCombat.ally_point(i)
		x0 = minf(x0, a.x)
		reach = maxf(reach, absf(a.y))
	reach += 1.3
	var x1 := float(f["rows"]["back"])
	var sz := arena.size
	return Vector2(sz.x * (0.06 + (p.x - x0) / maxf(1.0, x1 - x0) * 0.8), sz.y * (0.5 + p.y / (2.0 * reach)))


## Top-left corner that puts `node` around `center`, kept inside the arena.
func _spot(node: Control, center: Vector2, anchor_y: float) -> Vector2:
	var sz := node.size * node.scale
	var pos := center - Vector2(sz.x * 0.5, anchor_y * node.scale.y)
	pos.x = clampf(pos.x, 0.0, maxf(0.0, arena.size.x - sz.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, arena.size.y - sz.y))
	return pos


func _foe_spot(i: int) -> Vector2:
	var en: Dictionary = enemy_nodes[i]
	return _spot(en["root"], _px(b.enemy_point(i)), float(en["h"]) * 0.5 + 10.0)


func _layout() -> void:
	if arena == null or hero_node == null:
		return
	# The field is drawn for an arena about 460 tall; a shorter one shrinks the figures to match.
	figure_scale = clampf(arena.size.y / 460.0, 0.45, 1.0)
	for n in [hero_node] + ally_nodes.map(func(a): return a["root"]) + enemy_nodes.map(func(e): return e["root"]):
		(n as Control).scale = Vector2(figure_scale, figure_scale)
	hero_node.position = _spot(hero_node, _px(b.unit_point(-1)), 90.0)
	for i in ally_nodes.size():
		ally_nodes[i]["root"].position = _spot(ally_nodes[i]["root"], _px(b.unit_point(i)), 64.0)
	for i in enemy_nodes.size():
		enemy_nodes[i]["root"].position = _foe_spot(i)
	field.queue_redraw()


## The area being aimed, drawn on the ground in paces mapped to the screen, over any ground a feat
## has fouled.
func _draw_field() -> void:
	if not b.is_over():
		_draw_ground()
	if shown.is_empty() or b.is_over():
		return
	var ab: Dictionary = shown["ab"]
	var at := b._valid_target(int(shown["at"]))
	if at < 0:
		return
	var origin := b.cast_point(-1)
	var aim := b.enemy_point(at)
	var t: Dictionary = ab.get("target", {})
	var pts := PackedVector2Array()
	match GameCombat.shape(ab):
		"burst":
			var r := float(t.get("radius", 3.0))
			var centre := origin if GameCombat.around_self(ab) else aim
			for k in 40:
				pts.append(_px(centre + Vector2.from_angle(TAU * float(k) / 40.0) * r))
		"cone":
			var reach := float(t.get("range", 16.0))
			var half := deg_to_rad(float(t.get("angle", 60.0)) * 0.5)
			var dir := (aim - origin).angle()
			pts.append(_px(origin))
			for k in 25:
				pts.append(_px(origin + Vector2.from_angle(dir - half + 2.0 * half * float(k) / 24.0) * reach))
		"line":
			var along := (aim - origin).normalized()
			var side := Vector2(-along.y, along.x) * float(t.get("width", 3.0)) * 0.5
			var end := origin + along * float(t.get("length", 18.0))
			pts = PackedVector2Array([_px(origin + side), _px(end + side), _px(end - side), _px(origin - side)])
	if pts.size() >= 3:
		field.draw_colored_polygon(pts, Color(AREA, 0.13))
		var ring := pts.duplicate()
		ring.append(pts[0])
		field.draw_polyline(ring, Color(AREA, 0.7), 2.0)


## Caltrops, a mire: each field's reach, with its name and the rounds it still holds at its near edge.
func _draw_ground() -> void:
	var font := field.get_theme_default_font()
	for f in b.fields:
		var c := Vector2(float(f["x"]), float(f["y"]))
		var r := float(f["radius"])
		var col := Color(str(f["color"]))
		var pts := PackedVector2Array()
		for k in 36:
			pts.append(_px(c + Vector2.from_angle(TAU * float(k) / 36.0) * r))
		field.draw_colored_polygon(pts, Color(col, 0.16))
		var ring := pts.duplicate()
		ring.append(pts[0])
		field.draw_polyline(ring, Color(col, 0.6), 1.5)
		var edge := _px(c - Vector2(r, 0))
		field.draw_string(font, edge + Vector2(8, 4), "%s %d" % [f["name"], b.field_turns_left(f)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(col, 0.95))


func _show_area(ab: Dictionary, at: int) -> void:
	shown = {} if ab.is_empty() or not GameCombat.aims_at_foe(ab) else {"ab": ab, "at": at}
	_update_marks()
	field.queue_redraw()


# ---------------------------------------------------------------- input

func _on_foe_input(idx: int, ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or b.enemies[idx]["hp"] <= 0 or busy:
		return
	if aiming.is_empty():
		target = idx
		_update_marks()
	elif idx == aim_at:
		_confirm_aim()
	else:
		aim_at = idx
		_show_area(aiming["ab"], aim_at)
		_build_commands()


func _on_foe_hover(idx: int, inside: bool) -> void:
	if aiming.is_empty() or busy or b.enemies[idx]["hp"] <= 0:
		return
	var at := idx if inside else aim_at
	_show_area(aiming["ab"], at)
	if is_instance_valid(aim_info):
		aim_info.text = _aim_text(aiming["ab"], at, at != aim_at)


## An area ability waits for the player to pick where it lands; single strikes go to the target.
## Aiming starts on the target if the area reaches it, else on the first foe it does reach; a
## plague vial starts where its burst catches the most foes.
func _begin_aim(ab: Dictionary, skill: int, spell: String, feat: int = -1, item: String = "") -> void:
	aiming = {"ab": ab, "skill": skill, "spell": spell, "feat": feat, "item": item}
	aim_at = b._valid_target(target)
	if item != "":
		aim_at = GamePlague.best_aim(b, ab, aim_at)
	if aim_at not in b.aoe_targets(ab, -1, aim_at):
		for i in b.living_enemies():
			if i in b.aoe_targets(ab, -1, i):
				aim_at = i
				break
	_show_area(ab, aim_at)
	_build_commands()


func _cancel_aim() -> void:
	aiming = {}
	_show_area({}, -1)
	_build_commands()


func _confirm_aim() -> void:
	if aiming.is_empty() or b.aoe_targets(aiming["ab"], -1, aim_at).is_empty():
		return
	var plan := aiming
	var at := aim_at
	aiming = {}
	_show_area({}, -1)
	if float(plan["ab"].get("mult", 0.0)) > 0.0:
		target = at
	if str(plan.get("item", "")) != "":
		_do(func(): b.throw_vial(str(plan["item"]), at))
	elif int(plan.get("feat", -1)) >= 0:
		_do(func(): b.use_feat(int(plan["feat"]), at))
	elif int(plan["skill"]) >= 0:
		_do(func(): b.use_skill(int(plan["skill"]), at))
	else:
		_do(func(): b.cast_spell(str(plan["spell"]), at))


func _use_skill(i: int) -> void:
	var s := b.skill_info(i)
	if GameCombat.is_aoe(s):
		_begin_aim(s, i, "")
	else:
		_do(func(): b.use_skill(i, target))


func _use_spell(id: String) -> void:
	_close_spells()
	var sp := b.unit_spell(-1, id)
	if GameCombat.is_aoe(sp):
		_begin_aim(sp, -1, id)
	else:
		_do(func(): b.cast_spell(id, target))


func _use_feat(slot: int) -> void:
	_close_feats()
	var ab := b.unit_feat(-1, b.feat_in_slot(slot))
	if GameCombat.is_aoe(ab):
		_begin_aim(ab, -1, "", slot)
	else:
		_do(func(): b.use_feat(slot, target))


# ---------------------------------------------------------------- commands

func _build_commands() -> void:
	Kit.clear(command_box)
	aim_info = null
	if auto and not b.is_over():
		_build_auto_commands()
		return
	if not aiming.is_empty():
		_build_aim_commands()
		return
	hint.text = "Commands  (%s an enemy to target it)" % Kit.click()
	var col1 := VBoxContainer.new()
	var col2 := VBoxContainer.new()
	var col3 := VBoxContainer.new()
	col1.add_child(Kit.button("Attack", func(): _do(func(): b.attack(target))))
	col1.add_child(Kit.button("Defend", func(): _do(func(): b.defend())))
	var readied: Array = b.unit_feats(-1)
	var ready := range(readied.size()).filter(func(k): return b.can_use_feat(k)).size()
	var fb := Kit.button("Feats (%d ready)" % ready if not readied.is_empty() else "Feats", func(): _open_feats())
	if not readied.is_empty():
		fb.set_meta("compact", "Feats (%d)" % ready)
	fb.disabled = readied.is_empty()
	fb.tooltip_text = "%s's readied feats: no MP, a cooldown each." % d.heir.name if not readied.is_empty() else "%s has no feats readied." % d.heir.name
	col1.add_child(fb)
	# One button per skill open from level 1; every later class skill is in the Skills list.
	var first := mini(GameSkills.first_count(d.heir.class_id), b.skill_count())
	for i in first:
		var s := b.skill_info(i)
		var idx := i
		var cost := b.pay_text(-1, b.skill_cost(i))
		var one := "%s (%s)" % [s["name"], cost]
		var two := _short() or not _fits(one, 14, (cmd_w - 40.0) / 3.0 - 20.0)
		var btn := _small_button("%s\n%s" % [s["name"], cost] if two else one, func(): _use_skill(idx))
		if two:   # the cost under the name: a narrow column cannot hold both on one line
			btn.add_theme_font_size_override("font_size", 13)
			btn.add_theme_constant_override("line_spacing", -2)
		btn.disabled = not b.can_use_skill(i)
		btn.tooltip_text = "%s  -  %s\n%s" % [s["name"], GameCombat.shape_text(s), GameCombat.describe(s)]
		TouchHint.on_hover(btn, func(): _show_area(s, target), func(): _show_area({}, -1))
		col2.add_child(btn)
	if b.skill_count() > first:
		var usable := range(first, b.skill_count()).filter(func(k): return b.can_use_skill(k)).size()
		var kb := _small_button("Skills (%d ready)" % usable, func(): _open_skills())
		kb.set_meta("compact", "Skills (%d)" % usable)
		var nxt := GameSkills.next_unlock(d.heir)
		kb.tooltip_text = "%s's later class skills%s." % [d.heir.name, "" if nxt.is_empty() else "; next: %s at level %s" % [nxt["name"], GameText.num(int(nxt["level"]))]]
		col2.add_child(kb)
	var kit := GamePlague.toxins_carried(d.heir).size() + GamePlague.vials_carried(d.heir).size()
	if kit > 0 or not b.coating.is_empty():
		var n := 0
		for id in d.heir.inventory:
			if GameItems.kind_of(id) in ["toxin", "vial"]:
				n += 1
		var pb := _small_button("Poisons (%d)" % n, func(): _open_poisons())
		pb.disabled = n == 0
		pb.tooltip_text = "Coat the blade with a toxin (no turn) or throw a plague vial."
		col2.add_child(pb)
	if not GameCombat.class_spell_plan(d.heir.class_id).is_empty() or not b.known_spells().is_empty():
		var sb := Kit.button("Spells (%d)" % b.known_spells().size(), func(): _open_spells())
		sb.disabled = b.known_spells().is_empty()
		sb.tooltip_text = "The spells %s knows." % d.heir.name if not b.known_spells().is_empty() else "%s has learned no spells yet." % d.heir.name
		col3.add_child(sb)
	var pot := Kit.button("Potion (%s)" % GameText.num(d.heir.potions), func(): _do(func(): b.use_potion()))
	pot.disabled = d.heir.potions <= 0
	col3.add_child(pot)
	col3.add_child(Kit.button("Flee", func(): _do(func(): b.flee())))
	_lay_out_commands([col1, col2, col3])


func _fits(text: String, font_size: int, width: float) -> bool:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width


func _short() -> bool:
	return UiSettings.room(self).y < float(UiSettings.setting("short_height"))


## Three columns of commands; a short screen deals them into two rows instead, so the field keeps
## its height. The order (attacks, skills, spells and escape) reads the same either way.
func _lay_out_commands(cols: Array) -> void:
	var per := 2 if _short() else 0
	if per > 0:
		var all: Array = []
		for c in cols:
			for btn in (c as Control).get_children():
				c.remove_child(btn)
				all.append(btn)
			(c as Node).free()
		cols = []
		for k in all.size():
			if k % per == 0:
				cols.append(VBoxContainer.new())
			cols.back().add_child(all[k])
	for c in cols:
		c.add_theme_constant_override("separation", 6)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		command_box.add_child(c)
	_fit_commands.call_deferred()


## The columns share the command panel's width, and a narrow window or a big text size leaves some
## too little: clipped, "Skills (3 ready)" reads "Skills (3 re". Once laid out, if the text does
## not all fit, the commands that have a compact wording take it, then every command's font
## shrinks a point at a time (down to MIN_COMMAND_FONT); then each column is kept as wide as its
## widest text needs, the spare room shared out as before.
func _fit_commands() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(command_box):
		return
	var cols: Array = command_box.get_children().filter(func(c): return c is Container and is_instance_valid(c))
	if cols.is_empty():
		return
	var buttons: Array = []
	for c in cols:
		buttons.append_array((c as Node).get_children().filter(func(x): return x is Button))
	var base := {}
	for btn in buttons:
		(btn as Button).clip_text = true
		base[btn] = (btn as Button).get_theme_font_size("font_size")
	var room := command_box.size.x - float(command_box.get_theme_constant("separation")) * float(cols.size() - 1)
	if room <= 0.0:
		return
	var shrink := 0
	var compact := false
	while true:
		var total := 0.0
		for c in cols:
			total += _column_need(c)
		if total <= room or shrink > 16:
			break
		if not compact:
			compact = true
			for btn in buttons:
				if (btn as Button).has_meta("compact"):
					(btn as Button).text = str((btn as Button).get_meta("compact"))
			continue
		shrink += 1
		for btn in buttons:
			(btn as Button).add_theme_font_size_override("font_size", maxi(MIN_COMMAND_FONT, int(base[btn]) - shrink))
	for c in cols:
		(c as Control).custom_minimum_size.x = _column_need(c)


## The width a column of commands needs to show every text whole.
func _column_need(col: Node) -> float:
	var need := 0.0
	for btn in col.get_children():
		if btn is Button:
			var widest := 0.0
			for line in (btn as Button).text.split("\n"):
				widest = maxf(widest, (btn as Button).get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, (btn as Button).get_theme_font_size("font_size")).x)
			need = maxf(need, widest + (btn as Button).get_theme_stylebox("normal").get_minimum_size().x + 2.0)
	return need


# ---------------------------------------------------------------- auto-battle

## Switches auto-battle on or off, for this fight and the hunts after it. Off hands the next
## command back to the player at once; on lets the heir fight from their next turn.
func set_auto(on: bool) -> void:
	auto = on
	d.auto_battle = on
	_show_auto()
	if result_shown:
		return
	if busy:
		Kit.clear(command_box)
		hint.text = ""
		if auto:
			_auto_panel()
		return
	aiming = {}
	_show_area({}, -1)
	_build_commands()


func _show_auto() -> void:
	auto_button.text = "Auto-battle: %s" % ("ON" if auto else "OFF")
	auto_button.add_theme_color_override("font_color", Kit.GOOD if auto else Kit.TEXT)
	auto_button.tooltip_text = ("%s fights on their own, choosing as the autopilot would. " + Kit.click().capitalize() + " to take over." if auto
		else "Let %s fight on their own, now and in the hunts that follow.") % d.heir.name


func _build_auto_commands() -> void:
	_auto_panel()
	if not _auto_waiting:
		_auto_waiting = true
		get_tree().create_timer(AUTO_PACE).timeout.connect(_auto_step)


## What the command panel shows while the heir fights on their own.
func _auto_panel() -> void:
	Kit.clear(command_box)
	_close_spells()
	_close_skills()
	_close_feats()
	_close_poisons()
	hint.text = "Auto-battle: %s fights on their own." % d.heir.name
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	command_box.add_child(v)
	var l := Kit.label("Every choice is the one the autopilot would make: %s Switch auto-battle off to give the orders yourself." % GameSkills.style_text(d.heir), 14, Kit.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(cmd_w - 40.0, 0)
	v.add_child(l)
	v.add_child(Kit.button("Take over", func(): set_auto(false), Vector2(180, 38)))


func _auto_step() -> void:
	_auto_waiting = false
	if not auto or busy or result_shown or b.is_over() or not is_inside_tree():
		return
	_do(func(): GameTactics.auto_turn(b))


func _small_button(text: String, cb: Callable) -> Button:
	var btn := Kit.button(text, cb)
	btn.add_theme_font_size_override("font_size", 14)
	btn.clip_text = true
	btn.custom_minimum_size = Vector2(0, UiSettings.tap_h(38))
	return btn


func _build_aim_commands() -> void:
	var ab: Dictionary = aiming["ab"]
	var verb := "throw" if str(aiming.get("item", "")) != "" else ("cast" if str(aiming["spell"]) != "" else "strike")
	hint.text = "%s: %s a foe to aim, %s it again to %s." % [ab["name"], Kit.click(), Kit.click(), verb]
	if GameCombat.around_self(ab):
		hint.text = "%s strikes all around %s, wherever it is aimed." % [ab["name"], d.heir.name]
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	command_box.add_child(v)
	var effect := GameFeats.describe(str(ab["feat"])) if ab.has("feat") else GameCombat.describe(ab)
	var what := Kit.label("%s  -  %s" % [GameCombat.shape_text(ab), effect], 13, Kit.TEXT)
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	what.custom_minimum_size = Vector2(cmd_w - 220.0, 0)
	v.add_child(what)
	aim_info = Kit.label(_aim_text(ab, aim_at, false), 14, AREA)
	aim_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aim_info.custom_minimum_size = Vector2(cmd_w - 220.0, 0)
	v.add_child(aim_info)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	side.custom_minimum_size = Vector2(150, 0)
	command_box.add_child(side)
	var go := Kit.button(verb.capitalize() if verb != "strike" else "Use", func(): _confirm_aim())
	go.disabled = b.aoe_targets(ab, -1, aim_at).is_empty()
	side.add_child(go)
	side.add_child(Kit.button("Cancel", func(): _cancel_aim()))


## "Aimed at Dire Wolf: catches 3 foes, about 420 damage." (or "Over ..." while hovering).
func _aim_text(ab: Dictionary, at: int, hovering: bool) -> String:
	at = b._valid_target(at)
	if at < 0:
		return ""
	var caught := b.aoe_targets(ab, -1, at)
	var n := caught.size()
	if n == 0:
		if GameCombat.around_self(ab):
			return "No foe stands within reach of %s." % d.heir.name
		return "Toward %s it reaches no foe." % b.enemies[at]["name"]
	var foes := "%d foe%s" % [n, "" if n == 1 else "s"]
	var whom := str(b.enemies[at]["name"]) + ("" if at in caught else " (beyond reach)")
	var text := ("Over %s: would catch %s" if hovering else "Aimed at %s: catches %s") % [whom, foes]
	if GameCombat.around_self(ab):
		text = "Around %s: catches %s" % [d.heir.name, foes]
	var dmg := b.estimate(-1, ab, at)
	if dmg >= 1.0:
		text += ", about %s damage%s" % [GameText.num(int(round(dmg))), " in all" if n > 1 else ""]
	return text + "."


# ---------------------------------------------------------------- spell list

## A list over the field (the spellbook, the readied feats): a click outside it or on Close shuts
## it. Returns [the list's root, the box its rows go in].
func _list_panel(title: String, close: Callable) -> Array:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.z_index = 5
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close.call())
	root.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.style(Color("#1a1828"), 8, Kit.ACCENT))
	var room := size if size.x > 0.0 else UiSettings.room(self)
	p.size = Vector2(minf(980.0, room.x - 24.0), minf(470.0, room.y - 24.0))
	p.position = Vector2((room.x - p.size.x) * 0.5, clampf(48.0, 12.0, room.y - p.size.y - 12.0))
	root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := Kit.label(title, 20, Kit.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(Kit.button("Close", close, Vector2(100, 34)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 4)
	scroll.add_child(rows)
	return [root, rows]


func _open_spells() -> void:
	if busy or spell_list != null:
		return
	var made := _list_panel("Spells  -  %s has %s / %s MP" % [d.heir.name, GameText.num(d.heir.mp), GameText.num(d.heir.max_mp())], _close_spells)
	spell_list = made[0]
	var rows: VBoxContainer = made[1]
	var groups: Dictionary = GameData.combat["spells"].get("groups", {})
	for g in groups:
		var ids: Array = b.known_spells().filter(func(id): return GameCombat.spell(id).get("group", "") == g)
		if ids.is_empty():
			continue
		rows.add_child(Kit.label(str(groups[g]), 15, Kit.DIM))
		for id in ids:
			rows.add_child(_spell_row(id))
	var next := _next_spell()
	if next != "":
		rows.add_child(Kit.label(next, 13, Kit.DIM))


func _spell_row(id: String) -> Control:
	var sp := b.unit_spell(-1, id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var btn := Kit.button("%s  (%s)" % [sp["name"], b.pay_text(-1, b.spell_cost(id))], func(): _use_spell(id), Vector2(260, 34))
	btn.add_theme_font_size_override("font_size", 15)
	btn.clip_text = true
	btn.disabled = not b.can_cast(id)
	btn.tooltip_text = str(sp.get("text", ""))
	TouchHint.on_hover(btn, func(): _show_area(sp, target), func(): _show_area({}, -1))
	row.add_child(btn)
	var el := str(sp.get("element", ""))
	var shape := Kit.label(GameCombat.shape_text(sp), 14, Color(GameCombat.element_color(el)) if el != "" else Kit.TEXT)
	shape.custom_minimum_size = Vector2(96, 0)
	row.add_child(shape)
	var what := Kit.label(GameCombat.describe(sp) + ("" if b.can_cast(id) else "  (not enough %s)" % ("HP" if b.pays_in_hp(-1) else "MP")), 13, Kit.TEXT if b.can_cast(id) else Kit.DIM)
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if UiSettings.compact(self):   # a narrow list wraps rather than hide the end of the effect
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		what.clip_text = true
		what.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	what.tooltip_text = what.text
	what.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(what)
	return row


## "Next: Haste at level 32." for the class's next spell, if any.
func _next_spell() -> String:
	for p in GameCombat.class_spell_plan(d.heir.class_id):
		if p[0] not in b.known_spells():
			return "Next: %s at level %s." % [GameCombat.spell(p[0])["name"], GameText.num(int(p[1]))]
	return ""


func _close_spells() -> void:
	if spell_list != null:
		spell_list.queue_free()
		spell_list = null
	_show_area({}, -1)


# ---------------------------------------------------------------- class skill list

## Every class skill past the first ones: those the heir's level has opened, to use, then the
## rest dimmed with the level that opens each.
func _open_skills() -> void:
	if busy or skill_list != null:
		return
	var made := _list_panel("Class skills  -  %s has %s / %s MP" % [d.heir.name, GameText.num(d.heir.mp), GameText.num(d.heir.max_mp())], _close_skills)
	skill_list = made[0]
	var rows: VBoxContainer = made[1]
	var locked: Array = []
	for i in range(GameSkills.first_count(d.heir.class_id), b.skill_count()):
		if b.skill_unlocked(i):
			rows.add_child(_skill_row(i))
		else:
			locked.append(i)
	if not locked.is_empty():
		rows.add_child(Kit.label("Opened by level", 15, Kit.DIM))
	for i in locked:
		var s := b.skill_info(i)
		var l := Kit.label("Level %s: %s  -  %s" % [GameText.num(GameSkills.level_of(s)), s["name"], GameCombat.describe(s)], 13, Kit.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_child(l)


func _skill_row(i: int) -> Control:
	var s := b.skill_info(i)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var used := b.skill_used_up(i)
	var btn := Kit.button("%s  (%s)" % [s["name"], "used" if used else b.pay_text(-1, b.skill_cost(i))], func(): _pick_skill(i), Vector2(260, 34))
	btn.add_theme_font_size_override("font_size", 15)
	btn.clip_text = true
	btn.disabled = not b.can_use_skill(i)
	btn.tooltip_text = GameCombat.describe(s)
	TouchHint.on_hover(btn, func(): _show_area(s, target), func(): _show_area({}, -1))
	row.add_child(btn)
	var el := str(s.get("element", ""))
	var shape := Kit.label(GameCombat.shape_text(s), 14, Color(GameCombat.element_color(el)) if el != "" else Kit.TEXT)
	shape.custom_minimum_size = Vector2(96, 0)
	row.add_child(shape)
	var note := "" if b.can_use_skill(i) else ("  (once a battle)" if used else "  (not enough %s)" % ("HP" if b.pays_in_hp(-1) else "MP"))
	var what := Kit.label(GameCombat.describe(s) + note, 13, Kit.TEXT if b.can_use_skill(i) else Kit.DIM)
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if UiSettings.compact(self):   # a narrow list wraps rather than hide the end of the effect
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		what.clip_text = true
		what.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	what.tooltip_text = what.text
	what.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(what)
	return row


func _pick_skill(i: int) -> void:
	_close_skills()
	_use_skill(i)


func _close_skills() -> void:
	if skill_list != null:
		skill_list.queue_free()
		skill_list = null
	_show_area({}, -1)


# ---------------------------------------------------------------- toxins and vials

## The toxins and plague vials in the pack: a toxin goes on the blade at once and costs no turn;
## a vial is aimed like an area spell.
func _open_poisons() -> void:
	if busy or poison_list != null:
		return
	var made := _list_panel("Poisons  -  from the black market", _close_poisons)
	poison_list = made[0]
	var rows: VBoxContainer = made[1]
	var tox := GamePlague.toxins_carried(d.heir)
	if not tox.is_empty() or not b.coating.is_empty():
		rows.add_child(Kit.label("Toxins: coat the blade, no turn spent. The next %d blade blows carry it; pure spells do not." % int(GamePlague.setting("coat_hits")), 15, Kit.DIM))
	if not b.coating.is_empty():
		rows.add_child(Kit.label("The blade is coated with %s: %d blow%s left." % [GameItems.item_name(str(b.coating["item"])), int(b.coating["hits"]), "" if int(b.coating["hits"]) == 1 else "s"], 14, Kit.GOOD))
	for id in tox:
		var t: Dictionary = GameItems.item_def(id)["toxin"]
		var what := "Venom %d%% of max HP a turn for %d turns%s. Handling it: %d%% risk of %s." % [int(round(float(t["poison_pct"]) * 100.0)), int(t["turns"]),
			", and weakens %d%%" % int(round(float(t["weaken"]) * 100.0)) if t.has("weaken") else "", int(round(float(t["backfire"]["chance"]) * 100.0)), GameDisease.disease_name(str(t["backfire"]["disease"]))]
		var item: String = id
		rows.add_child(_poison_row("Coat: %s (%d)" % [GameItems.item_name(id), GameItems.count(d.heir, id)], what, b.can_coat(id), func(): _coat(item)))
	var vials := GamePlague.vials_carried(d.heir)
	if not vials.is_empty():
		rows.add_child(Kit.label("Plague vials: thrown like an area spell, a turn spent.", 15, Kit.DIM))
	for id in vials:
		var ab := GamePlague.vial_ability(id)
		var v: Dictionary = GameItems.item_def(id)["vial"]
		var what := "%s  -  %s. The thrower: %d%% risk of %s." % [GameCombat.shape_text(ab), GameCombat.describe(ab), int(round(float(v["splash"]) * 100.0)), GameDisease.disease_name(str(v["disease"]))]
		var item: String = id
		var row := _poison_row("Throw: %s (%d)" % [GameItems.item_name(id), GameItems.count(d.heir, id)], what, b.can_throw(id), func(): _throw(item))
		TouchHint.on_hover(row.get_child(0), func(): _show_area(ab, target), func(): _show_area({}, -1))
		rows.add_child(row)


func _poison_row(title: String, what: String, enabled: bool, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var btn := Kit.button(title, cb, Vector2(300, 34))
	btn.add_theme_font_size_override("font_size", 15)
	btn.clip_text = true
	btn.disabled = not enabled
	row.add_child(btn)
	var l := Kit.label(what, 13, Kit.TEXT if enabled else Kit.DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


func _close_poisons() -> void:
	if poison_list != null:
		poison_list.queue_free()
		poison_list = null
	_show_area({}, -1)


func _coat(item: String) -> void:
	_close_poisons()
	_do(func(): b.coat_blade(item))


func _throw(item: String) -> void:
	_close_poisons()
	_begin_aim(GamePlague.vial_ability(item), -1, "", -1, item)


# ---------------------------------------------------------------- feat list

## The readied feats in a panel over the party's side of the field, so the foes stay in sight:
## hovering a feat outlines the foes it would catch. The rest of the screen keeps working.
func _open_feats() -> void:
	if busy or b.unit_feats(-1).is_empty():
		return
	if feat_list != null:
		_close_feats()
		return
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.style(Color("#1a1828"), 8, Kit.ACCENT))
	p.z_index = 5
	var room := _feat_list_room()
	p.position = room.position
	p.custom_minimum_size = Vector2(room.size.x, 0)
	add_child(p)
	feat_list = p
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := Kit.label("Feats  -  no MP, each waits out its cooldown", 18, Kit.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(Kit.button("Close", _close_feats, Vector2(90, 32)))
	var scroll := ScrollContainer.new()   # a short arena cannot show four readied feats whole
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for k in b.unit_feats(-1).size():
		list.add_child(_feat_row(k, room.size.x - 14.0))
	var rec := int(GameFeats.setting("recovery_turns"))
	var note := "Feats are learned and readied in a town or right after a rest."
	if rec > 0:
		note = "After any feat %s catches breath for %s before the next. %s" % [d.heir.name, "a turn" if rec == 1 else "%d turns" % rec, note]
	var foot := Kit.label(note, 13, Kit.DIM)
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.custom_minimum_size = Vector2(room.size.x - 24.0, 0)
	v.add_child(foot)
	_fit_feat_list.call_deferred(scroll, room.size.y)


## The feat rows scroll if the list would run past the bottom of the field.
func _fit_feat_list(scroll: ScrollContainer, room_h: float) -> void:
	if not is_instance_valid(scroll) or not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_instance_valid(scroll) or feat_list == null:
		return
	var rows_h := (scroll.get_child(0) as Control).get_combined_minimum_size().y
	scroll.custom_minimum_size.y = 0
	var rest := feat_list.get_combined_minimum_size().y
	scroll.custom_minimum_size.y = minf(rows_h, maxf(60.0, room_h - rest))


## Where the feat list goes: the top left of the field, up to the nearest foe still standing.
func _feat_list_room() -> Rect2:
	var area := Rect2(arena.get_global_position() - get_global_position(), arena.size)
	var right := area.end.x - 8.0
	for i in b.living_enemies():
		right = minf(right, enemy_nodes[i]["root"].position.x + area.position.x - 14.0)
	var w := clampf(right - area.position.x - 8.0, minf(520.0, area.size.x - 16.0), 780.0)
	# On a short screen it may run down over the log and commands until it is closed.
	return Rect2(area.position + Vector2(8, 8), Vector2(w, maxf(area.size.y, size.y - area.position.y) - 16.0))


## A readied feat: its button, whether it is ready (or why not), its area and what it does.
func _feat_row(slot: int, width: float) -> Control:
	var id := b.feat_in_slot(slot)
	var ab := b.unit_feat(-1, id)
	var kind := GameFeats.kind_info(str(ab.get("kind", "")))
	var block := b.feat_block(-1, id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var btn := Kit.button(str(ab["name"]), func(): _use_feat(slot), Vector2(170, 34))
	btn.add_theme_font_size_override("font_size", 15)
	btn.clip_text = true
	btn.disabled = not b.can_use_feat(slot)
	btn.tooltip_text = str(ab.get("description", ""))
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	TouchHint.on_hover(btn, func(): _show_area(ab, target), func(): _show_area({}, -1))
	row.add_child(btn)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	row.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	top.add_child(Kit.label(GameFeats.shape_text(id), 14, Color(kind.get("color", "#ffffff"))))
	top.add_child(Kit.label("Ready" if block == "" else block, 14, Kit.GOOD if block == "" else Kit.BAD))
	var what := Kit.label(GameFeats.describe(id), 13, Kit.TEXT if block == "" else Kit.DIM)
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	what.custom_minimum_size = Vector2(width - 214.0, 0)
	v.add_child(what)
	return row


func _close_feats() -> void:
	if feat_list != null:
		feat_list.queue_free()
		feat_list = null
	_show_area({}, -1)


# ---------------------------------------------------------------- playing a turn

func _do(action: Callable) -> void:
	if busy or b.is_over():
		return
	busy = true
	_close_spells()
	_close_skills()
	_close_feats()
	_close_poisons()
	Kit.clear(command_box)
	hint.text = ""
	if auto:
		_auto_panel()
	var log_start := b.log.size()
	action.call()
	for i in range(log_start, b.log.size()):
		_say(b.log[i])
	await _play_events(b.events)
	busy = false
	target = b.first_target() if target < 0 or target >= b.enemies.size() or b.enemies[target]["hp"] <= 0 else target
	_update_view()
	if b.is_over():
		_show_result()
		return
	if b.heir_skip:   # a status cost the heir this turn: the round goes on without them
		hint.text = "%s cannot act this turn." % d.heir.name
		Kit.clear(command_box)
		await get_tree().create_timer(0.6).timeout
		_do(func(): b.pass_turn())
		return
	_build_commands()


## Next event of the same area cast, past deaths and statuses: if there is one, they land together.
func _lands_with_next(events: Array, i: int) -> bool:
	var cast := int(events[i].get("cast", 0))
	if cast == 0 or events[i]["type"] not in ["damage", "miss"]:
		return false
	for j in range(i + 1, events.size()):
		var t: String = events[j]["type"]
		if t in ["death", "status"]:
			continue
		return t in ["damage", "miss"] and int(events[j].get("cast", 0)) == cast
	return false


func _play_events(events: Array) -> void:
	floats = {}
	for i in events.size():
		var ev: Dictionary = events[i]
		_play_one(ev)
		_refresh_chips()
		_update_marks()
		if ev["type"] in ["death", "status"] or _lands_with_next(events, i):
			continue
		await get_tree().create_timer(0.25 if ev["type"] == "cast" else 0.35).timeout


func _play_one(ev: Dictionary) -> void:
	var by := int(ev.get("by", -1))
	match ev["type"]:
		"cast":
			_lunge(_unit_node(by), 22.0)
			var el := str(ev.get("element", ""))
			_float_text(_unit_node(by).position + Vector2(0, -30), str(ev["name"]), Color(GameCombat.element_color(el)) if el != "" else Kit.ACCENT, 20)
			for t in ev.get("targets", []):
				if ev.get("aoe", false):
					_pulse(enemy_nodes[t]["mark"])
		"damage":
			if ev["side"] == "enemy":
				if int(ev.get("cast", 0)) == 0:
					_lunge(_unit_node(by), 22.0)
				var en: Dictionary = enemy_nodes[ev["index"]]
				var txt := GameText.num(int(ev["amount"])) + ("!" if ev["crit"] else "")
				if ev.get("shatter", false):
					txt += " shatter"
				_float_text(en["root"].position + Vector2(en["w"] * 0.3, 6), txt, Color("#ffd24a") if ev["crit"] else Color.WHITE)
				_flash(en["body"])
				en["hp"].value = maxf(float(b.enemies[ev["index"]]["hp"]), en["hp"].value - float(ev["amount"]))
			elif ev["side"] == "ally":
				_lunge(enemy_nodes[ev["index"]]["root"], -22.0)
				var an: Dictionary = ally_nodes[ev["ally"]]
				_float_text(an["root"].position + Vector2(34, -6), _hurt_text(ev), Kit.BAD)
				_flash(an["body"])
				_step_ally_hp(ev["ally"], -int(ev["amount"]))
			else:
				_lunge(enemy_nodes[ev["index"]]["root"], -22.0)
				_float_text(hero_node.position + Vector2(40, 0), _hurt_text(ev), Kit.BAD)
				_flash(hero_node.get_child(0))
				_step_heir_hp(-int(ev["amount"]))
		"heal":
			if ev["side"] == "ally":
				_float_text(ally_nodes[ev["ally"]]["root"].position + Vector2(30, -6), GameText.signed(int(ev["amount"])), Kit.GOOD)
				_step_ally_hp(ev["ally"], int(ev["amount"]))
			else:
				_float_text(hero_node.position + Vector2(40, 0), GameText.signed(int(ev["amount"])), Kit.GOOD)
				_step_heir_hp(int(ev["amount"]))
		"tick":
			var def := GameCombat.status_def(str(ev["id"]))
			var heal: bool = ev.get("heal", false)
			var amt := int(ev["amount"])
			var txt := GameText.signed(amt) if heal else "-" + GameText.num(amt)
			if amt == 0 and int(ev.get("absorbed", 0)) > 0:
				txt = "absorbed"
			_float_text(_ref_node(ev["ref"]).position + Vector2(30, 0), txt, Kit.GOOD if heal else Color(def.get("color", "#ff9a3c")))
			_step_ref_hp(str(ev["ref"]), amt if heal else -amt)
		"status":
			var def := GameCombat.status_def(str(ev["id"]))
			if ev.get("applied", false):
				_float_text(_side_point(str(ev["ref"])), str(def.get("name", ev["id"])), Color(def.get("color", "#ffffff")), 16)
			elif not ev.has("removed"):
				_float_text(_side_point(str(ev["ref"])), "resisted", Kit.DIM, 16)
		"skip":
			var def := GameCombat.status_def(str(ev["id"]))
			_float_text(_side_point(str(ev["ref"])), "%s - no turn" % def.get("name", ev["id"]), Color(def.get("color", "#ffffff")), 16)
		"mana":
			_float_text(_unit_node(by).position + Vector2(30, 0), "+%s MP" % GameText.num(int(ev["amount"])), Kit.MP_BLUE, 18)
		"field", "field_end":   # ground fouled by a feat, or come clear again
			field.queue_redraw()
		"hp_cost":   # a feat paid for in the user's own blood
			_float_text(_unit_node(by).position + Vector2(30, 10), "-%s HP" % GameText.num(int(ev["amount"])), Kit.BAD, 18)
			if by < 0:
				_step_heir_hp(-int(ev["amount"]))
			else:
				_step_ally_hp(by, -int(ev["amount"]))
		"miss":
			if ev["side"] == "enemy":   # a foe slipped the party's blow
				if int(ev.get("cast", 0)) == 0:
					_lunge(_unit_node(by), 22.0)
				var en4: Dictionary = enemy_nodes[ev["index"]]
				_float_text(en4["root"].position + Vector2(en4["w"] * 0.2, 6), "dodge", Kit.DIM)
				return
			_lunge(enemy_nodes[ev["index"]]["root"], -22.0)
			if ev["side"] == "ally":
				_float_text(ally_nodes[ev["ally"]]["root"].position + Vector2(24, -6), "dodge", Kit.DIM)
			else:
				_float_text(hero_node.position + Vector2(30, 0), "dodge", Kit.DIM)
		"ko":
			_knock_out(ev["ally"])
			for en3 in enemy_nodes:   # the foes lose the toughness that companion's presence gave them
				en3["hp"].value *= float(ev.get("foe_scale", 1.0))
				en3["hp"].max_value *= float(ev.get("foe_scale", 1.0))
		"death":
			var en2: Dictionary = enemy_nodes[ev["index"]]
			en2["mark"].visible = false
			var t := create_tween()
			t.tween_property(en2["root"], "modulate:a", 0.0, 0.4)
		"advance":   # the back rank steps up into the fallen front rank's place
			for k in ev["indices"]:
				create_tween().tween_property(enemy_nodes[int(k)]["root"], "position", _foe_spot(int(k)), 0.3)
		"defend":
			_float_text(hero_node.position + Vector2(30, 0), "guard", Kit.MP_BLUE)
		"coat":
			_float_text(hero_node.position + Vector2(30, 70), "blade coated", GamePlague.toxin_color(), 18)
		"coat_end":
			_float_text(hero_node.position + Vector2(30, 0), "coating spent", Kit.DIM, 16)


func _hurt_text(ev: Dictionary) -> String:
	if int(ev["amount"]) == 0 and int(ev.get("absorbed", 0)) > 0:
		return "absorbed"
	return GameText.num(int(ev["amount"]))


func _unit_node(by: int) -> Control:
	return hero_node if by < 0 or by >= ally_nodes.size() else ally_nodes[by]["root"]


func _ref_node(ref: String) -> Control:
	var i := int(ref.get_slice(":", 1))
	match ref.get_slice(":", 0):
		"ally":
			return ally_nodes[i]["root"]
		"enemy":
			return enemy_nodes[i]["root"]
	return hero_node


## Where a status word floats up from: beside the figure, clear of the damage numbers; several
## words on one unit in the same action stack downwards.
func _side_point(ref: String) -> Vector2:
	var k := int(floats.get(ref, 0))
	floats[ref] = k + 1
	var i := int(ref.get_slice(":", 1))
	var p: Vector2
	match ref.get_slice(":", 0):
		"ally":
			p = ally_nodes[i]["root"].position + Vector2(88, 30)
		"enemy":
			p = enemy_nodes[i]["root"].position + Vector2(float(enemy_nodes[i]["w"]) + 6.0, float(enemy_nodes[i]["h"]) * 0.3)
		_:
			p = hero_node.position + Vector2(106, 50)
	return p + Vector2(0, 20.0 * float(k))


func _step_ref_hp(ref: String, delta: int) -> void:
	var i := int(ref.get_slice(":", 1))
	match ref.get_slice(":", 0):
		"ally":
			_step_ally_hp(i, delta)
		"enemy":
			var bar: ProgressBar = enemy_nodes[i]["hp"]
			bar.value = clampf(bar.value + float(delta), 0.0, bar.max_value)
		_:
			_step_heir_hp(delta)


func _step_heir_hp(delta: int) -> void:
	hero_hp.value = clampf(hero_hp.value + float(delta), 0.0, hero_hp.max_value)
	_heir_info(int(hero_hp.value))


func _heir_info(hp: int) -> void:
	hero_info.text = "HP %s  MP %s" % [GameText.num(hp), GameText.num(d.heir.mp)]


## Bars follow the blows one by one; _update_view snaps them to the true values afterwards.
func _step_ally_hp(i: int, delta: int) -> void:
	var an: Dictionary = ally_nodes[i]
	an["hp"].value = clampf(an["hp"].value + float(delta), 0.0, an["hp"].max_value)
	_ally_info(i, int(an["hp"].value))


## "Lv5,000  HP 1,888,159" under a companion; the eleven-digit HP of the last generations is set
## smaller so it stays clear of the next companion.
func _ally_info(i: int, hp: int) -> void:
	var l: Label = ally_nodes[i]["info"]
	l.text = "Lv%s  HP %s" % [GameText.num(b.allies[i].level), GameText.num(hp)]
	var wide := get_theme_font("font", "Label").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x > 140.0
	l.add_theme_font_size_override("font_size", 10 if wide else 12)


func _knock_out(i: int) -> void:
	var an: Dictionary = ally_nodes[i]
	if an["down"]:
		return
	an["down"] = true
	an["ko"].visible = true
	_float_text(an["root"].position + Vector2(10, -6), "knocked out", Kit.BAD)
	var t := create_tween()
	t.tween_property(an["body"], "modulate", Color(0.35, 0.35, 0.4), 0.4)


## A short step towards the other side and back, so it is clear who acted.
func _lunge(node: Control, dx: float) -> void:
	var home := node.position
	var t := create_tween()
	t.tween_property(node, "position:x", home.x + dx, 0.1)
	t.tween_property(node, "position:x", home.x, 0.15)


func _flash(node: CanvasItem) -> void:
	var t := create_tween()
	node.modulate = Color(3, 3, 3)
	t.tween_property(node, "modulate", Color.WHITE, 0.25)


## An area cast lights up every foe it catches for a moment.
func _pulse(mark: CanvasItem) -> void:
	mark.visible = true
	mark.modulate = Color(1, 1, 1, 1)
	var t := create_tween()
	t.tween_property(mark, "modulate:a", 0.0, 0.6)
	t.tween_callback(func():
		mark.modulate = Color.WHITE
		_update_marks())


func _float_text(pos: Vector2, text: String, color: Color, size: int = 26) -> void:
	var l := Kit.label(text, size, color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = pos
	l.z_index = 3
	arena.add_child(l)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(l, "position:y", pos.y - 50, 0.7)
	t.tween_property(l, "modulate:a", 0.0, 0.7)
	t.chain().tween_callback(l.queue_free)


# ---------------------------------------------------------------- state

func _update_marks() -> void:
	var caught: Array = []
	if not shown.is_empty() and not b.is_over():
		caught = b.aoe_targets(shown["ab"], -1, int(shown["at"]))
	var aimed := aim_at if not aiming.is_empty() else target
	for i in enemy_nodes.size():
		var alive: bool = b.enemies[i]["hp"] > 0 and not b.is_over()
		enemy_nodes[i]["sel"].visible = alive and i == aimed
		if not busy:
			enemy_nodes[i]["mark"].visible = alive and i in caught


## Status chips under every figure: tag and turns left, coloured by the status. Each row keeps to
## the room beside its figure (the heir's runs into the open middle of the field).
func _refresh_chips() -> void:
	_fill_chips(hero_chips, "heir", 280.0)
	if not b.coating.is_empty():
		var c := _chip("TOX %d" % int(b.coating["hits"]), GamePlague.toxin_color(), "%s on the blade: %d blow%s left" % [GameItems.item_name(str(b.coating["item"])), int(b.coating["hits"]), "" if int(b.coating["hits"]) == 1 else "s"])
		hero_chips.add_child(c)
		hero_chips.move_child(c, 0)
	for i in ally_nodes.size():
		_fill_chips(ally_nodes[i]["chips"], GameBattle.ref_of(i), 128.0)
	for i in enemy_nodes.size():
		_fill_chips(enemy_nodes[i]["chips"], GameBattle.enemy_ref(i), float(enemy_nodes[i]["w"]) + 52.0)


## Chips that would run past `room` pixels fold into a "+N" chip whose tooltip names them.
func _fill_chips(box: HBoxContainer, ref: String, room: float) -> void:
	Kit.clear(box)
	var list := b.status_list(ref)
	var font := get_theme_font("font", "Label")
	var gap := float(box.get_theme_constant("separation")) + 4.0   # and the outline
	var texts: Array = []
	var widths: Array = []
	var total := 0.0
	for inst in list:
		var def := GameCombat.status_def(inst["id"])
		var stacks := int(inst["stacks"])
		texts.append("%s%s %d" % [def.get("tag", inst["id"]), "x%d" % stacks if stacks > 1 else "", int(inst["turns"])])
		widths.append(font.get_string_size(texts[-1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + gap)
		total += float(widths[-1])
	var fit := list.size()
	if total > room:
		var used := font.get_string_size("+%d" % list.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + gap
		fit = 0
		while fit < list.size() and used + float(widths[fit]) <= room:
			used += float(widths[fit])
			fit += 1
	for k in fit:
		var def := GameCombat.status_def(list[k]["id"])
		box.add_child(_chip(texts[k], Color(def.get("color", "#ffffff")), _chip_tip(list[k])))
	if fit < list.size():
		box.add_child(_chip("+%d" % (list.size() - fit), Kit.DIM, "\n".join(PackedStringArray(list.slice(fit).map(func(inst): return _chip_tip(inst))))))


func _chip(text: String, color: Color, tip: String) -> Label:
	var l := Kit.label(text, 11, color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.tooltip_text = tip
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l


func _chip_tip(inst: Dictionary) -> String:
	var def := GameCombat.status_def(inst["id"])
	return "%s: %d turn%s left" % [def.get("name", inst["id"]), int(inst["turns"]), "" if int(inst["turns"]) == 1 else "s"]


func _update_view() -> void:
	hero_hp.max_value = d.heir.max_hp()
	hero_hp.value = d.heir.hp
	hero_mp.max_value = maxf(1.0, d.heir.max_mp())
	hero_mp.value = d.heir.mp
	_heir_info(d.heir.hp)
	_update_marks()
	_refresh_chips()
	field.queue_redraw()
	for i in enemy_nodes.size():
		enemy_nodes[i]["hp"].max_value = b.enemies[i]["max_hp"]
		enemy_nodes[i]["hp"].value = b.enemies[i]["hp"]
	for i in ally_nodes.size():
		var a: GameHeir = b.allies[i]
		var an: Dictionary = ally_nodes[i]
		an["hp"].max_value = a.max_hp()
		an["hp"].value = a.hp
		an["mp"].max_value = maxf(1.0, a.max_mp())
		an["mp"].value = a.mp
		_ally_info(i, a.hp)


func _show_result() -> void:
	if result_shown:
		return
	result_shown = true
	aiming = {}
	_close_spells()
	_close_skills()
	_close_feats()
	_close_poisons()
	Kit.clear(command_box)
	hint.text = ""
	var msgs: Array = d.finish_battle()
	hero_label.text = "%s  Lv%s" % [d.heir.name, GameText.num(d.heir.level)]
	app.autosave()
	var overlay := ColorRect.new()
	overlay.z_index = 10   # above the enemy name labels, which sit at z 1
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var p := Kit.panel(Color("#221f30"))
	p.custom_minimum_size = Vector2(560, 0)
	center.add_child(p)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	p.add_child(outer)
	var title: String = {"victory": "VICTORY", "defeat": "DEFEAT", "fled": "ESCAPED"}.get(b.result, "")
	outer.add_child(Kit.label(title, 36, Kit.GOOD if b.result == "victory" else (Kit.BAD if b.result == "defeat" else Kit.ACCENT)))
	# The story scrolls when a long fight (or a sick party) tells more than fits; the choice and
	# Continue stay below it, always on screen.
	result_scroll = ScrollContainer.new()
	result_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(result_scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 14)   # keeps the text clear of the scroll bar
	result_scroll.add_child(pad)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pad.add_child(v)
	var foot := VBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	outer.add_child(foot)
	result_panel = p
	for m in msgs:
		var l := Kit.label(m, 16)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	if d.loot.is_empty():
		foot.add_child(Kit.button("Continue", func(): app.show_state(), Vector2(0, 44)))
	elif auto:   # auto-battle settles the bodies as the autopilot would
		_loot_done(v, foot, null, GamePlague.bot_loot(d), "Auto-battle: ")
	else:
		_loot_choice(v, foot)
	_fit_result.call_deferred()


## The dead of a won hunt: search them (extra gold, maybe a find, a chance of their sickness) or
## leave them. The victory's own gold is already counted.
func _loot_choice(v: VBoxContainer, foot: VBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	foot.add_child(box)
	var risk := Kit.label(GamePlague.risk_text(d), 15, Kit.BAD if GamePlague.risk(d) > 0.0 else Kit.DIM)
	risk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(risk)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var search := Kit.button("Search the bodies", func(): _loot_done(v, foot, box, GamePlague.search(d), ""), Vector2(0, 44))
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.tooltip_text = "Extra gold and maybe something useful. Whatever sickness the dead carry, %s risks catching." % d.heir.name
	row.add_child(search)
	var leave := Kit.button("Leave them", func(): _loot_done(v, foot, box, GamePlague.leave(d), ""), Vector2(0, 44))
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(leave)


## Size the result's story to what it holds, but never past the window: beyond that it scrolls,
## showing its latest lines.
func _fit_result() -> void:
	if result_scroll == null or not is_instance_valid(result_scroll) or not is_inside_tree():
		return
	await get_tree().process_frame   # wrapped labels know their height once laid out at the panel's width
	if not is_instance_valid(result_scroll):
		return
	var story := result_scroll.get_child(0) as Control
	result_scroll.custom_minimum_size.y = 0
	var rest := result_panel.get_combined_minimum_size().y
	var room := maxf(80.0, get_viewport_rect().size.y - 40.0 - rest)
	result_scroll.custom_minimum_size.y = minf(story.get_combined_minimum_size().y, room)
	await get_tree().process_frame
	if is_instance_valid(result_scroll):
		result_scroll.scroll_vertical = int(result_scroll.get_v_scroll_bar().max_value)


func _loot_done(v: VBoxContainer, foot: VBoxContainer, box: Control, lines: Array, lead: String) -> void:
	if box != null:
		foot.remove_child(box)
		box.queue_free()
	for k in lines.size():
		var l := Kit.label((lead if k == 0 else "") + str(lines[k]), 16, Kit.BAD if " catches " in str(lines[k]) else Kit.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	app.autosave()
	foot.add_child(Kit.button("Continue", func(): app.show_state(), Vector2(0, 44)))
	_fit_result.call_deferred()
