## Tavern: companions for hire, and the party the house keeps.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")

var dynasty: GameDynasty
var on_change: Callable   # call after anything that changes the dynasty; the life screen refreshes


func _ready() -> void:
	var v := Kit.overlay(self, "Tavern")
	v.add_child(Kit.label("Not built yet.", 16, Kit.DIM))


## Lines for the life screen's right-hand panel.
static func summary_lines(_d: GameDynasty) -> Array:
	return []
