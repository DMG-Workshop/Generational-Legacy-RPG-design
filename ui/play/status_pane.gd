## The status pane (docs/PLAYER_INTERFACE.md, slice 3): the heir's name and level and three bars (health, mana and what they carry
## against what they can carry), and their gold. A pane that stays up over the open world (see PaneKit); the sandbox screen calls
## `refresh` a few times a second. Rendering only: GameHeir and GameCarry say the numbers.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const UiSkin := preload("res://ui/play/ui_skin.gd")

var dynasty: GameDynasty
var _who: Label
var _gold: Label
var _bars: Dictionary = {}   # "hp" | "mp" | "load" -> {bar, label}


func _ready() -> void:
	var v := Kit.overlay(self, dynasty.heir.name)
	v.add_theme_constant_override("separation", 6)
	_who = Kit.label("", 14, Kit.dim())
	v.add_child(_who)
	for row in [["hp", "Health", Kit.good()], ["mp", "Mana", Kit.MP_BLUE], ["load", "Carrying", Kit.ACCENT]]:
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
	refresh()


func refresh() -> void:
	var h := dynasty.heir
	_who.text = "Level %d %s" % [h.level, str(GameData.classes.get(h.class_id, {}).get("name", h.class_id))]
	_put("hp", float(h.hp), float(h.max_hp()), "%d of %d" % [h.hp, h.max_hp()])
	_put("mp", float(h.mp), float(maxi(1, h.max_mp())), "%d of %d" % [h.mp, h.max_mp()])
	var load_now := GameCarry.carried(h)
	var cap := GameCarry.capacity(h)
	_put("load", minf(load_now, cap), cap, GameCarry.summary(h))
	var bar: ProgressBar = _bars["load"]["bar"]
	bar.add_theme_stylebox_override("fill", Kit.style(Kit.bad() if GameCarry.burdened(h) else Kit.ACCENT, 4))
	if bar.has_meta("skin_bar"):
		bar.add_theme_stylebox_override("fill", StyleBoxEmpty.new())
		UiSkin.bar_text(bar, GameCarry.summary(h), "load_bad" if GameCarry.burdened(h) else "load")
	_gold.text = "%s gold" % GameText.num(h.gold)


func _put(key: String, value: float, top: float, text: String) -> void:
	var r: Dictionary = _bars[key]
	(r["bar"] as ProgressBar).max_value = maxf(top, 1.0)
	(r["bar"] as ProgressBar).value = value
	(r["label"] as Label).text = "%s  %s" % [r["name"], text]
	UiSkin.bar_text(r["bar"], text)
