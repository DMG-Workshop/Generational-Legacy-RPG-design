## Root of the playable game: owns the dynasty and swaps screens.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const TitleScreen := preload("res://ui/play/title_screen.gd")
const LifeScreen := preload("res://ui/play/life_screen.gd")
const BattleView := preload("res://ui/play/battle_view.gd")
const SuccessionScreen := preload("res://ui/play/succession_screen.gd")

var dynasty: GameDynasty
var current: Control
var bg: ColorRect


func _ready() -> void:
	GameData.load_all()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg = ColorRect.new()
	bg.color = Kit.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	show_title()


func _swap(screen: Control) -> void:
	if current != null:
		remove_child(current)
		current.queue_free()
	current = screen
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)


func show_title() -> void:
	var s := TitleScreen.new()
	s.app = self
	_swap(s)


func new_game(p_name: String, class_id: String, bloodline: String, p_seed: int, race_id: String = "human") -> void:
	dynasty = GameDynasty.new_game(p_seed, p_name, class_id, bloodline, race_id)
	dynasty.save_to_disk()
	show_state()


func continue_game() -> void:
	var d := GameDynasty.load_from_disk()
	if d == null:
		return
	dynasty = d
	show_state()


## Show the screen that matches the dynasty's current state.
func show_state() -> void:
	if dynasty.battle != null:
		var b := BattleView.new()
		b.app = self
		_swap(b)
	elif dynasty.state == "succession":
		var s := SuccessionScreen.new()
		s.app = self
		_swap(s)
	else:
		var l := LifeScreen.new()
		l.app = self
		_swap(l)


func autosave() -> void:
	if dynasty != null:
		dynasty.save_to_disk()
