## Notice board: side quests offered here, and the house's quest log.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")

var dynasty: GameDynasty
var on_change: Callable   # call after anything that changes the dynasty; the life screen refreshes


func _ready() -> void:
	var v := Kit.overlay(self, "Notice Board")
	v.add_child(Kit.label("Not built yet.", 16, Kit.DIM))


## Lines for the life screen's right-hand panel.
static func summary_lines(_d: GameDynasty) -> Array:
	return []
