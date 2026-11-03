## The family house: the two tracks the heir builds with gold (see GameHouse). Each row shows the
## level, what the house does now, what the next level adds and its price. The button builds the next
## level; a row that cannot be built says why. Nothing here computes a result: GameHouse does it all.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const WIDE := 760.0

var dynasty: GameDynasty
var on_change: Callable
var _body: VBoxContainer


func _ready() -> void:
	var v := Kit.overlay(self, "The family house")
	set_meta("modal", true)
	var column := minf(WIDE, Kit.overlay_room(self) - 16.0)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(center)
	_body = VBoxContainer.new()
	_body.custom_minimum_size = Vector2(column, 0)
	_body.add_theme_constant_override("separation", 10)
	center.add_child(_body)
	_build(column)


## Draws the rows afresh, so a purchase shows at once.
func _build(column: float) -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var note := Kit.label("Gold: %s. The house is kept by the dynasty, so every heir after this one has what is built here." % GameText.num(dynasty.heir.gold), 15, Kit.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(note)
	for track in GameHouse.TRACKS:
		_body.add_child(_row(track, column))
	_body.add_child(Kit.button("Close", func(): queue_free(), Vector2(column, 48)))


func _row(track: String, column: float) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var lv := GameHouse.level(dynasty, track)
	var title := Kit.label("%s: level %d of %d" % [GameHouse.track_name(track), lv, GameHouse.max_level()], 18, Kit.TEXT)
	box.add_child(title)
	var now := Kit.label(_effect(track, lv), 15, Kit.DIM)
	now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(now)
	var price := GameHouse.cost(dynasty, track)
	var text := "Fully built."
	if price >= 0:
		text = "Next level: %s. Costs %s gold." % [_effect(track, lv + 1), GameText.num(price)]
	var next := Kit.label(text, 15, Kit.DIM)
	next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(next)
	var why := GameHouse.buy_error(dynasty, track)
	var label := "Build (%s gold)" % GameText.num(price) if price >= 0 else "Fully built"
	var b := Kit.button(label, func(): _buy(track, column), Vector2(column, 48))
	b.disabled = why != ""
	box.add_child(b)
	# The reason is shown as text, not a tooltip: a touch player sees it without holding the button.
	if why != "":
		var reason := Kit.label(why, 14, Kit.DIM)
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(reason)
	return box


## What a track does at a level: the Hall's companion places, or the Yard's training XP.
static func _effect(track: String, lv: int) -> String:
	if track == GameHouse.HALL:
		var places := lv * int(GameData.bal("house_hall_slots_per_level"))
		return "%d extra companion place%s." % [places, "" if places == 1 else "s"]
	var pct := int(round(float(lv) * float(GameData.bal("house_yard_train_xp_per_level")) * 100.0))
	return "Training gives %d%% more XP." % pct


func _buy(track: String, column: float) -> void:
	var msg := GameHouse.buy(dynasty, track)
	dynasty._say(msg)
	if on_change.is_valid():
		on_change.call()
	_build(column)
