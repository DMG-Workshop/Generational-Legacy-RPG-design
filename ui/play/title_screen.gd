extends Control

const Kit := preload("res://ui/play/ui_kit.gd")

var app: Node
var name_edit: LineEdit
var class_pick: OptionButton
var bloodline_pick: OptionButton
var seed_edit: LineEdit
var class_desc: Label
var bloodline_desc: Label
var class_ids: Array = []
var bloodline_ids: Array = []


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(620, 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title := Kit.label("GENERATIONAL LEGACY", 44, Kit.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Kit.label("Found a dynasty. Every heir inherits your blood, your curses and your legend.", 16, Kit.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(Control.new())

	var p := Kit.panel()
	box.add_child(p)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 8)
	p.add_child(form)

	form.add_child(Kit.label("Founder name (blank = random)"))
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Theron"
	form.add_child(name_edit)

	form.add_child(Kit.label("Class"))
	class_pick = OptionButton.new()
	class_ids = GameData.classes.keys()
	class_ids.sort()
	for id in class_ids:
		class_pick.add_item(GameData.classes[id]["name"])
	class_pick.item_selected.connect(func(_i): _refresh())
	form.add_child(class_pick)
	class_desc = Kit.label("", 14, Kit.DIM)
	class_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(class_desc)

	form.add_child(Kit.label("Founding bloodline"))
	bloodline_pick = OptionButton.new()
	bloodline_ids = GameData.traits_in(["bloodline"])
	for id in bloodline_ids:
		bloodline_pick.add_item(GameData.trait_name(id))
	bloodline_pick.item_selected.connect(func(_i): _refresh())
	form.add_child(bloodline_pick)
	bloodline_desc = Kit.label("", 14, Kit.DIM)
	bloodline_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(bloodline_desc)

	form.add_child(Kit.label("Seed (blank = random; same seed + same choices = same dynasty)"))
	seed_edit = LineEdit.new()
	seed_edit.placeholder_text = "e.g. 42"
	form.add_child(seed_edit)

	box.add_child(Kit.button("Begin Dynasty", _start, Vector2(0, 48)))
	var cont := Kit.button("Continue Saved Dynasty", func(): app.continue_game(), Vector2(0, 42))
	cont.disabled = not GameDynasty.has_save()
	box.add_child(cont)
	box.add_child(Kit.button("Quit", func(): get_tree().quit(), Vector2(0, 36)))
	_refresh()


func _refresh() -> void:
	var c: Dictionary = GameData.classes[class_ids[class_pick.selected]]
	class_desc.text = "%s  Skills: %s" % [c["description"], ", ".join(c["skills"].map(func(s): return s["name"]))]
	bloodline_desc.text = GameData.trait_def(bloodline_ids[bloodline_pick.selected]).get("description", "")


func _start() -> void:
	var s := seed_edit.text.strip_edges()
	var seed_value: int = int(s) if s.is_valid_int() else int(Time.get_unix_time_from_system()) % 1000000
	app.new_game(name_edit.text.strip_edges(), class_ids[class_pick.selected], bloodline_ids[bloodline_pick.selected], seed_value)
