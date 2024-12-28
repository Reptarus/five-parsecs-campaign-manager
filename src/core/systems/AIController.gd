class_name AIController
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")
const Character = preload("res://src/core/character/Management/CharacterDataManager.gd")
const Mission = preload("res://src/core/systems/Mission.gd")
const UnifiedAISystem = preload("res://src/core/systems/UnifiedAISystem.gd")
const CombatManager = preload("res://src/core/battle/CombatManager.gd")

signal ai_action_completed(action: Dictionary)

@export var ai_behavior: int = GameEnums.AIBehavior.CAUTIOUS

var combat_manager: CombatManager
var game_state_manager: GameStateManager
var enemy_deployment_manager: Node # Will be typed when EnemyDeploymentManager is available

func _calculate_attack_score(character: Character, enemy: Character) -> float:
	var score := 0.0
	# Calculate attack score based on various factors
	# Distance to target
	var distance = character.global_position.distance_to(enemy.global_position)
	score -= distance * 0.1
	
	# Target's health
	score += (1.0 - enemy.health / enemy.max_health) * 50
	
	# Weapon effectiveness
	if character.has_weapon():
		score += 25
		
	return score

func _calculate_defensive_score(character: Character, position: Vector2) -> float:
	var score := 0.0
	# Calculate defensive position score
	# Distance to cover
	var distance = character.global_position.distance_to(position)
	score -= distance * 0.1
	
	# Cover effectiveness
	if combat_manager.has_cover_at_position(position):
		score += 30
		
	# Distance to enemies
	var closest_enemy_distance := 1000.0
	for enemy in combat_manager.get_active_enemies():
		var enemy_distance = position.distance_to(enemy.global_position)
		closest_enemy_distance = min(closest_enemy_distance, enemy_distance)
	
	score += closest_enemy_distance * 0.2
	
	return score
