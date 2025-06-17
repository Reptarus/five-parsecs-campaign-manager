@tool
class_name FPCM_BattlefieldDisplayManager
extends Control

## Battlefield Display Manager - Tabletop Assistant Style
##
## This system provides visual aids for running Five Parsecs battles
## without crossing into video game territory. Think "digital game master screen"
## rather than tactical video game interface.
##
## Features:
## - Rule-based map generation with printable layouts
## - Enemy/objective tracking with simple status indicators
## - Line-of-sight and range calculation aids
## - Battle event integration with visual cues

# Dependencies
const BattlefieldManager = preload("res://src/core/battle/BattlefieldManager.gd")
const BattleEventsSystem = preload("res://src/core/battle/BattleEventsSystem.gd")
const TerrainTypes = preload("res://src/core/terrain/TerrainTypes.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Signals
signal map_generated(map_data: Dictionary)
signal enemy_status_updated(enemy_id: String, status: Dictionary)
signal objective_status_updated(objective_id: String, status: Dictionary)
signal measurement_tool_activated(from: Vector2, to: Vector2, distance: float)
signal battle_event_displayed(event: Dictionary)

# UI Components
@onready var battlefield_grid: Control = $BattlefieldContainer/GridDisplay
@onready var legend_panel: Panel = $LegendPanel
@onready var tracker_panel: Panel = $TrackerPanel
@onready var info_panel: Panel = $InfoPanel
@onready var measurement_tool: Control = $MeasurementTool

# Core managers
var battlefield_manager: BattlefieldManager
var battle_events: BattleEventsSystem

# Display properties
var grid_size: Vector2i = Vector2i(20, 20)
var cell_pixel_size: int = 32
var show_grid: bool = true
var show_measurements: bool = true
var display_mode: String = "overview" # "overview", "tactical", "reference"

# NEW: Measurement system support
var measurement_mode: String = "grid" # "grid", "freeform", "both"
var grid_scale: float = 1.0 # 1 grid = 1 inch by default
var use_inches: bool = true # Five Parsecs standard
var snap_to_grid: bool = true # For grid mode

# NEW: Visual fidelity options
var visual_style: String = "enhanced" # "ascii", "simple", "enhanced", "detailed"
var use_terrain_sprites: bool = true
var show_cover_overlays: bool = true
var animate_markers: bool = false # Keep false for tabletop feel

# Tracking data
var enemy_markers: Dictionary = {}
var objective_markers: Dictionary = {}
var environmental_hazards: Array = []
var measurement_points: Array = []

# Visual theme - tabletop style
var color_scheme: Dictionary = {
	"background": Color(0.9, 0.9, 0.85), # Cream paper
	"grid_lines": Color(0.7, 0.7, 0.6), # Light brown
	"terrain_open": Color(0.95, 0.95, 0.9), # Almost white
	"terrain_cover": Color(0.6, 0.4, 0.2), # Brown
	"terrain_building": Color(0.4, 0.4, 0.4), # Gray
	"enemy_active": Color(0.8, 0.2, 0.2), # Red
	"enemy_inactive": Color(0.5, 0.5, 0.5), # Gray
	"objective_pending": Color(0.2, 0.2, 0.8), # Blue
	"objective_complete": Color(0.2, 0.8, 0.2) # Green
}

func _ready():
	_initialize_display()
	_setup_ui_layout()

## Initialize the display system
func _initialize_display() -> void:
	# Connect to core systems if available
	if has_node("/root/BattlefieldManager"):
		battlefield_manager = get_node("/root/BattlefieldManager")
		_connect_battlefield_signals()
	
	if has_node("/root/BattleEventsSystem"):
		var events_node = get_node("/root/BattleEventsSystem")
		if events_node is BattleEventsSystem:
			battle_events = events_node as BattleEventsSystem
			_connect_battle_events_signals()

## Setup UI layout for tabletop assistant style
func _setup_ui_layout() -> void:
	# Main battlefield display area
	battlefield_grid.custom_minimum_size = Vector2(grid_size.x * cell_pixel_size, grid_size.y * cell_pixel_size)
	
	# Legend panel shows terrain types and symbols
	_create_legend_panel()
	
	# Tracker panel for enemies and objectives
	_create_tracker_panel()
	
	# Info panel for rules references and calculations
	_create_info_panel()

## Generate battlefield map from mission data
func generate_battlefield_map(mission_data: Dictionary) -> Dictionary:
	var map_data = {
		"terrain_layout": [],
		"deployment_zones": {},
		"special_features": [],
		"suggested_setup": "",
		"print_friendly": true
	}
	
	# Use existing battlefield manager to generate terrain
	if battlefield_manager:
		var terrain_type = mission_data.get("terrain_type", "standard")
		var density = mission_data.get("terrain_density", 0.3)
		
		battlefield_manager.generate_terrain(terrain_type, density)
		battlefield_manager.generate_deployment_zones(2)
		
		# Convert to display-friendly format
		map_data = _convert_battlefield_to_display(battlefield_manager)
	
	# Add rule-based special features
	map_data.special_features = _generate_special_features(mission_data)
	
	# Generate setup suggestions
	map_data.suggested_setup = _generate_setup_instructions(map_data, mission_data)
	
	map_generated.emit(map_data)
	return map_data

## Convert battlefield manager data to display format
func _convert_battlefield_to_display(manager: BattlefieldManager) -> Dictionary:
	var display_data = {
		"grid_size": Vector2i(manager.battlefield_width, manager.battlefield_height),
		"terrain_layout": [],
		"deployment_zones": {},
		"cover_map": []
	}
	
	# Convert terrain map
	for x in range(manager.battlefield_width):
		display_data.terrain_layout.append([])
		display_data.cover_map.append([])
		for y in range(manager.battlefield_height):
			var terrain_type = manager.terrain_map[x][y]
			var cover_value = manager.cover_map[x][y]
			
			display_data.terrain_layout[x].append({
				"type": terrain_type,
				"symbol": _get_terrain_symbol(terrain_type),
				"description": TerrainTypes.get_display_name(terrain_type)
			})
			
			display_data.cover_map[x].append(cover_value)
	
	# Convert deployment zones
	for team in manager.deployment_zones:
		display_data.deployment_zones[team] = manager.deployment_zones[team]
	
	return display_data

## Add enemy to battlefield tracking
func add_enemy_marker(enemy_id: String, enemy_data: Dictionary) -> void:
	var marker = {
		"id": enemy_id,
		"name": enemy_data.get("name", "Enemy"),
		"type": enemy_data.get("type", "basic"),
		"position": enemy_data.get("position", Vector2.ZERO),
		"health": enemy_data.get("health", 1),
		"max_health": enemy_data.get("max_health", 1),
		"status": "active", # "active", "stunned", "down", "removed"
		"special_rules": enemy_data.get("special_rules", []),
		"activated": false
	}
	
	enemy_markers[enemy_id] = marker
	_update_tracker_display()
	enemy_status_updated.emit(enemy_id, marker)

## Update enemy status (health, position, activation, etc.)
func update_enemy_status(enemy_id: String, updates: Dictionary) -> void:
	if enemy_id not in enemy_markers:
		return
	
	var marker = enemy_markers[enemy_id]
	
	# Apply updates
	for key in updates:
		if key in marker:
			marker[key] = updates[key]
	
	# Handle special status changes
	if "health" in updates:
		if marker.health <= 0:
			marker.status = "down"
		elif marker.status == "down" and marker.health > 0:
			marker.status = "active"
	
	_update_tracker_display()
	enemy_status_updated.emit(enemy_id, marker)

## Add objective marker to battlefield
func add_objective_marker(objective_id: String, objective_data: Dictionary) -> void:
	var marker = {
		"id": objective_id,
		"title": objective_data.get("title", "Objective"),
		"description": objective_data.get("description", ""),
		"position": objective_data.get("position", Vector2.ZERO),
		"status": "pending", # "pending", "in_progress", "completed", "failed"
		"value": objective_data.get("value", 1),
		"conditions": objective_data.get("conditions", [])
	}
	
	objective_markers[objective_id] = marker
	_update_tracker_display()
	objective_status_updated.emit(objective_id, marker)

## Update objective status
func update_objective_status(objective_id: String, new_status: String) -> void:
	if objective_id not in objective_markers:
		return
	
	objective_markers[objective_id].status = new_status
	_update_tracker_display()
	objective_status_updated.emit(objective_id, objective_markers[objective_id])

## Display battle event with visual cues
func display_battle_event(event: Dictionary) -> void:
	# Add visual indicator to battlefield if event has location
	if "position" in event:
		_add_temporary_marker(event.position, "event", event.get("title", "Event"))
	
	# Update info panel with event details
	_show_event_info(event)
	
	battle_event_displayed.emit(event)

## Measurement tool for ranges and distances
func activate_measurement_tool(from_pos: Vector2, to_pos: Vector2 = Vector2.ZERO) -> Dictionary:
	var measurement_data = {
		"distance_pixels": 0.0,
		"distance_grid": 0.0,
		"distance_inches": 0.0,
		"line_of_sight": true,
		"cover_modifiers": []
	}
	
	if to_pos != Vector2.ZERO:
		# Snap positions if in grid mode
		var snapped_from = should_snap_to_grid(from_pos)
		var snapped_to = should_snap_to_grid(to_pos)
		
		# Calculate distances
		measurement_data.distance_pixels = snapped_from.distance_to(snapped_to)
		measurement_data.distance_grid = measurement_data.distance_pixels / cell_pixel_size
		measurement_data.distance_inches = measurement_data.distance_grid * grid_scale
		
		# Check line of sight if battlefield manager available
		if battlefield_manager:
			measurement_data.line_of_sight = _check_line_of_sight(snapped_from, snapped_to)
			measurement_data.cover_modifiers = _get_cover_along_path(snapped_from, snapped_to)
		
		_display_measurement_info(measurement_data)
		measurement_tool_activated.emit(snapped_from, snapped_to, measurement_data.distance_inches)
	
	return measurement_data

## Generate printable battlefield reference
func generate_printable_map() -> Dictionary:
	var printable = {
		"title": "Five Parsecs Battlefield Layout",
		"grid_data": _get_simplified_grid(),
		"legend": _get_terrain_legend(),
		"deployment_zones": _get_deployment_info(),
		"special_rules": _get_battlefield_special_rules(),
		"setup_notes": _get_setup_notes()
	}
	
	return printable

## Private helper methods

func _connect_battlefield_signals() -> void:
	if battlefield_manager:
		battlefield_manager.terrain_updated.connect(_on_terrain_updated)
		battlefield_manager.battlefield_generated.connect(_on_battlefield_generated)

func _connect_battle_events_signals() -> void:
	if battle_events:
		battle_events.battle_event_triggered.connect(_on_battle_event_triggered)
		battle_events.environmental_hazard_activated.connect(_on_environmental_hazard)

func _create_legend_panel() -> void:
	# Create terrain symbol legend
	pass

func _create_tracker_panel() -> void:
	# Create enemy and objective tracking interface
	pass

func _create_info_panel() -> void:
	# Create rules reference and calculation area
	pass

func _get_terrain_symbol(terrain_type: int) -> String:
	match terrain_type:
		TerrainTypes.Type.EMPTY:
			return "."
		TerrainTypes.Type.COVER_LOW:
			return "◊"
		TerrainTypes.Type.COVER_HIGH:
			return "█"
		TerrainTypes.Type.BUILDING:
			return "■"
		TerrainTypes.Type.WATER:
			return "~"
		TerrainTypes.Type.FOREST:
			return "♠"
		TerrainTypes.Type.OBSTACLE:
			return "●"
		TerrainTypes.Type.DIFFICULT:
			return "▒"
		TerrainTypes.Type.HAZARD:
			return "⚠"
		_:
			return "?"

func _generate_special_features(mission_data: Dictionary) -> Array:
	var features = []
	
	# Add mission-specific features based on Five Parsecs rules
	var mission_type = mission_data.get("type", "standard")
	
	match mission_type:
		"red_zone":
			features.append({"type": "danger_zone", "description": "Increased enemy activity"})
		"black_zone":
			features.append({"type": "restricted", "description": "Heavy security presence"})
		"patron":
			features.append({"type": "objective", "description": "Patron-specific goals"})
	
	return features

func _generate_setup_instructions(map_data: Dictionary, mission_data: Dictionary) -> String:
	var instructions = "Five Parsecs Battlefield Setup:\n\n"
	
	instructions += "1. Place terrain according to map layout\n"
	instructions += "2. Set up deployment zones as marked\n"
	instructions += "3. Roll for encounter generation\n"
	instructions += "4. Place objectives as indicated\n\n"
	
	instructions += "Special Rules:\n"
	for feature in map_data.get("special_features", []):
		instructions += "- " + feature.description + "\n"
	
	return instructions

func _update_tracker_display() -> void:
	# Update the enemy and objective tracking UI
	pass

func _show_event_info(event: Dictionary) -> void:
	# Display battle event information in info panel
	pass

func _add_temporary_marker(position: Vector2, type: String, label: String) -> void:
	# Add temporary visual marker (auto-removes after a few seconds)
	pass

func _display_measurement(from: Vector2, to: Vector2, distance: float) -> void:
	# Show measurement line and distance
	pass

## Signal handlers
func _on_terrain_updated(position: Vector2, terrain_type: int) -> void:
	# Refresh display when terrain changes
	queue_redraw()

func _on_battlefield_generated(width: int, height: int) -> void:
	grid_size = Vector2i(width, height)
	_setup_ui_layout()
	queue_redraw()

func _on_battle_event_triggered(event) -> void:
	display_battle_event({
		"title": event.title,
		"description": event.description,
		"effects": event.effects
	})

func _on_environmental_hazard(hazard) -> void:
	environmental_hazards.append(hazard)
	_update_tracker_display()

## Helper methods for printable content
func _get_simplified_grid() -> Array:
	var grid = []
	# Convert battlefield to simple symbols for printing
	return grid

func _get_terrain_legend() -> Dictionary:
	return {
		".": "Open Ground",
		"◊": "Light Cover",
		"█": "Heavy Cover",
		"■": "Building",
		"~": "Water/Liquid",
		"♠": "Forest/Vegetation",
		"●": "Obstacle",
		"▒": "Difficult Terrain",
		"⚠": "Hazard"
	}

func _get_deployment_info() -> Array:
	var zones = []
	# Return deployment zone information
	return zones

func _get_battlefield_special_rules() -> Array:
	var rules = []
	# Return any special battlefield rules in effect
	return rules

func _get_setup_notes() -> String:
	return "Place miniatures in deployment zones. Use measurement tool for ranges."

## Missing helper methods (stubs to be implemented)
func _check_line_of_sight(from: Vector2, to: Vector2) -> bool:
	# TODO: Implement line of sight calculation
	return true

func _get_cover_along_path(from: Vector2, to: Vector2) -> Array:
	# TODO: Implement cover calculation along path
	return []

func _display_measurement_info(measurement_data: Dictionary) -> void:
	# TODO: Display measurement information in UI
	pass

func _get_terrain_layers(terrain_type: int) -> Array:
	# TODO: Return parallax layers for detailed terrain
	return []

func _get_terrain_effects(terrain_type: int) -> Array:
	# TODO: Return visual effects for terrain
	return []

func _refresh_visual_display() -> void:
	# TODO: Refresh the battlefield display with new visual style
	queue_redraw()

func _update_measurement_tools() -> void:
	# TODO: Update measurement tool behavior based on mode
	pass

## Get terrain visual representation based on visual style
func get_terrain_visual(terrain_type: int, visual_style: String = "") -> Dictionary:
	if visual_style == "":
		visual_style = self.visual_style
	
	var base_data = {
		"type": terrain_type,
		"symbol": _get_terrain_symbol(terrain_type),
		"description": TerrainTypes.get_display_name(terrain_type),
		"color": _get_terrain_color(terrain_type)
	}
	
	match visual_style:
		"ascii":
			return {
				"display_type": "text",
				"symbol": base_data.symbol,
				"color": Color.BLACK,
				"background": Color.WHITE
			}
		
		"simple":
			return {
				"display_type": "shape",
				"shape": _get_terrain_shape(terrain_type),
				"color": base_data.color,
				"border_color": Color.BLACK,
				"symbol_overlay": base_data.symbol
			}
		
		"enhanced":
			return {
				"display_type": "sprite",
				"texture_path": _get_terrain_texture_path(terrain_type),
				"fallback_shape": _get_terrain_shape(terrain_type),
				"color_overlay": base_data.color,
				"symbol_overlay": base_data.symbol
			}
		
		"detailed":
			return {
				"display_type": "sprite",
				"texture_path": _get_detailed_texture_path(terrain_type),
				"parallax_layers": _get_terrain_layers(terrain_type),
				"effects": _get_terrain_effects(terrain_type)
			}
		
		_:
			return base_data

## Get terrain color for visual modes
func _get_terrain_color(terrain_type: int) -> Color:
	match terrain_type:
		TerrainTypes.Type.EMPTY:
			return Color(0.95, 0.95, 0.9) # Almost white
		TerrainTypes.Type.COVER_LOW:
			return Color(0.7, 0.5, 0.3) # Light brown
		TerrainTypes.Type.COVER_HIGH:
			return Color(0.5, 0.3, 0.2) # Dark brown
		TerrainTypes.Type.BUILDING:
			return Color(0.6, 0.6, 0.6) # Gray
		TerrainTypes.Type.WATER:
			return Color(0.3, 0.5, 0.8) # Blue
		TerrainTypes.Type.FOREST:
			return Color(0.2, 0.6, 0.3) # Green
		TerrainTypes.Type.OBSTACLE:
			return Color(0.4, 0.4, 0.4) # Dark gray
		TerrainTypes.Type.DIFFICULT:
			return Color(0.8, 0.7, 0.4) # Yellow-brown
		TerrainTypes.Type.HAZARD:
			return Color(0.8, 0.3, 0.3) # Red
		_:
			return Color.WHITE

## Get terrain shape for simple/enhanced modes
func _get_terrain_shape(terrain_type: int) -> String:
	match terrain_type:
		TerrainTypes.Type.EMPTY:
			return "none"
		TerrainTypes.Type.COVER_LOW:
			return "circle"
		TerrainTypes.Type.COVER_HIGH:
			return "square"
		TerrainTypes.Type.BUILDING:
			return "rectangle"
		TerrainTypes.Type.WATER:
			return "wavy"
		TerrainTypes.Type.FOREST:
			return "triangle"
		TerrainTypes.Type.OBSTACLE:
			return "hexagon"
		TerrainTypes.Type.DIFFICULT:
			return "dotted_square"
		TerrainTypes.Type.HAZARD:
			return "warning_triangle"
		_:
			return "square"

## Get texture paths for sprite-based modes
func _get_terrain_texture_path(terrain_type: int) -> String:
	var base_path = "res://assets/terrain/simple/"
	
	match terrain_type:
		TerrainTypes.Type.EMPTY:
			return base_path + "open_ground.png"
		TerrainTypes.Type.COVER_LOW:
			return base_path + "light_cover.png"
		TerrainTypes.Type.COVER_HIGH:
			return base_path + "heavy_cover.png"
		TerrainTypes.Type.BUILDING:
			return base_path + "building.png"
		TerrainTypes.Type.WATER:
			return base_path + "water.png"
		TerrainTypes.Type.FOREST:
			return base_path + "forest.png"
		TerrainTypes.Type.OBSTACLE:
			return base_path + "obstacle.png"
		TerrainTypes.Type.DIFFICULT:
			return base_path + "difficult.png"
		TerrainTypes.Type.HAZARD:
			return base_path + "hazard.png"
		_:
			return base_path + "default.png"

## Get detailed texture paths for high-fidelity mode
func _get_detailed_texture_path(terrain_type: int) -> String:
	var base_path = "res://assets/terrain/detailed/"
	# Similar to above but pointing to higher-detail assets
	return base_path + "detailed_" + str(terrain_type) + ".png"

## Set visual style and update display
func set_visual_style(new_style: String) -> void:
	if new_style in ["ascii", "simple", "enhanced", "detailed"]:
		visual_style = new_style
		_refresh_visual_display()

## Set measurement mode
func set_measurement_mode(new_mode: String) -> void:
	if new_mode in ["grid", "freeform", "both"]:
		measurement_mode = new_mode
		_update_measurement_tools()

## Check if position snaps to grid based on current mode
func should_snap_to_grid(position: Vector2) -> Vector2:
	if measurement_mode == "grid" and snap_to_grid:
		var grid_pos = Vector2i(
			round(position.x / cell_pixel_size),
			round(position.y / cell_pixel_size)
		)
		return Vector2(grid_pos.x * cell_pixel_size, grid_pos.y * cell_pixel_size)
	else:
		return position
