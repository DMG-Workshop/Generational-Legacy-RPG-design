## The figure pane (docs/PLAYER_INTERFACE.md, slice 4), opened by a double click on the heir: the heir drawn in their gear, a square for
## each thing worn (drag a piece of gear onto its square to wear it, double click a square to take it off), their level, class and
## the numbers that matter, and a button for the pack. Rendering only: GameItems and GameCarry do everything.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const SpriteArt := preload("res://ui/play/sprite_art.gd")
const UiSkin := preload("res://ui/play/ui_skin.gd")
const ItemSlot := preload("res://ui/play/item_slot.gd")

var dynasty: GameDynasty
var on_change := Callable()     # func(): something was worn or taken off; the other panes redraw
var on_pack := Callable()       # func(): the Pack button
var _body: VBoxContainer
var _sig := ""
var line := ""                  # what the last action said (shown at the foot)
var _line: Label


func _ready() -> void:
	var v := Kit.overlay(self, dynasty.heir.name)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_body)
	_line = Kit.label("", 13, Kit.dim())
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_line)
	_build()


func signature() -> String:
	var h := dynasty.heir
	return "%s|%s|%d|%d|%d|%d" % [str(h.equipment), str(h.inventory.size()), h.level, h.hp, h.mp, int(GameCarry.carried(h) * 10.0)]


func refresh() -> void:
	if signature() != _sig:
		_build()


func _build() -> void:
	_sig = signature()
	Kit.clear(_body)
	var h := dynasty.heir
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	_body.add_child(top)
	var tex: Texture2D = SpriteArt.figure(h)
	var pic := TextureRect.new()
	pic.texture = tex
	pic.custom_minimum_size = Vector2(150, 250)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if UiSkin.in_skin(self):   # the figure stands in an inset box
		var well := PanelContainer.new()
		well.add_theme_stylebox_override("panel", UiSkin.inset_box(false))
		well.add_child(pic)
		top.add_child(well)
	else:
		top.add_child(pic)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(side)
	side.add_child(Kit.label("Level %d %s" % [h.level, str(GameData.classes.get(h.class_id, {}).get("name", h.class_id))], 16, Kit.ACCENT))
	for slot in GameItems.SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		side.add_child(row)
		var worn := GameItems.equipped(h, str(slot))
		var sq := ItemSlot.new()
		sq.tag = str(slot)
		sq.setup(worn, 52.0, str(slot).capitalize())
		sq.can_drop = func(data: Dictionary): return GameItems.slot_of(str(data["item"])) == slot and str(data["from"]) != str(slot)
		sq.on_drop = func(data: Dictionary): _do(GameItems.equip(dynasty, str(data["item"])))
		sq.on_double = func(): _do(GameItems.unequip(dynasty, str(slot)))
		row.add_child(sq)
		var nm := Kit.label(GameItems.item_name(worn) if worn != "" else "Nothing worn", 13, Kit.TEXT if worn != "" else Kit.dim())
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
	_body.add_child(Kit.label("Health %d of %d    Mana %d of %d" % [h.hp, h.max_hp(), h.mp, h.max_mp()], 14))
	_body.add_child(Kit.label("Carrying %s" % GameCarry.summary(h), 14, Kit.bad() if GameCarry.burdened(h) else Kit.TEXT))
	_body.add_child(Kit.label("%s gold" % GameText.num(h.gold), 14, Kit.ACCENT))
	_body.add_child(Kit.button("Open the pack", func(): if on_pack.is_valid(): on_pack.call(), Vector2(0, 38)))


func _do(text: String) -> void:
	line = text
	_line.text = text
	if on_change.is_valid():
		on_change.call()
	_build()
