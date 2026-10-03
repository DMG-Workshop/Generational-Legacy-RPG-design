## Damage Popup: Floating damage/healing numbers with animations
##
## Displays damage and healing numbers that float upward with fade-out effect
## Supports critical hits with special formatting and color

extends Node


signal animation_complete


var damage: int = 0
var is_critical: bool = false
var is_healing: bool = false
var position_offset: Vector2 = Vector2.ZERO
var duration: float = 1.5  # Total animation duration in seconds
var float_distance: float = 40.0  # How far to float upward

var elapsed_time: float = 0.0
var start_position: Vector2 = Vector2.ZERO
var end_position: Vector2 = Vector2.ZERO
var start_opacity: float = 1.0


func _init(damage_amount: int, critical: bool = false, healing: bool = false) -> void:
	damage = damage_amount
	is_critical = critical
	is_healing = healing


## Start animation from given position
func animate_from(start_pos: Vector2) -> void:
	start_position = start_pos
	end_position = start_pos + Vector2.UP * float_distance
	elapsed_time = 0.0
	start_opacity = 1.0


## Update animation state (call once per frame)
func update(delta: float) -> void:
	elapsed_time += delta
	if elapsed_time >= duration:
		animation_complete.emit()
		return

	# Calculate progress (0 to 1)
	var progress = elapsed_time / duration

	# Ease out cubic for float motion
	var eased_progress = ease(progress, -2.0)

	# Position interpolation
	var current_pos = start_position.lerp(end_position, eased_progress)
	position_offset = current_pos - start_position

	# Opacity fade (stays opaque for 70% of duration, then fades)
	var fade_start = 0.7
	if progress < fade_start:
		start_opacity = 1.0
	else:
		var fade_progress = (progress - fade_start) / (1.0 - fade_start)
		start_opacity = 1.0 - fade_progress


## Get formatted damage text
func get_display_text() -> String:
	if is_healing:
		return "+%d" % damage
	elif is_critical:
		return "%d!" % damage
	else:
		return "%d" % damage


## Get color based on damage type and crit
func get_color() -> Color:
	if is_healing:
		return Color.GREEN if not is_critical else Color.LIME
	elif is_critical:
		return Color.YELLOW if damage > 50 else Color.ORANGE
	else:
		return Color.WHITE


## Get scale for critical hits
func get_scale() -> float:
	if is_critical:
		return 1.5
	elif is_healing:
		return 1.2
	else:
		return 1.0


## Check if animation is complete
func is_complete() -> bool:
	return elapsed_time >= duration
