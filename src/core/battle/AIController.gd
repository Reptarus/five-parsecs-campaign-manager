@tool
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const CharacterUnit = preload("res://src/core/battle/CharacterUnit.gd")
const TerrainTypes = preload("res://src/core/terrain/TerrainTypes.gd")

## Action types for battle
enum ActionType {
	NONE,
	MOVE,
	ATTACK,
	DEFEND,
	USE_ITEM,
	USE_ABILITY,
	END_TURN
}

## Signals
signal ai_turn_started
signal ai_turn_ended
signal ai_action_performed(unit: CharacterUnit, action_type: int, target_position: Vector2)

## Properties
var battlefield_manager = null
var current_unit: CharacterUnit = null
var enemy_units: Array[CharacterUnit] = []
var player_units: Array[CharacterUnit] = []
var difficulty_level: int = 2 # 1-5 scale

## AI behavior weights
var weights = {
	"attack": 0.6,
	"move_to_cover": 0.4,
	"group_up": 0.2,
	"retreat": 0.3,
	"target_weakest": 0.5,
	"target_closest": 0.3,
	"target_isolated": 0.4
}

## Initialize the AI controller
func _init() -> void:
	pass

## Set the battlefield manager reference
func set_battlefield_manager(manager) -> void:
	battlefield_manager = manager

## Set the AI difficulty level
func set_difficulty(level: int) -> void:
	difficulty_level = clamp(level, 1, 5)
	_adjust_weights_for_difficulty()

## Register units with the AI controller
func register_units(ai_units: Array[CharacterUnit], friendly_units: Array[CharacterUnit]) -> void:
	enemy_units = ai_units
	player_units = friendly_units

## Start AI turn
func start_ai_turn() -> void:
	ai_turn_started.emit()
	
	# Process each enemy unit
	for unit in enemy_units:
		if unit.is_active() and not unit.check_if_defeated():
			current_unit = unit
			process_unit_turn(unit)
			await get_tree().create_timer(0.5).timeout # Add delay between units for better visual flow
	
	ai_turn_ended.emit()
	current_unit = null

## Process a single unit's turn
func process_unit_turn(unit: CharacterUnit) -> void:
	if not unit or unit.check_if_defeated() or not unit.is_active():
		return
	
	# Get possible actions
	var possible_actions = _get_possible_actions(unit)
	
	# If no valid actions, end turn for this unit
	if possible_actions.is_empty():
		return
	
	# Select best action based on AI analysis
	var selected_action = _select_best_action(unit, possible_actions)
	
	# Execute the selected action
	_execute_action(unit, selected_action)

## Get all possible actions for a unit
func _get_possible_actions(unit: CharacterUnit) -> Array:
	var actions = []
	
	# Check if unit can attack
	var attack_targets = _get_attack_targets(unit)
	for target in attack_targets:
		actions.append({
			"type": ActionType.ATTACK,
			"target": target,
			"position": target.global_position,
			"score": _calculate_attack_score(unit, target)
		})
	
	# Check movement options
	var movement_options = _get_movement_options(unit)
	for option in movement_options:
		actions.append({
			"type": ActionType.MOVE,
			"position": option.position,
			"cover_value": option.cover_value,
			"distance_to_enemy": option.distance_to_enemy,
			"score": _calculate_move_score(unit, option)
		})
	
	# Add special abilities if available
	# This would be expanded based on the game's specific abilities
	
	return actions

## Get valid attack targets
func _get_attack_targets(unit: CharacterUnit) -> Array:
	var targets = []
	
	for player_unit in player_units:
		if player_unit.check_if_defeated():
			continue
		
		# Check if target is in range and line of sight
		var distance = unit.global_position.distance_to(player_unit.global_position)
		var in_range = distance <= unit.get_attack_range()
		
		if in_range and _has_line_of_sight(unit, player_unit):
			targets.append(player_unit)
	
	return targets

## Get movement options
func _get_movement_options(unit: CharacterUnit) -> Array:
	var options = []
	var move_range = unit.get_movement_range()
	var current_pos = unit.global_position
	
	# Get cell coordinates
	var current_cell = battlefield_manager._world_to_grid(current_pos)
	
	# Check cells in movement range
	for x in range(current_cell.x - move_range, current_cell.x + move_range + 1):
		for y in range(current_cell.y - move_range, current_cell.y + move_range + 1):
			var cell = Vector2i(x, y)
			
			# Skip if outside battlefield or current position
			if not battlefield_manager._is_valid_grid_position(cell) or cell == current_cell:
				continue
			
			# Skip if occupied by another unit
			if _is_cell_occupied(cell):
				continue
			
			# Check if within movement range (Manhattan distance for simplicity)
			var manhattan_distance = abs(cell.x - current_cell.x) + abs(cell.y - current_cell.y)
			if manhattan_distance > move_range:
				continue
			
			# Get terrain information
			var terrain_type = battlefield_manager.get_terrain_type(battlefield_manager._grid_to_world(cell))
			if TerrainTypes.blocks_movement(terrain_type):
				continue
			
			# Get world position
			var world_pos = battlefield_manager._grid_to_world(cell)
			
			# Calculate cover value at this position
			var cover_value = battlefield_manager.get_cover_value(world_pos)
			
			# Calculate distance to nearest enemy
			var min_distance = 1000.0
			for player_unit in player_units:
				if player_unit.check_if_defeated():
					continue
				
				var distance = world_pos.distance_to(player_unit.global_position)
				min_distance = min(min_distance, distance)
			
			options.append({
				"position": world_pos,
				"cell": cell,
				"cover_value": cover_value,
				"distance_to_enemy": min_distance
			})
	
	return options

## Check if a cell is occupied by a unit
func _is_cell_occupied(cell: Vector2i) -> bool:
	var world_pos = battlefield_manager._grid_to_world(cell)
	
	# Check if any unit is at this position
	for unit in enemy_units + player_units:
		if unit.check_if_defeated():
			continue
		
		var unit_cell = battlefield_manager._world_to_grid(unit.global_position)
		if unit_cell == cell:
			return true
	
	return false

## Check line of sight between two units
func _has_line_of_sight(from_unit: CharacterUnit, to_unit: CharacterUnit) -> bool:
	if not battlefield_manager:
		return true
	
	var from_pos = battlefield_manager._world_to_grid(from_unit.global_position)
	var to_pos = battlefield_manager._world_to_grid(to_unit.global_position)
	
	# Simple Bresenham line algorithm to check for obstacles
	var x0 = from_pos.x
	var y0 = from_pos.y
	var x1 = to_pos.x
	var y1 = to_pos.y
	
	var dx = abs(x1 - x0)
	var dy = - abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx + dy
	
	while x0 != x1 or y0 != y1:
		var e2 = 2 * err
		if e2 >= dy:
			if x0 == x1:
				break
			err += dy
			x0 += sx
		if e2 <= dx:
			if y0 == y1:
				break
			err += dx
			y0 += sy
		
		# Skip checking the starting and ending positions
		if Vector2i(x0, y0) != from_pos and Vector2i(x0, y0) != to_pos:
			var terrain_type = battlefield_manager.get_terrain_type(battlefield_manager._grid_to_world(Vector2i(x0, y0)))
			if TerrainTypes.get_los_blocking(terrain_type) > 0.8: # Threshold for blocking
				return false
	
	return true

## Calculate score for an attack action
func _calculate_attack_score(unit: CharacterUnit, target: CharacterUnit) -> float:
	var score = weights["attack"]
	
	# Factor in target health
	var health_factor = (1.0 - target.get_health_percent()) * weights["target_weakest"]
	score += health_factor
	
	# Factor in isolation (fewer allies nearby means more isolated)
	var isolation_factor = 0
	for player_unit in player_units:
		if player_unit != target and not player_unit.check_if_defeated():
			var distance = player_unit.global_position.distance_to(target.global_position)
			if distance < 3.0: # Arbitrary threshold for "nearby"
				isolation_factor -= 0.1
	
	score += isolation_factor * weights["target_isolated"]
	
	# Factor in distance
	var distance = unit.global_position.distance_to(target.global_position)
	var distance_factor = (1.0 - (distance / unit.get_attack_range())) * weights["target_closest"]
	score += distance_factor
	
	# Factor in hit chance
	var hit_chance = unit.calculate_hit_chance(target)
	score *= hit_chance
	
	return score

## Calculate score for a move action
func _calculate_move_score(unit: CharacterUnit, option: Dictionary) -> float:
	var score = 0.0
	
	# Factor in cover
	var cover_factor = option.cover_value * weights["move_to_cover"]
	score += cover_factor
	
	# Factor in distance to enemies
	var distance_factor = 0.0
	if unit.get_health_percent() < 0.3:
		# Low health, prefer to stay away
		distance_factor = min(option.distance_to_enemy / 10.0, 1.0) * weights["retreat"]
	else:
		# Healthy, prefer to get closer
		distance_factor = (1.0 - min(option.distance_to_enemy / 10.0, 1.0)) * (1.0 - weights["retreat"])
	
	score += distance_factor
	
	# Factor in grouping with allies
	var group_factor = 0.0
	for ally in enemy_units:
		if ally != unit and not ally.check_if_defeated():
			var distance = option.position.distance_to(ally.global_position)
			if distance < 4.0: # Arbitrary threshold for "nearby"
				group_factor += 0.1 * weights["group_up"]
	
	score += group_factor
	
	return score

## Select the best action from possible actions
func _select_best_action(unit: CharacterUnit, actions: Array):
	if actions.is_empty():
		return null
	
	# Sort actions by score, highest first
	actions.sort_custom(func(a, b): return a.score > b.score)
	
	# Add some randomness based on difficulty level
	# Lower difficulty = more random (less optimal) choices
	var randomness_factor = (6 - difficulty_level) * 0.1 # 0.1 to 0.5
	
	# Sometimes select a sub-optimal action
	if randf() < randomness_factor and actions.size() > 1:
		return actions[1] # Second best action
	
	return actions[0] # Best action

## Execute the selected action
func _execute_action(unit: CharacterUnit, action: Dictionary) -> void:
	if not action:
		return
	
	match action.type:
		ActionType.ATTACK:
			# Perform attack
			var target = action.target
			var damage = unit.calculate_damage(target)
			target.take_damage(damage)
			
			ai_action_performed.emit(unit, ActionType.ATTACK, target.global_position)
			
		ActionType.MOVE:
			# Move to position
			unit.move_to(action.position)
			
			ai_action_performed.emit(unit, ActionType.MOVE, action.position)
			
		# Add more action types as needed

## Adjust AI weights based on difficulty
func _adjust_weights_for_difficulty() -> void:
	match difficulty_level:
		1: # Easy
			weights["attack"] = 0.4
			weights["move_to_cover"] = 0.3
			weights["target_weakest"] = 0.3
			weights["target_isolated"] = 0.2
			
		2: # Normal (default)
			# Keep default weights
			pass
			
		3: # Challenging
			weights["attack"] = 0.7
			weights["move_to_cover"] = 0.5
			weights["target_weakest"] = 0.6
			weights["target_isolated"] = 0.5
			
		4: # Hard
			weights["attack"] = 0.8
			weights["move_to_cover"] = 0.6
			weights["target_weakest"] = 0.7
			weights["target_isolated"] = 0.6
			weights["group_up"] = 0.4
			
		5: # Brutal
			weights["attack"] = 0.9
			weights["move_to_cover"] = 0.7
			weights["target_weakest"] = 0.8
			weights["target_isolated"] = 0.7
			weights["group_up"] = 0.5
			weights["retreat"] = 0.2 # Less likely to retreat