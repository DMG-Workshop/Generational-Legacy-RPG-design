## Performance Monitor: Track and optimize battle system performance
##
## Monitors FPS, animation count, sound queue depth, and heap usage
## Provides throttling and optimization recommendations

class_name PerformanceMonitor


signal performance_warning(category: String, metric: String, value: float)
signal optimization_recommendation(recommendation: String)


enum OptimizationLevel { OFF, LIGHT, MEDIUM, HEAVY }

# Performance thresholds
var fps_warning_threshold: float = 50.0
var fps_critical_threshold: float = 30.0
var max_simultaneous_animations: int = 20
var max_sound_queue_depth: int = 32
var memory_warning_mb: float = 256.0
var memory_critical_mb: float = 512.0

# Performance metrics
var current_fps: float = 60.0
var active_animations_count: int = 0
var active_sounds_count: int = 0
var total_heap_mb: float = 0.0
var frame_time_ms: float = 0.0

# Historical data for averaging
var fps_history: Array[float] = []
var max_history_size: int = 60  # 1 second at 60 FPS

# Optimization state
var current_optimization_level: OptimizationLevel = OptimizationLevel.OFF
var is_throttling_animations: bool = false
var is_throttling_sounds: bool = false
var animation_throttle_rate: float = 1.0  # 1.0 = full speed, 0.5 = half speed


func _init() -> void:
	current_optimization_level = OptimizationLevel.OFF
	is_throttling_animations = false
	is_throttling_sounds = false


## Update performance metrics (call each frame)
func update_metrics(delta: float) -> void:
	frame_time_ms = delta * 1000.0
	current_fps = 1.0 / delta if delta > 0 else 60.0

	# Track FPS history
	fps_history.append(current_fps)
	if fps_history.size() > max_history_size:
		fps_history.pop_front()

	# Update total heap usage
	total_heap_mb = OS.get_static_memory_usage() / (1024.0 * 1024.0)

	# Check performance and apply optimizations
	_check_performance_thresholds()


## Set active animation count
func set_active_animations(count: int) -> void:
	active_animations_count = count

	if count > max_simultaneous_animations:
		performance_warning.emit("animations", "count_exceeded", float(count))
		if not is_throttling_animations:
			_enable_animation_throttling()


## Set active sound count
func set_active_sounds(count: int) -> void:
	active_sounds_count = count

	if count > max_sound_queue_depth:
		performance_warning.emit("sounds", "queue_exceeded", float(count))
		if not is_throttling_sounds:
			_enable_sound_throttling()


## Get average FPS over history
func get_average_fps() -> float:
	if fps_history.is_empty():
		return 60.0

	var sum = 0.0
	for fps in fps_history:
		sum += fps
	return sum / fps_history.size()


## Get current optimization level
func get_optimization_level() -> String:
	return OptimizationLevel.keys()[current_optimization_level]


## Enable optimization (automatic or manual)
func set_optimization_level(level: OptimizationLevel) -> void:
	if current_optimization_level == level:
		return

	current_optimization_level = level

	match level:
		OptimizationLevel.OFF:
			is_throttling_animations = false
			is_throttling_sounds = false
			animation_throttle_rate = 1.0
		OptimizationLevel.LIGHT:
			animation_throttle_rate = 0.9
			is_throttling_animations = false
			is_throttling_sounds = false
		OptimizationLevel.MEDIUM:
			animation_throttle_rate = 0.7
			is_throttling_animations = true
			is_throttling_sounds = false
		OptimizationLevel.HEAVY:
			animation_throttle_rate = 0.5
			is_throttling_animations = true
			is_throttling_sounds = true


## Get performance report
func get_performance_report() -> Dictionary:
	return {
		"fps": current_fps,
		"average_fps": get_average_fps(),
		"frame_time_ms": frame_time_ms,
		"active_animations": active_animations_count,
		"active_sounds": active_sounds_count,
		"heap_mb": total_heap_mb,
		"optimization_level": get_optimization_level(),
		"fps_status": _get_fps_status(),
		"memory_status": _get_memory_status(),
		"throttling_active": is_throttling_animations or is_throttling_sounds
	}


## Internal: Check if performance has degraded
func _check_performance_thresholds() -> void:
	var avg_fps = get_average_fps()

	# FPS checks
	if avg_fps < fps_critical_threshold:
		performance_warning.emit("fps", "critical", avg_fps)
		if current_optimization_level < OptimizationLevel.HEAVY:
			set_optimization_level(OptimizationLevel.HEAVY)
	elif avg_fps < fps_warning_threshold:
		performance_warning.emit("fps", "warning", avg_fps)
		if current_optimization_level < OptimizationLevel.MEDIUM:
			set_optimization_level(OptimizationLevel.MEDIUM)

	# Memory checks
	if total_heap_mb > memory_critical_mb:
		performance_warning.emit("memory", "critical", total_heap_mb)
		optimization_recommendation.emit("Consider reducing number of concurrent animations")
	elif total_heap_mb > memory_warning_mb:
		performance_warning.emit("memory", "warning", total_heap_mb)


## Internal: Enable animation throttling
func _enable_animation_throttling() -> void:
	is_throttling_animations = true
	animation_throttle_rate = 0.7
	optimization_recommendation.emit("Too many simultaneous animations; reducing update rate to 70%")


## Internal: Enable sound throttling
func _enable_sound_throttling() -> void:
	is_throttling_sounds = true
	optimization_recommendation.emit("Sound queue full; dropping low-priority sounds")


## Get FPS status text
func _get_fps_status() -> String:
	var avg_fps = get_average_fps()
	if avg_fps >= fps_warning_threshold:
		return "Good"
	elif avg_fps >= fps_critical_threshold:
		return "Warning"
	else:
		return "Critical"


## Get memory status text
func _get_memory_status() -> String:
	if total_heap_mb >= memory_critical_mb:
		return "Critical"
	elif total_heap_mb >= memory_warning_mb:
		return "Warning"
	else:
		return "Good"


## Should update animations this frame (for throttling)
func should_update_animations() -> bool:
	if not is_throttling_animations:
		return true
	return randf() < animation_throttle_rate


## Get estimated battle duration
func estimate_battle_duration(party_count: int, enemy_count: int, expected_rounds: int) -> float:
	var total_combatants = party_count + enemy_count
	var animations_per_round = total_combatants * 2  # Rough estimate
	var total_animations = animations_per_round * expected_rounds

	# Average animation time ~0.5 seconds
	var total_time = total_animations * 0.5
	return total_time
