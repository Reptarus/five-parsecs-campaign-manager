extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const Enemy = preload("res://src/core/enemy/base/Enemy.gd")
const UnifiedAISystem = preload("res://src/core/systems/UnifiedAISystem.gd")
const AIController = preload("res://src/core/systems/AIController.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
const SaveManager = preload("res://src/core/state/SaveManager.gd")

# Signals
signal ai_decision_made(enemy_ref: Enemy, decision: Dictionary)
signal behavior_changed(enemy_ref: Enemy, new_behavior: GameEnums.AIBehavior)
signal action_completed(enemy_ref: Enemy, action_type: String)

# Constants for behavior weights  
const BEHAVIOR_WEIGHTS = {
	"attack": 2.0,
	"move": 1.5,
	"cover": 1.0,
	"support": 0.8,
	"retreat": 0.5,
	"flank": 1.8,
	"suppress": 1.2,
	"coordinate": 1.0
}

# Five Parsecs specific AI behaviors
enum FiveParsecsAIBehavior {
	AGGRESSIVE, # Always move to attack
	DEFENSIVE, # Prioritize cover and position
	TACTICAL, # Use formation tactics
	BERSERKER, # Ignore damage, always attack
	CAUTIOUS, # Avoid unnecessary risks
	PACK_HUNTER, # Coordinate with allies
	LONE_WOLF, # Act independently
	OPPORTUNIST # Wait for openings
}

# Tactical formation patterns
const FORMATION_PATTERNS = {
	"line": {"spread": 2.0, "depth": 0.5},
	"wedge": {"spread": 1.5, "depth": 1.5},
	"box": {"spread": 1.0, "depth": 1.0},
	"skirmish": {"spread": 3.0, "depth": 0.8}
}

# Advanced AI state tracking
var formation_assignments: Dictionary = {} # enemy -> formation_role
var coordination_groups: Array[Array] = [] # Groups of coordinating enemies
var battlefield_analysis: Dictionary = {} # Terrain and position analysis

# AI State
var current_enemy: Enemy
var active_enemies: Array[Enemy] = []
var behavior_overrides: Dictionary = {}
var tactical_memory: Dictionary = {}

func _init() -> void:
	pass

# Enemy Management
func register_enemy(enemy: Enemy) -> void:
	if not enemy in active_enemies:
		active_enemies.append(enemy) # warning: return value discarded (intentional)
		_initialize_tactical_memory(enemy)

func unregister_enemy(enemy: Enemy) -> void:
	active_enemies.erase(enemy)
	tactical_memory.erase(enemy)
func set_behavior_override(enemy: Enemy, behavior: GameEnums.AIBehavior) -> void:
	behavior_overrides[enemy] = behavior
	behavior_changed.emit(enemy, behavior) # warning: return value discarded (intentional)

func clear_behavior_override(enemy: Enemy) -> void:
	behavior_overrides.erase(enemy)
func get_current_behavior(enemy: Enemy) -> GameEnums.AIBehavior:
	return behavior_overrides.get(enemy, enemy.behavior)

# Decision Making
func make_decision(enemy: Enemy) -> Dictionary:
	current_enemy = enemy
	var options: Array = []
	
	# Analyze battlefield situation
	_update_battlefield_analysis(enemy)
	
	# Get Five Parsecs AI behavior
	var ai_behavior = _get_five_parsecs_behavior(enemy)
	
	# Generate options based on AI behavior and tactical situation
	options = _generate_tactical_options(enemy, ai_behavior)
	
	# Apply formation coordination if in a group
	if _is_in_coordination_group(enemy):
		options = _apply_formation_tactics(enemy, options)
	
	# Evaluate threat assessment
	var threat_level = _assess_threat_level(enemy)
	options = _adjust_for_threat_level(enemy, options, threat_level)
	
	# Apply Five Parsecs specific modifiers
	options = _apply_five_parsecs_modifiers(enemy, options)
	
	if options.is_empty():
		return {"type": "idle", "reason": "no_valid_options"}
		
	# Sort by priority and select best option
	options.sort_custom(func(a, b): return a.priority > b.priority)
	var chosen_option = options[0]
	
	# Record decision for learning
	_record_tactical_decision(enemy, chosen_option)
	
	ai_decision_made.emit(enemy, chosen_option) # warning: return value discarded (intentional)
	return chosen_option

# Helper Functions
func _initialize_tactical_memory(enemy: Enemy) -> void:
	tactical_memory[enemy] = {
		"last_position": enemy.global_position,
		"last_target": null,
		"damage_taken": 0,
		"successful_hits": 0
	}
func _can_move(enemy: Enemy) -> bool:
	return enemy.get_movement_range() > 0

func _can_attack(enemy: Enemy) -> bool:
	return enemy.get_weapon() != null

func _should_seek_cover(enemy: Enemy) -> bool:
	var memory = tactical_memory.get(enemy, {})

	return memory.get("damage_taken", 0) > 0

func _get_optimal_position(enemy: Enemy) -> Vector2:
	# Implementation depends on your game's spatial system
	return enemy.global_position

func _get_best_target(enemy: Enemy) -> Node:
	# Get the closest viable target
	var targets = _get_viable_targets(enemy)
	if targets.is_empty():
		return null
	# Sort by distance and return closest
	var enemy_pos = enemy.global_position if enemy.has("global_position") else Vector2.ZERO
	targets.sort_custom(func(a, b):
		var a_pos = a.global_position if a.has("global_position") else Vector2.ZERO
		var b_pos = b.global_position if b.has("global_position") else Vector2.ZERO
		return enemy_pos.distance_to(a_pos) < enemy_pos.distance_to(b_pos)
	)
	return targets[0]

func _find_nearest_cover(enemy: Enemy) -> Vector2:
	# Implementation depends on your cover system
	var cover_positions = get_cover_positions()
	var nearest_cover = enemy.global_position
	var closest_distance: float = INF
	
	for cover_pos in cover_positions:
		var distance = enemy.global_position.distance_to(cover_pos)
		if distance < closest_distance:
			closest_distance = distance
			nearest_cover = cover_pos
	
	return nearest_cover

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

## ===== FIVE PARSECS TACTICAL AI ENHANCEMENTS =====
func _get_five_parsecs_behavior(enemy: Enemy) -> FiveParsecsAIBehavior:
	# Determine Five Parsecs AI behavior based on enemy type and situation
	# Check for behavior override first
	if enemy.has_method("get_ai_behavior"):
		var override = enemy.get_ai_behavior()
		if override != null:
			return override
	
	# Determine behavior based on enemy type and stats

	var enemy_type = enemy.enemy_type if enemy.has("enemy_type") else "generic"

	var health_ratio = float(enemy.health) / enemy.max_health if enemy.has("health") and enemy.has("max_health") else 1.0
	
	match enemy_type:
		"raider", "pirate":
			return FiveParsecsAIBehavior.AGGRESSIVE if health_ratio > 0.5 else FiveParsecsAIBehavior.OPPORTUNIST
		"soldier", "enforcer":
			return FiveParsecsAIBehavior.TACTICAL
		"beast", "creature":
			return FiveParsecsAIBehavior.BERSERKER
		"robot", "bot":
			return FiveParsecsAIBehavior.DEFENSIVE
		"assassin", "specialist":
			return FiveParsecsAIBehavior.LONE_WOLF
		"gang_member":
			return FiveParsecsAIBehavior.PACK_HUNTER
		_:
			return FiveParsecsAIBehavior.CAUTIOUS

func _generate_tactical_options(enemy: Enemy, ai_behavior: FiveParsecsAIBehavior) -> Array:
	# Generate tactical options based on AI behavior
	var options: Array = []
	
	# Base movement and attack options
	if _can_move(enemy):
		options.append_array(_generate_movement_options(enemy, ai_behavior))
	
	if _can_attack(enemy):
		options.append_array(_generate_attack_options(enemy, ai_behavior))
	
	# Behavior-specific options
	match ai_behavior:
		FiveParsecsAIBehavior.AGGRESSIVE:
			options.append_array(_generate_aggressive_options(enemy))
		FiveParsecsAIBehavior.DEFENSIVE:
			options.append_array(_generate_defensive_options(enemy))
		FiveParsecsAIBehavior.TACTICAL:
			options.append_array(_generate_tactical_formation_options(enemy))
		FiveParsecsAIBehavior.BERSERKER:
			options.append_array(_generate_berserker_options(enemy))
		FiveParsecsAIBehavior.CAUTIOUS:
			options.append_array(_generate_cautious_options(enemy))
		FiveParsecsAIBehavior.PACK_HUNTER:
			options.append_array(_generate_pack_hunting_options(enemy))
		FiveParsecsAIBehavior.LONE_WOLF:
			options.append_array(_generate_lone_wolf_options(enemy))
		FiveParsecsAIBehavior.OPPORTUNIST:
			options.append_array(_generate_opportunist_options(enemy))
	
	return options

func _generate_movement_options(enemy: Enemy, ai_behavior: FiveParsecsAIBehavior) -> Array:
	# Generate movement options based on AI behavior
	var options: Array = []
	var base_priority = BEHAVIOR_WEIGHTS["move"]
	
	# Different movement priorities based on behavior
	match ai_behavior:
		FiveParsecsAIBehavior.AGGRESSIVE:
			options.append({ # warning: return value discarded (intentional)
				"type": "move_to_attack",
				"priority": base_priority * 1.5,
				"position": _get_closest_attack_position(enemy),
				"reason": "aggressive_advance"
			})
		FiveParsecsAIBehavior.DEFENSIVE:
			options.append({ # warning: return value discarded (intentional)
				"type": "move_to_cover",
				"priority": base_priority * 1.3,
				"position": _find_best_defensive_position(enemy),
				"reason": "defensive_positioning"
			})
		FiveParsecsAIBehavior.TACTICAL:
			options.append({ # warning: return value discarded (intentional)
				"type": "move_to_formation",
				"priority": base_priority * 1.2,
				"position": _get_formation_position(enemy),
				"reason": "tactical_positioning"
			})
		_:
			options.append({ # warning: return value discarded (intentional)
				"type": "move",
				"priority": base_priority,
				"position": _get_optimal_position(enemy),
				"reason": "general_movement"
			})
	
	return options

func _generate_attack_options(enemy: Enemy, ai_behavior: FiveParsecsAIBehavior) -> Array:
	# Generate attack options based on AI behavior
	var options: Array = []
	var targets = _get_viable_targets(enemy)
	
	for target in targets:
		var base_priority = BEHAVIOR_WEIGHTS["attack"]
		var attack_type: String = "standard_attack"
		var priority_modifier: int = 1
		
		match ai_behavior:
			FiveParsecsAIBehavior.AGGRESSIVE, FiveParsecsAIBehavior.BERSERKER:
				priority_modifier = 1.5
				attack_type = "aggressive_attack"
			FiveParsecsAIBehavior.CAUTIOUS:
				priority_modifier = 0.8
				attack_type = "cautious_attack"
			FiveParsecsAIBehavior.OPPORTUNIST:
				if _is_target_vulnerable(target):
					priority_modifier = 2.0
					attack_type = "opportunistic_attack"
				else:
					continue # Skip non-vulnerable targets

		options.append({ # warning: return value discarded (intentional)
			"type": attack_type,
			"priority": base_priority * priority_modifier,
			"target": target,
			"weapon": enemy.get_weapon() if enemy.has_method("get_weapon") else null,
			"reason": "targeted_attack"
		})
	
	return options

func _generate_aggressive_options(enemy: Enemy) -> Array:
	# Generate options for aggressive AI behavior
	var options: Array = []
	
	# Charge attack - move and attack in one action
	var closest_target = _get_best_target(enemy)
	if closest_target:
		options.append({ # warning: return value discarded (intentional)
			"type": "charge_attack",
			"priority": BEHAVIOR_WEIGHTS["attack"] * 1.8,
			"target": closest_target,
			"position": _get_charge_position(enemy, closest_target),
			"reason": "aggressive_charge"
		})
	
	# Suppression fire to pin down enemies

	options.append({ # warning: return value discarded (intentional)
		"type": "suppress",
		"priority": BEHAVIOR_WEIGHTS["suppress"] * 1.2,
		"targets": _get_suppress_targets(enemy),
		"reason": "aggressive_suppression"
	})
	
	return options

func _generate_defensive_options(enemy: Enemy) -> Array:
	# Generate options for defensive AI behavior
	var options: Array = []
	
	# Overwatch - covering fire for allies
	if _has_allies_in_range(enemy):
		options.append({ # warning: return value discarded (intentional)
			"type": "overwatch",
			"priority": BEHAVIOR_WEIGHTS["support"] * 1.4,
			"cover_area": _get_overwatch_area(enemy),
			"reason": "defensive_overwatch"
		})
	
	# Fortify position

	options.append({ # warning: return value discarded (intentional)
		"type": "fortify",
		"priority": BEHAVIOR_WEIGHTS["cover"] * 1.5,
		"position": enemy.global_position if enemy.has("global_position") else Vector2.ZERO,
		"reason": "defensive_fortification"
	})
	
	return options

func _generate_pack_hunting_options(enemy: Enemy) -> Array:
	# Generate options for pack hunting behavior
	var options: Array = []
	var pack_allies = _get_pack_allies(enemy)
	
	if pack_allies.size() > 0:
		# Coordinated flank attack
		options.append({ # warning: return value discarded (intentional)
			"type": "flank_coordinate",
			"priority": BEHAVIOR_WEIGHTS["flank"] * 1.6,
			"allies": pack_allies,
			"target": _get_best_flank_target(enemy),
			"reason": "pack_flank_attack"
		})
		
		# Pack surround maneuver

		options.append({ # warning: return value discarded (intentional)
			"type": "surround",
			"priority": BEHAVIOR_WEIGHTS["coordinate"] * 1.4,
			"allies": pack_allies,
			"target": _get_isolated_target(enemy),
			"reason": "pack_surround"
		})
	
	return options

func _update_battlefield_analysis(enemy: Enemy) -> void:
	# Update tactical analysis of the battlefield
	var enemy_pos = enemy.global_position if enemy.has("global_position") else Vector2.ZERO
	
	battlefield_analysis = {
		"cover_positions": _scan_cover_positions(enemy_pos),
		"high_ground": _scan_elevation_advantage(enemy_pos),
		"choke_points": _identify_choke_points(enemy_pos),
		"ally_positions": _get_ally_positions(enemy),
		"enemy_positions": _get_player_positions(),
		"threat_zones": _calculate_threat_zones(),
		"escape_routes": _identify_escape_routes(enemy_pos)
	}
func _assess_threat_level(enemy: Enemy) -> String:
	# Assess current threat level for tactical decisions
	var health_ratio = float(enemy.health) / enemy.max_health if enemy.has("health") and enemy.has("max_health") else 1.0
	var nearby_enemies = _count_nearby_player_characters(enemy)
	var has_cover = _is_in_cover(enemy)
	
	var threat_score: int = 0
	
	# Health factor
	if health_ratio < 0.3:
		threat_score += 3
	elif health_ratio < 0.6:
		threat_score += 1
	
	# Enemy proximity factor
	threat_score += nearby_enemies
	
	# Cover factor
	if not has_cover:
		threat_score += 2
	
	# Determine threat level
	if threat_score >= 5:
		return "critical"
	elif threat_score >= 3:
		return "high"
	elif threat_score >= 1:
		return "moderate"
	else:
		return "low"

func _apply_five_parsecs_modifiers(enemy: Enemy, options: Array) -> Array:
	# Apply Five Parsecs specific combat modifiers
	for option in options:
		# Range modifiers
		if option.type.contains("attack"):
			var range_modifier = _calculate_range_modifier(enemy, option.get("target"))
			option.priority *= range_modifier
		
		# Cover modifiers
		if option.type.contains("cover"):
			var cover_quality = _assess_cover_quality(option.get("position", Vector2.ZERO))
			option.priority *= (1.0 + cover_quality * 0.3)
		
		# Weapon type modifiers
		if option.has("weapon") and option.weapon:
			var weapon_modifier = _get_weapon_tactical_modifier(option.weapon, option.type)
			option.priority *= weapon_modifier
	
	return options

func _record_tactical_decision(enemy: Enemy, decision: Dictionary) -> void:
	# Record AI decision for learning and analysis
	var memory = tactical_memory.get(enemy, {})
	
	if not memory.has("decision_history"):
		memory["decision_history"] = []
	
	memory.decision_history.append({
		"decision": decision,
		"timestamp": Time.get_unix_time_from_system(),
		"battlefield_state": battlefield_analysis.duplicate(),
		"threat_level": _assess_threat_level(enemy)
	})
	
	# Keep only last 10 decisions
	if memory.decision_history.size() > 10:
		memory.decision_history = memory.decision_history.slice(-10)
	
	tactical_memory[enemy] = memory

## ===== FORMATION AND COORDINATION =====
func create_coordination_group(enemies: Array[Enemy], formation_type: String = "line") -> void:
	# Create a coordination group with formation tactics
	coordination_groups.append(enemies) # warning: return value discarded (intentional)

	var formation_data = FORMATION_PATTERNS.get(formation_type, FORMATION_PATTERNS["line"])
	var center_pos = _calculate_group_center(enemies)
	
	for i in range(enemies.size()):
		var enemy = enemies[i]
		var role = _assign_formation_role(i, enemies.size(), formation_type)
		formation_assignments[enemy] = {
			"group_id": coordination_groups.size() - 1,
			"role": role,
			"formation_type": formation_type,
			"target_position": _calculate_formation_position(center_pos, i, formation_data)
		}

func _assign_formation_role(index: int, group_size: int, formation_type: String) -> String:
	# Assign formation role based on position and formation type
	match formation_type:
		"line":
			if index == 0:
				return "left_flank"
			elif index == group_size - 1:
				return "right_flank"
			else:
				return "center"
		"wedge":
			if index == 0:
				return "point"
			else:
				return "support"
		"box":
			match index % 4:
				0: return "front_left"
				1: return "front_right"
				2: return "rear_left"
				3: return "rear_right"
		_:
			return "skirmisher"
	return "skirmisher"

## ===== UTILITY FUNCTIONS =====

func _get_viable_targets(enemy: Enemy) -> Array:
	# Get all viable targets for this enemy
	# Implementation would depend on your character/target system
	return []

func _is_target_vulnerable(target) -> bool:
	# Check if target is in a vulnerable position
	# Implementation would check for flanking, no cover, low health, etc.
	return false

func _get_closest_attack_position(enemy: Enemy) -> Vector2:
	return enemy.global_position if enemy.has("global_position") else Vector2.ZERO

func _find_best_defensive_position(enemy: Enemy) -> Vector2:
	return enemy.global_position if enemy.has("global_position") else Vector2.ZERO

func _get_formation_position(enemy: Enemy) -> Vector2:
	var assignment = formation_assignments.get(enemy, {})

	return assignment.get("target_position", enemy.global_position if enemy.has("global_position") else Vector2.ZERO)

func _is_in_coordination_group(enemy: Enemy) -> bool:
	return formation_assignments.has(enemy)

func _apply_formation_tactics(enemy: Enemy, options: Array) -> Array:
	# Enhance existing options with formation considerations
	return options

func _scan_elevation_advantage(pos: Vector2) -> Array:
	return []

func _identify_choke_points(pos: Vector2) -> Array:
	return []

func _get_ally_positions(enemy: Enemy) -> Array:
	return []

func _get_player_positions() -> Array:
	return []

func _calculate_threat_zones() -> Array:
	return []

func _identify_escape_routes(pos: Vector2) -> Array:
	return []

func _count_nearby_player_characters(enemy: Enemy) -> int:
	return 0

func _is_in_cover(enemy: Enemy) -> bool:
	return false

func _adjust_for_threat_level(enemy: Enemy, options: Array, threat_level: String) -> Array:
	return options

func _generate_tactical_formation_options(enemy: Enemy) -> Array:
	return []

func _generate_berserker_options(enemy: Enemy) -> Array:
	return []

func _generate_cautious_options(enemy: Enemy) -> Array:
	return []

func _generate_lone_wolf_options(enemy: Enemy) -> Array:
	return []

func _generate_opportunist_options(enemy: Enemy) -> Array:
	return []

func _get_charge_position(enemy: Enemy, target) -> Vector2:
	return enemy.global_position if enemy.has("global_position") else Vector2.ZERO

func _get_suppress_targets(enemy: Enemy) -> Array:
	return []

func _has_allies_in_range(enemy: Enemy) -> bool:
	return false

func _get_overwatch_area(enemy: Enemy) -> Dictionary:
	return {}

func _get_pack_allies(enemy: Enemy) -> Array:
	return []

func _get_best_flank_target(enemy: Enemy) -> Node:
	return _get_closest_target(enemy)

func _get_isolated_target(enemy: Enemy) -> Node:
	return _get_closest_target(enemy)

func _assess_cover_quality(position: Vector2) -> float:
	return 0.5

func _calculate_group_center(enemies: Array) -> Vector2:
	if enemies.is_empty():
		return Vector2.ZERO
	var sum_pos = Vector2.ZERO
	for enemy in enemies:
		if enemy.has("global_position"):
			sum_pos += enemy.global_position
	return sum_pos / enemies.size()

func _calculate_formation_position(center: Vector2, index: int, formation_data: Dictionary) -> Vector2:
	return center

func get_player_targets() -> Array:
	# Stub implementation - return empty array
	return []

func get_cover_positions() -> Array:
	# Stub implementation - return empty array
	return []

func _scan_cover_positions(pos: Vector2) -> Array:
	# Stub implementation - scan for cover positions around the given position
	return []

func _calculate_range_modifier(enemy: Enemy, target) -> float:
	# Stub implementation - calculate range modifier for weapon effectiveness
	if not target:
		return 1.0
	var distance = enemy.global_position.distance_to(target.global_position) if enemy.has("global_position") and target.has("global_position") else 100.0
	if distance < 50.0:
		return 1.2 # Close range bonus
	elif distance > 200.0:
		return 0.8 # Long range penalty
	return 1.0

func _get_weapon_tactical_modifier(weapon, action_type: String) -> float:
	# Stub implementation - get tactical modifier based on weapon and action type
	if not weapon:
		return 1.0
	match action_type:
		"aggressive_attack":
			return 1.1
		"cautious_attack":
			return 0.9
		_:
			return 1.0

func _get_closest_target(enemy: Enemy) -> Node:
	# Implementation to find the closest target
	var targets = _get_viable_targets(enemy)
	if targets.is_empty():
		return null
	
	var enemy_pos = enemy.global_position if enemy.has("global_position") else Vector2.ZERO
	var closest_target: Node = null
	var closest_distance: float = INF
	
	for target in targets:
		var target_pos = target.global_position if target.has("global_position") else Vector2.ZERO
		var distance = enemy_pos.distance_to(target_pos)
		if distance < closest_distance:
			closest_distance = distance
			closest_target = target
	
	return closest_target
