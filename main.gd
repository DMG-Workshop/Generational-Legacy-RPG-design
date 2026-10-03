## Entry point: launches the playable game (ui/play/game_app.gd).
extends Node

const GameApp := preload("res://ui/play/game_app.gd")


func _ready() -> void:
	add_child(GameApp.new())
