## Menu Manager: Orchestrates main menu, pause menu, and settings
##
## Manages menu navigation, transitions, and state

extends CanvasLayer

class_name MenuManager


signal menu_opened(menu_type: String)
signal menu_closed(menu_type: String)
signal game_started()
signal game_resumed()
signal settings_changed(setting: String, value: String)


enum MenuType { MAIN, PAUSE, SETTINGS, INVENTORY, MAP }

# UI references
var main_menu: Control
var pause_menu: Control
var settings_menu: Control
var menu_stack: Array = []  # Track menu history

# Current state
var is_menu_open: bool = false
var current_menu: int = MenuType.MAIN


func _ready() -> void:
	_create_main_menu()
	_create_pause_menu()
	_create_settings_menu()

	# Show main menu on start
	show_menu(MenuType.MAIN)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_handle_escape_pressed()


## Create main menu UI
func _create_main_menu() -> void:
	main_menu = Control.new()
	add_child(main_menu)

	var container = VBoxContainer.new()
	container.anchor_left = 0.25
	container.anchor_top = 0.25
	container.anchor_right = 0.75
	container.anchor_bottom = 0.75
	main_menu.add_child(container)

	# Title
	var title = Label.new()
	title.text = "GENERATIONAL LEGACY"
	title.add_theme_font_size_override("font_size", 32)
	container.add_child(title)

	# Start button
	var start_button = Button.new()
	start_button.text = "New Game"
	start_button.pressed.connect(_on_new_game_pressed)
	container.add_child(start_button)

	# Continue button
	var continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.pressed.connect(_on_continue_pressed)
	container.add_child(continue_button)

	# Settings button
	var settings_button = Button.new()
	settings_button.text = "Settings"
	settings_button.pressed.connect(_on_settings_pressed)
	container.add_child(settings_button)

	# Quit button
	var quit_button = Button.new()
	quit_button.text = "Quit"
	quit_button.pressed.connect(_on_quit_pressed)
	container.add_child(quit_button)


## Create pause menu UI
func _create_pause_menu() -> void:
	pause_menu = Control.new()
	pause_menu.visible = false
	add_child(pause_menu)

	# Semi-transparent background
	var bg = ColorRect.new()
	bg.anchor_left = 0.0
	bg.anchor_top = 0.0
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color.BLACK
	bg.modulate.a = 0.5
	pause_menu.add_child(bg)

	var container = VBoxContainer.new()
	container.anchor_left = 0.3
	container.anchor_top = 0.3
	container.anchor_right = 0.7
	container.anchor_bottom = 0.7
	pause_menu.add_child(container)

	# Title
	var title = Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 24)
	container.add_child(title)

	# Resume button
	var resume_button = Button.new()
	resume_button.text = "Resume"
	resume_button.pressed.connect(_on_resume_pressed)
	container.add_child(resume_button)

	# Settings button
	var settings_button = Button.new()
	settings_button.text = "Settings"
	settings_button.pressed.connect(_on_pause_settings_pressed)
	container.add_child(settings_button)

	# Main menu button
	var menu_button = Button.new()
	menu_button.text = "Main Menu"
	menu_button.pressed.connect(_on_main_menu_pressed)
	container.add_child(menu_button)


## Create settings menu UI
func _create_settings_menu() -> void:
	settings_menu = Control.new()
	settings_menu.visible = false
	add_child(settings_menu)

	var container = VBoxContainer.new()
	container.anchor_left = 0.2
	container.anchor_top = 0.2
	container.anchor_right = 0.8
	container.anchor_bottom = 0.8
	settings_menu.add_child(container)

	# Title
	var title = Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 24)
	container.add_child(title)

	# Volume setting
	var volume_label = Label.new()
	volume_label.text = "Volume:"
	container.add_child(volume_label)

	var volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.value = 80
	volume_slider.value_changed.connect(_on_volume_changed)
	container.add_child(volume_slider)

	# Difficulty setting
	var difficulty_label = Label.new()
	difficulty_label.text = "Difficulty:"
	container.add_child(difficulty_label)

	var difficulty_option = OptionButton.new()
	difficulty_option.add_item("Easy")
	difficulty_option.add_item("Normal")
	difficulty_option.add_item("Hard")
	difficulty_option.select(1)
	difficulty_option.item_selected.connect(_on_difficulty_changed)
	container.add_child(difficulty_option)

	# Back button
	var back_button = Button.new()
	back_button.text = "Back"
	back_button.pressed.connect(_on_settings_back_pressed)
	container.add_child(back_button)


## Show specific menu
func show_menu(menu_type: int) -> void:
	# Hide all menus
	if main_menu:
		main_menu.visible = false
	if pause_menu:
		pause_menu.visible = false
	if settings_menu:
		settings_menu.visible = false

	# Show selected menu
	match menu_type:
		MenuType.MAIN:
			if main_menu:
				main_menu.visible = true
			current_menu = MenuType.MAIN
			is_menu_open = true

		MenuType.PAUSE:
			if pause_menu:
				pause_menu.visible = true
			current_menu = MenuType.PAUSE
			is_menu_open = true

		MenuType.SETTINGS:
			if settings_menu:
				settings_menu.visible = true
			current_menu = MenuType.SETTINGS
			is_menu_open = true

	menu_opened.emit(MenuType.keys()[menu_type])
	get_tree().paused = is_menu_open


## Hide all menus
func hide_all_menus() -> void:
	if main_menu:
		main_menu.visible = false
	if pause_menu:
		pause_menu.visible = false
	if settings_menu:
		settings_menu.visible = false

	is_menu_open = false
	get_tree().paused = false


## Handle button callbacks
func _on_new_game_pressed() -> void:
	hide_all_menus()
	game_started.emit()


func _on_continue_pressed() -> void:
	hide_all_menus()
	game_started.emit()


func _on_settings_pressed() -> void:
	show_menu(MenuType.SETTINGS)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_resume_pressed() -> void:
	hide_all_menus()
	game_resumed.emit()


func _on_pause_settings_pressed() -> void:
	show_menu(MenuType.SETTINGS)


func _on_main_menu_pressed() -> void:
	show_menu(MenuType.MAIN)


func _on_settings_back_pressed() -> void:
	if current_menu == MenuType.SETTINGS:
		if menu_stack.size() > 0:
			show_menu(menu_stack.pop_back())
		else:
			show_menu(MenuType.MAIN)


func _on_volume_changed(value: float) -> void:
	settings_changed.emit("volume", str(value))


func _on_difficulty_changed(index: int) -> void:
	var difficulty_names = ["Easy", "Normal", "Hard"]
	settings_changed.emit("difficulty", difficulty_names[index])


## Toggle pause menu
func toggle_pause_menu() -> void:
	if pause_menu.visible:
		_on_resume_pressed()
	else:
		show_menu(MenuType.PAUSE)


## Handle escape key
func _handle_escape_pressed() -> void:
	if current_menu == MenuType.MAIN:
		get_tree().quit()
	elif current_menu == MenuType.SETTINGS:
		_on_settings_back_pressed()
	else:
		toggle_pause_menu()


## Get menu visibility state
func is_menu_visible() -> bool:
	return is_menu_open


## Get current menu type
func get_current_menu() -> int:
	return current_menu
