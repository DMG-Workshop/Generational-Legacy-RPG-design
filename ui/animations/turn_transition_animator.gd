## Turn Transition Animator: Highlight current character and animate turn changes
##
## Handles turn indicators, character highlighting, and round transition animations

class_name TurnTransitionAnimator


signal turn_highlight_complete
signal round_transition_complete


enum AnimationType { CHARACTER_HIGHLIGHT, ROUND_TRANSITION, TURN_INDICATOR }


var current_character: Battle.Combatant = null
var previous_character: Battle.Combatant = null
var animation_type: AnimationType = AnimationType.CHARACTER_HIGHLIGHT

var is_animating: bool = false
var elapsed_time: float = 0.0
var animation_duration: float = 0.6

var highlight_color: Color = Color.YELLOW
var highlight_intensity: float = 1.0
var pulse_speed: float = 2.0  # Cycles per second


func _init() -> void:
	pass


## Highlight character for their turn
func highlight_character(character: Battle.Combatant) -> void:
	previous_character = current_character
	current_character = character
	animation_type = AnimationType.CHARACTER_HIGHLIGHT
	is_animating = true
	elapsed_time = 0.0


## Animate round transition
func animate_round_transition(round_number: int) -> void:
	animation_type = AnimationType.ROUND_TRANSITION
	is_animating = true
	elapsed_time = 0.0


## Update animation state
func update(delta: float) -> void:
	if not is_animating:
		return

	elapsed_time += delta

	match animation_type:
		AnimationType.CHARACTER_HIGHLIGHT:
			if elapsed_time >= animation_duration:
				is_animating = false
				turn_highlight_complete.emit()

		AnimationType.ROUND_TRANSITION:
			if elapsed_time >= animation_duration:
				is_animating = false
				round_transition_complete.emit()


## Get highlight intensity for current character (pulsing effect)
func get_highlight_intensity() -> float:
	if not is_animating or animation_type != AnimationType.CHARACTER_HIGHLIGHT:
		return 0.0

	# Pulse effect using sine wave
	var pulse = sin(elapsed_time * pulse_speed * TAU) * 0.5 + 0.5
	return pulse * highlight_intensity


## Get fade intensity for previous character (fading out)
func get_previous_fade() -> float:
	if not is_animating or animation_type != AnimationType.CHARACTER_HIGHLIGHT:
		return 0.0

	if previous_character == null:
		return 0.0

	# Fade out previous character over first half of animation
	var fade_duration = animation_duration * 0.5
	if elapsed_time < fade_duration:
		return 1.0 - (elapsed_time / fade_duration)
	return 0.0


## Get round transition flash intensity
func get_round_flash() -> float:
	if not is_animating or animation_type != AnimationType.ROUND_TRANSITION:
		return 0.0

	# Flash white at start of round transition
	var flash_duration = animation_duration * 0.3
	if elapsed_time < flash_duration:
		return 1.0 - (elapsed_time / flash_duration)
	return 0.0


## Get turn indicator color (faction-based)
func get_turn_indicator_color() -> Color:
	if current_character == null:
		return Color.GRAY

	match current_character.faction:
		"party":
			return Color.GREEN
		"enemy":
			return Color.RED
		_:
			return Color.YELLOW


## Check if animation is complete
func is_complete() -> bool:
	return not is_animating
