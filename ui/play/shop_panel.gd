## Town shops: forge, store and temple; the heir's gear and pack.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")

var dynasty: GameDynasty
var on_change: Callable   # call after anything that changes the dynasty; the life screen refreshes


func _ready() -> void:
	var v := Kit.overlay(self, "Shops")
	v.add_child(Kit.label("Not built yet.", 16, Kit.DIM))
