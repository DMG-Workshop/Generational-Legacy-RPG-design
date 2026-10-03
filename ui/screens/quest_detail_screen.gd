## Quest detail screen: shows quest information before acceptance
##
## Displays quest rewards, difficulty, location, and description.
## Allows player to accept or decline the quest.

extends Control

class_name QuestDetailScreen


var quest_data: Dictionary
var heir: Heir
var main_game: Node
var on_quest_accepted: Callable
var on_quest_declined: Callable


func _init(p_quest_data: Dictionary, p_heir: Heir) -> void:
	quest_data = p_quest_data
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
	panel.anchor_left = 0.15
	panel.anchor_top = 0.1
	panel.anchor_right = 0.85
	panel.anchor_bottom = 0.9
	add_child(panel)

	var main_vbox = VBoxContainer.new()
	panel.add_child(main_vbox)
	main_vbox.add_theme_constant_override("separation", 15)

	# Title
	var title = Label.new()
	title.text = quest_data.get("quest_type", "Unknown Quest").to_upper()
	title.add_theme_font_size_override("font_size", 24)
	main_vbox.add_child(title)

	# Description
	var desc_label = Label.new()
	desc_label.text = "Objective:"
	desc_label.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(desc_label)

	var desc_text = Label.new()
	desc_text.text = _build_description()
	desc_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_text.custom_minimum_size = Vector2(0, 80)
	main_vbox.add_child(desc_text)

	# Details grid
	var details_grid = GridContainer.new()
	details_grid.columns = 2
	details_grid.add_theme_constant_override("h_separation", 20)
	details_grid.add_theme_constant_override("v_separation", 10)
	main_vbox.add_child(details_grid)

	# Location
	var loc_label = Label.new()
	loc_label.text = "Location:"
	loc_label.add_theme_font_size_override("font_size", 12)
	details_grid.add_child(loc_label)

	var loc_value = Label.new()
	loc_value.text = quest_data.get("location", "Unknown")
	loc_value.add_theme_font_size_override("font_size", 12)
	details_grid.add_child(loc_value)

	# Difficulty
	var diff_label = Label.new()
	diff_label.text = "Difficulty:"
	diff_label.add_theme_font_size_override("font_size", 12)
	details_grid.add_child(diff_label)

	var diff_value = Label.new()
	var difficulty_str = _get_difficulty_text(quest_data.get("difficulty", 1))
	diff_value.text = difficulty_str
	diff_value.add_theme_font_size_override("font_size", 12)
	details_grid.add_child(diff_value)

	# Rewards section
	var rewards_label = Label.new()
	rewards_label.text = "Rewards:"
	rewards_label.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(rewards_label)

	var rewards_grid = GridContainer.new()
	rewards_grid.columns = 2
	rewards_grid.add_theme_constant_override("h_separation", 20)
	rewards_grid.add_theme_constant_override("v_separation", 8)
	main_vbox.add_child(rewards_grid)

	# Gold reward
	var gold_label = Label.new()
	gold_label.text = "Gold:"
	rewards_grid.add_child(gold_label)

	var gold_value = Label.new()
	gold_value.text = "%d" % quest_data.get("reward_gold", 0)
	rewards_grid.add_child(gold_value)

	# Reputation reward
	var rep_label = Label.new()
	rep_label.text = "Reputation:"
	rewards_grid.add_child(rep_label)

	var rep_value = Label.new()
	rep_value.text = "+%d" % quest_data.get("reward_reputation", 0)
	rewards_grid.add_child(rep_value)

	# Trait reward (if any)
	if quest_data.has("reward_trait"):
		var trait_label = Label.new()
		trait_label.text = "Trait:"
		rewards_grid.add_child(trait_label)

		var trait_value = Label.new()
		trait_value.text = quest_data["reward_trait"]
		rewards_grid.add_child(trait_value)

	# Action buttons
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(button_hbox)

	var decline_btn = Button.new()
	decline_btn.text = "Decline"
	decline_btn.custom_minimum_size = Vector2(100, 40)
	decline_btn.pressed.connect(_on_decline)
	button_hbox.add_child(decline_btn)

	var accept_btn = Button.new()
	accept_btn.text = "Accept Quest"
	accept_btn.custom_minimum_size = Vector2(150, 40)
	accept_btn.pressed.connect(_on_accept)
	button_hbox.add_child(accept_btn)


func _build_description() -> String:
	match quest_data.get("quest_type", ""):
		"hunt":
			return "Slay the %s in %s. The beast has been terrorizing the area." % [
				quest_data.get("target", "beast"),
				quest_data.get("location", "the wilds")
			]
		"retrieve":
			return "Recover the %s from %s. It was stolen and must be returned." % [
				quest_data.get("target", "artifact"),
				quest_data.get("location", "the catacombs")
			]
		"escort":
			return "Protect the %s on the journey to %s. Ensure safe passage through dangerous roads." % [
				quest_data.get("target", "caravan"),
				quest_data.get("location", "the capital")
			]
		_:
			return "Complete this quest objective and claim your rewards."


func _get_difficulty_text(difficulty: int) -> String:
	match difficulty:
		1:
			return "Easy ★"
		2:
			return "Medium ★★"
		3:
			return "Hard ★★★"
		_:
			return "Unknown"


func _on_accept() -> void:
	if on_quest_accepted.is_valid():
		on_quest_accepted.call()
	_close()


func _on_decline() -> void:
	if on_quest_declined.is_valid():
		on_quest_declined.call()
	_close()


func _close() -> void:
	main_game = get_tree().root.get_child(0)
	main_game.show_screen("world")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_decline()
