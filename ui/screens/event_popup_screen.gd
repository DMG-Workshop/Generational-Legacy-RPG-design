## Event popup screen: display events and consequences
##
## Shows quest offers, marriage proposals, betrayals, achievements, etc.

extends Control

class_name EventPopupScreen


var current_event: Dictionary = {}


func _ready() -> void:
	# Semi-transparent overlay
	var overlay = ColorRect.new()
	overlay.color = Color.BLACK.with_alpha(0.7)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	add_child(overlay)

	# Event popup panel
	var popup = PanelContainer.new()
	popup.anchor_left = 0.25
	popup.anchor_top = 0.25
	popup.anchor_right = 0.75
	popup.anchor_bottom = 0.75
	add_child(popup)

	var vbox = VBoxContainer.new()
	popup.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Event!"
	title.add_theme_font_size_override("font_size", 24)
	title.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Event description
	var description = TextEdit.new()
	description.text = "A stranger approaches you with an offer..."
	description.editable = false
	description.custom_minimum_size = Vector2(0, 150)
	vbox.add_child(description)

	# Consequences/choices
	var choices_label = Label.new()
	choices_label.text = "What do you do?"
	vbox.add_child(choices_label)

	var choices_hbox = HBoxContainer.new()
	vbox.add_child(choices_hbox)

	var accept_btn = Button.new()
	accept_btn.text = "Accept"
	accept_btn.pressed.connect(_on_accept)
	choices_hbox.add_child(accept_btn)

	var decline_btn = Button.new()
	decline_btn.text = "Decline"
	decline_btn.pressed.connect(_on_decline)
	choices_hbox.add_child(decline_btn)

	var ignore_btn = Button.new()
	ignore_btn.text = "Ignore"
	ignore_btn.pressed.connect(_on_ignore)
	choices_hbox.add_child(ignore_btn)


## Populate with actual event data
func set_event(event: Dictionary) -> void:
	current_event = event

	# Update UI based on event type
	match event.get("event_type", ""):
		"quest":
			_show_quest_event(event)
		"marriage":
			_show_marriage_event(event)
		"betrayal":
			_show_betrayal_event(event)
		"success":
			_show_success_event(event)
		"death":
			_show_death_event(event)
		_:
			_show_generic_event(event)


func _show_quest_event(event: Dictionary) -> void:
	print("Quest event: %s" % event)


func _show_marriage_event(event: Dictionary) -> void:
	print("Marriage event: %s" % event)


func _show_betrayal_event(event: Dictionary) -> void:
	print("Betrayal event: %s" % event)


func _show_success_event(event: Dictionary) -> void:
	print("Success event: %s" % event)


func _show_death_event(event: Dictionary) -> void:
	print("Death event: %s" % event)


func _show_generic_event(event: Dictionary) -> void:
	print("Generic event: %s" % event)


func _on_accept() -> void:
	print("Accepted event")
	current_event["accepted"] = true
	_close_event()


func _on_decline() -> void:
	print("Declined event")
	current_event["accepted"] = false
	_close_event()


func _on_ignore() -> void:
	print("Ignored event")
	current_event["ignored"] = true
	_close_event()


func _close_event() -> void:
	var main_game = get_tree().root.get_child(0)
	main_game.show_screen("year_action")
