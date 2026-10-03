## Dialogue tree screen: displays interactive dialogue conversations
##
## Shows NPC dialogue with branching choices, handles player selections,
## and applies dialogue outcomes to the heir's state.

extends Control

class_name DialogueTreeScreen


var dialogue_system: DialogueSystem
var current_tree_key: String
var current_node: DialogueSystem.DialogueNode
var heir: Heir
var main_game: Node

var speaker_label: Label
var dialogue_text: Label
var choices_container: VBoxContainer
var continue_button: Button


func _init(p_dialogue_system: DialogueSystem, tree_key: String, p_heir: Heir) -> void:
	dialogue_system = p_dialogue_system
	current_tree_key = tree_key
	current_node = dialogue_system.get_dialogue(tree_key)
	heir = p_heir


func _ready() -> void:
	# Background overlay
	var bg = ColorRect.new()
	bg.color = Color.BLACK.with_alpha(0.7)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Main panel
	var panel = PanelContainer.new()
	panel.anchor_left = 0.1
	panel.anchor_top = 0.2
	panel.anchor_right = 0.9
	panel.anchor_bottom = 0.9
	add_child(panel)

	var main_vbox = VBoxContainer.new()
	panel.add_child(main_vbox)
	main_vbox.add_theme_constant_override("separation", 10)

	# Speaker label
	speaker_label = Label.new()
	speaker_label.text = ""
	speaker_label.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(speaker_label)

	# Dialogue text
	dialogue_text = Label.new()
	dialogue_text.text = ""
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	dialogue_text.custom_minimum_size = Vector2(0, 150)
	main_vbox.add_child(dialogue_text)

	# Choices container
	choices_container = VBoxContainer.new()
	choices_container.add_theme_constant_override("separation", 5)
	main_vbox.add_child(choices_container)

	# Continue button (shown when dialogue ends)
	continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.pressed.connect(_on_continue)
	continue_button.visible = false
	main_vbox.add_child(continue_button)

	# Display initial dialogue
	_show_node(current_node)


func _show_node(node: DialogueSystem.DialogueNode) -> void:
	if node == null:
		_on_dialogue_end()
		return

	current_node = node

	# Update speaker and text
	speaker_label.text = node.speaker
	dialogue_text.text = node.text

	# Clear old choices
	for child in choices_container.get_children():
		child.queue_free()

	# Show choices or continue button
	var choices = dialogue_system.get_choices(node)
	if choices.size() > 0:
		for choice in choices:
			var choice_button = Button.new()
			choice_button.text = choice.text
			choice_button.pressed.connect(_on_choice_selected.bind(choice))
			choices_container.add_child(choice_button)
		continue_button.visible = false
	else:
		continue_button.visible = true


func _on_choice_selected(choice: DialogueSystem.DialogueChoice) -> void:
	# Apply immediate outcomes from this choice
	if choice.outcome.size() > 0:
		var result = dialogue_system.apply_outcome(choice.outcome, heir)
		# TODO: Display outcome to player (gold gained, reputation gained, quest started)

	# Navigate to next node
	var next_node = dialogue_system.get_next_node(current_tree_key, choice.next_node)
	if next_node:
		_show_node(next_node)
	else:
		_on_dialogue_end()


func _on_continue() -> void:
	_on_dialogue_end()


func _on_dialogue_end() -> void:
	main_game = get_tree().root.get_child(0)
	main_game.show_screen("world")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_dialogue_end()
