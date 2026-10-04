## Town shops: forge, store and temple; the heir's gear and pack.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")

const TAB_NAMES := {"forge": "Forge", "store": "Store", "temple": "Temple", "gear": "Gear"}
const TAB_NOTES := {
	"forge": "Weapons and armor, hammered out to order.",
	"store": "Rings, charms and curiosities.",
	"temple": "Blessed trinkets, and the priests' services.",
	"gear": "What the heir wears and carries. Gear passes to the next heir.",
}
const TIER_COLORS := ["#e8e4f0", "#e8e4f0", "#7fb7ff", "#c58fe8", "#ffd75e"]
const SLOT_HEADERS := {"weapon": "Weapons", "armor": "Armor", "trinket": "Trinkets"}
const LEFT_W := 370

var dynasty: GameDynasty
var on_change: Callable   # call after anything that changes the dynasty; the life screen refreshes

var tab: String = ""
var gold_label: Label
var price_label: Label
var note: Label
var tabs: HBoxContainer
var tab_note: Label
var scroll: ScrollContainer
var rows: VBoxContainer
var side: VBoxContainer
var confirm_sell: String = ""   # a unique item waiting for a second click before it is sold


func _ready() -> void:
	var v := Kit.overlay(self, "Shops of %s" % dynasty.world.here()["name"])
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	v.add_child(top)
	gold_label = Kit.label("", 20, Kit.ACCENT)
	top.add_child(gold_label)
	price_label = Kit.label("", 14, Kit.DIM)
	price_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(price_label)
	note = Kit.label("", 14, Kit.TEXT)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	note.custom_minimum_size = Vector2(100, 0)
	top.add_child(note)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	v.add_child(tab_row)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	tab_row.add_child(tabs)
	tab_note = Kit.label("", 14, Kit.DIM)
	tab_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tab_row.add_child(tab_note)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	v.add_child(body)
	scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)
	var sp := Kit.panel()
	sp.custom_minimum_size = Vector2(300, 0)
	body.add_child(sp)
	side = VBoxContainer.new()
	side.add_theme_constant_override("separation", 4)
	sp.add_child(side)

	var shops := GameItems.shops_here(dynasty)
	tab = shops[0] if not shops.is_empty() else "gear"
	_rebuild()


func _show(t: String) -> void:
	tab = t
	confirm_sell = ""
	scroll.scroll_vertical = 0
	_rebuild()


func _rebuild() -> void:
	var h := dynasty.heir
	gold_label.text = "Gold %d" % h.gold
	price_label.text = _price_text()
	Kit.clear(tabs)
	for t in GameItems.shops_here(dynasty) + ["gear"]:
		var tt: String = t
		var b := Kit.button(TAB_NAMES[tt], func(): _show(tt), Vector2(110, 34))
		b.toggle_mode = true
		b.button_pressed = tt == tab
		tabs.add_child(b)
	tab_note.text = TAB_NOTES[tab]
	var keep := scroll.scroll_vertical
	Kit.clear(rows)
	match tab:
		"gear":
			_build_gear()
		"temple":
			_build_temple()
			_build_wares("temple")
		_:
			_build_wares(tab)
	_build_side()
	_restore_scroll.call_deferred(keep)


func _restore_scroll(v: int) -> void:
	if is_inside_tree():
		await get_tree().process_frame
		scroll.scroll_vertical = v


func _price_text() -> String:
	var parts: Array = ["shop tier %d" % GameItems.shop_tier(dynasty)]
	var persuasion := GameItems.persuasion(dynasty)
	if persuasion > 0.0:
		parts.append("persuasion -%d%%" % int(round(persuasion * 100.0)))
	elif persuasion < 0.0:
		parts.append("wary merchants +%d%%" % int(round(-persuasion * 100.0)))
	var infamy := dynasty.echo_total("infamy")
	if infamy > 0.0:
		parts.append("infamy +%d%%" % int(round(infamy * 100.0)))
	return "  -  ".join(parts)


## Act on the dynasty, record the result and refresh everything that shows it.
func _act(msg: String) -> void:
	confirm_sell = ""
	dynasty._say(msg)
	note.text = msg
	note.tooltip_text = msg
	if on_change.is_valid():
		on_change.call()
	if is_inside_tree():
		_rebuild()


## Unique gear asks for a second click: it can never be bought back.
func _sell(id: String) -> void:
	if GameItems.item_def(id).get("unique", false) and confirm_sell != id:
		confirm_sell = id
		_rebuild()
		return
	confirm_sell = ""
	_act(GameItems.sell(dynasty, id))


# ---------------------------------------------------------------- tabs

func _build_wares(service: String) -> void:
	var h := dynasty.heir
	var stock := GameItems.stock(dynasty, service)
	if service == "temple":
		rows.add_child(_section("Wares"))
	if stock.is_empty():
		rows.add_child(Kit.label("Nothing on the shelves.", 15, Kit.DIM))
	var kinds := {}
	for id in stock:
		kinds[GameItems.slot_of(id)] = true
	var last_slot := ""
	for id in stock:
		var iid: String = id
		if kinds.size() > 1 and GameItems.slot_of(iid) != last_slot:
			last_slot = GameItems.slot_of(iid)
			rows.add_child(_section(SLOT_HEADERS.get(last_slot, last_slot.capitalize())))
		var cost := GameItems.price(dynasty, iid)
		var owned := GameItems.owns(h, iid)
		var b := Kit.button("Owned" if owned else "Buy", func(): _act(GameItems.buy(dynasty, iid)), Vector2(96, 34))
		b.disabled = owned or h.gold < cost
		if not owned and h.gold < cost:
			b.tooltip_text = "You need %d more gold." % (cost - h.gold)
		rows.add_child(_item_row(iid, "%dg" % cost, [b], "", Kit.ACCENT if owned else _afford(cost)))


func _build_temple() -> void:
	var h := dynasty.heir
	rows.add_child(_section("Services"))
	var curses := GameItems.curses_on(h)
	var cost := GameItems.cleanse_price(dynasty)
	if curses.is_empty():
		rows.add_child(_service_row("Cleansing", "No curse lies on %s." % h.name, "", "", Kit.TEXT, "", null))
	for t in curses:
		var tid: String = t
		var dormant := tid not in h.traits
		var b := Kit.button("Cleanse", func(): _act(GameItems.cleanse(dynasty, tid)), Vector2(96, 34))
		b.disabled = h.gold < cost
		var title := "%s%s" % [GameData.trait_name(tid), "  (dormant)" if dormant else ""]
		var what := "Gone for good; later children are spared."
		rows.add_child(_service_row(title, str(GameData.trait_def(tid).get("description", "")), what, "%dg" % cost, Kit.BAD, Kit.trait_tooltip(tid), b, _afford(cost)))
	var pcost := GameItems.prayer_price(dynasty)
	var pb := Kit.button("Pray", func(): _act(GameItems.pray(dynasty)), Vector2(96, 34))
	pb.disabled = not GameItems.can_pray(dynasty) or h.gold < pcost
	var floor_pct := int(round(float(GameData.bal("fate_min")) * 100.0))
	var drop := int(round(float(GameData.bal("prayer_fate_drop")) * 100.0))
	var fate_now := "Fate Value %d%%; prayer cannot take it below %d%%." % [int(round(h.fate_value * 100.0)), floor_pct]
	var effect := "-%d%% Fate Value" % drop
	if GameItems.trials_left(h) == 0:
		effect = "No trials left to face"
	elif not GameItems.can_pray(dynasty):
		effect = "Fate is as light as it gets"
	rows.add_child(_service_row("Prayer", fate_now, effect, "%dg" % pcost, Kit.TEXT, "A lower Fate Value makes failure at life's milestones less likely.", pb, _afford(pcost)))
	var c := GameItems.temple_uses(dynasty, "cleanse")
	var p := GameItems.temple_uses(dynasty, "prayer")
	rows.add_child(Kit.label("This life: %d cleansing%s, %d prayer%s. Each costs more than the last." % [c, "" if c == 1 else "s", p, "" if p == 1 else "s"], 13, Kit.DIM))


func _build_gear() -> void:
	var h := dynasty.heir
	rows.add_child(_section("Worn"))
	for slot in GameItems.SLOTS:
		var s: String = slot
		var id := GameItems.equipped(h, s)
		var b := Kit.button("Take off", func(): _act(GameItems.unequip(dynasty, s)), Vector2(96, 34))
		b.disabled = id == ""
		if id == "":
			rows.add_child(_service_row(s.capitalize(), "Nothing worn.", "", "", Kit.DIM, "", b))
		else:
			rows.add_child(_item_row(id, "", [b], s.capitalize()))
	rows.add_child(_section("Pack"))
	if h.inventory.is_empty():
		rows.add_child(Kit.label("The pack is empty.", 15, Kit.DIM))
	var can_sell := not GameItems.shops_here(dynasty).is_empty()
	for id in h.inventory:
		var iid: String = id
		var eb := Kit.button("Equip", func(): _act(GameItems.equip(dynasty, iid)), Vector2(80, 34))
		eb.disabled = GameItems.slot_of(iid) not in GameItems.SLOTS
		var sb := Kit.button("Sell", func(): _sell(iid), Vector2(80, 34))
		sb.disabled = not can_sell
		if confirm_sell == iid:
			sb.text = "Sure?"
			sb.tooltip_text = "Click again to sell the %s. It cannot be bought back." % GameItems.item_name(iid)
		rows.add_child(_item_row(iid, "sells %dg" % GameItems.sell_price(dynasty, iid), [eb, sb]))


func _build_side() -> void:
	Kit.clear(side)
	var h := dynasty.heir
	side.add_child(Kit.label("Worn", 18, Kit.ACCENT))
	for slot in GameItems.SLOTS:
		var id := GameItems.equipped(h, slot)
		side.add_child(Kit.label("%s: %s" % [str(slot).capitalize(), GameItems.item_name(id) if id != "" else "-"], 14, Kit.TEXT if id != "" else Kit.DIM))
		if id != "":
			var e := _wrap(Kit.label("   " + GameItems.describe(id), 12, Kit.DIM))
			side.add_child(e)
	side.add_child(HSeparator.new())
	side.add_child(Kit.label("%s, %s fighter" % [h.name, "a spell" if GameItems.fighting_style(h) == "magic" else "a weapon"], 15, Kit.ACCENT))
	side.add_child(Kit.label("Attack %d    Magic %d" % [int(h.attack_power()), int(h.magic_power())], 14))
	side.add_child(Kit.label("Defense %d" % int(h.defense()), 14))
	side.add_child(Kit.label("Dodge %d%%    Crit %d%%" % [int(round(h.dodge_chance() * 100.0)), int(round(h.crit_chance() * 100.0))], 14))
	side.add_child(Kit.label("HP %d / %d" % [h.hp, h.max_hp()], 14))
	side.add_child(Kit.label("MP %d / %d" % [h.mp, h.max_mp()], 14))
	side.add_child(Kit.label("Potions %d    Pack %d item%s" % [h.potions, h.inventory.size(), "" if h.inventory.size() == 1 else "s"], 14))
	side.add_child(HSeparator.new())
	side.add_child(_wrap(Kit.label("Bought gear goes on at once if that slot is empty; otherwise it waits in the pack. Merchants buy back at a fraction of the price.", 12, Kit.DIM)))


# ---------------------------------------------------------------- rows

func _section(text: String) -> Label:
	return Kit.label(text, 17, Kit.ACCENT)


func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(270, 0)
	return l


## One item: name and kind on the left, effects, a price and buttons on the right.
func _item_row(id: String, price_text: String, buttons: Array, slot_title: String = "", price_color: Color = Kit.ACCENT) -> PanelContainer:
	var def := GameItems.item_def(id)
	var tier := clampi(int(def.get("tier", 1)), 0, TIER_COLORS.size() - 1)
	var title := "%s: %s" % [slot_title, def.get("name", id)] if slot_title != "" else str(def.get("name", id))
	var sub := "Tier %d %s%s  -  %s" % [tier, def.get("slot", ""), ", unique" if def.get("unique", false) else "", def.get("description", "")]
	var effects := _effects_rich(def.get("effects", []))
	return _row(title, Color(TIER_COLORS[tier]), sub, effects, price_text, buttons, "%s\n%s" % [def.get("name", id), def.get("description", "")], price_color)


func _service_row(title: String, sub: String, effect: String, price_text: String, color: Color, tip: String, button: Variant, price_color: Color = Kit.ACCENT) -> PanelContainer:
	var r := _style_rich(RichTextLabel.new())
	r.text = effect
	return _row(title, color, sub, r, price_text, [button] if button != null else [], tip, price_color)


## Prices the heir cannot pay show in red.
func _afford(cost: int) -> Color:
	return Kit.ACCENT if dynasty.heir.gold >= cost else Kit.BAD


func _row(title: String, color: Color, sub: String, middle: Control, price_text: String, buttons: Array, tip: String, price_color: Color = Kit.ACCENT) -> PanelContainer:
	var p := Kit.panel(Kit.PANEL)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	p.add_child(hb)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 0)
	left.custom_minimum_size = Vector2(LEFT_W, 0)
	left.mouse_filter = Control.MOUSE_FILTER_PASS
	left.tooltip_text = tip
	hb.add_child(left)
	var t := Kit.label(title, 16, color)
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.custom_minimum_size = Vector2(LEFT_W, 0)
	left.add_child(t)
	if sub != "":
		var s := Kit.label(sub, 12, Kit.DIM)
		s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		s.custom_minimum_size = Vector2(LEFT_W, 0)
		left.add_child(s)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(middle)
	var pr := Kit.label(price_text, 15, price_color)
	pr.custom_minimum_size = Vector2(84, 0)
	pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(pr)
	for b in buttons:
		(b as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(b)
	return p


## Effects as colored text: gains in green, drawbacks in red.
func _effects_rich(effects: Array) -> RichTextLabel:
	var parts: Array = []
	for e in effects:
		var col := Kit.GOOD if float(e["value"]) >= 0.0 else Kit.BAD
		parts.append("[color=#%s]%s[/color]" % [col.to_html(false), GameItems.effect_text(str(e["stat"]), float(e["value"]))])
	var r := _style_rich(RichTextLabel.new())
	r.text = ", ".join(parts) if not parts.is_empty() else "[color=#8d88a0]no effect[/color]"
	return r


func _style_rich(r: RichTextLabel) -> RichTextLabel:
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(160, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", 14)
	r.add_theme_color_override("default_color", Kit.TEXT)
	return r
