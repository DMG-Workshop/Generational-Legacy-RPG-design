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
	call_deferred("_layout")
	_say("A battle begins!")


func _say(text: String) -> void:
	log_label.append_text(text + "\n")


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
	hero_label = Kit.label("%s  Lv%d" % [d.heir.name, d.heir.level], 14)
	hero_label.position = Vector2(0, 166)
	hero_node.add_child(hero_label)
	hero_hp = Kit.bar(Kit.GOOD, d.heir.max_hp(), d.heir.hp, Vector2(120, 10))
	hero_hp.position = Vector2(0, 188)
	hero_node.add_child(hero_hp)
	hero_mp = Kit.bar(Kit.MP_BLUE, maxf(1.0, d.heir.max_mp()), d.heir.mp, Vector2(120, 6))
	hero_mp.position = Vector2(0, 202)
	hero_node.add_child(hero_mp)
	arena.add_child(hero_node)

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
				_update_view())
		root.add_child(body)
		for ex in [0.28, 0.62]:
			var eye := ColorRect.new()
			eye.color = Color("#101010")
			eye.size = Vector2(w * 0.1, w * 0.1)
			eye.position = Vector2(w * ex, h * 0.22)
			eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
			body.add_child(eye)
		var lv := Kit.label("Lv %d" % int(e.get("level", 1)), 13, Kit.ACCENT if str(e["name"]).begins_with("Elite") else Kit.TEXT)
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


func _layout() -> void:
	if arena == null or hero_node == null:
		return
	var sz := arena.size
	hero_node.position = Vector2(sz.x * 0.16, sz.y * 0.5 - 90)
	var n := enemy_nodes.size()
	for i in n:
		var en: Dictionary = enemy_nodes[i]
		var x := sz.x * 0.62 + (i % 2) * 150.0 - (n - 1) * 20.0
		var y := sz.y * 0.5 - float(en["h"]) * 0.5 - 20.0 + (i - (n - 1) * 0.5) * 70.0
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
		var btn := Kit.button("%s (%d MP)" % [s["name"], b.skill_cost(i)], func(): _do(func(): b.use_skill(idx, target)))
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
		match ev["type"]:
			"damage":
				if ev["side"] == "enemy":
					var en: Dictionary = enemy_nodes[ev["index"]]
					_float_text(en["root"].position + Vector2(en["w"] * 0.4, 10), str(ev["amount"]) + ("!" if ev["crit"] else ""), Color("#ffd24a") if ev["crit"] else Color.WHITE)
					_flash(en["body"])
					en["hp"].value = b.enemies[ev["index"]]["hp"]
				else:
					_float_text(hero_node.position + Vector2(40, 0), str(ev["amount"]), Kit.BAD)
					_flash(hero_node.get_child(0))
			"heal":
				_float_text(hero_node.position + Vector2(40, 0), "+%d" % ev["amount"], Kit.GOOD)
			"miss":
				_float_text(hero_node.position + Vector2(30, 0), "dodge", Kit.DIM)
			"death":
				var en2: Dictionary = enemy_nodes[ev["index"]]
				var t := create_tween()
				t.tween_property(en2["root"], "modulate:a", 0.0, 0.4)
			"defend":
				_float_text(hero_node.position + Vector2(30, 0), "guard", Kit.MP_BLUE)
		_update_view()
		await get_tree().create_timer(0.35).timeout


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


func _update_view() -> void:
	hero_hp.max_value = d.heir.max_hp()
	hero_hp.value = d.heir.hp
	hero_mp.max_value = maxf(1.0, d.heir.max_mp())
	hero_mp.value = d.heir.mp
	for i in enemy_nodes.size():
		enemy_nodes[i]["sel"].visible = (i == target and b.enemies[i]["hp"] > 0 and not b.is_over())


func _show_result() -> void:
	if result_shown:
		return
	result_shown = true
	var msgs: Array = d.finish_battle()
	app.autosave()
	var overlay := ColorRect.new()
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
