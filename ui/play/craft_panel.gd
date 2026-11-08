## The workshop (roadmap item 44): compose a piece from a form, a material gathered and up to three essences, and break
## up gear in the pack for materials and essences. Nothing here computes a result: GameCraft does it all; this draws the
## choices and the preview and calls GameCraft.craft and GameCraft.salvage.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const WIDE := 760.0

var dynasty: GameDynasty
var on_change: Callable
var form_id: String = "sword"
var mat_id: String = ""
var picks: Array = ["", "", ""]   # an essence (an affix id) for each slot, "" for none
var confirm_salvage: String = ""   # a fine piece waiting for a second tap before it is broken up
var _body: VBoxContainer
var _column := WIDE
var note: Label


func _ready() -> void:
	var v := Kit.overlay(self, "The workshop")
	set_meta("modal", true)
	_column = minf(WIDE, Kit.overlay_room(self) - 16.0)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_body = VBoxContainer.new()
	_body.custom_minimum_size = Vector2(_column, 0)
	_body.add_theme_constant_override("separation", 8)
	center.add_child(_body)
	_build()


func _wrap(text: String, size: int = 15, color: Color = Kit.dim()) -> Label:
	var l := Kit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(_column, 0)
	return l


func _build() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var d := dynasty
	_body.add_child(_wrap("In the stores: %s." % GameCraft.describe(d)))
	_body.add_child(_wrap("Gold: %s. %s" % [GameText.num(d.heir.gold), "There is a forge here." if d.world.has_service("forge") else GameCraft.text("no_forge")]))
	note = _wrap("", 15, Kit.TEXT)
	_body.add_child(note)
	_build_make()
	_build_salvage()


# ---------------------------------------------------------------- make

func _forms() -> Array:
	var out: Array = GameLoot.data()["forms"].duplicate()
	out.sort_custom(func(a, b): return str(a["slot"]) + str(a["name"]) < str(b["slot"]) + str(b["name"]))
	return out


func _fix_choices() -> void:
	if not GameLoot.data()["_form"].has(form_id):
		form_id = str(_forms()[0]["id"])
	var mats := GameCraft.materials_for(form_id)
	if mat_id not in mats:
		mat_id = ""
		for m in mats:
			if GameCraft.have(dynasty, str(m)) > 0:
				mat_id = str(m)
				break
		if mat_id == "" and not mats.is_empty():
			mat_id = str(mats[0])
	var allowed := GameCraft.essences_for(form_id, mat_id)
	for i in picks.size():
		if picks[i] != "" and (picks[i] not in allowed or GameCraft.essence_have(dynasty, picks[i]) < 1 or picks.find(picks[i]) != i):
			picks[i] = ""


func _build_make() -> void:
	_fix_choices()
	_body.add_child(Kit.label("Make a piece", 18, Kit.ACCENT))
	var form_pick := OptionButton.new()
	form_pick.name = "FormPick"
	var forms := _forms()
	for i in forms.size():
		form_pick.add_item("%s (%s)" % [forms[i]["name"], forms[i]["slot"]], i)
		if str(forms[i]["id"]) == form_id:
			form_pick.select(i)
	form_pick.item_selected.connect(func(i: int): form_id = str(forms[i]["id"]); _build())
	_body.add_child(_pair("Form", form_pick))
	var mats := GameCraft.materials_for(form_id)
	var mat_pick := OptionButton.new()
	mat_pick.name = "MaterialPick"
	for i in mats.size():
		var m := str(mats[i])
		mat_pick.add_item("%s (tier %d), %d in the stores" % [GameMaterials.name_of(m), GameMaterials.tier_of(m), GameCraft.have(dynasty, m)], i)
		if m == mat_id:
			mat_pick.select(i)
	mat_pick.item_selected.connect(func(i: int): mat_id = str(mats[i]); _build())
	_body.add_child(_pair("Material", mat_pick))
	var allowed := GameCraft.essences_for(form_id, mat_id)
	var owned: Array = allowed.filter(func(a): return GameCraft.essence_have(dynasty, str(a)) > 0)
	for slot in int(GameCraft.setting("max_essences")):
		var s: int = slot
		var pick := OptionButton.new()
		pick.name = "EssencePick%d" % s
		pick.add_item("No essence", 0)
		var at := 0
		for i in owned.size():
			var a := str(owned[i])
			if a in picks and picks.find(a) != s:
				continue
			pick.add_item("%s (%d)" % [GameLoot.data()["_affix"][a]["name"], GameCraft.essence_have(dynasty, a)], i + 1)
			pick.set_item_metadata(pick.item_count - 1, a)
			if picks[s] == a:
				at = pick.item_count - 1
		pick.select(at)
		pick.item_selected.connect(func(i: int): picks[s] = str(pick.get_item_metadata(i)) if i > 0 else ""; _build())
		_body.add_child(_pair("Essence %d" % (s + 1), pick))
	var chosen: Array = picks.filter(func(x): return x != "")
	var p := GameCraft.plan(dynasty, form_id, mat_id, chosen)
	_body.add_child(_wrap(_preview(p), 15, Kit.TEXT))
	var make := Kit.button("Make it", func(): _make(chosen), Vector2(_column, 48))
	make.name = "MakeButton"
	make.disabled = not p["ok"]
	_body.add_child(make)
	if not p["ok"]:
		var reason := _wrap(str(p["why"]))
		reason.name = "MakeReason"
		_body.add_child(reason)


func _pair(title: String, pick: OptionButton) -> Control:
	var row := HBoxContainer.new()
	var t := Kit.label(title, 15, Kit.dim())
	t.custom_minimum_size = Vector2(90, 0)
	row.add_child(t)
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.custom_minimum_size = Vector2(0, UiSettings.tap_h(38))
	pick.clip_text = true
	row.add_child(pick)
	return row


func _preview(p: Dictionary) -> String:
	if not p.has("item"):
		return str(p.get("why", ""))
	var item: Dictionary = p["item"]
	return "%s: %s. Weighs %.1f. Costs %d %s and %s gold at the forge. Quality %d." % [item["name"], GameItems.describe_effects(item["effects"]), float(item["weight"]), int(p["units"]), GameMaterials.name_of(mat_id).to_lower(), GameText.num(int(p["fee"])), int(p["quality"])]


func _make(chosen: Array) -> void:
	_say(GameCraft.craft(dynasty, form_id, mat_id, chosen))
	picks = ["", "", ""]


# ---------------------------------------------------------------- salvage

func _build_salvage() -> void:
	_body.add_child(Kit.label("Break up gear from the pack", 18, Kit.ACCENT))
	var listed := {}
	for id in dynasty.heir.inventory:
		var iid: String = id
		if listed.has(iid) or GameCraft.salvage_yield(iid).is_empty():
			continue
		listed[iid] = true
		var y := GameCraft.salvage_yield(iid)
		var parts: Array = []
		for m in y["materials"]:
			parts.append("%d %s" % [int(y["materials"][m]), GameMaterials.name_of(str(m)).to_lower()])
		for a in y["essences"]:
			parts.append("1 essence of %s" % GameCraft._affix_label(str(a)))
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		row.add_child(_wrap("%s (x%d): gives %s." % [GameItems.item_name(iid), dynasty.heir.inventory.count(iid), ", ".join(parts)], 15, Kit.TEXT))
		var b := Kit.button("Break up", func(): _salvage(iid), Vector2(_column, 44))
		b.name = "Salvage"
		if confirm_salvage == iid:
			b.text = "Sure?"
		row.add_child(b)
		_body.add_child(row)
	if listed.is_empty():
		_body.add_child(_wrap("Nothing in the pack to break up."))
	_body.add_child(Kit.button("Close", func(): queue_free(), Vector2(_column, 48)))


## A plain piece breaks up at once; anything worth more than a plain piece asks a second time.
func _salvage(id: String) -> void:
	var def := GameItems.item_def(id)
	var careful: bool = def.get("unique", false) or str(def.get("rarity", "common")) not in ["common", "fine"] or int(def.get("tier", 1)) >= 3
	if careful and confirm_salvage != id:
		confirm_salvage = id
		_build()
		return
	confirm_salvage = ""
	_say(GameCraft.salvage(dynasty, id))


func _say(msg: String) -> void:
	confirm_salvage = ""
	dynasty._say(msg)
	if on_change.is_valid():
		on_change.call()
	_build()
	note.text = msg
