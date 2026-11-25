## Dresses a full-screen text screen in the interface skin (docs/ART_DIRECTION.md; UiSkin.screens): the title, the life screen, the
## succession and ending screens, and the menu and controls panels. A screen calls `apply(self)` first thing in `_ready`; from then on
## everything added under it is dressed as it is added (screens build and rebuild their contents), so the screens keep using
## `Kit.panel`, `Kit.label` and `Kit.button` as before:
##   - a kit panel (the meta `kit_panel`) becomes parchment, and the labels in it read in ink (`UiSkin.dress`); a panel marked `skin_well`
##     becomes the dark well a journal reads in and keeps its light text;
##   - a button becomes a wooden plank with studs, gold-lit when pointed at; a text box a light field; a rule a brown line;
##   - labels on the night sky keep their light colours; a title goes in a ribbon (`ribbon`).
## What an overlay panel (a node with its own script, added under the screen) holds is left to that panel. Rendering only.
extends RefCounted

const UiSkin := preload("res://ui/play/ui_skin.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const Backdrop := preload("res://ui/play/skin_backdrop.gd")


## Dresses `host` and what it will hold. `backdrop`: put the night sky behind it (a modal panel with its own dimmed backdrop says no).
static func apply(host: Control, backdrop: bool = true) -> void:
	if not UiSkin.screen_active(host) or host.has_meta("skin_screen"):
		return
	host.set_meta("skin_screen", true)
	if is_equal_approx(UiSettings.get_scale(), roundf(UiSettings.get_scale())):   # whole screen pixels: the art stays sharp; at 1.25 the text would not
		host.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if backdrop:
		var sky: Control = Backdrop.new()
		host.add_child(sky)
		host.move_child(sky, 0)
	var tree := host.get_tree()
	if tree == null:
		return
	var cb := func(n: Node):
		if host.is_ancestor_of(n):
			_dress(n, host)
	tree.node_added.connect(cb)
	host.tree_exiting.connect(func():
		if tree.node_added.is_connected(cb):
			tree.node_added.disconnect(cb))
	var todo: Array = host.get_children()
	while not todo.is_empty():
		var n: Node = todo.pop_front()
		_dress(n, host)
		todo.append_array(n.get_children())


## A title in a crimson ribbon (gold text, dark outline), or the label itself where the screens are not skinned. `size` 0 keeps the
## ribbon's own title size. The returned control is what to add.
static func ribbon(l: Label, size: int = 0) -> Control:
	if not UiSkin.screen_active(l):
		return l
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiSkin.ribbon_box())
	p.set_meta("skin_ribbon", true)
	p.set_meta("skin_screen_done", true)
	UiSkin.dress_title(l)
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
		UiSkin.dress_font(l, "title")
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(l)
	return p


## The dark well of a list that is read in light text (the life screen's journal).
static func well(p: PanelContainer) -> void:
	if UiSkin.screen_active(p):
		p.set_meta("skin_well", true)


## Which face a node sits on, from its nearest dressed ancestor: "parch", "well", or "" (the night sky, a ribbon, a button).
static func face_of(n: Node, host: Node) -> String:
	var p := n.get_parent()
	while p != null and p != host:
		if p.has_meta("skin_ribbon"):
			return ""
		if p.has_meta("skin_face"):
			return "parch"
		if p.has_meta("skin_well"):
			return "well"
		p = p.get_parent()
	return ""


## Whether `n` is inside something that has a script of its own under `host` (an overlay panel the screen opened): its colours are its own.
static func in_overlay(n: Node, host: Node) -> bool:
	var top := n
	while top.get_parent() != null and top.get_parent() != host:
		top = top.get_parent()
	return top != host and top.get_script() != null


static func _dress(n: Node, host: Control) -> void:
	if not (n is Control) or n.has_meta("skin_screen_done") or in_overlay(n, host):
		return
	n.set_meta("skin_screen_done", true)
	if n is PanelContainer:
		if n.has_meta("skin_well"):
			n.add_theme_stylebox_override("panel", UiSkin.well_box())
		elif n.has_meta("kit_panel") and not n.has_meta("skin_face"):
			n.add_theme_stylebox_override("panel", UiSkin.panel_box())
			n.set_meta("skin_face", true)
	elif n is Label or n is RichTextLabel:
		if face_of(n, host) == "parch":
			UiSkin.dress(n, host, "parch")
		elif n is Label and face_of(n, host) != "well" and not n.has_meta("skin_pixel_font"):
			UiSkin.dress_heading(n)   # a heading on the night sky
	elif n is LineEdit:
		UiSkin.dress_field(n)
	elif n is Button and not (n is CheckBox) and not n.has_meta("skin_keep"):
		UiSkin.dress_screen_button(n)
	elif n is HSeparator and face_of(n, host) == "parch":
		n.add_theme_stylebox_override("separator", UiSkin.rule_box())
	elif n is ProgressBar and n.has_meta("skin_bar_kind") and not n.has_meta("skin_bar"):
		UiSkin.dress_bar(n, str(n.get_meta("skin_bar_kind")))
