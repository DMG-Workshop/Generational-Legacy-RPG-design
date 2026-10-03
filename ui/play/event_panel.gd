## An event waiting for a choice (GameDynasty.pending_event), with skill checks.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")

var dynasty: GameDynasty
var on_change: Callable   # call after anything that changes the dynasty; the life screen refreshes


func _ready() -> void:
	var v := Kit.overlay(self, "Event")
	v.add_child(Kit.label("Not built yet.", 16, Kit.DIM))
