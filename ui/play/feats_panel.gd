## Feats: points to spend, slots, and every feat the heir has readied, knows, can learn or has yet
## to reach. Learning and readying follow GameFeats' rules: only in a town or right after a rest.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const SIDE_W := 150

var dynasty: GameDynasty
var on_change: Callable   # call after anything that changes the dynasty; the life screen refreshes

var body: VBoxContainer
var note := ""
var scrolls: Array = []


func _ready() -> void:
	var v := Kit.overlay(self, "Feats of %s" % dynasty.heir.name)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	v.add_child(body)
	_build()


func _build() -> void:
	var keep: Array = scrolls.map(func(sc): return sc.scroll_vertical)
	scrolls = []
	Kit.clear(body)
	var d := dynasty
	var h := d.heir
	var pts := GameFeats.points(h)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	body.add_child(top)
	top.add_child(Kit.label("Feat points %s" % GameText.num(pts), 20, Kit.ACCENT))
	top.add_child(Kit.label("Readied %d / %d" % [h.equipped_feats.size(), GameFeats.slots(h)], 20, Kit.ACCENT))
	var next := Kit.label(_next_text(h), 14, Kit.DIM)
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(next)
	var why := GameFeats.manage_block(d)
	var where := _wrap(why if why != "" else _open_text(d), 14, Kit.BAD if why != "" else Kit.GOOD)
	body.add_child(where)
	if note != "":
		body.add_child(_wrap(note, 14, Kit.TEXT))

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 12)
	body.add_child(cols)
	var mine := _column(cols, "%s's feats" % h.name)
	var others := _column(cols, "Feats to learn")

	var readied: Array = h.equipped_feats
	var known: Array = h.known_feats.filter(func(id): return id not in readied)
	if readied.is_empty() and known.is_empty():
		mine.add_child(_wrap("%s knows no feats yet. Learn one with feat points; it is readied at once while a slot is free." % h.name, 14, Kit.DIM))
	if not readied.is_empty():
		mine.add_child(Kit.label("Readied for battle", 16, Kit.ACCENT))
	for id in readied:
		var fid: String = id
		mine.add_child(_card(fid, "Set aside", func(): _act(GameFeats.unequip(d, fid)), why))
	if not known.is_empty():
		mine.add_child(Kit.label("Known, set aside", 16, Kit.ACCENT))
	for id in known:
		var fid: String = id
		var block := why if why != "" else GameFeats.equip_block(h, fid)
		mine.add_child(_card(fid, "Ready", func(): _act(GameFeats.equip(d, fid)), block))

	var open: Array = []
	var later: Array = []
	for id in GameFeats.ids():
		if id in h.known_feats:
			continue
		if GameFeats.requirement_block(h, id) == "":
			open.append(id)
		else:
			later.append(id)
	if open.is_empty():
		others.add_child(_wrap("Nothing more to learn for now.", 14, Kit.DIM))
	for id in open:
		var fid: String = id
		var block := why if why != "" else GameFeats.learn_block(h, fid)
		var c := GameFeats.cost(fid)
		others.add_child(_card(fid, "Learn (%d pt%s)" % [c, "" if c == 1 else "s"], func(): _act(GameFeats.learn(d, fid)), block))
	if not later.is_empty():
		others.add_child(Kit.label("Not yet", 16, Kit.ACCENT))
	for id in later:
		var c := GameFeats.cost(id)
		others.add_child(_card(id, "Learn (%d pt%s)" % [c, "" if c == 1 else "s"], Callable(), GameFeats.requirement_block(h, id)))
	_restore_scroll.call_deferred(keep)


func _open_text(d: GameDynasty) -> String:
	if d.world.is_town():
		return "In %s: feats can be learned and readied here." % d.world.here().get("name", "town")
	return "Rested: feats can be learned and readied until the next thing that takes time."


## "Next feat point at level 13. A third slot opens at level 10."
func _next_text(h: GameHeir) -> String:
	var parts: Array = []
	var p := GameFeats.next_point_level(h.level)
	if p > 0:
		parts.append("Next feat point at level %s." % GameText.num(p))
	var s := GameFeats.next_slot(h.level)
	if not s.is_empty():
		parts.append("Slot %d opens at level %s." % [int(s[1]), GameText.num(int(s[0]))])
	return "  ".join(PackedStringArray(parts))


func _act(msg: String) -> void:
	note = msg
	if on_change.is_valid():
		on_change.call()
	if is_inside_tree():
		_build()


## A rebuild must not jump the lists back to the top.
func _restore_scroll(keep: Array) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	for i in mini(keep.size(), scrolls.size()):
		scrolls[i].scroll_vertical = keep[i]


func _column(parent: Control, title: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	parent.add_child(col)
	col.add_child(Kit.label(title, 18, Kit.ACCENT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	scrolls.append(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	return list


func _wrap(text: String, size: int, color: Color) -> Label:
	var l := Kit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## One feat: name, kind, area and price; what it does; what it asks; a button with the reason it
## cannot be pressed beneath it (the place's reason is told once, above the lists).
func _card(id: String, action: String, cb: Callable, block: String) -> Control:
	var h := dynasty.heir
	var f := GameFeats.def(id)
	var kind := GameFeats.kind_info(str(f["kind"]))
	var card := Kit.panel(Kit.PANEL_LIGHT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var swatch := ColorRect.new()
	swatch.color = Color(kind.get("color", "#ffffff"))
	swatch.custom_minimum_size = Vector2(5, 0)
	row.add_child(swatch)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	row.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(Kit.label(str(f["name"]), 16, Color(kind.get("color", "#ffffff"))))
	var tag := Kit.label("%s  -  %s  -  %d pt%s" % [kind.get("name", ""), GameFeats.shape_text(id), GameFeats.cost(id), "" if GameFeats.cost(id) == 1 else "s"], 12, Kit.DIM)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tag)
	var flavour := _wrap(str(f["description"]), 12, Kit.DIM)
	v.add_child(flavour)
	v.add_child(_wrap(GameFeats.describe(id), 13, Kit.TEXT))
	v.add_child(_wrap(_needs_text(h, id), 12, Kit.DIM))
	card.tooltip_text = "%s\n%s" % [f["name"], kind.get("text", "")]
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(SIDE_W, 0)
	side.add_theme_constant_override("separation", 4)
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(side)
	if action != "":
		var b := Kit.button(action, cb if cb.is_valid() else func(): pass, Vector2(SIDE_W, 34))
		b.add_theme_font_size_override("font_size", 14)
		b.disabled = block != ""
		b.tooltip_text = block if block != "" else "%s: %s" % [action, f["name"]]
		side.add_child(b)
	if block != "" and block != GameFeats.manage_block(dynasty):
		var why := Kit.label(block, 12, Kit.BAD)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.custom_minimum_size = Vector2(SIDE_W, 0)
		side.add_child(why)
	return card


## "Level 12 - A bow in hand - power 1,234 (AGI x0.9, weapon +6% a tier)".
func _needs_text(h: GameHeir, id: String) -> String:
	var parts: Array = GameFeats.requirement_parts(id)
	var f := GameFeats.def(id)
	if float(f.get("mult", 0.0)) > 0.0:
		parts.append("power %s (%s)" % [GameText.num(int(round(GameFeats.power(h, id)))), GameFeats.scaling_text(id)])
	return "  -  ".join(PackedStringArray(parts))


## Lines for the life screen's right-hand panel: what is readied and what is left to spend.
static func summary_lines(d: GameDynasty) -> Array:
	var h := d.heir
	var out: Array = []
	if not h.equipped_feats.is_empty():
		out.append("Readied: %s (%d/%d)" % [", ".join(PackedStringArray(h.equipped_feats.map(func(id): return GameFeats.feat_name(id)))), h.equipped_feats.size(), GameFeats.slots(h)])
	var pts := GameFeats.points(h)
	if pts > 0:
		out.append("%s feat point%s to spend" % [GameText.num(pts), "" if pts == 1 else "s"])
	return out
