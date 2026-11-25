## The interface skin (ui/play/ui_skin.gd) on the frame around the battle: the command panel, the log, the lists, the result and the
## bars on the figures' plates. The look is the same pieces as the panes over the open world (parchment, a crimson ribbon, gold-studded
## buttons, segmented bars, inset slots); a touch screen or a compact window keeps the older dark look, as everywhere else. Nothing
## here changes a rule, a die or an event: it only dresses what the battle screen builds. Rendering only.
extends RefCounted

const UiSkin := preload("res://ui/play/ui_skin.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const Kit := preload("res://ui/play/ui_kit.gd")
const PartyStrip := preload("res://ui/play/party_strip.gd")

const FACE_META := "battle_face"
const BUTTONS_META := "battle_buttons"   # a row (the top bar) whose kit buttons are dressed though it is not a parchment panel


## Whether the battle screen `host` is drawn in the skin: a window that is wide and has a mouse.
static func on(host: Control) -> bool:
	return host != null and not UiSettings.compact(host) and not UiSettings.touch()


## Makes `p` a parchment panel of the skin, and what is put in it is dressed (see `watch`).
static func parchment(p: PanelContainer) -> void:
	p.add_theme_stylebox_override("panel", UiSkin.panel_box())
	p.set_meta(FACE_META, true)
	p.set_meta("skin_face", true)


## The wooden frame round the arena.
static func frame(p: PanelContainer) -> void:
	p.add_theme_stylebox_override("panel", UiSkin.frame_box())


## `l` in a crimson ribbon (a panel's title), the label's words in the gold of a ribbon. Returns the ribbon, to be added where the
## label would have been.
static func ribbon(l: Label, size: int = 14, outline: int = 2) -> PanelContainer:
	var r := PanelContainer.new()
	r.add_theme_stylebox_override("panel", UiSkin.ribbon_box())
	r.size_flags_horizontal = l.size_flags_horizontal
	r.set_meta("skin_face", true)
	UiSkin.dress_title(l)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", outline)
	r.add_child(l)
	return r


## A bar on a plate: slim, segmented, red for health and blue for mana (the picture of the full bar does not fit a plate; the numbers
## are written beside it).
static func thin_bar(pb: ProgressBar, kind: String) -> void:
	UiSkin.dress_thin_bar(pb, kind)


## The panel (one of ours) that `n` is in, or null.
static func face_of(n: Node) -> Control:
	var p := n.get_parent()
	while p != null:
		if p is Control and p.has_meta(FACE_META):
			return p
		p = p.get_parent()
	return null


## Dresses what is added under `host` from now on: a kit button in the top bar or on a parchment panel (not a menu opened over the screen) becomes a gold-studded button (but not a chip of the party
## strip, which has its own looks), and the labels and the rows of a parchment panel read on parchment. Stops when `host` leaves.
static func watch(host: Control) -> void:
	var tree := host.get_tree()
	if tree == null:
		return
	var cb := func(n: Node):
		if host.is_ancestor_of(n):
			dress(n)
	tree.node_added.connect(cb)
	host.tree_exiting.connect(func():
		if tree.node_added.is_connected(cb):
			tree.node_added.disconnect(cb))


static func dress(n: Node) -> void:
	if not (n is Control) or n.has_meta("skin_done"):
		return
	if n is Button:
		if n.has_meta("tap_base") and not n.has_meta("skin_keep") and not _in_strip(n) and (face_of(n) != null or _under_meta(n, BUTTONS_META)):
			UiSkin.dress_button(n, "parch")
		return
	var face := face_of(n)
	if face == null:
		return
	if n is PanelContainer and n.has_theme_stylebox_override("panel") and not n.has_meta("skin_face"):
		var sb: StyleBox = n.get_theme_stylebox("panel")
		if sb is StyleBoxFlat and (sb as StyleBoxFlat).bg_color.a > 0.3 and UiSkin.luminance((sb as StyleBoxFlat).bg_color) < 0.2:
			n.add_theme_stylebox_override("panel", UiSkin.inset_box(false))   # a row of a list is a slot: its light words stay
			n.set_meta("skin_done", true)
			return
	UiSkin.dress(n, face, "parch")


static func _under_meta(n: Node, key: String) -> bool:
	var p := n.get_parent()
	while p != null:
		if p.has_meta(key):
			return true
		p = p.get_parent()
	return false


static func _in_strip(n: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if p is PartyStrip:
			return true
		p = p.get_parent()
	return false


## A log line as BBCode that reads on parchment: its colours put on the face (`Kit.ink`), and the newest line gold-lit.
static func log_bb(text: String, newest: bool) -> String:
	var re := RegEx.new()
	re.compile("\\[color=#([0-9a-fA-F]{6})\\]")
	var out := ""
	var at := 0
	for m in re.search_all(text):
		out += text.substr(at, m.get_start() - at) + "[color=#%s]" % Kit.ink(Color("#" + m.get_string(1))).to_html(false)
		at = m.get_end()
	out += text.substr(at)
	if newest:
		return "[bgcolor=#%s][color=#%s] %s [/color][/bgcolor]" % [UiSkin.pal("gold").to_html(false), UiSkin.pal("ink").to_html(false), out]
	return out
