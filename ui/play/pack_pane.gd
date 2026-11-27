## The pack pane (docs/PLAYER_INTERFACE.md, slice 4): what the heir carries as a grid of icons, and, for a bag (`bag` set), what that
## bag holds, in a pane of its own. Drag an item onto a bag square to put it in, drag one out of a bag onto the pane to take it out,
## drag worn gear onto the pack to take it off, double click gear to wear it or a bag to open it; Drop leaves the chosen item behind.
## Rendering only: GameItems, GameBags and GameCarry do everything.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const ItemSlot := preload("res://ui/play/item_slot.gd")

const COLUMNS := 6
const MIN_SLOTS := 24

var dynasty: GameDynasty
var bag := ""                   # "" is the pack itself; a bag's id shows what is in that bag
var on_change := Callable()     # func(): the pack changed; the other panes redraw
var on_open_bag := Callable()   # func(bag_id): open that bag's pane
var on_smoke := Callable()      # func() -> String: break a smoke pot where the heir stands, and say what came of it (the open world's screen)
var on_fish := Callable()       # func() -> String: take the rod to the water (opens the fishing panel when the heir is at a bank), and say what came of it
var _grid: GridContainer
var _head: Label
var _line: Label
var _picked := ""
var _actions: HBoxContainer
var _sig := ""


func _ready() -> void:
	var v := Kit.overlay(self, "Pack" if bag == "" else GameItems.item_name(bag))
	v.add_theme_constant_override("separation", 6)
	_head = Kit.label("", 14)
	v.add_child(_head)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	v.add_child(_grid)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	v.add_child(_actions)
	_line = Kit.label("", 13, Kit.dim())
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_line)
	_build()


func _items() -> Array:
	GameBags.normalize(dynasty.heir)
	return dynasty.heir.inventory.duplicate() if bag == "" else GameBags.contents(dynasty.heir, bag)


func signature() -> String:
	var h := dynasty.heir
	return "%s|%s|%s|%d" % [str(h.inventory), str(h.bags), _picked, int(GameCarry.carried(h) * 10.0)]


func refresh() -> void:
	if bag != "" and GameBags.where(dynasty.heir, bag) == null:
		queue_free()   # the bag is gone (left behind, sold): so is its pane
		return
	if signature() != _sig:
		_build()


func _build() -> void:
	_sig = signature()
	var h := dynasty.heir
	Kit.clear(_grid)
	Kit.clear(_actions)
	var items := _items()
	if _picked != "" and _picked not in items:
		_picked = ""
	var total := MIN_SLOTS if bag == "" else GameBags.slots(bag)
	_head.text = GameCarry.summary(h) if bag == "" else "%d of %d things    %s" % [items.size(), total, GameCarry.summary(h)]
	var squares := maxi(total, items.size())
	if bag == "":
		squares = int(ceil(float(squares) / float(COLUMNS))) * COLUMNS
	for i in squares:
		var sq := ItemSlot.new()
		var id := str(items[i]) if i < items.size() else ""
		sq.tag = "bag" if (id != "" and GameBags.is_bag(id)) else "pack"
		sq.setup(id, 48.0)
		if id != "":
			sq.pressed.connect(func(): _pick(id))
			sq.on_double = func(): _open(id)
			if id == _picked:
				sq.modulate = Color(1.0, 0.95, 0.6)
		if id != "" and GameBags.is_bag(id):   # an item dropped on a bag goes into it
			sq.can_drop = func(data: Dictionary): return str(data["item"]) != id and str(data["from"]) in ["pack", "bag"]
			sq.on_drop = func(data: Dictionary): _say(GameBags.put(dynasty.heir, str(data["item"]), id)["text"])
		_grid.add_child(sq)
	if _picked != "":
		_actions.add_child(Kit.label(GameItems.item_name(_picked), 13, Kit.ACCENT))
		if _picked == GameSmoke.item_id():
			_actions.add_child(Kit.button("Use", func(): _say(_light()), Vector2(70, 32)))
		if _picked == str(GameFishing.setting("rod")):
			_actions.add_child(Kit.button("Use", func(): _say(_fish()), Vector2(70, 32)))
		if GameItems.slot_of(_picked) in GameItems.SLOTS:
			_actions.add_child(Kit.button("Wear", func(): _say(GameItems.equip(dynasty, _picked)), Vector2(70, 32)))
		if bag != "":
			_actions.add_child(Kit.button("Take out", func(): _say(GameBags.take(dynasty.heir, _picked)["text"]), Vector2(90, 32)))
		_actions.add_child(Kit.button("Drop", func(): _say(GameCarry.drop(dynasty, _picked)), Vector2(70, 32)))


func _pick(id: String) -> void:
	_picked = "" if _picked == id else id
	_build()


## A double click: gear is worn, a bag is opened.
func _open(id: String) -> void:
	if GameBags.is_bag(id):
		if on_open_bag.is_valid():
			on_open_bag.call(id)
	elif id == GameSmoke.item_id():
		_say(_light())
	elif id == str(GameFishing.setting("rod")):
		_say(_fish())
	elif GameItems.slot_of(id) in GameItems.SLOTS:
		_say(GameItems.equip(dynasty, id))


## A smoke pot is broken in the open world (the screen's `on_smoke` says what came of it); nowhere else has smoke.
func _light() -> String:
	return str(on_smoke.call()) if on_smoke.is_valid() else GameSmoke.text("indoors")


## A fishing rod is used at the water's edge in the open world (the screen's `on_fish` opens the panel there); nowhere else has water to fish.
func _fish() -> String:
	return str(on_fish.call()) if on_fish.is_valid() else GameFishing.text("indoors")


func _say(text: String) -> void:
	_line.text = text
	if on_change.is_valid():
		on_change.call()
	_build()


# the pane itself takes what is dropped on it: worn gear is taken off, and a thing from a bag comes out into the pack
func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("item"):
		return false
	var item := str(data["item"])
	if bag != "":   # a bag's pane takes anything the heir carries (not worn: take it off first), by putting it in the bag
		return str(data["from"]) not in GameItems.SLOTS and GameBags.where(dynasty.heir, item) != null and GameBags.where(dynasty.heir, item) != bag
	if str(data["from"]) in GameItems.SLOTS:
		return true
	var at: Variant = GameBags.where(dynasty.heir, item)
	return at != null and str(at) != ""


func _drop_data(_at: Vector2, data: Variant) -> void:
	var from := str(data["from"])
	if bag != "":
		_say(GameBags.put(dynasty.heir, str(data["item"]), bag)["text"])
	elif from in GameItems.SLOTS:
		_say(GameItems.unequip(dynasty, from))
	else:
		_say(GameBags.take(dynasty.heir, str(data["item"]))["text"])
