## Main bootstrap script for the game
##
## Entry point that initializes MainGame

extends Node

func _ready() -> void:
	var main_game = MainGame.new()
	add_child(main_game)
