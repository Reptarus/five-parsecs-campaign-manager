## UnifiedAISystem
## Manages AI behavior and decision making for units in the Five Parsecs battle system.
class_name UnifiedAISystem
extends Node

## Dependencies
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Management/CharacterDataManager.gd")
const EnemyData = preload("res://src/core/rivals/EnemyData.gd")

## Emitted when an AI unit decides on an action
signal action_decided(unit: Character, action: int, target_position: Vector2)
## Emitted when an AI unit selects a target
signal target_selected(unit: Character, target: Character)
## Emitted when an AI unit changes behavior
signal behavior_changed(unit: Character, new_behavior: int)

## Reference to the battlefield manager
@export var battlefield_manager: Node # Will be cast to BattlefieldManager
## Reference to the combat resolver
@export var combat_resolver: Node # Will be cast to CombatResolver

## Maps units to their current AI behavior
var unit_behaviors: Dictionary = {}
## Maps units to their current targets
var unit_targets: Dictionary = {}
## Maps units to their current tactics
var unit_tactics: Dictionary = {}
## Maps positions to their threat level
var threat_map: Dictionary = {}
## Currently active unit
var current_unit: Character = null

## Squad formation settings
const IDEAL_SPACING := 3.0 # Ideal distance between units
const MAX_SUPPORT_RANGE := 12.0 # Maximum range for support calculations
const OBJECTIVE_WEIGHT := 0.6 # Weight for objective-based decisions

## AI tactical behaviors
enum AITactic {
	ENGAGE_CLOSE, # Move closer to engage
	MAINTAIN_RANGE, # Keep optimal distance
	SEEK_COVER, # Move to cover
	FLANK_TARGET, # Move to flanking position
	SUPPORT_ALLY, # Move to support position
	RETREAT # Move away from danger
}

func _ready() -> void:
	if battlefield_manager:
		battlefield_manager.tactical_advantage_changed.connect(_on_tactical_advantage_changed)
	else:
		push_warning("UnifiedAISystem: No battlefield manager assigned")
	if not combat_resolver:
		push_warning("UnifiedAISystem: No combat resolver assigned")

## Initialize a unit with a specific behavior
func initialize_unit(unit: Character, behavior: GameEnums.AIBehavior) -> void:
	if not unit:
		push_error("UnifiedAISystem: Cannot initialize null unit")
		return
		
	unit_behaviors[unit] = behavior
	unit_tactics[unit] = AITactic.MAINTAIN_RANGE

## Process a unit's turn and determine their action
func process_turn(unit: Character) -> Dictionary:
	if not unit:
		push_error("UnifiedAISystem: Cannot process turn for null unit")
		return {}
		
	current_unit = unit
	var action := {}
	
	# Update unit state
	_update_unit_state(unit)
	
	# Determine action based on behavior
	match unit_behaviors.get(unit, GameEnums.AIBehavior.TACTICAL):
		GameEnums.AIBehavior.AGGRESSIVE:
			action = _process_aggressive_behavior(unit)
		GameEnums.AIBehavior.DEFENSIVE:
			action = _process_defensive_behavior(unit)
		GameEnums.AIBehavior.TACTICAL:
			action = _process_tactical_behavior(unit)
		GameEnums.AIBehavior.CAUTIOUS:
			action = _process_cautious_behavior(unit)
		GameEnums.AIBehavior.SUPPORTIVE:
			action = _process_support_behavior(unit)
		_:
			action = _process_default_behavior(unit)
	
	# Emit signals
	if action.has("target_position"):
		action_decided.emit(unit, action.get("action", -1), action.target_position)
	if action.has("target_unit"):
		target_selected.emit(unit, action.target_unit)
	
	return action

## Process aggressive behavior for a unit
func _process_aggressive_behavior(unit: Character) -> Dictionary:
	var target := _find_best_target(unit)
	if target:
		unit_targets[unit] = target
		return {
			"action": GameEnums.UnitAction.ATTACK,
			"target_unit": target,
			"target_position": battlefield_manager.unit_positions[target]
		}
	return _process_default_behavior(unit)

## Process defensive behavior for a unit
func _process_defensive_behavior(unit: Character) -> Dictionary:
	var cover_position := _find_best_cover(unit)
	if cover_position != Vector2.ZERO:
		return {
			"action": GameEnums.UnitAction.MOVE,
			"target_position": cover_position
		}
	return _process_default_behavior(unit)

## Process tactical behavior for a unit
func _process_tactical_behavior(unit: Character) -> Dictionary:
	var squad_status := _evaluate_squad_status(unit)
	
	if squad_status.average_health < 0.5:
		return _process_defensive_behavior(unit)
	
	var objective_priority := _calculate_objective_priority(unit)
	if objective_priority > OBJECTIVE_WEIGHT:
		return _process_objective_behavior(unit)
	
	return _process_aggressive_behavior(unit)

## Process cautious behavior for a unit
func _process_cautious_behavior(unit: Character) -> Dictionary:
	var threat_level := _calculate_threat_level(unit)
	if threat_level > 0.7:
		return _process_defensive_behavior(unit)
	return _process_tactical_behavior(unit)

## Process support behavior for a unit
func _process_support_behavior(unit: Character) -> Dictionary:
	var ally_needing_support := _find_ally_needing_support(unit)
	if ally_needing_support:
		return {
			"action": GameEnums.UnitAction.MOVE,
			"target_unit": ally_needing_support,
			"target_position": battlefield_manager.unit_positions[ally_needing_support]
		}
	return _process_tactical_behavior(unit)

## Process default behavior for a unit
func _process_default_behavior(unit: Character) -> Dictionary:
	return {
		"action": GameEnums.UnitAction.NONE,
		"target_position": battlefield_manager.unit_positions[unit]
	}

## Process objective-focused behavior for a unit
func _process_objective_behavior(unit: Character) -> Dictionary:
	var objective_position := _find_nearest_objective(unit)
	if objective_position != Vector2.ZERO:
		return {
			"action": GameEnums.UnitAction.MOVE,
			"target_position": objective_position
		}
	return _process_default_behavior(unit)

## Update a unit's state and behavior
func _update_unit_state(unit: Character) -> void:
	if not unit:
		return
		
	var current_behavior: int = unit_behaviors.get(unit, GameEnums.AIBehavior.TACTICAL)
	var new_behavior: int = _determine_behavior(unit)
	
	if new_behavior != current_behavior:
		unit_behaviors[unit] = new_behavior
		behavior_changed.emit(unit, new_behavior)

## Determine appropriate behavior for a unit based on their state
func _determine_behavior(unit: Character) -> GameEnums.AIBehavior:
	if not unit:
		return GameEnums.AIBehavior.TACTICAL
		
	var health_ratio: float = float(unit.get_current_health()) / unit.get_max_health()
	var threat_level: float = _calculate_threat_level(unit)
	var support_need: float = _evaluate_support_needs(unit)
	
	if health_ratio < 0.3:
		return GameEnums.AIBehavior.CAUTIOUS
	elif threat_level > 0.7:
		return GameEnums.AIBehavior.DEFENSIVE
	elif support_need > 0.7:
		return GameEnums.AIBehavior.SUPPORTIVE
	
	return GameEnums.AIBehavior.TACTICAL

## Find the best target for a unit to attack
func _find_best_target(unit: Character) -> Character:
	if not unit or not battlefield_manager:
		return null
		
	var best_target: Character = null
	var best_score := -INF
	
	for potential_target in battlefield_manager.unit_positions.keys():
		if potential_target.is_enemy() != unit.is_enemy():
			var score := _evaluate_target_score(unit, potential_target)
			if score > best_score:
				best_score = score
				best_target = potential_target
	
	return best_target

## Find the best cover position for a unit
func _find_best_cover(unit: Character) -> Vector2:
	# Implementation depends on your terrain system
	return Vector2.ZERO

## Find the nearest objective position for a unit
func _find_nearest_objective(unit: Character) -> Vector2:
	if not battlefield_manager or battlefield_manager.objective_positions.is_empty():
		return Vector2.ZERO
		
	var unit_pos: Vector2 = battlefield_manager.unit_positions[unit]
	var nearest_pos: Vector2 = Vector2.ZERO
	var nearest_dist: float = INF
	
	for obj_pos in battlefield_manager.objective_positions:
		var dist: float = unit_pos.distance_to(obj_pos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_pos = obj_pos
	
	return nearest_pos

## Find an ally that needs support
func _find_ally_needing_support(unit: Character) -> Character:
	if not unit:
		return null
		
	var allies := _get_nearby_allies(unit, MAX_SUPPORT_RANGE)
	var most_needed: Character = null
	var highest_need := 0.0
	
	for ally in allies:
		var need := _calculate_support_need(ally)
		if need > highest_need:
			highest_need = need
			most_needed = ally
	
	return most_needed

## Calculate how much support a unit needs
func _calculate_support_need(unit: Character) -> float:
	if not unit:
		return 0.0
		
	var health_ratio: float = float(unit.get_current_health()) / unit.get_max_health()
	var status_penalty: float = unit.has_negative_effects() as float
	return (1.0 - health_ratio) + (status_penalty * 0.3)

## Calculate the threat level at a unit's position
func _calculate_threat_level(unit: Character) -> float:
	if not battlefield_manager or not unit:
		return 0.0
		
	var unit_pos: Vector2 = battlefield_manager.unit_positions[unit]
	var grid_pos: Vector2i = battlefield_manager._world_to_grid(unit_pos)
	return _calculate_position_threat(grid_pos)

## Evaluate a target's score for targeting priority
func _evaluate_target_score(unit: Character, target: Character) -> float:
	if not unit or not target or not battlefield_manager:
		return -INF
		
	var distance: float = battlefield_manager.unit_positions[unit].distance_to(
		battlefield_manager.unit_positions[target]
	)
	var health_ratio: float = float(target.get_current_health()) / target.get_max_health()
	var threat_score: float = _calculate_threat_level(target)
	
	return (1.0 - health_ratio) * 0.4 + (1.0 - distance / 20.0) * 0.3 + threat_score * 0.3

## Evaluate support needs for a unit and their allies
func _evaluate_support_needs(unit: Character) -> float:
	if not battlefield_manager or not unit:
		return 0.0
		
	var allies := _get_nearby_allies(unit, 8.0)
	var support_need: float = 0.0
	
	for ally in allies:
		var health_ratio: float = float(ally.get_current_health()) / ally.get_max_health()
		if health_ratio < 0.5:
			support_need += (0.5 - health_ratio) * 2.0
		
		if ally.has_negative_effects():
			support_need += 0.3
	
	return clampf(support_need, 0.0, 1.0)

## Calculate priority for objective-based actions
func _calculate_objective_priority(unit: Character) -> float:
	if not battlefield_manager or battlefield_manager.objective_positions.is_empty():
		return 0.0
		
	var unit_pos: Vector2 = battlefield_manager.unit_positions[unit]
	var nearest_objective := _find_nearest_objective(unit)
	var distance: float = unit_pos.distance_to(nearest_objective)
	
	return maxf(0.0, 1.0 - (distance / 20.0))

## Calculate threat level at a specific position
func _calculate_position_threat(position: Vector2) -> float:
	if not battlefield_manager:
		return 0.0
		
	return threat_map.get(position, 0.0)

## Get nearby allies within a specified range
func _get_nearby_allies(unit: Character, range: float) -> Array[Character]:
	if not battlefield_manager or not unit:
		return []
		
	var allies: Array[Character] = []
	var unit_pos: Vector2 = battlefield_manager.unit_positions[unit]
	
	for other in battlefield_manager.unit_positions:
		if other != unit and not other.is_enemy() == unit.is_enemy():
			var distance: float = unit_pos.distance_to(battlefield_manager.unit_positions[other])
			if distance <= range:
				allies.append(other)
	
	return allies

## Evaluate the overall status of a unit's squad
func _evaluate_squad_status(unit: Character) -> Dictionary:
	if not unit:
		return {"average_health": 1.0, "morale": 1.0}
		
	var allies := _get_nearby_allies(unit, MAX_SUPPORT_RANGE)
	var total_health := 0.0
	var total_morale := 0.0
	var count := 1
	
	# Include the unit itself
	total_health += float(unit.get_current_health()) / unit.get_max_health()
	
	for ally in allies:
		total_health += float(ally.get_current_health()) / ally.get_max_health()
		count += 1
	
	return {
		"average_health": total_health / count,
		"morale": total_morale / count
	}

## Handle changes in tactical advantage
func _on_tactical_advantage_changed(position: Vector2, advantage: float) -> void:
	threat_map[position] = 1.0 - advantage

## Optional Enemy AI Integration
func process_enemy_turn(enemy: EnemyData) -> Dictionary:
	var unit = _convert_enemy_to_character(enemy)
	if unit:
		return process_turn(unit)
	return {}

func _convert_enemy_to_character(enemy: EnemyData) -> Character:
	# Implementation depends on your character system
	# This should convert EnemyData to a Character instance
	return null