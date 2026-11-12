extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const Clipboard := preload("res://ui/play/clipboard.gd")
const FilePicker := preload("res://ui/play/file_picker.gd")
const HardModePanel := preload("res://ui/play/hard_mode_panel.gd")

var app: Node
var name_edit: LineEdit
var class_pick: OptionButton
var race_pick: OptionButton
var race_desc: Label
var race_ids: Array = []
var bloodline_pick: OptionButton
var seed_edit: LineEdit
var sex_pick: OptionButton
var class_desc: Label
var bloodline_desc: Label
var class_ids: Array = []
var bloodline_ids: Array = []
var subclass_pick: OptionButton
var subclass_desc: Label
var subclass_ids: Array = [""]   # "" is none
var cont: Button
var slot_box: VBoxContainer
var slot_note: Label
var confirm_row: HBoxContainer
var _pending: Callable = Callable()
var hard_opts: Dictionary = {}   # the founder's hard-mode choices (see GameHardMode), none by default
var hard_button: Button


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
	var sub := Kit.label("Found a dynasty. Every heir inherits your blood, your curses and your legend.", 16, Kit.dim())
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(sub)
	if app.closed_badly:   # the last session ended without warning: offer a report, once
		var crow := HBoxContainer.new()
		crow.add_theme_constant_override("separation", 8)
		box.add_child(crow)
		var cl := Kit.label("The game did not close properly last time. Your save is as it was.", 14, Kit.bad())
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		crow.add_child(cl)
		crow.add_child(Kit.button("Report a problem", func(): app.open_report(), Vector2(170, 36)))
		crow.add_child(Kit.button("Dismiss", func():
			app.closed_badly = false
			crow.queue_free(), Vector2(100, 36)))
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

	form.add_child(Kit.label("Sex"))
	sex_pick = OptionButton.new()
	sex_pick.custom_minimum_size.y = UiSettings.tap_h(0)
	sex_pick.add_item("Male")
	sex_pick.add_item("Female")
	form.add_child(sex_pick)

	form.add_child(Kit.label("Class"))
	class_pick = OptionButton.new()
	class_pick.custom_minimum_size.y = UiSettings.tap_h(0)
	class_ids = GameData.starting_ids(GameData.classes)
	for id in class_ids:
		class_pick.add_item(GameData.classes[id]["name"])
	class_pick.item_selected.connect(func(_i): _refresh())
	form.add_child(class_pick)
	class_desc = Kit.label("", 14, Kit.dim())
	class_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(class_desc)
	hard_button = Kit.button("", _open_hard, Vector2(0, 0))
	hard_button.custom_minimum_size.y = UiSettings.tap_h(0)
	hard_button.clip_text = true
	form.add_child(hard_button)

	form2.add_child(Kit.label("Race"))
	race_pick = OptionButton.new()
	race_pick.custom_minimum_size.y = UiSettings.tap_h(0)
	race_ids = GameData.starting_ids(GameData.races)
	for id in race_ids:
		race_pick.add_item(GameData.races[id]["name"])
	race_pick.selected = maxi(0, race_ids.find("human"))
	race_pick.item_selected.connect(func(_i): _refresh())
	form2.add_child(race_pick)
	race_desc = Kit.label("", 14, Kit.dim())
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
	bloodline_desc = Kit.label("", 14, Kit.dim())
	bloodline_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form2.add_child(bloodline_desc)

	form2.add_child(Kit.label("Subclass (optional)"))
	subclass_pick = OptionButton.new()
	subclass_pick.custom_minimum_size.y = UiSettings.tap_h(0)
	subclass_pick.add_item("None")
	for s in GameSubclass.defs():
		subclass_ids.append(str(s["id"]))
		subclass_pick.add_item(str(s["name"]))
	subclass_pick.item_selected.connect(func(_i): _refresh())
	form2.add_child(subclass_pick)
	subclass_desc = Kit.label("", 14, Kit.dim())
	subclass_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form2.add_child(subclass_desc)

	var seed_label := Kit.label("Seed (blank = random; same seed + same choices = same dynasty)")
	seed_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form2.add_child(seed_label)
	seed_edit = LineEdit.new()
	seed_edit.custom_minimum_size.y = UiSettings.tap_h(0)
	seed_edit.placeholder_text = "e.g. 42"
	form2.add_child(seed_edit)

	var sp := Kit.panel()
	box.add_child(sp)
	slot_box = VBoxContainer.new()
	slot_box.add_theme_constant_override("separation", 6)
	sp.add_child(slot_box)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var begin := Kit.button("Begin Dynasty", _start, Vector2(0, 48))
	begin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(begin)
	cont = Kit.button("Continue" if narrow else "Continue Saved Dynasty", func(): app.continue_game(), Vector2(300 if not narrow else 160, 48))
	buttons.add_child(cont)
	buttons.add_child(Kit.button("Settings", func(): app.open_menu(), Vector2(130, 48)))
	if not UiSettings.is_mobile():   # phones leave an app from the system, not from a button
		buttons.add_child(Kit.button("Quit", func(): get_tree().quit(), Vector2(120, 48)))
	_refresh()
	_build_slots()


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
	class_desc.text = "%s  Skills: %s." % [c["description"], GameSkills.plan_text(cid)]
	if not hybrids.is_empty():
		class_desc.text += "\nChildren with another class may become: %s." % ", ".join(hybrids)
	var r: Dictionary = GameData.races[race_ids[race_pick.selected]]
	race_desc.text = "%s  Lives ~%d years, adult at %d.  %s" % [r["description"], int(r["lifespan"]), int(r["start_age"]), "  ".join(r.get("traits", []).map(func(t): return "%s: %s" % [GameData.trait_name(t), GameData.trait_def(t).get("description", "")]))]
	hard_button.text = GameHardMode.text("button", {"summary": GameHardMode.summary(hard_opts)})
	bloodline_desc.text = GameData.trait_def(bloodline_ids[bloodline_pick.selected]).get("description", "")
	var sid: String = subclass_ids[subclass_pick.selected]
	subclass_desc.text = "Anyone can take one later. One chosen now is stronger." if sid == "" else "%s  %s" % [str(GameSubclass.def(sid)["about"]), "  ".join(GameSubclass.perk_lines(null, sid, true))]


## The save slots: one row per slot to pick from, then Copy backup, Restore backup and Delete for the
## picked one. A slot with a house in it asks before it is overwritten or erased.
func _build_slots() -> void:
	Kit.clear(slot_box)
	var head := Kit.label("Save slot", 16, Kit.ACCENT)
	slot_box.add_child(head)
	for n in range(1, GameSaves.slots() + 1):
		var info := GameSaves.peek(n)
		var text := "Slot %d: empty" % n
		if info["exists"] and not info["valid"]:
			text = "Slot %d: damaged, cannot be read" % n
		elif info["valid"]:
			text = "Slot %d: House %s, gen %d. %s %s %s, level %d" % [n, info["house"], info["gen"], info["heir"], info["race"], info["class"], info["level"]]
			if info["ironman"]:
				text += GameHardMode.text("slot_mark")
		var b := Kit.button(("> " if n == app.slot else "") + text, _pick.bind(n), Vector2(0, 0))
		b.custom_minimum_size.y = UiSettings.tap_h(0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_box.add_child(b)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 8)
	slot_box.add_child(acts)
	var here := GameSaves.peek(app.slot)
	var no_export := GameSaves.why_no_export(app.slot)     # an iron-man house: no backups out, nothing restored over it
	var no_restore := GameSaves.why_no_restore(app.slot)
	var copy := Kit.button("Copy backup", _copy_backup, Vector2(0, 0))
	copy.custom_minimum_size.y = UiSettings.tap_h(0)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.disabled = not here["valid"] or no_export != ""
	acts.add_child(copy)
	var restore := Kit.button("Restore backup", func(): _ask_if_full(_restore_backup, "Restore the backup over this slot's house?"), Vector2(0, 0))
	restore.custom_minimum_size.y = UiSettings.tap_h(0)
	restore.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restore.disabled = no_restore != ""
	acts.add_child(restore)
	var del := Kit.button("Delete", func(): _ask_if_full(_delete_slot, "Erase this slot's house for good?"), Vector2(0, 0))
	del.custom_minimum_size.y = UiSettings.tap_h(0)
	del.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del.disabled = not here["exists"]
	acts.add_child(del)
	var files := HBoxContainer.new()
	files.add_theme_constant_override("separation", 8)
	slot_box.add_child(files)
	var export := Kit.button("Export to file", _export_file, Vector2(0, 0))
	export.custom_minimum_size.y = UiSettings.tap_h(0)
	export.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export.disabled = not here["valid"] or no_export != ""
	files.add_child(export)
	var import := Kit.button("Import from file", func(): _ask_if_full(_import_file, "Import the file over this slot's house?"), Vector2(0, 0))
	import.custom_minimum_size.y = UiSettings.tap_h(0)
	import.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	import.disabled = no_restore != ""
	files.add_child(import)
	confirm_row = HBoxContainer.new()
	confirm_row.add_theme_constant_override("separation", 8)
	confirm_row.visible = false
	slot_box.add_child(confirm_row)
	slot_note = Kit.label("", 14, Kit.dim())
	slot_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot_box.add_child(slot_note)
	if no_export != "":   # the reason the backup buttons are shut, as text
		slot_note.text = "%s %s" % [no_export, no_restore]
	cont.disabled = not here["valid"]


func _pick(n: int) -> void:
	app.use_slot(n)
	_build_slots()


func _say(text: String) -> void:
	slot_note.text = text


## Runs `act` at once when the picked slot is empty; otherwise shows "question" with Yes and No first.
func _ask_if_full(act: Callable, question: String) -> void:
	if not GameSaves.peek(app.slot)["exists"]:
		act.call()
		return
	_pending = act
	Kit.clear(confirm_row)
	var q := Kit.label(question, 14, Kit.bad())
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_row.add_child(q)
	var yes := Kit.button("Yes", _confirmed, Vector2(0, 0))
	yes.custom_minimum_size.y = UiSettings.tap_h(0)
	confirm_row.add_child(yes)
	var no := Kit.button("No", func(): confirm_row.visible = false, Vector2(0, 0))
	no.custom_minimum_size.y = UiSettings.tap_h(0)
	confirm_row.add_child(no)
	confirm_row.visible = true


func _confirmed() -> void:
	var act := _pending
	_pending = Callable()
	confirm_row.visible = false
	if act.is_valid():
		act.call()


func _copy_backup() -> void:
	var text := GameSaves.export_text(app.slot)
	if text.is_empty():
		var why := GameSaves.why_no_export(app.slot)
		_say(why if why != "" else "Nothing in this slot can be copied.")
		return
	Clipboard.set_text(text)
	_say("Backup copied (%d characters). Paste it into a note to keep it." % text.length())


func _export_file() -> void:
	var slot: int = app.slot
	FilePicker.save("Save the house to a file", GameSaves.file_name(slot), func(path: String):
		if path == "":
			_say("Nothing was saved.")
			return
		var r := GameSaves.export_file(slot, path)
		_say("Saved to %s." % path if r["ok"] else r["error"] + " Copy backup works too."))


func _import_file() -> void:
	FilePicker.open("Choose a save file", func(path: String):
		if path == "":
			_say("No save file was chosen. Put a .%s file in %s, or use Restore backup." % [FilePicker.EXT, FilePicker.fallback_dir()] if not FilePicker.fake and not FilePicker.native() else "No save file was chosen.")
			return
		_restore(GameSaves.import_file(path)))


func _restore_backup() -> void:
	_restore(GameSaves.import_text(Clipboard.get_text()))


## Writes a read backup or file into the picked slot, or says why it cannot.
func _restore(r: Dictionary) -> void:
	if not r["ok"]:
		_say(r["error"])
		return
	var why := GameSaves.restore_into(app.slot, r["json"])
	if why != "":
		_say(why)
		return
	_build_slots()
	_say("Restored House %s, generation %d, into slot %d." % [r["house"], r["gen"], app.slot])


func _delete_slot() -> void:
	GameSaves.delete(app.slot)
	_build_slots()
	_say("Slot %d is empty." % app.slot)


func _start() -> void:
	_ask_if_full(_begin, "Slot %d already has a house. Begin a new dynasty over it?" % app.slot)


func _begin() -> void:
	var s := seed_edit.text.strip_edges()
	var seed_value: int = int(s) if s.is_valid_int() else int(Time.get_unix_time_from_system()) % 1000000
	app.new_game(name_edit.text.strip_edges(), class_ids[class_pick.selected], bloodline_ids[bloodline_pick.selected], seed_value, race_ids[race_pick.selected], GameSex.SEXES[sex_pick.selected], subclass_ids[subclass_pick.selected], hard_opts)


## The founder's hard-mode choices: a small panel over the title; the button says what is chosen.
func _open_hard() -> void:
	var p := HardModePanel.new()
	p.opts = hard_opts
	p.on_change = func(o: Dictionary):
		hard_opts = o
		_refresh()
	add_child(p)
