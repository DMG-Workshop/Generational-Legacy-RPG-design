## A wilds trader's panel (GameWildsTrade), opened over the open world by Use beside a landmark that trades: the world waits while it is open.
## Three sections in a scroll: what is for sale (Buy), what the trader will take from the pack and the stores (Sell), and barter (materials for an item or
## for gold). It only calls GameWildsTrade and draws the rows; every refusal is shown as text and a button that cannot work is disabled with the reason.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")

var dynasty: GameDynasty
var landmark: Dictionary = {}
var on_change: Callable   # call after anything that changes the dynasty; the screen refreshes
var body: VBoxContainer
var rows: VBoxContainer
var note: Label
var gold_label: Label


func _ready() -> void:
	body = Kit.overlay(self, "%s - %s" % [GameWildsSites.name_of(landmark) if not landmark.is_empty() else "Trader", GameWilds.text("in_wilds")])
	gold_label = Kit.label("", 15, Kit.ACCENT)
	body.add_child(gold_label)
	note = Kit.label("", 14, Kit.good())
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)
	_rebuild()


## Does something to the dynasty, shows the line it gave and redraws.
func _act(msg: String) -> void:
	dynasty._say(msg)
	note.text = msg
	if on_change.is_valid():
		on_change.call()
	if is_inside_tree():
		_rebuild()


func _rebuild() -> void:
	var h := dynasty.heir
	gold_label.text = "Gold %s    Pack %.1f / %.1f" % [GameText.num(h.gold), GameCarry.carried(h), GameCarry.capacity(h)]
	for c in rows.get_children():
		rows.remove_child(c)
		c.queue_free()
	if not GameWildsTrade.is_trader(landmark):
		rows.add_child(Kit.label(GameWilds.text("no_trader"), 15, Kit.dim()))
		return
	_buy_section()
	_sell_section()
	_barter_section()


func _section(text: String) -> void:
	rows.add_child(Kit.label(text, 18, Kit.ACCENT))


func _row(title: String, sub: String, price: String, button: Button) -> void:
	var p := Kit.panel()
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	p.add_child(hb)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(left)
	var t := Kit.label(title, 16, Kit.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(t)
	if sub != "":
		var s := Kit.label(sub, 13, Kit.dim())
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left.add_child(s)
	if price != "":
		hb.add_child(Kit.label(price, 15, Kit.ACCENT))
	hb.add_child(button)
	rows.add_child(p)


func _buy_section() -> void:
	var h := dynasty.heir
	_section("For sale")
	var wares := GameWildsTrade.wares(dynasty, landmark)
	if wares.is_empty():
		rows.add_child(Kit.label(GameWilds.text("sold_out", {"heir": h.name}), 15, Kit.dim()))
	for w in wares:
		var key := str(w["key"])
		var id := str(w["id"])
		var cost := int(w["price"])
		var owned := GameItems.stack_max(id) <= 0 and GameItems.owns(h, id)
		var b := Kit.button("Owned" if owned else "Buy", func(): _act(GameWildsTrade.buy(dynasty, landmark, key)), Vector2(96, 34))
		b.name = "MerchantBuy"
		b.disabled = owned or h.gold < cost
		if not owned and h.gold < cost:
			b.tooltip_text = "You need %s more gold." % GameText.num(cost - h.gold)
		elif not owned and not GameCarry.can_carry(h, id):
			b.tooltip_text = "Too heavy to carry as things stand."
		var def := GameItems.item_def(id)
		_row(GameItems.item_name(id), str(def.get("description", "")), "%sg" % GameText.num(cost), b)


func _sell_section() -> void:
	_section("Sell")
	var items := GameWildsTrade.sellable(dynasty, landmark)
	var mats := GameWildsTrade.sellable_materials(dynasty, landmark)
	if items.is_empty() and mats.is_empty():
		rows.add_child(Kit.label("%s carries nothing %s wants." % [dynasty.heir.name, GameWildsSites.name_of(landmark)], 15, Kit.dim()))
	for s in items:
		var id := str(s["id"])
		var b := Kit.button("Sell", func(): _act(GameWildsTrade.sell(dynasty, landmark, id)), Vector2(96, 34))
		b.name = "MerchantSell"
		_row(GameItems.item_name(id) + (" x%d" % int(s["n"]) if int(s["n"]) > 1 else ""), "From the pack.", "%sg" % GameText.num(int(s["price"])), b)
	for m in mats:
		var mid := str(m["id"])
		var mb := Kit.button("Sell all", func(): _act(GameWildsTrade.sell_material(dynasty, landmark, mid, 9999)), Vector2(96, 34))
		mb.name = "MerchantSellMaterial"
		_row("%s x%d" % [GameMaterials.name_of(mid), int(m["have"])], "From the family's stores.", "%sg each" % GameText.num(int(m["price"])), mb)


func _barter_section() -> void:
	var rows_b := GameWildsTrade.barters(dynasty, landmark)
	if rows_b.is_empty():
		return
	_section("Barter")
	for b in rows_b:
		var idx := int(b["index"])
		var bb := Kit.button("Trade", func(): _act(GameWildsTrade.barter(dynasty, landmark, idx)), Vector2(96, 34))
		bb.name = "MerchantBarter"
		bb.disabled = not bool(b["ok"])
		if not bool(b["ok"]):
			bb.tooltip_text = "The stores do not hold %s." % str(b["give_text"])
		_row("%s for %s" % [str(b["give_text"]), str(b["get_text"])], "Materials from the family's stores.", "", bb)
