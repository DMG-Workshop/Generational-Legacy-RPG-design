## Side-view battle rendering. All rules live in GameBattle; this only draws and forwards input.
## Every combatant stands where the battle placed it (paces, see GameCombat); an area ability is
## shown on the field, with every foe it would catch outlined, before it is cast.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const AREA := Color("#ff9a3c")

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
var aiming: Dictionary = {}    # {ab, skill, spell} while the player picks where an ability lands
var aim_at: int = -1
var shown: Dictionary = {}     # {ab, at}: the area drawn on the field
var spell_list: Control = null
var aim_info: Label = null      # the aim panel's "catches N foes" line
var floats: Dictionary = {}     # ref -> status words floated this action, so they stack instead of overlap


func _ready() -> void:
	d = app.dynasty
	b = d.battle
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var title := Kit.label("Battle: %s" % _foe_list(), 22, Kit.ACCENT)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	root.add_child(title)

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

	var bottom := HBoxContainer.new()
	bottom.custom_minimum_size = Vector2(0, 170)
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)
	var lp := Kit.panel(Color("#1a1828"))
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(lp)
	log_label = Kit.rich()
	lp.add_child(log_label)
	var cp := Kit.panel()
	cp.custom_minimum_size = Vector2(600, 0)
	bottom.add_child(cp)
	var cv := VBoxContainer.new()
	cp.add_child(cv)
	hint = Kit.label("", 14, Kit.DIM)
	hint.clip_text = true
	hint.custom_minimum_size = Vector2(560, 0)
	cv.add_child(hint)
	command_box = HBoxContainer.new()
	command_box.add_theme_constant_override("separation", 8)
	cv.add_child(command_box)
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


func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel") and not aiming.is_empty():
		_cancel_aim()
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
		body.mouse_entered.connect(func(): _on_foe_hover(idx, true))
		body.mouse_exited.connect(func(): _on_foe_hover(idx, false))
		root.add_child(body)
		for ex in [0.28, 0.62]:
			var eye := ColorRect.new()
			eye.color = Color("#101010")
			eye.size = Vector2(w * 0.1, w * 0.1)
			eye.position = Vector2(w * ex, h * 0.22)
			eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
			body.add_child(eye)
		var lv := Kit.label("Lv %s" % GameText.num(int(e.get("level", 1))), 13, Kit.ACCENT if str(e["name"]).begins_with("Elite") else Kit.TEXT)
		lv.add_theme_constant_override("outline_size", 4)
		lv.add_theme_color_override("font_outline_color", Color.BLACK)
		lv.position = Vector2(4, h - 22)
		lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(lv)
		var lbl := Kit.label(e["name"], 13)
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
	var pos := center - Vector2(node.size.x * 0.5, anchor_y)
	pos.x = clampf(pos.x, 0.0, maxf(0.0, arena.size.x - node.size.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, arena.size.y - node.size.y))
	return pos


func _foe_spot(i: int) -> Vector2:
	var en: Dictionary = enemy_nodes[i]
	return _spot(en["root"], _px(b.enemy_point(i)), float(en["h"]) * 0.5 + 10.0)


func _layout() -> void:
	if arena == null or hero_node == null:
		return
	hero_node.position = _spot(hero_node, _px(b.unit_point(-1)), 90.0)
	for i in ally_nodes.size():
		ally_nodes[i]["root"].position = _spot(ally_nodes[i]["root"], _px(b.unit_point(i)), 64.0)
	for i in enemy_nodes.size():
		enemy_nodes[i]["root"].position = _foe_spot(i)
	field.queue_redraw()


## The area being aimed, drawn on the ground in paces mapped to the screen.
func _draw_field() -> void:
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
			for k in 40:
				pts.append(_px(aim + Vector2.from_angle(TAU * float(k) / 40.0) * r))
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
## Aiming starts on the target if the area reaches it, else on the first foe it does reach.
func _begin_aim(ab: Dictionary, skill: int, spell: String) -> void:
	aiming = {"ab": ab, "skill": skill, "spell": spell}
	aim_at = b._valid_target(target)
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
	if int(plan["skill"]) >= 0:
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
	var sp := GameCombat.spell(id)
	if GameCombat.is_aoe(sp):
		_begin_aim(sp, -1, id)
	else:
		_do(func(): b.cast_spell(id, target))


# ---------------------------------------------------------------- commands

func _build_commands() -> void:
	Kit.clear(command_box)
	aim_info = null
	if not aiming.is_empty():
		_build_aim_commands()
		return
	hint.text = "Commands  (click an enemy to target it)"
	var col1 := VBoxContainer.new()
	var col2 := VBoxContainer.new()
	var col3 := VBoxContainer.new()
	for c in [col1, col2, col3]:
		c.add_theme_constant_override("separation", 6)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		command_box.add_child(c)
	col1.add_child(Kit.button("Attack", func(): _do(func(): b.attack(target))))
	col1.add_child(Kit.button("Defend", func(): _do(func(): b.defend())))
	for i in b.skill_count():
		var s := b.skill_info(i)
		var idx := i
		var btn := _small_button("%s (%s MP)" % [s["name"], GameText.num(b.skill_cost(i))], func(): _use_skill(idx))
		btn.disabled = not b.can_use_skill(i)
		btn.tooltip_text = "%s  -  %s\n%s" % [s["name"], GameCombat.shape_text(s), GameCombat.describe(s)]
		btn.mouse_entered.connect(func(): _show_area(s, target))
		btn.mouse_exited.connect(func(): _show_area({}, -1))
		col2.add_child(btn)
	if not GameCombat.class_spell_plan(d.heir.class_id).is_empty() or not b.known_spells().is_empty():
		var sb := Kit.button("Spells (%d)" % b.known_spells().size(), func(): _open_spells())
		sb.disabled = b.known_spells().is_empty()
		sb.tooltip_text = "The spells %s knows." % d.heir.name if not b.known_spells().is_empty() else "%s has learned no spells yet." % d.heir.name
		col3.add_child(sb)
	var pot := Kit.button("Potion (%s)" % GameText.num(d.heir.potions), func(): _do(func(): b.use_potion()))
	pot.disabled = d.heir.potions <= 0
	col3.add_child(pot)
	col3.add_child(Kit.button("Flee", func(): _do(func(): b.flee())))


func _small_button(text: String, cb: Callable) -> Button:
	var btn := Kit.button(text, cb)
	btn.add_theme_font_size_override("font_size", 14)
	btn.clip_text = true
	btn.custom_minimum_size = Vector2(0, 38)
	return btn


func _build_aim_commands() -> void:
	var ab: Dictionary = aiming["ab"]
	hint.text = "%s: click a foe to aim, click it again to %s." % [ab["name"], "cast" if str(aiming["spell"]) != "" else "strike"]
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	command_box.add_child(v)
	var what := Kit.label("%s  -  %s" % [GameCombat.shape_text(ab), GameCombat.describe(ab)], 13, Kit.TEXT)
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	what.custom_minimum_size = Vector2(380, 0)
	v.add_child(what)
	aim_info = Kit.label(_aim_text(ab, aim_at, false), 14, AREA)
	aim_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aim_info.custom_minimum_size = Vector2(380, 0)
	v.add_child(aim_info)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	side.custom_minimum_size = Vector2(150, 0)
	command_box.add_child(side)
	var go := Kit.button("Cast" if str(aiming["spell"]) != "" else "Use", func(): _confirm_aim())
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
		return "Toward %s it reaches no foe." % b.enemies[at]["name"]
	var foes := "%d foe%s" % [n, "" if n == 1 else "s"]
	var whom := str(b.enemies[at]["name"]) + ("" if at in caught else " (beyond reach)")
	var text := ("Over %s: would catch %s" if hovering else "Aimed at %s: catches %s") % [whom, foes]
	var dmg := b.estimate(-1, ab, at)
	if dmg >= 1.0:
		text += ", about %s damage%s" % [GameText.num(int(round(dmg))), " in all" if n > 1 else ""]
	return text + "."


# ---------------------------------------------------------------- spell list

func _open_spells() -> void:
	if busy or spell_list != null:
		return
	spell_list = Control.new()
	spell_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	spell_list.z_index = 5
	add_child(spell_list)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_close_spells())
	spell_list.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.style(Color("#1a1828"), 8, Kit.ACCENT))
	p.position = Vector2(150, 48)
	p.size = Vector2(980, 470)
	spell_list.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := Kit.label("Spells  -  %s has %s / %s MP" % [d.heir.name, GameText.num(d.heir.mp), GameText.num(d.heir.max_mp())], 20, Kit.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(Kit.button("Close", func(): _close_spells(), Vector2(100, 34)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 4)
	scroll.add_child(rows)
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
	var sp := GameCombat.spell(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var btn := Kit.button("%s  (%s MP)" % [sp["name"], GameText.num(b.spell_cost(id))], func(): _use_spell(id), Vector2(260, 34))
	btn.add_theme_font_size_override("font_size", 15)
	btn.clip_text = true
	btn.disabled = not b.can_cast(id)
	btn.tooltip_text = str(sp.get("text", ""))
	btn.mouse_entered.connect(func(): _show_area(sp, target))
	btn.mouse_exited.connect(func(): _show_area({}, -1))
	row.add_child(btn)
	var el := str(sp.get("element", ""))
	var shape := Kit.label(GameCombat.shape_text(sp), 14, Color(GameCombat.element_color(el)) if el != "" else Kit.TEXT)
	shape.custom_minimum_size = Vector2(96, 0)
	row.add_child(shape)
	var what := Kit.label(GameCombat.describe(sp) + ("" if b.can_cast(id) else "  (not enough MP)"), 13, Kit.TEXT if b.can_cast(id) else Kit.DIM)
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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


# ---------------------------------------------------------------- playing a turn

func _do(action: Callable) -> void:
	if busy or b.is_over():
		return
	busy = true
	_close_spells()
	Kit.clear(command_box)
	hint.text = ""
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
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var title: String = {"victory": "VICTORY", "defeat": "DEFEAT", "fled": "ESCAPED"}.get(b.result, "")
	v.add_child(Kit.label(title, 36, Kit.GOOD if b.result == "victory" else (Kit.BAD if b.result == "defeat" else Kit.ACCENT)))
	for m in msgs:
		var l := Kit.label(m, 16)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	v.add_child(Kit.button("Continue", func(): app.show_state(), Vector2(0, 44)))
