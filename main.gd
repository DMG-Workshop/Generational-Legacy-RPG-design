## Entry point: launches the playable game (ui/play/game_app.gd).
extends Node

const GameApp := preload("res://ui/play/game_app.gd")


func _ready() -> void:
	var app := GameApp.new()
	app.boot_in_world = true   # a saved house opens in the 2D open world, not on the title
	add_child(app)
