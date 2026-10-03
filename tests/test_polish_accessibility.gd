## Tests for Phase 7.9 Polish & Accessibility
##
## Tests: CombatSoundManager, AccessibilityManager, PerformanceMonitor

extends GutTest


var sound_manager: CombatSoundManager
var accessibility_manager: AccessibilityManager
var performance_monitor: PerformanceMonitor


func before_each() -> void:
	sound_manager = CombatSoundManager.new()
	accessibility_manager = AccessibilityManager.new()
	performance_monitor = PerformanceMonitor.new()


# ========== CombatSoundManager Tests ==========

## Test: Sound manager initialization
func test_sound_manager_init() -> void:
	assert_not_null(sound_manager)
	assert_true(sound_manager.is_enabled)
	assert_eq(sound_manager.master_volume, 1.0)
	assert_eq(sound_manager.combat_volume, 0.8)
	assert_eq(sound_manager.effects_volume, 0.9)


## Test: Attack sounds are loaded
func test_sound_manager_attack_sounds_loaded() -> void:
	assert_gt(sound_manager.attack_sounds.size(), 0)
	assert_true("sword_swing" in sound_manager.attack_sounds)
	assert_true("punch" in sound_manager.attack_sounds)
	assert_true("bow_shot" in sound_manager.attack_sounds)


## Test: Ability sounds are loaded
func test_sound_manager_ability_sounds_loaded() -> void:
	assert_gt(sound_manager.ability_sounds.size(), 0)
	assert_true("fireball" in sound_manager.ability_sounds)
	assert_true("ice_spike" in sound_manager.ability_sounds)
	assert_true("heal" in sound_manager.ability_sounds)


## Test: Impact sounds are loaded
func test_sound_manager_impact_sounds_loaded() -> void:
	assert_gt(sound_manager.impact_sounds.size(), 0)
	assert_true("hit" in sound_manager.impact_sounds)
	assert_true("critical_hit" in sound_manager.impact_sounds)
	assert_true("miss" in sound_manager.impact_sounds)


## Test: Status effect sounds are loaded
func test_sound_manager_status_sounds_loaded() -> void:
	assert_gt(sound_manager.status_sounds.size(), 0)
	assert_true("poison" in sound_manager.status_sounds)
	assert_true("burn" in sound_manager.status_sounds)
	assert_true("freeze" in sound_manager.status_sounds)


## Test: UI sounds are loaded
func test_sound_manager_ui_sounds_loaded() -> void:
	assert_gt(sound_manager.ui_sounds.size(), 0)
	assert_true("level_up" in sound_manager.ui_sounds)
	assert_true("victory" in sound_manager.ui_sounds)
	assert_true("defeat" in sound_manager.ui_sounds)


## Test: Play attack sound
func test_sound_manager_play_attack_sound() -> void:
	sound_manager.play_attack_sound("sword_swing")
	assert_true("sword_swing" in sound_manager.active_sounds)


## Test: Play ability sound
func test_sound_manager_play_ability_sound() -> void:
	sound_manager.play_ability_sound("fireball")
	assert_true("fireball" in sound_manager.active_sounds)


## Test: Play impact sound
func test_sound_manager_play_impact_sound() -> void:
	sound_manager.play_impact_sound("hit")
	assert_true("hit" in sound_manager.active_sounds)


## Test: Play critical hit sound
func test_sound_manager_play_critical_hit_sound() -> void:
	sound_manager.play_critical_hit_sound()
	assert_true("critical_hit" in sound_manager.active_sounds)


## Test: Play healing sound
func test_sound_manager_play_healing_sound() -> void:
	sound_manager.play_healing_sound()
	assert_true("heal" in sound_manager.active_sounds)


## Test: Play status effect sound
func test_sound_manager_play_status_sound() -> void:
	sound_manager.play_status_sound("poison")
	assert_true("poison" in sound_manager.active_sounds)


## Test: Play UI sound
func test_sound_manager_play_ui_sound() -> void:
	sound_manager.play_ui_sound("level_up")
	assert_true("level_up" in sound_manager.active_sounds)


## Test: Play damage sound (small damage)
func test_sound_manager_play_damage_sound_small() -> void:
	sound_manager.play_damage_sound(20)
	assert_true("hit" in sound_manager.active_sounds)


## Test: Play damage sound (critical damage)
func test_sound_manager_play_damage_sound_critical() -> void:
	sound_manager.play_damage_sound(75)
	assert_true("critical_hit" in sound_manager.active_sounds)


## Test: Set master volume
func test_sound_manager_set_master_volume() -> void:
	sound_manager.set_master_volume(0.5)
	assert_eq(sound_manager.master_volume, 0.5)


## Test: Set combat volume
func test_sound_manager_set_combat_volume() -> void:
	sound_manager.set_combat_volume(0.6)
	assert_eq(sound_manager.combat_volume, 0.6)


## Test: Set effects volume
func test_sound_manager_set_effects_volume() -> void:
	sound_manager.set_effects_volume(0.7)
	assert_eq(sound_manager.effects_volume, 0.7)


## Test: Volume clamping (above max)
func test_sound_manager_volume_clamp_max() -> void:
	sound_manager.set_master_volume(1.5)
	assert_eq(sound_manager.master_volume, 1.0)


## Test: Volume clamping (below min)
func test_sound_manager_volume_clamp_min() -> void:
	sound_manager.set_master_volume(-0.5)
	assert_eq(sound_manager.master_volume, 0.0)


## Test: Disable sounds
func test_sound_manager_disable() -> void:
	sound_manager.set_enabled(false)
	sound_manager.play_attack_sound("sword_swing")
	assert_eq(sound_manager.active_sounds.size(), 0)


## Test: Stop all sounds
func test_sound_manager_stop_all() -> void:
	sound_manager.play_attack_sound("sword_swing")
	sound_manager.play_ability_sound("fireball")
	assert_gt(sound_manager.active_sounds.size(), 0)

	sound_manager.stop_all()
	assert_eq(sound_manager.active_sounds.size(), 0)


## Test: Mute and unmute
func test_sound_manager_mute_unmute() -> void:
	sound_manager.set_master_volume(0.8)
	sound_manager.mute()
	assert_eq(sound_manager.master_volume, 0.0)

	sound_manager.unmute()
	assert_eq(sound_manager.master_volume, 0.5)


## Test: Check if sound exists
func test_sound_manager_has_sound() -> void:
	assert_true(sound_manager.has_sound("sword_swing"))
	assert_true(sound_manager.has_sound("fireball"))
	assert_false(sound_manager.has_sound("nonexistent_sound"))


## Test: Get active sound count
func test_sound_manager_active_count() -> void:
	assert_eq(sound_manager.get_active_sound_count(), 0)

	sound_manager.play_attack_sound("sword_swing")
	assert_eq(sound_manager.get_active_sound_count(), 1)

	sound_manager.play_ability_sound("fireball")
	assert_eq(sound_manager.get_active_sound_count(), 2)


# ========== AccessibilityManager Tests ==========

## Test: Accessibility manager initialization
func test_accessibility_manager_init() -> void:
	assert_not_null(accessibility_manager)
	assert_eq(accessibility_manager.current_color_mode, AccessibilityManager.ColorMode.NORMAL)
	assert_eq(accessibility_manager.current_font_scale, 1.0)


## Test: Set color mode to Deuteranopia
func test_accessibility_manager_set_deuteranopia() -> void:
	accessibility_manager.set_color_mode(AccessibilityManager.ColorMode.DEUTERANOPIA)
	assert_eq(accessibility_manager.current_color_mode, AccessibilityManager.ColorMode.DEUTERANOPIA)


## Test: Set color mode to Protanopia
func test_accessibility_manager_set_protanopia() -> void:
	accessibility_manager.set_color_mode(AccessibilityManager.ColorMode.PROTANOPIA)
	assert_eq(accessibility_manager.current_color_mode, AccessibilityManager.ColorMode.PROTANOPIA)


## Test: Set color mode to Tritanopia
func test_accessibility_manager_set_tritanopia() -> void:
	accessibility_manager.set_color_mode(AccessibilityManager.ColorMode.TRITANOPIA)
	assert_eq(accessibility_manager.current_color_mode, AccessibilityManager.ColorMode.TRITANOPIA)


## Test: Get color mode name
func test_accessibility_manager_get_mode_name() -> void:
	accessibility_manager.set_color_mode(AccessibilityManager.ColorMode.PROTANOPIA)
	assert_eq(accessibility_manager.get_color_mode_name(), "PROTANOPIA")


## Test: Get color in normal mode
func test_accessibility_manager_get_color_normal() -> void:
	var color = accessibility_manager.get_color("critical_hit")
	assert_eq(color, Color.RED)


## Test: Get color in Deuteranopia mode
func test_accessibility_manager_get_color_deuteranopia() -> void:
	accessibility_manager.set_color_mode(AccessibilityManager.ColorMode.DEUTERANOPIA)
	var color = accessibility_manager.get_color("critical_hit")
	assert_eq(color, Color.BLUE)


## Test: Get healing color
func test_accessibility_manager_get_healing_color() -> void:
	var color = accessibility_manager.get_color("healing")
	assert_eq(color, Color.GREEN)


## Test: Get available color modes
func test_accessibility_manager_available_modes() -> void:
	var modes = accessibility_manager.get_available_color_modes()
	assert_gt(modes.size(), 0)
	assert_true("NORMAL" in modes)
	assert_true("DEUTERANOPIA" in modes)


## Test: Increase font scale
func test_accessibility_manager_increase_font_scale() -> void:
	var initial = accessibility_manager.current_font_scale
	accessibility_manager.increase_font_scale()
	assert_gt(accessibility_manager.current_font_scale, initial)


## Test: Decrease font scale
func test_accessibility_manager_decrease_font_scale() -> void:
	accessibility_manager.set_font_scale(1.5)
	accessibility_manager.decrease_font_scale()
	assert_lt(accessibility_manager.current_font_scale, 1.5)


## Test: Font scale clamping (above max)
func test_accessibility_manager_font_scale_clamp_max() -> void:
	accessibility_manager.set_font_scale(3.0)
	assert_eq(accessibility_manager.current_font_scale, 2.0)


## Test: Font scale clamping (below min)
func test_accessibility_manager_font_scale_clamp_min() -> void:
	accessibility_manager.set_font_scale(0.5)
	assert_eq(accessibility_manager.current_font_scale, 0.8)


## Test: Has active features (normal mode, normal scale)
func test_accessibility_manager_no_active_features() -> void:
	assert_false(accessibility_manager.has_active_features())


## Test: Has active features (color mode changed)
func test_accessibility_manager_active_color_mode() -> void:
	accessibility_manager.set_color_mode(AccessibilityManager.ColorMode.DEUTERANOPIA)
	assert_true(accessibility_manager.has_active_features())


## Test: Has active features (font scaled)
func test_accessibility_manager_active_font_scale() -> void:
	accessibility_manager.set_font_scale(1.5)
	assert_true(accessibility_manager.has_active_features())


## Test: Get status effects colors
func test_accessibility_manager_status_effect_colors() -> void:
	var poison_color = accessibility_manager.get_color("status_poison")
	var burn_color = accessibility_manager.get_color("status_burn")
	var freeze_color = accessibility_manager.get_color("status_freeze")

	assert_not_equal(poison_color, burn_color)
	assert_not_equal(burn_color, freeze_color)


# ========== PerformanceMonitor Tests ==========

## Test: Performance monitor initialization
func test_performance_monitor_init() -> void:
	assert_not_null(performance_monitor)
	assert_eq(performance_monitor.current_optimization_level, PerformanceMonitor.OptimizationLevel.OFF)
	assert_false(performance_monitor.is_throttling_animations)
	assert_false(performance_monitor.is_throttling_sounds)


## Test: Update metrics with delta time
func test_performance_monitor_update_metrics() -> void:
	performance_monitor.update_metrics(0.0167)  # ~60 FPS
	assert_gt(performance_monitor.current_fps, 0.0)
	assert_gt(performance_monitor.frame_time_ms, 0.0)


## Test: FPS tracking
func test_performance_monitor_fps_tracking() -> void:
	performance_monitor.update_metrics(0.0167)  # 60 FPS
	performance_monitor.update_metrics(0.0167)

	var avg_fps = performance_monitor.get_average_fps()
	assert_gt(avg_fps, 50.0)  # Should be around 60


## Test: Set active animations
func test_performance_monitor_set_animations() -> void:
	performance_monitor.set_active_animations(5)
	assert_eq(performance_monitor.active_animations_count, 5)


## Test: Set active sounds
func test_performance_monitor_set_sounds() -> void:
	performance_monitor.set_active_sounds(8)
	assert_eq(performance_monitor.active_sounds_count, 8)


## Test: Animation warning on too many
func test_performance_monitor_animation_warning() -> void:
	var warning_received = false
	performance_monitor.performance_warning.connect(func(cat, metric, val):
		if cat == "animations":
			warning_received = true)

	performance_monitor.set_active_animations(25)  # Exceeds default max of 20
	assert_true(warning_received)


## Test: Set optimization level LIGHT
func test_performance_monitor_optimization_light() -> void:
	performance_monitor.set_optimization_level(PerformanceMonitor.OptimizationLevel.LIGHT)
	assert_eq(performance_monitor.current_optimization_level, PerformanceMonitor.OptimizationLevel.LIGHT)


## Test: Set optimization level MEDIUM
func test_performance_monitor_optimization_medium() -> void:
	performance_monitor.set_optimization_level(PerformanceMonitor.OptimizationLevel.MEDIUM)
	assert_eq(performance_monitor.current_optimization_level, PerformanceMonitor.OptimizationLevel.MEDIUM)
	assert_true(performance_monitor.is_throttling_animations)


## Test: Set optimization level HEAVY
func test_performance_monitor_optimization_heavy() -> void:
	performance_monitor.set_optimization_level(PerformanceMonitor.OptimizationLevel.HEAVY)
	assert_eq(performance_monitor.current_optimization_level, PerformanceMonitor.OptimizationLevel.HEAVY)
	assert_true(performance_monitor.is_throttling_animations)
	assert_true(performance_monitor.is_throttling_sounds)


## Test: Get optimization level name
func test_performance_monitor_get_level_name() -> void:
	performance_monitor.set_optimization_level(PerformanceMonitor.OptimizationLevel.MEDIUM)
	assert_eq(performance_monitor.get_optimization_level(), "MEDIUM")


## Test: Get performance report
func test_performance_monitor_get_report() -> void:
	performance_monitor.update_metrics(0.0167)
	var report = performance_monitor.get_performance_report()

	assert_true("fps" in report)
	assert_true("frame_time_ms" in report)
	assert_true("active_animations" in report)
	assert_true("active_sounds" in report)
	assert_true("optimization_level" in report)


## Test: Should update animations (no throttling)
func test_performance_monitor_should_update_animations_no_throttle() -> void:
	performance_monitor.set_optimization_level(PerformanceMonitor.OptimizationLevel.OFF)
	assert_true(performance_monitor.should_update_animations())


## Test: Should update animations (with throttling)
func test_performance_monitor_should_update_animations_throttle() -> void:
	performance_monitor.set_optimization_level(PerformanceMonitor.OptimizationLevel.HEAVY)
	# Most calls should return true even with throttling at 50%
	var true_count = 0
	for i in range(20):
		if performance_monitor.should_update_animations():
			true_count += 1
	assert_gt(true_count, 0)  # At least some should be true


## Test: Estimate battle duration
func test_performance_monitor_estimate_duration() -> void:
	var duration = performance_monitor.estimate_battle_duration(2, 2, 5)
	assert_gt(duration, 0.0)
	assert_lt(duration, 60.0)  # Should be reasonable for short battle


## Test: FPS status good
func test_performance_monitor_fps_status_good() -> void:
	for i in range(60):
		performance_monitor.update_metrics(0.0167)

	var report = performance_monitor.get_performance_report()
	assert_eq(report["fps_status"], "Good")


## Test: Multiple animation events
func test_performance_monitor_multiple_events() -> void:
	performance_monitor.set_active_animations(5)
	performance_monitor.set_active_sounds(3)

	var report = performance_monitor.get_performance_report()
	assert_eq(report["active_animations"], 5)
	assert_eq(report["active_sounds"], 3)


## Test: Optimization recommendation signal
func test_performance_monitor_recommendation_signal() -> void:
	var recommendation_received = false
	performance_monitor.optimization_recommendation.connect(func(rec):
		recommendation_received = true)

	performance_monitor.set_active_animations(25)
	assert_true(recommendation_received)
