## Health Bar Animator: Smooth health/mana bar transitions
##
## Animates health and mana bars with smooth color transitions and damage flashes

class_name HealthBarAnimator


signal animation_complete(bar_type: String)


enum BarType { HEALTH, MANA, STAMINA }


var current_value: float = 0.0
var target_value: float = 0.0
var max_value: float = 100.0
var bar_type: BarType = BarType.HEALTH

var is_animating: bool = false
var elapsed_time: float = 0.0
var animation_duration: float = 0.4  # Smooth transition duration

var color_normal: Color = Color.GREEN
var color_warning: Color = Color.YELLOW
var color_critical: Color = Color.RED
var color_mana: Color = Color.CYAN


func _init(initial_value: float = 100.0, max_hp: float = 100.0, bar: BarType = BarType.HEALTH) -> void:
	current_value = initial_value
	target_value = initial_value
	max_value = max_hp
	bar_type = bar

	if bar == BarType.MANA:
		color_normal = color_mana


## Set target health value and start animation
func animate_to(new_value: float) -> void:
	target_value = clamp(new_value, 0.0, max_value)
	if abs(target_value - current_value) > 0.01:
		is_animating = true
		elapsed_time = 0.0


## Update animation (call once per frame)
func update(delta: float) -> void:
	if not is_animating:
		return

	elapsed_time += delta
	if elapsed_time >= animation_duration:
		current_value = target_value
		is_animating = false
		animation_complete.emit(BarType.keys()[bar_type])
		return

	# Ease in-out for smooth animation
	var progress = elapsed_time / animation_duration
	var eased = ease(progress, -1.5)  # ease out

	current_value = lerp(current_value, target_value, eased)


## Get percentage fill (0.0 to 1.0)
func get_fill_percentage() -> float:
	if max_value <= 0:
		return 0.0
	return clamp(current_value / max_value, 0.0, 1.0)


## Get health bar color based on current value
func get_bar_color() -> Color:
	var percentage = get_fill_percentage()

	match bar_type:
		BarType.HEALTH:
			if percentage > 0.5:
				return color_normal
			elif percentage > 0.25:
				return color_warning
			else:
				return color_critical
		BarType.MANA:
			return color_mana
		_:
			return Color.GRAY


## Get background color (darker shade)
func get_background_color() -> Color:
	return get_bar_color() * 0.3


## Check if health is critical
func is_critical_health() -> bool:
	return get_fill_percentage() < 0.25 and bar_type == BarType.HEALTH


## Flash effect intensity (for damage feedback)
func get_flash_intensity() -> float:
	if not is_animating:
		return 0.0

	# Flash at start of animation
	var flash_duration = 0.2
	if elapsed_time < flash_duration:
		return 1.0 - (elapsed_time / flash_duration)
	return 0.0
