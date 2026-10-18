## The dead of the last victory, still waiting (the game was closed on the battle's result screen
## before the player chose): search them or leave them, as the result screen offers.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const WIDE := 760.0

var dynasty: GameDynasty
var on_change: Callable
var body: VBoxContainer
var column := WIDE


func _ready() -> void:
	if dynasty.loot.is_empty():
		queue_free()
		return
	var v := Kit.overlay(self, "The dead of your last fight")
	var top: HBoxContainer = v.get_child(0)
	top.get_child(top.get_child_count() - 1).visible = false   # an answer is wanted; Leave them is the way out
	remove_meta("back_close")
	set_meta("modal", true)
	column = minf(WIDE, Kit.overlay_room(self) - 16.0)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(center)
	body = VBoxContainer.new()
	body.custom_minimum_size = Vector2(column, 0)
	body.add_theme_constant_override("separation", 10)
	center.add_child(body)
	var names: Array = dynasty.loot["foes"].map(func(f): return str(f["name"]))
	body.add_child(_wrapped("%s still lie where %s left them: %s." % ["They" if names.size() > 1 else "The body", dynasty.heir.name, ", ".join(names)], 17))
	var risk := _wrapped(GamePlague.risk_text(dynasty), 15, Kit.BAD if GamePlague.risk(dynasty) > 0.0 else Kit.DIM)
	body.add_child(risk)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	var search := Kit.button("Search the bodies", func(): _done(GamePlague.search(dynasty)), Vector2(0, 44))
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(search)
	var leave := Kit.button("Leave them", func(): _done(GamePlague.leave(dynasty)), Vector2(0, 44))
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(leave)


func _wrapped(text: String, size: int, color: Color = Kit.TEXT) -> Label:
	var l := Kit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(column, 0)
	return l


func _done(lines: Array) -> void:
	Kit.clear(body)
	for line in lines:
		body.add_child(_wrapped(str(line), 16, Kit.BAD if " catches " in str(line) else Kit.TEXT))
	body.add_child(Kit.button("Continue", func(): _close(), Vector2(column, 44)))
	dynasty.save_to_disk()


func _close() -> void:
	queue_free()
	if on_change.is_valid():
		on_change.call()
