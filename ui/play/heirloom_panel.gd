## The house's heirlooms and the reworking of them (see GameHeirlooms): each row says what the heirloom is, who has
## worked it, and what the next level costs; the button has it reworked. A row that cannot be reworked says why.
## Nothing here computes a result.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const PanelSkin := preload("res://ui/play/panel_skin.gd")
const WIDE := 760.0

var dynasty: GameDynasty
var on_change: Callable
var _body: VBoxContainer


func _ready() -> void:
	var v := Kit.overlay(self, "Heirlooms of House %s" % dynasty.dynasty_name)
	set_meta("modal", true)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_body)
	_build()


func _build() -> void:
	Kit.clear(_body)
	var note := Kit.label("Gold: %s. All heirlooms together: +%d%% power for every heir. Each heir may have each heirloom reworked once, at a forge, so an heirloom grows finer over the generations." % [GameText.num(dynasty.heir.gold), int(round(dynasty.heirloom_bonus() * 100.0))], 15, Kit.dim())
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(note)
	for i in dynasty.heirlooms.size():
		var h := GameHeirlooms.describe(dynasty, i)
		if h.is_empty():
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var head := PanelSkin.label(self, str(h["line"]), 16, Kit.ACCENT)
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(head)
		if PanelSkin.on(self):   # how far it has been reworked, as a segmented bar
			var pb := PanelSkin.progress(self, float(int(h["level"])), float(GameHeirlooms.max_level()), "level")
			pb.custom_minimum_size.x = 160.0
			pb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			text.add_child(pb)
		if str(h["effect"]) != "":
			var fx := PanelSkin.label(self, str(h["effect"]), 14, Kit.good())
			fx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text.add_child(fx)
		var under := str(h["worked"])
		if str(h["why_not"]) != "":
			under += ("  " if under != "" else "") + str(h["why_not"])
		if under != "":
			var line := PanelSkin.label(self, under, 14, Kit.dim())
			if str(h["why_not"]) != "":
				line.name = "Reason"
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text.add_child(line)
		var label := "Rework (%s gold)" % GameText.num(int(h["cost"])) if int(h["cost"]) >= 0 else "Finished"
		var b := Kit.button(label, func(): _rework(i), Vector2(200, 0))
		b.disabled = str(h["why_not"]) != ""
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if PanelSkin.on(self) and int(h["cost"]) >= 0:   # a coin and the price, so the cost reads at a glance
			var buy := VBoxContainer.new()
			buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			buy.add_child(PanelSkin.cost(self, int(h["cost"]), dynasty.heir.gold >= int(h["cost"]), 16))
			buy.add_child(b)
			row.add_child(buy)
		else:
			row.add_child(b)
		_put(row)
	_body.add_child(Kit.button("Close", func(): queue_free(), Vector2(0, 48)))


## Where a row goes: an inset slot when skinned, the body as it was otherwise. The row is added to the slot, which holds it.
func _put(row: Control) -> void:
	if PanelSkin.on(self):
		var slot := PanelSkin.row(self)
		slot.add_child(row)
		_body.add_child(slot)
	else:
		_body.add_child(row)


func _rework(index: int) -> void:
	if not GameHeirlooms.upgrade(dynasty, index)["ok"]:
		return
	if on_change.is_valid():
		on_change.call()
	_build()
