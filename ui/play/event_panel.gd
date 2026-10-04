## An event waiting for a choice (GameDynasty.pending_event): the scene, the choices with their
## checks and odds, then the roll and what came of it.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const COLUMN := 900.0

var dynasty: GameDynasty
var on_change: Callable   # call after anything that changes the dynasty; the life screen refreshes
var body: VBoxContainer


func _ready() -> void:
	GameEvents.drop_stale(dynasty)
	if not dynasty.has_pending_event():
		queue_free()
		return
	var v := Kit.overlay(self, GameEvents.event_title(dynasty))
	# An event wants an answer, and every event has a way to walk away, so there is no Close.
	var top: HBoxContainer = v.get_child(0)
	top.get_child(top.get_child_count() - 1).visible = false
	var place: Dictionary = GameWorld.place(str(dynasty.pending_event.get("place", dynasty.world.location)))
	var sub := Kit.label("%s  -  %s  -  %s, level %d" % [place.get("name", ""), dynasty.world.date_text(), dynasty.heir.name, dynasty.heir.level], 15, Kit.DIM)
	v.add_child(sub)
	v.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	body = VBoxContainer.new()
	body.custom_minimum_size = Vector2(COLUMN, 0)
	body.add_theme_constant_override("separation", 10)
	center.add_child(body)
	_build()


func _wrapped(text: String, size: int, color: Color = Kit.TEXT) -> Label:
	var l := Kit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(COLUMN, 0)
	return l


func _build() -> void:
	Kit.clear(body)
	body.add_child(_wrapped(GameEvents.event_text(dynasty), 18))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	body.add_child(spacer)
	if GameEvents.stage(dynasty) == "result":
		_build_result()
	else:
		_build_choices()


func _build_choices() -> void:
	body.add_child(Kit.label("What do you do?", 16, Kit.ACCENT))
	var choices: Array = GameEvents.current(dynasty)["choices"]
	for i in choices.size():
		var idx := i
		var st := GameEvents.choice_status(dynasty, choices[i])
		var b := Kit.button(GameEvents.choice_label(dynasty, i), func(): _choose(idx), Vector2(COLUMN, 46))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.disabled = not st["ok"]
		b.tooltip_text = GameEvents.choice_tooltip(dynasty, i)
		body.add_child(b)
	var hint := Kit.label("Hover a choice to see how its bonus is made up and the odds of each result.", 13, Kit.DIM)
	body.add_child(hint)


func _choose(i: int) -> void:
	dynasty.resolve_event(i)
	# Save and refresh behind the panel now, unless a fight or a death would swap screens under it.
	if dynasty.battle == null and dynasty.state == "life" and on_change.is_valid():
		on_change.call()
	_build()


func _build_result() -> void:
	var r: Dictionary = dynasty.pending_event.get("result", {})
	body.add_child(_wrapped("You chose: %s" % r.get("choice_text", ""), 15, Kit.DIM))
	var roll: Dictionary = r.get("roll", {})
	if not roll.is_empty():
		var deg: String = roll.get("degree", "")
		var col := Kit.GOOD if deg.ends_with("success") else Kit.BAD
		var line := Kit.label("%s check:  %s" % [GameEvents.ATTR_LABELS.get(roll.get("attr", ""), ""), GameEvents.roll_text(roll)], 20, col)
		body.add_child(line)
	var text: String = r.get("text", "")
	if text != "":
		body.add_child(_wrapped(text, 18))
	var fx: Array = r.get("effects", [])
	if not fx.is_empty():
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		for f in fx:
			var k: String = f.get("k", "info")
			var col: Color = Kit.GOOD if k == "good" else (Kit.BAD if k == "bad" else Kit.TEXT)
			box.add_child(_wrapped("  %s" % f.get("t", ""), 15, col))
		body.add_child(box)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	body.add_child(spacer)
	var label := "Continue"
	if not (r.get("fight", []) as Array).is_empty() and dynasty.battle != null:
		label = "To battle"
	body.add_child(Kit.button(label, _continue, Vector2(COLUMN, 44)))


func _continue() -> void:
	GameEvents.dismiss(dynasty)
	queue_free()
	if on_change.is_valid():
		on_change.call()
