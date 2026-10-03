## World exploration screen: tile-based world navigation
##
## Displays current chunk, player position, NPCs, structures
## Handles movement, interaction, and scene transitions

extends Control

class_name WorldScreen


var generation_manager: GenerationManager
var world: WorldManager
var current_realm: String = "material"
var player_pos: Vector3i = Vector3i.ZERO
var camera_pos: Vector2

## Tile rendering
var tile_size: int = 32
var tilemap: TileMap
var grid_container: Control


func _init(gen_manager: GenerationManager, world_mgr: WorldManager) -> void:
	generation_manager = gen_manager
	world = world_mgr


func _ready() -> void:
	# Setup background
	var bg = ColorRect.new()
	bg.color = Color.BLACK
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Create tilemap display area
	grid_container = Control.new()
	grid_container.custom_minimum_size = Vector2(800, 600)
	add_child(grid_container)
	grid_container.draw.connect(_on_grid_draw)

	# UI overlay
	var ui = VBoxContainer.new()
	ui.anchor_left = 0.0
	ui.anchor_top = 0.0
	ui.offset_top = 10
	ui.offset_left = 10
	add_child(ui)

	var realm_label = Label.new()
	realm_label.text = "Realm: %s" % current_realm
	ui.add_child(realm_label)

	var pos_label = Label.new()
	pos_label.text = "Position: (%d, %d)" % [player_pos.x, player_pos.y]
	ui.add_child(pos_label)

	var heir_label = Label.new()
	heir_label.text = "Heir: %s (Age %d)" % [generation_manager.current_heir.name, generation_manager.current_age]
	ui.add_child(heir_label)

	# Bottom UI with actions
	var action_bar = HBoxContainer.new()
	action_bar.anchor_left = 0.0
	action_bar.anchor_right = 1.0
	action_bar.anchor_top = 1.0
	action_bar.anchor_bottom = 1.0
	action_bar.offset_top = -40
	add_child(action_bar)

	var interact_btn = Button.new()
	interact_btn.text = "Interact (E)"
	interact_btn.pressed.connect(_on_interact)
	action_bar.add_child(interact_btn)

	var dig_btn = Button.new()
	dig_btn.text = "Dig Down (D)"
	dig_btn.pressed.connect(_on_dig)
	action_bar.add_child(dig_btn)

	var inv_btn = Button.new()
	inv_btn.text = "Inventory (I)"
	inv_btn.pressed.connect(_on_inventory)
	action_bar.add_child(inv_btn)


func _on_grid_draw() -> void:
	# Get current chunk
	var chunk = world.get_chunk(current_realm, player_pos)
	if not chunk:
		return

	# Draw tiles
	for x in range(16):
		for y in range(16):
			var tile_pos = Vector2(x * tile_size, y * tile_size)
			var tile_type = chunk.tiles[x][y]

			# Color tiles by type
			var color = _get_tile_color(tile_type)
			grid_container.draw_rect(Rect2(tile_pos, Vector2(tile_size, tile_size)), color)
			grid_container.draw_rect(Rect2(tile_pos, Vector2(tile_size, tile_size)), Color.WHITE, false, 1.0)

	# Draw player at center
	var player_x = 8 * tile_size
	var player_y = 8 * tile_size
	grid_container.draw_circle(Vector2(player_x + tile_size/2, player_y + tile_size/2), 8, Color.RED)


func _get_tile_color(tile_type: int) -> Color:
	match tile_type:
		0:  # Grass
			return Color.GREEN
		1:  # Forest
			return Color.DARK_GREEN
		2:  # Water
			return Color.BLUE
		3:  # Mountain
			return Color.GRAY
		4:  # Stone/cave
			return Color.DARK_GRAY
		_:
			return Color.WHITE


func _on_interact() -> void:
	# Check for NPCs, structures, items at current position
	print("Interact at %s" % player_pos)


func _on_dig() -> void:
	# Dig down one level (z += 1, moving back in time)
	player_pos.z += 1
	grid_container.queue_redraw()
	print("Dug down to z=%d" % player_pos.z)


func _on_inventory() -> void:
	var main_game = get_tree().root.get_child(0)
	main_game.show_screen("character")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP:
				player_pos.y -= 1
				grid_container.queue_redraw()
			KEY_DOWN:
				player_pos.y += 1
				grid_container.queue_redraw()
			KEY_LEFT:
				player_pos.x -= 1
				grid_container.queue_redraw()
			KEY_RIGHT:
				player_pos.x += 1
				grid_container.queue_redraw()
			KEY_E:
				_on_interact()
			KEY_D:
				_on_dig()
			KEY_I:
				_on_inventory()
