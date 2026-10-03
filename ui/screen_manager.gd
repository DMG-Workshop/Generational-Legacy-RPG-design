## Screen manager: container for all UI screens
##
## Handles screen layering and transitions

extends CanvasLayer

class_name ScreenManager


func _ready() -> void:
	# Ensure screens are rendered on top
	layer = 10
