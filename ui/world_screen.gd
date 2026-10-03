## World Screen: Displays game world, settlements, and player position
##
## Shows tile-based world map, settlements, NPCs, and movement UI

extends Control

class_name WorldScreen


signal heir_moved(new_position: Vector2i)
signal settlement_entered(settlement_name: String)
signal encounter_triggered(encounter_type: String)
signal realm_changed(realm_name: String)


# References
var world_tile_system: Object
var world_heir_integration: Object

# UI elements
var world_canvas: CanvasLayer
var movement_pad: VBoxContainer
var minimap: TextureRect
var location_label: Label
var time_display: Label
var realm_display: Label

# Camera and viewport
var camera: Camera2D
var tile_size: int = 32

# Current state
var heir_position: Vector2i = Vector2i.ZERO
var camera_following: bool = true
var zoom_level: float = 1.0


func _ready() -> void:
	_setup_world_ui()
	_setup_camera()


func _setup_world_ui() -> void:
	var main_container = VBoxContainer.new()
	main_container.anchor_left = 0.0
	main_container.anchor_top = 0.0
	main_container.anchor_right = 1.0
	main_container.anchor_bottom = 1.0
	add_child(main_container)

	# Top bar with info
	var top_bar = HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 40)
	main_container.add_child(top_bar)

	# Location display
	location_label = Label.new()
	location_label.text = "Location: Grasslands"
	top_bar.add_child(location_label)

	# Time display
	time_display = Label.new()
	time_display.text = "Year 1, Spring"
	top_bar.add_child(time_display)

	# Realm display
	realm_display = Label.new()
	realm_display.text = "Realm: Prime"
	top_bar.add_child(realm_display)

	# Main game area
	world_canvas = CanvasLayer.new()
	main_container.add_child(world_canvas)

	# Bottom bar with controls
	var bottom_bar = HBoxContainer.new()
	bottom_bar.custom_minimum_size = Vector2(0, 60)
	main_container.add_child(bottom_bar)

	# Movement pad (D-Pad style)
	movement_pad = VBoxContainer.new()
	movement_pad.custom_minimum_size = Vector2(120, 0)
	bottom_bar.add_child(movement_pad)

	# Up button
	var up_button = Button.new()
	up_button.text = "↑"
	up_button.pressed.connect(_on_move_up)
	movement_pad.add_child(up_button)

	# Left/Right/Down row
	var h_row = HBoxContainer.new()
	movement_pad.add_child(h_row)

	var left_button = Button.new()
	left_button.text = "←"
	left_button.pressed.connect(_on_move_left)
	h_row.add_child(left_button)

	var down_button = Button.new()
	down_button.text = "↓"
	down_button.pressed.connect(_on_move_down)
	h_row.add_child(down_button)

	var right_button = Button.new()
	right_button.text = "→"
	right_button.pressed.connect(_on_move_right)
	h_row.add_child(right_button)

	# Action buttons
	var action_container = VBoxContainer.new()
	bottom_bar.add_child(action_container)

	var interact_button = Button.new()
	interact_button.text = "Interact"
	interact_button.pressed.connect(_on_interact)
	action_container.add_child(interact_button)

	var inventory_button = Button.new()
	inventory_button.text = "Inventory"
	inventory_button.pressed.connect(_on_open_inventory)
	action_container.add_child(inventory_button)

	var map_button = Button.new()
	map_button.text = "Map"
	map_button.pressed.connect(_on_open_map)
	action_container.add_child(map_button)


## Setup camera
func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.zoom = Vector2(zoom_level, zoom_level)
	world_canvas.add_child(camera)


## Initialize world
func initialize_world(heir_pos: Vector2i) -> void:
	heir_position = heir_pos
	camera.global_position = Vector2(heir_pos) * tile_size
	_update_location_display()


## Update location display
func _update_location_display() -> void:
	var location = _get_location_name(heir_position)
	location_label.text = "Location: %s" % location


## Get location name from position
func _get_location_name(pos: Vector2i) -> String:
	# Convert world position to location name
	var biome = _get_biome_at(pos)
	return biome.capitalize()


## Get biome type
func _get_biome_at(pos: Vector2i) -> String:
	# Placeholder - would use world_tile_system
	if pos.x > 500:
		return "Mountain"
	elif pos.x < -500:
		return "Cavern"
	elif pos.y > 300:
		return "Desert"
	else:
		return "Grasslands"


## Handle movement
func _on_move_up() -> void:
	_move_heir(Vector2i.UP)


func _on_move_down() -> void:
	_move_heir(Vector2i.DOWN)


func _on_move_left() -> void:
	_move_heir(Vector2i.LEFT)


func _on_move_right() -> void:
	_move_heir(Vector2i.RIGHT)


## Move heir
func _move_heir(direction: Vector2i) -> void:
	heir_position += direction

	# Update camera
	if camera_following:
		camera.global_position = Vector2(heir_position) * tile_size

	_update_location_display()
	heir_moved.emit(heir_position)


## Handle interact
func _on_interact() -> void:
	# Check for settlement or NPC at current location
	var location = _get_location_name(heir_position)
	if location != "Grasslands":
		settlement_entered.emit(location)


## Open inventory
func _on_open_inventory() -> void:
	# Would open inventory screen
	pass


## Open map
func _on_open_map() -> void:
	# Would open full map view
	pass


## Update time display
func update_time(year: int, season: String) -> void:
	time_display.text = "Year %d, %s" % [year, season]


## Update realm display
func update_realm(realm_name: String) -> void:
	realm_display.text = "Realm: %s" % realm_name
	realm_changed.emit(realm_name)


## Display settlement marker
func mark_settlement(pos: Vector2i, settlement_name: String) -> void:
	var marker = ColorRect.new()
	marker.color = Color.YELLOW
	marker.size = Vector2(tile_size, tile_size)
	marker.position = Vector2(pos) * tile_size
	world_canvas.add_child(marker)


## Display encounter marker
func mark_encounter(pos: Vector2i, encounter_type: String) -> void:
	var marker = ColorRect.new()
	match encounter_type:
		"boss":
			marker.color = Color.RED
		"combat":
			marker.color = Color.ORANGE
		"treasure":
			marker.color = Color.GOLD
		_:
			marker.color = Color.GRAY

	marker.size = Vector2(tile_size, tile_size)
	marker.position = Vector2(pos) * tile_size
	world_canvas.add_child(marker)


## Get heir position
func get_heir_position() -> Vector2i:
	return heir_position


## Set camera zoom
func set_camera_zoom(zoom: float) -> void:
	zoom_level = zoom
	camera.zoom = Vector2(zoom_level, zoom_level)


## Toggle camera following
func toggle_camera_follow() -> void:
	camera_following = !camera_following


## Get current location name
func get_current_location() -> String:
	return _get_location_name(heir_position)
