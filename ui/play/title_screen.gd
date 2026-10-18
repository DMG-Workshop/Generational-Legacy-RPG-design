extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")

var app: Node
var name_edit: LineEdit
var class_pick: OptionButton
var race_pick: OptionButton
var race_desc: Label
var race_ids: Array = []
var bloodline_pick: OptionButton
var seed_edit: LineEdit
var class_desc: Label
var bloodline_desc: Label
var class_ids: Array = []
var bloodline_ids: Array = []


func _ready() -> void:
	var room := UiSettings.room(self)
	var narrow := room.x < 1140.0
	var scroll := ScrollContainer.new()   # large text on a short screen scrolls the form
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(minf(1080.0, room.x - 40.0), 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title := Kit.label("GENERATIONAL LEGACY", 44 if not narrow else 34, Kit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Kit.label("Found a dynasty. Every heir inherits your blood, your curses and your legend.", 16, Kit.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(sub)
	box.add_child(Control.new())

	var p := Kit.panel()
	box.add_child(p)
	# Side by side when there is room; one above the other on a narrow screen.
	var cols: BoxContainer = VBoxContainer.new() if narrow else HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24 if not narrow else 12)
	p.add_child(cols)
	var form := _column(cols)
	var form2 := _column(cols)

	form.add_child(Kit.label("Founder name (blank = random)"))
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Theron"
	name_edit.custom_minimum_size.y = UiSettings.tap_h(0)
	form.add_child(name_edit)

	form.add_child(Kit.label("Class"))
	class_pick = OptionButton.new()
	class_pick.custom_minimum_size.y = UiSettings.tap_h(0)
	class_ids = GameData.starting_ids(GameData.classes)
	for id in class_ids:
		class_pick.add_item(GameData.classes[id]["name"])
	class_pick.item_selected.connect(func(_i): _refresh())
	form.add_child(class_pick)
	class_desc = Kit.label("", 14, Kit.DIM)
	class_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(class_desc)

	form2.add_child(Kit.label("Race"))
	race_pick = OptionButton.new()
	race_pick.custom_minimum_size.y = UiSettings.tap_h(0)
	race_ids = GameData.starting_ids(GameData.races)
	for id in race_ids:
		race_pick.add_item(GameData.races[id]["name"])
	race_pick.selected = maxi(0, race_ids.find("human"))
	race_pick.item_selected.connect(func(_i): _refresh())
	form2.add_child(race_pick)
	race_desc = Kit.label("", 14, Kit.DIM)
	race_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form2.add_child(race_desc)

	form2.add_child(Kit.label("Founding bloodline"))
	bloodline_pick = OptionButton.new()
	bloodline_pick.custom_minimum_size.y = UiSettings.tap_h(0)
	bloodline_ids = GameData.traits_in(["bloodline"])
	for id in bloodline_ids:
		bloodline_pick.add_item(GameData.trait_name(id))
	bloodline_pick.item_selected.connect(func(_i): _refresh())
	form2.add_child(bloodline_pick)
	bloodline_desc = Kit.label("", 14, Kit.DIM)
	bloodline_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form2.add_child(bloodline_desc)

	var seed_label := Kit.label("Seed (blank = random; same seed + same choices = same dynasty)")
	seed_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form2.add_child(seed_label)
	seed_edit = LineEdit.new()
	seed_edit.custom_minimum_size.y = UiSettings.tap_h(0)
	seed_edit.placeholder_text = "e.g. 42"
	form2.add_child(seed_edit)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var begin := Kit.button("Begin Dynasty", _start, Vector2(0, 48))
	begin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(begin)
	var cont := Kit.button("Continue" if narrow else "Continue Saved Dynasty", func(): app.continue_game(), Vector2(300 if not narrow else 160, 48))
	cont.disabled = not GameDynasty.has_save()
	buttons.add_child(cont)
	buttons.add_child(Kit.button("Settings", func(): app.open_menu(), Vector2(130, 48)))
	if not UiSettings.is_mobile():   # phones leave an app from the system, not from a button
		buttons.add_child(Kit.button("Quit", func(): get_tree().quit(), Vector2(120, 48)))
	_refresh()


func _column(parent: Control) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(minf(500.0, UiSettings.room(self).x - 80.0), 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(col)
	return col


func _refresh() -> void:
	var c: Dictionary = GameData.classes[class_ids[class_pick.selected]]
	var cid: String = class_ids[class_pick.selected]
	var hybrids: Array = []
	for id in GameData.classes:
		var parents: Array = GameData.classes[id].get("parents", [])
		if cid in parents:
			var other: String = parents[1] if parents[0] == cid else parents[0]
			hybrids.append("%s (with a %s)" % [GameData.classes[id]["name"], GameData.classes[other]["name"]])
	class_desc.text = "%s  Skills: %s" % [c["description"], ", ".join(c["skills"].map(func(s): return s["name"]))]
	if not hybrids.is_empty():
		class_desc.text += "\nChildren with another class may become: %s." % ", ".join(hybrids)
	var r: Dictionary = GameData.races[race_ids[race_pick.selected]]
	race_desc.text = "%s  Lives ~%d years, adult at %d.  %s" % [r["description"], int(r["lifespan"]), int(r["start_age"]), "  ".join(r.get("traits", []).map(func(t): return "%s: %s" % [GameData.trait_name(t), GameData.trait_def(t).get("description", "")]))]
	bloodline_desc.text = GameData.trait_def(bloodline_ids[bloodline_pick.selected]).get("description", "")


func _start() -> void:
	var s := seed_edit.text.strip_edges()
	var seed_value: int = int(s) if s.is_valid_int() else int(Time.get_unix_time_from_system()) % 1000000
	app.new_game(name_edit.text.strip_edges(), class_ids[class_pick.selected], bloodline_ids[bloodline_pick.selected], seed_value, race_ids[race_pick.selected])
