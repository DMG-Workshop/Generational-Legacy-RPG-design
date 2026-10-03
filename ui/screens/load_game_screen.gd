## Load game screen: show saved games and allow loading

extends Control

class_name LoadGameScreen


func _ready() -> void:
	# Background overlay
	var bg = ColorRect.new()
	bg.color = Color.BLACK.with_alpha(0.8)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Main panel
	var panel = PanelContainer.new()
	panel.anchor_left = 0.2
	panel.anchor_top = 0.1
	panel.anchor_right = 0.8
	panel.anchor_bottom = 0.9
	add_child(panel)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Load Game"
	title.add_theme_font_size_override("font_size", 24)
	title.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Save slots list
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	vbox.add_child(scroll)

	var slots_vbox = VBoxContainer.new()
	scroll.add_child(slots_vbox)

	# Create 5 save slots
	for i in range(5):
		var slot_btn = _create_save_slot_button(i)
		slots_vbox.add_child(slot_btn)

	# Back button
	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.pressed.connect(_on_back)
	vbox.add_child(back_btn)


func _create_save_slot_button(slot: int) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 60)

	# Check if save exists
	var save_file = "user://saves/slot_%d.save" % slot
	if FileAccess.file_exists(save_file):
		btn.text = "Slot %d - [Save Found]" % slot
		btn.pressed.connect(_on_load_slot.bind(slot))
	else:
		btn.text = "Slot %d - [Empty]" % slot
		btn.disabled = true

	return btn


func _on_load_slot(slot: int) -> void:
	var main_game = get_tree().root.get_child(0)
	var result = main_game.load_game(slot)
	if result:
		print("Loaded game from slot %d" % slot)
	else:
		print("Failed to load game from slot %d" % slot)


func _on_back() -> void:
	var main_game = get_tree().root.get_child(0)
	main_game.show_screen("pause")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_back()
