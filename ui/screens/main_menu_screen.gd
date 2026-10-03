## Main menu screen: new game, load, options, quit

extends Control

class_name MainMenuScreen


func _ready() -> void:
	# Create UI hierarchy
	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.5
	vbox.offset_left = -150
	vbox.offset_top = -150
	vbox.size = Vector2(300, 300)
	add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Generational Legacy"
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	# Buttons
	var new_btn = Button.new()
	new_btn.text = "New Game"
	new_btn.pressed.connect(_on_new_game)
	vbox.add_child(new_btn)

	var load_btn = Button.new()
	load_btn.text = "Load Game"
	load_btn.pressed.connect(_on_load_game)
	vbox.add_child(load_btn)

	var quit_btn = Button.new()
	quit_btn.text = "Quit"
	quit_btn.pressed.connect(_on_quit)
	vbox.add_child(quit_btn)


func _on_new_game() -> void:
	var main_game = get_tree().root.get_child(0)
	main_game.start_new_game()


func _on_load_game() -> void:
	var main_game = get_tree().root.get_child(0)
	main_game.show_screen("load")


func _on_quit() -> void:
	get_tree().quit()
