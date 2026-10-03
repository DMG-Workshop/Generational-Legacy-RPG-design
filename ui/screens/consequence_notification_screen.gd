## Consequence notification screen: shows outcome of dialogue choices
##
## Displays gold gained, reputation changes, quests started, and traits gained.
## Auto-closes after showing consequences or on player interaction.

extends Control

class_name ConsequenceNotificationScreen


var consequences: Dictionary
var heir: Heir
var display_time: float = 3.0
var elapsed_time: float = 0.0


func _init(p_consequences: Dictionary, p_heir: Heir) -> void:
	consequences = p_consequences
	heir = p_heir


func _ready() -> void:
	# Background with transparency
	var bg = ColorRect.new()
	bg.color = Color.BLACK.with_alpha(0.5)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Notification panel
	var panel = PanelContainer.new()
	panel.anchor_left = 0.25
	panel.anchor_top = 0.3
	panel.anchor_right = 0.75
	panel.anchor_bottom = 0.7
	add_child(panel)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	vbox.add_theme_constant_override("separation", 15)

	# Title
	var title = Label.new()
	title.text = "Outcome"
	title.add_theme_font_size_override("font_size", 20)
	title.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Separator
	var separator = HSeparator.new()
	vbox.add_child(separator)

	# Content vbox for individual items
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(content_vbox)

	# Gold gained
	if consequences.get("gold_gained", 0) > 0:
		var gold_label = Label.new()
		gold_label.text = "+ %d Gold" % consequences["gold_gained"]
		gold_label.add_theme_font_size_override("font_size", 14)
		gold_label.add_theme_color_override("font_color", Color.YELLOW)
		content_vbox.add_child(gold_label)

	# Reputation gained/lost
	if consequences.get("reputation_gained", 0) > 0:
		var rep_label = Label.new()
		rep_label.text = "+ %d Reputation" % consequences["reputation_gained"]
		rep_label.add_theme_font_size_override("font_size", 14)
		rep_label.add_theme_color_override("font_color", Color.GREEN)
		content_vbox.add_child(rep_label)
	elif consequences.get("reputation_gained", 0) < 0:
		var rep_label = Label.new()
		rep_label.text = "- %d Reputation" % abs(consequences["reputation_gained"])
		rep_label.add_theme_font_size_override("font_size", 14)
		rep_label.add_theme_color_override("font_color", Color.RED)
		content_vbox.add_child(rep_label)

	# Quest started
	if consequences.get("quest_started", false):
		var quest_label = Label.new()
		quest_label.text = "Quest Started!"
		quest_label.add_theme_font_size_override("font_size", 14)
		quest_label.add_theme_color_override("font_color", Color.CYAN)
		content_vbox.add_child(quest_label)

	# Items gained
	if consequences.get("items_gained", []).size() > 0:
		for item in consequences["items_gained"]:
			var item_label = Label.new()
			item_label.text = "+ Gained: %s" % item
			item_label.add_theme_font_size_override("font_size", 12)
			item_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
			content_vbox.add_child(item_label)

	# If no consequences, show default message
	if content_vbox.get_child_count() == 0:
		var default_label = Label.new()
		default_label.text = "Conversation ended."
		default_label.add_theme_font_size_override("font_size", 14)
		content_vbox.add_child(default_label)

	# Continue button
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(button_hbox)

	var continue_btn = Button.new()
	continue_btn.text = "Continue"
	continue_btn.custom_minimum_size = Vector2(100, 30)
	continue_btn.pressed.connect(_on_continue)
	button_hbox.add_child(continue_btn)

	set_process(true)


func _process(delta: float) -> void:
	elapsed_time += delta
	if elapsed_time >= display_time:
		_close()


func _on_continue() -> void:
	_close()


func _close() -> void:
	var main_game = get_tree().root.get_child(0)
	main_game.show_screen("world")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_on_continue()
