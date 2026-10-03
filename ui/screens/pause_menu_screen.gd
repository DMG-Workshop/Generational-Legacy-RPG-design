## Pause menu screen: in-game menu

extends Control

class_name PauseMenuScreen


func _ready() -> void:
	# Setup background overlay
	var bg = ColorRect.new()
	bg.color = Color.BLACK.with_alpha(0.7)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Center menu
	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.5
	vbox.offset_left = -150
	vbox.offset_top = -150
	vbox.custom_minimum_size = Vector2(300, 300)
	add_child(vbox)

	var title = Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 28)
	title.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Options
	var resume_btn = Button.new()
	resume_btn.text = "Resume (ESC)"
	resume_btn.pressed.connect(_on_resume)
	vbox.add_child(resume_btn)

	var save_btn = Button.new()
	save_btn.text = "Save Game"
	save_btn.pressed.connect(_on_save)
	vbox.add_child(save_btn)

	var load_btn = Button.new()
	load_btn.text = "Load Game"
	load_btn.pressed.connect(_on_load)
	vbox.add_child(load_btn)

	var menu_btn = Button.new()
	menu_btn.text = "Return to Menu"
	menu_btn.pressed.connect(_on_main_menu)
	vbox.add_child(menu_btn)

	var quit_btn = Button.new()
	quit_btn.text = "Quit Game"
	quit_btn.pressed.connect(_on_quit)
	vbox.add_child(quit_btn)


func _on_resume() -> void:
	var main_game = get_tree().root.get_child(0)
	main_game.show_screen("world")


func _on_save() -> void:
	print("Save game - showing save dialog")
	var main_game = get_tree().root.get_child(0)
	main_game.save_game(0)  # Save to slot 0
	print("Game saved!")


func _on_load() -> void:
	var main_game = get_tree().root.get_child(0)
	main_game.show_screen("load")


func _on_main_menu() -> void:
	var main_game = get_tree().root.get_child(0)
	main_game.show_main_menu()


func _on_quit() -> void:
	get_tree().quit()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_resume()
