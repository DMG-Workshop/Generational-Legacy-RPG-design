## Animation Renderer: Renders CombatAnimator output to screen
##
## Converts animation data (positions, opacities, scales, colors) into visual effects
## Handles damage popups, health bar updates, turn highlights, and status effects

class_name AnimationRenderer


var combat_animator: CombatAnimator = null
var viewport_size: Vector2 = Vector2(1280, 720)

# Rendering targets
var battle_screen: BattleScreen = null
var combat_log: CombatLog = null

# Visual settings
var damage_font_size: int = 24
var damage_font_bold: bool = true
var popup_shadow_offset: Vector2 = Vector2(2, 2)
var popup_shadow_color: Color = Color.BLACK


func _init(animator: CombatAnimator) -> void:
	combat_animator = animator
	if animator:
		animator.all_animations_complete.connect(_on_animations_complete)


## Set rendering targets
func set_render_targets(screen: BattleScreen, log: CombatLog = null) -> void:
	battle_screen = screen
	combat_log = log


## Render all active damage popups
func render_damage_popups() -> Array[Dictionary]:
	var rendered_popups = []

	for popup in combat_animator.get_active_popups():
		var render_data = {
			"text": popup.get_display_text(),
			"position": popup.start_position + popup.position_offset,
			"color": popup.get_color(),
			"opacity": popup.start_opacity,
			"scale": popup.get_scale(),
			"is_critical": popup.is_critical,
			"is_healing": popup.is_healing,
		}
		rendered_popups.append(render_data)

	return rendered_popups


## Render health bar for combatant
func render_health_bar(combatant: Battle.Combatant) -> Dictionary:
	var animator = combat_animator.get_health_animator(combatant)
	if not animator:
		return {}

	return {
		"combatant": combatant.name,
		"fill": animator.get_fill_percentage(),
		"color": animator.get_bar_color(),
		"background_color": animator.get_background_color(),
		"flash_intensity": animator.get_flash_intensity(),
		"is_critical": animator.is_critical_health(),
	}


## Render turn highlight effect
func render_turn_highlight() -> Dictionary:
	var animator = combat_animator.get_turn_animator()

	return {
		"character": animator.current_character,
		"highlight_intensity": animator.get_highlight_intensity(),
		"highlight_color": animator.get_turn_indicator_color(),
		"previous_fade": animator.get_previous_fade(),
		"round_flash": animator.get_round_flash(),
	}


## Render status effects for combatant
func render_status_effects(combatant: Battle.Combatant) -> Array[Dictionary]:
	var rendered_effects = []
	var animators = combat_animator.get_status_animators(combatant)

	for animator in animators:
		var render_data = {
			"effect_name": animator.effect_name,
			"opacity": animator.get_opacity(),
			"scale": animator.get_scale(),
			"rotation": animator.get_rotation(),
			"color": animator.get_color(),
			"glow_intensity": animator.get_glow_intensity(),
			"is_negative": animator.is_negative_effect(),
		}
		rendered_effects.append(render_data)

	return rendered_effects


## Update health bar display
func update_health_bar_display(combatant: Battle.Combatant, health_bar_node: Control = null) -> void:
	if not health_bar_node:
		return

	var render_data = render_health_bar(combatant)
	if render_data.is_empty():
		return

	# Update progress bar (assuming it's a ProgressBar node)
	if "fill" in render_data:
		health_bar_node.value = render_data["fill"] * 100

	# Update color (assuming there's a modulate property)
	if "color" in render_data and health_bar_node.has_method("set_self_modulate"):
		var flash_color = render_data["color"]
		if render_data["flash_intensity"] > 0:
			flash_color = flash_color.lerp(Color.WHITE, render_data["flash_intensity"])
		health_bar_node.set_self_modulate(flash_color)


## Update turn indicator display
func update_turn_indicator(turn_indicator_node: Control = null) -> void:
	if not turn_indicator_node:
		return

	var render_data = render_turn_highlight()
	if render_data.is_empty() or not render_data["character"]:
		return

	# Update indicator visual
	if turn_indicator_node.has_method("set_character"):
		turn_indicator_node.set_character(render_data["character"])

	# Apply pulsing effect
	if turn_indicator_node.has_method("set_intensity"):
		turn_indicator_node.set_intensity(render_data["highlight_intensity"])

	# Apply color
	if turn_indicator_node.has_method("set_self_modulate"):
		turn_indicator_node.set_self_modulate(render_data["highlight_color"])


## Update status effect icons
func update_status_effects(combatant: Battle.Combatant, effect_container: Control = null) -> void:
	if not effect_container:
		return

	var rendered_effects = render_status_effects(combatant)

	# Clear old effects
	for child in effect_container.get_children():
		child.queue_free()

	# Add new effect icons
	for effect_data in rendered_effects:
		var effect_icon = _create_effect_icon(effect_data)
		if effect_icon:
			effect_container.add_child(effect_icon)


## Create visual effect icon node
func _create_effect_icon(effect_data: Dictionary) -> Node:
	# This would be implemented with actual Node2D/Control nodes in full implementation
	# For now, returns data structure that UI can render
	return null


## Get render data for battle screen full update
func get_full_render_data() -> Dictionary:
	return {
		"damage_popups": render_damage_popups(),
		"turn_highlight": render_turn_highlight(),
		"has_active": combat_animator.has_active_animations(),
	}


## Signal when all animations complete
func _on_animations_complete() -> void:
	# Can be connected to progression logic
	pass
