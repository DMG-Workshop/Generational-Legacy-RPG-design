## Shown when an heir dies: the family chooses who carries the legacy forward.
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
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var dead := d.last_death
	root.add_child(Kit.label("%s has passed." % dead["name"], 34, Kit.ACCENT))
	var cname: String = "%s %s" % [GameData.races[dead.get("race_id", "human")]["name"], GameData.classes[dead["class_id"]]["name"]]
	root.add_child(Kit.label("Generation %d  -  %s, level %d  -  died aged %d (%s)  -  %d victories, %d gold left" % [dead["gen"], cname, dead["level"], dead["age"], dead["cause"], dead["battles_won"], dead["gold"]], 16, Kit.DIM))
	if d.pending_archetype != "":
		var a: Dictionary = GameFate.ARCHETYPES[d.pending_archetype]
		root.add_child(Kit.label("Fate has left its mark. The next heir will be a %s: %s" % [a["name"], a["desc"]], 16, Kit.BAD))
	root.add_child(Kit.label("Choose who carries the family name into generation %d. They inherit %d%% of the gold left and every potion; legacy echoes fade by 15%%." % [d.gen + 1, int(round(float(GameData.bal("gold_inherit_fraction")) * 100.0))], 16))

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)
	for i in d.candidates.size():
		row.add_child(_card(i, d.candidates[i]))

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	root.add_child(foot)
	foot.add_child(Kit.button("Chronicle", func():
		var c := Chronicle.new()
		c.dynasty = d
		add_child(c), Vector2(160, 40)))
	foot.add_child(Kit.button("Main menu", func(): app.show_title(), Vector2(160, 40)))


func _card(i: int, c: GameHeir) -> Control:
	var p := Kit.panel()
	p.custom_minimum_size = Vector2(360, 0)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(Kit.label(c.full_name(), 24, Kit.ACCENT))
	v.add_child(Kit.label("%s %s  -  %s" % [c.race()["name"], c.cls()["name"], " & ".join(c.parent_names)], 14, Kit.DIM))
	v.add_child(Kit.label("Fate Value: %d%% (lifetime chance of major failure)" % int(round(c.fate_value * 100.0)), 15, Kit.BAD if c.fate_value > 0.2 else Kit.TEXT))
	v.add_child(Kit.label("Expected lifespan: ~%d years" % int(c.lifespan), 15))
	v.add_child(HSeparator.new())
	v.add_child(Kit.label("Expressed traits", 15, Kit.DIM))
	if c.traits.is_empty():
		v.add_child(Kit.label("none", 14, Kit.DIM))
	for id in c.traits:
		var l := Kit.label(GameData.trait_name(id), 16, Kit.trait_color(id))
		l.tooltip_text = Kit.trait_tooltip(id)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		v.add_child(l)
	if not c.dormant.is_empty():
		v.add_child(Kit.label("Carried dormant", 15, Kit.DIM))
		for id in c.dormant:
			var l2 := Kit.label("  " + GameData.trait_name(id), 14, Kit.DIM)
			l2.tooltip_text = Kit.trait_tooltip(id)
			l2.mouse_filter = Control.MOUSE_FILTER_STOP
			v.add_child(l2)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var idx := i
	v.add_child(Kit.button("Choose %s" % c.name, func(): _choose(idx), Vector2(0, 46)))
	return p


func _choose(i: int) -> void:
	d.choose_heir(i)
	app.autosave()
	app.show_state()
