## A waygate's panel (see GameGates; docs/GATES.md), opened by Use at an arch in the open world: the world waits while it is open. The arch's rune
## slots are drawn as a row with their state; below it what the heir can do at the stones: cut a rune again (cost and reason as text under the key),
## copy a rune that can still be read, buy silver from the road smith, post a companion as guard, and, when the arch works, the list of gates it
## leads to with a Step through key. Nothing here computes a result: GameGates does the repair and the rules, GameSandbox.step_through the trip.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const PanelSkin := preload("res://ui/play/panel_skin.gd")
const WIDE := 760.0
const ICON := 4   # a rune's picture is drawn at 4 pixels to one: a whole multiple

var dynasty: GameDynasty
var sandbox: GameSandbox = null        # where the heir stands (the repair needs them at the stones; the trip is the sandbox's)
var gate := ""                         # the gate's id
var on_change: Callable
var _body: VBoxContainer
var _line := ""                        # what the last action told
var _choice := ""                      # the destination picked
var _column := WIDE


func _ready() -> void:
	var v := Kit.overlay(self, GameGates.name_of(gate))
	set_meta("modal", true)
	_column = minf(WIDE, Kit.overlay_room(self) - 16.0)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.custom_minimum_size = Vector2(_column, 0)
	_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_body)
	GameGates.tend(dynasty)
	_build()


func _at() -> Vector2i:
	return sandbox.heir if sandbox != null else Vector2i(-1, -1)


func _wrapped(text: String, size: int, color: Color) -> Label:
	var l := PanelSkin.label(self, text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## Draws everything afresh, so a repair or a purchase shows at once.
func _build() -> void:
	Kit.clear(_body)
	var st := GameGates.state(dynasty, gate)
	var mode := str(st["mode"])
	var intro := GameGates.text("panel_intro", {"about": str(GameGates.def(gate).get("about", "")), "heir": dynasty.heir.name})
	_body.add_child(_wrapped(intro, 15, Kit.dim()))
	var nets: Array = (GameGates.def(gate)["networks"] as Array).map(func(n): return GameGates.network_name(str(n)))
	var state_color := Kit.good() if mode == "lit" else (Kit.ACCENT if mode == "flickering" else Kit.bad())
	var head := _wrapped("%s. %s. Road: %s." % [GameGates.mode_name(mode), GameGates.place_name(dynasty, gate), ", ".join(PackedStringArray(nets))], 17, state_color)
	head.name = "State"
	_body.add_child(head)
	if _line != "":
		var said := _wrapped(_line, 15, Kit.ACCENT)
		said.name = "Said"
		_body.add_child(said)
	_body.add_child(_slots(st))
	for i in (st["slots"] as Array).size():
		var row := _slot_row(i, st["slots"][i])
		if row != null:
			_body.add_child(row)
	if bool(GameGates.def(gate).get("trader", false)):
		_body.add_child(_trader())
	_body.add_child(_guard_row())
	if mode != "dark" or not GameGates.destinations(dynasty, gate).is_empty():
		_body.add_child(_travel())
	var close := PanelSkin.button(self, "Close", func(): queue_free(), Vector2(_column, 48))
	close.name = "Close"
	_body.add_child(close)


## The row of the arch's slots: the rune's picture in its state, the rune's name and the state under it.
func _slots(st: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "Slots"
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var lit := bool(st["lit"])
	for s in st["slots"]:
		var cell := VBoxContainer.new()
		cell.name = "Slot"
		cell.add_theme_constant_override("separation", 2)
		var pic := TextureRect.new()
		pic.texture = GateArt.rune_texture(str(s["rune"]), str(s["state"]), lit)
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		pic.custom_minimum_size = Vector2(7 * ICON, 9 * ICON)
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(pic)
		var nm := PanelSkin.label(self, GameGates.rune_name(str(s["rune"])), 13, Kit.TEXT)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(nm)
		var col := Kit.good() if str(s["state"]) == "whole" else (Kit.ACCENT if str(s["state"]) == "worn" else Kit.bad())
		var sl := PanelSkin.label(self, GameGates.text("slot_" + str(s["state"])), 12, col)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(sl)
		row.add_child(cell)
	return row


## What can be done at one slot, or null for a whole slot of a rune known.
func _slot_row(i: int, s: Dictionary) -> Control:
	var rune := str(s["rune"])
	var state := str(s["state"])
	var legible := state in ["whole", "worn"]
	var can_copy := legible and not GameGates.knows(dynasty, rune)
	if state == "whole" and not can_copy:
		return null
	var box := VBoxContainer.new()
	box.name = "Repair"
	box.add_theme_constant_override("separation", 4)
	if state != "whole":
		var plan := GameGates.inscribe_plan(dynasty, gate, i, _at())
		box.add_child(_wrapped("%s rune, %s: %d silver and %s gold to cut it again." % [GameGates.rune_name(rune), GameGates.text("slot_" + state), int(plan["silver"]), GameText.num(int(plan["gold"]))], 15, Kit.TEXT))
		var b := PanelSkin.button(self, "Inscribe the %s rune" % GameGates.rune_name(rune).to_lower(), func(): _inscribe(i), Vector2(_column, 48))
		b.name = "Inscribe%d" % i
		b.disabled = not bool(plan["ok"])
		box.add_child(b)
		if str(plan["why"]) != "":   # the reason is text, not a tooltip: a touch player sees it
			var why := PanelSkin.label(self, str(plan["why"]), 14, Kit.dim())
			why.name = "Reason"
			why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(why)
	if can_copy:
		var c := PanelSkin.button(self, "Copy the %s rune (free)" % GameGates.rune_name(rune).to_lower(), func(): _copy(i), Vector2(_column, 48))
		c.name = "Copy%d" % i
		box.add_child(c)
	var slot := PanelSkin.row(self)
	slot.add_child(box)
	return slot


func _trader() -> Control:
	var box := VBoxContainer.new()
	box.name = "Smith"
	var price := GameGates.silver_price(dynasty)
	box.add_child(_wrapped("A road smith keeps a stall here: silver for %s gold a piece. The family holds %d." % [GameText.num(price), GameCraft.have(dynasty, str(GameGates.setting("silver")))], 15, Kit.TEXT))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	for n in [1, 5]:
		var b := PanelSkin.button(self, "Buy %d" % n, func(): _buy(n), Vector2(120, 48))
		b.name = "BuySilver%d" % n
		b.disabled = GameGates.buy_silver_why(dynasty, gate, n, _at()) != ""
		line.add_child(b)
	box.add_child(line)
	var slot := PanelSkin.row(self)
	slot.add_child(box)
	return slot


func _guard_row() -> Control:
	var box := VBoxContainer.new()
	box.name = "Guard"
	box.add_theme_constant_override("separation", 4)
	var who := GameGates.guard_of(dynasty, gate)
	if who != "":
		box.add_child(_wrapped(GameGates.text("guard_is", {"name": dynasty.party.display_name(who)}) + " No thief will strip the silver while they serve.", 15, Kit.good()))
		var b := PanelSkin.button(self, "Relieve the guard", func(): _relieve(), Vector2(_column, 48))
		b.name = "Relieve"
		box.add_child(b)
	else:
		box.add_child(_wrapped("Thieves strip the silver from gates that are not watched. A companion posted here keeps them off while they serve.", 14, Kit.dim()))
		if dynasty.party.members.is_empty():
			var none := PanelSkin.label(self, "No companion travels with the family.", 14, Kit.dim())
			none.name = "Reason"
			box.add_child(none)
		for m in dynasty.party.members:
			var id := str(m["id"])
			var b2 := PanelSkin.button(self, "Post %s here as guard" % str(m["name"]), func(): _post(id), Vector2(_column, 48))
			b2.name = "Post_" + id
			box.add_child(b2)
	var slot := PanelSkin.row(self)
	slot.add_child(box)
	return slot


## The destinations and the Step through key.
func _travel() -> Control:
	var box := VBoxContainer.new()
	box.name = "Travel"
	box.add_theme_constant_override("separation", 6)
	var list := GameGates.destinations(dynasty, gate)
	var mode := str(GameGates.state(dynasty, gate)["mode"])
	if list.is_empty():
		box.add_child(_wrapped("No other gate of its road is awake.", 14, Kit.dim()))
	else:
		box.add_child(_wrapped("Where the arch leads:", 16, Kit.TEXT))
	if _choice != "" and not list.any(func(e): return str(e["id"]) == _choice):
		_choice = ""
	for e in list:
		var id := str(e["id"])
		var label := "%s, %s" % [str(e["name"]), str(e["place"])] if str(e["kind"]) == "gate" else "%s (%s)" % [str(e["name"]), str(e["place"])]
		if int(e["distance"]) > 0:
			label += ", %d tiles" % int(e["distance"])
		var b := PanelSkin.button(self, label, func(): _pick(id), Vector2(_column, 48))
		b.name = "Dest_" + id.replace(":", "_")
		b.toggle_mode = true
		b.button_pressed = id == _choice
		box.add_child(b)
	var why := _step_why()
	var go := PanelSkin.button(self, "Step through", func(): _step(), Vector2(_column, 48))
	go.name = "StepThrough"
	go.disabled = why != ""
	box.add_child(go)
	if why != "":
		var r := PanelSkin.label(self, why, 14, Kit.dim())
		r.name = "StepReason"
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(r)
	elif mode == "flickering":
		var ch := GameGates.charge_for(dynasty, gate, gate if _choice.begins_with("realm:") else _choice)
		var what := "a charge is spent: 1 silver" if ch.has("material") else "a charge is spent: an essence"
		box.add_child(_wrapped("The arch is flickering: " + what + ".", 14, Kit.dim()))
	var slot := PanelSkin.row(self)
	slot.add_child(box)
	return slot


func _step_why() -> String:
	if _choice == "":
		return "Pick where to go." if not GameGates.destinations(dynasty, gate).is_empty() else GameGates.text("refuse_dark") if str(GameGates.state(dynasty, gate)["mode"]) == "dark" else ""
	if sandbox == null:
		return GameGates.text("refuse_inside")
	var block := sandbox.gate_block()
	if block != "":
		return block
	var plan := GameGates.travel_plan(dynasty, gate, _choice)
	return "" if bool(plan["ok"]) else str(plan["why"])


func _changed() -> void:
	if on_change.is_valid():
		on_change.call()
	_build()


func _inscribe(slot: int) -> void:
	_line = str(GameGates.inscribe(dynasty, gate, slot, _at())["text"])
	_changed()


func _copy(slot: int) -> void:
	_line = str(GameGates.copy_rune(dynasty, gate, slot, _at())["text"])
	_changed()


func _buy(n: int) -> void:
	_line = str(GameGates.buy_silver(dynasty, gate, n, _at())["text"])
	_changed()


func _post(member: String) -> void:
	_line = str(GameGates.assign_guard(dynasty, gate, member, _at())["text"])
	_changed()


func _relieve() -> void:
	_line = str(GameGates.release_guard(dynasty, gate)["text"])
	_changed()


func _pick(id: String) -> void:
	_choice = id
	_build()


## Steps through: the trip is the sandbox's; the panel closes once the heir is through.
func _step() -> void:
	if sandbox == null or _choice == "":
		return
	var r := sandbox.step_through(gate, _choice)
	_line = str(r["text"])
	if bool(r["ok"]):
		if on_change.is_valid():
			on_change.call()
		queue_free()
		return
	_build()
