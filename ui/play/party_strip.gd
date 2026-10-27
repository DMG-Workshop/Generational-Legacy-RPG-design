## The party strip of a command round: one chip per member (name, what they will do, HP and MP bars),
## drawn from GameRound.view(). The active member (the one being asked) has the gold outline, a
## queued choice a green one, Auto blue, Held red; a fallen member is greyed out. A tap on a chip is
## reported as chip_pressed(by); the battle view decides what it means. The chip's text is the longest
## wording that fits (full, short, tiny from GameRound.describe), then a smaller font, then a cut
## name: never a clipped button. The whole story (HP, MP, statuses, the action in full) is the tooltip,
## which a long press shows on touch screens.
extends HBoxContainer

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")

signal chip_pressed(by: int)

const FONT := 13
const MIN_FONT := 11   # as small as a chip's text goes before the name is cut

var chips: Dictionary = {}    # by -> {btn, hp, mp, name, lines}


func _init() -> void:
	add_theme_constant_override("separation", 4)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Draws `view` (GameRound.view()); `active` is the member being asked, -2 for none.
func refresh(view: Dictionary, active: int) -> void:
	var members: Array = view["members"]
	if chips.size() != members.size():
		_rebuild(members)
	for m in members:
		var by := int(m["by"])
		var c: Dictionary = chips[by]
		var btn: Button = c["btn"]
		var decision := str(m["decision"])
		_look(btn, decision, by == active)
		btn.disabled = decision == "ko"
		btn.tooltip_text = "%s\n%s" % [m["tip"], _tap_hint(m)]
		c["name"] = str(m["name"])
		c["lines"] = [str(m["chip"]["full"]), str(m["chip"]["short"]), str(m["chip"]["tiny"])]
		var hp: ProgressBar = c["hp"]
		hp.max_value = maxf(1.0, float(m["max_hp"]))
		hp.value = float(m["hp"])
		var mp: ProgressBar = c["mp"]
		mp.max_value = maxf(1.0, float(m["max_mp"]))
		mp.value = float(m["mp"])
		_fit(c)
	_fit_later.call_deferred()


func _rebuild(members: Array) -> void:
	Kit.clear(self)
	chips = {}
	for m in members:
		var by := int(m["by"])
		var btn := Kit.button("", func(): chip_pressed.emit(by), Vector2(float(UiSettings.setting("party_chip_min_w")), float(UiSettings.setting("party_chip_h"))))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.clip_text = true
		btn.add_theme_font_size_override("font_size", FONT)
		btn.add_theme_color_override("font_disabled_color", Kit.DIM)
		btn.add_theme_constant_override("line_spacing", -2)
		add_child(btn)
		var hp := _bar(btn, Kit.GOOD, -9.0, -5.0)
		var mp := _bar(btn, Kit.MP_BLUE, -5.0, -2.0)
		chips[by] = {"btn": btn, "hp": hp, "mp": mp, "name": "", "lines": ["", "", ""]}


## A thin bar along the foot of a chip; it takes no clicks, so the whole chip is the button.
func _bar(chip: Button, color: Color, top: float, bottom: float) -> ProgressBar:
	var pb := Kit.bar(color, 1.0, 0.0, Vector2.ZERO)
	for k in ["background", "fill"]:
		(pb.get_theme_stylebox(k) as StyleBoxFlat).set_content_margin_all(0)
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pb.anchor_left = 0.0
	pb.anchor_right = 1.0
	pb.anchor_top = 1.0
	pb.anchor_bottom = 1.0
	pb.offset_left = 6.0
	pb.offset_right = -6.0
	pb.offset_top = top
	pb.offset_bottom = bottom
	chip.add_child(pb)
	return pb


## Fill and outline by what the member is doing; the active member gets a thicker gold outline.
func _look(btn: Button, decision: String, active: bool) -> void:
	var fill := Kit.PANEL_LIGHT
	var edge := Color("#4a4466")
	match decision:
		"queued":
			fill = Color("#233025")
			edge = Kit.GOOD
		"auto", "fallback":
			fill = Color("#1f2a44")
			edge = Kit.MP_BLUE
		"held":
			fill = Color("#33202a")
			edge = Kit.BAD
		"cover":
			fill = Color("#2e2a20")
			edge = Kit.ACCENT.darkened(0.35)
		"ko":
			fill = Color("#1b1927")
			edge = Color("#2a2740")
	if active:
		edge = Kit.ACCENT
		fill = fill.lightened(0.06)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s := Kit.style(fill.lightened(0.07) if state in ["hover", "pressed"] else fill, 6, edge)
		s.set_border_width_all(3 if active else 2)
		s.content_margin_left = 6
		s.content_margin_right = 6
		s.content_margin_top = 3
		s.content_margin_bottom = 10   # the bars sit in the bottom ten pixels
		btn.add_theme_stylebox_override(state, s)


## What a tap on the chip does, for the tooltip.
func _tap_hint(m: Dictionary) -> String:
	var tap := Kit.click().capitalize()
	match str(m["decision"]):
		"ko":
			return "Down for this fight."
		"held":
			return "Cannot act this round."
		"auto", "fallback":
			return "%s to take over from Auto." % tap
		"empty":
			return "%s to choose for %s." % [tap, m["name"]]
	return "%s to change." % tap


## The chip's two lines at the width it has now: name over action. The font steps down from FONT to
## MIN_FONT; the action takes its shorter wordings first, and only then is the name cut.
func _fit(c: Dictionary) -> void:
	var btn: Button = c["btn"]
	var inner := btn.size.x - btn.get_theme_stylebox("normal").get_minimum_size().x - 2.0
	var who: String = c["name"]
	var lines: Array = c["lines"]
	if inner <= 4.0:
		btn.text = "%s\n%s" % [who, lines[0]]
		return
	var font := btn.get_theme_font("font")
	for fs in range(FONT, MIN_FONT - 1, -1):
		if font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > inner:
			continue
		for line in lines:
			if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= inner:
				btn.add_theme_font_size_override("font_size", fs)
				btn.text = "%s\n%s" % [who, line]
				return
	btn.add_theme_font_size_override("font_size", MIN_FONT)
	btn.text = "%s\n%s" % [_cut(font, who, inner), _cut(font, lines[2], inner)]


## `text` as it fits `width` at the smallest font: a first name alone, else its start and a full stop.
func _cut(font: Font, text: String, width: float) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, MIN_FONT).x <= width:
		return text
	var first := text.get_slice(" ", 0)
	if first != text and font.get_string_size(first, HORIZONTAL_ALIGNMENT_LEFT, -1, MIN_FONT).x <= width:
		return first
	var n := text.length()
	while n > 1 and font.get_string_size(text.substr(0, n) + ".", HORIZONTAL_ALIGNMENT_LEFT, -1, MIN_FONT).x > width:
		n -= 1
	return text.substr(0, n) + "."


## Once the chips have their widths (a layout pass after a change), the texts are fitted again.
func _fit_later() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	for by in chips:
		_fit(chips[by])


## The bars follow the blows while a round plays.
func set_hp(by: int, value: float) -> void:
	if chips.has(by):
		var bar: ProgressBar = chips[by]["hp"]
		bar.value = clampf(value, 0.0, bar.max_value)


## The member whose move is playing is lit; -2 dims the whole strip for the foes' turn; -3 clears it.
func mark_acting(by: int) -> void:
	for k in chips:
		var btn: Button = chips[k]["btn"]
		btn.modulate = Color.WHITE if by == -3 else (Color(1.45, 1.45, 1.2) if k == by else Color(0.72, 0.72, 0.72))


func buttons() -> Array:
	return chips.values().map(func(c): return c["btn"])
