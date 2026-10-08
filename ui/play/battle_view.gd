## Side-view battle rendering. All rules live in GameBattle; this only draws and forwards input.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")

var app: Node
var d: GameDynasty
var b: GameBattle
var arena: Control
var hero_node: Control
var hero_hp: ProgressBar
var hero_mp: ProgressBar
var hero_label: Label
var enemy_nodes: Array = []   # [{root, body, hp, label}]
var ally_nodes: Array = []    # [{root, body, hp, mp, info, ko}] - companions, same order as b.allies
var log_label: RichTextLabel
var command_box: HBoxContainer
var target: int = 0
var busy: bool = false
var result_shown: bool = false


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

	var names: Array = b.enemies.map(func(e): return e["name"])
	root.add_child(Kit.label("Battle: %s" % ", ".join(names), 22, Kit.ACCENT))

	var ap := Kit.panel(Color("#191726"))
	ap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ap.clip_contents = true
	root.add_child(ap)
	arena = Control.new()
	arena.clip_contents = true
	ap.add_child(arena)
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
	cp.custom_minimum_size = Vector2(560, 0)
	bottom.add_child(cp)
	var cv := VBoxContainer.new()
	cp.add_child(cv)
	cv.add_child(Kit.label("Commands  (click an enemy to target it)", 14, Kit.DIM))
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


func _say(text: String) -> void:
	log_label.append_text(GameText.group_numbers(text) + "\n")


func _build_actors() -> void:
	var cls := d.heir.cls()
	hero_node = Control.new()
	hero_node.size = Vector2(120, 210)
	var hero_body := ColorRect.new()
	hero_body.color = Color(cls["color"])
	hero_body.size = Vector2(90, 130)
	hero_body.position = Vector2(15, 30)
	hero_node.add_child(hero_body)
	var head := ColorRect.new()
	head.color = Color("#f0d9b5")
	head.size = Vector2(46, 46)
	head.position = Vector2(37, -10)
	hero_node.add_child(head)
	hero_label = Kit.label("%s  Lv%s" % [d.heir.name, GameText.num(d.heir.level)], 14)
	hero_label.position = Vector2(0, 166)
	hero_node.add_child(hero_label)
	hero_hp = Kit.bar(Kit.GOOD, d.heir.max_hp(), d.heir.hp, Vector2(120, 10))
	hero_hp.position = Vector2(0, 188)
	hero_node.add_child(hero_hp)
	hero_mp = Kit.bar(Kit.MP_BLUE, maxf(1.0, d.heir.max_mp()), d.heir.mp, Vector2(120, 6))
	hero_mp.position = Vector2(0, 202)
	hero_node.add_child(hero_mp)
	arena.add_child(hero_node)

	for a in b.allies:
		ally_nodes.append(_build_ally(a))

	for i in b.enemies.size():
		var e: Dictionary = b.enemies[i]
		var root := Control.new()
		var w := 170.0 if e["boss"] else 110.0
		var h := 200.0 if e["boss"] else 130.0
		root.size = Vector2(w, h + 50)
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
		body.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and e["hp"] > 0:
				target = idx
				_update_marks())
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
		var lbl := Kit.label(e["name"], 14)
		lbl.position = Vector2(0, h + 6)
		lbl.z_index = 1
		root.add_child(lbl)
		var hp := Kit.bar(Kit.BAD, e["max_hp"], e["hp"], Vector2(w, 10))
		hp.position = Vector2(0, h + 28)
		root.add_child(hp)
		arena.add_child(root)
		enemy_nodes.append({"root": root, "body": body, "hp": hp, "sel": sel, "w": w, "h": h})


## A companion: smaller figure in class colours with a race-tinted head, name, level and HP.
func _build_ally(a: GameHeir) -> Dictionary:
	var root := Control.new()
	root.size = Vector2(110, 180)
	var body := ColorRect.new()
	body.color = Color(a.cls()["color"])
	body.size = Vector2(66, 92)
	body.position = Vector2(22, 30)
	root.add_child(body)
	var head := ColorRect.new()
	head.color = Color(a.race().get("color", "#f0d9b5"))
	head.size = Vector2(34, 34)
	head.position = Vector2(38, 0)
	root.add_child(head)
	var ko := Kit.label("KO", 22, Kit.BAD)
	ko.add_theme_color_override("font_outline_color", Color.BLACK)
	ko.add_theme_constant_override("outline_size", 6)
	ko.position = Vector2(38, 52)
	ko.visible = a.hp <= 0
	root.add_child(ko)
	var nm := Kit.label(a.name, 13)
	nm.position = Vector2(0, 126)
	root.add_child(nm)
	var info := Kit.label("", 12, Kit.DIM)
	info.position = Vector2(0, 143)
	root.add_child(info)
	var hp := _thin_bar(Kit.GOOD, a.max_hp(), a.hp, Vector2(110, 8))
	hp.position = Vector2(0, 162)
	root.add_child(hp)
	var mp := _thin_bar(Kit.MP_BLUE, maxf(1.0, a.max_mp()), a.mp, Vector2(110, 5))
	mp.position = Vector2(0, 173)
	root.add_child(mp)
	if a.hp <= 0:
		body.modulate = Color(0.35, 0.35, 0.4)
	arena.add_child(root)
	return {"root": root, "body": body, "hp": hp, "mp": mp, "info": info, "ko": ko, "down": a.hp <= 0}


## A bar exactly `size` tall (Kit bars pad to the stylebox margins).
func _thin_bar(color: Color, max_value: float, value: float, size: Vector2) -> ProgressBar:
	var pb := Kit.bar(color, max_value, value, size)
	for k in ["background", "fill"]:
		(pb.get_theme_stylebox(k) as StyleBoxFlat).set_content_margin_all(0)
	return pb


func _layout() -> void:
	if arena == null or hero_node == null:
		return
	var sz := arena.size
	hero_node.position = Vector2(sz.x * 0.16, sz.y * 0.5 - 90)
	# Companions flank the hero, above and below; a third stands forward between them.
	var na := ally_nodes.size()
	for i in na:
		var y := sz.y * 0.5 - 80.0 if na == 1 else sz.y * 0.5 - 195.0 + float(i) * 215.0
		var x := sz.x * 0.30 + float(i % 2) * 24.0
		if i == 2:
			x = sz.x * 0.43
			y = sz.y * 0.5 - 80.0
		ally_nodes[i]["root"].position = Vector2(x, y)
	var n := enemy_nodes.size()
	for i in n:
		var en: Dictionary = enemy_nodes[i]
		var x := sz.x * 0.62 + (i % 2) * 150.0 - (n - 1) * 20.0
		var y := sz.y * 0.5 - float(en["h"]) * 0.5 - 20.0 + (i - (n - 1) * 0.5) * 95.0
		en["root"].position = Vector2(x, y)


func _build_commands() -> void:
	Kit.clear(command_box)
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
		var btn := Kit.button("%s (%s MP)" % [s["name"], GameText.num(b.skill_cost(i))], func(): _do(func(): b.use_skill(idx, target)))
		btn.disabled = not b.can_use_skill(i)
		col2.add_child(btn)
	var pot := Kit.button("Potion (%d)" % d.heir.potions, func(): _do(func(): b.use_potion()))
	pot.disabled = d.heir.potions <= 0
	col3.add_child(pot)
	col3.add_child(Kit.button("Flee", func(): _do(func(): b.flee())))


func _do(action: Callable) -> void:
	if busy or b.is_over():
		return
	busy = true
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
	else:
		_build_commands()


func _play_events(events: Array) -> void:
	for ev in events:
		var by := int(ev.get("by", -1))
		if by >= 0 and by < ally_nodes.size() and ev["type"] in ["damage", "heal"]:
			_lunge(ally_nodes[by]["root"], 22.0)
		elif by < 0 and ev["type"] == "damage" and ev["side"] == "enemy":
			_lunge(hero_node, 22.0)
		match ev["type"]:
			"damage":
				if ev["side"] == "enemy":
					var en: Dictionary = enemy_nodes[ev["index"]]
					_float_text(en["root"].position + Vector2(en["w"] * 0.4, 10), GameText.num(ev["amount"]) + ("!" if ev["crit"] else ""), Color("#ffd24a") if ev["crit"] else Color.WHITE)
					_flash(en["body"])
					en["hp"].value = maxf(float(b.enemies[ev["index"]]["hp"]), en["hp"].value - float(ev["amount"]))
				elif ev["side"] == "ally":
					_lunge(enemy_nodes[ev["index"]]["root"], -22.0)
					var an: Dictionary = ally_nodes[ev["ally"]]
					_float_text(an["root"].position + Vector2(34, -6), GameText.num(ev["amount"]), Kit.BAD)
					_flash(an["body"])
					_step_ally_hp(ev["ally"], -int(ev["amount"]))
				else:
					_lunge(enemy_nodes[ev["index"]]["root"], -22.0)
					_float_text(hero_node.position + Vector2(40, 0), GameText.num(ev["amount"]), Kit.BAD)
					_flash(hero_node.get_child(0))
					hero_hp.value -= float(ev["amount"])
			"heal":
				if ev["side"] == "ally":
					_float_text(ally_nodes[ev["ally"]]["root"].position + Vector2(30, -6), GameText.signed(ev["amount"]), Kit.GOOD)
					_step_ally_hp(ev["ally"], int(ev["amount"]))
				else:
					_float_text(hero_node.position + Vector2(40, 0), GameText.signed(ev["amount"]), Kit.GOOD)
					hero_hp.value += float(ev["amount"])
			"miss":
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
				var t := create_tween()
				t.tween_property(en2["root"], "modulate:a", 0.0, 0.4)
			"defend":
				_float_text(hero_node.position + Vector2(30, 0), "guard", Kit.MP_BLUE)
		_update_marks()
		await get_tree().create_timer(0.35).timeout


## Bars follow the blows one by one; _update_view snaps them to the true values afterwards.
func _step_ally_hp(i: int, delta: int) -> void:
	var an: Dictionary = ally_nodes[i]
	an["hp"].value = clampf(an["hp"].value + float(delta), 0.0, an["hp"].max_value)
	an["info"].text = "Lv%s  HP %s" % [GameText.num(b.allies[i].level), GameText.num(int(an["hp"].value))]


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


func _float_text(pos: Vector2, text: String, color: Color) -> void:
	var l := Kit.label(text, 26, color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = pos
	arena.add_child(l)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(l, "position:y", pos.y - 50, 0.7)
	t.tween_property(l, "modulate:a", 0.0, 0.7)
	t.chain().tween_callback(l.queue_free)


func _update_marks() -> void:
	for i in enemy_nodes.size():
		enemy_nodes[i]["sel"].visible = (i == target and b.enemies[i]["hp"] > 0 and not b.is_over())


func _update_view() -> void:
	hero_hp.max_value = d.heir.max_hp()
	hero_hp.value = d.heir.hp
	hero_mp.max_value = maxf(1.0, d.heir.max_mp())
	hero_mp.value = d.heir.mp
	_update_marks()
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
		an["info"].text = "Lv%s  HP %s" % [GameText.num(a.level), GameText.num(a.hp)]


func _show_result() -> void:
	if result_shown:
		return
	result_shown = true
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
