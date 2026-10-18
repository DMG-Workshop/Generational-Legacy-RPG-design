## Skill trees: the heir's and each companion's, drawn as a graph by tier with the edges between
## nodes. A node is taken (gold), open to buy (green), open but not to be bought now (a green
## outline on a dim fill: too few points, or GameSkillTree.spend_block, e.g. mid-fight) or locked
## (dim); keystones are rounded with violet text, and a violet outline while locked. The side box
## tells the chosen node's exact effects and why it cannot be bought now. Buying follows
## GameSkillTree's rules anywhere but in a fight; refunding needs a town or the quiet after a rest,
## and gold.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const TouchHint := preload("res://ui/play/touch_hint.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const NODE_SIZE := Vector2(134, 44)
const GAP := Vector2(16, 20)
const PAD := 10.0
const SIDE_W := 310
const KEY := Color("#c58fe8")
const LOCKED_EDGE := Color("#3a3650")
const DIM_FILL := Color("#1d1b29")
const OPEN_FILL := Color("#25452c")
const WAITING_EDGE := Color("#4f9a55")   # Kit.GOOD, a step darker: the way is open, not the purse

var dynasty: GameDynasty
var on_change: Callable   # call after anything that changes the dynasty; the opener refreshes
var who := ""             # "" for the heir, else the companion's id
var tree_id := ""
var selected := ""
var note := ""

var body: VBoxContainer
var canvas: Control
var scroll: ScrollContainer
var boxes: Dictionary = {}   # node id -> its button on the canvas
var node_size := NODE_SIZE        # a fingertip tall on touch screens


func _ready() -> void:
	node_size = Vector2(NODE_SIZE.x, UiSettings.tap_h(NODE_SIZE.y))
	var v := Kit.overlay(self, "Skill Trees")
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	v.add_child(body)
	_build()


func _unit() -> GameHeir:
	var u := GameSkillTree.unit_of(dynasty, who)
	if u == null:   # the companion left the party
		who = ""
		u = GameSkillTree.unit_of(dynasty, "")
	return u


func _build() -> void:
	var keep := Vector2(scroll.scroll_horizontal, scroll.scroll_vertical) if scroll != null and is_instance_valid(scroll) else Vector2(-1, -1)
	Kit.clear(body)
	boxes = {}
	var d := dynasty
	var u := _unit()
	var trees := GameSkillTree.trees_for(u.class_id)
	if tree_id not in trees:
		tree_id = trees[0]
		selected = ""

	var units := HFlowContainer.new()
	units.add_theme_constant_override("h_separation", 6)
	units.add_theme_constant_override("v_separation", 6)
	body.add_child(units)
	_tab(units, "%s (heir)" % d.heir.name, who == "", func(): _pick_unit(""))
	for m in d.party.members:
		var mid: String = m["id"]
		_tab(units, str(m["name"]), who == mid, func(): _pick_unit(mid))

	# On a short screen (a phone at a large text size) the points, buttons and tree tabs move to the
	# top of the side column, where they scroll with it, and the tree keeps the height.
	var short := UiSettings.room(self).y < float(UiSettings.setting("short_height"))
	var head: Array = []
	var top := HFlowContainer.new()   # the buttons drop below the name on a narrow screen
	top.add_theme_constant_override("h_separation", 18)
	top.add_theme_constant_override("v_separation", 6)
	head.append(top)
	var pts := GameSkillTree.points(u)
	var who_text := "%s, %s %s, level %s" % [u.name, u.race()["name"], u.cls()["name"], GameText.num(u.level)]
	top.add_child(_wrap(who_text, 15, Kit.TEXT) if short else Kit.label(who_text, 17, Kit.TEXT))
	top.add_child(Kit.label("Skill points %s" % GameText.num(pts), 18, Kit.ACCENT))
	var nxt := GameSkillTree.next_point_for(u)
	if nxt > 0:
		top.add_child(Kit.label("Next at level %s" % GameText.num(nxt), 14, Kit.DIM))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(fill)
	var auto_btn := Kit.button("Spend along the path", func(): _act(GameSkillTree.auto(d, who)), Vector2(190, 32))
	auto_btn.add_theme_font_size_override("font_size", 14)
	auto_btn.disabled = pts <= 0 or GameSkillTree.spend_block(d) != ""
	auto_btn.tooltip_text = "Spend every point the way the autopilot would for a %s." % u.cls()["name"]
	top.add_child(auto_btn)
	var why := GameSkillTree.respec_block(d, who)
	var fee := GameSkillTree.respec_fee(d, u)
	var re := Kit.button("Unlearn all (%s gold)" % GameText.num(fee), func(): _act(GameSkillTree.respec(d, who)), Vector2(200, 32))
	re.add_theme_font_size_override("font_size", 14)
	re.disabled = why != ""
	re.tooltip_text = why if why != "" else "Refund every bought rank. What the blood carries stays."
	top.add_child(re)
	if why != "" and GameSkillTree.spent(u) > 0:
		head.append(_wrap(why, 13, Kit.BAD))

	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	head.append(tabs)
	for tid in trees:
		var t: String = tid
		var n := 0
		for id in GameSkillTree.nodes_of(t):
			n += GameSkillTree.rank(u, id)
		_tab(tabs, "%s  (%d)" % [GameSkillTree.tree(t)["name"], n], t == tree_id, func(): _pick_tree(t))
	if not short:
		for h in head:
			body.add_child(h)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	var frame := Kit.panel(Color("#16141f"))
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(frame)
	scroll = ScrollContainer.new()
	frame.add_child(scroll)
	var center := CenterContainer.new()   # a small tree sits in the middle, a large one scrolls
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	canvas = Control.new()
	center.add_child(canvas)
	_draw_tree(u)
	canvas.draw.connect(_draw_edges.bind(u))
	row.add_child(_side(u, head if short else []))
	if short and selected != "":
		_to_choice.call_deferred()
	if keep.x >= 0.0:
		_restore.call_deferred(keep)


## A short screen's side column opens on the chosen node's box, below the points and tabs.
func _to_choice() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_instance_valid(side_box) and side_box.get_parent().get_parent() is ScrollContainer:
		(side_box.get_parent().get_parent() as ScrollContainer).scroll_vertical = int(side_box.position.y)


func _restore(keep: Vector2) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_horizontal = int(keep.x)
		scroll.scroll_vertical = int(keep.y)


func _tab(parent: Control, text: String, on: bool, cb: Callable) -> void:
	var b := Kit.button(text, cb, Vector2(0, 30))
	b.add_theme_font_size_override("font_size", 14)
	if on:
		b.add_theme_stylebox_override("normal", Kit.style(Color("#3d3860"), 6, Kit.ACCENT))
		b.add_theme_color_override("font_color", Kit.ACCENT)
	parent.add_child(b)


func _pick_unit(id: String) -> void:
	who = id
	tree_id = ""
	selected = ""
	note = ""
	_build()


func _pick_tree(t: String) -> void:
	tree_id = t
	selected = ""
	_build()


func _spot(n: Dictionary) -> Vector2:
	return Vector2(PAD + float(n["col"]) * (node_size.x + GAP.x), PAD + float(int(n["tier"]) - 1) * (node_size.y + GAP.y))


func _draw_tree(u: GameHeir) -> void:
	var most := Vector2.ZERO
	for id in GameSkillTree.nodes_of(tree_id):
		var n := GameSkillTree.node(id)
		var at := _spot(n)
		most = most.max(at + node_size)
		var nid: String = id
		var r := GameSkillTree.rank(u, id)
		var mx := GameSkillTree.max_rank(id)
		var lk := look(dynasty, u, id)
		var b := Button.new()
		b.position = at
		b.size = node_size
		b.custom_minimum_size = node_size
		b.text = "%s\n%d/%d%s" % [n["name"], r, mx, "  *" if GameSkillTree.inheritable(id) else ""]
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 12)
		var keyst := GameSkillTree.is_keystone(id)
		var edge := LOCKED_EDGE
		var fill := DIM_FILL
		var ink := Kit.DIM
		match lk:
			"mastered":
				edge = Kit.ACCENT
				fill = Color("#4a3c18")
				ink = Kit.TEXT
			"taken":
				edge = Kit.ACCENT
				fill = Color("#33301f")
				ink = Kit.TEXT
			"open":
				edge = Kit.GOOD
				fill = OPEN_FILL
				ink = Kit.TEXT
			"waiting":
				edge = WAITING_EDGE
				ink = Kit.TEXT.darkened(0.2)
		if keyst and r == 0:
			ink = KEY
			if lk == "locked":
				edge = KEY.darkened(0.35)
		if nid == selected:
			fill = fill.lightened(0.15)
		var st := Kit.style(fill, 7 if not keyst else 14, edge)
		st.content_margin_top = 4
		st.content_margin_bottom = 4
		for s in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(s, st if s != "hover" else Kit.style(fill.lightened(0.1), 7 if not keyst else 14, edge.lightened(0.2)))
		b.add_theme_color_override("font_color", ink)
		b.add_theme_color_override("font_hover_color", Kit.TEXT)
		b.add_theme_color_override("font_pressed_color", Kit.TEXT)
		if int(u.tree_free.get(id, 0)) > 0:
			b.add_theme_color_override("font_color", Color("#e8a05a"))
		b.tooltip_text = GameSkillTree.node_text(u, id)
		b.set_meta("look", lk)
		b.pressed.connect(func(): _select(nid))
		TouchHint.on_hover(b, func(): _hover(nid))
		canvas.add_child(b)
		boxes[nid] = b
	canvas.custom_minimum_size = most + Vector2(PAD, PAD)


## How a node is drawn: "mastered", "taken" (some ranks), "open" (its next rank can be bought now),
## "waiting" (the way is open but points or the moment are lacking) or "locked".
static func look(d: GameDynasty, u: GameHeir, id: String) -> String:
	var r := GameSkillTree.rank(u, id)
	if r >= GameSkillTree.max_rank(id):
		return "mastered"
	if r > 0:
		return "taken"
	if GameSkillTree.path_block(u, id) != "":
		return "locked"
	return "open" if GameSkillTree.spend_block(d) == "" and GameSkillTree.take_block(u, id) == "" else "waiting"


func _draw_edges(u: GameHeir) -> void:
	for id in boxes:
		var n := GameSkillTree.node(id)
		var to := _spot(n) + Vector2(node_size.x * 0.5, 0.0)
		for r in n.get("requires", []):
			var p := GameSkillTree.node(str(r))
			var from := _spot(p) + Vector2(node_size.x * 0.5, node_size.y)
			var lit := GameSkillTree.rank(u, str(r)) > 0
			var col := Kit.ACCENT if lit and GameSkillTree.rank(u, id) > 0 else (Color("#6a8f6a") if lit else Color("#3a3650"))
			canvas.draw_line(from, to, col, 2.0 if lit else 1.5, true)


func _hover(id: String) -> void:
	if selected == "":
		_show(id)


func _select(id: String) -> void:
	selected = id
	note = ""
	_build()


var side_box: VBoxContainer


## The side column; `head` (the points, buttons and tree tabs of a short screen) above the box.
func _side(u: GameHeir, head: Array = []) -> Control:
	var p := Kit.panel(Kit.PANEL)
	p.custom_minimum_size = Vector2(SIDE_W if not UiSettings.compact(self) else 250, 0)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	sc.add_child(col)
	for h in head:
		col.add_child(h)
	if not head.is_empty():
		col.add_child(HSeparator.new())
	side_box = VBoxContainer.new()
	side_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_box.add_theme_constant_override("separation", 6)
	col.add_child(side_box)
	side_box.set_meta("unit", u)
	_show(selected)
	return p


## The side box: the tree's own words when nothing is chosen, else the node's exact effects, what it
## needs and a button to buy its next rank.
func _show(id: String) -> void:
	if side_box == null or not is_instance_valid(side_box):
		return
	Kit.clear(side_box)
	var u: GameHeir = side_box.get_meta("unit")
	if note != "":
		side_box.add_child(_wrap(note, 13, Kit.GOOD))
		side_box.add_child(HSeparator.new())
	if id == "":
		var t := GameSkillTree.tree(tree_id)
		side_box.add_child(_wrap(str(t["name"]), 17, Kit.ACCENT))
		side_box.add_child(_wrap(str(t.get("description", "")), 13, Kit.DIM))
		side_box.add_child(_wrap("Gold: taken. Green: open to buy. Green outline on a dark fill: open, but not to be bought now (too few points, or not mid-fight). Dim: locked. Violet text: a keystone, which bends a rule of battle and has a price. Orange text: carried in the blood.%s" % (" *: part of it passes to the next heir." if GameSkillTree.nodes_of(tree_id).any(func(x): return GameSkillTree.inheritable(x)) else ""), 12, Kit.DIM))
		for line in _held(u):
			side_box.add_child(_wrap(line, 13, Kit.TEXT))
		for line in GameSkillTree.plan_lines(dynasty, who):
			side_box.add_child(_wrap(line, 13, Color("#e8a05a")))
		return
	var n := GameSkillTree.node(id)
	var r := GameSkillTree.rank(u, id)
	var mx := GameSkillTree.max_rank(id)
	side_box.add_child(_wrap(str(n["name"]), 18, KEY if GameSkillTree.is_keystone(id) else Kit.ACCENT))
	var c := GameSkillTree.cost(id)
	side_box.add_child(_wrap("%sRank %d / %d  -  %d point%s a rank" % ["Keystone  -  " if GameSkillTree.is_keystone(id) else "", r, mx, c, "" if c == 1 else "s"], 13, Kit.DIM))
	if str(n.get("text", "")) != "":
		side_box.add_child(_wrap(str(n["text"]), 13, Kit.DIM))
	if r > 0:
		side_box.add_child(Kit.label("Now", 14, Kit.ACCENT))
		for line in GameSkillTree.effect_lines(id, r, u):
			side_box.add_child(_wrap(line, 13, Kit.TEXT))
	if r < mx:
		side_box.add_child(Kit.label("Next rank" if r > 0 else "Gives", 14, Kit.ACCENT))
		for line in GameSkillTree.effect_lines(id, r + 1, u):
			side_box.add_child(_wrap(line, 13, Kit.TEXT))
	var req: Array = n.get("requires", [])
	if not req.is_empty():
		side_box.add_child(_wrap("Needs a rank in %s." % " or ".join(PackedStringArray(req.map(func(q): return GameSkillTree.node_name(str(q))))), 12, Kit.DIM))
	if int(u.tree_free.get(id, 0)) > 0:
		side_box.add_child(_wrap("%d rank%s carried in the blood: free, never refunded." % [int(u.tree_free[id]), "" if int(u.tree_free[id]) == 1 else "s"], 12, Color("#e8a05a")))
	if GameSkillTree.inheritable(id):
		side_box.add_child(_wrap("Inheritable: part of it passes to the next heir.", 12, Color("#e8a05a")))
	if r < mx:
		var block := GameSkillTree.spend_block(dynasty)
		if block == "":
			block = GameSkillTree.take_block(u, id)
		var waiting := block != "" and GameSkillTree.path_block(u, id) == ""
		var nid := id
		var b := Kit.button("Learn rank %d (%d pt%s)" % [r + 1, c, "" if c == 1 else "s"], func(): _act(GameSkillTree.spend(dynasty, who, nid)), Vector2((SIDE_W if not UiSettings.compact(self) else 250) - 30, 36))
		b.disabled = block != ""
		b.tooltip_text = block
		side_box.add_child(b)
		if waiting:
			side_box.add_child(_wrap("The way is open, but it cannot be bought now: %s" % block, 12, Kit.BAD))
		elif block != "":
			side_box.add_child(_wrap(block, 12, Kit.BAD))


## The keystones held and what the bought ranks add up to, for the side box's resting state.
func _held(u: GameHeir) -> Array:
	var out: Array = []
	for k in GameSkillTree.held_keystones(u):
		var ks := GameSkillTree.keystone(k)
		out.append("Keystone %s: %s %s" % [ks["name"], ks["text"], ks["drawback"]])
	var f := GameSkillTree.fx(u)
	var parts: Array = []
	for s in GameSkillTree.CORE:
		var gains: Array = []
		if float(f["flat"].get(s, 0.0)) > 0.0:
			gains.append("+%s" % GameSkillTree._n(float(f["flat"][s])))
		if float(f["pct"].get(s, 0.0)) > 0.0:
			gains.append("+%s%%" % GameSkillTree._n(float(f["pct"][s]) * 100.0))
		if not gains.is_empty():
			parts.append("%s %s" % [" and ".join(PackedStringArray(gains)), GameSkillTree.label(s)])
	for s in f["bonus"]:
		if s != "crit_damage" and absf(float(f["bonus"][s])) >= 0.00005:
			parts.append("%s%s%% %s" % ["+" if float(f["bonus"][s]) >= 0.0 else "", GameSkillTree._n(float(f["bonus"][s]) * 100.0), GameSkillTree.label(s)])
	if not parts.is_empty():
		out.append("All trees together: " + ", ".join(PackedStringArray(parts)) + ".")
	return out


func _wrap(text: String, size: int, color: Color) -> Label:
	var l := Kit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 120
	return l


func _act(msg: String) -> void:
	note = msg
	if on_change.is_valid():
		on_change.call()
	if is_inside_tree():
		_build()


## Lines for the life screen's right-hand panel.
static func summary_lines(d: GameDynasty) -> Array:
	return GameSkillTree.summary_lines(d)
