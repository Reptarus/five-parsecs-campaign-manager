@tool
extends Node
# This class should be referenced using preload or load instead of class_name
# to avoid conflicts with global script classes

## A unified system for managing terrain in a grid-based environment
##
## This system handles all terrain-related operations including placement,
## modification, removal, and effects. It manages terrain types, features,
## and associated gameplay effects like movement costs and cover.
##
## @tutorial: To use this system, add it as a child node to your scene and
## connect to its signals to react to terrain changes.

## Dependencies - explicit loading to avoid circular references
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const TerrainTypes = preload("res://src/core/terrain/TerrainTypes.gd")
const TerrainRules = preload("res://src/core/terrain/TerrainRules.gd")
const TerrainEffectSystem = preload("res://src/core/terrain/TerrainEffectSystem.gd")

## Terrain type enum definition
enum TerrainType {
	EMPTY = 0,
	GRASS = 1,
	DIRT = 2,
	ROCK = 3,
	WATER = 4,
	SAND = 5,
	SNOW = 6,
	URBAN = 7
}

## Signal emitted when terrain is placed in the grid
## @param position: The grid position where terrain was placed
## @param terrain_type: The type of terrain that was placed
signal terrain_placed(position: Vector2i, terrain_type: int)

## Signal emitted when terrain is modified
## @param position: The grid position where terrain was modified
## @param old_type: The previous terrain type
## @param new_type: The new terrain type
signal terrain_modified(position: Vector2i, old_type: int, new_type: int)

## Signal emitted when terrain is removed from the grid
## @param position: The grid position where terrain was removed
signal terrain_removed(position: Vector2i)

## Signal emitted when a terrain effect is applied to a target
## @param target_id: ID of the target receiving the effect
## @param effect_type: Type of effect being applied
## @param strength: Strength of the effect
signal terrain_effect_applied(target_id: int, effect_type: int, strength: float)

## Signal emitted when a terrain effect is removed from a target
## @param target_id: ID of the target losing the effect
## @param effect_type: Type of effect being removed
signal terrain_effect_removed(target_id: int, effect_type: int)

## Dictionary mapping grid positions (Vector2i) to terrain data
## The data structure for each terrain cell is:
## {
##   "type": int,              # Terrain type enum value
##   "feature_type": int,      # Optional feature type enum value
##   "effects": Array[Dict]    # List of active effects on this terrain
## }
var terrain_map: Dictionary = {}

## Reference to the terrain effect system component
var terrain_effect_system: TerrainEffectSystem

## Reference to the terrain rules component
var terrain_rules: TerrainRules

## Grid size for the terrain system (in cells)
var _grid_size: Vector2 = Vector2(20, 20)

## Initialize terrain systems and components
## Creates and initializes the required subsystems
func _init() -> void:
	terrain_effect_system = TerrainEffectSystem.new()
	terrain_rules = TerrainRules.new()
	add_child(terrain_effect_system)

## Connect signals for terrain effect system
## Sets up internal signal connections when the node is ready
func _ready() -> void:
	terrain_effect_system.effect_applied.connect(_on_terrain_effect_applied)
	terrain_effect_system.effect_removed.connect(_on_terrain_effect_removed)

## Place terrain at the specified position
## 
## Places a new terrain cell at the given grid position if the position
## is valid and not already occupied.
##
## @param position: Grid position for terrain placement
## @param terrain_type: Type of terrain to place
## @param feature_type: Optional feature to add to the terrain
## @return: Whether the placement was successful
func place_terrain(position: Vector2i, terrain_type: int, feature_type: int = GameEnums.TerrainFeatureType.NONE) -> bool:
	if not _is_valid_position(position):
		return false
		
	if terrain_map.has(position):
		return false
		
	terrain_map[position] = {
		"type": terrain_type,
		"feature_type": feature_type,
		"effects": []
	}
	
	# Update terrain state in effect system
	terrain_effect_system.update_terrain_state(position, terrain_type, feature_type)
	
	terrain_placed.emit(position, terrain_type)
	return true

## Modify existing terrain at the specified position
## 
## Changes the type or features of existing terrain at the given position.
##
## @param position: Grid position to modify
## @param new_type: New terrain type
## @param feature_type: Optional new feature type
## @return: Whether the modification was successful
func modify_terrain(position: Vector2i, new_type: int, feature_type: int = GameEnums.TerrainFeatureType.NONE) -> bool:
	if not terrain_map.has(position):
		return false
		
	var old_type: int = terrain_map[position].type
	terrain_map[position].type = new_type
	terrain_map[position].feature_type = feature_type
	
	# Update terrain state in effect system
	terrain_effect_system.update_terrain_state(position, new_type, feature_type)
	
	terrain_modified.emit(position, old_type, new_type)
	return true

## Remove terrain at the specified position
## 
## Removes terrain from the specified grid position, clearing any effects.
##
## @param position: Grid position to clear
## @return: Whether the removal was successful
func remove_terrain(position: Vector2i) -> bool:
	if not terrain_map.has(position):
		return false
		
	terrain_map.erase(position)
	terrain_removed.emit(position)
	
	# Clear any terrain effects at this position
	terrain_effect_system.update_terrain_state(position, TerrainTypes.Type.EMPTY, GameEnums.TerrainFeatureType.NONE)
	
	return true

## Get terrain data at the specified position
## 
## Returns the terrain data at the given position, or default values if
## no terrain exists at that position.
##
## @param position: Grid position to query
## @return: Dictionary with terrain data or default values if empty
func get_terrain_at(position: Vector2i) -> Dictionary:
	return terrain_map.get(position, {
		"type": TerrainTypes.Type.EMPTY,
		"feature_type": GameEnums.TerrainFeatureType.NONE,
		"effects": []
	})

## Apply terrain effects to a unit at a position
## 
## Applies the effects of terrain at the specified position to the given unit.
## This handles effects like movement penalties, damage over time, etc.
##
## @param target: Unit to apply effects to
## @param position: Position where the unit is located
func apply_terrain_effect_to_unit(target: Node, position: Vector2i) -> void:
	var state: Dictionary = get_terrain_at(position)
	terrain_effect_system.apply_terrain_effect(target, state.get("type", TerrainTypes.Type.EMPTY), state.get("feature_type", GameEnums.TerrainFeatureType.NONE))

## Remove all terrain effects from a unit
## 
## Clears all terrain-based effects from the specified unit.
##
## @param target: Unit to remove effects from
func remove_terrain_effects_from_unit(target: Node) -> void:
	terrain_effect_system.remove_terrain_effects(target)

## Get the movement cost at a position
## 
## Returns the movement cost for the terrain at the specified position.
## Higher values indicate more difficult terrain to traverse.
##
## @param position: Grid position to query
## @return: Movement cost value (higher means more difficult)
func get_movement_cost(position: Vector2i) -> float:
	return terrain_effect_system.get_movement_cost(position)

## Check if a position provides cover
## 
## Determines whether the terrain at the specified position provides
## defensive cover to units.
##
## @param position: Grid position to query
## @return: Whether the position provides cover
func provides_cover(position: Vector2i) -> bool:
	return terrain_effect_system.provides_cover(position)

## Check if a position is traversable
## 
## Determines whether units can move through the terrain at the
## specified position.
##
## @param position: Grid position to query
## @return: Whether the position can be moved through
func is_traversable(position: Vector2i) -> bool:
	return terrain_effect_system.is_traversable(position)

## Check if a position is elevated
## 
## Determines whether the terrain at the specified position is elevated
## above the normal ground level, providing height advantages.
##
## @param position: Grid position to query
## @return: Whether the position is elevated above normal ground
func is_elevated(position: Vector2i) -> bool:
	return terrain_effect_system.is_elevated(position)

## Check if a position has no terrain
## 
## Determines whether the specified position is empty (has no terrain).
##
## @param position: Grid position to query
## @return: Whether the position is empty
func is_position_empty(position: Vector2i) -> bool:
	return not terrain_map.has(position)

## Set a terrain feature at a position
## 
## Adds or updates a terrain feature at the specified position,
## optionally creating new terrain if none exists.
##
## @param position: Grid position to modify
## @param feature_type: Feature type to set
## @return: Whether the operation was successful
func set_terrain_feature(position: Vector2i, feature_type: int) -> bool:
	if not terrain_map.has(position):
		# Create new terrain with the feature
		return place_terrain(position, TerrainTypes.Type.EMPTY, feature_type)
	else:
		# Modify existing terrain to add the feature
		var current_type: int = terrain_map[position].type
		return modify_terrain(position, current_type, feature_type)

## Get the grid size of the terrain system
## 
## Returns the current size of the terrain grid.
##
## @return: Vector2 representing width and height of the grid in cells
func get_grid_size() -> Vector2:
	return _grid_size

## Set the grid size of the terrain system
## 
## Updates the size of the terrain grid, optionally clearing terrain
## outside the new boundaries.
##
## @param size: New grid size (width and height)
## @param clear_outside: Whether to remove terrain outside new boundaries
func set_grid_size(size: Vector2, clear_outside: bool = false) -> void:
	var old_size: Vector2 = _grid_size
	_grid_size = size
	
	if clear_outside:
		_clear_outside_grid()

## Check if a position is within the valid grid bounds
## 
## Determines whether the specified position is within the
## current grid boundaries.
##
## @param position: Grid position to check
## @return: Whether the position is valid
func _is_valid_position(position: Vector2i) -> bool:
	return position.x >= 0 and position.y >= 0 and position.x < _grid_size.x and position.y < _grid_size.y

## Handle terrain effect application event
## 
## Internal callback for when a terrain effect is applied by the effect system.
##
## @param target_id: ID of the target receiving the effect
## @param effect_type: Type of effect being applied
## @param strength: Strength of the effect
func _on_terrain_effect_applied(target_id: int, effect_type: int, strength: float) -> void:
	terrain_effect_applied.emit(target_id, effect_type, strength)

## Handle terrain effect removal event
## 
## Internal callback for when a terrain effect is removed by the effect system.
##
## @param target_id: ID of the target losing the effect
## @param effect_type: Type of effect being removed
func _on_terrain_effect_removed(target_id: int, effect_type: int) -> void:
	terrain_effect_removed.emit(target_id, effect_type)

## Clear all terrain data
## 
## Removes all terrain from the system, effectively resetting the map.
## Useful for map resets or new campaign generation.
func clear_all() -> void:
	terrain_map.clear()
	terrain_effect_system._terrain_states.clear()
	terrain_effect_system._active_effects.clear()

## Clear terrain outside the current grid bounds
## 
## Internal method to remove terrain that falls outside the current
## grid boundaries after a grid size change.
func _clear_outside_grid() -> void:
	var positions_to_remove: Array[Vector2i] = []
	
	for pos_key in terrain_map:
		var pos: Vector2i = pos_key as Vector2i
		if not _is_valid_position(pos):
			positions_to_remove.append(pos)
	
	for pos in positions_to_remove:
		remove_terrain(pos)

## Serialize terrain system state to a dictionary
## 
## Converts the current terrain system state to a dictionary
## that can be stored or transmitted.
##
## @return: Dictionary containing all terrain system data
func serialize() -> Dictionary:
	var serialized_map := {}
	
	# Convert Vector2i keys to string representations for JSON compatibility
	for pos_key in terrain_map:
		var pos: Vector2i = pos_key as Vector2i
		var key_str := "%d,%d" % [pos.x, pos.y]
		serialized_map[key_str] = terrain_map[pos_key].duplicate(true)
	
	return {
		"grid_size": {
			"x": _grid_size.x,
			"y": _grid_size.y
		},
		"terrain_map": serialized_map,
		"version": 1 # For future compatibility
	}

## Deserialize terrain system state from a dictionary
## 
## Restores the terrain system state from a previously serialized dictionary.
##
## @param data: Dictionary containing terrain system data
## @return: Whether the deserialization was successful
func deserialize(data: Dictionary) -> bool:
	if not data.has("terrain_map") or not data.has("grid_size"):
		push_error("Invalid terrain data format")
		return false
	
	# Clear existing data
	clear_all()
	
	# Restore grid size
	_grid_size = Vector2(data.grid_size.x, data.grid_size.y)
	
	# Restore terrain map
	for pos_str in data.terrain_map:
		var pos_parts: PackedStringArray = pos_str.split(",", false, 2)
		if pos_parts.size() == 2:
			var pos := Vector2i(int(pos_parts[0]), int(pos_parts[1]))
			var terrain_data: Dictionary = data.terrain_map[pos_str]
			
			# Place terrain with its data
			place_terrain(pos, terrain_data.get("type", TerrainTypes.Type.EMPTY), terrain_data.get("feature_type", GameEnums.TerrainFeatureType.NONE))
			
			# Handle any additional data if needed
	
	return true