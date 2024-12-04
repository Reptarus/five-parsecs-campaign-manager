extends PanelContainer

signal terrain_regenerated
signal map_exported_as_png
signal map_exported_as_json
signal cell_selected(cell_pos: Vector2i)

const TerrainTypes = preload("res://Battle/TerrainTypes.gd")

@onready var battlefield_grid = %BattlefieldGrid
@onready var map_legend = %MapLegend
@onready var regenerate_button = %RegenerateButton
@onready var export_png_button = %ExportPNGButton
@onready var export_json_button = %ExportJSONButton
@onready var grid_overlay = %GridOverlay
@onready var visualization_options = %VisualizationOptions
@onready var info_label = %InfoLabel
@onready var terrain_analysis = %TerrainAnalysis
@onready var cover_value = %CoverValue
@onready var movement_value = %MovementValue
@onready var height_value = %HeightValue
@onready var los_value = %LOSValue

var cell_size := Vector2(32, 32)
var grid_size := Vector2(24, 24)
var current_battlefield_data: Dictionary
var selected_cell: Vector2i = Vector2i(-1, -1)
var hover_cell: Vector2i = Vector2i(-1, -1)
var current_visualization: String = "terrain"

# Terrain visualization colors with height variations
const TERRAIN_COLORS = {
	TerrainTypes.Type.EMPTY: Color(0.3, 0.6, 0.3, 1.0),      # Green for empty
	TerrainTypes.Type.WALL: Color(0.2, 0.2, 0.2, 1.0),       # Dark gray for walls
	TerrainTypes.Type.COVER_LOW: Color(0.5, 0.5, 0.5, 1.0),  # Gray for low cover
	TerrainTypes.Type.COVER_HIGH: Color(0.4, 0.4, 0.4, 1.0), # Darker gray for high cover
	TerrainTypes.Type.DIFFICULT: Color(0.7, 0.4, 0.1, 1.0),  # Brown for difficult
	TerrainTypes.Type.HAZARDOUS: Color(0.8, 0.2, 0.2, 1.0),  # Red for hazardous
	TerrainTypes.Type.ELEVATED: Color(0.6, 0.6, 0.8, 1.0),   # Blue-gray for elevated
	TerrainTypes.Type.WATER: Color(0.2, 0.4, 0.8, 1.0),      # Blue for water
}

const DEPLOYMENT_COLORS = {
	"player": Color(0.2, 0.7, 0.2, 0.3),    # Green transparent for player
	"enemy": Color(0.7, 0.2, 0.2, 0.3),     # Red transparent for enemy
	"objective": Color(0.7, 0.7, 0.2, 0.3),  # Yellow transparent for objectives
}

# Height visualization settings
const HEIGHT_COLORS = {
	-1: Color(0.2, 0.3, 0.7),  # Below ground (water)
	0: Color(0.3, 0.6, 0.3),   # Ground level
	1: Color(0.5, 0.5, 0.5),   # Low elevation
	2: Color(0.7, 0.7, 0.7),   # Medium elevation
	3: Color(0.9, 0.9, 0.9),   # High elevation
}

# Line of sight visualization
const LOS_COLORS = {
	"clear": Color(0.2, 0.8, 0.2, 0.3),     # Green for clear line of sight
	"partial": Color(0.8, 0.8, 0.2, 0.3),   # Yellow for partial cover
	"blocked": Color(0.8, 0.2, 0.2, 0.3),   # Red for blocked line of sight
}

func _ready() -> void:
	setup_buttons()
	setup_grid()
	setup_visualization_options()
	setup_input()
	terrain_analysis.hide()

func setup_buttons() -> void:
	regenerate_button.pressed.connect(_on_regenerate_pressed)
	export_png_button.pressed.connect(_on_export_png_pressed)
	export_json_button.pressed.connect(_on_export_json_pressed)

func setup_grid() -> void:
	battlefield_grid.custom_minimum_size = grid_size * cell_size
	_draw_grid_overlay()

func setup_visualization_options() -> void:
	visualization_options.clear()
	visualization_options.add_item("Terrain")
	visualization_options.add_item("Height Map")
	visualization_options.add_item("Line of Sight")
	visualization_options.add_item("Movement Cost")
	visualization_options.add_item("Cover Values")
	visualization_options.item_selected.connect(_on_visualization_changed)

func setup_input() -> void:
	battlefield_grid.gui_input.connect(_on_grid_input)
	battlefield_grid.mouse_entered.connect(_on_grid_mouse_entered)
	battlefield_grid.mouse_exited.connect(_on_grid_mouse_exited)

func update_preview(battlefield_data: Dictionary) -> void:
	current_battlefield_data = battlefield_data
	_clear_grid()
	_update_visualization()
	_update_grid_overlay()
	_update_info_label()

func _clear_grid() -> void:
	for child in battlefield_grid.get_children():
		if child != grid_overlay:
			child.queue_free()

func _update_visualization() -> void:
	match current_visualization:
		"terrain":
			_draw_terrain()
			_draw_objectives()
			_draw_deployment_zones()
		"height":
			_draw_height_map()
		"los":
			_draw_line_of_sight()
		"movement":
			_draw_movement_costs()
		"cover":
			_draw_cover_values()

func _draw_terrain() -> void:
	for terrain in current_battlefield_data.terrain:
		var terrain_rect = ColorRect.new()
		terrain_rect.size = cell_size
		terrain_rect.position = terrain.position * cell_size
		terrain_rect.color = TERRAIN_COLORS.get(terrain.type, Color.WHITE)
		
		# Add height shading
		var height = TerrainTypes.get_elevation(terrain.type)
		if height != 0:
			var shade = 1.0 + (height * 0.1)  # Adjust brightness based on height
			terrain_rect.color = terrain_rect.color * Color(shade, shade, shade, 1.0)
		
		# Add tooltip for terrain information
		var tooltip = _get_terrain_tooltip(terrain)
		terrain_rect.tooltip_text = tooltip
		
		battlefield_grid.add_child(terrain_rect)

func _draw_height_map() -> void:
	for terrain in current_battlefield_data.terrain:
		var height = TerrainTypes.get_elevation(terrain.type)
		var height_rect = ColorRect.new()
		height_rect.size = cell_size
		height_rect.position = terrain.position * cell_size
		height_rect.color = HEIGHT_COLORS.get(height, Color.WHITE)
		
		var tooltip = "Height: %d" % height
		height_rect.tooltip_text = tooltip
		
		battlefield_grid.add_child(height_rect)

func _draw_line_of_sight() -> void:
	if selected_cell == Vector2i(-1, -1):
		return
		
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var target_pos = Vector2i(x, y)
			var los_rect = ColorRect.new()
			los_rect.size = cell_size
			los_rect.position = Vector2(target_pos) * cell_size
			
			var los_status = _check_line_of_sight(selected_cell, target_pos)
			los_rect.color = LOS_COLORS[los_status]
			
			battlefield_grid.add_child(los_rect)

func _draw_movement_costs() -> void:
	for terrain in current_battlefield_data.terrain:
		var cost_rect = ColorRect.new()
		cost_rect.size = cell_size
		cost_rect.position = terrain.position * cell_size
		
		var movement_cost = TerrainTypes.get_movement_cost(terrain.type)
		var cost_color = Color.GREEN.lerp(Color.RED, movement_cost / 3.0)
		cost_rect.color = cost_color.darkened(0.2)
		
		var tooltip = "Movement Cost: %.1f" % movement_cost
		cost_rect.tooltip_text = tooltip
		
		battlefield_grid.add_child(cost_rect)

func _draw_cover_values() -> void:
	for terrain in current_battlefield_data.terrain:
		var cover_rect = ColorRect.new()
		cover_rect.size = cell_size
		cover_rect.position = terrain.position * cell_size
		
		var cover_value = TerrainTypes.get_cover_value(terrain.type)
		var cover_color = Color.RED.lerp(Color.GREEN, float(cover_value) / 4.0)
		cover_rect.color = cover_color.darkened(0.2)
		
		var tooltip = "Cover Value: %d" % cover_value
		cover_rect.tooltip_text = tooltip
		
		battlefield_grid.add_child(cover_rect)

func _draw_objectives() -> void:
	for objective in current_battlefield_data.objectives:
		var icon = TextureRect.new()
		icon.texture = load("res://Assets/Icons/%s.png" % objective.type)
		icon.position = objective.position * cell_size
		icon.tooltip_text = "Objective: %s" % objective.type.capitalize()
		battlefield_grid.add_child(icon)

func _draw_deployment_zones() -> void:
	for zone in current_battlefield_data.deployment_zones:
		var zone_rect = ColorRect.new()
		zone_rect.size = zone.size * cell_size
		zone_rect.position = zone.position * cell_size
		zone_rect.color = DEPLOYMENT_COLORS.get(zone.type, Color(0.2, 0.2, 1.0, 0.3))
		zone_rect.tooltip_text = "%s Deployment Zone" % zone.type.capitalize()
		battlefield_grid.add_child(zone_rect)

func _get_terrain_tooltip(terrain: Dictionary) -> String:
	var type_name = TerrainTypes.Type.keys()[terrain.type].capitalize()
	var properties = TerrainTypes.TERRAIN_PROPERTIES[terrain.type]
	return "%s\nCover: %d\nMovement Cost: %.1f\nElevation: %d" % [
		type_name,
		properties.cover_value,
		properties.movement_cost,
		properties.elevation
	]

func _check_line_of_sight(from: Vector2i, to: Vector2i) -> String:
	var line = _get_line(from, to)
	var total_cover = 0
	var blocked = false
	
	for point in line:
		for terrain in current_battlefield_data.terrain:
			if terrain.position == point:
				if TerrainTypes.blocks_los(terrain.type):
					blocked = true
					break
				total_cover += TerrainTypes.get_cover_value(terrain.type)
	
	if blocked:
		return "blocked"
	elif total_cover > 0:
		return "partial"
	else:
		return "clear"

func _get_line(from: Vector2i, to: Vector2i) -> Array:
	var points = []
	var dx = abs(to.x - from.x)
	var dy = abs(to.y - from.y)
	var x = from.x
	var y = from.y
	var n = 1 + dx + dy
	var x_inc = 1 if to.x > from.x else -1
	var y_inc = 1 if to.y > from.y else -1
	var error = dx - dy
	dx *= 2
	dy *= 2
	
	for _i in range(n):
		points.append(Vector2i(x, y))
		if error > 0:
			x += x_inc
			error -= dy
		else:
			y += y_inc
			error += dx
	
	return points

func _update_terrain_analysis(cell_pos: Vector2i) -> void:
	var terrain_found = false
	for terrain in current_battlefield_data.terrain:
		if terrain.position == Vector2(cell_pos):
			terrain_found = true
			cover_value.text = str(TerrainTypes.get_cover_value(terrain.type))
			movement_value.text = "%.1f" % TerrainTypes.get_movement_cost(terrain.type)
			height_value.text = str(TerrainTypes.get_elevation(terrain.type))
			los_value.text = "Yes" if TerrainTypes.blocks_los(terrain.type) else "No"
			break
	
	if not terrain_found:
		cover_value.text = "0"
		movement_value.text = "1.0"
		height_value.text = "0"
		los_value.text = "No"
	
	terrain_analysis.show()

func _update_info_label() -> void:
	match current_visualization:
		"terrain":
			info_label.text = "Click a cell to analyze terrain"
		"height":
			info_label.text = "Analyzing terrain elevation"
		"los":
			info_label.text = "Click a cell to check line of sight"
		"movement":
			info_label.text = "Analyzing movement costs"
		"cover":
			info_label.text = "Analyzing cover values"

func _on_visualization_changed(index: int) -> void:
	current_visualization = visualization_options.get_item_text(index).to_lower()
	_update_visualization()
	_update_info_label()

func _on_grid_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var cell_pos = Vector2i((event.position / cell_size).floor())
		if _is_valid_cell(cell_pos):
			selected_cell = cell_pos
			cell_selected.emit(cell_pos)
			_update_visualization()
			_update_grid_overlay()
			_update_terrain_analysis(cell_pos)

func _on_grid_mouse_entered() -> void:
	pass

func _on_grid_mouse_exited() -> void:
	hover_cell = Vector2i(-1, -1)
	_update_grid_overlay()

func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_size.x and cell.y >= 0 and cell.y < grid_size.y

func _on_regenerate_pressed() -> void:
	terrain_regenerated.emit()

func _on_export_png_pressed() -> void:
	map_exported_as_png.emit()

func _on_export_json_pressed() -> void:
	map_exported_as_json.emit()
