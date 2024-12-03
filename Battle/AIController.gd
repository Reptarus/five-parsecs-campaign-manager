class_name AIBehaviorController
extends Node

const TerrainTypes = preload("res://Battle/TerrainTypes.gd")
const BattlefieldManager = preload("res://Battle/BattlefieldManager.gd")
const CombatResolver = preload("res://Battle/CombatResolver.gd")
const PathFinder = preload("res://Battle/PathFinder.gd")

signal action_decided(unit: Character, action: int, target_position: Vector2)
signal target_selected(unit: Character, target: Character)

enum AIBehavior {
	AGGRESSIVE,    # Prioritize attacking enemies
	DEFENSIVE,     # Prioritize staying in cover and maintaining distance
	SUPPORT,       # Focus on supporting allies
	FLANKING,      # Attempt to flank enemies
	OPPORTUNIST    # Wait for reaction opportunities
}

var battlefield_manager: BattlefieldManager
var combat_resolver: CombatResolver
var path_finder: PathFinder

# AI State tracking
var unit_behaviors: Dictionary = {}  # Character: AIBehavior
var threat_map: Dictionary = {}      # Vector2: float
var opportunity_map: Dictionary = {} # Vector2: float
var tactical_memory: Dictionary = {} # For remembering previous successful tactics

func initialize(_battlefield_manager: BattlefieldManager, _combat_resolver: CombatResolver) -> void:
	battlefield_manager = _battlefield_manager
	combat_resolver = _combat_resolver
	path_finder = PathFinder.new()
	_connect_signals()

func decide_action(unit: Character) -> Dictionary:
	var behavior = _determine_behavior(unit)
	var action_scores = _evaluate_all_actions(unit, behavior)
	
	# Get highest scored action
	action_scores.sort_custom(func(a, b): return a.score > b.score)
	return action_scores[0] if action_scores else {"type": "defend", "score": 0}

func _evaluate_all_actions(unit: Character, behavior: AIBehavior) -> Array:
	var actions = []
	
	# Movement evaluation
	var movement_positions = _get_valid_movement_positions(unit)
	for pos in movement_positions:
		var score = _score_position(unit, pos, behavior)
		actions.append({
			"type": "move",
			"position": pos,
			"score": score
		})
	
	# Attack evaluation
	var potential_targets = _get_potential_targets(unit)
	for target in potential_targets:
		var score = _score_attack(unit, target, behavior)
		actions.append({
			"type": "attack",
			"target": target,
			"score": score
		})
	
	# Special actions based on behavior
	match behavior:
		AIBehavior.DEFENSIVE:
			actions.append(_evaluate_defensive_actions(unit))
		AIBehavior.FLANKING:
			actions.append(_evaluate_flanking_opportunities(unit))
		AIBehavior.SUPPORT:
			actions.append(_evaluate_support_actions(unit))
	
	return actions

func _determine_behavior(unit: Character) -> AIBehavior:
	# Update behavior based on unit's status and battlefield situation
	var health_ratio = float(unit.current_health) / unit.max_health
	var nearby_allies = _get_nearby_allies(unit)
	var nearby_enemies = _get_nearby_enemies(unit)
	
	if health_ratio < 0.3:
		return AIBehavior.DEFENSIVE
	elif _has_flanking_opportunity(unit):
		return AIBehavior.FLANKING
	elif nearby_allies.size() > nearby_enemies.size():
		return AIBehavior.AGGRESSIVE
	elif unit.has_support_abilities() and _allies_need_support(nearby_allies):
		return AIBehavior.SUPPORT
	
	return AIBehavior.OPPORTUNIST

func _score_position(unit: Character, position: Vector2, behavior: AIBehavior) -> float:
	var score = 0.0
	
	# Base position scoring
	score += _calculate_cover_value(position) * 2.0
	score += _calculate_tactical_advantage(unit, position)
	score -= _calculate_exposure_risk(position)
	
	# Behavior-specific scoring
	match behavior:
		AIBehavior.DEFENSIVE:
			score += _score_defensive_position(position)
		AIBehavior.FLANKING:
			score += _score_flanking_position(unit, position)
		AIBehavior.SUPPORT:
			score += _score_support_position(unit, position)
	
	return score

func _score_attack(unit: Character, target: Character, behavior: AIBehavior) -> float:
	var score = 0.0
	
	# Base attack scoring
	score += _calculate_damage_potential(unit, target)
	score += _calculate_kill_probability(unit, target) * 3.0
	score -= _calculate_retaliation_risk(unit, target)
	
	# Behavior modifiers
	match behavior:
		AIBehavior.AGGRESSIVE:
			score *= 1.5
		AIBehavior.DEFENSIVE:
			score *= 0.7
		AIBehavior.FLANKING:
			score *= 1.0 + _calculate_flanking_bonus(unit, target)
	
	return score

func _calculate_tactical_advantage(unit: Character, position: Vector2) -> float:
	var advantage = 0.0
	
	# Height advantage
	var elevation = battlefield_manager.get_elevation(position)
	advantage += elevation * 0.5
	
	# Line of sight to enemies
	var visible_enemies = _get_visible_enemies_from_position(position)
	advantage += visible_enemies.size() * 0.3
	
	# Distance to objectives
	var objective_positions = battlefield_manager.get_objective_positions()
	for obj_pos in objective_positions:
		var dist = position.distance_to(obj_pos)
		advantage += 1.0 / max(dist, 1.0)
	
	return advantage

func _update_threat_map() -> void:
	threat_map.clear()
	var enemy_units = battlefield_manager.get_enemy_units()
	
	for enemy in enemy_units:
		var threat_range = enemy.get_threat_range()
		var positions = battlefield_manager.get_positions_in_range(
			enemy.position, threat_range)
		
		for pos in positions:
			var threat_value = _calculate_threat_value(enemy, pos)
			threat_map[pos] = threat_map.get(pos, 0.0) + threat_value

# Helper methods
func _get_nearby_allies(unit: Character, range: float = 5.0) -> Array:
	return battlefield_manager.get_units_in_range(unit.position, range, true)

func _get_nearby_enemies(unit: Character, range: float = 5.0) -> Array:
	return battlefield_manager.get_units_in_range(unit.position, range, false)

func _has_flanking_opportunity(unit: Character) -> bool:
	var enemies = _get_nearby_enemies(unit)
	for enemy in enemies:
		if _can_flank_target(unit, enemy):
			return true
	return false

func _allies_need_support(allies: Array) -> bool:
	for ally in allies:
		if ally.current_health < ally.max_health * 0.6:
			return true
	return false 