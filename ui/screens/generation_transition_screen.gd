## Generation transition screen: shows life summary and heir selection
##
## Displays summary of completed heir's life, their children, and allows heir selection

extends Control

class_name GenerationTransitionScreen


var generation_manager: GenerationManager


func _init(gen_manager: GenerationManager) -> void:
	generation_manager = gen_manager


func _ready() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color.BLACK
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Main scroll container
	var scroll = ScrollContainer.new()
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	add_child(scroll)

	var main_vbox = VBoxContainer.new()
	scroll.add_child(main_vbox)

	# Title
	var title = Label.new()
	title.text = "Generation %d Complete" % generation_manager.current_heir.generation
	title.add_theme_font_size_override("font_size", 28)
	main_vbox.add_child(title)

	# Life summary
	var summary = generation_manager.get_life_summary()

	var summary_panel = PanelContainer.new()
	var summary_vbox = VBoxContainer.new()
	summary_panel.add_child(summary_vbox)
	main_vbox.add_child(summary_panel)

	var heir_name = Label.new()
	heir_name.text = summary["heir"]
	heir_name.add_theme_font_size_override("font_size", 24)
	summary_vbox.add_child(heir_name)

	var life_info = Label.new()
	life_info.text = "Lived %d years, from age %d to %d" % [
		summary["age"],
		summary.get("birth_age", 0),
		summary["age"]
	]
	summary_vbox.add_child(life_info)

	var children_info = Label.new()
	children_info.text = "Had %d children" % summary["children"]
	summary_vbox.add_child(children_info)

	var wealth_info = Label.new()
	wealth_info.text = "Accumulated wealth: %d" % summary.get("wealth", 0)
	summary_vbox.add_child(wealth_info)

	var accomplishments = Label.new()
	accomplishments.text = "Accomplishments:\n- Completed %d quests\n- Learned %d skills\n- Made %d allies" % [
		summary.get("quests", 0),
		summary.get("skills", 0),
		summary.get("allies", 0)
	]
	accomplishments.custom_minimum_size = Vector2(0, 80)
	accomplishments.autowrap_mode = TextServer.AUTOWRAP_WORD
	summary_vbox.add_child(accomplishments)

	# Legacy echo section
	var legacy_label = Label.new()
	legacy_label.text = "Legacy & Reputation"
	legacy_label.add_theme_font_size_override("font_size", 14)
	summary_vbox.add_child(legacy_label)

	var reputation_text = Label.new()
	reputation_text.text = "Final Reputation: %d\n\nYour deeds will be remembered:\n- Legendary warrior of the realm\n- Master strategist and leader\n- Protector of the weak" % summary.get("reputation", 0)
	reputation_text.custom_minimum_size = Vector2(0, 100)
	reputation_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	reputation_text.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	summary_vbox.add_child(reputation_text)

	# Heir selection
	var selection_title = Label.new()
	selection_title.text = "Choose Next Heir"
	selection_title.add_theme_font_size_override("font_size", 20)
	main_vbox.add_child(selection_title)

	# Children buttons
	var children = generation_manager.children
	if children.is_empty():
		var no_children = Label.new()
		no_children.text = "No children to inherit. Game Over."
		main_vbox.add_child(no_children)
	else:
		var children_container = VBoxContainer.new()
		for child in children:
			var child_btn = _create_child_button(child)
			children_container.add_child(child_btn)
		main_vbox.add_child(children_container)

	# Mentor selection (optional)
	var mentor_info = Label.new()
	mentor_info.text = "Optional: Choose a mentor from your ancestors"
	mentor_info.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(mentor_info)

	var mentor_container = VBoxContainer.new()
	var recent_ancestors = generation_manager.npc_system.get_recent_ancestors(
		generation_manager.current_heir.generation,
		5
	)

	for ancestor in recent_ancestors:
		var ancestor_panel = PanelContainer.new()
		var ancestor_vbox = VBoxContainer.new()
		ancestor_panel.add_child(ancestor_vbox)

		# Ancestor name and generation
		var ancestor_name = Label.new()
		ancestor_name.text = "%s (Gen %d)" % [ancestor.heir.name, ancestor.generation]
		ancestor_name.add_theme_font_size_override("font_size", 12)
		ancestor_vbox.add_child(ancestor_name)

		# Wisdom and personality
		var wisdom_label = Label.new()
		wisdom_label.text = "Wisdom: %d" % ancestor.wisdom
		wisdom_label.add_theme_font_size_override("font_size", 11)
		ancestor_vbox.add_child(wisdom_label)

		var personality_label = Label.new()
		personality_label.text = "Personality: %s" % ancestor.personality
		personality_label.add_theme_font_size_override("font_size", 11)
		ancestor_vbox.add_child(personality_label)

		# Mentor bonuses preview
		var bonus_label = Label.new()
		bonus_label.text = "Mentor Bonuses:\n+%d XP/Level, +%d Reputation" % [
			ancestor.wisdom * 5,
			ancestor.wisdom * 2
		]
		bonus_label.add_theme_font_size_override("font_size", 10)
		bonus_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
		bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		ancestor_vbox.add_child(bonus_label)

		# Select button
		var select_btn = Button.new()
		select_btn.text = "Choose as Mentor"
		select_btn.pressed.connect(_on_mentor_selected.bind(ancestor))
		ancestor_vbox.add_child(select_btn)

		mentor_container.add_child(ancestor_panel)

	if recent_ancestors.is_empty():
		var no_ancestors = Label.new()
		no_ancestors.text = "No ancestors to consult"
		mentor_container.add_child(no_ancestors)

	main_vbox.add_child(mentor_container)


func _create_child_button(child: Heir) -> Control:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)

	# Child name and class
	var name_label = Label.new()
	name_label.text = "%s (%s %s)" % [child.name, child.class_id, child.job_id]
	name_label.add_theme_font_size_override("font_size", 14)
	container.add_child(name_label)

	# Traits
	var traits_label = Label.new()
	traits_label.text = "Traits: %s" % ", ".join(child.traits)
	traits_label.add_theme_font_size_override("font_size", 12)
	traits_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	container.add_child(traits_label)

	# Stats preview
	var stats_label = Label.new()
	stats_label.text = "STR:%d CON:%d DEX:%d INT:%d WIS:%d CHA:%d" % [
		child.strength,
		child.constitution,
		child.dexterity,
		child.intelligence,
		child.wisdom,
		child.charisma
	]
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", Color.YELLOW)
	container.add_child(stats_label)

	# Select button
	var select_btn = Button.new()
	select_btn.text = "Select as Heir"
	select_btn.custom_minimum_size = Vector2(150, 30)
	select_btn.pressed.connect(_on_child_selected.bind(child))
	container.add_child(select_btn)

	# Separator
	var separator = HSeparator.new()
	container.add_child(separator)

	return container


func _on_child_selected(child: Heir) -> void:
	var result = generation_manager.transition_to_heir(child)
	if result["success"]:
		print("Transitioned to heir: %s" % child.name)
		var main_game = get_tree().root.get_child(0)
		main_game.show_screen("world")
	else:
		print("Failed to transition: %s" % result.get("reason", "Unknown error"))


func _on_mentor_selected(ancestor: GenerationManager.NPCSystem.NPCAncestor) -> void:
	print("Selected mentor: %s (Wisdom %d)" % [ancestor.heir.name, ancestor.wisdom])
	# TODO: Apply mentor bonuses to next heir
