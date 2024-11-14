class_name AIController
extends Node

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const Character = preload("res://Resources/CrewAndCharacters/Character.gd")
const GameState = preload("res://Resources/GameData/GameState.gd")
const GameStateManager = preload("res://StateMachines/GameStateManager.gd")
const CombatManager = preload("res://Resources/BattlePhase/CombatManager.gd")

signal ai_action_completed(action: Dictionary)

const DEFAULT_SCORE := -1.0

@export var ai_behavior: int = GlobalEnums.AIBehavior.AGGRESSIVE

var combat_manager: CombatManager
var game_state_manager: GameStateManager
var enemy_deployment_manager: Node  # Will be typed when EnemyDeploymentManager is available

func setup(p_combat_manager: Node, p_game_state_manager: GameStateManager) -> void:
	if not p_combat_manager or not p_game_state_manager:
		push_error("Invalid managers provided to AIController")
		return
		
	combat_manager = p_combat_manager
	game_state_manager = p_game_state_manager
	
	enemy_deployment_manager = _initialize_enemy_deployment_manager()

func _initialize_enemy_deployment_manager() -> Node:
	var manager = Node.new()  # Replace with actual EnemyDeploymentManager when available
	manager.name = "EnemyDeploymentManager"
	add_child(manager)
	return manager

func set_ai_behavior(behavior: int) -> void:
	ai_behavior = behavior

func perform_ai_turn(character: Character) -> void:
	match ai_behavior:
		GlobalEnums.AIBehavior.CAUTIOUS:
			_perform_cautious_actions(character)
		GlobalEnums.AIBehavior.AGGRESSIVE:
			_perform_aggressive_actions(character)
		GlobalEnums.AIBehavior.TACTICAL:
			_perform_tactical_actions(character)
		GlobalEnums.AIBehavior.DEFENSIVE:
			_perform_defensive_actions(character)
		GlobalEnums.AIBehavior.RAMPAGE:
			_perform_rampage_actions(character)
		GlobalEnums.AIBehavior.BEAST:
			_perform_beast_actions(character)
		GlobalEnums.AIBehavior.GUARDIAN:
			_perform_guardian_actions(character)
		_:
			push_error("Invalid AI behavior: %d" % ai_behavior)

# AI behavior implementations
func _perform_cautious_actions(character: Character) -> void:
	var cover_pos = combat_manager.find_cover_position(character)
	if cover_pos != Vector2.ZERO:
		combat_manager.handle_move(character, cover_pos)
	
	var target = combat_manager.find_best_target(character)
	if target:
		combat_manager.handle_attack(character, target)

func _perform_aggressive_actions(character: Character) -> void:
	var target = combat_manager.find_nearest_enemy(character)
	if target:
		combat_manager.handle_attack(character, target)
	else:
		var random_pos = combat_manager.get_random_position()
		combat_manager.handle_move(character, random_pos)

func _perform_tactical_actions(character: Character) -> void:
	var tactical_pos = combat_manager.find_tactical_position(character)
	if tactical_pos != Vector2.ZERO:
		combat_manager.handle_move(character, tactical_pos)
	
	var target = combat_manager.find_best_target(character)
	if target:
		combat_manager.handle_attack(character, target)

func _perform_defensive_actions(character: Character) -> void:
	var cover_near_enemy = combat_manager.find_cover_near_enemy(character)
	if cover_near_enemy != Vector2.ZERO:
		combat_manager.handle_move(character, cover_near_enemy)
	
	var target = combat_manager.find_random_enemy()
	if target:
		combat_manager.handle_attack(character, target)

func _perform_rampage_actions(character: Character) -> void:
	var target = combat_manager.find_random_enemy()
	if target:
		combat_manager.handle_attack(character, target)
	else:
		var random_pos = combat_manager.get_random_position()
		combat_manager.handle_move(character, random_pos)

func _perform_beast_actions(character: Character) -> void:
	var target = combat_manager.find_nearest_enemy(character)
	if target:
		combat_manager.handle_attack(character, target)
	else:
		var random_pos = combat_manager.get_random_position()
		combat_manager.handle_move(character, random_pos)

func _perform_guardian_actions(character: Character) -> void:
	var ally = combat_manager.find_random_ally()
	if ally:
		var cover_pos = combat_manager.find_cover_near_enemy(character)
		if cover_pos != Vector2.ZERO:
			combat_manager.handle_move(character, cover_pos)
	
	var target = combat_manager.find_best_target(character)
	if target:
		combat_manager.handle_attack(character, target)
