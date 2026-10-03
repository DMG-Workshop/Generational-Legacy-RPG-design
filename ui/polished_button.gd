## Polished button: adds hover and press effects to buttons
##
## Provides visual feedback for mouse interaction with scaling and color changes

extends Button

class_name PolishedButton


var normal_scale: Vector2 = Vector2(1.0, 1.0)
var hover_scale: Vector2 = Vector2(1.05, 1.05)
var press_scale: Vector2 = Vector2(0.95, 0.95)
var hover_color: Color = Color.WHITE
var normal_color: Color = Color.WHITE
var tween: Tween


func _ready() -> void:
	normal_scale = scale
	hover_color = modulate
	normal_color = modulate

	# Connect mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)


func _on_mouse_entered() -> void:
	# Kill any existing tween
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", hover_scale, 0.15)
	tween.parallel().tween_property(self, "modulate", hover_color * 1.2, 0.15)


func _on_mouse_exited() -> void:
	# Kill any existing tween
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", normal_scale, 0.15)
	tween.parallel().tween_property(self, "modulate", normal_color, 0.15)


func _on_pressed() -> void:
	# Brief press animation
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", press_scale, 0.1)
	tween.tween_property(self, "scale", hover_scale, 0.1)
