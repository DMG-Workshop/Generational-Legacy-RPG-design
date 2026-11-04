## Choosing whom the heir marries: the opposite-sex candidates the dynasty offers (see
## GameDynasty.mate_candidates), each with race, class and traits. The pick is the marriage.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const WIDE := 760.0

var dynasty: GameDynasty
var on_change: Callable


func _ready() -> void:
	var v := Kit.overlay(self, "Choose a mate for %s" % dynasty.heir.name)
	set_meta("modal", true)
	var column := minf(WIDE, Kit.overlay_room(self) - 16.0)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(center)
	var body := VBoxContainer.new()
	body.custom_minimum_size = Vector2(column, 0)
	body.add_theme_constant_override("separation", 10)
	center.add_child(body)
	var note := Kit.label("Only %s are offered. The one you pick is the spouse, and the children carry both of your blood." % _sex_word(GameSex.opposite(dynasty.heir.sex)), 15, Kit.dim())
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	var mates := dynasty.mate_candidates()
	for i in mates.size():
		body.add_child(_candidate(mates[i], i, column))


func _candidate(m: GameHeir, index: int, column: float) -> Button:
	var traits := []
	for t in m.traits:
		traits.append(GameData.trait_name(t))
	var dormant := []
	for t in m.dormant:
		dormant.append("(%s)" % GameData.trait_name(t))
	var lines := "%s %s: %s, %s" % [m.name, m.surname, m.race()["name"], m.cls()["name"]]
	var detail := "Traits: %s" % (", ".join(traits) if not traits.is_empty() else "none")
	if not dormant.is_empty():
		detail += "   Hidden: %s" % ", ".join(dormant)
	var b := Kit.button("%s\n%s" % [lines, detail], func(): _pick(index), Vector2(column, 64))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return b


func _pick(index: int) -> void:
	dynasty.found_family(index)
	if on_change.is_valid():
		on_change.call()
	queue_free()


static func _sex_word(sex: String) -> String:
	return "women" if sex == GameSex.FEMALE else "men"
