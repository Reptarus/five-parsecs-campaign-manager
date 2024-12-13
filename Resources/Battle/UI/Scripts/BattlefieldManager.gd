extends Control

const GRID_SIZE = 32  # Size of each grid cell in pixels
const MOVEMENT_BASE = 6  # Base movement from Core Rules

enum BattlefieldMode {
	SETUP,
	PREVIEW,
	DEPLOY
}

enum TerrainType {
	COVER,
	BUILDING,
	ELEVATED,
	HAZARD
}

var current_mode: BattlefieldMode = BattlefieldMode.SETUP
var selected_tool: TerrainType = TerrainType.COVER
var grid_data: Dictionary = {}
var terrain_data: Array = []
var deployment_zones: Dictionary = {
	"player": [],
	"enemy": [],
	"objectives": []
}

@onready var battlefield_view = $HSplitContainer/BattlefieldView
@onready var grid = $HSplitContainer/BattlefieldView/SubViewport/Battlefield/Grid
@onready var terrain = $HSplitContainer/BattlefieldView/SubViewport/Battlefield/Terrain
@onready var units = $HSplitContainer/BattlefieldView/SubViewport/Battlefield/Units
@onready var highlights = $HSplitContainer/BattlefieldView/SubViewport/Battlefield/Highlights
@onready var info_content = $HSplitContainer/ControlPanel/VBoxContainer/InfoPanel/VBoxContainer/InfoContent

func _ready() -> void:
	_connect_signals()
	_initialize_grid()
	_setup_camera()

func _connect_signals() -> void:
	# Mode buttons
	var mode_buttons = $HSplitContainer/ControlPanel/VBoxContainer/ModePanel/VBoxContainer/ModeButtons
	mode_buttons.get_node("SetupButton").pressed.connect(_on_mode_button_pressed.bind(BattlefieldMode.SETUP))
	mode_buttons.get_node("PreviewButton").pressed.connect(_on_mode_button_pressed.bind(BattlefieldMode.PREVIEW))
	mode_buttons.get_node("DeployButton").pressed.connect(_on_mode_button_pressed.bind(BattlefieldMode.DEPLOY))
	
	# Terrain tools
	var terrain_tools = $HSplitContainer/ControlPanel/VBoxContainer/ToolPanel/VBoxContainer/TerrainTools
	terrain_tools.get_node("AddCoverButton").pressed.connect(_on_terrain_tool_selected.bind(TerrainType.COVER))
	terrain_tools.get_node("AddBuildingButton").pressed.connect(_on_terrain_tool_selected.bind(TerrainType.BUILDING))
	terrain_tools.get_node("AddElevatedButton").pressed.connect(_on_terrain_tool_selected.bind(TerrainType.ELEVATED))
	terrain_tools.get_node("AddHazardButton").pressed.connect(_on_terrain_tool_selected.bind(TerrainType.HAZARD))
	
	# Confirm button
	$HSplitContainer/ControlPanel/VBoxContainer/ConfirmButton.pressed.connect(_on_confirm_pressed)

func _initialize_grid() -> void:
	# Create a 24x24 grid (standard battlefield size)
	for x in range(24):
		for y in range(24):
			var pos = Vector2(x, y)
			grid_data[pos] = {
				"terrain": null,
				"unit": null,
				"movement_cost": 1,
				"cover_bonus": 0
			}
	_draw_grid()

func _draw_grid() -> void:
	# Clear existing grid
	for child in grid.get_children():
		child.queue_free()
	
	# Draw new grid
	for pos in grid_data.keys():
		var rect = ColorRect.new()
		rect.size = Vector2(GRID_SIZE, GRID_SIZE)
		rect.position = pos * GRID_SIZE
		rect.color = Color(0.2, 0.2, 0.2, 0.1)
		grid.add_child(rect)

func _setup_camera() -> void:
	var camera = $HSplitContainer/BattlefieldView/SubViewport/Camera2D
	camera.position = Vector2(24 * GRID_SIZE / 2, 24 * GRID_SIZE / 2)
	camera.zoom = Vector2(0.5, 0.5)

func _on_mode_button_pressed(mode: BattlefieldMode) -> void:
	current_mode = mode
	_update_ui()
	_update_info_panel()

func _on_terrain_tool_selected(type: TerrainType) -> void:
	selected_tool = type
	_update_info_panel()

func _on_confirm_pressed() -> void:
	match current_mode:
		BattlefieldMode.SETUP:
			_validate_and_save_terrain()
		BattlefieldMode.PREVIEW:
			_confirm_preview()
		BattlefieldMode.DEPLOY:
			_confirm_deployment()

func _validate_and_save_terrain() -> void:
	# Validate terrain placement according to Core Rules
	var valid = true
	var error_message = ""
	
	# Check terrain density
	var terrain_count = terrain_data.size()
	if terrain_count < 4:
		valid = false
		error_message = "Battlefield must have at least 4 pieces of terrain"
	elif terrain_count > 12:
		valid = false
		error_message = "Battlefield cannot have more than 12 pieces of terrain"
	
	if valid:
		_save_terrain_data()
		current_mode = BattlefieldMode.PREVIEW
		_update_ui()
	else:
		_show_error(error_message)

func _confirm_preview() -> void:
	# Generate deployment zones
	_generate_deployment_zones()
	current_mode = BattlefieldMode.DEPLOY
	_update_ui()

func _confirm_deployment() -> void:
	# Validate deployment according to Core Rules
	if _validate_deployment():
		emit_signal("battlefield_setup_complete")

func _generate_deployment_zones() -> void:
	# Clear existing zones
	deployment_zones.clear()
	
	# Player deployment zone (usually bottom 6" of the battlefield)
	for x in range(24):
		for y in range(4):  # 4 squares = 6" in game terms
			deployment_zones.player.append(Vector2(x, y + 20))
	
	# Enemy deployment zone (usually top 6" of the battlefield)
	for x in range(24):
		for y in range(4):
			deployment_zones.enemy.append(Vector2(x, y))
	
	# Objective zones (middle of the battlefield)
	for x in range(8, 16):
		for y in range(8, 16):
			deployment_zones.objectives.append(Vector2(x, y))

func _update_ui() -> void:
	# Update UI based on current mode
	$HSplitContainer/ControlPanel/VBoxContainer/ToolPanel.visible = (current_mode == BattlefieldMode.SETUP)
	_update_info_panel()
	_update_highlights()

func _update_info_panel() -> void:
	var info_text = ""
	match current_mode:
		BattlefieldMode.SETUP:
			info_text = "[b]Setup Mode[/b]\n"
			info_text += "Place terrain on the battlefield.\n"
			info_text += "Selected tool: " + TerrainType.keys()[selected_tool] + "\n"
			info_text += "\nTerrain pieces: " + str(terrain_data.size()) + "/12"
		BattlefieldMode.PREVIEW:
			info_text = "[b]Preview Mode[/b]\n"
			info_text += "Review battlefield layout.\n"
			info_text += "Click Confirm to proceed to deployment."
		BattlefieldMode.DEPLOY:
			info_text = "[b]Deployment Mode[/b]\n"
			info_text += "Deploy your units in the highlighted zone.\n"
			info_text += "Remember base movement is " + str(MOVEMENT_BASE) + " inches."
	
	info_content.text = info_text

func _update_highlights() -> void:
	# Clear existing highlights
	for child in highlights.get_children():
		child.queue_free()
	
	match current_mode:
		BattlefieldMode.DEPLOY:
			_highlight_deployment_zones()

func _highlight_deployment_zones() -> void:
	for pos in deployment_zones.player:
		_add_highlight(pos, Color(0, 1, 0, 0.2))  # Green for player
	for pos in deployment_zones.enemy:
		_add_highlight(pos, Color(1, 0, 0, 0.2))  # Red for enemy
	for pos in deployment_zones.objectives:
		_add_highlight(pos, Color(1, 1, 0, 0.2))  # Yellow for objectives

func _add_highlight(pos: Vector2, color: Color) -> void:
	var highlight = ColorRect.new()
	highlight.size = Vector2(GRID_SIZE, GRID_SIZE)
	highlight.position = pos * GRID_SIZE
	highlight.color = color
	highlights.add_child(highlight)

func _show_error(message: String) -> void:
	info_content.text = "[color=red]Error: " + message + "[/color]"

func _validate_deployment() -> bool:
	# Implement deployment validation according to Core Rules
	return true  # Placeholder

func _save_terrain_data() -> void:
	# Save current terrain configuration
	pass

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(event.position)

func _handle_click(click_pos: Vector2) -> void:
	var viewport_pos = battlefield_view.get_local_mouse_position()
	var grid_pos = (viewport_pos / GRID_SIZE).floor()
	
	if grid_data.has(grid_pos):
		match current_mode:
			BattlefieldMode.SETUP:
				_handle_setup_click(grid_pos)
			BattlefieldMode.DEPLOY:
				_handle_deployment_click(grid_pos)

func _handle_setup_click(grid_pos: Vector2) -> void:
	if grid_data[grid_pos].terrain == null:
		_place_terrain(grid_pos, selected_tool)
	else:
		_remove_terrain(grid_pos)

func _handle_deployment_click(grid_pos: Vector2) -> void:
	if grid_pos in deployment_zones.player and grid_data[grid_pos].unit == null:
		_place_unit(grid_pos)

func _place_terrain(pos: Vector2, type: TerrainType) -> void:
	if terrain_data.size() >= 12:
		_show_error("Maximum terrain limit reached")
		return
		
	var terrain_node = _create_terrain_node(type)
	terrain_node.position = pos * GRID_SIZE
	terrain.add_child(terrain_node)
	
	grid_data[pos].terrain = type
	terrain_data.append({"position": pos, "type": type})
	
	_update_info_panel()

func _remove_terrain(pos: Vector2) -> void:
	if grid_data[pos].terrain != null:
		# Remove visual node
		for child in terrain.get_children():
			if child.position == pos * GRID_SIZE:
				child.queue_free()
				break
		
		# Remove from data
		grid_data[pos].terrain = null
		for i in range(terrain_data.size()):
			if terrain_data[i].position == pos:
				terrain_data.remove_at(i)
				break
		
		_update_info_panel()

func _create_terrain_node(type: TerrainType) -> Node2D:
	var node = ColorRect.new()
	node.size = Vector2(GRID_SIZE, GRID_SIZE)
	
	match type:
		TerrainType.COVER:
			node.color = Color(0, 0.7, 0, 0.5)
		TerrainType.BUILDING:
			node.color = Color(0.7, 0.7, 0.7, 0.5)
		TerrainType.ELEVATED:
			node.color = Color(0.7, 0.5, 0, 0.5)
		TerrainType.HAZARD:
			node.color = Color(1, 0, 0, 0.5)
	
	return node

func _place_unit(pos: Vector2) -> void:
	# Implement unit placement logic
	pass 