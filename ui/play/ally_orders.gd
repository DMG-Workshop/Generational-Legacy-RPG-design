## The companions' one-tap orders on the battle screen (data/ui/battle_ui.json "orders"): a row with one cell for each member of the
## party, level with the party strip. An ally's cell has four buttons, Attack, Defend, Skill and Auto, each a small pixel icon over a
## short word and at least a finger tall on a touch screen; the heir's cell has Focus (the party goes for the foe picked, round after
## round, until it falls) and All Auto. A tap only says what was pressed (`ordered`, `focus_pressed`, `all_auto_pressed`); the battle
## screen gives the order through GamePartyOrders, which makes the same GameRound command the long way round would. What is lit comes
## from GamePartyOrders.rows(): a decision is shown by its button's colour and by the words on the figure (see `mark_text`), never by
## colour alone. Rendering only.
extends HBoxContainer

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const BattleSpeed := preload("res://ui/play/battle_speed.gd")
const BattleSkin := preload("res://ui/play/battle_skin.gd")
const FONT := 12
const ICON_SCALE := 2   # the 8x8 glyph drawn 16x16, crisp

signal ordered(by: int, kind: String)
signal focus_pressed
signal all_auto_pressed

static var _icons: Dictionary = {}

var ink := Kit.TEXT              # the words and icons (made to read on the button's face by the screen)
var lit := Kit.ACCENT            # a lit order: what the member will do
var named := false               # a name over each cell (the overlay a short screen opens)
var cells: Dictionary = {}       # by -> {box, buttons: {kind: Button}}
var focus_button: Button = null
var all_auto_button: Button = null
var _signature := ""


# ---------------------------------------------------------------- the data

static func orders() -> Dictionary:
	return BattleSpeed.section("orders")


static func text(key: String, vals: Dictionary = {}) -> String:
	return str((orders().get("text", {}) as Dictionary).get(key, key)).format(vals)


static func kinds() -> Array:
	return orders().get("kinds", [])


static func word(kind: String) -> String:
	return str((orders().get("words", {}) as Dictionary).get(kind, kind))


static func tip(key: String, vals: Dictionary = {}) -> String:
	return str((orders().get("tips", {}) as Dictionary).get(key, key)).format(vals)


## The glyph `name` as a small white texture (tinted by the button), made once; null for a glyph the data does not have.
static func icon(glyph: String) -> Texture2D:
	if _icons.has(glyph):
		return _icons[glyph]
	var rows: Array = (orders().get("glyphs", {}) as Dictionary).get(glyph, [])
	if rows.size() != 8:
		return null
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in mini(8, str(rows[y]).length()):
			if str(rows[y])[x] == "#":
				img.set_pixel(x, y, Color.WHITE)
	img.resize(8 * ICON_SCALE, 8 * ICON_SCALE, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	_icons[glyph] = tex
	return tex


## The words shown on a figure for a member's order: "Attack", "Defend", "Skill", "Auto" or "Held"; "" for nothing. `mark` is a
## GamePartyOrders.rows() entry's "mark".
static func mark_text(mark: String) -> String:
	if mark == "held":
		return "Held"
	return word(mark) if mark != "" else ""


## The glyph for a mark ("" for none).
static func mark_glyph(mark: String) -> String:
	return mark if mark in kinds() else ""


# ---------------------------------------------------------------- the row

func _init() -> void:
	add_theme_constant_override("separation", 4)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_meta(BattleSkin.BUTTONS_META, true)
	name = "AllyOrders"


## Draws `rows` (GamePartyOrders.rows()). `ctx`: {"enabled": bool (orders can be given now), "pin_name": String ("" no focus),
## "target_name": String (the foe picked, "" none), "all_auto": bool}.
func refresh(rows: Array, ctx: Dictionary) -> void:
	var sig := "%d:%s" % [rows.size(), str(named)]
	if sig != _signature:
		_signature = sig
		_rebuild(rows)
	var enabled := bool(ctx.get("enabled", true))
	var at_name := str(ctx.get("target_name", ""))
	var at := text("at", {"name": at_name}) if at_name != "" else ""
	for row in rows:
		var by := int(row["by"])
		if not cells.has(by):
			continue
		var ready: bool = str(row["state"]) == "ready" and enabled
		var buttons: Dictionary = cells[by]["buttons"]
		for kind in buttons:
			var btn: Button = buttons[kind]
			var on: bool = str(row["active"]) == kind
			btn.disabled = not ready or (kind == "skill" and str(row["skill"]) == "")
			var color := lit if on else ink
			for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
				btn.add_theme_color_override(k, color)
			btn.tooltip_text = _tip(kind, row, at)
			btn.set_meta("lit", on)
	if focus_button != null:
		var pin_name := str(ctx.get("pin_name", ""))
		focus_button.text = text("focus_on", {"name": pin_name}) if pin_name != "" else text("focus")
		focus_button.set_meta("compact", text("focus"))
		focus_button.disabled = not enabled
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			focus_button.add_theme_color_override(k, lit if pin_name != "" else ink)
		focus_button.tooltip_text = text("focus_tip")
		focus_button.set_meta("lit", pin_name != "")
	if all_auto_button != null:
		var all_on := bool(ctx.get("all_auto", false))
		all_auto_button.text = text("all_auto_on") if all_on else text("all_auto")
		all_auto_button.disabled = not enabled
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			all_auto_button.add_theme_color_override(k, lit if all_on else ink)
		all_auto_button.tooltip_text = text("all_auto_tip")
		all_auto_button.set_meta("lit", all_on)


func _tip(kind: String, row: Dictionary, at: String) -> String:
	var who := str(row["name"])
	match kind:
		"skill":
			return tip("skill", {"name": who, "skill": row["skill"], "at": at}) if str(row["skill"]) != "" else tip("skill_none", {"name": who})
		"attack":
			return tip("attack", {"name": who, "at": at})
	return tip(kind, {"name": who})


func _rebuild(rows: Array) -> void:
	Kit.clear(self)
	cells = {}
	focus_button = null
	all_auto_button = null
	for row in rows:
		var by := int(row["by"])
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 1)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.custom_minimum_size.x = 0.0
		add_child(cell)
		if named:
			var nm := Kit.label(str(row["name"]), 11, Kit.dim())
			nm.clip_text = true
			cell.add_child(nm)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 3)
		cell.add_child(line)
		if by < 0:
			focus_button = _button(text("focus"), "focus", func(): focus_pressed.emit())
			focus_button.name = "FocusButton"
			all_auto_button = _button(text("all_auto"), "auto", func(): all_auto_pressed.emit())
			all_auto_button.name = "AllAutoButton"
			line.add_child(focus_button)
			line.add_child(all_auto_button)
			cells[by] = {"box": cell, "buttons": {}}
			continue
		var buttons := {}
		for kind in kinds():
			var k := str(kind)
			var btn := _button(word(k), k, func(): ordered.emit(by, k))
			btn.name = "Order_%s" % k
			line.add_child(btn)
			buttons[k] = btn
		cells[by] = {"box": cell, "buttons": buttons}


func _button(label: String, glyph: String, cb: Callable) -> Button:
	var btn := Kit.button(label, cb, Vector2(0, 44))
	btn.add_theme_font_size_override("font_size", FONT)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.clip_text = true
	btn.icon = icon(glyph)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	btn.add_theme_constant_override("icon_max_width", 8 * ICON_SCALE)
	btn.add_theme_constant_override("h_separation", 2)
	return btn


# ---------------------------------------------------------------- the data's own check

static func validate() -> Array:
	var out: Array = []
	var o := orders()
	if o.is_empty():
		return ["ally orders: data/ui/battle_ui.json has no orders section"]
	var ks: Variant = o.get("kinds")
	if typeof(ks) != TYPE_ARRAY or (ks as Array).is_empty():
		return ["ally orders: kinds must be a list"]
	for k in ["attack", "defend", "skill", "auto"]:
		if not (ks as Array).has(k):
			out.append("ally orders: kinds must include %s" % k)
	var glyphs: Dictionary = o.get("glyphs", {}) if typeof(o.get("glyphs")) == TYPE_DICTIONARY else {}
	for k in (ks as Array) + ["focus"]:
		if str((o.get("words", {}) as Dictionary).get(k, "")) == "" and k != "focus":
			out.append("ally orders: words.%s is missing" % k)
		if str((o.get("words", {}) as Dictionary).get(k, "x")).length() > 8:
			out.append("ally orders: words.%s is too long for a button" % k)
		var rows: Variant = glyphs.get(k)
		if typeof(rows) != TYPE_ARRAY or (rows as Array).size() != 8:
			out.append("ally orders: glyph %s must be 8 rows" % k)
			continue
		var any := false
		for r in rows:
			var line := str(r)
			if line.length() != 8 or line.replace("#", "").replace(".", "") != "":
				out.append("ally orders: glyph %s must be 8 rows of 8 '#' and '.'" % k)
				break
			any = any or line.contains("#")
		if not any:
			out.append("ally orders: glyph %s is empty" % k)
	for k in ["attack", "defend", "skill", "skill_none", "auto"]:
		if str((o.get("tips", {}) as Dictionary).get(k, "")) == "":
			out.append("ally orders: tips.%s is missing" % k)
	for k in ["all_auto", "all_auto_on", "all_auto_tip", "focus", "focus_on", "focus_tip", "focus_none", "at", "mark_focus"]:
		if str((o.get("text", {}) as Dictionary).get(k, "")) == "":
			out.append("ally orders: text.%s is missing" % k)
	return out
