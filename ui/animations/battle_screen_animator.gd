## Battle Screen Animator: Integrates animations into battle display
##
## Updates BattleScreen display based on CombatAnimator state
## Handles real-time animation rendering during combat

class_name BattleScreenAnimator


var combat_animator: CombatAnimator = null
var animation_renderer: AnimationRenderer = null
var battle_screen: BattleScreen = null

# Animation update timing
var last_update: float = 0.0
var update_interval: float = 0.016  # ~60 FPS

# Visual references
var party_display_nodes: Array[Control] = []
var enemy_display_nodes: Array[Control] = []
var turn_indicator_node: Control = null
var damage_popup_layer: Control = null


func _init(animator: CombatAnimator, screen: BattleScreen) -> void:
	combat_animator = animator
	battle_screen = screen
	animation_renderer = AnimationRenderer.new(animator)
	animation_renderer.set_render_targets(screen)


## Register visual nodes for animation updates
func register_party_node(index: int, node: Control) -> void:
	while party_display_nodes.size() <= index:
		party_display_nodes.append(null)
	party_display_nodes[index] = node


func register_enemy_node(index: int, node: Control) -> void:
	while enemy_display_nodes.size() <= index:
		enemy_display_nodes.append(null)
	enemy_display_nodes[index] = node


func set_turn_indicator(node: Control) -> void:
	turn_indicator_node = node


func set_damage_popup_layer(layer: Control) -> void:
	damage_popup_layer = layer


## Update all animations (call from _process)
func update_animations(delta: float) -> void:
	combat_animator.update(delta)

	# Update visual displays
	_update_health_bars()
	_update_turn_highlight()
	_update_damage_popups()
	_update_status_effects()


## Update all health bar displays
func _update_health_bars() -> void:
	var state = battle_screen.battle.state if battle_screen and battle_screen.battle else null
	if not state:
		return

	# Update party health bars
	for i in range(state.party.size()):
		if i < party_display_nodes.size() and party_display_nodes[i]:
			animation_renderer.update_health_bar_display(state.party[i], party_display_nodes[i])

	# Update enemy health bars
	for i in range(state.enemies.size()):
		if i < enemy_display_nodes.size() and enemy_display_nodes[i]:
			animation_renderer.update_health_bar_display(state.enemies[i], enemy_display_nodes[i])


## Update turn highlight
func _update_turn_highlight() -> void:
	if turn_indicator_node:
		animation_renderer.update_turn_indicator(turn_indicator_node)


## Render and display damage popups
func _update_damage_popups() -> void:
	if not damage_popup_layer:
		return

	var popup_data = animation_renderer.render_damage_popups()

	# Update or create popup display nodes
	var child_index = 0
	for data in popup_data:
		var popup_node = _get_or_create_popup_node(child_index)
		_render_popup_to_node(popup_node, data)
		child_index += 1

	# Remove extra popup nodes
	while damage_popup_layer.get_child_count() > child_index:
		damage_popup_layer.get_child(-1).queue_free()


## Create popup display node if needed
func _get_or_create_popup_node(index: int) -> Control:
	if index < damage_popup_layer.get_child_count():
		return damage_popup_layer.get_child(index)

	var popup_node = Control.new()
	popup_node.custom_minimum_size = Vector2(100, 40)
	damage_popup_layer.add_child(popup_node)
	return popup_node


## Render popup data to visual node
func _render_popup_to_node(node: Control, data: Dictionary) -> void:
	node.position = data.get("position", Vector2.ZERO)
	node.scale = Vector2.ONE * data.get("scale", 1.0)
	node.modulate = data.get("color", Color.WHITE)
	node.modulate.a = data.get("opacity", 1.0)


## Update status effect displays
func _update_status_effects() -> void:
	var state = battle_screen.battle.state if battle_screen and battle_screen.battle else null
	if not state:
		return

	# Update status effects for party
	for party_member in state.party:
		# This would update status effect icons if they exist
		pass

	# Update status effects for enemies
	for enemy in state.enemies:
		# This would update status effect icons if they exist
		pass


## Get all active animation data for rendering
func get_render_data() -> Dictionary:
	return animation_renderer.get_full_render_data()


## Check if animations are still playing
func has_active_animations() -> bool:
	return combat_animator.has_active_animations()


## Trigger damage animation
func show_damage(damage: int, position: Vector2, is_critical: bool = false) -> void:
	combat_animator.queue_damage_popup(damage, position, is_critical, false)


## Trigger healing animation
func show_healing(amount: int, position: Vector2) -> void:
	combat_animator.queue_damage_popup(amount, position, false, true)


## Highlight character turn
func highlight_character_turn(character: Battle.Combatant) -> void:
	combat_animator.highlight_turn(character)


## Animate health change
func animate_health_change(combatant: Battle.Combatant, new_health: float) -> void:
	combat_animator.animate_health_change(combatant, new_health)


## Show status effect
func show_status_effect(combatant: Battle.Combatant, effect_name: String) -> void:
	combat_animator.apply_status_effect(combatant, effect_name)
