## Looks: the shirt colour of the heir and of each companion. Pick who, then a colour; "Random" gives back
## the colour picked for them. The figure is drawn as it is in battle. GameDynasty.set_shirt keeps the choice;
## only the look changes and nothing is rolled.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const SpriteArt := preload("res://ui/play/sprite_art.gd")
const WIDE := 760.0
const SWATCH := Vector2(104, 40)

var dynasty: GameDynasty
var on_change: Callable
var who := -1   # whose shirt is being chosen: -1 the heir, else their place in the party
var _body: VBoxContainer


func _ready() -> void:
	var v := Kit.overlay(self, "Looks")
	set_meta("modal", true)
	var column := minf(WIDE, Kit.overlay_room(self) - 16.0)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_body = VBoxContainer.new()
	_body.custom_minimum_size = Vector2(column, 0)
	_body.add_theme_constant_override("separation", 12)
	center.add_child(_body)
	_build()


## The heir (by -1) or the companion at `by` in the party, as the battle draws them.
func unit(by: int) -> GameHeir:
	if by < 0 or by >= dynasty.party.members.size():
		return dynasty.heir
	return dynasty.party.unit(dynasty, dynasty.party.members[by])


## Draws the panel afresh, so a choice shows at once.
func _build() -> void:
	Kit.clear(_body)
	if who >= dynasty.party.members.size():
		who = -1
	var people := HFlowContainer.new()
	people.add_theme_constant_override("h_separation", 8)
	people.add_theme_constant_override("v_separation", 8)
	_body.add_child(people)
	for by in range(-1, dynasty.party.members.size()):
		var person := unit(by)
		var at := by
		var b := Kit.button(person.name, func(): who = at; _build(), Vector2(160, 40))
		b.clip_text = true
		if by == who:
			b.add_theme_stylebox_override("normal", Kit.style(Kit.PANEL_LIGHT, 6, Kit.ACCENT))
		people.add_child(b)

	var u := unit(who)
	var shirt: Dictionary = SpriteArt.shirts()[SpriteArt.shirt_index(u)] if not SpriteArt.shirts().is_empty() else {}
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_body.add_child(row)
	var tex := SpriteArt.figure(u)
	if tex != null:
		var fig := TextureRect.new()
		fig.texture = tex
		fig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fig.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fig.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		fig.custom_minimum_size = Vector2(SpriteArt.FIGURE) * 4.0
		row.add_child(fig)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	info.add_child(Kit.label(u.name, 20, Kit.TEXT))
	var picked := dynasty.shirt_of(who) == "" or str(shirt.get("id", "")) != dynasty.shirt_of(who)
	var line := Kit.label("Shirt: %s%s" % [shirt.get("name", "-"), ", picked at random" if picked else ""], 15, Kit.dim())
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(line)

	var swatches := HFlowContainer.new()
	swatches.add_theme_constant_override("h_separation", 8)
	swatches.add_theme_constant_override("v_separation", 8)
	_body.add_child(swatches)
	for s in SpriteArt.shirts():
		swatches.add_child(_swatch(s, str(s["id"]) == str(shirt.get("id", ""))))

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	_body.add_child(bottom)
	var rnd := Kit.button("Random", func(): _pick(""), Vector2(160, 44))
	rnd.disabled = picked
	bottom.add_child(rnd)
	bottom.add_child(Kit.button("Close", func(): queue_free(), Vector2(160, 44)))


## A shirt to choose: a button in its own colour with its name, the worn one ringed in gold.
func _swatch(s: Dictionary, worn: bool) -> Button:
	var id := str(s["id"])
	var c := Color.html(str(s["color"]))
	var b := Kit.button(str(s["name"]), func(): _pick(id), SWATCH)
	b.add_theme_font_size_override("font_size", 14)
	var ring := Kit.ACCENT if worn else c.darkened(0.4)
	b.add_theme_stylebox_override("normal", Kit.style(c, 6, ring))
	b.add_theme_stylebox_override("hover", Kit.style(c.lightened(0.12), 6, Kit.ACCENT))
	b.add_theme_stylebox_override("pressed", Kit.style(c.darkened(0.12), 6, Kit.ACCENT))
	var ink := Kit.BG if c.get_luminance() > 0.45 else Kit.TEXT
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, ink)
	b.set_meta("shirt", id)
	return b


func _pick(id: String) -> void:
	dynasty.set_shirt(who, id)
	if on_change.is_valid():
		on_change.call()
	_build()
