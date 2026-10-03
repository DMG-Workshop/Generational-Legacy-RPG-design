## Year action screen: choose actions and advance through the year
##
## Shows available actions, age tracking, and triggers events

extends Control

class_name YearActionScreen


var generation_manager: GenerationManager
var current_year_in_life: int = 0
var available_actions: Array[String] = []


func _init(gen_manager: GenerationManager) -> void:
	generation_manager = gen_manager


func _ready() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color.BLACK
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Main panel
	var panel = PanelContainer.new()
	panel.anchor_left = 0.1
	panel.anchor_top = 0.1
	panel.anchor_right = 0.9
	panel.anchor_bottom = 0.9
	add_child(panel)

	var main_vbox = VBoxContainer.new()
	panel.add_child(main_vbox)

	# Header with age and phase info
	var header = HBoxContainer.new()
	main_vbox.add_child(header)

	var heir_label = Label.new()
	heir_label.text = "Heir: %s" % generation_manager.current_heir.name
	heir_label.add_theme_font_size_override("font_size", 20)
	header.add_child(heir_label)

	var age_label = Label.new()
	age_label.text = "Age: %d" % generation_manager.current_age
	age_label.add_theme_font_size_override("font_size", 20)
	header.add_child(age_label)

	var phase_label = Label.new()
	var phase_name = _get_phase_name(generation_manager.current_phase)
	phase_label.text = "Phase: %s" % phase_name
	phase_label.add_theme_font_size_override("font_size", 20)
	header.add_child(phase_label)

	# Life progress bar
	var progress_label = Label.new()
	progress_label.text = "Life Progress"
	main_vbox.add_child(progress_label)

	var progress_bar = ProgressBar.new()
	progress_bar.value = (generation_manager.current_age / 65.0) * 100
	progress_bar.custom_minimum_size = Vector2(0, 20)
	main_vbox.add_child(progress_bar)

	# Actions section
	var actions_label = Label.new()
	actions_label.text = "Choose an Action for This Year"
	actions_label.add_theme_font_size_override("font_size", 18)
	main_vbox.add_child(actions_label)

	# Get available actions based on life phase
	_populate_actions()

	var actions_container = VBoxContainer.new()
	for action in available_actions:
		var action_btn = Button.new()
		action_btn.text = action
		action_btn.custom_minimum_size = Vector2(0, 50)
		action_btn.pressed.connect(_on_action_selected.bind(action))
		actions_container.add_child(action_btn)

	main_vbox.add_child(actions_container)

	# Stats overview
	var stats_label = Label.new()
	stats_label.text = "Current Status"
	stats_label.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(stats_label)

	var stats_hbox = HBoxContainer.new()
	main_vbox.add_child(stats_hbox)

	var wealth_info = Label.new()
	wealth_info.text = "Wealth: %d" % generation_manager.current_wealth
	stats_hbox.add_child(wealth_info)

	var health_info = Label.new()
	health_info.text = "Health: Good"
	stats_hbox.add_child(health_info)

	var relations_info = Label.new()
	relations_info.text = "Relations: Stable"
	stats_hbox.add_child(relations_info)


func _get_phase_name(phase: int) -> String:
	match phase:
		GenerationManager.LifePhase.CHILDHOOD:
			return "Childhood (0-12)"
		GenerationManager.LifePhase.ADOLESCENCE:
			return "Adolescence (13-17)"
		GenerationManager.LifePhase.ADULTHOOD:
			return "Adulthood (18-50)"
		GenerationManager.LifePhase.ELDERHOOD:
			return "Elderhood (51-64)"
		_:
			return "Unknown"


func _populate_actions() -> void:
	match generation_manager.current_phase:
		GenerationManager.LifePhase.CHILDHOOD:
			available_actions = [
				"Study with mentor",
				"Play and explore",
				"Learn family history"
			]

		GenerationManager.LifePhase.ADOLESCENCE:
			available_actions = [
				"Train in combat",
				"Study magic",
				"Go on an adventure",
				"Help with business"
			]

		GenerationManager.LifePhase.ADULTHOOD:
			available_actions = [
				"Work on quests",
				"Build your estate",
				"Travel and explore",
				"Strengthen bonds",
				"Train disciples"
			]

		GenerationManager.LifePhase.ELDERHOOD:
			available_actions = [
				"Mentor the next heir",
				"Write your legacy",
				"Strengthen final bonds",
				"Prepare inheritance"
			]


func _on_action_selected(action: String) -> void:
	print("Action selected: %s" % action)

	# Execute year advancement
	var event = generation_manager.advance_year()

	# Show event if one occurred
	if event and event.has("event_type"):
		_show_event_popup(event)
	else:
		# Advance to next year
		queue_redraw()


func _show_event_popup(event: Dictionary) -> void:
	var main_game = get_tree().root.get_child(0)
	main_game.show_screen("event_popup")
	# TODO: Pass event data to event popup screen


## Check if heir should die this turn
func _check_for_death() -> bool:
	if generation_manager.current_age >= 65:
		return true

	# Small chance of death from fate/accident
	if randf() < 0.02:  # 2% annual death chance
		return true

	return false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			# Might need to prevent escape in this screen
			pass
