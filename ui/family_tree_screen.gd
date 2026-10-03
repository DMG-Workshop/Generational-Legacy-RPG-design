## Family Tree Screen: Visualizes heir lineage and family relationships
##
## Displays generational tree, heir connections, marriages, and legacy information

extends Control

class_name FamilyTreeScreen


signal heir_selected(heir_name: String)
signal generation_selected(generation: int)


# References
var lineage_system: Object
var trait_system: Object

# UI elements
var tree_container: Control
var heir_detail_panel: PanelContainer
var generation_scroll: ScrollContainer
var zoom_level: float = 1.0

# Visual data
var heir_nodes: Dictionary = {}  # heir_name -> Node
var connection_lines: Array = []
var current_selected_heir: String = ""


func _ready() -> void:
	_setup_family_tree_ui()


func _setup_family_tree_ui() -> void:
	var main_container = HSplitContainer.new()
	main_container.anchor_left = 0.0
	main_container.anchor_top = 0.0
	main_container.anchor_right = 1.0
	main_container.anchor_bottom = 1.0
	add_child(main_container)

	# Left side: Tree view
	tree_container = Control.new()
	tree_container.custom_minimum_size = Vector2(600, 0)
	main_container.add_child(tree_container)

	# Right side: Detail panel
	heir_detail_panel = PanelContainer.new()
	heir_detail_panel.custom_minimum_size = Vector2(300, 0)
	main_container.add_child(heir_detail_panel)

	var detail_content = VBoxContainer.new()
	heir_detail_panel.add_child(detail_content)

	# Title label
	var title = Label.new()
	title.text = "Select an heir to view details"
	detail_content.add_child(title)


## Initialize family tree with lineage data
func initialize_tree(lineage_data: Array, current_generation: int) -> void:
	_draw_family_tree(lineage_data, current_generation)


## Draw family tree visualization
func _draw_family_tree(lineage_data: Array, current_generation: int) -> void:
	# Clear previous tree
	heir_nodes.clear()
	for line in connection_lines:
		line.queue_free()
	connection_lines.clear()

	var y_offset = 20.0
	var generation_width = 150.0

	# Draw each generation
	for generation in range(1, current_generation + 1):
		var heirs_in_gen = _get_heirs_for_generation(lineage_data, generation)

		for heir_idx in range(heirs_in_gen.size()):
			var heir = heirs_in_gen[heir_idx]
			var x_pos = generation * generation_width
			var y_pos = y_offset + (heir_idx * 80.0)

			# Create heir node
			var heir_node = _create_heir_node(heir, Vector2(x_pos, y_pos))
			tree_container.add_child(heir_node)
			heir_nodes[heir["name"]] = heir_node

			# Draw connection to parent
			if heir.get("parent", ""):
				if heir["parent"] in heir_nodes:
					_draw_connection(heir_nodes[heir["parent"]], heir_node)


## Create visual node for heir
func _create_heir_node(heir: Dictionary, position: Vector2) -> Control:
	var node = Control.new()
	node.position = position
	node.custom_minimum_size = Vector2(130, 70)

	# Background panel
	var panel = PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	node.add_child(panel)

	# Content
	var content = VBoxContainer.new()
	panel.add_child(content)

	# Heir name (clickable)
	var name_button = Button.new()
	name_button.text = heir["name"]
	name_button.pressed.connect(_on_heir_selected.bind(heir["name"]))
	content.add_child(name_button)

	# Generation
	var gen_label = Label.new()
	gen_label.text = "Gen %d" % heir.get("generation", 0)
	gen_label.add_theme_font_size_override("font_size", 10)
	content.add_child(gen_label)

	# Age
	var age_label = Label.new()
	age_label.text = "Age %d" % heir.get("age", 0)
	age_label.add_theme_font_size_override("font_size", 10)
	content.add_child(age_label)

	return node


## Draw connection line between heirs
func _draw_connection(parent_node: Control, child_node: Control) -> void:
	var line = Line2D.new()
	line.points = PackedVector2Array([
		parent_node.position,
		child_node.position,
	])
	line.width = 2.0
	line.modulate = Color.WHITE
	tree_container.add_child(line)
	connection_lines.append(line)


## Get heirs for a specific generation
func _get_heirs_for_generation(lineage_data: Array, generation: int) -> Array:
	var heirs = []
	for heir in lineage_data:
		if heir.get("generation", 0) == generation:
			heirs.append(heir)
	return heirs


## Handle heir selection
func _on_heir_selected(heir_name: String) -> void:
	current_selected_heir = heir_name
	_display_heir_details(heir_name)
	heir_selected.emit(heir_name)


## Display heir details in right panel
func _display_heir_details(heir_name: String) -> void:
	# Clear panel
	for child in heir_detail_panel.get_children():
		if child is VBoxContainer:
			for detail_child in child.get_children():
				detail_child.queue_free()

	var content = VBoxContainer.new()
	heir_detail_panel.add_child(content)

	# Heir name (large)
	var name_label = Label.new()
	name_label.text = heir_name
	name_label.add_theme_font_size_override("font_size", 20)
	content.add_child(name_label)

	# Stats display (placeholder)
	var stats_label = Label.new()
	stats_label.text = "Stats Information"
	content.add_child(stats_label)

	# Traits display (placeholder)
	var traits_label = Label.new()
	traits_label.text = "Traits & Abilities"
	content.add_child(traits_label)

	# Legacy display (placeholder)
	var legacy_label = Label.new()
	legacy_label.text = "Legacy Value: —"
	content.add_child(legacy_label)


## Zoom in
func zoom_in() -> void:
	zoom_level *= 1.2
	_update_zoom()


## Zoom out
func zoom_out() -> void:
	zoom_level /= 1.2
	_update_zoom()


## Update zoom on all nodes
func _update_zoom() -> void:
	tree_container.scale = Vector2(zoom_level, zoom_level)


## Get selected heir
func get_selected_heir() -> String:
	return current_selected_heir


## Highlight heir in tree
func highlight_heir(heir_name: String) -> void:
	for node_name in heir_nodes.keys():
		var node = heir_nodes[node_name]
		var panel = node.get_child(0)

		if node_name == heir_name:
			panel.modulate = Color.YELLOW
		else:
			panel.modulate = Color.WHITE


## Reset highlight
func reset_highlights() -> void:
	for node in heir_nodes.values():
		var panel = node.get_child(0)
		panel.modulate = Color.WHITE


## Export tree as image
func export_tree_image(filename: String) -> void:
	var image = tree_container.get_viewport().get_texture().get_image()
	image.save_png(filename)
