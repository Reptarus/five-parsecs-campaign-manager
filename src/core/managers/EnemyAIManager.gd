extends Node
class_name EnemyAIManager

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const EnemyNode = preload("res://src/core/enemy/base/EnemyNode.gd")
const UnifiedAISystem = preload("res://src/core/systems/UnifiedAISystem.gd")
const AIController = preload("res://src/core/systems/AIController.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
const SaveManager = preload("res://src/core/state/SaveManager.gd")

# Signals
signal ai_decision_made(enemy_ref: EnemyNode, decision: Dictionary)
signal behavior_changed(enemy_ref: EnemyNode, new_behavior: GameEnums.AIBehavior)
signal action_completed(enemy_ref: EnemyNode, action_type: String)

# Constants for behavior weights
const BEHAVIOR_WEIGHTS = {
	"attack": 2.0,
	"move": 1.5,
	"cover": 1.0,
	"support": 0.8,
	"retreat": 0.5
}

# AI State
var current_enemy: EnemyNode
var active_enemies: Array[EnemyNode] = []
var behavior_overrides: Dictionary = {}
var tactical_memory: Dictionary = {}

func _init() -> void:
	pass

# Initialization method for test compatibility
func initialize(battlefield_manager = null, combat_manager = null) -> void:
	# Store references to the managers
	if battlefield_manager:
		set_meta("battlefield_manager", battlefield_manager)
	
	if combat_manager:
		set_meta("combat_manager", combat_manager)
		
	# Initialize internal systems if needed
	for enemy in active_enemies:
		_initialize_tactical_memory(enemy)

# Enemy Management
func register_enemy(enemy: EnemyNode) -> void:
	if not enemy in active_enemies:
		active_enemies.append(enemy)
		_initialize_tactical_memory(enemy)

func unregister_enemy(enemy: EnemyNode) -> void:
	active_enemies.erase(enemy)
	tactical_memory.erase(enemy)

func set_behavior_override(enemy: EnemyNode, behavior: GameEnums.AIBehavior) -> void:
	behavior_overrides[enemy] = behavior
	behavior_changed.emit(enemy, behavior)

func clear_behavior_override(enemy: EnemyNode) -> void:
	behavior_overrides.erase(enemy)

func get_current_behavior(enemy: EnemyNode) -> GameEnums.AIBehavior:
	return behavior_overrides.get(enemy, enemy.behavior)

# Decision Making
func make_decision(enemy: EnemyNode) -> Dictionary:
	current_enemy = enemy
	var options = []
	
	# Evaluate movement options
	if _can_move(enemy):
		options.append({
			"type": "move",
			"priority": BEHAVIOR_WEIGHTS["move"],
			"position": _get_optimal_position(enemy)
		})
	
	# Evaluate attack options
	if _can_attack(enemy):
		var target = _get_best_target(enemy)
		if target:
			options.append({
				"type": "attack",
				"priority": BEHAVIOR_WEIGHTS["attack"],
				"target": target
			})
	
	# Evaluate cover options
	if _should_seek_cover(enemy):
		options.append({
			"type": "cover",
			"priority": BEHAVIOR_WEIGHTS["cover"],
			"position": _find_nearest_cover(enemy)
		})
	
	if options.is_empty():
		return {"type": "idle"}
		
	options.sort_custom(func(a, b): return a.priority > b.priority)
	return options[0]

# Helper Functions
func _initialize_tactical_memory(enemy: EnemyNode) -> void:
	tactical_memory[enemy] = {
		"last_position": enemy.global_position,
		"last_target": null,
		"damage_taken": 0,
		"successful_hits": 0
	}

func _can_move(enemy: EnemyNode) -> bool:
	return enemy.get_movement_range() > 0

func _can_attack(enemy: EnemyNode) -> bool:
	return enemy.get_weapon() != null

func _should_seek_cover(enemy: EnemyNode) -> bool:
	var memory = tactical_memory.get(enemy, {})
	return memory.get("damage_taken", 0) > 0

func _get_optimal_position(enemy: EnemyNode) -> Vector2:
	# Implementation depends on your game's spatial system
	return enemy.global_position

func _get_best_target(enemy: EnemyNode) -> Node:
	# Implementation depends on your target selection system
	return null

func _find_nearest_cover(enemy: EnemyNode) -> Vector2:
	# Implementation depends on your cover system
	return enemy.global_position

# Serialization
func serialize() -> Dictionary:
	var data = {
		"behavior_overrides": {},
		"tactical_memory": {}
	}
	
	for enemy in behavior_overrides:
		if is_instance_valid(enemy):
			data.behavior_overrides[enemy.get_instance_id()] = behavior_overrides[enemy]
			
	for enemy in tactical_memory:
		if is_instance_valid(enemy):
			data.tactical_memory[enemy.get_instance_id()] = tactical_memory[enemy]
			
	return data

func deserialize(data: Dictionary) -> void:
	behavior_overrides.clear()
	tactical_memory.clear()
	
	if data.has("behavior_overrides"):
		for enemy_id in data.behavior_overrides:
			var enemy = instance_from_id(int(enemy_id))
			if is_instance_valid(enemy):
				behavior_overrides[enemy] = data.behavior_overrides[enemy_id]
				
	if data.has("tactical_memory"):
		for enemy_id in data.tactical_memory:
			var enemy = instance_from_id(int(enemy_id))
			if is_instance_valid(enemy):
				tactical_memory[enemy] = data.tactical_memory[enemy_id]