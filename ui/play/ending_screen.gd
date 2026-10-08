## The saga's end: the heir of the last generation has died and the chronicle closes.
## A save in this state (GameDynasty.state "ended") always opens here.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const Chronicle := preload("res://ui/play/chronicle_panel.gd")

var app: Node
var d: GameDynasty


func _ready() -> void:
	d = app.dynasty
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	root.add_child(Kit.label("The saga of House %s is over" % d.dynasty_name, 34, Kit.ACCENT))
	var founder: Dictionary = d.history[0] if not d.history.is_empty() else {}
	var start: String = GameWorld.place(GameData.world["start"]).get("name", "home")
	root.add_child(_wrapped("%s and %s, %s since %s set out from %s." % [GameAges.count(d.gen, "generation"), GameAges.count(d.age_number(), "Age"), GameAges.count(int(d.world.year), "year"), founder.get("name", "the founder"), start], 17, Kit.TEXT))
	root.add_child(_wrapped(_last_heir_text(d.last_death), 16, Kit.DIM))

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 12)
	root.add_child(cols)
	_greatest(_column(cols, "Greatest heirs"))
	_legends(_column(cols, "Legends slain"))
	_deaths(_column(cols, "How they died"))

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	root.add_child(foot)
	foot.add_child(Kit.button("Chronicle", func():
		var c := Chronicle.new()
		c.dynasty = d
		add_child(c), Vector2(160, 40)))
	foot.add_child(Kit.button("Main menu", func(): app.show_title(), Vector2(160, 40)))


func _last_heir_text(rec: Dictionary) -> String:
	if rec.is_empty():
		return ""
	var who := "%s, a level %s %s %s," % [rec["name"], GameText.num(int(rec["level"])), GameData.races[rec.get("race_id", "human")]["name"], GameData.classes[rec["class_id"]]["name"]]
	var how := "died of old age at %d" % int(rec["age"]) if rec["cause"] == "old age" else "died at %d: %s" % [int(rec["age"]), rec["cause"]]
	return "The last heir, %s %s." % [who, how]


func _column(cols: HBoxContainer, title: String) -> VBoxContainer:
	var p := Kit.panel()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(p)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	sc.add_child(v)
	v.add_child(Kit.label(title, 20, Kit.ACCENT))
	return v


func _wrapped(text: String, size: int, color: Color) -> Label:
	var l := Kit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## A name on the left and a count on the right.
func _row(col: VBoxContainer, name: String, count: int) -> void:
	var row := HBoxContainer.new()
	var l := _wrapped(name, 15, Kit.TEXT)
	row.add_child(l)
	var n := Kit.label(GameText.num(count), 15, Kit.ACCENT)
	n.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(n)
	col.add_child(row)


func _greatest(col: VBoxContainer) -> void:
	for i in d.ages.hall.size():
		var h: Dictionary = d.ages.hall[i]
		col.add_child(_wrapped("%d. %s" % [i + 1, h["name"]], 16, Kit.ACCENT))
		col.add_child(_wrapped("%s %s, level %s" % [GameData.races[h["race_id"]]["name"], GameData.classes[h["class_id"]]["name"], GameText.num(int(h["level"]))], 14, Kit.TEXT))
		col.add_child(_wrapped("generation %s, Age %s" % [GameText.num(int(h["gen"])), GameText.num(GameAges.age_of(int(h["gen"])))], 13, Kit.DIM))


func _legends(col: VBoxContainer) -> void:
	var totals := d.ages.legend_totals(d)
	var all := 0
	for id in totals:
		all += int(totals[id])
	col.add_child(_wrapped("%s in all. Heirlooms kept: %d." % [GameText.num(all), d.heirlooms.size()], 14, Kit.DIM))
	if totals.is_empty():
		col.add_child(_wrapped("No legend fell to House %s." % d.dynasty_name, 14, Kit.DIM))
	for c in GameData.creatures:
		if totals.has(c["id"]):
			_row(col, c["name"], int(totals[c["id"]]))


func _deaths(col: VBoxContainer) -> void:
	var totals := d.ages.cause_totals(d)
	col.add_child(_wrapped("%s heirs in all." % GameText.num(d.ancestor_count()), 14, Kit.DIM))
	var causes := totals.keys()
	causes.sort_custom(func(a, b): return int(totals[a]) > int(totals[b]) or (int(totals[a]) == int(totals[b]) and str(a) < str(b)))
	for c in causes:
		_row(col, str(c).left(1).to_upper() + str(c).substr(1), int(totals[c]))
