## The first-heir tutorial's tip strip: one short tip about what to do next with a way to switch the
## tips off, and the marking of the buttons the tip points at. Which tip to show is
## core/game/game_tutorial.gd's question; the text is in data/ui/tutorial.json. The strip is a single
## row so it takes as little height as it can: a phone at large text has none to spare.
extends RefCounted

const Kit := preload("res://ui/play/ui_kit.gd")

const HIGHLIGHT := Color("#3d3860")
const SKIP_W := 96.0


## The strip for `tip` (from GameTutorial.current), its text wrapped to fit `width` UI units. Pressing
## Skip tips calls `on_skip`.
static func make(tip: Dictionary, width: float, on_skip: Callable) -> Control:
	var p := PanelContainer.new()
	p.name = "TutorialTip"
	p.add_theme_stylebox_override("panel", Kit.style(Color("#241f3a"), 8, Kit.ACCENT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)
	var body := Kit.label(str(tip["text"]), 14)
	body.name = "TipText"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.custom_minimum_size.x = maxf(120.0, width - 20.0 - 8.0 - SKIP_W - 12.0)
	row.add_child(body)
	var skip := Kit.button("Skip tips", on_skip, Vector2(SKIP_W, 28))
	skip.name = "SkipTips"
	skip.add_theme_font_size_override("font_size", 13)
	skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(skip)
	return p


## Marks the buttons a tip points at: those whose text starts with one of its `highlight` words.
static func mark(buttons: Array, tip: Dictionary) -> void:
	for b in buttons:
		if not (b is Button):
			continue
		for word in tip.get("highlight", []):
			if (b as Button).text.begins_with(str(word)):
				b.add_theme_stylebox_override("normal", Kit.style(HIGHLIGHT, 6, Kit.ACCENT))
				b.add_theme_color_override("font_color", Kit.ACCENT)
				b.set_meta("tutorial_mark", true)
				break
