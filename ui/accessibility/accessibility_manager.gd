## Accessibility Manager: Color-blind modes and font scaling
##
## Provides color-blind mode support (Deuteranopia, Protanopia, Tritanopia)
## and dynamic font scaling for readability

class_name AccessibilityManager


signal color_mode_changed(mode: String)
signal font_scale_changed(scale: float)


enum ColorMode { NORMAL, DEUTERANOPIA, PROTANOPIA, TRITANOPIA }

# Color definitions for each mode
var color_palettes: Dictionary = {
	"normal": {
		"critical_hit": Color.RED,
		"healing": Color.GREEN,
		"buff": Color.BLUE,
		"debuff": Color.PURPLE,
		"neutral": Color.WHITE,
		"ally": Color.GREEN,
		"enemy": Color.RED,
		"damage_text": Color.WHITE,
		"status_poison": Color.GREEN,
		"status_burn": Color.ORANGE_RED,
		"status_freeze": Color.CYAN,
		"status_stun": Color.YELLOW,
	},
	# Deuteranopia (red-green color blindness) - substitute red with blue, green with yellow
	"deuteranopia": {
		"critical_hit": Color.BLUE,
		"healing": Color.YELLOW,
		"buff": Color.CYAN,
		"debuff": Color.PURPLE,
		"neutral": Color.WHITE,
		"ally": Color.YELLOW,
		"enemy": Color.BLUE,
		"damage_text": Color.WHITE,
		"status_poison": Color.YELLOW,
		"status_burn": Color.ORANGE_RED,
		"status_freeze": Color.CYAN,
		"status_stun": Color.GRAY,
	},
	# Protanopia (red-green color blindness, different red perception) - substitute red with cyan
	"protanopia": {
		"critical_hit": Color.CYAN,
		"healing": Color.YELLOW,
		"buff": Color.LIGHT_BLUE,
		"debuff": Color.PURPLE,
		"neutral": Color.WHITE,
		"ally": Color.YELLOW,
		"enemy": Color.CYAN,
		"damage_text": Color.WHITE,
		"status_poison": Color.YELLOW,
		"status_burn": Color.PURPLE,
		"status_freeze": Color.LIGHT_BLUE,
		"status_stun": Color.GRAY,
	},
	# Tritanopia (blue-yellow color blindness) - substitute blue with red, yellow with cyan
	"tritanopia": {
		"critical_hit": Color.RED,
		"healing": Color.CYAN,
		"buff": Color.MAGENTA,
		"debuff": Color.GREEN,
		"neutral": Color.WHITE,
		"ally": Color.CYAN,
		"enemy": Color.RED,
		"damage_text": Color.WHITE,
		"status_poison": Color.GREEN,
		"status_burn": Color.RED,
		"status_freeze": Color.MAGENTA,
		"status_stun": Color.GRAY,
	}
}

var current_color_mode: ColorMode = ColorMode.NORMAL
var current_font_scale: float = 1.0
var min_font_scale: float = 0.8
var max_font_scale: float = 2.0
var font_scale_step: float = 0.1

# UI elements to update
var tracked_labels: Array[Label] = []
var tracked_colored_nodes: Array[Node] = []


func _init() -> void:
	current_color_mode = ColorMode.NORMAL
	current_font_scale = 1.0


## Set color-blind mode
func set_color_mode(mode: ColorMode) -> void:
	if current_color_mode == mode:
		return

	current_color_mode = mode
	_apply_color_mode_to_tracked_nodes()
	color_mode_changed.emit(ColorMode.keys()[mode])


## Get current color mode name
func get_color_mode_name() -> String:
	return ColorMode.keys()[current_color_mode]


## Get color for a specific element in current mode
func get_color(element_name: String) -> Color:
	var mode_name = get_color_mode_name().to_lower()
	if mode_name in color_palettes:
		var palette = color_palettes[mode_name]
		if element_name in palette:
			return palette[element_name]

	return Color.WHITE


## Register a label for font scaling
func register_label(label: Label) -> void:
	if label and label not in tracked_labels:
		tracked_labels.append(label)
		_update_label_font_size(label)


## Register a node for color updating
func register_colored_node(node: Node) -> void:
	if node and node not in tracked_colored_nodes:
		tracked_colored_nodes.append(node)
		_update_node_color(node)


## Increase font size
func increase_font_scale() -> void:
	set_font_scale(current_font_scale + font_scale_step)


## Decrease font size
func decrease_font_scale() -> void:
	set_font_scale(current_font_scale - font_scale_step)


## Set font scale directly
func set_font_scale(scale: float) -> void:
	var clamped = clamp(scale, min_font_scale, max_font_scale)
	if abs(clamped - current_font_scale) < 0.01:
		return

	current_font_scale = clamped
	_apply_font_scale_to_tracked_labels()
	font_scale_changed.emit(current_font_scale)


## Get current font scale
func get_font_scale() -> float:
	return current_font_scale


## Get all available color modes
func get_available_color_modes() -> Array[String]:
	return ColorMode.keys()


## Internal: Update label font sizes
func _update_label_font_size(label: Label) -> void:
	if label and label.has_meta("base_font_size"):
		var base_size = label.get_meta("base_font_size")
		label.add_theme_font_size_override("font_size", int(base_size * current_font_scale))


## Internal: Apply font scale to all tracked labels
func _apply_font_scale_to_tracked_labels() -> void:
	for label in tracked_labels:
		_update_label_font_size(label)


## Internal: Update node color based on metadata
func _update_node_color(node: Node) -> void:
	if node and node.has_meta("color_element"):
		var element_name = node.get_meta("color_element")
		var color = get_color(element_name)

		if node is Label:
			(node as Label).add_theme_color_override("font_color", color)
		elif node is Panel:
			(node as Panel).add_theme_color_override("panel_color", color)
		elif node is ColorRect:
			(node as ColorRect).color = color


## Internal: Apply color mode to all tracked nodes
func _apply_color_mode_to_tracked_nodes() -> void:
	for node in tracked_colored_nodes:
		_update_node_color(node)


## Set base font size for a label (called before registering)
func set_label_base_font_size(label: Label, base_size: int) -> void:
	if label:
		label.set_meta("base_font_size", base_size)


## Set color element type for a node (called before registering)
func set_node_color_element(node: Node, element_name: String) -> void:
	if node:
		node.set_meta("color_element", element_name)


## Check if accessibility features are active
func has_active_features() -> bool:
	return current_color_mode != ColorMode.NORMAL or abs(current_font_scale - 1.0) > 0.01
