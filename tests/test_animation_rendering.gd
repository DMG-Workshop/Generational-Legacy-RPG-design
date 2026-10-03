## Tests for Animation Rendering System
##
## Tests: AnimationRenderer, BattleScreenAnimator, BattleManagerAnimated

extends GutTest


var combat_animator: CombatAnimator
var animation_renderer: AnimationRenderer
var battle_screen_animator: BattleScreenAnimator
var battle_manager_animated: BattleManagerAnimated

var test_party: Array[Battle.Combatant]
var test_enemies: Array[Battle.Combatant]
var test_battle_screen: BattleScreen


func before_each() -> void:
	combat_animator = CombatAnimator.new()
	animation_renderer = AnimationRenderer.new(combat_animator)

	_setup_test_combatants()
	_setup_test_battle()

	test_battle_screen = BattleScreen.new()
	test_battle_screen.battle = Battle.new()

	battle_screen_animator = BattleScreenAnimator.new(combat_animator, test_battle_screen)
	battle_manager_animated = BattleManagerAnimated.new()


func _setup_test_combatants() -> void:
	test_party = []
	test_enemies = []

	var hero = Battle.Combatant.new()
	hero.name = "Hero"
	hero.faction = "party"
	hero.hp = 100
	hero.max_hp = 100
	hero.mp = 50
	hero.max_mp = 50
	hero.is_alive = true
	test_party.append(hero)

	var goblin = Battle.Combatant.new()
	goblin.name = "Goblin"
	goblin.faction = "enemy"
	goblin.hp = 50
	goblin.max_hp = 50
	goblin.is_alive = true
	test_enemies.append(goblin)


func _setup_test_battle() -> void:
	pass


## Test: AnimationRenderer initialization
func test_animation_renderer_init() -> void:
	assert_not_null(animation_renderer)
	assert_eq(animation_renderer.combat_animator, combat_animator)


## Test: AnimationRenderer render damage popups
func test_animation_renderer_damage_popups() -> void:
	combat_animator.queue_damage_popup(25, Vector2(100, 100), false, false)

	var rendered = animation_renderer.render_damage_popups()
	assert_eq(rendered.size(), 1)
	assert_eq(rendered[0].get("text"), "25")


## Test: AnimationRenderer damage popup with critical
func test_animation_renderer_critical_popup() -> void:
	combat_animator.queue_damage_popup(50, Vector2(100, 100), true, false)

	var rendered = animation_renderer.render_damage_popups()
	assert_eq(rendered[0].get("is_critical"), true)
	assert_eq(rendered[0].get("text"), "50!")


## Test: AnimationRenderer healing popup
func test_animation_renderer_healing_popup() -> void:
	combat_animator.queue_damage_popup(20, Vector2(100, 100), false, true)

	var rendered = animation_renderer.render_damage_popups()
	assert_true(rendered[0].get("text").contains("+"))
	assert_eq(rendered[0].get("is_healing"), true)


## Test: AnimationRenderer health bar rendering
func test_animation_renderer_health_bar() -> void:
	combat_animator.register_combatant(test_party[0])
	combat_animator.animate_health_change(test_party[0], 75)

	var rendered = animation_renderer.render_health_bar(test_party[0])
	assert_eq(rendered.get("combatant"), "Hero")
	assert_gt(rendered.get("fill", 0), 0.7)


## Test: AnimationRenderer turn highlight rendering
func test_animation_renderer_turn_highlight() -> void:
	combat_animator.highlight_turn(test_party[0])

	var rendered = animation_renderer.render_turn_highlight()
	assert_eq(rendered.get("character"), test_party[0])


## Test: AnimationRenderer status effects rendering
func test_animation_renderer_status_effects() -> void:
	combat_animator.register_combatant(test_enemies[0])
	combat_animator.apply_status_effect(test_enemies[0], "poison")

	var rendered = animation_renderer.render_status_effects(test_enemies[0])
	assert_eq(rendered.size(), 1)
	assert_eq(rendered[0].get("effect_name"), "poison")


## Test: BattleScreenAnimator initialization
func test_battle_screen_animator_init() -> void:
	assert_not_null(battle_screen_animator)
	assert_eq(battle_screen_animator.combat_animator, combat_animator)
	assert_not_null(battle_screen_animator.animation_renderer)


## Test: BattleScreenAnimator register party node
func test_battle_screen_animator_register_party() -> void:
	var node = Control.new()
	battle_screen_animator.register_party_node(0, node)

	assert_eq(battle_screen_animator.party_display_nodes.size(), 1)
	assert_eq(battle_screen_animator.party_display_nodes[0], node)


## Test: BattleScreenAnimator register enemy node
func test_battle_screen_animator_register_enemy() -> void:
	var node = Control.new()
	battle_screen_animator.register_enemy_node(0, node)

	assert_eq(battle_screen_animator.enemy_display_nodes.size(), 1)
	assert_eq(battle_screen_animator.enemy_display_nodes[0], node)


## Test: BattleScreenAnimator set turn indicator
func test_battle_screen_animator_turn_indicator() -> void:
	var node = Control.new()
	battle_screen_animator.set_turn_indicator(node)

	assert_eq(battle_screen_animator.turn_indicator_node, node)


## Test: BattleScreenAnimator set damage popup layer
func test_battle_screen_animator_popup_layer() -> void:
	var node = Control.new()
	battle_screen_animator.set_damage_popup_layer(node)

	assert_eq(battle_screen_animator.damage_popup_layer, node)


## Test: BattleScreenAnimator update animations
func test_battle_screen_animator_update() -> void:
	combat_animator.queue_damage_popup(25, Vector2(100, 100))

	battle_screen_animator.update_animations(0.1)
	assert_true(battle_screen_animator.has_active_animations())


## Test: BattleScreenAnimator show damage
func test_battle_screen_animator_show_damage() -> void:
	battle_screen_animator.show_damage(25, Vector2(100, 100))

	assert_eq(combat_animator.damage_popups.size(), 1)


## Test: BattleScreenAnimator show healing
func test_battle_screen_animator_show_healing() -> void:
	battle_screen_animator.show_healing(20, Vector2(100, 100))

	assert_eq(combat_animator.damage_popups.size(), 1)
	assert_true(combat_animator.damage_popups[0].is_healing)


## Test: BattleScreenAnimator highlight turn
func test_battle_screen_animator_highlight_turn() -> void:
	battle_screen_animator.highlight_character_turn(test_party[0])

	assert_eq(battle_screen_animator.combat_animator.turn_animator.current_character, test_party[0])


## Test: BattleScreenAnimator animate health
func test_battle_screen_animator_animate_health() -> void:
	combat_animator.register_combatant(test_party[0])
	battle_screen_animator.animate_health_change(test_party[0], 75)

	var animator = combat_animator.get_health_animator(test_party[0])
	assert_true(animator.is_animating)


## Test: BattleScreenAnimator show status effect
func test_battle_screen_animator_show_effect() -> void:
	combat_animator.register_combatant(test_enemies[0])
	battle_screen_animator.show_status_effect(test_enemies[0], "poison")

	var effects = combat_animator.get_status_animators(test_enemies[0])
	assert_gt(effects.size(), 0)


## Test: BattleScreenAnimator get render data
func test_battle_screen_animator_render_data() -> void:
	combat_animator.queue_damage_popup(25, Vector2(100, 100))

	var data = battle_screen_animator.get_render_data()
	assert_true("damage_popups" in data)
	assert_true("turn_highlight" in data)


## Test: BattleManagerAnimated initialization
func test_battle_manager_animated_init() -> void:
	assert_not_null(battle_manager_animated)


## Test: BattleManagerAnimated start battle with animations
func test_battle_manager_animated_start_battle() -> void:
	battle_manager_animated.start_battle_animated(test_party, test_enemies, battle_screen_animator)

	assert_true(battle_manager_animated.battle_in_progress)
	assert_eq(test_party[0] in battle_screen_animator.combat_animator.health_animators, true)


## Test: BattleManagerAnimated gets ability type
func test_battle_manager_animated_ability_type() -> void:
	var attack_type = battle_manager_animated._get_ability_type("attack")
	var spell_type = battle_manager_animated._get_ability_type("cast_spell")
	var heal_type = battle_manager_animated._get_ability_type("use_item")

	assert_eq(attack_type, AbilityAnimator.AbilityType.ATTACK)
	assert_eq(spell_type, AbilityAnimator.AbilityType.SPELL)
	assert_eq(heal_type, AbilityAnimator.AbilityType.UTILITY)


## Test: Multiple popups simultaneous rendering
func test_animation_renderer_multiple_popups() -> void:
	combat_animator.queue_damage_popup(25, Vector2(100, 100), false, false)
	combat_animator.queue_damage_popup(50, Vector2(150, 150), true, false)
	combat_animator.queue_damage_popup(15, Vector2(120, 120), false, true)

	var rendered = animation_renderer.render_damage_popups()
	assert_eq(rendered.size(), 3)


## Test: Popup cleanup after animation
func test_animation_renderer_popup_cleanup() -> void:
	combat_animator.queue_damage_popup(25, Vector2(100, 100))
	assert_eq(combat_animator.damage_popups.size(), 1)

	combat_animator.update(2.0)  # More than animation duration
	assert_eq(combat_animator.damage_popups.size(), 0)


## Test: Health bar color transitions
func test_animation_renderer_health_bar_colors() -> void:
	combat_animator.register_combatant(test_party[0])

	# Full health - should be green
	combat_animator.animate_health_change(test_party[0], 100)
	var full_render = animation_renderer.render_health_bar(test_party[0])
	var full_color = full_render.get("color")

	# Half health - should be yellow
	combat_animator.animate_health_change(test_party[0], 50)
	combat_animator.update(0.5)
	var half_render = animation_renderer.render_health_bar(test_party[0])
	var half_color = half_render.get("color")

	# Critical health - should be red
	combat_animator.animate_health_change(test_party[0], 20)
	combat_animator.update(0.5)
	var crit_render = animation_renderer.render_health_bar(test_party[0])
	var crit_color = crit_render.get("color")

	assert_ne(full_color, half_color)
	assert_ne(half_color, crit_color)


## Test: Turn highlight with multiple characters
func test_animation_renderer_turn_sequence() -> void:
	combat_animator.highlight_turn(test_party[0])
	var first_render = animation_renderer.render_turn_highlight()
	assert_eq(first_render.get("character"), test_party[0])

	combat_animator.highlight_turn(test_enemies[0])
	var second_render = animation_renderer.render_turn_highlight()
	assert_eq(second_render.get("character"), test_enemies[0])


## Test: Full render data structure
func test_animation_renderer_full_render_data() -> void:
	combat_animator.queue_damage_popup(25, Vector2(100, 100))
	combat_animator.register_combatant(test_party[0])
	combat_animator.highlight_turn(test_party[0])

	var data = animation_renderer.get_full_render_data()
	assert_true("damage_popups" in data)
	assert_true("turn_highlight" in data)
	assert_true("has_active" in data)

	assert_gt(data.get("damage_popups", []).size(), 0)
	assert_not_null(data.get("turn_highlight"))
