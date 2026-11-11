## The house's heirlooms and the reworking of them (see GameHeirlooms): each row says what the heirloom is, who has
## worked it, and what the next level costs; the button has it reworked. A row that cannot be reworked says why.
## Nothing here computes a result.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
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
		_body.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var head := Kit.label(str(h["line"]), 16, Kit.ACCENT)
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(head)
		var under := str(h["worked"])
		if str(h["why_not"]) != "":
			under += ("  " if under != "" else "") + str(h["why_not"])
		if under != "":
			var line := Kit.label(under, 14, Kit.dim())
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text.add_child(line)
		var label := "Rework (%s gold)" % GameText.num(int(h["cost"])) if int(h["cost"]) >= 0 else "Finished"
		var b := Kit.button(label, func(): _rework(i), Vector2(200, 0))
		b.disabled = str(h["why_not"]) != ""
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
	_body.add_child(Kit.button("Close", func(): queue_free(), Vector2(0, 48)))


func _rework(index: int) -> void:
	if not GameHeirlooms.upgrade(dynasty, index)["ok"]:
		return
	if on_change.is_valid():
		on_change.call()
	_build()
