## Ability Animator: Visual feedback for ability execution
##
## Animates ability activation, casting sequences, and impact effects

class_name AbilityAnimator


signal ability_cast_complete
signal ability_impact_complete


enum AbilityType { ATTACK, SPELL, HEAL, BUFF, DEBUFF, UTILITY }


var ability_name: String = ""
var ability_type: AbilityType = AbilityType.ATTACK
var caster: Battle.Combatant = null
var target: Battle.Combatant = null

var is_casting: bool = false
var is_impacting: bool = false

var elapsed_time: float = 0.0
var cast_duration: float = 0.5  # Casting animation time
var impact_duration: float = 0.3  # Impact animation time


var type_colors = {
	AbilityType.ATTACK: Color.RED,
	AbilityType.SPELL: Color.CYAN,
	AbilityType.HEAL: Color.GREEN,
	AbilityType.BUFF: Color.LIGHT_GREEN,
	AbilityType.DEBUFF: Color.YELLOW,
	AbilityType.UTILITY: Color.GRAY,
}


func _init(name: String = "", type: AbilityType = AbilityType.ATTACK) -> void:
	ability_name = name
	ability_type = type


## Start casting animation
func start_cast(actor: Battle.Combatant, tgt: Battle.Combatant = null) -> void:
	caster = actor
	target = tgt
	is_casting = true
	is_impacting = false
	elapsed_time = 0.0


## Transition to impact animation
func start_impact() -> void:
	is_casting = false
	is_impacting = true
	elapsed_time = 0.0
	ability_cast_complete.emit()


## Update animation state
func update(delta: float) -> void:
	elapsed_time += delta

	if is_impacting and elapsed_time >= impact_duration:
		is_impacting = false
		ability_impact_complete.emit()


## Get caster animation intensity (charge up effect)
func get_cast_intensity() -> float:
	if not is_casting:
		return 0.0

	var progress = elapsed_time / cast_duration
	# Accelerating glow effect
	return ease(progress, 2.0)


## Get cast bar fill (0.0 to 1.0)
func get_cast_progress() -> float:
	if not is_casting:
		return 1.0

	return clamp(elapsed_time / cast_duration, 0.0, 1.0)


## Get target shake intensity during impact
func get_impact_shake() -> float:
	if not is_impacting:
		return 0.0

	# Strong shake that fades out
	var progress = elapsed_time / impact_duration
	var shake = sin(progress * TAU * 4.0) * (1.0 - progress)
	return abs(shake) * 10.0  # Max 10 pixel shake


## Get impact flash opacity
func get_impact_flash() -> float:
	if not is_impacting:
		return 0.0

	# White flash that fades quickly
	if elapsed_time < impact_duration * 0.3:
		return 1.0 - (elapsed_time / (impact_duration * 0.3))
	return 0.0


## Get ability color based on type
func get_ability_color() -> Color:
	return type_colors.get(ability_type, Color.WHITE)


## Get particle emission intensity
func get_particle_intensity() -> float:
	if is_casting:
		return get_cast_intensity()
	elif is_impacting:
		return 1.0 - (elapsed_time / impact_duration)
	return 0.0


## Check if casting complete
func is_cast_complete() -> bool:
	return not is_casting


## Check if impact complete
func is_impact_complete() -> bool:
	return not is_impacting


## Get animation phase name
func get_phase() -> String:
	if is_casting:
		return "casting"
	elif is_impacting:
		return "impact"
	else:
		return "complete"
