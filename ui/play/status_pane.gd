## The status pane (docs/PLAYER_INTERFACE.md, slice 3): the heir's name and level and four bars (health, mana, experience toward
## the next level, and what they carry against what they can carry), their gold, and the time a smoke pot's cloud has left while one
## burns. A pane that stays up over the open world (see PaneKit); the sandbox screen calls
## `refresh` a few times a second. Rendering only: GameHeir and GameCarry say the numbers.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSkin := preload("res://ui/play/ui_skin.gd")
const GoalView := preload("res://ui/play/goal_view.gd")

var dynasty: GameDynasty
var sb: GameSandbox = null   # where the heir is, for the pin's distance
var _pin: Label
var _goal: Label   # the goal arrow's words: "Goal: Rest at the family house (24 tiles NE)"
var _who: Label
var _gold: Label
var _smoke: Label
var _bars: Dictionary = {}   # "hp" | "mp" | "xp" | "load" -> {bar, label}


func _ready() -> void:
	var v := Kit.overlay(self, dynasty.heir.name)
	v.add_theme_constant_override("separation", 6)
	_who = Kit.label("", 14, Kit.dim())
	v.add_child(_who)
	for row in [["hp", "Health", Kit.good()], ["mp", "Mana", Kit.MP_BLUE], ["xp", "XP", Kit.ACCENT], ["load", "Carrying", Kit.ACCENT]]:
		var l := Kit.label("", 13)
		v.add_child(l)
		var b := Kit.bar(row[2], 1.0, 0.0, Vector2(0, 14))
		v.add_child(b)
		if UiSkin.in_skin(self):   # a segmented bar with its picture and its words over it
			UiSkin.dress_bar(b, str(row[0]))
			l.visible = false
		_bars[str(row[0])] = {"bar": b, "label": l, "name": str(row[1]), "color": row[2]}
	_gold = Kit.label("", 14, Kit.ACCENT)
	v.add_child(_gold)
	_smoke = Kit.label("", 13, Kit.dim())
	_smoke.visible = false
	v.add_child(_smoke)
	_pin = Kit.label("", 13, Kit.dim())   # the map pin: "Pin: Kingshold, 212 tiles NE" (only when one is set)
	_pin.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pin.visible = false
	v.add_child(_pin)
	_goal = Kit.label("", 13, Kit.good())
	_goal.name = "GoalLine"
	_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal.visible = false
	v.add_child(_goal)
	refresh()


func refresh() -> void:
	var h := dynasty.heir
	_who.text = "Level %d %s" % [h.level, str(GameData.classes.get(h.class_id, {}).get("name", h.class_id))]
	_put("hp", float(h.hp), float(h.max_hp()), "%d of %d" % [h.hp, h.max_hp()])
	_put("mp", float(h.mp), float(maxi(1, h.max_mp())), "%d of %d" % [h.mp, h.max_mp()])
	_put("xp", float(h.xp), float(maxi(1, h.xp_to_next())), "Lv %s  %s / %s" % [GameText.num(h.level), GameText.num(h.xp), GameText.num(h.xp_to_next())])
	var load_now := GameCarry.carried(h)
	var cap := GameCarry.capacity(h)
	_put("load", minf(load_now, cap), cap, GameCarry.summary(h))
	var bar: ProgressBar = _bars["load"]["bar"]
	bar.add_theme_stylebox_override("fill", Kit.style(Kit.bad() if GameCarry.burdened(h) else Kit.ACCENT, 4))
	if bar.has_meta("skin_bar"):
		bar.add_theme_stylebox_override("fill", StyleBoxEmpty.new())
		UiSkin.bar_text(bar, GameCarry.summary(h), "load_bad" if GameCarry.burdened(h) else "load")
	_gold.text = "%s gold" % GameText.num(h.gold)
	_smoke.visible = GameSmoke.active(dynasty)   # "Smoke 2:10" while a pot's cloud burns
	if _smoke.visible:
		_smoke.text = GameSmoke.text("timer", {"time": GameSmoke.clock_text(GameSmoke.left(dynasty))})
	var pin_text := GameTravel.pin_line(dynasty, sb.heir) if sb != null and sb.space == "world" else ""
	_pin.text = pin_text
	_pin.visible = pin_text != ""
	var goal_text := GoalView.line(sb.heir) if sb != null and sb.space == "world" else ""
	_goal.text = goal_text
	_goal.visible = goal_text != ""


func _put(key: String, value: float, top: float, text: String) -> void:
	var r: Dictionary = _bars[key]
	(r["bar"] as ProgressBar).max_value = maxf(top, 1.0)
	(r["bar"] as ProgressBar).value = value
	(r["label"] as Label).text = "%s  %s" % [r["name"], text]
	UiSkin.bar_text(r["bar"], text)
