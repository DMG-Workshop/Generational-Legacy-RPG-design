## Screen transition animator: handles fade transitions between screens
##
## Provides smooth fade-in and fade-out animations for screen transitions

extends Node

class_name ScreenTransitionAnimator


var tween: Tween
var transition_speed: float = 0.3


func fade_in(screen: Control, callback: Callable = Callable()) -> void:
	screen.modulate.alpha = 0.0

	# Kill any existing tween
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(screen, "modulate:alpha", 1.0, transition_speed)

	if callback.is_valid():
		tween.tween_callback(callback)


func fade_out(screen: Control, callback: Callable = Callable()) -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(screen, "modulate:alpha", 0.0, transition_speed)

	if callback.is_valid():
		tween.tween_callback(callback)


func slide_in_from_right(screen: Control, callback: Callable = Callable()) -> void:
	screen.modulate.alpha = 1.0
	screen.position.x = screen.get_viewport_rect().size.x

	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(screen, "position:x", 0.0, transition_speed)

	if callback.is_valid():
		tween.tween_callback(callback)


func slide_out_to_left(screen: Control, callback: Callable = Callable()) -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(screen, "position:x", -screen.get_viewport_rect().size.x, transition_speed)

	if callback.is_valid():
		tween.tween_callback(callback)
