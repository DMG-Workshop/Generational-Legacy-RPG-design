## Status Effect Animator: Animate status effect icons and indicators
##
## Handles status effect appearance/disappearance, blinking, and color coding

class_name StatusEffectAnimator


signal effect_appeared
signal effect_disappeared


var effect_name: String = ""
var is_active: bool = false

var elapsed_time: float = 0.0
var appearance_duration: float = 0.3  # How long to animate in/out
var pulse_speed: float = 3.0  # Blinks per second


var effect_colors = {
	"poison": Color.GREEN,
	"burn": Color.RED,
	"freeze": Color.CYAN,
	"stun": Color.YELLOW,
	"bleed": Color.DARK_RED,
	"weakness": Color.GRAY,
	"strength_up": Color.LIGHT_GREEN,
	"defense_up": Color.LIGHT_BLUE,
	"curse": Color.MAGENTA,
	"bless": Color.YELLOW,
}


func _init(name: String = "") -> void:
	effect_name = name


## Apply status effect with animation
func apply_effect(effect: String) -> void:
	effect_name = effect
	is_active = true
	elapsed_time = 0.0
	effect_appeared.emit()


## Remove status effect with animation
func remove_effect() -> void:
	is_active = false
	elapsed_time = 0.0
	effect_disappeared.emit()


## Update animation state
func update(delta: float) -> void:
	if is_active or elapsed_time < appearance_duration:
		elapsed_time += delta


## Get icon opacity for fade in/out
func get_opacity() -> float:
	if is_active:
		# Fade in when appearing
		if elapsed_time < appearance_duration:
			return elapsed_time / appearance_duration
		return 1.0
	else:
		# Fade out when disappearing
		if elapsed_time < appearance_duration:
			return 1.0 - (elapsed_time / appearance_duration)
		return 0.0


## Get scale with pulse effect when active
func get_scale() -> float:
	if not is_active:
		return 1.0

	# Subtle pulse for active effects
	var pulse = sin((elapsed_time - appearance_duration) * pulse_speed * TAU) * 0.1 + 1.0
	return clamp(pulse, 0.9, 1.1)


## Get effect color
func get_color() -> Color:
	var color = effect_colors.get(effect_name.to_lower(), Color.WHITE)
	var opacity = get_opacity()
	color.a = opacity
	return color


## Get rotation for spinning effect
func get_rotation() -> float:
	if not is_active:
		return 0.0

	# Subtle rotation for new effects
	if elapsed_time < appearance_duration * 2:
		return (elapsed_time / (appearance_duration * 2)) * TAU * 0.5
	return 0.0


## Check if negative effect (debuff)
func is_negative_effect() -> bool:
	var negative_effects = ["poison", "burn", "freeze", "stun", "bleed", "weakness", "curse"]
	return effect_name.to_lower() in negative_effects


## Check if positive effect (buff)
func is_positive_effect() -> bool:
	var positive_effects = ["strength_up", "defense_up", "bless"]
	return effect_name.to_lower() in positive_effects


## Get glow intensity for negative effects
func get_glow_intensity() -> float:
	if not is_negative_effect() or not is_active:
		return 0.0

	# Pulsing glow for negative effects
	return sin(elapsed_time * pulse_speed * TAU) * 0.5 + 0.5
