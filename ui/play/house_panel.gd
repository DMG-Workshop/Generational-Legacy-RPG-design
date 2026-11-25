## The family house: the two tracks the heir builds with gold (see GameHouse). Each row shows the
## level, what the house does now, what the next level adds and its price. The button builds the next
## level; a row that cannot be built says why. Nothing here computes a result: GameHouse does it all.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const PanelSkin := preload("res://ui/play/panel_skin.gd")
const CraftPanel := preload("res://ui/play/craft_panel.gd")
const HeirloomPanel := preload("res://ui/play/heirloom_panel.gd")
const TrialsPanel := preload("res://ui/play/trials_panel.gd")
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
	var note := Kit.label("Gold: %s. The house is kept by the dynasty, so every heir after this one has what is built here." % GameText.num(dynasty.heir.gold), 15, Kit.dim())
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(note)
	for track in GameHouse.TRACKS:
		_body.add_child(_row(track, column))
	var shop := Kit.button("Workshop: make things, break up gear", func(): _workshop(), Vector2(column, 48))
	shop.name = "Workshop"
	_body.add_child(shop)
	if not dynasty.heirlooms.is_empty():   # only a house that holds one: a new house's panel is as it was
		var looms := Kit.button("Heirlooms: have them reworked", func(): _heirlooms(), Vector2(column, 48))
		looms.name = "Heirlooms"
		_body.add_child(looms)
	var trials := Kit.button("Trials: tests of the realms", func(): _trials(), Vector2(column, 48))
	trials.name = "Trials"
	_body.add_child(trials)
	_body.add_child(Kit.button("Close", func(): queue_free(), Vector2(column, 48)))


## The trials open over the house, as the heirlooms do.
func _trials() -> void:
	var panel: Control = TrialsPanel.new()
	panel.dynasty = dynasty
	panel.on_change = on_change
	get_parent().add_child(panel)


## The heirlooms open over the house, as the workshop does.
func _heirlooms() -> void:
	var panel: Control = HeirloomPanel.new()
	panel.dynasty = dynasty
	panel.on_change = on_change
	get_parent().add_child(panel)


## The workshop opens over the house, so closing it comes back here.
func _workshop() -> void:
	var panel: Control = CraftPanel.new()
	panel.dynasty = dynasty
	panel.on_change = on_change
	get_parent().add_child(panel)


func _row(track: String, column: float) -> Control:
	var skinned := PanelSkin.on(self)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var lv := GameHouse.level(dynasty, track)
	var title := PanelSkin.label(self, "%s: level %d of %d" % [GameHouse.track_name(track), lv, GameHouse.max_level()], 18, Kit.TEXT)
	box.add_child(title)
	if skinned:   # the level as a segmented bar
		var pb := PanelSkin.progress(self, float(lv), float(GameHouse.max_level()), "level")
		pb.custom_minimum_size.x = 180.0
		pb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		box.add_child(pb)
	var now := PanelSkin.label(self, _effect(track, lv), 15, Kit.dim())
	now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(now)
	var price := GameHouse.cost(dynasty, track)
	var text := "Fully built."
	if price >= 0:
		text = "Next level: %s. Costs %s gold." % [_effect(track, lv + 1), GameText.num(price)]
	var next := PanelSkin.label(self, text, 15, Kit.dim())
	next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(next)
	var why := GameHouse.buy_error(dynasty, track)
	var label := "Build (%s gold)" % GameText.num(price) if price >= 0 else "Fully built"
	var b := PanelSkin.button(self, label, func(): _buy(track, column), Vector2(column, 48))
	b.disabled = why != ""
	if skinned:   # a coin and the price beside the key, so the cost reads at a glance
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.x = 0.0
		if price >= 0:
			line.add_child(PanelSkin.cost(self, price, dynasty.heir.gold >= price, 17))
		line.add_child(b)
		box.add_child(line)
	else:
		box.add_child(b)
	# The reason is shown as text, not a tooltip: a touch player sees it without holding the button.
	if why != "":
		var reason := PanelSkin.label(self, why, 14, Kit.dim())
		reason.name = "Reason"
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(reason)
	if not skinned:
		return box
	var slot := PanelSkin.row(self)
	slot.add_child(box)
	return slot


## What a track does at a level: the Hall's companion places, or the Yard's training XP.
static func _effect(track: String, lv: int) -> String:
	if track == GameHouse.HALL:
		var places := lv * int(GameData.bal("house_hall_slots_per_level"))
		return "%d extra companion place%s." % [places, "" if places == 1 else "s"]
	if track == GameHouse.RANCH:
		return str(GameRanch.data()["ranch"]["levels"][clampi(lv, 0, GameHouse.max_level())]["about"])
	if track == GameHouse.SMITHY:
		var cut := int(round(float(lv) * float(GameData.bal("house_smithy_fee_cut_per_level")) * 100.0))
		return "Made pieces are %d better, and the forge's fee is %d%% less." % [lv * int(GameData.bal("house_smithy_quality_per_level")), cut]
	var pct := int(round(float(lv) * float(GameData.bal("house_yard_train_xp_per_level")) * 100.0))
	return "Training gives %d%% more XP." % pct


func _buy(track: String, column: float) -> void:
	var msg := GameHouse.buy(dynasty, track)
	dynasty._say(msg)
	if on_change.is_valid():
		on_change.call()
	_build(column)
