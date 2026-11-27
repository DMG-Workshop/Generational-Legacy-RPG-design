## Shown when an heir dies, before the succession screen: who died and how, what killed them, what the life came to, what the heir
## leaves the family and what carries over, and one button that carries on into the succession (GameDeath works the words out; this
## only draws them). Nothing here changes the dynasty: the rules of death and succession are the game's own and have already run.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const SkinScreen := preload("res://ui/play/skin_screen.gd")

var app: Node
var d: GameDynasty
var summary: Dictionary = {}
var carry_button: Button
var on_carry: Callable   # what the button does (the app's: go on to the succession or the ending)


func _ready() -> void:
	d = app.dynasty
	summary = GameDeath.summary(d)
	SkinScreen.apply(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	var head := Kit.label(str(summary["title"]), 34, Kit.ACCENT)
	head.name = "Title"
	root.add_child(SkinScreen.ribbon(_wrapped(head), 30))
	root.add_child(_wrapped(Kit.label(str(summary["who"]), 16, Kit.dim())))
	root.add_child(_wrapped(Kit.label(str(summary["how"]), 18)))
	var killer := _wrapped(Kit.label(str(summary["killer"]), 18, Kit.bad()))
	killer.name = "Killer"
	root.add_child(killer)
	# The sections scroll when a short screen or a big text size cannot show them whole; the button stays below.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	for sec in summary["sections"]:
		var p := Kit.panel()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(p)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		p.add_child(v)
		v.add_child(_wrapped(Kit.label(str(sec["head"]), 18, Kit.ACCENT)))
		for line in sec["lines"]:
			v.add_child(_wrapped(Kit.label(str(line), 15)))
	if bool(summary["ends"]):
		body.add_child(_wrapped(Kit.label(GameDeath.text("ended"), 16, Kit.bad())))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	root.add_child(foot)
	carry_button = Kit.button(str(summary["carry_on"]), _carry, Vector2(0, 46))
	carry_button.name = "CarryOn"
	carry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carry_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	carry_button.clip_text = true
	foot.add_child(carry_button)


func _carry() -> void:
	if on_carry.is_valid():
		on_carry.call()


func _wrapped(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
