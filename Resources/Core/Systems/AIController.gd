class_name AIController
extends Node

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const Character = preload("res://Resources/CrewAndCharacters/Character.gd")
const GameState = preload("res://Resources/GameData/GameState.gd")
const GameStateManager = preload("res://StateMachines/GameStateManager.gd")
const CombatManager = preload("res://Resources/BattlePhase/CombatManager.gd")

signal ai_action_completed(action: Dictionary)

const DEFAULT_SCORE := -1.0

@export var ai_behavior: int = GlobalEnums.AIBehavior.CAUTIOUS

var combat_manager: CombatManager
var game_state_manager: GameStateManager
var enemy_deployment_manager: Node  # Will be typed when EnemyDeploymentManager is available

# Add frame budgeting for AI calculations
const MAX_AI_UPDATES_PER_FRAME := 5
var _pending_ai_updates: Array[Character] = []

# Add helper functions for AI processing
var _current_frame_budget: int = 0
var _last_process_time: float = 0.0

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
		GlobalEnums.AIBehavior.AGGRESSIVE:
			_perform_aggressive_actions(character)
		GlobalEnums.AIBehavior.DEFENSIVE:
			_perform_defensive_actions(character)
		GlobalEnums.AIBehavior.TACTICAL:
			_perform_tactical_actions(character)
		GlobalEnums.AIBehavior.SUPPORT:
			_perform_support_actions(character)
		GlobalEnums.AIBehavior.RANDOM:
			_perform_random_actions(character)
		GlobalEnums.AIBehavior.CAUTIOUS:
			_perform_cautious_actions(character)
		GlobalEnums.AIBehavior.RAMPAGE:
			_perform_rampage_actions(character)
		GlobalEnums.AIBehavior.BEAST:
			_perform_beast_actions(character)
		GlobalEnums.AIBehavior.GUARDIAN:
			_perform_guardian_actions(character)
		GlobalEnums.AIBehavior.PROTECTIVE:
			_perform_protective_actions(character)
		GlobalEnums.AIBehavior.EVASIVE:
			_perform_evasive_actions(character)
		GlobalEnums.AIBehavior.BERSERK:
			_perform_berserk_actions(character)
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

func _perform_support_actions(character: Character) -> void:
	# Implementation for support behavior
	pass

func _perform_random_actions(character: Character) -> void:
	# Implementation for random behavior
	pass

func _perform_protective_actions(character: Character) -> void:
	# Implementation for protective behavior
	pass

func _perform_evasive_actions(character: Character) -> void:
	# Implementation for evasive behavior
	pass

func _perform_berserk_actions(character: Character) -> void:
	# Implementation for berserk behavior
	pass

func process_ai_updates() -> void:
	if OS.get_name() == "Android":
		var updates_this_frame := 0
		while not _pending_ai_updates.is_empty() and updates_this_frame < MAX_AI_UPDATES_PER_FRAME:
			var character = _pending_ai_updates.pop_front()
			_update_character_ai(character)
			updates_this_frame += 1
	else:
		for character in _pending_ai_updates:
			_update_character_ai(character)
		_pending_ai_updates.clear()

func _update_character_ai(character: Character) -> void:
	if not is_instance_valid(character):
		return
		
	match character.ai_behavior:
		GlobalEnums.AIBehavior.TACTICAL:
			_perform_tactical_actions(character)
		GlobalEnums.AIBehavior.DEFENSIVE:
			_perform_defensive_actions(character)
		GlobalEnums.AIBehavior.AGGRESSIVE:
			_perform_rampage_actions(character)
		GlobalEnums.AIBehavior.BEAST:
			_perform_beast_actions(character)
		GlobalEnums.AIBehavior.GUARDIAN:
			_perform_guardian_actions(character)
		_:
			push_warning("Unknown AI behavior type: %s" % character.ai_behavior)

func queue_ai_update(character: Character) -> void:
	if not character in _pending_ai_updates:
		_pending_ai_updates.append(character)

func _reset_frame_budget() -> void:
	_current_frame_budget = MAX_AI_UPDATES_PER_FRAME
	_last_process_time = Time.get_ticks_msec()

func has_pending_updates() -> bool:
	return not _pending_ai_updates.is_empty()

func get_pending_count() -> int:
	return _pending_ai_updates.size()

# Add performance monitoring
func _monitor_performance() -> void:
	var current_time = Time.get_ticks_msec()
	var frame_time = current_time - _last_process_time
	
	# Instead of modifying the constant, store the value in a variable
	var target_updates = _current_frame_budget
	if frame_time > 16.67:  # More than 1/60th of a second
		target_updates = max(1, target_updates - 1)
	elif frame_time < 8.33:  # Less than 1/120th of a second
		target_updates = min(10, target_updates + 1)
	_current_frame_budget = target_updates

func _perform_combat_action(character: Character) -> void:
	var best_action = _evaluate_combat_options(character)
	match best_action.type:
		"attack":
			combat_manager.handle_attack(character, best_action.target)
		"move":
			combat_manager.handle_move(character, best_action.position)
		"defend":
			_perform_defensive_actions(character)

func _evaluate_combat_options(character: Character) -> Dictionary:
	var options = []
	var enemies = combat_manager.find_valid_targets(character)
	
	for enemy in enemies:
		var score = _calculate_attack_score(character, enemy)
		options.append({
			"type": "attack",
			"target": enemy,
			"score": score
		})
	
	# Consider defensive positions
	var cover_positions = combat_manager.find_nearby_cover(character)
	for pos in cover_positions:
		var score = _calculate_defensive_score(character, pos)
		options.append({
			"type": "move",
			"position": pos,
			"score": score
		})
	
	# Sort by score and return best option
	options.sort_custom(func(a, b): return a.score > b.score)
	return options[0] if options else {"type": "defend"}
